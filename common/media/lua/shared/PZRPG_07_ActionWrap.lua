--[[
    PZ RPG  --  Timed-action wrapper util

        PZRPG.wrapAction(ActionClass, "methodName", fn)

    Wraps ActionClass.methodName so `fn(actionInstance, ...)` runs right AFTER
    the original each time it's called. Used to bolt PZ RPG behaviour onto
    vanilla timed actions (Firemaking, Woodcutting chop-speed, ...).

    Reload-safe: the true original is stashed once on the class
    (`cls.__pzrpgOrig[method]`); every load re-points the method at a fresh
    wrapper that calls that stored original -- so a -debug reload never stacks
    wrappers, and edits to `fn` take effect.

    `fn` is always pcall'd -- a bug in our hook can't break the vanilla action.

    Load order: _07_ -> after Core, before any skill file that wraps an action.
]]

PZRPG = PZRPG or {}

function PZRPG.wrapAction(cls, method, fn)
    if type(cls) ~= "table" or type(method) ~= "string" or type(fn) ~= "function" then
        PZRPG.log("wrapAction: bad args (" .. tostring(method) .. ")")
        return false
    end
    if type(cls[method]) ~= "function" then
        PZRPG.log("wrapAction: '" .. method .. "' is not a function on this class -- skipped")
        return false
    end

    cls.__pzrpgOrig = cls.__pzrpgOrig or {}
    if cls.__pzrpgOrig[method] == nil then
        cls.__pzrpgOrig[method] = cls[method]      -- the real original, captured once
    end
    local orig = cls.__pzrpgOrig[method]

    cls[method] = function(self, ...)
        local r = orig(self, ...)
        pcall(fn, self, ...)
        return r
    end
    return true
end
