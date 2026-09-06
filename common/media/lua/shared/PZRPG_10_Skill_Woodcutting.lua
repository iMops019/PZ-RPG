--[[
    PZ RPG  --  Woodcutting  (placeholder)

    Phase 1: registers the skill so it shows on the character sheet. No XP hook
    and no level effect yet -- chopping a tree does nothing for Woodcutting
    until it's built as its own slice (docs/ROADMAP.md, docs/DESIGN.md sec 5).

    Load order: _10_ -> after all the _0N_ Core files.
]]

PZRPG.registerSkill{
    id       = "woodcutting",
    name     = "Woodcutting",
    category = "gathering",
    order    = 10,
    describe = function(level)
        return "Chopping trees faster, with a small yield bonus. Not wired up yet."
    end,
}
