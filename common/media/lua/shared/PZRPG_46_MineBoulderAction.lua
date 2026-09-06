--[[
    PZ RPG  --  ISMineBoulderAction  (MINE-1)

    Swing-based, exactly like chopping a tree: no fixed duration, the Chop_tree
    anim fires a 'ChopTree' event per swing, and on each swing we award Mining
    XP and count a hit. After HITS_TO_DEPLETE swings the boulder yields its
    stone / ore and goes on cooldown.

    isValid() re-checks every tick that a working pickaxe is still HELD and the
    boulder is real and not on cooldown -- lose the pickaxe mid-swing and it
    stops cleanly.

    Load order: shared _46_. Referenced by the client context menu (PZRPG_45).
]]

require "TimedActions/ISBaseTimedAction"

ISMineBoulderAction = ISBaseTimedAction:derive("ISMineBoulderAction")

local function heldPickaxe(character)
    local h = character:getPrimaryHandItem()
    if h and not h:isBroken() and h:hasTag(ItemTag.PICK_AXE) then return h end
    return nil
end

local function hitsNeeded()
    return (PZRPG.tuning and PZRPG.tuning.mining and PZRPG.tuning.mining.HITS_TO_DEPLETE) or 6
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

function ISMineBoulderAction:update()
    self.character:faceThisObject(self.boulder)
    if instanceof(self.character, "IsoPlayer") then
        self.character:setMetabolicTarget(Metabolics.ForestryAxe)
    end
    local pick = heldPickaxe(self.character)
    if pick then pick:setJobDelta(self:getJobDelta()) end

    -- safety: if the anim never fires 'ChopTree' for some reason, don't hang
    self.ticks = (self.ticks or 0) + 1
    if self.ticks > 1200 then
        pcall(function()
            PZRPG.mineBoulderReward(self.character)
            PZRPG.markBoulderMined(self.boulder)
        end)
        self:forceComplete()
    end
end

function ISMineBoulderAction:start()
    self.pick = heldPickaxe(self.character)
    self.hits = 0
    if self.pick then
        self.pick:setJobType("Mine Boulder")
        self.pick:setJobDelta(0.0)
    end
    if self.character:isTimedActionInstant() then
        self.hits = hitsNeeded() - 1        -- one swing finishes it
    end
    self:setActionAnim(CharacterActionAnims.Chop_tree)
end

function ISMineBoulderAction:stop()
    if self.pick then self.pick:setJobDelta(0.0) end
    ISBaseTimedAction.stop(self)
end

function ISMineBoulderAction:perform()
    if self.pick then self.pick:setJobDelta(0.0) end
    ISBaseTimedAction.perform(self)
end

-- one swing landed
function ISMineBoulderAction:animEvent(event, parameter)
    if event ~= "ChopTree" then return end

    self.hits = (self.hits or 0) + 1

    local tuning = (PZRPG.tuning and PZRPG.tuning.mining) or {}
    PZRPG.addXp(self.character, "mining", tuning.XP_PER_HIT or 2)

    -- world sound + a little pick wear per swing
    pcall(function() self.character:getEmitter():playSound("ChopTree") end)
    addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 12, 8)
    if self.pick and self.pick.getCondition and ZombRand(8) == 0 then
        self.pick:setCondition(math.max(0, self.pick:getCondition() - 1))
    end

    if self.hits >= hitsNeeded() then
        pcall(function()
            PZRPG.mineBoulderReward(self.character)
            PZRPG.markBoulderMined(self.boulder)
        end)
        self:forceComplete()
    end
end

function ISMineBoulderAction:complete()
    return true
end

function ISMineBoulderAction:getDuration()
    return -1                                -- anim-driven, like ISChopTreeAction
end

-- progress bar fills per swing rather than by time
function ISMineBoulderAction:getJobDelta()
    return math.min(1, (self.hits or 0) / hitsNeeded())
end

function ISMineBoulderAction:new(character, boulder)
    local o = ISBaseTimedAction.new(self, character)
    o.character        = character
    o.boulder          = boulder
    o.hits             = 0
    o.maxTime          = -1
    o.caloriesModifier = 8
    o.forceProgressBar = true
    o.stopOnWalk       = true
    o.stopOnRun        = true
    return o
end
