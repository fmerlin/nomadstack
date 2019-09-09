local fluentd = require("rp.utils.fluentd")
local cmessagepack = require("MessagePack")
local cjson = require("cjson.safe")
local http = require("rp.utils.http")

cjson.decode_array_with_array_mt(true)

local _M = cjson.decode(os.getenv("CONSUL") or "{}")

function service_update(premature, service, myindex)
    local delay = 0
    local data, headers, err = http.get(_M, {
        path = '/v1/health/service/' .. service,
        query = { index = myindex }
    })
    if err then
        fluentd.error("consul", {message="failed to query the service", err=err})
        ngx.shared.rp_cache:delete('upstreams/' .. service)
        delay = 10
    else
        myindex = headers['X-Consul-Index']
        local res = {}
        for i,e in ipairs(data) do
            for j,c in ipairs(e.Checks) do
                if c.ServiceName == service and (c.Status == 'passing' or c.Status == 'warning') then
                    table.insert(res,{ id = e.Service.ID,
                                       port = e.Service.Port,
                                       address = e.Node.Address or 'localhost'
                    })
                    break
                end
            end
        end
        if ngx.shared.rp_cache:get('upstreams/' .. service) == nil then
            fluentd.info("consul", {message="new service", service=service, upstreams=res})
        end
        ngx.shared.rp_cache:set('upstreams/' .. service, cmessagepack.pack(res))
    end
    ngx.timer.at(delay, service_update, service, myindex)
end

function split(s, p)
    local res = {}
    for e in s:gmatch("([^" .. p .. "]+)") do
        table.insert(res, e)
    end
    return res
end

function kv_update(premature, myindex)
    local delay = 0
    local path = '/v1/kv/' .. (os.getenv('NGINX') or 'openresty') .. '/endpoints'
    local data, headers, err = http.get(_M, {
        path=path,
        query={index = myindex, recurse = 'true'}
    })
    if err then
        fluentd.error("consul", {message="failed to query the kv", err=err, url='http://' .. _M.host .. ':' .. _M.port .. '/' .. path})
        delay = 10
    else
        myindex = headers['X-Consul-Index']
        local swaggers = {}
        for i,e in ipairs(data) do
            local svcs = split(e.Key,"/")
            local svc = svcs[#svcs - 1]
            local v = ngx.decode_base64(e.Value)
            if svcs[#svcs] == 'rules' then
                local c, err = cjson.decode(v)
                if c then
                    ngx.shared.rp_cache:set('rules/' .. svc, cmessagepack.pack(c))
                end
            end
            if svcs[#svcs] == 'versions' then
                if ngx.shared.rp_cache:get('versions/' .. svc) == nil then
                    fluentd.info("consul", {message="new endpoint", service=svc})
                end
                local c, err = cjson.decode(v)
                if c then
                    ngx.shared.rp_cache:set('versions/' .. svc, cmessagepack.pack(c))
                    for t,up in pairs(c) do
                        if ngx.shared.rp_cache:get('upstreams/' .. up) == nil then
                            ngx.shared.rp_cache:set('upstreams/' .. up, cmessagepack.pack({}))
                            ngx.timer.at(0, service_update, up, '0')
                        end
                    end
                end
            end
            if svcs[#svcs] == 'restrictions' then
                local c, err = cjson.decode(v)
                if c then
                    ngx.shared.rp_cache:set('restrictions/' .. svc, cmessagepack.pack(c))
                end
            end
            if svcs[#svcs] == 'type' then
                ngx.shared.rp_cache:set('type/' .. svc, v)
                if v == 'uwsgi' or v == 'proxy' then
                    table.insert(swaggers, '/' .. svc .. '/swagger.json')
                end
            end
        end
        ngx.shared.rp_cache:set('swagger/definitions', cmessagepack.pack(swaggers))
    end
    ngx.timer.at(delay, kv_update, myindex)
end

function _M.connect()
    local ok, err = ngx.shared.rp_cache:add('locks/consul', true)
    if ok then
        fluentd.info("consul", {message="starting consul monitoring"})
        ngx.timer.at(0, kv_update, '0')
    end
end

return _M
