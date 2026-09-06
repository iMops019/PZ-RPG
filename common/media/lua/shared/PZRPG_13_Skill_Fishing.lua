--[[
    PZ RPG  --  Fishing

    MIRROR-1: trains off vanilla Fishing XP via PZRPG_06_VanillaMirror. No level
    effect yet (bite rate / catch size come later).

    Load order: _13_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id            = "fishing",
    name          = "Fishing",
    category      = "gathering",
    order         = 40,
    mirrorVanilla = { Fishing = 1.0 },
    describe      = function(level)
        return "Fishing rivers and lakes. Trains as you fish."
    end,
}
