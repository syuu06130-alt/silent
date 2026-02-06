-- ⚡ Silent Aim V3 - Advanced Aimbot System
-- 🎯 Features: Enhanced Silent Aim, Auto TP, Fixed Mode
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

-- ========================================
-- SILENT AIM SETTINGS
-- ========================================
local SilentSettings = {
    Enabled = false,
    FOVRadius = 200,
    Smoothness = 1, -- 0.1-3 (低いほど速い)
    VisibleCheck = false, -- 360度対応のためfalse
    TargetPart = "Head",
    Prediction = true,
    PredictionAmount = 0.13,
    BulletSpeed = 1000,
}

-- Global States
local States = {
    SilentAim = false,
    HeadLock = false,
    AutoAim = false,
    ESP = false,
    AutoShot = false,
    
    -- Silent Aim関連
    CurrentTarget = nil,
    TargetPlayer = nil,
    
    -- Auto TP Settings
    AutoTP = false,
    TPDistance = 10,
    CurrentTPTarget = nil,
    
    -- All Players Fixed Mode
    AllPlayersFixed = false,
    FixedDistanceAll = 3,
    
    Platform = IsMobile and "Mobile" or (IsConsole and "Console" or "PC")
}

local Connections = {}
local ESPObjects = {}

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

local function SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        warn("[Silent Aim] Error: " .. tostring(result))
    end
    return success, result
end

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

-- ========================================
-- SILENT AIM CORE FUNCTIONS
-- ========================================

-- 1. ターゲット検索関数 (360度対応)
local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local camera = Camera
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            local targetPart = player.Character:FindFirstChild(SilentSettings.TargetPart)
            
            if humanoid and humanoid.Health > 0 and targetPart then
                local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                
                -- 360度対応: onScreenチェックを削除
                local distance = (Vector2.new(screenPos.X, screenPos.Y) - 
                                Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)).Magnitude
                
                -- FOVチェック
                if distance <= SilentSettings.FOVRadius then
                    -- 視線チェック (オプション)
                    if not SilentSettings.VisibleCheck or hasLineOfSight(
                        LocalPlayer.Character.Head.Position,
                        targetPart.Position
                    ) then
                        if distance < shortestDistance then
                            shortestDistance = distance
                            closestPlayer = player
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

-- 2. 予測計算関数
local function predictPosition(targetPart, velocity)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Head") then
        return targetPart.Position
    end
    
    local distance = (targetPart.Position - LocalPlayer.Character.Head.Position).Magnitude
    local timeToHit = distance / SilentSettings.BulletSpeed
    
    return targetPart.Position + (velocity * timeToHit * SilentSettings.PredictionAmount)
end

-- 3. 角度計算関数
local function calculateAngle(origin, target)
    local direction = (target - origin).Unit
    return direction
end

-- 4. FOV (視野角) チェック関数
local function isInFOV(targetPosition, fovRadius)
    local camera = Camera
    local screenPos = camera:WorldToViewportPoint(targetPosition)
    local centerScreen = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local distance = (Vector2.new(screenPos.X, screenPos.Y) - centerScreen).Magnitude
    
    return distance <= fovRadius
end

-- 5. 壁貫通チェック関数
function hasLineOfSight(origin, target)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local result = WS:Raycast(origin, (target - origin), raycastParams)
    
    if result and result.Instance then
        local hitCharacter = result.Instance:FindFirstAncestorOfClass("Model")
        if hitCharacter then
            return Players:GetPlayerFromCharacter(hitCharacter) ~= nil
        end
    end
    return true -- 何もヒットしない = 視線通っている
end

-- 6. スムージング適用関数
local function applySmoothAim(currentCFrame, targetCFrame, smoothness)
    return currentCFrame:Lerp(targetCFrame, 1 / smoothness)
end

-- ========================================
-- ESP FUNCTIONS
-- ========================================

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
                    local canSee = hasLineOfSight(Camera.CFrame.Position, player.Character.HumanoidRootPart.Position)
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

local function RemoveESP(player)
    if ESPObjects[player] then
        SafeCall(function()
            ESPObjects[player]:Destroy()
            ESPObjects[player] = nil
        end)
    end
end

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

-- ========================================
-- AUTO SHOT FUNCTION
-- ========================================

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

local function GetAllTargets()
    local targets = {}
    local cameraPosition = Camera.CFrame.Position
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            SafeCall(function()
                local character = player.Character
                local humanoid = character:FindFirstChild("Humanoid")
                local targetPart = character:FindFirstChild("Head")
                
                if humanoid and humanoid.Health > 0 and targetPart then
                    local distance = (cameraPosition - targetPart.Position).Magnitude
                    
                    table.insert(targets, {
                        Player = player,
                        Character = character,
                        Part = targetPart,
                        Position = targetPart.Position,
                        Distance = distance,
                        Humanoid = humanoid
                    })
                end
            end)
        end
    end
    
    table.sort(targets, function(a, b)
        return a.Distance < b.Distance
    end)
    
    return targets
end

local function GetRandomEnemy()
    local targets = GetAllTargets()
    if #targets > 0 then
        return targets[math.random(1, #targets)]
    end
    return nil
end

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

local function IsTargetKilled(target)
    if not target or not target.Character then return true end
    local humanoid = target.Character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return true end
    return false
end

local function AutoTPRandom()
    if not States.AutoTP then return end
    
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
    
    if States.CurrentTPTarget then
        TPToTarget(States.CurrentTPTarget, States.TPDistance)
    end
end

local function AllPlayersFixed()
    if not States.AllPlayersFixed then return end
    
    SafeCall(function()
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        
        local rootPart = character.HumanoidRootPart
        local forwardDirection = rootPart.CFrame.LookVector
        local fixedPosition = rootPart.Position + (forwardDirection * States.FixedDistanceAll)
        
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
    Name = "⚡ Silent Aim V3 | Enhanced " .. (States.Platform == "Mobile" and "📱" or States.Platform == "Console" and "🎮" or "💻"),
    LoadingTitle = "Loading Silent Aim V3...",
    LoadingSubtitle = "Platform: " .. States.Platform,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SilentAimV3",
        FileName = "Settings"
    },
    Discord = {
        Enabled = false,
    },
    KeySystem = false,
})

-- ========================================
-- 🎯 SILENT AIM TAB
-- ========================================
local SilentTab = Window:CreateTab("🎯 Silent Aim", 4483362458)
local SilentSection = SilentTab:CreateSection("Enhanced Silent Aim (360°)")

-- Silent Aim Toggle
local SilentAimToggle = SilentTab:CreateToggle({
    Name = "Silent Aim (Camera Lock)",
    CurrentValue = true,
    Flag = "SilentAim",
    Callback = function(Value)
        States.SilentAim = Value
        SilentSettings.Enabled = Value
        
        if Value then
            -- Silent Aimメインループ開始
            Connections["SilentAimLoop"] = RS.RenderStepped:Connect(function()
                if not SilentSettings.Enabled then return end
                
                local targetPlayer = getClosestPlayer()
                if not targetPlayer or not targetPlayer.Character then 
                    States.CurrentTarget = nil
                    States.TargetPlayer = nil
                    return 
                end
                
                local targetPart = targetPlayer.Character:FindFirstChild(SilentSettings.TargetPart)
                if not targetPart then return end
                
                -- FOVチェック
                if not isInFOV(targetPart.Position, SilentSettings.FOVRadius) then return end
                
                -- 現在のターゲット保存
                States.CurrentTarget = targetPart
                States.TargetPlayer = targetPlayer
                
                local targetPos = targetPart.Position
                
                -- 予測適用
                if SilentSettings.Prediction then
                    local velocity = targetPart.AssemblyLinearVelocity
                    targetPos = predictPosition(targetPart, velocity)
                end
                
                -- スムージング適用
                local camera = Camera
                local currentCFrame = camera.CFrame
                local targetCFrame = CFrame.new(camera.CFrame.Position, targetPos)
                
                camera.CFrame = applySmoothAim(currentCFrame, targetCFrame, SilentSettings.Smoothness)
            end)
            
            Rayfield:Notify({
                Title = "Silent Aim",
                Content = "✅ Enabled (360° Enhanced)",
                Duration = 3,
                Image = 4483362458
            })
        else
            if Connections["SilentAimLoop"] then
                Connections["SilentAimLoop"]:Disconnect()
                Connections["SilentAimLoop"] = nil
            end
            States.CurrentTarget = nil
            States.TargetPlayer = nil
            
            Rayfield:Notify({
                Title = "Silent Aim",
                Content = "❌ Disabled",
                Duration = 2,
                Image = 4483362458
            })
        end
    end,
})

-- Smoothness Slider (0.1-3)
local SmoothnessSlider = SilentTab:CreateSlider({
    Name = "Smoothness (引き付き速度)",
    Range = {0.1, 3},
    Increment = 0.1,
    Suffix = "",
    CurrentValue = 1,
    Flag = "Smoothness",
    Callback = function(Value)
        SilentSettings.Smoothness = Value
    end,
})

-- FOV Slider
local FOVSlider = SilentTab:CreateSlider({
    Name = "FOV Radius (検出範囲)",
    Range = {50, 500},
    Increment = 10,
    Suffix = "px",
    CurrentValue = 200,
    Flag = "FOVRadius",
    Callback = function(Value)
        SilentSettings.FOVRadius = Value
    end,
})

-- Target Part Selection
local TargetPartDropdown = SilentTab:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "UpperTorso", "HumanoidRootPart"},
    CurrentOption = "Head",
    Flag = "TargetPart",
    Callback = function(Option)
        SilentSettings.TargetPart = Option
    end,
})

-- Prediction Toggle
local PredictionToggle = SilentTab:CreateToggle({
    Name = "Prediction (予測射撃)",
    CurrentValue = true,
    Flag = "Prediction",
    Callback = function(Value)
        SilentSettings.Prediction = Value
    end,
})

-- Prediction Amount
local PredictionSlider = SilentTab:CreateSlider({
    Name = "Prediction Amount",
    Range = {0.05, 0.5},
    Increment = 0.01,
    Suffix = "",
    CurrentValue = 0.13,
    Flag = "PredictionAmount",
    Callback = function(Value)
        SilentSettings.PredictionAmount = Value
    end,
})

-- Visible Check Toggle
local VisibleCheckToggle = SilentTab:CreateToggle({
    Name = "Visible Check (視線チェック)",
    CurrentValue = false,
    Flag = "VisibleCheck",
    Callback = function(Value)
        SilentSettings.VisibleCheck = Value
    end,
})

local SilentInfoLabel = SilentTab:CreateLabel("低いSmoothness = 速い追従")
local SilentInfoLabel2 = SilentTab:CreateLabel("0.1 = ほぼ瞬時 | 3 = 滑らか")

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

local ESPInfoLabel = ESPTab:CreateLabel("Red = Visible | Orange = Behind Wall")

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

local AutoTPToggle = AutoTPTab:CreateToggle({
    Name = "Auto TP (Random + Kill Loop)",
    CurrentValue = false,
    Flag = "AutoTP",
    Callback = function(Value)
        States.AutoTP = Value
        
        if Value then
            States.CurrentTPTarget = GetRandomEnemy()
            
            Connections["AutoTPRandom"] = RS.Heartbeat:Connect(function()
                AutoTPRandom()
            end)
            
            Rayfield:Notify({
                Title = "Auto TP",
                Content = "✅ Enabled - Random TP + Kill Loop",
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
local TPInfoLabel2 = AutoTPTab:CreateLabel("Auto switches after kill")

-- ========================================
-- 🎭 ALL PLAYERS FIXED TAB
-- ========================================
local FixedTab = Window:CreateTab("🎭 Fixed Mode", 4483362458)
local FixedSection = FixedTab:CreateSection("All Players Fixed Position")

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
                Content = "✅ All enemies fixed " .. States.FixedDistanceAll .. " studs",
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

local FixedInfoLabel = FixedTab:CreateLabel("All enemies stay in front")
local FixedInfoLabel2 = FixedTab:CreateLabel("Even after respawn")

-- ========================================
-- ⚙️ SETTINGS TAB
-- ========================================
local SettingsTab = Window:CreateTab("⚙️ Settings", 4483362458)
local SettingsSection = SettingsTab:CreateSection("Script Settings")

local InfoLabel1 = SettingsTab:CreateLabel("Silent Aim V3: Enhanced")
local InfoLabel2 = SettingsTab:CreateLabel("Platform: " .. States.Platform)
local InfoLabel3 = SettingsTab:CreateLabel("Current Target: None")
local InfoLabel4 = SettingsTab:CreateLabel("TP Target: None")

Connections["InfoUpdate"] = RS.Heartbeat:Connect(function()
    SafeCall(function()
        InfoLabel3:Set("Current Target: " .. (States.TargetPlayer and States.TargetPlayer.Name or "None"))
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
States.ESP = true
SilentSettings.Enabled = true

-- Silent Aimメインループを自動起動
Connections["SilentAimLoop"] = RS.RenderStepped:Connect(function()
    if not SilentSettings.Enabled then return end
    
    local targetPlayer = getClosestPlayer()
    if not targetPlayer or not targetPlayer.Character then 
        States.CurrentTarget = nil
        States.TargetPlayer = nil
        return 
    end
    
    local targetPart = targetPlayer.Character:FindFirstChild(SilentSettings.TargetPart)
    if not targetPart then return end
    
    if not isInFOV(targetPart.Position, SilentSettings.FOVRadius) then return end
    
    States.CurrentTarget = targetPart
    States.TargetPlayer = targetPlayer
    
    local targetPos = targetPart.Position
    
    if SilentSettings.Prediction then
        local velocity = targetPart.AssemblyLinearVelocity
        targetPos = predictPosition(targetPart, velocity)
    end
    
    local camera = Camera
    local currentCFrame = camera.CFrame
    local targetCFrame = CFrame.new(camera.CFrame.Position, targetPos)
    
    camera.CFrame = applySmoothAim(currentCFrame, targetCFrame, SilentSettings.Smoothness)
end)

UpdateESP()

-- ========================================
-- INITIAL NOTIFICATION
-- ========================================
Rayfield:Notify({
    Title = "⚡ Silent Aim V3 Loaded",
    Content = "✅ Enhanced Silent Aim!\n🎯 360° Detection\n📊 Smoothness: 0.1-3\n🔮 Prediction: ON\n🌀 Auto TP: Ready\n🎭 Fixed Mode: Ready\nPlatform: " .. States.Platform,
    Duration = 10,
    Image = 4483362458
})

print("✅ Silent Aim V3 - Enhanced System Loaded")
print("🎯 360° Detection | Prediction ON")
print("📊 Smoothness: 0.1-3 (Instant to Smooth)")
print("🌀 Auto TP | Fixed Mode Ready")
print("📱 Platform: " .. States.Platform)
print("🔫 Ready to dominate!")
