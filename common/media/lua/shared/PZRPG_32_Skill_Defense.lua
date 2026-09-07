--[[
    PZ RPG  --  Defense

    CMB-1: no vanilla "got hit" event exists, so we watch overall body health
    each player-update tick -- a real drop (took damage and survived) trains
    Defense.

    DEF-EFFECT-1: that same drop is now also *mitigated*. On a qualifying hit:
      - roll a block: chance BLK_MAX*(lvl/100)^BLK_EXP (0 -> 20% at L100). On a
        block, the whole tick's health loss is handed straight back -- the hit
        "glanced off". A "Defense: blocked!" halo fires.
      - otherwise, hand back drop * RED (RED = RED_MAX*(lvl/100)^RED_EXP,
        0 -> 30% at L100) -- the hit just hurt less.
    The refund goes in on the same tick the drop is seen, so the health bar
    barely flickers. We only ever touch *general* health -- the wound itself
    (scratch / bleed / fracture) still lands; softening the wound is
    Constitution's lane (CONST-EFFECT-2).

    Kept conservative on purpose -- PZ death is the point (DESIGN.md 5). Even a
    maxed Defense is ~44% average damage reduction, a bite still infects, you
    still bleed. Block/dodge as a real pre-hit animation whiff is DEF-EFFECT-2.

    Small drops (hunger / moodle noise) and a huge single-tick drop (death /
    debug) are both ignored.

    Load order: _32_ -> after the _0N_ Core files.
]]

PZRPG.tuning = PZRPG.tuning or {}
local TUNING = PZRPG.tuning.defense or {
    XP_PER_HP = 250,      -- Defense xp per point of body health lost to damage
    MIN_DROP  = 0.5,      -- ignore drops smaller than this (not real damage)
    MAX_DROP  = 15,       -- ignore drops bigger than this in one tick (death / debug)

    -- Mitigation (DEF-EFFECT-1)
    RED_MAX   = 0.30,     -- non-block hits: hand back this fraction of the loss at L100
    RED_EXP   = 1.3,      -- ramp (flat early)
    BLK_MAX   = 0.20,     -- block chance at L100 (full refund of the tick's loss)
    BLK_EXP   = 1.5,
}
PZRPG.tuning.defense = TUNING

local function mitigationFrac(level)
    local frac = math.max(0, math.min(1, (level or 1) / 100))
    return TUNING.RED_MAX * (frac ^ TUNING.RED_EXP)
end
local function blockChance(level)
    local frac = math.max(0, math.min(1, (level or 1) / 100))
    return TUNING.BLK_MAX * (frac ^ TUNING.BLK_EXP)
end

PZRPG.registerSkill{
    id       = "defense",
    name     = "Defense",
    category = "combat",
    order    = 100,
    describe = function(level)
        return ("Taking hits and living. -%d%% damage taken, %d%% chance to block a hit outright at this level.")
            :format(math.floor(mitigationFrac(level) * 100 + 0.5),
                    math.floor(blockChance(level) * 100 + 0.5))
    end,
}

---------------------------------------------------------------------------
-- DEF-EFFECT-1 + CMB-1 XP: one health-drop watcher does both
---------------------------------------------------------------------------

PZRPG.hookEvent("OnPlayerUpdate", "defense.update", function(player)
    if not player or player:getPlayerNum() ~= 0 then return end

    local ok, bd = pcall(function() return player:getBodyDamage() end)
    if not ok or not bd then return end
    local ok2, hp = pcall(function() return bd:getHealth() end)
    if not ok2 or type(hp) ~= "number" then return end

    local prev = PZRPG._defenseLastHp
    if prev == nil then
        PZRPG._defenseLastHp = hp
        return
    end

    local drop = prev - hp
    if drop < TUNING.MIN_DROP or drop > TUNING.MAX_DROP then
        PZRPG._defenseLastHp = hp
        return
    end

    -- CMB-1: train on the hit
    PZRPG.addXp(player, "defense", drop * TUNING.XP_PER_HP)

    -- DEF-EFFECT-1: mitigate the hit
    local level  = PZRPG.getLevel(player, "defense")
    local blocked = ZombRand(1000) < blockChance(level) * 1000
    local refund  = blocked and drop or (drop * mitigationFrac(level))

    if refund > 0 then
        pcall(function() bd:AddGeneralHealth(refund) end)
        if blocked then
            pcall(function()
                if HaloTextHelper and HaloTextHelper.addTextWithArrow then
                    HaloTextHelper.addTextWithArrow(player, "Defense: blocked!", true,
                        HaloTextHelper.getGoodColor())
                end
            end)
            PZRPG.log(("defense: blocked a hit (level %d, %.2f hp)"):format(level, drop))
        end
        -- account for the refund so next tick's drop isn't a phantom
        PZRPG._defenseLastHp = hp + refund
    else
        PZRPG._defenseLastHp = hp
    end
end)
