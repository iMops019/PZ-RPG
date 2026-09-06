--[[
    PZ RPG  --  ISMineBoulderAction  (MINE-1)

    A normal timed action against a world boulder (the Chop_tree anim plays for
    the visual). Duration = HITS_TO_DEPLETE * TICKS_PER_HIT. As the job delta
    crosses each 1/HITS mark we award a "swing" -- Mining XP + sound + a little
    pick wear -- so you see "+2 Mining" per hit. complete() drops the yield and
    puts the boulder on cooldown.

    isValid() re-checks every tick that a working pickaxe is still HELD, the
    boulder is real, and it isn't on cooldown -- lose the pickaxe or walk off
    and it stops cleanly (stopOnWalk / stopOnRun).

    Load order: shared _46_. Referenced by the client context menu (PZRPG_45).
]]

require "TimedActions/ISBaseTimedAction"

ISMineBoulderAction = ISBaseTimedAction:derive("ISMineBoulderAction")

local function tuning()
    return (PZRPG.tuning and PZRPG.tuning.mining) or {}
end

local function heldPickaxe(character)
    local h = character:getPrimaryHandItem()
    if h and not h:isBroken() and h:hasTag(ItemTag.PICK_AXE) then return h end
    return nil
end

function ISMineBoulderAction:isValid()
    return self.boulder ~= nil
        and self.boulder:getObjectIndex() ~= -1
        and heldPickaxe(self.character) ~= nil
        and self.character:isEnduranceSufficientForAction()
        and PZRPG.boulderCooldown(self.boulder) <= 0
end

function ISMineBoulderAction:waitToStart()
    self.character:faceThisObject(self.boulder)
    return self.character:shouldBeTurning()
end

function ISMineBoulderAction:start()
    self.pick = heldPickaxe(self.character)
    self.swings = 0
    if self.pick then
        self.pick:setJobType("Mine Boulder")
        self.pick:setJobDelta(0.0)
    end
    self:setActionAnim(CharacterActionAnims.Chop_tree)
end

function ISMineBoulderAction:update()
    self.character:faceThisObject(self.boulder)
    if instanceof(self.character, "IsoPlayer") then
        self.character:setMetabolicTarget(Metabolics.ForestryAxe)
    end
    if self.pick then self.pick:setJobDelta(self:getJobDelta()) end

    -- award each swing as the job delta crosses its 1/N mark
    local need = self.hitsNeeded or 6
    local crossed = math.floor(self:getJobDelta() * need)
    while (self.swings or 0) < crossed do
        self.swings = (self.swings or 0) + 1
        local t = tuning()
        PZRPG.addXp(self.character, "mining", t.XP_PER_HIT or 2)
        pcall(function() self.character:getEmitter():playSound("ChopTree") end)
        addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 12, 8)
        if self.pick and self.pick.getCondition and ZombRand(8) == 0 then
            self.pick:setCondition(math.max(0, self.pick:getCondition() - 1))
        end
    end
end

function ISMineBoulderAction:stop()
    if self.pick then self.pick:setJobDelta(0.0) end
    ISBaseTimedAction.stop(self)
end

function ISMineBoulderAction:perform()
    if self.pick then self.pick:setJobDelta(0.0) end
    ISBaseTimedAction.perform(self)
end

function ISMineBoulderAction:complete()
    pcall(function()
        PZRPG.mineBoulderReward(self.character)
        PZRPG.markBoulderMined(self.boulder)
    end)
    return true
end

function ISMineBoulderAction:getDuration()
    local t = tuning()
    return (t.HITS_TO_DEPLETE or 6) * (t.TICKS_PER_HIT or 55)
end

function ISMineBoulderAction:new(character, boulder)
    local o = ISBaseTimedAction.new(self, character)
    o.character        = character
    o.boulder          = boulder
    o.hitsNeeded       = (tuning().HITS_TO_DEPLETE or 6)
    o.swings           = 0
    o.maxTime          = o:getDuration()
    o.caloriesModifier = 8
    o.forceProgressBar = true
    o.stopOnWalk       = true
    o.stopOnRun        = true
    return o
end
