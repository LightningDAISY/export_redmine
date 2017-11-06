local AimiConfig = {}

function AimiConfig.new(o)
	o = o or {}
	return o
end

function AimiConfig:load(filename)
	local util = require('aimi.util')
	local config = util.loadIni(filename)
	return config
end

return AimiConfig
