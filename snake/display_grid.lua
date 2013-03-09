require("iuplua")
require("iupluagl")
require("luagl")
require("luaglu")

iup.key_open()

cnv = iup.glcanvas{buffer="DOUBLE", rastersize = "640x480"}

grid = { }
for x = 0, 99 do
	grid[x] = true
end

function cnv:resize_cb(width, height)
  iup.GLMakeCurrent(self)
  gl.Viewport(0, 0, width, height)

  gl.MatrixMode('PROJECTION')   -- Select The Projection Matrix
  gl.LoadIdentity()             -- Reset The Projection Matrix

  if height == 0 then           -- Calculate The Aspect Ratio Of The Window
    height = 1
  end

  --glu.Perspective(80, width / height, 1, 5000)
  gl.Ortho(0, 100, 0, 100, -1, 1)

  gl.MatrixMode('MODELVIEW')    -- Select The Model View Matrix
  gl.LoadIdentity()             -- Reset The Model View Matrix
end

function Render(data)
	local SizeX = 10
	local SizeY = 10
	local PixSizeX = 10
	local PixSizeY = 10
	gl.Begin('QUADS')
	for x = 0, SizeX-1 do
		for y = 0, SizeY-1 do
			if data[x * SizeY + y] then
				gl.Color(1, 0, 0)
			else
				gl.Color(0, 1, 0)
			end
			gl.Vertex(x * PixSizeX, y * PixSizeY)
			gl.Vertex((x+1) * PixSizeX, y * PixSizeY)
			gl.Vertex((x+1) * PixSizeX, (y+1) * PixSizeY)
			gl.Vertex(x * PixSizeX, (y+1) * PixSizeY)
		end
	end
	gl.End()
end

function MyAction()
end

function cnv:action(x, y)
  iup.GLMakeCurrent(self)
  gl.Clear('COLOR_BUFFER_BIT,DEPTH_BUFFER_BIT') -- Clear Screen And Depth Buffer

  MyAction()
  Render(grid)

  iup.GLSwapBuffers(self)
end

function cnv:k_any(c)
  if c == iup.K_q or c == iup.K_ESC then
    return iup.CLOSE
  elseif c == iup.K_F1 then
    if fullscreen then
      fullscreen = false
      dlg.fullscreen = "No"
    else
      fullscreen = true
      dlg.fullscreen = "Yes"
    end
    iup.SetFocus(cnv)
  end
end

function cnv:map_cb()
  iup.GLMakeCurrent(self)
  gl.ShadeModel('SMOOTH')            -- Enable Smooth Shading
  gl.ClearColor(0, 0, 0, 1.0)        -- Black Background
  --gl.ClearDepth(1.0)                 -- Depth Buffer Setup
  --gl.Enable('DEPTH_TEST')            -- Enables Depth Testing
  --gl.DepthFunc('LEQUAL')             -- The Type Of Depth Testing To Do
  gl.Enable('COLOR_MATERIAL')
  --gl.Hint('PERSPECTIVE_CORRECTION_HINT','NICEST')
end

-- Display Window
dlg = iup.dialog{cnv; title="ADVA OS Graphical Snake Client"}

dlg:show()
cnv.rastersize = nil -- reset minimum limitation

