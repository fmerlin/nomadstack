if ngx.var.status >= 400 then
    ngx.ctx.resp_body = (ngx.ctx.resp_body or "") .. ngx.arg[1]
end
