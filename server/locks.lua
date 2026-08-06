-- Per slot mutex ;) Assign the result to a `<close>` local so it auto releases on any exit path
local _locks = {}

local Lock = {}
Lock.__index = Lock
Lock.__metatable = "Lock"

function Lock:__close()
	for i = 1, #self do
		_locks[self[i]] = nil
	end
end

local MAX_WAIT_ATTEMPTS = 250

---@param keys string[]
---@return Lock|false
function AcquireLocks(keys)
	local attempts = 0

	while attempts < MAX_WAIT_ATTEMPTS do
		local free = true
		for i = 1, #keys do
			if _locks[keys[i]] then
				free = false
				break
			end
		end

		if free then
			for i = 1, #keys do
				_locks[keys[i]] = true
			end
			return setmetatable(keys, Lock)
		end

		Wait(0)
		attempts += 1
	end

	return false
end
