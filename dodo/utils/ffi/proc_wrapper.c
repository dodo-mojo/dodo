/*
 * Process and signal helpers for dodo (libdodo_proc.so).
 *
 * Mojo 1.2 has no global variables, so a signal handler written in Mojo
 * has nowhere to record a signal. The stdlib's Process also cannot pass
 * extra environment variables, redirect output or start a process group.
 * These few functions fill both gaps. dodo/utils/process.mojo and
 * dodo/utils/signals.mojo wrap them.
 *
 * Lists of strings (argv, extra environment) arrive as one buffer of
 * NUL-terminated strings placed back to back, plus a count.
 */

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <spawn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include "pin_self.h"

#ifdef __APPLE__
#include <crt_externs.h>
#define DODO_ENVIRON (*_NSGetEnviron())
#else
extern char **environ;
#define DODO_ENVIRON environ
#endif

#define DODO_PROC_NEW_GROUP 1

/* Point `out[i]` at each of the `count` strings packed in `buf`. */
static void unpack_strings(const char *buf, int count, char **out) {
    const char *cursor = buf;
    for (int i = 0; i < count; i++) {
        out[i] = (char *)cursor;
        cursor += strlen(cursor) + 1;
    }
    out[count] = NULL;
}

/* Length of the key in "KEY=VALUE", or the whole length without "=". */
static size_t key_length(const char *entry) {
    const char *equals = strchr(entry, '=');
    if (equals == NULL) {
        return strlen(entry);
    }
    return (size_t)(equals - entry);
}

static int is_overridden(const char *entry, char **extra, int extra_count) {
    size_t length = key_length(entry);
    for (int i = 0; i < extra_count; i++) {
        if (key_length(extra[i]) == length &&
            strncmp(entry, extra[i], length) == 0) {
            return 1;
        }
    }
    return 0;
}

/* The inherited environment with `extra` entries added or replacing
 * entries of the same name. The caller frees the array, not the strings. */
static char **merged_environment(char **extra, int extra_count) {
    int inherited = 0;
    while (DODO_ENVIRON[inherited] != NULL) {
        inherited++;
    }
    char **merged = calloc((size_t)(inherited + extra_count + 1), sizeof(char *));
    if (merged == NULL) {
        return NULL;
    }
    int next = 0;
    for (int i = 0; i < inherited; i++) {
        if (!is_overridden(DODO_ENVIRON[i], extra, extra_count)) {
            merged[next] = DODO_ENVIRON[i];
            next++;
        }
    }
    for (int i = 0; i < extra_count; i++) {
        merged[next] = extra[i];
        next++;
    }
    merged[next] = NULL;
    return merged;
}

/* The child starts with default handling and nothing blocked for the
 * signals a parent commonly catches or ignores. */
static int reset_child_signals(posix_spawnattr_t *attr) {
    sigset_t defaults;
    sigemptyset(&defaults);
    sigaddset(&defaults, SIGINT);
    sigaddset(&defaults, SIGTERM);
    sigaddset(&defaults, SIGHUP);
    sigaddset(&defaults, SIGQUIT);
    sigaddset(&defaults, SIGPIPE);
    int status = posix_spawnattr_setsigdefault(attr, &defaults);
    if (status != 0) {
        return status;
    }
    sigset_t nothing_blocked;
    sigemptyset(&nothing_blocked);
    return posix_spawnattr_setsigmask(attr, &nothing_blocked);
}

static int add_output(posix_spawn_file_actions_t *actions, int fd,
                      const char *path) {
    if (path[0] == '\0') {
        return 0;
    }
    if (fd == STDERR_FILENO && strcmp(path, "&1") == 0) {
        return posix_spawn_file_actions_adddup2(actions, STDOUT_FILENO,
                                                STDERR_FILENO);
    }
    return posix_spawn_file_actions_addopen(
        actions, fd, path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
}

/*
 * Start a program, searching PATH for argv[0].
 *
 * stdout_path and stderr_path are "" to inherit, or a file to write;
 * stderr_path "&1" joins stdout. flags may hold DODO_PROC_NEW_GROUP to
 * put the child in a process group of its own. Returns 0 and the pid,
 * or an errno value.
 */
int dodo_proc_spawn(const char *argv_buf, int argc, const char *env_buf,
                    int envc, const char *stdout_path,
                    const char *stderr_path, int flags, int64_t *pid_out) {
    if (argc < 1) {
        return EINVAL;
    }
    char **argv = calloc((size_t)(argc + 1), sizeof(char *));
    char **extra = calloc((size_t)(envc + 1), sizeof(char *));
    if (argv == NULL || extra == NULL) {
        free(argv);
        free(extra);
        return ENOMEM;
    }
    unpack_strings(argv_buf, argc, argv);
    unpack_strings(env_buf, envc, extra);
    char **envp = merged_environment(extra, envc);
    if (envp == NULL) {
        free(argv);
        free(extra);
        return ENOMEM;
    }

    posix_spawnattr_t attr;
    posix_spawn_file_actions_t actions;
    posix_spawnattr_init(&attr);
    posix_spawn_file_actions_init(&actions);

    short spawn_flags = POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK;
    if (flags & DODO_PROC_NEW_GROUP) {
        spawn_flags |= POSIX_SPAWN_SETPGROUP;
        posix_spawnattr_setpgroup(&attr, 0);
    }
    int status = posix_spawnattr_setflags(&attr, spawn_flags);
    if (status == 0) {
        status = reset_child_signals(&attr);
    }
    if (status == 0) {
        status = add_output(&actions, STDOUT_FILENO, stdout_path);
    }
    if (status == 0) {
        status = add_output(&actions, STDERR_FILENO, stderr_path);
    }
    if (status == 0) {
        pid_t pid = 0;
        status = posix_spawnp(&pid, argv[0], &actions, &attr, argv, envp);
        if (status == 0) {
            *pid_out = (int64_t)pid;
        }
    }

    posix_spawn_file_actions_destroy(&actions);
    posix_spawnattr_destroy(&attr);
    free(envp);
    free(extra);
    free(argv);
    return status;
}

/*
 * Replace this process with a program, searching PATH, with `extra`
 * environment entries added. Returns an errno value only on failure.
 */
int dodo_proc_exec(const char *argv_buf, int argc, const char *env_buf,
                   int envc) {
    if (argc < 1) {
        return EINVAL;
    }
    char **argv = calloc((size_t)(argc + 1), sizeof(char *));
    char **extra = calloc((size_t)(envc + 1), sizeof(char *));
    if (argv == NULL || extra == NULL) {
        free(argv);
        free(extra);
        return ENOMEM;
    }
    unpack_strings(argv_buf, argc, argv);
    unpack_strings(env_buf, envc, extra);
    for (int i = 0; i < envc; i++) {
        if (putenv(extra[i]) != 0) {
            int failure = errno;
            free(argv);
            free(extra);
            return failure;
        }
    }
    execvp(argv[0], argv);
    int failure = errno;
    free(argv);
    free(extra);
    return failure;
}

/*
 * Collect a child that ended. Returns 1 with the exit code (or the
 * signal that killed it), 0 when `nohang` is set and it still runs, or
 * -1 with errno in *exit_code.
 */
int dodo_proc_wait(int64_t pid, int nohang, int *exit_code, int *term_signal) {
    int options = 0;
    if (nohang) {
        options = WNOHANG;
    }
    int status = 0;
    pid_t got;
    do {
        got = waitpid((pid_t)pid, &status, options);
    } while (got < 0 && errno == EINTR);
    if (got < 0) {
        *exit_code = errno;
        *term_signal = 0;
        return -1;
    }
    if (got == 0) {
        return 0;
    }
    if (WIFSIGNALED(status)) {
        *exit_code = -1;
        *term_signal = WTERMSIG(status);
        return 1;
    }
    *exit_code = WEXITSTATUS(status);
    *term_signal = 0;
    return 1;
}

/* Send `sig` to a process, or to its whole group. Returns 0 or errno. */
int dodo_proc_kill(int64_t pid, int sig, int whole_group) {
    pid_t target = (pid_t)pid;
    if (whole_group) {
        target = -target;
    }
    if (kill(target, sig) != 0) {
        return errno;
    }
    return 0;
}

/* Let a child started later inherit `fd` (or stop it). Returns 0 or errno. */
int dodo_proc_set_inherit(int fd, int inherit) {
    int current = fcntl(fd, F_GETFD);
    if (current < 0) {
        return errno;
    }
    int updated = current | FD_CLOEXEC;
    if (inherit) {
        updated = current & ~FD_CLOEXEC;
    }
    if (fcntl(fd, F_SETFD, updated) != 0) {
        return errno;
    }
    return 0;
}

/* Copy the text for an errno value into `buf`, always NUL-terminated. */
void dodo_proc_error_text(int code, char *buf, int size) {
    if (size < 1) {
        return;
    }
    const char *text = strerror(code);
    strncpy(buf, text, (size_t)(size - 1));
    buf[size - 1] = '\0';
}

/* ── Signals ─────────────────────────────────────────────────────────── */

static volatile sig_atomic_t last_signal = 0;

static void record_signal(int sig) { last_signal = sig; }

static int set_handler(int sig, void (*handler)(int)) {
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = handler;
    sigemptyset(&action.sa_mask);
    /* Interrupted system calls restart, so code that never checks for
     * signals keeps working. Callers poll dodo_signals_take instead. */
    action.sa_flags = SA_RESTART;
    if (sigaction(sig, &action, NULL) != 0) {
        return errno;
    }
    return 0;
}

/* Catch SIGINT, SIGTERM and SIGHUP from now on. Returns 0 or errno. */
int dodo_signals_watch(void) {
    last_signal = 0;
    int status = set_handler(SIGINT, record_signal);
    if (status == 0) {
        status = set_handler(SIGTERM, record_signal);
    }
    if (status == 0) {
        status = set_handler(SIGHUP, record_signal);
    }
    return status;
}

/* The last signal caught since the previous call, or 0. */
int dodo_signals_take(void) {
    int sig = last_signal;
    last_signal = 0;
    return sig;
}

/* Back to the default handling for the three signals. Returns 0 or errno. */
int dodo_signals_stop(void) {
    int status = set_handler(SIGINT, SIG_DFL);
    if (status == 0) {
        status = set_handler(SIGTERM, SIG_DFL);
    }
    if (status == 0) {
        status = set_handler(SIGHUP, SIG_DFL);
    }
    return status;
}
