local cjson = require("cjson")
local redis = require("resty.redis")
local websocket = require("resty.websocket.server")
local fluentd = require("rp.utils.fluentd")

local _M = cjson.decode(os.getenv("REDIS") or "{}")

function _M.connect()
    local check, subscribe
    function check(msg, res, err)
        if not res then
            fluentd.error('', {message=msg, err=err})
            return ngx.exit(444)
        end
        return res
    end

    -- Redis
    function subscribe(redis_srv, ws_srv)
        while true do
            local res, err = redis_srv:read_reply()
            if res then
                local f = io.open(res[3], "rb")
                if f then
                    local data = f:read("*all")
                    ws_srv:send_binary(data)
                end
            end
        end
    end

    local redis_srv = redis:new()
    redis_srv:set_timeout(_M.timeout) -- 1 sec
    redis_srv:set_keepalive(_M.idle, _M.pool_size)
    check("failed to connect: ", redis_srv:connect(_M.host, _M.port))
    check("failed to subscribe: ", redis_srv:subscribe(ngx.var.service))

    -- WebSockets
    local ws_srv = check("failed to create a new websocket: ", websocket:new {
        timeout = 5000,
        max_payload_len = 65535
    })

    -- Loop
    ngx.thread.spawn(subscribe, redis_srv, ws_srv)


    while true do
        local data, typ, err = ws_srv:recv_frame()
        if ws_srv.fatal then
            fluentd.error("redis", {message="failed to receive frame", err=err})
            return ngx.exit(444)
        end
        if not data then
            check("failed to send ping: ", ws_srv:send_ping())
        elseif typ == "close" then
            break
        elseif typ == "ping" then
            check("failed to send pong: ", ws_srv:send_pong())
        elseif typ == "pong" then
            fluentd.debug("redis", "client ponged")
        elseif typ == "text" then
            check("failed to send text: ", redis_srv:publish(ngx.var.service, data))
        elseif typ == "binary" then
            check("failed to send data: ", redis_srv:publish(ngx.var.service, data))
        end

    end
    ws_srv:send_close()
end

return _M
