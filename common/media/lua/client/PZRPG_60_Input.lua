--[[
    PZ RPG  --  Key bindings

    Adds rows to Options > Key Bindings > "[PZ RPG]".  Default: K.

    Uses the vanilla `keyBinding` table (the same way A Little Help does) so the
    row shows up under its own category and is rebindable in the options screen.
    The keybind table is read at startup, so changing a binding needs a real
    game restart -- this file is not part of the hot-reload story, but it is
    written to be safe to re-run.

    Load order: client _60_ -> after PZRPG_50_Sheet.
]]

local BINDING = "PZ RPG: Character Sheet"

--- Insert one keyBinding row unless one with this value already exists
--- (a reload / re-scan would otherwise stack duplicates).
local function ensureBinding(value, key)
    for _, row in ipairs(keyBinding) do
        if row.value == value then return end
    end
    table.insert(keyBinding, { value = value, key = key })
end

if keyBinding then
    ensureBinding("[PZ RPG]", nil)                    -- category header, no key
    ensureBinding(BINDING, Keyboard.KEY_K)            -- default K
end

PZRPG.hookEvent("OnKeyStartPressed", "input.togglesheet", function(key)
    local bound = getCore():getKey(BINDING)
    if not bound or bound <= 0 or key ~= bound then return end
    if not getSpecificPlayer(0) then return end
    PZRPG_Sheet.toggle()
end)
