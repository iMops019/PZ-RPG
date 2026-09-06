--[[
    PZ RPG  --  Strength  (placeholder)

    Phase 1: registers the skill so it shows on the character sheet. No XP hook
    and no level effect yet (docs/ROADMAP.md, docs/DESIGN.md sec 5).

    Load order: _31_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id       = "strength",
    name     = "Strength",
    category = "combat",
    order    = 90,
    describe = function(level)
        return "Melee damage, shove force and carry capacity. Not wired up yet."
    end,
}
