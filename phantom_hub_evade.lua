--[[
    ██████╗ ██╗  ██╗ █████╗ ███╗   ██╗████████╗ ██████╗ ███╗   ███╗
    ██╔══██╗██║  ██║██╔══██╗████╗  ██║╚══██╔══╝██╔═══██╗████╗ ████║
    ██████╔╝███████║███████║██╔██╗ ██║   ██║   ██║   ██║██╔████╔██║
    ██╔═══╝ ██╔══██║██╔══██║██║╚██╗██║   ██║   ██║   ██║██║╚██╔╝██║
    ██║     ██║  ██║██║  ██║██║ ╚████║   ██║   ╚██████╔╝██║ ╚═╝ ██║
    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝
    PHANTOM HUB — EVADE  |  Custom UI  |  No Dependencies
]]

----------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local CoreGui      = game:GetService("CoreGui")

local LP     = Players.LocalPlayer
local Cam    = workspace.CurrentCamera
local Mouse  = LP:GetMouse()

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local CFG = {
    WalkSpeed=16, JumpPower=50,
    InfiniteJump=false, AutoJump=false,
    Bunny=false, BunnyPower=20,
    Noclip=false,
    FlyEnabled=false, FlySpeed=60,
    SpeedBoost=false, SpeedAmount=50,
    LowGrav=false, GravAmount=80,
    AirWalk=false,

    AntiKiller=false, AntiKillerDist=18,
    AutoDash=false, AutoDashDist=14,
    TPKiller=false,
    KillAura=false, KillAuraRadius=8,
    CamLock=false, CamSmooth=10,
    AutoHide=false,

    Fullbright=false, NoFog=false, BlackSky=false,
    CustomFOV=false, FOVAmount=90,
    FPSCounter=false,
    Crosshair=false, CrosshairSize=14,
    Chams=false, Tracers=false,

    ESPEnabled=false, ESPNames=true, ESPDist=true,
    ESPHealth=true, ESPMaxDist=500, ESPKillerOnly=false,

    AntiAFK=true, FakeLag=false, FakeLagInt=4,
    ChatSpam=false, ChatMsg="PHANTOM HUB", ChatDelay=3,
    RejoinDeath=false,
}

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local conns       = {}
local espCache    = {}
local chamCache   = {}
local tracerCache = {}
local flyBV, flyBG
local flyActive   = false
local lastBunny   = 0
local fpsGui, fpsConn
local crossLines  = {}
local origGrav    = workspace.Gravity
local origBright  = Lighting.Brightness
local origAmb     = Lighting.Ambient
local origOut     = Lighting.OutdoorAmbient
local camTarget   = nil
local chatThread  = nil

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------
local function getChar() return LP.Character end
local function getHRP()  local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum()  local c=getChar(); return c and c:FindFirstChildOfClass("Humanoid") end

local function tw(obj, props, t, style)
    TweenService:Create(obj,
        TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        props
    ):Play()
end

local function dc(name)
    if conns[name] then conns[name]:Disconnect(); conns[name]=nil end
end

local function isKiller(p)
    if not p or not p.Character then return false end
    local c = p.Character
    if c:FindFirstChild("Knife") or c:FindFirstChild("Weapon") then return true end
    local bp = p:FindFirstChildOfClass("Backpack")
    return bp and (bp:FindFirstChild("Knife") or bp:FindFirstChild("Weapon")) and true or false
end

----------------------------------------------------------------
-- LOGIC FUNCTIONS
----------------------------------------------------------------
local function applyStats()
    local h = getHum(); if not h then return end
    if not CFG.SpeedBoost then h.WalkSpeed = CFG.WalkSpeed end
    h.JumpPower = CFG.JumpPower
end

local function setInfJump(on)
    dc("infJump")
    if on then conns["infJump"] = UIS.JumpRequest:Connect(function()
        local h=getHum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end) end
end

local function setAutoJump(on)
    dc("autoJump")
    if on then conns["autoJump"] = RunService.Heartbeat:Connect(function()
        local h=getHum(); if h and h.FloorMaterial~=Enum.Material.Air then
            h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end) end
end

local function setBunny(on)
    dc("bunny")
    if on then conns["bunny"] = UIS.JumpRequest:Connect(function()
        if tick()-lastBunny < 0.22 then return end
        lastBunny = tick()
        local r=getHRP(); local h=getHum()
        if r and h and h.FloorMaterial~=Enum.Material.Air then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
            local v=r.AssemblyLinearVelocity
            r.AssemblyLinearVelocity = Vector3.new(v.X*1.1, CFG.BunnyPower, v.Z*1.1)
        end
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
        local c=getChar(); if c then
            for _,p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide=true end
            end
        end
    end
end

local function setFly(on)
    local r=getHRP(); if not r then return end
    if on and not flyActive then
        flyActive=true
        flyBV=Instance.new("BodyVelocity"); flyBV.MaxForce=Vector3.new(1e5,1e5,1e5); flyBV.Velocity=Vector3.zero; flyBV.Parent=r
        flyBG=Instance.new("BodyGyro");     flyBG.MaxTorque=Vector3.new(1e5,1e5,1e5); flyBG.P=1e4; flyBG.Parent=r
        conns["fly"]=RunService.Heartbeat:Connect(function()
            if not CFG.FlyEnabled then return end
            local cf=Cam.CFrame; local mv=Vector3.zero
            if UIS:IsKeyDown(Enum.KeyCode.W) then mv=mv+cf.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then mv=mv-cf.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then mv=mv-cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then mv=mv+cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then mv=mv+Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then mv=mv-Vector3.new(0,1,0) end
            flyBV.Velocity = mv.Magnitude>0 and mv.Unit*CFG.FlySpeed or Vector3.zero
            flyBG.CFrame   = cf
        end)
    elseif not on and flyActive then
        flyActive=false; dc("fly")
        if flyBV then flyBV:Destroy(); flyBV=nil end
        if flyBG then flyBG:Destroy(); flyBG=nil end
    end
end

local function setLowGrav(on) workspace.Gravity = on and CFG.GravAmount or origGrav end

local function setAntiKiller(on)
    dc("antiK")
    if on then conns["antiK"]=RunService.Heartbeat:Connect(function()
        local r=getHRP(); if not r then return end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP and isKiller(p) then
                local kr=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if kr and (kr.Position-r.Position).Magnitude<CFG.AntiKillerDist then
                    r.AssemblyLinearVelocity=(r.Position-kr.Position).Unit*90+Vector3.new(0,35,0)
                end
            end
        end
    end) end
end

local function setAutoDash(on)
    dc("autoDash")
    if on then conns["autoDash"]=RunService.Heartbeat:Connect(function()
        local r=getHRP(); if not r then return end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP and isKiller(p) then
                local kr=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if kr and (kr.Position-r.Position).Magnitude<CFG.AutoDashDist then
                    r.AssemblyLinearVelocity=(r.Position-kr.Position).Unit*80+Vector3.new(0,20,0)
                end
            end
        end
    end) end
end

local function setTPKiller(on)
    dc("tpK")
    if on then conns["tpK"]=RunService.Heartbeat:Connect(function()
        local r=getHRP(); if not r then return end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP and isKiller(p) then
                local kr=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if kr then r.CFrame=kr.CFrame*CFrame.new(0,0,2); break end
            end
        end
    end) end
end

local function setKillAura(on)
    dc("kAura")
    if on then conns["kAura"]=RunService.Heartbeat:Connect(function()
        local r=getHRP(); if not r then return end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP and p.Character then
                local pr=p.Character:FindFirstChild("HumanoidRootPart")
                if pr and (pr.Position-r.Position).Magnitude<=CFG.KillAuraRadius then
                    r.CFrame=CFrame.new(pr.Position+Vector3.new(0,0,0.4))
                end
            end
        end
    end) end
end

local function setCamLock(on)
    dc("camLock"); camTarget=nil
    if on then conns["camLock"]=RunService.RenderStepped:Connect(function()
        if not camTarget then
            local r=getHRP(); if not r then return end
            local best,bd=nil,math.huge
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LP and p.Character then
                    local pr=p.Character:FindFirstChild("HumanoidRootPart")
                    if pr then local d=(pr.Position-r.Position).Magnitude
                        if d<bd then bd=d; best=p end
                    end
                end
            end
            camTarget=best
        end
        if camTarget and camTarget.Character then
            local head=camTarget.Character:FindFirstChild("Head")
            if head then
                local s=CFG.CamSmooth/100
                Cam.CFrame=Cam.CFrame:Lerp(CFrame.new(Cam.CFrame.Position,head.Position),s)
            end
        end
    end) end
end

local function setAutoHide(on)
    dc("autoHide")
    if on then conns["autoHide"]=RunService.Heartbeat:Connect(function()
        local r=getHRP(); if not r then return end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP and isKiller(p) then
                local kr=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if kr and (kr.Position-r.Position).Magnitude<20 then
                    local away=r.Position-kr.Position
                    local perp=Vector3.new(-away.Z,0,away.X).Unit
                    r.CFrame=CFrame.new(r.Position+perp*6)
                end
            end
        end
    end) end
end

local function setFullbright(on)
    if on then
        Lighting.Brightness=8; Lighting.Ambient=Color3.new(1,1,1)
        Lighting.OutdoorAmbient=Color3.new(1,1,1); Lighting.ClockTime=14; Lighting.FogEnd=1e6
    else
        Lighting.Brightness=origBright; Lighting.Ambient=origAmb; Lighting.OutdoorAmbient=origOut
    end
end

local function setNoFog(on) Lighting.FogEnd=on and 1e6 or 1000; Lighting.FogStart=on and 9e5 or 0 end

local function setBlackSky(on)
    Lighting.ClockTime=on and 0 or 14
    Lighting.Brightness=on and 0 or origBright
end

local function setFOV(on) Cam.FieldOfView=on and CFG.FOVAmount or 70 end

local function setCrosshair()
    for _,l in ipairs(crossLines) do pcall(function() l:Remove() end) end
    crossLines={}
    if not CFG.Crosshair then return end
    local cx=Cam.ViewportSize.X/2; local cy=Cam.ViewportSize.Y/2; local s=CFG.CrosshairSize
    local defs={
        {Vector2.new(cx-s,cy),   Vector2.new(cx-3,cy)},
        {Vector2.new(cx+3,cy),   Vector2.new(cx+s,cy)},
        {Vector2.new(cx,cy-s),   Vector2.new(cx,cy-3)},
        {Vector2.new(cx,cy+3),   Vector2.new(cx,cy+s)},
    }
    for _,d in ipairs(defs) do
        local l=Drawing.new("Line")
        l.From=d[1]; l.To=d[2]
        l.Color=Color3.fromRGB(255,255,255)
        l.Thickness=1.5; l.Transparency=1; l.Visible=true
        table.insert(crossLines,l)
    end
end

local function setFPS(on)
    if fpsConn then fpsConn:Disconnect(); fpsConn=nil end
    if fpsGui then fpsGui:Destroy(); fpsGui=nil end
    if not on then return end
    local sg=Instance.new("ScreenGui",CoreGui); sg.Name="PhantomFPS"; sg.ResetOnSpawn=false
    local f=Instance.new("TextLabel",sg)
    f.Size=UDim2.new(0,80,0,24); f.Position=UDim2.new(1,-88,0,8)
    f.BackgroundColor3=Color3.fromRGB(10,10,18); f.BackgroundTransparency=0.3
    f.BorderSizePixel=0; f.TextColor3=Color3.fromRGB(120,255,160)
    f.Font=Enum.Font.GothamBold; f.TextSize=13; f.Text="FPS: --"
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,6)
    fpsGui=f
    local cnt,last=0,tick()
    fpsConn=RunService.RenderStepped:Connect(function()
        cnt+=1
        if tick()-last>=1 then f.Text="FPS: "..cnt; cnt=0; last=tick() end
    end)
end

local function setChams(on)
    for p,box in pairs(chamCache) do box:Destroy() end
    chamCache={}
    if not on then return end
    dc("chams")
    conns["chams"]=RunService.Heartbeat:Connect(function()
        for p,box in pairs(chamCache) do
            if not p.Parent or not p.Character then box:Destroy(); chamCache[p]=nil end
        end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP and p.Character and not chamCache[p] then
                local box=Instance.new("SelectionBox",CoreGui)
                box.Color3=Color3.fromRGB(255,60,80)
                box.SurfaceTransparency=0.65
                box.SurfaceColor3=Color3.fromRGB(255,60,80)
                box.LineThickness=0.04
                box.Adornee=p.Character
                chamCache[p]=box
            end
        end
    end)
end

local function setAntiAFK(on)
    dc("afk")
    if on then
        local vu=Instance.new("VirtualUser"); vu.Parent=LP
        conns["afk"]=LP.Idled:Connect(function() vu:CaptureController(); vu:ClickButton2(Vector2.new()) end)
    end
end

local function setChatSpam(on)
    if chatThread then task.cancel(chatThread); chatThread=nil end
    if not on then return end
    chatThread=task.spawn(function()
        while CFG.ChatSpam do
            local rs=game:GetService("ReplicatedStorage")
            local ev=rs:FindFirstChild("DefaultChatSystemChatEvents")
            if ev then local sr=ev:FindFirstChild("SayMessageRequest")
                if sr then sr:FireServer(CFG.ChatMsg,"All") end
            end
            task.wait(CFG.ChatDelay)
        end
    end)
end

-- ESP Container
local espSG=Instance.new("ScreenGui")
espSG.Name="PhantomESP"; espSG.ResetOnSpawn=false; espSG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
if gethui then espSG.Parent=gethui()
elseif syn and syn.protect_gui then syn.protect_gui(espSG); espSG.Parent=CoreGui
else espSG.Parent=CoreGui end

local function makeESP(p)
    if espCache[p] then return espCache[p] end
    local g=Instance.new("BillboardGui")
    g.AlwaysOnTop=true; g.Size=UDim2.new(0,110,0,70); g.StudsOffset=Vector3.new(0,3,0); g.LightInfluence=0
    local nl=Instance.new("TextLabel",g); nl.Name="N"
    nl.Size=UDim2.new(1,0,0,15); nl.Position=UDim2.new(0,0,0,-17)
    nl.BackgroundTransparency=1; nl.Font=Enum.Font.GothamBold
    nl.TextSize=12; nl.TextColor3=Color3.new(1,1,1)
    nl.TextStrokeTransparency=0.3; nl.TextStrokeColor3=Color3.new(0,0,0); nl.Text=p.Name
    local dl=Instance.new("TextLabel",g); dl.Name="D"
    dl.Size=UDim2.new(1,0,0,13); dl.Position=UDim2.new(0,0,1,2)
    dl.BackgroundTransparency=1; dl.Font=Enum.Font.Gotham
    dl.TextSize=11; dl.TextColor3=Color3.fromRGB(160,160,255)
    dl.TextStrokeTransparency=0.3; dl.TextStrokeColor3=Color3.new(0,0,0); dl.Text=""
    local hbg=Instance.new("Frame",g); hbg.Name="HBG"
    hbg.Size=UDim2.new(0,4,1,0); hbg.Position=UDim2.new(0,-7,0,0)
    hbg.BackgroundColor3=Color3.fromRGB(30,30,30); hbg.BorderSizePixel=0
    Instance.new("UICorner",hbg).CornerRadius=UDim.new(0,2)
    local hf=Instance.new("Frame",hbg); hf.Name="HF"
    hf.Size=UDim2.new(1,0,1,0); hf.BackgroundColor3=Color3.fromRGB(0,220,100); hf.BorderSizePixel=0
    Instance.new("UICorner",hf).CornerRadius=UDim.new(0,2)
    local kl=Instance.new("TextLabel",g); kl.Name="K"
    kl.Size=UDim2.new(1,0,0,13); kl.Position=UDim2.new(0,0,0,-30)
    kl.BackgroundTransparency=1; kl.Font=Enum.Font.GothamBold
    kl.TextSize=11; kl.TextColor3=Color3.fromRGB(255,60,60)
    kl.TextStrokeTransparency=0.3; kl.TextStrokeColor3=Color3.new(0,0,0); kl.Text=""
    espCache[p]=g; return g
end

RunService.RenderStepped:Connect(function()
    -- ESP
    for p,g in pairs(espCache) do
        if not p.Parent or not p.Character then g:Destroy(); espCache[p]=nil end
    end
    for p,l in pairs(tracerCache) do
        if not p.Parent then pcall(function()l:Remove()end); tracerCache[p]=nil end
    end
    if CFG.ESPEnabled then
        local myR=getHRP()
        for _,p in ipairs(Players:GetPlayers()) do
            if p==LP then continue end
            local char=p.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            local head=char and char:FindFirstChild("Head")
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            local ok2=hrp and head and hum and hum.Health>0
            if ok2 and CFG.ESPKillerOnly and not isKiller(p) then ok2=false end
            local dist=myR and hrp and (hrp.Position-myR.Position).Magnitude or 0
            if dist>CFG.ESPMaxDist then ok2=false end
            if ok2 then
                local esp=makeESP(p)
                esp.Adornee=head; esp.Parent=espSG
                local nl=esp:FindFirstChild("N"); if nl then nl.Visible=CFG.ESPNames; nl.Text=p.Name end
                local dl=esp:FindFirstChild("D"); if dl then dl.Visible=CFG.ESPDist; dl.Text=math.floor(dist).."m" end
                local hbg=esp:FindFirstChild("HBG")
                if hbg and CFG.ESPHealth and hum then
                    hbg.Visible=true
                    local hf=hbg:FindFirstChild("HF")
                    if hf then
                        local frac=hum.Health/hum.MaxHealth
                        hf.Size=UDim2.new(1,0,frac,0)
                        hf.BackgroundColor3=Color3.fromRGB(math.floor((1-frac)*255),math.floor(frac*220),60)
                    end
                elseif hbg then hbg.Visible=false end
                local kl=esp:FindFirstChild("K"); if kl then kl.Text=isKiller(p) and "⚠ KILLER" or "" end
                -- Tracer
                if CFG.Tracers then
                    if not tracerCache[p] then
                        local l=Drawing.new("Line"); l.Thickness=1.2; l.Transparency=1; l.Visible=true
                        tracerCache[p]=l
                    end
                    local l=tracerCache[p]
                    local sp,on2=Cam:WorldToViewportPoint(hrp.Position)
                    if on2 then
                        l.From=Vector2.new(Cam.ViewportSize.X/2,Cam.ViewportSize.Y)
                        l.To=Vector2.new(sp.X,sp.Y)
                        l.Color=isKiller(p) and Color3.fromRGB(255,60,80) or Color3.fromRGB(100,200,255)
                        l.Visible=true
                    else l.Visible=false end
                else if tracerCache[p] then tracerCache[p].Visible=false end end
            else
                local esp=espCache[p]; if esp then esp.Parent=nil end
                if tracerCache[p] then tracerCache[p].Visible=false end
            end
        end
    else
        for _,g in pairs(espCache) do g.Parent=nil end
        for _,l in pairs(tracerCache) do l.Visible=false end
    end
end)

-- Init on spawn
local function onSpawn(char)
    char:WaitForChild("Humanoid"); char:WaitForChild("HumanoidRootPart"); task.wait(0.4)
    applyStats()
    setInfJump(CFG.InfiniteJump); setAutoJump(CFG.AutoJump); setBunny(CFG.Bunny)
    setNoclip(CFG.Noclip); if CFG.FlyEnabled then setFly(true) end
    setLowGrav(CFG.LowGrav); setAntiKiller(CFG.AntiKiller)
    setAutoDash(CFG.AutoDash); setTPKiller(CFG.TPKiller)
    setKillAura(CFG.KillAura); setCamLock(CFG.CamLock); setAutoHide(CFG.AutoHide)
    if CFG.RejoinDeath then
        local hum=char:WaitForChild("Humanoid")
        hum.Died:Connect(function()
            task.wait(1.2)
            game:GetService("TeleportService"):Teleport(game.PlaceId,LP)
        end)
    end
end

if LP.Character then onSpawn(LP.Character) end
LP.CharacterAdded:Connect(onSpawn)
setAntiAFK(CFG.AntiAFK)

----------------------------------------------------------------
-- ╔══════════════════════════════════════╗
-- ║          PHANTOM HUB UI             ║
-- ╚══════════════════════════════════════╝
----------------------------------------------------------------
local SG=Instance.new("ScreenGui")
SG.Name="PhantomHub"; SG.ResetOnSpawn=false; SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
SG.DisplayOrder=100
if gethui then SG.Parent=gethui()
elseif syn and syn.protect_gui then syn.protect_gui(SG); SG.Parent=CoreGui
else SG.Parent=CoreGui end

----------------------------------------------------------------
-- THEME
----------------------------------------------------------------
local T={
    bg0     = Color3.fromRGB(8,   8,  14),
    bg1     = Color3.fromRGB(13,  13,  22),
    bg2     = Color3.fromRGB(20,  20,  34),
    bg3     = Color3.fromRGB(26,  26,  44),
    border  = Color3.fromRGB(45,  45,  80),
    acc     = Color3.fromRGB(110,  90, 255),
    accHot  = Color3.fromRGB(150, 130, 255),
    accDim  = Color3.fromRGB(60,   50, 160),
    green   = Color3.fromRGB(0,   210, 110),
    red     = Color3.fromRGB(220,  50,  70),
    yellow  = Color3.fromRGB(255, 200,  50),
    white   = Color3.fromRGB(235, 235, 255),
    muted   = Color3.fromRGB(120, 120, 160),
    tabOn   = Color3.fromRGB(110,  90, 255),
    tabOff  = Color3.fromRGB(22,   22,  36),
}

----------------------------------------------------------------
-- UTILITY BUILDERS
----------------------------------------------------------------
local function mkCorner(p,r) local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r or 8); return c end
local function mkStroke(p,c,t) local s=Instance.new("UIStroke",p); s.Color=c or T.border; s.Thickness=t or 1; return s end
local function mkPad(p,l,r2,t,b) local pad=Instance.new("UIPadding",p)
    pad.PaddingLeft=UDim.new(0,l or 0); pad.PaddingRight=UDim.new(0,r2 or 0)
    pad.PaddingTop=UDim.new(0,t or 0); pad.PaddingBottom=UDim.new(0,b or 0); return pad end
local function mkList(p,dir,pad,align)
    local l=Instance.new("UIListLayout",p)
    l.FillDirection=dir or Enum.FillDirection.Vertical
    l.Padding=UDim.new(0,pad or 0)
    if align then l.HorizontalAlignment=align end
    return l end

local function mkLabel(p,txt,sz,col,bold,xa)
    local l=Instance.new("TextLabel",p)
    l.BackgroundTransparency=1; l.Text=txt; l.TextSize=sz or 13
    l.TextColor3=col or T.white; l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextXAlignment=xa or Enum.TextXAlignment.Left; l.AutomaticSize=Enum.AutomaticSize.XY
    return l end

----------------------------------------------------------------
-- GLOW FRAME
----------------------------------------------------------------
local function mkGlow(parent, color, size, pos)
    local f=Instance.new("Frame",parent)
    f.Size=size or UDim2.new(1,0,1,0); f.Position=pos or UDim2.new(0,0,0,0)
    f.BackgroundColor3=color; f.BackgroundTransparency=0.88; f.BorderSizePixel=0; f.ZIndex=1
    mkCorner(f,12)
    return f
end

----------------------------------------------------------------
-- ICON BUTTON (draggable pill)
----------------------------------------------------------------
local IconFrame=Instance.new("Frame",SG)
IconFrame.Size=UDim2.new(0,44,0,44); IconFrame.Position=UDim2.new(0,14,0.44,0)
IconFrame.BackgroundColor3=T.bg2; IconFrame.ZIndex=20; IconFrame.Active=true
mkCorner(IconFrame,12); mkStroke(IconFrame,T.acc,2)

local glowIcon=Instance.new("Frame",IconFrame)
glowIcon.Size=UDim2.new(1,16,1,16); glowIcon.Position=UDim2.new(0,-8,0,-8)
glowIcon.BackgroundColor3=T.acc; glowIcon.BackgroundTransparency=0.78; glowIcon.ZIndex=19
mkCorner(glowIcon,16)

local IconLbl=Instance.new("TextLabel",IconFrame)
IconLbl.Size=UDim2.new(1,0,1,0); IconLbl.BackgroundTransparency=1
IconLbl.Text="P"; IconLbl.TextSize=20; IconLbl.TextColor3=T.acc
IconLbl.Font=Enum.Font.GothamBold; IconLbl.TextXAlignment=Enum.TextXAlignment.Center
IconLbl.TextYAlignment=Enum.TextYAlignment.Center; IconLbl.ZIndex=21

-- Pulse icon
task.spawn(function()
    while true do
        tw(IconLbl,{TextTransparency=0.5},0.8,Enum.EasingStyle.Sine)
        task.wait(0.8)
        tw(IconLbl,{TextTransparency=0},0.8,Enum.EasingStyle.Sine)
        task.wait(0.8)
    end
end)

-- Drag icon
do
    local drag,dStart,dPos=false
    IconFrame.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=true; dStart=i.Position; dPos=IconFrame.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then drag=false end end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-dStart
            IconFrame.Position=UDim2.new(dPos.X.Scale,dPos.X.Offset+d.X,dPos.Y.Scale,dPos.Y.Offset+d.Y)
        end
    end)
end

----------------------------------------------------------------
-- MAIN WINDOW
----------------------------------------------------------------
local Win=Instance.new("Frame",SG)
Win.Size=UDim2.new(0,480,0,500); Win.Position=UDim2.new(0.5,-240,0.5,-250)
Win.BackgroundColor3=T.bg0; Win.Visible=false; Win.ZIndex=10; Win.Active=true; Win.ClipsDescendants=true
mkCorner(Win,14); mkStroke(Win,T.acc,2)

-- bg texture stripes
local stripe=Instance.new("Frame",Win)
stripe.Size=UDim2.new(1,0,1,0); stripe.BackgroundTransparency=1; stripe.ZIndex=10
local sg2=Instance.new("UIGradient",stripe)
sg2.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(18,14,32)),
    ColorSequenceKeypoint.new(0.5,Color3.fromRGB(10,10,18)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(14,10,26)),
})
sg2.Rotation=130

-- Drop shadow
local Shadow=Instance.new("Frame",SG)
Shadow.Size=UDim2.new(0,500,0,520); Shadow.BackgroundColor3=Color3.new(0,0,0)
Shadow.BackgroundTransparency=0.5; Shadow.ZIndex=9; Shadow.Visible=false
mkCorner(Shadow,18)
local function syncShadow()
    Shadow.Position=UDim2.new(Win.Position.X.Scale,Win.Position.X.Offset-10,Win.Position.Y.Scale,Win.Position.Y.Offset-10)
end; syncShadow()

----------------------------------------------------------------
-- HEADER
----------------------------------------------------------------
local Header=Instance.new("Frame",Win)
Header.Size=UDim2.new(1,0,0,52); Header.BackgroundColor3=T.bg2; Header.ZIndex=11
mkCorner(Header,14)
-- fill bottom so it doesnt show rounded on inside
local HFix=Instance.new("Frame",Header)
HFix.Size=UDim2.new(1,0,0.5,0); HFix.Position=UDim2.new(0,0,0.5,0)
HFix.BackgroundColor3=T.bg2; HFix.BorderSizePixel=0; HFix.ZIndex=11
local HGrad=Instance.new("UIGradient",Header)
HGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(70,50,160)),ColorSequenceKeypoint.new(1,T.bg2)})
HGrad.Rotation=90

-- Logo dot
local LogoDot=Instance.new("Frame",Header)
LogoDot.Size=UDim2.new(0,8,0,8); LogoDot.Position=UDim2.new(0,16,0.5,-4)
LogoDot.BackgroundColor3=T.acc; LogoDot.ZIndex=12; mkCorner(LogoDot,4)

-- Title
local TitleL=Instance.new("TextLabel",Header)
TitleL.Size=UDim2.new(0,220,1,0); TitleL.Position=UDim2.new(0,32,0,0)
TitleL.BackgroundTransparency=1; TitleL.Text="PHANTOM HUB"
TitleL.TextSize=16; TitleL.TextColor3=T.white; TitleL.Font=Enum.Font.GothamBold
TitleL.TextXAlignment=Enum.TextXAlignment.Left; TitleL.ZIndex=12

local SubL=Instance.new("TextLabel",Header)
SubL.Size=UDim2.new(0,220,0,14); SubL.Position=UDim2.new(0,32,1,-16)
SubL.BackgroundTransparency=1; SubL.Text="evade edition  •  v1.0"
SubL.TextSize=10; SubL.TextColor3=T.muted; SubL.Font=Enum.Font.Gotham
SubL.TextXAlignment=Enum.TextXAlignment.Left; SubL.ZIndex=12

-- Close btn
local CloseBtn=Instance.new("TextButton",Header)
CloseBtn.Size=UDim2.new(0,26,0,26); CloseBtn.Position=UDim2.new(1,-36,0.5,-13)
CloseBtn.BackgroundColor3=Color3.fromRGB(160,35,55); CloseBtn.Text="✕"
CloseBtn.TextColor3=Color3.new(1,1,1); CloseBtn.TextSize=13; CloseBtn.Font=Enum.Font.GothamBold
CloseBtn.AutoButtonColor=false; CloseBtn.ZIndex=13; mkCorner(CloseBtn,6)
CloseBtn.MouseEnter:Connect(function() tw(CloseBtn,{BackgroundColor3=Color3.fromRGB(220,50,70)},0.1) end)
CloseBtn.MouseLeave:Connect(function() tw(CloseBtn,{BackgroundColor3=Color3.fromRGB(160,35,55)},0.1) end)
CloseBtn.MouseButton1Click:Connect(function()
    tw(Win,{Size=UDim2.new(0,480,0,0)},0.16)
    tw(Win,{Position=UDim2.new(Win.Position.X.Scale,Win.Position.X.Offset,Win.Position.Y.Scale,Win.Position.Y.Offset+250)},0.16)
    task.wait(0.18)
    Win.Visible=false; Shadow.Visible=false
    Win.Size=UDim2.new(0,480,0,500)
end)

-- Minimize btn
local MinBtn=Instance.new("TextButton",Header)
MinBtn.Size=UDim2.new(0,26,0,26); MinBtn.Position=UDim2.new(1,-66,0.5,-13)
MinBtn.BackgroundColor3=T.bg3; MinBtn.Text="—"; MinBtn.TextColor3=T.muted
MinBtn.TextSize=13; MinBtn.Font=Enum.Font.GothamBold; MinBtn.AutoButtonColor=false; MinBtn.ZIndex=13
mkCorner(MinBtn,6)
local minimized=false
MinBtn.MouseButton1Click:Connect(function()
    minimized=not minimized
    if minimized then
        tw(Win,{Size=UDim2.new(0,480,0,52)},0.2,Enum.EasingStyle.Quad)
    else
        tw(Win,{Size=UDim2.new(0,480,0,500)},0.22,Enum.EasingStyle.Back)
    end
end)

-- Drag window
do
    local drag,dStart,dPos=false
    Header.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            drag=true; dStart=i.Position; dPos=Win.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then drag=false end end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-dStart
            Win.Position=UDim2.new(dPos.X.Scale,dPos.X.Offset+d.X,dPos.Y.Scale,dPos.Y.Offset+d.Y)
            syncShadow()
        end
    end)
end

----------------------------------------------------------------
-- TAB BAR
----------------------------------------------------------------
local TabBar=Instance.new("Frame",Win)
TabBar.Size=UDim2.new(1,0,0,34); TabBar.Position=UDim2.new(0,0,0,52)
TabBar.BackgroundColor3=T.bg1; TabBar.ZIndex=11
local TBLayout=mkList(TabBar,Enum.FillDirection.Horizontal,2)
TBLayout.HorizontalAlignment=Enum.HorizontalAlignment.Left
TBLayout.VerticalAlignment=Enum.VerticalAlignment.Center
mkPad(TabBar,6,6,4,4)

-- Separator line under tab bar
local TabLine=Instance.new("Frame",Win)
TabLine.Size=UDim2.new(1,0,0,1); TabLine.Position=UDim2.new(0,0,0,86)
TabLine.BackgroundColor3=T.acc; TabLine.BackgroundTransparency=0.6; TabLine.BorderSizePixel=0; TabLine.ZIndex=11

-- Content area
local ContentArea=Instance.new("Frame",Win)
ContentArea.Size=UDim2.new(1,-2,1,-90); ContentArea.Position=UDim2.new(0,1,0,89)
ContentArea.BackgroundTransparency=1; ContentArea.ZIndex=10; ContentArea.ClipsDescendants=true

-- Status bar
local StatusBar=Instance.new("Frame",Win)
StatusBar.Size=UDim2.new(1,0,0,20); StatusBar.Position=UDim2.new(0,0,1,-20)
StatusBar.BackgroundColor3=T.bg2; StatusBar.ZIndex=11
local StatusTxt=Instance.new("TextLabel",StatusBar)
StatusTxt.Size=UDim2.new(1,-10,1,0); StatusTxt.Position=UDim2.new(0,8,0,0)
StatusTxt.BackgroundTransparency=1; StatusTxt.TextSize=10; StatusTxt.TextColor3=T.muted
StatusTxt.Font=Enum.Font.Gotham; StatusTxt.TextXAlignment=Enum.TextXAlignment.Left
StatusTxt.ZIndex=12; StatusTxt.Text="phantom hub  •  ready"

local function setStatus(txt)
    StatusTxt.Text=txt
    task.delay(3,function() if StatusTxt.Text==txt then StatusTxt.Text="phantom hub  •  ready" end end)
end

----------------------------------------------------------------
-- SCROLL PAGE BUILDER
----------------------------------------------------------------
local function makePage()
    local scroll=Instance.new("ScrollingFrame",ContentArea)
    scroll.Size=UDim2.new(1,0,1,0); scroll.BackgroundTransparency=1
    scroll.ScrollBarThickness=3; scroll.ScrollBarImageColor3=T.acc
    scroll.CanvasSize=UDim2.new(0,0,0,0); scroll.ZIndex=11; scroll.Visible=false
    local layout=Instance.new("UIListLayout",scroll)
    layout.SortOrder=Enum.SortOrder.LayoutOrder
    layout.Padding=UDim.new(0,6)
    mkPad(scroll,10,10,8,8)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize=UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+20)
    end)
    return scroll,layout
end

----------------------------------------------------------------
-- COMPONENT BUILDERS
----------------------------------------------------------------

-- Section header
local function addSection(parent,title,order)
    local f=Instance.new("Frame",parent)
    f.Size=UDim2.new(1,0,0,22); f.BackgroundTransparency=1; f.ZIndex=12; f.LayoutOrder=order
    local line=Instance.new("Frame",f)
    line.Size=UDim2.new(1,0,0,1); line.Position=UDim2.new(0,0,0.5,0)
    line.BackgroundColor3=T.acc; line.BackgroundTransparency=0.65; line.BorderSizePixel=0; line.ZIndex=12
    local bg=Instance.new("Frame",f)
    bg.BackgroundColor3=T.bg0; bg.BorderSizePixel=0; bg.ZIndex=13
    bg.AutomaticSize=Enum.AutomaticSize.X; bg.Size=UDim2.new(0,0,1,0)
    bg.Position=UDim2.new(0,0,0,0)
    mkPad(bg,0,8,0,0)
    local lbl=Instance.new("TextLabel",bg)
    lbl.BackgroundTransparency=1; lbl.Text=title; lbl.TextSize=11
    lbl.TextColor3=T.acc; lbl.Font=Enum.Font.GothamBold
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=14
    lbl.AutomaticSize=Enum.AutomaticSize.XY
end

-- Toggle
local function addToggle(parent, title, desc, cfgKey, order, callback)
    local Row=Instance.new("TextButton",parent)
    Row.Size=UDim2.new(1,0,0,46); Row.BackgroundColor3=T.bg2
    Row.Text=""; Row.AutoButtonColor=false; Row.ZIndex=12; Row.LayoutOrder=order
    mkCorner(Row,8); mkStroke(Row,T.border,1)

    local TxtFrame=Instance.new("Frame",Row)
    TxtFrame.Size=UDim2.new(1,-60,1,0); TxtFrame.BackgroundTransparency=1; TxtFrame.ZIndex=13
    mkPad(TxtFrame,12,0,6,6)
    local TL=mkList(TxtFrame)

    local tl=Instance.new("TextLabel",TxtFrame)
    tl.Size=UDim2.new(1,0,0,18); tl.BackgroundTransparency=1
    tl.Text=title; tl.TextSize=13; tl.TextColor3=T.white
    tl.Font=Enum.Font.GothamBold; tl.TextXAlignment=Enum.TextXAlignment.Left; tl.ZIndex=13
    tl.LayoutOrder=1

    if desc and desc~="" then
        local dl=Instance.new("TextLabel",TxtFrame)
        dl.Size=UDim2.new(1,0,0,14); dl.BackgroundTransparency=1
        dl.Text=desc; dl.TextSize=11; dl.TextColor3=T.muted
        dl.Font=Enum.Font.Gotham; dl.TextXAlignment=Enum.TextXAlignment.Left; dl.ZIndex=13
        dl.LayoutOrder=2
    end

    -- Pill
    local Pill=Instance.new("Frame",Row)
    Pill.Size=UDim2.new(0,38,0,20); Pill.Position=UDim2.new(1,-50,0.5,-10)
    Pill.BackgroundColor3=T.red; Pill.ZIndex=13; mkCorner(Pill,10)
    local Dot=Instance.new("Frame",Pill)
    Dot.Size=UDim2.new(0,14,0,14); Dot.Position=UDim2.new(0,3,0.5,-7)
    Dot.BackgroundColor3=Color3.new(1,1,1); Dot.ZIndex=14; mkCorner(Dot,7)

    local function refresh()
        local on=CFG[cfgKey]
        tw(Pill,{BackgroundColor3=on and T.green or T.red},0.15)
        tw(Dot,{Position=on and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)},0.15)
        tw(Row,{BackgroundColor3=on and Color3.fromRGB(18,28,22) or T.bg2},0.15)
    end
    refresh()

    Row.MouseButton1Click:Connect(function()
        CFG[cfgKey]=not CFG[cfgKey]
        refresh()
        if callback then callback(CFG[cfgKey]) end
        setStatus((CFG[cfgKey] and "enabled" or "disabled").." • "..title:lower())
    end)
    Row.MouseEnter:Connect(function()
        if not CFG[cfgKey] then tw(Row,{BackgroundColor3=Color3.fromRGB(24,24,40)},0.1) end
    end)
    Row.MouseLeave:Connect(function()
        if not CFG[cfgKey] then tw(Row,{BackgroundColor3=T.bg2},0.1) end
    end)
    return Row
end

-- Slider
local function addSlider(parent,title,min2,max2,def,cfgKey,order,suffix,decimals,callback)
    local Container=Instance.new("Frame",parent)
    Container.Size=UDim2.new(1,0,0,60); Container.BackgroundColor3=T.bg2
    Container.ZIndex=12; Container.LayoutOrder=order
    mkCorner(Container,8); mkStroke(Container,T.border,1)
    mkPad(Container,12,12,8,0)

    local TopRow=Instance.new("Frame",Container)
    TopRow.Size=UDim2.new(1,0,0,20); TopRow.BackgroundTransparency=1; TopRow.ZIndex=13

    local NameL=mkLabel(TopRow,title,12,T.muted,false,Enum.TextXAlignment.Left)
    NameL.Size=UDim2.new(0.65,0,1,0)

    local ValL=Instance.new("TextLabel",TopRow)
    ValL.Size=UDim2.new(0.35,0,1,0); ValL.Position=UDim2.new(0.65,0,0,0)
    ValL.BackgroundTransparency=1; ValL.TextSize=13; ValL.TextColor3=T.accHot
    ValL.Font=Enum.Font.GothamBold; ValL.TextXAlignment=Enum.TextXAlignment.Right; ValL.ZIndex=13

    local TrackBG=Instance.new("Frame",Container)
    TrackBG.Size=UDim2.new(1,0,0,8); TrackBG.Position=UDim2.new(0,0,0,30)
    TrackBG.BackgroundColor3=Color3.fromRGB(25,25,45); TrackBG.ZIndex=13; mkCorner(TrackBG,4)

    local Fill=Instance.new("Frame",TrackBG)
    Fill.Size=UDim2.new(0,0,1,0); Fill.BackgroundColor3=T.acc; Fill.ZIndex=14; mkCorner(Fill,4)
    local FG=Instance.new("UIGradient",Fill)
    FG.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T.accHot),ColorSequenceKeypoint.new(1,T.accDim)})

    local Knob=Instance.new("Frame",TrackBG)
    Knob.Size=UDim2.new(0,16,0,16); Knob.AnchorPoint=Vector2.new(0.5,0.5)
    Knob.Position=UDim2.new(0,0,0.5,0); Knob.BackgroundColor3=Color3.new(1,1,1); Knob.ZIndex=15; mkCorner(Knob,8)
    mkStroke(Knob,T.acc,2)

    local function set(v)
        v=math.clamp(v,min2,max2)
        if not decimals then v=math.round(v) end
        CFG[cfgKey]=v
        local frac=(v-min2)/(max2-min2)
        Fill.Size=UDim2.new(frac,0,1,0)
        Knob.Position=UDim2.new(frac,0,0.5,0)
        ValL.Text=decimals and string.format("%.1f",v) or tostring(v)..(suffix or "")
        if callback then callback(v) end
    end
    set(def)

    local dragging=false
    TrackBG.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=false
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local abs=TrackBG.AbsolutePosition.X; local sz=TrackBG.AbsoluteSize.X
            local frac=math.clamp((i.Position.X-abs)/sz,0,1)
            set(min2+(max2-min2)*frac)
        end
    end)
    return Container
end

-- Button
local function addButton(parent,title,desc,order,callback)
    local Btn=Instance.new("TextButton",parent)
    Btn.Size=UDim2.new(1,0,0,42); Btn.BackgroundColor3=T.bg3
    Btn.Text=""; Btn.AutoButtonColor=false; Btn.ZIndex=12; Btn.LayoutOrder=order
    mkCorner(Btn,8); mkStroke(Btn,T.acc,1)
    mkPad(Btn,12,12,0,0)

    local lbl=Instance.new("TextLabel",Btn)
    lbl.Size=UDim2.new(1,-30,1,0); lbl.BackgroundTransparency=1
    lbl.Text=title; lbl.TextSize=13; lbl.TextColor3=T.white
    lbl.Font=Enum.Font.GothamBold; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=13

    local arrow=Instance.new("TextLabel",Btn)
    arrow.Size=UDim2.new(0,24,1,0); arrow.Position=UDim2.new(1,-28,0,0)
    arrow.BackgroundTransparency=1; arrow.Text="›"; arrow.TextSize=18
    arrow.TextColor3=T.acc; arrow.Font=Enum.Font.GothamBold; arrow.ZIndex=13

    Btn.MouseEnter:Connect(function()
        tw(Btn,{BackgroundColor3=Color3.fromRGB(30,28,54)},0.1)
        tw(arrow,{TextColor3=T.accHot},0.1)
    end)
    Btn.MouseLeave:Connect(function()
        tw(Btn,{BackgroundColor3=T.bg3},0.1)
        tw(arrow,{TextColor3=T.acc},0.1)
    end)
    Btn.MouseButton1Click:Connect(function()
        tw(Btn,{BackgroundColor3=T.accDim},0.08)
        task.delay(0.12,function() tw(Btn,{BackgroundColor3=T.bg3},0.12) end)
        if callback then callback() end
        setStatus("executed • "..title:lower())
    end)
    return Btn
end

-- Input box
local function addInput(parent,title,placeholder,cfgKey,order,callback)
    local Container=Instance.new("Frame",parent)
    Container.Size=UDim2.new(1,0,0,56); Container.BackgroundColor3=T.bg2
    Container.ZIndex=12; Container.LayoutOrder=order
    mkCorner(Container,8); mkStroke(Container,T.border,1)
    mkPad(Container,12,12,8,6)

    local lbl=mkLabel(Container,title,12,T.muted,false)
    lbl.Size=UDim2.new(1,0,0,16)

    local box=Instance.new("TextBox",Container)
    box.Size=UDim2.new(1,0,0,26); box.Position=UDim2.new(0,0,0,22)
    box.BackgroundColor3=Color3.fromRGB(16,16,28); box.Text=CFG[cfgKey] or ""
    box.PlaceholderText=placeholder or ""; box.TextColor3=T.white
    box.PlaceholderColor3=T.muted; box.Font=Enum.Font.Gotham
    box.TextSize=12; box.ClearTextOnFocus=false; box.ZIndex=13
    mkCorner(box,6); mkStroke(box,T.border,1)
    mkPad(box,8,8,0,0)

    box.FocusLost:Connect(function()
        CFG[cfgKey]=box.Text
        if callback then callback(box.Text) end
        setStatus("updated • "..title:lower())
    end)
    return Container
end

----------------------------------------------------------------
-- TABS
----------------------------------------------------------------
local tabs={}
local activeTab=nil

local TAB_DEFS={
    {name="Movement", icon="🏃"},
    {name="Combat",   icon="⚔️"},
    {name="Visuals",  icon="🎨"},
    {name="ESP",      icon="👁️"},
    {name="Misc",     icon="🔧"},
}

local function switchTab(name)
    for n,data in pairs(tabs) do
        local on=(n==name)
        tw(data.btn,{BackgroundColor3=on and T.acc or T.tabOff},0.15)
        data.btn.TextColor3=on and T.white or T.muted
        data.page.Visible=on
    end
    activeTab=name
    setStatus("tab • "..name:lower())
end

for i,def in ipairs(TAB_DEFS) do
    local btn=Instance.new("TextButton",TabBar)
    btn.Size=UDim2.new(0,82,0,26); btn.BackgroundColor3=T.tabOff
    btn.Text=def.icon.." "..def.name; btn.TextSize=11; btn.TextColor3=T.muted
    btn.Font=Enum.Font.GothamBold; btn.AutoButtonColor=false; btn.ZIndex=12
    mkCorner(btn,6)
    btn.MouseEnter:Connect(function()
        if activeTab~=def.name then tw(btn,{BackgroundColor3=T.bg3},0.1) end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab~=def.name then tw(btn,{BackgroundColor3=T.tabOff},0.1) end
    end)

    local page,layout=makePage()

    tabs[def.name]={btn=btn,page=page,layout=layout}

    btn.MouseButton1Click:Connect(function() switchTab(def.name) end)
end

----------------------------------------------------------------
-- ═══════ TAB: MOVEMENT ═══════
----------------------------------------------------------------
local MPage=tabs["Movement"].page

addSection(MPage,"Speed & Jump",1)

addToggle(MPage,"Infinite Jump","Jump whenever you want","InfiniteJump",2,function(v) setInfJump(v) end)
addToggle(MPage,"Auto Jump","Continuously jumps","AutoJump",3,function(v) setAutoJump(v) end)
addToggle(MPage,"Bunny Hop","Gain speed while jumping","Bunny",4,function(v) setBunny(v) end)

addSlider(MPage,"Walk Speed",1,150,16,"WalkSpeed",5,"",false,function(v)
    local h=getHum(); if h and not CFG.SpeedBoost then h.WalkSpeed=v end
end)
addSlider(MPage,"Jump Power",1,250,50,"JumpPower",6,"",false,function(v)
    local h=getHum(); if h then h.JumpPower=v end
end)
addSlider(MPage,"Bunny Power",5,60,20,"BunnyPower",7,"",false)

addSection(MPage,"Movement Tricks",8)

addToggle(MPage,"Speed Boost","Instant high speed","SpeedBoost",9,function(v)
    local h=getHum(); if h then h.WalkSpeed=v and CFG.SpeedAmount or CFG.WalkSpeed end
end)
addSlider(MPage,"Boost Amount",20,300,50,"SpeedAmount",10,"",false,function(v)
    if CFG.SpeedBoost then local h=getHum(); if h then h.WalkSpeed=v end end
end)
addToggle(MPage,"Noclip","Walk through walls","Noclip",11,function(v) setNoclip(v) end)
addToggle(MPage,"Fly","WASD + Space/Ctrl","FlyEnabled",12,function(v) setFly(v) end)
addSlider(MPage,"Fly Speed",10,350,60,"FlySpeed",13,"",false)
addToggle(MPage,"Air Walk","Float in place","AirWalk",14,function(v)
    local h=getHum(); if h then h.PlatformStand=v end
end)

addSection(MPage,"Physics",15)
addToggle(MPage,"Low Gravity","Reduced gravity","LowGrav",16,function(v) setLowGrav(v) end)
addSlider(MPage,"Gravity Amount",5,196,80,"GravAmount",17,"",false,function(v)
    if CFG.LowGrav then workspace.Gravity=v end
end)

----------------------------------------------------------------
-- ═══════ TAB: COMBAT ═══════
----------------------------------------------------------------
local CPage=tabs["Combat"].page

addSection(CPage,"Survivor",1)
addToggle(CPage,"Anti-Killer","Velocity away from killer","AntiKiller",2,function(v) setAntiKiller(v) end)
addSlider(CPage,"Anti-Killer Distance",5,50,18,"AntiKillerDist",3,"m",false)
addToggle(CPage,"Auto Dash","Auto evade killer","AutoDash",4,function(v) setAutoDash(v) end)
addSlider(CPage,"Auto Dash Distance",5,40,14,"AutoDashDist",5,"m",false)
addToggle(CPage,"Auto Hide","Sidestep behind cover","AutoHide",6,function(v) setAutoHide(v) end)

addSection(CPage,"Killer",7)
addToggle(CPage,"TP to Killer","Teleport onto killer","TPKiller",8,function(v) setTPKiller(v) end)
addToggle(CPage,"Kill Aura","CFrame onto nearby players","KillAura",9,function(v) setKillAura(v) end)
addSlider(CPage,"Kill Aura Radius",3,30,8,"KillAuraRadius",10,"m",false)

addSection(CPage,"Camera",11)
addToggle(CPage,"Cam Lock","Auto-lock camera to nearest","CamLock",12,function(v) setCamLock(v) end)
addSlider(CPage,"Cam Smoothness",1,20,10,"CamSmooth",13,"",false)
addButton(CPage,"Reset Cam Target","Clears current lock target",14,function()
    camTarget=nil; setStatus("cam target reset")
end)

----------------------------------------------------------------
-- ═══════ TAB: VISUALS ═══════
----------------------------------------------------------------
local VPage=tabs["Visuals"].page

addSection(VPage,"Lighting",1)
addToggle(VPage,"Fullbright","Maximum visibility","Fullbright",2,function(v) setFullbright(v) end)
addToggle(VPage,"No Fog","Removes all fog","NoFog",3,function(v) setNoFog(v) end)
addToggle(VPage,"Black Sky","Midnight darkness","BlackSky",4,function(v) setBlackSky(v) end)

addSection(VPage,"Camera",5)
addToggle(VPage,"Custom FOV","Change field of view","CustomFOV",6,function(v) setFOV(v) end)
addSlider(VPage,"FOV Amount",50,130,90,"FOVAmount",7,"°",false,function(v)
    if CFG.CustomFOV then Cam.FieldOfView=v end
end)

addSection(VPage,"HUD",8)
addToggle(VPage,"FPS Counter","Show framerate","FPSCounter",9,function(v) setFPS(v) end)
addToggle(VPage,"Crosshair","Custom crosshair overlay","Crosshair",10,function(v)
    CFG.Crosshair=v; setCrosshair()
end)
addSlider(VPage,"Crosshair Size",4,40,14,"CrosshairSize",11,"px",false,function()
    if CFG.Crosshair then setCrosshair() end
end)

addSection(VPage,"Player Highlight",12)
addToggle(VPage,"Chams","Highlight players through walls","Chams",13,function(v) setChams(v) end)
addToggle(VPage,"Tracers","Lines from screen to players","Tracers",14)

----------------------------------------------------------------
-- ═══════ TAB: ESP ═══════
----------------------------------------------------------------
local EPage=tabs["ESP"].page

addToggle(EPage,"Enable ESP","Player ESP overlays","ESPEnabled",1)
addToggle(EPage,"Killer Only","Only show killer ESP","ESPKillerOnly",2)

addSection(EPage,"Components",3)
addToggle(EPage,"Show Names","Display player names","ESPNames",4)
addToggle(EPage,"Show Distance","Display distance in meters","ESPDist",5)
addToggle(EPage,"Health Bar","Show health bar on players","ESPHealth",6)
addSlider(EPage,"Max Distance",50,1000,500,"ESPMaxDist","m",7,"m",false)

----------------------------------------------------------------
-- ═══════ TAB: MISC ═══════
----------------------------------------------------------------
local MiPage=tabs["Misc"].page

addSection(MiPage,"Utility",1)
addToggle(MiPage,"Anti-AFK","Prevent kick for inactivity","AntiAFK",2,function(v) setAntiAFK(v) end)
addToggle(MiPage,"Rejoin on Death","Auto-rejoin when you die","RejoinDeath",3)
addToggle(MiPage,"Fake Lag","Simulate lag packets","FakeLag",4,function(v)
    dc("fakeLag")
    if v then local c=0
        conns["fakeLag"]=RunService.Heartbeat:Connect(function()
            c+=1; if c%CFG.FakeLagInt~=0 then local t=tick() while tick()-t<0.002 do end end
        end)
    end
end)
addSlider(MiPage,"Fake Lag Intensity",1,10,4,"FakeLagInt",5,"",false)

addSection(MiPage,"Chat",6)
addToggle(MiPage,"Chat Spam","Spam chat with message","ChatSpam",7,function(v) setChatSpam(v) end)
addInput(MiPage,"Spam Message","PHANTOM HUB","ChatMsg",8)
addSlider(MiPage,"Spam Delay",1,30,3,"ChatDelay",9,"s",false)

addSection(MiPage,"Actions",10)
addButton(MiPage,"Respawn Character","Force respawn your character",11,function()
    LP:LoadCharacter()
end)
addButton(MiPage,"Copy Player List","Copy all players to clipboard",12,function()
    local t={}
    for _,p in ipairs(Players:GetPlayers()) do
        table.insert(t,p.Name..(isKiller(p) and " [KILLER]" or ""))
    end
    setclipboard(table.concat(t,"\n"))
end)
addButton(MiPage,"Rejoin Server","Teleport to a fresh server",13,function()
    game:GetService("TeleportService"):Teleport(game.PlaceId,LP)
end)

addSection(MiPage,"Credits",14)
do
    local f=Instance.new("Frame",MiPage)
    f.Size=UDim2.new(1,0,0,60); f.BackgroundColor3=T.bg2; f.ZIndex=12; f.LayoutOrder=15
    mkCorner(f,8); mkStroke(f,T.border,1)
    mkPad(f,12,12,8,8)
    local l=mkList(f,Enum.FillDirection.Vertical,2)
    local a=mkLabel(f,"PHANTOM HUB  —  Evade Edition",13,T.acc,true); a.LayoutOrder=1
    local b=mkLabel(f,"All features are client-side only.",11,T.muted,false); b.LayoutOrder=2
    local c2=mkLabel(f,"UI built from scratch • No dependencies",11,T.muted,false); c2.LayoutOrder=3
end

----------------------------------------------------------------
-- OPEN / CLOSE ICON
----------------------------------------------------------------
local function openHub()
    Win.Size=UDim2.new(0,480,0,0)
    Win.Position=UDim2.new(0.5,-240,0.5,-0)
    Shadow.Size=UDim2.new(0,500,0,0)
    Win.Visible=true; Shadow.Visible=true; syncShadow()
    tw(Win,{Size=UDim2.new(0,480,0,500),Position=UDim2.new(0.5,-240,0.5,-250)},0.25,Enum.EasingStyle.Back)
    tw(Shadow,{Size=UDim2.new(0,500,0,520)},0.22)
    if not activeTab then switchTab("Movement") end
end

IconFrame.MouseButton1Click:Connect(function()
    if Win.Visible then
        tw(Win,{Size=UDim2.new(0,480,0,0)},0.18)
        task.wait(0.2); Win.Visible=false; Shadow.Visible=false
        Win.Size=UDim2.new(0,480,0,500)
    else openHub() end
end)

-- Key toggle
UIS.InputBegan:Connect(function(i,proc)
    if proc then return end
    if i.KeyCode==Enum.KeyCode.RightShift then
        if Win.Visible then
            tw(Win,{Size=UDim2.new(0,480,0,0)},0.18)
            task.wait(0.2); Win.Visible=false; Shadow.Visible=false
            Win.Size=UDim2.new(0,480,0,500)
        else openHub() end
    end
end)

-- Open on load
task.wait(1); openHub()
setStatus("phantom hub loaded  •  press rshift to toggle")
