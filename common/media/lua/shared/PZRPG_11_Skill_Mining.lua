--[[
    PZ RPG  --  Mining

    MINE-1: right-click a world boulder (`boulders_*` sprite) with a pickaxe in
    your inventory -> ISMineBoulderAction (PZRPG_46) -> Mining XP per swing, then
    6-12 Base.Stone2 + a guaranteed Base.IronOre (+1 bonus on a level-scaled
    roll) dropped on the ground. The boulder then goes on a cooldown (on its own
    object modData) for COOLDOWN_HOURS in-game hours.

    Level effect: bonus-ore chance scales with level. Mine-speed / pick-wear
    come in MINE-2.

    Load order: _11_ -> after the _0N_ Core files. Context menu + action are
    PZRPG_45 (client) and PZRPG_46 (shared).
]]

PZRPG.tuning = PZRPG.tuning or {}
local TUNING = PZRPG.tuning.mining or {
    XP_PER_HIT      = 2,       -- Mining xp per pickaxe swing
    HITS_TO_DEPLETE = 6,       -- swings to work a boulder out (~12 xp/boulder)
    TICKS_PER_HIT   = 55,      -- action time per swing (~0.9s)
    STONE_MIN       = 6,
    STONE_MAX       = 12,
    ORE_GUARANTEED  = 1,       -- every boulder gives at least this much iron ore
    ORE_BONUS_BASE  = 0.08,    -- chance of +1 bonus ore at level 1
    ORE_BONUS_MAX   = 0.60,    -- ...at level 100
    ORE_BONUS_EXP   = 0.80,
    COOLDOWN_HOURS  = 48,      -- in-game hours a mined boulder stays spent (2 days)
}
PZRPG.tuning.mining = TUNING

--- Chance (0..1) of an extra iron ore on top of the guaranteed one.
function PZRPG.miningBonusOreChance(level)
    local frac = math.max(0, math.min(1, (level or 1) / 100))
    return TUNING.ORE_BONUS_BASE
        + (TUNING.ORE_BONUS_MAX - TUNING.ORE_BONUS_BASE) * (frac ^ TUNING.ORE_BONUS_EXP)
end

PZRPG.registerSkill{
    id        = "mining",
    name      = "Mining",
    category  = "gathering",
    order     = 20,
    vanillaXp = { Fitness = 0.15, Strength = 0.12 },
    describe  = function(level)
        return ("Mining boulders with a pickaxe. Every boulder yields %d iron ore, +1 more at %d%%.")
            :format(TUNING.ORE_GUARANTEED, math.floor(PZRPG.miningBonusOreChance(level) * 100 + 0.5))
    end,
}

---------------------------------------------------------------------------
-- helpers used by the context menu (PZRPG_45) and the action (PZRPG_46)
---------------------------------------------------------------------------

function PZRPG.isBoulderSprite(name)
    return type(name) == "string" and luautils.stringStarts(name, "boulders_")
end

--- In-game hours until this boulder can be mined again (0 = ready now).
function PZRPG.boulderCooldown(boulder)
    if not boulder or not boulder.getModData then return 0 end
    local ok, md = pcall(function() return boulder:getModData() end)
    if not ok or type(md) ~= "table" then return 0 end
    local readyAt = tonumber(md.PZRPG_minedUntil) or 0
    return math.max(0, readyAt - getGameTime():getWorldAgeHours())
end

function PZRPG.markBoulderMined(boulder)
    if not boulder or not boulder.getModData then return end
    pcall(function()
        boulder:getModData().PZRPG_minedUntil =
            getGameTime():getWorldAgeHours() + TUNING.COOLDOWN_HOURS
        if boulder.transmitModData then boulder:transmitModData() end
        if boulder.setAlpha then boulder:setAlpha(0.5) end   -- instant "spent" look (PZRPG_47 maintains it)
    end)
end

--- Drop the yield on the ground (like logs from a felled tree) when a boulder
--- is worked out. XP is awarded per swing by the action, not here.
function PZRPG.mineBoulderReward(player)
    if not player then return end
    local level = PZRPG.getLevel(player, "mining")
    local sq    = player:getCurrentSquare()
    if not sq then return end

    local function drop(id)
        pcall(function()
            sq:AddWorldInventoryItem(id, ZombRand(100) / 100, ZombRand(100) / 100, 0.0)
        end)
    end

    local stones = ZombRand(TUNING.STONE_MIN, TUNING.STONE_MAX + 1)   -- 6..12
    for _ = 1, stones do drop("Base.Stone2") end

    local ore = TUNING.ORE_GUARANTEED                                 -- always >= 1
    if ZombRand(1000) < PZRPG.miningBonusOreChance(level) * 1000 then
        ore = ore + 1                                                 -- level-scaled bonus
    end
    for _ = 1, ore do drop("Base.IronOre") end

    pcall(function()
        if not (HaloTextHelper and HaloTextHelper.addText) then return end
        HaloTextHelper.addText(player, ("+%d Stone"):format(stones))
        HaloTextHelper.addTextWithArrow(player, ("+%d Iron Ore!"):format(ore),
            true, HaloTextHelper.getGoodColor())
    end)
end
