require ("simple_list")
local json = require "json"

Client =
{
	Data = List:new(),
	connection = nil,
	id = nil,
}

function Client:new(o)
	o = o or { }
	setmetatable(o, self)
	self.__index = self

	o.Coroutine = coroutine.create (function()
		while true do
			o:ProcessData()
		end
	end)

	return o
end

function Client:fancySend(P)
	self.connection:send(json.encode(P).."\r\n")
end

function Client:Resume()
	assert(coroutine.resume(self.Coroutine))
end

function Client:ProcessData()
	-- ta funkcja moze wymagac dowolnie duzo danych
	local data = self:_FetchData()
	print (data)
end

function Client:_FetchData(filter)
	while self.Data:size() < 1 do
		coroutine.yield(self.Coroutine)
	end
	if filter then
		print ("im in _FetchData of "..self.id)
		while true do
			-- matching filter
			for packet = self.Data.first, self.Data.last do
				local match = true
				for field,value in pairs(filter) do
					if value ~= self.Data[packet][field] then
						match = false
						break
					end
				end
				if match then
					return self.Data[packet]
				end
			end
			-- didnt find any matching packet
			coroutine.yield(self.Coroutine)
		end
	end
	return json.decode(self.Data:popleft())
end

function Client:AddData(x)
	self.Data:pushright(x)
end

function receive_raw (conn)
	local s, status = conn:receive()
	return s, status
end

function Client:Update ()
	local packet = receive_raw(self.connection)
	while packet do
		self:AddData(packet)
		packet = receive_raw(self.connection)
	end

	self:Resume()
	return self.alive
end

