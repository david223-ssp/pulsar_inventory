dIds = 1
dropzones = {}
local closerDrops = {}
local _dropProps = {}

function runDropsUpdate()
	if plsr.State.flags.position ~= nil then
		closerDrops = {}
		for k, v in ipairs(dropzones) do
			local distance = #(plsr.State.flags.position - vector3(v.coords.x, v.coords.y, v.coords.z))
			if distance <= Config.DropPropDistance and v.route == plsr.State.flags.currentRoute then
				table.insert(closerDrops, { id = v.id, coords = vector3(v.coords.x, v.coords.y, v.coords.z) })
			end
		end

		for id, entity in pairs(_dropProps) do
			local stillClose = false
			for k, v in ipairs(closerDrops) do
				if v.id == id then
					stillClose = true
					break
				end
			end
			if not stillClose then
				DeleteDropProp(id)
			end
		end

		for k, v in ipairs(closerDrops) do
			if not _dropProps[v.id] then
				SpawnDropProp(v.id, v.coords)
			end
		end
	end
end

function SpawnDropProp(id, coords)
	if _dropProps[id] then
		return
	end

	local model = joaat(Config.DropProp)
	LoadModel(model)
	if not HasModelLoaded(model) then
		return
	end

	local entity = CreateObject(model, coords.x, coords.y, coords.z, false, true, true)
	PlaceObjectOnGroundProperly(entity)
	FreezeEntityPosition(entity, true)
	SetEntityAsMissionEntity(entity, true, true)
	SetModelAsNoLongerNeeded(model)

	plsr.Targeting:AddEntity(entity, "box-open", {
		{ icon = "box-open", text = "Open", event = "Inventory:Client:OpenGroundDrop", data = { id = id, coords = coords } },
	})

	_dropProps[id] = entity
end

function DeleteDropProp(id)
	local entity = _dropProps[id]
	if entity then
		plsr.Targeting:RemoveEntity(entity)
		if DoesEntityExist(entity) then
			DeleteEntity(entity)
		end
		_dropProps[id] = nil
	end
end

AddEventHandler("Inventory:Client:OpenGroundDrop", function(ent, data)
	SecondInventory = { invType = 10, owner = data.id, position = data.coords }
	plsr.Inventory.Open:Player(true)
end)

function startDropsTick()
	CreateThread(function()
		while plsr.State.flags.loggedIn do
			runDropsUpdate()
			Wait(1000)
		end
	end)
end

RegisterNetEvent("Inventory:Client:DropzoneForceUpdate", function(dzs)
	dropzones = dzs
end)

RegisterNetEvent("Inventory:Client:AddDropzone", function(data)
	table.insert(dropzones, data)
end)

RegisterNetEvent("Inventory:Client:RemoveDropzone", function(id)
	for k, v in ipairs(dropzones) do
		if v.id == id then
			table.remove(dropzones, k)
			break
		end
	end
	DeleteDropProp(id)
end)

AddEventHandler("onResourceStop", function(resource)
	if resource == GetCurrentResourceName() then
		for id in pairs(_dropProps) do
			DeleteDropProp(id)
		end
	end
end)
