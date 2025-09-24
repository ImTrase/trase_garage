-----------------------------------------------------
---- For more scripts and updates, visit ------------
--------- https://discord.gg/trase ------------------
-----------------------------------------------------

fx_version 'cerulean'
games { 'gta5' }
author 'Trase'
lua54 'yes'


shared_script '@ox_lib/init.lua'
shared_script 'config.lua'
client_scripts {
    'client/*.lua',
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'framework/**/server.lua',
    'server/*.lua'
}

files {
  'locales/*.json'
}

dependency 'ox_lib'
dependency 'mysql-async'