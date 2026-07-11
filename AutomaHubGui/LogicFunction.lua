--!strict

-- Services
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- Clean up any standalone UI if present
pcall(function()
    local cg = (gethui and gethui()) or game:GetService("CoreGui")
    local oldParry = cg:FindFirstChild("AutomaHub_AutoParry")
    if oldParry then oldParry:Destroy() end
    local oldESP = cg:FindFirstChild("AutomaHub_ESP")
    if oldESP then oldESP:Destroy() end
end)

-- =====================================================================
-- COMBAT MODULE (Anti Auto Parry)
-- =====================================================================

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid  = Character:WaitForChild("Humanoid")
local RootPart  = Character:WaitForChild("HumanoidRootPart")

local antiAutoParryEnabled = false
local loadAntiParryTrack

LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid") :: Humanoid
    RootPart = newChar:WaitForChild("HumanoidRootPart") :: BasePart
    if loadAntiParryTrack then
        task.spawn(loadAntiParryTrack, newChar)
    end
end)

-- =====================================================================
-- AUTO DROP PALLET MODULE
-- =====================================================================
local autoPalletEnabled: boolean = false
local TRIGGER_DISTANCE: number = 13.2
local PLAYER_INTERACT_DISTANCE: number = 6 

local droppedDebounce: { [Instance]: boolean } = {}
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PalletDropEvent = Remotes:WaitForChild("Pallet"):WaitForChild("PalletDropEvent") :: any

local keybindConnection: RBXScriptConnection
keybindConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.J then
        TRIGGER_DISTANCE = math.round((TRIGGER_DISTANCE + 0.1) * 10) / 10
        print("AutoPallet Jarak Trigger Bertambah:", TRIGGER_DISTANCE)
    elseif input.KeyCode == Enum.KeyCode.K then
        TRIGGER_DISTANCE = math.max(0.1, math.round((TRIGGER_DISTANCE - 0.1) * 10) / 10)
        print("AutoPallet Jarak Trigger Berkurang:", TRIGGER_DISTANCE)
    end
end)

local function getKillerCharacter(): Model?
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Team and p.Team.Name == "Killer" then
            return p.Character
        end
    end
    return nil
end

local connection: RBXScriptConnection
connection = RunService.Heartbeat:Connect(function()
    if not autoPalletEnabled then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local hum = char and char:FindFirstChildOfClass("Humanoid") :: Humanoid?
    if not hrp or not hum or hum.Health <= 50 then return end
    
    if hrp:HasTag("doing action") or hrp:HasTag("carried") or char:GetAttribute("carried") then
        return
    end
    
    local killerChar = getKillerCharacter()
    local killerHrp = killerChar and killerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not killerHrp then return end
    
    local palletPoints = CollectionService:GetTagged("PalletPoint")
    for _, palletPoint in ipairs(palletPoints) do
        if palletPoint:IsA("BasePart") and not droppedDebounce[palletPoint] then
            local distToPlayer = (palletPoint.Position - hrp.Position).Magnitude
            if distToPlayer <= PLAYER_INTERACT_DISTANCE then
                local distToKiller = (palletPoint.Position - killerHrp.Position).Magnitude
                
                if distToKiller <= TRIGGER_DISTANCE then
                    droppedDebounce[palletPoint] = true
                    pcall(function()
                        PalletDropEvent:FireServer(palletPoint)
                    end)
                    task.delay(5, function()
                        droppedDebounce[palletPoint] = nil
                    end)
                end
            end
        end
    end
end)

if _G.AutoPalletConnection then
    pcall(function() (_G.AutoPalletConnection :: any):Disconnect() end)
end
if _G.AutoPalletKeybindConnection then
    pcall(function() (_G.AutoPalletKeybindConnection :: any):Disconnect() end)
end

_G.AutoPalletConnection = connection
_G.AutoPalletKeybindConnection = keybindConnection

-- =====================================================================
-- AUTO SKILLCHECK MODULE
-- =====================================================================
local autoSkillcheckEnabled = false
local scTriggered = false

local CONFIG_SC = {
    zoneCenter   = 108,
    zoneMax      = 116,
}

local VirtualInputManager = game:GetService("VirtualInputManager")

-- ponytail: virtual input lets Roblox's engine handle the skillcheck state naturally
local function simulateInput()
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local survivorMob = PlayerGui and PlayerGui:FindFirstChild("Survivor-mob")
    local actionButton = survivorMob and survivorMob:FindFirstChild("Controls") and survivorMob.Controls:FindFirstChild("action")

    local isMobileButtonActive = false
    if actionButton and actionButton.Visible then
        local screenGui = actionButton:FindFirstAncestorOfClass("ScreenGui")
        if screenGui and screenGui.Enabled then
            isMobileButtonActive = true
        end
    end

    if isMobileButtonActive and actionButton then
        if firesignal then
            firesignal(actionButton.MouseButton1Down)
        else
            local pos = actionButton.AbsolutePosition + (actionButton.AbsoluteSize / 2)
            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game)
        end
    else
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end
end

-- ponytail: track lastHitRotation to detect when a new skillcheck is presented within the same open GUI (e.g. King Scourge)
local lastHitRotation = -1

RunService.Heartbeat:Connect(function()
    if not autoSkillcheckEnabled then return end

    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local gui = PlayerGui and PlayerGui:FindFirstChild("SkillCheckPromptGui")
    if not gui then 
        scTriggered = false
        lastHitRotation = -1
        return 
    end

    local check = gui:FindFirstChild("Check")
    if not check or not check.Visible then
        scTriggered = false
        lastHitRotation = -1
        return
    end

    local line = check:FindFirstChild("Line")
    local goal = check:FindFirstChild("Goal")
    if not line or not goal then return end

    local rotation = line.Rotation
    local goalRotation = goal.Rotation
    
    -- If the goal has changed significantly (new stage) or needle reset, reset trigger
    if scTriggered and math.abs(goalRotation - lastHitRotation) > 1 then
        scTriggered = false
    end

    if scTriggered then return end

    local perfectZone = CONFIG_SC.zoneCenter + goalRotation
    local maxZone = CONFIG_SC.zoneMax + goalRotation

    if rotation >= perfectZone and rotation <= maxZone then
        scTriggered = true
        lastHitRotation = goalRotation
        task.spawn(simulateInput)
    end
end)



--Anti Auto Parry

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local antiParryAnimation = Instance.new("Animation")
antiParryAnimation.AnimationId = "rbxassetid://117042998468241"
local antiParryTrack = nil

local ATTACK_ANIM_IDS: { [string]: boolean } = {
    ["117042998468241"] = true, ["129784271201071"] = true, ["113255068724446"] = true,
    ["118907603246885"] = true, ["122812055447896"] = true, ["110355011987939"] = true,
    ["135002183282873"] = true, ["105374834496520"] = true, ["138720291317243"] = true,
    ["115244153053858"] = true, ["106871536134254"] = true,
    ["139369275981139"] = true, -- Slasher basic attack
}

function loadAntiParryTrack(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then
        warn("[AutomaHub AntiAutoParry] Humanoid not found on character!")
        return
    end
    local animator = hum:WaitForChild("Animator", 5)
    
    -- Dynamically find the correct attack animation ID for this killer from ReplicatedStorage
    local animId = "117042998468241" -- Default fallback (Slasher attack)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Killers = ReplicatedStorage:FindFirstChild("Killers")
    if Killers then
        local killerFolder = Killers:FindFirstChild(char.Name)
        if killerFolder then
            local foundAnim = nil
            local function search(inst)
                if inst:IsA("Animation") then
                    local id = inst.AnimationId:match("%d+")
                    if id and ATTACK_ANIM_IDS[id] then
                        foundAnim = inst
                        return true
                    end
                end
                for _, child in ipairs(inst:GetChildren()) do
                    if search(child) then return true end
                end
                return false
            end
            search(killerFolder)
            if foundAnim then
                animId = foundAnim.AnimationId:match("%d+")
            end
        end
    end
    
    antiParryAnimation.AnimationId = "rbxassetid://" .. animId
    
    local success, track
    if animator then
        success, track = pcall(function() return animator:LoadAnimation(antiParryAnimation) end)
    end
    if not success or not track then
        success, track = pcall(function() return hum:LoadAnimation(antiParryAnimation) end)
    end
    
    if success and track then
        antiParryTrack = track
        print("[AutomaHub AntiAutoParry] Animation loaded successfully for killer: " .. char.Name .. " (ID: " .. animId .. ")")
    else
        warn("[AutomaHub AntiAutoParry] Failed to load animation: " .. tostring(track))
    end
end

if Character then
    task.spawn(loadAntiParryTrack, Character)
end

local function getNearestSurvivorDistance()
    local myRoot = RootPart
    if not myRoot then return 999 end
    local minDist = 999
    local playersList = Players:GetPlayers()
    for i = 1, #playersList do
        local p = playersList[i]
        if p ~= LocalPlayer and p.Team and p.Team.Name == "Survivors" then
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (myRoot.Position - hrp.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                end
            end
        end
    end
    return minDist
end

local antiParryScriptId = HttpService:GenerateGUID(false)
_G.AntiAutoParryScriptId = antiParryScriptId

task.spawn(function()
    print("[AutomaHub AntiAutoParry] Loop started with ID:", antiParryScriptId)
    while _G.AntiAutoParryScriptId == antiParryScriptId do
        task.wait(0.3)
        if antiAutoParryEnabled then
            if not antiParryTrack then
                if Character and Character.Parent then
                    loadAntiParryTrack(Character)
                end
            end
            if antiParryTrack and Character and Character.Parent then
                local dist = getNearestSurvivorDistance()
                if dist <= 15 then
                    print("[AutomaHub AntiAutoParry] Survivor detected at distance:", dist, "- Playing bait animation!")
                    local pOk, pErr = pcall(function()
                        antiParryTrack:Play()
                        antiParryTrack:AdjustWeight(0)
                        task.wait(0.05)
                        antiParryTrack:Stop()
                    end)
                    if not pOk then
                        warn("[AutomaHub AntiAutoParry] Error playing track:", tostring(pErr))
                    end
                end
            end
        end
    end
end)


-- =====================================================================
-- VAULT MODULE (Fast Vault)
-- =====================================================================
local fastVaultEnabled = false

do
    -- ponytail: match-lifecycle optimized fast vault (0% lag)
    local Survivors = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Survivors")

    local AnimController = require(Survivors:WaitForChild("SurvivorAnimationsController"))
    local Actions = require(Survivors:WaitForChild("SurvivorActions"))

    -- 1. Hook Always Fast Vault (hanya sekali setup, guard by flag)
    AnimController._isFacingStraightEnough = function()
        if not fastVaultEnabled then return AnimController._isFacingStraightEnough end
        return true, 0
    end

    local oldOnVault = AnimController._onVaultAnimation
    AnimController._onVaultAnimation = function(self, vaultPoint, isSprinting)
        if not fastVaultEnabled then return oldOnVault(self, vaultPoint, isSprinting) end
        local hrp = self.humanoidRootPart or (self.character and self.character:FindFirstChild("HumanoidRootPart"))
        if hrp then
            local oldV = hrp.Velocity
            hrp.Velocity = Vector3.new(16, 0, 0)
            oldOnVault(self, vaultPoint, true)
            hrp.Velocity = oldV
        else
            oldOnVault(self, vaultPoint, true)
        end
    end

    local oldStartVault = Actions.startVault
    Actions.startVault = function(p49, p50)
        if not fastVaultEnabled then return oldStartVault(p49, p50) end
        local char = p49.character
        local oldSprint = char and char:GetAttribute("Sprinting")
        if char then char:SetAttribute("Sprinting", true) end
        local oldFlag = p49.getSprintFlag
        p49.getSprintFlag = function() return true end
        local ok, err = pcall(oldStartVault, p49, p50)
        p49.getSprintFlag = oldFlag
        if char then char:SetAttribute("Sprinting", oldSprint) end
        if not ok then error(err) end
    end


end


-- =====================================================================
-- VISUAL (ESP) MODULE
-- =====================================================================

local COLOR_GEN     = Color3.fromRGB(85, 255, 85)
local COLOR_PALLET  = Color3.fromRGB(255, 215, 0)
local COLOR_ZOMBIE  = Color3.fromRGB(255, 60, 60)
local COLOR_PLAYER  = Color3.fromRGB(0, 255, 170)
local COLOR_KILLER  = Color3.fromRGB(255, 60, 60)
local COLOR_OUTLINE = Color3.fromRGB(255, 255, 255)

type ESPKind = "Generator" | "Pallet" | "SCP" | "Player"

type TrackedEntry = {
    hl: Highlight?,
    bill: BillboardGui?,
    anchor: BasePart,
    sub: TextLabel?,
    nameL: TextLabel?,
    progConns: { RBXScriptConnection }?,
    wantDist: boolean?,
    kind: ESPKind
}

local ESP = {}

local espMasterEnabled = false
local selectedKinds: { [string]: boolean } = {
    Generator = false,
    Pallet = false,
    SCP = false,
    Player = false
}

local activeKinds: { [string]: boolean } = {
    Generator = false,
    Pallet = false,
    SCP = false,
    Player = false
}

local tracked: { [Instance]: TrackedEntry } = {}
local connsByKind: { [string]: { RBXScriptConnection } } = {
    Generator = {},
    Pallet = {},
    SCP = {},
    Player = {}
}

local distLoopRunning = false

local function isKindActive(kind: string): boolean
    return espMasterEnabled and (selectedKinds[kind] == true)
end

local function pushConn(kind: string, c: RBXScriptConnection)
    local cs = connsByKind[kind]
    if cs then cs[#cs + 1] = c end
end

local function cleanup(model: Instance)
    local t = tracked[model]
    if not t then return end
    if t.progConns then
        for _, c in ipairs(t.progConns) do pcall(function() c:Disconnect() end) end
    end
    if t.hl then pcall(function() t.hl:Destroy() end) end
    if t.bill then pcall(function() t.bill:Destroy() end) end
    tracked[model] = nil
end

local function stopKind(kind: string)
    local cs = connsByKind[kind]
    if cs then
        for _, c in ipairs(cs) do pcall(function() c:Disconnect() end) end
        connsByKind[kind] = {}
    end
    for key, e in pairs(tracked) do
        if e.kind == kind then cleanup(key) end
    end
end

local function mkHighlight(model: Instance, color: Color3): Highlight
    local hl = Instance.new("Highlight")
    hl.Name = "ESP_ObjHL"
    hl.FillColor = color
    hl.OutlineColor = COLOR_OUTLINE
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = model
    hl.Parent = model
    return hl
end

local function mkBillboard(anchor: BasePart, color: Color3, topText: string): (BillboardGui, TextLabel, TextLabel)
    local bill = Instance.new("BillboardGui")
    bill.Name = "ESP_ObjTag"
    bill.Size = UDim2.new(0, 140, 0, 34)
    bill.StudsOffset = Vector3.new(0, 3, 0)
    bill.AlwaysOnTop = true
    bill.LightInfluence = 0
    bill.MaxDistance = 2500
    bill.Adornee = anchor
    bill.Parent = anchor

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextSize = 13
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextColor3 = color
    nameLabel.Text = topText
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Parent = bill

    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(1, 0, 0.45, 0)
    subLabel.Position = UDim2.new(0, 0, 0.55, 0)
    subLabel.BackgroundTransparency = 1
    subLabel.TextSize = 12
    subLabel.Font = Enum.Font.SourceSans
    subLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    subLabel.Text = ""
    subLabel.TextStrokeTransparency = 0
    subLabel.Parent = bill

    return bill, nameLabel, subLabel
end

local function ensureDistLoop()
    if distLoopRunning then return end
    distLoopRunning = true
    task.spawn(function()
        while espMasterEnabled and next(tracked) ~= nil do
            local char = LocalPlayer.Character
            local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
            if root then
                local rootPos = root.Position
                for _, t in pairs(tracked) do
                    if t.wantDist and t.sub and t.anchor and t.anchor.Parent then
                        local dist = math.floor((t.anchor.Position - rootPos).Magnitude)
                        t.sub.Text = string.format("[%dm]", dist)
                    end
                end
            end
            task.wait(0.2)
        end
        distLoopRunning = false
    end)
end

local function hookRemoval(m: Instance, kind: string)
    pushConn(kind, m.Destroying:Connect(function() cleanup(m) end))
    pushConn(kind, m.AncestryChanged:Connect(function(_, parent)
        if not parent then cleanup(m) end
    end))
end

-- Generator ESP
local function anchorGen(model: Model): BasePart?
    local body = model:FindFirstChild("GeneratorBody")
    if body and body:IsA("BasePart") then return body :: BasePart end
    return model:FindFirstChildWhichIsA("BasePart") :: BasePart?
end

local function applyGen(model: Model)
    if tracked[model] then return end
    local anchor = anchorGen(model)
    if not anchor then return end
    
    local hl = mkHighlight(model, COLOR_GEN)
    local bill, _, sub = mkBillboard(anchor, COLOR_GEN, "Generator")
    
    local function upd()
        local p = tonumber(model:GetAttribute("RepairProgress")) or 0
        local regress = model:GetAttribute("Regressing")
        sub.Text = string.format("[%d%%]%s", math.floor(p), regress and " \u{2193}" or "")
        sub.TextColor3 = regress and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(120, 255, 120)
    end
    upd()
    
    local pc1 = model:GetAttributeChangedSignal("RepairProgress"):Connect(upd)
    local pc2 = model:GetAttributeChangedSignal("Regressing"):Connect(upd)
    
    tracked[model] = { hl = hl, bill = bill, anchor = anchor, sub = sub, progConns = { pc1, pc2 }, kind = "Generator" }
end

local function startGenerator()
    local Map = Workspace:FindFirstChild("Map")
    if not Map then return end
    for _, d in ipairs(Map:GetDescendants()) do
        if d:IsA("Model") and string.find(string.lower(d.Name), "generator") then
            applyGen(d)
            hookRemoval(d, "Generator")
        end
    end
    -- ponytail: use DescendantAdded to avoid replication race conditions where folders don't exist yet
    pushConn("Generator", Map.DescendantAdded:Connect(function(desc)
        if isKindActive("Generator") and desc:IsA("Model") and string.find(string.lower(desc.Name), "generator") then
            task.defer(function()
                if isKindActive("Generator") and desc.Parent and not tracked[desc] then
                    applyGen(desc)
                    hookRemoval(desc, "Generator")
                end
            end)
        end
    end))
end

-- Pallet ESP
local function pickPlank(model: Model): BasePart?
    local best: BasePart? = nil
    local bestVol = 0
    for _, d in ipairs(model:GetChildren()) do
        if d:IsA("MeshPart") and d.Transparency < 1 then
            local s = d.Size
            local vol = s.X * s.Y * s.Z
            if vol > bestVol then best = d :: BasePart; bestVol = vol end
        end
    end
    if best then return best end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("MeshPart") and d.Transparency < 1 then
            local s = d.Size
            local vol = s.X * s.Y * s.Z
            if vol > bestVol then best = d :: BasePart; bestVol = vol end
        end
    end
    return best or (model:FindFirstChildWhichIsA("BasePart") :: BasePart?)
end

local function applyPallet(model: Model)
    if tracked[model] then return end
    local anchor = pickPlank(model)
    if not anchor then return end
    local hl = mkHighlight(model, COLOR_PALLET)
    local bill, _, sub = mkBillboard(anchor, COLOR_PALLET, "Pallet")
    tracked[model] = { hl = hl, bill = bill, anchor = anchor, sub = sub, wantDist = true, kind = "Pallet" }
end

local function startPallet()
    local Map = Workspace:FindFirstChild("Map")
    if not Map then return end
    for _, m in ipairs(Map:GetDescendants()) do
        if m:IsA("Model") then
            local nm = string.lower(m.Name)
            if string.find(nm, "pallet") and not string.find(nm, "crate") then
                applyPallet(m)
                hookRemoval(m, "Pallet")
            end
        end
    end
    -- ponytail: use DescendantAdded to avoid replication race conditions where folders don't exist yet
    pushConn("Pallet", Map.DescendantAdded:Connect(function(desc)
        if isKindActive("Pallet") and desc:IsA("Model") then
            local nm = string.lower(desc.Name)
            if string.find(nm, "pallet") and not string.find(nm, "crate") then
                task.defer(function()
                    if isKindActive("Pallet") and desc.Parent and not tracked[desc] then
                        applyPallet(desc)
                        hookRemoval(desc, "Pallet")
                    end
                end)
            end
        end
    end))
    ensureDistLoop()
end

-- SCP / Zombie ESP
local function anchorZombie(model: Model): BasePart?
    local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model:FindFirstChild("Head")
    if hrp and hrp:IsA("BasePart") then return hrp :: BasePart end
    return model:FindFirstChildWhichIsA("BasePart") :: BasePart?
end

local function isZombie(m: Instance): boolean
    return m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") ~= nil and Players:GetPlayerFromCharacter(m :: Model) == nil
end

local function applyZombie(model: Model)
    if tracked[model] then return end
    local anchor = anchorZombie(model)
    if not anchor then return end
    local nameLower = string.lower(model.Name)
    local labelText = string.find(nameLower, "scp") and "Zombie" or model.Name
    local hl = mkHighlight(model, COLOR_ZOMBIE)
    local bill, _, sub = mkBillboard(anchor, COLOR_ZOMBIE, labelText)
    tracked[model] = { hl = hl, bill = bill, anchor = anchor, sub = sub, wantDist = true, kind = "SCP" }
end

local function startZombie()
    local Map = Workspace:FindFirstChild("Map")
    if not Map then return end
    for _, d in ipairs(Map:GetDescendants()) do
        if isZombie(d) then
            applyZombie(d :: Model)
            hookRemoval(d, "SCP")
        end
    end
    pushConn("SCP", Map.DescendantAdded:Connect(function(desc)
        if isKindActive("SCP") and desc:IsA("Model") then
            task.defer(function()
                if isKindActive("SCP") and desc.Parent and not tracked[desc] and isZombie(desc) then
                    applyZombie(desc :: Model)
                    hookRemoval(desc, "SCP")
                end
            end)
        end
    end))
    ensureDistLoop()
end

-- Player ESP
local function anchorPlayer(char: Model): BasePart?
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if hrp and hrp:IsA("BasePart") then return hrp :: BasePart end
    return char:FindFirstChildWhichIsA("BasePart") :: BasePart?
end

local function playerColor(plr: Player): Color3
    local tm = plr.Team
    if tm and (string.find(string.lower(tm.Name), "killer") or string.find(string.lower(tm.Name), "hunter")) then
        return COLOR_KILLER
    end
    if plr:GetAttribute("Role") == "Killer" or plr:GetAttribute("Killer") then
        return COLOR_KILLER
    end
    return COLOR_PLAYER
end

local function recolorPlayer(plr: Player)
    local char = plr.Character
    local t = char and tracked[char]
    if not t then return end
    local col = playerColor(plr)
    if t.hl then
        t.hl.FillColor = col
        t.hl.OutlineColor = col
    end
    if t.nameL then t.nameL.TextColor3 = col end
end

local function applyPlayer(char: Model, plr: Player)
    if tracked[char] then return end
    local anchor = anchorPlayer(char)
    if not anchor then return end
    local col = playerColor(plr)
    local hl = mkHighlight(char, col)
    local bill, nameL, sub = mkBillboard(anchor, col, plr.Name)
    tracked[char] = { hl = hl, bill = bill, anchor = anchor, sub = sub, nameL = nameL, wantDist = true, kind = "Player" }
end

local function startPlayer()
    local function setup(plr: Player)
        if plr == LocalPlayer then return end
        local function onChar(char: Model)
            task.defer(function()
                if isKindActive("Player") and char.Parent and not tracked[char] then
                    applyPlayer(char, plr)
                    pushConn("Player", char.AncestryChanged:Connect(function(_, parent)
                        if not parent then cleanup(char) end
                    end))
                end
            end)
        end
        if plr.Character then onChar(plr.Character) end
        pushConn("Player", plr.CharacterAdded:Connect(onChar))
        pushConn("Player", plr:GetPropertyChangedSignal("Team"):Connect(function() recolorPlayer(plr) end))
    end
    
    for _, plr in ipairs(Players:GetPlayers()) do setup(plr) end
    pushConn("Player", Players.PlayerAdded:Connect(function(plr)
        if isKindActive("Player") then setup(plr) end
    end))
    ensureDistLoop()
end

local starters = {
    Player = startPlayer,
    Generator = startGenerator,
    Pallet = startPallet,
    SCP = startZombie
}

-- ponytail: listen for when the map spawns (e.g. entering game from lobby) and re-initialize ESPs
Workspace.ChildAdded:Connect(function(child)
    if child.Name == "Map" then
        task.defer(function()
            for kind, active in pairs(activeKinds) do
                if active then
                    stopKind(kind)
                    starters[kind]()
                end
            end
        end)
    end
end)

function ESP.UpdateStates()
    for _, kind in ipairs({"Generator", "Pallet", "SCP", "Player"}) do
        local shouldBeActive = espMasterEnabled and (selectedKinds[kind] == true)
        if shouldBeActive ~= activeKinds[kind] then
            activeKinds[kind] = shouldBeActive
            if shouldBeActive then
                starters[kind]()
            else
                stopKind(kind)
            end
        end
    end
end

function ESP.SetMasterEnabled(enabled: boolean)
    espMasterEnabled = enabled
    ESP.UpdateStates()
end

function ESP.SetSelectedKinds(selected: any)
    local newSelected: { [string]: boolean } = {
        Generator = false,
        Pallet = false,
        SCP = false,
        Player = false
    }
    if typeof(selected) == "table" then
        for k, v in pairs(selected) do
            if typeof(k) == "number" and typeof(v) == "string" then
                if v == "SCP / Zombie" or v == "Zombie" then newSelected["SCP"] = true else newSelected[v] = true end
            elseif typeof(k) == "string" and v == true then
                if k == "SCP / Zombie" or k == "Zombie" then newSelected["SCP"] = true else newSelected[k] = true end
            end
        end
    end
    selectedKinds = newSelected
    ESP.UpdateStates()
end

-- =====================================================================
-- AIM CONFIGURATION & LOGIC MODULE EXPORT
-- =====================================================================
local AIM_CONFIG = {
    -- Aim Gun
    aimTargetMode   = "Killer",  -- "Killer" / "Survivor"
    silentAimGun    = true,      -- silent aim peluru (remote Fire)
    aimLock         = true,      -- kamera lock pas nahan pistol
    aimWallcheck    = true,      -- cuma target yg keliatan (LOS)
    aimEnableLead   = true,      -- prediksi gerak target
    aimFovRadius    = 120,
    aimLeadMult     = 1.0,
    aimSmooth       = 0.25,
    aimShowFov      = false,     -- POV circle (visual). set true kalau mau


}

local Logic = {
    Combat = {

        SetAutoSkillcheck = function(enabled: boolean)
            autoSkillcheckEnabled = enabled
        end,
        SetAutoPallet = function(enabled: boolean)
            autoPalletEnabled = enabled
        end,
        SetPalletDistance = function(dist: number)
            TRIGGER_DISTANCE = dist
        end,
        SetAntiAutoParry = function(enabled: boolean)
            antiAutoParryEnabled = enabled
        end,
        SetFastVault = function(enabled: boolean)
            fastVaultEnabled = enabled
        end
    },
    ESP = ESP,
    Aim = {
        -- Aim Gun Setters
        SetTargetMode = function(value: string)
            AIM_CONFIG.aimTargetMode = value
        end,
        SetSilentAim = function(value: boolean)
            AIM_CONFIG.silentAimGun = value
        end,
        SetAimLock = function(value: boolean)
            AIM_CONFIG.aimLock = value
        end,
        SetWallcheck = function(value: boolean)
            AIM_CONFIG.aimWallcheck = value
        end,
        SetEnableLead = function(value: boolean)
            AIM_CONFIG.aimEnableLead = value
        end,
        SetFovRadius = function(value: number)
            AIM_CONFIG.aimFovRadius = value
        end,
        SetShowFov = function(value: boolean)
            AIM_CONFIG.aimShowFov = value
        end,
        SetSmooth = function(value: number)
            AIM_CONFIG.aimSmooth = value
        end,
        SetLeadMult = function(value: number)
            AIM_CONFIG.aimLeadMult = value
        end,


    }
}

-- ============================================================
-- Violence District | AIM (Side Script / Standalone)
-- ============================================================

local Players           = game:GetService("Players")
local Teams             = game:GetService("Teams")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local LocalPlayer       = Players.LocalPlayer

-- ============================================================
-- SHARED: namecall hook infra (buat silent aim)
-- ============================================================
local silentSupported = (getrawmetatable ~= nil) and (getnamecallmethod ~= nil) and (newcclosure ~= nil)
local namecallHandlers = {}
local rawCall = nil

local function onNamecall(fn) table.insert(namecallHandlers, fn) end
local function callOriginal(self, ...) return rawCall(self, ...) end

local function installNamecallHook()
    if not silentSupported then
        warn("[Aim] Silent aim ga didukung executor ini (butuh getrawmetatable/getnamecallmethod/newcclosure).")
        return
    end
    local mt = getrawmetatable(game)
    if setreadonly then pcall(setreadonly, mt, false) end
    if getgenv and getgenv().__tomaAimOrig then
        pcall(function() mt.__namecall = getgenv().__tomaAimOrig end)
    end
    local oldNamecall = mt.__namecall
    if getgenv then getgenv().__tomaAimOrig = oldNamecall end
    rawCall = function(self, ...) return oldNamecall(self, ...) end
    local hookFn = function(self, ...)
        if typeof(self) == "Instance" then
            local method = getnamecallmethod()
            for _, h in ipairs(namecallHandlers) do
                local ok, res = h(self, method, ...)
                if ok then return res end
            end
        end
        return oldNamecall(self, ...)
    end
    mt.__namecall = newcclosure and newcclosure(hookFn) or hookFn
end

-- ============================================================
-- MODULE 1: Twist of Fate (Aim Lock + Silent Aim gun)
-- ============================================================
local function initTwistOfFate()
    local fovFollowMouse = false
    local AIM_TARGET_PART = "HumanoidRootPart"
    local AIM_BULLET_SPEED = 200
    local AIM_MUZZLE_OFFSET = Vector3.new(-1.41, -1.10, -5.44)
    local AimCamera = Workspace.CurrentCamera
    local aimSilentDir, aimTargetVel = nil, nil
    local GUN_ANIM_ID = "75029269564639"

    local function localAnimPlaying(animIdStr)
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local animator = hum and hum:FindFirstChildOfClass("Animator")
        if not animator then return false end
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            if track.Animation and string.find(track.Animation.AnimationId, animIdStr, 1, true) then return true end
        end
        return false
    end
    local aimVelSampleName, aimVelSamplePos, aimVelSampleT = nil, nil, 0

    local function aimGetTeam() if AIM_CONFIG.aimTargetMode == "Survivor" then return Teams:FindFirstChild("Survivors") end return Teams:FindFirstChild("Killer") end
    local function aimGetFovCenter() if fovFollowMouse then local m = UserInputService:GetMouseLocation() return Vector2.new(m.X, m.Y) end local vp = AimCamera.ViewportSize return Vector2.new(vp.X/2, vp.Y/2) end
    local function aimGetPart(plr) return plr and plr.Character and plr.Character:FindFirstChild(AIM_TARGET_PART) end

    -- ponytail: RaycastParams pre-allocated to avoid garbage collection overhead in RenderStepped/HasLOS
    local aimRaycastParams = RaycastParams.new()
    aimRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
    aimRaycastParams.IgnoreWater = true

    local function aimHasLOS(part)
        if not part or not part.Parent then return false end
        local origin = AimCamera.CFrame.Position
        local ignore = {}
        for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then table.insert(ignore, plr.Character) end end
        aimRaycastParams.FilterDescendantsInstances = ignore
        local char = part.Parent
        local points = { part.Position }
        local head = char and char:FindFirstChild("Head")
        if head then table.insert(points, head.Position) end
        table.insert(points, part.Position + Vector3.new(0, 2.5, 0))
        table.insert(points, part.Position - Vector3.new(0, 2.5, 0))
        for _, p in ipairs(points) do if Workspace:Raycast(origin, p - origin, aimRaycastParams) == nil then return true end end
        return false
    end

    local function aimGetTarget()
        local team = aimGetTeam() if not team then return nil end
        local center = aimGetFovCenter()
        local best, bestDist = nil, AIM_CONFIG.aimFovRadius
        for _, plr in ipairs(team:GetPlayers()) do
            if plr ~= LocalPlayer then
                local part = aimGetPart(plr)
                if part then
                    local sp, onScreen = AimCamera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if d <= bestDist then if (not AIM_CONFIG.aimWallcheck) or aimHasLOS(part) then best, bestDist = plr, d end end
                    end
                end
            end
        end
        return best
    end

    local function aimComputeDir(part, targetVel)
        local muzzle = AimCamera.CFrame:PointToWorldSpace(AIM_MUZZLE_OFFSET)
        local tp = part.Position local aimPoint = tp
        if AIM_CONFIG.aimEnableLead and targetVel then
            local tvel = targetVel * AIM_CONFIG.aimLeadMult
            local tof = (tp - muzzle).Magnitude / AIM_BULLET_SPEED
            for _ = 1, 2 do local predicted = tp + tvel * tof tof = (predicted - muzzle).Magnitude / AIM_BULLET_SPEED end
            aimPoint = tp + tvel * tof
        end
        local dir = (aimPoint - muzzle) if dir.Magnitude < 0.01 then return nil end return dir.Unit
    end

    local aimFovCircle = nil
    if Drawing then
        aimFovCircle = Drawing.new("Circle")
        aimFovCircle.Thickness = 2 aimFovCircle.NumSides = 64 aimFovCircle.Radius = AIM_CONFIG.aimFovRadius
        aimFovCircle.Filled = false aimFovCircle.Visible = false aimFovCircle.Color = Color3.fromRGB(255, 255, 255)
    end

    local aimRenderConn = RunService.RenderStepped:Connect(function()
        AimCamera = Workspace.CurrentCamera
        if not (AIM_CONFIG.silentAimGun or AIM_CONFIG.aimLock) then aimSilentDir = nil if aimFovCircle then aimFovCircle.Visible = false end return end
        if aimFovCircle then aimFovCircle.Visible = AIM_CONFIG.aimShowFov aimFovCircle.Radius = AIM_CONFIG.aimFovRadius aimFovCircle.Position = aimGetFovCenter() end
        local target = aimGetTarget()
        if target then
            local part = aimGetPart(target)
            if part then
                local pos = part.Position local now = tick()
                if aimVelSampleName == target.Name and aimVelSamplePos then
                    local dt = now - aimVelSampleT
                    if dt >= 0.04 then
                        local instVel = (pos - aimVelSamplePos) / dt
                        aimTargetVel = aimTargetVel and aimTargetVel:Lerp(instVel, 0.5) or instVel
                        aimVelSamplePos = pos aimVelSampleT = now
                    end
                else aimVelSampleName = target.Name aimVelSamplePos = pos aimVelSampleT = now aimTargetVel = Vector3.zero end
                local dir = aimComputeDir(part, aimTargetVel)
                aimSilentDir = (AIM_CONFIG.silentAimGun and dir) or nil
                if aimFovCircle then aimFovCircle.Color = Color3.fromRGB(255, 0, 0) end
                if AIM_CONFIG.aimLock and dir and localAnimPlaying(GUN_ANIM_ID) then
                    local cf = AimCamera.CFrame local goal = CFrame.new(cf.Position, cf.Position + dir)
                    AimCamera.CFrame = cf:Lerp(goal, AIM_CONFIG.aimSmooth)
                end
            else aimSilentDir = nil aimVelSampleName = nil if aimFovCircle then aimFovCircle.Color = Color3.fromRGB(255, 255, 255) end end
        else aimSilentDir = nil aimVelSampleName = nil if aimFovCircle then aimFovCircle.Color = Color3.fromRGB(255, 255, 255) end end
    end)

    onNamecall(function(self, method, ...)
        if method == "FireServer" and AIM_CONFIG.silentAimGun and aimSilentDir and self.Name == "Fire" then
            local p = self.Parent
            if p and p.Parent and p.Parent.Name == "Items" then
                local args = { ... }
                if typeof(args[2]) == "Vector3" then args[2] = aimSilentDir return true, callOriginal(self, unpack(args)) end
                for i, v in ipairs(args) do if typeof(v) == "Vector3" then args[i] = aimSilentDir return true, callOriginal(self, unpack(args)) end end
            end
        end
        return false
    end)

    if getgenv then
        local g = getgenv()
        if g.__tomaAimRender then pcall(function() g.__tomaAimRender:Disconnect() end) end
        g.__tomaAimRender = aimRenderConn
        if g.__tomaFov then pcall(function() g.__tomaFov:Remove() end) end
        g.__tomaFov = aimFovCircle
    end
end



-- ==================== INIT ========================
initTwistOfFate()
installNamecallHook()

print("[Aim Hub] Pistol script loaded. Silent aim supported: " .. tostring(silentSupported))

getgenv().AutomaHubLogic = Logic
return Logic
