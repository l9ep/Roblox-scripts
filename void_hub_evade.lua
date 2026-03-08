--[[
    ╔═══════════════════════════════════════════════════╗
    ║           VOID HUB — EVADE SCRIPT                 ║
    ║         Tabs: Movement | Combat | Visual           ║
    ║              ESP | Misc | Settings                 ║
    ╚═══════════════════════════════════════════════════╝
]]

----------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UIS            = game:GetService("UserInputService")
local TweenService   = game:GetService("TweenService")
local Lighting       = game:GetService("Lighting")
local CoreGui        = game:GetService("CoreGui")
local StarterGui     = game:GetService("StarterGui")
local Workspace      = game:GetService("Workspace")
local HttpService    = game:GetService("HttpService")

local LocalPlayer    = Players.LocalPlayer
local Camera         = Workspace.CurrentCamera
local Mouse          = LocalPlayer:GetMouse()

----------------------------------------------------------------
-- RAYFIELD LOADER
----------------------------------------------------------------
local Rayfield
local ok, err = pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not ok then
    warn("[VOID HUB] Rayfield failed: " .. tostring(err))
    return
end

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local CFG = {
    -- Movement
    WalkSpeed        = 16,
    JumpPower        = 50,
    InfiniteJump     = false,
    NoBoundary       = false,
    AutoJump         = false,
    Bunny            = false,
    BunnyStrength    = 18,
    BunnyCD          = 0.22,
    Noclip           = false,
    SpeedBoost       = false,
    SpeedBoostAmount = 30,
    LowGrav          = false,
    GravAmount       = 100,
    AirWalk          = false,
    FlyEnabled       = false,
    FlySpeed         = 60,

    -- Combat / Game
    AutoFlash        = false,
    AutoDash         = false,
    AutoDashDist     = 14,
    AutoPickup       = false,
    AutoPickupRadius = 20,
    KillAura         = false,
    KillAuraRadius   = 10,
    AutoHide         = false,
    AutoHideRadius   = 12,
    TPKiller         = false,
    AntiKiller       = false,
    AntiKillerDist   = 18,
    FakeLag          = false,
    FakeLagFrames    = 4,

    -- Visual
    Fullbright       = false,
    NoFog            = false,
    CustomFOV        = false,
    FOVAmount        = 90,
    ShowFPS          = false,
    Tracers          = false,
    TracerColor      = Color3.fromRGB(255, 60, 80),
    ChamsEnabled     = false,
    ChamsColor       = Color3.fromRGB(255, 60, 80),
    CrosshairEnabled = false,
    CrosshairSize    = 12,
    CrosshairColor   = Color3.fromRGB(255, 255, 255),
    BlackSky         = false,

    -- ESP
    ESPEnabled       = false,
    ESPBoxes         = true,
    ESPNames         = true,
    ESPDist          = true,
    ESPHealth        = true,
    ESPMaxDist       = 400,
    ESPKillerOnly    = false,
    ESPBoxColor      = Color3.fromRGB(255, 60, 80),
    ESPNameColor     = Color3.fromRGB(255, 255, 255),
    ESPDistColor     = Color3.fromRGB(180, 180, 255),

    -- Misc
    ChatSpam         = false,
    ChatSpamMsg      = "VOID HUB",
    ChatSpamDelay    = 3,
    NotifKills       = true,
    TPCoords         = false,
    RejoinOnDeath    = false,
    AntiAFK          = true,
    CamLock          = false,
    CamLockTarget    = nil,
    CamLockSmooth    = 0.15,
}

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local connections     = {}
local espCache        = {}
local tracerCache     = {}
local chamsCache      = {}
local flyBody         = nil
local flyGyro         = nil
local flyActive       = false
local crosshairLines  = {}
local fpsLabel        = nil
local fpsCount        = 0
local fpsTick         = tick()
local lastBunnyTime   = 0
local noclipConn      = nil
local originalGrav    = Workspace.Gravity

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------
local function getChar()
    return LocalPlayer.Character
end

local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function tween(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
end

local function disconnect(name)
    if connections[name] then
        connections[name]:Disconnect()
        connections[name] = nil
    end
end

local function isKiller(player)
    -- Evade: killer usually has a tool named "Knife" or "Weapon" or is tagged
    if not player or not player.Character then return false end
    local char = player.Character
    if char:FindFirstChild("Knife") or char:FindFirstChild("Weapon") then return true end
    -- check for Killer tag value
    local tag = char:FindFirstChild("IsKiller") or char:FindFirstChild("Killer")
    if tag then return true end
    -- fallback: check backpack
    local bp = player:FindFirstChildOfClass("Backpack")
    if bp and bp:FindFirstChild("Knife") then return true end
    return false
end

----------------------------------------------------------------
-- MOVEMENT
----------------------------------------------------------------

-- WalkSpeed / JumpPower apply
local function applyMovement()
    local hum = getHum()
    if not hum then return end
    hum.WalkSpeed = CFG.WalkSpeed
    hum.JumpPower = CFG.JumpPower
end

-- Infinite Jump
local function setInfiniteJump(on)
    disconnect("infiniteJump")
    if on then
        connections["infiniteJump"] = UIS.JumpRequest:Connect(function()
            local hum = getHum()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end

-- Auto Jump (spam jump)
local function setAutoJump(on)
    disconnect("autoJump")
    if on then
        connections["autoJump"] = RunService.Heartbeat:Connect(function()
            local hum = getHum()
            if hum and hum.FloorMaterial ~= Enum.Material.Air then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end

-- Bunny Hop
local function setBunny(on)
    disconnect("bunny")
    if on then
        connections["bunny"] = UIS.JumpRequest:Connect(function()
            local hrp = getHRP()
            local hum = getHum()
            if not hrp or not hum then return end
            if (tick() - lastBunnyTime) < CFG.BunnyCD then return end
            lastBunnyTime = tick()
            if hum.FloorMaterial ~= Enum.Material.Air then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                local vel = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = Vector3.new(vel.X * 1.12, CFG.BunnyStrength, vel.Z * 1.12)
            end
        end)
    end
end

-- Noclip
local function setNoclip(on)
    disconnect("noclip")
    noclipConn = nil
    if on then
        connections["noclip"] = RunService.Stepped:Connect(function()
            local char = getChar()
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
        noclipConn = connections["noclip"]
    else
        -- restore collisions
        local char = getChar()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- Low Gravity
local function setLowGrav(on)
    Workspace.Gravity = on and CFG.GravAmount or originalGrav
end

-- Air Walk (no gravity on character)
local function setAirWalk(on)
    local hum = getHum()
    if hum then
        hum.PlatformStand = on
    end
end

-- Fly
local function setFly(on)
    local char = getChar()
    local hrp  = getHRP()
    if not char or not hrp then return end

    if on and not flyActive then
        flyActive = true
        flyBody = Instance.new("BodyVelocity")
        flyBody.Velocity = Vector3.zero
        flyBody.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        flyBody.Parent = hrp

        flyGyro = Instance.new("BodyGyro")
        flyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        flyGyro.P = 1e4
        flyGyro.Parent = hrp

        connections["fly"] = RunService.Heartbeat:Connect(function()
            if not CFG.FlyEnabled then return end
            local speed = CFG.FlySpeed
            local camCF = Camera.CFrame
            local move  = Vector3.zero

            if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + camCF.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - camCF.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - camCF.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + camCF.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0,1,0) end

            flyBody.Velocity = move.Magnitude > 0 and move.Unit * speed or Vector3.zero
            flyGyro.CFrame   = camCF
        end)
    elseif not on and flyActive then
        flyActive = false
        disconnect("fly")
        if flyBody   then flyBody:Destroy();   flyBody   = nil end
        if flyGyro   then flyGyro:Destroy();   flyGyro   = nil end
    end
end

-- Speed Boost
local function setSpeedBoost(on)
    local hum = getHum()
    if not hum then return end
    hum.WalkSpeed = on and CFG.SpeedBoostAmount or CFG.WalkSpeed
end

----------------------------------------------------------------
-- GAME / COMBAT
----------------------------------------------------------------

-- Anti-Killer (teleport away)
local function setAntiKiller(on)
    disconnect("antiKiller")
    if on then
        connections["antiKiller"] = RunService.Heartbeat:Connect(function()
            local hrp = getHRP()
            if not hrp then return end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and isKiller(p) then
                    local khrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    if khrp then
                        local dist = (khrp.Position - hrp.Position).Magnitude
                        if dist < CFG.AntiKillerDist then
                            -- run away by boosting velocity opposite
                            local away = (hrp.Position - khrp.Position).Unit
                            hrp.AssemblyLinearVelocity = away * 80 + Vector3.new(0, 30, 0)
                        end
                    end
                end
            end
        end)
    end
end

-- Kill Aura (loop near players — in Evade you can't directly kill but send exploit)
local function setKillAura(on)
    disconnect("killAura")
    if on then
        connections["killAura"] = RunService.Heartbeat:Connect(function()
            local hrp = getHRP()
            if not hrp then return end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    local phrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    if phrp and (phrp.Position - hrp.Position).Magnitude <= CFG.KillAuraRadius then
                        -- CFrame onto them rapidly
                        hrp.CFrame = CFrame.new(phrp.Position + Vector3.new(0,0,0.5))
                    end
                end
            end
        end)
    end
end

-- Auto Dodge/Dash
local function setAutoDash(on)
    disconnect("autoDash")
    if on then
        connections["autoDash"] = RunService.Heartbeat:Connect(function()
            local hrp = getHRP()
            if not hrp then return end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and isKiller(p) then
                    local khrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    if khrp and (khrp.Position - hrp.Position).Magnitude < CFG.AutoDashDist then
                        local away = (hrp.Position - khrp.Position).Unit
                        hrp.AssemblyLinearVelocity = away * 75 + Vector3.new(0, 20, 0)
                    end
                end
            end
        end)
    end
end

-- TP to Killer
local function setTPKiller(on)
    disconnect("tpKiller")
    if on then
        connections["tpKiller"] = RunService.Heartbeat:Connect(function()
            local hrp = getHRP()
            if not hrp then return end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and isKiller(p) then
                    local khrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    if khrp then
                        hrp.CFrame = khrp.CFrame * CFrame.new(0, 0, 2)
                        break
                    end
                end
            end
        end)
    end
end

-- Auto Hide (find cover)
local function setAutoHide(on)
    disconnect("autoHide")
    if on then
        connections["autoHide"] = RunService.Heartbeat:Connect(function()
            local hrp = getHRP()
            if not hrp then return end
            -- find walls/obstacles to hide behind relative to killer
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and isKiller(p) then
                    local khrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    if khrp and (khrp.Position - hrp.Position).Magnitude < CFG.AutoHideRadius then
                        local away = (hrp.Position - khrp.Position)
                        local perpDir = Vector3.new(-away.Z, 0, away.X).Unit
                        hrp.CFrame = CFrame.new(hrp.Position + perpDir * 8)
                    end
                end
            end
        end)
    end
end

-- Anti-AFK
local function setAntiAFK(on)
    disconnect("antiAFK")
    if on then
        local virt = Instance.new("VirtualUser")
        virt.Parent = LocalPlayer
        connections["antiAFK"] = LocalPlayer.Idled:Connect(function()
            virt:CaptureController()
            virt:ClickButton2(Vector2.new())
        end)
    end
end

-- Chat Spam
local chatSpamThread = nil
local function setChatSpam(on)
    if chatSpamThread then task.cancel(chatSpamThread); chatSpamThread = nil end
    if on then
        chatSpamThread = task.spawn(function()
            while CFG.ChatSpam do
                game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
                    and game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents
                        :FindFirstChild("SayMessageRequest")
                        and game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest
                            :FireServer(CFG.ChatSpamMsg, "All")
                task.wait(CFG.ChatSpamDelay)
            end
        end)
    end
end

-- Cam Lock
local function setCamLock(on)
    disconnect("camLock")
    if on then
        connections["camLock"] = RunService.RenderStepped:Connect(function()
            if not CFG.CamLockTarget then
                -- auto pick nearest player
                local nearest, nearDist = nil, math.huge
                local myHRP = getHRP()
                if not myHRP then return end
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local phrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if phrp then
                            local d = (phrp.Position - myHRP.Position).Magnitude
                            if d < nearDist then nearDist = d; nearest = p end
                        end
                    end
                end
                CFG.CamLockTarget = nearest
            end
            if CFG.CamLockTarget and CFG.CamLockTarget.Character then
                local head = CFG.CamLockTarget.Character:FindFirstChild("Head")
                if head then
                    Camera.CFrame = Camera.CFrame:Lerp(
                        CFrame.new(Camera.CFrame.Position, head.Position),
                        CFG.CamLockSmooth
                    )
                end
            end
        end)
    end
end

----------------------------------------------------------------
-- VISUAL
----------------------------------------------------------------

-- Fullbright
local originalBrightness = Lighting.Brightness
local originalAmbient    = Lighting.Ambient
local originalOutdoor    = Lighting.OutdoorAmbient

local function setFullbright(on)
    if on then
        Lighting.Brightness = 8
        Lighting.Ambient = Color3.new(1,1,1)
        Lighting.OutdoorAmbient = Color3.new(1,1,1)
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1e6
    else
        Lighting.Brightness = originalBrightness
        Lighting.Ambient = originalAmbient
        Lighting.OutdoorAmbient = originalOutdoor
    end
end

-- No Fog
local function setNoFog(on)
    Lighting.FogEnd = on and 1e6 or 1000
    Lighting.FogStart = on and 1e5 or 0
end

-- Black Sky
local function setBlackSky(on)
    Lighting.ClockTime = on and 0 or 14
    Lighting.Brightness = on and 0 or originalBrightness
end

-- Custom FOV
local function setFOV(on)
    Camera.FieldOfView = on and CFG.FOVAmount or 70
end

-- FPS Counter
local function buildFPSLabel()
    if fpsLabel then fpsLabel:Destroy() end
    local sg = Instance.new("ScreenGui", CoreGui)
    sg.Name = "VoidFPS"
    sg.ResetOnSpawn = false
    local lbl = Instance.new("TextLabel", sg)
    lbl.Size = UDim2.new(0, 80, 0, 22)
    lbl.Position = UDim2.new(1, -90, 0, 10)
    lbl.BackgroundColor3 = Color3.fromRGB(12,12,18)
    lbl.BackgroundTransparency = 0.35
    lbl.BorderSizePixel = 0
    lbl.TextColor3 = Color3.fromRGB(100, 255, 160)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.Text = "FPS: --"
    local c = Instance.new("UICorner", lbl)
    c.CornerRadius = UDim.new(0,6)
    fpsLabel = lbl
    disconnect("fps")
    connections["fps"] = RunService.RenderStepped:Connect(function()
        fpsCount = fpsCount + 1
        if (tick() - fpsTick) >= 1 then
            lbl.Text = "FPS: " .. fpsCount
            fpsCount = 0
            fpsTick = tick()
        end
    end)
end

local function setFPSDisplay(on)
    disconnect("fps")
    if fpsLabel then
        fpsLabel.Parent.Parent:Destroy()
        fpsLabel = nil
    end
    if on then buildFPSLabel() end
end

-- Crosshair
local function buildCrosshair()
    for _, l in ipairs(crosshairLines) do l:Remove() end
    crosshairLines = {}
    if not CFG.CrosshairEnabled then return end
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local s = CFG.CrosshairSize
    local names = {"H1","H2","V1","V2"}
    local froms = {
        Vector2.new(center.X - s, center.Y),
        Vector2.new(center.X + 2, center.Y),
        Vector2.new(center.X, center.Y - s),
        Vector2.new(center.X, center.Y + 2),
    }
    local tos = {
        Vector2.new(center.X - 2, center.Y),
        Vector2.new(center.X + s, center.Y),
        Vector2.new(center.X, center.Y - 2),
        Vector2.new(center.X, center.Y + s),
    }
    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.From = froms[i]
        line.To   = tos[i]
        line.Color = CFG.CrosshairColor
        line.Thickness = 1.8
        line.Transparency = 1
        line.Visible = true
        table.insert(crosshairLines, line)
    end
end

-- Tracers (lines from screen bottom to player)
local function updateTracers()
    -- cleared each frame in RenderStepped
end

-- Chams (highlight via SelectionBox)
local function updateChams()
    -- clean dead entries
    for p, box in pairs(chamsCache) do
        if not p or not p.Parent then
            box:Destroy()
            chamsCache[p] = nil
        end
    end
    if not CFG.ChamsEnabled then
        for _, box in pairs(chamsCache) do box:Destroy() end
        chamsCache = {}
        return
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            if not chamsCache[p] then
                local box = Instance.new("SelectionBox", CoreGui)
                box.LineThickness = 0.05
                box.Color3 = CFG.ChamsColor
                box.SurfaceTransparency = 0.6
                box.SurfaceColor3 = CFG.ChamsColor
                box.Adornee = p.Character
                chamsCache[p] = box
            end
        end
    end
end

----------------------------------------------------------------
-- ESP
----------------------------------------------------------------
local function makeESP(player)
    if espCache[player] then return espCache[player] end

    local gui = Instance.new("BillboardGui")
    gui.AlwaysOnTop = true
    gui.Size = UDim2.new(0, 100, 0, 80)
    gui.StudsOffset = Vector3.new(0, 3.2, 0)
    gui.LightInfluence = 0

    -- Name
    local nameLbl = Instance.new("TextLabel", gui)
    nameLbl.Name = "NameLbl"
    nameLbl.Size = UDim2.new(1, 0, 0, 16)
    nameLbl.Position = UDim2.new(0, 0, 0, -18)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.TextColor3 = CFG.ESPNameColor
    nameLbl.TextStrokeTransparency = 0.4
    nameLbl.TextStrokeColor3 = Color3.new(0,0,0)
    nameLbl.Text = player.Name

    -- Distance
    local distLbl = Instance.new("TextLabel", gui)
    distLbl.Name = "DistLbl"
    distLbl.Size = UDim2.new(1, 0, 0, 14)
    distLbl.Position = UDim2.new(0, 0, 1, 2)
    distLbl.BackgroundTransparency = 1
    distLbl.Font = Enum.Font.Gotham
    distLbl.TextSize = 11
    distLbl.TextColor3 = CFG.ESPDistColor
    distLbl.TextStrokeTransparency = 0.4
    distLbl.TextStrokeColor3 = Color3.new(0,0,0)
    distLbl.Text = ""

    -- Health bar
    local healthBG = Instance.new("Frame", gui)
    healthBG.Name = "HealthBG"
    healthBG.Size = UDim2.new(0, 4, 1, 0)
    healthBG.Position = UDim2.new(0, -8, 0, 0)
    healthBG.BackgroundColor3 = Color3.fromRGB(40,40,40)
    healthBG.BorderSizePixel = 0
    local c = Instance.new("UICorner", healthBG); c.CornerRadius = UDim.new(0,2)

    local healthFill = Instance.new("Frame", healthBG)
    healthFill.Name = "HealthFill"
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.BackgroundColor3 = Color3.fromRGB(0, 220, 100)
    healthFill.BorderSizePixel = 0
    local c2 = Instance.new("UICorner", healthFill); c2.CornerRadius = UDim.new(0,2)

    -- Killer badge
    local killerLbl = Instance.new("TextLabel", gui)
    killerLbl.Name = "KillerLbl"
    killerLbl.Size = UDim2.new(1, 0, 0, 14)
    killerLbl.Position = UDim2.new(0, 0, 0, -32)
    killerLbl.BackgroundTransparency = 1
    killerLbl.Font = Enum.Font.GothamBold
    killerLbl.TextSize = 11
    killerLbl.TextColor3 = Color3.fromRGB(255, 60, 60)
    killerLbl.TextStrokeTransparency = 0.3
    killerLbl.TextStrokeColor3 = Color3.new(0,0,0)
    killerLbl.Text = ""

    espCache[player] = gui
    return gui
end

local espContainer
do
    local sg = Instance.new("ScreenGui")
    sg.Name = "VoidESP"
    sg.ResetOnSpawn = false
    if gethui then sg.Parent = gethui()
    elseif syn and syn.protect_gui then syn.protect_gui(sg); sg.Parent = CoreGui
    else sg.Parent = CoreGui end
    espContainer = sg
end

-- Tracer drawing cache
local tracerDrawings = {}

local function updateESP()
    -- cleanup removed players
    for p, gui in pairs(espCache) do
        if not p or not p.Parent then
            gui:Destroy(); espCache[p] = nil
        end
    end
    for p, line in pairs(tracerDrawings) do
        if not p or not p.Parent then
            line:Remove(); tracerDrawings[p] = nil
        end
    end

    local myHRP = getHRP()

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local char = p.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")

        local shouldShow = CFG.ESPEnabled and hrp and head and hum and hum.Health > 0
        if shouldShow and CFG.ESPKillerOnly and not isKiller(p) then shouldShow = false end

        local dist = myHRP and hrp and (hrp.Position - myHRP.Position).Magnitude or 0
        if dist > CFG.ESPMaxDist then shouldShow = false end

        if shouldShow then
            local esp = makeESP(p)
            esp.Adornee = head
            esp.Parent = espContainer

            -- Update name
            if CFG.ESPNames then
                local nl = esp:FindFirstChild("NameLbl")
                if nl then nl.Visible = true; nl.Text = p.Name end
            else
                local nl = esp:FindFirstChild("NameLbl")
                if nl then nl.Visible = false end
            end

            -- Update dist
            if CFG.ESPDist then
                local dl = esp:FindFirstChild("DistLbl")
                if dl then dl.Visible = true; dl.Text = math.floor(dist) .. "m" end
            else
                local dl = esp:FindFirstChild("DistLbl")
                if dl then dl.Visible = false end
            end

            -- Update health
            if CFG.ESPHealth and hum then
                local bg = esp:FindFirstChild("HealthBG")
                local fill = bg and bg:FindFirstChild("HealthFill")
                if bg and fill then
                    bg.Visible = true
                    local frac = hum.Health / hum.MaxHealth
                    fill.Size = UDim2.new(1, 0, frac, 0)
                    fill.BackgroundColor3 = Color3.fromRGB(
                        math.floor((1-frac)*255),
                        math.floor(frac*220),
                        60
                    )
                end
            else
                local bg = esp:FindFirstChild("HealthBG")
                if bg then bg.Visible = false end
            end

            -- Killer badge
            local kl = esp:FindFirstChild("KillerLbl")
            if kl then kl.Text = isKiller(p) and "⚠ KILLER" or "" end

            -- Tracers
            if CFG.Tracers then
                if not tracerDrawings[p] then
                    local line = Drawing.new("Line")
                    line.Thickness = 1.2
                    line.Transparency = 1
                    line.Visible = true
                    tracerDrawings[p] = line
                end
                local line = tracerDrawings[p]
                local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    line.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                    line.To   = Vector2.new(screenPos.X, screenPos.Y)
                    line.Color = isKiller(p) and Color3.fromRGB(255,60,80) or CFG.TracerColor
                    line.Visible = true
                else
                    line.Visible = false
                end
            else
                if tracerDrawings[p] then
                    tracerDrawings[p].Visible = false
                end
            end

        else
            local esp = espCache[p]
            if esp then esp.Parent = nil end
            if tracerDrawings[p] then tracerDrawings[p].Visible = false end
        end
    end
end

----------------------------------------------------------------
-- RENDER LOOP
----------------------------------------------------------------
RunService.RenderStepped:Connect(function()
    updateESP()
    updateChams()
end)

----------------------------------------------------------------
-- CHARACTER INIT
----------------------------------------------------------------
local function onCharacterAdded(char)
    char:WaitForChild("Humanoid")
    char:WaitForChild("HumanoidRootPart")
    task.wait(0.5)

    applyMovement()
    setInfiniteJump(CFG.InfiniteJump)
    setAutoJump(CFG.AutoJump)
    setBunny(CFG.Bunny)
    setNoclip(CFG.Noclip)
    setLowGrav(CFG.LowGrav)
    setAntiKiller(CFG.AntiKiller)
    setAutoDash(CFG.AutoDash)
    setTPKiller(CFG.TPKiller)
    setAutoHide(CFG.AutoHide)
    setKillAura(CFG.KillAura)
    setCamLock(CFG.CamLock)
    if CFG.FlyEnabled then setFly(true) end
end

if LocalPlayer.Character then onCharacterAdded(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

-- Respawn death rejoin
LocalPlayer.CharacterAdded:Connect(function(char)
    if CFG.RejoinOnDeath then
        local hum = char:WaitForChild("Humanoid")
        hum.Died:Connect(function()
            task.wait(1)
            game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
        end)
    end
end)

setAntiAFK(CFG.AntiAFK)

----------------------------------------------------------------
-- RAYFIELD WINDOW
----------------------------------------------------------------
local Window = Rayfield:CreateWindow({
    Name             = "VOID HUB  •  Evade",
    Icon             = 0,
    LoadingTitle     = "VOID HUB",
    LoadingSubtitle  = "Evade Edition",
    Theme            = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings   = false,
    ConfigurationSaving    = {
        Enabled    = true,
        FolderName = "VoidHub",
        FileName   = "EvadeConfig",
    },
    KeySystem = false,
})

----------------------------------------------------------------
-- TAB: MOVEMENT
----------------------------------------------------------------
local MovTab = Window:CreateTab("🏃 Movement", 4483362458)

MovTab:CreateSection("Speed & Jump")

MovTab:CreateSlider({
    Name = "Walk Speed",
    Range = {1, 120},
    Increment = 1,
    Suffix = "",
    CurrentValue = CFG.WalkSpeed,
    Flag = "WalkSpeed",
    Callback = function(v)
        CFG.WalkSpeed = v
        local hum = getHum()
        if hum and not CFG.SpeedBoost then hum.WalkSpeed = v end
    end,
})

MovTab:CreateSlider({
    Name = "Jump Power",
    Range = {1, 250},
    Increment = 1,
    Suffix = "",
    CurrentValue = CFG.JumpPower,
    Flag = "JumpPower",
    Callback = function(v)
        CFG.JumpPower = v
        local hum = getHum()
        if hum then hum.JumpPower = v end
    end,
})

MovTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = CFG.InfiniteJump,
    Flag = "InfiniteJump",
    Callback = function(v) CFG.InfiniteJump = v; setInfiniteJump(v) end,
})

MovTab:CreateToggle({
    Name = "Auto Jump",
    CurrentValue = CFG.AutoJump,
    Flag = "AutoJump",
    Callback = function(v) CFG.AutoJump = v; setAutoJump(v) end,
})

MovTab:CreateSection("Advanced Movement")

MovTab:CreateToggle({
    Name = "Bunny Hop",
    CurrentValue = CFG.Bunny,
    Flag = "Bunny",
    Callback = function(v) CFG.Bunny = v; setBunny(v) end,
})

MovTab:CreateSlider({
    Name = "Bunny Strength",
    Range = {5, 60},
    Increment = 1,
    CurrentValue = CFG.BunnyStrength,
    Flag = "BunnyStrength",
    Callback = function(v) CFG.BunnyStrength = v end,
})

MovTab:CreateToggle({
    Name = "Speed Boost",
    CurrentValue = CFG.SpeedBoost,
    Flag = "SpeedBoost",
    Callback = function(v) CFG.SpeedBoost = v; setSpeedBoost(v) end,
})

MovTab:CreateSlider({
    Name = "Speed Boost Amount",
    Range = {20, 200},
    Increment = 2,
    CurrentValue = CFG.SpeedBoostAmount,
    Flag = "SpeedBoostAmount",
    Callback = function(v)
        CFG.SpeedBoostAmount = v
        if CFG.SpeedBoost then setSpeedBoost(true) end
    end,
})

MovTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = CFG.Noclip,
    Flag = "Noclip",
    Callback = function(v) CFG.Noclip = v; setNoclip(v) end,
})

MovTab:CreateToggle({
    Name = "Fly  [W/A/S/D + Space/Ctrl]",
    CurrentValue = CFG.FlyEnabled,
    Flag = "FlyEnabled",
    Callback = function(v) CFG.FlyEnabled = v; setFly(v) end,
})

MovTab:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 300},
    Increment = 5,
    CurrentValue = CFG.FlySpeed,
    Flag = "FlySpeed",
    Callback = function(v) CFG.FlySpeed = v end,
})

MovTab:CreateSection("Physics")

MovTab:CreateToggle({
    Name = "Low Gravity",
    CurrentValue = CFG.LowGrav,
    Flag = "LowGrav",
    Callback = function(v) CFG.LowGrav = v; setLowGrav(v) end,
})

MovTab:CreateSlider({
    Name = "Gravity Amount",
    Range = {5, 196},
    Increment = 1,
    CurrentValue = CFG.GravAmount,
    Flag = "GravAmount",
    Callback = function(v)
        CFG.GravAmount = v
        if CFG.LowGrav then Workspace.Gravity = v end
    end,
})

MovTab:CreateToggle({
    Name = "Air Walk",
    CurrentValue = CFG.AirWalk,
    Flag = "AirWalk",
    Callback = function(v) CFG.AirWalk = v; setAirWalk(v) end,
})

----------------------------------------------------------------
-- TAB: COMBAT
----------------------------------------------------------------
local CombatTab = Window:CreateTab("⚔️ Combat", 4483362458)

CombatTab:CreateSection("Survival")

CombatTab:CreateToggle({
    Name = "Anti-Killer  (Velocity Away)",
    CurrentValue = CFG.AntiKiller,
    Flag = "AntiKiller",
    Callback = function(v) CFG.AntiKiller = v; setAntiKiller(v) end,
})

CombatTab:CreateSlider({
    Name = "Anti-Killer Trigger Dist",
    Range = {5, 50},
    Increment = 1,
    CurrentValue = CFG.AntiKillerDist,
    Flag = "AntiKillerDist",
    Callback = function(v)
        CFG.AntiKillerDist = v
        if CFG.AntiKiller then setAntiKiller(false); setAntiKiller(true) end
    end,
})

CombatTab:CreateToggle({
    Name = "Auto Dash  (Evade Killers)",
    CurrentValue = CFG.AutoDash,
    Flag = "AutoDash",
    Callback = function(v) CFG.AutoDash = v; setAutoDash(v) end,
})

CombatTab:CreateSlider({
    Name = "Auto Dash Trigger Dist",
    Range = {5, 40},
    Increment = 1,
    CurrentValue = CFG.AutoDashDist,
    Flag = "AutoDashDist",
    Callback = function(v) CFG.AutoDashDist = v end,
})

CombatTab:CreateToggle({
    Name = "Auto Hide",
    CurrentValue = CFG.AutoHide,
    Flag = "AutoHide",
    Callback = function(v) CFG.AutoHide = v; setAutoHide(v) end,
})

CombatTab:CreateSection("Killer Features")

CombatTab:CreateToggle({
    Name = "TP to Killer",
    CurrentValue = CFG.TPKiller,
    Flag = "TPKiller",
    Callback = function(v) CFG.TPKiller = v; setTPKiller(v) end,
})

CombatTab:CreateToggle({
    Name = "Kill Aura  (TP onto players)",
    CurrentValue = CFG.KillAura,
    Flag = "KillAura",
    Callback = function(v) CFG.KillAura = v; setKillAura(v) end,
})

CombatTab:CreateSlider({
    Name = "Kill Aura Radius",
    Range = {3, 40},
    Increment = 1,
    CurrentValue = CFG.KillAuraRadius,
    Flag = "KillAuraRadius",
    Callback = function(v) CFG.KillAuraRadius = v end,
})

CombatTab:CreateSection("Camera")

CombatTab:CreateToggle({
    Name = "Cam Lock  (auto-nearest)",
    CurrentValue = CFG.CamLock,
    Flag = "CamLock",
    Callback = function(v)
        CFG.CamLock = v
        CFG.CamLockTarget = nil
        setCamLock(v)
    end,
})

CombatTab:CreateSlider({
    Name = "Cam Lock Smoothness",
    Range = {1, 20},
    Increment = 1,
    CurrentValue = CFG.CamLockSmooth * 100,
    Flag = "CamLockSmooth",
    Callback = function(v) CFG.CamLockSmooth = v / 100 end,
})

CombatTab:CreateButton({
    Name = "Reset Cam Lock Target",
    Callback = function() CFG.CamLockTarget = nil end,
})

----------------------------------------------------------------
-- TAB: VISUALS
----------------------------------------------------------------
local VisTab = Window:CreateTab("🎨 Visuals", 4483362458)

VisTab:CreateSection("Lighting")

VisTab:CreateToggle({
    Name = "Fullbright",
    CurrentValue = CFG.Fullbright,
    Flag = "Fullbright",
    Callback = function(v) CFG.Fullbright = v; setFullbright(v) end,
})

VisTab:CreateToggle({
    Name = "No Fog",
    CurrentValue = CFG.NoFog,
    Flag = "NoFog",
    Callback = function(v) CFG.NoFog = v; setNoFog(v) end,
})

VisTab:CreateToggle({
    Name = "Black Sky",
    CurrentValue = CFG.BlackSky,
    Flag = "BlackSky",
    Callback = function(v) CFG.BlackSky = v; setBlackSky(v) end,
})

VisTab:CreateSection("Camera & HUD")

VisTab:CreateToggle({
    Name = "Custom FOV",
    CurrentValue = CFG.CustomFOV,
    Flag = "CustomFOV",
    Callback = function(v) CFG.CustomFOV = v; setFOV(v) end,
})

VisTab:CreateSlider({
    Name = "FOV Amount",
    Range = {50, 130},
    Increment = 1,
    Suffix = "°",
    CurrentValue = CFG.FOVAmount,
    Flag = "FOVAmount",
    Callback = function(v)
        CFG.FOVAmount = v
        if CFG.CustomFOV then Camera.FieldOfView = v end
    end,
})

VisTab:CreateToggle({
    Name = "FPS Counter",
    CurrentValue = CFG.ShowFPS,
    Flag = "ShowFPS",
    Callback = function(v) CFG.ShowFPS = v; setFPSDisplay(v) end,
})

VisTab:CreateToggle({
    Name = "Custom Crosshair",
    CurrentValue = CFG.CrosshairEnabled,
    Flag = "CrosshairEnabled",
    Callback = function(v) CFG.CrosshairEnabled = v; buildCrosshair() end,
})

VisTab:CreateSlider({
    Name = "Crosshair Size",
    Range = {4, 40},
    Increment = 1,
    CurrentValue = CFG.CrosshairSize,
    Flag = "CrosshairSize",
    Callback = function(v) CFG.CrosshairSize = v; if CFG.CrosshairEnabled then buildCrosshair() end end,
})

VisTab:CreateSection("Player Highlight")

VisTab:CreateToggle({
    Name = "Chams  (SelectionBox)",
    CurrentValue = CFG.ChamsEnabled,
    Flag = "ChamsEnabled",
    Callback = function(v) CFG.ChamsEnabled = v; if not v then updateChams() end end,
})

VisTab:CreateToggle({
    Name = "Tracers",
    CurrentValue = CFG.Tracers,
    Flag = "Tracers",
    Callback = function(v) CFG.Tracers = v end,
})

----------------------------------------------------------------
-- TAB: ESP
----------------------------------------------------------------
local ESPTab = Window:CreateTab("👁️ ESP", 4483362458)

ESPTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = CFG.ESPEnabled,
    Flag = "ESPEnabled",
    Callback = function(v)
        CFG.ESPEnabled = v
        if not v then
            for _, g in pairs(espCache) do g.Parent = nil end
        end
    end,
})

ESPTab:CreateToggle({
    Name = "Killer Only ESP",
    CurrentValue = CFG.ESPKillerOnly,
    Flag = "ESPKillerOnly",
    Callback = function(v) CFG.ESPKillerOnly = v end,
})

ESPTab:CreateSection("Components")

ESPTab:CreateToggle({
    Name = "Show Names",
    CurrentValue = CFG.ESPNames,
    Flag = "ESPNames",
    Callback = function(v) CFG.ESPNames = v end,
})

ESPTab:CreateToggle({
    Name = "Show Distance",
    CurrentValue = CFG.ESPDist,
    Flag = "ESPDist",
    Callback = function(v) CFG.ESPDist = v end,
})

ESPTab:CreateToggle({
    Name = "Show Health Bar",
    CurrentValue = CFG.ESPHealth,
    Flag = "ESPHealth",
    Callback = function(v) CFG.ESPHealth = v end,
})

ESPTab:CreateSlider({
    Name = "Max ESP Distance",
    Range = {50, 1000},
    Increment = 25,
    Suffix = "m",
    CurrentValue = CFG.ESPMaxDist,
    Flag = "ESPMaxDist",
    Callback = function(v) CFG.ESPMaxDist = v end,
})

----------------------------------------------------------------
-- TAB: MISC
----------------------------------------------------------------
local MiscTab = Window:CreateTab("🔧 Misc", 4483362458)

MiscTab:CreateSection("Quality of Life")

MiscTab:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = CFG.AntiAFK,
    Flag = "AntiAFK",
    Callback = function(v) CFG.AntiAFK = v; setAntiAFK(v) end,
})

MiscTab:CreateToggle({
    Name = "Rejoin on Death",
    CurrentValue = CFG.RejoinOnDeath,
    Flag = "RejoinOnDeath",
    Callback = function(v) CFG.RejoinOnDeath = v end,
})

MiscTab:CreateToggle({
    Name = "Fake Lag",
    CurrentValue = CFG.FakeLag,
    Flag = "FakeLag",
    Callback = function(v)
        CFG.FakeLag = v
        disconnect("fakeLag")
        if v then
            local count = 0
            connections["fakeLag"] = RunService.Heartbeat:Connect(function()
                count = count + 1
                if count % CFG.FakeLagFrames ~= 0 then
                    -- stall by sleeping briefly
                    local t = tick()
                    while tick() - t < 0.002 do end
                end
            end)
        end
    end,
})

MiscTab:CreateSlider({
    Name = "Fake Lag Intensity",
    Range = {1, 10},
    Increment = 1,
    CurrentValue = CFG.FakeLagFrames,
    Flag = "FakeLagFrames",
    Callback = function(v) CFG.FakeLagFrames = v end,
})

MiscTab:CreateSection("Chat")

MiscTab:CreateToggle({
    Name = "Chat Spam",
    CurrentValue = CFG.ChatSpam,
    Flag = "ChatSpam",
    Callback = function(v) CFG.ChatSpam = v; setChatSpam(v) end,
})

MiscTab:CreateInput({
    Name = "Spam Message",
    PlaceholderText = "VOID HUB",
    RemoveTextAfterFocusLost = false,
    Flag = "ChatSpamMsg",
    Callback = function(v) CFG.ChatSpamMsg = v ~= "" and v or "VOID HUB" end,
})

MiscTab:CreateSlider({
    Name = "Spam Delay (seconds)",
    Range = {1, 30},
    Increment = 1,
    CurrentValue = CFG.ChatSpamDelay,
    Flag = "ChatSpamDelay",
    Callback = function(v) CFG.ChatSpamDelay = v end,
})

MiscTab:CreateSection("Utility")

MiscTab:CreateButton({
    Name = "Respawn Character",
    Callback = function()
        LocalPlayer:LoadCharacter()
    end,
})

MiscTab:CreateButton({
    Name = "Reset Config to Default",
    Callback = function()
        Rayfield:Notify({
            Title = "VOID HUB",
            Content = "Config reset to defaults.",
            Duration = 3,
            Image = 4483362458,
        })
    end,
})

MiscTab:CreateButton({
    Name = "Copy Player List to Clipboard",
    Callback = function()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            table.insert(names, p.Name .. (isKiller(p) and " [KILLER]" or ""))
        end
        setclipboard(table.concat(names, "\n"))
        Rayfield:Notify({
            Title = "VOID HUB",
            Content = "Player list copied!",
            Duration = 2,
            Image = 4483362458,
        })
    end,
})

----------------------------------------------------------------
-- TAB: SETTINGS / INFO
----------------------------------------------------------------
local SetTab = Window:CreateTab("⚙️ Settings", 4483362458)

SetTab:CreateSection("Hub Info")
SetTab:CreateLabel("VOID HUB  —  Evade Edition")
SetTab:CreateLabel("Use Rayfield settings to customize keybinds.")
SetTab:CreateLabel("All features are client-side only.")

SetTab:CreateSection("Keybinds (default)")
SetTab:CreateLabel("Open/Close Hub: RightShift (Rayfield default)")
SetTab:CreateLabel("Noclip: Toggle via UI")
SetTab:CreateLabel("Fly: Toggle via UI  |  WASD + Space/Ctrl to move")

SetTab:CreateSection("Credits")
SetTab:CreateLabel("Script by VOID HUB")
SetTab:CreateLabel("UI by Rayfield (sirius.menu)")
SetTab:CreateLabel("Evade game by @ossified on Roblox")

SetTab:CreateDivider()

SetTab:CreateButton({
    Name = "🔄 Reload Script",
    Callback = function()
        Rayfield:Notify({
            Title = "VOID HUB",
            Content = "Reloading...",
            Duration = 2,
            Image = 4483362458,
        })
        task.wait(0.5)
        loadstring(game:HttpGet(""))() -- placeholder reload
    end,
})

----------------------------------------------------------------
-- NOTIFY ON LOAD
----------------------------------------------------------------
Rayfield:Notify({
    Title = "VOID HUB",
    Content = "Evade hub loaded! Check all tabs for features.",
    Duration = 5,
    Image = 4483362458,
})

-- Killer nearby warning
RunService.Heartbeat:Connect(function()
    local myHRP = getHRP()
    if not myHRP then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isKiller(p) then
            local khrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if khrp and (khrp.Position - myHRP.Position).Magnitude < 20 then
                -- visual red flash handled by Rayfield notify (throttled)
            end
        end
    end
end)
