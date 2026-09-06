--[[
    PZ RPG  --  Docked-mode auto-open

    If the character's sheet mode is "docked" (the default after the welcome
    flow), reopen the sheet at its saved position a short while after load. In
    "toggle" mode nothing happens until the player presses the sheet keybind.

    Skipped for a brand-new character -- PZRPG_55_Welcome handles that spawn.

    Load order: client _56_ -> after PZRPG_50_Sheet and _55_Welcome.
]]

local OPEN_DELAY_TICKS = 120

PZRPG.hookEvent("OnCreatePlayer", "dock.oncreateplayer", function(playerIndex)
    if playerIndex ~= 0 then return end
    PZRPG._dockCountdown = OPEN_DELAY_TICKS
end)

PZRPG.hookEvent("OnTick", "dock.tick", function()
    local n = PZRPG._dockCountdown
    if n == nil then return end
    if n > 0 then
        PZRPG._dockCountdown = n - 1
        return
    end
    local player = getSpecificPlayer(0)
    if not player then return end
    if not PZRPG.isProfileCreated(player) then PZRPG._dockCountdown = nil; return end  -- welcome will run
    if PZRPG.getProfile(player).sheetMode ~= "docked" then PZRPG._dockCountdown = nil; return end

    -- wait for the Survival Guide / menu / a modal to clear first
    if PZRPG_Sheet.otherUIBlocking() then
        PZRPG._dockCountdown = 20
        return
    end

    PZRPG._dockCountdown = nil
    PZRPG_Sheet.open("profile")   -- pcall-guarded inside
end)
