--[[
    PHANTOM HUB — EVADE
    No dependencies. Pure custom UI.
    Nextbots are AI PNG monsters that chase players.
    Toggle: RightShift
]]

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local CoreGui      = game:GetService("CoreGui")
local HttpService  = game:GetService("HttpService")
local LP           = Players.LocalPlayer
local Cam          = workspace.CurrentCamera

----------------------------------------------------------------
-- SAFE GUI PARENT
----------------------------------------------------------------
local function safeParent(gui)
    if gethui then gui.Parent = gethui()
    elseif syn and syn.protect_gui then syn.protect_gui(gui); gui.Parent = CoreGui
    else gui.Parent = CoreGui end
end

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local CFG = {
    -- Movement
    WalkSpeed    = 16,
    JumpPower    = 50,
    BHop         = false,
    InfJump      = false,
    Noclip       = false,
    Fly          = false,
    FlySpeed     = 55,

    -- Game
    AvoidNextbot  = false,
    AvoidDist     = 28,
    AutoRevive    = false,
    AutoCarry     = false,
    AutoInteract  = false,
    AutoCola      = false,
    AutoWhistle   = false,
    AutoFarmXP    = false,
    AutoFarmCash  = false,
    AutoCollect   = false,

    -- Visual
    Fullbright       = false,
    NoFlicker        = false,
    NoDarkness       = false,
    NoCamShake       = false,
    RemoveBarriers   = false,
    CustomFOV        = false,
    FOVVal           = 90,
    FPSBoost         = false,
    ShowRoundTimer   = false,

    -- ESP
    ESPEnabled   = false,
    ESPPlayers   = true,
    ESPNextbots  = true,
    ESPNames     = true,
    ESPDist      = true,
    ESPHealth    = true,
    ESPMaxDist   = 600,

    -- Misc
    AntiAFK      = true,
    NoClip       = false,
    ChatSpam     = false,
    ChatMsg      = "PHANTOM HUB",
    ChatDelay    = 4,
}

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local conns        = {}
local flyBV, flyBG = nil, nil
local flyOn        = false
local lastBhop     = 0
local espSG, espCache = nil, {}
local nbEspCache   = {}
local origGrav     = workspace.Gravity
local origBright   = Lighting.Brightness
local origAmb      = Lighting.Ambient
local origOutAmb   = Lighting.OutdoorAmbient
local chatThread   = nil
local roundTimerLabel = nil

local function dc(k) if conns[k] then conns[k]:Disconnect(); conns[k]=nil end end
local function getChar() return LP.Character end
local function getHRP()  local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum()  local c=getChar(); return c and c:FindFirstChildOfClass("Humanoid") end
local function tw(o,p,t,s) TweenService:Create(o,TweenInfo.new(t or .15,s or Enum.EasingStyle.Quad,Enum.EasingDirection.Out),p):Play() end

----------------------------------------------------------------
-- NEXTBOT DETECTION
-- Nextbots in Evade are NPCs parented under workspace,
-- they have a "NextbotName" attribute OR are in a "Nextbots" folder
----------------------------------------------------------------
local function getNextbots()
    local bots = {}
    -- Check Nextbots folder
    local folder = workspace:FindFirstChild("Nextbots") or workspace:FindFirstChild("nextbots")
    if folder then
        for _, nb in ipairs(folder:GetChildren()) do
            if nb:IsA("Model") or nb:IsA("Part") or nb:IsA("BasePart") then
                table.insert(bots, nb)
            end
        end
    end
    -- Also scan workspace for models with nextbot attributes
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") then
            if obj:GetAttribute("NextbotName") or obj:GetAttribute("IsNextbot")
                or obj:FindFirstChild("NextbotImage") or obj:FindFirstChild("FaceGui") then
                -- avoid duplicates
                local found = false
                for _, b in ipairs(bots) do if b == obj then found=true; break end end
                if not found then table.insert(bots, obj) end
            end
        end
    end
    return bots
end

local function getNBRoot(nb)
    if nb:IsA("Model") then
        return nb:FindFirstChild("HumanoidRootPart") or nb:FindFirstChild("PrimaryPart") or nb.PrimaryPart
    elseif nb:IsA("BasePart") then return nb end
    return nil
end

----------------------------------------------------------------
-- MOVEMENT LOGIC
----------------------------------------------------------------
local function applyStats()
    local h = getHum(); if not h then return end
    h.WalkSpeed = CFG.WalkSpeed; h.JumpPower = CFG.JumpPower
end

local function setBHop(on)
    dc("bhop")
    if on then
        conns["bhop"] = UIS.JumpRequest:Connect(function()
            if tick()-lastBhop < 0.2 then return end
            lastBhop = tick()
            local r=getHRP(); local h=getHum()
            if not r or not h then return end
            if h.FloorMaterial ~= Enum.Material.Air then
                h:ChangeState(Enum.HumanoidStateType.Jumping)
                local v = r.AssemblyLinearVelocity
                r.AssemblyLinearVelocity = Vector3.new(v.X*1.08, 22, v.Z*1.08)
            end
        end)
    end
end

local function setInfJump(on)
    dc("infj")
    if on then conns["infj"] = UIS.JumpRequest:Connect(function()
        local h=getHum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end) end
end

local function setNoclip(on)
    dc("noclip")
    if on then
        conns["noclip"] = RunService.Stepped:Connect(function()
            local c=getChar(); if not c then return end
            for _,p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide=false end
            end
        end)
    else
        local c=getChar(); if not c then return end
        for _,p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide=true end
        end
    end
end

local function setFly(on)
    local r=getHRP(); if not r then return end
    if on and not flyOn then
        flyOn=true
        flyBV=Instance.new("BodyVelocity"); flyBV.MaxForce=Vector3.new(1e5,1e5,1e5); flyBV.Velocity=Vector3.zero; flyBV.Parent=r
        flyBG=Instance.new("BodyGyro"); flyBG.MaxTorque=Vector3.new(1e5,1e5,1e5); flyBG.P=1e4; flyBG.Parent=r
        conns["fly"]=RunService.Heartbeat:Connect(function()
            if not CFG.Fly then return end
            local cf=Cam.CFrame; local mv=Vector3.zero
            if UIS:IsKeyDown(Enum.KeyCode.W) then mv+=cf.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then mv-=cf.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then mv-=cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then mv+=cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then mv+=Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then mv-=Vector3.new(0,1,0) end
            flyBV.Velocity = mv.Magnitude>0 and mv.Unit*CFG.FlySpeed or Vector3.zero
            flyBG.CFrame = cf
        end)
    elseif not on and flyOn then
        flyOn=false; dc("fly")
        if flyBV then flyBV:Destroy(); flyBV=nil end
        if flyBG then flyBG:Destroy(); flyBG=nil end
    end
end

----------------------------------------------------------------
-- GAME FEATURES
----------------------------------------------------------------

-- Avoid Nextbots: push velocity away from nearest bot
local function setAvoidNextbot(on)
    dc("avoid")
    if on then conns["avoid"]=RunService.Heartbeat:Connect(function()
        local r=getHRP(); if not r then return end
        for _,nb in ipairs(getNextbots()) do
            local root=getNBRoot(nb)
            if root then
                local dist=(root.Position-r.Position).Magnitude
                if dist < CFG.AvoidDist then
                    local away=(r.Position-root.Position).Unit
                    r.AssemblyLinearVelocity=away*85+Vector3.new(0,30,0)
                end
            end
        end
    end) end
end

-- Auto Revive: walk to downed players and auto-revive via proximity
local function setAutoRevive(on)
    dc("revive")
    if not on then return end
    conns["revive"]=RunService.Heartbeat:Connect(function()
        local r=getHRP(); if not r then return end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP and p.Character then
                local ph=p.Character:FindFirstChildOfClass("Humanoid")
                local pr=p.Character:FindFirstChild("HumanoidRootPart")
                -- "Downed" state: health 0 but character still exists with a ReviveGui or downed value
                local downed = p.Character:FindFirstChild("Downed") or
                    (ph and ph.Health<=0 and ph.Health>-1)
                if downed and pr then
                    local dist=(pr.Position-r.Position).Magnitude
                    if dist<6 then
                        -- Fire revive remote if it exists
                        local rs=game:GetService("ReplicatedStorage")
                        local revRemote = rs:FindFirstChild("Revive") or rs:FindFirstChild("RevivePlayer")
                            or rs:FindFirstChild("Events") and rs.Events:FindFirstChild("Revive")
                        if revRemote and revRemote:IsA("RemoteEvent") then
                            revRemote:FireServer(p)
                        end
                    elseif dist<30 then
                        -- Walk toward downed player
                        local h=getHum()
                        if h then h:MoveTo(pr.Position) end
                    end
                end
            end
        end
    end)
end

-- Auto Interact: press E on nearby interact prompts
local function setAutoInteract(on)
    dc("interact")
    if not on then return end
    conns["interact"]=RunService.Heartbeat:Connect(function()
        local r=getHRP(); if not r then return end
        for _,v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ProximityPrompt") then
                local part=v.Parent
                if part and part:IsA("BasePart") then
                    local dist=(part.Position-r.Position).Magnitude
                    if dist <= v.MaxActivationDistance then
                        v.Triggered:Fire(LP)
                        -- also try the Interact remote
                        local rs=game:GetService("ReplicatedStorage")
                        local rem=rs:FindFirstChild("Interact") or rs:FindFirstChild("InteractEvent")
                        if rem then rem:FireServer(v) end
                    end
                end
            end
        end
    end)
end

-- Auto Collect: walk to collectables (coins, items, event items)
local function setAutoCollect(on)
    dc("collect")
    if not on then return end
    conns["collect"]=RunService.Heartbeat:Connect(function()
        local r=getHRP(); if not r then return end
        local best,bd=nil,math.huge
        for _,v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                local n=v.Name:lower()
                if n:find("coin") or n:find("cash") or n:find("collectable")
                    or n:find("rose") or n:find("chocolate") or n:find("item") or n:find("pickup") then
                    local d=(v.Position-r.Position).Magnitude
                    if d<bd then bd=d; best=v end
                end
            end
        end
        if best and bd<50 then
            local h=getHum()
            if h then h:MoveTo(best.Position) end
        end
    end)
end

-- Auto Cola: use Cola item when near (interact remote)
local function setAutoCola(on)
    dc("cola")
    if not on then return end
    conns["cola"]=RunService.Heartbeat:Connect(function()
        local rs=game:GetService("ReplicatedStorage")
        local useItem=rs:FindFirstChild("UseItem") or rs:FindFirstChild("UseTool") or
            (rs:FindFirstChild("Events") and rs.Events:FindFirstChild("UseItem"))
        if useItem then
            -- find cola in backpack or character
            for _,t in ipairs(LP:FindFirstChildOfClass("Backpack"):GetChildren()) do
                if t.Name:lower():find("cola") then
                    pcall(function() useItem:FireServer(t) end)
                end
            end
        end
    end)
end

-- Auto Whistle: fire whistle remote (lures nextbots away)
local function setAutoWhistle(on)
    dc("whistle")
    if not on then return end
    conns["whistle"]=task.spawn(function()
        while CFG.AutoWhistle do
            local rs=game:GetService("ReplicatedStorage")
            local whistleEv=rs:FindFirstChild("Whistle") or
                (rs:FindFirstChild("Events") and rs.Events:FindFirstChild("Whistle"))
            if whistleEv then pcall(function() whistleEv:FireServer() end) end
            task.wait(3.5)
        end
    end)
end

-- FPS Boost: disable unnecessary effects
local function setFPSBoost(on)
    if on then
        Lighting.GlobalShadows=false
        for _,e in ipairs(Lighting:GetChildren()) do
            if e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect")
                or e:IsA("DepthOfFieldEffect") then
                e.Enabled=false
            end
        end
        workspace.StreamingEnabled = false
        game:GetService("RunService"):Set3dRenderingEnabled and
            pcall(function() end) -- can't disable but reduce particles
        for _,v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                v.Enabled=false
            end
        end
    end
end

-- No Camera Shake: zero shake magnitude
local function setNoCamShake(on)
    dc("camshake")
    if on then
        conns["camshake"]=RunService.RenderStepped:Connect(function()
            Cam.HeadLocked=false
        end)
    end
end

-- No Light Flicker: lock lighting
local function setNoFlicker(on)
    dc("flicker")
    if on then
        local savedBrightness=Lighting.Brightness
        conns["flicker"]=RunService.Heartbeat:Connect(function()
            Lighting.Brightness=savedBrightness
        end)
    end
end

-- Remove Darkness: brighten lighting  
local function setNoDarkness(on)
    if on then
        Lighting.Brightness=3
        Lighting.Ambient=Color3.fromRGB(200,200,200)
        Lighting.OutdoorAmbient=Color3.fromRGB(200,200,200)
    else
        Lighting.Brightness=origBright
        Lighting.Ambient=origAmb
        Lighting.OutdoorAmbient=origOutAmb
    end
end

-- Fullbright
local function setFullbright(on)
    if on then
        Lighting.Brightness=8
        Lighting.Ambient=Color3.new(1,1,1)
        Lighting.OutdoorAmbient=Color3.new(1,1,1)
        Lighting.ClockTime=14; Lighting.FogEnd=1e6
    else
        Lighting.Brightness=origBright; Lighting.Ambient=origAmb
        Lighting.OutdoorAmbient=origOutAmb
    end
end

-- Remove Barriers: make barrier/door parts non-collidable
local function setRemoveBarriers(on)
    for _,v in ipairs(workspace:GetDescendants()) do
        local n=v.Name:lower()
        if v:IsA("BasePart") and (n:find("barrier") or n:find("door") or n:find("gate") or n:find("wall")) then
            v.CanCollide = not on
            v.Transparency = on and 0.7 or v.Transparency
        end
    end
end

-- Anti AFK
local function setAntiAFK(on)
    dc("afk")
    if on then
        local vu=Instance.new("VirtualUser"); vu.Parent=LP
        conns["afk"]=LP.Idled:Connect(function() vu:CaptureController(); vu:ClickButton2(Vector2.new()) end)
    end
end

-- Chat Spam
local function setChatSpam(on)
    if chatThread then task.cancel(chatThread); chatThread=nil end
    if not on then return end
    chatThread=task.spawn(function()
        while CFG.ChatSpam do
            local rs=game:GetService("ReplicatedStorage")
            local ev=rs:FindFirstChild("DefaultChatSystemChatEvents")
            if ev then
                local sr=ev:FindFirstChild("SayMessageRequest")
                if sr then pcall(function() sr:FireServer(CFG.ChatMsg,"All") end) end
            end
            task.wait(CFG.ChatDelay)
        end
    end)
end

-- Round Timer display
local function buildRoundTimer()
    if roundTimerLabel then roundTimerLabel.Parent.Parent:Destroy(); roundTimerLabel=nil end
    if not CFG.ShowRoundTimer then return end
    local sg=Instance.new("ScreenGui"); sg.Name="PhantomTimer"; sg.ResetOnSpawn=false
    safeParent(sg)
    local f=Instance.new("Frame",sg)
    f.Size=UDim2.new(0,120,0,32); f.Position=UDim2.new(0.5,-60,0,8)
    f.BackgroundColor3=Color3.fromRGB(10,10,18); f.BackgroundTransparency=0.25; f.BorderSizePixel=0
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
    local l=Instance.new("TextLabel",f)
    l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1
    l.Font=Enum.Font.GothamBold; l.TextSize=15
    l.TextColor3=Color3.fromRGB(255,220,80); l.Text="⏱ --:--"
    roundTimerLabel=l
    -- try to find round timer value in game
    dc("timer")
    conns["timer"]=RunService.Heartbeat:Connect(function()
        local rs=game:GetService("ReplicatedStorage")
        local tv=rs:FindFirstChild("RoundTime") or rs:FindFirstChild("TimeLeft") or
            workspace:FindFirstChild("RoundTime") or workspace:FindFirstChild("TimeLeft")
        if tv and (tv:IsA("IntValue") or tv:IsA("NumberValue")) then
            local secs=math.floor(tv.Value)
            l.Text=string.format("⏱ %d:%02d", math.floor(secs/60), secs%60)
        end
    end)
end

-- ESP setup
espSG=Instance.new("ScreenGui"); espSG.Name="PhantomESP"; espSG.ResetOnSpawn=false
safeParent(espSG)

local function makePlayerESP(p)
    if espCache[p] then return espCache[p] end
    local g=Instance.new("BillboardGui")
    g.AlwaysOnTop=true; g.Size=UDim2.new(0,110,0,60); g.StudsOffset=Vector3.new(0,3.5,0); g.LightInfluence=0
    -- name
    local nl=Instance.new("TextLabel",g); nl.Name="N"
    nl.Size=UDim2.new(1,0,0,14); nl.Position=UDim2.new(0,0,0,-16)
    nl.BackgroundTransparency=1; nl.Font=Enum.Font.GothamBold; nl.TextSize=12
    nl.TextColor3=Color3.fromRGB(120,210,255); nl.TextStrokeTransparency=0.3; nl.TextStrokeColor3=Color3.new(0,0,0)
    nl.Text=p.Name
    -- dist
    local dl=Instance.new("TextLabel",g); dl.Name="D"
    dl.Size=UDim2.new(1,0,0,12); dl.Position=UDim2.new(0,0,1,2)
    dl.BackgroundTransparency=1; dl.Font=Enum.Font.Gotham; dl.TextSize=11
    dl.TextColor3=Color3.fromRGB(160,160,255); dl.TextStrokeTransparency=0.3; dl.TextStrokeColor3=Color3.new(0,0,0)
    dl.Text=""
    -- health bar bg
    local hbg=Instance.new("Frame",g); hbg.Name="HBG"
    hbg.Size=UDim2.new(0,4,1,0); hbg.Position=UDim2.new(0,-7,0,0)
    hbg.BackgroundColor3=Color3.fromRGB(30,30,30); hbg.BorderSizePixel=0
    Instance.new("UICorner",hbg).CornerRadius=UDim.new(0,2)
    local hf=Instance.new("Frame",hbg); hf.Name="HF"
    hf.Size=UDim2.new(1,0,1,0); hf.BackgroundColor3=Color3.fromRGB(0,220,100); hf.BorderSizePixel=0
    Instance.new("UICorner",hf).CornerRadius=UDim.new(0,2)
    espCache[p]=g; return g
end

local function makeNextbotESP(nb)
    if nbEspCache[nb] then return nbEspCache[nb] end
    local g=Instance.new("BillboardGui")
    g.AlwaysOnTop=true; g.Size=UDim2.new(0,110,0,50); g.StudsOffset=Vector3.new(0,4,0); g.LightInfluence=0
    local bg=Instance.new("Frame",g)
    bg.Size=UDim2.new(1,0,1,0); bg.BackgroundColor3=Color3.fromRGB(200,0,0); bg.BackgroundTransparency=0.6
    bg.BorderSizePixel=0; Instance.new("UICorner",bg).CornerRadius=UDim.new(0,4)
    local nl=Instance.new("TextLabel",g); nl.Name="N"
    nl.Size=UDim2.new(1,0,0,16); nl.Position=UDim2.new(0,0,0,-18)
    nl.BackgroundTransparency=1; nl.Font=Enum.Font.GothamBold; nl.TextSize=13
    nl.TextColor3=Color3.fromRGB(255,60,60); nl.TextStrokeTransparency=0.2; nl.TextStrokeColor3=Color3.new(0,0,0)
    nl.Text="⚠ "..nb.Name
    local dl=Instance.new("TextLabel",g); dl.Name="D"
    dl.Size=UDim2.new(1,0,0,13); dl.Position=UDim2.new(0,0,1,2)
    dl.BackgroundTransparency=1; dl.Font=Enum.Font.GothamBold; dl.TextSize=12
    dl.TextColor3=Color3.fromRGB(255,120,120); dl.TextStrokeTransparency=0.3; dl.TextStrokeColor3=Color3.new(0,0,0)
    dl.Text=""
    nbEspCache[nb]=g; return g
end

RunService.RenderStepped:Connect(function()
    if not CFG.ESPEnabled then
        for _,g in pairs(espCache) do g.Parent=nil end
        for _,g in pairs(nbEspCache) do g.Parent=nil end
        return
    end
    local myR=getHRP()
    -- Player ESP
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP then continue end
        local char=p.Character
        local hrp=char and char:FindFirstChild("HumanoidRootPart")
        local head=char and char:FindFirstChild("Head")
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local alive=hrp and head and hum and hum.Health>0
        local dist=myR and hrp and (hrp.Position-myR.Position).Magnitude or 999
        if alive and CFG.ESPPlayers and dist<=CFG.ESPMaxDist then
            local esp=makePlayerESP(p)
            esp.Adornee=head; esp.Parent=espSG
            local nl=esp:FindFirstChild("N"); if nl then nl.Visible=CFG.ESPNames; nl.Text=p.Name end
            local dl=esp:FindFirstChild("D"); if dl then dl.Visible=CFG.ESPDist; dl.Text=math.floor(dist).."m" end
            local hbg=esp:FindFirstChild("HBG"); local hf=hbg and hbg:FindFirstChild("HF")
            if hbg then hbg.Visible=CFG.ESPHealth end
            if hf and CFG.ESPHealth then
                local frac=math.clamp(hum.Health/hum.MaxHealth,0,1)
                hf.Size=UDim2.new(1,0,frac,0)
                hf.BackgroundColor3=Color3.fromRGB(math.floor((1-frac)*255),math.floor(frac*200),50)
            end
        else
            local esp=espCache[p]; if esp then esp.Parent=nil end
        end
    end
    -- cleanup dead players
    for p,g in pairs(espCache) do
        if not p.Parent then g:Destroy(); espCache[p]=nil end
    end
    -- Nextbot ESP
    if CFG.ESPNextbots then
        for _,nb in ipairs(getNextbots()) do
            local root=getNBRoot(nb)
            local dist=myR and root and (root.Position-myR.Position).Magnitude or 999
            if root and dist<=CFG.ESPMaxDist then
                local esp=makeNextbotESP(nb)
                esp.Adornee=root; esp.Parent=espSG
                local dl=esp:FindFirstChild("D"); if dl then dl.Text=math.floor(dist).."m" end
            else
                local esp=nbEspCache[nb]; if esp then esp.Parent=nil end
            end
        end
    else
        for _,g in pairs(nbEspCache) do g.Parent=nil end
    end
    for nb,g in pairs(nbEspCache) do
        if not nb.Parent then g:Destroy(); nbEspCache[nb]=nil end
    end
end)

-- Spawn init
local function onSpawn(char)
    char:WaitForChild("Humanoid"); char:WaitForChild("HumanoidRootPart"); task.wait(0.5)
    applyStats()
    setBHop(CFG.BHop); setInfJump(CFG.InfJump); setNoclip(CFG.Noclip)
    if CFG.Fly then setFly(true) end
    setAvoidNextbot(CFG.AvoidNextbot)
    setAutoRevive(CFG.AutoRevive); setAutoInteract(CFG.AutoInteract)
    setAutoCollect(CFG.AutoCollect)
end
if LP.Character then onSpawn(LP.Character) end
LP.CharacterAdded:Connect(onSpawn)
setAntiAFK(CFG.AntiAFK)

----------------------------------------------------------------
-- ══════════════════════════════════════════════
--                 PHANTOM HUB UI
-- ══════════════════════════════════════════════
----------------------------------------------------------------
local SG=Instance.new("ScreenGui"); SG.Name="PhantomHub"; SG.ResetOnSpawn=false
SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; SG.DisplayOrder=100
safeParent(SG)

-- Theme
local T={
    bg0    = Color3.fromRGB(9,9,16),
    bg1    = Color3.fromRGB(14,14,24),
    bg2    = Color3.fromRGB(20,20,34),
    bg3    = Color3.fromRGB(26,26,44),
    border = Color3.fromRGB(40,40,72),
    acc    = Color3.fromRGB(100,80,255),
    accHi  = Color3.fromRGB(140,120,255),
    accLo  = Color3.fromRGB(55,42,140),
    green  = Color3.fromRGB(0,205,105),
    red    = Color3.fromRGB(215,45,65),
    yellow = Color3.fromRGB(255,205,50),
    white  = Color3.fromRGB(230,230,255),
    muted  = Color3.fromRGB(110,110,150),
    nb     = Color3.fromRGB(255,55,55),
}

local function mkCorner(p,r) local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r or 8); return c end
local function mkStroke(p,c2,t2) local s=Instance.new("UIStroke",p); s.Color=c2 or T.border; s.Thickness=t2 or 1; return s end
local function mkPad(p,l,r2,top,b)
    local pad=Instance.new("UIPadding",p)
    pad.PaddingLeft=UDim.new(0,l or 0); pad.PaddingRight=UDim.new(0,r2 or 0)
    pad.PaddingTop=UDim.new(0,top or 0); pad.PaddingBottom=UDim.new(0,b or 0)
end
local function mkList(p,dir,pad2)
    local l=Instance.new("UIListLayout",p)
    l.FillDirection=dir or Enum.FillDirection.Vertical
    l.Padding=UDim.new(0,pad2 or 0); l.SortOrder=Enum.SortOrder.LayoutOrder; return l end

-- Drag helper
local function makeDraggable(handle, target)
    local dragging,dStart,dPos=false
    handle.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true; dStart=i.Position; dPos=target.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-dStart
            target.Position=UDim2.new(dPos.X.Scale,dPos.X.Offset+d.X,dPos.Y.Scale,dPos.Y.Offset+d.Y)
        end
    end)
end

-- Floating icon
local Icon=Instance.new("TextButton",SG)
Icon.Size=UDim2.new(0,42,0,42); Icon.Position=UDim2.new(0,14,0.45,0)
Icon.BackgroundColor3=T.bg2; Icon.Text=""; Icon.AutoButtonColor=false; Icon.ZIndex=20
mkCorner(Icon,12); mkStroke(Icon,T.acc,2)
local ILbl=Instance.new("TextLabel",Icon)
ILbl.Size=UDim2.new(1,0,1,0); ILbl.BackgroundTransparency=1; ILbl.Text="👻"
ILbl.TextSize=20; ILbl.TextColor3=T.white; ILbl.Font=Enum.Font.GothamBold
ILbl.TextXAlignment=Enum.TextXAlignment.Center; ILbl.TextYAlignment=Enum.TextYAlignment.Center; ILbl.ZIndex=21
-- pulse
task.spawn(function() while true do tw(ILbl,{TextTransparency=0.5},0.9,Enum.EasingStyle.Sine) task.wait(0.9) tw(ILbl,{TextTransparency=0},0.9,Enum.EasingStyle.Sine) task.wait(0.9) end end)
makeDraggable(Icon,Icon)

-- Main window
local Win=Instance.new("Frame",SG)
Win.Size=UDim2.new(0,460,0,490); Win.Position=UDim2.new(0.5,-230,0.5,-245)
Win.BackgroundColor3=T.bg0; Win.Visible=false; Win.ZIndex=10; Win.Active=true; Win.ClipsDescendants=true
mkCorner(Win,14); mkStroke(Win,T.acc,2)
local WinGrad=Instance.new("UIGradient",Win)
WinGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(16,12,30)),ColorSequenceKeypoint.new(1,Color3.fromRGB(8,8,16))})
WinGrad.Rotation=140

-- Shadow
local Shad=Instance.new("Frame",SG)
Shad.Size=UDim2.new(0,480,0,510); Shad.BackgroundColor3=Color3.new(0,0,0)
Shad.BackgroundTransparency=0.52; Shad.ZIndex=9; Shad.Visible=false; mkCorner(Shad,18)
local function syncShad() Shad.Position=UDim2.new(Win.Position.X.Scale,Win.Position.X.Offset-10,Win.Position.Y.Scale,Win.Position.Y.Offset-10) end
syncShad()

-- Header
local Hdr=Instance.new("Frame",Win); Hdr.Size=UDim2.new(1,0,0,50); Hdr.BackgroundColor3=T.bg2; Hdr.ZIndex=11; mkCorner(Hdr,14)
local HFix=Instance.new("Frame",Hdr); HFix.Size=UDim2.new(1,0,0.5,0); HFix.Position=UDim2.new(0,0,0.5,0); HFix.BackgroundColor3=T.bg2; HFix.BorderSizePixel=0; HFix.ZIndex=11
local HGrd=Instance.new("UIGradient",Hdr); HGrd.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(65,45,155)),ColorSequenceKeypoint.new(1,T.bg2)}); HGrd.Rotation=90

local TitleL=Instance.new("TextLabel",Hdr); TitleL.Size=UDim2.new(0,200,1,0); TitleL.Position=UDim2.new(0,14,0,0)
TitleL.BackgroundTransparency=1; TitleL.Text="👻  PHANTOM HUB"; TitleL.TextSize=15; TitleL.TextColor3=T.white
TitleL.Font=Enum.Font.GothamBold; TitleL.TextXAlignment=Enum.TextXAlignment.Left; TitleL.ZIndex=12

local SubL=Instance.new("TextLabel",Hdr); SubL.Size=UDim2.new(0,200,0,12); SubL.Position=UDim2.new(0,14,1,-14)
SubL.BackgroundTransparency=1; SubL.Text="evade  •  no dependencies"; SubL.TextSize=10; SubL.TextColor3=T.muted
SubL.Font=Enum.Font.Gotham; SubL.TextXAlignment=Enum.TextXAlignment.Left; SubL.ZIndex=12

-- Close
local CBtn=Instance.new("TextButton",Hdr); CBtn.Size=UDim2.new(0,24,0,24); CBtn.Position=UDim2.new(1,-32,0.5,-12)
CBtn.BackgroundColor3=Color3.fromRGB(155,30,50); CBtn.Text="✕"; CBtn.TextSize=12; CBtn.TextColor3=Color3.new(1,1,1)
CBtn.Font=Enum.Font.GothamBold; CBtn.AutoButtonColor=false; CBtn.ZIndex=13; mkCorner(CBtn,6)
CBtn.MouseEnter:Connect(function() tw(CBtn,{BackgroundColor3=T.red},0.1) end)
CBtn.MouseLeave:Connect(function() tw(CBtn,{BackgroundColor3=Color3.fromRGB(155,30,50)},0.1) end)
CBtn.MouseButton1Click:Connect(function()
    tw(Win,{Size=UDim2.new(0,460,0,0)},0.15); task.wait(0.17)
    Win.Visible=false; Shad.Visible=false; Win.Size=UDim2.new(0,460,0,490)
end)

-- Minimize
local minimized=false
local MinBtn=Instance.new("TextButton",Hdr); MinBtn.Size=UDim2.new(0,24,0,24); MinBtn.Position=UDim2.new(1,-60,0.5,-12)
MinBtn.BackgroundColor3=T.bg3; MinBtn.Text="—"; MinBtn.TextSize=12; MinBtn.TextColor3=T.muted
MinBtn.Font=Enum.Font.GothamBold; MinBtn.AutoButtonColor=false; MinBtn.ZIndex=13; mkCorner(MinBtn,6)
MinBtn.MouseButton1Click:Connect(function()
    minimized=not minimized
    tw(Win,{Size=minimized and UDim2.new(0,460,0,50) or UDim2.new(0,460,0,490)},0.2,Enum.EasingStyle.Back)
end)

makeDraggable(Hdr,Win); -- make window draggable by header

-- Status bar
local Sb=Instance.new("Frame",Win); Sb.Size=UDim2.new(1,0,0,18); Sb.Position=UDim2.new(0,0,1,-18)
Sb.BackgroundColor3=T.bg2; Sb.ZIndex=11
local SbT=Instance.new("TextLabel",Sb); SbT.Size=UDim2.new(1,-10,1,0); SbT.Position=UDim2.new(0,8,0,0)
SbT.BackgroundTransparency=1; SbT.TextSize=10; SbT.TextColor3=T.muted; SbT.Font=Enum.Font.Gotham
SbT.TextXAlignment=Enum.TextXAlignment.Left; SbT.ZIndex=12; SbT.Text="phantom hub  •  loaded"
local function setStatus(t2) SbT.Text=t2; task.delay(3,function() if SbT.Text==t2 then SbT.Text="phantom hub  •  ready" end end) end

-- Tab bar
local TabBar=Instance.new("Frame",Win); TabBar.Size=UDim2.new(1,0,0,32); TabBar.Position=UDim2.new(0,0,0,50)
TabBar.BackgroundColor3=T.bg1; TabBar.ZIndex=11
mkList(TabBar,Enum.FillDirection.Horizontal,2)
mkPad(TabBar,6,6,4,4)

local TabSep=Instance.new("Frame",Win); TabSep.Size=UDim2.new(1,0,0,1); TabSep.Position=UDim2.new(0,0,0,82)
TabSep.BackgroundColor3=T.acc; TabSep.BackgroundTransparency=0.65; TabSep.BorderSizePixel=0; TabSep.ZIndex=11

-- Content
local Content=Instance.new("Frame",Win); Content.Size=UDim2.new(1,0,1,-102); Content.Position=UDim2.new(0,0,0,83)
Content.BackgroundTransparency=1; Content.ZIndex=10; Content.ClipsDescendants=true

-- Make scrolling page
local function mkPage()
    local sf=Instance.new("ScrollingFrame",Content)
    sf.Size=UDim2.new(1,0,1,0); sf.BackgroundTransparency=1
    sf.ScrollBarThickness=3; sf.ScrollBarImageColor3=T.acc
    sf.CanvasSize=UDim2.new(0,0,0,0); sf.ZIndex=11; sf.Visible=false
    local ly=mkList(sf); mkPad(sf,10,10,8,8)
    ly.Padding=UDim.new(0,6)
    ly:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sf.CanvasSize=UDim2.new(0,0,0,ly.AbsoluteContentSize.Y+20)
    end)
    return sf
end

-- Section label
local function mkSection(parent,title,order)
    local f=Instance.new("Frame",parent); f.Size=UDim2.new(1,0,0,20); f.BackgroundTransparency=1; f.ZIndex=12; f.LayoutOrder=order
    local line=Instance.new("Frame",f); line.Size=UDim2.new(1,0,0,1); line.Position=UDim2.new(0,0,0.5,0)
    line.BackgroundColor3=T.acc; line.BackgroundTransparency=0.6; line.BorderSizePixel=0; line.ZIndex=12
    local bg=Instance.new("Frame",f); bg.AutomaticSize=Enum.AutomaticSize.X; bg.Size=UDim2.new(0,0,1,0)
    bg.BackgroundColor3=T.bg0; bg.BorderSizePixel=0; bg.ZIndex=13; mkPad(bg,0,8,0,0)
    local l=Instance.new("TextLabel",bg); l.BackgroundTransparency=1; l.Text="  "..title
    l.TextSize=10; l.TextColor3=T.acc; l.Font=Enum.Font.GothamBold
    l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=14; l.AutomaticSize=Enum.AutomaticSize.XY
end

-- Toggle row
local function mkToggle(parent,title,desc,cfgKey,order,cb)
    local Row=Instance.new("TextButton",parent)
    Row.Size=UDim2.new(1,0,0,desc~="" and 48 or 40)
    Row.BackgroundColor3=T.bg2; Row.Text=""; Row.AutoButtonColor=false; Row.ZIndex=12; Row.LayoutOrder=order
    mkCorner(Row,8); mkStroke(Row,T.border,1)
    mkPad(Row,12,12,0,0)

    local Tf=Instance.new("Frame",Row); Tf.Size=UDim2.new(1,-52,1,0); Tf.BackgroundTransparency=1; Tf.ZIndex=13
    mkPad(Tf,0,0,6,6); mkList(Tf)

    local tl=Instance.new("TextLabel",Tf); tl.Size=UDim2.new(1,0,0,16); tl.BackgroundTransparency=1
    tl.Text=title; tl.TextSize=13; tl.TextColor3=T.white; tl.Font=Enum.Font.GothamBold
    tl.TextXAlignment=Enum.TextXAlignment.Left; tl.ZIndex=13; tl.LayoutOrder=1

    if desc and desc~="" then
        local dl=Instance.new("TextLabel",Tf); dl.Size=UDim2.new(1,0,0,13); dl.BackgroundTransparency=1
        dl.Text=desc; dl.TextSize=11; dl.TextColor3=T.muted; dl.Font=Enum.Font.Gotham
        dl.TextXAlignment=Enum.TextXAlignment.Left; dl.ZIndex=13; dl.LayoutOrder=2
    end

    local Pill=Instance.new("Frame",Row); Pill.Size=UDim2.new(0,36,0,18); Pill.Position=UDim2.new(1,-48,0.5,-9)
    Pill.BackgroundColor3=T.red; Pill.ZIndex=13; mkCorner(Pill,9)
    local Dot=Instance.new("Frame",Pill); Dot.Size=UDim2.new(0,12,0,12); Dot.Position=UDim2.new(0,3,0.5,-6)
    Dot.BackgroundColor3=Color3.new(1,1,1); Dot.ZIndex=14; mkCorner(Dot,6)

    local function refresh()
        local on=CFG[cfgKey]
        tw(Pill,{BackgroundColor3=on and T.green or T.red},0.15)
        tw(Dot,{Position=on and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)},0.15)
        tw(Row,{BackgroundColor3=on and Color3.fromRGB(16,26,20) or T.bg2},0.12)
    end
    refresh()

    Row.MouseButton1Click:Connect(function()
        CFG[cfgKey]=not CFG[cfgKey]; refresh()
        if cb then cb(CFG[cfgKey]) end
        setStatus((CFG[cfgKey] and "on" or "off").."  •  "..title:lower())
    end)
    Row.MouseEnter:Connect(function() if not CFG[cfgKey] then tw(Row,{BackgroundColor3=Color3.fromRGB(22,22,38)},0.1) end end)
    Row.MouseLeave:Connect(function() if not CFG[cfgKey] then tw(Row,{BackgroundColor3=T.bg2},0.1) end end)
end

-- Slider row
local function mkSlider(parent,title,min2,max2,def,cfgKey,order,suffix,dec,cb)
    local C=Instance.new("Frame",parent); C.Size=UDim2.new(1,0,0,58); C.BackgroundColor3=T.bg2
    C.ZIndex=12; C.LayoutOrder=order; mkCorner(C,8); mkStroke(C,T.border,1); mkPad(C,12,12,8,0)

    local Top=Instance.new("Frame",C); Top.Size=UDim2.new(1,0,0,18); Top.BackgroundTransparency=1; Top.ZIndex=13
    local NL=Instance.new("TextLabel",Top); NL.Size=UDim2.new(0.65,0,1,0); NL.BackgroundTransparency=1
    NL.Text=title; NL.TextSize=12; NL.TextColor3=T.muted; NL.Font=Enum.Font.Gotham; NL.TextXAlignment=Enum.TextXAlignment.Left; NL.ZIndex=13
    local VL=Instance.new("TextLabel",Top); VL.Size=UDim2.new(0.35,0,1,0); VL.Position=UDim2.new(0.65,0,0,0)
    VL.BackgroundTransparency=1; VL.TextSize=13; VL.TextColor3=T.accHi; VL.Font=Enum.Font.GothamBold
    VL.TextXAlignment=Enum.TextXAlignment.Right; VL.ZIndex=13

    local TBG=Instance.new("Frame",C); TBG.Size=UDim2.new(1,0,0,7); TBG.Position=UDim2.new(0,0,0,28)
    TBG.BackgroundColor3=Color3.fromRGB(22,22,42); TBG.ZIndex=13; mkCorner(TBG,4)
    local Fill=Instance.new("Frame",TBG); Fill.Size=UDim2.new(0,0,1,0); Fill.BackgroundColor3=T.acc; Fill.ZIndex=14; mkCorner(Fill,4)
    Instance.new("UIGradient",Fill).Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T.accHi),ColorSequenceKeypoint.new(1,T.accLo)})
    local Knob=Instance.new("Frame",TBG); Knob.Size=UDim2.new(0,14,0,14); Knob.AnchorPoint=Vector2.new(0.5,0.5)
    Knob.Position=UDim2.new(0,0,0.5,0); Knob.BackgroundColor3=Color3.new(1,1,1); Knob.ZIndex=15; mkCorner(Knob,7)
    mkStroke(Knob,T.acc,2)

    local function set(v)
        v=math.clamp(v,min2,max2); if not dec then v=math.round(v) end
        CFG[cfgKey]=v; local f=(v-min2)/(max2-min2)
        Fill.Size=UDim2.new(f,0,1,0); Knob.Position=UDim2.new(f,0,0.5,0)
        VL.Text=(dec and string.format("%.1f",v) or tostring(v))..(suffix or "")
        if cb then cb(v) end
    end
    set(def)

    local drag=false
    TBG.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
    UIS.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local f=math.clamp((i.Position.X-TBG.AbsolutePosition.X)/TBG.AbsoluteSize.X,0,1)
            set(min2+(max2-min2)*f)
        end
    end)
end

-- Button row
local function mkButton(parent,title,order,cb)
    local Btn=Instance.new("TextButton",parent); Btn.Size=UDim2.new(1,0,0,38)
    Btn.BackgroundColor3=T.bg3; Btn.Text=""; Btn.AutoButtonColor=false; Btn.ZIndex=12; Btn.LayoutOrder=order
    mkCorner(Btn,8); mkStroke(Btn,T.acc,1); mkPad(Btn,12,12,0,0)
    local l=Instance.new("TextLabel",Btn); l.Size=UDim2.new(1,-26,1,0); l.BackgroundTransparency=1
    l.Text=title; l.TextSize=13; l.TextColor3=T.white; l.Font=Enum.Font.GothamBold
    l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=13
    local ar=Instance.new("TextLabel",Btn); ar.Size=UDim2.new(0,22,1,0); ar.Position=UDim2.new(1,-24,0,0)
    ar.BackgroundTransparency=1; ar.Text="›"; ar.TextSize=18; ar.TextColor3=T.acc; ar.Font=Enum.Font.GothamBold; ar.ZIndex=13
    Btn.MouseEnter:Connect(function() tw(Btn,{BackgroundColor3=Color3.fromRGB(28,24,50)},0.1) end)
    Btn.MouseLeave:Connect(function() tw(Btn,{BackgroundColor3=T.bg3},0.1) end)
    Btn.MouseButton1Click:Connect(function()
        tw(Btn,{BackgroundColor3=T.accLo},0.07); task.delay(0.14,function() tw(Btn,{BackgroundColor3=T.bg3},0.12) end)
        if cb then cb() end; setStatus("ran  •  "..title:lower())
    end)
end

-- Input row
local function mkInput(parent,title,placeholder,cfgKey,order,cb)
    local C=Instance.new("Frame",parent); C.Size=UDim2.new(1,0,0,54); C.BackgroundColor3=T.bg2
    C.ZIndex=12; C.LayoutOrder=order; mkCorner(C,8); mkStroke(C,T.border,1); mkPad(C,12,12,8,6)
    local nl=Instance.new("TextLabel",C); nl.Size=UDim2.new(1,0,0,15); nl.BackgroundTransparency=1
    nl.Text=title; nl.TextSize=11; nl.TextColor3=T.muted; nl.Font=Enum.Font.Gotham; nl.TextXAlignment=Enum.TextXAlignment.Left; nl.ZIndex=13
    local box=Instance.new("TextBox",C); box.Size=UDim2.new(1,0,0,24); box.Position=UDim2.new(0,0,0,22)
    box.BackgroundColor3=Color3.fromRGB(14,14,26); box.Text=tostring(CFG[cfgKey] or "")
    box.PlaceholderText=placeholder or ""; box.TextColor3=T.white; box.PlaceholderColor3=T.muted
    box.Font=Enum.Font.Gotham; box.TextSize=12; box.ClearTextOnFocus=false; box.ZIndex=13
    mkCorner(box,5); mkStroke(box,T.border,1); mkPad(box,6,6,0,0)
    box.FocusLost:Connect(function() CFG[cfgKey]=box.Text; if cb then cb(box.Text) end end)
end

----------------------------------------------------------------
-- TABS
----------------------------------------------------------------
local TABS={"Movement","Game","Visuals","ESP","Misc"}
local tabs={}
local activeTab=""

local function switchTab(name)
    for n,d in pairs(tabs) do
        local on=n==name
        tw(d.btn,{BackgroundColor3=on and T.acc or T.bg3},0.15)
        d.btn.TextColor3=on and T.white or T.muted
        d.page.Visible=on
    end
    activeTab=name
    setStatus("tab  •  "..name:lower())
end

for i,name in ipairs(TABS) do
    local btn=Instance.new("TextButton",TabBar)
    btn.Size=UDim2.new(0,74,0,24); btn.BackgroundColor3=T.bg3
    btn.Text=name; btn.TextSize=11; btn.TextColor3=T.muted
    btn.Font=Enum.Font.GothamBold; btn.AutoButtonColor=false; btn.ZIndex=12; mkCorner(btn,6)
    btn.MouseEnter:Connect(function() if activeTab~=name then tw(btn,{BackgroundColor3=T.bg2},0.1) end end)
    btn.MouseLeave:Connect(function() if activeTab~=name then tw(btn,{BackgroundColor3=T.bg3},0.1) end end)
    local page=mkPage()
    tabs[name]={btn=btn,page=page}
    btn.MouseButton1Click:Connect(function() switchTab(name) end)
end

local function page(name) return tabs[name].page end

----------------------------------------------------------------
-- MOVEMENT TAB
----------------------------------------------------------------
mkSection(page("Movement"),"Walk & Jump",1)
mkToggle(page("Movement"),"Bunny Hop","Time jumps to gain speed","BHop",2,function(v) setBHop(v) end)
mkToggle(page("Movement"),"Infinite Jump","Jump again mid-air","InfJump",3,function(v) setInfJump(v) end)
mkSlider(page("Movement"),"Walk Speed",1,120,16,"WalkSpeed",4,"",false,function(v) local h=getHum(); if h then h.WalkSpeed=v end end)
mkSlider(page("Movement"),"Jump Power",1,200,50,"JumpPower",5,"",false,function(v) local h=getHum(); if h then h.JumpPower=v end end)
mkSection(page("Movement"),"Advanced",6)
mkToggle(page("Movement"),"Noclip","Walk through walls","Noclip",7,function(v) setNoclip(v) end)
mkToggle(page("Movement"),"Fly","WASD + Space/Ctrl to fly","Fly",8,function(v) setFly(v) end)
mkSlider(page("Movement"),"Fly Speed",10,200,55,"FlySpeed",9,"",false)

----------------------------------------------------------------
-- GAME TAB
----------------------------------------------------------------
mkSection(page("Game"),"Survival",1)
mkToggle(page("Game"),"Avoid Nextbots","Velocity away when bot is near","AvoidNextbot",2,function(v) setAvoidNextbot(v) end)
mkSlider(page("Game"),"Avoid Trigger Distance",8,60,28,"AvoidDist",3,"m",false)
mkSection(page("Game"),"Auto Actions",4)
mkToggle(page("Game"),"Auto Revive","Auto-revive nearby downed players","AutoRevive",5,function(v) setAutoRevive(v) end)
mkToggle(page("Game"),"Auto Interact","Auto-press all nearby E prompts","AutoInteract",6,function(v) setAutoInteract(v) end)
mkToggle(page("Game"),"Auto Collect","Walk to and collect items/coins","AutoCollect",7,function(v) setAutoCollect(v) end)
mkToggle(page("Game"),"Auto Use Cola","Auto-use Cola from inventory","AutoCola",8,function(v) setAutoCola(v) end)
mkToggle(page("Game"),"Auto Whistle","Auto-whistle to distract bots","AutoWhistle",9,function(v) setAutoWhistle(v) end)
mkSection(page("Game"),"Round Info",10)
mkToggle(page("Game"),"Show Round Timer","Display timer at top of screen","ShowRoundTimer",11,function(v) buildRoundTimer() end)

----------------------------------------------------------------
-- VISUALS TAB
----------------------------------------------------------------
mkSection(page("Visuals"),"Lighting",1)
mkToggle(page("Visuals"),"Fullbright","Max brightness everywhere","Fullbright",2,function(v) setFullbright(v) end)
mkToggle(page("Visuals"),"No Darkness","Removes dark areas","NoDarkness",3,function(v) setNoDarkness(v) end)
mkToggle(page("Visuals"),"No Light Flicker","Stops flicker when bots are near","NoFlicker",4,function(v) setNoFlicker(v) end)
mkSection(page("Visuals"),"Camera",5)
mkToggle(page("Visuals"),"No Camera Shake","Removes shake effects","NoCamShake",6,function(v) setNoCamShake(v) end)
mkToggle(page("Visuals"),"Custom FOV","Override field of view","CustomFOV",7,function(v)
    Cam.FieldOfView = v and CFG.FOVVal or 70
end)
mkSlider(page("Visuals"),"FOV Value",50,130,90,"FOVVal",8,"°",false,function(v) if CFG.CustomFOV then Cam.FieldOfView=v end end)
mkSection(page("Visuals"),"World",9)
mkToggle(page("Visuals"),"Remove Barriers","Make doors/barriers transparent","RemoveBarriers",10,function(v) setRemoveBarriers(v) end)
mkToggle(page("Visuals"),"FPS Boost","Disable particles & post-processing","FPSBoost",11,function(v) setFPSBoost(v) end)

----------------------------------------------------------------
-- ESP TAB
----------------------------------------------------------------
mkToggle(page("ESP"),"Enable ESP","All player & nextbot overlays","ESPEnabled",1)
mkSection(page("ESP"),"Targets",2)
mkToggle(page("ESP"),"Player ESP","Show teammate/player labels","ESPPlayers",3)
mkToggle(page("ESP"),"Nextbot ESP","Show nextbot positions","ESPNextbots",4)
mkSection(page("ESP"),"Display",5)
mkToggle(page("ESP"),"Show Names","Display player usernames","ESPNames",6)
mkToggle(page("ESP"),"Show Distance","Show distance in meters","ESPDist",7)
mkToggle(page("ESP"),"Health Bar","Show health bar","ESPHealth",8)
mkSlider(page("ESP"),"Max Distance",50,1000,600,"ESPMaxDist","m",9,"m",false)

----------------------------------------------------------------
-- MISC TAB
----------------------------------------------------------------
mkSection(page("Misc"),"Quality of Life",1)
mkToggle(page("Misc"),"Anti-AFK","Prevent idle kick","AntiAFK",2,function(v) setAntiAFK(v) end)
mkSection(page("Misc"),"Chat",3)
mkToggle(page("Misc"),"Chat Spam","Spam chat with your message","ChatSpam",4,function(v) setChatSpam(v) end)
mkInput(page("Misc"),"Spam Message","PHANTOM HUB","ChatMsg",5)
mkSlider(page("Misc"),"Spam Delay",1,30,4,"ChatDelay",6,"s",false)
mkSection(page("Misc"),"Actions",7)
mkButton(page("Misc"),"Respawn Character",8,function() LP:LoadCharacter() end)
mkButton(page("Misc"),"Copy Player List",9,function()
    local t={}
    for _,p in ipairs(Players:GetPlayers()) do table.insert(t,p.Name) end
    pcall(function() setclipboard(table.concat(t,"\n")) end)
end)
mkButton(page("Misc"),"Rejoin Server",10,function()
    game:GetService("TeleportService"):Teleport(game.PlaceId,LP)
end)
mkSection(page("Misc"),"Info",11)
do
    local f=Instance.new("Frame",page("Misc")); f.Size=UDim2.new(1,0,0,50); f.BackgroundColor3=T.bg2; f.ZIndex=12; f.LayoutOrder=12
    mkCorner(f,8); mkStroke(f,T.border,1); mkPad(f,12,12,8,8); mkList(f,_,_,3)
    local a=Instance.new("TextLabel",f); a.Size=UDim2.new(1,0,0,15); a.BackgroundTransparency=1; a.Text="PHANTOM HUB  •  Evade Edition"
    a.TextSize=12; a.TextColor3=T.acc; a.Font=Enum.Font.GothamBold; a.TextXAlignment=Enum.TextXAlignment.Left; a.ZIndex=13; a.LayoutOrder=1
    local b2=Instance.new("TextLabel",f); b2.Size=UDim2.new(1,0,0,14); b2.BackgroundTransparency=1; b2.Text="Custom UI  •  No dependencies  •  RightShift to toggle"
    b2.TextSize=11; b2.TextColor3=T.muted; b2.Font=Enum.Font.Gotham; b2.TextXAlignment=Enum.TextXAlignment.Left; b2.ZIndex=13; b2.LayoutOrder=2
end

----------------------------------------------------------------
-- OPEN / CLOSE
----------------------------------------------------------------
local function openWin()
    Win.Size=UDim2.new(0,460,0,0)
    Win.Position=UDim2.new(0.5,-230,0.5,0)
    Shad.Size=UDim2.new(0,480,0,0)
    Win.Visible=true; Shad.Visible=true; syncShad()
    tw(Win,{Size=UDim2.new(0,460,0,490),Position=UDim2.new(0.5,-230,0.5,-245)},0.22,Enum.EasingStyle.Back)
    tw(Shad,{Size=UDim2.new(0,480,0,510)},0.2)
    if activeTab=="" then switchTab("Movement") end
end

Icon.MouseButton1Click:Connect(function()
    if Win.Visible then
        tw(Win,{Size=UDim2.new(0,460,0,0)},0.15); task.wait(0.17)
        Win.Visible=false; Shad.Visible=false; Win.Size=UDim2.new(0,460,0,490)
    else openWin() end
end)

UIS.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.KeyCode==Enum.KeyCode.RightShift then
        if Win.Visible then
            tw(Win,{Size=UDim2.new(0,460,0,0)},0.15); task.wait(0.17)
            Win.Visible=false; Shad.Visible=false; Win.Size=UDim2.new(0,460,0,490)
        else openWin() end
    end
end)

task.wait(1.2); openWin()
