--[[
    PZ RPG  --  Smithing  (placeholder)

    Phase 1: registers the skill so it shows on the character sheet. No XP hook
    and no level effect yet (docs/ROADMAP.md, docs/DESIGN.md sec 5). Smithing is
    the "unlock tree" skill -- metal recipes gated by level.

    Load order: _20_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id       = "smithing",
    name     = "Smithing",
    category = "production",
    order    = 50,
    describe = function(level)
        return "Smelting ore and forging metal gear at a station. Not wired up yet."
    end,
}
