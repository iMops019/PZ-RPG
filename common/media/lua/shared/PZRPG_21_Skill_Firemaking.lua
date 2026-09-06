--[[
    PZ RPG  --  Firemaking

    FIRE-1: no vanilla perk maps to this, so we wrap the campfire light / fuel
    timed actions (via PZRPG.wrapAction) and grant XP on success.
      - a fire catches                     -> LIGHT_SUCCESS
      - kindling breaks without catching   -> LIGHT_ATTEMPT
      - feeding fuel to an existing fire   -> ADD_FUEL

    No level effect yet (light speed / fuel efficiency come later).

    Load order: _21_ -> after Core (_00-07); the vanilla Camping actions live
    under shared/Camping/ which loads before this (C < P).
]]

local TUNING = {
    LIGHT_SUCCESS = 150,   -- a campfire catches
    LIGHT_ATTEMPT = 20,    -- kindling broke without catching
    ADD_FUEL      = 15,    -- feeding an existing fire
}

PZRPG.registerSkill{
    id       = "firemaking",
    name     = "Firemaking",
    category = "production",
    order    = 60,
    describe = function(level)
        return "Lighting and tending fires. Trains when you light or feed a campfire."
    end,
}

local function isLocalPlayer(character)
    return character ~= nil and character == getSpecificPlayer(0)
end

--- The lua campfire object for an action's target square (client system;
--- resolved at runtime, so load order with client lua doesn't matter).
local function campfireIsLit(action)
    if not action or not action.campfire then return false end
    local c = action.campfire
    local ok, lua = pcall(function()
        return CCampfireSystem.instance:getLuaObjectAt(c.x, c.y, c.z)
    end)
    return (ok and lua and lua.isLit) and true or false
end

-- Kindle: re-queues itself until the fire lights OR the kindling breaks.
local function onKindlePerform(action)
    if not isLocalPlayer(action.character) then return end
    if campfireIsLit(action) then
        PZRPG.addXp(action.character, "firemaking", TUNING.LIGHT_SUCCESS)
    elseif action.item == nil then          -- kindling broke (kindle nils .item)
        PZRPG.addXp(action.character, "firemaking", TUNING.LIGHT_ATTEMPT)
    end
    -- else: still trying, action re-queued -> no xp
end

-- Literature / petrol: always succeed on perform.
local function onLightPerform(action)
    if not isLocalPlayer(action.character) then return end
    PZRPG.addXp(action.character, "firemaking", TUNING.LIGHT_SUCCESS)
end

local function onAddFuelPerform(action)
    if not isLocalPlayer(action.character) then return end
    PZRPG.addXp(action.character, "firemaking", TUNING.ADD_FUEL)
end

local function install()
    if ISLightFromKindle     then PZRPG.wrapAction(ISLightFromKindle,     "perform", onKindlePerform) end
    if ISLightFromLiterature then PZRPG.wrapAction(ISLightFromLiterature, "perform", onLightPerform) end
    if ISLightFromPetrol     then PZRPG.wrapAction(ISLightFromPetrol,     "perform", onLightPerform) end
    if ISAddFuelAction       then PZRPG.wrapAction(ISAddFuelAction,       "perform", onAddFuelPerform) end
end

install()                                                 -- -debug reload / late-load
PZRPG.hookEvent("OnGameBoot", "firemaking.wrap", install)  -- first boot (load order)
