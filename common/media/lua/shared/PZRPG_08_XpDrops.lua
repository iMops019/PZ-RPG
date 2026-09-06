--[[
    PZ RPG  --  XP drops (floating text)

    A "+N Skill" bubble over the player when a skill gains XP -- OSRS style.
    PZRPG.addXp (PZRPG_03) feeds queueXpDrop(); we accumulate per skill and flush
    one bubble a beat after the last gain, so a ~10-swing tree chop reads as one
    "+15 Woodcutting" rather than ten "+1.5"s.

    Toggle / tune from the -debug console via PZRPG.xpDrops.

    Load order: _08_ -> after Core. Uses OnTick + HaloTextHelper.
]]

PZRPG = PZRPG or {}

PZRPG.xpDrops = PZRPG.xpDrops or {
    enabled     = true,
    FLUSH_TICKS = 150,    -- ticks of no new xp for a skill before its bubble shows.
                          -- Must exceed the gap between repeated gains (a chop swing
                          -- is ~1.5-2s) so a whole tree reads as one "+15", not many.
    MIN_SHOWN   = 1,      -- skip a bubble whose rounded total is below this
}

PZRPG._xpPending = PZRPG._xpPending or {}   -- skillId -> { amount, idle, player }

--- Called by PZRPG.addXp on every gain.
function PZRPG.queueXpDrop(player, skillId, amount)
    if not PZRPG.xpDrops.enabled then return end
    if not player or type(skillId) ~= "string" then return end
    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    local p = PZRPG._xpPending[skillId]
    if not p then p = { amount = 0 }; PZRPG._xpPending[skillId] = p end
    p.amount = p.amount + amount
    p.idle   = 0
    p.player = player
end

local function flush(skillId, p)
    PZRPG._xpPending[skillId] = nil
    local n = math.floor(p.amount + 0.5)
    if n < (PZRPG.xpDrops.MIN_SHOWN or 1) then return end
    local def  = PZRPG.skills and PZRPG.skills[skillId]
    local name = (def and def.name) or skillId
    pcall(function()
        if HaloTextHelper and HaloTextHelper.addText then
            HaloTextHelper.addText(p.player, ("+%d %s"):format(n, name))
        end
    end)
end

PZRPG.hookEvent("OnTick", "xpdrops.tick", function()
    local pending = PZRPG._xpPending
    local flushAt = PZRPG.xpDrops.FLUSH_TICKS or 40
    local due
    for skillId, p in pairs(pending) do
        p.idle = (p.idle or 0) + 1
        if p.idle >= flushAt then
            due = due or {}
            due[#due + 1] = skillId
        end
    end
    if due then
        for _, skillId in ipairs(due) do
            local p = pending[skillId]
            if p then flush(skillId, p) end     -- flush after the pairs() loop
        end
    end
end)
