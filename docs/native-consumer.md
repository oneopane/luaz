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
`std::bad_alloc` and returned-copy `malloc` failure return
`LUAZ_COMPILE_ALLOCATION_FAILED`; other escaping exceptions and an unexpected
empty compiler result return `LUAZ_COMPILE_INTERNAL_ERROR`. Normal bytecode and
encoded syntax errors return `LUAZ_COMPILE_OK` and `LUAZ_COMPILE_ERROR`. Both own a
`malloc` blob that the consumer frees exactly once with `free`.

The inclusive output-copy ceiling applies to bytecode and encoded diagnostics
before the returned blob is allocated or copied. Exceeding it returns
`LUAZ_COMPILE_OUTPUT_LIMIT_EXCEEDED`. Limit, allocation, and internal failure
always return a null pointer and zero size. This ceiling does not bound the
compiler's temporary C++ allocations. Compiler memory metering remains owned
by the consumer; Luaz installs no production global allocator.

`Compiler.compileBounded(source, options, output_limit)` exposes
`ok`, `err`, `output_limit_exceeded`, `allocation_failed`, and `internal_error`
without parsing diagnostics. Its result's `deinit` frees owned blobs and does
nothing for the three empty dispositions. `Compiler.compile` uses this boundary
with a max-`usize` output-copy ceiling, mapping allocation failure to `OutOfMemory` and internal
failure to `CompilerInternalError`. Raw upstream `c.luau_compile` remains
available for compatibility, but does not provide this exception contract.
The unreachable max-`usize` output-limit case conservatively maps to `OutOfMemory`.
Stable C values are OK=0, ERROR=1, OUTPUT_LIMIT_EXCEEDED=2, INTERNAL_ERROR=3,
and ALLOCATION_FAILED=4. The former ambiguous EXHAUSTED alias is removed.

The external consumer installs a test-only throwing allocator. Exactly 8192
spaces followed by a function under a 4096-byte compiler allocation budget
returns `allocation_failed` to Zig with `meter_refused=true` and no live compiler
allocation. A separate simulated test-only backing-allocation failure returns the same
package status with `meter_refused=false`; the native result is null/zero, and
later calls recover. A budget sweep checks refusal after successful allocations
and complete C++ unwinding. The latch resets at invocation entry, is set only on
budget rejection, and is captured before another invocation; nesting is rejected.
The package status alone never proves caller-budget exhaustion. Inclusive output
bounds, one-short bytecode, oversized diagnostics, syntax errors, and convenience
`OutOfMemory` mapping are exercised through the actual external dependency.

Reified retains disposition composition: `output_limit_exceeded` identifies the
configured output bound, while `allocation_failed` requires the invocation's
captured meter-refusal evidence to distinguish a configured compiler-memory bound
from an unclassified allocation failure. `internal_error` remains an internal
failure. Luaz supplies no production classifier or invocation policy.

Returned-copy `malloc` failure, non-`bad_alloc` exceptions, and unexpected empty
compiler output are structurally reviewed, not induced by these runtime tests.
No isolated malloc interposer proves the exact returned-copy branch. This receipt
does not claim those branches were fault-injected, nor compiler-route completeness.

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
`e0274e1edd64d7245cfb0d87b7a294d98918cf62`. The selected profile is exactly
`/opt/homebrew/bin/zig build profile -Doptimize=ReleaseSafe -Dcodegen=false -Dvector-size=4`;
its effective options are `optimize=ReleaseSafe`, `codegen=false`, and
`vector_size=4`, with `LUA_USE_LONGJMP=1`, C++17, and libc++.

The immutable Luaz implementation archive is
`https://github.com/oneopane/luaz/archive/e0274e1edd64d7245cfb0d87b7a294d98918cf62.tar.gz`.
Its Zig package content hash is
`luaz-0.6.0-w-BJfD6PCAAMXd_Qzhh2auiKU8Fh4yXcf9yRUYbLgW0o`, independently
reproduced with the pinned toolchain:

```sh
/opt/homebrew/bin/zig fetch https://github.com/oneopane/luaz/archive/e0274e1edd64d7245cfb0d87b7a294d98918cf62.tar.gz
```

This archive hash identifies Luaz, not its unchanged Luau dependency hash
`N-V-__8AADetGAEcdQuTr-nq27CyCea3jnhtkeu-EYaA03Lb`, and not the selected build
profile fingerprint `8ed5b5cf419951d97e738404d6d01e0ed8ecf90e5212113c42c07ed5439ec477`.
Together the Luaz archive and selected profile identify the explicit changed
Luaz package/profile compatibility boundary. This receipt supersedes delivery
receipts `c5086fd4651998f4b31d2ef31f7dff1ab34a7d15`,
`90237af7448e85aaaa137d9ff99405302ca1b243`, and
`b34a9b1b496f885ced3628e07bcba088842b3f2a`; implementation revision
`cb7a31e28d0a7d33c3c4a37a92c31103d44cb95d`; and profile fingerprint
`522adcf844fbcfa96f7a02226093824b080273ab91295fc7bbe3966681712d9f`.
The current implementation remains `e0274e1edd64d7245cfb0d87b7a294d98918cf62`.
The receipt adds delivery evidence and does not change implementation behavior
or claim Reified adoption.

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
`8ed5b5cf419951d97e738404d6d01e0ed8ecf90e5212113c42c07ed5439ec477`.

At that revision, focused callback trampoline coverage passed in the ordinary
test artifact, including instance dispatch, state/block/string forwarding,
return propagation, and clearing callbacks on replacement. Debug and
ReleaseSafe product, ordinary-test, and native-consumer checks passed with
codegen disabled and enabled. Repeating the selected profile produced the same
fingerprint; changing vector size produced a different fingerprint.
Independent review reported no implementation P1/P2 findings against the frozen
implementation, reran external Debug and ReleaseSafe/codegen-disabled/vector-4
checks, and reproduced the selected fingerprint.

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
The artifact-owned emitted-header repair remains present. Against base receipt
`90237af7448e85aaaa137d9ff99405302ca1b243`, the external Debug/codegen-disabled
oracle expected stable allocation status 4 and failed at runtime with
`NativeConsumerFailed`; after the status split, it passed. An earlier attempt
stopped at `NoSpaceLeft` and is not counted as behavioral evidence. The selected
fingerprint repeated identically; vector size 3 produced
`29d390d99d8698ba542721e2bbfe765ea35fedad3fa697c3e226f9acdc49e110`, and
`-Dcpu=generic` produced
`bd74bc2b0ee4a26e4c85cd96b49b7bab9386812a7bec01b62a20ed1093ef27b9`.
The selected profile output was restored after variant checks. These facts hash
the production source/build inputs, including the new native compiler wrapper;
the external fixture itself is bound by the immutable implementation revision.

The package does not make arbitrary Luau calls safe across Zig cleanup or C++
RAII frames when Luau uses `longjmp`. A consumer-owned protected native landing
point remains responsible for that lifetime boundary.
