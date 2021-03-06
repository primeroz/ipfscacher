worker_processes  2;
#error_log logs/error.log debug;
error_log logs/error.log info;
daemon off;

events {
	worker_connections 1024;
}

http {
	access_log logs/access.log;

	init_by_lua_file "/home/prz/resty/ipfscache/init.lua";

 	server {
		listen 8080;
		resolver 8.8.4.4;  # use Google's open DNS server

		location /v0/new {


					if ($request_method ~ ^(PUT|POST)$ ) {

					content_by_lua '
						-- local cjson = require "cjson"
						local redis = require "resty.redis"
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

            -- ngx.log(ngx.ERR, "URI to: ", uri)
            -- ngx.log(ngx.ERR, "data : ", data)

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
	
						local resty_sha256 = require "resty.sha256"
						local str = require "resty.string"
						local sha256 = resty_sha256:new()
						for k,v in pairs(hashes) do
							sha256:update(v)
						end
						local digest = sha256:final()
						local key = tostring(str.to_hex(digest))
						-- ngx.say("sha256: ", tostring(str.to_hex(digest)))
						-- ngx.log("sha256: ", tostring(digest))


						local ok,err = red:set(key,cjson.encode(hashes))
						if not ok then
							ngx.log(ngx.ERR, "failed to put data into redis: ", err)
							return ngx.exit(500)
						end

						local ok,err = red:expire(key,60)
						if not ok then
							ngx.log(ngx.ERR, "failed to set expire into redis: ", err)
							return ngx.exit(500)
						end

						return ngx.exit(200)
					';
					}
			
					if ($request_method ~ ^(GET|HEAD)$ ) {
					content_by_lua '
						ngx.log(ngx.ERR, "GET")
					';
					}
        }
    }
}
