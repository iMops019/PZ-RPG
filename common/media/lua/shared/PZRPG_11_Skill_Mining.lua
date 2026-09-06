--[[
    PZ RPG  --  Mining

    MINE-1: right-click a world boulder (`boulders_*` sprite) with a pickaxe in
    your inventory -> ISMineBoulderAction (PZRPG_46) -> 1-3 Base.Stone2 + an
    iron-ore roll + Mining XP. The boulder then goes on a cooldown (stored on
    its own object modData) for COOLDOWN_HOURS in-game hours.

    Level effect: iron-ore chance scales with level. Mine-speed / pick-wear
    come in MINE-2.

    Load order: _11_ -> after the _0N_ Core files. Context menu + action are
    PZRPG_45 (client) and PZRPG_46 (shared).
]]

PZRPG.tuning = PZRPG.tuning or {}
local TUNING = PZRPG.tuning.mining or {
    XP_PER_HIT      = 2,       -- Mining xp per pickaxe swing
    HITS_TO_DEPLETE = 6,       -- swings to work a boulder out (~12 xp/boulder)
    STONE_MIN       = 6,
    STONE_MAX       = 12,
    ORE_CHANCE_BASE = 0.08,    -- iron ore drop chance at level 1
    ORE_CHANCE_MAX  = 0.25,    -- ...at level 100
    ORE_CHANCE_EXP  = 0.80,
    COOLDOWN_HOURS  = 48,      -- in-game hours a mined boulder stays spent (2 days)
}
PZRPG.tuning.mining = TUNING

function PZRPG.miningOreChance(level)
    local frac = math.max(0, math.min(1, (level or 1) / 100))
    return TUNING.ORE_CHANCE_BASE
        + (TUNING.ORE_CHANCE_MAX - TUNING.ORE_CHANCE_BASE) * (frac ^ TUNING.ORE_CHANCE_EXP)
end

PZRPG.registerSkill{
    id        = "mining",
    name      = "Mining",
    category  = "gathering",
    order     = 20,
    vanillaXp = { Fitness = 0.15, Strength = 0.12 },
    describe  = function(level)
        return ("Mining boulders with a pickaxe for stone and ore. Iron-ore chance %d%%.")
            :format(math.floor(PZRPG.miningOreChance(level) * 100 + 0.5))
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

    local gotOre = ZombRand(1000) < PZRPG.miningOreChance(level) * 1000
    if gotOre then drop("Base.IronOre") end

    pcall(function()
        if not (HaloTextHelper and HaloTextHelper.addText) then return end
        HaloTextHelper.addText(player, ("+%d Stone"):format(stones))
        if gotOre then
            HaloTextHelper.addTextWithArrow(player, "+1 Iron Ore!", true, HaloTextHelper.getGoodColor())
        end
    end)
end
