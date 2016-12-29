local utils = require "utils"

local ttl = 60;

-- Setup Redis connections
local red = redis:new()
local redcoin = redis:new()

red:set_timeout(1000) -- 1 second

local ok, err = red:connect("127.0.0.1", 6379)
if not ok then
	ngx.log(ngx.ERR, "failed to connect to redis: ", err)
	return ngx.exit(500)
end
red:select(0) -- Database 0 for new requests

local ok, err = redcoin:connect("127.0.0.1", 6379)
if not ok then
	ngx.log(ngx.ERR, "failed to connect to redis: ", err)
	return ngx.exit(500)
end
redcoin:select(1) -- Database 1 for bitcoin addresses
-- Redis End

-- Get data from request
local uri = ngx.var.uri
ngx.req.read_body()
local data = ngx.req.get_body_data()

value=cjson.decode(data)
if not value then
	ngx.log(ngx.ERR, "Failed to decode json")
	return ngx.exit(400)
end

-- Extract Hashes from Request and generate key_ID
local hashes={}
if not value.hashes then
	ngx.log(ngx.ERR, "Missing key Hashes in data")
	return ngx.exit(400)
end
for k,v in pairs(value.hashes) do
	table.insert(hashes, v)
end

local key = utils.hashes_to_id(hashes)

-- Insert new Key into REDIS if does not exist or refresh

local exist,err = red:exists(key)
if exist==1 then
	
	-- Refresh existing key
	local ok,err = red:expire(key,ttl)
	if not ok then
		ngx.log(ngx.ERR, "failed to set expire into redis for key: ",key," with error: ", err)
		return ngx.exit(500)
	end

else

	-- Pull a bitcoin address and build document
	local address,err = redcoin:lpop("coin0")
	if not address then
		ngx.log(ngx.ERR, "Failed to get a bitcoin address from redis")
		return ngx.exit(500)
	end

	local new_document = {}
	new_document["address"]=address
	new_document["hashes"]=hashes

	local ok,err = red:set(key,cjson.encode(new_document))
	if not ok then
		ngx.log(ngx.ERR, "failed to put data into redis for key: ",key," with error: ", err)
		return ngx.exit(500)
	end
	
	local ok,err = red:expire(key,ttl)
	if not ok then
		ngx.log(ngx.ERR, "failed to set expire into redis for key: ",key," with error: ", err)
		return ngx.exit(500)
	end
	
end


-- Return ID and 200

ngx.status = ngx.HTTP_OK  
ngx.header.content_type = "application/json; charset=utf-8"  
ngx.say(cjson.encode({ status = true , id = key }))  
return ngx.exit(ngx.HTTP_OK)  
