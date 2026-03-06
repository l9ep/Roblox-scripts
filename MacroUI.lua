-- MacroUI v5
-- Floating macro keys you place on game buttons
-- Toggle = one tap or auto tap all macro keys

local Players   = game:GetService("Players")
local UIS       = game:GetService("UserInputService")
local RS        = game:GetService("RunService")
local TS        = game:GetService("TweenService")

local LP  = Players.LocalPlayer
local PG  = LP:WaitForChild("PlayerGui")

if PG:FindFirstChild("MacroUI") then PG.MacroUI:Destroy() end

-- ═══════════════════════════════════════════════
-- COLORS
-- ═══════════════════════════════════════════════
local BG     = Color3.fromRGB(10,  10,  14)
local PANEL  = Color3.fromRGB(18,  18,  26)
local RED    = Color3.fromRGB(210, 30,  30)
local REDLIT = Color3.fromRGB(255, 60,  60)
local REDDIM = Color3.fromRGB(120, 20,  20)
local WHITE  = Color3.new(1, 1, 1)
local GRAY   = Color3.fromRGB(160, 160, 175)
local DARK   = Color3.fromRGB(28,  28,  40)
local GREEN  = Color3.fromRGB(50,  200, 90)
local YELLOW = Color3.fromRGB(255, 200, 0)
local TEXTC  = Color3.fromRGB(220, 220, 235)
local DIMC   = Color3.fromRGB(100, 100, 118)

-- ═══════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════
local MODE       = "onetap"   -- "onetap" or "autotap"
local autoActive = false      -- autotap running?
local locked     = false
local opacity    = 1
local macroKeys  = {}
local keyCount   = 0
local AUTO_INTERVAL = 0.1

-- ═══════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════
local function tw(o, p, t)
    pcall(function()
        TS:Create(o, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), p):Play()
    end)
end

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
    return c
end

local function mkStroke(p, col, th, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or RED
    s.Thickness = th or 1.5
    s.Transparency = tr or 0.3
    s.Parent = p
    return s
end

local function mkLabel(p, txt, sz, col, xa, ya)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextSize = sz or 13
    l.TextColor3 = col or TEXTC
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = xa or Enum.TextXAlignment.Center
    l.TextYAlignment = ya or Enum.TextYAlignment.Center
    l.Size = UDim2.new(1, 0, 1, 0)
    l.Parent = p
    return l
end

local function mkBtn(p, txt, sz, bg, tc, rad)
    local b = Instance.new("TextButton")
    b.Size = sz or UDim2.new(0, 80, 0, 30)
    b.BackgroundColor3 = bg or RED
    b.TextColor3 = tc or WHITE
    b.Text = txt
    b.TextSize = 13
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    corner(b, rad or 8)
    b.Parent = p
    return b
end

-- Make any frame draggable
local function makeDraggable(win, handle)
    local drag, sp, sm = false, nil, nil
    handle = handle or win
    handle.InputBegan:Connect(function(i)
        if locked then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; sp = win.Position; sm = i.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not drag then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            local d = i.Position - sm
            win.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
end

-- Find topmost GuiButton under screen point, ignoring our own UI
local function getButtonAt(ax, ay)
    local best, bestZ = nil, -math.huge
    for _, gui in ipairs(PG:GetChildren()) do
        if gui.Name == "MacroUI" then continue end
        for _, obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("GuiButton") and obj.Visible then
                local ap = obj.AbsolutePosition
                local as = obj.AbsoluteSize
                if ax >= ap.X and ax <= ap.X + as.X and ay >= ap.Y and ay <= ap.Y + as.Y then
                    local z = obj.ZIndex or 1
                    if z > bestZ then bestZ = z; best = obj end
                end
            end
        end
    end
    return best
end

local function fireButton(obj)
    pcall(function() obj.MouseButton1Click:Fire() end)
    pcall(function() obj.Activated:Fire() end)
end

-- Get center of a frame in absolute screen coords
local function centerOf(frame)
    local ap = frame.AbsolutePosition
    local as = frame.AbsoluteSize
    return ap.X + as.X * 0.5, ap.Y + as.Y * 0.5
end

-- Flash a frame a color briefly
local function flash(frame, col, orig)
    tw(frame, {BackgroundColor3 = col}, 0.06)
    task.delay(0.12, function() tw(frame, {BackgroundColor3 = orig}, 0.1) end)
end

-- Apply opacity to a frame and its non-transparent children
local function applyOpacity(frame, op)
    frame.BackgroundTransparency = 1 - op
    for _, d in ipairs(frame:GetDescendants()) do
        if d:IsA("Frame") or d:IsA("TextButton") then
            if d.BackgroundTransparency < 1 then
                d.BackgroundTransparency = 1 - op
            end
        end
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            d.TextTransparency = 1 - op
        end
        if d:IsA("UIStroke") then
            d.Transparency = math.max(0, (1 - op) + 0.3)
        end
    end
end

-- Click all macro keys once
local function triggerAllOnce()
    for _, k in ipairs(macroKeys) do
        local cx, cy = centerOf(k.frame)
        local target = getButtonAt(cx, cy)
        if target then
            fireButton(target)
            flash(k.frame, GREEN, DARK)
        else
            flash(k.frame, REDDIM, DARK)
        end
    end
end

-- ═══════════════════════════════════════════════
-- SCREENGUI
-- ═══════════════════════════════════════════════
local SG = Instance.new("ScreenGui")
SG.Name = "MacroUI"
SG.ResetOnSpawn = false
SG.DisplayOrder = 9999
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent = PG

-- ═══════════════════════════════════════════════
-- CONTROL PANEL
-- ═══════════════════════════════════════════════
local Panel = Instance.new("Frame")
Panel.Name = "Panel"
Panel.Size = UDim2.new(0, 230, 0, 200)
Panel.Position = UDim2.new(0, 16, 0, 60)
Panel.BackgroundColor3 = BG
Panel.BorderSizePixel = 0
Panel.ZIndex = 20
corner(Panel, 14)
mkStroke(Panel, RED, 1.5, 0.2)
Panel.Parent = SG

-- Red top accent bar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = RED
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 21
corner(TopBar, 14)
TopBar.Parent = Panel

local TBFix = Instance.new("Frame")
TBFix.Size = UDim2.new(1, 0, 0.5, 0)
TBFix.Position = UDim2.new(0, 0, 0.5, 0)
TBFix.BackgroundColor3 = RED
TBFix.BorderSizePixel = 0
TBFix.ZIndex = 21
TBFix.Parent = TopBar

local TitleL = mkLabel(TopBar, "MACRO UI", 14, WHITE)
TitleL.Position = UDim2.new(0, 12, 0, 0)
TitleL.TextXAlignment = Enum.TextXAlignment.Left
TitleL.ZIndex = 22

-- Minimize
local minP = false
local MinBtn = mkBtn(TopBar, "-", UDim2.new(0, 26, 0, 22), REDDIM, WHITE, 6)
MinBtn.Position = UDim2.new(1, -32, 0.5, -11)
MinBtn.ZIndex = 23
MinBtn.MouseButton1Click:Connect(function()
    minP = not minP
    tw(Panel, {Size = minP and UDim2.new(0, 230, 0, 40) or UDim2.new(0, 230, 0, 200)})
    MinBtn.Text = minP and "+" or "-"
end)

makeDraggable(Panel, TopBar)

-- ── ADD KEY BUTTON ────────────────────────────
local AddKeyBtn = mkBtn(Panel, "+ Add Macro Key", UDim2.new(1, -20, 0, 34), DARK, RED, 8)
AddKeyBtn.Position = UDim2.new(0, 10, 0, 50)
AddKeyBtn.ZIndex = 21
mkStroke(AddKeyBtn, RED, 1, 0.4)

-- ── MODE ROW (One Tap / Auto Tap) ─────────────
local ModeRow = Instance.new("Frame")
ModeRow.Size = UDim2.new(1, -20, 0, 30)
ModeRow.Position = UDim2.new(0, 10, 0, 93)
ModeRow.BackgroundColor3 = DARK
ModeRow.BorderSizePixel = 0
ModeRow.ZIndex = 21
corner(ModeRow, 8)
ModeRow.Parent = Panel

local OneTapBtn = mkBtn(ModeRow, "One Tap", UDim2.new(0.5, -2, 1, 0), RED, WHITE, 7)
OneTapBtn.Position = UDim2.new(0, 0, 0, 0)
OneTapBtn.ZIndex = 22

local AutoTapBtn = mkBtn(ModeRow, "Auto Tap", UDim2.new(0.5, -2, 1, 0), DARK, DIMC, 7)
AutoTapBtn.Position = UDim2.new(0.5, 2, 0, 0)
AutoTapBtn.ZIndex = 22

local function setMode(m)
    MODE = m
    if m == "onetap" then
        tw(OneTapBtn,  {BackgroundColor3 = RED})
        tw(AutoTapBtn, {BackgroundColor3 = DARK})
        OneTapBtn.TextColor3  = WHITE
        AutoTapBtn.TextColor3 = DIMC
    else
        tw(OneTapBtn,  {BackgroundColor3 = DARK})
        tw(AutoTapBtn, {BackgroundColor3 = RED})
        OneTapBtn.TextColor3  = DIMC
        AutoTapBtn.TextColor3 = WHITE
    end
end

OneTapBtn.MouseButton1Click:Connect(function()  setMode("onetap") end)
AutoTapBtn.MouseButton1Click:Connect(function() setMode("autotap") end)

-- ── LOCK BUTTON ───────────────────────────────
local LockBtn = mkBtn(Panel, "Lock All", UDim2.new(1, -20, 0, 30), DARK, GRAY, 8)
LockBtn.Position = UDim2.new(0, 10, 0, 132)
LockBtn.ZIndex = 21
mkStroke(LockBtn, GRAY, 1, 0.5)
LockBtn.MouseButton1Click:Connect(function()
    locked = not locked
    LockBtn.Text = locked and "Unlock All" or "Lock All"
    tw(LockBtn, {BackgroundColor3 = locked and REDDIM or DARK})
    LockBtn.TextColor3 = locked and REDLIT or GRAY
end)

-- ── OPACITY ROW ───────────────────────────────
local OpRow = Instance.new("Frame")
OpRow.Size = UDim2.new(1, -20, 0, 28)
OpRow.Position = UDim2.new(0, 10, 0, 170)
OpRow.BackgroundColor3 = DARK
OpRow.BorderSizePixel = 0
OpRow.ZIndex = 21
corner(OpRow, 8)
OpRow.Parent = Panel

local OpLbl = mkLabel(OpRow, "Opacity", 11, DIMC, Enum.TextXAlignment.Left)
OpLbl.Size = UDim2.new(0, 58, 1, 0)
OpLbl.Position = UDim2.new(0, 8, 0, 0)
OpLbl.ZIndex = 22

local OpPct = mkLabel(OpRow, "100%", 11, RED, Enum.TextXAlignment.Right)
OpPct.Size = UDim2.new(0, 36, 1, 0)
OpPct.Position = UDim2.new(1, -42, 0, 0)
OpPct.ZIndex = 22

local SliderBg = Instance.new("Frame")
SliderBg.Size = UDim2.new(1, -106, 0, 5)
SliderBg.Position = UDim2.new(0, 64, 0.5, -2)
SliderBg.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
SliderBg.BorderSizePixel = 0
SliderBg.ZIndex = 22
corner(SliderBg, 99)
SliderBg.Parent = OpRow

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new(1, 0, 1, 0)
SliderFill.BackgroundColor3 = RED
SliderFill.BorderSizePixel = 0
SliderFill.ZIndex = 22
corner(SliderFill, 99)
SliderFill.Parent = SliderBg

local SliderKnob = Instance.new("Frame")
SliderKnob.Size = UDim2.new(0, 14, 0, 14)
SliderKnob.Position = UDim2.new(1, -7, 0.5, -7)
SliderKnob.BackgroundColor3 = WHITE
SliderKnob.BorderSizePixel = 0
SliderKnob.ZIndex = 23
corner(SliderKnob, 99)
SliderKnob.Parent = SliderBg

local sliding = false
SliderBg.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        sliding = true
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        sliding = false
    end
end)
UIS.InputChanged:Connect(function(i)
    if not sliding then return end
    if i.UserInputType ~= Enum.UserInputType.MouseMovement
    and i.UserInputType ~= Enum.UserInputType.Touch then return end
    local r = math.clamp((i.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0.1, 1)
    opacity = r
    SliderFill.Size = UDim2.new(r, 0, 1, 0)
    SliderKnob.Position = UDim2.new(r, -7, 0.5, -7)
    OpPct.Text = math.floor(r * 100) .. "%"
    -- Apply to toggle button and all macro keys
    for _, k in ipairs(macroKeys) do
        applyOpacity(k.frame, r)
    end
    if ToggleButton then
        applyOpacity(ToggleButton, r)
    end
end)

-- ═══════════════════════════════════════════════
-- FLOATING TOGGLE BUTTON
-- ═══════════════════════════════════════════════
ToggleButton = Instance.new("Frame")
ToggleButton.Name = "ToggleButton"
ToggleButton.Size = UDim2.new(0, 110, 0, 50)
ToggleButton.Position = UDim2.new(0.5, -55, 0, 80)
ToggleButton.BackgroundColor3 = RED
ToggleButton.BorderSizePixel = 0
ToggleButton.ZIndex = 50
ToggleButton.Active = true
corner(ToggleButton, 12)
mkStroke(ToggleButton, REDLIT, 1.5, 0.1)
ToggleButton.Parent = SG

-- Glow effect frame
local TGlow = Instance.new("Frame")
TGlow.Size = UDim2.new(1, 10, 1, 10)
TGlow.Position = UDim2.new(0, -5, 0, -5)
TGlow.BackgroundColor3 = RED
TGlow.BackgroundTransparency = 0.8
TGlow.BorderSizePixel = 0
TGlow.ZIndex = 49
corner(TGlow, 16)
TGlow.Parent = ToggleButton

local TogLbl = mkLabel(ToggleButton, "TOGGLE", 15, WHITE)
TogLbl.ZIndex = 51

local TogSubLbl = mkLabel(ToggleButton, "ONE TAP", 9, Color3.fromRGB(255, 180, 180))
TogSubLbl.Position = UDim2.new(0, 0, 0.6, 0)
TogSubLbl.Size = UDim2.new(1, 0, 0.4, 0)
TogSubLbl.ZIndex = 51

makeDraggable(ToggleButton)

-- Auto tap heartbeat timer
local autoTimer = 0
RS.Heartbeat:Connect(function(dt)
    if MODE ~= "autotap" or not autoActive then return end
    autoTimer = autoTimer + dt
    if autoTimer < AUTO_INTERVAL then return end
    autoTimer = 0
    triggerAllOnce()
end)

-- Pulse glow when autotap active
RS.Heartbeat:Connect(function()
    if autoActive then
        TGlow.BackgroundTransparency = 0.6 + 0.3 * math.sin(tick() * 6)
    else
        TGlow.BackgroundTransparency = 0.9
    end
end)

-- Toggle button click logic
local TogClickBtn = Instance.new("TextButton")
TogClickBtn.Size = UDim2.new(1, 0, 1, 0)
TogClickBtn.BackgroundTransparency = 1
TogClickBtn.Text = ""
TogClickBtn.ZIndex = 52
TogClickBtn.Parent = ToggleButton

TogClickBtn.MouseButton1Click:Connect(function()
    if MODE == "onetap" then
        -- One tap: fire once, flash button
        triggerAllOnce()
        tw(ToggleButton, {BackgroundColor3 = GREEN}, 0.08)
        task.delay(0.2, function() tw(ToggleButton, {BackgroundColor3 = RED}) end)
    else
        -- Auto tap: toggle on/off
        autoActive = not autoActive
        if autoActive then
            tw(ToggleButton, {BackgroundColor3 = REDDIM})
            TogLbl.Text = "STOP"
            TogSubLbl.Text = "AUTO ON"
        else
            tw(ToggleButton, {BackgroundColor3 = RED})
            TogLbl.Text = "TOGGLE"
            TogSubLbl.Text = "AUTO TAP"
        end
    end
end)

-- Update toggle sublabel when mode changes
local origSetMode = setMode
setMode = function(m)
    origSetMode(m)
    if m == "onetap" then
        TogSubLbl.Text = "ONE TAP"
        if autoActive then
            autoActive = false
            tw(ToggleButton, {BackgroundColor3 = RED})
            TogLbl.Text = "TOGGLE"
        end
    else
        TogSubLbl.Text = "AUTO TAP"
    end
end

OneTapBtn.MouseButton1Click:Connect(function()  setMode("onetap") end)
AutoTapBtn.MouseButton1Click:Connect(function() setMode("autotap") end)

-- ═══════════════════════════════════════════════
-- CREATE FLOATING MACRO KEY
-- ═══════════════════════════════════════════════
local function addMacroKey()
    keyCount = keyCount + 1
    local num = keyCount

    local kf = Instance.new("Frame")
    kf.Name = "MacroKey" .. num
    kf.Size = UDim2.new(0, 58, 0, 58)
    kf.Position = UDim2.new(0.5, -29 + ((num - 1) % 5) * 68, 0.3, ((math.floor((num-1)/5)) * 70))
    kf.BackgroundColor3 = DARK
    kf.BorderSizePixel = 0
    kf.ZIndex = 60
    kf.Active = true
    corner(kf, 10)
    mkStroke(kf, RED, 1.5, 0.2)
    kf.Parent = SG

    -- Number label
    local numL = mkLabel(kf, tostring(num), 24, RED)
    numL.ZIndex = 61

    -- Small "M" tag bottom right
    local tag = mkLabel(kf, "M", 9, DIMC)
    tag.Size = UDim2.new(0, 14, 0, 14)
    tag.Position = UDim2.new(1, -15, 1, -15)
    tag.ZIndex = 62

    -- Delete X (top left, hidden when locked)
    local delB = mkBtn(kf, "x", UDim2.new(0, 18, 0, 18), Color3.fromRGB(50, 12, 12), REDLIT, 5)
    delB.Position = UDim2.new(0, 2, 0, 2)
    delB.TextSize = 10
    delB.ZIndex = 63

    local keyObj = {frame = kf, num = num, delBtn = delB}
    table.insert(macroKeys, keyObj)

    -- Entrance pop animation
    kf.BackgroundTransparency = 1
    kf.Size = UDim2.new(0, 10, 0, 10)
    kf.Position = UDim2.new(
        kf.Position.X.Scale, kf.Position.X.Offset + 24,
        kf.Position.Y.Scale, kf.Position.Y.Offset + 24
    )
    task.spawn(function()
        task.wait()
        tw(kf, {
            Size = UDim2.new(0, 58, 0, 58),
            BackgroundTransparency = 0
        }, 0.2)
        applyOpacity(kf, opacity)
    end)

    -- Delete
    delB.MouseButton1Click:Connect(function()
        for i, k in ipairs(macroKeys) do
            if k == keyObj then table.remove(macroKeys, i) break end
        end
        tw(kf, {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}, 0.15)
        task.delay(0.18, function() kf:Destroy() end)
    end)

    -- Drag
    local drag, sp, sm = false, nil, nil
    kf.InputBegan:Connect(function(i)
        if locked then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; sp = kf.Position; sm = i.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not drag then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            local d = i.Position - sm
            kf.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)

    return keyObj
end

AddKeyBtn.MouseButton1Click:Connect(addMacroKey)

-- ═══════════════════════════════════════════════
-- PANEL OPEN ANIMATION
-- ═══════════════════════════════════════════════
Panel.Size = UDim2.new(0, 230, 0, 0)
Panel.BackgroundTransparency = 1
task.spawn(function()
    task.wait(0.06)
    tw(Panel, {Size = UDim2.new(0, 230, 0, 200), BackgroundTransparency = 0}, 0.3)
end)

print("MacroUI ready")
