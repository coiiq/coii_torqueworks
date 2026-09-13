-- Server-only: never include webhook configuration in shared_scripts or files.
Config.DiscordLogs = {
    enabled = true,
    webhook = '',
    username = 'TorqueWorks Audit',
    avatarUrl = '',
    footer = 'coii_torqueworks | server audit',
    events = {
        quoteCreated = true,
        quoteRejected = true,
        paymentFailed = true,
        paymentApproved = true,
        paymentRollback = true,
        workOrderCompleted = true
    },
    colors = {
        info = 5793266,
        success = 5763719,
        warning = 16760576,
        danger = 15548997
    }
}

local localConfig = LoadResourceFile(GetCurrentResourceName(), 'server/config/logging.local.lua')
if localConfig then
    local applyConfig, message = load(localConfig, '@server/config/logging.local.lua', 't', _ENV)
    if not applyConfig then error(message) end
    applyConfig()
end

local webhook = GetConvar('torqueworks_discord_webhook', '')
if webhook ~= '' then Config.DiscordLogs.webhook = webhook end
