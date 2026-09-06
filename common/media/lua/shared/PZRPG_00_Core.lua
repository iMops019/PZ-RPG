--[[
    PZ RPG  --  Core (bootstrap stub).

    Owns the PZRPG namespace and the logger. Everything else in the mod loads
    after this (the _NN_ prefix guarantees it) and calls into PZRPG.

    Phase 0: this only proves B42 discovers and runs the mod. The real Core
    (XP curve, save layer, skill registry, addXp) lands in Phase 1 - see
    docs/ROADMAP.md.
]]

PZRPG = PZRPG or {}

PZRPG.VERSION      = "0.0.1"
PZRPG.SAVE_VERSION = 1              -- bumped when the getModData().PZRPG shape changes

--- Prefixed print so console.txt / the debug console tell one story.
function PZRPG.log(msg)
    print("[PZ RPG] " .. tostring(msg))
end

-- Reload-safe Events registration. Skill modules will register through this so a
-- -debug hot-reload doesn't stack duplicate handlers. Kept here from day one.
PZRPG._handlers = PZRPG._handlers or {}

function PZRPG.hookEvent(eventName, key, fn)
    local event = Events[eventName]
    if not event then
        PZRPG.log("hookEvent: unknown event '" .. tostring(eventName) .. "'")
        return
    end
    local prev = PZRPG._handlers[key]
    if prev and Events[prev.event] then
        Events[prev.event].Remove(prev.fn)
    end
    event.Add(fn)
    PZRPG._handlers[key] = { event = eventName, fn = fn }
end

PZRPG.log("Core loaded (v" .. PZRPG.VERSION .. ")")

PZRPG.hookEvent("OnGameBoot", "core.boot", function()
    PZRPG.log("OnGameBoot - mod discovered and running.")
end)
