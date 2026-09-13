local zoneMembership = {}
local previewVehicle = 0
local previewCache = {}
local previewAccentKey
local lastProjection = { visible = false, x = -1.0, y = -1.0 }
local previewTopOffset = 0.42

local function insideCardZone()
    for _, inside in pairs(zoneMembership) do if inside then return true end end
    return false
end

local function plateOf(vehicle)
    return GetVehicleNumberPlateText(vehicle):upper():gsub('^%s+', ''):gsub('%s+$', '')
end

local function modelName(vehicle)
    local key = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local label = GetLabelText(key)
    return label and label ~= 'NULL' and label or key
end

local function manufacturerName(vehicle)
    if type(GetMakeNameFromVehicleModel) ~= 'function' then return 'CUSTOM' end
    local key = GetMakeNameFromVehicleModel(GetEntityModel(vehicle))
    if type(key) ~= 'string' or key == '' or key == 'NULL' then return 'CUSTOM' end
    local label = GetLabelText(key)
    if type(label) == 'string' and label ~= '' and label ~= 'NULL' then return label end
    return key
end

local function vehicleAccent(vehicle)
    local function readable(r, g, b)
        r, g, b = tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0
        local luminance = r * 0.2126 + g * 0.7152 + b * 0.0722
        if luminance < 115.0 then
            local mix = (115.0 - luminance) / math.max(1.0, 255.0 - luminance)
            r, g, b = r + (255 - r) * mix, g + (255 - g) * mix, b + (255 - b) * mix
        end
        return { r = math.floor(r + 0.5), g = math.floor(g + 0.5), b = math.floor(b + 0.5) }
    end
    -- Custom RGB paint must be checked first. GET_VEHICLE_COLOR can report the
    -- underlying indexed/base paint even while a custom primary is displayed.
    if GetIsVehiclePrimaryColourCustom(vehicle) then
        local r, g, b = GetVehicleCustomPrimaryColour(vehicle)
        return readable(r, g, b)
    end
    if type(GetVehicleColor) == 'function' then
        local ok, r, g, b = pcall(GetVehicleColor, vehicle)
        if ok and tonumber(r) and tonumber(g) and tonumber(b) then return readable(r, g, b) end
    end
    local primary = select(1, GetVehicleColours(vehicle)) or 0
    if primary >= 27 and primary <= 49 then return readable(190, 38, 42) end
    if primary >= 50 and primary <= 60 then return readable(38, 135, 83) end
    if primary >= 61 and primary <= 74 then return readable(40, 102, 190) end
    if primary >= 88 and primary <= 91 then return readable(225, 178, 42) end
    if primary >= 135 and primary <= 137 then return readable(218, 83, 151) end
    if primary == 111 or primary == 112 then return readable(215, 220, 218) end
    return readable(45, 48, 50)
end

local function hidePreview()
    if previewVehicle == 0 then return end
    previewVehicle = 0
    previewAccentKey = nil
    previewTopOffset = 0.42
    lastProjection.visible, lastProjection.x, lastProjection.y = false, -1.0, -1.0
    SendNUIMessage({ action = 'buildCardPreviewHide' })
end

local function loadPreview(vehicle)
    if not NetworkGetEntityIsNetworked(vehicle) then
        hidePreview()
        return
    end
    local plate = plateOf(vehicle)
    local cached = previewCache[plate]
    local now = GetGameTimer()
    local response
    if cached and now - cached.loadedAt < Config.BuildCard.previewRefreshMs then
        response = cached.response
    else
        response = lib.callback.await('coii_torqueworks:server:getBuildCard', false,
            plate, NetworkGetNetworkIdFromEntity(vehicle))
        if response then previewCache[plate] = { loadedAt = now, response = response } end
    end
    if not response or response.private or response.unavailable then
        hidePreview()
        return
    end
    previewVehicle = vehicle
    local _, maximum = GetModelDimensions(GetEntityModel(vehicle))
    previewTopOffset = maximum.z + 0.42
    response.modelName = modelName(vehicle)
    response.manufacturer = manufacturerName(vehicle)
    response.accent = vehicleAccent(vehicle)
    previewAccentKey = ('%d:%d:%d'):format(response.accent.r, response.accent.g, response.accent.b)
    SendNUIMessage({ action = 'buildCardPreview', card = response })
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if not insideCardZone() or IsPedInAnyVehicle(ped, false) then
            hidePreview()
            Wait(500)
        else
            local playerCoords = GetEntityCoords(ped)
            local closest = 0
            local closestDistanceSq = (Config.BuildCard.previewDistance + 0.001) ^ 2
            for _, vehicle in ipairs(GetGamePool('CVehicle')) do
                if DoesEntityExist(vehicle) and NetworkGetEntityIsNetworked(vehicle) and
                    GetPedInVehicleSeat(vehicle, -1) == 0 then
                    local coords = GetEntityCoords(vehicle)
                    local dx, dy, dz = playerCoords.x - coords.x, playerCoords.y - coords.y, playerCoords.z - coords.z
                    local distanceSq = dx * dx + dy * dy + dz * dz
                    if distanceSq < closestDistanceSq then
                        closest, closestDistanceSq = vehicle, distanceSq
                    end
                end
            end
            if closest == 0 then
                hidePreview()
            else
                local cached = previewCache[plateOf(closest)]
                local expired = not cached or GetGameTimer() - cached.loadedAt >= Config.BuildCard.previewRefreshMs
                if closest ~= previewVehicle or expired then loadPreview(closest) end
                if closest == previewVehicle then
                    local accent = vehicleAccent(closest)
                    local accentKey = ('%d:%d:%d'):format(accent.r, accent.g, accent.b)
                    if accentKey ~= previewAccentKey then
                        previewAccentKey = accentKey
                        SendNUIMessage({ action = 'buildCardPreviewAccent', accent = accent })
                    end
                end
            end
            Wait(Config.BuildCard.scanIntervalMs or 400)
        end
    end
end)

CreateThread(function()
    while true do
        if previewVehicle == 0 or not DoesEntityExist(previewVehicle) then
            Wait(300)
        else
            local world = GetOffsetFromEntityInWorldCoords(previewVehicle, 0.0, 0.0, previewTopOffset)
            local projector = type(GetScreenCoordFromWorldCoord) == 'function' and
                GetScreenCoordFromWorldCoord or World3dToScreen2d
            local visible, screenX, screenY = projector(world.x, world.y, world.z)
            visible = visible == true or visible == 1
            screenX, screenY = tonumber(screenX) or -1.0, tonumber(screenY) or -1.0
            if visible ~= lastProjection.visible or math.abs(screenX - lastProjection.x) > 0.00025 or
                math.abs(screenY - lastProjection.y) > 0.00025 then
                lastProjection.visible, lastProjection.x, lastProjection.y = visible, screenX, screenY
                SendNUIMessage({ action = 'buildCardPreviewPosition', visible = visible, x = screenX, y = screenY })
            end
            Wait(Config.BuildCard.positionUpdateMs or 33)
        end
    end
end)

RegisterNetEvent('coii_torqueworks:client:buildCardChanged', function(plate)
    if type(plate) ~= 'string' then return end
    previewCache[plate] = nil
    if previewVehicle ~= 0 and DoesEntityExist(previewVehicle) and plateOf(previewVehicle) == plate then
        hidePreview()
    end
end)

CreateThread(function()
    for index, definition in ipairs(Config.BuildCard.zones) do
        if definition.enabled ~= false and definition.type == 'box' and definition.coords and definition.size then
            lib.zones.box({
                name = definition.name or ('torqueworks_build_cards_' .. index),
                coords = vector3(definition.coords.x, definition.coords.y, definition.coords.z),
                size = vector3(definition.size.x, definition.size.y, definition.size.z),
                rotation = definition.rotation or definition.heading or 0.0,
                debug = definition.debug == true,
                onEnter = function() zoneMembership[index] = true end,
                onExit = function() zoneMembership[index] = nil end
            })
        elseif definition.enabled ~= false and type(definition.points) == 'table' and #definition.points >= 3 then
            local points = {}
            for i, point in ipairs(definition.points) do points[i] = vector3(point.x, point.y, point.z) end
            lib.zones.poly({
                name = definition.name or ('torqueworks_build_cards_' .. index), points = points,
                thickness = definition.thickness or 6.0, debug = definition.debug == true,
                onEnter = function() zoneMembership[index] = true end,
                onExit = function() zoneMembership[index] = nil end
            })
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SendNUIMessage({ action = 'buildCardPreviewHide' })
end)
