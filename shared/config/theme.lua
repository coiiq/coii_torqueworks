-- Customer-facing colors are centralized here. Hex, rgb(), and rgba() values are supported.
-- Invalid values are ignored by the NUI and fall back to TorqueWorks defaults.
Config.UITheme = {
    colors = {
        accent = '#55D7FF', background = '#050607', surface = '#10171C',
        surfaceRaised = '#151E24', panel = 'rgba(5, 6, 7, 0.84)',
        text = '#EDF5F8', muted = '#84949C', border = 'rgba(255, 255, 255, 0.16)',
        success = '#72E6AD', warning = '#F1C75B', error = '#FF7169'
    },
    categories = {
        power = '#FF695F', driveline = '#A987FF', grip = '#C9F45D', electronics = '#50CFFF'
    },
    dyno = {
        power = '#58E7EF', torque = '#FFAD3D', boost = '#FF4D91',
        grid = 'rgba(255, 255, 255, 0.065)'
    },
    effects = { carbonTexture = true, glowStrength = 0.29, blur = 8 }
}
