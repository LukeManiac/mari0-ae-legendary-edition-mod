--OVERLAY TASKS
--Anything that shows a loading overlay (renderoverlay) and then does a lot of work (loading a level, the editor, a
--mappack, refreshing data...) now does that work in the background, a little every frame, instead of stopping the
--whole program until it's done:
--
--* Every input callback and love.update runs inside a coroutine. When renderoverlay is called inside one, it shows the
--  overlay and hands the rest of that callback to the main loop: the coroutine is resumed once a frame, in place of the
--  game's update, until it's finished.
--* While it runs, the game is frozen (no updates, input is ignored), but the window isn't: LÖVE keeps handling the
--  window's events and drawing frames, so it can be moved, closed and doesn't stop responding.
--* The work gives the frame back (overlayyield) at points inside the long loops (map tiles, enemies, animations,
--  tiles, previews...) once it's used up its share of the frame (OVERLAYTASK_BUDGET).
--* What's drawn meanwhile is a picture of the screen taken when the overlay first showed, never the half-loaded game,
--  with the overlay's text on top. A text ending in "..." animates its dots: "", ".", "..", "...", one every 0.5 seconds.
--
--LÖVE's own threads (love.thread) can't run this work: they have their own Lua state, so they can't see or change the
--game's tables, and they can't make images or canvases. Coroutines run on the main thread, where all of that works.

OVERLAYTASK_BUDGET = 0.012 --seconds of work a frame before giving the frame back
OVERLAYTASK_DOTTIME = 0.5 --seconds between each step of the "..." animation

overlaytask = nil --the work running in the background: {co = coroutine}
overlayfrozen = nil --{text, start}: the overlay drawn over the frozen picture while the work runs
overlaysnapshot = nil --the frozen picture

local handlerco = nil --the callback coroutine running right now (nil outside of one)
local resumeat = 0 --when the running coroutine was last resumed

--whether the code running now can hand the rest of its work to the main loop
function overlaytask_canyield()
	return handlerco ~= nil and coroutine.running() == handlerco
end

--whether background work is running (the game is frozen)
function overlaytask_busy()
	return overlaytask ~= nil or (overlayfrozen ~= nil and overlaytask_canyield())
end

--gives the frame back to the main loop if the background work has used up its share of it (or always, with force).
--Does nothing outside of background work, so long loops can call it whenever
function overlayyield(force)
	if not overlaytask_canyield() then
		return
	end
	if not force and not overlayfrozen then
		return --no overlay shown: the work isn't in the background, so it runs straight through like before
	end
	if force or love.timer.getTime() - resumeat >= OVERLAYTASK_BUDGET then
		coroutine.yield()
		resumeat = love.timer.getTime()
	end
end

--a text ending in "..." with its dots animated: "", ".", "..", "..." (start: when the animation began). Only the dots
--that are showing are in the text, so it's centred as it is
function overlay_animatedtext(text, start)
	text = tostring(text)
	local base
	if text:sub(-3) == "..." then
		base = text:sub(1, -4)
	elseif text:sub(-3) == "…" then
		base = text:sub(1, -4) --one character, three bytes
	else
		return text
	end
	local n = math.floor((love.timer.getTime() - start)/OVERLAYTASK_DOTTIME) % 4
	return base .. string.rep(".", n)
end

--the overlay drawn from love.draw (donotpresentgraphics): its dots start over whenever the text changes, or when it
--hasn't been drawn for a moment
local drawnoverlay = {text = nil, start = 0, last = 0}
function overlay_drawnanimatedtext(text)
	local now = love.timer.getTime()
	if drawnoverlay.text ~= text or now - drawnoverlay.last > 0.25 then
		drawnoverlay.text = text
		drawnoverlay.start = now
	end
	drawnoverlay.last = now
	return overlay_animatedtext(text, drawnoverlay.start)
end

--takes the picture that's shown while the work runs: the frame as it is now, dimmed like the overlay, without its text
function overlaytask_snapshot(donotupdate)
	overlaysnapshot = nil
	overlaytext = "" --dims the screen, no text
	love.draw(donotupdate)
	overlaytext = nil
	if (resizable or android) and canvas then
		--love.draw drew the frame into the game's canvas first: keep a copy of it
		local w, h = canvas:getDimensions()
		local copy = love.graphics.newCanvas(w, h)
		copy:setFilter("nearest", "nearest")
		love.graphics.push("all")
		love.graphics.setCanvas(copy)
		love.graphics.origin()
		love.graphics.setScissor()
		love.graphics.setShader()
		love.graphics.setBlendMode("replace", "premultiplied")
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(canvas, 0, 0)
		love.graphics.pop()
		overlaysnapshot = copy
		love.graphics.present()
	else
		--drawn straight onto the window: take a screenshot of it when it's shown
		love.graphics.captureScreenshot(function(imagedata)
			overlaysnapshot = love.graphics.newImage(imagedata)
		end)
		love.graphics.present()
	end
end

--drawn by lovedraw in place of the game while the work runs. Returns true if it drew
function overlaytask_draw()
	if not overlayfrozen then
		return false
	end
	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setScissor()
	love.graphics.setShader()
	if overlaysnapshot then
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(overlaysnapshot, 0, 0)
	else
		love.graphics.setColor(0, 0, 0, 255)
		local ww, wh = getproperwindowsize()
		love.graphics.rectangle("fill", 0, 0, ww, wh)
	end
	love.graphics.setColor(255, 255, 255, 255)
	centerprintscreen(overlay_animatedtext(overlayfrozen.text, overlayfrozen.start))
	love.graphics.pop()
	return true
end

local function finish()
	overlaytask = nil
	overlayfrozen = nil
	overlaysnapshot = nil
end

local function check(co, ok, err)
	if not ok then
		finish()
		error(debug.traceback(co, tostring(err)), 0)
	end
	if coroutine.status(co) == "dead" then
		finish()
		return false
	end
	return true
end

--runs one more piece of the background work (the main loop calls this in place of love.update)
local function resume()
	local co = overlaytask.co
	handlerco = co
	resumeat = love.timer.getTime()
	local ok, err = coroutine.resume(co)
	handlerco = nil
	check(co, ok, err)
end

--callbacks that keep working while the game is frozen: the window's own events
local PASSTHROUGH = {quit = true, resize = true, visible = true}

local function wrap(name)
	local f = love[name]
	if type(f) ~= "function" then
		return
	end
	love[name] = function(...)
		if PASSTHROUGH[name] then
			return f(...) --never in the background: quit has to finish before the window closes
		end
		if overlaytask then
			if name == "update" then
				resume()
			end
			return --frozen: input is ignored
		end
		if handlerco then
			return f(...) --called from inside another callback (android buttons, the mouse wheel...): part of that one
		end
		local co = coroutine.create(f)
		handlerco = co
		resumeat = love.timer.getTime()
		local results = {coroutine.resume(co, ...)}
		handlerco = nil
		if check(co, results[1], results[2]) then
			--renderoverlay handed the rest of this callback to the main loop
			overlaytask = {co = co}
			return
		end
		return unpack(results, 2)
	end
end

local CALLBACKS = {
	"update", "keypressed", "keyreleased", "textinput", "mousepressed", "mousereleased", "mousemoved", "wheelmoved",
	"filedropped", "directorydropped", "focus", "joystickpressed", "joystickreleased", "joystickaxis", "joystickhat",
	"gamepadpressed", "gamepadreleased", "gamepadaxis", "joystickadded", "joystickremoved",
	"touchpressed", "touchreleased", "touchmoved", "resize", "visible", "quit",
}

--wraps love's callbacks (once love.load has set them all up)
function overlaytask_install()
	if overlaytask_installed then
		return
	end
	overlaytask_installed = true
	for _, name in ipairs(CALLBACKS) do
		wrap(name)
	end
end