TorqueWorksUI = {}

local defaults = {
    notify = lib.notify,
    progressBar = lib.progressBar,
    progressCircle = lib.progressCircle,
    showTextUI = lib.showTextUI,
    hideTextUI = lib.hideTextUI
}

local integrations = Config.Integrations or {}

function TorqueWorksUI.notify(data)
    data = type(data) == 'table' and data or { description = tostring(data or '') }
    local adapter = integrations.notification
    if adapter then return adapter(data, defaults) end
    return defaults.notify(data)
end

function TorqueWorksUI.progress(kind, data)
    local adapter = integrations.progress
    if adapter then return adapter(kind, data, defaults) end
    return kind == 'bar' and defaults.progressBar(data) or defaults.progressCircle(data)
end

function TorqueWorksUI.showTextUI(text, options)
    local adapter = integrations.textUI and integrations.textUI.show
    if adapter then return adapter(text, options, defaults) end
    return defaults.showTextUI(text, options)
end

function TorqueWorksUI.hideTextUI()
    local adapter = integrations.textUI and integrations.textUI.hide
    if adapter then return adapter(defaults) end
    return defaults.hideTextUI()
end

RegisterNetEvent('coii_torqueworks:client:notification', function(data)
    TorqueWorksUI.notify(data)
end)

local function sendUiTheme()
    SendNUIMessage({ action = 'torqueWorksTheme', theme = Config.UITheme or {} })
end

CreateThread(function()
    Wait(250)
    sendUiTheme()
end)
