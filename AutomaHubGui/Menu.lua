--!strict

local WindUI = getgenv().WindUI
local Window = getgenv().Window
if not WindUI or not Window then
    warn("[AutomaHub] WindUI or Window not initialized!")
    return
end

-- ponytail: require, readfile, or HTTP fallback for Logic module
local Logic = (function()
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
    
    return getgenv().AutomaHubLogic
end)()

local Combat = Logic and Logic.Combat

-- Create Tabs
local CombatTab = Window:Tab({ Title = "Combat", Icon = "swords" })
local ThemeTab = Window:Tab({ Title = "Theme", Icon = "palette" })

-- Combat Tab Sections (Tidied and organized)
local ParrySection = CombatTab:Section({ Title = "Auto Parry Settings" })
ParrySection:Toggle({
    Title = "Auto Parry",
    Desc = "Automatically parry killer attacks",
    Value = false,
    Callback = function(value: boolean)
        if Combat and Combat.SetAutoParry then
            Combat.SetAutoParry(value)
        end
    end
})

ParrySection:Slider({
    Title = "Parry Distance",
    Value = { Min = 5, Max = 25, Default = 9 },
    Callback = function(value: number)
        if Combat and Combat.SetParryDistance then
            Combat.SetParryDistance(value)
        end
    end
})

ParrySection:Slider({
    Title = "Dash Parry Distance",
    Value = { Min = 20, Max = 50, Default = 30 },
    Callback = function(value: number)
        if Combat and Combat.SetDashParryDistance then
            Combat.SetDashParryDistance(value)
        end
    end
})

local DodgeSection = CombatTab:Section({ Title = "Auto Dodge Settings" })
DodgeSection:Toggle({
    Title = "Auto Dodge (Abysswalker)",
    Desc = "Automatically dodge Abysswalker skills",
    Value = false,
    Callback = function(value: boolean)
        if Combat and Combat.SetAutoDodgeAbyss then
            Combat.SetAutoDodgeAbyss(value)
        end
    end
})

DodgeSection:Slider({
    Title = "Dodge Distance",
    Value = { Min = 15, Max = 35, Default = 25 },
    Callback = function(value: number)
        if Combat and Combat.SetDodgeDistance then
            Combat.SetDodgeDistance(value)
        end
    end
})

local SkillcheckSection = CombatTab:Section({ Title = "Skillcheck Settings" })
SkillcheckSection:Toggle({
    Title = "Auto Skillcheck",
    Desc = "Automatically hit perfect skillchecks",
    Value = false,
    Callback = function(value: boolean)
        if Combat and Combat.SetAutoSkillcheck then
            Combat.SetAutoSkillcheck(value)
        end
    end
})

-- Theme Tab (Dropdown selection)
local themes = {}
for name in pairs(WindUI:GetThemes()) do
    table.insert(themes, name)
end
table.sort(themes)

ThemeTab:Dropdown({
    Title = "Theme",
    Values = themes,
    Value = "Crimson",
    Callback = function(value: string)
        WindUI:SetTheme(value)
    end
})
