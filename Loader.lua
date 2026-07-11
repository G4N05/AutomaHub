--!strict

local baseUrl = "https://raw.githubusercontent.com/G4N05/AutomaHub/main/"

getgenv().AutomaHubLoaderModule = true

local function fetchScript(path: string): any
    local content
    if _G.AutomaHubDeveloperMode and typeof(isfile) == "function" and typeof(readfile) == "function" then
        if isfile(path) then
            pcall(function() content = readfile(path) end)
        elseif isfile("AutomaHub/" .. path) then
            pcall(function() content = readfile("AutomaHub/" .. path) end)
        end
    end

    if not content then
        local ok, res = pcall(game.HttpGet, game, baseUrl .. path .. "?t=" .. tostring(tick()))
        if ok and res and not res:find("Too Many Requests") and not res:find("429") and not res:find("Not Found") and not res:find("404") then
            content = res
        end
    end

    -- ponytail: live proxy fallback (raw.githack) to bypass jsdelivr's 12-24h cache when GitHub returns 429
    if not content then
        local githackUrl = "https://raw.githack.com/G4N05/AutomaHub/main/"
        local ok, res = pcall(game.HttpGet, game, githackUrl .. path .. "?t=" .. tostring(tick()))
        if ok and res and not res:find("Too Many Requests") and not res:find("429") and not res:find("Not Found") and not res:find("404") then
            content = res
        end
    end

    if not content then
        local ghproxyUrl = "https://ghproxy.net/https://raw.githubusercontent.com/G4N05/AutomaHub/main/"
        local ok, res = pcall(game.HttpGet, game, ghproxyUrl .. path .. "?t=" .. tostring(tick()))
        if ok and res and not res:find("Too Many Requests") and not res:find("429") and not res:find("Not Found") and not res:find("404") then
            content = res
        end
    end

    if not content then
        local cdnUrl = "https://cdn.jsdelivr.net/gh/G4N05/AutomaHub@main/"
        local ok, res = pcall(game.HttpGet, game, cdnUrl .. path .. "?t=" .. tostring(tick()))
        if ok and res and not res:find("Not Found") and not res:find("404") then
            content = res
        end
    end

    if not content then
        error("Failed to fetch script: " .. path .. " (local, GitHub, and all CDN mirrors failed)")
    end

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
