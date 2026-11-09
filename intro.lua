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
	introscaletimer = introscaletimer + dt
	introtypewritetimer = math.min(introtypewritetimer + dt, introtypewriteduration)

	-- Transition once the sound finishes.
	if introtimer >= introduration and not (introtransition or introsound:isPlaying()) then
		introtransition = true
		startwarpfade(intro_finish_menu, false, true)
	end
end

--prints a single line of text centered on x, y (game pixels), every character has its own oscillating colour
--scalemult can be a number (same scale for every character) or a function(i) returning the scale of character i, or nil to skip it entirely
local function intro_printcolour(text, x, y, scalemult, spacingmult)
	spacingmult = spacingmult or scalemult
	local length = utf8.len(text) or #text

	for i, char in utf8.chars(text) do
		local charscale = scalemult
		if type(scalemult) == "function" then
			charscale = scalemult(i)
		end

		--character is still waiting for its turn, skip it (no colour calculation, no print)
		if not charscale then
			goto continue
		end
		--full cycle every 2 seconds: second 1 = authorcolour, second 2 = authorcolour / 2
		local p = (1 - math.cos(math.pi * (introtimer - (i - 1) * introcolouroffset))) / 2

		love.graphics.setColor(
			lerp(authorcolour[1], authorcolour[1] / 2, p),
			lerp(authorcolour[2], authorcolour[2] / 2, p),
			lerp(authorcolour[3], authorcolour[3] / 2, p),
			introalpha
		)

		--centre of this character's cell (game pixels), spacing stays fixed while the character itself scales
		local centerx = x + ((i - 0.5) - length / 2) * 8 * spacingmult
		local charx = (centerx - (8 * charscale) / 2) * scale
		local chary = (y - (10 * charscale) / 2) * scale

		if hudoutline then
			properprintFbackground(char, charx, chary, nil, nil, charscale)
		else
			properprintF(char, charx, chary, charscale)
		end

		::continue::
	end
end

function intro_draw()
	-- Author name.
	-- Each character zooms in on its own, one after another, introcolouroffset seconds apart.
	local function authorcharscale(i)
		local chartimer = introscaletimer - (i - 1) * introcolouroffset
		if chartimer <= 0 then
			return nil --not its turn yet
		end

		return motion_curve(math.min(chartimer / introscaleduration, 1), introcurve, true, false, true) * 2.5
	end

	intro_printcolour(authorname, 200, 112, authorcharscale, 2.5)

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