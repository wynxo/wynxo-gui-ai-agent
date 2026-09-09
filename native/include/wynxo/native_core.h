#pragma once

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
 * Returned strings are immutable process-lifetime literals owned by the
 * library. Callers must never free them. Integer booleans are 0/1 so the API
 * is straightforward to consume from Python ctypes, Rust FFI, or a future Qt
 * C++ application shell without binding-library lock-in.
 */

WYNXO_NATIVE_API const char* wynxo_native_version(void);
WYNXO_NATIVE_API const char* wynxo_normalize_permission_mode(const char* mode);
WYNXO_NATIVE_API int wynxo_command_is_destructive(const char* command);
WYNXO_NATIVE_API int wynxo_permission_needs_confirmation(
    const char* action,
    const char* mode,
    const char* command
);

#ifdef __cplusplus
}
#endif
