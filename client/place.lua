-- Colocar (Config.PlaceMode), como no WHIP.
--
-- "Place" no menu de um item fecha o inventário e mostra uma cópia transparente do item que segue a câmara:
--   [E]           coloca o item exatamente ali (vai para o chão como item físico, client/drops.lua)
--   [Roda rato]   roda-o
--   [C]           cancela
-- O servidor (server/ground_items.lua, "Inventory:Server:PlaceItem") verifica a distância e mexe o item.

local state = nil -- { slot, count, name, label, started, ghost, hash, minZ, heading, valid, pos, prevDisabled }
local busy = false
local _hint = nil

local function pcfg()
	return Config.PlaceMode or {}
end

local function txt(key)
	return ((Config.GiveMode or {}).Text or {})[key] or key
end

local function showHint(text)
	if _hint == text then
		return
	end
	_hint = text
	if plsr.Action and plsr.Action.Show then
		plsr.Action:Show("inventory_place", text)
	end
end

local function hideHint()
	if _hint == nil then
		return
	end
	_hint = nil
	if plsr.Action and plsr.Action.Hide then
		plsr.Action:Hide("inventory_place")
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

-- Onde a câmara aponta: mundo e objetos (não veículos, que se mexem), ignorando o próprio jogador.
local function aimPoint(ped)
	local cam = GetGameplayCamCoord()
	local fwd = camForward()
	local to = cam + fwd * 15.0
	local _, hit, at, normal = GetShapeTestResult(StartExpensiveSynchronousShapeTestLosProbe(
		cam.x, cam.y, cam.z, to.x, to.y, to.z, 1 + 16, ped, 4))
	if hit ~= 1 then
		return nil
	end
	return at, normal
end

local function deleteGhost(obj)
	if obj and DoesEntityExist(obj) then
		DeleteEntity(obj)
	end
end

local function endMode()
	if not state then
		return nil
	end
	hideHint()
	if not state.prevDisabled then
		plsr.Inventory:Enable()
	end
	local s = state
	state = nil
	return s
end

local function cancel(reason)
	local s = endMode()
	if s then
		deleteGhost(s.ghost)
	end
	if reason then
		plsr.Notification:Error(reason)
	end
end

local function confirm()
	local s = endMode()
	if not s then
		return
	end
	busy = true

	CreateThread(function()
		local ped = PlayerPedId()
		local pos = s.pos
		TaskTurnPedToFaceCoord(ped, pos.x, pos.y, pos.z, 400)
		Wait(300)

		local anim = pcfg().Anim
		if anim and loadDictTimed(anim.dict) then
			TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, 1000, 48, 0.0, false, false, false)
			Wait(600)
		end

		-- a pré-visualização fica opaca enquanto o servidor responde
		if DoesEntityExist(s.ghost) then
			ResetEntityAlpha(s.ghost)
		end

		plsr.Callbacks:ServerCallback("Inventory:Server:PlaceItem", {
			slot = s.slot,
			count = s.count,
			x = pos.x,
			y = pos.y,
			z = pos.z,
			rx = 0.0,
			ry = 0.0,
			h = s.heading,
			settled = true,
		}, function(result)
			busy = false
			if not result or not result.success then
				deleteGhost(s.ghost)
				plsr.Notification:Error((result and result.reason) or txt("PlaceFailed"))
				return
			end
			-- o prop "a sério" chega pela dropzone (client/drops.lua); a cópia sai pouco depois
			SetTimeout(700, function()
				deleteGhost(s.ghost)
			end)
		end)
	end)
end

-- 26 = C, 14/15 = roda do rato (troca de arma no jogo)
local DISABLED_CONTROLS = { 14, 15, 16, 17, 24, 25, 26, 37, 45, 47, 58, 140, 141, 142, 143, 257, 263, 264 }

local function tick()
	local maxDist = pcfg().MaxDistance or 3.5
	local alpha = pcfg().Alpha or 160
	local step = pcfg().RotateStep or 10.0

	while state do
		local ped = PlayerPedId()

		for i = 1, #DISABLED_CONTROLS do
			DisableControlAction(0, DISABLED_CONTROLS[i], true)
		end

		if plsr.State.flags.isDead or IsEntityDead(ped) or IsPedRagdoll(ped) then
			cancel()
			break
		end
		if IsPedInAnyVehicle(ped, true) then
			cancel(txt("InVehicle"))
			break
		end
		if GetGameTimer() - state.started > (pcfg().Timeout or 60000) then
			cancel(txt("TimedOut"))
			break
		end
		if not DoesEntityExist(state.ghost) then
			cancel()
			break
		end

		if IsDisabledControlJustPressed(0, 15) then
			state.heading = (state.heading + step) % 360.0
		elseif IsDisabledControlJustPressed(0, 14) then
			state.heading = (state.heading - step) % 360.0
		end

		local at, normal = aimPoint(ped)
		local me = GetEntityCoords(ped)
		local valid = at ~= nil
			and normal.z >= 0.6 -- chão / tampo, não parede
			and #(at - me) <= maxDist
			and math.abs(at.z - me.z) <= 2.0

		if at then
			local z = at.z - state.minZ
			SetEntityCoordsNoOffset(state.ghost, at.x, at.y, z, false, false, false)
			SetEntityRotation(state.ghost, 0.0, 0.0, state.heading, 2, true)
			state.pos = vector3(at.x, at.y, z)
		end
		SetEntityVisible(state.ghost, at ~= nil, false)

		if valid ~= state.valid then
			state.valid = valid
			SetEntityAlpha(state.ghost, valid and alpha or math.floor(alpha * 0.35), false)
		end

		if valid then
			showHint(txt("HintPlace"):format(state.label))
		else
			showHint(txt("HintPlaceInvalid"))
		end

		if IsDisabledControlJustPressed(0, 26) then -- C
			cancel()
			plsr.Notification:Info(txt("Cancelled"))
			break
		elseif valid and IsControlJustPressed(0, 38) then -- E
			confirm()
			break
		end

		Wait(0)
	end
end

function StartPlaceMode(slot, count, name)
	if state or busy or not slot or not name then
		return
	end
	if IsGiveModeActive ~= nil and IsGiveModeActive() then
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

	local hash = GroundPropModelFor(name)
	if not GroundLoadModel(hash, 2000) then
		plsr.Notification:Error(txt("PlaceFailed"))
		return
	end

	local at = GetEntityCoords(ped)
	local ghost = CreateObject(hash, at.x, at.y, at.z - 5.0, false, false, false)
	SetModelAsNoLongerNeeded(hash)
	if not ghost or ghost == 0 then
		plsr.Notification:Error(txt("PlaceFailed"))
		return
	end
	SetEntityCollision(ghost, false, false)
	FreezeEntityPosition(ghost, true)
	SetEntityAlpha(ghost, pcfg().Alpha or 160, false)
	SetEntityVisible(ghost, false, false)

	local minDim = GetModelDimensions(hash)
	local def = _items and _items[name] or nil

	state = {
		slot = slot,
		count = count,
		name = name,
		label = (def and def.label) or name,
		started = GetGameTimer(),
		ghost = ghost,
		minZ = minDim and minDim.z or 0.0,
		heading = GetEntityHeading(ped),
		valid = nil,
		pos = nil,
		prevDisabled = plsr.State.flags.InventoryDisabled == true,
	}
	-- não abrir o inventário durante a colocação
	plsr.Inventory:Disable()

	CreateThread(tick)
end

function IsPlaceModeActive()
	return state ~= nil or busy
end

RegisterNUICallback("StartPlaceMode", function(data, cb)
	cb(true)
	if type(data) ~= "table" then
		return
	end
	local count = tonumber(data.count)
	StartPlaceMode(tonumber(data.slot), count and math.floor(count) or nil, data.name)
end)

AddEventHandler("onResourceStop", function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end
	if state then
		hideHint()
		deleteGhost(state.ghost)
	end
end)
