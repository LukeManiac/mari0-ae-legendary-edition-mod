local intro_finish_menu

function intro_load()
	gamestate = "intro"

	introtypewriteduration = 1

	introscaletimer = 0
	introscaleduration = 1
	introtypewritetimer = 0

	introcurve = random_motion_curve()
	introsound = newsound(randomitem(introsoundpaths))
	playsound(introsound)

	introtransition = false
	introalpha = 255
end

function intro_update(dt)
	introscaletimer = math.min(introscaletimer + dt, introscaleduration)
	introtypewritetimer = math.min(introtypewritetimer + dt, introtypewriteduration)

	-- Transition once the sound finishes.
	if not (introtransition or introsound:isPlaying()) then
		introtransition = true
		startwarpfade(intro_finish_menu, false, true)
	end
end

function intro_draw()
	-- Loading text.
	local introscale = motion_curve(introscaletimer / introscaleduration, introcurve, true, false, true) * 2.5

	love.graphics.setColor(150, 150, 150, introalpha)
	centerprint("loading mari0...", 200, 112, introscale)

	-- Typewriter effect.
	local charcount = utf8.len(loadingtext) or #loadingtext
	local visiblechars = math.floor(charcount * math.min(introtypewritetimer / introtypewriteduration, 1))
	local byteend = utf8.offset(loadingtext, visiblechars + 1)

	local visibletext = visiblechars >= charcount and loadingtext or loadingtext:sub(1, (byteend or (#loadingtext + 1)) - 1)

	love.graphics.setColor(50, 50, 50, introalpha)
	centerprint(visibletext, 200, 204)
end

function intro_finish_menu()
	introalpha = 0
	renderoverlay("loading menu...")
	menu_load()
end