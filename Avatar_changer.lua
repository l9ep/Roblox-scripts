-- AVATAR CHANGER
-- Glass Dark/White UI — by XYTHC

local X_Player    = game:GetService("Players").LocalPlayer
local X_UIS       = game:GetService("UserInputService")
local X_Players   = game:GetService("Players")
local X_Http      = game:GetService("HttpService")
local X_Tween     = game:GetService("TweenService")
local X_Market    = game:GetService("MarketplaceService")
local X_Run       = game:GetService("RunService")

-- ══════════════════════════════════════════
-- STATE
-- ══════════════════════════════════════════
local X_OriginalItems  = {}
local X_CurrentItems   = {}
local X_History        = {}
local X_ItemHistory    = {}
local X_Favorites      = {}
local X_SavedOutfits   = {}
local X_KorbloxActive  = false
local X_HeadlessActive = false

-- ══════════════════════════════════════════
-- PERSISTENCE
-- ══════════════════════════════════════════
local FILE = "AvatarChanger_Data.json"

local function SaveData()
    pcall(function()
        if not writefile then return end
        writefile(FILE, X_Http:JSONEncode({
            H  = X_History,
            IH = X_ItemHistory,
            F  = X_Favorites,
            SO = X_SavedOutfits,
        }))
    end)
end

local function LoadData()
    pcall(function()
        if not isfile or not isfile(FILE) then return end
        local ok, r = pcall(function() return X_Http:JSONDecode(readfile(FILE)) end)
        if not ok or not r then return end
        X_History      = type(r.H)  == "table" and r.H  or {}
        X_ItemHistory  = type(r.IH) == "table" and r.IH or {}
        X_Favorites    = type(r.F)  == "table" and r.F  or {}
        X_SavedOutfits = type(r.SO) == "table" and r.SO or {}
    end)
end
LoadData()

-- ══════════════════════════════════════════
-- TWEEN SHORTCUTS
-- ══════════════════════════════════════════
local function tw(o, p, t, s, d)
    X_Tween:Create(o, TweenInfo.new(
        t or 0.22,
        s or Enum.EasingStyle.Quart,
        d or Enum.EasingDirection.Out
    ), p):Play()
end
local function twBack(o, p, t)
    tw(o, p, t or 0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

local function getChar() return X_Player.Character end

-- ══════════════════════════════════════════
-- NOTIFY
-- ══════════════════════════════════════════
local function Notify(msg)
    local nParent
    if gethui then nParent = gethui()
    elseif syn and syn.protect_gui then nParent = game:GetService("CoreGui")
    elseif protect_gui then nParent = game:GetService("CoreGui")
    else nParent = X_Player.PlayerGui end
    local sg = nParent:FindFirstChild("XNotify") or Instance.new("ScreenGui", nParent)
    sg.Name = "XNotify"
    local f = Instance.new("Frame", sg)
    f.Size     = UDim2.new(0, 210, 0, 38)
    f.Position = UDim2.new(1, 12, 0.87, 0)
    f.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    f.BackgroundTransparency = 0.08
    f.BorderSizePixel = 0; f.ZIndex = 60
    local fc = Instance.new("UICorner", f); fc.CornerRadius = UDim.new(0, 10)
    local fs = Instance.new("UIStroke", f)
    fs.Color = Color3.fromRGB(255, 255, 255); fs.Thickness = 1; fs.Transparency = 0.76
    -- accent bar
    local bar = Instance.new("Frame", f)
    bar.Size = UDim2.new(0, 3, 0, 22); bar.Position = UDim2.new(0, 9, 0.5, -11)
    bar.BackgroundColor3 = Color3.new(1, 1, 1); bar.BorderSizePixel = 0; bar.ZIndex = 61
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1, -22, 1, 0); lbl.Position = UDim2.new(0, 18, 0, 0)
    lbl.Text = msg; lbl.TextColor3 = Color3.fromRGB(230, 230, 235)
    lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 62
    f:TweenPosition(UDim2.new(1, -222, 0.87, 0), "Out", "Back", 0.36, true)
    task.delay(2.8, function()
        f:TweenPosition(UDim2.new(1, 12, 0.87, 0), "In", "Quad", 0.26, true,
            function() f:Destroy() end)
    end)
end

-- ══════════════════════════════════════════
-- POV FIX
-- ══════════════════════════════════════════
local povConn = nil
local function fixPOV()
    if povConn then povConn:Disconnect(); povConn = nil end
    povConn = X_Run.RenderStepped:Connect(function()
        local char = getChar(); if not char then return end
        local cam  = workspace.CurrentCamera; if not cam then return end
        local head = char:FindFirstChild("Head")
        local fp = head and (cam.CFrame.Position - head.Position).Magnitude < 1.5
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") then
                local n = obj.Name:lower()
                if n:find("viewmodel") or n == "leftarm_vm" or n == "rightarm_vm" then
                    obj.LocalTransparencyModifier = 1
                elseif fp then
                    obj.LocalTransparencyModifier = 0
                end
            end
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, obj in ipairs(hrp:GetDescendants()) do
                if obj:IsA("BasePart") then
                    local n = obj.Name:lower()
                    if n:find("arm") or n:find("hand") then
                        obj.LocalTransparencyModifier = 1
                    end
                end
            end
        end
    end)
end

-- ══════════════════════════════════════════
-- WELD
-- ══════════════════════════════════════════
local function X_Weld(acc)
    local char = getChar()
    local h = acc:FindFirstChild("Handle")
    if not char or not h then return end
    local att = h:FindFirstChildOfClass("Attachment")
    local tar = att and char:FindFirstChild(att.Name, true)
    acc.Parent = char
    if tar then
        local w = Instance.new("Weld", h)
        w.Part0 = h; w.Part1 = tar.Parent
        w.C0 = att.CFrame; w.C1 = tar.CFrame
    else
        local hd = char:FindFirstChild("Head")
        if hd then
            local w = Instance.new("Weld", h)
            w.Part0 = h; w.Part1 = hd
        end
    end
end

-- ══════════════════════════════════════════
-- KORBLOX
-- ══════════════════════════════════════════
local function ApplyKorblox(state)
    local char = getChar(); if not char then return end
    for _, v in ipairs(char:GetChildren()) do
        if v.Name == "VisualKorblox" then v:Destroy() end
    end
    local LP = {"RightUpperLeg","RightLowerLeg","RightFoot","Right Leg"}
    if state then
        local fl = Instance.new("Part", char)
        fl.Name = "VisualKorblox"; fl.Size = Vector3.new(1,2,1); fl.CanCollide = false
        local m = Instance.new("SpecialMesh", fl)
        m.MeshId = "rbxassetid://902942096"; m.TextureId = "rbxassetid://902843398"
        m.Scale = Vector3.new(1.2, 1.2, 1.2)
        local leg = char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg")
        if leg then
            local w = Instance.new("Weld", fl)
            w.Part0 = leg; w.Part1 = fl
            w.C0 = (leg.Name == "Right Leg") and CFrame.new(0,0.6,-0.1) or CFrame.new(0,0.15,0)
        end
        for _, p in ipairs(LP) do
            if char:FindFirstChild(p) then char[p].Transparency = 1 end
        end
    else
        for _, p in ipairs(LP) do
            if char:FindFirstChild(p) then char[p].Transparency = 0 end
        end
    end
end

-- ══════════════════════════════════════════
-- CLOTHING TEMPLATE
-- ══════════════════════════════════════════
local function GetTemplate(id)
    local ok, a = pcall(function() return game:GetObjects("rbxassetid://"..id)[1] end)
    if ok and a then
        local tid = ""
        if a:IsA("Shirt")        then tid = a.ShirtTemplate
        elseif a:IsA("Pants")    then tid = a.PantsTemplate
        elseif a:IsA("ShirtGraphic") then tid = a.Graphic end
        a:Destroy()
        return tid ~= "" and tid or "rbxassetid://"..id
    end
    return "rbxassetid://"..id
end

-- ══════════════════════════════════════════
-- INJECT BODY / FACE
-- ══════════════════════════════════════════
local function InjectCustomPart(id)
    local char = getChar(); if not char then return end
    local cid = tostring(id):match("%d+"); if not cid then return end
    local ok, info = pcall(function() return X_Market:GetProductInfo(tonumber(cid)) end)
    if ok and info then
        if info.AssetTypeId == 1 or info.AssetTypeId == 13 then
            local hd = char:FindFirstChild("Head")
            if hd then
                local face = hd:FindFirstChild("face") or Instance.new("Decal", hd)
                face.Name = "face"; face.Texture = "rbxassetid://"..cid
                Notify("Face applied")
            end
        elseif info.AssetTypeId == 17 or info.AssetTypeId == 24 then
            local hd = char:FindFirstChild("Head")
            if hd then
                local m = hd:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh", hd)
                m.MeshId = "rbxassetid://"..cid; Notify("Head mesh applied")
            end
        elseif info.AssetTypeId >= 27 and info.AssetTypeId <= 31 then
            local ok2, a = pcall(function() return game:GetObjects("rbxassetid://"..cid)[1] end)
            if ok2 and a then a.Parent = char; Notify("Body part applied") end
        end
    end
end

-- ══════════════════════════════════════════
-- WEAR ITEM
-- ══════════════════════════════════════════
local function WearItem(id)
    local char = getChar(); if not char then return false end
    local ok, info = pcall(function() return X_Market:GetProductInfo(tonumber(id)) end)
    if ok and info then
        if info.AssetTypeId == 11 then
            local s = char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt", char)
            s.ShirtTemplate = GetTemplate(id); Notify("Shirt applied"); return true
        elseif info.AssetTypeId == 12 then
            local p = char:FindFirstChildOfClass("Pants") or Instance.new("Pants", char)
            p.PantsTemplate = GetTemplate(id); Notify("Pants applied"); return true
        end
    end
    local ok2, a = pcall(function() return game:GetObjects("rbxassetid://"..id)[1] end)
    if ok2 and a then
        if a:IsA("Accessory") then X_Weld(a) else a.Parent = char end
        Notify("Item added"); return true
    end
    return false
end

-- ══════════════════════════════════════════
-- FINAL APPLY
-- ══════════════════════════════════════════
local function FinalApply(items, isReset)
    local char = getChar(); if not char then return end
    local head = char:FindFirstChild("Head")
    local isR15, hasR6Mesh = false, false

    for _, item in ipairs(items) do
        if type(item) ~= "table" then
            local n = item.Name or ""
            if n:find("Upper") or n:find("Lower") or n:find("Hand") or n:find("Foot") then
                isR15 = true
            end
            if item:IsA("SpecialMesh") and (item.MeshType == Enum.MeshType.Head or item.MeshId ~= "") then
                hasR6Mesh = true
            end
        end
    end

    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Clothing") or v:IsA("BodyColors") or v:IsA("CharacterMesh") then
            v:Destroy()
        elseif v:IsA("BasePart") and v.Name:find("Leg") then
            v.Transparency = 0
        end
    end

    if head then
        head.Transparency = 0; head.Size = Vector3.new(2, 1, 1)
        for _, v in ipairs(head:GetChildren()) do
            if v:IsA("Decal") or v:IsA("SpecialMesh") then v:Destroy() end
        end
    end

    for _, item in ipairs(items) do
        if type(item) ~= "userdata" then continue end
        if item:IsA("Accessory") then X_Weld(item:Clone())
        elseif item:IsA("Clothing") or item:IsA("BodyColors") or item:IsA("CharacterMesh") then
            item:Clone().Parent = char
        elseif item:IsA("SpecialMesh") and head then item:Clone().Parent = head
        elseif item:IsA("Decal") and item.Name == "face" and head then item:Clone().Parent = head
        end
    end

    if head then
        local hide = X_HeadlessActive or (isR15 and not hasR6Mesh and not isReset)
        head.Transparency = hide and 1 or 0
        local face = head:FindFirstChild("face")
        if face then face.Transparency = hide and 1 or 0 end
        if isReset and not head:FindFirstChildOfClass("SpecialMesh") then
            local m = Instance.new("SpecialMesh", head)
            m.MeshType = Enum.MeshType.Head; m.Scale = Vector3.new(1.25, 1.25, 1.25)
        end
    end

    ApplyKorblox(X_KorbloxActive or (isR15 and not isReset))
    X_CurrentItems = items
    fixPOV()
    Notify(isReset and "Avatar reset" or "Avatar changed!")
end

-- ══════════════════════════════════════════
-- SERIALIZE / DESERIALIZE
-- ══════════════════════════════════════════
local function Serialize(items)
    local t = {}
    for _, item in ipairs(items) do
        if type(item) ~= "userdata" then continue end
        local r = {class = item.ClassName, name = item.Name}
        if item:IsA("Shirt")        then r.template = item.ShirtTemplate end
        if item:IsA("Pants")        then r.template = item.PantsTemplate end
        if item:IsA("ShirtGraphic") then r.template = item.Graphic end
        if item:IsA("BodyColors")   then
            r.bc = {
                item.HeadColor3.R,     item.HeadColor3.G,     item.HeadColor3.B,
                item.TorsoColor3.R,    item.TorsoColor3.G,    item.TorsoColor3.B,
                item.LeftArmColor3.R,  item.LeftArmColor3.G,  item.LeftArmColor3.B,
                item.RightArmColor3.R, item.RightArmColor3.G, item.RightArmColor3.B,
                item.LeftLegColor3.R,  item.LeftLegColor3.G,  item.LeftLegColor3.B,
                item.RightLegColor3.R, item.RightLegColor3.G, item.RightLegColor3.B,
            }
        end
        if item:IsA("Accessory") then
            local h = item:FindFirstChild("Handle")
            if h then
                local m = h:FindFirstChildOfClass("SpecialMesh")
                r.meshId    = m and m.MeshId    or ""
                r.textureId = m and m.TextureId or ""
                r.meshScale = m and {m.Scale.X, m.Scale.Y, m.Scale.Z} or {1,1,1}
            end
        end
        if item:IsA("SpecialMesh") then
            r.meshId = item.MeshId; r.textureId = item.TextureId
            r.scale  = {item.Scale.X, item.Scale.Y, item.Scale.Z}
        end
        if item:IsA("Decal") then r.texture = item.Texture end
        table.insert(t, r)
    end
    return t
end

local function Deserialize(records)
    local char = getChar(); if not char then return end
    local head = char:FindFirstChild("Head")
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Clothing") or v:IsA("BodyColors") or v:IsA("CharacterMesh") then
            v:Destroy()
        end
    end
    if head then
        for _, v in ipairs(head:GetChildren()) do
            if v:IsA("Decal") or v:IsA("SpecialMesh") then v:Destroy() end
        end
    end
    for _, rec in ipairs(records) do
        if rec.class == "Shirt" then
            local s = char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt", char)
            s.ShirtTemplate = rec.template or ""
        elseif rec.class == "Pants" then
            local p = char:FindFirstChildOfClass("Pants") or Instance.new("Pants", char)
            p.PantsTemplate = rec.template or ""
        elseif rec.class == "ShirtGraphic" then
            local sg = char:FindFirstChildOfClass("ShirtGraphic") or Instance.new("ShirtGraphic", char)
            sg.Graphic = rec.template or ""
        elseif rec.class == "BodyColors" and rec.bc then
            local bc = char:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors", char)
            local b = rec.bc
            if #b >= 18 then
                bc.HeadColor3     = Color3.new(b[1],b[2],b[3])
                bc.TorsoColor3    = Color3.new(b[4],b[5],b[6])
                bc.LeftArmColor3  = Color3.new(b[7],b[8],b[9])
                bc.RightArmColor3 = Color3.new(b[10],b[11],b[12])
                bc.LeftLegColor3  = Color3.new(b[13],b[14],b[15])
                bc.RightLegColor3 = Color3.new(b[16],b[17],b[18])
            end
        elseif rec.class == "Accessory" and rec.meshId and rec.meshId ~= "" then
            local acc = Instance.new("Accessory"); acc.Name = rec.name or "Accessory"
            local handle = Instance.new("Part", acc)
            handle.Name = "Handle"; handle.CanCollide = false; handle.Size = Vector3.new(1,1,1)
            local mesh = Instance.new("SpecialMesh", handle)
            mesh.MeshId = rec.meshId; mesh.TextureId = rec.textureId or ""
            if rec.meshScale then
                mesh.Scale = Vector3.new(rec.meshScale[1], rec.meshScale[2], rec.meshScale[3])
            end
            X_Weld(acc)
        elseif rec.class == "SpecialMesh" and head then
            local m = Instance.new("SpecialMesh", head)
            m.MeshId = rec.meshId or ""; m.TextureId = rec.textureId or ""
            if rec.scale then m.Scale = Vector3.new(rec.scale[1], rec.scale[2], rec.scale[3]) end
        elseif rec.class == "Decal" and head then
            local d = Instance.new("Decal", head)
            d.Name = "face"; d.Texture = rec.texture or ""
        end
    end
    fixPOV(); Notify("Outfit loaded!")
end

-- ══════════════════════════════════════════
-- CAPTURE ORIGINAL + RESPAWN
-- ══════════════════════════════════════════
local char0 = X_Player.Character or X_Player.CharacterAdded:Wait()
for _, v in ipairs(char0:GetChildren()) do
    if not v:IsA("Humanoid") and not v:IsA("Script") and not v:IsA("LocalScript") then
        table.insert(X_OriginalItems, v:Clone())
    end
end
if char0:FindFirstChild("Head") then
    for _, v in ipairs(char0.Head:GetChildren()) do
        table.insert(X_OriginalItems, v:Clone())
    end
end
X_Player.CharacterAdded:Connect(function()
    task.wait(0.6)
    if #X_CurrentItems > 0 then FinalApply(X_CurrentItems, false) end
    fixPOV()
end)
fixPOV()

-- ══════════════════════════════════════════════════════════
--
--   G L A S S   U I   —  D A R K  +  W H I T E
--
-- ══════════════════════════════════════════════════════════

-- Safe GUI parent — correctly handles all executor environments
local SG = Instance.new("ScreenGui")
SG.Name = "AvatarChanger"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = 200

-- Remove any existing copy first
local existing = X_Player.PlayerGui:FindFirstChild("AvatarChanger")
if existing then existing:Destroy() end

if gethui then
    -- Synapse X / most modern executors
    SG.Parent = gethui()
elseif syn and syn.protect_gui then
    syn.protect_gui(SG)
    SG.Parent = game:GetService("CoreGui")
elseif protect_gui then
    protect_gui(SG)
    SG.Parent = game:GetService("CoreGui")
else
    -- Fallback: plain PlayerGui (works on most executors)
    SG.Parent = X_Player.PlayerGui
end

-- ── COLOUR PALETTE ───────────────────────
local C = {
    win     = Color3.fromRGB(10,  10,  16),   -- window base
    panel   = Color3.fromRGB(18,  18,  28),   -- panel/button base
    hdr     = Color3.fromRGB(14,  14,  22),   -- header
    input   = Color3.fromRGB(16,  16,  24),   -- input field
    hover   = Color3.fromRGB(28,  28,  42),   -- hover state
    press   = Color3.fromRGB(38,  38,  56),   -- press state
    stroke  = Color3.fromRGB(255, 255, 255),  -- white stroke
    strokeD = Color3.fromRGB(40,  40,  60),   -- dark stroke
    textW   = Color3.fromRGB(240, 240, 248),  -- primary white text
    textG   = Color3.fromRGB(140, 140, 160),  -- muted grey text
    textD   = Color3.fromRGB(75,  75,  95),   -- dim text
    ok      = Color3.fromRGB(100, 230, 160),
    red     = Color3.fromRGB(220,  70,  70),
    yellow  = Color3.fromRGB(240, 200,  80),
}

-- ── HELPERS ──────────────────────────────
local function mkC(p, r)
    local c = Instance.new("UICorner", p); c.CornerRadius = UDim.new(0, r or 8); return c
end
local function mkS(p, col, thick, trans)
    local s = Instance.new("UIStroke", p)
    s.Color = col or C.stroke; s.Thickness = thick or 1
    s.Transparency = trans or 0.78; return s
end
local function mkPad(p, l, r2, top, b)
    local pad = Instance.new("UIPadding", p)
    pad.PaddingLeft   = UDim.new(0, l   or 0)
    pad.PaddingRight  = UDim.new(0, r2  or 0)
    pad.PaddingTop    = UDim.new(0, top or 0)
    pad.PaddingBottom = UDim.new(0, b   or 0)
end
local function mkList(p, dir, gap)
    local l = Instance.new("UIListLayout", p)
    l.FillDirection  = dir or Enum.FillDirection.Vertical
    l.Padding        = UDim.new(0, gap or 0)
    l.SortOrder      = Enum.SortOrder.LayoutOrder; return l
end
local function autoCanvas(sf)
    local l = sf:FindFirstChildOfClass("UIListLayout")
    if l then
        l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            sf.CanvasSize = UDim2.new(0, 0, 0, l.AbsoluteContentSize.Y + 20)
        end)
    end
end
local function drag(handle, target)
    local d, s, p = false
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            d = true; s = i.Position; p = target.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then d = false end
            end)
        end
    end)
    X_UIS.InputChanged:Connect(function(i)
        if d and i.UserInputType == Enum.UserInputType.MouseMovement then
            local dt = i.Position - s
            target.Position = UDim2.new(p.X.Scale, p.X.Offset + dt.X, p.Y.Scale, p.Y.Offset + dt.Y)
        end
    end)
end

-- ── FLOATING ICON ────────────────────────
local Icon = Instance.new("TextButton", SG)
Icon.Size = UDim2.new(0, 42, 0, 42)
Icon.Position = UDim2.new(0, 12, 0.5, -21)
Icon.BackgroundColor3 = C.panel
Icon.Text = ""; Icon.AutoButtonColor = false; Icon.ZIndex = 20
mkC(Icon, 12); mkS(Icon, C.stroke, 1.5, 0.70)

-- Icon emoji label
local IcoL = Instance.new("TextLabel", Icon)
IcoL.Size = UDim2.new(1,0,1,0); IcoL.BackgroundTransparency = 1
IcoL.Text = "👤"; IcoL.TextSize = 20; IcoL.TextColor3 = C.textW
IcoL.Font = Enum.Font.GothamBold; IcoL.ZIndex = 21
IcoL.TextXAlignment = Enum.TextXAlignment.Center
IcoL.TextYAlignment = Enum.TextYAlignment.Center

-- Status dot
local SDot = Instance.new("Frame", Icon)
SDot.Size = UDim2.new(0, 8, 0, 8)
SDot.Position = UDim2.new(1, -10, 0, 2)
SDot.BackgroundColor3 = C.red; SDot.ZIndex = 22
mkC(SDot, 4)

drag(Icon, Icon)

-- Idle pulse on icon
task.spawn(function()
    while task.wait(1.2) do
        tw(IcoL, {TextTransparency = 0.5}, 0.9, Enum.EasingStyle.Sine)
        task.wait(0.9)
        tw(IcoL, {TextTransparency = 0},   0.9, Enum.EasingStyle.Sine)
    end
end)

-- ── MAIN WINDOW ──────────────────────────
local Win = Instance.new("Frame", SG)
Win.Size = UDim2.new(0, 320, 0, 510)
Win.Position = UDim2.new(0.5, -160, 0.5, -255)
Win.BackgroundColor3 = C.win
Win.Visible = false; Win.ZIndex = 10; Win.Active = true
Win.ClipsDescendants = true
mkC(Win, 14)
mkS(Win, C.stroke, 1.2, 0.72)

-- Subtle top-to-bottom gradient tint
local WG = Instance.new("UIGradient", Win)
WG.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(22, 22, 36)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(10, 10, 16)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(8,  8,  12)),
})
WG.Rotation = 160

-- Top shine line
local Shine = Instance.new("Frame", Win)
Shine.Size = UDim2.new(0.65, 0, 0, 1)
Shine.Position = UDim2.new(0.175, 0, 0, 0)
Shine.BackgroundColor3 = Color3.new(1,1,1)
Shine.BackgroundTransparency = 0.60
Shine.BorderSizePixel = 0; Shine.ZIndex = 20
local SG2 = Instance.new("UIGradient", Shine)
SG2.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.new(0,0,0)),
    ColorSequenceKeypoint.new(0.5, Color3.new(1,1,1)),
    ColorSequenceKeypoint.new(1,   Color3.new(0,0,0)),
})

-- ── HEADER ───────────────────────────────
local Hdr = Instance.new("Frame", Win)
Hdr.Size = UDim2.new(1, 0, 0, 52)
Hdr.BackgroundColor3 = C.hdr
Hdr.ZIndex = 11
mkC(Hdr, 14)
-- fill bottom half of header corners to look flush
local HFix = Instance.new("Frame", Hdr)
HFix.Size = UDim2.new(1, 0, 0.5, 0)
HFix.Position = UDim2.new(0, 0, 0.5, 0)
HFix.BackgroundColor3 = C.hdr; HFix.BorderSizePixel = 0; HFix.ZIndex = 11

-- header bottom border line
local HLine = Instance.new("Frame", Win)
HLine.Size = UDim2.new(1, 0, 0, 1)
HLine.Position = UDim2.new(0, 0, 0, 52)
HLine.BackgroundColor3 = C.stroke
HLine.BackgroundTransparency = 0.80
HLine.BorderSizePixel = 0; HLine.ZIndex = 12

-- Title
local TitleL = Instance.new("TextLabel", Hdr)
TitleL.Size = UDim2.new(0, 200, 0, 26)
TitleL.Position = UDim2.new(0, 14, 0, 8)
TitleL.BackgroundTransparency = 1
TitleL.Text = "AVATAR CHANGER"
TitleL.TextSize = 13; TitleL.TextColor3 = C.textW
TitleL.Font = Enum.Font.GothamBold
TitleL.TextXAlignment = Enum.TextXAlignment.Left; TitleL.ZIndex = 13

local SubL = Instance.new("TextLabel", Hdr)
SubL.Size = UDim2.new(0, 200, 0, 14)
SubL.Position = UDim2.new(0, 14, 0, 32)
SubL.BackgroundTransparency = 1
SubL.Text = "by xythc"
SubL.TextSize = 10; SubL.TextColor3 = C.textD
SubL.Font = Enum.Font.Gotham
SubL.TextXAlignment = Enum.TextXAlignment.Left; SubL.ZIndex = 13

-- Close button
local CBtn = Instance.new("TextButton", Hdr)
CBtn.Size = UDim2.new(0, 24, 0, 24)
CBtn.Position = UDim2.new(1, -30, 0.5, -12)
CBtn.BackgroundColor3 = C.panel
CBtn.Text = "✕"; CBtn.TextSize = 11; CBtn.TextColor3 = C.textG
CBtn.Font = Enum.Font.GothamBold; CBtn.AutoButtonColor = false; CBtn.ZIndex = 14
mkC(CBtn, 6); mkS(CBtn, C.stroke, 1, 0.84)
CBtn.MouseEnter:Connect(function()  tw(CBtn, {BackgroundColor3 = C.red, TextColor3 = C.textW}, 0.12) end)
CBtn.MouseLeave:Connect(function()  tw(CBtn, {BackgroundColor3 = C.panel, TextColor3 = C.textG}, 0.12) end)
CBtn.MouseButton1Click:Connect(function()
    tw(Win, {Size = UDim2.new(0, 320, 0, 0)}, 0.18, Enum.EasingStyle.Quart)
    task.wait(0.2); Win.Visible = false
    Win.Size = UDim2.new(0, 320, 0, 510)
    tw(SDot, {BackgroundColor3 = C.red}, 0.2)
end)

-- Minimize button
local minimized = false
local MinBtn = Instance.new("TextButton", Hdr)
MinBtn.Size = UDim2.new(0, 24, 0, 24)
MinBtn.Position = UDim2.new(1, -58, 0.5, -12)
MinBtn.BackgroundColor3 = C.panel
MinBtn.Text = "–"; MinBtn.TextSize = 13; MinBtn.TextColor3 = C.textG
MinBtn.Font = Enum.Font.GothamBold; MinBtn.AutoButtonColor = false; MinBtn.ZIndex = 14
mkC(MinBtn, 6); mkS(MinBtn, C.stroke, 1, 0.84)
MinBtn.MouseEnter:Connect(function()  tw(MinBtn, {BackgroundColor3 = C.hover, TextColor3 = C.textW}, 0.12) end)
MinBtn.MouseLeave:Connect(function()  tw(MinBtn, {BackgroundColor3 = C.panel, TextColor3 = C.textG}, 0.12) end)
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tw(Win, {Size = UDim2.new(0, 320, 0, 52)}, 0.22, Enum.EasingStyle.Quart)
    else
        twBack(Win, {Size = UDim2.new(0, 320, 0, 510)}, 0.30)
    end
end)

drag(Hdr, Win)

-- ── TAB BAR ──────────────────────────────
local TabBar = Instance.new("Frame", Win)
TabBar.Size = UDim2.new(1, -16, 0, 28)
TabBar.Position = UDim2.new(0, 8, 0, 58)
TabBar.BackgroundTransparency = 1; TabBar.ZIndex = 11
mkList(TabBar, Enum.FillDirection.Horizontal, 6)

local TabSep = Instance.new("Frame", Win)
TabSep.Size = UDim2.new(1, 0, 0, 1)
TabSep.Position = UDim2.new(0, 0, 0, 90)
TabSep.BackgroundColor3 = C.stroke
TabSep.BackgroundTransparency = 0.84
TabSep.BorderSizePixel = 0; TabSep.ZIndex = 11

-- Content
local Content = Instance.new("Frame", Win)
Content.Size = UDim2.new(1, 0, 1, -93)
Content.Position = UDim2.new(0, 0, 0, 92)
Content.BackgroundTransparency = 1; Content.ZIndex = 10
Content.ClipsDescendants = true

-- Bottom status bar
local BotBar = Instance.new("Frame", Win)
BotBar.Size = UDim2.new(1, 0, 0, 20)
BotBar.Position = UDim2.new(0, 0, 1, -20)
BotBar.BackgroundColor3 = C.hdr
BotBar.BorderSizePixel = 0; BotBar.ZIndex = 15
local BotL = Instance.new("Frame", BotBar)
BotL.Size = UDim2.new(1, 0, 0, 1)
BotL.BackgroundColor3 = C.stroke; BotL.BackgroundTransparency = 0.84
BotL.BorderSizePixel = 0; BotL.ZIndex = 15
local BotT = Instance.new("TextLabel", BotBar)
BotT.Size = UDim2.new(1, -12, 1, 0); BotT.Position = UDim2.new(0, 8, 0, 0)
BotT.BackgroundTransparency = 1; BotT.TextSize = 10; BotT.TextColor3 = C.textD
BotT.Font = Enum.Font.Gotham; BotT.TextXAlignment = Enum.TextXAlignment.Left
BotT.ZIndex = 16; BotT.Text = "ready"

local function setStatus(t2)
    BotT.Text = t2; tw(BotT, {TextColor3 = C.textG}, 0.15)
    task.delay(3, function()
        if BotT.Text == t2 then
            tw(BotT, {TextColor3 = C.textD}, 0.3); BotT.Text = "ready"
        end
    end)
end

-- ── SCROLLING PAGE FACTORY ───────────────
local function mkPage()
    local sf = Instance.new("ScrollingFrame", Content)
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency = 1
    sf.ScrollBarThickness = 2
    sf.ScrollBarImageColor3 = C.stroke
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.ZIndex = 11; sf.Visible = false
    local ly = mkList(sf); ly.Padding = UDim.new(0, 7)
    mkPad(sf, 8, 8, 8, 24)
    autoCanvas(sf); return sf
end

-- ── TAB SYSTEM ───────────────────────────
local tabs = {}
local activeTab = ""

local function switchTab(name)
    for n, d in pairs(tabs) do
        local on = (n == name)
        tw(d.btn, {BackgroundColor3 = on and C.hover or C.panel}, 0.15)
        tw(d.btn, {TextColor3 = on and C.textW or C.textG}, 0.15)
        d.page.Visible = on
    end
    activeTab = name; setStatus(name:lower())
end

local function mkTab(label, order)
    local btn = Instance.new("TextButton", TabBar)
    btn.Size = UDim2.new(0, 148, 1, 0)
    btn.BackgroundColor3 = C.panel
    btn.Text = label; btn.TextSize = 11; btn.TextColor3 = C.textG
    btn.Font = Enum.Font.GothamBold; btn.AutoButtonColor = false
    btn.ZIndex = 12; btn.LayoutOrder = order
    mkC(btn, 6); mkS(btn, C.stroke, 1, 0.85)
    return btn
end

-- ── SECTION DIVIDER ──────────────────────
local function mkSection(parent, label, order)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 18); f.BackgroundTransparency = 1
    f.ZIndex = 12; f.LayoutOrder = order
    local line = Instance.new("Frame", f)
    line.Size = UDim2.new(1, 0, 0, 1); line.Position = UDim2.new(0, 0, 0.5, 0)
    line.BackgroundColor3 = C.stroke; line.BackgroundTransparency = 0.82
    line.BorderSizePixel = 0; line.ZIndex = 12
    local lg = Instance.new("UIGradient", line)
    lg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.new(0,0,0)),
        ColorSequenceKeypoint.new(0.25, Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(0.75, Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(1,   Color3.new(0,0,0)),
    })
    local bg = Instance.new("Frame", f)
    bg.AutomaticSize = Enum.AutomaticSize.X; bg.Size = UDim2.new(0, 0, 1, 0)
    bg.BackgroundColor3 = C.win; bg.BorderSizePixel = 0; bg.ZIndex = 13
    mkPad(bg, 0, 6, 0, 0)
    local lbl = Instance.new("TextLabel", bg)
    lbl.BackgroundTransparency = 1; lbl.AutomaticSize = Enum.AutomaticSize.XY
    lbl.Text = "  "..label; lbl.TextSize = 10; lbl.TextColor3 = C.textG
    lbl.Font = Enum.Font.GothamBold; lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 14
end

-- ── BUTTON ───────────────────────────────
local function mkBtn(parent, label, order, col, cb)
    local base = col or C.panel
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = base
    btn.Text = label; btn.TextSize = 12; btn.TextColor3 = C.textW
    btn.Font = Enum.Font.GothamBold; btn.AutoButtonColor = false
    btn.ZIndex = 12; btn.LayoutOrder = order
    mkC(btn, 8); mkS(btn, C.stroke, 1, 0.84)
    mkPad(btn, 12, 8, 0, 0)
    btn.MouseEnter:Connect(function()  tw(btn, {BackgroundColor3 = C.hover}, 0.12) end)
    btn.MouseLeave:Connect(function()  tw(btn, {BackgroundColor3 = base},  0.12) end)
    btn.MouseButton1Click:Connect(function()
        tw(btn, {BackgroundColor3 = C.press}, 0.06)
        task.delay(0.12, function() tw(btn, {BackgroundColor3 = base}, 0.14) end)
        if cb then cb() end
    end)
    return btn
end

-- ── TOGGLE BUTTON ────────────────────────
local function mkToggle(parent, lblOff, lblOn, order, cb)
    local state = false
    local btn = mkBtn(parent, lblOff, order, C.panel, nil)

    -- pill
    local pill = Instance.new("Frame", btn)
    pill.Size = UDim2.new(0, 30, 0, 14); pill.Position = UDim2.new(1, -38, 0.5, -7)
    pill.BackgroundColor3 = C.panel; pill.ZIndex = 14
    mkC(pill, 7); mkS(pill, C.stroke, 1, 0.80)
    local dot = Instance.new("Frame", pill)
    dot.Size = UDim2.new(0, 10, 0, 10); dot.Position = UDim2.new(0, 2, 0.5, -5)
    dot.BackgroundColor3 = C.textD; dot.ZIndex = 15; mkC(dot, 5)

    local function refresh()
        btn.Text = state and lblOn or lblOff
        tw(dot, {
            Position = state and UDim2.new(1,-12,0.5,-5) or UDim2.new(0,2,0.5,-5),
            BackgroundColor3 = state and C.ok or C.textD
        }, 0.18)
        tw(btn, {BackgroundColor3 = state and C.hover or C.panel}, 0.18)
    end

    btn.MouseButton1Click:Connect(function()
        state = not state; refresh()
        if cb then cb(state) end
    end)

    local function set(s) state = s; refresh() end
    return btn, set
end

-- ══════════════════════════════════════════
-- BUILD PAGES
-- ══════════════════════════════════════════

-- ── CHANGER PAGE ─────────────────────────
local btnC = mkTab("  Changer", 1)
local pageC = mkPage()
tabs["Changer"] = {btn = btnC, page = pageC}
btnC.MouseButton1Click:Connect(function() switchTab("Changer") end)

-- ── LOGS PAGE ────────────────────────────
local btnL = mkTab("  Logs", 2)
local pageL = mkPage()
tabs["Logs"] = {btn = btnL, page = pageL}
btnL.MouseButton1Click:Connect(function() switchTab("Logs"); rebuildLogs() end)

-- ── INPUT BOX ────────────────────────────
local InputF = Instance.new("Frame", pageC)
InputF.Size = UDim2.new(1, 0, 0, 40)
InputF.BackgroundColor3 = C.input
InputF.ZIndex = 12; InputF.LayoutOrder = 0
mkC(InputF, 8); mkS(InputF, C.stroke, 1, 0.80)

local InputIcon = Instance.new("TextLabel", InputF)
InputIcon.Size = UDim2.new(0, 16, 1, 0); InputIcon.Position = UDim2.new(0, 10, 0, 0)
InputIcon.BackgroundTransparency = 1; InputIcon.Text = "🔍"; InputIcon.TextSize = 14
InputIcon.TextColor3 = C.textD; InputIcon.Font = Enum.Font.Gotham; InputIcon.ZIndex = 13

local Box = Instance.new("TextBox", InputF)
Box.Size = UDim2.new(1, -32, 1, 0); Box.Position = UDim2.new(0, 28, 0, 0)
Box.BackgroundTransparency = 1; Box.Text = ""
Box.PlaceholderText = "Username, ID or Link..."
Box.TextColor3 = C.textW; Box.PlaceholderColor3 = C.textD
Box.Font = Enum.Font.Gotham; Box.TextSize = 12
Box.ClearTextOnFocus = false; Box.ZIndex = 13

Box.Focused:Connect(function()    tw(InputF, {BackgroundColor3 = C.hover}, 0.15) end)
Box.FocusLost:Connect(function()  tw(InputF, {BackgroundColor3 = C.input}, 0.15) end)

-- ── CHANGER BUTTONS ──────────────────────
mkSection(pageC, "AVATAR", 1)

mkBtn(pageC, "👤  Change Avatar", 2, C.panel, function()
    local inp = Box.Text:match("^%s*(.-)%s*$"); if inp == "" then return end
    local cid = inp:match("%d+")
    if cid and #inp <= 15 then
        if WearItem(cid) then
            if not table.find(X_ItemHistory, cid) then
                table.insert(X_ItemHistory, 1, cid)
                if #X_ItemHistory > 30 then table.remove(X_ItemHistory) end
                SaveData()
            end; return
        end
    end
    local ok, uid = pcall(function() return X_Players:GetUserIdFromNameAsync(inp) end)
    if not ok then uid = tonumber(cid) end
    if not uid then Notify("User not found"); return end
    if not table.find(X_History, inp) then
        table.insert(X_History, 1, inp)
        if #X_History > 30 then table.remove(X_History) end
        SaveData()
    end
    local model = X_Players:CreateHumanoidModelFromUserId(uid)
    local items = {}
    for _, v in ipairs(model:GetChildren()) do
        if not v:IsA("Humanoid") then
            if v:IsA("BasePart") and (v.Name:find("Leg") or v.Name == "Head") then
                local m = v:FindFirstChildOfClass("SpecialMesh")
                if m then table.insert(items, m:Clone()) end
            end
            table.insert(items, v:Clone())
        end
    end
    FinalApply(items, false); model:Destroy(); setStatus("avatar changed")
end)

mkBtn(pageC, "🎭  Wear Item ID", 3, C.panel, function()
    local cid = Box.Text:match("%d+"); if not cid then return end
    if WearItem(cid) then
        if not table.find(X_ItemHistory, cid) then
            table.insert(X_ItemHistory, 1, cid)
            if #X_ItemHistory > 50 then table.remove(X_ItemHistory) end
            SaveData()
        end
    end; setStatus("item worn")
end)

mkBtn(pageC, "💉  Inject Body / Face / Head", 4, C.panel, function()
    local cid = Box.Text:match("%d+"); if not cid then return end
    InjectCustomPart(cid); setStatus("injected")
end)

mkSection(pageC, "TOGGLES", 5)

local _, kbSet = mkToggle(pageC, "🦴  Korblox: Off", "🦴  Korblox: On", 6, function(on)
    X_KorbloxActive = on; ApplyKorblox(on)
    setStatus("korblox "..(on and "on" or "off"))
end)

local _, hlSet = mkToggle(pageC, "💀  Headless: Off", "💀  Headless: On", 7, function(on)
    X_HeadlessActive = on
    local head = getChar() and getChar():FindFirstChild("Head")
    if head then
        head.Transparency = on and 1 or 0
        local face = head:FindFirstChild("face")
        if face then face.Transparency = on and 1 or 0 end
    end
    setStatus("headless "..(on and "on" or "off"))
end)

mkSection(pageC, "OUTFIT", 8)

mkBtn(pageC, "⭐  Add to Favorites", 9, C.panel, function()
    local inp = Box.Text:match("^%s*(.-)%s*$")
    if inp == "" then Notify("Enter a username or ID first"); return end
    if table.find(X_Favorites, inp) then Notify("Already in favorites"); return end
    table.insert(X_Favorites, 1, inp)
    if #X_Favorites > 30 then table.remove(X_Favorites) end
    SaveData(); Notify("Added to favorites!"); setStatus("favorited")
end)

mkBtn(pageC, "💾  Save Current Outfit", 10, C.panel, function()
    if #X_CurrentItems == 0 then Notify("No outfit applied yet"); return end
    local name = Box.Text:match("^%s*(.-)%s*$")
    if name == "" then name = "Outfit " .. (#X_SavedOutfits + 1) end
    X_SavedOutfits[name] = Serialize(X_CurrentItems)
    SaveData(); Notify("Saved: " .. name); setStatus("outfit saved")
end)

mkBtn(pageC, "🔄  Reset Avatar", 11, C.panel, function()
    X_KorbloxActive = false; X_HeadlessActive = false
    kbSet(false); hlSet(false)
    FinalApply(X_OriginalItems, true); setStatus("avatar reset")
end)

-- ══════════════════════════════════════════
-- LOGS PAGE
-- ══════════════════════════════════════════
function rebuildLogs()
    for _, v in ipairs(pageL:GetChildren()) do
        if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then v:Destroy() end
    end

    local order = 0

    local function addSec(title)
        order += 1; mkSection(pageL, title, order)
    end

    local function addEmpty(note)
        order += 1
        local l = Instance.new("TextLabel", pageL)
        l.Size = UDim2.new(1, 0, 0, 24); l.BackgroundTransparency = 1
        l.Text = note; l.TextSize = 11; l.TextColor3 = C.textD
        l.Font = Enum.Font.Gotham; l.TextXAlignment = Enum.TextXAlignment.Center
        l.ZIndex = 12; l.LayoutOrder = order
    end

    local function addRow(label, onApply, onDel)
        order += 1
        local row = Instance.new("Frame", pageL)
        row.Size = UDim2.new(1, 0, 0, 34)
        row.BackgroundColor3 = C.panel
        row.ZIndex = 12; row.LayoutOrder = order
        mkC(row, 8); mkS(row, C.stroke, 1, 0.86)

        local applyBtn = Instance.new("TextButton", row)
        applyBtn.Size = UDim2.new(1, -34, 1, 0)
        applyBtn.BackgroundTransparency = 1
        applyBtn.Text = label; applyBtn.TextSize = 11; applyBtn.TextColor3 = C.textW
        applyBtn.Font = Enum.Font.GothamBold; applyBtn.TextXAlignment = Enum.TextXAlignment.Left
        applyBtn.ZIndex = 13; mkPad(applyBtn, 10, 0, 0, 0)
        applyBtn.MouseEnter:Connect(function()  tw(row, {BackgroundColor3 = C.hover}, 0.12) end)
        applyBtn.MouseLeave:Connect(function()  tw(row, {BackgroundColor3 = C.panel}, 0.12) end)
        applyBtn.MouseButton1Click:Connect(function()
            tw(row, {BackgroundColor3 = C.press}, 0.06)
            task.delay(0.1, function() tw(row, {BackgroundColor3 = C.panel}, 0.12) end)
            if onApply then onApply() end
        end)

        local delBtn = Instance.new("TextButton", row)
        delBtn.Size = UDim2.new(0, 24, 0, 24); delBtn.Position = UDim2.new(1, -30, 0.5, -12)
        delBtn.BackgroundColor3 = C.panel
        delBtn.Text = "✕"; delBtn.TextSize = 10; delBtn.TextColor3 = C.textG
        delBtn.Font = Enum.Font.GothamBold; delBtn.AutoButtonColor = false; delBtn.ZIndex = 13
        mkC(delBtn, 5); mkS(delBtn, C.stroke, 1, 0.88)
        delBtn.MouseEnter:Connect(function()  tw(delBtn, {BackgroundColor3 = C.red, TextColor3 = C.textW}, 0.10) end)
        delBtn.MouseLeave:Connect(function()  tw(delBtn, {BackgroundColor3 = C.panel, TextColor3 = C.textG}, 0.10) end)
        delBtn.MouseButton1Click:Connect(function()
            tw(row, {BackgroundTransparency = 1}, 0.14)
            task.delay(0.16, function() row:Destroy() end)
            if onDel then onDel() end
        end)
    end

    -- Saved Outfits
    addSec("💾  SAVED OUTFITS")
    local hasO = false
    for name, serialized in pairs(X_SavedOutfits) do
        hasO = true; local n = name
        addRow(n,
            function() Deserialize(serialized); setStatus("outfit loaded") end,
            function() X_SavedOutfits[n] = nil; SaveData() end
        )
    end
    if not hasO then addEmpty("No saved outfits") end

    -- Favorites
    addSec("⭐  FAVORITES")
    if #X_Favorites == 0 then addEmpty("No favorites yet")
    else
        for i, fav in ipairs(X_Favorites) do
            local idx, f = i, fav
            addRow(f,
                function() Box.Text = f; switchTab("Changer"); setStatus("loaded favorite") end,
                function() table.remove(X_Favorites, idx); SaveData() end
            )
        end
    end

    -- Avatar History
    addSec("🕓  AVATAR HISTORY")
    if #X_History == 0 then addEmpty("No history yet")
    else
        for i, entry in ipairs(X_History) do
            local idx, e = i, entry
            addRow(e,
                function() Box.Text = e; switchTab("Changer"); setStatus("loaded from history") end,
                function() table.remove(X_History, idx); SaveData(); rebuildLogs() end
            )
        end
    end

    -- Item History
    addSec("🎭  ITEM HISTORY")
    if #X_ItemHistory == 0 then addEmpty("No item history yet")
    else
        for i, id in ipairs(X_ItemHistory) do
            local idx = i
            addRow("ID: " .. id,
                function() Box.Text = id; switchTab("Changer"); setStatus("loaded item id") end,
                function() table.remove(X_ItemHistory, idx); SaveData(); rebuildLogs() end
            )
        end
    end

    -- Clear row
    order += 1
    local crow = Instance.new("Frame", pageL)
    crow.Size = UDim2.new(1, 0, 0, 32); crow.BackgroundTransparency = 1
    crow.ZIndex = 12; crow.LayoutOrder = order
    mkList(crow, Enum.FillDirection.Horizontal, 6)

    local function mkClear(lbl, cb2)
        local b = Instance.new("TextButton", crow)
        b.Size = UDim2.new(0.5, -3, 1, 0)
        b.BackgroundColor3 = C.panel
        b.Text = lbl; b.TextSize = 10; b.TextColor3 = C.textG
        b.Font = Enum.Font.GothamBold; b.AutoButtonColor = false; b.ZIndex = 13
        mkC(b, 7); mkS(b, C.red, 1, 0.60)
        b.MouseEnter:Connect(function()  tw(b, {BackgroundColor3 = C.hover, TextColor3 = C.red}, 0.12) end)
        b.MouseLeave:Connect(function()  tw(b, {BackgroundColor3 = C.panel, TextColor3 = C.textG}, 0.12) end)
        b.MouseButton1Click:Connect(function()
            tw(b, {BackgroundColor3 = C.press}, 0.06)
            task.delay(0.1, function() tw(b, {BackgroundColor3 = C.panel}, 0.12) end)
            if cb2 then cb2() end
        end)
    end
    mkClear("✕  Clear History", function()
        X_History = {}; X_ItemHistory = {}; SaveData(); rebuildLogs()
    end)
    mkClear("✕  Clear Favorites", function()
        X_Favorites = {}; SaveData(); rebuildLogs()
    end)
end

-- ══════════════════════════════════════════
-- OPEN / CLOSE / TOGGLE
-- ══════════════════════════════════════════
local function openWin()
    Win.Size = UDim2.new(0, 320, 0, 0)
    Win.Position = UDim2.new(0.5, -160, 0.5, 0)
    Win.Visible = true
    twBack(Win, {
        Size     = UDim2.new(0, 320, 0, 510),
        Position = UDim2.new(0.5, -160, 0.5, -255)
    }, 0.32)
    tw(SDot, {BackgroundColor3 = C.ok}, 0.22)
    if activeTab == "" then switchTab("Changer") end
end

local function closeWin()
    tw(Win, {
        Size     = UDim2.new(0, 320, 0, 0),
        Position = UDim2.new(0.5, -160, 0.5, 0)
    }, 0.20, Enum.EasingStyle.Quart)
    task.wait(0.22); Win.Visible = false
    Win.Size = UDim2.new(0, 320, 0, 510)
    tw(SDot, {BackgroundColor3 = C.red}, 0.20)
end

Icon.MouseButton1Click:Connect(function()
    if Win.Visible then closeWin() else openWin() end
end)

X_UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        if Win.Visible then closeWin() else openWin() end
    end
end)

-- ── LAUNCH ───────────────────────────────
task.wait(0.5); openWin()
Notify("Avatar Changer loaded!")
