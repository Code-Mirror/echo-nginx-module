# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Echo;

plan tests => 1 * blocks();

#$Test::Nginx::Echo::LogLevel = 'debug';

run_tests();

__DATA__

=== TEST 1: sanity - GET
--- config
    location /main {
        echo_subrequest_async GET /sub;
    }
    location /sub {
        echo "sub method: $echo_request_method";
        echo "main method: $echo_client_request_method";
    }
--- request
    GET /main
--- response_body
sub method: GET
main method: GET



=== TEST 2: sanity - DELETE
--- config
    location /main {
        echo_subrequest_async DELETE /sub;
    }
    location /sub {
        echo "sub method: $echo_request_method";
        echo "main method: $echo_client_request_method";
    }
--- request
    GET /main
--- response_body
sub method: DELETE
main method: GET



=== TEST 3: trailing echo
--- config
    location /main {
        echo_subrequest_async GET /sub;
        echo after subrequest;
    }
    location /sub {
        echo hello;
    }
--- request
    GET /main
--- response_body
hello
after subrequest



=== TEST 4: leading echo
--- config
    location /main {
        echo before subrequest;
        echo_subrequest_async GET /sub;
    }
    location /sub {
        echo hello;
    }
--- request
    GET /main
--- response_body
before subrequest
hello



=== TEST 5: leading & trailing echo
--- config
    location /main {
        echo before subrequest;
        echo_subrequest_async GET /sub;
        echo after subrequest;
    }
    location /sub {
        echo hello;
    }
--- request
    GET /main
--- response_body
before subrequest
hello
after subrequest



=== TEST 6: multiple subrequests
--- config
    location /main {
        echo before sr 1;
        echo_subrequest_async GET /sub;
        echo after sr 1;
        echo before sr 2;
        echo_subrequest_async GET /sub;
        echo after sr 2;
    }
    location /sub {
        echo hello;
    }
--- request
    GET /main
--- response_body
before sr 1
hello
after sr 1
before sr 2
hello
after sr 2



=== TEST 7: timed multiple subrequests (blocking sleep)
--- config
    location /main {
        echo_reset_timer;
        echo_subrequest_async GET /sub1;
        echo_subrequest_async GET /sub2;
        echo "took $echo_timer_elapsed sec for total.";
    }
    location /sub1 {
        echo_blocking_sleep 0.02;
        echo hello;
    }
    location /sub2 {
        echo_blocking_sleep 0.01;
        echo world;
    }

--- request
    GET /main
--- response_body_like
^hello
world
took 0\.00[0-5] sec for total\.$



=== TEST 8: timed multiple subrequests (non-blocking sleep)
--- config
    location /main {
        echo_reset_timer;
        echo_subrequest_async GET /sub1;
        echo_subrequest_async GET /sub2;
        echo "took $echo_timer_elapsed sec for total.";
    }
    location /sub1 {
        echo_sleep 0.02;
        echo hello;
    }
    location /sub2 {
        echo_sleep 0.01;
        echo world;
    }

--- request
    GET /main
--- response_body_like
^hello
world
took 0\.00[0-5] sec for total\.$



=== TEST 9: location with args
--- config
    location /main {
        echo_subrequest_async GET /sub -q 'foo=Foo&bar=Bar';
    }
    location /sub {
        echo $arg_foo $arg_bar;
    }
--- request
    GET /main
--- response_body
Foo Bar



=== TEST 10: encoded chars in query strings
--- config
    location /main {
        echo_subrequest_async GET /sub -q 'foo=a%20b&bar=Bar';
    }
    location /sub {
        echo $arg_foo $arg_bar;
    }
--- request
    GET /main
--- response_body
a%20b Bar



=== TEST 11: UTF-8 chars in query strings
--- config
    location /main {
        echo_subrequest_async GET /sub -q 'foo=你好';
    }
    location /sub {
        echo $arg_foo;
    }
--- request
    GET /main
--- response_body
你好



=== TEST 12: encoded chars in location url
--- config
    location /main {
        echo_subrequest_async GET /sub%31 -q 'foo=Foo&bar=Bar';
    }
    location /sub1 {
        echo 'sub1';
    }
    location /sub%31 {
        echo 'sub%31';
    }
--- request
    GET /main
--- response_body
sub%31



=== TEST 13: querystring in url
--- config
    location /main {
        echo_subrequest_async GET /sub?foo=Foo&bar=Bar;
    }
    location /sub {
        echo $arg_foo $arg_bar;
    }
--- request
    GET /main
--- response_body eval: " \n"



=== TEST 14: explicit flush in main request
flush won't really flush the buffer...
--- config
    location /main_flush {
        echo 'pre main';
        echo_subrequest_async GET /sub;
        echo 'post main';
        echo_flush;
    }

    location /sub {
        echo_sleep 0.02;
        echo 'sub';
    }
--- request
    GET /main_flush
--- response_body
pre main
sub
post main



=== TEST 15: POST subrequest with body (with proxy in the middle) and without read body explicitly
--- config
    location /main {
        echo_subrequest_async POST /proxy -b 'hello, world';
    }
    location /proxy {
        proxy_pass $scheme://127.0.0.1:$server_port/sub;
    }
    location /sub {
        echo "sub method: $echo_request_method.";
        # we need to read body explicitly here...or $echo_request_body
        #   will evaluate to empty ("")
        echo "sub body: $echo_request_body.";
    }
--- request
    GET /main
--- response_body
sub method: POST.
sub body: .



=== TEST 16: POST subrequest with body (with proxy in the middle) and read body explicitly
--- config
    location /main {
        echo_subrequest_async POST /proxy -b 'hello, world';
    }
    location /proxy {
        proxy_pass $scheme://127.0.0.1:$server_port/sub;
    }
    location /sub {
        echo "sub method: $echo_request_method.";
        # we need to read body explicitly here...or $echo_request_body
        #   will evaluate to empty ("")
        echo_read_request_body;
        echo "sub body: $echo_request_body.";
    }
--- request
    GET /main
--- response_body
sub method: POST.
sub body: hello, world.
