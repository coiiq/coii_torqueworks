-- Saved builds contain only these server-trusted identifiers, never physics values.
Config.Parts = {
    turbo = {
        NATURALLY_ASPIRATED = { label = 'Aeris Velocity Stack', threshold = 1.00, maxBoost = 0.00, spoolRate = 0.0, releaseRate = 6.0 },
        SMALL = { label = 'Kaze T28', threshold = 0.18, maxBoost = 0.10, spoolRate = 3.8, releaseRate = 5.0,
            wastegateSound = 'audio/turbos/small.wav', wastegateVolume = 0.12 },
        MEDIUM = { label = 'Kaze T44', threshold = 0.28, maxBoost = 0.12, spoolRate = 2.7, releaseRate = 4.2,
            wastegateSound = 'audio/turbos/medium.wav', wastegateVolume = 0.08 },
        LARGE = { label = 'Kaze T67-R', threshold = 0.48, maxBoost = 0.22, spoolRate = 0.75, releaseRate = 1.8,
            wastegateSound = 'audio/turbos/large.wav', wastegateVolume = 0.06 },
        QUICK_SPOOL = {
            label = 'Kaze Pulse-48', compatibilityClass = 'MEDIUM',
            threshold = 0.22, maxBoost = 0.15, spoolRate = 4.6, releaseRate = 5.8,
            wastegateSound = 'audio/turbos/pshh.wav', wastegateVolume = 0.17
        },
        BIG_BLOWOFF = {
            label = 'Kaze Titan-88', compatibilityClass = 'LARGE',
            threshold = 0.56, maxBoost = 0.29, spoolRate = 0.52, releaseRate = 1.35,
            wastegateSound = 'audio/turbos/bigblowoff.wav', wastegateVolume = 0.11
        }
    },
    ecu = {
        FACTORY = { label = 'Synapse Core', curve = { { rpm = 0.00, torque = 1.00 }, { rpm = 1.00, torque = 1.00 } } },
        RESPONSIVE = { label = 'Synapse R1', curve = {
            { rpm = 0.00, torque = 0.91 }, { rpm = 0.18, torque = 1.02 },
            { rpm = 0.38, torque = 1.12 }, { rpm = 0.62, torque = 1.08 },
            { rpm = 0.82, torque = 0.96 }, { rpm = 1.00, torque = 0.83 }
        } },
        LINEAR = { label = 'Synapse X2', curve = {
            { rpm = 0.00, torque = 0.88 }, { rpm = 0.20, torque = 0.97 },
            { rpm = 0.42, torque = 1.05 }, { rpm = 0.68, torque = 1.08 },
            { rpm = 0.86, torque = 1.04 }, { rpm = 1.00, torque = 0.94 }
        } },
        TOP_END = { label = 'Synapse V-Max', curve = {
            { rpm = 0.00, torque = 0.72 }, { rpm = 0.22, torque = 0.76 },
            { rpm = 0.42, torque = 0.84 }, { rpm = 0.60, torque = 0.98 },
            { rpm = 0.78, torque = 1.12 }, { rpm = 0.92, torque = 1.19 },
            { rpm = 1.00, torque = 1.14 }
        } }
    },
    engine = {
        FACTORY = { label = 'Origin Long Block', engineType = 'OEM', torque = 1.00, driveInertia = 1.00, maxFlatVel = 1.00 },
        HIGH_COMPRESSION = { label = 'Bravura HC-24', engineType = 'I4', torque = 1.02, driveInertia = 1.08, maxFlatVel = 0.94 },
        BALANCED = { label = 'ST77 GTR', engineType = 'V6', torque = 1.00, driveInertia = 1.02, maxFlatVel = 1.01, audioName = 'st77gtr' },
        REV_HAPPY = { label = 'SK8-R Sprint', engineType = 'I6', torque = 0.98, driveInertia = 0.94, maxFlatVel = 1.12 },
        -- `audioName` may reference a GTA profile or a custom sound DLC profile.
        SK8 = { label = 'SR15 Atom', engineType = 'V8', torque = 1.03, driveInertia = 0.90, maxFlatVel = 1.08, audioName = 'sr15atom' },
        ST69_V12 = {
            label = 'ST69 Zagato', engineType = 'V12',
            torque = 1.16, driveInertia = 1.18, maxFlatVel = 1.22,
            audioName = 'st69zagato'
        },
        STR17_MACH1 = {
            label = 'Ravenport M17', engineType = 'V8', torque = 1.10,
            driveInertia = 0.96, maxFlatVel = 1.10, audioName = 'str17mach1gen1'
        },
        STR025_F20C = {
            label = 'Kairo F20-R', engineType = 'I4', torque = 0.96,
            driveInertia = 0.86, maxFlatVel = 1.14, audioName = 'str025f20c'
        },
        STR022_13BT = {
            label = 'Rotec R13-T', engineType = 'ROTARY', torque = 1.01,
            driveInertia = 0.82, maxFlatVel = 1.16, audioName = 'str02213bt'
        },
        STR021_M3E30 = {
            label = 'Valken E30-R', engineType = 'I4', torque = 1.00,
            driveInertia = 0.88, maxFlatVel = 1.10, audioName = 'str021m3e30'
        }
    },
    flywheel = {
        HEAVY = { label = 'Graviton H8', driveInertia = 0.82, throttleResponse = 0.72, rpmFallRate = 0.28 },
        FACTORY = { label = 'Origin Flywheel', driveInertia = 1.00, throttleResponse = 1.00, rpmFallRate = 0.55 },
        LIGHTWEIGHT = { label = 'Razor LT-4', driveInertia = 1.22, throttleResponse = 1.35, rpmFallRate = 1.05 }
    },
    transmission = {
        FACTORY = { label = 'Origin Gearset', gearCount = nil, ratios = nil },
        SHORT = { label = 'Strada SR6', gearCount = 6, ratios = { 3.35, 2.28, 1.68, 1.32, 1.08, 0.91 } },
        MEDIUM = { label = 'Vector MX7', gearCount = 7, ratios = { 3.05, 2.10, 1.55, 1.22, 1.00, 0.84, 0.73 } },
        LONG = { label = 'Aeroline LX8', gearCount = 8, ratios = { 2.72, 1.90, 1.42, 1.12, 0.91, 0.76, 0.65, 0.57 } }
    },
    fuelpump = {
        FACTORY = { label = 'Origin Fuel Cell', flow = 1.00, backfire = false },
        HIGH_FLOW = { label = 'Flux F900', flow = 1.18, backfire = false },
        MOTORSPORT = {
            label = 'Flux Blackline', flow = 1.35, backfire = true,
            backfireRpm = 0.58, throttleFrom = 0.68, throttleTo = 0.16,
            cooldownMs = 420,
            particleDictionary = 'veh_xs_vehicle_mods', particleName = 'veh_nitrous',
            particleScale = 0.58, particleDurationMs = 145
        }
    },
    nitro = {
        NONE = {
            label = 'Origin Bypass', enabled = false,
            durationMs = 0, powerMultiplier = 1.0, particleScale = 0.0
        },
        STREET = {
            label = 'Voltic N20-S', enabled = true,
            durationMs = 2400, powerMultiplier = 1.22, particleScale = 0.72
        },
        PRO = {
            label = 'Voltic N20-R', enabled = true,
            durationMs = 3500, powerMultiplier = 1.42, particleScale = 0.88
        },
        COMPETITION = {
            label = 'Voltic Blackshot', enabled = true,
            durationMs = 4300, powerMultiplier = 1.62, particleScale = 1.0
        }
    },
    brakes = {
        STREET = {
            label = 'Velin Streetline', forceMultiplier = 1.00,
            pedalExponent = 1.12, pedalResponse = 7.0,
            heatRate = 0.42, coolingRate = 0.025, fadeStart = 0.55, maximumFade = 0.22
        },
        SPORT = {
            label = 'Velin Sport-R', forceMultiplier = 1.12,
            pedalExponent = 0.95, pedalResponse = 10.0,
            heatRate = 0.32, coolingRate = 0.035, fadeStart = 0.68, maximumFade = 0.16
        },
        TRACK = {
            label = 'Velin Apex-6', forceMultiplier = 1.20,
            pedalExponent = 0.80, pedalResponse = 14.0,
            heatRate = 0.24, coolingRate = 0.050, fadeStart = 0.82, maximumFade = 0.10
        }
    },
    suspension = {
        FACTORY = {
            label = 'Origin Chassis', stiffness = 1.00,
            compressionDamping = 1.00, reboundDamping = 1.00,
            antiRollForce = 1.00, antiRollBiasOffset = 0.00
        },
        STREET = {
            label = 'Vektor Street-R', stiffness = 1.08,
            compressionDamping = 1.10, reboundDamping = 1.08,
            antiRollForce = 1.08, antiRollBiasOffset = 0.00
        },
        SPORT = {
            label = 'Vektor Clubsport', stiffness = 1.22,
            compressionDamping = 1.25, reboundDamping = 1.28,
            antiRollForce = 1.28, antiRollBiasOffset = 0.02
        },
        TRACK = {
            label = 'Vektor Circuit-X', stiffness = 1.38,
            compressionDamping = 1.38, reboundDamping = 1.48,
            antiRollForce = 1.48, antiRollBiasOffset = -0.02
        },
        ANGLE = {
            label = 'Vektor Lock-X', purpose = 'ANGLE', steeringLock = 1.38,
            stiffness = 1.18, compressionDamping = 1.22, reboundDamping = 1.26,
            antiRollForce = 1.20, antiRollBiasOffset = 0.00
        },
        DRIFT = {
            label = 'Vektor Slide-R', purpose = 'DRIFT', steeringLock = 1.30,
            stiffness = 1.24, compressionDamping = 1.18, reboundDamping = 1.32,
            antiRollForce = 1.15, antiRollBiasOffset = 0.05,
            tractionBiasOffset = 0.04, lateralGrip = 0.94, lowSpeedLoss = 1.22
        },
        OFFROAD = {
            label = 'Vektor Terra-X', purpose = 'OFF-ROAD', steeringLock = 1.06,
            stiffness = 0.78, compressionDamping = 0.82, reboundDamping = 0.88,
            antiRollForce = 0.62, antiRollBiasOffset = 0.00,
            suspensionUpperLimit = 1.35, suspensionLowerLimit = 1.35,
            surfaceLossMultiplier = 0.78, lateralGrip = 0.98, lowSpeedLoss = 0.92
        }
    },
    differential = {
        FACTORY = { label = 'Origin Open-Diff', lsdLock = 0.00, tractionLossMultiplier = 1.00 },
        SPORT = { label = 'Helix S25', lsdLock = 0.25, tractionLossMultiplier = 0.92 },
        LIMITED_SLIP = { label = 'Helix M55', lsdLock = 0.55, tractionLossMultiplier = 0.80 },
        ACTIVE = { label = 'Helix Vector 78', lsdLock = 0.78, tractionLossMultiplier = 0.72 }
    }
}
