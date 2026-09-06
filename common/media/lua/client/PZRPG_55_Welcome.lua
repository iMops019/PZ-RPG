--[[
    PZ RPG  --  First-run welcome flow

    On a brand-new character (profile.created == false), open the character
    sheet on the Profile tab in "welcome" mode: centered, only a "Begin
    Survival" button. The game stays LIVE -- pausing with setGameSpeed(0)
    freezes the input loop the text fields need. No backdrop -- a full-screen
    ISUIElement consumes mouse events and would eat clicks meant for the sheet.

    Sequencing: PZ's own Survival Guide ("how to play") opens on spawn. We wait
    until it (and the main menu, and any modal dialog) is gone before showing
    our welcome, so we don't stack UI on top of a screen the player still has
    to dismiss. A 60s cap means it can never hang.

    An already-created character never sees this again.

    Load order: client _55_ -> after PZRPG_50_Sheet.
]]

local MIN_DELAY_TICKS = 60     -- always let the spawn settle at least this long
local RECHECK_TICKS   = 20     -- while something else is on screen, look again soon
local MAX_WAIT_TICKS  = 3600   -- give up waiting for other UI after ~60s (no deadlock)

local function startWelcome()
    local player = getSpecificPlayer(0)
    if not player then return end
    if PZRPG.isProfileCreated(player) then return end

    local ok, err = pcall(function()
        local sheet = PZRPG_Sheet.get()
        if sheet then sheet:startWelcome() end
    end)
    PZRPG.log(ok and "welcome: opened for new character"
                  or ("welcome: failed to open sheet -- " .. tostring(err)))
end

PZRPG.hookEvent("OnCreatePlayer", "welcome.oncreateplayer", function(playerIndex)
    if playerIndex ~= 0 then return end
    if PZRPG.isProfileCreated(getSpecificPlayer(playerIndex)) then return end
    PZRPG._welcomeCountdown = MIN_DELAY_TICKS
    PZRPG._welcomeWaited    = 0
end)

PZRPG.hookEvent("OnTick", "welcome.tick", function()
    local n = PZRPG._welcomeCountdown
    if n == nil then return end
    if n > 0 then
        PZRPG._welcomeCountdown = n - 1
        return
    end

    PZRPG._welcomeWaited = (PZRPG._welcomeWaited or 0) + RECHECK_TICKS
    if PZRPG_Sheet.otherUIBlocking() and PZRPG._welcomeWaited < MAX_WAIT_TICKS then
        PZRPG._welcomeCountdown = RECHECK_TICKS
        return
    end

    PZRPG._welcomeCountdown = nil
    if PZRPG_Sheet.otherUIBlocking() then
        PZRPG.log("welcome: other UI still up after the wait cap; skipping the welcome this spawn")
        return
    end
    startWelcome()
end)
