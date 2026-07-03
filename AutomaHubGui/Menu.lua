--!strict

local Fluent = getgenv().Fluent or loadstring(game:HttpGet("https://github.com/StyearX/Fluent-Modded/releases/download/Fluent/FluentPro"))() :: any

-- ponytail: require, readfile, or HTTP fallback for Theme module
local Theme = (function()
    local themeScript = typeof(script) == "Instance" and script.Parent and script.Parent:FindFirstChild("Theme")
    if themeScript and themeScript:IsA("ModuleScript") then
        local success, module = pcall(require, themeScript)
        if success then return module end
    end
    
    local ok, fileContent = pcall(readfile, "AutomaHub/AutomaHubGui/Theme.lua")
    if ok then
        local loader, err = loadstring(fileContent)
        if loader then
            local success, module = pcall(loader)
            if success and module then return module end
        end
    end
    
    local ok2, remoteContent = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/G4N05/AutomaHub/main/AutomaHubGui/Theme.lua")
    if ok2 then
        local loader, err = loadstring(remoteContent)
        if loader then
            local success, module = pcall(loader)
            if success and module then return module end
        end
    end
    
    return nil
end)()

-- ponytail: retry-wait bridge loader for Logic module
local Logic = (function()
    for _ = 1, 50 do
        local globalLogic = getgenv().AutomaHubLogic or (_G and _G.AutomaHubLogic)
        if globalLogic then return globalLogic end
        task.wait(0.1)
    end
    
    local globalLogic = getgenv().AutomaHubLogic or (_G and _G.AutomaHubLogic)
    if globalLogic then return globalLogic end

    local logicScript = typeof(script) == "Instance" and script.Parent and script.Parent:FindFirstChild("LogicFunction")
    if logicScript and logicScript:IsA("ModuleScript") then
        local success, module = pcall(require, logicScript)
        if success then return module end
    end
    
    local ok, fileContent = pcall(readfile, "AutomaHub/AutomaHubGui/LogicFunction.lua")
    if ok then
        local loader, err = loadstring(fileContent)
        if loader then
            local success, module = pcall(loader)
            if success and module then return module end
        end
    end
    
    local ok2, remoteContent = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/G4N05/AutomaHub/main/AutomaHubGui/LogicFunction.lua")
    if ok2 then
        local loader, err = loadstring(remoteContent)
        if loader then
            local success, module = pcall(loader)
            if success and module then return module end
        end
    end
    
    return nil
end)()

local function getLiveCombat(): any
    local L = getgenv().AutomaHubLogic or (_G and _G.AutomaHubLogic) or Logic
    return L and L.Combat
end

local function getLiveESP(): any
    local L = getgenv().AutomaHubLogic or (_G and _G.AutomaHubLogic) or Logic
    return L and L.ESP
end

local Window = getgenv().Window
if not Window then
    warn("[AutomaHub] Window is not initialized yet!")
    return
end

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "swords" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" })
}

-- Init Theme in Main tab
if Theme and typeof(Theme) == "table" and typeof(Theme.Init) == "function" then
    Theme.Init(Fluent, Tabs.Main)
else
    warn("[AutomaHub] Failed to load Theme module!")
end

-- Init Combat Controls in Combat tab
Tabs.Combat:AddToggle("AutoParryToggle", {
    Title = "Auto Parry",
    Description = "Automatically parry killer attacks",
    Default = false,
    Callback = function(Value: boolean)
        local C = getLiveCombat()
        if C then C.SetAutoParry(Value) end
    end
})

Tabs.Combat:AddSlider("ParryDistance", {
    Title = "Parry Distance",
    Description = "Parry detection distance",
    Default = 9,
    Min = 5,
    Max = 25,
    Rounding = 0,
    Suffix = "u",
    Callback = function(Value: number)
        local C = getLiveCombat()
        if C then C.SetParryDistance(math.floor(Value)) end
    end
})

Tabs.Combat:AddSlider("DashParryDistance", {
    Title = "Dash Parry Distance",
    Description = "Dash parry distance (auto with Auto Parry)",
    Default = 30,
    Min = 20,
    Max = 50,
    Rounding = 0,
    Suffix = "u",
    Callback = function(Value: number)
        local C = getLiveCombat()
        if C then C.SetDashParryDistance(math.floor(Value)) end
    end
})

Tabs.Combat:AddToggle("AutoDodgeAbyssToggle", {
    Title = "Dodge Hidden (Abyss)",
    Description = "Automatically dodge Abysswalker skills",
    Default = false,
    Callback = function(Value: boolean)
        local C = getLiveCombat()
        if C then C.SetAutoDodgeAbyss(Value) end
    end
})

Tabs.Combat:AddSlider("DodgeDistance", {
    Title = "Dodge Distance",
    Description = "Distance to detect & dodge Abyss skills",
    Default = 25,
    Min = 15,
    Max = 35,
    Rounding = 0,
    Suffix = "u",
    Callback = function(Value: number)
        local C = getLiveCombat()
        if C then C.SetDodgeDistance(math.floor(Value)) end
    end
})

-- Apply initial defaults to live Combat module immediately
local C = getLiveCombat()
if C then
    C.SetParryDistance(9)
    C.SetDashParryDistance(30)
    C.SetDodgeDistance(25)
end

-- Init Visuals (ESP) Controls in Visuals tab
Tabs.Visuals:AddToggle("ESPMasterToggle", {
    Title = "Enable ESP",
    Description = "Master toggle to activate/deactivate ESP",
    Default = false,
    Callback = function(Value: boolean)
        local E = getLiveESP()
        if E then E.SetMasterEnabled(Value) end
    end
})

Tabs.Visuals:AddDropdown("ESPSelection", {
    Title = "Choose ESP",
    Description = "Select target ESP types to display",
    Values = { "Player", "Generator", "Pallet", "SCP / Zombie" },
    Multi = true,
    Default = {},
    Callback = function(Value: any)
        local E = getLiveESP()
        if E then E.SetSelectedKinds(Value) end
    end
})
