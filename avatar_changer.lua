-- AVATAR CHANGER V94
-- FIXES: face bug, animations, body type, korblox/headless toggle logic,
--        cross-rig outfit copy (R6<>R15), bigger UI, updated icons (XYTHC)

local X_Player   = game:GetService("Players").LocalPlayer
local X_UIS      = game:GetService("UserInputService")
local X_Players  = game:GetService("Players")
local X_Http     = game:GetService("HttpService")
local X_Tween    = game:GetService("TweenService")
local X_Market   = game:GetService("MarketplaceService")
local X_Run      = game:GetService("RunService")

local X_OrigItems   = {}          -- original cosmetics at load
local X_CurItems    = {}          -- currently applied cosmetics
local X_OrigHDesc   = nil         -- original HumanoidDescription
local X_CurHDesc    = nil         -- currently applied HumanoidDescription
local X_KorbloxOn   = false
local X_HeadlessOn  = false
local X_FOVConns    = {}
local X_History, X_ItemHistory, X_Favorites, X_SavedOutfits = {}, {}, {}, {}

-- ═══════════════════════════════════════════════════
-- PERSISTENCE
-- ═══════════════════════════════════════════════════
local FNAME = "AvatarChangerV94.json"
local function Save()
    pcall(function()
        if writefile then
            writefile(FNAME, X_Http:JSONEncode({H=X_History,IH=X_ItemHistory,F=X_Favorites,SO=X_SavedOutfits}))
        end
    end)
end
local function Load()
    pcall(function()
        if isfile and isfile(FNAME) then
            local ok,r = pcall(function() return X_Http:JSONDecode(readfile(FNAME)) end)
            if ok and r then
                X_History=r.H or {}; X_ItemHistory=r.IH or {}
                X_Favorites=r.F or {}; X_SavedOutfits=r.SO or {}
            end
        end
    end)
end
Load()

-- ═══════════════════════════════════════════════════
-- TWEEN HELPERS
-- ═══════════════════════════════════════════════════
local function TW(obj, goal, t, sty, dir)
    local tw = X_Tween:Create(obj, TweenInfo.new(
        t or 0.22, sty or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), goal)
    tw:Play(); return tw
end
local function TWBack(obj, goal, t)
    X_Tween:Create(obj, TweenInfo.new(t or 0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out), goal):Play()
end

-- ═══════════════════════════════════════════════════
-- COLORS  (black & white)
-- ═══════════════════════════════════════════════════
local C = {
    WIN      = Color3.fromRGB(10,  10,  10),
    PANEL    = Color3.fromRGB(18,  18,  18),
    CARD     = Color3.fromRGB(26,  26,  26),
    CARDHOV  = Color3.fromRGB(36,  36,  36),
    INPUT    = Color3.fromRGB(20,  20,  20),
    DIV      = Color3.fromRGB(42,  42,  42),
    TXT      = Color3.fromRGB(245, 245, 245),
    SUB      = Color3.fromRGB(120, 120, 120),
    STROKE   = Color3.fromRGB(48,  48,  48),
    STROKEHI = Color3.fromRGB(190, 190, 190),
    WHITE    = Color3.fromRGB(238, 238, 238),
    BPRI     = Color3.fromRGB(232, 232, 232),   -- primary (white) btn bg
    BSEC     = Color3.fromRGB(32,  32,  32),    -- secondary btn bg
    BDNG     = Color3.fromRGB(55,  22,  22),    -- danger btn bg
    BSAV     = Color3.fromRGB(20,  38,  22),    -- save btn bg
    BFAV     = Color3.fromRGB(42,  34,  14),    -- favorite btn bg
    BTOG_ON  = Color3.fromRGB(46,  46,  46),    -- toggle ON bg
    NOK      = Color3.fromRGB(170, 170, 170),
    NERR     = Color3.fromRGB(210, 70,  70),
    NSAV     = Color3.fromRGB(80,  190, 100),
    NFAV     = Color3.fromRGB(210, 160, 50),
}

-- ═══════════════════════════════════════════════════
-- NOTIFICATION SYSTEM
-- ═══════════════════════════════════════════════════
local NGui = Instance.new("ScreenGui", X_Player.PlayerGui)
NGui.Name="X_NGui_V94"; NGui.ResetOnSpawn=false; NGui.DisplayOrder=99

local nQ, nBusy = {}, false
local function Pump()
    if nBusy or #nQ==0 then return end
    nBusy=true
    local msg,clr = table.unpack(table.remove(nQ,1))
    clr=clr or C.NOK
    local bg=Instance.new("Frame",NGui)
    bg.Size=UDim2.new(0,240,0,44); bg.Position=UDim2.new(1,18,1,-68)
    bg.BackgroundColor3=Color3.fromRGB(14,14,14); bg.BorderSizePixel=0; bg.ZIndex=20
    Instance.new("UICorner",bg).CornerRadius=UDim.new(0,11)
    local sk=Instance.new("UIStroke",bg); sk.Color=clr; sk.Thickness=1.2
    local bar=Instance.new("Frame",bg); bar.Size=UDim2.new(0,3,1,-12); bar.Position=UDim2.new(0,8,0,6)
    bar.BackgroundColor3=clr; bar.BorderSizePixel=0; Instance.new("UICorner",bar).CornerRadius=UDim.new(1,0)
    local lbl=Instance.new("TextLabel",bg)
    lbl.Size=UDim2.new(1,-24,1,0); lbl.Position=UDim2.new(0,20,0,0)
    lbl.Text=msg; lbl.TextColor3=C.TXT; lbl.BackgroundTransparency=1
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=12
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=21
    bg:TweenPosition(UDim2.new(1,-258,1,-68),"Out","Back",0.36,true)
    task.delay(2.8,function()
        TW(bg,{Position=UDim2.new(1,18,1,-68)},0.28)
        task.delay(0.3,function() bg:Destroy(); nBusy=false; Pump() end)
    end)
end
local function Notify(msg,clr) table.insert(nQ,{msg,clr}); Pump() end

-- ═══════════════════════════════════════════════════
-- RIG DETECTION
-- ═══════════════════════════════════════════════════
local function Rig(char)
    if char:FindFirstChild("UpperTorso") then return "R15" end
    if char:FindFirstChild("Torso")      then return "R6"  end
    return "Unknown"
end

-- ═══════════════════════════════════════════════════
-- WELD ACCESSORY
-- ═══════════════════════════════════════════════════
local function WeldAcc(acc, char)
    char = char or X_Player.Character
    local h = acc:FindFirstChild("Handle"); if not char or not h then return end
    local att = h:FindFirstChildOfClass("Attachment")
    local tar = att and char:FindFirstChild(att.Name, true)
    acc.Parent = char
    if tar then
        local w = Instance.new("Weld", h)
        w.Part0=h; w.Part1=tar.Parent
        w.C0=att.CFrame; w.C1=tar.CFrame
    end
end

-- ═══════════════════════════════════════════════════
-- FOV FIX
-- ═══════════════════════════════════════════════════
local function ApplyFOV(char, hide)
    if not char then return end
    local limbs = {
        "Right Arm","Left Arm",
        "RightUpperArm","RightLowerArm","RightHand",
        "LeftUpperArm","LeftLowerArm","LeftHand"
    }
    for _,n in ipairs(limbs) do
        local p=char:FindFirstChild(n)
        if p and p:IsA("BasePart") then
            if not p:FindFirstChild("_OT") then
                local v=Instance.new("NumberValue",p); v.Name="_OT"; v.Value=p.Transparency
            end
            p.Transparency = hide and 1 or (p:FindFirstChild("_OT") and p._OT.Value or 0)
        end
    end
    -- keep accessories visible in FOV
    for _,v in pairs(char:GetChildren()) do
        if v:IsA("Accessory") then
            local hdl=v:FindFirstChild("Handle")
            if hdl then hdl.LocalTransparencyModifier=0 end
        end
    end
end

local function StartFOV()
    for _,c in pairs(X_FOVConns) do c:Disconnect() end; X_FOVConns={}
    local cam=workspace.CurrentCamera; local last=nil
    local conn=X_Run.RenderStepped:Connect(function()
        local char=X_Player.Character; if not char then return end
        cam=workspace.CurrentCamera
        local hd=char:FindFirstChild("Head"); if not hd then return end
        local inFOV=(cam.CFrame.Position-hd.Position).Magnitude<1.2
        if inFOV~=last then
            last=inFOV; ApplyFOV(char,inFOV)
            if inFOV and #X_CurItems>0 then
                task.spawn(function()
                    task.wait(0.05)
                    local c2=X_Player.Character; if not c2 then return end
                    for _,item in pairs(X_CurItems) do
                        if item:IsA("Accessory") and not c2:FindFirstChild(item.Name) then
                            WeldAcc(item:Clone(),c2)
                        end
                    end
                end)
            end
        end
    end)
    table.insert(X_FOVConns,conn)
end

-- ═══════════════════════════════════════════════════
-- CLOTHING TEMPLATE RESOLVER
-- ═══════════════════════════════════════════════════
local function GetTemplate(id)
    local ok,a=pcall(function() return game:GetObjects("rbxassetid://"..id)[1] end)
    if ok and a then
        local t=""
        if a:IsA("Shirt") then t=a.ShirtTemplate
        elseif a:IsA("Pants") then t=a.PantsTemplate
        elseif a:IsA("ShirtGraphic") then t=a.Graphic end
        a:Destroy(); return t~="" and t or "rbxassetid://"..id
    end
    return "rbxassetid://"..id
end

-- ═══════════════════════════════════════════════════
-- KORBLOX
-- ═══════════════════════════════════════════════════
local function DoKorblox(on)
    local char=X_Player.Character; if not char then return end
    for _,v in pairs(char:GetChildren()) do if v.Name=="VKorblox" then v:Destroy() end end
    if on then
        local p=Instance.new("Part",char); p.Name="VKorblox"; p.Size=Vector3.new(1,2,1); p.CanCollide=false
        local m=Instance.new("SpecialMesh",p)
        m.MeshId="rbxassetid://902942096"; m.TextureId="rbxassetid://902843398"; m.Scale=Vector3.new(1.2,1.2,1.2)
        local leg=char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg")
        if leg then
            local w=Instance.new("Weld",p); w.Part0=leg; w.Part1=p
            w.C0=(leg.Name=="Right Leg") and CFrame.new(0,0.6,-0.1) or CFrame.new(0,0.15,0)
        end
        for _,n in ipairs({"RightUpperLeg","RightLowerLeg","RightFoot","Right Leg"}) do
            if char:FindFirstChild(n) then char[n].Transparency=1 end
        end
    else
        for _,n in ipairs({"RightUpperLeg","RightLowerLeg","RightFoot","Right Leg"}) do
            if char:FindFirstChild(n) then char[n].Transparency=0 end
        end
    end
end

-- ═══════════════════════════════════════════════════
-- APPLY HUMANOIDDESCRIPTION  ← animations + body scale
-- ═══════════════════════════════════════════════════
local function ApplyHDesc(hDesc, char)
    if not hDesc or not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    -- We keep body scales from HDesc but preserve the CURRENT rig's body parts untouched
    -- (ApplyDescription handles this correctly on its own)
    pcall(function() hum:ApplyDescription(hDesc) end)
end

-- ═══════════════════════════════════════════════════
-- CORE APPLY  — works for any rig on any rig
-- ═══════════════════════════════════════════════════
local function Apply(items, isReset, hDesc)
    local char=X_Player.Character; if not char then return end
    local charRig = Rig(char)
    local head = char:FindFirstChild("Head")

    -- ── Step 1: full clean ───────────────────────────
    for _,v in pairs(char:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants")
        or v:IsA("ShirtGraphic") or v:IsA("BodyColors") or v:IsA("CharacterMesh") then
            v:Destroy()
        end
    end
    -- Reset all body part transparencies
    for _,v in pairs(char:GetDescendants()) do
        if v:IsA("BasePart") and v.Name~="HumanoidRootPart" then
            v.Transparency=0
        end
    end

    -- ── Step 2: clean head — NO SpecialMesh from outside on R15 ──
    if head then
        head.Transparency=0
        -- Remove face and mesh (we will add them back properly below)
        for _,v in pairs(head:GetChildren()) do
            if v:IsA("Decal") or v:IsA("SpecialMesh") then v:Destroy() end
        end
        -- R6 needs a SpecialMesh for the rounded shape;
        -- R15 gets its shape from the rig mesh system — never inject SpecialMesh on R15
        if charRig=="R6" and isReset then
            local m=Instance.new("SpecialMesh",head)
            m.MeshType=Enum.MeshType.Head; m.Scale=Vector3.new(1.25,1.25,1.25)
        end
    end

    -- ── Step 3: apply cosmetics from item list ────────
    -- Determine source rig from items
    local srcR15=false
    for _,item in pairs(items) do
        local n=item.Name
        if n=="UpperTorso" or n=="LowerTorso" or n:find("Upper") or n:find("Lower")
        or n=="RightHand" or n=="LeftHand" or n=="RightFoot" or n=="LeftFoot" then
            srcR15=true; break
        end
    end

    for _,item in pairs(items) do
        local cls=item.ClassName

        if cls=="Accessory" then
            WeldAcc(item:Clone(), char)

        elseif cls=="Shirt" or cls=="Pants" or cls=="ShirtGraphic" then
            item:Clone().Parent=char

        elseif cls=="BodyColors" then
            item:Clone().Parent=char

        elseif cls=="CharacterMesh" then
            -- R6-only; skip entirely on R15 — causes invisible body glitch
            if charRig=="R6" then item:Clone().Parent=char end

        elseif cls=="SpecialMesh" then
            -- ONLY apply head SpecialMesh when:
            --   R6 char + R6 src (matching rigs) and NOT resetting
            --   Never on R15 char (avoids box-head entirely)
            if charRig=="R6" and not isReset then
                if head then item:Clone().Parent=head end
            end
            -- R15: handled by ApplyDescription + rig system

        elseif cls=="Decal" and item.Name=="face" then
            -- Apply face texture — but NEVER the default Roblox face texture
            -- (that's what was showing up in the screenshot)
            local tex=item.Texture
            local isDefault = (tex=="rbxasset://textures/face.png"
                           or tex=="rbxassetid://0"
                           or tex==""
                           or tex=="rbxasset://textures/whiteDecal.dds")
            if head and not isDefault then
                item:Clone().Parent=head
            end
        end
    end

    -- ── Step 4: headless handling ─────────────────────
    if head then
        if X_HeadlessOn then
            head.Transparency=1
            local f=head:FindFirstChild("face"); if f then f.Transparency=1 end
        else
            head.Transparency=0
            local f=head:FindFirstChild("face"); if f then f.Transparency=0 end
        end
    end

    -- ── Step 5: ensure all body parts visible ─────────
    -- (cross-rig: R6 src on R15 body — arms etc should stay visible)
    for _,v in pairs(char:GetDescendants()) do
        if v:IsA("BasePart") and v.Name~="HumanoidRootPart" and not v:FindFirstChildOfClass("SpecialMesh") then
            if v.Name~="Head" then
                v.Transparency=0
            end
        end
    end

    -- ── Step 6: korblox ───────────────────────────────
    DoKorblox(X_KorbloxOn)

    -- ── Step 7: HumanoidDescription (anims + body scale) ──
    -- Apply AFTER cosmetics so body scale doesn't fight the weld positions
    local descToApply = hDesc or (isReset and X_OrigHDesc or nil)
    if descToApply then
        X_CurHDesc=descToApply
        task.spawn(function()
            task.wait(0.15)
            ApplyHDesc(descToApply, X_Player.Character)
        end)
    end

    -- ── Step 8: store & restart FOV fix ───────────────
    X_CurItems = items
    task.spawn(StartFOV)
    Notify(isReset and "Avatar Reset" or "Avatar Applied",
           isReset and C.NERR or C.NOK)
end

-- ═══════════════════════════════════════════════════
-- CHANGE AVATAR  (full avatar from username/id)
-- ═══════════════════════════════════════════════════
local function ChangeAvatar(input)
    input=tostring(input):match("^%s*(.-)%s*$")  -- trim
    if input=="" then Notify("Enter a username or ID", C.NERR); return end

    local cid=input:match("%d+")

    -- Short numeric → try as single item first
    if cid and #input<13 then
        local ok,info=pcall(function() return X_Market:GetProductInfo(tonumber(cid)) end)
        if ok and info and info.AssetTypeId~=21 then  -- 21 = place, not a wearable
            -- it looks like an item ID; but still let it fall through to username check
            -- if user typed a username that happens to be all digits, GetUserIdFromName will catch it
        end
    end

    -- Resolve to userId
    local ok,uid=pcall(function() return X_Players:GetUserIdFromNameAsync(input) end)
    if not ok then uid=tonumber(cid) end
    if not uid then Notify("User not found", C.NERR); return end

    -- History
    local entry={name=input, time=os.time()}
    local found=false
    for _,e in pairs(X_History) do
        local n=type(e)=="table" and e.name or tostring(e)
        if n==input then found=true; break end
    end
    if not found then
        table.insert(X_History,1,entry)
        if #X_History>30 then table.remove(X_History) end
        Save()
    end

    -- HumanoidDescription first (animations + body scale + body type)
    local hDesc=nil
    pcall(function() hDesc=X_Players:GetHumanoidDescriptionFromUserId(uid) end)

    -- Build cosmetic item list from model
    local model=X_Players:CreateHumanoidModelFromUserId(uid)
    local items={}
    for _,v in pairs(model:GetDescendants()) do
        -- only cosmetic types; skip BaseParts (we don't transplant body parts, only cosmetics)
        local cls=v.ClassName
        if cls=="Accessory" or cls=="Shirt" or cls=="Pants" or cls=="ShirtGraphic"
        or cls=="BodyColors" or cls=="CharacterMesh" then
            table.insert(items, v:Clone())
        elseif cls=="Decal" and v.Name=="face" then
            table.insert(items, v:Clone())
        elseif cls=="SpecialMesh" and v.Parent and v.Parent.Name=="Head" then
            table.insert(items, v:Clone())
        end
    end
    model:Destroy()

    Apply(items, false, hDesc)
end

-- ═══════════════════════════════════════════════════
-- WEAR SINGLE ITEM
-- ═══════════════════════════════════════════════════
local function WearItem(id)
    local char=X_Player.Character; if not char then return false end
    local ok,info=pcall(function() return X_Market:GetProductInfo(tonumber(id)) end)
    if ok and info then
        if info.AssetTypeId==11 then
            local s=char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt",char)
            s.ShirtTemplate=GetTemplate(id); Notify("Shirt Applied",C.NOK); return true
        elseif info.AssetTypeId==12 then
            local p=char:FindFirstChildOfClass("Pants") or Instance.new("Pants",char)
            p.PantsTemplate=GetTemplate(id); Notify("Pants Applied",C.NOK); return true
        end
    end
    local ok2,asset=pcall(function() return game:GetObjects("rbxassetid://"..id)[1] end)
    if ok2 and asset then
        if asset:IsA("Accessory") then WeldAcc(asset,char)
        else asset.Parent=char end
        Notify("Item Added",C.NOK); return true
    end
    return false
end

-- ═══════════════════════════════════════════════════
-- INJECT BODY / FACE / HEAD
-- ═══════════════════════════════════════════════════
local function InjectPart(id)
    local char=X_Player.Character; if not char then return false end
    local cid=tostring(id):match("%d+"); if not cid then return false end
    local ok,info=pcall(function() return X_Market:GetProductInfo(tonumber(cid)) end)
    if ok and info then
        local t=info.AssetTypeId
        local head=char:FindFirstChild("Head")
        if t==1 or t==18 then  -- Image / Face decal
            if head then
                local f=head:FindFirstChild("face") or Instance.new("Decal",head)
                f.Name="face"; f.Texture="rbxassetid://"..cid
                Notify("Face Injected",C.NOK); return true
            end
        elseif t==17 or t==24 then  -- Mesh / Head mesh
            if head then
                local m=head:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh",head)
                m.MeshId="rbxassetid://"..cid
                Notify("Head Injected",C.NOK); return true
            end
        elseif t>=27 and t<=31 then
            local ok2,a=pcall(function() return game:GetObjects("rbxassetid://"..cid)[1] end)
            if ok2 and a then a.Parent=char; Notify("Body Part Injected",C.NOK); return true end
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════
--   U I   (V94: bigger, cleaner icons, all bugs fixed)
-- ═══════════════════════════════════════════════════════════════

local Gui=Instance.new("ScreenGui",X_Player.PlayerGui)
Gui.Name="AvatarChangerV94"; Gui.ResetOnSpawn=false; Gui.DisplayOrder=10

-- ─── Main window  (bigger: 290×540) ─────────────────────────────
local WIN_W, WIN_H = 290, 540
local Main=Instance.new("Frame",Gui)
Main.Name="Main"; Main.Size=UDim2.new(0,WIN_W,0,WIN_H)
Main.Position=UDim2.new(0.5,-WIN_W/2,0.5,-WIN_H/2)
Main.BackgroundColor3=C.WIN; Main.Active=true
Main.ClipsDescendants=true; Main.Visible=false
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,16)
local wSK=Instance.new("UIStroke",Main); wSK.Color=C.STROKE; wSK.Thickness=1.4

-- Top accent
local tLine=Instance.new("Frame",Main)
tLine.Size=UDim2.new(1,0,0,2); tLine.BackgroundColor3=C.WHITE
tLine.BorderSizePixel=0; tLine.ZIndex=6
local tG=Instance.new("UIGradient",tLine)
tG.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(25,25,25)),
    ColorSequenceKeypoint.new(0.25,C.WHITE),
    ColorSequenceKeypoint.new(0.75,C.WHITE),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(25,25,25))
})

-- Header
local HDR=Instance.new("Frame",Main)
HDR.Size=UDim2.new(1,0,0,52); HDR.Position=UDim2.new(0,0,0,2)
HDR.BackgroundColor3=C.PANEL; HDR.BorderSizePixel=0; HDR.ZIndex=4
local hLine=Instance.new("Frame",HDR)
hLine.Size=UDim2.new(1,0,0,1); hLine.Position=UDim2.new(0,0,1,-1)
hLine.BackgroundColor3=C.DIV; hLine.BorderSizePixel=0; hLine.ZIndex=5

local TL=Instance.new("TextLabel",HDR)
TL.Size=UDim2.new(0,180,0,24); TL.Position=UDim2.new(0,16,0,8)
TL.Text="AVATAR CHANGER"; TL.TextColor3=C.TXT
TL.Font=Enum.Font.GothamBold; TL.TextSize=14
TL.BackgroundTransparency=1; TL.TextXAlignment=Enum.TextXAlignment.Left; TL.ZIndex=5

local SL=Instance.new("TextLabel",HDR)
SL.Size=UDim2.new(0,200,0,15); SL.Position=UDim2.new(0,16,0,32)
SL.Text="V94  ·  by XYTHC"; SL.TextColor3=C.SUB
SL.Font=Enum.Font.Gotham; SL.TextSize=10
SL.BackgroundTransparency=1; SL.TextXAlignment=Enum.TextXAlignment.Left; SL.ZIndex=5

local CloseBtn=Instance.new("TextButton",HDR)
CloseBtn.Size=UDim2.new(0,28,0,28); CloseBtn.Position=UDim2.new(1,-38,0,12)
CloseBtn.BackgroundColor3=Color3.fromRGB(36,36,36); CloseBtn.Text="✕"
CloseBtn.TextColor3=C.SUB; CloseBtn.Font=Enum.Font.GothamBold; CloseBtn.TextSize=12; CloseBtn.ZIndex=5
Instance.new("UICorner",CloseBtn).CornerRadius=UDim.new(0,8)
CloseBtn.MouseEnter:Connect(function() TW(CloseBtn,{TextColor3=Color3.fromRGB(230,80,80)},0.14) end)
CloseBtn.MouseLeave:Connect(function() TW(CloseBtn,{TextColor3=C.SUB},0.14) end)

-- Tab bar
local TabBar=Instance.new("Frame",Main)
TabBar.Size=UDim2.new(1,-22,0,34); TabBar.Position=UDim2.new(0,11,0,60)
TabBar.BackgroundColor3=C.CARD; TabBar.ZIndex=4
Instance.new("UICorner",TabBar).CornerRadius=UDim.new(0,10)

local function MkTab(txt,xs,active)
    local b=Instance.new("TextButton",TabBar)
    b.Size=UDim2.new(0.5,-4,1,-6); b.Position=UDim2.new(xs, xs==0 and 3 or 1, 0, 3)
    b.BackgroundColor3=active and C.WHITE or Color3.fromRGB(0,0,0)
    b.BackgroundTransparency=active and 0 or 1
    b.Text=txt; b.Font=Enum.Font.GothamBold; b.TextSize=11; b.ZIndex=5
    b.TextColor3=active and C.WIN or C.SUB
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    return b
end
local TAB_C=MkTab("  CHANGER",0,true)
local TAB_H=MkTab("  HISTORY",0.5,false)

-- Scroll pages
local PY=102
local PageC=Instance.new("ScrollingFrame",Main)
PageC.Size=UDim2.new(1,0,1,-PY); PageC.Position=UDim2.new(0,0,0,PY)
PageC.BackgroundTransparency=1; PageC.ScrollBarThickness=3
PageC.ScrollBarImageColor3=Color3.fromRGB(70,70,70); PageC.BorderSizePixel=0

local PageH=Instance.new("ScrollingFrame",Main)
PageH.Size=UDim2.new(1,0,1,-PY); PageH.Position=UDim2.new(0,0,0,PY)
PageH.BackgroundTransparency=1; PageH.ScrollBarThickness=3
PageH.ScrollBarImageColor3=Color3.fromRGB(70,70,70); PageH.Visible=false; PageH.BorderSizePixel=0

-- ─── Changer page ─────────────────────────────────────────────────
local PAD=13; local cY=12

-- Section separator
local function Sep(txt)
    local L=Instance.new("TextLabel",PageC)
    L.Size=UDim2.new(1,-PAD*2,0,16); L.Position=UDim2.new(0,PAD,0,cY)
    L.BackgroundTransparency=1; L.Text=txt; L.TextColor3=C.SUB
    L.Font=Enum.Font.GothamBold; L.TextSize=9
    L.TextXAlignment=Enum.TextXAlignment.Left; L.ZIndex=4
    local d=Instance.new("Frame",PageC)
    d.Size=UDim2.new(1,-PAD*2,0,1); d.Position=UDim2.new(0,PAD,0,cY+16)
    d.BackgroundColor3=C.DIV; d.BorderSizePixel=0; d.ZIndex=4
    cY=cY+22
end

-- Input box
local IWrap=Instance.new("Frame",PageC)
IWrap.Size=UDim2.new(1,-PAD*2,0,40); IWrap.Position=UDim2.new(0,PAD,0,cY)
IWrap.BackgroundColor3=C.INPUT; IWrap.ZIndex=4
Instance.new("UICorner",IWrap).CornerRadius=UDim.new(0,11)
local iSK=Instance.new("UIStroke",IWrap); iSK.Color=C.STROKE; iSK.Thickness=1

local iIcon=Instance.new("TextLabel",IWrap)
iIcon.Size=UDim2.new(0,36,1,0); iIcon.Text="  "
iIcon.TextColor3=C.SUB; iIcon.BackgroundTransparency=1
iIcon.Font=Enum.Font.GothamBold; iIcon.TextSize=15; iIcon.ZIndex=5

local Box=Instance.new("TextBox",IWrap)
Box.Size=UDim2.new(1,-38,1,0); Box.Position=UDim2.new(0,34,0,0)
Box.BackgroundTransparency=1; Box.Text=""
Box.PlaceholderText="Username / Item ID / Link..."
Box.PlaceholderColor3=C.SUB; Box.TextColor3=C.TXT
Box.Font=Enum.Font.Gotham; Box.TextSize=12; Box.ZIndex=5; Box.ClearTextOnFocus=false
Box.Focused:Connect(function()  TW(iSK,{Color=C.STROKEHI,Thickness=1.5},0.16) end)
Box.FocusLost:Connect(function() TW(iSK,{Color=C.STROKE, Thickness=1},  0.16) end)
cY=cY+50

-- Button builder
local function MkBtn(txt, bg, fg, h)
    h=h or 38
    local card=Instance.new("Frame",PageC)
    card.Size=UDim2.new(1,-PAD*2,0,h); card.Position=UDim2.new(0,PAD,0,cY)
    card.BackgroundColor3=bg; card.ZIndex=4
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,11)
    if bg~=C.BPRI then
        local sk=Instance.new("UIStroke",card); sk.Color=C.DIV; sk.Thickness=1
    end
    cY=cY+h+8
    local btn=Instance.new("TextButton",card)
    btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1
    btn.Text=txt; btn.TextColor3=fg or C.TXT
    btn.Font=Enum.Font.GothamBold; btn.TextSize=12; btn.ZIndex=5
    btn.MouseEnter:Connect(function()
        TW(card,{BackgroundColor3=Color3.new(
            math.min(bg.R+0.07,1),math.min(bg.G+0.07,1),math.min(bg.B+0.07,1))},0.13)
    end)
    btn.MouseLeave:Connect(function() TW(card,{BackgroundColor3=bg},0.13) end)
    btn.MouseButton1Down:Connect(function() TW(card,{Size=UDim2.new(1,-PAD*2-6,0,h-4)},0.08) end)
    btn.MouseButton1Up:Connect(function()   TW(card,{Size=UDim2.new(1,-PAD*2,0,h)},0.18)    end)
    return btn,card
end

-- Toggle builder  (FIXED: state is managed here, click fires ONCE and syncs)
local function MkToggle(txtOff, txtOn, bgOff, bgOn, fgOff, fgOn)
    local btn,card=MkBtn(txtOff, bgOff, fgOff)
    local state=false
    local function Sync(v)
        state=v
        btn.Text=v and txtOn or txtOff
        TW(btn, {TextColor3=v and (fgOn or C.TXT) or (fgOff or C.SUB)}, 0.16)
        TW(card,{BackgroundColor3=v and bgOn or bgOff},0.16)
        local sk=card:FindFirstChildOfClass("UIStroke")
        if sk then TW(sk,{Color=v and C.STROKEHI or C.DIV},0.16) end
    end
    btn.MouseButton1Click:Connect(function() Sync(not state) end)
    -- return btn, card, stateSetter, stateGetter
    return btn, card,
        function(v) Sync(v) end,
        function()  return state end
end

-- Build changer buttons
Sep("AVATAR")
local B_CHANGE  = MkBtn("  CHANGE AVATAR",  C.BPRI, C.WIN)
local B_WEAR    = MkBtn("  WEAR ITEM / ID",  C.BSEC, C.TXT)
local B_INJECT  = MkBtn("  INJECT BODY / FACE / HEAD", C.BSEC, C.TXT)

Sep("TOGGLES")
-- Korblox toggle  (FIXED inverted logic)
local B_KB, _, SetKB, GetKB = MkToggle(
    "  KORBLOX: OFF", "  KORBLOX: ON",
    C.BSEC, C.BTOG_ON,
    C.SUB, C.TXT
)
-- Headless toggle  (FIXED inverted logic)
local B_HL, _, SetHL, GetHL = MkToggle(
    "  HEADLESS: OFF", "  HEADLESS: ON",
    C.BSEC, C.BTOG_ON,
    C.SUB, C.TXT
)

Sep("MANAGE")
local B_FAV     = MkBtn("  ADD TO FAVORITES",    C.BFAV, Color3.fromRGB(210,170,60))
local B_SAVE    = MkBtn("  SAVE CURRENT OUTFIT",  C.BSAV, Color3.fromRGB(90, 200,110))
local B_RESET   = MkBtn("  RESET AVATAR",          C.BDNG, Color3.fromRGB(220,90, 90))

PageC.CanvasSize=UDim2.new(0,0,0,cY+12)

-- ─── Button actions ──────────────────────────────────────────────
B_CHANGE.MouseButton1Click:Connect(function()
    ChangeAvatar(Box.Text)
end)

B_WEAR.MouseButton1Click:Connect(function()
    local cid=Box.Text:match("%d+"); if not cid then Notify("No ID found",C.NERR); return end
    if WearItem(cid) then
        local found=false
        for _,e in pairs(X_ItemHistory) do
            if (type(e)=="table" and e.id==cid) or e==cid then found=true; break end
        end
        if not found then
            table.insert(X_ItemHistory,1,{id=cid,time=os.time()})
            if #X_ItemHistory>30 then table.remove(X_ItemHistory) end
            Save()
        end
    else Notify("Item not found",C.NERR) end
end)

B_INJECT.MouseButton1Click:Connect(function()
    local cid=Box.Text:match("%d+"); if not cid then Notify("No ID found",C.NERR); return end
    if not InjectPart(cid) then Notify("Inject failed",C.NERR) end
end)

-- Korblox: toggle fires state change, then we sync X_KorbloxOn and apply
B_KB.MouseButton1Click:Connect(function()
    -- Note: MkToggle already flipped state before this fires via MouseButton1Click order,
    -- but since we connect AFTER MkToggle's internal connect, state is already updated.
    -- We read it with GetKB()
    task.wait()  -- yield one frame so MkToggle's internal click fires first
    X_KorbloxOn=GetKB()
    DoKorblox(X_KorbloxOn)
end)

B_HL.MouseButton1Click:Connect(function()
    task.wait()
    X_HeadlessOn=GetHL()
    local head=X_Player.Character and X_Player.Character:FindFirstChild("Head")
    if head then
        head.Transparency=X_HeadlessOn and 1 or 0
        local f=head:FindFirstChild("face"); if f then f.Transparency=X_HeadlessOn and 1 or 0 end
    end
end)

B_FAV.MouseButton1Click:Connect(function()
    if Box.Text=="" then Notify("Enter something first",C.NERR); return end
    if not table.find(X_Favorites,Box.Text) then
        table.insert(X_Favorites,Box.Text); Save()
        Notify("Added to Favorites",C.NFAV)
    else Notify("Already in Favorites",C.NERR) end
end)

B_SAVE.MouseButton1Click:Connect(function()
    if #X_CurItems==0 then Notify("No outfit applied yet",C.NERR); return end
    local name=Box.Text~="" and Box.Text or ("Outfit "..(#X_SavedOutfits+1))
    X_SavedOutfits[name]=X_CurItems; Save()
    Notify("Saved: "..name, C.NSAV)
end)

B_RESET.MouseButton1Click:Connect(function()
    X_KorbloxOn=false; X_HeadlessOn=false
    SetKB(false); SetHL(false)
    Apply(X_OrigItems, true, nil)
end)

-- ─── History page ────────────────────────────────────────────────
local function FmtTime(t)
    if not t then return nil end
    local d=os.time()-t
    if d<60 then return d.."s ago"
    elseif d<3600 then return math.floor(d/60).."m ago"
    else return math.floor(d/3600).."h ago" end
end

local function MkCard(par, mainTxt, subTxt, bg, onClick)
    local h=subTxt and 46 or 38
    local card=Instance.new("Frame",par)
    card.Size=UDim2.new(1,-22,0,h); card.BackgroundColor3=bg or C.CARD; card.ZIndex=4
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,10)
    local sk=Instance.new("UIStroke",card); sk.Color=C.DIV; sk.Thickness=1
    local lbl=Instance.new("TextButton",card)
    lbl.Size=UDim2.new(1,-44,subTxt and 0 or 1, subTxt and 22 or 0)
    lbl.Position=UDim2.new(0,12,0,subTxt and 5 or 0)
    lbl.BackgroundTransparency=1; lbl.Text=mainTxt; lbl.TextColor3=C.TXT
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=11
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=5
    lbl.TextTruncate=Enum.TextTruncate.AtEnd
    if subTxt then
        local sub=Instance.new("TextLabel",card)
        sub.Size=UDim2.new(1,-44,0,14); sub.Position=UDim2.new(0,12,0,25)
        sub.BackgroundTransparency=1; sub.Text=subTxt; sub.TextColor3=C.SUB
        sub.Font=Enum.Font.Gotham; sub.TextSize=9
        sub.TextXAlignment=Enum.TextXAlignment.Left; sub.ZIndex=5
    end
    if onClick then
        lbl.MouseButton1Click:Connect(onClick)
        lbl.MouseEnter:Connect(function()  TW(card,{BackgroundColor3=C.CARDHOV},0.11) end)
        lbl.MouseLeave:Connect(function()  TW(card,{BackgroundColor3=bg or C.CARD},0.11) end)
    end
    return card
end

local function MkSecHdr(par, txt, lo)
    local l=Instance.new("TextLabel",par)
    l.Size=UDim2.new(1,-22,0,20); l.BackgroundTransparency=1
    l.Text=txt; l.TextColor3=C.STROKEHI; l.Font=Enum.Font.GothamBold; l.TextSize=9
    l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=4; l.LayoutOrder=lo
    return l
end

local function MkDel(par,cb)
    local d=Instance.new("TextButton",par)
    d.Size=UDim2.new(0,26,0,26); d.Position=UDim2.new(1,-32,0.5,-13)
    d.BackgroundColor3=Color3.fromRGB(44,18,18); d.Text="✕"
    d.TextColor3=Color3.fromRGB(190,70,70); d.Font=Enum.Font.GothamBold
    d.TextSize=11; d.ZIndex=6
    Instance.new("UICorner",d).CornerRadius=UDim.new(0,7)
    d.MouseButton1Click:Connect(cb)
end

local function GoChanger(txt)
    if txt then Box.Text=txt end
    PageH.Visible=false; PageC.Visible=true
    TW(TAB_C,{BackgroundColor3=C.WHITE,BackgroundTransparency=0,TextColor3=C.WIN},0.16)
    TW(TAB_H,{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,TextColor3=C.SUB},0.16)
end

local function RebuildHistory()
    for _,v in pairs(PageH:GetChildren()) do
        if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then v:Destroy() end
    end
    local lay=Instance.new("UIListLayout",PageH)
    lay.Padding=UDim.new(0,6); lay.HorizontalAlignment=Enum.HorizontalAlignment.Center
    lay.SortOrder=Enum.SortOrder.LayoutOrder
    Instance.new("UIPadding",PageH).PaddingTop=UDim.new(0,10)
    local lo=1

    -- Saved outfits
    if next(X_SavedOutfits) then
        MkSecHdr(PageH,"  SAVED OUTFITS",lo); lo=lo+1
        for name,items in pairs(X_SavedOutfits) do
            local c=MkCard(PageH,name,nil,Color3.fromRGB(18,32,20),function()
                Apply(items,false,X_CurHDesc); Notify("Loaded: "..name,C.NSAV)
            end)
            c.LayoutOrder=lo; lo=lo+1
            MkDel(c,function() X_SavedOutfits[name]=nil; Save(); RebuildHistory() end)
        end
    end

    -- Favorites
    if #X_Favorites>0 then
        MkSecHdr(PageH,"  FAVORITES",lo); lo=lo+1
        for idx,fav in ipairs(X_Favorites) do
            local c=MkCard(PageH,fav,nil,Color3.fromRGB(36,26,10),function() GoChanger(fav) end)
            c.LayoutOrder=lo; lo=lo+1
            local di=idx
            MkDel(c,function() table.remove(X_Favorites,di); Save(); RebuildHistory() end)
        end
    end

    -- Avatar history
    if #X_History>0 then
        MkSecHdr(PageH,"  AVATAR HISTORY",lo); lo=lo+1
        for _,e in ipairs(X_History) do
            local name=type(e)=="table" and e.name or tostring(e)
            local ts=type(e)=="table" and FmtTime(e.time) or nil
            local c=MkCard(PageH,name,ts,C.CARD,function() GoChanger(name) end)
            c.LayoutOrder=lo; lo=lo+1
        end
    end

    -- Item history
    if #X_ItemHistory>0 then
        MkSecHdr(PageH,"  ITEM HISTORY",lo); lo=lo+1
        for _,e in ipairs(X_ItemHistory) do
            local id=type(e)=="table" and e.id or tostring(e)
            local ts=type(e)=="table" and FmtTime(e.time) or nil
            local c=MkCard(PageH,"ID: "..id,ts,C.CARD,function() GoChanger(id) end)
            c.LayoutOrder=lo; lo=lo+1
        end
    end

    -- Empty state
    if #X_History==0 and #X_ItemHistory==0 and #X_Favorites==0 and not next(X_SavedOutfits) then
        local e=Instance.new("TextLabel",PageH)
        e.Size=UDim2.new(1,0,0,60); e.BackgroundTransparency=1
        e.Text="Nothing here yet"; e.TextColor3=C.SUB
        e.Font=Enum.Font.Gotham; e.TextSize=12; e.ZIndex=4; e.LayoutOrder=1
    end

    -- Clear history
    if #X_History>0 or #X_ItemHistory>0 then
        local clr=Instance.new("TextButton",PageH)
        clr.Size=UDim2.new(1,-22,0,32); clr.BackgroundColor3=Color3.fromRGB(38,16,16)
        clr.Text="  CLEAR HISTORY"; clr.TextColor3=Color3.fromRGB(190,70,70)
        clr.Font=Enum.Font.GothamBold; clr.TextSize=11; clr.ZIndex=4; clr.LayoutOrder=lo+999
        Instance.new("UICorner",clr).CornerRadius=UDim.new(0,10)
        clr.MouseButton1Click:Connect(function()
            X_History={}; X_ItemHistory={}; Save(); RebuildHistory()
            Notify("History Cleared",C.NERR)
        end)
    end

    task.wait()
    PageH.CanvasSize=UDim2.new(0,0,0,lay.AbsoluteContentSize.Y+24)
end

-- Tab switching
TAB_H.MouseButton1Click:Connect(function()
    PageC.Visible=false; PageH.Visible=true; RebuildHistory()
    TW(TAB_H,{BackgroundColor3=C.WHITE,BackgroundTransparency=0,TextColor3=C.WIN},0.16)
    TW(TAB_C,{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,TextColor3=C.SUB},0.16)
end)
TAB_C.MouseButton1Click:Connect(function()
    PageH.Visible=false; PageC.Visible=true
    TW(TAB_C,{BackgroundColor3=C.WHITE,BackgroundTransparency=0,TextColor3=C.WIN},0.16)
    TW(TAB_H,{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,TextColor3=C.SUB},0.16)
end)

-- ─── Floating icon ───────────────────────────────────────────────
local Ico=Instance.new("TextButton",Gui)
Ico.Size=UDim2.new(0,50,0,50); Ico.Position=UDim2.new(0,14,0,14)
Ico.BackgroundColor3=Color3.fromRGB(16,16,16); Ico.Text=""; Ico.ZIndex=5
Instance.new("UICorner",Ico).CornerRadius=UDim.new(0,14)
local icoSK=Instance.new("UIStroke",Ico); icoSK.Color=C.STROKE; icoSK.Thickness=1.3

local icoLbl=Instance.new("TextLabel",Ico)
icoLbl.Size=UDim2.new(1,0,0.65,0); icoLbl.Position=UDim2.new(0,0,0.1,0)
icoLbl.Text=""; icoLbl.TextSize=20; icoLbl.BackgroundTransparency=1
icoLbl.ZIndex=6; icoLbl.Font=Enum.Font.Gotham

local Dot=Instance.new("Frame",Ico)
Dot.Size=UDim2.new(0,10,0,10); Dot.Position=UDim2.new(1,-12,0,2)
Dot.BackgroundColor3=Color3.fromRGB(220,55,55); Dot.ZIndex=7
Instance.new("UICorner",Dot).CornerRadius=UDim.new(1,0)

local function SetDot(open)
    TW(Dot,{BackgroundColor3=open and Color3.fromRGB(90,210,110) or Color3.fromRGB(220,55,55)},0.2)
end

Ico.MouseEnter:Connect(function()
    TWBack(Ico,{Size=UDim2.new(0,54,0,54),Position=UDim2.new(0,12,0,12)},0.22)
    TW(icoSK,{Color=C.STROKEHI},0.14)
end)
Ico.MouseLeave:Connect(function()
    TWBack(Ico,{Size=UDim2.new(0,50,0,50),Position=UDim2.new(0,14,0,14)},0.22)
    TW(icoSK,{Color=C.STROKE},0.14)
end)
Ico.MouseButton1Click:Connect(function()
    if not Main.Visible then
        Main.Size=UDim2.new(0,0,0,0); Main.Position=UDim2.new(0.5,0,0.5,0); Main.Visible=true
        TWBack(Main,{Size=UDim2.new(0,WIN_W,0,WIN_H),Position=UDim2.new(0.5,-WIN_W/2,0.5,-WIN_H/2)},0.4)
        SetDot(true)
    else
        TW(Main,{Size=UDim2.new(0,0,0,0),Position=UDim2.new(0.5,0,0.5,0)},0.2)
        task.delay(0.21,function() Main.Visible=false end)
        SetDot(false)
    end
end)
CloseBtn.MouseButton1Click:Connect(function()
    TW(Main,{Size=UDim2.new(0,0,0,0),Position=UDim2.new(0.5,0,0.5,0)},0.2)
    task.delay(0.21,function() Main.Visible=false end)
    SetDot(false)
end)

-- ─── Drag ────────────────────────────────────────────────────────
local function Drag(obj,handle)
    local drag,inp,sp,sop
    handle.InputBegan:Connect(function(x)
        if x.UserInputType==Enum.UserInputType.MouseButton1
        or x.UserInputType==Enum.UserInputType.Touch then
            drag=true; sp=x.Position; sop=obj.Position
            x.Changed:Connect(function()
                if x.UserInputState==Enum.UserInputState.End then drag=false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(x)
        if x.UserInputType==Enum.UserInputType.MouseMovement
        or x.UserInputType==Enum.UserInputType.Touch then inp=x end
    end)
    X_UIS.InputChanged:Connect(function(x)
        if x==inp and drag then
            local d=x.Position-sp
            obj.Position=UDim2.new(sop.X.Scale,sop.X.Offset+d.X,sop.Y.Scale,sop.Y.Offset+d.Y)
        end
    end)
end
Drag(Main,HDR); Drag(Ico,Ico)

-- ═══════════════════════════════════════════════════
-- RESPAWN HANDLER
-- ═══════════════════════════════════════════════════
X_Player.CharacterAdded:Connect(function()
    task.wait(0.7)
    if #X_CurItems>0 then Apply(X_CurItems, false, X_CurHDesc) end
    task.spawn(StartFOV)
end)

-- ═══════════════════════════════════════════════════
-- INIT  — capture original state
-- ═══════════════════════════════════════════════════
local initChar=X_Player.Character or X_Player.CharacterAdded:Wait()

-- Capture original HumanoidDescription (animations + body scale)
pcall(function()
    local hum=initChar:FindFirstChildOfClass("Humanoid")
    if hum then X_OrigHDesc=hum:GetAppliedDescription() end
end)
if not X_OrigHDesc then
    pcall(function()
        X_OrigHDesc=X_Players:GetHumanoidDescriptionFromUserId(X_Player.UserId)
    end)
end

-- Capture original cosmetics
for _,v in pairs(initChar:GetDescendants()) do
    local cls=v.ClassName
    if cls=="Accessory" or cls=="Shirt" or cls=="Pants" or cls=="ShirtGraphic"
    or cls=="BodyColors" or cls=="CharacterMesh" then
        table.insert(X_OrigItems, v:Clone())
    elseif cls=="Decal" and v.Name=="face" and v.Parent and v.Parent.Name=="Head" then
        table.insert(X_OrigItems, v:Clone())
    elseif cls=="SpecialMesh" and v.Parent and v.Parent.Name=="Head" then
        table.insert(X_OrigItems, v:Clone())
    end
end

task.spawn(StartFOV)
Notify("Avatar Changer V94  Ready", C.NOK)
