/*
 * Keep a dodo wrapper library loaded for the rest of the process.
 *
 * dodo reaches its wrapper libraries through dlopen handles, and Mojo can
 * dlclose a handle while a function pointer from it is still in use. On
 * Linux the libraries are linked with -z nodelete, so dlclose never unmaps
 * them. macOS has no such link flag, so each library includes this header
 * and marks itself RTLD_NODELETE when it loads. Without it, the first call
 * through a stale pointer jumps into unmapped memory.
 */

#ifndef DODO_PIN_SELF_H
#define DODO_PIN_SELF_H

#ifdef __APPLE__
#include <dlfcn.h>
#include <stddef.h>

__attribute__((constructor)) static void dodo_pin_self(void) {
    Dl_info info;
    if (dladdr((const void *)&dodo_pin_self, &info) == 0) {
        return;
    }
    if (info.dli_fname == NULL) {
        return;
    }
    /* The handle is never closed on purpose: it is the pin. */
    dlopen(info.dli_fname, RTLD_LAZY | RTLD_NODELETE);
}
#endif

#endif
