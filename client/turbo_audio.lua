TorqueWorksTurboAudio = {
    vehicle = 0,
    lastThrottle = 0.0,
    lastRpm = 0.0,
    lastGear = 0,
    lastRelease = 0
}

function TorqueWorksTurboAudio.reset()
    TorqueWorksTurboAudio.vehicle = 0
    TorqueWorksTurboAudio.lastThrottle = 0.0
    TorqueWorksTurboAudio.lastRpm = 0.0
    TorqueWorksTurboAudio.lastGear = 0
    TorqueWorksTurboAudio.lastRelease = 0
end

function TorqueWorksTurboAudio.update(active, rpm, throttle, currentGear)
    local gear = currentGear or GetVehicleCurrentGear(active.vehicle)
    local turbo = active and active.parts and active.parts.turbo
    if not turbo or not turbo.wastegateSound then
        TorqueWorksTurboAudio.lastThrottle = throttle or 0.0
        TorqueWorksTurboAudio.lastRpm = rpm or 0.0
        TorqueWorksTurboAudio.lastGear = gear
        return
    end

    if TorqueWorksTurboAudio.vehicle ~= active.vehicle then
        TorqueWorksTurboAudio.vehicle = active.vehicle
        TorqueWorksTurboAudio.lastThrottle = throttle or 0.0
        TorqueWorksTurboAudio.lastRpm = rpm or 0.0
        TorqueWorksTurboAudio.lastGear = gear
        TorqueWorksTurboAudio.lastRelease = 0
        return
    end

    rpm = TorqueWorksMath.clamp(tonumber(rpm) or 0.0, 0.0, 1.0)
    throttle = TorqueWorksMath.clamp(tonumber(throttle) or 0.0, 0.0, 1.0)
    local now = GetGameTimer()
    local config = Config.TurboAudio
    local minimumNormalizedRpm = config.minimumRpm / math.max(1, config.referenceRedlineRpm)
    local released = TorqueWorksTurboAudio.lastThrottle >= config.minimumThrottleBeforeRelease and
        throttle <= config.maximumThrottleAfterRelease
    local shifted = TorqueWorksTurboAudio.lastGear > 0 and gear > 0 and
        gear ~= TorqueWorksTurboAudio.lastGear

    local releaseRpm = math.max(rpm, TorqueWorksTurboAudio.lastRpm)
    if (released or shifted) and releaseRpm >= minimumNormalizedRpm and
        now - TorqueWorksTurboAudio.lastRelease >= config.cooldownMs then
        local rpmLevel = TorqueWorksMath.clamp((releaseRpm - minimumNormalizedRpm) /
            math.max(0.01, 1.0 - minimumNormalizedRpm), 0.0, 1.0)
        TriggerServerEvent('coii_torqueworks:server:turboRelease',
            NetworkGetNetworkIdFromEntity(active.vehicle), active.build.turbo, rpmLevel)
        TorqueWorksTurboAudio.lastRelease = now
    end

    TorqueWorksTurboAudio.lastThrottle = throttle
    TorqueWorksTurboAudio.lastRpm = rpm
    TorqueWorksTurboAudio.lastGear = gear
end

function TorqueWorksTurboAudio.playSpatial(vehicle, file, volume, boneName)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local sourceBone = GetEntityBoneIndexByName(vehicle, boneName or 'engine')
    local origin = sourceBone ~= -1 and GetWorldPositionOfEntityBone(vehicle, sourceBone)
        or GetEntityCoords(vehicle)
    local listener = GetEntityCoords(PlayerPedId())
    local distance = #(origin - listener)
    if distance > Config.TurboAudio.syncDistance then return end

    local camera = GetGameplayCamCoord()
    local rotation = GetGameplayCamRot(2)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local cosPitch = math.abs(math.cos(pitch))
    local forward = vector3(-math.sin(yaw) * cosPitch, math.cos(yaw) * cosPitch, math.sin(pitch))
    local right = vector3(math.cos(yaw), math.sin(yaw), 0.0)
    local up = vector3(
        right.y * forward.z - right.z * forward.y,
        right.z * forward.x - right.x * forward.z,
        right.x * forward.y - right.y * forward.x)
    local delta = origin - camera
    local spatialX = delta.x * right.x + delta.y * right.y + delta.z * right.z
    local spatialY = delta.x * up.x + delta.y * up.y + delta.z * up.z
    local spatialZ = -(delta.x * forward.x + delta.y * forward.y + delta.z * forward.z)
    SendNUIMessage({
        action = 'turboWastegateSound',
        file = file,
        volume = volume,
        spatial = { x = spatialX, y = spatialY, z = spatialZ },
        maxDistance = Config.TurboAudio.syncDistance
    })
end

RegisterNetEvent('coii_torqueworks:client:turboRelease', function(networkId, turboId, rpmLevel)
    local turbo = Config.Parts.turbo[turboId]
    if not turbo or not turbo.wastegateSound then return end
    local vehicle = NetToVeh(tonumber(networkId) or 0)
    TorqueWorksTurboAudio.playSpatial(vehicle, turbo.wastegateSound,
        (turbo.wastegateVolume or 0.2) *
            TorqueWorksMath.lerp(0.72, 1.0, tonumber(rpmLevel) or 0.0), 'engine')
end)

RegisterNUICallback('turboAudioStatus', function(data, callback)
    if data and data.ok then
        TorqueWorksUI.notify({ type = 'success', description = 'Turbo audio playback started.' })
    else
        TorqueWorksUI.notify({ type = 'error', description = ('Turbo audio failed: %s'):format(
            data and tostring(data.error) or 'unknown NUI error') })
    end
    callback({ ok = true })
end)
