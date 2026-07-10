--!strict

local HttpService = game:GetService("HttpService")
local REPOSITORY = "G4N05/AutomaHub"
local BRANCH = "main"

getgenv().AutomaHubLoaderModule = true

local function isValidResponse(response: any): boolean
    return type(response) == "string"
        and #response > 0
        and not response:find("Too Many Requests", 1, true)
        and not response:find("429", 1, true)
        and not response:find("404: Not Found", 1, true)
end

-- Resolve main to an immutable commit. This avoids stale ISP/jsDelivr caches after a push.
local function getLatestCommit(): string?
    local nonce = tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
    local apiUrl = "https://api.github.com/repos/" .. REPOSITORY .. "/commits/" .. BRANCH .. "?cache=" .. nonce
    local ok, response = pcall(game.HttpGet, game, apiUrl)
    if not ok or not isValidResponse(response) then
        return nil
    end

    local decodedOk, data = pcall(HttpService.JSONDecode, HttpService, response)
    if decodedOk and type(data) == "table" and type(data.sha) == "string" then
        return data.sha
    end
    return nil
end

local commit = getLatestCommit()
getgenv().AutomaHubCommit = commit or BRANCH

local function tryHttp(url: string): string?
    local ok, response = pcall(game.HttpGet, game, url)
    if ok and isValidResponse(response) then
        return response
    end
    return nil
end

local function fetchScript(path: string): any
    local content: string? = nil

    -- Local files are only used intentionally in developer mode. Previously,
    -- stale executor files could silently override newly pushed GitHub files.
    if _G.AutomaHubDeveloperMode and isfile and readfile then
        for _, localPath in ipairs({ path, "AutomaHub/" .. path }) do
            if isfile(localPath) then
                local ok, result = pcall(readfile, localPath)
                if ok and isValidResponse(result) then
                    content = result
                    break
                end
            end
        end
    end

    if not content then
        local nonce = tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
        local urls = {}

        if commit then
            table.insert(urls, "https://raw.githubusercontent.com/" .. REPOSITORY .. "/" .. commit .. "/" .. path)
            table.insert(urls, "https://cdn.jsdelivr.net/gh/" .. REPOSITORY .. "@" .. commit .. "/" .. path)
        end

        table.insert(urls, "https://raw.githubusercontent.com/" .. REPOSITORY .. "/" .. BRANCH .. "/" .. path .. "?cache=" .. nonce)

        for _, url in ipairs(urls) do
            content = tryHttp(url)
            if content then break end
        end
    end

    if not content then
        error("Failed to fetch latest script: " .. path)
    end

    local func, compileError = loadstring(content)
    if not func then
        error("Failed to compile " .. path .. ": " .. tostring(compileError))
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

L:setStatus("Fetching latest menu resources...")
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

L:setStatus("Loaded latest version!")
L:setProgress(1.0)
L:finish()
