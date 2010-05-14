#define DDEBUG 0

#include "ddebug.h"

#include "ngx_http_echo_handler.h"
#include "ngx_http_echo_echo.h"
#include "ngx_http_echo_util.h"
#include "ngx_http_echo_sleep.h"
#include "ngx_http_echo_var.h"
#include "ngx_http_echo_timer.h"
#include "ngx_http_echo_location.h"
#include "ngx_http_echo_subrequest.h"
#include "ngx_http_echo_request_info.h"
#include "ngx_http_echo_foreach.h"

#include <nginx.h>
#include <ngx_log.h>

ngx_int_t
ngx_http_echo_handler_init(ngx_conf_t *cf)
{
    ngx_int_t         rc;

    rc = ngx_http_echo_echo_init(cf);
    if (rc != NGX_OK) {
        return rc;
    }

    return ngx_http_echo_add_variables(cf);
}


void
ngx_http_echo_wev_handler(ngx_http_request_t *r)
{
    ngx_int_t                    rc;
    ngx_http_echo_ctx_t         *ctx;


    dd_enter();

    ctx = ngx_http_get_module_ctx(r, ngx_http_echo_module);

    if (ctx == NULL) {
        ngx_http_finalize_request(r, NGX_ERROR);
        return;
    }

    ctx->next_handler_cmd++;

    rc = ngx_http_echo_run_cmds(r);

    dd("rc: %d", (int) rc);

    if (rc != NGX_AGAIN && rc != NGX_DONE) {
        ngx_http_finalize_request(r, rc);
    }
}


ngx_int_t
ngx_http_echo_handler(ngx_http_request_t *r)
{
    ngx_int_t           rc;

    rc = ngx_http_echo_run_cmds(r);

    if (rc == NGX_ERROR) {
        return NGX_HTTP_INTERNAL_SERVER_ERROR;
    }

    if (rc >= NGX_HTTP_SPECIAL_RESPONSE) {
        return rc;
    }

    if (rc == NGX_AGAIN || rc == NGX_DONE) {
#if defined(nginx_version) && nginx_version >= 8011
        r->main->count++;
#endif

        return NGX_DONE;
    }

    return NGX_OK;
}


ngx_int_t
ngx_http_echo_run_cmds(ngx_http_request_t *r)
{
    ngx_http_echo_loc_conf_t    *elcf;
    ngx_http_echo_ctx_t         *ctx;
    ngx_int_t                    rc;
    ngx_array_t                 *cmds;
    ngx_array_t                 *computed_args = NULL;
    ngx_http_echo_cmd_t         *cmd;
    ngx_http_echo_cmd_t         *cmd_elts;
    ngx_array_t                 *opts = NULL;

    elcf = ngx_http_get_module_loc_conf(r, ngx_http_echo_module);
    cmds = elcf->handler_cmds;
    if (cmds == NULL) {
        return NGX_DECLINED;
    }

    ctx = ngx_http_get_module_ctx(r, ngx_http_echo_module);
    if (ctx == NULL) {
        rc = ngx_http_echo_init_ctx(r, &ctx);
        if (rc != NGX_OK) {
            return rc;
        }

        ngx_http_set_ctx(r, ctx, ngx_http_echo_module);
    }

    dd("exec handler: %.*s: %i", (int) r->uri.len, r->uri.data,
            (int) ctx->next_handler_cmd);

    cmd_elts = cmds->elts;

    for (; ctx->next_handler_cmd < cmds->nelts; ctx->next_handler_cmd++) {

        cmd = &cmd_elts[ctx->next_handler_cmd];

        /* evaluate arguments for the current cmd (if any) */
        if (cmd->args) {
            computed_args = ngx_array_create(r->pool, cmd->args->nelts,
                    sizeof(ngx_str_t));

            if (computed_args == NULL) {
                return NGX_HTTP_INTERNAL_SERVER_ERROR;
            }

            opts = ngx_array_create(r->pool, 1, sizeof(ngx_str_t));

            if (opts == NULL) {
                return NGX_HTTP_INTERNAL_SERVER_ERROR;
            }

            rc = ngx_http_echo_eval_cmd_args(r, cmd, computed_args, opts);
            if (rc != NGX_OK) {
                ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                        "Failed to evaluate arguments for "
                        "the directive.");
                return rc;
            }
        }

        /* do command dispatch based on the opcode */
        switch (cmd->opcode) {
        case echo_opcode_echo:
            /* XXX moved the following code to a separate
             * function */
            dd("found echo opcode");
            rc = ngx_http_echo_exec_echo(r, ctx, computed_args,
                    0 /* in filter */, opts);
            break;

        case echo_opcode_echo_request_body:
            rc = ngx_http_echo_exec_echo_request_body(r, ctx);
            break;

        case echo_opcode_echo_location_async:
            dd("found opcode echo location async...");
            rc = ngx_http_echo_exec_echo_location_async(r, ctx,
                    computed_args);
            break;

        case echo_opcode_echo_location:
            return ngx_http_echo_exec_echo_location(r, ctx, computed_args);
            break;

        case echo_opcode_echo_subrequest_async:
            dd("found opcode echo subrequest async...");
            rc = ngx_http_echo_exec_echo_subrequest_async(r, ctx,
                    computed_args);
            break;

        case echo_opcode_echo_subrequest:
            return ngx_http_echo_exec_echo_subrequest(r, ctx, computed_args);
            break;

        case echo_opcode_echo_sleep:
            return ngx_http_echo_exec_echo_sleep(r, ctx, computed_args);
            break;

        case echo_opcode_echo_flush:
            rc = ngx_http_echo_exec_echo_flush(r, ctx);
            break;

        case echo_opcode_echo_blocking_sleep:
            rc = ngx_http_echo_exec_echo_blocking_sleep(r, ctx,
                    computed_args);
            break;

        case echo_opcode_echo_reset_timer:
            rc = ngx_http_echo_exec_echo_reset_timer(r, ctx);
            break;

        case echo_opcode_echo_duplicate:
            rc = ngx_http_echo_exec_echo_duplicate(r, ctx, computed_args);
            break;

        case echo_opcode_echo_read_request_body:
            ctx->wait_read_request_body = 0;

            rc = ngx_http_echo_exec_echo_read_request_body(r, ctx);

#if defined(nginx_version) && nginx_version >= 8011
            /* XXX read_client_request_body always increments the counter */
            r->main->count--;
#endif

            dd("read request body: %d", (int) rc);

            if (rc == NGX_OK) {
                continue;
            }

            ctx->wait_read_request_body = 1;

            r->write_event_handler = ngx_http_request_empty_handler;

            return rc;
            break;

        case echo_opcode_echo_foreach_split:
            rc = ngx_http_echo_exec_echo_foreach_split(r, ctx, computed_args);
            break;

        case echo_opcode_echo_end:
            rc = ngx_http_echo_exec_echo_end(r, ctx);
            break;

        case echo_opcode_echo_exec:
            rc = ngx_http_echo_exec_exec(r, ctx, computed_args);

#if defined(nginx_version) && nginx_version >= 8011
            if (rc == NGX_DONE) {
                r->main->count--;
            }
#endif

            return rc;
            break;

        default:
            ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                    "Unknown opcode: %d", cmd->opcode);
            return NGX_HTTP_INTERNAL_SERVER_ERROR;
            break;
        }

        if (rc == NGX_ERROR || rc >= NGX_HTTP_SPECIAL_RESPONSE) {
            return rc;
        }
    }

    rc = ngx_http_echo_send_chain_link(r, ctx, NULL /* indicate LAST */);

    if (rc == NGX_ERROR || rc >= NGX_HTTP_SPECIAL_RESPONSE) {
        return rc;
    }

    return NGX_OK;
}


ngx_int_t
ngx_http_echo_post_subrequest(ngx_http_request_t *r,
        void *data, ngx_int_t rc)
{
    ngx_http_request_t          *pr;
    ngx_http_echo_ctx_t         *pr_ctx;


    dd_enter();

    pr = r->parent;

    pr_ctx = ngx_http_get_module_ctx(pr, ngx_http_echo_module);
    if (pr_ctx == NULL) {
        return NGX_ERROR;
    }

    pr->write_event_handler = ngx_http_echo_wev_handler;

    /* ensure that the parent request is (or will be)
     *  posted out the head of the r->posted_requests chain */

    if (r->main->posted_requests) {
        rc = ngx_http_echo_post_request_at_head(pr, NULL);
        if (rc != NGX_OK) {
            return NGX_ERROR;
        }
    }

    return rc;
}
