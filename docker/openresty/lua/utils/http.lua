local cjson = require("cjson")
local requests = require("resty.http")
local fluentd = require("rp.utils.fluentd")

cjson.decode_array_with_array_mt(true)

local _M = {}

function _M.get(server, args)
    fluentd.info("http", {message="http query", server=server.host, port=server.port ,args=args})
    local res, data, err, err2
    local con = requests.new()
    con:set_timeout(server.timeout * 1000)
    con:connect(server.host, server.port)
    res, err = con:request(args)
    if not err then
        data, err2 = res:read_body()
        if not err2 then
            con:set_keepalive()
            if res.headers["Content-Type"] == "application/json" then
                data = cjson.decode(data)
            end
            if res.status == 200 then
                return data, res.headers, nil
            else
                return nil, {}, ""
            end
        end
    end
    con:close()
    return nil, {}, err or err2
end

function _M.post(server, args, data)
    local headers = args:get('headers', {})
    headers['Content-Type'] = 'application/json'
    args['headers'] = headers
    args['body'] = cjson.encode(data)
    args['method'] = 'POST'
    return _M.get(server, args)
end

return _M