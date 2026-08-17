--[[
    ============================================================
    ANIME EXPEDITIONS — FULL-MATCH MACRO (RECORD / JSON / REPLAY)
    Executor: Delta (KRNL/Synapse equivalents should also work)
    UI: MacLib (https://raw.githubusercontent.com/kingroko2077/SocTha/refs/heads/main/Thanhnam.lua)

    FLOW
    ----
    1. Type a filename, hit "Create New File (empty)"
    2. Select that file in "Saved Files" dropdown
    3. Hit "Start Recording" — play the match normally (place/upgrade/
       delete units, wave-agnostic, no need to time it around waves)
    4. Recording auto-stops when a Victory/Complete popup is detected
       (fallback: wave counter holds at N/N for 5s straight)
    5. JSON is auto-saved to the selected filename on auto-stop
    6. Later: select the file, hit "Auto Play Selected File"
       - normal clicks/keys replay on their recorded timestamp
       - placement clicks replay GATED on currency: script reads the
         live currency label, compares against the cost recorded for
         that click, and only fires once when balance >= cost. No
         spam-clicking while waiting.

    CURRENCY DETECTION
    ------------------
    No manual path needed — during recording the script polls every
    TextLabel under PlayerGui, watches which one changes value in a
    way that correlates with new units appearing, and locks that as
    the currency label. If it locks the wrong label (e.g. an enemy
    counter that also changes a lot), use "Debug: Lock Currency Now"
    after eyeballing "Debug: Print Currency Value", or hardcode the
    path via CurrencyDetector:SetManualPath(...) near the bottom.
    ============================================================
]]

local MacLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/kingroko2077/SocTha/refs/heads/main/Thanhnam.lua"
))()

local Players           = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local Workspace          = game:GetService("Workspace")
local HttpService        = game:GetService("HttpService")
local lp                 = Players.LocalPlayer

local SAVE_FOLDER = "AE_Macros"
if not isfolder(SAVE_FOLDER) then
    makefolder(SAVE_FOLDER)
end

-- ============================================================
--  WAVE READER (path-anchored, full-match only — not used to
--  gate recording, only for the victory fallback detector)
-- ============================================================
local function getWaveLabel()
    local pg = lp:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local hud = pg:FindFirstChild("TopGameHUD")
    if not hud then return nil end

    local direct = hud
    for _ = 1, 6 do
        direct = direct and direct:FindFirstChildOfClass("Frame")
    end
    if direct then
        local lbl = direct:FindFirstChildOfClass("TextLabel")
        if lbl and lbl.Text:match("^%d+%s*/%s*%d+$") then
            return lbl
        end
    end

    local function scan(inst, depth)
        if depth > 12 then return nil end
        for _, child in ipairs(inst:GetChildren()) do
            if child:IsA("TextLabel") and child.Text:match("^%d+%s*/%s*%d+$") then
                return child
            end
            local found = scan(child, depth + 1)
            if found then return found end
        end
        return nil
    end
    return scan(hud, 0)
end

local function parseWave()
    local lbl = getWaveLabel()
    if not lbl then return nil, nil end
    local cur, total = lbl.Text:match("(%d+)%s*/%s*(%d+)")
    return tonumber(cur), tonumber(total)
end

-- ============================================================
--  UNIT FOLDER / COUNT
--  Used both to detect "did this click place a unit" during record,
--  and to correlate currency-label candidates.
-- ============================================================
local UNIT_FOLDER_NAMES = { "Units", "PlacedUnits", "MyUnits", "Towers" }

local function getUnitFolder()
    for _, name in ipairs(UNIT_FOLDER_NAMES) do
        local f = Workspace:FindFirstChild(name)
        if f then return f end
    end
    local pf = Workspace:FindFirstChild(lp.Name)
    return pf
end

local function countUnits(folder)
    if not folder then return 0 end
    local n = 0
    for _, v in ipairs(folder:GetChildren()) do
        if v:IsA("Model") then n += 1 end
    end
    return n
end

-- ============================================================
--  CURRENCY DETECTOR — auto-discovers the gold/currency label
-- ============================================================
local CurrencyDetector = {
    labelRef   = nil,
    candidates = {},
}

local KNOWN_NON_CURRENCY_PATTERNS = {
    "^%d+%s*/%s*%d+$",  -- wave "X/Y", fraction-style health
    "^%d%d:%d%d$",       -- time "01:29"
}

local function isKnownNonCurrency(text)
    for _, pat in ipairs(KNOWN_NON_CURRENCY_PATTERNS) do
        if text:match(pat) then return true end
    end
    return false
end

local function extractNumber(text)
    local clean = text:gsub(",", "")
    local num, suffix = clean:match("^(%d+%.?%d*)([KkMm]?)$")
    if not num then return nil end
    num = tonumber(num)
    if suffix == "K" or suffix == "k" then num *= 1000
    elseif suffix == "M" or suffix == "m" then num *= 1000000 end
    return num
end

function CurrencyDetector:Scan()
    local pg = lp:FindFirstChild("PlayerGui")
    if not pg then return end

    local function scan(inst, depth)
        if depth > 14 then return end
        for _, child in ipairs(inst:GetChildren()) do
            if child:IsA("TextLabel") and not isKnownNonCurrency(child.Text) then
                local num = extractNumber(child.Text)
                if num then
                    if not self.candidates[child] then
                        self.candidates[child] = { history = {} }
                    end
                    table.insert(self.candidates[child].history, num)
                end
            end
            scan(child, depth + 1)
        end
    end
    scan(pg, 0)
end

function CurrencyDetector:LockBySpawnCorrelation()
    local bestLabel, bestScore = nil, -1
    for label, data in pairs(self.candidates) do
        if #data.history >= 2 then
            local changes = 0
            for i = 2, #data.history do
                if data.history[i] ~= data.history[i - 1] then changes += 1 end
            end
            if changes > bestScore then
                bestScore = changes
                bestLabel = label
            end
        end
    end
    if bestLabel then
        self.labelRef = bestLabel
        print("[Currency] Locked label:", bestLabel:GetFullName(), "| sample:", bestLabel.Text)
        return true
    end
    print("[Currency] Could not auto-lock currency label")
    return false
end

function CurrencyDetector:GetValue()
    if not self.labelRef or not self.labelRef.Parent then return nil end
    return extractNumber(self.labelRef.Text)
end

function CurrencyDetector:SetManualPath(pathFn)
    local ok, lbl = pcall(pathFn)
    if ok and lbl and lbl:IsA("TextLabel") then
        self.labelRef = lbl
        print("[Currency] Manual label set:", lbl:GetFullName())
        return true
    end
    print("[Currency] Manual path failed")
    return false
end

-- ============================================================
--  VICTORY DETECTOR — GUI-name match + wave-stable fallback
-- ============================================================
local VictoryDetector = { callback = nil, conn1 = nil }

local VICTORY_NAME_PATTERNS = { "victory", "complete", "result", "win", "gameover", "gameend" }

local function looksLikeVictoryGui(name)
    local lower = name:lower()
    for _, pat in ipairs(VICTORY_NAME_PATTERNS) do
        if lower:find(pat) then return true end
    end
    return false
end

function VictoryDetector:Start(onVictory)
    self:Stop()
    self.callback = onVictory
    local pg = lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui")

    self.conn1 = pg.ChildAdded:Connect(function(child)
        task.wait(0.1)
        if looksLikeVictoryGui(child.Name) then
            print("[Victory] Detected via GUI:", child.Name)
            if self.callback then self.callback() end
        end
    end)

    task.spawn(function()
        local stableSince = nil
        while self.conn1 do
            local cur, total = parseWave()
            if cur and total and cur == total then
                stableSince = stableSince or tick()
                if tick() - stableSince > 5 then
                    print("[Victory] Detected via wave-stable fallback")
                    if self.callback then self.callback() end
                    break
                end
            else
                stableSince = nil
            end
            task.wait(1)
        end
    end)
end

function VictoryDetector:Stop()
    if self.conn1 then self.conn1:Disconnect(); self.conn1 = nil end
    self.callback = nil
end

-- ============================================================
--  RECORDER — wave-agnostic, tags placement clicks + their cost
-- ============================================================
local Recorder = {
    active      = false,
    events      = {},
    startTime   = 0,
    connections = {},
}

local function clearRecConnections()
    for _, c in ipairs(Recorder.connections) do
        pcall(function() c:Disconnect() end)
    end
    Recorder.connections = {}
end

function Recorder:Start()
    if self.active then return end
    self.active    = true
    self.events    = {}
    self.startTime = tick()

    CurrencyDetector.candidates = {}
    CurrencyDetector.labelRef   = nil

    local unitFolder = getUnitFolder()

    task.spawn(function()
        while self.active do
            CurrencyDetector:Scan()
            task.wait(0.3)
        end
    end)

    local c1 = UserInputService.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.MouseButton2
        or inp.UserInputType == Enum.UserInputType.Keyboard then

            local preCount   = countUnits(unitFolder)
            local preBalance = CurrencyDetector:GetValue()

            local ev = {
                eventType   = "Began",
                inputType   = inp.UserInputType.Name,
                keyCode     = inp.KeyCode ~= Enum.KeyCode.Unknown and inp.KeyCode.Name or nil,
                posX        = inp.Position.X,
                posY        = inp.Position.Y,
                timestamp   = tick() - self.startTime,
                cost        = nil,
                isPlacement = false,
            }
            table.insert(self.events, ev)
            local evIndex = #self.events

            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                task.spawn(function()
                    task.wait(0.5)
                    local postCount = countUnits(unitFolder)
                    if postCount > preCount then
                        local postBalance = CurrencyDetector:GetValue()
                        self.events[evIndex].isPlacement = true
                        if preBalance and postBalance then
                            self.events[evIndex].cost = preBalance - postBalance
                            print(string.format("[Recorder] Placement detected, cost=%s",
                                tostring(self.events[evIndex].cost)))
                        else
                            print("[Recorder] Placement detected but currency not locked yet")
                        end
                    end
                end)
            end
        end
    end)

    local c2 = UserInputService.InputEnded:Connect(function(inp, gp)
        if gp then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.MouseButton2
        or inp.UserInputType == Enum.UserInputType.Keyboard then
            table.insert(self.events, {
                eventType = "Ended",
                inputType = inp.UserInputType.Name,
                keyCode   = inp.KeyCode ~= Enum.KeyCode.Unknown and inp.KeyCode.Name or nil,
                posX      = inp.Position.X,
                posY      = inp.Position.Y,
                timestamp = tick() - self.startTime,
            })
        end
    end)

    table.insert(self.connections, c1)
    table.insert(self.connections, c2)

    VictoryDetector:Start(function()
        if Recorder.active then
            CurrencyDetector:LockBySpawnCorrelation()
            print("[Recorder] Victory detected — auto-stopping & saving")
            Recorder:Stop()
        end
    end)

    print("[Recorder] Recording started (full match, wave-agnostic)")
end

function Recorder:Stop()
    if not self.active then return end
    self.active = false
    clearRecConnections()
    VictoryDetector:Stop()
    print(string.format("[Recorder] Stopped — %d events, %.2fs total",
        #self.events, tick() - self.startTime))
end

-- ============================================================
--  JSON PERSIST
-- ============================================================
local function saveToFile(filename)
    if not filename or filename == "" then
        print("[Save] Empty filename, aborted")
        return false
    end
    local path = SAVE_FOLDER .. "/" .. filename .. ".json"
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, {
        events   = Recorder.events,
        duration = Recorder.events[#Recorder.events] and Recorder.events[#Recorder.events].timestamp or 0,
        savedAt  = os.time(),
    })
    if not ok then
        print("[Save] JSON encode failed:", encoded)
        return false
    end
    writefile(path, encoded)
    print("[Save] Written to", path)
    return true
end

local function loadFromFile(filename)
    local path = SAVE_FOLDER .. "/" .. filename .. ".json"
    if not isfile(path) then
        print("[Load] File not found:", path)
        return nil
    end
    local raw = readfile(path)
    local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok then
        print("[Load] JSON decode failed:", decoded)
        return nil
    end
    return decoded
end

local function listSavedFiles()
    local files = {}
    if isfolder(SAVE_FOLDER) then
        for _, f in ipairs(listfiles(SAVE_FOLDER)) do
            local name = f:match("([^/\\]+)%.json$")
            if name then table.insert(files, name) end
        end
    end
    return files
end

-- ============================================================
--  REPLAYER — strict timeline for normal input, currency-gated
--  single-fire for placement clicks (no spam)
-- ============================================================
local Replayer = { active = false }

function Replayer:Play(data, speedMultiplier)
    if self.active then return end
    if not data or not data.events or #data.events == 0 then
        print("[Replayer] No data to replay")
        return
    end
    speedMultiplier = speedMultiplier or 1.0
    self.active = true

    if not CurrencyDetector.labelRef or not CurrencyDetector.labelRef.Parent then
        print("[Replayer] WARNING: currency label not locked this session.")
        print("[Replayer] Run 'Debug: Lock Currency Now' first, or placement clicks fire ungated.")
    end

    task.spawn(function()
        local function fireInput(ev)
            pcall(function()
                if ev.inputType == "MouseButton1" then
                    if ev.eventType == "Began" then mouse1press() else mouse1release() end
                elseif ev.inputType == "MouseButton2" then
                    if ev.eventType == "Began" then mouse2press() else mouse2release() end
                elseif ev.inputType == "Keyboard" and ev.keyCode then
                    local kc = Enum.KeyCode[ev.keyCode]
                    if kc then
                        if ev.eventType == "Began" then keypress(kc.Value) else keyrelease(kc.Value) end
                    end
                end
            end)
        end
        local function moveMouse(x, y)
            pcall(function() mousemoveabs(x, y) end)
        end

        local replayStart = tick()

        for _, ev in ipairs(data.events) do
            if not self.active then break end

            local targetTime = ev.timestamp / speedMultiplier
            local elapsed = tick() - replayStart
            if targetTime > elapsed then
                task.wait(targetTime - elapsed)
            end
            if not self.active then break end

            if ev.inputType == "MouseButton1" or ev.inputType == "MouseButton2" then
                moveMouse(ev.posX, ev.posY)
                task.wait(0.01)
            end

            if ev.isPlacement and ev.cost and CurrencyDetector.labelRef then
                local balance = CurrencyDetector:GetValue()
                while balance and balance < ev.cost and self.active do
                    task.wait(0.3)
                    balance = CurrencyDetector:GetValue()
                end
                fireInput(ev)
            else
                fireInput(ev)
            end
        end

        self.active = false
        print("[Replayer] Match replay complete")
    end)
end

function Replayer:Stop()
    self.active = false
end

-- ============================================================
--  UI
-- ============================================================
local Window = MacLib:Window({
    Title       = "Anime Expeditions",
    Subtitle    = "Full-Match Macro (JSON)",
    Size        = UDim2.fromOffset(780, 540),
    AcrylicBlur = true,
})

local TabGroup = Window:TabGroup()
local MainTab  = TabGroup:Tab({ Name = "Macro", Image = "rbxassetid://7733960981" })

-- LEFT: file management
local FileSection = MainTab:Section({ Side = "Left" })

local filenameInput = FileSection:Input({
    Name        = "File Name",
    Placeholder = "vd: run1",
    Default     = "",
    Callback    = function() end,
})

local fileDropdown = FileSection:Dropdown({
    Name     = "Saved Files",
    Options  = listSavedFiles(),
    Callback = function() end,
})

FileSection:Button({
    Name = "🔄 Refresh File List",
    Callback = function()
        fileDropdown:ClearOptions()
        fileDropdown:InsertOptions(listSavedFiles())
    end,
})

FileSection:Button({
    Name = "📄 Create New File (empty)",
    Callback = function()
        local name = filenameInput:GetInput()
        if name == "" then print("[UI] Enter a filename first"); return end
        writefile(SAVE_FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode({ events = {}, duration = 0 }))
        print("[UI] Created", name .. ".json")
        fileDropdown:ClearOptions()
        fileDropdown:InsertOptions(listSavedFiles())
    end,
})

-- RIGHT: recording + replay controls
local ControlSection = MainTab:Section({ Side = "Right" })

local statusBtn = ControlSection:Button({ Name = "Status: IDLE", Callback = function() end })

ControlSection:Button({
    Name = "⏺  Start Recording",
    Callback = function()
        if Replayer.active then print("[UI] Can't record during replay"); return end
        Recorder:Start()
        statusBtn:UpdateName("Status: RECORDING ⏺ (auto-stops on Victory)")
    end,
})

ControlSection:Button({
    Name = "⏹  Force Stop Recording",
    Callback = function()
        Recorder:Stop()
        local name = filenameInput:GetInput()
        if name ~= "" then
            saveToFile(name)
            fileDropdown:ClearOptions()
            fileDropdown:InsertOptions(listSavedFiles())
        else
            print("[UI] No filename set — data kept in memory only, saving skipped")
        end
        statusBtn:UpdateName("Status: IDLE")
    end,
})

local replaySpeed = 1.0
ControlSection:Slider({
    Name = "Replay Speed", Minimum = 0.5, Maximum = 3.0, Default = 1.0, Suffix = "x",
    Callback = function(v) replaySpeed = v end,
})

ControlSection:Button({
    Name = "▶  Auto Play Selected File",
    Callback = function()
        local sel = fileDropdown.Value
        if not sel then print("[UI] Select a file first"); return end
        local data = loadFromFile(sel)
        if data then
            Replayer:Play(data, replaySpeed)
            statusBtn:UpdateName("Status: REPLAYING ▶ (" .. sel .. ")")
        end
    end,
})

ControlSection:Button({
    Name = "⏹  Stop Replay",
    Callback = function()
        Replayer:Stop()
        statusBtn:UpdateName("Status: IDLE")
    end,
})

ControlSection:Button({
    Name = "Debug: Lock Currency Now",
    Callback = function()
        CurrencyDetector:Scan()
        task.wait(0.5)
        CurrencyDetector:Scan()
        local ok = CurrencyDetector:LockBySpawnCorrelation()
        if not ok and next(CurrencyDetector.candidates) then
            local best, bestLen = nil, 0
            for label, data in pairs(CurrencyDetector.candidates) do
                if #data.history > bestLen then bestLen = #data.history; best = label end
            end
            if best then
                CurrencyDetector.labelRef = best
                print("[Debug] Fallback-locked:", best:GetFullName(), best.Text)
            end
        end
    end,
})

ControlSection:Button({
    Name = "Debug: Print Currency Value",
    Callback = function()
        local v = CurrencyDetector:GetValue()
        print("[Debug] Currency:", v, "| label:",
            CurrencyDetector.labelRef and CurrencyDetector.labelRef:GetFullName() or "none")
    end,
})

ControlSection:Button({
    Name = "Debug: Print Wave / Unit Count",
    Callback = function()
        local cur, total = parseWave()
        local folder = getUnitFolder()
        print(string.format("[Debug] Wave %s/%s | Unit folder: %s | Count: %d",
            tostring(cur), tostring(total),
            folder and folder:GetFullName() or "NOT FOUND",
            countUnits(folder)))
    end,
})

-- auto-save hook: when Recorder self-stops on Victory, persist if a
-- filename is currently typed in
local originalStop = Recorder.Stop
Recorder.Stop = function(self)
    local wasActive = self.active
    originalStop(self)
    if wasActive then
        local name = filenameInput:GetInput()
        if name ~= "" then
            saveToFile(name)
            fileDropdown:ClearOptions()
            fileDropdown:InsertOptions(listSavedFiles())
        end
        statusBtn:UpdateName("Status: IDLE (saved)")
    end
end

print("[AE Macro] Full-match recorder loaded — set filename, Create File, Start Recording")
