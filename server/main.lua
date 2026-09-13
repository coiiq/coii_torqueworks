local Framework = TorqueWorksFramework
local requestCooldowns = {}
local nitroSessions = {}
local nitroReuseAt = {}
local nitroAutoRefillTokens = {}
local nitroAutoRefillEnabled = {}
local trustedBuilds = {}
local settlingPlates = {}
local settlingPlayers = {}

math.randomseed(os.time() + GetGameTimer())

local function normalizePlate(plate)
    if type(plate) ~= 'string' then return nil end
    plate = plate:upper():gsub('^%s+', ''):gsub('%s+$', '')
    if #plate < 1 or #plate > 12 or not plate:match('^[%w%s%-]+$') then return nil end
    return plate
end

local function factoryEfficiency(seed)
    local bucket = (tonumber(seed) * 1103515245 + 12345) % 20001
    return 0.99 + (bucket / 20000.0) * 0.02
end

local function normalizeBuildName(value)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('[%c]', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    value = value:gsub("[^%w%s%-%_']", '')
    return value:sub(1, Config.BuildName.maxLength)
end

local function normalizeEcuCalibration(value)
    value = type(value) == 'table' and value or {}
    local defaults = Config.EcuCalibration.defaults
    local boostConfig, launchConfig = Config.EcuCalibration.boost, Config.EcuCalibration.launchRpm
    local boost = TorqueWorksMath.clamp(tonumber(value.boost) or defaults.boost,
        boostConfig.minimum, boostConfig.maximum)
    boost = math.floor(boost / boostConfig.increment + 0.5) * boostConfig.increment
    local launchRpm = TorqueWorksMath.clamp(tonumber(value.launchRpm) or defaults.launchRpm,
        launchConfig.minimum, launchConfig.maximum)
    launchRpm = math.floor(launchRpm / launchConfig.increment + 0.5) * launchConfig.increment
    local pops = type(value.pops) == 'string' and value.pops:upper() or defaults.pops
    if not Config.EcuCalibration.pops[pops] then pops = defaults.pops end
    return {
        customEnabled = value.customEnabled == true,
        boost = boost, pops = pops,
        launchEnabled = value.launchEnabled == true,
        launchRpm = launchRpm
    }
end

local function driverVehicle(source)
    local ped = GetPlayerPed(source)
    if ped == 0 then return 0 end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return 0 end
    return vehicle
end

local function isSupportedCar(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    return GetVehicleType(vehicle) == 'automobile'
end

local function workshopById(workshopId)
    if type(workshopId) ~= 'string' or type(Config.Workshops) ~= 'table' then return nil end
    return Config.Workshops[workshopId]
end

local function privilegedMechanic(source, xPlayer)
    if Config.MechanicAccess.acePermission and
        IsPlayerAceAllowed(source, Config.MechanicAccess.acePermission) then return true end
    if not xPlayer then return false end
    local group = xPlayer.getGroup and xPlayer.getGroup() or xPlayer.group
    if group and Config.MechanicAccess.adminGroups[group] then return true end
    return false
end

local function hasWorkshopJob(xPlayer, workshop)
    if not xPlayer or type(workshop) ~= 'table' then return false end
    local job = xPlayer.getJob and xPlayer.getJob() or xPlayer.job
    if not job or not job.name then return false end
    local minimumGrade = type(workshop.jobs) == 'table' and workshop.jobs[job.name] or nil
    return minimumGrade ~= nil and (tonumber(job.grade) or 0) >= minimumGrade
end

local function hasMechanicAccess(source, workshopId)
    local xPlayer = Framework.GetPlayerFromId(source)
    if privilegedMechanic(source, xPlayer) then return true end
    if workshopId then return hasWorkshopJob(xPlayer, workshopById(workshopId)) end
    for _, workshop in pairs(Config.Workshops or {}) do
        if hasWorkshopJob(xPlayer, workshop) then return true end
    end
    return false
end

local function playerIdentifier(xPlayer)
    if not xPlayer then return nil end
    return xPlayer.identifier or (xPlayer.getIdentifier and xPlayer.getIdentifier())
end

local function roleplayName(xPlayer, source)
    local function clean(firstName, lastName)
        local name = (('%s %s'):format(firstName or '', lastName or ''))
            :gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
        return name ~= '' and name or nil
    end
    local function playerValue(key)
        if not xPlayer then return nil end
        if type(xPlayer.get) == 'function' then
            local ok, value = pcall(function() return xPlayer.get(key) end)
            if ok and value ~= nil then return value end
        end
        if type(xPlayer.variables) == 'table' and xPlayer.variables[key] ~= nil then
            return xPlayer.variables[key]
        end
        return xPlayer[key]
    end

    local characterName = clean(playerValue('firstName') or playerValue('firstname'),
        playerValue('lastName') or playerValue('lastname'))
    if characterName then return characterName end

    local identifier = playerIdentifier(xPlayer)
    if Framework.name == 'esx' and identifier and MySQL and MySQL.single and MySQL.single.await then
        local ok, row = pcall(function()
            return MySQL.single.await('SELECT firstname, lastname FROM users WHERE identifier = ? LIMIT 1',
                { identifier })
        end)
        characterName = ok and row and clean(row.firstname, row.lastname) or nil
        if characterName then return characterName end
    end

    if xPlayer and type(xPlayer.getName) == 'function' then
        local ok, name = pcall(function() return xPlayer.getName() end)
        if ok and type(name) == 'string' and name:gsub('%s+', '') ~= '' then return name end
    end
    return GetPlayerName(source) or 'Mechanic'
end

local function notifyIdentifier(identifier, notification)
    if not identifier then return end
    for _, playerId in ipairs(GetPlayers()) do
        local target = Framework.GetPlayerFromId(tonumber(playerId))
        if playerIdentifier(target) == identifier then
            Config.Integrations.serverNotification(tonumber(playerId), notification)
            return
        end
    end
end

local function sourceForIdentifier(identifier)
    if not identifier then return nil end
    for _, playerId in ipairs(GetPlayers()) do
        local numericId = tonumber(playerId)
        if playerIdentifier(Framework.GetPlayerFromId(numericId)) == identifier then return numericId end
    end
end

local function installationBypass(source)
    if not Config.Installation.adminBypass then return false end
    local xPlayer = Framework.GetPlayerFromId(source)
    if not xPlayer then return false end
    local group = xPlayer.getGroup and xPlayer.getGroup() or xPlayer.group
    return group and Config.MechanicAccess.adminGroups[group] == true or false
end

local function isAtWorkshopLocation(source, workshopId, locationType)
    local workshop = workshopById(workshopId)
    local location = workshop and workshop[locationType]
    if not location or location.enabled == false then return false end
    local coords = location.coords or location.station
    if not coords then return false end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local target = vector3(coords.x, coords.y, coords.z)
    local allowedDistance = location.interactDistance or
        (locationType == 'dyno' and Config.Dyno.interactionDistance) or 3.0
    return #(GetEntityCoords(ped) - target) <= (allowedDistance + 2.0)
end

local function resolvedInstallationItem(key)
    local configured = Config.Installation
    local definition = configured.items and configured.items[key] or nil
    local itemName = definition and definition.item or key
    if type(itemName) ~= 'string' or itemName == '' then return nil end
    local inventoryItem = Framework.GetItemDefinition(itemName)
    return {
        item = itemName,
        label = inventoryItem and inventoryItem.label or definition and definition.label or itemName,
        image = inventoryItem and inventoryItem.image or definition and definition.image
    }
end

local function installationCatalog()
    local configured = Config.Installation
    local catalog = {
        consumable = configured.consumable,
        requirements = configured.requirements,
        adminBypass = configured.adminBypass,
        items = {}
    }
    local function append(entries)
        for _, requirement in ipairs(entries or {}) do
            if type(requirement) == 'table' and type(requirement.item) == 'string' and not catalog.items[requirement.item] then
                catalog.items[requirement.item] = resolvedInstallationItem(requirement.item)
            end
        end
    end
    append(configured.requirements and configured.requirements.universal)
    for _, category in pairs(configured.requirements and configured.requirements.parts or {}) do
        for _, entries in pairs(category) do append(entries) end
    end
    return catalog
end

local function installationRequirements(category, partId)
    local installation, resolved = Config.Installation, {}
    local function append(entries)
        for _, requirement in ipairs(entries or {}) do
            local definition = type(requirement) == 'table' and resolvedInstallationItem(requirement.item)
            if definition then
                resolved[#resolved + 1] = {
                    item = definition.item,
                    label = definition.label or definition.item,
                    amount = math.max(1, math.floor(tonumber(requirement.amount) or 1))
                }
            end
        end
    end
    append(installation.requirements and installation.requirements.universal)
    local categoryRequirements = installation.requirements and installation.requirements.parts and
        installation.requirements.parts[category]
    append(categoryRequirements and categoryRequirements[partId])
    return resolved
end

local function validatedDrivenVehicle(source, plate, networkId)
    plate = normalizePlate(plate)
    if not plate or type(networkId) ~= 'number' or settlingPlates[plate] then return 0, nil end
    local vehicle = driverVehicle(source)
    if vehicle == 0 or NetworkGetNetworkIdFromEntity(vehicle) ~= networkId then return 0, nil end
    if normalizePlate(GetVehicleNumberPlateText(vehicle)) ~= plate then return 0, nil end
    if not Framework.IsVehicleOwned(plate) then return 0, nil, 'not_owned' end
    return vehicle, plate
end

local function validatedInstallationVehicle(source, plate, networkId, allowNearby)
    if allowNearby ~= true then return validatedDrivenVehicle(source, plate, networkId) end
    plate = normalizePlate(plate)
    if not plate or type(networkId) ~= 'number' then return 0, nil end
    local vehicle = NetworkGetEntityFromNetworkId(networkId)
    local ped = GetPlayerPed(source)
    if vehicle == 0 or not DoesEntityExist(vehicle) or ped == 0 or
        #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > 8.0 or
        normalizePlate(GetVehicleNumberPlateText(vehicle)) ~= plate then return 0, nil end
    if not Framework.IsVehicleOwned(plate) then return 0, nil, 'not_owned' end
    return vehicle, plate
end

local function copyBuild(source)
    local build = {}
    for category in pairs(Config.PartCategories) do build[category] = source[category] end
    build.ecuMap = tonumber(source.ecuMap) or Config.FactoryBuild.ecuMap
    build.ecuCalibration = normalizeEcuCalibration(source.ecuCalibration)
    build.tireCompound = source.tireCompound or Config.FactoryBuild.tireCompound
    build.tirePressure = tonumber(source.tirePressure) or Config.FactoryBuild.tirePressure
    build.frontTorqueBias = tonumber(source.frontTorqueBias) or Config.FactoryBuild.frontTorqueBias
    build.transmissionPersonality = source.transmissionPersonality or Config.FactoryBuild.transmissionPersonality
    build.nitroLevel = TorqueWorksMath.clamp(tonumber(source.nitroLevel) or 0.0, 0.0, 1.0)
    build.buildName = normalizeBuildName(source.buildName)
    build.buildVisibility = ({ PUBLIC = true, PERFORMANCE = true, PRIVATE = true })[source.buildVisibility]
        and source.buildVisibility or Config.FactoryBuild.buildVisibility
    return build
end

local function normalizeBuild(saved)
    if type(saved) ~= 'table' then saved = {} end
    local needsMigration = saved.flywheel == nil or saved.ecuMap == nil or saved.tireCompound == nil or
        saved.tirePressure == nil or saved.frontTorqueBias == nil or saved.transmissionPersonality == nil or
        saved.fuelpump == nil or saved.nitro == nil or saved.brakes == nil or saved.suspension == nil or saved.nitroLevel == nil or
        saved.buildVisibility == nil or saved.ecuCalibration == nil
    local legacy = type(saved.profile) == 'string' and Config.LegacyBuilds[saved.profile:upper()] or nil
    local source = legacy or saved
    local build = {}
    for category in pairs(Config.PartCategories) do
        local partId = type(source[category]) == 'string' and source[category]:upper() or Config.FactoryBuild[category]
        build[category] = Config.Parts[category][partId] and partId or Config.FactoryBuild[category]
    end
    local ecuMap = math.floor(tonumber(source.ecuMap) or Config.FactoryBuild.ecuMap)
    build.ecuMap = Config.EcuMaps[ecuMap] and ecuMap or Config.FactoryBuild.ecuMap
    build.ecuCalibration = normalizeEcuCalibration(source.ecuCalibration)
    local compound = type(source.tireCompound) == 'string' and source.tireCompound:upper() or Config.FactoryBuild.tireCompound
    build.tireCompound = Config.TireCompounds[compound] and compound or Config.FactoryBuild.tireCompound
    local personality = type(source.transmissionPersonality) == 'string' and source.transmissionPersonality:upper()
        or Config.FactoryBuild.transmissionPersonality
    build.transmissionPersonality = Config.TransmissionPersonalities[personality] and personality
        or Config.FactoryBuild.transmissionPersonality
    build.nitroLevel = TorqueWorksMath.clamp(tonumber(source.nitroLevel) or 0.0, 0.0, 1.0)
    local pressure = tonumber(source.tirePressure) or Config.FactoryBuild.tirePressure
    pressure = math.floor((pressure / Config.TirePressure.increment) + 0.5) * Config.TirePressure.increment
    build.tirePressure = TorqueWorksMath.clamp(pressure, Config.TirePressure.minimum, Config.TirePressure.maximum)
    local frontBias = tonumber(source.frontTorqueBias)
    if not frontBias or frontBias < 0.0 then
        build.frontTorqueBias = -1.0
    else
        build.frontTorqueBias = TorqueWorksMath.clamp(math.floor(frontBias * 20.0 + 0.5) / 20.0, 0.0, 1.0)
    end
    if build.differential ~= 'ACTIVE' then build.frontTorqueBias = -1.0 end
    build.buildName = normalizeBuildName(source.buildName)
    local visibility = type(source.buildVisibility) == 'string' and source.buildVisibility:upper() or nil
    build.buildVisibility = ({ PUBLIC = true, PERFORMANCE = true, PRIVATE = true })[visibility]
        and visibility or Config.FactoryBuild.buildVisibility
    return build, legacy ~= nil or needsMigration
end

local function vehicleClass(build)
    local rating = Config.VehicleClass.baseRating
    for category, values in pairs(Config.VehicleClass.points) do
        rating = rating + (values[build[category]] or 0)
    end
    rating = math.floor(rating + 0.5)
    local label = 'D'
    for _, tier in ipairs(Config.VehicleClass.tiers) do
        if rating >= tier.minimum then label = tier.label break end
    end
    return { label = label, rating = rating }
end

local function partRestricted(category, partId, model)
    local restriction = Config.PartRestrictions[category] and Config.PartRestrictions[category][partId]
    if not restriction or type(restriction.unavailableFor) ~= 'table' then return false end
    for _, spawnCode in ipairs(restriction.unavailableFor) do
        if type(spawnCode) == 'string' and joaat(spawnCode) == model then return true end
    end
    return false
end

local function lockedPartsForModel(model)
    local locked = {}
    for category in pairs(Config.PartCategories) do
        locked[category] = {}
        for partId in pairs(Config.Parts[category]) do
            if partRestricted(category, partId, model) then locked[category][partId] = true end
        end
    end
    locked.tireCompound = {}
    for compoundId in pairs(Config.TireCompounds) do
        if partRestricted('tireCompound', compoundId, model) then locked.tireCompound[compoundId] = true end
    end
    return locked
end

local function enforcePartCompatibility(build, model)
    local changed = false
    for category in pairs(Config.PartCategories) do
        if partRestricted(category, build[category], model) then
            build[category] = Config.FactoryBuild[category]
            changed = true
        end
    end
    if partRestricted('tireCompound', build.tireCompound, model) then
        build.tireCompound = Config.FactoryBuild.tireCompound
        changed = true
    end
    return changed
end

local function trustedState(row, build)
    local trustedBuild = copyBuild(build)
    trustedBuilds[row.plate] = trustedBuild
    return {
        plate = row.plate,
        build = trustedBuild,
        factorySeed = row.factory_seed,
        factoryEfficiency = factoryEfficiency(row.factory_seed),
        vehicleClass = vehicleClass(build)
    }
end

local function rateLimited(source, action, interval)
    local now = GetGameTimer()
    local playerCooldowns = requestCooldowns[source] or {}
    requestCooldowns[source] = playerCooldowns
    if now - (playerCooldowns[action] or -interval) < interval then return true end
    playerCooldowns[action] = now
    return false
end

local function applyMmiState(vehicle, plate)
    local placement = TorqueWorksRepository.getMmi(plate)
    Entity(vehicle).state:set('torqueworksMmi', placement or false, true)
    return placement
end

local function sanitizeMmiPlacement(value)
    if type(value) ~= 'table' or type(value.position) ~= 'table' or type(value.rotation) ~= 'table' then return nil end
    local position, rotation = {}, {}
    for _, axis in ipairs({ 'x', 'y', 'z' }) do
        local number = tonumber(value.position[axis])
        local limits = Config.Mmi.positionLimits[axis]
        if not number or not limits then return nil end
        position[axis] = TorqueWorksMath.clamp(number, limits[1], limits[2])
        local angle = tonumber(value.rotation[axis])
        if not angle then return nil end
        rotation[axis] = TorqueWorksMath.clamp(angle, -180.0, 180.0)
    end
    return { position = position, rotation = rotation }
end

RegisterNetEvent('coii_torqueworks:server:turboRelease', function(networkId, claimedTurbo, rpmLevel)
    local source = source
    if rateLimited(source, 'turboRelease', Config.TurboAudio.cooldownMs) then return end
    if type(networkId) ~= 'number' or type(claimedTurbo) ~= 'string' then return end
    local vehicle = driverVehicle(source)
    if vehicle == 0 or NetworkGetNetworkIdFromEntity(vehicle) ~= networkId then return end

    local plate = normalizePlate(GetVehicleNumberPlateText(vehicle))
    if not plate then return end
    local build = trustedBuilds[plate]
    if not build then return end
    local turboId = build.turbo
    local turbo = Config.Parts.turbo[turboId]
    if claimedTurbo:upper() ~= turboId or not turbo or not turbo.wastegateSound then return end

    local origin = GetEntityCoords(vehicle)
    local sourceBucket = GetPlayerRoutingBucket(source)
    local level = TorqueWorksMath.clamp(tonumber(rpmLevel) or 0.0, 0.0, 1.0)
    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        if target and GetPlayerRoutingBucket(target) == sourceBucket then
            local ped = GetPlayerPed(target)
            if ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local dx, dy, dz = coords.x - origin.x, coords.y - origin.y, coords.z - origin.z
                if dx * dx + dy * dy + dz * dz <= Config.TurboAudio.syncDistance ^ 2 then
                    TriggerClientEvent('coii_torqueworks:client:turboRelease', target,
                        networkId, turboId, level)
                end
            end
        end
    end
end)

RegisterNetEvent('coii_torqueworks:server:backfireSound', function(networkId, claimedPump)
    local source = source
    if type(networkId) ~= 'number' or type(claimedPump) ~= 'string' then return end
    local vehicle = driverVehicle(source)
    if vehicle == 0 or NetworkGetNetworkIdFromEntity(vehicle) ~= networkId then return end

    local plate = normalizePlate(GetVehicleNumberPlateText(vehicle))
    local build = plate and trustedBuilds[plate]
    if not build then return end
    local pumpId = build.fuelpump
    local pump = Config.Parts.fuelpump[pumpId]
    if claimedPump:upper() ~= pumpId or not pump or not pump.backfire then return end
    local calibration = build.ecuCalibration
    local popMode = calibration and calibration.customEnabled and
        Config.EcuCalibration.pops[calibration.pops]
    if not popMode or not popMode.enabled then popMode = Config.EcuCalibration.pops.SPORT end
    -- Leave a small allowance for client/server timer and packet jitter. The
    -- authoritative pump still limits how frequently audio may be replicated.
    local syncCooldown = math.max(100,
        (tonumber(pump.cooldownMs) or 400) * (tonumber(popMode.cooldownMultiplier) or 1.0) - 75)
    if rateLimited(source, 'backfireSound', syncCooldown) then return end

    local origin = GetEntityCoords(vehicle)
    local sourceBucket = GetPlayerRoutingBucket(source)
    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        -- The driver plays the sound immediately alongside the local particle;
        -- echo only to other nearby clients to avoid double audio.
        if target and target ~= source and GetPlayerRoutingBucket(target) == sourceBucket then
            local ped = GetPlayerPed(target)
            if ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local dx, dy, dz = coords.x - origin.x, coords.y - origin.y, coords.z - origin.z
                if dx * dx + dy * dy + dz * dz <= Config.TurboAudio.syncDistance ^ 2 then
                    TriggerClientEvent('coii_torqueworks:client:backfireSound', target, networkId)
                end
            end
        end
    end
end)

lib.callback.register('coii_torqueworks:server:getTorqueWorks', function(source, plate, model, networkId)
    if rateLimited(source, 'load', 250) then return nil end
    plate = normalizePlate(plate)
    if not plate or type(model) ~= 'number' or type(networkId) ~= 'number' then return nil end

    local vehicle = driverVehicle(source)
    if vehicle == 0 or NetworkGetNetworkIdFromEntity(vehicle) ~= networkId then return nil end
    if GetEntityModel(vehicle) ~= model then return nil end
    if normalizePlate(GetVehicleNumberPlateText(vehicle)) ~= plate then return nil end
    if not Framework.IsVehicleOwned(plate) then return nil end

    local row = TorqueWorksRepository.getOrCreate(plate, model)
    if not row then return nil end
    local build, migrated = normalizeBuild(row.build)
    local compatibilityChanged = enforcePartCompatibility(build, model)
    if migrated or compatibilityChanged then TorqueWorksRepository.saveBuild(plate, build) end
    applyMmiState(vehicle, plate)
    return trustedState(row, build)
end)

RegisterNetEvent('coii_torqueworks:server:setTransmissionPersonality', function(requestedPersonality, plate, networkId)
    local source = source
    if not hasMechanicAccess(source) or rateLimited(source, 'transmissionPersonality', 350) then return end
    local personality = type(requestedPersonality) == 'string' and requestedPersonality:upper() or nil
    if not personality or not Config.TransmissionPersonalities[personality] then return end
    if Config.Billing.enabled then return end
    local vehicle, normalized = validatedDrivenVehicle(source, plate, networkId)
    if vehicle == 0 then return end
    local row = TorqueWorksRepository.getOrCreate(normalized, GetEntityModel(vehicle))
    if not row then return end
    local build = normalizeBuild(row.build)
    build.transmissionPersonality = personality
    if not TorqueWorksRepository.saveBuild(normalized, build) then return end
    TriggerClientEvent('coii_torqueworks:client:buildCardChanged', -1, normalized)
    TriggerClientEvent('coii_torqueworks:client:buildApplied', source, trustedState(row, build), networkId)
end)

RegisterNetEvent('coii_torqueworks:server:setPart', function(requestedCategory, requestedPart, plate, networkId)
    local source = source
    if not hasMechanicAccess(source) then return end
    if rateLimited(source, 'part', 500) then return end

    local category = type(requestedCategory) == 'string' and requestedCategory:lower() or nil
    local partId = type(requestedPart) == 'string' and requestedPart:upper() or nil
    plate = normalizePlate(plate)
    if not category or not Config.PartCategories[category] or
        not partId or not Config.Parts[category][partId] or
        not plate or type(networkId) ~= 'number' then return end

    local vehicle, normalized = validatedDrivenVehicle(source, plate, networkId)
    if vehicle == 0 then return end
    plate = normalized

    local row = TorqueWorksRepository.getOrCreate(plate, GetEntityModel(vehicle))
    if not row then return end
    local build = normalizeBuild(row.build)
    if partRestricted(category, partId, GetEntityModel(vehicle)) then
        Config.Integrations.serverNotification(source, {
            type = 'error', description = 'This part is not compatible with this vehicle.'
        })
        return
    end
    if build[category] == partId then return end
    local factoryPart = Config.FactoryBuild[category]
    if Config.Billing.enabled and partId ~= factoryPart then return end
    local requirements = partId ~= factoryPart and installationRequirements(category, partId) or {}
    local requiresConsumable = Config.Installation.consumable.enabled and
        #requirements > 0 and not installationBypass(source)
    local xPlayer
    if requiresConsumable then
        xPlayer = Framework.GetPlayerFromId(source)
        for _, requirement in ipairs(requirements) do
            local inventoryItem = xPlayer and xPlayer.getInventoryItem(requirement.item)
            if not inventoryItem or (tonumber(inventoryItem.count) or 0) < requirement.amount then
                Config.Integrations.serverNotification(source, {
                    type = 'error',
                    description = "You don't have enough parts."
                })
                return
            end
        end
    end
    build[category] = partId
    if category == 'nitro' then build.nitroLevel = 0.0 end
    if category == 'differential' and partId ~= 'ACTIVE' then build.frontTorqueBias = -1.0 end
    if not TorqueWorksRepository.saveBuild(plate, build) then return end
    if requiresConsumable then
        for _, requirement in ipairs(requirements) do
            xPlayer.removeInventoryItem(requirement.item, requirement.amount)
        end
    end
    TriggerClientEvent('coii_torqueworks:client:buildCardChanged', -1, plate)
    TriggerClientEvent('coii_torqueworks:client:buildApplied', source, trustedState(row, build), networkId)
end)

RegisterNetEvent('coii_torqueworks:server:setBuildName', function(requestedName, plate, networkId)
    local source = source
    if not hasMechanicAccess(source) or rateLimited(source, 'buildName', 500) then return end
    local vehicle, normalized = validatedDrivenVehicle(source, plate, networkId)
    if vehicle == 0 then return end
    local row = TorqueWorksRepository.getOrCreate(normalized, GetEntityModel(vehicle))
    if not row then return end
    local build = normalizeBuild(row.build)
    build.buildName = normalizeBuildName(requestedName)
    if not TorqueWorksRepository.saveBuild(normalized, build) then return end
    TriggerClientEvent('coii_torqueworks:client:buildCardChanged', -1, normalized)
    TriggerClientEvent('coii_torqueworks:client:buildApplied', source, trustedState(row, build), networkId)
end)

RegisterNetEvent('coii_torqueworks:server:resetBuild', function(plate, networkId)
    local source = source
    if not hasMechanicAccess(source) then return end
    if rateLimited(source, 'part', 500) then return end
    plate = normalizePlate(plate)
    if not plate or type(networkId) ~= 'number' then return end

    local vehicle, normalized = validatedDrivenVehicle(source, plate, networkId)
    if vehicle == 0 then return end
    plate = normalized

    local row = TorqueWorksRepository.getOrCreate(plate, GetEntityModel(vehicle))
    local previous = row and normalizeBuild(row.build) or copyBuild(Config.FactoryBuild)
    local build = copyBuild(Config.FactoryBuild)
    build.buildVisibility = previous.buildVisibility
    if not row or not TorqueWorksRepository.saveBuild(plate, build) then return end
    TriggerClientEvent('coii_torqueworks:client:buildCardChanged', -1, plate)
    TriggerClientEvent('coii_torqueworks:client:buildApplied', source, trustedState(row, build), networkId)
end)

local function nearbyVehicle(source, plate, networkId)
    plate = normalizePlate(plate)
    if not plate or type(networkId) ~= 'number' then return 0, nil end
    local vehicle = NetworkGetEntityFromNetworkId(networkId)
    local ped = GetPlayerPed(source)
    if vehicle == 0 or ped == 0 or not DoesEntityExist(vehicle) then return 0, nil end
    if GetEntityType(vehicle) ~= 2 or normalizePlate(GetVehicleNumberPlateText(vehicle)) ~= plate then return 0, nil end
    local playerCoords, vehicleCoords = GetEntityCoords(ped), GetEntityCoords(vehicle)
    if #(playerCoords - vehicleCoords) > (Config.BuildCard.validationDistance + 2.0) then return 0, nil end
    return vehicle, plate
end

local function vehicleOwner(source, plate)
    local owner = Framework.GetVehicleOwnerIdentifier(plate)
    local xPlayer = Framework.GetPlayerFromId(source)
    local identifier = xPlayer and (xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier)
    return owner ~= nil and identifier ~= nil and owner == identifier
end

local function bestAcceleration(history, fromSpeed, toSpeed)
    local best
    for _, run in ipairs(history) do
        local started
        for _, sample in ipairs(run.samples or {}) do
            local speed = tonumber(sample.speed)
            if not started and speed and speed >= fromSpeed then started = tonumber(sample.time) end
            if started and speed and speed >= toSpeed then
                local seconds = ((tonumber(sample.time) or started) - started) / 1000.0
                if seconds > 0 and (not best or seconds < best) then best = seconds end
                break
            end
        end
    end
    return best
end

local function buildCardPayload(source, row, build)
    local history = TorqueWorksRepository.getDynoHistory(row.plate, Config.BuildCard.historyLimit)
    local latest = history[1]
    local isOwner = vehicleOwner(source, row.plate)
    local visibility = build.buildVisibility
    if visibility == 'PRIVATE' and not isOwner then
        return { private = true, visibility = visibility, isOwner = false }
    end
    local payload = {
        plate = row.plate, model = tonumber(row.model) or row.model, buildName = build.buildName,
        visibility = visibility, isOwner = isOwner, vehicleClass = vehicleClass(build),
        performance = {
            whp = latest and tonumber(latest.peak_power) or nil,
            torque = latest and tonumber(latest.peak_torque) or nil,
            best100to200 = bestAcceleration(history, 100.0, 200.0)
        }
    }
    if visibility == 'PUBLIC' or isOwner then
        payload.parts = {
            turbo = ('%s / %s spool'):format(Config.Parts.turbo[build.turbo].label,
                build.turbo == 'SMALL' and 'Quick' or build.turbo == 'MEDIUM' and 'Medium' or
                build.turbo == 'LARGE' and 'Slow' or 'None'),
            engine = Config.Parts.engine[build.engine].label,
            nitro = Config.Parts.nitro[build.nitro].label,
            transmission = Config.Parts.transmission[build.transmission].label,
            differential = Config.Parts.differential[build.differential].label,
            brakes = Config.Parts.brakes[build.brakes].label,
            suspension = Config.Parts.suspension[build.suspension].label,
            tires = Config.TireCompounds[build.tireCompound].label,
            ecuMap = Config.EcuMaps[build.ecuMap].label
        }
    end
    return payload
end

lib.callback.register('coii_torqueworks:server:getBuildCard', function(source, plate, networkId)
    if rateLimited(source, 'buildCard', 500) then return nil end
    local vehicle, normalized = nearbyVehicle(source, plate, networkId)
    if vehicle == 0 then return nil end
    if not Framework.IsVehicleOwned(normalized) then return { unavailable = true } end
    local row = TorqueWorksRepository.get(normalized)
    if not row then return { unavailable = true } end
    local build, migrated = normalizeBuild(row.build)
    local compatibilityChanged = enforcePartCompatibility(build, GetEntityModel(vehicle))
    if migrated or compatibilityChanged then TorqueWorksRepository.saveBuild(normalized, build) end
    return buildCardPayload(source, row, build)
end)

lib.callback.register('coii_torqueworks:server:setBuildCardVisibility', function(source, plate, networkId, requested)
    if rateLimited(source, 'buildCardVisibility', 500) then return nil end
    local visibility = type(requested) == 'string' and requested:upper() or nil
    if not ({ PUBLIC = true, PERFORMANCE = true, PRIVATE = true })[visibility] then return nil end
    local vehicle, normalized = nearbyVehicle(source, plate, networkId)
    if vehicle == 0 or not vehicleOwner(source, normalized) then return nil end
    local row = TorqueWorksRepository.get(normalized)
    if not row then return nil end
    local build = normalizeBuild(row.build)
    build.buildVisibility = visibility
    if not TorqueWorksRepository.saveBuild(normalized, build) then return nil end
    TriggerClientEvent('coii_torqueworks:client:buildCardChanged', -1, normalized)
    return buildCardPayload(source, row, build)
end)

RegisterNetEvent('coii_torqueworks:server:setEcuMap', function(requestedMap, plate, networkId)
    local source = source
    if not hasMechanicAccess(source) then return end
    if rateLimited(source, 'map', 350) then return end
    local mapId = math.floor(tonumber(requestedMap) or 0)
    plate = normalizePlate(plate)
    if not Config.EcuMaps[mapId] or not plate or type(networkId) ~= 'number' then return end

    local vehicle, normalized = validatedDrivenVehicle(source, plate, networkId)
    if vehicle == 0 then return end
    plate = normalized

    local row = TorqueWorksRepository.getOrCreate(plate, GetEntityModel(vehicle))
    if not row then return end
    local build = normalizeBuild(row.build)
    build.ecuMap = mapId
    build.ecuCalibration.customEnabled = false
    if not TorqueWorksRepository.saveBuild(plate, build) then return end
    TriggerClientEvent('coii_torqueworks:client:buildCardChanged', -1, plate)
    TriggerClientEvent('coii_torqueworks:client:buildApplied', source, trustedState(row, build), networkId)
end)

RegisterNetEvent('coii_torqueworks:server:setEcuCalibration', function(requested, plate, networkId)
    local source = source
    if not hasMechanicAccess(source) or rateLimited(source, 'ecuCalibration', 350) then return end
    if type(requested) ~= 'table' then return end
    local vehicle, normalized = validatedDrivenVehicle(source, plate, networkId)
    if vehicle == 0 then return end
    local row = TorqueWorksRepository.getOrCreate(normalized, GetEntityModel(vehicle))
    if not row then return end
    local build = normalizeBuild(row.build)
    build.ecuCalibration = normalizeEcuCalibration(requested)
    if not TorqueWorksRepository.saveBuild(normalized, build) then return end
    TriggerClientEvent('coii_torqueworks:client:buildCardChanged', -1, normalized)
    TriggerClientEvent('coii_torqueworks:client:buildApplied', source,
        trustedState(row, build), NetworkGetNetworkIdFromEntity(vehicle), true)
end)

RegisterNetEvent('coii_torqueworks:server:setChassisSetting', function(requestedSetting, requestedValue, plate, networkId)
    local source = source
    if not hasMechanicAccess(source) then return end
    if rateLimited(source, 'chassis', 350) then return end
    local setting = type(requestedSetting) == 'string' and requestedSetting:lower() or nil
    plate = normalizePlate(plate)
    if not setting or not plate or type(networkId) ~= 'number' then return end

    local trustedValue
    if setting == 'compound' then
        if Config.Billing.enabled then return end
        local compound = type(requestedValue) == 'string' and requestedValue:upper() or nil
        if not compound or not Config.TireCompounds[compound] then return end
        trustedValue = compound
    elseif setting == 'pressure' then
        local pressure = tonumber(requestedValue)
        if not pressure or pressure < Config.TirePressure.minimum or pressure > Config.TirePressure.maximum then return end
        trustedValue = math.floor((pressure / Config.TirePressure.increment) + 0.5) * Config.TirePressure.increment
    elseif setting == 'split' then
        if requestedValue == 'FACTORY' then
            trustedValue = -1.0
        else
            local percentage = tonumber(requestedValue)
            if not percentage or percentage < 0.0 or percentage > 100.0 then return end
            trustedValue = math.floor(percentage / 5.0 + 0.5) / 20.0
        end
    else
        return
    end

    local vehicle, normalized = validatedDrivenVehicle(source, plate, networkId)
    if vehicle == 0 then return end
    plate = normalized
    if setting == 'compound' and partRestricted('tireCompound', trustedValue, GetEntityModel(vehicle)) then
        Config.Integrations.serverNotification(source, {
            type = 'error', description = 'This tire compound is not compatible with this vehicle.'
        })
        return
    end
    local row = TorqueWorksRepository.getOrCreate(plate, GetEntityModel(vehicle))
    if not row then return end
    local build = normalizeBuild(row.build)
    if setting == 'split' and build.differential ~= 'ACTIVE' then
        Config.Integrations.serverNotification(source, {
            type = 'error', description = 'Front torque bias requires an Active differential.'
        })
        return
    end
    if setting == 'compound' then build.tireCompound = trustedValue end
    if setting == 'pressure' then build.tirePressure = trustedValue end
    if setting == 'split' then build.frontTorqueBias = trustedValue end
    if not TorqueWorksRepository.saveBuild(plate, build) then return end
    TriggerClientEvent('coii_torqueworks:client:buildCardChanged', -1, plate)
    TriggerClientEvent('coii_torqueworks:client:buildApplied', source, trustedState(row, build), networkId)
end)

lib.callback.register('coii_torqueworks:server:getMechanicData', function(source, plate, networkId, workshopId)
    local workshop = workshopById(workshopId)
    if not workshop or not hasMechanicAccess(source, workshopId) then return { authorized = false } end
    if not isAtWorkshopLocation(source, workshopId, 'tuning') then
        return { authorized = true, error = 'Drive into the mechanic terminal to open TorqueWorks.' }
    end
    local vehicle, normalized, validationError = validatedDrivenVehicle(source, plate, networkId)
    if vehicle == 0 then return { authorized = true, error = validationError == 'not_owned' and
        'Only player-owned vehicles can be tuned.' or 'You must be driving the target vehicle.' } end
    if not isSupportedCar(vehicle) then
        return { authorized = true, error = 'The mechanic terminal is only available for cars.' }
    end
    local row = TorqueWorksRepository.getOrCreate(normalized, GetEntityModel(vehicle))
    if not row then return { authorized = true, error = 'TorqueWorks could not be loaded.' } end
    local build, migrated = normalizeBuild(row.build)
    local compatibilityChanged = enforcePartCompatibility(build, GetEntityModel(vehicle))
    if migrated or compatibilityChanged then TorqueWorksRepository.saveBuild(normalized, build) end
    return {
        authorized = true,
        workshop = { id = workshopId, name = workshop.name or workshopId },
        state = trustedState(row, build),
        history = TorqueWorksRepository.getDynoHistory(normalized, 10),
        lockedParts = lockedPartsForModel(GetEntityModel(vehicle)),
        installationBypass = installationBypass(source),
        installation = installationCatalog(),
        workOrder = TorqueWorksRepository.getApprovedWorkOrderForPlate(normalized)
    }
end)

lib.callback.register('coii_torqueworks:server:canUseWorkshopDyno', function(source, workshopId)
    local workshop = workshopById(workshopId)
    if not workshop or not hasMechanicAccess(source, workshopId) then
        return { ok = false, error = 'You do not have access to this workshop dyno.' }
    end
    if not isAtWorkshopLocation(source, workshopId, 'dyno') then
        return { ok = false, error = 'Drive onto this workshop dyno first.' }
    end
    return { ok = true, name = workshop.name or workshopId }
end)

RegisterNetEvent('coii_torqueworks:server:resetEcu', function(plate, networkId)
    local source = source
    if not hasMechanicAccess(source) or rateLimited(source, 'part', 350) then return end
    local vehicle, normalized = validatedDrivenVehicle(source, plate, networkId)
    if vehicle == 0 then return end
    local row = TorqueWorksRepository.getOrCreate(normalized, GetEntityModel(vehicle))
    if not row then return end
    local build = normalizeBuild(row.build)
    build.ecu = Config.FactoryBuild.ecu
    build.ecuMap = Config.FactoryBuild.ecuMap
    build.ecuCalibration = normalizeEcuCalibration(Config.FactoryBuild.ecuCalibration)
    if not TorqueWorksRepository.saveBuild(normalized, build) then return end
    TriggerClientEvent('coii_torqueworks:client:buildCardChanged', -1, normalized)
    TriggerClientEvent('coii_torqueworks:client:buildApplied', source, trustedState(row, build), networkId)
end)

local function sanitizeDynoSamples(samples)
    if type(samples) ~= 'table' or #samples < 2 or #samples > Config.Dyno.maxSamples then return nil end
    local clean = {}
    for index, sample in ipairs(samples) do
        if type(sample) ~= 'table' then return nil end
        local rpm, power, torque = tonumber(sample.rpm), tonumber(sample.power), tonumber(sample.torque)
        local boost, speed = tonumber(sample.boost), tonumber(sample.speed)
        if not rpm or not power or not torque or not boost or not speed or
            rpm < 0 or rpm > 15000 or power < 0 or power > 3000 or
            torque < 0 or torque > 5000 or boost < 0 or boost > 2 or speed < 0 or speed > 600 then return nil end
        clean[index] = {
            time = tonumber(sample.time) or 0,
            rpmNormalized = TorqueWorksMath.clamp(tonumber(sample.rpmNormalized) or 0, 0, 1),
            rpm = rpm, power = power, torque = torque, boost = boost, speed = speed,
            gear = math.floor(tonumber(sample.gear) or 0)
        }
    end
    return clean
end

RegisterNetEvent('coii_torqueworks:server:saveDynoRun', function(plate, networkId, result)
    local source = source
    if not hasMechanicAccess(source) or rateLimited(source, 'dynoSave', 5000) or
        type(result) ~= 'table' then return end
    local vehicle, normalized = validatedDrivenVehicle(source, plate, networkId)
    if vehicle == 0 then return end
    local samples = sanitizeDynoSamples(result.samples)
    if not samples then return end
    local peakPower, peakTorque = 0.0, 0.0
    for _, sample in ipairs(samples) do
        peakPower = math.max(peakPower, sample.power)
        peakTorque = math.max(peakTorque, sample.torque)
    end
    local row = TorqueWorksRepository.getOrCreate(normalized, GetEntityModel(vehicle))
    if not row then return end
    local build = normalizeBuild(row.build)
    TorqueWorksRepository.saveDynoRun(normalized, build, peakPower, peakTorque, samples)
end)

local function scheduleNitroAutoRefill(playerId, plate)
    if nitroAutoRefillEnabled[playerId] == false then return end
    local token = (nitroAutoRefillTokens[playerId] or 0) + 1
    nitroAutoRefillTokens[playerId] = token
    SetTimeout(Config.Nitro.reuseDelayMs + Config.Nitro.autoRefillDelayMs, function()
        if nitroAutoRefillTokens[playerId] ~= token or nitroSessions[playerId] or
            nitroAutoRefillEnabled[playerId] == false then return end
        local xPlayer = Framework.GetPlayerFromId(playerId)
        if not xPlayer then return end
        local item = xPlayer.getInventoryItem(Config.Nitro.refillItem)
        if not item or (tonumber(item.count) or 0) < 1 then return end
        local row = TorqueWorksRepository.get(plate)
        if not row then return end
        local build = normalizeBuild(row.build)
        local system = Config.Parts.nitro[build.nitro]
        if not system or not system.enabled or build.nitroLevel >= 0.999 then return end
        local vehicle = driverVehicle(playerId)
        if vehicle == 0 or normalizePlate(GetVehicleNumberPlateText(vehicle)) ~= plate then return end
        TriggerClientEvent('coii_torqueworks:client:beginNitroRefill', playerId, {
            automatic = true, plate = plate
        })
    end)
end

local function finishNitroSession(playerId)
    local session = nitroSessions[playerId]
    if not session then return end
    nitroSessions[playerId] = nil
    for _, recipient in ipairs(session.trailRecipients or {}) do
        TriggerClientEvent('coii_torqueworks:client:nitroTrailSync', recipient,
            session.networkId, false)
    end
    nitroReuseAt[playerId] = GetGameTimer() + Config.Nitro.reuseDelayMs
    local row = TorqueWorksRepository.get(session.plate)
    if not row then return end
    local build = normalizeBuild(row.build)
    local elapsed = math.max(0, GetGameTimer() - session.startedAt)
    build.nitroLevel = TorqueWorksMath.clamp(session.initialLevel - elapsed / session.fullDurationMs, 0.0, 1.0)
    if not TorqueWorksRepository.saveBuild(session.plate, build) then return end
    TriggerClientEvent('coii_torqueworks:client:nitroLevel', playerId, build.nitroLevel)
    TriggerClientEvent('coii_torqueworks:client:buildCardChanged', -1, session.plate)
    if build.nitroLevel < 0.999 then scheduleNitroAutoRefill(playerId, session.plate) end
end

lib.callback.register('coii_torqueworks:server:startNitro', function(source, plate, networkId)
    finishNitroSession(source)
    if GetGameTimer() < (nitroReuseAt[source] or 0) then return -1 end
    local vehicle, normalized = validatedDrivenVehicle(source, plate, networkId)
    if vehicle == 0 then return nil end
    local row = TorqueWorksRepository.getOrCreate(normalized, GetEntityModel(vehicle))
    if not row then return nil end
    local build = normalizeBuild(row.build)
    local system = Config.Parts.nitro[build.nitro]
    if not system or not system.enabled then return nil end
    if build.nitroLevel <= 0.001 then return 0 end
    nitroSessions[source] = {
        plate = normalized, startedAt = GetGameTimer(), initialLevel = build.nitroLevel,
        fullDurationMs = math.max(1, system.durationMs), networkId = networkId,
        trailRecipients = {}
    }
    local vehicleCoords = GetEntityCoords(vehicle)
    for _, playerId in ipairs(GetPlayers()) do
        local recipient = tonumber(playerId)
        if recipient and recipient ~= source then
            local ped = GetPlayerPed(recipient)
            if ped ~= 0 and #(GetEntityCoords(ped) - vehicleCoords) <= Config.Nitro.trailSyncDistance then
                nitroSessions[source].trailRecipients[#nitroSessions[source].trailRecipients + 1] = recipient
                TriggerClientEvent('coii_torqueworks:client:nitroTrailSync', recipient,
                    networkId, true, Config.Nitro.taillightTrailColor)
            end
        end
    end
    return build.nitroLevel
end)

RegisterNetEvent('coii_torqueworks:server:stopNitro', function()
    finishNitroSession(source)
end)

RegisterNetEvent('coii_torqueworks:server:cancelAutoRefill', function()
    local playerId = source
    nitroAutoRefillTokens[playerId] = (nitroAutoRefillTokens[playerId] or 0) + 1
end)

RegisterNetEvent('coii_torqueworks:server:setAutoRefillPreference', function(enabled)
    local playerId = source
    nitroAutoRefillEnabled[playerId] = enabled == true
    if not nitroAutoRefillEnabled[playerId] then
        nitroAutoRefillTokens[playerId] = (nitroAutoRefillTokens[playerId] or 0) + 1
    end
end)

Framework.RegisterUsableItem(Config.Nitro.refillItem, function(source)
    TriggerClientEvent('coii_torqueworks:client:beginNitroRefill', source)
end)

Framework.RegisterUsableItem(Config.Mmi.item, function(source)
    if not hasMechanicAccess(source) then
        Config.Integrations.serverNotification(source, {
            type = 'error', description = 'You do not have access to install an MMI controller.'
        })
        return
    end
    local vehicle = driverVehicle(source)
    if vehicle == 0 then
        Config.Integrations.serverNotification(source, {
            type = 'error', description = 'Sit in the driver seat of a car to install the MMI controller.'
        })
        return
    end
    if not isSupportedCar(vehicle) then
        Config.Integrations.serverNotification(source, {
            type = 'error', description = 'An MMI controller can only be installed in a car.'
        })
        return
    end
    TriggerClientEvent('coii_torqueworks:client:beginMmiPlacement', source)
end)

lib.callback.register('coii_torqueworks:server:installMmi', function(source, plate, networkId, requestedPlacement)
    if not hasMechanicAccess(source) or rateLimited(source, 'mmiInstall', 1000) then
        return { ok = false, error = 'MMI installation request denied.' }
    end
    local vehicle, normalized, validationError = validatedDrivenVehicle(source, plate, networkId)
    if vehicle == 0 then return { ok = false, error = validationError == 'not_owned' and
        'Only player-owned vehicles can receive an MMI controller.' or 'You must remain in the driver seat.' } end
    if not isSupportedCar(vehicle) then
        return { ok = false, error = 'An MMI controller can only be installed in a car.' }
    end
    local placement = sanitizeMmiPlacement(requestedPlacement)
    if not placement then return { ok = false, error = 'Invalid tablet placement.' } end
    if TorqueWorksRepository.getMmi(normalized) then
        return { ok = false, error = 'This vehicle already has an MMI controller installed.' }
    end
    local xPlayer = Framework.GetPlayerFromId(source)
    local item = xPlayer and xPlayer.getInventoryItem(Config.Mmi.item)
    if not item or (tonumber(item.count) or 0) < 1 then
        return { ok = false, error = 'The MMI item is no longer available.' }
    end
    if not TorqueWorksRepository.saveMmi(normalized, placement) then
        return { ok = false, error = 'The MMI placement could not be saved.' }
    end
    xPlayer.removeInventoryItem(Config.Mmi.item, 1)
    Entity(vehicle).state:set('torqueworksMmi', placement, true)
    return { ok = true }
end)

RegisterNetEvent('coii_torqueworks:server:setMmiSetting', function(requestedSetting, requestedValue, plate, networkId)
    local source = source
    if rateLimited(source, 'mmiSetting', 250) then return end
    local vehicle, normalized = validatedDrivenVehicle(source, plate, networkId)
    if vehicle == 0 or not TorqueWorksRepository.getMmi(normalized) then return end
    local row = TorqueWorksRepository.getOrCreate(normalized, GetEntityModel(vehicle))
    if not row then return end
    local build = normalizeBuild(row.build)
    local setting = type(requestedSetting) == 'string' and requestedSetting or ''

    if setting == 'ecuMap' then
        local mapId = math.floor(tonumber(requestedValue) or 0)
        if not Config.EcuMaps[mapId] then return end
        build.ecuMap = mapId
    elseif setting == 'transmission' then
        local personality = type(requestedValue) == 'string' and requestedValue:upper() or nil
        if not personality or not Config.TransmissionPersonalities[personality] then return end
        build.transmissionPersonality = personality
    elseif setting == 'pressure' then
        local pressure = tonumber(requestedValue)
        if not pressure or pressure < Config.TirePressure.minimum or pressure > Config.TirePressure.maximum then return end
        build.tirePressure = math.floor(pressure / Config.TirePressure.increment + 0.5) * Config.TirePressure.increment
    elseif setting == 'split' then
        if build.differential ~= 'ACTIVE' then return end
        if requestedValue == 'FACTORY' then
            build.frontTorqueBias = -1.0
        else
            local percentage = tonumber(requestedValue)
            if not percentage or percentage < 0.0 or percentage > 100.0 then return end
            build.frontTorqueBias = math.floor(percentage / 5.0 + 0.5) / 20.0
        end
    else
        return
    end

    if not TorqueWorksRepository.saveBuild(normalized, build) then return end
    TriggerClientEvent('coii_torqueworks:client:buildCardChanged', -1, normalized)
    TriggerClientEvent('coii_torqueworks:client:buildApplied', source,
        trustedState(row, build), NetworkGetNetworkIdFromEntity(vehicle), true)
end)

RegisterNetEvent('coii_torqueworks:server:refillNitro', function(plate, networkId, automatic)
    local source = source
    if rateLimited(source, 'nitroRefill', Config.Nitro.refillDurationMs - 250) then return end
    if nitroSessions[source] then
        Config.Integrations.serverNotification(source, { type = 'error', description = 'Stop nitrous before replacing the bottle.' })
        return
    end
    local vehicle, normalized = validatedDrivenVehicle(source, plate, networkId)
    if vehicle == 0 then
        Config.Integrations.serverNotification(source, { type = 'error', description = 'You must be driving the vehicle you want to refill.' })
        return
    end
    local row = TorqueWorksRepository.getOrCreate(normalized, GetEntityModel(vehicle))
    if not row then return end
    local build = normalizeBuild(row.build)
    local system = Config.Parts.nitro[build.nitro]
    if not system or not system.enabled then
        Config.Integrations.serverNotification(source, { type = 'error', description = 'This vehicle has no nitrous system installed.' })
        return
    end
    if build.nitroLevel >= 0.999 then
        Config.Integrations.serverNotification(source, { type = 'inform', description = 'The nitrous bottle is already full.' })
        return
    end
    local xPlayer = Framework.GetPlayerFromId(source)
    local item = xPlayer and xPlayer.getInventoryItem(Config.Nitro.refillItem)
    if not item or (tonumber(item.count) or 0) < 1 then
        Config.Integrations.serverNotification(source, { type = 'error', description = 'You do not have a nitrous bottle.' })
        return
    end
    build.nitroLevel = 1.0
    if not TorqueWorksRepository.saveBuild(normalized, build) then return end
    nitroAutoRefillTokens[source] = (nitroAutoRefillTokens[source] or 0) + 1
    xPlayer.removeInventoryItem(Config.Nitro.refillItem, 1)
    -- A refill only changes consumable state. Refresh the server-owned cache without
    -- reapplying the entire build client-side, which would restart custom engine audio.
    trustedState(row, build)
    TriggerClientEvent('coii_torqueworks:client:buildCardChanged', -1, normalized)
    TriggerClientEvent('coii_torqueworks:client:nitroLevel', source, 1.0)
    Config.Integrations.serverNotification(source, {
        type = 'success',
        description = automatic == true and 'Nitrous bottle automatically refilled.' or 'Nitrous bottle refilled.'
    })
end)

RegisterNetEvent('coii_torqueworks:server:createMechanicQuote', function(customerId, plate, networkId, workshopId, requestedLines)
    local source = source
    local workshop = workshopById(workshopId)
    if Config.Billing.enabled ~= true or not workshop or not hasMechanicAccess(source, workshopId) or
        not isAtWorkshopLocation(source, workshopId, 'tuning') or
        rateLimited(source, 'createMechanicQuote', 1500) then return end
    customerId = math.floor(tonumber(customerId) or 0)
    if customerId <= 0 or not GetPlayerName(customerId) or type(requestedLines) ~= 'table' then
        Config.Integrations.serverNotification(source, { type = 'error', description = 'Select a nearby customer first.' })
        return
    end
    local vehicle, normalized = validatedDrivenVehicle(source, plate, networkId)
    if vehicle == 0 then return end
    local customerPed, mechanicPed = GetPlayerPed(customerId), GetPlayerPed(source)
    if customerPed == 0 or mechanicPed == 0 or
        #(GetEntityCoords(customerPed) - GetEntityCoords(mechanicPed)) > (Config.Billing.customerDistance or 8.0) then
        Config.Integrations.serverNotification(source, { type = 'error', description = 'The customer is not nearby.' })
        return
    end
    local row = TorqueWorksRepository.getOrCreate(normalized, GetEntityModel(vehicle))
    if not row then return end
    if TorqueWorksRepository.getApprovedWorkOrderForPlate(normalized) then
        Config.Integrations.serverNotification(source, {
            type = 'error', description = 'This vehicle already has an approved work order.'
        })
        return
    end
    local currentBuild = normalizeBuild(row.build)
    local estimatedBuild = copyBuild(currentBuild)
    local lines, seen, partsTotal = {}, {}, 0
    for _, request in ipairs(requestedLines) do
        local category = type(request) == 'table' and type(request.category) == 'string' and request.category:lower() or nil
        local partId = type(request) == 'table' and type(request.partId) == 'string' and request.partId:upper() or nil
        local part, priceGroup, restrictionCategory = nil, category, category
        if category == 'tirecompound' then
            category, priceGroup, restrictionCategory = 'tireCompound', 'compounds', 'tireCompound'
            part = Config.TireCompounds[partId]
        elseif category == 'transmissionpersonality' then
            category, priceGroup, restrictionCategory = 'transmissionPersonality', 'transmissionPersonalities', nil
            part = Config.TransmissionPersonalities[partId]
        elseif category and Config.PartCategories[category] then
            part = Config.Parts[category] and Config.Parts[category][partId]
        end
        local restricted = restrictionCategory and partRestricted(restrictionCategory, partId, GetEntityModel(vehicle)) or false
        if part and not seen[category] and currentBuild[category] ~= partId and not restricted then
            local price = math.max(0, math.floor(tonumber(Config.DisplayPrices[priceGroup] and
                Config.DisplayPrices[priceGroup][partId]) or 0))
            local requirements = partId ~= Config.FactoryBuild[category] and installationRequirements(category, partId) or {}
            lines[#lines + 1] = {
                category = category, partId = partId, label = part.label or partId,
                categoryLabel = category == 'fuelpump' and 'FUEL PUMP' or category:upper(),
                price = price, requirements = requirements, completed = false
            }
            seen[category], estimatedBuild[category] = true, partId
            partsTotal = partsTotal + price
        end
    end
    if #lines == 0 then
        Config.Integrations.serverNotification(source, { type = 'error', description = 'The quote has no valid parts.' })
        return
    end
    local labor = math.max(0, math.floor(tonumber(Config.Billing.laborPerPart) or 0)) * #lines
    local total = partsTotal + labor
    if total > (Config.Billing.maximumQuote or 250000) then
        Config.Integrations.serverNotification(source, { type = 'error', description = 'The quote exceeds the configured maximum.' })
        return
    end
    local mechanic, customer = Framework.GetPlayerFromId(source), Framework.GetPlayerFromId(customerId)
    local mechanicIdentifier, customerIdentifier = playerIdentifier(mechanic), playerIdentifier(customer)
    if not mechanicIdentifier or not customerIdentifier then return end
    local token = ('q:%d:%d:%d:%d'):format(source, customerId, os.time(), math.random(100000, 999999))
    local mechanicName = roleplayName(mechanic, source)
    local quote = {
        test = false, baseBuild = copyBuild(currentBuild), lines = lines, partsTotal = partsTotal, labor = labor, total = total,
        networkId = networkId,
        workshopId = workshopId, workshopName = workshop.name or workshopId,
        mechanicName = mechanicName, currentClass = vehicleClass(currentBuild),
        estimatedClass = vehicleClass(estimatedBuild)
    }
    local orderId = TorqueWorksRepository.createWorkOrder({
        plate = normalized, mechanicIdentifier = mechanicIdentifier,
        customerIdentifier = customerIdentifier, quote = quote, total = total,
        simulated = false, token = token,
        timeoutMinutes = math.max(1, math.floor(Config.Billing.approvalTimeoutMinutes or 10))
    })
    if not orderId then return end
    local partLabels = {}
    for _, line in ipairs(lines) do
        partLabels[#partLabels + 1] = ('%s: %s ($%d)'):format(
            line.categoryLabel or line.category, line.label or line.partId, line.price or 0)
    end
    TorqueWorksLogs.audit('quoteCreated', {
        title = 'Workshop quote created', level = 'info', actorLabel = 'Mechanic',
        actorSource = source, actorIdentifier = mechanicIdentifier,
        customerSource = customerId, customerIdentifier = customerIdentifier,
        workshop = workshop.name or workshopId, plate = normalized, orderId = orderId,
        amount = total, transactionMode = 'PENDING', parts = table.concat(partLabels, '\n')
    })
    local accounts = {}
    for _, method in ipairs({ 'cash', 'bank' }) do
        local account = Config.Billing.paymentAccounts[method]
        if account and account.enabled == true then accounts[#accounts + 1] = { value = method, label = account.label or method } end
    end
    TriggerClientEvent('coii_torqueworks:client:customerQuote', customerId, {
        id = orderId, token = token, plate = normalized, total = total,
        selfQuote = customerId == source,
        mechanicName = mechanicName, quote = quote, accounts = accounts
    })
    Config.Integrations.serverNotification(source, {
        type = 'inform',
        description = customerId == source and 'Your personal build estimate is ready.' or
            'Quote sent to the nearby customer.'
    })
end)

local function prepareQuotedBuild(order, mechanicSource, customerSource)
    local quote = order.quote
    local mechanic = Framework.GetPlayerFromId(mechanicSource)
    if not mechanic or not hasMechanicAccess(mechanicSource, quote.workshopId) or
        not workshopById(quote.workshopId) or not isAtWorkshopLocation(mechanicSource, quote.workshopId, 'tuning') then
        error('The mechanic must be at the quoted workshop.', 0)
    end
    local vehicle = validatedInstallationVehicle(mechanicSource, order.plate, quote.networkId, true)
    if vehicle == 0 or not isSupportedCar(vehicle) then
        error('The player-owned vehicle must be near the mechanic.', 0)
    end
    local customerPed, mechanicPed = GetPlayerPed(customerSource), GetPlayerPed(mechanicSource)
    if customerPed == 0 or mechanicPed == 0 or
        #(GetEntityCoords(customerPed) - GetEntityCoords(mechanicPed)) > (Config.Billing.customerDistance or 8.0) then
        error('The customer must stay near the mechanic.', 0)
    end
    local vehicleRow = TorqueWorksRepository.getOrCreate(order.plate, GetEntityModel(vehicle))
    if not vehicleRow then error('The vehicle build could not be loaded.', 0) end
    local build = normalizeBuild(vehicleRow.build)
    if order.status == 'PENDING' and type(quote.baseBuild) == 'table' then
        for category in pairs(Config.PartCategories) do
            if quote.baseBuild[category] ~= build[category] then
                error('The build changed. Ask the mechanic for a new quote.', 0)
            end
        end
        for _, key in ipairs({ 'tireCompound', 'transmissionPersonality' }) do
            if quote.baseBuild[key] ~= build[key] then
                error('The build changed. Ask the mechanic for a new quote.', 0)
            end
        end
    end
    local requirements, requirementLabels, seen = {}, {}, {}
    if type(quote.lines) ~= 'table' or #quote.lines == 0 then error('This quote contains no parts.', 0) end
    for _, line in ipairs(quote.lines) do
        local category, partId = line.category, line.partId
        local catalog = category == 'tireCompound' and Config.TireCompounds or
            category == 'transmissionPersonality' and Config.TransmissionPersonalities or Config.Parts[category]
        if not catalog or not catalog[partId] or seen[category] or
            partRestricted(category, partId, GetEntityModel(vehicle)) then
            error('A quoted part is no longer available or compatible. Request a new quote.', 0)
        end
        seen[category] = true
        if line.completed ~= true then
            if build[category] == partId and order.status == 'PENDING' then
                error('A quoted part is already installed. Request a new quote.', 0)
            end
            if build[category] ~= partId then
                if Config.Installation.consumable.enabled and not installationBypass(mechanicSource) and
                    partId ~= Config.FactoryBuild[category] then
                    for _, requirement in ipairs(installationRequirements(category, partId)) do
                        requirements[requirement.item] = (requirements[requirement.item] or 0) + requirement.amount
                        requirementLabels[requirement.item] = requirement.label or requirement.item
                    end
                end
                build[category] = partId
                if category == 'nitro' then build.nitroLevel = 0.0 end
            end
        end
    end
    if build.differential ~= 'ACTIVE' then build.frontTorqueBias = -1.0 end
    for itemName, amount in pairs(requirements) do
        local item = mechanic.getInventoryItem(itemName)
        if not item or (tonumber(item.count) or 0) < amount then
            error(('The mechanic needs %dx %s to install this quote.'):format(amount, requirementLabels[itemName] or itemName), 0)
        end
    end
    return { vehicle = vehicle, row = vehicleRow, build = build, requirements = requirements, mechanic = mechanic }
end

local function settleQuotedBuild(order, customerSource, paymentMethod, token, actingMechanicSource)
    local quote = type(order.quote) == 'table' and order.quote or {}
    local mechanicSource = actingMechanicSource or sourceForIdentifier(order.mechanic_identifier)
    if not mechanicSource then
        Config.Integrations.serverNotification(customerSource, { type = 'error', description = 'The mechanic is no longer online.' })
        return
    end
    if settlingPlates[order.plate] or settlingPlayers[customerSource] or settlingPlayers[mechanicSource] then return end
    local mechanicIdentifier = playerIdentifier(Framework.GetPlayerFromId(mechanicSource))
    settlingPlates[order.plate], settlingPlayers[customerSource], settlingPlayers[mechanicSource] = true, true, true
    local simulated = tonumber(order.simulated) == 1
    local prepaid = order.status == 'APPROVED'
    local charged, removed, committed = 0, {}, false
    local customer, prepared
    local function audit(event, description, level, reason)
        TorqueWorksLogs.audit(event, {
            title = description, level = level, actorLabel = 'Customer',
            actorSource = customerSource, actorIdentifier = order.customer_identifier,
            mechanicSource = mechanicSource, mechanicIdentifier = mechanicIdentifier,
            workshop = quote.workshopName or quote.workshopId, plate = order.plate,
            orderId = order.id, amount = order.total, paymentMethod = paymentMethod,
            simulated = simulated, transactionMode = committed and 'FINALIZED' or
                (prepaid and 'RESERVED' or simulated and 'SIMULATED' or 'NOT_COMPLETED'),
            reason = reason
        })
    end
    local _, failure = pcall(function()
        customer = Framework.GetPlayerFromId(customerSource)
        if not customer or playerIdentifier(customer) ~= order.customer_identifier then
            error('The quoted customer is no longer available.', 0)
        end
        local account = Config.Billing.paymentAccounts[paymentMethod]
        if (paymentMethod ~= 'cash' and paymentMethod ~= 'bank') or not account or
            (not prepaid and account.enabled ~= true) then error('This payment method is unavailable.', 0) end
        local total = tonumber(order.total)
        if not total or total < 0 or total ~= math.floor(total) or
            (not prepaid and total > (Config.Billing.maximumQuote or 250000)) then error('Invalid quote total.', 0) end
        if quote.test == true then error('Test quotes cannot install vehicle parts.', 0) end
        prepared = prepareQuotedBuild(order, mechanicSource, customerSource)
        if not prepaid and TorqueWorksRepository.getApprovedWorkOrderForPlate(order.plate) then
            error('Complete the existing paid work order for this vehicle first.', 0)
        end
        if prepaid and not simulated and (tonumber(order.reserved_amount) or 0) < total then
            error('The existing work order has an invalid payment reservation.', 0)
        end
        customer = Framework.GetPlayerFromId(customerSource)
        prepared.mechanic = Framework.GetPlayerFromId(mechanicSource)
        if playerIdentifier(customer) ~= order.customer_identifier or
            playerIdentifier(prepared.mechanic) ~= mechanicIdentifier then
            error('A participant disconnected before installation.', 0)
        end
        local function balance()
            return paymentMethod == 'cash' and tonumber(customer.getMoney()) or
                tonumber((customer.getAccount('bank') or {}).money)
        end
        if not prepaid then
            local before = balance()
            if not before or before < total then error(('Not enough money in %s.'):format(account.label or paymentMethod), 0) end
            if not simulated then
                local debited, result = pcall(function()
                    if paymentMethod == 'cash' then return customer.removeMoney(total, 'TorqueWorks quote payment') end
                    return customer.removeAccountMoney('bank', total, 'TorqueWorks quote payment')
                end)
                charged = math.max(0, before - (balance() or before))
                if not debited or result == false or charged ~= total then error('The payment could not be taken.', 0) end
            end
        end
        for itemName, amount in pairs(prepared.requirements) do
            local before = tonumber((prepared.mechanic.getInventoryItem(itemName) or {}).count) or 0
            if before < amount then error('The required materials are no longer available.', 0) end
            local taken, result = pcall(prepared.mechanic.removeInventoryItem, itemName, amount)
            local after = tonumber((prepared.mechanic.getInventoryItem(itemName) or {}).count) or before
            local consumed = math.max(0, before - after)
            if consumed > 0 then removed[#removed + 1] = { item = itemName, amount = consumed } end
            if not taken or result == false or consumed ~= amount then error('The required materials could not be consumed.', 0) end
        end
        for _, line in ipairs(quote.lines) do line.completed = true end
        if not TorqueWorksRepository.completeQuotedBuild(order, prepared.build, quote, paymentMethod, token) then
            error('The build could not be saved or the quote has expired.', 0)
        end
        committed = true
    end)
    if not committed then
        local rollbackOk = true
        local currentMechanic = Framework.GetPlayerFromId(mechanicSource)
        for _, item in ipairs(removed) do
            local restored, result = pcall(function()
                if playerIdentifier(currentMechanic) ~= mechanicIdentifier then return false end
                return currentMechanic.addInventoryItem(item.item, item.amount)
            end)
            if not restored or result == false then rollbackOk = false end
        end
        if charged > 0 then
            local refunded, result = pcall(function()
                local currentCustomer = Framework.GetPlayerFromId(customerSource)
                if playerIdentifier(currentCustomer) ~= order.customer_identifier then return false end
                if paymentMethod == 'cash' then return currentCustomer.addMoney(charged, 'TorqueWorks failed quote refund') end
                return currentCustomer.addAccountMoney('bank', charged, 'TorqueWorks failed quote refund')
            end)
            if not refunded or result == false then rollbackOk = false end
        end
        settlingPlates[order.plate], settlingPlayers[customerSource], settlingPlayers[mechanicSource] = nil, nil, nil
        local message = tostring(failure or 'The installation could not be completed.')
        if not rollbackOk then
            message = message .. ' A refund needs administrator attention.'
            print(('[coii_torqueworks] Work order #%d rollback needs attention. Charged: %s; removed materials: %s')
                :format(order.id, charged, json.encode(removed)))
        end
        audit((charged > 0 or #removed > 0) and 'paymentRollback' or 'paymentFailed',
            'Workshop installation failed', rollbackOk and 'warning' or 'danger', message)
        Config.Integrations.serverNotification(customerSource, { type = 'error', description = message })
        if mechanicSource ~= customerSource then
            Config.Integrations.serverNotification(mechanicSource, { type = 'error', description = message })
        end
        return
    end
    settlingPlates[order.plate], settlingPlayers[customerSource], settlingPlayers[mechanicSource] = nil, nil, nil
    local state = trustedState(prepared.row, prepared.build)
    TriggerClientEvent('coii_torqueworks:client:workOrderCompleted', mechanicSource)
    TriggerClientEvent('coii_torqueworks:client:buildCardChanged', -1, order.plate)
    TriggerClientEvent('coii_torqueworks:client:buildApplied', mechanicSource, state, quote.networkId, true)
    local driver = GetPedInVehicleSeat(prepared.vehicle, -1)
    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        if target ~= mechanicSource and GetPlayerPed(target) == driver then
            TriggerClientEvent('coii_torqueworks:client:buildApplied', target, state, quote.networkId, true)
            break
        end
    end
    audit(prepaid and 'workOrderCompleted' or 'paymentApproved', 'Workshop quote installed', 'success')
    if not prepaid then audit('workOrderCompleted', 'Work order completed', 'success') end
    local message = ('Work order #%d complete. All quoted parts are installed.'):format(order.id)
    Config.Integrations.serverNotification(customerSource, { type = 'success', description = message })
    if mechanicSource ~= customerSource then
        Config.Integrations.serverNotification(mechanicSource, { type = 'success', description = message })
    end
end

RegisterNetEvent('coii_torqueworks:server:respondQuote', function(orderId, token, accepted, paymentMethod)
    local source = source
    if Config.Billing.enabled ~= true or rateLimited(source, 'quoteResponse', 750) then return end
    orderId = math.floor(tonumber(orderId) or 0)
    if orderId <= 0 or type(token) ~= 'string' or #token > 64 then return end
    local order = TorqueWorksRepository.getPendingWorkOrder(orderId, token)
    local customer = Framework.GetPlayerFromId(source)
    if not order or not customer or order.customer_identifier ~= playerIdentifier(customer) then
        TorqueWorksLogs.audit('paymentFailed', {
            title = 'Invalid quote response', level = 'warning', actorLabel = 'Player',
            actorSource = source, actorIdentifier = playerIdentifier(customer), orderId = orderId,
            reason = 'Invalid/expired token or a response from someone other than the quoted customer.'
        })
        return
    end
    if accepted ~= true then
        if TorqueWorksRepository.rejectWorkOrder(orderId, token) then
            TorqueWorksLogs.audit('quoteRejected', {
                title = 'Workshop quote rejected', level = 'warning', actorLabel = 'Customer',
                actorSource = source, actorIdentifier = order.customer_identifier,
                mechanicSource = sourceForIdentifier(order.mechanic_identifier), mechanicIdentifier = order.mechanic_identifier,
                workshop = order.quote.workshopName or order.quote.workshopId, plate = order.plate,
                orderId = order.id, amount = order.total, transactionMode = 'REJECTED'
            })
            Config.Integrations.serverNotification(source, { type = 'inform', description = 'Workshop quote rejected.' })
            if order.mechanic_identifier ~= order.customer_identifier then
                notifyIdentifier(order.mechanic_identifier, { type = 'inform', description = 'The customer rejected the quote.' })
            end
        end
        return
    end
    settleQuotedBuild(order, source, type(paymentMethod) == 'string' and paymentMethod:lower() or '', token)
end)

-- Finish orders paid before the instant-install update without charging again.
RegisterNetEvent('coii_torqueworks:server:completeApprovedWorkOrder', function(plate, networkId)
    local source = source
    if Config.Billing.enabled ~= true or rateLimited(source, 'completeWorkOrder', 1000) then return end
    local vehicle, normalized = validatedDrivenVehicle(source, plate, networkId)
    if vehicle == 0 then return end
    local order = TorqueWorksRepository.getApprovedWorkOrderForPlate(normalized)
    if not order then return end
    local customerSource = sourceForIdentifier(order.customer_identifier)
    if not customerSource then
        Config.Integrations.serverNotification(source, { type = 'error', description = 'The customer must be nearby to finish this paid order.' })
        return
    end
    order.quote.networkId = networkId
    settleQuotedBuild(order, customerSource, order.payment_method, nil, source)
end)

AddEventHandler('playerDropped', function()
    finishNitroSession(source)
    nitroReuseAt[source] = nil
    nitroAutoRefillTokens[source] = nil
    nitroAutoRefillEnabled[source] = nil
    requestCooldowns[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local players = {}
    for playerId in pairs(nitroSessions) do players[#players + 1] = playerId end
    for _, playerId in ipairs(players) do finishNitroSession(playerId) end
end)
