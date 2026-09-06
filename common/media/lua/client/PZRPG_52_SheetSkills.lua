--[[
    PZ RPG  --  Character Sheet : Skills tab

    Read-only. Registered skills from PZRPG.skillsByCategory(), one category
    header per group, then a row per skill: name, level, an XP bar to the next
    level, and the skill's describe(level) blurb.

    Everything is drawn in prerender (no child widgets); the panel scrolls if
    the list is taller than the view.

    Load order: client _52_ -> after PZRPG_50_Sheet.
]]

require "ISUI/ISPanel"

PZRPG_SkillsPanel = ISPanel:derive("PZRPG_SkillsPanel")

local PAD       = 10
local SMALL     = UIFont.Small
local MEDIUM    = UIFont.Medium
local ROW_H     = 44
local HEADER_H  = 24
local BAR_H     = 8

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

function PZRPG_SkillsPanel:refresh()
    local groups = PZRPG.skillsByCategory()
    local h = PAD
    for _, g in ipairs(groups) do
        h = h + HEADER_H + (#g.skills * ROW_H) + 6
    end
    self:setScrollHeight(h + PAD)
end

function PZRPG_SkillsPanel:prerender()
    ISPanel.prerender(self)

    local p      = self.player
    local lh     = getTextManager():getFontHeight(SMALL)
    local w      = self.width
    local y      = PAD + self:getYScroll()

    local groups = PZRPG.skillsByCategory()
    if #groups == 0 then
        self:drawText("No skills registered.", PAD, y, 0.7, 0.7, 0.7, 1, SMALL)
        return
    end

    for _, group in ipairs(groups) do
        self:drawText(group.category.label, PAD, y, 0.65, 0.75, 0.9, 1, MEDIUM)
        y = y + HEADER_H
        self:drawRect(PAD, y - 4, w - PAD * 2, 1, 0.4, 0.4, 0.4, 0.45)

        for _, def in ipairs(group.skills) do
            local level = PZRPG.getLevel(p, def.id)
            local into, span, frac = PZRPG.getXpProgress(p, def.id)

            self:drawText(def.name, PAD, y, 1, 1, 1, 1, SMALL)
            self:drawTextRight(("Level %d"):format(level), w - PAD, y, 0.9, 0.9, 0.7, 1, SMALL)

            -- xp bar
            local barY = y + lh + 3
            local barW = w - PAD * 2
            self:drawRect(PAD, barY, barW, BAR_H, 0.5, 0.15, 0.15, 0.18)
            self:drawRect(PAD, barY, barW * math.max(0, math.min(1, frac)), BAR_H, 0.9, 0.35, 0.65, 0.4)
            if level < PZRPG.curve.MAX_LEVEL then
                self:drawTextRight(("%d / %d"):format(into, span), w - PAD, barY + BAR_H, 0.6, 0.6, 0.6, 1, SMALL)
            else
                self:drawTextRight("MAX", w - PAD, barY + BAR_H, 0.7, 0.7, 0.5, 1, SMALL)
            end

            -- blurb
            local blurb = ""
            if type(def.describe) == "function" then
                local ok, s = pcall(def.describe, level)
                if ok and type(s) == "string" then blurb = s end
            end
            self:drawText(blurb, PAD, barY + BAR_H + 2, 0.6, 0.62, 0.66, 1, SMALL)

            y = y + ROW_H
        end
        y = y + 6
    end
end
