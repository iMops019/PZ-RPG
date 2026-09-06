--[[
    PZ RPG  --  Woodcutting

    WC-1: trains on every axe swing during a tree-chop. In B42 the dedicated
    chop uses ISChopTreeAction (NOT the OnWeaponHitTree event -- that only fires
    when you whack a tree in melee), so we wrap ISChopTreeAction:animEvent and
    count each 'ChopTree' anim event = one swing landing.

    No level effect yet -- chop speed is WC-2, yield is WC-3.
    Also trickles a little vanilla Fitness / Strength XP (docs/DESIGN.md sec 3a).

    Load order: _10_. ISChopTreeAction (shared/TimedActions/) loads AFTER this,
    so the wrap is installed on OnGameBoot (and directly on a -debug reload,
    when the class already exists). PZRPG.wrapAction is idempotent.
]]

-- Live-tunable from the -debug console:  PZRPG.tuning.woodcutting.XP_PER_SWING = 0.8
PZRPG.tuning = PZRPG.tuning or {}
local TUNING = PZRPG.tuning.woodcutting or {
    XP_PER_SWING = 1.5,    -- Woodcutting xp per axe swing (~10 swings/tree -> ~15 xp/tree)
}
PZRPG.tuning.woodcutting = TUNING

PZRPG.registerSkill{
    id        = "woodcutting",
    name      = "Woodcutting",
    category  = "gathering",
    order     = 10,
    vanillaXp = { Fitness = 0.15, Strength = 0.08 },
    describe  = function(level)
        return "Chopping trees. Trains on every axe swing. (Speed & yield bonuses: WC-2/WC-3.)"
    end,
}

local function onChopSwing(action, event)
    if event ~= "ChopTree" then return end

    local ch = action.character
    if not ch then return end
    local ok, pn = pcall(function() return ch:getPlayerNum() end)
    if not ok or pn ~= 0 then return end

    PZRPG.addXp(ch, "woodcutting", TUNING.XP_PER_SWING)

    if getDebug and getDebug() then
        PZRPG.log(("woodcutting: +%d  (xp=%s lvl=%s)"):format(
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
