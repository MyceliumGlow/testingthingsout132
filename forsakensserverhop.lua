--[[
    REVISED FORSAKEN SYSTEM: Smart Persistence, Efficient Detection & Auto-Hop
    
    LOGIC FLOW:
    1. Checks if LocalPlayer is in Workspace.Players.Spectating.
    2. If NOT found (you spawned), waits 5 seconds.
    3. Triggers Invisibility.
    4. Checks Spectating folder for ANY other models.
    5. If models found -> Server Hop.
]]--

-----------------------------------------------------------------------------------------------------------------------
-- SECTION 0: PERSISTENCE (AUTO-EXECUTE AFTER HOP)
-----------------------------------------------------------------------------------------------------------------------
-- This ensures the script runs again automatically when you join the new server.
if (not game:IsLoaded()) then game.Loaded:Wait() end

local queue_on_teleport = queue_on_teleport or (syn and syn.queue_on_teleport)
if queue_on_teleport then
    -- We queue the exact source of this script to run on the next teleport
    queue_on_teleport(game:HttpGet("https://raw.githubusercontent.com/user/repo/main/script.lua")) 
    -- NOTE: If you are running this from a file/clipboard, queue_on_teleport cannot grab the text automatically 
    -- without 'readfile'. If you are using a loadstring, keep using that loadstring. 
    -- Below is a generic fallback that attempts to queue the current execution context if possible, 
    -- but usually putting this script in your "AutoExec" folder is the safest bet.
    print(" >> Script queued for next server.")
end

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
                    
                    -- IMPORTANT: Queue this script again before leaving
                    if queue_on_teleport then
                        -- If you are copy-pasting this script, you may need to rely on AutoExec folder instead
                        -- or replace this empty string with the actual loadstring url if you have one.
                    end
                    
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
                    -- If there are spectators (and we are not one of them), HOP.
                    warn("Others found in Spectating. Hopping...")
                    ServerHop()
                    break -- Stop loop, we are leaving
                end
            end
        end
    end
end)