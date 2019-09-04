local cjson = require("cjson")
local http = require("rp.utils.http")
local fluentd = require("rp.utils.fluentd")

local _M = cjson.decode(os.getenv("RIAK") or "{}")

function _M.load_user_info()
    local res, headers, err = http.get(_M, {path='/types/user/buckets/openresty/key/' .. ngx.ctx.user[_M.key]})
    if err then
        fluentd.error("riak", {message="user not found", err=err, user=ngx.ctx.user[_M.key]})
    else
        for k,v in pairs(res) do
            ngx.ctx.user[k] = v
        end
    end
end

function _M.load_key_info()
    local res, headers, err = http.get(_M, {path='/types/apikey/buckets/openresty/key/' .. ngx.ctx.api_key})
    if err then
        fluentd.error("riak", {message="api key not found", err=err, key=ngx.ctx.api_key})
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end
    return res
end

return _M
