# Native consumer contract

Luaz owns one coherent Luau native build. Consumers import the existing `luaz`
Zig module or translated `c` module and may link the package artifacts
`luaz`, `luau_vm`, and `luau_compiler`. The `luau_codegen` artifact is present
only when `-Dcodegen=true` (the compatibility default); Reified selects
`-Dcodegen=false`.

Native C++ consumers include `luaz_config.h` before Luau headers and compile as
C++17 with libc++. The installed headers include the public VM, compiler, and
common surfaces. Upstream VM internals are installed under `luau/internal` only
for pin-coupled consumers; `lstate.h` is not a stable Luaz API.

The package fixes `LUA_USE_LONGJMP=1` and applies the selected vector size to the
VM, translated C declarations, Luaz support code, and native consumers. A
consumer must not compile or link a second Luau VM or compiler.

`zig build profile` installs deterministic facts at
`zig-out/share/luaz/build-facts.json` and their SHA-256 fingerprint at
`zig-out/share/luaz/build-fingerprint.txt`. These identify the package build,
not a consumer's bridge source, execution policy, limits, or worker protocol.

The package does not make arbitrary Luau calls safe across Zig cleanup or C++
RAII frames when Luau uses `longjmp`. A consumer-owned protected native landing
point remains responsible for that lifetime boundary.
