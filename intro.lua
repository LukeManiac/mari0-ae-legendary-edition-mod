local intro_finish

function intro_load()
	gamestate = "intro"
	
	introduration = 2.5
	blackafterintro = 0.3
	introfadetime = 0.5
	introprogress = 0.5
	introscaletimer = 0
	introscaleduration = 0.5
	
	screenwidth = width*16*scale
	screenheight = 224*scale
	allowskip = false
end

function intro_update(dt)
	allowskip = true
	if introprogress < introduration+blackafterintro then
		introprogress = introprogress + dt
		introscaletimer = clamp(introscaletimer + dt, {maxval=introscaleduration})

		if introprogress > introduration+blackafterintro then
			introprogress = introduration+blackafterintro
		end
		
		if introprogress > 0.5 and playedwilhelm == nil then
			playsound(introsound)
			playedwilhelm = true
		end
	end
		
	if introprogress >= introduration + blackafterintro then
		intro_finish()
	end
end

function intro_draw()
	if introprogress >= 0 and introprogress < introduration then
		local a = 255
		if introprogress < introfadetime then
			a = introprogress/introfadetime * 255
		elseif introprogress >= introduration-introfadetime then
			a = (1-(introprogress-(introduration-introfadetime))/introfadetime) * 255
		end
		
		love.graphics.setColor(255, 255, 255, a)
		intro_scale = motion_curve(introscaletimer, "circ", {curve_out=true, clamp_input=true}) * scale / introscaleduration / 2
		intro_width = intro_image:getWidth() * intro_scale
		intro_height = intro_image:getHeight() * intro_scale
		
		love.graphics.draw(intro_image, ((400 * scale) - intro_width) / 2, ((224 * scale) - intro_height) / 2, 0, intro_scale, intro_scale)
		
		intro_textdraw(math.max(0, (1-(introprogress-.5)/0.3)*255))
	end
end

function intro_textdraw(a2)
	if a2 == nil then a2 = 255 end
	love.graphics.setColor(150, 150, 150, a2)
	properprint("loading mari0..", love.graphics.getWidth()/2-string.len("loading mari0..")*4*scale, 20*scale)
	love.graphics.setColor(50, 50, 50, a2)
	properprint(loadingtext, love.graphics.getWidth()/2-string.len(loadingtext)*4*scale, love.graphics.getHeight()/2+165)
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
	introsound:stop()
	renderoverlay("loading menu...", nil, true)
	menu_load()
end
