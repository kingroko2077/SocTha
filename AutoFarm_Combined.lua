--[[
    Blox Fruits Auto Farm + ThahNamUI v2.7 — combined single-file build
    Không phụ thuộc HttpGet/GitHub — thư viện UI được nhúng thẳng bên dưới.
    Nguồn ThahNamUI: file gốc do user cung cấp (v2.7, glass-lite).
]]

-- ============================================================
-- PHẦN 1: THAHNAMUI LIBRARY (nhúng trực tiếp, không loadstring)
-- ============================================================
local function LoadThahNamUI()
--[[
    THAH NAM UI v2.7 -- glass-lite, optimized for 24/7 uptime.

    DESIGN: glassmorphism WITHOUT real backdrop blur. Roblox has no native
    UI blur -- "glass" here means translucent panels + soft static
    gradient + thin border. Real blur would mean re-rendering the 3D
    scene through a ViewportFrame every frame, which is the opposite of
    what a 24/7 hub wants.

    PERFORMANCE CONTRACT (unchanged from v2.1, still enforced in v2.2):
    1. Every Tween is event-driven (click/hover/state-change). Nothing
       tweens on a loop, nothing re-tweens every Heartbeat.
    2. Exactly one background gradient, created once at window build time,
       never re-created or re-tweened after.
    3. No custom RenderStepped/Heartbeat connections owned by the UI layer.
       Sliders/drag use InputChanged (engine-debounced event stream).
    4. Card creation is O(1) per control at build time.
    5. Re-execute safety: destroys any prior ThahNamUI ScreenGui.

    WHAT'S NEW IN v2.2 (carried forward)
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

    WHAT'S NEW IN v2.3 -- bugfix pass
    - Slider connection leak: CreateSlider() was firing three raw
      Track.InputBegan / UserInputService.InputEnded / .InputChanged
      connections with no handle stored anywhere. Row:Destroy() kills the
      Instance tree, not a connection sitting in a Lua closure -- every
      slider ever created (including ones destroyed or nuked by
      re-execute) left two permanent dead listeners on UserInputService
      for the rest of the process lifetime. Now captured and disconnected
      in Destroy().
    - Slider touch input: Track.InputBegan only matched MouseButton1.
      TopBar-drag and the FAB both handle Touch; the slider didn't --
      mobile/touch users could not drag it at all. Added the Touch branch
      to InputBegan/InputEnded/InputChanged alongside MouseButton1.
    - Toast LayoutOrder: was os.clock() written into an int32 property.
      Roblox truncates the float to whole seconds on assignment, so
      every toast fired within the same second collapsed to an identical
      LayoutOrder and ordering fell back to undocumented tie-breaking.
      Replaced with a monotonic per-window counter.
    - Dropdown Set(): accepted any value with no membership check against
      Options, including values arriving from LoadConfig()'s JSON blob.
      A stale or hand-edited config could park the control on a value
      with no corresponding highlighted option. Set() now no-ops if the
      value isn't in the option list.

    WHAT'S NEW IN v2.4 -- crash fix
    - Fab was Instance.new("ImageButton") carrying Text = "" in its
      props table. ImageButton has no Text property (only TextButton and
      the label classes do) -- New()'s assignment loop is an unguarded
      `inst[k] = v`, so this threw "Text is not a valid member of
      ImageButton" on every execute, unwinding all of CreateWindow()
      before a single frame rendered. Property removed; the FAB's glyph
      was always drawn by a separate TextLabel child, never by this
      property.

    WHAT'S NEW IN v2.5 -- MenuButton
    - New pill-shaped labeled toggle, yellow "Menu" style seen in mobile
      hubs. Distinct from the FAB: FAB is a small icon-only circle on
      the mid-right edge; MenuButton is a wider labeled pill, default
      bottom-left. Both read/write the SAME uiVisible/SetUIVisible/
      ToggleVisible upvalues as the FAB, so the two controls (and any
      keybind bound to ToggleVisible) can never go out of sync -- one
      visibility state per window. Same drag-vs-click disambiguation as
      the FAB (moved-threshold gate). Fill/label color repaints via
      rerenderCallbacks so SetTheme() picks it up like every other
      stateful control.

    WHAT'S NEW IN v2.6 -- FAB placement fix
    - Fab was anchored at mid-right of the whole ScreenGui (Position
      Y-scale 0.5), on the assumption that spot is always clear of
      Root/Ambient. That's only true when Root is small relative to the
      viewport -- on a phone screen, or with a wider/taller configured
      Width/Height, Root's bounds extend into mid-right and Fab renders
      on top (ZIndex/Sibling math was always correct) but visually
      disappears: its BackgroundTransparency = 0.15 Glass tone sits on
      top of Root's own near-identical Glass background with too little
      contrast to read as a separate control. Moved Fab to the
      bottom-right corner of the screen instead, mirroring MenuButton's
      bottom-left placement -- both buttons now sit below Root/Ambient's
      bounds unconditionally, since Root always keeps a >=20px pad from
      every screen edge (see Ambient's centering math and
      ToggleMaximize's pad = 20).

    WHAT'S NEW IN v2.7 -- true top-most layer for Fab/MenuButton
    - v2.6 fixed the visibility case (Fab wasn't actually covered, just
      low-contrast against Root). This pass makes "on top of everything"
      a structural guarantee instead of a ZIndex number that happens to
      currently be the highest one in use. ZIndexBehavior.Sibling only
      orders children of the SAME direct parent -- Fab/MenuButton's
      ZIndex=60 only beat whatever else was ALSO a direct child of the
      main ScreenGui with a lower number. Any future control parented
      into the main ScreenGui with ZIndex > 60 would still render above
      them. Moved both into a dedicated second ScreenGui (OverlayGui,
      DisplayOrder = 2147483647 -- max int32) parented alongside the
      main one. Roblox stacks separate ScreenGuis by DisplayOrder,
      completely independent of any ZIndex math inside either one -- so
      this is not a bigger number racing other numbers, it's a different
      compositing layer entirely. Root, ToastLayer, ClickCatcher, and
      every tab/control stay in the main ScreenGui, untouched. Re-execute
      safety extended: OverlayGui gets its own FindFirstChild/Destroy
      guard (ThahNamUIOverlay) alongside the main ThahNamUI guard, and
      Window:Destroy() now tears down both ScreenGuis explicitly --
      previously ScreenGui:Destroy() alone was correct because Fab was
      its child; now it isn't, so OverlayGui:Destroy() had to be added
      or every window teardown would leak a full ScreenGui plus its
      buttons, connections, and rerenderCallbacks closures.

    TOKENS
    Background   #120E1F  (deep violet-black panel base)
    Glass        #1C1730  @ 30% transparency (the "glass" layer)
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

    -- Window size is now configurable via config.Width/Height. Default
    -- reduced from 700x460 (original v2.2) to 520x360 -- everything
    -- inside Root (Sidebar, Content, TopBar) is already defined in
    -- Scale ratios (UDim2.new(1, -8, 1, -8) etc.), not hardcoded Offset
    -- numbers, so resizing Ambient alone is enough -- no need to touch
    -- the internal layout.
    local winW = config.Width or 520
    local winH = config.Height or 360

    local existing = PlayerGui:FindFirstChild("ThahNamUI")
    if existing then existing:Destroy() end -- 24/7 re-execute safety

    -- Every ScreenGui's DisplayOrder defaults to 0 if not set explicitly
    -- -- this main ScreenGui (holding Root/Ambient/all tab controls)
    -- previously did NOT set DisplayOrder, so it sat at 0, and any
    -- ScreenGui the GAME creates with DisplayOrder > 0 (very common --
    -- HUDs, tutorial overlays, in-game promo banners routinely set a
    -- high value to stay on top) would draw OVER this entire panel,
    -- even with a high ZIndex inside Root -- ZIndex only compares
    -- within the SAME ScreenGui, it can't compare across different
    -- ScreenGuis (that's DisplayOrder's job). This is why the main
    -- panel was getting covered by the game's tutorial/HUD buttons in
    -- the real screenshot.
    -- FIX: give the main ScreenGui a high DisplayOrder -- exactly one
    -- step below OverlayGui (max-int - 1) to preserve the correct
    -- INTERNAL ordering: MenuButton (OverlayGui) must still render
    -- above Root (main ScreenGui) too -- the two layers shouldn't share
    -- the same DisplayOrder and have to fall back on fragile
    -- insertion-order tie-breaking between each other.
    local MAIN_DISPLAY_ORDER = 2147483646 -- max int32 - 1
    local ScreenGui = New("ScreenGui", {
        Name = "ThahNamUI",
        Parent = PlayerGui,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = MAIN_DISPLAY_ORDER,
    })

    -- Separate top-most ScreenGui for FAB/MenuButton. ZIndex only
    -- resolves ordering between children of the SAME parent
    -- (ZIndexBehavior.Sibling) -- Fab's old ZIndex=60 only beat whatever
    -- else happened to also be a direct child of `ScreenGui` with a
    -- lower number. Any future control parented into ScreenGui with a
    -- higher ZIndex, or any nested structure, could still end up
    -- visually on top of it -- that's a hardcoded assumption, not a
    -- structural guarantee. Roblox stacks separate ScreenGuis by
    -- DisplayOrder, independent of any ZIndex math inside either one --
    -- so a dedicated ScreenGui with a high DisplayOrder is the only way
    -- to make "always on top of everything" actually true regardless of
    -- what gets added to the main ScreenGui later. Also re-execute-safe
    -- via the existing FindFirstChild/Destroy guard below, same as the
    -- main ScreenGui.
    local existingOverlay = PlayerGui:FindFirstChild("ThahNamUIOverlay")
    if existingOverlay then existingOverlay:Destroy() end
    local OverlayGui = New("ScreenGui", {
        Name = "ThahNamUIOverlay",
        Parent = PlayerGui,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 2147483647, -- max int32 -- highest legal DisplayOrder, wins against any other ScreenGui in the DataModel short of another script also claiming max-int
    })

    -- Self-healing top layer, for BOTH ScreenGuis. DisplayOrder set at
    -- creation time only guarantees "on top of everything that EXISTS
    -- right now" -- it says nothing about a ScreenGui the GAME parents
    -- into PlayerGui a moment later. Two concrete ways that breaks:
    --   1. Game UI also claims a high DisplayOrder (very common -- HUDs,
    --      tutorial overlays, in-game banners routinely set a high
    --      value to stay on top of everything else) -- if it ties or
    --      beats ours, Roblox falls back to insertion order, and a
    --      later-inserted ScreenGui can render over an earlier one even
    --      at the same DisplayOrder.
    --   2. Game re-parents or recreates one of its own ScreenGuis after
    --      ours already exists (very common -- HUD rebuilt on respawn,
    --      on a size-class change, on a game-state transition). The new
    --      Instance is a sibling inserted AFTER ours, same tie-break
    --      risk as above.
    -- Can't poll every frame for this (violates this file's no-
    -- Heartbeat/no-RenderStepped contract) -- instead, listen for the
    -- actual event that would ever cause the problem: something new
    -- becoming a ScreenGui-class descendant of PlayerGui. DescendantAdded
    -- only fires on an actual structural change, not per-frame -- same
    -- event-driven philosophy as InputChanged elsewhere in this file.
    -- CoreGui (chat, default backpack, leaderboard) is a SEPARATE render
    -- layer the engine always draws above every ScreenGui in PlayerGui
    -- regardless of DisplayOrder -- no client script can out-order that
    -- layer; StarterGui:SetCoreGuiEnabled()/SetCore() is the only lever
    -- for it, and this file doesn't touch it uninvited.
    local function ReassertTop(gui)
        -- Reassigning the SAME DisplayOrder value doesn't resolve a tie
        -- (Roblox needs a STRICTLY HIGHER number to break a tie via
        -- DisplayOrder alone) -- so on a genuine collision at the same
        -- level, fall back to insertion order as the safety net:
        -- reparent out and back into PlayerGui, making it the most
        -- recently inserted ScreenGui within that tied group, which
        -- Roblox draws LAST (= on top) within that tie.
        gui.Parent = nil
        gui.Parent = PlayerGui
    end

    local overlayWatcherConn
    overlayWatcherConn = PlayerGui.DescendantAdded:Connect(function(inst)
        if inst == ScreenGui or inst == OverlayGui then return end -- our own creation firing this same event
        if not inst:IsA("ScreenGui") then return end
        -- OverlayGui must always hold the absolute top position
        -- (MenuButton can't be covered by anything, including this
        -- library's OWN main ScreenGui) -- check it first.
        if inst.DisplayOrder >= OverlayGui.DisplayOrder then
            ReassertTop(OverlayGui)
        end
        -- The main ScreenGui (Root/big panel) also needs to self-heal
        -- independently -- this was the piece MISSING before, which is
        -- why the panel got covered by the game's tutorial/HUD even
        -- while OverlayGui rendered on top just fine.
        if inst.DisplayOrder >= ScreenGui.DisplayOrder then
            ReassertTop(ScreenGui)
        end
    end)

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
    -- Forward declarations -- TopBar needs to call these functions
    -- (minimize, maximize, destroy, close-confirm) but their real
    -- bodies are assigned further below, after Ambient/ClickCatcher/
    -- sharedInputConn/ConfirmOverlay already exist. Declared here so
    -- TopBar's closures capture the correct upvalues -- assigning the
    -- real value later still reflects correctly in closures created
    -- earlier, because Lua closures hold a reference to the variable,
    -- not the value at creation time.
    --------------------------------------------------------------
    local ToggleVisible -- function() ... end, assigned below
    local ToggleMaximize -- function() ... end, assigned below
    local DestroyWindow -- function() ... end, assigned below
    local ShowCloseConfirm -- function() ... end, assigned below (after ConfirmOverlay)

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
        -- Narrowed and shifted left compared to the original (200px
        -- from -160) so it doesn't overlap the 3 title-bar buttons
        -- (the first one starts at -96).
        Size = UDim2.new(0, 110, 0, 14), Position = UDim2.new(1, -220, 0, 13),
        TextXAlignment = Enum.TextXAlignment.Right, Parent = TopBar,
    })

    --------------------------------------------------------------
    -- Title-bar controls: minimize (—), maximize (▢), close (×).
    -- ZIndex=10 explicit -- higher than every other child in Root
    -- (cards don't set ZIndex by default, so they're 1) -- so these
    -- never get covered even if some future control ends up drawing
    -- over the TopBar area.
    --------------------------------------------------------------
    local function TitleBarBtn(text, xOffsetFromRight, hoverColor)
        local Btn = New("TextButton", {
            Text = text, Font = Tokens.FontHeader, TextSize = 13,
            TextColor3 = Tokens.TextMuted, BackgroundColor3 = Tokens.Border,
            BackgroundTransparency = 1, BorderSizePixel = 0,
            AutoButtonColor = false, ZIndex = 10,
            Size = UDim2.new(0, 22, 0, 22),
            Position = UDim2.new(1, xOffsetFromRight, 0, 9),
            Parent = TopBar,
        }, { Corner(6) })
        Btn.MouseEnter:Connect(function()
            Tween(Btn, { BackgroundTransparency = 0.85, TextColor3 = hoverColor or Tokens.TextPrimary })
        end)
        Btn.MouseLeave:Connect(function()
            Tween(Btn, { BackgroundTransparency = 1, TextColor3 = Tokens.TextMuted })
        end)
        return Btn
    end

    local MinBtn = TitleBarBtn("—", -96)
    local MaxBtn = TitleBarBtn("▢", -70)
    local CloseBtn = TitleBarBtn("×", -44, Tokens.Error)

    -- InputBegan (drag) on TopBar and MouseButton1Click on the child
    -- buttons are two SEPARATE events in Roblox -- the latter ALWAYS
    -- fires even when the former also fires, there's no default
    -- "swallow". The real issue in an earlier pass was CloseBtn's
    -- closure calling DestroyWindow() -- an upvalue assigned late
    -- (~line 748 at the time) -- while MouseButton1Click here connects
    -- immediately when CreateWindow runs, BEFORE that assignment
    -- happens. Because DestroyWindow is a forward-declared local (not
    -- a global), Lua captures the correct memory cell even though its
    -- value is still nil at connect time -- calling
    -- Btn.MouseButton1Click:Connect(function() DestroyWindow() end)
    -- at click time (AFTER all of CreateWindow has already run) still
    -- reads the assigned value correctly. This is technically correct
    -- Lua. The more legitimate concern: ScreenGui has several stacked
    -- layers (Ambient > Root > TopBar) and the button sits very close
    -- to the right edge -- on devices with a notch/safe-area, the
    -- outermost strip can get intercepted by another OS/Roblox input
    -- layer. Buttons were shifted inward by 20px as a safety margin.
    MinBtn.MouseButton1Click:Connect(function() ToggleVisible() end)
    MaxBtn.MouseButton1Click:Connect(function() ToggleMaximize() end)
    -- CloseBtn no longer destroys the window directly -- it opens a
    -- confirmation dialog first (see ShowCloseConfirm below, defined
    -- after ConfirmOverlay exists). DestroyWindow only actually runs
    -- if the user taps "Yes" on that dialog.
    CloseBtn.MouseButton1Click:Connect(function()
        ShowCloseConfirm()
    end)

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
    -- Monotonic counter for toast LayoutOrder. Replaces os.clock(), which
    -- truncates to whole seconds when written into an int32 property --
    -- any two toasts fired within the same second collapsed to the same
    -- LayoutOrder. This counter only ever increments, one integer per
    -- toast, so ordering is exact regardless of fire rate.
    local toastCounter = 0
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
    -- Close confirmation dialog. Fires when CloseBtn (×) is clicked --
    -- asks "close or not" instead of destroying the window immediately.
    -- Parented into OverlayGui (not ScreenGui) so it always renders
    -- above Root regardless of DisplayOrder edge cases -- a confirm
    -- dialog that could itself be covered by game UI would defeat the
    -- point of asking. Built once at window creation (same "build
    -- once, toggle Visible" pattern as ClickCatcher above), not
    -- recreated per open/close.
    --------------------------------------------------------------
    local ConfirmDim = New("TextButton", {
        Name = "ConfirmDim",
        Text = "", AutoButtonColor = false,
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.5,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 70, Visible = false,
        Parent = OverlayGui,
    })
    -- Clicking the dim backdrop counts as "No" -- same convention as
    -- ClickCatcher for dropdowns (click-outside-to-cancel).
    ConfirmDim.MouseButton1Click:Connect(function()
        ConfirmDim.Visible = false
    end)

    local ConfirmCard = New("Frame", {
        Name = "ConfirmCard",
        BackgroundColor3 = Tokens.Background,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 260, 0, 130),
        ZIndex = 71,
        Parent = ConfirmDim,
    }, {
        Corner(16),
        Stroke(Tokens.Border, 1, 0.8),
        Pad(18, 16, 18, 16),
    }, { BackgroundColor3 = "Background" })

    New("TextLabel", {
        Text = "Close window?", Font = Tokens.FontHeader, TextSize = 15,
        TextColor3 = Tokens.TextPrimary, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 71, Parent = ConfirmCard,
    }, nil, { TextColor3 = "TextPrimary" })
    New("TextLabel", {
        Text = "This will destroy the UI. You'll need to re-execute the script to bring it back.",
        Font = Tokens.FontLabel, TextSize = 12,
        TextColor3 = Tokens.TextMuted, TextWrapped = true, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 24),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 71, Parent = ConfirmCard,
    }, nil, { TextColor3 = "TextMuted" })

    local NoBtn = New("TextButton", {
        Text = "No", Font = Tokens.FontHeader, TextSize = 13,
        TextColor3 = Tokens.TextPrimary, BackgroundColor3 = Tokens.Border,
        BackgroundTransparency = 0.9, BorderSizePixel = 0,
        AutoButtonColor = false, ZIndex = 71,
        Size = UDim2.new(0, 100, 0, 32),
        Position = UDim2.new(0, 0, 1, -32),
        Parent = ConfirmCard,
    }, { Corner(8) })
    local YesBtn = New("TextButton", {
        Text = "Yes, close", Font = Tokens.FontHeader, TextSize = 13,
        TextColor3 = Color3.fromRGB(20, 16, 10), BackgroundColor3 = Tokens.Error,
        BackgroundTransparency = 0, BorderSizePixel = 0,
        AutoButtonColor = false, ZIndex = 71,
        Size = UDim2.new(0, 116, 0, 32),
        Position = UDim2.new(1, -116, 1, -32),
        Parent = ConfirmCard,
    }, { Corner(8) })

    NoBtn.MouseEnter:Connect(function() Tween(NoBtn, { BackgroundTransparency = 0.75 }) end)
    NoBtn.MouseLeave:Connect(function() Tween(NoBtn, { BackgroundTransparency = 0.9 }) end)
    NoBtn.MouseButton1Click:Connect(function()
        ConfirmDim.Visible = false
    end)

    -- Yes actually destroys the window -- routes through the
    -- forward-declared DestroyWindow upvalue, same reasoning as
    -- CloseBtn's own click handler above: DestroyWindow is assigned
    -- later but Lua closures capture the variable, not its value at
    -- connect time, so this reads the correct function once clicked.
    YesBtn.MouseButton1Click:Connect(function()
        ConfirmDim.Visible = false
        DestroyWindow()
    end)

    ShowCloseConfirm = function()
        ConfirmDim.Visible = true
    end

    --------------------------------------------------------------
    -- Visibility state -- shared by MenuButton and any keybind bound
    -- to it (if a control sets that Flag), so both trigger paths can
    -- never drift out of sync with each other. There is exactly one
    -- uiVisible flag for the whole window.
    --------------------------------------------------------------
    local uiVisible = true
    local function SetUIVisible(v)
        uiVisible = v
        Ambient.Visible = v
        if not v then CloseOpenDropdown() end
    end
    -- Assigned into the forward-declared variable at the top of
    -- CreateWindow (not `local function` here -- that would create a
    -- NEW local, shadowing the variable TitleBarBtn/MinBtn already
    -- captured, and the — button would call into an upvalue that stays
    -- nil forever).
    ToggleVisible = function()
        SetUIVisible(not uiVisible)
    end

    -- Maximize/restore: true fullscreen (minus a 20px safe padding per
    -- edge, to avoid the notch/status bar) when maximized, restores the
    -- original size (winW x winH) on toggle back. Uses
    -- ScreenGui.AbsoluteSize instead of UDim2 Scale=1 because Ambient
    -- stands independently (not a full-size child of ScreenGui) --
    -- Scale=1 would be wrong if ScreenGui were ever nested inside
    -- another container.
    local isMaximized = false
    local savedPos = nil -- position before maximizing, so restore lands back where the user last dragged it
    ToggleMaximize = function()
        isMaximized = not isMaximized
        if isMaximized then
            savedPos = Ambient.Position
            local viewport = ScreenGui.AbsoluteSize
            local pad = 20
            local w = math.max(200, viewport.X - pad * 2)
            local h = math.max(150, viewport.Y - pad * 2)
            Tween(Ambient, {
                Size = UDim2.new(0, w, 0, h),
                Position = UDim2.new(0, pad, 0, pad),
            })
            MaxBtn.Text = "▢▢"
        else
            Tween(Ambient, {
                Size = UDim2.new(0, winW, 0, winH),
                Position = savedPos or UDim2.new(0.5, -winW / 2, 0.5, -winH / 2),
            })
            MaxBtn.Text = "▢"
        end
    end

    -- v2.8: the round Fab (icon-only ImageButton) was REMOVED per
    -- request -- MenuButton (labeled pill) is now the sole UI
    -- visibility toggle. ToggleVisible/uiVisible/SetUIVisible are kept
    -- unchanged below since MenuButton and any keybind bound to
    -- ToggleVisible still need them -- only the Fab's Instance
    -- construction was stripped out.

    --------------------------------------------------------------
    -- MenuButton -- pill-shaped, labeled toggle (yellow "Menu" style,
    -- e.g. Banana Cat Hub / other mobile hubs). Sole visibility toggle
    -- now that Fab is removed (v2.8). Calls the SAME SetUIVisible/
    -- uiVisible upvalues as any keybind bound to ToggleVisible, so
    -- there's still exactly one visibility state in the whole window.
    --
    -- v2.8 placement fix: was bottom-left (16,-16 from that corner).
    -- On this game's HUD that spot sits directly on top of the game's
    -- own stacked reward buttons (+$ cash pickups) and the Rebirth
    -- counter -- both belong to the HOST GAME's UI, not ThahNamUI, and
    -- OverlayGui's top DisplayOrder only wins compositing order, it
    -- doesn't reserve screen space or push other UI out of the way.
    -- Two overlapping clickable layers at the same screen position is
    -- a hitbox conflict regardless of which one paints on top. Moved to
    -- bottom-right, mirroring the old Fab position, which is clear in
    -- this game's layout (only the OS/Roblox system gesture control
    -- sits there, well below MenuButton's 16px inset).
    --------------------------------------------------------------
    local MenuBtnLbl -- forward ref so Render() below can repaint text/color
    local MenuButton = New("TextButton", {
        Name = "MenuButtonToggle",
        AutoButtonColor = false,
        BackgroundColor3 = Tokens.AccentA,
        BackgroundTransparency = 0,
        Text = "", -- valid here, TextButton HAS a Text property -- left
        -- blank on purpose: MenuBtnLbl below is a separate TextLabel
        -- child so RenderMenuButton() can flip label color independently
        -- of the button's own text-color property (same click-catcher-
        -- plus-label split every other control in this file already uses).
        AnchorPoint = Vector2.new(1, 1),
        Size = UDim2.new(0, 96, 0, 34),
        -- Bottom-right, 16px inset off both edges -- same corner the old
        -- Fab used, clear of this game's HUD (see note above). If a
        -- different host game has its own controls in THIS corner
        -- instead, config.MenuButtonPosition below is the escape hatch.
        Position = config.MenuButtonPosition or UDim2.new(1, -16, 1, -16),
        ZIndex = 60,
        Parent = OverlayGui,
    }, {
        Corner(17), -- half of Size.Y -> full pill, not just rounded-rect
    })

    MenuBtnLbl = New("TextLabel", {
        Text = "Menu", Font = Tokens.FontHeader, TextSize = 14,
        TextColor3 = Color3.fromRGB(20, 16, 10), BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0), ZIndex = 61, Parent = MenuButton,
    })

    -- Render() repaints both the pill's fill and the label to reflect
    -- current uiVisible -- visually distinct from the FAB, which never
    -- changes appearance on toggle. This gives the player two different
    -- signals for the same state: FAB stays a static icon, MenuButton's
    -- text/color flips, matching how the reference hub's button reads
    -- as an on/off switch rather than a pure open/close glyph.
    local function RenderMenuButton()
        if uiVisible then
            MenuButton.BackgroundColor3 = Tokens.AccentA
            MenuBtnLbl.Text = "Menu"
            MenuBtnLbl.TextColor3 = Color3.fromRGB(20, 16, 10)
        else
            MenuButton.BackgroundColor3 = Tokens.Glass
            MenuBtnLbl.Text = "Menu"
            MenuBtnLbl.TextColor3 = Tokens.TextPrimary
        end
    end
    RenderMenuButton()

    -- SetTheme() only walks `themedInstances`/`rerenderCallbacks` (see
    -- the New()/RegisterRerender machinery above) -- MenuButton's fill
    -- is state-dependent (on/off), same category as Toggle's Track, so
    -- it registers into rerenderCallbacks rather than a static themeMap.
    -- Re-set here reuses the same list every other stateful control uses.
    table.insert(rerenderCallbacks, RenderMenuButton)

    -- Same drag-vs-click disambiguation as the FAB: `moved` gates
    -- whether MouseButton1Click actually toggles, so ending a drag on
    -- top of the button doesn't also fire a toggle at the drop point.
    do
        local dragging, dragStart, startPos = false, nil, nil
        local moved = false
        MenuButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                moved = false
                dragStart = input.Position
                startPos = MenuButton.Position
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
                MenuButton.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
        MenuButton.MouseButton1Click:Connect(function()
            if not moved then
                ToggleVisible()
                RenderMenuButton()
            end
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

        toastCounter = toastCounter + 1
        local Toast = New("Frame", {
            BackgroundColor3 = Tokens.Glass, BackgroundTransparency = 1,
            BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ClipsDescendants = true, LayoutOrder = toastCounter,
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
        -- Watcher installed alongside OverlayGui above (DescendantAdded on
        -- PlayerGui) -- PlayerGui itself is never destroyed by this
        -- library (it's the engine's own container), so without this
        -- explicit disconnect the connection would outlive both
        -- ScreenGuis and keep firing on every future ScreenGui the game
        -- creates for the rest of the process lifetime, for a window
        -- that no longer exists.
        overlayWatcherConn:Disconnect()
        ScreenGui:Destroy()
        -- Fab/MenuButton now live in OverlayGui, a SEPARATE ScreenGui
        -- instance (see the DisplayOrder note above) -- ScreenGui:Destroy()
        -- above only tears down the main window, it has no reach into a
        -- sibling ScreenGui. Skipping this line would leak OverlayGui
        -- (and its two buttons, connections, and rerenderCallbacks
        -- closures) every time the window is destroyed or re-executed.
        OverlayGui:Destroy()
    end
    -- The TopBar's × button (via the close-confirm dialog) calls
    -- through this upvalue instead of calling Window:Destroy() directly
    -- from CloseBtn's closure, because the `Window` method can be
    -- overridden by the caller after CreateWindow returns (a valid
    -- pattern) -- while DestroyWindow always points at the original,
    -- correct teardown behavior.
    DestroyWindow = function() Window:Destroy() end

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

        -- A real button control, not a Toggle wearing a trenchcoat --
        -- hover-darken, press-flash, single click event, built against
        -- ThahNamUI's own token set and Tween() helper.
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

            -- Per-element Destroy lets a caller tear down one control
            -- without nuking the whole tab page. Row is the single root
            -- Instance; every child (label, pill, click-catcher) dies
            -- with it.
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

            -- v2.1 bug (still fixed here): the global InputChanged
            -- listener would drive WHICHEVER slider last set
            -- `dragging = true`, with no ownership check -- starting a
            -- drag on Slider B while Slider A's `dragging` flag was
            -- still true (e.g. mouse left the track before InputEnded
            -- fired) could make A silently eat B's drag. Each slider's
            -- closure only reacts to its OWN `dragging` upvalue, so
            -- ownership is per-instance by construction.
            --
            -- v2.3 fix: all three connections below are captured into
            -- local handles and disconnected in Destroy(). Previously
            -- they were fire-and-forget -- Row:Destroy() tears down the
            -- Instance tree but has no reach into a RBXScriptConnection
            -- sitting in a Lua closure, so every slider ever created
            -- left two dead listeners pinned on UserInputService for
            -- the rest of the process lifetime (harmless per-instance,
            -- compounds across a 24/7 session with re-executes).
            --
            -- v2.3 also adds Touch alongside MouseButton1 -- TopBar-drag
            -- and the FAB both handle Touch already; the slider didn't,
            -- so it was mouse-only.
            local dragging = false
            local function IsPointerDown(t)
                return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
            end
            local beganConn = Track.InputBegan:Connect(function(i)
                if IsPointerDown(i.UserInputType) then
                    dragging = true
                end
            end)
            local endedConn = UserInputService.InputEnded:Connect(function(i)
                if IsPointerDown(i.UserInputType) then
                    dragging = false
                end
            end)
            local changedConn = UserInputService.InputChanged:Connect(function(i)
                if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
                    or i.UserInputType == Enum.UserInputType.Touch) then
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
                -- v2.3: disconnect all three UserInputService/Track
                -- listeners before tearing down Row -- see note above.
                Destroy = function()
                    beganConn:Disconnect()
                    endedConn:Disconnect()
                    changedConn:Disconnect()
                    Row:Destroy()
                end,
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

            -- v2.3: this is the setter LoadConfig() actually calls
            -- (entry.Set -> RegisterFlag's wrapper -> here), NOT the
            -- Set() in the returned table below -- LoadConfig reads
            -- flag values straight out of a JSON file and had no
            -- membership check on this path either. Same guard applied.
            RegisterFlag(opts.Flag, current, function(v)
                if not table.find(options, v) then return end
                current = v
                ValueBtn.Text = tostring(v) .. "  ▾"
                if opts.Callback then opts.Callback({v}) end
            end)

            return {
                -- v2.3: Set() previously accepted any value with no
                -- check against `options` -- including values arriving
                -- from LoadConfig()'s JSON blob, which round-trips
                -- straight to Set() with no validation of its own. A
                -- stale or hand-edited config file could park the
                -- control on text with no corresponding highlighted
                -- OptBtn. No-op on values not in the option list.
                Set = function(v)
                    if not table.find(options, v) then return end
                    current = v; ValueBtn.Text = v .. "  ▾"
                end,
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
            --
            -- BUGFIX: FireCallback used to be declared with
            -- `function FireCallback() ... end` -- no `local`, so it
            -- created a process-wide GLOBAL. Every CreateKeybind() call
            -- reassigned the SAME global to a new closure. Register()'s
            -- removal loop matches by identity (`list[i] == FireCallback`),
            -- so once a second keybind existed, the global no longer
            -- pointed at the first keybind's closure -- Register(nil)
            -- from keybind #1's Destroy() silently failed to find its own
            -- handler in the list (comparing against keybind #2's current
            -- closure instead) and never removed it. Net effect: Destroy()
            -- on any keybind control stopped actually unregistering its
            -- handler as soon as more than one keybind existed -- a
            -- permanent leaked closure in keybindHandlers per destroyed
            -- control, firing opts.Callback() for a Row that no longer
            -- exists on every future matching keypress.
            -- FIX: forward-declare FireCallback as a `local` scoped to
            -- this CreateKeybind() call, same pattern as registeredKey --
            -- one distinct upvalue per keybind instance, so identity
            -- comparison in Register() always matches THIS control's
            -- closure regardless of how many other keybinds exist.
            local registeredKey = nil
            local FireCallback
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

            FireCallback = function()
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
end

local ThahNamUI = LoadThahNamUI()

-- ============================================================
-- PHẦN 2: AUTO FARM — hitbox reach + hover tween
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- ============ CONFIG ============
local Config = {
    Enabled = false,
    ScanRadius = 150,        -- radius quét mob (rộng)
    HitboxReach = 25,        -- reach tấn công thực tế — đây là "hitbox rộng"
    HoverHeight = 8,          -- cao bao nhiêu trên đầu quái
    TweenSpeed = 0.15,        -- giây, tween di chuyển tới vị trí
    AttackInterval = 0.1,
    MobBlacklist = {},
}

local State = {
    Running = false,
    CurrentTween = nil,
    Connection = nil,
}

-- ============ UTIL ============
local function getHRP(model)
    return model and model:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(model)
    return model and model:FindFirstChildOfClass("Humanoid")
end

local function getModelHeight(model)
    local ok, cf, size = pcall(function()
        return model:GetBoundingBox()
    end)
    if ok and size then
        return size.Y
    end
    return 5
end

local function isPlayerModel(model)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == model then return true end
    end
    return false
end

-- ============ MOB SCAN ============
local function getNearbyMobs(radius)
    local mobs = {}
    local hrpPos = HumanoidRootPart.Position

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= Character then
            local hum = getHumanoid(obj)
            local hrp = getHRP(obj)

            if hum and hrp and hum.Health > 0 and hum.MaxHealth > 0 and not isPlayerModel(obj) then
                local blacklisted = false
                for _, name in ipairs(Config.MobBlacklist) do
                    if obj.Name:lower():find(name:lower()) then
                        blacklisted = true
                        break
                    end
                end

                if not blacklisted then
                    local dist = (hrpPos - hrp.Position).Magnitude
                    if dist <= radius then
                        table.insert(mobs, {model = obj, hrp = hrp, hum = hum, dist = dist})
                    end
                end
            end
        end
    end

    table.sort(mobs, function(a, b) return a.dist < b.dist end)
    return mobs
end

-- ============ HOVER TWEEN — bay lên đầu quái ============
local function hoverAbove(mob)
    if not HumanoidRootPart or not mob.hrp or not mob.hrp.Parent then return end

    local height = getModelHeight(mob.model)
    local targetPos = mob.hrp.Position + Vector3.new(0, height + Config.HoverHeight, 0)
    local targetCFrame = CFrame.new(targetPos, mob.hrp.Position)

    if State.CurrentTween then
        State.CurrentTween:Cancel()
    end

    Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

    local tweenInfo = TweenInfo.new(
        Config.TweenSpeed,
        Enum.EasingStyle.Sine,
        Enum.EasingDirection.Out
    )

    State.CurrentTween = TweenService:Create(HumanoidRootPart, tweenInfo, {
        CFrame = targetCFrame
    })
    State.CurrentTween:Play()

    return State.CurrentTween
end

-- ============ HITBOX SPOOF — remote arg injection ============
local function fireWeaponRemote(mob)
    local tool = Character:FindFirstChildOfClass("Tool")
    if not tool then return end

    local args = {
        mob.model,
        mob.hrp.Position,
        Config.HitboxReach,
    }

    for _, child in ipairs(tool:GetDescendants()) do
        if child:IsA("RemoteEvent") then
            pcall(function()
                child:FireServer(unpack(args))
            end)
        end
    end

    tool:Activate()
end

-- ============ ATTACK LOOP ============
local function attackMob(mob)
    while State.Running and mob.hum and mob.hum.Health > 0 and mob.hrp and mob.hrp.Parent do
        local dist = (HumanoidRootPart.Position - mob.hrp.Position).Magnitude
        if dist > Config.HitboxReach then
            hoverAbove(mob)
            task.wait(Config.TweenSpeed)
        end

        fireWeaponRemote(mob)
        task.wait(Config.AttackInterval)

        mob.hum = getHumanoid(mob.model)
    end

    if Humanoid then
        Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

-- ============ MAIN LOOP ============
local function farmLoop()
    while State.Running do
        if not Humanoid or Humanoid.Health <= 0 then
            task.wait(2)
            Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
            Humanoid = Character:WaitForChild("Humanoid")
            task.wait(1)
        end

        local mobs = getNearbyMobs(Config.ScanRadius)

        if #mobs == 0 then
            task.wait(1)
        else
            local target = mobs[1]
            hoverAbove(target)
            task.wait(Config.TweenSpeed + 0.05)
            attackMob(target)
        end

        task.wait(0.05)
    end
end

-- ============ GUI ============
local Window = ThahNamUI.CreateWindow({
    Title = "Thah Nam Hub",
    Subtitle = "Auto Farm — Hitbox + Hover",
    Width = 520,
    Height = 360,
})

local Main = Window:CreateTab("Main", "★")
Main:CreateSection("Auto Farm")

Main:CreateToggle({
    Name = "Auto Farm (Hover + Hitbox)",
    Flag = "AutoFarm",
    CurrentValue = false,
    Callback = function(v)
        State.Running = v
        if v then
            task.spawn(farmLoop)
        elseif State.CurrentTween then
            State.CurrentTween:Cancel()
        end
    end,
})

Main:CreateSlider({
    Name = "Scan Radius (tìm quái)",
    Flag = "ScanRadius",
    Min = 30,
    Max = 500,
    Default = Config.ScanRadius,
    Callback = function(v)
        Config.ScanRadius = v
    end,
})

Main:CreateSlider({
    Name = "Hitbox Reach (sát thương)",
    Flag = "HitboxReach",
    Min = 5,
    Max = 100,
    Default = Config.HitboxReach,
    Callback = function(v)
        Config.HitboxReach = v
    end,
})

Main:CreateSlider({
    Name = "Hover Height (độ cao trên đầu)",
    Flag = "HoverHeight",
    Min = 2,
    Max = 50,
    Default = Config.HoverHeight,
    Callback = function(v)
        Config.HoverHeight = v
    end,
})

Main:CreateSlider({
    Name = "Tween Speed",
    Flag = "TweenSpeed",
    Min = 0.05,
    Max = 1,
    Default = Config.TweenSpeed,
    Callback = function(v)
        Config.TweenSpeed = v
    end,
})

Window:Notify({
    Title = "Auto Farm",
    Content = "Đã load — bật toggle để bắt đầu.",
    Type = "info",
    Duration = 3,
})
