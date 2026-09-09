#pragma once

#include <stddef.h>

#if defined(_WIN32)
#  if defined(WYNXO_NATIVE_BUILD)
#    define WYNXO_NATIVE_API __declspec(dllexport)
#  else
#    define WYNXO_NATIVE_API __declspec(dllimport)
#  endif
#else
#  define WYNXO_NATIVE_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Stable C ABI for the native core.
 *
 * Literal string results (version and normalized permission mode) are owned by
 * the library for the lifetime of the process. Scanner/error strings are owned
 * by the library and remain valid until the next scanner call on the same
 * thread. Callers must never free any returned pointer. Integer booleans are
 * 0/1 so the ABI stays straightforward for Python ctypes, Rust FFI, or a future
 * Qt C++ application shell.
 */

WYNXO_NATIVE_API const char* wynxo_native_version(void);
WYNXO_NATIVE_API const char* wynxo_normalize_permission_mode(const char* mode);
WYNXO_NATIVE_API int wynxo_command_is_destructive(const char* command);
WYNXO_NATIVE_API int wynxo_permission_needs_confirmation(
    const char* action,
    const char* mode,
    const char* command
);

/*
 * Scan exactly one already-authorized directory without following symlinks.
 * The JSON object is {"entries":[...],"truncated":bool}. Each entry contains
 * name, absolute path, isDir, size, and link. Product filtering and sorting are
 * intentionally left to the caller.
 *
 * Returns NULL on failure; wynxo_native_last_error() then contains a readable
 * diagnostic. max_entries is defensively capped inside the native core.
 */
WYNXO_NATIVE_API const char* wynxo_scan_directory_json(
    const char* directory,
    size_t max_entries
);
WYNXO_NATIVE_API const char* wynxo_native_last_error(void);

#ifdef __cplusplus
}
#endif
