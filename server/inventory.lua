LoadedEntitys = {}
ItemCallbacks = {}
createdInventories = {}

GlobalState["Dropzones"] = {}
_polyInvs = {}
_openInvs = {}
_doingThings = {}
_exitSaving = {}

-- Server-authority hardening: tracks which secondary inventory each source
-- has actually been granted (_pendingOpen, short-lived, consumed by
-- Inventory:Server:Request) or is currently holding open (_openSecondary,
-- cleared on close/disconnect). See validateInventoryAccess() below.
_pendingOpen = {}
_openSecondary = {}
_govAccount = nil
_hasAttchs = {}

_refreshAttchs = {}
_refreshGangChain = {}

_dropzones = {}

_equipped = {}
_cachedProps = {}

_invCounts = {}
_cachedInvs = {}

_playerShops = {}
_playerShopMods = {}

_lastUsedItem = {}

local _defInvSettings = {
	muted = false,
	useBank = true,
}

function split(pString, pPattern)
	local Table = {}  -- NOTE: use {n = 0} in Lua-5.0
	local fpat = "(.-)" .. pPattern
	local last_end = 1
	local s, e, cap = pString:find(fpat, 1)
	while s do
	   if s ~= 1 or cap ~= "" then
	  table.insert(Table,cap)
	   end
	   last_end = e+1
	   s, e, cap = pString:find(fpat, last_end)
	end
	if last_end <= #pString then
	   cap = pString:sub(last_end)
	   table.insert(Table, cap)
	end
	return Table
end

function ValueContined(tbl, value)
	for k, v in ipairs(tbl) do
		if v == value then
			return true
		end
	end
	return false
end

function BuildMetaDataTable(cData, item, existing)
	local itemExist = itemsDatabase[item]
	local MetaData = deepcopy(existing or {})
	
	if itemExist.staticMetadata ~= nil then
		for k, v in pairs(itemExist.staticMetadata) do
			MetaData[k] = v
		end
	end

	if itemExist.type == 2 then
		if not MetaData.SerialNumber and not itemExist.noSerial then
			if MetaData.Scratched then
				MetaData.ScratchedSerialNumber = plsr.Weapons:Purchase(cData.SID, itemExist, true, MetaData.Company)
				MetaData.Scratched = nil
			else
				MetaData.SerialNumber = plsr.Weapons:Purchase(cData.SID, itemExist, false, MetaData.Company)
			end
			MetaData.Company = nil
		end

		MetaData.ammo = MetaData.ammo or 0
		MetaData.clip = MetaData.clip or 0
	elseif itemExist.type == 10 and not MetaData.Container then
		MetaData.Container = string.format("container:%s", plsr.Sequence:Get("Container"))
	elseif itemExist.type == 11 and not MetaData.Quality then
		MetaData.Quality = math.random(100)
	elseif itemExist.name == "govid" then
		local genStr = "Male"
		if cData.Gender == 1 then
			genStr = "Female"
		end
		MetaData.Name = string.format("%s %s", cData.First, cData.Last)
		MetaData.Gender = genStr
		MetaData.PassportID = cData.User
		MetaData.StateID = cData.SID
		MetaData.DOB = cData.DOB
		MetaData.Mugshot = cData.Mugshot
	elseif itemExist.name == "moneybag" and not MetaData.Finish then
		MetaData.Finished = os.time() + (60 * 60 * 24 * math.random(1, 3))
	elseif itemExist.name == "crypto_voucher" and not MetaData.CryptoCoin and not MetaData.Quantity then
		MetaData.CryptoCoin = "MALD"
		MetaData.Quantity = math.random(25, 50)
	elseif itemExist.name == "rep_voucher" and not MetaData.Reputation and not MetaData.Amount then
		MetaData.Reputation = "Farming"
		MetaData.Amount = math.random(1000, 5000)
	elseif itemExist.name == "vpn" then
		MetaData.VpnName = {
			First = plsr.Generator.Name:First(),
			Last = plsr.Generator.Name:Last(),
		}
	elseif itemExist.name == "cigarette_pack" then
		MetaData.Count = 30
	elseif itemExist.name == "rusty_strawsprinkbox" then
		MetaData.Count = 10
	elseif itemExist.name == "rusty_ringmixbox" then
		MetaData.Count = 6
	elseif itemExist.name == "rusty_ringbox" then
		MetaData.Count = 12
	elseif itemExist.name == "rusty_pd" then
		MetaData.Count = 12
	elseif itemExist.name == "meth_table" and not MetaData.MethTable then
		MetaData.MethTable = plsr.Drugs.Meth:GenerateTable(1)
	elseif itemExist.name == "adv_meth_table" and not MetaData.MethTable then
		MetaData.MethTable = plsr.Drugs.Meth:GenerateTable(2)
	elseif itemExist.name == "meth_brick" then
			MetaData.Finished = os.time() + (60 * 60 * 24)
	elseif itemExist.name == "moonshine_still" and not MetaData.Still then
		MetaData.Still = plsr.Drugs.Moonshine.Still:Generate(1)
	elseif itemExist.name == "moonshine_barrel" and not MetaData.Brew then
		MetaData.Brew = plsr.Drugs.Moonshine.Barrel:Generate(1)
	elseif itemExist.name == "paleto_access_codes" and not MetaData.AccessCodes then
		MetaData.AccessCodes = {
			plsr.Robbery:GetAccessCodes('paleto')[1]
		}
	elseif itemExist.name == "lsundg_invite" and cData then
		MetaData.Inviter = {
			SID = cData.SID,
			First = cData.First,
			Last = cData.Last
		}
	elseif (itemExist.name == "pd_panic_button" or itemExist.name == "doc_panic_button" or itemExist.name == "ems_panic_button") and cData then
		MetaData.Officer = {
			Callsign = cData.Callsign or "???",
			First = cData.First,
			Last = cData.Last,
			SID = cData.SID,
		}
	elseif itemExist.name == "shark_card" and not MetaData.Amount then
		MetaData.Amount = math.random(5000, 25000)
	end

	return MetaData
end

function EnsureInventorySchema()
	MySQL.query.await([[
		CREATE TABLE IF NOT EXISTS `inventory` (
			`id` int(11) NOT NULL AUTO_INCREMENT,
			`owner` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
			`type` int(11) unsigned NOT NULL DEFAULT 0,
			`slots` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci NOT NULL DEFAULT '[]' CHECK (json_valid(`slots`)),
			`updatedAt` bigint(20) NOT NULL DEFAULT 0,
			PRIMARY KEY (`id`) USING BTREE,
			UNIQUE KEY `owner_type` (`owner`,`type`) USING BTREE
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci
	]])
end

CreateThread(function()
	EnsureInventorySchema()
	UpdateDatabaseItems()
	LoadItemsFromDb()
	--LoadItems()
	RegisterCallbacks()
	LoadEntityTypes()
	LoadShops()
	LoadPlayerShops()
	SetupGarbage()

	ClearDropZones()
	ClearBrokenItems()
	ClearLocalVehicleInventories()
	CleanupExpiredCooldowns()
	LoadCraftingCooldowns()

	RegisterCommands()
	RegisterStashCallbacks()
	RegisterTestBench()
	RegisterPublicSchematicBenches()
	RegisterCraftingCallbacks()
	RegisterDonorVanityItemsCallbacks()

	local f = plsr.Banking.Accounts:GetOrganization("government")
	if f ~= true then
		_govAccount = f.Account
	end

	plsr.Middleware:Add("Characters:Spawning", function(source)
		TriggerLatentClientEvent("Inventory:Client:PolySetup", source, 50000, _polyInvs)

		local char = plsr.Fetch:CharacterSource(source)
		local sid = char:GetData("SID")

		if Config.CashAsItem then
			local cashDelta = (char:GetData("Cash") or 0) - INVENTORY.Items:GetCount(sid, 1, Config.CashAsItem)
			if cashDelta ~= 0 then
				INVENTORY:AdjustCashItem(sid, cashDelta)
			end
		end

		_refreshAttchs[sid] = true
		_refreshGangChain[sid] = true
		refreshShit(sid, true)

		TriggerLatentClientEvent("Weapons:Client:SetProps", source, 50000, _cachedProps)
		if char:GetData("InventorySettings") == nil then
			char:SetData("InventorySettings", _defInvSettings)
		end
	end, 1)

	plsr.Middleware:Add("Characters:Spawning", function(source)
		local benches = {}
		for k, v in pairs(_types) do
			table.insert(benches, {
				id = v.id,
				label = v.label,
				targeting = v.targeting,
				location = v.location,
				restrictions = v.restrictions,
				canUseSchematics = v.canUseSchematics,
			})
		end
		TriggerLatentClientEvent("Crafting:Client:CreateBenches", source, 50000, benches)
		TriggerLatentClientEvent("Inventory:Client:DropzoneForceUpdate", source, 50000, _dropzones)
		TriggerLatentClientEvent("Inventory:Client:BasicShop:Set", source, 50000, _playerShops)
	end, 2)

	plsr.Middleware:Add("Characters:Created", function(source, cData)
		local player = plsr.Fetch:Source(source)
		local docs = {}

		local slot = 1
		for k, v in ipairs(Config.StartItems) do
			local metadata = BuildMetaDataTable(cData, v.name)

			if v.name == "choplist" then
				metadata.ChopList = plsr.Laptop.LSUnderground.Chopping:GenerateList(math.random(4, 8), math.random(3, 5))
				metadata.Owner = cData.SID
			end

			local insData = INVENTORY:AddItem(cData.SID, v.name, v.countTo, metadata, 1, false, false, false, false, slot, false, false, true)
			slot += 1
		end

		return true
	end, 2)
end)

local function HandleLogout(source, cData)
	for k, v in pairs(_openInvs) do
		if v == source then
			_openInvs[k] = false
		end
	end

	_cachedInvs[source] = nil
	_equipped[source] = nil

	TriggerClientEvent("Weapons:Client:ClearWeaponProps", -1, source)

	if cData ~= nil then
		_cachedInvs[string.format("%s-1", cData.SID)] = nil
		_invCounts[cData.SID] = nil
	end

	_lastUsedItem[source] = nil
end
AddEventHandler("Characters:Server:PlayerLoggedOut", HandleLogout)
AddEventHandler("Characters:Server:PlayerDropped", HandleLogout)

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["pulsar_core"]:RegisterComponent("Inventory", INVENTORY)
end)

AddEventHandler("Queue:Server:SessionActive", function(source)
	TriggerLatentClientEvent("Inventory:Client:LoadItems", source, 50000, itemsDatabase)
end)

RegisterNetEvent("Inventory:Server:ReloadItems", function()
	local src = source
	TriggerLatentClientEvent("Inventory:Client:ReceiveReload", source, 50000, itemsDatabase)
end)

RegisterServerEvent("Inventory:server:closePlayerInventory", function()
	local src = source
	local char = plsr.Fetch:CharacterSource(src)
	if char ~= nil then
		_openInvs[string.format("%s-%s", char:GetData("SID"), 1)] = false
		refreshShit(char:GetData("SID"), true)
	end
end)

RegisterNetEvent("Inventory:Server:DegradeLastUsed", function(degradeAmt)
	local src = source
	local char = plsr.Fetch:CharacterSource(src)
	if char ~= nil then
		if _lastUsedItem[src] then
			local slot = plsr.Inventory:GetItem(_lastUsedItem[src])

			if slot then
				local itemData = itemsDatabase[slot.Name]

				local newValue = slot.CreateDate - math.floor(itemData.durability * (degradeAmt / 100))

				if (os.time() - itemData.durability >= newValue) then
					plsr.Inventory.Items:RemoveId(slot.Owner, slot.invType, slot)
				else
					plsr.Inventory:SetItemCreateDate(slot.id, newValue)
				end
			end

		end
	end
end)

function sendRefreshForClient(_src, owner, invType, slot)
	--local data = Inventory:GetSlot(owner, slot, invType)
	TriggerClientEvent("Inventory:Client:SetSlot", _src, owner, invType, slot)
end

function SetGunPropData(source, sid, inv, isForce)
	local data = {}
	for k, v in ipairs(inv or {}) do
		local itemData = itemsDatabase[v.Name]
		if WEAPON_PROPS[itemData?.weapon or v.Name] then
			local md = v.MetaData
			data[string.format("i-%s", v.id)] = {
				item = v.Name,
				weapon = itemData?.weapon or v.Name,
				tint = md?.WeaponTint or false,
				attachments = md?.WeaponComponents or false,
				slot = v.Slot,
				equipped = _equipped[source] == v.Slot,
			}
		end
	end

	local needsUpdate = isForce
	if not needsUpdate then
		if _cachedProps[source] ~= nil then
			for k, v in pairs(_cachedProps[source]) do
				if data[k] == nil or v.equipped ~= data[k].equipped then
					needsUpdate = true
					break
				end
			end
	
			for k, v in pairs(data) do
				if _cachedProps[source][k] == nil then
					needsUpdate = true
					break
				end
			end
		else
			needsUpdate = true
		end
	end

	if needsUpdate then
		_cachedProps[source] = data
		TriggerLatentClientEvent("Weapons:Client:UpdateProps", -1, 50000, source, data)
	end
end

local function isShopModerator(shop, source)
	local char = plsr.Fetch:CharacterSource(source)
	if char then
		local sid = char:GetData("SID")
		if _playerShops[shop] then
			if _playerShops[shop].owner == sid then
				return true
			else
				if _playerShops[shop].job ~= nil then
					return plsr.Jobs.Permissions:HasPermissionInJob(source, _playerShops[shop].job, 'JOB_SHOP')
				else
					if _playerShopMods[shop] then
						for k, v in ipairs(_playerShopMods[shop]) do
							if v.sid == sid then
								return true
							end
						end
					end
				end
			end
		end
	end

	return false
end

RegisterNetEvent("Weapons:Server:Equipped", function(state)
	local src = source
	_equipped[src] = tonumber(state)
	local char = plsr.Fetch:CharacterSource(src)
	if char ~= nil then
		SetGunPropData(src, char:GetData("SID"), _cachedInvs[src])
	end
end)

AddEventHandler("Queue:Server:SessionActive", function()
	-- local src = source
	-- for k, v in pairs(_cachedProps) do
	-- 	TriggerClientEvent("Weapons:Client:UpdateProps", src, k, v)
	-- end
end)

function refreshShit(sid, adding)
	local char = plsr.Fetch:SID(tonumber(sid))
	if char ~= nil then
		local source = char:GetData("Source")
		local inventory = getInventory(source, sid, 1)

		UpdateCharacterItemStates(source, inventory, true)

		if  _refreshGangChain[sid] then
			UpdateCharacterGangChain(source, inventory)
		end

		if _refreshAttchs[sid] ~= nil then
			SetGunPropData(source, sid, inventory)
		end

		TriggerClientEvent("Inventory:Client:Cache", source, {
			size = (LoadedEntitys[1].slots or 10),
			name = char:GetData("First") .. " " .. char:GetData("Last"),
			inventory = inventory,
			invType = 1,
			capacity = LoadedEntitys[1].capacity,
			owner = sid,
			isWeaponEligble = plsr.Weapons:IsEligible(source),
			qualifications = char:GetData("Qualifications") or {},
		}, _refreshAttchs[sid] ~= nil)

		_cachedInvs[source] = inventory

		_refreshAttchs[sid] = nil
		_refreshGangChain[sid] = nil
	end
end

function entityPermCheck(source, invType)
	local char = plsr.Fetch:CharacterSource(source)

	local shittyInvData = LoadedEntitys[invType]

	if shittyInvData then
		return (
				shittyInvData.restriction == nil
				or (shittyInvData.restriction.job ~= nil and plsr.Jobs.Permissions:HasJob(
					source,
					shittyInvData.restriction.job.id,
					shittyInvData.restriction.job.workplace or false,
					shittyInvData.restriction.job.grade or false,
					false,
					false,
					shittyInvData.restriction.job.permissionKey or "JOB_STORAGE"
				) and (not shittyInvData.restriction.job.duty or plsr.State:Player(source).onDuty == shittyInvData.restriction.job.id))
				or (shittyInvData.restriction.state and hasValue(
					char:GetData("States"),
					shittyInvData.restriction.state
				))
				or (
					shittyInvData.restriction.rep ~= nil
					and plsr.Reputation:GetLevel(source, shittyInvData.restriction.rep.id) >= shittyInvData.restriction.rep.level
				)
				or (shittyInvData.restriction.character ~= nil and shittyInvData.restriction.character == char:GetData(
					"ID"
				))
				or (shittyInvData.restriction.admin and plyr.Permissions:IsAdmin())
			)
	else
		return false
	end
end

-- Grants source a short-lived claim on owner/invType, consumed by Inventory:Server:Request
function grantPendingOpen(source, owner, invType)
	_pendingOpen[source] = { owner = owner, invType = invType, expiresAt = os.time() + 15 }
end

-- invType==1 isn't always "own inventory" (Search/Rob open invType 1 with the target's SID)
function validateInventoryAccess(source, owner, invType)
	if invType == 1 then
		local char = plsr.Fetch:CharacterSource(source)
		if char and tostring(owner) == tostring(char:GetData("SID")) then
			return true
		end
	end

	if invType == 10 then
		local x, y, route = tostring(owner):match("^(-?%d+):(-?%d+):(%d+)$")
		if not x then return false end
		if tonumber(route) ~= plsr.State:Player(source).currentRoute then return false end

		local ped = GetPlayerPed(source)
		if ped == 0 then return false end

		local coords = GetEntityCoords(ped)
		return #(vector2(coords.x, coords.y) - vector2(tonumber(x), tonumber(y))) < 3.0
	end

	local granted = _openSecondary[source]
	return granted ~= nil and tostring(granted.owner) == tostring(owner) and granted.invType == invType
end

function getShopSlot(src, Owner, Type, slotId)
	if LoadedEntitys[tonumber(Type)].shop then
		if entityPermCheck(src, Type) then
			local char = plsr.Fetch:CharacterSource(src)
			local slots = getInventory(src, Owner, Type)
			local slot = slots[slotId]
			if slot then
				local item, stack, price = nil, nil, nil
				if itemsDatabase[slot.Name] ~= nil then
					if not slot.job or plsr.Jobs.Permissions:HasJob(src, slot.job) then
						return slot
					end
				end
			end
		end
	end

	return nil
end

function getShopSize(src, Owner, Type)
	if LoadedEntitys[tonumber(Type)].shop then
		if entityPermCheck(src, Type) then
			return #getInventory(src, Owner, Type)
		end
	end

	return 0
end

function getInventory(src, Owner, Type, limit)
	if LoadedEntitys[tonumber(Type)].shop then
		local char = plsr.Fetch:CharacterSource(src)

		local items = {}
		if entityPermCheck(src, Type) then
			for k, v in ipairs(Config.ShopItemSets[LoadedEntitys[Type].itemSet]) do
				local item, stack, price = nil, nil, nil
				if type(v) == "table" then
					if itemsDatabase[v.item] ~= nil then
						if not v.job or plsr.Jobs.Permissions:HasJob(src, v.job) then
							item = v.item
							stack = v.count or itemsDatabase[v.item].isStackable or 1
							price = v.price or itemsDatabase[v.item].price or 0
						end
					end
				else
					if itemsDatabase[v] ~= nil then
						item = v
						stack = itemsDatabase[v].storeStack or itemsDatabase[v].isStackable

						if not itemsDatabase[v].isStackable then
							stack = 1
						end
	
						if itemsDatabase[v].isStackable and stack > itemsDatabase[v].isStackable then
							stack = itemsDatabase[v].isStackable
						end
						price = itemsDatabase[v].price or 0
					end
				end

				if item then
					local doc = {
						Slot = #items + 1,
						Label = itemsDatabase[item].label,
						Count = stack,
						Name = item,
						invType = Type,
						Quality = nil,
						MetaData = {},
						Owner = tostring(Owner),
						Price = price,
					}

					table.insert(items, doc)
				end
			end
		end
		return items
	else
		local slots = LoadInventoryRaw(Owner, Type)
		local inv = {}

		for i = 1, #slots do
			table.insert(inv, SlotEntryToDoc(Owner, Type, slots[i]))
		end

		table.sort(inv, function(a, b) return a.Slot < b.Slot end)
		_cachedInvs[string.format("%s-%s", Owner, Type)] = inv

		if Type == 1 then
			_invCounts[Owner] = {}
			for k, v in ipairs(inv) do
				_invCounts[Owner][v.Name] = _invCounts[Owner][v.Name] or 0
				_invCounts[Owner][v.Name] += v.Count
			end
		end

		return inv
	end
end

function getSlotCount(invType, vehClass, vehModel, override, owner, src)
	if override then
		return override
	end

	if LoadedEntitys[tonumber(invType)].isTrunk and (vehClass or vehModel) then
		if vehModel and _modelOverride[vehModel] ~= nil then
			return _modelOverride[vehModel].trunk.slots
		else
			return _trunkSizes[vehClass].slots
		end
	elseif LoadedEntitys[tonumber(invType)].isGlovebox and (vehClass or vehModel) then
		if vehModel and _modelOverride[vehModel] ~= nil then
			return _modelOverride[vehModel].glovebox.slots
		else
			return _gloveboxSizes[vehClass].slots
		end
	elseif LoadedEntitys[tonumber(invType)].shop and LoadedEntitys[tonumber(invType)].itemSet ~= nil and Config.ShopItemSets[LoadedEntitys[tonumber(invType)].itemSet] ~= nil then
		return getShopSize(src, owner, invType)
	else
		return LoadedEntitys[tonumber(invType)].slots
	end
end

function getCapacity(invType, vehClass, vehModel, override)
	if override then
		return override
	end

	if LoadedEntitys[tonumber(invType)].isTrunk and (vehClass or vehModel) then
		if vehModel and _modelOverride[vehModel] ~= nil then
			return _modelOverride[vehModel].trunk.capacity
		else
			return _trunkSizes[vehClass].capacity
		end
	elseif LoadedEntitys[tonumber(invType)].isGlovebox and (vehClass or vehModel) then
		if vehModel and _modelOverride[vehModel] ~= nil then
			return _modelOverride[vehModel].glovebox.capacity
		else
			return _gloveboxSizes[vehClass].capacity
		end
	else
		return LoadedEntitys[tonumber(invType)].capacity
	end
end

function CreateStoreLog(inventory, item, count, buyer, metadata, itemId)
	MySQL.insert('INSERT INTO inventory_shop_logs (inventory, item, count, buyer, metadata, itemId) VALUES(?, ?, ?, ?, ?, ?)', {
		inventory, item, count, buyer, json.encode(metadata), itemId
	})
end

-- destination weight + incoming item vs capacity; displacedWeight subtracts a swapped-out item
function checkDestWeight(data, item, displacedWeight)
	if data.ownerFrom == data.ownerTo and data.invTypeFrom == data.invTypeTo then
		return true
	end
	local destWeight = INVENTORY.Items:GetWeights(data.ownerTo, data.invTypeTo) - (displacedWeight or 0) + (item.weight or 0) * tonumber(data.countTo)
	local destCapacity = getCapacity(tonumber(data.invTypeTo), data.vehClassTo, data.vehModelTo, data.capacityOverrideTo)
	return destWeight <= destCapacity
end

-- true if a container item is about to be dropped into the storage it itself owns - the item is the only key
-- back into that storage, so trapping it inside makes the storage permanently unreachable
function isContainerOwnStorage(item, slotEntry, ownerTo)
	return item.type == 10 and slotEntry.MetaData?.Container ~= nil and ownerTo == ("container:%s"):format(slotEntry.MetaData.Container)
end

function DoMerge(source, data, cb)
	local char = plsr.Fetch:CharacterSource(source)

	local item = itemsDatabase[data.name]
	local cash = char:GetData("Cash")

	local entityFrom = LoadedEntitys[tonumber(data.invTypeFrom)]
	local entityTo = LoadedEntitys[tonumber(data.invTypeTo)]

	if data.ownerFrom == nil or data.slotFrom == nil or data.invTypeFrom == nil or data.ownerTo == nil or data.slotTo == nil or data.invTypeTo == nil then
		cb({ reason = "Invalid Move Data" })
		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
		return
	end

	if data.countTo <= 0 then
		cb({ reason = "Can't Move 0 - Naughty Boy" })
		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
		return
	end

	-- shop/playerShop branches gate ownerFrom themselves below; every other case had no check at all
	if not validateInventoryAccess(source, data.ownerTo, tonumber(data.invTypeTo)) or (not entityFrom.shop and not entityFrom.playerShop and not validateInventoryAccess(source, data.ownerFrom, tonumber(data.invTypeFrom))) then
		cb({ reason = "No Access To That Inventory" })
		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
		return
	end

	-- shop branch skips locking the destination here since AddItem locks it itself below
	local lockKeys = {}
	if not entityFrom.shop then
		table.insert(lockKeys, ("%s:%s"):format(data.ownerFrom, data.invTypeFrom))
		local toKey = ("%s:%s"):format(data.ownerTo, data.invTypeTo)
		if toKey ~= lockKeys[1] then
			table.insert(lockKeys, toKey)
		end
	end
	local lock <close> = AcquireLocks(lockKeys)
	if not lock then
		cb({ reason = "Item Currently Being Moved" })
		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
		return
	end

	if not checkDestWeight(data, item) then
		cb({ reason = "Too Heavy" })
		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
		return
	end

	if entityFrom.shop then
		local slotFrom = getShopSlot(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		local cost = math.ceil(((slotFrom?.Price or item.price) * tonumber(data.countTo)))
		local paymentType = (cash >= cost and 'cash' or (plsr.Banking.Balance:Has(char:GetData("BankAccount"), cost) and 'bank' or nil))
		if entityFrom.free or paymentType ~= nil then
			if -- Check if the item is either not a gun, or if it is that they have a Weapons license
				(item.type ~= 2
				or (
					item.type == 2
					and (not item.requiresLicense or item.requiresLicense and plsr.Weapons:IsEligible(source))
				))
				and (not item.qualification or hasValue(char:GetData("Qualifications"), item.qualification))
			then
				local paid = cost == 0 or entityFrom.free

				if not paid then
					if paymentType == 'cash' then
						paid = plsr.Wallet:Modify(source, -(math.abs(cost)))
					else
						paid = plsr.Banking.Balance:Charge(char:GetData("BankAccount"), cost, {
							type = 'bill',
							title = 'Store Purchase',
							description = string.format('Bought x%s %s', data.countTo, item.label),
							data = {}
						})
						plsr.Phone.Notification:Add(source, "Bill Payment Successful", false, os.time(), 3000, "bank", {})
					end

					if paid then
						local bonk = storeBankAccounts[tostring(entityFrom.id)]
						if bank then
							pendingShopDeposits[bonk] = pendingShopDeposits[bonk] or { amount = 0, transactions = 0 }
							pendingShopDeposits[bonk].amount += math.floor( (cost * STORE_SHARE_AMOUNT) )
							pendingShopDeposits[bonk].transactions += 1
						end

						pendingShopDeposits[_govAccount] = pendingShopDeposits[_govAccount] or { amount = 0, transactions = 0, tax = true }
						pendingShopDeposits[_govAccount].amount += math.ceil(cost * (1.0 - STORE_SHARE_AMOUNT))
						pendingShopDeposits[_govAccount].transactions += 1
					end
				end

				if paid then
					local insData = INVENTORY:AddItem(char:GetData("SID"), data.name, data.countTo, {}, data.invTypeTo, false, false, false, false, data.slotTo, false, false, false, true)
					-- AddItem/AddSlot can genuinely fail (e.g. lost a slot race) - refund rather than take payment for nothing, matching ox_inventory's buyItem
					if not (insData and insData.id) then
						if not (cost == 0 or entityFrom.free) then
							if paymentType == 'cash' then
								plsr.Wallet:Modify(source, math.abs(cost))
							else
								plsr.Banking.Balance:Deposit(char:GetData("BankAccount"), cost, {
									type = 'refund',
									title = 'Store Purchase Refund',
									description = string.format('Refunded x%s %s (Purchase Failed)', data.countTo, item.label),
									data = {},
								})
							end
						end

						sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
						sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
						return cb({ reason = "Failed To Add Item, Refunded" })
					end

					CreateStoreLog(data.ownerFrom, data.name, data.countTo or 1, char:GetData("SID"), insData.MetaData, 0)
				end

				sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
				sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
				return cb({ success = true })
			else
				sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
				sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
				cb({ reason = "Ineligible To Purchase Item" })
			end
		else
			sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
			sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
			cb({ reason = "Not Enough Cash" })
		end
	elseif entityFrom.playerShop and data.ownerFrom ~= data.ownerTo and data.invTypeFrom ~= data.invTypeTo then
		if _playerShops[data.ownerFrom] then
			local isMod = isShopModerator(data.ownerFrom, source)
			local slotFrom = INVENTORY:GetSlot(data.ownerFrom, data.slotFrom, data.invTypeFrom)
			local slotTo = INVENTORY:GetSlot(data.ownerTo, data.slotTo, data.invTypeTo)

			if slotFrom ~= nil then
				local cost = math.ceil((slotFrom.Price * tonumber(data.countTo)))
				local paymentType = (cash >= cost and 'cash' or (plsr.Banking.Balance:Has(char:GetData("BankAccount"), cost) and 'bank' or nil))
	
				if cost == 0 or paymentType ~= nil or isMod then
					local paid = cost == 0 or isMod

					if not paid then
						if paymentType == 'cash' then
							paid = plsr.Wallet:Modify(source, -(math.abs(cost)))
						else
							paid = plsr.Banking.Balance:Charge(char:GetData("BankAccount"), cost, {
								type = 'bill',
								title = 'Store Purchase',
								description = string.format('Bought x%s %s From %s', data.countTo, item.label, _playerShops[data.ownerFrom].name),
								data = {}
							})
							plsr.Phone.Notification:Add(source, "Bill Payment Successful", string.format('Bought x%s %s From %s', data.countTo, item.label, _playerShops[data.ownerFrom].name), os.time(), 3000, "bank", {})
						end
					end

					if paid then
						if not isMod then
							pendingShopDeposits[_playerShops[data.ownerFrom].bank] = pendingShopDeposits[_playerShops[data.ownerFrom].bank] or { amount = 0, transactions = 0 }
							pendingShopDeposits[_playerShops[data.ownerFrom].bank].amount += math.floor( (cost * STORE_SHARE_AMOUNT) )
							pendingShopDeposits[_playerShops[data.ownerFrom].bank].transactions += 1
	
							pendingShopDeposits[_govAccount] = pendingShopDeposits[_govAccount] or { amount = 0, transactions = 0, tax = true }
							pendingShopDeposits[_govAccount].amount += math.ceil(cost * (1.0 - STORE_SHARE_AMOUNT))
							pendingShopDeposits[_govAccount].transactions += 1
						end

						WithBothInventories(data.ownerFrom, data.invTypeFrom, data.ownerTo, data.invTypeTo, function(fromSlots, toSlots)
							MoveSlotUnits(fromSlots, data.slotFrom, toSlots, data.slotTo, data.countTo, { price = 0 })
						end)


						if WEAPON_PROPS[item.weapon or item.name] ~= nil then
							_refreshAttchs[data.ownerTo] = source
						end

						if item.gangChain ~= nil then
							_refreshGangChain[data.ownerTo] = source
						end
				
						-- This might be bad, but idk how else to do this other than just not and deal with client UI being incorrect
						getInventory(source, data.ownerFrom, data.invTypeFrom)
						getInventory(source, data.ownerTo, data.invTypeTo)
					
						sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
						sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)

						return cb({ success = true })
					else
						TriggerClientEvent("StoreFailedPurchase", source, {
							player = {
								inventory = _cachedInvs[string.format("%s-%s", data.ownerTo, data.invTypeTo)],
							},
							secondary = {
								inventory = _cachedInvs[string.format("%s-%s", data.ownerFrom, data.invTypeFrom)],
							}
						})
						sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
						sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
						return cb({ reason = "Payment Failed" })
					end
				else
					TriggerClientEvent("StoreFailedPurchase", source, {
						player = {
							inventory = _cachedInvs[string.format("%s-%s", data.ownerTo, data.invTypeTo)],
						},
						secondary = {
							inventory = _cachedInvs[string.format("%s-%s", data.ownerFrom, data.invTypeFrom)],
						}
					})
					sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
					sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
					return cb({ reason = "You Cannot Afford That" })
				end
			else
				TriggerClientEvent("StoreFailedPurchase", source, {
					player = {
						inventory = _cachedInvs[string.format("%s-%s", data.ownerTo, data.invTypeTo)],
					},
					secondary = {
						inventory = _cachedInvs[string.format("%s-%s", data.ownerFrom, data.invTypeFrom)],
					}
				})
				sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
				sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
				return cb({ reason = "Invalid Item" })
			end
		else
			TriggerClientEvent("StoreFailedPurchase", source, {
				player = {
					inventory = _cachedInvs[string.format("%s-%s", data.ownerTo, data.invTypeTo)],
				},
				secondary = {
					inventory = _cachedInvs[string.format("%s-%s", data.ownerFrom, data.invTypeFrom)],
				}
			})
			sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
			sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
			return cb({ reason = "Invalid Shop" })
		end
	else
		if entityTo.playerShop and not isShopModerator(data.ownerFrom, source) then
			sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
			sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
			return cb({ reason = "Cannot Do That" })
		end

		local slotFrom = INVENTORY:GetSlot(data.ownerFrom, data.slotFrom, data.invTypeFrom)
		local slotTo = INVENTORY:GetSlot(data.ownerTo, data.slotTo, data.invTypeTo)

		if slotFrom == nil or slotTo == nil then
			cb({ reason = "Item No Longer In That Slot" })
			sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
			sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
			return
		end
		
		if entityFrom.playerShop and slotFrom?.Price ~= slotTo?.Price then
			sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
			sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
			return cb({ reason = "Item Price Mismatch, Cannot Merge" })
		end

		WithBothInventories(data.ownerFrom, data.invTypeFrom, data.ownerTo, data.invTypeTo, function(fromSlots, toSlots)
			MoveSlotUnits(fromSlots, data.slotFrom, toSlots, data.slotTo, data.countTo)
		end)


		if ((data.ownerFrom ~= data.ownerTo) or (data.invTypeFrom ~= data.invTypeTo)) then
			if data.invTypeFrom == 1 then
				local char = plsr.Fetch:SID(data.ownerFrom)

				if data.ownerFrom == data.ownerTo then
					if item.type == 2 then
						if (not item.isStackable and item.isStackable ~= -1) or data.countTo == slotFrom.Count then
							TriggerClientEvent(
								"Weapons:Client:Move",
								char:GetData("Source"),
								data.slotFrom,
								data.slotTo
							)
						end
						
						if item.isThrowable then
							TriggerClientEvent(
								"Weapons:Client:UpdateCount",
								char:GetData("Source"),
								data.slotFrom,
								(slotFrom.Count - data.countTo)
							)
							TriggerClientEvent(
								"Weapons:Client:UpdateCount",
								char:GetData("Source"),
								data.slotTo,
								((slotTo?.Count or 0) + data.countTo)
							)
						end
					elseif item.type == 10 then
						TriggerClientEvent(
							"Inventory:Container:Move",
							char:GetData("Source"),
							data.slotFrom,
							data.slotTo
						)
					end
				else
					if not item.isStackable or data.countTo == slotFrom.Count then
						if item.type == 2 then
							TriggerClientEvent(
								"Weapons:Client:Remove",
								char:GetData("Source"),
								slotFrom,
								data.slotFrom,
								{
									owner = data.ownerTo,
									type = data.invTypeTo,
									slot = data.slotTo,
								}
							)
						elseif item.type == 10 then
							TriggerClientEvent(
								"Inventory:Container:Remove",
								char:GetData("Source"),
								slotFrom,
								data.slotFrom
							)
						end
					else
						if item.isThrowable then
							TriggerClientEvent(
								"Weapons:Client:UpdateCount",
								char:GetData("Source"),
								data.slotFrom,
								(slotFrom.Count - data.countTo)
							)
						end
					end
				end
			end
	
			if data.invTypeTo == 1 then
				local char = plsr.Fetch:SID(data.ownerTo)
				if item.isThrowable then
					TriggerClientEvent(
						"Weapons:Client:UpdateCount",
						char:GetData("Source"),
						data.slotTo,
						((slotTo?.Count or 0) + data.countTo)
					)
				end
			end

			if data.inventory.position ~= nil then
				CreateDZIfNotExist(source, data.inventory.position)
			end
		end

		if ((data.ownerFrom ~= data.ownerTo) or (data.invTypeFrom ~= data.invTypeTo)) and WEAPON_PROPS[item.weapon or item.name] ~= nil then
			_refreshAttchs[data.ownerFrom] = source
			_refreshAttchs[data.ownerTo] = source
		end

		if ((data.ownerFrom ~= data.ownerTo) or (data.invTypeFrom ~= data.invTypeTo)) and item.gangChain ~= nil then
			_refreshGangChain[data.ownerFrom] = source
			_refreshGangChain[data.ownerTo] = source
		end

		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)

		return cb({ success = true })
	end
end

function DoSwap(source, data, cb)
	local char = plsr.Fetch:CharacterSource(source)

	local item = itemsDatabase[data.name]
	local cash = char:GetData("Cash")

	local entityFrom = LoadedEntitys[tonumber(data.invTypeFrom)]
	local entityTo = LoadedEntitys[tonumber(data.invTypeTo)]

	if data.ownerFrom == nil or data.slotFrom == nil or data.invTypeFrom == nil or data.ownerTo == nil or data.slotTo == nil or data.invTypeTo == nil then
		cb({ reason = "Invalid Move Data" })
		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
		return
	end

	if data.countTo <= 0 then
		cb({ reason = "Can't Move 0 - Naughty Boy" })
		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
		return
	end

	-- swaps never go through the shop/playerShop paths (blocked just below), so this is unconditional
	if not validateInventoryAccess(source, data.ownerFrom, tonumber(data.invTypeFrom)) or not validateInventoryAccess(source, data.ownerTo, tonumber(data.invTypeTo)) then
		cb({ reason = "No Access To That Inventory" })
		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
		return
	end

	-- held for the rest of this function, released automatically on any exit path
	local lockKeys = { ("%s:%s"):format(data.ownerFrom, data.invTypeFrom) }
	local toKey = ("%s:%s"):format(data.ownerTo, data.invTypeTo)
	if toKey ~= lockKeys[1] then
		table.insert(lockKeys, toKey)
	end
	local lock <close> = AcquireLocks(lockKeys)
	if not lock then
		cb({ reason = "Item Currently Being Moved" })
		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
		return
	end

	if entityFrom.shop or (entityFrom.playerShop and ((data.ownerFrom ~= data.ownerTo and data.invTypeFrom ~= data.invTypeTo) or not isShopModerator(data.ownerFrom, source))) then
		cb({ reason = "Illegal Operation" })
		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
		return
	else
		local slotFrom = INVENTORY:GetSlot(data.ownerFrom, data.slotFrom, data.invTypeFrom)
		local slotTo = INVENTORY:GetSlot(data.ownerTo, data.slotTo, data.invTypeTo)

		if slotFrom == nil or slotTo == nil then
			cb({ reason = "Item No Longer In That Slot" })
			sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
			sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
			return
		end

		if isContainerOwnStorage(item, slotFrom, data.ownerTo) then
			cb({ reason = "Can't Put A Container Inside Itself" })
			sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
			sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
			return
		end

		-- a swap moves weight both ways at once, so both sides need their own capacity check
		local toItemData = itemsDatabase[slotTo.Name]
		local toWeight = (toItemData and toItemData.weight or 0) * slotTo.Count
		if not checkDestWeight(data, item, toWeight) then
			cb({ reason = "Too Heavy" })
			sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
			sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
			return
		end

		local reverseData = { ownerFrom = data.ownerTo, invTypeFrom = data.invTypeTo, ownerTo = data.ownerFrom, invTypeTo = data.invTypeFrom, vehClassTo = data.vehClassFrom, vehModelTo = data.vehModelFrom, capacityOverrideTo = data.capacityOverrideFrom, countTo = slotTo.Count }
		if not checkDestWeight(reverseData, toItemData or {}, (item.weight or 0) * tonumber(data.countTo)) then
			cb({ reason = "Too Heavy" })
			sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
			sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
			return
		end

		WithBothInventories(data.ownerFrom, data.invTypeFrom, data.ownerTo, data.invTypeTo, function(fromSlots, toSlots)
			SwapSlotEntries(fromSlots, data.slotFrom, toSlots, data.slotTo)
		end)

		if (data.ownerFrom ~= data.ownerTo) or (data.invTypeFrom ~= data.invTypeTo) then

			if data.invTypeFrom == 1 then
				local char = plsr.Fetch:SID(data.ownerFrom)

				if (data.ownerFrom == data.ownerTo) and (data.invTypeFrom == data.invTypeTo) then -- Within Same Inventory
					if item.type == 2 then
						if (not item.isStackable and item.isStackable ~= -1) or data.countTo == slotFrom.Count then
							TriggerClientEvent(
								"Weapons:Client:Move",
								char:GetData("Source"),
								data.slotFrom,
								data.slotTo
							)
						end
						
						if item.isThrowable then
							TriggerClientEvent(
								"Weapons:Client:UpdateCount",
								char:GetData("Source"),
								data.slotFrom,
								(slotFrom.Count - data.countTo)
							)
							TriggerClientEvent(
								"Weapons:Client:UpdateCount",
								char:GetData("Source"),
								data.slotTo,
								((slotTo?.Count or 0) + data.countTo)
							)
						end
					elseif item.type == 10 then
						TriggerClientEvent(
							"Inventory:Container:Move",
							char:GetData("Source"),
							data.slotFrom,
							data.slotTo
						)
					end
				else
					if not item.isStackable or data.countTo == slotFrom.Count then
						if item.type == 2 then
							TriggerClientEvent(
								"Weapons:Client:Remove",
								char:GetData("Source"),
								slotFrom,
								data.slotFrom,
								{
									owner = data.ownerTo,
									type = data.invTypeTo,
									slot = data.slotTo,
								}
							)
						elseif item.type == 10 then
							TriggerClientEvent(
								"Inventory:Container:Remove",
								char:GetData("Source"),
								slotFrom,
								data.slotFrom
							)
						end
					else
						if item.isThrowable then
							TriggerClientEvent(
								"Weapons:Client:UpdateCount",
								char:GetData("Source"),
								data.slotFrom,
								(slotFrom.Count - data.countTo)
							)
						end
					end
				end
			end
	
			if data.invTypeTo == 1 then
				local char = plsr.Fetch:SID(data.ownerTo)
				if item.isThrowable then
					TriggerClientEvent(
						"Weapons:Client:UpdateCount",
						char:GetData("Source"),
						data.slotTo,
						((slotTo?.Count or 0) + data.countTo)
					)
				end
			end

			if data.inventory.position ~= nil then
				CreateDZIfNotExist(source, data.inventory.position)
			end
		end

		if ((data.ownerFrom ~= data.ownerTo) or (data.invTypeFrom ~= data.invTypeTo)) and WEAPON_PROPS[item.weapon or item.name] ~= nil then
			_refreshAttchs[data.ownerFrom] = source
			_refreshAttchs[data.ownerTo] = source
		end

		if ((data.ownerFrom ~= data.ownerTo) or (data.invTypeFrom ~= data.invTypeTo)) and item.gangChain ~= nil then
			_refreshGangChain[data.ownerFrom] = source
			_refreshGangChain[data.ownerTo] = source
		end

		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)

		return cb({ success = true })
	end
end

function DoMove(source, data, cb)
	local char = plsr.Fetch:CharacterSource(source)

	local item = itemsDatabase[data.name]
	local cash = char:GetData("Cash")

	local entityFrom = LoadedEntitys[tonumber(data.invTypeFrom)]
	local entityTo = LoadedEntitys[tonumber(data.invTypeTo)]

	if data.ownerFrom == nil or data.slotFrom == nil or data.invTypeFrom == nil or data.ownerTo == nil or data.slotTo == nil or data.invTypeTo == nil then
		cb({ reason = "Invalid Move Data" })
		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
		return
	end

	if data.countTo <= 0 then
		cb({ reason = "Can't Move 0 - Naughty Boy" })
		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
		return
	end

	-- shop/playerShop branches gate ownerFrom themselves below; every other case had no check at all
	if not validateInventoryAccess(source, data.ownerTo, tonumber(data.invTypeTo)) or (not entityFrom.shop and not entityFrom.playerShop and not validateInventoryAccess(source, data.ownerFrom, tonumber(data.invTypeFrom))) then
		cb({ reason = "No Access To That Inventory" })
		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
		return
	end

	-- shop branch skips locking the destination here since AddItem locks it itself below
	local lockKeys = {}
	if not entityFrom.shop then
		table.insert(lockKeys, ("%s:%s"):format(data.ownerFrom, data.invTypeFrom))
		local toKey = ("%s:%s"):format(data.ownerTo, data.invTypeTo)
		if toKey ~= lockKeys[1] then
			table.insert(lockKeys, toKey)
		end
	end
	local lock <close> = AcquireLocks(lockKeys)
	if not lock then
		cb({ reason = "Item Currently Being Moved" })
		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
		return
	end

	-- DoMove never displaces an occupant (that's DoSwap's job), so no subtraction needed
	if not checkDestWeight(data, item) then
		cb({ reason = "Too Heavy" })
		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
		return
	end

	if entityFrom.shop then
		local slotFrom = getShopSlot(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		local cost = math.ceil(((slotFrom?.Price or item.price) * tonumber(data.countTo)))
		local paymentType = (cash >= cost and 'cash' or (plsr.Banking.Balance:Has(char:GetData("BankAccount"), cost) and 'bank' or nil))
		if entityFrom.free or paymentType ~= nil then
			if -- Check if the item is either not a gun, or if it is that they have a Weapons license
				(item.type ~= 2
				or (
					item.type == 2
					and (not item.requiresLicense or item.requiresLicense and plsr.Weapons:IsEligible(source))
				))
				and (not item.qualification or hasValue(char:GetData("Qualifications"), item.qualification))
			then
				local paid = cost == 0 or entityFrom.free
				if not paid then
					if paymentType == 'cash' then
						paid = plsr.Wallet:Modify(source, -(math.abs(cost)))
					else
						paid = plsr.Banking.Balance:Charge(char:GetData("BankAccount"), cost, {
							type = 'bill',
							title = 'Store Purchase',
							description = string.format('Bought x%s %s', data.countTo, item.label),
							data = {}
						})
						plsr.Phone.Notification:Add(source, "Bill Payment Successful", string.format('Bought x%s %s', data.countTo, item.label), os.time(), 3000, "bank", {})
					end

					if paid then
						local bonk = storeBankAccounts[entityFrom.id]
						pendingShopDeposits[bonk] = pendingShopDeposits[bonk] or { amount = 0, transactions = 0 }
						pendingShopDeposits[bonk].amount += math.floor( (cost * STORE_SHARE_AMOUNT) )
						pendingShopDeposits[bonk].transactions += 1

						pendingShopDeposits[_govAccount] = pendingShopDeposits[_govAccount] or { amount = 0, transactions = 0, tax = true }
						pendingShopDeposits[_govAccount].amount += math.ceil(cost * (1.0 - STORE_SHARE_AMOUNT))
						pendingShopDeposits[_govAccount].transactions += 1
					end
				end

				if paid then
					local insData = INVENTORY:AddItem(char:GetData("SID"), data.name, data.countTo, {}, data.invTypeTo, false, false, false, false, data.slotTo, false, false, false, true)
					-- AddItem/AddSlot can genuinely fail (e.g. lost a slot race) - refund rather than take payment for nothing, matching ox_inventory's buyItem
					if not (insData and insData.id) then
						if not (cost == 0 or entityFrom.free) then
							if paymentType == 'cash' then
								plsr.Wallet:Modify(source, math.abs(cost))
							else
								plsr.Banking.Balance:Deposit(char:GetData("BankAccount"), cost, {
									type = 'refund',
									title = 'Store Purchase Refund',
									description = string.format('Refunded x%s %s (Purchase Failed)', data.countTo, item.label),
									data = {},
								})
							end
						end

						sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
						sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
						return cb({ reason = "Failed To Add Item, Refunded" })
					end

					CreateStoreLog(data.ownerFrom, data.name, data.countTo or 1, char:GetData("SID"), insData.MetaData, 0)
				end

				if ((data.ownerFrom ~= data.ownerTo) or (data.invTypeFrom ~= data.invTypeTo)) and WEAPON_PROPS[item.weapon or item.name] ~= nil then
					_refreshAttchs[data.ownerFrom] = source
					_refreshAttchs[data.ownerTo] = source
				end

				if ((data.ownerFrom ~= data.ownerTo) or (data.invTypeFrom ~= data.invTypeTo)) and item.gangChain ~= nil then
					_refreshGangChain[data.ownerFrom] = source
					_refreshGangChain[data.ownerTo] = source
				end

				sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
				sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
				return cb({ success = true })
			else
				sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
				sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
				cb({ reason = "Ineligible To Purchase Item" })
			end
		else
			sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
			sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
			cb({ reason = "Not Enough Cash" })
		end
	elseif entityFrom.playerShop and data.ownerFrom ~= data.ownerTo and data.invTypeFrom ~= data.invTypeTo then
		if _playerShops[data.ownerFrom] then
			local isMod = isShopModerator(data.ownerFrom, source)
			local slotFrom = INVENTORY:GetSlot(data.ownerFrom, data.slotFrom, data.invTypeFrom)
			local slotTo = INVENTORY:GetSlot(data.ownerTo, data.slotTo, data.invTypeTo)

			if slotFrom ~= nil then
				local cost = math.ceil((slotFrom.Price * tonumber(data.countTo)))
				local paymentType = (cash >= cost and 'cash' or (plsr.Banking.Balance:Has(char:GetData("BankAccount"), cost) and 'bank' or nil))
				if cost == 0 or paymentType ~= nil or isMod then
					local paid = cost == 0 or isMod
					if not paid then
						if paymentType == 'cash' then
							paid = plsr.Wallet:Modify(source, -(math.abs(cost)))
						else
							paid = plsr.Banking.Balance:Charge(char:GetData("BankAccount"), cost, {
								type = 'bill',
								title = 'Store Purchase',
								description = string.format('Bought x%s %s From %s', data.countTo, item.label, _playerShops[data.ownerFrom].name),
								data = {}
							})
							plsr.Phone.Notification:Add(source, "Bill Payment Successful", string.format('Bought x%s %s From %s', data.countTo, item.label, _playerShops[data.ownerFrom].name), os.time(), 3000, "bank", {})
						end
					end

					if paid then
						if not isMod then
							pendingShopDeposits[_playerShops[data.ownerFrom].bank] = pendingShopDeposits[_playerShops[data.ownerFrom].bank] or { amount = 0, transactions = 0 }
							pendingShopDeposits[_playerShops[data.ownerFrom].bank].amount += math.floor( (cost * STORE_SHARE_AMOUNT) )
							pendingShopDeposits[_playerShops[data.ownerFrom].bank].transactions += 1
	
							pendingShopDeposits[_govAccount] = pendingShopDeposits[_govAccount] or { amount = 0, transactions = 0, tax = true }
							pendingShopDeposits[_govAccount].amount += math.ceil(cost * (1.0 - STORE_SHARE_AMOUNT))
							pendingShopDeposits[_govAccount].transactions += 1
						end

						WithBothInventories(data.ownerFrom, data.invTypeFrom, data.ownerTo, data.invTypeTo, function(fromSlots, toSlots)
							local fromEntry = FindSlotEntry(fromSlots, data.slotFrom)
							if not fromEntry or fromEntry.name ~= data.name then
								return false
							end
							local moveCount = data.isSplit and data.countTo or fromEntry.count
							MoveSlotUnits(fromSlots, data.slotFrom, toSlots, data.slotTo, moveCount, { price = 0 })
						end)

						
						if WEAPON_PROPS[item.weapon or item.name] ~= nil then
							_refreshAttchs[data.ownerTo] = source
						end

						if item.gangChain ~= nil then
							_refreshGangChain[data.ownerTo] = source
						end
					
						-- This might be bad, but idk how else to do this other than just not and deal with client UI being incorrect
						getInventory(source, data.ownerFrom, data.invTypeFrom)
						getInventory(source, data.ownerTo, data.invTypeTo)

						sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
						sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)

						return cb({ success = true })
					else
						TriggerClientEvent("StoreFailedPurchase", source, {
							player = {
								inventory = _cachedInvs[string.format("%s-%s", data.ownerTo, data.invTypeTo)],
							},
							secondary = {
								inventory = _cachedInvs[string.format("%s-%s", data.ownerFrom, data.invTypeFrom)],
							}
						})
						sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
						sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
						cb({ reason = "Payment Failed" })
					end
				else
					TriggerClientEvent("StoreFailedPurchase", source, {
						player = {
							inventory = _cachedInvs[string.format("%s-%s", data.ownerTo, data.invTypeTo)],
						},
						secondary = {
							inventory = _cachedInvs[string.format("%s-%s", data.ownerFrom, data.invTypeFrom)],
						}
					})
					sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
					sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
					cb({ reason = "You Cannot Afford That" })
				end
			else
				TriggerClientEvent("StoreFailedPurchase", source, {
					player = {
						inventory = _cachedInvs[string.format("%s-%s", data.ownerTo, data.invTypeTo)],
					},
					secondary = {
						inventory = _cachedInvs[string.format("%s-%s", data.ownerFrom, data.invTypeFrom)],
					}
				})
				sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
				sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
				return cb({ reason = "Invalid Item" })
			end
		else
			TriggerClientEvent("StoreFailedPurchase", source, {
				player = {
					inventory = _cachedInvs[string.format("%s-%s", data.ownerTo, data.invTypeTo)],
				},
				secondary = {
					inventory = _cachedInvs[string.format("%s-%s", data.ownerFrom, data.invTypeFrom)],
				}
			})
			sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
			sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
			return cb({ reason = "Invalid Shop" })
		end
	else
		if entityTo.playerShop and not isShopModerator(data.ownerFrom, source) then
			sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
			sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
			return cb({ reason = "Cannot Do That" })
		end

		local slotFrom = INVENTORY:GetSlot(data.ownerFrom, data.slotFrom, data.invTypeFrom)
		local slotTo = INVENTORY:GetSlot(data.ownerTo, data.slotTo, data.invTypeTo)

		if slotFrom == nil then
			cb({ reason = "Item No Longer In That Slot" })
			sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
			sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
			return
		end

		if isContainerOwnStorage(item, slotFrom, data.ownerTo) then
			cb({ reason = "Can't Put A Container Inside Itself" })
			sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
			sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
			return
		end

		WithBothInventories(data.ownerFrom, data.invTypeFrom, data.ownerTo, data.invTypeTo, function(fromSlots, toSlots)
			local fromEntry = FindSlotEntry(fromSlots, data.slotFrom)
			if not fromEntry or fromEntry.name ~= data.name then
				return false
			end
			local moveCount = data.isSplit and data.countTo or fromEntry.count
			MoveSlotUnits(fromSlots, data.slotFrom, toSlots, data.slotTo, moveCount)
		end)
		
		if (data.ownerFrom ~= data.ownerTo) or (data.invTypeFrom ~= data.invTypeTo) then
			if data.invTypeFrom == 1 then
				local char = plsr.Fetch:SID(data.ownerFrom)

				if (data.ownerFrom == data.ownerTo) and (data.invTypeFrom == data.invTypeTo) then -- Within Same Inventory
					if item.type == 2 then
						if (not item.isStackable and item.isStackable ~= -1) or data.countTo == slotFrom.Count then
							TriggerClientEvent(
								"Weapons:Client:Move",
								char:GetData("Source"),
								data.slotFrom,
								data.slotTo
							)
						end
						
						if item.isThrowable then
							TriggerClientEvent(
								"Weapons:Client:UpdateCount",
								char:GetData("Source"),
								data.slotFrom,
								(slotFrom.Count - data.countTo)
							)
							TriggerClientEvent(
								"Weapons:Client:UpdateCount",
								char:GetData("Source"),
								data.slotTo,
								((slotTo?.Count or 0) + data.countTo)
							)
						end
					elseif item.type == 10 then
						TriggerClientEvent(
							"Inventory:Container:Move",
							char:GetData("Source"),
							data.slotFrom,
							data.slotTo
						)
					end
				else
					if not item.isStackable or data.countTo == slotFrom.Count then
						if item.type == 2 then
							TriggerClientEvent(
								"Weapons:Client:Remove",
								char:GetData("Source"),
								slotFrom,
								data.slotFrom,
								{
									owner = data.ownerTo,
									type = data.invTypeTo,
									slot = data.slotTo,
								}
							)
						elseif item.type == 10 then
							TriggerClientEvent(
								"Inventory:Container:Remove",
								char:GetData("Source"),
								slotFrom,
								data.slotFrom
							)
						end
					else
						if item.isThrowable then
							TriggerClientEvent(
								"Weapons:Client:UpdateCount",
								char:GetData("Source"),
								data.slotFrom,
								(slotFrom.Count - data.countTo)
							)
						end
					end
				end
			end
	
			if data.invTypeTo == 1 then
				local char = plsr.Fetch:SID(data.ownerTo)
				if item.isThrowable then
					TriggerClientEvent(
						"Weapons:Client:UpdateCount",
						char:GetData("Source"),
						data.slotTo,
						((slotTo?.Count or 0) + data.countTo)
					)
				end
			end

			if data.inventory.position ~= nil then
				CreateDZIfNotExist(source, data.inventory.position)
			end
		end

		if ((data.ownerFrom ~= data.ownerTo) or (data.invTypeFrom ~= data.invTypeTo)) and WEAPON_PROPS[item.weapon or item.name] ~= nil then
			_refreshAttchs[data.ownerFrom] = source
			_refreshAttchs[data.ownerTo] = source
		end

		if ((data.ownerFrom ~= data.ownerTo) or (data.invTypeFrom ~= data.invTypeTo)) and item.gangChain ~= nil then
			_refreshGangChain[data.ownerFrom] = source
			_refreshGangChain[data.ownerTo] = source
		end
	
		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)

		return cb({ success = true })
	end
end

function CreateDZIfNotExist(source, coords)
	local route = plsr.State:Player(source).currentRoute
	local id = string.format("%s:%s:%s", math.ceil(coords.x), math.ceil(coords.y), route)
	if not INVENTORY:DropExists(route, id) then
		INVENTORY:CreateDropzone(route, coords)
	end
end

function RegisterCallbacks()
	plsr.Callbacks:RegisterServerCallback("Inventory:MergeItem", DoMerge)
	plsr.Callbacks:RegisterServerCallback("Inventory:SwapItem", DoSwap)
	plsr.Callbacks:RegisterServerCallback("Inventory:MoveItem", DoMove)

	plsr.Callbacks:RegisterServerCallback("Inventory:Server:DropToGround", function(source, data, cb)
		local item = data.item
		local ground = data.ground

		if not item or not ground or not ground.owner or not ground.position then
			return cb(false)
		end

		if not validateInventoryAccess(source, item.ownerFrom, tonumber(item.invTypeFrom)) then
			sendRefreshForClient(source, item.ownerFrom, item.invTypeFrom, item.slotFrom)
			return cb(false)
		end

		local freeSlots = INVENTORY:GetFreeSlotNumbers(ground.owner, 10, false, false, source)
		local slotTo = freeSlots[1]
		if not slotTo then
			sendRefreshForClient(source, item.ownerFrom, item.invTypeFrom, item.slotFrom)
			return cb(false)
		end

		DoMove(source, {
			ownerFrom = item.ownerFrom,
			invTypeFrom = tonumber(item.invTypeFrom),
			slotFrom = item.slotFrom,
			ownerTo = ground.owner,
			invTypeTo = 10,
			slotTo = slotTo,
			name = item.name,
			countFrom = item.count,
			countTo = item.count,
			vehClassFrom = item.vehClassFrom,
			vehModelFrom = item.vehModelFrom,
			slotOverrideFrom = item.slotOverrideFrom,
			capacityOverrideFrom = item.capacityOverrideFrom,
			inventory = { position = ground.position },
		}, function(result)
			if result and result.success then
				-- only do the full reopen (player resync, drop anim, nui focus) the first time the
				-- pane isn't already showing, otherwise just push fresh secondary data to it
				local granted = _openSecondary[source]
				local alreadyOpen = granted ~= nil and tostring(granted.owner) == tostring(ground.owner) and granted.invType == 10
				if alreadyOpen then
					TriggerClientEvent("Inventory:Client:RefreshSecondary", source, INVENTORY:GetSecondary(source, 10, ground.owner))
				else
					INVENTORY:OpenSecondary(source, 10, ground.owner)
				end
				cb(true)
			else
				cb(false)
			end
		end)
	end)

	plsr.Callbacks:RegisterServerCallback("Inventory:OpenTrunk", function(source, data, cb)
		local myCoords = GetEntityCoords(GetPlayerPed(source))
		local veh = NetworkGetEntityFromNetworkId(data.netId)

		if plsr.State.Entity(veh).VIN == nil then
			return cb(false)
		end

		local vehCoords = GetEntityCoords(veh)
		local dist = #(vector3(myCoords.x, myCoords.y, myCoords.z) - vector3(vehCoords.x, vehCoords.y, vehCoords.z))
		local lock = GetVehicleDoorLockStatus(veh)
		if dist < 8 and (lock == 0 or lock == 1) then
			INVENTORY:OpenSecondary(source, 4, plsr.State.Entity(veh).VIN, data.class or false, data.model or false)
			cb(true)
		else
			cb(false)
		end
	end)

	-- mirrors OpenTrunk's grant pattern - glovebox needs the player actually seated in the vehicle, not just nearby
	plsr.Callbacks:RegisterServerCallback("Inventory:OpenGlovebox", function(source, data, cb)
		local veh = NetworkGetEntityFromNetworkId(data.netId)
		if not DoesEntityExist(veh) or plsr.State.Entity(veh).VIN == nil then
			return cb(false)
		end

		if GetVehiclePedIsIn(GetPlayerPed(source), false) ~= veh then
			return cb(false)
		end

		INVENTORY:OpenSecondary(source, 5, plsr.State.Entity(veh).VIN, data.class or false, data.model or false)
		cb(true)
	end)

	plsr.Callbacks:RegisterServerCallback("Inventory:UseItem", function(source, data, cb)
		if entityPermCheck(source, data.invType) then
			local slot = INVENTORY:GetOldestInSlot(data.owner, data.slot, data.invType)
			if slot ~= nil then
				_lastUsedItem[source] = slot.id
				INVENTORY.Items:Use(source, slot, cb)
			else
				sendRefreshForClient(source, data.owner, data.invType, data.slot)
				cb(false)
			end
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Inventory:UseSlot", function(source, data, cb)
		if data and data.slot then
			local char = plsr.Fetch:CharacterSource(source)
			if char then
				local slotFrom = INVENTORY:GetOldestInSlot(char:GetData("SID"), data.slot, 1)
				if slotFrom ~= nil then
					if slotFrom.Count or 0 > 0 then
						_lastUsedItem[source] = slotFrom.id
						INVENTORY.Items:Use(source, slotFrom, function(yea)
							if not yea then
								sendRefreshForClient(source, char:GetData("SID"), 1, slotFrom)
							end
							cb(yea)
						end)
					else
						sendRefreshForClient(source, char:GetData("SID"), 1, slotFrom)
						cb(false)
					end
				else
					sendRefreshForClient(source, char:GetData("SID"), 1, slotFrom)
					cb(false)
				end
			else
				cb(false)
			end
		else
			cb(false)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Inventory:CheckIfNearDropZone", function(source, data, cb)
		local playerPed = GetPlayerPed(source)
		local playerCoords = GetEntityCoords(playerPed)
		local route = plsr.State:Player(source).currentRoute
		cb(INVENTORY:CheckDropZones(route, vector3(playerCoords.x, playerCoords.y, playerCoords.z)))
	end)

	plsr.Callbacks:RegisterServerCallback("Inventory:Server:retreiveStores", function(source, data, cb)
		cb(shopLocations)
	end)

	plsr.Callbacks:RegisterServerCallback("Inventory:Search", function(source, data, cb)
		local dest = plsr.Fetch:CharacterSource(data.serverId)
		if dest ~= nil then
			INVENTORY.Search:Character(source, data.serverId, dest:GetData("SID"))
			cb(dest:GetData("SID"))
		else
			cb(false)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Inventory:Raid", function(source, data, cb)
		local dest = plsr.Fetch:CharacterSource(source)
		local onDuty = plsr.State:Player(source).onDuty

		if dest and onDuty ~= nil and onDuty == "police" and plsr.Jobs.Permissions:HasPermissionInJob(source, 'police', 'PD_RAID') then
			INVENTORY:OpenSecondary(source, data.invType, data.owner, data.class or false, data.model or false, true)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Inventory:Dumpster:Open", function(source, data, cb)
		plsr.Callbacks:ClientCallback(source, "Inventory:Compartment:Open", {
			invType = 4000,
			owner = data.identifier,
			}, function()
				INVENTORY:OpenSecondary(source, 4000, data.identifier)
		end)
		cb()
	end)

	plsr.Callbacks:RegisterServerCallback("Inventory:CloseSecondary", function(source, inventory, cb)
		if inventory.invType == 1 then
			refreshShit(inventory.owner)
		elseif inventory.invType == 10 then
			local route = plsr.State:Player(source).currentRoute
			local exists = INVENTORY:DropExists(route, inventory.owner)
			local hasItems = INVENTORY:HasItems(inventory.owner, 10)
			if inventory.position ~= nil and hasItems and not exists then
				INVENTORY:CreateDropzone(route, inventory.position)
			elseif exists and not hasItems then
				INVENTORY:RemoveDropzone(route, inventory.owner)
			end
		else
			if _refreshAttchs[inventory.owner] then
				_refreshAttchs[inventory.owner] = false
			end

			if _refreshGangChain[inventory.owner] then
				_refreshGangChain[inventory.owner] = false
			end
		end

		_openInvs[string.format("%s-%s", inventory.owner, inventory.invType)] = false

		-- unconditional: firing at all means they're done with whatever secondary they had
		_openSecondary[source] = nil

		cb()
	end)

	plsr.Callbacks:RegisterServerCallback("Inventory:PlayerShop:AddItem", function(source, data, cb)
		local char = plsr.Fetch:CharacterSource(source)
		if char ~= nil then
			local sid = char:GetData("SID")
			if _playerShops[data.ownerTo] ~= nil then
				if isShopModerator(data.ownerTo, source) then
					local slotFrom = INVENTORY:GetSlot(data.ownerFrom, data.slotFrom, data.invTypeFrom)
					if slotFrom ~= nil then
						local item = itemsDatabase[slotFrom.Name]
						local slotTo = INVENTORY:GetSlot(data.ownerTo, data.slotTo, data.invTypeTo)

						if slotTo == nil or slotTo.Price == data.price then
							local moved = MutateTwoInventories(data.ownerFrom, data.invTypeFrom, data.ownerTo, data.invTypeTo, function(fromSlots, toSlots)
								MoveSlotUnits(fromSlots, data.slotFrom, toSlots, data.slotTo, data.quantity, { price = data.price })
							end)

							if not moved then
								cb(false)
							else
								if item.type == 2 then
									TriggerClientEvent(
										"Weapons:Client:Remove",
										source,
										slotFrom,
										data.slotFrom,
										{
											owner = data.ownerTo,
											type = data.invTypeTo,
											slot = data.slotTo,
										}
									)
								elseif item.type == 10 then
									TriggerClientEvent(
										"Inventory:Container:Remove",
										source,
										slotFrom,
										data.slotFrom
									)
								end

								if WEAPON_PROPS[itemsDatabase[slotFrom.Name].weapon or slotFrom.Name] ~= nil then
									_refreshAttchs[data.ownerFrom] = source
								end

								if itemsDatabase[slotFrom.Name].gangChain ~= nil then
									_refreshGangChain[data.ownerFrom] = source
								end

								cb({
									player = getInventory(source, data.ownerFrom, data.invTypeFrom),
									secondary = getInventory(source, data.ownerTo, data.invTypeTo)
								})
							end
						else
							cb(false)
						end
					else
						cb(false)
					end
				else
					cb(false)
				end
			else
				cb(false)
			end
		else
			cb(false)
		end

		sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
		sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
	end)

	plsr.Callbacks:RegisterServerCallback("Inventory:PlayerShop:AddModerator", function(source, data, cb)
		local char = plsr.Fetch:CharacterSource(source)
		if char ~= nil then
			local sid = char:GetData("SID")
			if _playerShops[data.shop] ~= nil then
				if _playerShops[data.shop].owner == sid then
					local tChar = plsr.Fetch:SID(tonumber(data.sid))
					if tChar ~= nil then
						if not isShopModerator(data.shop, tChar:GetData("Source")) then
							INVENTORY.PlayerShops.Moderators:Add(data.shop, tonumber(data.sid), string.format("%s %s", tChar:GetData("First"), tChar:GetData("Last")))
							plsr.Execute:Client(source, "Notification", "Success", string.format("%s %s Added As A Shop Moderator", tChar:GetData("First"), tChar:GetData("Last")))
						else
							plsr.Execute:Client(source, "Notification", "Error", string.format("%s %s Is Already A Shop Moderator", tChar:GetData("First"), tChar:GetData("Last")))
						end
					else
						plsr.Execute:Client(source, "Notification", "Error", "Invalid Target ID")
					end
				else
					plsr.Execute:Client(source, "Notification", "Error", "You're Not The Owner Of This Shop")
				end
			else
				plsr.Execute:Client(source, "Notification", "Error", "Invalid Shop")
			end
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Inventory:PlayerShop:RemoveModerator", function(source, data, cb)
		local char = plsr.Fetch:CharacterSource(source)
		if char ~= nil then
			local sid = char:GetData("SID")
			if _playerShops[data.shop] ~= nil then
				if _playerShops[data.shop].owner == sid then
					INVENTORY.PlayerShops.Moderators:Remove(data.shop, data.sid)
					plsr.Execute:Client(source, "Notification", "Success", "Shop Moderator Removed")
				else
					plsr.Execute:Client(source, "Notification", "Error", "You're Not The Owner Of This Shop")
				end
			else
				plsr.Execute:Client(source, "Notification", "Error", "Invalid Shop")
			end
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Inventory:PlayerShop:ViewModerators", function(source, data, cb)
		local char = plsr.Fetch:CharacterSource(source)
		if char ~= nil then
			local sid = char:GetData("SID")
			if _playerShops[data] and _playerShops[data].owner == sid then
				local list = {}
				for k, v in pairs(_playerShopMods[data] or {}) do
					table.insert(list, {
						label = v.name,
						description = string.format("State ID: %s", v.sid),
						event = "Shop:Client:BasicShop:RemoveModerator",
						data = {
							shop = data,
							sid = v.sid,
							name = v.name
						}
					})
				end

				cb(list)
			else
				cb(false)
			end
		else
			cb(false)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Inventory:PlayerShop:ChangeState", function(source, data, cb)
		local char = plsr.Fetch:CharacterSource(source)
		if char ~= nil then
			if _playerShops[data.id] and isShopModerator(data.id, source) then
				if not _playerShops[data.id].job or plsr.Jobs.Permissions:HasPermissionInJob(source, _playerShops[data.id].job, "JOB_SHOP_CONTROL") then
					GlobalState[string.format("BasicShop:%s", data.id)] = data.state

					plsr.Execute:Client(source, "Notification", "Success", data.state and "Store Opened" or "Store Closed")

					cb(true)
				else
					cb(false)
				end
			else
				cb(false)
			end
		else
			cb(false)
		end
	end)
end

RegisterNetEvent("Inventory:Server:UpdateSettings", function(data)
	local src = source
	local char = plsr.Fetch:CharacterSource(src)
	if char ~= nil then
		local settings = char:GetData("InventorySettings") or _defInvSettings
		for k, v in pairs(data) do
			settings[k] = v
		end
		char:SetData("InventorySettings", settings)
	end
end)

RegisterNetEvent("Inventory:Server:TriggerAction", function(data)
	local src = source
	local char = plsr.Fetch:CharacterSource(src)
	if char ~= nil then
		if LoadedEntitys[data.invType] ~= nil and LoadedEntitys[data.invType].action ~= nil then
			TriggerEvent(LoadedEntitys[data.invType].action.event, src, data)
		end
	end
end)

RegisterNetEvent("Inventory:Server:Request", function(secondary)
	local src = source

	-- client-triggerable, requires a matching OpenSecondary grant
	if secondary and not secondary.crafting then
		if tonumber(secondary.invType) == 10 then
			if not validateInventoryAccess(src, secondary.owner, 10) then return end
		else
			local grant = _pendingOpen[src]
			if not grant or grant.expiresAt < os.time() or tostring(grant.owner) ~= tostring(secondary.owner) or grant.invType ~= tonumber(secondary.invType) then
				return
			end
			_pendingOpen[src] = nil
		end
	end

	local char = plsr.Fetch:CharacterSource(src)

	local plyrInvData = {
		size = (LoadedEntitys[1].slots or 10),
		name = char:GetData("First") .. " " .. char:GetData("Last"),
		inventory = {},
		invType = 1,
		capacity = LoadedEntitys[1].capacity,
		owner = char:GetData("SID"),
		isWeaponEligble = plsr.Weapons:IsEligible(src),
		qualifications = char:GetData("Qualifications") or {},
		loaded = false,
	}

	if secondary?.crafting then
		local benchDetails = plsr.Crafting:GetBench(source, secondary.id)
		if benchDetails ~= nil then
			benchDetails.crafting = true
			benchDetails.bench = secondary.id
	
			TriggerClientEvent("Inventory:Client:Open", src, plyrInvData, benchDetails)
			plyrInvData.inventory = getInventory(src, char:GetData("SID"), 1)
			plyrInvData.loaded = true
			--TriggerClientEvent("Inventory:Client:Cache", src, plyrInvData)
			TriggerClientEvent("Inventory:Client:Load", src, plyrInvData, benchDetails)

		end
	else
		TriggerClientEvent("Inventory:Client:Open", src, plyrInvData, secondary and INVENTORY:GetSecondaryData(src, secondary.invType, secondary.owner, secondary.class or false, secondary.model or false) or nil)
		plyrInvData.inventory = getInventory(src, char:GetData("SID"), 1)
		plyrInvData.loaded = true
		--TriggerClientEvent("Inventory:Client:Cache", src, plyrInvData)
		TriggerClientEvent("Inventory:Client:Load", src, plyrInvData, secondary and INVENTORY:GetSecondary(src, secondary.invType, secondary.owner, secondary.class or false, secondary.model or false) or nil)
	end
end)

-- CloseSecondary clears these on a normal close, but not a disconnect
AddEventHandler("playerDropped", function()
	local src = source
	_openSecondary[src] = nil
	_pendingOpen[src] = nil
end)

-- personal inventory only, stashes/shops they owned stay put for reassignment
AddEventHandler("Characters:Server:CharacterDeleted", function(data, sid)
	MySQL.query("DELETE FROM inventory WHERE owner = ? AND type = 1", { tostring(sid) })
end)

-- pure in-memory reads/writes against an already-loaded slots table, no lock/load/save of their own -
-- callers hold the lock for that owner:type and load/save it themselves, see AddItem below
local function freeSlotNumbersFromTable(slots, invType, vehClass, vehModel, owner, src)
	local occupiedTable = {}
	for i = 1, #slots do
		occupiedTable[slots[i].slot] = true
	end

	local total = 8
	if LoadedEntitys[invType] ~= nil then
		total = getSlotCount(invType, vehClass or false, vehModel or false, false, owner, src)
	else
		plsr.Logger:Error("Inventory", string.format("Entity Type ^2%s^7 Was Attempted To Be Loaded", invType))
	end

	local unOccupiedSlots = {}
	for i = 1, total do
		if not occupiedTable[i] then
			table.insert(unOccupiedSlots, i)
		end
	end
	table.sort(unOccupiedSlots)
	return unOccupiedSlots
end

local function matchingSlotFromTable(slots, Name, Count)
	if not itemsDatabase[Name].isStackable then
		return nil
	end
	for i = 1, #slots do
		local entry = slots[i]
		if entry.name == Name and entry.count + Count <= itemsDatabase[Name].isStackable then
			return entry.slot
		end
	end
	return nil
end

local function applySlotAdd(slots, Name, Count, MetaData, Slot, forceCreateDate, quality)
	if Count <= 0 then
		plsr.Logger:Error("Inventory", "[AddSlot] Cannot Add " .. Count .. " Of An Item")
		return false
	end

	if itemsDatabase[Name] == nil then
		plsr.Logger:Error("Inventory", string.format("Slot %s Has Invalid Item %s", Slot, Name))
		return false
	end

	local entry = FindSlotEntry(slots, Slot)
	if entry then
		-- the caller decided this slot was free
		if entry.name ~= Name then
			plsr.Logger:Error("Inventory", string.format("[AddSlot] Slot %s Is Occupied By %s, Refusing To Merge %s Into It", Slot, entry.name, Name))
			return false
		end
		entry.count += Count
		return true
	end

	local created = forceCreateDate or os.time()
	local expiry = -1
	if itemsDatabase[Name].durability ~= nil and itemsDatabase[Name].isDestroyed then
		expiry = created + itemsDatabase[Name].durability
	end

	table.insert(slots, {
		slot = Slot,
		name = Name,
		count = Count,
		quality = quality or 0,
		price = 0,
		createdAt = created,
		expiryDate = expiry,
		metadata = MetaData or {},
	})
	return true
end

local _inUse = {}
INVENTORY = {
	CreateDropzone = function(self, routeId, coords)
		local area = {
			id = string.format("%s:%s:%s", math.ceil(coords.x), math.ceil(coords.y), routeId),
			route = routeId,
			coords = {
				x = coords.x,
				y = coords.y,
				z = coords.z,
			},
		}

		table.insert(_dropzones, area)
		TriggerClientEvent("Inventory:Client:AddDropzone", -1, area)

		return area.id
	end,
	CheckDropZones = function(self, routeId, coords)
		local found = nil

		for k, v in ipairs(_dropzones) do
			if v.route == routeId then
				local dz = v.coords
				local distance = #(vector3(coords.x, coords.y, coords.z) - vector3(dz.x, dz.y, dz.z))
				if distance < 2.0 and (found == nil or distance < found.distance) then
					found = {
						id = v.id,
						position = v.coords,
						distance = distance,
						route = v.route,
					}
				end
			end
		end

		return found
	end,
	RemoveDropzone = function(self, routeId, id)
		for k, v in ipairs(_dropzones) do
			if v.id == id and v.route == routeId then
				if not _doingThings[string.format("%s-%s", id, 10)] then
					table.remove(_dropzones, k)
					TriggerClientEvent("Inventory:Client:RemoveDropzone", -1, id)
				end
				break
			end
		end
	end,
	DropExists = function(self, routeId, id)
		for k, v in ipairs(_dropzones) do
			if v.id == id and v.route == routeId then
				return true
			end
		end

		return false
	end,
	GetInventory = function(self, source, owner, invType)
		return getInventory(source, owner, invType)
	end,
	GetSecondaryData = function(self, _src, invType, Owner, vehClass, vehModel, isRaid, nameOverride, slotOverride, capacityOverride)
		if _src and invType and Owner then
			if entityPermCheck(_src, invType) or (isRaid and plsr.State:Player(_src).onDuty == "police") then
				if not _openInvs[string.format("%s-%s", Owner, invType)] or _openInvs[string.format("%s-%s", Owner, invType)] == _src then
					if not LoadedEntitys[invType].shop then
						_openInvs[string.format("%s-%s", Owner, invType)] = _src
					end
					
					local name = nameOverride or (LoadedEntitys[invType].name or "Unknown")
					if LoadedEntitys[invType].shop and shopLocations[Owner] ~= nil then
						name = string.format(
							"%s (%s)",
							shopLocations[Owner].name,
							LoadedEntitys[invType].name
						)
					end

					if LoadedEntitys[invType].playerShop and _playerShops[Owner] then
						name = _playerShops[Owner].name
					end

					local requestedInventory = {
						size = getSlotCount(invType, vehClass, vehModel, slotOverride, Owner, _src),
						name = name,
						class = vehClass,
						model = vehModel,
						capacity = getCapacity(invType, vehClass, vehModel, capacityOverride),
						shop = LoadedEntitys[invType].shop or false,
						playerShop = LoadedEntitys[invType].playerShop or false,
						modifyShop = LoadedEntitys[invType].playerShop and isShopModerator(Owner, _src) or false,
						free = LoadedEntitys[invType].free or false,
						inventory = {},
						invType = invType,
						owner = Owner,
						loaded = false,
						slotOverride = slotOverride,
						capacityOverride = capacityOverride,
					}

					return requestedInventory
				else
					return nil
				end
			end
		end
	end,
	GetSecondary = function(self, _src, invType, Owner, vehClass, vehModel, isRaid, nameOverride, slotOverride, capacityOverride)
		if _src and invType and Owner then
			if entityPermCheck(_src, invType) or (isRaid and plsr.State:Player(_src).onDuty == "police") then
				if not _openInvs[string.format("%s-%s", Owner, invType)] or _openInvs[string.format("%s-%s", Owner, invType)] == _src then
					if not LoadedEntitys[invType].shop then
						_openInvs[string.format("%s-%s", Owner, invType)] = _src
					end

					local name = nameOverride or (LoadedEntitys[invType].name or "Unknown")
					if LoadedEntitys[tonumber(invType)].shop and shopLocations[Owner] ~= nil then
						name = string.format(
							"%s (%s)",
							shopLocations[Owner].name,
							LoadedEntitys[tonumber(invType)].name
						)
					end

					if LoadedEntitys[tonumber(invType)].playerShop and _playerShops[Owner] then
						name = _playerShops[Owner].name
					end
	
					local requestedInventory = {
						size = getSlotCount(invType, vehClass, vehModel, slotOverride, Owner, _src),
						name = name,
						class = vehClass,
						model = vehModel,
						capacity = getCapacity(invType, vehClass, vehModel, capacityOverride),
						shop = LoadedEntitys[tonumber(invType)].shop or false,
						free = LoadedEntitys[tonumber(invType)].free or false,
						playerShop = LoadedEntitys[tonumber(invType)].playerShop or false,
						modifyShop = LoadedEntitys[tonumber(invType)].playerShop and isShopModerator(Owner, _src) or false,
						action = LoadedEntitys[tonumber(invType)].action or false,
						inventory = getInventory(_src, Owner, invType),
						invType = invType,
						owner = Owner,
						loaded = true,
						slotOverride = slotOverride,
						capacityOverride = capacityOverride,
					}
					
					return requestedInventory
				else
					return nil
				end
			else
				return nil
			end
		else
			return nil
		end
	end,
	OpenSecondary = function(self, _src, invType, Owner, vehClass, vehModel, isRaid, nameOverride, slotOverride, capacityOverride)
		if _src and invType and Owner then
			-- every trusted open path funnels through here; this is the real access grant
			_openSecondary[_src] = { owner = Owner, invType = invType, openedAt = os.time() }
			grantPendingOpen(_src, Owner, invType)

			local char = plsr.Fetch:CharacterSource(_src)

			local plyrInvData = {
				size = (LoadedEntitys[1].slots or 10),
				name = char:GetData("First") .. " " .. char:GetData("Last"),
				inventory = {},
				invType = 1,
				capacity = LoadedEntitys[1].capacity,
				owner = char:GetData("SID"),
				isWeaponEligble = plsr.Weapons:IsEligible(_src),
				qualifications = char:GetData("Qualifications") or {},
			}
		
			TriggerEvent("Inventory:Server:Opened", _src, Owner, invType)

			TriggerClientEvent("Inventory:Client:Open", _src, plyrInvData, INVENTORY:GetSecondaryData(_src, invType, Owner, vehClass, vehModel, isRaid, nameOverride, slotOverride, capacityOverride))
		
			plyrInvData.inventory = getInventory(_src, char:GetData("SID"), 1)
			plyrInvData.loaded = true
		
			TriggerClientEvent("Inventory:Client:Cache", _src, plyrInvData)
			TriggerClientEvent("Inventory:Client:Load", _src, plyrInvData, INVENTORY:GetSecondary(_src, invType, Owner, vehClass, vehModel, isRaid, nameOverride, slotOverride, capacityOverride))
		end
	end,
	GetSlots = function(self, Owner, Type)
		local slots = LoadInventoryRaw(Owner, Type)
		local out = {}
		for i = 1, #slots do
			table.insert(out, slots[i].slot)
		end
		table.sort(out)
		return out
	end,
	HasItems = function(self, Owner, Type)
		return #LoadInventoryRaw(Owner, Type) > 0
	end,
	-- called by plsr.Wallet:Modify to keep Config.CashAsItem's stack in sync with a cash change
	AdjustCashItem = function(self, sid, delta)
		if not Config.CashAsItem or not sid or not delta or delta == 0 then
			return false
		end

		local key = tostring(sid)
		_cashSyncGuard[key] = true

		local ok
		if delta > 0 then
			ok = INVENTORY:AddItem(sid, Config.CashAsItem, delta, {}, 1) ~= nil
		else
			ok = INVENTORY.Items:Remove(sid, 1, Config.CashAsItem, math.abs(delta))
		end

		_cashSyncGuard[key] = nil
		return ok
	end,
	GetMatchingSlot = function(self, Owner, Name, Count, Type)
		if not itemsDatabase[Name].isStackable then
			return nil
		end

		local slots = LoadInventoryRaw(Owner, Type)
		for i = 1, #slots do
			local entry = slots[i]
			if entry.name == Name and entry.count + Count <= itemsDatabase[Name].isStackable then
				return entry.slot
			end
		end
		return nil
	end,
	GetFreeSlotNumbers = function(self, Owner, invType, vehClass, vehModel, src)
		local result = INVENTORY:GetSlots(Owner, invType)
		local occupiedTable = {}
		local unOccupiedSlots = {}
		for k, v in ipairs(result) do
			occupiedTable[v] = true
		end

		local total = 8
		if LoadedEntitys[invType] ~= nil then
			total = getSlotCount(invType, vehClass or false, vehModel or false, false, Owner, src)
		else
			plsr.Logger:Error("Inventory", string.format("Entity Type ^2%s^7 Was Attempted To Be Loaded", invType))
		end

		for i = 1, total do
			if not occupiedTable[i] then
				table.insert(unOccupiedSlots, i)
			end
		end

		table.sort(unOccupiedSlots)

		return unOccupiedSlots
	end,
	SlotExists = function(self, Owner, Slot, Type)
		return FindSlotEntry(LoadInventoryRaw(Owner, Type), Slot) ~= nil
	end,
	GetSlot = function(self, Owner, Slot, Type)
		local entry = FindSlotEntry(LoadInventoryRaw(Owner, Type), Slot)
		if not entry then
			return nil
		end
		return SlotEntryToDoc(Owner, Type, entry)
	end,
	CountInSlot = function(self, Owner, Slot, Type)
		local entry = FindSlotEntry(LoadInventoryRaw(Owner, Type), Slot)
		return entry and entry.count or 0
	end,
	-- no more per-unit creationDate spread within a slot to pick "oldest" from
	GetOldestInSlot = function(self, Owner, Slot, Type)
		return self:GetSlot(Owner, Slot, Type)
	end,
	-- id is a synthesized "owner:invType:slot" string, there's no real row id anymore
	GetItem = function(self, id)
		local owner, invType, slot = id:match("^(.-):(.-):(.-)$")
		if not owner then
			return nil
		end
		return self:GetSlot(owner, tonumber(slot), tonumber(invType))
	end,
	AddItem = function(self, Owner, Name, Count, md, invType, vehClass, vehModel, entity, isRecurse, Slot, forceCreateDate, quality, skipMetaGen, skipChangeAlert)
		local p = promise.new()

		CreateThread(function()
			if vehClass == nil then
				vehClass = false
			end

			if vehModel == nil then
				vehModel = false
			end

			if entity == nil then
				entity = false
			end

			if not Count or not tonumber(Count) or Count <= 0 then
				Count = 1
			end

			local itemExist = itemsDatabase[Name]
			if not itemExist then
				p:resolve(false)
				return
			end

			if invType == 1 and not skipMetaGen then
				if not isRecurse and not skipChangeAlert then
					local char = plsr.Fetch:SID(Owner)
					if char ~= nil then
						TriggerClientEvent("Inventory:Client:Changed", char:GetData("Source"), "add", Name, Count)
					end
				end
			end

			-- held for the whole decide-a-slot-then-write-to-it sequence below, closes the gap that let two
			-- concurrent adds independently decide on the same free/matching slot and clobber each other
			local lock <close> = AcquireLocks({ ("%s:%s"):format(Owner, invType) })
			if not lock then
				plsr.Logger:Error("Inventory", string.format("[AddItem] Could Not Acquire Lock For %s-%s (Timed Out)", Owner, invType))
				p:resolve(false)
				return
			end

			local primarySlots = LoadInventoryRaw(Owner, invType)

			local slotsNeeded = math.ceil(Count / (itemExist.isStackable or 1))
			-- same math as checkDestWeight - over capacity forces freeSlots empty so this falls into the
			-- dropzone-overflow branch below instead of landing in the primary destination
			local overCapacity = (INVENTORY.Items:GetWeights(Owner, invType) + (itemExist.weight or 0) * Count) > getCapacity(invType, vehClass, vehModel, nil)
			local freeSlots = overCapacity and {} or freeSlotNumbersFromTable(primarySlots, invType, vehClass, vehModel, Owner)
			local slotsData = {}
			if Slot and not overCapacity then
				table.insert(slotsData, {
					owner = Owner,
					type = invType,
					slot = Slot
				})
			end
			if #freeSlots < slotsNeeded then
				for k, v in ipairs(freeSlots) do
					table.insert(slotsData, {
						owner = Owner,
						type = invType,
						slot = v
					})
				end

				-- overflowing to a dropzone is a different owner/type entirely, and rare (destination is
				-- effectively full) - falls back to the old per-slot locked path rather than the fast one above
				local char = plsr.Fetch:SID(Owner)
				local coords = { x = 900.441, y = -1757.186, z = 21.359 }
				local route = 0

				if char ~= nil then
					local x, y, z = table.unpack(GetEntityCoords(GetPlayerPed(char:GetData("Source"))))
					coords = { x = x, y = y, z = z - 0.98 }
					route = plsr.State:Player(char:GetData("Source")).currentRoute
				elseif entity ~= nil then
					local x, y, z = table.unpack(GetEntityCoords(entity))
					coords = { x = x, y = y, z = z }
					route = GetEntityRoutingBucket(entity)
				end

				local dz = INVENTORY:CheckDropZones(route, coords)
				local tOwn = nil
				if dz == nil then
					tOwn = INVENTORY:CreateDropzone(route, coords)
				else
					tOwn = dz.id
				end

				local t = INVENTORY:GetFreeSlotNumbers(tOwn, 10, vehClass, vehModel)
				for k, v in ipairs(t) do
					if #slotsData < slotsNeeded then
						table.insert(slotsData, {
							owner = tOwn,
							type = 10,
							slot = v
						})
					else
						break
					end
				end
			else
				for k, v in ipairs(freeSlots) do
					if #slotsData < slotsNeeded then
						table.insert(slotsData, {
							owner = Owner,
							type = invType,
							slot = v
						})
					else
						break
					end
				end
			end

			local MetaData = nil
			if not skipMetaGen then
				if invType == 1 then
					local char = plsr.Fetch:SID(Owner)
					if char ~= nil then
						if itemExist.name == "choplist" then
							md.Owner = char:GetData("SID")
						end
						MetaData = BuildMetaDataTable(char:GetData(), Name, md or false)
					else
						MetaData = BuildMetaDataTable({}, Name, md or false)
					end
				else
					MetaData = BuildMetaDataTable({}, Name, md or false)
				end
			else
				MetaData = table.copy(md or {})
			end

			local retval = false
			local qualSet = quality ~= nil
			local touchedPrimary = false

			for k, v in ipairs(slotsData) do
				if (itemExist.name == "meth_bag" or itemExist.name == "meth_brick" or itemExist.name == "coke_bag" or itemExist.name == "coke_brick") and not qualSet then
					quality = math.random(1, 100)
				elseif itemExist.name == "choplist" then
					MetaData.ChopList = plsr.Laptop.LSUnderground.Chopping:GenerateList(math.random(4, 8), math.random(3, 5))
				end

				local c = Count > (itemExist.isStackable or 1) and (itemExist.isStackable or 1) or Count

				if v.owner == Owner and v.type == invType then
					-- same live table for the whole loop, so this sees earlier iterations' own mutations immediately
					local mSlot = matchingSlotFromTable(primarySlots, Name, c)
					retval = applySlotAdd(primarySlots, Name, c, MetaData, mSlot or v.slot, forceCreateDate or false, quality or false)
					touchedPrimary = true
				else
					local mSlot = INVENTORY:GetMatchingSlot(v.owner, Name, c, v.type)
					retval = INVENTORY:AddSlot(v.owner, Name, c, MetaData, mSlot or v.slot, v.type, forceCreateDate or false, quality or false)
				end
			end

			if touchedPrimary then
				SaveInventory(Owner, invType, primarySlots)
			end

			if not isRecurse then
				if invType == 1 then
					if WEAPON_PROPS[itemExist.weapon or Name] ~= nil then
						_refreshAttchs[Owner] = true
					end

					if itemExist.gangChain ~= nil then
						_refreshGangChain[Owner] = true
					end
					refreshShit(Owner, true)
				end
			end

			p:resolve({ id = retval, MetaData = MetaData })
		end)

		return Citizen.Await(p)
	end,
	AddSlot = function(self, Owner, Name, Count, MetaData, Slot, Type, forceCreateDate, quality)
		if Count <= 0 then
			plsr.Logger:Error("Inventory", "[AddSlot] Cannot Add " .. Count .. " of an Item (" .. Owner .. ":" .. Type .. ")")
			return false
		end

		if Slot == nil then
			local freeSlots = INVENTORY:GetFreeSlotNumbers(Owner, Type)
			if #freeSlots == 0 then
				plsr.Logger:Error("Inventory", "[AddSlot] No Available Slots For " .. Owner .. ":" .. Type .. " And Passed Slot Was Nil")
				return false
			end
			Slot = freeSlots[1]
		end

		if itemsDatabase[Name] == nil then
			plsr.Logger:Error(
				"Inventory",
				string.format("Slot %s in %s-%s has invalid item %s", Slot, Owner, Type, Name)
			)
			return false
		end

		local created = forceCreateDate or os.time()
		local expiry = -1
		if itemsDatabase[Name].durability ~= nil and itemsDatabase[Name].isDestroyed then
			expiry = created + itemsDatabase[Name].durability
		end

		local saved, reason = MutateInventory(Owner, Type, function(slots)
			local entry = FindSlotEntry(slots, Slot)
			if entry then
				-- the caller decided this slot was free/matching before the lock was held, someone else
				-- may have claimed it since - refuse rather than silently merging into the wrong item
				if entry.name ~= Name then
					plsr.Logger:Error("Inventory", string.format("[AddSlot] Slot %s in %s-%s Is Occupied By %s, Refusing To Merge %s Into It", Slot, Owner, Type, entry.name, Name))
					return false
				end
				entry.count += Count
			else
				table.insert(slots, {
					slot = Slot,
					name = Name,
					count = Count,
					quality = quality or 0,
					price = 0,
					createdAt = created,
					expiryDate = expiry,
					metadata = MetaData or {},
				})
			end
		end)

		if not saved then
			plsr.Logger:Error("Inventory", string.format("[AddSlot] Failed To Save %s Into %s-%s Slot %s (%s)", Name, Owner, Type, Slot, tostring(reason)))
		end

		return saved
	end,
	-- id is a synthesized "owner:invType:slot" string, there's no real row id anymore
	SetItemCreateDate = function(self, id, value)
		local owner, invType, slot = tostring(id):match("^(.-):(.-):(.-)$")
		if not owner then
			return
		end
		MutateInventory(owner, tonumber(invType), function(slots)
			local entry = FindSlotEntry(slots, tonumber(slot))
			if not entry then
				return false
			end
			entry.createdAt = value
		end)
	end,
	SetMetaDataKey = function(self, id, key, value, source)
		local owner, invType, slot = tostring(id):match("^(.-):(.-):(.-)$")
		if not owner then
			return {}
		end
		invType, slot = tonumber(invType), tonumber(slot)

		local md = {}
		local ok = MutateInventory(owner, invType, function(slots)
			local entry = FindSlotEntry(slots, slot)
			if not entry then
				return false
			end
			entry.metadata = entry.metadata or {}
			entry.metadata[key] = value
			md = entry.metadata
		end)

		if ok and source then
			TriggerClientEvent("Inventory:Client:UpdateMetadata", source, slot, json.encode(md), key)
		end

		return md
	end,
	UpdateMetaData = function(self, id, updatingMeta)
		if type(updatingMeta) ~= "table" then
			return false
		end

		local owner, invType, slot = tostring(id):match("^(.-):(.-):(.-)$")
		if not owner then
			return {}
		end
		invType, slot = tonumber(invType), tonumber(slot)

		local md = {}
		MutateInventory(owner, invType, function(slots)
			local entry = FindSlotEntry(slots, slot)
			if not entry then
				return false
			end
			entry.metadata = entry.metadata or {}
			for k, v in pairs(updatingMeta) do
				entry.metadata[k] = v
			end
			md = entry.metadata
		end)

		return md
	end,
	Items = {
		GetData = function(self, item)
			return itemsDatabase[item]
		end,
		GetCatalog = function(self)
			return itemsDatabase
		end,
		GetCount = function(self, owner, invType, item)
			local counts = INVENTORY.Items:GetCounts(owner, invType)
			return counts[item] or 0
		end,
		GetCounts = function(self, owner, invType)
			if invType == 1 then
				if _invCounts[owner] == nil then
					getInventory(owner, owner, invType)
				end
				return _invCounts[owner]
			else
				-- non-players shouldn't be counting, so why are we here?
				return {}
			end
		end,
		GetWeights = function(self, owner, invType)
			local slots = LoadInventoryRaw(owner, invType)
			local weights = 0
			for i = 1, #slots do
				local itemData = itemsDatabase[slots[i].name]
				if itemData then
					weights += (slots[i].count * (itemData.weight or 0))

					local md = slots[i].MetaData
					if md then
						if md.ammo and md.ammo > 0 and itemData.ammoType then
							local ammoItem = itemsDatabase[itemData.ammoType]
							if ammoItem and ammoItem.bulletCount and ammoItem.bulletCount > 0 then
								weights += md.ammo * ((ammoItem.weight or 0) / ammoItem.bulletCount)
							end
						end

						if md.WeaponComponents then
							for _, comp in pairs(md.WeaponComponents) do
								local compItem = comp.item and itemsDatabase[comp.item]
								if compItem then
									weights += (compItem.weight or 0)
								end
							end
						end
					end
				end
			end
			return weights
		end,
		GetFirst = function(self, Owner, Name, invType)
			local slots = LoadInventoryRaw(Owner, invType)
			local now = os.time()
			local best = nil
			for i = 1, #slots do
				local entry = slots[i]
				if entry.name == Name and ((entry.expiryDate or -1) == -1 or entry.expiryDate >= now) then
					if not best
						or (entry.quality or 0) > (best.quality or 0)
						or ((entry.quality or 0) == (best.quality or 0) and (entry.createdAt or 0) < (best.createdAt or 0))
					then
						best = entry
					end
				end
			end
			return best and SlotEntryToDoc(Owner, invType, best) or nil
		end,
		GetAll = function(self, Owner, Name, invType)
			local slots = LoadInventoryRaw(Owner, invType)
			local out = {}
			for i = 1, #slots do
				if slots[i].name == Name then
					table.insert(out, SlotEntryToDoc(Owner, invType, slots[i]))
				end
			end
			table.sort(out, function(a, b)
				if a.Quality ~= b.Quality then return (a.Quality or 0) > (b.Quality or 0) end
				return a.CreateDate < b.CreateDate
			end)
			return out
		end,
		Has = function(self, owner, invType, item, count)
			local slots = LoadInventoryRaw(owner, invType)
			local total = 0
			for i = 1, #slots do
				if slots[i].name == item then
					total += slots[i].count
				end
			end
			return total >= (count or 1)
		end,
		-- id is a synthesized "owner:invType:slot" string, there's no real row id anymore
		HasId = function(self, owner, invType, id)
			local idOwner, idInvType, idSlot = tostring(id):match("^(.-):(.-):(.-)$")
			if not idOwner then
				return false
			end
			return tostring(idOwner) == tostring(owner)
				and tonumber(idInvType) == invType
				and FindSlotEntry(LoadInventoryRaw(owner, invType), tonumber(idSlot)) ~= nil
		end,
		HasItems = function(self, source, items)
			local char = plsr.Fetch:CharacterSource(source)
			local charId = char:GetData("SID")
			for k, v in ipairs(items) do
				if not INVENTORY.Items:Has(charId, 1, v.item, v.count) then
					return false
				end
			end
			return true
		end,
		HasAnyItems = function(self, source, items)
			local char = plsr.Fetch:CharacterSource(source)
			local charId = char:GetData("SID")

			for k, v in ipairs(items) do
				if INVENTORY.Items:Has(charId, 1, v.item, v.count) then
					return true
				end
			end

			return false
		end,
		GetAllOfType = function(self, owner, invType, itemType)
			local slots = LoadInventoryRaw(owner, invType)
			local out = {}
			for i = 1, #slots do
				local entry = slots[i]
				local itemData = itemsDatabase[entry.name]
				if itemData and itemData.type == itemType then
					table.insert(out, SlotEntryToDoc(owner, invType, entry))
				end
			end
			table.sort(out, function(a, b) return a.CreateDate < b.CreateDate end)
			return out
		end,
		GetAllOfTypeNoStack = function(self, owner, invType, itemType)
			local slots = LoadInventoryRaw(owner, invType)
			local out = {}
			for i = 1, #slots do
				local entry = slots[i]
				local itemData = itemsDatabase[entry.name]
				if itemData and itemData.type == itemType then
					table.insert(out, SlotEntryToDoc(owner, invType, entry))
				end
			end
			return out
		end,
		RegisterUse = function(self, item, id, cb)
			ItemCallbacks[item] = ItemCallbacks[item] or {}
			ItemCallbacks[item][id] = cb
			if itemsDatabase[item] and not itemsDatabase[item].isUsable then
				itemsDatabase[item].isUsable = true
			end

			if itemsDatabase[item]?.isUsable then
				for k, v in pairs(itemsDatabase) do
					if v.imitate == item then
						v.isUsable = true
					end
				end
			end
		end,
		Use = function(self, source, item, cb)
			if item == nil then
				return cb(false)
			end

			if not itemsDatabase[item.Name]?.isUsable or _inUse[source] then
				return cb(false)
			end

			local itemData = itemsDatabase[item.Name]
			if
				not itemData.durability
				or item ~= nil
					and item.CreateDate ~= nil
					and item.CreateDate + itemData.durability > os.time()
			then
				if itemData.closeUi then
					TriggerClientEvent("Inventory:CloseUI", source)
				end

				if
					itemData.useRestrict == nil
					or (itemData.useRestrict.job ~= nil and plsr.Jobs.Permissions:HasJob(
						source,
						itemData.useRestrict.job.id,
						itemData.useRestrict.job.workplace or false,
						itemData.useRestrict.job.grade or false,
						false,
						false,
						itemData.useRestrict.job.permissionKey or false
					) and (not itemData.useRestrict.job.duty or plsr.State:Player(source).onDuty == itemData.useRestrict.job.id))
					or (itemData.useRestrict.state and hasValue(char:GetData("States"), itemData.useRestrict.state))
					or (itemData.useRestrict.rep ~= nil and plsr.Reputation:GetLevel(source, itemData.useRestrict.rep.id) >= itemData.useRestrict.rep.level)
					or (itemData.useRestrict.character ~= nil and itemData.useRestrict.character == char:GetData("ID"))
					or (itemData.useRestrict.admin and plyr.Permissions:IsAdmin())
				then
					_inUse[source] = true
					TriggerClientEvent("Inventory:Client:InUse", source, _inUse[source])
					TriggerClientEvent("Inventory:Client:Changed", source, itemData.type == 2 and "holster" or "used", item.Name, 0, item.Slot)

					local used = true
					if itemData.animConfig ~= nil then
						used = false
						local p = promise.new()
						plsr.Callbacks:ClientCallback(source, "Inventory:ItemUse", itemData.animConfig, function(state)
							p:resolve(state)
						end)
						used = Citizen.Await(p)
					end

					if used then
						local retard = false
						if ItemCallbacks[item.Name] ~= nil then
							for k, callback in pairs(ItemCallbacks[item.Name]) do
								retard = true
								callback(source, item, itemsDatabase[item.Name])
							end
						elseif itemData.imitate and ItemCallbacks[itemData.imitate] ~= nil then
							for k, callback in pairs(ItemCallbacks[itemData.imitate]) do
								retard = true
								callback(source, item, itemsDatabase[item.Name])
							end
						end

						if retard then
							TriggerClientEvent("Markers:ItemAction", source, item)
						end
					end

					local sid = plsr.Fetch:CharacterSource(source):GetData("SID")
					if WEAPON_PROPS[item.Name] then
						_refreshAttchs[sid] = true
					end

					if itemData.gangChain ~= nil then
						_refreshGangChain[sid] = true
					end

					local char = plsr.Fetch:CharacterSource(source)
					sendRefreshForClient(source, char:GetData("SID"), 1, item.Slot)
					_inUse[source] = false
					TriggerClientEvent("Inventory:Client:InUse", source, _inUse[source])
					cb(used)
				else
					plsr.Execute:Client(source, "Notification", "Error", "You Can't Use That")
					cb(false)
				end

			else
				cb(false)
			end
		end,
		-- owner can be nil if a caller passes char:GetData("SID") mid-disconnect, just no-op
		Remove = function(self, owner, invType, item, count, skipUpdate)
			if not owner or not invType then
				return false
			end

			local removed = 0
			MutateInventory(owner, invType, function(slots)
				table.sort(slots, function(a, b) return a.slot < b.slot end)
				local i = 1
				while i <= #slots do
					local entry = slots[i]
					if entry.name == item and (not count or removed < count) then
						local take = count and math.min(count - removed, entry.count) or entry.count
						entry.count -= take
						removed += take
						if entry.count <= 0 then
							table.remove(slots, i)
						else
							i += 1
						end
					else
						i += 1
					end
				end
			end)

			if not skipUpdate then
				local itemData = itemsDatabase[item]
				if invType == 1 then
					local char = plsr.Fetch:SID(owner)
					if char ~= nil then
						local source = char:GetData("Source")
						TriggerClientEvent("Inventory:Client:Changed", source, "removed", item, count)
						if WEAPON_PROPS[itemData?.weapon or item] ~= nil then
							_refreshAttchs[owner] = source
						end
						if itemData?.gangChain ~= nil then
							_refreshGangChain[owner] = source
						end
						refreshShit(owner)
					end
				end
			end

			return removed >= (count or 0)
		end,
		RemoveId = function(self, owner, invType, item)
			if not owner or not invType then
				return true
			end

			MutateInventory(owner, invType, function(slots)
				RemoveSlotEntry(slots, item.Slot)
			end)

			if invType == 1 then
				local itemData = itemsDatabase[item.Name]
				local char = plsr.Fetch:SID(tonumber(owner))
				if char ~= nil then
					local source = char:GetData("Source")
					TriggerClientEvent("Inventory:Client:Changed", source, "removed", item.Name, 1)
					if WEAPON_PROPS[itemData?.weapon or item.Name] ~= nil then
						_refreshAttchs[owner] = source
					end

					if itemData?.gangChain ~= nil then
						_refreshGangChain[owner] = source
					end

					refreshShit(owner)
				end
			end

			return true
		end,
		-- owner can be nil if a caller passes char:GetData("SID") mid-disconnect, just no-op
		RemoveAll = function(self, owner, type, item)
			if not owner or not type then
				return true
			end

			MutateInventory(owner, type, function(slots)
				local i = 1
				while i <= #slots do
					if slots[i].name == item then
						table.remove(slots, i)
					else
						i += 1
					end
				end
			end)
			return true
		end,
		RemoveSlot = function(self, Owner, Name, Count, Slot, invType)
			if not Owner or not invType then
				return false
			end

			local entry = FindSlotEntry(LoadInventoryRaw(Owner, invType), Slot)
			if entry == nil then
				plsr.Logger:Error(
					"Inventory",
					"Failed to remove " .. Count .. " from Slot " .. Slot .. " for " .. Owner,
					{ console = false }
				)
				return false
			elseif entry.count < Count then
				return false
			end

			MutateInventory(Owner, invType, function(slots)
				local e = FindSlotEntry(slots, Slot)
				if not e or e.count < Count then
					return false
				end
				e.count -= Count
				if e.count <= 0 then
					RemoveSlotEntry(slots, Slot)
				end
			end)

			if invType == 1 then
				local itemData = itemsDatabase[Name]
				local char = plsr.Fetch:SID(Owner)
				if char ~= nil then
					local source = char:GetData("Source")
					TriggerClientEvent("Inventory:Client:Changed", source, "removed", Name, Count)
					if WEAPON_PROPS[itemData?.weapon or Name] ~= nil then
						_refreshAttchs[Owner] = source
					end

					if itemData?.gangChain ~= nil then
						_refreshGangChain[Owner] = source
					end

					refreshShit(Owner)
				end
			end

			return true
		end,
		RemoveList = function(self, owner, invType, items)
			for k, v in ipairs(items) do
				INVENTORY.Items:Remove(owner, invType, v.name, v.count)
			end
		end,
		GetWithStaticMetadata = function(self, masterKey, mainIdName, textureIdName, gender, data)
			for k, v in pairs(itemsDatabase) do
				if v.staticMetadata ~= nil
					and v.staticMetadata[masterKey] ~= nil
					and v.staticMetadata[masterKey][gender] ~= nil
					and v.staticMetadata[masterKey][gender][mainIdName] == data[mainIdName]
					and v.staticMetadata[masterKey][gender][textureIdName] == data[textureIdName]
				then
					return k
				end
			end

			return nil
		end,
	},
	Holding = {
		Put = function(self, source)
			CreateThread(function()
				local char = plsr.Fetch:CharacterSource(source)
				if char ~= nil then
					local sid = char:GetData("SID")
					local inv = getInventory(source, sid, 1)

					if #inv > 0 then
						local freeSlots = INVENTORY:GetFreeSlotNumbers(sid, 2)

						if #inv <= #freeSlots then
							MutateTwoInventories(sid, 1, sid, 2, function(fromSlots, toSlots)
								for k, v in ipairs(inv) do
									MoveSlotUnits(fromSlots, v.Slot, toSlots, freeSlots[k], v.Count)
								end
							end)
							refreshShit(sid)

							plsr.Execute:Client(source, "Notification", "Success", "Retreived Items")
						else
							plsr.Execute:Client(source, "Notification", "Error", "Not Enough Slots Available")
						end
					else
						plsr.Execute:Client(source, "Notification", "Error", "No Items To Retreive")
					end
				end
			end)
		end,
		Take = function(self, source)
			CreateThread(function()
				local char = plsr.Fetch:CharacterSource(source)
				if char ~= nil then
					local sid = char:GetData("SID")
					local inv = getInventory(source, sid, 2)

					if #inv > 0 then
						local freeSlots = INVENTORY:GetFreeSlotNumbers(sid, 1)

						if #inv <= #freeSlots then
							MutateTwoInventories(sid, 2, sid, 1, function(fromSlots, toSlots)
								for k, v in ipairs(inv) do
									MoveSlotUnits(fromSlots, v.Slot, toSlots, freeSlots[k], v.Count)
								end
							end)
							refreshShit(sid, true)

							plsr.Execute:Client(source, "Notification", "Success", "Retreived Items")
						else
							plsr.Execute:Client(source, "Notification", "Error", "Not Enough Slots Available")
						end
					else
						plsr.Execute:Client(source, "Notification", "Error", "No Items To Retreive")
					end
				end
			end)
		end,
	},
	Ballistics = {
		Clear = function(self, source, ballisticId, ballisticType)
			CreateThread(function()
				local char = plsr.Fetch:CharacterSource(source)
				if char ~= nil then
					local sid = char:GetData("SID")
					local inv = getInventory(source, ballisticId, ballisticType)

					if #inv > 0 then
						local freeSlots = INVENTORY:GetFreeSlotNumbers(sid, 1)

						if #inv <= #freeSlots then
							MutateTwoInventories(ballisticId, ballisticType, sid, 1, function(fromSlots, toSlots)
								for k, v in ipairs(inv) do
									MoveSlotUnits(fromSlots, v.Slot, toSlots, freeSlots[k], v.Count)
								end
							end)
							refreshShit(sid, true)
						end
					end
				end
			end)
		end,
	},
	Container = {
		Open = function(self, src, item, identifier)
			plsr.Callbacks:ClientCallback(src, "Inventory:Container:Open", {
				item = item,
				container = ("container:%s"):format(identifier),
			}, function()
				INVENTORY:OpenSecondary(src, itemsDatabase[item.Name].container, ("container:%s"):format(identifier))
			end)
		end,
	},
	Stash = {
		Open = function(self, src, invType, identifier)
			INVENTORY:OpenSecondary(src, invType, ("stash:%s"):format(identifier))
		end,
	},
	Shop = {
		Open = function(self, src, identifier)
			INVENTORY:OpenSecondary(src, 11, ("shop:%s"):format(identifier))
		end,
	},
	Search = {
		Character = function(self, src, tSrc, id)
			plsr.Callbacks:ClientCallback(tSrc, "Inventory:ForceClose", {}, function(state)
				plsr.Execute:Client(tSrc, "Notification", "Info", "You Were Searched")
				INVENTORY:OpenSecondary(src, 1, id)
			end)
		end,
	},
	Rob = function(self, src, tSrc, id)
		plsr.Callbacks:ClientCallback(tSrc, "Inventory:ForceClose", {}, function(state)
			INVENTORY:OpenSecondary(src, 1, id)
		end)
	end,
	Poly = {
		Create = function(self, data)
			table.insert(_polyInvs, data.id)
			GlobalState[string.format("Inventory:%s", data.id)] = data
		end,
		-- Add = {
		-- 	Box = function(self, id, coords, length, width, options, entityId, restrictions)

		-- 	end,
		-- 	Poly = function(self) end,
		-- 	Circle = function(self) end,
		-- },
		Remove = function(self, id)

		end,
	},
	IsOpen = function(self, invType, id)
		return _openInvs[string.format("%s-%s", invType, id)]
	end,
	-- a govid could be anywhere (stolen, evidence lockup, etc), so this scans every instance
	UpdateGovIDMugshot = function(self, stateId, mugshot)
		if not stateId or type(stateId) ~= "number" then
			return false
		end

		local rows = MySQL.query.await("SELECT owner, type, slots FROM inventory", {})
		for i = 1, #rows do
			local row = rows[i]
			local ok, scanned = pcall(json.decode, row.slots)
			if ok and type(scanned) == "table" then
				local hasMatch = false
				for j = 1, #scanned do
					local entry = scanned[j]
					if entry.name == "govid" and entry.metadata and tostring(entry.metadata.StateID) == tostring(stateId) then
						hasMatch = true
						break
					end
				end
				if hasMatch then
					MutateInventory(row.owner, row.type, function(slots)
						local changed = false
						for j = 1, #slots do
							local entry = slots[j]
							if entry.name == "govid" and entry.metadata and tostring(entry.metadata.StateID) == tostring(stateId) then
								entry.metadata.Mugshot = mugshot
								changed = true
							end
						end
						if not changed then
							return false
						end
					end)
				end
			end
		end

		return true
	end,
	PlayerShops = {
		Basic = {
			Create = function(self, name, position, ped, owner, bank, job)
				local id = MySQL.insert.await('INSERT INTO player_shops (name, position, ped_model, owner, job, owner_bank) VALUES(?, ?, ?, ?, ?, ?)', {
					name,
					json.encode(position),
					ped ~= "0" and ped or nil,
					owner,
					job ~= "0" and job or nil,
					bank,
				})
				_playerShops[id] = {
					id = id,
					name = name,
					ped_model = ped ~= "0" and ped or nil,
					position = position,
					owner = owner,
					job = job ~= "0" and job or nil,
					bank = bank,
				}
	
				TriggerClientEvent("Inventory:Client:BasicShop:Create", -1, _playerShops[id])
			end,
			Delete = function(self, id)
				local queries = {}
				table.insert(queries, {
					query = "DELETE FROM player_shops_moderators WHERE shop = ?",
					values = {
						id,
					}
				})
				table.insert(queries, {
					query = "DELETE FROM player_shops WHERE id = ?",
					values = {
						id,
					}
				})
				MySQL.transaction(queries)
				_playerShops[id] = nil
				_playerShopMods[id] = nil
				TriggerClientEvent("Inventory:Client:BasicShop:Delete", -1, id)
			end,
		},
		Moderators = {
			Add = function(self, shop, sid, name)
				MySQL.insert("INSERT INTO player_shops_moderators (shop, sid, name) VALUES(?, ?, ?) ON DUPLICATE KEY UPDATE shop = VALUES(shop), sid = VALUES(sid), name = VALUES(name)", {
					shop,
					sid,
					name
				})
				_playerShopMods[shop] = _playerShopMods[shop] or {}
				table.insert(_playerShopMods[shop], {
					sid = sid,
					name = name,
				})
			end,
			Remove = function(self, shop, sid)
				MySQL.query("DELETE FROM player_shops_moderators WHERE shop = ? AND sid = ?", {
					shop,
					sid,
				})

				_playerShopMods[shop] = _playerShopMods[shop] or {}
				for k, v in ipairs(_playerShopMods[shop]) do
					if v.sid == sid then
						table.remove(_playerShopMods[shop], k)
						break
					end
				end
			end
		}
	},
	ItemTemplate = {
		Create = function(self, itemId, label, description, type, rarity, weight, durability, stackLimit, iconOverride, price, itemData)
			EnsureCustomItemsSchema()
			local id = MySQL.query.await('INSERT INTO custom_items (description, type, rarity, iconOverride, price, weapon, imitate, isStackable, closeUi, metalic, weight, durability, isDestroyed, isRemoved, gun, requiresLicense, qualification, ammoType, bulletCount, container, staticMetadata, component, animConfig, statusChange, extra, schematic, name, label) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
				description or nil,
				type or 1,
				rarity or 1,
				iconOverride or nil,
				price >= 0 and price or 0,
				itemData?.weapon or nil,
				itemData?.imitate or nil,
				stackLimit or 1,
				itemData?.closeUi or false,
				itemData?.metalic or false,
				weight >= 0 and weight or nil,
				durability >= 0 and durability or nil,
				itemData?.isDestroyed or false,
				itemData?.isRemoved or false,
				type == 2,
				itemData?.requiresLicense or false,
				itemData?.qualification or nil,
				itemData?.ammoType or nil,
				itemData?.bulletCount or 0,
				itemData?.container or nil,
				itemData?.staticMetadata and json.encode(itemData?.staticMetadata) or nil,
				itemData?.component and json.encode(itemData?.component) or nil,
				itemData?.animConfig and json.encode(itemData?.animConfig) or nil,
				itemData?.statusChange and json.encode(itemData?.statusChange) or nil,
				itemData?.extra and json.encode(itemData?.extra) or nil,
				itemData?.schematic or nil,
				itemId,
				label,
			})

			itemsDatabase[itemId] = {
				name = itemId,
				label = label,
				description = description or nil,
				type = type or 1,
				rarity = rarity or 1,
				iconOverride = iconOverride or nil,
				price = price >= 0 and price or 0,
				weapon = itemData?.weapon or nil,
				imitate = itemData?.imitate or nil,
				isStackable = stackLimit or 1,
				closeUi = itemData?.closeUi or false,
				metalic = itemData?.metalic or false,
				weight = weight >= 0 and weight or nil,
				durability = durability >= 0 and durability or nil,
				isDestroyed = itemData?.isDestroyed or false,
				isRemoved = itemData?.isRemoved or false,
				gun = type == 2,
				requiresLicense = itemData?.requiresLicense or false,
				qualification = itemData?.qualification or nil,
				ammoType = itemData?.ammoType or nil,
				bulletCount = itemData?.bulletCount or 0,
				container = itemData?.container or nil,
				staticMetadata = itemData?.staticMetadata or nil,
				component = itemData?.component or nil,
				animConfig = itemData?.animConfig or nil,
				statusChange = itemData?.statusChange or nil,
				schematic = itemData?.schematic or nil,
			}

			if itemData?.extra then
				for k, v in pairs(itemData.extra) do
					itemsDatabase[itemId][k] = v
				end
			end

			SetupItemUses(itemsDatabase[itemId])

			TriggerEvent("Inventory:Server:NewItemCreated", itemId, type)
			TriggerLatentClientEvent("Inventory:Client:NewItemCreated", -1, 50000, itemsDatabase[itemId])

			return itemsDatabase[itemId]
		end,
	}
}

function UpdateCharacterItemStates(source, inventory, adding)
	local char = plsr.Fetch:CharacterSource(source)
	if not char then
		return
	end
	local changedState = false
	local playerStates = char:GetData("States") or {}

	local allInventoryStates = {}
	for k, v in ipairs(inventory) do
		local item = itemsDatabase[v.Name]
		if item ~= nil and item.state ~= nil and (item.durability == nil or (os.time() - v.CreateDate < item.durability)) then
			table.insert(allInventoryStates, item.state)
		end
	end

	if adding then
		for item, itemState in pairs(allInventoryStates) do
			if not plsr.Utils:DoesTableHaveValue(playerStates, itemState) then
				table.insert(playerStates, itemState)
				changedState = true
			end
		end
	end

	local s = {}
	for i = #playerStates, 1, -1 do
		if
			not plsr.Utils:DoesTableHaveValue(allInventoryStates, playerStates[i])
			and string.sub(playerStates[i], 1, string.len("SCRIPT")) ~= "SCRIPT"
			and string.sub(playerStates[i], 1, string.len("ACCESS")) ~= "ACCESS"
		then
			table.remove(playerStates, i)
			changedState = true
		end
	end

	if changedState then
		char:SetData("States", playerStates)
	end
end


function UpdateCharacterGangChain(source, inventory)
	local char = plsr.Fetch:CharacterSource(source)
	if not char then
		return
	end

	local gangChains = {}
	for k, v in ipairs(inventory) do
		local item = itemsDatabase[v.Name]
		if item ~= nil and item.gangChain ~= nil then
			table.insert(gangChains, item.gangChain)
		end
	end

	local myGangChain = char:GetData("GangChain") or nil
	if myGangChain ~= nil and not plsr.Utils:DoesTableHaveValue(gangChains, myGangChain) then
		char:SetData("GangChain", "NONE")
	end
end