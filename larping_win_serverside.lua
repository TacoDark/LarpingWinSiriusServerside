--[[

larping.win | serverside
Version 1.0

Based on Sirius by SiriusSoftwareLtd
© 2024 Sirius — Original Source
larping.win modifications © 2026

--]]

--[[
Usage:
    require(ID_HERE)("USERNAME_HERE")
    e.g.: require(12345678)("PlayerName")
--]]

-- host ts yourself if u want on git or roblos

-- Ensure the game is loaded
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Module/require pattern: return a function that accepts a username
local larpingWin = {}

local function init(targetUser)

-- ====================== SERVICES ======================
local coreGui = game:GetService("CoreGui")
local httpService = game:GetService("HttpService")
local lighting = game:GetService("Lighting")
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local guiService = game:GetService("GuiService")
local statsService = game:GetService("Stats")
local starterGui = game:GetService("StarterGui")
local teleportService = game:GetService("TeleportService")
local tweenService = game:GetService("TweenService")
local userInputService = game:GetService('UserInputService')
local gameSettings = UserSettings():GetService("UserGameSettings")

-- ====================== VARIABLES ======================
local camera = workspace.CurrentCamera
local getMessage = replicatedStorage:WaitForChild("DefaultChatSystemChatEvents", 1) and replicatedStorage.DefaultChatSystemChatEvents:WaitForChild("OnMessageDoneFiltering", 1)

-- Resolve the target player
-- On serverside: the username passed to require(id)("username") is who the GUI runs FOR.
-- Their PlayerGui is where we parent the interface so it appears on THEIR screen.
local localPlayer
if targetUser and targetUser ~= "" then
    localPlayer = players:FindFirstChild(targetUser)
    if not localPlayer then
        -- Player not in server — bail out cleanly
        warn("[larping.win] Player '" .. tostring(targetUser) .. "' was not found in the server. Aborting.")
        -- Try to show a quick notification to whoever ran it via a hint in workspace
        local hint = Instance.new("Hint", workspace)
        hint.Text = "[larping.win] Player '" .. tostring(targetUser) .. "' not found in server."
        game:GetService("Debris"):AddItem(hint, 5)
        return
    end
else
    -- No username given — default to LocalPlayer (client-side use)
    localPlayer = players.LocalPlayer
end

local notifications = {}
local friendsCooldown = 0
-- GetMouse() returns mouse input for whichever player context is running this.
-- On serverside the executing context IS the target player's client, so this is correct.
local mouse = localPlayer:GetMouse()
local promptedDisconnected = false
local smartBarOpen = false
local debounce = false
local searchingForPlayer = false
local musicQueue = {}
local currentAudio
local lowerName = localPlayer.Name:lower()
local lowerDisplayName = localPlayer.DisplayName:lower()
local placeId = game.PlaceId
local jobId = game.JobId
local checkingForKey = false
local originalTextValues = {}
local creatorId = game.CreatorId
local noclipDefaults = {}
local movers = {}
local creatorType = game.CreatorType
local espContainer = Instance.new("Folder", gethui and gethui() or coreGui)
local oldVolume = gameSettings.MasterVolume
local Pro = true -- Open sourced

-- ====================== CORE CONFIG ======================
local larpingValues = {
    version = "1.0",
    name = "larping.win | serverside",
    releaseType = "Stable",
    folder = "LarpingWin",
    settingsFile = "settings.lws",
    interfaceAsset = 14183548964, -- Reusing Sirius asset
    cdn = "https://cdn.sirius.menu/SIRIUS-SCRIPT-CORE-ASSETS/",
    icons = "https://cdn.sirius.menu/SIRIUS-SCRIPT-CORE-ASSETS/Icons/",
    enableExperienceSync = false,

    -- Serverside scripts list (user-configurable)
    -- Each entry: { name, execFunc, dangerous, requiresArg, argPrompt }
    --   execFunc(arg) — arg will be nil if requiresArg is false
    serversideScripts = {
        {
            name = "Script Logger",
            dangerous = false,
            requiresArg = true,
            argPrompt = "Enter the target username to log:",
            execFunc = function(arg)
                require(120869500317355)(arg)
            end,
        },
        {
            name = "IY Admin Aureus Port",
            dangerous = false,
            requiresArg = true,
            argPrompt = "Enter the target username for IY Admin:",
            execFunc = function(arg)
                require(125907588661544)(arg)
            end,
        },
        {
            name = "Anti Ban",
            dangerous = true,
            requiresArg = false,
            execFunc = function()
                require(4820862445).load("imagine trying to ban me")
            end,
        },
        {
            name = "Custom Chat",
            dangerous = false,
            requiresArg = false,
            execFunc = function()
                require(90460703988237):load()
            end,
        },
    },

    executors = {"synapse x", "script-ware", "krnl", "scriptware", "comet", "valyse", "fluxus", "electron", "hydrogen"},
    disconnectTypes = { {"ban", {"ban", "perm"}}, {"network", {"internet connection", "network"}} },
    nameGeneration = {
        adjectives = {"Cool", "Awesome", "Epic", "Ninja", "Super", "Mystic", "Swift", "Golden", "Diamond", "Silver", "Mint", "Roblox", "Amazing"},
        nouns = {"Player", "Gamer", "Master", "Legend", "Hero", "Ninja", "Wizard", "Champion", "Warrior", "Sorcerer"}
    },
    administratorRoles = {"mod","admin","staff","dev","founder","owner","supervis","manager","management","executive","president","chairman","chairwoman","chairperson","director"},
    transparencyProperties = {
        UIStroke = {'Transparency'},
        Frame = {'BackgroundTransparency'},
        TextButton = {'BackgroundTransparency', 'TextTransparency'},
        TextLabel = {'BackgroundTransparency', 'TextTransparency'},
        TextBox = {'BackgroundTransparency', 'TextTransparency'},
        ImageLabel = {'BackgroundTransparency', 'ImageTransparency'},
        ImageButton = {'BackgroundTransparency', 'ImageTransparency'},
        ScrollingFrame = {'BackgroundTransparency', 'ScrollBarImageTransparency'}
    },
    buttonPositions = {Character = UDim2.new(0.5, -155, 1, -29), Serverside = UDim2.new(0.5, -122, 1, -29), Playerlist = UDim2.new(0.5, -68, 1, -29)},
    chatSpy = {
        enabled = true,
        visual = {
            Color = Color3.fromRGB(26, 148, 255),
            Font = Enum.Font.SourceSansBold,
            TextSize = 18
        },
    },
    pingProfile = {
        recentPings = {},
        adaptiveBaselinePings = {},
        pingNotificationCooldown = 0,
        maxSamples = 12,
        spikeThreshold = 1.75,
        adaptiveBaselineSamples = 30,
        adaptiveHighPingThreshold = 120
    },
    frameProfile = {
        frameNotificationCooldown = 0,
        fpsQueueSize = 10,
        lowFPSThreshold = 20,
        totalFPS = 0,
        fpsQueue = {},
    },
    actions = {
        {
            name = "Noclip",
            images = {14385986465, 9134787693},
            color = Color3.fromRGB(0, 170, 127),
            enabled = false,
            rotateWhileEnabled = false,
            callback = function() end,
        },
        {
            name = "Flight",
            images = {9134755504, 14385992605},
            color = Color3.fromRGB(170, 37, 46),
            enabled = false,
            rotateWhileEnabled = false,
            callback = function(value)
                local character = localPlayer.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.PlatformStand = value
                end
            end,
        },
        {
            name = "Refresh",
            images = {9134761478, 9134761478},
            color = Color3.fromRGB(61, 179, 98),
            enabled = false,
            rotateWhileEnabled = true,
            disableAfter = 3,
            callback = function()
                task.spawn(function()
                    local character = localPlayer.Character
                    if character then
                        local cframe = character:GetPivot()
                        local humanoid = character:FindFirstChildOfClass("Humanoid")
                        if humanoid then
                            humanoid:ChangeState(Enum.HumanoidStateType.Dead)
                        end
                        character = localPlayer.CharacterAdded:Wait()
                        task.defer(character.PivotTo, character, cframe)
                    end
                end)
            end,
        },
        {
            name = "Respawn",
            images = {9134762943, 9134762943},
            color = Color3.fromRGB(49, 88, 193),
            enabled = false,
            rotateWhileEnabled = true,
            disableAfter = 2,
            callback = function()
                local character = localPlayer.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid:ChangeState(Enum.HumanoidStateType.Dead)
                end
            end,
        },
        {
            name = "Invulnerability",
            images = {9134765994, 14386216487},
            color = Color3.fromRGB(193, 46, 90),
            enabled = false,
            rotateWhileEnabled = false,
            callback = function(value)
                local character = localPlayer.Character
                if character then
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        if value then
                            -- Hook health changes to prevent death
                            humanoid:GetPropertyChangedSignal("Health"):Connect(function()
                                if larpingValues.actions[5].enabled then
                                    humanoid.Health = humanoid.MaxHealth
                                end
                            end)
                        end
                    end
                end
            end,
        },
        {
            name = "Fling",
            images = {9134785384, 14386226155},
            color = Color3.fromRGB(184, 85, 61),
            enabled = false,
            rotateWhileEnabled = true,
            callback = function(value)
                local character = localPlayer.Character
                local primaryPart = character and character.PrimaryPart
                if primaryPart then
                    for _, part in ipairs(character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.Massless = value
                            part.CustomPhysicalProperties = PhysicalProperties.new(value and math.huge or 0.7, 0.3, 0.5)
                        end
                    end

                    primaryPart.Anchored = true
                    primaryPart.AssemblyLinearVelocity = Vector3.zero
                    primaryPart.AssemblyAngularVelocity = Vector3.zero

                    movers[3] = movers[3] or Instance.new("BodyAngularVelocity")
                    movers[3].Parent = value and primaryPart or nil

                    task.delay(0.5, function() primaryPart.Anchored = false end)
                end
            end,
        },
        {
            name = "Extrasensory Perception",
            images = {9134780101, 14386232387},
            color = Color3.fromRGB(214, 182, 19),
            enabled = false,
            rotateWhileEnabled = false,
            callback = function(value)
                for _, highlight in ipairs(espContainer:GetChildren()) do
                    highlight.Enabled = value
                end
            end,
        },
        {
            name = "Night and Day",
            images = {9134778004, 10137794784},
            color = Color3.fromRGB(102, 75, 190),
            enabled = false,
            rotateWhileEnabled = false,
            callback = function(value)
                tweenService:Create(lighting, TweenInfo.new(0.5), { ClockTime = value and 12 or 24 }):Play()
            end,
        },
        {
            name = "Global Audio",
            images = {9134774810, 14386246782},
            color = Color3.fromRGB(202, 103, 58),
            enabled = false,
            rotateWhileEnabled = false,
            callback = function(value)
                if value then
                    oldVolume = gameSettings.MasterVolume
                    gameSettings.MasterVolume = 0
                else
                    gameSettings.MasterVolume = oldVolume
                end
            end,
        },
        {
            name = "Visibility",
            images = {14386256326, 9134770786},
            color = Color3.fromRGB(62, 94, 170),
            enabled = false,
            rotateWhileEnabled = false,
            callback = function(value)
                local character = localPlayer.Character
                if character then
                    for _, part in ipairs(character:GetDescendants()) do
                        if part:IsA("BasePart") or part:IsA("Decal") then
                            if part:IsA("BasePart") then
                                part.Transparency = value and 1 or 0
                            elseif part:IsA("Decal") then
                                part.Transparency = value and 1 or 0
                            end
                        end
                    end
                end
            end,
        },
    },
    sliders = {
        {
            name = "player speed",
            color = Color3.fromRGB(44, 153, 93),
            values = {0, 300},
            default = 16,
            value = 16,
            active = false,
            callback = function(value)
                local character = localPlayer.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.WalkSpeed = value
                end
            end,
        },
        {
            name = "jump power",
            color = Color3.fromRGB(59, 126, 184),
            values = {0, 350},
            default = 50,
            value = 50,
            active = false,
            callback = function(value)
                local character = localPlayer.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    if humanoid.UseJumpPower then
                        humanoid.JumpPower = value
                    else
                        humanoid.JumpHeight = value
                    end
                end
            end,
        },
        {
            name = "flight speed",
            color = Color3.fromRGB(177, 45, 45),
            values = {1, 25},
            default = 3,
            value = 3,
            active = false,
            callback = function(value) end,
        },
        {
            name = "field of view",
            color = Color3.fromRGB(198, 178, 75),
            values = {45, 120},
            default = 70,
            value = 70,
            active = false,
            callback = function(value)
                tweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), { FieldOfView = value }):Play()
            end,
        },
    }
}

local larpingSettings = {
    {
        name = 'General',
        description = 'General settings for larping.win.',
        color = Color3.new(0.117647, 0.490196, 0.72549),
        minimumLicense = 'Free',
        categorySettings = {
            {
                name = 'Anonymous Client',
                description = 'Randomise your username in real-time in any CoreGui parented interface. You will still appear as your actual name to others in-game.',
                settingType = 'Boolean',
                current = false,
                id = 'anonmode'
            },
            {
                name = 'Chat Spy',
                description = 'Displays whispers hidden from you in the legacy chat box.',
                settingType = 'Boolean',
                current = true,
                id = 'chatspy'
            },
            {
                name = 'Hide Toggle Button',
                description = 'Remove the toggle button for the smartBar.',
                settingType = 'Boolean',
                current = false,
                id = 'hidetoggle'
            },
            {
                name = 'Now Playing Notifications',
                description = 'Notify you when the next song in your Music queue plays.',
                settingType = 'Boolean',
                current = true,
                id = 'nowplaying'
            },
            {
                name = 'Friend Notifications',
                settingType = 'Boolean',
                current = true,
                id = 'friendnotifs'
            },
            {
                name = 'Load Hidden',
                settingType = 'Boolean',
                current = false,
                id = 'loadhidden'
            },
            {
                name = 'Startup Sound Effect',
                settingType = 'Boolean',
                current = true,
                id = 'startupsound'
            },
            {
                name = 'Anti Idle',
                description = 'Remove all callbacks linked to the LocalPlayer Idled state.',
                settingType = 'Boolean',
                current = true,
                id = 'antiidle'
            },
            {
                name = 'Client-Based Anti Kick',
                description = 'Cancel any kick request involving you sent by the client.',
                settingType = 'Boolean',
                current = false,
                id = 'antikick'
            },
            {
                name = 'Muffle audio while unfocused',
                settingType = 'Boolean',
                current = true,
                id = 'muffleunfocused'
            },
        }
    },
    {
        name = 'Keybinds',
        description = 'Assign keybinds to actions.',
        color = Color3.new(0.0941176, 0.686275, 0.509804),
        minimumLicense = 'Free',
        categorySettings = {
            {
                name = 'Toggle smartBar',
                settingType = 'Key',
                current = "K",
                id = 'smartbar'
            },
            {
                name = 'Open ScriptSearch',
                settingType = 'Key',
                current = "T",
                id = 'scriptsearch'
            },
            {
                name = 'NoClip',
                settingType = 'Key',
                current = nil,
                id = 'noclip',
                callback = function()
                    local noclip = larpingValues.actions[1]
                    noclip.enabled = not noclip.enabled
                    noclip.callback(noclip.enabled)
                end
            },
            {
                name = 'Flight',
                settingType = 'Key',
                current = nil,
                id = 'flight',
                callback = function()
                    local flight = larpingValues.actions[2]
                    flight.enabled = not flight.enabled
                    flight.callback(flight.enabled)
                end
            },
            {
                name = 'Refresh',
                settingType = 'Key',
                current = nil,
                id = 'refresh',
                callback = function()
                    local refresh = larpingValues.actions[3]
                    if not refresh.enabled then
                        refresh.enabled = true
                        refresh.callback()
                    end
                end
            },
            {
                name = 'Respawn',
                settingType = 'Key',
                current = nil,
                id = 'respawn',
                callback = function()
                    local respawn = larpingValues.actions[4]
                    if not respawn.enabled then
                        respawn.enabled = true
                        respawn.callback()
                    end
                end
            },
            {
                name = 'Invulnerability',
                settingType = 'Key',
                current = nil,
                id = 'invulnerability',
                callback = function()
                    local inv = larpingValues.actions[5]
                    inv.enabled = not inv.enabled
                    inv.callback(inv.enabled)
                end
            },
            {
                name = 'Fling',
                settingType = 'Key',
                current = nil,
                id = 'fling',
                callback = function()
                    local fling = larpingValues.actions[6]
                    fling.enabled = not fling.enabled
                    fling.callback(fling.enabled)
                end
            },
            {
                name = 'ESP',
                settingType = 'Key',
                current = nil,
                id = 'esp',
                callback = function()
                    local esp = larpingValues.actions[7]
                    esp.enabled = not esp.enabled
                    esp.callback(esp.enabled)
                end
            },
            {
                name = 'Night and Day',
                settingType = 'Key',
                current = nil,
                id = 'nightandday',
                callback = function()
                    local nad = larpingValues.actions[8]
                    nad.enabled = not nad.enabled
                    nad.callback(nad.enabled)
                end
            },
            {
                name = 'Global Audio',
                settingType = 'Key',
                current = nil,
                id = 'globalaudio',
                callback = function()
                    local ga = larpingValues.actions[9]
                    ga.enabled = not ga.enabled
                    ga.callback(ga.enabled)
                end
            },
            {
                name = 'Visibility',
                settingType = 'Key',
                current = nil,
                id = 'visibility',
                callback = function()
                    local vis = larpingValues.actions[10]
                    vis.enabled = not vis.enabled
                    vis.callback(vis.enabled)
                end
            },
        }
    },
    {
        name = 'Performance',
        description = 'Tweak performance settings.',
        color = Color3.new(1, 0.376471, 0.168627),
        minimumLicense = 'Free',
        categorySettings = {
            {
                name = 'Artificial FPS Limit',
                description = 'Set your FPS limit when tabbed-in.',
                settingType = 'Number',
                values = {20, 5000},
                current = 240,
                id = 'fpscap'
            },
            {
                name = 'Limit FPS while unfocused',
                description = 'Set FPS to 60 when tabbed-out.',
                settingType = 'Boolean',
                current = true,
                id = 'fpsunfocused'
            },
            {
                name = 'Adaptive Latency Warning',
                description = 'Notify you when latency spikes above your average.',
                settingType = 'Boolean',
                current = true,
                id = 'latencynotif'
            },
            {
                name = 'Adaptive Performance Warning',
                description = 'Notify you when FPS drops below threshold.',
                settingType = 'Boolean',
                current = true,
                id = 'fpsnotif'
            },
        }
    },
    {
        name = 'Detections',
        description = 'Detect and prevent harmful actions.',
        color = Color3.new(0.705882, 0, 0),
        minimumLicense = 'Free',
        categorySettings = {
            {
                name = 'Spatial Shield',
                description = 'Suppress loud sounds played in-game.',
                settingType = 'Boolean',
                minimumLicense = 'Pro',
                current = true,
                id = 'spatialshield'
            },
            {
                name = 'Spatial Shield Threshold',
                description = 'How loud a sound needs to be to be suppressed.',
                settingType = 'Number',
                minimumLicense = 'Pro',
                values = {100, 1000},
                current = 300,
                id = 'spatialshieldthreshold'
            },
            {
                name = 'Moderator Detection',
                description = 'Notify you when a potential moderator joins your session.',
                settingType = 'Boolean',
                minimumLicense = 'Pro',
                current = true,
                id = 'moddetection'
            },
        },
    },
    {
        name = 'Logging',
        description = 'Send logs to your Discord webhook.',
        color = Color3.new(0.905882, 0.780392, 0.0666667),
        minimumLicense = 'Free',
        categorySettings = {
            {
                name = 'Log Messages',
                description = 'Log messages to your webhook.',
                settingType = 'Boolean',
                current = false,
                id = 'logmsg'
            },
            {
                name = 'Message Webhook URL',
                description = 'Discord Webhook URL',
                settingType = 'Input',
                current = 'No Webhook',
                id = 'logmsgurl'
            },
            {
                name = 'Log PlayerAdded and PlayerRemoving',
                description = 'Log whenever any player leaves or joins.',
                settingType = 'Boolean',
                current = false,
                id = 'logplrjoinleave'
            },
            {
                name = 'Player Added and Removing Webhook URL',
                description = 'Discord Webhook URL',
                settingType = 'Input',
                current = 'No Webhook',
                id = 'logplrjoinleaveurl'
            },
        }
    },
}

-- ====================== RANDOM USERNAME ======================
local randomAdjective = larpingValues.nameGeneration.adjectives[math.random(1, #larpingValues.nameGeneration.adjectives)]
local randomNoun = larpingValues.nameGeneration.nouns[math.random(1, #larpingValues.nameGeneration.nouns)]
local randomNumber = math.random(100, 3999)
local randomUsername = randomAdjective .. randomNoun .. randomNumber

-- ====================== UI INITIALISATION ======================
-- Parent to the target player's PlayerGui so the interface appears ON THEIR SCREEN.
-- Falls back to CoreGui / gethui if PlayerGui is unavailable.
local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
local guiParent = playerGui or (gethui and gethui() or coreGui)

-- Remove any existing instance from that player's GUI
local existingUI = guiParent:FindFirstChild("LarpingWin")
if existingUI then existingUI:Destroy() end

-- Reuse Sirius asset (same interface base)
local UI = game:GetObjects('rbxassetid://'..larpingValues.interfaceAsset)[1]
UI.Name = "LarpingWin"
UI.Parent = guiParent
UI.Enabled = false

-- ====================== UI ELEMENT REFERENCES ======================
local characterPanel = UI.Character
local customScriptPrompt = UI.CustomScriptPrompt
local securityPrompt = UI.SecurityPrompt
local disconnectedPrompt = UI.Disconnected
local gameDetectionPrompt = UI.GameDetection
local homeContainer = UI.Home
local moderatorDetectionPrompt = UI.ModeratorDetectionPrompt
local musicPanel = UI.Music
local notificationContainer = UI.Notifications
local playerlistPanel = UI.Playerlist
local scriptSearch = UI.ScriptSearch
-- NOTE: "Scripts" panel is repurposed as "Serverside" panel below
local serversidePanel = UI.Scripts
local settingsPanel = UI.Settings
local smartBar = UI.SmartBar
local toggle = UI.Toggle
local starlight = UI.Starlight
local toastsContainer = UI.Toasts

-- Re-label the Scripts panel as Serverside
serversidePanel.Title.Text = "SERVERSIDE"
if serversidePanel:FindFirstChild("Icon") then
    -- Keep existing icon
end

-- ====================== INTERFACE CACHING ======================
if not getgenv().cachedInGameUI then getgenv().cachedInGameUI = {} end
if not getgenv().cachedCoreUI then getgenv().cachedCoreUI = {} end

-- ====================== SECURITY HOOKS ======================
local indexSetClipboard = "setclipboard"
local originalSetClipboard = getgenv()[indexSetClipboard]

local index = http_request and "http_request" or "request"
local originalRequest = getgenv()[index]

local suppressedSounds = {}
local soundSuppressionNotificationCooldown = 0
local soundInstances = {}
local cachedIds = {}
local cachedText = {}

if not getMessage then larpingValues.chatSpy.enabled = false end

local httpRequest = originalRequest

-- ====================== HELPER FUNCTIONS ======================
local function checkLarping() return UI.Parent end
local function getPing() return math.clamp(statsService.Network.ServerStatsItem["Data Ping"]:GetValue(), 10, 700) end

local function checkFolder()
    if isfolder then
        if not isfolder(larpingValues.folder) then makefolder(larpingValues.folder) end
        if not isfolder(larpingValues.folder.."/Music") then
            makefolder(larpingValues.folder.."/Music")
            writefile(larpingValues.folder.."/Music/readme.txt", "Place your MP3 or audio files here to play them through the Music UI!")
        end
        if not isfolder(larpingValues.folder.."/Assets/Icons") then makefolder(larpingValues.folder.."/Assets/Icons") end
        if not isfolder(larpingValues.folder.."/Assets") then makefolder(larpingValues.folder.."/Assets") end
    end
end

local function isPanel(name) return not table.find({"Home", "Music", "Settings"}, name) end

local function storeOriginalText(element)
    originalTextValues[element] = element.Text
end

local function undoAnonymousChanges()
    for element, originalText in pairs(originalTextValues) do
        element.Text = originalText
    end
end

local function createEsp(player)
    if player == localPlayer or not checkLarping() then return end

    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.OutlineColor = Color3.new(1,1,1)
    highlight.Adornee = player.Character
    highlight.Name = player.Name
    highlight.Enabled = larpingValues.actions[7].enabled
    highlight.Parent = espContainer

    player.CharacterAdded:Connect(function(character)
        if not checkLarping() then return end
        task.wait()
        highlight.Adornee = character
    end)
end

local function makeDraggable(object)
    local dragging = false
    local relative = nil

    local offset = Vector2.zero
    local screenGui = object:FindFirstAncestorWhichIsA("ScreenGui")
    if screenGui and screenGui.IgnoreGuiInset then
        offset += guiService:GetGuiInset()
    end

    object.InputBegan:Connect(function(input, processed)
        if processed then return end
        local inputType = input.UserInputType.Name
        if inputType == "MouseButton1" or inputType == "Touch" then
            relative = object.AbsolutePosition + object.AbsoluteSize * object.AnchorPoint - userInputService:GetMouseLocation()
            dragging = true
        end
    end)

    local inputEnded = userInputService.InputEnded:Connect(function(input)
        if not dragging then return end
        local inputType = input.UserInputType.Name
        if inputType == "MouseButton1" or inputType == "Touch" then
            dragging = false
        end
    end)

    local renderStepped = runService.RenderStepped:Connect(function()
        if dragging then
            local position = userInputService:GetMouseLocation() + relative + offset
            object.Position = UDim2.fromOffset(position.X, position.Y)
        end
    end)

    object.Destroying:Connect(function()
        inputEnded:Disconnect()
        renderStepped:Disconnect()
    end)
end

local function checkAction(target)
    local toReturn = {}

    for _, action in ipairs(larpingValues.actions) do
        if action.name == target then
            toReturn.action = action
            break
        end
    end

    for _, action in ipairs(characterPanel.Interactions.Grid:GetChildren()) do
        if action.name == target then
            toReturn.object = action
            break
        end
    end

    return toReturn
end

local function checkSetting(settingTarget, categoryTarget)
    for _, category in ipairs(larpingSettings) do
        if categoryTarget then
            if category.name == categoryTarget then
                for _, setting in ipairs(category.categorySettings) do
                    if setting.name == settingTarget then
                        return setting
                    end
                end
            end
            return
        else
            for _, setting in ipairs(category.categorySettings) do
                if setting.name == settingTarget then
                    return setting
                end
            end
        end
    end
end

local function wipeTransparency(ins, target, checkSelf, tween, duration)
    local transparencyProperties = larpingValues.transparencyProperties

    local function applyTransparency(obj)
        local properties = transparencyProperties[obj.className]
        if properties then
            local tweenProperties = {}
            for _, property in ipairs(properties) do
                tweenProperties[property] = target
            end
            for property, transparency in pairs(tweenProperties) do
                if tween then
                    tweenService:Create(obj, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {[property] = transparency}):Play()
                else
                    obj[property] = transparency
                end
            end
        end
    end

    if checkSelf then applyTransparency(ins) end
    for _, descendant in ipairs(ins:getDescendants()) do
        applyTransparency(descendant)
    end
end

local function blurSignature(value)
    if not value then
        if lighting:FindFirstChild("LarpingBlur") then
            lighting:FindFirstChild("LarpingBlur"):Destroy()
        end
    else
        if not lighting:FindFirstChild("LarpingBlur") then
            local blurLight = Instance.new("DepthOfFieldEffect", lighting)
            blurLight.Name = "LarpingBlur"
            blurLight.Enabled = true
            blurLight.FarIntensity = 0
            blurLight.FocusDistance = 51.6
            blurLight.InFocusRadius = 50
            blurLight.NearIntensity = 0.8
        end
    end
end

local function figureNotifications()
    if checkLarping() then
        local notificationsSize = 0

        if #notifications > 0 then
            blurSignature(true)
        else
            blurSignature(false)
        end

        for i = #notifications, 0, -1 do
            local notification = notifications[i]
            if notification then
                if notificationsSize == 0 then
                    notificationsSize = notification.Size.Y.Offset + 2
                else
                    notificationsSize += notification.Size.Y.Offset + 5
                end
                local desiredPosition = UDim2.new(0.5, 0, 0, notificationsSize)
                if notification.Position ~= desiredPosition then
                    notification:TweenPosition(desiredPosition, "Out", "Quint", 0.8, true)
                end
            end
        end
    end
end

local function queueNotification(Title, Description, Image)
    task.spawn(function()
        if checkLarping() then
            local newNotification = notificationContainer.Template:Clone()
            newNotification.Parent = notificationContainer
            newNotification.Name = Title or "Unknown Title"
            newNotification.Visible = true

            newNotification.Title.Text = Title or "Unknown Title"
            newNotification.Description.Text = Description or "Unknown Description"
            newNotification.Time.Text = "now"

            newNotification.AnchorPoint = Vector2.new(0.5, 1)
            newNotification.Position = UDim2.new(0.5, 0, -1, 0)
            newNotification.Size = UDim2.new(0, 320, 0, 500)
            newNotification.Description.Size = UDim2.new(0, 241, 0, 400)
            wipeTransparency(newNotification, 1, true)

            newNotification.Description.Size = UDim2.new(0, 241, 0, newNotification.Description.TextBounds.Y)
            newNotification.Size = UDim2.new(0, 100, 0, newNotification.Description.TextBounds.Y + 50)

            table.insert(notifications, newNotification)
            figureNotifications()

            local notificationSound = Instance.new("Sound")
            notificationSound.Parent = UI
            notificationSound.SoundId = "rbxassetid://255881176"
            notificationSound.Name = "notificationSound"
            notificationSound.Volume = 0.65
            notificationSound.PlayOnRemove = true
            notificationSound:Destroy()

            if not tonumber(Image) then
                newNotification.Icon.Image = 'rbxassetid://14317577326'
            else
                newNotification.Icon.Image = 'rbxassetid://'..Image or 0
            end

            newNotification:TweenPosition(UDim2.new(0.5, 0, 0, newNotification.Size.Y.Offset + 2), "Out", "Quint", 0.9, true)
            task.wait(0.1)
            tweenService:Create(newNotification, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 320, 0, newNotification.Description.TextBounds.Y + 50)}):Play()
            task.wait(0.05)
            tweenService:Create(newNotification, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.35}):Play()
            tweenService:Create(newNotification.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0.7}):Play()
            task.wait(0.05)
            tweenService:Create(newNotification.Icon, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
            task.wait(0.04)
            tweenService:Create(newNotification.Title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
            task.wait(0.04)
            tweenService:Create(newNotification.Description, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0.15}):Play()
            tweenService:Create(newNotification.Time, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0.5}):Play()

            newNotification.Interact.MouseButton1Click:Connect(function()
                local foundNotification = table.find(notifications, newNotification)
                if foundNotification then table.remove(notifications, foundNotification) end

                tweenService:Create(newNotification, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position = UDim2.new(1.5, 0, 0, newNotification.Position.Y.Offset)}):Play()

                task.wait(0.4)
                newNotification:Destroy()
                figureNotifications()
                return
            end)

            local waitTime = (#newNotification.Description.Text*0.1)+2
            if waitTime <= 1 then waitTime = 2.5 elseif waitTime > 10 then waitTime = 10 end

            task.wait(waitTime)

            local foundNotification = table.find(notifications, newNotification)
            if foundNotification then table.remove(notifications, foundNotification) end

            tweenService:Create(newNotification, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position = UDim2.new(1.5, 0, 0, newNotification.Position.Y.Offset)}):Play()

            task.wait(1.2)
            newNotification:Destroy()
            figureNotifications()
        end
    end)
end

-- ====================== SERVERSIDE SCRIPT EXECUTION ======================

-- Prompt the user for a text argument, then call callback(value) or callback(nil) on cancel
local function showArgPrompt(promptText, callback)
    local argFrame = Instance.new("Frame")
    argFrame.Name = "ArgPrompt"
    argFrame.Size = UDim2.new(0, 400, 0, 150)
    argFrame.Position = UDim2.new(0.5, -200, 0.5, -75)
    argFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    argFrame.BorderSizePixel = 0
    argFrame.ZIndex = 110
    argFrame.Parent = UI
    Instance.new("UICorner", argFrame).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", argFrame)
    stroke.Color = Color3.fromRGB(80, 120, 220)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3

    local titleLbl = Instance.new("TextLabel", argFrame)
    titleLbl.Size = UDim2.new(1, -20, 0, 26)
    titleLbl.Position = UDim2.new(0, 10, 0, 10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = promptText
    titleLbl.TextColor3 = Color3.fromRGB(210, 210, 255)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextWrapped = true
    titleLbl.ZIndex = 111

    local inputBox = Instance.new("TextBox", argFrame)
    inputBox.Size = UDim2.new(1, -20, 0, 34)
    inputBox.Position = UDim2.new(0, 10, 0, 44)
    inputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    inputBox.Text = ""
    inputBox.PlaceholderText = "Type here..."
    inputBox.TextColor3 = Color3.fromRGB(240, 240, 240)
    inputBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
    inputBox.Font = Enum.Font.Gotham
    inputBox.TextSize = 13
    inputBox.ClearTextOnFocus = false
    inputBox.BorderSizePixel = 0
    inputBox.ZIndex = 111
    Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 8)
    local inputStroke = Instance.new("UIStroke", inputBox)
    inputStroke.Color = Color3.fromRGB(70, 70, 100)
    inputStroke.Thickness = 1

    local confirmBtn = Instance.new("TextButton", argFrame)
    confirmBtn.Size = UDim2.new(0, 120, 0, 32)
    confirmBtn.Position = UDim2.new(0, 10, 1, -42)
    confirmBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 220)
    confirmBtn.Text = "Confirm"
    confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirmBtn.Font = Enum.Font.GothamBold
    confirmBtn.TextSize = 13
    confirmBtn.BorderSizePixel = 0
    confirmBtn.ZIndex = 111
    Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0, 8)

    local cancelBtn = Instance.new("TextButton", argFrame)
    cancelBtn.Size = UDim2.new(0, 90, 0, 32)
    cancelBtn.Position = UDim2.new(0, 140, 1, -42)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    cancelBtn.Text = "Cancel"
    cancelBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
    cancelBtn.Font = Enum.Font.Gotham
    cancelBtn.TextSize = 13
    cancelBtn.BorderSizePixel = 0
    cancelBtn.ZIndex = 111
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 8)

    argFrame.BackgroundTransparency = 1
    tweenService:Create(argFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
    task.delay(0.1, function() inputBox:CaptureFocus() end)

    local function close(value)
        tweenService:Create(argFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
        task.wait(0.25)
        argFrame:Destroy()
        callback(value)
    end

    confirmBtn.MouseButton1Click:Connect(function()
        local val = inputBox.Text
        if val == "" then
            inputStroke.Color = Color3.fromRGB(220, 60, 60)
            return
        end
        close(val)
    end)

    cancelBtn.MouseButton1Click:Connect(function()
        close(nil)
    end)

    inputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local val = inputBox.Text
            if val ~= "" then close(val) end
        end
    end)
end

local function showDangerousConfirm(callback)
    -- Create a simple confirm prompt overlay
    local confirmFrame = Instance.new("Frame")
    confirmFrame.Name = "DangerousConfirm"
    confirmFrame.Size = UDim2.new(0, 420, 0, 160)
    confirmFrame.Position = UDim2.new(0.5, -210, 0.5, -80)
    confirmFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    confirmFrame.BorderSizePixel = 0
    confirmFrame.ZIndex = 100
    confirmFrame.Parent = UI

    local corner = Instance.new("UICorner", confirmFrame)
    corner.CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", confirmFrame)
    stroke.Color = Color3.fromRGB(220, 50, 50)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3

    local titleLabel = Instance.new("TextLabel", confirmFrame)
    titleLabel.Size = UDim2.new(1, -20, 0, 32)
    titleLabel.Position = UDim2.new(0, 10, 0, 12)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "⚠ WARNING"
    titleLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 15
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 101

    local descLabel = Instance.new("TextLabel", confirmFrame)
    descLabel.Size = UDim2.new(1, -20, 0, 50)
    descLabel.Position = UDim2.new(0, 10, 0, 48)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = "This script may be banned on some Serversides. Are you sure you want to execute?"
    descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 12
    descLabel.TextWrapped = true
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.ZIndex = 101

    local confirmBtn = Instance.new("TextButton", confirmFrame)
    confirmBtn.Size = UDim2.new(0, 140, 0, 34)
    confirmBtn.Position = UDim2.new(0, 10, 1, -46)
    confirmBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    confirmBtn.Text = "Execute Anyway"
    confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirmBtn.Font = Enum.Font.GothamBold
    confirmBtn.TextSize = 13
    confirmBtn.BorderSizePixel = 0
    confirmBtn.ZIndex = 101
    Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0, 8)

    local cancelBtn = Instance.new("TextButton", confirmFrame)
    cancelBtn.Size = UDim2.new(0, 110, 0, 34)
    cancelBtn.Position = UDim2.new(0, 160, 1, -46)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    cancelBtn.Text = "Cancel"
    cancelBtn.TextColor3 = Color3.fromRGB(190, 190, 190)
    cancelBtn.Font = Enum.Font.Gotham
    cancelBtn.TextSize = 13
    cancelBtn.BorderSizePixel = 0
    cancelBtn.ZIndex = 101
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 8)

    -- Animate in
    confirmFrame.BackgroundTransparency = 1
    tweenService:Create(confirmFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()

    confirmBtn.MouseButton1Click:Connect(function()
        tweenService:Create(confirmFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
        task.wait(0.3)
        confirmFrame:Destroy()
        callback(true)
    end)

    cancelBtn.MouseButton1Click:Connect(function()
        tweenService:Create(confirmFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
        task.wait(0.3)
        confirmFrame:Destroy()
        callback(false)
    end)
end

local function runExecFunc(scriptData, arg)
    local ok, err = pcall(function()
        if scriptData.requiresArg then
            scriptData.execFunc(arg)
        else
            scriptData.execFunc()
        end
    end)
    if not ok then
        queueNotification("Script Error", "'"..scriptData.name.."' errored: "..tostring(err), 4370336704)
    end
end

local function executeServersideScript(scriptData)
    -- Step 1: if needs an argument, prompt first
    local function proceedWithArg(arg)
        -- Step 2: if dangerous, show confirm
        if scriptData.dangerous then
            showDangerousConfirm(function(confirmed)
                if confirmed then
                    runExecFunc(scriptData, arg)
                else
                    queueNotification("Cancelled", "Script execution cancelled.", 4400699701)
                end
            end)
        else
            runExecFunc(scriptData, arg)
        end
    end

    if scriptData.requiresArg then
        showArgPrompt(scriptData.argPrompt or "Enter argument:", function(val)
            if val == nil then
                queueNotification("Cancelled", "No argument provided, execution cancelled.", 4400699701)
                return
            end
            proceedWithArg(val)
        end)
    else
        proceedWithArg(nil)
    end
end

-- ====================== POPULATE SERVERSIDE PANEL ======================
local function populateServersidePanel()
    -- Clear existing buttons (except template)
    for _, child in ipairs(serversidePanel.Interactions.Selection:GetChildren()) do
        if child.ClassName == "Frame" and child.Name ~= "Template" then
            child:Destroy()
        end
    end

    -- Add credit label at top
    local creditLabel = Instance.new("TextLabel")
    creditLabel.Size = UDim2.new(1, -10, 0, 20)
    creditLabel.Position = UDim2.new(0, 5, 0, 0)
    creditLabel.BackgroundTransparency = 1
    creditLabel.Text = "larping.win | serverside  •  Based on Sirius by SiriusSoftwareLtd"
    creditLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
    creditLabel.Font = Enum.Font.Gotham
    creditLabel.TextSize = 10
    creditLabel.TextXAlignment = Enum.TextXAlignment.Left
    creditLabel.Name = "CreditLabel"
    creditLabel.ZIndex = 5
    creditLabel.Parent = serversidePanel.Interactions

    -- Render each serverside script as a button
    for i, scriptData in ipairs(larpingValues.serversideScripts) do
        local template = serversidePanel.Interactions.Selection.Template
        local newBtn = template:Clone()
        newBtn.Name = "SSScript_"..i
        newBtn.Parent = serversidePanel.Interactions.Selection
        newBtn.Visible = true

        -- Set the label
        if newBtn:FindFirstChild("Title") then
            newBtn.Title.Text = scriptData.name
        end

        -- Add DANGEROUS! badge if applicable
        if scriptData.dangerous then
            local badge = Instance.new("TextLabel", newBtn)
            badge.Name = "DangerousBadge"
            badge.Size = UDim2.new(0, 90, 0, 18)
            badge.Position = UDim2.new(1, -95, 0.5, -9)
            badge.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
            badge.Text = "DANGEROUS!"
            badge.TextColor3 = Color3.fromRGB(255, 255, 255)
            badge.Font = Enum.Font.GothamBold
            badge.TextSize = 10
            badge.BorderSizePixel = 0
            badge.ZIndex = 6
            Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 5)
        end

        -- Button animation hover
        newBtn.MouseEnter:Connect(function()
            if not debounce then
                tweenService:Create(newBtn, TweenInfo.new(.4, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.1}):Play()
                tweenService:Create(newBtn.UIStroke, TweenInfo.new(.4, Enum.EasingStyle.Quint), {Transparency = 0.5}):Play()
                if newBtn:FindFirstChild("Title") then
                    tweenService:Create(newBtn.Title, TweenInfo.new(.4, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
                end
            end
        end)

        newBtn.MouseLeave:Connect(function()
            if not debounce then
                tweenService:Create(newBtn, TweenInfo.new(.4, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
                tweenService:Create(newBtn.UIStroke, TweenInfo.new(.4, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
                if newBtn:FindFirstChild("Title") then
                    tweenService:Create(newBtn.Title, TweenInfo.new(.4, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
                end
            end
        end)

        newBtn.Interact.MouseButton1Click:Connect(function()
            -- Small press animation
            tweenService:Create(newBtn, TweenInfo.new(.2, Enum.EasingStyle.Quint), {Size = UDim2.new(0, newBtn.Size.X.Offset - 4, 0, newBtn.Size.Y.Offset - 2)}):Play()
            task.wait(0.12)
            tweenService:Create(newBtn, TweenInfo.new(.2, Enum.EasingStyle.Quint), {Size = UDim2.new(0, newBtn.Size.X.Offset + 4, 0, newBtn.Size.Y.Offset + 2)}):Play()
            task.wait(0.05)
            executeServersideScript(scriptData)
        end)
    end

    -- "Add Script" hint if empty
    if #larpingValues.serversideScripts == 0 then
        local hint = Instance.new("TextLabel")
        hint.Size = UDim2.new(1, -20, 0, 40)
        hint.Position = UDim2.new(0, 10, 0, 30)
        hint.BackgroundTransparency = 1
        hint.Text = "No serverside scripts added.\nAdd scripts via larpingValues.serversideScripts in the source."
        hint.TextColor3 = Color3.fromRGB(90, 90, 110)
        hint.Font = Enum.Font.Gotham
        hint.TextSize = 11
        hint.TextWrapped = true
        hint.Name = "EmptyHint"
        hint.Parent = serversidePanel.Interactions.Selection
    end
end

-- ====================== PUBLIC API: ADD SERVERSIDE SCRIPT ======================
-- Allow external scripts to add buttons:
-- require(id)("user"):AddScript({ name = "Kill All", script = [[...]]], dangerous = true })
function larpingWin.AddScript(scriptData)
    table.insert(larpingValues.serversideScripts, scriptData)
    populateServersidePanel()
end

-- ====================== REMAINING CORE FUNCTIONS ======================

local function removeReverbs(timing)
    timing = timing or 0.65
    for index, sound in next, soundInstances do
        if sound:FindFirstChild("LarpingAudioProfile") then
            local reverb = sound:FindFirstChild("LarpingAudioProfile")
            tweenService:Create(reverb, TweenInfo.new(timing, Enum.EasingStyle.Exponential), {HighGain = 0}):Play()
            tweenService:Create(reverb, TweenInfo.new(timing, Enum.EasingStyle.Exponential), {LowGain = 0}):Play()
            tweenService:Create(reverb, TweenInfo.new(timing, Enum.EasingStyle.Exponential), {MidGain = 0}):Play()
            task.delay(timing + 0.03, reverb.Destroy, reverb)
        end
    end
end

local function playNext()
    if #musicQueue == 0 then currentAudio.Playing = false currentAudio.SoundId = "" musicPanel.Playing.Text = "Not Playing" return end

    if not currentAudio then
        local newAudio = Instance.new("Sound")
        newAudio.Parent = UI
        newAudio.Name = "Audio"
        currentAudio = newAudio
    end

    musicPanel.Menu.TogglePlaying.ImageRectOffset = currentAudio.Playing and Vector2.new(804, 124) or Vector2.new(764, 244)
    local asset = getcustomasset(larpingValues.folder.."/Music/"..musicQueue[1].sound)

    if checkSetting("Now Playing Notifications").current then queueNotification("Now Playing", musicQueue[1].sound, 4400695581) end

    if musicPanel.Queue.List:FindFirstChild(tostring(musicQueue[1].instanceName)) then
        musicPanel.Queue.List:FindFirstChild(tostring(musicQueue[1].instanceName)):Destroy()
    end

    currentAudio.SoundId = asset
    musicPanel.Playing.Text = musicQueue[1].sound
    currentAudio:Play()
    musicPanel.Menu.TogglePlaying.ImageRectOffset = currentAudio.Playing and Vector2.new(804, 124) or Vector2.new(764, 244)
    currentAudio.Ended:Wait()

    table.remove(musicQueue, 1)
    playNext()
end

local function addToQueue(file)
    if not getcustomasset then return end
    checkFolder()
    if not isfile(larpingValues.folder.."/Music/"..file) then queueNotification("Unable to locate file", "Please ensure that your audio file is in the LarpingWin/Music folder.", 4370341699) return end
    musicPanel.AddBox.Input.Text = ""

    local newAudio = musicPanel.Queue.List.Template:Clone()
    newAudio.Parent = musicPanel.Queue.List
    newAudio.Size = UDim2.new(0, 254, 0, 40)
    newAudio.Close.ImageTransparency = 1
    newAudio.Name = file
    if string.len(newAudio.FileName.Text) > 26 then
        newAudio.FileName.Text = string.sub(tostring(file), 1,24)..".."
    else
        newAudio.FileName.Text = file
    end
    newAudio.Visible = true
    newAudio.Duration.Text = ""

    table.insert(musicQueue, {sound = file, instanceName = newAudio.Name})

    local getLength = Instance.new("Sound", workspace)
    getLength.SoundId = getcustomasset(larpingValues.folder.."/Music/"..file)
    getLength.Volume = 0
    getLength:Play()
    task.wait(0.05)
    newAudio.Duration.Text = tostring(math.round(getLength.TimeLength)).."s"
    getLength:Stop()
    getLength:Destroy()

    newAudio.MouseEnter:Connect(function()
        tweenService:Create(newAudio, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(100, 100, 100)}):Play()
        tweenService:Create(newAudio.Close, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
        tweenService:Create(newAudio.Duration, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
    end)

    newAudio.MouseLeave:Connect(function()
        tweenService:Create(newAudio.Close, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
        tweenService:Create(newAudio, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(0, 0, 0)}):Play()
        tweenService:Create(newAudio.Duration, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {TextTransparency = 0.7}):Play()
    end)

    newAudio.Close.MouseButton1Click:Connect(function()
        if not string.find(currentAudio.Name, file) then
            for i,v in pairs(musicQueue) do
                for _,b in pairs(v) do
                    if b == newAudio.Name then
                        newAudio:Destroy()
                        table.remove(musicQueue, i)
                    end
                end
            end
        else
            for i,v in pairs(musicQueue) do
                for _,b in pairs(v) do
                    if b == newAudio.Name then
                        newAudio:Destroy()
                        table.remove(musicQueue, i)
                        playNext()
                    end
                end
            end
        end
    end)

    if #musicQueue == 1 then
        playNext()
    end
end

local function openMusic()
    debounce = true
    musicPanel.Visible = true
    musicPanel.Queue.List.Template.Visible = false
    debounce = false
end

local function closeMusic()
    debounce = true
    musicPanel.Visible = false
    debounce = false
end

local function createReverb(timing)
    for index, sound in next, soundInstances do
        if not sound:FindFirstChild("LarpingAudioProfile") then
            local reverb = Instance.new("EqualizerSoundEffect")
            reverb.Name = "LarpingAudioProfile"
            reverb.Parent = sound
            reverb.Enabled = false
            reverb.HighGain = 0
            reverb.LowGain = 0
            reverb.MidGain = 0
            reverb.Enabled = true

            if timing then
                tweenService:Create(reverb, TweenInfo.new(timing, Enum.EasingStyle.Exponential), {HighGain = -20}):Play()
                tweenService:Create(reverb, TweenInfo.new(timing, Enum.EasingStyle.Exponential), {LowGain = 5}):Play()
                tweenService:Create(reverb, TweenInfo.new(timing, Enum.EasingStyle.Exponential), {MidGain = -20}):Play()
            end
        end
    end
end

local function updateSliderPadding()
    for _, v in pairs(larpingValues.sliders) do
        v.padding = {
            v.object.Interact.AbsolutePosition.X,
            v.object.Interact.AbsolutePosition.X + v.object.Interact.AbsoluteSize.X
        }
    end
end

local function updateSlider(data, setValue, forceValue)
    local inverse_interpolation

    if setValue then
        setValue = math.clamp(setValue, data.values[1], data.values[2])
        inverse_interpolation = (setValue - data.values[1]) / (data.values[2] - data.values[1])
    else
        local posX = math.clamp(mouse.X, data.padding[1], data.padding[2])
        inverse_interpolation = (posX - data.padding[1]) / (data.padding[2] - data.padding[1])
    end

    tweenService:Create(data.object.Progress, TweenInfo.new(.5, Enum.EasingStyle.Quint), {Size = UDim2.new(inverse_interpolation, 0, 1, 0)}):Play()

    local value = math.floor(data.values[1] + (data.values[2] - data.values[1]) * inverse_interpolation + .5)
    data.object.Information.Text = value.." "..data.name
    data.value = value

    if data.callback and not setValue or forceValue then
        data.callback(value)
    end
end

local function resetSliders()
    for _, v in pairs(larpingValues.sliders) do
        updateSlider(v, v.default, true)
    end
end

local function sortActions()
    characterPanel.Interactions.Grid.Template.Visible = false
    characterPanel.Interactions.Sliders.Template.Visible = false

    for _, action in ipairs(larpingValues.actions) do
        local newAction = characterPanel.Interactions.Grid.Template:Clone()
        newAction.Name = action.name
        newAction.Parent = characterPanel.Interactions.Grid
        newAction.BackgroundColor3 = action.color
        newAction.UIStroke.Color = action.color
        newAction.Icon.Image = "rbxassetid://"..action.images[2]
        newAction.Visible = true
        newAction.BackgroundTransparency = 0.8
        newAction.Transparency = 0.7

        newAction.MouseEnter:Connect(function()
            characterPanel.Interactions.ActionsTitle.Text = string.upper(action.name)
            if action.enabled or debounce then return end
            tweenService:Create(newAction, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.4}):Play()
            tweenService:Create(newAction.UIStroke, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Transparency = 0.6}):Play()
        end)

        newAction.MouseLeave:Connect(function()
            if action.enabled or debounce then return end
            tweenService:Create(newAction, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.55}):Play()
            tweenService:Create(newAction.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0.4}):Play()
        end)

        characterPanel.Interactions.Grid.MouseLeave:Connect(function()
            characterPanel.Interactions.ActionsTitle.Text = "PLAYER ACTIONS"
        end)

        newAction.Interact.MouseButton1Click:Connect(function()
            local success, response = pcall(function()
                action.enabled = not action.enabled
                action.callback(action.enabled)

                if action.enabled then
                    newAction.Icon.Image = "rbxassetid://"..action.images[1]
                    tweenService:Create(newAction, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.1}):Play()
                    tweenService:Create(newAction.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
                    tweenService:Create(newAction.Icon, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {ImageTransparency = 0.1}):Play()

                    if action.disableAfter then
                        task.delay(action.disableAfter, function()
                            action.enabled = false
                            newAction.Icon.Image = "rbxassetid://"..action.images[2]
                            tweenService:Create(newAction, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.55}):Play()
                            tweenService:Create(newAction.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0.4}):Play()
                            tweenService:Create(newAction.Icon, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {ImageTransparency = 0.5}):Play()
                        end)
                    end

                    if action.rotateWhileEnabled then
                        repeat
                            newAction.Icon.Rotation = 0
                            tweenService:Create(newAction.Icon, TweenInfo.new(0.75, Enum.EasingStyle.Quint), {Rotation = 360}):Play()
                            task.wait(1)
                        until not action.enabled
                        newAction.Icon.Rotation = 0
                    end
                else
                    newAction.Icon.Image = "rbxassetid://"..action.images[2]
                    tweenService:Create(newAction, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.55}):Play()
                    tweenService:Create(newAction.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0.4}):Play()
                    tweenService:Create(newAction.Icon, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {ImageTransparency = 0.5}):Play()
                end
            end)

            if not success then
                queueNotification("Action Error", "Action '"..action.name.."' errored. Please check your executor.", 4370336704)
                action.enabled = false
                newAction.Icon.Image = "rbxassetid://"..action.images[2]
                tweenService:Create(newAction, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.55}):Play()
                tweenService:Create(newAction.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0.4}):Play()
                tweenService:Create(newAction.Icon, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {ImageTransparency = 0.5}):Play()
            end
        end)
    end

    if localPlayer.Character then
        if not localPlayer.Character:FindFirstChildOfClass('Humanoid').UseJumpPower then
            larpingValues.sliders[2].name = "jump height"
            larpingValues.sliders[2].default = 7.2
            larpingValues.sliders[2].values = {0, 120}
        end
    end

    for _, slider in ipairs(larpingValues.sliders) do
        local newSlider = characterPanel.Interactions.Sliders.Template:Clone()
        newSlider.Name = slider.name.." Slider"
        newSlider.Parent = characterPanel.Interactions.Sliders
        newSlider.BackgroundColor3 = slider.color
        newSlider.Progress.BackgroundColor3 = slider.color
        newSlider.UIStroke.Color = slider.color
        newSlider.Information.Text = slider.name
        newSlider.Visible = true

        slider.object = newSlider
        slider.padding = {
            newSlider.Interact.AbsolutePosition.X,
            newSlider.Interact.AbsolutePosition.X + newSlider.Interact.AbsoluteSize.X
        }

        newSlider.MouseEnter:Connect(function()
            if debounce or slider.active then return end
            tweenService:Create(newSlider, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.85}):Play()
            tweenService:Create(newSlider.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0.6}):Play()
            tweenService:Create(newSlider.Information, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
        end)

        newSlider.MouseLeave:Connect(function()
            if debounce or slider.active then return end
            tweenService:Create(newSlider, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.8}):Play()
            tweenService:Create(newSlider.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
            tweenService:Create(newSlider.Information, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 0.3}):Play()
        end)

        newSlider.Interact.MouseButton1Down:Connect(function()
            if debounce or not checkLarping() then return end
            slider.active = true
            updateSlider(slider)
            tweenService:Create(slider.object, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.9}):Play()
            tweenService:Create(slider.object.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
            tweenService:Create(slider.object.Information, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 0.05}):Play()
        end)

        updateSlider(slider, slider.default)
    end
end

local function getAdaptiveHighPingThreshold()
    local adaptiveBaselinePings = larpingValues.pingProfile.adaptiveBaselinePings
    if #adaptiveBaselinePings == 0 then
        return larpingValues.pingProfile.adaptiveHighPingThreshold
    end
    table.sort(adaptiveBaselinePings)
    local median
    if #adaptiveBaselinePings % 2 == 0 then
        median = (adaptiveBaselinePings[#adaptiveBaselinePings/2] + adaptiveBaselinePings[#adaptiveBaselinePings/2 + 1]) / 2
    else
        median = adaptiveBaselinePings[math.ceil(#adaptiveBaselinePings/2)]
    end
    return median * larpingValues.pingProfile.spikeThreshold
end

local function checkHighPing()
    local recentPings = larpingValues.pingProfile.recentPings
    local adaptiveBaselinePings = larpingValues.pingProfile.adaptiveBaselinePings
    local currentPing = getPing()
    table.insert(recentPings, currentPing)

    if #recentPings > larpingValues.pingProfile.maxSamples then
        table.remove(recentPings, 1)
    end

    if #adaptiveBaselinePings < larpingValues.pingProfile.adaptiveBaselineSamples then
        if currentPing >= 350 then currentPing = 300 end
        table.insert(adaptiveBaselinePings, currentPing)
        return false
    end

    local averagePing = 0
    for _, ping in ipairs(recentPings) do
        averagePing = averagePing + ping
    end
    averagePing = averagePing / #recentPings

    if averagePing > getAdaptiveHighPingThreshold() then
        return true
    end

    return false
end

local function checkTools()
    task.wait(0.03)
    if localPlayer.Backpack and localPlayer.Character then
        if localPlayer.Backpack:FindFirstChildOfClass('Tool') or localPlayer.Character:FindFirstChildOfClass('Tool') then
            return true
        end
    else
        return false
    end
end

local function closePanel(panelName, openingOther)
    debounce = true

    local button = smartBar.Buttons:FindFirstChild(panelName)
    local panel = UI:FindFirstChild(panelName)

    if not isPanel(panelName) then return end
    if not (panel and button) then return end

    local panelSize = UDim2.new(0, 581, 0, 246)

    if not openingOther then
        if panel.Name == "Character" then
            tweenService:Create(characterPanel.Interactions.PropertiesTitle, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()

            for _, slider in ipairs(characterPanel.Interactions.Sliders:GetChildren()) do
                if slider.ClassName == "Frame" then
                    tweenService:Create(slider, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
                    tweenService:Create(slider.Progress, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
                    tweenService:Create(slider.UIStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
                    tweenService:Create(slider.Shadow, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
                    tweenService:Create(slider.Information, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
                end
            end

            tweenService:Create(characterPanel.Interactions.Reset, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
            tweenService:Create(characterPanel.Interactions.ActionsTitle, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()

            for _, gridButton in ipairs(characterPanel.Interactions.Grid:GetChildren()) do
                if gridButton.ClassName == "Frame" then
                    tweenService:Create(gridButton, TweenInfo.new(0.21, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                    tweenService:Create(gridButton.UIStroke, TweenInfo.new(0.1, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                    tweenService:Create(gridButton.Icon, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
                    tweenService:Create(gridButton.Shadow, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
                end
            end

            tweenService:Create(characterPanel.Interactions.Serverhop, TweenInfo.new(.15,Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
            tweenService:Create(characterPanel.Interactions.Serverhop.Title, TweenInfo.new(.15,Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
            tweenService:Create(characterPanel.Interactions.Serverhop.UIStroke, TweenInfo.new(.15,Enum.EasingStyle.Quint), {Transparency = 1}):Play()
            tweenService:Create(characterPanel.Interactions.Rejoin, TweenInfo.new(.15,Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
            tweenService:Create(characterPanel.Interactions.Rejoin.Title, TweenInfo.new(.15,Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
            tweenService:Create(characterPanel.Interactions.Rejoin.UIStroke, TweenInfo.new(.15,Enum.EasingStyle.Quint), {Transparency = 1}):Play()

        elseif panel.Name == "Scripts" then
            for _, scriptButton in ipairs(serversidePanel.Interactions.Selection:GetChildren()) do
                if scriptButton.ClassName == "Frame" then
                    tweenService:Create(scriptButton, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
                    if scriptButton:FindFirstChild('Icon') then tweenService:Create(scriptButton.Icon, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play() end
                    tweenService:Create(scriptButton.Title, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
                    if scriptButton:FindFirstChild('Subtitle') then tweenService:Create(scriptButton.Subtitle, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play() end
                    tweenService:Create(scriptButton.UIStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
                end
            end

        elseif panel.Name == "Playerlist" then
            for _, playerIns in ipairs(playerlistPanel.Interactions.List:GetDescendants()) do
                if playerIns.ClassName == "Frame" then
                    tweenService:Create(playerIns, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
                elseif playerIns.ClassName == "TextLabel" or playerIns.ClassName == "TextButton" then
                    tweenService:Create(playerIns, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
                elseif playerIns.ClassName == "ImageLabel" or playerIns.ClassName == "ImageButton" then
                    tweenService:Create(playerIns, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
                    if playerIns.Name == "Avatar" then tweenService:Create(playerIns, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play() end
                elseif playerIns.ClassName == "UIStroke" then
                    tweenService:Create(playerIns, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
                end
            end

            tweenService:Create(playerlistPanel.Interactions.SearchFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
            tweenService:Create(playerlistPanel.Interactions.SearchFrame.Icon, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
            tweenService:Create(playerlistPanel.Interactions.SearchFrame.SearchBox, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
            tweenService:Create(playerlistPanel.Interactions.SearchFrame.UIStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
            tweenService:Create(playerlistPanel.Interactions.List, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ScrollBarImageTransparency = 1}):Play()
        end

        tweenService:Create(panel.Icon, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
        tweenService:Create(panel.Title, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
        tweenService:Create(panel.UIStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
        tweenService:Create(panel.Shadow, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
        task.wait(0.03)

        tweenService:Create(panel, TweenInfo.new(0.75, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut), {BackgroundTransparency = 1}):Play()
        tweenService:Create(panel, TweenInfo.new(1.1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = button.Size}):Play()
        tweenService:Create(panel, TweenInfo.new(0.65, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {Position = larpingValues.buttonPositions[panelName]}):Play()
        tweenService:Create(toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {Position = UDim2.new(0.5, 0, 1, -85)}):Play()
    end

    if openingOther then
        tweenService:Create(panel, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {Position = UDim2.new(0.5, 350, 1, -90)}):Play()
        wipeTransparency(panel, 1, true, true, 0.3)
    end

    task.wait(0.5)
    panel.Size = panelSize
    panel.Visible = false

    debounce = false
end

local function openPanel(panelName)
    if debounce then return end
    debounce = true

    local button = smartBar.Buttons:FindFirstChild(panelName)
    local panel = UI:FindFirstChild(panelName)

    if not isPanel(panelName) then return end
    if not (panel and button) then return end

    for _, otherPanel in ipairs(UI:GetChildren()) do
        if smartBar.Buttons:FindFirstChild(otherPanel.Name) then
            if isPanel(otherPanel.Name) and otherPanel.Visible then
                task.spawn(closePanel, otherPanel.Name, true)
                task.wait()
            end
        end
    end

    local panelSize = UDim2.new(0, 581, 0, 246)

    panel.Size = button.Size
    panel.Position = larpingValues.buttonPositions[panelName]

    wipeTransparency(panel, 1, true)

    panel.Visible = true

    tweenService:Create(toggle, TweenInfo.new(0.65, Enum.EasingStyle.Quint), {Position = UDim2.new(0.5, 0, 1, -(panelSize.Y.Offset + 95))}):Play()

    tweenService:Create(panel, TweenInfo.new(0.1, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
    tweenService:Create(panel, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Size = panelSize}):Play()
    tweenService:Create(panel, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0.5, 0, 1, -90)}):Play()
    task.wait(0.1)
    tweenService:Create(panel.Shadow, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {ImageTransparency = 0.7}):Play()
    tweenService:Create(panel.Icon, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
    task.wait(0.05)
    tweenService:Create(panel.Title, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
    tweenService:Create(panel.UIStroke, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {Transparency = 0.95}):Play()
    task.wait(0.05)

    if panel.Name == "Character" then
        tweenService:Create(characterPanel.Interactions.PropertiesTitle, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {TextTransparency = 0.65}):Play()

        local sliderInfo = {}
        for _, slider in ipairs(characterPanel.Interactions.Sliders:GetChildren()) do
            if slider.ClassName == "Frame" then
                table.insert(sliderInfo, {slider.Name, slider.Progress.Size, slider.Information.Text})
                slider.Progress.Size = UDim2.new(0, 0, 1, 0)
                slider.Progress.BackgroundTransparency = 0

                tweenService:Create(slider, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.8}):Play()
                tweenService:Create(slider.UIStroke, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Transparency = 0.5}):Play()
                tweenService:Create(slider.Shadow, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {ImageTransparency = 0.6}):Play()
                tweenService:Create(slider.Information, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {TextTransparency = 0.3}):Play()
            end
        end

        for _, sliderV in pairs(sliderInfo) do
            if characterPanel.Interactions.Sliders:FindFirstChild(sliderV[1]) then
                local slider = characterPanel.Interactions.Sliders:FindFirstChild(sliderV[1])
                local tweenValue = Instance.new("IntValue", UI)
                local tweenTo
                local name

                for _, sliderFound in ipairs(larpingValues.sliders) do
                    if sliderFound.name.." Slider" == slider.Name then
                        tweenTo = sliderFound.value
                        name = sliderFound.name
                        break
                    end
                end

                tweenService:Create(slider.Progress, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Size = sliderV[2]}):Play()

                local function animateNumber(n)
                    tweenService:Create(tweenValue, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), {Value = n}):Play()
                    task.delay(0.4, tweenValue.Destroy, tweenValue)
                end

                tweenValue:GetPropertyChangedSignal("Value"):Connect(function()
                    slider.Information.Text = tostring(tweenValue.Value).." "..name
                end)

                animateNumber(tweenTo)
            end
        end

        tweenService:Create(characterPanel.Interactions.Reset, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {ImageTransparency = 0.7}):Play()
        tweenService:Create(characterPanel.Interactions.ActionsTitle, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {TextTransparency = 0.65}):Play()

        for _, gridButton in ipairs(characterPanel.Interactions.Grid:GetChildren()) do
            if gridButton.ClassName == "Frame" then
                for _, action in ipairs(larpingValues.actions) do
                    if action.name == gridButton.Name then
                        if action.enabled then
                            tweenService:Create(gridButton, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.1}):Play()
                            tweenService:Create(gridButton.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
                            tweenService:Create(gridButton.Icon, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {ImageTransparency = 0.1}):Play()
                        else
                            tweenService:Create(gridButton, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.55}):Play()
                            tweenService:Create(gridButton.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0.4}):Play()
                            tweenService:Create(gridButton.Icon, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {ImageTransparency = 0.5}):Play()
                        end
                        break
                    end
                end

                tweenService:Create(gridButton.Shadow, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {ImageTransparency = 0.6}):Play()
            end
        end

        tweenService:Create(characterPanel.Interactions.Serverhop, TweenInfo.new(.5,Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
        tweenService:Create(characterPanel.Interactions.Serverhop.Title, TweenInfo.new(.5,Enum.EasingStyle.Quint), {TextTransparency = 0.5}):Play()
        tweenService:Create(characterPanel.Interactions.Serverhop.UIStroke, TweenInfo.new(.5,Enum.EasingStyle.Quint), {Transparency = 0}):Play()
        tweenService:Create(characterPanel.Interactions.Rejoin, TweenInfo.new(.5,Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
        tweenService:Create(characterPanel.Interactions.Rejoin.Title, TweenInfo.new(.5,Enum.EasingStyle.Quint), {TextTransparency = 0.5}):Play()
        tweenService:Create(characterPanel.Interactions.Rejoin.UIStroke, TweenInfo.new(.5,Enum.EasingStyle.Quint), {Transparency = 0}):Play()

    elseif panel.Name == "Scripts" then
        for _, scriptButton in ipairs(serversidePanel.Interactions.Selection:GetChildren()) do
            if scriptButton.ClassName == "Frame" then
                tweenService:Create(scriptButton, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
                if scriptButton:FindFirstChild('Icon') then tweenService:Create(scriptButton.Icon, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play() end
                tweenService:Create(scriptButton.Title, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
                if scriptButton:FindFirstChild('Subtitle') then tweenService:Create(scriptButton.Subtitle, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {TextTransparency = 0.3}):Play() end
                tweenService:Create(scriptButton.UIStroke, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {Transparency = 0.2}):Play()
            end
        end

    elseif panel.Name == "Playerlist" then
        for _, playerIns in ipairs(playerlistPanel.Interactions.List:GetDescendants()) do
            if playerIns.Name ~= "Interact" and playerIns.Name ~= "Role" then
                if playerIns.ClassName == "Frame" then
                    tweenService:Create(playerIns, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
                elseif playerIns.ClassName == "TextLabel" or playerIns.ClassName == "TextButton" then
                    tweenService:Create(playerIns, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
                elseif playerIns.ClassName == "ImageLabel" or playerIns.ClassName == "ImageButton" then
                    tweenService:Create(playerIns, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
                    if playerIns.Name == "Avatar" then tweenService:Create(playerIns, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play() end
                elseif playerIns.ClassName == "UIStroke" then
                    tweenService:Create(playerIns, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
                end
            end
        end

        tweenService:Create(playerlistPanel.Interactions.SearchFrame, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
        tweenService:Create(playerlistPanel.Interactions.SearchFrame.Icon, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
        task.wait(0.01)
        tweenService:Create(playerlistPanel.Interactions.SearchFrame.SearchBox, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
        tweenService:Create(playerlistPanel.Interactions.SearchFrame.UIStroke, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {Transparency = 0.2}):Play()
        task.wait(0.05)
        tweenService:Create(playerlistPanel.Interactions.List, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {ScrollBarImageTransparency = 0.7}):Play()
    end

    task.wait(0.45)
    debounce = false
end

local function rejoin()
    queueNotification("Rejoining Session", "We're queueing a rejoin to this session, give us a moment.", 4400696294)
    if #players:GetPlayers() <= 1 then
        task.wait()
        teleportService:Teleport(placeId, localPlayer)
    else
        teleportService:TeleportToPlaceInstance(placeId, jobId, localPlayer)
    end
end

local function serverhop()
    local highestPlayers = 0
    local servers = {}

    for _, v in ipairs(httpService:JSONDecode(game:HttpGetAsync("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100")).data) do
        if type(v) == "table" and v.maxPlayers > v.playing and v.id ~= jobId then
            if v.playing > highestPlayers then
                highestPlayers = v.playing
                servers[1] = v.id
            end
        end
    end

    if #servers > 0 then
        queueNotification("Teleporting", "We're now moving you to the new session.", 4335479121)
        task.wait(0.3)
        teleportService:TeleportToPlaceInstance(placeId, servers[1])
    else
        return queueNotification("No Servers Found", "Couldn't find another server.", 4370317928)
    end
end

local function ensureFrameProperties()
    UI.Enabled = true
    characterPanel.Visible = false
    customScriptPrompt.Visible = false
    disconnectedPrompt.Visible = false
    playerlistPanel.Interactions.List.Template.Visible = false
    gameDetectionPrompt.Visible = false
    homeContainer.Visible = false
    moderatorDetectionPrompt.Visible = false
    musicPanel.Visible = false
    notificationContainer.Visible = true
    playerlistPanel.Visible = false
    scriptSearch.Visible = false
    serversidePanel.Visible = false
    settingsPanel.Visible = false
    smartBar.Visible = false
    musicPanel.Playing.Text = "Not Playing"
    if not getcustomasset then smartBar.Buttons.Music.Visible = false end
    toastsContainer.Visible = true
    makeDraggable(settingsPanel)
    makeDraggable(musicPanel)
end

local function checkFriends()
    if friendsCooldown == 0 then
        friendsCooldown = 25

        local playersFriends = {}
        local success, page = pcall(players.GetFriendsAsync, players, localPlayer.UserId)

        if success then
            repeat
                local info = page:GetCurrentPage()
                for i, friendInfo in pairs(info) do
                    table.insert(playersFriends, friendInfo)
                end
                if not page.IsFinished then
                    page:AdvanceToNextPageAsync()
                end
            until page.IsFinished
        end

        local friendsInTotal = 0
        local onlineFriends = 0
        local friendsInGame = 0

        for i,v in pairs(playersFriends) do
            friendsInTotal = friendsInTotal + 1
            if v.IsOnline then onlineFriends = onlineFriends + 1 end
            if players:FindFirstChild(v.Username) then friendsInGame = friendsInGame + 1 end
        end

        if not checkLarping() then return end

        homeContainer.Interactions.Friends.All.Value.Text = tostring(friendsInTotal).." friends"
        homeContainer.Interactions.Friends.Offline.Value.Text = tostring(friendsInTotal - onlineFriends).." friends"
        homeContainer.Interactions.Friends.Online.Value.Text = tostring(onlineFriends).." friends"
        homeContainer.Interactions.Friends.InGame.Value.Text = tostring(friendsInGame).." friends"
    else
        friendsCooldown -= 1
    end
end

function promptModerator(player, role)
    local serversAvailable = false
    local promptClosed = false

    if moderatorDetectionPrompt.Visible then return end

    moderatorDetectionPrompt.Size = UDim2.new(0, 283, 0, 175)
    moderatorDetectionPrompt.UIGradient.Offset = Vector2.new(0, 1)
    wipeTransparency(moderatorDetectionPrompt, 1, true)

    moderatorDetectionPrompt.DisplayName.Text = player.DisplayName
    moderatorDetectionPrompt.Rank.Text = role
    moderatorDetectionPrompt.Avatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..player.UserId.."&width=420&height=420&format=png"

    moderatorDetectionPrompt.Visible = true

    for _, v in ipairs(game:GetService("HttpService"):JSONDecode(game:HttpGetAsync("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")).data) do
        if type(v) == "table" and v.maxPlayers > v.playing and v.id ~= game.JobId then
            serversAvailable = true
        end
    end

    if not serversAvailable then
        moderatorDetectionPrompt.Serverhop.Visible = false
    else
        moderatorDetectionPrompt.ServersAvailableFade.Visible = true
    end

    tweenService:Create(moderatorDetectionPrompt, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
    tweenService:Create(moderatorDetectionPrompt, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 300, 0, 186)}):Play()
    tweenService:Create(moderatorDetectionPrompt.UIGradient, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Offset = Vector2.new(0, 0.65)}):Play()
    tweenService:Create(moderatorDetectionPrompt.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
    tweenService:Create(moderatorDetectionPrompt.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
    tweenService:Create(moderatorDetectionPrompt.Avatar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.7}):Play()
    tweenService:Create(moderatorDetectionPrompt.Avatar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
    tweenService:Create(moderatorDetectionPrompt.DisplayName, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
    tweenService:Create(moderatorDetectionPrompt.Rank, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
    tweenService:Create(moderatorDetectionPrompt.Serverhop, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.7}):Play()
    tweenService:Create(moderatorDetectionPrompt.Leave, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.7}):Play()
    task.wait(0.2)
    tweenService:Create(moderatorDetectionPrompt.Serverhop, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
    tweenService:Create(moderatorDetectionPrompt.Leave, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
    task.wait(0.3)
    tweenService:Create(moderatorDetectionPrompt.Close, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 0.6}):Play()

    local function closeModPrompt()
        tweenService:Create(moderatorDetectionPrompt, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
        tweenService:Create(moderatorDetectionPrompt, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 283, 0, 175)}):Play()
        tweenService:Create(moderatorDetectionPrompt.UIGradient, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Offset = Vector2.new(0, 1)}):Play()
        tweenService:Create(moderatorDetectionPrompt.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
        tweenService:Create(moderatorDetectionPrompt.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
        tweenService:Create(moderatorDetectionPrompt.Avatar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
        tweenService:Create(moderatorDetectionPrompt.Avatar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
        tweenService:Create(moderatorDetectionPrompt.DisplayName, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
        tweenService:Create(moderatorDetectionPrompt.Rank, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
        tweenService:Create(moderatorDetectionPrompt.Serverhop, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
        tweenService:Create(moderatorDetectionPrompt.Leave, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
        tweenService:Create(moderatorDetectionPrompt.Serverhop, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
        tweenService:Create(moderatorDetectionPrompt.Leave, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
        tweenService:Create(moderatorDetectionPrompt.Close, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
        task.wait(0.5)
        moderatorDetectionPrompt.Visible = false
    end

    moderatorDetectionPrompt.Leave.MouseButton1Click:Connect(function()
        closeModPrompt()
        game:Shutdown()
    end)

    moderatorDetectionPrompt.Serverhop.MouseEnter:Connect(function()
        tweenService:Create(moderatorDetectionPrompt.ServersAvailableFade, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0.5}):Play()
    end)

    moderatorDetectionPrompt.Serverhop.MouseLeave:Connect(function()
        tweenService:Create(moderatorDetectionPrompt.ServersAvailableFade, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
    end)

    moderatorDetectionPrompt.Serverhop.MouseButton1Click:Connect(function()
        if promptClosed then return end
        serverhop()
        closeModPrompt()
    end)

    moderatorDetectionPrompt.Close.MouseButton1Click:Connect(function()
        closeModPrompt()
        promptClosed = true
    end)
end

local function UpdateHome()
    if not checkLarping() then return end

    local function format(Int)
        return string.format("%02i", Int)
    end

    local function convertToHMS(Seconds)
        local Minutes = (Seconds - Seconds%60)/60
        Seconds = Seconds - Minutes*60
        local Hours = (Minutes - Minutes%60)/60
        Minutes = Minutes - Hours*60
        return format(Hours)..":"..format(Minutes)..":"..format(Seconds)
    end

    homeContainer.Title.Text = "Welcome home, "..localPlayer.DisplayName

    homeContainer.Interactions.Server.Players.Value.Text = #players:GetPlayers().." playing"
    homeContainer.Interactions.Server.MaxPlayers.Value.Text = players.MaxPlayers.." players can join this server"
    homeContainer.Interactions.Server.Latency.Value.Text = math.floor(getPing()).."ms"
    homeContainer.Interactions.Server.Time.Value.Text = convertToHMS(time())
    homeContainer.Interactions.Server.Region.Value.Text = "Unable to retrieve region"

    homeContainer.Interactions.User.Avatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..localPlayer.UserId.."&width=420&height=420&format=png"
    homeContainer.Interactions.User.Title.Text = localPlayer.DisplayName
    homeContainer.Interactions.User.Subtitle.Text = localPlayer.Name

    -- Show serverside executor info
    homeContainer.Interactions.Client.Title.Text = "Serverside Executor"
    if identifyexecutor then
        homeContainer.Interactions.Client.Subtitle.Text = identifyexecutor().." — some scripts require extra arguments, enter them when prompted."
    else
        homeContainer.Interactions.Client.Subtitle.Text = "You're on a serverside executor. Some scripts require extra arguments — enter them when prompted."
    end

    checkFriends()
end

local function openHome()
    if debounce then return end
    debounce = true
    homeContainer.Visible = true

    local homeBlur = Instance.new("BlurEffect", lighting)
    homeBlur.Size = 0
    homeBlur.Name = "HomeBlur"

    homeContainer.BackgroundTransparency = 1
    homeContainer.Title.TextTransparency = 1
    homeContainer.Subtitle.TextTransparency = 1

    for _, homeItem in ipairs(homeContainer.Interactions:GetChildren()) do
        wipeTransparency(homeItem, 1, true)
        homeItem.Position = UDim2.new(0, homeItem.Position.X.Offset - 20, 0, homeItem.Position.Y.Offset - 20)
        homeItem.Size = UDim2.new(0, homeItem.Size.X.Offset + 30, 0, homeItem.Size.Y.Offset + 20)
        if homeItem.UIGradient.Offset.Y > 0 then
            homeItem.UIGradient.Offset = Vector2.new(0, homeItem.UIGradient.Offset.Y + 3)
            homeItem.UIStroke.UIGradient.Offset = Vector2.new(0, homeItem.UIStroke.UIGradient.Offset.Y + 3)
        else
            homeItem.UIGradient.Offset = Vector2.new(0, homeItem.UIGradient.Offset.Y - 3)
            homeItem.UIStroke.UIGradient.Offset = Vector2.new(0, homeItem.UIStroke.UIGradient.Offset.Y - 3)
        end
    end

    tweenService:Create(homeContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.9}):Play()
    tweenService:Create(homeBlur, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Size = 5}):Play()
    tweenService:Create(camera, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {FieldOfView = camera.FieldOfView + 5}):Play()

    task.wait(0.25)

    for _, inGameUI in ipairs(localPlayer:FindFirstChildWhichIsA("PlayerGui"):GetChildren()) do
        if inGameUI:IsA("ScreenGui") then
            if inGameUI.Enabled then
                if not table.find(getgenv().cachedInGameUI, inGameUI.Name) then
                    table.insert(getgenv().cachedInGameUI, #getgenv().cachedInGameUI+1, inGameUI.Name)
                end
                inGameUI.Enabled = false
            end
        end
    end

    table.clear(getgenv().cachedCoreUI)

    for _, coreUI in pairs({"PlayerList", "Chat", "EmotesMenu", "Health", "Backpack"}) do
        if game:GetService("StarterGui"):GetCoreGuiEnabled(coreUI) then
            table.insert(getgenv().cachedCoreUI, #getgenv().cachedCoreUI+1, coreUI)
        end
    end

    for _, coreUI in pairs(getgenv().cachedCoreUI) do
        game:GetService("StarterGui"):SetCoreGuiEnabled(coreUI, false)
    end

    createReverb(0.8)

    tweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {FieldOfView = camera.FieldOfView - 40}):Play()
    tweenService:Create(homeContainer, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.7}):Play()
    tweenService:Create(homeContainer.Title, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
    tweenService:Create(homeContainer.Subtitle, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {TextTransparency = 0.4}):Play()
    tweenService:Create(homeBlur, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Size = 20}):Play()

    for _, homeItem in ipairs(homeContainer.Interactions:GetChildren()) do
        for _, otherHomeItem in ipairs(homeItem:GetDescendants()) do
            if otherHomeItem.ClassName == "Frame" then
                tweenService:Create(otherHomeItem, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.7}):Play()
            elseif otherHomeItem.ClassName == "TextLabel" then
                if otherHomeItem.Name == "Title" then
                    tweenService:Create(otherHomeItem, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
                else
                    tweenService:Create(otherHomeItem, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0.3}):Play()
                end
            elseif otherHomeItem.ClassName == "ImageLabel" then
                tweenService:Create(otherHomeItem, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.8}):Play()
                tweenService:Create(otherHomeItem, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
            end
        end

        tweenService:Create(homeItem, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
        tweenService:Create(homeItem.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
        tweenService:Create(homeItem, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Position = UDim2.new(0, homeItem.Position.X.Offset + 20, 0, homeItem.Position.Y.Offset + 20)}):Play()
        tweenService:Create(homeItem, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Size = UDim2.new(0, homeItem.Size.X.Offset - 30, 0, homeItem.Size.Y.Offset - 20)}):Play()

        task.delay(0.03, function()
            if homeItem.UIGradient.Offset.Y > 0 then
                tweenService:Create(homeItem.UIGradient, TweenInfo.new(1, Enum.EasingStyle.Exponential), {Offset = Vector2.new(0, homeItem.UIGradient.Offset.Y - 3)}):Play()
                tweenService:Create(homeItem.UIStroke.UIGradient, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Offset = Vector2.new(0, homeItem.UIStroke.UIGradient.Offset.Y - 3)}):Play()
            else
                tweenService:Create(homeItem.UIGradient, TweenInfo.new(1, Enum.EasingStyle.Exponential), {Offset = Vector2.new(0, homeItem.UIGradient.Offset.Y + 3)}):Play()
                tweenService:Create(homeItem.UIStroke.UIGradient, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Offset = Vector2.new(0, homeItem.UIStroke.UIGradient.Offset.Y + 3)}):Play()
            end
        end)

        task.wait(0.02)
    end

    task.wait(0.85)
    debounce = false
end

local function closeHome()
    if debounce then return end
    debounce = true

    tweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {FieldOfView = camera.FieldOfView + 35}):Play()

    for _, obj in ipairs(lighting:GetChildren()) do
        if obj.Name == "HomeBlur" then
            tweenService:Create(obj, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = 0}):Play()
            task.delay(0.6, obj.Destroy, obj)
        end
    end

    tweenService:Create(homeContainer, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
    tweenService:Create(homeContainer.Title, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
    tweenService:Create(homeContainer.Subtitle, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()

    for _, homeItem in ipairs(homeContainer.Interactions:GetChildren()) do
        for _, otherHomeItem in ipairs(homeItem:GetDescendants()) do
            if otherHomeItem.ClassName == "Frame" then
                tweenService:Create(otherHomeItem, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
            elseif otherHomeItem.ClassName == "TextLabel" then
                tweenService:Create(otherHomeItem, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
            elseif otherHomeItem.ClassName == "ImageLabel" then
                tweenService:Create(otherHomeItem, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
                tweenService:Create(otherHomeItem, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
            end
        end
        tweenService:Create(homeItem, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
        tweenService:Create(homeItem.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
    end

    task.wait(0.2)

    for _, cachedInGameUIObject in pairs(getgenv().cachedInGameUI) do
        for _, currentPlayerUI in ipairs(localPlayer:FindFirstChildWhichIsA("PlayerGui"):GetChildren()) do
            if table.find(getgenv().cachedInGameUI, currentPlayerUI.Name) then
                currentPlayerUI.Enabled = true
            end
        end
    end

    for _, coreUI in pairs(getgenv().cachedCoreUI) do
        game:GetService("StarterGui"):SetCoreGuiEnabled(coreUI, true)
    end

    removeReverbs(0.5)
    task.wait(0.52)
    homeContainer.Visible = false
    debounce = false
end

local function openScriptSearch()
    debounce = true

    scriptSearch.Size = UDim2.new(0, 480, 0, 23)
    scriptSearch.Position = UDim2.new(0.5, 0, 0.5, 0)
    scriptSearch.SearchBox.Position = UDim2.new(0.509, 0, 0.5, 0)
    scriptSearch.Icon.Position = UDim2.new(0.04, 0, 0.5, 0)
    scriptSearch.SearchBox.Text = ""
    scriptSearch.UIGradient.Offset = Vector2.new(0, 2)
    scriptSearch.SearchBox.PlaceholderText = "Search ScriptBlox.com"
    scriptSearch.List.Template.Visible = false
    scriptSearch.List.Visible = false
    scriptSearch.Visible = true

    wipeTransparency(scriptSearch, 1, true)

    tweenService:Create(scriptSearch, TweenInfo.new(.5,Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
    tweenService:Create(scriptSearch, TweenInfo.new(.5,Enum.EasingStyle.Quint), {Size = UDim2.new(0, 580, 0, 43)}):Play()
    tweenService:Create(scriptSearch.Shadow, TweenInfo.new(.5,Enum.EasingStyle.Quint), {ImageTransparency = 0.85}):Play()
    task.wait(0.03)
    tweenService:Create(scriptSearch.Icon, TweenInfo.new(.5,Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
    task.wait(0.02)
    tweenService:Create(scriptSearch.SearchBox, TweenInfo.new(.5,Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()

    task.wait(0.3)
    scriptSearch.SearchBox:CaptureFocus()
    task.wait(0.2)
    debounce = false
end

local function closeScriptSearch()
    debounce = true

    wipeTransparency(scriptSearch, 1, false)
    task.wait(0.1)

    scriptSearch.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    scriptSearch.UIGradient.Enabled = false
    tweenService:Create(scriptSearch, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 520, 0, 0)}):Play()
    scriptSearch.SearchBox:ReleaseFocus()

    task.wait(0.5)

    for _, createdScript in ipairs(scriptSearch.List:GetChildren()) do
        if createdScript.Name ~= "Placeholder" and createdScript.Name ~= "Template" and createdScript.ClassName == "Frame" then
            createdScript:Destroy()
        end
    end

    task.wait(0.1)
    scriptSearch.BackgroundColor3 = Color3.fromRGB(255,255,255)
    scriptSearch.Visible = false
    scriptSearch.UIGradient.Enabled = true
    debounce = false
end

local function openSmartBar()
    smartBarOpen = true

    coreGui.RobloxGui.Backpack.Position = UDim2.new(0,0,0,0)

    smartBar.BackgroundTransparency = 1
    smartBar.Time.TextTransparency = 1
    smartBar.UIStroke.Transparency = 1
    smartBar.Shadow.ImageTransparency = 1
    smartBar.Visible = true
    smartBar.Position = UDim2.new(0.5, 0, 1.05, 0)
    smartBar.Size = UDim2.new(0, 531, 0, 64)
    toggle.Rotation = 180
    toggle.Visible = not checkSetting("Hide Toggle Button").current

    if checkTools() then
        toggle.Position = UDim2.new(0.5,0,1,-68)
    else
        toggle.Position = UDim2.new(0.5, 0, 1, -5)
    end

    for _, button in ipairs(smartBar.Buttons:GetChildren()) do
        button.UIGradient.Rotation = -120
        button.UIStroke.UIGradient.Rotation = -120
        button.Size = UDim2.new(0,30,0,30)
        button.Position = UDim2.new(button.Position.X.Scale, 0, 1.3, 0)
        button.BackgroundTransparency = 1
        button.UIStroke.Transparency = 1
        button.Icon.ImageTransparency = 1
    end

    tweenService:Create(coreGui.RobloxGui.Backpack, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Position = UDim2.new(-0.325,0,0,0)}):Play()
    tweenService:Create(toggle, TweenInfo.new(0.82, Enum.EasingStyle.Quint), {Rotation = 0}):Play()
    tweenService:Create(smartBar, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Position = UDim2.new(0.5, 0, 1, -12)}):Play()
    tweenService:Create(toastsContainer, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0.5, 0, 1, -110)}):Play()
    tweenService:Create(toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Position = UDim2.new(0.5, 0, 1, -85)}):Play()
    tweenService:Create(smartBar, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0,581,0,70)}):Play()
    tweenService:Create(smartBar, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
    tweenService:Create(smartBar.Shadow, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {ImageTransparency = 0.7}):Play()
    tweenService:Create(smartBar.Time, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
    tweenService:Create(smartBar.UIStroke, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Transparency = 0.95}):Play()
    tweenService:Create(toggle, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()

    for _, button in ipairs(smartBar.Buttons:GetChildren()) do
        tweenService:Create(button.UIStroke, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
        tweenService:Create(button, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 36, 0, 36)}):Play()
        tweenService:Create(button.UIGradient, TweenInfo.new(1, Enum.EasingStyle.Quint), {Rotation = 50}):Play()
        tweenService:Create(button.UIStroke.UIGradient, TweenInfo.new(1, Enum.EasingStyle.Quint), {Rotation = 50}):Play()
        tweenService:Create(button, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(button.Position.X.Scale, 0, 0.5, 0)}):Play()
        tweenService:Create(button, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
        tweenService:Create(button.Icon, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
        task.wait(0.03)
    end
end

local function closeSmartBar()
    smartBarOpen = false

    for _, otherPanel in ipairs(UI:GetChildren()) do
        if smartBar.Buttons:FindFirstChild(otherPanel.Name) then
            if isPanel(otherPanel.Name) and otherPanel.Visible then
                task.spawn(closePanel, otherPanel.Name, true)
                task.wait()
            end
        end
    end

    tweenService:Create(smartBar.Time, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
    for _, Button in ipairs(smartBar.Buttons:GetChildren()) do
        tweenService:Create(Button.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
        tweenService:Create(Button, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 30, 0, 30)}):Play()
        tweenService:Create(Button, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
        tweenService:Create(Button.Icon, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
    end

    tweenService:Create(coreGui.RobloxGui.Backpack, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 0, 0, 0)}):Play()
    tweenService:Create(smartBar, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {BackgroundTransparency = 1}):Play()
    tweenService:Create(smartBar.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
    tweenService:Create(smartBar.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
    tweenService:Create(smartBar, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Size = UDim2.new(0,531,0,64)}):Play()
    tweenService:Create(smartBar, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {Position = UDim2.new(0.5, 0,1, 73)}):Play()

    if checkTools() then
        tweenService:Create(toggle, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {Position = UDim2.new(0.5,0,1,-68)}):Play()
        tweenService:Create(toastsContainer, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {Position = UDim2.new(0.5, 0, 1, -90)}):Play()
        tweenService:Create(toggle, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Rotation = 180}):Play()
    else
        tweenService:Create(toastsContainer, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {Position = UDim2.new(0.5, 0, 1, -28)}):Play()
        tweenService:Create(toggle, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {Position = UDim2.new(0.5, 0, 1, -5)}):Play()
        tweenService:Create(toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Rotation = 180}):Play()
    end
end

local function windowFocusChanged(value)
    if checkLarping() then
        if value then
            if setfpscap then setfpscap(tonumber(checkSetting("Artificial FPS Limit").current)) end
            removeReverbs(0.5)
        else
            if checkSetting("Muffle audio while unfocused").current then createReverb(0.7) end
            if checkSetting("Limit FPS while unfocused").current then if setfpscap then setfpscap(60) end end
        end
    end
end

local function onChatted(player, message)
    local enabled = checkSetting("Chat Spy").current and larpingValues.chatSpy.enabled
    local chatSpyVisuals = larpingValues.chatSpy.visual

    if not message or not checkLarping() then return end

    if enabled and player ~= localPlayer then
        local message2 = message:gsub("[\n\r]",''):gsub("\t",' '):gsub("[ ]+",' ')
        local hidden = true

        local get = getMessage.OnClientEvent:Connect(function(packet, channel)
            if packet.SpeakerUserId == player.UserId and packet.Message == message2:sub(#message2-#packet.Message+1) and (channel=="All" or (channel=="Team" and players[packet.FromSpeaker].Team == localPlayer.Team)) then
                hidden = false
            end
        end)

        task.wait(1)
        get:Disconnect()

        if hidden and enabled then
            chatSpyVisuals.Text = "larping.win Spy - [".. player.Name .."]: "..message2
            starterGui:SetCore("ChatMakeSystemMessage", chatSpyVisuals)
        end
    end

    if checkSetting("Log Messages").current then
        local logData = {
            ["content"] = message,
            ["avatar_url"] = "https://www.roblox.com/headshot-thumbnail/image?userId="..player.UserId.."&width=420&height=420&format=png",
            ["username"] = player.DisplayName,
            ["allowed_mentions"] = {parse = {}}
        }

        logData = httpService:JSONEncode(logData)

        pcall(function()
            originalRequest({
                Url = checkSetting("Message Webhook URL").current,
                Method = 'POST',
                Headers = { ['Content-Type'] = 'application/json' },
                Body = logData
            })
        end)
    end
end

local function sortPlayers()
    local newTable = playerlistPanel.Interactions.List:GetChildren()

    for index, player in ipairs(newTable) do
        if player.ClassName ~= "Frame" or player.Name == "Placeholder" then
            table.remove(newTable, index)
        end
    end

    table.sort(newTable, function(playerA, playerB)
        return playerA.Name < playerB.Name
    end)

    for index, frame in ipairs(newTable) do
        if frame.ClassName == "Frame" then
            if frame.Name ~= "Placeholder" then
                frame.LayoutOrder = index
            end
        end
    end
end

-- ====================== PLAYER FEATURES (SERVERSIDE-PORTED) ======================

local function kill(player)
    -- Serverside kill: attempt via tool damage or character manipulation
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            pcall(function()
                -- Try direct health set (works in some serversides / unprotected games)
                humanoid.Health = 0
            end)
        end
    end
end

local function teleportTo(player)
    if players:FindFirstChild(player.Name) then
        queueNotification("Teleportation", "Teleporting to "..player.DisplayName..".")

        local targetChar = workspace:FindFirstChild(player.Name)
        if targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
            local target = targetChar.HumanoidRootPart
            local myChar = localPlayer.Character
            if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                myChar.HumanoidRootPart.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
            end
        end
    else
        queueNotification("Teleportation Error", player.DisplayName.." has left this server.")
    end
end

local function spectate(player)
    if players:FindFirstChild(player.Name) then
        local character = workspace:FindFirstChild(player.Name)
        if character and character:FindFirstChildOfClass("Humanoid") then
            camera.CameraType = Enum.CameraType.Follow
            camera.CameraSubject = character:FindFirstChildOfClass("Humanoid")
            queueNotification("Spectating", "Now spectating "..player.DisplayName..". Click anywhere to stop.", 4400695581)

            -- Stop spectate on click
            local conn
            conn = userInputService.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    camera.CameraType = Enum.CameraType.Custom
                    local localChar = localPlayer.Character
                    if localChar then
                        camera.CameraSubject = localChar:FindFirstChildOfClass("Humanoid")
                    end
                    conn:Disconnect()
                    queueNotification("Spectate Stopped", "Stopped spectating "..player.DisplayName..".")
                end
            end)
        end
    else
        queueNotification("Spectate Error", player.DisplayName.." is not in the server.")
    end
end

local function locatePlayer(player)
    -- Toggle ESP highlight for this specific player
    local highlight = espContainer:FindFirstChild(player.Name)
    if highlight then
        highlight.Enabled = not highlight.Enabled
        queueNotification("ESP Toggle", (highlight.Enabled and "Enabled" or "Disabled").." ESP for "..player.DisplayName..".")
    else
        queueNotification("ESP Error", "No ESP object found for "..player.DisplayName..".")
    end
end

local function createPlayer(player)
    if not checkLarping() then return end

    if playerlistPanel.Interactions.List:FindFirstChild(player.DisplayName) then return end

    local newPlayer = playerlistPanel.Interactions.List.Template:Clone()
    newPlayer.Name = player.DisplayName
    newPlayer.Parent = playerlistPanel.Interactions.List
    newPlayer.Visible = not searchingForPlayer

    newPlayer.NoActions.Visible = false
    newPlayer.PlayerInteractions.Visible = false
    newPlayer.Role.Visible = false

    newPlayer.Size = UDim2.new(0, 539, 0, 45)
    newPlayer.DisplayName.Position = UDim2.new(0, 53, 0.5, 0)
    newPlayer.DisplayName.Size = UDim2.new(0, 224, 0, 16)
    newPlayer.Avatar.Size = UDim2.new(0, 30, 0, 30)

    sortPlayers()

    newPlayer.DisplayName.TextTransparency = 0
    newPlayer.DisplayName.TextScaled = true
    newPlayer.DisplayName.FontFace.Weight = Enum.FontWeight.Medium
    newPlayer.DisplayName.Text = player.DisplayName
    newPlayer.Avatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..player.UserId.."&width=420&height=420&format=png"

    if creatorType == Enum.CreatorType.Group then
        task.spawn(function()
            local role = player:GetRoleInGroup(creatorId)
            if role == "Guest" then
                newPlayer.Role.Text = "Group Rank: None"
            else
                newPlayer.Role.Text = "Group Rank: "..role
            end
            newPlayer.Role.Visible = true
            newPlayer.Role.TextTransparency = 1
        end)
    end

    local function openInteractions()
        if newPlayer.PlayerInteractions.Visible then return end

        newPlayer.PlayerInteractions.BackgroundTransparency = 1
        for _, interaction in ipairs(newPlayer.PlayerInteractions:GetChildren()) do
            if interaction.ClassName == "Frame" and interaction.Name ~= "Placeholder" then
                interaction.BackgroundTransparency = 1
                interaction.Shadow.ImageTransparency = 1
                interaction.Icon.ImageTransparency = 1
                interaction.UIStroke.Transparency = 1
            end
        end

        newPlayer.PlayerInteractions.Visible = true

        for _, interaction in ipairs(newPlayer.PlayerInteractions:GetChildren()) do
            if interaction.ClassName == "Frame" and interaction.Name ~= "Placeholder" then
                tweenService:Create(interaction.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
                tweenService:Create(interaction.Icon, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
                tweenService:Create(interaction.Shadow, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 0.7}):Play()
                tweenService:Create(interaction, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
            end
        end
    end

    local function closeInteractions()
        if not newPlayer.PlayerInteractions.Visible then return end
        for _, interaction in ipairs(newPlayer.PlayerInteractions:GetChildren()) do
            if interaction.ClassName == "Frame" and interaction.Name ~= "Placeholder" then
                tweenService:Create(interaction.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
                tweenService:Create(interaction.Icon, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
                tweenService:Create(interaction.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
                tweenService:Create(interaction, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
            end
        end
        task.wait(0.35)
        newPlayer.PlayerInteractions.Visible = false
    end

    newPlayer.MouseEnter:Connect(function()
        if debounce or not playerlistPanel.Visible then return end
        tweenService:Create(newPlayer.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
        tweenService:Create(newPlayer.DisplayName, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0.3}):Play()
    end)

    newPlayer.MouseLeave:Connect(function()
        if debounce or not playerlistPanel.Visible then return end
        task.spawn(closeInteractions)
        tweenService:Create(newPlayer.DisplayName, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 53, 0.5, 0)}):Play()
        tweenService:Create(newPlayer, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 539, 0, 45)}):Play()
        tweenService:Create(newPlayer.Avatar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 30, 0, 30)}):Play()
        tweenService:Create(newPlayer.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
        tweenService:Create(newPlayer.DisplayName, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
        tweenService:Create(newPlayer.Role, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
    end)

    newPlayer.Interact.MouseButton1Click:Connect(function()
        if debounce or not playerlistPanel.Visible then return end
        if creatorType == Enum.CreatorType.Group then
            tweenService:Create(newPlayer.DisplayName, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 73, 0.39, 0)}):Play()
            tweenService:Create(newPlayer.Role, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0.3}):Play()
        else
            tweenService:Create(newPlayer.DisplayName, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 73, 0.5, 0)}):Play()
        end

        if player ~= localPlayer then openInteractions() end

        tweenService:Create(newPlayer, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 539, 0, 75)}):Play()
        tweenService:Create(newPlayer.DisplayName, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
        tweenService:Create(newPlayer.Avatar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 50, 0, 50)}):Play()
        tweenService:Create(newPlayer.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
    end)

    -- Kill button — functional serverside kill
    newPlayer.PlayerInteractions.Kill.Interact.MouseButton1Click:Connect(function()
        tweenService:Create(newPlayer.PlayerInteractions.Kill, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(0, 124, 89)}):Play()
        kill(player)
        queueNotification("Kill", "Attempted kill on "..player.DisplayName..".")
        task.wait(1)
        tweenService:Create(newPlayer.PlayerInteractions.Kill, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(50, 50, 50)}):Play()
    end)

    -- Teleport button
    newPlayer.PlayerInteractions.Teleport.Interact.MouseButton1Click:Connect(function()
        tweenService:Create(newPlayer.PlayerInteractions.Teleport, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(0, 152, 111)}):Play()
        teleportTo(player)
        task.wait(0.5)
        tweenService:Create(newPlayer.PlayerInteractions.Teleport, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(50, 50, 50)}):Play()
    end)

    -- Spectate button — functional
    newPlayer.PlayerInteractions.Spectate.Interact.MouseButton1Click:Connect(function()
        spectate(player)
    end)

    -- Locate/ESP button — functional
    newPlayer.PlayerInteractions.Locate.Interact.MouseButton1Click:Connect(function()
        locatePlayer(player)
    end)
end

local function removePlayer(player)
    if not checkLarping() then return end

    if playerlistPanel.Interactions.List:FindFirstChild(player.Name) then
        playerlistPanel.Interactions.List:FindFirstChild(player.Name):Destroy()
    end
end

local function openSettings()
    debounce = true

    settingsPanel.BackgroundTransparency = 1
    settingsPanel.Title.TextTransparency = 1
    settingsPanel.Subtitle.TextTransparency = 1
    settingsPanel.Back.ImageTransparency = 1
    settingsPanel.Shadow.ImageTransparency = 1

    wipeTransparency(settingsPanel.SettingTypes, 1, true)

    settingsPanel.Visible = true
    settingsPanel.UIGradient.Enabled = true
    settingsPanel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    settingsPanel.UIGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0.0470588, 0.0470588, 0.0470588)),ColorSequenceKeypoint.new(1, Color3.new(0.0470588, 0.0470588, 0.0470588))})
    settingsPanel.UIGradient.Offset = Vector2.new(0, 1.7)
    settingsPanel.SettingTypes.Visible = true
    settingsPanel.SettingLists.Visible = false
    settingsPanel.Size = UDim2.new(0, 550, 0, 340)
    settingsPanel.Title.Position = UDim2.new(0.045, 0, 0.057, 0)

    settingsPanel.Title.Text = "Settings"
    settingsPanel.Subtitle.Text = "Adjust preferences, keybinds, and features for larping.win."

    tweenService:Create(settingsPanel, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 613, 0, 384)}):Play()
    tweenService:Create(settingsPanel, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
    tweenService:Create(settingsPanel.Shadow, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 0.7}):Play()
    tweenService:Create(settingsPanel.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
    tweenService:Create(settingsPanel.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()

    task.wait(0.1)

    for _, settingType in ipairs(settingsPanel.SettingTypes:GetChildren()) do
        if settingType.ClassName == "Frame" then
            local gradientRotation = math.random(78, 95)
            tweenService:Create(settingType.UIGradient, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Rotation = gradientRotation}):Play()
            tweenService:Create(settingType.Shadow.UIGradient, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Rotation = gradientRotation}):Play()
            tweenService:Create(settingType.UIStroke.UIGradient, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Rotation = gradientRotation}):Play()
            tweenService:Create(settingType, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
            tweenService:Create(settingType.Shadow, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 0.7}):Play()
            tweenService:Create(settingType.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
            tweenService:Create(settingType.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0.2}):Play()
            task.wait(0.02)
        end
    end

    for _, settingList in ipairs(settingsPanel.SettingLists:GetChildren()) do
        if settingList.ClassName == "ScrollingFrame" then
            for _, setting in ipairs(settingList:GetChildren()) do
                if setting.ClassName == "Frame" then
                    setting.Visible = true
                end
            end
        end
    end

    debounce = false
end

local function closeSettings()
    debounce = true

    for _, settingType in ipairs(settingsPanel.SettingTypes:GetChildren()) do
        if settingType.ClassName == "Frame" then
            tweenService:Create(settingType, TweenInfo.new(0.1, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
            tweenService:Create(settingType.Shadow, TweenInfo.new(0.05, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
            tweenService:Create(settingType.UIStroke, TweenInfo.new(0.05, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
            tweenService:Create(settingType.Title, TweenInfo.new(0.05, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
        end
    end

    tweenService:Create(settingsPanel.Shadow, TweenInfo.new(0.1, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
    tweenService:Create(settingsPanel.Back, TweenInfo.new(0.1, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
    tweenService:Create(settingsPanel.Title, TweenInfo.new(0.1, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
    tweenService:Create(settingsPanel.Subtitle, TweenInfo.new(0.1, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()

    for _, settingList in ipairs(settingsPanel.SettingLists:GetChildren()) do
        if settingList.ClassName == "ScrollingFrame" then
            for _, setting in ipairs(settingList:GetChildren()) do
                if setting.ClassName == "Frame" then
                    setting.Visible = false
                end
            end
        end
    end

    tweenService:Create(settingsPanel, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 520, 0, 0)}):Play()
    tweenService:Create(settingsPanel, TweenInfo.new(0.55, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()

    task.wait(0.55)

    settingsPanel.Visible = false
    debounce = false
end

local function saveSettings()
    checkFolder()
    if isfile and isfile(larpingValues.folder.."/"..larpingValues.settingsFile) then
        writefile(larpingValues.folder.."/"..larpingValues.settingsFile, httpService:JSONEncode(larpingSettings))
    end
end

local function assembleSettings()
    if isfile and isfile(larpingValues.folder.."/"..larpingValues.settingsFile) then
        local currentSettings
        local success, response = pcall(function()
            currentSettings = httpService:JSONDecode(readfile(larpingValues.folder.."/"..larpingValues.settingsFile))
        end)

        if success then
            for _, liveCategory in ipairs(larpingSettings) do
                for _, liveSetting in ipairs(liveCategory.categorySettings) do
                    for _, category in ipairs(currentSettings) do
                        for _, setting in ipairs(category.categorySettings) do
                            if liveSetting.id == setting.id then
                                liveSetting.current = setting.current
                            end
                        end
                    end
                end
            end
            writefile(larpingValues.folder.."/"..larpingValues.settingsFile, httpService:JSONEncode(larpingSettings))
        end
    else
        if writefile then
            checkFolder()
            if not isfile(larpingValues.folder.."/"..larpingValues.settingsFile) then
                writefile(larpingValues.folder.."/"..larpingValues.settingsFile, httpService:JSONEncode(larpingSettings))
            end
        end
    end

    for _, category in larpingSettings do
        local newCategory = settingsPanel.SettingTypes.Template:Clone()
        newCategory.Name = category.name
        newCategory.Title.Text = string.upper(category.name)
        newCategory.Parent = settingsPanel.SettingTypes
        newCategory.UIGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0.0392157, 0.0392157, 0.0392157)),ColorSequenceKeypoint.new(1, category.color)})
        newCategory.Visible = true

        local hue, sat, val = Color3.toHSV(category.color)
        hue = math.clamp(hue + 0.01, 0, 1) sat = math.clamp(sat + 0.1, 0, 1) val = math.clamp(val + 0.2, 0, 1)
        local newColor = Color3.fromHSV(hue, sat, val)
        newCategory.UIStroke.UIGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0.117647, 0.117647, 0.117647)),ColorSequenceKeypoint.new(1, newColor)})
        newCategory.Shadow.UIGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0.117647, 0.117647, 0.117647)),ColorSequenceKeypoint.new(1, newColor)})

        local newList = settingsPanel.SettingLists.Template:Clone()
        newList.Name = category.name
        newList.Parent = settingsPanel.SettingLists
        newList.Visible = true

        for _, obj in ipairs(newList:GetChildren()) do if obj.Name ~= "Placeholder" and obj.Name ~= "UIListLayout" then obj:Destroy() end end

        settingsPanel.Back.MouseButton1Click:Connect(function()
            tweenService:Create(settingsPanel.Back, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
            tweenService:Create(settingsPanel.Back, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0.002, 0, 0.052, 0)}):Play()
            tweenService:Create(settingsPanel.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0.045, 0, 0.057, 0)}):Play()
            tweenService:Create(settingsPanel.UIGradient, TweenInfo.new(1, Enum.EasingStyle.Exponential), {Offset = Vector2.new(0, 1.3)}):Play()
            settingsPanel.Title.Text = "Settings"
            settingsPanel.Subtitle.Text = "Adjust preferences, keybinds, and features for larping.win."
            settingsPanel.SettingTypes.Visible = true
            settingsPanel.SettingLists.Visible = false
        end)

        newCategory.Interact.MouseButton1Click:Connect(function()
            if settingsPanel.SettingLists:FindFirstChild(category.name) then
                settingsPanel.UIGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0.0470588, 0.0470588, 0.0470588)),ColorSequenceKeypoint.new(1, category.color)})
                settingsPanel.SettingTypes.Visible = false
                settingsPanel.SettingLists.Visible = true
                settingsPanel.SettingLists.UIPageLayout:JumpTo(settingsPanel.SettingLists[category.name])
                settingsPanel.Subtitle.Text = category.description
                settingsPanel.Back.Visible = true
                settingsPanel.Title.Text = category.name

                local gradientRotation = math.random(78, 95)
                settingsPanel.UIGradient.Rotation = gradientRotation
                tweenService:Create(settingsPanel.UIGradient, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Offset = Vector2.new(0, 0.65)}):Play()
                tweenService:Create(settingsPanel.Back, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
                tweenService:Create(settingsPanel.Back, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0.041, 0, 0.052, 0)}):Play()
                tweenService:Create(settingsPanel.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0.091, 0, 0.057, 0)}):Play()
            else
                closeSettings()
            end
        end)

        newCategory.MouseEnter:Connect(function()
            tweenService:Create(newCategory.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
            tweenService:Create(newCategory.UIGradient, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Offset = Vector2.new(0, 0.4)}):Play()
            tweenService:Create(newCategory.UIStroke.UIGradient, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Offset = Vector2.new(0, 0.2)}):Play()
            tweenService:Create(newCategory.Shadow.UIGradient, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Offset = Vector2.new(0, 0.2)}):Play()
        end)

        newCategory.MouseLeave:Connect(function()
            tweenService:Create(newCategory.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0.2}):Play()
            tweenService:Create(newCategory.UIGradient, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Offset = Vector2.new(0, 0.65)}):Play()
            tweenService:Create(newCategory.UIStroke.UIGradient, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Offset = Vector2.new(0, 0.4)}):Play()
            tweenService:Create(newCategory.Shadow.UIGradient, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Offset = Vector2.new(0, 0.4)}):Play()
        end)

        for _, setting in ipairs(category.categorySettings) do
            if not setting.hidden then
                local settingType = setting.settingType
                local minimumLicense = setting.minimumLicense
                local object = nil

                if settingType == "Boolean" then
                    local newSwitch = settingsPanel.SettingLists.Template.SwitchTemplate:Clone()
                    object = newSwitch
                    newSwitch.Name = setting.name
                    newSwitch.Parent = newList
                    newSwitch.Visible = true
                    newSwitch.Title.Text = setting.name

                    if setting.current == true then
                        newSwitch.Switch.Indicator.Position = UDim2.new(1, -20, 0.5, 0)
                        newSwitch.Switch.Indicator.UIStroke.Color = Color3.fromRGB(220, 220, 220)
                        newSwitch.Switch.Indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                        newSwitch.Switch.Indicator.BackgroundTransparency = 0.6
                    end

                    newSwitch.Interact.MouseButton1Click:Connect(function()
                        setting.current = not setting.current
                        saveSettings()
                        if setting.current == true then
                            tweenService:Create(newSwitch.Switch.Indicator, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -20, 0.5, 0)}):Play()
                            tweenService:Create(newSwitch.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,12,0,12)}):Play()
                            tweenService:Create(newSwitch.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = Color3.fromRGB(200, 200, 200)}):Play()
                            tweenService:Create(newSwitch.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
                            tweenService:Create(newSwitch.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = 0.5}):Play()
                            tweenService:Create(newSwitch.Switch.Indicator, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = 0.6}):Play()
                            task.wait(0.05)
                            tweenService:Create(newSwitch.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,17,0,17)}):Play()
                        else
                            tweenService:Create(newSwitch.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -40, 0.5, 0)}):Play()
                            tweenService:Create(newSwitch.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,12,0,12)}):Play()
                            tweenService:Create(newSwitch.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = Color3.fromRGB(255, 255, 255)}):Play()
                            tweenService:Create(newSwitch.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = 0.7}):Play()
                            tweenService:Create(newSwitch.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(235, 235, 235)}):Play()
                            tweenService:Create(newSwitch.Switch.Indicator, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = 0.75}):Play()
                            task.wait(0.05)
                            tweenService:Create(newSwitch.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,17,0,17)}):Play()
                        end
                    end)

                elseif settingType == "Input" or settingType == "Number" then
                    local newInput = settingsPanel.SettingLists.Template.InputTemplate:Clone()
                    object = newInput
                    newInput.Name = setting.name
                    newInput.InputFrame.InputBox.Text = tostring(setting.current)
                    newInput.InputFrame.InputBox.PlaceholderText = setting.placeholder or (settingType == "Number" and "number" or "input")
                    newInput.Parent = newList
                    newInput.Visible = true
                    newInput.Title.Text = setting.name
                    newInput.InputFrame.InputBox.TextWrapped = false
                    newInput.InputFrame.Size = UDim2.new(0, newInput.InputFrame.InputBox.TextBounds.X + 24, 0, 30)

                    newInput.InputFrame.InputBox.FocusLost:Connect(function()
                        if settingType == "Number" then
                            local inputValue = tonumber(newInput.InputFrame.InputBox.Text)
                            if inputValue then
                                if setting.values then
                                    setting.current = math.clamp(inputValue, setting.values[1], setting.values[2])
                                else
                                    setting.current = inputValue
                                end
                                newInput.InputFrame.InputBox.Text = tostring(setting.current)
                            else
                                newInput.InputFrame.InputBox.Text = tostring(setting.current)
                            end
                        else
                            if newInput.InputFrame.InputBox.Text ~= nil or "" then
                                setting.current = newInput.InputFrame.InputBox.Text
                            end
                        end
                        saveSettings()
                    end)

                    newInput.InputFrame.InputBox:GetPropertyChangedSignal("Text"):Connect(function()
                        tweenService:Create(newInput.InputFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, newInput.InputFrame.InputBox.TextBounds.X + 24, 0, 30)}):Play()
                    end)

                elseif settingType == "Key" then
                    local newKeybind = settingsPanel.SettingLists.Template.InputTemplate:Clone()
                    object = newKeybind
                    newKeybind.Name = setting.name
                    newKeybind.InputFrame.InputBox.PlaceholderText = setting.placeholder or "listening.."
                    newKeybind.InputFrame.InputBox.Text = setting.current or "No Keybind"
                    newKeybind.Parent = newList
                    newKeybind.Visible = true
                    newKeybind.Title.Text = setting.name
                    newKeybind.InputFrame.InputBox.TextWrapped = false
                    newKeybind.InputFrame.Size = UDim2.new(0, newKeybind.InputFrame.InputBox.TextBounds.X + 24, 0, 30)

                    newKeybind.InputFrame.InputBox.FocusLost:Connect(function()
                        checkingForKey = false
                        if newKeybind.InputFrame.InputBox.Text == nil or newKeybind.InputFrame.InputBox.Text == "" then
                            newKeybind.InputFrame.InputBox.Text = "No Keybind"
                            setting.current = nil
                            newKeybind.InputFrame.InputBox:ReleaseFocus()
                            saveSettings()
                        end
                    end)

                    newKeybind.InputFrame.InputBox.Focused:Connect(function()
                        checkingForKey = {data = setting, object = newKeybind}
                        newKeybind.InputFrame.InputBox.Text = ""
                    end)

                    newKeybind.InputFrame.InputBox:GetPropertyChangedSignal("Text"):Connect(function()
                        tweenService:Create(newKeybind.InputFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, newKeybind.InputFrame.InputBox.TextBounds.X + 24, 0, 30)}):Play()
                    end)
                end

                if object then
                    if setting.description then
                        object.Description.Visible = true
                        object.Description.TextWrapped = true
                        object.Description.Size = UDim2.new(0, 333, 0, 999)
                        object.Description.Text = setting.description
                        object.Description.Size = UDim2.new(0, 333, 0, object.Description.TextBounds.Y + 10)
                        object.Size = UDim2.new(0, 558, 0, object.Description.TextBounds.Y + 44)
                    end

                    local objectTouching
                    object.MouseEnter:Connect(function()
                        objectTouching = true
                        tweenService:Create(object.UIStroke, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = 0.45}):Play()
                        tweenService:Create(object, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = 0.83}):Play()
                    end)

                    object.MouseLeave:Connect(function()
                        objectTouching = false
                        tweenService:Create(object.UIStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = 0.6}):Play()
                        tweenService:Create(object, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = 0.9}):Play()
                    end)
                end
            end
        end
    end
end

local function initialiseAntiKick()
    if checkSetting("Client-Based Anti Kick").current then
        if hookmetamethod then
            local originalIndex
            local originalNamecall

            originalIndex = hookmetamethod(game, "__index", function(self, method)
                if self == localPlayer and method:lower() == "kick" and checkSetting("Client-Based Anti Kick").current and checkLarping() then
                    queueNotification("Kick Prevented", "larping.win has prevented you from being kicked by the client.", 4400699701)
                    return error("Expected ':' not '.' calling member function Kick", 2)
                end
                return originalIndex(self, method)
            end)

            originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                if self == localPlayer and getnamecallmethod():lower() == "kick" and checkSetting("Client-Based Anti Kick").current and checkLarping() then
                    queueNotification("Kick Prevented", "larping.win has prevented you from being kicked by the client.", 4400699701)
                    return
                end
                return originalNamecall(self, ...)
            end)
        end
    end
end

local function start()
    windowFocusChanged(true)

    UI.Enabled = true

    assembleSettings()
    ensureFrameProperties()
    sortActions()
    populateServersidePanel()
    initialiseAntiKick()

    smartBar.Time.Text = os.date("%H")..":"..os.date("%M")

    toggle.Visible = not checkSetting("Hide Toggle Button").current

    if not checkSetting("Load Hidden").current then
        openSmartBar()
    else
        closeSmartBar()
    end

    queueNotification(
        "larping.win | serverside",
        "Welcome! Based on Sirius. Open the Serverside panel to execute scripts.",
        4400701828
    )
end

-- ====================== EVENTS ======================

start()

toggle.MouseButton1Click:Connect(function()
    if smartBarOpen then
        closeSmartBar()
    else
        openSmartBar()
    end
end)

characterPanel.Interactions.Reset.MouseButton1Click:Connect(function()
    resetSliders()
    characterPanel.Interactions.Reset.Rotation = 360
    queueNotification("Slider Values Reset","Successfully reset all character panel sliders", 4400696294)
    tweenService:Create(characterPanel.Interactions.Reset, TweenInfo.new(.5,Enum.EasingStyle.Back), {Rotation = 0}):Play()
end)

characterPanel.Interactions.Reset.MouseEnter:Connect(function() if debounce then return end tweenService:Create(characterPanel.Interactions.Reset, TweenInfo.new(.5,Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play() end)
characterPanel.Interactions.Reset.MouseLeave:Connect(function() if debounce then return end tweenService:Create(characterPanel.Interactions.Reset, TweenInfo.new(.5,Enum.EasingStyle.Quint), {ImageTransparency = 0.7}):Play() end)

local playerSearch = playerlistPanel.Interactions.SearchFrame.SearchBox

playerSearch:GetPropertyChangedSignal("Text"):Connect(function()
    for _, player in ipairs(playerlistPanel.Interactions.List:GetChildren()) do
        if player.ClassName == "Frame" and player.Name ~= "Placeholder" and player.Name ~= "Template" then
            if string.find(player.Name, playerSearch.Text) then
                player.Visible = true
            else
                player.Visible = false
            end
        end
    end

    if #playerSearch.Text == 0 then
        searchingForPlayer = false
        for _, player in ipairs(playerlistPanel.Interactions.List:GetChildren()) do
            if player.ClassName == "Frame" and player.Name ~= "Placeholder" and player.Name ~= "Template" then
                player.Visible = true
            end
        end
    else
        searchingForPlayer = true
    end
end)

characterPanel.Interactions.Serverhop.MouseEnter:Connect(function()
    if debounce then return end
    tweenService:Create(characterPanel.Interactions.Serverhop, TweenInfo.new(.5,Enum.EasingStyle.Quint), {BackgroundTransparency = 0.5}):Play()
    tweenService:Create(characterPanel.Interactions.Serverhop.Title, TweenInfo.new(.5,Enum.EasingStyle.Quint), {TextTransparency = 0.1}):Play()
    tweenService:Create(characterPanel.Interactions.Serverhop.UIStroke, TweenInfo.new(.5,Enum.EasingStyle.Quint), {Transparency = 1}):Play()
end)

characterPanel.Interactions.Serverhop.MouseLeave:Connect(function()
    if debounce then return end
    tweenService:Create(characterPanel.Interactions.Serverhop, TweenInfo.new(.5,Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
    tweenService:Create(characterPanel.Interactions.Serverhop.Title, TweenInfo.new(.5,Enum.EasingStyle.Quint), {TextTransparency = 0.5}):Play()
    tweenService:Create(characterPanel.Interactions.Serverhop.UIStroke, TweenInfo.new(.5,Enum.EasingStyle.Quint), {Transparency = 0}):Play()
end)

characterPanel.Interactions.Rejoin.MouseEnter:Connect(function()
    if debounce then return end
    tweenService:Create(characterPanel.Interactions.Rejoin, TweenInfo.new(.5,Enum.EasingStyle.Quint), {BackgroundTransparency = 0.5}):Play()
    tweenService:Create(characterPanel.Interactions.Rejoin.Title, TweenInfo.new(.5,Enum.EasingStyle.Quint), {TextTransparency = 0.1}):Play()
    tweenService:Create(characterPanel.Interactions.Rejoin.UIStroke, TweenInfo.new(.5,Enum.EasingStyle.Quint), {Transparency = 1}):Play()
end)

characterPanel.Interactions.Rejoin.MouseLeave:Connect(function()
    if debounce then return end
    tweenService:Create(characterPanel.Interactions.Rejoin, TweenInfo.new(.5,Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
    tweenService:Create(characterPanel.Interactions.Rejoin.Title, TweenInfo.new(.5,Enum.EasingStyle.Quint), {TextTransparency = 0.5}):Play()
    tweenService:Create(characterPanel.Interactions.Rejoin.UIStroke, TweenInfo.new(.5,Enum.EasingStyle.Quint), {Transparency = 0}):Play()
end)

musicPanel.Close.MouseButton1Click:Connect(function()
    if musicPanel.Visible and not debounce then closeMusic() end
end)

musicPanel.Add.Interact.MouseButton1Click:Connect(function()
    musicPanel.AddBox.Input:ReleaseFocus()
    addToQueue(musicPanel.AddBox.Input.Text)
end)

musicPanel.Menu.TogglePlaying.MouseButton1Click:Connect(function()
    if currentAudio then
        currentAudio.Playing = not currentAudio.Playing
        musicPanel.Menu.TogglePlaying.ImageRectOffset = currentAudio.Playing and Vector2.new(804, 124) or Vector2.new(764, 244)
    end
end)

musicPanel.Menu.Next.MouseButton1Click:Connect(function()
    if currentAudio then
        if #musicQueue == 0 then currentAudio.Playing = false currentAudio.SoundId = "" return end
        if musicPanel.Queue.List:FindFirstChild(tostring(musicQueue[1].instanceName)) then
            musicPanel.Queue.List:FindFirstChild(tostring(musicQueue[1].instanceName)):Destroy()
        end
        musicPanel.Menu.TogglePlaying.ImageRectOffset = currentAudio.Playing and Vector2.new(804, 124) or Vector2.new(764, 244)
        table.remove(musicQueue, 1)
        playNext()
    end
end)

characterPanel.Interactions.Rejoin.Interact.MouseButton1Click:Connect(rejoin)
characterPanel.Interactions.Serverhop.Interact.MouseButton1Click:Connect(serverhop)

smartBar.Buttons.Music.Interact.MouseButton1Click:Connect(function()
    if debounce then return end
    if musicPanel.Visible then closeMusic() else openMusic() end
end)

smartBar.Buttons.Home.Interact.MouseButton1Click:Connect(function()
    if debounce then return end
    if homeContainer.Visible then closeHome() else openHome() end
end)

smartBar.Buttons.Settings.Interact.MouseButton1Click:Connect(function()
    if debounce then return end
    if settingsPanel.Visible then closeSettings() else openSettings() end
end)

for _, button in ipairs(smartBar.Buttons:GetChildren()) do
    if UI:FindFirstChild(button.Name) and button:FindFirstChild("Interact") then
        button.Interact.MouseButton1Click:Connect(function()
            if isPanel(button.Name) then
                if not debounce and UI:FindFirstChild(button.Name).Visible then
                    task.spawn(closePanel, button.Name)
                else
                    task.spawn(openPanel, button.Name)
                end
            end

            tweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Size = UDim2.new(0,28,0,28)}):Play()
            tweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.6}):Play()
            tweenService:Create(button.Icon, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 0.6}):Play()
            task.wait(0.15)
            tweenService:Create(button, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Size = UDim2.new(0,36,0,36)}):Play()
            tweenService:Create(button, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
            tweenService:Create(button.Icon, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {ImageTransparency = 0.02}):Play()
        end)

        button.MouseEnter:Connect(function()
            tweenService:Create(button.UIGradient, TweenInfo.new(1.4, Enum.EasingStyle.Quint), {Rotation = 360}):Play()
            tweenService:Create(button.UIStroke.UIGradient, TweenInfo.new(1.4, Enum.EasingStyle.Quint), {Rotation = 360}):Play()
            tweenService:Create(button.UIStroke, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
            tweenService:Create(button.Icon, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
            tweenService:Create(button.UIGradient, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Offset = Vector2.new(0,-0.5)}):Play()
        end)

        button.MouseLeave:Connect(function()
            tweenService:Create(button.UIStroke.UIGradient, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Rotation = 50}):Play()
            tweenService:Create(button.UIGradient, TweenInfo.new(0.9, Enum.EasingStyle.Quint), {Rotation = 50}):Play()
            tweenService:Create(button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
            tweenService:Create(button.Icon, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 0.05}):Play()
            tweenService:Create(button.UIGradient, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Offset = Vector2.new(0,0)}):Play()
        end)
    end
end

userInputService.InputBegan:Connect(function(input, processed)
    if not checkLarping() then return end

    if checkingForKey then
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            local splitMessage = string.split(tostring(input.KeyCode), ".")
            local newKeyNoEnum = splitMessage[3]
            checkingForKey.object.InputFrame.InputBox.Text = tostring(newKeyNoEnum)
            checkingForKey.data.current = tostring(newKeyNoEnum)
            checkingForKey.object.InputFrame.InputBox:ReleaseFocus()
            saveSettings()
        end
        return
    end

    for _, category in ipairs(larpingSettings) do
        for _, setting in ipairs(category.categorySettings) do
            if setting.settingType == "Key" then
                if setting.current ~= nil and setting.current ~= "" then
                    if input.KeyCode == Enum.KeyCode[setting.current] and not processed then
                        if setting.callback then
                            task.spawn(setting.callback)

                            local action = checkAction(setting.name) or nil
                            if action then
                                local object = action.object
                                action = action.action

                                if action.enabled then
                                    object.Icon.Image = "rbxassetid://"..action.images[1]
                                    tweenService:Create(object, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.1}):Play()
                                    tweenService:Create(object.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
                                    tweenService:Create(object.Icon, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {ImageTransparency = 0.1}):Play()

                                    if action.disableAfter then
                                        task.delay(action.disableAfter, function()
                                            action.enabled = false
                                            object.Icon.Image = "rbxassetid://"..action.images[2]
                                            tweenService:Create(object, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.55}):Play()
                                            tweenService:Create(object.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0.4}):Play()
                                            tweenService:Create(object.Icon, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {ImageTransparency = 0.5}):Play()
                                        end)
                                    end

                                    if action.rotateWhileEnabled then
                                        repeat
                                            object.Icon.Rotation = 0
                                            tweenService:Create(object.Icon, TweenInfo.new(0.75, Enum.EasingStyle.Quint), {Rotation = 360}):Play()
                                            task.wait(1)
                                        until not action.enabled
                                        object.Icon.Rotation = 0
                                    end
                                else
                                    object.Icon.Image = "rbxassetid://"..action.images[2]
                                    tweenService:Create(object, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.55}):Play()
                                    tweenService:Create(object.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0.4}):Play()
                                    tweenService:Create(object.Icon, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {ImageTransparency = 0.5}):Play()
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local scriptSearchSetting = checkSetting("Open ScriptSearch")
    if scriptSearchSetting and scriptSearchSetting.current then
        if input.KeyCode == Enum.KeyCode[scriptSearchSetting.current] and not processed and not debounce then
            if scriptSearch.Visible then
                closeScriptSearch()
            else
                openScriptSearch()
            end
        end
    end

    local smartBarSetting = checkSetting("Toggle smartBar")
    if smartBarSetting and smartBarSetting.current then
        if input.KeyCode == Enum.KeyCode[smartBarSetting.current] and not processed and not debounce then
            if smartBarOpen then
                closeSmartBar()
            else
                openSmartBar()
            end
        end
    end
end)

userInputService.InputEnded:Connect(function(input, processed)
    if not checkLarping() then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        for _, slider in pairs(larpingValues.sliders) do
            slider.active = false

            if characterPanel.Visible and not debounce and slider.object and checkLarping() then
                tweenService:Create(slider.object, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.8}):Play()
                tweenService:Create(slider.object.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
                tweenService:Create(slider.object.Information, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 0.3}):Play()
            end
        end
    end
end)

camera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
    task.wait(.5)
    updateSliderPadding()
end)

scriptSearch.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    if #scriptSearch.SearchBox.Text > 0 then
        tweenService:Create(scriptSearch.Icon, TweenInfo.new(.5,Enum.EasingStyle.Quint), {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        tweenService:Create(scriptSearch.SearchBox, TweenInfo.new(.5,Enum.EasingStyle.Quint), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    else
        tweenService:Create(scriptSearch.Icon, TweenInfo.new(.5,Enum.EasingStyle.Quint), {ImageColor3 = Color3.fromRGB(150, 150, 150)}):Play()
        tweenService:Create(scriptSearch.SearchBox, TweenInfo.new(.5,Enum.EasingStyle.Quint), {TextColor3 = Color3.fromRGB(150, 150, 150)}):Play()
    end
end)

scriptSearch.SearchBox.FocusLost:Connect(function(enterPressed)
    tweenService:Create(scriptSearch.Icon, TweenInfo.new(.5,Enum.EasingStyle.Quint), {ImageColor3 = Color3.fromRGB(150, 150, 150)}):Play()
    tweenService:Create(scriptSearch.SearchBox, TweenInfo.new(.5,Enum.EasingStyle.Quint), {TextColor3 = Color3.fromRGB(150, 150, 150)}):Play()

    if #scriptSearch.SearchBox.Text > 0 then
        if enterPressed then
            -- Simple ScriptBlox search via HTTP
            task.spawn(function()
                local response
                local success = pcall(function()
                    local req = httpRequest({
                        Url = "https://scriptblox.com/api/script/search?q="..httpService:UrlEncode(scriptSearch.SearchBox.Text).."&mode=free&max=20&page=1",
                        Method = "GET"
                    })
                    response = httpService:JSONDecode(req.Body)
                end)

                if success and response and response.result then
                    for _, scriptResult in pairs(response.result.scripts) do
                        local newScript = UI.ScriptSearch.List.Template:Clone()
                        newScript.Name = scriptResult.title
                        newScript.Parent = UI.ScriptSearch.List
                        newScript.Visible = true
                        newScript.ScriptName.Text = scriptResult.title

                        newScript.Execute.MouseButton1Click:Connect(function()
                            queueNotification("ScriptSearch", "Running "..scriptResult.title, 4384403532)
                            closeScriptSearch()
                            pcall(function() loadstring(scriptResult.script)() end)
                        end)
                    end
                    scriptSearch.List.Visible = true
                end
            end)
        end
    else
        closeScriptSearch()
    end
end)

mouse.Move:Connect(function()
    for _, slider in pairs(larpingValues.sliders) do
        if slider.active then
            updateSlider(slider)
        end
    end
end)

userInputService.WindowFocusReleased:Connect(function() windowFocusChanged(false) end)
userInputService.WindowFocused:Connect(function() windowFocusChanged(true) end)

for index, player in ipairs(players:GetPlayers()) do
    createPlayer(player)
    createEsp(player)
    player.Chatted:Connect(function(message) onChatted(player, message) end)
end

players.PlayerAdded:Connect(function(player)
    if not checkLarping() then return end

    createPlayer(player)
    createEsp(player)

    player.Chatted:Connect(function(message) onChatted(player, message) end)

    if checkSetting("Log PlayerAdded and PlayerRemoving") and checkSetting("Log PlayerAdded and PlayerRemoving").current then
        local logData = {
            ["content"] = player.DisplayName.." (@"..player.Name..") joined the server.",
            ["avatar_url"] = "https://www.roblox.com/headshot-thumbnail/image?userId="..player.UserId.."&width=420&height=420&format=png",
            ["username"] = player.DisplayName,
            ["allowed_mentions"] = {parse = {}}
        }
        logData = httpService:JSONEncode(logData)
        pcall(function()
            originalRequest({
                Url = checkSetting("Player Added and Removing Webhook URL").current,
                Method = 'POST',
                Headers = { ['Content-Type'] = 'application/json' },
                Body = logData
            })
        end)
    end

    if checkSetting("Moderator Detection") and checkSetting("Moderator Detection").current and Pro then
        local roleFound = player:GetRoleInGroup(creatorId)
        if larpingValues.currentCreator == "group" then
            for _, role in pairs(larpingValues.administratorRoles) do
                if string.find(string.lower(roleFound), role) then
                    promptModerator(player, roleFound)
                    queueNotification("Administrator Joined", roleFound.." "..player.DisplayName.." has joined your session", 3944670656)
                end
            end
        end
    end

    if checkSetting("Friend Notifications") and checkSetting("Friend Notifications").current then
        if localPlayer:IsFriendsWith(player.UserId) then
            queueNotification("Friend Joined", "Your friend "..player.DisplayName.." has joined your server.", 4370335364)
        end
    end
end)

players.PlayerRemoving:Connect(function(player)
    if checkSetting("Log PlayerAdded and PlayerRemoving") and checkSetting("Log PlayerAdded and PlayerRemoving").current then
        local logData = {
            ["content"] = player.DisplayName.." (@"..player.Name..") left the server.",
            ["avatar_url"] = "https://www.roblox.com/headshot-thumbnail/image?userId="..player.UserId.."&width=420&height=420&format=png",
            ["username"] = player.DisplayName,
            ["allowed_mentions"] = {parse = {}}
        }
        logData = httpService:JSONEncode(logData)
        pcall(function()
            originalRequest({
                Url = checkSetting("Player Added and Removing Webhook URL").current,
                Method = 'POST',
                Headers = { ['Content-Type'] = 'application/json' },
                Body = logData
            })
        end)
    end

    removePlayer(player)

    local highlight = espContainer:FindFirstChild(player.Name)
    if highlight then highlight:Destroy() end
end)

runService.RenderStepped:Connect(function(frame)
    if not checkLarping() then return end
    local fps = math.round(1/frame)

    table.insert(larpingValues.frameProfile.fpsQueue, fps)
    larpingValues.frameProfile.totalFPS += fps

    if #larpingValues.frameProfile.fpsQueue > larpingValues.frameProfile.fpsQueueSize then
        larpingValues.frameProfile.totalFPS -= larpingValues.frameProfile.fpsQueue[1]
        table.remove(larpingValues.frameProfile.fpsQueue, 1)
    end
end)

runService.Stepped:Connect(function()
    if not checkLarping() then return end

    local character = localPlayer.Character
    if character then
        local noclipEnabled = larpingValues.actions[1].enabled
        local flingEnabled = larpingValues.actions[6].enabled

        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if noclipDefaults[part] == nil then
                    task.wait()
                    noclipDefaults[part] = part.CanCollide
                else
                    if noclipEnabled or flingEnabled then
                        part.CanCollide = false
                    else
                        part.CanCollide = noclipDefaults[part]
                    end
                end
            end
        end
    end
end)

runService.Heartbeat:Connect(function()
    if not checkLarping() then return end

    local character = localPlayer.Character
    local primaryPart = character and character.PrimaryPart
    if primaryPart then
        local bodyVelocity, bodyGyro = unpack(movers)
        if not bodyVelocity then
            bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.one * 9e9

            bodyGyro = Instance.new("BodyGyro")
            bodyGyro.MaxTorque = Vector3.one * 9e9
            bodyGyro.P = 9e4

            local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
            bodyAngularVelocity.AngularVelocity = Vector3.yAxis * 9e9
            bodyAngularVelocity.MaxTorque = Vector3.yAxis * 9e9
            bodyAngularVelocity.P = 9e9

            movers = { bodyVelocity, bodyGyro, bodyAngularVelocity }
        end

        if larpingValues.actions[2].enabled then
            local camCFrame = camera.CFrame
            local velocity = Vector3.zero
            local rotation = camCFrame.Rotation

            if userInputService:IsKeyDown(Enum.KeyCode.W) then velocity += camCFrame.LookVector rotation *= CFrame.Angles(math.rad(-40), 0, 0) end
            if userInputService:IsKeyDown(Enum.KeyCode.S) then velocity -= camCFrame.LookVector rotation *= CFrame.Angles(math.rad(40), 0, 0) end
            if userInputService:IsKeyDown(Enum.KeyCode.D) then velocity += camCFrame.RightVector rotation *= CFrame.Angles(0, 0, math.rad(-40)) end
            if userInputService:IsKeyDown(Enum.KeyCode.A) then velocity -= camCFrame.RightVector rotation *= CFrame.Angles(0, 0, math.rad(40)) end
            if userInputService:IsKeyDown(Enum.KeyCode.Space) then velocity += Vector3.yAxis end
            if userInputService:IsKeyDown(Enum.KeyCode.LeftShift) then velocity -= Vector3.yAxis end

            local tweenInfo = TweenInfo.new(0.5)
            tweenService:Create(bodyVelocity, tweenInfo, { Velocity = velocity * larpingValues.sliders[3].value * 45 }):Play()
            bodyVelocity.Parent = primaryPart

            if not larpingValues.actions[6].enabled then
                tweenService:Create(bodyGyro, tweenInfo, { CFrame = rotation }):Play()
                bodyGyro.Parent = primaryPart
            end
        else
            bodyVelocity.Parent = nil
            bodyGyro.Parent = nil
        end
    end
end)

runService.Heartbeat:Connect(function(frame)
    if not checkLarping() then return end

    if checkSetting("Anonymous Client") and checkSetting("Anonymous Client").current then
        for _, text in ipairs(cachedText) do
            local lowerText = string.lower(text.Text)
            if string.find(lowerText, lowerName, 1, true) or string.find(lowerText, lowerDisplayName, 1, true) then
                storeOriginalText(text)
                local newText = string.gsub(string.gsub(lowerText, lowerName, randomUsername), lowerDisplayName, randomUsername)
                text.Text = string.gsub(newText, "^%l", string.upper)
            end
        end
    else
        undoAnonymousChanges()
    end
end)

for _, instance in next, game:GetDescendants() do
    if instance:IsA("Sound") then
        if not table.find(cachedIds, instance.SoundId) then
            table.insert(soundInstances, instance)
            table.insert(cachedIds, instance.SoundId)
        end
    elseif instance:IsA("TextLabel") or instance:IsA("TextButton") then
        if not table.find(cachedText, instance) then
            table.insert(cachedText, instance)
        end
    end
end

game.DescendantAdded:Connect(function(instance)
    if checkLarping() then
        if instance:IsA("Sound") then
            if not table.find(cachedIds, instance.SoundId) then
                table.insert(soundInstances, instance)
                table.insert(cachedIds, instance.SoundId)
            end
        elseif instance:IsA("TextLabel") or instance:IsA("TextButton") then
            if not table.find(cachedText, instance) then
                table.insert(cachedText, instance)
            end
        end
    end
end)

while task.wait(1) do
    if not checkLarping() then
        if espContainer then espContainer:Destroy() end
        undoAnonymousChanges()
        break
    end

    smartBar.Time.Text = os.date("%H")..":"..os.date("%M")
    task.spawn(UpdateHome)

    if getconnections then
        for _, connection in getconnections(localPlayer.Idled) do
            if not checkSetting("Anti Idle").current then connection:Enable() else connection:Disable() end
        end
    end

    toggle.Visible = not checkSetting("Hide Toggle Button").current

    local disconnectedRobloxUI = coreGui.RobloxPromptGui.promptOverlay:FindFirstChild("ErrorPrompt")

    if disconnectedRobloxUI and not promptedDisconnected then
        local reasonPrompt = disconnectedRobloxUI.MessageArea.ErrorFrame.ErrorMessage.Text

        promptedDisconnected = true
        disconnectedPrompt.Parent = coreGui.RobloxPromptGui

        local disconnectType
        local foundString

        for _, preDisconnectType in ipairs(larpingValues.disconnectTypes) do
            for _, typeString in pairs(preDisconnectType[2]) do
                if string.find(reasonPrompt, typeString) then
                    disconnectType = preDisconnectType[1]
                    foundString = true
                    break
                end
            end
        end

        if not foundString then disconnectType = "kick" end

        wipeTransparency(disconnectedPrompt, 1, true)
        disconnectedPrompt.Visible = true

        if disconnectType == "ban" then
            disconnectedPrompt.Content.Text = "You've been banned, would you like to leave?"
            disconnectedPrompt.Action.Text = "Leave"
            disconnectedPrompt.Action.Size = UDim2.new(0, 77, 0, 36)
            disconnectedPrompt.UIGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),ColorSequenceKeypoint.new(1, Color3.new(0.819608, 0.164706, 0.164706))})
        elseif disconnectType == "kick" then
            disconnectedPrompt.Content.Text = "You've been kicked. Would you like to serverhop?"
            disconnectedPrompt.Action.Text = "Serverhop"
            disconnectedPrompt.Action.Size = UDim2.new(0, 114, 0, 36)
            disconnectedPrompt.UIGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),ColorSequenceKeypoint.new(1, Color3.new(0.0862745, 0.596078, 0.835294))})
        elseif disconnectType == "network" then
            disconnectedPrompt.Content.Text = "You've lost connection. Would you like to rejoin?"
            disconnectedPrompt.Action.Text = "Rejoin"
            disconnectedPrompt.Action.Size = UDim2.new(0, 82, 0, 36)
            disconnectedPrompt.UIGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),ColorSequenceKeypoint.new(1, Color3.new(0.862745, 0.501961, 0.0862745))})
        end

        tweenService:Create(disconnectedPrompt, TweenInfo.new(.5,Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
        tweenService:Create(disconnectedPrompt.Title, TweenInfo.new(.5,Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
        tweenService:Create(disconnectedPrompt.Content, TweenInfo.new(.5,Enum.EasingStyle.Quint), {TextTransparency = 0.3}):Play()
        tweenService:Create(disconnectedPrompt.Action, TweenInfo.new(.5,Enum.EasingStyle.Quint), {BackgroundTransparency = 0.7}):Play()
        tweenService:Create(disconnectedPrompt.Action, TweenInfo.new(.5,Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()

        disconnectedPrompt.Action.MouseButton1Click:Connect(function()
            if disconnectType == "ban" then game:Shutdown()
            elseif disconnectType == "kick" then serverhop()
            elseif disconnectType == "network" then rejoin() end
        end)
    end

    -- Adaptive latency/FPS checks
    if Pro then
        if checkHighPing() then
            if larpingValues.pingProfile.pingNotificationCooldown <= 0 then
                if checkSetting("Adaptive Latency Warning") and checkSetting("Adaptive Latency Warning").current then
                    queueNotification("High Latency Warning","Your latency has spiked above your average. Consider checking background downloads.", 4370305588)
                    larpingValues.pingProfile.pingNotificationCooldown = 120
                end
            end
        end

        if larpingValues.pingProfile.pingNotificationCooldown > 0 then
            larpingValues.pingProfile.pingNotificationCooldown -= 1
        end

        if larpingValues.frameProfile.frameNotificationCooldown <= 0 then
            if #larpingValues.frameProfile.fpsQueue > 0 then
                local avgFPS = larpingValues.frameProfile.totalFPS / #larpingValues.frameProfile.fpsQueue
                if avgFPS < larpingValues.frameProfile.lowFPSThreshold then
                    if checkSetting("Adaptive Performance Warning") and checkSetting("Adaptive Performance Warning").current then
                        queueNotification("Degraded Performance","Your FPS has decreased. Consider checking background tasks.", 4384400106)
                        larpingValues.frameProfile.frameNotificationCooldown = 120
                    end
                end
            end
        end

        if larpingValues.frameProfile.frameNotificationCooldown > 0 then
            larpingValues.frameProfile.frameNotificationCooldown -= 1
        end
    end
end

return larpingWin

end -- end init()

-- ====================== MODULE RETURN ======================
-- Usage: require(ID)("Username")
return function(username)
    init(username)
    return larpingWin
end
