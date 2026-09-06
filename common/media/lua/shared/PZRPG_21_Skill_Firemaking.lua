--[[
    PZ RPG  --  Firemaking  (placeholder)

    Phase 1: registers the skill so it shows on the character sheet. No XP hook
    and no level effect yet (docs/ROADMAP.md, docs/DESIGN.md sec 5).

    Load order: _21_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id       = "firemaking",
    name     = "Firemaking",
    category = "production",
    order    = 60,
    describe = function(level)
        return "Lighting and tending fires, making charcoal. Not wired up yet."
    end,
}
