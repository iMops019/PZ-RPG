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

    FIRE-4: a passive Firemaking XP trickle (XP_TEND every TEND_INTERVAL_MIN
    game-minutes) while a lit campfire is within TEND_RADIUS tiles of the local
    player -- the reward loop is "keep a fire going at camp", not "spam-light
    fires". Lighting and feeding stay one-shot (cut in FIRE-2 to make room).
    Runs off OnPlayerUpdate throttled by world-age hours (EveryTenMinutes never
    fired for us), so it keeps pace when the clock is sped up. Client-only.

    FIRE-3: Firemaking *level* scales the kindle (friction) ignition -- and only
    that. We fork ISLightFromKindle:updateKindling (B42 42.20.4) and swap its two
    flat ZombRand(300) bounds for level-driven ones: higher level catches sooner
    and snaps the kindling far less; carrying real tinder (twigs / paper /
    sheets) helps more again. Literature / petrol lighting stays auto-success.
    "Fires last longer" is still the flat BURN_RATE + raised cap, not level.

    Load order: _21_ -> after Core (_00-07). Vanilla Camping actions
    (ISLightFromKindle, ...) load under shared/Camping/ *before* us, so the
    kindle fork applies at load; server/Camping/*.lua defines getCampingFuelMax /
    SCampfireSystem *after* shared, so those two re-points wait for OnGameBoot.
    (MP: server-authoritative burn already runs server-side; the cap override
    also runs in the client context for the add-fuel menu preview.)
]]

PZRPG.tuning = PZRPG.tuning or {}
PZRPG.tuning.firemaking = PZRPG.tuning.firemaking or {
    XP_LIGHT_SUCCESS = 40,    -- a campfire catches
    XP_LIGHT_ATTEMPT = 8,     -- kindling broke without catching
    XP_ADD_FUEL      = 10,    -- feeding an existing fire
    XP_TEND          = 3,     -- FIRE-4: awarded per TEND_INTERVAL_MIN near a lit fire
    TEND_INTERVAL_MIN = 10,   -- game-minutes between trickles
    TEND_RADIUS      = 2,     -- tiles (chebyshev) from the player to that fire

    FUEL_MAX_HOURS = 12,      -- fallback if the sandbox option isn't readable
    BURN_RATE      = 0.75,    -- fuel-minutes burned per real minute per lit fire
                             -- (1.0 = vanilla; 0.75 => a 6h log lasts ~8h)

    -- FIRE-3: kindle (friction) ignition, scaled by Firemaking level.
    -- Vanilla's updateKindling rolls ZombRand(N)==0 each tick to CATCH, and
    -- ZombRand(M)==0 to SNAP the kindling. Lower catch-N = lights sooner;
    -- higher break-M = kindling lasts longer. Vanilla is a flat 300 / 300
    -- (150 / 450 with Wilderness Knowledge or Scout).
    KINDLE_CATCH_L1    = 300,   -- mean ticks to catch at level 1 (= vanilla)
    KINDLE_CATCH_L100  = 55,    -- ...at level 100
    KINDLE_CATCH_EXP   = 0.85,
    KINDLE_BREAK_L1    = 300,   -- mean ticks to snap the kindling at level 1 (= vanilla)
    KINDLE_BREAK_L100  = 1400,  -- ...at level 100
    KINDLE_BREAK_EXP   = 1.0,
    KINDLE_TINDER_CATCH_MULT = 0.55,  -- catch-N multiplier when real tinder is in the bag
    KINDLE_TINDER_BREAK_MULT = 1.25,  -- break-M multiplier when real tinder is in the bag
    KINDLE_TRAIT_CATCH_MULT  = 0.5,   -- Wilderness Knowledge / Scout, kept from vanilla
    KINDLE_TRAIT_BREAK_MULT  = 1.5,
}
local TUNING = PZRPG.tuning.firemaking

local function frac(level)
    return math.max(0, math.min(1, (level or 1) / 100))
end

--- Mean ticks to catch a friction fire at this level (lower = lights sooner).
local function kindleCatchTries(level)
    local a, b = TUNING.KINDLE_CATCH_L1, TUNING.KINDLE_CATCH_L100
    return math.max(1, math.floor(a - (a - b) * (frac(level) ^ TUNING.KINDLE_CATCH_EXP)))
end

--- Mean ticks to snap the kindling at this level (higher = lasts longer).
local function kindleBreakTries(level)
    local a, b = TUNING.KINDLE_BREAK_L1, TUNING.KINDLE_BREAK_L100
    return math.max(1, math.floor(a + (b - a) * (frac(level) ^ TUNING.KINDLE_BREAK_EXP)))
end

PZRPG.registerSkill{
    id       = "firemaking",
    name     = "Firemaking",
    category = "production",
    order    = 60,
    describe = function(level)
        local faster = math.floor((1 - kindleCatchTries(level) / TUNING.KINDLE_CATCH_L1) * 100 + 0.5)
        return ("Lighting and tending fires. Friction fires catch ~%d%% faster than a novice's; "
            .. "real tinder (twigs, paper) in your bag helps more. Trains on light / feed and "
            .. "while you sit by a lit fire.")
            :format(faster)
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
-- FIRE-3: Firemaking level scales the kindle (friction) ignition
---------------------------------------------------------------------------

--- True if the character carries a valid fire tinder (twigs, paper, sheets,
--- literature ...) other than `exclude` (the branch being rubbed).
local function hasTinder(character, exclude)
    local inv = character and character:getInventory()
    if not inv or not (ISCampingMenu and ISCampingMenu.isValidTinder) then return false end
    local ok, res = pcall(function()
        return inv:getFirstEvalRecurse(function(it)
            return it ~= nil and it ~= exclude and ISCampingMenu.isValidTinder(it)
        end)
    end)
    return ok and res ~= nil
end

--- catch-N, break-M for this attempt (level + tinder + the vanilla traits).
local function kindleOdds(character, level, tinderItem)
    local catch = kindleCatchTries(level)
    local brk   = kindleBreakTries(level)
    if hasTinder(character, tinderItem) then
        catch = catch * TUNING.KINDLE_TINDER_CATCH_MULT
        brk   = brk   * TUNING.KINDLE_TINDER_BREAK_MULT
    end
    local okT, hasT = pcall(function()
        return character:hasTrait(CharacterTrait.WILDERNESS_KNOWLEDGE)
            or character:hasTrait(CharacterTrait.SCOUT)
    end)
    if okT and hasT then
        catch = catch * TUNING.KINDLE_TRAIT_CATCH_MULT
        brk   = brk   * TUNING.KINDLE_TRAIT_BREAK_MULT
    end
    return math.max(1, math.floor(catch)), math.max(1, math.floor(brk))
end

--- Our fork of vanilla ISLightFromKindle:updateKindling (B42 42.20.4). Only the
--- two ZombRand bounds change -- they come from Firemaking level + tinder now,
--- not a flat 300 / 300. Endurance drain, the 20 %-progress gate, the
--- server/client completion branches and the kindling-snap all stay verbatim.
local function pzrpgUpdateKindling(self)
    self.character:getStats():remove(CharacterStat.ENDURANCE, 0.0001 * getGameTime():getMultiplier())
    if not isServer() then
        if self:getJobDelta() < 0.2 then return end
    else
        if self.netAction:getProgress() < 0.2 then return end
    end

    local lvl = PZRPG.getLevel(self.character, "firemaking")
    local randNumber, randBrokeNumber = kindleOdds(self.character, lvl, self.item)

    if ZombRand(randNumber) == 0 then
        local campfire = SCampfireSystem.instance:getLuaObjectAt(self.campfire.x, self.campfire.y, self.campfire.z)
        if campfire then campfire:lightFire() end
        if isServer() then self.netAction:forceComplete() else self:forceComplete() end
    elseif ZombRand(randBrokeNumber) == 0 then
        -- the wood kit broke
        self.character:getInventory():Remove(self.item)
        sendRemoveItemFromContainer(self.character:getInventory(), self.item)
        if isServer() then
            sendPlaySound("BreakWoodItem", false, self.character)
            self.item = nil
            self.netAction:forceComplete()
        else
            self.character:getEmitter():playSound("BreakWoodItem")
            self:forceComplete()
        end
    end
end

local function installKindle()
    if type(ISLightFromKindle) ~= "table" then return end
    ISLightFromKindle.updateKindling = pzrpgUpdateKindling   -- straight replace, reload-safe
end

---------------------------------------------------------------------------
-- FIRE-4: passive XP while you're near a lit fire (rewards tending a camp
-- fire, not spam-lighting). Driven off OnPlayerUpdate (the event the rest of
-- the mod uses -- the EveryTenMinutes hook never fired), throttled by game
-- time so it still works when the clock is sped up.
---------------------------------------------------------------------------

--- A lit campfire on or within TEND_RADIUS tiles of `player`? (Per-square via
--- getLuaObjectOnSquare -- on the client getLuaObjectByIndex returns bare
--- modData with no x/y/z, so iterating the system doesn't work; this is the
--- path vanilla's ISCampingInfoWindow uses.)
local function litFireNear(player)
    if type(CCampfireSystem) ~= "table" or not CCampfireSystem.instance then return false end
    local cell = getCell()
    if not cell then return false end
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    local r = TUNING.TEND_RADIUS
    for x = px - r, px + r do
        for y = py - r, py + r do
            local sq = cell:getGridSquare(x, y, pz)
            local ok, cf = pcall(function()
                return sq and CCampfireSystem.instance:getLuaObjectOnSquare(sq)
            end)
            if ok and cf and cf.isLit then return true end
        end
    end
    return false
end

local tendPrevHrs   -- world-age hours at the last tick
local tendAccumMin = 0

local function onTendUpdate(player)
    if not player or player ~= getSpecificPlayer(0) then return end
    local gt = getGameTime()
    if not gt then return end
    local nowHrs = gt:getWorldAgeHours()
    local prev = tendPrevHrs
    tendPrevHrs = nowHrs
    if not prev then return end
    local dMin = (nowHrs - prev) * 60
    if dMin <= 0 or dMin > 60 then return end   -- clock jump / load / paused

    if not litFireNear(player) then
        tendAccumMin = 0
        return
    end
    tendAccumMin = tendAccumMin + dMin
    if tendAccumMin >= (TUNING.TEND_INTERVAL_MIN or 10) then
        tendAccumMin = 0
        PZRPG.addXp(player, "firemaking", TUNING.XP_TEND)
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
    installKindle()
end

local function installAndLog()
    install()
    PZRPG.log(("firemaking: fuel cap %.0fh, burn rate %.2f/min, kindle catch L1..L100 %d..%d")
        :format(pzrpgFuelMaxMinutes() / 60, TUNING.BURN_RATE or 1,
                kindleCatchTries(1), kindleCatchTries(100)))
end

install()                                                       -- -debug reload / late-load
PZRPG.hookEvent("OnGameBoot", "firemaking.wrap", installAndLog)  -- first boot (load order)
PZRPG.hookEvent("OnPlayerUpdate", "firemaking.tend", onTendUpdate)  -- FIRE-4 passive trickle
