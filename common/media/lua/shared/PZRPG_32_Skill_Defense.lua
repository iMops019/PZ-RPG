--[[
    PZ RPG  --  Defense

    CMB-1: no vanilla "got hit" event exists, so we watch overall body health
    each player-update tick -- a real drop (took damage and survived) trains
    Defense. XP wiring only -- NO level effect yet.

    Small drops (hunger / moodle noise) are ignored; a huge single-tick drop
    (death / debug) is ignored too.

    Load order: _32_ -> after the _0N_ Core files.
]]

local TUNING = {
    XP_PER_HP = 250,      -- Defense xp per point of body health lost to damage
    MIN_DROP  = 0.5,      -- ignore drops smaller than this (not real damage)
    MAX_DROP  = 15,       -- ignore drops bigger than this in one tick (death / debug)
}

PZRPG.registerSkill{
    id       = "defense",
    name     = "Defense",
    category = "combat",
    order    = 100,
    describe = function(level)
        return "Damage taken, block chance and armour wear. Trains when you take a hit and live."
    end,
}

PZRPG.hookEvent("OnPlayerUpdate", "defense.update", function(player)
    if not player or player:getPlayerNum() ~= 0 then return end

    local ok, hp = pcall(function() return player:getBodyDamage():getHealth() end)
    if not ok or type(hp) ~= "number" then return end

    local prev = PZRPG._defenseLastHp
    PZRPG._defenseLastHp = hp
    if prev == nil then return end

    local drop = prev - hp
    if drop < TUNING.MIN_DROP or drop > TUNING.MAX_DROP then return end

    PZRPG.addXp(player, "defense", drop * TUNING.XP_PER_HP)
end)
