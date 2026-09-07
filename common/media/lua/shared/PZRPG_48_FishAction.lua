--[[
    PZ RPG  --  ISPZRPGFishAction  (FISH-2)

    A normal timed action against a water square. Duration is
    CASTS_PER_ACTION cast cycles, each cycle's length scaling down with Fishing
    level. As the job delta crosses each 1/N mark we resolve one cast --
    PZRPG.resolveFishingCast (PZRPG_13) -> bite roll, XP, maybe a fish -- so a
    "+N Fishing" bubble ticks up as you fish. complete() resolves any leftover
    casts and, if still valid, re-queues a fresh action so you keep fishing
    until you walk away or bottom out your endurance.

    isValid() re-checks every tick: a working fishing rod still HELD, the water
    square still water and in reach, endurance not empty. stopOnWalk / stopOnRun
    end it cleanly (and skip the re-queue -- that only fires on a real finish).

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
    self.casts = 0
    self:setActionAnim("Loot")   -- TODO(FISH-3): a real fishing cast/idle anim
    pcall(function() self.character:playSound("LureHitWater") end)
end

local function resolveOne(self)
    self.casts = (self.casts or 0) + 1
    local result = "nibble"
    pcall(function() result = PZRPG.resolveFishingCast(self.character) or "nibble" end)
    pcall(function() self.character:getEmitter():playSound("LureHitWater") end)
    addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 4, 3)
end

function ISPZRPGFishAction:update()
    self.character:faceLocationF(self.waterX + 0.5, self.waterY + 0.5)

    local need    = self.castsNeeded or 3
    local crossed = math.floor(self:getJobDelta() * need)
    while (self.casts or 0) < crossed do
        resolveOne(self)
    end
end

function ISPZRPGFishAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISPZRPGFishAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISPZRPGFishAction:complete()
    local need = self.castsNeeded or 3
    while (self.casts or 0) < need do
        resolveOne(self)
    end

    -- keep fishing: re-queue only on a clean finish (a walk-off calls stop())
    if ISTimedActionQueue and self:isValid() then
        ISTimedActionQueue.add(ISPZRPGFishAction:new(self.character, self.waterSq))
    end
    return true
end

function ISPZRPGFishAction:getDuration()
    local lvl = 1
    pcall(function() lvl = PZRPG.getLevel(self.character, "fishing") end)
    local t = tuning()
    return (t.CASTS_PER_ACTION or 3) * PZRPG.fishingCastTicks(lvl)
end

function ISPZRPGFishAction:new(character, waterSq)
    local o = ISBaseTimedAction.new(self, character)
    o.character        = character
    o.waterSq          = waterSq
    o.waterX           = waterSq:getX()
    o.waterY           = waterSq:getY()
    o.castsNeeded      = (tuning().CASTS_PER_ACTION or 3)
    o.casts            = 0
    o.maxTime          = o:getDuration()
    o.caloriesModifier = 2
    o.forceProgressBar = true
    o.stopOnWalk       = true
    o.stopOnRun        = true
    return o
end
