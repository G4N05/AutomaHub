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
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "swords" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
    Aim = Window:AddTab({ Title = "Aim", Icon = "crosshair" })
}

-- Init Theme in Main tab
if Theme and typeof(Theme) == "table" and typeof(Theme.Init) == "function" then
    Theme.Init(Fluent, Tabs.Main)
else
    warn("[AutomaHub] Failed to load Theme module!")
end

-- Init Combat Controls in Combat tab
local Combat = Logic and Logic.Combat
if Combat then
    Tabs.Combat:AddToggle("AutoParryToggle", {
        Title = "Auto Parry",
        Description = "Automatically parry killer attacks",
        Default = false,
        Callback = function(Value: boolean)
            Combat.SetAutoParry(Value)
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
            Combat.SetParryDistance(math.floor(Value))
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
            Combat.SetDashParryDistance(math.floor(Value))
        end
    })

    Tabs.Combat:AddToggle("AutoDodgeAbyssToggle", {
        Title = "Dodge Hidden (Abyss)",
        Description = "Automatically dodge Abysswalker skills",
        Default = false,
        Callback = function(Value: boolean)
            Combat.SetAutoDodgeAbyss(Value)
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
            Combat.SetDodgeDistance(math.floor(Value))
        end
    })

    Tabs.Combat:AddToggle("AutoSkillcheckToggle", {
        Title = "Auto Skillcheck",
        Description = "Automatically hit perfect skillchecks",
        Default = false,
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
    Tabs.Visuals:AddToggle("ESPMasterToggle", {
        Title = "Enable ESP",
        Description = "Master toggle to activate/deactivate ESP",
        Default = false,
        Callback = function(Value: boolean)
            ESP.SetMasterEnabled(Value)
        end
    })

    Tabs.Visuals:AddDropdown("ESPSelection", {
        Title = "Choose ESP",
        Description = "Select target ESP types to display",
        Values = { "Player", "Generator", "Pallet", "SCP / Zombie" },
        Multi = true,
        Default = {},
        Callback = function(Value: any)
            ESP.SetSelectedKinds(Value)
        end
    })
else
    warn("[AutomaHub] Failed to load ESP module!")
end

-- =====================================================================
-- Init Aim Controls in Aim tab (GunAim + VeilAim sections)
-- =====================================================================
local GunAim = Logic and Logic.GunAim
local VeilAim = Logic and Logic.VeilAim

if GunAim then
    -- ── GunAim Section ──
    Tabs.Aim:AddSection("GunAim")

    Tabs.Aim:AddToggle("GunAimLockToggle", {
        Title = "Aim Lock",
        Description = "Lock camera to target while holding gun",
        Default = false,
        Callback = function(Value: boolean)
            GunAim.SetAimLock(Value)
        end
    })

    Tabs.Aim:AddToggle("GunSilentAimToggle", {
        Title = "Silent Aim",
        Description = "Redirect bullets to target (server-side)",
        Default = false,
        Callback = function(Value: boolean)
            GunAim.SetSilentAim(Value)
        end
    })

    Tabs.Aim:AddToggle("GunShowPovToggle", {
        Title = "Show POV",
        Description = "Show FOV circle on screen",
        Default = false,
        Callback = function(Value: boolean)
            GunAim.SetShowPov(Value)
        end
    })

    Tabs.Aim:AddSlider("GunAimOffset", {
        Title = "Aim Offset",
        Description = "Vertical offset for aim point",
        Default = 0,
        Min = -5,
        Max = 5,
        Rounding = 1,
        Suffix = "",
        Callback = function(Value: number)
            GunAim.SetAimOffset(Value)
        end
    })

    Tabs.Aim:AddSlider("GunPovSize", {
        Title = "POV Size",
        Description = "FOV circle radius (pixels)",
        Default = 120,
        Min = 10,
        Max = 500,
        Rounding = 0,
        Suffix = "px",
        Callback = function(Value: number)
            GunAim.SetPovSize(math.floor(Value))
        end
    })
else
    warn("[AutomaHub] Failed to load GunAim module!")
end

if VeilAim then
    -- ── VeilAim Section ──
    Tabs.Aim:AddSection("VeilAim")

    Tabs.Aim:AddToggle("VeilAimLockToggle", {
        Title = "Aim Lock",
        Description = "Lock camera to target while in throw stance",
        Default = false,
        Callback = function(Value: boolean)
            VeilAim.SetAimLock(Value)
        end
    })

    Tabs.Aim:AddToggle("VeilSilentAimToggle", {
        Title = "Silent Aim",
        Description = "Redirect spear to target (server-side)",
        Default = false,
        Callback = function(Value: boolean)
            VeilAim.SetSilentAim(Value)
        end
    })

    Tabs.Aim:AddToggle("VeilShowPovToggle", {
        Title = "Show POV",
        Description = "Show FOV circle on screen",
        Default = false,
        Callback = function(Value: boolean)
            VeilAim.SetShowPov(Value)
        end
    })

    Tabs.Aim:AddSlider("VeilAimOffset", {
        Title = "Aim Offset",
        Description = "Vertical offset for aim point",
        Default = 0,
        Min = -5,
        Max = 5,
        Rounding = 1,
        Suffix = "",
        Callback = function(Value: number)
            VeilAim.SetAimOffset(Value)
        end
    })

    Tabs.Aim:AddSlider("VeilPovSize", {
        Title = "POV Size",
        Description = "FOV circle radius (pixels)",
        Default = 150,
        Min = 10,
        Max = 500,
        Rounding = 0,
        Suffix = "px",
        Callback = function(Value: number)
            VeilAim.SetPovSize(math.floor(Value))
        end
    })

    -- ── Veil Distance Offset Sliders ──
    Tabs.Aim:AddSection("Veil Distance Offsets")

    local veilOffsetSliders: { any } = {}

    local function rebuildVeilOffsetSliders()
        -- ponytail: remove old slider UI elements
        for _, s in ipairs(veilOffsetSliders) do
            pcall(function() s:Destroy() end)
        end
        table.clear(veilOffsetSliders)

        local offsets = VeilAim.GetDistOffsets()
        for i, entry in ipairs(offsets) do
            local distSlider = Tabs.Aim:AddSlider("VeilDistSlider_" .. i, {
                Title = "Distance #" .. i .. " (" .. entry.dist .. "u)",
                Description = "Lead offset multiplier at " .. entry.dist .. " studs",
                Default = entry.offset,
                Min = 0,
                Max = 5,
                Rounding = 1,
                Suffix = "x",
                Callback = function(Value: number)
                    VeilAim.SetDistOffset(i, entry.dist, Value)
                end
            })
            table.insert(veilOffsetSliders, distSlider)
        end
    end

    rebuildVeilOffsetSliders()

    Tabs.Aim:AddButton({
        Title = "+ Add Offset Entry",
        Description = "Add a new distance offset entry",
        Callback = function()
            VeilAim.AddDistOffset(100, 0.8)
            rebuildVeilOffsetSliders()
        end
    })

    Tabs.Aim:AddButton({
        Title = "- Remove Last Entry",
        Description = "Remove the last distance offset entry",
        Callback = function()
            local offsets = VeilAim.GetDistOffsets()
            if #offsets > 1 then
                VeilAim.RemoveDistOffset(#offsets)
                rebuildVeilOffsetSliders()
            end
        end
    })
else
    warn("[AutomaHub] Failed to load VeilAim module!")
end

