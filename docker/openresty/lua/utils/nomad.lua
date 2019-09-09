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
    fluentd.debug("nomad", "add_job")
    check(http.post(_M, {path='/v1/jobs'}, _M.gen_job(ngx.var.proxy_to)))
end

function _M.gen_job(svc)
    local fluentbit_port = 24244
    local EmbeddedTmpl = [[
[uwsgi]
die-on-idle = false
idle = 1800
chdir = /app/
wsgi-file = $(WSGI_FILE)
socket = {{ env "NOMAD_ADDR_uwsgi" }}
protocol = uwsgi
disable-logging = true
processes = 4
threads = 4
master = true
module = app
callable = app
]]
    return { Job = { ID = svc,
                     Name = svc,
                     Datacenters = { os.getenv("NOMAD_DC") },
                     Type = "service",
                     TaskGroups = {
                         { Name = svc,
                           Tasks = {
                               { Name = svc,
                                 Driver = "docker",
                                 Config = {
                                     image = svc,
                                     network_mode = "host",
                                     volumes = { "local/uwsgi.ini:/app/uwsgi.ini" },
                                     logging = {
                                         type = "fluentd",
                                         config = {
                                             { ["fluentd-address"] = "localhost:" .. fluentbit_port },
                                             { tag = "docker.uwsgi" },
                                             { ["fluentd-async-connect"] = "true" }
                                         }
                                     }
                                 },
                                 Resources = {
                                     CPU = 100,
                                     MemoryMB = 300,
                                     Networks = {
                                         { MBits = 1,
                                           DynamicPorts = {
                                               { Label = "uwsgi" }
                                           }
                                         }
                                     },
                                     Templates = {
                                         { EmbeddedTmpl = EmbeddedTmpl,
                                           DestPath = "local/uwsgi.ini",
                                           ChangeMode = "signal",
                                           ChangeSignal = "SIGHUP" }
                                     },
                                     Services = {
                                         { Name = svc,
                                           Tags = {},
                                           PortLabel = "uwsgi",
                                           Checks = {
                                               {
                                                   Type = "script",
                                                   Command = "uwsgi_curl",
                                                   Args = { "${NOMAD_ADDR_uwsgi}/health" },
                                                   Interval = 10000000000,
                                                   Timeout = 2000000000
                                               }
                                           }
                                         }
                                     }
                                 }
                               }
                           }
                         }
                     }
        }
    }
end

return _M
