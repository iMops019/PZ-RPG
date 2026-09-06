--[[
    PZ RPG  --  Core.

    Owns the PZRPG namespace and the primitives every other file builds on:
      - PZRPG.log            prefixed print
      - PZRPG.hookEvent       reload-safe Events registration
      - PZRPG.VERSION / SAVE_VERSION
      - PZRPG.curve           the shared 1-100 XP curve

    The rest of Core is split by responsibility into sibling shared files:
      _01_Save            per-character save table + migrations
      _02_SkillRegistry  PZRPG.registerSkill / PZRPG.skills
      _03_Xp             getXp / getLevel / addXp / level-up

    Still to come in Phase 1 (docs/ROADMAP.md): the character sheet.

    Load order: the _00_ prefix makes this the first PZ RPG file the game runs.
]]

PZRPG = PZRPG or {}

PZRPG.VERSION      = "0.0.1"
PZRPG.SAVE_VERSION = 1              -- bumped when the getModData().PZRPG shape changes

--- Prefixed print so console.txt / the debug console tell one story.
function PZRPG.log(msg)
    print("[PZ RPG] " .. tostring(msg))
end

-- Reload-safe Events registration. Skill modules register through this so a
-- -debug hot-reload doesn't stack duplicate handlers. Kept here from day one.
PZRPG._handlers = PZRPG._handlers or {}

function PZRPG.hookEvent(eventName, key, fn)
    local event = Events[eventName]
    if not event then
        PZRPG.log("hookEvent: unknown event '" .. tostring(eventName) .. "'")
        return
    end
    local prev = PZRPG._handlers[key]
    if prev and Events[prev.event] then
        Events[prev.event].Remove(prev.fn)
    end
    event.Add(fn)
    PZRPG._handlers[key] = { event = eventName, fn = fn }
end

---------------------------------------------------------------------------
-- XP curve  (docs/DESIGN.md sec 4, docs/ARCHITECTURE.md sec 2)
--
-- One curve, shared by every skill. Level is ALWAYS derived from XP -- it is
-- never stored -- so these two knobs can be retuned with no save migration.
--
--   xpForLevel(n) = floor(COEFF * (n - 1) ^ EXPONENT)
--
-- A gently accelerating curve: cheap early levels, a long tail to 100.
-- Defaults put the total XP for level 100 near 1.46M and level 50 near 252k
-- (~17% of the climb), so per-action XP rewards can stay small whole numbers.
-- Nothing awards XP yet; tune these in-game once Woodcutting lands (Phase 2).
---------------------------------------------------------------------------

PZRPG.curve = PZRPG.curve or {}

PZRPG.curve.MAX_LEVEL = 100
PZRPG.curve.COEFF     = 15
PZRPG.curve.EXPONENT  = 2.5

--- Total XP required to *be* the given level. Level 1 costs 0; clamped at MAX_LEVEL.
function PZRPG.curve.xpForLevel(level)
    if not level or level <= 1 then return 0 end
    if level > PZRPG.curve.MAX_LEVEL then level = PZRPG.curve.MAX_LEVEL end
    return math.floor(PZRPG.curve.COEFF * ((level - 1) ^ PZRPG.curve.EXPONENT))
end

--- Level (1..MAX_LEVEL) for a raw XP total. xpForLevel is monotonic, so a
--- linear walk is exact and plenty fast for a 100-entry curve.
function PZRPG.curve.levelForXp(xp)
    if not xp or xp <= 0 then return 1 end
    for level = 2, PZRPG.curve.MAX_LEVEL do
        if xp < PZRPG.curve.xpForLevel(level) then
            return level - 1
        end
    end
    return PZRPG.curve.MAX_LEVEL
end

--- Dev check: dump sample rows + a round-trip test to the log. Call from the
--- -debug Lua console:  PZRPG.curve.dump()
function PZRPG.curve.dump()
    PZRPG.log(("curve: COEFF=%s EXPONENT=%s MAX=%d")
        :format(tostring(PZRPG.curve.COEFF), tostring(PZRPG.curve.EXPONENT), PZRPG.curve.MAX_LEVEL))
    for _, lv in ipairs({ 1, 2, 5, 10, 25, 50, 75, 99, 100 }) do
        PZRPG.log(("  L%-3d  total xp %d"):format(lv, PZRPG.curve.xpForLevel(lv)))
    end
    for _, lv in ipairs({ 1, 2, 50, 99, 100 }) do
        local x = PZRPG.curve.xpForLevel(lv)
        PZRPG.log(("  levelForXp(%d) -> %d  (expect %d)"):format(x, PZRPG.curve.levelForXp(x), lv))
    end
end

---------------------------------------------------------------------------

PZRPG.log("Core loaded (v" .. PZRPG.VERSION .. ", save v" .. PZRPG.SAVE_VERSION .. ")")

PZRPG.hookEvent("OnGameBoot", "core.boot", function()
    PZRPG.log("OnGameBoot - mod discovered and running.")
    -- In a -debug session, print the curve so it can be eyeballed in console.txt
    -- without opening the Lua console. Silent in normal play.
    if getDebug and getDebug() then
        PZRPG.curve.dump()
    end
end)
