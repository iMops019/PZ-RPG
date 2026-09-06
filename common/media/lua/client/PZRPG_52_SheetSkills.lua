--[[
    PZ RPG  --  Character Sheet : Skills tab

    Read-only. Registered skills from PZRPG.skillsByCategory(), one category
    header per group, then a row per skill:
        line 1:  name (left)            level (right)
        line 2:  describe(level) blurb  (dim)
        line 3:  XP bar to next level   xp text (right)

    Everything is drawn in prerender (no child widgets); the panel scrolls when
    the list is taller than the view.

    Load order: client _52_ -> after PZRPG_50_Sheet.
]]

require "ISUI/ISPanel"

PZRPG_SkillsPanel = ISPanel:derive("PZRPG_SkillsPanel")

local PAD          = 12
local SCROLLBAR_W  = 17          -- room reserved so right-aligned text clears the scrollbar
local SMALL        = UIFont.Small
local MEDIUM       = UIFont.Medium
local BAR_H        = 7
local HEADER_GAP   = 10          -- extra space above a category header
local ROW_GAP      = 12          -- space between skill rows

function PZRPG_SkillsPanel:new(x, y, w, h, player)
    local o = ISPanel.new(self, x, y, w, h)
    o.player          = player
    o.background      = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.55 }
    o.borderColor     = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    return o
end

function PZRPG_SkillsPanel:createChildren()
    self:setScrollChildren(true)
    self:addScrollBars()
    self:refresh()
end

--- Height of one skill row: name line + blurb line + bar line.
local function rowHeight()
    local lh = getTextManager():getFontHeight(SMALL)
    return lh + 2 + lh + 4 + BAR_H + ROW_GAP
end

function PZRPG_SkillsPanel:refresh()
    local lhM = getTextManager():getFontHeight(MEDIUM)
    local rh  = rowHeight()
    local h   = PAD
    for _, g in ipairs(PZRPG.skillsByCategory()) do
        h = h + HEADER_GAP + lhM + 6 + (#g.skills * rh)
    end
    self:setScrollHeight(h + PAD)
end

function PZRPG_SkillsPanel:prerender()
    ISPanel.prerender(self)

    local p     = self.player
    local lh    = getTextManager():getFontHeight(SMALL)
    local lhM   = getTextManager():getFontHeight(MEDIUM)
    local left  = PAD
    local right = self.width - PAD - SCROLLBAR_W
    local rh    = rowHeight()
    local y     = PAD + self:getYScroll()

    local groups = PZRPG.skillsByCategory()
    if #groups == 0 then
        self:drawText("No skills registered.", left, y, 0.7, 0.7, 0.7, 1, SMALL)
        return
    end

    for _, group in ipairs(groups) do
        y = y + HEADER_GAP
        self:drawText(group.category.label, left, y, 0.62, 0.74, 0.92, 1, MEDIUM)
        y = y + lhM + 3
        self:drawRect(left, y, right - left, 1, 0.5, 0.45, 0.45, 0.5)
        y = y + 3

        for _, def in ipairs(group.skills) do
            local level = PZRPG.getLevel(p, def.id)
            local into, span, frac = PZRPG.getXpProgress(p, def.id)

            -- line 1: name + level
            self:drawText(def.name, left, y, 1, 1, 1, 1, SMALL)
            self:drawTextRight(("Level %d"):format(level), right, y, 0.92, 0.9, 0.68, 1, SMALL)

            -- line 2: blurb (left) + xp text (right)
            local blurb = ""
            if type(def.describe) == "function" then
                local ok, s = pcall(def.describe, level)
                if ok and type(s) == "string" then blurb = s end
            end
            self:drawText(blurb, left, y + lh + 2, 0.58, 0.60, 0.64, 1, SMALL)
            local xpText = (level < PZRPG.curve.MAX_LEVEL)
                and ("%d / %d xp"):format(into, span) or "MAX"
            self:drawTextRight(xpText, right, y + lh + 2, 0.55, 0.55, 0.58, 1, SMALL)

            -- line 3: xp bar
            local barY = y + lh + 2 + lh + 4
            local barW = right - left
            self:drawRect(left, barY, barW, BAR_H, 0.55, 0.18, 0.18, 0.22)
            self:drawRect(left, barY, barW * math.max(0, math.min(1, frac or 0)), BAR_H,
                1, 0.40, 0.72, 0.45)

            y = y + rh
        end
    end
end
