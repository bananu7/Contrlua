Contrlua
========

Distributed application framework written in Lua

Example usage:


#Scenario 1
It shows simple app discovery thorough the network and
IPC

```
Node 1:
	TTY 1.1:
		lua controller.lua -s --name="Node_1"

	TTY 1.2: - we are using this tty to issue commands
		lua -i app_test.lua

Node 2:
	TTY 2.1:
		lua controler.lua [-s] --name="Node_2"

	TTY 2.2:
		lua -i app_test.lua
		> A:Ct([[ Operations.ConnectToOtherNode("Node_1_ip") ]])
		> S = A:createSocket("Node_1_1")
		> S:send("test data")
```

To look at results type in TTY 1.2

```Lua
	> A:getData()
```


If you can't or are not willing to open two TTYs at remote node,
you can use backdoored initialize:

```
TTY 2.3 (instead of 1.2)
	lua -i app.lua
	> A = App:new()
	> A:initialize("Node_1_ip")
	> A:getData()
```

This will cause App A_1 to run on Node 2 physically, but on Node 1
in terms of Contrlua cloud.


#Scenario 2
It shows "hot" application movement thorough the grid.
With some modifications, it's also possible to achieve "snapshots"
functionality.

```
Node 1:
	TTY 1.1:
		lua controller.lua -s --name="Node_1"

	TTY 1.2:
		lua -i app_test.lua
		> A:Ct[[ Operations.RunApp("snake", "SNAKE_APP_ID") ]]

Node 2:
	TTY 2.1
		lua controller.lua [-s] --name="Node_2" --connect="node_1_ip"

	TTY 2.2
		lua snake/snake-client.lua

```

After a while, a window with running snake should appear
To move app, type (or even better, copy):

```
	TTY 1.2:
		> A:Ct[[ Operations.MoveApp("SNAKE_APP_ID", "Node_2") ]]
```
		
If everything works as planned, you shouldn't be able to see any
erratic snake behavior; in fact, it will keep running, confirming
the app movement is pretty much in real-time.

If you aren't convinced, feel free to kill all of the processes on
node 1.
