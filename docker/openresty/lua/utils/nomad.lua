local http = require("rp.utils.http")
local fluentd = require("rp.utils.fluentd")
local redis = require("rp.utils.redis")
local cjson = require("cjson")
local cmessagepack = require("MessagePack")

local _M = cjson.decode(os.getenv("NOMAD") or "{}")

function _M.add_uwsgi_job(service, version)
    fluentd.debug("nomad", "add_uwsgi_job")
    local config = ngx.shared.rp_cache:get("job/" .. service)
    if config then
        config = cmessagepack.unpack(config)
        local res, err = http.post(_M, {
            path = '/v1/jobs',
            headers = { ["X-Nomad-Token"] = os.getenv("NOMAD_TOKEN") }
        }, _M.gen_uwsgi_job(service, version, config, redis))
    end
end

function _M.add_celery_job(service, version)
    fluentd.debug("nomad", "add_celery_job")
    local config = ngx.shared.rp_cache:get("job/" .. service)
    if config then
        config = cmessagepack.unpack(config)
        local res, err = http.post(_M, {
            path = '/v1/jobs',
            headers = { ["X-Nomad-Token"] = os.getenv("NOMAD_TOKEN") }
        }, _M.gen_celery_job(service, version, config, redis))
    end
end

function _M.gen_celery_json(redis, config, service, version)
    local redis_url = "redis://" .. redis.password .. "@" .. redis.host .. ":" .. (redis.port or 6739) "/" .. (ngx.ctx.settings.redis_db or 0)
    local d = {
        broker_url = redis_url,
        result_backend = redis_url,
        task_serializer = 'json',
        result_serializer = 'json',
        accept_content = { 'application/json' },
        task_default_queue = service .. '-' .. version
    }
    for k, v in pairs(config.celery) do
        d[k] = v
    end
    return cjson.encode(d)
end

function _M.gen_uwsgi_ini(service, config)
    local d = {
        ["die-on-idle"] = false,
        idle = 1800,
        chdir = "/app/",
        ["wsgi-file"] = "$(WSGI_FILE)",
        socket = '{{ env "NOMAD_ADDR_wsgi" }}',
        protocol = 'uwsgi',
        ["disable-logging"] = true,
        processes = 1,
        threads = 1,
        master = true,
        mount = '/' .. service .. '=flask_app.py',
        ["manage-script-name"] = true,
        module = 'app',
        callable = 'app'
    }
    for k, v in pairs(config.uwsgi) do
        d[k] = v
    end
    local res = { '[uwsgi]' }
    for k, v in pairs(config) do
        table.insert(res, k .. '=' .. tostring(v))
    end
    return table.concat(res, '\n')
end

function _M.gen_uwsgi_job(service, version, config, redis)
    return {
        Job = {
            ID = service .. '-' .. version,
            Name = service,
            Datacenters = { os.getenv("NOMAD_DC") },
            Type = "service",
            TaskGroups = {
                {
                    Name = service,
                    EphemeralDisk = {
                        SizeMB = config.disk or 300,
                        Sticky = config.sticky or false,
                        Migrate = config.migrate or false
                    },
                    Tasks = {
                        {
                            Name = service,
                            Driver = "docker",
                            Config = {
                                image = config.image .. ':' .. version,
                                network_mode = "host",
                                entrypoint = { "uwsgi", "--ini", "/secrets/uwsgi.ini" },
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
                                FLUENTD = os.getenv("FLUENTD"),
                                UWSGI_VASSAL_SOCKET = "/run/uwsgi/*.socket",
                                CELERY_CONFIG_FILE = '/secrets/celery.json',
                                REDIS_DB = ngx.ctx.settings.db or '0'
                            },
                            Meta = {
                                version = version
                            },
                            Vault = {
                                Policies = config.policies or {},
                                ChangeMode = "signal",
                                ChangeSignal = "SIGHUP"
                            },
                            Templates = {
                                {
                                    EmbeddedTmpl = _M.gen_uwsgi_ini(service, config),
                                    DestPath = "secrets/uwsgi.ini",
                                    ChangeMode = "signal",
                                    ChangeSignal = "SIGHUP"
                                },
                                {
                                    EmbeddedTmpl = _M.gen_celery_json(redis, config, service, version),
                                    DestPath = "secrets/celery.json",
                                    ChangeMode = "signal",
                                    ChangeSignal = "SIGHUP"
                                }
                            },
                            Services = {
                                {
                                    Name = service,
                                    Tags = { version, "wsgi" },
                                    Meta = {
                                        version = version
                                    },
                                    PortLabel = "wsgi",
                                    Checks = {
                                        {
                                            Type = "script",
                                            Command = "uwsgi_curl",
                                            Args = { "${NOMAD_ADDR_wsgi}", "/health" },
                                            Interval = (config.interval or 10) * 1000000000,
                                            Timeout = (config.timeout or 2) * 1000000000
                                        }
                                    }
                                }
                            },
                            Resources = {
                                CPU = config.cpu or 100,
                                MemoryMB = config.memory or 300,
                                Networks = {
                                    {
                                        MBits = config.network or 1,
                                        DynamicPorts = {
                                            { Label = "wsgi" }
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

function _M.gen_celery_job(service, version, config, redis)
    return {
        Job = {
            ID = service .. '-' .. version,
            Name = service,
            Datacenters = { os.getenv("NOMAD_DC") },
            Type = "service",
            TaskGroups = {
                {
                    Name = service,
                    EphemeralDisk = {
                        SizeMB = config.disk or 300,
                        Sticky = config.sticky or false,
                        Migrate = config.migrate or false
                    },
                    Tasks = {
                        {
                            Name = service,
                            Driver = "docker",
                            Config = {
                                image = config.image .. ':' .. version,
                                network_mode = "host",
                                entrypoint = { "celery", "-A", config.entry or "celery_app", "worker" },
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
                                FLUENTD = os.getenv("FLUENTD"),
                                CELERY_CONFIG_FILE = '/secrets/celery.json',
                                REDIS_DB = ngx.ctx.settings.db or '0'
                            },
                            Meta = {
                                version = version
                            },
                            Vault = {
                                Policies = config.policies or {},
                                ChangeMode = "signal",
                                ChangeSignal = "SIGHUP"
                            },
                            Templates = {
                                {
                                    EmbeddedTmpl = _M.gen_celery_json(redis, config, service, version),
                                    DestPath = "secrets/celery.json",
                                    ChangeMode = "signal",
                                    ChangeSignal = "SIGHUP"
                                }
                            },
                            Services = {
                                {
                                    Name = service,
                                    Tags = { version, "celery" },
                                    Meta = {
                                        version = version
                                    },
                                    Checks = {
                                        {
                                            Type = "script",
                                            Command = "celery",
                                            Args = { "-A", config.entry or 'celery_app', "status" },
                                            Interval = (config.interval or 10) * 1000000000,
                                            Timeout = (config.timeout or 2) * 1000000000
                                        }
                                    }
                                }
                            },
                            Resources = {
                                CPU = config.cpu or 100,
                                MemoryMB = config.memory or 300
                            }
                        }
                    }
                }
            }
        }
    }
end


return _M
