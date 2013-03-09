local Node = { }
local Client = { }

-- module mainly for remote diagnostics and control

function Client.get_applist(self, packet)
	local TempTable = { }
	for i,_ in pairs(apps) do
		table.insert(TempTable, i)
	end
	self:fancySend{
		kind = "applist",
		data = TempTable,
	}
end

return { Node = Node, Client = Client }
