--[[
    PZ RPG  --  Fishing : world context menu  (FISH-2)

    Right-click on or beside water -> "Fish Here" IF the player has a working
    fishing rod somewhere in their inventory. The rod is auto-equipped (like the
    pickaxe for mining) and the player walks to the water's edge first if they
    aren't already in reach.

    The whole handler is pcall-wrapped -- a bug in here must never stop the
    vanilla context menu from opening.

    Load order: client _44_ -> after PZRPG_48 (shared action) and PZRPG_13
    (shared helpers).
]]

local function predicateRod(item)
    return item ~= nil and not item:isBroken() and item:hasTag(ItemTag.FISHING_ROD)
end

local function reach()
    return (PZRPG.tuning.fishing and PZRPG.tuning.fishing.REACH) or 4
end

--- Nearest fishable water square to the click, within reach of the player.
local function findWater(playerObj, worldobjects)
    local pSq = playerObj:getCurrentSquare()
    if not pSq then return nil end
    local cell = getCell()

    local best, bestD
    local function consider(sq)
        if not PZRPG.isFishableSquare(sq) then return end
        local d = sq:DistToProper(pSq)
        if d > reach() then return end
        if not bestD or d < bestD then best, bestD = sq, d end
    end

    for _, obj in ipairs(worldobjects) do
        local ok, sq = pcall(function() return obj:getSquare() end)
        if ok and sq then
            consider(sq)
            -- you usually click the shore tile; the water is next to it
            for dx = -1, 1 do
                for dy = -1, 1 do
                    if dx ~= 0 or dy ~= 0 then
                        consider(cell:getGridSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ()))
                    end
                end
            end
        end
    end
    return best
end

--- context option callback: (worldobjects, playerObj, waterSq)
local function onFishSelected(worldobjects, playerObj, waterSq)
    local ok, err = pcall(function()
        if not PZRPG.isFishableSquare(waterSq) then return end

        local pSq = playerObj:getCurrentSquare()
        if not pSq or waterSq:DistToProper(pSq) > reach() then
            if not luautils.walkAdj(playerObj, waterSq, true) then return end
        end

        if not predicateRod(playerObj:getPrimaryHandItem()) then
            local rod = playerObj:getInventory():getFirstEvalRecurse(predicateRod)
            if not rod then return end
            ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), rod,
                true, not playerObj:getSecondaryHandItem())
        end

        ISTimedActionQueue.add(ISPZRPGFishAction:new(playerObj, waterSq))
    end)
    if not ok then PZRPG.log("fishing: fish-select failed -- " .. tostring(err)) end
end

local function buildOptions(player, context, worldobjects)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    local water = findWater(playerObj, worldobjects)
    if not water then return end

    -- hard gate: no rod anywhere in inventory -> no option at all
    if not playerObj:getInventory():getFirstEvalRecurse(predicateRod) then return end

    local label = PZRPG.findFishingBait(playerObj) and "Fish Here  (bait ready)" or "Fish Here"
    context:addOption(label, worldobjects, onFishSelected, playerObj, water)
end

PZRPG.hookEvent("OnFillWorldObjectContextMenu", "fishing.context", function(player, context, worldobjects, test)
    local ok, err = pcall(buildOptions, player, context, worldobjects)
    if not ok then PZRPG.log("fishing: context build failed -- " .. tostring(err)) end
end)
