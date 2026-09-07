--[[
    PZ RPG  --  Cooking

    XP  (COOK-2): trains off vanilla Cooking XP via PZRPG_06_VanillaMirror
    (mirrorVanilla = { Cooking = 1.0 }). Vanilla already scales its Cooking XP by
    how involved the recipe is, so the mirror weight *is* the "bonus for real
    cooking" knob -- no separate hook. Reheating a can barely moves it; making a
    stew does.

    COOK-3 (level effect): a cooked meal now heals. When you finish eating a
    COOKED, non-burnt, non-rotten food, PZ RPG starts a short general-health
    regen -- total HP scales with the meal's size (its base hunger value) and,
    on a shallow curve, your Cooking level: about the same as a novice at L1,
    ~2x by L30, ~2.5x at L100. Delivered over HEAL_DURATION_MIN game-minutes so
    it reads as "the food did you good", not an instant potion. Canned / raw /
    burnt food heals nothing. (Field Recipe buff meals -- COOK-4 -- will layer
    their fixed effect on top of this.)

    Load order: _23_ -> after the _0N_ Core files. ISEatFoodAction lives under
    shared/TimedActions/ which loads *after* us, so the wrap waits for
    OnGameBoot (and runs directly too -- wrapAction is idempotent).
]]

PZRPG.tuning = PZRPG.tuning or {}
local TUNING = PZRPG.tuning.cooking or {
    -- COOK-3: cooked-food heal
    HEAL_K           = 0.35,   -- HP per (|baseHunger| * 100) of the meal, before the level mult
    HEAL_CAP_BASE    = 26,     -- cap on the pre-mult HP from one meal
    HEAL_MULT_MAX    = 2.5,    -- level multiplier at L100 (L1 ~= 1.0)
    HEAL_MULT_EXP    = 0.45,   -- ramp: ~2x by L30
    HEAL_DURATION_MIN = 45,    -- game-minutes to deliver the full heal
    HEAL_MIN         = 1,      -- skip totals below this

    XP_PREPARE       = 60,     -- COOK-4b: Cooking XP for preparing a Field Recipe dish
}
PZRPG.tuning.cooking = TUNING

local function frac(level)
    return math.max(0, math.min(1, (level or 1) / 100))
end

--- Cooking-level multiplier on a cooked meal's heal (≈1.0 at L1 → HEAL_MULT_MAX at L100).
local function healMult(level)
    return 1 + (TUNING.HEAL_MULT_MAX - 1) * (frac(level) ^ TUNING.HEAL_MULT_EXP)
end

PZRPG.registerSkill{
    id            = "cooking",
    name          = "Cooking",
    category      = "production",
    order         = 75,
    mirrorVanilla = { Cooking = 1.0 },
    describe      = function(level)
        local m = healMult(level)
        return ("Preparing food. A cooked meal heals you — about %d%% more per meal at your level "
            .. "(x%.1f). Trains as you cook."):format(math.floor((m - 1) * 100 + 0.5), m)
    end,
}

---------------------------------------------------------------------------
-- COOK-3: "a cooked meal heals" -- a short general-health regen after eating
---------------------------------------------------------------------------

-- PZRPG._cookHeal = { remaining = <HP left to give>, perHour = <HP/game-hour>,
--                     lastHrs = <world-age hours at last tick> }
-- Single local-player buff; eating again refreshes it at the higher rate.

local function startHeal(totalHp)
    local durHrs = math.max(0.05, (TUNING.HEAL_DURATION_MIN or 45) / 60)
    local perHour = totalHp / durHrs
    local gt = getGameTime()
    local now = gt and gt:getWorldAgeHours() or 0
    local cur = PZRPG._cookHeal
    if cur and cur.remaining and cur.remaining > 0 then
        -- refresh: keep whatever's left, take the better rate, restart the clock
        PZRPG._cookHeal = {
            remaining = cur.remaining + totalHp,
            perHour   = math.max(cur.perHour or 0, perHour),
            lastHrs   = now,
        }
    else
        PZRPG._cookHeal = { remaining = totalHp, perHour = perHour, lastHrs = now }
    end
end

local function onAte(action)
    local ch = action and action.character
    if not ch or ch ~= getSpecificPlayer(0) then return end
    local item = action.item
    if not item then return end
    pcall(function()
        if not instanceof(item, "Food") then return end
        if item:isRotten() then return end
        local pct = action.percentage or 1

        -- COOK-4b: a Field Recipe dish -> fixed heal + its timed buff, and
        -- skip the size-based COOK-3 heal (the recipe defines the payload).
        local rid = item:getModData() and item:getModData().PZRPG_recipe
        local recipe = rid and PZRPG.cooking and PZRPG.cooking.recipes and PZRPG.cooking.recipes[rid]
        if recipe then
            if (recipe.heal or 0) > 0 then startHeal(recipe.heal * pct) end
            if recipe.buffs and PZRPG.buffs then
                PZRPG.buffs.apply(ch, recipe.buffs, (recipe.durationHrs or 1) * pct, "recipe:" .. rid)
            end
            return
        end

        -- COOK-3: a plain cooked meal heals, scaled by size x level.
        if not item:isCooked() or item:isBurnt() then return end
        local bh = math.abs(item:getBaseHunger() or 0)
        if bh <= 0.01 then return end
        local lvl   = PZRPG.getLevel(ch, "cooking")
        local base  = math.min(TUNING.HEAL_CAP_BASE, TUNING.HEAL_K * bh * 100)
        local total = base * healMult(lvl) * pct
        if total >= (TUNING.HEAL_MIN or 1) then startHeal(total) end
    end)
end

local function onHealTick(player)
    if not player or player ~= getSpecificPlayer(0) then return end
    local h = PZRPG._cookHeal
    if not h then return end
    local gt = getGameTime()
    if not gt then return end

    local now = gt:getWorldAgeHours()
    local dt  = now - (h.lastHrs or now)
    h.lastHrs = now
    if dt <= 0 or dt > 1 then return end   -- clock jump / load / paused

    local ok, bd = pcall(function() return player:getBodyDamage() end)
    if not ok or not bd then return end

    local step = math.min(h.remaining, h.perHour * dt)
    if step > 0 then
        local okH, hp = pcall(function() return bd:getHealth() end)
        if okH and hp and hp < 100 then
            pcall(function() bd:AddGeneralHealth(step) end)
        end
        h.remaining = h.remaining - step
    end
    if h.remaining <= 0.01 then PZRPG._cookHeal = nil end
end

---------------------------------------------------------------------------

local function install()
    if ISEatFoodAction then PZRPG.wrapAction(ISEatFoodAction, "complete", onAte) end
end

install()                                                     -- -debug reload / late-load
PZRPG.hookEvent("OnGameBoot", "cooking.wrap", install)          -- first boot (load order)
PZRPG.hookEvent("OnPlayerUpdate", "cooking.heal", onHealTick)   -- COOK-3 regen delivery
