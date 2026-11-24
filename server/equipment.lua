-- Character equipment (Config.Equipment): a per-character inventory (owner = SID, invType = Config.Equipment.invType).
-- The backpack slot holds a container item; while it's equipped its storage ("container:<id>") is reachable
-- straight from the player pane, without opening it as a secondary inventory.

local function equipInvType()
	return Config.Equipment.invType
end

local function charSid(source)
	local char = plsr.Fetch:CharacterSource(source)
	return char and char:GetData("SID") or nil
end

local function findSlot(inv, slot)
	for _, v in ipairs(inv or {}) do
		if v.Slot == slot then
			return v
		end
	end
	return nil
end

function IsOwnEquipment(source, owner, invType)
	if tonumber(invType) ~= equipInvType() then return false end
	local sid = charSid(source)
	return sid ~= nil and tostring(owner) == tostring(sid)
end

-- the backpack item currently in the backpack slot, plus its storage owner/invType
function GetEquippedBackpack(source)
	local sid = charSid(source)
	if not sid then return nil end

	local entry = findSlot(getInventory(source, sid, equipInvType()), Config.Equipment.backpackSlot)
	if not entry then return nil end

	local itemData = itemsDatabase[entry.Name]
	local containerId = entry.MetaData and entry.MetaData.Container
	if not itemData or not itemData.container or not containerId then return nil end

	return {
		item = entry,
		itemData = itemData,
		owner = ("container:%s"):format(containerId),
		invType = tonumber(itemData.container),
	}
end

function IsEquippedBackpackStorage(source, owner, invType)
	if not tostring(owner):match("^container:") then return false end
	local bp = GetEquippedBackpack(source)
	return bp ~= nil and bp.owner == tostring(owner) and bp.invType == tonumber(invType)
end

local function slotAccepts(slot, itemName)
	local rule = Config.Equipment.slots[tonumber(slot)]
	return rule ~= nil and rule.accepts(itemsDatabase[itemName]) == true
end

-- pushes the equipment pane and the equipped backpack's storage (or nil) to the client UI
function SendEquipment(source)
	local sid = charSid(source)
	if not sid then return end

	local t = equipInvType()
	local equipment = {
		size = getSlotCount(t, false, false, nil, sid, source),
		name = LoadedEntitys[t].name or "Equipment",
		inventory = getInventory(source, sid, t),
		invType = t,
		owner = sid,
		capacity = getCapacity(t),
		loaded = true,
	}

	local backpack = nil
	local bp = GetEquippedBackpack(source)
	if bp then
		backpack = {
			size = getSlotCount(bp.invType, false, false, nil, bp.owner, source),
			name = (bp.item.MetaData and bp.item.MetaData.CustomItemLabel) or bp.itemData.label or "Backpack",
			inventory = getInventory(source, bp.owner, bp.invType),
			invType = bp.invType,
			owner = bp.owner,
			capacity = getCapacity(bp.invType),
			loaded = true,
		}
	end

	TriggerClientEvent("Inventory:Client:Equipment", source, equipment, backpack)
end

-- wraps DoMove/DoSwap/DoMerge: rejects items an equipment slot doesn't accept, and re-sends the equipment
-- state after anything that touched it (so the backpack pane opens/closes with the backpack slot)
function EquipmentGuard(handler, kind)
	return function(source, data, cb)
		local t = equipInvType()
		local toEquip = tonumber(data.invTypeTo) == t
		local fromEquip = tonumber(data.invTypeFrom) == t
		local touchesBackpack = IsEquippedBackpackStorage(source, data.ownerTo, data.invTypeTo) or IsEquippedBackpackStorage(source, data.ownerFrom, data.invTypeFrom)

		if not toEquip and not fromEquip and not touchesBackpack then
			return handler(source, data, cb)
		end

		local function reject(reason)
			cb({ reason = reason })
			sendRefreshForClient(source, data.ownerFrom, data.invTypeFrom, data.slotFrom)
			sendRefreshForClient(source, data.ownerTo, data.invTypeTo, data.slotTo)
			SendEquipment(source)
		end

		if toEquip and not slotAccepts(data.slotTo, data.name) then
			return reject("That Doesn't Go In This Slot")
		end

		-- a swap sends the destination's occupant back into the origin slot, which must accept it too
		if kind == "swap" and fromEquip then
			local occupant = findSlot(getInventory(source, data.ownerTo, tonumber(data.invTypeTo)), tonumber(data.slotTo))
			if occupant and not slotAccepts(data.slotFrom, occupant.Name) then
				return reject("That Doesn't Go In This Slot")
			end
		end

		-- unequipping into the backpack's own storage would lock the backpack inside itself
		if fromEquip and tonumber(data.slotFrom) == Config.Equipment.backpackSlot and IsEquippedBackpackStorage(source, data.ownerTo, data.invTypeTo) then
			return reject("Can't Put A Container Inside Itself")
		end

		handler(source, data, function(result)
			cb(result)
			if toEquip or fromEquip then
				SendEquipment(source)
			end
		end)
	end
end
