_cachedInventory = nil
SecondInventory = {}

_inUse = false
_reloading = false
local _openCd = false
local _timedCd = false
local _hkCd = false
local _container = nil
local trunkOpen = false

local _itemDefs = nil
local _schems = {}

function dropAnim(drop)
	if plsr.State.flags.doingAction then
		return
	end
	if plsr.State.flags.isK9Ped then
		loadAnimDict("creatures@rottweiler@move")
		if drop then
			TaskPlayAnim(PlayerPedId(), "creatures@rottweiler@move", "fetch_pickup", 5.0, 1.0, 1.0, 48, 0.0, 0, 0, 0)
		else
			TaskPlayAnim(PlayerPedId(), "creatures@rottweiler@move", "fetch_drop", 5.0, 1.0, 1.0, 48, 0.0, 0, 0, 0)
		end
		return
	end
	if drop then
		loadAnimDict("pickup_object")
		TaskPlayAnim(PlayerPedId(), "pickup_object", "putdown_low", 5.0, 1.0, 1.0, 48, 0.0, 0, 0, 0)
	else
		loadAnimDict("pickup_object")
		TaskPlayAnim(PlayerPedId(), "pickup_object", "pickup_low", 5.0, 1.0, 1.0, 48, 0.0, 0, 0, 0)
	end
end

local function DoItemLoad(items)
	if _loading then
		return
	end

	SendNUIMessage({
		type = "ITEMS_UNLOADED",
		data = {},
	})
	Wait(100)
	SendNUIMessage({
		type = "RESET_ITEMS",
		data = {},
	})

	for k, v in pairs(_itemsSource) do
		for k2, v2 in ipairs(v) do
			_items[v2.name] = v2
		end
	end

	if items ~= nil then
		for k, v in pairs(items) do
			_items[v.name] = v
		end
	end

	SendNUIMessage({
		type = "SET_ITEMS",
		data = {
			items = _items,
		},
	})

	SendNUIMessage({
		type = "ITEMS_LOADED",
	})
	TriggerEvent("Inventory:Client:ItemsLoaded")
	_startup = true
	_loading = false
	_reloading = false
end

CreateThread(function()
	plsr.State.flags.inventoryOpen = false
	plsr.State.flags.craftingOpen = false
	plsr.State.flags.InventoryDisabled = false
	plsr.State.flags.holstering = false

	RegisterKeyBinds()
	RegisterRandomItems()
	DoItemLoad()
	CreateDonorVanityItems()

	plsr.Callbacks:RegisterClientCallback("Inventory:ForceClose", function(data, cb)
		plsr.Inventory.Close:All()
		cb(true)
	end)

	plsr.Callbacks:RegisterClientCallback("Inventory:Container:Open", function(data, cb)
		if SecondInventory.owner ~= nil then
			plsr.Callbacks:ServerCallback("Inventory:CloseSecondary", SecondInventory, function()
				_container = data.item
				SecondInventory = { invType = _items[data.item.Name].container, owner = data.container }
				cb(true)
			end)
		else
			_container = data.item
			SecondInventory = { invType = _items[data.item.Name].container, owner = data.container }
			cb(true)
		end
	end)

	plsr.Callbacks:RegisterClientCallback("Inventory:Compartment:Open", function(data, cb)
		if SecondInventory.owner ~= nil then
			plsr.Callbacks:ServerCallback("Inventory:CloseSecondary", SecondInventory, function()
				SecondInventory = data
				cb(true)
			end)
		else
			SecondInventory = data
			cb(true)
		end
	end)

	plsr.Callbacks:RegisterClientCallback("Inventory:ItemUse", function(item, cb)
		if item.anim and (not item.pbConfig or not item.pbConfig.animation) then
			plsr.Animations.Emotes:Play(item.anim, false, item.time, true)
		end

		if item.pbConfig ~= nil then
			plsr.Progress:Progress({
				name = item.pbConfig.name,
				duration = item.time,
				label = item.pbConfig.label,
				useWhileDead = item.pbConfig.useWhileDead,
				canCancel = item.pbConfig.canCancel,
				vehicle = item.pbConfig.vehicle,
				disarm = item.pbConfig.disarm,
				ignoreModifier = item.pbConfig.ignoreModifier or true,
				animation = item.pbConfig.animation or false,
				controlDisables = {
					disableMovement = item.pbConfig.disableMovement,
					disableCarMovement = item.pbConfig.disableCarMovement,
					disableMouse = item.pbConfig.disableMouse,
					disableCombat = item.pbConfig.disableCombat,
				},
			}, function(cancelled)
				plsr.Animations.Emotes:ForceCancel()
				cb(not cancelled)
			end)
		else
			cb(true)
		end
	end)

	CreateVendingMachines()
end)

function PlayTrunkOpenAnim()
    local playerPed = PlayerPedId()
    RequestAnimDict('anim@heists@prison_heiststation@cop_reactions')

    while not HasAnimDictLoaded('anim@heists@prison_heiststation@cop_reactions') do
        Wait(100)
    end

    TaskPlayAnim(playerPed, 'anim@heists@prison_heiststation@cop_reactions', 'cop_b_idle', 3.0, 3.0, -1, 49, 0.0, 0, 0, 0)

    RemoveAnimDict('anim@heists@prison_heiststation@cop_reactions')
end

function PlayTrunkCloseAnim()
	local playerPed = PlayerPedId()
    RequestAnimDict('anim@heists@fleeca_bank@scope_out@return_case')

    while not HasAnimDictLoaded('anim@heists@fleeca_bank@scope_out@return_case') do
        Wait(100)
    end

    TaskPlayAnim( playerPed, 'anim@heists@fleeca_bank@scope_out@return_case', 'trevor_action', 2.0, 2.0, -1, 49, 0.25, 0.0, 0.0, GetEntityHeading(playerPed))
    RemoveAnimDict('anim@heists@fleeca_bank@scope_out@return_case')
end

RegisterNetEvent("Inventory:Client:LoadItems", DoItemLoad)

RegisterNetEvent("Inventory:Client:ReloadItems", function()
	_reloading = true
	plsr.Notification.Persistent:Info("INVENTORY_RELOAD", "Requesting Updated Item Definitions, Inventory Temporarily Unavailable")
	TriggerServerEvent("Inventory:Server:ReloadItems")
end)

RegisterNetEvent("Inventory:Client:NewItemCreated", function(itemData)
	_items[itemData.name] = itemData
	SendNUIMessage({
		type = "ADD_ITEM",
		data = {
			id = itemData.name,
			item = itemData,
		},
	})
end)

RegisterNetEvent("Inventory:Client:ReceiveReload", function(items)
	LoadItems()
	DoItemLoad(items)
	plsr.Notification.Persistent:Remove("INVENTORY_RELOAD")
	plsr.Notification:Info("Item Reload Has Completed")
end)

function startCd()
	CreateThread(function()
		_timedCd = true
		Wait(1000)
		_timedCd = false
	end)
end

RegisterNetEvent("UI:Client:Reset", function(force)
	if force then
		_startup = false
		LoadItems()
	end
	plsr.Inventory.Close:All()
	plsr.Inventory:Enable()
end)

RegisterNetEvent("Inventory:Client:Cache", function(inventory, refresh)
	_cachedInventory = inventory
end)

RegisterNetEvent("Inventory:Client:Open", function(inventory, inventory2)
	if inventory ~= nil then
		_openCd = true
		plsr.State.flags.inventoryOpen = true
		plsr.Inventory.Set.Player:Inventory(inventory)
		plsr.Inventory.Set.Player.Data.Open = true

		if inventory2?.crafting then
			plsr.Inventory.Set.Secondary.Data.Open = true
			SendNUIMessage({
				type = "SET_MODE",
				data = {
					mode = "crafting",
				},
			})
			SendNUIMessage({
				type = "SET_BENCH",
				data = {
					bench = inventory2.bench,
					cooldowns = inventory2.cooldowns,
					recipes = inventory2.recipes,
				},
			})
			SendNUIMessage({
				type = "APP_SHOW",
			})
			SetNuiFocus(true, true)
		else
			if SecondInventory?.invType == 10 then
				dropAnim(true)
			end

			SendNUIMessage({
				type = "SET_MODE",
				data = {
					mode = "inventory",
				},
			})

			if inventory2 ~= nil then
				plsr.Inventory.Set.Secondary:Inventory(inventory2)
				plsr.Inventory.Set.Secondary.Data.Open = true
				plsr.Inventory.Open:Secondary()
			else
				plsr.Inventory.Set.Secondary.Data.Open = false
			end

			SendNUIMessage({
				type = "APP_SHOW",
			})
			SetNuiFocus(true, true)
		end
	
		CreateThread(function()
			while plsr.State.flags.inventoryOpen do
				Wait(50)
			end
			TriggerServerEvent("Inventory:server:closePlayerInventory", plsr.State.character.SID)
		end)
	else
		plsr.State.flags.inventoryOpen = false
	end
end)

RegisterNetEvent("Inventory:Client:Load", function(inventory, inventory2)
	if inventory ~= nil then
		plsr.Inventory.Set.Player:Inventory(inventory)
		if inventory2 ~= nil then
			plsr.Inventory.Set.Secondary:Inventory(inventory2)
		end
	else
		plsr.State.flags.inventoryOpen = false
	end
	_openCd = false
end)

-- pane's already open and visible, just refresh its contents, skips the full open/focus/anim dance
RegisterNetEvent("Inventory:Client:RefreshSecondary", function(inventory2)
	if inventory2 ~= nil then
		plsr.Inventory.Set.Secondary:Inventory(inventory2)
	end
end)

AddEventHandler("Characters:Client:Updated", function(key)
	if key == "InventorySettings" then
		SendNUIMessage({
			type = "UPDATE_SETTINGS",
			data = {
				settings = plsr.State.character.InventorySettings or {},
			}
		})
	end
end)

AddEventHandler("Vehicles:Client:ExitVehicle", function()
	if plsr.State.flags.inventoryOpen then
		plsr.Inventory.Close:All()
	end
end)

INVENTORY = {
	_required = { "IsEnabled", "Open", "Close", "Set", "Enable", "Disable", "Toggle", "Check" },
	IsEnabled = function(self)
		return _startup and not _openCd and not _timedCd and not plsr.Hud:IsDisabled()
	end,
	Open = {
		Player = function(self, doSecondary)
			if plsr.Inventory:IsEnabled() then
				plsr.Phone:Close()
				plsr.Interaction:Hide()
				if not plsr.State.flags.inventoryOpen then
					plsr.State.flags.inventoryOpen = true
					TriggerServerEvent("Inventory:Server:Request", doSecondary and SecondInventory or false)
				end
			end
		end,
		Secondary = function(self)
			SendNUIMessage({
				type = "SHOW_SECONDARY_INVENTORY",
			})
		end,
	},
	Close = {
		All = function(self)
			SendNUIMessage({
				type = "APP_HIDE",
			})
			SetNuiFocus(false, false)

			plsr.State.flags.inventoryOpen = false
			plsr.State.flags.craftingOpen = false
			plsr.Inventory.Set.Player.Data.Open = false

			if trunkOpen and trunkOpen > 0 then
				PlayTrunkCloseAnim()
				Wait(900)
				plsr.Vehicles.Sync.Doors:Shut(trunkOpen, 5, false)
				trunkOpen = false
				ClearPedTasks(PlayerPedId())
			end

			if plsr.Inventory.Set.Secondary.Data.Open then
				plsr.Inventory.Close:Secondary()
			end
		end,
		Secondary = function(self)
			if trunkOpen and trunkOpen > 0 then
				PlayTrunkCloseAnim()
				Wait(900)
				plsr.Vehicles.Sync.Doors:Shut(trunkOpen, 5, false)
				trunkOpen = false
				ClearPedTasks(PlayerPedId())
			end

			if plsr.Inventory.Set.Secondary.Data.Open then
				plsr.Callbacks:ServerCallback("Inventory:CloseSecondary", SecondInventory, function()
					SecondInventory = {}
					_container = nil
					plsr.Inventory.Set.Secondary.Data.Open = false
				end)
			end
		end,
	},
	Set = {
		Player = {
			Data = {
				allowOpen = true,
				Open = false,
			},
			Inventory = function(self, data)
				if not data then
					plsr.State.flags.inventoryOpen = false
					plsr.State.flags.craftingOpen = false
					plsr.Inventory.Set.Player.Data.Open = false
					return
				end

				SendNUIMessage({
					type = "SET_PLAYER_INVENTORY",
					data = data,
				})
			end,
			Slot = function(self, slot)
				SendNUIMessage({
					type = "SET_PLAYER_SLOT",
					data = {
						slot = slot,
					},
				})
			end,
		},
		Secondary = {
			Data = {
				Open = false,
			},
			Inventory = function(self, data)
				plsr.Inventory.Set.Secondary.Data.Open = true
				SendNUIMessage({
					type = "SET_SECONDARY_INVENTORY",
					data = data,
				})
			end,
			Slot = function(self, slot)
				SendNUIMessage({
					type = "SET_SECONDARY_SLOT",
					data = {
						slot = slot,
					},
				})
			end,
		},
	},
	Used = {
		HotKey = function(self, control)
			if not _hkCd and not _inUse and not plsr.Hud:IsDisabled() then
				SendNUIMessage({
					type = "USE_ITEM_PLAYER",
					data = {
						originSlot = control,
					},
				})
				_hkCd = true
				plsr.Callbacks:ServerCallback("Inventory:UseSlot", { slot = control }, function(state)
					if not state then
						SendNUIMessage({
							type = "SLOT_NOT_USED",
							data = {
								originSlot = control,
							},
						})
					end

					Citizen.SetTimeout(3000, function()
						_hkCd = false
					end)
				end)
			end
		end,
	},
	-- ALL OF THIS NEEDS TO BE VALIDATED SERVER SIDE
	-- THIS IS BEING ADDED TO SAVE A CLIENT > SERVER > CLIENT CALL
	Items = {
		GetInstance = function(self, item)
			if _cachedInventory == nil or _cachedInventory.inventory == nil or #_cachedInventory.inventory == 0 then
				return nil
			end

			for k, v in ipairs(_cachedInventory.inventory) do
				if v.Name == item
					and (
						_items[v.Name].durability == nil
						or not _items[v.Name].isDestroyed
						or (((v.CreateDate or 0) + _items[v.Name].durability) >= GetCloudTimeAsInt())
							
					) then
						return v
					end
			end
		end,
		GetCount = function(self, item, bundleWeapons)
			local counts = plsr.Inventory.Items:GetCounts(bundleWeapons)
			return counts[item] or 0
		end,
		GetCounts = function(self, bundleWeapons)
			if _cachedInventory == nil or _cachedInventory.inventory == nil or #_cachedInventory.inventory == 0 then
				return {}
			end
			local counts = {}

			if not plsr.State.flags.loggedIn then
				return counts
			end

			for k, v in ipairs(_cachedInventory.inventory) do
				if _items[v.Name] then
					if
						_items[v.Name].durability == nil
						or not _items[v.Name].isDestroyed
						or (((v.CreateDate or 0) + _items[v.Name].durability) >= GetCloudTimeAsInt())
					then
						local itemData = plsr.Inventory.Items:GetData(v.Name)
	
						if bundleWeapons and itemData?.weapon then
							counts[itemData?.weapon] = (counts[itemData?.weapon] or 0) + v.Count
						end
						counts[v.Name] = (counts[v.Name] or 0) + v.Count
					end
				end
			end

			return counts
		end,
		GetTypeCounts = function(self)
			local counts = {}

			if not plsr.State.flags.loggedIn or _cachedInventory == nil or _items == nil then
				return counts
			end

			for k, v in ipairs(_cachedInventory.inventory) do
				if _items[v.Name] ~= nil then
					if
						_items[v.Name].durability == nil
						or not _items[v.Name].isDestroyed
						or (((v.CreateDate or 0) + _items[v.Name].durability) >= GetCloudTimeAsInt())
					then
						local itemData = plsr.Inventory.Items:GetData(v.Name)
						counts[itemData.type] = (counts[itemData.type] or 0) + v.Count
					end
				end
			end

			return counts
		end,
		Has = function(self, item, count, bundleWeapons)
			return plsr.Inventory.Items:GetCount(item, bundleWeapons) >= count
		end,
		HasType = function(self, itemType, count)
			return (plsr.Inventory.Items:GetTypeCounts()[itemType] or 0) >= count
		end,
		GetData = function(self, name)
			if name ~= nil then
				return _items[name]
			else
				return _items
			end
		end,
		GetWithStaticMetadata = function(self, masterKey, mainIdName, textureIdName, gender, data)
			for k, v in pairs(_items) do
				if
					v.staticMetadata ~= nil
					and v.staticMetadata[masterKey] ~= nil
					and v.staticMetadata[masterKey][gender][mainIdName] == data[mainIdName]
					and v.staticMetadata[masterKey][gender][textureIdName] == data[textureIdName]
				then
					return k
				end
			end

			return nil
		end,
	},
	Check = {
		Player = {
			HasItem = function(self, item, count)
				return plsr.Inventory.Items:Has(item, count)
			end,
			HasItems = function(self, items)
				for k, v in ipairs(items) do
					if not plsr.Inventory.Items:Has(v.item, v.count, true) then
						return false
					end
				end
				return true
			end,
			HasAnyItems = function(self, items)
				for k, v in ipairs(items) do
					if plsr.Inventory.Items:Has(v.item, v.count) then
						return true
					end
				end

				return false
			end,
		},
	},
	Enable = function(self)
		plsr.State.flags.InventoryDisabled = false
	end,
	Disable = function(self)
		plsr.State.flags.InventoryDisabled = true
	end,
	Toggle = function(self)
		plsr.State.flags.InventoryDisabled = not plsr.State.flags.InventoryDisabled
	end,
	Secondary = {
		Open = function(self, data)
			plsr.Callbacks:ServerCallback("Inventory:Server:Open", data, function(state)
				if state then
					SecondInventory = { invType = data.invType, owner = data.owner }
				end
			end)
		end,
	},
	Stash = {
		Open = function(self, type, identifier)
			plsr.Callbacks:ServerCallback("Stash:Server:Open", {
				type = type,
				identifier = identifier,
			}, function(state)
				if state ~= nil then
					SecondInventory = state
				end
			end)
		end,
	},
	Shop = {
		Open = function(self, identifier)
			plsr.Callbacks:ServerCallback("Shop:Server:Open", {
				identifier = identifier,
			}, function(state)
				if state then
					SecondInventory = { invType = state, owner = string.format("shop:%s", identifier) }
				end
			end)
		end,
	},
	PlayerShop = {
		Open = function(self, shopId)
			plsr.Callbacks:ServerCallback("PlayerShop:Server:Open", {
				id = shopId,
			}, function(state)
				if state then
					SecondInventory = { invType = state, owner = shopId }
				end
			end)
		end,
	},
	Search = {
		Character = function(self, serverId)
			plsr.Callbacks:ServerCallback("Inventory:Search", {
				serverId = serverId,
			}, function(owner)
				if owner then
					SecondInventory = { invType = 1, owner = owner }
				end
			end)
		end,
	},
	StaticTooltip = {
		Open = function(self, item)
			SendNUIMessage({
				type = "OPEN_STATIC_TOOLTIP",
				data = {
					item = item,
				}
			})
		end,
		Close = function(self)
			SendNUIMessage({
				type = "CLOSE_STATIC_TOOLTIP",
			})
		end,
	},
	UpdateCachedMD = function(self, slot, md, triggeredKey)
		if _cachedInventory and _cachedInventory.inventory then
			for k, v in ipairs(_cachedInventory.inventory) do
				if v.Slot == slot then
					v.MetaData = md

					local itemData = _items[v.Name]
					if WEAPON_PROPS[itemData?.weapon or v.name] and triggeredKey == "WeaponComponents" then
						
					end

					return
				end
			end
		end
	end,
}

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["pulsar_core"]:RegisterComponent("Inventory", INVENTORY)
end)

local Sounds = {
	["SELECT"] = { id = -1, sound = "SELECT", library = "HUD_FRONTEND_DEFAULT_SOUNDSET" },
	["BACK"] = { id = -1, sound = "CANCEL", library = "HUD_FRONTEND_DEFAULT_SOUNDSET" },
	["UPDOWN"] = { id = -1, sound = "NAV_UP_DOWN", library = "HUD_FRONTEND_DEFAULT_SOUNDSET" },
	["DISABLED"] = { id = -1, sound = "ERROR", library = "HUD_FRONTEND_DEFAULT_SOUNDSET" },
	["SHOP_ADD"] = { id = -1, sound = "ATM_WINDOW", library = "HUD_FRONTEND_DEFAULT_SOUNDSET" }
}
RegisterNUICallback("FrontEndSound", function(data, cb)
	cb("ok")
	if Sounds[data] ~= nil then
		plsr.UISounds.Play:FrontEnd(Sounds[data].id, Sounds[data].sound, Sounds[data].library)
	end
end)

RegisterNUICallback("UpdateSettings", function(data, cb)
	cb('OK')
	TriggerServerEvent("Inventory:Server:UpdateSettings", data)
end)

RegisterNUICallback("SubmitAction", function(data, cb)
	cb('OK')
	plsr.Inventory.Close:All()
	TriggerServerEvent("Inventory:Server:TriggerAction", data)
end)

RegisterNUICallback("Close", function(data, cb)
	startCd()
	cb(true)
	plsr.Inventory.Close:All()
	plsr.Inventory:Enable()
end)

RegisterNUICallback("Crashed", function(data, cb)
	startCd()
	cb(true)
	plsr.Inventory.Close:All()
	plsr.Inventory:Enable()
	_openCd = false
end)

RegisterNUICallback("BrokeShit", function(data, cb)
	startCd()
	cb(true)
	plsr.Inventory.Close:All()
	plsr.Inventory:Enable()
	_openCd = false
	plsr.Notification:Error("Something Is Broken And Your Inventory Isn't Working, You May Need To Hard Nap To Fix")
end)

RegisterNetEvent("Inventory:Client:ReceiveItems", function(items)
	_itemDefs = items or {}
end)

RegisterNetEvent("Characters:Client:Spawn", function()
	plsr.Callbacks:ServerCallback("Inventory:Server:retreiveStores", {}, function(shopsData)
		Shops = shopsData
		setupStores(shopsData)
		startDropsTick()
	end)

	SendNUIMessage({
		type = "SET_SCHEMS",
		data = _schematics
	})

	SendNUIMessage({
		type = "UPDATE_SETTINGS",
		data = {
			settings = plsr.State.character.InventorySettings or {},
		}
	})

	WeaponsThread()
end)

RegisterNetEvent("Characters:Client:Logout", function()
	Shops = {}
	_cachedInventory = nil
end)

AddEventHandler("Ped:Client:Died", function()
	plsr.Inventory.Close:All()
end)

AddEventHandler("Inventory:Client:Trunk", function(entity, data)
	local vehClass = GetVehicleClass(entity.entity)
	local vehModel = GetEntityModel(entity.entity)

	plsr.Callbacks:ServerCallback("Inventory:OpenTrunk", {
		netId = VehToNet(entity.entity),
		class = vehClass,
		model = vehModel,
	}, function(s)
		if s then
			SecondInventory = {
				netId = VehToNet(entity.entity),
				invType = 4,
				owner = plsr.State.Entity(entity.entity).VIN,
				class = vehClass,
				model = vehModel,
			}
			trunkOpen = entity.entity
			SetVehicleHasBeenOwnedByPlayer(entity.entity, true)
			SetEntityAsMissionEntity(entity.entity, true, true)
			--SetVehicleDoorOpen(entity.entity, 5, true, false)
			plsr.Vehicles.Sync.Doors:Open(entity.entity, 5, false, false)
			PlayTrunkOpenAnim()
		end
	end)
end)

RegisterNetEvent("Inventory:Client:InUse", function(state)
	SendNUIMessage({
		type = "USE_IN_PROGRESS",
		data = {
			state = state,
		},
	})
end)

RegisterNetEvent("Inventory:Container:Move", function(from, to)
	if _container ~= nil and _container.Slot == from then
		_container.Slot = to
	end
end)

RegisterNetEvent("Inventory:Container:Remove", function(data, from)
	if _container ~= nil and _container.Slot == from then
		plsr.Inventory.Close:All()
	end
end)

RegisterNetEvent("Inventory:Client:SetSlot", function(owner, type, slot)
	if SecondInventory?.owner == owner and SecondInventory?.invType == type then
		plsr.Inventory.Set.Secondary:Slot(slot)
	else
		plsr.Inventory.Set.Player:Slot(slot)
	end
end)

local runningId = 0
RegisterNetEvent("Inventory:Client:Changed", function(type, item, count, slot)
	if type == "holster" then
		local equipped = plsr.Weapons:GetEquippedItem()
		if equipped ~= nil and equipped.Slot == slot and equipped.Name == item then
			type = "Holstered"
		else
			type = "Equipped"
		end
	end
	runningId = runningId + 1
	SendNUIMessage({
		type = "ADD_ALERT",
		data = {
			alert = {
				id = runningId,
				type = type,
				item = item,
				count = count,
			},
		},
	})
end)

-- Nearby dropzone if one already exists, else a fresh position-based one (same id format
-- CreateDZIfNotExist uses server-side). Pass existingOnly=true to get nil instead of
-- fabricating a new one, e.g. OpenInventory() checking "is a real drop nearby right now"
function GetGroundSecondary(existingOnly)
	local playerPed = PlayerPedId()
	local p = promise.new()

	plsr.Callbacks:ServerCallback("Inventory:CheckIfNearDropZone", {}, function(dropzone)
		if dropzone ~= nil then
			p:resolve({ invType = 10, owner = dropzone.id, position = dropzone.position })
		elseif existingOnly then
			p:resolve(nil)
		else
			local x, y, z = table.unpack(GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 0, -0.99))
			if plsr.State.flags.isK9Ped then
				z = z + 0.5
			end
			p:resolve({
				invType = 10,
				owner = string.format("%s:%s:%s", math.ceil(x), math.ceil(y), plsr.State.flags.currentRoute),
				position = vector3(x, y, z),
			})
		end
	end)

	return Citizen.Await(p)
end

-- Fired from the NUI when a held item is dropped outside any pane. Resolves
-- (or creates) the ground dropzone at the player's position server-side,
-- then moves the item into it — reuses the same DoMove path a drag onto an
-- already-open ground pane would take.
RegisterNUICallback("DropToGround", function(data, cb)
	local ground = GetGroundSecondary()
	plsr.Callbacks:ServerCallback("Inventory:Server:DropToGround", {
		item = data,
		ground = ground,
	}, function(result)
		if result then
			SecondInventory = ground
		end
		cb(result and true or false)
	end)
end)

function OpenInventory()
	if not plsr.Inventory:IsEnabled() then
		return
	end

	local playerPed = PlayerPedId()
	local isPedInVehicle = IsPedInAnyVehicle(playerPed, true)

	if isPedInVehicle then
		local v = GetVehiclePedIsIn(playerPed)
		local vin = v ~= nil and v > 0 and plsr.State.Entity(v).VIN or nil

		if vin == nil then
			plsr.Inventory.Open:Player(false)
			return
		end

		local vehClass = GetVehicleClass(v)
		local vehModel = GetEntityModel(v)
		plsr.Callbacks:ServerCallback("Inventory:OpenGlovebox", {
			netId = VehToNet(v),
			class = vehClass,
			model = vehModel,
		}, function(granted)
			if granted then
				SecondInventory = {
					netId = VehToNet(v),
					invType = 5,
					owner = vin,
					class = vehClass,
					model = vehModel,
				}
				plsr.Inventory.Open:Player(true)
			else
				plsr.Inventory.Open:Player(false)
			end
		end)
		return
	end

	local requestSecondary = false
	if _inInvPoly ~= nil then
		SecondInventory = { invType = _inInvPoly.inventory.invType, owner = _inInvPoly.inventory.owner }
		requestSecondary = true
	else
		local ground = GetGroundSecondary(true)
		if ground ~= nil then
			SecondInventory = ground
			requestSecondary = true
		end
	end

	plsr.Inventory.Open:Player(requestSecondary)
end

RegisterNUICallback("MergeSlot", function(data, cb)
	cb("OK")
	data.class = SecondInventory.class
	data.model = SecondInventory.model
	data.inventory = SecondInventory

	plsr.Callbacks:ServerCallback("Inventory:MergeItem", data, function(success)
		if success and success.success then
			if SecondInventory.netId then
				local veh = NetToVeh(SecondInventory.netId)
				if veh then
					local vEnt = plsr.State.Entity(veh)
					if vEnt and not vEnt.Owned and not vEnt.PleaseDoNotFuckingDelete then
						TriggerServerEvent("Vehicles:Server:StopDespawn", SecondInventory.netId)
					end
				end
			end
			if SecondInventory ~= nil and SecondInventory.invType == 10 and (data.ownerFrom ~= data.ownerTo) then
				dropAnim(data.invTypeTo == 10)
			end
		else
			if success and success.reason then
				plsr.Notification:Error(success.reason, 3600)
			end
		end
	end)
end)

RegisterNUICallback("SwapSlot", function(data, cb)
	cb("OK")
	data.class = SecondInventory.class
	data.model = SecondInventory.model
	data.inventory = SecondInventory

	plsr.Callbacks:ServerCallback("Inventory:SwapItem", data, function(success)
		if success and success.success then
			if SecondInventory.netId then
				local veh = NetToVeh(SecondInventory.netId)
				if veh then
					local vEnt = plsr.State.Entity(veh)
					if vEnt and not vEnt.Owned and not vEnt.PleaseDoNotFuckingDelete then
						TriggerServerEvent("Vehicles:Server:StopDespawn", SecondInventory.netId)
					end
				end
			end
			if SecondInventory ~= nil and SecondInventory.invType == 10 and (data.ownerFrom ~= data.ownerTo) then
				dropAnim(data.invTypeTo == 10)
			end
		else
			if success and success.reason then
				plsr.Notification:Error(success.reason, 3600)
			end
		end
	end)
end)

RegisterNUICallback("MoveSlot", function(data, cb)
	cb("OK")
	data.class = SecondInventory.class
	data.model = SecondInventory.model
	data.inventory = SecondInventory

	plsr.Callbacks:ServerCallback("Inventory:MoveItem", data, function(success)
		if success and success.success then
			if SecondInventory.netId then
				local veh = NetToVeh(SecondInventory.netId)
				if veh then
					local vEnt = plsr.State.Entity(veh)
					if vEnt and not vEnt.Owned and not vEnt.PleaseDoNotFuckingDelete then
						TriggerServerEvent("Vehicles:Server:StopDespawn", SecondInventory.netId)
					end
				end
			end
			if SecondInventory ~= nil and SecondInventory.invType == 10 and (data.ownerFrom ~= data.ownerTo) then
				dropAnim(data.invTypeTo == 10)
			end
		else
			if success and success.reason then
				plsr.Notification:Error(success.reason, 3600)
			end
		end
	end)
end)

RegisterNUICallback("SendNotify", function(data, cb)
	cb("OK")
	if data then
		if data.alert == "success" then
			plsr.Notification:Success(data.message, data.time)
		elseif data.alert == "warning" then
			plsr.Notification:Warning(data.message, data.time)
		elseif data.alert == "error" then
			plsr.Notification:Error(data.message, data.time)
		end
	end
end)

RegisterNUICallback("UseItem", function(data, cb)
	cb("OK")
	if plsr.State.flags.doingAction then
		return
	end
	plsr.Callbacks:ServerCallback("Inventory:UseItem", {
		slot = data.slot,
		owner = data.owner,
		invType = data.invType,
	}, function(success) end)
end)

RegisterNetEvent("Inventory:CloseUI", function()
	startCd()
	plsr.Inventory.Close:All()
	plsr.Inventory:Enable()
end)

RegisterNetEvent("Inventory:Client:UpdateMetadata", function(slot, md, key)
	plsr.Inventory:UpdateCachedMD(slot, md, key)
end)

local _shops = {}
RegisterNetEvent("Inventory:Client:BasicShop:Set", function(shops)
	_shops = shops
	for k, v in pairs(shops) do
		local menus = {
			{
				icon = "sack-dollar",
				text = v.name or "Shop",
				event = "Shop:Client:BasicShop:Open",
				data = v.id,
				isEnabled = function(data, ent)
					return GlobalState[string.format("BasicShop:%s", data)]
				end,
			}
		}
	
		if v.job == nil and plsr.State.flags.loggedIn and v.owner == plsr.State.character.SID then
			table.insert(menus, {
				icon = "sack-dollar",
				text = "Add Shop Moderator",
				event = "Shop:Client:BasicShop:AddModerator",
				data = v.id,
			})
			table.insert(menus, {
				icon = "bars",
				text = "View Shop Moderator",
				event = "Shop:Client:BasicShop:ViewModerators",
				data = v.id,
			})
			table.insert(menus, {
				icon = "octagon-check",
				text = "Open Shop",
				event = "Shop:Client:BasicShop:OpenShop",
				data = v.id,
				isEnabled = function(data, ent)
					return not GlobalState[string.format("BasicShop:%s", data)]
				end,
			})
			table.insert(menus, {
				icon = "octagon-xmark",
				text = "Close Shop",
				event = "Shop:Client:BasicShop:CloseShop",
				data = v.id,
				isEnabled = function(data, ent)
					return GlobalState[string.format("BasicShop:%s", data)]
				end,
			})
		else
			if plsr.Jobs.Permissions:HasPermissionInJob(v.job, "JOB_SHOP_CONTROL") then
				table.insert(menus, {
					icon = "octagon-check",
					text = "Open Shop",
					event = "Shop:Client:BasicShop:OpenShop",
					data = v.id,
					isEnabled = function(data, ent)
						return not GlobalState[string.format("BasicShop:%s", data)]
					end,
				})
				table.insert(menus, {
					icon = "octagon-xmark",
					text = "Close Shop",
					event = "Shop:Client:BasicShop:CloseShop",
					data = v.id,
					isEnabled = function(data, ent)
						return GlobalState[string.format("BasicShop:%s", data)]
					end,
				})
			end
		end
		
		plsr.PedInteraction:Add(
			"player-shop-" .. v.id,
			GetHashKey(v.ped_model or 'S_F_Y_SweatShop_01'),
			vector3(v.position.x, v.position.y, v.position.z),
			v.position.h,
			25.0,
			menus,
			"shop"
		)
	end
end)

RegisterNetEvent("Characters:Client:Logout", function()
	for k, v in pairs(_shops) do
		plsr.PedInteraction:Remove("player-shop-" .. v.id)
	end
end)

RegisterNetEvent("Inventory:Client:BasicShop:Create", function(shop)
	local menus = {
		{
			icon = "sack-dollar",
			text = shop.name or "Shop",
			event = "Shop:Client:BasicShop:Open",
			data = shop.id,
			isEnabled = function(data, ent)
				return GlobalState[string.format("BasicShop:%s", data)]
			end,
		}
	}

	if shop.job == nil and plsr.State.flags.loggedIn and tonumber(shop.owner) == plsr.State.character.SID then
		table.insert(menus, {
			icon = "sack-dollar",
			text = "Add Shop Moderator",
			event = "Shop:Client:BasicShop:AddModerator",
			data = shop.id,
		})
		table.insert(menus, {
			icon = "octagon-check",
			text = "Open Shop",
			event = "Shop:Client:BasicShop:OpenShop",
			data = shop.id,
			isEnabled = function(data, ent)
				return not GlobalState[string.format("BasicShop:%s", data)]
			end,
		})
		table.insert(menus, {
			icon = "octagon-xmark",
			text = "Close Shop",
			event = "Shop:Client:BasicShop:CloseShop",
			data = shop.id,
			isEnabled = function(data, ent)
				return GlobalState[string.format("BasicShop:%s", data)]
			end,
		})
	else
		if plsr.Jobs.Permissions:HasPermissionInJob(shop.job, "JOB_SHOP_CONTROL") then
			table.insert(menus, {
				icon = "octagon-check",
				text = "Open Shop",
				event = "Shop:Client:BasicShop:OpenShop",
				data = shop.id,
				isEnabled = function(data, ent)
					return not GlobalState[string.format("BasicShop:%s", data)]
				end,
			})
			table.insert(menus, {
				icon = "octagon-xmark",
				text = "Close Shop",
				event = "Shop:Client:BasicShop:CloseShop",
				data = shop.id,
				isEnabled = function(data, ent)
					return GlobalState[string.format("BasicShop:%s", data)]
				end,
			})
		end
	end


	plsr.PedInteraction:Add(
		"player-shop-" .. shop.id,
		GetHashKey(shop.ped_model or 'S_F_Y_SweatShop_01'),
		vector3(shop.position.x, shop.position.y, shop.position.z),
		shop.position.h,
		25.0,
		menus,
		"shop"
	)
end)

RegisterNetEvent("Inventory:Client:BasicShop:Delete", function(shopId)
	plsr.PedInteraction:Remove("player-shop-" .. shopId)
end)

RegisterNUICallback("AddToShop", function(data, cb)
	plsr.Callbacks:ServerCallback("Inventory:PlayerShop:AddItem", data, cb)
end)

RegisterNetEvent("StoreFailedPurchase", function(data)
	SendNUIMessage({
		type = "SET_INVENTORIES",
		data = data,
	})
end)

AddEventHandler("Shop:Client:BasicShop:Open", function(obj, shopId)
	plsr.Inventory.PlayerShop:Open(shopId)
end)

AddEventHandler("Shop:Client:BasicShop:AddModerator", function(obj, shopId)
	plsr.Input:Show(
		"Add Shop Moderator",
		"Add Shop Moderator",
		{
			{
				id = "sid",
				type = "number",
				options = {
					inputProps = {
						maxLength = 11,
					},
				},
			},
		},
		"Shop:Client:BasicShop:AddModeratorInput",
		shopId
	)
end)

AddEventHandler("Shop:Client:BasicShop:AddModeratorInput", function(values, shopId)
	plsr.Callbacks:ServerCallback("Inventory:PlayerShop:AddModerator", {
		shop = shopId,
		sid = values.sid
	})
end)

AddEventHandler("Shop:Client:BasicShop:ViewModerators", function(obj, shopId)
	plsr.Callbacks:ServerCallback("Inventory:PlayerShop:ViewModerators", shopId, function(list)
		if list then
			plsr.ListMenu:Show({
				main = {
					label = "Shop Moderators",
					items = list,
				},
			})
		end
	end)
end)

AddEventHandler("Shop:Client:BasicShop:RemoveModerator", function(data)
	plsr.Callbacks:ServerCallback("Inventory:PlayerShop:RemoveModerator", data)
end)

AddEventHandler("Shop:Client:BasicShop:OpenShop", function(obj, shopId)
	plsr.Callbacks:ServerCallback("Inventory:PlayerShop:ChangeState", {
		id = shopId,
		state = true
	})
end)

AddEventHandler("Shop:Client:BasicShop:CloseShop", function(obj, shopId)
	plsr.Callbacks:ServerCallback("Inventory:PlayerShop:ChangeState", {
		id = shopId,
		state = false
	})
end)