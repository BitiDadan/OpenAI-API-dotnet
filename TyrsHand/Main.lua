local addonName, ns = ...
local db, errorWrapper, window, reportBox
local recording = false

local function inventory()
    local list = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        list[#list + 1] = {
            name = name,
            version = C_AddOns.GetAddOnMetadata(i, "Version") or "未知版本",
            enabled = C_AddOns.GetAddOnEnableState(name, UnitName("player")) > 0,
            loaded = C_AddOns.IsAddOnLoaded(name),
        }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function refresh()
    local version, build, _, interface = GetBuildInfo()
    reportBox:SetText(ns.Report(db,
        string.format("%s (%s), Interface %s, %s", version, build, interface, GetLocale()),
        inventory(), geterrorhandler() == errorWrapper))
    reportBox:SetCursorPosition(0)
end

local function button(parent, label, x, callback)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(110, 24)
    control:SetPoint("BOTTOMLEFT", x, 16)
    control:SetText(label)
    control:SetScript("OnClick", callback)
    return control
end

local function showReport()
    if not window then
        window = CreateFrame("Frame", "TyrsHandReportFrame", UIParent)
        window:SetSize(760, 520)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
        window:SetClampedToScreen(true)
        window:EnableMouse(true)
        window:SetMovable(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        local background = window:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.04, 0.04, 0.06, 0.97)
        local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 20, -16)
        title:SetText("提尔之手 — 点击报告后 Ctrl+A / Ctrl+C 复制")
        local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT")
        local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 20, -48)
        scroll:SetPoint("BOTTOMRIGHT", -42, 54)
        reportBox = CreateFrame("EditBox", nil, scroll)
        reportBox:SetMultiLine(true)
        reportBox:SetAutoFocus(false)
        reportBox:SetFontObject("ChatFontNormal")
        reportBox:SetWidth(690)
        reportBox:SetHeight(400)
        reportBox:SetMaxLetters(0)
        reportBox:SetScript("OnEscapePressed", function() window:Hide() end)
        reportBox:SetScript("OnTextChanged", function(self)
            local rows = 0
            for line in (self:GetText() .. "\n"):gmatch("(.-)\n") do
                rows = rows + math.max(1, math.ceil(#line / 60))
            end
            self:SetHeight(math.max(400, rows * 20))
        end)
        scroll:SetScrollChild(reportBox)
        button(window, "刷新报告", 20, refresh)
        button(window, "清空错误", 140, function()
            db.errors = {}
            refresh()
        end)
        UISpecialFrames[#UISpecialFrames + 1] = "TyrsHandReportFrame"
    end
    refresh()
    window:Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, loadedName)
    if loadedName ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    db = ns.Initialize(TyrsHandDB)
    TyrsHandDB = db
    local previous = geterrorhandler()
    errorWrapper = function(message)
        if not recording then
            recording = true
            -- Restricted/secret values can reject inspection. Never let capture break the handler chain.
            pcall(function()
                ns.Record(db, message, debugstack(2, 30, 20), date("%Y-%m-%d %H:%M:%S"))
            end)
            recording = false
        end
        return previous(message)
    end
    seterrorhandler(errorWrapper)
    SLASH_TYRSHAND1 = "/tyr"
    SLASH_TYRSHAND2 = "/tyrshand"
    SlashCmdList.TYRSHAND = showReport
    print("提尔之手已加载：输入 /tyr 打开诊断报告。")
end)
