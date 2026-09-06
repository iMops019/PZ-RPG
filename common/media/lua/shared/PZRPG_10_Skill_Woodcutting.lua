--[[
    PZ RPG  --  Woodcutting

    WC-1: trains on every axe swing during a tree-chop. B42's dedicated chop
    uses ISChopTreeAction (NOT the OnWeaponHitTree event -- that only fires when
    you whack a tree in melee), so we wrap ISChopTreeAction:animEvent and count
    each 'ChopTree' anim event = one swing landing.

    WC-2: a small, level-scaled chop-speed bonus. After each vanilla swing we
    shave a little extra off the tree's remaining health -- imperceptible early,
    noticeable by the later levels. We never take it below 1, so the felling
    blow is always vanilla's (log-drop / topple logic stays untouched).

    Yield bonus is WC-3. Also trickles vanilla Fitness / Strength (DESIGN 3a).

    Load order: _10_. ISChopTreeAction (shared/TimedActions/) loads AFTER this,
    so the wrap is installed on OnGameBoot (and directly on a -debug reload).
]]

-- Live-tunable:  PZRPG.tuning.woodcutting.XP_PER_SWING = 0.8   etc.
PZRPG.tuning = PZRPG.tuning or {}
local TUNING = PZRPG.tuning.woodcutting or {
    XP_PER_SWING     = 1.5,   -- xp per axe swing (~10 swings/tree -> ~15 xp/tree)

    -- Chop speed: extra tree damage per swing = base * SPEED_MAX * (lvl/100)^SPEED_EXP
    SPEED_MAX = 0.80,          -- +80% chop damage per swing at level 100
    SPEED_EXP = 1.8,           -- ramp shape: flat early, accelerating
}
PZRPG.tuning.woodcutting = TUNING

local function speedMult(level)
    local frac = math.max(0, math.min(1, (level or 1) / 100))
    return 1 + TUNING.SPEED_MAX * (frac ^ TUNING.SPEED_EXP)
end

PZRPG.registerSkill{
    id        = "woodcutting",
    name      = "Woodcutting",
    category  = "gathering",
    order     = 10,
    vanillaXp = { Fitness = 0.15, Strength = 0.08 },
    describe  = function(level)
        return ("Chopping trees. Chop speed +%d%% at this level. (Yield bonus: WC-3.)")
            :format(math.floor((speedMult(level) - 1) * 100 + 0.5))
    end,
}

local function onChopSwing(action, event)
    if event ~= "ChopTree" then return end

    local ch = action.character
    if not ch then return end
    local ok, pn = pcall(function() return ch:getPlayerNum() end)
    if not ok or pn ~= 0 then return end

    -- WC-1: xp
    PZRPG.addXp(ch, "woodcutting", TUNING.XP_PER_SWING)

    -- WC-2: chop-speed bonus
    local tree, axe = action.tree, action.axe
    pcall(function()
        if not tree or tree:getObjectIndex() < 0 or not axe then return end
        local level = PZRPG.getLevel(ch, "woodcutting")
        local extra = (speedMult(level) - 1) * (axe:getTreeDamage() or 0)
        if extra <= 0 then return end
        local h = tree:getHealth()
        if h and h > 1 then
            tree:setHealth(math.max(1, math.floor(h - extra)))
        end
    end)

    if getDebug and getDebug() then
        PZRPG.log(("woodcutting: +%.1f  (xp=%s lvl=%s)"):format(
            TUNING.XP_PER_SWING, tostring(PZRPG.getXp(ch, "woodcutting")),
            tostring(PZRPG.getLevel(ch, "woodcutting"))))
    end
end

local function install()
    if ISChopTreeAction then
        PZRPG.wrapAction(ISChopTreeAction, "animEvent", onChopSwing)
    end
end

install()                                                   -- -debug reload / late-load
PZRPG.hookEvent("OnGameBoot", "woodcutting.wrap", install)   -- first boot (load order)
