local fluentd = require("rp.utils.fluentd")
local cmessagepack = require("MessagePack")
local cjson = require("cjson.safe")
local http = require("rp.utils.http")

cjson.decode_array_with_array_mt(true)

local _M = cjson.decode(os.getenv("CONSUL") or "{}")

function _M.get_version(items)
    for i, item in ipairs(items) do
        if item:sub(1,1) == 'v'then
            return item
        end
        return nil
    end
end

function _M.service_update(premature, service, myindex)
    local delay = 0
    local data, headers, err = http.get(_M, {
        path = '/v1/health/service/' .. service,
        query = { index = myindex }
    })
    if err == 'timeout' then
        delay = 0
    elseif err then
        fluentd.error("consul", {message="failed to query the service", err=err})
        delay = 10
    else
        myindex = headers['X-Consul-Index']
        local res = {}
        for i,e in ipairs(data) do
            for j,c in ipairs(e.Checks) do
                if c.ServiceName == service and (c.Status == 'passing' or c.Status == 'warning') then
                    table.insert(res,{ id = e.Service.ID,
                        port = e.Service.Port,
                        version = e.Service.Meta.version or _M.get_version(e.Service.Tags),
                        address = e.Node.Address or 'localhost'
                    })
                    break
                end
            end
        end
        ngx.shared.rp_cache:set('upstreams/' .. service, cmessagepack.pack(res))
        fluentd.info("consul", {message="update service", service=service, upstreams=res})
    end
    ngx.timer.at(delay, _M.service_update, service, myindex)
end

function _M.split(s, p)
    local res = {}
    for e in s:gmatch("([^" .. p .. "]+)") do
        table.insert(res, e)
    end
    return res
end

function _M.kv_update(premature, myindex)
    local delay = 0
    local path = '/v1/kv/' .. (os.getenv('NGINX') or 'openresty') .. '/endpoints'
    local data, headers, err = http.get(_M, {
        path=path,
        query={index = myindex, recurse = 'true'}
    })
    if err == 'timeout' then
        delay = 0
    elseif err then
        fluentd.error("consul", {message="failed to query the kv", err=err, url='http://' .. _M.host .. ':' .. _M.port .. '/' .. path})
        delay = 10
    else
        myindex = headers['X-Consul-Index']
        local swaggers = {}
        for i,e in ipairs(data) do
            local svcs = _M.split(e.Key,"/")
            local svc = svcs[#svcs - 1]
            local v = ngx.decode_base64(e.Value)
            for j, kind in ipairs({'rules', 'restrictions', 'job', 'redis', 'versions'}) do
                if svcs[#svcs] == kind then
                    local c, err = cjson.decode(v)
                    if c then
                        ngx.shared.rp_cache:set(kind .. '/' .. svc, cmessagepack.pack(c))
                    else
                        fluentd.error("consul", {message="cannot decode json", err=err})
                    end
                end
            end
            if svcs[#svcs] == 'type' then
                fluentd.info("consul", {message="new endpoint", service=svc})
                ngx.shared.rp_cache:set('type/' .. svc, v)
                if v == 'uwsgi' or v == 'proxy' then
                    table.insert(swaggers, '/' .. svc .. '/swagger.json')
                end
            end
            if svcs[#svcs] == 'service' then
                ngx.shared.rp_cache:set('service/' .. svc, v)
                if ngx.shared.rp_cache:get('upstreams/' .. v) == nil then
                    ngx.shared.rp_cache:set('upstreams/' .. v, cmessagepack.pack({}))
                    ngx.timer.at(0, _M.service_update, v, '0')
                end
            end
        end
        ngx.shared.rp_cache:set('swagger/definitions', cmessagepack.pack(swaggers))
    end
    ngx.timer.at(delay, _M.kv_update, myindex)
end

function _M.connect()
    local ok, err = ngx.shared.rp_cache:add('locks/consul', true)
    if ok then
        fluentd.info("consul", {message="starting consul monitoring"})
        ngx.timer.at(0, _M.kv_update, '0')
    end
end

return _M
