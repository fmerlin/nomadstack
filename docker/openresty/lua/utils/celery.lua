local cjson = require("cjson")
local misc = require("rp.utils.misc")
local fluentd = require("rp.utils.fluentd")
local _M = {}

function _M.create(self)
    self.celery_data = {}
    self.celery_event = function(msg)
        msg = cjson.decode(msg)
        if self.celery_data[msg.body.id] then
            if misc.is_in(msg.body.type, {"task-succeeded", "task-failed", "task-revoked"}) then
                self.celery_data[msg.id] = nil
            end
            fluentd.info('celery event', msg)
            return { action = 'read_reply', status = msg.body.type, id = msg.id }
        else
            return nil
        end
    end
    self.celery_message = function(msg)
        self.celery_data[msg.id] = true
        return cjson.encode({
            body = cjson.encode({ msg.args, msg.kwargs, nil }),
            headers = {
                task = msg.task,
                lang = 'py',
                origin = ngx.var.remote_addr
            },
            properties = {
                correlation_id = msg.id,
                content_type = 'application/json',
                content_encoding = 'utf-8'
            }
        })
    end
    return self
end


return _M
