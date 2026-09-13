TorqueWorksBackfire = {}

local exhaustBones = {
    'exhaust', 'exhaust_2', 'exhaust_3', 'exhaust_4', 'exhaust_5', 'exhaust_6',
    'exhaust_7', 'exhaust_8', 'exhaust_9', 'exhaust_10', 'exhaust_11', 'exhaust_12',
    'exhaust_13', 'exhaust_14', 'exhaust_15', 'exhaust_16'
}

local activeBursts = {}
local entrySyncToken = 0

function TorqueWorksBackfire.setStockSuppressed(vehicle, suppressed)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    EnableVehicleExhaustPops(vehicle, suppressed ~= true)
end

local function loadAsset(dictionary, waitForAsset)
    if HasNamedPtfxAssetLoaded(dictionary) then return true end
    RequestNamedPtfxAsset(dictionary)
    if not waitForAsset then return false end
    local deadline = GetGameTimer() + 2000
    while not HasNamedPtfxAssetLoaded(dictionary) and GetGameTimer() < deadline do
        Wait(0)
        RequestNamedPtfxAsset(dictionary)
    end
    return HasNamedPtfxAssetLoaded(dictionary)
end

local function startLoopedParticle(pump, vehicle, bone)
    UseParticleFxAssetNextCall(pump.particleDictionary)
    local handle = StartParticleFxLoopedOnEntityBone(pump.particleName, vehicle,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bone, pump.particleScale,
        false, false, false)
    return handle and handle ~= 0 and handle or nil
end

local function startFallbackParticle(pump, vehicle)
    local minimum, maximum = GetModelDimensions(GetEntityModel(vehicle))
    local rear = minimum.y - 0.05
    local height = minimum.z + math.max(0.22, (maximum.z - minimum.z) * 0.24)
    UseParticleFxAssetNextCall(pump.particleDictionary)
    local handle = StartParticleFxLoopedOnEntity(pump.particleName, vehicle,
        0.0, rear, height, 0.0, 0.0, 0.0, pump.particleScale,
        false, false, false)
    return handle and handle ~= 0 and handle or nil
end

local function stopBurst(burst)
    for _, handle in ipairs(burst.handles) do
        if handle and handle ~= 0 then StopParticleFxLooped(handle, false) end
    end
    burst.handles = {}
end

function TorqueWorksBackfire.cleanup(vehicle)
    if vehicle then TorqueWorksBackfire.setStockSuppressed(vehicle, false) end
    for index = #activeBursts, 1, -1 do
        local burst = activeBursts[index]
        if not vehicle or burst.vehicle == vehicle then
            stopBurst(burst)
            table.remove(activeBursts, index)
        end
    end
end

function TorqueWorksBackfire.trigger(active, waitForAsset)
    local pump = active and active.parts and active.parts.fuelpump
    if not pump or not pump.backfire or not DoesEntityExist(active.vehicle) then return false end
    local now = GetGameTimer()
    local popMode = active.ecuCalibration and active.ecuCalibration.customEnabled and
        Config.EcuCalibration.pops[active.ecuCalibration.pops]
    -- A backfire-capable pump may produce one shift pop without a custom ECU
    -- overrun map. CUSTOM Pops & Bangs controls the repeated throttle-lift burst.
    if not popMode or not popMode.enabled then popMode = Config.EcuCalibration.pops.SPORT end
    local cooldown = pump.cooldownMs * (popMode.cooldownMultiplier or 1.0)
    if now - (active.lastBackfire or 0) < cooldown then return false, 'cooldown' end
    if not loadAsset(pump.particleDictionary, waitForAsset == true) then return false, 'asset' end

    local burst = { vehicle = active.vehicle, handles = {} }
    for _, boneName in ipairs(exhaustBones) do
        local bone = GetEntityBoneIndexByName(active.vehicle, boneName)
        if bone ~= -1 then
            local handle = startLoopedParticle(pump, active.vehicle, bone)
            if handle then burst.handles[#burst.handles + 1] = handle end
        end
    end

    local method = 'bones'
    if #burst.handles == 0 then
        local handle = startFallbackParticle(pump, active.vehicle)
        if handle then
            burst.handles[1] = handle
            method = 'fallback'
        end
    end
    if #burst.handles == 0 then return false, 'effect' end

    active.lastBackfire = now
    -- The emitting client owns the visual trigger, so play its matching sound
    -- immediately. Waiting for a server round trip allowed the server cooldown
    -- to discard valid bursts close to the configured boundary.
    if TorqueWorksTurboAudio and TorqueWorksTurboAudio.playSpatial then
        TorqueWorksTurboAudio.playSpatial(active.vehicle,
            'audio/turbos/backfirepop.wav', 0.10, 'exhaust')
    end
    TriggerServerEvent('coii_torqueworks:server:backfireSound',
        NetworkGetNetworkIdFromEntity(active.vehicle), active.build.fuelpump)
    activeBursts[#activeBursts + 1] = burst
    CreateThread(function()
        Wait(math.max(50, tonumber(pump.particleDurationMs) or 145))
        stopBurst(burst)
        for index = #activeBursts, 1, -1 do
            if activeBursts[index] == burst then
                table.remove(activeBursts, index)
                break
            end
        end
    end)
    return true, method
end

RegisterNetEvent('coii_torqueworks:client:backfireSound', function(networkId)
    if not TorqueWorksTurboAudio or not TorqueWorksTurboAudio.playSpatial then return end
    local vehicle = NetToVeh(tonumber(networkId) or 0)
    TorqueWorksTurboAudio.playSpatial(vehicle,
        'audio/turbos/backfirepop.wav', 0.13, 'exhaust')
end)

function TorqueWorksBackfire.update(active, rpm, throttle)
    local pump = active.parts.fuelpump
    -- GTA and custom engine audio packs can reset this flag after activation.
    -- Reassert it from the already-running driver physics tick; this creates no
    -- additional loop and only runs for the locally driven active vehicle.
    local hasAftermarketPump = active.build.fuelpump ~= Config.FactoryBuild.fuelpump
    local now = GetGameTimer()
    if active.stockPopsSuppressed ~= hasAftermarketPump or
        now - (active.lastStockPopRefresh or 0) >= 100 then
        TorqueWorksBackfire.setStockSuppressed(active.vehicle, hasAftermarketPump)
        active.stockPopsSuppressed = hasAftermarketPump
        active.lastStockPopRefresh = now
    end
    local previous = active.lastRawThrottle or throttle
    active.lastRawThrottle = throttle
    if not pump.backfire then
        active.popArmedUntil = nil
        active.popArmedRpm = 0.0
        return
    end
    local popMode = active.ecuCalibration and active.ecuCalibration.customEnabled and
        Config.EcuCalibration.pops[active.ecuCalibration.pops]
    local threshold = pump.backfireRpm * ((popMode and popMode.rpmMultiplier) or 1.0)
    if popMode and popMode.enabled and
        (rpm >= threshold or previous >= pump.throttleFrom) and throttle >= pump.throttleFrom then
        active.popArmedUntil = now + 650
        active.popArmedRpm = math.max(rpm, active.popArmedRpm or 0.0)
    end
    if popMode and popMode.enabled and active.popArmedUntil and
        now <= active.popArmedUntil and (active.popArmedRpm or 0.0) >= threshold and
        throttle <= pump.throttleTo then
        active.popArmedUntil = nil
        active.popArmedRpm = 0.0
        active.popBurstToken = (active.popBurstToken or 0) + 1
        local token = active.popBurstToken
        CreateThread(function()
            local count = math.max(1, math.floor(tonumber(popMode.burstCount) or 1))
            local interval = math.max(100, math.floor(tonumber(popMode.burstIntervalMs) or pump.cooldownMs))
            for index = 1, count do
                if not TorqueWorks.active or TorqueWorks.active ~= active or
                    active.popBurstToken ~= token or not DoesEntityExist(active.vehicle) then return end
                TorqueWorksBackfire.trigger(active, index == 1)
                if index < count then Wait(interval) end
            end
        end)
    end
end

function TorqueWorksBackfire.prepare(active)
    local pump = active.parts.fuelpump
    local hasAftermarketPump = active.build.fuelpump ~= Config.FactoryBuild.fuelpump
    TorqueWorksBackfire.setStockSuppressed(active.vehicle, hasAftermarketPump)
    active.lastRawThrottle = 0.0
    active.lastBackfire = -math.max(500, tonumber(pump.cooldownMs) or 500)
    active.popBurstToken = 0
    active.popArmedUntil = nil
    active.popArmedRpm = 0.0
    active.stockPopsSuppressed = hasAftermarketPump
    active.lastStockPopRefresh = GetGameTimer()
    if pump.backfire then RequestNamedPtfxAsset(pump.particleDictionary) end
end

local function syncPopsAfterEntry(vehicle, seat)
    if seat ~= nil and tonumber(seat) ~= -1 then return end
    vehicle = tonumber(vehicle) or 0
    if vehicle == 0 then return end
    entrySyncToken = entrySyncToken + 1
    local token = entrySyncToken
    CreateThread(function()
        local deadline = GetGameTimer() + 8000
        while token == entrySyncToken and GetGameTimer() < deadline do
            local active = TorqueWorks and TorqueWorks.active
            if active and active.vehicle == vehicle and active.build then
                local aftermarket = active.build.fuelpump ~= Config.FactoryBuild.fuelpump
                TorqueWorksBackfire.setStockSuppressed(vehicle, aftermarket)
                Wait(500)
                if token == entrySyncToken and DoesEntityExist(vehicle) and
                    GetPedInVehicleSeat(vehicle, -1) == PlayerPedId() then
                    TorqueWorksBackfire.setStockSuppressed(vehicle, aftermarket)
                end
                return
            end
            Wait(100)
        end
    end)
end


AddEventHandler('baseevents:enteringVehicle', function(vehicle, seat)
    syncPopsAfterEntry(vehicle, seat)
end)

AddEventHandler('baseevents:enteredVehicle', function(vehicle, seat)
    syncPopsAfterEntry(vehicle, seat)
end)

AddEventHandler('baseevents:leftVehicle', function()
    entrySyncToken = entrySyncToken + 1
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then TorqueWorksBackfire.cleanup(nil) end
end)
