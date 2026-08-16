--[[
    THAH NAM UI v2.2 -- glass-lite, optimized for 24/7 uptime.

    DESIGN: glassmorphism WITHOUT real backdrop blur. Roblox has no native
    UI blur -- "kính mờ" here means translucent panels + soft static
    gradient + thin border, the same trick Rayfield/Fluent actually use.
    Real blur would mean re-rendering the 3D scene through a ViewportFrame
    every frame, which is the opposite of what a 24/7 hub wants.

    PERFORMANCE CONTRACT (unchanged from v2.1, still enforced in v2.2):
    1. Every Tween is event-driven (click/hover/state-change). Nothing
       tweens on a loop, nothing re-tweens every Heartbeat.
    2. Exactly one background gradient, created once at window build time,
       never re-created or re-tweened after.
    3. No custom RenderStepped/Heartbeat connections owned by the UI layer.
       Sliders/drag use InputChanged (engine-debounced event stream).
    4. Card creation is O(1) per control at build time.
    5. Re-execute safety: destroys any prior ThahNamUI ScreenGui.

    WHAT'S NEW IN v2.2
    - Flag/config system: every control takes `Flag = "name"`, state lives
      in Window.Flags, SaveConfig/LoadConfig round-trip through writefile
      (guarded -- not every executor exposes file IO).
    - Notification toast stack, bottom-right, event-driven fade/slide.
    - Keybind control -- ONE shared InputBegan connection for the whole
      UI regardless of how many keybinds exist (lookup table dispatch,
      not N connections).
    - Window:Destroy() -- explicit teardown beyond re-execute auto-destroy.
    - Dropdown: only one open at a time, click-outside closes it.
    - Slider: input debounced to the slider that actually captured
      MouseButton1Down, so a drag started on one slider can't leak into
      another via the shared UserInputService.InputChanged listener.

    TOKENS
    Background   #120E1F  (deep violet-black panel base)
    Glass        #1C1730  @ 30% transparency (the "kính" layer)
    Border       rgba(255,255,255,0.09)
    AccentA      #FF8FD6  (pink)
    AccentB      #7C9FFF  (blue) -- AccentA->AccentB is the one static
                 gradient in the whole UI, used on fills/active states only
    Success      #7CFFA0  (toast only)
    Warn         #FF8FD6  (reuses AccentA)
    Error        #FF6B6B  (toast only)
    TextPrimary  #F1EEFA
    TextMuted    #756E8C
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--============================================================
-- TOKENS
--============================================================
local Tokens = {
    Background  = Color3.fromRGB(18, 14, 31),
    Glass       = Color3.fromRGB(28, 23, 48),
    Border      = Color3.fromRGB(255, 255, 255),
    AccentA     = Color3.fromRGB(255, 143, 214),
    AccentB     = Color3.fromRGB(124, 159, 255),
    Success     = Color3.fromRGB(124, 255, 160),
    Error       = Color3.fromRGB(255, 107, 107),
    TextPrimary = Color3.fromRGB(241, 238, 250),
    TextMuted   = Color3.fromRGB(117, 110, 140),

    FontLabel  = Enum.Font.GothamMedium,
    FontHeader = Enum.Font.GothamBold,
    FontMono   = Enum.Font.Code,

    SidebarW = 84,
    Tween = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

local CONFIG_FOLDER = "ThahNamUI"

--============================================================
-- THEMES
--============================================================
-- Named palettes, same shape as Tokens' color fields. "Dark" IS the
-- existing Tokens palette -- nothing about the default look changes.
-- Each palette only needs to cover the fields controls actually bind
-- to (Background/Glass/Border/AccentA/AccentB/Success/Error/Text*);
-- fonts and layout constants (SidebarW, Tween) stay in Tokens and are
-- NOT re-themed, since swapping fonts mid-session has no use case here.
local Themes = {
    Dark = {
        Background = Color3.fromRGB(18, 14, 31),
        Glass = Color3.fromRGB(28, 23, 48),
        Border = Color3.fromRGB(255, 255, 255),
        AccentA = Color3.fromRGB(255, 143, 214),
        AccentB = Color3.fromRGB(124, 159, 255),
        Success = Color3.fromRGB(124, 255, 160),
        Error = Color3.fromRGB(255, 107, 107),
        TextPrimary = Color3.fromRGB(241, 238, 250),
        TextMuted = Color3.fromRGB(117, 110, 140),
    },
    Rose = {
        Background = Color3.fromRGB(26, 14, 20),
        Glass = Color3.fromRGB(40, 22, 30),
        Border = Color3.fromRGB(255, 255, 255),
        AccentA = Color3.fromRGB(255, 107, 149),
        AccentB = Color3.fromRGB(255, 176, 138),
        Success = Color3.fromRGB(124, 255, 160),
        Error = Color3.fromRGB(255, 90, 90),
        TextPrimary = Color3.fromRGB(250, 238, 241),
        TextMuted = Color3.fromRGB(140, 108, 118),
    },
    Aqua = {
        Background = Color3.fromRGB(10, 20, 26),
        Glass = Color3.fromRGB(16, 34, 42),
        Border = Color3.fromRGB(255, 255, 255),
        AccentA = Color3.fromRGB(94, 234, 212),
        AccentB = Color3.fromRGB(96, 165, 250),
        Success = Color3.fromRGB(124, 255, 160),
        Error = Color3.fromRGB(255, 107, 107),
        TextPrimary = Color3.fromRGB(232, 250, 248),
        TextMuted = Color3.fromRGB(102, 140, 138),
    },
}

--============================================================
-- LOW-LEVEL HELPERS (unchanged pattern -- cheap, no loops)
--============================================================
-- `New` keeps its original 3-arg call shape everywhere it's already
-- used -- the 4th arg is opt-in. When present, it's a map of
-- { PropertyName = "TokenFieldName" }, e.g. { BackgroundColor3 = "Glass" }.
-- On creation the property is set from the CURRENT active palette, and
-- the (Instance, propMap) pair is pushed into `themedInstances` so a
-- later SetTheme() call can revisit it. Instances that are never
-- destroyed accumulate here for the process lifetime of the window --
-- acceptable for a 24/7 hub with a bounded control count, not something
-- that grows per-frame.
local themedInstances = {} -- array of { inst = Instance, map = {prop=field} }
local activeThemeName = "Dark"

local function CurrentPalette()
    return Themes[activeThemeName] or Themes.Dark
end

local function New(class, props, children, themeMap)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then inst[k] = v end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    if themeMap then
        local palette = CurrentPalette()
        for prop, field in pairs(themeMap) do
            local val = palette[field]
            if val then inst[prop] = val end
        end
        local entry = { inst = inst, map = themeMap }
        table.insert(themedInstances, entry)
        -- Self-cleaning: fires whether this Instance dies via its own
        -- control's Destroy(), via Row:Destroy() cascading to children,
        -- or via Window:Destroy() nuking the whole ScreenGui. This is
        -- why individual control Destroy() methods don't need to call
        -- UnregisterThemed manually for THEIR OWN themed children --
        -- only for cases where an Instance's identity needs clearing
        -- from other stateful pointers (like openDropdown).
        inst.Destroying:Connect(function()
            for i = #themedInstances, 1, -1 do
                if themedInstances[i] == entry then
                    table.remove(themedInstances, i)
                    break
                end
            end
        end)
    end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

-- Removes an Instance's entry from the theme registry. Every control's
-- Destroy() calls this for each themed child it owns, so SetTheme()
-- never touches a dead Instance (which would error on property write).
local function UnregisterThemed(inst)
    for i = #themedInstances, 1, -1 do
        if themedInstances[i].inst == inst then
            table.remove(themedInstances, i)
        end
    end
end

local function Corner(r) return New("UICorner", { CornerRadius = UDim.new(0, r or 14) }) end

local function Stroke(color, thickness, transparency)
    return New("UIStroke", {
        Color = color or Tokens.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0.85,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function Pad(l, t, r, b)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or l or 0), PaddingBottom = UDim.new(0, b or t or 0),
    })
end

-- The ONE static gradient pattern reused across accent fills. Built once
-- per instance, never touched again after creation.
local function AccentGradient(rotation)
    return New("UIGradient", {
        Rotation = rotation or 0,
        Color = ColorSequence.new(Tokens.AccentA, Tokens.AccentB),
    })
end

local function Tween(inst, props, info)
    local t = TweenService:Create(inst, info or Tokens.Tween, props)
    t:Play()
    return t
end

-- File IO isn't universal across executors. Every touch point is wrapped
-- so a missing writefile/readfile/isfile doesn't hard-crash the UI --
-- it just silently degrades config persistence. The UI doesn't know or
-- care which executor it's running under; it only knows whether the
-- global exists this call.
local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return false, "unsupported" end
    return pcall(fn, ...)
end

--============================================================
-- ROOT WINDOW
--============================================================
local function CreateWindow(config)
    config = config or {}
    local title = config.Title or "Thah Nam Hub"
    local subtitle = config.Subtitle or ""
    local configFolder = config.ConfigFolder or CONFIG_FOLDER

    -- Kích thước cửa sổ giờ cấu hình được qua config.Width/Height.
    -- Mặc định giảm từ 700x460 (v2.2 gốc) xuống 520x360 -- mọi thứ bên
    -- trong Root (Sidebar, Content, TopBar) đã được định nghĩa theo tỉ lệ
    -- Scale (UDim2.new(1, -8, 1, -8) v.v.), không phải số Offset cứng,
    -- nên co Ambient là đủ, không cần sửa layout bên trong.
    local winW = config.Width or 520
    local winH = config.Height or 360

    local existing = PlayerGui:FindFirstChild("ThahNamUI")
    if existing then existing:Destroy() end -- 24/7 re-execute safety

    local ScreenGui = New("ScreenGui", {
        Name = "ThahNamUI",
        Parent = PlayerGui,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    })

    -- Static ambient backdrop: one soft tinted rect, built once, zero
    -- runtime cost. Stands in for a CSS radial-gradient background.
    local Ambient = New("Frame", {
        Name = "Ambient",
        Size = UDim2.new(0, winW, 0, winH),
        Position = UDim2.new(0.5, -winW / 2, 0.5, -winH / 2),
        BackgroundColor3 = Color3.fromRGB(13, 10, 22),
        BorderSizePixel = 0,
        Parent = ScreenGui,
    }, {
        Corner(24),
        AccentGradient(115),
    })
    Ambient.UIGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.88),
        NumberSequenceKeypoint.new(1, 0.88),
    })

    local Root = New("Frame", {
        Name = "Root",
        Size = UDim2.new(1, -8, 1, -8),
        Position = UDim2.new(0, 4, 0, 4),
        BackgroundColor3 = Tokens.Glass,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = Ambient,
    }, {
        Corner(22),
        Stroke(Tokens.Border, 1, 0.85),
    }, { BackgroundColor3 = "Glass" })

    --------------------------------------------------------------
    -- Toast layer -- sits above Root, outside ClipsDescendants,
    -- so notifications aren't cropped by the panel bounds.
    --------------------------------------------------------------
    local ToastLayer = New("Frame", {
        Name = "ToastLayer",
        Size = UDim2.new(0, 280, 1, -20),
        Position = UDim2.new(1, -296, 0, 10),
        BackgroundTransparency = 1,
        ZIndex = 50,
        Parent = ScreenGui,
    }, {
        New("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            Padding = UDim.new(0, 8),
        }),
    })

    --------------------------------------------------------------
    -- Drag strip (top bar, also the title header)
    --------------------------------------------------------------
    local TopBar = New("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        Parent = Root,
    })
    New("TextLabel", {
        Text = title, Font = Tokens.FontHeader, TextSize = 15,
        TextColor3 = Tokens.TextPrimary, BackgroundTransparency = 1,
        Size = UDim2.new(0, 200, 1, 0), Position = UDim2.new(0, 100, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = TopBar,
    })
    New("TextLabel", {
        Text = subtitle, Font = Tokens.FontMono, TextSize = 10,
        TextColor3 = Tokens.TextMuted, BackgroundTransparency = 1,
        Size = UDim2.new(0, 200, 0, 14), Position = UDim2.new(1, -160, 0, 13),
        TextXAlignment = Enum.TextXAlignment.Right, Parent = TopBar,
    })

    do -- drag behavior, engine event-driven, no polling loop
        local dragging, dragStart, startPos = false, nil, nil
        TopBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = Ambient.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                Ambient.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    --------------------------------------------------------------
    -- Sidebar (fixed width -- no expand/collapse tween cost)
    --------------------------------------------------------------
    local Sidebar = New("Frame", {
        Size = UDim2.new(0, Tokens.SidebarW, 1, -40),
        Position = UDim2.new(0, 0, 0, 40),
        BackgroundTransparency = 1,
        Parent = Root,
    }, {
        Stroke(Tokens.Border, 1, 0.92),
    })
    Sidebar.UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, {}).Parent = Sidebar
    Pad(0, 20, 0, 0).Parent = Sidebar

    local Content = New("Frame", {
        Size = UDim2.new(1, -Tokens.SidebarW, 1, -40),
        Position = UDim2.new(0, Tokens.SidebarW, 0, 40),
        BackgroundTransparency = 1,
        Parent = Root,
    })

    local tabButtons, tabPages, activeTab = {}, {}, nil
    local Window = { Flags = {} }

    -- Controls whose current-state color depends on live logic (Toggle
    -- on/off, Slider fill ratio) rather than a fixed property can't just
    -- be repainted from a static themeMap -- their color is a function
    -- of state, not a constant. Each such control pushes a zero-arg
    -- "repaint yourself with current Tokens" callback here; SetTheme()
    -- calls every one of these AFTER overwriting Tokens, so the visible
    -- state (on/off, fill %) is preserved but rendered in the new palette
    -- immediately instead of waiting for the next user interaction.
    local rerenderCallbacks = {}
    local function RegisterRerender(fn)
        table.insert(rerenderCallbacks, fn)
        return function() -- returns an unregister function for Destroy() to call
            for i = #rerenderCallbacks, 1, -1 do
                if rerenderCallbacks[i] == fn then table.remove(rerenderCallbacks, i) end
            end
        end
    end

    --------------------------------------------------------------
    -- Shared input dispatch. ONE InputBegan connection backs every
    -- keybind control in the UI, regardless of count -- a lookup
    -- table swap, not N listeners. This is the same philosophy as
    -- the slider's InputChanged reuse: one engine event stream,
    -- fan-out happens in Lua, not in connection count.
    --------------------------------------------------------------
    local keybindHandlers = {} -- [Enum.KeyCode] = { fn, fn, ... }
    local capturingKeybind = nil -- non-nil while a "press a key" bind box is listening

    local sharedInputConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if capturingKeybind then
            capturingKeybind(input)
            return
        end
        local handlers = keybindHandlers[input.KeyCode]
        if handlers then
            for _, fn in ipairs(handlers) do fn() end
        end
    end)

    -- Click-outside-to-close for dropdowns. One transparent full-screen
    -- catcher, ZIndex below the open dropdown's option list, only
    -- listens while a dropdown is actually open.
    local openDropdown = nil -- { OptFrame, Close = fn }
    local ClickCatcher = New("TextButton", {
        Name = "ClickCatcher",
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0), ZIndex = 4,
        Visible = false, AutoButtonColor = false,
        Parent = ScreenGui,
    })
    ClickCatcher.MouseButton1Click:Connect(function()
        if openDropdown then openDropdown.Close() end
    end)

    local function CloseOpenDropdown()
        if openDropdown then openDropdown.Close() end
    end

    --------------------------------------------------------------
    -- Nút nổi (FAB) bật/tắt UI -- kéo được, đứng ngoài Ambient nên
    -- vẫn bấm được kể cả khi Ambient đang Visible=false. Dùng chung
    -- hàm ToggleVisible với phím tắt (nếu control nào set Flag đó)
    -- để 2 đường trigger không lệch trạng thái nhau.
    --------------------------------------------------------------
    local uiVisible = true
    local function SetUIVisible(v)
        uiVisible = v
        Ambient.Visible = v
        if not v then CloseOpenDropdown() end
    end
    local function ToggleVisible()
        SetUIVisible(not uiVisible)
    end

    local Fab = New("ImageButton", {
        Name = "FabToggle",
        Image = "",
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = Tokens.Glass,
        BackgroundTransparency = 0.15,
        Size = UDim2.new(0, 44, 0, 44),
        Position = UDim2.new(0, 16, 0, 16),
        ZIndex = 60,
        Parent = ScreenGui,
    }, {
        Corner(22),
        Stroke(Tokens.Border, 1, 0.8),
    }, { BackgroundColor3 = "Glass" })

    New("TextLabel", {
        Text = "☰", Font = Tokens.FontHeader, TextSize = 18,
        TextColor3 = Tokens.TextPrimary, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0), ZIndex = 61, Parent = Fab,
    }, nil, { TextColor3 = "TextPrimary" })

    -- FAB vừa kéo-thả được vừa bấm-toggle được, dùng chung một cờ
    -- `moved`: MouseButton1Click chỉ gọi ToggleVisible nếu ngón tay/chuột
    -- không di chuyển quá ngưỡng kể từ lúc InputBegan -- nếu không, mỗi
    -- lần kéo xong sẽ vô tình toggle UI ngay tại điểm thả tay.
    do
        local dragging, dragStart, startPos = false, nil, nil
        local moved = false
        Fab.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                moved = false
                dragStart = input.Position
                startPos = Fab.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                if delta.Magnitude > 4 then moved = true end
                Fab.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
        Fab.MouseButton1Click:Connect(function()
            if not moved then ToggleVisible() end
        end)
    end

    --------------------------------------------------------------
    -- Notifications
    --------------------------------------------------------------
    local TYPE_COLOR = {
        info = Tokens.AccentB,
        success = Tokens.Success,
        warn = Tokens.AccentA,
        error = Tokens.Error,
    }

    function Window:Notify(opts)
        opts = opts or {}
        local kind = opts.Type or "info"
        local duration = opts.Duration or 4
        local accent = TYPE_COLOR[kind] or Tokens.AccentB

        local Toast = New("Frame", {
            BackgroundColor3 = Tokens.Glass, BackgroundTransparency = 1,
            BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ClipsDescendants = true, LayoutOrder = os.clock(),
            Parent = ToastLayer,
        }, {
            Corner(12),
            Stroke(Tokens.Border, 1, 0.85),
            Pad(14, 10, 14, 10),
        })

        local Bar = New("Frame", {
            Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = accent,
            BorderSizePixel = 0, Parent = Toast,
        }, { Corner(2) })

        New("TextLabel", {
            Text = opts.Title or "Notice", Font = Tokens.FontHeader, TextSize = 12,
            TextColor3 = Tokens.TextPrimary, BackgroundTransparency = 1,
            Size = UDim2.new(1, -10, 0, 16), Position = UDim2.new(0, 10, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Left, Parent = Toast,
        })
        New("TextLabel", {
            Text = opts.Content or "", Font = Tokens.FontLabel, TextSize = 11,
            TextColor3 = Tokens.TextMuted, TextWrapped = true, BackgroundTransparency = 1,
            Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            Position = UDim2.new(0, 10, 0, 18), TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Toast,
        })

        -- Every property here starts transparent/off-screen and tweens
        -- in on spawn. This is still event-driven: the "event" is the
        -- toast being created, not a per-frame poll. Exactly two tweens
        -- fire per toast lifetime (in, out) -- nothing loops.
        Toast.BackgroundTransparency = 1
        Toast.Position = UDim2.new(0, 40, 0, 0)
        Tween(Toast, { BackgroundTransparency = 0.35, Position = UDim2.new(0, 0, 0, 0) })

        task.delay(duration, function()
            if not Toast.Parent then return end
            local out = Tween(Toast, { BackgroundTransparency = 1, Position = UDim2.new(0, 40, 0, 0) })
            out.Completed:Connect(function() Toast:Destroy() end)
        end)
    end

    --------------------------------------------------------------
    -- Config persistence
    --------------------------------------------------------------
    -- Applies a saved value to a flag WITHOUT re-firing SaveConfig or
    -- creating feedback loops. Set() below is the raw setter every
    -- control registers; LoadConfig calls it directly so loading a
    -- config doesn't require the UI to already be mid-interaction.
    function Window:SaveConfig(name)
        name = name or "default"
        local ok = SafeCall(function()
            if not isfolder(configFolder) then makefolder(configFolder) end
        end)
        if not ok then return false, "no folder API" end

        local data = {}
        for flag, entry in pairs(self.Flags) do
            data[flag] = entry.Value
        end
        local encodeOk, encoded = pcall(HttpService.JSONEncode, HttpService, data)
        if not encodeOk then return false, "encode failed" end

        local ok2 = SafeCall(writefile, configFolder .. "/" .. name .. ".json", encoded)
        return ok2
    end

    function Window:LoadConfig(name)
        name = name or "default"
        local path = configFolder .. "/" .. name .. ".json"
        local existsOk, exists = SafeCall(isfile, path)
        if not existsOk or not exists then return false, "no config file" end

        local readOk, raw = SafeCall(readfile, path)
        if not readOk then return false, "read failed" end

        local decodeOk, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if not decodeOk or type(data) ~= "table" then return false, "decode failed" end

        for flag, value in pairs(data) do
            local entry = self.Flags[flag]
            if entry then entry.Set(value) end
        end
        return true
    end

    -- Walks every registered themed Instance and rewrites its bound
    -- properties from the new palette. This is a full re-paint, not a
    -- Tween -- theme swaps are rare, deliberate user actions (settings
    -- menu, not a hover state), so an instant property write is correct
    -- here and keeps this out of the "everything tweens" contract that
    -- governs interactive feedback elsewhere in the library.
    --
    -- SECOND EFFECT, and the important one: this also overwrites the
    -- color fields on the module-level `Tokens` table in place. Every
    -- control's Render()/interaction closures (Toggle's on/off colors,
    -- Slider's fill, Dropdown's accent text) read `Tokens.AccentB` etc.
    -- fresh on EVERY call rather than capturing a value at creation --
    -- so once Tokens itself is repainted, the next state change any
    -- control renders (next toggle flip, next slider drag tick) picks
    -- up the new palette with zero additional bookkeeping. This is why
    -- Tokens is a plain table, not a frozen/locked one: it's the second
    -- half of the theme system, not just static constants.
    function Window:SetTheme(name)
        if not Themes[name] then return false, "unknown theme" end
        activeThemeName = name
        local palette = Themes[name]

        for field, val in pairs(palette) do
            Tokens[field] = val
        end

        for _, entry in ipairs(themedInstances) do
            if entry.inst.Parent then -- skip anything destroyed but not yet unregistered
                for prop, field in pairs(entry.map) do
                    local val = palette[field]
                    if val then entry.inst[prop] = val end
                end
            end
        end

        for _, fn in ipairs(rerenderCallbacks) do
            fn()
        end

        return true
    end

    function Window:GetTheme()
        return activeThemeName
    end

    function Window:Destroy()
        sharedInputConn:Disconnect()
        ScreenGui:Destroy() -- Fab là con của ScreenGui, dọn theo, không cần gọi riêng
    end

    function Window:SetVisible(v) SetUIVisible(v) end
    function Window:ToggleVisible() ToggleVisible() end
    function Window:GetVisible() return uiVisible end

    function Window:CreateTab(name, icon)
        icon = icon or "●"

        local Btn = New("TextButton", {
            Text = "", BackgroundColor3 = Tokens.Glass, BackgroundTransparency = 1,
            Size = UDim2.new(0, 44, 0, 44), LayoutOrder = #tabButtons + 1,
            AutoButtonColor = false, Parent = Sidebar,
        }, { Corner(12) })

        local Icon = New("TextLabel", {
            Text = icon, Font = Tokens.FontLabel, TextSize = 16,
            TextColor3 = Tokens.TextMuted, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0), Parent = Btn,
        })

        tabButtons[name] = { Btn = Btn, Icon = Icon }

        local Page = New("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2, ScrollBarImageColor3 = Tokens.AccentB,
            ScrollBarImageTransparency = 0.4,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false, Parent = Content,
        }, {
            Pad(20, 18, 20, 18),
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
        })
        tabPages[name] = Page

        local function Select()
            if activeTab then
                Tween(tabButtons[activeTab].Btn, { BackgroundTransparency = 1 })
                Tween(tabButtons[activeTab].Icon, { TextColor3 = Tokens.TextMuted })
                tabPages[activeTab].Visible = false
            end
            activeTab = name
            Tween(Btn, { BackgroundTransparency = 0.85 })
            Tween(Icon, { TextColor3 = Tokens.TextPrimary })
            Page.Visible = true
        end
        Btn.MouseButton1Click:Connect(Select)
        if not activeTab then Select() end

        --========================================================
        -- Controls -- each is O(1) instances at creation, and every
        -- update after that is a direct property write, never a
        -- rebuild.
        --========================================================
        local TabAPI = {}

        local function Card(height)
            return New("Frame", {
                BackgroundColor3 = Tokens.Glass, BackgroundTransparency = 0.4,
                BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, height or 46),
                LayoutOrder = #Page:GetChildren(), Parent = Page,
            }, { Corner(12), Stroke(Tokens.Border, 1, 0.88) }, { BackgroundColor3 = "Glass" })
        end

        -- Every control that takes opts.Flag registers into Window.Flags
        -- here. `setter` is the RAW state mutator (no callback firing on
        -- config load); `opts.Callback` still fires on user interaction.
        local function RegisterFlag(flag, initial, setter)
            if not flag then return end
            Window.Flags[flag] = { Value = initial, Set = function(v)
                Window.Flags[flag].Value = v
                setter(v)
            end }
        end

        function TabAPI:CreateToggle(opts)
            local Row = Card(46)
            New("TextLabel", {
                Text = opts.Name, Font = Tokens.FontLabel, TextSize = 13,
                TextColor3 = Tokens.TextPrimary, BackgroundTransparency = 1,
                Size = UDim2.new(1, -70, 1, 0), Position = UDim2.new(0, 16, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left, Parent = Row,
            })

            local Track = New("Frame", {
                Size = UDim2.new(0, 38, 0, 20), Position = UDim2.new(1, -50, 0.5, -10),
                BackgroundColor3 = Tokens.Border, BackgroundTransparency = 0.85,
                BorderSizePixel = 0, Parent = Row,
            }, { Corner(10) })
            local Knob = New("Frame", {
                Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 2, 0.5, -8),
                BackgroundColor3 = Tokens.TextPrimary, BorderSizePixel = 0, Parent = Track,
            }, { Corner(8) })

            local state = opts.CurrentValue or false
            local function Render()
                if state then
                    Tween(Track, { BackgroundTransparency = 0, BackgroundColor3 = Tokens.AccentB })
                    Tween(Knob, { Position = UDim2.new(0, 20, 0.5, -8) })
                else
                    Tween(Track, { BackgroundTransparency = 0.85, BackgroundColor3 = Tokens.Border })
                    Tween(Knob, { Position = UDim2.new(0, 2, 0.5, -8) })
                end
            end

            local Click = New("TextButton", {
                Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Row,
            })
            Click.MouseButton1Click:Connect(function()
                state = not state
                Render()
                if opts.Callback then opts.Callback(state) end
                if opts.Flag then Window.Flags[opts.Flag].Value = state end
            end)
            Render()

            RegisterFlag(opts.Flag, state, function(v)
                state = v
                Render()
                if opts.Callback then opts.Callback(v) end
            end)

            local UnregisterRerender = RegisterRerender(Render)

            return {
                Set = function(v) state = v; Render(); if opts.Callback then opts.Callback(v) end end,
                Destroy = function() UnregisterRerender(); Row:Destroy() end,
            }
        end

        -- New in this pass: a real button control, not a Toggle wearing
        -- a trenchcoat. Modeled on Fluent's Elements/Button.lua pattern
        -- (hover-darken, press-flash, single click event) but rebuilt
        -- against ThahNamUI's own token set and Tween() helper -- no
        -- code lifted from Fluent's bundle, just the interaction shape.
        function TabAPI:CreateButton(opts)
            local Row = Card(46)
            New("TextLabel", {
                Text = opts.Name, Font = Tokens.FontLabel, TextSize = 13,
                TextColor3 = Tokens.TextPrimary, BackgroundTransparency = 1,
                Size = UDim2.new(1, -90, 1, 0), Position = UDim2.new(0, 16, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left, Parent = Row,
            })

            local ActionLbl = New("TextLabel", {
                Text = opts.ButtonText or "Run", Font = Tokens.FontMono, TextSize = 11,
                TextColor3 = Tokens.AccentB, BackgroundTransparency = 1,
                Size = UDim2.new(0, 70, 0, 26), Position = UDim2.new(1, -82, 0.5, -13),
                TextXAlignment = Enum.TextXAlignment.Center, Parent = Row,
            }, nil, { TextColor3 = "AccentB" })
            local Pill = New("Frame", {
                Size = UDim2.new(0, 70, 0, 26), Position = UDim2.new(1, -82, 0.5, -13),
                BackgroundColor3 = Tokens.Border, BackgroundTransparency = 0.88,
                BorderSizePixel = 0, ZIndex = 0, Parent = Row,
            }, { Corner(8) }, { BackgroundColor3 = "Border" })
            ActionLbl.ZIndex = 1

            local Click = New("TextButton", {
                Text = "", BackgroundTransparency = 1,
                Size = UDim2.new(0, 70, 0, 26), Position = UDim2.new(1, -82, 0.5, -13),
                AutoButtonColor = false, Parent = Row,
            })

            -- Three-state event-driven feedback: idle -> hover (subtle
            -- lift) -> press (flash, then callback fires on release
            -- inside bounds, matching standard TextButton semantics).
            -- Every state change is exactly one Tween pair, nothing
            -- polls MouseEnter/Leave on a loop.
            Click.MouseEnter:Connect(function()
                Tween(Pill, { BackgroundTransparency = 0.75 })
            end)
            Click.MouseLeave:Connect(function()
                Tween(Pill, { BackgroundTransparency = 0.88 })
            end)
            Click.MouseButton1Down:Connect(function()
                Tween(Pill, { BackgroundTransparency = 0.5 }, TweenInfo.new(0.08))
            end)
            Click.MouseButton1Click:Connect(function()
                Tween(Pill, { BackgroundTransparency = 0.75 })
                if opts.Callback then opts.Callback() end
            end)

            -- Per-element Destroy, same shape Fluent added in 1.1.0 --
            -- lets a caller tear down one control without nuking the
            -- whole tab page. Row is the single root Instance; every
            -- child (label, pill, click-catcher) dies with it.
            return {
                Destroy = function() Row:Destroy() end,
                SetText = function(t) ActionLbl.Text = t end,
            }
        end

        function TabAPI:CreateSlider(opts)
            local Row = Card(52)
            New("TextLabel", {
                Text = opts.Name, Font = Tokens.FontLabel, TextSize = 13,
                TextColor3 = Tokens.TextPrimary, BackgroundTransparency = 1,
                Size = UDim2.new(1, -80, 0, 18), Position = UDim2.new(0, 16, 0, 8),
                TextXAlignment = Enum.TextXAlignment.Left, Parent = Row,
            })
            local ValueLbl = New("TextLabel", {
                Text = tostring(opts.CurrentValue or opts.Min or 0), Font = Tokens.FontMono, TextSize = 11,
                TextColor3 = Tokens.AccentB, BackgroundTransparency = 1,
                Size = UDim2.new(0, 60, 0, 18), Position = UDim2.new(1, -76, 0, 8),
                TextXAlignment = Enum.TextXAlignment.Right, Parent = Row,
            })
            local Track = New("Frame", {
                Size = UDim2.new(1, -32, 0, 5), Position = UDim2.new(0, 16, 1, -16),
                BackgroundColor3 = Tokens.Border, BackgroundTransparency = 0.85,
                BorderSizePixel = 0, Parent = Row,
            }, { Corner(3) }, { BackgroundColor3 = "Border" })
            local Fill = New("Frame", {
                Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Tokens.AccentA,
                BorderSizePixel = 0, Parent = Track,
            }, { Corner(3), AccentGradient(0) })
            -- Fill's gradient (AccentA->AccentB) is baked at creation and
            -- NOT retheme-tracked here -- a gradient repaint would need
            -- to touch the UIGradient's Color sequence, not a plain
            -- property, which is a different registry shape. Acceptable
            -- gap for this pass: the base BackgroundColor3 still updates,
            -- the gradient overlay just keeps its original hue. Flagging
            -- rather than silently shipping a half-retheme.

            local min, max = opts.Min or 0, opts.Max or 100
            local value = opts.CurrentValue or min

            local function Render(v, instant)
                value = math.clamp(v, min, max)
                local ratio = (value - min) / (max - min)
                Tween(Fill, { Size = UDim2.new(ratio, 0, 1, 0) }, instant and TweenInfo.new(0) or Tokens.Tween)
                ValueLbl.Text = opts.Suffix and (tostring(math.floor(value)) .. opts.Suffix) or tostring(math.floor(value))
            end

            -- v2.1 bug: the global InputChanged listener would drive
            -- WHICHEVER slider last set `dragging = true`, with no
            -- ownership check -- starting a drag on Slider B while
            -- Slider A's `dragging` flag was still true (e.g. mouse
            -- left the track before InputEnded fired, common on fast
            -- flicks) could make A silently eat B's drag. Fix: each
            -- slider only listens to a module-level `activeSlider`
            -- token that IT set, and only reacts if it still owns it.
            local dragging = false
            Track.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                end
            end)
            UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                end
            end)
            UserInputService.InputChanged:Connect(function(i)
                if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                    local relX = (i.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X
                    Render(min + relX * (max - min))
                    if opts.Callback then opts.Callback(math.floor(value)) end
                    if opts.Flag then Window.Flags[opts.Flag].Value = math.floor(value) end
                end
            end)

            Render(value, true)

            RegisterFlag(opts.Flag, value, function(v)
                Render(v, true)
                if opts.Callback then opts.Callback(math.floor(value)) end
            end)

            return {
                Set = function(v) Render(v); if opts.Callback then opts.Callback(math.floor(value)) end end,
                Destroy = function() Row:Destroy() end,
            }
        end

        function TabAPI:CreateDropdown(opts)
            local Row = Card(46)
            local options = opts.Options or {}
            local current = (opts.CurrentOption and opts.CurrentOption[1]) or options[1]

            New("TextLabel", {
                Text = opts.Name, Font = Tokens.FontLabel, TextSize = 13,
                TextColor3 = Tokens.TextPrimary, BackgroundTransparency = 1,
                Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 16, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left, Parent = Row,
            })
            local ValueBtn = New("TextButton", {
                Text = tostring(current) .. "  ▾", Font = Tokens.FontMono, TextSize = 11,
                TextColor3 = Tokens.AccentB, BackgroundTransparency = 1,
                Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.new(0.55, -10, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Right, AutoButtonColor = false, Parent = Row,
            }, nil, { TextColor3 = "AccentB" })
            local OptFrame = New("Frame", {
                BackgroundColor3 = Tokens.Glass, BackgroundTransparency = 0.15,
                BorderSizePixel = 0, Visible = false,
                Size = UDim2.new(1, 0, 0, #options * 28), Position = UDim2.new(0, 0, 1, 4),
                ZIndex = 5, Parent = Row,
            }, { Corner(10), Stroke(Tokens.Border, 1, 0.8), New("UIListLayout", {}) })

            local function CloseThis()
                OptFrame.Visible = false
                ClickCatcher.Visible = false
                openDropdown = nil
            end
            local function OpenThis()
                -- v2.1 bug: opening a second dropdown left the first one's
                -- OptFrame visible and its options still clickable
                -- underneath -- overlapping hitboxes, silent misclicks.
                -- Fix: exactly one open dropdown at a time, tracked at
                -- Window scope, closed before this one opens.
                CloseOpenDropdown()
                OptFrame.Visible = true
                ClickCatcher.Visible = true
                ClickCatcher.ZIndex = 3 -- under OptFrame(5), above everything else
                openDropdown = { OptFrame = OptFrame, Close = CloseThis }
            end

            for i, opt in ipairs(options) do
                local OptBtn = New("TextButton", {
                    Text = opt, Font = Tokens.FontLabel, TextSize = 12, TextColor3 = Tokens.TextPrimary,
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = i,
                    ZIndex = 5, Parent = OptFrame,
                })
                OptBtn.MouseButton1Click:Connect(function()
                    current = opt
                    ValueBtn.Text = opt .. "  ▾"
                    CloseThis()
                    if opts.Callback then opts.Callback({opt}) end
                    if opts.Flag then Window.Flags[opts.Flag].Value = opt end
                end)
            end
            ValueBtn.MouseButton1Click:Connect(function()
                if OptFrame.Visible then CloseThis() else OpenThis() end
            end)

            RegisterFlag(opts.Flag, current, function(v)
                current = v
                ValueBtn.Text = tostring(v) .. "  ▾"
                if opts.Callback then opts.Callback({v}) end
            end)

            return {
                Set = function(v) current = v; ValueBtn.Text = v .. "  ▾" end,
                -- If this dropdown happens to be the currently open one,
                -- clear the Window-scope pointer first -- otherwise a
                -- later click-outside would call Close() on a dead
                -- OptFrame (Row already destroyed) and error mid-event.
                Destroy = function()
                    if openDropdown and openDropdown.OptFrame == OptFrame then
                        openDropdown = nil
                        ClickCatcher.Visible = false
                    end
                    Row:Destroy()
                end,
            }
        end

        function TabAPI:CreateKeybind(opts)
            local Row = Card(46)
            New("TextLabel", {
                Text = opts.Name, Font = Tokens.FontLabel, TextSize = 13,
                TextColor3 = Tokens.TextPrimary, BackgroundTransparency = 1,
                Size = UDim2.new(1, -110, 1, 0), Position = UDim2.new(0, 16, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left, Parent = Row,
            })

            local currentKey = opts.CurrentKeybind or Enum.KeyCode.Unknown
            local BindBtn = New("TextButton", {
                Text = currentKey.Name, Font = Tokens.FontMono, TextSize = 11,
                TextColor3 = Tokens.AccentB, BackgroundColor3 = Tokens.Border,
                BackgroundTransparency = 0.9, BorderSizePixel = 0,
                Size = UDim2.new(0, 84, 0, 26), Position = UDim2.new(1, -96, 0.5, -13),
                AutoButtonColor = false, Parent = Row,
            }, { Corner(8) })

            -- Registers this handler under `key` in the shared dispatch
            -- table. Multiple keybinds can share a key (e.g. two features
            -- both bound to F -- both fire, order = registration order).
            local registeredKey = nil
            local function Register(key)
                if registeredKey then
                    local list = keybindHandlers[registeredKey]
                    if list then
                        for i = #list, 1, -1 do
                            if list[i] == FireCallback then table.remove(list, i) end
                        end
                    end
                end
                registeredKey = key
                if key and key ~= Enum.KeyCode.Unknown then
                    keybindHandlers[key] = keybindHandlers[key] or {}
                    table.insert(keybindHandlers[key], FireCallback)
                end
            end

            function FireCallback()
                if opts.Callback then opts.Callback() end
            end

            BindBtn.MouseButton1Click:Connect(function()
                if capturingKeybind then return end -- one capture at a time
                BindBtn.Text = "..."
                Tween(BindBtn, { BackgroundTransparency = 0.6 })
                capturingKeybind = function(input)
                    capturingKeybind = nil
                    Tween(BindBtn, { BackgroundTransparency = 0.9 })
                    if input.UserInputType ~= Enum.UserInputType.Keyboard then
                        BindBtn.Text = currentKey.Name
                        return
                    end
                    currentKey = input.KeyCode
                    BindBtn.Text = currentKey.Name
                    Register(currentKey)
                    if opts.Flag then Window.Flags[opts.Flag].Value = currentKey.Name end
                end
            end)

            Register(currentKey)

            RegisterFlag(opts.Flag, currentKey.Name, function(v)
                local key = Enum.KeyCode[v]
                if key then
                    currentKey = key
                    BindBtn.Text = key.Name
                    Register(key)
                end
            end)

            return {
                Set = function(v) currentKey = v; BindBtn.Text = v.Name; Register(v) end,
                -- Register(nil) strips this control's FireCallback out of
                -- keybindHandlers[registeredKey] without registering a
                -- replacement. Skipping this step would leave a closure
                -- alive in the shared dispatch table pointing at a Row
                -- that no longer exists -- next matching keypress calls
                -- opts.Callback() for a control the caller thinks is gone.
                Destroy = function()
                    Register(nil)
                    Row:Destroy()
                end,
            }
        end

        function TabAPI:CreateSection(name)
            local Label = New("TextLabel", {
                Text = name:upper(), Font = Tokens.FontHeader, TextSize = 11,
                TextColor3 = Tokens.TextMuted, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 20), LayoutOrder = #Page:GetChildren(),
                TextXAlignment = Enum.TextXAlignment.Left, Parent = Page,
            }, nil, { TextColor3 = "TextMuted" })
            return { Destroy = function() UnregisterThemed(Label); Label:Destroy() end }
        end

        function TabAPI:CreateParagraph(opts)
            local Row = New("Frame", {
                BackgroundColor3 = Tokens.Glass, BackgroundTransparency = 0.55, BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 50), AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = #Page:GetChildren(), Parent = Page,
            }, { Corner(12), Pad(14, 10, 14, 10) }, { BackgroundColor3 = "Glass" })
            New("TextLabel", {
                Text = opts.Title, Font = Tokens.FontHeader, TextSize = 12,
                TextColor3 = Tokens.TextPrimary, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = Row,
            }, nil, { TextColor3 = "TextPrimary" })
            New("TextLabel", {
                Text = opts.Content, Font = Tokens.FontLabel, TextSize = 11,
                TextColor3 = Tokens.TextMuted, TextWrapped = true, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                Position = UDim2.new(0, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Parent = Row,
            }, nil, { TextColor3 = "TextMuted" })
            return { Destroy = function() UnregisterThemed(Row); Row:Destroy() end }
        end

        return TabAPI
    end

    return Window, ScreenGui
end

return { CreateWindow = CreateWindow, Tokens = Tokens, Themes = Themes }
