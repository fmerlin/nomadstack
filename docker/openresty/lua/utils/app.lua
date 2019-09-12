local cmessagepack = require("MessagePack")
local riak = require("rp.utils.riak")
local oauth = require("rp.utils.oauth")
local fluentd = require("rp.utils.fluentd")
local nomad = require("rp.utils.nomad")
local balancer = require("ngx.balancer")
local cjson = require("cjson")

local _M = {}

function _M.uuid()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

function _M.load_session()
    fluentd.debug('app', 'loading session')
    ngx.ctx.args = ngx.req.get_uri_args()
    ngx.var.x_request_id = _M.uuid()
    local session = ngx.var.cookie_x_session
    if session ~= nil then
        ngx.ctx.session = session
        local data = ngx.shared.rp_cache:get('sessions/' .. session)
        if data then
            ngx.ctx.user = cmessagepack.unpack(data)
            return
        end
    end

    oauth.extract_bearer()
    if #ngx.ctx.user > 0 then
        riak.load_user_info()
        _M.save_session()
    end
end

function _M.save_session()
    fluentd.debug('app', 'save_session')
    if ngx.ctx.session == nil then
        ngx.ctx.session = _M.uuid()
    end
    local t = ngx.ctx.user.exp - ngx.now()
    _M.add_cookie("x_session", session, t)
    ngx.shared.rp_cache:put('sessions/' .. ngx.ctx.session, cmessagepack.pack(ngx.ctx.user), t)
end

function _M.should_auth()
    fluentd.debug('app', 'should_auth')
    local s = ngx.var.service
    local u = ngx.var.uri:sub(s:len() + 2)
    local restrictions = ngx.shared.rp_cache:get('restrictions/' .. s)
    if restrictions then
        restrictions = cmessagepack.unpack(restrictions)
        for k, v in pairs(restrictions) do
            if u:sub(1, k:len()) == k then
                if ngx.ctx.user.group == nil then
                    return true
                elseif _M.does_not_equal(ngx.ctx.user.group, v) then
                    ngx.exit(ngx.HTTP_UNAUTHORIZED)
                end
            end
        end
    end
    return false
end

function _M.load_settings()
    fluentd.debug('app', 'load_settings')
    local key = ngx.header['X-API-KEY']
    if key then
        ngx.ctx.api_key = key
        local settings = ngx.shared.rp_cache:get('apikeys/' .. key)
        if settings == nil then
            settings = riak.load_key()
            ngx.shared.rp_cache:put('apikeys/' .. key, cmessagepack.pack(settings))
        else
            settings = cmessagepack.unpack(settings)
        end
        if _M.check(settings.input or {}) then
            ngx.ctx.settings = settings.output
        else
            fluentd.error("riak", { message = "api key not valid", err = err, key = key })
            ngx.exit(ngx.HTTP_UNAUTHORIZED)
        end
    else
        ngx.ctx.api_key = ngx.var.remote_addr .. '-' .. ngx.var.service
        local rules = ngx.shared.rp_cache:get('rules/' .. ngx.var.service)
        if rules then
            rules = cmessagepack.unpack(rules)
            for i, rule in ipairs(rules) do
                if _M.check(rule.input or {}) then
                    ngx.ctx.settings = rule.output
                    return
                end
            end
            ngx.exit(ngx.HTTP_UNAUTHORIZED)
        end
    end
end

function _M.does_not_equal(a, b)
    if a and b then
        if type(a) == table then
            for i, v in ipairs(a) do
                if _M.does_not_equal(v, b) then
                    return true
                end
            end
            return false
        end
        if type(b) == table then
            for i, v in ipairs(b) do
                if _M.does_not_equal(a, v) then
                    return true
                end
            end
            return false
        end
        return a ~= b
    end
    return false
end

function _M.check(map)
    for k2, v2 in pairs(map) do
        if _M.does_not_equal(ngx.ctx.user[k2], v2) then
            return false
        end
    end
    return true
end

function _M.set_upstream()
    fluentd.debug('app', 'set_upstream')
    local versions = ngx.shared.rp_cache:get('versions/' .. ngx.var.service)
    if versions then
        versions = cmessagepack.unpack(versions)
        ngx.ctx.version = versions[ngx.ctx.settings.version or '']
    else
        fluentd.error('balancer', { message = "no upstream found" })
        return ngx.exit(ngx.HTTP_BAD_GATEWAY)
    end
end

function _M.throttle()
    fluentd.debug('app', 'throttle')
    local settings = ngx.ctx.settings or {}
    local l = ngx.shared.rp_cache:get('throttle/' .. ngx.ctx.api_key)
    if l then
        l = cmessagepack.unpack(l)
    else
        l = {}
    end

    local n = ngx.now()
    local d = (settings.max_time or 1) * (settings.max_req or 100) / (settings.max_par or 10)
    local mx = n - d

    while #l > 0 and l[1] < mx do
        table.remove(l, 1)
    end

    if #l > (settings.max_req or 100) then
        ngx.exit(ngx.HTTP_TOO_MANY_REQUESTS)
    end

    table.insert(l, n)
    ngx.shared.rp_cache:set('throttle/' .. ngx.ctx.api_key, cmessagepack.pack(l), d)

    local t = l[#l] + math.floor((#l - 1)  / (settings.max_par or 10)) * (settings.max_time or 1) - n
    if t > 0 then
        ngx.ctx.throttling = t
        ngx.sleep(t)
    else
        ngx.ctx.throttling = 0
    end
end

function _M.balance(is_sticky)
    fluentd.debug('app', 'balance')
    local service = ngx.var.service
    local up = is_sticky and ngx.var.cookie_x_upstream
    local mn = 1000000
    local host
    local hosts
    local type = ngx.shared.rp_cache:get('type/' .. service)
    local try = 0

    while host == nil do
        if try > 0 then
            if try > 10 or type ~= 'uwsgi' then
                fluentd.error('balance', { message = "no upstream found" })
                return ngx.exit(ngx.HTTP_BAD_GATEWAY)
            end
            if try == 1 then
                nomad.add_job(service, ngx.ctx.version)
            end
            ngx.sleep(1)
        end
        hosts = ngx.shared.rp_cache:get('upstreams/' .. service)
        hosts = hosts and cmessagepack.unpack(hosts) or {}
        for i, h in ipairs(hosts) do
            if h.version == ngx.ctx.version then
                if is_sticky and h.id == up then
                    host = h
                    break
                end
                local n = ngx.shared.rp_cache:get('connections/' .. h.address) or 0
                if n < mn then
                    host = h
                    mn = n
                end
            end
        end
        try = try + 1
    end

    if is_sticky then
        _M.add_cookie("x_upstream", host.id, 3600)
    end

    ngx.ctx.host = host
    ngx.ctx.nb_hosts = #hosts
    ngx.shared.rp_cache:incr('connections/' .. host.address, 1, 0)
    ngx.var.proxy_to = host.address .. ':' .. host.port
end

function _M.set_peer()
    local host = ngx.ctx.host
    local ok, err = balancer.set_current_peer(host.address, host.port)
    if err then
        fluentd.error('set_peer', { message = "failed to set the current peer", err = err })
        return ngx.exit(ngx.ERROR)
    end
end

function _M.write_cookies()
    if ngx.ctx.cookies and #ngx.ctx.cookies > 0 then
        fluentd.debug('app', 'write_cookies')
        ngx.header["Set-Cookie"] = ngx.ctx.cookies
    end
end

function _M.add_cookie(name, value, expires)
    fluentd.debug('app', 'add_cookie')
    if ngx.ctx.cookies == nil then
        ngx.ctx.cookies = {}
    end
    local cookie = name .. "=" .. value .. "; Expires=" .. ngx.cookie_time(ngx.time() + expires)
    table.insert(ngx.ctx.cookies, cookie)
end

function _M.cors()
    if ngx.var.service ~= '' then
        fluentd.debug('app', 'cors')
        local origin = ngx.req.get_headers()["Origin"]
        if origin then
            ngx.header["Access-Control-Expose-Headers"] = ""
            ngx.header["Access-Control-Allow-Headers"] = ""
            ngx.header["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE"
            ngx.header["Access-Control-Allow-Credentials"] = "false"
            ngx.header["Access-Control-Max-Age"] = 7200
            ngx.header["Access-Control-Allow-Origin"] = origin
        end
    end
end

function _M.end_request()
    if ngx.var.service ~= '' then
        fluentd.debug('app', 'end_request')
        local body = ngx.ctx.resp_body
        if ngx.ctx.host then
            ngx.shared.rp_cache:incr('connections/' .. ngx.ctx.host.address, -1)
        end
        if body and ngx.header['Content-Type'] == 'application/json' then
            body = cjson.decode(body)
        end
        fluentd.info('request', { duration = ngx.now() - ngx.req.start_time(),
                                  throttle = ngx.ctx.throttling or 0,
                                  args = ngx.ctx.args or {},
                                  uri = ngx.var.uri,
                                  body = body or '',
                                  node = ngx.ctx.host and ngx.ctx.host.id or '',
                                  nb_hosts = ngx.var.nb_hosts or 0,
                                  upstream = ngx.var.proxy_to or '',
                                  server = ngx.ctx.host and ngx.ctx.host.id or '',
                                  status = ngx.var.status or 0})
    end
end

function _M.collect_metrics()
    local add_line
    fluentd.debug('app', 'collect_metrics')
    function add_line(res, name, args, value)
        local atts = {}
        for k, v in pairs(args) do
            table.insert(atts, k .. '="' .. v .. '"')
        end
        table.insert(res, name .. '{' .. table.concat(atts, ',') .. '} ' .. value .. '\n')
    end
    local sum = {}
    local count = {}
    local keys = ngx.shared.rp_cache:get_keys()
    for i, key in ipairs(keys) do
        local cat = key:match("([^/]*)")
        local v = ngx.shared.rp_cache:get(key)
        local size = (sum[cat] or 0) + key:len() + 40
        count[cat] = (count[cat] or 0) + 1
        if v then
            if type(v) == 'string' then
                sum[cat] = size + v:len()
            elseif type(v) == 'number' then
                sum[cat] = size + 8
            elseif type(v) == 'boolean' then
                sum[cat] = size + 1
            end
        end
    end

    local res = {}
    for k, v in pairs(sum) do
        add_line(res, "openresty_cache_size", { category = k }, v)
    end
    for k, v in pairs(count) do
        add_line(res, "openresty_cache_count", { category = k }, v)
    end
    add_line(res, "openresty_connections", { category = 'reading' }, ngx.var.connections_reading)
    add_line(res, "openresty_connections", { category = 'writing' }, ngx.var.connections_writing)
    add_line(res, "openresty_connections", { category = 'waiting' }, ngx.var.connections_waiting)

    ngx.header['Content-Type'] = 'text/plain'
    ngx.print(res)
end

function _M.get_open_api()
    fluentd.debug('app', 'get_open_api')
    local tags = {}
    local paths = {}
    local securityDefinitions = {}
    local externalDocs = {}
    local definitions = {}
    local defs = ngx.shared.rp_cache:get('swagger/definitions')
    if defs then
        local res = ngx.location.capture_multi(cmessagepack.unpack(defs))
        for srv in res do
            if srv.status == ngx.HTTP_OK then
                local data = cjson.decode(res.body)
                for k, v in pairs(data['paths']) do
                    paths[data['basePath'] .. k] = v
                end
                for k, v in pairs(data['definitions']) do
                    definitions[k] = v
                end
                for k, v in pairs(data['securityDefinitions']) do
                    securityDefinitions[k] = v
                end
                for i, v in ipairs(data['tags']) do
                    table.insert(tags, v)
                end
            end
        end
    end

    ngx.header['Content-Type'] = 'application/json'
    ngx.print(cjson.encode({
        swagger='2.0',
        info={
            description='',
            version='',
            title='',
            license={
                name='Apache 2.0',
                url='http://www.apache.org/licenses/LICENSE-2.0.html'
            }
        },
        host='',
        basePath='/',
        tags=tags,
        schemes={'http'},
        paths=paths,
        securityDefinitions=securityDefinitions,
        definitions=definitions,
        externalDocs=externalDocs
    }))
end

return _M
