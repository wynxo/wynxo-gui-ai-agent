#include <wynxo/native_core.h>

#include "permission_policy.hpp"

#include <string_view>

namespace {

std::string_view safe_view(const char* value) noexcept {
    return value == nullptr ? std::string_view{} : std::string_view(value);
}

}  // namespace

extern "C" {

const char* wynxo_native_version(void) {
    return "0.1.0";
}

const char* wynxo_normalize_permission_mode(const char* mode) {
    const auto normalized = wynxo::native::normalize_permission_mode(safe_view(mode));
    switch (normalized) {
        case wynxo::native::PermissionMode::Manual: return "manual";
        case wynxo::native::PermissionMode::Safe: return "safe";
        case wynxo::native::PermissionMode::Auto: return "auto";
        case wynxo::native::PermissionMode::Full: return "full";
    }
    return "safe";
}

int wynxo_command_is_destructive(const char* command) {
    try {
        return wynxo::native::command_is_destructive(safe_view(command)) ? 1 : 0;
    } catch (...) {
        // A policy failure must fail closed. If parsing ever throws, require
        // confirmation rather than letting an unknown command run unattended.
        return 1;
    }
}

int wynxo_permission_needs_confirmation(const char* action, const char* mode,
                                        const char* command) {
    try {
        const auto normalized = wynxo::native::normalize_permission_mode(safe_view(mode));
        return wynxo::native::needs_confirmation(safe_view(action), normalized,
                                                  safe_view(command)) ? 1 : 0;
    } catch (...) {
        return 1;
    }
}

}  // extern "C"
