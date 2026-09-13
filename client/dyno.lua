TorqueWorksDyno = {
    state = 'IDLE',
    samples = {},
    rollers = {},
    station = nil,
    workshopId = nil,
    temporaryStation = nil,
    lastResult = nil
}

local function stationVector()
    local station = TorqueWorksDyno.station
    if not station then return nil, nil end
    return vector3(station.x, station.y, station.z), station
end

local function offsetPosition(station, forward, right, zOffset)
    local heading = math.rad(station.heading)
    return vector3(
        station.x + right * math.cos(heading) - forward * math.sin(heading),
        station.y + right * math.sin(heading) + forward * math.cos(heading),
        station.z + (zOffset or Config.Dyno.rollerZOffset)
    )
end

local function deleteRollers()
    for _, roller in ipairs(TorqueWorksDyno.rollers) do
        if DoesEntityExist(roller.entity) then DeleteEntity(roller.entity) end
    end
    TorqueWorksDyno.rollers = {}
end

local function spawnDynoBay(workshopId, station, dyno)
    dyno = dyno or {}
    local prop = {}
    for key, value in pairs(Config.Dyno.prop or {}) do prop[key] = value end
    for key, value in pairs(dyno.prop or {}) do prop[key] = value end
    if prop.enabled ~= false and type(prop.model) == 'string' and prop.model ~= '' then
        local model = joaat(prop.model)
        if not IsModelInCdimage(model) or not IsModelValid(model) then
            print(('[coii_torqueworks] streamed dyno model is unavailable: %s'):format(prop.model))
            return
        end
        RequestModel(model)
        local deadline = GetGameTimer() + 5000
        while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(25) end
        if not HasModelLoaded(model) then return end
        local position = offsetPosition(station, prop.forward or 0.0, prop.right or 0.0, prop.zOffset or 0.0)
        local entity = CreateObjectNoOffset(model, position.x, position.y, position.z, false, false, false)
        if entity ~= 0 then
            SetEntityHeading(entity, station.heading + (prop.headingOffset or 0.0))
            SetEntityCollision(entity, prop.collision ~= false, prop.collision ~= false)
            FreezeEntityPosition(entity, true)
            SetEntityAsMissionEntity(entity, true, true)
            TorqueWorksDyno.rollers[#TorqueWorksDyno.rollers + 1] = {
                entity = entity, rotate = false, workshopId = workshopId
            }
        end
        SetModelAsNoLongerNeeded(model)
        return
    end

    local rollerModel = dyno.rollerModel or Config.Dyno.rollerModel
    local model = joaat(rollerModel)
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        print(('[coii_torqueworks] dyno roller model is unavailable: %s'):format(rollerModel))
        return
    end

    RequestModel(model)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(25) end
    if not HasModelLoaded(model) then return end

    for _, offset in ipairs(dyno.rollerOffsets or Config.Dyno.rollerOffsets) do
        local position = offsetPosition(station, offset.forward, offset.right)
        local entity = CreateObjectNoOffset(model, position.x, position.y, position.z, false, false, false)
        if entity ~= 0 then
            SetEntityHeading(entity, station.heading + 90.0)
            SetEntityCollision(entity, false, false)
            FreezeEntityPosition(entity, true)
            TorqueWorksDyno.rollers[#TorqueWorksDyno.rollers + 1] = {
                entity = entity, angle = 0.0, rotate = true, workshopId = workshopId
            }
        end
    end
    SetModelAsNoLongerNeeded(model)
end

local function spawnRollers()
    deleteRollers()
    for workshopId, workshop in pairs(Config.Workshops or {}) do
        local dyno = workshop.dyno
        if dyno and dyno.enabled ~= false and dyno.station then
            spawnDynoBay(workshopId, dyno.station, dyno)
        end
    end
    if TorqueWorksDyno.temporaryStation then
        spawnDynoBay('__temporary', TorqueWorksDyno.temporaryStation, Config.Dyno)
    end
end

local function configuredDyno(workshopId)
    if workshopId == '__temporary' and TorqueWorksDyno.temporaryStation then
        return TorqueWorksDyno.temporaryStation, Config.Dyno
    end
    local workshop = type(Config.Workshops) == 'table' and Config.Workshops[workshopId] or nil
    local dyno = workshop and workshop.dyno
    if not dyno or dyno.enabled == false or not dyno.station then return nil, nil end
    return dyno.station, dyno
end

local function closeUi()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function releaseVehicle(vehicle)
    TorqueWorks.rpmOverride = nil
    TorqueWorks.dynoGearOverride = nil
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        FreezeEntityPosition(vehicle, false)
        SetVehicleHandbrake(vehicle, false)
        pcall(SetVehicleCurrentRpm, vehicle, 0.0)
    end
end

function TorqueWorksDyno.cancel(reason, notify)
    if TorqueWorksDyno.state == 'IDLE' then return end
    releaseVehicle(TorqueWorksDyno.vehicle)
    TorqueWorksDyno.state = 'IDLE'
    TorqueWorksDyno.vehicle = nil
    TorqueWorksDyno.samples = {}
    closeUi()
    if notify ~= false then
        TorqueWorksUI.notify({ type = 'inform', description = ('Dyno stopped%s'):format(reason and (': ' .. reason) or '.') })
    end
end

local function buildSummary(active)
    local build = active.build
    return {
        plate = active.plate,
        turbo = build.turbo,
        ecu = build.ecu,
        engine = build.engine,
        fuelpump = build.fuelpump,
        flywheel = build.flywheel,
        transmission = build.transmission,
        transmissionPersonality = build.transmissionPersonality,
        differential = build.differential,
        ecuMap = build.ecuMap,
        tireCompound = build.tireCompound,
        tirePressure = build.tirePressure,
        frontTorqueBias = build.frontTorqueBias
    }
end

local function selectedGearRatio(active)
    local gear = Config.Dyno.testGear
    local configured = active.parts.transmission.ratios
    if configured and configured[gear] then return configured[gear] end
    local baseline = TorqueWorksBaseline.get(active.vehicle)
    return (baseline and baseline.transmission[gear]) or Config.Dyno.fallbackGearRatios[gear] or 1.0
end

local function calculateSample(active, normalizedRpm, elapsedMs)
    local telemetry = TorqueWorks.telemetry
    local baseline = TorqueWorksBaseline.get(active.vehicle)
    if not telemetry or not baseline then return nil end

    local actualRpm = Config.Dyno.idleRpm + normalizedRpm * (Config.Dyno.redlineRpm - Config.Dyno.idleRpm)
    local mass = GetVehicleHandlingFloat(active.vehicle, 'CHandlingData', 'fMass')
    local ratio = math.max(0.01, selectedGearRatio(active) * Config.Dyno.finalDrive)
    local engineTorque = baseline.driveForce * mass * Config.Dyno.torqueCalibration * telemetry.appliedMultiplier
    -- A chassis dyno reports torque referenced back to engine RPM. Raw axle
    -- torque includes gear/final-drive multiplication and produces misleading
    -- four-digit figures, despite no corresponding increase in wheel power.
    local wheelTorque = engineTorque * Config.Dyno.drivetrainEfficiency
    local wheelRpm = actualRpm / ratio
    local wheelPower = wheelTorque * actualRpm / 7127.0
    local speed = wheelRpm * Config.Dyno.tireCircumferenceM * 0.06

    return {
        time = elapsedMs,
        rpmNormalized = normalizedRpm,
        rpm = actualRpm,
        power = wheelPower,
        torque = wheelTorque,
        boost = telemetry.currentBoost,
        throttle = telemetry.throttle,
        gearBoost = telemetry.gearBoost,
        revLimit = telemetry.revLimit,
        limiterActive = telemetry.limiterActive,
        speed = speed,
        gear = Config.Dyno.testGear
    }
end

local function rotateRollers(speed, dt)
    local delta = speed * dt * 2.2
    local _, station = stationVector()
    if not station then return end
    for _, roller in ipairs(TorqueWorksDyno.rollers) do
        if roller.workshopId == TorqueWorksDyno.workshopId and roller.rotate and DoesEntityExist(roller.entity) then
            roller.angle = (roller.angle + delta) % 360.0
            SetEntityRotation(roller.entity, roller.angle, 0.0, station.heading + 90.0, 2, true)
        end
    end
end

local function finishPull(active)
    local samples = TorqueWorksDyno.samples
    local peakPower, peakTorque = 0.0, 0.0
    for _, sample in ipairs(samples) do
        peakPower = math.max(peakPower, sample.power)
        peakTorque = math.max(peakTorque, sample.torque)
    end

    TorqueWorksDyno.lastResult = {
        build = buildSummary(active), samples = samples,
        peakPower = peakPower, peakTorque = peakTorque
    }
    TriggerServerEvent('coii_torqueworks:server:saveDynoRun', active.plate,
        active.networkId, TorqueWorksDyno.lastResult)
    releaseVehicle(active.vehicle)
    TorqueWorksDyno.state = 'RESULT'
    TorqueWorksDyno.vehicle = nil
    SendNUIMessage({ action = 'complete', result = TorqueWorksDyno.lastResult })
    SetNuiFocus(true, true)
    TorqueWorksUI.notify({
        type = 'success', duration = 7000,
        description = ('Dyno complete: %.1f whp / %.1f Nm'):format(peakPower, peakTorque)
    })
end

local function activeDrivenVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return nil end
    local active = TorqueWorks.active
    if not active or active.vehicle ~= vehicle then TorqueWorks.ensureActive(vehicle) end
    active = TorqueWorks.active
    return active and active.vehicle == vehicle and DoesEntityExist(active.vehicle) and active or nil
end

function TorqueWorksDyno.start(workshopId)
    if TorqueWorksDyno.state ~= 'IDLE' and TorqueWorksDyno.state ~= 'RESULT' then
        TorqueWorksDyno.cancel('cancelled by driver', true)
        return
    end

    local station, dyno = configuredDyno(workshopId)
    if not station then
        TorqueWorksUI.notify({ type = 'error', description = 'This workshop has no configured dyno.' })
        return
    end
    if workshopId ~= '__temporary' then
        local access = lib.callback.await('coii_torqueworks:server:canUseWorkshopDyno', false, workshopId)
        if not access or not access.ok then
            TorqueWorksUI.notify({ type = 'error', description = access and access.error or 'Dyno access was denied.' })
            return
        end
    end

    local active = activeDrivenVehicle()
    if not active then
        TorqueWorksUI.notify({ type = 'error', description = 'You must be driving an active TorqueWorks vehicle.' })
        return
    end

    TorqueWorksDyno.station = station
    TorqueWorksDyno.workshopId = workshopId
    local stationPosition = vector3(station.x, station.y, station.z)
    if #(GetEntityCoords(active.vehicle) - stationPosition) > (dyno.activationRadius or Config.Dyno.activationRadius) then
        TorqueWorksUI.notify({ type = 'error', description = 'Drive the vehicle onto the dyno rollers first.' })
        return
    end

    TorqueWorksDyno.vehicle = active.vehicle
    TorqueWorksDyno.samples = {}
    TorqueWorksDyno.state = 'ARMED'
    SetNuiFocus(false, false)
    if Config.Dyno.alignVehicle ~= false then
        local offset = Config.Dyno.vehicleOffset or {}
        local target = offsetPosition(station, offset.forward or 0.0, offset.right or 0.0, 0.0)
        local current = GetEntityCoords(active.vehicle)
        SetEntityCoordsNoOffset(active.vehicle, target.x, target.y, current.z, false, false, false)
    end
    SetEntityHeading(active.vehicle, station.heading)
    FreezeEntityPosition(active.vehicle, true)
    SetVehicleHandbrake(active.vehicle, true)
    SendNUIMessage({ action = 'open', build = buildSummary(active), gear = Config.Dyno.testGear })
    TorqueWorksUI.notify({ type = 'inform', description = 'Dyno armed. Hold full throttle to begin the pull.' })
end

function TorqueWorksDyno.place()
    local active = activeDrivenVehicle()
    if not active then
        TorqueWorksUI.notify({ type = 'error', description = 'Park the development vehicle where the dyno should be placed.' })
        return
    end
    local coords = GetEntityCoords(active.vehicle)
    TorqueWorksDyno.temporaryStation = { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(active.vehicle) }
    TorqueWorksDyno.station = TorqueWorksDyno.temporaryStation
    TorqueWorksDyno.workshopId = '__temporary'
    spawnRollers()
    TorqueWorksUI.notify({ type = 'success', description = 'Temporary dyno bay placed under this vehicle.' })
end

function TorqueWorksDyno.showLastResult()
    local result = TorqueWorksDyno.lastResult
    if not result then
        TorqueWorksUI.notify({ type = 'error', description = 'No dyno result is available yet.' })
        return
    end
    TorqueWorksDyno.state = 'RESULT'
    SendNUIMessage({ action = 'open', build = result.build, gear = Config.Dyno.testGear })
    SendNUIMessage({ action = 'complete', result = result })
    SetNuiFocus(true, true)
end

RegisterNUICallback('close', function(_, callback)
    if TorqueWorksDyno.state == 'ARMED' or TorqueWorksDyno.state == 'RUNNING' then
        TorqueWorksDyno.cancel('UI closed', false)
    else
        TorqueWorksDyno.state = 'IDLE'
        closeUi()
    end
    callback({ ok = true })
end)

function TorqueWorksDyno.nearestWorkshop()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearestId, nearestDistance, nearestDyno
    for workshopId, workshop in pairs(Config.Workshops or {}) do
        local dyno = workshop.dyno
        if dyno and dyno.enabled ~= false and dyno.station then
            local station = dyno.station
            local distance = #(playerCoords - vector3(station.x, station.y, station.z))
            if not nearestDistance or distance < nearestDistance then
                nearestId, nearestDistance, nearestDyno = workshopId, distance, dyno
            end
        end
    end
    return nearestId, nearestDistance, nearestDyno
end

-- Mouse focus stays disabled during a pull so the driver retains throttle
-- control. Capture Escape through GTA controls to keep an exit available.
CreateThread(function()
    while true do
        if TorqueWorksDyno.state == 'ARMED' or TorqueWorksDyno.state == 'RUNNING' then
            DisableControlAction(0, 200, true)
            if IsDisabledControlJustReleased(0, 200) then
                TorqueWorksDyno.cancel('cancelled by driver', false)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    -- A resource restart can leave Chromium focus/page state alive briefly.
    -- Force a known closed and transparent state before creating the bay.
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    Wait(1000)
    spawnRollers()

    local promptVisible = false
    local function hidePrompt()
        if not promptVisible then return end
        promptVisible = false
        TorqueWorksUI.hideTextUI()
    end
    while true do
        local workshopId, distance, dyno = TorqueWorksDyno.nearestWorkshop()
        local ped = PlayerPedId()
        if workshopId and distance < (dyno.drawDistance or Config.Dyno.drawDistance or 35.0) then
            local station = dyno.station
            local stationPosition = vector3(station.x, station.y, station.z)
            local vehicle = GetVehiclePedIsIn(ped, false)
            local active = TorqueWorks.active
            local canStart = TorqueWorksDyno.state == 'IDLE' and vehicle ~= 0 and
                GetPedInVehicleSeat(vehicle, -1) == ped and active and active.vehicle == vehicle and
                #(GetEntityCoords(vehicle) - stationPosition) <=
                    (dyno.interactionDistance or Config.Dyno.interactionDistance or 3.5)
            if canStart and not promptVisible then
                promptVisible = true
                local workshop = Config.Workshops[workshopId]
                TorqueWorksUI.showTextUI(dyno.interactionPrompt or
                    ('[E] Start %s dyno'):format(workshop.name or workshopId), {
                    position = 'left-center', icon = 'gauge-high'
                })
            elseif not canStart then
                hidePrompt()
            end
            if canStart and IsControlJustReleased(0,
                dyno.interactionControl or Config.Dyno.interactionControl or 38) then
                hidePrompt()
                TorqueWorksDyno.start(workshopId)
            end
            Wait(0)
        else
            hidePrompt()
            Wait(1000)
        end
    end
end)

CreateThread(function()
    local runStarted, lastFrame, lastSample, lastUi = 0, 0, 0, 0
    while true do
        if TorqueWorksDyno.state == 'IDLE' or TorqueWorksDyno.state == 'RESULT' then
            Wait(250)
        else
            local active = TorqueWorks.active
            local vehicle = TorqueWorksDyno.vehicle
            if not active or active.vehicle ~= vehicle or not DoesEntityExist(vehicle) then
                TorqueWorksDyno.cancel('vehicle unavailable', true)
            elseif TorqueWorksDyno.state == 'ARMED' then
                if GetControlNormal(0, 71) >= 0.90 then
                    TorqueWorksDyno.state = 'RUNNING'
                    active.currentBoost = 0.0
                    active.currentThrottle = 0.0
                    TorqueWorks.dynoGearOverride = Config.Dyno.testGear
                    runStarted = GetGameTimer()
                    lastFrame, lastSample, lastUi = runStarted, runStarted, runStarted
                    SendNUIMessage({ action = 'running' })
                end
                Wait(0)
            else
                local now = GetGameTimer()
                local elapsed = now - runStarted
                local progress = TorqueWorksMath.clamp(elapsed / (Config.Dyno.sweepSeconds * 1000.0), 0.0, 1.0)
                local rpm = TorqueWorksMath.lerp(Config.Dyno.startRpm, Config.Dyno.endRpm, progress)
                TorqueWorks.rpmOverride = rpm
                pcall(SetVehicleCurrentRpm, vehicle, rpm)
                pcall(SetVehicleCurrentGear, vehicle, Config.Dyno.testGear)
                pcall(SetVehicleNextGear, vehicle, Config.Dyno.testGear)

                local dt = TorqueWorksMath.clamp((now - lastFrame) / 1000.0, 0.0, 0.1)
                lastFrame = now
                local preview = calculateSample(active, rpm, elapsed)
                if preview then rotateRollers(preview.speed, dt) end

                if preview and now - lastSample >= Config.Dyno.sampleIntervalMs and
                    #TorqueWorksDyno.samples < Config.Dyno.maxSamples then
                    TorqueWorksDyno.samples[#TorqueWorksDyno.samples + 1] = preview
                    lastSample = now
                end
                if preview and now - lastUi >= Config.Dyno.uiIntervalMs then
                    SendNUIMessage({ action = 'sample', sample = preview })
                    lastUi = now
                end

                if progress >= 1.0 then finishPull(active) else Wait(0) end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    TorqueWorksDyno.cancel(nil, false)
    TorqueWorksUI.hideTextUI()
    deleteRollers()
end)
