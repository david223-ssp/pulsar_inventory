function RegisterStashCallbacks()
	plsr.Callbacks:RegisterServerCallback("Stash:Server:Open", function(source, data, cb)
		if GlobalState[string.format("%s:Property", source)] ~= nil then
			local pid = GlobalState[string.format("%s:Property", source)]
			if not _openInvs[string.format("%s-%s", 13, pid)] then
				plsr.Inventory.Stash:Open(source, 13, pid)
				cb({ type = 13, owner = string.format("stash:%s", pid) })
			else
				cb(nil)
			end
		else
			cb(nil)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Shop:Server:Open", function(source, data, cb)
		local k = string.format("shop:%s", data.identifier)
		if shopLocations[k] ~= nil then
			local entId = shopLocations[k].entityId
			if not _openInvs[string.format("%s-%s", entId, data.identifier)] then
				plsr.Inventory:OpenSecondary(source, entId, ("shop:%s"):format(data.identifier))
				cb(entId)
			else
				cb(false)
			end
		else
			cb(false)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Inventory:Server:Open", function(source, data, cb)
		if not _openInvs[string.format("%s-%s", data.invType, data.owner)] then
			if entityPermCheck(source, data.invType) then
				plsr.Inventory:OpenSecondary(source, data.invType, data.owner, data.class or false, data.model or false)
				cb(true)
			else
				cb(false)
			end
		else
			cb(false)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("PlayerShop:Server:Open", function(source, data, cb)
		if _playerShops[data.id] then
			if not _openInvs[string.format("200-%s", data.id)] then
				plsr.Inventory:OpenSecondary(source, 200, data.id)
				cb(200)
			else
				cb(false)
			end
		else
			cb(false)
		end
	end)
end
