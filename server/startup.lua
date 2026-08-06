STORE_SHARE_AMOUNT = 0.8

repairWindow = (60 * 60 * 24) * 7 -- Give 7 day period before we completely delete item

itemsDatabase = {}
itemClasses = {}
itemsWithState = {}

_schematics = _schematics or {}

itemsLoaded = false
_started = false

_dbItems = {}

-- item catalog is pure Lua now; this just flattens _itemsSource into the runtime lookup table
function UpdateDatabaseItems()
	for k, v in pairs(_itemsSource) do
		for k2, v2 in ipairs(v) do
			itemsDatabase[v2.name] = v2
		end
	end
end

function EnsureCustomItemsSchema()
	MySQL.query.await([[
		CREATE TABLE IF NOT EXISTS `custom_items` (
			`name` char(64) CHARACTER SET big5 COLLATE big5_bin NOT NULL,
			`label` varchar(128) NOT NULL,
			`description` varchar(256) DEFAULT NULL,
			`type` int(11) NOT NULL,
			`rarity` int(11) NOT NULL,
			`iconOverride` varchar(256) DEFAULT NULL,
			`price` int(10) unsigned NOT NULL DEFAULT 0,
			`weapon` varchar(256) DEFAULT NULL,
			`state` varchar(256) DEFAULT NULL,
			`weight` int(10) unsigned NOT NULL DEFAULT 0,
			`imitate` char(64) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
			`isStackable` int(10) unsigned DEFAULT NULL,
			`closeUi` tinyint(1) NOT NULL DEFAULT 0,
			`metalic` tinyint(1) NOT NULL DEFAULT 0,
			`durability` bigint(20) unsigned DEFAULT NULL,
			`isUsable` tinyint(1) NOT NULL DEFAULT 0,
			`isDestroyed` tinyint(1) NOT NULL DEFAULT 0,
			`isRemoved` tinyint(1) NOT NULL DEFAULT 0,
			`gun` tinyint(1) NOT NULL DEFAULT 0,
			`requiresLicense` tinyint(1) NOT NULL DEFAULT 0,
			`qualification` varchar(32) DEFAULT NULL,
			`ammoType` varchar(32) DEFAULT NULL,
			`bulletCount` int(10) unsigned DEFAULT NULL,
			`container` int(10) unsigned DEFAULT NULL,
			`staticMetadata` longtext DEFAULT NULL,
			`component` longtext DEFAULT NULL,
			`animConfig` longtext DEFAULT NULL,
			`statusChange` longtext DEFAULT NULL,
			`extra` longtext DEFAULT NULL,
			`schematic` varchar(64) DEFAULT NULL,
			PRIMARY KEY (`name`) USING BTREE
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci
	]])
end

function LoadItemsFromDb()
	EnsureCustomItemsSchema()
	local iDb = MySQL.query.await("SELECT * FROM custom_items WHERE name IS NOT NULL", {})

	for k, v in ipairs(iDb) do
		if v.isStackable == 0 then
			v.isStackable = false
		end

		if v.staticMetadata then
			v.staticMetadata = json.decode(v.staticMetadata)
		end

		if v.component then
			v.component = json.decode(v.component)
		end

		if v.animConfig then
			v.animConfig = json.decode(v.animConfig)
		end

		if v.statusChange then
			v.statusChange = json.decode(v.statusChange)
		end

		if v.extra then
			for k2, v2 in pairs(json.decode(v.extra)) do
				v[k2] = v2
			end
		end

		if not v.isUsable and ItemCallbacks[v.name] ~= nil then
			v.isUsable = true
		end

		itemClasses[v.type] = itemClasses[v.type] or {}
		table.insert(itemClasses[v.type], v.name)
		itemsDatabase[v.name] = v
		_dbItems[v.name] = v
	end

	for k, v in pairs(itemsDatabase) do
		SetupItemUses(v)
	end

	itemsLoaded = true

	RegisterRandomItems()

	plsr.Logger:Trace("Inventory", string.format("Loaded ^2%s^7 Items", #iDb))
	TriggerLatentClientEvent("Inventory:Client:LoadItems", -1, 50000, _dbItems)
end

local tmpItems = { paleto_access_codes = true, event_invite = true }
function ClearDropZones()
	-- dropzones and trash types get wiped as whole instances, no need to look inside the blob
	local f = MySQL.query.await("DELETE FROM inventory WHERE type = ?", { 10 })

	plsr.Logger:Info("Inventory", string.format("Cleaned Up ^2%s^7 Items In Dropzones", f.affectedRows))

	local trash = 0
	local s = {}
	for k, v in pairs(LoadedEntitys) do
		if v.trash then
			table.insert(s, v.id)
		end
	end

	local t = MySQL.query.await("DELETE FROM inventory WHERE type IN (" .. table.concat(s, ",") .. ")")
	trash += t.affectedRows

	plsr.Logger:Info("Inventory", string.format("Cleaned Up ^2%s^7 Items In Trash Inventories", trash))

	-- these can be anywhere, so every remaining instance needs a look inside its blob
	local removedTmp = 0
	local rows = MySQL.query.await("SELECT owner, type, slots FROM inventory", {})
	for i = 1, #rows do
		local row = rows[i]
		local ok, scanned = pcall(json.decode, row.slots)
		if ok and type(scanned) == "table" then
			local hasTmp = false
			for j = 1, #scanned do
				if tmpItems[scanned[j].name] then
					hasTmp = true
					break
				end
			end
			if hasTmp then
				MutateInventory(row.owner, row.type, function(slots)
					local before = #slots
					local j = 1
					while j <= #slots do
						if tmpItems[slots[j].name] then
							table.remove(slots, j)
						else
							j += 1
						end
					end
					removedTmp += (before - #slots)
				end)
			end
		end
	end
	plsr.Logger:Info("Inventory", string.format("Cleaned Up ^2%s^7 Temporary Items", removedTmp))
end

function ClearLocalVehicleInventories()
	local d = MySQL.query.await("DELETE FROM inventory WHERE SUBSTRING(owner, 11, 1) = ? AND type = ?", { "B", 4 })
	plsr.Logger:Info("Inventory", string.format("Cleaned Up ^2%s^7 Local Vehicle Inventories", d.affectedRows))
end

function countTable(t)
	local c = 0
	for k, v in pairs(t) do
		c += 1
	end
	return c
end

-- expiry lives in each slot's json now, so this has to scan every instance, no indexed DELETE anymore
function ClearBrokenItemsSweep()
	local removed = 0
	local now = os.time()
	local rows = MySQL.query.await("SELECT owner, type FROM inventory", {})
	for i = 1, #rows do
		local row = rows[i]
		MutateInventory(row.owner, row.type, function(slots)
			local before = #slots
			local j = 1
			while j <= #slots do
				local expiry = slots[j].expiryDate
				if expiry and expiry >= 0 and expiry < now then
					table.remove(slots, j)
				else
					j += 1
				end
			end
			removed += (before - #slots)
			if before == #slots then
				return false
			end
		end)
	end
	plsr.Logger:Info("Inventory", string.format("Cleaned Up ^2%s^7 Degraded Items", removed))
end

function ClearBrokenItems()
	if _started then
		return
	end
	_started = true

	ClearBrokenItemsSweep()

	CreateThread(function()
		while _started do
			Wait((1000 * 60) * 30)
			ClearBrokenItemsSweep()
		end
	end)
end

function SetupGarbage()
	if _trashCans then
		for storageId, storage in ipairs(_trashCans) do
			INVENTORY.Poly:Create(storage)
		end
	end
end

function SetupItemUses(itemData)
	if itemData.state ~= nil then
		itemsWithState[itemData.name] = itemData.state
	end

	if itemData.type == 1 and itemsDatabase[itemData.name].statusChange ~= nil then
		INVENTORY.Items:RegisterUse(itemData.name, "StatusConsumable", function(source, item) -- Foo
			INVENTORY.Items:RemoveSlot(item.Owner, item.Name, 1, item.Slot, 1)

			if itemsDatabase[item.Name].statusChange.Add ~= nil then
				for k, v in pairs(itemsDatabase[item.Name].statusChange.Add) do
					TriggerClientEvent("Status:Client:updateStatus", source, k, true, v)
				end
			end

			if itemsDatabase[item.Name].statusChange.Remove ~= nil then
				for k, v in pairs(itemsDatabase[item.Name].statusChange.Remove) do
					TriggerClientEvent("Status:Client:updateStatus", source, k, false, -v)
				end
			end

			if itemsDatabase[item.Name].statusChange.Ignore ~= nil then
				for k, v in pairs(itemsDatabase[item.Name].statusChange.Ignore) do
					plsr.State:Player(source)[string.format("ignore%s", k)] = v
				end
			end

			if itemsDatabase[item.Name].progressModifier ~= nil then
				plsr.Execute:Client(
					source,
					"Progress",
					"Modifier",
					itemsDatabase[item.Name].progressModifier.modifier,
					math.random(
						itemsDatabase[item.Name].progressModifier.min,
						itemsDatabase[item.Name].progressModifier.max
					) * (60 * 1000)
				)
			end

			if itemsDatabase[item.Name].energyModifier ~= nil then
				TriggerClientEvent(
					"Inventory:Client:SpeedyBoi",
					source,
					itemsDatabase[item.Name].energyModifier.modifier,
					itemsDatabase[item.Name].energyModifier.duration * 1000,
					itemsDatabase[item.Name].energyModifier.cooldown * 1000,
					itemsDatabase[item.Name].energyModifier.skipScreenEffects
				)
			end

			if itemsDatabase[item.Name].healthModifier ~= nil then
				TriggerClientEvent("Inventory:Client:HealthModifier", source, itemsDatabase[item.Name].healthModifier)
			end

			if itemsDatabase[item.Name].armourModifier ~= nil then
				TriggerClientEvent("Inventory:Client:ArmourModifier", source, itemsDatabase[item.Name].armourModifier)
			end

			if itemsDatabase[item.Name].stressTicks ~= nil then
				plsr.State:Player(source).stressTicks = itemsDatabase[item.Name].stressTicks
				TriggerClientEvent("Status:Client:Ticks:Stress", source)
			end
		end)
	elseif itemData.type == 2 then
		INVENTORY.Items:RegisterUse(itemData.name, "Weapons", function(source, item)
			TriggerClientEvent("Weapons:Client:Use", source, item)
		end)
	elseif itemData.type == 9 then
		INVENTORY.Items:RegisterUse(itemData.name, "Ammo", function(source, item)
			plsr.Callbacks:ClientCallback(source, "Weapons:AddAmmo", itemsDatabase[item.Name], function(state)
				if state then
					plsr.Inventory.Items:RemoveSlot(item.Owner, item.Name, 1, item.Slot, 1)
				end
			end)
		end)
	elseif itemData.type == 10 then
		INVENTORY.Items:RegisterUse(itemData.name, "Containers", function(source, item)
			INVENTORY.Container:Open(source, item, item.MetaData.Container)
		end)
	elseif itemData.imitate and itemsDatabase[itemData.imitate] ~= nil and itemsDatabase[itemData.imitate].isUsable then
		itemsDatabase[itemData.name].isUsable = true
		itemsDatabase[itemData.name].closeUi = itemsDatabase[itemData.imitate].closeUi
	elseif itemData.gangChain ~= nil then
		INVENTORY.Items:RegisterUse(itemData.name, "GangChains", function(source, item)
			local char = plsr.Fetch:CharacterSource(source)
			if itemData.gangChain ~= nil then
				if itemData.gangChain ~= char:GetData("GangChain") then
					TriggerClientEvent("Ped:Client:ChainAnim", source)
					Wait(3000)
					char:SetData("GangChain", itemData.gangChain)
				else
					TriggerClientEvent("Ped:Client:ChainAnim", source)
					Wait(3000)
					char:SetData("GangChain", "NONE")
				end
			end
		end)
	elseif itemData.type == 16 and itemData.component ~= nil then
		INVENTORY.Items:RegisterUse(itemData.name, "WeaponAttachments", function(source, item)
			plsr.Weapons:EquipAttachment(source, item)
		end)
	end

	if itemData.drugState ~= nil then
		INVENTORY.Items:RegisterUse(itemData.name, "DrugStates", function(source, item)
			local char = plsr.Fetch:CharacterSource(source)
			if char ~= nil then
				local drugStates = char:GetData("DrugStates") or {}
				drugStates[itemData.drugState.type] = {
					item = itemData.name,
					expires = os.time() + itemData.drugState.duration,
				}
				char:SetData("DrugStates", drugStates)
			end
		end)
	end

	if itemData.phoneCase ~= nil then
		INVENTORY.Items:RegisterUse(itemData.name, "PhoneCase", function(source, item)
			local char = plsr.Fetch:CharacterSource(source, true)
			if char ~= nil then
				char:SetData("PhoneCase", itemData.phoneCase)
				INVENTORY.Items:RemoveSlot(item.Owner, item.Name, 1, item.Slot, 1)
			end
		end)
	end
end

function LoadItems()
	local c = 0
	for _, its in pairs(_itemsSource) do
		for k, v in ipairs(its) do
			c = c + 1
			itemClasses[v.type] = itemClasses[v.type] or {}
			table.insert(itemClasses[v.type], v.name)
			itemsDatabase[v.name] = v

			SetupItemUses(v)
		end
	end

	itemsLoaded = true

	RegisterRandomItems()
	plsr.Logger:Trace("Inventory", string.format("Loaded ^2%s^7 Items", c))
end

function LoadEntityTypes()
	for k, v in ipairs(_entityTypes) do
		LoadedEntitys[tonumber(v.id)] = v
	end
	plsr.Logger:Trace("Inventory", string.format("Loaded ^2%s^7 Inventory Entity Types", #_entityTypes))
end

shopLocations = {}
storeBankAccounts = {}
pendingShopDeposits = {}
local _startingPendingDepositThread = false
function LoadShops()
	CreateThread(function()
		Wait(10000)

		local f = plsr.Banking.Accounts:GetOrganization("dgang")

		for k, v in ipairs(_shops) do
			local id = k
			if v.id ~= nil then
				id = v.id
			else
				v.id = k
			end

			v.restriction = LoadedEntitys[v.entityId].restriction
			shopLocations[string.format("shop:%s", id)] = v
		end

		for k, v in pairs(_entityTypes) do
			storeBankAccounts[v.id] = f.Account
		end

		local t = MySQL.rawExecute.await("SELECT shop, bank FROM shop_bank_accounts")
		for k, v in ipairs(t) do
			storeBankAccounts[v.shop] = v.bank
		end

		plsr.Logger:Trace("Inventory", string.format("Loaded ^2%s^7 Shop Locations", #_shops))
	end)

	if not _startingPendingDepositThread then
		_startingPendingDepositThread = true
		CreateThread(function()
			while true do
				Wait(1000 * 60 * 60)

				for k, v in pairs(pendingShopDeposits) do
					if v.tax then
						plsr.Logger:Trace(
							"Inventory",
							string.format(
								"Depositing ^2$%s^7 To ^3%s^7 For Tax On ^2%s^7 Store Transactions",
								v.amount,
								k,
								v.transactions
							)
						)
						plsr.Banking.Balance:Deposit(k, v.amount, {
							type = "deposit",
							title = "Sales Tax",
							description = string.format("Deposit For Sales Tax On %s Store Sales", v.transactions),
							data = {},
						}, true)
					else
						plsr.Logger:Trace(
							"Inventory",
							string.format(
								"Depositing ^2$%s^7 To ^3%s^7 For ^2%s^7 Store Transactions",
								v.amount,
								k,
								v.transactions
							)
						)
						plsr.Banking.Balance:Deposit(k, v.amount, {
							type = "deposit",
							title = "Store Sales",
							description = string.format("Deposit For %s Store Sales", v.transactions),
							data = {},
						}, true)
					end

					pendingShopDeposits[k] = nil
				end
			end
		end)
	end
end

function RegisterCommands()
	plsr.Chat:RegisterAdminCommand("storebank", function(source, args, rawCommand)
		MySQL.query.await(
			"INSERT INTO shop_bank_accounts (shop, bank) VALUES(?, ?) ON DUPLICATE KEY UPDATE bank = VALUES(bank)",
			{
				tonumber(args[1]),
				tonumber(args[2]),
			}
		)
		storeBankAccounts[string.format("shop:%s", tonumber(args[1]))] = tonumber(args[2])
	end, {
		help = "Link Bank Account To Shop",
		params = {
			{
				name = "Shop ID",
				help = "Shop Entity ID To Attach Bank Account To",
			},
			{
				name = "Account Number",
				help = "Account Number To Attach Bank Account To",
			},
		},
	}, 2)

	plsr.Chat:RegisterAdminCommand("openinv", function(source, args, rawCommand)
		if source == nil or source <= 0 then
			plsr.Logger:Info("Inventory", "Source is empty. This is sus.")
			return
		end
		if args[1] == nil or args[1] == "" then
			plsr.Logger:Info("Inventory", "Player SID is not valid!")
			return
		end
		local char = plsr.Fetch:SID(tonumber(args[1]), true)
		if char == nil then
			plsr.Logger:Info("Inventory", "Player does not exist!")
			return
		end
		plsr.Logger:Info(
			"Inventory",
			string.format(
				"Opening Secondary Inventory: %s %s (%s)",
				char:GetData("First"),
				char:GetData("Last"),
				char:GetData("SID")
			)
		)
		INVENTORY:OpenSecondary(source, 1, tonumber(args[1]))
	end, {
		help = "Open Secondary Inventory",
		params = {
			{
				name = "State ID",
				help = "Player State ID",
			},
		},
	}, 1)

	plsr.Chat:RegisterAdminCommand("removecd", function(source, args, rawCommand)
		RemoveCraftingCooldown(source, args[1], args[2])
	end, {
		help = "Remove Crafting Cooldown From A Bench",
		params = {
			{
				name = "Bench ID",
				help = "Unique ID of the bench to interact with",
			},
			{
				name = "Craft Key",
				help = "Unique key for the craft item",
			},
		},
	}, 2)

	plsr.Chat:RegisterAdminCommand("clearinventory", function(source, args, rawCommand)
		local char = plsr.Fetch:CharacterSource(source)
		local tChar = plsr.Fetch:SID(tonumber(args[1]), true)
		if tChar == nil then
			plsr.Execute:Client(source, "Notification", "Error", "This player is not online")
			return
		end

		local sid = char:GetData("SID")
		local tsid = tChar:GetData("SID")

		local lock <close> = AcquireLocks({ ("%s:%s"):format(sid, 1) })
		if lock then
			MySQL.query.await("DELETE FROM inventory WHERE owner = ? AND type = ?", { sid, 1 })
		end
		plsr.Execute:Client(
			tChar:GetData("Source"),
			"Notification",
			"Error",
			"Your inventory was cleared by " .. tostring(tsid)
		)
		plsr.Execute:Client(source, "Notification", "Success", "You cleared the inventory of " .. tostring(sid))
		refreshShit(tsid, true)
	end, {
		help = "Clear Player Inventory",
		params = {
			{
				name = "SID",
				help = "SID of the Player",
			},
		},
	}, 1)

	plsr.Chat:RegisterAdminCommand("clearinventory2", function(source, args, rawCommand)
		local Owner, Type = args[1], tonumber(args[2])

		if Owner and Type then
			local lock <close> = AcquireLocks({ ("%s:%s"):format(Owner, Type) })
			if lock then
				MySQL.query.await("DELETE FROM inventory WHERE owner = ? AND type = ?", { Owner, Type })
			end
			plsr.Execute:Client(
				source,
				"Notification",
				"Success",
				string.format("You cleared inventory of %s-%s", Owner, Type)
			)
		end
	end, {
		help = "Clear Inventory",
		params = {
			{
				name = "Owner",
				help = "Inventory Owner",
			},
			{
				name = "Type",
				help = "Inventory Type",
			},
		},
	}, 2)

	plsr.Chat:RegisterAdminCommand("giveitem", function(source, args, rawCommand)
		local char = plsr.Fetch:CharacterSource(source, true)
		if char and tostring(args[1]) ~= nil and tonumber(args[2]) ~= nil then
			local itemExist = itemsDatabase[args[1]]
			if itemExist then
				if itemExist.type ~= 2 then
					INVENTORY:AddItem(char:GetData("SID"), args[1], tonumber(args[2]), {}, 1)
				else
					plsr.Execute:Client(
						source,
						"Notification",
						"Error",
						"You can only give items with this command, try /giveweapon"
					)
				end
			else
				plsr.Execute:Client(source, "Notification", "Error", "Item not located")
			end
		end
	end, {
		help = "Give Item",
		params = {
			{
				name = "Item Name",
				help = "The name of the Item",
			},
			{
				name = "Item Count",
				help = "The count of the Item",
			},
		},
	}, 2)

	plsr.Chat:RegisterAdminCommand("giveweapon", function(source, args, rawCommand)
		local char = plsr.Fetch:CharacterSource(source)
		if tostring(args[1]) ~= nil then
			local weapon = string.upper(args[1])
			local itemExist = itemsDatabase[weapon]
			if itemExist then
				if itemExist.type == 2 then
					local sid = char:GetData("SID")
					if itemExist.isThrowable then
						INVENTORY:AddItem(sid, weapon, tonumber(args[2]), { ammo = 1, clip = 0 }, 1)
					else
						local ammo = 0
						if args[2] ~= nil then
							ammo = tonumber(args[2])
						end

						INVENTORY:AddItem(
							sid,
							weapon,
							1,
							{ ammo = ammo, clip = 0, Scratched = args[3] == "1" or nil },
							1
						)
					end
				else
					plsr.Execute:Client(
						source,
						"Notification",
						"Error",
						"You can only give weapons with this command, try /giveitem"
					)
				end
			else
				plsr.Execute:Client(source, "Notification", "Error", "Weapon not located")
			end
		end
	end, {
		help = "Give Weapon",
		params = {
			{
				name = "Weapon Name",
				help = "The name of the Weapon",
			},
			{
				name = "Ammo",
				help = "[Optional] The amount of ammo with the weapon.",
			},
			{
				name = "Is Scratched?",
				help = "Whether to spawn with a normal serial number registered to you, or a scratched serial number (1 = true, 0 = false).",
			},
		},
	}, 3)

	plsr.Chat:RegisterAdminCommand("vanityitemnew", function(source, args, rawCommand)
		local label, image, amount, text, action = args[1], args[2], tonumber(args[3]), args[4], args[5]

		local char = plsr.Fetch:CharacterSource(source)
		if char and label and image and amount and amount > 0 then
			local t = plsr.Sequence:Get("VanityItem")
			local newItem = INVENTORY.ItemTemplate:Create(
				string.format("vanityitem%s", t),
				label,
				text,
				5,
				3,
				0,
				-1,
				25,
				false,
				0,
				{
					imitate = "vanityitem",
					staticMetadata = {
						CustomItemImage = image,
						CustomItemAction = action,
					},
				}
			)

			INVENTORY:AddItem(char:GetData("SID"), newItem.name, amount, {}, 1)
		else
			plsr.Execute:Client(source, "Notification", "Error", "Wrong")
		end
	end, {
		help = "Create a Vanity Item",
		params = {
			{
				name = "Label",
				help = "Item Label",
			},
			{
				name = "Image",
				help = "Item Image URL - Imgur",
			},
			{
				name = "Amount",
				help = "Amount to Give",
			},
			{
				name = "Text",
				help = "Tooltip Text",
			},
			{
				name = "Action ID",
				help = "Unique Item ID If We Want to Assign an Action Later",
			},
		},
	}, 5)

	plsr.Chat:RegisterAdminCommand("vanityitem", function(source, args, rawCommand)
		local label, image, amount, text, action = args[1], args[2], tonumber(args[3]), args[4], args[5]
		local char = plsr.Fetch:CharacterSource(source)

		if char and label and image and amount and amount > 0 then
			INVENTORY:AddItem(char:GetData("SID"), "vanityitem", amount, {
				CustomItemLabel = label,
				CustomItemImage = image,
				CustomItemText = text or "",
				CustomItemAction = action,
			}, 1)
		else
			plsr.Execute:Client(source, "Notification", "Error", "Wrong")
		end
	end, {
		help = "Create a Vanity Item",
		params = {
			{
				name = "Label",
				help = "Item Label",
			},
			{
				name = "Image",
				help = "Item Image URL - Imgur",
			},
			{
				name = "Amount",
				help = "Amount to Give",
			},
			{
				name = "Text",
				help = "Tooltip Text",
			},
			{
				name = "Action ID",
				help = "Unique Item ID If We Want to Assign an Action Later",
			},
		},
	}, -1)

	plsr.Chat:RegisterAdminCommand("addpshop", function(source, args, rawCommand)
		local coords = GetEntityCoords(GetPlayerPed(source))
		local h = GetEntityHeading(GetPlayerPed(source))

		INVENTORY.PlayerShops.Basic:Create(args[4], {
			x = coords.x,
			y = coords.y,
			z = coords.z - 0.99,
			h = h,
		}, args[2], tonumber(args[1]), tonumber(args[3]), args[5] ~= "0" and args[5] or nil)
		plsr.Execute:Client(source, "Notification", "Success", "Shop Created")
	end, {
		help = "Add New Player Shop",
		params = {
			{
				name = "Owner State ID",
				help = "State ID of shop owner",
			},
			{
				name = "Ped Model",
				help = "Model name of ped to use, 0 to use default",
			},
			{
				name = "Owner Bank Account",
				help = "Bank Account Number To Deposite Money From Sales Into",
			},
			{
				name = "Name",
				help = "Name of shop",
			},
			{
				name = "Job",
				help = "Job ID to link to, 0 to disable",
			},
		},
	}, 5)

	plsr.Chat:RegisterAdminCommand("delpshop", function(source, args, rawCommand)
		INVENTORY.PlayerShops.Basic:Delete(tonumber(args[1]))
		plsr.Execute:Client(source, "Notification", "Success", "Shop Deleted")
	end, {
		help = "Delete Player Shop",
		params = {
			{
				name = "Shop ID",
				help = "ID of the Player Shop to delete",
			},
		},
	}, 1)

	plsr.Chat:RegisterAdminCommand("reloaddbitems", function(source, args, rawCommand)
		LoadItemsFromDb()
		plsr.Execute:Client(source, "Notification", "Success", "Items Reloaded & Sent To Clients")
	end, {
		help = "Force reload item defintions from database",
	}, 0)

	plsr.Chat:RegisterCommand("reloaditems", function(source, args, rawCommand)
		TriggerClientEvent("Inventory:Client:ReloadItems", source)
	end, {
		help = "Attempts To Force Reload Inventory Items",
	}, 0)
end
