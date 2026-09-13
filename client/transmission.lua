TorqueWorksTransmission = {}

local supported = type(SetVehicleGearRatio) == 'function'

function TorqueWorksTransmission.apply(vehicle, ratios, gearCount, factoryHighGear)
    -- Factory gearsets must remain under GTA's control. Newly created vehicles
    -- can briefly report a high gear of 1 or 2 while their drivetrain initializes;
    -- writing that transient value back permanently caps the transmission.
    if not ratios and gearCount == nil then
        return factoryHighGear or GetVehicleHighGear(vehicle)
    end

    local highGear = math.max(1, math.min(math.floor(tonumber(gearCount) or factoryHighGear or
        GetVehicleHighGear(vehicle)), 8))
    SetVehicleHighGear(vehicle, highGear)
    if not supported or not ratios then return highGear end
    for gear = 1, math.min(#ratios, highGear) do
        local ok = pcall(SetVehicleGearRatio, vehicle, gear, ratios[gear])
        if not ok then
            supported = false
            return highGear
        end
    end
    return highGear
end

function TorqueWorksTransmission.restore(vehicle, ratios)
    if not supported or not ratios then return end
    for gear, ratio in pairs(ratios) do
        pcall(SetVehicleGearRatio, vehicle, gear, ratio)
    end
end

function TorqueWorksTransmission.isSupported()
    return supported
end

function TorqueWorksTransmission.configurePersonality(active)
    local vehicle, personality = active.vehicle, active.transmissionPersonality
    local baseline = TorqueWorksBaseline.get(vehicle)
    active.lastGear = GetVehicleCurrentGear(vehicle)
    active.lastTransmissionRpm = GetVehicleCurrentRpm(vehicle)
    active.shiftStarted = 0
    active.manualGear = nil
    if personality.manual and baseline then
        active.manualGear = math.max(1, math.min(active.lastGear, active.highGear or baseline.highGear))
        -- High gear is the transmission ceiling, not the currently selected
        -- manual gear. Lowering it here can permanently cap the entity at 2nd.
        SetVehicleHighGear(vehicle, active.highGear or baseline.highGear)
    end
end

function TorqueWorksTransmission.shiftFactor(active, gear, now, rpm)
    rpm = tonumber(rpm) or GetVehicleCurrentRpm(active.vehicle)
    if gear ~= active.lastGear then
        if gear > 0 and active.lastGear > 0 then
            active.shiftStarted = now
            local pump = active.parts and active.parts.fuelpump
            local shiftRpm = math.max(rpm, tonumber(active.lastTransmissionRpm) or 0.0)
            if pump and pump.backfire and shiftRpm >= (pump.backfireRpm or 2.0) and
                TorqueWorksBackfire and TorqueWorksBackfire.trigger then
                TorqueWorksBackfire.trigger(active)
            end
        end
        active.lastGear = gear
    end
    active.lastTransmissionRpm = rpm
    local personality = active.transmissionPersonality
    local elapsed = (now - active.shiftStarted) / 1000.0
    if active.shiftStarted == 0 or elapsed >= personality.shiftDuration then return 1.0 end
    local progress = TorqueWorksMath.clamp(elapsed / math.max(0.01, personality.shiftDuration), 0.0, 1.0)
    local smooth = progress * progress * (3.0 - 2.0 * progress)
    return TorqueWorksMath.lerp(personality.shiftPowerFloor, 1.0, smooth)
end

function TorqueWorksTransmission.enforceManual(active, currentGear)
    if not active.transmissionPersonality.manual or not active.manualGear then return currentGear end
    -- Do not fight GTA's reverse behavior when the driver backs away from rest.
    if GetEntitySpeed(active.vehicle) < 2.0 and GetControlNormal(0, 72) > 0.1 then return currentGear end
    if currentGear ~= active.manualGear then
        local baseline = TorqueWorksBaseline.get(active.vehicle)
        SetVehicleHighGear(active.vehicle, active.highGear or (baseline and baseline.highGear) or active.manualGear)
        pcall(SetVehicleNextGear, active.vehicle, active.manualGear)
        pcall(SetVehicleCurrentGear, active.vehicle, active.manualGear)
    end
    return active.manualGear
end

function TorqueWorksTransmission.manualShift(direction)
    local active = TorqueWorks and TorqueWorks.active
    if not active or not active.transmissionPersonality.manual or TorqueWorks.rpmOverride then return false end
    local baseline = TorqueWorksBaseline.get(active.vehicle)
    if not baseline then return false end
    local current = active.manualGear or math.max(1, GetVehicleCurrentGear(active.vehicle))
    local requested = math.max(1, math.min(current + direction, active.highGear or baseline.highGear))
    if requested == current then return false end
    active.manualGear = requested
    active.shiftStarted = GetGameTimer()
    active.lastGear = requested
    if TorqueWorksBackfire and TorqueWorksBackfire.trigger and
        GetVehicleCurrentRpm(active.vehicle) >= (active.parts.fuelpump.backfireRpm or 2.0) then
        TorqueWorksBackfire.trigger(active)
    end
    if direction < 0 then
        local rpm = GetVehicleCurrentRpm(active.vehicle)
        pcall(SetVehicleCurrentRpm, active.vehicle,
            TorqueWorksMath.clamp(rpm + Config.ManualTransmission.downshiftRevMatch, 0.0, 0.96))
    end
    SetVehicleHighGear(active.vehicle, active.highGear or baseline.highGear)
    pcall(SetVehicleNextGear, active.vehicle, requested)
    pcall(SetVehicleCurrentGear, active.vehicle, requested)
    if Config.ManualTransmission.soundEnabled then
        SendNUIMessage({
            action = 'manualShiftSound',
            direction = direction > 0 and 'up' or 'down',
            volume = Config.ManualTransmission.soundVolume
        })
    end
    return true
end

RegisterCommand('+' .. Config.ManualTransmission.shiftUpCommand, function()
    TorqueWorksTransmission.manualShift(1)
end, false)
RegisterCommand('-' .. Config.ManualTransmission.shiftUpCommand, function() end, false)
RegisterKeyMapping('+' .. Config.ManualTransmission.shiftUpCommand, 'TorqueWorks manual shift up',
    'keyboard', Config.ManualTransmission.shiftUpKey)

RegisterCommand('+' .. Config.ManualTransmission.shiftDownCommand, function()
    TorqueWorksTransmission.manualShift(-1)
end, false)
RegisterCommand('-' .. Config.ManualTransmission.shiftDownCommand, function() end, false)
RegisterKeyMapping('+' .. Config.ManualTransmission.shiftDownCommand, 'TorqueWorks manual shift down',
    'keyboard', Config.ManualTransmission.shiftDownKey)
