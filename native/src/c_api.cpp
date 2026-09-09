#include <wynxo/native_core.h>

#include "permission_policy.hpp"
#include "project_scanner.hpp"

#include <exception>
#include <stdexcept>
#include <string>
#include <string_view>

namespace {

std::string_view safe_view(const char* value) noexcept {
    return value == nullptr ? std::string_view{} : std::string_view(value);
}

thread_local std::string scan_result;
thread_local std::string last_error;

void set_error(const std::exception& error) {
    last_error = error.what();
    scan_result.clear();
}

}  // namespace

extern "C" {

const char* wynxo_native_version(void) {
    return "0.2.0";
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

const char* wynxo_scan_directory_json(const char* directory,
                                      size_t max_entries) {
    try {
        if (directory == nullptr || *directory == '\0') {
            throw std::invalid_argument("project directory is empty");
        }
        scan_result = wynxo::native::scan_directory_json(directory, max_entries);
        last_error.clear();
        return scan_result.c_str();
    } catch (const std::exception& error) {
        set_error(error);
        return nullptr;
    } catch (...) {
        last_error = "unknown native directory scanner failure";
        scan_result.clear();
        return nullptr;
    }
}

const char* wynxo_native_last_error(void) {
    return last_error.c_str();
}

}  // extern "C"
