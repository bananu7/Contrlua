
local Client = { }
local Node = { }

-- basic controller module

function Client.hello(self, packet)
	self.connection:send("hi\r\n")
end

function Client.disconnect(self, packet)
	print ("App "..self.id.." disconnected")
	apps[self.id] = nil
end

function Client.request(self, packet)
	print ("request")
	if packet.data == "id" then
		P = {
			kind="newid",
			data=self.id,
			timestamp = socket.gettime()
		}
		self:fancySend(P)
	elseif packet.data  == "newsocket" then
		table.insert(self.sockets, packet.recipient)
		P = {
			kind="newsocket",
			data = #(self.sockets),
			timestamp = socket.gettime()
		}
		self:fancySend(P)
	end
end

function Client.identify(self, packet)
	local new_id = packet.data
	print ("Identified app : "..new_id)
	apps[new_id] = apps[self.id]

	if appCache[new_id] then
		apps[new_id].SerializeData = appCache[new_id]

		self:fancySend {
			kind="serializedata",
			data=appCache[new_id]
		}
	end
	apps[self.id] = nil
	apps[new_id].id = new_id
end

function Client.socketdata(self, packet)
	-- TODO: dopisac kilku recipientow?
	local recipient = packet.recipient or self.sockets[packet.socketid]
	--print (string.format ("Dataflow from %s (socket %d) to %s", self.id, packet.socketid, recipient ))
	if not recipient then
		print ("Socketdata without recipient : dropping")
		return
	end

	if apps[recipient] then
		--TEMP - podpisujemy, od kogo jest wiadomosc
		packet.from = self.id
		apps[recipient]:fancySend(packet)
	elseif foreignApps[recipient] then
		packet.recipient = recipient
		nodes[foreignApps[recipient]]:fancySend(packet)
	else
		-- if we already queued to ask, no use asking again
		local AddQuery = true
		for i = QueryBuffer.first, QueryBuffer.last do
			if QueryBuffer[i].data == recipient and QueryBuffer[i].kind == "is_given_app_there" then
				AddQuery = false
				break
			end
		end
		if AddQuery then
			print ("I don't have app "..recipient.." there, gonna ask grid")
			QueryBuffer:pushright( {
				kind = "is_given_app_there",
				data = recipient,
				from = NodeName,
			})
		end
		packet.recipient = recipient
		DataBuffers[recipient] = DataBuffers[recipient] or List:new()
		DataBuffers[recipient]:pushright(packet)
	end
end

function Client.console(self, packet)
	-- odebralismy kod do przeslania do innego node'a
	print ("console packet received")
	if packet.id == 0 then
		print ("Executing foreign code from ",self.id," : ",packet.data)
		testv = "testv"
		assert(loadstring(packet.data))()
	else
		apps[packet.id]:fancySend(packet)
	end
end

function Client.serializedata(self, packet)
	print ("Received serialization data from app "..self.id)
	self.SerializeData = packet.data
	if self.scheduledToMove then
		Operations.MoveApp(self.id, self.scheduledToMove)
	end
end


-- NODE
---------------------------------------------------------------------------

function Node.is_given_app_there(self, packet)
	local app_id = packet.data
	print ("Received app discovery request about "..app_id.." from "..self.id)
	local response = { kind = "app_query_response" }
	-- if apps[app_id] is nil, it just means we dont have this app
	response.data = app_id
	self:fancySend(response)
end

function Node.app_query_response(self, packet)
	if packet.data then
		print ("Just found app "..packet.data.." on controller "..self.id)
		while DataBuffers[packet.data]:size() > 0 do
			local Node = DataBuffers[packet.data]:popleft()
			self:fancySend(Node)
		end

		foreignApps[packet.data] = self.id
	end
end

function Node.socketdata(self, packet)
	if apps[packet.recipient] then
		apps[packet.recipient]:fancySend(packet)
	else
		print("Received data for app "..packet.recipient.." from node "..self.id)
		print("It doesn't exist on current node, additional research is required")
	end
end

function Node.app_run(self, packet)
	Operations.RunApp (packet.data.name, packet.data.id, packet.data.serializeData)
end

function Node.identification(self, packet)
	local Reconnected = RenameNode(self.id, packet.data)
	if Reconnected then
		print("Node "..packet.data.." reconnected")
	else
		print("Node "..self.id.." is now known as "..packet.data)
	end
end

return { Client = Client, Node = Node }
