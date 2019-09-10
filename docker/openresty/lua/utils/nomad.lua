local http = require("rp.utils.http")
local fluentd = require("rp.utils.fluentd")
local cjson = require("cjson")
local cmessagepack = require("MessagePack")

local _M = cjson.decode(os.getenv("NOMAD") or "{}")

function _M.add_job()
    fluentd.debug("nomad", "add_job")
    local config = ngx.shared.rp_cache:get("job/" .. ngx.var.service)
    if config then
        config = cmessagepack.unpack(config)
        local res, err = http.post(_M, { path = '/v1/jobs' }, _M.gen_job(ngx.var.service, ngx.var.proxy_to, config))
        if err then
            fluentd.error("nomad", { message = "failed to start a job", err = err })
            ngx.exit(ngx.HTTP_BAD_GATEWAY)
        end
    end
end

function _M.gen_job(service, version, config)
    local d = {
        ["die-on-idle"] = false,
        idle = 1800,
        chdir = "/app/",
        ["wsgi-file"] = "$(WSGI_FILE)",
        socket = '{{ env "NOMAD_ADDR_uwsgi" }}',
        protocol = 'uwsgi',
        ["disable-logging"] = true,
        processes = 1,
        threads = 1,
        master = true,
        mount = '/' .. service .. '=app.py',
        module = 'app',
        callable = 'app'
    }
    for k, v in pairs(config.uwsgi) do
        d[k] = v
    end
    return { Job = { ID = service .. '-' .. version,
                     Name = service,
                     Datacenters = { os.getenv("NOMAD_DC") },
                     Type = "service",
                     TaskGroups = {
                         { Name = service,
                           EphemeralDisk = {
                               SizeMB = config.disk or 300,
                               Sticky = config.sticky or false,
                               Migrate = config.migrate or false
                           },
                           Tasks = {
                               { Name = service,
                                 Driver = "docker",
                                 Config = {
                                     image = config.image .. ':' .. version,
                                     network_mode = "host",
                                     volumes = {
                                         "secrets/uwsgi.json:/app/uwsgi.json",
                                         "local:/data"
                                     },
                                     logging = {
                                         type = "fluentd",
                                         config = {
                                             { ["fluentd-address"] = "localhost:" .. fluentd.port },
                                             { tag = "docker." .. service },
                                             { ["fluentd-async-connect"] = "true" }
                                         }
                                     }
                                 },
                                 Env = {
                                     CONSUL = os.getenv("CONSUL"),
                                     REDIS = os.getenv("REDIS"),
                                     FLUENTD = os.getenv("FLUENTD")
                                 },
                                 Resources = {
                                     CPU = config.cpu or 100,
                                     MemoryMB = config.memory or 300,
                                     Networks = {
                                         { MBits = config.network or 1,
                                           DynamicPorts = {
                                               { Label = "uwsgi" }
                                           }
                                         }
                                     },
                                     Templates = {
                                         { EmbeddedTmpl = cjson.encode({ uwsgi = d }),
                                           DestPath = "secrets/uwsgi.json",
                                           ChangeMode = "signal",
                                           ChangeSignal = "SIGHUP" }
                                     },
                                     Services = {
                                         { Name = service,
                                           Tags = { version },
                                           PortLabel = "uwsgi",
                                           Checks = {
                                               {
                                                   Type = "script",
                                                   Command = "uwsgi_curl",
                                                   Args = { "${NOMAD_ADDR_uwsgi}", "/health" },
                                                   Interval = (config.interval or 10) * 1000000000,
                                                   Timeout = (config.timeout or 2) * 1000000000
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
