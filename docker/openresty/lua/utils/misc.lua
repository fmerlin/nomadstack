local _M = {}

function _M.uuid()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
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

function _M.check_map(map1, map2)
    for k2, v2 in pairs(map1) do
        if _M.does_not_equal(map2[k2], v2) then
            return false
        end
    end
    return true
end

function _M.is_in(item, list)
    if list == nil or item == nil then
        return true
    end

    for i,v in ipairs(list) do
        if v == item then
            return true
        end
    end

    return false
end

return _M