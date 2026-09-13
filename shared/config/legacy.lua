-- Read-only migration map for V0.1 profile rows.
Config.LegacyBuilds = {
    STOCK = Config.FactoryBuild,
    STREET = { turbo = 'SMALL', ecu = 'RESPONSIVE', engine = 'HIGH_COMPRESSION', transmission = 'SHORT', differential = 'SPORT' },
    TRACK = { turbo = 'MEDIUM', ecu = 'LINEAR', engine = 'BALANCED', transmission = 'MEDIUM', differential = 'LIMITED_SLIP' },
    HIGHWAY = { turbo = 'LARGE', ecu = 'TOP_END', engine = 'REV_HAPPY', transmission = 'LONG', differential = 'ACTIVE' }
}
