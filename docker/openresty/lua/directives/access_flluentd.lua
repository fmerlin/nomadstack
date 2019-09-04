local app = require("rp.utils.app")
local fluentd = require("rp.utils.fluentd")
local oauth = require("rp.utils.oauth")

app.load_session()
if app.should_auth() then
    oauth.login()
else
    app.load_settings()
    app.throttle()
    fluentd.remote_log(ngx.var.service, cjson.decode(ngx.var.request_body))
end
