-- calculate key id
local resty_sha256 = require "resty.sha256"
local str = require "resty.string"
local sha256 = resty_sha256:new()

local _M = {}

function _M.hashes_to_id(h)
	for k,v in pairs(h) do
		sha256:update(v)
	end
	local digest = sha256:final()
	local key = tostring(str.to_hex(digest))

	return key
end

return _M
