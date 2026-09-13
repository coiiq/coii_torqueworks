-- TorqueWorks public configuration. Feature data lives in shared/config/.
Config = {}

-- auto, esx, qbcore, or qbox.
Config.Framework = 'auto'

-- Only vehicles present in the framework's ownership table may be tuned.
-- Change a mapping here if your garage resource uses different table/column names.
Config.VehicleOwnership = {
    required = true,
    esx = { table = 'owned_vehicles', ownerColumn = 'owner', plateColumn = 'plate' },
    qbcore = { table = 'player_vehicles', ownerColumn = 'citizenid', plateColumn = 'plate' },
    qbox = { table = 'player_vehicles', ownerColumn = 'citizenid', plateColumn = 'plate' }
}

-- Replace these functions to use another notification, progress, or TextUI resource.
-- `defaults` contains the original ox_lib functions and can be used as a fallback.
Config.Integrations = {
    notification = function(data, defaults)
        return defaults.notify(data)
    end,
    progress = function(kind, data, defaults)
        return kind == 'bar' and defaults.progressBar(data) or defaults.progressCircle(data)
    end,
    textUI = {
        show = function(text, options, defaults)
            return defaults.showTextUI(text, options)
        end,
        hide = function(defaults)
            return defaults.hideTextUI()
        end
    },
    serverNotification = function(target, data)
        TriggerClientEvent('coii_torqueworks:client:notification', target, data)
    end
}
