dIds = 1
dropzones = {}

-- Itens físicos no chão (Config.GroundItems): cada entrada de uma dropzone é um prop seu, na posição que o servidor
-- lhe deu (server/ground_items.lua). Apanha-se com a etiqueta flutuante + [E] (Config.GroundItems.Prompt) e/ou com o
-- target "Apanhar" (Config.GroundItems.UseTarget). Uma dropzone sem itens conhecidos (ou com
-- Config.GroundItems.Enabled = false) mostra o saco antigo, Config.DropProp, que abre o painel do chão.

local _dropProps = {}    -- [dropzoneId] = { bag = entity|nil, items = { [slot] = { entity, sig } } }
local _pendingItems = {} -- [dropzoneId] = itens que chegaram antes da própria dropzone
local _dirty = true

local function groundCfg()
	return Config.GroundItems or {}
end

local function groundEnabled()
	return groundCfg().Enabled ~= false
end

function GroundLoadModel(hash, ms)
	if HasModelLoaded(hash) then
		return true
	end
	if not IsModelInCdimage(hash) then
		return false
	end
	RequestModel(hash)
	local untilAt = GetGameTimer() + (ms or 3000)
	while not HasModelLoaded(hash) and GetGameTimer() < untilAt do
		Wait(0)
	end
	return HasModelLoaded(hash)
end

local function modelOrNil(m)
	if m == nil then
		return nil
	end
	local hash = type(m) == "number" and m or joaat(m)
	if IsModelInCdimage(hash) then
		return hash
	end
	return nil
end

-- O modelo que representa um item no chão (e na mão, no modo dar).
function GroundPropModelFor(name)
	local cfg = groundCfg()
	local def = _items and _items[name] or nil

	local hash = modelOrNil(cfg.Props and cfg.Props[name]) or modelOrNil(def and def.groundProp)

	if not hash and def and (def.type == 2 or def.weapon) then
		local weaponModel = GetWeapontypeModel(GetHashKey(def.weapon or name))
		if weaponModel and weaponModel ~= 0 and IsModelInCdimage(weaponModel) then
			hash = weaponModel
		end
	end

	if not hash and def and cfg.TypeProps then
		hash = modelOrNil(cfg.TypeProps[def.type])
	end

	return hash or modelOrNil(cfg.DefaultProp) or joaat(Config.DropProp)
end

function GroundItemLabel(name, count)
	local def = _items and _items[name] or nil
	local label = (def and def.label) or name
	if (count or 1) > 1 then
		return ("%s (x%s)"):format(label, count)
	end
	return label
end

local _targeted = {} -- [entity] = true quando tem target (para só o tirar a quem o tem)

local function deleteEntity(entity)
	if not entity then
		return
	end
	if _targeted[entity] then
		_targeted[entity] = nil
		plsr.Targeting:RemoveEntity(entity)
	end
	if DoesEntityExist(entity) then
		DeleteEntity(entity)
	end
end

local function itemSig(it)
	local p = it.pos
	return ("%s|%s|%.2f|%.2f|%.2f|%s"):format(it.name, it.count, p.x, p.y, p.z, tostring(p.exact))
end

local function spawnItemProp(dz, it)
	local hash = GroundPropModelFor(it.name)
	if not GroundLoadModel(hash, 3000) then
		hash = joaat(Config.DropProp)
		if not GroundLoadModel(hash, 3000) then
			return nil
		end
	end

	local p = it.pos
	local entity = CreateObject(hash, p.x, p.y, p.z, false, false, false)
	SetModelAsNoLongerNeeded(hash)
	if not entity or entity == 0 then
		return nil
	end

	if p.exact then
		SetEntityCoordsNoOffset(entity, p.x, p.y, p.z, false, false, false)
		SetEntityRotation(entity, tonumber(p.rx) or 0.0, tonumber(p.ry) or 0.0, tonumber(p.h) or 0.0, 2, true)
	else
		SetEntityHeading(entity, tonumber(p.h) or 0.0)
		PlaceObjectOnGroundProperly(entity)
	end
	FreezeEntityPosition(entity, true)
	SetEntityAsMissionEntity(entity, true, true)

	if groundCfg().UseTarget == false then
		return entity
	end

	local txt = groundCfg().Text or {}
	_targeted[entity] = true
	plsr.Targeting:AddEntity(entity, "hand", {
		{
			icon = "hand",
			text = (txt.Pickup or "Apanhar %s"):format(GroundItemLabel(it.name, it.count)),
			event = "Inventory:Client:PickupGroundItem",
			data = { id = dz.id, slot = it.slot },
		},
		{
			icon = "box-open",
			text = txt.Open or "Abrir monte",
			event = "Inventory:Client:OpenGroundDrop",
			data = { id = dz.id, coords = dz.coords },
		},
	})

	return entity
end

local function spawnBag(dz)
	local model = joaat(Config.DropProp)
	if not GroundLoadModel(model, 3000) then
		return nil
	end

	local c = dz.coords
	local entity = CreateObject(model, c.x, c.y, c.z, false, true, true)
	PlaceObjectOnGroundProperly(entity)
	FreezeEntityPosition(entity, true)
	SetEntityAsMissionEntity(entity, true, true)
	SetModelAsNoLongerNeeded(model)

	_targeted[entity] = true
	plsr.Targeting:AddEntity(entity, "box-open", {
		{ icon = "box-open", text = "Open", event = "Inventory:Client:OpenGroundDrop", data = { id = dz.id, coords = c } },
	})

	return entity
end

function DeleteDropProp(id)
	local set = _dropProps[id]
	if not set then
		return
	end
	deleteEntity(set.bag)
	for _, v in pairs(set.items) do
		deleteEntity(v.entity)
	end
	_dropProps[id] = nil
end

-- Mantém os props de uma dropzone iguais ao que o servidor diz que lá está.
local function syncDropzone(dz)
	local set = _dropProps[dz.id]
	if not set then
		set = { bag = nil, items = {} }
		_dropProps[dz.id] = set
	end

	local items = dz.items
	local usePhysical = groundEnabled() and type(items) == "table" and #items > 0

	if not usePhysical then
		for slot, v in pairs(set.items) do
			deleteEntity(v.entity)
			set.items[slot] = nil
		end
		-- sem itens conhecidos ainda: o saco, como antes (com itens físicos ligados, só enquanto o conteúdo não chega)
		if not set.bag and (not groundEnabled() or items == nil) then
			set.bag = spawnBag(dz)
		elseif set.bag and groundEnabled() and items ~= nil then
			deleteEntity(set.bag)
			set.bag = nil
		end
		return
	end

	if set.bag then
		deleteEntity(set.bag)
		set.bag = nil
	end

	local seen = {}
	for _, it in ipairs(items) do
		if it.pos and it.slot then
			seen[it.slot] = true
			local sig = itemSig(it)
			local cur = set.items[it.slot]
			if not cur or cur.sig ~= sig or not DoesEntityExist(cur.entity) then
				if cur then
					deleteEntity(cur.entity)
				end
				local entity = spawnItemProp(dz, it)
				set.items[it.slot] = entity and { entity = entity, sig = sig, id = dz.id, slot = it.slot, name = it.name, count = it.count } or nil
			end
		end
	end

	for slot, v in pairs(set.items) do
		if not seen[slot] then
			deleteEntity(v.entity)
			set.items[slot] = nil
		end
	end
end

function runDropsUpdate()
	local position = plsr.State.flags.position
	if position == nil then
		return
	end

	local range = Config.DropPropDistance or 25.0
	local near = {}
	for _, v in ipairs(dropzones) do
		if v.route == plsr.State.flags.currentRoute then
			local distance = #(position - vector3(v.coords.x, v.coords.y, v.coords.z))
			if distance <= range then
				near[v.id] = v
			end
		end
	end

	for id in pairs(_dropProps) do
		if not near[id] then
			DeleteDropProp(id)
		end
	end

	for _, dz in pairs(near) do
		syncDropzone(dz)
	end
end

-- compatibilidade: o código antigo chamava isto para o saco de uma dropzone
function SpawnDropProp(id, coords)
	for _, dz in ipairs(dropzones) do
		if dz.id == id then
			syncDropzone(dz)
			return
		end
	end
end

AddEventHandler("Inventory:Client:OpenGroundDrop", function(ent, data)
	SecondInventory = { invType = 10, owner = data.id, position = data.coords }
	plsr.Inventory.Open:Player(true)
end)

local _pickingUp = false

-- Apanhar um item do chão (pela etiqueta + E ou pelo target).
local function pickupGroundItem(entity, id, slot)
	if _pickingUp or not id or not slot then
		return
	end
	_pickingUp = true

	if type(entity) == "number" and entity ~= 0 and DoesEntityExist(entity) then
		TaskTurnPedToFaceEntity(PlayerPedId(), entity, 400)
		Wait(250)
	end
	dropAnim(false)

	plsr.Callbacks:ServerCallback("Inventory:Server:PickupGround", { owner = id, slot = slot }, function(result)
		_pickingUp = false
		if not result or not result.success then
			plsr.Notification:Error((result and result.reason) or "Não foi possível apanhar o item")
		end
	end)
end

AddEventHandler("Inventory:Client:PickupGroundItem", function(ent, data)
	if type(data) ~= "table" then
		return
	end
	-- pulsar_targeting passes its hit data ({ entity = handle, type = ..., ... }), not the bare handle;
	-- DoesEntityExist on that table throws "invalid table argument" and left _pickingUp stuck on true
	local entity = type(ent) == "table" and ent.entity or ent
	pickupGroundItem(entity, data.id, data.slot)
end)

-- ============================================
-- Etiqueta flutuante + [E] (Config.GroundItems.Prompt)
-- ============================================

local OUTLINE = { 179, 157, 255, 255 }
local _promptRunning = false

local function promptBlocked()
	local ped = PlayerPedId()
	return _pickingUp
		or plsr.State.flags.inventoryOpen
		or plsr.State.flags.isDead
		or IsPedInAnyVehicle(ped, false)
		or IsEntityDead(ped)
		or (IsGiveModeActive ~= nil and IsGiveModeActive())
		or (IsPlaceModeActive ~= nil and IsPlaceModeActive())
end

local function camForwardFlat()
	local rot = GetGameplayCamRot(2)
	local rz = math.rad(rot.z)
	return -math.sin(rz), math.cos(rz)
end

-- O item com etiqueta: dentro do alcance, de preferência o que está à frente da câmara.
local function pickPromptItem()
	local range = groundCfg().PromptRange or 2.0
	local at = GetEntityCoords(PlayerPedId())
	local fx, fy = camForwardFlat()
	local best, bestScore = nil, nil

	for _, set in pairs(_dropProps) do
		for _, v in pairs(set.items) do
			if v.entity and DoesEntityExist(v.entity) then
				local c = GetEntityCoords(v.entity)
				local d = #(c - at)
				if d <= range then
					local dx, dy = c.x - at.x, c.y - at.y
					local flat = math.sqrt(dx * dx + dy * dy)
					local angle = 0.0
					if flat > 0.05 then
						angle = math.deg(math.acos(math.max(-1.0, math.min(1.0, (dx * fx + dy * fy) / flat))))
					end
					local score = d + angle / 45.0
					if bestScore == nil or score < bestScore then
						best, bestScore = v, score
					end
				end
			end
		end
	end

	return best
end

local function textWidth(text, scale)
	BeginTextCommandGetWidth("STRING")
	SetTextFont(4)
	SetTextScale(scale, scale)
	AddTextComponentSubstringPlayerName(text)
	return EndTextCommandGetWidth(true)
end

local function drawText(text, x, y, scale, r, g, b, a, centre)
	SetTextFont(4)
	SetTextScale(scale, scale)
	SetTextColour(r, g, b, a)
	SetTextOutline()
	SetTextCentre(centre == true)
	BeginTextCommandDisplayText("STRING")
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandDisplayText(x, y)
end

-- [E] Nome (xN), por cima do item, como no WHIP
local function drawPrompt(v)
	local c = GetEntityCoords(v.entity)
	local label = GroundItemLabel(v.name, v.count)
	local key = groundCfg().PromptKeyLabel or "E"
	local scale = 0.32
	local boxW, boxH, gap = 0.0115, 0.021, 0.004
	local labelW = textWidth(label, scale)
	local total = boxW + gap + labelW
	local x0 = -total / 2.0

	SetDrawOrigin(c.x, c.y, c.z + 0.30, 0)
	DrawRect(x0 + boxW / 2.0, 0.0, boxW, boxH, 240, 240, 245, 235)
	SetTextDropShadow()
	drawText(key, x0 + boxW / 2.0, -0.0115, scale, 20, 20, 25, 255, true)
	drawText(label, x0 + boxW + gap, -0.0115, scale, 255, 255, 255, 245, false)
	ClearDrawOrigin()
end

local function setOutline(entity, on)
	if not groundCfg().Outline or not entity or not DoesEntityExist(entity) then
		return
	end
	if on then
		SetEntityDrawOutlineColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], OUTLINE[4])
	end
	SetEntityDrawOutline(entity, on)
end

local function startPromptTick()
	if groundCfg().Prompt == false or not groundEnabled() then
		return
	end

	if _promptRunning then
		return
	end
	_promptRunning = true

	CreateThread(function()
		local key = groundCfg().PromptKey or 38
		local shown = nil

		while plsr.State.flags.loggedIn do
			local v = (next(_dropProps) ~= nil and not promptBlocked()) and pickPromptItem() or nil

			if shown and (not v or shown.entity ~= v.entity) then
				setOutline(shown.entity, false)
				shown = nil
			end

			if not v then
				Wait(next(_dropProps) ~= nil and 200 or 750)
			else
				if not shown then
					setOutline(v.entity, true)
					shown = v
				end

				-- desenha e lê a tecla em cada frame; volta a escolher o item de 200 em 200 ms
				local untilAt = GetGameTimer() + 200
				while GetGameTimer() < untilAt and DoesEntityExist(v.entity) and not promptBlocked() do
					drawPrompt(v)
					if IsControlJustPressed(0, key) then
						setOutline(v.entity, false)
						shown = nil
						pickupGroundItem(v.entity, v.id, v.slot)
						break
					end
					Wait(0)
				end
			end
		end

		if shown then
			setOutline(shown.entity, false)
		end
		_promptRunning = false
	end)
end

function startDropsTick()
	startPromptTick()
	CreateThread(function()
		local last = 0
		while plsr.State.flags.loggedIn do
			local now = GetGameTimer()
			if _dirty or now - last >= 1000 then
				_dirty = false
				last = now
				runDropsUpdate()
			end
			Wait(150)
		end
	end)
end

local function attachPending(dz)
	if _pendingItems[dz.id] then
		dz.items = _pendingItems[dz.id]
		_pendingItems[dz.id] = nil
	end
end

RegisterNetEvent("Inventory:Client:DropzoneForceUpdate", function(dzs)
	for id in pairs(_dropProps) do
		DeleteDropProp(id)
	end
	dropzones = dzs or {}
	for _, dz in ipairs(dropzones) do
		attachPending(dz)
	end
	_dirty = true
end)

RegisterNetEvent("Inventory:Client:AddDropzone", function(data)
	for k, v in ipairs(dropzones) do
		if v.id == data.id then
			table.remove(dropzones, k)
			break
		end
	end
	attachPending(data)
	table.insert(dropzones, data)
	_dirty = true
end)

RegisterNetEvent("Inventory:Client:RemoveDropzone", function(id)
	for k, v in ipairs(dropzones) do
		if v.id == id then
			table.remove(dropzones, k)
			break
		end
	end
	_pendingItems[id] = nil
	DeleteDropProp(id)
end)

RegisterNetEvent("Inventory:Client:DropzoneItems", function(id, items)
	for _, v in ipairs(dropzones) do
		if v.id == id then
			v.items = items or {}
			_dirty = true
			return
		end
	end
	_pendingItems[id] = items or {}
end)

AddEventHandler("onResourceStop", function(resource)
	if resource == GetCurrentResourceName() then
		for id in pairs(_dropProps) do
			DeleteDropProp(id)
		end
	end
end)
