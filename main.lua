#! /usr/bin/env lua
package.path =	'./libs/?.lua;' .. package.path
local Util = require 'aimi/util'
local JSON = require 'json'
local Config = require 'aimi/config'
local conf = Config:new():load('etc/config.ini')
local columnNames = {
	"検知日時",
	"障害内容",
	"対応内容",
	"起因",
	"原因",
	"影響人数",
	"被害想定額",
	"補填内容",
	"再発防止策",
	"備考",
}

local userCache = {}

function char2hex(char)
	return string.format("%%%02X", string.byte(char))
end

function hex2char(x)
	return string.char(tonumber(x, 16))
end

function uriEscape(uri)
	if not uri then return end
	uri = uri:gsub("\n", "\r\n")
	uri = uri:gsub("([^%w ])", char2hex)
	uri = uri:gsub(" ", "+")
	return uri
end

function uriUnescape(uri)
	if not uri then return end
	uri = uri:gsub("+", " ")
	uri = url:gsub("%%(%x%x)", hex2char)
	return uri
end

function setDefaultHeader(reqHeader)
	reqHeader = reqHeader or {}
	reqHeader["Content-Type"] = reqHeader["Content-Type"] or "application/x-www-form-urlencoded"
	reqHeader["Host"] = conf.redmine.host .. ":" .. conf.redmine.port
	reqHeader["Origin"] = conf.redmine.scheme .. '://' .. conf.redmine.host .. ":" .. conf.redmine.port
	reqHeader["Accept-Language"] = "ja-jp"
	reqHeader["Accept"] = "text/html,*/*;q=0.8"
	--reqHeader["X-Redmine-Switch-User"] = conf.redmine.username
	--reqHeader["X-Redmine-API-Key"] = conf.redmine.password
	return reqHeader
end

function getToken()
	local HTTPRequest = require 'http/request'
	local req = HTTPRequest:new()
	local code,resBody,resHeaders = req:simple(
		conf.scheme,
		'GET',
		conf.redmine.host,
		conf.redmine.port,
		conf.uris.login
	)
	local reqHeader = setDefaultHeader()
	-- local token = resBody:match('<meta name="csrf-token" content="([^"]+)')
	local token = resBody:match('<meta name="csrf%-token" content="([^"]+)"')
	local cookie = resHeaders["set-cookie"]:match("[^;]+")
	return token,cookie,code
end

function getSession(token,reqHeader)
	local reqBody = string.format(
		"username=%s&password=%s&authenticity_token=%s",
		uriEscape(conf.redmine.username),
		uriEscape(conf.redmine.password),
		uriEscape(token)
	)
	setDefaultHeader(reqHeader)
	reqHeader["Content-Length"] = #reqBody
	local HTTPRequest = require 'http/request'
	local req = HTTPRequest:new()
	local code,resBody,resHeaders = req:simple(
		'POST',
		conf.redmine.scheme,
		conf.redmine.host,
		conf.redmine.port,
		conf.uris.login,
		reqHeader,
		reqBody
	)
	local cookie = resHeaders["set-cookie"]:match("[^;]+")
	return resBody,cookie,code
end

function parseNumber(entry)
	local title = entry:match("<title>(.-)</title>")
	local number = title:match("%#(%d+)")
	return number
end

function parseStatus(entry)
	local title = entry:match("<title>(.-)</title>")
	local status = title:match("#%d+%s+%((.-)%)")
	return status
end

function getTicketList(reqHeader,limit,offset)
	setDefaultHeader(reqHeader)
	local HTTPRequest = require 'http/request'
	local req = HTTPRequest:new()
	local limit = limit or 100
	local offset = offset or 0
	local resultTable = {}
	for currentOffset = offset, limit, 100 do
		local requestUri = string.format(
			'%s&limit=%d&offset=%d',
			conf.uris.exportjson,
			100,
			currentOffset
		)
		local code,resBody,resHeaders = req:simple(
			'GET',
			conf.redmine.scheme,
			string.format(
				"%s:%s@%s",
				conf.redmine.username,
				conf.redmine.password,
				conf.redmine.host
			),
			conf.redmine.port,
			requestUri,
			reqHeader
		)
		if code ~= 200 then throw("redmine API returns nothing " .. code .. resBody) end
		local parsedTable = JSON.decode(resBody)
		if resultTable.issues  then
			for key, issue in pairs(parsedTable.issues) do
				table.insert(resultTable.issues, issue)
			end
		else
			resultTable = parsedTable
		end
	end
	return resultTable
end

function getUsernameById(userId)
	if type(userId) ~= 'number' then return "" end
	if userId < 1 then return "" end

	local reqHeader = setDefaultHeader()
	local HTTPRequest = require 'http/request'
	local req = HTTPRequest:new()
	local resultTable = {}
	local code,resBody,resHeaders = req:simple(
		'GET',
		conf.redmine.scheme,
		string.format(
			"%s:%s@%s",
			conf.redmine.username,
			conf.redmine.password,
			conf.redmine.host
		),
		conf.redmine.port,
		string.format(
			"%s%d.json",
			conf.redmine.uris.userjson,
			userId
		),
		reqHeader
	)
	if code ~= 200 then throw(code) end
	local parsed = JSON.decode(resBody)
	if not parsed.user.firstname then throw("unknwon error") end
	return parsed.user.firstname .. " " .. parsed.user.lastname
end

function parseTickets(tickets)
	-- 番号,PJ,済,障害の概要,ガチャ,ランク,責任者
	local rows = {}
	for i,issue in ipairs(tickets.issues) do	
		local row = {
			PJ			= { column = 'PJ', value = ''},
			isFinished	= { column = '済', value = false },
			subject     = { column = '障害の概要', value = '' },
			description	= { column = '障害の詳細', value = '' },
			isGacha		= { column = 'ガチャ', value = false },
			rank		= { column = 'ランク', value = 0 },
			accountable	= { column = '責任者', value = '', id = 0 },
		}
		row.id = issue.id
		-- Project Name		
		if issue.project then row.PJ.value = issue.project.name end
		-- Done
		if issue.status and issue.status.id == conf.redmine.finishedid then row.isFinished.value = true end
		-- Subject
		row.subject.value = issue.subject
		-- Description
		row.description.value = issue.description
		-- Is Gacha
		if issue.category and issue.category.id == conf.redmine.gachaid then
			row.isGacha.value = true
		end
		-- Rank
		if issue.custom_fields then
			for i,customField in ipairs(issue.custom_fields) do

				--rank--
				if customField.id == conf.redmine.rankid then
					row.rank.value = customField.value
				end

				--accountable--
				if customField.id == conf.redmine.accountableid then
					row.accountable.id = customField.value
					row.accountable.value = getUsernameById(row.accountable.id)
				end

			end
		end
		table.insert(rows, row)
	end
	return rows
end

function login()
	local token,cookie = getToken()
	local session,cookie,code = getSession(token,{ Cookie = cookie })
	if code == 302 then
		return cookie
	end
end

function parseDescription(description)
	local result = {}

	description = description:gsub('%s', '')
	for i,name in ipairs(columnNames) do
		if description then
			if columnNames[i+1] then
				local matched = description:match(name .. '(.+)' .. columnNames[i+1])
				if matched then
					result[i] = matched
				else
					result[i] = ""
				end
			else
				local matched = description:match(name .. '(.+)$')
				if matched then
					result[i] = matched
				else
					result[i] = ""
				end
			end
		else
			result[i] = ""
		end
	end

--[[
	for i,name in ipairs(columnNames) do
		if description then
			local matched = description:match(name .. '%s*([^$]+)\r*\n')
			if matched then
				result[i] = matched
			else
				result[i] = ""
			end
		else
			result[i] = ""
		end
	end
]]--
	return result
end

function parsed2csv(parsed)
	local fbody = "番号,PJ,障害の概要,ガチャ,ランク,責任者,"
	fbody = fbody .. table.concat(columnNames, ",") .. "\n"
	for id,struct in pairs(parsed) do
		local descriptions = parseDescription(struct.description.value)
		local isGacha = ""
		if struct.isGacha.value == true then isGacha = "ガチャ" end
		fbody = fbody .. string.format(
			'"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s' .. "\n",
			struct.id, -- 番号
			struct.PJ.value, -- PJ
			struct.subject.value, -- 障害の概要
			isGacha, -- ガチャ
			struct.rank.value, -- ランク
			struct.accountable.value, -- 責任者
			descriptions[1],
			descriptions[2],
			descriptions[3],
			descriptions[4],
			descriptions[5],
			descriptions[6],
			descriptions[7],
			descriptions[8],
			descriptions[9],
			descriptions[10]
		)
	end
	Util.saveFile(conf.output.filepath,fbody)
end

function throw(code,str)
	if type(code) ~= 'number' then
		str = code
		code = 500
	end

	local traceback = debug.traceback()
	print(traceback)

	if str then
		print('Exception: ' .. str)
	else
		print('Exception: unknown error')
	end
	os.exit(1)
end

function main()
	--local cookie = login()
	local tickets = getTicketList({}, conf.download.limit, 0)
	local parsed = parseTickets(tickets)
	parsed2csv(parsed)
	--print(Util.dumper(parsed))
end

main()

