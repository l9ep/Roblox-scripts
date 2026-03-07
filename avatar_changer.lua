-- AVATAR CHANGER
-- V93: HEAD FIX + ANIMATIONS + BODY SCALE + R6/R15 FULL COMPAT (XYTHC)

local X_Player    = game:GetService("Players").LocalPlayer
local X_UIS       = game:GetService("UserInputService")
local X_Players   = game:GetService("Players")
local X_HttpSvc   = game:GetService("HttpService")
local X_Tween     = game:GetService("TweenService")
local X_Market    = game:GetService("MarketplaceService")
local X_Run       = game:GetService("RunService")

local X_OriginalItems    = {}
local X_CurrentItems     = {}
local X_OriginalHDesc    = nil   -- stores original HumanoidDescription for reset
local X_History, X_ItemHistory, X_Favorites, X_SavedOutfits = {}, {}, {}, {}
local X_KorbloxActive, X_HeadlessActive = false, false
local X_FOVConnections = {}

-- ================================================
-- PERSISTENCE
-- ================================================
local FILE_NAME = "AvatarChanger_Data_V93.json"
local function SaveData()
    local data = {H=X_History, IH=X_ItemHistory, F=X_Favorites, SO=X_SavedOutfits}
    pcall(function() if writefile then writefile(FILE_NAME, X_HttpSvc:JSONEncode(data)) end end)
end
local function LoadData()
    if isfile and isfile(FILE_NAME) then
        pcall(function()
            local ok, r = pcall(function() return X_HttpSvc:JSONDecode(readfile(FILE_NAME)) end)
            if ok and r then
                X_History=r.H or {}; X_ItemHistory=r.IH or {}
                X_Favorites=r.F or {}; X_SavedOutfits=r.SO or {}
            end
        end)
    end
end
LoadData()

-- ================================================
-- TWEEN HELPERS
-- ================================================
local function TS(obj, goal, t, style, dir)
    local tw = X_Tween:Create(obj,
        TweenInfo.new(t or 0.22, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), goal)
    tw:Play(); return tw
end
local function TSBack(obj, goal, t)
    X_Tween:Create(obj,
        TweenInfo.new(t or 0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), goal):Play()
end

-- ================================================
-- COLOR PALETTE  (black & white)
-- ================================================
local C = {
    WIN      = Color3.fromRGB(12,  12,  12),
    PANEL    = Color3.fromRGB(20,  20,  20),
    CARD     = Color3.fromRGB(28,  28,  28),
    CARDHOV  = Color3.fromRGB(38,  38,  38),
    INPUT    = Color3.fromRGB(22,  22,  22),
    DIVIDER  = Color3.fromRGB(40,  40,  40),
    TEXT     = Color3.fromRGB(245, 245, 245),
    SUBTEXT  = Color3.fromRGB(130, 130, 130),
    ACCENT   = Color3.fromRGB(220, 220, 220),
    STROKE   = Color3.fromRGB(50,  50,  50),
    STROKEHI = Color3.fromRGB(180, 180, 180),
    WHITE    = Color3.fromRGB(240, 240, 240),
    BTN_PRI  = Color3.fromRGB(235, 235, 235),
    BTN_SEC  = Color3.fromRGB(36,  36,  36),
    BTN_DNGR = Color3.fromRGB(60,  30,  30),
    BTN_SAVE = Color3.fromRGB(28,  40,  28),
    BTN_STAR = Color3.fromRGB(45,  38,  20),
    NTF_OK   = Color3.fromRGB(180, 180, 180),
    NTF_ERR  = Color3.fromRGB(200, 80,  80),
    NTF_SAVE = Color3.fromRGB(90,  180, 110),
    NTF_FAV  = Color3.fromRGB(200, 160, 60),
}

-- ================================================
-- NOTIFICATIONS
-- ================================================
local NotifyGui = Instance.new("ScreenGui", X_Player.PlayerGui)
NotifyGui.Name = "X_NotifyGui_V93"; NotifyGui.ResetOnSpawn=false; NotifyGui.DisplayOrder=99

local nQueue, nBusy = {}, false
local function PumpNotify()
    if nBusy or #nQueue==0 then return end
    nBusy=true
    local msg, clr = table.unpack(table.remove(nQueue,1))
    clr = clr or C.NTF_OK
    local bg=Instance.new("Frame",NotifyGui)
    bg.Size=UDim2.new(0,230,0,42); bg.Position=UDim2.new(1,15,1,-65)
    bg.BackgroundColor3=Color3.fromRGB(16,16,16); bg.BorderSizePixel=0; bg.ZIndex=20
    Instance.new("UICorner",bg).CornerRadius=UDim.new(0,10)
    local sk=Instance.new("UIStroke",bg); sk.Color=clr; sk.Thickness=1.2
    local bar=Instance.new("Frame",bg)
    bar.Size=UDim2.new(0,3,1,-10); bar.Position=UDim2.new(0,7,0,5)
    bar.BackgroundColor3=clr; bar.BorderSizePixel=0
    Instance.new("UICorner",bar).CornerRadius=UDim.new(1,0)
    local lbl=Instance.new("TextLabel",bg)
    lbl.Size=UDim2.new(1,-22,1,0); lbl.Position=UDim2.new(0,18,0,0)
    lbl.Text=msg; lbl.TextColor3=C.TEXT; lbl.BackgroundTransparency=1
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=11
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=21
    bg:TweenPosition(UDim2.new(1,-248,1,-65),"Out","Back",0.38,true)
    task.delay(2.8,function()
        TS(bg,{Position=UDim2.new(1,15,1,-65)},0.3)
        task.delay(0.32,function() bg:Destroy(); nBusy=false; PumpNotify() end)
    end)
end
local function Notify(msg,clr) table.insert(nQueue,{msg,clr}); PumpNotify() end

-- ================================================
-- WELD
-- ================================================
function X_Weld_Internal(acc, char)
    char = char or X_Player.Character
    local h=acc:FindFirstChild("Handle"); if not char or not h then return end
    local att=h:FindFirstChildOfClass("Attachment")
    local tar=char:FindFirstChild(att and att.Name or "HatAttachment", true)
    acc.Parent=char
    if tar then
        local w=Instance.new("Weld",h)
        w.Part0=h; w.Part1=tar.Parent
        w.C0=att and att.CFrame or CFrame.new()
        w.C1=tar.CFrame
    end
end
local function X_Weld(acc) X_Weld_Internal(acc, X_Player.Character) end

-- ================================================
-- FOV FIX
-- ================================================
local function SetFOVTransparency(char, inFOV)
    if not char then return end
    local arms={"RightHand","LeftHand","RightLowerArm","LeftLowerArm",
                "RightUpperArm","LeftUpperArm","Right Arm","Left Arm"}
    for _,name in ipairs(arms) do
        local p=char:FindFirstChild(name)
        if p and p:IsA("BasePart") then
            if not p:FindFirstChild("_OT") then
                local v=Instance.new("NumberValue",p); v.Name="_OT"; v.Value=p.Transparency
            end
            p.Transparency=inFOV and 1 or (p:FindFirstChild("_OT") and p._OT.Value or 0)
        end
    end
    for _,v in pairs(char:GetChildren()) do
        if v:IsA("Accessory") then
            local hdl=v:FindFirstChild("Handle")
            if hdl and inFOV then hdl.LocalTransparencyModifier=0 end
        end
    end
end

local function StartFOVFix()
    for _,c in pairs(X_FOVConnections) do c:Disconnect() end
    X_FOVConnections={}
    local cam=workspace.CurrentCamera; local last=nil
    local conn=X_Run.RenderStepped:Connect(function()
        local char=X_Player.Character; if not char then return end
        if not cam then cam=workspace.CurrentCamera end
        local head=char:FindFirstChild("Head"); if not head then return end
        local inFOV=(cam.CFrame.Position-head.Position).Magnitude<1.2
        if inFOV~=last then
            last=inFOV; SetFOVTransparency(char,inFOV)
            if inFOV and #X_CurrentItems>0 then
                task.spawn(function()
                    task.wait(0.05)
                    local c2=X_Player.Character; if not c2 then return end
                    for _,item in pairs(X_CurrentItems) do
                        if item:IsA("Accessory") and not c2:FindFirstChild(item.Name) then
                            X_Weld_Internal(item:Clone(),c2)
                        end
                    end
                end)
            end
        end
    end)
    table.insert(X_FOVConnections,conn)
end

-- ================================================
-- CLOTHING TEMPLATE RESOLVER
-- ================================================
local function GetTemplate(id)
    local ok,asset=pcall(function() return game:GetObjects("rbxassetid://"..id)[1] end)
    if ok and asset then
        local t=""
        if asset:IsA("Shirt") then t=asset.ShirtTemplate
        elseif asset:IsA("Pants") then t=asset.PantsTemplate
        elseif asset:IsA("ShirtGraphic") then t=asset.Graphic end
        asset:Destroy()
        return t~="" and t or "rbxassetid://"..id
    end
    return "rbxassetid://"..id
end

-- ================================================
-- RIG DETECTION
-- ================================================
local function DetectRig(char)
    if char:FindFirstChild("UpperTorso") then return "R15" end
    if char:FindFirstChild("Torso")      then return "R6"  end
    return "Unknown"
end

-- ================================================
-- APPLY HUMANOIDDESCRIPTION  (animations + body scale)
-- ================================================
local function ApplyHumanoidDescription(hDesc, char)
    if not hDesc or not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        -- ApplyDescription applies animations, body colors, body scale, and packages
        hum:ApplyDescription(hDesc)
    end)
end

-- ================================================
-- FETCH HUMANOIDDESCRIPTION FROM USER ID
-- ================================================
local function GetHDescFromUserId(userId)
    local ok, hDesc = pcall(function()
        return X_Players:GetHumanoidDescriptionFromUserId(userId)
    end)
    if ok and hDesc then return hDesc end
    return nil
end

-- ================================================
-- INJECT BODY / FACE
-- ================================================
local function InjectCustomPart(id)
    local char=X_Player.Character; if not char then return false end
    local cid=tostring(id):match("%d+")
    local ok,info=pcall(function() return X_Market:GetProductInfo(tonumber(cid)) end)
    if ok and info then
        local t=info.AssetTypeId
        if t==1 or t==13 then
            local head=char:FindFirstChild("Head"); if not head then return false end
            local face=head:FindFirstChild("face") or Instance.new("Decal",head)
            face.Name="face"; face.Texture="rbxassetid://"..cid
            Notify("Face Applied",C.NTF_OK); return true
        elseif t==17 or t==24 then
            local head=char:FindFirstChild("Head"); if not head then return false end
            local m=head:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh",head)
            m.MeshId="rbxassetid://"..cid
            Notify("Head Applied",C.NTF_OK); return true
        elseif t>=27 and t<=31 then
            local ok2,a=pcall(function() return game:GetObjects("rbxassetid://"..cid)[1] end)
            if ok2 and a then a.Parent=char; Notify("Body Part Applied",C.NTF_OK); return true end
        end
    end
    return false
end

-- ================================================
-- WEAR ITEM
-- ================================================
local function WearItem(id)
    local char=X_Player.Character; if not char then return false end
    local ok,info=pcall(function() return X_Market:GetProductInfo(tonumber(id)) end)
    if ok and info then
        if info.AssetTypeId==11 then
            local s=char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt",char)
            s.ShirtTemplate=GetTemplate(id); Notify("Shirt Applied",C.NTF_OK); return true
        elseif info.AssetTypeId==12 then
            local p=char:FindFirstChildOfClass("Pants") or Instance.new("Pants",char)
            p.PantsTemplate=GetTemplate(id); Notify("Pants Applied",C.NTF_OK); return true
        end
    end
    local ok2,asset=pcall(function() return game:GetObjects("rbxassetid://"..id)[1] end)
    if ok2 and asset then
        if asset:IsA("Accessory") then X_Weld(asset) else asset.Parent=char end
        Notify("Item Added",C.NTF_OK); return true
    end
    return false
end

-- ================================================
-- KORBLOX
-- ================================================
local function ApplyKorblox(state)
    local char=X_Player.Character; if not char then return end
    for _,v in pairs(char:GetChildren()) do if v.Name=="VisualKorblox" then v:Destroy() end end
    if state then
        local fl=Instance.new("Part",char); fl.Name="VisualKorblox"
        fl.Size=Vector3.new(1,2,1); fl.CanCollide=false
        local m=Instance.new("SpecialMesh",fl)
        m.MeshId="rbxassetid://902942096"; m.TextureId="rbxassetid://902843398"; m.Scale=Vector3.new(1.2,1.2,1.2)
        local leg=char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg")
        if leg then
            local w=Instance.new("Weld",fl); w.Part0=leg; w.Part1=fl
            w.C0=(leg.Name=="Right Leg") and CFrame.new(0,0.6,-0.1) or CFrame.new(0,0.15,0)
        end
        for _,p in pairs({"RightUpperLeg","RightLowerLeg","RightFoot","Right Leg"}) do
            if char:FindFirstChild(p) then char[p].Transparency=1 end
        end
    else
        for _,p in pairs({"RightUpperLeg","RightLowerLeg","RightFoot","Right Leg"}) do
            if char:FindFirstChild(p) then char[p].Transparency=0 end
        end
    end
end

-- ================================================
-- FINAL APPLY  ← completely rewritten head logic
-- ================================================
local function FinalApply(items, isReset, hDesc)
    local char=X_Player.Character; if not char then return end
    local head=char:FindFirstChild("Head")
    local rig=DetectRig(char)

    -- Figure out what the SOURCE avatar rig is
    local srcIsR15=false
    for _,item in pairs(items) do
        local n=item.Name
        if n:find("Upper") or n:find("Lower") or n:find("Hand") or n:find("Foot") then
            srcIsR15=true; break
        end
    end

    -- ── 1. CLEAN existing cosmetics ──────────────────
    for _,v in pairs(char:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Clothing") or v:IsA("BodyColors") or v:IsA("CharacterMesh") then
            v:Destroy()
        elseif v:IsA("BasePart") then
            -- reset transparencies
            if v.Name:find("Leg") or v.Name:find("Arm") or v.Name:find("Hand")
               or v.Name:find("Foot") or v.Name:find("Torso") then
                v.Transparency=0
            end
        end
    end

    -- ── 2. CLEAN head children ────────────────────────
    if head then
        -- ALWAYS reset head to proper defaults first
        head.Transparency = 0
        -- Remove any existing mesh/face so we start fresh
        for _,v in pairs(head:GetChildren()) do
            if v:IsA("Decal") or v:IsA("SpecialMesh") then v:Destroy() end
        end

        -- On R15, the head shape is controlled by the Humanoid body scale mesh system.
        -- We should NOT inject any SpecialMesh from outside — that causes the box-head bug.
        -- On R6, we do need a SpecialMesh for the round head shape.
        if rig=="R6" then
            -- If resetting, add default R6 head mesh
            if isReset then
                local m=Instance.new("SpecialMesh",head)
                m.MeshType=Enum.MeshType.Head
                m.Scale=Vector3.new(1.25,1.25,1.25)
            end
            -- If applying an R6 avatar to an R6 rig, SpecialMesh is applied below from items
        end
        -- R15: never add SpecialMesh from an R6 source — it overrides the proper rounded head
    end

    -- ── 3. APPLY items ───────────────────────────────
    for _,item in pairs(items) do
        if item:IsA("Accessory") then
            X_Weld(item:Clone())

        elseif item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
            item:Clone().Parent=char

        elseif item:IsA("BodyColors") then
            item:Clone().Parent=char

        elseif item:IsA("CharacterMesh") then
            -- CharacterMesh is R6-only; skip on R15 (causes glitches)
            if rig=="R6" then item:Clone().Parent=char end

        elseif item:IsA("SpecialMesh") then
            -- Only apply SpecialMesh to head when rig matches source
            -- R15 rig + R6 source = SKIP to prevent box-head bug
            if head and rig=="R6" and not isReset then
                item:Clone().Parent=head
            elseif head and rig=="R15" and srcIsR15 then
                -- R15-to-R15: safe to apply head mesh if it came from R15 source
                item:Clone().Parent=head
            end
            -- All other combos: skip

        elseif item:IsA("Decal") and item.Name=="face" then
            if head then item:Clone().Parent=head end
        end
    end

    -- ── 4. HEAD VISIBILITY ───────────────────────────
    if head then
        head.Transparency = X_HeadlessActive and 1 or 0
        local faceDecal=head:FindFirstChild("face")
        if faceDecal then faceDecal.Transparency = X_HeadlessActive and 1 or 0 end

        -- R15 reset: make sure default face decal exists
        if isReset and rig=="R15" and not faceDecal then
            local def=Instance.new("Decal",head)
            def.Name="face"; def.Texture="rbxasset://textures/face.png"
        end
    end

    -- ── 5. ARM VISIBILITY FIX for cross-rig ──────────
    -- If source was R6 but body is R15, make sure R15 arms stay visible
    if rig=="R15" then
        for _,n in pairs({"RightUpperArm","LeftUpperArm","RightLowerArm",
                           "LeftLowerArm","RightHand","LeftHand"}) do
            local p=char:FindFirstChild(n); if p then p.Transparency=0 end
        end
    end
    if rig=="R6" then
        for _,n in pairs({"Right Arm","Left Arm"}) do
            local p=char:FindFirstChild(n); if p then p.Transparency=0 end
        end
    end

    -- ── 6. KORBLOX ───────────────────────────────────
    ApplyKorblox(X_KorbloxActive)

    -- ── 7. APPLY HUMANOIDDESCRIPTION (anims + scale) ─
    if hDesc then
        task.spawn(function()
            task.wait(0.1) -- let character settle first
            ApplyHumanoidDescription(hDesc, X_Player.Character)
        end)
    elseif isReset and X_OriginalHDesc then
        task.spawn(function()
            task.wait(0.1)
            ApplyHumanoidDescription(X_OriginalHDesc, X_Player.Character)
        end)
    end

    -- ── 8. STORE & WRAP UP ───────────────────────────
    X_CurrentItems=items
    task.spawn(StartFOVFix)
    Notify(isReset and "Avatar Reset" or "Avatar Applied",
           isReset and C.NTF_ERR or C.NTF_OK)
end

-- ================================================
-- CHANGE AVATAR FROM USERNAME/ID  (main logic)
-- ================================================
local function ChangeAvatar(input)
    local cid=input:match("%d+")

    -- Short numeric = try as item ID first
    if cid and #input<15 then
        if WearItem(cid) then return end
    end

    -- Resolve to userId
    local ok, uid = pcall(function() return X_Players:GetUserIdFromNameAsync(input) end)
    if not ok then uid=tonumber(cid) end
    if not uid then Notify("User Not Found", C.NTF_ERR); return end

    -- Save history
    local entry={name=input, time=os.time()}
    local found=false
    for _,e in pairs(X_History) do
        if (type(e)=="table" and e.name==input) or e==input then found=true; break end
    end
    if not found then
        table.insert(X_History,1,entry)
        if #X_History>30 then table.remove(X_History) end
        SaveData()
    end

    -- Get HumanoidDescription first (gives us animations + body scale)
    local hDesc = GetHDescFromUserId(uid)

    -- Build avatar model for cosmetics
    local model=X_Players:CreateHumanoidModelFromUserId(uid)
    local items={}
    for _,v in pairs(model:GetChildren()) do
        if not v:IsA("Humanoid") and not v:IsA("Script") then
            -- Grab SpecialMesh from Head specifically
            if v:IsA("BasePart") and v.Name=="Head" then
                local m=v:FindFirstChildOfClass("SpecialMesh")
                if m then table.insert(items,m:Clone()) end
                -- Also grab face decal
                local f=v:FindFirstChild("face")
                if f then table.insert(items,f:Clone()) end
            end
            table.insert(items,v:Clone())
        end
    end
    model:Destroy()

    FinalApply(items, false, hDesc)
end

-- ================================================
-- ================================================
--   U I   (black & white theme — identical to V92)
-- ================================================
-- ================================================

local X_Gui=Instance.new("ScreenGui",X_Player.PlayerGui)
X_Gui.Name="AvatarChangerV93"; X_Gui.ResetOnSpawn=false; X_Gui.DisplayOrder=10

-- Main window
local Main=Instance.new("Frame",X_Gui)
Main.Name="Main"; Main.Size=UDim2.new(0,268,0,500)
Main.Position=UDim2.new(0.5,-134,0.5,-250)
Main.BackgroundColor3=C.WIN; Main.Active=true
Main.ClipsDescendants=true; Main.Visible=false
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,16)
local winStroke=Instance.new("UIStroke",Main)
winStroke.Color=C.STROKE; winStroke.Thickness=1.4

-- Top accent line
local topLine=Instance.new("Frame",Main)
topLine.Size=UDim2.new(1,0,0,2); topLine.BackgroundColor3=C.WHITE
topLine.BorderSizePixel=0; topLine.ZIndex=6
local tlG=Instance.new("UIGradient",topLine)
tlG.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(30,30,30)),
    ColorSequenceKeypoint.new(0.3,C.WHITE),
    ColorSequenceKeypoint.new(0.7,C.WHITE),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(30,30,30))
})

-- Header
local Header=Instance.new("Frame",Main)
Header.Size=UDim2.new(1,0,0,50); Header.Position=UDim2.new(0,0,0,2)
Header.BackgroundColor3=C.PANEL; Header.BorderSizePixel=0; Header.ZIndex=4
local hDiv=Instance.new("Frame",Header)
hDiv.Size=UDim2.new(1,0,0,1); hDiv.Position=UDim2.new(0,0,1,-1)
hDiv.BackgroundColor3=C.DIVIDER; hDiv.BorderSizePixel=0; hDiv.ZIndex=5

local TitleLbl=Instance.new("TextLabel",Header)
TitleLbl.Size=UDim2.new(0,160,0,22); TitleLbl.Position=UDim2.new(0,16,0,8)
TitleLbl.Text="AVATAR CHANGER"; TitleLbl.TextColor3=C.TEXT
TitleLbl.Font=Enum.Font.GothamBold; TitleLbl.TextSize=13
TitleLbl.BackgroundTransparency=1; TitleLbl.TextXAlignment=Enum.TextXAlignment.Left; TitleLbl.ZIndex=5

local SubLbl=Instance.new("TextLabel",Header)
SubLbl.Size=UDim2.new(0,200,0,14); SubLbl.Position=UDim2.new(0,16,0,30)
SubLbl.Text="V93  ·  by XYTHC"; SubLbl.TextColor3=C.SUBTEXT
SubLbl.Font=Enum.Font.Gotham; SubLbl.TextSize=9
SubLbl.BackgroundTransparency=1; SubLbl.TextXAlignment=Enum.TextXAlignment.Left; SubLbl.ZIndex=5

local CloseBtn=Instance.new("TextButton",Header)
CloseBtn.Size=UDim2.new(0,26,0,26); CloseBtn.Position=UDim2.new(1,-36,0,12)
CloseBtn.BackgroundColor3=Color3.fromRGB(35,35,35); CloseBtn.Text="✕"
CloseBtn.TextColor3=C.SUBTEXT; CloseBtn.Font=Enum.Font.GothamBold; CloseBtn.TextSize=11; CloseBtn.ZIndex=5
Instance.new("UICorner",CloseBtn).CornerRadius=UDim.new(0,7)
CloseBtn.MouseEnter:Connect(function() TS(CloseBtn,{BackgroundColor3=Color3.fromRGB(55,25,25),TextColor3=Color3.fromRGB(220,80,80)},0.15) end)
CloseBtn.MouseLeave:Connect(function() TS(CloseBtn,{BackgroundColor3=Color3.fromRGB(35,35,35),TextColor3=C.SUBTEXT},0.15) end)

-- Tab bar
local TabBar=Instance.new("Frame",Main)
TabBar.Size=UDim2.new(1,-24,0,32); TabBar.Position=UDim2.new(0,12,0,58)
TabBar.BackgroundColor3=C.CARD; TabBar.ZIndex=4
Instance.new("UICorner",TabBar).CornerRadius=UDim.new(0,9)

local function MakeTab(lbl,xscale,active)
    local b=Instance.new("TextButton",TabBar)
    b.Size=UDim2.new(0.5,-4,1,-6); b.Position=UDim2.new(xscale,xscale==0 and 3 or 1,0,3)
    b.BackgroundColor3=active and C.WHITE or Color3.fromRGB(0,0,0)
    b.BackgroundTransparency=active and 0 or 1
    b.Text=lbl; b.Font=Enum.Font.GothamBold; b.TextSize=10; b.ZIndex=5
    b.TextColor3=active and C.WIN or C.SUBTEXT
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    return b
end
local btnChanger=MakeTab("⚡  CHANGER",0,true)
local btnLog    =MakeTab("📋  HISTORY",0.5,false)

-- Scroll pages
local CY0=100
local PageChanger=Instance.new("ScrollingFrame",Main)
PageChanger.Size=UDim2.new(1,0,1,-CY0); PageChanger.Position=UDim2.new(0,0,0,CY0)
PageChanger.BackgroundTransparency=1; PageChanger.ScrollBarThickness=3
PageChanger.ScrollBarImageColor3=Color3.fromRGB(80,80,80); PageChanger.BorderSizePixel=0

local PageLog=Instance.new("ScrollingFrame",Main)
PageLog.Size=UDim2.new(1,0,1,-CY0); PageLog.Position=UDim2.new(0,0,0,CY0)
PageLog.BackgroundTransparency=1; PageLog.ScrollBarThickness=3
PageLog.ScrollBarImageColor3=Color3.fromRGB(80,80,80); PageLog.Visible=false; PageLog.BorderSizePixel=0

-- ─────────────────────────────────────────────────
-- CHANGER PAGE  BUILDER
-- ─────────────────────────────────────────────────
local PAD=12; local cY=10

local function VSep(text)
    local lbl=Instance.new("TextLabel",PageChanger)
    lbl.Size=UDim2.new(1,-PAD*2,0,18); lbl.Position=UDim2.new(0,PAD,0,cY)
    lbl.BackgroundTransparency=1; lbl.Text=text; lbl.TextColor3=C.SUBTEXT
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=9
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=4
    local line=Instance.new("Frame",PageChanger)
    line.Size=UDim2.new(1,-PAD*2,0,1); line.Position=UDim2.new(0,PAD,0,cY+18)
    line.BackgroundColor3=C.DIVIDER; line.BorderSizePixel=0; line.ZIndex=4
    cY=cY+24
end

-- Input
local InputWrap=Instance.new("Frame",PageChanger)
InputWrap.Size=UDim2.new(1,-PAD*2,0,38); InputWrap.Position=UDim2.new(0,PAD,0,cY)
InputWrap.BackgroundColor3=C.INPUT; InputWrap.ZIndex=4
Instance.new("UICorner",InputWrap).CornerRadius=UDim.new(0,10)
local inpSK=Instance.new("UIStroke",InputWrap); inpSK.Color=C.STROKE; inpSK.Thickness=1

local searchIcon=Instance.new("TextLabel",InputWrap)
searchIcon.Size=UDim2.new(0,32,1,0); searchIcon.Text="⌕"
searchIcon.TextColor3=C.SUBTEXT; searchIcon.BackgroundTransparency=1
searchIcon.Font=Enum.Font.GothamBold; searchIcon.TextSize=16; searchIcon.ZIndex=5

local Box=Instance.new("TextBox",InputWrap)
Box.Size=UDim2.new(1,-36,1,0); Box.Position=UDim2.new(0,32,0,0)
Box.BackgroundTransparency=1; Box.Text=""
Box.PlaceholderText="Username / Item ID / Link..."
Box.PlaceholderColor3=C.SUBTEXT; Box.TextColor3=C.TEXT
Box.Font=Enum.Font.Gotham; Box.TextSize=11; Box.ZIndex=5; Box.ClearTextOnFocus=false
Box.Focused:Connect(function()  TS(inpSK,{Color=C.STROKEHI,Thickness=1.5},0.18) end)
Box.FocusLost:Connect(function() TS(inpSK,{Color=C.STROKE,Thickness=1},0.18) end)
cY=cY+48

-- Button factory
local function Btn(labelText,bgColor,textColor,h)
    h=h or 36
    local card=Instance.new("Frame",PageChanger)
    card.Size=UDim2.new(1,-PAD*2,0,h); card.Position=UDim2.new(0,PAD,0,cY)
    card.BackgroundColor3=bgColor; card.ZIndex=4
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,10)
    if bgColor~=C.BTN_PRI then
        local st=Instance.new("UIStroke",card); st.Color=C.DIVIDER; st.Thickness=1
    end
    cY=cY+h+7
    local btn=Instance.new("TextButton",card)
    btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1
    btn.Text=labelText; btn.TextColor3=textColor or C.TEXT
    btn.Font=Enum.Font.GothamBold; btn.TextSize=11; btn.ZIndex=5
    btn.MouseEnter:Connect(function()
        TS(card,{BackgroundColor3=Color3.new(
            math.min(bgColor.R+0.07,1),math.min(bgColor.G+0.07,1),math.min(bgColor.B+0.07,1))},0.13)
    end)
    btn.MouseLeave:Connect(function() TS(card,{BackgroundColor3=bgColor},0.13) end)
    btn.MouseButton1Down:Connect(function() TS(card,{Size=UDim2.new(1,-PAD*2-4,0,h-4)},0.08) end)
    btn.MouseButton1Up:Connect(function()   TS(card,{Size=UDim2.new(1,-PAD*2,0,h)},0.18)    end)
    return btn,card
end

local function BtnPrimary(lbl)   return Btn(lbl,C.BTN_PRI,C.WIN) end
local function BtnSecondary(lbl) return Btn(lbl,C.BTN_SEC,C.TEXT) end
local function BtnDanger(lbl)    return Btn(lbl,C.BTN_DNGR,Color3.fromRGB(220,100,100)) end
local function BtnSave(lbl)      return Btn(lbl,C.BTN_SAVE,Color3.fromRGB(100,210,120)) end
local function BtnStar(lbl)      return Btn(lbl,C.BTN_STAR,Color3.fromRGB(210,170,70)) end

local function BtnToggle(off,on)
    local btn,card=Btn(off,C.BTN_SEC,C.SUBTEXT)
    local state=false
    local function Set(v)
        state=v; btn.Text=v and on or off
        TS(btn,{TextColor3=v and C.TEXT or C.SUBTEXT},0.18)
        TS(card,{BackgroundColor3=v and Color3.fromRGB(50,50,50) or C.BTN_SEC},0.18)
        local st=card:FindFirstChildOfClass("UIStroke")
        if st then TS(st,{Color=v and C.STROKEHI or C.DIVIDER},0.18) end
    end
    btn.MouseButton1Click:Connect(function() Set(not state) end)
    return btn,card,Set,function() return state end
end

-- Build buttons
VSep("AVATAR")
local btnChangeAvatar            = BtnPrimary("👤   CHANGE AVATAR")
local btnWearItem                = BtnSecondary("🧢   WEAR ITEM / ID")
local btnInjectPart              = BtnSecondary("💉   INJECT BODY · FACE · HEAD")

VSep("TOGGLES")
local btnKB,_,SetKorblox,GetKorblox     = BtnToggle("🦾   KORBLOX: OFF","🦾   KORBLOX: ON")
local btnHL,_,SetHeadless,GetHeadless   = BtnToggle("💀   HEADLESS: OFF","💀   HEADLESS: ON")

VSep("MANAGE")
local btnFav          = BtnStar("⭐   ADD TO FAVORITES")
local btnSaveOutfit   = BtnSave("💾   SAVE CURRENT OUTFIT")
local btnReset        = BtnDanger("🔄   RESET AVATAR")

PageChanger.CanvasSize=UDim2.new(0,0,0,cY+10)

-- ─────────────────────────────────────────────────
-- BUTTON ACTIONS
-- ─────────────────────────────────────────────────
btnChangeAvatar.MouseButton1Click:Connect(function()
    local input=Box.Text
    if input=="" then Notify("Enter a username or ID",C.NTF_ERR); return end
    ChangeAvatar(input)
end)

btnWearItem.MouseButton1Click:Connect(function()
    local cid=Box.Text:match("%d+"); if not cid then Notify("No ID Found",C.NTF_ERR); return end
    if WearItem(cid) then
        local found=false
        for _,e in pairs(X_ItemHistory) do
            if (type(e)=="table" and e.id==cid) or e==cid then found=true; break end
        end
        if not found then
            table.insert(X_ItemHistory,1,{id=cid,time=os.time()})
            if #X_ItemHistory>30 then table.remove(X_ItemHistory) end
            SaveData()
        end
    else
        Notify("Item Not Found",C.NTF_ERR)
    end
end)

btnInjectPart.MouseButton1Click:Connect(function()
    local cid=Box.Text:match("%d+"); if not cid then Notify("No ID Found",C.NTF_ERR); return end
    if not InjectCustomPart(cid) then Notify("Inject Failed",C.NTF_ERR) end
end)

btnKB.MouseButton1Click:Connect(function()
    X_KorbloxActive=GetKorblox(); ApplyKorblox(X_KorbloxActive)
end)

btnHL.MouseButton1Click:Connect(function()
    X_HeadlessActive=GetHeadless()
    local h=X_Player.Character and X_Player.Character:FindFirstChild("Head")
    if h then h.Transparency=X_HeadlessActive and 1 or 0 end
end)

btnFav.MouseButton1Click:Connect(function()
    if Box.Text=="" then Notify("Enter something first",C.NTF_ERR); return end
    if not table.find(X_Favorites,Box.Text) then
        table.insert(X_Favorites,Box.Text); SaveData()
        Notify("Added to Favorites",C.NTF_FAV)
    else
        Notify("Already in Favorites",C.NTF_ERR)
    end
end)

btnSaveOutfit.MouseButton1Click:Connect(function()
    if #X_CurrentItems==0 then Notify("No outfit applied yet",C.NTF_ERR); return end
    local name=Box.Text~="" and Box.Text or ("Outfit "..(#X_SavedOutfits+1))
    X_SavedOutfits[name]=X_CurrentItems; SaveData()
    Notify("Saved: "..name,C.NTF_SAVE)
end)

btnReset.MouseButton1Click:Connect(function()
    X_KorbloxActive=false; X_HeadlessActive=false
    SetKorblox(false); SetHeadless(false)
    FinalApply(X_OriginalItems, true, nil)   -- nil = use X_OriginalHDesc internally
end)

-- ─────────────────────────────────────────────────
-- HISTORY PAGE
-- ─────────────────────────────────────────────────
local function MakeLogCard(parent,text,subtext,bgColor,onClick)
    local card=Instance.new("Frame",parent)
    card.Size=UDim2.new(1,-24,0,subtext and 44 or 36)
    card.BackgroundColor3=bgColor or C.CARD; card.ZIndex=4
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,9)
    local csk=Instance.new("UIStroke",card); csk.Color=C.DIVIDER; csk.Thickness=1
    local lbl=Instance.new("TextButton",card)
    lbl.Size=UDim2.new(1,-44,subtext and 0 or 1,subtext and 22 or 0)
    lbl.Position=UDim2.new(0,12,0,subtext and 5 or 0)
    lbl.BackgroundTransparency=1; lbl.Text=text; lbl.TextColor3=C.TEXT
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=10
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=5
    lbl.TextTruncate=Enum.TextTruncate.AtEnd
    if subtext then
        local sub=Instance.new("TextLabel",card)
        sub.Size=UDim2.new(1,-44,0,14); sub.Position=UDim2.new(0,12,0,24)
        sub.BackgroundTransparency=1; sub.Text=subtext; sub.TextColor3=C.SUBTEXT
        sub.Font=Enum.Font.Gotham; sub.TextSize=9
        sub.TextXAlignment=Enum.TextXAlignment.Left; sub.ZIndex=5
    end
    if onClick then
        lbl.MouseButton1Click:Connect(onClick)
        lbl.MouseEnter:Connect(function() TS(card,{BackgroundColor3=C.CARDHOV},0.12) end)
        lbl.MouseLeave:Connect(function() TS(card,{BackgroundColor3=bgColor or C.CARD},0.12) end)
    end
    return card,lbl
end

local function MakeLogSection(parent,text,order)
    local lbl=Instance.new("TextLabel",parent)
    lbl.Size=UDim2.new(1,-24,0,20); lbl.BackgroundTransparency=1
    lbl.Text=text; lbl.TextColor3=C.ACCENT
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=9
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=4; lbl.LayoutOrder=order
    return lbl
end

local function MakeDelBtn(parent,onClick)
    local del=Instance.new("TextButton",parent)
    del.Size=UDim2.new(0,24,0,24); del.Position=UDim2.new(1,-30,0.5,-12)
    del.BackgroundColor3=Color3.fromRGB(45,20,20); del.Text="✕"
    del.TextColor3=Color3.fromRGB(180,70,70); del.Font=Enum.Font.GothamBold
    del.TextSize=10; del.ZIndex=6
    Instance.new("UICorner",del).CornerRadius=UDim.new(0,6)
    del.MouseButton1Click:Connect(onClick)
end

local function SwitchToChanger(text)
    if text then Box.Text=text end
    PageLog.Visible=false; PageChanger.Visible=true
    TS(btnChanger,{BackgroundColor3=C.WHITE,BackgroundTransparency=0,TextColor3=C.WIN},0.18)
    TS(btnLog,{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,TextColor3=C.SUBTEXT},0.18)
end

local function RefreshLogs()
    for _,v in pairs(PageLog:GetChildren()) do
        if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then v:Destroy() end
    end
    local layout=Instance.new("UIListLayout",PageLog)
    layout.Padding=UDim.new(0,6); layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
    layout.SortOrder=Enum.SortOrder.LayoutOrder
    Instance.new("UIPadding",PageLog).PaddingTop=UDim.new(0,10)
    local lo=1

    local function TS_fmt(t)
        if not t then return nil end
        local d=os.time()-t
        if d<60 then return d.."s ago"
        elseif d<3600 then return math.floor(d/60).."m ago"
        else return math.floor(d/3600).."h ago" end
    end

    -- Saved outfits
    if next(X_SavedOutfits) then
        MakeLogSection(PageLog,"💾  SAVED OUTFITS",lo); lo=lo+1
        for name,items in pairs(X_SavedOutfits) do
            local c=MakeLogCard(PageLog,name,nil,Color3.fromRGB(22,34,24),function()
                FinalApply(items,false,nil); Notify("Loaded: "..name,C.NTF_SAVE)
            end)
            c.LayoutOrder=lo; lo=lo+1
            MakeDelBtn(c,function() X_SavedOutfits[name]=nil; SaveData(); RefreshLogs() end)
        end
    end

    -- Favorites
    if #X_Favorites>0 then
        MakeLogSection(PageLog,"⭐  FAVORITES",lo); lo=lo+1
        for idx,fav in ipairs(X_Favorites) do
            local c=MakeLogCard(PageLog,fav,nil,Color3.fromRGB(34,28,14),function() SwitchToChanger(fav) end)
            c.LayoutOrder=lo; lo=lo+1
            local di=idx
            MakeDelBtn(c,function() table.remove(X_Favorites,di); SaveData(); RefreshLogs() end)
        end
    end

    -- Avatar history
    if #X_History>0 then
        MakeLogSection(PageLog,"👤  AVATAR HISTORY",lo); lo=lo+1
        for _,entry in ipairs(X_History) do
            local name=type(entry)=="table" and entry.name or tostring(entry)
            local ts=type(entry)=="table" and TS_fmt(entry.time) or nil
            local c=MakeLogCard(PageLog,name,ts,C.CARD,function() SwitchToChanger(name) end)
            c.LayoutOrder=lo; lo=lo+1
        end
    end

    -- Item history
    if #X_ItemHistory>0 then
        MakeLogSection(PageLog,"🧢  ITEM HISTORY",lo); lo=lo+1
        for _,entry in ipairs(X_ItemHistory) do
            local id=type(entry)=="table" and entry.id or tostring(entry)
            local ts=type(entry)=="table" and TS_fmt(entry.time) or nil
            local c=MakeLogCard(PageLog,"ID: "..id,ts,C.CARD,function() SwitchToChanger(id) end)
            c.LayoutOrder=lo; lo=lo+1
        end
    end

    -- Empty
    if #X_History==0 and #X_ItemHistory==0 and #X_Favorites==0 and not next(X_SavedOutfits) then
        local e=Instance.new("TextLabel",PageLog)
        e.Size=UDim2.new(1,0,0,60); e.BackgroundTransparency=1
        e.Text="Nothing here yet · start changing!"; e.TextColor3=C.SUBTEXT
        e.Font=Enum.Font.Gotham; e.TextSize=11; e.ZIndex=4; e.LayoutOrder=1
    end

    -- Clear history
    if #X_History>0 or #X_ItemHistory>0 then
        local clr=Instance.new("TextButton",PageLog)
        clr.Size=UDim2.new(1,-24,0,30); clr.BackgroundColor3=Color3.fromRGB(35,20,20)
        clr.Text="🗑   CLEAR HISTORY"; clr.TextColor3=Color3.fromRGB(180,70,70)
        clr.Font=Enum.Font.GothamBold; clr.TextSize=10; clr.ZIndex=4; clr.LayoutOrder=lo+999
        Instance.new("UICorner",clr).CornerRadius=UDim.new(0,9)
        clr.MouseButton1Click:Connect(function()
            X_History={}; X_ItemHistory={}; SaveData(); RefreshLogs()
            Notify("History Cleared",C.NTF_ERR)
        end)
    end

    task.wait()
    PageLog.CanvasSize=UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+24)
end

-- Tab switching
btnLog.MouseButton1Click:Connect(function()
    PageChanger.Visible=false; PageLog.Visible=true; RefreshLogs()
    TS(btnLog,{BackgroundColor3=C.WHITE,BackgroundTransparency=0,TextColor3=C.WIN},0.18)
    TS(btnChanger,{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,TextColor3=C.SUBTEXT},0.18)
end)
btnChanger.MouseButton1Click:Connect(function()
    PageLog.Visible=false; PageChanger.Visible=true
    TS(btnChanger,{BackgroundColor3=C.WHITE,BackgroundTransparency=0,TextColor3=C.WIN},0.18)
    TS(btnLog,{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,TextColor3=C.SUBTEXT},0.18)
end)

-- ─────────────────────────────────────────────────
-- FLOATING ICON
-- ─────────────────────────────────────────────────
local X_Icon=Instance.new("TextButton",X_Gui)
X_Icon.Size=UDim2.new(0,46,0,46); X_Icon.Position=UDim2.new(0,14,0,14)
X_Icon.BackgroundColor3=Color3.fromRGB(18,18,18); X_Icon.Text=""; X_Icon.ZIndex=5
Instance.new("UICorner",X_Icon).CornerRadius=UDim.new(0,13)
local iconSK=Instance.new("UIStroke",X_Icon); iconSK.Color=C.STROKE; iconSK.Thickness=1.2

local iconEmoji=Instance.new("TextLabel",X_Icon)
iconEmoji.Size=UDim2.new(1,0,0.65,0); iconEmoji.Position=UDim2.new(0,0,0.08,0)
iconEmoji.Text="👤"; iconEmoji.TextSize=17; iconEmoji.BackgroundTransparency=1
iconEmoji.ZIndex=6; iconEmoji.Font=Enum.Font.Gotham

local Dot=Instance.new("Frame",X_Icon)
Dot.Size=UDim2.new(0,9,0,9); Dot.Position=UDim2.new(1,-11,0,2)
Dot.BackgroundColor3=Color3.fromRGB(220,60,60); Dot.ZIndex=7
Instance.new("UICorner",Dot).CornerRadius=UDim.new(1,0)

local function SetDot(open)
    TS(Dot,{BackgroundColor3=open and Color3.fromRGB(100,210,120) or Color3.fromRGB(220,60,60)},0.2)
end
X_Icon.MouseEnter:Connect(function()
    TSBack(X_Icon,{Size=UDim2.new(0,50,0,50),Position=UDim2.new(0,12,0,12)},0.22)
    TS(iconSK,{Color=C.STROKEHI},0.15)
end)
X_Icon.MouseLeave:Connect(function()
    TSBack(X_Icon,{Size=UDim2.new(0,46,0,46),Position=UDim2.new(0,14,0,14)},0.22)
    TS(iconSK,{Color=C.STROKE},0.15)
end)
X_Icon.MouseButton1Click:Connect(function()
    if not Main.Visible then
        Main.Size=UDim2.new(0,0,0,0); Main.Position=UDim2.new(0.5,0,0.5,0); Main.Visible=true
        TSBack(Main,{Size=UDim2.new(0,268,0,500),Position=UDim2.new(0.5,-134,0.5,-250)},0.42)
        SetDot(true)
    else
        TS(Main,{Size=UDim2.new(0,0,0,0),Position=UDim2.new(0.5,0,0.5,0)},0.22)
        task.delay(0.23,function() Main.Visible=false end); SetDot(false)
    end
end)
CloseBtn.MouseButton1Click:Connect(function()
    TS(Main,{Size=UDim2.new(0,0,0,0),Position=UDim2.new(0.5,0,0.5,0)},0.22)
    task.delay(0.23,function() Main.Visible=false end); SetDot(false)
end)

-- ─────────────────────────────────────────────────
-- DRAG
-- ─────────────────────────────────────────────────
local function Drg(o,h)
    local drag,inp,sp,sop
    h.InputBegan:Connect(function(x)
        if x.UserInputType==Enum.UserInputType.MouseButton1 or x.UserInputType==Enum.UserInputType.Touch then
            drag=true; sp=x.Position; sop=o.Position
            x.Changed:Connect(function() if x.UserInputState==Enum.UserInputState.End then drag=false end end)
        end
    end)
    h.InputChanged:Connect(function(x)
        if x.UserInputType==Enum.UserInputType.MouseMovement or x.UserInputType==Enum.UserInputType.Touch then inp=x end
    end)
    X_UIS.InputChanged:Connect(function(x)
        if x==inp and drag then
            local d=x.Position-sp
            o.Position=UDim2.new(sop.X.Scale,sop.X.Offset+d.X,sop.Y.Scale,sop.Y.Offset+d.Y)
        end
    end)
end
Drg(Main,Header); Drg(X_Icon,X_Icon)

-- ─────────────────────────────────────────────────
-- RESPAWN  →  re-apply last outfit + FOV fix
-- ─────────────────────────────────────────────────
X_Player.CharacterAdded:Connect(function()
    task.wait(0.6)
    if #X_CurrentItems>0 then FinalApply(X_CurrentItems,false,nil) end
    task.spawn(StartFOVFix)
end)

-- ─────────────────────────────────────────────────
-- INIT  —  capture original items + HumanoidDescription
-- ─────────────────────────────────────────────────
local initChar=X_Player.Character or X_Player.CharacterAdded:Wait()

-- Store original HumanoidDescription (animations, body scale)
pcall(function()
    local hum=initChar:FindFirstChildOfClass("Humanoid")
    if hum then
        X_OriginalHDesc=hum:GetAppliedDescription()
    end
end)
if not X_OriginalHDesc then
    -- fallback: fetch from API
    pcall(function()
        X_OriginalHDesc=X_Players:GetHumanoidDescriptionFromUserId(X_Player.UserId)
    end)
end

-- Store original cosmetic items
for _,v in pairs(initChar:GetChildren()) do
    if not v:IsA("Humanoid") and not v:IsA("Script") and not v:IsA("LocalScript") then
        table.insert(X_OriginalItems,v:Clone())
    end
end
if initChar:FindFirstChild("Head") then
    for _,v in pairs(initChar.Head:GetChildren()) do
        table.insert(X_OriginalItems,v:Clone())
    end
end

task.spawn(StartFOVFix)
Notify("Avatar Changer V93  ·  Ready",C.NTF_OK)
