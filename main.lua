#! /usr/bin/env lua
package.path =	'./libs/?.lua;' .. package.path

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

function setDefaultHeader(conf,reqHeader)
	reqHeader = reqHeader or {}
	reqHeader["Content-Type"] = reqHeader["Content-Type"] or "application/x-www-form-urlencoded"
	reqHeader["Host"] = conf.redmine.host .. ":" .. conf.redmine.port
	reqHeader["Origin"] = conf.redmine.scheme .. '://' .. conf.redmine.host .. ":" .. conf.redmine.port
	reqHeader["Accept-Language"] = "ja-jp"
	reqHeader["Accept"] = "text/html,*/*;q=0.8"
	return reqHeader
end

function getToken(conf)
	local HTTPRequest = require 'http/request'
	local req = HTTPRequest:new()
	local code,resBody,resHeaders = req:simple(
		conf.scheme,
		'GET',
		conf.redmine.host,
		conf.redmine.port,
		conf.uris.login
	)
	local reqHeader = setDefaultHeader(conf)
	-- local token = resBody:match('<meta name="csrf-token" content="([^"]+)')
	local token = resBody:match('<meta name="csrf%-token" content="([^"]+)"')
	local cookie = resHeaders["set-cookie"]:match("[^;]+")
	return token,cookie,code
end

function getSession(conf,token,reqHeader)
	local reqBody = string.format(
		"username=%s&password=%s&authenticity_token=%s",
		uriEscape(conf.redmine.username),
		uriEscape(conf.redmine.password),
		uriEscape(token)
	)
	setDefaultHeader(conf,reqHeader)
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

function login(conf)
	local token,cookie = getToken(conf)
	local session,cookie,code = getSession(conf,token,{ Cookie = cookie })
	if code == 302 then
		return cookie
	end
end

function throw(code,str)
	if type(code) ~= 'number' then
		str = code
		code = 500
	end
	print('Exception: ' .. str)
	exit(1)
end

function main()
	local Config = require 'aimi/config'
	local conf = Config:new():load('etc/config.ini')
	local cookie = login(conf)

	print(cookie)
end

main()

