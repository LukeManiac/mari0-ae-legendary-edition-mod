local intro_finish_menu

local introcolouroffset = 0.125 --seconds of oscillation offset added per character index

function intro_load()
	gamestate = "intro"

	introtypewriteduration = 1

	introtimer = 0
	introduration = 5
	introscaletimer = 0
	introscaleduration = 1
	introtypewritetimer = 0

	introcurve = random_motion_curve()
	introsound = newsound(randomitem(introsoundpaths))

	introtransition = false
	introalpha = 255

	if SkipIntro then
		intro_finish_menu()
	else
		playsound(introsound)
	end
end

function intro_update(dt)
	introtimer = introtimer + dt
	introscaletimer = math.min(introscaletimer + dt, introscaleduration)
	introtypewritetimer = math.min(introtypewritetimer + dt, introtypewriteduration)

	-- Transition once the sound finishes.
	if introtimer >= introduration and not (introtransition or introsound:isPlaying()) then
		introtransition = true
		startwarpfade(intro_finish_menu, false, true)
	end
end

--prints a single line of text centered on x, y (game pixels), every character has its own oscillating colour
local function intro_printcolour(text, x, y, scalemult)
	local length = utf8.len(text) or #text
	local textx = (x - (8 * scalemult * length) / 2) * scale
	local texty = (y - (10 * scalemult) / 2) * scale

	for i, char in utf8.chars(text) do
		--full cycle every 2 seconds: second 1 = authorcolour, second 2 = authorcolour / 2
		local p = (1 - math.cos(math.pi * (introtimer - (i - 1) * introcolouroffset))) / 2

		love.graphics.setColor(
			lerp(authorcolour[1], authorcolour[1] / 2, p),
			lerp(authorcolour[2], authorcolour[2] / 2, p),
			lerp(authorcolour[3], authorcolour[3] / 2, p),
			introalpha
		)

		local charx = textx + ((i - 1) * 8 * scalemult) * scale

		if hudoutline then
			properprintFbackground(char, charx, texty, nil, nil, scalemult)
		else
			properprintF(char, charx, texty, scalemult)
		end
	end
end

function intro_draw()
	-- Author name.
	local introscale = motion_curve(introscaletimer / introscaleduration, introcurve, true, false, true) * 2.5

	intro_printcolour(authorname, 200, 112, introscale)

	-- Typewriter effect.
	local charcount = utf8.len(loadingtext) or #loadingtext
	local visiblechars = math.floor(charcount * math.min(introtypewritetimer / introtypewriteduration, 1))
	local byteend = utf8.offset(loadingtext, visiblechars + 1)

	local visibletext = visiblechars >= charcount and loadingtext or loadingtext:sub(1, (byteend or (#loadingtext + 1)) - 1)

	intro_printcolour(visibletext, 200, 168, 1)
end

function intro_finish_menu()
	introalpha = 0
	renderoverlay("loading menu...")
	menu_load()
end