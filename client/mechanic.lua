TorqueWorksMechanic = {
    visible = false,
    build = nil,
    camera = nil,
    yaw = 0.0,
    pitch = 0.24,
    distance = 6.0
}

local hotspotInterval = 50
local lastHotspotUpdate = 0

local function plateOf(vehicle)
    return GetVehicleNumberPlateText(vehicle):upper():gsub('^%s+', ''):gsub('%s+$', '')
end

local function drivenVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return 0 end
    return vehicle
end

local function isSupportedCar(vehicle)
    return vehicle ~= 0 and DoesEntityExist(vehicle) and IsThisModelACar(GetEntityModel(vehicle))
end

local function closeMechanic()
    local vehicle = TorqueWorksMechanic.vehicle
    if vehicle and DoesEntityExist(vehicle) and not TorqueWorksMechanic.wasFrozen then
        FreezeEntityPosition(vehicle, false)
    end
    if TorqueWorksMechanic.camera then
        RenderScriptCams(false, true, 350, true, true)
        DestroyCam(TorqueWorksMechanic.camera, false)
        TorqueWorksMechanic.camera = nil
    end
    ClearFocus()
    TorqueWorksMechanic.visible = false
    TorqueWorksMechanic.build = nil
    TorqueWorksMechanic.vehicle = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'mechanicClose' })
end

local function startCamera(vehicle)
    local minimum, maximum = GetModelDimensions(GetEntityModel(vehicle))
    local length = math.abs(maximum.y - minimum.y)
    local width = math.abs(maximum.x - minimum.x)
    TorqueWorksMechanic.minimum = minimum
    TorqueWorksMechanic.maximum = maximum
    TorqueWorksMechanic.cachedHotspotOffsets = nil
    TorqueWorksMechanic.cachedHotspotPoints = nil
    TorqueWorksMechanic.cameraDirty = true
    TorqueWorksMechanic.hotspotsDirty = true
    TorqueWorksMechanic.lastCameraRefresh = 0
    TorqueWorksMechanic.yaw = math.rad(GetEntityHeading(vehicle) + 135.0)
    TorqueWorksMechanic.pitch = 0.24
    TorqueWorksMechanic.distance = TorqueWorksMath.clamp(math.max(length, width) * 1.65, 4.5, 9.0)
    TorqueWorksMechanic.wasFrozen = IsEntityPositionFrozen(vehicle)
    TorqueWorksMechanic.vehicle = vehicle
    FreezeEntityPosition(vehicle, true)

    local camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    if not camera or camera == 0 then
        if not TorqueWorksMechanic.wasFrozen then FreezeEntityPosition(vehicle, false) end
        TorqueWorksMechanic.vehicle = nil
        return false
    end
    SetCamFov(camera, 46.0)
    pcall(SetCamUseShallowDofMode, camera, true)
    pcall(SetCamNearDof, camera, 0.8)
    pcall(SetCamFarDof, camera, 14.0)
    pcall(SetCamDofStrength, camera, 0.72)

    -- A newly-created scripted camera starts at an undefined/default world
    -- position. Fully place and aim it before rendering, otherwise one frame
    -- of sky/void is visible while the camera update thread catches up.
    local center = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 0.0,
        (maximum.z + minimum.z) * 0.5)
    local horizontal = math.cos(TorqueWorksMechanic.pitch) * TorqueWorksMechanic.distance
    local cameraPosition = vector3(
        center.x + math.cos(TorqueWorksMechanic.yaw) * horizontal,
        center.y + math.sin(TorqueWorksMechanic.yaw) * horizontal,
        center.z + math.sin(TorqueWorksMechanic.pitch) * TorqueWorksMechanic.distance)
    SetCamCoord(camera, cameraPosition.x, cameraPosition.y, cameraPosition.z)
    PointCamAtCoord(camera, center.x, center.y, center.z)
    SetFocusPosAndVel(center.x, center.y, center.z, 0.0, 0.0, 0.0)

    SetCamActive(camera, true)
    TorqueWorksMechanic.camera = camera
    TorqueWorksMechanic.cameraDirty = false
    TorqueWorksMechanic.lastCameraRefresh = GetGameTimer()
    RenderScriptCams(true, true, 450, true, true)
    return true
end

function TorqueWorksMechanic.open(workshopId)
    local workshop = type(Config.Workshops) == 'table' and Config.Workshops[workshopId] or nil
    if not workshop or not workshop.tuning or workshop.tuning.enabled == false then
        TorqueWorksUI.notify({ type = 'error', description = 'No TorqueWorks workshop is available here.' })
        return
    end
    local vehicle = drivenVehicle()
    if vehicle == 0 then
        TorqueWorksUI.notify({ type = 'error', description = 'You must be driving an active TorqueWorks vehicle.' })
        return
    end
    if not isSupportedCar(vehicle) then
        TorqueWorksUI.notify({ type = 'error', description = 'The mechanic terminal is only available for cars.' })
        return
    end
    local response = lib.callback.await('coii_torqueworks:server:getMechanicData', false,
        plateOf(vehicle), NetworkGetNetworkIdFromEntity(vehicle), workshopId)
    if not response or not response.authorized then
        TorqueWorksUI.notify({ type = 'error', description = 'You do not have mechanic access.' })
        return
    end
    if response.error then
        TorqueWorksUI.notify({ type = 'error', description = response.error })
        return
    end
    if (not TorqueWorks.active or TorqueWorks.active.vehicle ~= vehicle) and
        not TorqueWorks.ensureActive(vehicle) then
        TorqueWorksUI.notify({ type = 'error', description = 'TorqueWorks could not be loaded for this vehicle.' })
        return
    end

    TorqueWorksMechanic.visible = true
    TorqueWorksMechanic.build = response.state.build
    TorqueWorksMechanic.workshopId = workshopId
    if not startCamera(vehicle) then
        TorqueWorksMechanic.visible = false
        TorqueWorksMechanic.build = nil
        TorqueWorksUI.notify({ type = 'error', description = 'The mechanic camera could not be created.' })
        return
    end
    SendNUIMessage({
        action = 'mechanicOpen',
        workshop = response.workshop,
        plate = response.state.plate,
        build = response.state.build,
        vehicleClass = response.state.vehicleClass,
        lockedParts = response.lockedParts or {},
        installationBypass = response.installationBypass == true,
        history = response.history or {},
        workOrder = response.workOrder,
        catalogs = {
            parts = Config.Parts,
            maps = Config.EcuMaps,
            ecuCalibration = Config.EcuCalibration,
            compounds = Config.TireCompounds,
            prices = Config.DisplayPrices,
            pressure = Config.TirePressure,
            compatibility = Config.PartCompatibility,
            transmissionPersonalities = Config.TransmissionPersonalities,
            factory = Config.FactoryBuild,
            installation = response.installation or Config.Installation,
            billing = { laborPerPart = Config.Billing.laborPerPart }
        }
    })
    SetNuiFocus(true, true)
end

local terminalTextVisible = false
local activeTerminalId

local function hideTerminalInteraction()
    if not terminalTextVisible then return end
    terminalTextVisible = false
    activeTerminalId = nil
    TorqueWorksUI.hideTextUI()
end

for workshopId, workshop in pairs(Config.Workshops or {}) do
    local terminal = workshop.tuning
    if terminal and terminal.enabled ~= false and terminal.coords then
        local pointWorkshopId, pointWorkshopName = workshopId, workshop.name or workshopId
        local terminalPoint = lib.points.new({
            coords = terminal.coords,
            distance = terminal.drawDistance or 18.0
        })

        function terminalPoint:nearby()
            local validVehicle = isSupportedCar(drivenVehicle())
            local canInteract = self.currentDistance <= (terminal.interactDistance or 3.0)
                and not TorqueWorksMechanic.visible and validVehicle
            if canInteract and (not terminalTextVisible or activeTerminalId ~= pointWorkshopId) then
                if terminalTextVisible then TorqueWorksUI.hideTextUI() end
                terminalTextVisible = true
                activeTerminalId = pointWorkshopId
                TorqueWorksUI.showTextUI(terminal.prompt or ('[E] Open %s'):format(pointWorkshopName), {
                    position = 'left-center', icon = 'screwdriver-wrench'
                })
            elseif not canInteract and activeTerminalId == pointWorkshopId then
                hideTerminalInteraction()
            end
            if canInteract and IsControlJustReleased(0, terminal.control or 38) then
                hideTerminalInteraction()
                TorqueWorksMechanic.open(pointWorkshopId)
            end
        end

        function terminalPoint:onExit()
            if activeTerminalId == pointWorkshopId then hideTerminalInteraction() end
        end
    end
end

function TorqueWorksMechanic.nearestWorkshop()
    local coords = GetEntityCoords(PlayerPedId())
    local nearestId, nearestDistance
    for workshopId, workshop in pairs(Config.Workshops or {}) do
        local tuning = workshop.tuning
        if tuning and tuning.enabled ~= false and tuning.coords then
            local distance = #(coords - tuning.coords)
            if not nearestDistance or distance < nearestDistance then
                nearestId, nearestDistance = workshopId, distance
            end
        end
    end
    return nearestId, nearestDistance
end

function TorqueWorksMechanic.updateBuild(build, vehicleClass)
    if not TorqueWorksMechanic.visible then return end
    TorqueWorksMechanic.build = build
    SendNUIMessage({ action = 'mechanicBuild', build = build, vehicleClass = vehicleClass })
end

RegisterNUICallback('mechanicClose', function(_, callback)
    closeMechanic()
    callback({ ok = true })
end)

RegisterNetEvent('coii_torqueworks:client:customerQuote', function(quote)
    if type(quote) ~= 'table' or type(quote.token) ~= 'string' then return end
    SendNUIMessage({ action = 'customerQuote', quote = quote })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('coii_torqueworks:client:workOrderCompleted', function()
    closeMechanic()
end)

RegisterNUICallback('customerQuoteResponse', function(data, callback)
    SetNuiFocus(data.selfQuote == true, data.selfQuote == true)
    local response = type(data) == 'table' and data.response or 'reject'
    local accepted = response == 'cash' or response == 'bank'
    TriggerServerEvent('coii_torqueworks:server:respondQuote',
        data.id, data.token, accepted, accepted and response or nil)
    callback({ ok = true })
end)

RegisterNUICallback('mechanicSendQuote', function(data, callback)
    if not TorqueWorksMechanic.visible or type(data) ~= 'table' or type(data.lines) ~= 'table' then
        callback({ ok = false }) return
    end
    local ped, origin = PlayerPedId(), GetEntityCoords(PlayerPedId())
    local closestServerId, closestDistance
    if data.self == true then
        closestServerId = GetPlayerServerId(PlayerId())
    else
        for _, player in ipairs(GetActivePlayers()) do
            if player ~= PlayerId() then
                local targetPed = GetPlayerPed(player)
                local distance = #(origin - GetEntityCoords(targetPed))
                if distance <= (Config.Billing.customerDistance or 8.0) and
                    (not closestDistance or distance < closestDistance) then
                    closestDistance, closestServerId = distance, GetPlayerServerId(player)
                end
            end
        end
    end
    if not closestServerId then
        TorqueWorksUI.notify({ type = 'error', description = 'No customer is nearby.' })
        callback({ ok = false }) return
    end
    local vehicle = TorqueWorksMechanic.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then callback({ ok = false }) return end
    TriggerServerEvent('coii_torqueworks:server:createMechanicQuote', closestServerId,
        plateOf(vehicle), NetworkGetNetworkIdFromEntity(vehicle), TorqueWorksMechanic.workshopId, data.lines)
    callback({ ok = true })
end)

RegisterNUICallback('mechanicAction', function(data, callback)
    if not TorqueWorksMechanic.visible or type(data) ~= 'table' then
        callback({ ok = false })
        return
    end
    local vehicle = drivenVehicle()
    if vehicle == 0 then
        closeMechanic()
        callback({ ok = false })
        return
    end

    local plate, networkId = plateOf(vehicle), NetworkGetNetworkIdFromEntity(vehicle)
    if data.action == 'part' then
        if Config.Billing.enabled and data.value ~= Config.FactoryBuild[data.category] then
            TriggerServerEvent('coii_torqueworks:server:completeApprovedWorkOrder', plate, networkId)
        else
            TriggerServerEvent('coii_torqueworks:server:setPart', data.category, data.value, plate, networkId)
        end
    elseif data.action == 'buildName' then
        TriggerServerEvent('coii_torqueworks:server:setBuildName', data.value, plate, networkId)
    elseif data.action == 'map' then
        TriggerServerEvent('coii_torqueworks:server:setEcuMap', data.value, plate, networkId)
    elseif data.action == 'ecuCalibration' then
        TriggerServerEvent('coii_torqueworks:server:setEcuCalibration', data.value, plate, networkId)
    elseif data.action == 'transmissionPersonality' or data.action == 'compound' then
        if Config.Billing.enabled then
            TriggerServerEvent('coii_torqueworks:server:completeApprovedWorkOrder', plate, networkId)
        elseif data.action == 'transmissionPersonality' then
            TriggerServerEvent('coii_torqueworks:server:setTransmissionPersonality', data.value, plate, networkId)
        else
            TriggerServerEvent('coii_torqueworks:server:setChassisSetting', data.action, data.value, plate, networkId)
        end
    elseif data.action == 'pressure' or data.action == 'split' then
        TriggerServerEvent('coii_torqueworks:server:setChassisSetting', data.action, data.value, plate, networkId)
    elseif data.action == 'resetEcu' then
        TriggerServerEvent('coii_torqueworks:server:resetEcu', plate, networkId)
    elseif data.action == 'resetBuild' then
        TriggerServerEvent('coii_torqueworks:server:resetBuild', plate, networkId)
    else
        callback({ ok = false })
        return
    end
    callback({ ok = true })
end)

RegisterNUICallback('mechanicCamera', function(data, callback)
    if not TorqueWorksMechanic.visible then callback({ ok = false }) return end
    if data.kind == 'orbit' then
        TorqueWorksMechanic.yaw = TorqueWorksMechanic.yaw - TorqueWorksMath.clamp(tonumber(data.x) or 0, -80, 80) * 0.006
        TorqueWorksMechanic.pitch = TorqueWorksMath.clamp(TorqueWorksMechanic.pitch +
            TorqueWorksMath.clamp(tonumber(data.y) or 0, -80, 80) * 0.004, -0.08, 0.72)
    elseif data.kind == 'zoom' then
        TorqueWorksMechanic.distance = TorqueWorksMath.clamp(TorqueWorksMechanic.distance +
            TorqueWorksMath.clamp(tonumber(data.value) or 0, -3, 3) * 0.55, 3.5, 11.0)
    end
    TorqueWorksMechanic.cameraDirty = true
    TorqueWorksMechanic.hotspotsDirty = true
    callback({ ok = true })
end)

local function hotspotOffsets(minimum, maximum)
    local lowerZ = minimum.z + (maximum.z - minimum.z) * 0.42
    return {
        { id = 'engine', x = 0.0, y = maximum.y * 0.62, z = maximum.z * 0.42 },
        { id = 'turbo', x = maximum.x * 0.62, y = maximum.y * 0.48, z = maximum.z * 0.40 },
        { id = 'ecu', x = minimum.x * 0.62, y = maximum.y * 0.43, z = maximum.z * 0.48 },
        { id = 'fuelpump', x = minimum.x * 0.50, y = maximum.y * 0.12, z = lowerZ },
        { id = 'nitro', x = maximum.x * 0.35, y = minimum.y * 0.05, z = lowerZ },
        { id = 'flywheel', x = 0.0, y = 0.0, z = lowerZ },
        { id = 'transmission', x = 0.0, y = 0.0, z = lowerZ },
        { id = 'differential', x = 0.0, y = minimum.y * 0.62, z = lowerZ },
        { id = 'tires', x = maximum.x * 0.90, y = minimum.y * 0.25, z = lowerZ },
        { id = 'brakes', x = minimum.x * 0.90, y = maximum.y * 0.18, z = lowerZ },
        { id = 'suspension', x = minimum.x * 0.55, y = minimum.y * 0.30, z = lowerZ },
        { id = 'history', x = 0.0, y = 0.0, z = maximum.z + 0.55 }
    }
end

local function projectWorldPoint(world)
    local projector = type(GetScreenCoordFromWorldCoord) == 'function' and
        GetScreenCoordFromWorldCoord or World3dToScreen2d
    if type(projector) ~= 'function' then return false, -1.0, -1.0 end
    local ok, visible, screenX, screenY = pcall(projector, world.x, world.y, world.z)
    if not ok then return false, -1.0, -1.0 end
    return visible == true or visible == 1, tonumber(screenX) or -1.0, tonumber(screenY) or -1.0
end

CreateThread(function()
    while true do
        if not TorqueWorksMechanic.visible or not TorqueWorksMechanic.camera then
            Wait(500)
        else
            local vehicle = TorqueWorksMechanic.vehicle
            if not vehicle or not DoesEntityExist(vehicle) then
                closeMechanic()
                Wait(500)
            else
                local center = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 0.0,
                    (TorqueWorksMechanic.maximum.z + TorqueWorksMechanic.minimum.z) * 0.5)
                local now = GetGameTimer()
                if TorqueWorksMechanic.cameraDirty or
                    now - (TorqueWorksMechanic.lastCameraRefresh or 0) >= 1000 then
                    local horizontal = math.cos(TorqueWorksMechanic.pitch) * TorqueWorksMechanic.distance
                    local cameraPosition = vector3(
                        center.x + math.cos(TorqueWorksMechanic.yaw) * horizontal,
                        center.y + math.sin(TorqueWorksMechanic.yaw) * horizontal,
                        center.z + math.sin(TorqueWorksMechanic.pitch) * TorqueWorksMechanic.distance)
                    SetCamCoord(TorqueWorksMechanic.camera, cameraPosition.x, cameraPosition.y, cameraPosition.z)
                    PointCamAtCoord(TorqueWorksMechanic.camera, center.x, center.y, center.z)
                    SetFocusPosAndVel(center.x, center.y, center.z, 0.0, 0.0, 0.0)
                    TorqueWorksMechanic.cameraDirty = false
                    TorqueWorksMechanic.hotspotsDirty = true
                    TorqueWorksMechanic.lastCameraRefresh = now
                end
                HideHudAndRadarThisFrame()
                pcall(SetUseHiDof)

                if TorqueWorksMechanic.hotspotsDirty and now - lastHotspotUpdate >= hotspotInterval then
                    local offsets = TorqueWorksMechanic.cachedHotspotOffsets
                    if not offsets then
                        offsets = hotspotOffsets(TorqueWorksMechanic.minimum, TorqueWorksMechanic.maximum)
                        TorqueWorksMechanic.cachedHotspotOffsets = offsets
                    end
                    local points = TorqueWorksMechanic.cachedHotspotPoints or {}
                    TorqueWorksMechanic.cachedHotspotPoints = points
                    for index, offset in ipairs(offsets) do
                        local world = GetOffsetFromEntityInWorldCoords(vehicle, offset.x, offset.y, offset.z)
                        local visible, screenX, screenY = projectWorldPoint(world)
                        local point = points[index] or {}
                        points[index] = point
                        point.id, point.visible, point.x, point.y = offset.id, visible, screenX, screenY
                    end
                    SendNUIMessage({ action = 'mechanicHotspots', points = points })
                    lastHotspotUpdate = now
                    TorqueWorksMechanic.hotspotsDirty = false
                end
                Wait(0)
            end
        end
    end
end)

CreateThread(function()
    while true do
        if TorqueWorksMechanic.visible then
            local vehicle = drivenVehicle()
            if vehicle == 0 or not TorqueWorks.active or TorqueWorks.active.vehicle ~= vehicle then
                closeMechanic()
            end
            Wait(300)
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeMechanic()
end)
