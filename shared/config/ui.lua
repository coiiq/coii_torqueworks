-- Player-facing UI and world interaction presentation.
Config.BuildName = {
    maxLength = 24
}

Config.Mmi = {
    item = 'coii_mmi',
    prop = 'prop_cs_tablet',
    renderDistance = 35.0,
    scanIntervalMs = 1000,
    updateIntervalMs = 16,
    installMaxSpeed = 0.5,
    rayDistance = 3.0,
    -- Placement fallback for vehicle interiors without raycastable collision.
    previewDepth = 0.55,
    minimumDepth = 0.30,
    maximumDepth = 1.20,
    depthStep = 0.025,
    movementSpeed = 0.22,
    scale = 0.72,
    interactionKey = 'F7',
    interactionMaxSpeed = 1.0,
    dui = {
        enabled = true,
        width = 1024,
        height = 600,
        refreshMs = 100,
        screen = {
            width = 0.160, height = 0.200,
            y = -0.007, x = 0.0, z = 0.0,
            rotation = 90
        }
    },
    -- Server-side limits for vehicle-local prop placement.
    positionLimits = {
        x = { -1.5, 1.5 }, y = { -2.5, 2.5 }, z = { -0.5, 2.0 }
    },
    rotationStep = 2.0
}

Config.VehicleClass = {
    baseRating = 300,
    tiers = {
        { minimum = 650, label = 'S+' }, { minimum = 550, label = 'S' },
        { minimum = 500, label = 'A+' }, { minimum = 450, label = 'A' },
        { minimum = 400, label = 'B' }, { minimum = 350, label = 'C' },
        { minimum = 200, label = 'D' }
    },
    points = {
        turbo = { NATURALLY_ASPIRATED = 0, SMALL = 22, MEDIUM = 42, LARGE = 70,
            QUICK_SPOOL = 48, BIG_BLOWOFF = 78 },
        ecu = { FACTORY = 0, RESPONSIVE = 14, LINEAR = 20, TOP_END = 28 },
        engine = { FACTORY = 0, HIGH_COMPRESSION = 35, BALANCED = 45, REV_HAPPY = 58, SK8 = 68, ST69_V12 = 100,
            STR17_MACH1 = 74, STR025_F20C = 52, STR022_13BT = 64, STR021_M3E30 = 57 },
        flywheel = { HEAVY = 3, FACTORY = 0, LIGHTWEIGHT = 14 },
        transmission = { FACTORY = 0, SHORT = 24, MEDIUM = 30, LONG = 34 },
        fuelpump = { FACTORY = 0, HIGH_FLOW = 10, MOTORSPORT = 20 },
        nitro = { NONE = 0, STREET = 18, PRO = 34, COMPETITION = 52 },
        brakes = { STREET = 0, SPORT = 14, TRACK = 28 },
        suspension = { FACTORY = 0, STREET = 8, SPORT = 18, TRACK = 30,
            ANGLE = 16, DRIFT = 22, OFFROAD = 18 },
        differential = { FACTORY = 0, SPORT = 12, LIMITED_SLIP = 22, ACTIVE = 32 },
        tireCompound = { STREET = 0, SPORT = 12, SEMI_SLICK = 24, DRAG = 28,
            DRIFT = 8, OFFROAD = 14, STREET_RACE = 20 },
        ecuMap = { [1] = 0, [2] = 8, [3] = 16 }
    }
}

Config.BuildCard = {
    validationDistance = 3.0,
    previewDistance = 4.0,
    previewRefreshMs = 15000,
    scanIntervalMs = 400,
    positionUpdateMs = 33,
    historyLimit = 20,
    zones = {
        {
            name = 'carshow', enabled = true, type = 'box',
            coords = { x = 1124.96, y = -786.36, z = 56.02 },
            size = { x = 35, y = 18, z = 8.0 },
            rotation = 90.0,
            debug = false
        }
    }
}
