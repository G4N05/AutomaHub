local WindUI = getgenv().WindUI
local Window = getgenv().Window
if not Window then
    warn("[AutomaHub] Window is not initialized yet!")
    return
end

local Tabs = {
    Theme = Window:Tab({ Title = "Theme", Icon = "palette" })
}

-- Use Theme module to initialize theme tab
local Theme = (function()
    local themeScript = typeof(script) == "Instance" and script.Parent and script.Parent:FindFirstChild("Theme")
    if themeScript then return require(themeScript) end
    
    local hasThemeFile = false
    if isfile then pcall(function() hasThemeFile = isfile("AutomaHubGui/Theme.lua") end) end
    if hasThemeFile and readfile then
        local ok, content = pcall(readfile, "AutomaHubGui/Theme.lua")
        if ok and content then
            local func = loadstring(content)
            if func then return func() end
        end
    end
    
    local ok, res = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/G4N05/AutomaHub/main/AutomaHubGui/Theme.lua")
    return ok and loadstring(res)() or {}
end)()

if Theme.Init then
    Theme.Init(WindUI, Tabs.Theme)
end
