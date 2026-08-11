fx_version 'cerulean'
games { 'gta5' }

name 'Pulsar Inventory'
description 'Player inventory with a drag-and-drop grid, crafting, and hotbar'
author 'Artmines - maintained for Pulsar Framework'
url 'https://pulsarframe.work'
version 'v1.0.2'

version_check 'yes'
github 'https://github.com/PulsarFW/pulsar_inventory'

client_script '@pulsar_core/components/cl_error.lua'
shared_script '@pulsar_core/core/sh_pulsar.lua'
client_script '@pulsar_pwnzor/client/check.lua'
server_script '@oxmysql/lib/MySQL.lua'

client_scripts({
	'donor_vanitys_config.lua',
	'client/**/*.lua',
})

shared_scripts({
	'config.lua',
	'items/**/*.lua',
	'schematic_config.lua',
	'shared/utils.lua',
	'shared/weapon_props.lua',
	'shared/weapon_components.lua',
	'shared/weapon_recoil.lua',
})

server_scripts({
	'crafting_config.lua',
	'server/**/*.lua',
})

files({
	'ui/dist/index.html',
	'ui/dist/assets/*',
	'ui/images/items/*.webp',
})

ui_page 'ui/dist/index.html'
lua54 'yes'
