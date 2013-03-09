local Node = { }
local Client = { }
local Operations = { }

-- module containing high-availabilty functions

function Client.poke_reply (self, packet)
	self.LastDataTime = socket.gettime()
end

-- OPERATIONS
-----------------------------------------------------------------

function Operations.BackupServe()
	-- Backup serve realizes two functions

	-- 1. Act as a backup - check other controllers for stability
	local CurrentTime = socket.gettime()
	for id,v in pairs(appCache) do
		if v.Delay then
			-- if the app has been inactive for too long
			if (CurrentTime - v.LastTime) > Delay then
				-- Can we just skip the last parameter and query
				-- cache directly from RunApp instead?
				-- (+ just turn it into bool)
				RunApp (id, v.Name, v.SerializeData)
			end
		end
	end
	-- 2. Act as a backup-er - inform backup nodes he is still working
	for _,id in pairs(BackupNodes) do
		nodes[id]:fancySend { kind="keep_alive" from=NodeName }
	end
end

function Operations.BackupStart (app_id, node_id)
	-- send backup info to new node. It's the last one,
	-- so it doesn't have to know about any others.
	
	if not BackupNodes[node_id] then -- node isn't our backup yet
		BackupNodes[node_id] = { }
		BackupNodes[node_id].apps = { } -- this table will hold apps to serialize
	end
	
	table.insert(BackupNodes[node_id].apps, app_id)
	
	-- what's important here is that app_id is truly global
	-- around the whole cloud. It doesn't matter if we are on NC or EC level
	nodes[node_id]:fancySend {
		kind = "backup_start",
		app_id = app_id,
		app_name = apps[app_id].Name,
		delay = #BackupNodes[node_id] * 200, -- in miliseconds
		from = NodeName
	}
	
	-- Now, we need to inform other nodes that the new one will
	-- also panic, and they have to either continue to update it,
	-- or to send him a note that he is free from given backup task.
	-- TODO
end
function Operations.UpdateBackupData (app_id)
	--apps[app_id]:fancySend{ kind="serialize" }
	
	local BData = apps[app_id].SerializeData
	
	for _,v in ipairs(apps[app_id].BackupNodes) do 
		nodes[v]:fancySend { 
			kind="backup_data",
			data = BData,
			app_id = app_id 
		}
	end
end
function Operations.BackupEnd (app_id, node_id)
	if node_id then
		if nodes[node_id] then
			nodes[node_id]:fancySend{ kind = "backup_end" }
		else
			print ("Node "..node_id.." not present for backup_end")
		end
	else --if node id is not provided, we stop the backup on ALL nodes
		for _,v in ipairs(apps[app_id].BackupNodes) do 
			nodes[v]:fancySend { kind = "backup_end" }
		end
	end
end

-- NODE
----------------------------------------------------------------------

function Node.backup_start (self, packet)
	-- We can provide some data right when backup starts
	-- This can be also used paired with Delay == infinity
	-- to store snapshots on controllers
	
	-- First, check if we are backing up ANY of the sender's apps
	nodes[packet.from].AppCache = nodes[packet.from].AppCache or { }
	
	-- Second, check in case we already have started backup for given app
	appCache[packet.app_id].SerializedData = packet.data
	
	-- In current design each app has it's own name and possibly
	-- other attributes (ex. version)
	appCache[packet.app_id].Name = packet.app_name
	appCache[packet.app_id].Delay = packet.delay
end
function Node.backup_data (self, packet)
	if nodes[packet.from].AppCache and nodes[packet.from].AppCache[packet.app_id] then
	else
		nodes[packet.from].AppCache[packet.app_id].SerializedData = packet.data
		print ("Backup not started for app "..packet.app_id)
	end
end
function Node.backup_stop (self, packet)
	if nodes[packet.from].AppCache then
		-- we didn't get a chance to run this app, so
		-- deleting all of its data now
		nodes[packet.from].AppCache = nil
	else
		print ("Trying to stop non-existing backup task")
	end
end
function Node.keep_alive (self, packet)
	if nodes[packet.from] and nodes[packet.from].Delay then
		nodes[packet.from].LastContact = socket.gettime()
	else
		print ("Node "..packet.from.." is either not present or not set for backup")
	end
end

-- Add backup server to tasks
local OnLoad = [[
	AddTask(Operations.BackupServe)
]]

return { Node = Node, Client = Client, OnLoad = OnLoad }
