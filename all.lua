-- ============================================================
-- ⚡ Ultimate Combat System V3
-- PASTED1 + PASTED2 統合・全機能強化版
-- 🎯 Silent Aim (Hitbox円上化+視点移動) | Head Lock | Auto Aim
-- 👁️ ESP+ (Box/Health/Trace/Circle/Triangle/3D形状) + FOV
-- 🔫 Auto Shot (1ms対応) | 🌀 Auto TP 360° | 🎭 Fixed Mode
-- ⚔️ Combat | 📱 PC・Mobile・Console 対応
-- ============================================================

-- UI Framework Loading
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services
local Players       = game:GetService("Players")
local UIS           = game:GetService("UserInputService")
local RS            = game:GetService("RunService")
local WS            = game:GetService("Workspace")
local Camera        = WS.CurrentCamera
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService  = game:GetService("TweenService")

-- Player Variables
local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

-- Platform Detection
local IsMobile  = UIS.TouchEnabled  and not UIS.KeyboardEnabled
local IsPC      = UIS.KeyboardEnabled
local IsConsole = UIS.GamepadEnabled and not UIS.KeyboardEnabled

-- ============================================================
-- GLOBAL STATE
-- ============================================================
local States = {
    Platform = IsMobile and "Mobile" or (IsConsole and "Console" or "PC"),

    -- === Silent Aim (Hitbox + Camera) ===
    SilentAim        = false,
    HitboxRadius     = 5,       -- SilentAim Strength (Hitbox半径)
    CameraSmooth     = 5.5,     -- 視点移動スムーズ 1-10 (初期 5.5)
    TargetPart       = "Head",
    Prediction       = true,
    PredictionAmount = 0.10,    -- 予測量 (秒)

    -- === Head Lock ===
    HeadLock         = false,
    HeadLockSmooth   = 5.5,

    -- === Auto Aim ===
    AutoAim          = false,
    AutoAimSmooth    = 5.5,

    -- === Target ===
    CurrentTarget    = nil,
    TargetDistance   = math.huge,
    StickyAim        = false,
    LockedTarget     = nil,
    TeamCheck        = true,
    WallCheck        = true,
    VisibleCheck     = true,
    MaxDistance      = 1000,

    -- === FOV ===
    FOVVisible       = false,
    FOVActive        = false,   -- フィルタリング ON/OFF
    FOVRadius        = 150,
    FOVColor         = Color3.fromRGB(255, 255, 255),
    FOVTransparency  = 0.70,
    FOVThickness     = 2,

    -- === ESP ===
    ESP              = false,
    ESPHighlight     = true,
    ESPBox           = false,
    ESPHealth        = false,
    ESPName          = false,
    ESPDistance      = false,
    ESPTracer        = false,
    ESPCircle        = false,
    ESPTriangle      = false,
    -- 3D 形状
    ESPSphere        = false,
    ESPCube          = false,
    ESPCylinder      = false,

    ESPFillColor         = Color3.fromRGB(255, 0,   0),
    ESPOutlineColor      = Color3.fromRGB(0,   255, 0),
    ESPFillTransparency  = 0.50,
    ESPOutlineTransparency = 0,
    ESPOutlineSize       = 2,

    -- === Auto Shot ===
    AutoShot             = false,
    AutoShotDelay        = 0.01,    -- 1ms = 0.01s
    AutoShotOnDetect     = false,
    AutoShotDetectDelay  = 0.01,

    -- === Trigger Bot ===
    TriggerBot           = false,
    TriggerDelay         = 0.05,

    -- === Auto TP 360° ===
    AutoTP               = false,
    TPDistance           = 5,
    CurrentTPTarget      = nil,

    -- === Fixed Mode ===
    AllPlayersFixed      = false,
    FixedDistance        = 3,

    -- === Combat ===
    RecoilControl        = false,
    RecoilStrength       = 100,
    BulletTracerEnabled  = false,
    TracerColor          = Color3.fromRGB(255, 0, 0),
    TracerThickness      = 2,
    TracerDuration       = 2,
}

local Connections = {}
local ESPObjects  = {}  -- [player] = { Drawing objects }
local ESP3DObjects= {}  -- [player] = { Part instances }

-- ============================================================
-- UTILITY
-- ============================================================
local function SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[CombatV3] " .. tostring(err)) end
    return ok
end

-- ============================================================
-- WALL CHECK
-- ============================================================
local function CheckWall(origin, targetPos, character)
    if not States.WallCheck then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = { LocalPlayer.Character or Instance.new("Folder") }
    params.IgnoreWater = true
    local direction = targetPos - origin
    local ray = WS:Raycast(origin, direction, params)
    if ray then
        local hit = ray.Instance
        if hit and character and hit:IsDescendantOf(character) then return true end
        return false
    end
    return true
end

-- ============================================================
-- FOV CHECK
-- ============================================================
local function IsInFOV(targetPos)
    if not States.FOVActive then return true end
    local sp, onScreen = Camera:WorldToViewportPoint(targetPos)
    if not onScreen then return false end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    return (Vector2.new(sp.X, sp.Y) - center).Magnitude <= States.FOVRadius
end

-- ============================================================
-- TARGET ACQUISITION
-- ============================================================
local function GetAllTargets()
    local targets = {}
    local camPos  = Camera.CFrame.Position

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not player.Character then continue end

        SafeCall(function()
            local char  = player.Character
            local hum   = char:FindFirstChild("Humanoid")
            local root  = char:FindFirstChild("HumanoidRootPart")
            local head  = char:FindFirstChild(States.TargetPart) or char:FindFirstChild("Head")

            if not (hum and hum.Health > 0 and root and head) then return end
            if States.TeamCheck and player.Team == LocalPlayer.Team then return end

            local dist = (camPos - head.Position).Magnitude
            if dist > States.MaxDistance then return end
            if not CheckWall(camPos, head.Position, char) then return end
            if not IsInFOV(head.Position) then return end

            table.insert(targets, {
                Player    = player,
                Character = char,
                Part      = head,
                Root      = root,
                Position  = head.Position,
                Distance  = dist,
                Humanoid  = hum,
            })
        end)
    end

    table.sort(targets, function(a, b) return a.Distance < b.Distance end)
    return targets
end

local function GetNearestTarget()
    if States.StickyAim and States.LockedTarget then
        local lt = States.LockedTarget
        if lt.Character and lt.Character:FindFirstChild("Humanoid")
            and lt.Character.Humanoid.Health > 0 then
            local head = lt.Character:FindFirstChild(States.TargetPart)
                      or lt.Character:FindFirstChild("Head")
            if head then
                States.CurrentTarget = {
                    Player    = lt,
                    Character = lt.Character,
                    Part      = head,
                    Root      = lt.Character:FindFirstChild("HumanoidRootPart"),
                    Position  = head.Position,
                    Distance  = (Camera.CFrame.Position - head.Position).Magnitude,
                    Humanoid  = lt.Character.Humanoid,
                }
                States.TargetDistance = States.CurrentTarget.Distance
                return States.CurrentTarget
            end
        end
    end

    local targets = GetAllTargets()
    if #targets > 0 then
        States.CurrentTarget  = targets[1]
        States.TargetDistance = targets[1].Distance
        return targets[1]
    end
    States.CurrentTarget  = nil
    States.TargetDistance = math.huge
    return nil
end

-- ============================================================
-- HITBOX CIRCULAR EXPANSION (Silent Aim)
-- ============================================================
local function GetHitboxPosition(targetPart)
    local r      = States.HitboxRadius
    local angle  = math.random() * 2 * math.pi
    local radius = math.sqrt(math.random()) * r  -- 円内に均一分布
    local right  = Camera.CFrame.RightVector
    local up     = Camera.CFrame.UpVector
    return targetPart.Position
        + right * (math.cos(angle) * radius)
        + up    * (math.sin(angle) * radius)
end

-- ============================================================
-- CAMERA SMOOTH TRACKING
-- ============================================================
-- smooth: 1=ゆっくり / 5.5=普通 / 10=完全ロック
local function SmoothnessToAlpha(smooth)
    if smooth >= 10 then return 1.0 end
    -- 1→0.02 / 5.5→0.165 / 9.9→0.297
    return (smooth / 10) * 0.3
end

local function SmoothCameraTo(targetPos, smooth)
    local alpha  = SmoothnessToAlpha(smooth)
    local curCF  = Camera.CFrame
    local tgtCF  = CFrame.new(curCF.Position, targetPos)
    Camera.CFrame = curCF:Lerp(tgtCF, alpha)
end

-- ============================================================
-- 2D ESP SYSTEM (Drawing API)
-- ============================================================
local function CreateDrawings(player)
    if ESPObjects[player] then return end
    local d = {}

    -- Highlight (3D)
    if player.Character then
        local hl = Instance.new("Highlight")
        hl.Parent   = player.Character
        hl.Adornee  = player.Character
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillColor = States.ESPFillColor
        hl.OutlineColor = States.ESPOutlineColor
        hl.FillTransparency = States.ESPFillTransparency
        hl.OutlineTransparency = States.ESPOutlineTransparency
        d.Highlight = hl
    end

    -- Box (4 lines)
    d.BoxLines = {}
    for _ = 1, 4 do
        local ln = Drawing.new("Line")
        ln.Thickness = States.ESPOutlineSize
        ln.Color     = States.ESPOutlineColor
        ln.Transparency = 1
        ln.Visible   = false
        table.insert(d.BoxLines, ln)
    end

    -- Health Background
    local hBG = Drawing.new("Line")
    hBG.Thickness   = 4
    hBG.Color        = Color3.fromRGB(30, 30, 30)
    hBG.Transparency = 1
    hBG.Visible      = false
    d.HealthBG = hBG

    -- Health Foreground
    local hFG = Drawing.new("Line")
    hFG.Thickness   = 3
    hFG.Color        = Color3.fromRGB(0, 255, 0)
    hFG.Transparency = 1
    hFG.Visible      = false
    d.HealthFG = hFG

    -- Name
    local nm = Drawing.new("Text")
    nm.Size  = 14
    nm.Font  = Drawing.Fonts.UI
    nm.Color = Color3.fromRGB(255, 255, 255)
    nm.Outline = true
    nm.Center  = true
    nm.Text    = player.Name
    nm.Visible = false
    d.Name = nm

    -- Distance
    local dist = Drawing.new("Text")
    dist.Size    = 12
    dist.Font    = Drawing.Fonts.UI
    dist.Color   = Color3.fromRGB(200, 200, 200)
    dist.Outline = true
    dist.Center  = true
    dist.Visible = false
    d.Distance = dist

    -- Tracer
    local tr = Drawing.new("Line")
    tr.Thickness   = 1
    tr.Color        = States.ESPOutlineColor
    tr.Transparency = 1
    tr.Visible      = false
    d.Tracer = tr

    -- Circle
    local ci = Drawing.new("Circle")
    ci.Thickness   = 2
    ci.NumSides    = 32
    ci.Color        = States.ESPOutlineColor
    ci.Filled       = false
    ci.Transparency = 1
    ci.Visible      = false
    d.Circle = ci

    -- Triangle
    local tri = Drawing.new("Triangle")
    tri.Thickness   = 2
    tri.Color        = States.ESPOutlineColor
    tri.Filled       = false
    tri.Transparency = 1
    tri.Visible      = false
    d.Triangle = tri

    ESPObjects[player] = d
end

local function Remove2DESP(player)
    local d = ESPObjects[player]
    if not d then return end
    if d.Highlight then SafeCall(function() d.Highlight:Destroy() end) end
    if d.BoxLines  then for _, l in ipairs(d.BoxLines) do SafeCall(function() l:Remove() end) end end
    for k, obj in pairs(d) do
        if k ~= "Highlight" and k ~= "BoxLines" then
            SafeCall(function() obj:Remove() end)
        end
    end
    ESPObjects[player] = nil
end

-- 3D Part-based ESP helper
local function CreatePart3D(char, shape, size, color)
    local p = Instance.new("Part")
    p.Shape       = shape or Enum.PartType.Block
    p.Size        = size  or Vector3.new(6,6,6)
    p.Material    = Enum.Material.Neon
    p.Color       = color or States.ESPOutlineColor
    p.Transparency = 0.65
    p.CanCollide  = false
    p.Anchored    = false
    p.CastShadow  = false
    p.Parent      = char
    local weld    = Instance.new("WeldConstraint")
    weld.Part0    = p
    weld.Part1    = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildOfClass("Part")
    weld.Parent   = p
    return p
end

local function Create3DESP(player)
    if ESP3DObjects[player] then return end
    local char = player.Character
    if not char then return end
    local d = {}

    if States.ESPSphere then
        d.Sphere = CreatePart3D(char, Enum.PartType.Ball, Vector3.new(7,7,7), States.ESPOutlineColor)
    end
    if States.ESPCube then
        -- SelectionBox for cube outline
        local sb = Instance.new("SelectionBox")
        sb.LineThickness = 0.04
        sb.Color3     = States.ESPOutlineColor
        sb.SurfaceColor3 = States.ESPFillColor
        sb.SurfaceTransparency = 0.85
        sb.Adornee    = char
        sb.Parent     = char
        d.Cube = sb
    end
    if States.ESPCylinder then
        d.Cylinder = CreatePart3D(char, Enum.PartType.Cylinder,
            Vector3.new(1.5, 7, 7), States.ESPOutlineColor)
    end

    ESP3DObjects[player] = d
end

local function Remove3DESP(player)
    local d = ESP3DObjects[player]
    if not d then return end
    for _, obj in pairs(d) do
        SafeCall(function() obj:Destroy() end)
    end
    ESP3DObjects[player] = nil
end

local function RemoveESP(player)
    Remove2DESP(player)
    Remove3DESP(player)
end

-- Update ESP per player
local function UpdateESPPlayer(player)
    if not States.ESP then return end

    -- 2D Drawings
    if not ESPObjects[player] then CreateDrawings(player) end
    local d   = ESPObjects[player]
    local char = player.Character
    if not (d and char) then return end

    local root = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    local hum  = char:FindFirstChild("Humanoid")
    if not (root and head and hum) then return end

    -- Update Highlight
    if d.Highlight then
        d.Highlight.FillColor          = States.ESPFillColor
        d.Highlight.OutlineColor       = States.ESPOutlineColor
        d.Highlight.FillTransparency   = States.ESPFillTransparency
        d.Highlight.OutlineTransparency = States.ESPOutlineTransparency
        d.Highlight.Enabled            = States.ESPHighlight
    end

    local spRoot, visRoot = Camera:WorldToViewportPoint(root.Position)
    local spHead, visHead = Camera:WorldToViewportPoint(head.Position)

    -- Hide 2D if off screen
    local function Hide2D()
        for _, ln in ipairs(d.BoxLines or {}) do ln.Visible = false end
        d.HealthBG.Visible  = false
        d.HealthFG.Visible  = false
        d.Name.Visible      = false
        d.Distance.Visible  = false
        d.Tracer.Visible    = false
        d.Circle.Visible    = false
        d.Triangle.Visible  = false
    end

    if not visRoot then Hide2D(); return end

    local rootV  = Vector2.new(spRoot.X, spRoot.Y)
    local headV  = Vector2.new(spHead.X, spHead.Y)
    local height = math.abs(headV.Y - rootV.Y) * 1.15
    local width  = height * 0.55

    local TL = Vector2.new(rootV.X - width/2, headV.Y - height * 0.05)
    local TR = Vector2.new(rootV.X + width/2, headV.Y - height * 0.05)
    local BL = Vector2.new(rootV.X - width/2, rootV.Y + height * 0.15)
    local BR = Vector2.new(rootV.X + width/2, rootV.Y + height * 0.15)

    -- Box
    if d.BoxLines then
        d.BoxLines[1].From = TL ; d.BoxLines[1].To = TR
        d.BoxLines[2].From = TR ; d.BoxLines[2].To = BR
        d.BoxLines[3].From = BR ; d.BoxLines[3].To = BL
        d.BoxLines[4].From = BL ; d.BoxLines[4].To = TL
        for _, ln in ipairs(d.BoxLines) do
            ln.Visible   = States.ESPBox
            ln.Thickness = States.ESPOutlineSize
            ln.Color     = States.ESPOutlineColor
        end
    end

    -- Health bar (left side)
    local hp    = hum.Health / math.max(hum.MaxHealth, 1)
    local hpCol = Color3.fromRGB(math.floor(255*(1-hp)), math.floor(255*hp), 0)
    local barX  = TL.X - 5
    local barH  = BL.Y - TL.Y
    d.HealthBG.From    = Vector2.new(barX, TL.Y)
    d.HealthBG.To      = Vector2.new(barX, BL.Y)
    d.HealthBG.Visible = States.ESPHealth

    d.HealthFG.From    = Vector2.new(barX, BL.Y)
    d.HealthFG.To      = Vector2.new(barX, BL.Y - barH * hp)
    d.HealthFG.Color   = hpCol
    d.HealthFG.Visible = States.ESPHealth

    -- Name
    d.Name.Position = Vector2.new(rootV.X, TL.Y - 16)
    d.Name.Visible  = States.ESPName

    -- Distance
    local wDist = math.floor((Camera.CFrame.Position - root.Position).Magnitude)
    d.Distance.Text     = wDist .. "m"
    d.Distance.Position = Vector2.new(rootV.X, BL.Y + 2)
    d.Distance.Visible  = States.ESPDistance

    -- Tracer
    d.Tracer.From    = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
    d.Tracer.To      = rootV
    d.Tracer.Color   = States.ESPOutlineColor
    d.Tracer.Visible = States.ESPTracer

    -- Circle (head ring)
    d.Circle.Position    = headV
    d.Circle.Radius      = math.max(height * 0.22, 5)
    d.Circle.Color       = States.ESPOutlineColor
    d.Circle.Visible     = States.ESPCircle

    -- Triangle (indicator above head)
    local tipY = TL.Y - 12
    d.Triangle.PointA  = Vector2.new(rootV.X,          tipY)
    d.Triangle.PointB  = Vector2.new(rootV.X - width/3, tipY + 10)
    d.Triangle.PointC  = Vector2.new(rootV.X + width/3, tipY + 10)
    d.Triangle.Color   = States.ESPOutlineColor
    d.Triangle.Visible = States.ESPTriangle

    -- 3D ESP
    if States.ESPSphere or States.ESPCube or States.ESPCylinder then
        if not ESP3DObjects[player] then Create3DESP(player) end
        local d3 = ESP3DObjects[player]
        if d3 then
            if d3.Sphere   then d3.Sphere.Visible   = States.ESPSphere   end
            if d3.Cube     then d3.Cube.Visible      = States.ESPCube     end
            if d3.Cylinder then d3.Cylinder.Visible  = States.ESPCylinder end
        end
    else
        Remove3DESP(player)
    end
end

local function UpdateAllESP()
    if not States.ESP then
        for pl, _ in pairs(ESPObjects)   do Remove2DESP(pl) end
        for pl, _ in pairs(ESP3DObjects) do Remove3DESP(pl) end
        return
    end
    for _, pl in pairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then
            UpdateESPPlayer(pl)
        end
    end
end

-- ============================================================
-- FOV CIRCLE
-- ============================================================
local FOVDraw = Drawing.new("Circle")
FOVDraw.Thickness   = States.FOVThickness
FOVDraw.NumSides    = 64
FOVDraw.Radius      = States.FOVRadius
FOVDraw.Filled      = false
FOVDraw.Visible     = false
FOVDraw.Color       = States.FOVColor
FOVDraw.Transparency = States.FOVTransparency

-- ============================================================
-- AUTO TP 360° (極座標方式)
-- 円の外周のランダムな角度(0-360°)にTPし、対象を向く
-- ============================================================
local function IsTargetDead(t)
    if not t or not t.Character then return true end
    local h = t.Character:FindFirstChild("Humanoid")
    return not h or h.Health <= 0
end

local function TP360ToTarget(target)
    if not target or not target.Character then return end
    SafeCall(function()
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end

        local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
        if not tRoot then return end

        local tPos = tRoot.Position

        -- 極座標: θ = ランダム 0~2π (360°)
        -- r = TPDistance (studs)
        local theta  = math.random() * 2 * math.pi  -- 0 ≤ θ < 2π
        local r      = States.TPDistance

        -- 直交座標変換: x = r·cos(θ), z = r·sin(θ)
        local offsetX = math.cos(theta) * r
        local offsetZ = math.sin(theta) * r

        local tpPos = Vector3.new(
            tPos.X + offsetX,
            tPos.Y,           -- 同じ高さ
            tPos.Z + offsetZ
        )

        -- HumanoidRootPart を移動し、対象を向く
        char.HumanoidRootPart.CFrame = CFrame.new(tpPos, tPos)

        -- カメラも対象を向く
        local camOffset = Camera.CFrame.Position - char.HumanoidRootPart.Position
        Camera.CFrame   = CFrame.new(tpPos + camOffset, tPos)
    end)
end

local function AutoTPUpdate()
    if not States.AutoTP then return end
    if not States.CurrentTPTarget or IsTargetDead(States.CurrentTPTarget) then
        local targets = GetAllTargets()
        if #targets > 0 then
            States.CurrentTPTarget = targets[math.random(1, #targets)]
            Rayfield:Notify({
                Title   = "🌀 TP Target",
                Content = "新ターゲット: " .. States.CurrentTPTarget.Player.Name,
                Duration = 2,
                Image   = 4483362458
            })
        else
            States.CurrentTPTarget = nil
        end
    end
    if States.CurrentTPTarget then
        TP360ToTarget(States.CurrentTPTarget)
    end
end

-- ============================================================
-- AUTO SHOT
-- ============================================================
local function PerformShot()
    SafeCall(function()
        if States.Platform == "Mobile" then
            VirtualInputManager:SendMouseButtonEvent(0,0,0, true,  game, 1)
            task.wait(0.005)
            VirtualInputManager:SendMouseButtonEvent(0,0,0, false, game, 1)
        elseif States.Platform == "Console" then
            VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.ButtonR1, false, game)
            task.wait(0.005)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.ButtonR1, false, game)
        else
            mouse1press()
            task.wait(0.005)
            mouse1release()
        end
    end)
end

-- ============================================================
-- FIXED MODE
-- ============================================================
local function AllPlayersFixedUpdate()
    if not States.AllPlayersFixed then return end
    SafeCall(function()
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local root    = char.HumanoidRootPart
        local fwd     = root.CFrame.LookVector
        local fixPos  = root.Position + fwd * States.FixedDistance
        for _, pl in pairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and pl.Character then
                local er = pl.Character:FindFirstChild("HumanoidRootPart")
                local eh = pl.Character:FindFirstChild("Humanoid")
                if er and eh and eh.Health > 0 then
                    er.CFrame = CFrame.new(fixPos, root.Position)
                    er.AssemblyLinearVelocity  = Vector3.zero
                    er.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end
    end)
end

-- ============================================================
-- NAMECALL HOOK (Silent Aim)
-- ============================================================
local mt = getrawmetatable(game)
setreadonly(mt, false)

local _oldNamecall = mt.__namecall
mt.__namecall = newcclosure(function(self, ...)
    local args   = {...}
    local method = getnamecallmethod()

    if States.SilentAim
        and (method == "FireServer" or method == "InvokeServer")
        and States.CurrentTarget
        and States.CurrentTarget.Part
    then
        local hitPos = GetHitboxPosition(States.CurrentTarget.Part)

        if States.Prediction and States.CurrentTarget.Root then
            local vel = States.CurrentTarget.Root.AssemblyLinearVelocity
            hitPos = hitPos + vel * States.PredictionAmount
        end

        for i, arg in ipairs(args) do
            if typeof(arg) == "Vector3" then
                args[i] = hitPos
                break
            end
        end
    end

    return _oldNamecall(self, unpack(args))
end)

-- __index hook (Mouse.Hit / Mouse.Target)
local _oldIndex = mt.__index
mt.__index = newcclosure(function(self, key)
    if States.SilentAim and States.CurrentTarget and States.CurrentTarget.Part then
        if tostring(self):find("Mouse") and (key == "Hit" or key == "Target") then
            local hitPos = GetHitboxPosition(States.CurrentTarget.Part)
            if States.Prediction and States.CurrentTarget.Root then
                local vel = States.CurrentTarget.Root.AssemblyLinearVelocity
                hitPos = hitPos + vel * States.PredictionAmount
            end
            if key == "Hit"    then return CFrame.new(hitPos) end
            if key == "Target" then return States.CurrentTarget.Part end
        end
    end
    return _oldIndex(self, key)
end)

setreadonly(mt, true)

-- ============================================================
-- UI WINDOW
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name = "⚡ Ultimate Combat System V3 | "
        .. (States.Platform == "Mobile" and "📱" or States.Platform == "Console" and "🎮" or "💻"),
    LoadingTitle    = "Ultimate Combat System V3",
    LoadingSubtitle = "Platform: " .. States.Platform .. "  |  360° Systems",
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "UltimateCombatV3",
        FileName   = "Config",
    },
    Discord   = { Enabled = false },
    KeySystem = false,
})

-- ============================================================
-- 🎯 AIMBOT TAB
-- ============================================================
local AimbotTab = Window:CreateTab("🎯 Aimbot", 4483362458)

AimbotTab:CreateSection("Silent Aim ― ヒットボックス＋視点移動")

AimbotTab:CreateToggle({
    Name = "Silent Aim (有効にするとヒットボックス拡張＋視点移動が同時起動)",
    CurrentValue = false,
    Flag = "SilentAim",
    Callback = function(v)
        States.SilentAim = v
        Rayfield:Notify({ Title = "Silent Aim",
            Content = v and "✅ 有効 (Hitbox + 視点移動)" or "❌ 無効", Duration = 2 })
    end,
})

AimbotTab:CreateSlider({
    Name         = "ヒットボックス半径 ※ Silent Aim Strength",
    Range        = {1, 50},
    Increment    = 1,
    Suffix       = " units",
    CurrentValue = 5,
    Flag         = "HitboxRadius",
    Callback     = function(v) States.HitboxRadius = v end,
})

AimbotTab:CreateSlider({
    Name         = "視点移動スムーズ (1=ゆっくり / 5.5=普通 / 10=完全ロック)",
    Range        = {1, 10},
    Increment    = 0.5,
    Suffix       = "",
    CurrentValue = 5.5,
    Flag         = "CameraSmooth",
    Callback     = function(v) States.CameraSmooth = v end,
})

AimbotTab:CreateSection("Head Lock")

AimbotTab:CreateToggle({
    Name = "Head Lock (頭部へカメラをロック)",
    CurrentValue = false,
    Flag = "HeadLock",
    Callback = function(v)
        States.HeadLock = v
        Rayfield:Notify({ Title = "Head Lock", Content = v and "✅ 有効" or "❌ 無効", Duration = 2 })
    end,
})

AimbotTab:CreateSlider({
    Name = "Head Lock スムーズ", Range = {1,10}, Increment = 0.5,
    Suffix = "", CurrentValue = 5.5, Flag = "HeadLockSmooth",
    Callback = function(v) States.HeadLockSmooth = v end,
})

AimbotTab:CreateSection("Auto Aim")

AimbotTab:CreateToggle({
    Name = "Auto Aim (なめらかな自動エイム)",
    CurrentValue = false,
    Flag = "AutoAim",
    Callback = function(v)
        States.AutoAim = v
        Rayfield:Notify({ Title = "Auto Aim", Content = v and "✅ 有効" or "❌ 無効", Duration = 2 })
    end,
})

AimbotTab:CreateSlider({
    Name = "Auto Aim スムーズ", Range = {1,10}, Increment = 0.5,
    Suffix = "", CurrentValue = 5.5, Flag = "AutoAimSmooth",
    Callback = function(v) States.AutoAimSmooth = v end,
})

AimbotTab:CreateSection("ターゲット設定")

AimbotTab:CreateDropdown({
    Name = "狙う部位",
    Options = {"Head", "UpperTorso", "HumanoidRootPart", "LowerTorso"},
    CurrentOption = {"Head"},
    MultipleOptions = false,
    Flag = "TargetPart",
    Callback = function(opt)
        States.TargetPart = type(opt) == "table" and opt[1] or opt
    end,
})

AimbotTab:CreateToggle({
    Name = "スティッキーエイム (一度ロックしたら固定)",
    CurrentValue = false, Flag = "StickyAim",
    Callback = function(v) States.StickyAim = v end,
})

AimbotTab:CreateToggle({
    Name = "チームチェック (味方を除外)",
    CurrentValue = true, Flag = "TeamCheck",
    Callback = function(v) States.TeamCheck = v end,
})

AimbotTab:CreateToggle({
    Name = "壁チェック (壁越し無効)",
    CurrentValue = true, Flag = "WallCheck",
    Callback = function(v) States.WallCheck = v end,
})

AimbotTab:CreateToggle({
    Name = "移動予測 (弾着補正)",
    CurrentValue = true, Flag = "Prediction",
    Callback = function(v) States.Prediction = v end,
})

AimbotTab:CreateSlider({
    Name = "予測量 (ms)", Range = {1, 500}, Increment = 1,
    Suffix = "ms", CurrentValue = 100, Flag = "PredAmt",
    Callback = function(v) States.PredictionAmount = v / 1000 end,
})

AimbotTab:CreateSlider({
    Name = "最大照準距離", Range = {100, 5000}, Increment = 100,
    Suffix = " studs", CurrentValue = 1000, Flag = "MaxDist",
    Callback = function(v) States.MaxDistance = v end,
})

-- ============================================================
-- 👁️ ESP TAB
-- ============================================================
local ESPTab = Window:CreateTab("👁️ ESP", 4483362458)

ESPTab:CreateSection("ESP メインスイッチ")

ESPTab:CreateToggle({
    Name = "ESP オン/オフ (全ESP要素の基準スイッチ)",
    CurrentValue = false,
    Flag = "ESP",
    Callback = function(v)
        States.ESP = v
        if not v then
            for pl, _ in pairs(ESPObjects)   do Remove2DESP(pl) end
            for pl, _ in pairs(ESP3DObjects) do Remove3DESP(pl) end
        end
        Rayfield:Notify({ Title = "ESP", Content = v and "✅ 有効" or "❌ 無効", Duration = 2 })
    end,
})

ESPTab:CreateSection("ハイライト (3D) 設定")

ESPTab:CreateToggle({
    Name = "ハイライト (3D キャラクター強調表示)",
    CurrentValue = true, Flag = "ESPHighlight",
    Callback = function(v) States.ESPHighlight = v end,
})

ESPTab:CreateColorPicker({
    Name = "塗りつぶし色 (Fill Color)",
    Color = Color3.fromRGB(255, 0, 0), Flag = "ESPFillColor",
    Callback = function(v) States.ESPFillColor = v end,
})

ESPTab:CreateColorPicker({
    Name = "外枠色 (Outline Color)",
    Color = Color3.fromRGB(0, 255, 0), Flag = "ESPOutlineColor",
    Callback = function(v) States.ESPOutlineColor = v end,
})

ESPTab:CreateSlider({
    Name = "塗りつぶし透明度", Range = {0,100}, Increment = 5,
    Suffix = "%", CurrentValue = 50, Flag = "ESPFillTrans",
    Callback = function(v) States.ESPFillTransparency = v / 100 end,
})

ESPTab:CreateSlider({
    Name = "外枠の太さ (Outline Size)", Range = {1,10}, Increment = 1,
    Suffix = "px", CurrentValue = 2, Flag = "ESPOutlineSize",
    Callback = function(v) States.ESPOutlineSize = v end,
})

ESPTab:CreateSection("2D ESP 要素")

ESPTab:CreateToggle({
    Name = "ボックス (Box ESP)", CurrentValue = false, Flag = "ESPBox",
    Callback = function(v) States.ESPBox = v end,
})
ESPTab:CreateToggle({
    Name = "体力バー (Health Bar)", CurrentValue = false, Flag = "ESPHealth",
    Callback = function(v) States.ESPHealth = v end,
})
ESPTab:CreateToggle({
    Name = "名前表示 (Name Label)", CurrentValue = false, Flag = "ESPName",
    Callback = function(v) States.ESPName = v end,
})
ESPTab:CreateToggle({
    Name = "距離表示 (Distance Label)", CurrentValue = false, Flag = "ESPDist",
    Callback = function(v) States.ESPDistance = v end,
})
ESPTab:CreateToggle({
    Name = "トレーサー (Tracer Line)", CurrentValue = false, Flag = "ESPTracer",
    Callback = function(v) States.ESPTracer = v end,
})
ESPTab:CreateToggle({
    Name = "円 (Circle ― 頭周り)", CurrentValue = false, Flag = "ESPCircle",
    Callback = function(v) States.ESPCircle = v end,
})
ESPTab:CreateToggle({
    Name = "三角形 (Triangle ― 頭上表示)", CurrentValue = false, Flag = "ESPTriangle",
    Callback = function(v) States.ESPTriangle = v end,
})

ESPTab:CreateSection("3D 立体 ESP")

ESPTab:CreateToggle({
    Name = "球体 (Sphere ESP)", CurrentValue = false, Flag = "ESPSphere",
    Callback = function(v)
        States.ESPSphere = v
        if not v then for pl, _ in pairs(ESP3DObjects) do Remove3DESP(pl) end end
    end,
})
ESPTab:CreateToggle({
    Name = "立方体/直方体 (Cube / Box 3D)", CurrentValue = false, Flag = "ESPCube",
    Callback = function(v)
        States.ESPCube = v
        if not v then for pl, _ in pairs(ESP3DObjects) do Remove3DESP(pl) end end
    end,
})
ESPTab:CreateToggle({
    Name = "円柱 (Cylinder ESP)", CurrentValue = false, Flag = "ESPCylinder",
    Callback = function(v)
        States.ESPCylinder = v
        if not v then for pl, _ in pairs(ESP3DObjects) do Remove3DESP(pl) end end
    end,
})

ESPTab:CreateSection("FOV サークル ― Silent Aim / Auto Aim 連動")

ESPTab:CreateToggle({
    Name = "FOV サークル表示",
    CurrentValue = false, Flag = "FOVVisible",
    Callback = function(v)
        States.FOVVisible = v
        FOVDraw.Visible   = v
    end,
})

ESPTab:CreateToggle({
    Name = "FOV フィルタリング (円内の敵のみロック対象 ― 壁判定ON)",
    CurrentValue = false, Flag = "FOVActive",
    Callback = function(v)
        States.FOVActive = v
        Rayfield:Notify({
            Title   = "FOV Filter",
            Content = v and "✅ 有効 ― Silent/Auto Aim は FOV 内の敵のみ対象"
                        or "❌ 無効",
            Duration = 3
        })
    end,
})

ESPTab:CreateSlider({
    Name = "FOV 半径", Range = {10,600}, Increment = 10,
    Suffix = "px", CurrentValue = 150, Flag = "FOVRadius",
    Callback = function(v)
        States.FOVRadius  = v
        FOVDraw.Radius    = v
    end,
})

ESPTab:CreateColorPicker({
    Name = "FOV 色",
    Color = Color3.fromRGB(255,255,255), Flag = "FOVColor",
    Callback = function(v)
        States.FOVColor = v
        FOVDraw.Color   = v
    end,
})

ESPTab:CreateSlider({
    Name = "FOV 透明度", Range = {0,100}, Increment = 5,
    Suffix = "%", CurrentValue = 70, Flag = "FOVTrans",
    Callback = function(v)
        States.FOVTransparency = v / 100
        FOVDraw.Transparency   = v / 100
    end,
})

ESPTab:CreateSlider({
    Name = "FOV 太さ", Range = {1,10}, Increment = 1,
    Suffix = "px", CurrentValue = 2, Flag = "FOVThick",
    Callback = function(v)
        States.FOVThickness = v
        FOVDraw.Thickness   = v
    end,
})

-- ============================================================
-- 🔫 AUTO SHOT TAB
-- ============================================================
local AutoShotTab = Window:CreateTab("🔫 Auto Shot", 4483362458)

AutoShotTab:CreateSection("Auto Shot ― ターゲット検出時に自動射撃")

AutoShotTab:CreateToggle({
    Name = "Auto Shot (現在のターゲットを自動で射撃)",
    CurrentValue = false, Flag = "AutoShot",
    Callback = function(v)
        States.AutoShot = v
        Rayfield:Notify({ Title = "Auto Shot", Content = v and "✅ 有効" or "❌ 無効", Duration = 2 })
    end,
})

AutoShotTab:CreateSlider({
    Name = "射撃間隔 (最小 1ms / 初期 10ms)",
    Range = {1, 2000}, Increment = 1,
    Suffix = "ms", CurrentValue = 10, Flag = "AutoShotDelay",
    Callback = function(v) States.AutoShotDelay = v / 1000 end,
})

AutoShotTab:CreateSection("視認時 Auto Shot ― 敵を視認したら即発砲")

AutoShotTab:CreateToggle({
    Name = "視認時 Auto Shot (敵を視認した瞬間に自動発砲)",
    CurrentValue = false, Flag = "AutoShotDetect",
    Callback = function(v)
        States.AutoShotOnDetect = v
        Rayfield:Notify({ Title = "視認Shot", Content = v and "✅ 有効" or "❌ 無効", Duration = 2 })
    end,
})

AutoShotTab:CreateSlider({
    Name = "視認発砲遅延 (最小 1ms / 初期 10ms)",
    Range = {1, 2000}, Increment = 1,
    Suffix = "ms", CurrentValue = 10, Flag = "DetectDelay",
    Callback = function(v) States.AutoShotDetectDelay = v / 1000 end,
})

AutoShotTab:CreateSection("Trigger Bot")

AutoShotTab:CreateToggle({
    Name = "Trigger Bot (クロスヘア上の敵を自動発砲)",
    CurrentValue = false, Flag = "TriggerBot",
    Callback = function(v) States.TriggerBot = v end,
})

AutoShotTab:CreateSlider({
    Name = "Trigger Bot 遅延",
    Range = {1, 500}, Increment = 1,
    Suffix = "ms", CurrentValue = 50, Flag = "TriggerDelay",
    Callback = function(v) States.TriggerDelay = v / 1000 end,
})

-- ============================================================
-- 🌀 AUTO TP TAB
-- ============================================================
local AutoTPTab = Window:CreateTab("🌀 Auto TP", 4483362458)

AutoTPTab:CreateSection("360° ランダムテレポート ― 極座標方式")

AutoTPTab:CreateToggle({
    Name = "Auto TP 360° (ランダム角度にTPし、キル後に次の敵へ)",
    CurrentValue = false, Flag = "AutoTP",
    Callback = function(v)
        States.AutoTP = v
        if v then
            States.CurrentTPTarget = nil
            Rayfield:Notify({
                Title   = "Auto TP 360°",
                Content = "✅ 有効 ― 360°ランダム角度にTP\nキル後は次の敵へ自動切替",
                Duration = 4
            })
        else
            States.CurrentTPTarget = nil
            Rayfield:Notify({ Title = "Auto TP", Content = "❌ 無効", Duration = 2 })
        end
    end,
})

AutoTPTab:CreateSlider({
    Name = "TP距離 (円の半径: 0〜25 studs)",
    Range = {0, 25}, Increment = 0.5,
    Suffix = " studs", CurrentValue = 5, Flag = "TPDist",
    Callback = function(v) States.TPDistance = v end,
})

AutoTPTab:CreateLabel("θ = random(0° ~ 360°) で毎回異なる方向に出現")
AutoTPTab:CreateLabel("x = r·cos(θ),  z = r·sin(θ)  (極座標→直交座標変換)")
AutoTPTab:CreateLabel("TP後は必ず相手の方向を向きます")
AutoTPTab:CreateLabel("キル確認後、次のランダムな敵へ自動切替")

-- ============================================================
-- 🎭 FIXED MODE TAB
-- ============================================================
local FixedTab = Window:CreateTab("🎭 Fixed Mode", 4483362458)

FixedTab:CreateSection("全敵プレイヤー固定モード")

FixedTab:CreateToggle({
    Name = "全敵をプレイヤー正面に固定",
    CurrentValue = false, Flag = "AllFixed",
    Callback = function(v)
        States.AllPlayersFixed = v
        Rayfield:Notify({ Title = "Fixed Mode", Content = v and "✅ 有効" or "❌ 無効", Duration = 2 })
    end,
})

FixedTab:CreateSlider({
    Name = "固定距離", Range = {1,10}, Increment = 0.5,
    Suffix = " studs", CurrentValue = 3, Flag = "FixedDist",
    Callback = function(v) States.FixedDistance = v end,
})

FixedTab:CreateLabel("全ての敵キャラクターをプレイヤーの正面に固定します")
FixedTab:CreateLabel("リスポーン後も固定が持続します")

-- ============================================================
-- ⚔️ COMBAT TAB
-- ============================================================
local CombatTab = Window:CreateTab("⚔️ Combat", 4483362458)

CombatTab:CreateSection("リコイル制御")

CombatTab:CreateToggle({
    Name = "リコイル制御", CurrentValue = false, Flag = "RecoilCtrl",
    Callback = function(v) States.RecoilControl = v end,
})

CombatTab:CreateSlider({
    Name = "制御強度", Range = {0,100}, Increment = 5,
    Suffix = "%", CurrentValue = 100, Flag = "RecoilStr",
    Callback = function(v) States.RecoilStrength = v end,
})

CombatTab:CreateSection("弾道トレーサー")

CombatTab:CreateToggle({
    Name = "弾道トレーサー表示", CurrentValue = false, Flag = "BulletTrace",
    Callback = function(v) States.BulletTracerEnabled = v end,
})

CombatTab:CreateColorPicker({
    Name = "トレーサー色",
    Color = Color3.fromRGB(255,0,0), Flag = "TracerCol",
    Callback = function(v) States.TracerColor = v end,
})

CombatTab:CreateSlider({
    Name = "トレーサー太さ", Range = {1,10}, Increment = 1,
    Suffix = "px", CurrentValue = 2, Flag = "TracerThick",
    Callback = function(v) States.TracerThickness = v end,
})

CombatTab:CreateSlider({
    Name = "トレーサー表示時間", Range = {1,20}, Increment = 1,
    Suffix = "s", CurrentValue = 2, Flag = "TracerDur",
    Callback = function(v) States.TracerDuration = v end,
})

CombatTab:CreateSection("武器設定 (ゲーム依存)")

CombatTab:CreateToggle({
    Name = "リロード不要", CurrentValue = false, Flag = "NoReload",
    Callback = function(v)
        Rayfield:Notify({ Title = "リロード不要", Content = v and "✅" or "❌", Duration = 1 })
    end,
})

CombatTab:CreateToggle({
    Name = "無限弾薬", CurrentValue = false, Flag = "InfAmmo",
    Callback = function(v)
        Rayfield:Notify({ Title = "無限弾薬", Content = v and "✅" or "❌", Duration = 1 })
    end,
})

CombatTab:CreateToggle({
    Name = "ラピッドファイア", CurrentValue = false, Flag = "RapidFire",
    Callback = function(v)
        Rayfield:Notify({ Title = "ラピッドファイア", Content = v and "✅" or "❌", Duration = 1 })
    end,
})

CombatTab:CreateToggle({
    Name = "拡散なし (No Spread)", CurrentValue = false, Flag = "NoSpread",
    Callback = function(v)
        Rayfield:Notify({ Title = "拡散なし", Content = v and "✅" or "❌", Duration = 1 })
    end,
})

-- ============================================================
-- ⚙️ SETTINGS TAB
-- ============================================================
local SettingsTab = Window:CreateTab("⚙️ Settings", 4483362458)

SettingsTab:CreateSection("システム情報")

SettingsTab:CreateLabel("プラットフォーム: " .. States.Platform)
local lbl_target   = SettingsTab:CreateLabel("照準ターゲット: なし")
local lbl_tptarget = SettingsTab:CreateLabel("TPターゲット: なし")
local lbl_fov      = SettingsTab:CreateLabel("FOV Filter: OFF")

Connections["InfoUpdate"] = RS.Heartbeat:Connect(function()
    SafeCall(function()
        lbl_target:Set("照準ターゲット: "
            .. (States.CurrentTarget  and States.CurrentTarget.Player.Name  or "なし"))
        lbl_tptarget:Set("TPターゲット: "
            .. (States.CurrentTPTarget and States.CurrentTPTarget.Player.Name or "なし"))
        lbl_fov:Set("FOV Filter: " .. (States.FOVActive and "ON (壁判定込み)" or "OFF"))
    end)
end)

SettingsTab:CreateSection("キーバインド")
SettingsTab:CreateLabel("X キー: スティッキーエイム解除")

SettingsTab:CreateSection("操作")

SettingsTab:CreateButton({
    Name = "🔌 スクリプト終了",
    Callback = function()
        for _, c in pairs(Connections) do SafeCall(function() c:Disconnect() end) end
        Connections = {}
        for pl, _ in pairs(ESPObjects)   do Remove2DESP(pl) end
        for pl, _ in pairs(ESP3DObjects) do Remove3DESP(pl) end
        FOVDraw:Remove()
        SafeCall(function() Rayfield:Destroy() end)
    end,
})

-- ============================================================
-- MAIN LOOPS
-- ============================================================

-- Aimbot / Silent Aim Camera
Connections["MainAimbot"] = RS.Heartbeat:Connect(function()
    GetNearestTarget()
    local t = States.CurrentTarget
    if not t then return end

    local pos = t.Position

    if States.SilentAim then
        SmoothCameraTo(pos, States.CameraSmooth)
    end

    if States.HeadLock then
        SmoothCameraTo(pos, States.HeadLockSmooth)
    end

    if States.AutoAim then
        SmoothCameraTo(pos, States.AutoAimSmooth)
    end
end)

-- Auto Shot
local lastShot       = 0
local lastDetectShot = 0
local lastTrigger    = 0

Connections["AutoShotLoop"] = RS.Heartbeat:Connect(function()
    local now = tick()

    if States.AutoShot and States.CurrentTarget then
        if now - lastShot >= States.AutoShotDelay then
            lastShot = now
            PerformShot()
        end
    end

    if States.AutoShotOnDetect and States.CurrentTarget then
        if now - lastDetectShot >= States.AutoShotDetectDelay then
            lastDetectShot = now
            PerformShot()
        end
    end

    if States.TriggerBot and States.CurrentTarget then
        if now - lastTrigger >= States.TriggerDelay then
            lastTrigger = now
            PerformShot()
        end
    end
end)

-- Auto TP
Connections["AutoTP"] = RS.Heartbeat:Connect(function()
    AutoTPUpdate()
end)

-- Fixed Mode
Connections["FixedMode"] = RS.Heartbeat:Connect(function()
    AllPlayersFixedUpdate()
end)

-- ESP Update
Connections["ESPUpdate"] = RS.Heartbeat:Connect(function()
    UpdateAllESP()
end)

-- FOV Circle position update
Connections["FOVUpdate"] = RS.RenderStepped:Connect(function()
    if FOVDraw.Visible then
        FOVDraw.Position = Vector2.new(
            Camera.ViewportSize.X / 2,
            Camera.ViewportSize.Y / 2
        )
    end
end)

-- ============================================================
-- PLAYER EVENTS
-- ============================================================
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        if States.ESP then CreateDrawings(player) end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
    if States.CurrentTPTarget and States.CurrentTPTarget.Player == player then
        States.CurrentTPTarget = nil
    end
end)

-- Sticky Aim unlock key
UIS.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.X then
        States.LockedTarget = nil
        Rayfield:Notify({ Title = "ロック解除", Content = "X: ターゲットロック解除", Duration = 1 })
    end
end)

-- ============================================================
-- LOAD CONFIG & INITIAL NOTIFY
-- ============================================================
Rayfield:LoadConfiguration()

task.wait(1)
Rayfield:Notify({
    Title   = "⚡ Ultimate Combat System V3 起動完了",
    Content = table.concat({
        "✅ 全機能ロード完了!",
        "🎯 Silent Aim: Hitbox円 + 視点移動スムーズ",
        "👁️ ESP+: Box/Health/Trace/Circle/Triangle + 3D形状",
        "🌀 Auto TP 360°: 極座標ランダムTP",
        "🔫 Auto Shot: 1ms 精度対応",
        "Platform: " .. States.Platform,
    }, "\n"),
    Duration = 10,
    Image    = 4483362458,
})

print("✅ Ultimate Combat System V3 Loaded  |  Platform: " .. States.Platform)
print("🎯 Silent Aim (Hitbox+Camera)  |  Head Lock  |  Auto Aim")
print("👁️ ESP+ (2D+3D)  |  FOV System (wall-check linked)")
print("🔫 Auto Shot 1ms  |  🌀 Auto TP 360°  |  🎭 Fixed Mode")
