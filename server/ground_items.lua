-- Itens físicos no chão, atirar e dar em mão (inspirado no WHIP, escrito de raiz para o Pulsar).
--
-- O armazenamento continua a ser o das dropzones (invType 10): uma linha na BD por dropzone, com os slots em JSON.
-- O que muda é que cada entrada de uma dropzone guarda a sua própria posição (`groundPos`), e os clientes desenham
-- um prop por entrada em vez de um saco por dropzone. Quem decide as posições é o servidor, em SaveInventory
-- (OnGroundInventorySaved), por isso qualquer caminho que mexa numa dropzone (arrastar, DropToGround, AddItem que
-- transborda, apanhar, atirar) fica coerente sem tocar em cada um deles.
--
-- Acesso: o validateInventoryAccess do Pulsar só deixa mexer numa dropzone a menos de 3 m do centro e nunca no
-- inventário de outro jogador. Dar e atirar precisam de passar por cima disso depois de o servidor ter feito as suas
-- próprias verificações, por isso há um acesso de uso único (GrantTrustedAccess), gasto na primeira chamada de
-- validateInventoryAccess que bater certo. O DoMove valida antes de qualquer yield, logo nenhum outro pedido
-- consegue usar esse acesso pelo meio.

local GOLDEN_ANGLE = 2.39996323

local _pendingPos = {} -- [dropzoneId] = posição para a próxima entrada nova sem posição (largar à frente, atirar)
local _centers = {}    -- [dropzoneId] = { x, y, z } onde a dropzone foi criada
local _itemsCache = {} -- [dropzoneId] = lista enviada aos clientes da última vez
local _trusted = {}    -- [source] = "owner:invType", acesso de uso único
local _lastAction = {} -- [source] = { [acção] = GetGameTimer() }
_holding = {}          -- [source] = nome do item que tem na mão (modo dar)

local function cfg()
	return Config.GroundItems or {}
end

local function giveCfg()
	return Config.GiveMode or {}
end

local function text(key, ...)
	local t = (Config.GiveMode and Config.GiveMode.Text) or {}
	local s = t[key] or key
	if select("#", ...) > 0 then
		return s:format(...)
	end
	return s
end

local function notify(source, kind, msg)
	plsr.Execute:Client(source, "Notification", kind, msg)
end

local function rateLimited(source, action, ms)
	local now = GetGameTimer()
	_lastAction[source] = _lastAction[source] or {}
	local last = _lastAction[source][action]
	if last and now - last < ms then
		return true
	end
	_lastAction[source][action] = now
	return false
end

local function routeFromId(id)
	local route = tostring(id):match("^%-?%d+:%-?%d+:(%d+)$")
	return tonumber(route)
end

local function pedCoords(source)
	local ped = GetPlayerPed(source)
	if not ped or ped == 0 then
		return nil
	end
	return GetEntityCoords(ped)
end

local function isNumber(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- ============================================
-- Acesso de uso único (ver topo do ficheiro)
-- ============================================

function GrantTrustedAccess(source, owner, invType)
	_trusted[source] = ("%s:%s"):format(owner, tonumber(invType))
end

function ConsumeTrustedAccess(source, owner, invType)
	local key = _trusted[source]
	if key ~= nil and key == ("%s:%s"):format(owner, tonumber(invType)) then
		_trusted[source] = nil
		return true
	end
	return false
end

local function clearTrusted(source)
	_trusted[source] = nil
end

-- Chama o DoMove do Pulsar e espera pelo resultado (o DoMove responde por callback).
local function doMoveAwait(source, data)
	local p = promise.new()
	DoMove(source, data, function(result)
		p:resolve(result or {})
	end)
	local result = Citizen.Await(p)
	clearTrusted(source)
	return result
end

-- ============================================
-- Posições das entradas de uma dropzone
-- ============================================

function SetGroundCenter(id, coords)
	_centers[tostring(id)] = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }
end

local function centerOf(id)
	id = tostring(id)
	if _centers[id] then
		return _centers[id]
	end
	for _, dz in ipairs(_dropzones) do
		if dz.id == id then
			return dz.coords
		end
	end
	return nil
end

local function scatterPos(center, slot)
	local maxR = cfg().ScatterRadius or 1.2
	local r = math.min(0.35 + 0.17 * math.sqrt(slot), maxR)
	local a = slot * GOLDEN_ANGLE
	return {
		x = center.x + math.cos(a) * r,
		y = center.y + math.sin(a) * r,
		z = center.z,
		h = (slot * 47) % 360,
		exact = false,
	}
end

local function validPos(p)
	return type(p) == "table" and isNumber(p.x) and isNumber(p.y) and isNumber(p.z)
end

local function toClientItems(slots)
	local out = {}
	for i = 1, #slots do
		local e = slots[i]
		if e.groundPos then
			out[#out + 1] = {
				slot = e.slot,
				name = e.name,
				count = e.count,
				pos = e.groundPos,
			}
		end
	end
	return out
end

local function broadcast(id, slots)
	id = tostring(id)
	local items = toClientItems(slots)
	_itemsCache[id] = items
	for _, dz in ipairs(_dropzones) do
		if dz.id == id then
			dz.items = items
		end
	end
	TriggerClientEvent("Inventory:Client:DropzoneItems", -1, id, items)
end

function GetGroundItemsCached(id)
	return _itemsCache[tostring(id)] or {}
end

-- Chamado por SaveInventory para todas as escritas. Não pode fazer yield (corre dentro dos locks do inventário).
function OnInventorySaved(owner, invType, slots)
	if tonumber(invType) ~= 10 then
		-- uma entrada que veio do chão por troca (SwapSlotEntries) traz a posição consigo; fora do chão não serve
		for i = 1, #slots do
			slots[i].groundPos = nil
		end
		return
	end

	if cfg().Enabled == false then
		return
	end

	local id = tostring(owner)
	local center = centerOf(id)
	local pending = _pendingPos[id]
	_pendingPos[id] = nil
	-- uma posição pendente velha é de um largar/atirar que falhou: não serve para o próximo item
	if pending and (GetGameTimer() - (pending.at or 0)) > 5000 then
		pending = nil
	end
	if pending then
		pending = { x = pending.x, y = pending.y, z = pending.z, h = pending.h, rx = pending.rx, ry = pending.ry, exact = pending.exact }
	end
	local maxDrift = cfg().MaxDrift or 4.0

	for i = 1, #slots do
		local e = slots[i]
		local p = e.groundPos
		local stale = not validPos(p)
		if not stale and center then
			local dx, dy = p.x - center.x, p.y - center.y
			stale = (dx * dx + dy * dy) > (maxDrift * maxDrift)
		end
		if stale then
			if pending then
				e.groundPos = pending
				pending = nil
			elseif center then
				e.groundPos = scatterPos(center, e.slot)
			else
				e.groundPos = nil -- sem centro ainda: CreateDropzone volta a pedir (RefreshGroundItems)
			end
		end
	end

	local route = routeFromId(id)
	if route == nil then
		return
	end

	local exists = INVENTORY:DropExists(route, id)
	if #slots == 0 then
		broadcast(id, slots)
		if exists then
			INVENTORY:RemoveDropzone(route, id)
		end
		return
	end

	if not exists and center then
		INVENTORY:CreateDropzone(route, center)
	end

	broadcast(id, slots)
end

-- Depois de criar uma dropzone: dá posição a entradas que ainda não a tenham e envia o conteúdo aos clientes.
function RefreshGroundItems(id)
	id = tostring(id)
	local slots = LoadInventoryRaw(id, 10)
	if #slots == 0 then
		broadcast(id, slots)
		return
	end

	local missing = false
	for i = 1, #slots do
		if not validPos(slots[i].groundPos) then
			missing = true
			break
		end
	end

	if missing then
		-- guardar sem alterar nada passa por OnInventorySaved, que atribui as posições e envia
		MutateInventory(id, 10, function()
			return true
		end)
	else
		broadcast(id, slots)
	end
end

-- O próximo item novo nesta dropzone fica nesta posição (exact = true: tal como está, sem encostar ao chão).
function SetPendingGroundPos(id, pos)
	pos.at = GetGameTimer()
	_pendingPos[tostring(id)] = pos
end

-- ============================================
-- Callbacks
-- ============================================

local function findEntry(owner, invType, slot)
	return FindSlotEntry(LoadInventoryRaw(owner, invType), tonumber(slot))
end

-- Um slot livre no inventário do jogador, ou uma pilha do mesmo item com espaço.
local function destSlotFor(sid, name, count, src)
	local matching = INVENTORY:GetMatchingSlot(sid, name, count, 1)
	if matching then
		return matching
	end
	local free = INVENTORY:GetFreeSlotNumbers(sid, 1, false, false, src)
	return free[1]
end

local function pickupGround(source, data, cb)
	if cfg().Enabled == false or type(data) ~= "table" then
		return cb({ reason = text("PickupFailed") })
	end
	if rateLimited(source, "pickup", 400) then
		return cb({ reason = text("TooFast") })
	end

	local char = plsr.Fetch:CharacterSource(source)
	if not char then
		return cb({ reason = text("PickupFailed") })
	end
	local sid = char:GetData("SID")

	local owner = tostring(data.owner or "")
	local slot = tonumber(data.slot)
	local route = routeFromId(owner)
	if not slot or route == nil or route ~= plsr.State:Player(source).currentRoute then
		return cb({ reason = text("PickupFailed") })
	end

	local entry = findEntry(owner, 10, slot)
	if not entry then
		return cb({ reason = text("AlreadyTaken") })
	end
	if not itemsDatabase[entry.name] then
		return cb({ reason = text("PickupFailed") })
	end

	local at = pedCoords(source)
	local where = entry.groundPos or centerOf(owner)
	if not at or not where or #(vector3(at.x, at.y, at.z) - vector3(where.x, where.y, where.z)) > (cfg().PickupRange or 2.5) + 1.0 then
		return cb({ reason = text("TooFar") })
	end

	local slotTo = destSlotFor(sid, entry.name, entry.count, source)
	if not slotTo then
		return cb({ reason = text("NoRoom") })
	end

	GrantTrustedAccess(source, owner, 10)
	local result = doMoveAwait(source, {
		ownerFrom = owner,
		invTypeFrom = 10,
		slotFrom = slot,
		ownerTo = sid,
		invTypeTo = 1,
		slotTo = slotTo,
		name = entry.name,
		countFrom = entry.count,
		countTo = entry.count,
		isSplit = false,
		inventory = {},
	})

	if result.success then
		refreshShit(sid)
		notify(source, "Success", text("YouPickedUp", entry.count, itemsDatabase[entry.name].label or entry.name))
		return cb({ success = true })
	end
	cb({ reason = result.reason or text("PickupFailed") })
end

local function giveItem(source, data, cb)
	if type(data) ~= "table" then
		return cb({ reason = text("GiveFailed") })
	end
	if rateLimited(source, "give", 1000) then
		return cb({ reason = text("TooFast") })
	end

	local target = tonumber(data.target)
	local slot = tonumber(data.slot)
	if not target or not slot or target == source then
		return cb({ reason = text("GiveFailed") })
	end

	local char = plsr.Fetch:CharacterSource(source)
	local tChar = plsr.Fetch:CharacterSource(target)
	if not char or not tChar then
		return cb({ reason = text("NoTarget") })
	end

	if plsr.State:Player(source).currentRoute ~= plsr.State:Player(target).currentRoute then
		return cb({ reason = text("NoTarget") })
	end

	local a, b = pedCoords(source), pedCoords(target)
	if not a or not b or #(a - b) > (giveCfg().MaxDistance or 3.0) + 1.0 then
		return cb({ reason = text("TooFar") })
	end

	local sid = char:GetData("SID")
	local tSid = tChar:GetData("SID")
	local entry = findEntry(sid, 1, slot)
	if not entry then
		return cb({ reason = text("ItemGone") })
	end

	local count = math.floor(tonumber(data.count) or entry.count)
	if count < 1 or count > entry.count then
		count = entry.count
	end

	local itemData = itemsDatabase[entry.name]
	if not itemData then
		return cb({ reason = text("GiveFailed") })
	end
	if giveCfg().Blacklist and giveCfg().Blacklist[entry.name] then
		return cb({ reason = text("CantGive") })
	end

	local slotTo = destSlotFor(tSid, entry.name, count, target)
	if not slotTo then
		notify(target, "Error", text("TheyHadNoRoomYou"))
		return cb({ reason = text("TheyHaveNoRoom") })
	end

	GrantTrustedAccess(source, tSid, 1)
	local result = doMoveAwait(source, {
		ownerFrom = sid,
		invTypeFrom = 1,
		slotFrom = slot,
		ownerTo = tSid,
		invTypeTo = 1,
		slotTo = slotTo,
		name = entry.name,
		countFrom = entry.count,
		countTo = count,
		isSplit = count < entry.count,
		inventory = {},
	})

	if not result.success then
		local reason = result.reason
		if reason == "Too Heavy" then
			reason = text("TheyAreTooHeavy")
		end
		return cb({ reason = reason or text("GiveFailed") })
	end

	sendRefreshForClient(target, tSid, 1, slotTo)
	refreshShit(sid)
	refreshShit(tSid)

	TriggerClientEvent("Inventory:Client:GiveAnim", source, target, true)
	TriggerClientEvent("Inventory:Client:GiveAnim", target, source, false)

	local label = itemData.label or entry.name
	notify(source, "Success", text("YouGave", count, label))
	notify(target, "Success", text("YouReceived", count, label))

	cb({ success = true })
end

-- Atirar (kind = "throw") e colocar (kind = "place") acabam iguais: o item sai dos bolsos para uma dropzone no sítio
-- onde caiu / onde foi posto, com a posição exata. Muda o alcance permitido, a lista negra e os textos.
local DROP_KINDS = {
	throw = {
		limit = 1000,
		maxDist = function()
			return giveCfg().ThrowMaxDistance or 35.0
		end,
		blacklist = function()
			return giveCfg().ThrowBlacklist
		end,
		failed = "ThrowFailed",
		blocked = "CantThrow",
		done = "YouThrew",
	},
	place = {
		limit = 600,
		maxDist = function()
			return ((Config.PlaceMode or {}).MaxDistance or 3.5) + 1.5
		end,
		blacklist = function()
			return (Config.PlaceMode or {}).Blacklist
		end,
		failed = "PlaceFailed",
		blocked = "CantPlace",
		done = "YouPlaced",
	},
}

local function dropAt(kind, source, data, cb)
	local k = DROP_KINDS[kind]
	if cfg().Enabled == false or type(data) ~= "table" then
		return cb({ reason = text(k.failed) })
	end
	if rateLimited(source, kind, k.limit) then
		return cb({ reason = text("TooFast") })
	end

	local slot = tonumber(data.slot)
	local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
	if not slot or not isNumber(x) or not isNumber(y) or not isNumber(z) then
		return cb({ reason = text(k.failed) })
	end

	local char = plsr.Fetch:CharacterSource(source)
	if not char then
		return cb({ reason = text(k.failed) })
	end
	local sid = char:GetData("SID")

	local at = pedCoords(source)
	local landing = vector3(x, y, z)
	if not at or #(at - landing) > k.maxDist() then
		return cb({ reason = text("TooFar") })
	end

	local entry = findEntry(sid, 1, slot)
	if not entry then
		return cb({ reason = text("ItemGone") })
	end
	local blacklist = k.blacklist()
	if blacklist and blacklist[entry.name] then
		return cb({ reason = text(k.blocked) })
	end

	local count = math.floor(tonumber(data.count) or entry.count)
	if count < 1 or count > entry.count then
		count = entry.count
	end

	local route = plsr.State:Player(source).currentRoute
	local dz = INVENTORY:CheckDropZones(route, landing)
	local id = dz and dz.id or INVENTORY:CreateDropzone(route, landing)

	local slotTo = INVENTORY:GetFreeSlotNumbers(id, 10, false, false, source)[1]
	if not slotTo then
		return cb({ reason = text("GroundFull") })
	end

	SetPendingGroundPos(id, {
		x = x,
		y = y,
		z = z,
		h = (tonumber(data.h) or 0.0) % 360,
		rx = tonumber(data.rx) or 0.0,
		ry = tonumber(data.ry) or 0.0,
		exact = data.settled ~= false,
	})

	GrantTrustedAccess(source, id, 10)
	local result = doMoveAwait(source, {
		ownerFrom = sid,
		invTypeFrom = 1,
		slotFrom = slot,
		ownerTo = id,
		invTypeTo = 10,
		slotTo = slotTo,
		name = entry.name,
		countFrom = entry.count,
		countTo = count,
		isSplit = count < entry.count,
		inventory = {},
	})

	if not result.success then
		_pendingPos[tostring(id)] = nil
		if not INVENTORY:HasItems(id, 10) then
			INVENTORY:RemoveDropzone(route, id)
		end
		return cb({ reason = result.reason or text(k.failed) })
	end

	refreshShit(sid)
	local itemData = itemsDatabase[entry.name]
	notify(source, "Success", text(k.done, count, (itemData and itemData.label) or entry.name))
	cb({ success = true })
end

local function throwItem(source, data, cb)
	dropAt("throw", source, data, cb)
end

local function placeItem(source, data, cb)
	dropAt("place", source, data, cb)
end

-- Quem está perto vê o objeto a voar (cada cliente simula a sua cópia local).
RegisterNetEvent("Inventory:Server:ThrowStart", function(slot, from, vel)
	local src = source
	if rateLimited(src, "throwStart", 800) then
		return
	end
	if type(from) ~= "table" or type(vel) ~= "table" then
		return
	end
	local fx, fy, fz = tonumber(from.x), tonumber(from.y), tonumber(from.z)
	local vx, vy, vz = tonumber(vel.x), tonumber(vel.y), tonumber(vel.z)
	if not (isNumber(fx) and isNumber(fy) and isNumber(fz) and isNumber(vx) and isNumber(vy) and isNumber(vz)) then
		return
	end

	local char = plsr.Fetch:CharacterSource(src)
	local at = pedCoords(src)
	if not char or not at or #(at - vector3(fx, fy, fz)) > 5.0 then
		return
	end

	local entry = findEntry(char:GetData("SID"), 1, slot)
	if not entry then
		return
	end

	local speed = math.min(math.sqrt(vx * vx + vy * vy + vz * vz), 40.0)
	local len = math.max(math.sqrt(vx * vx + vy * vy + vz * vz), 0.001)
	local v = { x = vx / len * speed, y = vy / len * speed, z = vz / len * speed }

	local route = plsr.State:Player(src).currentRoute
	local range = giveCfg().VisualRange or 80.0
	for _, pid in ipairs(GetPlayers()) do
		local p = tonumber(pid)
		if p ~= src and plsr.State:Player(p).currentRoute == route then
			local c = pedCoords(p)
			if c and #(c - at) <= range then
				TriggerClientEvent("Inventory:Client:ThrowVisual", p, src, entry.name, { x = fx, y = fy, z = fz }, v)
			end
		end
	end
end)

-- Modo dar: o item na mão, para os outros verem (cada cliente prende uma cópia local ao ped).
RegisterNetEvent("Inventory:Server:GiveHold", function(slot)
	local src = source
	if rateLimited(src, "hold", 250) then
		return
	end

	local name = false
	if slot then
		local char = plsr.Fetch:CharacterSource(src)
		local entry = char and findEntry(char:GetData("SID"), 1, slot)
		if entry then
			name = entry.name
		end
	end

	_holding[src] = name or nil
	TriggerClientEvent("Inventory:Client:PlayerHolding", -1, src, name)
end)

AddEventHandler("playerDropped", function()
	local src = source
	if _holding[src] then
		_holding[src] = nil
		TriggerClientEvent("Inventory:Client:PlayerHolding", -1, src, false)
	end
	_trusted[src] = nil
	_lastAction[src] = nil
end)

function RegisterGroundCallbacks()
	plsr.Callbacks:RegisterServerCallback("Inventory:Server:PickupGround", pickupGround)
	plsr.Callbacks:RegisterServerCallback("Inventory:Server:GiveItem", giveItem)
	plsr.Callbacks:RegisterServerCallback("Inventory:Server:ThrowItem", throwItem)
	plsr.Callbacks:RegisterServerCallback("Inventory:Server:PlaceItem", placeItem)
end
