-- Health & Injuries tab: "Heal Injury" uses a medical item through the normal item-use flow, so pulsar_damage's own
-- registered effect (plus animation and removal) does the healing - nothing is healed here.

local function loadDamageItems()
	local raw = LoadResourceFile(Config.HealthTab.resource, "config/shared.lua")
	if not raw then return {} end
	local chunk = load(raw)
	local ok, cfg = pcall(chunk or function() end)
	return (ok and type(cfg) == "table" and cfg.Injuries and cfg.Injuries.items) or {}
end

local function isBleeding(injuries)
	for _, inj in pairs(injuries or {}) do
		if type(inj) == "table" and (tonumber(inj.bleeding) or 0) > 0 then
			return true
		end
	end
	return false
end

-- first configured item the player carries that pulsar_damage treats and that can be used right now
local function pickHealSlot(source, sid, injuries)
	local effects = loadDamageItems()
	local bleeding = isBleeding(injuries)
	local inv = getInventory(source, sid, 1)

	for _, name in ipairs(Config.HealthTab.healItems) do
		local effect = effects[name]
		if effect and (bleeding or not effect.requireBleeding) then
			for _, entry in ipairs(inv) do
				if entry.Name == name and (entry.Count or 0) > 0 then
					return entry.Slot
				end
			end
		end
	end
	return nil
end

function RegisterHealthCallbacks()
	plsr.Callbacks:RegisterServerCallback("Inventory:Health:Heal", function(source, data, cb)
		if GetResourceState(Config.HealthTab.resource) ~= "started" or type(data) ~= "table" then
			return cb(false)
		end

		local char = plsr.Fetch:CharacterSource(source)
		if not char then
			return cb(false)
		end

		local sid = char:GetData("SID")
		local injuries = plsr.Damage.Injuries:Get(sid) or {}
		if data.id == nil or injuries[data.id] == nil then
			return cb(false)
		end

		local slotNumber = pickHealSlot(source, sid, injuries)
		if not slotNumber then
			plsr.Execute:Client(source, "Notification", "Error", "You don't have anything to treat this with.")
			return cb(false)
		end

		local slot = INVENTORY:GetOldestInSlot(sid, slotNumber, 1)
		if not slot then
			return cb(false)
		end

		_lastUsedItem[source] = slot.id
		INVENTORY.Items:Use(source, slot, cb)
	end)
end
