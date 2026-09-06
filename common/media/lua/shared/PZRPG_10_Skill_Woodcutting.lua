--[[
    PZ RPG  --  Woodcutting  (placeholder)

    Phase 1: this only registers the skill, so the registry, the XP accessors,
    and the character sheet have one real skill to exercise. No XP hook and no
    level effect yet -- chopping a tree does nothing for Woodcutting until
    Phase 2 (docs/ROADMAP.md).

    Load order: _10_ -> after all the _0N_ Core files.
]]

PZRPG.registerSkill{
    id       = "woodcutting",
    name     = "Woodcutting",
    category = "gathering",
    order    = 10,
    describe = function(level)
        -- Phase 2 replaces this with the real chop-speed / yield blurb.
        return "Chopping trees. No bonus yet - Phase 2."
    end,
}
