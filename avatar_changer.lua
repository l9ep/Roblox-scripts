--[[
    Avatar Changer V99
    by XYTHC

    Changes:
    - Headless/Korblox now re-enforced in a loop after apply so
      ApplyDescription can never overwrite them no matter how long it takes
    - Reset no longer copies face from original items (fixes face bleed on R6)
    - Reset restores the proper default Roblox face texture instead
    - Code rewritten in a clean, readable style
--]]

-- Services
local Players         = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService      = game:GetService("RunService")
local HttpService     = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- Default Roblox face texture (used on reset)
local DEFAULT_FACE = "rbxasset://textures/face.png"

-- Session state
local originalHDesc  = nil   -- HumanoidDescription captured at load
local currentHDesc   = nil   -- last applied HumanoidDescription
local originalItems  = {}    -- cosmetics captured at load (manual mode fallback)
local currentItems   = {}    -- last applied items (for respawn re-apply)
local useManualMode  = false -- becomes true if ApplyDescription is blocked
local korbloxEnabled = false
local headlessEnabled = false
local fovConnections = {}

-- Persistent data (saved outfits stay in memory only — HDesc isn't serialisable)
local avatarHistory  = {}
local itemHistory    = {}
local favorites      = {}
local savedOutfits   = {}  -- [name] = { hDesc = ..., items = ... }

-- ============================================================
-- File persistence
-- ============================================================

local SAVE_FILE = "AvatarChangerV98.json"

local function saveData()
    pcall(function()
        if writefile then
            local data = {
                H  = avatarHistory,
                IH = itemHistory,
                F  = favorites,
            }
            writefile(SAVE_FILE, HttpService:JSONEncode(data))
        end
    end)
end

local function loadData()
    pcall(function()
        if isfile and isfile(SAVE_FILE) then
            local ok, result = pcall(function()
                return HttpService:JSONDecode(readfile(SAVE_FILE))
            end)
            if ok and result then
                avatarHistory = result.H  or {}
                itemHistory   = result.IH or {}
                favorites     = result.F  or {}
            end
        end
    end)
end

loadData()

-- ============================================================
-- Tween helpers
-- ============================================================

local function tween(obj, props, duration, style, direction)
    local info = TweenInfo.new(
        duration   or 0.2,
        style      or Enum.EasingStyle.Quart,
        direction  or Enum.EasingDirection.Out
    )
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function tweenBack(obj, props, duration)
    local info = TweenInfo.new(
        duration or 0.34,
        Enum.EasingStyle.Back,
        Enum.EasingDirection.Out
    )
    TweenService:Create(obj, info, props):Play()
end

-- ============================================================
-- Color palette
-- ============================================================

local Colors = {
    background   = Color3.fromRGB(10,  10,  10),
    panel        = Color3.fromRGB(18,  18,  18),
    card         = Color3.fromRGB(26,  26,  26),
    cardHover    = Color3.fromRGB(36,  36,  36),
    input        = Color3.fromRGB(20,  20,  20),
    divider      = Color3.fromRGB(42,  42,  42),
    text         = Color3.fromRGB(245, 245, 245),
    subtext      = Color3.fromRGB(112, 112, 112),
    stroke       = Color3.fromRGB(48,  48,  48),
    strokeHi     = Color3.fromRGB(188, 188, 188),
    white        = Color3.fromRGB(236, 236, 236),
    btnPrimary   = Color3.fromRGB(232, 232, 232),
    btnSecondary = Color3.fromRGB(30,  30,  30),
    btnDanger    = Color3.fromRGB(52,  20,  20),
    btnSave      = Color3.fromRGB(18,  36,  20),
    btnFav       = Color3.fromRGB(40,  32,  12),
    btnToggle    = Color3.fromRGB(44,  44,  44),
    notifyOk     = Color3.fromRGB(168, 168, 168),
    notifyErr    = Color3.fromRGB(210, 65,  65),
    notifySave   = Color3.fromRGB(75,  188, 95),
    notifyFav    = Color3.fromRGB(208, 155, 45),
}

-- ============================================================
-- Notification queue
-- ============================================================

local notifyGui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
notifyGui.Name = "AvatarChangerNotifs"
notifyGui.ResetOnSpawn = false
notifyGui.DisplayOrder = 99

local notifyQueue = {}
local notifyBusy  = false

local function pumpNotify()
    if notifyBusy or #notifyQueue == 0 then return end
    notifyBusy = true

    local msg, color = table.unpack(table.remove(notifyQueue, 1))
    color = color or Colors.notifyOk

    local frame = Instance.new("Frame", notifyGui)
    frame.Size = UDim2.new(0, 228, 0, 40)
    frame.Position = UDim2.new(1, 16, 1, -60)
    frame.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    frame.BorderSizePixel = 0
    frame.ZIndex = 20
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = color
    stroke.Thickness = 1.2

    local bar = Instance.new("Frame", frame)
    bar.Size = UDim2.new(0, 3, 1, -10)
    bar.Position = UDim2.new(0, 7, 0, 5)
    bar.BackgroundColor3 = color
    bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -22, 1, 0)
    label.Position = UDim2.new(0, 18, 0, 0)
    label.Text = msg
    label.TextColor3 = Colors.text
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 21

    frame:TweenPosition(UDim2.new(1, -246, 1, -60), "Out", "Back", 0.32, true)

    task.delay(2.6, function()
        tween(frame, { Position = UDim2.new(1, 16, 1, -60) }, 0.24)
        task.delay(0.26, function()
            frame:Destroy()
            notifyBusy = false
            pumpNotify()
        end)
    end)
end

local function notify(msg, color)
    table.insert(notifyQueue, { msg, color })
    pumpNotify()
end

-- ============================================================
-- Rig detection
-- ============================================================

local function getRig(char)
    return char:FindFirstChild("UpperTorso") and "R15" or "R6"
end

-- ============================================================
-- Accessory welding
-- ============================================================

local function weldAccessory(acc, char)
    local handle = acc:FindFirstChild("Handle")
    if not char or not handle then return end

    local attachment = handle:FindFirstChildOfClass("Attachment")
    local target = attachment and char:FindFirstChild(attachment.Name, true)

    acc.Parent = char

    if target then
        local weld = Instance.new("Weld", handle)
        weld.Part0 = handle
        weld.Part1 = target.Parent
        weld.C0 = attachment.CFrame
        weld.C1 = target.CFrame
    end
end

-- ============================================================
-- First-person (FOV) arm hide fix
-- ============================================================

local function applyFOVHide(char, hide)
    if not char then return end

    local armParts = {
        "Right Arm", "Left Arm",
        "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperArm",  "LeftLowerArm",  "LeftHand",
    }

    for _, name in ipairs(armParts) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            -- Cache the original transparency the first time
            if not part:FindFirstChild("_origTransp") then
                local v = Instance.new("NumberValue", part)
                v.Name = "_origTransp"
                v.Value = part.Transparency
            end
            local orig = part:FindFirstChild("_origTransp")
            part.Transparency = hide and 1 or (orig and orig.Value or 0)
        end
    end

    -- Keep accessories visible in first-person
    for _, child in pairs(char:GetChildren()) do
        if child:IsA("Accessory") then
            local handle = child:FindFirstChild("Handle")
            if handle then
                handle.LocalTransparencyModifier = 0
            end
        end
    end
end

local function startFOVFix()
    for _, conn in pairs(fovConnections) do conn:Disconnect() end
    fovConnections = {}

    local lastState = nil

    local conn = RunService.RenderStepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end

        local head = char:FindFirstChild("Head")
        if not head then return end

        local cam = workspace.CurrentCamera
        local inFirstPerson = (cam.CFrame.Position - head.Position).Magnitude < 1.2

        if inFirstPerson ~= lastState then
            lastState = inFirstPerson
            applyFOVHide(char, inFirstPerson)
        end
    end)

    table.insert(fovConnections, conn)
end

-- ============================================================
-- Korblox visual
-- ============================================================

local function applyKorblox(enabled)
    local char = LocalPlayer.Character
    if not char then return end

    -- Remove existing korblox part
    for _, v in pairs(char:GetChildren()) do
        if v.Name == "_KorbloxPart" then v:Destroy() end
    end

    if enabled then
        local part = Instance.new("Part", char)
        part.Name = "_KorbloxPart"
        part.Size = Vector3.new(1, 2, 1)
        part.CanCollide = false

        local mesh = Instance.new("SpecialMesh", part)
        mesh.MeshId    = "rbxassetid://902942096"
        mesh.TextureId = "rbxassetid://902843398"
        mesh.Scale     = Vector3.new(1.2, 1.2, 1.2)

        local leg = char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg")
        if leg then
            local weld = Instance.new("Weld", part)
            weld.Part0 = leg
            weld.Part1 = part
            weld.C0 = (leg.Name == "Right Leg")
                and CFrame.new(0, 0.6, -0.1)
                or  CFrame.new(0, 0.15, 0)
        end

        -- Hide the real leg parts
        for _, name in ipairs({ "RightUpperLeg", "RightLowerLeg", "RightFoot", "Right Leg" }) do
            local p = char:FindFirstChild(name)
            if p then p.Transparency = 1 end
        end
    else
        -- Show them again
        for _, name in ipairs({ "RightUpperLeg", "RightLowerLeg", "RightFoot", "Right Leg" }) do
            local p = char:FindFirstChild(name)
            if p then p.Transparency = 0 end
        end
    end
end

-- ============================================================
-- Headless visual
-- Runs in a short loop to fight ApplyDescription overwriting it
-- ============================================================

local function enforceHeadless(char, enabled)
    local head = char and char:FindFirstChild("Head")
    if not head then return end

    -- Loop a few times over ~0.5s to beat ApplyDescription's async completion
    task.spawn(function()
        for _ = 1, 8 do
            task.wait(0.07)
            local c = LocalPlayer.Character
            if not c then break end
            local h = c:FindFirstChild("Head")
            if not h then break end
            h.Transparency = enabled and 1 or 0
            for _, child in pairs(h:GetChildren()) do
                if child:IsA("Decal") then
                    child.Transparency = enabled and 1 or 0
                end
            end
        end
    end)
end

-- Same looping approach for korblox leg hides
local function enforceKorblox(char, enabled)
    task.spawn(function()
        for _ = 1, 8 do
            task.wait(0.07)
            local c = LocalPlayer.Character
            if not c then break end
            -- Re-run the hide/show on legs
            for _, name in ipairs({ "RightUpperLeg", "RightLowerLeg", "RightFoot", "Right Leg" }) do
                local p = c:FindFirstChild(name)
                if p then p.Transparency = enabled and 1 or 0 end
            end
        end
    end)
end

-- ============================================================
-- Manual cosmetic apply (fallback when ApplyDescription blocked)
-- ============================================================

local function applyItemsToChar(items, char, isReset)
    if not char then return end

    local rig  = getRig(char)
    local head = char:FindFirstChild("Head")

    -- Reset all body part visibility FIRST (before applying items)
    -- so korblox/headless set at the end of applyAvatar won't get stomped
    for _, v in pairs(char:GetDescendants()) do
        if v:IsA("BasePart")
        and v.Name ~= "HumanoidRootPart"
        and v.Name ~= "Head" then
            v.Transparency = 0
        end
    end

    -- Strip existing cosmetics
    for _, v in pairs(char:GetChildren()) do
        if v:IsA("Accessory")
        or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic")
        or v:IsA("BodyColors") or v:IsA("CharacterMesh") then
            v:Destroy()
        end
    end

    -- Reset head
    if head then
        head.Transparency = 0

        -- Remove face decal and (on R15) any injected mesh
        for _, v in pairs(head:GetChildren()) do
            if v:IsA("Decal") or (v:IsA("SpecialMesh") and rig == "R15") then
                v:Destroy()
            end
        end

        if isReset then
            -- Restore default face — never copy face from captured items on reset
            local face = Instance.new("Decal", head)
            face.Name    = "face"
            face.Texture = DEFAULT_FACE

            -- R6 needs a SpecialMesh for the round head shape
            if rig == "R6" then
                local existing = head:FindFirstChildOfClass("SpecialMesh")
                if not existing then
                    local m = Instance.new("SpecialMesh", head)
                    m.MeshType = Enum.MeshType.Head
                    m.Scale    = Vector3.new(1.25, 1.25, 1.25)
                end
            end
        end
    end

    -- Apply items from the list
    for _, item in pairs(items) do
        local cls = item.ClassName

        if cls == "Accessory" then
            weldAccessory(item:Clone(), char)

        elseif cls == "Shirt" or cls == "Pants" or cls == "ShirtGraphic" then
            item:Clone().Parent = char

        elseif cls == "BodyColors" then
            item:Clone().Parent = char

        elseif cls == "CharacterMesh" then
            -- R6 only — CharacterMesh on R15 causes invisible body parts
            if rig == "R6" then
                item:Clone().Parent = char
            end

        elseif cls == "SpecialMesh" then
            -- Only inject head mesh on R6 (R15 rig system handles head shape)
            if head and rig == "R6" and not isReset then
                local ex = head:FindFirstChildOfClass("SpecialMesh")
                if ex then ex:Destroy() end
                item:Clone().Parent = head
            end

        elseif cls == "Decal" and item.Name == "face" then
            -- Skip on reset (we already set the default face above)
            if not isReset and head then
                local tex = item.Texture
                local isDefaultTex = (
                    tex == DEFAULT_FACE
                    or tex == "rbxassetid://0"
                    or tex == ""
                )
                if not isDefaultTex then
                    local ex = head:FindFirstChild("face")
                    if ex then ex:Destroy() end
                    item:Clone().Parent = head
                end
            end
        end
    end

end

-- ============================================================
-- Build cosmetic item list from a user's model
-- ============================================================

local function buildItemList(userId)
    local ok, model = pcall(function()
        return Players:CreateHumanoidModelFromUserId(userId)
    end)
    if not ok or not model then return nil end

    local items = {}
    for _, v in pairs(model:GetDescendants()) do
        local cls = v.ClassName
        if cls == "Accessory"
        or cls == "Shirt" or cls == "Pants" or cls == "ShirtGraphic"
        or cls == "BodyColors" or cls == "CharacterMesh" then
            table.insert(items, v:Clone())
        elseif cls == "Decal" and v.Name == "face" then
            table.insert(items, v:Clone())
        elseif cls == "SpecialMesh" and v.Parent and v.Parent.Name == "Head" then
            table.insert(items, v:Clone())
        end
    end

    model:Destroy()
    return items
end

-- ============================================================
-- Core avatar apply
-- Tries ApplyDescription first; falls back to manual if blocked
-- ============================================================

local function applyAvatar(hDesc, items, isReset)
    local char = LocalPlayer.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local usedApplyDesc = false

    if not useManualMode and hDesc then
        local ok = pcall(function() hum:ApplyDescription(hDesc) end)
        if ok then
            usedApplyDesc = true
            currentHDesc  = hDesc
        else
            useManualMode = true
            notify("Auto-switched to manual mode", Colors.notifyFav)
        end
    end

    if not usedApplyDesc then
        if not items then
            notify("No avatar data available", Colors.notifyErr)
            return
        end
        applyItemsToChar(items, char, isReset)
        currentItems = items
    end

    -- Apply headless and korblox synchronously RIGHT HERE, last thing before notify.
    -- V90 worked because it did this directly inside FinalApply with no async.
    -- The body-reset in applyItemsToChar now runs at the top of that function,
    -- so there is nothing left to stomp on these after we set them.
    local head = char:FindFirstChild("Head")
    if head then
        head.Transparency = headlessEnabled and 1 or 0
        for _, v in pairs(head:GetChildren()) do
            if v:IsA("Decal") then
                v.Transparency = headlessEnabled and 1 or 0
            end
        end
    end

    applyKorblox(korbloxEnabled)

    task.spawn(startFOVFix)
    notify(isReset and "Avatar Reset" or "Avatar Applied",
           isReset and Colors.notifyErr or Colors.notifyOk)
end

-- ============================================================
-- Change avatar by username or user ID
-- ============================================================

local function changeAvatar(input)
    input = tostring(input):match("^%s*(.-)%s*$")
    if input == "" then
        notify("Enter a username or ID", Colors.notifyErr)
        return
    end

    -- Resolve to a userId
    local userId
    local ok, result = pcall(function()
        return Players:GetUserIdFromNameAsync(input)
    end)
    if ok and result then
        userId = result
    else
        local numericId = tonumber(input:match("^%d+$"))
        if numericId then
            userId = numericId
        else
            notify("User not found", Colors.notifyErr)
            return
        end
    end

    -- Push to history (deduplicated, most recent first)
    for i, entry in ipairs(avatarHistory) do
        local name = type(entry) == "table" and entry.name or tostring(entry)
        if name == input then
            table.remove(avatarHistory, i)
            break
        end
    end
    table.insert(avatarHistory, 1, { name = input, time = os.time() })
    if #avatarHistory > 30 then table.remove(avatarHistory) end
    saveData()

    -- Fetch the HumanoidDescription and item list in parallel
    local hDesc
    pcall(function()
        hDesc = Players:GetHumanoidDescriptionFromUserId(userId)
    end)

    local items = buildItemList(userId)

    if not hDesc and not items then
        notify("Could not fetch avatar data", Colors.notifyErr)
        return
    end

    applyAvatar(hDesc, items, false)
end

-- ============================================================
-- Wear a single item by ID
-- ============================================================

local function getClothingTemplate(id)
    local ok, asset = pcall(function()
        return game:GetObjects("rbxassetid://" .. id)[1]
    end)
    if ok and asset then
        local template = ""
        if asset:IsA("Shirt") then
            template = asset.ShirtTemplate
        elseif asset:IsA("Pants") then
            template = asset.PantsTemplate
        elseif asset:IsA("ShirtGraphic") then
            template = asset.Graphic
        end
        asset:Destroy()
        return template ~= "" and template or ("rbxassetid://" .. id)
    end
    return "rbxassetid://" .. id
end

local function wearItem(id)
    local char = LocalPlayer.Character
    if not char then return false end

    local ok, info = pcall(function()
        return MarketplaceService:GetProductInfo(tonumber(id))
    end)

    if ok and info then
        if info.AssetTypeId == 11 then
            local shirt = char:FindFirstChildOfClass("Shirt")
                       or Instance.new("Shirt", char)
            shirt.ShirtTemplate = getClothingTemplate(id)
            notify("Shirt Applied", Colors.notifyOk)
            return true
        elseif info.AssetTypeId == 12 then
            local pants = char:FindFirstChildOfClass("Pants")
                       or Instance.new("Pants", char)
            pants.PantsTemplate = getClothingTemplate(id)
            notify("Pants Applied", Colors.notifyOk)
            return true
        end
    end

    local ok2, asset = pcall(function()
        return game:GetObjects("rbxassetid://" .. id)[1]
    end)
    if ok2 and asset then
        if asset:IsA("Accessory") then
            weldAccessory(asset, char)
        else
            asset.Parent = char
        end
        notify("Item Added", Colors.notifyOk)
        return true
    end

    return false
end

-- ============================================================
-- Inject face / head mesh / body part by ID
-- ============================================================

local function injectPart(id)
    local char = LocalPlayer.Character
    if not char then return end

    local cid = tostring(id):match("%d+")
    if not cid then notify("Invalid ID", Colors.notifyErr); return end

    local head = char:FindFirstChild("Head")
    local ok, info = pcall(function()
        return MarketplaceService:GetProductInfo(tonumber(cid))
    end)

    if ok and info then
        local assetType = info.AssetTypeId

        if assetType == 18 then  -- Face decal
            if head then
                local face = head:FindFirstChild("face") or Instance.new("Decal", head)
                face.Name    = "face"
                face.Texture = "rbxassetid://" .. cid
                notify("Face Injected", Colors.notifyOk)
            end
            return

        elseif assetType == 17 or assetType == 24 then  -- Head mesh
            if head then
                local mesh = head:FindFirstChildOfClass("SpecialMesh")
                          or Instance.new("SpecialMesh", head)
                mesh.MeshId = "rbxassetid://" .. cid
                notify("Head Injected", Colors.notifyOk)
            end
            return

        elseif assetType >= 27 and assetType <= 31 then  -- Body part package
            local ok2, asset = pcall(function()
                return game:GetObjects("rbxassetid://" .. cid)[1]
            end)
            if ok2 and asset then
                asset.Parent = char
                notify("Body Part Injected", Colors.notifyOk)
            end
            return
        end
    end

    notify("ID not recognised", Colors.notifyErr)
end

-- ============================================================
--
--   U I   (260 x 490)
--
-- ============================================================

local WIN_W = 260
local WIN_H = 490

local screenGui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
screenGui.Name          = "AvatarChangerV98"
screenGui.ResetOnSpawn  = false
screenGui.DisplayOrder  = 10

-- Main window frame
local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Name              = "MainWindow"
mainFrame.Size              = UDim2.new(0, WIN_W, 0, WIN_H)
mainFrame.Position          = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
mainFrame.BackgroundColor3  = Colors.background
mainFrame.Active            = true
mainFrame.ClipsDescendants  = true
mainFrame.Visible           = false
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 14)
local windowStroke = Instance.new("UIStroke", mainFrame)
windowStroke.Color     = Colors.stroke
windowStroke.Thickness = 1.3

-- Gradient accent line at top
local accentLine = Instance.new("Frame", mainFrame)
accentLine.Size             = UDim2.new(1, 0, 0, 2)
accentLine.BackgroundColor3 = Colors.white
accentLine.BorderSizePixel  = 0
accentLine.ZIndex           = 6
local gradient = Instance.new("UIGradient", accentLine)
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(18, 18, 18)),
    ColorSequenceKeypoint.new(0.22, Colors.white),
    ColorSequenceKeypoint.new(0.78, Colors.white),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(18, 18, 18)),
})

-- Header bar
local header = Instance.new("Frame", mainFrame)
header.Size             = UDim2.new(1, 0, 0, 46)
header.Position         = UDim2.new(0, 0, 0, 2)
header.BackgroundColor3 = Colors.panel
header.BorderSizePixel  = 0
header.ZIndex           = 4

local headerDivider = Instance.new("Frame", header)
headerDivider.Size             = UDim2.new(1, 0, 0, 1)
headerDivider.Position         = UDim2.new(0, 0, 1, -1)
headerDivider.BackgroundColor3 = Colors.divider
headerDivider.BorderSizePixel  = 0
headerDivider.ZIndex           = 5

local titleLabel = Instance.new("TextLabel", header)
titleLabel.Size               = UDim2.new(0, 180, 0, 20)
titleLabel.Position           = UDim2.new(0, 13, 0, 7)
titleLabel.Text               = "AVATAR CHANGER"
titleLabel.TextColor3         = Colors.text
titleLabel.Font               = Enum.Font.GothamBold
titleLabel.TextSize           = 13
titleLabel.BackgroundTransparency = 1
titleLabel.TextXAlignment     = Enum.TextXAlignment.Left
titleLabel.ZIndex             = 5

local versionLabel = Instance.new("TextLabel", header)
versionLabel.Size               = UDim2.new(0, 180, 0, 12)
versionLabel.Position           = UDim2.new(0, 13, 0, 28)
versionLabel.Text               = "V99  ·  by XYTHC"
versionLabel.TextColor3         = Colors.subtext
versionLabel.Font               = Enum.Font.Gotham
versionLabel.TextSize           = 9
versionLabel.BackgroundTransparency = 1
versionLabel.TextXAlignment     = Enum.TextXAlignment.Left
versionLabel.ZIndex             = 5

local closeButton = Instance.new("TextButton", header)
closeButton.Size             = UDim2.new(0, 24, 0, 24)
closeButton.Position         = UDim2.new(1, -34, 0, 11)
closeButton.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
closeButton.Text             = "✕"
closeButton.TextColor3       = Colors.subtext
closeButton.Font             = Enum.Font.GothamBold
closeButton.TextSize         = 11
closeButton.ZIndex           = 5
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 7)
closeButton.MouseEnter:Connect(function()
    tween(closeButton, { TextColor3 = Color3.fromRGB(228, 70, 70) }, 0.12)
end)
closeButton.MouseLeave:Connect(function()
    tween(closeButton, { TextColor3 = Colors.subtext }, 0.12)
end)

-- Tab bar
local tabBar = Instance.new("Frame", mainFrame)
tabBar.Size             = UDim2.new(1, -18, 0, 30)
tabBar.Position         = UDim2.new(0, 9, 0, 54)
tabBar.BackgroundColor3 = Colors.card
tabBar.ZIndex           = 4
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 9)

local function makeTab(text, xScale, isActive)
    local btn = Instance.new("TextButton", tabBar)
    btn.Size             = UDim2.new(0.5, -4, 1, -6)
    btn.Position         = UDim2.new(xScale, xScale == 0 and 3 or 1, 0, 3)
    btn.BackgroundColor3 = isActive and Colors.white or Color3.fromRGB(0, 0, 0)
    btn.BackgroundTransparency = isActive and 0 or 1
    btn.Text             = text
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 10
    btn.ZIndex           = 5
    btn.TextColor3       = isActive and Colors.background or Colors.subtext
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local changerTab = makeTab("CHANGER", 0,   true)
local historyTab = makeTab("HISTORY", 0.5, false)

-- Scroll pages
local PAGE_Y = 90

local changerPage = Instance.new("ScrollingFrame", mainFrame)
changerPage.Size                  = UDim2.new(1, 0, 1, -PAGE_Y)
changerPage.Position              = UDim2.new(0, 0, 0, PAGE_Y)
changerPage.BackgroundTransparency = 1
changerPage.ScrollBarThickness    = 3
changerPage.ScrollBarImageColor3  = Color3.fromRGB(58, 58, 58)
changerPage.BorderSizePixel       = 0

local historyPage = Instance.new("ScrollingFrame", mainFrame)
historyPage.Size                  = UDim2.new(1, 0, 1, -PAGE_Y)
historyPage.Position              = UDim2.new(0, 0, 0, PAGE_Y)
historyPage.BackgroundTransparency = 1
historyPage.ScrollBarThickness    = 3
historyPage.ScrollBarImageColor3  = Color3.fromRGB(58, 58, 58)
historyPage.Visible               = false
historyPage.BorderSizePixel       = 0

-- ── Changer page content ──────────────────────────────────────

local PAD = 10
local cursorY = 9  -- tracks vertical position inside changerPage

local function addSeparator(text)
    local label = Instance.new("TextLabel", changerPage)
    label.Size               = UDim2.new(1, -PAD*2, 0, 13)
    label.Position           = UDim2.new(0, PAD, 0, cursorY)
    label.BackgroundTransparency = 1
    label.Text               = text
    label.TextColor3         = Colors.subtext
    label.Font               = Enum.Font.GothamBold
    label.TextSize           = 9
    label.TextXAlignment     = Enum.TextXAlignment.Left
    label.ZIndex             = 4

    local divLine = Instance.new("Frame", changerPage)
    divLine.Size             = UDim2.new(1, -PAD*2, 0, 1)
    divLine.Position         = UDim2.new(0, PAD, 0, cursorY + 13)
    divLine.BackgroundColor3 = Colors.divider
    divLine.BorderSizePixel  = 0
    divLine.ZIndex           = 4

    cursorY = cursorY + 19
end

-- Input box
local inputWrapper = Instance.new("Frame", changerPage)
inputWrapper.Size             = UDim2.new(1, -PAD*2, 0, 36)
inputWrapper.Position         = UDim2.new(0, PAD, 0, cursorY)
inputWrapper.BackgroundColor3 = Colors.input
inputWrapper.ZIndex           = 4
Instance.new("UICorner", inputWrapper).CornerRadius = UDim.new(0, 10)
local inputStroke = Instance.new("UIStroke", inputWrapper)
inputStroke.Color     = Colors.stroke
inputStroke.Thickness = 1

local inputIcon = Instance.new("TextLabel", inputWrapper)
inputIcon.Size               = UDim2.new(0, 30, 1, 0)
inputIcon.Text               = "  "
inputIcon.TextColor3         = Colors.subtext
inputIcon.BackgroundTransparency = 1
inputIcon.Font               = Enum.Font.GothamBold
inputIcon.TextSize           = 13
inputIcon.ZIndex             = 5

local inputBox = Instance.new("TextBox", inputWrapper)
inputBox.Size                = UDim2.new(1, -32, 1, 0)
inputBox.Position            = UDim2.new(0, 28, 0, 0)
inputBox.BackgroundTransparency = 1
inputBox.Text                = ""
inputBox.PlaceholderText     = "Username / Item ID..."
inputBox.PlaceholderColor3   = Colors.subtext
inputBox.TextColor3          = Colors.text
inputBox.Font                = Enum.Font.Gotham
inputBox.TextSize            = 12
inputBox.ZIndex              = 5
inputBox.ClearTextOnFocus    = false
inputBox.Focused:Connect(function()
    tween(inputStroke, { Color = Colors.strokeHi, Thickness = 1.5 }, 0.14)
end)
inputBox.FocusLost:Connect(function()
    tween(inputStroke, { Color = Colors.stroke,   Thickness = 1   }, 0.14)
end)
cursorY = cursorY + 44

-- Button factory
local function makeButton(text, bgColor, textColor, height)
    height = height or 32

    local card = Instance.new("Frame", changerPage)
    card.Size             = UDim2.new(1, -PAD*2, 0, height)
    card.Position         = UDim2.new(0, PAD, 0, cursorY)
    card.BackgroundColor3 = bgColor
    card.ZIndex           = 4
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 9)

    if bgColor ~= Colors.btnPrimary then
        local stroke = Instance.new("UIStroke", card)
        stroke.Color     = Colors.divider
        stroke.Thickness = 1
    end

    cursorY = cursorY + height + 6

    local btn = Instance.new("TextButton", card)
    btn.Size             = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text             = text
    btn.TextColor3       = textColor or Colors.text
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 11
    btn.ZIndex           = 5

    btn.MouseEnter:Connect(function()
        local r = math.min(bgColor.R + 0.07, 1)
        local g = math.min(bgColor.G + 0.07, 1)
        local b = math.min(bgColor.B + 0.07, 1)
        tween(card, { BackgroundColor3 = Color3.new(r, g, b) }, 0.11)
    end)
    btn.MouseLeave:Connect(function()
        tween(card, { BackgroundColor3 = bgColor }, 0.11)
    end)
    btn.MouseButton1Down:Connect(function()
        tween(card, { Size = UDim2.new(1, -PAD*2 - 4, 0, height - 3) }, 0.07)
    end)
    btn.MouseButton1Up:Connect(function()
        tween(card, { Size = UDim2.new(1, -PAD*2, 0, height) }, 0.15)
    end)

    return btn, card
end

-- Toggle factory
-- The onToggle callback receives the new boolean value.
local function makeToggle(textOff, textOn, bgOff, bgOn, colorOff, colorOn, onToggle)
    local btn, card = makeButton(textOff, bgOff, colorOff)
    local toggled = false

    local function sync(value)
        toggled = value
        btn.Text = value and textOn or textOff
        tween(btn,  { TextColor3 = value and colorOn or colorOff }, 0.14)
        tween(card, { BackgroundColor3 = value and bgOn or bgOff }, 0.14)
        local stroke = card:FindFirstChildOfClass("UIStroke")
        if stroke then
            tween(stroke, { Color = value and Colors.strokeHi or Colors.divider }, 0.14)
        end
    end

    btn.MouseButton1Click:Connect(function()
        sync(not toggled)
        if onToggle then onToggle(toggled) end
    end)

    -- Returns a setter so the reset button can force both to off
    return btn, card, function(value) sync(value) end
end

-- Build all buttons on changer page
addSeparator("AVATAR")
local changeAvatarBtn = makeButton("  CHANGE AVATAR",            Colors.btnPrimary,   Colors.background)
local wearItemBtn     = makeButton("  WEAR ITEM / ID",            Colors.btnSecondary, Colors.text)
local injectBtn       = makeButton("  INJECT BODY / FACE / HEAD", Colors.btnSecondary, Colors.text)

addSeparator("TOGGLES")
local _, _, setKorblox = makeToggle(
    "  KORBLOX: OFF", "  KORBLOX: ON",
    Colors.btnSecondary, Colors.btnToggle,
    Colors.subtext, Colors.text,
    function(value)
        korbloxEnabled = value
        applyKorblox(value)
    end
)

local _, _, setHeadless = makeToggle(
    "  HEADLESS: OFF", "  HEADLESS: ON",
    Colors.btnSecondary, Colors.btnToggle,
    Colors.subtext, Colors.text,
    function(value)
        headlessEnabled = value
        local char = LocalPlayer.Character
        local head = char and char:FindFirstChild("Head")
        if head then
            head.Transparency = value and 1 or 0
            for _, v in pairs(head:GetChildren()) do
                if v:IsA("Decal") then v.Transparency = value and 1 or 0 end
            end
        end
    end
)

addSeparator("MANAGE")
local addFavBtn    = makeButton("  ADD TO FAVORITES",    Colors.btnFav,    Color3.fromRGB(208, 165, 55))
local saveOutfitBtn = makeButton("  SAVE CURRENT OUTFIT", Colors.btnSave,   Color3.fromRGB(75,  196, 95))
local resetBtn     = makeButton("  RESET AVATAR",         Colors.btnDanger, Color3.fromRGB(218, 85,  85))

changerPage.CanvasSize = UDim2.new(0, 0, 0, cursorY + 8)

-- Button click handlers
changeAvatarBtn.MouseButton1Click:Connect(function()
    changeAvatar(inputBox.Text)
end)

wearItemBtn.MouseButton1Click:Connect(function()
    local id = inputBox.Text:match("%d+")
    if not id then notify("No ID found", Colors.notifyErr); return end

    if wearItem(id) then
        -- Push to item history
        for i, entry in ipairs(itemHistory) do
            local storedId = type(entry) == "table" and entry.id or tostring(entry)
            if storedId == id then table.remove(itemHistory, i); break end
        end
        table.insert(itemHistory, 1, { id = id, time = os.time() })
        if #itemHistory > 30 then table.remove(itemHistory) end
        saveData()
    else
        notify("Item not found", Colors.notifyErr)
    end
end)

injectBtn.MouseButton1Click:Connect(function()
    local id = inputBox.Text:match("%d+")
    if not id then notify("No ID found", Colors.notifyErr); return end
    injectPart(id)
end)

addFavBtn.MouseButton1Click:Connect(function()
    local text = inputBox.Text:match("^%s*(.-)%s*$")
    if text == "" then notify("Enter something first", Colors.notifyErr); return end
    if table.find(favorites, text) then notify("Already in Favorites", Colors.notifyErr); return end
    table.insert(favorites, text)
    saveData()
    notify("Added to Favorites", Colors.notifyFav)
end)

saveOutfitBtn.MouseButton1Click:Connect(function()
    if not currentHDesc and #currentItems == 0 then
        notify("No outfit applied yet", Colors.notifyErr)
        return
    end
    local name = inputBox.Text:match("^%s*(.-)%s*$")
    name = (name ~= "") and name or ("Outfit " .. os.date("%H:%M"))
    savedOutfits[name] = { hDesc = currentHDesc, items = currentItems }
    notify("Saved: " .. name, Colors.notifySave)
end)

resetBtn.MouseButton1Click:Connect(function()
    korbloxEnabled  = false
    headlessEnabled = false
    setKorblox(false)
    setHeadless(false)
    applyAvatar(originalHDesc, originalItems, true)
end)

-- ── History page ──────────────────────────────────────────────

local function formatRelativeTime(timestamp)
    if not timestamp then return nil end
    local delta = os.time() - timestamp
    if delta < 60 then
        return delta .. "s ago"
    elseif delta < 3600 then
        return math.floor(delta / 60) .. "m ago"
    else
        return math.floor(delta / 3600) .. "h ago"
    end
end

local function makeHistoryCard(parent, mainText, subText, bgColor, onClick)
    local height = subText and 40 or 34

    local card = Instance.new("Frame", parent)
    card.Size             = UDim2.new(1, -18, 0, height)
    card.BackgroundColor3 = bgColor or Colors.card
    card.ZIndex           = 4
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local cardStroke = Instance.new("UIStroke", card)
    cardStroke.Color     = Colors.divider
    cardStroke.Thickness = 1

    local label = Instance.new("TextButton", card)
    label.Size             = UDim2.new(1, -38, subText and 0 or 1, subText and 19 or 0)
    label.Position         = UDim2.new(0, 9, 0, subText and 4 or 0)
    label.BackgroundTransparency = 1
    label.Text             = mainText
    label.TextColor3       = Colors.text
    label.Font             = Enum.Font.GothamBold
    label.TextSize         = 10
    label.TextXAlignment   = Enum.TextXAlignment.Left
    label.ZIndex           = 5
    label.TextTruncate     = Enum.TextTruncate.AtEnd

    if subText then
        local sub = Instance.new("TextLabel", card)
        sub.Size             = UDim2.new(1, -38, 0, 12)
        sub.Position         = UDim2.new(0, 9, 0, 22)
        sub.BackgroundTransparency = 1
        sub.Text             = subText
        sub.TextColor3       = Colors.subtext
        sub.Font             = Enum.Font.Gotham
        sub.TextSize         = 9
        sub.TextXAlignment   = Enum.TextXAlignment.Left
        sub.ZIndex           = 5
    end

    if onClick then
        label.MouseButton1Click:Connect(onClick)
        label.MouseEnter:Connect(function()
            tween(card, { BackgroundColor3 = Colors.cardHover }, 0.09)
        end)
        label.MouseLeave:Connect(function()
            tween(card, { BackgroundColor3 = bgColor or Colors.card }, 0.09)
        end)
    end

    return card
end

local function makeDeleteButton(parent, onDelete)
    local btn = Instance.new("TextButton", parent)
    btn.Size             = UDim2.new(0, 22, 0, 22)
    btn.Position         = UDim2.new(1, -28, 0.5, -11)
    btn.BackgroundColor3 = Color3.fromRGB(40, 14, 14)
    btn.Text             = "✕"
    btn.TextColor3       = Color3.fromRGB(185, 60, 60)
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 10
    btn.ZIndex           = 6
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(onDelete)
end

local function makeSectionLabel(parent, text, layoutOrder)
    local label = Instance.new("TextLabel", parent)
    label.Size               = UDim2.new(1, -18, 0, 17)
    label.BackgroundTransparency = 1
    label.Text               = text
    label.TextColor3         = Colors.strokeHi
    label.Font               = Enum.Font.GothamBold
    label.TextSize           = 9
    label.TextXAlignment     = Enum.TextXAlignment.Left
    label.ZIndex             = 4
    label.LayoutOrder        = layoutOrder
    return label
end

local function switchToChanger(text)
    if text then inputBox.Text = text end
    historyPage.Visible = false
    changerPage.Visible = true
    tween(changerTab, { BackgroundColor3 = Colors.white, BackgroundTransparency = 0, TextColor3 = Colors.background }, 0.14)
    tween(historyTab, { BackgroundColor3 = Color3.fromRGB(0,0,0), BackgroundTransparency = 1, TextColor3 = Colors.subtext }, 0.14)
end

local function rebuildHistory()
    -- Clear old children
    for _, v in pairs(historyPage:GetChildren()) do
        if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then
            v:Destroy()
        end
    end

    local layout = Instance.new("UIListLayout", historyPage)
    layout.Padding             = UDim.new(0, 5)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder           = Enum.SortOrder.LayoutOrder

    local padding = Instance.new("UIPadding", historyPage)
    padding.PaddingTop = UDim.new(0, 7)

    local order = 1
    local hasContent = false

    -- Saved outfits
    if next(savedOutfits) then
        hasContent = true
        makeSectionLabel(historyPage, "  SAVED OUTFITS", order); order = order + 1
        for name, data in pairs(savedOutfits) do
            local card = makeHistoryCard(
                historyPage, name, nil,
                Color3.fromRGB(16, 30, 18),
                function()
                    applyAvatar(data.hDesc, data.items, false)
                    notify("Loaded: " .. name, Colors.notifySave)
                end
            )
            card.LayoutOrder = order; order = order + 1
            makeDeleteButton(card, function()
                savedOutfits[name] = nil
                rebuildHistory()
            end)
        end
    end

    -- Favorites
    if #favorites > 0 then
        hasContent = true
        makeSectionLabel(historyPage, "  FAVORITES", order); order = order + 1
        for idx, fav in ipairs(favorites) do
            local card = makeHistoryCard(
                historyPage, fav, nil,
                Color3.fromRGB(34, 24, 8),
                function() switchToChanger(fav) end
            )
            card.LayoutOrder = order; order = order + 1
            local capturedIdx = idx
            makeDeleteButton(card, function()
                table.remove(favorites, capturedIdx)
                saveData()
                rebuildHistory()
            end)
        end
    end

    -- Avatar history
    if #avatarHistory > 0 then
        hasContent = true
        makeSectionLabel(historyPage, "  AVATAR HISTORY", order); order = order + 1
        for _, entry in ipairs(avatarHistory) do
            local name = type(entry) == "table" and entry.name or tostring(entry)
            local time = type(entry) == "table" and formatRelativeTime(entry.time) or nil
            local card = makeHistoryCard(
                historyPage, name, time,
                Colors.card,
                function() switchToChanger(name) end
            )
            card.LayoutOrder = order; order = order + 1
        end
    end

    -- Item history
    if #itemHistory > 0 then
        hasContent = true
        makeSectionLabel(historyPage, "  ITEM HISTORY", order); order = order + 1
        for _, entry in ipairs(itemHistory) do
            local id   = type(entry) == "table" and entry.id or tostring(entry)
            local time = type(entry) == "table" and formatRelativeTime(entry.time) or nil
            local card = makeHistoryCard(
                historyPage, "ID: " .. id, time,
                Colors.card,
                function() switchToChanger(id) end
            )
            card.LayoutOrder = order; order = order + 1
        end
    end

    -- Empty state
    if not hasContent then
        local empty = Instance.new("TextLabel", historyPage)
        empty.Size               = UDim2.new(1, 0, 0, 50)
        empty.BackgroundTransparency = 1
        empty.Text               = "Nothing saved yet"
        empty.TextColor3         = Colors.subtext
        empty.Font               = Enum.Font.Gotham
        empty.TextSize           = 11
        empty.ZIndex             = 4
        empty.LayoutOrder        = 1
    end

    -- Clear history button
    if #avatarHistory > 0 or #itemHistory > 0 then
        local clearBtn = Instance.new("TextButton", historyPage)
        clearBtn.Size             = UDim2.new(1, -18, 0, 28)
        clearBtn.BackgroundColor3 = Color3.fromRGB(36, 12, 12)
        clearBtn.Text             = "  CLEAR HISTORY"
        clearBtn.TextColor3       = Color3.fromRGB(185, 60, 60)
        clearBtn.Font             = Enum.Font.GothamBold
        clearBtn.TextSize         = 10
        clearBtn.ZIndex           = 4
        clearBtn.LayoutOrder      = order + 999
        Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 8)
        clearBtn.MouseButton1Click:Connect(function()
            avatarHistory = {}
            itemHistory   = {}
            saveData()
            rebuildHistory()
            notify("History Cleared", Colors.notifyErr)
        end)
    end

    task.wait()
    historyPage.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
end

-- Tab switching
historyTab.MouseButton1Click:Connect(function()
    changerPage.Visible = false
    historyPage.Visible = true
    rebuildHistory()
    tween(historyTab, { BackgroundColor3 = Colors.white, BackgroundTransparency = 0, TextColor3 = Colors.background }, 0.14)
    tween(changerTab, { BackgroundColor3 = Color3.fromRGB(0,0,0), BackgroundTransparency = 1, TextColor3 = Colors.subtext }, 0.14)
end)

changerTab.MouseButton1Click:Connect(function()
    historyPage.Visible = false
    changerPage.Visible = true
    tween(changerTab, { BackgroundColor3 = Colors.white, BackgroundTransparency = 0, TextColor3 = Colors.background }, 0.14)
    tween(historyTab, { BackgroundColor3 = Color3.fromRGB(0,0,0), BackgroundTransparency = 1, TextColor3 = Colors.subtext }, 0.14)
end)

-- ── Floating toggle button ────────────────────────────────────

local iconButton = Instance.new("TextButton", screenGui)
iconButton.Size             = UDim2.new(0, 44, 0, 44)
iconButton.Position         = UDim2.new(0, 12, 0, 12)
iconButton.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
iconButton.Text             = ""
iconButton.ZIndex           = 5
Instance.new("UICorner", iconButton).CornerRadius = UDim.new(0, 12)
local iconStroke = Instance.new("UIStroke", iconButton)
iconStroke.Color     = Colors.stroke
iconStroke.Thickness = 1.2

local iconLabel = Instance.new("TextLabel", iconButton)
iconLabel.Size               = UDim2.new(1, 0, 0.65, 0)
iconLabel.Position           = UDim2.new(0, 0, 0.1, 0)
iconLabel.Text               = ""
iconLabel.TextSize           = 19
iconLabel.BackgroundTransparency = 1
iconLabel.ZIndex             = 6
iconLabel.Font               = Enum.Font.Gotham

local statusDot = Instance.new("Frame", iconButton)
statusDot.Size             = UDim2.new(0, 8, 0, 8)
statusDot.Position         = UDim2.new(1, -10, 0, 2)
statusDot.BackgroundColor3 = Color3.fromRGB(215, 48, 48)
statusDot.ZIndex           = 7
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

local function setStatusDot(open)
    tween(statusDot, {
        BackgroundColor3 = open
            and Color3.fromRGB(80, 210, 100)
            or  Color3.fromRGB(215, 48, 48)
    }, 0.2)
end

iconButton.MouseEnter:Connect(function()
    tweenBack(iconButton, { Size = UDim2.new(0, 48, 0, 48), Position = UDim2.new(0, 10, 0, 10) }, 0.2)
    tween(iconStroke, { Color = Colors.strokeHi }, 0.12)
end)
iconButton.MouseLeave:Connect(function()
    tweenBack(iconButton, { Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0, 12, 0, 12) }, 0.2)
    tween(iconStroke, { Color = Colors.stroke }, 0.12)
end)

local function openWindow()
    mainFrame.Size     = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.Visible  = true
    tweenBack(mainFrame, {
        Size     = UDim2.new(0, WIN_W, 0, WIN_H),
        Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
    }, 0.36)
    setStatusDot(true)
end

local function closeWindow()
    tween(mainFrame, {
        Size     = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0)
    }, 0.17)
    task.delay(0.19, function() mainFrame.Visible = false end)
    setStatusDot(false)
end

iconButton.MouseButton1Click:Connect(function()
    if not mainFrame.Visible then openWindow() else closeWindow() end
end)
closeButton.MouseButton1Click:Connect(closeWindow)

-- ── Drag ──────────────────────────────────────────────────────

local function makeDraggable(frame, handle)
    local isDragging = false
    local dragInput   = nil
    local startMouse  = nil
    local startPos    = nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            startMouse = input.Position
            startPos   = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and isDragging then
            local delta = input.Position - startMouse
            frame.Position = UDim2.new(
                startPos.X.Scale,  startPos.X.Offset  + delta.X,
                startPos.Y.Scale,  startPos.Y.Offset  + delta.Y
            )
        end
    end)
end

makeDraggable(mainFrame, header)
makeDraggable(iconButton, iconButton)

-- ============================================================
-- Respawn handler
-- ============================================================

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.8)
    local hasOutfit = (currentHDesc ~= nil) or (#currentItems > 0)
    if hasOutfit then
        applyAvatar(currentHDesc, currentItems, false)
    end
    task.spawn(startFOVFix)
end)

-- ============================================================
-- Initialise — capture original avatar state
-- ============================================================

local initialChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-- Try getting the HumanoidDescription from the humanoid first (most accurate)
pcall(function()
    local hum = initialChar:FindFirstChildOfClass("Humanoid")
    if hum then
        originalHDesc = hum:GetAppliedDescription()
    end
end)

-- Fall back to the API if that didn't work
if not originalHDesc then
    pcall(function()
        originalHDesc = Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
    end)
end

-- Capture the original cosmetics for manual-mode reset
for _, v in pairs(initialChar:GetDescendants()) do
    local cls = v.ClassName
    if cls == "Accessory"
    or cls == "Shirt" or cls == "Pants" or cls == "ShirtGraphic"
    or cls == "BodyColors" or cls == "CharacterMesh" then
        table.insert(originalItems, v:Clone())
    elseif cls == "Decal" and v.Name == "face" and v.Parent and v.Parent.Name == "Head" then
        table.insert(originalItems, v:Clone())
    elseif cls == "SpecialMesh" and v.Parent and v.Parent.Name == "Head" then
        table.insert(originalItems, v:Clone())
    end
end

task.spawn(startFOVFix)
notify("Avatar Changer V98  Ready", Colors.notifyOk)
