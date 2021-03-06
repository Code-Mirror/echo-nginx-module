# vi:filetype=

use lib 'lib';
use Test::Nginx::Socket;

plan tests => 2 * blocks();

#$Test::Nginx::LWP::LogLevel = 'debug';

run_tests();

__DATA__

=== TEST 1: sanity
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /dup {
        echo_duplicate 3 a;
    }
--- request
    GET /dup
--- response_body: aaa



=== TEST 2: abc abc
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /dup {
        echo_duplicate 2 abc;
    }
--- request
    GET /dup
--- response_body: abcabc



=== TEST 3: big size with underscores
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /dup {
        echo_duplicate 10_000 A;
    }
--- request
    GET /dup
--- response_body eval
'A' x 10_000



=== TEST 4: 0 duplicate 0 empty strings
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /dup {
        echo_duplicate 0 "";
    }
--- request
    GET /dup
--- response_body



=== TEST 5: 0 duplicate non-empty strings
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /dup {
        echo_duplicate 0 "abc";
    }
--- request
    GET /dup
--- response_body



=== TEST 6: duplication of empty strings
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /dup {
        echo_duplicate 2 "";
    }
--- request
    GET /dup
--- response_body



=== TEST 7: sanity (HEAD)
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /dup {
        echo_duplicate 3 a;
    }
--- request
    HEAD /dup
--- response_body

