if not isServer() then
    return
end

RBXBridge = RBXBridge or {}

-- Player/pause/weather state is checked in memory every second.
RBXBridge.pollIntervalMs = 1000

-- Hard recalibration every 30 real minutes.
RBXBridge.snapshotIntervalMs = 1800000

RBXBridge.nextPollMs = 0
RBXBridge.nextSnapshotMs = 0

RBXBridge.players = {}
RBXBridge.initialized = false
RBXBridge.lastPaused = nil

RBXBridge.lastWrittenTemp = nil
RBXBridge.lastWrittenPrecip = nil
RBXBridge.lastWrittenPrecipType = nil
RBXBridge.lastWrittenThunder = nil


local function log(message)
    print("[RBXBridge] " .. tostring(message))
end


local function boolText(value)
    if value then
        return "true"
    end
    return "false"
end


local function getUsername(player)
    if not player then
        return nil
    end

    return player:getUsername() or player:getDisplayName()
end


local function getPlayerSnapshot()
    local result = {}
    local players = getOnlinePlayers()

    if not players then
        return result
    end

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        local username = getUsername(player)

        if username then
            result[username] = true
        end
    end

    return result
end


local function countPlayers()
    local players = getOnlinePlayers()

    if not players then
        return 0
    end

    return players:size()
end


local function getWeather()
    local cm = getClimateManager()

    if not cm then
        return nil
    end

    local temperature = cm:getTemperature()
    local precipitation = cm:getPrecipitationIntensity()
    local isSnow = cm:getPrecipitationIsSnow()
    local thunder = cm:getIsThunderStorming()

    local precipitationType = "none"

    if precipitation > 0.01 then
        if isSnow then
            precipitationType = "snow"
        else
            precipitationType = "rain"
        end
    end

    return {
        temperature = temperature,
        precipitation = precipitation,
        precipitationType = precipitationType,
        thunder = thunder
    }
end


local function writeStatus(reason)
    local gt = getGameTime()

    if not gt then
        log("ERROR: GameTime unavailable")
        return
    end

    local weather = getWeather()

    if not weather then
        log("ERROR: ClimateManager unavailable")
        return
    end

    local writer = getFileWriter(
        "RBXBridge_status.txt",
        true,
        false
    )

    if not writer then
        log("ERROR: could not open RBXBridge_status.txt")
        return
    end

    writer:writeln("year=" .. tostring(gt:getYear()))
    writer:writeln("month=" .. tostring(gt:getMonth() + 1))
    writer:writeln("day=" .. tostring(gt:getDayPlusOne()))
    writer:writeln("hour=" .. tostring(gt:getHour()))
    writer:writeln("minute=" .. tostring(gt:getMinutes()))

    writer:writeln(
        "world_age_hours=" ..
        tostring(gt:getWorldAgeHours())
    )

    writer:writeln(
        "minutes_per_day=" ..
        tostring(gt:getMinutesPerDay())
    )

    writer:writeln("players=" .. tostring(countPlayers()))
    writer:writeln("paused=" .. boolText(isGamePaused()))

    writer:writeln(
        "temperature_c=" ..
        tostring(weather.temperature)
    )

    writer:writeln(
        "precipitation_intensity=" ..
        tostring(weather.precipitation)
    )

    writer:writeln(
        "precipitation_type=" ..
        weather.precipitationType
    )

    writer:writeln(
        "thunder=" ..
        boolText(weather.thunder)
    )

    writer:writeln("updated_epoch=" .. tostring(getTimestamp()))
    writer:writeln("reason=" .. tostring(reason))

    writer:close()

    RBXBridge.lastWrittenTemp = weather.temperature
    RBXBridge.lastWrittenPrecip = weather.precipitation
    RBXBridge.lastWrittenPrecipType = weather.precipitationType
    RBXBridge.lastWrittenThunder = weather.thunder

    log("snapshot written: " .. tostring(reason))
end


local function getChatServerInstance()
    -- First try the normal exposed global.
    if ChatServer and ChatServer.getInstance then
        local ok, instance = pcall(function()
            return ChatServer.getInstance()
        end)

        if ok and instance then
            return instance
        end
    end

    -- Build 42 dedicated may not expose ChatServer as a Lua global.
    -- Try resolving the Java class directly if the bridge is available.
    if luajava and luajava.bindClass then
        local okClass, class = pcall(function()
            return luajava.bindClass(
                "zombie.network.chat.ChatServer"
            )
        end)

        if okClass and class then
            local okInstance, instance = pcall(function()
                return class.getInstance()
            end)

            if okInstance and instance then
                return instance
            end
        end
    end

    return nil
end


local function sendChatOnly(message)
    log(
        "in-game join/leave suppressed for stability: " ..
        tostring(message)
    )
end


local function checkPlayers()
    local current = getPlayerSnapshot()

    if not RBXBridge.initialized then
        RBXBridge.players = current
        RBXBridge.initialized = true

        log("player watcher initialized")
        writeStatus("startup")
        return
    end

    local changed = false

    -- JOIN
    for username in pairs(current) do
        if not RBXBridge.players[username] then
            log(username .. " joined")
            sendChatOnly(username .. " joined the server.")
            changed = true
        end
    end

    -- LEAVE
    for username in pairs(RBXBridge.players) do
        if not current[username] then
            log(username .. " left")
            sendChatOnly(username .. " left the server.")
            changed = true
        end
    end

    RBXBridge.players = current

    if changed then
        writeStatus("player-change")
    end
end


local function checkPause()
    local paused = isGamePaused()

    if RBXBridge.lastPaused == nil then
        RBXBridge.lastPaused = paused
        return
    end

    if paused ~= RBXBridge.lastPaused then
        RBXBridge.lastPaused = paused

        if paused then
            log("game paused")
            writeStatus("pause")
        else
            log("game unpaused")
            writeStatus("unpause")
        end
    end
end


local function checkWeather()
    local weather = getWeather()

    if not weather then
        return
    end

    if RBXBridge.lastWrittenTemp == nil then
        return
    end

    local significant = false

    -- Temperature changed by at least 0.5 C.
    if math.abs(
        weather.temperature - RBXBridge.lastWrittenTemp
    ) >= 0.5 then
        significant = true
    end

    -- Rain/snow started, stopped or changed type.
    if weather.precipitationType ~=
       RBXBridge.lastWrittenPrecipType then
        significant = true
    end

    -- Precipitation intensity changed by at least 10%.
    if math.abs(
        weather.precipitation - RBXBridge.lastWrittenPrecip
    ) >= 0.10 then
        significant = true
    end

    -- Thunderstorm state changed.
    if weather.thunder ~= RBXBridge.lastWrittenThunder then
        significant = true
    end

    if significant then
        writeStatus("weather-change")
    end
end


local function onTick()
    local now = getTimestampMs()

    if now >= RBXBridge.nextPollMs then
        RBXBridge.nextPollMs = now + RBXBridge.pollIntervalMs

        checkPlayers()
        checkPause()
        checkWeather()
    end

    if now >= RBXBridge.nextSnapshotMs then
        RBXBridge.nextSnapshotMs =
            now + RBXBridge.snapshotIntervalMs

        if RBXBridge.initialized then
            writeStatus("periodic")
        end
    end
end


Events.OnTick.Add(onTick)

log("loaded")
