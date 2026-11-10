local _, ns = ...

ns.MAX_ERRORS = 50

local function bounded(value, limit)
    local text = tostring(value or "")
    return text:sub(1, limit)
end

function ns.Initialize(db)
    if type(db) ~= "table" or db.schema ~= 1 then
        db = { schema = 1, errors = {} }
    end
    if type(db.errors) ~= "table" then db.errors = {} end
    while #db.errors > ns.MAX_ERRORS do table.remove(db.errors, 1) end
    return db
end

function ns.Record(db, message, stack, timestamp)
    message, stack = bounded(message, 8000), bounded(stack, 12000)
    local last = db.errors[#db.errors]
    if last and last.message == message and last.stack == stack then
        last.count = (last.count or 1) + 1
        last.time = timestamp
        return
    end
    db.errors[#db.errors + 1] = {
        message = message, stack = stack, time = timestamp, count = 1,
    }
    while #db.errors > ns.MAX_ERRORS do table.remove(db.errors, 1) end
end

function ns.Report(db, build, addons, handlerActive)
    local lines = {
        "提尔之手 / Tyr's Hand 0.1.0",
        "客户端: " .. build,
        "错误记录器: " .. (handlerActive and "已挂接" or "被其他插件替换；请重新登录后检查"),
        "仅记录本插件加载后的 Lua 错误；调用栈中的插件名只是排查线索。",
        "报告可能含聊天内容、路径等信息，请检查后再分享。",
        "", "插件清单（当前状态，不代表报错时状态）:",
    }
    for _, addon in ipairs(addons) do
        lines[#lines + 1] = string.format("%s | %s | %s | %s",
            addon.name, addon.version, addon.enabled and "启用" or "停用",
            addon.loaded and "已加载" or "未加载")
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "最近错误（最多显示 20 条，共保存 " .. #db.errors .. " 条）:"
    for i = math.max(1, #db.errors - 19), #db.errors do
        local entry = db.errors[i]
        lines[#lines + 1] = string.format("\n[%d] %s | 次数 %d\n%s\n%s",
            i, entry.time or "?", entry.count or 1, entry.message or "", entry.stack or "")
    end
    if #db.errors == 0 then lines[#lines + 1] = "暂无错误。请在插件启用后复现问题。" end
    return table.concat(lines, "\n")
end
