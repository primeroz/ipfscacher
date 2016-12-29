local red = redis:new()

red:set_timeout(1000) -- 1 second

local ok, err = red:connect("127.0.0.1", 6379)

if not ok then
	ngx.log(ngx.ERR, "failed to connect to redis: ", err)
	return ngx.exit(500)
end

local uri = ngx.var.uri
ngx.req.read_body()
local data = ngx.req.get_body_data()

value=cjson.decode(data)
if not value then
	ngx.log(ngx.ERR, "Failed to decode json")
	return ngx.exit(400)
end

-- Extract Hashes from Request
local hashes={}
if not value.hashes then
	ngx.log(ngx.ERR, "Missing key Hashes in data")
	return ngx.exit(400)
end
for k,v in pairs(value.hashes) do
	table.insert(hashes, v)
end

-- calculate key id
local resty_sha256 = require "resty.sha256"
local str = require "resty.string"
local sha256 = resty_sha256:new()
for k,v in pairs(hashes) do
	sha256:update(v)
end
local digest = sha256:final()
local key = tostring(str.to_hex(digest))

-- Insert new Key into REDIS 
local ok,err = red:set(key,cjson.encode(hashes))
if not ok then
	ngx.log(ngx.ERR, "failed to put data into redis for key: ",key," with error: ", err)
	return ngx.exit(500)
end

local ok,err = red:expire(key,60)
if not ok then
	ngx.log(ngx.ERR, "failed to set expire into redis for key: ",key," with error: ", err)
	return ngx.exit(500)
end

-- Return ID and 200

ngx.status = ngx.HTTP_OK  
ngx.header.content_type = "application/json; charset=utf-8"  
ngx.say(cjson.encode({ status = true , id = key }))  
return ngx.exit(ngx.HTTP_OK)  
