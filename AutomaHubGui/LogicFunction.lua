--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Colors
local COLOR_GEN     = Color3.fromRGB(85, 255, 85)   -- Generator: Green
local COLOR_PALLET  = Color3.fromRGB(255, 215, 0)   -- Pallet: Yellow
local COLOR_ZOMBIE  = Color3.fromRGB(255, 60, 60)   -- SCP/Zombie: Red
local COLOR_PLAYER  = Color3.fromRGB(0, 255, 170)   -- Player survivor: Cyan-Green
local COLOR_KILLER  = Color3.fromRGB(255, 60, 60)   -- Player killer: Red
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

local masterEnabled = false
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
    return masterEnabled and (selectedKinds[kind] == true)
end

local function pushConn(kind: string, c: RBXScriptConnection)
    local cs = connsByKind[kind]
    if cs then
        cs[#cs + 1] = c
    end
end

-- Cleanup single tracked model
local function cleanup(model: Instance)
    local t = tracked[model]
    if not t then return end
    if t.progConns then
        for _, c in ipairs(t.progConns) do
            pcall(function() c:Disconnect() end)
        end
    end
    if t.hl then pcall(function() t.hl:Destroy() end) end
    if t.bill then pcall(function() t.bill:Destroy() end) end
    tracked[model] = nil
end

-- Stop ESP for a specific kind
local function stopKind(kind: string)
    local cs = connsByKind[kind]
    if cs then
        for _, c in ipairs(cs) do
            pcall(function() c:Disconnect() end)
        end
        connsByKind[kind] = {}
    end
    
    for key, e in pairs(tracked) do
        if e.kind == kind then
            cleanup(key)
        end
    end
end

-- Optimized Highlight creation
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

-- Optimized Billboard creation
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

-- Optimized Distance Loop (no pcall closures inside loop, throttled efficiently)
local function ensureDistLoop()
    if distLoopRunning then return end
    distLoopRunning = true
    task.spawn(function()
        while masterEnabled and next(tracked) ~= nil do
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

-- ---------- GENERATOR ----------
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
    
    tracked[model] = {
        hl = hl,
        bill = bill,
        anchor = anchor,
        sub = sub,
        progConns = { pc1, pc2 },
        kind = "Generator"
    }
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

-- ---------- PALLET (Optimized) ----------
local function pickPlank(model: Model): BasePart?
    -- Check direct children first for performance
    local best: BasePart? = nil
    local bestVol = 0
    for _, d in ipairs(model:GetChildren()) do
        if d:IsA("MeshPart") and d.Transparency < 1 then
            local s = d.Size
            local vol = s.X * s.Y * s.Z
            if vol > bestVol then
                best = d :: BasePart
                bestVol = vol
            end
        end
    end
    if best then return best end
    
    -- Fallback to descendants if direct children don't match
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("MeshPart") and d.Transparency < 1 then
            local s = d.Size
            local vol = s.X * s.Y * s.Z
            if vol > bestVol then
                best = d :: BasePart
                bestVol = vol
            end
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

-- ---------- SCP / ZOMBIE ----------
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

-- ---------- PLAYER ----------
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
    if t.nameL then
        t.nameL.TextColor3 = col
    end
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

-- Update state for each ESP kind
function ESP.UpdateStates()
    for _, kind in ipairs({"Generator", "Pallet", "SCP", "Player"}) do
        local shouldBeActive = masterEnabled and (selectedKinds[kind] == true)
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

-- Public Master Toggle setter
function ESP.SetMasterEnabled(enabled: boolean)
    masterEnabled = enabled
    ESP.UpdateStates()
end

-- Public Selection setter (normalizes dictionary or array format from UI)
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
                -- Array format: {"Player", "SCP"}
                if v == "SCP / Zombie" or v == "Zombie" then
                    newSelected["SCP"] = true
                else
                    newSelected[v] = true
                end
            elseif typeof(k) == "string" and v == true then
                -- Dictionary format: { ["Player"] = true }
                if k == "SCP / Zombie" or k == "Zombie" then
                    newSelected["SCP"] = true
                else
                    newSelected[k] = true
                end
            end
        end
    end
    
    selectedKinds = newSelected
    ESP.UpdateStates()
end

getgenv().AutomaHubESP = ESP
return ESP
