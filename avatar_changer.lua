-- AVATAR CHANGER — GLASSMORPHISM UI
-- v92: Dark glass + white theme, rich animations
-- Logic: POV fix, save/load, history, favorites all intact

local X_Player  = game:GetService("Players").LocalPlayer
local X_UIS     = game:GetService("UserInputService")
local X_Players = game:GetService("Players")
local X_Http    = game:GetService("HttpService")
local X_Tween   = game:GetService("TweenService")
local X_Market  = game:GetService("MarketplaceService")
local X_Run     = game:GetService("RunService")
local CoreGui   = game:GetService("CoreGui")

-- ───────────────────────────────────────────────
-- STATE
-- ───────────────────────────────────────────────
local X_OriginalItems  = {}
local X_CurrentItems   = {}
local X_History        = {}
local X_ItemHistory    = {}
local X_Favorites      = {}
local X_SavedOutfits   = {}
local X_KorbloxActive  = false
local X_HeadlessActive = false

-- ───────────────────────────────────────────────
-- PERSISTENCE
-- ───────────────────────────────────────────────
local FILE = "AvatarChanger_V92.json"

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

-- ───────────────────────────────────────────────
-- TWEEN HELPER
-- ───────────────────────────────────────────────
local function tw(obj, props, t, style, dir)
    X_Tween:Create(obj,
        TweenInfo.new(t or 0.22,
            style or Enum.EasingStyle.Quart,
            dir   or Enum.EasingDirection.Out),
        props):Play()
end

local function twSpring(obj, props, t)
    tw(obj, props, t or 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

local function getChar() return X_Player.Character end
local function getHum()  local c=getChar(); return c and c:FindFirstChildOfClass("Humanoid") end
local function getHRP()  local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart") end

-- ───────────────────────────────────────────────
-- NOTIFICATION  (glass style)
-- ───────────────────────────────────────────────
local function Notify(msg, icon)
    local nG = X_Player.PlayerGui:FindFirstChild("X_Notify_V92")
        or Instance.new("ScreenGui", X_Player.PlayerGui)
    nG.Name = "X_Notify_V92"

    local f = Instance.new("Frame", nG)
    f.Size = UDim2.new(0, 230, 0, 42)
    f.Position = UDim2.new(1, 12, 0.87, 0)
    f.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    f.BackgroundTransparency = 0.12
    f.BorderSizePixel = 0; f.ZIndex = 50
    local fc = Instance.new("UICorner", f); fc.CornerRadius = UDim.new(0, 10)
    local fs = Instance.new("UIStroke", f)
    fs.Color = Color3.fromRGB(255, 255, 255); fs.Thickness = 1
    fs.Transparency = 0.82

    -- left accent bar
    local bar = Instance.new("Frame", f)
    bar.Size = UDim2.new(0, 3, 0, 26); bar.Position = UDim2.new(0, 8, 0.5, -13)
    bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    bar.BackgroundTransparency = 0; bar.BorderSizePixel = 0; bar.ZIndex = 51
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1, -26, 1, 0); lbl.Position = UDim2.new(0, 20, 0, 0)
    lbl.Text = (icon or "") .. (icon and "  " or "") .. msg
    lbl.TextColor3 = Color3.fromRGB(235, 235, 240)
    lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 52

    f:TweenPosition(UDim2.new(1, -242, 0.87, 0), "Out", "Back", 0.38, true)
    task.delay(3, function()
        f:TweenPosition(UDim2.new(1, 12, 0.87, 0), "In", "Quad", 0.28, true,
            function() f:Destroy() end)
    end)
end

-- ───────────────────────────────────────────────
-- POV / FIRST-PERSON FIX
-- ───────────────────────────────────────────────
local povConn = nil
local function fixPOVVisibility()
    if povConn then povConn:Disconnect(); povConn = nil end
    povConn = X_Run.RenderStepped:Connect(function()
        local char = getChar(); if not char then return end
        local cam = workspace.CurrentCamera; if not cam then return end
        local head = char:FindFirstChild("Head")
        local isFirstPerson = head and
            (cam.CFrame.Position - head.Position).Magnitude < 1.5

        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") then
                local n = obj.Name:lower()
                if n:find("viewmodel") or n=="leftarm_vm" or n=="rightarm_vm" then
                    obj.LocalTransparencyModifier = 1
                elseif isFirstPerson then
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

-- ───────────────────────────────────────────────
-- WELD / KORBLOX
-- ───────────────────────────────────────────────
local function X_Weld(acc)
    local char = getChar(); local h = acc:FindFirstChild("Handle")
    if not char or not h then return end
    local att = h:FindFirstChildOfClass("Attachment")
    local tar = att and char:FindFirstChild(att.Name, true)
    acc.Parent = char
    if tar then
        local w = Instance.new("Weld", h)
        w.Part0=h; w.Part1=tar.Parent; w.C0=att.CFrame; w.C1=tar.CFrame
    else
        local hd = char:FindFirstChild("Head")
        if hd then
            local w = Instance.new("Weld", h)
            w.Part0=h; w.Part1=hd; w.C0=CFrame.new(); w.C1=CFrame.new()
        end
    end
end

local function ApplyKorblox(state)
    local char = getChar(); if not char then return end
    for _, v in ipairs(char:GetChildren()) do
        if v.Name=="VisualKorblox" then v:Destroy() end
    end
    local LP = {"RightUpperLeg","RightLowerLeg","RightFoot","Right Leg"}
    if state then
        local fl = Instance.new("Part", char)
        fl.Name="VisualKorblox"; fl.Size=Vector3.new(1,2,1); fl.CanCollide=false
        local m = Instance.new("SpecialMesh", fl)
        m.MeshId="rbxassetid://902942096"; m.TextureId="rbxassetid://902843398"
        m.Scale=Vector3.new(1.2,1.2,1.2)
        local leg = char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg")
        if leg then
            local w = Instance.new("Weld", fl)
            w.Part0=leg; w.Part1=fl
            w.C0 = (leg.Name=="Right Leg") and CFrame.new(0,0.6,-0.1) or CFrame.new(0,0.15,0)
        end
        for _, p in ipairs(LP) do if char:FindFirstChild(p) then char[p].Transparency=1 end end
    else
        for _, p in ipairs(LP) do if char:FindFirstChild(p) then char[p].Transparency=0 end end
    end
end

-- ───────────────────────────────────────────────
-- CLOTHING TEMPLATE
-- ───────────────────────────────────────────────
local function GetActualTemplate(id)
    local ok, asset = pcall(function() return game:GetObjects("rbxassetid://"..id)[1] end)
    if ok and asset then
        local tid=""
        if asset:IsA("Shirt") then tid=asset.ShirtTemplate
        elseif asset:IsA("Pants") then tid=asset.PantsTemplate
        elseif asset:IsA("ShirtGraphic") then tid=asset.Graphic end
        asset:Destroy()
        return tid~="" and tid or "rbxassetid://"..id
    end
    return "rbxassetid://"..id
end

-- ───────────────────────────────────────────────
-- INJECT BODY / FACE
-- ───────────────────────────────────────────────
local function InjectCustomPart(id)
    local char=getChar(); if not char then return end
    local cid=tostring(id):match("%d+"); if not cid then return end
    local ok, info = pcall(function() return X_Market:GetProductInfo(tonumber(cid)) end)
    if ok and info then
        if info.AssetTypeId==1 or info.AssetTypeId==13 then
            local hd=char:FindFirstChild("Head")
            if hd then
                local face=hd:FindFirstChild("face") or Instance.new("Decal",hd)
                face.Name="face"; face.Texture="rbxassetid://"..cid
                Notify("Face applied","✦")
            end
        elseif info.AssetTypeId==17 or info.AssetTypeId==24 then
            local hd=char:FindFirstChild("Head")
            if hd then
                local m=hd:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh",hd)
                m.MeshId="rbxassetid://"..cid; Notify("Head mesh applied","✦")
            end
        elseif info.AssetTypeId>=27 and info.AssetTypeId<=31 then
            local ok2,asset=pcall(function() return game:GetObjects("rbxassetid://"..cid)[1] end)
            if ok2 and asset then asset.Parent=char; Notify("Body part applied","✦") end
        end
    end
end

-- ───────────────────────────────────────────────
-- WEAR SINGLE ITEM
-- ───────────────────────────────────────────────
local function WearItem(id)
    local char=getChar(); if not char then return end
    local ok, info = pcall(function() return X_Market:GetProductInfo(tonumber(id)) end)
    if ok and info then
        if info.AssetTypeId==11 then
            local s=char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt",char)
            s.ShirtTemplate=GetActualTemplate(id); Notify("Shirt applied","✦"); return true
        elseif info.AssetTypeId==12 then
            local p=char:FindFirstChildOfClass("Pants") or Instance.new("Pants",char)
            p.PantsTemplate=GetActualTemplate(id); Notify("Pants applied","✦"); return true
        end
    end
    local ok2,asset=pcall(function() return game:GetObjects("rbxassetid://"..id)[1] end)
    if ok2 and asset then
        if asset:IsA("Accessory") then X_Weld(asset) else asset.Parent=char end
        Notify("Item added","✦"); return true
    end
    return false
end

-- ───────────────────────────────────────────────
-- FINAL APPLY
-- ───────────────────────────────────────────────
local function FinalApply(items, isReset)
    local char=getChar(); if not char then return end
    local head=char:FindFirstChild("Head")
    local isR15,hasR6Mesh=false,false

    for _, item in ipairs(items) do
        if type(item)~="table" then
            local n=item.Name or ""
            if n:find("Upper") or n:find("Lower") or n:find("Hand") or n:find("Foot") then isR15=true end
            if item:IsA("SpecialMesh") and (item.MeshType==Enum.MeshType.Head or item.MeshId~="") then hasR6Mesh=true end
        end
    end

    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Clothing") or v:IsA("BodyColors") or v:IsA("CharacterMesh") then v:Destroy()
        elseif v:IsA("BasePart") and v.Name:find("Leg") then v.Transparency=0 end
    end
    if head then
        head.Transparency=0; head.Size=Vector3.new(2,1,1)
        for _, v in ipairs(head:GetChildren()) do
            if v:IsA("Decal") or v:IsA("SpecialMesh") then v:Destroy() end
        end
    end

    for _, item in ipairs(items) do
        if type(item)~="userdata" then continue end
        if item:IsA("Accessory") then X_Weld(item:Clone())
        elseif item:IsA("Clothing") or item:IsA("BodyColors") or item:IsA("CharacterMesh") then item:Clone().Parent=char
        elseif item:IsA("SpecialMesh") and head then item:Clone().Parent=head
        elseif item:IsA("Decal") and item.Name=="face" and head then item:Clone().Parent=head
        end
    end

    if head then
        local forceHL = isR15 and not hasR6Mesh and not isReset
        local hide = X_HeadlessActive or forceHL
        head.Transparency = hide and 1 or 0
        local face=head:FindFirstChild("face")
        if face then face.Transparency = hide and 1 or 0 end
        if isReset and not head:FindFirstChildOfClass("SpecialMesh") then
            local m=Instance.new("SpecialMesh",head)
            m.MeshType=Enum.MeshType.Head; m.Scale=Vector3.new(1.25,1.25,1.25)
        end
    end

    ApplyKorblox(X_KorbloxActive or (isR15 and not isReset))
    X_CurrentItems=items
    fixPOVVisibility()
    Notify(isReset and "Avatar reset" or "Avatar changed","✦")
end

-- ───────────────────────────────────────────────
-- SERIALIZE / DESERIALIZE
-- ───────────────────────────────────────────────
local function SerializeItems(items)
    local t={}
    for _, item in ipairs(items) do
        if type(item)~="userdata" then continue end
        local r={class=item.ClassName, name=item.Name}
        if item:IsA("Shirt")       then r.template=item.ShirtTemplate end
        if item:IsA("Pants")       then r.template=item.PantsTemplate end
        if item:IsA("ShirtGraphic")then r.template=item.Graphic end
        if item:IsA("BodyColors")  then
            r.bc={item.HeadColor3.R,item.HeadColor3.G,item.HeadColor3.B,
                  item.TorsoColor3.R,item.TorsoColor3.G,item.TorsoColor3.B,
                  item.LeftArmColor3.R,item.LeftArmColor3.G,item.LeftArmColor3.B,
                  item.RightArmColor3.R,item.RightArmColor3.G,item.RightArmColor3.B,
                  item.LeftLegColor3.R,item.LeftLegColor3.G,item.LeftLegColor3.B,
                  item.RightLegColor3.R,item.RightLegColor3.G,item.RightLegColor3.B}
        end
        if item:IsA("Accessory") then
            local h=item:FindFirstChild("Handle")
            if h then
                local m=h:FindFirstChildOfClass("SpecialMesh")
                r.meshId    = m and m.MeshId    or ""
                r.textureId = m and m.TextureId or ""
                r.meshScale = m and {m.Scale.X,m.Scale.Y,m.Scale.Z} or {1,1,1}
            end
        end
        if item:IsA("SpecialMesh") then
            r.meshId=item.MeshId; r.textureId=item.TextureId
            r.scale={item.Scale.X,item.Scale.Y,item.Scale.Z}
        end
        if item:IsA("Decal") then r.texture=item.Texture end
        table.insert(t,r)
    end
    return t
end

local function DeserializeAndApply(records)
    local char=getChar(); if not char then return end
    local head=char:FindFirstChild("Head")
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Clothing") or v:IsA("BodyColors") or v:IsA("CharacterMesh") then v:Destroy() end
    end
    if head then
        for _, v in ipairs(head:GetChildren()) do
            if v:IsA("Decal") or v:IsA("SpecialMesh") then v:Destroy() end
        end
    end
    for _, rec in ipairs(records) do
        if rec.class=="Shirt" then
            local s=char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt",char)
            s.ShirtTemplate=rec.template or ""
        elseif rec.class=="Pants" then
            local p=char:FindFirstChildOfClass("Pants") or Instance.new("Pants",char)
            p.PantsTemplate=rec.template or ""
        elseif rec.class=="ShirtGraphic" then
            local sg=char:FindFirstChildOfClass("ShirtGraphic") or Instance.new("ShirtGraphic",char)
            sg.Graphic=rec.template or ""
        elseif rec.class=="BodyColors" and rec.bc then
            local bc=char:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors",char)
            local b=rec.bc
            if #b>=18 then
                bc.HeadColor3=Color3.new(b[1],b[2],b[3])
                bc.TorsoColor3=Color3.new(b[4],b[5],b[6])
                bc.LeftArmColor3=Color3.new(b[7],b[8],b[9])
                bc.RightArmColor3=Color3.new(b[10],b[11],b[12])
                bc.LeftLegColor3=Color3.new(b[13],b[14],b[15])
                bc.RightLegColor3=Color3.new(b[16],b[17],b[18])
            end
        elseif rec.class=="Accessory" and rec.meshId and rec.meshId~="" then
            local acc=Instance.new("Accessory"); acc.Name=rec.name or "Accessory"
            local handle=Instance.new("Part",acc)
            handle.Name="Handle"; handle.CanCollide=false; handle.Size=Vector3.new(1,1,1)
            local mesh=Instance.new("SpecialMesh",handle)
            mesh.MeshId=rec.meshId; mesh.TextureId=rec.textureId or ""
            if rec.meshScale then mesh.Scale=Vector3.new(rec.meshScale[1],rec.meshScale[2],rec.meshScale[3]) end
            X_Weld(acc)
        elseif rec.class=="SpecialMesh" and head then
            local m=Instance.new("SpecialMesh",head)
            m.MeshId=rec.meshId or ""; m.TextureId=rec.textureId or ""
            if rec.scale then m.Scale=Vector3.new(rec.scale[1],rec.scale[2],rec.scale[3]) end
        elseif rec.class=="Decal" and head then
            local d=Instance.new("Decal",head)
            d.Name="face"; d.Texture=rec.texture or ""
        end
    end
    fixPOVVisibility()
    Notify("Outfit loaded","✦")
end

-- ───────────────────────────────────────────────
-- CAPTURE ORIGINAL + RESPAWN
-- ───────────────────────────────────────────────
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
    if #X_CurrentItems>0 then FinalApply(X_CurrentItems, false) end
    fixPOVVisibility()
end)
fixPOVVisibility()

-- ═══════════════════════════════════════════════════════════════
--
--              GLASSMORPHISM UI  — DARK + WHITE
--
-- ═══════════════════════════════════════════════════════════════

local SG = Instance.new("ScreenGui", X_Player.PlayerGui)
SG.Name = "AvatarChangerUI_V92"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = 200

-- ── THEME ─────────────────────────────────────
-- Dark glass: very dark near-black bases, frosted white overlays,
-- white text, subtle white strokes, no colour accents except pure white
local G = {
    -- Base layers (very dark, near transparent)
    base0   = Color3.fromRGB(6,   6,   9),    -- deepest background
    base1   = Color3.fromRGB(12,  12,  18),   -- window bg
    base2   = Color3.fromRGB(18,  18,  26),   -- panel bg
    base3   = Color3.fromRGB(24,  24,  36),   -- element bg

    -- Glass overlays
    glass0  = Color3.fromRGB(255, 255, 255),  -- pure white glass
    glassT0 = 0.92,   -- near-transparent white surface
    glassT1 = 0.88,   -- slightly more opaque
    glassT2 = 0.80,   -- button hover glass

    -- Strokes
    strokeW = Color3.fromRGB(255, 255, 255),
    strokeD = Color3.fromRGB(60,  60,  80),

    -- Text
    textPri = Color3.fromRGB(240, 240, 248),  -- primary white text
    textSec = Color3.fromRGB(160, 160, 175),  -- secondary muted
    textDim = Color3.fromRGB(90,  90, 110),   -- dimmed

    -- Status
    ok      = Color3.fromRGB(180, 255, 200),
    warn    = Color3.fromRGB(255, 220, 120),
    err     = Color3.fromRGB(255, 130, 130),
}

-- ── PRIMITIVE BUILDERS ────────────────────────
local function mkCorner(p, r)
    local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r or 10); return c
end
local function mkStroke(p, col, t2, tr)
    local s=Instance.new("UIStroke",p)
    s.Color=col or G.strokeW; s.Thickness=t2 or 1
    s.Transparency=tr or 0.78; return s
end
local function mkPad(p, l, r2, top, b)
    local pad=Instance.new("UIPadding",p)
    pad.PaddingLeft=UDim.new(0,l or 0); pad.PaddingRight=UDim.new(0,r2 or 0)
    pad.PaddingTop=UDim.new(0,top or 0); pad.PaddingBottom=UDim.new(0,b or 0)
end
local function mkList(p, dir, gap)
    local l=Instance.new("UIListLayout",p)
    l.FillDirection=dir or Enum.FillDirection.Vertical
    l.Padding=UDim.new(0,gap or 0)
    l.SortOrder=Enum.SortOrder.LayoutOrder; return l
end

-- Glass Frame — the core glassmorphism element
-- White semi-transparent surface with bright white stroke
local function mkGlass(parent, trans, strokeTrans)
    local f=Instance.new("Frame",parent)
    f.BackgroundColor3=G.glass0
    f.BackgroundTransparency=trans or G.glassT0
    f.BorderSizePixel=0
    mkStroke(f, G.strokeW, 1, strokeTrans or 0.78)
    return f
end

-- Drag helper
local function makeDrag(handle, target, onDrag)
    local drag,dS,dP=false
    handle.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            drag=true; dS=i.Position; dP=target.Position
            i.Changed:Connect(function()
                if i.UserInputState==Enum.UserInputState.End then drag=false end
            end)
        end
    end)
    X_UIS.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-dS
            target.Position=UDim2.new(dP.X.Scale,dP.X.Offset+d.X,dP.Y.Scale,dP.Y.Offset+d.Y)
            if onDrag then onDrag() end
        end
    end)
end

-- ── BACKGROUND BLUR SIMULATION ────────────────
-- Roblox doesn't expose blur per-frame, but we layer a very dark
-- semi-transparent base underneath the glass panels for depth
local BgLayer=Instance.new("Frame",SG)
BgLayer.Size=UDim2.new(0,360,0,540)
BgLayer.BackgroundColor3=G.base0
BgLayer.BackgroundTransparency=0.35
BgLayer.ZIndex=8; BgLayer.Visible=false; BgLayer.BorderSizePixel=0
mkCorner(BgLayer,18)
local function syncBg(win)
    BgLayer.Position=UDim2.new(
        win.Position.X.Scale, win.Position.X.Offset-10,
        win.Position.Y.Scale, win.Position.Y.Offset-10)
end

-- ── FLOATING ICON BUTTON ──────────────────────
local Icon=mkGlass(SG, 0.60, 0.55)
Icon.Size=UDim2.new(0,46,0,46)
Icon.Position=UDim2.new(0,14,0.46,0)
Icon.ZIndex=30; mkCorner(Icon,13)
Icon.Active=true

-- Subtle glow ring behind icon
local IconGlow=Instance.new("Frame",SG)
IconGlow.Size=UDim2.new(0,62,0,62)
IconGlow.Position=UDim2.new(0,6,0.46,-8)
IconGlow.BackgroundColor3=G.glass0
IconGlow.BackgroundTransparency=0.94
IconGlow.BorderSizePixel=0; IconGlow.ZIndex=29
mkCorner(IconGlow,18)

local IconLbl=Instance.new("TextLabel",Icon)
IconLbl.Size=UDim2.new(1,0,1,0); IconLbl.BackgroundTransparency=1
IconLbl.Text="◈"; IconLbl.TextSize=22; IconLbl.TextColor3=G.textPri
IconLbl.Font=Enum.Font.GothamBold
IconLbl.TextXAlignment=Enum.TextXAlignment.Center
IconLbl.TextYAlignment=Enum.TextYAlignment.Center
IconLbl.ZIndex=31

-- Status dot
local SDot=Instance.new("Frame",Icon)
SDot.Size=UDim2.new(0,8,0,8); SDot.Position=UDim2.new(1,-10,0,2)
SDot.BackgroundColor3=G.err; SDot.ZIndex=32
mkCorner(SDot,4)

makeDrag(Icon,Icon,function()
    IconGlow.Position=UDim2.new(
        Icon.Position.X.Scale, Icon.Position.X.Offset-8,
        Icon.Position.Y.Scale, Icon.Position.Y.Offset-8)
end)

-- Idle shimmer on icon
task.spawn(function()
    while true do
        tw(IconLbl,{TextTransparency=0.45},1.1,Enum.EasingStyle.Sine)
        task.wait(1.1)
        tw(IconLbl,{TextTransparency=0},1.1,Enum.EasingStyle.Sine)
        task.wait(1.1)
    end
end)

-- ── MAIN WINDOW ───────────────────────────────
local Win=mkGlass(SG, 0.10, 0.60)
Win.Size=UDim2.new(0,350,0,530)
Win.Position=UDim2.new(0.5,-175,0.5,-265)
Win.Visible=false; Win.ZIndex=10; Win.Active=true; Win.ClipsDescendants=true
mkCorner(Win,16)

-- inner noise / grain overlay (simulate frosted glass texture)
local Grain=Instance.new("Frame",Win)
Grain.Size=UDim2.new(1,0,1,0)
Grain.BackgroundColor3=G.glass0; Grain.BackgroundTransparency=0.97
Grain.BorderSizePixel=0; Grain.ZIndex=10

-- top gradient tint
local WGrad=Instance.new("UIGradient",Win)
WGrad.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(38,38,52)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(14,14,20)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8,8,12)),
})
WGrad.Transparency=NumberSequence.new({
    NumberSequenceKeypoint.new(0,0.0),
    NumberSequenceKeypoint.new(1,0.0),
})
WGrad.Rotation=150

-- ── HEADER ────────────────────────────────────
local Hdr=mkGlass(Win, 0.78, 0.68)
Hdr.Size=UDim2.new(1,0,0,54); Hdr.ZIndex=11; mkCorner(Hdr,16)
-- fill bottom so inner rounded corners don't show
local HFix=Instance.new("Frame",Hdr)
HFix.Size=UDim2.new(1,0,0.55,0); HFix.Position=UDim2.new(0,0,0.45,0)
HFix.BackgroundColor3=G.glass0; HFix.BackgroundTransparency=0.78; HFix.BorderSizePixel=0; HFix.ZIndex=11

-- header shimmer gradient
local HGrd=Instance.new("UIGradient",Hdr)
HGrd.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(180,180,200)),
})
HGrd.Transparency=NumberSequence.new({
    NumberSequenceKeypoint.new(0,0.78),
    NumberSequenceKeypoint.new(1,0.90),
})
HGrd.Rotation=90

-- decorative top border line (bright white)
local TopLine=Instance.new("Frame",Win)
TopLine.Size=UDim2.new(0.6,0,0,1); TopLine.Position=UDim2.new(0.2,0,0,0)
TopLine.BackgroundColor3=G.glass0; TopLine.BackgroundTransparency=0.55
TopLine.BorderSizePixel=0; TopLine.ZIndex=20
Instance.new("UIGradient",TopLine).Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(0,0,0)),
    ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,255,255)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(0,0,0)),
})

-- Title text
local TitleL=Instance.new("TextLabel",Hdr)
TitleL.Size=UDim2.new(0,200,0,28); TitleL.Position=UDim2.new(0,16,0,6)
TitleL.BackgroundTransparency=1; TitleL.Text="AVATAR CHANGER"
TitleL.TextSize=14; TitleL.TextColor3=G.textPri; TitleL.Font=Enum.Font.GothamBold
TitleL.TextXAlignment=Enum.TextXAlignment.Left; TitleL.ZIndex=13

local SubL=Instance.new("TextLabel",Hdr)
SubL.Size=UDim2.new(0,200,0,14); SubL.Position=UDim2.new(0,16,0,30)
SubL.BackgroundTransparency=1; SubL.Text="by xythc  ·  v92"
SubL.TextSize=10; SubL.TextColor3=G.textDim; SubL.Font=Enum.Font.Gotham
SubL.TextXAlignment=Enum.TextXAlignment.Left; SubL.ZIndex=13

-- Close button
local CBtn=mkGlass(Hdr,0.80,0.65)
CBtn=Instance.new("TextButton",Hdr)
CBtn.Size=UDim2.new(0,26,0,26); CBtn.Position=UDim2.new(1,-34,0.5,-13)
CBtn.BackgroundColor3=G.glass0; CBtn.BackgroundTransparency=0.82
CBtn.Text="✕"; CBtn.TextSize=11; CBtn.TextColor3=G.textSec
CBtn.Font=Enum.Font.GothamBold; CBtn.AutoButtonColor=false; CBtn.ZIndex=14
mkCorner(CBtn,7); mkStroke(CBtn,G.strokeW,1,0.82)
CBtn.MouseEnter:Connect(function()
    tw(CBtn,{BackgroundTransparency=0.55,TextColor3=G.err},0.12)
end)
CBtn.MouseLeave:Connect(function()
    tw(CBtn,{BackgroundTransparency=0.82,TextColor3=G.textSec},0.12)
end)
CBtn.MouseButton1Click:Connect(function()
    tw(Win,{Size=UDim2.new(0,350,0,0)},0.18,Enum.EasingStyle.Quart)
    task.wait(0.2); Win.Visible=false; BgLayer.Visible=false
    Win.Size=UDim2.new(0,350,0,530)
    tw(SDot,{BackgroundColor3=G.err},0.2)
end)

-- Minimize button
local minimized=false
local MinBtn=Instance.new("TextButton",Hdr)
MinBtn.Size=UDim2.new(0,26,0,26); MinBtn.Position=UDim2.new(1,-64,0.5,-13)
MinBtn.BackgroundColor3=G.glass0; MinBtn.BackgroundTransparency=0.82
MinBtn.Text="–"; MinBtn.TextSize=13; MinBtn.TextColor3=G.textSec
MinBtn.Font=Enum.Font.GothamBold; MinBtn.AutoButtonColor=false; MinBtn.ZIndex=14
mkCorner(MinBtn,7); mkStroke(MinBtn,G.strokeW,1,0.82)
MinBtn.MouseEnter:Connect(function()
    tw(MinBtn,{BackgroundTransparency=0.55,TextColor3=G.textPri},0.12)
end)
MinBtn.MouseLeave:Connect(function()
    tw(MinBtn,{BackgroundTransparency=0.82,TextColor3=G.textSec},0.12)
end)
MinBtn.MouseButton1Click:Connect(function()
    minimized=not minimized
    if minimized then
        tw(Win,{Size=UDim2.new(0,350,0,54)},0.26,Enum.EasingStyle.Quart)
    else
        twSpring(Win,{Size=UDim2.new(0,350,0,530)},0.38)
    end
end)

makeDrag(Hdr,Win,function() syncBg(Win) end)

-- ── THIN SEPARATOR LINE ───────────────────────
local Sep=Instance.new("Frame",Win)
Sep.Size=UDim2.new(1,0,0,1); Sep.Position=UDim2.new(0,0,0,54)
Sep.BackgroundColor3=G.glass0; Sep.BackgroundTransparency=0.80
Sep.BorderSizePixel=0; Sep.ZIndex=11

-- ── TAB BAR ───────────────────────────────────
local TBar=Instance.new("Frame",Win)
TBar.Size=UDim2.new(1,-20,0,32); TBar.Position=UDim2.new(0,10,0,60)
TBar.BackgroundTransparency=1; TBar.ZIndex=11
mkList(TBar,Enum.FillDirection.Horizontal,8)

local Sep2=Instance.new("Frame",Win)
Sep2.Size=UDim2.new(1,0,0,1); Sep2.Position=UDim2.new(0,0,0,96)
Sep2.BackgroundColor3=G.glass0; Sep2.BackgroundTransparency=0.85
Sep2.BorderSizePixel=0; Sep2.ZIndex=11

-- Content area
local ContentHolder=Instance.new("Frame",Win)
ContentHolder.Size=UDim2.new(1,0,1,-100); ContentHolder.Position=UDim2.new(0,0,0,99)
ContentHolder.BackgroundTransparency=1; ContentHolder.ZIndex=10; ContentHolder.ClipsDescendants=true

-- Status bar at bottom
local SBar=Instance.new("Frame",Win)
SBar.Size=UDim2.new(1,0,0,22); SBar.Position=UDim2.new(0,0,1,-22)
SBar.BackgroundColor3=G.glass0; SBar.BackgroundTransparency=0.90
SBar.BorderSizePixel=0; SBar.ZIndex=15
local SBarTop=Instance.new("Frame",SBar)
SBarTop.Size=UDim2.new(1,0,0,1); SBarTop.BackgroundColor3=G.glass0
SBarTop.BackgroundTransparency=0.82; SBarTop.BorderSizePixel=0; SBarTop.ZIndex=15
local SBarT=Instance.new("TextLabel",SBar)
SBarT.Size=UDim2.new(1,-16,1,0); SBarT.Position=UDim2.new(0,10,0,0)
SBarT.BackgroundTransparency=1; SBarT.TextSize=10; SBarT.TextColor3=G.textDim
SBarT.Font=Enum.Font.Gotham; SBarT.TextXAlignment=Enum.TextXAlignment.Left
SBarT.ZIndex=16; SBarT.Text="ready"

local function setStatus(t2)
    SBarT.Text=t2
    tw(SBarT,{TextColor3=G.textSec},0.15)
    task.delay(3,function()
        if SBarT.Text==t2 then
            tw(SBarT,{TextColor3=G.textDim},0.3)
            SBarT.Text="ready"
        end
    end)
end

-- ── SCROLLING PAGES ───────────────────────────
local function mkPage()
    local sf=Instance.new("ScrollingFrame",ContentHolder)
    sf.Size=UDim2.new(1,0,1,0); sf.BackgroundTransparency=1
    sf.ScrollBarThickness=2; sf.ScrollBarImageColor3=G.glass0
    sf.CanvasSize=UDim2.new(0,0,0,0); sf.ZIndex=11; sf.Visible=false
    local ly=mkList(sf); mkPad(sf,10,10,10,28); ly.Padding=UDim.new(0,8)
    ly:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sf.CanvasSize=UDim2.new(0,0,0,ly.AbsoluteContentSize.Y+24)
    end)
    return sf
end

-- ── TAB BUTTON ────────────────────────────────
local tabs={}
local activeTab=""

local function mkTabBtn(label, order)
    local btn=Instance.new("TextButton",TBar)
    btn.Size=UDim2.new(0,152,1,0)
    btn.BackgroundColor3=G.glass0; btn.BackgroundTransparency=0.90
    btn.Text=label; btn.TextSize=11; btn.TextColor3=G.textDim
    btn.Font=Enum.Font.GothamBold; btn.AutoButtonColor=false
    btn.ZIndex=12; btn.LayoutOrder=order
    mkCorner(btn,8); mkStroke(btn,G.strokeW,1,0.88)
    return btn
end

local function switchTab(name)
    for n,d in pairs(tabs) do
        local on=n==name
        tw(d.btn,{BackgroundTransparency=on and 0.72 or 0.90},0.18)
        tw(d.btn,{TextColor3=on and G.textPri or G.textDim},0.18)
        d.page.Visible=on
    end
    activeTab=name
    setStatus(name:lower().." tab")
end

-- ── GLASS SECTION DIVIDER ─────────────────────
local function mkSection(parent, title, order)
    local f=Instance.new("Frame",parent)
    f.Size=UDim2.new(1,0,0,22); f.BackgroundTransparency=1; f.ZIndex=12; f.LayoutOrder=order
    local line=Instance.new("Frame",f)
    line.Size=UDim2.new(1,0,0,1); line.Position=UDim2.new(0,0,0.5,0)
    line.BackgroundColor3=G.glass0; line.BackgroundTransparency=0.82
    line.BorderSizePixel=0; line.ZIndex=12
    -- gradient fade
    local lg=Instance.new("UIGradient",line)
    lg.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.new(0,0,0)),
        ColorSequenceKeypoint.new(0.3,Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(0.7,Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(1,Color3.new(0,0,0)),
    })
    local bg=Instance.new("Frame",f)
    bg.AutomaticSize=Enum.AutomaticSize.X; bg.Size=UDim2.new(0,0,1,0)
    bg.BackgroundColor3=G.base1; bg.BorderSizePixel=0; bg.ZIndex=13
    mkPad(bg,0,8,0,0)
    local lbl=Instance.new("TextLabel",bg)
    lbl.BackgroundTransparency=1; lbl.Text="  "..title
    lbl.TextSize=10; lbl.TextColor3=G.textDim
    lbl.Font=Enum.Font.GothamBold; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.ZIndex=14; lbl.AutomaticSize=Enum.AutomaticSize.XY
    -- letter-spaced look
    lbl.TextColor3=G.textSec
end

-- ── GLASS BUTTON ──────────────────────────────
local function mkBtn(parent, label, order, cb, accentCol)
    local btn=Instance.new("TextButton",parent)
    btn.Size=UDim2.new(1,0,0,40)
    btn.BackgroundColor3=G.glass0; btn.BackgroundTransparency=0.88
    btn.Text=label; btn.TextSize=12; btn.TextColor3=G.textPri
    btn.Font=Enum.Font.GothamBold; btn.AutoButtonColor=false
    btn.ZIndex=12; btn.LayoutOrder=order
    mkCorner(btn,10); mkStroke(btn,accentCol or G.strokeW,1,0.82)

    -- left accent line
    if accentCol then
        local accent=Instance.new("Frame",btn)
        accent.Size=UDim2.new(0,2,0,22); accent.Position=UDim2.new(0,0,0.5,-11)
        accent.BackgroundColor3=accentCol; accent.BorderSizePixel=0; accent.ZIndex=13
        Instance.new("UICorner",accent).CornerRadius=UDim.new(1,0)
    end

    mkPad(btn,14,10,0,0)

    -- ripple on click
    btn.MouseEnter:Connect(function()
        tw(btn,{BackgroundTransparency=0.72},0.14)
        tw(btn,{TextColor3=Color3.new(1,1,1)},0.14)
    end)
    btn.MouseLeave:Connect(function()
        tw(btn,{BackgroundTransparency=0.88},0.14)
        tw(btn,{TextColor3=G.textPri},0.14)
    end)
    btn.MouseButton1Click:Connect(function()
        -- flash
        tw(btn,{BackgroundTransparency=0.55},0.07)
        task.delay(0.08,function() tw(btn,{BackgroundTransparency=0.88},0.18) end)
        if cb then cb() end
    end)
    return btn
end

-- ── GLASS TOGGLE BUTTON ───────────────────────
local function mkToggle(parent, lblOff, lblOn, order, cb)
    local state=false
    local btn=mkBtn(parent, lblOff, order, nil)

    -- pill indicator
    local pill=Instance.new("Frame",btn)
    pill.Size=UDim2.new(0,28,0,14); pill.Position=UDim2.new(1,-40,0.5,-7)
    pill.BackgroundColor3=G.glass0; pill.BackgroundTransparency=0.75
    pill.ZIndex=14; mkCorner(pill,7); mkStroke(pill,G.strokeW,1,0.72)
    local dot=Instance.new("Frame",pill)
    dot.Size=UDim2.new(0,10,0,10); dot.Position=UDim2.new(0,2,0.5,-5)
    dot.BackgroundColor3=G.textDim; dot.ZIndex=15; mkCorner(dot,5)

    local function refresh()
        btn.Text=state and lblOn or lblOff
        tw(dot,{Position=state and UDim2.new(1,-12,0.5,-5) or UDim2.new(0,2,0.5,-5)},0.18)
        tw(dot,{BackgroundColor3=state and G.textPri or G.textDim},0.18)
        tw(btn,{BackgroundTransparency=state and 0.72 or 0.88},0.18)
    end

    btn.MouseButton1Click:Connect(function()
        state=not state; refresh()
        if cb then cb(state) end
    end)

    local function setState(s) state=s; refresh() end
    return btn, setState
end

-- ── INPUT BOX ─────────────────────────────────
local InputWrap=Instance.new("Frame",nil) -- will be parented when page ready
InputWrap.Size=UDim2.new(1,0,0,46)
InputWrap.BackgroundColor3=G.glass0; InputWrap.BackgroundTransparency=0.85
InputWrap.ZIndex=12; InputWrap.LayoutOrder=0
mkCorner(InputWrap,10); mkStroke(InputWrap,G.strokeW,1,0.72)
mkPad(InputWrap,12,12,0,0)

local InputIcon=Instance.new("TextLabel",InputWrap)
InputIcon.Size=UDim2.new(0,18,1,0); InputIcon.BackgroundTransparency=1
InputIcon.Text="◎"; InputIcon.TextSize=14; InputIcon.TextColor3=G.textDim
InputIcon.Font=Enum.Font.GothamBold; InputIcon.ZIndex=13
InputIcon.TextXAlignment=Enum.TextXAlignment.Left

local Box=Instance.new("TextBox",InputWrap)
Box.Size=UDim2.new(1,-22,1,0); Box.Position=UDim2.new(0,22,0,0)
Box.BackgroundTransparency=1; Box.Text=""
Box.PlaceholderText="Username, Asset ID, or Link..."
Box.TextColor3=G.textPri; Box.PlaceholderColor3=G.textDim
Box.Font=Enum.Font.Gotham; Box.TextSize=12
Box.ClearTextOnFocus=false; Box.ZIndex=13

-- Focus animation
Box.Focused:Connect(function()
    tw(InputWrap,{BackgroundTransparency=0.75},0.18)
    tw(InputWrap,{},0.18)  -- trigger stroke update
    mkStroke(InputWrap,G.strokeW,1.5,0.55)
end)
Box.FocusLost:Connect(function()
    tw(InputWrap,{BackgroundTransparency=0.85},0.18)
end)

-- ───────────────────────────────────────────────
-- BUILD PAGES
-- ───────────────────────────────────────────────

-- CHANGER PAGE
local btnChanger=mkTabBtn("◈  Changer",1)
local pageChanger=mkPage()
tabs["Changer"]={btn=btnChanger,page=pageChanger}
btnChanger.MouseButton1Click:Connect(function() switchTab("Changer") end)

-- LOGS PAGE
local btnLogs=mkTabBtn("≡  Logs",2)
local pageLogs=mkPage()
tabs["Logs"]={btn=btnLogs,page=pageLogs}
btnLogs.MouseButton1Click:Connect(function() switchTab("Logs"); rebuildLogs() end)

-- Parent input to changer page
InputWrap.Parent=pageChanger

-- ───────────────────────────────────────────────
-- CHANGER PAGE BUTTONS
-- ───────────────────────────────────────────────
mkSection(pageChanger,"AVATAR",1)

mkBtn(pageChanger,"◈  Change Avatar", 2, function()
    local input=Box.Text:match("^%s*(.-)%s*$"); if input=="" then return end
    local cid=input:match("%d+")
    if cid and #input<=15 then
        if WearItem(cid) then
            if not table.find(X_ItemHistory,cid) then
                table.insert(X_ItemHistory,1,cid)
                if #X_ItemHistory>30 then table.remove(X_ItemHistory) end
                SaveData()
            end; return
        end
    end
    local ok,uid=pcall(function() return X_Players:GetUserIdFromNameAsync(input) end)
    if not ok then uid=tonumber(cid) end
    if not uid then Notify("User not found","!"); return end
    if not table.find(X_History,input) then
        table.insert(X_History,1,input)
        if #X_History>30 then table.remove(X_History) end
        SaveData()
    end
    local model=X_Players:CreateHumanoidModelFromUserId(uid); local items={}
    for _,v in ipairs(model:GetChildren()) do
        if not v:IsA("Humanoid") then
            if v:IsA("BasePart") and (v.Name:find("Leg") or v.Name=="Head") then
                local m=v:FindFirstChildOfClass("SpecialMesh")
                if m then table.insert(items,m:Clone()) end
            end
            table.insert(items,v:Clone())
        end
    end
    FinalApply(items,false); model:Destroy()
    setStatus("avatar changed")
end, G.textPri)

mkBtn(pageChanger,"⊕  Wear Item ID",3,function()
    local cid=Box.Text:match("%d+"); if not cid then return end
    if WearItem(cid) then
        if not table.find(X_ItemHistory,cid) then
            table.insert(X_ItemHistory,1,cid)
            if #X_ItemHistory>50 then table.remove(X_ItemHistory) end
            SaveData()
        end
    end
    setStatus("item worn")
end)

mkBtn(pageChanger,"⊛  Inject Body / Face / Head",4,function()
    local cid=Box.Text:match("%d+"); if not cid then return end
    InjectCustomPart(cid); setStatus("injected")
end)

mkSection(pageChanger,"TOGGLES",5)

local _,kbSet=mkToggle(pageChanger,"◻  Korblox: Off","◼  Korblox: On",6,function(on)
    X_KorbloxActive=on; ApplyKorblox(on)
    setStatus("korblox "..(on and "on" or "off"))
end)

local _,hlSet=mkToggle(pageChanger,"◻  Headless: Off","◼  Headless: On",7,function(on)
    X_HeadlessActive=on
    local head=getChar() and getChar():FindFirstChild("Head")
    if head then
        head.Transparency=on and 1 or 0
        local face=head:FindFirstChild("face")
        if face then face.Transparency=on and 1 or 0 end
    end
    setStatus("headless "..(on and "on" or "off"))
end)

mkSection(pageChanger,"OUTFIT",8)

mkBtn(pageChanger,"★  Add to Favorites",9,function()
    local input=Box.Text:match("^%s*(.-)%s*$")
    if input=="" then Notify("Enter a username or ID","!"); return end
    if table.find(X_Favorites,input) then Notify("Already favorited","·"); return end
    table.insert(X_Favorites,1,input)
    if #X_Favorites>30 then table.remove(X_Favorites) end
    SaveData(); Notify("Added to favorites","★"); setStatus("favorited")
end)

mkBtn(pageChanger,"▣  Save Current Outfit",10,function()
    if #X_CurrentItems==0 then Notify("No outfit applied","!"); return end
    local name=Box.Text:match("^%s*(.-)%s*$")
    if name=="" then name="Outfit "..(#X_SavedOutfits+1) end
    X_SavedOutfits[name]=SerializeItems(X_CurrentItems)
    SaveData(); Notify("Saved: "..name,"▣"); setStatus("outfit saved")
end)

mkBtn(pageChanger,"↺  Reset Avatar",11,function()
    X_KorbloxActive=false; X_HeadlessActive=false
    kbSet(false); hlSet(false)
    FinalApply(X_OriginalItems,true); setStatus("avatar reset")
end)

-- ───────────────────────────────────────────────
-- LOGS PAGE
-- ───────────────────────────────────────────────
function rebuildLogs()
    for _,v in ipairs(pageLogs:GetChildren()) do
        if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then v:Destroy() end
    end

    local order=0
    local function addSec(title)
        order+=1
        mkSection(pageLogs,title,order)
    end

    local function addRow(label, onApply, onDel)
        order+=1
        local row=Instance.new("Frame",pageLogs)
        row.Size=UDim2.new(1,0,0,38)
        row.BackgroundColor3=G.glass0; row.BackgroundTransparency=0.88
        row.ZIndex=12; row.LayoutOrder=order
        mkCorner(row,8); mkStroke(row,G.strokeW,1,0.84)

        local applyBtn=Instance.new("TextButton",row)
        applyBtn.Size=UDim2.new(1,-36,1,0); applyBtn.BackgroundTransparency=1
        applyBtn.Text=label; applyBtn.TextSize=11; applyBtn.TextColor3=G.textPri
        applyBtn.Font=Enum.Font.GothamBold; applyBtn.TextXAlignment=Enum.TextXAlignment.Left
        applyBtn.ZIndex=13; mkPad(applyBtn,10,0,0,0)
        applyBtn.MouseEnter:Connect(function() tw(row,{BackgroundTransparency=0.72},0.12) end)
        applyBtn.MouseLeave:Connect(function() tw(row,{BackgroundTransparency=0.88},0.12) end)
        applyBtn.MouseButton1Click:Connect(function()
            tw(row,{BackgroundTransparency=0.55},0.07)
            task.delay(0.1,function() tw(row,{BackgroundTransparency=0.88},0.15) end)
            if onApply then onApply() end
        end)

        local delBtn=Instance.new("TextButton",row)
        delBtn.Size=UDim2.new(0,26,0,26); delBtn.Position=UDim2.new(1,-32,0.5,-13)
        delBtn.BackgroundColor3=G.glass0; delBtn.BackgroundTransparency=0.84
        delBtn.Text="✕"; delBtn.TextSize=10; delBtn.TextColor3=G.textDim
        delBtn.Font=Enum.Font.GothamBold; delBtn.AutoButtonColor=false; delBtn.ZIndex=13
        mkCorner(delBtn,6); mkStroke(delBtn,G.strokeW,1,0.88)
        delBtn.MouseEnter:Connect(function()
            tw(delBtn,{BackgroundTransparency=0.55,TextColor3=G.err},0.1)
        end)
        delBtn.MouseLeave:Connect(function()
            tw(delBtn,{BackgroundTransparency=0.84,TextColor3=G.textDim},0.1)
        end)
        delBtn.MouseButton1Click:Connect(function()
            tw(row,{BackgroundTransparency=1},0.14)
            task.delay(0.16,function() row:Destroy() end)
            if onDel then onDel() end
        end)
    end

    local function addEmpty(note)
        order+=1
        local l=Instance.new("TextLabel",pageLogs)
        l.Size=UDim2.new(1,0,0,26); l.BackgroundTransparency=1
        l.Text=note; l.TextSize=11; l.TextColor3=G.textDim
        l.Font=Enum.Font.Gotham; l.TextXAlignment=Enum.TextXAlignment.Center
        l.ZIndex=12; l.LayoutOrder=order
    end

    -- Saved Outfits
    addSec("▣  SAVED OUTFITS")
    local hasO=false
    for name,serialized in pairs(X_SavedOutfits) do
        hasO=true
        local n=name
        addRow(n,
            function() DeserializeAndApply(serialized); setStatus("outfit loaded") end,
            function() X_SavedOutfits[n]=nil; SaveData() end
        )
    end
    if not hasO then addEmpty("No saved outfits") end

    -- Favorites
    addSec("★  FAVORITES")
    if #X_Favorites==0 then addEmpty("No favorites yet")
    else
        for i,fav in ipairs(X_Favorites) do
            local idx=i; local f=fav
            addRow(f,
                function() Box.Text=f; switchTab("Changer"); setStatus("loaded from favorites") end,
                function() table.remove(X_Favorites,idx); SaveData() end
            )
        end
    end

    -- Avatar History
    addSec("◈  AVATAR HISTORY")
    if #X_History==0 then addEmpty("No history yet")
    else
        for i,entry in ipairs(X_History) do
            local idx=i; local e=entry
            addRow(e,
                function() Box.Text=e; switchTab("Changer"); setStatus("loaded from history") end,
                function() table.remove(X_History,idx); SaveData(); rebuildLogs() end
            )
        end
    end

    -- Item History
    addSec("⊕  ITEM HISTORY")
    if #X_ItemHistory==0 then addEmpty("No item history yet")
    else
        for i,id in ipairs(X_ItemHistory) do
            local idx=i
            addRow("ID  "..id,
                function() Box.Text=id; switchTab("Changer"); setStatus("loaded item id") end,
                function() table.remove(X_ItemHistory,idx); SaveData(); rebuildLogs() end
            )
        end
    end

    -- Clear buttons
    order+=1
    local clearRow=Instance.new("Frame",pageLogs)
    clearRow.Size=UDim2.new(1,0,0,34); clearRow.BackgroundTransparency=1
    clearRow.ZIndex=12; clearRow.LayoutOrder=order
    mkList(clearRow,Enum.FillDirection.Horizontal,8)

    local function mkClear(label, cb)
        local b=Instance.new("TextButton",clearRow)
        b.Size=UDim2.new(0.5,-4,1,0)
        b.BackgroundColor3=G.glass0; b.BackgroundTransparency=0.88
        b.Text=label; b.TextSize=10; b.TextColor3=G.textSec
        b.Font=Enum.Font.GothamBold; b.AutoButtonColor=false; b.ZIndex=13
        mkCorner(b,8); mkStroke(b,G.err,1,0.65)
        b.MouseEnter:Connect(function() tw(b,{BackgroundTransparency=0.65,TextColor3=G.err},0.12) end)
        b.MouseLeave:Connect(function() tw(b,{BackgroundTransparency=0.88,TextColor3=G.textSec},0.12) end)
        b.MouseButton1Click:Connect(function()
            tw(b,{BackgroundTransparency=0.50},0.07)
            task.delay(0.1,function() tw(b,{BackgroundTransparency=0.88},0.15) end)
            if cb then cb() end
        end)
    end
    mkClear("✕  Clear History",function()
        X_History={}; X_ItemHistory={}; SaveData(); rebuildLogs()
    end)
    mkClear("✕  Clear Favorites",function()
        X_Favorites={}; SaveData(); rebuildLogs()
    end)
end

-- ───────────────────────────────────────────────
-- OPEN / CLOSE
-- ───────────────────────────────────────────────
local function openWin()
    syncBg(Win)
    Win.Size=UDim2.new(0,350,0,0)
    Win.Position=UDim2.new(0.5,-175,0.5,0)
    BgLayer.Visible=true; Win.Visible=true
    twSpring(Win,{
        Size=UDim2.new(0,350,0,530),
        Position=UDim2.new(0.5,-175,0.5,-265)
    }, 0.36)
    tw(BgLayer,{Size=UDim2.new(0,370,0,550)},0.3)
    tw(SDot,{BackgroundColor3=G.ok},0.25)
    if activeTab=="" then switchTab("Changer") end
end

local function closeWin()
    tw(Win,{Size=UDim2.new(0,350,0,0),Position=UDim2.new(0.5,-175,0.5,0)},0.2,Enum.EasingStyle.Quart)
    tw(BgLayer,{Size=UDim2.new(0,370,0,0)},0.18)
    task.wait(0.22)
    Win.Visible=false; BgLayer.Visible=false
    Win.Size=UDim2.new(0,350,0,530)
    tw(SDot,{BackgroundColor3=G.err},0.2)
end

Icon.MouseButton1Click:Connect(function()
    if Win.Visible then closeWin() else openWin() end
end)

X_UIS.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.KeyCode==Enum.KeyCode.RightShift then
        if Win.Visible then closeWin() else openWin() end
    end
end)

-- ── LAUNCH ────────────────────────────────────
task.wait(0.8); openWin()
Notify("Avatar Changer loaded","◈")
