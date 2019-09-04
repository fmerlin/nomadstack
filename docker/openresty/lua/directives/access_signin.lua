local app = require("rp.utils.app")
local oauth = require("rp.utils.oauth")
local riak = require("rp.utils.riak")

oauth.load_user_info()
riak.load_user_info()
app.save_session()
ngx.redirect(ngx.var.cookie_x_redirect_uri)
