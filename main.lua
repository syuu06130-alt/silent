-- ⚡ Silent Aim - Advanced Aimbot System
-- 🎯 Features: Silent Aim, Head Lock, Auto Aim, ESP, Auto Shot
-- 🔫 Game: Sniper FPS Arena
-- 📱 PC & Mobile Compatible

-- UI Framework Loading
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local WS = game:GetService("Workspace")
local Camera = WS.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Player Variables
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Platform Detection
local IsMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
local IsPC = UIS.KeyboardEnabled
local IsConsole = UIS.GamepadEnabled and not UIS.KeyboardEnabled

-- Global States
local States = {
    SilentAim = false,
    HeadLock = false,
    AutoAim = false,
    ESP = false,
    AutoShot = false,
    WallCheck = true,
    TargetPart = "Head",
    FOV = 200,
    CurrentTarget = nil,
    TargetDistance = math.huge,
    Platform = IsMobile and "Mobile" or (IsConsole and "Console" or "PC")
}

local Connections = {}
local ESPObjects = {}

-- Safe Call Function
local function SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        warn("[Silent Aim] Error: " .. tostring(result))
    end
    return success, result
end

-- Cleanup Function
local function CleanupAll()
    for name, connection in pairs(Connections) do
        SafeCall(function() connection:Disconnect() end)
    end
    Connections = {}
    
    for _, esp in pairs(ESPObjects) do
        SafeCall(function() esp:Destroy() end)
    end
    ESPObjects = {}
end

-- Wall Check Function (Ray Casting)
local function WallCheck(origin, target)
    if not States.WallCheck then return true end
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.IgnoreWater = true
    
    local ray = WS:Raycast(origin, (target - origin), raycastParams)
    
    if ray then
        local hitPart = ray.Instance
        if hitPart then
            -- Check if hit player's character
            local character = hitPart:FindFirstAncestorOfClass("Model")
            if character and character:FindFirstChild("Humanoid") then
                return true
            end
            return false
        end
    end
    
    return true
end

-- Get Nearest Target Function
local function GetNearestTarget()
    local nearestTarget = nil
    local nearestDistance = math.huge
    local cameraPosition = Camera.CFrame.Position
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            SafeCall(function()
                local character = player.Character
                local humanoid = character:FindFirstChild("Humanoid")
                local targetPart = character:FindFirstChild(States.TargetPart)
                
                if humanoid and humanoid.Health > 0 and targetPart then
                    local targetPosition = targetPart.Position
                    local distance = (cameraPosition - targetPosition).Magnitude
                    
                    -- FOV Check
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPosition)
                    if onScreen then
                        local mousePos = Vector2.new(Mouse.X, Mouse.Y)
                        local targetPos2D = Vector2.new(screenPos.X, screenPos.Y)
                        local distanceFromCenter = (mousePos - targetPos2D).Magnitude
                        
                        if distanceFromCenter <= States.FOV then
                            -- Wall Check
                            if WallCheck(cameraPosition, targetPosition) then
                                if distance < nearestDistance then
                                    nearestDistance = distance
                                    nearestTarget = {
                                        Player = player,
                                        Character = character,
                                        Part = targetPart,
                                        Position = targetPosition,
                                        Distance = distance
                                    }
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
    
    States.CurrentTarget = nearestTarget
    States.TargetDistance = nearestDistance
    
    return nearestTarget
end

-- ESP Creation Function
local function CreateESP(player)
    if ESPObjects[player] then return end
    
    SafeCall(function()
        if player.Character then
            local highlight = Instance.new("Highlight")
            highlight.Name = player.Name .. "_ESP"
            highlight.Parent = player.Character
            highlight.Adornee = player.Character
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            
            -- Red fill, Yellow outline
            highlight.FillColor = Color3.fromRGB(255, 0, 0)
            highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            
            ESPObjects[player] = highlight
            
            -- Update ESP based on wall check
            local updateConnection = RS.Heartbeat:Connect(function()
                if highlight and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local canSee = WallCheck(Camera.CFrame.Position, player.Character.HumanoidRootPart.Position)
                    if canSee then
                        highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Red when visible
                        highlight.OutlineColor = Color3.fromRGB(0, 255, 0) -- Green outline
                    else
                        highlight.FillColor = Color3.fromRGB(255, 100, 0) -- Orange when behind wall
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 0) -- Yellow outline
                    end
                else
                    updateConnection:Disconnect()
                end
            end)
        end
    end)
end

-- Remove ESP Function
local function RemoveESP(player)
    if ESPObjects[player] then
        SafeCall(function()
            ESPObjects[player]:Destroy()
            ESPObjects[player] = nil
        end)
    end
end

-- Update All ESP
local function UpdateESP()
    if States.ESP then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                CreateESP(player)
            end
        end
    else
        for player, highlight in pairs(ESPObjects) do
            SafeCall(function() highlight:Destroy() end)
        end
        ESPObjects = {}
    end
end

-- Silent Aim Hook
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if States.SilentAim and (method == "FireServer" or method == "InvokeServer") then
        if States.CurrentTarget and States.CurrentTarget.Part then
            -- Modify shooting direction to target
            if typeof(args[1]) == "Vector3" then
                args[1] = States.CurrentTarget.Position
            elseif typeof(args[2]) == "Vector3" then
                args[2] = States.CurrentTarget.Position
            end
        end
    end
    
    return oldNamecall(self, unpack(args))
end)

-- Auto Aim Function (Camera Lock)
local function AutoAim()
    if States.AutoAim and States.CurrentTarget and States.CurrentTarget.Part then
        SafeCall(function()
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, States.CurrentTarget.Position)
        end)
    end
end

-- Head Lock Function (Stronger Camera Lock)
local function HeadLock()
    if States.HeadLock and States.CurrentTarget and States.CurrentTarget.Part then
        SafeCall(function()
            local targetPos = States.CurrentTarget.Position
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
        end)
    end
end

-- Auto Shot Function
local function AutoShot()
    if not States.AutoShot then return end
    if not States.CurrentTarget then return end
    
    SafeCall(function()
        if States.Platform == "Mobile" then
            -- Mobile: Simulate touch on fire button
            -- Note: You may need to adjust coordinates based on your mobile UI
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        elseif States.Platform == "Console" then
            -- Console: Simulate R1 button
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.ButtonR1, false, game)
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.ButtonR1, false, game)
        else
            -- PC: Simulate Mouse1 click
            mouse1press()
            task.wait(0.01)
            mouse1release()
        end
    end)
end

-- Main Window Creation
local Window = Rayfield:CreateWindow({
    Name = "⚡ Silent Aim | Advanced Aimbot " .. (States.Platform == "Mobile" and "📱" or States.Platform == "Console" and "🎮" or "💻"),
    LoadingTitle = "Loading Silent Aim...",
    LoadingSubtitle = "Platform: " .. States.Platform,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SilentAim",
        FileName = "Settings"
    },
    Discord = {
        Enabled = false,
    },
    KeySystem = false,
})

-- ========================================
-- 🎯 MAIN AIMBOT TAB
-- ========================================
local MainTab = Window:CreateTab("🎯 Aimbot", 4483362458)
local AimbotSection = MainTab:CreateSection("Core Aimbot Features")

-- Silent Aim Toggle (Auto-enabled)
local SilentAimToggle = MainTab:CreateToggle({
    Name = "Silent Aim",
    CurrentValue = true, -- Auto-enabled
    Flag = "SilentAim",
    Callback = function(Value)
        States.SilentAim = Value
        Rayfield:Notify({
            Title = "Silent Aim",
            Content = Value and "✅ Enabled" or "❌ Disabled",
            Duration = 2,
            Image = 4483362458
        })
    end,
})

-- Head Lock Toggle (Auto-enabled)
local HeadLockToggle = MainTab:CreateToggle({
    Name = "Head Lock (Camera Lock)",
    CurrentValue = true, -- Auto-enabled
    Flag = "HeadLock",
    Callback = function(Value)
        States.HeadLock = Value
        Rayfield:Notify({
            Title = "Head Lock",
            Content = Value and "✅ Enabled" or "❌ Disabled",
            Duration = 2,
            Image = 4483362458
        })
    end,
})

-- Auto Aim Toggle (Auto-enabled)
local AutoAimToggle = MainTab:CreateToggle({
    Name = "Auto Aim (Smooth Lock)",
    CurrentValue = true, -- Auto-enabled
    Flag = "AutoAim",
    Callback = function(Value)
        States.AutoAim = Value
        Rayfield:Notify({
            Title = "Auto Aim",
            Content = Value and "✅ Enabled" or "❌ Disabled",
            Duration = 2,
            Image = 4483362458
        })
    end,
})

-- Wall Check Toggle
local WallCheckToggle = MainTab:CreateToggle({
    Name = "Wall Check (Visible Only)",
    CurrentValue = true,
    Flag = "WallCheck",
    Callback = function(Value)
        States.WallCheck = Value
    end,
})

-- Target Part Selection
local TargetPartDropdown = MainTab:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "UpperTorso", "HumanoidRootPart"},
    CurrentOption = "Head",
    Flag = "TargetPart",
    Callback = function(Option)
        States.TargetPart = Option
    end,
})

-- FOV Slider
local FOVSlider = MainTab:CreateSlider({
    Name = "FOV Size",
    Range = {50, 500},
    Increment = 10,
    Suffix = "px",
    CurrentValue = 200,
    Flag = "FOV",
    Callback = function(Value)
        States.FOV = Value
    end,
})

-- ========================================
-- 👁️ ESP TAB (Auto-enabled)
-- ========================================
local ESPTab = Window:CreateTab("👁️ ESP", 4483362458)
local ESPSection = ESPTab:CreateSection("ESP Features")

-- ESP Toggle (Auto-enabled)
local ESPToggle = ESPTab:CreateToggle({
    Name = "ESP (Player Highlight)",
    CurrentValue = true, -- Auto-enabled
    Flag = "ESP",
    Callback = function(Value)
        States.ESP = Value
        UpdateESP()
        Rayfield:Notify({
            Title = "ESP",
            Content = Value and "✅ Enabled (Red=Visible, Orange=Wall)" or "❌ Disabled",
            Duration = 3,
            Image = 4483362458
        })
    end,
})

local ESPInfoLabel = ESPTab:CreateLabel("Red Fill = Enemy Visible")
local ESPInfoLabel2 = ESPTab:CreateLabel("Orange Fill = Enemy Behind Wall")
local ESPInfoLabel3 = ESPTab:CreateLabel("Yellow Outline = Always Visible")

-- ========================================
-- 🔫 AUTO SHOT TAB
-- ========================================
local AutoShotTab = Window:CreateTab("🔫 Auto Shot", 4483362458)
local AutoShotSection = AutoShotTab:CreateSection("Automatic Shooting")

-- Auto Shot Toggle
local AutoShotToggle = AutoShotTab:CreateToggle({
    Name = "Auto Shot (When Locked)",
    CurrentValue = false,
    Flag = "AutoShot",
    Callback = function(Value)
        States.AutoShot = Value
        
        if Value then
            Connections["AutoShot"] = RS.Heartbeat:Connect(function()
                if States.AutoShot and States.CurrentTarget then
                    AutoShot()
                end
            end)
            
            Rayfield:Notify({
                Title = "Auto Shot",
                Content = "✅ Enabled - Will shoot when target locked",
                Duration = 3,
                Image = 4483362458
            })
        else
            if Connections["AutoShot"] then
                Connections["AutoShot"]:Disconnect()
                Connections["AutoShot"] = nil
            end
            
            Rayfield:Notify({
                Title = "Auto Shot",
                Content = "❌ Disabled",
                Duration = 2,
                Image = 4483362458
            })
        end
    end,
})

-- Shot Delay Slider
local ShotDelaySlider = AutoShotTab:CreateSlider({
    Name = "Shot Delay",
    Range = {0.01, 1},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = 0.01,
    Flag = "ShotDelay",
    Callback = function(Value)
        States.ShotDelay = Value
    end,
})

local AutoShotInfoLabel = AutoShotTab:CreateLabel("Platform: " .. States.Platform)
if States.Platform == "Mobile" then
    AutoShotTab:CreateLabel("Fire Button: Touch Screen")
elseif States.Platform == "Console" then
    AutoShotTab:CreateLabel("Fire Button: R1")
else
    AutoShotTab:CreateLabel("Fire Button: Mouse 1")
end

-- ========================================
-- ⚙️ SETTINGS TAB
-- ========================================
local SettingsTab = Window:CreateTab("⚙️ Settings", 4483362458)
local SettingsSection = SettingsTab:CreateSection("Script Settings")

local InfoLabel1 = SettingsTab:CreateLabel("Silent Aim Status: Active")
local InfoLabel2 = SettingsTab:CreateLabel("Platform: " .. States.Platform)
local InfoLabel3 = SettingsTab:CreateLabel("Current Target: None")

-- Update Info Labels
Connections["InfoUpdate"] = RS.Heartbeat:Connect(function()
    SafeCall(function()
        InfoLabel3:Set("Current Target: " .. (States.CurrentTarget and States.CurrentTarget.Player.Name or "None"))
    end)
end)

local UnloadButton = SettingsTab:CreateButton({
    Name = "🔌 Unload Script",
    Callback = function()
        CleanupAll()
        Rayfield:Destroy()
        SafeCall(function() script:Destroy() end)
    end,
})

-- ========================================
-- MAIN AIMBOT LOOP
-- ========================================
Connections["MainAimbot"] = RS.Heartbeat:Connect(function()
    -- Get nearest target every frame
    GetNearestTarget()
    
    -- Apply Head Lock
    if States.HeadLock then
        HeadLock()
    end
    
    -- Apply Auto Aim
    if States.AutoAim then
        AutoAim()
    end
end)

-- ========================================
-- ESP UPDATE LOOP
-- ========================================
Connections["ESPUpdate"] = RS.Heartbeat:Connect(function()
    if States.ESP then
        UpdateESP()
    end
end)

-- Player Added/Removed Handlers
Players.PlayerAdded:Connect(function(player)
    if States.ESP then
        player.CharacterAdded:Connect(function()
            task.wait(0.5)
            CreateESP(player)
        end)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
end)

-- ========================================
-- AUTO-ENABLE FEATURES ON LOAD
-- ========================================
task.wait(0.5)

-- Auto-enable all main features
States.SilentAim = true
States.HeadLock = true
States.AutoAim = true
States.ESP = true

-- Update ESP immediately
UpdateESP()

-- ========================================
-- INITIAL NOTIFICATION
-- ========================================
Rayfield:Notify({
    Title = "⚡ Silent Aim Loaded",
    Content = "✅ All features auto-enabled!\n🎯 Silent Aim: ON\n🔒 Head Lock: ON\n🎯 Auto Aim: ON\n👁️ ESP: ON\nPlatform: " .. States.Platform,
    Duration = 8,
    Image = 4483362458
})

print("✅ Silent Aim - Advanced Aimbot System Loaded")
print("🎯 Features: Silent Aim, Head Lock, Auto Aim, ESP, Auto Shot")
print("📱 Platform: " .. States.Platform)
print("🔫 Ready to dominate!")
