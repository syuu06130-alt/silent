-- ==========================================
-- FPS Flick | Ultimate V3 (Rayfield UI Fixed)
-- ==========================================

-- 1. Rayfield UIの読み込み
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- 2. メインウィンドウの作成
local Window = Rayfield:CreateWindow({
    Name = "FPS Flick | Ultimate V3",
    LoadingTitle = "システム起動中...",
    LoadingSubtitle = "モジュールをロードしています",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "FlickUltimate",
        FileName = "ConfigV3"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false,
})

-- ==========================================
-- サービスと変数の定義
-- ==========================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- 設定テーブル
local Settings = {
    -- Silent Aim
    AimEnabled = false,
    AimFOV = 200,
    AimPart = "Head",
    AimTeamCheck = true,
    AimPrediction = true,
    AimPredAmount = 0.13,
    
    -- ESP
    ESPEnabled = false,
    ESPBoxes = false,
    ESPTracers = false,
    ESPNames = false,
    ESPTeamCheck = true,
    
    -- Triggerbot
    TriggerEnabled = false,
    TriggerDelay = 0.1,
    TriggerTeamCheck = true
}

-- 描画オブジェクト用テーブル
local ESPObjects = {}
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 50
FOVCircle.Filled = false
FOVCircle.Transparency = 0.5
FOVCircle.Visible = false
FOVCircle.Color = Color3.fromRGB(255, 255, 255)

-- ==========================================
-- UIタブの作成
-- ==========================================

-- 【タブ1】メイン (サイレントエイム & トリガーボット)
local MainTab = Window:CreateTab("🎯 メイン", 4483362458) -- アイコンID

local SectionAim = MainTab:CreateSection("サイレントエイム設定")

MainTab:CreateToggle({
    Name = "サイレントエイム有効化",
    CurrentValue = false,
    Flag = "AimToggle",
    Callback = function(Value)
        Settings.AimEnabled = Value
    end,
})

MainTab:CreateSlider({
    Name = "FOV (視野角)",
    Range = {0, 500},
    Increment = 10,
    Suffix = " px",
    CurrentValue = 200,
    Flag = "AimFOV",
    Callback = function(Value)
        Settings.AimFOV = Value
        FOVCircle.Radius = Value
    end,
})

MainTab:CreateDropdown({
    Name = "ターゲット部位",
    Options = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
    CurrentOption = {"Head"},
    Flag = "AimPart",
    Callback = function(Option)
        Settings.AimPart = Option[1]
    end,
})

local SectionTrigger = MainTab:CreateSection("トリガーボット")

MainTab:CreateToggle({
    Name = "トリガーボット有効化",
    CurrentValue = false,
    Flag = "TriggerToggle",
    Callback = function(Value)
        Settings.TriggerEnabled = Value
    end,
})

MainTab:CreateSlider({
    Name = "発射遅延 (秒)",
    Range = {0.01, 1.0},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = 0.1,
    Flag = "TriggerDelay",
    Callback = function(Value)
        Settings.TriggerDelay = Value
    end,
})

-- 【タブ2】ビジュアル (ESP & FOV)
local VisualTab = Window:CreateTab("👁️ ビジュアル", 4483362458)

local SectionFOV = VisualTab:CreateSection("FOV表示設定")

VisualTab:CreateToggle({
    Name = "FOVサークル表示",
    CurrentValue = false,
    Flag = "ShowFOV",
    Callback = function(Value)
        FOVCircle.Visible = Value
    end,
})

VisualTab:CreateColorPicker({
    Name = "FOVカラー",
    Color = Color3.fromRGB(255, 255, 255),
    Flag = "FOVColor",
    Callback = function(Value)
        FOVCircle.Color = Value
    end
})

local SectionESP = VisualTab:CreateSection("ESP (視覚補助)")

VisualTab:CreateToggle({
    Name = "ESP全般有効化",
    CurrentValue = false,
    Flag = "ESPEnabled",
    Callback = function(Value)
        Settings.ESPEnabled = Value
        -- オフにする時に全ての描画を消す
        if not Value then
            for _, v in pairs(ESPObjects) do
                for _, drawing in pairs(v) do
                    drawing:Remove()
                end
            end
            ESPObjects = {}
        end
    end,
})

VisualTab:CreateToggle({
    Name = "ボックス (2D Box)",
    CurrentValue = false,
    Flag = "ESPBoxes",
    Callback = function(Value) Settings.ESPBoxes = Value end,
})

VisualTab:CreateToggle({
    Name = "トレーサー (線)",
    CurrentValue = false,
    Flag = "ESPTracers",
    Callback = function(Value) Settings.ESPTracers = Value end,
})

VisualTab:CreateToggle({
    Name = "ネームタグ",
    CurrentValue = false,
    Flag = "ESPNames",
    Callback = function(Value) Settings.ESPNames = Value end,
})

VisualTab:CreateColorPicker({
    Name = "ESPカラー",
    Color = Color3.fromRGB(255, 0, 0),
    Flag = "ESPColor",
    Callback = function(Value)
        -- リアルタイムで色を変更する場合はここにロジックを追加
        -- 今回は簡易化のため、次回更新時または再描画時に適用されます
    end
})

-- 【タブ3】設定
local SettingsTab = Window:CreateTab("⚙️ 設定", 4483362458)

SettingsTab:CreateToggle({
    Name = "チームチェック (AIM/ESP共通)",
    CurrentValue = true,
    Flag = "TeamCheck",
    Callback = function(Value)
        Settings.AimTeamCheck = Value
        Settings.ESPTeamCheck = Value
        Settings.TriggerTeamCheck = Value
    end,
})

-- ==========================================
-- コア機能の実装
-- ==========================================

-- ヘルパー関数
local function GetDistance(Pos1, Pos2)
    return (Pos1 - Pos2).Magnitude
end

local function WorldToScreen(Position)
    local ScreenPos, OnScreen = Camera:WorldToViewportPoint(Position)
    return Vector2.new(ScreenPos.X, ScreenPos.Y), OnScreen
end

-- ターゲット取得
local function GetClosestPlayer()
    local ClosestPlayer = nil
    local ShortestDistance = Settings.AimFOV
    local MousePos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer then continue end
        if not Player.Character then continue end
        if not Player.Character:FindFirstChild("HumanoidRootPart") then continue end

        -- チームチェック
        if Settings.AimTeamCheck and Player.Team == LocalPlayer.Team then continue end

        local TargetPart = Player.Character:FindFirstChild(Settings.AimPart)
        if not TargetPart then TargetPart = Player.Character.HumanoidRootPart end

        local ScreenPos, OnScreen = WorldToScreen(TargetPart.Position)

        if OnScreen then
            local Distance = (ScreenPos - MousePos).Magnitude
            if Distance < ShortestDistance then
                ClosestPlayer = Player
                ShortestDistance = Distance
            end
        end
    end
    return ClosestPlayer
end

-- ESP描画処理
local function UpdateESP()
    if not Settings.ESPEnabled then return end

    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer then continue end
        if not Player.Character then continue end
        
        -- チームチェック
        if Settings.ESPTeamCheck and Player.Team == LocalPlayer.Team then continue end

        local Root = Player.Character:FindFirstChild("HumanoidRootPart")
        local Head = Player.Character:FindFirstChild("Head")
        local Humanoid = Player.Character:FindFirstChildOfClass("Humanoid")

        if Root and Head and Humanoid.Health > 0 then
            -- 描画オブジェクトの初期化
            if not ESPObjects[Player] then
                ESPObjects[Player] = {
                    Box = Drawing.new("Square"),
                    Tracer = Drawing.new("Line"),
                    Name = Drawing.new("Text")
                }
            end

            local Drawings = ESPObjects[Player]
            local ScreenPos, OnScreen = WorldToScreen(Root.Position)
            local HeadScreenPos, HeadOnScreen = WorldToScreen(Head.Position + Vector3.new(0, 0.5, 0))

            if OnScreen then
                local Height = math.abs(HeadScreenPos.Y - ScreenPos.Y) * 2
                local Width = Height / 1.8

                -- ボックス
                if Settings.ESPBoxes then
                    Drawings.Box.Size = Vector2.new(Width, Height)
                    Drawings.Box.Position = Vector2.new(ScreenPos.X - Width/2, ScreenPos.Y - Height)
                    Drawings.Box.Color = Color3.fromRGB(255, 50, 50)
                    Drawings.Box.Thickness = 1
                    Drawings.Box.Visible = true
                    Drawings.Box.Transparency = 1
                else
                    Drawings.Box.Visible = false
                end

                -- トレーサー
                if Settings.ESPTracers then
                    Drawings.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    Drawings.Tracer.To = Vector2.new(ScreenPos.X, ScreenPos.Y)
                    Drawings.Tracer.Color = Color3.fromRGB(255, 255, 255)
                    Drawings.Tracer.Thickness = 1
                    Drawings.Tracer.Visible = true
                    Drawings.Tracer.Transparency = 1
                else
                    Drawings.Tracer.Visible = false
                end

                -- ネームタグ
                if Settings.ESPNames then
                    local Dist = math.floor(GetDistance(Camera.CFrame.Position, Root.Position))
                    Drawings.Name.Text = Player.Name .. " ["..Dist.."m]"
                    Drawings.Name.Position = Vector2.new(ScreenPos.X, ScreenPos.Y - Height - 15)
                    Drawings.Name.Size = 14
                    Drawings.Name.Center = true
                    Drawings.Name.Outline = true
                    Drawings.Name.Color = Color3.new(1, 1, 1)
                    Drawings.Name.Visible = true
                else
                    Drawings.Name.Visible = false
                end
            else
                for _, v in pairs(Drawings) do v.Visible = false end
            end
        else
            -- プレイヤーが死んだり消えた時のクリーンアップ
            if ESPObjects[Player] then
                for _, v in pairs(ESPObjects[Player]) do v:Remove() end
                ESPObjects[Player] = nil
            end
        end
    end
end

-- トリガーボット処理
local LastTriggerTime = 0
local function UpdateTriggerbot()
    if not Settings.TriggerEnabled then return end
    if tick() - LastTriggerTime < Settings.TriggerDelay then return end

    local Mouse = UserInputService:GetMouseLocation()
    local Ray = Camera:ViewportPointToRay(Mouse.X, Mouse.Y)
    local RaycastParams = RaycastParams.new()
    RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
    RaycastParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}

    local Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 1000, RaycastParams)

    if Result and Result.Instance then
        local Char = Result.Instance:FindFirstAncestorOfClass("Model")
        local Plr = Players:GetPlayerFromCharacter(Char)

        if Plr and Plr ~= LocalPlayer then
            if Settings.TriggerTeamCheck and Plr.Team == LocalPlayer.Team then return end
            
            -- 発射
            mouse1press()
            wait(0.05)
            mouse1release()
            
            LastTriggerTime = tick()
        end
    end
end

-- ==========================================
-- Metatable Hook (Silent Aim)
-- ==========================================
local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local Method = getnamecallmethod()
    local Args = {...}

    if Method == "FireServer" and Settings.AimEnabled then
        if tostring(self):find("MainEvent") or tostring(self):find("Fire") or tostring(self):find("Shoot") then
            local Target = GetClosestPlayer()
            
            if Target and Target.Character then
                local TargetPart = Target.Character:FindFirstChild(Settings.AimPart) or Target.Character.HumanoidRootPart
                if TargetPart then
                    local Pos = TargetPart.Position
                    
                    if Settings.AimPrediction then
                        local Vel = Target.Character.HumanoidRootPart.Velocity
                        Pos = Pos + (Vel * Settings.AimPredAmount)
                    end
                    
                    Args[2] = Pos -- 座標書き換え
                end
            end
        end
    end

    return OldNamecall(self, unpack(Args))
end)

-- ==========================================
-- ループ処理
-- ==========================================
RunService.RenderStepped:Connect(function()
    -- FOVサークル位置更新
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    -- ESP更新
    UpdateESP()
    
    -- トリガーボット更新
    UpdateTriggerbot()
end)

-- 設定の読み込み
Rayfield:LoadConfiguration()
```
