--[[
    PZ RPG  --  Character Sheet : Profile tab

    Top block: the vanilla character, read-only -- name, profession, days
    survived, hours survived, known traits (from PZRPG_04 helpers).
    Below: one labelled text box per PZRPG.PROFILE_FIELDS entry, editable.

    The panel scrolls if the fields run past the bottom. Values are read from
    the profile on refresh() and written back on commit() (called by the sheet
    on tab-switch, close, and "Begin Survival").

    Load order: client _51_ -> after PZRPG_50_Sheet defines the window.
]]

require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"

PZRPG_ProfilePanel = ISPanel:derive("PZRPG_ProfilePanel")

local PAD         = 12
local SCROLLBAR_W = 17          -- keep field boxes clear of the scrollbar
local SMALL       = UIFont.Small
local MEDIUM      = UIFont.Medium

function PZRPG_ProfilePanel:new(x, y, w, h, player)
    local o = ISPanel.new(self, x, y, w, h)
    o.player            = player
    o.background        = true
    o.backgroundColor   = { r = 0, g = 0, b = 0, a = 0.55 }
    o.borderColor       = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.boxes             = {}          -- key -> ISTextEntryBox
    o.headerHeight      = 0
    return o
end

function PZRPG_ProfilePanel:createChildren()
    local lh = getTextManager():getFontHeight(SMALL)

    for _, field in ipairs(PZRPG.PROFILE_FIELDS) do
        local lines  = field.lines or 1
        local boxH   = lh * lines + 8
        local box = ISTextEntryBox:new("", PAD, 0, self.width - PAD * 2 - SCROLLBAR_W, boxH)
        box:initialise(); box:instantiate()
        if lines > 1 then
            box:setMultipleLine(true)
            box:setMaxLines(lines * 3)          -- allow some wrapping past the visible lines
        end
        if field.max then box:setMaxTextLength(field.max) end
        if field.numeric then box:setOnlyNumbers(true) end
        box:setVisible(true)
        self:addChild(box)
        self.boxes[field.key] = box
    end

    self:setScrollChildren(true)
    self:addScrollBars()
    self:layoutFields()
    self:refresh()
end

--- Position the field boxes below the (fixed-height) vanilla header block.
function PZRPG_ProfilePanel:layoutFields()
    local lh = getTextManager():getFontHeight(SMALL)
    -- header: name line + profession + days/hours + up to ~3 wrapped trait lines
    self.headerHeight = lh * 7 + PAD * 2

    local y = self.headerHeight
    for _, field in ipairs(PZRPG.PROFILE_FIELDS) do
        y = y + lh + 2                       -- label
        local box = self.boxes[field.key]
        box:setY(y)
        y = y + box:getHeight() + PAD
    end
    self:setScrollHeight(y + PAD)
end

function PZRPG_ProfilePanel:refresh()
    for _, field in ipairs(PZRPG.PROFILE_FIELDS) do
        local box = self.boxes[field.key]
        if box then box:setText(PZRPG.getProfileField(self.player, field.key)) end
    end
end

function PZRPG_ProfilePanel:commit()
    for _, field in ipairs(PZRPG.PROFILE_FIELDS) do
        local box = self.boxes[field.key]
        if box then
            local txt = box:getText() or ""
            PZRPG.setProfileField(self.player, field.key, txt ~= "" and txt or nil)
        end
    end
end

---------------------------------------------------------------------------
-- rendering
---------------------------------------------------------------------------

local function wrapLines(font, text, maxW)
    local tm, words, lines, cur = getTextManager(), {}, {}, ""
    for w in tostring(text):gmatch("%S+") do words[#words + 1] = w end
    for _, w in ipairs(words) do
        local try = (cur == "") and w or (cur .. " " .. w)
        if tm:MeasureStringX(font, try) > maxW and cur ~= "" then
            lines[#lines + 1] = cur; cur = w
        else
            cur = try
        end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    return lines
end

function PZRPG_ProfilePanel:prerender()
    ISPanel.prerender(self)

    local p       = self.player
    local lh      = getTextManager():getFontHeight(SMALL)
    local x       = PAD
    local y       = PAD + self:getYScroll()

    self:drawText(PZRPG.vanillaName(p), x, y, 1, 1, 1, 1, MEDIUM)
    y = y + getTextManager():getFontHeight(MEDIUM) + 2

    self:drawText("Profession:  " .. PZRPG.vanillaProfession(p), x, y, 0.8, 0.85, 0.9, 1, SMALL)
    y = y + lh
    self:drawText(("Survived:  %d days  (%d hours)"):format(
        PZRPG.daysSurvived(p), math.floor(PZRPG.hoursSurvived(p))),
        x, y, 0.8, 0.85, 0.9, 1, SMALL)
    y = y + lh + 4

    local traits = PZRPG.vanillaTraits(p)
    local names  = {}
    for _, t in ipairs(traits) do names[#names + 1] = t.label end
    local traitStr = (#names > 0) and table.concat(names, ", ") or "(none)"
    self:drawText("Traits:", x, y, 0.7, 0.7, 0.75, 1, SMALL)
    y = y + lh
    for i, line in ipairs(wrapLines(SMALL, traitStr, self.width - PAD * 2 - SCROLLBAR_W)) do
        if i > 3 then break end
        self:drawText(line, x, y, 0.85, 0.85, 0.9, 1, SMALL)
        y = y + lh
    end

    -- divider
    self:drawRect(PAD, self.headerHeight + self:getYScroll() - 6, self.width - PAD * 2 - SCROLLBAR_W, 1, 0.5, 0.4, 0.4, 0.45)

    -- field labels (boxes are real children; labels are drawn here)
    for _, field in ipairs(PZRPG.PROFILE_FIELDS) do
        local box = self.boxes[field.key]
        if box then
            self:drawText(field.label, PAD, box:getY() - lh - 2 + self:getYScroll(),
                0.75, 0.8, 0.85, 1, SMALL)
        end
    end
end
