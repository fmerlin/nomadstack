local app = require("rp.utils.app")
local oauth = require("rp.utils.oauth")
local ws_redis = require("rp.utils.ws_redis")

app.load_session()
if app.should_auth() then
    oauth.login()
else
    app.load_settings()
    app.throttle()
    ws_redis.connect()
end