--[[
    REVISED FORSAKEN SYSTEM: Efficient Detection & Auto-Hop
    (Queue logic removed - Please place in your AutoExec folder for persistence)
]]--

if (not game:IsLoaded()) then game.Loaded:Wait() end

-----------------------------------------------------------------------------------------------------------------------
-- SERVICES & SETUP
-----------------------------------------------------------------------------------------------------------------------
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local Notify = loadstring(game:HttpGet("https://raw.githubusercontent.com/Gazer-Ha/NOT-MINE/refs/heads/main/AkaliNotify"))()
Notify.Notify({Title="Protocol Started", Description="Waiting for spawn (Leave Spectator)...", Duration=5})

-- Configuration
local animationId = "rbxassetid://75804462760596"
local PlaceID = game.PlaceId
local invisApplied = false

-----------------------------------------------------------------------------------------------------------------------
-- SECTION 1: INVISIBILITY LOGIC
-----------------------------------------------------------------------------------------------------------------------
local function ActivateInvisibility()
    if invisApplied then return end
    
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        local hum = char.Humanoid
        local anim = Instance.new("Animation")
        anim.AnimationId = animationId
        
        local loadedAnim = hum:LoadAnimation(anim)
        if loadedAnim then
            loadedAnim.Priority = Enum.AnimationPriority.Action 
            loadedAnim.Looped = true
            loadedAnim:Play()
            loadedAnim:AdjustSpeed(0) -- Freeze for glitch
            
            invisApplied = true
            Notify.Notify({Title="Action", Description="5s Passed: Invisibility Applied.", Duration=3})
        end
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- SECTION 2: ROBUST SERVER HOPPER
-----------------------------------------------------------------------------------------------------------------------
local function ServerHop()
    Notify.Notify({Title="Server Hopper", Description="Spectators found. Finding new server...", Duration=5})
    
    local AllIDs = {}
    local foundAnything = ""
    local actualHour = os.date("!*t").hour
    
    -- File Safety
    pcall(function()
        if isfile("NotSameServers.json") then
            AllIDs = HttpService:JSONDecode(readfile("NotSameServers.json"))
        else
            table.insert(AllIDs, actualHour)
            writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs))
        end
    end)

    local function TPReturner()
        local Site;
        if foundAnything == "" then
            Site = HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100'))
        else
            Site = HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100&cursor=' .. foundAnything))
        end
        
        if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
            foundAnything = Site.nextPageCursor
        end

        for _, v in pairs(Site.data) do
            local ID = tostring(v.id)
            if tonumber(v.maxPlayers) > tonumber(v.playing) then
                local Possible = true
                for _, Existing in pairs(AllIDs) do
                    if ID == tostring(Existing) then
                        Possible = false
                    end
                end
                
                if Possible then
                    table.insert(AllIDs, ID)
                    writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs))
                    
                    TeleportService:TeleportToPlaceInstance(PlaceID, ID, LocalPlayer)
                    return true
                end
            end
        end
        return false
    end

    -- Try to hop repeatedly
    while task.wait(1) do
        pcall(function()
            TPReturner()
        end)
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- SECTION 3: MAIN MONITOR LOOP (Detections)
-----------------------------------------------------------------------------------------------------------------------

local spectatingPath = Workspace:WaitForChild("Players"):WaitForChild("Spectating")

task.spawn(function()
    while task.wait(1) do
        -- STEP 1: Check if WE are in the Spectating folder
        local myModel = spectatingPath:FindFirstChild(LocalPlayer.Name)
        
        if myModel then
            -- We are spectating (dead or waiting). Reset invis flag.
            invisApplied = false
        else
            -- We are NOT in spectating (We are spawned/Survivors).
            
            -- STEP 2: Wait 5 seconds as requested
            task.wait(5)
            
            -- Verify we are STILL not in spectating (didn't die immediately)
            if not spectatingPath:FindFirstChild(LocalPlayer.Name) then
                
                -- Protocol A: Apply Invisibility
                ActivateInvisibility()
                
                -- Protocol B: Check for Others in Spectating
                local spectators = spectatingPath:GetChildren()
                if #spectators > 0 then
                    warn("Others found in Spectating. Hopping...")
                    ServerHop()
                    break -- Stop loop, we are leaving
                end
            end
        end
    end
end)

