
require( "iuplua" )
require( "app" )

A = App:new()
A:initialize(arg[1])
local SelectedApp = 0

SuspendBtn = iup.button{title="Suspend", size="50x20"}
function SuspendBtn:action()
	if SelectedApp > 0 then
		local AppName = iup.GetAttribute(AppList, SelectedApp)

		if self.title == "Suspend" then
			A:Ct("Operations.SuspendApp('"..AppName.."')")
			self.title = "Unsuspend"
		else
			A:Ct("Operations.UnsuspendApp('"..AppName.."')")
			self.title = "Suspend"
		end
	end
end

KillBtn = iup.button{title="Kill", size = "50x20"}
function KillBtn:action()
	if SelectedApp > 0 then
		local AppName = iup.GetAttribute(AppList, SelectedApp)

		A:Ct("Operations.KillApp('"..AppName.."')")
	end
end

AppList = iup.list { dropdown="YES", visible_items=5, size="120" }
function AppList:action(_, item, state)
	-- state -> 0 deselect, 1 select
	-- it's mainly for multiple-choice lists
	if state == 1 then
		--local AppIndexOnList = iup.GetAttribute(self, 'VALUE')
		--iup.Message("selected", item)
		SelectedApp = item
	end
end

RefreshAppsBtn = iup.button{title="Refresh", size="40x10"}
function RefreshAppsBtn:action()
	A:fancySend{ kind = "get_applist" }
end

tree = iup.tree{}

------------------------------------------------------------
-- LAYOUT
------------------------------------------------------------
frCt = iup.frame
{
	iup.hbox
	{
		AppList,
		RefreshAppsBtn,
		iup.fill{},
	};
	title="Choose Application"
}

fr1 = iup.frame
{
	iup.hbox
	{
		SuspendBtn,
		KillBtn,
		alignment = "ATOP"
	};
	title = "Control your app!"
}

fr3 = iup.frame
{
	tree,
	title = "Alignment = ABOTTOM"
}

dlg = iup.dialog
{
	iup.frame
	{
		iup.vbox
		{
			frCt,
			fr1,
			fr2,
			fr3
		},
	};
  title="Alignment",
  size=200
}

function dlg:close_cb()
	A:fancySend{ kind="disconnect" }
	return IUP_IGNORE
end


dlg:show()

tree.name = "Nodes"
tree.addbranch = "Local"
tree.addbranch1 = A.id

function A.dataDispatchers.applist (self, data)
	-- clear all items
	iup.SetAttribute(AppList, 'REMOVEITEM', nil)
	-- add new table
	for _,v in ipairs(data.data) do
		iup.SetAttribute(AppList, 'APPENDITEM', v)
	end
	-- select first app
	if #data.data > 0 then
		iup.SetAttribute(AppList, 'VALUE', 1)
	end
end

while true do
	A:getData()
	A:processData()
	sleep(0.001)
	local Ret = iup.LoopStep()
	if Ret ~= -2 then print(Ret) end
	if Ret == IUP_CLOSE then
		print(Ret)
		print(IUP_CLOSE)
		print ("IUP_CLOSE")
		break
	end
end

--[[if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
end]]
