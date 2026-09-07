--[[
    PZ RPG  --  Fishing   (FISH-2: custom fishing action)

    Vanilla B42 fishing is a real-time cast/reel minigame with a silent hard
    requirement -- a hook attached to the rod, or NOTHING ever bites -- plus
    fish-abundance / weather / shore-distance gates. PZ RPG replaces it with a
    grounded world action, the same shape as Mining:

      right-click on or beside water with a fishing rod  ->  "Fish Here"
        -> ISPZRPGFishAction (PZRPG_48): a few cast cycles per action, then it
           re-queues itself so you keep fishing until you walk off (stopOnWalk)
           or run your endurance out. Each cycle rolls a bite (level- and
           bait-scaled); a bite lands a fish (custom species list, level-gated)
           into your inventory -- IF you then win the landing roll (level- and
           species-scaled; big fish slip more) -- or junk, or "it got away"
           with a random "Darn, it got away!" line. XP per cycle, more per fish.

    Level effect (DESIGN.md sec 4): bite rate climbs, better/bigger species
    unlock, less junk. All numbers in PZRPG.tuning.fishing -- live-tunable from
    the -debug console.

    Bait is OPTIONAL. Any vanilla lure item (worm, cricket, leech, minnow, ...)
    anywhere in your inventory adds a flat bonus to the bite chance; one unit is
    consumed each time a fish bites. (Digging worms while foraging -> FRG-2.)

    Still vanilla-mirrored (mirrorVanilla = { Fishing = 1.0 }) so if you do play
    the vanilla minigame it trains this skill too.

    Load order: _13_ -> after the _0N_ Core files. Action is PZRPG_48 (shared),
    context menu is PZRPG_44 (client).
]]

PZRPG.tuning = PZRPG.tuning or {}
local TUNING = PZRPG.tuning.fishing or {
    XP_NIBBLE = 1,    -- cast cycle that landed nothing
    XP_TRASH  = 4,    -- reeled in junk
    XP_LOST   = 3,    -- hooked a fish but lost it before landing
    XP_CATCH  = 10,   -- landed a fish

    CASTS_PER_ACTION = 3,     -- cast cycles resolved per queued action (then it re-queues)
    CAST_TICKS_BASE  = 460,   -- action ticks for one cast cycle at level 1
    CAST_TICKS_MIN   = 280,   -- ...at level 100 (higher level = quicker casts)
    CAST_TICKS_EXP   = 1.0,

    BITE_BASE  = 0.34,   -- chance a cast cycle gets a bite, level 1
    BITE_MAX   = 0.82,   -- ...level 100
    BITE_EXP   = 0.70,
    BAIT_BONUS = 0.22,   -- added to the bite chance while bait is on hand

    FISH_BASE  = 0.55,   -- of bites, chance it's a fish (not junk / miss), level 1
    FISH_MAX   = 0.93,   -- ...level 100
    FISH_EXP   = 0.80,
    MISS_SHARE = 0.45,   -- of non-fish bites, share that are "got away" (rest = junk)

    -- once a fish is on the line you still have to land it
    LAND_BASE  = 0.65,   -- chance to land a hooked fish, level 1
    LAND_MAX   = 0.94,   -- ...level 100
    LAND_EXP   = 0.85,
    LAND_TROPHY_PENALTY = 0.35,  -- big/rare species (high minLvl) fight harder and slip more

    -- flavour said on the water's edge when one gets away (miss or lost fish)
    LOSS_LINES = {
        "Darn, it got away!",
        "Lost it!",
        "Better luck next time...",
        "The line went slack.",
        "Argh -- so close!",
        "It spat the hook.",
        "Should've set the hook harder.",
        "That one was a fighter.",
    },

    REACH = 4,           -- max tiles from the player to the fished water square

    -- junk pulls: vanilla's own fishing trash list (no new content). Missing
    -- entries just no-op (AddItem is pcall'd), so this stays safe if an id moves.
    TRASH = { "Base.Seaweed", "Base.TinCanEmpty", "Base.WaterBottleEmpty",
              "Base.RippedSheetsDirty", "Base.BrokenFishingNet" },

    -- fallback bait set, used only if vanilla's Fishing.lure.All isn't indexed yet
    BAIT_FALLBACK = {
        ["Base.Worm"] = true, ["Base.Maggots"] = true, ["Base.Cricket"] = true,
        ["Base.Grasshopper"] = true, ["Base.Cockroach"] = true, ["Base.Leech"] = true,
        ["Base.Snail"] = true, ["Base.Slug"] = true, ["Base.Crayfish"] = true,
        ["Base.Shrimp"] = true, ["Base.Tadpole"] = true, ["Base.BaitFish"] = true,
    },

    -- custom catch list: real B42 fish items (icons / models / cooking come
    -- free), PZ RPG's own level gates and pick weights. minLvl gates a species
    -- in; weight is its relative commonness once unlocked. Bigger fish sit
    -- behind higher levels -- that's the "size" progression for this slice;
    -- size-within-species scaling is FISH-3.
    SPECIES = {
        { id = "Base.BaitFish",        minLvl = 1,  weight = 14 },
        { id = "Base.Bluegill",        minLvl = 1,  weight = 22 },
        { id = "Base.GreenSunfish",    minLvl = 1,  weight = 16 },
        { id = "Base.RedearSunfish",   minLvl = 3,  weight = 14 },
        { id = "Base.YellowPerch",     minLvl = 6,  weight = 15 },
        { id = "Base.WhiteCrappie",    minLvl = 9,  weight = 12 },
        { id = "Base.BlackCrappie",    minLvl = 9,  weight = 11 },
        { id = "Base.WhiteBass",       minLvl = 15, weight = 9  },
        { id = "Base.SmallmouthBass",  minLvl = 18, weight = 8  },
        { id = "Base.LargemouthBass",  minLvl = 22, weight = 8  },
        { id = "Base.SpottedBass",     minLvl = 26, weight = 6  },
        { id = "Base.Sauger",          minLvl = 30, weight = 5  },
        { id = "Base.FreshwaterDrum",  minLvl = 38, weight = 4  },
        { id = "Base.Walleye",         minLvl = 42, weight = 4  },
        { id = "Base.ChannelCatfish",  minLvl = 46, weight = 4  },
        { id = "Base.StripedBass",     minLvl = 52, weight = 3  },
        { id = "Base.BlueCatfish",     minLvl = 58, weight = 3  },
        { id = "Base.FlatheadCatfish", minLvl = 64, weight = 2  },
        { id = "Base.Muskellunge",     minLvl = 74, weight = 2  },
        { id = "Base.Paddlefish",      minLvl = 82, weight = 1  },
        { id = "Base.AligatorGar",     minLvl = 90, weight = 1  },
    },
}
PZRPG.tuning.fishing = TUNING

---------------------------------------------------------------------------
-- level curves
---------------------------------------------------------------------------

local function frac(level)
    return math.max(0, math.min(1, (level or 1) / 100))
end

--- Chance (0..1) that one cast cycle produces a bite.
function PZRPG.fishingBiteChance(level, hasBait)
    local c = TUNING.BITE_BASE
        + (TUNING.BITE_MAX - TUNING.BITE_BASE) * (frac(level) ^ TUNING.BITE_EXP)
    if hasBait then c = c + TUNING.BAIT_BONUS end
    return math.max(0, math.min(0.98, c))
end

--- Chance (0..1) that a bite is a real fish rather than junk / a miss.
function PZRPG.fishingFishChance(level)
    return TUNING.FISH_BASE
        + (TUNING.FISH_MAX - TUNING.FISH_BASE) * (frac(level) ^ TUNING.FISH_EXP)
end

--- Chance (0..1) to actually land a hooked fish. Climbs with level; a species
--- with a high minLvl (bigger, rarer) is harder to bring in.
function PZRPG.fishingLandChance(level, speciesId)
    local c = TUNING.LAND_BASE
        + (TUNING.LAND_MAX - TUNING.LAND_BASE) * (frac(level) ^ TUNING.LAND_EXP)
    if speciesId then
        for _, s in ipairs(TUNING.SPECIES) do
            if s.id == speciesId then
                c = c - (s.minLvl / 100) * (TUNING.LAND_TROPHY_PENALTY or 0)
                break
            end
        end
    end
    return math.max(0.15, math.min(0.98, c))
end

--- Speech bubble when a fish gets away -- a random line from TUNING.LOSS_LINES.
function PZRPG.sayFishingLoss(player)
    if not player then return end
    local lines = TUNING.LOSS_LINES
    if type(lines) ~= "table" or #lines == 0 then return end
    pcall(function() player:Say(lines[ZombRand(#lines) + 1]) end)
end

--- Action ticks for one cast cycle at this level.
function PZRPG.fishingCastTicks(level)
    local span = TUNING.CAST_TICKS_BASE - TUNING.CAST_TICKS_MIN
    return math.floor(TUNING.CAST_TICKS_BASE - span * (frac(level) ^ TUNING.CAST_TICKS_EXP))
end

---------------------------------------------------------------------------
-- world / inventory helpers (shared with the context menu, PZRPG_44)
---------------------------------------------------------------------------

--- True if the square carries the vanilla `water` terrain flag.
function PZRPG.isFishableSquare(sq)
    if not sq then return false end
    local ok, res = pcall(function()
        local p = sq:getProperties()
        return p and p:has(IsoFlagType.water)
    end)
    return ok and res == true
end

--- First vanilla lure item anywhere in the player's inventory, or nil.
function PZRPG.findFishingBait(player)
    if not player then return nil end
    local inv = player:getInventory()
    if not inv then return nil end
    local ok, item = pcall(function()
        return inv:getFirstEvalRecurse(function(it)
            if not it then return false end
            local ft = it:getFullType()
            if Fishing and Fishing.IsLure and Fishing.IsLure(ft) then return true end
            return TUNING.BAIT_FALLBACK[ft] == true
        end)
    end)
    return ok and item or nil
end

--- Weighted, level-gated species pick from TUNING.SPECIES. Returns a full type.
function PZRPG.rollFishSpecies(level)
    local pool, total = {}, 0
    for _, s in ipairs(TUNING.SPECIES) do
        if (level or 1) >= s.minLvl then
            total = total + s.weight
            pool[#pool + 1] = s
        end
    end
    if total <= 0 then return "Base.Bluegill" end
    local r, acc = ZombRand(total) + 1, 0
    for _, s in ipairs(pool) do
        acc = acc + s.weight
        if r <= acc then return s.id end
    end
    return pool[#pool].id
end

---------------------------------------------------------------------------
-- one cast cycle (called by ISPZRPGFishAction)
---------------------------------------------------------------------------

--- Resolve a single cast: roll the bite, hand out XP + any item, consume bait.
--- Returns "catch" / "trash" / "miss" / "nibble" for the caller's feedback.
function PZRPG.resolveFishingCast(player)
    if not player then return "nibble" end

    local level   = PZRPG.getLevel(player, "fishing")
    local bait    = PZRPG.findFishingBait(player)
    local hasBait = bait ~= nil

    -- no bite this cycle
    if ZombRandFloat(0, 1) >= PZRPG.fishingBiteChance(level, hasBait) then
        PZRPG.addXp(player, "fishing", TUNING.XP_NIBBLE)
        return "nibble"
    end

    -- a bite -- burn one bait item if we have one
    if hasBait then
        pcall(function() player:getInventory():Remove(bait) end)
    end

    -- a fish is on the line -- but you still have to land it
    if ZombRandFloat(0, 1) < PZRPG.fishingFishChance(level) then
        local id = PZRPG.rollFishSpecies(level)

        if ZombRandFloat(0, 1) >= PZRPG.fishingLandChance(level, id) then
            PZRPG.addXp(player, "fishing", TUNING.XP_LOST)
            PZRPG.sayFishingLoss(player)
            return "lost"
        end

        local item
        pcall(function() item = player:getInventory():AddItem(id) end)  -- OnCreate=Fishing.onCreateFish shapes size + name
        PZRPG.addXp(player, "fishing", TUNING.XP_CATCH)
        pcall(function()
            if HaloTextHelper and HaloTextHelper.addTextWithArrow and item then
                HaloTextHelper.addTextWithArrow(player, item:getName(), true, HaloTextHelper.getGoodColor())
            end
        end)
        return "catch"
    end

    -- a nibble that stole the bait, or a snag
    if ZombRandFloat(0, 1) < TUNING.MISS_SHARE then
        PZRPG.addXp(player, "fishing", TUNING.XP_NIBBLE)
        PZRPG.sayFishingLoss(player)
        return "miss"
    end

    -- junk
    local trash = (Fishing and type(Fishing.trashItems) == "table" and #Fishing.trashItems > 0)
        and Fishing.trashItems or TUNING.TRASH
    local tid = trash[ZombRand(#trash) + 1]
    pcall(function() player:getInventory():AddItem(tid) end)
    PZRPG.addXp(player, "fishing", TUNING.XP_TRASH)
    return "trash"
end

---------------------------------------------------------------------------

PZRPG.registerSkill{
    id            = "fishing",
    name          = "Fishing",
    category      = "gathering",
    order         = 40,
    mirrorVanilla = { Fishing = 1.0 },
    vanillaXp     = { Fitness = 0.04 },
    describe      = function(level)
        local dry  = math.floor(PZRPG.fishingBiteChance(level, false) * 100 + 0.5)
        local bait = math.floor(PZRPG.fishingBiteChance(level, true)  * 100 + 0.5)
        return ("Fish at any water's edge with a rod. Bite chance %d%% (%d%% with bait).")
            :format(dry, bait)
    end,
}
