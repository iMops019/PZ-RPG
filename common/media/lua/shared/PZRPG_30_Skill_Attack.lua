--[[
    PZ RPG  --  Attack

    CMB-1: trains on landing melee hits (Events.OnWeaponHitXp, which vanilla
    also uses for Axe/Blunt/etc perk XP). Also trickles vanilla Fitness so the
    end-game Attack + Fitness synergy builds itself (DESIGN.md 3a).

    ATK-EFFECT-1: Attack is the *stamina* combat skill -- the higher your level,
    the less endurance a melee swing costs, so you swing longer and last longer
    in a fight. B42's per-swing endurance drain is Java-side but scales off the
    held weapon's HandWeapon:getEnduranceMod(), so we multiply that down toward
    a floor as Attack rises. Stacks on top of PZRPG_05_Exertion's flat refund --
    by L100 a swing costs a tiny fraction of vanilla, which is the intended
    "Attack + Fitness = end-game monster" payoff.

    Hit chance is deliberately NOT touched -- B42 melee hit chance is a real
    stat (a fresh character with an axe does miss), but tying Attack to survival
    stamina is the design goal, not accuracy.

    Stack-safe: the factor we last multiplied enduranceMod by is stored on the
    weapon's modData (PZRPG_atkEnd). Every tick we divide it back out to recover
    the true base, recompute from the current level, re-apply -- so a level-up,
    a weapon swap, or a -debug reload never compounds it.

    Load order: _30_ -> after the _0N_ Core files.
]]

PZRPG.tuning = PZRPG.tuning or {}
local TUNING = PZRPG.tuning.attack or {
    XP_PER_HIT = 8,       -- Attack xp per character struck in a swing

    -- Endurance cost of a melee swing is scaled by the held weapon's
    -- enduranceMod. We multiply it down toward a floor as Attack rises:
    --   factor = 1 - END_MAX * (lvl/100)^END_EXP
    END_MAX = 0.85,       -- L100: a swing costs ~15% of its normal endurance
    END_EXP = 1.5,        -- ramp: ~11% cut at L25, 30% at L50, 55% at L75
}
PZRPG.tuning.attack = TUNING

--- Multiplier applied to the weapon's enduranceMod at a given Attack level
--- (1.0 = untouched, 0.15 = swing costs 15% of normal).
local function enduranceFactor(level)
    local frac = math.max(0, math.min(1, (level or 1) / 100))
    return 1 - TUNING.END_MAX * (frac ^ TUNING.END_EXP)
end

PZRPG.registerSkill{
    id        = "attack",
    name      = "Attack",
    category  = "combat",
    order     = 80,
    vanillaXp = { Fitness = 0.08 },
    describe  = function(level)
        return ("Landing melee hits. Melee swings cost %d%% less endurance at this level.")
            :format(math.floor((1 - enduranceFactor(level)) * 100 + 0.5))
    end,
}

---------------------------------------------------------------------------
-- XP  (CMB-1)
---------------------------------------------------------------------------

PZRPG.hookEvent("OnWeaponHitXp", "attack.hit", function(owner, weapon, hitObject, damage, hitCount)
    if not owner or owner ~= getSpecificPlayer(0) then return end
    if not weapon or weapon:isRanged() or weapon:getType() == "BareHands" then return end
    hitCount = tonumber(hitCount) or 0
    if hitCount <= 0 then return end

    PZRPG.addXp(owner, "attack", TUNING.XP_PER_HIT * hitCount)
end)

---------------------------------------------------------------------------
-- ATK-EFFECT-1: scale the held melee weapon's swing endurance cost down
---------------------------------------------------------------------------

local function isMeleeWeapon(item)
    if not item then return false end
    local ok, ranged = pcall(function() return item:isRanged() end)
    if not ok or ranged then return false end
    return instanceof(item, "HandWeapon") and item:getType() ~= "BareHands"
end

--- Recover the weapon's true enduranceMod (divide out the factor we last
--- applied), recompute for `level`, re-apply. Idempotent tick to tick.
local function reconcileEndurance(weapon, level)
    local md      = weapon:getModData()
    local applied = tonumber(md.PZRPG_atkEnd)
    if not applied or applied <= 0 then applied = 1 end

    local current = weapon:getEnduranceMod()
    local base    = current / applied
    local factor  = enduranceFactor(level)
    local target  = base * factor

    if math.abs(target - current) > 0.0001 then
        weapon:setEnduranceMod(target)
    end
    if factor ~= 1 or md.PZRPG_atkEnd ~= nil then md.PZRPG_atkEnd = factor end
end

PZRPG.hookEvent("OnPlayerUpdate", "attack.weaponbonus", function(player)
    if not player or player:getPlayerNum() ~= 0 then return end

    local ok, weapon = pcall(function() return player:getPrimaryHandItem() end)
    if not ok or not isMeleeWeapon(weapon) then return end

    pcall(reconcileEndurance, weapon, PZRPG.getLevel(player, "attack"))
end)
