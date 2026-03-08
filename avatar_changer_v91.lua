-- AVATAR CHANGER — REBUILT UI
-- Fixed: POV arms, first-person item visibility, history, save outfit, favorites

local X_Player    = game:GetService("Players").LocalPlayer
local X_UIS       = game:GetService("UserInputService")
local X_Players   = game:GetService("Players")
local X_Http      = game:GetService("HttpService")
local X_Tween     = game:GetService("TweenService")
local X_Market    = game:GetService("MarketplaceService")
local X_Insert    = game:GetService("InsertService")
local X_Run       = game:GetService("RunService")
local CoreGui     = game:GetService("CoreGui")

-- ─────────────────────────────────────────
-- STATE
-- ─────────────────────────────────────────
local X_OriginalItems = {}
local X_CurrentItems  = {}
local X_History       = {}   -- usernames
local X_ItemHistory   = {}   -- item IDs
local X_Favorites     = {}   -- username or ID strings
local X_SavedOutfits  = {}   -- { name = { serialized items } }
local X_KorbloxActive = false
local X_HeadlessActive = false

-- ─────────────────────────────────────────
-- PERSISTENCE  (save/load JSON)
-- ─────────────────────────────────────────
local FILE = "AvatarChanger_V91.json"

local function SaveData()
    pcall(function()
        if not writefile then return end
        -- Saved outfits store item info as serializable tables, not Instance refs
        local serialOutfits = {}
        for name, items in pairs(X_SavedOutfits) do
            serialOutfits[name] = items -- already serialized on save
        end
        local data = {
            H  = X_History,
            IH = X_ItemHistory,
            F  = X_Favorites,
            SO = serialOutfits,
        }
        writefile(FILE, X_Http:JSONEncode(data))
    end)
end

local function LoadData()
    pcall(function()
        if not isfile or not isfile(FILE) then return end
        local ok, result = pcall(function() return X_Http:JSONDecode(readfile(FILE)) end)
        if not ok or not result then return end
        X_History      = type(result.H)  == "table" and result.H  or {}
        X_ItemHistory  = type(result.IH) == "table" and result.IH or {}
        X_Favorites    = type(result.F)  == "table" and result.F  or {}
        X_SavedOutfits = type(result.SO) == "table" and result.SO or {}
    end)
end
LoadData()

-- ─────────────────────────────────────────
-- HELPERS
-- ─────────────────────────────────────────
local function tw(obj, props, t, style)
    X_Tween:Create(obj, TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play()
end

local function getChar() return X_Player.Character end
local function getHum()  local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid") end
local function getHRP()  local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end

-- ─────────────────────────────────────────
-- NOTIFICATION
-- ─────────────────────────────────────────
local function Notify(msg)
    local nG = X_Player.PlayerGui:FindFirstChild("X_Notify") or Instance.new("ScreenGui", X_Player.PlayerGui)
    nG.Name = "X_Notify"
    local f = Instance.new("Frame", nG)
    f.Size = UDim2.new(0, 200, 0, 36)
    f.Position = UDim2.new(1, 10, 0.88, 0)
    f.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", f)
    stroke.Color = Color3.fromRGB(100, 80, 255); stroke.Thickness = 1.5
    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1, -12, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.Text = msg; lbl.TextColor3 = Color3.new(1,1,1)
    lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    f:TweenPosition(UDim2.new(1, -210, 0.88, 0), "Out", "Back", 0.35, true)
    task.delay(2.8, function()
        f:TweenPosition(UDim2.new(1, 10, 0.88, 0), "In", "Quad", 0.3, true, function() f:Destroy() end)
    end)
end

-- ─────────────────────────────────────────
-- POV / FIRST-PERSON FIX
-- Makes sure all character parts and accessories are visible
-- in first person, and hides the vanilla "ViewmodelArms" default arms
-- ─────────────────────────────────────────
local povConn = nil

local function fixPOVVisibility()
    -- Kill previous connection
    if povConn then povConn:Disconnect(); povConn = nil end

    povConn = X_Run.RenderStepped:Connect(function()
        local char = getChar(); if not char then return end
        local cam  = workspace.CurrentCamera
        if not cam then return end

        local isFirstPerson = (cam.CFrame.Position - (char:FindFirstChild("Head") and char.Head.Position or Vector3.zero)).Magnitude < 1.5

        for _, obj in ipairs(char:GetDescendants()) do
            -- Parts: keep visible unless headless
            if obj:IsA("BasePart") then
                -- Default arm parts (inserted by the engine for first-person)
                -- They're parented to HumanoidRootPart or character with name containing "ViewmodelArm"
                local n = obj.Name:lower()
                if n:find("viewmodel") or n == "leftarm_vm" or n == "rightarm_vm" then
                    -- Always hide engine viewmodel default arms — our custom ones show fine
                    obj.LocalTransparencyModifier = 1
                else
                    -- Force all other parts visible (engine hides them at <1.5 studs)
                    if isFirstPerson then
                        obj.LocalTransparencyModifier = 0
                    end
                end
            end

            -- Accessories / meshes — force visible in first person
            if obj:IsA("Accessory") or obj:IsA("SpecialMesh") or obj:IsA("Decal") then
                -- nothing to set on these, their parent Parts handle it
            end
        end

        -- Also check for the Animator-spawned C0 Arms that Roblox injects
        -- They live in workspace as "RightArm" / "LeftArm" under the HumanoidRootPart
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

-- ─────────────────────────────────────────
-- WELD ACCESSORY
-- ─────────────────────────────────────────
local function X_Weld(acc)
    local char = getChar(); local h = acc:FindFirstChild("Handle")
    if not char or not h then return end
    local att = h:FindFirstChildOfClass("Attachment")
    local tar = att and char:FindFirstChild(att.Name, true)
    acc.Parent = char
    if tar then
        local w = Instance.new("Weld", h)
        w.Part0 = h; w.Part1 = tar.Parent
        w.C0 = att.CFrame; w.C1 = tar.CFrame
    else
        -- fallback: weld to head
        local head = char:FindFirstChild("Head")
        if head then
            local w = Instance.new("Weld", h)
            w.Part0 = h; w.Part1 = head
            w.C0 = CFrame.new(0, 0, 0); w.C1 = CFrame.new(0, 0, 0)
        end
    end
end

-- ─────────────────────────────────────────
-- KORBLOX
-- ─────────────────────────────────────────
local function ApplyKorblox(state)
    local char = getChar(); if not char then return end
    for _, v in ipairs(char:GetChildren()) do
        if v.Name == "VisualKorblox" then v:Destroy() end
    end
    local legParts = {"RightUpperLeg","RightLowerLeg","RightFoot","Right Leg"}
    if state then
        local fl = Instance.new("Part", char)
        fl.Name = "VisualKorblox"; fl.Size = Vector3.new(1,2,1); fl.CanCollide = false
        local m = Instance.new("SpecialMesh", fl)
        m.MeshId = "rbxassetid://902942096"; m.TextureId = "rbxassetid://902843398"; m.Scale = Vector3.new(1.2,1.2,1.2)
        local leg = char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg")
        if leg then
            local w = Instance.new("Weld", fl)
            w.Part0 = leg; w.Part1 = fl
            w.C0 = (leg.Name == "Right Leg") and CFrame.new(0,0.6,-0.1) or CFrame.new(0,0.15,0)
        end
        for _, p in ipairs(legParts) do if char:FindFirstChild(p) then char[p].Transparency = 1 end end
    else
        for _, p in ipairs(legParts) do if char:FindFirstChild(p) then char[p].Transparency = 0 end end
    end
end

-- ─────────────────────────────────────────
-- CLOTHING TEMPLATE RESOLVER
-- ─────────────────────────────────────────
local function GetActualTemplate(id)
    local ok, asset = pcall(function() return game:GetObjects("rbxassetid://"..id)[1] end)
    if ok and asset then
        local tid = ""
        if asset:IsA("Shirt") then tid = asset.ShirtTemplate
        elseif asset:IsA("Pants") then tid = asset.PantsTemplate
        elseif asset:IsA("ShirtGraphic") then tid = asset.Graphic end
        asset:Destroy()
        return tid ~= "" and tid or "rbxassetid://"..id
    end
    return "rbxassetid://"..id
end

-- ─────────────────────────────────────────
-- INJECT BODY PART / FACE / HEAD
-- ─────────────────────────────────────────
local function InjectCustomPart(id)
    local char = getChar(); if not char then return end
    local cleanID = tostring(id):match("%d+"); if not cleanID then return end
    local ok, info = pcall(function() return X_Market:GetProductInfo(tonumber(cleanID)) end)
    if ok and info then
        if info.AssetTypeId == 1 or info.AssetTypeId == 13 then
            local head = char:FindFirstChild("Head")
            if head then
                local face = head:FindFirstChild("face") or Instance.new("Decal", head)
                face.Name = "face"; face.Texture = "rbxassetid://"..cleanID
                Notify("Face applied")
            end
        elseif info.AssetTypeId == 17 or info.AssetTypeId == 24 then
            local head = char:FindFirstChild("Head")
            if head then
                local m = head:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh", head)
                m.MeshId = "rbxassetid://"..cleanID
                Notify("Head mesh applied")
            end
        elseif info.AssetTypeId >= 27 and info.AssetTypeId <= 31 then
            local ok2, asset = pcall(function() return game:GetObjects("rbxassetid://"..cleanID)[1] end)
            if ok2 and asset then asset.Parent = char; Notify("Body part applied") end
        else return false end
        return true
    end
    return false
end

-- ─────────────────────────────────────────
-- WEAR SINGLE ITEM
-- ─────────────────────────────────────────
local function WearItem(id)
    local char = getChar(); if not char then return end
    local ok, info = pcall(function() return X_Market:GetProductInfo(tonumber(id)) end)
    if ok and info then
        if info.AssetTypeId == 11 then
            local shirt = char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt", char)
            shirt.ShirtTemplate = GetActualTemplate(id)
            Notify("Shirt applied"); return true
        elseif info.AssetTypeId == 12 then
            local pants = char:FindFirstChildOfClass("Pants") or Instance.new("Pants", char)
            pants.PantsTemplate = GetActualTemplate(id)
            Notify("Pants applied"); return true
        end
    end
    local ok2, asset = pcall(function() return game:GetObjects("rbxassetid://"..id)[1] end)
    if ok2 and asset then
        if asset:IsA("Accessory") then X_Weld(asset)
        else asset.Parent = char end
        Notify("Item added"); return true
    end
    return false
end

-- ─────────────────────────────────────────
-- FINAL APPLY  (full avatar swap)
-- ─────────────────────────────────────────
local function FinalApply(items, isReset)
    local char = getChar(); if not char then return end
    local head = char:FindFirstChild("Head")
    local isR15Source, hasR6HeadMesh = false, false

    for _, item in ipairs(items) do
        if type(item) == "table" then
            -- serialized form (from saved outfits loaded from file) — skip instance checks
        else
            local n = item.Name or ""
            if n:find("Upper") or n:find("Lower") or n:find("Hand") or n:find("Foot") then isR15Source = true end
            if item:IsA("SpecialMesh") and (item.MeshType == Enum.MeshType.Head or item.MeshId ~= "") then hasR6HeadMesh = true end
        end
    end

    -- Clean existing
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Clothing") or v:IsA("BodyColors") or v:IsA("CharacterMesh") then
            v:Destroy()
        elseif v:IsA("BasePart") and v.Name:find("Leg") then
            v.Transparency = 0
        end
    end

    if head then
        head.Transparency = 0
        head.Size = Vector3.new(2, 1, 1)
        for _, v in ipairs(head:GetChildren()) do
            if v:IsA("Decal") or v:IsA("SpecialMesh") then v:Destroy() end
        end
    end

    for _, item in ipairs(items) do
        if type(item) ~= "userdata" then continue end -- skip serialized tables
        if item:IsA("Accessory") then X_Weld(item:Clone())
        elseif item:IsA("Clothing") or item:IsA("BodyColors") or item:IsA("CharacterMesh") then
            item:Clone().Parent = char
        elseif item:IsA("SpecialMesh") and head then
            item:Clone().Parent = head
        elseif item:IsA("Decal") and item.Name == "face" and head then
            item:Clone().Parent = head
        end
    end

    if head then
        local forceHeadless = isR15Source and not hasR6HeadMesh and not isReset
        local hideHead = X_HeadlessActive or forceHeadless
        head.Transparency = hideHead and 1 or 0
        local face = head:FindFirstChild("face")
        if face then face.Transparency = hideHead and 1 or 0 end
        if isReset and not head:FindFirstChildOfClass("SpecialMesh") then
            local m = Instance.new("SpecialMesh", head)
            m.MeshType = Enum.MeshType.Head; m.Scale = Vector3.new(1.25,1.25,1.25)
        end
    end

    ApplyKorblox(X_KorbloxActive or (isR15Source and not isReset))

    X_CurrentItems = items
    fixPOVVisibility()
    Notify(isReset and "Avatar reset" or "Avatar changed ✓")
end

-- ─────────────────────────────────────────
-- SERIALIZE / DESERIALIZE OUTFITS
-- We store item instance data as serializable records so saved outfits
-- survive across sessions properly (instead of storing live Instance refs)
-- ─────────────────────────────────────────
local function SerializeItems(items)
    local t = {}
    for _, item in ipairs(items) do
        if type(item) ~= "userdata" then continue end
        local record = {class = item.ClassName, name = item.Name}
        if item:IsA("Shirt")  then record.template = item.ShirtTemplate end
        if item:IsA("Pants")  then record.template = item.PantsTemplate end
        if item:IsA("ShirtGraphic") then record.template = item.Graphic end
        if item:IsA("BodyColors") then
            record.bc = {
                item.HeadColor3.R, item.HeadColor3.G, item.HeadColor3.B,
                item.TorsoColor3.R, item.TorsoColor3.G, item.TorsoColor3.B,
                item.LeftArmColor3.R, item.LeftArmColor3.G, item.LeftArmColor3.B,
                item.RightArmColor3.R, item.RightArmColor3.G, item.RightArmColor3.B,
                item.LeftLegColor3.R, item.LeftLegColor3.G, item.LeftLegColor3.B,
                item.RightLegColor3.R, item.RightLegColor3.G, item.RightLegColor3.B,
            }
        end
        if item:IsA("Accessory") then
            local h = item:FindFirstChild("Handle")
            if h then
                local m = h:FindFirstChildOfClass("SpecialMesh")
                record.meshId    = m and m.MeshId    or ""
                record.textureId = m and m.TextureId or ""
                record.meshScale = m and {m.Scale.X, m.Scale.Y, m.Scale.Z} or {1,1,1}
            end
        end
        if item:IsA("SpecialMesh") then
            record.meshId    = item.MeshId
            record.textureId = item.TextureId
            record.meshType  = tostring(item.MeshType)
            record.scale     = {item.Scale.X, item.Scale.Y, item.Scale.Z}
        end
        if item:IsA("Decal") then record.texture = item.Texture end
        table.insert(t, record)
    end
    return t
end

local function DeserializeAndApply(records)
    -- Re-apply from serialized record list
    local char = getChar(); if not char then return end
    local head = char:FindFirstChild("Head")

    -- Clean
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
            local acc = Instance.new("Accessory")
            acc.Name = rec.name or "Accessory"
            local handle = Instance.new("Part", acc)
            handle.Name = "Handle"; handle.CanCollide = false; handle.Size = Vector3.new(1,1,1)
            local mesh = Instance.new("SpecialMesh", handle)
            mesh.MeshId = rec.meshId; mesh.TextureId = rec.textureId or ""
            if rec.meshScale then mesh.Scale = Vector3.new(rec.meshScale[1], rec.meshScale[2], rec.meshScale[3]) end
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

    fixPOVVisibility()
    Notify("Outfit loaded ✓")
end

-- ─────────────────────────────────────────
-- CAPTURE ORIGINAL AVATAR
-- ─────────────────────────────────────────
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

-- Re-apply avatar on respawn
X_Player.CharacterAdded:Connect(function()
    task.wait(0.6)
    if #X_CurrentItems > 0 then FinalApply(X_CurrentItems, false) end
    fixPOVVisibility()
end)

-- Start POV fix immediately
fixPOVVisibility()

-- ═══════════════════════════════════════════════════════════
--                     NEW UI
-- ═══════════════════════════════════════════════════════════
local SG = Instance.new("ScreenGui", X_Player.PlayerGui)
SG.Name = "AvatarChangerUI"; SG.ResetOnSpawn = false; SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = 200

-- THEME
local T = {
    bg0    = Color3.fromRGB(8,   8,  14),
    bg1    = Color3.fromRGB(13,  13,  22),
    bg2    = Color3.fromRGB(18,  18,  30),
    bg3    = Color3.fromRGB(24,  24,  40),
    border = Color3.fromRGB(40,  40,  72),
    acc    = Color3.fromRGB(110,  90, 255),
    accHi  = Color3.fromRGB(150, 130, 255),
    accLo  = Color3.fromRGB(55,   42, 140),
    green  = Color3.fromRGB(0,   200, 100),
    red    = Color3.fromRGB(210,  45,  65),
    yellow = Color3.fromRGB(255, 200,  50),
    orange = Color3.fromRGB(240, 130,  20),
    white  = Color3.fromRGB(230, 230, 255),
    muted  = Color3.fromRGB(110, 110, 150),
}

local function mkCorner(p, r)
    local c = Instance.new("UICorner", p); c.CornerRadius = UDim.new(0, r or 8); return c
end
local function mkStroke(p, col, t2)
    local s = Instance.new("UIStroke", p); s.Color = col or T.border; s.Thickness = t2 or 1.2; return s
end
local function mkPad(p, l, r2, top, b)
    local pad = Instance.new("UIPadding", p)
    pad.PaddingLeft = UDim.new(0, l or 0); pad.PaddingRight = UDim.new(0, r2 or 0)
    pad.PaddingTop  = UDim.new(0, top or 0); pad.PaddingBottom = UDim.new(0, b or 0)
end
local function mkList(p, dir, pad2, ha, va)
    local l = Instance.new("UIListLayout", p)
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.Padding = UDim.new(0, pad2 or 0)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    if ha then l.HorizontalAlignment = ha end
    if va then l.VerticalAlignment = va end
    return l
end

-- drag helper
local function makeDrag(handle, target)
    local drag, dStart, dPos = false
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true; dStart = i.Position; dPos = target.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then drag = false end end)
        end
    end)
    X_UIS.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dStart
            target.Position = UDim2.new(dPos.X.Scale, dPos.X.Offset + d.X, dPos.Y.Scale, dPos.Y.Offset + d.Y)
        end
    end)
end

-- ─────────────────────────────────────────
-- FLOATING ICON
-- ─────────────────────────────────────────
local Icon = Instance.new("TextButton", SG)
Icon.Size = UDim2.new(0, 44, 0, 44)
Icon.Position = UDim2.new(0, 12, 0.5, -22)
Icon.BackgroundColor3 = T.bg2
Icon.Text = ""; Icon.AutoButtonColor = false; Icon.ZIndex = 20
mkCorner(Icon, 12); mkStroke(Icon, T.acc, 2)

local IconLbl = Instance.new("TextLabel", Icon)
IconLbl.Size = UDim2.new(1,0,1,0); IconLbl.BackgroundTransparency = 1
IconLbl.Text = "👤"; IconLbl.TextSize = 20; IconLbl.ZIndex = 21
IconLbl.Font = Enum.Font.GothamBold; IconLbl.TextColor3 = T.white
IconLbl.TextXAlignment = Enum.TextXAlignment.Center
IconLbl.TextYAlignment = Enum.TextYAlignment.Center

local StatusDot = Instance.new("Frame", Icon)
StatusDot.Size = UDim2.new(0, 9, 0, 9)
StatusDot.Position = UDim2.new(1, -11, 0, 2)
StatusDot.BackgroundColor3 = T.red; mkCorner(StatusDot, 5)
StatusDot.ZIndex = 22

makeDrag(Icon, Icon)

-- ─────────────────────────────────────────
-- MAIN WINDOW
-- ─────────────────────────────────────────
local Win = Instance.new("Frame", SG)
Win.Size = UDim2.new(0, 340, 0, 520)
Win.Position = UDim2.new(0.5, -170, 0.5, -260)
Win.BackgroundColor3 = T.bg0
Win.Visible = false; Win.ZIndex = 10; Win.Active = true; Win.ClipsDescendants = true
mkCorner(Win, 14); mkStroke(Win, T.acc, 2)

local WGrad = Instance.new("UIGradient", Win)
WGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 10, 28)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 8, 14)),
})
WGrad.Rotation = 140

-- Shadow
local Shad = Instance.new("Frame", SG)
Shad.Size = UDim2.new(0, 360, 0, 540)
Shad.BackgroundColor3 = Color3.new(0,0,0); Shad.BackgroundTransparency = 0.55
Shad.ZIndex = 9; Shad.Visible = false; mkCorner(Shad, 18)
local function syncShad()
    Shad.Position = UDim2.new(Win.Position.X.Scale, Win.Position.X.Offset - 10,
                               Win.Position.Y.Scale, Win.Position.Y.Offset - 10)
end; syncShad()

-- ─────────────────────────────────────────
-- HEADER
-- ─────────────────────────────────────────
local Hdr = Instance.new("Frame", Win)
Hdr.Size = UDim2.new(1, 0, 0, 50); Hdr.BackgroundColor3 = T.bg2; Hdr.ZIndex = 11; mkCorner(Hdr, 14)
local HFix = Instance.new("Frame", Hdr)
HFix.Size = UDim2.new(1, 0, 0.5, 0); HFix.Position = UDim2.new(0, 0, 0.5, 0)
HFix.BackgroundColor3 = T.bg2; HFix.BorderSizePixel = 0; HFix.ZIndex = 11

local HGrd = Instance.new("UIGradient", Hdr)
HGrd.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 45, 155)), ColorSequenceKeypoint.new(1, T.bg2)})
HGrd.Rotation = 90

local TitleL = Instance.new("TextLabel", Hdr)
TitleL.Size = UDim2.new(0, 220, 1, 0); TitleL.Position = UDim2.new(0, 14, 0, 0)
TitleL.BackgroundTransparency = 1; TitleL.Text = "👤  AVATAR CHANGER"
TitleL.TextSize = 14; TitleL.TextColor3 = T.white; TitleL.Font = Enum.Font.GothamBold
TitleL.TextXAlignment = Enum.TextXAlignment.Left; TitleL.ZIndex = 12

local SubL = Instance.new("TextLabel", Hdr)
SubL.Size = UDim2.new(0, 220, 0, 13); SubL.Position = UDim2.new(0, 14, 1, -15)
SubL.BackgroundTransparency = 1; SubL.Text = "by XYTHC  •  v91"
SubL.TextSize = 10; SubL.TextColor3 = T.muted; SubL.Font = Enum.Font.Gotham
SubL.TextXAlignment = Enum.TextXAlignment.Left; SubL.ZIndex = 12

-- Close btn
local CloseBtn = Instance.new("TextButton", Hdr)
CloseBtn.Size = UDim2.new(0, 26, 0, 26); CloseBtn.Position = UDim2.new(1, -32, 0.5, -13)
CloseBtn.BackgroundColor3 = Color3.fromRGB(155, 30, 50); CloseBtn.Text = "✕"
CloseBtn.TextSize = 12; CloseBtn.TextColor3 = Color3.new(1,1,1); CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.AutoButtonColor = false; CloseBtn.ZIndex = 13; mkCorner(CloseBtn, 6)
CloseBtn.MouseEnter:Connect(function() tw(CloseBtn, {BackgroundColor3 = T.red}, 0.1) end)
CloseBtn.MouseLeave:Connect(function() tw(CloseBtn, {BackgroundColor3 = Color3.fromRGB(155, 30, 50)}, 0.1) end)
CloseBtn.MouseButton1Click:Connect(function()
    tw(Win, {Size = UDim2.new(0, 340, 0, 0)}, 0.15)
    task.wait(0.17); Win.Visible = false; Shad.Visible = false
    Win.Size = UDim2.new(0, 340, 0, 520)
    StatusDot.BackgroundColor3 = T.red
end)

makeDrag(Hdr, Win)

-- ─────────────────────────────────────────
-- TAB BAR  (Changer | Logs)
-- ─────────────────────────────────────────
local TabBar = Instance.new("Frame", Win)
TabBar.Size = UDim2.new(1, -20, 0, 30); TabBar.Position = UDim2.new(0, 10, 0, 55)
TabBar.BackgroundTransparency = 1; TabBar.ZIndex = 11
mkList(TabBar, Enum.FillDirection.Horizontal, 8)

local TabSep = Instance.new("Frame", Win)
TabSep.Size = UDim2.new(1, 0, 0, 1); TabSep.Position = UDim2.new(0, 0, 0, 90)
TabSep.BackgroundColor3 = T.acc; TabSep.BackgroundTransparency = 0.65
TabSep.BorderSizePixel = 0; TabSep.ZIndex = 11

-- Content holder
local ContentHolder = Instance.new("Frame", Win)
ContentHolder.Size = UDim2.new(1, 0, 1, -94); ContentHolder.Position = UDim2.new(0, 0, 0, 93)
ContentHolder.BackgroundTransparency = 1; ContentHolder.ZIndex = 10; ContentHolder.ClipsDescendants = true

local activeTab = ""

local function mkTabBtn(label, order)
    local btn = Instance.new("TextButton", TabBar)
    btn.Size = UDim2.new(0, 148, 1, 0)
    btn.BackgroundColor3 = T.bg3; btn.Text = label
    btn.TextSize = 11; btn.TextColor3 = T.muted; btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false; btn.ZIndex = 12; btn.LayoutOrder = order
    mkCorner(btn, 7)
    return btn
end

local tabs = {}

local function switchTab(name)
    for n, d in pairs(tabs) do
        local on = n == name
        tw(d.btn, {BackgroundColor3 = on and T.acc or T.bg3}, 0.15)
        d.btn.TextColor3 = on and T.white or T.muted
        d.page.Visible = on
    end
    activeTab = name
end

-- ─────────────────────────────────────────
-- SCROLLING PAGES
-- ─────────────────────────────────────────
local function mkPage()
    local sf = Instance.new("ScrollingFrame", ContentHolder)
    sf.Size = UDim2.new(1, 0, 1, 0); sf.BackgroundTransparency = 1
    sf.ScrollBarThickness = 3; sf.ScrollBarImageColor3 = T.acc
    sf.CanvasSize = UDim2.new(0, 0, 0, 0); sf.ZIndex = 11; sf.Visible = false
    local ly = mkList(sf); mkPad(sf, 10, 10, 8, 8); ly.Padding = UDim.new(0, 7)
    ly:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sf.CanvasSize = UDim2.new(0, 0, 0, ly.AbsoluteContentSize.Y + 20)
    end)
    return sf
end

-- Tab: CHANGER
local btnChanger = mkTabBtn("✏️  CHANGER", 1)
local pageChanger = mkPage()
tabs["Changer"] = {btn = btnChanger, page = pageChanger}
btnChanger.MouseButton1Click:Connect(function() switchTab("Changer") end)

-- Tab: LOGS
local btnLogs = mkTabBtn("📋  LOGS", 2)
local pageLogs = mkPage()
tabs["Logs"] = {btn = btnLogs, page = pageLogs}
btnLogs.MouseButton1Click:Connect(function() switchTab("Logs"); rebuildLogs() end)

-- ─────────────────────────────────────────
-- COMPONENT BUILDERS
-- ─────────────────────────────────────────
local function mkSection(parent, title, order)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 20); f.BackgroundTransparency = 1; f.ZIndex = 12; f.LayoutOrder = order
    local line = Instance.new("Frame", f)
    line.Size = UDim2.new(1, 0, 0, 1); line.Position = UDim2.new(0, 0, 0.5, 0)
    line.BackgroundColor3 = T.acc; line.BackgroundTransparency = 0.65; line.BorderSizePixel = 0; line.ZIndex = 12
    local bg = Instance.new("Frame", f)
    bg.AutomaticSize = Enum.AutomaticSize.X; bg.Size = UDim2.new(0, 0, 1, 0)
    bg.BackgroundColor3 = T.bg0; bg.BorderSizePixel = 0; bg.ZIndex = 13; mkPad(bg, 0, 8, 0, 0)
    local lbl = Instance.new("TextLabel", bg)
    lbl.BackgroundTransparency = 1; lbl.Text = "  " .. title
    lbl.TextSize = 10; lbl.TextColor3 = T.acc; lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 14
    lbl.AutomaticSize = Enum.AutomaticSize.XY
end

local function mkButton(parent, label, color, order, cb)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.BackgroundColor3 = color or T.bg3
    btn.Text = label; btn.TextSize = 12; btn.TextColor3 = T.white
    btn.Font = Enum.Font.GothamBold; btn.AutoButtonColor = false; btn.ZIndex = 12
    btn.LayoutOrder = order; mkCorner(btn, 8); mkStroke(btn, T.border, 1)
    btn.MouseEnter:Connect(function() tw(btn, {BackgroundColor3 = Color3.new(color.R*1.2, color.G*1.2, color.B*1.2)}, 0.1) end)
    btn.MouseLeave:Connect(function() tw(btn, {BackgroundColor3 = color}, 0.1) end)
    btn.MouseButton1Click:Connect(function()
        tw(btn, {BackgroundColor3 = Color3.new(color.R*0.7, color.G*0.7, color.B*0.7)}, 0.07)
        task.delay(0.12, function() tw(btn, {BackgroundColor3 = color}, 0.12) end)
        if cb then cb() end
    end)
    return btn
end

local function mkToggleBtn(parent, labelOff, labelOn, colorOff, colorOn, order, cb)
    local state = false
    local btn = mkButton(parent, labelOff, colorOff, order, nil)
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = state and labelOn or labelOff
        tw(btn, {BackgroundColor3 = state and colorOn or colorOff}, 0.15)
        if cb then cb(state) end
    end)
    return btn, function(s) state = s; btn.Text = s and labelOn or labelOff; btn.BackgroundColor3 = s and colorOn or colorOff end
end

-- ─────────────────────────────────────────
-- INPUT BOX (full width, in changer page)
-- ─────────────────────────────────────────
local InputContainer = Instance.new("Frame", pageChanger)
InputContainer.Size = UDim2.new(1, 0, 0, 44); InputContainer.BackgroundColor3 = T.bg2
InputContainer.ZIndex = 12; InputContainer.LayoutOrder = 0; mkCorner(InputContainer, 8); mkStroke(InputContainer, T.border, 1)
mkPad(InputContainer, 10, 10, 6, 6)

local InputIcon = Instance.new("TextLabel", InputContainer)
InputIcon.Size = UDim2.new(0, 20, 1, 0); InputIcon.BackgroundTransparency = 1
InputIcon.Text = "🔍"; InputIcon.TextSize = 14; InputIcon.ZIndex = 13
InputIcon.TextXAlignment = Enum.TextXAlignment.Left

local Box = Instance.new("TextBox", InputContainer)
Box.Size = UDim2.new(1, -24, 1, 0); Box.Position = UDim2.new(0, 24, 0, 0)
Box.BackgroundTransparency = 1; Box.Text = ""
Box.PlaceholderText = "Username, Asset ID, or Link..."
Box.TextColor3 = T.white; Box.PlaceholderColor3 = T.muted
Box.Font = Enum.Font.Gotham; Box.TextSize = 12
Box.ClearTextOnFocus = false; Box.ZIndex = 13

-- ─────────────────────────────────────────
-- CHANGER PAGE BUTTONS
-- ─────────────────────────────────────────
mkSection(pageChanger, "AVATAR", 1)

mkButton(pageChanger, "👤  Change Avatar (Username)", T.acc, 2, function()
    local input = Box.Text:match("^%s*(.-)%s*$")
    if input == "" then return end
    local cleanID = input:match("%d+")
    -- If it looks like a pure item ID (short number), try WearItem first
    if cleanID and #input <= 15 then
        if WearItem(cleanID) then
            if not table.find(X_ItemHistory, cleanID) then
                table.insert(X_ItemHistory, 1, cleanID)
                if #X_ItemHistory > 30 then table.remove(X_ItemHistory) end
                SaveData()
            end
            return
        end
    end
    -- Otherwise treat as username
    local ok, uid = pcall(function() return X_Players:GetUserIdFromNameAsync(input) end)
    if not ok then uid = tonumber(cleanID) end
    if not uid then Notify("User not found"); return end
    if not table.find(X_History, input) then
        table.insert(X_History, 1, input)
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
    FinalApply(items, false); model:Destroy()
end)

mkButton(pageChanger, "🎭  Wear Item (ID)", Color3.fromRGB(0, 110, 200), 3, function()
    local cleanID = Box.Text:match("%d+"); if not cleanID then return end
    if WearItem(cleanID) then
        if not table.find(X_ItemHistory, cleanID) then
            table.insert(X_ItemHistory, 1, cleanID)
            if #X_ItemHistory > 50 then table.remove(X_ItemHistory) end
            SaveData()
        end
    end
end)

mkButton(pageChanger, "💉  Inject Body / Face / Head", Color3.fromRGB(0, 140, 190), 4, function()
    local cleanID = Box.Text:match("%d+"); if not cleanID then return end
    InjectCustomPart(cleanID)
end)

mkSection(pageChanger, "TOGGLES", 5)

local kbBtn, kbSet = mkToggleBtn(
    pageChanger,
    "🦴  Korblox: OFF", "🦴  Korblox: ON",
    T.bg3, Color3.fromRGB(60, 40, 140),
    6,
    function(on) X_KorbloxActive = on; ApplyKorblox(on) end
)

local hlBtn, hlSet = mkToggleBtn(
    pageChanger,
    "💀  Headless: OFF", "💀  Headless: ON",
    T.bg3, Color3.fromRGB(40, 40, 40),
    7,
    function(on)
        X_HeadlessActive = on
        local head = getChar() and getChar():FindFirstChild("Head")
        if head then
            head.Transparency = on and 1 or 0
            local face = head:FindFirstChild("face")
            if face then face.Transparency = on and 1 or 0 end
        end
    end
)

mkSection(pageChanger, "OUTFIT", 8)

mkButton(pageChanger, "⭐  Add to Favorites", Color3.fromRGB(160, 110, 0), 9, function()
    local input = Box.Text:match("^%s*(.-)%s*$")
    if input == "" then Notify("Enter a username or ID first"); return end
    if table.find(X_Favorites, input) then Notify("Already in favorites"); return end
    table.insert(X_Favorites, 1, input)
    if #X_Favorites > 30 then table.remove(X_Favorites) end
    SaveData(); Notify("⭐ Added to favorites")
end)

mkButton(pageChanger, "💾  Save Current Outfit", Color3.fromRGB(0, 140, 90), 10, function()
    if #X_CurrentItems == 0 then Notify("No outfit applied yet"); return end
    local name = Box.Text:match("^%s*(.-)%s*$")
    if name == "" then name = "Outfit " .. (#X_SavedOutfits + 1) end
    -- Serialize for persistence
    local serialized = SerializeItems(X_CurrentItems)
    X_SavedOutfits[name] = serialized
    SaveData(); Notify("💾 Saved: " .. name)
end)

mkButton(pageChanger, "🔄  Reset Avatar", T.red, 11, function()
    X_KorbloxActive = false; X_HeadlessActive = false
    kbSet(false); hlSet(false)
    FinalApply(X_OriginalItems, true)
end)

-- ─────────────────────────────────────────
-- LOGS PAGE  (rebuilt properly)
-- ─────────────────────────────────────────
function rebuildLogs()
    -- Clear existing children except layout
    for _, v in ipairs(pageLogs:GetChildren()) do
        if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then v:Destroy() end
    end

    local order = 0

    local function addSectionL(title)
        order += 1
        local f = Instance.new("Frame", pageLogs)
        f.Size = UDim2.new(1, 0, 0, 20); f.BackgroundTransparency = 1; f.ZIndex = 12; f.LayoutOrder = order
        local line = Instance.new("Frame", f)
        line.Size = UDim2.new(1, 0, 0, 1); line.Position = UDim2.new(0, 0, 0.5, 0)
        line.BackgroundColor3 = T.acc; line.BackgroundTransparency = 0.65; line.BorderSizePixel = 0; line.ZIndex = 12
        local bg = Instance.new("Frame", f); bg.AutomaticSize = Enum.AutomaticSize.X
        bg.Size = UDim2.new(0, 0, 1, 0); bg.BackgroundColor3 = T.bg0; bg.BorderSizePixel = 0; bg.ZIndex = 13; mkPad(bg, 0, 8, 0, 0)
        local lbl = Instance.new("TextLabel", bg)
        lbl.BackgroundTransparency = 1; lbl.Text = "  " .. title
        lbl.TextSize = 10; lbl.TextColor3 = T.acc; lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 14; lbl.AutomaticSize = Enum.AutomaticSize.XY
    end

    local function addRow(label, color, onApply, onDelete)
        order += 1
        local row = Instance.new("Frame", pageLogs)
        row.Size = UDim2.new(1, 0, 0, 36); row.BackgroundColor3 = color or T.bg2
        row.ZIndex = 12; row.LayoutOrder = order; mkCorner(row, 7); mkStroke(row, T.border, 1)

        local applyBtn = Instance.new("TextButton", row)
        applyBtn.Size = UDim2.new(1, -38, 1, 0); applyBtn.BackgroundTransparency = 1
        applyBtn.Text = label; applyBtn.TextSize = 11; applyBtn.TextColor3 = T.white
        applyBtn.Font = Enum.Font.GothamBold; applyBtn.TextXAlignment = Enum.TextXAlignment.Left
        applyBtn.ZIndex = 13; mkPad(applyBtn, 10, 0, 0, 0)
        applyBtn.MouseButton1Click:Connect(function() if onApply then onApply() end end)

        -- Delete / remove button
        local delBtn = Instance.new("TextButton", row)
        delBtn.Size = UDim2.new(0, 28, 0, 28); delBtn.Position = UDim2.new(1, -34, 0.5, -14)
        delBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 50); delBtn.Text = "✕"
        delBtn.TextSize = 11; delBtn.TextColor3 = Color3.new(1,1,1); delBtn.Font = Enum.Font.GothamBold
        delBtn.AutoButtonColor = false; delBtn.ZIndex = 13; mkCorner(delBtn, 6)
        delBtn.MouseButton1Click:Connect(function()
            if onDelete then onDelete() end
            row:Destroy()
        end)

        return row
    end

    local function addEmptyNote(note)
        order += 1
        local l = Instance.new("TextLabel", pageLogs)
        l.Size = UDim2.new(1, 0, 0, 24); l.BackgroundTransparency = 1
        l.Text = note; l.TextSize = 11; l.TextColor3 = T.muted; l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Center; l.ZIndex = 12; l.LayoutOrder = order
    end

    -- ── SAVED OUTFITS ──
    addSectionL("💾  SAVED OUTFITS")
    local hasOutfits = false
    for name, serialized in pairs(X_SavedOutfits) do
        hasOutfits = true
        addRow(name, Color3.fromRGB(0, 90, 65),
            function()
                -- Apply saved outfit from serialized data
                DeserializeAndApply(serialized)
            end,
            function()
                X_SavedOutfits[name] = nil
                SaveData()
            end
        )
    end
    if not hasOutfits then addEmptyNote("No saved outfits") end

    -- ── FAVORITES ──
    addSectionL("⭐  FAVORITES")
    if #X_Favorites == 0 then
        addEmptyNote("No favorites yet")
    else
        for i, fav in ipairs(X_Favorites) do
            local idx = i
            addRow(fav, Color3.fromRGB(100, 75, 0),
                function() Box.Text = fav; switchTab("Changer") end,
                function()
                    table.remove(X_Favorites, idx)
                    SaveData()
                end
            )
        end
    end

    -- ── AVATAR HISTORY ──
    addSectionL("🕓  AVATAR HISTORY")
    if #X_History == 0 then
        addEmptyNote("No history yet")
    else
        for i, entry in ipairs(X_History) do
            local idx = i
            addRow(entry, T.bg2,
                function() Box.Text = entry; switchTab("Changer") end,
                function()
                    table.remove(X_History, idx)
                    SaveData(); rebuildLogs()
                end
            )
        end
    end

    -- ── ITEM HISTORY ──
    addSectionL("🎭  ITEM HISTORY")
    if #X_ItemHistory == 0 then
        addEmptyNote("No item history yet")
    else
        for i, id in ipairs(X_ItemHistory) do
            local idx = i
            addRow("ID: " .. id, T.bg3,
                function() Box.Text = id; switchTab("Changer") end,
                function()
                    table.remove(X_ItemHistory, idx)
                    SaveData(); rebuildLogs()
                end
            )
        end
    end

    -- Clear all buttons row
    order += 1
    local clearRow = Instance.new("Frame", pageLogs)
    clearRow.Size = UDim2.new(1, 0, 0, 36); clearRow.BackgroundColor3 = T.bg2
    clearRow.ZIndex = 12; clearRow.LayoutOrder = order; mkCorner(clearRow, 7); mkStroke(clearRow, T.border, 1)
    mkList(clearRow, Enum.FillDirection.Horizontal, 8)
    mkPad(clearRow, 8, 8, 5, 5)

    local function mkSmallClear(label, cb)
        local b = Instance.new("TextButton", clearRow)
        b.Size = UDim2.new(0.5, -4, 1, 0); b.BackgroundColor3 = Color3.fromRGB(120, 20, 30)
        b.Text = label; b.TextSize = 10; b.TextColor3 = T.white; b.Font = Enum.Font.GothamBold
        b.AutoButtonColor = false; mkCorner(b, 6)
        b.MouseButton1Click:Connect(function() if cb then cb() end end)
    end
    mkSmallClear("🗑 Clear History", function()
        X_History = {}; X_ItemHistory = {}; SaveData(); rebuildLogs()
    end)
    mkSmallClear("🗑 Clear Favorites", function()
        X_Favorites = {}; SaveData(); rebuildLogs()
    end)
end

-- ─────────────────────────────────────────
-- OPEN / CLOSE
-- ─────────────────────────────────────────
local function openWin()
    Win.Size = UDim2.new(0, 340, 0, 0)
    Win.Position = UDim2.new(0.5, -170, 0.5, 0)
    Shad.Size = UDim2.new(0, 360, 0, 0)
    Win.Visible = true; Shad.Visible = true; syncShad()
    tw(Win, {Size = UDim2.new(0, 340, 0, 520), Position = UDim2.new(0.5, -170, 0.5, -260)}, 0.22, Enum.EasingStyle.Back)
    tw(Shad, {Size = UDim2.new(0, 360, 0, 540)}, 0.2)
    StatusDot.BackgroundColor3 = T.green
    if activeTab == "" then switchTab("Changer") end
end

Icon.MouseButton1Click:Connect(function()
    if Win.Visible then
        tw(Win, {Size = UDim2.new(0, 340, 0, 0)}, 0.15)
        task.wait(0.17); Win.Visible = false; Shad.Visible = false
        Win.Size = UDim2.new(0, 340, 0, 520)
        StatusDot.BackgroundColor3 = T.red
    else
        openWin()
    end
end)

task.wait(0.5); openWin()
Notify("Avatar Changer loaded ✓")
