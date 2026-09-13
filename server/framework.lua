TorqueWorksFramework = {}

local configured = type(Config.Framework) == 'string' and Config.Framework:lower() or 'auto'
local framework, core

local function started(resource)
    return GetResourceState(resource) == 'started'
end

if configured == 'auto' then
    if started('qbx_core') then framework = 'qbox'
    elseif started('qb-core') then framework = 'qbcore'
    elseif started('es_extended') then framework = 'esx' end
else
    framework = configured
end

if framework == 'esx' then
    core = exports.es_extended:getSharedObject()
elseif framework == 'qbcore' then
    core = exports['qb-core']:GetCoreObject()
elseif framework == 'qbox' then
    core = exports.qbx_core
else
    error(('[coii_torqueworks] No supported framework found (configured: %s).'):format(configured))
end

TorqueWorksFramework.name = framework

local function oxItemCount(source, itemName)
    if not started('ox_inventory') then return nil end
    local ok, count = pcall(function() return exports.ox_inventory:Search(source, 'count', itemName) end)
    return ok and tonumber(count) or nil
end

local function qbItemCount(player, itemName)
    local item = player.Functions and player.Functions.GetItemByName and player.Functions.GetItemByName(itemName)
    if item then return tonumber(item.amount or item.count) or 0 end
    for _, entry in pairs((player.PlayerData and player.PlayerData.items) or {}) do
        if entry and entry.name == itemName then return tonumber(entry.amount or entry.count) or 0 end
    end
    return 0
end

local function wrapQbPlayer(player, source)
    if not player then return nil end
    local data = player.PlayerData or {}
    local charinfo = data.charinfo or {}
    local job = data.job or {}
    local grade = type(job.grade) == 'table' and (job.grade.level or job.grade.grade) or job.grade
    local wrapper = {
        raw = player,
        identifier = data.citizenid or data.license,
        group = data.permission or 'user',
        job = { name = job.name, grade = tonumber(grade) or 0 },
        variables = {
            firstName = charinfo.firstname,
            lastName = charinfo.lastname,
            firstname = charinfo.firstname,
            lastname = charinfo.lastname
        }
    }
    wrapper.getIdentifier = function() return wrapper.identifier end
    wrapper.getGroup = function()
        if framework == 'qbcore' and core.Functions and core.Functions.HasPermission then
            for group in pairs((Config.MechanicAccess and Config.MechanicAccess.adminGroups) or {}) do
                if core.Functions.HasPermission(source, group) then return group end
            end
        elseif framework == 'qbox' then
            for group in pairs((Config.MechanicAccess and Config.MechanicAccess.adminGroups) or {}) do
                local ok, allowed = pcall(function() return core:HasGroup(source, group) end)
                if ok and allowed then return group end
            end
        end
        return wrapper.group
    end
    wrapper.getJob = function() return wrapper.job end
    wrapper.get = function(key) return wrapper.variables[key] end
    wrapper.getName = function()
        local name = (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        return name ~= '' and name or GetPlayerName(source)
    end
    wrapper.getInventoryItem = function(itemName)
        local count = oxItemCount(source, itemName)
        return { name = itemName, count = count ~= nil and count or qbItemCount(player, itemName) }
    end
    wrapper.removeInventoryItem = function(itemName, amount)
        if started('ox_inventory') then return exports.ox_inventory:RemoveItem(source, itemName, amount) end
        return player.Functions.RemoveItem(itemName, amount)
    end
    wrapper.addInventoryItem = function(itemName, amount)
        if started('ox_inventory') then return exports.ox_inventory:AddItem(source, itemName, amount) end
        return player.Functions.AddItem(itemName, amount)
    end
    wrapper.getMoney = function()
        if framework == 'qbox' then return tonumber(core:GetMoney(source, 'cash')) or 0 end
        return tonumber((player.PlayerData.money or {}).cash) or 0
    end
    wrapper.getAccount = function(account)
        if framework == 'qbox' then return { money = tonumber(core:GetMoney(source, account)) or 0 } end
        return { money = tonumber((player.PlayerData.money or {})[account]) or 0 }
    end
    wrapper.removeMoney = function(amount, reason)
        if framework == 'qbox' then return core:RemoveMoney(source, 'cash', amount, reason) end
        return player.Functions.RemoveMoney('cash', amount, reason)
    end
    wrapper.addMoney = function(amount, reason)
        if framework == 'qbox' then return core:AddMoney(source, 'cash', amount, reason) end
        return player.Functions.AddMoney('cash', amount, reason)
    end
    wrapper.removeAccountMoney = function(account, amount, reason)
        if framework == 'qbox' then return core:RemoveMoney(source, account, amount, reason) end
        return player.Functions.RemoveMoney(account, amount, reason)
    end
    wrapper.addAccountMoney = function(account, amount, reason)
        if framework == 'qbox' then return core:AddMoney(source, account, amount, reason) end
        return player.Functions.AddMoney(account, amount, reason)
    end
    return wrapper
end

function TorqueWorksFramework.GetPlayerFromId(source)
    if framework == 'esx' then return core.GetPlayerFromId(source) end
    local player
    if framework == 'qbcore' then player = core.Functions.GetPlayer(source)
    else
        local ok, result = pcall(function() return core:GetPlayer(source) end)
        if ok then player = result end
    end
    return wrapQbPlayer(player, source)
end

local function ownershipDefinition()
    local config = Config.VehicleOwnership
    local definition = type(config) == 'table' and config[framework] or nil
    if type(definition) ~= 'table' then return nil end
    for _, key in ipairs({ 'table', 'ownerColumn', 'plateColumn' }) do
        if type(definition[key]) ~= 'string' or not definition[key]:match('^[%w_]+$') then return nil end
    end
    return definition
end

function TorqueWorksFramework.GetVehicleOwnerIdentifier(plate)
    if type(plate) ~= 'string' or plate == '' then return nil end
    local definition = ownershipDefinition()
    if not definition then return nil end
    local query = ('SELECT `%s` AS owner FROM `%s` WHERE TRIM(UPPER(`%s`)) = ? LIMIT 1')
        :format(definition.ownerColumn, definition.table, definition.plateColumn)
    local ok, row = pcall(function() return MySQL.single.await(query, { plate:upper() }) end)
    if not ok or not row then return nil end
    return row.owner
end

function TorqueWorksFramework.IsVehicleOwned(plate)
    if Config.VehicleOwnership and Config.VehicleOwnership.required == false then return true end
    return TorqueWorksFramework.GetVehicleOwnerIdentifier(plate) ~= nil
end

function TorqueWorksFramework.RegisterUsableItem(itemName, callback)
    if framework == 'esx' then return core.RegisterUsableItem(itemName, callback) end
    if framework == 'qbcore' then return core.Functions.CreateUseableItem(itemName, callback) end
    local ok = pcall(function() core:CreateUseableItem(itemName, callback) end)
    if not ok then
        print(('[coii_torqueworks] Qbox could not register usable item %s; configure its ox_inventory server export.'):format(itemName))
    end
end

function TorqueWorksFramework.GetItemDefinition(itemName)
    if started('ox_inventory') then
        local ok, item = pcall(function() return exports.ox_inventory:Items(itemName) end)
        if ok and type(item) == 'table' then
            local image = item.client and item.client.image or (itemName .. '.png')
            if not image:match('^https?://') and not image:match('^nui://') and not image:match('^data:') then
                image = ('nui://ox_inventory/web/images/%s'):format(image)
            end
            return { label = item.label or itemName, image = image }
        end
    end
    if framework == 'qbcore' then
        local item = core.Shared and core.Shared.Items and core.Shared.Items[itemName]
        if item then
            local image = item.image or (itemName .. '.png')
            if not image:match('^https?://') and not image:match('^nui://') and not image:match('^data:') then
                image = ('nui://qb-inventory/html/images/%s'):format(image)
            end
            return { label = item.label or itemName, image = image }
        end
    end
end

local VERSION_API_URL = 'https://api.github.com/repos/coii/coii_torqueworks/releases/latest'

local function normalizedVersion(version)
    local parts = {}
    for number in tostring(version or ''):gsub('^[vV]', ''):gmatch('%d+') do
        parts[#parts + 1] = tonumber(number) or 0
        if #parts == 3 then break end
    end
    while #parts < 3 do parts[#parts + 1] = 0 end
    return parts
end

local function isNewerVersion(remote, installed)
    local remoteParts = normalizedVersion(remote)
    local installedParts = normalizedVersion(installed)
    for index = 1, 3 do
        if remoteParts[index] ~= installedParts[index] then
            return remoteParts[index] > installedParts[index]
        end
    end
    return false
end

local function printStartupBanner(installedVersion, latestVersion)
    local tuneCount = 0
    local ok, row = pcall(function()
        return MySQL.single.await('SELECT COUNT(*) AS total FROM coii_torqueworks')
    end)
    if ok and row then tuneCount = math.max(0, math.floor(tonumber(row.total) or 0)) end

    local width = 56
    local function centered(text)
        text = tostring(text or '')
        return string.rep(' ', math.max(0, math.floor((width - #text) / 2))) .. text
    end
    local function centeredPair(label, value, visibleValue)
        local text = label .. (visibleValue or value)
        local padding = string.rep(' ', math.max(0, math.floor((width - #text) / 2)))
        return ('%s^5%s^7%s'):format(padding, label, value)
    end

    local separator = '^5' .. string.rep('=', width) .. '^7'
    print(separator)
    print(('^5%s^7'):format(centered('coii_torqueworks')))
    print(('^7%s^7'):format(centered('(BETA)')))
    print(centeredPair('DISCORD: ', 'discord.gg/discord'))
    print(centeredPair('FRAMEWORK: ', framework:upper()))
    local versionStatus = ('v%s'):format(installedVersion)
    local visibleVersionStatus = versionStatus
    if latestVersion then
        local cleanLatestVersion = (latestVersion:gsub('^[vV]', ''))
        local updateAvailable = isNewerVersion(cleanLatestVersion, installedVersion)
        visibleVersionStatus = updateAvailable
            and ('%s (NEW UPDATE AVAILABLE: v%s)'):format(versionStatus, cleanLatestVersion)
            or ('%s (UP TO DATE)'):format(versionStatus)
        versionStatus = updateAvailable
            and ('%s ^1(NEW UPDATE AVAILABLE: v%s)^7'):format(versionStatus, cleanLatestVersion)
            or ('%s ^2(UP TO DATE)^7'):format(versionStatus)
    end
    print(centeredPair('VERSION: ', versionStatus, visibleVersionStatus))
    print(centeredPair('IMPORTED: ', ('%s TUNES'):format(tuneCount)))
    print(separator)
end

SetTimeout(60000, function()
    local installedVersion = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '0.0.0'
    PerformHttpRequest(VERSION_API_URL, function(status, body)
        local latestVersion
        if status == 200 and type(body) == 'string' then
            local decodedOk, release = pcall(json.decode, body)
            if decodedOk and type(release) == 'table' and type(release.tag_name) == 'string' then
                latestVersion = release.tag_name
            end
        end
        printStartupBanner(installedVersion, latestVersion)
    end, 'GET', '', {
        ['Accept'] = 'application/vnd.github+json',
        ['User-Agent'] = 'coii_torqueworks-version-check'
    })
end)
