local USER = "PregenBOT"

local QUEUE_FILE = "RBXPregen_queue.txt"
local CONTROL_FILE = "RBXPregen_control.txt"
local CHECKPOINT_FILE = "RBXPregen_checkpoint.txt"
local STATUS_FILE = "RBXPregen_status.txt"

local INTERVAL_MS = 8000

local queue = {}
local index = 1
local teleports = 0

local control = "pause"
local runCount = 0
local runLimit = nil

local initialized = false
local lastTeleport = 0
local lastControlCheck = 0


local function log(msg)
    print("[RBXPregen] " .. tostring(msg))
end


local function readLines(name)
    local ok, reader = pcall(function()
        return getFileReader(name, false)
    end)

    if not ok or not reader then
        return nil
    end

    local lines = {}

    while true do
        local line = reader:readLine()
        if not line then break end
        table.insert(lines, tostring(line))
    end

    reader:close()
    return lines
end


local function writeFile(name, text)
    local writer = getFileWriter(name, true, false)
    writer:write(text)
    writer:close()
end


local function setControl(value)
    writeFile(CONTROL_FILE, value .. "\n")
    control = value
end


local function readControl()
    local lines = readLines(CONTROL_FILE)

    if not lines or not lines[1] then
        return "pause"
    end

    local value =
        tostring(lines[1]):lower():match("^%s*(.-)%s*$")

    if value == "run" or
       value == "run1" or
       value == "run20" or
       value == "done" then
        return value
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


local function findPregenPlayer()
    local players = getOnlinePlayers()

    if not players then
        return nil
    end

    for i = 0, players:size() - 1 do
        local player = players:get(i)

        if player and player:getUsername() == USER then
            return player
        end
    end

    return nil
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
        "player_online=" ..
            tostring(findPregenPlayer() ~= nil) .. "\n" ..
        "error=" .. tostring(err or "") .. "\n" ..
        "updated_epoch=" .. tostring(getTimestamp()) .. "\n"
    )
end


local function initialize()
    local lines = readLines(QUEUE_FILE)

    if not lines then
        log("ERROR: queue file unavailable")
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
        log("ERROR: queue is empty")
        return false
    end

    loadCheckpoint()

    if index < 1 then index = 1 end
    if index > #queue + 1 then index = #queue + 1 end

    initialized = true

    log(
        "loaded queue=" .. tostring(#queue) ..
        " checkpoint index=" .. tostring(index) ..
        " teleports=" .. tostring(teleports)
    )

    writeStatus("initialized")

    return true
end


local function teleportPlayer(player, x, y)
    local ok, err = pcall(function()

        if player.teleportTo then
            player:teleportTo(
                x + 0.5,
                y + 0.5,
                0
            )
        else
            player:setX(x + 0.5)
            player:setY(y + 0.5)
            player:setZ(0)
        end

        if teleportPlayers then
            teleportPlayers(player)
        end
    end)

    return ok, err
end


local function onTick()
    local now = getTimestampMs()

    if not initialized then
        if not initialize() then
            return
        end
    end

    if now - lastControlCheck >= 2000 then
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

    local player =
        findPregenPlayer()

    if not player then
        writeStatus("waiting-for-player")
        return
    end

    if now - lastTeleport < INTERVAL_MS then
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

    local ok, err =
        teleportPlayer(
            player,
            target.x,
            target.y
        )

    if not ok then
        setControl("pause")

        writeStatus(
            "teleport-error",
            target.x,
            target.y,
            err
        )

        log(
            "ERROR target=" ..
            tostring(target.x) .. "," ..
            tostring(target.y) ..
            " " .. tostring(err)
        )

        return
    end

    lastTeleport = now
    teleports = teleports + 1
    runCount = runCount + 1
    index = index + 1

    saveCheckpoint()

    writeStatus(
        "teleported",
        target.x,
        target.y
    )

    if teleports % 10 == 0 then
        log(
            "progress " ..
            tostring(teleports) ..
            "/" ..
            tostring(#queue) ..
            " last=" ..
            tostring(target.x) .. "," ..
            tostring(target.y)
        )
    end

    if runLimit and runCount >= runLimit then
        setControl("pause")

        writeStatus(
            "test-complete",
            target.x,
            target.y
        )

        log(
            "test complete count=" ..
            tostring(runCount)
        )
    end
end


Events.OnTick.Add(onTick)

log("loaded; waiting for pause/run1/run20/run")
