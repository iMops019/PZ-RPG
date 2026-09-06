--[[
    PZ RPG  --  Fishing  (placeholder)

    Phase 1: registers the skill so it shows on the character sheet. No XP hook
    and no level effect yet (docs/ROADMAP.md, docs/DESIGN.md sec 5).

    Load order: _13_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id       = "fishing",
    name     = "Fishing",
    category = "gathering",
    order    = 40,
    describe = function(level)
        return "Fishing rivers and lakes for food. Not wired up yet."
    end,
}
