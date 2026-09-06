--[[
    PZ RPG  --  Defense  (placeholder)

    Phase 1: registers the skill so it shows on the character sheet. No XP hook
    and no level effect yet (docs/ROADMAP.md, docs/DESIGN.md sec 5).

    Load order: _32_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id       = "defense",
    name     = "Defense",
    category = "combat",
    order    = 100,
    describe = function(level)
        return "Damage taken, block chance and armour wear. Not wired up yet."
    end,
}
