--[[
    PZ RPG  --  Field Recipe context menu  (COOK-4b)

    Right-click a heat source (lit campfire, activated stove/oven, lit BBQ) ->
    "Prepare Field Recipe" submenu listing every recipe you KNOW. Ones you can
    make right now are clickable; the rest show greyed with the reason
    (need Cooking N, need 2x Potato, ...).

    The whole handler is pcall-wrapped -- a bug here must never stop the vanilla
    context menu opening.

    Load order: client _49_ -> after PZRPG_25 / _26 (shared) are defined.
]]

local function isHeatObject(obj)
    local ok, res = pcall(function()
        if instanceof(obj, "IsoStove") and obj:isActivated() then return true end
        if instanceof(obj, "IsoFireplace") then return true end
        local n = obj:getName() or (obj:getSprite() and obj:getSprite():getName()) or ""
        if type(n) == "string" and (n == "Campfire" or n:find("BBQ")) then return true end
        return false
    end)
    return ok and res == true
end

local function anyHeat(worldobjects)
    for _, obj in ipairs(worldobjects) do
        if isHeatObject(obj) then return true end
    end
    return false
end

local function onPrepareSelected(worldobjects, playerObj, recipe)
    local ok, err = pcall(function()
        if PZRPG.cooking.missingFor(playerObj, recipe) ~= nil then return end
        if not PZRPG.cooking.heatSourceNear(playerObj) then return end
        ISTimedActionQueue.add(ISPZRPGPrepareDishAction:new(playerObj, recipe))
    end)
    if not ok then PZRPG.log("cooking: prepare-select failed -- " .. tostring(err)) end
end

local function buildOptions(player, context, worldobjects)
    local playerObj = getSpecificPlayer(player)
    if not playerObj or not PZRPG.cooking then return end
    if not anyHeat(worldobjects) then return end

    local known = PZRPG.cooking.knownList(playerObj)
    if #known == 0 then return end

    local parent = context:addOption("Prepare Field Recipe", nil, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)

    for _, recipe in ipairs(known) do
        local reason = PZRPG.cooking.missingFor(playerObj, recipe)
        local opt = sub:addOption(recipe.name, worldobjects, onPrepareSelected, playerObj, recipe)
        local tip = ISToolTip:new()
        tip:initialise()
        local parts = {}
        for _, spec in ipairs(recipe.ingredients or {}) do
            parts[#parts + 1] = (spec.count or 1) .. "x " ..
                (spec.type and spec.type:gsub("^Base%.", "") or spec.tag or spec.foodType or "?")
        end
        local nbuffs = recipe.buffs and #recipe.buffs or 0
        tip.description = table.concat(parts, ", ")
            .. " <LINE> Cooking " .. (recipe.minLevel or 1)
            .. " <LINE> " .. nbuffs .. " buff(s), " .. (recipe.durationHrs or 0) .. "h"
        opt.toolTip = tip
        if reason ~= nil then
            opt.notAvailable = true
            tip.description = tip.description .. " <LINE> <RGB:1,0.4,0.4>(" .. reason .. ")"
        end
    end
end

PZRPG.hookEvent("OnFillWorldObjectContextMenu", "cooking.context", function(player, context, worldobjects, test)
    local ok, err = pcall(buildOptions, player, context, worldobjects)
    if not ok then PZRPG.log("cooking: context build failed -- " .. tostring(err)) end
end)
