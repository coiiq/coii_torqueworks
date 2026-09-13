TorqueWorksMmi = {
    placing = false,
    objects = {}
}

local mmiProp = type(Config.Mmi.prop) == 'string' and joaat(Config.Mmi.prop) or Config.Mmi.prop

local function plateOf(vehicle)
    return GetVehicleNumberPlateText(vehicle):upper():gsub('^%s+', ''):gsub('%s+$', '')
end

local function isSupportedCar(vehicle)
    return vehicle ~= 0 and DoesEntityExist(vehicle) and IsThisModelACar(GetEntityModel(vehicle))
end

local function loadModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local deadline = GetGameTimer() + 4000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(25) end
    return HasModelLoaded(model)
end

local function rotationToDirection(rotation)
    local z, x = math.rad(rotation.z), math.rad(rotation.x)
    local cosine = math.abs(math.cos(x))
    return vector3(-math.sin(z) * cosine, math.cos(z) * cosine, math.sin(x))
end

local function applyScale(entity, scale)
    if not entity or entity == 0 or not DoesEntityExist(entity) or scale == 1.0 then return end
    local forward, right, up, position = GetEntityMatrix(entity)
    local function scaledUnit(axis)
        local length = math.sqrt(axis.x * axis.x + axis.y * axis.y + axis.z * axis.z)
        if length < 0.0001 then return axis end
        return vector3(axis.x / length * scale, axis.y / length * scale, axis.z / length * scale)
    end
    forward, right, up = scaledUnit(forward), scaledUnit(right), scaledUnit(up)
    SetEntityMatrix(entity,
        forward.x, forward.y, forward.z,
        right.x, right.y, right.z,
        up.x, up.y, up.z,
        position.x, position.y, position.z)
end

local function cameraRaycast(vehicle, previewDepth)
    local origin = GetGameplayCamCoord()
    local direction = rotationToDirection(GetGameplayCamRot(2))
    local target = origin + direction * Config.Mmi.rayDistance
    local handle = StartExpensiveSynchronousShapeTestLosProbe(
        origin.x, origin.y, origin.z, target.x, target.y, target.z, 2, PlayerPedId(), 7)
    local _, hit, coords, normal, entity = GetShapeTestResult(handle)
    if hit == 1 and entity == vehicle then
        return true, coords, normal, direction, true
    end

    -- Many GTA vehicles have no raycastable interior mesh. Keep placement tied
    -- to the camera ray and validate the projected point against model bounds.
    local fallback = origin + direction * previewDepth
    local localPoint = GetOffsetFromEntityGivenWorldCoords(vehicle, fallback.x, fallback.y, fallback.z)
    local minimum, maximum = GetModelDimensions(GetEntityModel(vehicle))
    local margin = 0.12
    local inside = localPoint.x >= minimum.x - margin and localPoint.x <= maximum.x + margin and
        localPoint.y >= minimum.y - margin and localPoint.y <= maximum.y + margin and
        localPoint.z >= minimum.z - margin and localPoint.z <= maximum.z + margin
    return inside, fallback, vector3(0.0, 0.0, 1.0), direction, false
end

local function deleteObject(object)
    if object and DoesEntityExist(object) then DeleteEntity(object) end
end

local function endPlacement(state, installed)
    if not state then return end
    TorqueWorksMmi.placing = false
    deleteObject(state.preview)
    if state.vehicle ~= 0 and DoesEntityExist(state.vehicle) and not state.wasFrozen then
        FreezeEntityPosition(state.vehicle, false)
    end
    if state.camera then
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(state.camera, false)
    end
    SetFollowVehicleCamViewMode(state.previousViewMode)
    TorqueWorksUI.hideTextUI()
    SetModelAsNoLongerNeeded(mmiProp)
    if installed then
        TorqueWorksUI.notify({ type = 'success', description = 'TorqueWorks MMI installed.' })
    end
end

local function beginPlacement()
    if TorqueWorksMmi.placing then return end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        TorqueWorksUI.notify({ type = 'error', description = 'Sit in the driver seat to place the MMI.' })
        return
    end
    if not isSupportedCar(vehicle) then
        TorqueWorksUI.notify({ type = 'error', description = 'An MMI controller can only be installed in a car.' })
        return
    end
    if GetEntitySpeed(vehicle) > Config.Mmi.installMaxSpeed then
        TorqueWorksUI.notify({ type = 'error', description = 'Stop the vehicle before installing the MMI.' })
        return
    end
    if Entity(vehicle).state.torqueworksMmi then
        TorqueWorksUI.notify({ type = 'error', description = 'This vehicle already has an MMI controller.' })
        return
    end
    if not IsModelInCdimage(mmiProp) or not IsModelValid(mmiProp) or not loadModel(mmiProp) then
        TorqueWorksUI.notify({ type = 'error', description = 'The configured MMI prop could not be loaded.' })
        return
    end

    local preview = CreateObjectNoOffset(mmiProp, 0.0, 0.0, 0.0, false, false, false)
    SetEntityCollision(preview, false, false)
    FreezeEntityPosition(preview, true)
    SetEntityAlpha(preview, 255, false)
    SetEntityVisible(preview, true, false)

    local state = {
        vehicle = vehicle,
        preview = preview,
        relativeRotation = vector3(0.0, 0.0, 0.0),
        relativePosition = nil,
        depth = Config.Mmi.previewDepth,
        previousViewMode = GetFollowVehicleCamViewMode(),
        wasFrozen = IsEntityPositionFrozen(vehicle),
        valid = false,
        saving = false
    }
    TorqueWorksMmi.placing = state
    FreezeEntityPosition(vehicle, true)
    SetFollowVehicleCamViewMode(4)
    Wait(100)
    local camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    if camera and camera ~= 0 then
        local cameraPosition = GetGameplayCamCoord()
        local cameraRotation = GetGameplayCamRot(2)
        SetCamCoord(camera, cameraPosition.x, cameraPosition.y, cameraPosition.z)
        SetCamRot(camera, cameraRotation.x, cameraRotation.y, cameraRotation.z, 2)
        SetCamFov(camera, 52.0)
        SetCamActive(camera, true)
        RenderScriptCams(true, true, 250, true, true)
        state.camera = camera
    end
    TorqueWorksUI.showTextUI('[ENTER] INSTALL  [BACKSPACE] CANCEL  [W/S] FRONT/BACK  [A/D] LEFT/RIGHT  [SHIFT/CTRL] UP/DOWN  [Q/E] ROTATE  [ARROWS] TILT/ROLL', {
        position = 'top-center'
    })

    CreateThread(function()
        while TorqueWorksMmi.placing == state do
            if not DoesEntityExist(vehicle) or GetVehiclePedIsIn(PlayerPedId(), false) ~= vehicle then
                endPlacement(state, false)
                break
            end

            DisableControlAction(0, 23, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 38, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 172, true)
            DisableControlAction(0, 173, true)
            DisableControlAction(0, 174, true)
            DisableControlAction(0, 175, true)
            DisableControlAction(0, 14, true)
            DisableControlAction(0, 15, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)
            DisableControlAction(0, 36, true)

            if IsDisabledControlPressed(0, 44) then
                state.relativeRotation = state.relativeRotation + vector3(0.0, 0.0, Config.Mmi.rotationStep)
            elseif IsDisabledControlPressed(0, 38) then
                state.relativeRotation = state.relativeRotation - vector3(0.0, 0.0, Config.Mmi.rotationStep)
            end
            if IsDisabledControlPressed(0, 172) then
                state.relativeRotation = state.relativeRotation + vector3(Config.Mmi.rotationStep, 0.0, 0.0)
            elseif IsDisabledControlPressed(0, 173) then
                state.relativeRotation = state.relativeRotation - vector3(Config.Mmi.rotationStep, 0.0, 0.0)
            end
            if IsDisabledControlPressed(0, 174) then
                state.relativeRotation = state.relativeRotation + vector3(0.0, Config.Mmi.rotationStep, 0.0)
            elseif IsDisabledControlPressed(0, 175) then
                state.relativeRotation = state.relativeRotation - vector3(0.0, Config.Mmi.rotationStep, 0.0)
            end

            -- The ray chooses an initial location. After that the placement is
            -- vehicle-local, so looking around no longer drags the tablet.
            if not state.relativePosition then
                local _, hit, _, direction, physicalHit = cameraRaycast(vehicle, state.depth)
                local anchor = physicalHit and (hit - direction * 0.012) or hit
                state.relativePosition = GetOffsetFromEntityGivenWorldCoords(vehicle,
                    anchor.x, anchor.y, anchor.z)
            end

            local movement = Config.Mmi.movementSpeed * GetFrameTime()
            local x, y, z = state.relativePosition.x, state.relativePosition.y, state.relativePosition.z
            if IsDisabledControlPressed(0, 32) then y = y + movement end
            if IsDisabledControlPressed(0, 33) then y = y - movement end
            if IsDisabledControlPressed(0, 34) then x = x - movement end
            if IsDisabledControlPressed(0, 35) then x = x + movement end
            if IsDisabledControlPressed(0, 21) then z = z + movement end
            if IsDisabledControlPressed(0, 36) then z = z - movement end
            if IsDisabledControlPressed(0, 14) then y = y + Config.Mmi.depthStep end
            if IsDisabledControlPressed(0, 15) then y = y - Config.Mmi.depthStep end
            x = TorqueWorksMath.clamp(x, Config.Mmi.positionLimits.x[1], Config.Mmi.positionLimits.x[2])
            y = TorqueWorksMath.clamp(y, Config.Mmi.positionLimits.y[1], Config.Mmi.positionLimits.y[2])
            z = TorqueWorksMath.clamp(z, Config.Mmi.positionLimits.z[1], Config.Mmi.positionLimits.z[2])
            state.relativePosition = vector3(x, y, z)
            state.valid = true

            local position = GetOffsetFromEntityInWorldCoords(vehicle, x, y, z)
            SetEntityCoordsNoOffset(preview, position.x, position.y, position.z, false, false, false)
            local vehicleRotation = GetEntityRotation(vehicle, 2)
            SetEntityRotation(preview,
                vehicleRotation.x + state.relativeRotation.x,
                vehicleRotation.y + state.relativeRotation.y,
                vehicleRotation.z + state.relativeRotation.z, 2, true)
            applyScale(preview, Config.Mmi.scale)
            SetEntityAlpha(preview, 255, false)
            if state.camera then
                local cameraPosition = GetOffsetFromEntityInWorldCoords(vehicle, x, y - 0.62, z + 0.18)
                SetCamCoord(state.camera, cameraPosition.x, cameraPosition.y, cameraPosition.z)
                PointCamAtCoord(state.camera, position.x, position.y, position.z)
            end

            if IsControlJustReleased(0, 177) then
                endPlacement(state, false)
                break
            elseif IsControlJustReleased(0, 191) and state.valid and not state.saving then
                state.saving = true
                local result = lib.callback.await('coii_torqueworks:server:installMmi', false,
                    plateOf(vehicle), NetworkGetNetworkIdFromEntity(vehicle), {
                        position = {
                            x = state.relativePosition.x,
                            y = state.relativePosition.y,
                            z = state.relativePosition.z
                        },
                        rotation = {
                            x = state.relativeRotation.x,
                            y = state.relativeRotation.y,
                            z = state.relativeRotation.z
                        }
                    })
                if result and result.ok then
                    endPlacement(state, true)
                    break
                end
                state.saving = false
                TorqueWorksUI.notify({ type = 'error', description = result and result.error or 'MMI installation failed.' })
            end
            Wait(0)
        end
    end)
end

RegisterNetEvent('coii_torqueworks:client:beginMmiPlacement', beginPlacement)

local function createInstalledObject(vehicle, placement)
    if not loadModel(mmiProp) or not DoesEntityExist(vehicle) then return nil end
    local object = CreateObjectNoOffset(mmiProp, 0.0, 0.0, 0.0, false, false, false)
    SetEntityCollision(object, false, false)
    FreezeEntityPosition(object, true)
    SetModelAsNoLongerNeeded(mmiProp)
    return { entity = object, placement = placement }
end

function TorqueWorksMmi.updateInstalled(vehicle, installed)
    local object = installed and installed.entity
    if not object or not DoesEntityExist(object) or not DoesEntityExist(vehicle) then return false end
    local placement = installed.placement
    local localPosition, rotation = placement.position, placement.rotation
    local world = GetOffsetFromEntityInWorldCoords(vehicle,
        localPosition.x + 0.0, localPosition.y + 0.0, localPosition.z + 0.0)
    local vehicleRotation = GetEntityRotation(vehicle, 2)
    SetEntityCoordsNoOffset(object, world.x, world.y, world.z, false, false, false)
    SetEntityRotation(object,
        vehicleRotation.x + rotation.x,
        vehicleRotation.y + rotation.y,
        vehicleRotation.z + rotation.z, 2, true)
    applyScale(object, Config.Mmi.scale)
    return true
end

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local renderDistanceSq = Config.Mmi.renderDistance * Config.Mmi.renderDistance
        local seen = {}
        for _, vehicle in ipairs(GetGamePool('CVehicle')) do
            local coords = GetEntityCoords(vehicle)
            local dx, dy, dz = coords.x - playerCoords.x, coords.y - playerCoords.y, coords.z - playerCoords.z
            if dx * dx + dy * dy + dz * dz <= renderDistanceSq then
                local placement = Entity(vehicle).state.torqueworksMmi
                if type(placement) == 'table' and placement.position and placement.rotation then
                    seen[vehicle] = true
                    local installed = TorqueWorksMmi.objects[vehicle]
                    if not installed or not DoesEntityExist(installed.entity) then
                        TorqueWorksMmi.objects[vehicle] = createInstalledObject(vehicle, placement)
                    end
                end
            end
        end
        for vehicle, installed in pairs(TorqueWorksMmi.objects) do
            if not seen[vehicle] or not DoesEntityExist(vehicle) then
                deleteObject(installed and installed.entity)
                TorqueWorksMmi.objects[vehicle] = nil
            end
        end
        Wait(Config.Mmi.scanIntervalMs or 1000)
    end
end)

-- Attachment processing can normalize an object's matrix. Reassert the visual
-- scale only while at least one nearby installed MMI is actually being rendered.
CreateThread(function()
    while true do
        local active = false
        for vehicle, installed in pairs(TorqueWorksMmi.objects) do
            if TorqueWorksMmi.updateInstalled(vehicle, installed) then
                active = true
            end
        end
        Wait(active and (Config.Mmi.updateIntervalMs or 16) or 500)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if TorqueWorksMmi.placing then endPlacement(TorqueWorksMmi.placing, false) end
    for _, installed in pairs(TorqueWorksMmi.objects) do deleteObject(installed and installed.entity) end
    TorqueWorksMmi.objects = {}
end)
