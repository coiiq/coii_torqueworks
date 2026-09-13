Config.DriverPollMs = 400
Config.ServerCacheMs = 15000
Config.ActivationRetryMs = 1500
-- SET_VEHICLE_CHEAT_POWER_INCREASE is a frame-applied drivetrain modifier.
-- This loop exists only while the local player is the current driver.
Config.ActiveTickMs = 0
Config.NetworkControlTimeoutMs = 500
Config.PowerApplicationGain = 1.0

Config.BrakeVisuals = {
    enabled = true,
    visibleHeatThreshold = 0.08,
    maximumTemperatureC = 900,
    lightRange = 0.78,
    minimumIntensity = 1.50,
    maximumIntensity = 12.0,
    rearIntensityMultiplier = 0.82,
    wheelBones = {
        { name = 'wheel_lf', front = true }, { name = 'wheel_rf', front = true },
        { name = 'wheel_lr', front = false }, { name = 'wheel_rr', front = false }
    }
}

Config.Nitro = {
    refillItem = 'nos_bottle',
    reuseDelayMs = 3000,
    refillDurationMs = 5000,
    autoRefillDelayMs = 30000,
    cameraShake = 0.24,
    soundVolume = 0.16,
    trailSyncDistance = 150.0,
    taillightTrailScale = 1.0,
    taillightTrailColor = { r = 255, g = 0, b = 0 },
    particleDictionary = 'veh_xs_vehicle_mods',
    particleName = 'veh_nitrous',
    particleScale = 1.0,
    particleColor = { r = 40, g = 170, b = 255, alpha = 1.0 },
    particleLoadTimeoutMs = 2500,
    exhaustBones = { 'exhaust', 'exhaust_2', 'exhaust_3', 'exhaust_4' },
    shiftBurstEnabled = true,
    shiftBurstDurationMs = 220,
    shiftBurstScale = 0.72,
    shiftBurstCooldownMs = 120
}
