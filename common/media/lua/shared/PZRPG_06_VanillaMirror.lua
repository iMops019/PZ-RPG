--[[
    PZ RPG  --  Vanilla-perk XP mirror  (docs/DESIGN.md sec 3a)

    Many PZ RPG skills map onto a vanilla perk -- vanilla already detects the
    activity (cooking, fishing, foraging, smithing, carpentry, ...) and awards
    that perk XP. We hook Events.AddXP and mirror a proportion into our skill:

        <skill def>.mirrorVanilla = { Cooking = 1.0, MetalWelding = 0.7, ... }
                                     -- vanilla perk name -> relative weight

    effective PZ RPG xp  =  vanillaAmount * weight * PZRPG.mirror.GLOBAL_MULT

    Our own vanillaXp feed (PZRPG_03) bumps PZRPG._vanillaFeedDepth while it
    runs, and this hook ignores those, so Woodcutting -> Fitness can't loop back.

    Load order: _06_ -> after Core. The hook reads PZRPG.skills live at event
    time, so it doesn't matter that skill files load after this.
]]

PZRPG = PZRPG or {}

PZRPG.mirror = PZRPG.mirror or {
    -- One dial for how fast every mirrored skill climbs relative to its vanilla
    -- perk. Per-skill relative weights live in each skill def. Placeholder --
    -- retune in-game (vanilla perks are 0-10 with small XP totals; our curve is
    -- 1-100 with huge totals, so this has to scale the signal UP).
    GLOBAL_MULT = 5.0,
}

--- Debug: PZRPG.mirror.dump()
function PZRPG.mirror.dump()
    PZRPG.log(("mirror: GLOBAL_MULT=%.1f"):format(PZRPG.mirror.GLOBAL_MULT))
    for id, def in pairs(PZRPG.skills or {}) do
        if type(def.mirrorVanilla) == "table" then
            local parts = {}
            for perk, w in pairs(def.mirrorVanilla) do parts[#parts + 1] = perk .. "*" .. w end
            PZRPG.log(("  %s <- %s"):format(id, table.concat(parts, ", ")))
        end
    end
end

PZRPG.hookEvent("AddXP", "mirror.addxp", function(owner, perk, amount)
    if (PZRPG._vanillaFeedDepth or 0) > 0 then return end       -- our own feed, not real activity
    if not perk or owner ~= getSpecificPlayer(0) then return end

    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    local ok, perkName = pcall(function() return PerkFactory.getPerkName(perk) end)
    if not ok or type(perkName) ~= "string" or perkName == "" then return end

    local mult = PZRPG.mirror.GLOBAL_MULT
    for skillId, def in pairs(PZRPG.skills or {}) do
        local mv = def.mirrorVanilla
        local weight = (type(mv) == "table") and mv[perkName] or nil
        if weight and weight > 0 then
            PZRPG.addXp(owner, skillId, amount * weight * mult)
        end
    end
end)

PZRPG.hookEvent("OnGameBoot", "mirror.boot", function()
    if getDebug and getDebug() then PZRPG.mirror.dump() end
end)
