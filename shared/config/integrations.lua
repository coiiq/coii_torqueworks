-- Framework permissions shared by every workshop. Physical locations and
-- workshop-specific jobs are configured in shared/config/workshops.lua.
Config.MechanicAccess = {
    acePermission = 'coii_torqueworks.mechanic',
    adminGroups = { admin = true, superadmin = true }
}

-- Accepted quotes charge the customer and install the complete build immediately.
Config.Billing = {
    enabled = true,
    laborPerPart = 750,
    maximumQuote = 250000,
    customerDistance = 8.0,
    approvalTimeoutMinutes = 10,
    paymentAccounts = {
        cash = { enabled = true, label = 'Cash' },
        bank = { enabled = true, label = 'Bank' }
    }
}
