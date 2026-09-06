--[[
    PZ RPG  --  Mining : depleted-boulder overlay  (MINE-1b)

    A worked-out boulder (PZRPG_minedUntil in the future on its modData) is:
      - faded (setAlpha) so you can see at a glance it's spent
      - captioned with "Depleted  1d 6h" floating above it

    NO UI element -- a throttled OnTick scans nearby squares and rebuilds
    PZRPG._depletedBoulders; the caption is drawn straight from an OnPostUIDraw
    hook via getTextManager(). (A full-screen ISUIElement would swallow clicks.)

    Load order: client _47_ -> after PZRPG_11 (helpers).
]]

PZRPG._depletedBoulders = PZRPG._depletedBoulders or {}   -- { {obj, x, y, z}, ... }

local SCAN_RADIUS   = 8
local SCAN_INTERVAL = 60      -- ticks between rescans (~1s)
local FADE_ALPHA    = 0.5

local function fmtHours(h)
    h = math.ceil(h)
    if h >= 24 then
        local d, r = math.floor(h / 24), h % 24
        return (r > 0) and ("%dd %dh"):format(d, r) or ("%dd"):format(d)
    end
    return ("%dh"):format(math.max(1, h))
end

local function restore(o)
    pcall(function()
        o:setAlpha(1.0)
        local md = o:getModData()
        if md and md.PZRPG_minedUntil then
            md.PZRPG_minedUntil = nil
            if o.transmitModData then o:transmitModData() end
        end
    end)
end

local function rescan()
    local player = getSpecificPlayer(0)
    if not player then PZRPG._depletedBoulders = {}; return end

    local cell = getCell()
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())

    local list = {}
    for dx = -SCAN_RADIUS, SCAN_RADIUS do
        for dy = -SCAN_RADIUS, SCAN_RADIUS do
            local sq = cell:getGridSquare(px + dx, py + dy, pz)
            if sq then
                local objs = sq:getObjects()
                for i = 0, objs:size() - 1 do
                    local o = objs:get(i)
                    local ok, name = pcall(function() local s = o:getSprite(); return s and s:getName() end)
                    if ok and PZRPG.isBoulderSprite(name) then
                        if PZRPG.boulderCooldown(o) > 0 then
                            list[#list + 1] = { obj = o, x = px + dx, y = py + dy, z = pz }
                        else
                            restore(o)
                        end
                    end
                end
            end
        end
    end
    PZRPG._depletedBoulders = list
end

PZRPG.hookEvent("OnTick", "mining.overlay.scan", function()
    PZRPG._overlayTick = (PZRPG._overlayTick or 0) + 1
    if PZRPG._overlayTick % SCAN_INTERVAL == 0 then
        pcall(rescan)
    end
end)

PZRPG.hookEvent("OnPostUIDraw", "mining.overlay.draw", function()
    local list = PZRPG._depletedBoulders
    if not list or #list == 0 then return end
    local tm = getTextManager()
    if not tm then return end

    for _, b in ipairs(list) do
        pcall(function()
            local o = b.obj
            if not o or o:getObjectIndex() == -1 then return end
            local cd = PZRPG.boulderCooldown(o)
            if cd <= 0 then return end

            o:setAlpha(FADE_ALPHA)

            local sx = isoToScreenX(0, b.x + 0.5, b.y + 0.4, b.z)
            local sy = isoToScreenY(0, b.x + 0.5, b.y + 0.4, b.z) - 48
            tm:DrawStringCentre(UIFont.Small, sx, sy,       "Depleted",     0.78, 0.78, 0.82, 0.9)
            tm:DrawStringCentre(UIFont.Small, sx, sy + 15,  fmtHours(cd),   0.92, 0.86, 0.55, 0.95)
        end)
    end
end)
