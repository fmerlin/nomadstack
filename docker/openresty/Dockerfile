FROM openresty/openresty:bionic

RUN luarocks install lua-resty-http && \
    luarocks install lua-protobuf && \
    opm get SkyLothar/lua-resty-jwt && \
    opm get fperrad/lua-messagepack

ADD lua /usr/local/openresty/lualib/rp/
