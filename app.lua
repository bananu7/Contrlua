
local socket = require("socket")
local List = require"simple_list"
json = require"json"

function sleep(sec)
	socket.select(nil, nil, sec)
end

AdvaSocket = {
	controller = nil
}


App = {
	id = nil,
	controllerSocket = nil,
	dataQueue = nil,
	processCoroutine = nil,
	lastReqId = 0,
	suspended = false,
	dataDispatchers = { }
}

function App:new (o)
	o = o or { }
	o.dataQueue = List:new()
	setmetatable(o, self)
	-- linijka ponizej jest wazna tylko raz
	self.__index = self

	self.processCoroutine = coroutine.create (function () self:processData() end)

	return o
end

packets = {
	--TEMP! - druga czesc ma byc w JSONie
	request_newid = '{"kind":"request", "data":"id"}\r\n',
	request_newsocket = '{"kind":"request", "data":"socket"}\r\n'
}

function App:initialize(addr)
	self.controllerSocket = socket.tcp()
	local addr, port = addr or "localhost", 5000

	print ("Attempting Controller linkage")
	local ok, err = self.controllerSocket:connect (addr, port)
	self.controllerSocket:settimeout(0)
	if not ok then
		print ("Connection to Controller failed : ", err)
	else
		print ("Connected to controller")
	end

	self.name = arg[0]

	-- request app id
	if arg[1] then
		print ("Identifying as : "..arg[1])
		self.id = arg[1]
		self.controllerSocket:send(json.encode({ kind = "identify", data=arg[1] }).."\r\n")
	else
		self.controllerSocket:send(packets["request_newid"])
	end
end

MetaSocket = {
	app = nil,
	id = nil
}

function MetaSocket:new(appHandle, socketId)
	o = { }
	o.app = appHandle
	o.id = socketId
	setmetatable(o, self)
	self.__index = self
	return o
end

function MetaSocket:send(dataToSend)
	-- Opakowujemy dane uzytkownika w odpowiedni 'kontener'
	packet = {
		kind = "socketdata",
		data = dataToSend,
		socketid = self.id,
		from = self.app.id,
		timestamp = socket.gettime()
	}

	-- I wysylamy bezposrednio do Controllera
	self.app:fancySend(packet)
end

function App:createSocket(toWhere)
	-- request new socket with controller
	P = { kind="request", data="newsocket", recipient=toWhere }
	self:fancySend(P)

	-- Czekamy na pale na odpowienie dane

	while true do
		local data, status = self.controllerSocket:receive()
		if data then
			data = json.decode(data)
			if not data.kind then
				print ("Wrong packet received!")
			end

			if data.kind ~= "newsocket" then
				self.dataQueue:pushright(data)
			else
				return MetaSocket:new(self, data.data)
			end
		end
	end
end

function App:getData()
	local data, status = self.controllerSocket:receive()
	while data do
		print ("rawdata : "..data)
		packet, err, err2 = json.decode(data)
		if not packet then
			error ("Json decode failed "..err.." "..err2)
		end

		if not packet.kind then
			print ("Wrong packet received!")
		end

		self.dataQueue:pushright(packet)

		data, status = self.controllerSocket:receive()
	end
end

function App:update()
	print ("update")
end

function App:processData()
	if self.dataQueue:size() == 0 then
		return
	end

	local data = self.dataQueue:popleft()
	while data do
		if data.timestamp then
			local Delay = socket.gettime() - data.timestamp
			print ("Delay (server->ctrl->client) = "..Delay)
		else
			print ("Time info unavailable")
		end

		if self.dataDispatchers[data.kind] then
			self.dataDispatchers[data.kind](self, data)
		else
			print("No data dispatcher for packet kind '"..data.kind.."' loaded")
		end

		if self.dataQueue:size() == 0 then
			return
		end
		data = self.dataQueue:popleft()
	end
end

function App.dataDispatchers.console (self, data)
	print ("Executing remote request: ",data.data)
	loadstring(data.data)()
end
function App.dataDispatchers.newid (self, data)
	print ("Received new id: ", data.data)
	self.id = data.data
end
function App.dataDispatchers.socketdata (self, data)
	print ("Received data : %s", data.data)
end
function App.dataDispatchers.serialize (self, data)
	print ("Received serialization request, sending data to controller")
	self:serialize()
	self:fancySend {
		kind="serializedata",
		data=self.SerializeBuffer
	}
end
function App.dataDispatchers.serializedata (self, data)
	print ("Received serialized state data")
	self.SerializeBuffer = data.data
	self:deserialize()
end
function App.dataDispatchers.suspend (self, data)
	self.suspended = true
end
function App.dataDispatchers.unsuspend (self, data)
	self.suspended = false
end
function App.dataDispatchers.poke (self, data)
	self:fancySend { kind="poke_reply" }
end

-- Stub functions - overload them if you need them
-- You can use self.SerializeBuffer to store your data
function App:serialize()
end
function App:deserialize()
end

function App:rawSend (data)
	--print ("sending ",data)
	ok, err = self.controllerSocket:send(data)
	if not ok then
		error ("error sending : ", err)
	end
end

function App:fancySend (packet)
	self:rawSend(json.encode(packet).."\r\n")
end

-- funkcja do wywolywania kodu na controllerze
function App:Ct (code)
	local P = {kind="console", data=code, id=0}
	self:fancySend(P)
end


