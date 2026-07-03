--!strict

local Fluent = loadstring(game:HttpGet("https://github.com/StyearX/Fluent-Modded/releases/download/Fluent/FluentPro"))() :: any

-- ponytail: require, readfile, or HTTP fallback
local Theme = (function()
    if script and script.Parent then
        local success, module = pcall(function()
            return require(script.Parent:WaitForChild("Theme") :: ModuleScript)
        end)
        if success then return module end
    end
    local ok, fileContent = pcall(readfile, "AutomaHub/AutomaHubMenu/Theme.lua")
    if ok then return loadstring(fileContent)() end
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/G4N05/AutomaHub/main/AutomaHubMenu/Theme.lua"))()
end)()


local function customizeHeader()
    local function apply()
        local parentGui = nil
        local containers = { (getgenv().gethui or gethui) and (getgenv().gethui or gethui)(), game:GetService("CoreGui"), Players.LocalPlayer:FindFirstChild("PlayerGui") }
        
        for _, container in ipairs(containers) do
            if not container then continue end
            for _, desc in ipairs(container:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Text == "GUI" then
                    local titleLabel = desc
                    titleLabel.Text = "AutomaHub"
                    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
                    
                    local parent = titleLabel.Parent
                    if parent then
                        local logo = Instance.new("ImageLabel")
                        logo.Name = "Logo"
                        logo.BackgroundTransparency = 1
                        logo.BorderSizePixel = 0
                        logo.Size = UDim2.fromOffset(18, 18)
                        logo.Position = UDim2.new(0, 16, 0.5, -9)
                        logo.Image = (getcustomasset or getsynasset) and (getcustomasset or getsynasset)("Icon/logo.jpg") or "rbxassetid://0"
                        logo.Parent = parent
                        
                        titleLabel.Position = UDim2.new(0, 40, titleLabel.Position.Y.Scale, titleLabel.Position.Y.Offset)
                    end
                    return true
                end
            end
        end
        return false
    end
    
    if not apply() then
        task.defer(function()
            for i = 1, 10 do
                if apply() then break end
                task.wait(0.1)
            end
        end)
    end
end

local Players = game:GetService("Players")
local Window = Fluent:CreateWindow({
    Title = "GUI",
    SubTitle = "",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Charcoal",
    MinimizeKey = Enum.KeyCode.LeftControl
})

customizeHeader()


local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" })
}

Theme.Init(Fluent, Tabs.Main)
Window:SelectTab(1)

