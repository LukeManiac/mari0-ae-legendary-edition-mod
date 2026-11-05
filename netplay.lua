local socket = require "socket"
local relayconfig = require "relayconfig"

local udp
 
local relay_host, relay_port = relayconfig.host, relayconfig.port
 
local entity
local clients
local updaterate = 0.1
local pingrate = 2
local updatetimer --update timer
local actions
local levelscreensync
local enemyspawnx

local clientconnecttimer = 0
local clientconnected = false
local clientconnecttime = 4
local clientjoinpending = false
local relay_room_code
local relay_room_ready = false
local relay_keepalive_timer = 0
local relay_setup_timer = 0
local relay_retry_timer = 0
local local_relay_socket
local local_relay_instance_id
local local_relay_start_pending = false
local local_relay_start_attempted = false
local local_relay_heartbeat_timer = 0
local local_relay_start_timer = 0
local local_relay_spawned = false
local local_relay_thread

local spamtimer = 0 --stop "funny" kids from spamming
local spamtime = 0.2
local spamcounter = 0
local spammercount = 10

local function nt(key)
	return TEXT[key] or key
end

local lobbytimeout = 12 --kick player if ping is higher than this (a ping this high means they've disconnected)

local function is_local_relay()
	return relay_host == "localhost" or relay_host == "127.0.0.1"
end

local function current_process_id()
	local ok, ffi = pcall(require, "ffi")
	if not ok then
		return nil
	end

	local osname = love.system.getOS()
	local declaration
	local function_name
	if osname == "Windows" then
		declaration = "unsigned long __stdcall GetCurrentProcessId(void);"
		function_name = "GetCurrentProcessId"
	elseif osname == "Linux" or osname == "OS X" then
		declaration = "int getpid(void);"
		function_name = "getpid"
	else
		return nil
	end

	pcall(ffi.cdef, declaration)
	local success, process_id = pcall(function()
		return ffi.C[function_name]()
	end)
	if success then
		return tostring(process_id)
	end
end

local function start_local_relay()
	-- Pure Lua relay runs inside a LÖVE thread; no Python required.
	local_relay_thread = love.thread.newThread("relaythread.lua")
	local_relay_thread:start()
	love.thread.getChannel("relayin"):push({
		port = relay_port,
	})
	return true
end

local conn_state = "idle" --idle, connecting or connected
local conn_id = 0
local conn_in
local conn_out
local conn_start = 0
local conn_timeout = 30 --seconds

local function format_connect_time(seconds)
	local text = string.format("%.3f", seconds)
	text = text:gsub("%.?0+$", "")
	return text .. "s"
end

local function conn_stop()
	conn_state = "idle"
	if conn_in then
		conn_in:push("stop")
	end
end

local function open_local_relay_monitor()
	if local_relay_socket then
		return true
	end

	local process_id = current_process_id()
	if not process_id then
		notice.new("Could not identify this game process to start the relay", notice.red, 6)
		return false
	end

	local_relay_instance_id = process_id .. "-" .. tostring(math.random(2147483647))
	local_relay_socket = socket.udp()
	if not local_relay_socket then
		notice.new("Could not create the relay monitor socket", notice.red, 6)
		return false
	end
	local_relay_socket:settimeout(0)
	local bound, binderr = local_relay_socket:setsockname("0.0.0.0", 0)
	if not bound then
		local_relay_socket:close()
		local_relay_socket = nil
		notice.new("Could not open the relay monitor socket: " .. tostring(binderr), notice.red, 6)
		return false
	end

	local_relay_heartbeat_timer = 0
	local_relay_socket:sendto(
		"RELAY~INSTANCE~" .. local_relay_instance_id .. "~HEARTBEAT",
		relay_host,
		relay_port
	)
	return true
end

--returns true if the online menu may open
function net_try_online_menu()
	if conn_state == "connected" then
		return true
	end

	if conn_state == "connecting" then
		notice.new("Please wait for\nthe game to\ntry connecting to\nthe server.", notice.red, 4)
		return false
	end

	if relay_host == "localhost" then
		relay_host = "127.0.0.1"
	end
	if is_local_relay() and not open_local_relay_monitor() then
		return false
	end

	conn_id = conn_id + 1
	conn_in = love.thread.getChannel("connin" .. conn_id)
	conn_out = love.thread.getChannel("connout" .. conn_id)
	conn_start = love.timer.getTime()
	conn_state = "connecting"
	love.thread.newThread("connectthread.lua"):start(conn_id, relay_host, relay_port, is_local_relay())

	notice.new("Connecting to\nthe internet...")
	return false
end

function net_update_local_relay(dt)
	if local_relay_socket then
		local_relay_heartbeat_timer = local_relay_heartbeat_timer + dt
		if local_relay_heartbeat_timer >= 3 then
			local_relay_heartbeat_timer = local_relay_heartbeat_timer - 3
			local_relay_socket:sendto(
				"RELAY~INSTANCE~" .. local_relay_instance_id .. "~HEARTBEAT",
				relay_host,
				relay_port
			)
		end
	end

	local spawnresult = love.thread.getChannel("relayout"):pop()
	if spawnresult then
		if spawnresult[1] == "ok" then
			local_relay_spawned = true
		else
			local_relay_start_attempted = false
			notice.new(nt(spawnresult[2]), notice.red, 6)
			conn_stop()
		end
	end

	if conn_state ~= "connecting" then
		return
	end

	local message = conn_out:pop()
	while message do
		if message[1] == "ok" then
			conn_state = "connected"
			notice.new(nt("net connected") .. " " .. format_connect_time(message[2]), {0, 255, 0})
			return
		elseif message[1] == "spawn" then
			if not local_relay_start_attempted then
				local_relay_start_attempted = true
				if not start_local_relay() then
					local_relay_start_attempted = false
					conn_stop()
					return
				end
			end
		elseif message[1] == "timeout" then
			conn_stop()
			notice.new("Connection failed.\nTry opening the\nonline menu again.", notice.red, 5)
			return
		end
		message = conn_out:pop()
	end

	if love.timer.getTime() - conn_start >= conn_timeout then
		conn_stop()
		notice.new("Connection failed.\nTry opening the\nonline menu again.", notice.red, 5)
	end
end

function net_stop_local_relay()
	conn_stop()
	if not local_relay_socket then
		return
	end
	local message = "RELAY~INSTANCE~" .. local_relay_instance_id .. "~STOP"
	for i = 1, 3 do
		local_relay_socket:sendto(message, relay_host, relay_port)
	end
	local_relay_socket:close()
	local_relay_socket = nil
	local_relay_instance_id = nil
	local_relay_start_pending = false
	local_relay_start_attempted = false
	local_relay_spawned = false
end

local function relay_error_text(code)
	if code == "room_not_found" then
		return nt("net room not found")
	elseif code == "room_full" then
		return nt("net room full")
	elseif code == "room_exists" then
		return nt("net room exists")
	elseif code == "server_full" then
		return nt("net server full")
	elseif code == "endpoint_in_use" then
		return nt("net endpoint in use")
	end
	return nt("net relay failed")
end

local function relay_update(dt)
	relay_keepalive_timer = relay_keepalive_timer + dt
	if relay_room_code and relay_room_ready and relay_keepalive_timer >= 15 then
		relay_keepalive_timer = 0
		local message = "RELAY~KEEPALIVE~" .. relay_room_code
		if SERVER then
			udp:sendto(message, relay_host, relay_port)
		elseif CLIENT then
			udp:send(message)
		end
	end

	if SERVER and not relay_room_ready then
		relay_setup_timer = relay_setup_timer + dt
		relay_retry_timer = relay_retry_timer + dt
		if relay_setup_timer >= 10 then
			notice.new("Relay did not create the room", notice.red, 5)
			net_quit()
			return true
		elseif relay_retry_timer >= 1 then
			relay_retry_timer = relay_retry_timer - 1
			udp:sendto("RELAY~CREATE~" .. relay_room_code, relay_host, relay_port)
		end
	elseif CLIENT and clientjoinpending then
		relay_setup_timer = relay_setup_timer + dt
		relay_retry_timer = relay_retry_timer + dt
		if relay_setup_timer >= 10 then
			notice.new("Could not reach the room", notice.red, 5)
			net_quit()
			return true
		elseif relay_retry_timer >= 1 then
			relay_retry_timer = relay_retry_timer - 1
			udp:send("RELAY~JOIN~" .. relay_room_code)
		end
	end
	return false
end

function net_create_room_code()
	local chars = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
	local code = {}
	for i = 1, 8 do
		local index = math.random(#chars)
		code[i] = chars:sub(index, index)
	end
	return table.concat(code)
end

function client_load(roomcode)
	if type(roomcode) ~= "string" or not roomcode:match("^[A-Z2-9]+$") or #roomcode ~= 8 then
		notice.new("Enter the 8-character room code", notice.red, 3)
		return false
	end

	relay_room_code = roomcode
	udp = socket.udp()
	if not udp then
		notice.new("Could not create network socket", notice.red, 3)
		return false
	end
	udp:settimeout(0)

	local connected, err = udp:setpeername(relay_host, relay_port)
	if not connected then
		udp:close()
		udp = nil
		notice.new("Could not connect to relay: " .. tostring(err), notice.red, 3)
		return false
	end
 
	entity = tostring(math.random(99999))
	clients = {}
	playerlist[1].id = entity
	updatetimer = 0
	actions = {}
	levelscreensync = false
	enemyspawnx = 0

	clientconnected = false
	clientconnecttimer = 0
	clientjoinpending = true
	relay_room_ready = false
	relay_keepalive_timer = 0
	relay_setup_timer = 0
	relay_retry_timer = 0
	
	SERVER = false
	CLIENT = true

	local sent, senderr = udp:send("RELAY~JOIN~" .. relay_room_code)
	if not sent then
		udp:close()
		udp = nil
		CLIENT = false
		clientjoinpending = false
		notice.new("Could not contact relay: " .. tostring(senderr), notice.red, 3)
		return false
	end
	
	return true
end

function server_load(roomcode)
	if type(roomcode) ~= "string" or not roomcode:match("^[A-Z2-9]+$") or #roomcode ~= 8 then
		notice.new("Could not create a room code", notice.red, 3)
		return false
	end

	relay_room_code = roomcode
	udp = socket.udp()
	if not udp then
		notice.new("Could not create network socket", notice.red, 3)
		return false
	end
	entity = nil
	clients = {}
	
	local bound, binderr = udp:setsockname("0.0.0.0", 0)
	if not bound then
		udp:close()
		udp = nil
		notice.new("Could not open network socket: " .. tostring(binderr), notice.red, 3)
		return false
	end
	udp:settimeout(0)
	
	updatetimer = 0
	actions = {}
	enemyspawnx = 0
	relay_keepalive_timer = 0
	relay_setup_timer = 0
	relay_retry_timer = 0
	
	SERVER = true
	CLIENT = false
	relay_room_ready = false

	local sent, senderr = udp:sendto("RELAY~CREATE~" .. relay_room_code, relay_host, relay_port)
	if not sent then
		udp:close()
		udp = nil
		SERVER = false
		notice.new("Could not contact relay: " .. tostring(senderr), notice.red, 3)
		return false
	end
	
	return true
end

function server_update(dt)
	-- SERVER CODE --
	if relay_update(dt) then
		return
	end
	
	--send
	if gamestate == "lobby" then
		--update ping
		local kickedplayer = false --not a table because only one player should be kicked in a frame (otherwise ids would get shuffled)
		for i, t in pairs(clients) do
			if clients[i].ping then
				clients[i].ping = clients[i].ping + dt
				if not kickedplayer and clients[i].ping > lobbytimeout then
					kickedplayer = clients[i].i
				end
			end
		end
		if kickedplayer then
			server_disconnect(kickedplayer)
		end
		updatetimer = updatetimer + dt
		if updatetimer > pingrate then
			for i, t in pairs(clients) do
				if not clients[i].ping then
					clients[i].ping = 0
					if t.i and playerlist[t.i] and playerlist[t.i].ping then
						udp:sendto(string.format("%s~%f", 'ping', playerlist[t.i].ping), t[1], t[2])
					end
				end
			end
	 
			updatetimer = updatetimer - pingrate
		end
	elseif gamestate == "game" or gamestate == "levelscreen" or gamestate == "sublevelscreen" then
		--one-time actions
		updatetimer = updatetimer + dt
		if updatetimer > updaterate then
			if #actions > 0 then
				local s = "" --colors
				for i2 = 1, #actions do
					s = s .. actions[i2] .. "~"
				end
				s = s:sub(1, -2)
				--for i, t in pairs(clients) do
					playerlist[1].actions = s
					--udp:sendto(string.format("%s~%s~%s", 'action', playerlist[1].id, s), t[1], t[2])
				--end
				actions = {}
			end
			for entity, t in pairs(clients) do
				for i = 1, players do
					if i ~= clients[entity].i then
						--send player actions to clients
						if playerlist[i].actions then
							udp:sendto(string.format("%s~%s~%s", 'action', playerlist[i].id, playerlist[i].actions), clients[entity][1], clients[entity][2])
						end
						--send player locations to clients
						if objects and gamestate == "game" and objects["player"][i] and (not (objects["player"][i].dead and objects["player"][i].speedy > 0)) then
							local x, y = tostring(round(objects["player"][i].x, 6)), tostring(round(objects["player"][i].y, 6))
							local speedx, speedy = tostring(round(objects["player"][i].speedx, 5) or 0), tostring(round(objects["player"][i].speedy, 5) or 0)
							local gravity, animationstate = objects["player"][i].gravity or 0, objects["player"][i].animationstate or "idle"
							local pointingangle = tostring(round(objects["player"][i].pointingangle, 4))
							if not objects["player"][i].portalgun then pointingangle = objects["player"][i].animationdirection or "right" end
							local ft = {"f", "f"}
							if speedx == math.floor(speedx) then ft[1] = "d" end; if speedy == math.floor(speedy) then ft[2] = "d" end
						
							if (objects["player"][i].speedx ~= 0 or objects["player"][i].speedy ~= 0) or
							 ((not objects["player"][i].oldx) or (objects["player"][i].oldx ~= objects["player"][i].x)) or
							 ((not objects["player"][i].oldy) or (objects["player"][i].oldy ~= objects["player"][i].y)) then
								local dg = string.format("%s~%s~%s~%s~%s~%s~%d~%s~%s", 'move', playerlist[i].id, x, y, speedx, speedy, gravity, animationstate, pointingangle)
								udp:sendto(dg, clients[entity][1], clients[entity][2])
							end
							objects["player"][i].oldx = objects["player"][i].x; objects["player"][i].oldy = objects["player"][i].y
						end
					end
				end
				for i = 1, players do
					playerlist[i].actions = false
				end
			end
			updatetimer = updatetimer - updaterate
		end
	end
	
	--recieve
	local data, msg_or_ip, port_or_nil = udp:receivefrom()
	if data and data:sub(1, 6) == "RELAY~" then
		local relaymessage = data:split("~")
		if relaymessage[2] == "CREATED" then
			relay_room_ready = true
			relay_setup_timer = 0
			relay_retry_timer = 0
		elseif relaymessage[2] == "PEER_LEFT" then
			for clientid, client in pairs(clients) do
				if client.i then
					server_disconnect(client.i)
					clients[clientid] = nil
					break
				end
			end
		elseif relaymessage[2] == "ERROR" then
			notice.new(relay_error_text(relaymessage[3]), notice.red, 5)
			net_quit()
			return
		end
	elseif data then
		print(data)
		
		--add player to list
		local t = data:split("~")
		cmd = t[2]
		local entity = t[1]
		local safe = true
		if entity and not clients[entity] then
			--clients[entity] = {msg_or_ip, port_or_nil}
			safe = false
		end
		
		--commands
		if cmd == 'connect' then
			if entity and not clients[entity] then
				clients[entity] = {msg_or_ip, port_or_nil}
			end
			if gamestate ~= "lobby" then
				--kick out during game
				notice.new("rejected player\ncant join during the game", notice.red, 3)
				udp:sendto(string.format("%s~%s", 'notice', "cant connect during the game"), clients[entity][1], clients[entity][2])
				udp:sendto('kick', clients[entity][1], clients[entity][2])
				return
			end
			if not t[6] then --no character sent, must be from v11 or lower
				notice.new("rejected player\ncant join with outdated version", notice.red, 3)
				udp:sendto(string.format("%s~%s", 'notice', "outdated game!\nyou need to be on version " .. VERSIONSTRING), clients[entity][1], clients[entity][2])
				udp:sendto('kick', clients[entity][1], clients[entity][2])
				return
			end
			local c, color = t[4]:split("|"), {}
			for i = 1, math.floor(#c/3) do
				table.insert(color, {tonumber(c[(i-1)*3+1]),tonumber(c[(i-1)*3+2]),tonumber(c[(i-1)*3+3])})
			end
			local hat = tonumber(t[5]) or 1
			if t[5] == "nil" then
				hat = nil
			end
			table.insert(playerlist, {connected=true, id=entity, hats={hat}, colors=color, nick=t[3], ping = 0, character=t[6] or false})
			setcustomplayer(playerlist[#playerlist].character, #playerlist, "initial")
			if mariocharacter[#playerlist] then --change character to mario if other character isn't loaded
				playerlist[#playerlist].character = mariocharacter[#playerlist]
			end
			clients[entity].i = #playerlist
			clients[entity].nick = t[3] or entity
			players = #playerlist
			local s = ""--player information
			for i = 1, #playerlist do
				local c = "" --colors
				for i2 = 1, #playerlist[i].colors do
					c = c .. playerlist[i].colors[i2][1] .. "|" .. playerlist[i].colors[i2][2] .. "|" .. playerlist[i].colors[i2][3] .. "|"
				end
				c = c:sub(1, -2)
				s = s .. playerlist[i].id .. ";" .. tostring(playerlist[i].nick) .. ";" .. c .. ";" .. tostring(playerlist[i].hats[1]) .. ";" .. tostring(playerlist[i].character) .. "~"
				if i ~= 1 then
					controls[i] = {}
					controls[i]["right"] = {""}
					controls[i]["left"] = {""}
					controls[i]["down"] = {""}
					controls[i]["up"] = {""}
					controls[i]["run"] = {""}
					controls[i]["jump"] = {""}
					controls[i]["aimx"] = {""} --mouse aiming, so no need
					controls[i]["aimy"] = {""}
					controls[i]["portal1"] = {""}
					controls[i]["portal2"] = {""}
					controls[i]["reload"] = {""}
					controls[i]["use"] = {""}
					clearadditionalcontrolbindings(i)
				end
			end
			s = s:sub(1, -2)
			for i, t in pairs(clients) do
				udp:sendto(string.format("%s~%d~%s", 'connect', #playerlist, s), t[1], t[2])
			end
			--send them the settings
			server_infinitelives(infinitelives, clients[entity])
			server_infinitetime(infinitetime, clients[entity])
			server_setmappack(mappack, clients[entity])
			notice.new(playerlist[players].nick .. nt("net player connected"), nil, 3)
		elseif cmd == 'pong' and safe then
			--get ping
			if clients[entity] and clients[entity].i and playerlist[clients[entity].i] then
				playerlist[clients[entity].i].ping = clients[entity].ping
				clients[entity].ping = false
			end
		elseif cmd == 'chat' and safe then
			--recieve chat message and relay to clients
			local name = t[3]
			if clients[t[3]] then
				name = clients[t[3]].nick or t[3]
			end
			if gamestate ~= "lobby" then
				notice.new(tostring(name) .. ":" .. tostring(t[4]), nil, 10)
			end
			table.insert(chatmessages, {id = entity, message = t[4]})
			if t[4] == "kappa" then
				playsound(rainboomsound)
			else
				--playsound(blockhitsound)
			end
			local dg = string.format("%s~%s~%s", 'chat', t[3], t[4])
			for i, t in pairs(clients) do
				if i ~= entity then
					udp:sendto(dg, t[1], t[2])
				end
			end
		elseif cmd == 'disconnect' and safe then
			server_disconnect(clients[entity].i)
			clients[entity] = nil
		elseif cmd == 'move' and safe then
			if objects then
				net_moveplayer(clients[entity].i, t)
			end
		elseif cmd == 'update' and safe then
			--relay player information to clients
			
		elseif cmd == 'action' and safe then
			local id = clients[entity].i
			if id and objects then
				local a = ""
				for i = 1, #t-2 do
					a = a .. t[i+2] .. "~"
					local s = t[i+2]:split("|")
					net_doaction(objects["player"][id], s)
				end
				if playerlist[id].actions then
					playerlist[id].actions = playerlist[id].actions .. "~" .. a:sub(1, -2)
				else
					playerlist[id].actions = a:sub(1, -2)
				end
			end
		elseif cmd == 'mappackerror' and safe then
			--player is missing mappack
			if guielements.mappack then
				guielements.mappack.textcolor = {127, 0, 0}
				notice.new(playerlist[clients[entity].i].nick .. " is missing the mappack!", notice.red, 5)
			end
		elseif cmd == 'quit' then
			
		else
			print("unrecognised command:", cmd)
		end
	elseif msg_or_ip ~= 'timeout' then
		print("Unknown network error: "..tostring(msg_or_ip))
		--notice.new("Unknown network error: "..tostring(msg_or_ip), notice.red, 3)
	end
end

function client_update(dt)
	-- CLIENT CODE --
	if relay_update(dt) then
		return
	end

	if spamtimer > 0 then--this is why we can't have nice things
		spamtimer = spamtimer - dt
	end

	--send
	if gamestate == "game" or gamestate == "levelscreen" or gamestate == "sublevelscreen" then
		--send player posistion
		updatetimer = updatetimer + dt
		if updatetimer > updaterate and gamestate == "game" and objects and objects["player"] and objects["player"][1] then
			local i = 1
			if (not (objects["player"][i].dead and objects["player"][i].speedy > 0)) then
				local x, y = tostring(round(objects["player"][1].x, 6)), tostring(round(objects["player"][1].y, 6))
				local speedx, speedy = tostring(round(objects["player"][1].speedx, 5) or 0), tostring(round(objects["player"][1].speedy, 5) or 0)
				local gravity, animationstate = objects["player"][1].gravity or 0, objects["player"][1].animationstate or "idle"
				local pointingangle = tostring(round(objects["player"][1].pointingangle, 4))
				if not objects["player"][1].portalgun then pointingangle = objects["player"][1].animationdirection or "right" end
				local ft = {"f", "f"}
				if speedx == math.floor(speedx) then ft[1] = "d" end; if speedy == math.floor(speedy) then ft[2] = "d" end
				
				if (objects["player"][1].speedx ~= 0 or objects["player"][1].speedy ~= 0) or ((not objects["player"][1].oldx) or (objects["player"][1].oldx ~= objects["player"][1].x)) or ((not objects["player"][1].oldy) or (objects["player"][1].oldy ~= objects["player"][1].y)) then
					local dg = string.format("%s~%s~%s~%s~%s~%s~%d~%s~%s", entity, 'move', x, y, speedx, speedy, gravity, animationstate, pointingangle)
					udp:send(dg)
				end
				objects["player"][1].oldx = objects["player"][1].x; objects["player"][1].oldy = objects["player"][1].y
		
				--local dg = string.format("%s~%s", entity, 'update')
				--udp:send(dg)
			end
	 
			updatetimer = updatetimer - updaterate
		end
		
		--one-time actions
		if #actions > 0 then
			local s = "" --colors
			for i2 = 1, #actions do
				s = s .. actions[i2] .. "~"
			end
			s = s:sub(1, -2)
			udp:send(string.format("%s~%s~%s", entity, 'action', s))
			actions = {}
		end
	end
 
	--recieve
	repeat
		local data, msg = udp:receive()
		if data then
			if data:sub(1, 6) == "RELAY~" then
				local relaymessage = data:split("~")
				if relaymessage[2] == "JOINED" and clientjoinpending then
					clientjoinpending = false
					relay_room_ready = true
					relay_setup_timer = 0
					relay_retry_timer = 0
					clientconnecttimer = 0
					local s = ""
					for i = 1, #mariocolors[playerconfig] do
						s = s .. mariocolors[playerconfig][i][1] .. "|" .. mariocolors[playerconfig][i][2] .. "|" .. mariocolors[playerconfig][i][3] .. "|"
					end
					s = s:sub(1, -2)
					local dg = string.format("%s~%s~%s~%s~%s~%s", entity, 'connect', localnick, s, mariohats[playerconfig][1], tostring(mariocharacter[playerconfig]))
					udp:send(dg)
				elseif relaymessage[2] == "ERROR" then
					net_quit()
					notice.new(relay_error_text(relaymessage[3]), notice.red, 5)
					return
				elseif relaymessage[2] == "CLOSED" then
					net_quit()
					notice.new("The host closed the room", notice.red, 5)
					return
				end
			else
			local t = data:split("~")
			local cmd = t[1]
			if cmd == 'connect' then
				if gamestate == "lobby" then
					clientconnected = true
					--update player list
					players = tonumber(t[2])
					playerlist = {{connected=true, hats=mariohats[playerconfig], colors=mariocolors[playerconfig], nick=localnick, id=entity, character=mariocharacter[playerconfig]}}
					local id, nick, color, hats, p
					for i = 1, players do
						local t2 = t[2+i]:split(";")
						id, nick, color, hats, character = t2[1], t2[2], {}, tonumber(t2[4]) or 1, t2[5]
						if id ~= playerlist[1].id then
							if t2[3] then
								local c = t2[3]:split("|")
								for i2 = 1, math.floor(#c/3) do
									table.insert(color, {tonumber(c[(i2-1)*3+1]),tonumber(c[(i2-1)*3+2]),tonumber(c[(i2-1)*3+3])})
								end
							end
							if character == "false" then
								character = "mario"
							end
							if t2[4] == "nil" then
								hats = nil
							end
							table.insert(playerlist, {connected=true, id=id, hats={hats}, colors=color, nick=nick, ping = 0, character=character or false})
							setcustomplayer(playerlist[#playerlist].character, #playerlist, "initial")
						end
						if i ~= 1 then
							controls[i] = {}
							controls[i]["right"] = {""}
							controls[i]["left"] = {""}
							controls[i]["down"] = {""}
							controls[i]["up"] = {""}
							controls[i]["run"] = {""}
							controls[i]["jump"] = {""}
							controls[i]["aimx"] = {""} --mouse aiming, so no need
							controls[i]["aimy"] = {""}
							controls[i]["portal1"] = {""}
							controls[i]["portal2"] = {""}
							controls[i]["reload"] = {""}
							controls[i]["use"] = {""}
							clearadditionalcontrolbindings(i)
						end
					end
				end
			elseif cmd == 'ping' then
				--get ping
				playerlist[1].ping = tonumber(t[2])
				udp:send(string.format("%s~%s", entity, 'pong'))
			elseif cmd == 'start' then
				--start game
				for i = 1, players do
					if playerlist[i] then
						if playerlist[i].character then
							setcustomplayer(playerlist[i].character, i, "initial")
						end
						mariocolors[i] = playerlist[i].colors
						mariohats[i] = playerlist[i].hats
					end
				end
				game_load()--true)
			elseif cmd == 'levelscreen' then
				if gamestate ~= "levelscreen" or gamestate ~= "sublevelscreen" then
					levelscreen_load(t[2], tonumber(t[3]))
				end
				marioworld = tonumber(t[4]) or t[4] or marioworld
				mariolevel = tonumber(t[5]) or t[5] or mariolevel
				mariosublevel = tonumber(t[6]) or t[6] or mariosublevel
				--sublevelscreen_level = mariosublevel
				actualsublevel = mariosublevel
			elseif cmd == 'levelscreensync' then
				levelscreensync = true
				levelscreentimer = blacktime
			elseif cmd == 'chat' then
				--recieve chat message
				if gamestate ~= "lobby" then
					notice.new(tostring(t[2]) .. ":" .. tostring(t[3]), nil, 10)
				end
				table.insert(chatmessages, {id = t[2], message = t[3]})
				if t[3] == "kappa" then
					playsound(rainboomsound)
				else
					--playsound(blockhitsound)
				end
			elseif cmd == 'move' then
				if objects then
					local i
					for p = 1, players do
						if t[2] == playerlist[p].id then
							i = p
							break
						end
					end
					if i then
						net_moveplayer(i, t)
					end
				end
			elseif cmd == 'action' then
				local id
				for p = 1, players do
					if t[2] == playerlist[p].id then
						id = p
						break
					end
				end
				if id and objects then
					for i = 1, #t-2 do
						local s = t[i+2]:split("|")
						net_doaction(objects["player"][id], s)
					end
				end
			elseif cmd == 'infinitelives' then
				infinitelives = (t[2] == "true")
				if guielements.infinitelives then
					guielements.infinitelives.var = infinitelives
				end
			elseif cmd == 'infinitetime' then
				infinitetime = (t[2] == "true")
				if guielements.infinitetime then
					guielements.infinitetime.var = infinitetime
				end
			elseif cmd == 'mappack' then
				local target = t[2]
				if mappack ~= t[2] and mappacklist then
					for i = 1, #mappacklist do
						--find and set mappack
						if mappacklist[i] == target then
							mappack = target
							if mappackbackground and mappackbackground[mappackselection] then
								loadbackground(mappackbackground[mappackselection] .. ".txt")
							else
								loadbackground("1-1.txt")
							end
							mappackselection = i
							if guielements.mappack then
								guielements.mappack.text = target:lower()
								guielements.mappack.textcolor = {127, 127, 127}
							end
							break
						end
						--didn't find mappack, send message
						if i == #mappacklist then
							if guielements.mappack then
								guielements.mappack.text = target:lower()
								guielements.mappack.textcolor = {127, 0, 0}
							end
							notice.new("missing mappack!", notice.red)
							udp:send(string.format("%s~%s", entity, 'mappackerror'))
						end
					end
				end
			elseif cmd == 'disablecheats' then
				playertype = "portal"
				playertypei = 1
				bullettime = false
				speedtarget = 1
				portalknockback = false
				bigmario = false
				goombaattack = false
				sonicrainboom = false
				playercollisions = false
				--infinitetime = false
				--infinitelives = false
				notice.new("cheats disabled", nil, 3)
			elseif cmd == 'lobby' then
				if gamestate ~= "lobby" then
					love.audio.stop()
					lobby_load()
				end
			elseif cmd == 'notice' then
				notice.new("Server:" .. t[2], notice.red)
			elseif cmd == 'kick' then
				net_quit()
				notice.new("Kicked from server", notice.red)
			else
				print("unrecognised command:", cmd)
			end
			end
		elseif msg ~= 'timeout' then 
			print("Network error: "..tostring(msg))
			notice.new("Network error: "..tostring(msg), notice.red, 3)
			net_quit()
		end
	until not data

	--make sure client is actually connected
	if not clientconnected and not clientjoinpending then
		clientconnecttimer = clientconnecttimer + dt
		if clientconnecttimer > clientconnecttime then
			net_quit()
			notice.new("Could not connnect", notice.red)
			return
		end
	end
end

function server_start()
	for i = 1, players do
		if playerlist[i] then
			if playerlist[i].character then
				setcustomplayer(playerlist[i].character, i, "initial")
			end
			mariocolors[i] = playerlist[i].colors
			mariohats[i] = playerlist[i].hats
		end
	end
	for i, t in pairs(clients) do
		udp:sendto(string.format("%s~%d~%d", 'start', #playerlist, 0), t[1], t[2])
	end
	players = #playerlist
	game_load()--true)
end

function server_lobby()
	for i, t in pairs(clients) do
		udp:sendto(string.format("%s", 'lobby'), t[1], t[2])
	end
end

function net_quit()
	if CLIENT then
		if udp then
			if not clientjoinpending then
				udp:send(string.format("%s~%s", entity, 'disconnect'))
			end
			if relay_room_code then
				udp:send("RELAY~DETACH~" .. relay_room_code)
			end
		end
	elseif SERVER then
		for i, t in pairs(clients) do
			udp:sendto("kick", t[1], t[2])
		end
		if udp and relay_room_code then
			udp:sendto("RELAY~LEAVE~" .. relay_room_code, relay_host, relay_port)
		end
	end
	
	players = 1
	gamestate = "menu"
	menu_load()
	if udp then
		udp:close()
	end
	udp = nil
	relay_room_code = nil
	clientjoinpending = false
	relay_keepalive_timer = 0
	relay_room_ready = false
	relay_setup_timer = 0
	relay_retry_timer = 0
	SERVER = false
	CLIENT = false
	
	loadconfig("nodefaultconfig")
	loadbackground("1-1.txt")
	setcustomplayer(mariocharacter[1], 1, "initial")
end

function server_levelscreen(reason, subleveli)
	if SERVER then
		for i, t in pairs(clients) do
			udp:sendto(string.format('levelscreen~%s~%s~%s~%s~%s', tostring(reason), tostring(subleveli), tostring(marioworld), tostring(mariolevel), tostring(actualsublevel)), t[1], t[2])
		end
	end
end

function net_levelscreensync()
	if not SERVER and not CLIENT then
		return true
	elseif SERVER then
		for i, t in pairs(clients) do
			udp:sendto('levelscreensync', t[1], t[2])
		end
		return true
	elseif levelscreensync then
		levelscreensync = false
		return true
	end
	return false
end


function net_sendchat(s)
	table.insert(chatmessages, {id = playerlist[1].id, message = s})
	if SERVER then
		local dg = string.format("%s~%s~%s", 'chat', playerlist[1].id, s)
		for i, t in pairs(clients) do
			udp:sendto(dg, t[1], t[2])
		end

		--commands
		if gamestate == "game" and s:find("/") then
			net_command(s)
		elseif s == "/disablecheats" then
			for i, t in pairs(clients) do
				udp:sendto('disablecheats', t[1], t[2])
			end
			notice.new("cheats disabled", nil, 3)
		end
	else
		if spamcounter > spammercount then
			return false
		elseif spamtimer <= 0 then
			spamtimer = spamtime
		else
			spamcounter = spamcounter + 1
		end
		local dg = string.format("%s~%s~%s~%s", entity, 'chat', playerlist[1].id, s)
		udp:send(dg)
	end
end

function net_command(s)
	local s = s:sub(2,-1)
	if s == "nextlevel" then
		nextlevel()
		server_infinitetime(infinitetime, clients[entity])
		notice.new("skipped level", nil, 3)
	elseif s == "reload" then
		levelscreen_load("death")
		notice.new("reloaded level", nil, 3)
	elseif s:sub(1,5) == "level" then
		local v = s:split(" ")
		love.audio.stop()
		
		--why do sublevels suck so much
		marioworld = tonumber(v[2]) or marioworld
		mariolevel = tonumber(v[3]) or mariolevel
		mariosublevel = tonumber(v[4]) or mariosublevel
		testlevelworld = marioworld
		testlevellevel = mariolevel
		actualsublevel = mariosublevel
		respawnsublevel = mariosublevel
		levelscreen_load("animation")
		mariosublevel = tonumber(v[4]) or mariosublevel
		actualsublevel = mariosublevel
		respawnsublevel = mariosublevel
		notice.new("skipped level", nil, 3)
	elseif s == "infinitelives" then
		infinitelives = not infinitelives
		server_infinitelives(infinitelives, clients[entity])
		notice.new("set infinite lives to " .. tostring(infinitelives), nil, 3)
	elseif s == "infinitetime" then
		infinitetime = not infinitetime
		server_infinitetime(infinitetime, clients[entity])
		notice.new("set infinite time to " .. tostring(infinitetime), nil, 3)
	end
end

function net_action(i, a, t) --player no?, action name, argument
	if (CLIENT or SERVER) and i == 1 then
		if t then
			table.insert(actions, a .. "|" .. t)
		else
			table.insert(actions, a)
		end
	end
end

function server_disconnect(removei)
	if (not removei) or (not playerlist[removei]) then
		--sometimes the player never connected in the first place. ugh
		notice.new("failed to remove player " .. tostring(removei), notice.red, 3)
		return
	end
	playerlist[removei].connected = false
	notice.new(playerlist[removei].nick .. " disconnected", nil, 3)
	table.remove(playerlist, removei)
	players = players - 1
	local s = ""--player information
	for i = 1, #playerlist do
		local c = "" --colors
		for i2 = 1, #playerlist[i].colors do
			c = c .. playerlist[i].colors[i2][1] .. "|" .. playerlist[i].colors[i2][2] .. "|" .. playerlist[i].colors[i2][3] .. "|"
		end
		c = c:sub(1, -2)
		s = s .. playerlist[i].id .. ";" .. tostring(playerlist[i].nick) .. ";" .. c .. ";" .. tostring(playerlist[i].hats[1]) .. ";" .. tostring(playerlist[i].character) .. "~"
	end
	s = s:sub(1, -2)

	local delete = {}
	for i, t in pairs(clients) do
		if t.i then
			if t.i ~= removei then
				if t.i >= removei then
					t.i = t.i - 1
				end
				udp:sendto(string.format("%s~%d~%s", 'connect', #playerlist, s), t[1], t[2])
			else
				table.insert(delete,i) --remove if has id of player being kicked
			end
		else
			table.insert(delete,i) --remove if no id
		end
	end
	--table.sort(delete, function(a,b) return a>b end)
	
	for i, v in pairs(delete) do
		--table.remove(clients, v) --remove
		clients[v] = nil
		print("removed client: " .. tostring(v))
	end
end

function net_moveplayer(player, t)
	if not (objects and objects["player"] and objects["player"][player]) then
		return
	end
	objects["player"][player].x = tonumber(t[3])
	objects["player"][player].y = tonumber(t[4])
	objects["player"][player].speedx = tonumber(t[5])
	objects["player"][player].speedy = tonumber(t[6])
	objects["player"][player].gravity = tonumber(t[7])
	objects["player"][player].animationstate = t[8]
	if objects["player"][player].animationstate == "dead" then
		if (not objects["player"][player].dead) then
			objects["player"][player]:die("lava")
		end
		objects["player"][player].dead = true
	end
	objects["player"][player]:setquad(t[8])
	if tonumber(t[9]) then
		objects["player"][player].pointingangle = tonumber(t[9])
	else --no portal gun
		objects["player"][player].animationdirection = t[9]
	end
end

function net_spawnenemy(x, y)
	if (CLIENT or SERVER) and x > enemyspawnx then
		enemyspawnx = x
		local dospawn = true
		--[[for i = 1, #enemiesspawned do
			if x == enemiesspawned[i][1] then
				dospawn = false
				break
			end
		end]]
		if dospawn then
			net_action(1, "se|" .. x)
		end
	end
end

function net_doaction(player, s)
	if not (objects and player) then --make sure gamestarted
		return
	end
	if s[1] == 'jump' then
		player:jump()
	elseif s[1] == 'duck' then
		player:duck(true)
	elseif s[1] == 'unduck' then
		player:duck(false)
	elseif s[1] == 'die' then
		player.netaction = true
		player:die(s[2])
		player.netaction = nil
	elseif s[1] == 'grow' then
		player.netaction = true
		player:grow(tonumber(s[2]))
		player.netaction = nil
	elseif s[1] == 'pipe' then
		player:pipe(tonumber(s[2]), tonumber(s[3]), s[4], tonumber(s[5]))
		print(unpack(s))
	elseif s[1] == 'warppipe' then
		player:pipe(tonumber(s[2]), tonumber(s[3]), s[4], tonumber(s[5]))
	elseif s[1] == 'door' then
		player:door(tonumber(s[2]), tonumber(s[3]), s[4])
	elseif s[1] == 'upkey' then
		player:upkey()
	elseif s[1] == 'fire' then
		player:fire()
	elseif s[1] == 'portal' then
		player.pointingangle = tonumber(s[5])
		shootportal(player.playernumber, tonumber(s[2]), tonumber(s[3]), tonumber(s[4]), tonumber(s[5]))
	elseif s[1] == 'removeportals' then
		player:removeportals()
	elseif s[1] == 'use' then
		player.pointingangle = tonumber(s[2])
		player:use()
	elseif s[1] == "levelball" then
		if not levelfinished then
			for i = 1, players do
				local obj = levelball:new(objects["player"][i].x+6/16, objects["player"][i].y+11/16)
				table.insert(objects["levelball"], obj)
				obj.drawable = false
				obj.sound = dailychallenge and dcwin2sound or bowserendsound
				obj.autodelete = false
			end
		end
	elseif s[1] == 'hitblock' then
		local x, y = tonumber(s[2]), tonumber(s[3])
		local offset = false --make sure block wasn't already hit
		if getblockbounce(x, y) then
			offset = true
		end
		if not offset then
			hitblock(x, y, {size = tonumber(s[4])}, {})
		end
	elseif s[1] == "grabfence" then
		player:grabfence()
	elseif s[1] == "dropfence" then
		player:dropfence()
	elseif s[1] == "shoed" then
		local shoe = s[2]
		if shoe == "false" then
			shoe = false
		end
		player:shoed(shoe, s[3] == "true", s[4] == "true")
	elseif s[1] == 'se' then --spawn enemy
		local x = tonumber(s[2])
		for y = 1, mapheight do
			spawnenemyentity(x, y)
		end
	end
end

function server_infinitelives(bool, t) --true?, client
	if t then
		udp:sendto(string.format("%s~%s", 'infinitelives', tostring(bool) or true), t[1], t[2])
	else
		for i, t in pairs(clients) do
			udp:sendto(string.format("%s~%s", 'infinitelives', tostring(bool) or true), t[1], t[2])
		end
	end
end

function server_infinitetime(bool, t)
	if t then
		udp:sendto(string.format("%s~%s", 'infinitetime', tostring(bool) or true), t[1], t[2])
	else
		for i, t in pairs(clients) do
			udp:sendto(string.format("%s~%s", 'infinitetime', tostring(bool) or true), t[1], t[2])
		end
	end
end

function server_setmappack(m, t)
	if t then
		udp:sendto(string.format("%s~%s", 'mappack', m), t[1], t[2])
	else
		mappack = mappacklist[mappackselection]
		if mappackbackground and mappackbackground[mappackselection] then
			loadbackground(mappackbackground[mappackselection] .. ".txt")
		else
			loadbackground("1-1.txt")
		end
		local s = string.format("%s~%s", 'mappack', m)
		for i, t in pairs(clients) do
			udp:sendto(s, t[1], t[2])
		end
	end
end

function net_getroomcode()
	if relay_room_ready then
		return relay_room_code
	end
end
