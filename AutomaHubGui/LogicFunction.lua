--!strict

-- Services
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Teams             = game:GetService("Teams")
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
-- COMBAT MODULE (Auto Parry, Dash Parry, Auto Dodge Abyss)
-- =====================================================================

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid  = Character:WaitForChild("Humanoid")
local RootPart  = Character:WaitForChild("HumanoidRootPart")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local parryResult = Remotes:WaitForChild("Items"):WaitForChild("Parrying Dagger"):WaitForChild("parryResult")
local DamagevizEvent = Remotes:WaitForChild("Killers"):WaitForChild("Damageviz")
local SlowAttack = Remotes:WaitForChild("Killers"):FindFirstChild("SlowAttack")
local KillerTeam = Teams:FindFirstChild("Killer")

local killerDistance = 999
local killerRoot: BasePart? = nil
local killerFilterCache: { Instance } = { Character }

LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid") :: Humanoid
    RootPart = newChar:WaitForChild("HumanoidRootPart") :: BasePart
end)

-- State Toggles & Distances
local autoParryEnabled = false
local parryDistance = 9
local dashDistance = 30

local autoDodgeEnabled = false
local dodgeDistance = 25

-- Optimized Heartbeat for Killer Tracking (Only runs when Combat features are active)
RunService.Heartbeat:Connect(function()
    if not autoParryEnabled and not autoDodgeEnabled then return end
    if not RootPart or not RootPart.Parent then return end
    
    local nearest = 9999
    local nearestRoot: BasePart? = nil
    
    table.clear(killerFilterCache)
    table.insert(killerFilterCache, Character)
    
    if KillerTeam then
        for _, plr in ipairs(KillerTeam:GetPlayers()) do
            local kChar = plr.Character
            if kChar then
                table.insert(killerFilterCache, kChar)
                local kRoot = kChar:FindFirstChild("HumanoidRootPart") :: BasePart?
                if kRoot then
                    local d = (RootPart.Position - kRoot.Position).Magnitude
                    if d < nearest then
                        nearest = d
                        nearestRoot = kRoot
                    end
                end
            end
        end
    end
    
    killerDistance = nearest
    killerRoot = nearestRoot
end)

-- Optimized RaycastParams instance (reused to prevent GC overhead)
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function hasLineOfSight(): boolean
    if not RootPart or not RootPart.Parent or not killerRoot or not killerRoot.Parent then return false end
    raycastParams.FilterDescendantsInstances = killerFilterCache
    local rayResult = Workspace:Raycast(RootPart.Position, killerRoot.Position - RootPart.Position, raycastParams)
    return rayResult == nil
end

-- Animation Event Hooks
local animHandlers: { (plr: Player, idRaw: any, animId: string) -> () } = {}
local killerAnimConnections: { RBXScriptConnection } = {}

local function onKillerAnim(fn: (plr: Player, idRaw: any, animId: string) -> ())
    table.insert(animHandlers, fn)
end

local function fireAnim(plr: Player, idRaw: any, animId: string)
    for _, h in ipairs(animHandlers) do
        pcall(h, plr, idRaw, animId)
    end
end

local function hookKillerAnimators()
    for _, c in ipairs(killerAnimConnections) do pcall(function() c:Disconnect() end) end
    table.clear(killerAnimConnections)
    if not KillerTeam then return end
    
    for _, plr in ipairs(KillerTeam:GetPlayers()) do
        local function hook(char: Model)
            local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
            if hum then
                local animator = hum:WaitForChild("Animator", 5) :: Animator?
                if animator then
                    table.insert(killerAnimConnections, animator.AnimationPlayed:Connect(function(animTrack)
                        local id = animTrack.Animation and animTrack.Animation.AnimationId
                        local animId = id and tostring(id):match("%d+") or ""
                        fireAnim(plr, id, animId)
                    end))
                end
            end
        end
        if plr.Character then task.spawn(hook, plr.Character) end
        table.insert(killerAnimConnections, plr.CharacterAdded:Connect(hook))
    end
end

-- Auto Parry Mechanics
local isOnCooldown, isResolving, isSilenced, isAutoParrying = false, false, false, false
local ATTACK_ANIM_IDS: { [string]: boolean } = {
    ["117042998468241"] = true, ["129784271201071"] = true, ["113255068724446"] = true,
    ["118907603246885"] = true, ["122812055447896"] = true, ["110355011987939"] = true,
    ["135002183282873"] = true, ["105374834496520"] = true, ["138720291317243"] = true,
    ["115244153053858"] = true, ["106871536134254"] = true,
}
local lastPrePress, rearmCooldown, postParryCooldown, lastAutoPress = 0, 0.08, 0.25, 0
local facingDotThreshold = 0.1

local function canParry(): boolean
    if isOnCooldown or isSilenced or LocalPlayer:GetAttribute("IsDead") then return false end
    if not Character or not Character.Parent or Character:GetAttribute("IsCarried") or Character:GetAttribute("IsHooked") then return false end
    if CollectionService:HasTag(RootPart, "doing action") then return false end
    return true
end

local function cleanupStaleActionTag()
    if not RootPart or not RootPart.Parent then return end
    if CollectionService:HasTag(RootPart, "doing action") then
        local checkInt = Character and Character:FindFirstChild("CheckInterractable")
        if not checkInt or not checkInt:GetAttribute("isRepairing") then
            CollectionService:RemoveTag(RootPart, "doing action")
            if RootPart.Anchored then RootPart.Anchored = false end
            isResolving, isOnCooldown = false, false
        end
    end
end

local function isKillerFacing(): boolean
    if not killerRoot or not killerRoot.Parent or not RootPart or not RootPart.Parent then return true end
    local dot = killerRoot.CFrame.LookVector:Dot((RootPart.Position - killerRoot.Position).Unit)
    return dot >= facingDotThreshold
end

local parryController: any = nil
local function resolveParryController(): any
    if parryController then return parryController end
    -- Match instance by its exact class metatable (ParryClient), same as the
    -- working standalone script. The old loose duck-typing scan grabbed the
    -- first table with .Parry/.CanUse (usually the class module/prototype),
    -- so :Parry() ran without instance state and silently did nothing.
    local ok, ParryClient = pcall(function()
        return require(ReplicatedStorage.Modules.Items.ParryClient)
    end)
    if not ok or not ParryClient then return nil end
    if type(getgc) ~= "function" then return nil end

    for _, v in ipairs(getgc(true)) do
        if type(v) == "table" and getmetatable(v) == ParryClient then
            parryController = v
            break
        end
    end

    return parryController
end

local function doParryPress()
    isAutoParrying = true
    lastAutoPress = os.clock()
    lastPrePress = os.clock()
    local ctrl = resolveParryController()
    if ctrl then
        local ok, err = pcall(function()
            if ctrl:CanUse() then ctrl:Parry() end
        end)
        if not ok then parryController = nil end
    else
        warn("[AutomaHub Debug] Controller is nil!")
    end
    task.delay(0.05, function() isAutoParrying = false end)
end

local function attemptParry(maxRange: number)
    if not autoParryEnabled then warn("[AutomaHub Debug] AutoParry disabled"); return end
    if killerDistance > maxRange then warn("[AutomaHub Debug] Out of range:", killerDistance, ">", maxRange); return end
    if not canParry() then warn("[AutomaHub Debug] canParry() is false. CD:", isOnCooldown, "Silenced:", isSilenced); return end
    if (os.clock() - lastPrePress) < rearmCooldown then warn("[AutomaHub Debug] Rearm cooldown active"); return end
    if not hasLineOfSight() then warn("[AutomaHub Debug] No line of sight"); return end
    if not isKillerFacing() then warn("[AutomaHub Debug] Killer not facing"); return end
    
    warn("[AutomaHub Debug] attemptParry PASSED ALL CHECKS, calling doParryPress()")
    doParryPress()
end

local function triggerParry()
    attemptParry(parryDistance)
end

DamagevizEvent.OnClientEvent:Connect(triggerParry)
if SlowAttack then SlowAttack.OnClientEvent:Connect(triggerParry) end

onKillerAnim(function(plr, idRaw, animId)
    if ATTACK_ANIM_IDS[animId] then triggerParry() end
end)

parryResult.OnClientEvent:Connect(function(success, cd)
    isResolving = false
    if success then
        isOnCooldown = true
        task.delay(postParryCooldown, function() isOnCooldown = false end)
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and input.UserInputType == Enum.UserInputType.MouseButton2 then
        if isAutoParrying or (os.clock() - lastAutoPress) < 0.2 then return end
        if canParry() then isResolving = true end
    end
end)

CollectionService:GetInstanceAddedSignal("Silenced"):Connect(function(i) if i == Character then isSilenced = true end end)
CollectionService:GetInstanceRemovedSignal("Silenced"):Connect(function(i) if i == Character then isSilenced = false end end)
LocalPlayer.CharacterAdded:Connect(function() isOnCooldown, isResolving, isSilenced, parryController = false, false, false, nil end)

if KillerTeam then
    hookKillerAnimators()
    KillerTeam.PlayerAdded:Connect(hookKillerAnimators)
    KillerTeam.PlayerRemoved:Connect(hookKillerAnimators)
end

RunService.Heartbeat:Connect(function()
    if autoParryEnabled and RootPart and CollectionService:HasTag(RootPart, "doing action") then
        cleanupStaleActionTag()
    end
end)

-- Dash Parry (Hidden)
local DASH_WINDUP_ID = "98163597193511"
local dashParryDelay = 0.775
local dashFacingDotMin = math.cos(math.rad(10))
local dashRetriggerGuard = 1.4
local dashPending = false
local lastDashSchedule = -999

local function dashFacingInfo(kr: BasePart?): (number, boolean)
    if not kr or not kr.Parent or not RootPart or not RootPart.Parent then return 999, false end
    local toPlayer = RootPart.Position - kr.Position
    local dist = toPlayer.Magnitude
    if dist < 0.01 then return dist, true end
    local dot = math.clamp(kr.CFrame.LookVector:Dot(toPlayer.Unit), -1, 1)
    return dist, (dot >= dashFacingDotMin)
end

local function fireDashParry(getKr: () -> BasePart?)
    dashPending = false
    if not autoParryEnabled then return end
    local kr = getKr()
    local dist, facingOk = dashFacingInfo(kr)
    if dist > dashDistance or not facingOk then return end
    if not canParry() or not hasLineOfSight() then return end
    doParryPress()
end

local function scheduleDashParry(plr: Player, kr: BasePart?)
    if not autoParryEnabled or dashPending or (os.clock() - lastDashSchedule) < dashRetriggerGuard then return end
    local dist, facingOk = dashFacingInfo(kr)
    if dist > dashDistance or not facingOk then return end
    dashPending = true
    lastDashSchedule = os.clock()
    task.delay(dashParryDelay, function()
        fireDashParry(function()
            return plr.Character and (plr.Character:FindFirstChild("HumanoidRootPart") :: BasePart?)
        end)
    end)
end

onKillerAnim(function(plr, idRaw, animId)
    if idRaw and tostring(idRaw):find(DASH_WINDUP_ID) then
        scheduleDashParry(plr, plr.Character and (plr.Character:FindFirstChild("HumanoidRootPart") :: BasePart?))
    end
end)

-- Auto Dodge Abysswalker
local crouchHoldTime = 1.0
local dodgeTriggerDelay = 0.1
local dodgeSkillWindow = 2.0
local dodgeCheckInterval = 0.1
local ABYSS_SKILL_ID = "80411309607666"
local isDodging = false
local dodgeSkillPending = false

local crouchController: any = nil
local function resolveCrouchController(): any
    if crouchController then return crouchController end
    local ok, SAC = pcall(function()
        return require(ReplicatedStorage.Modules.Survivors.SurvivorAnimationsController)
    end)
    if not ok or not SAC then return nil end
    if type(getgc) ~= "function" then return nil end
    for _, v in ipairs(getgc(true)) do
        if type(v) == "table" and getmetatable(v) == SAC then
            crouchController = v
            break
        end
    end
    return crouchController
end

local function setCrouch(state: boolean): boolean
    local ctrl = resolveCrouchController()
    if not ctrl then return false end
    local ok = pcall(function() ctrl:_setCrouching(state) end)
    if not ok then crouchController = nil end
    return ok
end

local function doCrouch()
    if isDodging then return end
    isDodging = true
    setCrouch(true)
    task.delay(crouchHoldTime, function()
        setCrouch(false)
        isDodging = false
    end)
end

LocalPlayer.CharacterAdded:Connect(function() crouchController = nil; isDodging = false end)

local function triggerDodge()
    if not autoDodgeEnabled or isDodging then return end
    if killerDistance <= dodgeDistance and hasLineOfSight() then
        task.delay(dodgeTriggerDelay, function()
            if not isDodging and not dodgeSkillPending and killerDistance <= dodgeDistance and hasLineOfSight() then
                doCrouch()
            end
        end)
        return
    end
    if dodgeSkillPending then return end
    dodgeSkillPending = true
    task.spawn(function()
        local elapsed = 0
        while elapsed < dodgeSkillWindow do
            task.wait(dodgeCheckInterval)
            elapsed = elapsed + dodgeCheckInterval
            if not autoDodgeEnabled or isDodging then break end
            if killerDistance <= dodgeDistance and hasLineOfSight() then
                task.delay(dodgeTriggerDelay, function()
                    if not isDodging and not dodgeSkillPending and killerDistance <= dodgeDistance and hasLineOfSight() then
                        doCrouch()
                    end
                end)
                break
            end
        end
        dodgeSkillPending = false
    end)
end

onKillerAnim(function(plr, idRaw, animId)
    if idRaw and tostring(idRaw):find(ABYSS_SKILL_ID) then triggerDodge() end
end)

if KillerTeam then
    hookKillerAnimators()
    KillerTeam.PlayerAdded:Connect(hookKillerAnimators)
    KillerTeam.PlayerRemoved:Connect(hookKillerAnimators)
end


-- =====================================================================
-- AUTO SKILLCHECK MODULE
-- =====================================================================
local autoSkillcheckEnabled = false
local scTriggered = false
local SkillCheckResultEvent, SkillCheckEvent = nil, nil
local generatorModel, generatorPoint = nil, nil

local CONFIG_SC = {
    zoneMin      = 102,
    zoneMax      = 116,
    zoneCenter   = 108,
    cleanupDelay = 0.15,
}

local function resolveGeneratorRemotes()
    local ok, genFolder = pcall(function()
        return ReplicatedStorage:WaitForChild("Remotes", 5):WaitForChild("Generator", 5)
    end)
    if ok and genFolder then
        SkillCheckResultEvent = genFolder:FindFirstChild("SkillCheckResultEvent")
        SkillCheckEvent       = genFolder:FindFirstChild("SkillCheckEvent")
        if SkillCheckEvent then
            SkillCheckEvent.OnClientEvent:Connect(function(gm, gp)
                generatorModel, generatorPoint = gm, gp
            end)
        end
    end
end

local function doSkillcheckSuccess(line, goal)
    scTriggered = true
    
    local frozenRot = CONFIG_SC.zoneCenter + goal.Rotation
    pcall(function()
        local TweenService = game:GetService("TweenService")
        TweenService:Create(line, TweenInfo.new(0), { Rotation = frozenRot }):Play()
        line.Rotation = frozenRot
    end)

    local char = LocalPlayer.Character
    local scr = char and char:FindFirstChild("Skillcheck-gen")
    if scr then
        pcall(function() scr.Disabled = true end)
        local great = scr:FindFirstChild("Great")
        if great then pcall(function() great:Play() end) end
    end

    if SkillCheckResultEvent and generatorModel and generatorPoint then
        pcall(function()
            SkillCheckResultEvent:FireServer("success", 1, generatorModel, generatorPoint)
        end)
    end

    task.delay(CONFIG_SC.cleanupDelay, function()
        pcall(function()
            local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
            local gui = PlayerGui and PlayerGui:FindFirstChild("SkillCheckPromptGui")
            if gui then
                local check = gui:FindFirstChild("Check")
                if check then check.Visible = false end
            end
            line.Rotation = 0
            goal.Rotation = 0
        end)
        if scr then pcall(function() scr.Disabled = false end) end
    end)
end

RunService.Heartbeat:Connect(function()
    if not autoSkillcheckEnabled then return end

    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local gui = PlayerGui and PlayerGui:FindFirstChild("SkillCheckPromptGui")
    if not gui then 
        scTriggered = false
        return 
    end

    local check = gui:FindFirstChild("Check")
    if not check or not check.Visible then
        scTriggered = false
        return
    end

    if scTriggered then return end

    local line = check:FindFirstChild("Line")
    local goal = check:FindFirstChild("Goal")
    if not line or not goal then return end

    local rotation = line.Rotation
    local goalRotation = goal.Rotation
    local minZone = CONFIG_SC.zoneMin + goalRotation
    local maxZone = CONFIG_SC.zoneMax + goalRotation

    if rotation >= minZone and rotation <= maxZone then
        doSkillcheckSuccess(line, goal)
    end
end)

task.spawn(resolveGeneratorRemotes)

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
    local gf = Map:FindFirstChild("Generators") or Map
    pushConn("Generator", gf.ChildAdded:Connect(function(child)
        if isKindActive("Generator") and child:IsA("Model") and string.find(string.lower(child.Name), "generator") then
            task.defer(function()
                if isKindActive("Generator") and child.Parent and not tracked[child] then
                    applyGen(child)
                    hookRemoval(child, "Generator")
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
    local pf = Map:FindFirstChild("Pallets") or Map
    pushConn("Pallet", pf.ChildAdded:Connect(function(child)
        if isKindActive("Pallet") and child:IsA("Model") then
            local nm = string.lower(child.Name)
            if string.find(nm, "pallet") and not string.find(nm, "crate") then
                task.defer(function()
                    if isKindActive("Pallet") and child.Parent and not tracked[child] then
                        applyPallet(child)
                        hookRemoval(child, "Pallet")
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
-- AIM MODULE: Shared Infrastructure
-- =====================================================================

-- ponytail: namecall hook infra for silent aim (shared by GunAim + VeilAim)
local silentSupported = (getrawmetatable ~= nil) and (getnamecallmethod ~= nil) and (newcclosure ~= nil)
local namecallHandlers: { (self: any, method: string, ...any) -> (boolean, any?) } = {}
local rawCall: ((self: any, ...any) -> ...any)? = nil

local function onNamecall(fn: (self: any, method: string, ...any) -> (boolean, any?))
    table.insert(namecallHandlers, fn)
end

local function callOriginal(self: any, ...: any): ...any
    if rawCall then return rawCall(self, ...) end
    return nil :: any
end

local function installNamecallHook()
    if not silentSupported then return end
    local mt = getrawmetatable(game)
    if setreadonly then pcall(setreadonly, mt, false) end
    if getgenv and getgenv().__tomaAimOrig then
        pcall(function() mt.__namecall = getgenv().__tomaAimOrig end)
    end
    local oldNamecall = mt.__namecall
    if getgenv then getgenv().__tomaAimOrig = oldNamecall end
    rawCall = function(self: any, ...: any) return oldNamecall(self, ...) end
    local hookFn = function(self: any, ...: any)
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

-- =====================================================================
-- AIM MODULE 1: GunAim (Twist of Fate)
-- =====================================================================
local gunAimLockEnabled = false
local gunSilentAimEnabled = false
local gunShowPov = false
local gunAimOffset = 0.0
local gunPovSize = 120

-- ponytail: reuse top-level services (Players, Teams, Workspace, RunService, UserInputService already declared)
local GUN_TARGET_PART = "HumanoidRootPart"
local GUN_BULLET_SPEED = 200
local GUN_MUZZLE_OFFSET = Vector3.new(-1.41, -1.10, -5.44)
local GUN_ANIM_ID = "75029269564639"
local GUN_SMOOTH = 0.25
local GUN_LEAD_MULT = 1.0

local gunSilentDir: Vector3? = nil
local gunTargetVel: Vector3? = nil
local gunVelSampleName: string? = nil
local gunVelSamplePos: Vector3? = nil
local gunVelSampleT = 0

local function gunLocalAnimPlaying(animIdStr: string): boolean
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and (hum :: Humanoid):FindFirstChildOfClass("Animator")
    if not animator then return false end
    for _, track in ipairs((animator :: Animator):GetPlayingAnimationTracks()) do
        if track.Animation and string.find(track.Animation.AnimationId, animIdStr, 1, true) then return true end
    end
    return false
end

local function gunGetFovCenter(): Vector2
    local vp = Workspace.CurrentCamera.ViewportSize
    return Vector2.new(vp.X / 2, vp.Y / 2)
end

-- ponytail: reuse raycastParams from combat module where possible, but aim needs separate filter
local gunRayParams = RaycastParams.new()
gunRayParams.FilterType = Enum.RaycastFilterType.Exclude
gunRayParams.IgnoreWater = true

local function gunHasLOS(part: BasePart): boolean
    if not part or not part.Parent then return false end
    local origin = Workspace.CurrentCamera.CFrame.Position
    local ignore: { Instance } = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then table.insert(ignore, plr.Character) end
    end
    gunRayParams.FilterDescendantsInstances = ignore
    local points = { part.Position, part.Position + Vector3.new(0, 2.5, 0), part.Position - Vector3.new(0, 2.5, 0) }
    local head = part.Parent and (part.Parent :: Instance):FindFirstChild("Head")
    if head then table.insert(points, (head :: BasePart).Position) end
    for _, p in ipairs(points) do
        if Workspace:Raycast(origin, p - origin, gunRayParams) == nil then return true end
    end
    return false
end

local function gunGetTarget(): Player?
    local KillerTeam = Teams:FindFirstChild("Killer")
    if not KillerTeam then return nil end
    local cam = Workspace.CurrentCamera
    local center = gunGetFovCenter()
    local best: Player? = nil
    local bestDist = gunPovSize
    for _, plr in ipairs(KillerTeam:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local part = char and char:FindFirstChild(GUN_TARGET_PART) :: BasePart?
            if part then
                local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d <= bestDist and gunHasLOS(part) then
                        best = plr
                        bestDist = d
                    end
                end
            end
        end
    end
    return best
end

local function gunComputeDir(part: BasePart, targetVel: Vector3?): Vector3?
    local cam = Workspace.CurrentCamera
    local muzzle = cam.CFrame:PointToWorldSpace(GUN_MUZZLE_OFFSET)
    local tp = part.Position + Vector3.new(0, gunAimOffset, 0)
    local aimPoint = tp
    if targetVel then
        local tvel = targetVel * GUN_LEAD_MULT
        local tof = (tp - muzzle).Magnitude / GUN_BULLET_SPEED
        for _ = 1, 2 do
            local predicted = tp + tvel * tof
            tof = (predicted - muzzle).Magnitude / GUN_BULLET_SPEED
        end
        aimPoint = tp + tvel * tof
    end
    local dir = aimPoint - muzzle
    if dir.Magnitude < 0.01 then return nil end
    return dir.Unit
end

-- ponytail: Drawing FOV circle (nil-safe if executor lacks Drawing)
local gunFovCircle: any = nil
if Drawing then
    gunFovCircle = Drawing.new("Circle")
    gunFovCircle.Thickness = 2
    gunFovCircle.NumSides = 64
    gunFovCircle.Radius = gunPovSize
    gunFovCircle.Filled = false
    gunFovCircle.Visible = false
    gunFovCircle.Color = Color3.fromRGB(255, 255, 255)
end

RunService.RenderStepped:Connect(function()
    -- ponytail: zero-cost when disabled
    if not gunAimLockEnabled and not gunSilentAimEnabled then
        gunSilentDir = nil
        if gunFovCircle then gunFovCircle.Visible = false end
        return
    end

    if gunFovCircle then
        gunFovCircle.Visible = gunShowPov
        gunFovCircle.Radius = gunPovSize
        gunFovCircle.Position = gunGetFovCenter()
    end

    local target = gunGetTarget()
    if target then
        local char = target.Character
        local part = char and char:FindFirstChild(GUN_TARGET_PART) :: BasePart?
        if part then
            local pos = part.Position
            local now = tick()
            if gunVelSampleName == target.Name and gunVelSamplePos then
                local dt = now - gunVelSampleT
                if dt >= 0.04 then
                    local instVel = (pos - gunVelSamplePos) / dt
                    gunTargetVel = if gunTargetVel then gunTargetVel:Lerp(instVel, 0.5) else instVel
                    gunVelSamplePos = pos
                    gunVelSampleT = now
                end
            else
                gunVelSampleName = target.Name
                gunVelSamplePos = pos
                gunVelSampleT = now
                gunTargetVel = Vector3.zero
            end

            local dir = gunComputeDir(part, gunTargetVel)
            gunSilentDir = if gunSilentAimEnabled and dir then dir else nil
            if gunFovCircle then gunFovCircle.Color = Color3.fromRGB(255, 0, 0) end

            if gunAimLockEnabled and dir and gunLocalAnimPlaying(GUN_ANIM_ID) then
                local cam = Workspace.CurrentCamera
                local cf = cam.CFrame
                local goal = CFrame.new(cf.Position, cf.Position + dir)
                cam.CFrame = cf:Lerp(goal, GUN_SMOOTH)
            end
        else
            gunSilentDir = nil
            gunVelSampleName = nil
            if gunFovCircle then gunFovCircle.Color = Color3.fromRGB(255, 255, 255) end
        end
    else
        gunSilentDir = nil
        gunVelSampleName = nil
        if gunFovCircle then gunFovCircle.Color = Color3.fromRGB(255, 255, 255) end
    end
end)

-- ponytail: silent aim hook for gun Fire remote
onNamecall(function(self, method, ...)
    if method ~= "FireServer" or not gunSilentAimEnabled or not gunSilentDir then return false end
    if self.Name ~= "Fire" then return false end
    local p = self.Parent
    if not (p and p.Parent and p.Parent.Name == "Items") then return false end
    local args = { ... }
    for i, v in ipairs(args) do
        if typeof(v) == "Vector3" then
            args[i] = gunSilentDir
            return true, callOriginal(self, unpack(args))
        end
    end
    return false
end)

-- cleanup old connections on re-run
if getgenv then
    local g = getgenv()
    if g.__tomaFov then pcall(function() g.__tomaFov:Remove() end) end
    g.__tomaFov = gunFovCircle
end

-- =====================================================================
-- AIM MODULE 2: VeilAim (Spear Ballistic)
-- =====================================================================
local veilAimLockEnabled = false
local veilSilentAimEnabled = false
local veilShowPov = false
local veilAimOffset = 0.0
local veilPovSize = 150

local VEIL_TARGET_PART = "HumanoidRootPart"
local VEIL_GRAVITY = 98.1
local VEIL_SMOOTH = 0.35
local VEIL_LOCK_SPEED = 165

-- ponytail: mutable distance offset table for veil lead prediction
local veilDistOffsets: { { dist: number, offset: number } } = {
    { dist = 40, offset = 1.9 },
    { dist = 60, offset = 1.4 },
    { dist = 80, offset = 1.0 },
}

local function veilOffsetForDist(dist: number): number
    local best, bestDiff = 1.0, math.huge
    for _, e in ipairs(veilDistOffsets) do
        local diff = math.abs(dist - e.dist)
        if diff < bestDiff then bestDiff = diff; best = e.offset end
    end
    return best
end

local veilTargetPos: Vector3? = nil
local veilTargetVel: Vector3? = nil
local veilSampleName: string? = nil
local veilSamplePos: Vector3? = nil
local veilSampleT = 0
local veilLockedPlayer: Player? = nil
local veilLockGraceUntil = 0

local function veilGetFovCenter(): Vector2
    local vp = Workspace.CurrentCamera.ViewportSize
    return Vector2.new(vp.X / 2, vp.Y / 2)
end

local function veilInRange(origin: Vector3, targetPos: Vector3, speed: number, g: number): boolean
    local disp = targetPos - origin
    local flatX, flatZ = disp.X, disp.Z
    local dx = math.sqrt(flatX * flatX + flatZ * flatZ)
    if dx < 0.001 then return true end
    local v2 = speed * speed
    local root = v2 * v2 - g * (g * dx * dx + 2 * disp.Y * v2)
    return root >= 0
end

local function veilGetTarget(): Player?
    local team = Teams:FindFirstChild("Survivors")
    if not team then return nil end
    local cam = Workspace.CurrentCamera
    local origin = cam.CFrame.Position
    local center = veilGetFovCenter()
    local best: Player? = nil
    local bestDist = veilPovSize
    for _, plr in ipairs(team:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local part = char and char:FindFirstChild(VEIL_TARGET_PART) :: BasePart?
            if part then
                local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d <= bestDist and veilInRange(origin, part.Position, VEIL_LOCK_SPEED, VEIL_GRAVITY) then
                        best = plr
                        bestDist = d
                    end
                end
            end
        end
    end
    return best
end

local function veilSolveBallistic(origin: Vector3, target: Vector3, speed: number, g: number): (Vector3?, number)
    local disp = target - origin
    local dy = disp.Y
    local flatX, flatZ = disp.X, disp.Z
    local dx = math.sqrt(flatX * flatX + flatZ * flatZ)
    if dx < 0.001 then return if disp.Magnitude > 0 then disp.Unit else nil, 0 end
    local v2 = speed * speed
    local root = v2 * v2 - g * (g * dx * dx + 2 * dy * v2)
    local tanTheta: number
    if root < 0 then
        tanTheta = 1
    else
        tanTheta = (v2 - math.sqrt(root)) / (g * dx)
    end
    local horiz = Vector3.new(flatX / dx, 0, flatZ / dx)
    local dir = (horiz + Vector3.new(0, tanTheta, 0))
    if dir.Magnitude < 0.001 then return nil, 0 end
    dir = dir.Unit
    local cosTheta = math.sqrt(dir.X * dir.X + dir.Z * dir.Z)
    local tof = if speed * cosTheta > 0.001 then dx / (speed * cosTheta) else 0
    return dir, tof
end

local function veilSolveLead(origin: Vector3, targetPos: Vector3, targetVel: Vector3?, speed: number, g: number): (Vector3?, number)
    local pred = targetPos + Vector3.new(0, veilAimOffset, 0)
    local dist = (targetPos - origin).Magnitude
    local applyLead = targetVel ~= nil
    local mult = if applyLead then veilOffsetForDist(dist) else 0
    local dir: Vector3? = nil
    local tof = 0
    for _ = 1, 3 do
        dir, tof = veilSolveBallistic(origin, pred, speed, g)
        if not dir then return nil, 0 end
        if applyLead and targetVel then
            pred = targetPos + Vector3.new(0, veilAimOffset, 0) + targetVel * (tof * mult)
        end
    end
    return dir, tof
end

local veilFovCircle: any = nil
if Drawing then
    veilFovCircle = Drawing.new("Circle")
    veilFovCircle.Thickness = 2
    veilFovCircle.NumSides = 64
    veilFovCircle.Radius = veilPovSize
    veilFovCircle.Filled = false
    veilFovCircle.Visible = false
    veilFovCircle.Color = Color3.fromRGB(255, 255, 255)
end

RunService.RenderStepped:Connect(function()
    -- ponytail: zero-cost when disabled
    if not veilAimLockEnabled and not veilSilentAimEnabled then
        veilTargetPos, veilTargetVel = nil, nil
        veilSampleName = nil
        veilLockedPlayer = nil
        if veilFovCircle then veilFovCircle.Visible = false end
        return
    end

    if veilFovCircle then
        veilFovCircle.Visible = veilShowPov
        veilFovCircle.Radius = veilPovSize
        veilFovCircle.Position = veilGetFovCenter()
    end

    local stanceChar = LocalPlayer.Character
    local inThrowStance = stanceChar and stanceChar:GetAttribute("spearmode") == true
    local holding = inThrowStance == true

    local target: Player?
    if holding then
        if not veilLockedPlayer then veilLockedPlayer = veilGetTarget() end
        local lChar = veilLockedPlayer and veilLockedPlayer.Character
        if not (lChar and lChar:FindFirstChild(VEIL_TARGET_PART)) then
            veilLockedPlayer = veilGetTarget()
        end
        target = veilLockedPlayer
        veilLockGraceUntil = tick() + 0.3
    elseif veilLockedPlayer and tick() < veilLockGraceUntil then
        local lChar = veilLockedPlayer.Character
        if lChar and lChar:FindFirstChild(VEIL_TARGET_PART) then
            target = veilLockedPlayer
        else
            veilLockedPlayer = nil
            target = veilGetTarget()
        end
    else
        veilLockedPlayer = nil
        target = veilGetTarget()
    end

    if target then
        local char = target.Character
        local part = char and char:FindFirstChild(VEIL_TARGET_PART) :: BasePart?
        if part then
            local pos = part.Position
            local now = tick()
            if veilSampleName == target.Name and veilSamplePos then
                local dt = now - veilSampleT
                if dt >= 0.04 then
                    local instVel = (pos - veilSamplePos) / dt
                    veilTargetVel = if veilTargetVel then veilTargetVel:Lerp(instVel, 0.5) else instVel
                    veilSamplePos = pos
                    veilSampleT = now
                end
            else
                veilSampleName = target.Name
                veilSamplePos = pos
                veilSampleT = now
                veilTargetVel = Vector3.zero
            end
            veilTargetPos = pos
            if veilFovCircle then veilFovCircle.Color = Color3.fromRGB(255, 0, 0) end

            if veilAimLockEnabled and holding then
                local cam = Workspace.CurrentCamera
                local origin = cam.CFrame.Position
                local dir = veilSolveLead(origin, pos, veilTargetVel, VEIL_LOCK_SPEED, VEIL_GRAVITY)
                if dir then
                    local goal = CFrame.new(origin, origin + dir)
                    cam.CFrame = cam.CFrame:Lerp(goal, VEIL_SMOOTH)
                end
            end
        else
            veilTargetPos, veilTargetVel = nil, nil
            veilSampleName = nil
        end
    else
        veilTargetPos, veilTargetVel = nil, nil
        veilSampleName = nil
        if veilFovCircle then veilFovCircle.Color = Color3.fromRGB(255, 255, 255) end
    end
end)

-- ponytail: silent aim hook for veil Spearthrow remote
onNamecall(function(self, method, ...)
    if method ~= "FireServer" or not veilSilentAimEnabled or not veilTargetPos then return false end
    if self.Name ~= "Spearthrow" then return false end
    local p = self.Parent
    if not (p and p.Name == "Veil") then return false end
    local args = { ... }
    local dirArg, speedArg, originArg = args[1], args[2], args[3]
    if typeof(dirArg) == "Vector3" and type(speedArg) == "number" and typeof(originArg) == "Vector3" then
        local newDir = veilSolveLead(originArg, veilTargetPos, veilTargetVel, speedArg, VEIL_GRAVITY)
        if newDir then
            args[1] = newDir
            return true, callOriginal(self, unpack(args))
        end
    end
    return false
end)

-- cleanup old connections on re-run
if getgenv then
    local g = getgenv()
    if g.__tomaVeilFov then pcall(function() g.__tomaVeilFov:Remove() end) end
    g.__tomaVeilFov = veilFovCircle
end

-- Install namecall hook (shared by both aim modules)
task.spawn(installNamecallHook)

-- =====================================================================
-- EXPORT COMBINED LOGIC MODULE
-- =====================================================================
local Logic = {
    Combat = {
        SetAutoParry = function(enabled: boolean)
            autoParryEnabled = enabled
        end,
        SetParryDistance = function(dist: number)
            parryDistance = dist
        end,
        SetDashParryDistance = function(dist: number)
            dashDistance = dist
        end,
        SetAutoDodgeAbyss = function(enabled: boolean)
            autoDodgeEnabled = enabled
        end,
        SetDodgeDistance = function(dist: number)
            dodgeDistance = dist
        end,
        SetAutoSkillcheck = function(enabled: boolean)
            autoSkillcheckEnabled = enabled
        end
    },
    ESP = ESP,
    GunAim = {
        SetAimLock = function(enabled: boolean)
            gunAimLockEnabled = enabled
        end,
        SetSilentAim = function(enabled: boolean)
            gunSilentAimEnabled = enabled
        end,
        SetShowPov = function(enabled: boolean)
            gunShowPov = enabled
        end,
        SetAimOffset = function(value: number)
            gunAimOffset = value
        end,
        SetPovSize = function(value: number)
            gunPovSize = value
            if gunFovCircle then gunFovCircle.Radius = value end
        end,
    },
    VeilAim = {
        SetAimLock = function(enabled: boolean)
            veilAimLockEnabled = enabled
        end,
        SetSilentAim = function(enabled: boolean)
            veilSilentAimEnabled = enabled
        end,
        SetShowPov = function(enabled: boolean)
            veilShowPov = enabled
        end,
        SetAimOffset = function(value: number)
            veilAimOffset = value
        end,
        SetPovSize = function(value: number)
            veilPovSize = value
            if veilFovCircle then veilFovCircle.Radius = value end
        end,
        SetDistOffset = function(index: number, dist: number, offset: number)
            if veilDistOffsets[index] then
                veilDistOffsets[index] = { dist = dist, offset = offset }
            end
        end,
        AddDistOffset = function(dist: number, offset: number)
            table.insert(veilDistOffsets, { dist = dist, offset = offset })
        end,
        RemoveDistOffset = function(index: number)
            if #veilDistOffsets > 1 and veilDistOffsets[index] then
                table.remove(veilDistOffsets, index)
            end
        end,
        GetDistOffsets = function(): { { dist: number, offset: number } }
            return veilDistOffsets
        end,
    },
}

getgenv().AutomaHubLogic = Logic
return Logic

