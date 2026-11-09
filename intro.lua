local intro_finish_menu
local intro_loading

function intro_load()
	gamestate = "intro"

	introfadetime = 0.5
	introscaletimer = 0
	introscaleduration = 0.5
	introcurve = random_motion_curve()
	introsound = newsound(randomitem(introsoundpaths))
	introsound:play()

	introprogress = 0
	introfade = false
	introfadestart = nil
	allowskip = false

	screenwidth = width*16*scale
	screenheight = 224*scale
end

function intro_update(dt)
	allowskip = true

	introscaletimer = math.min(introscaletimer + dt, introscaleduration)

	if not introfade and not introsound:isPlaying() then
		introfade = true
		introfadestart = 0
	end

	if introfade then
		introfadestart = introfadestart + dt

		if introfadestart >= introfadetime*2 then
			intro_finish()
		end
	end
end

function intro_draw()
	if introfade and introfadestart >= introfadetime then
		return
	end

	local a = 255

	if introfade then
		a = 255 * (1 - introfadestart / introfadetime)
	end

	love.graphics.setColor(255, 255, 255, a)

	local introscale = motion_curve(introscaletimer / introscaleduration, introcurve, true, false, true) * scale
	local originx = intro_image:getWidth() / 2
	local originy = intro_image:getHeight() / 2

	if not intro_loading then
		love.graphics.draw(intro_image, 200 * scale, 112 * scale, 0, introscale, introscale, originx, originy)
	end

	local a2 = math.max(0, 170 * (4 - 5 * introprogress))
	love.graphics.setColor(150, 150, 150, a2)
	centerprint("loading mari0...", 200, 20)
	love.graphics.setColor(50, 50, 50, a2)
	centerprint(loadingtext, 200, 204)
end

function intro_mousepressed()
	intro_finish()
end

function intro_keypressed()
	intro_finish()
end

function intro_finish()
	if not allowskip then
		return
	end

	allowskip = false

	if introfade then
		return
	end

	introfade = true
	introfadestart = 0

	introsound:stop()
	startwarpfade(intro_finish_menu, false, true)
end

function intro_finish_menu()
	intro_loading = true
	renderoverlay("loading menu...")
	menu_load()
end