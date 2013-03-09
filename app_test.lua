require"json"
require"app"

A = App:new()
A:initialize()

Sockets = { }

function Reload()
	package.loaded["app"] = nil
	require"app"
	A.getData = App.getData
end

function A.dataDispatchers.socketdata (self, packet)
	local from = packet.from

	-- Sprawdzamy, czy mamy socketa laczacego nas z nadawca
	if not Sockets[from] then
		-- Jesli nie, tworzymy go
		Sockets[from] = A:createSocket(from)
	end

	Sockets[from]:send(packet.data .." :P")
end

function ReplyLoop()
	while true do
		socket.sleep(0.005)
		A:getData()
		A:processData()
		Reload();
	end
end
