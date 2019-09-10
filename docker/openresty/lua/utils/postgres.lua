local cjson = require("cjson")
local cmessagepack = require("MessagePack")
local pgmoon = require('pgmoon.arrays')
local pgmoon_arrays = require('pgmoon')

local _M = cjson.decode(os.getenv("POSTGRES") or {})

function _M.is_in(val, lst)
    for i, e in ipairs(lst) do
        if e == val then
            return true
        end
    end
    return false
end

function _M.format(config, values)
    local conds = {}
    for k,v in pairs(values) do
        if _M.is_in(k, config.fields) then
            if type(v) == 'string' then
                table.insert(conds, k .. '="' .. v .. '"')
            else
                table.insert(conds, k .. '=' .. v)
            end
        end
    end
    if #conds == 0 then
            table.insert(conds, '1=1')
    end
    return conds
end

function _M.pg_crud()
    local res
    local m = ngx.var.http_method
    local pg = pgmoon.new(_M)
    local config = cmessagepack.unpack(ngx.shared.rp_cache:get('config/' .. ngx.var.service))
    pg:connect()
    if m == 'GET' then
        res = pg:query('select ' .. table.concat(config.fields,',') .. ' from ' .. config.table .. ' where ' .. table.concat(_M.format(config, ngx.ctx.args),' and '))
    elseif m == 'POST' then
        local body = cjson.decode(ngx.var.request_body)
        local fields = {}
        local data = {}
        for i,b in ipairs(body) do
            for k,v in pairs(b) do
                if _M.is_in(k, config.fields) then
                    table.insert(fields, k)
                    table.insert(data, v)
                end
            end
            res = pg:query('insert into ' .. config.table .. ' (' .. table.concat(fields,',') .. ' values(' .. pgmoon_arrays.encode_array(data) .. ')')
        end
    elseif m == 'PUT' then
        local body = cjson.decode(ngx.var.request_body)
        res = pg:query('update ' .. config.table .. ' set ' .. table.concat(_M.format(config, body),' and ') .. ' where ' .. table.concat(_M.format(config, ngx.ctx.args),' and '))
    elseif m == 'DELETE' then
        res = pg:query('delete from ' .. config.table .. ' where ' .. table.concat(_M.format(config, ngx.ctx.args),' and '))
    end
    pg:keepalive()
    return res
end

function _M.pg_query()
    local pg = pgmoon.new(_M)
    local config = cmessagepack.unpack(ngx.shared.rp_cache:get('config/' .. ngx.var.service))
    local res = pg:query(config.query)
    pg:keepalive()
    return res
end

return _M
