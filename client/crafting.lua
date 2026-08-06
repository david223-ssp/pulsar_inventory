CRAFTING = {
	Benches = {
		Open = function(self, bench)
			TriggerServerEvent("Inventory:Server:Request", {
				crafting = true,
				id = bench,
			})
		end,
		Cleanup = function(self)
			for k, v in ipairs(_benchObjs) do
				plsr.Targeting:RemoveEntity(v)
				DeleteEntity(v)
			end
			_benchObjs = {}
		end,
		Refresh = function(self, interior)
			self:Cleanup()

			if _benches then
				for k, v in ipairs(_benches) do
					if v.targeting and not v.targeting.manual then
						if
							v.restrictions.interior == nil
							or v.restrictions.interior
								== GlobalState[string.format("%s:Property", plsr.State.flags.ID)]
						then
							local obj = nil
							if v.targeting.model ~= nil then
								obj = CreateObject(
									GetHashKey(v.targeting.model),
									v.location.x,
									v.location.y,
									v.location.z,
									false,
									true,
									false
								)
								FreezeEntityPosition(obj, true)
								table.insert(_benchObjs, obj)
								SetEntityHeading(obj, v.location.h)
							end

							if
								v.restrictions.shared
								or (v.restrictions.char ~= nil and v.restrictions.char == plsr.State.character.SID)
								or (v.restrictions.job ~= nil and plsr.Jobs.Permissions:HasJob(
									v.restrictions.job.id,
									v.restrictions.job.workplace,
									v.restrictions.job.grade,
									false,
									false,
									v.restrictions.job.permissionKey or "JOB_CRAFTING"
								))
								or (
									v.restrictions.rep ~= nil
									and plsr.Reputation:GetLevel(v.restrictions.rep.id) >= v.restrictions.rep.level
								)
							then
								local menu = {
									{
										icon = v.targeting.icon,
										text = v.label,
										event = "Crafting:Client:OpenCrafting",
										data = v,
										jobPerms = v.restrictions.job ~= nil and {
											{
												job = v.restrictions.job.id,
												workplace = v.restrictions.job.workplace,
												reqDuty = v.restrictions.job.onDuty,
												reqOffDuty = not v.restrictions.job.onDuty,
											},
										} or nil,
									},
								}

								if v.canUseSchematics then
									table.insert(menu, {
										icon = "memo-circle-check",
										text = "Add Schematic To Bench",
										event = "Crafting:Client:AddSchematic",
										data = v,
										isEnabled = function(data, entityData)
											return plsr.Inventory.Items:HasType(17, 1)
										end,
										jobPerms = v.restrictions.job ~= nil and {
											{
												job = v.restrictions.job.id,
												workplace = v.restrictions.job.workplace,
												reqDuty = v.restrictions.job.onDuty,
												reqOffDuty = not v.restrictions.job.onDuty,
											},
										} or nil,
									})
								end

								if obj ~= nil then
									plsr.Targeting:AddEntity(obj, v.targeting.icon, menu)
								elseif v.targeting.ped ~= nil then
									plsr.PedInteraction:Add(
										v.id,
										GetHashKey(v.targeting.ped.model),
										vector3(v.location.x, v.location.y, v.location.z),
										v.location.h,
										25.0,
										menu,
										v.targeting.icon,
										v.targeting.ped.task
									)
								elseif v.targeting.poly ~= nil then
									plsr.Targeting.Zones:AddBox(
										v.id,
										v.targeting.icon,
										v.targeting.poly.coords,
										v.targeting.poly.w,
										v.targeting.poly.l,
										v.targeting.poly.options,
										menu,
										2.0,
										true
									)
								end
							else
								if obj ~= nil then
								elseif v.targeting.ped ~= nil then
									plsr.PedInteraction:Remove(v.id)
								elseif v.targeting.poly ~= nil then
									plsr.Targeting.Zones:RemoveZone(v.id)
								end
							end
						end
					end
				end

				plsr.Targeting.Zones:Refresh()
			end
		end,
	},
}

_benchObjs = {}
_benches = nil
RegisterNetEvent("Crafting:Client:CreateBenches", function(benches)
	_benches = benches
	plsr.Crafting.Benches:Refresh(nil)
end)

AddEventHandler("Characters:Client:Updated", function(key)
	if key == -1 then
		plsr.Crafting.Benches:Refresh(nil)
	end
end)

RegisterNetEvent("Job:Client:DutyChanged", function(state)
	plsr.Crafting.Benches:Refresh(nil)
end)

RegisterNetEvent("Crafting:Client:ForceBenchRefresh", function()
	plsr.Crafting.Benches:Refresh(nil)
end)

RegisterNetEvent("Characters:Client:Logout", function()
	plsr.Crafting.Benches:Cleanup()
end)

AddEventHandler("Crafting:Client:OpenCrafting", function(ent, data)
	plsr.Crafting.Benches:Open(data.id)
end)

AddEventHandler("Crafting:Client:AddSchematic", function(ent, data)
	plsr.Callbacks:ServerCallback("Crafting:GetSchematics", data, function(schematics)
		if #schematics > 0 then
			for k, v in ipairs(schematics) do
				schematics[k].data = {
					bench = data.id,
					schematic = schematics[k].data,
				}
			end

			plsr.ListMenu:Show({
				main = {
					label = "Crafting Schematics",
					items = schematics,
				},
			})
		else
			plsr.Notification:Error("You Have No Schematics")
		end
	end)
end)

AddEventHandler("Crafting:Client:UseSchematic", function(data)
	plsr.Progress:Progress({
		name = "schematic_action",
		duration = 8000,
		label = "Using Schematic",
		useWhileDead = false,
		canCancel = true,
		ignoreModifier = true,
		controlDisables = {
			disableMovement = true,
			disableCarMovement = true,
			disableMouse = false,
			disableCombat = true,
		},
	}, function(cancelled)
		if not cancelled then
			plsr.Callbacks:ServerCallback("Crafting:UseSchematic", data, function(s) end)
		end
	end)
end)

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["pulsar_core"]:RegisterComponent("Crafting", CRAFTING)
end)

RegisterNUICallback("Crafting:Craft", function(data, cb)
	plsr.Callbacks:ServerCallback("Crafting:Craft", data, function(state)
		if not state.error then
			cb(state)
		else
			plsr.Notification:Error(string.format("Error - %s", state.message or "Something Is Broken, Report This"))
			cb(false)
		end
	end)
end)

function RegisterBenches() end
