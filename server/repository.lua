TorqueWorksRepository = {}
local buildCache = {}
local mmiCache = {}

local function cacheDuration()
    return math.max(1000, tonumber(Config.ServerCacheMs) or 15000)
end

local function cachedBuild(plate)
    local entry = buildCache[plate]
    if not entry or entry.expiresAt <= GetGameTimer() then
        buildCache[plate] = nil
        return nil
    end
    return {
        plate = entry.plate,
        model = entry.model,
        factory_seed = entry.factory_seed,
        build = entry.build
    }
end

local function rememberBuild(row)
    if not row then return nil end
    buildCache[row.plate] = {
        plate = row.plate,
        model = row.model,
        factory_seed = row.factory_seed,
        build = row.build,
        expiresAt = GetGameTimer() + cacheDuration()
    }
    return row
end

CreateThread(function()
    while true do
        Wait(60000)
        local now = GetGameTimer()
        for plate, entry in pairs(buildCache) do
            if entry.expiresAt <= now then buildCache[plate] = nil end
        end
        for plate, entry in pairs(mmiCache) do
            if entry.expiresAt <= now then mmiCache[plate] = nil end
        end
    end
end)

local function decodeBuild(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return {} end
    local ok, decoded = pcall(json.decode, value)
    return ok and type(decoded) == 'table' and decoded or {}
end

function TorqueWorksRepository.getOrCreate(plate, model)
    local cached = cachedBuild(plate)
    if cached then return cached end
    local seed = math.random(1, 2147483646)
    MySQL.insert.await([[
        INSERT IGNORE INTO coii_torqueworks (plate, model, factory_seed, build)
        VALUES (?, ?, ?, ?)
    ]], { plate, tostring(model), seed, json.encode(Config.FactoryBuild) })

    local row = MySQL.single.await([[
        SELECT plate, model, factory_seed, build
        FROM coii_torqueworks
        WHERE plate = ?
        LIMIT 1
    ]], { plate })

    if not row then return nil end
    row.build = decodeBuild(row.build)
    return rememberBuild(row)
end

function TorqueWorksRepository.get(plate)
    local cached = cachedBuild(plate)
    if cached then return cached end
    local row = MySQL.single.await([[
        SELECT plate, model, factory_seed, build
        FROM coii_torqueworks WHERE plate = ? LIMIT 1
    ]], { plate })
    if row then row.build = decodeBuild(row.build) end
    return rememberBuild(row)
end

function TorqueWorksRepository.saveBuild(plate, build)
    local affected = MySQL.update.await([[
        UPDATE coii_torqueworks SET build = ? WHERE plate = ?
    ]], { json.encode(build), plate })
    -- Zero affected rows means the requested build already matched; it is still
    -- a successful write and the client must reapply it after local cleanup.
    if affected ~= nil then
        local cached = buildCache[plate]
        buildCache[plate] = {
            plate = plate,
            model = cached and cached.model or nil,
            factory_seed = cached and cached.factory_seed or nil,
            build = build,
            expiresAt = GetGameTimer() + cacheDuration()
        }
    end
    return affected ~= nil
end

function TorqueWorksRepository.getMmi(plate)
    local cached = mmiCache[plate]
    if cached and cached.expiresAt > GetGameTimer() then
        return cached.placement or nil
    end
    local row = MySQL.single.await([[
        SELECT placement FROM coii_torqueworks_mmi WHERE plate = ? LIMIT 1
    ]], { plate })
    local placement = row and decodeBuild(row.placement) or false
    mmiCache[plate] = { placement = placement, expiresAt = GetGameTimer() + cacheDuration() }
    return placement or nil
end

function TorqueWorksRepository.saveMmi(plate, placement)
    local saved = MySQL.insert.await([[
        INSERT INTO coii_torqueworks_mmi (plate, placement)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE placement = VALUES(placement), updated_at = CURRENT_TIMESTAMP
    ]], { plate, json.encode(placement) }) ~= nil
    if saved then
        mmiCache[plate] = { placement = placement, expiresAt = GetGameTimer() + cacheDuration() }
    end
    return saved
end

function TorqueWorksRepository.saveDynoRun(plate, build, peakPower, peakTorque, samples)
    return MySQL.insert.await([[
        INSERT INTO coii_torqueworks_dyno_runs
            (plate, build, peak_power, peak_torque, samples)
        VALUES (?, ?, ?, ?, ?)
    ]], { plate, json.encode(build), peakPower, peakTorque, json.encode(samples) })
end

function TorqueWorksRepository.getDynoHistory(plate, limit)
    local rows = MySQL.query.await([[
        SELECT id, build, peak_power, peak_torque, samples, created_at
        FROM coii_torqueworks_dyno_runs
        WHERE plate = ?
        ORDER BY id DESC
        LIMIT ?
    ]], { plate, limit or 10 }) or {}
    for _, row in ipairs(rows) do
        row.build = decodeBuild(row.build)
        row.samples = decodeBuild(row.samples)
    end
    return rows
end

function TorqueWorksRepository.createWorkOrder(data)
    return MySQL.insert.await([[
        INSERT INTO coii_torqueworks_work_orders
            (plate, mechanic_identifier, customer_identifier, quote, total,
             simulated, approval_token, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, TIMESTAMPADD(MINUTE, ?, CURRENT_TIMESTAMP))
    ]], {
        data.plate or '', data.mechanicIdentifier, data.customerIdentifier,
        json.encode(data.quote), data.total, data.simulated and 1 or 0,
        data.token, data.timeoutMinutes
    })
end

function TorqueWorksRepository.getPendingWorkOrder(id, token)
    local row = MySQL.single.await([[
        SELECT id, plate, mechanic_identifier, customer_identifier, quote, total,
               payment_method, reserved_amount, simulated, status, expires_at
        FROM coii_torqueworks_work_orders
        WHERE id = ? AND approval_token = ? AND status = 'PENDING'
          AND expires_at > CURRENT_TIMESTAMP
        LIMIT 1
    ]], { id, token })
    if row then row.quote = decodeBuild(row.quote) end
    return row
end

function TorqueWorksRepository.getApprovedWorkOrderForPlate(plate)
    local row = MySQL.single.await([[
        SELECT id, plate, mechanic_identifier, customer_identifier, quote, total,
               payment_method, reserved_amount, simulated, status
        FROM coii_torqueworks_work_orders
        WHERE plate = ? AND status = 'APPROVED'
        ORDER BY id DESC LIMIT 1
    ]], { plate })
    if row then row.quote = decodeBuild(row.quote) end
    return row
end

function TorqueWorksRepository.rejectWorkOrder(id, token)
    return (MySQL.update.await([[
        UPDATE coii_torqueworks_work_orders
        SET status = 'REJECTED'
        WHERE id = ? AND approval_token = ? AND status = 'PENDING'
    ]], { id, token }) or 0) > 0
end

function TorqueWorksRepository.completeQuotedBuild(order, build, quote, paymentMethod, token)
    -- InnoDB commits the vehicle build and receipt in the same statement.
    -- The status/token condition also makes repeated approval requests harmless.
    local affected = MySQL.update.await([[
        UPDATE coii_torqueworks AS vehicle
        INNER JOIN coii_torqueworks_work_orders AS work_order ON work_order.plate = vehicle.plate
        SET vehicle.build = ?, work_order.quote = ?, work_order.status = 'COMPLETED',
            work_order.payment_method = ?, work_order.reserved_amount = work_order.total
        WHERE work_order.id = ? AND work_order.status = ?
          AND (work_order.status = 'APPROVED' OR
               (work_order.approval_token = ? AND work_order.expires_at > CURRENT_TIMESTAMP))
    ]], { json.encode(build), json.encode(quote), paymentMethod, order.id, order.status, token or '' })
    if not affected or affected < 1 then return false end
    buildCache[order.plate] = nil
    return true
end
