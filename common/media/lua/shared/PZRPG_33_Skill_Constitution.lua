--[[
    PZ RPG  --  Constitution  (placeholder)

    Phase 1: registers the skill so it shows on the character sheet. No XP hook
    and no level effect yet (docs/ROADMAP.md, docs/DESIGN.md sec 5). Kept modest
    -- PZ death is the point.

    Load order: _33_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id       = "constitution",
    name     = "Constitution",
    category = "combat",
    order    = 110,
    describe = function(level)
        return "Effective health and injury resistance. Not wired up yet."
    end,
}
