Config.FactoryBuild = {
    turbo = 'NATURALLY_ASPIRATED', ecu = 'FACTORY', engine = 'FACTORY',
    flywheel = 'FACTORY', transmission = 'FACTORY', fuelpump = 'FACTORY', nitro = 'NONE', transmissionPersonality = 'AUTOMATIC',
    differential = 'FACTORY', brakes = 'STREET', suspension = 'FACTORY', ecuMap = 2,
    tireCompound = 'STREET', tirePressure = 32.0, frontTorqueBias = -1.0,
    nitroLevel = 0.0, buildName = '', buildVisibility = 'PUBLIC',
    ecuCalibration = { customEnabled = false, boost = 1.00, pops = 'OFF', launchEnabled = false, launchRpm = 3800 }
}

Config.PartCategories = {
    turbo = true, ecu = true, engine = true, flywheel = true, transmission = true, fuelpump = true, nitro = true, differential = true, brakes = true, suspension = true
}

-- Combination tuning is server-owned alongside the rest of the trusted part
-- catalog. Values are multipliers applied by the common physics engine, not
-- client-provided handling data. Missing combinations use `default`.
Config.PartCompatibility = {
    engineTurbo = {
        default = { label = 'BALANCED', torque = 1.00, boost = 1.00, spool = 1.00, topEnd = 1.00 },
        combinations = {
            FACTORY = {
                NATURALLY_ASPIRATED = { label = 'FACTORY MATCH', torque = 1.00, boost = 1.00, spool = 1.00, topEnd = 1.00 },
                SMALL = { label = 'GOOD MATCH', torque = 1.02, boost = 1.00, spool = 1.08, topEnd = 0.98 },
                MEDIUM = { label = 'COMPROMISED', torque = 0.96, boost = 0.94, spool = 0.86, topEnd = 1.00 },
                LARGE = { label = 'POOR MATCH', torque = 0.88, boost = 0.86, spool = 0.68, topEnd = 0.94 }
            },
            HIGH_COMPRESSION = {
                NATURALLY_ASPIRATED = { label = 'GOOD MATCH', torque = 1.03, boost = 1.00, spool = 1.00, topEnd = 0.98 },
                SMALL = { label = 'OPTIMAL MATCH', torque = 1.07, boost = 1.04, spool = 1.18, topEnd = 0.98 },
                MEDIUM = { label = 'GOOD MATCH', torque = 1.02, boost = 1.00, spool = 0.96, topEnd = 1.02 },
                LARGE = { label = 'POOR MATCH', torque = 0.91, boost = 0.90, spool = 0.70, topEnd = 1.03 }
            },
            BALANCED = {
                NATURALLY_ASPIRATED = { label = 'BALANCED', torque = 1.00, boost = 1.00, spool = 1.00, topEnd = 1.00 },
                SMALL = { label = 'GOOD MATCH', torque = 1.03, boost = 1.00, spool = 1.04, topEnd = 0.98 },
                MEDIUM = { label = 'OPTIMAL MATCH', torque = 1.06, boost = 1.05, spool = 1.08, topEnd = 1.04 },
                LARGE = { label = 'COMPROMISED', torque = 0.97, boost = 0.98, spool = 0.84, topEnd = 1.07 }
            },
            REV_HAPPY = {
                NATURALLY_ASPIRATED = { label = 'GOOD MATCH', torque = 0.99, boost = 1.00, spool = 1.00, topEnd = 1.04 },
                SMALL = { label = 'COMPROMISED', torque = 0.97, boost = 0.94, spool = 0.94, topEnd = 0.96 },
                MEDIUM = { label = 'GOOD MATCH', torque = 1.03, boost = 1.03, spool = 1.02, topEnd = 1.06 },
                LARGE = { label = 'OPTIMAL MATCH', torque = 1.08, boost = 1.08, spool = 0.96, topEnd = 1.11 }
            },
            SK8 = {
                NATURALLY_ASPIRATED = { label = 'BALANCED', torque = 1.00, boost = 1.00, spool = 1.00, topEnd = 1.00 },
                SMALL = { label = 'RESTRICTED', torque = 0.96, boost = 0.92, spool = 1.10, topEnd = 0.91 },
                MEDIUM = { label = 'OPTIMAL MATCH', torque = 1.07, boost = 1.05, spool = 1.08, topEnd = 1.06 },
                LARGE = { label = 'GOOD MATCH', torque = 1.04, boost = 1.06, spool = 0.88, topEnd = 1.09 }
            },
            ST69_V12 = {
                NATURALLY_ASPIRATED = { label = 'GOOD MATCH', torque = 1.02, boost = 1.00, spool = 1.00, topEnd = 1.03 },
                SMALL = { label = 'POOR MATCH', torque = 0.89, boost = 0.86, spool = 1.04, topEnd = 0.84 },
                MEDIUM = { label = 'COMPROMISED', torque = 0.98, boost = 0.96, spool = 0.91, topEnd = 0.97 },
                LARGE = { label = 'OPTIMAL MATCH', torque = 1.10, boost = 1.10, spool = 0.82, topEnd = 1.12 }
            },
            STR17_MACH1 = {
                NATURALLY_ASPIRATED = { label = 'OPTIMAL MATCH', torque = 1.06, boost = 1.00, spool = 1.00, topEnd = 1.05 },
                SMALL = { label = 'RESTRICTED', torque = 0.96, boost = 0.91, spool = 1.08, topEnd = 0.91 },
                MEDIUM = { label = 'GOOD MATCH', torque = 1.04, boost = 1.03, spool = 1.04, topEnd = 1.04 },
                LARGE = { label = 'GOOD MATCH', torque = 1.06, boost = 1.07, spool = 0.86, topEnd = 1.09 }
            },
            STR025_F20C = {
                NATURALLY_ASPIRATED = { label = 'OPTIMAL MATCH', torque = 1.01, boost = 1.00, spool = 1.00, topEnd = 1.10 },
                SMALL = { label = 'GOOD MATCH', torque = 1.04, boost = 1.02, spool = 1.14, topEnd = 1.04 },
                MEDIUM = { label = 'COMPROMISED', torque = 0.98, boost = 0.96, spool = 0.88, topEnd = 1.05 },
                LARGE = { label = 'POOR MATCH', torque = 0.87, boost = 0.84, spool = 0.62, topEnd = 0.96 }
            },
            STR022_13BT = {
                NATURALLY_ASPIRATED = { label = 'RESTRICTED', torque = 0.94, boost = 1.00, spool = 1.00, topEnd = 0.96 },
                SMALL = { label = 'OPTIMAL MATCH', torque = 1.07, boost = 1.05, spool = 1.18, topEnd = 1.06 },
                MEDIUM = { label = 'GOOD MATCH', torque = 1.04, boost = 1.04, spool = 0.98, topEnd = 1.09 },
                LARGE = { label = 'POOR MATCH', torque = 0.90, boost = 0.88, spool = 0.58, topEnd = 1.01 }
            },
            STR021_M3E30 = {
                NATURALLY_ASPIRATED = { label = 'OPTIMAL MATCH', torque = 1.03, boost = 1.00, spool = 1.00, topEnd = 1.07 },
                SMALL = { label = 'GOOD MATCH', torque = 1.04, boost = 1.01, spool = 1.12, topEnd = 1.02 },
                MEDIUM = { label = 'COMPROMISED', torque = 0.98, boost = 0.95, spool = 0.85, topEnd = 1.03 },
                LARGE = { label = 'POOR MATCH', torque = 0.86, boost = 0.82, spool = 0.60, topEnd = 0.94 }
            }
        }
    }
}

-- Add GTA spawn codes to a part's `unavailableFor` array to lock that part
-- for those vehicle models. Internal IDs and saved builds remain unchanged.
Config.PartRestrictions = {
    turbo = {
        NATURALLY_ASPIRATED = { unavailableFor = {} }, SMALL = { unavailableFor = {} },
        MEDIUM = { unavailableFor = {} }, LARGE = { unavailableFor = {} },
        QUICK_SPOOL = { unavailableFor = {} }, BIG_BLOWOFF = { unavailableFor = {} }
    },
    ecu = {
        FACTORY = { unavailableFor = {} }, RESPONSIVE = { unavailableFor = {} },
        LINEAR = { unavailableFor = {} }, TOP_END = { unavailableFor = {} }
    },
    engine = {
        FACTORY = { unavailableFor = {} }, HIGH_COMPRESSION = { unavailableFor = {} },
        BALANCED = { unavailableFor = {"thrax"} }, REV_HAPPY = { unavailableFor = {"thrax"} },
        SK8 = { unavailableFor = {"thrax"} }, ST69_V12 = { unavailableFor = {"thrax"} },
        STR17_MACH1 = { unavailableFor = {} }, STR025_F20C = { unavailableFor = {} },
        STR022_13BT = { unavailableFor = {} }, STR021_M3E30 = { unavailableFor = {} }
    },
    flywheel = {
        HEAVY = { unavailableFor = {} }, FACTORY = { unavailableFor = {} },
        LIGHTWEIGHT = { unavailableFor = {} }
    },
    transmission = {
        FACTORY = { unavailableFor = {} }, SHORT = { unavailableFor = {} },
        MEDIUM = { unavailableFor = {} }, LONG = { unavailableFor = {"gbargento7f"} }
    },
    fuelpump = {
        FACTORY = { unavailableFor = {} }, HIGH_FLOW = { unavailableFor = {} },
        MOTORSPORT = { unavailableFor = {} }
    },
    nitro = {
        NONE = { unavailableFor = {} }, STREET = { unavailableFor = {} },
        PRO = { unavailableFor = {} }, COMPETITION = { unavailableFor = {} }
    },
    differential = {
        FACTORY = { unavailableFor = {} }, SPORT = { unavailableFor = {} },
        LIMITED_SLIP = { unavailableFor = {} }, ACTIVE = { unavailableFor = {} }
    },
    brakes = {
        STREET = { unavailableFor = {} }, SPORT = { unavailableFor = {} }, TRACK = { unavailableFor = {} }
    },
    suspension = {
        FACTORY = { unavailableFor = {} }, STREET = { unavailableFor = {} },
        SPORT = { unavailableFor = {} }, TRACK = { unavailableFor = {} },
        ANGLE = { unavailableFor = {} }, DRIFT = { unavailableFor = {} },
        OFFROAD = { unavailableFor = {} }
    },
    tireCompound = {
        STREET = { unavailableFor = {} }, SPORT = { unavailableFor = {} },
        SEMI_SLICK = { unavailableFor = {} }, DRAG = { unavailableFor = {} },
        DRIFT = { unavailableFor = {} }, OFFROAD = { unavailableFor = {} },
        STREET_RACE = { unavailableFor = {} }
    }
}

-- Server-authoritative part prices used when creating quotes.
Config.DisplayPrices = {
    turbo = { NATURALLY_ASPIRATED = 0, SMALL = 4200, MEDIUM = 7800, LARGE = 13500,
        QUICK_SPOOL = 9800, BIG_BLOWOFF = 16800 },
    ecu = { FACTORY = 0, RESPONSIVE = 1800, LINEAR = 2400, TOP_END = 3200 },
    engine = { FACTORY = 0, HIGH_COMPRESSION = 9200, BALANCED = 11800, REV_HAPPY = 15600,
        SK8 = 18500, ST69_V12 = 32000, STR17_MACH1 = 23800, STR025_F20C = 14200,
        STR022_13BT = 17600, STR021_M3E30 = 15800 },
    flywheel = { HEAVY = 1800, FACTORY = 0, LIGHTWEIGHT = 4200 },
    transmission = { FACTORY = 0, SHORT = 5800, MEDIUM = 7200, LONG = 8600 },
    fuelpump = { FACTORY = 0, HIGH_FLOW = 2100, MOTORSPORT = 4600 },
    nitro = { NONE = 0, STREET = 5200, PRO = 9200, COMPETITION = 14800 },
    transmissionPersonalities = { AUTOMATIC = 0, SPORT_AUTOMATIC = 1600, DCT = 4800, MANUAL = 3200 },
    differential = { FACTORY = 0, SPORT = 3200, LIMITED_SLIP = 5400, ACTIVE = 9800 },
    brakes = { STREET = 0, SPORT = 3800, TRACK = 7600 },
    suspension = { FACTORY = 0, STREET = 3200, SPORT = 6800, TRACK = 11200,
        ANGLE = 7400, DRIFT = 9200, OFFROAD = 8600 },
    maps = { [1] = 650, [2] = 950, [3] = 1450 },
    compounds = { STREET = 0, SPORT = 1400, SEMI_SLICK = 2600, DRAG = 3100,
        DRIFT = 1800, OFFROAD = 2200, STREET_RACE = 2800 }
}

-- Shift behavior is independent from the installed ratio set. Clutch multipliers
-- always apply to the captured factory handling values.
Config.TransmissionPersonalities = {
    AUTOMATIC = {
        label = 'Automatic', description = 'Smooth, relaxed automatic shifts.',
        clutchUp = 0.82, clutchDown = 0.78, shiftDuration = 0.36, shiftPowerFloor = 0.72
    },
    SPORT_AUTOMATIC = {
        label = 'Sport Automatic', description = 'Quicker shifts with a firmer torque handover.',
        clutchUp = 1.45, clutchDown = 1.30, shiftDuration = 0.22, shiftPowerFloor = 0.64
    },
    DCT = {
        label = 'DCT', description = 'Near-instant, aggressive dual-clutch shifts.',
        clutchUp = 2.80, clutchDown = 2.45, shiftDuration = 0.10, shiftPowerFloor = 0.82
    },
    MANUAL = {
        label = 'Manual', description = 'Driver-selected gears with direct shift response.',
        clutchUp = 1.15, clutchDown = 1.05, shiftDuration = 0.28, shiftPowerFloor = 0.48,
        manual = true
    }
}

Config.ManualTransmission = {
    shiftUpCommand = 'torqueworks_shift_up', shiftDownCommand = 'torqueworks_shift_down',
    shiftUpKey = 'PAGEUP', shiftDownKey = 'PAGEDOWN',
    soundEnabled = true, soundVolume = 0.32,
    downshiftRevMatch = 0.14
}

Config.EcuMaps = {
    [1] = {
        label = 'Road', boostMultiplier = 0.82, revLimit = 0.86,
        limiterSoftZone = 0.025, limiterFloor = 0.12,
        throttleExponent = 1.25, throttleResponseRate = 3.5,
        boostByGear = { [0] = 0.0, 0.45, 0.70, 0.84, 0.90, 0.95, 1.00, 1.00 }
    },
    [2] = {
        label = 'Sport', boostMultiplier = 1.00, revLimit = 0.94,
        limiterSoftZone = 0.020, limiterFloor = 0.10,
        throttleExponent = 1.00, throttleResponseRate = 6.0,
        boostByGear = { [0] = 0.0, 0.68, 0.84, 0.94, 1.00, 1.00, 1.00, 1.00 }
    },
    [3] = {
        label = 'Race', boostMultiplier = 1.15, revLimit = 0.99,
        limiterSoftZone = 0.015, limiterFloor = 0.08,
        throttleExponent = 0.72, throttleResponseRate = 10.0,
        boostByGear = { [0] = 0.0, 0.82, 0.94, 1.00, 1.00, 1.00, 1.00, 1.00 }
    }
}

-- One vehicle-specific active calibration. There are deliberately no map slots,
-- names or save workflow: changes are validated server-side and written directly
-- into the vehicle build JSON.
Config.EcuCalibration = {
    defaults = { customEnabled = false, boost = 1.00, pops = 'OFF', launchEnabled = false, launchRpm = 3800 },
    boost = { minimum = 0.70, maximum = 1.25, increment = 0.05 },
    launchRpm = { minimum = 2500, maximum = 5500, increment = 100 },
    launch = {
        maximumSpeedKmh = 4.0, minimumThrottle = 0.72,
        referenceRedlineRpm = 8000, holdFloor = 0.08, softZoneRpm = 350
    },
    pops = {
        OFF = { label = 'OFF', enabled = false },
        SPORT = { label = 'SPORT', enabled = true, rpmMultiplier = 1.00, cooldownMultiplier = 1.00,
            burstCount = 2, burstIntervalMs = 440 },
        AGGRESSIVE = { label = 'AGGRESSIVE', enabled = true, rpmMultiplier = 0.86, cooldownMultiplier = 0.62,
            burstCount = 4, burstIntervalMs = 280 }
    }
}

Config.TirePressure = {
    minimum = 15.0,
    maximum = 45.0,
    increment = 0.5,
    pressureGripPenalty = 0.14,
    underInflationDragPerPsi = 0.012
}

Config.TireCompounds = {
    STREET = {
        label = 'Veloce S1', grip = 1.00, lateralGrip = 1.00,
        lowSpeedLoss = 1.00, optimalPressure = 32.0, pressureTolerance = 12.0
    },
    SPORT = {
        label = 'Veloce R3', grip = 1.07, lateralGrip = 1.04,
        lowSpeedLoss = 0.94, optimalPressure = 31.0, pressureTolerance = 10.0
    },
    SEMI_SLICK = {
        label = 'Veloce RS-X', grip = 1.14, lateralGrip = 1.08,
        lowSpeedLoss = 0.86, optimalPressure = 29.0, pressureTolerance = 8.0
    },
    DRAG = {
        label = 'Veloce D8', grip = 1.18, lateralGrip = 0.93,
        lowSpeedLoss = 0.70, optimalPressure = 20.0, pressureTolerance = 7.0
    },
    DRIFT = {
        label = 'Veloce Slide-S', purpose = 'DRIFT', grip = 0.96, lateralGrip = 0.88,
        lowSpeedLoss = 1.28, surfaceLossMultiplier = 1.04,
        optimalPressure = 36.0, pressureTolerance = 8.0
    },
    OFFROAD = {
        label = 'Veloce Terra-A/T', purpose = 'OFF-ROAD', grip = 1.03, lateralGrip = 0.98,
        lowSpeedLoss = 0.88, surfaceLossMultiplier = 0.72,
        optimalPressure = 26.0, pressureTolerance = 10.0
    },
    STREET_RACE = {
        label = 'Veloce Urban-R', purpose = 'STREET RACE', grip = 1.11, lateralGrip = 1.08,
        lowSpeedLoss = 0.86, surfaceLossMultiplier = 0.96,
        optimalPressure = 30.0, pressureTolerance = 7.0
    }
}
