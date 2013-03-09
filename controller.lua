 -- lua messaging function
-- TODO
-- ogarnac ustalony format przesylania danych o innych nodach
-- ogarnac dostep do danych o innych nodach z poziomu noda - bardziej obiektowo

local socket = require("socket")
--local timer = require ("timer") --pure lua
require ("simple_list") -- pure lua
require ("client") -- pure lua
require"get-opt" -- pure lua

-- simple check of OS
operatingSystem = os.getenv("HOME") and "ix" or "windows"

local timer
if operatingSystem == "windows" then
	timer=require"HiResTimer"
else
	--timer=require"timer"
end
-- this catalog should be loaded from file
appCatalog = require"app-catalog"

apps = { }
appCount = 0
appCache = { }
foreignApps = { } -- pairs of <app_id, ctrl_id>
nodes = { }
nodeCount = 0

QueryBuffer = List:new()
DataBuffers = { }
Tasks = { }

local NodeName = "A"

function LoadModule(file)
	print("Loading controller module "..file)
	local Module = require(file)
	local ClientDisps = Module.Client or { }
	local NodeDisps = Module.Node or { }
	local Ops = Module.Operations or { }

	for k,v in pairs(ClientDisps) do
		if ClientDataDispatchers[k] then
			print ("Overwriting client dispatcher "..k)
		end
		ClientDataDispatchers[k] = v
	end
	for k,v in pairs(NodeDisps) do
		if NodeDataDispatchers[k] then
			print ("Overwriting node dispatcher "..k)
		end
		NodeDataDispatchers[k] = v
	end
	for k,v in pairs(Ops) do
		if Operations[k] then
			print ("Overwriting operation "..k)
		end
		Operations[k] = v
	end

	-- WARNING
	-- the code below allows arbitrary code to be run when loading a module
	if Module.OnLoad then
		assert(loadstring(Module.OnLoad))()
	end
end

-- Functions able to look at the 'kind' of packet
-- and resolve it
ClientDataDispatchers = { }
NodeDataDispatchers = {	}
-- Functions which can be called to execute specific
-- behavior
Operations = { }

LoadModule("controller_module_basic")
LoadModule("controller_module_remote")

--

function sleep(sec)
	socket.select(nil, nil, sec)
end

-- funkcja, ktora podmieniamy domyslna funkcje klienta
function MyProcessData (self)
	local packet = self:_FetchData()

	if packet.timestamp then
		local Delay = socket.gettime() - packet.timestamp
		--print ("Delay (app->ctrl) = "..Delay)
	else
		--print ("Time info unavailable")
	end

	if ClientDataDispatchers[packet.kind] then
		ClientDataDispatchers[packet.kind](self, packet)
	else
		print("Data dispatcher not present for client comm. : "..packet.kind)
	end
end

function OtherControllerProcessData(self)
	local packet = self:_FetchData()

	if NodeDataDispatchers[packet.kind] then
		NodeDataDispatchers[packet.kind](self, packet)
	else
		print("Data dispatcher not present for node comm. : "..packet.kind)
	end
end

function SendToAllNodes (x)
	for i,v in pairs(nodes) do
		print ("Sending "..tostring(x).." to "..v.id)
		v:fancySend(x)
	end
end

function SendToAllBut (x, one)
	--print ("Sending "..tostring(x).." to all but "..tostring(one))
	for i,v in ipairs(nodes) do
		if i ~= one then
			--print("\tSending to "..tostring(i))
			v.connection:send(x)
		end
	end
end

function SendToOne (x, one)
	nodes(one).connection:send(x)
end

function AddNewApp (connection, dataprocess)
	-- create coroutine
	C = Client:new()
	C.connection = connection
	C.connection:settimeout(0)
	C.alive = true

	appCount = appCount + 1

	C.id = NodeName.."_"..(appCount)

	C.sockets = { }
	if dataprocess then
		C.ProcessData = dataprocess
	end
	apps[C.id] = C
end

function AddNewNode (connection, dataprocess)
	C = Client:new()
	C.connection = connection
	C.connection:settimeout(0)
	C.connection:setoption('tcp-nodelay', true)
	C.alive = true

	nodeCount = nodeCount + 1
	C.id = "Ctrl_"..(nodeCount)
	C.sockets = { }
	if dataprocess then
		C.ProcessData = dataprocess
	end
	nodes[C.id] = C
	C:fancySend{
		kind = "identification",
		data = NodeName
	}
end

function RenameNode (old_id, new_id)
	local Replace = nodes[new_id] and true or false

	nodes[new_id] = nodes[old_id]
	nodes[old_id] = nil
	nodes[new_id].id = new_id

	return Replace
end

-- HOST
------------------------------------------------------------
function host(port, grid_serve_port)
	-- Connections from apps
	local server = assert(socket.bind ("*", port))
	server:settimeout(0)
	local ip, port = server:getsockname()
	print ("Listening on "..ip..":"..port.."\n")

	-- Connections from other controllers
	local grid_server
	if grid_serve_port then
		print("Opening grid server")
		grid_server = assert(socket.bind ("*", grid_serve_port))
		grid_server:settimeout(0)
	end

	while true do
		local app = server:accept()
		if app then
			local cip = app:getpeername()
			print ("New app connected : ",cip)

			AddNewApp(app, MyProcessData)
		end
		if grid_server then
			local node = grid_server:accept()
			if node then
				local node_ip = node:getpeername()
				print ("New node connected : ",node_ip)

				AddNewNode(node, OtherControllerProcessData)
			end
		end

		-- Run all tasks
		for _,task in pairs(Tasks) do
			task()
		end

		-- Let the CPU do something else
		--sleep(0.001)
		--print (socket.gettime())
		--print (hrt.clock())
	end
end

-- OPERATIONS
------------------------------------------------------------
function Operations.ConnectToOtherNode (ip)
	con = socket.tcp()
	local ok, err = con:connect(ip, 5555)
	if not ok then
		print ("Connection to other node failed")
	else
		print ("Connected to other node")
		con:settimeout(0)
		AddNewNode(con, OtherControllerProcessData)
	end
end
function Operations.SerializeApp (app_id)
	if not apps[app_id] then
		print ("Serialize : No app with id "..app_id.." found!")
		return
	end
	print ("Serializing : "..app_id)
	apps[app_id]:fancySend { kind = "serialize" }
end
function Operations.MoveApp (app_id, node_id)
	print ("Moving app : "..app_id)
	if not apps[app_id] then
		print ("Move : No app with id "..app_id.." found!")
		return
	end
	if not apps[app_id].SerializeData then
		--print ("No app serialization data found. Serialize first!")
		Operations.SerializeApp(app_id)
		apps[app_id].scheduledToMove = node_id
		return
	end

	if not nodes[node_id] then
		print ("Move : No node with id "..node_id.." found!")
		return
	end

	-- Sending information to target node
	nodes[node_id]:fancySend {
		kind = "app_run",
		data = {
			--TEMP!!!
			name="snake",
			id=app_id,
			serializeData = apps[app_id].SerializeData,
		}
	}
	apps[app_id] = nil
	foreignApps[app_id] = node_id
end
function Operations.RunApp(name, id, serializeData)
	local appPath = appCatalog[name]
	if appPath then
		print ("Running application : "..name)
		if id then
			appCache[id] = serializeData
			--os.execute("lua "..appPath.. " "..id.." &")
		else
			--reserve id for app
			appCount = appCount+1
			id = NodeName.."_"..(appCount)
		end

		local osCommand
		if operatingSystem == "windows" then
			osCommand = 'start "" /B lua '..appPath.." "..id
		else
			osCommand = "lua "..appPath.." "..id.."& echo $! > /tmp/"..id..".pid"
		end

		print ("Executing : "..osCommand)
		os.execute(osCommand)
	else
		print ("Unknown application : "..name)
	end
end
function Operations.KillApp(app_id)
	if not apps[app_id] then
		print ("No app with id "..app_id.." currently present")
	else
		os.execute("kill `cat /tmp/"..app_id..".pid`")
		apps[app_id] = nil
	end
end
function Operations.SuspendApp(app_id)
	if not apps[app_id] then
		print ("No app with id "..app_id.." currently present")
	else
		apps[app_id]:fancySend{
			kind="suspend"
		}
	end
end
function Operations.UnsuspendApp(app_id)
	if not apps[app_id] then
		print ("No app with id "..app_id.." currently present")
	else
		apps[app_id]:fancySend{
			kind="unsuspend"
		}
	end
end

-- TASKS
-- Note: these are operations that are put in Tasks table
-- and are periodically ran in the main loop
function Operations.UpdateAllNodes()
	for i,v in pairs (nodes) do
		local alive = v:Update()
		if not alive then --kasujemy polaczenie
			nodes[i] = nil
		end
	end
end
function Operations.UpdateAllApps()
	for i,v in pairs (apps) do
		local alive = v:Update()

		if not alive then --kasujemy polaczenie
			apps[i] = nil
		end
	end
end
function Operations.SendBufferedQueries()
	while QueryBuffer:size() > 0 do
		print ("Sending Query To All Nodes")
		local status = false
		local Query = QueryBuffer:popleft()
		--TEMP
		SendToAllNodes(Query)
	end
end

-- Helpers
-- (And I mean like, for real)
function AddTask (x)
	table.insert(Tasks, x)
end

-- Startujemy controller
function main()
	local arg_p = getopt(arg, "")
	-- Komunikacja z innymi kontrolerami w ramach clouda
	if arg_p["s"] then
		grid_serve = true
	end
	NodeName = arg_p["name"] or "Default"

	-- start-up connections
	local StartConns = arg_p["connect"] or ""
	for ip in string.gmatch(StartConns, "[^;\s][^\;]*[^;\s]*") do
		Operations.ConnectToOtherNode(ip)
	end

	AddTask(Operations.UpdateAllNodes)
	AddTask(Operations.UpdateAllApps)
	AddTask(Operations.SendBufferedQueries)

	-- Komunikacja z aplikacjami
	local port = 5000
	host(port, grid_serve and 5555 or nil)
end

main()
