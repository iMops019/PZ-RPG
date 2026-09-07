--[[
    PZ RPG  --  Strength

    CMB-1: trains on melee damage dealt (Events.OnWeaponHitXp). Also trickles
    vanilla Strength (DESIGN.md 3a) -- vanilla already gives a little Strength
    perk xp per melee hit, we add a bit more.

    STR-EFFECT-1: raw melee damage. The held weapon's min/max damage is scaled
    up by a multiplier that grows with level:
        factor = 1 + DMG_MAX * (lvl/100)^DMG_EXP
    ~+4% at L25, +11% at L50, +20% at L75, +30% at L100. Strength is an
    offensive skill so this is "moderate" -- more than the conservative
    defensive skills, less than Attack+Fitness's near-free swings.

    B42 rolls swing damage off the HandWeapon instance's getMinDamage /
    getMaxDamage; there is no Lua hook in CombatManager's damage calc. Same
    stack-safe reconcile as Attack: the factor we last multiplied by is stored
    on the weapon's modData (PZRPG_strDmg); each tick we divide it back out to
    recover the true base (whatever condition / other mods produced), recompute
    from the current level, re-apply.

    Carry capacity / shove force are STR-EFFECT-2 -- B42's carry-weight recalc
    path still needs pinning down before we touch it safely.

    Load order: _31_ -> after the _0N_ Core files.
]]

PZRPG.tuning = PZRPG.tuning or {}
local TUNING = PZRPG.tuning.strength or {
    XP_PER_DAMAGE = 12,   -- Strength xp per point of melee damage dealt in a swing

    -- Melee damage: weapon min/max scaled by 1 + DMG_MAX*(lvl/100)^DMG_EXP.
    DMG_MAX = 0.30,       -- +30% melee damage at L100
    DMG_EXP = 1.4,        -- ramp: ~+4% at L25, +11% at L50, +20% at L75
}
PZRPG.tuning.strength = TUNING

--- Fractional melee-damage bonus at a given Strength level (0 = none).
local function damageBonus(level)
    local frac = math.max(0, math.min(1, (level or 1) / 100))
    return TUNING.DMG_MAX * (frac ^ TUNING.DMG_EXP)
end

PZRPG.registerSkill{
    id        = "strength",
    name      = "Strength",
    category  = "combat",
    order     = 90,
    vanillaXp = { Strength = 0.06 },
    describe  = function(level)
        return ("Melee damage (carry capacity & shove: STR-EFFECT-2). +%d%% melee damage at this level.")
            :format(math.floor(damageBonus(level) * 100 + 0.5))
    end,
}

---------------------------------------------------------------------------
-- XP  (CMB-1)
---------------------------------------------------------------------------

PZRPG.hookEvent("OnWeaponHitXp", "strength.hit", function(owner, weapon, hitObject, damage, hitCount)
    if not owner or owner ~= getSpecificPlayer(0) then return end
    if not weapon or weapon:isRanged() or weapon:getType() == "BareHands" then return end
    if (tonumber(hitCount) or 0) <= 0 then return end
    damage = tonumber(damage) or 0
    if damage <= 0 then return end

    PZRPG.addXp(owner, "strength", TUNING.XP_PER_DAMAGE * damage)
end)

---------------------------------------------------------------------------
-- STR-EFFECT-1: scale the held melee weapon's damage up
---------------------------------------------------------------------------

local function isMeleeWeapon(item)
    if not item then return false end
    local ok, ranged = pcall(function() return item:isRanged() end)
    if not ok or ranged then return false end
    return instanceof(item, "HandWeapon") and item:getType() ~= "BareHands"
end

--- Recover the weapon's true min/max damage (divide out the factor we last
--- applied), recompute for `level`, re-apply. Idempotent tick to tick.
local function reconcileDamage(weapon, level)
    local md      = weapon:getModData()
    local applied = tonumber(md.PZRPG_strDmg)
    if not applied or applied <= 0 then applied = 1 end

    -- `strong` buff (COOK-4b meals) adds flat to the level bonus
    local factor = 1 + damageBonus(level) + ((PZRPG.buffs and PZRPG.buffs.get("strong")) or 0)
    local curMin = weapon:getMinDamage()
    local curMax = weapon:getMaxDamage()
    local tMin   = (curMin / applied) * factor
    local tMax   = (curMax / applied) * factor

    if math.abs(tMin - curMin) > 0.0001 then weapon:setMinDamage(tMin) end
    if math.abs(tMax - curMax) > 0.0001 then weapon:setMaxDamage(tMax) end
    if factor ~= 1 or md.PZRPG_strDmg ~= nil then md.PZRPG_strDmg = factor end
end

PZRPG.hookEvent("OnPlayerUpdate", "strength.weaponbonus", function(player)
    if not player or player:getPlayerNum() ~= 0 then return end

    local ok, weapon = pcall(function() return player:getPrimaryHandItem() end)
    if not ok or not isMeleeWeapon(weapon) then return end

    pcall(reconcileDamage, weapon, PZRPG.getLevel(player, "strength"))
end)
