--[[
    PZ RPG  --  Foraging  (placeholder)

    Phase 1: registers the skill so it shows on the character sheet. No XP hook
    and no level effect yet (docs/ROADMAP.md, docs/DESIGN.md sec 5).

    Load order: _12_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id       = "foraging",
    name     = "Foraging",
    category = "gathering",
    order    = 30,
    describe = function(level)
        return "Searching the wild for plants, materials and food. Not wired up yet."
    end,
}
