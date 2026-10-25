local applied = {}
local running = true

local function plateOf(vehicle)
    return GetVehicleNumberPlateText(vehicle):upper():gsub('^%s+', ''):gsub('%s+$', '')
end

local function sameEntity(vehicle, entry)
    return DoesEntityExist(vehicle) and NetworkGetEntityIsNetworked(vehicle) and
        GetEntityModel(vehicle) == entry.model and NetworkGetNetworkIdFromEntity(vehicle) == entry.networkId and
        plateOf(vehicle) == entry.plate
end

local function restore(vehicle, entry)
    if not sameEntity(vehicle, entry) then return end
    if entry.audio then ForceVehicleEngineAudio(vehicle, entry.factoryAudio) end
    if TorqueWorksBackfire then TorqueWorksBackfire.setStockSuppressed(vehicle, false) end
end

local function refresh(vehicle)
    if not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 or
        not NetworkGetEntityIsNetworked(vehicle) then return end
    local state = Entity(vehicle).state
    local effects = state.torqueworksEffects
    local entry = applied[vehicle]
    if entry and not sameEntity(vehicle, entry) then
        applied[vehicle], entry = nil, nil
    end
    if type(effects) == 'table' and effects.plate == plateOf(vehicle) and
        Config.Parts.engine[effects.engine] and Config.Parts.fuelpump[effects.fuelpump] then
        if not entry then
            local model = GetEntityModel(vehicle)
            local display = GetDisplayNameFromVehicleModel(model)
            entry = { model = model, networkId = NetworkGetNetworkIdFromEntity(vehicle),
                plate = effects.plate, factoryAudio = type(display) == 'string' and display:lower() or '' }
            applied[vehicle] = entry
        end
        local audio = Config.Parts.engine[effects.engine].audioName
        audio = type(audio) == 'string' and audio ~= '' and audio or nil
        local driver = GetPedInVehicleSeat(vehicle, -1)
        if audio ~= entry.audio or (audio and driver ~= entry.driver) then
            ForceVehicleEngineAudio(vehicle, audio or entry.factoryAudio)
            entry.audio = audio
        end
        entry.driver = driver
        if TorqueWorksBackfire then
            TorqueWorksBackfire.setStockSuppressed(vehicle, effects.fuelpump ~= Config.FactoryBuild.fuelpump)
        end
    elseif entry then
        restore(vehicle, entry)
        applied[vehicle] = nil
    end
    if TorqueWorksNitro and TorqueWorksNitro.syncRemote then
        TorqueWorksNitro.syncRemote(vehicle, state.torqueworksNitro)
    end
end

-- State changes handle live upgrades; the scan also catches stream-in and resource restarts.
for _, key in ipairs({ 'torqueworksEffects', 'torqueworksNitro' }) do
    AddStateBagChangeHandler(key, nil, function(bagName)
        SetTimeout(0, function()
            if not running then return end
            local vehicle = GetEntityFromStateBagName(bagName)
            if vehicle ~= 0 then refresh(vehicle) end
        end)
    end)
end

CreateThread(function()
    while running do
        for _, vehicle in ipairs(GetGamePool('CVehicle')) do refresh(vehicle) end
        for vehicle, entry in pairs(applied) do
            if not sameEntity(vehicle, entry) then applied[vehicle] = nil end
        end
        if TorqueWorksNitro and TorqueWorksNitro.pruneRemote then TorqueWorksNitro.pruneRemote() end
        Wait(500)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    running = false
    for vehicle, entry in pairs(applied) do restore(vehicle, entry) end
    applied = {}
end)
