--[[
	TAS CORE (used by the TAS editor in tas.lua)

	Runs the game one fixed frame (1/60 of a second) at a time with input taken from the TAS, and saves and loads the
	whole game state so any frame can be gone back to, the same way FCEUX's TAS Editor does it:

	* A savestate is a picture of every table reachable from the globals (and the local variables of every function
	  reachable from them, its upvalues), plus the state of every random generator. Loading one puts every table back
	  as it was, in place, so code that kept a reference to a table still sees the right one.
	* While the TAS runs the game ("game context"), the game sees the TAS's input instead of the real keyboard and
	  mouse, a clock that moves exactly 1/60 of a second a frame, one random generator the TAS controls, and can't
	  write files, quit, change the window or show a loading overlay the slow way.
	* Frame f's input is used while going from frame f to frame f+1, like FCEUX: the state "at frame f" is the state
	  before frame f's input.
]]

tascore = {}
local C = tascore

C.FPS = 60
C.DT = 1/60
C.TIMEBASE = 1000 --the clock the game sees at frame 0

--globals that are never saved or loaded: libraries, and the TAS itself (every global starting with "tas")
local SKIPGLOBALS = {
	love = true, string = true, table = true, math = true, io = true, os = true, coroutine = true, debug = true,
	package = true, bit = true, jit = true, utf8 = true, ffi = true, _G = true, arg = true, _VERSION = true,
}
local function skipglobal(k)
	return SKIPGLOBALS[k] or (type(k) == "string" and k:sub(1, 3) == "tas")
end
C.skipglobal = skipglobal

------------------------------------------------------------
-- savestates
------------------------------------------------------------

local fnups = setmetatable({}, {__mode = "k"}) --function -> how many upvalues to save (0: none, or not a Lua function)
local udkind = setmetatable({}, {__mode = "k"}) --userdata -> "rng", "batch" or false

local function upvaluecount(f)
	local n = fnups[f]
	if n == nil then
		local info = debug.getinfo(f, "Su")
		if info.what == "Lua" and not tostring(info.source):match("[@/\\]tas%w*%.lua$") then
			n = info.nups or 0
		else
			n = 0
		end
		fnups[f] = n
	end
	return n
end

local function userdatakind(u)
	local k = udkind[u]
	if k == nil then
		k = false
		local ok, isrng = pcall(function() return u:typeOf("RandomGenerator") end)
		if ok and isrng then
			k = "rng"
		end
		udkind[u] = k
	end
	return k
end

--takes a savestate. prev (optional): an earlier savestate, whose copies are shared when a table hasn't changed since,
--so tables that never change (graphics, quads, text...) only take memory once
function C.save(prev)
	local tbls, cons, mts = {}, {}, {}
	local nt = 0
	local upf, upi, upv = {}, {}, {}
	local nu = 0
	local rngs, rngstates = {}, {}
	local seen, upseen = {}, {}
	local previndex = prev and prev.index
	local index = {}

	local stack, top = {_G}, 1
	seen[_G] = true

	while top > 0 do
		local x = stack[top]
		stack[top] = nil
		top = top - 1
		if type(x) == "table" then
			local c = {}
			local isg = (x == _G)
			for k, v in next, x do
				if not (isg and skipglobal(k)) then
					c[k] = v
					local tk = type(k)
					if (tk == "table" or tk == "function") and not seen[k] then
						seen[k] = true
						top = top + 1
						stack[top] = k
					end
					local tv = type(v)
					if (tv == "table" or tv == "function") and not seen[v] then
						seen[v] = true
						top = top + 1
						stack[top] = v
					elseif tv == "userdata" and not seen[v] then
						seen[v] = true
						if userdatakind(v) == "rng" then
							rngs[#rngs+1] = v
							rngstates[#rngstates+1] = v:getState()
						end
					end
				end
			end
			local mt = debug.getmetatable(x)
			if mt and not seen[mt] then
				seen[mt] = true
				top = top + 1
				stack[top] = mt
			end
			--a table that hasn't changed since prev shares prev's copy
			if previndex then
				local pi = previndex[x]
				if pi then
					local pc = prev.cons[pi]
					local same = true
					local count = 0
					for k, v in next, c do
						if pc[k] ~= v then
							same = false
							break
						end
						count = count + 1
					end
					if same then
						for _ in next, pc do
							count = count - 1
							if count < 0 then
								same = false
								break
							end
						end
						if same and count == 0 then
							c = pc
						end
					end
				end
			end
			nt = nt + 1
			tbls[nt], cons[nt], mts[nt] = x, c, mt
			index[x] = nt
		else --a function: its upvalues
			local n = upvaluecount(x)
			for i = 1, n do
				local id = debug.upvalueid(x, i)
				if not upseen[id] then
					upseen[id] = true
					local _, v = debug.getupvalue(x, i)
					nu = nu + 1
					upf[nu], upi[nu], upv[nu] = x, i, v
					local tv = type(v)
					if (tv == "table" or tv == "function") and not seen[v] then
						seen[v] = true
						top = top + 1
						stack[top] = v
					elseif tv == "userdata" and not seen[v] then
						seen[v] = true
						if userdatakind(v) == "rng" then
							rngs[#rngs+1] = v
							rngstates[#rngstates+1] = v:getState()
						end
					end
				end
			end
		end
	end

	return {
		tbls = tbls, cons = cons, mts = mts, n = nt, index = index,
		upf = upf, upi = upi, upv = upv, nu = nu,
		rngs = rngs, rngstates = rngstates,
		gen = C.gen and C.gen:getState(),
		--state that lives in LÖVE instead of Lua
		background = {love.graphics.getBackgroundColor()},
		font = love.graphics.getFont(),
		keyrepeat = love.keyboard.hasKeyRepeat(),
		input = C.lastinput, --the input the game last saw (for press and release events)
		frame = C.frame,
	}
end

--puts every table, upvalue and random generator back the way the savestate has them
function C.load(s)
	local tbls, cons, mts = s.tbls, s.cons, s.mts
	for i = 1, s.n do
		local x, c = tbls[i], cons[i]
		if x == _G then
			for k in next, x do
				if c[k] == nil and not skipglobal(k) then
					rawset(x, k, nil)
				end
			end
		else
			for k in next, x do
				if c[k] == nil then
					rawset(x, k, nil)
				end
			end
		end
		for k, v in next, c do
			rawset(x, k, v)
		end
		if debug.getmetatable(x) ~= mts[i] then
			debug.setmetatable(x, mts[i])
		end
	end
	local upf, upi, upv = s.upf, s.upi, s.upv
	for i = 1, s.nu do
		debug.setupvalue(upf[i], upi[i], upv[i])
	end
	for i, r in ipairs(s.rngs) do
		r:setState(s.rngstates[i])
	end
	if s.gen and C.gen then
		C.gen:setState(s.gen)
	end
	C.lastinput = s.input
	C.frame = s.frame
	if s.background then
		love.graphics.setBackgroundColor(unpack(s.background))
	end
	if s.font then
		love.graphics.setFont(s.font)
	end
	if s.keyrepeat ~= nil then
		love.keyboard.setKeyRepeat(s.keyrepeat)
	end
	--things that live outside of Lua and have to be rebuilt from the state
	love.audio.stop()
	if gamestate == "game" and updatespritebatch then
		pcall(updatespritebatch)
	end
end

------------------------------------------------------------
-- input
------------------------------------------------------------

--a frame's input: {k = {key = true...}, x = game pixels or nil (same as the frame before), y, b = {[1] = true...}, w = wheel}
function C.emptyinput()
	return {k = {}}
end

local function normalkey(k)
	if k == " " then
		return "space"
	end
	return k
end
C.normalkey = normalkey

C.lastinput = {k = {}, x = 0, y = 0, b = {}} --what the game saw last frame (mouse position filled in)

--the mouse position frame i uses: its own, or the last one set before it
function C.mouseat(frames, i)
	local x, y
	for j = i, 1, -1 do
		local f = frames[j]
		if f then
			if x == nil and f.x then
				x = f.x
			end
			if y == nil and f.y then
				y = f.y
			end
			if x and y then
				break
			end
		end
	end
	return x or 0, y or 0
end

------------------------------------------------------------
-- game context: what the game sees while the TAS runs it
------------------------------------------------------------

C.ctx = false --true while the game is running or drawing for the TAS
C.frame = 0
C.muted = false
C.canvas = nil --setCanvas() with nothing goes here while drawing the game view
C.messages = {} --things the game tried to do that the TAS stopped (shown in the editor)

local orig = {} --the real functions
C.orig = orig
local inner = {} --love's callbacks under the TAS's own (what the game would normally get)
C.inner = inner

local function message(s)
	C.messages[#C.messages+1] = s
end

local function wrapfield(tablename, t, name, fn)
	local f = t[name]
	if type(f) ~= "function" then
		return
	end
	orig[tablename .. "." .. name] = f
	t[name] = function(...)
		if C.ctx then
			return fn(f, ...)
		end
		return f(...)
	end
end

local function frameinput()
	return C.lastinput
end

function C.install()
	if C.installed then
		return
	end
	C.installed = true

	--keyboard
	wrapfield("keyboard", love.keyboard, "isDown", function(f, ...)
		local k = frameinput().k
		for i = 1, select("#", ...) do
			local key = select(i, ...)
			if type(key) == "table" then
				for _, kk in ipairs(key) do
					if k[normalkey(kk)] then
						return true
					end
				end
			elseif k[normalkey(key)] then
				return true
			end
		end
		return false
	end)
	wrapfield("keyboard", love.keyboard, "isScancodeDown", function(f, ...)
		local k = frameinput().k
		for i = 1, select("#", ...) do
			local sc = select(i, ...)
			local key = orig["keyboard.getKeyFromScancode"] and orig["keyboard.getKeyFromScancode"](sc) or sc
			if k[normalkey(key)] then
				return true
			end
		end
		return false
	end)
	orig["keyboard.getKeyFromScancode"] = love.keyboard.getKeyFromScancode

	--mouse: the game sees game pixels times the scale, like the window's own pixels
	local function mx()
		return (frameinput().x or 0)*scale
	end
	local function my()
		return (frameinput().y or 0)*scale
	end
	wrapfield("mouse", love.mouse, "getX", function() return mx() end)
	wrapfield("mouse", love.mouse, "getY", function() return my() end)
	wrapfield("mouse", love.mouse, "getPosition", function() return mx(), my() end)
	wrapfield("mouse", love.mouse, "isDown", function(f, ...)
		local b = frameinput().b
		for i = 1, select("#", ...) do
			local n = select(i, ...)
			if mousebuttonnum then
				n = mousebuttonnum(n)
			end
			if b[n] then
				return true
			end
		end
		return false
	end)
	for _, name in ipairs({"setPosition", "setGrabbed", "setVisible", "setRelativeMode", "setCursor", "setX", "setY"}) do
		wrapfield("mouse", love.mouse, name, function() end)
	end

	--clock: exactly 1/60 of a second a frame
	wrapfield("timer", love.timer, "getTime", function() return C.TIMEBASE + C.frame*C.DT end)
	wrapfield("timer", love.timer, "getDelta", function() return C.DT end)
	wrapfield("timer", love.timer, "getFPS", function() return C.FPS end)
	wrapfield("timer", love.timer, "sleep", function() end)
	wrapfield("os", os, "time", function(f, t)
		if t then
			return f(t)
		end
		return (C.epoch or 0) + math.floor(C.frame*C.DT)
	end)
	wrapfield("os", os, "clock", function() return C.frame*C.DT end)
	wrapfield("os", os, "date", function(f, format, t)
		return f(format, t or ((C.epoch or 0) + math.floor(C.frame*C.DT)))
	end)

	--random numbers: one generator the TAS saves with every frame. What each frame drew is kept (C.rngout)
	local function record(v)
		local out = C.rngout
		if out and #out < 256 then
			out[#out+1] = v
		end
		return v
	end
	wrapfield("math", math, "random", function(f, ...)
		return record(C.gen:random(...))
	end)
	wrapfield("math", math, "randomseed", function(f, s) C.gen:setSeed(math.floor(tonumber(s) or 0)) end)
	wrapfield("lovemath", love.math, "random", function(f, ...) return record(C.gen:random(...)) end)
	wrapfield("lovemath", love.math, "randomNormal", function(f, ...) return record(C.gen:randomNormal(...)) end)
	wrapfield("lovemath", love.math, "setRandomSeed", function(f, ...) C.gen:setSeed(...) end)
	wrapfield("lovemath", love.math, "getRandomSeed", function(f) return C.gen:getSeed() end)
	wrapfield("lovemath", love.math, "setRandomState", function(f, s) C.gen:setState(s) end)
	wrapfield("lovemath", love.math, "getRandomState", function(f) return C.gen:getState() end)

	--files: the game can read, but nothing it writes is kept (a TAS never touches the real save data)
	for _, name in ipairs({"write", "append", "remove", "createDirectory"}) do
		wrapfield("filesystem", love.filesystem, name, function() return true end)
	end
	wrapfield("filesystem", love.filesystem, "newFile", function(f, path, mode)
		if mode and mode ~= "r" then
			return nil, "the TAS doesn't let the game write files"
		end
		return f(path, mode)
	end)
	wrapfield("io", io, "open", function(f, path, mode)
		if mode and mode:find("[wa+]") then
			return nil, "the TAS doesn't let the game write files"
		end
		return f(path, mode)
	end)

	--window and program
	for _, name in ipairs({"setMode", "updateMode", "setFullscreen", "setTitle", "setIcon", "setVSync", "setPosition", "maximize", "minimize", "restore"}) do
		wrapfield("window", love.window, name, function() return true end)
	end
	wrapfield("event", love.event, "quit", function() message("the game tried to quit") end)
	wrapfield("event", love.event, "push", function(f, e, ...)
		if e == "quit" then
			message("the game tried to quit")
			return
		end
		return f(e, ...)
	end)
	wrapfield("system", love.system, "openURL", function() return true end)
	wrapfield("graphics", love.graphics, "present", function() end)
	wrapfield("graphics", love.graphics, "setCanvas", function(f, ...)
		if C.canvas and (select("#", ...) == 0 or (...) == nil) then
			return f({C.canvas, stencil = true})
		end
		return f(...)
	end)

	--sound: silent while seeking
	wrapfield("audio", love.audio, "setVolume", function(f, v)
		C.wantedvolume = v
		if not C.muted then
			return f(v)
		end
	end)
	for _, name in ipairs({"play"}) do
		wrapfield("audio", love.audio, name, function(f, ...)
			if not C.muted then
				return f(...)
			end
		end)
	end
end

--love's callbacks as they are now, under the TAS's own hooks: running them runs the game normally
function C.captureinner()
	for _, name in ipairs({"update", "keypressed", "keyreleased", "textinput", "mousepressed", "mousereleased",
		"mousemoved", "wheelmoved", "focus", "joystickpressed", "joystickreleased", "joystickaxis", "joystickhat",
		"gamepadpressed", "gamepadreleased", "gamepadaxis", "filedropped", "directorydropped", "resize", "visible",
		"touchpressed", "touchreleased", "touchmoved", "draw", "quit"}) do
		inner[name] = love[name]
	end
end

--runs fn in the game context
function C.run(fn, ...)
	local was = C.ctx
	C.ctx = true
	tasstepping = true
	local results = {xpcall(fn, debug.traceback, ...)}
	C.ctx = was
	tasstepping = was or nil
	if not results[1] then
		return false, results[2]
	end
	return true
end

function C.setmuted(m)
	if m == C.muted then
		return
	end
	C.muted = m
	if m then
		orig["audio.setVolume"](0)
	else
		orig["audio.setVolume"](C.wantedvolume or volume or 1)
	end
end

------------------------------------------------------------
-- stepping
------------------------------------------------------------

local MOUSEBUTTONS = {1, 2, 3}

--sends the game the events that take it from the last frame's input to this one's, then runs one frame
local function stepbody(input, x, y)
	local last = C.lastinput
	local now = {k = input.k or {}, x = x, y = y, b = input.b or {}}
	--releases first, then presses (the order keys go up and down in within a frame isn't recorded)
	for key in pairs(last.k) do
		if not now.k[key] then
			C.lastinput = {k = now.k, x = last.x, y = last.y, b = last.b}
			if inner.keyreleased then
				inner.keyreleased(key, key)
			end
		end
	end
	for key in pairs(now.k) do
		if not last.k[key] then
			C.lastinput = {k = now.k, x = last.x, y = last.y, b = last.b}
			if inner.keypressed then
				local sc = key
				pcall(function() sc = love.keyboard.getScancodeFromKey(key) end)
				inner.keypressed(key, sc, false)
			end
		end
	end
	C.lastinput = now
	if (x ~= last.x or y ~= last.y) and inner.mousemoved then
		inner.mousemoved(x*scale, y*scale, (x - (last.x or 0))*scale, (y - (last.y or 0))*scale, false)
	end
	for _, b in ipairs(MOUSEBUTTONS) do
		if last.b[b] and not now.b[b] and inner.mousereleased then
			inner.mousereleased(x*scale, y*scale, b, false, 1)
		elseif now.b[b] and not last.b[b] and inner.mousepressed then
			inner.mousepressed(x*scale, y*scale, b, false, 1)
		end
	end
	if input.w and input.w ~= 0 and inner.wheelmoved then
		inner.wheelmoved(0, input.w)
	end
	inner.update(C.DT)
end

--runs frame C.frame with input (and the mouse position x, y in game pixels). Returns false and an error if the game
--broke. The random numbers it drew are in C.rngout afterwards
function C.step(input, x, y)
	C.rngout = {}
	local ok, err = C.run(stepbody, input, x, y)
	C.frame = C.frame + 1
	return ok, err
end

--what's worth showing (and checking) about a frame's state: a small table
function C.summary()
	local s = {g = gamestate}
	if gamestate == "game" and objects and objects["player"] then
		s.p = {}
		for i, p in pairs(objects["player"]) do
			if type(i) == "number" and type(p) == "table" then
				s.p[i] = {
					x = p.x and math.floor(p.x*10000 + 0.5)/10000,
					y = p.y and math.floor(p.y*10000 + 0.5)/10000,
					sx = p.speedx and math.floor(p.speedx*10000 + 0.5)/10000,
					sy = p.speedy and math.floor(p.speedy*10000 + 0.5)/10000,
					size = p.size,
					dead = p.dead or nil,
				}
			end
		end
		s.cx = xscroll and math.floor(xscroll*10000 + 0.5)/10000
		s.cy = yscroll and math.floor(yscroll*10000 + 0.5)/10000
		s.w, s.l = marioworld, mariolevel
	end
	s.rng = C.gen and C.gen:getState()
	return s
end

--whether two summaries are the same (for spotting a desync)
function C.samesummary(a, b)
	if not a or not b then
		return true
	end
	if a.g ~= b.g or a.rng ~= b.rng or a.cx ~= b.cx or a.cy ~= b.cy then
		return false
	end
	local pa, pb = a.p or {}, b.p or {}
	for i, p in pairs(pa) do
		local q = pb[i]
		if not q or q.x ~= p.x or q.y ~= p.y or q.sx ~= p.sx or q.sy ~= p.sy then
			return false
		end
	end
	return true
end

------------------------------------------------------------
-- drawing the game
------------------------------------------------------------

--draws the game as it is now into its own canvas (width*16*scale by height*16*scale) and returns it
function C.drawgame(target)
	local w, h = width*16*scale, height*16*scale
	if not target or target:getWidth() ~= w or target:getHeight() ~= h then
		target = love.graphics.newCanvas(w, h)
		target:setFilter("nearest", "nearest")
	end
	love.graphics.push("all")
	C.canvas = target
	local ok, err = C.run(function()
		orig["graphics.setCanvas"]({target, stencil = true})
		love.graphics.clear(love.graphics.getBackgroundColor())
		love.graphics.origin()
		love.graphics.setScissor()
		lovedraw()
	end)
	C.canvas = nil
	love.graphics.pop()
	orig["graphics.setCanvas"]()
	return target, ok, err
end