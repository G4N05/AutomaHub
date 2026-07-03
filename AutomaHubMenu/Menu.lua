--!strict

local Fluent = loadstring(game:HttpGet("https://github.com/StyearX/Fluent-Modded/releases/download/Fluent/FluentPro"))() :: any

-- ponytail: require, readfile, or HTTP fallback
local Theme = (function()
    local themeScript = typeof(script) == "Instance" and script.Parent and script.Parent:FindFirstChild("Theme")
    if themeScript and themeScript:IsA("ModuleScript") then
        local success, module = pcall(require, themeScript)
        if success then return module end
    end
    
    local ok, fileContent = pcall(readfile, "AutomaHub/AutomaHubMenu/Theme.lua")
    if ok then
        local loader, err = loadstring(fileContent)
        if loader then
            local success, module = pcall(loader)
            if success and module then return module end
        end
    end
    
    local ok2, remoteContent = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/G4N05/AutomaHub/main/AutomaHubMenu/Theme.lua")
    if ok2 then
        local loader, err = loadstring(remoteContent)
        if loader then
            local success, module = pcall(loader)
            if success and module then return module end
        end
    end
    
    return nil
end)()

local UserInputService = game:GetService("UserInputService")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Get logo asset ID (works on all platforms)
local LOGO_ASSET_ID = "rbxassetid://89249705975584"
local asset = LOGO_ASSET_ID
if (getcustomasset or getsynasset) and writefile then
    local logoPath = "AutomaHub/Icon/logo.jpg"
    if isfile and not isfile(logoPath) then
        pcall(makefolder, "AutomaHub")
        pcall(makefolder, "AutomaHub/Icon")
        local ok, content = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/G4N05/AutomaHub/main/Icon/logo.jpg")
        if ok and content then pcall(writefile, logoPath, content) end
    end
    if isfile and isfile(logoPath) then
        local ok, res = pcall((getcustomasset or getsynasset), logoPath)
        if ok and res then asset = res end
    end
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local unlocked = false

-- While unlocked: force mouse Default + cursor each frame (overrides LockCenter)
task.spawn(function()
    while true do
        if unlocked then
            pcall(function()
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                UserInputService.MouseIconEnabled = true
            end)
        end
        task.wait()
    end
end)

-- ---------- GUI toggle ----------
local gui = Instance.new("ScreenGui")
gui.Name = "AutomaHub_MouseUnlock"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 160, 0, 40)
btn.Position = UDim2.new(0, 20, 0.5, -20)
btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
btn.BorderSizePixel = 0
btn.Font = Enum.Font.GothamBold
btn.TextSize = 14
btn.TextColor3 = Color3.fromRGB(0, 0, 0)
btn.AutoButtonColor = false
btn.Text = "Mouse: LOCKED"
btn.Active = true
btn.Draggable = true
btn.Parent = gui
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

local function setUnlock(v)
    unlocked = v
    btn.Text = "Mouse: " .. (v and "UNLOCKED" or "LOCKED")
    btn.BackgroundColor3 = v and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(70, 70, 70)
end

btn.MouseButton1Click:Connect(function() setUnlock(not unlocked) end)
UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.RightControl then setUnlock(not unlocked) end
end)

warn("[AutomaHub] Mouse Unlock loaded. Klik tombol / pencet RightControl buat toggle.")

-- ponytail: add logo, bold, and add glitch effect to title text
for _, desc in ipairs(Window.Root:GetDescendants()) do
    if desc:IsA("TextLabel") and desc.Text == "AutomaHub" then
        local label = desc :: TextLabel
        label.Font = Enum.Font.GothamBold
        label.Position = UDim2.new(0, 32, 0, 0)
        
        local logo = Instance.new("ImageLabel")
        logo.Name = "CustomLogo"
        logo.BackgroundTransparency = 1
        logo.Position = UDim2.new(0, 0, 0.5, -12)
        logo.Size = UDim2.fromOffset(24, 24)
        logo.Image = asset
        logo.Parent = label.Parent
        
        -- Glitch effect loop
        task.spawn(function()
            local rng = Random.new()
            local originalPos = label.Position
            local originalText = label.Text
            local chars = {"#", "@", "$", "%", "*", "!", "?", "0", "1"}
            
            while label and label.Parent do
                task.wait(rng:NextNumber(0.08, 0.45))
                if not (label and label.Parent) then break end
                
                if rng:NextNumber() < 0.35 then
                    local dx = rng:NextInteger(-2, 2)
                    local dy = rng:NextInteger(-1, 1)
                    label.Position = originalPos + UDim2.fromOffset(dx, dy)
                    
                    if rng:NextNumber() < 0.5 then
                        local len = string.len(originalText)
                        local idx = rng:NextInteger(1, len)
                        label.Text = string.sub(originalText, 1, idx - 1) .. chars[rng:NextInteger(1, #chars)] .. string.sub(originalText, idx + 1)
                    end
                    
                    task.wait(rng:NextNumber(0.02, 0.08))
                    if not (label and label.Parent) then break end
                    label.Position = originalPos
                    label.Text = originalText
                end
            end
        end)
        break
    end
end

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" })
}

if Theme and typeof(Theme) == "table" and typeof(Theme.Init) == "function" then
    Theme.Init(Fluent, Tabs.Main)
else
    warn("[AutomaHub] Failed to load Theme module!")
end

-- ponytail: simple draggable mobile toggle button
local parentGui = (function()
    local ok, hui = pcall(function() return (getgenv().gethui or gethui)() end)
    if ok and hui then return hui end
    local okc, core = pcall(function() return game:GetService("CoreGui") end)
    if okc and core then return core end
    return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end)()

local oldToggle = parentGui:FindFirstChild("AutomaHubToggle")
if oldToggle then pcall(function() oldToggle:Destroy() end) end

local toggleGui = Instance.new("ScreenGui")
toggleGui.Name = "AutomaHubToggle"
toggleGui.ResetOnSpawn = false
toggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
toggleGui.Parent = parentGui

local btn = Instance.new("ImageButton")
btn.Name = "ToggleButton"
btn.Size = UDim2.fromOffset(44, 44)
btn.Position = UDim2.new(0.02, 0, 0.4, 0)
btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
btn.Image = asset
btn.Parent = toggleGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = btn

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(60, 60, 65)
stroke.Parent = btn

btn.MouseButton1Click:Connect(function()
    Window:Minimize()
end)

-- simple dragging support
local dragging = false
local dragInput, dragStart, startPos

btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = btn.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

btn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ponytail: force unlock mouse when GUI is open, restore when closed
local RunService = game:GetService("RunService")
local mouseConn: RBXScriptConnection? = nil
local lastBehavior = UserInputService.MouseBehavior

task.spawn(function()
    while true do
        task.wait(0.1)
        local isMinimized = Window.Minimized
        if not isMinimized then
            if not mouseConn then
                lastBehavior = UserInputService.MouseBehavior
                mouseConn = RunService.RenderStepped:Connect(function()
                    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                end)
            end
        else
            if mouseConn then
                mouseConn:Disconnect()
                mouseConn = nil
                UserInputService.MouseBehavior = lastBehavior
            end
        end
    end
end)