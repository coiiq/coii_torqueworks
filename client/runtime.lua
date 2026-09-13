TorqueWorks = {
    active = nil,
    telemetry = nil,
    pendingBuilds = {}
}

local requestSerial = 0

local function engineTurboCompatibility(build)
    local system = Config.PartCompatibility and Config.PartCompatibility.engineTurbo
    local engine = system and system.combinations and system.combinations[build.engine]
    local turbo = Config.Parts.turbo[build.turbo]
    local compatibilityKey = turbo and turbo.compatibilityClass or build.turbo
    local selected = (engine and engine[compatibilityKey]) or (system and system.default) or {}
    return {
        label = type(selected.label) == 'string' and selected.label or 'BALANCED',
        torque = tonumber(selected.torque) or 1.0,
        boost = tonumber(selected.boost) or 1.0,
        spool = tonumber(selected.spool) or 1.0,
        topEnd = tonumber(selected.topEnd) or 1.0
    }
end

local function normalizedPlate(vehicle)
    return GetVehicleNumberPlateText(vehicle):upper():gsub('^%s+', ''):gsub('%s+$', '')
end

local function hasControl(vehicle, request)
    if NetworkHasControlOfEntity(vehicle) then return true end
    if not request then return false end

    NetworkRequestControlOfEntity(vehicle)
    local deadline = GetGameTimer() + Config.NetworkControlTimeoutMs
    while DoesEntityExist(vehicle) and not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < deadline do
        Wait(25)
        NetworkRequestControlOfEntity(vehicle)
    end
    return NetworkHasControlOfEntity(vehicle)
end

local function restoreActive(requestControl)
    local active = TorqueWorks.active
    if not active then return end
    if TorqueWorksDyno then TorqueWorksDyno.cancel('vehicle lifecycle changed', false) end
    if DoesEntityExist(active.vehicle) then
        if requestControl then hasControl(active.vehicle, true) end
        if TorqueWorksBackfire and TorqueWorksBackfire.cleanup then
            TorqueWorksBackfire.cleanup(active.vehicle)
        end
        -- Handling overrides are local; restore even if network ownership migrated.
        TorqueWorksBaseline.restore(active.vehicle, active.transmissionModified == true)
    end
    if TorqueWorksTurboAudio then TorqueWorksTurboAudio.reset() end
    TorqueWorks.active = nil
    TorqueWorks.telemetry = nil
end

local function activate(vehicle, state)
    if type(state.build) ~= 'table' or not DoesEntityExist(vehicle) then return end
    if TorqueWorksDyno then TorqueWorksDyno.cancel('build changed', false) end
    if TorqueWorksNitro and TorqueWorksNitro.stop then TorqueWorksNitro.stop() end
    local parts = {}
    for category in pairs(Config.PartCategories) do
        local partId = state.build[category] or Config.FactoryBuild[category]
        state.build[category] = partId
        parts[category] = Config.Parts[category][partId]
        if not parts[category] then
            TorqueWorksUI.notify({ type = 'error', description = ('TorqueWorks has an invalid %s configuration.'):format(category) })
            return
        end
    end
    local mapId = math.floor(tonumber(state.build.ecuMap) or Config.FactoryBuild.ecuMap)
    local ecuMap = Config.EcuMaps[mapId]
    if not ecuMap then return end
    state.build.ecuMap = mapId
    local ecuCalibration = state.build.ecuCalibration or Config.EcuCalibration.defaults
    local compound = Config.TireCompounds[state.build.tireCompound]
    local personalityId = state.build.transmissionPersonality or Config.FactoryBuild.transmissionPersonality
    local transmissionPersonality = Config.TransmissionPersonalities[personalityId]
    if not compound or type(state.build.tirePressure) ~= 'number' or
        type(state.build.frontTorqueBias) ~= 'number' or not transmissionPersonality then return end
    state.build.transmissionPersonality = personalityId

    if TorqueWorks.active and TorqueWorks.active.vehicle ~= vehicle then restoreActive(true) end
    if not hasControl(vehicle, true) then
        TorqueWorksUI.notify({ type = 'error', description = 'Vehicle network control is unavailable.' })
        return
    end

    local replacingActiveTransmission = TorqueWorks.active and TorqueWorks.active.vehicle == vehicle and
        TorqueWorks.active.transmissionModified == true
    TorqueWorksBaseline.capture(vehicle)
    -- Restore first so part changes can never build on the previous build.
    TorqueWorksBaseline.restore(vehicle, replacingActiveTransmission == true)
    TorqueWorksBaseline.applyStatic(vehicle, parts.engine, parts.flywheel, parts.differential, parts.brakes, parts.suspension,
        state.build, compound, transmissionPersonality)
    TorqueWorksBaseline.applyTurboMod(vehicle, state.build.turbo ~= 'NATURALLY_ASPIRATED')
    local baseline = TorqueWorksBaseline.get(vehicle)
    local configuredHighGear = TorqueWorksTransmission.apply(vehicle, parts.transmission.ratios,
        parts.transmission.gearCount, baseline.highGear)
    local compatibility = engineTurboCompatibility(state.build)

    TorqueWorks.active = {
        vehicle = vehicle,
        networkId = NetworkGetNetworkIdFromEntity(vehicle),
        plate = state.plate,
        build = state.build,
        parts = parts,
        ecuMap = ecuMap,
        ecuCalibration = ecuCalibration,
        tireCompound = compound,
        transmissionPersonality = transmissionPersonality,
        compatibility = compatibility,
        highGear = configuredHighGear,
        transmissionModified = parts.transmission.ratios ~= nil or parts.transmission.gearCount ~= nil,
        factoryEfficiency = state.factoryEfficiency,
        brakeHeat = 0.0,
        currentBrakeInput = 0.0,
        currentBoost = 0.0,
        currentThrottle = 0.0,
        lastTick = GetGameTimer()
    }
    TorqueWorksTransmission.configurePersonality(TorqueWorks.active)
    if TorqueWorksBackfire and TorqueWorksBackfire.prepare then
        TorqueWorksBackfire.prepare(TorqueWorks.active)
    end
end

local function loadVehicle(vehicle)
    requestSerial = requestSerial + 1
    local serial = requestSerial
    local networkId = NetworkGetNetworkIdFromEntity(vehicle)
    local pending = TorqueWorks.pendingBuilds[networkId]
    if pending and pending.plate == normalizedPlate(vehicle) then
        TorqueWorks.pendingBuilds[networkId] = nil
        activate(vehicle, pending)
        return TorqueWorks.active ~= nil and TorqueWorks.active.vehicle == vehicle
    elseif pending then
        TorqueWorks.pendingBuilds[networkId] = nil
    end
    local state = lib.callback.await('coii_torqueworks:server:getTorqueWorks', false,
        normalizedPlate(vehicle), GetEntityModel(vehicle), networkId)

    if serial ~= requestSerial or not state or not DoesEntityExist(vehicle) then return false end
    local ped = PlayerPedId()
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then return false end
    activate(vehicle, state)
    return TorqueWorks.active ~= nil and TorqueWorks.active.vehicle == vehicle
end

function TorqueWorks.ensureActive(vehicle)
    if TorqueWorks.active and TorqueWorks.active.vehicle == vehicle then return true end
    loadVehicle(vehicle)
    return TorqueWorks.active ~= nil and TorqueWorks.active.vehicle == vehicle
end

function TorqueWorks.requestPart(category, partId)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        TorqueWorksUI.notify({ type = 'error', description = 'You must be driving a vehicle.' })
        return
    end
    TriggerServerEvent('coii_torqueworks:server:setPart', category, partId,
        normalizedPlate(vehicle), NetworkGetNetworkIdFromEntity(vehicle))
end

function TorqueWorks.requestEcuMap(mapId)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        TorqueWorksUI.notify({ type = 'error', description = 'You must be driving a vehicle.' })
        return
    end
    TriggerServerEvent('coii_torqueworks:server:setEcuMap', mapId,
        normalizedPlate(vehicle), NetworkGetNetworkIdFromEntity(vehicle))
end

function TorqueWorks.requestChassisSetting(setting, value)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        TorqueWorksUI.notify({ type = 'error', description = 'You must be driving a vehicle.' })
        return
    end
    TriggerServerEvent('coii_torqueworks:server:setChassisSetting', setting, value,
        normalizedPlate(vehicle), NetworkGetNetworkIdFromEntity(vehicle))
end

function TorqueWorks.reset()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        TorqueWorksUI.notify({ type = 'error', description = 'You must be driving a vehicle.' })
        return
    end
    TriggerServerEvent('coii_torqueworks:server:resetBuild',
        normalizedPlate(vehicle), NetworkGetNetworkIdFromEntity(vehicle))
end

RegisterNetEvent('coii_torqueworks:client:buildApplied', function(state, networkId, silent)
    local vehicle = NetToVeh(networkId)
    local ped = PlayerPedId()
    if type(state) ~= 'table' or type(state.build) ~= 'table' then return end
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        -- Keep server updates until this player becomes the vehicle's driver.
        TorqueWorks.pendingBuilds[networkId] = state
        if vehicle ~= 0 and TorqueWorks.active and TorqueWorks.active.vehicle == vehicle then
            restoreActive(true)
        end
        if not silent then TorqueWorksUI.notify({ type = 'success', description = 'Part installed. Re-enter the vehicle to apply the tune.' }) end
        return
    end
    TorqueWorks.pendingBuilds[networkId] = nil
    activate(vehicle, state)
    if TorqueWorksMechanic then TorqueWorksMechanic.updateBuild(state.build, state.vehicleClass) end
    if not silent then TorqueWorksUI.notify({ type = 'success', description = 'TorqueWorks build updated.' }) end
end)

CreateThread(function()
    local observedVehicle = 0
    local nextActivationAttempt = 0
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local driving = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped

        if driving then
            if vehicle ~= observedVehicle then
                if observedVehicle ~= 0 then restoreActive(true) end
                observedVehicle = vehicle
                nextActivationAttempt = 0
            end
            local activeForVehicle = TorqueWorks.active and TorqueWorks.active.vehicle == vehicle
            local now = GetGameTimer()
            if not activeForVehicle and now >= nextActivationAttempt then
                nextActivationAttempt = now + Config.ActivationRetryMs
                loadVehicle(vehicle)
            end
        elseif not driving and observedVehicle ~= 0 then
            requestSerial = requestSerial + 1
            restoreActive(true)
            observedVehicle = 0
            nextActivationAttempt = 0
        end

        TorqueWorksBaseline.forgetInvalid()
        Wait(Config.DriverPollMs)
    end
end)

CreateThread(function()
    while true do
        local active = TorqueWorks.active
        if not active then
            Wait(Config.DriverPollMs)
        else
            local vehicle = active.vehicle
            local ped = PlayerPedId()
            if not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= ped then
                restoreActive(true)
                Wait(Config.DriverPollMs)
            elseif not hasControl(vehicle, false) then
                Wait(100)
            else
                local now = GetGameTimer()
                local dt = TorqueWorksMath.clamp((now - active.lastTick) / 1000.0, 0.0, 0.1)
                active.lastTick = now

                -- The dyno supplies a controlled RPM load point. Road operation
                -- continues to use GTA's live drivetrain RPM.
                local rpm = TorqueWorks.rpmOverride or GetVehicleCurrentRpm(vehicle)
                rpm = TorqueWorksMath.clamp(rpm, 0.0, 1.0)
                local curve = TorqueWorksMath.interpolateCurve(active.parts.ecu.curve, rpm)
                local turbo = active.parts.turbo
                local flywheel = active.parts.flywheel
                local ecuMap = active.ecuMap
                local rawThrottle = TorqueWorks.rpmOverride and 1.0 or GetControlNormal(0, 71)
                if not TorqueWorks.rpmOverride and TorqueWorksBackfire and TorqueWorksBackfire.update then
                    TorqueWorksBackfire.update(active, rpm, rawThrottle)
                end
                local targetThrottle = rawThrottle ^ ecuMap.throttleExponent
                active.currentThrottle = TorqueWorksMath.lerp(active.currentThrottle,
                    targetThrottle, ecuMap.throttleResponseRate * flywheel.throttleResponse * dt)
                local gear = TorqueWorks.dynoGearOverride or GetVehicleCurrentGear(vehicle)
                if not TorqueWorks.rpmOverride then
                    gear = TorqueWorksTransmission.enforceManual(active, gear)
                end
                local shiftFactor = TorqueWorks.rpmOverride and 1.0
                    or TorqueWorksTransmission.shiftFactor(active, gear, now, rpm)
                local brakes = active.parts.brakes
                local vehicleSpeed = GetEntitySpeed(vehicle)
                local brakeControl = 0.0
                local handbrakeControl = 0.0
                if not TorqueWorks.rpmOverride then
                    brakeControl = math.max(GetControlNormal(0, 72), GetDisabledControlNormal(0, 72))
                    if brakeControl <= 0.01 and (IsControlPressed(0, 72) or IsDisabledControlPressed(0, 72)) then
                        brakeControl = 1.0
                    end
                    handbrakeControl = math.max(GetControlNormal(0, 76), GetDisabledControlNormal(0, 76))
                    if handbrakeControl <= 0.01 and
                        (IsControlPressed(0, 76) or IsDisabledControlPressed(0, 76)) then
                        handbrakeControl = 1.0
                    end
                end
                local longitudinalSpeed = GetEntitySpeedVector(vehicle, true).y
                local rawBrake = longitudinalSpeed > 0.5 and brakeControl or 0.0
                -- In reverse GTA swaps the accelerator/brake roles: control 71
                -- is the pedal that actually slows the vehicle down.
                if longitudinalSpeed < -0.5 then
                    rawBrake = math.max(GetControlNormal(0, 71), GetDisabledControlNormal(0, 71))
                    if rawBrake <= 0.01 and (IsControlPressed(0, 71) or IsDisabledControlPressed(0, 71)) then
                        rawBrake = 1.0
                    end
                end
                local mappedBrake = rawBrake ^ brakes.pedalExponent
                active.currentBrakeInput = TorqueWorksMath.lerp(active.currentBrakeInput,
                    mappedBrake, brakes.pedalResponse * dt)
                local speedLoad = TorqueWorksMath.clamp(vehicleSpeed / 45.0, 0.0, 1.0)
                if rawBrake > 0.05 and speedLoad > 0.02 then
                    active.brakeHeat = TorqueWorksMath.clamp(active.brakeHeat +
                        rawBrake * speedLoad * brakes.heatRate * dt, 0.0, 1.0)
                else
                    active.brakeHeat = TorqueWorksMath.clamp(active.brakeHeat -
                        brakes.coolingRate * dt, 0.0, 1.0)
                end
                local fadeWindow = TorqueWorksMath.clamp((active.brakeHeat - brakes.fadeStart) /
                    math.max(0.01, 1.0 - brakes.fadeStart), 0.0, 1.0)
                local brakeFade = fadeWindow * brakes.maximumFade
                local pedalScale = rawBrake > 0.01 and
                    TorqueWorksMath.clamp(active.currentBrakeInput / rawBrake, 0.55, 1.60) or 1.0
                local brakeMultiplier = brakes.forceMultiplier * (1.0 - brakeFade) * pedalScale
                local modifiedBrakeForce = TorqueWorksBaseline.applyBrake(vehicle, brakeMultiplier)
                if TorqueWorksBrakes then TorqueWorksBrakes.drawHeat(vehicle, active.brakeHeat) end
                if not TorqueWorks.rpmOverride and rawThrottle < 0.03 and
                    (gear == 0 or vehicleSpeed < 0.7) and rpm > 0.12 then
                    rpm = math.max(0.12, rpm - flywheel.rpmFallRate * dt)
                    pcall(SetVehicleCurrentRpm, vehicle, rpm)
                end
                local gearBoost = ecuMap.boostByGear[gear] or ecuMap.boostByGear[#ecuMap.boostByGear] or 1.0
                local boostWindow = TorqueWorksMath.clamp((rpm - turbo.threshold) / math.max(0.01, 1.0 - turbo.threshold), 0.0, 1.0)
                local compatibility = active.compatibility
                local customCalibration = active.ecuCalibration.customEnabled == true
                local calibrationBoost = customCalibration and (tonumber(active.ecuCalibration.boost) or 1.0) or 1.0
                local targetBoost = turbo.maxBoost * compatibility.boost * ecuMap.boostMultiplier * calibrationBoost * gearBoost *
                    boostWindow * active.currentThrottle
                local rate = targetBoost > active.currentBoost and
                    (turbo.spoolRate * compatibility.spool) or turbo.releaseRate
                active.currentBoost = TorqueWorksMath.lerp(active.currentBoost, targetBoost, rate * dt)
                if TorqueWorksTurboAudio then
                    TorqueWorksTurboAudio.update(active, rpm, rawThrottle, gear)
                end

                local topEndBlend = TorqueWorksMath.clamp((rpm - 0.55) / 0.45, 0.0, 1.0)
                local compatibilityTopEnd = TorqueWorksMath.lerp(1.0, compatibility.topEnd, topEndBlend)
                local fullThrottleMultiplier = active.factoryEfficiency * active.parts.engine.torque *
                    compatibility.torque * compatibilityTopEnd * curve * (1.0 + active.currentBoost)
                local calculatedMultiplier = TorqueWorksMath.lerp(1.0, fullThrottleMultiplier, active.currentThrottle)
                local launchConfig = Config.EcuCalibration.launch
                local launchActive = customCalibration and active.ecuCalibration.launchEnabled == true and not TorqueWorks.rpmOverride and
                    vehicleSpeed * 3.6 <= launchConfig.maximumSpeedKmh and
                    rawThrottle >= launchConfig.minimumThrottle and handbrakeControl > 0.5
                if launchActive then
                    local launchRpm = TorqueWorksMath.clamp(active.ecuCalibration.launchRpm /
                        launchConfig.referenceRedlineRpm, 0.1, 0.95)
                    local launchZone = launchConfig.softZoneRpm / launchConfig.referenceRedlineRpm
                    local launchCut = TorqueWorksMath.clamp((rpm - (launchRpm - launchZone)) /
                        math.max(0.001, launchZone), 0.0, 1.0)
                    calculatedMultiplier = TorqueWorksMath.lerp(calculatedMultiplier,
                        launchConfig.holdFloor, launchCut)
                    if rpm > launchRpm then
                        pcall(SetVehicleCurrentRpm, vehicle, launchRpm)
                        rpm = launchRpm
                    end
                end
                local limiterStart = ecuMap.revLimit - ecuMap.limiterSoftZone
                -- GTA automatic gearboxes need to reach their own upshift RPM.
                -- Cutting power before that point makes them hang in a gear.
                -- The custom limiter is therefore reserved for neutral and the
                -- player-controlled manual personality.
                local limiterEligible = gear == 0 or active.transmissionPersonality.manual == true
                local limiterFactor = limiterEligible and (1.0 - TorqueWorksMath.clamp(
                    (rpm - limiterStart) / math.max(0.001, ecuMap.limiterSoftZone), 0.0, 1.0)) or 1.0
                local limiterActive = limiterEligible and limiterFactor < 1.0
                if limiterActive then
                    calculatedMultiplier = TorqueWorksMath.lerp(ecuMap.limiterFloor,
                        calculatedMultiplier, limiterFactor)
                end
                calculatedMultiplier = calculatedMultiplier * shiftFactor
                local nitro = TorqueWorks.nitro
                if nitro and nitro.vehicle == vehicle and now < nitro.expiresAt then
                    calculatedMultiplier = calculatedMultiplier * nitro.powerMultiplier
                end
                local modifiedForce, appliedMultiplier = TorqueWorksBaseline.applyPower(vehicle, calculatedMultiplier)
                local baseline = TorqueWorksBaseline.get(vehicle)
                local nativeHighGear = GetVehicleHighGear(vehicle)
                local telemetry = TorqueWorks.telemetry or {}
                telemetry.build = active.build
                telemetry.mapLabel = customCalibration and 'Custom' or ecuMap.label
                telemetry.rpm = rpm
                telemetry.gear = gear
                telemetry.highGear = active.highGear or nativeHighGear
                telemetry.nativeHighGear = nativeHighGear
                telemetry.speed = vehicleSpeed * 3.6
                telemetry.targetBoost = targetBoost
                telemetry.currentBoost = active.currentBoost
                telemetry.throttle = active.currentThrottle
                telemetry.gearBoost = gearBoost
                telemetry.revLimit = ecuMap.revLimit
                telemetry.limiterActive = limiterActive
                telemetry.launchActive = launchActive
                telemetry.shiftFactor = shiftFactor
                telemetry.lsdLock = active.parts.differential.lsdLock
                telemetry.curve = curve
                telemetry.multiplier = calculatedMultiplier
                telemetry.appliedMultiplier = appliedMultiplier
                telemetry.baselineForce = baseline.driveForce
                telemetry.modifiedForce = modifiedForce
                telemetry.compatibility = compatibility.label
                telemetry.brakeHeat = active.brakeHeat
                telemetry.brakeFade = brakeFade
                telemetry.brakeInput = active.currentBrakeInput
                telemetry.baselineBrakeForce = baseline.brakeForce
                telemetry.modifiedBrakeForce = modifiedBrakeForce
                telemetry.brakeTemperature = TorqueWorksBrakes and TorqueWorksBrakes.temperature(active.brakeHeat) or 0
                TorqueWorks.telemetry = telemetry
                Wait(Config.ActiveTickMs)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    restoreActive(false)
end)
