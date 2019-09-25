local cjson = require("cjson")
local websocket = require("resty.websocket.server")
local fluentd = require("rp.utils.fluentd")
local redis = require("rp.utils.redis")
local celery = require("rp.utils.celery")
local misc = require("rp.utils.misc")
local cmessagepack = require("MessagePack")

local _M = cjson.decode(os.getenv("REDIS") or "{}")

function _M.connect()
    local service = ngx.var.service
    local version = ngx.ctx.version
    local ws_srv = websocket:new {
        timeout = 5000,
        max_payload_len = 65535
    }
    local config = ngx.shared.rp_cache:get('redis/' .. ngx.var.endpoint)
    if config then
        config = cmessagepack.unpack(config)
    else
        config = {}
    end

    local obj = {
        config = config,
        celery_queue = service .. '-' .. version,
        send = function(data)
            if data then
                if _M.encoding == 'json' then
                    ws_srv:send_text(cjson.encode(data))
                else
                    ws_srv:send_binary(cmessagepack.pack(data))
                end
            end
        end
    }
    celery.create(obj)
    redis.create(obj)

    local hosts = ngx.shared.rp_cache:get('upstreams/' .. service)
    local host
    if hosts then
        hosts = hosts and cmessagepack.unpack(hosts) or {}
        for i, h in ipairs(hosts) do
            if h.version == version and misc.is_in('celery', h.tags) then
                host = h
                break
            end
        end
        if host == nil then
            nomad.add_celery_job(service, version)
        end
    end

    local check = function(msg, res, err)
        if not res then
            fluentd.error('redis issue', { message = msg, err = err })
            obj.send({ action = 'error', message = msg, err = err })
        end
        return res
    end

    while true do
        local data, typ, err = ws_srv:recv_frame()
        if ws_srv.fatal then
            fluentd.error("redis", { message = "failed to receive frame", err = err })
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
            obj.execute(cjson.decode(data))
        elseif typ == "binary" then
            obj.execute(cmessagepack.unpack(data))
        end
    end
    ws_srv:send_close()
end


return _M
