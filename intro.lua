local intro_finish
local intro_finish_menu
local intro_loading

function intro_load()
	gamestate = "intro"
	
	introduration = 2.5
	blackafterintro = 0.3
	introfadetime = 0.5
	introprogress = 0.5
	introscaletimer = 0
	introscaleduration = 0.5
	introcurve = random_motion_curve()
	
	screenwidth = width*16*scale
	screenheight = 224*scale
	allowskip = false
end

function intro_update(dt)
	allowskip = true
	if introprogress < introduration+blackafterintro then
		introprogress = introprogress + dt
		introscaletimer = math.max(0, math.min(introscaletimer + dt, introscaleduration))

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
		intro_scale = motion_curve(introscaletimer / introscaleduration, introcurve, true, false, true) * scale
		local originx = intro_image:getWidth() / 2
		local originy = intro_image:getHeight() / 2
		
		if not intro_loading then
			love.graphics.draw(intro_image, 200 * scale, 112 * scale, 0, intro_scale, intro_scale, originx, originy)
		end
		
		intro_textdraw(math.max(0, 170*(4-5*introprogress)))
	end
end

function intro_textdraw(a2)
	if a2 == nil then a2 = 255 end
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
	introsound:stop()
	startwarpfade(intro_finish_menu, false, true)
end

function intro_finish_menu()
	intro_loading = true
	renderoverlay("loading menu...")
	menu_load()
end