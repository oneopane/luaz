# Native consumer contract

The 2026-09-12 candidate package builds Luau 0.738 (commit
`c54f558b4d5748ab0658610b8ce0c432053e41eb`) as one native graph. Consumers may
import both documented Zig modules:

```zig
const c = @import("c");
const luaz = @import("luaz");
```

The package publishes the `luaz` and `luaz_support` artifacts alongside the
`luau_vm` and `luau_compiler` dependencies. `luaz_support` is the sole owner
of the Luaz native support source (`src/handler.cpp`) and installs
`include/handler.h`; it is reached transitively by both public modules and by
the `luaz` artifact. A consumer must link one package graph and must not
compile `handler.cpp`, a second Luau VM, or a second Luau compiler. The
`luau_codegen` artifact is present only when `-Dcodegen=true` (the compatibility
default); Reified selects `-Dcodegen=false`.

The package-boundary smoke test imports and uses both modules, calls
`luaz.setAssertHandler` and `c.luau_set_assert_handler`, and links a C++ call to
the installed-header primitive. This verifies that the support implementation
is available through the public package closure rather than through a second
consumer-local copy.

Native C++ consumers include `luaz_config.h` before Luau headers and compile as
C++17 with libc++. The installed headers include the public VM, compiler, and
common surfaces. Upstream VM internals are installed under `luau/internal` only
for pin-coupled consumers; `lstate.h` is not a stable Luaz API.

The package fixes `LUA_USE_LONGJMP=1` and applies the selected vector size to the
VM, translated C declarations, Luaz support code, and native consumers. The
effective C++ flags and C macro definitions are included in the build facts. A
consumer must not compile or link a second Luau VM or compiler.

`zig build profile` installs deterministic facts at
`zig-out/share/luaz/build-facts.json` and their SHA-256 fingerprint at
`zig-out/share/luaz/build-fingerprint.txt`. The version-2 facts include the
Luau revision/content hash, Luaz source and support-source hashes, target
architecture/CPU model/feature set, compiler defaults, native flags/macros,
module/artifact names, vector/longjmp/codegen settings, and source roots.
They identify the package build, not a consumer's bridge source, execution
policy, limits, or worker protocol.

The candidate was checked with `/opt/homebrew/bin/zig` 0.16.0 on
`aarch64-macos` for Debug and ReleaseSafe builds, with codegen disabled and
enabled. The focused commands were:

```sh
zig fmt --check build.zig build.zig.zon src tests/native_consumer
zig build
zig build test
zig build test-native-consumer
zig build test-native-consumer -Dcodegen=false
zig build profile -Doptimize=ReleaseSafe -Dcodegen=false -Dvector-size=4
```

This delivery is bound to Luaz implementation revision
`ca3f50b48a7d5631fbbd7c3193f0ba6158ca6bdd`. The selected profile is exactly
`/opt/homebrew/bin/zig build profile -Doptimize=ReleaseSafe -Dcodegen=false -Dvector-size=4`;
its effective options are `optimize=ReleaseSafe`, `codegen=false`, and
`vector_size=4`.

The fingerprint below is the profile fingerprint at that implementation
revision. The later documentation and callback-test follow-up changes
`src/**/*.zig`, which is intentionally included in the package source digest;
rebuilding after those changes therefore produces a new fingerprint and does
not replace this candidate receipt.

The profile output is deterministic for repeated identical inputs and changes
when the vector-size or target CPU feature set changes. Compiler allocation
metering, Reified worker policy, and Reified adoption remain outside this fork
candidate and are not claimed by these checks.

For the host `aarch64-macos` / ReleaseSafe / vector-size-4 / codegen-disabled
configuration, the checked fingerprint is
`79ececf7a9dece184f130c0087178ab852cd6de72d19745543a38347986570a7`.

At that revision, delivery checks passed: formatting, Debug and ReleaseSafe
product builds, ordinary tests, native-consumer tests with codegen enabled and
disabled, and the selected profile. Repeating the selected profile produced
the same fingerprint; changing vector size or target CPU features produced a
different fingerprint. The follow-up callback trampoline coverage also passes
in the ordinary test artifact.

The package does not make arbitrary Luau calls safe across Zig cleanup or C++
RAII frames when Luau uses `longjmp`. A consumer-owned protected native landing
point remains responsible for that lifetime boundary.
