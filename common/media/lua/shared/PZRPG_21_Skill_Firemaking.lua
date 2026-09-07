--[[
    PZ RPG  --  Firemaking

    FIRE-1: no vanilla perk maps to this, so we wrap the campfire light / fuel
    timed actions (via PZRPG.wrapAction) and grant XP on success.
      - a fire catches                     -> XP_LIGHT_SUCCESS
      - kindling breaks without catching   -> XP_LIGHT_ATTEMPT
      - feeding fuel to an existing fire   -> XP_ADD_FUEL

    FIRE-2: the physical system is the vanilla 3-stone campfire -- no new object.
    Two vanilla globals are re-pointed on OnGameBoot (idempotent):
      - getCampingFuelMax()             -> our sandbox slider (default 12h),
                                          overriding vanilla's MaximumFireFuelHours
      - SCampfireSystem:lowerFuelAmount -> drains fuel at TUNING.BURN_RATE per
                                          real minute instead of a flat 1 (a
                                          flat, *non-level* efficiency rebalance,
                                          same spirit as PZRPG_05_Exertion)

    Firemaking *level* does nothing here yet -- FIRE-3 makes level scale the
    kindle ignition chance (and only that). "Fires last longer" is handled by
    the flat BURN_RATE + the raised cap, not by level.

    Load order: _21_ -> after Core (_00-07). Vanilla Camping actions load under
    shared/Camping/ (before us); server/Camping/*.lua defines getCampingFuelMax /
    SCampfireSystem and loads *after* shared -- hence both re-points wait for
    OnGameBoot. (MP: server-authoritative burn already runs server-side; the cap
    override also runs in the client context for the add-fuel menu preview.)
]]

PZRPG.tuning = PZRPG.tuning or {}
PZRPG.tuning.firemaking = PZRPG.tuning.firemaking or {
    XP_LIGHT_SUCCESS = 40,    -- a campfire catches
    XP_LIGHT_ATTEMPT = 8,     -- kindling broke without catching
    XP_ADD_FUEL      = 10,    -- feeding an existing fire

    FUEL_MAX_HOURS = 12,      -- fallback if the sandbox option isn't readable
    BURN_RATE      = 0.75,    -- fuel-minutes burned per real minute per lit fire
                             -- (1.0 = vanilla; 0.75 => a 6h log lasts ~8h)
}
local TUNING = PZRPG.tuning.firemaking

PZRPG.registerSkill{
    id       = "firemaking",
    name     = "Firemaking",
    category = "production",
    order    = 60,
    describe = function(level)
        return "Lighting and tending fires. Trains when you light or feed a campfire. "
            .. "(Level scales ignition odds: FIRE-3.)"
    end,
}

local function isLocalPlayer(character)
    return character ~= nil and character == getSpecificPlayer(0)
end

---------------------------------------------------------------------------
-- FIRE-1: XP on the vanilla light / fuel actions
---------------------------------------------------------------------------

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
        PZRPG.addXp(action.character, "firemaking", TUNING.XP_LIGHT_SUCCESS)
    elseif action.item == nil then          -- kindling broke (kindle nils .item)
        PZRPG.addXp(action.character, "firemaking", TUNING.XP_LIGHT_ATTEMPT)
    end
    -- else: still trying, action re-queued -> no xp
end

-- Literature / petrol: always succeed on perform.
local function onLightPerform(action)
    if not isLocalPlayer(action.character) then return end
    PZRPG.addXp(action.character, "firemaking", TUNING.XP_LIGHT_SUCCESS)
end

local function onAddFuelPerform(action)
    if not isLocalPlayer(action.character) then return end
    PZRPG.addXp(action.character, "firemaking", TUNING.XP_ADD_FUEL)
end

---------------------------------------------------------------------------
-- FIRE-2: raised fuel cap + flat burn-efficiency rebalance
---------------------------------------------------------------------------

--- Our fuel cap in minutes, from the PZRPG.MaximumFireFuelHours sandbox option
--- (falls back to TUNING.FUEL_MAX_HOURS if the option isn't present).
local function pzrpgFuelMaxMinutes()
    local hours = TUNING.FUEL_MAX_HOURS
    local ok, v = pcall(function() return SandboxVars.PZRPG.MaximumFireFuelHours end)
    if ok and type(v) == "number" and v > 0 then hours = v end
    return hours * 60
end

-- Both re-points below are safe to run repeatedly: each is a straight
-- assignment of a fresh function (no wrapping of a prior value), so a -debug
-- reload or a second OnGameBoot just re-applies the same thing. They run at
-- OnGameBoot because the vanilla definitions load (server/) after this file.

local function installFuelCap()
    -- vanilla getCampingFuelMax (server/Camping/camping_fuel.lua) is a bare
    -- global; replace it so campfire / BBQ / stove all honour our cap.
    getCampingFuelMax = pzrpgFuelMaxMinutes
end

local function installBurnRate()
    if type(SCampfireSystem) ~= "table" then return end   -- MP client: no server system
    -- Reimplement the per-minute drain loop (vanilla's is 8 lines, amt hard-1).
    function SCampfireSystem:lowerFuelAmount()
        local rate = TUNING.BURN_RATE or 1
        for i = 1, self:getLuaObjectCount() do
            local o = self:getLuaObjectByIndex(i)
            if o.isLit then
                o.fuelAmt = math.max(o.fuelAmt - rate, 0)
                o:changeFireLvl()
            end
        end
    end
end

---------------------------------------------------------------------------

local function install()
    if ISLightFromKindle     then PZRPG.wrapAction(ISLightFromKindle,     "perform", onKindlePerform) end
    if ISLightFromLiterature then PZRPG.wrapAction(ISLightFromLiterature, "perform", onLightPerform)  end
    if ISLightFromPetrol     then PZRPG.wrapAction(ISLightFromPetrol,     "perform", onLightPerform)  end
    if ISAddFuelAction       then PZRPG.wrapAction(ISAddFuelAction,       "perform", onAddFuelPerform) end
    installFuelCap()
    installBurnRate()
end

local function installAndLog()
    install()
    PZRPG.log(("firemaking: fuel cap %.0fh, burn rate %.2f/min")
        :format(pzrpgFuelMaxMinutes() / 60, TUNING.BURN_RATE or 1))
end

install()                                                       -- -debug reload / late-load
PZRPG.hookEvent("OnGameBoot", "firemaking.wrap", installAndLog)  -- first boot (load order)
