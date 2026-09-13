-- Copy these entries into ox_inventory/data/items.lua.
return {
    ['coii_mmi'] = {
        label = 'MMI Tablet',
        weight = 750,
        stack = false,
        close = true,
        client = {
            image = 'coii_mmi.png'
        }
    },

    ['coii_clamp'] = {
        label = 'Hose Clamp',
        weight = 100,
        stack = true,
        close = false
    },

    ['coii_mechanic_turbo_1'] = {
        label = 'Turbo (In parts)',
        weight = 2000,
        stack = false,
        close = false
    },

    ['coii_oil'] = {
        label = 'Motor Oil',
        weight = 600,
        stack = true,
        close = false
    },

    ['coii_screws'] = {
        label = 'Screws',
        weight = 30,
        stack = true,
        close = false
    },

    ['nos_bottle'] = {
        label = 'NOS Bottle',
        weight = 1500,
        stack = false,
        close = true
    }
}
