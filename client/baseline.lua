TorqueWorksBaseline = {}

local cache = {}
local handlingClass = 'CHandlingData'

local fields = {
    driveForce = 'fInitialDriveForce',
    driveInertia = 'fDriveInertia',
    maxFlatVel = 'fInitialDriveMaxFlatVel',
    brakeForce = 'fBrakeForce',
    driveBiasFront = 'fDriveBiasFront',
    tractionCurveMax = 'fTractionCurveMax',
    tractionCurveMin = 'fTractionCurveMin',
    tractionCurveLateral = 'fTractionCurveLateral',
    tractionBiasFront = 'fTractionBiasFront',
    tractionLoss = 'fTractionLossMult',
    lowSpeedTractionLoss = 'fLowSpeedTractionLossMult',
    initialDrag = 'fInitialDragCoeff',
    clutchUp = 'fClutchChangeRateScaleUpShift',
    clutchDown = 'fClutchChangeRateScaleDownShift',
    suspensionForce = 'fSuspensionForce',
    suspensionCompDamp = 'fSuspensionCompDamp',
    suspensionReboundDamp = 'fSuspensionReboundDamp',
    suspensionUpperLimit = 'fSuspensionUpperLimit',
    suspensionLowerLimit = 'fSuspensionLowerLimit',
    antiRollForce = 'fAntiRollBarForce',
    antiRollBiasFront = 'fAntiRollBarBiasFront',
    steeringLock = 'fSteeringLock'
}

local function readFactoryGearCount(vehicle)
    if type(GetVehicleHandlingInt) == 'function' then
        local ok, gears = pcall(GetVehicleHandlingInt, vehicle, handlingClass, 'nInitialDriveGears')
        if ok and type(gears) == 'number' and gears >= 1 then
            return math.floor(gears)
        end
    end
    return GetVehicleHighGear(vehicle)
end

local function readTransmission(vehicle, gearCount)
    local ratios = {}
    if type(GetVehicleGearRatio) ~= 'function' then return ratios end

    for gear = 1, math.min(gearCount, 8) do
        local ok, ratio = pcall(GetVehicleGearRatio, vehicle, gear)
        if ok and type(ratio) == 'number' and ratio > 0.0 then ratios[gear] = ratio end
    end
    return ratios
end

function TorqueWorksBaseline.capture(vehicle)
    local model = GetEntityModel(vehicle)
    local networkId = NetworkGetNetworkIdFromEntity(vehicle)
    local cached = cache[vehicle]
    if cached and cached.model == model and cached.networkId == networkId then return cached end

    local displayName = GetDisplayNameFromVehicleModel(model)
    local factoryGearCount = readFactoryGearCount(vehicle)
    local baseline = {
        model = model,
        networkId = networkId,
        transmission = readTransmission(vehicle, factoryGearCount),
        highGear = factoryGearCount,
        turboModEnabled = IsToggleModOn(vehicle, 18),
        engineAudio = type(displayName) == 'string' and displayName:lower() or ''
    }
    for key, field in pairs(fields) do
        baseline[key] = GetVehicleHandlingFloat(vehicle, handlingClass, field)
    end
    cache[vehicle] = baseline
    return baseline
end

function TorqueWorksBaseline.get(vehicle)
    return cache[vehicle]
end

function TorqueWorksBaseline.applyStatic(vehicle, engine, flywheel, differential, brakes, suspension, build, compound, personality)
    local baseline = TorqueWorksBaseline.capture(vehicle)
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.driveInertia,
        baseline.driveInertia * engine.driveInertia * flywheel.driveInertia)
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.maxFlatVel, baseline.maxFlatVel * engine.maxFlatVel)
    local staticBrakeForce = baseline.brakeForce * brakes.forceMultiplier
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.brakeForce, staticBrakeForce)
    baseline.lastAppliedBrakeForce = staticBrakeForce
    baseline.lastBrakeRefresh = GetGameTimer()
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.suspensionForce,
        baseline.suspensionForce * suspension.stiffness)
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.suspensionCompDamp,
        baseline.suspensionCompDamp * suspension.compressionDamping)
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.suspensionReboundDamp,
        baseline.suspensionReboundDamp * suspension.reboundDamping)
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.antiRollForce,
        baseline.antiRollForce * suspension.antiRollForce)
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.antiRollBiasFront,
        TorqueWorksMath.clamp(baseline.antiRollBiasFront + suspension.antiRollBiasOffset, 0.0, 1.0))
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.steeringLock,
        baseline.steeringLock * (suspension.steeringLock or 1.0))
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.suspensionUpperLimit,
        baseline.suspensionUpperLimit * (suspension.suspensionUpperLimit or 1.0))
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.suspensionLowerLimit,
        baseline.suspensionLowerLimit * (suspension.suspensionLowerLimit or 1.0))
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.tractionBiasFront,
        TorqueWorksMath.clamp(baseline.tractionBiasFront + (suspension.tractionBiasOffset or 0.0), 0.01, 0.99))
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.tractionLoss,
        baseline.tractionLoss * (suspension.surfaceLossMultiplier or 1.0) *
            (compound.surfaceLossMultiplier or 1.0))
    if type(ForceVehicleEngineAudio) == 'function' then
        pcall(ForceVehicleEngineAudio, vehicle,
            type(engine.audioName) == 'string' and engine.audioName or baseline.engineAudio)
    end
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.clutchUp, baseline.clutchUp * personality.clutchUp)
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.clutchDown, baseline.clutchDown * personality.clutchDown)
    local pressureDelta = math.abs(build.tirePressure - compound.optimalPressure)
    local normalizedDelta = TorqueWorksMath.clamp(pressureDelta / compound.pressureTolerance, 0.0, 1.0)
    local pressureGrip = 1.0 - (normalizedDelta * normalizedDelta * Config.TirePressure.pressureGripPenalty)
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.tractionCurveMax,
        baseline.tractionCurveMax * compound.grip * pressureGrip)
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.tractionCurveMin,
        baseline.tractionCurveMin * compound.grip * pressureGrip)
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.tractionCurveLateral,
        baseline.tractionCurveLateral * compound.lateralGrip * pressureGrip *
            (suspension.lateralGrip or 1.0))
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.lowSpeedTractionLoss,
        baseline.lowSpeedTractionLoss * compound.lowSpeedLoss * differential.tractionLossMultiplier *
            (suspension.lowSpeedLoss or 1.0))
    local underInflation = math.max(0.0, compound.optimalPressure - build.tirePressure)
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.initialDrag,
        baseline.initialDrag * (1.0 + underInflation * Config.TirePressure.underInflationDragPerPsi))

    local bias = build.frontTorqueBias >= 0.0 and build.frontTorqueBias or baseline.driveBiasFront
    SetVehicleHandlingFloat(vehicle, handlingClass, fields.driveBiasFront, bias)
end

function TorqueWorksBaseline.applyBrake(vehicle, multiplier)
    local baseline = TorqueWorksBaseline.capture(vehicle)
    local force = baseline.brakeForce * multiplier
    local now = GetGameTimer()
    if not baseline.lastAppliedBrakeForce or math.abs(force - baseline.lastAppliedBrakeForce) >= 0.0005 or
        now - (baseline.lastBrakeRefresh or 0) >= 250 then
        SetVehicleHandlingFloat(vehicle, handlingClass, fields.brakeForce, force)
        baseline.lastAppliedBrakeForce = force
        baseline.lastBrakeRefresh = now
    end
    return force
end

function TorqueWorksBaseline.applyTurboMod(vehicle, enabled)
    local baseline = TorqueWorksBaseline.capture(vehicle)
    SetVehicleModKit(vehicle, 0)
    local shouldEnable = enabled == true or baseline.turboModEnabled == true
    if IsToggleModOn(vehicle, 18) ~= shouldEnable then
        ToggleVehicleMod(vehicle, 18, shouldEnable)
    end
    return shouldEnable
end

function TorqueWorksBaseline.applyPower(vehicle, multiplier)
    local baseline = TorqueWorksBaseline.capture(vehicle)
    -- Keep the handling value stock. The live multiplier is applied separately,
    -- avoiding a handling multiplier multiplied again by the drivetrain native.
    local now = GetGameTimer()
    if now - (baseline.lastDriveForceRefresh or 0) >= 500 then
        SetVehicleHandlingFloat(vehicle, handlingClass, fields.driveForce, baseline.driveForce)
        baseline.lastDriveForceRefresh = now
    end
    local appliedMultiplier = 1.0 + ((multiplier - 1.0) * Config.PowerApplicationGain)
    SetVehicleCheatPowerIncrease(vehicle, appliedMultiplier)
    return baseline.driveForce * appliedMultiplier, appliedMultiplier
end

function TorqueWorksBaseline.restore(vehicle, restoreTransmission)
    local baseline = cache[vehicle]
    if not baseline or not DoesEntityExist(vehicle) then return end

    for key, field in pairs(fields) do
        SetVehicleHandlingFloat(vehicle, handlingClass, field, baseline[key])
    end
    baseline.lastAppliedBrakeForce = nil
    baseline.lastBrakeRefresh = 0
    baseline.lastDriveForceRefresh = 0
    SetVehicleCheatPowerIncrease(vehicle, 1.0)
    if type(ForceVehicleEngineAudio) == 'function' then
        pcall(ForceVehicleEngineAudio, vehicle, baseline.engineAudio)
    end
    SetVehicleModKit(vehicle, 0)
    if IsToggleModOn(vehicle, 18) ~= baseline.turboModEnabled then
        ToggleVehicleMod(vehicle, 18, baseline.turboModEnabled)
    end
    -- Do not touch a newly spawned vehicle's transmission during its first
    -- activation. Some vehicles report a temporary two-gear state while GTA
    -- initializes them. Transmission restoration is only needed after Vehicle
    -- TorqueWorks has already applied a configured gearset to this entity.
    if restoreTransmission then
        TorqueWorksTransmission.restore(vehicle, baseline.transmission)
        SetVehicleHighGear(vehicle, baseline.highGear)
    end
end

function TorqueWorksBaseline.forgetInvalid()
    for vehicle in pairs(cache) do
        if not DoesEntityExist(vehicle) then cache[vehicle] = nil end
    end
end
