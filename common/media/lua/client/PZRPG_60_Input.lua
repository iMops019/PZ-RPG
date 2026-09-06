--[[
    PZ RPG  --  Keybind: open/close the character sheet

    Registers "[PZ RPG] Character Sheet" (default K) in the vanilla key-binding
    list and toggles the sheet on press. OnKeyStartPressed is skipped by the
    engine while a text field has focus, so K won't fire while editing the sheet.

    NOTE: K (keycode 37) is also PZ's "Display FPS" debug-overlay bind on this
    dev machine, so pressing K toggles both until you clear one in
    Options > Key Bindings. In a normal (non -debug) install K is free.

    addKeyBinding only sets the DEFAULT for a new binding name -- once the row
    exists in keysB42.ini (after the player visits Options) that saved value
    wins, so a later change to this default has no effect on that machine.

    Load order: client _60_ -> after PZRPG_50_Sheet.
]]

local BINDING = "[PZ RPG] Character Sheet"

if not PZRPG._keybindRegistered then
    local ok, err = pcall(function()
        getCore():addKeyBinding(BINDING, Keyboard.KEY_K, 0, false, false, false)
    end)
    PZRPG._keybindRegistered = ok
    if ok then
        local k = pcall(function() return getCore():getKey(BINDING) end) and getCore():getKey(BINDING) or "?"
        PZRPG.log(("input: keybind '%s' -> key %s (rebind in Options if K clashes)"):format(BINDING, tostring(k)))
    else
        PZRPG.log("input: addKeyBinding failed -- " .. tostring(err))
    end
end

PZRPG.hookEvent("OnKeyStartPressed", "input.togglesheet", function(key)
    local bound = getCore():getKey(BINDING)
    if not bound or bound <= 0 or key ~= bound then return end
    if not getSpecificPlayer(0) then return end
    PZRPG_Sheet.toggle()
end)
