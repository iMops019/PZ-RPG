--[[
    PZ RPG  --  Character Sheet window  (docs/ARCHITECTURE.md sec 5)

    An ISCollapsableWindow with two tabs:
        Profile   -- vanilla name/profession/traits (read-only) + RP fields
        Skills    -- registered skills, grouped by category, level + XP bar

    One instance, kept alive and hidden between opens (ISCollapsableWindow:close
    only hides). Opened with the K keybind (PZRPG_60_Input) or the welcome flow
    (PZRPG_55_Welcome).

    Two display modes, stored in the profile (PZRPG_04):
        "docked"  -- reopens automatically on load, sits where you left it
        "toggle"  -- stays hidden until you press K

    Load order: client _50_ -> after all shared Core files.
]]

require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
require "ISUI/ISButton"

-- Reload-safe: drop a stale window from a previous -debug load of this file.
if PZRPG and PZRPG._sheet then
    pcall(function() PZRPG._sheet:removeFromUIManager() end)
    PZRPG._sheet = nil
end

PZRPG_Sheet = ISCollapsableWindow:derive("PZRPG_Sheet")

local WIN_W        = 560
local WIN_H        = 660
local TAB_H        = 26
local PAD          = 12

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------

function PZRPG_Sheet:new(player)
    local x = getCore():getScreenWidth() * 0.5 - WIN_W * 0.5
    local y = getCore():getScreenHeight() * 0.5 - WIN_H * 0.5
    local o = ISCollapsableWindow.new(self, x, y, WIN_W, WIN_H)
    o.resizable  = false
    o.player     = player
    o.title      = "PZ RPG"
    o.welcome    = false            -- set by PZRPG_Sheet:startWelcome
    o.currentTab = "profile"
    return o
end

function PZRPG_Sheet:createChildren()
    ISCollapsableWindow.createChildren(self)

    local th = self:titleBarHeight()

    -- tab strip
    self.tabProfile = ISButton:new(PAD, th + 4, 120, TAB_H, "Profile", self, function() self:setTab("profile") end)
    self.tabSkills  = ISButton:new(PAD + 124, th + 4, 120, TAB_H, "Skills", self, function() self:setTab("skills") end)
    for _, b in ipairs({ self.tabProfile, self.tabSkills }) do
        b:initialise(); b:instantiate()
        b.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
        self:addChild(b)
    end

    -- content region
    local cy = th + 4 + TAB_H + 6
    local ch = self.height - cy - PAD - 30          -- leave a footer strip
    self.profilePanel = PZRPG_ProfilePanel:new(PAD, cy, self.width - PAD * 2, ch, self.player)
    self.profilePanel:initialise()
    self:addChild(self.profilePanel)

    self.skillsPanel = PZRPG_SkillsPanel:new(PAD, cy, self.width - PAD * 2, ch, self.player)
    self.skillsPanel:initialise()
    self:addChild(self.skillsPanel)

    -- footer: "Begin" in welcome mode, otherwise a mode toggle
    self.footerButton = ISButton:new(self.width - PAD - 160, self.height - PAD - 24, 160, 24,
        "", self, function() self:onFooter() end)
    self.footerButton:initialise(); self.footerButton:instantiate()
    self:addChild(self.footerButton)

    self:setTab(self.currentTab)
    self:refreshFooter()
end

---------------------------------------------------------------------------
-- tabs
---------------------------------------------------------------------------

function PZRPG_Sheet:setTab(tab)
    -- don't lose in-progress edits when leaving the Profile tab
    if self.currentTab == "profile" and tab ~= "profile" and self.profilePanel then
        self.profilePanel:commit()
    end
    self.currentTab = tab
    local onProfile = (tab == "profile")
    self.profilePanel:setVisible(onProfile)
    self.skillsPanel:setVisible(not onProfile)
    if onProfile then self.profilePanel:refresh() else self.skillsPanel:refresh() end

    local on  = { r = 0.25, g = 0.28, b = 0.33, a = 1 }
    local off = { r = 0.10, g = 0.10, b = 0.12, a = 1 }
    self.tabProfile.backgroundColor = onProfile and on or off
    self.tabSkills.backgroundColor  = onProfile and off or on
end

---------------------------------------------------------------------------
-- footer button: welcome "Begin" vs. mode switch
---------------------------------------------------------------------------

function PZRPG_Sheet:refreshFooter()
    if self.welcome then
        self.footerButton:setTitle("Begin Survival")
        self.footerButton:setVisible(true)
        if self.closeButton then self.closeButton:setVisible(false) end
        return
    end
    if self.closeButton then self.closeButton:setVisible(true) end
    local mode = PZRPG.getProfile(self.player).sheetMode
    self.footerButton:setTitle(mode == "docked" and "Mode: Docked" or "Mode: Toggle (K)")
    self.footerButton:setVisible(true)
end

function PZRPG_Sheet:onFooter()
    if self.welcome then
        self:finishWelcome()
        return
    end
    local p = PZRPG.getProfile(self.player)
    p.sheetMode = (p.sheetMode == "docked") and "toggle" or "docked"
    PZRPG.log("sheet: mode -> " .. p.sheetMode)
    self:refreshFooter()
end

---------------------------------------------------------------------------
-- welcome flow (called by PZRPG_55_Welcome)
---------------------------------------------------------------------------

function PZRPG_Sheet:startWelcome()
    -- Game stays LIVE (pausing freezes the input loop the text fields need) and
    -- there is NO backdrop -- a full-screen ISUIElement defaults to consuming
    -- mouse events and would eat every click meant for the sheet.
    self.welcome = true
    self:setTitle("Welcome to PZ RPG  -  your character")
    self:setVisible(true)
    self:setTab("profile")
    self:centerOnScreen()
    self:refreshFooter()
    self:bringToTop()
end

function PZRPG_Sheet:finishWelcome()
    self.welcome = false
    self:setTitle("PZ RPG")
    self:saveAll()
    PZRPG.markProfileCreated(self.player)
    self:refreshFooter()
    -- drop to a resting spot, bottom-left, out of the way
    self:setX(24)
    self:setY(math.max(24, getCore():getScreenHeight() - self.height - 64))
    self:savePosition()
end

function PZRPG_Sheet:centerOnScreen()
    self:setX(getCore():getScreenWidth() * 0.5 - self.width * 0.5)
    self:setY(getCore():getScreenHeight() * 0.5 - self.height * 0.5)
end

---------------------------------------------------------------------------
-- persistence
---------------------------------------------------------------------------

function PZRPG_Sheet:saveAll()
    if self.profilePanel then self.profilePanel:commit() end
    self:savePosition()
end

function PZRPG_Sheet:savePosition()
    local p = PZRPG.getProfile(self.player)
    p.sheetX, p.sheetY = self:getX(), self:getY()
end

function PZRPG_Sheet:restorePosition()
    local p = PZRPG.getProfile(self.player)
    if type(p.sheetX) == "number" and type(p.sheetY) == "number" then
        self:setX(p.sheetX)
        self:setY(p.sheetY)
    end
end

---------------------------------------------------------------------------
-- window overrides
---------------------------------------------------------------------------

function PZRPG_Sheet:prerender()
    ISCollapsableWindow.prerender(self)
    -- While the welcome is up: keep the game live and clear any stale
    -- "- Game Paused -" banner another mod may have left on.
    if self.welcome and self:isReallyVisible() then
        pcall(function()
            if isGamePaused and isGamePaused() and setGameSpeed then setGameSpeed(1) end
            if UIManager and UIManager.setShowPausedMessage then
                UIManager.setShowPausedMessage(false)
            end
        end)
    end
end

-- Instance method: the title-bar X calls self:close(). Do NOT also define a
-- static PZRPG_Sheet.close -- same table key, it would shadow this and recurse.
function PZRPG_Sheet:close()
    if self.welcome then return end          -- must press "Begin Survival"
    self:saveAll()
    ISCollapsableWindow.close(self)          -- just hides
end

function PZRPG_Sheet:onMouseUp(x, y)
    ISCollapsableWindow.onMouseUp(self, x, y)
    self:savePosition()                       -- remember drags
end

---------------------------------------------------------------------------
-- singleton + static open / toggle
---------------------------------------------------------------------------

function PZRPG_Sheet.get()
    local player = getSpecificPlayer(0) or getPlayer()
    if not player then return nil end
    local inst = PZRPG._sheet
    if inst and inst.player ~= player then
        inst:removeFromUIManager()
        inst = nil
    end
    if not inst then
        inst = PZRPG_Sheet:new(player)
        inst:initialise()
        inst:addToUIManager()
        inst:setVisible(false)
        PZRPG._sheet = inst
    end
    return inst
end

function PZRPG_Sheet.open(tab)
    local ok, err = pcall(function()
        local inst = PZRPG_Sheet.get()   -- already addToUIManager'd
        if not inst then return end
        inst:restorePosition()
        inst:setTab(tab or "profile")
        inst:setVisible(true)
        inst:bringToTop()
    end)
    if not ok then PZRPG.log("sheet: open failed -- " .. tostring(err)) end
end

function PZRPG_Sheet.toggle()
    local ok, err = pcall(function()
        local inst = PZRPG._sheet
        if inst and inst.welcome then return end       -- can't dismiss the welcome with K
        if inst and inst:isReallyVisible() then
            inst:close()
        else
            PZRPG_Sheet.open()
        end
    end)
    if not ok then PZRPG.log("sheet: toggle failed -- " .. tostring(err)) end
end

--- True while another full-screen / modal UI owns the player's attention
--- (main menu, PZ's Survival Guide, a modal dialog). Used to hold back our
--- auto-open so we never cover a screen the player still has to dismiss.
function PZRPG_Sheet.otherUIBlocking()
    if MainScreen and MainScreen.instance then
        local ok, v = pcall(function() return MainScreen.instance:isReallyVisible() end)
        if ok and v then return true end
    end
    if SurvivalGuide and SurvivalGuide.instance then
        local ok, v = pcall(function() return SurvivalGuide.instance:isReallyVisible() end)
        if ok and v then return true end
    end
    if ISModalDialog and ISModalDialog.instance then
        local ok, v = pcall(function() return ISModalDialog.instance:isReallyVisible() end)
        if ok and v then return true end
    end
    return false
end
