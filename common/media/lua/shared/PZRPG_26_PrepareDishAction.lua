--[[
    PZ RPG  --  ISPZRPGPrepareDishAction  (COOK-4b)

    A plain timed action: stand near a heat source, "cook" for the recipe's
    cookMinutes (real action ticks), then PZRPG.cooking.prepare consumes the
    ingredients and drops the dish. Re-checks each tick that the ingredients
    and a heat source are still there (walk off / burn the fire out and it
    stops cleanly).

    Heat source = a lit campfire, or an activated stove / oven / BBQ, within
    REACH tiles. Detection mirrors FIRE-4's per-square campfire scan plus a
    scan for IsoStove that is activated.

    Load order: shared _26_ -> after PZRPG_25 (recipe model). Context menu is
    client PZRPG_49.
]]

require "TimedActions/ISBaseTimedAction"

PZRPG = PZRPG or {}
PZRPG.cooking = PZRPG.cooking or {}

ISPZRPGPrepareDishAction = ISBaseTimedAction:derive("ISPZRPGPrepareDishAction")

local REACH = 2

--- A usable heat source within REACH tiles of the player?
function PZRPG.cooking.heatSourceNear(player)
    local cell = getCell()
    if not player or not cell then return false end
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    for x = px - REACH, px + REACH do
        for y = py - REACH, py + REACH do
            local sq = cell:getGridSquare(x, y, pz)
            if sq then
                -- lit campfire
                if type(CCampfireSystem) == "table" and CCampfireSystem.instance then
                    local ok, cf = pcall(function()
                        return CCampfireSystem.instance:getLuaObjectOnSquare(sq)
                    end)
                    if ok and cf and cf.isLit then return true end
                end
                -- activated stove / oven, or a lit BBQ
                local hot = false
                pcall(function()
                    local objs = sq:getObjects()
                    for i = 0, objs:size() - 1 do
                        local o = objs:get(i)
                        if o and instanceof(o, "IsoStove") and o:isActivated() then hot = true; return end
                        local md = o and o.getModData and o:getModData()
                        if md and md.BBQ and md.BBQ.isLit then hot = true; return end
                    end
                end)
                if hot then return true end
            end
        end
    end
    return false
end

function ISPZRPGPrepareDishAction:isValid()
    return self.recipe ~= nil
        and PZRPG.cooking.missingFor(self.character, self.recipe) == nil
        and PZRPG.cooking.heatSourceNear(self.character)
        and self.character:isEnduranceSufficientForAction()
end

function ISPZRPGPrepareDishAction:update()
    pcall(function()
        if Metabolics and Metabolics.LightDomestic then
            self.character:setMetabolicTarget(Metabolics.LightDomestic)
        end
    end)
end

function ISPZRPGPrepareDishAction:start()
    pcall(function()
        self:setActionAnim("Loot")
        self.character:SetVariable("LootPosition", "Low")
    end)
end

function ISPZRPGPrepareDishAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISPZRPGPrepareDishAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISPZRPGPrepareDishAction:complete()
    local dish = PZRPG.cooking.prepare(self.character, self.recipe)
    if dish then
        pcall(function() self.character:Say("That should do it.") end)
        if HaloTextHelper and HaloTextHelper.addTextWithArrow then
            pcall(function()
                HaloTextHelper.addTextWithArrow(self.character, self.recipe.name, true,
                    HaloTextHelper.getGoodColor())
            end)
        end
    end
    return true
end

function ISPZRPGPrepareDishAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    local mins = (self.recipe and self.recipe.cookMinutes) or 40
    -- ~12 action ticks per recipe-minute, clamped so nothing is absurd
    return math.max(200, math.min(2400, mins * 12))
end

function ISPZRPGPrepareDishAction:new(character, recipe)
    local o = ISBaseTimedAction.new(self, character)
    o.character        = character
    o.recipe           = recipe
    o.maxTime          = o:getDuration()
    o.caloriesModifier = 4
    o.forceProgressBar = true
    o.stopOnWalk       = true
    o.stopOnRun        = true
    return o
end
