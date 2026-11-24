-- Dar em mão e atirar (Config.GiveMode), como no WHIP, escrito de raiz para o Pulsar.
--
-- "Give" no menu de um item do inventário fecha o inventário e põe o item na mão direita:
--   [E]               dá-o à pessoa para onde estás virado (até Config.GiveMode.MaxDistance)
--   [Clique esquerdo] atira-o para onde a câmara aponta; cai no chão como item físico (client/drops.lua)
--   [C]               cancela
-- Quem decide tudo é o servidor (server/ground_items.lua): o cliente só mostra e pede.

local WEAPON_UNARMED = GetHashKey("WEAPON_UNARMED")
local RIGHT_HAND = 57005
local GRAVITY = 9.81

local state = nil      -- { slot, count, name, started, prop, prevDisabled }
local busy = false     -- entre o fim do modo e a resposta do servidor (dar/atirar)
local _hint = nil
local _othersHolding = {} -- [serverId] = entidade presa à mão desse jogador
local _giveProp = nil      -- o item na mão depois de um dar aceite, até a animação o entregar

local function cfg()
	return Config.GiveMode or {}
end

local function txt(key)
	return (cfg().Text or {})[key] or key
end

-- ============================================
-- Ajudas
-- ============================================

local function showHint(text)
	if _hint == text then
		return
	end
	_hint = text
	if plsr.Action and plsr.Action.Show then
		plsr.Action:Show("inventory_give", text)
	end
end

local function hideHint()
	if _hint == nil then
		return
	end
	_hint = nil
	if plsr.Action and plsr.Action.Hide then
		plsr.Action:Hide("inventory_give")
	end
end

local function loadDictTimed(dict, ms)
	if HasAnimDictLoaded(dict) then
		return true
	end
	if not DoesAnimDictExist(dict) then
		return false
	end
	RequestAnimDict(dict)
	local untilAt = GetGameTimer() + (ms or 2000)
	while not HasAnimDictLoaded(dict) and GetGameTimer() < untilAt do
		Wait(0)
	end
	return HasAnimDictLoaded(dict)
end

local function camForward()
	local rot = GetGameplayCamRot(2)
	local rx, rz = math.rad(rot.x), math.rad(rot.z)
	return vector3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
end

local function attachItemProp(ped, name)
	local hash = GroundPropModelFor(name)
	if not GroundLoadModel(hash, 2000) then
		return nil
	end

	local at = GetEntityCoords(ped)
	local obj = CreateObject(hash, at.x, at.y, at.z + 0.5, false, false, false)
	SetModelAsNoLongerNeeded(hash)
	if not obj or obj == 0 then
		return nil
	end

	local o = (cfg().ItemOffsets and cfg().ItemOffsets[name]) or cfg().HandOffset or {}
	SetEntityCollision(obj, false, false)
	AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, RIGHT_HAND),
		o.x or 0.12, o.y or 0.02, o.z or -0.02, o.rx or -90.0, o.ry or 0.0, o.rz or 0.0,
		true, true, false, true, 1, true)
	return obj
end

local function deleteObj(obj)
	if obj and DoesEntityExist(obj) then
		DetachEntity(obj, true, false)
		DeleteEntity(obj)
	end
end

local function dropHandProp()
	if state and state.prop then
		deleteObj(state.prop)
		state.prop = nil
	end
	TriggerServerEvent("Inventory:Server:GiveHold", false)
end

-- A pessoa mais à frente (para onde a câmara aponta) dentro do alcance, ou nil.
local function findTarget()
	local me = PlayerPedId()
	local myPos = GetEntityCoords(me)
	local fwd = camForward()
	local fl = math.sqrt(fwd.x * fwd.x + fwd.y * fwd.y)
	if fl < 0.001 then
		return nil
	end
	local fx, fy = fwd.x / fl, fwd.y / fl

	local maxDist = cfg().MaxDistance or 3.0
	local maxAngle = cfg().AimAngle or 30.0
	local best, bestAngle = nil, nil

	for _, pid in ipairs(GetActivePlayers()) do
		if pid ~= PlayerId() then
			local ped = GetPlayerPed(pid)
			if ped ~= 0 and DoesEntityExist(ped) and IsEntityVisible(ped) then
				local pos = GetEntityCoords(ped)
				local dx, dy = pos.x - myPos.x, pos.y - myPos.y
				local flat = math.sqrt(dx * dx + dy * dy)
				if #(pos - myPos) <= maxDist and flat > 0.05 then
					local dot = math.max(-1.0, math.min(1.0, (dx * fx + dy * fy) / flat))
					local angle = math.deg(math.acos(dot))
					if angle <= maxAngle and (bestAngle == nil or angle < bestAngle)
						and HasEntityClearLosToEntity(me, ped, 17) then
						best, bestAngle = { serverId = GetPlayerServerId(pid), ped = ped }, angle
					end
				end
			end
		end
	end

	return best
end

-- Velocidade que leva o item de `from` até `to` à velocidade `speed`, no arco mais baixo; nil se não chega lá.
local function launchVelocity(from, to, speed)
	local dx, dy, dz = to.x - from.x, to.y - from.y, to.z - from.z
	local d = math.sqrt(dx * dx + dy * dy)
	if d < 0.05 then
		return nil
	end
	local v2 = speed * speed
	local disc = v2 * v2 - GRAVITY * (GRAVITY * d * d + 2.0 * dz * v2)
	if disc < 0.0 then
		return nil
	end
	local tanA = (v2 - math.sqrt(disc)) / (GRAVITY * d)
	local cosA = 1.0 / math.sqrt(1.0 + tanA * tanA)
	local h = speed * cosA / d
	return vector3(dx * h, dy * h, speed * tanA * cosA)
end

local function endMode(keepProp)
	if not state then
		return
	end
	hideHint()
	if not keepProp then
		dropHandProp()
	end
	if not state.prevDisabled then
		plsr.Inventory:Enable()
	end
	local s = state
	state = nil
	return s
end

-- ============================================
-- Atirar
-- ============================================

local function doThrow()
	local s = endMode(true)
	if not s then
		return
	end
	busy = true

	CreateThread(function()
		local ped = PlayerPedId()
		local anim = cfg().ThrowAnim
		if anim and loadDictTimed(anim.dict) then
			TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, 1200, 48, 0.0, false, false, false)
		end
		Wait(cfg().ThrowReleaseMs or 350)

		local fwd = camForward()
		local hand = GetPedBoneCoords(ped, RIGHT_HAND, 0.0, 0.0, 0.0)
		local start = hand + vector3(fwd.x, fwd.y, 0.0) * 0.35

		-- para onde a câmara aponta: raio a partir de um pouco à frente do jogador (para não acertar nele)
		local cam = GetGameplayCamCoord()
		local skip = #(GetEntityCoords(ped) - cam) + 1.0
		local rayFrom = cam + fwd * skip
		local rayTo = cam + fwd * 100.0
		local _, hit, hitAt = GetShapeTestResult(StartExpensiveSynchronousShapeTestLosProbe(
			rayFrom.x, rayFrom.y, rayFrom.z, rayTo.x, rayTo.y, rayTo.z, 1 + 2 + 16, ped, 4))

		local speed = cfg().ThrowSpeed or 14.0
		local vel = hit == 1 and launchVelocity(start, hitAt, speed) or nil
		if not vel or (vel.x * fwd.x + vel.y * fwd.y) <= 0.0 then
			vel = fwd * speed + vector3(0.0, 0.0, 2.5)
		end

		-- o item sai da mão
		local name = s.name
		if s.prop then
			deleteObj(s.prop)
			s.prop = nil
		end
		TriggerServerEvent("Inventory:Server:GiveHold", false)

		local hash = GroundPropModelFor(name)
		local obj = nil
		if GroundLoadModel(hash, 2000) then
			obj = CreateObject(hash, start.x, start.y, start.z, false, false, false)
			SetModelAsNoLongerNeeded(hash)
		end

		local landing, rot, settled
		if obj and obj ~= 0 then
			SetEntityDynamic(obj, true)
			SetEntityCollision(obj, true, true)
			SetEntityHasGravity(obj, true)
			ActivatePhysics(obj)
			SetEntityMaxSpeed(obj, 100.0)
			SetEntityVelocity(obj, vel.x, vel.y, vel.z)
			SetEntityAngularVelocity(obj, math.random() * 4.0 - 2.0, math.random() * 4.0 - 2.0, math.random() * 4.0 - 2.0)

			TriggerServerEvent("Inventory:Server:ThrowStart", s.slot,
				{ x = start.x, y = start.y, z = start.z }, { x = vel.x, y = vel.y, z = vel.z })

			local started, still = GetGameTimer(), 0
			while DoesEntityExist(obj) do
				local now = GetGameTimer()
				if now - started < 400 then
					SetEntityNoCollisionEntity(obj, ped, true)
				end
				local v = GetEntityVelocity(obj)
				if #v < 0.05 then
					still = still + 1
				else
					still = 0
				end
				local c = GetEntityCoords(obj)
				settled = still >= 10
				if settled or now - started > 8000 or c.z < -50.0 then
					break
				end
				Wait(0)
			end

			if DoesEntityExist(obj) then
				landing = GetEntityCoords(obj)
				rot = GetEntityRotation(obj, 2)
				FreezeEntityPosition(obj, true)
			end
		end

		if not landing then
			-- sem objeto (modelo não carregou): cai aos pés
			local at = GetEntityCoords(ped)
			landing, rot, settled = vector3(at.x, at.y, at.z - 0.98), vector3(0.0, 0.0, GetEntityHeading(ped)), false
		end

		plsr.Callbacks:ServerCallback("Inventory:Server:ThrowItem", {
			slot = s.slot,
			count = s.count,
			x = landing.x,
			y = landing.y,
			z = landing.z,
			rx = rot.x,
			ry = rot.y,
			h = rot.z,
			settled = settled == true,
		}, function(result)
			busy = false
			if not result or not result.success then
				plsr.Notification:Error((result and result.reason) or txt("ThrowFailed"))
			end
			-- o prop "a sério" chega pela dropzone (client/drops.lua); esta cópia vai pouco depois
			SetTimeout(600, function()
				deleteObj(obj)
			end)
		end)
	end)
end

-- ============================================
-- Dar
-- ============================================

local function doGive(target)
	local s = endMode(true)
	if not s then
		return
	end
	busy = true

	plsr.Callbacks:ServerCallback("Inventory:Server:GiveItem", {
		target = target.serverId,
		slot = s.slot,
		count = s.count,
	}, function(result)
		busy = false
		if result and result.success then
			-- a animação (Inventory:Client:GiveAnim) tira o item da mão a meio
			_giveProp = s.prop
		else
			deleteObj(s.prop)
			TriggerServerEvent("Inventory:Server:GiveHold", false)
			plsr.Notification:Error((result and result.reason) or txt("GiveFailed"))
		end
	end)
end

RegisterNetEvent("Inventory:Client:GiveAnim", function(otherServerId, isGiver)
	local ped = PlayerPedId()
	local other = GetPlayerFromServerId(otherServerId)
	if other ~= -1 then
		local otherPed = GetPlayerPed(other)
		if otherPed ~= 0 and DoesEntityExist(otherPed) then
			TaskTurnPedToFaceEntity(ped, otherPed, 500)
			Wait(500)
		end
	end

	local a = cfg().GiveAnim
	if a and loadDictTimed(a.dict) then
		TaskPlayAnim(ped, a.dict, isGiver and a.giver or a.receiver, 8.0, -8.0, 2000, 48, 0.0, false, false, false)
	end

	if isGiver then
		Wait(1000)
		deleteObj(_giveProp)
		_giveProp = nil
		TriggerServerEvent("Inventory:Server:GiveHold", false)
	end
end)

-- ============================================
-- O modo
-- ============================================

-- 26 = C (olhar para trás no jogo), usado aqui para cancelar
local DISABLED_CONTROLS = { 24, 25, 26, 37, 45, 47, 58, 140, 141, 142, 143, 257, 263, 264 }

local function tick()
	while state do
		local ped = PlayerPedId()

		for i = 1, #DISABLED_CONTROLS do
			DisableControlAction(0, DISABLED_CONTROLS[i], true)
		end

		if plsr.State.flags.isDead or IsPedRagdoll(ped) or IsEntityDead(ped) then
			endMode(false)
			break
		end
		if IsPedInAnyVehicle(ped, true) then
			endMode(false)
			plsr.Notification:Error(txt("InVehicle"))
			break
		end
		if GetGameTimer() - state.started > (cfg().Timeout or 30000) then
			endMode(false)
			plsr.Notification:Error(txt("TimedOut"))
			break
		end
		if state.prop and not DoesEntityExist(state.prop) then
			state.prop = attachItemProp(ped, state.name)
		end

		local now = GetGameTimer()
		if not state.nextScan or now >= state.nextScan then
			state.nextScan = now + 150
			state.target = findTarget()
		end

		local target = state.target
		if target and DoesEntityExist(target.ped) then
			local head = GetPedBoneCoords(target.ped, 31086, 0.0, 0.0, 0.0)
			DrawMarker(2, head.x, head.y, head.z + 0.45, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.18, 0.18, 0.18,
				255, 255, 255, 190, false, true, 2, false, nil, nil, false)
			showHint(txt("HintTarget"))
		else
			target = nil
			showHint(txt("HintNoTarget"))
		end

		if IsDisabledControlJustPressed(0, 26) then -- C
			endMode(false)
			plsr.Notification:Info(txt("Cancelled"))
			break
		elseif IsDisabledControlJustPressed(0, 24) then -- clique esquerdo
			doThrow()
			break
		elseif target and IsControlJustPressed(0, 38) then -- E
			doGive(target)
			break
		end

		Wait(0)
	end
end

function StartGiveMode(slot, count, name)
	if state or busy or not slot or not name then
		return
	end
	if IsPlaceModeActive ~= nil and IsPlaceModeActive() then
		return
	end

	local ped = PlayerPedId()
	if plsr.State.flags.isDead or IsEntityDead(ped) then
		return
	end

	plsr.Inventory.Close:All()

	if IsPedInAnyVehicle(ped, true) then
		plsr.Notification:Error(txt("InVehicle"))
		return
	end

	-- as mãos livres: arma guardada (o sistema de armas do Pulsar) e desarmado
	if plsr.Weapons and plsr.Weapons.UnequipIfEquippedNoAnim then
		pcall(function()
			plsr.Weapons:UnequipIfEquippedNoAnim()
		end)
	end
	SetCurrentPedWeapon(ped, WEAPON_UNARMED, true)

	state = {
		slot = slot,
		count = count,
		name = name,
		started = GetGameTimer(),
		prevDisabled = plsr.State.flags.InventoryDisabled == true,
	}
	-- não abrir o inventário com o item na mão
	plsr.Inventory:Disable()

	state.prop = attachItemProp(ped, name)
	TriggerServerEvent("Inventory:Server:GiveHold", slot)

	CreateThread(tick)
end

function IsGiveModeActive()
	return state ~= nil
end

RegisterNUICallback("StartGiveMode", function(data, cb)
	cb(true)
	if type(data) ~= "table" then
		return
	end
	local count = tonumber(data.count)
	StartGiveMode(tonumber(data.slot), count and math.floor(count) or nil, data.name)
end)

-- ============================================
-- O que os outros veem
-- ============================================

local function clearOther(serverId)
	deleteObj(_othersHolding[serverId])
	_othersHolding[serverId] = nil
end

local _watching = false
local function watchOthers()
	if _watching then
		return
	end
	_watching = true
	CreateThread(function()
		while next(_othersHolding) do
			for sid, obj in pairs(_othersHolding) do
				local p = GetPlayerFromServerId(sid)
				if p == -1 or not DoesEntityExist(GetPlayerPed(p)) or not DoesEntityExist(obj) then
					clearOther(sid)
				end
			end
			Wait(1000)
		end
		_watching = false
	end)
end

RegisterNetEvent("Inventory:Client:PlayerHolding", function(serverId, name)
	if serverId == GetPlayerServerId(PlayerId()) then
		return
	end
	clearOther(serverId)
	if not name then
		return
	end

	local p = GetPlayerFromServerId(serverId)
	if p == -1 then
		return
	end
	local ped = GetPlayerPed(p)
	if ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(PlayerPedId())) > 60.0 then
		return
	end

	local obj = attachItemProp(ped, name)
	if obj then
		_othersHolding[serverId] = obj
		watchOthers()
	end
end)

-- Outro jogador atirou um item: uma cópia local voa pelo mesmo caminho e desaparece quando assenta
-- (o item a sério aparece pela dropzone).
RegisterNetEvent("Inventory:Client:ThrowVisual", function(serverId, name, from, vel)
	clearOther(serverId)

	local hash = GroundPropModelFor(name)
	if not GroundLoadModel(hash, 1500) then
		return
	end
	local obj = CreateObject(hash, from.x, from.y, from.z, false, false, false)
	SetModelAsNoLongerNeeded(hash)
	if not obj or obj == 0 then
		return
	end

	local p = GetPlayerFromServerId(serverId)
	local throwerPed = p ~= -1 and GetPlayerPed(p) or 0

	SetEntityDynamic(obj, true)
	SetEntityCollision(obj, true, true)
	SetEntityHasGravity(obj, true)
	ActivatePhysics(obj)
	SetEntityMaxSpeed(obj, 100.0)
	SetEntityVelocity(obj, vel.x, vel.y, vel.z)

	local started, still = GetGameTimer(), 0
	while DoesEntityExist(obj) do
		local now = GetGameTimer()
		if throwerPed ~= 0 and now - started < 400 then
			SetEntityNoCollisionEntity(obj, throwerPed, true)
		end
		if #GetEntityVelocity(obj) < 0.05 then
			still = still + 1
		else
			still = 0
		end
		if still >= 10 or now - started > 8000 then
			break
		end
		Wait(0)
	end

	Wait(900)
	deleteObj(obj)
end)

AddEventHandler("onResourceStop", function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end
	if state then
		hideHint()
		if state.prop then
			deleteObj(state.prop)
		end
	end
	deleteObj(_giveProp)
	for sid in pairs(_othersHolding) do
		clearOther(sid)
	end
end)
