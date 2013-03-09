---------------------------
-- this module provide a function
-- HiResTimer.clock() which returns a high resolution timer
---------------------------
module("HiResTimer",package.seeall)

--
-- take the alien module
--
require"alien"

--
-- get the kernel dll
--
local kernel32=alien.load("kernel32.dll")

--
-- get dll functions
--
local QueryPerformanceCounter=kernel32.QueryPerformanceCounter
QueryPerformanceCounter:types{ret="int",abi="stdcall","pointer"}
local QueryPerformanceFrequency=kernel32.QueryPerformanceFrequency
QueryPerformanceFrequency:types{ret="int",abi="stdcall","pointer"}

--------------------------------------------
--- utility : convert a long to an unsigned long value
-- (because alien does not support longlong nor ulong)
--------------------------------------------
local function lu(long)
	return long<0 and long+0x80000000+0x80000000 or long
end

--------------------------------------------
--- Query the performance frequency.
-- @return (number)
--------------------------------------------
local function qpf()
	local frequency=alien.array('long',2)
	QueryPerformanceFrequency(frequency.buffer)
	return  math.ldexp(lu(frequency[1]),0)
		    +math.ldexp(lu(frequency[2]),32)
end

--------------------------------------------
--- Query the performance counter.
-- @return (number)
--------------------------------------------
local function qpc()
	local counter=alien.array('long',2)
	QueryPerformanceCounter(counter.buffer)
	return	 math.ldexp(lu(counter[1]),0)
			+math.ldexp(lu(counter[2]),32)
end

--------------------------------------------
-- get the startup values
--------------------------------------------
local f0=qpf()
local c0=qpc()

--------------------------------------------
--- Return a hires clock
-- @return (number) elapsed seconds since load of the module
--------------------------------------------
function clock()
	local c1=qpc()
	return (c1-c0)/f0
end

return HiResTimer
