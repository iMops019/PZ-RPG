--[[
    PZ RPG  --  Foraging

    MIRROR-1: trains off vanilla PlantScavenging XP via PZRPG_06_VanillaMirror.
    No level effect yet (rare-find chance / more per pick come later).

    Load order: _12_ -> after the _0N_ Core files.
]]

PZRPG.registerSkill{
    id            = "foraging",
    name          = "Foraging",
    category      = "gathering",
    order         = 30,
    mirrorVanilla = { PlantScavenging = 1.0 },
    vanillaXp     = { Fitness = 0.05 },     -- a lot of walking
    describe      = function(level)
        return "Searching the wild for plants, materials and food. Trains as you forage."
    end,
}
