--[[
    PZ RPG  --  Crafting

    MIRROR-1: trains off vanilla Woodwork + Tailoring + Carving XP via
    PZRPG_06_VanillaMirror. No level effect yet (recipe unlocks / quality come
    later). Fletching folded in here for now.

    Load order: _22_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id            = "crafting",
    name          = "Crafting",
    category      = "production",
    order         = 70,
    mirrorVanilla = { Woodwork = 0.7, Tailoring = 0.7, Carving = 0.8 },
    describe      = function(level)
        return "Working wood, leather and bone. Trains as you craft."
    end,
}
