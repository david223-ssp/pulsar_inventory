-- Health & Injuries tab bridge (NUI contracts: getHealthData, setHealthData, healInjury).
-- pulsar_damage owns the data (plsr.State.flags.injuries) and every heal; this only reads and relays it.

local function damageResource()
	return Config.HealthTab.resource
end

local function damageRunning()
	return GetResourceState(damageResource()) == "started"
end

-- Major/Critical thresholds: Major starts where pulsar_damage starts limping, Critical from our config
local _majorThreshold = nil
local function majorThreshold()
	if _majorThreshold == nil then
		_majorThreshold = 40
		local raw = LoadResourceFile(damageResource(), "config/shared.lua")
		if raw then
			local chunk = load(raw)
			local ok, cfg = pcall(chunk or function() end)
			if ok and type(cfg) == "table" and cfg.Injuries and tonumber(cfg.Injuries.limpThreshold) then
				_majorThreshold = tonumber(cfg.Injuries.limpThreshold)
			end
		end
	end
	return _majorThreshold
end

local function pct(value)
	return math.floor(math.max(0, math.min(100, value)) + 0.5)
end

function BuildHealthData()
	if not damageRunning() then
		return { available = false }
	end

	local ped = PlayerPedId()
	local maxHp = math.max(GetEntityMaxHealth(ped), 101)
	local _, stamina = StatGetInt(`MP0_STAMINA`, -1)

	return {
		available = true,
		health = pct((GetEntityHealth(ped) - 100) / (maxHp - 100) * 100),
		armor = pct(GetPedArmour(ped)),
		stamina = pct(stamina or 0),
		injuries = plsr.State.flags.injuries or {},
		thresholds = { major = majorThreshold(), critical = Config.HealthTab.criticalThreshold },
		healItems = Config.HealthTab.healItems,
	}
end

local _lastSent = nil
local function pushHealthData(force)
	local data = BuildHealthData()
	local encoded = json.encode(data)
	if force or encoded ~= _lastSent then
		_lastSent = encoded
		SendNUIMessage({ type = "setHealthData", data = data })
	end
end

RegisterNUICallback("getHealthData", function(data, cb)
	local payload = BuildHealthData()
	_lastSent = json.encode(payload)
	cb(payload)
end)

RegisterNUICallback("healInjury", function(data, cb)
	cb("OK")
	if not damageRunning() or plsr.State.flags.doingAction or type(data) ~= "table" or data.id == nil then
		return
	end
	plsr.Callbacks:ServerCallback("Inventory:Health:Heal", { id = tostring(data.id) }, function() end)
end)

-- live updates: injuries through plsr.State, health/armor/stamina are polled (both sent only on change)
plsr.State:Watch("flags", "injuries", function()
	pushHealthData(false)
end)

AddEventHandler("onClientResourceStart", function(resource)
	if resource == damageResource() then
		_majorThreshold = nil
		pushHealthData(true)
	end
end)

AddEventHandler("onClientResourceStop", function(resource)
	if resource == damageResource() then
		pushHealthData(true)
	end
end)

CreateThread(function()
	while true do
		Wait(1000)
		pushHealthData(false)
	end
end)
