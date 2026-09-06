--[[
    PZ RPG  --  Strength

    CMB-1: trains on melee damage dealt (Events.OnWeaponHitXp). XP wiring only --
    NO level effect yet.

    Load order: _31_ -> after the _0N_ Core files.
]]

local TUNING = {
    XP_PER_DAMAGE = 12,     -- Strength xp per point of melee damage dealt in a swing
}

PZRPG.registerSkill{
    id       = "strength",
    name     = "Strength",
    category = "combat",
    order    = 90,
    describe = function(level)
        return "Melee damage, shove force and carry capacity. Trains as you deal melee damage."
    end,
}

PZRPG.hookEvent("OnWeaponHitXp", "strength.hit", function(owner, weapon, hitObject, damage, hitCount)
    if not owner or owner ~= getSpecificPlayer(0) then return end
    if not weapon or weapon:isRanged() or weapon:getType() == "BareHands" then return end
    if (tonumber(hitCount) or 0) <= 0 then return end
    damage = tonumber(damage) or 0
    if damage <= 0 then return end

    PZRPG.addXp(owner, "strength", TUNING.XP_PER_DAMAGE * damage)
end)
