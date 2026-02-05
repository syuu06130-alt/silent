-- ⚡ Silent Aim - Ultra Advanced Aimbot System
-- 🎯 Features: 360° Detection, 10x Lock Power, Smart Auto TP
-- 🔫 Game: Sniper FPS Arena
-- 📱 PC & Mobile & Console Compatible

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
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")
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
    AutoTP = false,
    WallCheck = true,
    TargetPart = "Head",
    FOV = 360, -- 360° detection for all directions including behind
    CurrentTarget = nil,
    TargetDistance = math.huge,
    Platform = IsMobile and "Mobile" or (IsConsole and "Console" or "PC"),
    LockPower = 10, -- 10x lock power multiplier
    ShotDelay = 0.01,
    TPRange = 50, -- TP distance from target
    LastKillTime = 0,
    CurrentTPTarget = nil,
    TargetLastHealth = nil,
    KillCount = 0
}

local Connections = {}
local ESPObjects = {}
local AllTargets = {} -- Store all potential targets

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

-- Wall Check Function (Ray Casting) - Enhanced
local function WallCheck(origin, target)
    if not States.WallCheck then return true end
    
    SafeCall(function()
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
        raycastParams.IgnoreWater = true
        
        local direction = (target - origin)
        local ray = WS:Raycast(origin, direction, raycastParams)
        
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
    end)
    
    return true
end

-- Get ALL Targets (360° including behind) - Sorted by Distance
local function GetAllTargets()
    AllTargets = {}
    local myPosition = HRP.Position
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            SafeCall(function()
                local character = player.Character
                local humanoid = character:FindFirstChild("Humanoid")
                local targetPart = character:FindFirstChild(States.TargetPart)
                local targetHRP = character:FindFirstChild("HumanoidRootPart")
                
                if humanoid and humanoid.Health > 0 and targetPart and targetHRP then
                    local targetPosition = targetPart.Position
                    local distance = (myPosition - targetHRP.Position).Magnitude
                    
                    -- Wall Check
                    if WallCheck(Camera.CFrame.Position, targetPosition) then
                        table.insert(AllTargets, {
                            Player = player,
                            Character = character,
                            Part = targetPart,
                            HRP = targetHRP,
                            Position = targetPosition,
                            Distance = distance,
                            Humanoid = humanoid,
                            Health = humanoid.Health
                        })
                    end
                end
            end)
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(AllTargets, function(a, b)
        return a.Distance < b.Distance
    end)
    
    return AllTargets
end

-- Get Nearest Target (360° Detection)
local function GetNearestTarget()
    GetAllTargets()
    
    if #AllTargets > 0 then
        States.CurrentTarget = AllTargets[1] -- Closest target
        States.TargetDistance = AllTargets[1].Distance
        return AllTargets[1]
    end
    
    States.CurrentTarget = nil
    States.TargetDistance = math.huge
    return nil
end

-- ESP Creation Function - Enhanced
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

-- Silent Aim Hook - 10x Power
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if States.SilentAim and (method == "FireServer" or method == "InvokeServer") then
        if States.CurrentTarget and States.CurrentTarget.Part then
            -- Predict target position with 10x lock power
            local targetVelocity = States.CurrentTarget.HRP.AssemblyVelocity or Vector3.new(0, 0, 0)
            local predictedPosition = States.CurrentTarget.Position + (targetVelocity * States.LockPower * 0.1)
            
            -- Modify shooting direction to predicted target
            if typeof(args[1]) == "Vector3" then
                args[1] = predictedPosition
            elseif typeof(args[2]) == "Vector3" then
                args[2] = predictedPosition
            end
            
            -- Also modify CFrame if present
            for i, arg in ipairs(args) do
                if typeof(arg) == "CFrame" then
                    args[i] = CFrame.new(arg.Position, predictedPosition)
                end
            end
        end
    end
    
    return oldNamecall(self, unpack(args))
end)

-- Auto Aim Function (Camera Lock) - 10x Power
local function AutoAim()
    if States.AutoAim and States.CurrentTarget and States.CurrentTarget.Part then
        SafeCall(function()
            local targetPos = States.CurrentTarget.Position
            local targetVelocity = States.CurrentTarget.HRP.AssemblyVelocity or Vector3.new(0, 0, 0)
            local predictedPos = targetPos + (targetVelocity * States.LockPower * 0.05)
            
            -- Smooth camera movement with 10x lock strength
            local currentCFrame = Camera.CFrame
            local targetCFrame = CFrame.new(currentCFrame.Position, predictedPos)
            
            -- Lerp with lock power multiplier
            local lerpFactor = 0.1 * States.LockPower
            Camera.CFrame = currentCFrame:Lerp(targetCFrame, math.min(lerpFactor, 1))
        end)
    end
end

-- Head Lock Function (Instant Lock) - 10x Power
local function HeadLock()
    if States.HeadLock and States.CurrentTarget and States.CurrentTarget.Part then
        SafeCall(function()
            local targetPos = States.CurrentTarget.Position
            local targetVelocity = States.CurrentTarget.HRP.AssemblyVelocity or Vector3.new(0, 0, 0)
            local predictedPos = targetPos + (targetVelocity * States.LockPower * 0.1)
            
            -- Instant camera snap with prediction
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, predictedPos)
        end)
    end
end

-- Auto Shot Function - Enhanced
local function AutoShot()
    if not States.AutoShot then return end
    if not States.CurrentTarget then return end
    
    SafeCall(function()
        -- Platform-specific shooting
        if States.Platform == "Mobile" then
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            task.wait(States.ShotDelay)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        elseif States.Platform == "Console" then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.ButtonR1, false, game)
            task.wait(States.ShotDelay)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.ButtonR1, false, game)
        else
            -- PC
            mouse1press()
            task.wait(States.ShotDelay)
            mouse1release()
        end
    end)
end

-- Check if Target is Killed
local function IsTargetKilled(target)
    if not target or not target.Humanoid then return false end
    
    SafeCall(function()
        if target.Humanoid.Health <= 0 then
            return true
        end
        
        -- Check if health decreased significantly
        if States.TargetLastHealth and target.Humanoid.Health < States.TargetLastHealth - 50 then
            States.TargetLastHealth = target.Humanoid.Health
            if target.Humanoid.Health <= 0 then
                return true
            end
        else
            States.TargetLastHealth = target.Humanoid.Health
        end
    end)
    
    return false
end

-- Auto TP Function - Smart Random TP After Kill
local function AutoTP()
    if not States.AutoTP then return end
    
    SafeCall(function()
        -- Get all available targets
        GetAllTargets()
        
        if #AllTargets == 0 then return end
        
        -- If no current TP target, select random one
        if not States.CurrentTPTarget or not States.CurrentTPTarget.Character then
            local randomIndex = math.random(1, #AllTargets)
            States.CurrentTPTarget = AllTargets[randomIndex]
            States.TargetLastHealth = States.CurrentTPTarget.Humanoid.Health
        end
        
        -- Check if current target is killed
        if States.CurrentTPTarget then
            local targetHumanoid = States.CurrentTPTarget.Character and States.CurrentTPTarget.Character:FindFirstChild("Humanoid")
            
            if not targetHumanoid or targetHumanoid.Health <= 0 then
                -- Target killed! Increment kill count
                States.KillCount = States.KillCount + 1
                States.LastKillTime = tick()
                
                -- Select new random target
                task.wait(0.5) -- Small delay before TP
                GetAllTargets()
                
                if #AllTargets > 0 then
                    local randomIndex = math.random(1, #AllTargets)
                    States.CurrentTPTarget = AllTargets[randomIndex]
                    States.TargetLastHealth = States.CurrentTPTarget.Humanoid.Health
                    
                    -- TP to new target
                    if States.CurrentTPTarget and States.CurrentTPTarget.HRP and HRP then
                        local targetPos = States.CurrentTPTarget.HRP.Position
                        local offset = Vector3.new(
                            math.random(-States.TPRange, States.TPRange),
                            5,
                            math.random(-States.TPRange, States.TPRange)
                        )
                        HRP.CFrame = CFrame.new(targetPos + offset)
                        
                        Rayfield:Notify({
                            Title = "🎯 Kill Confirmed!",
                            Content = "Kills: " .. States.KillCount .. " | TP to next target!",
                            Duration = 2,
                            Image = 4483362458
                        })
                    end
                end
            else
                -- Keep tracking current target's health
                States.TargetLastHealth = targetHumanoid.Health
            end
        end
    end)
end

-- Main Window Creation
local Window = Rayfield:CreateWindow({
    Name = "⚡ Silent Aim Ultra | 360° + 10x Lock " .. (States.Platform == "Mobile" and "📱" or States.Platform == "Console" and "🎮" or "💻"),
    LoadingTitle = "Loading Ultra Silent Aim...",
    LoadingSubtitle = "360° Detection + 10x Lock Power | Platform: " .. States.Platform,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SilentAimUltra",
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
local AimbotSection = MainTab:CreateSection("Core Aimbot Features (Auto-Enabled)")

-- Silent Aim Toggle (Auto-enabled)
local SilentAimToggle = MainTab:CreateToggle({
    Name = "Silent Aim (10x Power)",
    CurrentValue = true,
    Flag = "SilentAim",
    Callback = function(Value)
        States.SilentAim = Value
        Rayfield:Notify({
            Title = "Silent Aim",
            Content = Value and "✅ Enabled (10x Power)" or "❌ Disabled",
            Duration = 2,
            Image = 4483362458
        })
    end,
})

-- Head Lock Toggle (Auto-enabled)
local HeadLockToggle = MainTab:CreateToggle({
    Name = "Head Lock (10x Instant Lock)",
    CurrentValue = true,
    Flag = "HeadLock",
    Callback = function(Value)
        States.HeadLock = Value
        Rayfield:Notify({
            Title = "Head Lock",
            Content = Value and "✅ Enabled (10x Instant)" or "❌ Disabled",
            Duration = 2,
            Image = 4483362458
        })
    end,
})

-- Auto Aim Toggle (Auto-enabled)
local AutoAimToggle = MainTab:CreateToggle({
    Name = "Auto Aim (10x Smooth Lock)",
    CurrentValue = true,
    Flag = "AutoAim",
    Callback = function(Value)
        States.AutoAim = Value
        Rayfield:Notify({
            Title = "Auto Aim",
            Content = Value and "✅ Enabled (10x Smooth)" or "❌ Disabled",
            Duration = 2,
            Image = 4483362458
        })
    end,
})

-- Lock Power Slider (NEW!)
local LockPowerSlider = MainTab:CreateSlider({
    Name = "Lock Power Multiplier",
    Range = {1, 20},
    Increment = 1,
    Suffix = "x",
    CurrentValue = 10,
    Flag = "LockPower",
    Callback = function(Value)
        States.LockPower = Value
        Rayfield:Notify({
            Title = "Lock Power",
            Content = "Set to " .. Value .. "x",
            Duration = 1,
            Image = 4483362458
        })
    end,
})

local AimbotSection2 = MainTab:CreateSection("Advanced Settings")

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
    Options = {"Head", "UpperTorso", "HumanoidRootPart", "LowerTorso"},
    CurrentOption = "Head",
    Flag = "TargetPart",
    Callback = function(Option)
        States.TargetPart = Option
    end,
})

-- Detection Info
local DetectionLabel = MainTab:CreateLabel("Detection: 360° (Front + Back + Sides)")
local TargetingLabel = MainTab:CreateLabel("Targeting: Closest Enemy First")

-- ========================================
-- 👁️ ESP TAB (Auto-enabled)
-- ========================================
local ESPTab = Window:CreateTab("👁️ ESP", 4483362458)
local ESPSection = ESPTab:CreateSection("ESP Features (Auto-Enabled)")

-- ESP Toggle (Auto-enabled)
local ESPToggle = ESPTab:CreateToggle({
    Name = "ESP (Player Highlight)",
    CurrentValue = true,
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
local ESPInfoLabel3 = ESPTab:CreateLabel("Green Outline = Can See")
local ESPInfoLabel4 = ESPTab:CreateLabel("Yellow Outline = Behind Wall")

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
                Content = "✅ Enabled - Shooting when locked",
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
-- 🌀 AUTO TP TAB (NEW!)
-- ========================================
local AutoTPTab = Window:CreateTab("🌀 Auto TP", 4483362458)
local AutoTPSection = AutoTPTab:CreateSection("Smart Random Teleport")

-- Auto TP Toggle
local AutoTPToggle = AutoTPTab:CreateToggle({
    Name = "Auto TP (After Kill)",
    CurrentValue = false,
    Flag = "AutoTP",
    Callback = function(Value)
        States.AutoTP = Value
        
        if Value then
            States.KillCount = 0
            States.CurrentTPTarget = nil
            
            Rayfield:Notify({
                Title = "Auto TP",
                Content = "✅ Enabled - Will TP after each kill!",
                Duration = 3,
                Image = 4483362458
            })
        else
            States.CurrentTPTarget = nil
            
            Rayfield:Notify({
                Title = "Auto TP",
                Content = "❌ Disabled",
                Duration = 2,
                Image = 4483362458
            })
        end
    end,
})

-- TP Range Slider
local TPRangeSlider = AutoTPTab:CreateSlider({
    Name = "TP Distance from Target",
    Range = {10, 100},
    Increment = 5,
    Suffix = "studs",
    CurrentValue = 50,
    Flag = "TPRange",
    Callback = function(Value)
        States.TPRange = Value
    end,
})

local AutoTPSection2 = AutoTPTab:CreateSection("How It Works")
local TPInfoLabel1 = AutoTPTab:CreateLabel("1. Randomly selects an enemy")
local TPInfoLabel2 = AutoTPTab:CreateLabel("2. Locks onto them with aimbot")
local TPInfoLabel3 = AutoTPTab:CreateLabel("3. When killed, TPs to next random enemy")
local TPInfoLabel4 = AutoTPTab:CreateLabel("4. Loop continues infinitely")

local KillCountLabel = AutoTPTab:CreateLabel("Kills This Session: 0")

-- ========================================
-- ⚙️ SETTINGS TAB
-- ========================================
local SettingsTab = Window:CreateTab("⚙️ Settings", 4483362458)
local SettingsSection = SettingsTab:CreateSection("Script Information")

local InfoLabel1 = SettingsTab:CreateLabel("Silent Aim Status: Active")
local InfoLabel2 = SettingsTab:CreateLabel("Platform: " .. States.Platform)
local InfoLabel3 = SettingsTab:CreateLabel("Current Target: None")
local InfoLabel4 = SettingsTab:CreateLabel("Target Distance: ∞")
local InfoLabel5 = SettingsTab:CreateLabel("Lock Power: 10x")
local InfoLabel6 = SettingsTab:CreateLabel("Detection: 360°")

-- Update Info Labels
Connections["InfoUpdate"] = RS.Heartbeat:Connect(function()
    SafeCall(function()
        InfoLabel3:Set("Current Target: " .. (States.CurrentTarget and States.CurrentTarget.Player.Name or "None"))
        InfoLabel4:Set("Target Distance: " .. (States.CurrentTarget and math.floor(States.TargetDistance) .. " studs" or "∞"))
        InfoLabel5:Set("Lock Power: " .. States.LockPower .. "x")
        KillCountLabel:Set("Kills This Session: " .. States.KillCount)
    end)
end)

local SettingsSection2 = SettingsTab:CreateSection("Script Controls")

local UnloadButton = SettingsTab:CreateButton({
    Name = "🔌 Unload Script",
    Callback = function()
        CleanupAll()
        Rayfield:Destroy()
        SafeCall(function() script:Destroy() end)
    end,
})

-- ========================================
-- MAIN AIMBOT LOOP (360° Detection)
-- ========================================
Connections["MainAimbot"] = RS.Heartbeat:Connect(function()
    -- Get nearest target (360° including behind)
    GetNearestTarget()
    
    -- Apply Head Lock (10x power)
    if States.HeadLock then
        HeadLock()
    end
    
    -- Apply Auto Aim (10x power)
    if States.AutoAim then
        AutoAim()
    end
    
    -- Auto TP Logic
    if States.AutoTP then
        AutoTP()
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

-- Character Re-added Handler
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    HRP = newChar:WaitForChild("HumanoidRootPart")
    Humanoid = newChar:WaitForChild("Humanoid")
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
    Title = "⚡ Silent Aim Ultra Loaded",
    Content = "✅ All features auto-enabled!\n🎯 Silent Aim: ON (10x)\n🔒 Head Lock: ON (10x)\n🎯 Auto Aim: ON (10x)\n👁️ ESP: ON\n🌐 Detection: 360°\nPlatform: " .. States.Platform,
    Duration = 10,
    Image = 4483362458
})

print("✅ Silent Aim Ultra - Advanced Aimbot System Loaded")
print("🎯 Features: 360° Detection, 10x Lock Power, Smart Auto TP")
print("📱 Platform: " .. States.Platform)
print("🔫 Ready to dominate!")
