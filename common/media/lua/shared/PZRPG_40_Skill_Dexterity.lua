--[[
    PZ RPG  --  Dexterity

    DEX-1: the stealth / quiet-movement side mirrors vanilla Sneak + Lightfoot +
    Nimble via PZRPG_06_VanillaMirror. Lockpicking has no clean B42 hook yet --
    folded in later. No level effect yet.

    One skill for now; may split into Lockpicking / Stealth / Noise later.

    Load order: _40_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id            = "dexterity",
    name          = "Dexterity",
    category      = "dexterity",
    order         = 120,
    mirrorVanilla = { Sneak = 1.0, Lightfoot = 0.6, Nimble = 0.6 },
    describe      = function(level)
        return "Stealth and quiet movement. Trains as you sneak. (Lockpicking: later.)"
    end,
}
