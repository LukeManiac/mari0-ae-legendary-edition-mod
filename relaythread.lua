require "love.system"

local channelin = love.thread.getChannel("relayin")
local channelout = love.thread.getChannel("relayout")

local function shell_quote(value, osname)
	if osname == "Windows" then
		return '"' .. value:gsub('"', '""') .. '"'
	end
	return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function file_exists(path)
	local handle = io.open(path, "rb")
	if handle then
		handle:close()
		return true
	end
	return false
end

local function find_bundled_python(osname, base_dir)
	if not base_dir or base_dir == "" then
		return nil
	end
	local path
	if osname == "Windows" then
		path = (base_dir .. "/python/pythonw.exe"):gsub("/", "\\")
	else
		path = base_dir .. "/python/bin/python3"
	end
	if file_exists(path) then
		return path
	end
end

local function find_relay_python(osname)
	local command
	if osname == "Windows" then
		command = "where.exe pythonw.exe 2>NUL"
	else
		command = "command -v python3 2>/dev/null"
	end

	local pipe = io.popen(command, "r")
	if not pipe then
		return nil
	end
	local executable = pipe:read("*l")
	pipe:close()
	if executable and executable ~= "" then
		return executable
	end
end

local job = channelin:demand()
local osname = job.osname

local executable = find_bundled_python(osname, job.bundled_dir) or find_relay_python(osname)
if not executable then
	channelout:push({"error", "net needs python"})
	return
end

local command
if osname == "Windows" then
	command = "start \"\" /B " .. shell_quote(executable, osname) .. " " .. shell_quote(job.script_path, osname)
		.. " --host 127.0.0.1 --port " .. tostring(job.port)
		.. " --managed --owner-pid " .. job.process_id .. " >NUL 2>&1"
else
	command = shell_quote(executable, osname) .. " " .. shell_quote(job.script_path, osname)
		.. " --host 127.0.0.1 --port " .. tostring(job.port)
		.. " --managed --owner-pid " .. job.process_id .. " >/dev/null 2>&1 &"
end

local launched, _, code = os.execute(command)
if launched ~= true and launched ~= 0 and code ~= 0 then
	channelout:push({"error", "net relay start error"})
	return
end
channelout:push({"ok"})