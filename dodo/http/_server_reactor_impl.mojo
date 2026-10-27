"""Reactor-backed HTTP server: re-export surface for the loops.

The per-connection state machine (``ConnHandle`` and the keep-alive
helpers) lives in ``dodo.http._reactor``; the epoll/kqueue loops in
``dodo.http._server_reactor_epoll``; the io_uring buffer-ring loop in
``dodo.http._server_reactor_uring``.
"""

from ._reactor import (
    STATE_READING,
    STATE_WRITING,
    STATE_PARKED,
    STATE_CLOSING,
    StepResult,
    ConnHandle,
    _detect_h2c_upgrade_inline,
    _is_content_length,
    _is_date,
    _is_connection,
    _connection_is_keepalive,
    _connection_is_close,
    _compact_read_buf_drop_prefix,
    _compute_close_after,
    _wants_close,
)

from ._server_reactor_epoll import (
    _poll_timeout_ms,
    _accept_errno_is_retry,
    _arm_accept_timer,
    _conn_alloc_addr,
    _conn_free_addr,
    _conn_ptr_from_int,
    _apply_step,
    _cleanup_conn,
    _accept_loop,
    _accept_loop_fd,
    run_reactor_loop_shared,
    run_reactor_loop_cancel,
)

from ._server_reactor_uring import (
    run_uring_bufring_reactor_loop,
    run_uring_bufring_reactor_loop_shared,
)
from ._server_uring_setup import _probe_bufring_setup_flags
