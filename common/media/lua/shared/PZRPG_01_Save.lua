--[[
    PZ RPG  --  Save layer  (docs/ARCHITECTURE.md sec 3)

    Per-character store at  player:getModData().PZRPG :

        { version = <SAVE_VERSION>, skills = { woodcutting = { xp = 0 }, ... } }

    - Auto-serialized with the save, unique per character, dies with the
      character (DESIGN.md sec 9 Q6, current lean).
    - Level is NEVER stored -- always PZRPG.curve.levelForXp(entry.xp).
    - Per-skill entries are created lazily by the XP accessors (PZRPG_03_Xp),
      so a skill added to the mod list after a save exists just works on next
      access -- no migration needed for that case.

    Load order: _01_ -> after Core (_00_), before the registry and XP files.
]]

PZRPG = PZRPG or {}

---------------------------------------------------------------------------
-- Migrations
--
-- Key = the version you are migrating FROM. The step mutates `data` in place
-- and leaves it shaped for version+1. NEVER wipe, never drop a skill's xp.
-- When the shape changes: add a step here AND bump PZRPG.SAVE_VERSION in Core.
---------------------------------------------------------------------------

PZRPG._migrations = PZRPG._migrations or {
    -- [1] = function(data) ... end,   -- 1 -> 2, when we first change the shape
}

local function migrate(data)
    while data.version < PZRPG.SAVE_VERSION do
        local from = data.version
        local step = PZRPG._migrations[from]
        if step then
            step(data)
            PZRPG.log(("save: migrated v%d -> v%d"):format(from, from + 1))
        else
            -- No step: the change from `from` was purely additive (a new skill,
            -- a new optional field). Just advance the marker.
            PZRPG.log(("save: no migration step for v%d; advancing marker to v%d")
                :format(from, from + 1))
        end
        data.version = from + 1
    end
end

---------------------------------------------------------------------------
-- Accessor
---------------------------------------------------------------------------

--- The player's PZ RPG save table, created and migrated on demand.
--- Every read/write of PZ RPG data goes through here -- never getModData() raw.
function PZRPG.getData(player)
    if not player then return nil end

    local md = player:getModData()
    local data = md.PZRPG

    if not data then
        data = { version = PZRPG.SAVE_VERSION, skills = {} }
        md.PZRPG = data
        PZRPG.log("save: created character data (v" .. PZRPG.SAVE_VERSION .. ")")
        return data
    end

    -- Defensive: a hand-edited or partially-written table.
    if type(data.version) ~= "number" then data.version = 1 end
    if type(data.skills) ~= "table" then data.skills = {} end

    if data.version < PZRPG.SAVE_VERSION then
        migrate(data)
    elseif data.version > PZRPG.SAVE_VERSION then
        -- Loaded a save from a newer build. Don't touch it; just warn.
        PZRPG.log(("save: data version v%d is newer than this build's v%d -- leaving as-is")
            :format(data.version, PZRPG.SAVE_VERSION))
    end

    return data
end

---------------------------------------------------------------------------
-- Lifecycle: build/migrate the table as soon as we have a player
---------------------------------------------------------------------------

local function initFor(player)
    if not player then return end
    local data = PZRPG.getData(player)
    if getDebug and getDebug() then
        local n = 0
        for _ in pairs(data.skills) do n = n + 1 end
        PZRPG.log(("save: ready (v%d, %d skill entr%s)")
            :format(data.version, n, n == 1 and "y" or "ies"))
    end
end

PZRPG.hookEvent("OnCreatePlayer", "save.oncreateplayer", function(playerIndex)
    initFor(getSpecificPlayer(playerIndex))
end)

PZRPG.hookEvent("OnGameStart", "save.ongamestart", function()
    initFor(getPlayer())
end)
