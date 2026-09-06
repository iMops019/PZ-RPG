--[[
    PZ RPG  --  Attack

    CMB-1: trains on landing melee hits (Events.OnWeaponHitXp, which vanilla
    also uses for Axe/Blunt/etc perk XP). XP wiring only -- NO level effect yet;
    combat effects are the most balance-sensitive and come much later.

    Load order: _30_ -> after the _0N_ Core files.
]]

local TUNING = {
    XP_PER_HIT = 8,        -- Attack xp per character struck in a swing
}

PZRPG.registerSkill{
    id       = "attack",
    name     = "Attack",
    category = "combat",
    order    = 80,
    describe = function(level)
        return "Landing melee hits. Trains every time you connect with a weapon."
    end,
}

PZRPG.hookEvent("OnWeaponHitXp", "attack.hit", function(owner, weapon, hitObject, damage, hitCount)
    if not owner or owner ~= getSpecificPlayer(0) then return end
    if not weapon or weapon:isRanged() or weapon:getType() == "BareHands" then return end
    hitCount = tonumber(hitCount) or 0
    if hitCount <= 0 then return end

    PZRPG.addXp(owner, "attack", TUNING.XP_PER_HIT * hitCount)
end)
