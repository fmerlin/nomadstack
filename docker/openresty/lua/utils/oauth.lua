local cjson = require("cjson")
local fluentd = require("rp.utils.fluentd")
local jwt = require("resty.jwt")

local _M = cjson.decode(os.getenv("OAUTH") or "{}")

function _M.get_base_url()
    return ngx.var.scheme .. '://' .. ngx.var.server_name .. ':' .. ngx.var.server_port
end

function _M.login()
    fluentd.debug("oauth", "login")
    app.add_cookie("x_redirect_uri", ngx.var.request_uri, 60)
    return ngx.redirect(_M.signin_url .. '?' .. ngx.encode_args({ client_id = _M.client_id,
                                                                  scope = _M.scope,
                                                                  response_type = _M.response_type,
                                                                  redirect_uri = _M.get_base_url() .. '/signin' }))
end

function _M.load_user_info()
    fluentd.debug("oauth", "load_user_info")
    local res, err
    local args = ngx.ctx.args
    local uri_args = {
        client_id = _M.client_id,
        client_secret = _M.client_secret
    }
    if _M.reponse_type == 'token' then
        uri_args['access_token'] = args["token"]
        res = ngx.location.capture(M.details_url, {args=uri_args})
        if res.status == 200 then
            ngx.ctx.user = cjson.decode(res.body)
        else
            err = res.status
        end
    elseif _M.reponse_type == 'code' then
        uri_args['code'] = args["code"]
        uri_args['grant_type'] = "authorization_code"
        uri_args['redirect_uri'] = _M.get_base_url() .. '/token'
        res = ngx.location.capture(M.details_url, {method=ngx.HTTP_POST, args=uri_args})
        if res.status == 200 then
            res = cjson.decode(res.body)
            ngx.ctx.user = jwt:verify(_M.jwt_secret, res.id_token)
        else
            err = res.status
        end
    end
    if err then
        fluentd.error("oauth", {message="token not found", err=err})
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end
end

function _M.extract_bearer()
    fluentd.debug("oauth", "extract_bearer")
    local auth = ngx.header["Authorization"]
    if auth then
        local jwt_obj, err = jwt:verify(_M.jwt_secret, auth.sub(8)) -- len("Bearer: ")
        if err then
            fluentd.error("consul", {message="jwt verification failed", err=err})
            ngx.exit(ngx.HTTP_UNAUTHORIZED)
        else
            ngx.ctx.user =  jwt_obj
        end
    else
        ngx.ctx.user = {}
    end
end

return _M
