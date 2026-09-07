--[[
    PZ RPG  --  Constitution

    CMB-1: "all combat + surviving hits". Trains from body-health drops (like
    Defense, at half the rate) plus a flat trickle on every melee hit landed.

    CONST-EFFECT-1: higher Constitution = a chance to shrug off the Knox
    infection the instant a bite / scratch would transmit it. Vanilla still
    decides whether infection happens; we only get a save right as it lands
    (not a cure for an established infection). Kept conservative -- a maxed
    character still dies to most bites.

    CONST-EFFECT-2 (resilience): the injury-side counterpart to Defense's flat
    damage reduction. Two transient per-tick nudges, no persistent state:
      - a small passive general-health regen while hurt (not while bleeding
        badly, not while a hit just landed)
      - bleeding stops faster -- each tick shave a level-scaled fraction off
        every bleeding body part's remaining bleed time
    Kept modest -- PZ death is the point (DESIGN.md 5).

    Load order: _33_ -> after the _0N_ Core files.
]]

PZRPG.tuning = PZRPG.tuning or {}
local TUNING = PZRPG.tuning.constitution or {
    -- XP
    XP_PER_HP  = 125,     -- half of Defense's rate
    MIN_DROP   = 0.5,
    MAX_DROP   = 15,
    XP_PER_HIT = 2,       -- flat trickle per character struck in melee

    -- CONST-EFFECT-1: infection resistance (chance 0..1 to negate transmission)
    --   resist = COEF * (level / 100) ^ EXP
    SCRATCH_COEF = 0.55, SCRATCH_EXP = 0.75,   -- L50 ~0.33, L100 0.55
    BITE_COEF    = 0.20, BITE_EXP    = 0.85,   -- L50 ~0.11, L100 0.20

    -- CONST-EFFECT-2: resilience
    REGEN_MAX      = 0.004,   -- extra general-health per tick while hurt, at L100
    REGEN_EXP      = 1.4,     -- ramp: near-zero below ~L40
    REGEN_MIN_HP   = 3,       -- don't bother regen'ing when within this of full
    BLEED_SHRINK_MAX = 0.020, -- fraction of remaining bleed-time removed per tick at L100
    BLEED_SHRINK_EXP = 1.3,
}
PZRPG.tuning.constitution = TUNING

local function ramp(level, maxAt100, exp)
    local frac = math.max(0, math.min(1, (level or 1) / 100))
    return maxAt100 * (frac ^ exp)
end

PZRPG.registerSkill{
    id       = "constitution",
    name     = "Constitution",
    category = "combat",
    order    = 110,
    describe = function(level)
        local s = math.floor(TUNING.SCRATCH_COEF * ((level / 100) ^ TUNING.SCRATCH_EXP) * 100 + 0.5)
        local b = math.floor(TUNING.BITE_COEF    * ((level / 100) ^ TUNING.BITE_EXP)    * 100 + 0.5)
        local bleed = math.floor(ramp(level, TUNING.BLEED_SHRINK_MAX, TUNING.BLEED_SHRINK_EXP) * 100 + 0.5)
        return ("Shrug-off chance: scratch %d%%, bite %d%%. Bleeding resolves ~%d%% faster/tick; slow passive regen while hurt.")
            :format(s, b, bleed)
    end,
}

---------------------------------------------------------------------------
-- XP  (CMB-1)
---------------------------------------------------------------------------

PZRPG.hookEvent("OnPlayerUpdate", "constitution.update", function(player)
    if not player or player:getPlayerNum() ~= 0 then return end

    local ok, hp = pcall(function() return player:getBodyDamage():getHealth() end)
    if not ok or type(hp) ~= "number" then return end

    local prev = PZRPG._constitutionLastHp
    PZRPG._constitutionLastHp = hp
    if prev == nil then return end

    local drop = prev - hp
    if drop < TUNING.MIN_DROP or drop > TUNING.MAX_DROP then return end

    PZRPG.addXp(player, "constitution", drop * TUNING.XP_PER_HP)
end)

PZRPG.hookEvent("OnWeaponHitXp", "constitution.hit", function(owner, weapon, hitObject, damage, hitCount)
    if not owner or owner ~= getSpecificPlayer(0) then return end
    if not weapon or weapon:isRanged() or weapon:getType() == "BareHands" then return end
    hitCount = tonumber(hitCount) or 0
    if hitCount <= 0 then return end

    PZRPG.addXp(owner, "constitution", TUNING.XP_PER_HIT * hitCount)
end)

---------------------------------------------------------------------------
-- CONST-EFFECT-1: infection resistance
---------------------------------------------------------------------------

local function resistChance(level, isBite)
    local frac = math.max(0, math.min(1, level / 100))
    if isBite then
        return TUNING.BITE_COEF * (frac ^ TUNING.BITE_EXP)
    end
    return TUNING.SCRATCH_COEF * (frac ^ TUNING.SCRATCH_EXP)
end

--- A fresh zombie infection just landed this tick -- roll a save on each
--- newly-infected part and clear the ones we resist.
local function tryResistInfection(player, bd)
    local level = PZRPG.getLevel(player, "constitution")
    local parts = bd:getBodyParts()
    if not parts then return end

    local cured, remaining = false, false
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part and part:IsInfected() then
            local isBite = part:bitten()
            local chance = resistChance(level, isBite)
            if chance > 0 and ZombRand(100) < chance * 100 then
                part:SetInfected(false)
                cured = true
            else
                remaining = true
            end
        end
    end

    if cured then
        if not remaining then
            pcall(function() bd:setInfected(false) end)
        end
        pcall(function()
            if HaloTextHelper and HaloTextHelper.addTextWithArrow then
                HaloTextHelper.addTextWithArrow(player, "Constitution: fought off the infection!",
                    true, HaloTextHelper.getGoodColor())
            end
        end)
        PZRPG.log(("constitution: resisted zombie infection (level %d%s)")
            :format(level, remaining and ", partially" or ""))
    end
end

PZRPG.hookEvent("OnPlayerUpdate", "constitution.infection", function(player)
    if not player or player:getPlayerNum() ~= 0 then return end

    local ok, bd = pcall(function() return player:getBodyDamage() end)
    if not ok or not bd then return end

    local now  = bd:IsInfected()
    local prev = PZRPG._constInfPrev

    -- First observation (spawn / save load): just record it. We only ever act
    -- on a false -> true transition, i.e. infection landing while we watch --
    -- never on an infection that already existed.
    if prev == nil then
        PZRPG._constInfPrev = now
        return
    end

    if now and not prev then
        pcall(function() tryResistInfection(player, bd) end)
        now = bd:IsInfected()          -- re-read after a possible cure
    end
    PZRPG._constInfPrev = now
end)

---------------------------------------------------------------------------
-- CONST-EFFECT-2: resilience -- faster bleed stop + slow regen while hurt
---------------------------------------------------------------------------

PZRPG.hookEvent("OnPlayerUpdate", "constitution.resilience", function(player)
    if not player or player:getPlayerNum() ~= 0 then return end

    local ok, bd = pcall(function() return player:getBodyDamage() end)
    if not ok or not bd then return end

    local level = PZRPG.getLevel(player, "constitution")

    -- Faster bleed stop: shave a level-scaled fraction off every bleeding
    -- part's remaining bleed time each tick (compounds -> bleeds end sooner).
    local shrink = ramp(level, TUNING.BLEED_SHRINK_MAX, TUNING.BLEED_SHRINK_EXP)
    local bleeding = false
    if shrink > 0 then
        pcall(function()
            local parts = bd:getBodyParts()
            if not parts then return end
            for i = 0, parts:size() - 1 do
                local part = parts:get(i)
                local t = part and part:getBleedingTime() or 0
                if t and t > 0 then
                    local nt = t * (1 - shrink)
                    if nt < 0.05 then
                        nt = 0
                        pcall(function() part:setBleeding(false) end)
                    else
                        bleeding = true
                    end
                    part:setBleedingTime(nt)
                end
            end
        end)
    end

    -- Slow passive regen while hurt -- but not while still bleeding (you're
    -- losing blood, not recovering) and not on a tick a hit just landed
    -- (Defense's watcher owns those; don't fight it).
    local regen = ramp(level, TUNING.REGEN_MAX, TUNING.REGEN_EXP)
    if regen > 0 and not bleeding then
        local okH, hp = pcall(function() return bd:getHealth() end)
        local prev = PZRPG._constResilLastHp
        PZRPG._constResilLastHp = (okH and hp) or nil
        if okH and type(hp) == "number"
           and hp > 0 and hp < (100 - TUNING.REGEN_MIN_HP)
           and prev ~= nil and hp >= prev - 0.001 then     -- not dropping this tick
            pcall(function() bd:AddGeneralHealth(regen) end)
        end
    else
        PZRPG._constResilLastHp = nil
    end
end)
