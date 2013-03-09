-- Snake server
package.path = "snake/?.lua;../?.lua;"..package.path
require"app"
require"snake-main"
	
A = App:new()

Sockets = { }
	
function A.dataDispatchers.socketdata (self, data)
	local from = data.from
	
	-- Sprawdzamy, czy mamy socketa laczacego nas z nadawca
	if not Sockets[from] then
		-- Jesli nie, tworzymy go
		Sockets[from] = A:createSocket(from)
	end
	print ("New client connected, id = ", from)
	--if data.data = "I want to watch snake!" then
	--end
	--Sockets[from]:send(data.data .." :P")
end

--A:initialize("172.27.3.46")
A:initialize("localhost")
S = Snake:new()
S:init()

function sendSnakeInfo()
	for i,s in pairs(Sockets) do
		--print ("Sending snake data to client "..i)
		S:sendState(s)
	end
end

function Loop()
	while true do
		A:getData()
		A:processData()
		if not A.suspended then
			sendSnakeInfo()
			S:move()
		end
		sleep(0.05)
	end
end

function App:serialize()
	self.SerializeBuffer = {
		sockets = { },
		snakeData = { },
		direction = S.direction,
		suspended = self.suspended,
	}	
	
	for i = S.Data.first, S.Data.last do
		table.insert(self.SerializeBuffer.snakeData, S.Data[i])
	end

	for i,v in pairs(Sockets) do
		self.SerializeBuffer.sockets[i] = i
	end
end
function App:deserialize()
	print ("Deserializing snake server")
	for i,v in pairs(self.SerializeBuffer.sockets) do
		Sockets[i] = A:createSocket(i)
	end
	S.Data = List:new()
	for _,v in ipairs(self.SerializeBuffer.snakeData) do
		S.Data:pushright(v)
	end
	S.direction = self.SerializeBuffer.direction
	self.suspended = self.SerializeBuffer.suspended
end

Loop()