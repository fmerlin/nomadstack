local cjson = require("cjson")
local redis = require("resty.redis")
local fluentd = require("rp.utils.fluentd")
local misc = require("rp.utils.misc")
local cmessagepack = require("MessagePack")

local _M = cjson.decode(os.getenv("REDIS") or "{}")

function _M.create(self)
    self.subscribe = function(msg, decode)
        local redis_srv = redis:new()
        redis_srv:set_timeout(_M.timeout) -- 1 sec
        local _, err = redis_srv:connect(_M.host, _M.port)
        if err == nil then
            _, err = redis_srv:auth(_M.password)
            if err == nil then
                redis_srv:select(ngx.ctx.settings.redis_db or _M.db or 0)
                _, err = redis_srv:psubscribe(msg.channel)
                while true do
                    local res, err = self.redis_srv:read_reply()
                    if res then
                        local f = io.open(res[3], "rb")
                        if f then
                            local data = decode(f:read("*all"))
                            if data and data ~= self.celery_event then
                                data = {
                                    action = 'read_reply',
                                    channel = res[2],
                                    id = msg.id,
                                    status = 'ok',
                                    data = data
                                }
                            end
                            fluentd.info('redis receiving', msg)
                            self.send(data)
                        end
                    else
                        local err_msg = {
                            action = 'read_reply',
                            status = 'error',
                            err = err,
                            id = msg.id,
                            channel = msg.channel
                        }
                        fluentd.error('redis issue', err_msg)
                        self.send(err_msg)
                        redis_srv:set_keepalive(_M.idle, _M.pool_size)
                        return
                    end
                end
            end
        end
    end

    self.encoder = {
        json = cjson.encode,
        msgpack = cmessagepack.pack,
        str = tostring,
        celery_message = self.celery_message
    }

    self.decoder = {
        json = cjson.decode,
        msgpack = cmessagepack.unpack,
        str = tostring,
        celery_event = self.celery_event
    }

    self.execute = function(msg)
        local res, err, _, encode, decode
        local redis_srv = redis:new()
        redis_srv:set_timeout(_M.timeout) -- 1 sec
        _, err = redis_srv:connect(_M.host, _M.port)
        if err == nil then
            _, err = redis_srv:auth(_M.password)

            if err == nil then
                redis_srv:select(ngx.ctx.settings.redis_db or _M.db or 0)
                encode = self.encoder[msg.encoding]
                decode = self.decoder[msg.encoding]

                if msg.action == 'publish' then
                    if misc.is_in(msg.channel, self.config.publish_channels) then
                        _, err = redis_srv:publish(msg.channel, encode(msg.data))
                    end
                elseif msg.action == 'psubscribe' then
                    if misc.is_in(msg.channel, self.config.psubscribe_channels) then
                        ngx.thread.spawn(self.subscribe, msg, decode)
                    end
                elseif msg.action == 'lpush' then
                    if misc.is_in(msg.queue, self.config.lpush_queues) then
                        _, err = redis_srv:lpush(msg.queue or self.default_queue, encode(msg))
                    end
                elseif msg.action == 'lpop' then
                    if misc.is_in(msg.queue, self.config.lpop_queues) then
                        res, err = redis_srv:lpop(msg.queue or self.default_queue)
                    end
                elseif msg.action == 'set' then
                    _, err = redis_srv:set(msg.key, encode(msg.data))
                elseif msg.action == 'get' then
                    res, err = redis_srv:get(msg.key)
                end
            end
        end
        if err then
            msg.status = 'error'
            msg.err = err
            fluentd.error('redis issue', msg)
            self.send(msg)
        end
        if res then
            res, err = decode(res)
            if err then
                msg.status = 'error'
                msg.err = err
                fluentd.error('encoding issue', msg)
                self.send(msg)
            else
                msg.status = 'ok'
                msg.data = res
                fluentd.info('redis sending', msg)
                self.send(msg)
            end
        end
        redis_srv:set_keepalive(_M.idle, _M.pool_size)
    end
end


return _M
