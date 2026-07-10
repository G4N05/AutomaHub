--!strict

local baseUrl = "https://raw.githubusercontent.com/G4N05/AutomaHub/main/"

getgenv().AutomaHubLoaderModule = true

local function fetchScript(path: string): any
    local content
    local source = "unknown"
    if isfile then
        if isfile(path) then
            pcall(function() content = readfile(path) source = "local" end)
        elseif isfile("AutomaHub/" .. path) then
            pcall(function() content = readfile("AutomaHub/" .. path) source = "local (AutomaHub)" end)
        end
    end
    if not content then
        local ok, res = pcall(game.HttpGet, game, baseUrl .. path .. "?t=" .. tostring(tick()))
        if ok and res and not res:find("Too Many Requests") and not res:find("429") then
            content = res
            source = "GitHub"
        else
            warn("[AutomaHub] GitHub fetch failed for " .. path .. ": " .. tostring(res))
        end
    end
    if not content then
        local devCdn = "https://raw.githack.com/G4N05/AutomaHub/main/"
        local ok, res = pcall(game.HttpGet, game, devCdn .. path)
        if ok and res and not res:find("404") then
            content = res
            source = "GitHack (No-Cache)"
        else
            warn("[AutomaHub] GitHack fetch failed for " .. path .. ": " .. tostring(res))
        end
    end
    if not content then
        error("Failed to fetch script: " .. path .. " (local, GitHub, and CDN all failed)")
    end
    print("[AutomaHub] Loaded " .. path .. " from " .. source)
    local func, err = loadstring(content)
    if not func then
        error("Failed to compile script " .. path .. ": " .. tostring(err) .. "\nContent: " .. string.sub(content, 1, 100))
    end
    return func()
end

local successLoader, Loader = pcall(fetchScript, "Load.lua")
if not successLoader then
    error("Failed to load loader UI: " .. tostring(Loader))
end

local L = Loader.new()
L:setStatus("Connecting to AutomaHub...")
L:setProgress(0.2)
task.wait(0.4)

L:setStatus("Fetching menu resources...")
L:setProgress(0.6)

local successGui, errGui = pcall(fetchScript, "AutomaHubGui/Gui.lua")
if not successGui then
    L:setStatus("Error loading GUI!")
    task.wait(1)
    L:destroy()
    error("Failed to load GUI: " .. tostring(errGui))
end

local successMenu, errMenu = pcall(fetchScript, "AutomaHubGui/Menu.lua")
if not successMenu then
    L:setStatus("Error loading menu!")
    task.wait(1)
    L:destroy()
    error("Failed to load menu: " .. tostring(errMenu))
end

L:setStatus("Loaded successfully!")
L:setProgress(1.0)

L:finish()
