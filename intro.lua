local intro_finish_menu
local intro_loading

function intro_load()
	gamestate = "intro"

	introfadetime = 0.5
	introtypewriteduration = 1

	introscaletimer = 0
	introscaleduration = 1
	introtypewritetimer = 0
	introfadeprogress = 0

	introcurve = random_motion_curve()
	introsound = newsound(randomitem(introsoundpaths))
	playsound(introsound)

	introfade = false
	introsoundfade = false
	introtransition = false
	allowskip = false

	screenwidth = width*16*scale
	screenheight = 224*scale
end

function intro_update(dt)
	allowskip = true

	introscaletimer = math.min(introscaletimer + dt, introscaleduration)
	introtypewritetimer = math.min(introtypewritetimer + dt, introtypewriteduration)

	-- Start the exit fade when the sound finishes naturally.
	if not introfade and not introsound:isPlaying() then
		introfade = true
		introfadeprogress = 0
	end

	if introfade then
		introfadeprogress = introfadeprogress + dt

		-- Fade the sound out when skipped.
		if introsoundfade then
			introsound:setVolume(introsoundvolume * (1 - math.min(introfadeprogress / introfadetime, 1)))
		end

		-- Finish the sound fade and transition immediately after the visual fade.
		if introfadeprogress >= introfadetime and not introtransition then
			if introsoundfade then
				introsound:stop()
			end

			introtransition = true
			startwarpfade(intro_finish_menu, false, true)
		end
	end
end

function intro_draw()
	-- Loading text.
	local introscale = motion_curve(introscaletimer / introscaleduration, introcurve, true, false, true) * 2.5

	love.graphics.setColor(150, 150, 150)
	centerprint("loading mari0...", 200, 112, introscale)

	-- Typewriter effect.
	local charcount = utf8.len(loadingtext) or #loadingtext
	local visiblechars = math.floor(charcount * math.min(introtypewritetimer / introtypewriteduration, 1))
	local byteend = utf8.offset(loadingtext, visiblechars + 1)

	local visibletext = visiblechars >= charcount and loadingtext or loadingtext:sub(1, (byteend or (#loadingtext + 1)) - 1)

	love.graphics.setColor(50, 50, 50)
	centerprint(visibletext, 200, 204)
end

function intro_mousepressed()
	intro_finish()
end

function intro_keypressed()
	intro_finish()
end

function intro_finish()
	if not allowskip or introfade then
		return
	end

	allowskip = false
	introfade = true
	introsoundfade = true
	introfadeprogress = 0
	introsoundvolume = introsound:getVolume()
end

function intro_finish_menu()
	intro_loading = true
	renderoverlay("loading menu...")
	menu_load()
end