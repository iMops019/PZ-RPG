--[[
    PZ RPG  --  Cooking

    MIRROR-1: trains off vanilla Cooking XP via PZRPG_06_VanillaMirror. No level
    effect yet (better nutrition / less waste / safer results come later).

    Load order: _23_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id            = "cooking",
    name          = "Cooking",
    category      = "production",
    order         = 75,
    mirrorVanilla = { Cooking = 1.0 },
    describe      = function(level)
        return "Preparing food. Trains as you cook. (Bonuses to nutrition & waste: later.)"
    end,
}
