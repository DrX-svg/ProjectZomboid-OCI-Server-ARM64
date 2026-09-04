local USER = "PregenBOT"
local MODULE = "RBXPregen"

local QUEUE_FILE = "RBXPregen_queue.txt"
local CONTROL_FILE = "RBXPregen_control.txt"
local CHECKPOINT_FILE = "RBXPregen_checkpoint.txt"
local STATUS_FILE = "RBXPregen_status.txt"

local DWELL_MS = 8000
local TIMEOUT_MS = 20000

local queue = {}
local index = 1
local teleports = 0

local control = "pause"
local runCount = 0
local runLimit = nil

local initialized = false
local pending = nil
local nextAllowed = 0
local lastControlCheck = 0


local function log(msg)
    print("[RBXPregen] " .. tostring(msg))
end


local function readLines(name)
    local ok, r = pcall(function()
        return getFileReader(name, false)
    end)

    if not ok or not r then
        return nil
    end

    local lines = {}

    while true do
        local line = r:readLine()
        if not line then break end
        table.insert(lines, tostring(line))
    end

    r:close()
    return lines
end


local function writeFile(name, text)
    local w = getFileWriter(name, true, false)
    w:write(text)
    w:close()
end


local function findPlayer()
    local players = getOnlinePlayers()

    if not players then
        return nil
    end

    for i = 0, players:size() - 1 do
        local p = players:get(i)

        if p and p:getUsername() == USER then
            return p
        end
    end

    return nil
end


local function setControl(value)
    control = value
    writeFile(CONTROL_FILE, value .. "\n")
end


local function readControl()
    local lines = readLines(CONTROL_FILE)

    if not lines or not lines[1] then
        return "pause"
    end

    local v = tostring(lines[1]):lower():match("^%s*(.-)%s*$")

    if v == "run" or
       v == "run1" or
       v == "run20" or
       v == "done" then
        return v
    end

    return "pause"
end


local function saveCheckpoint()
    writeFile(
        CHECKPOINT_FILE,
        "index=" .. tostring(index) .. "\n" ..
        "teleports=" .. tostring(teleports) .. "\n"
    )
end


local function loadCheckpoint()
    local lines = readLines(CHECKPOINT_FILE)
    if not lines then return end

    for _, line in ipairs(lines) do
        local k, v = line:match("^([^=]+)=(.*)$")

        if k == "index" then
            index = tonumber(v) or 1
        elseif k == "teleports" then
            teleports = tonumber(v) or 0
        end
    end
end


local function writeStatus(reason, x, y, err)
    writeFile(
        STATUS_FILE,
        "reason=" .. tostring(reason) .. "\n" ..
        "control=" .. tostring(control) .. "\n" ..
        "index=" .. tostring(index) .. "\n" ..
        "queue_total=" .. tostring(#queue) .. "\n" ..
        "teleports=" .. tostring(teleports) .. "\n" ..
        "target_x=" .. tostring(x or "") .. "\n" ..
        "target_y=" .. tostring(y or "") .. "\n" ..
        "player_online=" .. tostring(findPlayer() ~= nil) .. "\n" ..
        "pending=" .. tostring(pending ~= nil) .. "\n" ..
        "error=" .. tostring(err or "") .. "\n" ..
        "updated_epoch=" .. tostring(getTimestamp()) .. "\n"
    )
end


local function initialize()
    local lines = readLines(QUEUE_FILE)

    if not lines then
        log("ERROR queue unavailable")
        return false
    end

    for _, line in ipairs(lines) do
        local xs, ys =
            line:match("^%s*(-?%d+),%s*(-?%d+)%s*$")

        if xs and ys then
            table.insert(queue, {
                x = tonumber(xs),
                y = tonumber(ys)
            })
        end
    end

    if #queue == 0 then
        log("ERROR queue empty")
        return false
    end

    loadCheckpoint()

    initialized = true

    log(
        "loaded queue=" .. tostring(#queue) ..
        " checkpoint index=" .. tostring(index) ..
        " teleports=" .. tostring(teleports)
    )

    writeStatus("initialized")

    return true
end


local function onClientCommand(module, command, player, args)
    if module ~= MODULE then return end
    if not player then return end
    if player:getUsername() ~= USER then return end
    if not pending then return end
    if not args then return end

    local ackIndex = tonumber(args.index)

    if ackIndex ~= pending.index then
        return
    end

    if command == "failed" then
        local x = pending.x
        local y = pending.y

        pending = nil
        setControl("pause")

        writeStatus(
            "client-failed",
            x,
            y,
            "client did not reach target"
        )

        log(
            "FAILED index=" ..
            tostring(ackIndex)
        )

        return
    end

    if command ~= "ack" then
        return
    end

    local actualX = player:getX()
    local actualY = player:getY()

    local dx = math.abs(actualX - pending.x)
    local dy = math.abs(actualY - pending.y)

    if dx > 8 or dy > 8 then
        local x = pending.x
        local y = pending.y

        pending = nil
        setControl("pause")

        writeStatus(
            "server-position-mismatch",
            x,
            y,
            "server player position did not match ACK"
        )

        log(
            "POSITION MISMATCH actual=" ..
            tostring(actualX) .. "," ..
            tostring(actualY)
        )

        return
    end

    local completedIndex = pending.index
    local targetX = pending.x
    local targetY = pending.y

    pending = nil

    teleports = teleports + 1
    index = index + 1
    runCount = runCount + 1

    saveCheckpoint()

    log(
        "VALIDATED index=" ..
        tostring(completedIndex) ..
        " target=" ..
        tostring(targetX) .. "," ..
        tostring(targetY) ..
        " actual=" ..
        tostring(actualX) .. "," ..
        tostring(actualY)
    )

    nextAllowed = getTimestampMs() + DWELL_MS

    if runLimit and runCount >= runLimit then
        setControl("pause")

        writeStatus(
            "test-complete",
            targetX,
            targetY
        )

        log(
            "test complete count=" ..
            tostring(runCount)
        )
    else
        writeStatus(
            "validated",
            targetX,
            targetY
        )
    end
end


local function onTick()
    local now = getTimestampMs()

    if not initialized then
        if not initialize() then return end
    end

    if now - lastControlCheck >= 1000 then
        lastControlCheck = now

        local newControl = readControl()

        if newControl ~= control then
            control = newControl
            runCount = 0
            runLimit = nil

            if control == "run1" then
                runLimit = 1
            elseif control == "run20" then
                runLimit = 20
            end

            log("control=" .. tostring(control))
            writeStatus("control-change")
        end
    end

    if control ~= "run" and
       control ~= "run1" and
       control ~= "run20" then
        return
    end

    if pending then
        if now - pending.sentMs > TIMEOUT_MS then
            local x = pending.x
            local y = pending.y
            local i = pending.index

            pending = nil
            setControl("pause")

            writeStatus(
                "timeout",
                x,
                y,
                "no client ACK"
            )

            log(
                "TIMEOUT index=" ..
                tostring(i)
            )
        end

        return
    end

    if now < nextAllowed then
        return
    end

    local player = findPlayer()

    if not player then
        return
    end

    if index > #queue then
        setControl("done")
        saveCheckpoint()
        writeStatus("complete")

        log(
            "COMPLETE teleports=" ..
            tostring(teleports)
        )

        return
    end

    local target = queue[index]

    pending = {
        index = index,
        x = target.x,
        y = target.y,
        sentMs = now
    }

    local ok, err = pcall(function()
        sendServerCommand(
            MODULE,
            "teleport",
            {
                index = index,
                x = target.x,
                y = target.y,
                z = 0
            }
        )
    end)

    if not ok then
        pending = nil
        setControl("pause")

        writeStatus(
            "send-error",
            target.x,
            target.y,
            err
        )

        log(
            "SEND ERROR: " ..
            tostring(err)
        )

        return
    end

    writeStatus(
        "sent",
        target.x,
        target.y
    )

    log(
        "SENT index=" ..
        tostring(index) ..
        " target=" ..
        tostring(target.x) .. "," ..
        tostring(target.y)
    )
end


Events.OnClientCommand.Add(onClientCommand)
Events.OnTick.Add(onTick)

log("ACK controller loaded")
