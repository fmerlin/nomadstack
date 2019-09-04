local app = require("rp.utils.app")
local oauth = require("rp.utils.oauth")

app.load_session()
if app.should_auth() then
    oauth.login()
else
    app.load_settings()
    app.throttle()
    app.set_upstream()
end
