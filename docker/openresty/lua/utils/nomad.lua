local http = require("rp.utils.http")
local fluentd = require("rp.utils.fluentd")
local cjson = require("cjson")

local _M = cjson.decode(os.getenv("NOMAD") or "{}")

function check(res, err)
    if err then
        fluentd.error("nomad", {message="failed to start a job", err=err})
        ngx.exit(ngx.HTTP_BAD_GATEWAY)
    end
    return res
end

function _M.add_job()
    local f = check(io.open('/jobs/' .. ngx.var.service .. '.nomad', "r"))
    local content = check(f:read("*all"))
    f:close()
    content = content:gsub('$JOBID', ngx.var.proxy_to)
    check(http.post(_M, {path='/v1/jobs'}, content))
end

return _M
