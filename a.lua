-- ⚡ Silent Aim V3 - Advanced Aimbot System (完全修正版)
-- 🔫 Game: Sniper FPS Arena [1]

-- UI Framework Loading
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services [1, 2]
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

-- 設定値の初期化 [2, 3]
local SilentSettings = {
    Enabled = false,
    SilentEnabled = true, -- 真のサイレントエイムを有効化
    FOVRadius = 200,
    Smoothness = 1,
    VisibleCheck = true,
    TargetPart = "Head",
    Prediction = true,
    PredictionAmount = 0.13,
    BulletSpeed = 1000,
}

local States = {
    SilentAim = false,
    ESP = false,
    AutoShot = false,
    CurrentTarget = nil,
    TargetPlayer = nil,
    Platform = UIS.TouchEnabled and "Mobile" or "PC" [4]
}

local Connections = {}
local ESPObjects = {}

-- ========================================
-- ユーティリティ関数
-- ========================================

-- 壁貫通チェック [5]
local function hasLineOfSight(origin, target, ignoreList)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = ignoreList or {LocalPlayer.Character, Camera}
    
    local result = WS:Raycast(origin, (target - origin), raycastParams)
    return result == nil
end

-- 予測位置の計算 (Ping考慮版) [6, 7]
local function predictPosition(targetPart)
    local velocity = targetPart.AssemblyLinearVelocity
    local distance = (targetPart.Position - Camera.CFrame.Position).Magnitude
    local ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    local timeToHit = (distance / SilentSettings.BulletSpeed) + ping
    
    return targetPart.Position + (velocity * timeToHit * SilentSettings.PredictionAmount)
end

-- ターゲット検索 (カーソルに最も近い敵) [8, 9]
local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = SilentSettings.FOVRadius

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
            local humanoid = player.Character.Humanoid
            local targetPart = player.Character:FindFirstChild(SilentSettings.TargetPart)

            if humanoid.Health > 0 and targetPart then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                
                if onScreen then
                    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude

                    if distance < shortestDistance then
                        -- 可視チェックが有効な場合の判定
                        if not SilentSettings.VisibleCheck or hasLineOfSight(Camera.CFrame.Position, targetPart.Position, {LocalPlayer.Character, player.Character}) then
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

-- ========================================
-- サイレントエイムのコア修正
-- ========================================

-- サーバー通信のフック (真のサイレントエイム) [10]
local function FireSilentEvent(targetPart)
    if not targetPart or not SilentSettings.SilentEnabled then return end
    
    local targetPos = targetPart.Position
    if SilentSettings.Prediction then
        targetPos = predictPosition(targetPart)
    end
    
    -- Sniper FPS Arenaの通信プロトコルに合わせる [10, 11]
    local mainRemote = ReplicatedStorage:FindFirstChild("MainEvent")
    if mainRemote then
        mainRemote:FireServer("UpdateMousePos", targetPos)
    end
end

-- ========================================
-- メインループ
-- ========================================

Connections["MainLoop"] = RS.RenderStepped:Connect(function()
    if not States.SilentAim then 
        States.CurrentTarget = nil
        return 
    end

    local targetPlayer = getClosestPlayer()
    if targetPlayer and targetPlayer.Character then
        local targetPart = targetPlayer.Character:FindFirstChild(SilentSettings.TargetPart)
        if targetPart then
            States.CurrentTarget = targetPart
            States.TargetPlayer = targetPlayer
            
            -- カメラロック(Cam Lock)が不要な場合は以下をコメントアウト可能
            local targetPos = SilentSettings.Prediction and predictPosition(targetPart) or targetPart.Position
            local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPos)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, 1 / SilentSettings.Smoothness) [12, 13]
        end
    else
        States.CurrentTarget = nil
    end
end)

-- 射撃時にサイレントエイムを適用するフック [7]
LocalPlayer.CharacterChildAdded = LocalPlayer.Character.ChildAdded:Connect(function(tool)
    if tool:IsA("Tool") then
        tool.Activated:Connect(function()
            if States.SilentAim and States.CurrentTarget then
                FireSilentEvent(States.CurrentTarget)
            end
        end)
    end
end)

-- ========================================
-- UI作成 (Rayfield)
-- ========================================
local Window = Rayfield:CreateWindow({
    Name = "⚡ Silent Aim V3 | COMPLETE",
    LoadingTitle = "Loading Silent Aim V3...",
    ConfigurationSaving = { Enabled = true, FolderName = "SilentAimV3" }
})

local Tab = Window:CreateTab("🎯 Main", 4483362458)

Tab:CreateToggle({
    Name = "Silent Aim Enable",
    CurrentValue = false,
    Callback = function(Value)
        States.SilentAim = Value
    end,
})

Tab:CreateSlider({
    Name = "FOV Radius",
    Range = {50, 1000},
    Increment = 10,
    CurrentValue = 200,
    Callback = function(Value)
        SilentSettings.FOVRadius = Value
    end,
})

Tab:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "UpperTorso", "HumanoidRootPart"},
    CurrentOption = "Head",
    Callback = function(Option)
        SilentSettings.TargetPart = Option
    end,
})

Tab:CreateToggle({
    Name = "Prediction (未来予測)",
    CurrentValue = true,
    Callback = function(Value)
        SilentSettings.Prediction = Value
    end,
})

Tab:CreateToggle({
    Name = "Visible Check (壁越し除外)",
    CurrentValue = true,
    Callback = function(Value)
        SilentSettings.VisibleCheck = Value
    end,
})

Rayfield:Notify({
    Title = "Script Loaded",
    Content = "Sniper FPS Arena向け完全版サイレントエイムが起動しました",
    Duration = 5
})
