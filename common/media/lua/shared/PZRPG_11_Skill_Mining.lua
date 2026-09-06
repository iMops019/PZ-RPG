--[[
    PZ RPG  --  Mining  (placeholder)

    Phase 1: registers the skill so it shows on the character sheet. No XP hook
    and no level effect yet -- that lands when Mining is built as its own slice
    (docs/ROADMAP.md, docs/DESIGN.md sec 5).

    Load order: _11_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id       = "mining",
    name     = "Mining",
    category = "gathering",
    order    = 20,
    describe = function(level)
        return "Mining boulders with a pickaxe for stone and ore. Not wired up yet."
    end,
}
