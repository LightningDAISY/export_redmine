local O = {}

function O.new(o)
	o = o or {}
	o.errorMessages = {}
	local base  = require 'aimi.base'
	local parent = base:new()
	setmetatable(
		o,
		{
			__index = parent
		}
	)
	return o
end

function O:simple(method, scheme, host, port, path, reqHeaders, reqBody)
	local http  = require 'socket.http'
	scheme = scheme or 'http'
	http.TIMEOUT = 3
	http.PORT = port or 80

	reqHeaders = reqHeaders or { Host = host }
	reqBody = reqBody or ''

	local url = scheme .. '://' .. host .. ':' .. port .. path
	local resBody = {}

	local body, code, resHeaders, status = http.request({
		method  = method,
		url     = url,
		source  = ltn12.source.string(reqBody),
		headers = reqHeaders,
		sink    = ltn12.sink.table(resBody)
	})
	local body = table.concat(resBody, '')
	return code, body, resHeaders
end

function O:getAuthInfo(method, host, path, reqHeaders, reqbody, port, scheme)
	local io    = require "io"
	local http  = require 'socket.http'
	local ltn12 = require "ltn12"
	http.TIMEOUT = 3

	scheme = scheme or 'http'
	http.PORT = port or 80

	reqHeaders.Host = host
	reqHeaders.connection = 'close'
	local url = scheme .. '://' .. host .. ':' .. port .. path
	local resbody = {}
	local body, code, resHeaders, status = http.request({
		method  = method,
		url     = url,
		source  = ltn12.source.string(reqbody),
		headers = reqHeaders,
		sink    = ltn12.sink.table(resbody)
	})
	if code == 401 then
		local chr,idx,realm  = resHeaders['www-authenticate']:find('realm%s*=%s*"?([%w%s]+)"?')
		local chr,idx,qop    = resHeaders['www-authenticate']:find('qop%s*=%s*"?(%w+)"?')
		local chr,idx,nonce  = resHeaders['www-authenticate']:find('nonce%s*=%s*"?(%w+)"?')
		local chr,idx,opaque = resHeaders['www-authenticate']:find('opaque%s*=%s*"?(%w+)"?')
		local chr,idx,cnonce = resHeaders['www-authenticate']:find('cnonce%s*=%s*"?(%w+)"?')
		local chr,idx,nc     = resHeaders['www-authenticate']:find('nc%s*=%s*"?(%w+)"?')
		if not qop    then qop    = 1 end
		if not nonce  then nonce  = 1 end
		if not opaque then opaque = 1 end
		if not cnonce then cnonce = 1 end
		if not nc     then nc     = 1 end
		return realm,qop,nonce,opaque,cnonce,nc
	else
		return false
	end
end

function O:createAuthorization(realm,qop,nonce,opaque,cnonce,nc,method,path,username,password)
	local arr = {
		ngx.md5(username .. ':' .. realm .. ':' .. password),
		nonce,
		nc,
		cnonce,
		qop,
		ngx.md5(method .. ':' .. path)
	}
	local response = ngx.md5(table.concat(arr, ':'))

	arr = {
		'username="' .. username .. '"',
		'realm="' .. realm .. '"',
		'password="' .. password .. '"',
		'nonce="' .. nonce .. '"',
		'nc="' .. nc .. '"',
		'cnonce="' .. cnonce .. '"',
		'qop="' .. qop .. '"',
		'uri="' .. path .. '"',
		'response="' .. response .. '"',
	}
	local str = 'Digest ' .. table.concat(arr, ',')
	return str
end

function O:apiAccess(method, host, path, reqHeaders, reqBody, port, scheme)
	local http  = require 'socket.http'
	method = method or 'GET'
 	port = port or 80
	reqHeaders = reqHeaders or {}
	http.TIMEOUT = 3
	http.PORT = port

	scheme = scheme or 'http'
	local url = scheme .. '://' .. host .. ':' .. port .. path

	reqHeaders.Host = host
	reqHeaders.connection = 'close'
	reqBody = reqBody or ''
	local resBody = {}

	local body, code, resHeaders, status = http.request({
		method  = method,
		url     = url,
		source  = ltn12.source.string(reqBody),
		headers = reqHeaders,
		sink    = ltn12.sink.table(resBody)
	})
	self.code = code
	if code == 200 then return resBody end

	if code == 500 then
		self.message = 'api internal server error'
	else
		self.message = 'auth error'
	end
	return nil
end

return O

