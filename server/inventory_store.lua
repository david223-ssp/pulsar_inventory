-- one inventory row per owner+type, holding a JSON array of slots instead of a row per unit

-- write-through cache: every write below is still synchronous to the DB on every call, nothing is ever deferred/debounced, 
-- so a crash right after any completed operation has that operation safely persisted - this only saves the LOAD round-trip 
-- on repeat access, it never changes what "durably saved" means... sooo LoadInventoryRaw always hands out a deep copy so a caller 
-- mutating its result can never desync the cache from what was actually written; only SaveInventory (called by MutateInventory) updates the cache
local _inventoryCache = {}
local _inventoryCacheTouched = {}

local function cacheKey(owner, invType)
	return ("%s:%s"):format(owner, invType)
end

-- set around AdjustCashItem's own Add/Remove call so its write doesn't loop back into itself below
_cashSyncGuard = {}

local function sumItemCount(slots, itemName)
	local total = 0
	for i = 1, #slots do
		if slots[i].name == itemName then
			total += slots[i].count
		end
	end
	return total
end

-- keeps Cash in sync with Config.CashAsItem's stack count on any inventory change (personal inventories only)
local function syncCashItem(owner, invType, oldSlots, newSlots)
	if invType ~= 1 or not Config.CashAsItem or _cashSyncGuard[tostring(owner)] then
		return
	end

	local delta = sumItemCount(newSlots, Config.CashAsItem) - sumItemCount(oldSlots or {}, Config.CashAsItem)
	if delta == 0 then
		return
	end

	local char = plsr.Fetch:SID(tonumber(owner) or owner)
	if char then
		char:SetData("Cash", math.max(0, math.floor((char:GetData("Cash") or 0) + delta)))
	end
end

---@param owner string|number
---@param invType number
---@return table[] slots decoded slot entries (deep copy), empty table if the instance does not exist yet
function LoadInventoryRaw(owner, invType)
	if owner == nil or invType == nil then
		plsr.Logger:Error("Inventory", "LoadInventoryRaw called with a nil owner or invType\n" .. debug.traceback(), { console = true })
		return {}
	end

	local key = cacheKey(owner, invType)
	local cached = _inventoryCache[key]
	if cached then
		_inventoryCacheTouched[key] = os.time()
		return deepcopy(cached)
	end

	local rows = MySQL.query.await("SELECT slots FROM inventory WHERE owner = ? AND type = ?", {
		tostring(owner),
		invType,
	})

	local row = rows[1]
	local slots = {}
	if row then
		local ok, decoded = pcall(json.decode, row.slots)
		if ok and type(decoded) == "table" then
			slots = decoded
		end
	end

	_inventoryCache[key] = slots
	_inventoryCacheTouched[key] = os.time()
	return deepcopy(slots)
end

---@param owner string|number
---@param invType number
---@param slots table[]
function SaveInventory(owner, invType, slots)
	if owner == nil or invType == nil then
		plsr.Logger:Error("Inventory", "SaveInventory called with a nil owner or invType, refusing to write\n" .. debug.traceback(), { console = true })
		return
	end

	local key = cacheKey(owner, invType)
	syncCashItem(owner, invType, _inventoryCache[key], slots)
	_inventoryCache[key] = slots
	_inventoryCacheTouched[key] = os.time()

	if #slots == 0 then
		MySQL.query.await("DELETE FROM inventory WHERE owner = ? AND type = ?", {
			tostring(owner),
			invType,
		})
		return
	end

	MySQL.query.await(
		"INSERT INTO inventory (owner, type, slots, updatedAt) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE slots = VALUES(slots), updatedAt = VALUES(updatedAt)",
		{
			tostring(owner),
			invType,
			json.encode(slots),
			os.time(),
		}
	)
end

-- evicts entries untouched for a while so a long-lived server doesn accumulate every inventory ever
-- read forever...always safe to evict since writes above are synchronous, cache is never newer than the DB
local CACHE_TTL_SECONDS = 20 * 60
CreateThread(function()
	while true do
		Wait(5 * 60 * 1000)
		local now = os.time()
		for key, touchedAt in pairs(_inventoryCacheTouched) do
			if now - touchedAt > CACHE_TTL_SECONDS then
				_inventoryCache[key] = nil
				_inventoryCacheTouched[key] = nil
			end
		end
	end
end)

-- locks the instance, loads it, lets fn poke at it, saves unless fn returns false
---@param owner string|number
---@param invType number
---@param fn fun(slots: table[]): boolean|nil
---@return boolean saved
function MutateInventory(owner, invType, fn)
	local lock <close> = AcquireLocks({ ("%s:%s"):format(owner, invType) })
	if not lock then
		return false, "locked"
	end

	local slots = LoadInventoryRaw(owner, invType)
	local ok = fn(slots)

	if ok ~= false then
		SaveInventory(owner, invType, slots)
	end

	return ok ~= false
end

---@param slots table[]
---@param slotNumber number
---@return table|nil entry, number|nil index
function FindSlotEntry(slots, slotNumber)
	for i = 1, #slots do
		if slots[i].slot == slotNumber then
			return slots[i], i
		end
	end
	return nil
end

---@param slots table[]
---@param name string
---@return table|nil entry, number|nil index
function FindSlotEntryByName(slots, name)
	for i = 1, #slots do
		if slots[i].name == name then
			return slots[i], i
		end
	end
	return nil
end

-- loads both instances, lets fn poke at both, saves unless fn returns false, no locking of its own
---@param ownerFrom string|number
---@param invTypeFrom number
---@param ownerTo string|number
---@param invTypeTo number
---@param fn fun(fromSlots: table[], toSlots: table[]): boolean|nil
---@return boolean saved
function WithBothInventories(ownerFrom, invTypeFrom, ownerTo, invTypeTo, fn)
	local sameInstance = tostring(ownerFrom) == tostring(ownerTo) and invTypeFrom == invTypeTo
	local fromSlots = LoadInventoryRaw(ownerFrom, invTypeFrom)
	local toSlots = sameInstance and fromSlots or LoadInventoryRaw(ownerTo, invTypeTo)

	local ok = fn(fromSlots, toSlots)

	if ok ~= false then
		SaveInventory(ownerFrom, invTypeFrom, fromSlots)
		if not sameInstance then
			SaveInventory(ownerTo, invTypeTo, toSlots)
		end
	end

	return ok ~= false
end

-- same as WithBothInventories but grabs both instance locks itself first
---@param ownerFrom string|number
---@param invTypeFrom number
---@param ownerTo string|number
---@param invTypeTo number
---@param fn fun(fromSlots: table[], toSlots: table[]): boolean|nil
---@return boolean saved
function MutateTwoInventories(ownerFrom, invTypeFrom, ownerTo, invTypeTo, fn)
	local sameInstance = tostring(ownerFrom) == tostring(ownerTo) and invTypeFrom == invTypeTo
	local keys = { ("%s:%s"):format(ownerFrom, invTypeFrom) }
	if not sameInstance then
		table.insert(keys, ("%s:%s"):format(ownerTo, invTypeTo))
	end

	local lock <close> = AcquireLocks(keys)
	if not lock then
		return false, "locked"
	end

	return WithBothInventories(ownerFrom, invTypeFrom, ownerTo, invTypeTo, fn)
end

-- shapes a decoded slot entry into the doc callers already expect (id, Count, Owner, ...)
---@param owner string|number
---@param invType number
---@param entry table
---@return table doc
function SlotEntryToDoc(owner, invType, entry)
	return {
		id = ("%s:%s:%s"):format(owner, invType, entry.slot),
		Count = entry.count,
		Owner = tostring(owner),
		invType = invType,
		Name = entry.name,
		Price = entry.price or 0,
		Quality = entry.quality,
		MetaData = entry.metadata or {},
		Slot = entry.slot,
		CreateDate = entry.createdAt or 0,
	}
end

-- moves moveCount units between slot entries, drops the source if drained
---@param fromSlots table[]
---@param fromSlot number
---@param toSlots table[]
---@param toSlot number
---@param moveCount number
---@param overrides table|nil
---@return boolean moved
function MoveSlotUnits(fromSlots, fromSlot, toSlots, toSlot, moveCount, overrides)
	local fromEntry = FindSlotEntry(fromSlots, fromSlot)
	if not fromEntry or fromEntry.count < moveCount then
		return false
	end

	local toEntry = FindSlotEntry(toSlots, toSlot)
	if toEntry then
		toEntry.count += moveCount
	else
		toEntry = {
			slot = toSlot,
			name = fromEntry.name,
			count = moveCount,
			quality = fromEntry.quality,
			price = fromEntry.price,
			createdAt = fromEntry.createdAt,
			expiryDate = fromEntry.expiryDate,
			metadata = fromEntry.metadata,
		}
		if overrides then
			for k, v in pairs(overrides) do
				toEntry[k] = v
			end
		end
		table.insert(toSlots, toEntry)
	end

	fromEntry.count -= moveCount
	if fromEntry.count <= 0 then
		RemoveSlotEntry(fromSlots, fromSlot)
	end

	return true
end

-- full swap of whatever's in each slot, not a partial move
---@param fromSlots table[]
---@param fromSlot number
---@param toSlots table[]
---@param toSlot number
---@return boolean swapped
function SwapSlotEntries(fromSlots, fromSlot, toSlots, toSlot)
	local fromEntry, fromIdx = FindSlotEntry(fromSlots, fromSlot)
	local toEntry, toIdx = FindSlotEntry(toSlots, toSlot)

	if fromSlots == toSlots then
		if fromEntry then fromEntry.slot = toSlot end
		if toEntry then toEntry.slot = fromSlot end
		return true
	end

	if fromIdx then table.remove(fromSlots, fromIdx) end
	if toIdx then table.remove(toSlots, toIdx) end

	if fromEntry then
		fromEntry.slot = toSlot
		table.insert(toSlots, fromEntry)
	end
	if toEntry then
		toEntry.slot = fromSlot
		table.insert(fromSlots, toEntry)
	end

	return true
end

---@param slots table[]
---@param slotNumber number
---@return boolean removed
function RemoveSlotEntry(slots, slotNumber)
	for i = 1, #slots do
		if slots[i].slot == slotNumber then
			table.remove(slots, i)
			return true
		end
	end
	return false
end
