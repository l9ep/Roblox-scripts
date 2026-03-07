-- AVATAR CHANGER
-- V91: FULL UI OVERHAUL + FOV FIX + R6/R15 FIX + HISTORY UPDATE (XYTHC)

local X_Player = game:GetService("Players").LocalPlayer
local X_UIS = game:GetService("UserInputService")
local X_Players = game:GetService("Players")
local X_HttpService = game:GetService("HttpService")
local X_Tween = game:GetService("TweenService")
local X_Market = game:GetService("MarketplaceService")
local X_RunService = game:GetService("RunService")

local X_OriginalItems = {}
local X_CurrentItems = {}
local X_History, X_ItemHistory, X_Favorites, X_SavedOutfits = {}, {}, {}, {}
local X_KorbloxActive, X_HeadlessActive = false, false
local X_FOVFixActive = false
local X_FOVConnections = {}

-- DATA PERSISTENCE
local FILE_NAME = "AvatarChanger_Data_V91.json"
local function SaveData()
    local data = {H = X_History, IH = X_ItemHistory, F = X_Favorites, SO = X_SavedOutfits}
    pcall(function() if writefile then writefile(FILE_NAME, X_HttpService:JSONEncode(data)) end end)
end
local function LoadData()
    if isfile and isfile(FILE_NAME) then
        pcall(function()
            local ok, result = pcall(function() return X_HttpService:JSONDecode(readfile(FILE_NAME)) end)
            if ok and result then
                X_History = result.H or {}; X_ItemHistory = result.IH or {}; X_Favorites = result.F or {}; X_SavedOutfits = result.SO or {}
            end
        end)
    end
end
LoadData()

-- ================================
-- TWEEN HELPERS
-- ================================
local function TS(obj, goal, t, style, dir)
    local ti = TweenInfo.new(t or 0.25, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out)
    local tw = X_Tween:Create(obj, ti, goal)
    tw:Play()
    return tw
end

local function TSSpring(obj, goal, t)
    local ti = TweenInfo.new(t or 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    X_Tween:Create(obj, ti, goal):Play()
end

-- ================================
-- NOTIFICATION SYSTEM (improved)
-- ================================
local NotifyGui = Instance.new("ScreenGui", X_Player.PlayerGui)
NotifyGui.Name = "X_NotifyGui_V91"
NotifyGui.ResetOnSpawn = false
NotifyGui.DisplayOrder = 99

local notifyQueue = {}
local notifyActive = false

local function ProcessNotifyQueue()
    if notifyActive or #notifyQueue == 0 then return end
    notifyActive = true
    local msg, color = table.unpack(table.remove(notifyQueue, 1))
    color = color or Color3.fromRGB(85, 80, 255)

    local bg = Instance.new("Frame", NotifyGui)
    bg.Size = UDim2.new(0, 220, 0, 40)
    bg.Position = UDim2.new(1, 10, 1, -60)
    bg.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
    bg.BorderSizePixel = 0
    bg.ZIndex = 10
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", bg)
    stroke.Color = color
    stroke.Thickness = 1.5

    local bar = Instance.new("Frame", bg)
    bar.Size = UDim2.new(0, 4, 1, -8)
    bar.Position = UDim2.new(0, 6, 0, 4)
    bar.BackgroundColor3 = color
    bar.BorderSizePixel = 0
    bar.ZIndex = 11
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local lbl = Instance.new("TextLabel", bg)
    lbl.Size = UDim2.new(1, -22, 1, 0)
    lbl.Position = UDim2.new(0, 18, 0, 0)
    lbl.Text = msg
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 11

    bg:TweenPosition(UDim2.new(1, -235, 1, -60), "Out", "Back", 0.4, true)
    task.delay(2.8, function()
        TS(bg, {Position = UDim2.new(1, 10, 1, -60)}, 0.35)
        task.delay(0.4, function()
            bg:Destroy()
            notifyActive = false
            ProcessNotifyQueue()
        end)
    end)
end

local function Notify(msg, color)
    table.insert(notifyQueue, {msg, color})
    ProcessNotifyQueue()
end

-- ================================
-- FOV / FIRST PERSON FIX
-- ================================
local function GetAllCharacterItems(char)
    local items = {}
    for _, v in pairs(char:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("BodyColors") or v:IsA("CharacterMesh") then
            table.insert(items, v)
        end
    end
    return items
end

local function SetTransparencyForFOV(char, inFOV)
    if not char then return end
    -- In FOV mode, hide local arms so they don't show wrong avatar
    local armsToHide = {"RightHand", "LeftHand", "RightLowerArm", "LeftLowerArm", "RightUpperArm", "LeftUpperArm",
                        "Right Arm", "Left Arm"}
    for _, name in pairs(armsToHide) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            -- Store original transparency if not stored
            if not part:FindFirstChild("_OrigTrans") then
                local tag = Instance.new("NumberValue", part)
                tag.Name = "_OrigTrans"
                tag.Value = part.Transparency
            end
            if inFOV then
                part.Transparency = 1
            else
                local tag = part:FindFirstChild("_OrigTrans")
                part.Transparency = tag and tag.Value or 0
            end
        end
    end

    -- Also ensure accessories stay visible in FOV
    for _, v in pairs(char:GetChildren()) do
        if v:IsA("Accessory") then
            local handle = v:FindFirstChild("Handle")
            if handle then
                if inFOV then
                    handle.LocalTransparencyModifier = 0
                end
            end
        end
    end
end

local function StartFOVFix()
    -- Disconnect old
    for _, c in pairs(X_FOVConnections) do c:Disconnect() end
    X_FOVConnections = {}

    local camera = workspace.CurrentCamera
    local lastAngle = nil

    local conn = X_RunService.RenderStepped:Connect(function()
        local char = X_Player.Character
        if not char then return end
        if not camera then camera = workspace.CurrentCamera end

        local fovMode = camera.CameraType == Enum.CameraType.Custom and
                        (camera.CFrame.Position - (char:FindFirstChild("Head") and char.Head.Position or Vector3.new())).Magnitude < 1.5

        -- Alternative detection using zoom level approximation
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local inFOV = false

        if humanoid then
            -- Check if camera is very close to head (first person)
            local head = char:FindFirstChild("Head")
            if head then
                local dist = (camera.CFrame.Position - head.Position).Magnitude
                inFOV = dist < 1.2
            end
        end

        if inFOV ~= lastAngle then
            lastAngle = inFOV
            SetTransparencyForFOV(char, inFOV)

            -- Reapply all accessories/items to ensure nothing disappears
            if inFOV and #X_CurrentItems > 0 then
                task.spawn(function()
                    task.wait(0.05)
                    local currentChar = X_Player.Character
                    if not currentChar then return end
                    for _, item in pairs(X_CurrentItems) do
                        if item:IsA("Accessory") then
                            local existing = currentChar:FindFirstChild(item.Name)
                            if not existing then
                                X_Weld_Internal(item:Clone(), currentChar)
                            end
                        end
                    end
                end)
            end
        end
    end)
    table.insert(X_FOVConnections, conn)
end

-- ================================
-- WELDING
-- ================================
function X_Weld_Internal(acc, char)
    char = char or X_Player.Character
    local h = acc:FindFirstChild("Handle")
    if not char or not h then return end
    local att = h:FindFirstChildOfClass("Attachment")
    local tar = char:FindFirstChild(att and att.Name or "HatAttachment", true)
    acc.Parent = char
    if tar then
        local w = Instance.new("Weld", h)
        w.Part0 = h
        w.Part1 = tar.Parent
        w.C0 = att and att.CFrame or CFrame.new()
        w.C1 = tar.CFrame
    end
end

local function X_Weld(acc) X_Weld_Internal(acc, X_Player.Character) end

-- ================================
-- KORBLOX
-- ================================
local function ApplyKorblox(state)
    local char = X_Player.Character; if not char then return end
    for _, v in pairs(char:GetChildren()) do if v.Name == "VisualKorblox" then v:Destroy() end end
    if state then
        local fl = Instance.new("Part", char); fl.Name = "VisualKorblox"; fl.Size = Vector3.new(1,2,1); fl.CanCollide = false
        local m = Instance.new("SpecialMesh", fl); m.MeshId = "rbxassetid://902942096"; m.TextureId = "rbxassetid://902843398"; m.Scale = Vector3.new(1.2,1.2,1.2)
        local leg = char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg")
        if leg then
            local w = Instance.new("Weld", fl); w.Part0 = leg; w.Part1 = fl
            w.C0 = (leg.Name == "Right Leg") and CFrame.new(0, 0.6, -0.1) or CFrame.new(0, 0.15, 0)
        end
        for _, p in pairs({"RightUpperLeg","RightLowerLeg","RightFoot","Right Leg"}) do
            if char:FindFirstChild(p) then char[p].Transparency = 1 end
        end
    else
        for _, p in pairs({"RightUpperLeg","RightLowerLeg","RightFoot","Right Leg"}) do
            if char:FindFirstChild(p) then char[p].Transparency = 0 end
        end
    end
end

-- ================================
-- CLASSIC CLOTHING TEMPLATE
-- ================================
local function GetActualTemplate(id)
    local success, asset = pcall(function() return game:GetObjects("rbxassetid://" .. id)[1] end)
    if success and asset then
        local tid = ""
        if asset:IsA("Shirt") then tid = asset.ShirtTemplate
        elseif asset:IsA("Pants") then tid = asset.PantsTemplate
        elseif asset:IsA("ShirtGraphic") then tid = asset.Graphic end
        asset:Destroy()
        return tid ~= "" and tid or "rbxassetid://"..id
    end
    return "rbxassetid://"..id
end

-- ================================
-- BODY / FACE INJECTOR
-- ================================
local function InjectCustomPart(id)
    local char = X_Player.Character; if not char then return end
    local cleanID = tostring(id):match("%d+")
    local s, info = pcall(function() return X_Market:GetProductInfo(tonumber(cleanID)) end)
    if s and info then
        if info.AssetTypeId == 1 or info.AssetTypeId == 13 then
            local head = char:FindFirstChild("Head")
            if head then
                local face = head:FindFirstChild("face") or Instance.new("Decal", head)
                face.Name = "face"; face.Texture = "rbxassetid://"..cleanID
                Notify("✦ Face Applied", Color3.fromRGB(0, 200, 180))
            end
        elseif info.AssetTypeId == 17 or info.AssetTypeId == 24 then
            local head = char:FindFirstChild("Head")
            if head then
                local m = head:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh", head)
                m.MeshId = "rbxassetid://"..cleanID
                Notify("✦ Head Applied", Color3.fromRGB(0, 200, 180))
            end
        elseif info.AssetTypeId >= 27 and info.AssetTypeId <= 31 then
            local s2, asset = pcall(function() return game:GetObjects("rbxassetid://"..cleanID)[1] end)
            if s2 and asset then asset.Parent = char; Notify("✦ Body Part Applied", Color3.fromRGB(0, 200, 180)) end
        else return false end
        return true
    end
    return false
end

-- ================================
-- WEAR ITEM
-- ================================
local function WearItem(id)
    local char = X_Player.Character; if not char then return end
    local s, info = pcall(function() return X_Market:GetProductInfo(tonumber(id)) end)
    if s and info then
        if info.AssetTypeId == 11 then
            local shirt = char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt", char)
            shirt.ShirtTemplate = GetActualTemplate(id)
            Notify("✦ Shirt Applied", Color3.fromRGB(85, 80, 255)); return true
        elseif info.AssetTypeId == 12 then
            local pants = char:FindFirstChildOfClass("Pants") or Instance.new("Pants", char)
            pants.PantsTemplate = GetActualTemplate(id)
            Notify("✦ Pants Applied", Color3.fromRGB(85, 80, 255)); return true
        end
    end
    local s2, asset = pcall(function() return game:GetObjects("rbxassetid://"..id)[1] end)
    if s2 and asset then
        if asset:IsA("Accessory") then X_Weld(asset)
        else asset.Parent = char end
        Notify("✦ Item Added", Color3.fromRGB(85, 80, 255)); return true
    end
    return false
end

-- ================================
-- R6 / R15 COMPATIBILITY FIX
-- ================================
local function DetectRigType(char)
    if char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("UpperTorso") then return "R15" end
    if char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Torso") then return "R6" end
    return "Unknown"
end

local function ConvertR6toR15Parts(items, charRig)
    -- If char is R15 but items come from R6, adapt CharacterMesh objects safely
    local filtered = {}
    for _, item in pairs(items) do
        if item:IsA("CharacterMesh") then
            if charRig == "R15" then
                -- CharacterMesh is R6-only, skip to avoid glitch; apply meshes manually if possible
                -- Try to map body part visuals
                local s, asset = pcall(function() return game:GetObjects("rbxassetid://"..item.MeshId)[1] end)
                if s and asset and asset:IsA("Accessory") then
                    table.insert(filtered, asset)
                end
                -- Skip unsupported CharacterMesh on R15
            else
                table.insert(filtered, item)
            end
        else
            table.insert(filtered, item)
        end
    end
    return filtered
end

-- ================================
-- FINAL APPLY (with R6/R15 fix)
-- ================================
local function FinalApply(items, isReset)
    local char = X_Player.Character; if not char then return end
    local head = char:FindFirstChild("Head")
    local charRig = DetectRigType(char)
    local isR15Source = false
    local hasHeadMesh = false

    for _, item in pairs(items) do
        if item.Name:find("Upper") or item.Name:find("Lower") or item.Name:find("Hand") or item.Name:find("Foot") then
            isR15Source = true
        end
        if item:IsA("SpecialMesh") and (item.MeshType == Enum.MeshType.Head or item.MeshId ~= "") then
            hasHeadMesh = true
        end
    end

    -- Rig compatibility: if R6 source on R15 body (or vice versa), auto-adapt
    local adaptedItems = ConvertR6toR15Parts(items, charRig)

    -- Clean existing cosmetics
    for _, v in pairs(char:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Clothing") or v:IsA("BodyColors") or v:IsA("CharacterMesh") then
            v:Destroy()
        elseif v:IsA("BasePart") and (v.Name:find("Leg") or v.Name:find("Arm")) then
            v.Transparency = 0
        end
    end

    -- Reset head
    if head then
        head.Transparency = 0
        head.Size = Vector3.new(2, 1, 1)
        for _, v in pairs(head:GetChildren()) do
            if v:IsA("Decal") or v:IsA("SpecialMesh") then v:Destroy() end
        end
    end

    -- Apply items
    for _, item in pairs(adaptedItems) do
        if item:IsA("Accessory") then
            X_Weld(item:Clone())
        elseif item:IsA("Clothing") or item:IsA("BodyColors") then
            -- Only apply clothing if rig type matches or it's universal
            item:Clone().Parent = char
        elseif item:IsA("CharacterMesh") then
            if charRig == "R6" then item:Clone().Parent = char end
        elseif item:IsA("SpecialMesh") and head then
            item:Clone().Parent = head
        elseif item:IsA("Decal") and item.Name == "face" and head then
            item:Clone().Parent = head
        end
    end

    -- Headless / head visibility
    if head then
        local forceHeadless = (isR15Source and not hasHeadMesh and not isReset)
        local hideHead = X_HeadlessActive or forceHeadless
        head.Transparency = hideHead and 1 or 0
        if head:FindFirstChild("face") then
            head.face.Transparency = hideHead and 1 or 0
        end
        if isReset and not head:FindFirstChildOfClass("SpecialMesh") then
            local m = Instance.new("SpecialMesh", head)
            m.MeshType = Enum.MeshType.Head
            m.Scale = Vector3.new(1.25, 1.25, 1.25)
        end
    end

    -- Arm fix for R15 on R6 avatar
    if charRig == "R15" and not isR15Source and not isReset then
        for _, armName in pairs({"RightUpperArm","LeftUpperArm","RightLowerArm","LeftLowerArm","RightHand","LeftHand"}) do
            local part = char:FindFirstChild(armName)
            if part then part.Transparency = 0 end
        end
    end

    ApplyKorblox(X_KorbloxActive or (isR15Source and not isReset))
    X_CurrentItems = adaptedItems

    -- Re-enable FOV fix after apply
    task.spawn(StartFOVFix)

    Notify(isReset and "✦ Avatar Reset" or "✦ Avatar Changed", isReset and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(85, 80, 255))
end

-- ================================
-- UI CONSTRUCTION
-- ================================
local COLORS = {
    BG       = Color3.fromRGB(14, 15, 26),
    PANEL    = Color3.fromRGB(20, 22, 36),
    CARD     = Color3.fromRGB(26, 28, 44),
    ACCENT   = Color3.fromRGB(100, 90, 255),
    ACCENT2  = Color3.fromRGB(60, 200, 160),
    RED      = Color3.fromRGB(210, 50, 70),
    GOLD     = Color3.fromRGB(220, 165, 0),
    TEXT     = Color3.new(1, 1, 1),
    SUBTEXT  = Color3.fromRGB(130, 130, 160),
    STROKE   = Color3.fromRGB(45, 48, 72),
}

local X_Gui = Instance.new("ScreenGui", X_Player.PlayerGui)
X_Gui.Name = "AvatarChangerV91"
X_Gui.ResetOnSpawn = false
X_Gui.DisplayOrder = 10

-- Main window
local Main = Instance.new("Frame", X_Gui)
Main.Name = "Main"
Main.Size = UDim2.new(0, 260, 0, 490)
Main.Position = UDim2.new(0.5, -130, 0.5, -245)
Main.BackgroundColor3 = COLORS.BG
Main.Active = true
Main.ClipsDescendants = true
Main.Visible = false
Main.BackgroundTransparency = 0.04
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)
local mainStroke = Instance.new("UIStroke", Main)
mainStroke.Color = COLORS.STROKE
mainStroke.Thickness = 1.2

-- Gradient top accent line
local topAccent = Instance.new("Frame", Main)
topAccent.Size = UDim2.new(1, 0, 0, 3)
topAccent.BackgroundColor3 = COLORS.ACCENT
topAccent.BorderSizePixel = 0
topAccent.ZIndex = 5
local tAG = Instance.new("UIGradient", topAccent)
tAG.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COLORS.ACCENT),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 80, 255)),
    ColorSequenceKeypoint.new(1, COLORS.ACCENT2)
})

-- Top bar
local Top = Instance.new("Frame", Main)
Top.Size = UDim2.new(1, 0, 0, 40)
Top.Position = UDim2.new(0, 0, 0, 3)
Top.BackgroundTransparency = 1
Top.ZIndex = 4

local TitleLabel = Instance.new("TextLabel", Top)
TitleLabel.Size = UDim2.new(0, 160, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.Text = "AVATAR CHANGER"
TitleLabel.TextColor3 = COLORS.TEXT
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 12
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 4

local VerLabel = Instance.new("TextLabel", Top)
VerLabel.Size = UDim2.new(0, 40, 0, 14)
VerLabel.Position = UDim2.new(0, 14, 0, 24)
VerLabel.Text = "V91"
VerLabel.TextColor3 = COLORS.ACCENT
VerLabel.Font = Enum.Font.GothamBold
VerLabel.TextSize = 9
VerLabel.BackgroundTransparency = 1
VerLabel.TextXAlignment = Enum.TextXAlignment.Left
VerLabel.ZIndex = 4

local ByLabel = Instance.new("TextLabel", Top)
ByLabel.Size = UDim2.new(0, 80, 0, 14)
ByLabel.Position = UDim2.new(0, 34, 0, 24)
ByLabel.Text = "by XYTHC"
ByLabel.TextColor3 = COLORS.SUBTEXT
ByLabel.Font = Enum.Font.Gotham
ByLabel.TextSize = 9
ByLabel.BackgroundTransparency = 1
ByLabel.TextXAlignment = Enum.TextXAlignment.Left
ByLabel.ZIndex = 4

-- Close button
local CloseBtn = Instance.new("TextButton", Top)
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -36, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 40)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11
CloseBtn.ZIndex = 5
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

-- Tab buttons
local TabFrame = Instance.new("Frame", Main)
TabFrame.Size = UDim2.new(1, -20, 0, 32)
TabFrame.Position = UDim2.new(0, 10, 0, 48)
TabFrame.BackgroundTransparency = 1
TabFrame.ZIndex = 3

local function MakeTab(text, xPos, active)
    local btn = Instance.new("TextButton", TabFrame)
    btn.Size = UDim2.new(0.5, -4, 1, 0)
    btn.Position = UDim2.new(xPos, xPos == 0 and 0 or 8, 0, 0)
    btn.BackgroundColor3 = active and COLORS.ACCENT or COLORS.CARD
    btn.Text = text
    btn.TextColor3 = active and COLORS.TEXT or COLORS.SUBTEXT
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.ZIndex = 3
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    return btn
end

local btnChanger = MakeTab("⚡ CHANGER", 0, true)
local btnLog = MakeTab("📋 HISTORY", 0.5, false)

-- Content area
local ContentArea = Instance.new("Frame", Main)
ContentArea.Size = UDim2.new(1, 0, 1, -88)
ContentArea.Position = UDim2.new(0, 0, 0, 88)
ContentArea.BackgroundTransparency = 1
ContentArea.ClipsDescendants = true

-- Page: Changer
local PageChanger = Instance.new("ScrollingFrame", ContentArea)
PageChanger.Size = UDim2.new(1, 0, 1, 0)
PageChanger.BackgroundTransparency = 1
PageChanger.ScrollBarThickness = 3
PageChanger.ScrollBarImageColor3 = COLORS.ACCENT
PageChanger.CanvasSize = UDim2.new(0, 0, 0, 600)
PageChanger.Visible = true
PageChanger.BorderSizePixel = 0

-- Page: Logs
local PageLog = Instance.new("ScrollingFrame", ContentArea)
PageLog.Size = UDim2.new(1, 0, 1, 0)
PageLog.BackgroundTransparency = 1
PageLog.ScrollBarThickness = 3
PageLog.ScrollBarImageColor3 = COLORS.ACCENT
PageLog.Visible = false
PageLog.BorderSizePixel = 0

-- ================================
-- UI COMPONENTS
-- ================================

-- Input Box
local BoxBG = Instance.new("Frame", PageChanger)
BoxBG.Size = UDim2.new(1, -20, 0, 36)
BoxBG.Position = UDim2.new(0, 10, 0, 8)
BoxBG.BackgroundColor3 = COLORS.CARD
BoxBG.ZIndex = 3
Instance.new("UICorner", BoxBG).CornerRadius = UDim.new(0, 10)
local boxStroke = Instance.new("UIStroke", BoxBG)
boxStroke.Color = COLORS.STROKE
boxStroke.Thickness = 1

local BoxIcon = Instance.new("TextLabel", BoxBG)
BoxIcon.Size = UDim2.new(0, 30, 1, 0)
BoxIcon.Text = "🔍"
BoxIcon.BackgroundTransparency = 1
BoxIcon.TextSize = 13
BoxIcon.ZIndex = 4
BoxIcon.Font = Enum.Font.Gotham

local Box = Instance.new("TextBox", BoxBG)
Box.Size = UDim2.new(1, -38, 1, 0)
Box.Position = UDim2.new(0, 30, 0, 0)
Box.BackgroundTransparency = 1
Box.TextColor3 = COLORS.TEXT
Box.PlaceholderText = "Username / Item ID / URL..."
Box.PlaceholderColor3 = COLORS.SUBTEXT
Box.Text = ""
Box.Font = Enum.Font.Gotham
Box.TextSize = 11
Box.ZIndex = 4
Box.ClearTextOnFocus = false

-- Focus glow on box
Box.Focused:Connect(function()
    TS(boxStroke, {Color = COLORS.ACCENT, Thickness = 1.5}, 0.2)
end)
Box.FocusLost:Connect(function()
    TS(boxStroke, {Color = COLORS.STROKE, Thickness = 1}, 0.2)
end)

-- Button factory
local btnY = 54
local function MakeButton(text, color, icon)
    local card = Instance.new("Frame", PageChanger)
    card.Size = UDim2.new(1, -20, 0, 36)
    card.Position = UDim2.new(0, 10, 0, btnY)
    card.BackgroundColor3 = color
    card.ZIndex = 3
    card.BackgroundTransparency = 0.1
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    btnY = btnY + 42

    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.TextColor3 = COLORS.TEXT
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Text = (icon and (icon .. "  ") or "") .. text
    btn.ZIndex = 4

    -- Hover/press animations
    btn.MouseEnter:Connect(function()
        TS(card, {BackgroundTransparency = 0}, 0.15)
        TSSpring(card, {Size = UDim2.new(1, -16, 0, 36)}, 0.2)
        card.Position = UDim2.new(0, 8, card.Position.Y.Scale, card.Position.Y.Offset)
    end)
    btn.MouseLeave:Connect(function()
        TS(card, {BackgroundTransparency = 0.1}, 0.15)
        TSSpring(card, {Size = UDim2.new(1, -20, 0, 36)}, 0.2)
        card.Position = UDim2.new(0, 10, card.Position.Y.Scale, card.Position.Y.Offset)
    end)
    btn.MouseButton1Down:Connect(function()
        TS(card, {BackgroundTransparency = 0.3}, 0.1)
        TS(card, {Size = UDim2.new(1, -24, 0, 33)}, 0.1)
    end)
    btn.MouseButton1Up:Connect(function()
        TS(card, {BackgroundTransparency = 0, Size = UDim2.new(1, -16, 0, 36)}, 0.2)
    end)

    return btn, card
end

-- Separator label
local function MakeSep(text, y)
    local sep = Instance.new("TextLabel", PageChanger)
    sep.Size = UDim2.new(1, -20, 0, 16)
    sep.Position = UDim2.new(0, 10, 0, y or btnY)
    sep.BackgroundTransparency = 1
    sep.TextColor3 = COLORS.SUBTEXT
    sep.Font = Enum.Font.GothamBold
    sep.TextSize = 9
    sep.Text = "── " .. text .. " ──"
    sep.ZIndex = 3
    if not y then btnY = btnY + 20 end
end

MakeSep("AVATAR")
local btnChange, _  = MakeButton("CHANGE AVATAR", COLORS.ACCENT, "👤")
local btnWear, _    = MakeButton("WEAR ITEM / ID", Color3.fromRGB(40, 120, 220), "🧢")
local btnInject, _  = MakeButton("INJECT BODY / FACE", Color3.fromRGB(0, 160, 180), "💉")

MakeSep("TOGGLES")
local btnKorblox, cardKorblox = MakeButton("KORBLOX: OFF", COLORS.CARD, "🦾")
local btnHeadless, cardHeadless = MakeButton("HEADLESS: OFF", COLORS.CARD, "💀")

MakeSep("MANAGE")
local btnFav, _     = MakeButton("ADD TO FAVORITES", Color3.fromRGB(160, 110, 0), "⭐")
local btnSave, _    = MakeButton("SAVE OUTFIT", Color3.fromRGB(0, 140, 90), "💾")
local btnReset, _   = MakeButton("RESET AVATAR", COLORS.RED, "🔄")

PageChanger.CanvasSize = UDim2.new(0, 0, 0, btnY + 20)

-- ================================
-- TOGGLE BUTTONS (Korblox / Headless)
-- ================================
local korbloxOn = false
local headlessOn = false

btnKorblox.MouseButton1Click:Connect(function()
    korbloxOn = not korbloxOn
    X_KorbloxActive = korbloxOn
    btnKorblox.Text = "🦾  KORBLOX: " .. (korbloxOn and "ON" or "OFF")
    TS(cardKorblox, {BackgroundColor3 = korbloxOn and COLORS.ACCENT or COLORS.CARD, BackgroundTransparency = 0.1}, 0.2)
    ApplyKorblox(korbloxOn)
end)

btnHeadless.MouseButton1Click:Connect(function()
    headlessOn = not headlessOn
    X_HeadlessActive = headlessOn
    btnHeadless.Text = "💀  HEADLESS: " .. (headlessOn and "ON" or "OFF")
    TS(cardHeadless, {BackgroundColor3 = headlessOn and Color3.fromRGB(60, 60, 80) or COLORS.CARD, BackgroundTransparency = 0.1}, 0.2)
    local h = X_Player.Character and X_Player.Character:FindFirstChild("Head")
    if h then h.Transparency = headlessOn and 1 or 0 end
end)

-- ================================
-- MAIN BUTTON ACTIONS
-- ================================
btnChange.MouseButton1Click:Connect(function()
    local input = Box.Text
    local cleanID = input:match("%d+")

    -- If short numeric ID, try as item first
    if cleanID and #input < 15 then
        if WearItem(cleanID) then return end
    end

    local s, id = pcall(function() return X_Players:GetUserIdFromNameAsync(input) end)
    if not s then id = tonumber(cleanID) end
    if not id then Notify("✕ Invalid Input", COLORS.RED); return end

    -- Save to history with timestamp
    local entry = {name = input, time = os.time()}
    if not table.find(X_History, input) then table.insert(X_History, 1, entry); if #X_History > 30 then table.remove(X_History) end; SaveData() end

    local model = X_Players:CreateHumanoidModelFromUserId(id)
    local items = {}
    for _, v in pairs(model:GetChildren()) do
        if not v:IsA("Humanoid") then
            if v:IsA("BasePart") and (v.Name:find("Leg") or v.Name == "Head") then
                local m = v:FindFirstChildOfClass("SpecialMesh")
                if m then table.insert(items, m:Clone()) end
            end
            table.insert(items, v:Clone())
        end
    end
    FinalApply(items, false)
    model:Destroy()
end)

btnWear.MouseButton1Click:Connect(function()
    local cleanID = Box.Text:match("%d+"); if not cleanID then Notify("✕ No ID Found", COLORS.RED); return end
    if WearItem(cleanID) then
        if not table.find(X_ItemHistory, cleanID) then
            table.insert(X_ItemHistory, 1, {id = cleanID, time = os.time()})
            if #X_ItemHistory > 30 then table.remove(X_ItemHistory) end
            SaveData()
        end
    end
end)

btnInject.MouseButton1Click:Connect(function()
    local cleanID = Box.Text:match("%d+"); if not cleanID then Notify("✕ No ID Found", COLORS.RED); return end
    InjectCustomPart(cleanID)
end)

btnFav.MouseButton1Click:Connect(function()
    if Box.Text ~= "" and not table.find(X_Favorites, Box.Text) then
        table.insert(X_Favorites, Box.Text)
        SaveData()
        Notify("⭐ Added to Favorites", COLORS.GOLD)
    end
end)

btnSave.MouseButton1Click:Connect(function()
    local name = Box.Text ~= "" and Box.Text or "Outfit " .. (#X_SavedOutfits + 1)
    X_SavedOutfits[name] = X_CurrentItems
    SaveData()
    Notify("💾 Outfit Saved: " .. name, COLORS.ACCENT2)
end)

btnReset.MouseButton1Click:Connect(function()
    X_KorbloxActive, X_HeadlessActive, korbloxOn, headlessOn = false, false, false, false
    btnKorblox.Text = "🦾  KORBLOX: OFF"
    btnHeadless.Text = "💀  HEADLESS: OFF"
    TS(cardKorblox, {BackgroundColor3 = COLORS.CARD}, 0.2)
    TS(cardHeadless, {BackgroundColor3 = COLORS.CARD}, 0.2)
    FinalApply(X_OriginalItems, true)
end)

-- ================================
-- LOGS / HISTORY PAGE (upgraded)
-- ================================
local function MakeLogEntry(text, color, parent, onClick)
    local card = Instance.new("Frame", parent)
    card.Size = UDim2.new(1, -20, 0, 34)
    card.BackgroundColor3 = color or COLORS.CARD
    card.ZIndex = 3
    card.BackgroundTransparency = 0.1
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 9)

    local lbl = Instance.new("TextButton", card)
    lbl.Size = UDim2.new(1, -10, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = COLORS.TEXT
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 10
    lbl.Text = text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 4

    if onClick then
        lbl.MouseButton1Click:Connect(onClick)
        lbl.MouseEnter:Connect(function() TS(card, {BackgroundTransparency = 0}, 0.1) end)
        lbl.MouseLeave:Connect(function() TS(card, {BackgroundTransparency = 0.1}, 0.1) end)
    end
    return card
end

local function MakeSectionHeader(text, parent)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = COLORS.ACCENT
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.Text = text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 3
    return lbl
end

local function RefreshLogs()
    for _, v in pairs(PageLog:GetChildren()) do
        if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then v:Destroy() end
    end

    local layout = Instance.new("UIListLayout", PageLog)
    layout.Padding = UDim.new(0, 5)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local pad = Instance.new("UIPadding", PageLog)
    pad.PaddingTop = UDim.new(0, 8)

    -- Saved Outfits
    if next(X_SavedOutfits) then
        local h = MakeSectionHeader("💾  SAVED OUTFITS", PageLog)
        h.LayoutOrder = 1
        local i = 2
        for name, items in pairs(X_SavedOutfits) do
            local c = MakeLogEntry(name, COLORS.ACCENT2, PageLog, function()
                FinalApply(items, false)
                Notify("💾 Loaded: " .. name, COLORS.ACCENT2)
            end)
            c.LayoutOrder = i; i = i + 1

            -- Delete button
            local del = Instance.new("TextButton", c)
            del.Size = UDim2.new(0, 22, 0, 22)
            del.Position = UDim2.new(1, -28, 0.5, -11)
            del.BackgroundColor3 = COLORS.RED
            del.Text = "✕"
            del.TextColor3 = Color3.new(1,1,1)
            del.Font = Enum.Font.GothamBold
            del.TextSize = 9
            del.ZIndex = 5
            Instance.new("UICorner", del).CornerRadius = UDim.new(0, 6)
            del.MouseButton1Click:Connect(function()
                X_SavedOutfits[name] = nil; SaveData(); RefreshLogs()
            end)
        end
    end

    -- Favorites
    if #X_Favorites > 0 then
        local h = MakeSectionHeader("⭐  FAVORITES", PageLog)
        h.LayoutOrder = 50
        for idx, fav in ipairs(X_Favorites) do
            local c = MakeLogEntry(fav, Color3.fromRGB(100, 75, 10), PageLog, function()
                Box.Text = fav
                PageLog.Visible = false
                PageChanger.Visible = true
                TS(btnChanger, {BackgroundColor3 = COLORS.ACCENT}, 0.2)
                TS(btnLog, {BackgroundColor3 = COLORS.CARD}, 0.2)
            end)
            c.LayoutOrder = 51 + idx

            local del = Instance.new("TextButton", c)
            del.Size = UDim2.new(0, 22, 0, 22)
            del.Position = UDim2.new(1, -28, 0.5, -11)
            del.BackgroundColor3 = COLORS.RED
            del.Text = "✕"
            del.TextColor3 = Color3.new(1,1,1)
            del.Font = Enum.Font.GothamBold
            del.TextSize = 9
            del.ZIndex = 5
            Instance.new("UICorner", del).CornerRadius = UDim.new(0, 6)
            del.MouseButton1Click:Connect(function()
                table.remove(X_Favorites, idx); SaveData(); RefreshLogs()
            end)
        end
    end

    -- Avatar history
    if #X_History > 0 then
        local h = MakeSectionHeader("👤  AVATAR HISTORY", PageLog)
        h.LayoutOrder = 100
        for idx, entry in ipairs(X_History) do
            local name = type(entry) == "table" and entry.name or tostring(entry)
            local timeStr = ""
            if type(entry) == "table" and entry.time then
                local delta = os.time() - entry.time
                if delta < 60 then timeStr = " (" .. delta .. "s ago)"
                elseif delta < 3600 then timeStr = " (" .. math.floor(delta/60) .. "m ago)"
                else timeStr = " (" .. math.floor(delta/3600) .. "h ago)" end
            end
            local c = MakeLogEntry(name .. timeStr, COLORS.CARD, PageLog, function()
                Box.Text = name
                PageLog.Visible = false
                PageChanger.Visible = true
                TS(btnChanger, {BackgroundColor3 = COLORS.ACCENT}, 0.2)
                TS(btnLog, {BackgroundColor3 = COLORS.CARD}, 0.2)
            end)
            c.LayoutOrder = 101 + idx
        end
    end

    -- Item history
    if #X_ItemHistory > 0 then
        local h = MakeSectionHeader("🧢  ITEM HISTORY", PageLog)
        h.LayoutOrder = 200
        for idx, entry in ipairs(X_ItemHistory) do
            local id = type(entry) == "table" and entry.id or tostring(entry)
            local c = MakeLogEntry("ID: " .. id, COLORS.CARD, PageLog, function()
                Box.Text = id
                PageLog.Visible = false
                PageChanger.Visible = true
                TS(btnChanger, {BackgroundColor3 = COLORS.ACCENT}, 0.2)
                TS(btnLog, {BackgroundColor3 = COLORS.CARD}, 0.2)
            end)
            c.LayoutOrder = 201 + idx
        end
    end

    if #X_History == 0 and #X_ItemHistory == 0 and #X_Favorites == 0 and not next(X_SavedOutfits) then
        local empty = Instance.new("TextLabel", PageLog)
        empty.Size = UDim2.new(1, 0, 0, 50)
        empty.BackgroundTransparency = 1
        empty.TextColor3 = COLORS.SUBTEXT
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 11
        empty.Text = "No history yet!"
        empty.LayoutOrder = 1
        empty.ZIndex = 3
    end

    task.wait()
    PageLog.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
end

-- ================================
-- TAB SWITCHING WITH ANIMATION
-- ================================
btnLog.MouseButton1Click:Connect(function()
    PageChanger.Visible = false
    PageLog.Visible = true
    RefreshLogs()
    TS(btnLog, {BackgroundColor3 = COLORS.ACCENT}, 0.2)
    TS(btnChanger, {BackgroundColor3 = COLORS.CARD}, 0.2)
    btnLog.TextColor3 = COLORS.TEXT
    btnChanger.TextColor3 = COLORS.SUBTEXT
end)

btnChanger.MouseButton1Click:Connect(function()
    PageLog.Visible = false
    PageChanger.Visible = true
    TS(btnChanger, {BackgroundColor3 = COLORS.ACCENT}, 0.2)
    TS(btnLog, {BackgroundColor3 = COLORS.CARD}, 0.2)
    btnChanger.TextColor3 = COLORS.TEXT
    btnLog.TextColor3 = COLORS.SUBTEXT
end)

-- ================================
-- TOGGLE ICON (floating button)
-- ================================
local X_Icon = Instance.new("TextButton", X_Gui)
X_Icon.Size = UDim2.new(0, 48, 0, 48)
X_Icon.Position = UDim2.new(0, 12, 0, 12)
X_Icon.BackgroundColor3 = COLORS.PANEL
X_Icon.Text = ""
X_Icon.ZIndex = 5
Instance.new("UICorner", X_Icon).CornerRadius = UDim.new(0, 12)
local iconStroke = Instance.new("UIStroke", X_Icon)
iconStroke.Color = COLORS.STROKE
iconStroke.Thickness = 1.2

local iconGrad = Instance.new("UIGradient", X_Icon)
iconGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COLORS.ACCENT),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 200, 160))
})
iconGrad.Rotation = 45

local iconLabel = Instance.new("TextLabel", X_Icon)
iconLabel.Size = UDim2.new(1, 0, 0.6, 0)
iconLabel.Position = UDim2.new(0, 0, 0.1, 0)
iconLabel.Text = "👤"
iconLabel.TextSize = 18
iconLabel.BackgroundTransparency = 1
iconLabel.ZIndex = 6
iconLabel.Font = Enum.Font.Gotham

local StatusDot = Instance.new("Frame", X_Icon)
StatusDot.Size = UDim2.new(0, 10, 0, 10)
StatusDot.Position = UDim2.new(1, -12, 0, 2)
StatusDot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
StatusDot.ZIndex = 7
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

X_Icon.MouseEnter:Connect(function()
    TSSpring(X_Icon, {Size = UDim2.new(0, 52, 0, 52), Position = UDim2.new(0, 10, 0, 10)}, 0.25)
end)
X_Icon.MouseLeave:Connect(function()
    TSSpring(X_Icon, {Size = UDim2.new(0, 48, 0, 48), Position = UDim2.new(0, 12, 0, 12)}, 0.25)
end)

X_Icon.MouseButton1Click:Connect(function()
    if not Main.Visible then
        Main.Size = UDim2.new(0, 0, 0, 0)
        Main.Position = UDim2.new(0.5, 0, 0.5, 0)
        Main.Visible = true
        TSSpring(Main, {Size = UDim2.new(0, 260, 0, 490), Position = UDim2.new(0.5, -130, 0.5, -245)}, 0.4)
    else
        TS(Main, {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.25)
        task.delay(0.26, function() Main.Visible = false end)
    end
    StatusDot.BackgroundColor3 = Main.Visible and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(255, 60, 60)
end)

CloseBtn.MouseButton1Click:Connect(function()
    TS(Main, {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.25)
    task.delay(0.26, function() Main.Visible = false end)
    StatusDot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
end)

-- ================================
-- DRAGGING
-- ================================
local function Drg(o, h)
    local dragging, dragInput, startPos, startObjPos
    h.InputBegan:Connect(function(x)
        if x.UserInputType == Enum.UserInputType.MouseButton1 or x.UserInputType == Enum.UserInputType.Touch then
            dragging = true; startPos = x.Position; startObjPos = o.Position
            x.Changed:Connect(function()
                if x.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    h.InputChanged:Connect(function(x)
        if x.UserInputType == Enum.UserInputType.MouseMovement or x.UserInputType == Enum.UserInputType.Touch then
            dragInput = x
        end
    end)
    X_UIS.InputChanged:Connect(function(x)
        if x == dragInput and dragging then
            local delta = x.Position - startPos
            o.Position = UDim2.new(startObjPos.X.Scale, startObjPos.X.Offset + delta.X,
                                   startObjPos.Y.Scale, startObjPos.Y.Offset + delta.Y)
        end
    end)
end

Drg(Main, Top)
Drg(X_Icon, X_Icon)

-- ================================
-- CHARACTER RESPAWN HANDLING
-- ================================
X_Player.CharacterAdded:Connect(function(char)
    task.wait(0.6)
    if #X_CurrentItems > 0 then
        FinalApply(X_CurrentItems, false)
    end
    -- Restart FOV fix on new char
    task.spawn(StartFOVFix)
end)

-- ================================
-- INIT: Store original items
-- ================================
local char = X_Player.Character or X_Player.CharacterAdded:Wait()
for _, v in pairs(char:GetChildren()) do
    if not v:IsA("Humanoid") and not v:IsA("Script") then
        table.insert(X_OriginalItems, v:Clone())
    end
end
if char:FindFirstChild("Head") then
    for _, v in pairs(char.Head:GetChildren()) do
        table.insert(X_OriginalItems, v:Clone())
    end
end

-- Start FOV fix immediately
task.spawn(StartFOVFix)

Notify("✦ Avatar Changer V91 Ready", COLORS.ACCENT)
