fx_version 'cerulean'
game 'gta5'

author 'coii'
description 'TorqueWorks - vehicle tuning, workshop billing and dyno'
version '0.1.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/config/theme.lua',
    'shared/config/core.lua',
    'shared/config/sounds.lua',
    'shared/config/integrations.lua',
    'shared/config/workshops.lua',
    'shared/config/ui.lua',
    'shared/config/installation.lua',
    'shared/config/dyno.lua',
    'shared/config/tuning.lua',
    'shared/config/parts.lua',
    'shared/config/legacy.lua',
    'shared/math.lua'
}

client_scripts {
    'client/integrations.lua',
    'client/baseline.lua',
    'client/brakes.lua',
    'client/turbo_audio.lua',
    'client/transmission.lua',
    'client/backfire.lua',
    'client/runtime.lua',
    'client/nitro.lua',
    'client/dyno.lua',
    'client/build_card.lua',
    'client/mechanic.lua',
    'client/mmi.lua',
    'client/mmi_dui.lua',
    'client/commands.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/mechanic.js',
    'web/mmi.html',
    'web/mmi.css',
    'web/mmi-theme.css',
    'web/mmi.js',
    'web/audio/turbos/*.wav',
    'stream/mist_dy.ytyp',
    'stream/sounds/audioconfig/*.rel',
    'stream/sounds/sfx/**/*.awc'
}

data_file 'DLC_ITYP_REQUEST' 'stream/mist_dy.ytyp'

data_file 'AUDIO_GAMEDATA' 'stream/sounds/audioconfig/sr15atom_game.dat'
data_file 'AUDIO_SOUNDDATA' 'stream/sounds/audioconfig/sr15atom_sounds.dat'
data_file 'AUDIO_WAVEPACK' 'stream/sounds/sfx/dlc_sr15atom'

data_file 'AUDIO_GAMEDATA' 'stream/sounds/audioconfig/st77gtr_game.dat'
data_file 'AUDIO_SOUNDDATA' 'stream/sounds/audioconfig/st77gtr_sounds.dat'
data_file 'AUDIO_WAVEPACK' 'stream/sounds/sfx/dlc_st77gtr'

data_file 'AUDIO_GAMEDATA' 'stream/sounds/audioconfig/st69zagato_game.dat'
data_file 'AUDIO_SOUNDDATA' 'stream/sounds/audioconfig/st69zagato_sounds.dat'
data_file 'AUDIO_WAVEPACK' 'stream/sounds/sfx/dlc_st69zagato'

data_file 'AUDIO_GAMEDATA' 'stream/sounds/audioconfig/str17mach1gen1_game.dat'
data_file 'AUDIO_SOUNDDATA' 'stream/sounds/audioconfig/str17mach1gen1_sounds.dat'
data_file 'AUDIO_WAVEPACK' 'stream/sounds/sfx/dlc_str17mach1gen1'

data_file 'AUDIO_GAMEDATA' 'stream/sounds/audioconfig/str025f20c_game.dat'
data_file 'AUDIO_SOUNDDATA' 'stream/sounds/audioconfig/str025f20c_sounds.dat'
data_file 'AUDIO_WAVEPACK' 'stream/sounds/sfx/dlc_str025f20c'

data_file 'AUDIO_GAMEDATA' 'stream/sounds/audioconfig/str02213bt_game.dat'
data_file 'AUDIO_SOUNDDATA' 'stream/sounds/audioconfig/str02213bt_sounds.dat'
data_file 'AUDIO_WAVEPACK' 'stream/sounds/sfx/dlc_str02213bt'

data_file 'AUDIO_GAMEDATA' 'stream/sounds/audioconfig/str021m3e30_game.dat'
data_file 'AUDIO_SOUNDDATA' 'stream/sounds/audioconfig/str021m3e30_sounds.dat'
data_file 'AUDIO_WAVEPACK' 'stream/sounds/sfx/dlc_str021m3e30'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config/logging.lua',
    'server/framework.lua',
    'server/database.lua',
    'server/repository.lua',
    'server/logging.lua',
    'server/main.lua'
}

dependencies {
    'baseevents',
    'ox_lib',
    'oxmysql'
}
