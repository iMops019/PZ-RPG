--[[
    PZ RPG  --  Attack  (placeholder)

    Phase 1: registers the skill so it shows on the character sheet. No XP hook
    and no level effect yet (docs/ROADMAP.md, docs/DESIGN.md sec 5). Combat
    skills are the most balance-sensitive -- kept modest so PZ still kills you.

    Load order: _30_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id       = "attack",
    name     = "Attack",
    category = "combat",
    order    = 80,
    describe = function(level)
        return "Landing melee hits -- accuracy and weapon proficiency. Not wired up yet."
    end,
}
