# Native consumer contract

The 2026-09-12 candidate package builds the coordinator-accepted Luau 0.737
baseline as one native graph. The supplied evidence maps that tag to commit
`62dbc0b4718e87fc746b02f969c91ca2a461b4cf`; Luaz records that mapping as
accepted provenance and does not independently resolve it. Consumers may
import both documented Zig modules:

```zig
const c = @import("c");
const luaz = @import("luaz");
```

The package publishes the `luaz` and `luaz_support` artifacts alongside the
`luau_vm` and `luau_compiler` dependencies. `luaz_support` is the sole owner
of the Luaz native support sources (`src/handler.cpp` and `src/compiler.cpp`)
and installs `include/handler.h` and `include/luaz_compiler.h`; it is reached
transitively by both public modules and by
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

The generated configuration header belongs to the public `luaz` artifact.
External Zig builds obtain it with
`dependency.artifact("luaz").getEmittedIncludeTree()`. This tree also supplies
compiler/common headers; public VM and support headers are obtained from the
`luau_vm` and `luaz_support` artifact include trees. Link the `luaz` artifact
once to obtain the native dependency closure. No install step, cache path,
private generator directory, or consumer-generated configuration is required.
`zig build` installs the same generated header as `include/luaz_config.h`;
`zig build profile` installs only the facts and fingerprint.

`tests/external_consumer` is a separate Zig package with a path dependency on
Luaz. From that directory, run `zig build test -Doptimize=ReleaseSafe
-Dcodegen=false -Dvector-size=4`. It obtains only public modules/artifacts,
compiles C++ through their emitted include trees, links, and executes the
native compile/load/call boundary. Its source explicitly includes the generated
configuration header and asserts vector-size and longjmp agreement.

### Native compiler exception boundary

The `luaz_support` artifact owns `luaz_compile_bounded`, declared in its public
`luaz_compiler.h` header and exposed by the `c` module. The C++ function is
`noexcept` and calls `Luau::compile` inside its exception landing point.
`std::bad_alloc` returns `LUAZ_COMPILE_EXHAUSTED`; other escaping exceptions
return `LUAZ_COMPILE_INTERNAL_ERROR`. Normal bytecode and encoded syntax errors
return `LUAZ_COMPILE_OK` and `LUAZ_COMPILE_ERROR`, respectively. Both own a
`malloc` blob that the consumer frees exactly once with `free`.

The inclusive output-copy ceiling applies to bytecode and encoded diagnostics
before the returned blob is allocated or copied. Exhaustion/internal failure
always return a null pointer and zero size. This ceiling does not bound the
compiler's temporary C++ allocations. Compiler memory metering remains owned
by the consumer; Luaz installs no production global allocator.

`Compiler.compileBounded(source, options, output_limit)` exposes
`ok`, `err`, `exhausted`, and `internal_error` without parsing diagnostics.
Its result's `deinit` frees owned blobs and does nothing for the two empty
dispositions. Existing `Compiler.compile` now uses this boundary with an
unlimited output-copy ceiling, mapping exhaustion to `OutOfMemory` and internal
failure to `CompilerInternalError`. Raw upstream `c.luau_compile` remains
available for compatibility, but does not provide this exception contract.

The external consumer installs a test-only throwing allocator. Exactly 8192
spaces followed by a function under a 4096-byte compiler allocation budget
returns explicit exhaustion to Zig and leaves no live compiler allocation.
A budget sweep also checks exhaustion after successful allocations, complete
C++ unwinding, and subsequent success. Ordinary tests check inclusive output
bounds and distinguish syntax errors from exhaustion.

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
zig build -Doptimize=Debug -Dcodegen=false
zig build test -Doptimize=Debug -Dcodegen=false
zig build test-native-consumer -Doptimize=Debug -Dcodegen=false
zig build -Doptimize=ReleaseSafe -Dcodegen=false
zig build test -Doptimize=ReleaseSafe -Dcodegen=false
zig build test-native-consumer -Doptimize=ReleaseSafe -Dcodegen=false
zig build profile -Doptimize=ReleaseSafe -Dcodegen=false -Dvector-size=4
```

This delivery is bound to Luaz implementation revision
`21107bf1d6a0312fba75e696c799bcc03893cb87`. The selected profile is exactly
`/opt/homebrew/bin/zig build profile -Doptimize=ReleaseSafe -Dcodegen=false -Dvector-size=4`;
its effective options are `optimize=ReleaseSafe`, `codegen=false`, and
`vector_size=4`, with `LUA_USE_LONGJMP=1`, C++17, and libc++.

G0 provenance is recorded in `tests/native_consumer/baseline.json`: this is the
Reified packaged luaz 0.6.0 baseline, and the 0.737 commit mapping is supplied
and accepted evidence rather than an independent Luaz resolution. The
fingerprint below is the profile fingerprint at the final implementation
revision; the package source digest includes the callback coverage and the
accepted dependency/build identity.

The profile output is deterministic for repeated identical inputs and changes
when the vector-size or target CPU feature set changes. Compiler allocation
metering, Reified worker policy, and Reified adoption remain outside this fork
candidate and are not claimed by these checks.

For the host `aarch64-macos` / ReleaseSafe / vector-size-4 / codegen-disabled
configuration, the checked fingerprint is
`8e08ee8a06e21bdb63415906a47973d2dfb153e7668dc514349c8f1c656eff7d`.

At that revision, focused callback trampoline coverage passed in the ordinary
test artifact, including instance dispatch, state/block/string forwarding,
return propagation, and clearing callbacks on replacement. Debug and
ReleaseSafe product, ordinary-test, and native-consumer checks passed with
codegen disabled and enabled. Repeating the selected profile produced the same
fingerprint; changing vector size produced a different fingerprint.

The replacement implementation was checked with `/opt/homebrew/bin/zig`
0.16.0 using the following exact command families (each brace alternative was
run independently):

```sh
/opt/homebrew/bin/zig fmt --check build.zig build.zig.zon src tests
/opt/homebrew/bin/zig build -Doptimize={Debug,ReleaseSafe} -Dcodegen={false,true} -Dvector-size=4 --summary failures
/opt/homebrew/bin/zig build test test-native-consumer -Doptimize={Debug,ReleaseSafe} -Dcodegen={false,true} -Dvector-size=4 --summary failures
# From tests/external_consumer:
/opt/homebrew/bin/zig build test -Doptimize={Debug,ReleaseSafe} -Dcodegen={false,true} -Dvector-size=4 --summary failures
/opt/homebrew/bin/zig build test -Doptimize=ReleaseSafe -Dcodegen=false -Dvector-size=3 --summary failures
# From the package root:
/opt/homebrew/bin/zig build profile -Doptimize=ReleaseSafe -Dcodegen=false -Dvector-size=4
/opt/homebrew/bin/zig build profile -Doptimize=ReleaseSafe -Dcodegen=false -Dvector-size=3
/opt/homebrew/bin/zig build profile -Doptimize=ReleaseSafe -Dcodegen=false -Dvector-size=4 -Dcpu=generic
```

All product, ordinary (93), native (3), and external consumer checks passed.
The external config-header oracle first failed against receipt
`c5086fd4651998f4b31d2ef31f7dff1ab34a7d15` with `luaz_config.h file not found`,
then passed after the artifact-owned header repair. The compiler exhaustion
oracle and inclusive-output-bound tests pass on the replacement. The selected
fingerprint repeated identically; vector size 3 produced
`1544b0e5d43b938915f063f8b70da935f185e7b68497d8322688ccd83e90ac92`, and
`-Dcpu=generic` produced
`71807351d0f151467d6ef1f790985e017d5a39817c75cb07c027916d9c6cf27b`.
The selected profile output was restored after variant checks. These facts hash
the production source/build inputs, including the new native compiler wrapper;
the external fixture itself is bound by the immutable implementation revision.

The package does not make arbitrary Luau calls safe across Zig cleanup or C++
RAII frames when Luau uses `longjmp`. A consumer-owned protected native landing
point remains responsible for that lifetime boundary.
