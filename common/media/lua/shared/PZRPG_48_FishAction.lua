--[[
    PZ RPG  --  ISPZRPGFishAction  (FISH-2)

    One cast cycle per queued action: the progress bar is you casting and
    waiting, and the outcome is resolved once, at the end -- PZRPG.resolveFishingCast
    (PZRPG_13) -> bite roll, XP, maybe a fish (or a "lost it" line). On a clean
    finish it re-queues a fresh action so you keep fishing until you walk away
    (stopOnWalk / stopOnRun) or bottom out your endurance.

    Animation: equipping a rod auto-spawns vanilla's own FishingManager
    (OnEquipPrimary), which drives the cast / idle fishing pose whenever you're
    holding a rod facing water -- which is exactly what this action sets up. We
    leave that alone and just run "Loot" as the base action anim under it.
    (FISH-4 tried to drive FishingStage ourselves + suppress vanilla's manager;
    it killed the animation and was reverted -- vanilla's layer already does it.)

    isValid() re-checks every tick: a working fishing rod still HELD, the water
    square still water and in reach, endurance not empty.

    Load order: shared _48_. Referenced by the client context menu (PZRPG_44).
]]

require "TimedActions/ISBaseTimedAction"

ISPZRPGFishAction = ISBaseTimedAction:derive("ISPZRPGFishAction")

local function tuning()
    return (PZRPG.tuning and PZRPG.tuning.fishing) or {}
end

local function heldRod(character)
    local h = character:getPrimaryHandItem()
    if h and not h:isBroken() and h:hasTag(ItemTag.FISHING_ROD) then return h end
    return nil
end

function ISPZRPGFishAction:isValid()
    local sq = self.character:getCurrentSquare()
    return heldRod(self.character) ~= nil
        and PZRPG.isFishableSquare(self.waterSq)
        and sq ~= nil
        and self.waterSq:DistToProper(sq) <= (tuning().REACH or 4)
        and self.character:isEnduranceSufficientForAction()
end

function ISPZRPGFishAction:waitToStart()
    self.character:faceLocationF(self.waterX + 0.5, self.waterY + 0.5)
    return self.character:shouldBeTurning()
end

function ISPZRPGFishAction:start()
    self:setActionAnim("Loot")
    pcall(function() self.character:playSound("CastFishingLine") end)
end

function ISPZRPGFishAction:update()
    self.character:faceLocationF(self.waterX + 0.5, self.waterY + 0.5)
end

function ISPZRPGFishAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISPZRPGFishAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISPZRPGFishAction:complete()
    pcall(function() PZRPG.resolveFishingCast(self.character) end)
    pcall(function() self.character:getEmitter():playSound("LureHitWater") end)
    addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 4, 3)

    -- keep fishing: re-queue only on a clean finish (a walk-off calls stop())
    if ISTimedActionQueue and self:isValid() then
        ISTimedActionQueue.add(ISPZRPGFishAction:new(self.character, self.waterSq))
    end
    return true
end

function ISPZRPGFishAction:getDuration()
    local lvl = 1
    pcall(function() lvl = PZRPG.getLevel(self.character, "fishing") end)
    return PZRPG.fishingCastTicks(lvl)
end

function ISPZRPGFishAction:new(character, waterSq)
    local o = ISBaseTimedAction.new(self, character)
    o.character        = character
    o.waterSq          = waterSq
    o.waterX           = waterSq:getX()
    o.waterY           = waterSq:getY()
    o.maxTime          = o:getDuration()
    o.caloriesModifier = 2
    o.forceProgressBar = true
    o.stopOnWalk       = true
    o.stopOnRun        = true
    return o
end
