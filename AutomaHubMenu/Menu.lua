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

local Window = Fluent:CreateWindow({
    Title = "AutomaHub",
    SubTitle = "",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Charcoal",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- ponytail: replace title text with logo and custom font text
for _, desc in ipairs(Window.Root:GetDescendants()) do
    if desc:IsA("TextLabel") and desc.Text == "AutomaHub" then
        desc.Visible = false
        
        local logo = Instance.new("ImageLabel")
        logo.Name = "CustomLogo"
        logo.BackgroundTransparency = 1
        logo.Position = UDim2.new(0, 0, 0.5, -12)
        logo.Size = UDim2.fromOffset(24, 24)
        logo.Image = (getcustomasset or getsynasset)(isfile("AutomaHub/Icon/logo.jpg") and "AutomaHub/Icon/logo.jpg" or "Icon/logo.jpg")
        logo.Parent = desc.Parent
        
        local label = Instance.new("TextLabel")
        label.Name = "CustomTitle"
        label.BackgroundTransparency = 1
        label.Position = UDim2.new(0, 32, 0, 0)
        label.Size = UDim2.new(1, -32, 1, 0)
        label.Text = "AutomaHub"
        label.TextColor3 = Color3.fromRGB(245, 245, 250)
        label.TextSize = 22
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Center
        
        local fontUrl = (getcustomasset or getsynasset)(isfile("AutomaHub/Icon/King Luau.ttf") and "AutomaHub/Icon/King Luau.ttf" or "Icon/King Luau.ttf")
        label.FontFace = Font.new(fontUrl)
        label.Parent = desc.Parent
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
