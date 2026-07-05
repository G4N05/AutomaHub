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

-- Aim Tab (Sub-tabs: Aim Veil on the left, Aim Gun on the right)
local AimGunSection = AimTab:Section({ Title = "Aim Gun Settings" })
local AimVeilSection = AimTab:Section({ Title = "Aim Veil Settings" })

-- Placeholder UI elements for the sub-tabs
AimGunSection:Toggle({
    Title = "Silent Aim (Gun)",
    Value = false,
    Callback = function(value: boolean)
        -- No logic yet
    end
})

AimVeilSection:Toggle({
    Title = "Silent Aim (Veil)",
    Value = false,
    Callback = function(value: boolean)
        -- No logic yet
    end
})

-- Helper to toggle Section visibility
local function setSectionVisible(section: any, visible: boolean)
    if not section then return end
    local obj = section.Object or section.Frame or section.Container
    if obj then
        obj.Visible = visible
    end
end

-- Active state
local activeSubTab = "Aim Gun"
local function updateSubTabs()
    setSectionVisible(AimGunSection, activeSubTab == "Aim Gun")
    setSectionVisible(AimVeilSection, activeSubTab == "Aim Veil")
end

local SwitcherSection = AimTab:Section({ Title = "Select Category" })

-- Try to use HStack/Group layout if supported, fallback to vertical buttons
local container = SwitcherSection
pcall(function()
    local stack = SwitcherSection.HStack and SwitcherSection:HStack() or SwitcherSection:Group()
    if stack then container = stack end
end)

container:Button({
    Title = "Aim Veil",
    Callback = function()
        activeSubTab = "Aim Veil"
        updateSubTabs()
    end
})

container:Button({
    Title = "Aim Gun",
    Callback = function()
        activeSubTab = "Aim Gun"
        updateSubTabs()
    end
})

-- Default to Aim Gun and update initial visibility
task.spawn(function()
    task.wait(0.1)
    updateSubTabs()
end)

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
