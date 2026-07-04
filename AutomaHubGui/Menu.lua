--!strict

local WindUI = getgenv().WindUI or loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))() :: any

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

-- ponytail: require, readfile, or HTTP fallback for Logic module (Combat + ESP)
local Logic = (function()
    if getgenv().AutomaHubLogic then
        return getgenv().AutomaHubLogic
    end

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

local Window = getgenv().Window
if not Window then
    warn("[AutomaHub] Window is not initialized yet!")
    return
end

local Tabs = {
    Main = Window:Tab({ Title = "Main", Icon = "home" }),
    Combat = Window:Tab({ Title = "Combat", Icon = "swords" }),
    Visuals = Window:Tab({ Title = "Visuals", Icon = "eye" })
}

-- Init Theme in Main tab
if Theme and typeof(Theme) == "table" and typeof(Theme.Init) == "function" then
    Theme.Init(WindUI, Tabs.Main)
else
    warn("[AutomaHub] Failed to load Theme module!")
end

-- Init Combat Controls in Combat tab
local Combat = Logic and Logic.Combat
if Combat then
    Tabs.Combat:Toggle({
        Title = "Auto Parry",
        Desc = "Automatically parry killer attacks",
        Value = false,
        Callback = function(Value: boolean)
            Combat.SetAutoParry(Value)
        end
    })

    Tabs.Combat:Slider({
        Title = "Parry Distance",
        Desc = "Parry detection distance",
        Value = { Min = 5, Max = 25, Default = 9 },
        Callback = function(Value: number)
            Combat.SetParryDistance(math.floor(Value))
        end
    })

    Tabs.Combat:Slider({
        Title = "Dash Parry Distance",
        Desc = "Dash parry distance (auto with Auto Parry)",
        Value = { Min = 20, Max = 50, Default = 30 },
        Callback = function(Value: number)
            Combat.SetDashParryDistance(math.floor(Value))
        end
    })

    Tabs.Combat:Toggle({
        Title = "Dodge Hidden (Abyss)",
        Desc = "Automatically dodge Abysswalker skills",
        Value = false,
        Callback = function(Value: boolean)
            Combat.SetAutoDodgeAbyss(Value)
        end
    })

    Tabs.Combat:Slider({
        Title = "Dodge Distance",
        Desc = "Distance to detect & dodge Abyss skills",
        Value = { Min = 15, Max = 35, Default = 25 },
        Callback = function(Value: number)
            Combat.SetDodgeDistance(math.floor(Value))
        end
    })

    Tabs.Combat:Toggle({
        Title = "Auto Skillcheck",
        Desc = "Automatically hit perfect skillchecks",
        Value = false,
        Callback = function(Value: boolean)
            Combat.SetAutoSkillcheck(Value)
        end
    })

    -- Apply defaults to Logic immediately (so values are correct even before user touches sliders)
    Combat.SetParryDistance(9)
    Combat.SetDashParryDistance(30)
    Combat.SetDodgeDistance(25)
    Combat.SetAutoSkillcheck(false)
else
    warn("[AutomaHub] Failed to load Combat module!")
end

-- Init Visuals (ESP) Controls in Visuals tab
local ESP = Logic and Logic.ESP
if ESP then
    Tabs.Visuals:Toggle({
        Title = "Enable ESP",
        Desc = "Master toggle to activate/deactivate ESP",
        Value = false,
        Callback = function(Value: boolean)
            ESP.SetMasterEnabled(Value)
        end
    })

    Tabs.Visuals:Dropdown({
        Title = "Choose ESP",
        Desc = "Select target ESP types to display",
        Values = { "Player", "Generator", "Pallet", "SCP / Zombie" },
        Value = {},
        Multi = true,
        Callback = function(Value: any)
            ESP.SetSelectedKinds(Value)
        end
    })
else
    warn("[AutomaHub] Failed to load ESP module!")
end

