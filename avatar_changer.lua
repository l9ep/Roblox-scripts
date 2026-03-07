-- AVATAR CHANGER V96
-- Full audit + bug fixes over V95:
--   - SavedOutfits no longer tries to JSON-encode Roblox Instances (crash fix)
--   - Toggle double-fire eliminated: KorbloxOn/HeadlessOn updated inside MkToggle callback
--   - ChangeAvatar userId resolution improved (no false positive on item IDs)
--   - InjectPart face type narrowed to 18 only (type 1 = generic image, wrong)
--   - ApplyHDesc headless/korblox post-step moved to task.spawn to avoid yielding caller
--   - UI slightly smaller: 268x510 window, buttons 34px, tighter spacing
-- (XYTHC)

local X_Player  = game:GetService("Players").LocalPlayer
local X_UIS     = game:GetService("UserInputService")
local X_Players = game:GetService("Players")
local X_Http    = game:GetService("HttpService")
local X_Tween   = game:GetService("TweenService")
local X_Market  = game:GetService("MarketplaceService")
local X_Run     = game:GetService("RunService")

-- ═══════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════
local OrigHDesc  = nil
local CurHDesc   = nil
local KorbloxOn  = false
local HeadlessOn = false
local FOVConns   = {}

-- Saved outfits are kept in memory as live HDesc references.
-- They are NOT written to disk (HDesc is a Roblox Instance, not serialisable).
-- Everything else is persisted normally.
local History, ItemHistory, Favorites = {}, {}, {}
local SavedOutfits = {}   -- [name] = HumanoidDescription instance (memory only)

-- ═══════════════════════════════════════════════
-- PERSISTENCE  (SavedOutfits intentionally excluded)
-- ═══════════════════════════════════════════════
local FNAME = "AvatarChangerV96.json"
local function SaveData()
    pcall(function()
        if writefile then
            writefile(FNAME, X_Http:JSONEncode({
                H  = History,
                IH = ItemHistory,
                F  = Favorites,
            }))
        end
    end)
end
local function LoadData()
    pcall(function()
        if isfile and isfile(FNAME) then
            local ok,r = pcall(function() return X_Http:JSONDecode(readfile(FNAME)) end)
            if ok and r then
                History     = r.H  or {}
                ItemHistory = r.IH or {}
                Favorites   = r.F  or {}
            end
        end
    end)
end
LoadData()

-- ═══════════════════════════════════════════════
-- TWEENS
-- ═══════════════════════════════════════════════
local function TW(o,g,t,s,d)
    local tw=X_Tween:Create(o,
        TweenInfo.new(t or .2, s or Enum.EasingStyle.Quart, d or Enum.EasingDirection.Out), g)
    tw:Play(); return tw
end
local function TWBack(o,g,t)
    X_Tween:Create(o,
        TweenInfo.new(t or .34, Enum.EasingStyle.Back, Enum.EasingDirection.Out), g):Play()
end

-- ═══════════════════════════════════════════════
-- COLORS
-- ═══════════════════════════════════════════════
local C = {
    WIN    = Color3.fromRGB(10,10,10),
    PANEL  = Color3.fromRGB(18,18,18),
    CARD   = Color3.fromRGB(26,26,26),
    CHOV   = Color3.fromRGB(36,36,36),
    INPUT  = Color3.fromRGB(20,20,20),
    DIV    = Color3.fromRGB(42,42,42),
    TXT    = Color3.fromRGB(245,245,245),
    SUB    = Color3.fromRGB(112,112,112),
    STR    = Color3.fromRGB(48,48,48),
    STRHI  = Color3.fromRGB(188,188,188),
    WHITE  = Color3.fromRGB(236,236,236),
    BPRI   = Color3.fromRGB(232,232,232),
    BSEC   = Color3.fromRGB(30,30,30),
    BDNG   = Color3.fromRGB(52,20,20),
    BSAV   = Color3.fromRGB(18,36,20),
    BFAV   = Color3.fromRGB(40,32,12),
    BTOG   = Color3.fromRGB(44,44,44),
    NOK    = Color3.fromRGB(168,168,168),
    NERR   = Color3.fromRGB(210,65,65),
    NSAV   = Color3.fromRGB(75,188,95),
    NFAV   = Color3.fromRGB(208,155,45),
}

-- ═══════════════════════════════════════════════
-- NOTIFICATIONS
-- ═══════════════════════════════════════════════
local NGui = Instance.new("ScreenGui", X_Player.PlayerGui)
NGui.Name = "X_NGuiV96"; NGui.ResetOnSpawn = false; NGui.DisplayOrder = 99

local nQ, nBusy = {}, false
local function Pump()
    if nBusy or #nQ == 0 then return end
    nBusy = true
    local msg, clr = table.unpack(table.remove(nQ, 1))
    clr = clr or C.NOK

    local bg = Instance.new("Frame", NGui)
    bg.Size = UDim2.new(0,230,0,40)
    bg.Position = UDim2.new(1,16,1,-62)
    bg.BackgroundColor3 = Color3.fromRGB(14,14,14)
    bg.BorderSizePixel = 0; bg.ZIndex = 20
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0,10)
    local sk = Instance.new("UIStroke", bg); sk.Color = clr; sk.Thickness = 1.2

    local bar = Instance.new("Frame", bg)
    bar.Size = UDim2.new(0,3,1,-10); bar.Position = UDim2.new(0,7,0,5)
    bar.BackgroundColor3 = clr; bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)

    local lbl = Instance.new("TextLabel", bg)
    lbl.Size = UDim2.new(1,-22,1,0); lbl.Position = UDim2.new(0,18,0,0)
    lbl.Text = msg; lbl.TextColor3 = C.TXT; lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 21

    bg:TweenPosition(UDim2.new(1,-248,1,-62), "Out","Back",.34, true)
    task.delay(2.6, function()
        TW(bg, {Position=UDim2.new(1,16,1,-62)}, .25)
        task.delay(.27, function() bg:Destroy(); nBusy=false; Pump() end)
    end)
end
local function Notify(msg, clr) table.insert(nQ,{msg,clr}); Pump() end

-- ═══════════════════════════════════════════════
-- FOV FIX
-- ═══════════════════════════════════════════════
local function ApplyFOV(char, hide)
    if not char then return end
    for _,n in ipairs({
        "Right Arm","Left Arm",
        "RightUpperArm","RightLowerArm","RightHand",
        "LeftUpperArm","LeftLowerArm","LeftHand"
    }) do
        local p = char:FindFirstChild(n)
        if p and p:IsA("BasePart") then
            if not p:FindFirstChild("_OT") then
                local v = Instance.new("NumberValue", p)
                v.Name = "_OT"; v.Value = p.Transparency
            end
            p.Transparency = hide and 1 or (p:FindFirstChild("_OT") and p._OT.Value or 0)
        end
    end
    -- Keep accessories visible in first-person
    for _,v in pairs(char:GetChildren()) do
        if v:IsA("Accessory") then
            local h = v:FindFirstChild("Handle")
            if h then h.LocalTransparencyModifier = 0 end
        end
    end
end

local function StartFOV()
    for _,c in pairs(FOVConns) do c:Disconnect() end
    FOVConns = {}
    local cam = workspace.CurrentCamera
    local last = nil
    local conn = X_Run.RenderStepped:Connect(function()
        local char = X_Player.Character; if not char then return end
        cam = workspace.CurrentCamera
        local head = char:FindFirstChild("Head"); if not head then return end
        local inFOV = (cam.CFrame.Position - head.Position).Magnitude < 1.2
        if inFOV ~= last then
            last = inFOV
            ApplyFOV(char, inFOV)
        end
    end)
    table.insert(FOVConns, conn)
end

-- ═══════════════════════════════════════════════
-- KORBLOX
-- ═══════════════════════════════════════════════
local function DoKorblox(on)
    local char = X_Player.Character; if not char then return end
    for _,v in pairs(char:GetChildren()) do
        if v.Name == "VKB" then v:Destroy() end
    end
    if on then
        local p = Instance.new("Part", char)
        p.Name = "VKB"; p.Size = Vector3.new(1,2,1); p.CanCollide = false
        local m = Instance.new("SpecialMesh", p)
        m.MeshId    = "rbxassetid://902942096"
        m.TextureId = "rbxassetid://902843398"
        m.Scale     = Vector3.new(1.2,1.2,1.2)
        local leg = char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg")
        if leg then
            local w = Instance.new("Weld", p)
            w.Part0 = leg; w.Part1 = p
            w.C0 = (leg.Name == "Right Leg")
                and CFrame.new(0,.6,-.1)
                or  CFrame.new(0,.15,0)
        end
        for _,n in ipairs({"RightUpperLeg","RightLowerLeg","RightFoot","Right Leg"}) do
            local pt = char:FindFirstChild(n); if pt then pt.Transparency = 1 end
        end
    else
        for _,n in ipairs({"RightUpperLeg","RightLowerLeg","RightFoot","Right Leg"}) do
            local pt = char:FindFirstChild(n); if pt then pt.Transparency = 0 end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- CORE APPLY — HumanoidDescription-first, works on any rig
-- ═══════════════════════════════════════════════════════════════
local function ApplyHDesc(hDesc, isReset)
    if not hDesc then
        Notify(isReset and "Reset Failed" or "Apply Failed", C.NERR); return
    end
    local char = X_Player.Character; if not char then return end
    local hum  = char:FindFirstChildOfClass("Humanoid"); if not hum then return end

    -- ApplyDescription handles: face, shirt, pants, accessories,
    -- body colors, body scale, body type, all animations — rig-safe.
    local ok, err = pcall(function() hum:ApplyDescription(hDesc) end)
    if not ok then
        Notify("Error: "..(tostring(err):sub(1,40)), C.NERR); return
    end

    CurHDesc = hDesc

    -- Post-apply work in a separate thread so we never yield the caller
    task.spawn(function()
        task.wait(0.06)
        local c2 = X_Player.Character; if not c2 then return end
        local head = c2:FindFirstChild("Head")
        if head then
            head.Transparency = HeadlessOn and 1 or 0
            for _,v in pairs(head:GetChildren()) do
                if v:IsA("Decal") then v.Transparency = HeadlessOn and 1 or 0 end
            end
        end
        DoKorblox(KorbloxOn)
        StartFOV()
    end)

    Notify(isReset and "Avatar Reset" or "Avatar Applied",
           isReset and C.NERR or C.NOK)
end

-- ═══════════════════════════════════════════════
-- CHANGE AVATAR
-- ═══════════════════════════════════════════════
local function ChangeAvatar(input)
    input = tostring(input):match("^%s*(.-)%s*$")
    if input == "" then Notify("Enter a username or ID", C.NERR); return end

    -- Resolve to a userId.
    -- Strategy: always try GetUserIdFromNameAsync first (handles both usernames
    -- and numeric usernames). Only treat as raw userId if that fails AND input is numeric.
    local uid
    local ok1, res1 = pcall(function()
        return X_Players:GetUserIdFromNameAsync(input)
    end)
    if ok1 and res1 then
        uid = res1
    else
        local n = tonumber(input:match("^%d+$"))
        if n then uid = n
        else Notify("User not found", C.NERR); return end
    end

    -- Deduplicate & push to history
    for i, e in ipairs(History) do
        if (type(e)=="table" and e.name==input) or e==input then
            table.remove(History, i); break
        end
    end
    table.insert(History, 1, {name=input, time=os.time()})
    if #History > 30 then table.remove(History) end
    SaveData()

    -- Fetch HumanoidDescription (face + clothes + accessories + body + anims)
    local hDesc
    local ok2, res2 = pcall(function()
        return X_Players:GetHumanoidDescriptionFromUserId(uid)
    end)
    if ok2 and res2 then
        hDesc = res2
    else
        Notify("Could not fetch avatar", C.NERR); return
    end

    ApplyHDesc(hDesc, false)
end

-- ═══════════════════════════════════════════════
-- WEAR SINGLE ITEM
-- ═══════════════════════════════════════════════
local function GetTemplate(id)
    local ok, a = pcall(function() return game:GetObjects("rbxassetid://"..id)[1] end)
    if ok and a then
        local t = ""
        if a:IsA("Shirt")       then t = a.ShirtTemplate
        elseif a:IsA("Pants")   then t = a.PantsTemplate
        elseif a:IsA("ShirtGraphic") then t = a.Graphic end
        a:Destroy()
        return t ~= "" and t or ("rbxassetid://"..id)
    end
    return "rbxassetid://"..id
end

local function WeldAcc(acc, char)
    local h = acc:FindFirstChild("Handle"); if not char or not h then return end
    local att = h:FindFirstChildOfClass("Attachment")
    local tar = att and char:FindFirstChild(att.Name, true)
    acc.Parent = char
    if tar then
        local w = Instance.new("Weld", h)
        w.Part0 = h; w.Part1 = tar.Parent
        w.C0 = att.CFrame; w.C1 = tar.CFrame
    end
end

local function WearSingleItem(id)
    local char = X_Player.Character; if not char then return false end
    local ok, info = pcall(function() return X_Market:GetProductInfo(tonumber(id)) end)
    if ok and info then
        if info.AssetTypeId == 11 then   -- Shirt
            local s = char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt", char)
            s.ShirtTemplate = GetTemplate(id)
            Notify("Shirt Applied", C.NOK); return true
        elseif info.AssetTypeId == 12 then  -- Pants
            local p = char:FindFirstChildOfClass("Pants") or Instance.new("Pants", char)
            p.PantsTemplate = GetTemplate(id)
            Notify("Pants Applied", C.NOK); return true
        end
    end
    local ok2, asset = pcall(function() return game:GetObjects("rbxassetid://"..id)[1] end)
    if ok2 and asset then
        if asset:IsA("Accessory") then WeldAcc(asset, char)
        else asset.Parent = char end
        Notify("Item Added", C.NOK); return true
    end
    return false
end

-- ═══════════════════════════════════════════════
-- INJECT BODY / FACE / HEAD
-- ═══════════════════════════════════════════════
local function InjectPart(id)
    local char = X_Player.Character; if not char then return false end
    local cid = tostring(id):match("%d+"); if not cid then return false end
    local head = char:FindFirstChild("Head")
    local ok, info = pcall(function() return X_Market:GetProductInfo(tonumber(cid)) end)
    if ok and info then
        local t = info.AssetTypeId
        if t == 18 then   -- Face (NOT type 1 which is generic Image)
            if head then
                local f = head:FindFirstChild("face") or Instance.new("Decal", head)
                f.Name = "face"; f.Texture = "rbxassetid://"..cid
                Notify("Face Injected", C.NOK); return true
            end
        elseif t == 17 or t == 24 then  -- Head mesh
            if head then
                local m = head:FindFirstChildOfClass("SpecialMesh")
                    or Instance.new("SpecialMesh", head)
                m.MeshId = "rbxassetid://"..cid
                Notify("Head Injected", C.NOK); return true
            end
        elseif t >= 27 and t <= 31 then  -- Body parts
            local ok2, a = pcall(function() return game:GetObjects("rbxassetid://"..cid)[1] end)
            if ok2 and a then
                a.Parent = char
                Notify("Body Part Injected", C.NOK); return true
            end
        end
    end
    Notify("ID not recognised", C.NERR)
    return false
end

-- ═══════════════════════════════════════════════════════════════
--   U I   (V96: slightly smaller — 268×510 window)
-- ═══════════════════════════════════════════════════════════════
local WIN_W, WIN_H = 268, 510
local Gui = Instance.new("ScreenGui", X_Player.PlayerGui)
Gui.Name = "AvatarChangerV96"; Gui.ResetOnSpawn = false; Gui.DisplayOrder = 10

-- ── Main window ────────────────────────────────────────────────
local Main = Instance.new("Frame", Gui)
Main.Name = "Main"
Main.Size = UDim2.new(0,WIN_W,0,WIN_H)
Main.Position = UDim2.new(.5,-WIN_W/2,.5,-WIN_H/2)
Main.BackgroundColor3 = C.WIN; Main.Active = true
Main.ClipsDescendants = true; Main.Visible = false
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,14)
local wSK = Instance.new("UIStroke", Main); wSK.Color = C.STR; wSK.Thickness = 1.3

-- Gradient top accent
local tLine = Instance.new("Frame", Main)
tLine.Size = UDim2.new(1,0,0,2); tLine.BackgroundColor3 = C.WHITE
tLine.BorderSizePixel = 0; tLine.ZIndex = 6
Instance.new("UIGradient", tLine).Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(18,18,18)),
    ColorSequenceKeypoint.new(.22, C.WHITE),
    ColorSequenceKeypoint.new(.78, C.WHITE),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(18,18,18)),
})

-- ── Header (48px) ──────────────────────────────────────────────
local HDR = Instance.new("Frame", Main)
HDR.Size = UDim2.new(1,0,0,48); HDR.Position = UDim2.new(0,0,0,2)
HDR.BackgroundColor3 = C.PANEL; HDR.BorderSizePixel = 0; HDR.ZIndex = 4
local hDiv = Instance.new("Frame", HDR)
hDiv.Size = UDim2.new(1,0,0,1); hDiv.Position = UDim2.new(0,0,1,-1)
hDiv.BackgroundColor3 = C.DIV; hDiv.BorderSizePixel = 0; hDiv.ZIndex = 5

local TitleL = Instance.new("TextLabel", HDR)
TitleL.Size = UDim2.new(0,190,0,22); TitleL.Position = UDim2.new(0,14,0,8)
TitleL.Text = "AVATAR CHANGER"
TitleL.TextColor3 = C.TXT; TitleL.Font = Enum.Font.GothamBold; TitleL.TextSize = 13
TitleL.BackgroundTransparency = 1
TitleL.TextXAlignment = Enum.TextXAlignment.Left; TitleL.ZIndex = 5

local VerL = Instance.new("TextLabel", HDR)
VerL.Size = UDim2.new(0,190,0,13); VerL.Position = UDim2.new(0,14,0,30)
VerL.Text = "V96  ·  by XYTHC"
VerL.TextColor3 = C.SUB; VerL.Font = Enum.Font.Gotham; VerL.TextSize = 9
VerL.BackgroundTransparency = 1
VerL.TextXAlignment = Enum.TextXAlignment.Left; VerL.ZIndex = 5

local CloseBtn = Instance.new("TextButton", HDR)
CloseBtn.Size = UDim2.new(0,26,0,26); CloseBtn.Position = UDim2.new(1,-36,0,11)
CloseBtn.BackgroundColor3 = Color3.fromRGB(34,34,34); CloseBtn.Text = "✕"
CloseBtn.TextColor3 = C.SUB; CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12; CloseBtn.ZIndex = 5
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0,7)
CloseBtn.MouseEnter:Connect(function() TW(CloseBtn,{TextColor3=Color3.fromRGB(228,75,75)},.12) end)
CloseBtn.MouseLeave:Connect(function() TW(CloseBtn,{TextColor3=C.SUB},.12) end)

-- ── Tab bar (32px) ─────────────────────────────────────────────
local TabBar = Instance.new("Frame", Main)
TabBar.Size = UDim2.new(1,-20,0,32); TabBar.Position = UDim2.new(0,10,0,56)
TabBar.BackgroundColor3 = C.CARD; TabBar.ZIndex = 4
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0,9)

local function MkTab(txt, xs, active)
    local b = Instance.new("TextButton", TabBar)
    b.Size = UDim2.new(.5,-4,1,-6)
    b.Position = UDim2.new(xs, xs==0 and 3 or 1, 0, 3)
    b.BackgroundColor3 = active and C.WHITE or Color3.fromRGB(0,0,0)
    b.BackgroundTransparency = active and 0 or 1
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 10; b.ZIndex = 5
    b.TextColor3 = active and C.WIN or C.SUB
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    return b
end
local TAB_C = MkTab("CHANGER", 0,   true)
local TAB_H = MkTab("HISTORY", .5, false)

-- ── Scroll pages (start at y=94) ───────────────────────────────
local PY = 94
local PageC = Instance.new("ScrollingFrame", Main)
PageC.Size = UDim2.new(1,0,1,-PY); PageC.Position = UDim2.new(0,0,0,PY)
PageC.BackgroundTransparency = 1; PageC.ScrollBarThickness = 3
PageC.ScrollBarImageColor3 = Color3.fromRGB(60,60,60); PageC.BorderSizePixel = 0

local PageH = Instance.new("ScrollingFrame", Main)
PageH.Size = UDim2.new(1,0,1,-PY); PageH.Position = UDim2.new(0,0,0,PY)
PageH.BackgroundTransparency = 1; PageH.ScrollBarThickness = 3
PageH.ScrollBarImageColor3 = Color3.fromRGB(60,60,60)
PageH.Visible = false; PageH.BorderSizePixel = 0

-- ── Changer page content ───────────────────────────────────────
local PAD = 11
local cY  = 10   -- running Y cursor inside PageC

local function Sep(txt)
    local L = Instance.new("TextLabel", PageC)
    L.Size = UDim2.new(1,-PAD*2,0,14); L.Position = UDim2.new(0,PAD,0,cY)
    L.BackgroundTransparency = 1; L.Text = txt; L.TextColor3 = C.SUB
    L.Font = Enum.Font.GothamBold; L.TextSize = 9
    L.TextXAlignment = Enum.TextXAlignment.Left; L.ZIndex = 4
    local d = Instance.new("Frame", PageC)
    d.Size = UDim2.new(1,-PAD*2,0,1); d.Position = UDim2.new(0,PAD,0,cY+14)
    d.BackgroundColor3 = C.DIV; d.BorderSizePixel = 0; d.ZIndex = 4
    cY = cY + 20
end

-- Input box (38px tall)
local IW = Instance.new("Frame", PageC)
IW.Size = UDim2.new(1,-PAD*2,0,38); IW.Position = UDim2.new(0,PAD,0,cY)
IW.BackgroundColor3 = C.INPUT; IW.ZIndex = 4
Instance.new("UICorner", IW).CornerRadius = UDim.new(0,10)
local iSK = Instance.new("UIStroke", IW); iSK.Color = C.STR; iSK.Thickness = 1

local iIco = Instance.new("TextLabel", IW)
iIco.Size = UDim2.new(0,34,1,0); iIco.Text = "  "
iIco.TextColor3 = C.SUB; iIco.BackgroundTransparency = 1
iIco.Font = Enum.Font.GothamBold; iIco.TextSize = 14; iIco.ZIndex = 5

local Box = Instance.new("TextBox", IW)
Box.Size = UDim2.new(1,-36,1,0); Box.Position = UDim2.new(0,32,0,0)
Box.BackgroundTransparency = 1; Box.Text = ""
Box.PlaceholderText = "Username / Item ID..."
Box.PlaceholderColor3 = C.SUB; Box.TextColor3 = C.TXT
Box.Font = Enum.Font.Gotham; Box.TextSize = 12; Box.ZIndex = 5
Box.ClearTextOnFocus = false
Box.Focused:Connect(function()  TW(iSK,{Color=C.STRHI,Thickness=1.5},.15) end)
Box.FocusLost:Connect(function() TW(iSK,{Color=C.STR, Thickness=1},  .15) end)
cY = cY + 47

-- Button factory (34px default)
local function MkBtn(txt, bg, fg, bh)
    bh = bh or 34
    local card = Instance.new("Frame", PageC)
    card.Size = UDim2.new(1,-PAD*2,0,bh)
    card.Position = UDim2.new(0,PAD,0,cY)
    card.BackgroundColor3 = bg; card.ZIndex = 4
    Instance.new("UICorner", card).CornerRadius = UDim.new(0,10)
    if bg ~= C.BPRI then
        local sk = Instance.new("UIStroke", card); sk.Color = C.DIV; sk.Thickness = 1
    end
    cY = cY + bh + 7

    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1
    btn.Text = txt; btn.TextColor3 = fg or C.TXT
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 11; btn.ZIndex = 5

    btn.MouseEnter:Connect(function()
        TW(card,{BackgroundColor3=Color3.new(
            math.min(bg.R+.07,1), math.min(bg.G+.07,1), math.min(bg.B+.07,1))},.12)
    end)
    btn.MouseLeave:Connect(function() TW(card,{BackgroundColor3=bg},.12) end)
    btn.MouseButton1Down:Connect(function()
        TW(card,{Size=UDim2.new(1,-PAD*2-4,0,bh-3)},.07)
    end)
    btn.MouseButton1Up:Connect(function()
        TW(card,{Size=UDim2.new(1,-PAD*2,0,bh)},.16)
    end)
    return btn, card
end

-- Toggle factory — state variable lives inside the closure.
-- The onToggle callback receives the new boolean state so the
-- caller never needs a separate MouseButton1Click connection.
local function MkToggle(txtOff, txtOn, bgOff, bgOn, fgOff, fgOn, onToggle)
    local btn, card = MkBtn(txtOff, bgOff, fgOff)
    local state = false

    local function Sync(v)
        state = v
        btn.Text      = v and txtOn  or txtOff
        TW(btn,  {TextColor3 = v and (fgOn  or C.TXT) or (fgOff or C.SUB)}, .15)
        TW(card, {BackgroundColor3 = v and bgOn or bgOff}, .15)
        local sk = card:FindFirstChildOfClass("UIStroke")
        if sk then TW(sk,{Color = v and C.STRHI or C.DIV},.15) end
    end

    btn.MouseButton1Click:Connect(function()
        Sync(not state)
        if onToggle then onToggle(state) end
    end)

    -- Return setter so reset button can force both to OFF
    return btn, card, function(v) Sync(v) end
end

-- ── Build changer page ─────────────────────────────────────────
Sep("AVATAR")
local B_CHANGE = MkBtn("  CHANGE AVATAR",          C.BPRI, C.WIN)
local B_WEAR   = MkBtn("  WEAR ITEM / ID",          C.BSEC, C.TXT)
local B_INJ    = MkBtn("  INJECT BODY / FACE / HEAD", C.BSEC, C.TXT)

Sep("TOGGLES")
local _,_,SetKB = MkToggle(
    "  KORBLOX: OFF", "  KORBLOX: ON",
    C.BSEC, C.BTOG, C.SUB, C.TXT,
    function(v) KorbloxOn=v; DoKorblox(v) end
)
local _,_,SetHL = MkToggle(
    "  HEADLESS: OFF", "  HEADLESS: ON",
    C.BSEC, C.BTOG, C.SUB, C.TXT,
    function(v)
        HeadlessOn=v
        local char=X_Player.Character; if not char then return end
        local head=char:FindFirstChild("Head"); if not head then return end
        head.Transparency = v and 1 or 0
        for _,c in pairs(head:GetChildren()) do
            if c:IsA("Decal") then c.Transparency = v and 1 or 0 end
        end
    end
)

Sep("MANAGE")
local B_FAV   = MkBtn("  ADD TO FAVORITES",    C.BFAV, Color3.fromRGB(208,165,55))
local B_SAVO  = MkBtn("  SAVE CURRENT OUTFIT",  C.BSAV, Color3.fromRGB(75,196,95))
local B_RESET = MkBtn("  RESET AVATAR",          C.BDNG, Color3.fromRGB(218,85,85))

PageC.CanvasSize = UDim2.new(0,0,0,cY+10)

-- ── Button actions ─────────────────────────────────────────────
B_CHANGE.MouseButton1Click:Connect(function()
    ChangeAvatar(Box.Text)
end)

B_WEAR.MouseButton1Click:Connect(function()
    local cid = Box.Text:match("%d+")
    if not cid then Notify("No ID found", C.NERR); return end
    if WearSingleItem(cid) then
        -- deduplicate item history
        for i,e in ipairs(ItemHistory) do
            if (type(e)=="table" and e.id==cid) or e==cid then
                table.remove(ItemHistory,i); break
            end
        end
        table.insert(ItemHistory,1,{id=cid, time=os.time()})
        if #ItemHistory > 30 then table.remove(ItemHistory) end
        SaveData()
    else
        Notify("Item not found", C.NERR)
    end
end)

B_INJ.MouseButton1Click:Connect(function()
    local cid = Box.Text:match("%d+")
    if not cid then Notify("No ID found", C.NERR); return end
    InjectPart(cid)
end)

B_FAV.MouseButton1Click:Connect(function()
    local txt = Box.Text:match("^%s*(.-)%s*$")
    if txt == "" then Notify("Enter something first", C.NERR); return end
    if table.find(Favorites, txt) then
        Notify("Already in Favorites", C.NERR); return
    end
    table.insert(Favorites, txt); SaveData()
    Notify("Added to Favorites", C.NFAV)
end)

B_SAVO.MouseButton1Click:Connect(function()
    if not CurHDesc then Notify("No outfit applied yet", C.NERR); return end
    local name = Box.Text:match("^%s*(.-)%s*$")
    name = (name ~= "") and name or ("Outfit "..os.date("%H:%M"))
    -- Store only in memory (HDesc is a Roblox Instance, cannot be JSON-encoded)
    SavedOutfits[name] = CurHDesc
    Notify("Saved: "..name, C.NSAV)
end)

B_RESET.MouseButton1Click:Connect(function()
    KorbloxOn  = false
    HeadlessOn = false
    SetKB(false)
    SetHL(false)
    ApplyHDesc(OrigHDesc, true)
end)

-- ── History page helpers ───────────────────────────────────────
local function FmtTime(t)
    if not t then return nil end
    local d = os.time() - t
    if d < 60      then return d.."s ago"
    elseif d < 3600 then return math.floor(d/60).."m ago"
    else                 return math.floor(d/3600).."h ago" end
end

local function MkHCard(par, mainTxt, subTxt, bg, onClick)
    local h = subTxt and 42 or 36
    local card = Instance.new("Frame", par)
    card.Size = UDim2.new(1,-20,0,h)
    card.BackgroundColor3 = bg or C.CARD; card.ZIndex = 4
    Instance.new("UICorner", card).CornerRadius = UDim.new(0,9)
    local sk = Instance.new("UIStroke", card); sk.Color = C.DIV; sk.Thickness = 1

    local lbl = Instance.new("TextButton", card)
    lbl.Size = UDim2.new(1,-40, subTxt and 0 or 1, subTxt and 20 or 0)
    lbl.Position = UDim2.new(0,10, 0, subTxt and 4 or 0)
    lbl.BackgroundTransparency = 1; lbl.Text = mainTxt; lbl.TextColor3 = C.TXT
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 5
    lbl.TextTruncate = Enum.TextTruncate.AtEnd

    if subTxt then
        local s = Instance.new("TextLabel", card)
        s.Size = UDim2.new(1,-40,0,13); s.Position = UDim2.new(0,10,0,22)
        s.BackgroundTransparency = 1; s.Text = subTxt; s.TextColor3 = C.SUB
        s.Font = Enum.Font.Gotham; s.TextSize = 9
        s.TextXAlignment = Enum.TextXAlignment.Left; s.ZIndex = 5
    end

    if onClick then
        lbl.MouseButton1Click:Connect(onClick)
        lbl.MouseEnter:Connect(function()  TW(card,{BackgroundColor3=C.CHOV},.1) end)
        lbl.MouseLeave:Connect(function()  TW(card,{BackgroundColor3=bg or C.CARD},.1) end)
    end
    return card
end

local function MkSecLbl(par, txt, lo)
    local l = Instance.new("TextLabel", par)
    l.Size = UDim2.new(1,-20,0,18); l.BackgroundTransparency = 1
    l.Text = txt; l.TextColor3 = C.STRHI; l.Font = Enum.Font.GothamBold; l.TextSize = 9
    l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 4; l.LayoutOrder = lo
    return l
end

local function MkDelBtn(par, cb)
    local d = Instance.new("TextButton", par)
    d.Size = UDim2.new(0,24,0,24); d.Position = UDim2.new(1,-30,.5,-12)
    d.BackgroundColor3 = Color3.fromRGB(42,16,16); d.Text = "✕"
    d.TextColor3 = Color3.fromRGB(188,65,65)
    d.Font = Enum.Font.GothamBold; d.TextSize = 10; d.ZIndex = 6
    Instance.new("UICorner", d).CornerRadius = UDim.new(0,6)
    d.MouseButton1Click:Connect(cb)
end

local function GoChanger(txt)
    if txt then Box.Text = txt end
    PageH.Visible = false; PageC.Visible = true
    TW(TAB_C,{BackgroundColor3=C.WHITE,BackgroundTransparency=0,TextColor3=C.WIN},.15)
    TW(TAB_H,{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,TextColor3=C.SUB},.15)
end

local function BuildHistory()
    -- Clear all children except layout/padding instances
    for _,v in pairs(PageH:GetChildren()) do
        if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then v:Destroy() end
    end

    local lay = Instance.new("UIListLayout", PageH)
    lay.Padding = UDim.new(0,6)
    lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", PageH)
    pad.PaddingTop = UDim.new(0,8)

    local lo = 1
    local hasAnything = false

    -- Saved outfits (memory only)
    if next(SavedOutfits) then
        hasAnything = true
        MkSecLbl(PageH,"  SAVED OUTFITS", lo); lo=lo+1
        for name, hDesc in pairs(SavedOutfits) do
            local c = MkHCard(PageH, name, nil, Color3.fromRGB(16,30,18), function()
                ApplyHDesc(hDesc, false)
                Notify("Loaded: "..name, C.NSAV)
            end)
            c.LayoutOrder = lo; lo=lo+1
            MkDelBtn(c, function()
                SavedOutfits[name] = nil; BuildHistory()
            end)
        end
    end

    -- Favorites
    if #Favorites > 0 then
        hasAnything = true
        MkSecLbl(PageH,"  FAVORITES", lo); lo=lo+1
        for idx, fav in ipairs(Favorites) do
            local c = MkHCard(PageH, fav, nil, Color3.fromRGB(34,24,8),
                function() GoChanger(fav) end)
            c.LayoutOrder = lo; lo=lo+1
            local di = idx
            MkDelBtn(c, function()
                table.remove(Favorites, di); SaveData(); BuildHistory()
            end)
        end
    end

    -- Avatar history
    if #History > 0 then
        hasAnything = true
        MkSecLbl(PageH,"  AVATAR HISTORY", lo); lo=lo+1
        for _,e in ipairs(History) do
            local name = type(e)=="table" and e.name or tostring(e)
            local ts   = type(e)=="table" and FmtTime(e.time) or nil
            local c = MkHCard(PageH, name, ts, C.CARD,
                function() GoChanger(name) end)
            c.LayoutOrder = lo; lo=lo+1
        end
    end

    -- Item history
    if #ItemHistory > 0 then
        hasAnything = true
        MkSecLbl(PageH,"  ITEM HISTORY", lo); lo=lo+1
        for _,e in ipairs(ItemHistory) do
            local id = type(e)=="table" and e.id or tostring(e)
            local ts = type(e)=="table" and FmtTime(e.time) or nil
            local c = MkHCard(PageH, "ID: "..id, ts, C.CARD,
                function() GoChanger(id) end)
            c.LayoutOrder = lo; lo=lo+1
        end
    end

    -- Empty state
    if not hasAnything then
        local e = Instance.new("TextLabel", PageH)
        e.Size = UDim2.new(1,0,0,50); e.BackgroundTransparency = 1
        e.Text = "Nothing saved yet"
        e.TextColor3 = C.SUB; e.Font = Enum.Font.Gotham; e.TextSize = 11
        e.ZIndex = 4; e.LayoutOrder = 1
    end

    -- Clear history button
    if #History > 0 or #ItemHistory > 0 then
        local clr = Instance.new("TextButton", PageH)
        clr.Size = UDim2.new(1,-20,0,30)
        clr.BackgroundColor3 = Color3.fromRGB(36,14,14)
        clr.Text = "  CLEAR HISTORY"
        clr.TextColor3 = Color3.fromRGB(188,65,65)
        clr.Font = Enum.Font.GothamBold; clr.TextSize = 10
        clr.ZIndex = 4; clr.LayoutOrder = lo + 999
        Instance.new("UICorner", clr).CornerRadius = UDim.new(0,9)
        clr.MouseButton1Click:Connect(function()
            History = {}; ItemHistory = {}; SaveData(); BuildHistory()
            Notify("History Cleared", C.NERR)
        end)
    end

    task.wait()
    PageH.CanvasSize = UDim2.new(0,0,0, lay.AbsoluteContentSize.Y + 22)
end

-- Tab switching
TAB_H.MouseButton1Click:Connect(function()
    PageC.Visible=false; PageH.Visible=true; BuildHistory()
    TW(TAB_H,{BackgroundColor3=C.WHITE,BackgroundTransparency=0,TextColor3=C.WIN},.15)
    TW(TAB_C,{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,TextColor3=C.SUB},.15)
end)
TAB_C.MouseButton1Click:Connect(function()
    PageH.Visible=false; PageC.Visible=true
    TW(TAB_C,{BackgroundColor3=C.WHITE,BackgroundTransparency=0,TextColor3=C.WIN},.15)
    TW(TAB_H,{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,TextColor3=C.SUB},.15)
end)

-- ── Floating icon ──────────────────────────────────────────────
local Ico = Instance.new("TextButton", Gui)
Ico.Size = UDim2.new(0,46,0,46); Ico.Position = UDim2.new(0,13,0,13)
Ico.BackgroundColor3 = Color3.fromRGB(15,15,15); Ico.Text = ""; Ico.ZIndex = 5
Instance.new("UICorner", Ico).CornerRadius = UDim.new(0,13)
local icoSK = Instance.new("UIStroke", Ico); icoSK.Color = C.STR; icoSK.Thickness = 1.2

local icoL = Instance.new("TextLabel", Ico)
icoL.Size = UDim2.new(1,0,.65,0); icoL.Position = UDim2.new(0,0,.1,0)
icoL.Text = ""; icoL.TextSize = 20; icoL.BackgroundTransparency = 1
icoL.ZIndex = 6; icoL.Font = Enum.Font.Gotham

local Dot = Instance.new("Frame", Ico)
Dot.Size = UDim2.new(0,9,0,9); Dot.Position = UDim2.new(1,-11,0,2)
Dot.BackgroundColor3 = Color3.fromRGB(218,50,50); Dot.ZIndex = 7
Instance.new("UICorner", Dot).CornerRadius = UDim.new(1,0)

local function SetDot(open)
    TW(Dot,{BackgroundColor3 = open
        and Color3.fromRGB(85,212,105)
        or  Color3.fromRGB(218,50,50)}, .2)
end

Ico.MouseEnter:Connect(function()
    TWBack(Ico,{Size=UDim2.new(0,50,0,50),Position=UDim2.new(0,11,0,11)},.2)
    TW(icoSK,{Color=C.STRHI},.13)
end)
Ico.MouseLeave:Connect(function()
    TWBack(Ico,{Size=UDim2.new(0,46,0,46),Position=UDim2.new(0,13,0,13)},.2)
    TW(icoSK,{Color=C.STR},.13)
end)

local function OpenWin()
    Main.Size = UDim2.new(0,0,0,0)
    Main.Position = UDim2.new(.5,0,.5,0)
    Main.Visible = true
    TWBack(Main,{Size=UDim2.new(0,WIN_W,0,WIN_H),Position=UDim2.new(.5,-WIN_W/2,.5,-WIN_H/2)},.38)
    SetDot(true)
end
local function CloseWin()
    TW(Main,{Size=UDim2.new(0,0,0,0),Position=UDim2.new(.5,0,.5,0)},.18)
    task.delay(.2, function() Main.Visible = false end)
    SetDot(false)
end

Ico.MouseButton1Click:Connect(function()
    if not Main.Visible then OpenWin() else CloseWin() end
end)
CloseBtn.MouseButton1Click:Connect(CloseWin)

-- ── Drag (header drags window; icon drags itself) ──────────────
local function Drag(obj, handle)
    local dragging, inp, startPos, startObjPos
    handle.InputBegan:Connect(function(x)
        if x.UserInputType == Enum.UserInputType.MouseButton1
        or x.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startPos = x.Position
            startObjPos = obj.Position
            x.Changed:Connect(function()
                if x.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    handle.InputChanged:Connect(function(x)
        if x.UserInputType == Enum.UserInputType.MouseMovement
        or x.UserInputType == Enum.UserInputType.Touch then
            inp = x
        end
    end)
    X_UIS.InputChanged:Connect(function(x)
        if x == inp and dragging then
            local d = x.Position - startPos
            obj.Position = UDim2.new(
                startObjPos.X.Scale, startObjPos.X.Offset + d.X,
                startObjPos.Y.Scale, startObjPos.Y.Offset + d.Y)
        end
    end)
end
Drag(Main, HDR)
Drag(Ico,  Ico)

-- ═══════════════════════════════════════════════
-- RESPAWN — reapply last outfit automatically
-- ═══════════════════════════════════════════════
X_Player.CharacterAdded:Connect(function()
    task.wait(0.8)
    local desc = CurHDesc or OrigHDesc
    if desc then ApplyHDesc(desc, CurHDesc == nil) end
    task.spawn(StartFOV)
end)

-- ═══════════════════════════════════════════════
-- INIT — capture original HumanoidDescription
-- ═══════════════════════════════════════════════
local initChar = X_Player.Character or X_Player.CharacterAdded:Wait()

-- Primary: read from humanoid (most accurate, reflects current game state)
pcall(function()
    local hum = initChar:FindFirstChildOfClass("Humanoid")
    if hum then OrigHDesc = hum:GetAppliedDescription() end
end)
-- Fallback: fetch from Roblox API
if not OrigHDesc then
    pcall(function()
        OrigHDesc = X_Players:GetHumanoidDescriptionFromUserId(X_Player.UserId)
    end)
end

task.spawn(StartFOV)
Notify("Avatar Changer V96  Ready", C.NOK)
