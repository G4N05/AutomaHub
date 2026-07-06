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
local ESP = Logic and Logic.ESP
local Aim = Logic and Logic.Aim

-- Create Tabs
local ThemeTab = Window:Tab({ Title = "Theme", Icon = "palette" })
local CombatTab = Window:Tab({ Title = "Combat", Icon = "swords" })
local VisualTab = Window:Tab({ Title = "Visual", Icon = "eye" })
local AimTab = Window:Tab({ Title = "Aim", Icon = "crosshair" })

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

-- Visual Tab (ESP Settings)
local ESPSection = VisualTab:Section({ Title = "ESP Settings" })
ESPSection:Toggle({
    Title = "ESP",
    Desc = "Enable ESP visuals",
    Value = false,
    Callback = function(value: boolean)
        if ESP and ESP.SetMasterEnabled then
            ESP.SetMasterEnabled(value)
        end
    end
})

ESPSection:Dropdown({
    Title = "Select Esp",
    Desc = "Choose which ESP elements to display",
    Values = { "Player", "Generator", "Pallet", "Zombie" },
    Value = {},
    Multi = true,
    Callback = function(values: { string })
        if ESP and ESP.SetSelectedKinds then
            ESP.SetSelectedKinds(values)
        end
    end
})

-- Aim Tab (Aim Gun Settings)
local AimSection = AimTab:Section({ Title = "Aim Gun Settings" })

AimSection:Dropdown({
    Title = "Aim Gun",
    Desc = "Select Aim Gun mode",
    Values = { "Disabled", "Silent Aim", "Aim Lock", "Both" },
    Value = "Both",
    Callback = function(value: string)
        if Aim then
            if value == "Disabled" then
                Aim.SetSilentAim(false)
                Aim.SetAimLock(false)
            elseif value == "Silent Aim" then
                Aim.SetSilentAim(true)
                Aim.SetAimLock(false)
            elseif value == "Aim Lock" then
                Aim.SetSilentAim(false)
                Aim.SetAimLock(true)
            elseif value == "Both" then
                Aim.SetSilentAim(true)
                Aim.SetAimLock(true)
            end
        end
    end
})

AimSection:Dropdown({
    Title = "Aim Target",
    Desc = "Target team selection",
    Values = { "Killer", "Survivor" },
    Value = "Killer",
    Callback = function(value: string)
        if Aim and Aim.SetTargetMode then
            Aim.SetTargetMode(value)
        end
    end
})

AimSection:Toggle({
    Title = "Show FOV",
    Desc = "Show FOV circle",
    Value = false,
    Callback = function(value: boolean)
        if Aim and Aim.SetShowFov then
            Aim.SetShowFov(value)
        end
    end
})

AimSection:Slider({
    Title = "FOV Radius",
    Value = { Min = 50, Max = 300, Default = 120 },
    Callback = function(value: number)
        if Aim and Aim.SetFovRadius then
            Aim.SetFovRadius(value)
        end
    end
})

AimSection:Toggle({
    Title = "Wallcheck",
    Desc = "Aim only at visible targets",
    Value = true,
    Callback = function(value: boolean)
        if Aim and Aim.SetWallcheck then
            Aim.SetWallcheck(value)
        end
    end
})

AimSection:Toggle({
    Title = "Predict Movement",
    Desc = "Predict target movement trajectory",
    Value = true,
    Callback = function(value: boolean)
        if Aim and Aim.SetEnableLead then
            Aim.SetEnableLead(value)
        end
    end
})

AimSection:Slider({
    Title = "Aim Smooth",
    Value = { Min = 0.05, Max = 1.0, Default = 0.25 },
    Callback = function(value: number)
        if Aim and Aim.SetSmooth then
            Aim.SetSmooth(value)
        end
    end
})

local AimVeilSection = AimTab:Section({ Title = "Aim Veil Settings" })

AimVeilSection:Dropdown({
    Title = "Aim Veil",
    Desc = "Select Aim Veil mode",
    Values = { "Disabled", "Silent Aim", "Aim Lock", "Both" },
    Value = "Both",
    Callback = function(value: string)
        if Aim then
            if value == "Disabled" then
                Aim.SetVeilSilentAim(false)
                Aim.SetVeilAimLock(false)
            elseif value == "Silent Aim" then
                Aim.SetVeilSilentAim(true)
                Aim.SetVeilAimLock(false)
            elseif value == "Aim Lock" then
                Aim.SetVeilSilentAim(false)
                Aim.SetVeilAimLock(true)
            elseif value == "Both" then
                Aim.SetVeilSilentAim(true)
                Aim.SetVeilAimLock(true)
            end
        end
    end
})

AimVeilSection:Toggle({
    Title = "Show FOV",
    Desc = "Show FOV circle",
    Value = false,
    Callback = function(value: boolean)
        if Aim and Aim.SetVeilShowFov then
            Aim.SetVeilShowFov(value)
        end
    end
})

AimVeilSection:Slider({
    Title = "FOV Radius",
    Value = { Min = 50, Max = 300, Default = 150 },
    Callback = function(value: number)
        if Aim and Aim.SetVeilFovRadius then
            Aim.SetVeilFovRadius(value)
        end
    end
})

AimVeilSection:Toggle({
    Title = "Predict Movement",
    Desc = "Predict target movement trajectory",
    Value = true,
    Callback = function(value: boolean)
        if Aim and Aim.SetVeilEnableLead then
            Aim.SetVeilEnableLead(value)
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
