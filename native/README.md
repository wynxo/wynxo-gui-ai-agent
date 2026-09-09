# Wynxo native core

Wynxo is moving toward a C++-first desktop core without throwing away the parts
of the current Python/QML application that already work well.

## Language boundaries

- **C++20** — native core and performance/safety-sensitive desktop services.
  Permission policy is the first migrated subsystem. File indexing, diff work,
  PTY/process control, system telemetry, and other hot paths are candidates to
  follow when their interfaces are stable.
- **QML** — the desktop UI, layout, state presentation, accessibility, and
  interaction animation. Permanent application surfaces stay solid; glass is
  interaction feedback, not the visual foundation of the whole app.
- **JavaScript in QML** — small presentation helpers only. Business rules do
  not live in anonymous QML JavaScript functions when C++ or Python can own a
  testable implementation.
- **Python** — Ollama orchestration, higher-level agent flow, and migration
  glue while native services replace mature boundaries one at a time.
- **Rust** — deliberately not a baseline dependency. Add it only for an
  isolated subsystem where Rust gives a concrete reliability/security win
  large enough to justify a second native toolchain and FFI boundary.

## Why a C ABI

`include/wynxo/native_core.h` is intentionally a tiny C ABI over the C++ core.
That keeps the boundary stable and lets the current Python application use it
through `ctypes` without pybind11. It also leaves the door open to a future Qt
C++ application shell, Rust components, or standalone tests without binding the
core to one language runtime.

No function in the public ABI transfers heap ownership. String returns are
process-lifetime literals owned by the library, and booleans are integer 0/1.

## Build and test

```bash
cmake -S native -B build/native -DCMAKE_BUILD_TYPE=Release
cmake --build build/native --parallel
ctest --test-dir build/native --output-on-failure
```

To test the Python bridge from a source checkout:

```bash
WYNXO_NATIVE_CORE="$PWD/build/native/libwynxo_native_core.so" python3 - <<'PY'
from wynxo.native_core import native_core
assert native_core.available, native_core.error
print(native_core.version)
print(native_core.normalize_permission_mode("safe_auto"))
PY
```

The same configure/build/test/FFI sequence runs in GitHub Actions.

## Migration rule

Do not rewrite a working subsystem only to increase the C++ line count. Move a
boundary when at least one of these is true:

1. it is security-critical and benefits from one canonical implementation;
2. it is CPU/IO hot enough that Python overhead is measurable;
3. it needs native OS primitives or deterministic lifetime management;
4. keeping duplicate Python/QML implementations is causing correctness bugs.

Each migrated subsystem must have tests at the native boundary before the
Python implementation is removed.
