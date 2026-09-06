--[[
    PZ RPG  --  Exertion softening  (docs/DESIGN.md sec 3a)

    Vanilla PZ drains endurance so fast that physical work is "chop once, sit
    down". This softens it: every player-update tick, if the player's endurance
    dropped since last tick and they are NOT running/sprinting, refund a
    fraction of the drop. Net effect -- work (chopping, sawing, digging, mining,
    melee) costs a fraction of the vanilla endurance hit, while running is left
    alone so you can't sprint forever.

    Same idea is available for Fatigue (the sleepiness stat) but OFF by default
    -- fatigue is mostly time-driven, not exertion.

    All knobs live in PZRPG.exertion -- one table, live-tunable from the -debug
    Lua console, later a sandbox option.

    Load order: _05_ -> after Core. Hooks OnPlayerUpdate (SP / local player).
]]

PZRPG = PZRPG or {}

PZRPG.exertion = PZRPG.exertion or {
    -- Fraction of each endurance DROP that is handed back.
    --   0.00 = vanilla     0.65 = work is ~35% as tiring     1.00 = no cost
    ENDURANCE_REFUND = 0.65,

    -- Same for Fatigue rises. 0 = vanilla (recommended -- fatigue is a sleep
    -- clock, not an exertion cost).
    FATIGUE_REFUND = 0.00,

    -- Never refund while running / sprinting (keeps sprinting finite).
    SKIP_WHILE_RUNNING = true,

    -- Ignore a single-tick change larger than this (a scripted / injury drain,
    -- not incidental exertion). 0 = no cap.
    MAX_TICK_DELTA = 0.00,
}

--- Debug: print the current knobs. Call from the -debug console: PZRPG.exertion.dump()
function PZRPG.exertion.dump()
    local t = PZRPG.exertion
    PZRPG.log(("exertion: ENDURANCE_REFUND=%.2f FATIGUE_REFUND=%.2f skipRun=%s maxDelta=%.3f")
        :format(t.ENDURANCE_REFUND, t.FATIGUE_REFUND, tostring(t.SKIP_WHILE_RUNNING), t.MAX_TICK_DELTA))
end

PZRPG._exState = PZRPG._exState or {}      -- playerNum -> { endurance = <n>, fatigue = <n> }

--- Refund part of an exertion change on one stat.
---   exertionDir = -1 : exerting LOWERS the stat (endurance) -> we add back
---   exertionDir = +1 : exerting RAISES the stat (fatigue)   -> we take back
local function soften(stats, statEnum, prev, refund, maxDelta, exertionDir)
    local cur = stats:get(statEnum)
    if prev == nil or refund <= 0 then return cur end

    local exertion = (cur - prev) * exertionDir      -- > 0 only when the player exerted
    if exertion <= 0 then return cur end
    if maxDelta > 0 and exertion > maxDelta then return cur end

    local adjust = -exertionDir * (exertion * refund)   -- push the stat back toward `prev`
    stats:add(statEnum, adjust)
    return math.max(0, math.min(1, cur + adjust))
end

PZRPG.hookEvent("OnPlayerUpdate", "exertion.update", function(player)
    if not player then return end

    local t = PZRPG.exertion
    if t.ENDURANCE_REFUND <= 0 and t.FATIGUE_REFUND <= 0 then return end   -- fully off

    local num   = player:getPlayerNum() or 0
    local stats = player:getStats()
    if not stats then return end

    local st = PZRPG._exState[num]
    if not st then st = {}; PZRPG._exState[num] = st end

    -- While running we still track the value (so we don't "bank" the run drain
    -- and refund it on the next still frame) but we don't refund it.
    local running = t.SKIP_WHILE_RUNNING and (player:isRunning() or player:isSprinting())
    local paused  = isGamePaused and isGamePaused()

    if running or paused then
        st.endurance = stats:get(CharacterStat.ENDURANCE)
        st.fatigue   = stats:get(CharacterStat.FATIGUE)
        return
    end

    st.endurance = soften(stats, CharacterStat.ENDURANCE, st.endurance,
        t.ENDURANCE_REFUND, t.MAX_TICK_DELTA, -1)   -- exertion lowers endurance
    st.fatigue = soften(stats, CharacterStat.FATIGUE, st.fatigue,
        t.FATIGUE_REFUND, t.MAX_TICK_DELTA, 1)      -- exertion raises fatigue
end)

PZRPG.hookEvent("OnGameBoot", "exertion.boot", function()
    if getDebug and getDebug() then PZRPG.exertion.dump() end
end)
