--[[
    PZ RPG  --  Dexterity  (placeholder)

    Phase 1: registers the skill so it shows on the character sheet. No XP hook
    and no level effect yet (docs/ROADMAP.md, docs/DESIGN.md sec 5). One skill
    covering lockpicking / stealth / noise for now -- may split later.

    Load order: _40_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id       = "dexterity",
    name     = "Dexterity",
    category = "dexterity",
    order    = 120,
    describe = function(level)
        return "Lockpicking, stealth and how much noise you make. Not wired up yet."
    end,
}
