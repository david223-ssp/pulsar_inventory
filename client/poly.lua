_inInvPoly = nil

RegisterNetEvent("Inventory:Client:PolySetup", function(locs)
	for k, v in ipairs(locs) do
		local data = GlobalState[string.format("Inventory:%s", v)]
		if data ~= nil then
			if data.data ~= nil then
				data.data.isInventory = true 
			end

			if data.type == "box" then
				plsr.Polyzone.Create:Box(data.id, data.coords, data.length, data.width, data.options, data.data)
			elseif data.type == "poly" then
				plsr.Polyzone.Create:Poly(data.id, data.points, data.options, data.data)
			else
				plsr.Polyzone.Create:Circle(data.id, data.coords, data.radius, data.options, data.data)
			end
		end
	end
end)

AddEventHandler("Polyzone:Enter", function(id, testedPoint, insideZones, data)
	if GlobalState[string.format("Inventory:%s", id)] ~= nil then
		plsr.State.flags._inInvPoly = data
		_inInvPoly = data
	end
end)

AddEventHandler("Polyzone:Exit", function(id, testedPoint, insideZones, data)
	if plsr.State.flags.loggedIn and GlobalState[string.format("Inventory:%s", id)] ~= nil then
		if
			SecondInventory ~= nil
			and SecondInventory.owner == data.owner
			and SecondInventory.invType == data.invType
		then
			plsr.Inventory.Close:All()
		end
		plsr.State.flags._inInvPoly = nil
		_inInvPoly = nil
	end
end)
