-- MacroUI v4
-- Floating numbered macro keys you drag onto game buttons
-- Toggle button auto-clicks whatever is under each macro key

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

if PG:FindFirstChild("MacroUI") then PG.MacroUI:Destroy() end

-- ── SETTINGS ──────────────────────────────────────
local CLICK_INTERVAL = 0.1   -- seconds between clicks per key
local KEY_SIZE       = 60    -- size of each floating key box (px)

-- ── COLORS ────────────────────────────────────────
local C = {
    bg      = Color3.fromRGB(14, 14, 22),
    panel   = Color3.fromRGB(22, 22, 34),
    accent  = Color3.fromRGB(80, 160, 255),
    accdim  = Color3.fromRGB(40, 88, 148),
    keybg   = Color3.fromRGB(28, 28, 44),
    keyact  = Color3.fromRGB(50, 130, 255),
    text    = Color3.fromRGB(210, 215, 230),
    dim     = Color3.fromRGB(100, 105, 125),
    red     = Color3.fromRGB(255, 65, 65),
    green   = Color3.fromRGB(65, 210, 105),
    togon   = Color3.fromRGB(255, 180, 0),
    white   = Color3.new(1, 1, 1),
}

-- ── STATE ─────────────────────────────────────────
local toggled    = false   -- are macros firing?
local locked     = false   -- lock all keys in place
local macroKeys  = {}      -- list of key objects
local keyCount   = 0
local timers     = {}      -- per-key click timer

-- ── HELPERS ───────────────────────────────────────
local function tw(o, p, t)
    pcall(function()
        TS:Create(o, TweenInfo.new(t or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), p):Play()
    end)
end

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
end

local function stroke(p, col, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or C.accent
    s.Thickness = 1.5
    s.Transparency = tr or 0.4
    s.Parent = p
end

local function lbl(p, txt, sz, col, xa)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextSize = sz or 13
    l.TextColor3 = col or C.text
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = xa or Enum.TextXAlignment.Center
    l.TextYAlignment = Enum.TextYAlignment.Center
    l.Size = UDim2.new(1, 0, 1, 0)
    l.Parent = p
    return l
end

local function mkbtn(p, txt, sz, bg, tc)
    local b = Instance.new("TextButton")
    b.Size = sz or UDim2.new(0, 80, 0, 32)
    b.BackgroundColor3 = bg or C.accent
    b.TextColor3 = tc or Color3.fromRGB(10, 10, 16)
    b.Text = txt
    b.TextSize = 13
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    corner(b, 8)
    b.Parent = p
    return b
end

-- ── FIND GUI ELEMENT UNDER ABSOLUTE POSITION ──────
-- Returns the topmost clickable GuiButton at screen position (x, y)
-- ignoring our own MacroUI elements
local function getButtonAt(ax, ay)
    local found = nil
    local foundZ = -math.huge
    for _, gui in ipairs(PG:GetChildren()) do
        if gui.Name == "MacroUI" then continue end
        for _, obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("GuiButton") and obj.Visible then
                local absPos  = obj.AbsolutePosition
                local absSize = obj.AbsoluteSize
                if ax >= absPos.X and ax <= absPos.X + absSize.X
                and ay >= absPos.Y and ay <= absPos.Y + absSize.Y then
                    local z = obj.ZIndex or 1
                    if z > foundZ then
                        foundZ = z
                        found  = obj
                    end
                end
            end
        end
    end
    return found
end

-- Click a button safely
local function clickButton(btn)
    pcall(function() btn.MouseButton1Click:Fire() end)
    pcall(function() btn.Activated:Fire() end)
end

-- ── MAIN SCREENGUI ────────────────────────────────
local SG = Instance.new("ScreenGui")
SG.Name = "MacroUI"
SG.ResetOnSpawn = false
SG.DisplayOrder = 9999
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent = PG

-- ── CONTROL PANEL ─────────────────────────────────
local Panel = Instance.new("Frame")
Panel.Name = "Panel"
Panel.Size = UDim2.new(0, 220, 0, 130)
Panel.Position = UDim2.new(0, 20, 0, 80)
Panel.BackgroundColor3 = C.bg
Panel.BorderSizePixel = 0
Panel.ZIndex = 10
corner(Panel, 12)
stroke(Panel, C.accent, 0.3)
Panel.Parent = SG

-- Panel gradient
local pg = Instance.new("UIGradient")
pg.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 34)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 20)),
})
pg.Rotation = 135
pg.Parent = Panel

-- Panel title bar (drag handle)
local PTitle = Instance.new("Frame")
PTitle.Size = UDim2.new(1, 0, 0, 36)
PTitle.BackgroundColor3 = C.panel
PTitle.BorderSizePixel = 0
PTitle.ZIndex = 11
corner(PTitle, 12)
PTitle.Parent = Panel

local PTFix = Instance.new("Frame")
PTFix.Size = UDim2.new(1, 0, 0.5, 0)
PTFix.Position = UDim2.new(0, 0, 0.5, 0)
PTFix.BackgroundColor3 = C.panel
PTFix.BorderSizePixel = 0
PTFix.ZIndex = 11
PTFix.Parent = PTitle

local PTitleLbl = lbl(PTitle, "MacroUI", 13, C.accent)
PTitleLbl.Position = UDim2.new(0, 12, 0, 0)
PTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
PTitleLbl.ZIndex = 12

-- Drag panel
do
    local drag, sp, sm = false, nil, nil
    PTitle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; sp = Panel.Position; sm = i.Position
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
            Panel.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
end

-- Minimize button on panel
local minPanel = false
local MinPBtn = mkbtn(PTitle, "-", UDim2.new(0, 26, 0, 22), C.keybg, C.text)
MinPBtn.Position = UDim2.new(1, -32, 0.5, -11)
MinPBtn.ZIndex = 13
MinPBtn.MouseButton1Click:Connect(function()
    minPanel = not minPanel
    tw(Panel, {Size = minPanel and UDim2.new(0, 220, 0, 36) or UDim2.new(0, 220, 0, 130)})
    MinPBtn.Text = minPanel and "+" or "-"
end)

-- ── TOGGLE BUTTON (big, on panel) ─────────────────
local TogBtn = mkbtn(Panel, "TOGGLE  OFF", UDim2.new(1, -20, 0, 38), C.accdim, C.white)
TogBtn.Position = UDim2.new(0, 10, 0, 44)
TogBtn.TextSize = 14
TogBtn.ZIndex = 11

local function setToggle(val)
    toggled = val
    if val then
        tw(TogBtn, {BackgroundColor3 = C.togon})
        TogBtn.Text = "TOGGLE  ON"
        TogBtn.TextColor3 = Color3.fromRGB(10, 10, 16)
    else
        tw(TogBtn, {BackgroundColor3 = C.accdim})
        TogBtn.Text = "TOGGLE  OFF"
        TogBtn.TextColor3 = C.white
    end
    -- Flash all macro keys
    for _, k in ipairs(macroKeys) do
        tw(k.frame, {BackgroundColor3 = val and C.keyact or C.keybg}, 0.12)
    end
end

TogBtn.MouseButton1Click:Connect(function() setToggle(not toggled) end)

-- ── ADD / LOCK BUTTONS ────────────────────────────
local BtnRow = Instance.new("Frame")
BtnRow.Size = UDim2.new(1, -20, 0, 30)
BtnRow.Position = UDim2.new(0, 10, 0, 90)
BtnRow.BackgroundTransparency = 1
BtnRow.ZIndex = 11
BtnRow.Parent = Panel

local AddBtn = mkbtn(BtnRow, "+ Add Key", UDim2.new(0.58, -3, 1, 0), C.accent, Color3.fromRGB(10,10,16))
AddBtn.Position = UDim2.new(0, 0, 0, 0)
AddBtn.ZIndex = 12

local LockBtn = mkbtn(BtnRow, "Lock", UDim2.new(0.42, -3, 1, 0), C.keybg, C.text)
LockBtn.Position = UDim2.new(0.58, 3, 0, 0)
LockBtn.ZIndex = 12

LockBtn.MouseButton1Click:Connect(function()
    locked = not locked
    LockBtn.Text = locked and "Unlock" or "Lock"
    tw(LockBtn, {BackgroundColor3 = locked and C.red or C.keybg})
    -- Show/hide delete X on all keys based on lock
    for _, k in ipairs(macroKeys) do
        k.delBtn.Visible = not locked
    end
end)

-- ── CREATE FLOATING MACRO KEY ──────────────────────
local function addMacroKey()
    keyCount = keyCount + 1
    local num = keyCount

    -- Floating key frame
    local kf = Instance.new("Frame")
    kf.Name = "MacroKey" .. num
    kf.Size = UDim2.new(0, KEY_SIZE, 0, KEY_SIZE)
    -- Spawn near center, offset each key so they don't stack
    kf.Position = UDim2.new(0.5, -30 + (num - 1) * 70, 0.5, -30)
    kf.BackgroundColor3 = C.keybg
    kf.BorderSizePixel = 0
    kf.ZIndex = 100
    kf.Active = true
    corner(kf, 10)
    stroke(kf, C.accent, 0.3)
    kf.Parent = SG

    -- Number label
    local numLbl = lbl(kf, tostring(num), 22, C.accent)
    numLbl.ZIndex = 101

    -- Locked indicator dot (top right)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(1, -11, 0, 3)
    dot.BackgroundColor3 = C.green
    dot.BorderSizePixel = 0
    dot.ZIndex = 102
    dot.Visible = false
    corner(dot, 99)
    dot.Parent = kf

    -- Delete button (small X top-left)
    local delB = mkbtn(kf, "x", UDim2.new(0, 18, 0, 18), Color3.fromRGB(60, 18, 18), C.red)
    delB.Position = UDim2.new(0, 2, 0, 2)
    delB.TextSize = 10
    delB.ZIndex = 103

    -- Key object
    local keyObj = {
        frame  = kf,
        num    = num,
        delBtn = delB,
        dot    = dot,
        timer  = 0,
    }
    table.insert(macroKeys, keyObj)

    -- Entrance animation
    kf.BackgroundTransparency = 1
    kf.Size = UDim2.new(0, 0, 0, 0)
    task.spawn(function()
        task.wait()
        tw(kf, {Size = UDim2.new(0, KEY_SIZE, 0, KEY_SIZE), BackgroundTransparency = 0}, 0.22)
    end)

    -- Delete
    delB.MouseButton1Click:Connect(function()
        for i, k in ipairs(macroKeys) do
            if k == keyObj then table.remove(macroKeys, i) break end
        end
        tw(kf, {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}, 0.18)
        task.delay(0.2, function() kf:Destroy() end)
    end)

    -- ── DRAG the floating key ──
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

AddBtn.MouseButton1Click:Connect(addMacroKey)

-- ── MACRO CLICK RUNNER ────────────────────────────
RS.Heartbeat:Connect(function(dt)
    if not toggled then return end
    for _, k in ipairs(macroKeys) do
        k.timer = k.timer + dt
        if k.timer >= CLICK_INTERVAL then
            k.timer = 0
            -- Find center of this key box in absolute screen coords
            local absPos  = k.frame.AbsolutePosition
            local absSize = k.frame.AbsoluteSize
            local cx = absPos.X + absSize.X * 0.5
            local cy = absPos.Y + absSize.Y * 0.5
            -- Find a game button under that position
            local target = getButtonAt(cx, cy)
            if target then
                clickButton(target)
                -- Flash green to show it fired
                tw(k.frame, {BackgroundColor3 = C.green}, 0.05)
                task.delay(0.08, function()
                    tw(k.frame, {BackgroundColor3 = C.keyact}, 0.1)
                end)
            else
                -- No button found - show dim pulse
                tw(k.frame, {BackgroundColor3 = Color3.fromRGB(50, 50, 70)}, 0.05)
                task.delay(0.08, function()
                    tw(k.frame, {BackgroundColor3 = C.keyact}, 0.1)
                end)
            end
        end
    end
end)

-- ── PANEL OPEN ANIMATION ──────────────────────────
Panel.Size = UDim2.new(0, 220, 0, 0)
Panel.BackgroundTransparency = 1
task.spawn(function()
    task.wait(0.05)
    tw(Panel, {Size = UDim2.new(0, 220, 0, 130), BackgroundTransparency = 0}, 0.28)
end)

print("MacroUI loaded - tap Add Key, drag boxes onto game buttons, then hit Toggle")
