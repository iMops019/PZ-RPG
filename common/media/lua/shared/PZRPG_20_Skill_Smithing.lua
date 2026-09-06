--[[
    PZ RPG  --  Smithing

    MIRROR-1: trains off vanilla Blacksmith + MetalWelding XP via
    PZRPG_06_VanillaMirror. No level effect yet -- the "unlock tree of metal
    items" and material-waste / durability bonuses come later.

    Load order: _20_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id            = "smithing",
    name          = "Smithing",
    category      = "production",
    order         = 50,
    mirrorVanilla = { Blacksmith = 1.0, MetalWelding = 0.7 },
    describe      = function(level)
        return "Smelting ore and forging metal. Trains as you smith or weld."
    end,
}
