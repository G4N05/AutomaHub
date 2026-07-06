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
local ESP    = Logic and Logic.ESP
local Aim    = Logic and Logic.Aim
local Veil   = Logic and Logic.Veil

-- Create Tabs
local ThemeTab  = Window:Tab({ Title = "Theme",  Icon = "palette" })
local CombatTab = Window:Tab({ Title = "Combat",  Icon = "swords" })
local VisualTab = Window:Tab({ Title = "Visual",  Icon = "eye" })
local AimTab    = Window:Tab({ Title = "Aim",     Icon = "crosshair" })

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

-- ══ Aim Tab ══════════════════════════════════════════════════

-- ──── Section: Aim Gun (Twist of Fate) ────
local AimSection = AimTab:Section({ Title = "Aim Gun  (Twist of Fate)" })

AimSection:Dropdown({
    Title = "Aim Gun",
    Desc  = "Select Aim Gun mode",
    Values = { "Disabled", "Silent Aim", "Aim Lock", "Both" },
    Value  = "Both",
    Callback = function(value: string)
        if not Aim then return end
        Aim.SetSilentAim(value == "Silent Aim" or value == "Both")
        Aim.SetAimLock(value == "Aim Lock" or value == "Both")
    end
})

AimSection:Dropdown({
    Title  = "Aim Target",
    Desc   = "Team to target",
    Values = { "Killer", "Survivor" },
    Value  = "Killer",
    Callback = function(value: string)
        if Aim then Aim.SetTargetMode(value) end
    end
})

AimSection:Toggle({
    Title = "Show FOV",
    Desc  = "Show FOV ring on screen",
    Value = false,
    Callback = function(value: boolean)
        if Aim then Aim.SetShowFov(value) end
    end
})

AimSection:Slider({
    Title = "FOV Radius",
    Value = { Min = 50, Max = 300, Default = 120 },
    Callback = function(value: number)
        if Aim then Aim.SetFovRadius(value) end
    end
})

AimSection:Toggle({
    Title = "Wallcheck",
    Desc  = "Only aim at visible targets",
    Value = true,
    Callback = function(value: boolean)
        if Aim then Aim.SetWallcheck(value) end
    end
})

AimSection:Toggle({
    Title = "Predict Movement",
    Desc  = "Lead target trajectory",
    Value = true,
    Callback = function(value: boolean)
        if Aim then Aim.SetEnableLead(value) end
    end
})

AimSection:Slider({
    Title = "Aim Smooth",
    Value = { Min = 0.05, Max = 1.0, Default = 0.25 },
    Callback = function(value: number)
        if Aim then Aim.SetSmooth(value) end
    end
})

-- ──── Section: Aim Veil (Spear/Ballistic) ────
local VeilSection = AimTab:Section({ Title = "Aim Veil  (Spear / Ballistic)" })

VeilSection:Dropdown({
    Title  = "Aim Veil",
    Desc   = "Select Veil aim mode",
    Values = { "Disabled", "Silent Aim", "Aim Lock", "Both" },
    Value  = "Both",
    Callback = function(value: string)
        if not Veil then return end
        Veil.SetSilentAim(value == "Silent Aim" or value == "Both")
        Veil.SetAimLock(value == "Aim Lock" or value == "Both")
    end
})

VeilSection:Toggle({
    Title = "Show FOV",
    Desc  = "Show Veil FOV ring on screen",
    Value = false,
    Callback = function(value: boolean)
        if Veil then Veil.SetShowFov(value) end
    end
})

VeilSection:Slider({
    Title = "FOV Radius",
    Value = { Min = 50, Max = 400, Default = 150 },
    Callback = function(value: number)
        if Veil then Veil.SetFovRadius(value) end
    end
})

VeilSection:Toggle({
    Title = "Predict Movement",
    Desc  = "Lead spear trajectory based on distance offset",
    Value = true,
    Callback = function(value: boolean)
        if Veil then Veil.SetEnableLead(value) end
    end
})

-- ──── Section: Veil Offset Setting ────
-- Offsets: { dist=studs, offset=lead_mult }
-- Preset 1: close (~40 studs), Preset 2: mid (~60), Preset 3: far (~80)
local OffsetSection = AimTab:Section({ Title = "Veil Offset Setting" })

OffsetSection:Slider({
    Title = "Close Range Offset (40 studs)",
    Desc  = "Lead multiplier for close range",
    Value = { Min = 0.5, Max = 3.0, Default = 1.9 },
    Callback = function(value: number)
        if Veil then Veil.SetOffset(1, 40, value) end
    end
})

OffsetSection:Slider({
    Title = "Mid Range Offset (60 studs)",
    Desc  = "Lead multiplier for mid range",
    Value = { Min = 0.5, Max = 3.0, Default = 1.4 },
    Callback = function(value: number)
        if Veil then Veil.SetOffset(2, 60, value) end
    end
})

OffsetSection:Slider({
    Title = "Far Range Offset (80 studs)",
    Desc  = "Lead multiplier for far range",
    Value = { Min = 0.5, Max = 3.0, Default = 1.0 },
    Callback = function(value: number)
        if Veil then Veil.SetOffset(3, 80, value) end
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
