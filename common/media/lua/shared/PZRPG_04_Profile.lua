--[[
    PZ RPG  --  Character profile  (the RP half of the character sheet)

    Vanilla already knows the character's name, profession and traits -- we only
    read those (PZRPG_04 helpers below). The profile stores the RP-only fields
    the player types on the sheet, per character, in the existing save table:

        getModData().PZRPG.profile = {
            created = false,           -- set true when the welcome flow is done
            sheetMode = "docked",      -- "docked" | "toggle"   (PZRPG_50 sheet)
            sheetX = nil, sheetY = nil,-- last window position
            fields = { age = "34", alias = "Rook", bio = "...", ... },
        }

    `profile` is additive -- getData() tolerates it being absent, so no
    SAVE_VERSION bump / migration is needed.

    Load order: _04_ -> after Save (_01_). Shared so the sheet (client) and any
    future server-side check see the same shape.
]]

PZRPG = PZRPG or {}

--- The editable RP fields, in sheet order.
---   key       stable id, also the fields{} table key
---   label     shown on the sheet
---   lines     text-entry height in lines (1 = single line)
---   max       max characters
---   numeric   digits only (still stored as a string)
PZRPG.PROFILE_FIELDS = {
    { key = "alias",       label = "Alias / callsign",   lines = 1,  max = 40 },
    { key = "age",         label = "Age",                lines = 1,  max = 3,  numeric = true },
    { key = "sex",         label = "Sex / gender",       lines = 1,  max = 24 },
    { key = "height",      label = "Height & build",     lines = 1,  max = 60 },
    { key = "hometown",    label = "Hometown / origin",  lines = 1,  max = 60 },
    { key = "occupation",  label = "Occupation (before)",lines = 1,  max = 60 },
    { key = "goal",        label = "Goal / motivation",  lines = 2,  max = 140 },
    { key = "personality", label = "Personality / quirks",lines = 4, max = 400 },
    { key = "bio",         label = "Short bio",          lines = 6,  max = 1200 },
}

local DEFAULT_PROFILE = "docked"

--- The profile sub-table, created lazily. Always returns a table.
function PZRPG.getProfile(player)
    local data = PZRPG.getData(player)
    if not data then return { created = false, fields = {} } end

    local p = data.profile
    if type(p) ~= "table" then
        p = { created = false, sheetMode = DEFAULT_PROFILE, fields = {} }
        data.profile = p
    end
    if type(p.fields) ~= "table" then p.fields = {} end
    if p.sheetMode ~= "toggle" and p.sheetMode ~= "docked" then
        p.sheetMode = DEFAULT_PROFILE
    end
    return p
end

function PZRPG.getProfileField(player, key)
    return PZRPG.getProfile(player).fields[key] or ""
end

function PZRPG.setProfileField(player, key, value)
    if type(key) ~= "string" then return end
    PZRPG.getProfile(player).fields[key] = value and tostring(value) or nil
end

function PZRPG.isProfileCreated(player)
    return PZRPG.getProfile(player).created == true
end

function PZRPG.markProfileCreated(player)
    PZRPG.getProfile(player).created = true
    PZRPG.log("profile: marked created")
end

---------------------------------------------------------------------------
-- Read-only views of the vanilla character (name / profession / traits)
---------------------------------------------------------------------------

local function descriptor(player)
    if not player then return nil end
    local ok, d = pcall(function() return player:getDescriptor() end)
    return ok and d or nil
end

function PZRPG.vanillaName(player)
    local d = descriptor(player)
    if not d then return "?" end
    local ok, name = pcall(function()
        return ((d:getForename() or "") .. " " .. (d:getSurname() or "")):match("^%s*(.-)%s*$")
    end)
    return (ok and name ~= "" and name) or "?"
end

function PZRPG.vanillaProfession(player)
    local d = descriptor(player)
    if not d then return "Unemployed" end
    local ok, name = pcall(function()
        local prof = d:getCharacterProfession()
        if not prof then return "Unemployed" end
        local def = CharacterProfessionDefinition
            and CharacterProfessionDefinition.getCharacterProfessionDefinition(prof)
        if def then
            local ui = def:getUIName()
            if ui and ui ~= "" then return ui end
        end
        return prof:getName() or "Unemployed"
    end)
    return (ok and name) or "Unemployed"
end

--- Array of { label = "...", desc = "..." } for the character's known traits.
function PZRPG.vanillaTraits(player)
    local out = {}
    local ok = pcall(function()
        local known = player:getCharacterTraits():getKnownTraits()
        if not known then return end
        for i = 0, known:size() - 1 do
            local t   = known:get(i)
            local def = CharacterTraitDefinition
                and CharacterTraitDefinition.getCharacterTraitDefinition(t)
            local label = (def and def:getLabel()) or tostring(t)
            local desc  = (def and def:getDescription()) or ""
            out[#out + 1] = { label = label, desc = desc }
        end
    end)
    if not ok then return {} end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

--- Hours the character has survived (float).
function PZRPG.hoursSurvived(player)
    if player and player.getHoursSurvived then
        local ok, h = pcall(function() return player:getHoursSurvived() end)
        if ok and type(h) == "number" then return h end
    end
    return 0
end

--- Whole days the character has survived.
function PZRPG.daysSurvived(player)
    return math.floor(PZRPG.hoursSurvived(player) / 24)
end
