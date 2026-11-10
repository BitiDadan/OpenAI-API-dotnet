local lu = require("luaunit")
local ns = {}
assert(loadfile("Core.lua"))("TyrsHand", ns)

TestCore = {}
function TestCore:testInitialization()
    lu.assertEquals(ns.Initialize(nil), { schema = 1, errors = {} })
    lu.assertEquals(ns.Initialize({ schema = 1, errors = false }).errors, {})
end

function TestCore:testDeduplicationAndBounds()
    local db = ns.Initialize(nil)
    ns.Record(db, "error", "stack", "first")
    ns.Record(db, "error", "stack", "second")
    lu.assertEquals(#db.errors, 1)
    lu.assertEquals(db.errors[1].count, 2)
    lu.assertEquals(db.errors[1].time, "second")
    for i = 1, 70 do ns.Record(db, "error " .. i, "stack", "now") end
    lu.assertEquals(#db.errors, 50)
    lu.assertEquals(db.errors[1].message, "error 21")
    ns.Record(db, string.rep("x", 10000), string.rep("y", 14000), "now")
    lu.assertEquals(#db.errors[50].message, 8000)
    lu.assertEquals(#db.errors[50].stack, 12000)
end

function TestCore:testReport()
    local db = ns.Initialize(nil)
    for i = 1, 30 do ns.Record(db, "error-" .. i, "trace-" .. i, "now") end
    local report = ns.Report(db, "client-test", {
        { name = "OtherAddon", version = "2.0", enabled = true, loaded = false },
    }, true)
    lu.assertStrContains(report, "client-test")
    lu.assertStrContains(report, "OtherAddon | 2.0")
    lu.assertStrContains(report, "trace-30")
    lu.assertNotStrContains(report, "trace-10\n")
    lu.assertStrContains(ns.Report(db, "test", {}, false), "被其他插件替换")
end

TestIntegration = {}
function TestIntegration:testLoadCaptureAndWindow()
    local frames, buttons = {}, {}
    local previousCalls = 0
    local handler = function() previousCalls = previousCalls + 1 end
    local env = setmetatable({
        TyrsHandDB = nil, UIParent = {}, UISpecialFrames = {}, SlashCmdList = {},
        print = function() end,
        UnitName = function() return "Player" end,
        GetBuildInfo = function() return "test-version", "123", "date", 120000 end,
        GetLocale = function() return "zhCN" end,
        debugstack = function() return "Interface/AddOns/OtherAddon/Main.lua:42" end,
        date = function() return "test-time" end,
        geterrorhandler = function() return handler end,
        seterrorhandler = function(value) handler = value end,
        C_AddOns = {
            GetNumAddOns = function() return 1 end,
            GetAddOnInfo = function() return "OtherAddon" end,
            GetAddOnMetadata = function() return "1.2.3" end,
            GetAddOnEnableState = function(name)
                lu.assertEquals(name, "OtherAddon")
                return 2
            end,
            IsAddOnLoaded = function() return true end,
        },
    }, { __index = _G })
    local function newFrame(kind)
        local frame = { scripts = {}, kind = kind }
        local methods = {
            "SetSize", "SetPoint", "SetFrameStrata", "SetClampedToScreen",
            "EnableMouse", "SetMovable", "RegisterForDrag", "StartMoving",
            "StopMovingOrSizing", "SetAllPoints", "SetColorTexture",
            "SetMultiLine", "SetAutoFocus", "SetFontObject", "SetWidth",
            "SetHeight", "SetMaxLetters", "SetScrollChild", "SetCursorPosition",
            "RegisterEvent", "UnregisterEvent",
        }
        for _, method in ipairs(methods) do frame[method] = function() end end
        function frame:SetScript(event, fn) self.scripts[event] = fn end
        function frame:SetText(text)
            self.text = text
            if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
        end
        function frame:GetText() return self.text or "" end
        function frame:Show() self.visible = true end
        function frame:Hide() self.visible = false end
        function frame:CreateTexture() return newFrame("Texture") end
        function frame:CreateFontString() return newFrame("FontString") end
        frames[#frames + 1] = frame
        if kind == "Button" then buttons[#buttons + 1] = frame end
        return frame
    end
    env.CreateFrame = function(kind) return newFrame(kind) end
    local main = assert(loadfile("Main.lua"))
    setfenv(main, env)
    main("TyrsHand", ns)
    local events = frames[1]
    events.scripts.OnEvent(events, "ADDON_LOADED", "Unrelated")
    lu.assertNil(rawget(env, "TyrsHandDB"))
    events.scripts.OnEvent(events, "ADDON_LOADED", "TyrsHand")
    handler("simulated addon failure")
    lu.assertEquals(previousCalls, 1)
    lu.assertEquals(env.TyrsHandDB.errors[1].message, "simulated addon failure")
    -- An unreadable protected value must not interrupt the existing handler.
    handler(setmetatable({}, { __tostring = function() error("restricted") end }))
    lu.assertEquals(previousCalls, 2)
    lu.assertEquals(#env.TyrsHandDB.errors, 1)
    env.SlashCmdList.TYRSHAND()
    local report
    for _, frame in ipairs(frames) do
        if frame.kind == "EditBox" then report = frame.text end
    end
    lu.assertStrContains(report, "OtherAddon | 1.2.3")
    lu.assertStrContains(report, "simulated addon failure")
    lu.assertStrContains(report, "Interface 120000")
    for _, control in ipairs(buttons) do
        if control.text == "清空错误" then control.scripts.OnClick() end
    end
    lu.assertEquals(#env.TyrsHandDB.errors, 0)
end

os.exit(lu.LuaUnit.run())
