--!strict

local Fluent = loadstring(game:HttpGet("https://github.com/StyearX/Fluent-Modded/releases/download/Fluent/FluentPro"))() :: any

-- ponytail: require, readfile, or HTTP fallback
local Theme = (function()
    local hasScript = typeof(script) == "Instance" and script:IsA("LuaSourceContainer")
    if hasScript then
        local success, module = pcall(require, script.Parent:WaitForChild("Theme") :: ModuleScript)
        if success then return module end
    end
    
    local ok, fileContent = pcall(readfile, "AutomaHubMenu/Theme.lua")
    if ok then return loadstring(fileContent)() end
    
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/G4N05/AutomaHub/main/AutomaHubMenu/Theme.lua"))()
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

Window:SelectTab(1)
