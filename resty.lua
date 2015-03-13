--[[
  
  Copyright (C) 2014 Masatoshi Teruya

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
 
  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.
 
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.

  resty.lua
  lua-httpcli-resty
  
  Created by Masatoshi Teruya on 14/11/14.
  
--]]

-- modules
local HttpCli = require('httpcli');
-- constants
local FAILOVER_STATUS = {
    -- bad gateway
    ['502'] = true,
    -- service unavailable
    ['503'] = true,
    -- gateway timedout
    ['504'] = true
};
local METHOD = {};
-- append method
for _, m in ipairs({
    'OPTIONS', 'GET', 'HEAD', 'POST', 'PUT', 'DELETE', 'TRACE', 'PATCH'
}) do
    METHOD[m] = ngx['HTTP_' .. m];
    METHOD[m:lower()] = METHOD[m];
end

-- class
local Resty = require('halo').class.Resty;


function Resty.proxy( inheritHeaders )
    local ctx = ngx.ctx;
    
    -- remove all parent header
    if inheritHeaders ~= true then
        for k, v in pairs( ngx.req.get_headers() ) do
            ngx.req.set_header( k, nil );
        end
    end
    
    -- set client specified uri and headers
    ngx.req.set_uri( ctx.uri, false );
    for k, v in pairs( ctx.header ) do
        ngx.req.set_header( k, v );
    end
    -- save request time
    ctx.latency = ngx.now();
end


-- gateway:string = proxy uri
function Resty:init( gateway, ... )
    if type( gateway ) ~= 'string' then
        return nil, 'gateway must be string';
    end
    protected(self).gateway = gateway;
    
    return HttpCli.new( self, METHOD, ... );
end


function Resty:request( req )
    local failover = {
        host = req.host,
        uri = req.uri
    };
    local gateway = protected(self).gateway;
    local nfail = 0;
    local entity, ctx;
    
    repeat
        req.header['Host'] = failover.host;
        ctx = {
            uri = failover.uri,
            header = req.header
        };
        entity = ngx.location.capture( gateway, {
            method = req.method,
            body = req.body,
            ctx = ctx
        });
        -- gateway timedout
        if FAILOVER_STATUS[tostring(entity.status)] then
            -- check failover
            nfail = nfail + 1;
            failover = req.failover[nfail];
        else
            -- calculate latency
            entity.latency = ngx.now() - ctx.latency;
            return entity;
        end
    until not failover;
    
    return entity;
end


return Resty.exports;
