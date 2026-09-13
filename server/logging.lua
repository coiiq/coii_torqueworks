TorqueWorksLogs = {}

local function configured(eventName)
    local config = Config.DiscordLogs
    return type(config) == 'table' and config.enabled == true and
        type(config.webhook) == 'string' and config.webhook ~= '' and
        (type(config.events) ~= 'table' or config.events[eventName] ~= false)
end

local function safe(value, fallback)
    value = tostring(value or fallback or 'N/A'):gsub('%c', function(character)
        return character == '\n' and '\n' or ' '
    end)
    return value:sub(1, 1000)
end

local function identifier(source, prefix)
    if not source or source <= 0 then return 'N/A' end
    for _, value in ipairs(GetPlayerIdentifiers(source)) do
        if value:sub(1, #prefix + 1) == prefix .. ':' then return value end
    end
    return 'N/A'
end

local function roleplayName(source, frameworkIdentifier)
    if not source or source <= 0 or not TorqueWorksFramework then return nil end
    local player = TorqueWorksFramework.GetPlayerFromId(source)
    if not player then return nil end
    if TorqueWorksFramework.name == 'esx' and frameworkIdentifier and MySQL and MySQL.single then
        local ok, row = pcall(function()
            return MySQL.single.await(
                'SELECT firstname, lastname FROM users WHERE identifier = ? LIMIT 1',
                { frameworkIdentifier })
        end)
        if ok and row then
            local name = (('%s %s'):format(row.firstname or '', row.lastname or ''))
                :gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
            if name ~= '' then return name end
        end
        return nil
    end
    if type(player.getName) ~= 'function' then return nil end
    local ok, name = pcall(function() return player.getName() end)
    return ok and type(name) == 'string' and name ~= '' and name or nil
end

local function playerField(label, source, frameworkIdentifier)
    if not source or source <= 0 then
        return { name = label, value = safe(frameworkIdentifier), inline = false }
    end
    local cfxName = GetPlayerName(source) or 'Unknown'
    local rpName = roleplayName(source, frameworkIdentifier)
    local discordIdentifier = identifier(source, 'discord')
    local discordId = discordIdentifier:match('^discord:(%d+)$')
    local displayName = (rpName or cfxName):gsub('[%[%]]', '')
    local linkedName = discordId and
        ('[%s](https://discord.com/users/%s)'):format(displayName, discordId) or displayName
    local discordProfile = discordId and ('<@%s>'):format(discordId) or 'Not linked'
    return {
        name = label,
        value = safe(('RP: **%s**\nFiveM: %s (`%s`)\nFramework: `%s`\nLicense: `%s`\nDiscord: %s'):format(
            linkedName, cfxName, source, frameworkIdentifier or 'N/A',
            identifier(source, 'license'), discordProfile)),
        inline = false
    }
end

local function append(fields, name, value, inline)
    if value == nil or value == '' then return end
    fields[#fields + 1] = { name = name, value = safe(value), inline = inline == true }
end

function TorqueWorksLogs.audit(eventName, data)
    if not configured(eventName) then return end
    data = type(data) == 'table' and data or {}
    local config = Config.DiscordLogs
    local fields = {}
    if data.actorSource or data.actorIdentifier then
        fields[#fields + 1] = playerField(data.actorLabel or 'Actor', data.actorSource, data.actorIdentifier)
    end
    if (data.mechanicSource or data.mechanicIdentifier) and data.actorLabel ~= 'Mechanic' then
        fields[#fields + 1] = playerField('Mechanic', data.mechanicSource, data.mechanicIdentifier)
    end
    if data.customerSource or data.customerIdentifier then
        fields[#fields + 1] = playerField('Customer', data.customerSource, data.customerIdentifier)
    end
    append(fields, 'Workshop', data.workshop, true)
    append(fields, 'Vehicle plate', data.plate and ('`%s`'):format(data.plate), true)
    append(fields, 'Work order', data.orderId and ('`#%s`'):format(data.orderId), true)
    append(fields, 'Amount', data.amount and ('$%s'):format(math.floor(tonumber(data.amount) or 0)), true)
    append(fields, 'Payment', data.paymentMethod and tostring(data.paymentMethod):upper(), true)
    append(fields, 'Transaction mode', data.simulated and 'SIMULATED' or data.transactionMode, true)
    append(fields, 'Part', data.part, true)
    append(fields, 'Parts', data.parts, false)
    append(fields, 'Reason', data.reason, false)

    local payload = {
        username = config.username or 'TorqueWorks Audit',
        avatar_url = config.avatarUrl ~= '' and config.avatarUrl or nil,
        allowed_mentions = { parse = {} },
        embeds = {{
            title = safe(data.title or eventName),
            description = safe(data.description or 'TorqueWorks transaction event.'),
            color = (config.colors or {})[data.level or 'info'] or 5793266,
            fields = fields,
            footer = { text = safe(config.footer or 'coii_torqueworks') },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }}
    }
    PerformHttpRequest(config.webhook, function(status)
        if status < 200 or status >= 300 then
            print(('[coii_torqueworks] Discord audit webhook returned HTTP %s.'):format(status))
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end
