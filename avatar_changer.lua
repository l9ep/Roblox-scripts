-- AVATAR CHANGER V95
-- COMPLETE REWRITE: HDesc-first approach fixes ALL cross-rig issues
-- R6<>R15 works perfectly, face always correct, reset always correct (XYTHC)

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
local OrigHDesc  = nil   -- captured at init
local CurHDesc   = nil   -- last applied
local KorbloxOn  = false
local HeadlessOn = false
local FOVConns   = {}

local History, ItemHistory, Favorites, SavedOutfits = {}, {}, {}, {}

-- ═══════════════════════════════════════════════
-- PERSISTENCE
-- ═══════════════════════════════════════════════
local FNAME = "AvatarChangerV95.json"
local function SaveData()
    pcall(function()
        if writefile then
            writefile(FNAME, X_Http:JSONEncode({
                H=History, IH=ItemHistory, F=Favorites, SO=SavedOutfits
            }))
        end
    end)
end
local function LoadData()
    pcall(function()
        if isfile and isfile(FNAME) then
            local ok,r = pcall(function() return X_Http:JSONDecode(readfile(FNAME)) end)
            if ok and r then
                History   = r.H  or {}
                ItemHistory = r.IH or {}
                Favorites = r.F  or {}
                SavedOutfits = r.SO or {}
            end
        end
    end)
end
LoadData()

-- ═══════════════════════════════════════════════
-- TWEENS
-- ═══════════════════════════════════════════════
local function TW(o,g,t,s,d)
    local tw=X_Tween:Create(o,TweenInfo.new(t or .22,s or Enum.EasingStyle.Quart,d or Enum.EasingDirection.Out),g)
    tw:Play(); return tw
end
local function TWBack(o,g,t)
    X_Tween:Create(o,TweenInfo.new(t or .36,Enum.EasingStyle.Back,Enum.EasingDirection.Out),g):Play()
end

-- ═══════════════════════════════════════════════
-- COLORS
-- ═══════════════════════════════════════════════
local C = {
    WIN=Color3.fromRGB(10,10,10), PANEL=Color3.fromRGB(18,18,18),
    CARD=Color3.fromRGB(26,26,26), CARDHOV=Color3.fromRGB(36,36,36),
    INPUT=Color3.fromRGB(20,20,20), DIV=Color3.fromRGB(42,42,42),
    TXT=Color3.fromRGB(245,245,245), SUB=Color3.fromRGB(115,115,115),
    STROKE=Color3.fromRGB(48,48,48), STROKEHI=Color3.fromRGB(190,190,190),
    WHITE=Color3.fromRGB(238,238,238),
    BPRI=Color3.fromRGB(232,232,232), BSEC=Color3.fromRGB(32,32,32),
    BDNG=Color3.fromRGB(55,22,22),   BSAV=Color3.fromRGB(20,38,22),
    BFAV=Color3.fromRGB(42,34,14),   BTOG=Color3.fromRGB(46,46,46),
    NOK=Color3.fromRGB(170,170,170), NERR=Color3.fromRGB(210,70,70),
    NSAV=Color3.fromRGB(80,190,100), NFAV=Color3.fromRGB(210,160,50),
}

-- ═══════════════════════════════════════════════
-- NOTIFICATIONS
-- ═══════════════════════════════════════════════
local NGui=Instance.new("ScreenGui",X_Player.PlayerGui)
NGui.Name="X_NGuiV95"; NGui.ResetOnSpawn=false; NGui.DisplayOrder=99
local nQ,nBusy={},false
local function Pump()
    if nBusy or #nQ==0 then return end
    nBusy=true
    local msg,clr=table.unpack(table.remove(nQ,1)); clr=clr or C.NOK
    local bg=Instance.new("Frame",NGui)
    bg.Size=UDim2.new(0,240,0,44); bg.Position=UDim2.new(1,18,1,-68)
    bg.BackgroundColor3=Color3.fromRGB(14,14,14); bg.BorderSizePixel=0; bg.ZIndex=20
    Instance.new("UICorner",bg).CornerRadius=UDim.new(0,11)
    local sk=Instance.new("UIStroke",bg); sk.Color=clr; sk.Thickness=1.2
    local bar=Instance.new("Frame",bg)
    bar.Size=UDim2.new(0,3,1,-12); bar.Position=UDim2.new(0,8,0,6)
    bar.BackgroundColor3=clr; bar.BorderSizePixel=0
    Instance.new("UICorner",bar).CornerRadius=UDim.new(1,0)
    local lbl=Instance.new("TextLabel",bg)
    lbl.Size=UDim2.new(1,-24,1,0); lbl.Position=UDim2.new(0,20,0,0)
    lbl.Text=msg; lbl.TextColor3=C.TXT; lbl.BackgroundTransparency=1
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=12
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=21
    bg:TweenPosition(UDim2.new(1,-258,1,-68),"Out","Back",.36,true)
    task.delay(2.8,function()
        TW(bg,{Position=UDim2.new(1,18,1,-68)},.28)
        task.delay(.3,function() bg:Destroy(); nBusy=false; Pump() end)
    end)
end
local function Notify(msg,clr) table.insert(nQ,{msg,clr}); Pump() end

-- ═══════════════════════════════════════════════
-- FOV FIX
-- ═══════════════════════════════════════════════
local function ApplyFOV(char,hide)
    if not char then return end
    for _,n in ipairs({"Right Arm","Left Arm","RightUpperArm","RightLowerArm","RightHand",
                       "LeftUpperArm","LeftLowerArm","LeftHand"}) do
        local p=char:FindFirstChild(n)
        if p and p:IsA("BasePart") then
            if not p:FindFirstChild("_OT") then
                local v=Instance.new("NumberValue",p); v.Name="_OT"; v.Value=p.Transparency
            end
            p.Transparency=hide and 1 or (p:FindFirstChild("_OT") and p._OT.Value or 0)
        end
    end
    for _,v in pairs(char:GetChildren()) do
        if v:IsA("Accessory") then
            local h=v:FindFirstChild("Handle")
            if h then h.LocalTransparencyModifier=0 end
        end
    end
end

local function StartFOV()
    for _,c in pairs(FOVConns) do c:Disconnect() end; FOVConns={}
    local cam=workspace.CurrentCamera; local last=nil
    local conn=X_Run.RenderStepped:Connect(function()
        local char=X_Player.Character; if not char then return end
        cam=workspace.CurrentCamera
        local head=char:FindFirstChild("Head"); if not head then return end
        local inFOV=(cam.CFrame.Position-head.Position).Magnitude<1.2
        if inFOV~=last then
            last=inFOV; ApplyFOV(char,inFOV)
        end
    end)
    table.insert(FOVConns,conn)
end

-- ═══════════════════════════════════════════════
-- KORBLOX
-- ═══════════════════════════════════════════════
local function DoKorblox(on)
    local char=X_Player.Character; if not char then return end
    for _,v in pairs(char:GetChildren()) do if v.Name=="VKB" then v:Destroy() end end
    if on then
        local p=Instance.new("Part",char); p.Name="VKB"; p.Size=Vector3.new(1,2,1); p.CanCollide=false
        local m=Instance.new("SpecialMesh",p)
        m.MeshId="rbxassetid://902942096"; m.TextureId="rbxassetid://902843398"
        m.Scale=Vector3.new(1.2,1.2,1.2)
        local leg=char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg")
        if leg then
            local w=Instance.new("Weld",p); w.Part0=leg; w.Part1=p
            w.C0=(leg.Name=="Right Leg") and CFrame.new(0,.6,-.1) or CFrame.new(0,.15,0)
        end
        for _,n in ipairs({"RightUpperLeg","RightLowerLeg","RightFoot","Right Leg"}) do
            local pt=char:FindFirstChild(n); if pt then pt.Transparency=1 end
        end
    else
        for _,n in ipairs({"RightUpperLeg","RightLowerLeg","RightFoot","Right Leg"}) do
            local pt=char:FindFirstChild(n); if pt then pt.Transparency=0 end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- CORE APPLY  ← HumanoidDescription-first, works on ANY rig
-- ═══════════════════════════════════════════════════════════════
--
-- Strategy:
--   1. Call hum:ApplyDescription(hDesc)
--      → This sets: face, shirts, pants, body colors, body scale,
--        animations, AND accessories — all rig-safe, all correct.
--   2. Post-apply: enforce headless/korblox on top.
--
-- For single-item wear (not a full avatar change) we still weld manually.
-- ─────────────────────────────────────────────────────────────────
local function ApplyHDesc(hDesc, isReset)
    if not hDesc then
        Notify(isReset and "Reset Failed" or "Apply Failed", C.NERR); return
    end
    local char=X_Player.Character; if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end

    -- Let Roblox handle everything: clothes, face, accessories, body scale, anims
    local ok,err=pcall(function() hum:ApplyDescription(hDesc) end)
    if not ok then
        Notify("ApplyDescription error: "..(err or "?"), C.NERR); return
    end

    -- Store current desc
    CurHDesc = hDesc

    -- Post-apply: headless enforcement
    task.wait(0.05)
    local head=char:FindFirstChild("Head")
    if head then
        if HeadlessOn then
            head.Transparency=1
            for _,v in pairs(head:GetChildren()) do
                if v:IsA("Decal") then v.Transparency=1 end
            end
        else
            head.Transparency=0
            for _,v in pairs(head:GetChildren()) do
                if v:IsA("Decal") then v.Transparency=0 end
            end
        end
    end

    -- Post-apply: korblox
    DoKorblox(KorbloxOn)

    -- Restart FOV fix
    task.spawn(StartFOV)

    Notify(isReset and "Avatar Reset" or "Avatar Applied", isReset and C.NERR or C.NOK)
end

-- ═══════════════════════════════════════════════
-- CHANGE AVATAR (from username or userId)
-- ═══════════════════════════════════════════════
local function ChangeAvatar(input)
    input = tostring(input):match("^%s*(.-)%s*$")
    if input=="" then Notify("Enter a username or ID", C.NERR); return end

    -- Resolve userId
    local uid
    local numId=tonumber(input:match("^%d+$"))
    if numId and numId > 1000000 then
        -- looks like a userId (Roblox userIds are large numbers)
        uid=numId
    else
        local ok,res=pcall(function() return X_Players:GetUserIdFromNameAsync(input) end)
        if ok and res then uid=res
        elseif numId then uid=numId
        else Notify("User not found", C.NERR); return end
    end

    -- History
    local found=false
    for _,e in pairs(History) do
        if (type(e)=="table" and e.name==input) or e==input then found=true; break end
    end
    if not found then
        table.insert(History,1,{name=input, time=os.time()})
        if #History>30 then table.remove(History) end
        SaveData()
    end

    -- Fetch HumanoidDescription — this is the single source of truth
    -- It carries: face ID, shirt/pants IDs, accessory IDs, body colors,
    --             body scales, body type, and ALL animation IDs
    local hDesc
    local ok2,res2=pcall(function()
        return X_Players:GetHumanoidDescriptionFromUserId(uid)
    end)
    if ok2 and res2 then
        hDesc=res2
    else
        Notify("Could not fetch avatar data", C.NERR); return
    end

    ApplyHDesc(hDesc, false)
end

-- ═══════════════════════════════════════════════
-- WEAR SINGLE ITEM  (accessories, shirts, pants)
-- ═══════════════════════════════════════════════
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

local function WeldAcc(acc, char)
    local h=acc:FindFirstChild("Handle"); if not char or not h then return end
    local att=h:FindFirstChildOfClass("Attachment")
    local tar=att and char:FindFirstChild(att.Name,true)
    acc.Parent=char
    if tar then
        local w=Instance.new("Weld",h); w.Part0=h; w.Part1=tar.Parent
        w.C0=att.CFrame; w.C1=tar.CFrame
    end
end

local function WearSingleItem(id)
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
        if asset:IsA("Accessory") then
            WeldAcc(asset, char)
        else
            asset.Parent=char
        end
        Notify("Item Added",C.NOK); return true
    end
    return false
end

-- ═══════════════════════════════════════════════
-- INJECT BODY / FACE / HEAD
-- ═══════════════════════════════════════════════
local function InjectPart(id)
    local char=X_Player.Character; if not char then return false end
    local cid=tostring(id):match("%d+"); if not cid then return false end
    local head=char:FindFirstChild("Head")
    local ok,info=pcall(function() return X_Market:GetProductInfo(tonumber(cid)) end)
    if ok and info then
        local t=info.AssetTypeId
        if t==1 or t==18 then
            if head then
                local f=head:FindFirstChild("face") or Instance.new("Decal",head)
                f.Name="face"; f.Texture="rbxassetid://"..cid
                Notify("Face Injected",C.NOK); return true
            end
        elseif t==17 or t==24 then
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
--   U I
-- ═══════════════════════════════════════════════════════════════
local WIN_W,WIN_H=292,548
local Gui=Instance.new("ScreenGui",X_Player.PlayerGui)
Gui.Name="AvatarChangerV95"; Gui.ResetOnSpawn=false; Gui.DisplayOrder=10

-- Main window
local Main=Instance.new("Frame",Gui)
Main.Name="Main"
Main.Size=UDim2.new(0,WIN_W,0,WIN_H)
Main.Position=UDim2.new(.5,-WIN_W/2,.5,-WIN_H/2)
Main.BackgroundColor3=C.WIN; Main.Active=true
Main.ClipsDescendants=true; Main.Visible=false
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,16)
local wSK=Instance.new("UIStroke",Main); wSK.Color=C.STROKE; wSK.Thickness=1.4

-- Top accent line with gradient
local tLine=Instance.new("Frame",Main)
tLine.Size=UDim2.new(1,0,0,2); tLine.BackgroundColor3=C.WHITE
tLine.BorderSizePixel=0; tLine.ZIndex=6
Instance.new("UIGradient",tLine).Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(20,20,20)),
    ColorSequenceKeypoint.new(.25,C.WHITE),
    ColorSequenceKeypoint.new(.75,C.WHITE),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(20,20,20)),
})

-- Header
local HDR=Instance.new("Frame",Main)
HDR.Size=UDim2.new(1,0,0,54); HDR.Position=UDim2.new(0,0,0,2)
HDR.BackgroundColor3=C.PANEL; HDR.BorderSizePixel=0; HDR.ZIndex=4
local hLine=Instance.new("Frame",HDR)
hLine.Size=UDim2.new(1,0,0,1); hLine.Position=UDim2.new(0,0,1,-1)
hLine.BackgroundColor3=C.DIV; hLine.BorderSizePixel=0; hLine.ZIndex=5

local TitleLbl=Instance.new("TextLabel",HDR)
TitleLbl.Size=UDim2.new(0,200,0,24); TitleLbl.Position=UDim2.new(0,16,0,9)
TitleLbl.Text="AVATAR CHANGER"
TitleLbl.TextColor3=C.TXT; TitleLbl.Font=Enum.Font.GothamBold; TitleLbl.TextSize=14
TitleLbl.BackgroundTransparency=1; TitleLbl.TextXAlignment=Enum.TextXAlignment.Left; TitleLbl.ZIndex=5

local VerLbl=Instance.new("TextLabel",HDR)
VerLbl.Size=UDim2.new(0,200,0,15); VerLbl.Position=UDim2.new(0,16,0,33)
VerLbl.Text="V95  ·  by XYTHC"
VerLbl.TextColor3=C.SUB; VerLbl.Font=Enum.Font.Gotham; VerLbl.TextSize=10
VerLbl.BackgroundTransparency=1; VerLbl.TextXAlignment=Enum.TextXAlignment.Left; VerLbl.ZIndex=5

local CloseBtn=Instance.new("TextButton",HDR)
CloseBtn.Size=UDim2.new(0,28,0,28); CloseBtn.Position=UDim2.new(1,-40,0,13)
CloseBtn.BackgroundColor3=Color3.fromRGB(36,36,36); CloseBtn.Text="✕"
CloseBtn.TextColor3=C.SUB; CloseBtn.Font=Enum.Font.GothamBold; CloseBtn.TextSize=13; CloseBtn.ZIndex=5
Instance.new("UICorner",CloseBtn).CornerRadius=UDim.new(0,8)
CloseBtn.MouseEnter:Connect(function() TW(CloseBtn,{TextColor3=Color3.fromRGB(230,80,80)},.13) end)
CloseBtn.MouseLeave:Connect(function() TW(CloseBtn,{TextColor3=C.SUB},.13) end)

-- Tab bar
local TabBar=Instance.new("Frame",Main)
TabBar.Size=UDim2.new(1,-22,0,36); TabBar.Position=UDim2.new(0,11,0,62)
TabBar.BackgroundColor3=C.CARD; TabBar.ZIndex=4
Instance.new("UICorner",TabBar).CornerRadius=UDim.new(0,10)

local function MkTab(txt,xs,active)
    local b=Instance.new("TextButton",TabBar)
    b.Size=UDim2.new(.5,-4,1,-6); b.Position=UDim2.new(xs, xs==0 and 3 or 1, 0, 3)
    b.BackgroundColor3=active and C.WHITE or Color3.fromRGB(0,0,0)
    b.BackgroundTransparency=active and 0 or 1
    b.Text=txt; b.Font=Enum.Font.GothamBold; b.TextSize=11; b.ZIndex=5
    b.TextColor3=active and C.WIN or C.SUB
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    return b
end
local TAB_C=MkTab("CHANGER",0,true)
local TAB_H=MkTab("HISTORY",.5,false)

-- Scroll pages
local PY=104
local PageC=Instance.new("ScrollingFrame",Main)
PageC.Size=UDim2.new(1,0,1,-PY); PageC.Position=UDim2.new(0,0,0,PY)
PageC.BackgroundTransparency=1; PageC.ScrollBarThickness=3
PageC.ScrollBarImageColor3=Color3.fromRGB(65,65,65); PageC.BorderSizePixel=0

local PageH=Instance.new("ScrollingFrame",Main)
PageH.Size=UDim2.new(1,0,1,-PY); PageH.Position=UDim2.new(0,0,0,PY)
PageH.BackgroundTransparency=1; PageH.ScrollBarThickness=3
PageH.ScrollBarImageColor3=Color3.fromRGB(65,65,65); PageH.Visible=false; PageH.BorderSizePixel=0

-- ── Changer page layout ────────────────────────────────────────────
local PAD=13; local cY=12

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
local IW=Instance.new("Frame",PageC)
IW.Size=UDim2.new(1,-PAD*2,0,42); IW.Position=UDim2.new(0,PAD,0,cY)
IW.BackgroundColor3=C.INPUT; IW.ZIndex=4
Instance.new("UICorner",IW).CornerRadius=UDim.new(0,11)
local iSK=Instance.new("UIStroke",IW); iSK.Color=C.STROKE; iSK.Thickness=1

local iIco=Instance.new("TextLabel",IW)
iIco.Size=UDim2.new(0,36,1,0); iIco.Text="  "
iIco.TextColor3=C.SUB; iIco.BackgroundTransparency=1
iIco.Font=Enum.Font.GothamBold; iIco.TextSize=16; iIco.ZIndex=5

local Box=Instance.new("TextBox",IW)
Box.Size=UDim2.new(1,-38,1,0); Box.Position=UDim2.new(0,34,0,0)
Box.BackgroundTransparency=1; Box.Text=""
Box.PlaceholderText="Username / Item ID / Link..."
Box.PlaceholderColor3=C.SUB; Box.TextColor3=C.TXT
Box.Font=Enum.Font.Gotham; Box.TextSize=13; Box.ZIndex=5; Box.ClearTextOnFocus=false
Box.Focused:Connect(function()  TW(iSK,{Color=C.STROKEHI,Thickness=1.5},.16) end)
Box.FocusLost:Connect(function() TW(iSK,{Color=C.STROKE,Thickness=1},.16) end)
cY=cY+52

-- Button builder
local function MkBtn(txt,bg,fg,bh)
    bh=bh or 40
    local card=Instance.new("Frame",PageC)
    card.Size=UDim2.new(1,-PAD*2,0,bh); card.Position=UDim2.new(0,PAD,0,cY)
    card.BackgroundColor3=bg; card.ZIndex=4
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,11)
    if bg~=C.BPRI then
        local sk=Instance.new("UIStroke",card); sk.Color=C.DIV; sk.Thickness=1
    end
    cY=cY+bh+9
    local btn=Instance.new("TextButton",card)
    btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1
    btn.Text=txt; btn.TextColor3=fg or C.TXT
    btn.Font=Enum.Font.GothamBold; btn.TextSize=12; btn.ZIndex=5
    btn.MouseEnter:Connect(function()
        TW(card,{BackgroundColor3=Color3.new(
            math.min(bg.R+.07,1),math.min(bg.G+.07,1),math.min(bg.B+.07,1))},.13)
    end)
    btn.MouseLeave:Connect(function() TW(card,{BackgroundColor3=bg},.13) end)
    btn.MouseButton1Down:Connect(function() TW(card,{Size=UDim2.new(1,-PAD*2-6,0,bh-4)},.08) end)
    btn.MouseButton1Up:Connect(function()   TW(card,{Size=UDim2.new(1,-PAD*2,0,bh)},.18)    end)
    return btn,card
end

-- Toggle builder — FIXED: state flips correctly, no double-connect bug
local function MkToggle(txtOff,txtOn,bgOff,bgOn,fgOff,fgOn)
    local btn,card=MkBtn(txtOff,bgOff,fgOff)
    local state=false
    -- Internal sync (called by external code to force a state)
    local function Sync(v)
        state=v
        btn.Text=v and txtOn or txtOff
        TW(btn,{TextColor3=v and (fgOn or C.TXT) or (fgOff or C.SUB)},.16)
        TW(card,{BackgroundColor3=v and bgOn or bgOff},.16)
        local sk=card:FindFirstChildOfClass("UIStroke")
        if sk then TW(sk,{Color=v and C.STROKEHI or C.DIV},.16) end
    end
    -- The button click ONLY flips state and fires Sync — no external reconnects needed
    btn.MouseButton1Click:Connect(function() Sync(not state) end)
    return btn, card,
        function(v) Sync(v) end,       -- setter
        function()  return state end   -- getter
end

-- Build buttons
Sep("AVATAR")
local B_CHANGE = MkBtn("  CHANGE AVATAR",     C.BPRI, C.WIN)
local B_WEAR   = MkBtn("  WEAR ITEM / ID",    C.BSEC, C.TXT)
local B_INJ    = MkBtn("  INJECT BODY / FACE / HEAD", C.BSEC, C.TXT)

Sep("TOGGLES")
local B_KB,_,SetKB,GetKB = MkToggle(
    "  KORBLOX: OFF","  KORBLOX: ON",
    C.BSEC, C.BTOG, C.SUB, C.TXT
)
local B_HL,_,SetHL,GetHL = MkToggle(
    "  HEADLESS: OFF","  HEADLESS: ON",
    C.BSEC, C.BTOG, C.SUB, C.TXT
)

Sep("MANAGE")
local B_FAV   = MkBtn("  ADD TO FAVORITES",   C.BFAV, Color3.fromRGB(210,170,60))
local B_SAVO  = MkBtn("  SAVE CURRENT OUTFIT", C.BSAV, Color3.fromRGB(90,200,110))
local B_RESET = MkBtn("  RESET AVATAR",        C.BDNG, Color3.fromRGB(220,90,90))

PageC.CanvasSize=UDim2.new(0,0,0,cY+14)

-- ── Button actions ─────────────────────────────────────────────────
B_CHANGE.MouseButton1Click:Connect(function()
    ChangeAvatar(Box.Text)
end)

B_WEAR.MouseButton1Click:Connect(function()
    local cid=Box.Text:match("%d+"); if not cid then Notify("No ID found",C.NERR); return end
    if WearSingleItem(cid) then
        local found=false
        for _,e in pairs(ItemHistory) do
            if (type(e)=="table" and e.id==cid) or e==cid then found=true; break end
        end
        if not found then
            table.insert(ItemHistory,1,{id=cid,time=os.time()})
            if #ItemHistory>30 then table.remove(ItemHistory) end
            SaveData()
        end
    else Notify("Item not found",C.NERR) end
end)

B_INJ.MouseButton1Click:Connect(function()
    local cid=Box.Text:match("%d+"); if not cid then Notify("No ID found",C.NERR); return end
    if not InjectPart(cid) then Notify("Inject failed",C.NERR) end
end)

-- Korblox toggle — read state AFTER MkToggle's internal click already fired
B_KB.MouseButton1Click:Connect(function()
    task.defer(function()
        KorbloxOn=GetKB(); DoKorblox(KorbloxOn)
    end)
end)

-- Headless toggle
B_HL.MouseButton1Click:Connect(function()
    task.defer(function()
        HeadlessOn=GetHL()
        local char=X_Player.Character; if not char then return end
        local head=char:FindFirstChild("Head"); if not head then return end
        head.Transparency=HeadlessOn and 1 or 0
        for _,v in pairs(head:GetChildren()) do
            if v:IsA("Decal") then v.Transparency=HeadlessOn and 1 or 0 end
        end
    end)
end)

B_FAV.MouseButton1Click:Connect(function()
    if Box.Text=="" then Notify("Enter something first",C.NERR); return end
    if not table.find(Favorites,Box.Text) then
        table.insert(Favorites,Box.Text); SaveData(); Notify("Added to Favorites",C.NFAV)
    else Notify("Already in Favorites",C.NERR) end
end)

B_SAVO.MouseButton1Click:Connect(function()
    if not CurHDesc then Notify("No outfit applied yet",C.NERR); return end
    local name=Box.Text~="" and Box.Text or ("Outfit "..tostring(os.time()))
    -- Store the HDesc property table so it can be re-applied later
    local descData={
        FaceId=CurHDesc.Face,
        Shirt=CurHDesc.Shirt, Pants=CurHDesc.Pants,
        -- serialise the full desc as a snapshot reference
        _hDesc=CurHDesc
    }
    SavedOutfits[name]=descData; SaveData()
    Notify("Saved: "..name, C.NSAV)
end)

B_RESET.MouseButton1Click:Connect(function()
    KorbloxOn=false; HeadlessOn=false
    SetKB(false); SetHL(false)
    ApplyHDesc(OrigHDesc, true)
end)

-- ── History page ───────────────────────────────────────────────────
local function FmtTime(t)
    if not t then return nil end
    local d=os.time()-t
    if d<60 then return d.."s ago"
    elseif d<3600 then return math.floor(d/60).."m ago"
    else return math.floor(d/3600).."h ago" end
end

local function MkCard(par,main,sub,bg,cb)
    local h=sub and 46 or 40
    local card=Instance.new("Frame",par)
    card.Size=UDim2.new(1,-22,0,h); card.BackgroundColor3=bg or C.CARD; card.ZIndex=4
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,10)
    local sk=Instance.new("UIStroke",card); sk.Color=C.DIV; sk.Thickness=1
    local lbl=Instance.new("TextButton",card)
    lbl.Size=UDim2.new(1,-44, sub and 0 or 1, sub and 22 or 0)
    lbl.Position=UDim2.new(0,12, 0, sub and 5 or 0)
    lbl.BackgroundTransparency=1; lbl.Text=main; lbl.TextColor3=C.TXT
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=11
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=5
    lbl.TextTruncate=Enum.TextTruncate.AtEnd
    if sub then
        local s=Instance.new("TextLabel",card)
        s.Size=UDim2.new(1,-44,0,15); s.Position=UDim2.new(0,12,0,26)
        s.BackgroundTransparency=1; s.Text=sub; s.TextColor3=C.SUB
        s.Font=Enum.Font.Gotham; s.TextSize=9
        s.TextXAlignment=Enum.TextXAlignment.Left; s.ZIndex=5
    end
    if cb then
        lbl.MouseButton1Click:Connect(cb)
        lbl.MouseEnter:Connect(function()  TW(card,{BackgroundColor3=C.CARDHOV},.11) end)
        lbl.MouseLeave:Connect(function()  TW(card,{BackgroundColor3=bg or C.CARD},.11) end)
    end
    return card
end

local function MkSecLbl(par,txt,lo)
    local l=Instance.new("TextLabel",par)
    l.Size=UDim2.new(1,-22,0,20); l.BackgroundTransparency=1
    l.Text=txt; l.TextColor3=C.STROKEHI; l.Font=Enum.Font.GothamBold; l.TextSize=9
    l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=4; l.LayoutOrder=lo
    return l
end

local function MkDel(par,cb)
    local d=Instance.new("TextButton",par)
    d.Size=UDim2.new(0,26,0,26); d.Position=UDim2.new(1,-32,.5,-13)
    d.BackgroundColor3=Color3.fromRGB(44,18,18); d.Text="✕"
    d.TextColor3=Color3.fromRGB(190,70,70)
    d.Font=Enum.Font.GothamBold; d.TextSize=11; d.ZIndex=6
    Instance.new("UICorner",d).CornerRadius=UDim.new(0,7)
    d.MouseButton1Click:Connect(cb)
end

local function GoChanger(txt)
    if txt then Box.Text=txt end
    PageH.Visible=false; PageC.Visible=true
    TW(TAB_C,{BackgroundColor3=C.WHITE,BackgroundTransparency=0,TextColor3=C.WIN},.16)
    TW(TAB_H,{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,TextColor3=C.SUB},.16)
end

local function BuildHistory()
    for _,v in pairs(PageH:GetChildren()) do
        if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then v:Destroy() end
    end
    local lay=Instance.new("UIListLayout",PageH)
    lay.Padding=UDim.new(0,7); lay.HorizontalAlignment=Enum.HorizontalAlignment.Center
    lay.SortOrder=Enum.SortOrder.LayoutOrder
    Instance.new("UIPadding",PageH).PaddingTop=UDim.new(0,10)
    local lo=1

    -- Saved outfits
    if next(SavedOutfits) then
        MkSecLbl(PageH,"  SAVED OUTFITS",lo); lo=lo+1
        for name,data in pairs(SavedOutfits) do
            local c=MkCard(PageH,name,nil,Color3.fromRGB(18,32,20),function()
                if data._hDesc then
                    ApplyHDesc(data._hDesc,false)
                    Notify("Loaded: "..name,C.NSAV)
                end
            end)
            c.LayoutOrder=lo; lo=lo+1
            MkDel(c,function() SavedOutfits[name]=nil; SaveData(); BuildHistory() end)
        end
    end

    -- Favorites
    if #Favorites>0 then
        MkSecLbl(PageH,"  FAVORITES",lo); lo=lo+1
        for idx,fav in ipairs(Favorites) do
            local c=MkCard(PageH,fav,nil,Color3.fromRGB(36,26,10),function() GoChanger(fav) end)
            c.LayoutOrder=lo; lo=lo+1
            local di=idx
            MkDel(c,function() table.remove(Favorites,di); SaveData(); BuildHistory() end)
        end
    end

    -- Avatar history
    if #History>0 then
        MkSecLbl(PageH,"  AVATAR HISTORY",lo); lo=lo+1
        for _,e in ipairs(History) do
            local name=type(e)=="table" and e.name or tostring(e)
            local ts=type(e)=="table" and FmtTime(e.time) or nil
            local c=MkCard(PageH,name,ts,C.CARD,function() GoChanger(name) end)
            c.LayoutOrder=lo; lo=lo+1
        end
    end

    -- Item history
    if #ItemHistory>0 then
        MkSecLbl(PageH,"  ITEM HISTORY",lo); lo=lo+1
        for _,e in ipairs(ItemHistory) do
            local id=type(e)=="table" and e.id or tostring(e)
            local ts=type(e)=="table" and FmtTime(e.time) or nil
            local c=MkCard(PageH,"ID: "..id,ts,C.CARD,function() GoChanger(id) end)
            c.LayoutOrder=lo; lo=lo+1
        end
    end

    -- Empty
    if #History==0 and #ItemHistory==0 and #Favorites==0 and not next(SavedOutfits) then
        local e=Instance.new("TextLabel",PageH)
        e.Size=UDim2.new(1,0,0,60); e.BackgroundTransparency=1
        e.Text="Nothing here yet"; e.TextColor3=C.SUB
        e.Font=Enum.Font.Gotham; e.TextSize=12; e.ZIndex=4; e.LayoutOrder=1
    end

    -- Clear history
    if #History>0 or #ItemHistory>0 then
        local clr=Instance.new("TextButton",PageH)
        clr.Size=UDim2.new(1,-22,0,34); clr.BackgroundColor3=Color3.fromRGB(38,16,16)
        clr.Text="  CLEAR HISTORY"; clr.TextColor3=Color3.fromRGB(190,70,70)
        clr.Font=Enum.Font.GothamBold; clr.TextSize=11; clr.ZIndex=4; clr.LayoutOrder=lo+999
        Instance.new("UICorner",clr).CornerRadius=UDim.new(0,10)
        clr.MouseButton1Click:Connect(function()
            History={}; ItemHistory={}; SaveData(); BuildHistory()
            Notify("History Cleared",C.NERR)
        end)
    end

    task.wait()
    PageH.CanvasSize=UDim2.new(0,0,0,lay.AbsoluteContentSize.Y+26)
end

-- Tab switching
TAB_H.MouseButton1Click:Connect(function()
    PageC.Visible=false; PageH.Visible=true; BuildHistory()
    TW(TAB_H,{BackgroundColor3=C.WHITE,BackgroundTransparency=0,TextColor3=C.WIN},.16)
    TW(TAB_C,{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,TextColor3=C.SUB},.16)
end)
TAB_C.MouseButton1Click:Connect(function()
    PageH.Visible=false; PageC.Visible=true
    TW(TAB_C,{BackgroundColor3=C.WHITE,BackgroundTransparency=0,TextColor3=C.WIN},.16)
    TW(TAB_H,{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,TextColor3=C.SUB},.16)
end)

-- ── Floating icon ──────────────────────────────────────────────────
local Ico=Instance.new("TextButton",Gui)
Ico.Size=UDim2.new(0,50,0,50); Ico.Position=UDim2.new(0,14,0,14)
Ico.BackgroundColor3=Color3.fromRGB(16,16,16); Ico.Text=""; Ico.ZIndex=5
Instance.new("UICorner",Ico).CornerRadius=UDim.new(0,14)
local icoSK=Instance.new("UIStroke",Ico); icoSK.Color=C.STROKE; icoSK.Thickness=1.3

local icoLbl=Instance.new("TextLabel",Ico)
icoLbl.Size=UDim2.new(1,0,.65,0); icoLbl.Position=UDim2.new(0,0,.1,0)
icoLbl.Text=""; icoLbl.TextSize=21; icoLbl.BackgroundTransparency=1
icoLbl.ZIndex=6; icoLbl.Font=Enum.Font.Gotham

local Dot=Instance.new("Frame",Ico)
Dot.Size=UDim2.new(0,10,0,10); Dot.Position=UDim2.new(1,-12,0,2)
Dot.BackgroundColor3=Color3.fromRGB(220,55,55); Dot.ZIndex=7
Instance.new("UICorner",Dot).CornerRadius=UDim.new(1,0)

local function SetDot(open)
    TW(Dot,{BackgroundColor3=open and Color3.fromRGB(90,215,110) or Color3.fromRGB(220,55,55)},.2)
end
Ico.MouseEnter:Connect(function()
    TWBack(Ico,{Size=UDim2.new(0,54,0,54),Position=UDim2.new(0,12,0,12)},.2)
    TW(icoSK,{Color=C.STROKEHI},.14)
end)
Ico.MouseLeave:Connect(function()
    TWBack(Ico,{Size=UDim2.new(0,50,0,50),Position=UDim2.new(0,14,0,14)},.2)
    TW(icoSK,{Color=C.STROKE},.14)
end)
Ico.MouseButton1Click:Connect(function()
    if not Main.Visible then
        Main.Size=UDim2.new(0,0,0,0); Main.Position=UDim2.new(.5,0,.5,0); Main.Visible=true
        TWBack(Main,{Size=UDim2.new(0,WIN_W,0,WIN_H),Position=UDim2.new(.5,-WIN_W/2,.5,-WIN_H/2)},.4)
        SetDot(true)
    else
        TW(Main,{Size=UDim2.new(0,0,0,0),Position=UDim2.new(.5,0,.5,0)},.2)
        task.delay(.21,function() Main.Visible=false end); SetDot(false)
    end
end)
CloseBtn.MouseButton1Click:Connect(function()
    TW(Main,{Size=UDim2.new(0,0,0,0),Position=UDim2.new(.5,0,.5,0)},.2)
    task.delay(.21,function() Main.Visible=false end); SetDot(false)
end)

-- ── Drag ───────────────────────────────────────────────────────────
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

-- ═══════════════════════════════════════════════
-- RESPAWN HANDLER
-- ═══════════════════════════════════════════════
X_Player.CharacterAdded:Connect(function()
    task.wait(0.8)  -- wait for character to fully load
    local desc=CurHDesc or OrigHDesc
    if desc then ApplyHDesc(desc, CurHDesc==nil) end
    task.spawn(StartFOV)
end)

-- ═══════════════════════════════════════════════
-- INIT — capture original HumanoidDescription
-- ═══════════════════════════════════════════════
local initChar=X_Player.Character or X_Player.CharacterAdded:Wait()

-- Method 1: get from currently applied description (most accurate)
pcall(function()
    local hum=initChar:FindFirstChildOfClass("Humanoid")
    if hum then OrigHDesc=hum:GetAppliedDescription() end
end)

-- Method 2: fallback fetch from API
if not OrigHDesc then
    pcall(function()
        OrigHDesc=X_Players:GetHumanoidDescriptionFromUserId(X_Player.UserId)
    end)
end

task.spawn(StartFOV)
Notify("Avatar Changer V95  Ready", C.NOK)
