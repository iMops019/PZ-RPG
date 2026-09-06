--[[
    PZ RPG  --  XP accessors + level-up  (docs/ARCHITECTURE.md sec 3)

    The only way skill modules touch progression. They never call getModData(),
    PZRPG.curve, or PZRPG.getData directly -- always through:

        PZRPG.getXp(player, skillId)              -> number
        PZRPG.getLevel(player, skillId)           -> 1..MAX_LEVEL
        PZRPG.getXpProgress(player, skillId)      -> into, span, fraction (for the sheet)
        PZRPG.addXp(player, skillId, amount)      -> newXp, newLevel  (fires level-up)

    addXp also trickles a fraction of the XP into vanilla perks when the skill
    def has `vanillaXp = { Fitness = 0.15, ... }` (docs/DESIGN.md sec 3a).

    Level-up feedback: a green arrow halo over the player + a log line, plus any
    listeners added with PZRPG.addLevelUpListener(fn).

    Load order: _03_ -> after Core, Save, Registry; before skill modules.
]]

PZRPG = PZRPG or {}

--- data.skills[skillId], created on first touch. Local: skills go through the
--- public accessors below, not this.
local function skillEntry(player, skillId)
    local data = PZRPG.getData(player)
    if not data then return nil end
    local entry = data.skills[skillId]
    if not entry then
        entry = { xp = 0 }
        data.skills[skillId] = entry
    end
    return entry
end

---------------------------------------------------------------------------
-- Reads
---------------------------------------------------------------------------

function PZRPG.getXp(player, skillId)
    local entry = skillEntry(player, skillId)
    return (entry and entry.xp) or 0
end

function PZRPG.getLevel(player, skillId)
    return PZRPG.curve.levelForXp(PZRPG.getXp(player, skillId))
end

--- Progress within the current level, for XP bars.
--- Returns: xp into this level, xp span of this level, fraction 0..1.
--- At MAX_LEVEL: span 0, fraction 1.
function PZRPG.getXpProgress(player, skillId)
    local xp    = PZRPG.getXp(player, skillId)
    local level = PZRPG.curve.levelForXp(xp)
    if level >= PZRPG.curve.MAX_LEVEL then
        return 0, 0, 1
    end
    local base     = PZRPG.curve.xpForLevel(level)
    local nextBase = PZRPG.curve.xpForLevel(level + 1)
    local span     = nextBase - base
    local into     = xp - base
    return into, span, (span > 0) and (into / span) or 0
end

---------------------------------------------------------------------------
-- Write
---------------------------------------------------------------------------

--- Trickle a fraction of a skill's XP into vanilla perks, per the skill def's
--- `vanillaXp = { Fitness = 0.15, Strength = 0.08 }` map (perk name -> ratio).
--- Silent (no halo), respects vanilla XP multipliers, fires vanilla level-ups.
--- docs/DESIGN.md sec 3a.
local function grantVanillaXp(player, skillId, amount)
    local def = PZRPG.skills and PZRPG.skills[skillId]
    if not def or type(def.vanillaXp) ~= "table" then return end

    local ok, xpObj = pcall(function() return player:getXp() end)
    if not ok or not xpObj then return end

    -- Mark the re-entrant window so PZRPG_06_VanillaMirror ignores the AddXP
    -- events we're about to fire (otherwise Woodcutting -> Fitness could loop).
    PZRPG._vanillaFeedDepth = (PZRPG._vanillaFeedDepth or 0) + 1
    pcall(function()
        for perkName, ratio in pairs(def.vanillaXp) do
            local give = amount * (tonumber(ratio) or 0)
            if give > 0 then
                local perk = PerkFactory.getPerkFromName(perkName)
                if perk then xpObj:AddXP(perk, give) end
            end
        end
    end)
    PZRPG._vanillaFeedDepth = PZRPG._vanillaFeedDepth - 1
end

--- Add XP to a skill. Ignores non-positive amounts. On a level crossing, fires
--- PZRPG.notifyLevelUp. Also routes def.vanillaXp into vanilla perks.
--- Returns the new xp total and new level.
function PZRPG.addXp(player, skillId, amount)
    if not player or type(skillId) ~= "string" then return end

    amount = tonumber(amount) or 0
    if amount <= 0 then
        return PZRPG.getXp(player, skillId), PZRPG.getLevel(player, skillId)
    end

    local entry = skillEntry(player, skillId)
    if not entry then return end

    local oldLevel = PZRPG.curve.levelForXp(entry.xp)
    entry.xp = entry.xp + amount
    local newLevel = PZRPG.curve.levelForXp(entry.xp)

    grantVanillaXp(player, skillId, amount)
    if PZRPG.queueXpDrop then PZRPG.queueXpDrop(player, skillId, amount) end   -- floating "+N Skill"

    if newLevel > oldLevel then
        PZRPG.notifyLevelUp(player, skillId, oldLevel, newLevel)
    end

    return entry.xp, newLevel
end

---------------------------------------------------------------------------
-- Level-up notification
---------------------------------------------------------------------------

PZRPG._levelUpListeners = PZRPG._levelUpListeners or {}

--- fn(player, skillId, oldLevel, newLevel). Reload-safe: pass a stable `key`
--- and re-registering replaces the previous fn for that key.
function PZRPG.addLevelUpListener(key, fn)
    PZRPG._levelUpListeners[key] = fn
end

function PZRPG.notifyLevelUp(player, skillId, oldLevel, newLevel)
    local def  = PZRPG.skills and PZRPG.skills[skillId]
    local name = (def and def.name) or skillId

    PZRPG.log(("%s: level %d -> %d"):format(name, oldLevel, newLevel))

    -- Green arrow halo, same call vanilla uses for a perk level-up.
    if HaloTextHelper and HaloTextHelper.addTextWithArrow then
        pcall(function()
            HaloTextHelper.addTextWithArrow(player, name .. " " .. newLevel, true,
                HaloTextHelper.getGoodColor())
        end)
    end

    for _, fn in pairs(PZRPG._levelUpListeners) do
        pcall(fn, player, skillId, oldLevel, newLevel)
    end
end
