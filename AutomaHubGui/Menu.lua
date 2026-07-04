--!strict

local WindUI = getgenv().WindUI

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

-- Init Combat Controls in Combat tab (Mocked/No Logic Sync yet)
Tabs.Combat:Toggle({
    Title = "Auto Parry",
    Desc = "Automatically parry killer attacks",
    Value = false,
    Callback = function(Value: boolean)
        print("Auto Parry toggled:", Value)
    end
})

Tabs.Combat:Slider({
    Title = "Parry Distance",
    Range = {5, 25},
    Value = 9,
    Increment = 1,
    Callback = function(Value: number)
        print("Parry Distance set to:", Value)
    end
})

Tabs.Combat:Slider({
    Title = "Dash Parry Distance",
    Range = {20, 50},
    Value = 30,
    Increment = 1,
    Callback = function(Value: number)
        print("Dash Parry Distance set to:", Value)
    end
})

Tabs.Combat:Toggle({
    Title = "Dodge Hidden (Abyss)",
    Desc = "Automatically dodge Abysswalker skills",
    Value = false,
    Callback = function(Value: boolean)
        print("Dodge Hidden toggled:", Value)
    end
})

Tabs.Combat:Slider({
    Title = "Dodge Distance",
    Range = {15, 35},
    Value = 25,
    Increment = 1,
    Callback = function(Value: number)
        print("Dodge Distance set to:", Value)
    end
})

Tabs.Combat:Toggle({
    Title = "Auto Skillcheck",
    Desc = "Automatically hit perfect skillchecks",
    Value = false,
    Callback = function(Value: boolean)
        print("Auto Skillcheck toggled:", Value)
    end
})

-- Init Visuals Controls in Visuals tab (Mocked/No Logic Sync yet)
Tabs.Visuals:Toggle({
    Title = "Enable ESP",
    Desc = "Master toggle to activate/deactivate ESP",
    Value = false,
    Callback = function(Value: boolean)
        print("Enable ESP toggled:", Value)
    end
})

Tabs.Visuals:Dropdown({
    Title = "Choose ESP",
    Values = { "Player", "Generator", "Pallet", "SCP / Zombie" },
    Value = {},
    Multi = true,
    Callback = function(Value: any)
        print("Choose ESP changed:", table.concat(Value, ", "))
    end
})
