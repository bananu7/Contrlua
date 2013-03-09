-- Snake Client
package.path = "snake/?.lua;../?.lua;"..package.path
require"app"
require"display_grid"
A = App:new()
A:initialize()

function A.dataDispatchers.socketdata (self, data)
	local from = data.from
	local snake = data.data

	if not snake then
		print("Malicious data. WTF?")
	else
		for x = 0, 99 do
			grid[x] = false
		end
		for _,v in ipairs(snake) do
			--io.write("["..v.X..", "..v.Y.."]")
			grid[v.X * 10 + v.Y] = true
		end

		io.write("\n")
	end
end

timer = iup.timer{time=10}
function timer:action_cb()
  iup.Update(cnv)
end

S = A:createSocket("SNAKE_APP_ID")
local SentSnakeInfo = false

function MyAction ()
	A:getData()
	A:processData()

	if not SentSnakeInfo and A.id then
		SentSnakeInfo = true
		S:send("I want to watch snake!")
	end
	-- sleep synchronized with server uses socket buffer as buffer
	-- possibly prone to overflows, should be rewritten into our own buffer
	sleep(0.05)
end

timer.run = "YES"

iup.MainLoop()

-- //Display Window
