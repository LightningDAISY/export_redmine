module('AimiUtil', package.seeall)

function split(str,pattern,limiter)
	limiter = limiter or nil
	pattern = '(.-)' .. '(' .. pattern .. ')'
	local result = {}
	local offset = 0;
	local counter = 1
	if limiter == 1 then
		table.insert(result, str)
		return result
	end
	for part,sep in string.gmatch(str, pattern) do
		counter = counter + 1
		offset = offset + string.len(part) + string.len(sep)
		table.insert(result, part)
		if limiter and limiter <= counter then
			break
		end
	end
	if(string.len(str) > offset) then
		table.insert(result, string.sub(str,offset + 1))
	end
	return result
end

function dump(obj)
	if type(obj) ~= 'table' then return obj end
	local result = ''
	for key,value in pairs(obj) do
		if type(value) == 'table' then value = '(TABLE)' end
		result = result .. key .. ' => ' .. value .. ",\n"
	end
	return result
end

function datetime_full(time)
	time = time or os.time()
	local wd = os.date('%w', time)
	local wn = { 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' }
	return os.date('%Y-%m-%d[', time) .. wn[tonumber(wd)] .. os.date('] %H:%M:%S %Z', time)
end

function datetime_int(time)
	time = time or os.time()
	return os.date('%Y%m%d%H%M%S', time)
end

function fileExists(fname)
   local fp = io.open(fname,"r")
   if fp then io.close(fp) return true else return false end
end

function reverse(tbl)
	for i=1, math.floor(#tbl / 2) do
		tbl[i], tbl[#tbl - i + 1] = tbl[#tbl - i + 1], tbl[i]
	end
end

function loadFile(filename)
	local file = io.open(filename, 'r')
	if not file then throw(500, filename .. ' is not found.') end
	local fBody = ''
	for line in file:lines() do
		fBody = fBody .. line .. "\n"
	end
	file:close()
	return fBody
end

function saveFile(filename,fBody)
	local file = io.open(filename, 'w')
	if not file then throw(500, 'cannot write ' .. fname .. ".") end
	file:write(fBody)
	file:close()
end

function loadJSON(filename)
	local cjson = require 'cjson'
	local fbody = loadFile(filename)
	return cjson.decode(fbody)
end

function loadIni(filename)
	local file = io.open(filename, 'r')
	local hash = {}
	local section
	if not file then return {} end
	for line in file:lines() do
		local tempSection = line:match('^%[([^%[%]]+)%]$')
		if(tempSection) then
			section = tonumber(tempSection) and tonumber(tempSection) or tempSection
			hash[section] = hash[section] or {}
		end
		local param, value = line:match('^([%w|_]+)%s-=%s-(.+)$')
		if(param and value ~= nil) then
			if(tonumber(value)) then
				value = tonumber(value)
			elseif(value == 'true') then
				value = true
			elseif(value == 'false') then
				value = false
			end
			if(tonumber(param)) then
				param = tonumber(param)
			end
			hash[section][param] = value
		end
	end
	file:close()
	return hash
end

function tableMerge(t1, t2)
	for k,v in pairs(t2) do
		if type(v) == "table" then
			if type(t1[k] or false) == "table" then
				tableMerge(t1[k] or {}, t2[k] or {})
			else
				t1[k] = v
			end
		else
			t1[k] = v
		end
	end
	return t1
end

function trim(str)
	return str:gsub("^%s+", ''):gsub("%s+$", '')
end

--
-- local str = Util.dumper({ a = "A", b = "B"})
-- print(str)
--
function dumper(struct, deep, result)
	result = result or ''
	deep = deep or 0
	deep = deep + 1

	local indent = ""
	for i=deep, 0, -1 do indent = indent .. "  " end
	result = result .. indent .. "{" .. "\n"

	if type(struct) ~= "table" then return struct .. "\n" end
	for key,val in pairs(struct) do
		indent = ''
		if type(val) == "table" then
			for i=deep+1, 0, -1 do indent = indent .. "  " end
			result = result .. indent .. key .. "\n"
			result = dumper(val, deep, result)
		else
			local indent = ""
			for i=deep+1, 0, -1 do indent = indent .. "  " end
			if type(val) == "boolean" then
				local trueOrFalse = "(false)"
				if val then trueOrFalse = "(true)" end
				result = result .. indent .. key .. " : " .. trueOrFalse .. "\n"
			elseif type(val) == "function" then
				result = result .. indent .. key .. " : (function)\n"
			else
				result = result .. indent .. key .. " : " .. val .. "\n"
			end
		end
	end

	indent = ""
	for i=deep, 0, -1 do indent = indent .. "  " end
	result = result .. indent .. "}" .. "\n"
	deep = deep - 1
	return result .. "\n"
end

function tohex(str)
    local hexstr = '0123456789abcdef'
    local s = ''
	local num = tonumber(str)
    while num > 0 do
        local mod = math.fmod(num, 16)
        s = string.sub(hexstr, mod+1, mod+1) .. s
        num = math.floor(num / 16)
    end
    if s == '' then s = '0' end
    return s
end

function toPascalCase(str)
	str = str:lower()
	local letterFirst = str:sub(1,1)
	letterFirst = letterFirst:upper()
	return letterFirst .. str:sub(2,str:len())
end

function utf8()
	return require 'aimi.util.utf8_simple'
end

function md5(str)
	if type(str) == 'number' then str = tostring(str) end
	return ngx.md5(str)
end

return AimiUtil

-----------------------------------------------------------
-- いちいちrequireして使います。
-- （一度requireされたファイルはLua内でキャッシュされます）
-- 以下の要領で.（ドット）でcallする点だけ注意しましょう。
--
-- local util = require 'aimi.util'
-- local md5String = util.md5('xyz')
-----------------------------------------------------------
