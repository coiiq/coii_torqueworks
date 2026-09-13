-- Physical TorqueWorks locations. Add as many workshop entries as required.
-- `jobs` maps framework job names to their minimum grade for this workshop.
Config.Workshops = {
    harmony = {
        name = 'Harmony TorqueWorks',
        jobs = { mechanic = 0, tuner = 0 },
        tuning = {
            enabled = true,
            coords = vector3(1146.2537, -783.5482, 57.6078),
            drawDistance = 18.0,
            interactDistance = 3.0,
            control = 38,
            prompt = '[E] Open tuning terminal'
        },
        dyno = {
            enabled = true,
            station = { x = 1151.1528, y = -783.4118, z = 56.6077, heading = 180.0 }
        }
    },

    -- Example second workshop:
    -- bennys = {
    --     name = "Benny's Motorworks",
    --     jobs = { bennys = 0 },
    --     tuning = {
    --         enabled = true,
    --         coords = vector3(-211.55, -1324.55, 30.89),
    --         drawDistance = 18.0,
    --         interactDistance = 3.0
    --     },
    --     dyno = {
    --         enabled = true,
    --         station = { x = -222.0, y = -1329.0, z = 30.3, heading = 90.0 }
    --     }
    -- }
}
