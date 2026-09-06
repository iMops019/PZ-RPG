--[[
    PZ RPG  --  Constitution

    CMB-1: "all combat + surviving hits". Trains from body-health drops (like
    Defense, at half the rate) plus a flat trickle on every melee hit landed.

    CONST-EFFECT-1: higher Constitution = a chance to shrug off the Knox
    infection the instant a bite / scratch would transmit it. Vanilla still
    decides whether infection happens; we only get a save right as it lands
    (not a cure for an established infection). Kept conservative -- a maxed
    character still dies to most bites.

    Load order: _33_ -> after the _0N_ Core files.
]]

local TUNING = {
    -- XP
    XP_PER_HP  = 125,     -- half of Defense's rate
    MIN_DROP   = 0.5,
    MAX_DROP   = 15,
    XP_PER_HIT = 2,       -- flat trickle per character struck in melee

    -- Infection resistance (chance 0..1 to negate transmission at a given level)
    --   resist = COEF * (level / 100) ^ EXP
    SCRATCH_COEF = 0.55, SCRATCH_EXP = 0.75,   -- L50 ~0.33, L100 0.55
    BITE_COEF    = 0.20, BITE_EXP    = 0.85,   -- L50 ~0.11, L100 0.20
}

PZRPG.registerSkill{
    id       = "constitution",
    name     = "Constitution",
    category = "combat",
    order    = 110,
    describe = function(level)
        local s = math.floor(TUNING.SCRATCH_COEF * ((level / 100) ^ TUNING.SCRATCH_EXP) * 100 + 0.5)
        local b = math.floor(TUNING.BITE_COEF    * ((level / 100) ^ TUNING.BITE_EXP)    * 100 + 0.5)
        return ("Effective health & injury resistance. Shrug-off chance: scratch %d%%, bite %d%%."):format(s, b)
    end,
}

---------------------------------------------------------------------------
-- XP
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
