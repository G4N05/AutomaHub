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

local function getAsset(path: string): string
    local getcustom = (getgenv() :: any).getcustomasset or (getgenv() :: any).getsynasset or (_G :: any).getcustomasset
    if getcustom then
        local success, asset = pcall(getcustom, path)
        if success then return asset end
        success, asset = pcall(getcustom, "AutomaHub/" .. path)
        if success then return asset end
    end
    return "rbxassetid://6031075929"
end

local function customizeTitle(windowTitleText: string)
    local parentGui = (function()
        local ok, hui = pcall(function() return (getgenv().gethui or gethui)() end)
        if ok and hui then return hui end
        local okc, core = pcall(function() return game:GetService("CoreGui") end)
        if okc and core then return core end
        return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end)()

    local screenGui = parentGui:WaitForChild("Fluent", 2) or parentGui:FindFirstChild("Fluent")
    if not screenGui then
        for _, child in ipairs(parentGui:GetChildren()) do
            if child:IsA("ScreenGui") and child.Name == "Fluent" then
                screenGui = child
                break
            end
        end
    end

    if screenGui then
        local titleLabel = nil
        for _, desc in ipairs(screenGui:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Text == windowTitleText then
                titleLabel = desc
                break
            end
        end

        if titleLabel then
            local container = titleLabel.Parent
            if container then
                titleLabel.Visible = false

                local logoImage = Instance.new("ImageLabel")
                logoImage.Name = "AutomaHubLogo"
                logoImage.Size = UDim2.fromOffset(24, 24)
                logoImage.Position = UDim2.new(0, 16, 0.5, -12)
                logoImage.BackgroundTransparency = 1
                logoImage.Image = getAsset("Icon/logo.jpg")
                logoImage.Parent = container

                local newTitle = Instance.new("TextLabel")
                newTitle.Name = "AutomaHubTitle"
                newTitle.Size = UDim2.new(1, -60, 1, 0)
                newTitle.Position = UDim2.new(0, 48, 0, 0)
                newTitle.BackgroundTransparency = 1
                newTitle.Text = "AutomaHub"
                newTitle.TextColor3 = Color3.fromRGB(245, 245, 250)
                newTitle.TextSize = 20
                newTitle.TextXAlignment = Enum.TextXAlignment.Left

                local fontFace
                pcall(function()
                    fontFace = Font.new("rbxgameasset://Fonts/HelloChristmas-1Ge70")
                end)
                if fontFace then
                    newTitle.FontFace = fontFace
                else
                    newTitle.Font = Enum.Font.FredokaOne
                end
                newTitle.Parent = container
            end
        end
    end
end

local Window = Fluent:CreateWindow({
    Title = "GUI",
    SubTitle = "",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Charcoal",
    MinimizeKey = Enum.KeyCode.LeftControl
})

customizeTitle("GUI")

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" })
}

Theme.Init(Fluent, Tabs.Main)
Window:SelectTab(1)

