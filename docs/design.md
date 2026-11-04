# Design

- **Callback-free.** Mojo closures stored in a struct need a type per closure; a list of
  `(token, events)` needs none, and the caller's `if`/`Dict` dispatch is as fast as it gets.
- **Timers in the epoll timeout.** A binary min-heap on the deadline; `wait()` passes the time to
  the next deadline as epoll's timeout and appends due timers after epoll returns. No timerfd, no
  extra descriptor or syscall per timer.
- **Threads.** `epoll_wait` on one set from many threads is safe in the kernel. `ready()` takes the
  caller's buffer so threads share nothing in user space; pair it with `ONESHOT` so each event goes
  to one thread (mojo-bento does this). `wait()` owns the heap and belongs to one thread.
- **Errors.** Setup failures raise `aio: <call> failed (errno N)`. Per-connection I/O returns codes
  (-1 not ready, -2 gone) because a dropped peer is normal, not exceptional. `accept` returns -1 on
  ECONNABORTED/EMFILE/ENFILE so a full descriptor table does not kill the server.
- **Layout.** `struct epoll_event` is packed to 12 bytes on x86-64; the buffer is 3 `UInt32` per slot.
