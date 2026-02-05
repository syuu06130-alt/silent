-- ⚡ Silent Aim - Advanced Aimbot System V2
-- 🎯 Features: 360° Silent Aim, Head Lock, Auto Aim, ESP, Auto Shot, Auto TP
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
local TweenService = game:GetService("TweenService")

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
    WallCheck = false, -- 360度対応のため無効化
    TargetPart = "Head",
    FOV = 360, -- 360度に変更
    CurrentTarget = nil,
    TargetDistance = math.huge,
    Platform = IsMobile and "Mobile" or (IsConsole and "Console" or "PC"),
    
    -- Performance Settings
    SilentAimStrength = 100,
    HeadLockStrength = 100,
    AutoAimStrength = 100,
    
    -- Auto TP Settings
    AutoTP = false,
    TPDistance = 10, -- 0-25 studs
    TPMode = "Random", -- "Random" or "Fixed"
    FixedDistance = 3, -- For Fixed mode
    CurrentTPTarget = nil,
    LastKilledTarget = nil,
    
    -- All Players Fixed Mode
    AllPlayersFixed = false,
    FixedDistanceAll = 3,
}

local Connections = {}
local ESPObjects = {}
local TPTargets = {} -- Track TP targets

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
    
    TPTargets = {}
end

-- Wall Check Function (Optional - 360度では不要)
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
            local character = hitPart:FindFirstAncestorOfClass("Model")
            if character and character:FindFirstChild("Humanoid") then
                return true
            end
            return false
        end
    end
    
    return true
end

-- Get All Valid Targets (360度、近い順)
local function GetAllTargets()
    local targets = {}
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
                    
                    table.insert(targets, {
                        Player = player,
                        Character = character,
                        Part = targetPart,
                        Position = targetPosition,
                        Distance = distance,
                        Humanoid = humanoid
                    })
                end
            end)
        end
    end
    
    -- Sort by distance (近い順)
    table.sort(targets, function(a, b)
        return a.Distance < b.Distance
    end)
    
    return targets
end

-- Get Nearest Target Function (360度対応)
local function GetNearestTarget()
    local targets = GetAllTargets()
    
    if #targets > 0 then
        States.CurrentTarget = targets[1]
        States.TargetDistance = targets[1].Distance
        return targets[1]
    end
    
    States.CurrentTarget = nil
    States.TargetDistance = math.huge
    return nil
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
            
            highlight.FillColor = Color3.fromRGB(255, 0, 0)
            highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            
            ESPObjects[player] = highlight
            
            local updateConnection = RS.Heartbeat:Connect(function()
                if highlight and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local canSee = WallCheck(Camera.CFrame.Position, player.Character.HumanoidRootPart.Position)
                    if canSee then
                        highlight.FillColor = Color3.fromRGB(255, 0, 0)
                        highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
                    else
                        highlight.FillColor = Color3.fromRGB(255, 100, 0)
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
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

-- Silent Aim Hook (性能調節付き)
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if States.SilentAim and (method == "FireServer" or method == "InvokeServer") then
        if States.CurrentTarget and States.CurrentTarget.Part then
            local strength = States.SilentAimStrength / 100
            local currentPos = args[1]
            local targetPos = States.CurrentTarget.Position
            
            -- Lerp between current and target based on strength
            if typeof(currentPos) == "Vector3" then
                args[1] = currentPos:Lerp(targetPos, strength)
            elseif typeof(args[2]) == "Vector3" then
                args[2] = args[2]:Lerp(targetPos, strength)
            end
        end
    end
    
    return oldNamecall(self, unpack(args))
end)

-- Auto Aim Function (性能調節付き)
local function AutoAim()
    if States.AutoAim and States.CurrentTarget and States.CurrentTarget.Part then
        SafeCall(function()
            local strength = States.AutoAimStrength / 100
            local targetPos = States.CurrentTarget.Position
            local currentCFrame = Camera.CFrame
            local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)
            
            -- Lerp camera rotation
            Camera.CFrame = currentCFrame:Lerp(targetCFrame, strength * 0.3)
        end)
    end
end

-- Head Lock Function (性能調節付き)
local function HeadLock()
    if States.HeadLock and States.CurrentTarget and States.CurrentTarget.Part then
        SafeCall(function()
            local strength = States.HeadLockStrength / 100
            local targetPos = States.CurrentTarget.Position
            local currentCFrame = Camera.CFrame
            local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)
            
            -- Instant lock at full strength, lerp at lower strength
            if strength >= 0.9 then
                Camera.CFrame = targetCFrame
            else
                Camera.CFrame = currentCFrame:Lerp(targetCFrame, strength)
            end
        end)
    end
end

-- Auto Shot Function
local function AutoShot()
    if not States.AutoShot then return end
    if not States.CurrentTarget then return end
    
    SafeCall(function()
        if States.Platform == "Mobile" then
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        elseif States.Platform == "Console" then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.ButtonR1, false, game)
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.ButtonR1, false, game)
        else
            mouse1press()
            task.wait(0.01)
            mouse1release()
        end
    end)
end

-- ========================================
-- AUTO TP FUNCTIONS
-- ========================================

-- Get Random Enemy
local function GetRandomEnemy()
    local targets = GetAllTargets()
    if #targets > 0 then
        return targets[math.random(1, #targets)]
    end
    return nil
end

-- Teleport to Target with Distance
local function TPToTarget(target, distance)
    if not target or not target.Character then return end
    
    SafeCall(function()
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        
        local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return end
        
        local targetPos = targetRoot.Position
        local direction = (character.HumanoidRootPart.Position - targetPos).Unit
        local tpPosition = targetPos + (direction * distance)
        
        character.HumanoidRootPart.CFrame = CFrame.new(tpPosition, targetPos)
    end)
end

-- Check if target is killed
local function IsTargetKilled(target)
    if not target or not target.Character then return true end
    local humanoid = target.Character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return true end
    return false
end

-- Auto TP Random Mode (敵を倒したら次へ)
local function AutoTPRandom()
    if not States.AutoTP or States.TPMode ~= "Random" then return end
    
    -- If no current target or target is dead, get new one
    if not States.CurrentTPTarget or IsTargetKilled(States.CurrentTPTarget) then
        States.CurrentTPTarget = GetRandomEnemy()
        
        if States.CurrentTPTarget then
            Rayfield:Notify({
                Title = "🎯 New TP Target",
                Content = "Locked on: " .. States.CurrentTPTarget.Player.Name,
                Duration = 2,
                Image = 4483362458
            })
        end
    end
    
    -- TP to current target with fixed distance
    if States.CurrentTPTarget then
        TPToTarget(States.CurrentTPTarget, States.TPDistance)
    end
end

-- All Players Fixed Mode (全員を3スタッド前に固定)
local function AllPlayersFixed()
    if not States.AllPlayersFixed then return end
    
    SafeCall(function()
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        
        local rootPart = character.HumanoidRootPart
        local forwardDirection = rootPart.CFrame.LookVector
        local fixedPosition = rootPart.Position + (forwardDirection * States.FixedDistanceAll)
        
        -- Move all enemies to fixed position
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local enemyRoot = player.Character:FindFirstChild("HumanoidRootPart")
                local enemyHumanoid = player.Character:FindFirstChild("Humanoid")
                
                if enemyRoot and enemyHumanoid and enemyHumanoid.Health > 0 then
                    enemyRoot.CFrame = CFrame.new(fixedPosition, rootPart.Position)
                    enemyRoot.Velocity = Vector3.new(0, 0, 0)
                    enemyRoot.RotVelocity = Vector3.new(0, 0, 0)
                end
            end
        end
    end)
end

-- ========================================
-- UI CREATION
-- ========================================

local Window = Rayfield:CreateWindow({
    Name = "⚡ Silent Aim V2 | 360° Aimbot " .. (States.Platform == "Mobile" and "📱" or States.Platform == "Console" and "🎮" or "💻"),
    LoadingTitle = "Loading Silent Aim V2...",
    LoadingSubtitle = "Platform: " .. States.Platform,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SilentAimV2",
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
local AimbotSection = MainTab:CreateSection("Core Aimbot Features (360°)")

-- Silent Aim Toggle
local SilentAimToggle = MainTab:CreateToggle({
    Name = "Silent Aim",
    CurrentValue = true,
    Flag = "SilentAim",
    Callback = function(Value)
        States.SilentAim = Value
        Rayfield:Notify({
            Title = "Silent Aim",
            Content = Value and "✅ Enabled (360°)" or "❌ Disabled",
            Duration = 2,
            Image = 4483362458
        })
    end,
})

-- Silent Aim Strength
local SilentAimStrength = MainTab:CreateSlider({
    Name = "Silent Aim Strength",
    Range = {10, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = 100,
    Flag = "SilentAimStrength",
    Callback = function(Value)
        States.SilentAimStrength = Value
    end,
})

-- Head Lock Toggle
local HeadLockToggle = MainTab:CreateToggle({
    Name = "Head Lock (Camera Lock)",
    CurrentValue = true,
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

-- Head Lock Strength
local HeadLockStrength = MainTab:CreateSlider({
    Name = "Head Lock Strength",
    Range = {10, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = 100,
    Flag = "HeadLockStrength",
    Callback = function(Value)
        States.HeadLockStrength = Value
    end,
})

-- Auto Aim Toggle
local AutoAimToggle = MainTab:CreateToggle({
    Name = "Auto Aim (Smooth Lock)",
    CurrentValue = true,
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

-- Auto Aim Strength
local AutoAimStrength = MainTab:CreateSlider({
    Name = "Auto Aim Strength",
    Range = {10, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = 100,
    Flag = "AutoAimStrength",
    Callback = function(Value)
        States.AutoAimStrength = Value
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

-- ========================================
-- 👁️ ESP TAB
-- ========================================
local ESPTab = Window:CreateTab("👁️ ESP", 4483362458)
local ESPSection = ESPTab:CreateSection("ESP Features")

local ESPToggle = ESPTab:CreateToggle({
    Name = "ESP (Player Highlight)",
    CurrentValue = true,
    Flag = "ESP",
    Callback = function(Value)
        States.ESP = Value
        UpdateESP()
        Rayfield:Notify({
            Title = "ESP",
            Content = Value and "✅ Enabled" or "❌ Disabled",
            Duration = 3,
            Image = 4483362458
        })
    end,
})

-- ========================================
-- 🔫 AUTO SHOT TAB
-- ========================================
local AutoShotTab = Window:CreateTab("🔫 Auto Shot", 4483362458)
local AutoShotSection = AutoShotTab:CreateSection("Automatic Shooting")

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
                Content = "✅ Enabled",
                Duration = 3,
                Image = 4483362458
            })
        else
            if Connections["AutoShot"] then
                Connections["AutoShot"]:Disconnect()
                Connections["AutoShot"] = nil
            end
        end
    end,
})

-- ========================================
-- 🌀 AUTO TP TAB
-- ========================================
local AutoTPTab = Window:CreateTab("🌀 Auto TP", 4483362458)
local TPSection = AutoTPTab:CreateSection("Auto Teleport Features")

-- Auto TP Random Mode
local AutoTPToggle = AutoTPTab:CreateToggle({
    Name = "Auto TP (Random + Kill Loop)",
    CurrentValue = false,
    Flag = "AutoTP",
    Callback = function(Value)
        States.AutoTP = Value
        States.TPMode = "Random"
        
        if Value then
            States.CurrentTPTarget = GetRandomEnemy()
            
            Connections["AutoTPRandom"] = RS.Heartbeat:Connect(function()
                AutoTPRandom()
            end)
            
            Rayfield:Notify({
                Title = "Auto TP Random",
                Content = "✅ TP to random enemy, new target after kill",
                Duration = 4,
                Image = 4483362458
            })
        else
            if Connections["AutoTPRandom"] then
                Connections["AutoTPRandom"]:Disconnect()
                Connections["AutoTPRandom"] = nil
            end
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

-- TP Distance Slider (0-25 studs)
local TPDistanceSlider = AutoTPTab:CreateSlider({
    Name = "TP Distance (Studs)",
    Range = {0, 25},
    Increment = 0.5,
    Suffix = " studs",
    CurrentValue = 10,
    Flag = "TPDistance",
    Callback = function(Value)
        States.TPDistance = Value
    end,
})

local TPInfoLabel = AutoTPTab:CreateLabel("TP follows enemy movement")
local TPInfoLabel2 = AutoTPTab:CreateLabel("Auto switches to new enemy after kill")

-- ========================================
-- 🎭 ALL PLAYERS FIXED TAB
-- ========================================
local FixedTab = Window:CreateTab("🎭 Fixed Mode", 4483362458)
local FixedSection = FixedTab:CreateSection("All Players Fixed Position")

-- All Players Fixed Toggle
local AllFixedToggle = FixedTab:CreateToggle({
    Name = "Fix All Players In Front",
    CurrentValue = false,
    Flag = "AllPlayersFixed",
    Callback = function(Value)
        States.AllPlayersFixed = Value
        
        if Value then
            Connections["AllPlayersFixed"] = RS.Heartbeat:Connect(function()
                AllPlayersFixed()
            end)
            
            Rayfield:Notify({
                Title = "Fixed Mode",
                Content = "✅ All enemies fixed " .. States.FixedDistanceAll .. " studs in front",
                Duration = 4,
                Image = 4483362458
            })
        else
            if Connections["AllPlayersFixed"] then
                Connections["AllPlayersFixed"]:Disconnect()
                Connections["AllPlayersFixed"] = nil
            end
            
            Rayfield:Notify({
                Title = "Fixed Mode",
                Content = "❌ Disabled",
                Duration = 2,
                Image = 4483362458
            })
        end
    end,
})

-- Fixed Distance Slider
local FixedDistanceSlider = FixedTab:CreateSlider({
    Name = "Fixed Distance",
    Range = {1, 10},
    Increment = 0.5,
    Suffix = " studs",
    CurrentValue = 3,
    Flag = "FixedDistanceAll",
    Callback = function(Value)
        States.FixedDistanceAll = Value
    end,
})

local FixedInfoLabel = FixedTab:CreateLabel("All enemies stay in front of you")
local FixedInfoLabel2 = FixedTab:CreateLabel("Even after respawn, they stay fixed")

-- ========================================
-- ⚙️ SETTINGS TAB
-- ========================================
local SettingsTab = Window:CreateTab("⚙️ Settings", 4483362458)
local SettingsSection = SettingsTab:CreateSection("Script Settings")

local InfoLabel1 = SettingsTab:CreateLabel("Silent Aim Status: Active (360°)")
local InfoLabel2 = SettingsTab:CreateLabel("Platform: " .. States.Platform)
local InfoLabel3 = SettingsTab:CreateLabel("Current Target: None")
local InfoLabel4 = SettingsTab:CreateLabel("TP Target: None")

-- Update Info Labels
Connections["InfoUpdate"] = RS.Heartbeat:Connect(function()
    SafeCall(function()
        InfoLabel3:Set("Current Target: " .. (States.CurrentTarget and States.CurrentTarget.Player.Name or "None"))
        InfoLabel4:Set("TP Target: " .. (States.CurrentTPTarget and States.CurrentTPTarget.Player.Name or "None"))
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
    GetNearestTarget()
    
    if States.HeadLock then
        HeadLock()
    end
    
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

-- Player Handlers
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
-- AUTO-ENABLE FEATURES
-- ========================================
task.wait(0.5)

States.SilentAim = true
States.HeadLock = true
States.AutoAim = true
States.ESP = true

UpdateESP()

-- ========================================
-- INITIAL NOTIFICATION
-- ========================================
Rayfield:Notify({
    Title = "⚡ Silent Aim V2 Loaded",
    Content = "✅ All features ready!\n🎯 360° Detection\n📊 Performance: 10-100%\n🌀 Auto TP: Random + Kill Loop\n🎭 Fixed Mode: Available\nPlatform: " .. States.Platform,
    Duration = 10,
    Image = 4483362458
})

print("✅ Silent Aim V2 - Advanced Aimbot System Loaded")
print("🎯 360° Detection | Performance Adjustable")
print("🌀 Auto TP: Random + Follow | Fixed Mode")
print("📱 Platform: " .. States.Platform)
print("🔫 Ready to dominate!")
