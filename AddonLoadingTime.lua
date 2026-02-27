-- AddonLoadingTime.lua
-- Measures per-addon loading times and displays results in a sortable UI table.
-- Usage: /alt or /addonloadingtime

local ADDON_NAME = "AddonLoadingTime"
local results = {}
local lastTime = nil
local startTime = nil
local totalTracked = 0

-- Sort state
local sortColumn = "elapsed"  -- "name", "elapsed", "cumulative"
local sortAscending = false

-- Colours
local C_RED    = {1, 0.27, 0.27}
local C_YELLOW = {1, 1, 0.2}
local C_GREEN  = {0.27, 1, 0.27}
local C_HEADER = {0.6, 0.8, 1}
local C_BG     = {0.05, 0.05, 0.08}
local C_ROW1   = {0.10, 0.10, 0.14}
local C_ROW2   = {0.14, 0.14, 0.18}
local C_BORDER = {0.3, 0.5, 0.8}

local ROW_HEIGHT = 18
local VISIBLE_ROWS = 22
local WIN_WIDTH = 500
local WIN_HEIGHT = ROW_HEIGHT * VISIBLE_ROWS + 90  -- rows + header + footer
local SCROLLBAR_W = 20  -- UIPanelScrollFrameTemplate scrollbar width

-- Column positions shared by both header buttons and row labels so they always align.
local CONTENT_W  = WIN_WIDTH - 4 - SCROLLBAR_W  -- usable width inside scroll area
local COL_CUM_R  = CONTENT_W - 4                -- right edge of Cumulative col
local COL_CUM_W  = 90
local COL_EL_R   = COL_CUM_R - COL_CUM_W - 6   -- right edge of Load Time col
local COL_EL_W   = 80
local COL_NAME_L = 6
local COL_NAME_R = COL_EL_R - COL_EL_W - 6     -- right edge of Name col

-- ─── Capture load times ──────────────────────────────────────────────────────

debugprofilestart()
startTime = debugprofilestop()

local captureFrame = CreateFrame("Frame")
captureFrame:RegisterEvent("ADDON_LOADED")
captureFrame:RegisterEvent("PLAYER_LOGIN")

captureFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        local now = debugprofilestop()
        local elapsed = lastTime and (now - lastTime) or (now - startTime)
        lastTime = now
        if addonName ~= ADDON_NAME then
            totalTracked = totalTracked + 1
            table.insert(results, {
                name       = addonName,
                elapsed    = elapsed,
                cumulative = now - startTime,
            })
        end
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent("ADDON_LOADED")
        self:UnregisterEvent("PLAYER_LOGIN")
        ALT_ShowUI()
    end
end)

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function GetRowColour(elapsed)
    if elapsed > 50 then return C_RED
    elseif elapsed > 10 then return C_YELLOW
    else return C_GREEN end
end

local function GetSorted()
    local t = {}
    for _, v in ipairs(results) do t[#t+1] = v end
    table.sort(t, function(a, b)
        local av, bv = a[sortColumn], b[sortColumn]
        if sortAscending then return av < bv else return av > bv end
    end)
    return t
end

-- ─── UI ──────────────────────────────────────────────────────────────────────

local mainFrame, scrollFrame, rowPool, headerLabels

local function SetBg(f, r, g, b, a)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(r, g, b, a or 1)
    f:SetBackdropBorderColor(C_BORDER[1], C_BORDER[2], C_BORDER[3], 0.8)
end

local function MakeLabel(parent, size, anchor, x, y, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size or 11, "")
    fs:SetPoint(anchor or "TOPLEFT", x or 0, y or 0)
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local function RefreshRows()
    if not mainFrame then return end

    local sorted = GetSorted()
    local totalTime = results[#results] and results[#results].cumulative or 0

    -- Update footer
    mainFrame.footer:SetFormattedText(
        "|cff00ccff%d addons|r  •  total load time: |cffffcc00%.1f ms|r",
        totalTracked, totalTime)

    -- Recycle row pool
    for _, r in ipairs(rowPool) do r:Hide() end

    local contentHeight = #sorted * ROW_HEIGHT
    scrollFrame.content:SetHeight(math.max(contentHeight, 1))

    for i, v in ipairs(sorted) do
        local row = rowPool[i]
        if not row then
            -- Create new row
            row = CreateFrame("Frame", nil, scrollFrame.content)
            row:SetHeight(ROW_HEIGHT)
            row:SetPoint("LEFT", 0, 0)
            row:SetPoint("RIGHT", 0, 0)

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()

            row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
            row.nameLabel:SetJustifyH("LEFT")
            row.nameLabel:SetPoint("LEFT", row, "LEFT", COL_NAME_L, 0)
            row.nameLabel:SetWidth(COL_NAME_R - COL_NAME_L)

            row.elLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.elLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
            row.elLabel:SetJustifyH("RIGHT")
            row.elLabel:SetPoint("LEFT", row, "LEFT", COL_EL_R - COL_EL_W, 0)
            row.elLabel:SetWidth(COL_EL_W)

            row.cumLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.cumLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
            row.cumLabel:SetJustifyH("RIGHT")
            row.cumLabel:SetPoint("LEFT", row, "LEFT", COL_CUM_R - COL_CUM_W, 0)
            row.cumLabel:SetWidth(COL_CUM_W)
            rowPool[i] = row
        end

        -- Position
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:Show()

        -- Alternating background
        local bg = (i % 2 == 0) and C_ROW2 or C_ROW1
        row.bg:SetColorTexture(bg[1], bg[2], bg[3], 1)

        -- Colour by load time
        local c = GetRowColour(v.elapsed)
        row.elLabel:SetTextColor(c[1], c[2], c[3])

        row.nameLabel:SetText(v.name)
        row.elLabel:SetFormattedText("%.2f ms", v.elapsed)
        row.cumLabel:SetFormattedText("|cff999999%.1f ms|r", v.cumulative)
    end
end

local function MakeHeaderButton(parent, label, tooltipText, col, xLeft, xRight, justify)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetPoint("TOPLEFT", xLeft, 0)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", xRight, 0)
    btn:SetHeight(24)

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints()
    fs:SetJustifyH(justify or "LEFT")
    fs:SetTextColor(C_HEADER[1], C_HEADER[2], C_HEADER[3])
    btn.label = fs

    local function UpdateLabel()
        local arrow = ""
        if sortColumn == col then
            arrow = sortAscending and " ▲" or " ▼"
        end
        fs:SetText(label .. arrow)
    end
    UpdateLabel()

    btn:SetScript("OnClick", function()
        if sortColumn == col then
            sortAscending = not sortAscending
        else
            sortColumn = col
            sortAscending = (col == "name")
        end
        -- Update all header arrows
        for _, hb in ipairs(headerLabels) do hb() end
        RefreshRows()
    end)

    btn:SetScript("OnEnter", function(self)
        fs:SetTextColor(1, 1, 1)
        if tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tooltipText, 0.9, 0.9, 0.9, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function()
        fs:SetTextColor(C_HEADER[1], C_HEADER[2], C_HEADER[3])
        GameTooltip:Hide()
    end)

    return btn, UpdateLabel
end

function ALT_ShowUI()
    if not mainFrame then
        -- ── Main window ──
        mainFrame = CreateFrame("Frame", "AddonLoadingTimeWindow", UIParent, "BackdropTemplate")
        mainFrame:SetSize(WIN_WIDTH, WIN_HEIGHT)
        mainFrame:SetPoint("CENTER")
        mainFrame:SetFrameStrata("HIGH")
        mainFrame:SetMovable(true)
        mainFrame:EnableMouse(true)
        mainFrame:RegisterForDrag("LeftButton")
        mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
        mainFrame:SetScript("OnDragStop",  mainFrame.StopMovingOrSizing)
        SetBg(mainFrame, C_BG[1], C_BG[2], C_BG[3])

        -- Title bar
        local titleBar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
        titleBar:SetPoint("TOPLEFT",  2, -2)
        titleBar:SetPoint("TOPRIGHT", -2, -2)
        titleBar:SetHeight(26)
        titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        titleBar:SetBackdropColor(C_BORDER[1]*0.4, C_BORDER[2]*0.4, C_BORDER[3]*0.4, 1)

        local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("LEFT", 8, 0)
        title:SetText("|cff00ccffAddon Loading Time|r")
        title:SetFont("Fonts\\FRIZQT__.TTF", 12, "")

        -- Close button
        local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -2, -2)
        closeBtn:SetSize(24, 24)
        closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)

        -- ── Column headers ──
        local headerBar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
        headerBar:SetPoint("TOPLEFT",  2, -30)
        headerBar:SetPoint("TOPRIGHT", -2, -30)
        headerBar:SetHeight(24)
        headerBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        headerBar:SetBackdropColor(0.12, 0.12, 0.18, 1)

        headerLabels = {}
        -- Header bar is WIN_WIDTH-4 wide; content is CONTENT_W wide, same left edge.
        -- xRight offsets are: col_right - headerBar_width = col_right - (WIN_WIDTH-4)
        local HW = WIN_WIDTH - 4
        local _, u1 = MakeHeaderButton(headerBar, "Addon",      nil, "name",       COL_NAME_L,          COL_NAME_R - HW,          "LEFT")
        local _, u2 = MakeHeaderButton(headerBar, "Load Time",  "The time taken to load this specific addon (the gap since the previous one finished).", "elapsed",    COL_EL_R - COL_EL_W, COL_EL_R   - HW,          "RIGHT")
        local _, u3 = MakeHeaderButton(headerBar, "Cumulative", "The total time elapsed since the start of the loading process until this addon finished.", "cumulative", COL_CUM_R - COL_CUM_W, COL_CUM_R - HW,         "RIGHT")
        headerLabels = {u1, u2, u3}

        -- Column dividers — x is distance from headerBar LEFT
        local function Divider(x)
            local d = headerBar:CreateTexture(nil, "OVERLAY")
            d:SetSize(1, 18)
            d:SetPoint("TOPLEFT", headerBar, "TOPLEFT", x, -3)
            d:SetColorTexture(C_BORDER[1], C_BORDER[2], C_BORDER[3], 0.4)
        end
        Divider(COL_EL_R - COL_EL_W - 3)   -- left edge of Load Time col
        Divider(COL_CUM_R - COL_CUM_W - 3)  -- left edge of Cumulative col

        -- ── Scroll frame ──
        scrollFrame = CreateFrame("ScrollFrame", nil, mainFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT",     2, -56)
        scrollFrame:SetPoint("BOTTOMRIGHT", -22, 28)

        local content = CreateFrame("Frame", nil, scrollFrame)
        content:SetWidth(WIN_WIDTH - 26)
        content:SetHeight(1)
        scrollFrame:SetScrollChild(content)
        scrollFrame.content = content

        -- ── Footer ──
        mainFrame.footer = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mainFrame.footer:SetPoint("BOTTOMLEFT", 8, 8)
        mainFrame.footer:SetPoint("BOTTOMRIGHT", -8, 8)
        mainFrame.footer:SetJustifyH("CENTER")

        rowPool = {}
    end

    RefreshRows()
    mainFrame:Show()
end

-- ─── Slash commands ───────────────────────────────────────────────────────────

SLASH_ADDONLOADINGTIME1 = "/addonloadingtime"
SLASH_ADDONLOADINGTIME2 = "/alt"
SlashCmdList["ADDONLOADINGTIME"] = function()
    if mainFrame and mainFrame:IsShown() then
        mainFrame:Hide()
    else
        ALT_ShowUI()
    end
end
