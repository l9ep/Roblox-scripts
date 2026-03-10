-- LAG SWITCH — EVADE
-- UI matches reference layout: freeze display + settings panel + bottom button
-- Mobile + PC support | Real anchor freeze | by XYTHC

local Players  = game:GetService("Players")
local UIS      = game:GetService("UserInputService")
local TweenS   = game:GetService("TweenService")
local Player   = Players.LocalPlayer

-- ══════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════
local CFG = {
    lagDuration  = 0.4,
    baseBounce   = 150,
    keybind      = Enum.KeyCode.F12,
    lockEnabled  = false,
    dynamicBoost = true,
    removeWalls  = false,
}
local COOLDOWN = 0.8

-- ══════════════════════════════════════════
-- STATE
-- ══════════════════════════════════════════
local onCooldown = false
local isFrozen   = false

local function getChar() return Player.Character end
local function getHRP()  local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum()  local c=getChar(); return c and c:FindFirstChildOfClass("Humanoid") end

-- ══════════════════════════════════════════
-- FREEZE + BOUNCE LOGIC
-- ══════════════════════════════════════════
local function doFreeze()
    if onCooldown or isFrozen then return end
    local hrp = getHRP(); local hum = getHum()
    if not hrp or not hum or hum.Health <= 0 then return end

    isFrozen = true; onCooldown = true

    local savedVel = hrp.AssemblyLinearVelocity
    local fwd = Vector3.new(savedVel.X, 0, savedVel.Z)
    local speed = fwd.Magnitude

    if CFG.removeWalls then
        for _, p in ipairs(getChar():GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end

    hrp.Anchored = true
    hum.WalkSpeed = 0
    hum.JumpPower = 0

    task.delay(CFG.lagDuration, function()
        local hrp2 = getHRP()
        if not hrp2 then isFrozen=false; onCooldown=false; return end

        hrp2.Anchored = false
        local hum2 = getHum()
        if hum2 then hum2.WalkSpeed=16; hum2.JumpPower=50 end

        if CFG.removeWalls then
            task.delay(0.3, function()
                local c=getChar(); if not c then return end
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide=true end
                end
            end)
        end

        local bounceUp = CFG.baseBounce
        local boostMul = CFG.dynamicBoost and (1+math.clamp(speed/20,0,1.5)) or 1
        local launchDir = CFG.lockEnabled and fwd or
            Vector3.new(hrp2.AssemblyLinearVelocity.X, 0, hrp2.AssemblyLinearVelocity.Z)

        hrp2.AssemblyLinearVelocity = Vector3.new(
            launchDir.X * 1.3,
            bounceUp * boostMul,
            launchDir.Z * 1.3
        )

        isFrozen = false
        task.delay(COOLDOWN, function() onCooldown=false end)
    end)
end

-- ══════════════════════════════════════════
-- GUI
-- ══════════════════════════════════════════
local function cleanup()
    for _, sg in ipairs({Player.PlayerGui, game:GetService("CoreGui")}) do
        local old = sg:FindFirstChild("LagSwitchUI")
        if old then old:Destroy() end
    end
end
cleanup()

local SG = Instance.new("ScreenGui")
SG.Name="LagSwitchUI"; SG.ResetOnSpawn=false
SG.DisplayOrder=150; SG.IgnoreGuiInset=true

if gethui then SG.Parent=gethui()
elseif syn and syn.protect_gui then syn.protect_gui(SG); SG.Parent=game:GetService("CoreGui")
elseif protect_gui then protect_gui(SG); SG.Parent=game:GetService("CoreGui")
else SG.Parent=Player.PlayerGui end

-- ── COLOURS ──────────────────────────────
local C = {
    bg     = Color3.fromRGB(8,8,14),
    panel  = Color3.fromRGB(13,10,22),
    elem   = Color3.fromRGB(22,18,36),
    hover  = Color3.fromRGB(32,26,50),
    stroke = Color3.fromRGB(255,255,255),
    purple = Color3.fromRGB(170,100,255),
    purDim = Color3.fromRGB(110,60,200),
    textW  = Color3.fromRGB(235,235,245),
    textG  = Color3.fromRGB(140,130,165),
    textD  = Color3.fromRGB(80,70,105),
    ok     = Color3.fromRGB(60,210,120),
    red    = Color3.fromRGB(220,70,70),
}

-- ── HELPERS ──────────────────────────────
local function mkC(p,r) local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r or 8) end
local function mkS(p,col,th,tr)
    local s=Instance.new("UIStroke",p)
    s.Color=col or C.stroke; s.Thickness=th or 1.2; s.Transparency=tr or 0.60
end
local function mkPad(p,l,r2,t,b)
    local pad=Instance.new("UIPadding",p)
    pad.PaddingLeft=UDim.new(0,l or 0); pad.PaddingRight=UDim.new(0,r2 or 0)
    pad.PaddingTop=UDim.new(0,t or 0); pad.PaddingBottom=UDim.new(0,b or 0)
end
local function tw(o,p,t)
    TweenS:Create(o,TweenInfo.new(t or 0.18,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),p):Play()
end
local function makeDrag(handle, target)
    local drag=false; local ds=Vector3.new(); local sp=UDim2.new()
    local function onBegin(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=true; ds=i.Position; sp=target.Position
        end
    end
    local function onEnd(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=false
        end
    end
    handle.InputBegan:Connect(onBegin)
    handle.InputEnded:Connect(onEnd)
    UIS.InputChanged:Connect(function(i)
        if not drag then return end
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
            local d=i.Position-ds
            target.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
        end
    end)
end

-- ══════════════════════════════════════════
-- FREEZE DISPLAY  (top-centre, like screenshot)
-- ══════════════════════════════════════════
local FD = Instance.new("Frame", SG)
FD.Size=UDim2.new(0,320,0,100); FD.Position=UDim2.new(0.5,-160,0.06,0)
FD.BackgroundColor3=C.panel; FD.BorderSizePixel=0; FD.Active=true
mkC(FD,14); mkS(FD,C.purple,1.5,0.45)

Instance.new("UIGradient",FD).Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(22,14,40)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(10,8,18)),
})

-- Gear button
local GearBtn=Instance.new("TextButton",FD)
GearBtn.Size=UDim2.new(0,30,0,30); GearBtn.Position=UDim2.new(1,-36,0,6)
GearBtn.BackgroundColor3=C.elem; GearBtn.Text="⚙"; GearBtn.TextSize=16
GearBtn.TextColor3=C.textG; GearBtn.Font=Enum.Font.GothamBold
GearBtn.AutoButtonColor=false; GearBtn.ZIndex=5
mkC(GearBtn,8); mkS(GearBtn,C.stroke,1,0.80)

-- Big status word
local FreezeL=Instance.new("TextLabel",FD)
FreezeL.Size=UDim2.new(1,0,0,52); FreezeL.Position=UDim2.new(0,0,0,8)
FreezeL.BackgroundTransparency=1; FreezeL.Text="READY"
FreezeL.TextSize=40; FreezeL.TextColor3=C.purple
FreezeL.Font=Enum.Font.GothamBold
FreezeL.TextXAlignment=Enum.TextXAlignment.Center; FreezeL.ZIndex=3

-- Sub status
local SubL=Instance.new("TextLabel",FD)
SubL.Size=UDim2.new(1,0,0,20); SubL.Position=UDim2.new(0,0,0,62)
SubL.BackgroundTransparency=1; SubL.Text="READY  [F12]"
SubL.TextSize=13; SubL.TextColor3=C.textG
SubL.Font=Enum.Font.Gotham
SubL.TextXAlignment=Enum.TextXAlignment.Center; SubL.ZIndex=3

makeDrag(FD, FD)

-- ══════════════════════════════════════════
-- SETTINGS PANEL  (right side)
-- ══════════════════════════════════════════
local settingsOpen=false

local SP=Instance.new("Frame",SG)
SP.Size=UDim2.new(0,190,0,0); SP.Position=UDim2.new(1,-200,0.06,0)
SP.BackgroundColor3=C.panel; SP.BorderSizePixel=0; SP.Visible=false
SP.ClipsDescendants=true
mkC(SP,14); mkS(SP,C.purple,1.5,0.45)
Instance.new("UIGradient",SP).Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(22,14,40)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(10,8,18)),
})

local SPInner=Instance.new("Frame",SP)
SPInner.Size=UDim2.new(1,0,1,0); SPInner.BackgroundTransparency=1
local SPList=Instance.new("UIListLayout",SPInner)
SPList.Padding=UDim.new(0,6); SPList.SortOrder=Enum.SortOrder.LayoutOrder
mkPad(SPInner,8,8,10,10)

-- Helper to make a settings label
local function spLabel(text, order)
    local l=Instance.new("TextLabel",SPInner)
    l.Size=UDim2.new(1,0,0,16); l.BackgroundTransparency=1
    l.Text=text; l.TextSize=11; l.TextColor3=C.textG
    l.Font=Enum.Font.GothamBold; l.TextXAlignment=Enum.TextXAlignment.Center
    l.ZIndex=4; l.LayoutOrder=order
end

-- Number input
local function spInput(val, order)
    local f=Instance.new("Frame",SPInner)
    f.Size=UDim2.new(1,0,0,34); f.BackgroundColor3=C.elem
    f.BorderSizePixel=0; f.ZIndex=4; f.LayoutOrder=order
    mkC(f,8); mkS(f,C.stroke,1,0.82)
    local tb=Instance.new("TextBox",f)
    tb.Size=UDim2.new(1,-12,1,0); tb.Position=UDim2.new(0,6,0,0)
    tb.BackgroundTransparency=1; tb.Text=tostring(val)
    tb.TextColor3=C.textW; tb.Font=Enum.Font.GothamBold
    tb.TextSize=14; tb.TextXAlignment=Enum.TextXAlignment.Center
    tb.ClearTextOnFocus=false; tb.ZIndex=5
    tb.Focused:Connect(function() tw(f,{BackgroundColor3=C.hover},0.12) end)
    tb.FocusLost:Connect(function() tw(f,{BackgroundColor3=C.elem},0.12) end)
    return tb
end

-- Toggle button
local function spToggle(label, state, order, cb)
    local btn=Instance.new("TextButton",SPInner)
    btn.Size=UDim2.new(1,0,0,36); btn.AutoButtonColor=false
    btn.BackgroundColor3=state and C.purple or C.elem
    btn.Text=label..(state and ": ON" or ": OFF")
    btn.TextSize=12; btn.TextColor3=C.textW
    btn.Font=Enum.Font.GothamBold; btn.ZIndex=4; btn.LayoutOrder=order
    mkC(btn,8)
    local s=state
    local function toggle()
        s=not s
        btn.Text=label..(s and ": ON" or ": OFF")
        tw(btn,{BackgroundColor3=s and C.purple or C.elem},0.15)
        if cb then cb(s) end
    end
    btn.MouseButton1Click:Connect(toggle)
    btn.TouchTap:Connect(toggle)
    return btn
end

-- Plain action button
local function spBtn(label, col, order, cb)
    local btn=Instance.new("TextButton",SPInner)
    btn.Size=UDim2.new(1,0,0,36); btn.AutoButtonColor=false
    btn.BackgroundColor3=col or C.elem
    btn.Text=label; btn.TextSize=12
    btn.TextColor3=col==C.ok and Color3.fromRGB(10,30,18) or C.textW
    btn.Font=Enum.Font.GothamBold; btn.ZIndex=4; btn.LayoutOrder=order
    mkC(btn,8)
    btn.MouseButton1Click:Connect(function() if cb then cb() end end)
    btn.TouchTap:Connect(function() if cb then cb() end end)
    return btn
end

spLabel("LAG DUR (S)", 1)
local LagIn=spInput(CFG.lagDuration, 2)
spLabel("BASE BOUNCE", 3)
local BounceIn=spInput(CFG.baseBounce, 4)
spLabel("KEYBIND", 5)
local KeyIn=spInput("F12", 6)
spToggle("LOCK",         CFG.lockEnabled,  7, function(s) CFG.lockEnabled=s end)
spToggle("DYNAMIC",      CFG.dynamicBoost, 8, function(s) CFG.dynamicBoost=s end)
spToggle("REMOVE WALLS", CFG.removeWalls,  9, function(s) CFG.removeWalls=s end)
spBtn("VIEW LOGS",   C.elem, 10, nil)
spBtn("BLOXSTRAP",   C.elem, 11, nil)

local ApplyBtn=spBtn("APPLY SETTINGS", C.ok, 12, nil)

-- Compute panel height after layout
local function refreshPanelHeight()
    local h=SPList.AbsoluteContentSize.Y+24
    SP.Size=UDim2.new(0,190,0,h)
end
SPList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshPanelHeight)

-- Apply logic
local function applySettings()
    local lv=tonumber(LagIn.Text)
    if lv then CFG.lagDuration=math.clamp(lv,0.05,5) end
    local bv=tonumber(BounceIn.Text)
    if bv then CFG.baseBounce=math.clamp(bv,10,500) end

    local kbStr=KeyIn.Text:upper():gsub("%s","")
    for _, v in ipairs(Enum.KeyCode:GetEnumItems()) do
        if v.Name:upper()==kbStr then CFG.keybind=v; break end
    end

    SubL.Text="READY  ["..KeyIn.Text:upper().."]"
    tw(ApplyBtn,{BackgroundColor3=Color3.fromRGB(40,210,110)},0.1)
    task.delay(0.35,function() tw(ApplyBtn,{BackgroundColor3=C.ok},0.2) end)
end
ApplyBtn.MouseButton1Click:Connect(applySettings)
ApplyBtn.TouchTap:Connect(applySettings)

-- Gear toggle with smooth slide
local function toggleSettings()
    settingsOpen=not settingsOpen
    if settingsOpen then
        SP.Visible=true
        refreshPanelHeight()
        local h=SPList.AbsoluteContentSize.Y+24
        SP.Size=UDim2.new(0,190,0,0)
        tw(SP,{Size=UDim2.new(0,190,0,h)},0.22)
    else
        tw(SP,{Size=UDim2.new(0,190,0,0)},0.18)
        task.delay(0.2,function() SP.Visible=false end)
    end
    tw(GearBtn,{TextColor3=settingsOpen and C.purple or C.textG},0.15)
end
GearBtn.MouseButton1Click:Connect(toggleSettings)
GearBtn.TouchTap:Connect(toggleSettings)


-- ══════════════════════════════════════════
-- UI STATE
-- ══════════════════════════════════════════
local function setUIFreezing()
    FreezeL.Text="FREEZE"
    tw(FreezeL,{TextColor3=Color3.fromRGB(210,160,255)},0.1)
    SubL.TextColor3=Color3.fromRGB(190,140,255)
    task.spawn(function()
        local t0=tick()
        while isFrozen do
            local rem=math.max(0,CFG.lagDuration-(tick()-t0))
            SubL.Text=string.format("Launching in %.1fs",rem)
            task.wait(0.05)
        end
    end)
end

local function setUICooldown()
    FreezeL.Text="WAIT"
    tw(FreezeL,{TextColor3=Color3.fromRGB(180,160,80)},0.1)
    SubL.Text="Cooling down..."; SubL.TextColor3=C.textG
end

local function setUIReady()
    tw(FreezeL,{TextColor3=C.purple},0.25,Enum.EasingStyle.Back)
    FreezeL.Text="READY"
    local kb=CFG.keybind.Name
    SubL.Text="READY  ["..kb.."]"; SubL.TextColor3=C.textG
end

-- ══════════════════════════════════════════
-- TRIGGER  (tap freeze display OR keybind)
-- ══════════════════════════════════════════
local function trigger()
    if onCooldown or isFrozen then return end
    setUIFreezing()
    doFreeze()
    task.delay(CFG.lagDuration,function()
        setUICooldown()
        task.delay(COOLDOWN,function() setUIReady() end)
    end)
end

-- Tap the freeze display to activate (mobile + pc)
FD.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.Touch or
       i.UserInputType==Enum.UserInputType.MouseButton1 then
        trigger()
    end
end)

-- Keybind
UIS.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.KeyCode==CFG.keybind then trigger() end
end)

-- Respawn safety
Player.CharacterAdded:Connect(function()
    isFrozen=false; onCooldown=false
    task.wait(0.5); setUIReady()
end)

setUIReady()
