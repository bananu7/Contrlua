-- Basic snake code
package.path = "../?.lua;"..package.path
local List = require"simple_list"	

Vector2 = { X = 0, Y = 0 }
function Vector2:new(x, y)
	o = { }
	setmetatable(o, self)
	self.__index = self
	o.X = x or 0
	o.Y = y or 0
	return o
end

Snake = {
	direction = "up",
	ccw = false
 }
function Snake:new(o)
	o = o or { }
	setmetatable(o, self)
	self.__index = self
	o.Data = List:new()
	return o
end

function Snake:init ()
	self.Data:pushright(Vector2:new(2, 2))
	self.Data:pushright(Vector2:new(2, 3))
	self.Data:pushright(Vector2:new(2, 4))
	self.Data:pushright(Vector2:new(2, 5))
	self.Data:pushright(Vector2:new(2, 6))
	self.direction = "up"
end
	
function Snake:sendState(socket)
	local temp = { }
	for i = self.Data.first, self.Data.last do
		table.insert(temp, self.Data[i])
	end
	socket:send(temp)
end

function Snake:move()
	if (self.Data:size() > 0) then
		local head = self.Data[self.Data.first]
		if self.direction == "up" then
			if head.Y == 0 then
				self.direction = "right"
			end
		elseif self.direction == "down" then
			if head.Y == 9 then
				self.direction = "left"
			end
		elseif self.direction == "left" then
			if head.X == 0 then
				self.direction = "up"
			end
		elseif self.direction == "right" then
			if head.X == 9 then
				self.direction = "down"
			end
		end
		if self.direction == "up" then
			self.Data:pushleft(Vector2:new(head.X, head.Y-1))
		elseif self.direction == "down" then
			self.Data:pushleft(Vector2:new(head.X, head.Y+1))
		elseif self.direction == "left" then
			self.Data:pushleft(Vector2:new(head.X-1, head.Y))
		elseif self.direction == "right" then
			self.Data:pushleft(Vector2:new(head.X+1, head.Y))
		end
		
		self.Data:popright()
	end
end