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
    if not autoParryEnabled then warn("[AutomaHub Debug] AutoParry disabled") return end
    if killerDistance > maxRange then warn("[AutomaHub Debug] Out of range:", killerDistance, ">", maxRange) return end
    if not canParry() then warn("[AutomaHub Debug] canParry() is false. CD:", isOnCooldown, "Silenced:", isSilenced) return end
    if (os.clock() - lastPrePress) < rearmCooldown then warn("[AutomaHub Debug] Rearm cooldown active") return end
    if not hasLineOfSight() then warn("[AutomaHub Debug] No line of sight") return end
    if not isKillerFacing() then warn("[AutomaHub Debug] Killer not facing") return end
    
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

LocalPlayer.CharacterAdded:Connect(function() crouchController = nil isDodging = false end)

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


--SkillCheck

-- ============================================================
-- Violence District | AUTO SKILLCHECK (Side Script / Standalone)
-- ------------------------------------------------------------
-- Versi lepas dari framework AutomaHub. Bisa langsung di-execute
-- sendiri (Xeno dll) tanpa butuh ctx / AutomaHub.
--
-- Nyalinin SEMUA function skillcheck dari source:
--   resolveSkillCheckRefs()  -> cari GUI Line/Goal
--   SkillCheckEvent hook     -> simpen generatorModel & point
--   Heartbeat detector       -> deteksi zona "Great"
--   freezeNeedle()           -> bekuin jarum di tengah zona
--   disableGameScript()      -> matiin Skillcheck-gen game
--   playGreatSfx()           -> bunyiin sfx Great bawaan
--   fireSuccess()            -> kirim sukses ke server
--   cleanupUI()              -> bersihin UI & hidupin script game
-- Plus toggle universal (PC keybind + tombol mobile/PC di layar).
-- ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local LocalPlayer       = Players.LocalPlayer
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")

-- ===================== CONFIG =====================
local CONFIG = {
    enabled      = false,          -- state awal Auto Skillcheck
    toggleKey    = Enum.KeyCode.K, -- keybind PC buat on/off
    zoneMin      = 102,            -- offset bawah zona great (relatif ke Goal)
    zoneMax      = 116,            -- offset atas  zona great (relatif ke Goal)
    zoneCenter   = 108,            -- titik beku jarum (relatif ke Goal)
    cleanupDelay = 0.15,           -- jeda sebelum bersihin UI
    showButton   = true,           -- tampilin tombol toggle di layar (mobile+PC)
}

-- ===================== STATE ======================
local autoSkillCheckEnabled = CONFIG.enabled
local scTriggered = false
local SkillCheckFrame, SkillCheckLine, SkillCheckGoal = nil, nil, nil
local SkillCheckResultEvent, SkillCheckEvent = nil, nil
local generatorModel, generatorPoint = nil, nil

-- ============ FUNCTION: resolve refs GUI ==========
local function resolveSkillCheckRefs()
    local gui = PlayerGui:FindFirstChild("SkillCheckPromptGui")
    local check = gui and gui:FindFirstChild("Check")
    if not check then
        SkillCheckFrame, SkillCheckLine, SkillCheckGoal = nil, nil, nil
        return false
    end
    SkillCheckFrame = check
    SkillCheckLine  = check:FindFirstChild("Line")
    SkillCheckGoal  = check:FindFirstChild("Goal")
    return (SkillCheckLine ~= nil and SkillCheckGoal ~= nil)
end

-- ====== FUNCTION: resolve remotes Generator =======
local function resolveGeneratorRemotes()
    local ok, genFolder = pcall(function()
        return ReplicatedStorage:WaitForChild("Remotes", 10):WaitForChild("Generator", 10)
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

-- ========= FUNCTION: bekuin jarum di tengah =======
local function freezeNeedle(frozenRot)
    pcall(function()
        TweenService:Create(SkillCheckLine, TweenInfo.new(0), { Rotation = frozenRot }):Play()
        SkillCheckLine.Rotation = frozenRot
    end)
end

-- === FUNCTION: matiin script game + sfx Great =====
local function disableGameScriptAndSfx()
    local char = LocalPlayer.Character
    local scr = char and char:FindFirstChild("Skillcheck-gen")
    if scr then
        pcall(function() scr.Disabled = true end)
        local great = scr:FindFirstChild("Great")
        if great then pcall(function() great:Play() end) end
    end
    return scr
end

-- ======== FUNCTION: kirim sukses ke server ========
local function fireSuccess()
    if SkillCheckResultEvent and generatorModel and generatorPoint then
        pcall(function()
            SkillCheckResultEvent:FireServer("success", 1, generatorModel, generatorPoint)
        end)
    end
end

-- ==== FUNCTION: bersihin UI + hidupin script game =
local function cleanupUI(scr)
    task.delay(CONFIG.cleanupDelay, function()
        pcall(function()
            if SkillCheckFrame then SkillCheckFrame.Visible = false end
            if SkillCheckLine  then SkillCheckLine.Rotation = 0 end
            if SkillCheckGoal  then SkillCheckGoal.Rotation = 0 end
        end)
        if scr then pcall(function() scr.Disabled = false end) end
    end)
end

-- ============ CORE: detector heartbeat ============
local function tick()
    if not autoSkillCheckEnabled then scTriggered = false return end
    if not SkillCheckFrame or not SkillCheckFrame.Parent or not SkillCheckLine or not SkillCheckGoal then
        resolveSkillCheckRefs()
    end
    if not (SkillCheckFrame and SkillCheckFrame.Parent and SkillCheckFrame.Visible) then
        scTriggered = false
        return
    end
    if scTriggered then return end

    local rotation     = SkillCheckLine.Rotation
    local goalRotation = SkillCheckGoal.Rotation
    local minZone = CONFIG.zoneMin + goalRotation
    local maxZone = CONFIG.zoneMax + goalRotation

    if rotation >= minZone and rotation <= maxZone then
        scTriggered = true
        local frozenRot = CONFIG.zoneCenter + goalRotation
        freezeNeedle(frozenRot)                 -- 1. bekuin jarum
        local scr = disableGameScriptAndSfx()   -- 2-3. matiin script + sfx Great
        fireSuccess()                           -- 4. kirim sukses
        cleanupUI(scr)                          -- 5-6. bersihin & hidupin lagi
    end
end

-- ================== TOGGLE API ====================
local function setEnabled(state)
    autoSkillCheckEnabled = state and true or false
    if not autoSkillCheckEnabled then scTriggered = false end
    getgenv().AutoSkillCheckEnabled = autoSkillCheckEnabled
    print("[SkillCheck] Auto Skillcheck: " .. (autoSkillCheckEnabled and "ON" or "OFF"))
end
local function toggle() setEnabled(not autoSkillCheckEnabled) end

-- expose ke getgenv biar bisa dikontrol script lain / console
getgenv().SkillCheckSide = {
    setEnabled = setEnabled,
    toggle     = toggle,
    isEnabled  = function() return autoSkillCheckEnabled end,
}

-- ============ INPUT: keybind PC ===================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == CONFIG.toggleKey then toggle() end
end)

-- ====== UI: tombol toggle (mobile + PC) ===========
local function buildButton()
    if not CONFIG.showButton then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "SkillCheckSideGui"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() sg.Parent = (gethui and gethui()) or PlayerGui end)
    if not sg.Parent then sg.Parent = PlayerGui end

    local btn = Instance.new("TextButton")
    btn.Name = "Toggle"
    btn.Size = UDim2.new(0, 160, 0, 40)
    btn.Position = UDim2.new(0, 20, 0.5, -20)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    btn.BackgroundTransparency = 0.15
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(235, 235, 235)
    btn.Text = "Auto Skillcheck: OFF"
    btn.AutoButtonColor = true
    btn.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(90, 90, 110)
    stroke.Thickness = 1
    stroke.Parent = btn

    local function refresh()
        btn.Text = "Auto Skillcheck: " .. (autoSkillCheckEnabled and "ON" or "OFF")
        stroke.Color = autoSkillCheckEnabled and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(90, 90, 110)
    end
    btn.MouseButton1Click:Connect(function() toggle() refresh() end)
    -- refresh berkala kalau di-toggle lewat keybind/getgenv
    task.spawn(function()
        while sg.Parent do refresh() task.wait(0.3) end
    end)
end

-- ==================== INIT ========================
resolveSkillCheckRefs()
resolveGeneratorRemotes()
buildButton()
RunService.Heartbeat:Connect(tick)
setEnabled(CONFIG.enabled)

print("[SkillCheck] Side script loaded. Keybind: " .. CONFIG.toggleKey.Name)



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
        end
    },
    ESP = ESP
}

getgenv().AutomaHubLogic = Logic
return Logic
