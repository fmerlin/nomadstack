local cmessagepack = require("MessagePack")
local cjson = require("cjson")

local _M = cjson.decode(os.getenv("FLUENTD") or "{}")
local var_phases = {
    set=true,
    rewrite=true,
    access=true,
    balancer=true,
    content=true,
    header_filter=true,
    body_filter=true,
    log=true
}

function _M.remote_log(tag, data)
    local r = { user = ngx.var.remote_user,
                host = ngx.var.remote_addr,
                key = ngx.ctx.api_key,
                log = 'info',
                session = ngx.ctx.session }
    for k, v in pairs(data) do
        r[k] = v
    end
    ngx.timer.at(0, _M.send, cmessagepack.pack({ 'app.' .. tag, ngx.time(), r }))
end

function _M.debug(tag, data)
    _M.log(tag, 'debug', {message = data})
end

function _M.info(tag, data)
    _M.log(tag, 'info', data)
end

function _M.error(tag, data)
    _M.log(tag, 'error', data)
end

function _M.log(tag, level, data)
    local r
    local phase = ngx.get_phase()
    if var_phases[phase] == true then
        r = { service =  ngx.var.service,
              user = ngx.var.remote_user,
              host = ngx.var.remote_addr,
              key = ngx.ctx.api_key,
              log_level = level,
              request = ngx.var.x_request_id,
              phase = phase,
              session = ngx.ctx.session }
        for k, v in pairs(data) do
            r[k] = v
        end
    else
        r = data or {}
        r['log_level'] = level
        r['phase'] = phase
    end
    ngx.timer.at(0, _M.send, cmessagepack.pack({ 'openresty.' .. tag, ngx.time(), r }))
end

function _M.send(premature, e)
    local ok, bytes
    local sock, err = ngx.socket.tcp()
    if not err then
        sock:settimeout(_M.timeout * 1000)
        ok, err = sock:connect(_M.host, _M.port)
        if not err then
            bytes, err = sock:send(e)
            if not err then
                sock:setkeepalive(_M.timeout)
                return
            end
            sock:close()
        end
    end
    ngx.log(ngx.ERR, cjson.encode(cmessagepack.unpack(e)))
end

return _M
