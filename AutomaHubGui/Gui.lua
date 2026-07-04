--!strict

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))() :: any

getgenv().WindUI = WindUI

local Window = WindUI:CreateWindow({
    Title = "AutomaHub",
    Icon = "swords", 
    Author = "G4N05",
    Folder = "AutomaHubConfig",
    Size = UDim2.fromOffset(580, 460),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 170,
    HasOutline = true
})
getgenv().Window = Window

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

-- ponytail: add logo and glitch effect to title text
if Window and Window.Instance then
    for _, desc in ipairs(Window.Instance:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text == "AutomaHub" then
            local label = desc :: TextLabel
            label.Font = Enum.Font.GothamBold
            
            -- Wind UI handles icon placement differently, but we can override it if we want
            local originalPos = label.Position
            local originalText = label.Text
            local chars = {"#", "@", "$", "%", "*", "!", "?", "0", "1"}
            
            -- Glitch effect loop
            task.spawn(function()
                local rng = Random.new()
                
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

-- Wind UI doesn't have an explicit minimize function in the early docs, but usually destroying/recreating or just toggling UI visibility works.
-- Most modern UIs hide when you press a key bind. We'll simulate a keybind press or hide the window instance.
btn.MouseButton1Click:Connect(function()
    if Window and Window.Instance then
        Window.Instance.Enabled = not Window.Instance.Enabled
    end
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
