-- ╔════════════════════════════════════════════════════════════════════════════════╗
-- ║                    UNIVERSAL REMOTE DUMPER — ЛЮБАЯ ИГРА                        ║
-- ║              Работает с RemoteEvent, RemoteFunction, BindableEvent            ║
-- ╚════════════════════════════════════════════════════════════════════════════════╝

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- ════════════════════════════════════════════════════════════════════════════════
-- [ НАСТРОЙКИ ]
-- ════════════════════════════════════════════════════════════════════════════════
local CONFIG = {
    SpyDuration = 60,
    OutputFolder = "workspace/UniversalDumper/",
}

-- Создаём папку
if not isfolder(CONFIG.OutputFolder) then
    pcall(makefolder, CONFIG.OutputFolder)
end

-- ════════════════════════════════════════════════════════════════════════════════
-- [ ПЕРЕМЕННЫЕ ]
-- ════════════════════════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local spyRunning = false
local logs = {}
local connections = {}
local oldNamecall = nil

-- Имя игры для папки
local gameName = string.gsub(game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name or "Unknown", "[^%w]", "_")
local gameFolder = CONFIG.OutputFolder .. gameName .. "_" .. tostring(game.PlaceId) .. "/"

pcall(makefolder, gameFolder)

local DUMP_FILE = gameFolder .. "remotes_dump.txt"
local SPY_FILE = gameFolder .. "spy_log.txt"
local ALL_FILE = gameFolder .. "full_dump.txt"

-- ════════════════════════════════════════════════════════════════════════════════
-- [ УТИЛИТЫ ]
-- ════════════════════════════════════════════════════════════════════════════════
local function saveToFile(filename, content)
    local success, err = pcall(function()
        writefile(filename, content)
    end)
    return success, err
end

local function formatValue(value)
    local t = typeof(value)
    if t == "Instance" then
        return value:GetFullName() .. " [" .. value.ClassName .. "]"
    elseif t == "Vector3" then
        return string.format("V3(%.2f,%.2f,%.2f)", value.X, value.Y, value.Z)
    elseif t == "CFrame" then
        return string.format("CF(%.2f,%.2f,%.2f)", value.X, value.Y, value.Z)
    elseif t == "table" then
        local str = "{"
        for k, v in pairs(value) do
            str = str .. tostring(k) .. "=" .. tostring(v) .. ","
            if #str > 100 then str = str .. "..." break end
        end
        return str .. "}"
    elseif t == "string" then
        return '"' .. value .. '"'
    else
        return tostring(value) .. "[" .. t .. "]"
    end
end

local function log(direction, remote, args)
    local parts = {}
    for i = 1, args.n do
        table.insert(parts, formatValue(args[i]))
    end
    local line = string.format("[%s] %s → %s(%s)",
        os.date("%H:%M:%S"),
        remote:GetFullName(),
        direction,
        table.concat(parts, ", ")
    )
    table.insert(logs, line)
    print(line)
end

-- ════════════════════════════════════════════════════════════════════════════════
-- [ УНИВЕРСАЛЬНЫЙ ХУК REMOTES ]
-- ════════════════════════════════════════════════════════════════════════════════
local function hookRemote(obj)
    if not spyRunning then return end
    
    if obj:IsA("RemoteEvent") then
        -- Перехват сервер → клиент
        local ok, conn = pcall(function()
            return obj.OnClientEvent:Connect(function(...)
                if spyRunning then
                    local args = table.pack(...)
                    log("S→C", obj, args)
                end
            end)
        end)
        if ok and conn then table.insert(connections, conn) end
        
    elseif obj:IsA("RemoteFunction") then
        -- RemoteFunction тоже можно перехватить
        local ok, conn = pcall(function()
            return obj.OnClientInvoke:Connect(function(...)
                if spyRunning then
                    local args = table.pack(...)
                    log("S→C (Invoke)", obj, args)
                end
                return nil
            end)
        end)
        if ok and conn then table.insert(connections, conn) end
        
    elseif obj:IsA("BindableEvent") then
        local ok, conn = pcall(function()
            return obj.Event:Connect(function(...)
                if spyRunning then
                    local args = table.pack(...)
                    log("BIND", obj, args)
                end
            end)
        end)
        if ok and conn then table.insert(connections, conn) end
    end
end

-- ════════════════════════════════════════════════════════════════════════════════
-- [ УНИВЕРСАЛЬНЫЙ ДАМП REMOTES ]
-- ════════════════════════════════════════════════════════════════════════════════
local function dumpAllRemotes()
    local results = {
        "╔══════════════════════════════════════════════════════════════╗",
        "║              UNIVERSAL REMOTE DUMPER                         ║",
        "╚══════════════════════════════════════════════════════════════╝",
        "Игра: " .. game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name,
        "PlaceId: " .. game.PlaceId,
        "JobId: " .. game.JobId,
        "Время: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "",
        "═══ RemoteEvent ═══",
    }
    
    local remotes = {}
    local functions = {}
    local bindables = {}
    
    for _, obj in pairs(game:GetDescendants()) do
        pcall(function()
            if obj:IsA("RemoteEvent") then
                table.insert(remotes, "  • " .. obj:GetFullName())
            elseif obj:IsA("RemoteFunction") then
                table.insert(functions, "  • " .. obj:GetFullName())
            elseif obj:IsA("BindableEvent") or obj:IsA("BindableFunction") then
                table.insert(bindables, "  • " .. obj:GetFullName())
            end
        end)
    end
    
    table.insert(results, "Всего RemoteEvent: " .. #remotes)
    for _, v in pairs(remotes) do table.insert(results, v) end
    
    table.insert(results, "")
    table.insert(results, "═══ RemoteFunction ═══")
    table.insert(results, "Всего RemoteFunction: " .. #functions)
    for _, v in pairs(functions) do table.insert(results, v) end
    
    table.insert(results, "")
    table.insert(results, "═══ BindableEvent/Function ═══")
    table.insert(results, "Всего Bindable: " .. #bindables)
    for _, v in pairs(bindables) do table.insert(results, v) end
    
    local out = table.concat(results, "\n")
    local ok, err = saveToFile(DUMP_FILE, out)
    
    return ok, err, out
end

-- ════════════════════════════════════════════════════════════════════════════════
-- [ ЗАПУСК SPY ]
-- ════════════════════════════════════════════════════════════════════════════════
local function startSpy()
    if spyRunning then return end
    
    spyRunning = true
    logs = {}
    connections = {}
    
    table.insert(logs, "═══════════════════════════════════════════════════════════════")
    table.insert(logs, "REMOTE SPY LOG — " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(logs, "Игра: " .. game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name)
    table.insert(logs, "═══════════════════════════════════════════════════════════════")
    table.insert(logs, "")
    
    -- Хукаем все существующие объекты
    for _, obj in pairs(game:GetDescendants()) do
        pcall(function() hookRemote(obj) end)
    end
    
    -- Хукаем новые объекты
    local descAdded = game.DescendantAdded:Connect(function(obj)
        if spyRunning then pcall(function() hookRemote(obj) end) end
    end)
    table.insert(connections, descAdded)
    
    -- Хук через hookmetamethod для перехвата FireServer
    if hookmetamethod and getnamecallmethod then
        pcall(function()
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if spyRunning and (method == "FireServer" or method == "InvokeServer") then
                    local args = table.pack(...)
                    log("C→S", self, args)
                end
                return oldNamecall(self, ...)
            end)
        end)
    end
    
    print("═══════════════════════════════════════════════════════════════")
    print("🕵️ REMOTE SPY ЗАПУЩЕН на " .. CONFIG.SpyDuration .. " секунд")
    print("═══════════════════════════════════════════════════════════════")
end

-- ════════════════════════════════════════════════════════════════════════════════
-- [ ОСТАНОВКА SPY ]
-- ════════════════════════════════════════════════════════════════════════════════
local function stopSpy()
    if not spyRunning then return end
    
    spyRunning = false
    
    for _, conn in pairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}
    
    if oldNamecall then
        pcall(function()
            hookmetamethod(game, "__namecall", oldNamecall)
        end)
        oldNamecall = nil
    end
    
    table.insert(logs, "")
    table.insert(logs, "═══════════════════════════════════════════════════════════════")
    table.insert(logs, "СПИ ОСТАНОВЛЕН — " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(logs, "Всего перехвачено: " .. (#logs - 5) .. " вызовов")
    table.insert(logs, "═══════════════════════════════════════════════════════════════")
    
    local out = table.concat(logs, "\n")
    local ok, err = saveToFile(SPY_FILE, out)
    
    return ok, err, out
end

-- ════════════════════════════════════════════════════════════════════════════════
-- [ ПОЛНЫЙ ДАМП ]
-- ════════════════════════════════════════════════════════════════════════════════
local function fullDump()
    -- Сначала дампим remotes
    local remoteOk, remoteErr, remoteOut = dumpAllRemotes()
    
    -- Затем читаем spy логи если есть
    local spyContent = ""
    local readOk, spyData = pcall(readfile, SPY_FILE)
    if readOk and spyData then
        spyContent = spyData
    elseif #logs > 0 then
        spyContent = table.concat(logs, "\n")
    else
        spyContent = "— Spy логи не найдены —"
    end
    
    local full = {
        "╔════════════════════════════════════════════════════════════════════════════════╗",
        "║                         FULL DUMP — " .. gameName .. "                         ║",
        "╚════════════════════════════════════════════════════════════════════════════════╝",
        "",
        "═══════════════════════════════════════════════════════════════════════════════════",
        "═══ 1. REMOTE EVENT/FUNCTION DUMP ═══",
        "═══════════════════════════════════════════════════════════════════════════════════",
        remoteOut,
        "",
        "═══════════════════════════════════════════════════════════════════════════════════",
        "═══ 2. REMOTE SPY LOGS ═══",
        "═══════════════════════════════════════════════════════════════════════════════════",
        spyContent,
        "",
        "═══════════════════════════════════════════════════════════════════════════════════",
        "КОНЕЦ ДАМПА — " .. os.date("%Y-%m-%d %H:%M:%S"),
        "═══════════════════════════════════════════════════════════════════════════════════",
    }
    
    local out = table.concat(full, "\n")
    local ok, err = saveToFile(ALL_FILE, out)
    
    return ok, err, out
end

-- ════════════════════════════════════════════════════════════════════════════════
-- [ GUI ]
-- ════════════════════════════════════════════════════════════════════════════════
local Window = WindUI:CreateWindow({
    Title = "Universal Remote Dumper",
    Icon = "eye",
    Author = "Purple Orca",
    Folder = "UniversalDumper",
    Size = UDim2.fromOffset(550, 500),
    Transparent = true,
    Theme = "Violet",
})

-- Главная вкладка
local MainTab = Window:Tab({ Title = "Dumper", Icon = "search" })

MainTab:Section({ Title = "Remote Dumper", Opened = true }):Button({
    Title = "📋 Дампить все Remotes",
    Desc = "Сохраняет все RemoteEvent/Function/Bindable в файл",
    Callback = function()
        WindUI:Notify({ Title = "Сканирование...", Content = "Поиск всех Remotes", Duration = 2 })
        local ok, err, out = dumpAllRemotes()
        if ok then
            WindUI:Notify({ Title = "✅ Готово", Content = "Сохранено: " .. DUMP_FILE, Duration = 5 })
        else
            WindUI:Notify({ Title = "❌ Ошибка", Content = err, Duration = 5 })
        end
    end
})

MainTab:Section({ Title = "Remote Spy", Opened = true }):Slider({
    Title = "Длительность (сек)",
    Value = { Min = 30, Max = 300, Default = 60 },
    Callback = function(v) CONFIG.SpyDuration = v end
})

MainTab:Section({ Title = "Remote Spy" }):Button({
    Title = "▶ Запустить Spy",
    Desc = "Начинает перехват всех Remote вызовов",
    Callback = function()
        if spyRunning then
            WindUI:Notify({ Title = "⚠️", Content = "Spy уже запущен!", Duration = 2 })
            return
        end
        
        startSpy()
        
        WindUI:Notify({ Title = "🕵️ Spy запущен", Content = "Длительность: " .. CONFIG.SpyDuration .. " сек. Играй активно!", Duration = 4 })
        
        -- Авто-остановка
        task.spawn(function()
            for i = CONFIG.SpyDuration, 1, -1 do
                if not spyRunning then break end
                if i == 10 then
                    WindUI:Notify({ Title = "Spy", Content = "Осталось 10 секунд!", Duration = 2 })
                end
                task.wait(1)
            end
            if spyRunning then
                local ok, err = stopSpy()
                WindUI:Notify({
                    Title = ok and "✅ Spy завершён" or "❌ Ошибка",
                    Content = ok and ("Сохранено: " .. SPY_FILE) or err,
                    Duration = 5
                })
            end
        end)
    end
})

MainTab:Section({ Title = "Remote Spy" }):Button({
    Title = "⏹ Остановить Spy",
    Desc = "Принудительная остановка",
    Callback = function()
        if not spyRunning then
            WindUI:Notify({ Title = "⚠️", Content = "Spy не запущен", Duration = 2 })
            return
        end
        local ok, err = stopSpy()
        WindUI:Notify({
            Title = ok and "✅ Остановлено" or "❌ Ошибка",
            Content = ok and ("Сохранено: " .. SPY_FILE) or err,
            Duration = 4
        })
    end
})

MainTab:Section({ Title = "Полный дамп", Opened = true }):Button({
    Title = "💾 ДАМПИТЬ ВСЁ",
    Desc = "Объединяет Remotes + Spy логи в один файл",
    Callback = function()
        WindUI:Notify({ Title = "Сбор данных...", Content = "Формирую полный дамп", Duration = 2 })
        local ok, err, out = fullDump()
        if ok then
            WindUI:Notify({ Title = "✅ Всё сдамплено!", Content = "Файл: " .. ALL_FILE, Duration = 6 })
        else
            WindUI:Notify({ Title = "❌ Ошибка", Content = err, Duration = 5 })
        end
    end
})

-- Инструкция
local InfoTab = Window:Tab({ Title = "Инструкция", Icon = "info" })
InfoTab:Paragraph({
    Title = "📖 Как использовать",
    Desc = "1. Нажми «Дампить все Remotes» — сохранит список всех Remote в игре\n\n2. Настрой длительность (30-300 сек)\n\n3. Нажми «Запустить Spy» и АКТИВНО играй\n\n4. Дождись окончания или нажми «Остановить»\n\n5. Нажми «ДАМПИТЬ ВСЁ» — объединит всё в один файл\n\n6. Файлы сохраняются в: " .. gameFolder
})

-- Управление
UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftControl then
        pcall(function() Window:Toggle() end)
    end
end)

WindUI:Notify({
    Title = "Universal Remote Dumper",
    Content = "Загружен! Файлы в: " .. gameFolder,
    Duration = 6,
})
