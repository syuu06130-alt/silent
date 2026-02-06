-- Rayfield UI + Silent Aim Module for [FPS] フリック
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "FPS フリック | Silent Aim",
   LoadingTitle = "Silent Aim Loading...",
   LoadingSubtitle = "by Script",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = nil,
      FileName = "FlickSilentAim"
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
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Silent Aim Configuration
local SilentAim = {
    Enabled = false,
    FOV = 150,
    TargetPart = "Head",
    TeamCheck = true,
    VisibleCheck = true,
    Prediction = true,
    PredictionAmount = 0.1
}

-- Main Tab
local MainTab = Window:CreateTab("🎯 Main", 4483362458)
local Section1 = MainTab:CreateSection("Silent Aim Settings")

-- Silent Aim Toggle
local SilentAimToggle = MainTab:CreateToggle({
   Name = "Silent Aim",
   CurrentValue = false,
   Flag = "SilentAimToggle",
   Callback = function(Value)
      SilentAim.Enabled = Value
      if Value then
         Rayfield:Notify({
            Title = "Silent Aim",
            Content = "有効化されました",
            Duration = 3,
            Image = 4483362458,
         })
      else
         Rayfield:Notify({
            Title = "Silent Aim",
            Content = "無効化されました",
            Duration = 3,
            Image = 4483362458,
         })
      end
   end,
})

-- FOV Slider
local FOVSlider = MainTab:CreateSlider({
   Name = "FOV (視野角)",
   Range = {10, 500},
   Increment = 10,
   Suffix = "px",
   CurrentValue = 150,
   Flag = "FOVSlider",
   Callback = function(Value)
      SilentAim.FOV = Value
   end,
})

-- Target Part Dropdown
local TargetPartDropdown = MainTab:CreateDropdown({
   Name = "狙う部位",
   Options = {"Head", "UpperTorso", "HumanoidRootPart", "LowerTorso"},
   CurrentOption = {"Head"},
   MultipleOptions = false,
   Flag = "TargetPartDropdown",
   Callback = function(Option)
      SilentAim.TargetPart = Option[1]
   end,
})

-- Settings Section
local Section2 = MainTab:CreateSection("追加設定")

-- Team Check Toggle
local TeamCheckToggle = MainTab:CreateToggle({
   Name = "チームチェック",
   CurrentValue = true,
   Flag = "TeamCheckToggle",
   Callback = function(Value)
      SilentAim.TeamCheck = Value
   end,
})

-- Visible Check Toggle
local VisibleCheckToggle = MainTab:CreateToggle({
   Name = "視界チェック",
   CurrentValue = true,
   Flag = "VisibleCheckToggle",
   Callback = function(Value)
      SilentAim.VisibleCheck = Value
   end,
})

-- Prediction Toggle
local PredictionToggle = MainTab:CreateToggle({
   Name = "移動予測",
   CurrentValue = true,
   Flag = "PredictionToggle",
   Callback = function(Value)
      SilentAim.Prediction = Value
   end,
})

-- Prediction Amount Slider
local PredictionSlider = MainTab:CreateSlider({
   Name = "予測量",
   Range = {0, 0.5},
   Increment = 0.01,
   Suffix = "s",
   CurrentValue = 0.1,
   Flag = "PredictionSlider",
   Callback = function(Value)
      SilentAim.PredictionAmount = Value
   end,
})

-- Visual Tab (FOV Circle)
local VisualTab = Window:CreateTab("👁️ Visual", 4483362458)
local Section3 = VisualTab:CreateSection("FOV Circle")

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.NumSides = 50
FOVCircle.Radius = SilentAim.FOV
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

-- Update FOV Circle
RunService.RenderStepped:Connect(function()
   if FOVCircle.Visible then
      FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
      FOVCircle.Radius = SilentAim.FOV
   end
end)

-- Get Closest Player Function
local function getClosestPlayerToMouse()
    local closestPlayer = nil
    local shortestDistance = SilentAim.FOV
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if SilentAim.TeamCheck and player.Team == LocalPlayer.Team then continue end
            
            local character = player.Character
            local targetPart = character:FindFirstChild(SilentAim.TargetPart) or character.HumanoidRootPart
            local screenPoint, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            
            if onScreen then
                local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)).Magnitude
                
                if distance < shortestDistance then
                    if SilentAim.VisibleCheck then
                        local ray = Workspace:Raycast(Camera.CFrame.Position, (targetPart.Position - Camera.CFrame.Position).Unit * 1000)
                        if ray and ray.Instance:IsDescendantOf(character) then
                            closestPlayer = player
                            shortestDistance = distance
                        end
                    else
                        closestPlayer = player
                        shortestDistance = distance
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

-- Hook Namecall (FireServer)
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    
    if method == "FireServer" and (self.Name:find("Fire") or self.Name:find("Shoot")) then
        if SilentAim.Enabled then
            local targetPlayer = getClosestPlayerToMouse()
            if targetPlayer and targetPlayer.Character then
                local targetPart = targetPlayer.Character:FindFirstChild(SilentAim.TargetPart)
                if targetPart then
                    local targetPos = targetPart.Position
                    
                    if SilentAim.Prediction then
                        local velocity = targetPlayer.Character.HumanoidRootPart.Velocity
                        targetPos = targetPos + (velocity * SilentAim.PredictionAmount)
                    end
                    
                    args[2] = targetPos
                end
            end
        end
    end
    
    return oldNamecall(self, unpack(args))
end)

setreadonly(mt, true)

-- Info Tab
local InfoTab = Window:CreateTab("ℹ️ Info", 4483362458)
local Section4 = InfoTab:CreateSection("使い方")

InfoTab:CreateParagraph({
   Title = "Silent Aim とは？",
   Content = "自動的に最も近い敵にエイムを補正する機能です。視野角内の敵を自動でターゲットします。"
})

InfoTab:CreateParagraph({
   Title = "設定説明",
   Content = "• FOV: ターゲット検出範囲\n• 狙う部位: ヘッド推奨\n• チームチェック: 味方を除外\n• 視界チェック: 壁越しを除外\n• 移動予測: 動く敵への補正"
})

InfoTab:CreateButton({
   Name = "UIを再読み込み",
   Callback = function()
      Rayfield:Destroy()
      loadstring(game:HttpGet('https://raw.githubusercontent.com/your-script-url'))()
   end,
})

Rayfield:LoadConfiguration()

print("Silent Aim UI loaded for [FPS] フリック")
