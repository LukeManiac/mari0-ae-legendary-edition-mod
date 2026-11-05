function onlinemenu_load()
	objects = nil
	--mappack = "smb"
	
	gamestate = "onlinemenu"
	
	--maurice kept roasting me about this
	--guess that's what I get for reusing menus
	localnicks = {"mario", "luigi", "wario", "waluigi", "peach", "toad", "bowser", "chell", "mel", "p-body", "atlas", "glados", "wheatley", "cave"}
	if not localnick then
		localnick = randomitem(localnicks)
	end
	
	guielements = {}
	guielements.nickentry = guielement:new("input", 5, 30, 14, nil, localnick, 14, 1)
	
	guielements.configdecrease = guielement:new("button", 192, 31, "{", configdecrease, 0)
	guielements.configincrease = guielement:new("button", 214, 31, "}", configincrease, 0)
	
	
	guielements.roomentry = guielement:new("input", 6, 87, 23, joingame, "", 8, 1)
	
	guielements.hostbutton = guielement:new("button", 247, 199, TEXT["create game"], creategame, 2)
	guielements.hostbutton.bordercolor = {255, 0, 0}
	guielements.hostbutton.bordercolorhigh = {255, 127, 127}
	
	guielements.joinbutton = guielement:new("button", 61, 199, TEXT["join game"], joingame, 2)
	guielements.joinbutton.bordercolor = {0, 255, 0}
	guielements.joinbutton.bordercolorhigh = {127, 255, 127}
	
	runanimationtimer = 0
	runanimationframe = 1
	runanimationdelay = 0.1
	
	playerconfig = 1
	
end

function onlinemenu_update(dt)
	runanimationtimer = runanimationtimer + dt
	while runanimationtimer > runanimationdelay do
		runanimationtimer = runanimationtimer - runanimationdelay
		runanimationframe = runanimationframe - 1
		if runanimationframe == 0 then
			runanimationframe = 3
		end
	end
	
	localnick = guielements.nickentry.value
end

function onlinemenu_draw()
	--TOP PART
	love.graphics.setColor(0, 0, 0, 200)
	love.graphics.rectangle("fill", 3*scale, 3*scale, 394*scale, 52*scale)
	love.graphics.setColor(255, 255, 255)
	
	properprintF(TEXT["online play"], 4*scale, 5*scale)
	
	properprintF(TEXT["your nick:"], 4*scale, 20*scale)
	guielements.nickentry:draw()
	
	properprintF(TEXT["use config"], 140*scale, 20*scale)
	properprintF(TEXT["config number"] .. playerconfig , 140*scale, 33*scale)
	guielements.configdecrease:draw()
	guielements.configincrease:draw()
	
	drawplayercard(240, 10, mariocolors[playerconfig], mariohats[playerconfig], localnick, nil, nil, mariocharacter[playerconfig])
	
	
	--BOTTOM PART
	
	--LEFT (JOIN)
	love.graphics.setColor(0, 0, 0, 200)
	love.graphics.rectangle("fill", 3*scale, 58*scale, 196*scale, 163*scale)
	
	love.graphics.setColor(255, 255, 255)
	properprintF(TEXT["join game"], 64*scale, 60*scale)
	
	properprintF(TEXT["room code"], 36*scale, 77*scale)
	guielements.roomentry:draw()
	love.graphics.setColor(150, 150, 150)
	properprintF(TEXT["enter room code"], 24*scale, 107*scale)
	
	guielements.joinbutton:draw()
	
	--RIGHT (HOST)
	love.graphics.setColor(0, 0, 0, 200)
	love.graphics.rectangle("fill", 202*scale, 58*scale, 195*scale, 163*scale)
	
	love.graphics.setColor(255, 255, 255)
	properprintF(TEXT["host game"], 260*scale, 60*scale)
	properprintF(TEXT["no port forwarding"], 240*scale, 82*scale)
	
	love.graphics.setColor(150, 150, 150)
	properprintF(TEXT["share room code"], 218*scale, 107*scale)
	
	guielements.hostbutton:draw()
end


function drawplayercard(x, y, colortable, hattable, nick, ping, focus, character)
	if focus then
		love.graphics.setColor(127, 127, 127, 150)
	else
		love.graphics.setColor(0, 0, 0, 255)
	end
	love.graphics.rectangle("fill", x*scale, y*scale, 150*scale, 38*scale)
	love.graphics.setColor(255, 255, 255, 255)
	drawrectangle(x+1, y+1, 148, 36)

	local v = characters.data[character or "mario"]
	if not v then
		v = characters.data["mario"]
	end
	if v then
		love.graphics.setColor(255, 255, 255, 255)
		for i = 0, #v.colorables do
			if i > 0 then
				love.graphics.setColor(colortable[i])
			else
				love.graphics.setColor(255, 255, 255)
			end
			if mariocharacter[skinningplayer] then
				love.graphics.draw(v["animations"][i], v["small"]["run"][3][math.min(#v["small"]["run"],runanimationframe)], (x+4+v.smalloffsetX*2)*scale, (y+26-v.smalloffsetY*2)*scale, 0, scale*2, scale*2, v.smallquadcenterX, v.smallquadcenterY)
			end
		end
		
		--Scissors just for hat stacks
		local yadd = 0
		local addcolortohat = true

		if (type(hattable) == "table" and #hattable > 1) or hattable[1] ~= 1 then 
			addcolortohat = false
		end
		for i = 1, #hattable do
			if hat[hattable[i] ] then
				if addcolortohat then
					love.graphics.setColor(colortable[1])
				end
				local offsets = customplayerhatoffsets(character, "hatoffsets", "running") or hatoffsets["running"]
				love.graphics.draw(hat[hattable[i] ].graphic, hat[hattable[i] ].quad[1], (x+4+v.smalloffsetX*2)*scale, (y+26-v.smalloffsetY*2)*scale, 0, scale*2, scale*2, v.smallquadcenterX - hat[hattable[i] ].x + offsets[runanimationframe][1], v.smallquadcenterY - hat[hattable[i] ].y + offsets[runanimationframe][2] + yadd)
				yadd = yadd + hat[hattable[i] ].height
			end
		end
	end

	love.graphics.setColor(255, 255, 255)
	properprintF(nick, x*scale+35*scale, y*scale+10*scale)

	if ping then
		if tonumber(ping) then
			if tonumber(ping) < 40 then
				love.graphics.setColor(100+125*(tonumber(ping)/40), 255, 100)
			elseif tonumber(ping) >= 40 and tonumber(ping) < 80 then
				love.graphics.setColor(255, 225-125*((tonumber(ping)-40)/40), 100)
			elseif tonumber(ping) >= 80 then
				love.graphics.setColor(255, 100, 100)
			end
		else
			love.graphics.setColor(127, 127, 127, 255)
		end
		properprintF("ping:", x*scale+35*scale, y*scale+22*scale)
		properprintF(ping .. "ms", (x+123-#(ping .. "ms")*8)*scale, y*scale+22*scale)
	else
		love.graphics.setColor(127, 127, 127)
		properprintF("ping:", x*scale+35*scale, y*scale+22*scale)
		properprintF("host", x*scale+75*scale, y*scale+22*scale)
	end
end

function configdecrease()
	playerconfig = math.max(1, playerconfig-1)
end

function configincrease()
	playerconfig = math.min(4, playerconfig+1)
end

function creategame()
	local roomcode = net_create_room_code()
	if not server_load(roomcode) then
		return
	end
	
	playerlist = {}
	playerlist[1] = {connected=true, hats=mariohats[playerconfig], colors=mariocolors[playerconfig], nick=localnick, id="host", ping=0, character=mariocharacter[playerconfig]}
	lobby_load()
end

function joingame()
	local roomcode = guielements.roomentry.value:upper():gsub("%s", "")
	
	playerlist = {}
	playerlist[1] = {connected=true, hats=mariohats[playerconfig], colors=mariocolors[playerconfig], nick=localnick, id="self", ping=0, character=mariocharacter[playerconfig]}
	
	if not client_load(roomcode) then
		return
	end
	lobby_load()
end
