--[[
    PZ RPG  --  Timed buff engine   (docs/DESIGN.md sec 5 -- "The buff engine")

    A general, source-tracked, self-expiring buff layer for the LOCAL player.
    Not Cooking-specific -- Field Recipe meals (COOK-4b) are the first user, but
    anything can call PZRPG.buffs.apply.

        PZRPG.buffs.apply(player, list, durationHrs, source)
            list  = { { t = "mending", mag = 0.003 }, { t = "scholar", mag = 0.15 }, ... }
            source= a string key ("recipe:BountifulTroutPlatter"). Re-applying
                    the same source REPLACES its entry (eating the dish again
                    just resets the timer); different sources STACK.

        PZRPG.buffs.get(t)      -> summed magnitude of every active buff of type t (0 if none)
        PZRPG.buffs.list()      -> array copy of active buffs (for UI / debug)
        PZRPG.buffs.clear(src)  -> drop one source, or all if src is nil
        PZRPG.buffs.remaining() -> game-hours until the last buff expires (0 if none)

    Expiry is on the world-age clock (getWorldAgeHours) so it survives a
    sped-up clock, same as COOK-3.

    Effects wired HERE (self-contained, no other file touched):
      - mending          : + mag general-health per tick while hurt
      - scholar          : x (1 + mag) on PZRPG XP gains  (wraps PZRPG.addXp)
      - infectionResist  : chance mag to negate a bite/scratch infection as it
                           transmits (same idiom as CONST-EFFECT-1)
      - steady           : panic + stress decay faster while active
    Effects folded into the matching skill-effect files (one line each, so the
    mechanism isn't duplicated) are COOK-4a.2: strong / toughness / guarded /
    vigor. PZRPG.buffs.get(t) already returns their magnitude.

    Load order: _09_ -> right after _08_ XpDrops, before every skill module.
]]

PZRPG = PZRPG or {}
PZRPG.buffs = PZRPG.buffs or {}

PZRPG.tuning = PZRPG.tuning or {}
local TUNING = PZRPG.tuning.buffs or {
    MENDING_MIN_HP  = 2,      -- don't bother regen'ing within this of full health
    STEADY_DECAY    = 0.06,   -- fraction of panic/stress shed per tick while `steady`
    INDICATOR       = true,   -- floating "Well Fed" halo when a buff starts / every ~refresh
}
PZRPG.tuning.buffs = TUNING

-- active buffs: array of { t, mag, endHrs, source }
PZRPG._buffs = PZRPG._buffs or {}

local function nowHrs()
    local gt = getGameTime()
    return gt and gt:getWorldAgeHours() or 0
end

local function prune()
    local n = nowHrs()
    local kept = {}
    for _, b in ipairs(PZRPG._buffs) do
        if (b.endHrs or 0) > n then kept[#kept + 1] = b end
    end
    PZRPG._buffs = kept
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Apply / refresh a set of buffs from one source.
function PZRPG.buffs.apply(player, list, durationHrs, source)
    if type(list) ~= "table" or (tonumber(durationHrs) or 0) <= 0 then return end
    source = source or "anon"
    local endHrs = nowHrs() + durationHrs

    -- drop any existing buffs from this source (replace, don't stack a source on itself)
    local kept = {}
    for _, b in ipairs(PZRPG._buffs) do
        if b.source ~= source then kept[#kept + 1] = b end
    end
    PZRPG._buffs = kept

    for _, spec in ipairs(list) do
        local t   = spec.t or spec.type
        local mag = tonumber(spec.mag or spec.magnitude) or 0
        if type(t) == "string" and mag ~= 0 then
            PZRPG._buffs[#PZRPG._buffs + 1] = { t = t, mag = mag, endHrs = endHrs, source = source }
        end
    end

    if TUNING.INDICATOR and player and HaloTextHelper and HaloTextHelper.addTextWithArrow then
        pcall(function()
            HaloTextHelper.addTextWithArrow(player, "Well Fed", true, HaloTextHelper.getGoodColor())
        end)
    end
end

--- Summed magnitude of all active buffs of type `t`.
function PZRPG.buffs.get(t)
    prune()
    local sum = 0
    for _, b in ipairs(PZRPG._buffs) do
        if b.t == t then sum = sum + b.mag end
    end
    return sum
end

function PZRPG.buffs.list()
    prune()
    local out = {}
    for i, b in ipairs(PZRPG._buffs) do out[i] = { t = b.t, mag = b.mag, endHrs = b.endHrs, source = b.source } end
    return out
end

function PZRPG.buffs.clear(source)
    if source == nil then PZRPG._buffs = {}; return end
    local kept = {}
    for _, b in ipairs(PZRPG._buffs) do
        if b.source ~= source then kept[#kept + 1] = b end
    end
    PZRPG._buffs = kept
end

--- Game-hours until the last active buff expires (0 if none).
function PZRPG.buffs.remaining()
    prune()
    local n, latest = nowHrs(), 0
    for _, b in ipairs(PZRPG._buffs) do
        if b.endHrs and b.endHrs - n > latest then latest = b.endHrs - n end
    end
    return latest
end

--- Debug: PZRPG.buffs.dump()
function PZRPG.buffs.dump()
    prune()
    PZRPG.log(("buffs: %d active, %.2fh left"):format(#PZRPG._buffs, PZRPG.buffs.remaining()))
    for _, b in ipairs(PZRPG._buffs) do
        PZRPG.log(("  %s  mag %.3f  %.2fh  (%s)"):format(b.t, b.mag, (b.endHrs or 0) - nowHrs(), b.source))
    end
end

---------------------------------------------------------------------------
-- scholar: multiply PZ RPG XP gains  (wrap PZRPG.addXp, idempotent on reload)
---------------------------------------------------------------------------

PZRPG._addXpOrig = PZRPG._addXpOrig or PZRPG.addXp
PZRPG.addXp = function(player, skillId, amount, ...)
    local m = 1 + PZRPG.buffs.get("scholar")
    if m ~= 1 then
        local a = tonumber(amount)
        if a and a > 0 then amount = a * m end
    end
    return PZRPG._addXpOrig(player, skillId, amount, ...)
end

---------------------------------------------------------------------------
-- Per-tick effects: mending, steady
---------------------------------------------------------------------------

PZRPG.hookEvent("OnPlayerUpdate", "buffs.tick", function(player)
    if not player or player:getPlayerNum() ~= 0 then return end
    if #PZRPG._buffs == 0 then return end
    prune()

    -- mending: gentle general-health regen while hurt
    local mend = PZRPG.buffs.get("mending")
    if mend > 0 then
        pcall(function()
            local bd = player:getBodyDamage()
            if bd and bd:getHealth() < 100 - (TUNING.MENDING_MIN_HP or 2) then
                bd:AddGeneralHealth(mend)
            end
        end)
    end

    -- steady: shed panic + stress faster
    local steady = PZRPG.buffs.get("steady")
    if steady > 0 then
        pcall(function()
            local st = player:getStats()
            if not st then return end
            local k = math.min(0.5, (TUNING.STEADY_DECAY or 0.06) * steady * 10)
            st:setPanic(math.max(0, st:getPanic()  * (1 - k)))
            st:setStress(math.max(0, st:getStress() * (1 - k)))
        end)
    end
end)

---------------------------------------------------------------------------
-- infectionResist: negate a Knox infection as it transmits (cf. CONST-EFFECT-1)
---------------------------------------------------------------------------

PZRPG.hookEvent("OnPlayerUpdate", "buffs.infection", function(player)
    if not player or player:getPlayerNum() ~= 0 then return end

    local ok, bd = pcall(function() return player:getBodyDamage() end)
    if not ok or not bd then return end

    local now  = bd:IsInfected()
    local prev = PZRPG._buffInfPrev
    if prev == nil then PZRPG._buffInfPrev = now; return end

    if now and not prev then
        local resist = PZRPG.buffs.get("infectionResist")
        if resist > 0 then
            pcall(function()
                -- same per-part idiom as CONST-EFFECT-1: roll a save on each
                -- newly-infected part, clear the ones we resist.
                local parts = bd:getBodyParts()
                if not parts then return end
                local cured, remaining = false, false
                for i = 0, parts:size() - 1 do
                    local part = parts:get(i)
                    if part and part:IsInfected() then
                        if ZombRandFloat(0, 1) < resist then
                            part:SetInfected(false)
                            cured = true
                        else
                            remaining = true
                        end
                    end
                end
                if cured and not remaining then bd:setInfected(false) end
                if cured and HaloTextHelper and HaloTextHelper.addTextWithArrow then
                    HaloTextHelper.addTextWithArrow(player, "Well Fed: shrugged off the infection!",
                        true, HaloTextHelper.getGoodColor())
                    PZRPG.log("buffs: infectionResist negated a zombie infection")
                end
            end)
        end
        now = bd:IsInfected()
    end
    PZRPG._buffInfPrev = now
end)

---------------------------------------------------------------------------

PZRPG.hookEvent("OnGameBoot", "buffs.boot", function()
    if getDebug and getDebug() then PZRPG.log("buffs: engine ready") end
end)
