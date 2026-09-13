TorqueWorksNitro = {
    active = false,
    vehicle = 0,
    particles = {},
    cooldownUntil = 0,
    lastShiftBurst = 0,
    held = false,
    holdMode = false,
    starting = false,
    level = 0.0,
    cooldownToken = 0,
    autoRefillEnabled = true
}

local function callNative(native, ...)
    if type(native) == 'function' then pcall(native, ...) end
end

local nitroLightTrails = {}

function CreateVehicleLightTrail(vehicle, bone, scale, r, g, b)
    if bone == -1 then return nil end
    RequestNamedPtfxAsset('core')
    local deadline = GetGameTimer() + 1500
    while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < deadline do Wait(0) end
    if not HasNamedPtfxAssetLoaded('core') then return nil end
    UseParticleFxAssetNextCall('core')
    local handle = StartParticleFxLoopedOnEntityBone('veh_light_red_trail', vehicle,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bone, scale,
        false, false, false)
    if not handle or handle == 0 then return nil end
    SetParticleFxLoopedEvolution(handle, 'speed', 1.0, false)
    SetParticleFxLoopedColour(handle,
        TorqueWorksMath.clamp((tonumber(r) or 255) / 255.0, 0.0, 1.0),
        TorqueWorksMath.clamp((tonumber(g) or 0) / 255.0, 0.0, 1.0),
        TorqueWorksMath.clamp((tonumber(b) or 0) / 255.0, 0.0, 1.0), false)
    return handle
end

function StopVehicleLightTrail(handle, duration)
    if not handle or handle == 0 then return end
    CreateThread(function()
        duration = math.max(1, tonumber(duration) or 500)
        local endsAt = GetGameTimer() + duration
        while GetGameTimer() < endsAt do
            local alpha = TorqueWorksMath.clamp((endsAt - GetGameTimer()) / duration, 0.0, 1.0)
            SetParticleFxLoopedScale(handle, alpha)
            SetParticleFxLoopedAlpha(handle, alpha)
            Wait(0)
        end
        StopParticleFxLooped(handle, false)
    end)
end

function SetVehicleNitroLightTrail(vehicle, enabled, r, g, b)
    if not DoesEntityExist(vehicle) then return false end
    if enabled then
        if nitroLightTrails[vehicle] then return true end
        if type(CreateVehicleLightTrail) ~= 'function' then return false end
        local color = Config.Nitro.taillightTrailColor
        r = tonumber(r) or color.r or 255
        g = tonumber(g) or color.g or 255
        b = tonumber(b) or color.b or 255
        local trails = {}
        local left = GetEntityBoneIndexByName(vehicle, 'taillight_l')
        local right = GetEntityBoneIndexByName(vehicle, 'taillight_r')
        if left ~= -1 then
            local ok, handle = pcall(CreateVehicleLightTrail, vehicle, left,
                Config.Nitro.taillightTrailScale, r, g, b)
            if ok and handle and handle ~= 0 then trails.left = handle end
        end
        if right ~= -1 then
            local ok, handle = pcall(CreateVehicleLightTrail, vehicle, right,
                Config.Nitro.taillightTrailScale, r, g, b)
            if ok and handle and handle ~= 0 then trails.right = handle end
        end
        if trails.left or trails.right then
            nitroLightTrails[vehicle] = trails
            return true
        end
        return false
    end

    local trails = nitroLightTrails[vehicle]
    if not trails then return true end
    if type(StopVehicleLightTrail) == 'function' then
        if trails.left then pcall(StopVehicleLightTrail, trails.left, 500) end
        if trails.right then pcall(StopVehicleLightTrail, trails.right, 500) end
    end
    nitroLightTrails[vehicle] = nil
    return true
end

local function setNativeNitro(vehicle, enabled, nitro)
    local power = enabled and nitro and nitro.powerMultiplier or 0.0
    callNative(SetVehicleBoostActive, vehicle, enabled)
    callNative(SetVehicleRocketBoostActive, vehicle, enabled)
    callNative(SetNitrousIsActive, vehicle, enabled)
    -- Cfx nitro extension: vehicle, enabled, level, power, recharge time, mute.
    callNative(SetVehicleNitroEnabled, vehicle, enabled, enabled and 1.0 or 0.0,
        power, 0.0, false)
end

local function stopNitro(showDelayHud)
    if showDelayHud == nil then showDelayHud = true end
    local wasActive = TorqueWorksNitro.active
    local vehicle = TorqueWorksNitro.vehicle
    if vehicle ~= 0 and DoesEntityExist(vehicle) then setNativeNitro(vehicle, false, nil) end
    if vehicle ~= 0 then SetVehicleNitroLightTrail(vehicle, false) end
    for _, handle in ipairs(TorqueWorksNitro.particles) do
        if handle and handle ~= 0 then StopParticleFxLooped(handle, false) end
    end
    TorqueWorksNitro.particles = {}
    TorqueWorksNitro.active = false
    TorqueWorksNitro.vehicle = 0
    TorqueWorks.nitro = nil
    if wasActive then
        TorqueWorksNitro.cooldownUntil = GetGameTimer() + Config.Nitro.reuseDelayMs
        TriggerServerEvent('coii_torqueworks:server:stopNitro')
        StopGameplayCamShaking(true)
        SendNUIMessage({ action = 'nitroSound', enabled = false })
        TorqueWorksNitro.cooldownToken = TorqueWorksNitro.cooldownToken + 1
        local token = TorqueWorksNitro.cooldownToken
        if showDelayHud then
            local reuseEndsAt = TorqueWorksNitro.cooldownUntil
            local autoRefillEndsAt = reuseEndsAt +
                (TorqueWorksNitro.autoRefillEnabled and Config.Nitro.autoRefillDelayMs or 0)
            CreateThread(function()
                while token == TorqueWorksNitro.cooldownToken do
                    local now = GetGameTimer()
                    local reusing = now < reuseEndsAt
                    local remaining = (reusing and reuseEndsAt or autoRefillEndsAt) - now
                    if remaining <= 0 then break end
                    SendNUIMessage({
                        action = 'nitroHud', visible = true, level = TorqueWorksNitro.level,
                        cooldown = remaining / 1000.0,
                        delayLabel = reusing and 'READY IN' or 'AUTO REFILL'
                    })
                    Wait(50)
                end
                if token == TorqueWorksNitro.cooldownToken then
                    SendNUIMessage({ action = 'nitroHud', visible = false })
                end
            end)
        else
            SendNUIMessage({ action = 'nitroHud', visible = false })
        end
    end
end

TorqueWorksNitro.stop = stopNitro

function TorqueWorksNitro.deactivate(showDelayHud)
    if TorqueWorksNitro.active then stopNitro(showDelayHud) end
end

local function loadParticleDictionary(dictionary)
    RequestNamedPtfxAsset(dictionary)
    local deadline = GetGameTimer() + Config.Nitro.particleLoadTimeoutMs
    while not HasNamedPtfxAssetLoaded(dictionary) and GetGameTimer() < deadline do Wait(25) end
    return HasNamedPtfxAssetLoaded(dictionary)
end

local function startParticles(vehicle, destination, scale)
    local config = Config.Nitro
    if not loadParticleDictionary(config.particleDictionary) then return false end
    destination = destination or TorqueWorksNitro.particles
    local started = false
    for _, boneName in ipairs(config.exhaustBones) do
        local bone = GetEntityBoneIndexByName(vehicle, boneName)
        if bone and bone ~= -1 then
            UseParticleFxAssetNextCall(config.particleDictionary)
            local handle = StartParticleFxLoopedOnEntityBone(config.particleName, vehicle,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bone, scale or config.particleScale,
                false, false, false)
            if handle and handle ~= 0 then
                local color = config.particleColor
                if type(color) == 'table' then
                    callNative(SetParticleFxLoopedColour, handle,
                        TorqueWorksMath.clamp((tonumber(color.r) or 255) / 255.0, 0.0, 1.0),
                        TorqueWorksMath.clamp((tonumber(color.g) or 255) / 255.0, 0.0, 1.0),
                        TorqueWorksMath.clamp((tonumber(color.b) or 255) / 255.0, 0.0, 1.0), false)
                    callNative(SetParticleFxLoopedAlpha, handle,
                        TorqueWorksMath.clamp(tonumber(color.alpha) or 1.0, 0.0, 1.0))
                end
                destination[#destination + 1] = handle
                started = true
            end
        end
    end
    RemoveNamedPtfxAsset(config.particleDictionary)
    return started
end

function TorqueWorksNitro.shiftBurst(vehicle)
    local config = Config.Nitro
    if not config.shiftBurstEnabled or not DoesEntityExist(vehicle) then return end
    local now = GetGameTimer()
    if now - TorqueWorksNitro.lastShiftBurst < config.shiftBurstCooldownMs then return end
    TorqueWorksNitro.lastShiftBurst = now
    CreateThread(function()
        local handles = {}
        if not startParticles(vehicle, handles, config.shiftBurstScale) then return end
        Wait(config.shiftBurstDurationMs)
        for _, handle in ipairs(handles) do
            if handle and handle ~= 0 then StopParticleFxLooped(handle, false) end
        end
    end)
end

function TorqueWorksNitro.activate()
    if TorqueWorksNitro.active or TorqueWorksNitro.starting then return end
    local now = GetGameTimer()
    if now < TorqueWorksNitro.cooldownUntil then
        return
    end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return
    end
    if not TorqueWorks.active or TorqueWorks.active.vehicle ~= vehicle then
        return
    end

    local nitro = TorqueWorks.active.parts and TorqueWorks.active.parts.nitro
    if not nitro or not nitro.enabled then
        return
    end
    local plate = GetVehicleNumberPlateText(vehicle):upper():gsub('^%s+', ''):gsub('%s+$', '')
    TorqueWorksNitro.starting = true
    local initialLevel = lib.callback.await('coii_torqueworks:server:startNitro', false,
        plate, NetworkGetNetworkIdFromEntity(vehicle))
    TorqueWorksNitro.starting = false
    if type(initialLevel) ~= 'number' or initialLevel < 0 then return end
    if initialLevel <= 0.001 then
        TorqueWorksUI.notify({ type = 'error', description = 'The nitrous bottle is empty. Use a nos_bottle to refill it.' })
        return
    end
    if TorqueWorksNitro.holdMode and not TorqueWorksNitro.held then
        TriggerServerEvent('coii_torqueworks:server:stopNitro')
        return
    end

    now = GetGameTimer()
    stopNitro()
    TorqueWorksNitro.active = true
    TorqueWorksNitro.vehicle = vehicle
    TorqueWorksNitro.level = initialLevel
    TorqueWorksNitro.cooldownToken = TorqueWorksNitro.cooldownToken + 1
    local availableDuration = nitro.durationMs * initialLevel
    TorqueWorksNitro.cooldownUntil = 0
    TorqueWorks.nitro = {
        vehicle = vehicle,
        expiresAt = now + availableDuration,
        powerMultiplier = nitro.powerMultiplier
    }
    setNativeNitro(vehicle, true, nitro)
    ShakeGameplayCam('ROAD_VIBRATION_SHAKE', Config.Nitro.cameraShake)
    SendNUIMessage({ action = 'nitroSound', enabled = true,
        volume = Config.Nitro.soundVolume })
    SetVehicleNitroLightTrail(vehicle, true)
    local particleStarted = startParticles(vehicle, TorqueWorksNitro.particles, nitro.particleScale)
    SendNUIMessage({ action = 'nitroHud', visible = true, level = initialLevel, label = nitro.label })
    TorqueWorksUI.notify({
        type = particleStarted and 'success' or 'inform',
        description = particleStarted and ('%s activated.'):format(nitro.label) or
            'Nitrous boost activated; veh_nitrous could not attach to this vehicle exhaust.'
    })

    CreateThread(function()
        local expiresAt = TorqueWorks.nitro and TorqueWorks.nitro.expiresAt or now
        while TorqueWorksNitro.active and GetGameTimer() < expiresAt do
            if not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then break end
            local remaining = math.max(0, expiresAt - GetGameTimer())
            TorqueWorksNitro.level = TorqueWorksMath.clamp(
                initialLevel - ((availableDuration - remaining) / math.max(1, nitro.durationMs)), 0.0, 1.0)
            SendNUIMessage({
                action = 'nitroHud', visible = true,
                level = TorqueWorksNitro.level,
                cooldown = 0,
                label = nitro.label
            })
            Wait(75)
        end
        if TorqueWorksNitro.vehicle == vehicle then
            local stillDriving = DoesEntityExist(vehicle) and
                GetPedInVehicleSeat(vehicle, -1) == PlayerPedId()
            stopNitro(stillDriving)
        end
    end)
end

function TorqueWorksNitro.press()
    if TorqueWorksNitro.held then return end
    TorqueWorksNitro.held = true
    TorqueWorksNitro.holdMode = true
    TorqueWorksNitro.activate()
end

function TorqueWorksNitro.release()
    TorqueWorksNitro.held = false
    TorqueWorksNitro.deactivate()
end

RegisterNetEvent('coii_torqueworks:client:nitroLevel', function(level)
    TorqueWorksNitro.level = TorqueWorksMath.clamp(tonumber(level) or 0.0, 0.0, 1.0)
    if TorqueWorksNitro.level >= 0.999 and not TorqueWorksNitro.active then
        TorqueWorksNitro.cooldownToken = TorqueWorksNitro.cooldownToken + 1
        TorqueWorksNitro.cooldownUntil = 0
        SendNUIMessage({ action = 'nitroHud', visible = false })
    end
    if TorqueWorks.active and TorqueWorks.active.build then
        TorqueWorks.active.build.nitroLevel = TorqueWorksMath.clamp(tonumber(level) or 0.0, 0.0, 1.0)
    end
end)

RegisterNetEvent('coii_torqueworks:client:nitroTrailSync', function(networkId, enabled, color)
    networkId = tonumber(networkId)
    if not networkId then return end
    CreateThread(function()
        local deadline = GetGameTimer() + 2000
        local vehicle = NetToVeh(networkId)
        while enabled and vehicle == 0 and GetGameTimer() < deadline do
            Wait(50)
            vehicle = NetToVeh(networkId)
        end
        if vehicle == 0 or not DoesEntityExist(vehicle) then return end
        color = type(color) == 'table' and color or Config.Nitro.taillightTrailColor
        SetVehicleNitroLightTrail(vehicle, enabled == true, color.r, color.g, color.b)
    end)
end)

local refillInProgress = false
local refillToken = 0
RegisterNetEvent('coii_torqueworks:client:beginNitroRefill', function(options)
    options = type(options) == 'table' and options or {}
    if refillInProgress then return end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        TorqueWorksUI.notify({ type = 'error', description = 'You must be driving the vehicle you want to refill.' })
        return
    end
    local plate = GetVehicleNumberPlateText(vehicle):upper():gsub('^%s+', ''):gsub('%s+$', '')
    if options.automatic and options.plate ~= plate then return end
    if TorqueWorksNitro.active then
        TorqueWorksUI.notify({ type = 'error', description = 'Stop nitrous before replacing the bottle.' })
        return
    end
    refillInProgress = true
    refillToken = refillToken + 1
    local token = refillToken
    CreateThread(function()
        while refillInProgress and refillToken == token do
            if not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= ped then
                pcall(lib.cancelProgress)
                break
            end
            Wait(100)
        end
    end)
    local completed = TorqueWorksUI.progress('bar', {
        duration = Config.Nitro.refillDurationMs,
        label = options.automatic and 'Nitro auto-refill' or 'Installing nitrous bottle',
        canCancel = false,
        useWhileDead = false,
        disable = {}
    })
    if refillToken == token then refillInProgress = false end
    if not completed or not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end
    TriggerServerEvent('coii_torqueworks:server:refillNitro', plate,
        NetworkGetNetworkIdFromEntity(vehicle), options.automatic == true)
end)

RegisterNUICallback('nitroAutoRefillPreference', function(data, callback)
    TorqueWorksNitro.autoRefillEnabled = type(data) == 'table' and data.enabled == true
    TriggerServerEvent('coii_torqueworks:server:setAutoRefillPreference',
        TorqueWorksNitro.autoRefillEnabled)
    if not TorqueWorksNitro.autoRefillEnabled and not TorqueWorksNitro.active then
        TorqueWorksNitro.cooldownToken = TorqueWorksNitro.cooldownToken + 1
        SendNUIMessage({ action = 'nitroHud', visible = false, immediate = true })
    end
    callback({ ok = true })
end)

AddEventHandler('baseevents:leftVehicle', function()
    TorqueWorksNitro.held = false
    TorqueWorksNitro.starting = false
    TorqueWorksNitro.deactivate(false)
    TorqueWorksNitro.cooldownToken = TorqueWorksNitro.cooldownToken + 1
    SendNUIMessage({ action = 'nitroHud', visible = false, immediate = true })
    TriggerServerEvent('coii_torqueworks:server:cancelAutoRefill')
    if refillInProgress then
        refillInProgress = false
        refillToken = refillToken + 1
        pcall(lib.cancelProgress)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        stopNitro(false)
        for vehicle in pairs(nitroLightTrails) do SetVehicleNitroLightTrail(vehicle, false) end
        SendNUIMessage({ action = 'nitroSound', enabled = false })
    end
end)
