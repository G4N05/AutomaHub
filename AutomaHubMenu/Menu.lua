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

local Window = Fluent:CreateWindow({
    Title = "AutomaHub",
    SubTitle = "",
    TabWidth = isMobile and 120 or 160,
    Size = isMobile and UDim2.fromOffset(480, 360) or UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Charcoal",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- ponytail: add logo, bold, and add glitch effect to title text
for _, desc in ipairs(Window.Root:GetDescendants()) do
    if desc:IsA("TextLabel") and desc.Text == "AutomaHub" then
        local label = desc :: TextLabel
        label.Font = Enum.Font.GothamBold
        
        local logoPath = "AutomaHub/Icon/logo.jpg"
        local asset = nil
        if (getcustomasset or getsynasset) and writefile then
            if isfile and not isfile(logoPath) then
                pcall(makefolder, "AutomaHub")
                pcall(makefolder, "AutomaHub/Icon")
                local success, content = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/G4N05/AutomaHub/main/Icon/logo.jpg")
                if success and content then
                    pcall(writefile, logoPath, content)
                end
            end
            if isfile and isfile(logoPath) then
                local success, res = pcall((getcustomasset or getsynasset), logoPath)
                if success and res then
                    asset = res
                end
            end
        end
        
        if asset then
            label.Position = UDim2.new(0, 32, 0, 0)
            local logo = Instance.new("ImageLabel")
            logo.Name = "CustomLogo"
            logo.BackgroundTransparency = 1
            logo.Position = UDim2.new(0, 0, 0.5, -12)
            logo.Size = UDim2.fromOffset(24, 24)
            logo.Image = asset
            logo.Parent = label.Parent
        else
            label.Position = UDim2.new(0, 0, 0, 0)
        end
        
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
