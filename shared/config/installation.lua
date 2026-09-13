-- Parts consumed when the customer accepts a build quote.
-- Item labels and images are resolved from ox_inventory at runtime.
Config.Installation = {
    consumable = { enabled = true },
    requirements = {
        universal = {},
        parts = {
            turbo = {
                LARGE = {
                    { item = 'coii_mechanic_turbo_1', amount = 1 },
                    { item = 'coii_clamp', amount = 3 },
                    { item = 'coii_oil', amount = 1 },
                    { item = 'coii_screws', amount = 20 }
                }
            }
        }
    },
    adminBypass = false
}
