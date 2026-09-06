--[[
    PZ RPG  --  Crafting  (placeholder)

    Phase 1: registers the skill so it shows on the character sheet. No XP hook
    and no level effect yet (docs/ROADMAP.md, docs/DESIGN.md sec 5). Covers
    leather / wood / bone work (fletching folded in for now).

    Load order: _22_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id       = "crafting",
    name     = "Crafting",
    category = "production",
    order    = 70,
    describe = function(level)
        return "Working leather, wood and bone into gear. Not wired up yet."
    end,
}
