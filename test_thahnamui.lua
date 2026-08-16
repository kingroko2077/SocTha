--[[
    Demo test cho ThahNamUI v2.2
    Load thư viện từ GitHub raw, dựng window mẫu để kiểm tra toàn bộ control.
]]

local ThahNamUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/kingroko2077/SocTha/main/ThahNamUI.lua"
))()

local Window = ThahNamUI.CreateWindow({
    Title = "Thah Nam Hub",
    Subtitle = "v2.2 demo",
})

--------------------------------------------------
-- Tab 1: Main
--------------------------------------------------
local Main = Window:CreateTab("Main", "★")

Main:CreateSection("Cơ bản")

Main:CreateToggle({
    Name = "Auto Farm",
    Flag = "AutoFarm",
    CurrentValue = false,
    Callback = function(v)
        print("[AutoFarm]", v)
    end,
})

Main:CreateSlider({
    Name = "Tốc độ",
    Flag = "Speed",
    Min = 16,
    Max = 200,
    Default = 16,
    Callback = function(v)
        print("[Speed]", v)
    end,
})

Main:CreateDropdown({
    Name = "Chế độ",
    Flag = "Mode",
    Options = { "Farm", "PvP", "AFK" },
    CurrentOption = "Farm",
    Callback = function(v)
        print("[Mode]", v[1])
    end,
})

Main:CreateKeybind({
    Name = "Toggle UI",
    Flag = "ToggleUIKey",
    CurrentKeybind = Enum.KeyCode.RightControl,
    Callback = function()
        Window:Notify({ Title = "Keybind", Content = "Đã nhấn phím", Type = "info" })
    end,
})

Main:CreateButton({
    Name = "Thông báo test",
    Callback = function()
        Window:Notify({
            Title = "Xin chào",
            Content = "ThahNamUI đang chạy ổn.",
            Type = "success",
            Duration = 3,
        })
    end,
})

Main:CreateParagraph({
    Title = "Ghi chú",
    Content = "Đây là bản demo để kiểm tra toàn bộ control trong thư viện.",
})

--------------------------------------------------
-- Tab 2: Config
--------------------------------------------------
local ConfigTab = Window:CreateTab("Config", "⚙")

ConfigTab:CreateSection("Lưu / Tải")

ConfigTab:CreateButton({
    Name = "Lưu config",
    Callback = function()
        local ok = Window:SaveConfig("default")
        Window:Notify({
            Title = "SaveConfig",
            Content = ok and "Đã lưu." or "Thất bại (không hỗ trợ file IO).",
            Type = ok and "success" or "error",
        })
    end,
})

ConfigTab:CreateButton({
    Name = "Tải config",
    Callback = function()
        local ok = Window:LoadConfig("default")
        Window:Notify({
            Title = "LoadConfig",
            Content = ok and "Đã tải." or "Không có file config.",
            Type = ok and "success" or "warn",
        })
    end,
})

ConfigTab:CreateSection("Giao diện")

ConfigTab:CreateDropdown({
    Name = "Theme",
    Options = { "Dark", "Rose", "Aqua" },
    CurrentOption = "Dark",
    Callback = function(v)
        Window:SetTheme(v[1])
    end,
})

Window:Notify({
    Title = "ThahNamUI",
    Content = "UI đã load xong.",
    Type = "info",
    Duration = 3,
})
