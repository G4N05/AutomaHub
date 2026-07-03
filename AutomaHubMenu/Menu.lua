--!strict

type ThemeModule = {
    Init: (Fluent: any, Tab: any) -> any
}

local Fluent = loadstring(game:HttpGet("https://github.com/StyearX/Fluent-Modded/releases/download/Fluent/FluentPro"))() :: any

-- ponytail: require, readfile, or HTTP fallback
local Theme: ThemeModule = (function(): ThemeModule
    local success, module = pcall(function()
        local parent = script and script.Parent
        if not parent then error("no parent") end
        return require(parent:WaitForChild("Theme", 2) :: ModuleScript)
    end)
    if success then return module :: ThemeModule end
    local ok, fileContent = pcall(readfile, "AutomaHub/AutomaHubMenu/Theme.lua")
    if ok then return loadstring(fileContent)() :: ThemeModule end
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/G4N05/AutomaHub/main/AutomaHubMenu/Theme.lua"))() :: ThemeModule
end)()

local Window = Fluent:CreateWindow({
    Title = "GUI",
    SubTitle = "",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Charcoal",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" })
}

Theme.Init(Fluent, Tabs.Main)
