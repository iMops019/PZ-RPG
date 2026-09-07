--[[
    PZ RPG  --  Field Recipes  (COOK-4b)

    The data model + the known-recipe store + "can I make this / make it".

    A Field Recipe is a discovered meal that grants a fixed timed buff (via the
    COOK-4a buff engine) plus a fixed heal on top of vanilla nutrition. Level
    gates *cooking* the recipe (minLevel), never the payload -- the buff is the
    same at L10 or L100 (decided 2026-09-06).

        PZRPG.cooking.recipes                    id -> recipe def
        PZRPG.cooking.isKnown(player, id)        -> bool
        PZRPG.cooking.learn(player, id)          -> bool (false if already known)
        PZRPG.cooking.knownList(player)          -> array of recipe defs, known + sorted
        PZRPG.cooking.missingFor(player, recipe) -> nil if craftable, else a reason string
        PZRPG.cooking.prepare(player, recipe)    -> the dish item, or nil  (consumes ingredients)

    Recipe def:
        { id, name, result = "PZRPG.HeartyFishStew",
          minLevel = 3, cookMinutes = 40,
          ingredients = { { foodType = "Fish", count = 1 },
                          { type = "Base.Potato", count = 2 },
                          { type = "Base.Onion" } },
          heal = 22,                 -- fixed HP, delivered like COOK-3's regen
          buffs = { { t = "mending", mag = 0.02 }, { t = "toughness", mag = 0.08 } },
          durationHrs = 2,
          starter = true }           -- auto-known at character creation

    Load order: shared _25_ -> after Core + PZRPG_09 Buffs + PZRPG_23 Cooking.
    Item scripts: common/media/scripts/pzrpg_food.txt.
]]

PZRPG.cooking = PZRPG.cooking or {}

---------------------------------------------------------------------------
-- Recipe catalogue  (the 3 starters; world-loot recipes get added by COOK-5)
---------------------------------------------------------------------------

PZRPG.cooking.recipes = PZRPG.cooking.recipes or {
    HeartyFishStew = {
        id = "HeartyFishStew", name = "Hearty Fish Stew",
        result = "PZRPG.HeartyFishStew", minLevel = 2, cookMinutes = 35,
        ingredients = {
            { tag = "fishmeat", count = 1 },
            { type = "Base.Potato", count = 2 },
            { type = "Base.Onion", count = 1 },
        },
        heal = 20,
        buffs = { { t = "mending", mag = 0.020 }, { t = "toughness", mag = 0.06 } },
        durationHrs = 2,
        starter = true,
    },
    VenisonPotRoast = {
        id = "VenisonPotRoast", name = "Venison Pot Roast",
        result = "PZRPG.VenisonPotRoast", minLevel = 3, cookMinutes = 50,
        ingredients = {
            { type = "Base.Venison", count = 1 },
            { type = "Base.Carrots", count = 1 },
            { type = "Base.Potato", count = 1 },
        },
        heal = 24,
        buffs = { { t = "strong", mag = 0.10 }, { t = "vigor", mag = 0.12 } },
        durationHrs = 2,
        starter = true,
    },
    RoastChickenDinner = {
        id = "RoastChickenDinner", name = "Roast Chicken Dinner",
        result = "PZRPG.RoastChickenDinner", minLevel = 3, cookMinutes = 45,
        ingredients = {
            { type = "Base.Chicken", count = 1 },
            { type = "Base.Potato", count = 1 },
            { foodType = "Vegetables", count = 1 },
        },
        heal = 22,
        buffs = { { t = "scholar", mag = 0.15 }, { t = "steady", mag = 0.30 } },
        durationHrs = 3,
        starter = true,
    },
}

---------------------------------------------------------------------------
-- Known-recipe store  (additive to the save table -- no SAVE_VERSION bump)
---------------------------------------------------------------------------

local function knownTable(player)
    local data = PZRPG.getData(player)
    if not data then return nil end
    data.cooking = data.cooking or {}
    data.cooking.known = data.cooking.known or {}
    return data.cooking.known
end

function PZRPG.cooking.isKnown(player, id)
    local k = knownTable(player)
    return k ~= nil and k[id] == true
end

function PZRPG.cooking.learn(player, id)
    if not PZRPG.cooking.recipes[id] then return false end
    local k = knownTable(player)
    if not k or k[id] then return false end
    k[id] = true
    PZRPG.log("cooking: learned recipe " .. id)
    return true
end

function PZRPG.cooking.knownList(player)
    local out = {}
    for id, def in pairs(PZRPG.cooking.recipes) do
        if PZRPG.cooking.isKnown(player, id) then out[#out + 1] = def end
    end
    pcall(function()
        table.sort(out, function(a, b) return (a.minLevel or 0) < (b.minLevel or 0) end)
    end)
    return out
end

--- Grant every recipe flagged `starter`. Safe to call repeatedly.
local function grantStarters(player)
    if not player then return end
    for id, def in pairs(PZRPG.cooking.recipes) do
        if def.starter then PZRPG.cooking.learn(player, id) end
    end
end

PZRPG.hookEvent("OnCreatePlayer", "cooking.starters.create", function(pi)
    grantStarters(getSpecificPlayer(pi))
end)
PZRPG.hookEvent("OnGameStart", "cooking.starters.start", function()
    grantStarters(getSpecificPlayer(0))
end)

---------------------------------------------------------------------------
-- Ingredient matching / consumption
---------------------------------------------------------------------------

--- Does inventory item `it` satisfy ingredient spec `spec`?
---   spec.type     exact full type ("Base.Potato" or bare "Potato")
---   spec.tag      item tag ("fishmeat", ...)
---   spec.foodType Food:getFoodType() string ("Vegetables", "Fruits", "Meat", ...)
local function itemMatches(it, spec)
    if not it then return false end
    if spec.type then
        local want = spec.type
        if not want:find("%.") then want = "Base." .. want end
        return it:getFullType() == want
    end
    if spec.tag then
        local ok, has = pcall(function() return it:hasTag(spec.tag) end)
        return ok and has == true
    end
    if spec.foodType then
        local ok, ft = pcall(function() return it:getFoodType() end)
        return ok and ft ~= nil and tostring(ft) == spec.foodType
    end
    return false
end

--- Collect up to `count` matching items from the player's inventory.
local function gather(inv, spec)
    local found = {}
    local need  = spec.count or 1
    local ok = pcall(function()
        local items = inv:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if itemMatches(it, spec) and not (it.isRotten and it:isRotten()) then
                found[#found + 1] = it
                if #found >= need then break end
            end
        end
    end)
    return ok and found or {}
end

--- nil if the player can prepare `recipe` right now, else a short reason.
function PZRPG.cooking.missingFor(player, recipe)
    if not player or not recipe then return "no recipe" end
    if not PZRPG.cooking.isKnown(player, recipe.id) then return "recipe not known" end
    local lvl = PZRPG.getLevel(player, "cooking")
    if lvl < (recipe.minLevel or 1) then
        return ("needs Cooking %d"):format(recipe.minLevel)
    end
    local inv = player:getInventory()
    if not inv then return "no inventory" end
    for _, spec in ipairs(recipe.ingredients or {}) do
        if #gather(inv, spec) < (spec.count or 1) then
            local label = spec.type or spec.tag or spec.foodType or "ingredient"
            return "need " .. (spec.count or 1) .. "x " .. label:gsub("^Base%.", "")
        end
    end
    return nil
end

--- Consume the ingredients and drop the dish in the player's inventory.
--- Returns the dish item or nil. Stamps getModData().PZRPG_recipe.
function PZRPG.cooking.prepare(player, recipe)
    if PZRPG.cooking.missingFor(player, recipe) ~= nil then return nil end
    local inv = player:getInventory()

    for _, spec in ipairs(recipe.ingredients or {}) do
        for _, it in ipairs(gather(inv, spec)) do
            pcall(function() inv:Remove(it) end)
        end
    end

    local dish
    pcall(function() dish = inv:AddItem(recipe.result) end)
    if dish then
        pcall(function()
            dish:getModData().PZRPG_recipe = recipe.id
            if dish.setCooked then dish:setCooked(true) end
        end)
        PZRPG.addXp(player, "cooking", (PZRPG.tuning.cooking and PZRPG.tuning.cooking.XP_PREPARE) or 60)
    end
    return dish
end
