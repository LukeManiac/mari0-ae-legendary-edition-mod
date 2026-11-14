--splitscreen.lua: everything related to splitscreen
--(the splitscreenmultiplayer viewports, and the old scrolling splitscreen in updatesplitscreen)

--SPLIT SCREEN MULTIPLAYER (SPLITSCREENISBACK, set by the "splitscreenmultiplayer" nitpick)
splitcamx = {}
splitcamy = {}
splitscreenfade = {}
splitscreencanvases = {}
splitscreenwasactive = false
splitscreenfadetime = 0.8
--all of these are "ease out", one gets picked at random every time a player dies or respawns
splitscreencurves = {
	function(t) return 1-(1-t)^2 end, --quad
	function(t) return 1-(1-t)^3 end, --cubic
	function(t) return 1-(1-t)^4 end, --quart
	function(t) return 1-(1-t)^5 end, --quint
	function(t) return math.sin(t*math.pi/2) end, --sine
	function(t) if t >= 1 then return 1 end return 1-2^(-10*t) end, --expo
	function(t) return math.sqrt(1-(t-1)^2) end, --circ
}

--a minigame can pick which players get a viewport (splitscreenviewplayers = {1, 3}, a single one is fine too)
--and who a viewport follows (splitscreenviewtarget(view) returns a player object, or nil for the viewport's own player)
splitscreenviewplayers = nil
splitscreenviewtarget = nil
splitscreenviewhud = nil --function(view index, view, player number), drawn after the lives of a viewport
--a change of splitscreenviewplayers made with splitscreen_setviewplayers: the viewports move and resize into the new layout
--{from = {[player number] = {x, y, w, h, mul}}, t = 0 to 1, curve = a motion curve name}
splitscreenlayoutanim = nil
splitscreenlayouttime = 0.5

function splitscreen_viewcount()
	if splitscreenviewplayers then
		return #splitscreenviewplayers
	end
	return players or 0
end

--the player number a viewport belongs to
function splitscreen_viewplayer(i)
	if splitscreenviewplayers then
		return splitscreenviewplayers[i]
	end
	return i
end

--the player a viewport's camera follows
function splitscreen_viewtarget(i)
	local p
	if splitscreenviewtarget then
		p = splitscreenviewtarget(i)
	end
	return p or objects["player"][splitscreen_viewplayer(i)]
end

--projectiles thrown by players disappear once they leave the camera, with split screen that's the whole level
function projectileoffscreenx(x)
	if splitscreenactive() then
		return x < -1 or x > mapwidth+1
	end
	return x < xscroll-1 or x > xscroll+width+1
end

function splitscreen_reset()
	splitcamx = {}
	splitcamy = {}
	splitscreenfade = {}
	splitscreenwasactive = false
	splitscreenlayoutanim = nil
end

--how much more of the level a viewport shows than its size: the ones shaped like the screen (2x2 for example)
--are drawn at half scale, so they show twice as much (see splitscreen_beginview)
function splitscreen_rangemul(view)
	if view.rangemul then
		return view.rangemul
	end
	local gameaspect = (width * 16) / (height * 16)
	local viewaspect = view.w / view.h
	if math.abs(viewaspect - gameaspect) < 1e-6 and view.w < width*16 then
		return scale / math.max(scale / 2, 1)
	end
	return 1
end

--a new list of players with a viewport (a minigame taking away a player who's out, for example).
--Every viewport keeps its camera and fade, and they all move and resize into the new layout with a random motion curve;
--one that's new grows out of the middle of where it goes
function splitscreen_setviewplayers(list)
	local old = getsplitscreenviews()
	local from, state = {}, {}
	if old then
		for i, v in ipairs(old) do
			local pn = splitscreen_viewplayer(i)
			from[pn] = {x = v.x, y = v.y, w = v.w, h = v.h, mul = splitscreen_rangemul(v)}
			state[pn] = {cx = splitcamx[i], cy = splitcamy[i], fade = splitscreenfade[i]}
		end
	end
	splitscreenviewplayers = list
	splitcamx, splitcamy, splitscreenfade = {}, {}, {}
	for i, pn in ipairs(list) do
		local s = state[pn]
		if s then
			splitcamx[i], splitcamy[i], splitscreenfade[i] = s.cx, s.cy, s.fade
		end
	end
	splitscreenviewscache = nil
	if old then
		splitscreenlayoutanim = {from = from, t = 0, curve = random_motion_curve()}
	else
		splitscreenlayoutanim = nil
	end
end

function splitscreenactive()
	if not SPLITSCREENISBACK then
		return false
	end
	if editormode or CLIENT or SERVER or darkmode or lightsout then
		return false
	end
	--camera is being controlled by an animation, everyone gets the shared one
	if autoscroll == false then
		return false
	end
	if autoscrolling then
		return false
	end
	local count = splitscreen_viewcount()
	local mincount = 2 --a minigame's list of viewports can have a single one
	if splitscreenviewplayers then
		mincount = 1
	end
	if (not players) or count < mincount or count > 4 then
		return false
	end
	if not (objects and objects["player"]) then
		return false
	end
	for i = 1, players do
		if not objects["player"][i] then
			return false
		end
	end
	return true
end

--viewports in game pixels (not multiplied by scale)
--"lives" is where the lives indicator sits inside of the viewport
function getsplitscreenviews()
	if not splitscreenactive() then
		return nil
	end
	local W, H = width*16, height*16
	local views = {}
	local count = splitscreen_viewcount()
	if count == 1 then
		views[1] = {x = 0, y = 0, w = W, h = H, lives = "centerbottom"}
	elseif count == 2 then
		-- top / bottom
		if HorizontalSplitScreen then
			views[1] = {x = 0, y = 0, w = W, h = H/2, lives = "centerbottom"}
			views[2] = {x = 0, y = H/2, w = W, h = H/2, lives = "centerbottom"}
		else
			views[1] = {x = 0, y = 0, w = W/2, h = H, lives = "centerbottom"}
			views[2] = {x = W/2, y = 0, w = W/2, h = H, lives = "centerbottom"}
		end
	elseif count == 3 then
		-- P1 top-left, P2 top-right, P3 full bottom
		if HorizontalSplitScreen then
			views[1] = {x = 0, y = 0, w = W/2, h = H/2, lives = "centerbottom"}
			views[2] = {x = W/2, y = 0, w = W/2, h = H/2, lives = "centerbottom"}
			views[3] = {x = 0, y = H/2, w = W, h = H/2, lives = "centerbottom"}
		else
			views[1] = {x = 0, y = 0, w = W/2, h = H/2, lives = "centerbottom"}
			views[2] = {x = 0, y = H/2, w = W/2, h = H/2, lives = "centerbottom"}
			views[3] = {x = W/2, y = 0, w = W/2, h = H, lives = "centerbottom"}
		end
	else
		views[1] = {x = 0, y = 0, w = W/2, h = H/2, lives = "centerbottom"}
		views[2] = {x = W/2, y = 0, w = W/2, h = H/2, lives = "centerbottom"}
		views[3] = {x = 0, y = H/2, w = W/2, h = H/2, lives = "centerbottom"}
		views[4] = {x = W/2, y = H/2, w = W/2, h = H/2, lives = "centerbottom"}
	end

	--a layout change: every viewport on its way from where it was to where it goes
	local A = splitscreenlayoutanim
	if A then
		local k = motion_curve(A.t, A.curve, true, false, true, true)
		for i, v in ipairs(views) do
			local target = {x = v.x, y = v.y, w = v.w, h = v.h}
			local tmul = splitscreen_rangemul(target)
			local f = A.from[splitscreen_viewplayer(i)] or {x = v.x + v.w/2, y = v.y + v.h/2, w = 0, h = 0, mul = tmul}
			v.x = lerp(f.x, target.x, k)
			v.y = lerp(f.y, target.y, k)
			v.w = math.max(1, lerp(f.w, target.w, k))
			v.h = math.max(1, lerp(f.h, target.h, k))
			v.rangemul = lerp(f.mul, tmul, k)
		end
	end
	return views
end

function getsplitscreenviewscached()
	if not splitscreenactive() then
		return nil
	end
	if splitscreenlayoutanim then
		return getsplitscreenviews() --they change every frame
	end
	local c = splitscreenviewscache
	if not c or c.players ~= players or c.count ~= splitscreen_viewcount() or c.horizontal ~= HorizontalSplitScreen or c.width ~= width or c.height ~= height then
		c = {players = players, count = splitscreen_viewcount(), horizontal = HorizontalSplitScreen, width = width, height = height, views = getsplitscreenviews()}
		splitscreenviewscache = c
	end
	return c.views
end

function splitscreen_update(dt)
	local views = getsplitscreenviews()
	if not views then
		return
	end
	local resnap = not splitscreenwasactive
	splitscreenwasactive = true

	local A = splitscreenlayoutanim
	if A then
		A.t = A.t + dt/splitscreenlayouttime
		if A.t >= 1 then
			splitscreenlayoutanim = nil
			splitscreenviewscache = nil
		end
	end

	for i = 1, #views do
		local p = splitscreen_viewtarget(i)
		local view = views[i]
		local dead = p.dead --only .dead counts, not .drawable
		local shouldfade = dead and not everyonedead

		--fade
		local f = splitscreenfade[i]
		local revived = false
		if not f then
			f = {dead = dead, alpha = bool2int(shouldfade), from = 0, to = 0, t = 1, curve = splitscreencurves[1]}
			splitscreenfade[i] = f
		elseif dead ~= f.dead then
			f.dead = dead
			f.from = f.alpha
			f.to = bool2int(shouldfade)
			f.t = 0
			f.curve = splitscreencurves[math.random(#splitscreencurves)]
			revived = not dead
		end
		if f.t < 1 then
			f.t = math.min(1, f.t + dt/splitscreenfadetime)
			if f.t >= 1 then
				f.alpha = f.to
			else
				f.alpha = lerp(f.from, f.to, f.curve(f.t))
			end
		end

		--camera, it stays where it is while the player is dead (until they revive)
		camerasmoothing_restore("view" .. i, splitcamx, splitcamy, i) --(camerasmoothing, see game.lua)
		if (not dead) or (not splitcamx[i]) then
			splitscreen_updatecamera(i, view, p, f, dt, revived or resnap)
		end
		local mul = (splitscreencanvases[i] and splitscreencanvases[i].viewrangemul) or 1
		camerasmoothing_apply("view" .. i, splitcamx, splitcamy, i, dt,
			math.max(0, mapwidth-view.w/16*screenzoom2*mul), math.max(0, mapheight-view.h/16*screenzoom2*mul-1))

		splitscreen_spawn(i, view, f)
	end
end

function splitscreen_updatecamera(i, view, p, f, dt, snap)
	local mul = (splitscreencanvases[i] and splitscreencanvases[i].viewrangemul) or 1
	local vw = view.w/16*screenzoom2*mul
	local vh = view.h/16*screenzoom2*mul
	local maxx = math.max(0, mapwidth-vw)
	local maxy = math.max(0, mapheight-vh-1)

	local cx, cy = splitcamx[i], splitcamy[i]
	if snap or (not cx) or (not cy) then
		cx = p.x + p.width/2 - vw/2
		cy = getunduckedhitbox(p).centery - vh/2 - .5
		splitcamx[i] = math.max(0, math.min(maxx, cx))
		splitcamy[i] = math.max(0, math.min(maxy, cy))
		return
	end

	--HORIZONTAL
	if autoscrollx ~= false then
		if autoscrollingx then
			cx = cx + autoscrollingx*dt
		elseif CompletelyCenteredCamera then
			cx = p.x + p.width/2 - vw/2
		else
			--same behaviour as the normal camera, but scaled to the size of the viewport
			local ratio = view.w/(width*16)*screenzoom2
			local rightstart = scrollingstart*ratio
			local rightcomplete = scrollingcomplete*ratio
			local leftstart = scrollingleftstart*ratio
			local leftcomplete = scrollingleftcomplete*ratio

			if camerasetting ~= 3 and p.x < cx + leftstart and cx > 0 then
				if p.speedx < 0 then
					if p.speedx < -scrollrate then
						cx = cx - scrollrate*dt
					else
						cx = cx + p.speedx*dt
					end
				end
				if p.x < cx + leftcomplete then
					cx = cx - scrollrate*dt
					if p.x > cx + leftcomplete then
						cx = p.x - leftcomplete
					end
				end
			end

			if p.x > cx + vw - rightstart and cx < maxx then
				if p.speedx > 0.3 then
					if p.speedx > scrollrate then
						cx = cx + scrollrate*dt
					else
						cx = cx + p.speedx*dt
					end
				end
				if p.x > cx + vw - rightcomplete then
					cx = cx + scrollrate*dt
					if cx > p.x - (vw - rightcomplete) then
						cx = p.x - (vw - rightcomplete)
					end
				end
			end

			--just force it
			if not levelfinished then
				if p.x > cx + vw - rightcomplete then
					cx = cx + superscroll*dt
					if p.x < cx + vw - rightcomplete then
						cx = p.x - vw + rightcomplete
					end
				elseif camerasetting ~= 3 and p.x < cx + leftcomplete then
					cx = cx - superscroll*dt
					if p.x > cx + leftcomplete then
						cx = p.x - leftcomplete
					end
				end
			end
		end

		cx = math.max(0, math.min(maxx, cx))
		if axex and axex >= width and cx > axex-vw then
			cx = math.max(0, axex-vw)
		end
	end

	--VERTICAL (always follows, because a viewport can be way smaller than the level)
	if autoscrolly ~= false then
		if autoscrollingy then
			cy = cy + autoscrollingy*dt
		else
			local py = p.y
			if p.height > 2 then
				py = p.y + p.height/2
			end
			local ratio = view.h/(height*16)*screenzoom2
			local target = cy
			if CompletelyCenteredCamera then
				target = getunduckedhitbox(p).centery - vh/2 - .5
			else
				local upbound = 9*ratio
				local downbound = 4*ratio
				if camerasetting == 2 then
					upbound = 8*ratio
					downbound = 6*ratio
				end
				local sy = py - cy
				if sy > upbound then
					target = py - upbound
				elseif sy < downbound then
					target = py - downbound
				end
			end
			target = math.max(0, math.min(maxy, target))

			local seeking = false
			if p.animationstate == "idle" then
				if p.upkeytimer and p.upkeytimer > seektime then
					target = math.max(0, math.min(maxy, target - seekrange))
					seeking = true
				elseif p.downkeytimer and p.downkeytimer > seektime then
					target = math.max(0, math.min(maxy, target + seekrange))
					seeking = true
				end
			end

			local diff = math.abs(cy-target)
			local speed = math.max(math.abs(p.speedy), scrollrate)
			if seeking then
				speed = seekspeed
			elseif diff > 2.5*ratio then
				speed = superscrollrate
			end
			if target > cy then
				cy = math.min(target, cy + speed*dt)
			elseif target < cy then
				cy = math.max(target, cy - speed*dt)
			end

			if CompletelyCenteredCamera then
				if seeking then
					f.centeredseeking = true
				elseif (not f.centeredseeking) or math.abs(cy-target) <= 1/16 then
					f.centeredseeking = false
					cy = target
				end
			end
		end

		cy = math.max(0, math.min(maxy, cy))
	end

	splitcamx[i] = cx
	splitcamy[i] = cy
end

--enemies spawn when they get into view, so every viewport has to do that
function splitscreen_spawn(i, view, f)
	local mul = (splitscreencanvases[i] and splitscreencanvases[i].viewrangemul) or 1
	local vw = view.w/16*screenzoom2*mul
	local vh = view.h/16*screenzoom2*mul
	local x1 = math.max(1, math.floor(splitcamx[i]))
	local x2 = math.min(mapwidth, math.floor(splitcamx[i])+math.ceil(vw)+2)
	local y1 = math.max(1, math.floor(splitcamy[i]))
	local y2 = math.min(mapheight, math.floor(splitcamy[i])+math.ceil(vh)+3)
	if f.sx1 == x1 and f.sx2 == x2 and f.sy1 == y1 and f.sy2 == y2 then
		return
	end
	for x = x1, x2 do
		for y = y1, y2 do
			if not (f.sx1 and x >= f.sx1 and x <= f.sx2 and y >= f.sy1 and y <= f.sy2) then
				spawnenemyentity(x, y)
			end
		end
	end
	f.sx1, f.sx2, f.sy1, f.sy2 = x1, x2, y1, y2
end

--every viewport is drawn onto its own canvas, so scissors/stencils used while drawing the level can't leak into other viewports
--where the mouse is in the level (in tiles), seen through the viewport of player p, or nil without split screen.
--A viewport is drawn at view.x, view.y with its own camera (splitcamx/splitcamy), and shows rangemul times as much
--(see splitscreen_beginview). s: the scale the mouse position is in
function splitscreen_mouseworld(p, s)
	local views = getsplitscreenviewscached()
	if not views then
		return nil
	end
	local index
	for i = 1, #views do
		if splitscreen_viewplayer(i) == p.playernumber then
			index = i
			break
		end
	end
	if not index then
		--no viewport of their own (a minigame's layout): the one that follows them
		for i = 1, #views do
			if splitscreen_viewtarget(i) == p then
				index = i
				break
			end
		end
	end
	if not index then
		return nil
	end
	local view = views[index]
	local mul = splitscreen_rangemul(view)
	local camx = splitcamx[index] or splitxscroll[1]
	local camy = splitcamy[index] or splityscroll[1]
	local x = camx + (love.mouse.getX() - view.x*s)*mul/(16*screenzoom*s)
	local y = camy + (love.mouse.getY() - view.y*s)*mul/(16*screenzoom*s)
	return x, y
end

function splitscreen_beginview(split, view)
	local basescale = scale
	local renderscale = scale
	local upscale = 1
	local viewrangemul = 1
	if view.rangemul then
		--a layout change: the range eases between the old and the new layout's
		viewrangemul = view.rangemul
		renderscale = basescale / viewrangemul
	else
		-- viewports matching the game window aspect (e.g. 2x2) render at half scale and stay there
		local gameaspect = (width * 16) / (height * 16)
		local viewaspect = view.w / view.h
		if math.abs(viewaspect - gameaspect) < 1e-6 and view.w < width*16 then --(a single full screen viewport stays at full scale)
			renderscale = math.max(scale / 2, 1)
			viewrangemul = basescale / renderscale
			-- do not scale back up
		end
	end
	-- canvas stays full viewport size so the extra view range fills the slot
	local cw, ch = math.max(1, math.floor(view.w * basescale)), math.max(1, math.floor(view.h * basescale))
	local sc = splitscreencanvases[split]
	--during a layout change the size changes every frame: one screen-sized canvas for the whole change, only part of it is shown
	local canvasw, canvash = cw, ch
	if splitscreenlayoutanim then
		if sc and sc.w >= cw and sc.h >= ch then
			canvasw, canvash = sc.w, sc.h
		else
			canvasw = math.max(cw, math.floor(width*16*basescale))
			canvash = math.max(ch, math.floor(height*16*basescale))
		end
	end
	if (not sc) or sc.w ~= canvasw or sc.h ~= canvash then
		sc = {w = canvasw, h = canvash, canvas = love.graphics.newCanvas(canvasw, canvash), upscale = upscale, viewrangemul = viewrangemul}
		sc.canvas:setFilter("nearest", "nearest")
		splitscreencanvases[split] = sc
	else
		sc.upscale = upscale
		sc.viewrangemul = viewrangemul
	end
	sc.vw, sc.vh = cw, ch --the part of the canvas the viewport shows
	splitscreenprevcanvas = love.graphics.getCanvas()
	love.graphics.origin()
	love.graphics.setCanvas({sc.canvas, stencil = true})
	love.graphics.clear(love.graphics.getBackgroundColor())
	sc.oldscale = scale
	scale = renderscale
end

function splitscreen_endview(split, view)
	local sc = splitscreencanvases[split]
	if sc.oldscale then
		scale = sc.oldscale
		sc.oldscale = nil
	end
	love.graphics.origin()
	love.graphics.setScissor()
	love.graphics.setStencilTest()
	if splitscreenprevcanvas then
		love.graphics.setCanvas({splitscreenprevcanvas, stencil = true})
	else
		love.graphics.setCanvas()
	end
	local x, y = view.x*scale, view.y*scale
	love.graphics.setColor(255, 255, 255, 255)
	local up = sc.upscale or 1
	if sc.vw and (sc.vw ~= sc.w or sc.vh ~= sc.h) then
		--a bigger canvas than the viewport (a layout change): only the viewport's part of it
		sc.quad = sc.quad or love.graphics.newQuad(0, 0, 1, 1, 1, 1)
		sc.quad:setViewport(0, 0, sc.vw, sc.vh, sc.w, sc.h)
		love.graphics.draw(sc.canvas, sc.quad, x, y, 0, up, up)
	else
		love.graphics.draw(sc.canvas, x, y, 0, up, up)
	end

	--dead players fade to black
	local f = splitscreenfade[split]
	if f and f.alpha > 0 then
		love.graphics.setColor(0, 0, 0, f.alpha*255)
		love.graphics.rectangle("fill", x, y, view.w*scale, view.h*scale)
	end

	love.graphics.setColor(255, 255, 255, 255)
end

function splitscreen_finishdraw(views)
	--borders between viewports
	love.graphics.setColor(0, 0, 0, 255)
	for i = 1, #views do
		local v = views[i]
		if v.x > 0 then
			love.graphics.rectangle("fill", (v.x-1)*scale, v.y*scale, 2*scale, v.h*scale)
		end
		if v.y > 0 then
			love.graphics.rectangle("fill", v.x*scale, (v.y-1)*scale, v.w*scale, 2*scale)
		end
	end
	love.graphics.setColor(255, 255, 255, 255)

	--score, coins and time are only drawn once
	if hudvisible then
		love.graphics.push()
		drawHUD()
		love.graphics.pop()
	end

	--livecounter on top of the viewports
	for i = 1, #views do
		splitscreen_drawlives(i, views[i])
	end

	--the rest of the game expects the normal camera
	xscroll = splitxscroll[1]
	yscroll = splityscroll[1]
	love.graphics.setColor(255, 255, 255, 255)
end

--same info as drawmultiHUD, but placed inside of the viewport of the player
function splitscreen_drawlives(i, view)
	local playeri = splitscreen_viewplayer(i)
	local p = objects["player"][playeri]
	local livesdisplay = (mariolivecount ~= false)
	if not livesdisplay then
		for j = 1, players do
			local q = objects["player"][j]
			if q and ((q.key and q.key > 0) or (q.health and q.characterdata.healthimg)) then
				livesdisplay = true
				break
			end
		end
	end
	if not livesdisplay then
		if splitscreenviewhud then
			splitscreenviewhud(i, view, playeri)
		end
		return
	end

	local properprintfunc = properprintF
	if hudoutline then
		properprintfunc = properprintFbackground
	end

	local s
	if mariolivecount ~= false then
		s = "p" .. playeri .. " * " .. mariolives[playeri]
	else
		s = "p" .. playeri
	end
	local hp, key
	if p.health and p.characterdata.healthimg then
		hp = "hp: " .. p.health
	end
	if p.key and p.key > 0 then
		key = "*" .. p.key
	end

	local blockw, blockh = 8 + string.len(s)*8, 9
	if hp then
		blockw = math.max(blockw, string.len(hp)*8)
		blockh = blockh + 10
	end
	if key then
		blockw = math.max(blockw, 9 + string.len(key)*8)
		blockh = blockh + 10
	end

	-- y-padding matches the gap from the top of the window to the topmost HUD line
	local toppadding = hudsimple and 12 or 8
	local margin = 4
	local anchor = view.lives
	local cx, cy
	if string.find(anchor, "right") then
		cx = view.x + view.w - blockw - margin
	elseif string.find(anchor, "left") then
		cx = view.x + margin
	else
		-- center horizontally
		cx = view.x + (view.w - blockw)/2
	end
	if string.find(anchor, "top") then
		cy = view.y + toppadding
	elseif string.find(anchor, "bottom") then
		cy = view.y + view.h - blockh
	else
		cy = view.y + (view.h - blockh)/2
	end
	cx, cy = math.floor(cx), math.floor(cy)

	-- livecounter at centerbottom of its viewport
	love.graphics.setColor(255, 255, 255, 255)
	properprintfunc(s, (cx+8)*scale, cy*scale)
	if hudoutline then
		love.graphics.setColor(0, 0, 0)
		love.graphics.rectangle("fill", (cx-1)*scale, (cy-1)*scale, 9*scale, 9*scale)
	end
	love.graphics.setColor(mariocolors[playeri][1])
	love.graphics.rectangle("fill", cx*scale, cy*scale, 7*scale, 7*scale)
	love.graphics.setColor(255, 255, 255, 255)
	cy = cy + 10

	if hp then
		properprintfunc(hp, cx*scale, cy*scale)
		cy = cy + 10
	end
	if key then
		love.graphics.draw(keyuiimg, keyuiquad[spriteset or 1][coinframe or 1], cx*scale, cy*scale, 0, scale, scale)
		properprintfunc(key, (cx+9)*scale, cy*scale)
	end
	if splitscreenviewhud then
		splitscreenviewhud(i, view, playeri)
	end
end

function updatesplitscreen()
	if players == 2 then
		if #splitscreen == 1 then
			if math.abs(objects["player"][1].x - objects["player"][2].x) > width - scrollingstart - scrollingleftstart then
				if objects["player"][1].x < objects["player"][2].x then
					splitscreen = {{1}, {2}}
				else
					splitscreen = {{2}, {1}}
				end
				
				splitxscroll = {xscroll, xscroll+width/2}
				generatespritebatch()
			end
		else
			if splitxscroll[2] <= splitxscroll[1]+width/2 then
				splitscreen = {{1, 2}}
				
				xscroll = splitxscroll[1]
				generatespritebatch()
			end
		end
	end
end