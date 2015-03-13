lua-httpcli-resty
=========

Lua HTTP client module for OpenResty.

---

## Dependencies

- httpcli: https://github.com/mah0x211/lua-httpcli


## Installation

```sh
luarocks install httpcli-resty --from=http://mah0x211.github.io/rocks/
```


## Usage

this module will be sending the http request via `ngx.location.capture` API of OpenResty. please see https://github.com/openresty/lua-nginx-module/#ngxlocationcapture for more details of that API and behavior.


**Supported Method**

- OPTIONS
- GET
- HEAD
- POST
- PUT
- DELETE
- TRACE
- PATCH

**Example nginx.conf**

```
daemon off;
worker_processes    1;

events {
    worker_connections  1024;
    accept_mutex_delay  100ms;
}


http {
    sendfile            on;
    tcp_nopush          on;
    #keepalive_timeout  0;
    keepalive_requests  500000;
    #gzip               on;
    open_file_cache     max=100;
    include             mime.types;
    default_type        text/html;
    index               index.htm;
    resolver            8.8.8.8;
    resolver_timeout    5;
    
    #
    # log settings
    #
    access_log  off;
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';
    
    
    # 
    # lua global settings
    #
    lua_check_client_abort  on;
    lua_code_cache          on;
    
    #
    # initialize script
    #
    init_by_lua "HttpCliResty = require('httpcli.resty');";
    
    #
    # Admin Console
    #
    server {
        listen      1080;
        root        html;
        
        #
        # content handler: html
        #
        location ~* \.(html|htm)$ {
            content_by_lua "
                local inspect = require('util').inspect;
                local SYMBOLS = {
                    ['<'] = '&lt;',
                    ['>'] = '&gt;'
                };
                local cli, err = HttpCliResty.new('/proxy_gateway');
                local res;
                
                if err then
                    res = err;
                else
                    local timeoutForThisRequest = 30;
                    local entity;
                    -- also, can be pass the https url
                    entity, err = cli:get( 'http://example.com/', {
                        -- query    = <table>,
                        -- header   = <table>,
                        -- body     = <string or table>,
                        -- enctype  = <encoding-type string>
                        --            supported enctype:
                        --              * 'application/json'
                        --              * 'application/x-www-form-urlencoded'
                        -- failover = <failover-address table>
                        --            format: [scheme://]host[:port]
                        --            scheme: http or https
                        --            port: 0 - 65535
                        --            e.g.: {
                        --              'https://localhost',
                        --              this format will inherit a scheme of url argument
                        --              '127.0.0.1:8080'
                        --            }
                    }, timeoutForThisRequest );
                    if err then
                        res = err;
                    else
                        res = inspect( entity );
                    end
                end
                
                ngx.say( '<pre>' .. res:gsub('[<>]', SYMBOLS ) .. '</pre>' );
            ";
        }
        
        #
        # proxy
        #
        location /proxy_gateway {
            internal;
            #
            # HttpCliResty.proxy( [inheritHeaders:boolean] )
            # please pass false if you need to remove headers of parent request.
            #
            rewrite_by_lua          "HttpCliResty.proxy();";
            proxy_redirect          off;
            proxy_connect_timeout   60;
            proxy_send_timeout      60;
            proxy_read_timeout      60;
            proxy_pass              $uri;
            proxy_pass_request_body on;
        }
    }
}
```
