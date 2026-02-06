-- Rayfield UI + Complete Silent Aim Module for [FPS] フリック
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "FPS フリック | Combat System",
   LoadingTitle = "Combat System Loading...",
   LoadingSubtitle = "by Script",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = nil,
      FileName = "FlickCombatSystem"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvitelink",
      RememberJoins = true
   },
   KeySystem = false,
})

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Combat Configuration
local Combat = {
    -- Silent Aim
    SilentAim = {
        Enabled = false,
        FOV = 150,
        TargetPart = "Head",
        TeamCheck = true,
        VisibleCheck = true,
        Prediction = true,
        PredictionAmount = 0.1,
        WallCheck = true,
        IgnoreFriends = false,
        MaxDistance = 1000,
        StickyAim = false, -- ターゲット固定
    },
    
    -- Trigger Bot
    TriggerBot = {
        Enabled = false,
        Delay = 0.05,
        TeamCheck = true,
        VisibleOnly = true,
    },
    
    -- Auto Shoot
    AutoShoot = {
        Enabled = false,
        RequireADS = false, -- エイム時のみ
        MinimumAccuracy = 0,
    },
    
    -- Target Selection
    TargetSelection = {
        Mode = "Closest", -- Closest, Lowest HP, Highest Threat
        PrioritizeHead = true,
        PrioritizeVisible = true,
        IgnoreDowned = true,
        IgnoreTeammates = true,
    },
    
    -- Hit Parts
    HitParts = {
        Head = true,
        Torso = false,
        Arms = false,
        Legs = false,
        VisiblePart = false, -- 見える部位を狙う
        AutoSwitch = false, -- 自動切り替え
    },
    
    -- Aimbot
    Aimbot = {
        Enabled = false,
        Smoothness = 5,
        FOV = 100,
        VisibleCheck = true,
        TeamCheck = true,
        LockTarget = false,
    },
    
    -- Recoil Control
    RecoilControl = {
        Enabled = false,
        Strength = 100,
        Horizontal = true,
        Vertical = true,
    },
    
    -- Bullet Tracker
    BulletTracker = {
        Enabled = false,
        TracerColor = Color3.fromRGB(255, 0, 0),
        TracerThickness = 2,
        TracerDuration = 2,
    },
}

-- ==================== MAIN TAB ====================
local MainTab = Window:CreateTab("🎯 Main", 4483362458)
local Section1 = MainTab:CreateSection("Silent Aim Core")

local SilentAimToggle = MainTab:CreateToggle({
   Name = "Silent Aim",
   CurrentValue = false,
   Flag = "SilentAimToggle",
   Callback = function(Value)
      Combat.SilentAim.Enabled = Value
      Rayfield:Notify({
         Title = "Silent Aim",
         Content = Value and "有効化" or "無効化",
         Duration = 2,
         Image = 4483362458,
      })
   end,
})

local FOVSlider = MainTab:CreateSlider({
   Name = "FOV (視野角)",
   Range = {10, 500},
   Increment = 10,
   Suffix = "px",
   CurrentValue = 150,
   Flag = "FOVSlider",
   Callback = function(Value)
      Combat.SilentAim.FOV = Value
   end,
})

local MaxDistanceSlider = MainTab:CreateSlider({
   Name = "最大距離",
   Range = {100, 5000},
   Increment = 100,
   Suffix = "studs",
   CurrentValue = 1000,
   Flag = "MaxDistanceSlider",
   Callback = function(Value)
      Combat.SilentAim.MaxDistance = Value
   end,
})

local TargetPartDropdown = MainTab:CreateDropdown({
   Name = "狙う部位",
   Options = {"Head", "UpperTorso", "HumanoidRootPart", "LowerTorso"},
   CurrentOption = {"Head"},
   MultipleOptions = false,
   Flag = "TargetPartDropdown",
   Callback = function(Option)
      Combat.SilentAim.TargetPart = Option[1]
   end,
})

local Section2 = MainTab:CreateSection("Silent Aim Settings")

local TeamCheckToggle = MainTab:CreateToggle({
   Name = "チームチェック",
   CurrentValue = true,
   Flag = "TeamCheckToggle",
   Callback = function(Value)
      Combat.SilentAim.TeamCheck = Value
   end,
})

local VisibleCheckToggle = MainTab:CreateToggle({
   Name = "視界チェック",
   CurrentValue = true,
   Flag = "VisibleCheckToggle",
   Callback = function(Value)
      Combat.SilentAim.VisibleCheck = Value
   end,
})

local WallCheckToggle = MainTab:CreateToggle({
   Name = "壁チェック",
   CurrentValue = true,
   Flag = "WallCheckToggle",
   Callback = function(Value)
      Combat.SilentAim.WallCheck = Value
   end,
})

local PredictionToggle = MainTab:CreateToggle({
   Name = "移動予測",
   CurrentValue = true,
   Flag = "PredictionToggle",
   Callback = function(Value)
      Combat.SilentAim.Prediction = Value
   end,
})

local PredictionSlider = MainTab:CreateSlider({
   Name = "予測量",
   Range = {0, 0.5},
   Increment = 0.01,
   Suffix = "s",
   CurrentValue = 0.1,
   Flag = "PredictionSlider",
   Callback = function(Value)
      Combat.SilentAim.PredictionAmount = Value
   end,
})

local StickyAimToggle = MainTab:CreateToggle({
   Name = "スティッキーエイム (ターゲット固定)",
   CurrentValue = false,
   Flag = "StickyAimToggle",
   Callback = function(Value)
      Combat.SilentAim.StickyAim = Value
   end,
})

local IgnoreFriendsToggle = MainTab:CreateToggle({
   Name = "フレンド除外",
   CurrentValue = false,
   Flag = "IgnoreFriendsToggle",
   Callback = function(Value)
      Combat.SilentAim.IgnoreFriends = Value
   end,
})

-- ==================== COMBAT TAB ====================
local CombatTab = Window:CreateTab("⚔️ Combat", 4483362458)

local Section3 = CombatTab:CreateSection("Auto Functions")

local TriggerBotToggle = CombatTab:CreateToggle({
   Name = "Trigger Bot (自動射撃)",
   CurrentValue = false,
   Flag = "TriggerBotToggle",
   Callback = function(Value)
      Combat.TriggerBot.Enabled = Value
   end,
})

local TriggerDelaySlider = CombatTab:CreateSlider({
   Name = "Trigger 遅延",
   Range = {0, 0.5},
   Increment = 0.01,
   Suffix = "s",
   CurrentValue = 0.05,
   Flag = "TriggerDelaySlider",
   Callback = function(Value)
      Combat.TriggerBot.Delay = Value
   end,
})

local AutoShootToggle = CombatTab:CreateToggle({
   Name = "Auto Shoot (敵検出時自動発砲)",
   CurrentValue = false,
   Flag = "AutoShootToggle",
   Callback = function(Value)
      Combat.AutoShoot.Enabled = Value
   end,
})

local RequireADSToggle = CombatTab:CreateToggle({
   Name = "ADS時のみ発砲",
   CurrentValue = false,
   Flag = "RequireADSToggle",
   Callback = function(Value)
      Combat.AutoShoot.RequireADS = Value
   end,
})

local Section4 = CombatTab:CreateSection("Aimbot")

local AimbotToggle = CombatTab:CreateToggle({
   Name = "Aimbot",
   CurrentValue = false,
   Flag = "AimbotToggle",
   Callback = function(Value)
      Combat.Aimbot.Enabled = Value
   end,
})

local AimbotSmoothnessSlider = CombatTab:CreateSlider({
   Name = "滑らかさ",
   Range = {1, 20},
   Increment = 1,
   Suffix = "",
   CurrentValue = 5,
   Flag = "AimbotSmoothnessSlider",
   Callback = function(Value)
      Combat.Aimbot.Smoothness = Value
   end,
})

local AimbotFOVSlider = CombatTab:CreateSlider({
   Name = "Aimbot FOV",
   Range = {10, 360},
   Increment = 10,
   Suffix = "°",
   CurrentValue = 100,
   Flag = "AimbotFOVSlider",
   Callback = function(Value)
      Combat.Aimbot.FOV = Value
   end,
})

local LockTargetToggle = CombatTab:CreateToggle({
   Name = "ターゲットロック",
   CurrentValue = false,
   Flag = "LockTargetToggle",
   Callback = function(Value)
      Combat.Aimbot.LockTarget = Value
   end,
})

local Section5 = CombatTab:CreateSection("Target Selection")

local TargetModeDropdown = CombatTab:CreateDropdown({
   Name = "ターゲット優先順位",
   Options = {"Closest", "Lowest HP", "Highest Threat"},
   CurrentOption = {"Closest"},
   MultipleOptions = false,
   Flag = "TargetModeDropdown",
   Callback = function(Option)
      Combat.TargetSelection.Mode = Option[1]
   end,
})

local PrioritizeHeadToggle = CombatTab:CreateToggle({
   Name = "ヘッドショット優先",
   CurrentValue = true,
   Flag = "PrioritizeHeadToggle",
   Callback = function(Value)
      Combat.TargetSelection.PrioritizeHead = Value
   end,
})

local PrioritizeVisibleToggle = CombatTab:CreateToggle({
   Name = "視認可能な敵優先",
   CurrentValue = true,
   Flag = "PrioritizeVisibleToggle",
   Callback = function(Value)
      Combat.TargetSelection.PrioritizeVisible = Value
   end,
})

local IgnoreDownedToggle = CombatTab:CreateToggle({
   Name = "ダウン中の敵を無視",
   CurrentValue = true,
   Flag = "IgnoreDownedToggle",
   Callback = function(Value)
      Combat.TargetSelection.IgnoreDowned = Value
   end,
})

local Section6 = CombatTab:CreateSection("Hit Parts Configuration")

local HeadToggle = CombatTab:CreateToggle({
   Name = "Head (頭)",
   CurrentValue = true,
   Flag = "HeadToggle",
   Callback = function(Value)
      Combat.HitParts.Head = Value
   end,
})

local TorsoToggle = CombatTab:CreateToggle({
   Name = "Torso (胴体)",
   CurrentValue = false,
   Flag = "TorsoToggle",
   Callback = function(Value)
      Combat.HitParts.Torso = Value
   end,
})

local ArmsToggle = CombatTab:CreateToggle({
   Name = "Arms (腕)",
   CurrentValue = false,
   Flag = "ArmsToggle",
   Callback = function(Value)
      Combat.HitParts.Arms = Value
   end,
})

local LegsToggle = CombatTab:CreateToggle({
   Name = "Legs (脚)",
   CurrentValue = false,
   Flag = "LegsToggle",
   Callback = function(Value)
      Combat.HitParts.Legs = Value
   end,
})

local VisiblePartToggle = CombatTab:CreateToggle({
   Name = "Visible Part Only (見える部位のみ)",
   CurrentValue = false,
   Flag = "VisiblePartToggle",
   Callback = function(Value)
      Combat.HitParts.VisiblePart = Value
   end,
})

local AutoSwitchToggle = CombatTab:CreateToggle({
   Name = "Auto Switch Parts (部位自動切替)",
   CurrentValue = false,
   Flag = "AutoSwitchToggle",
   Callback = function(Value)
      Combat.HitParts.AutoSwitch = Value
   end,
})

local Section7 = CombatTab:CreateSection("Recoil & Spread")

local RecoilToggle = CombatTab:CreateToggle({
   Name = "リコイル制御",
   CurrentValue = false,
   Flag = "RecoilToggle",
   Callback = function(Value)
      Combat.RecoilControl.Enabled = Value
   end,
})

local RecoilStrengthSlider = CombatTab:CreateSlider({
   Name = "制御強度",
   Range = {0, 100},
   Increment = 5,
   Suffix = "%",
   CurrentValue = 100,
   Flag = "RecoilStrengthSlider",
   Callback = function(Value)
      Combat.RecoilControl.Strength = Value
   end,
})

local HorizontalRecoilToggle = CombatTab:CreateToggle({
   Name = "横反動制御",
   CurrentValue = true,
   Flag = "HorizontalRecoilToggle",
   Callback = function(Value)
      Combat.RecoilControl.Horizontal = Value
   end,
})

local VerticalRecoilToggle = CombatTab:CreateToggle({
   Name = "縦反動制御",
   CurrentValue = true,
   Flag = "VerticalRecoilToggle",
   Callback = function(Value)
      Combat.RecoilControl.Vertical = Value
   end,
})

-- ==================== SUB TAB ====================
local SubTab = Window:CreateTab("🔧 Sub", 4483362458)

local Section8 = SubTab:CreateSection("Weapon Modifications")

local NoReloadToggle = SubTab:CreateToggle({
   Name = "リロード不要",
   CurrentValue = false,
   Flag = "NoReloadToggle",
   Callback = function(Value)
      -- ゲーム固有の実装が必要
      Rayfield:Notify({
         Title = "リロード不要",
         Content = Value and "有効" or "無効",
         Duration = 2,
      })
   end,
})

local InfiniteAmmoToggle = SubTab:CreateToggle({
   Name = "無限弾薬",
   CurrentValue = false,
   Flag = "InfiniteAmmoToggle",
   Callback = function(Value)
      -- ゲーム固有の実装が必要
      Rayfield:Notify({
         Title = "無限弾薬",
         Content = Value and "有効" or "無効",
         Duration = 2,
      })
   end,
})

local RapidFireToggle = SubTab:CreateToggle({
   Name = "ラピッドファイア",
   CurrentValue = false,
   Flag = "RapidFireToggle",
   Callback = function(Value)
      -- ゲーム固有の実装が必要
      Rayfield:Notify({
         Title = "ラピッドファイア",
         Content = Value and "有効" or "無効",
         Duration = 2,
      })
   end,
})

local NoSpreadToggle = SubTab:CreateToggle({
   Name = "拡散なし",
   CurrentValue = false,
   Flag = "NoSpreadToggle",
   Callback = function(Value)
      -- ゲーム固有の実装が必要
      Rayfield:Notify({
         Title = "拡散なし",
         Content = Value and "有効" or "無効",
         Duration = 2,
      })
   end,
})

local InstantHitToggle = SubTab:CreateToggle({
   Name = "即着弾",
   CurrentValue = false,
   Flag = "InstantHitToggle",
   Callback = function(Value)
      -- ゲーム固有の実装が必要
      Rayfield:Notify({
         Title = "即着弾",
         Content = Value and "有効" or "無効",
         Duration = 2,
      })
   end,
})

local Section9 = SubTab:CreateSection("Bullet Modifications")

local BulletTrackerToggle = SubTab:CreateToggle({
   Name = "弾道トレーサー",
   CurrentValue = false,
   Flag = "BulletTrackerToggle",
   Callback = function(Value)
      Combat.BulletTracker.Enabled = Value
   end,
})

local TracerColorPicker = SubTab:CreateColorPicker({
   Name = "トレーサー色",
   Color = Color3.fromRGB(255, 0, 0),
   Flag = "TracerColorPicker",
   Callback = function(Value)
      Combat.BulletTracker.TracerColor = Value
   end
})

local TracerThicknessSlider = SubTab:CreateSlider({
   Name = "トレーサー太さ",
   Range = {1, 10},
   Increment = 1,
   Suffix = "px",
   CurrentValue = 2,
   Flag = "TracerThicknessSlider",
   Callback = function(Value)
      Combat.BulletTracker.TracerThickness = Value
   end,
})

local TracerDurationSlider = SubTab:CreateSlider({
   Name = "トレーサー表示時間",
   Range = {0.5, 10},
   Increment = 0.5,
   Suffix = "s",
   CurrentValue = 2,
   Flag = "TracerDurationSlider",
   Callback = function(Value)
      Combat.BulletTracker.TracerDuration = Value
   end,
})

local Section10 = SubTab:CreateSection("Auto Actions")

local AutoReloadToggle = SubTab:CreateToggle({
   Name = "オートリロード",
   CurrentValue = false,
   Flag = "AutoReloadToggle",
   Callback = function(Value)
      -- ゲーム固有の実装が必要
   end,
})

local AutoSwitchWeaponToggle = SubTab:CreateToggle({
   Name = "弾切れ時武器切替",
   CurrentValue = false,
   Flag = "AutoSwitchWeaponToggle",
   Callback = function(Value)
      -- ゲーム固有の実装が必要
   end,
})

-- ==================== VISUAL TAB ====================
local VisualTab = Window:CreateTab("👁️ Visual", 4483362458)
local Section11 = VisualTab:CreateSection("FOV Circle")

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.NumSides = 50
FOVCircle.Radius = Combat.SilentAim.FOV
FOVCircle.Filled = false
FOVCircle.Visible = false
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Transparency = 1

local ShowFOVToggle = VisualTab:CreateToggle({
   Name = "FOV円を表示",
   CurrentValue = false,
   Flag = "ShowFOVToggle",
   Callback = function(Value)
      FOVCircle.Visible = Value
   end,
})

local FOVColorPicker = VisualTab:CreateColorPicker({
   Name = "FOV円の色",
   Color = Color3.fromRGB(255, 255, 255),
   Flag = "FOVColorPicker",
   Callback = function(Value)
      FOVCircle.Color = Value
   end
})

local Section12 = VisualTab:CreateSection("Target Indicators")

local TargetESPToggle = VisualTab:CreateToggle({
   Name = "ターゲット強調表示",
   CurrentValue = false,
   Flag = "TargetESPToggle",
   Callback = function(Value)
      -- 実装が必要
   end,
})

local ShowTargetNameToggle = VisualTab:CreateToggle({
   Name = "ターゲット名表示",
   CurrentValue = false,
   Flag = "ShowTargetNameToggle",
   Callback = function(Value)
      -- 実装が必要
   end,
})

local ShowTargetHealthToggle = VisualTab:CreateToggle({
   Name = "ターゲット体力表示",
   CurrentValue = false,
   Flag = "ShowTargetHealthToggle",
   Callback = function(Value)
      -- 実装が必要
   end,
})

local ShowTargetDistanceToggle = VisualTab:CreateToggle({
   Name = "ターゲット距離表示",
   CurrentValue = false,
   Flag = "ShowTargetDistanceToggle",
   Callback = function(Value)
      -- 実装が必要
   end,
})

-- Update FOV Circle
RunService.RenderStepped:Connect(function()
   if FOVCircle.Visible then
      FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
      FOVCircle.Radius = Combat.SilentAim.FOV
   end
end)

-- ==================== CORE FUNCTIONS ====================

-- Get Closest Player Function with Advanced Selection
local lockedTarget = nil
local function getClosestPlayerToMouse()
    if Combat.SilentAim.StickyAim and lockedTarget and lockedTarget.Character then
        return lockedTarget
    end
    
    local closestPlayer = nil
    local shortestDistance = Combat.SilentAim.FOV
    local highestPriority = -math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            -- Team Check
            if Combat.SilentAim.TeamCheck and player.Team == LocalPlayer.Team then continue end
            
            -- Friend Check
            if Combat.SilentAim.IgnoreFriends and LocalPlayer:IsFriendsWith(player.UserId) then continue end
            
            local character = player.Character
            local humanoid = character:FindFirstChild("Humanoid")
            
            -- Ignore Downed
            if Combat.TargetSelection.IgnoreDowned and humanoid and humanoid.Health <= 0 then continue end
            
            -- Get Target Part
            local targetPart = character:FindFirstChild(Combat.SilentAim.TargetPart) or character.HumanoidRootPart
            local screenPoint, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            
            if onScreen then
                local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)).Magnitude
                local worldDistance = (Camera.CFrame.Position - targetPart.Position).Magnitude
                
                -- Distance Check
                if worldDistance > Combat.SilentAim.MaxDistance then continue end
                
                if distance < shortestDistance then
                    -- Visibility Check
                    local isVisible = true
                    if Combat.SilentAim.VisibleCheck or Combat.SilentAim.WallCheck then
                        local ray = Workspace:Raycast(Camera.CFrame.Position, (targetPart.Position - Camera.CFrame.Position).Unit * worldDistance)
                        isVisible = ray and ray.Instance:IsDescendantOf(character)
                    end
                    
                    if isVisible or not Combat.SilentAim.VisibleCheck then
                        -- Calculate Priority
                        local priority = 0
                        
                        if Combat.TargetSelection.Mode == "Closest" then
                            priority = -distance
                        elseif Combat.TargetSelection.Mode == "Lowest HP" and humanoid then
                            priority = -humanoid.Health
                        elseif Combat.TargetSelection.Mode == "Highest Threat" then
                            -- 距離と体力を考慮した脅威度
                            priority = (humanoid and humanoid.Health or 100) / math.max(worldDistance, 1)
                        end
                        
                        -- Prioritize Visible
                        if Combat.TargetSelection.PrioritizeVisible and isVisible then
                            priority = priority + 10000
                        end
                        
                        if priority > highestPriority then
                            closestPlayer = player
                            shortestDistance = distance
                            highestPriority = priority
                        end
                    end
                end
            end
        end
    end
    
    if Combat.SilentAim.StickyAim and closestPlayer then
        lockedTarget = closestPlayer
    end
    
    return closestPlayer
end

-- Get Best Hit Part
local function getBestHitPart(character)
    if not character then return nil end
    
    local parts = {}
    
    if Combat.HitParts.Head and character:FindFirstChild("Head") then
        table.insert(parts, character.Head)
    end
    if Combat.HitParts.Torso then
        if character:FindFirstChild("UpperTorso") then table.insert(parts, character.UpperTorso) end
        if character:FindFirstChild("LowerTorso") then table.insert(parts, character.LowerTorso) end
    end
    if Combat.HitParts.Arms then
        if character:FindFirstChild("LeftUpperArm") then table.insert(parts, character.LeftUpperArm) end
        if character:FindFirstChild("RightUpperArm") then table.insert(parts, character.RightUpperArm) end
    end
    if Combat.HitParts.Legs then
        if character:FindFirstChild("LeftUpperLeg") then table.insert(parts, character.LeftUpperLeg) end
        if character:FindFirstChild("RightUpperLeg") then table.insert(parts, character.RightUpperLeg) end
    end
    
    -- Visible Part Only
    if Combat.HitParts.VisiblePart then
        for _, part in ipairs(parts) do
            local ray = Workspace:Raycast(Camera.CFrame.Position, (part.Position - Camera.CFrame.Position).Unit * 1000)
            if ray and ray.Instance == part then
                return part
            end
        end
    end
    
    -- Auto Switch
    if Combat.HitParts.AutoSwitch and #parts > 0 then
        return parts[math.random(1, #parts)]
    end
    
    return parts[1] or character:FindFirstChild(Combat.SilentAim.TargetPart) or character.HumanoidRootPart
end

-- Hook Namecall (FireServer, InvokeServer, etc.)
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    
    -- Silent Aim Hook
    if method == "FireServer" or method == "InvokeServer" then
        if (self.Name:find("Fire") or self.Name:find("Shoot") or self.Name:find("Gun") or self.Name:find("Weapon")) then
            if Combat.SilentAim.Enabled then
                local targetPlayer = getClosestPlayerToMouse()
                if targetPlayer and targetPlayer.Character then
                    local targetPart = getBestHitPart(targetPlayer.Character)
                    if targetPart then
                        local targetPos = targetPart.Position
                        
                        -- Prediction
                        if Combat.SilentAim.Prediction then
                            local velocity = targetPlayer.Character.HumanoidRootPart.Velocity
                            targetPos = targetPos + (velocity * Combat.SilentAim.PredictionAmount)
                        end
                        
                        -- 引数の位置を上書き (ゲームによって異なる可能性あり)
                        for i, arg in ipairs(args) do
                            if typeof(arg) == "Vector3" then
                                args[i] = targetPos
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    
    return oldNamecall(self, unpack(args))
end)

-- Hook Index/Newindex for Mouse (一部ゲーム用)
local oldIndex = mt.__index
mt.__index = newcclosure(function(self, key)
    if Combat.SilentAim.Enabled and tostring(self) == "Mouse" and (key == "Hit" or key == "Target") then
        local targetPlayer = getClosestPlayerToMouse()
        if targetPlayer and targetPlayer.Character then
            local targetPart = getBestHitPart(targetPlayer.Character)
            if targetPart then
                local targetPos = targetPart.Position
                
                if Combat.SilentAim.Prediction then
                    local velocity = targetPlayer.Character.HumanoidRootPart.Velocity
                    targetPos = targetPos + (velocity * Combat.SilentAim.PredictionAmount)
                end
                
                if key == "Hit" then
                    return CFrame.new(targetPos)
                elseif key == "Target" then
                    return targetPart
                end
            end
        end
    end
    
    return oldIndex(self, key)
end)

setreadonly(mt, true)

-- Trigger Bot
local canShoot = true
RunService.Heartbeat:Connect(function()
    if Combat.TriggerBot.Enabled then
        local targetPlayer = getClosestPlayerToMouse()
        if targetPlayer and canShoot then
            canShoot = false
            task.wait(Combat.TriggerBot.Delay)
            -- ゲーム固有のシュート関数を呼ぶ
            -- mouse1click() または特定のRemoteEvent:FireServer()
            canShoot = true
        end
    end
end)

-- Aimbot
local aimbotTarget = nil
RunService.RenderStepped:Connect(function()
    if Combat.Aimbot.Enabled then
        local target = getClosestPlayerToMouse()
        if target and target.Character then
            if Combat.Aimbot.LockTarget and not aimbotTarget then
                aimbotTarget = target
            elseif not Combat.Aimbot.LockTarget then
                aimbotTarget = target
            end
            
            if aimbotTarget and aimbotTarget.Character then
                local targetPart = getBestHitPart(aimbotTarget.Character)
                if targetPart then
                    local targetPos = targetPart.Position
                    local cameraPos = Camera.CFrame.Position
                    local newCFrame = CFrame.new(cameraPos, targetPos)
                    
                    Camera.CFrame = Camera.CFrame:Lerp(newCFrame, 1 / Combat.Aimbot.Smoothness)
                end
            end
        else
            aimbotTarget = nil
        end
    end
end)

-- Unlock Sticky Aim on Key Press
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.X then
        lockedTarget = nil
        aimbotTarget = nil
    end
end)

-- ==================== INFO TAB ====================
local InfoTab = Window:CreateTab("ℹ️ Info", 4483362458)

InfoTab:CreateParagraph({
   Title = "使い方",
   Content = "• Main: Silent Aimの基本設定\n• Combat: 戦闘支援機能\n• Sub: 武器・弾薬修正\n• Visual: 視覚的エフェクト"
})

InfoTab:CreateParagraph({
   Title = "キーバインド",
   Content = "• X キー: ターゲットロック解除"
})

InfoTab:CreateButton({
   Name = "設定をリセット",
   Callback = function()
      Rayfield:Notify({
         Title = "リセット",
         Content = "設定をリセットしました",
         Duration = 3,
      })
   end,
})

Rayfield:LoadConfiguration()

print("Complete Combat System loaded for [FPS] フリック")
