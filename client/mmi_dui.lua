local mmiDui
local nextUpdate = 0
local runtimeTxdName = 'coii_mmi_runtime'
local runtimeTxnName = 'screen'
local interaction
local mmiThemePending = true

local function createScreen()
    if mmiDui then return true end
    if not Config.Mmi.dui.enabled then return false end
    local url = ('https://cfx-nui-%s/web/mmi.html?v=0.8.1'):format(GetCurrentResourceName())
    mmiDui = CreateDui(url, Config.Mmi.dui.width, Config.Mmi.dui.height)
    mmiThemePending = true
    local deadline = GetGameTimer() + 5000
    while not IsDuiAvailable(mmiDui) and GetGameTimer() < deadline do Wait(25) end
    if not IsDuiAvailable(mmiDui) then
        DestroyDui(mmiDui)
        mmiDui = nil
        return false
    end
    local txd = CreateRuntimeTxd(runtimeTxdName)
    CreateRuntimeTextureFromDuiHandle(txd, runtimeTxnName, GetDuiHandle(mmiDui))
    return true
end

local function destroyScreen()
    if mmiDui then DestroyDui(mmiDui) end
    mmiDui = nil
end

local function sendTelemetry(active)
    local telemetry = TorqueWorks.telemetry or {}
    local nitro = TorqueWorksNitro and TorqueWorksNitro.level or active.build.nitroLevel or 0.0
    local displayKey = GetDisplayNameFromVehicleModel(GetEntityModel(active.vehicle))
    local localizedName = displayKey and GetLabelText(displayKey) or nil
    local vehicleName = localizedName and localizedName ~= 'NULL' and localizedName or displayKey or 'VEHICLE'
    SendDuiMessage(mmiDui, json.encode({
        action = 'telemetry', plate = active.plate, buildName = active.build.buildName,
        theme = mmiThemePending and (Config.UITheme or {}) or nil,
        vehicleName = vehicleName,
        map = telemetry.mapLabel or active.ecuMap.label,
        rpm = math.floor((telemetry.rpm or 0.0) * 10000.0 + 0.5),
        gear = telemetry.gear or GetVehicleCurrentGear(active.vehicle),
        speed = telemetry.speed or GetEntitySpeed(active.vehicle) * 3.6,
        boost = telemetry.currentBoost or 0.0, nitro = nitro,
        brakeTemperature = telemetry.brakeTemperature or 0.0,
        settings = {
            ecuMap = active.build.ecuMap,
            transmission = active.build.transmissionPersonality,
            pressure = active.build.tirePressure,
            split = active.build.frontTorqueBias,
            differential = active.build.differential,
            autoRefill = TorqueWorksNitro and TorqueWorksNitro.autoRefillEnabled ~= false
        }
    }))
    mmiThemePending = false
end

local function vertex(object, x, y, z)
    return GetOffsetFromEntityInWorldCoords(object, x, y, z)
end

local function drawTriangle(a, b, c, au, av, bu, bv, cu, cv)
    DrawSpritePoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z,
        255, 255, 255, 255, runtimeTxdName, runtimeTxnName,
        au, av, 1.0, bu, bv, 1.0, cu, cv, 1.0)
end

local function drawTabletScreen(object)
    local screen = Config.Mmi.dui.screen
    local halfWidth, halfHeight = screen.width * 0.5, screen.height * 0.5
    local left, right = screen.x - halfWidth, screen.x + halfWidth
    local top, bottom = screen.z + halfHeight, screen.z - halfHeight
    local tl = vertex(object, left, screen.y, top)
    local tr = vertex(object, right, screen.y, top)
    local br = vertex(object, right, screen.y, bottom)
    local bl = vertex(object, left, screen.y, bottom)
    local rotations = {
        [0] = { { 0.0, 0.0 }, { 1.0, 0.0 }, { 1.0, 1.0 }, { 0.0, 1.0 } },
        [90] = { { 0.0, 1.0 }, { 0.0, 0.0 }, { 1.0, 0.0 }, { 1.0, 1.0 } },
        [180] = { { 1.0, 1.0 }, { 0.0, 1.0 }, { 0.0, 0.0 }, { 1.0, 0.0 } },
        [270] = { { 1.0, 0.0 }, { 1.0, 1.0 }, { 0.0, 1.0 }, { 0.0, 0.0 } }
    }
    local uv = rotations[math.floor(tonumber(screen.rotation) or 0) % 360] or rotations[0]
    drawTriangle(tl, tr, br, uv[1][1], uv[1][2], uv[2][1], uv[2][2], uv[3][1], uv[3][2])
    drawTriangle(tl, br, bl, uv[1][1], uv[1][2], uv[3][1], uv[3][2], uv[4][1], uv[4][2])
    -- Keep the display visible if a placed tablet was rotated to expose the
    -- opposite face; triangle winding is culled by the world renderer.
    drawTriangle(br, tr, tl, uv[3][1], uv[3][2], uv[2][1], uv[2][2], uv[1][1], uv[1][2])
    drawTriangle(bl, br, tl, uv[4][1], uv[4][2], uv[3][1], uv[3][2], uv[1][1], uv[1][2])
end

local function projectedScreenCorners(object)
    local screen = Config.Mmi.dui.screen
    local halfWidth, halfHeight = screen.width * 0.5, screen.height * 0.5
    local corners = {
        vertex(object, screen.x - halfWidth, screen.y, screen.z + halfHeight),
        vertex(object, screen.x + halfWidth, screen.y, screen.z + halfHeight),
        vertex(object, screen.x + halfWidth, screen.y, screen.z - halfHeight),
        vertex(object, screen.x - halfWidth, screen.y, screen.z - halfHeight)
    }
    local projected = {}
    for index, corner in ipairs(corners) do
        local visible, x, y = GetScreenCoordFromWorldCoord(corner.x, corner.y, corner.z)
        if not visible then return nil end
        projected[index] = { x = x, y = y }
    end
    return projected
end

local function triangleUv(px, py, a, b, c, au, av, bu, bv, cu, cv)
    local denominator = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
    if math.abs(denominator) < 0.000001 then return nil end
    local wa = ((b.y - c.y) * (px - c.x) + (c.x - b.x) * (py - c.y)) / denominator
    local wb = ((c.y - a.y) * (px - c.x) + (a.x - c.x) * (py - c.y)) / denominator
    local wc = 1.0 - wa - wb
    if wa < -0.001 or wb < -0.001 or wc < -0.001 then return nil end
    return wa * au + wb * bu + wc * cu, wa * av + wb * bv + wc * cv
end

local function screenPointToDui(normalizedX, normalizedY, corners)
    local tl, tr, br, bl = corners[1], corners[2], corners[3], corners[4]
    local u, v = triangleUv(normalizedX, normalizedY, tl, tr, br,
        0.0, 0.0, 1.0, 0.0, 1.0, 1.0)
    if not u then
        u, v = triangleUv(normalizedX, normalizedY, tl, br, bl,
            0.0, 0.0, 1.0, 1.0, 0.0, 1.0)
    end
    if not u then return nil end
    local rotation = math.floor(tonumber(Config.Mmi.dui.screen.rotation) or 0) % 360

    -- Keep pointer coordinates aligned with drawTabletScreen's rotated UVs.
    if rotation == 90 then
        u, v = v, 1.0 - u
    elseif rotation == 180 then
        u, v = 1.0 - u, 1.0 - v
    elseif rotation == 270 then
        u, v = 1.0 - v, u
    end

    return math.floor(u * (Config.Mmi.dui.width - 1)),
        math.floor(v * (Config.Mmi.dui.height - 1))
end

local function closeInteraction()
    local state = interaction
    if not state then return end
    interaction = nil
    SendNUIMessage({ action = 'mmiInteraction', active = false })
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    if state.camera then
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(state.camera, false)
    end
    if DoesEntityExist(state.vehicle) and not state.wasFrozen then FreezeEntityPosition(state.vehicle, false) end
end

local function openInteraction()
    if interaction then closeInteraction() return end
    local active = TorqueWorks.active
    local installed = active and TorqueWorksMmi and TorqueWorksMmi.objects[active.vehicle]
    local object = installed and installed.entity
    if not object or not DoesEntityExist(object) then return end
    if GetPedInVehicleSeat(active.vehicle, -1) ~= PlayerPedId() or
        GetEntitySpeed(active.vehicle) > Config.Mmi.interactionMaxSpeed then
        TorqueWorksUI.notify({ type = 'error', description = 'Stop the vehicle before using the MMI.' })
        return
    end
    if not createScreen() then return end
    TorqueWorksMmi.updateInstalled(active.vehicle, installed)
    local center = GetEntityCoords(object)
    local gameplay = GetGameplayCamCoord()
    local direction = gameplay - center
    local length = math.sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
    if length < 0.01 then direction, length = vector3(0.0, -1.0, 0.0), 1.0 end
    local cameraPosition = center + direction * (0.42 / length)
    local camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(camera, cameraPosition.x, cameraPosition.y, cameraPosition.z)
    PointCamAtEntity(camera, object, 0.0, 0.0, 0.0, true)
    SetCamFov(camera, 32.0)
    SetCamActive(camera, true)
    RenderScriptCams(true, true, 250, true, true)
    interaction = { vehicle = active.vehicle, object = object, camera = camera,
        wasFrozen = IsEntityPositionFrozen(active.vehicle) }
    FreezeEntityPosition(active.vehicle, true)
    SendNUIMessage({ action = 'mmiInteraction', active = true })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
end

RegisterCommand('+torqueworks_mmi', openInteraction, false)
RegisterCommand('-torqueworks_mmi', function() end, false)
RegisterKeyMapping('+torqueworks_mmi', 'Open installed TorqueWorks MMI', 'keyboard', Config.Mmi.interactionKey)

RegisterNUICallback('mmiClose', function(_, callback)
    closeInteraction()
    callback({ ok = true })
end)

RegisterNUICallback('mmiPointer', function(data, callback)
    if interaction and mmiDui and type(data) == 'table' then
        if data.pressed == true and interaction.cursorInside then
            SendDuiMouseDown(mmiDui, 'left')
        else
            SendDuiMouseUp(mmiDui, 'left')
        end
    end
    callback({ ok = true })
end)

RegisterNUICallback('mmiKey', function(data, callback)
    if interaction and mmiDui and type(data) == 'table' and type(data.key) == 'string' then
        local allowed = { ArrowUp = true, ArrowDown = true, ArrowLeft = true,
            ArrowRight = true, Enter = true }
        if allowed[data.key] then
            SendDuiMessage(mmiDui, json.encode({ action = 'keyboard', key = data.key }))
        end
    end
    callback({ ok = true })
end)

RegisterNUICallback('mmiAction', function(data, callback)
    if not interaction or type(data) ~= 'table' then callback({ ok = false }) return end
    local allowed = { pressure = true, split = true }
    if allowed[data.action] then
        local active = TorqueWorks.active
        TriggerServerEvent('coii_torqueworks:server:setMmiSetting', data.action, data.value,
            active.plate, active.networkId)
        callback({ ok = true })
        return
    elseif data.action == 'autoRefill' then
        TorqueWorksNitro.autoRefillEnabled = data.value == true
        TriggerServerEvent('coii_torqueworks:server:setAutoRefillPreference', TorqueWorksNitro.autoRefillEnabled)
        callback({ ok = true })
        return
    end
    callback({ ok = false })
end)

CreateThread(function()
    while true do
        local state = interaction
        if state then
            if not DoesEntityExist(state.vehicle) or not DoesEntityExist(state.object) or
                GetVehiclePedIsIn(PlayerPedId(), false) ~= state.vehicle then
                closeInteraction()
            else
                TorqueWorksMmi.updateInstalled(state.vehicle, TorqueWorksMmi.objects[state.vehicle])
                local center = GetEntityCoords(state.object)
                PointCamAtCoord(state.camera, center.x, center.y, center.z)
                local screenX, screenY = GetActualScreenResolution()
                local cursorX, cursorY = GetNuiCursorPosition()
                local corners = projectedScreenCorners(state.object)
                local normalizedX, normalizedY = cursorX / math.max(screenX, 1), cursorY / math.max(screenY, 1)
                local duiX, duiY = corners and screenPointToDui(normalizedX, normalizedY, corners)
                state.cursorInside = duiX ~= nil
                if duiX then
                    SendDuiMouseMove(mmiDui, duiX, duiY)
                end
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 200, true)
                DisableControlAction(0, 168, true)
                if IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 168) then
                    closeInteraction()
                end
            end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

CreateThread(function()
    while true do
        local active = TorqueWorks.active
        local installed = active and TorqueWorksMmi and TorqueWorksMmi.objects[active.vehicle]
        local object = installed and installed.entity
        if object and DoesEntityExist(object) and createScreen() then
            -- Synchronize the prop and its screen in this render pass. Reading
            -- an object transform updated by another thread caused a one-frame
            -- separation that became obvious while the vehicle was moving.
            TorqueWorksMmi.updateInstalled(active.vehicle, installed)
            local now = GetGameTimer()
            if now >= nextUpdate then
                nextUpdate = now + Config.Mmi.dui.refreshMs
                sendTelemetry(active)
            end
            drawTabletScreen(object)
            Wait(0)
        else
            if mmiDui then destroyScreen() end
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        closeInteraction()
        destroyScreen()
    end
end)
