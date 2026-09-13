-- Shared dyno prop, interaction defaults, and pull simulation. Physical dyno
-- stations belong to individual entries in shared/config/workshops.lua.
Config.Dyno = {
    activationRadius = 3.5,
    interactionDistance = 3.5,
    interactionControl = 38,
    interactionPrompt = '[E] Start dyno test',
    drawDistance = 35.0,
    prop = {
        enabled = true,
        model = 'mist_dyno',
        forward = 0.0,
        right = 0.0,
        zOffset = 0.0,
        headingOffset = 0.0,
        collision = true
    },
    alignVehicle = true,
    vehicleOffset = { forward = 0.0, right = 0.0 },
    -- Used only when the complete streamed dyno prop is disabled.
    rollerModel = 'prop_abat_roller_static',
    rollerOffsets = {
        { forward = 1.35, right = -0.78 }, { forward = 1.35, right = 0.78 },
        { forward = -1.35, right = -0.78 }, { forward = -1.35, right = 0.78 }
    },
    rollerZOffset = -0.12,
    startRpm = 0.18,
    endRpm = 0.98,
    sweepSeconds = 12.0,
    testGear = 4,
    sampleIntervalMs = 50,
    uiIntervalMs = 100,
    idleRpm = 900,
    redlineRpm = 8000,
    finalDrive = 3.42,
    fallbackGearRatios = { 3.20, 2.10, 1.52, 1.18, 0.96, 0.80, 0.68, 0.59 },
    tireCircumferenceM = 2.05,
    drivetrainEfficiency = 0.85,
    -- Global conversion from GTA drive force and vehicle mass to approximate Nm.
    torqueCalibration = 0.80,
    maxSamples = 220
}
