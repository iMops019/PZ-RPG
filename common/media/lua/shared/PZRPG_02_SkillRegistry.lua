--[[
    PZ RPG  --  Skill registry  (docs/ARCHITECTURE.md sec 4)

    A skill module calls PZRPG.registerSkill{...} at load time. Core tracks it,
    the character sheet renders it, XP routes to it. Core never knows what a
    skill *does* -- only that it exists, has an id, a name, a sort order, and an
    optional describe(level) blurb.

    This is the seam that would become a mod boundary if we ever split Core out:
    a skill imports only registerSkill / addXp / curve / getLevel.

    Load order: _02_ -> after Core + Save, before the XP accessors and any
    skill module (_10_+).
]]

PZRPG = PZRPG or {}

PZRPG.skills = PZRPG.skills or {}   -- id -> def table; survives a -debug reload

--- Skill categories, in sheet order (docs/DESIGN.md sec 5). A skill def's
--- `category` is one of these ids; anything else (or nil) falls under "other".
PZRPG.CATEGORIES = {
    { id = "gathering",  label = "Gathering",  order = 10 },
    { id = "production",  label = "Production", order = 20 },
    { id = "combat",      label = "Combat",     order = 30 },
    { id = "dexterity",   label = "Dexterity",  order = 40 },
    { id = "other",       label = "Other",      order = 999 },
}

local function categoryDef(id)
    for _, c in ipairs(PZRPG.CATEGORIES) do
        if c.id == id then return c end
    end
    return PZRPG.CATEGORIES[#PZRPG.CATEGORIES]   -- "other"
end

--- Register (or, idempotently, re-register) a skill.
--- def: { id = "woodcutting", name = "Woodcutting", order = 10,
---        icon = "media/ui/PZRPG/woodcutting.png",   -- optional, for the sheet
---        describe = function(level) return "..." end } -- optional blurb
function PZRPG.registerSkill(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or def.id == "" then
        PZRPG.log("registerSkill: ignored -- def needs a non-empty string id")
        return nil
    end

    def.name     = def.name or def.id
    def.order    = tonumber(def.order) or 100
    def.category = categoryDef(def.category).id   -- normalise to a known id

    local replacing = PZRPG.skills[def.id] ~= nil
    PZRPG.skills[def.id] = def

    PZRPG.log(("registered skill '%s' (%s, %s, order %d)%s")
        :format(def.id, def.name, def.category, def.order, replacing and " [replaced]" or ""))
    return def
end

--- Registered skills as an array, sorted by order then id. For the sheet.
function PZRPG.skillsSorted()
    local list = {}
    for _, def in pairs(PZRPG.skills) do
        list[#list + 1] = def
    end
    table.sort(list, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.id < b.id
    end)
    return list
end

--- Skills grouped for the sheet: an array of { category = <catDef>, skills = {...} }
--- in category order, skipping categories with no registered skills.
function PZRPG.skillsByCategory()
    local byId = {}
    for _, def in ipairs(PZRPG.skillsSorted()) do
        byId[def.category] = byId[def.category] or {}
        table.insert(byId[def.category], def)
    end
    local groups = {}
    for _, cat in ipairs(PZRPG.CATEGORIES) do
        if byId[cat.id] then
            groups[#groups + 1] = { category = cat, skills = byId[cat.id] }
        end
    end
    return groups
end
