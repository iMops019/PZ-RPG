--[[
    PZ RPG  --  Mining : world context menu  (MINE-1)

    Right-click a world boulder -> add "Mine Boulder" IF the player has a
    working pickaxe somewhere in their inventory. If the boulder is on cooldown
    the option shows greyed-out with the time left.

    The whole handler is pcall-wrapped -- a bug in here must never stop the
    vanilla context menu from opening.

    Load order: client _45_ -> after PZRPG_46 (shared) is defined.
]]

local function predicatePickaxe(item)
    return item ~= nil and not item:isBroken() and item:hasTag(ItemTag.PICK_AXE)
end

local function findBoulder(worldobjects)
    for _, obj in ipairs(worldobjects) do
        local ok, name = pcall(function()
            local s = obj:getSprite()
            return s and s:getName() or nil
        end)
        if ok and PZRPG.isBoulderSprite(name) then
            return obj
        end
    end
    return nil
end

local function fmtHours(h)
    h = math.ceil(h)
    if h >= 24 then
        local d = math.floor(h / 24)
        local r = h % 24
        return (r > 0) and ("%dd %dh"):format(d, r) or ("%dd"):format(d)
    end
    return ("%dh"):format(math.max(1, h))
end

--- context option callback: (worldobjects, playerObj, boulder)
local function onMineSelected(worldobjects, playerObj, boulder)
    local ok, err = pcall(function()
        if not boulder or boulder:getObjectIndex() == -1 or not boulder:getSquare() then return end
        if PZRPG.boulderCooldown(boulder) > 0 then return end
        if not luautils.walkAdj(playerObj, boulder:getSquare(), true) then return end

        if not predicatePickaxe(playerObj:getPrimaryHandItem()) then
            local pick = playerObj:getInventory():getFirstEvalRecurse(predicatePickaxe)
            if not pick then return end
            ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), pick,
                true, not playerObj:getSecondaryHandItem())
        end

        ISTimedActionQueue.add(ISMineBoulderAction:new(playerObj, boulder))
    end)
    if not ok then PZRPG.log("mining: mine-select failed -- " .. tostring(err)) end
end

local function buildOptions(player, context, worldobjects)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    local boulder = findBoulder(worldobjects)
    if not boulder then return end

    -- hard gate: no pickaxe anywhere in inventory -> no option at all
    if not playerObj:getInventory():getFirstEvalRecurse(predicatePickaxe) then return end

    local cd = PZRPG.boulderCooldown(boulder)
    if cd and cd > 0 then
        local opt = context:addOption(("Mine Boulder  (depleted -- %s)"):format(fmtHours(cd)), nil, nil)
        if opt then opt.notAvailable = true end
        return
    end

    context:addOption("Mine Boulder", worldobjects, onMineSelected, playerObj, boulder)
end

PZRPG.hookEvent("OnFillWorldObjectContextMenu", "mining.context", function(player, context, worldobjects, test)
    local ok, err = pcall(buildOptions, player, context, worldobjects)
    if not ok then PZRPG.log("mining: context build failed -- " .. tostring(err)) end
end)
