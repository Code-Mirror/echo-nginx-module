# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Echo;

plan tests => 1 * blocks();

#$Test::Nginx::Echo::LogLevel = 'debug';

run_tests();

__DATA__

=== TEST 1: sanity
--- config
    location /main {
        echo_foreach_split '&' $query_string;
            echo_location_async $echo_it;
            echo '/* end */';
        echo_end;
    }
    location /sub/1.css {
        echo "body { font-size: 12pt; }";
    }
    location /sub/2.css {
        echo "table { color: 'red'; }";
    }
--- request
    GET /main?/sub/1.css&/sub/2.css
--- response_body
body { font-size: 12pt; }
/* end */
table { color: 'red'; }
/* end */



=== TEST 2: split in a url argument (echo_location_async)
--- config
    location /main_async {
        echo_foreach_split ',' $arg_cssfiles;
            echo_location_async $echo_it;
        echo_end;
    }
    location /foo.css {
        echo foo;
    }
    location /bar.css {
        echo bar;
    }
    location /baz.css {
        echo baz;
    }
--- request
    GET /main_async?cssfiles=/foo.css,/bar.css,/baz.css
--- response_body
foo
bar
baz



=== TEST 3: split in a url argument (echo_location)
--- config
    location /main_sync {
        echo_foreach_split ',' $arg_cssfiles;
            echo_location $echo_it;
        echo_end;
    }
    location /foo.css {
        echo foo;
    }
    location /bar.css {
        echo bar;
    }
    location /baz.css {
        echo baz;
    }
--- request
    GET /main_sync?cssfiles=/foo.css,/bar.css,/baz.css
--- response_body
foo
bar
baz



=== TEST 4: empty loop
--- config
    location /main {
        echo "start";
        echo_foreach_split ',' $arg_cssfiles;
        echo_end;
        echo "end";
    }
--- request
    GET /main?cssfiles=/foo.css,/bar.css,/baz.css
--- response_body
start
end



=== TEST 5: trailing delimiter
--- config
    location /main_t {
        echo_foreach_split ',' $arg_cssfiles;
            echo_location_async $echo_it;
        echo_end;
    }
    location /foo.css {
        echo foo;
    }
--- request
    GET /main_t?cssfiles=/foo.css,
--- response_body
foo



=== TEST 6: multi-char delimiter
--- config
    location /main_sleep {
        echo_foreach_split '-a-' $arg_list;
            echo $echo_it;
        echo_end;
    }
--- request
    GET /main_sleep?list=foo-a-bar-a-baz
--- response_body
foo
bar
baz



=== TEST 7: loop with sleep
--- config
    location /main_sleep {
        echo_foreach_split '-' $arg_list;
            echo_sleep 0.001;
            echo $echo_it;
        echo_end;
    }
--- request
    GET /main_sleep?list=foo-a-bar-A-baz
--- response_body
foo
a
bar
A
baz
