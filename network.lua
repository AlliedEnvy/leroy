local socket = require('socket')

math.randomseed(os.time()); math.random(); math.random(); math.random();

local conn = nil
local queue, sq_top, sq_bottom = {}, 1, 1

function send_enqueue(command, use_separator, ...)
	queue[sq_bottom] = {command, use_separator, {...}}
	sq_bottom = sq_bottom +1
end

function send_dequeue()
	if sq_top == sq_bottom then return nil end
	local command = queue[sq_top][1]
	local use_separator = #queue[sq_top] > 1 and queue[sq_top][2] or nil
	local arg = #queue[sq_top] > 2 and queue[sq_top][3] or {}
	queue[sq_top] = nil
	sq_top = sq_top +1
	if sq_top == sq_bottom then sq_top, sq_bottom = 1, 1 end
	return send(command, use_separator, unpack(arg))
end

function connect(network, port)
	conn = socket.tcp()
	local result, err = conn:connect(network, port)
	conn:settimeout(0.1)
end

function send(command, use_separator, ...)
	local str = command
	local arg = {...}
	if #arg > 0 then
		local sep = use_separator and ' :' or #arg > 1 and ' ' or ''
		str = str  .. ' ' .. table.concat(arg, ' ', 1 , #arg-1) .. sep .. arg[#arg]
	end
	print(str)
	return conn:send(str .. '\r\n')
end

function pass(password) return send_enqueue('PASS', false, password) end
function nick(nickname) return send_enqueue('NICK', false, nickname) end
function user(username, usermode, unused, realname)
	return send_enqueue('USER', true, username, usermode, unused, realname)
end
-- server, oper not likely aused
function quit(quitmsg)
	if quitmsg then return send_enqueue('QUIT', true, quitmsg)
	else return send_enqueue('QUIT') end
end
-- squit not likely used
function join(channels, keys)
	if keys then return send_enqueue('JOIN', false, channels, keys)
	else return send_enqueue('JOIN', false, channels) end
end
function part(channels) return send_enqueue('PART', false, channels) end
function mode_chan(channel, modestring) return send_enqueue('MODE', false, channel, modestring) end
-- mode_user not likely used
function topic(channel, topicstr)
	if topicstr then return send_enqueue('TOPIC', true, channel, topicstr)
	else return send_enqueue('TOPIC') end
end
-- names not used yet
-- list not used yet
-- invite
function kick(channels, users, message)
	if message then return send_enqueue('KICK', true, channels, users, message)
	else return send_enqueue('KICK', false, channels, users) end
end
-- server queries/commands not likely used
function privmsg(recipients, text) return send_enqueue('PRIVMSG', true, recipients, text) end
function notice(recipients, text) return send_enqueue('NOTICE', true, recipients, text) end
-- user queries not likely used
-- kill not likely used
function ping(str) return send_enqueue('PING', false, str) end
function pong(str) return send_enqueue('PONG', false, str) end
-- error not likely used

function tokenize_line(line)
	local s, e, prefix = line:find('^:(%S+)')
	local s, e, command = line:find('(%S+)', e and e+1 or 1)
	local s, e, rest = line:find('%s+(.*)', e and e+1 or 1)
	return prefix, command, rest
end

local replies = {}

replies.PING = function(prefix, rest)
	pong(rest)
end

local http = require('socket.http')
dofile('music_genres.lua')
dofile('calc.lua')
local NSRX = require('NSRX')

local authed = {}
for line in io.lines("authed.txt") do
	authed[line] = true
end

function os.capture(cmd, raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if raw then return s end
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  s = string.gsub(s, '%s+', ' ')
  return s
end

replies.PRIVMSG = function(prefix, rest)
	local chan = rest:match('(%S+)')
	local msg = rest:match(':(.*)')
	local nick = prefix:match('(%S+)!')
	local host = prefix:match('@(%S+)')
	local user = prefix:match('!(%S+)')

	if not chan:find('^#') then
		chan = nick
	end

	if msg:find('^!help') then
		privmsg(chan, '!down !flip !fortune !genre !math !word')
	end
	if msg:find('^!calc') then
		privmsg(chan, "Use !math now, to avoid pinging you-know-who.")
	end
	if msg:find('^!math') then
		local str = msg:match('^!math (.*)')
		local result, err = nil, 0
		if str then
			result, err = calculate(str)
			if not result then
				result = err
			end
		else result = "Usage: !math <mathematical expression>"
		end
		privmsg(chan, nick .. ': ' ..(result or 'Syntax error.'))
	end
	if msg:find('^!flip') then
		if math.random(2) == 1 then
			privmsg(chan, "Heads.")
			mode_chan(chan, '+o '.. nick)
		else
			privmsg(chan, "Tails.")
			mode_chan(chan, '+b '.. '*!*@'..host)
			kick(chan, nick, 'bang.')
		end
	end
	if msg:find('^!down') then
		local site = msg:match('^!down (%S+)')
		if not site then
			privmsg(chan, 'Usage: !down www.example.com')
		else
			local req = http.request('http://www.isup.me/'..socket.url.escape(site))
			if not req then
				privmsg('Error connecting to http://www.isup.me/ . Seems to be down.')
			else
				if req:find("It's just you.") then
					privmsg(chan, "It's just you, ".. site .. ' seems to be up.')
				elseif req:find("It's not just you!") then
					privmsg(chan, 'Yup, '..site .. ' is down.')
				elseif req:find('Huh?') then
					privmsg(chan, site.." isn't a valid URL.")
				else
					privmsg(chan, "I can't tell if "..site.." is up or not.")
				end
			end
		end
	end
	if msg:find('^!fortune') then
		privmsg(chan, os.capture('fortune -s fortunes platitudes cookie'))
	end
	if msg:find('^!genre') then
		privmsg(chan, prefixes[math.random(#prefixes)]..' '..suffixes[math.random(#suffixes)])
	end
	if msg:find("let's do this") and nick == 'AlliedEnvy' then
		privmsg(chan, "LEEEEEEEEEEEEEROY")
		privmsg(chan, "JENKINS")
		privmsg('chanserv', "clear "..chan.." users")
	end
	if msg:find('^!word') then
		local str = ''
		for i = 1, 4 do
			str = str.. string.char(math.random(26)-1+string.byte('a'))
		end
		privmsg(chan, str)
	end
	if chan == "#NSRX" then
		NSRX:parseCommand(nick, msg)
	end
	if msg:find('^!auth') and authed[user] then
		local entry = msg:match('%w+@.+$')
		if entry and not authed[entry] then
			authed[entry] = true
			local file = io.open("authed.txt", "w+")
			for entry,_ in pairs(authed) do
				file:write(entry .."\n")
			end
			file:flush()
			file:close()
			privmsg(chan, "Successfully added "..entry)
		elseif authed[entry] then
			privmsg(chan, "That user is already authorized.")
		else
			privmsg(chan, "Not a valid entry. Should be username and hostname.")
		end
	end
end

function main()
	while true do
		connect('irc.mountai.net', 6667)
		nick('Leroy')
		user('Leroy', '0', '*', 'baddest man in the whole damn town')
		join('#Leroy')
		join('#n')
		join('#NSRX')

		while true do
			send_dequeue()
			line, err = conn:receive('*l')
			if line then
				print(line)
				prefix, command, rest = tokenize_line(line)
				if replies[command] then replies[command](prefix, rest) end
			elseif err == 'closed' then
				break
			end
		end

		socket.sleep(10)

		--quit('this has been a test.')

		conn:close()
	end
end
