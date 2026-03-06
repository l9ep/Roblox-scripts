-- MacroUI v3 - Mobile Delta Compatible
-- No CoreGui, no VirtualInputManager, no emoji characters

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

-- Remove old UI
if PG:FindFirstChild("MacroUI") then
    PG.MacroUI:Destroy()
end

-- Config
local ACCENT   = Color3.fromRGB(80, 160, 255)
local DARK     = Color3.fromRGB(13, 13, 20)
local PANEL    = Color3.fromRGB(22, 22, 32)
local KEYBG    = Color3.fromRGB(28, 28, 42)
local RED      = Color3.fromRGB(255, 70, 70)
local GREEN    = Color3.fromRGB(70, 210, 110)
local TEXTC    = Color3.fromRGB(210, 210, 225)
local DIMC     = Color3.fromRGB(110, 110, 135)
local ACCDIM   = Color3.fromRGB(45, 90, 150)

local INTERVAL = 0.08
local macros   = {}
local active   = false
local locked   = false
local rowCount = 0

-- Tween helper
local function tw(obj, props, t)
    pcall(function()
        TS:Create(obj, TweenInfo.new(t or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
    end)
end

-- Corner helper
local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
end

-- Stroke helper
local function stroke(p, col)
    local s = Instance.new("UIStroke")
    s.Color = col or ACCENT
    s.Thickness = 1
    s.Transparency = 0.6
    s.Parent = p
end

-- Label helper
local function lbl(p, txt, sz, col, xa)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextSize = sz or 13
    l.TextColor3 = col or TEXTC
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = xa or Enum.TextXAlignment.Left
    l.Size = UDim2.new(1, 0, 1, 0)
    l.Parent = p
    return l
end

-- Button helper
local function btn(p, txt, sz, bg, tc)
    local b = Instance.new("TextButton")
    b.Size = sz or UDim2.new(0, 80, 0, 28)
    b.BackgroundColor3 = bg or ACCENT
    b.TextColor3 = tc or Color3.fromRGB(10, 10, 15)
    b.Text = txt
    b.TextSize = 12
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    corner(b, 6)
    b.Parent = p
    return b
end

-- TextBox helper
local function tbox(p, ph, sz, pos)
    local t = Instance.new("TextBox")
    t.Size = sz or UDim2.new(0, 80, 0, 28)
    t.Position = pos or UDim2.new(0, 0, 0, 0)
    t.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
    t.TextColor3 = ACCENT
    t.PlaceholderText = ph or ""
    t.PlaceholderColor3 = DIMC
    t.Text = ""
    t.TextSize = 12
    t.Font = Enum.Font.Gotham
    t.BorderSizePixel = 0
    t.ClearTextOnFocus = false
    corner(t, 6)
    stroke(t, ACCDIM)
    t.Parent = p
    return t
end

-- GUI button fire
local function fireGui(path)
    if not path or path == "" then return end
    local parts = string.split(path, ".")
    local cur = PG
    for _, part in ipairs(parts) do
        cur = cur:FindFirstChild(part)
        if not cur then return end
    end
    if cur and cur:IsA("GuiButton") then
        pcall(function() cur.MouseButton1Click:Fire() end)
    end
end

-- Dragging
local function draggable(win, handle)
    local drag, sp, sm = false, nil, nil
    handle.InputBegan:Connect(function(i)
        if locked then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag = true
            sp = win.Position
            sm = i.Position
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

-- ScreenGui - parent directly to PlayerGui (mobile safe)
local SG = Instance.new("ScreenGui")
SG.Name = "MacroUI"
SG.ResetOnSpawn = false
SG.DisplayOrder = 9999
SG.Parent = PG

-- Main window
local Win = Instance.new("Frame")
Win.Name = "Win"
Win.Size = UDim2.new(0, 400, 0, 500)
Win.Position = UDim2.new(0.5, -200, 0.5, -250)
Win.BackgroundColor3 = DARK
Win.BorderSizePixel = 0
Win.ClipsDescendants = true
corner(Win, 12)
stroke(Win, ACCENT)
Win.Parent = SG

-- Title bar
local TBar = Instance.new("Frame")
TBar.Size = UDim2.new(1, 0, 0, 46)
TBar.BackgroundColor3 = PANEL
TBar.BorderSizePixel = 0
corner(TBar, 12)
TBar.Parent = Win

local TFix = Instance.new("Frame")
TFix.Size = UDim2.new(1, 0, 0.5, 0)
TFix.Position = UDim2.new(0, 0, 0.5, 0)
TFix.BackgroundColor3 = PANEL
TFix.BorderSizePixel = 0
TFix.Parent = TBar

local TitleLbl = lbl(TBar, "MacroUI", 15, ACCENT)
TitleLbl.Size = UDim2.new(0, 100, 1, 0)
TitleLbl.Position = UDim2.new(0, 14, 0, 0)
TitleLbl.ZIndex = 3

local SubLbl = lbl(TBar, "F6=toggle  F7=hide", 10, DIMC)
SubLbl.Size = UDim2.new(0, 130, 1, 0)
SubLbl.Position = UDim2.new(0, 116, 0, 0)
SubLbl.ZIndex = 3

draggable(Win, TBar)

-- Lock btn
local LockB = btn(TBar, "Unlock", UDim2.new(0, 62, 0, 26), KEYBG, TEXTC)
LockB.Position = UDim2.new(1, -162, 0.5, -13)
LockB.ZIndex = 4
LockB.MouseButton1Click:Connect(function()
    locked = not locked
    LockB.Text = locked and "Locked" or "Unlock"
    tw(LockB, {BackgroundColor3 = locked and RED or KEYBG})
end)

-- Minimize btn
local minimized = false
local MinB = btn(TBar, "-", UDim2.new(0, 30, 0, 26), KEYBG, TEXTC)
MinB.Position = UDim2.new(1, -94, 0.5, -13)
MinB.ZIndex = 4
MinB.MouseButton1Click:Connect(function()
    minimized = not minimized
    tw(Win, {Size = minimized and UDim2.new(0, 400, 0, 46) or UDim2.new(0, 400, 0, 500)})
    MinB.Text = minimized and "+" or "-"
end)

-- Close btn
local CloseB = btn(TBar, "X", UDim2.new(0, 30, 0, 26), Color3.fromRGB(180, 45, 45), Color3.new(1,1,1))
CloseB.Position = UDim2.new(1, -40, 0.5, -13)
CloseB.ZIndex = 4
CloseB.MouseButton1Click:Connect(function()
    tw(Win, {Size = UDim2.new(0, 400, 0, 0)}, 0.2)
    task.delay(0.22, function() SG:Destroy() end)
end)

-- Toggle row
local TogRow = Instance.new("Frame")
TogRow.Size = UDim2.new(1, -20, 0, 50)
TogRow.Position = UDim2.new(0, 10, 0, 54)
TogRow.BackgroundColor3 = PANEL
TogRow.BorderSizePixel = 0
corner(TogRow, 10)
stroke(TogRow, ACCDIM)
TogRow.Parent = Win

local TogLbl = lbl(TogRow, "Global Toggle", 13, TEXTC)
TogLbl.Size = UDim2.new(0, 120, 1, 0)
TogLbl.Position = UDim2.new(0, 12, 0, 0)

-- Status pill
local Pill = Instance.new("Frame")
Pill.Size = UDim2.new(0, 48, 0, 20)
Pill.Position = UDim2.new(0, 136, 0.5, -10)
Pill.BackgroundColor3 = RED
Pill.BorderSizePixel = 0
corner(Pill, 99)
Pill.Parent = TogRow

local PillLbl = lbl(Pill, "OFF", 11, Color3.fromRGB(10,10,15), Enum.TextXAlignment.Center)

local TogB = btn(TogRow, "START", UDim2.new(0, 90, 0, 30), ACCDIM, Color3.new(1,1,1))
TogB.Position = UDim2.new(1, -102, 0.5, -15)
TogB.ZIndex = 3

local function setActive(val)
    active = val
    if val then
        tw(TogB, {BackgroundColor3 = RED})
        TogB.Text = "STOP"
        tw(Pill, {BackgroundColor3 = GREEN})
        PillLbl.Text = "ON"
    else
        tw(TogB, {BackgroundColor3 = ACCDIM})
        TogB.Text = "START"
        tw(Pill, {BackgroundColor3 = RED})
        PillLbl.Text = "OFF"
    end
end

TogB.MouseButton1Click:Connect(function() setActive(not active) end)

-- Pill pulse
RS.Heartbeat:Connect(function()
    Pill.BackgroundTransparency = active and (0.2 + 0.2 * math.sin(tick() * 5)) or 0
end)

-- Opacity slider row
local OpRow = Instance.new("Frame")
OpRow.Size = UDim2.new(1, -20, 0, 40)
OpRow.Position = UDim2.new(0, 10, 0, 112)
OpRow.BackgroundColor3 = PANEL
OpRow.BorderSizePixel = 0
corner(OpRow, 10)
stroke(OpRow, ACCDIM)
OpRow.Parent = Win

local OpLbl = lbl(OpRow, "Opacity", 12, DIMC)
OpLbl.Size = UDim2.new(0, 62, 1, 0)
OpLbl.Position = UDim2.new(0, 12, 0, 0)

local OpVal = lbl(OpRow, "95%", 12, ACCENT, Enum.TextXAlignment.Right)
OpVal.Size = UDim2.new(0, 40, 1, 0)
OpVal.Position = UDim2.new(1, -50, 0, 0)

local STrack = Instance.new("Frame")
STrack.Size = UDim2.new(1, -130, 0, 6)
STrack.Position = UDim2.new(0, 78, 0.5, -3)
STrack.BackgroundColor3 = KEYBG
STrack.BorderSizePixel = 0
corner(STrack, 99)
STrack.Parent = OpRow

local SFill = Instance.new("Frame")
SFill.Size = UDim2.new(0.95, 0, 1, 0)
SFill.BackgroundColor3 = ACCENT
SFill.BorderSizePixel = 0
corner(SFill, 99)
SFill.Parent = STrack

local SKnob = Instance.new("Frame")
SKnob.Size = UDim2.new(0, 15, 0, 15)
SKnob.Position = UDim2.new(0.95, -7, 0.5, -7)
SKnob.BackgroundColor3 = Color3.new(1, 1, 1)
SKnob.BorderSizePixel = 0
SKnob.ZIndex = 4
corner(SKnob, 99)
SKnob.Parent = STrack

local sliding = false
STrack.InputBegan:Connect(function(i)
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
    local r = math.clamp((i.Position.X - STrack.AbsolutePosition.X) / STrack.AbsoluteSize.X, 0.05, 1)
    SFill.Size = UDim2.new(r, 0, 1, 0)
    SKnob.Position = UDim2.new(r, -7, 0.5, -7)
    OpVal.Text = math.floor(r * 100) .. "%"
    Win.BackgroundTransparency = 1 - r
end)

-- Macro list label
local ListLbl = lbl(Win, "MACRO KEYS", 10, DIMC)
ListLbl.Size = UDim2.new(1, -20, 0, 18)
ListLbl.Position = UDim2.new(0, 14, 0, 160)

-- Scroll frame for macro rows
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -20, 0, 200)
Scroll.Position = UDim2.new(0, 10, 0, 180)
Scroll.BackgroundColor3 = PANEL
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = ACCENT
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.ScrollingDirection = Enum.ScrollingDirection.Y
corner(Scroll, 10)
stroke(Scroll, ACCDIM)
Scroll.Parent = Win

local ULL = Instance.new("UIListLayout")
ULL.SortOrder = Enum.SortOrder.LayoutOrder
ULL.Padding = UDim.new(0, 5)
ULL.Parent = Scroll

local ULP = Instance.new("UIPadding")
ULP.PaddingLeft = UDim.new(0, 6)
ULP.PaddingRight = UDim.new(0, 6)
ULP.PaddingTop = UDim.new(0, 6)
ULP.Parent = Scroll

ULL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Scroll.CanvasSize = UDim2.new(0, 0, 0, ULL.AbsoluteContentSize.Y + 12)
end)

-- Add macro row
local function addRow(preset)
    rowCount = rowCount + 1
    local m = preset or {key = "", guiPath = "", enabled = true}
    table.insert(macros, m)
    local idx = #macros

    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 48)
    Row.BackgroundColor3 = KEYBG
    Row.BorderSizePixel = 0
    Row.LayoutOrder = rowCount
    corner(Row, 7)
    stroke(Row, ACCDIM)
    Row.Parent = Scroll

    Row.BackgroundTransparency = 1
    task.spawn(function()
        task.wait()
        tw(Row, {BackgroundTransparency = 0}, 0.18)
    end)

    -- Index label
    local idxLbl = lbl(Row, tostring(idx), 11, DIMC, Enum.TextXAlignment.Center)
    idxLbl.Size = UDim2.new(0, 20, 1, 0)
    idxLbl.Position = UDim2.new(0, 4, 0, 0)

    -- Key input
    local keyBox = tbox(Row, "Key e.g. E", UDim2.new(0, 62, 0, 28), UDim2.new(0, 26, 0.5, -14))
    keyBox.Text = m.key
    keyBox.FocusLost:Connect(function() m.key = keyBox.Text end)

    -- GUI path input
    local pathBox = tbox(Row, "Gui.Frame.Btn", UDim2.new(0, 118, 0, 28), UDim2.new(0, 94, 0.5, -14))
    pathBox.TextColor3 = TEXTC
    pathBox.Text = m.guiPath
    pathBox.FocusLost:Connect(function() m.guiPath = pathBox.Text end)

    -- Enable toggle
    local enB = btn(Row, "ON", UDim2.new(0, 38, 0, 28), GREEN, Color3.fromRGB(10,10,15))
    enB.Position = UDim2.new(0, 218, 0.5, -14)
    enB.TextSize = 11
    enB.ZIndex = 3
    enB.MouseButton1Click:Connect(function()
        m.enabled = not m.enabled
        tw(enB, {BackgroundColor3 = m.enabled and GREEN or RED})
        enB.Text = m.enabled and "ON" or "OFF"
    end)

    -- Test button
    local testB = btn(Row, ">", UDim2.new(0, 26, 0, 28), ACCDIM, Color3.new(1,1,1))
    testB.Position = UDim2.new(0, 262, 0.5, -14)
    testB.TextSize = 13
    testB.ZIndex = 3
    testB.MouseButton1Click:Connect(function()
        if m.guiPath ~= "" then pcall(fireGui, m.guiPath) end
        tw(testB, {BackgroundColor3 = GREEN}, 0.1)
        task.delay(0.3, function() tw(testB, {BackgroundColor3 = ACCDIM}) end)
    end)

    -- Delete button
    local delB = btn(Row, "X", UDim2.new(0, 26, 0, 28), Color3.fromRGB(65, 20, 20), RED)
    delB.Position = UDim2.new(1, -32, 0.5, -14)
    delB.TextSize = 12
    delB.ZIndex = 3
    delB.MouseButton1Click:Connect(function()
        for i, v in ipairs(macros) do
            if v == m then table.remove(macros, i) break end
        end
        tw(Row, {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0)}, 0.16)
        task.delay(0.18, function() Row:Destroy() end)
    end)
end

-- Add buttons row
local AddRow = Instance.new("Frame")
AddRow.Size = UDim2.new(1, -20, 0, 40)
AddRow.Position = UDim2.new(0, 10, 0, 388)
AddRow.BackgroundColor3 = PANEL
AddRow.BorderSizePixel = 0
corner(AddRow, 10)
stroke(AddRow, ACCDIM)
AddRow.Parent = Win

local addKeyB = btn(AddRow, "+ Key Macro", UDim2.new(0.5, -8, 0, 28), ACCENT, Color3.fromRGB(10,10,18))
addKeyB.Position = UDim2.new(0, 8, 0.5, -14)
addKeyB.MouseButton1Click:Connect(function()
    addRow({key = "", guiPath = "", enabled = true})
end)

local addGuiB = btn(AddRow, "+ GUI Macro", UDim2.new(0.5, -8, 0, 28), ACCDIM, Color3.new(1,1,1))
addGuiB.Position = UDim2.new(0.5, 0, 0.5, -14)
addGuiB.MouseButton1Click:Connect(function()
    addRow({key = "", guiPath = "ScreenGui.Frame.Button", enabled = true})
end)

-- Interval row
local IntRow = Instance.new("Frame")
IntRow.Size = UDim2.new(1, -20, 0, 36)
IntRow.Position = UDim2.new(0, 10, 0, 436)
IntRow.BackgroundColor3 = PANEL
IntRow.BorderSizePixel = 0
corner(IntRow, 10)
stroke(IntRow, ACCDIM)
IntRow.Parent = Win

local intLbl = lbl(IntRow, "Interval ms:", 12, DIMC)
intLbl.Size = UDim2.new(0, 90, 1, 0)
intLbl.Position = UDim2.new(0, 12, 0, 0)

local intBox = tbox(IntRow, "80", UDim2.new(0, 65, 0, 24), UDim2.new(0, 106, 0.5, -12))
intBox.Text = "80"
intBox.FocusLost:Connect(function()
    local n = tonumber(intBox.Text)
    if n and n >= 10 then
        INTERVAL = n / 1000
    else
        intBox.Text = tostring(math.floor(INTERVAL * 1000))
    end
end)

local intNote = lbl(IntRow, "lower = faster", 10, DIMC)
intNote.Size = UDim2.new(0, 110, 1, 0)
intNote.Position = UDim2.new(0, 178, 0, 0)

-- Macro runner
local timer = 0
RS.Heartbeat:Connect(function(dt)
    if not active then return end
    timer = timer + dt
    if timer < INTERVAL then return end
    timer = 0
    for _, m in ipairs(macros) do
        if m.enabled then
            if m.guiPath ~= "" then pcall(fireGui, m.guiPath) end
        end
    end
end)

-- Keyboard toggle (works on PC, may not fire on mobile)
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.F6 then
        setActive(not active)
    elseif inp.KeyCode == Enum.KeyCode.F7 then
        Win.Visible = not Win.Visible
    end
end)

-- Open animation
Win.Size = UDim2.new(0, 400, 0, 0)
Win.BackgroundTransparency = 1
task.spawn(function()
    task.wait(0.05)
    tw(Win, {Size = UDim2.new(0, 400, 0, 500), BackgroundTransparency = 0}, 0.28)
end)

print("MacroUI loaded - tap START to begin")
