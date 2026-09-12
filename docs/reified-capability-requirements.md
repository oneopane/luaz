# Reified capability requirements for the luaz fork

This note is the capability contract between Reified and the policy-neutral
Luau embedding layer. It records the luaz 0.6.0 surface and the current
Reified bridge as inspected on 2026-09-12. A file-and-line citation names the
repository and the displayed source lines; upstream behavior is linked to the
official Luau API or source.

“Covered” below means that a usable primitive exists. “Partial” means that the
primitive exists but its ownership, status, or determinism is not sufficient
for Reified. “Missing” means that the fork or its build graph needs a new
surface. A primitive is not a Reified policy decision: filesystem/process
containment, the accepted library allowlist, request limits, and worker
attestation remain outside generic Luau.

## Boundary and baseline

Luaz is a Zig wrapper around a Luau state, compiler, values, callbacks, and
the C API. Its public exports are Lua, State, Compiler, Debug, GC, raw C, and
the assert handler (luaz/src/lib.zig:6-18); the README presents it as a
library API, not as a worker or a process boundary (luaz/README.md:12-38).
The state may be constructed with a caller allocator and closed explicitly
(luaz/src/State.zig:94-109). That is the right level for generic embedding,
but it does not by itself provide a Reified invocation, module graph, hard
budgets, or OS isolation.

The current Reified native bridge already demonstrates one policy-bearing
realization: a fresh state, supplied-source modules, bounded input/output,
instruction and VM allocation accounting, and a native sandbox
(reified/src/luau/native/luau.cpp:1-3,251-329). The worker adds process,
timeout, environment, profile, and OS-sandbox rules
(reified/src/luau/worker.zig:1-6,65-224;
reified/src/luau/native/worker_memory.cpp:47-67). Those mechanisms are
evidence of required observable behavior, not reason to put worker policy
into luaz.

There is an immediate package-graph gap. Reified's build expects luaz,
luaz_c, luaz_options, and luaz_profile modules and installs the associated
roots (reified/build.zig:84-139), while luaz's build creates a single luaz
Zig module plus the VM, codegen, and compiler artifacts
(luaz/build.zig:239-279). The fork is pinned to Luau 0.702 at commit
c836feb... (luaz/build.zig.zon:1-12); the Reified profile records the nested
Luau hash and other ABI facts (reified/src/luau/profile.zig:13-37), while
the native bridge comments refer to a later Luau 0.737 allocator contract
(reified/src/luau/native/allocator.hpp:1-13). The profile and build exports
therefore need an explicit compatibility decision; a language-version string
is not enough.

## Requirements matrix

| Mechanism Reified needs | What luaz currently provides | Exact gap or boundary | Observable test oracle |
| --- | --- | --- | --- |
| Stable build ABI and fingerprint | Luau VM/codegen/compiler are built as static artifacts with C API macros, vector size, and longjmp enabled (luaz/build.zig:37-121,239-279). | No luaz_c, luaz_options, or luaz_profile module; no exported nested Luau source hash or compile-option attestation. Reified cannot satisfy its current imports from this graph alone (reified/build.zig:84-139). | A consumer can import every expected module; changing Luau ref, vector size, longjmp, C++ ABI, or codegen changes the profile and rejects a mismatched worker. |
| State owner, close, threads, and allocator lifetime | lua_newstate/luaL_newstate, lua_close, lua_newthread, reset, and allocator access are wrapped (luaz/src/State.zig:94-134,897-917). Lua's allocator userdata is supplied by the caller and the high-level Lua object documents that the allocator must outlive the VM (luaz/src/Lua.zig:79-104). | No non-copyable owner token or invocation-scoped lifetime type. Threads are Luau coroutines, not OS threads; refs, borrowed strings, and callbacks remain tied to the state. | The allocator userdata remains valid through close; all child threads are reclaimed by main close; double close is impossible at the owner boundary; a borrowed string is copied before close and never read afterward. |
| Protected execution and longjmp discipline | State exposes load, raw call, protected call, yield/resume, and status (luaz/src/State.zig:793-856). The C API's pcall and cpcall are the intended protected boundaries. | Raw call can invoke panic/abort on an unprotected error; the high-level Function.call collapses statuses and prints the error string (luaz/src/Lua.zig:1635-1684,2295-2377). Luaz does not express “all VM calls must be inside this protected frame” or C++ longjmp-safe lifetimes. | A runtime error, syntax error, and OOM return a structured outcome and an error object/diagnostic without process abort; the stack is restored; no C++ destructor or Zig defer is relied on across a Luau longjmp. |
| Source compilation, bytecode loading, and diagnostics | Compiler.compile returns an owned success blob or owned error bytes, freeing the Luau allocation on deinit (luaz/src/Compiler.zig:10-88). State.load calls luau_load with chunk name, bytecode, and environment (luaz/src/State.zig:793-818). | Compiler options are only opt/debug/type/coverage; compiler allocation is not injected or metered. Lua.eval discards the compiler error text and maps it to Error.Compile (luaz/src/Lua.zig:2380-2429). Invalid load statuses are not represented as a reusable diagnostic type. | Valid source produces bytecode that runs; invalid source preserves bounded, location-bearing diagnostic bytes; every success/error allocation is freed exactly once; compiler-budget exhaustion is distinguished from VM OOM and syntax failure. |
| Supplied module graph, resolver, cache, cycles, and environments | Luaz offers only the low-level load primitive with a caller-supplied environment; it has no graph or resolver API (luaz/src/State.zig:793-818). | Reified needs exact path/alias/scope validation, per-module cache and active-cycle state, and isolated environments. That policy-neutral loader is missing from luaz; Reified currently implements it in its native bridge (reified/src/luau/native/luau.cpp:97-197,353-436; frame construction reified/src/luau/modules.zig:1-56). | Relative imports resolve only within their declared scope; aliases never fall through to another scope; duplicate, malformed, absolute, NUL, or escaping paths are invalid_source; one cache entry executes once; a cycle has a deterministic error; each module's writes stay in its environment. |
| Raw value access and deterministic traversal | State exposes raw iteration and registry operations (luaz/src/State.zig:919-1006); stack conversion handles primitives, tables, functions, buffers, refs, tuples, and userdata (luaz/src/stack.zig:78-201,609-789). | High-level Table access is metamethod-aware (luaz/src/Lua.zig:680-725), and its iterator is a convenience wrapper over next rather than a documented policy-neutral raw visitor (luaz/src/Lua.zig:1110-1183). There is no bounded, cycle-aware, key-shape visitor/serializer contract. | A data traversal never invokes __index, __iter, or other user metamethods; cycles, sparse arrays, unsupported keys, non-finite numbers, and excessive depth are rejected deterministically; strings including NUL are preserved and key order is deterministic. |
| Registry references and value ownership | Ref pins a state value in the registry and unref releases it; Value deinit releases owned refs (luaz/src/Lua.zig:478-525,1225-1255; luaz/src/State.zig:973-1006). | Strings and some converted values are borrowed from the VM; light userdata is a non-GC pointer whose host lifetime is the caller's responsibility (luaz/src/State.zig:380-399; luaz/src/stack.zig:222-316). There is no result arena that survives lua_close. | A returned result is wholly owned outside the state; every temporary ref is released; no light pointer crosses an invocation; GC cannot invalidate a value before its documented owner releases it. |
| VM allocation accounting and allocator semantics | The Zig allocator adapter honors Luau realloc/free rules and returns null for failure (luaz/src/alloc.zig:10-45). State exposes allocator and memory-category callbacks (luaz/src/State.zig:897-917,1410-1487). | Luaz supplies no hard live/peak budget, overflow-safe accounting, or qualified exhaustion disposition. Reified's allocator implements aligned rounded charges, no-fail shrink, live/peak metrics, and reserve-before-copy (reified/src/luau/native/allocator.hpp:1-64; bridge use reified/src/luau/native/luau.cpp:61-73). | Allocation failure is reproducible at the configured boundary; shrink/equal-size realloc never fails; old-size mismatch is trapped; live and peak bytes are exact; no output is committed after exhaustion. |
| Instruction accounting and cancellation | Upstream exposes interrupt callbacks and single-step/debugstep hooks; luaz exports callbacks and Debug/Hook aliases (luaz/src/State.zig:1410-1487; luaz/src/Lua.zig:218-476). | A callback hook is not a hard budget or a standardized disposition. Luaz does not count each instruction or account compiler time. Reified currently installs debugstep and raises a VM error when the count reaches the limit (reified/src/luau/native/luau.cpp:88-95). | The same source reaches the exact configured instruction ceiling, returns exhausted, and cannot produce partial output; callback/GC safepoints cannot bypass the policy; long native functions remain separately identified. |
| Sandbox primitives | luaL_sandbox and luaL_sandboxthread are wrapped (luaz/src/State.zig:1365-1377; luaz/src/Lua.zig:2571-2602). Upstream makes libraries/metatables readonly and gives threads a proxy global environment (https://luau.org/api/#sandboxing). | These primitives do not define the library removal list, remove require/loadstring, deny process/filesystem APIs, or provide a process boundary. Reified performs those removals and then calls both sandbox functions (reified/src/luau/native/luau.cpp:251-315). | Mutating protected libraries/metatables fails; thread-local writes do not mutate the shared global table; every forbidden global is absent; a script cannot regain require, loadstring, random, OS, debug, or process access. |
| Callbacks, GC/destructors, and host hooks | Luaz maps interrupt, panic, userthread, useratom, debug, and onallocate callbacks and documents userdata lifetime (luaz/src/Lua.zig:218-476; luaz/src/State.zig:1424-1487). | Interrupt can only be installed cross-thread upstream; the wrapper has no cancellation token or structured invocation context, and callback errors still interact with longjmp. The assert handler is process/global rather than a per-invocation diagnostic sink (luaz/src/handler.h:1-13; luaz/src/handler.cpp:1-5). | Stale callback pointers are cleared when callbacks change; no callback runs after state close; userthread create/destroy is balanced; interrupt cancellation is observed inside a protected call; panic/assert text is bounded and associated with the invocation. |
| Owned invocation result | Luaz's high-level call returns Value/Result and its VM strings are state-owned; it does not define a byte/diagnostic result container (luaz/src/Lua.zig:2295-2429; luaz/src/stack.zig:609-789). | Reified needs output bytes and diagnostics to outlive a fresh state, a disposition, metrics, and deinit. The native bridge and vm.zig provide this privately (reified/src/luau/native/luau.cpp:75-80,251-329; reified/src/luau/vm.zig:62-124). | Result storage is freed once, lengths are validated before slicing, diagnostic truncation is explicit, and non-return dispositions never expose stale or partial output. |

## Current coverage and exact gap map

### 1. State and protected lifetime

The generic state lifecycle is usable: main state creation, custom allocation,
close, and coroutine creation exist. A thread shares the global environment but
has its own execution stack and is reclaimed by the main state
(luaz/src/State.zig:111-134). Refs pin values in the registry; strings returned
from the state are borrowed and can become invalid after the value is removed
or collected (luaz/src/State.zig:380-399,973-1006).

The gap is an ownership contract, not a missing C function. Reified needs a
fresh invocation owner that makes state, allocator userdata, threads, refs,
callbacks, and result storage one lifetime. Luaz's wrapper documents the
allocator requirement but does not prevent copying or mixing state-bound
objects (luaz/src/Lua.zig:79-146). The Reified owner must copy final bytes
before lua_close and must not allow a VM reference to escape.

With LUA_USE_LONGJMP=1 in the luaz build (luaz/build.zig:49,107), a VM throw
does not unwind C++ destructors. Upstream installs a jump buffer in
luaD_rawrunprotected; luaD_throw writes the status and longjmps to the active
handler, or invokes panic/aborts when none exists
([ldo.cpp protected execution](https://github.com/luau-lang/luau/blob/master/VM/src/ldo.cpp#L2099-L2167)).
luaD_pcall and lua_resume restore protected state around their bodies
([luaD_pcall](https://github.com/luau-lang/luau/blob/master/VM/src/ldo.cpp#L3403-L3484),
[lua_resume](https://github.com/luau-lang/luau/blob/master/VM/src/ldo.cpp#L3293-L3325)).
The generic deep module therefore needs an explicit ProtectedFrame
abstraction: all potentially throwing VM operations execute under a known
landing point, and callbacks translate cancellation/errors inside that frame.
The current high-level call path is too lossy because it maps most statuses to
Runtime and writes the message to stderr (luaz/src/Lua.zig:2295-2377).

### 2. Bytecode and diagnostics

Compiler.Result has a good basic ownership rule: the returned pointer is freed
with std.c.free on deinit, and the Luau compiler marks encoded errors separately
from valid bytecode (luaz/src/Compiler.zig:10-88). The options are deliberately
small and generic (luaz/src/Compiler.zig:27-57). The missing pieces are an
allocator/budget injection point, an owned diagnostic type with bounded length
and source identity, and a structured distinction among syntax, compiler OOM,
invalid bytecode, and runtime errors.

Lua.eval currently defers deinit but returns only Error.Compile for a compiler
error, losing the message (luaz/src/Lua.zig:2380-2429). That is acceptable for
a convenience API and insufficient for Reified's externally observable
diagnostics. Upstream's compile API returns valid bytecode or an encoded error,
and compiler errors own message strings
([Compiler.h](https://github.com/luau-lang/luau/blob/master/Compiler/include/Luau/Compiler.h#L560-L577),
[Compiler.cpp](https://github.com/luau-lang/luau/blob/master/Compiler/src/Compiler.cpp#L2301-L2342)).
The fork should expose ownership and status without imposing Reified's
diagnostic wording or output policy.

### 3. Module graph, resolver, cache, cycles, and environments

Luaz's load operation accepts one chunk name, bytecode slice, and environment;
there is no module graph or supplied-source resolver
(luaz/src/State.zig:793-818). Generic require semantics therefore cannot be
obtained from the wrapper by merely adding a convenience function: resolution,
source identity, cache state, active-load state, and environment creation must
be specified together.

Reified already has a useful policy-neutral frame shape: each source is
compiled independently, relative imports are fenced by scope, and aliases
occupy exact slots (reified/src/luau/modules.zig:1-56). The native loader
normalizes and validates paths, resolves aliases only in the exact scope,
creates an environment with require, caches the returned module value, and
detects an active cycle (reified/src/luau/native/luau.cpp:97-197). Its module
index validation covers duplicate paths, scope/alias errors, and source
limits (reified/src/luau/native/luau.cpp:353-436). The current Reified
behavior is explicit cycle rejection; it must not be silently replaced with a
different upstream require policy. The upstream cyclic-requires RFC describes
why cycle behavior is a separate semantic choice
([cyclic requires RFC](https://github.com/luau-lang/rfcs/blob/master/docs/support-for-cyclic-requires.md)).

The exact luaz gap is the absence of this supplied-module abstraction. A
generic interface should accept already validated source records and resolver
bindings; filesystem/package search and the decision to reject cycles belong
to Reified policy. If the fork does not gain a module API, the Reified native
bridge must remain the owner of all graph behavior.

### 4. Raw values and traversal

State has raw iteration and registry operations, and stack conversion can
materialize a Value/ref graph (luaz/src/State.zig:919-1006;
luaz/src/stack.zig:609-789). The high-level Table API intentionally performs
ordinary table access, including metamethod-aware get/length behavior
(luaz/src/Lua.zig:680-725,805-843). Its iterator is a convenience adapter
that repeatedly calls next and converts keys/values to owned-or-borrowed
Values (luaz/src/Lua.zig:1110-1183), not a complete no-side-effect traversal
contract.

Reified's JSON module is the reference data boundary: it uses next/rawget,
rejects non-data values and cycles, validates depth and finite numbers, and
sorts string keys for deterministic output (reified/src/luau/sdk/json.luau:1-58).
The native input tree independently validates node/depth, safe integers, UTF-8,
and object/array shape (reified/src/luau/native/luau.cpp:199-249;
reified/src/luau/vm_input.zig:1-74). The generic gap is a raw visitor or
scalar-copy facility that states whether metatables are ignored, what roots
are held, and how cycles/sparsity/key types are reported. Reified policy should
choose the accepted shape; luaz should provide predictable raw mechanics.

### 5. Allocation, instruction accounting, and GC

Luaz adapts a Zig allocator to Luau's realloc contract: nsize zero frees,
nonzero requests realloc, and shrinking must not fail
(luaz/src/alloc.zig:10-45). Upstream has the same non-failing shrink/equal
rule and updates VM totals/categories around realloc
([lmem.cpp allocator contract](https://github.com/luau-lang/luau/blob/master/VM/src/lmem.cpp#L2009-L2035),
[lmem.cpp accounting](https://github.com/luau-lang/luau/blob/master/VM/src/lmem.cpp#L3167-L3239)).
These are the correct generic hooks. They are not a hard budget.

The Reified allocator adds overflow-safe aligned charges, reserves both
old/new blocks before copy, and tracks live/peak bytes
(reified/src/luau/native/allocator.hpp:14-64). The bridge's allocator records
the resulting disposition (reified/src/luau/native/luau.cpp:61-73). The
compiler uses C++ allocations outside the VM allocator; Reified bounds those
in the worker by overriding new/delete and tracks compiler peak
(reified/src/luau/native/worker_memory.cpp:1-70). Luaz has no equivalent
compiler allocator seam or metric.

Upstream interrupt callbacks are eventual safepoint hooks and long-running
native C functions can delay them ([Luau sandbox interrupts](https://luau.org/sandbox/)).
Luaz exposes callbacks but does not define an exact instruction count. Reified
uses debugstep before each instruction and raises once the configured count is
reached (reified/src/luau/native/luau.cpp:88-95; single-step is documented at
[Luau API — debug hooks](https://luau.org/api/#debug-hooks)). A generic
Budget mechanism should report allocator live/peak, instruction count,
compiler peak, and a qualified reason; it must not pretend to bound arbitrary
native time. Worker CPU/timeout controls remain containment policy.

### 6. Sandbox and callbacks

Luaz's sandbox wrappers expose upstream's readonly-library/metatable and
thread-proxy mechanisms (luaz/src/State.zig:1365-1377). Upstream explicitly
describes sandboxing as embedder cooperation: luaL_sandbox marks the main
environment and libraries readonly, while luaL_sandboxthread gives a thread
isolated writes ([Luau API — sandboxing](https://luau.org/api/#sandboxing)).
The upstream page also cautions that sandboxing is not a formal proof of safety
and that unsafe libraries must be removed
([Luau sandbox overview](https://luau.org/sandbox/)).

The native Reified bridge removes unsafe globals and libraries, removes
randomness and dynamic-loading helpers, applies luaL_sandbox and
luaL_sandboxthread, and then executes only supplied code
(reified/src/luau/native/luau.cpp:251-315). That list is Reified policy. The
luaz gap is not a missing sandbox function; it is the lack of an explicit
installation seam that lets the policy owner supply a removal/readonly plan
without implying that generic luaz is a secure worker.

Luaz maps every upstream callback family and stores callback userdata until
replacement or state destruction (luaz/src/Lua.zig:218-476). Upstream says
only interrupt is safe to set from another thread; callbacks otherwise require
the VM to be stopped ([Luau API — callbacks](https://luau.org/api/#callbacks)).
The fork has no standard cancellation context, bounded diagnostic sink, or
per-invocation assert handler. A callback-facing deep module should make those
preconditions and the callback userdata lifetime explicit. Reified currently
keeps the critical meter in native debugstep and uses the worker process for
termination, avoiding an untrusted callback crossing the process boundary.

## Proposed deep module interfaces (design only; no code)

These are capability boundaries, not a demand that all names become public
Zig types.

1. **LuauProfile.** Immutable package/Luau source hashes, vector size,
   longjmp/codegen flags, C++ ABI, compiler options, and a profile identifier.
   It exposes verification and human-readable mismatch diagnostics. It does
   not choose deployment limits.

2. **VmOwner.** A non-copyable owner that opens one state with a supplied
   allocator, installs callbacks/sandbox hooks, creates scoped threads, and
   closes exactly once. Every ref, borrowed pointer, string view, and callback
   userdata carries this lifetime. No owner value escapes an invocation.

3. **ProtectedFrame.** The only boundary for load, call, resume, error,
   interrupt, and callback translation. It returns a status/disposition,
   stack effect, and owned diagnostic while restoring the expected stack
   height. It documents that raw lua_call-like operations never cross its
   boundary and that C++ destructors cannot be skipped by a longjmp.

4. **CompilerSession.** Compiles a source record with explicit options and a
   compiler allocation budget. The result owns bytecode or bounded diagnostic
   bytes and distinguishes valid bytecode, syntax/compile error, compiler OOM,
   and invalid result. It accepts no implicit filesystem or module resolver.

5. **ModuleFrame.** Registers immutable source records, exact scope/path
   identities, and explicit aliases; loads an entry using a supplied resolver.
   It owns cache and active-load state, creates per-module environments, and
   reports duplicate, alias, path, missing, and cycle outcomes. Whether cycles
   are rejected is a caller policy, but Reified's current contract rejects
   active cycles.

6. **RawValue/RawWalker.** Inspects type, pins a root when necessary, performs
   raw table iteration and scalar copy, and releases refs. It states that no
   metamethods or callbacks are invoked, reports cycles/depth/sparse/key-shape
   failures, and never returns a state-borrowed string as an invocation result.

7. **BudgetMeter.** Composes VM realloc accounting, instruction ticks,
   compiler allocation accounting, output/diagnostic bounds, and metrics. The
   allocator contract guarantees no-fail shrink and reserve-before-copy; the
   meter returns qualified exhaustion rather than a generic Runtime error.

8. **SandboxInstall.** Applies upstream readonly/sandbox primitives and takes
   a policy-owned capability removal plan. It has separate main-state and
   thread operations and exposes no promise of process isolation or formal
   memory safety.

9. **InvocationResult.** Owns output and diagnostic storage after the VM is
   closed, includes disposition, flags, byte lengths, live/peak/compiler
   metrics, and deinit. It validates lengths before slicing and never exposes
   partial output for non-return outcomes.

10. **WorkerBoundary (Reified-owned).** The process, pipes, timeout, CPU
    limit, empty environment/cwd, request framing, profile attestation, and
    successful-EOF rule stay here. This is not a luaz capability and should not
    be hidden in a generic State wrapper.

## Dependency-only implementation slices

1. **Pin and profile alignment.** Decide the Luau 0.702 versus 0.737 target;
   export luaz_c, luaz_options, and luaz_profile (or retarget Reified's build);
   freeze vector, longjmp, C++ ABI, compiler, and codegen facts.
2. **State owner and protected frame.** Add the lifetime/stack/status contract
   around the existing allocator, load, call, resume, refs, and callbacks.
   Establish negative longjmp tests before exposing higher-level execution.
3. **Compiler ownership seam.** Return owned bytecode/diagnostic objects and
   introduce the compiler allocation budget/peak path, including all C++ new
   forms used by the pinned compiler.
4. **Raw value seam.** Add no-metamethod raw traversal, scalar copying, root
   pinning, and explicit cycle/depth/key-shape outcomes.
5. **Module frame.** Implement supplied-source registration, normalized
   resolver, exact scope aliases, environments, cache, and selected cycle
   semantics. Keep filesystem/package policy out of this layer.
6. **Execution meter.** Connect allocator resize, debugstep/interrupt policy,
   output/diagnostic caps, and qualified metrics to InvocationResult.
7. **Sandbox installation.** Keep the removal list and safe-capability decision
   in Reified; make generic luaz only provide the upstream primitives and an
   installation seam.
8. **Native bridge and worker integration.** Wire the existing Reified bridge
   to the chosen luaz profile/frame contracts; retain process timeout, CPU,
   OS sandbox, and attested framing in worker code.
9. **Boundary verification.** Run the exact tests below at each dependency
   boundary, then one integrated invocation/worker acceptance pass. No slice
   should require a second VM owner or an ambient module search.

## Exact test oracles

### Build and compatibility

- Import luaz, luaz_c, luaz_options, and luaz_profile from the product graph;
  fail with a named diagnostic when a module is absent.
- Build metadata must expose the exact Luau commit/hash, vector size, longjmp
  setting, C++ standard/library, compiler options, and codegen mode. Change any
  one and assert that profile verification rejects the old identifier.
- Compile a bytecode blob with the pinned compiler and load it with the pinned
  VM; reject a blob/profile pair from a different fingerprint.

### State, refs, and longjmp

- Create a state with a counting allocator, create a thread and registry ref,
  close the main state, and assert balanced reclamation and no callback after
  close.
- Hold a string view, remove/collect its value, and assert the view is
  documented as invalid; copy it into result storage before close and assert
  the copied bytes remain valid.
- Trigger lua_error inside a protected C call and assert status, error object,
  stack restoration, and result ownership. Trigger the same error through an
  unprotected raw call only in a subprocess negative test; it must never be
  the ordinary Reified path.
- Replace callbacks and assert missing callback slots are cleared rather than
  retaining stale function pointers. Exercise userthread create/destroy as a
  balanced pair.

### Compiler and bytecode

- Valid source produces non-empty bytecode and executes.
- Syntax and compiler errors preserve the expected source location/message
  bytes up to the configured diagnostic bound; compiler deinit frees both
  success and failure results.
- Force compiler allocation failure at each allocation site; assert a compiler
  exhaustion/OOM disposition, no leaked C++ allocation, and no VM result bytes.
- Load invalid bytecode and assert a structured load diagnostic, not an
  unreachable branch or generic stderr-only Runtime error.

### Modules and environments

- Relative import resolves within its own scope and returns the expected
  origin/scope; an undeclared alias never falls through another scope.
- Reject malformed frames, duplicate paths, duplicate aliases, invalid scope
  indices, absolute/backslash/NUL/empty/escaping paths, missing modules, and
  invalid entry indices as invalid_source.
- Require the same module twice and assert one execution and one stable cache
  identity. Require an active module and assert the documented deterministic
  cycle error (current Reified policy).
- Assert each module has its own environment, writes do not leak across
  modules, readonly global/library tables cannot be mutated, and the private
  module index cannot be required by an unbound name.

### Raw values and result ownership

- Construct __index, __iter, __newindex, and __call side effects and traverse
  a result; assert that the raw visitor/serializer invokes none of them.
- Reject cycles, sparse arrays, unsupported key types, non-finite numbers,
  excessive depth/nodes, null array elements, and non-data values with stable
  dispositions.
- Encode embedded NUL and UTF-8 strings byte-for-byte; sort string keys and
  assert deterministic repeated output.
- Assert every temporary registry ref is released and that no state-bound
  Value, light userdata pointer, or string slice is present in
  InvocationResult.

### Budgets and callbacks

- Exercise allocator alloc, grow, shrink, equal-size, free, overflow,
  old-size mismatch, and exact-boundary cases. Shrink/equal must not fail;
  growth must reserve before copy; live/peak must match the counted bytes.
- Run a loop at limits N-1, N, and N+1 and assert the exact debugstep
  instruction count and exhausted disposition. Test a long native call
  separately to document that instruction hooks do not bound native time.
- Bound output and diagnostic independently; assert truncation flags/lengths
  and no partial output on exhaustion or runtime error.
- Exercise interrupt cancellation at a safepoint and GC interrupt state; assert
  cancellation is translated only inside the protected frame and cannot yield
  or leave a live VM.

### Sandbox and worker containment

- After installation, assert unsafe globals/libraries and dynamic loading
  helpers are absent; readonly library/metatable mutation fails; a thread's
  local global write does not mutate the main global.
- Assert the supplied resolver has no filesystem, cwd, package-path, network,
  process, clock, or ambient environment fallback.
- Worker tests must assert absolute executable validation, empty environment,
  cwd root, request magic/profile/length checks, EOF and successful exit,
  timeout cancellation plus kill/reap, CPU/OS restriction where supported,
  compiler peak reporting, VM live bytes equal to zero, and no accepted
  output after protocol or child failure.

Existing luaz tests establish the baseline rather than the full Reified
oracle: runtime/compile error mapping (luaz/src/tests.zig:284-346),
coroutine yield/resume (luaz/src/tests.zig:1177-1210), sandbox mutation
(luaz/src/tests.zig:1389-1411), and callback allocation/thread coverage
(luaz/src/tests.zig:2148-2273). Reified already tests module scope and
malformed bindings (reified/src/luau/modules.zig:58-121) and input
ownership/limits (reified/src/luau/vm_input.zig:76-127); the new seam tests
should preserve those oracles while making the underlying ownership/status
contracts explicit.

## Compatibility and non-goals

- Treat the pinned Luau 0.702 source and hash as the compatibility baseline
  until an explicit upgrade decision is made. Do not infer compatibility from
  the language version alone.
- Reified's worker profile keeps codegen disabled and records that fact
  (reified/src/luau/profile.zig:13-37). Generic luaz may expose codegen, but
  this worker contract does not promise JIT behavior, native-code accounting,
  or codegen-stable fingerprints.
- No persistent VM, coroutine, ref, pointer, borrowed string, or module cache
  crosses a Reified invocation. Luau threads are coroutine state, not
  OS-thread isolation (luaz/src/State.zig:111-134).
- No generic module API may search the filesystem, package paths, process
  environment, network, cwd, clock, or random source. The resolver receives
  supplied records only.
- Process timeout/kill, CPU and OS sandbox, empty env/cwd, framing, profile
  attestation, worker protocol, domain schema, and authority/worker policy are
  not luaz responsibilities. The worker owns them
  (reified/src/luau/worker.zig:1-6,115-224).
- Upstream sandboxing is embedder cooperation, not a formal memory-safety
  proof; process containment remains required for hostile code
  (https://luau.org/sandbox/).
- Do not promise that interrupts bound arbitrary native C/C++ duration, or
  that a callback can safely mutate a running state. Follow upstream callback
  preconditions (https://luau.org/api/#callbacks).

## Open decisions

1. Should the fork upgrade from Luau 0.702 to the Reified bridge's 0.737
   assumptions, or should the bridge be retargeted to 0.702? The answer must
   update the nested hash and allocator/ABI tests together.
2. Should module loading become a reusable luaz supplied-source API, or remain
   wholly in Reified native code? Keeping it native minimizes generic policy,
   but leaves the graph contract outside Zig.
3. Can the pinned compiler accept an allocator/context directly, or must the
   worker-wide C++ operator-new interception remain the budget mechanism?
   Include aligned/sized/array new and exception/destructor behavior in the
   decision.
4. What is the diagnostic wire format and maximum? Decide source path,
   location, truncation flag, encoding, and whether syntax, compile OOM,
   invalid bytecode, and runtime errors remain distinct externally.
5. Is the instruction ceiling defined as “debugstep callbacks observed” or
   “instructions completed,” and how are a final instruction, VM calls, GC,
   and native C functions accounted?
6. Should the generic seam expose safeenv/readonly/pointer encoding directly,
   or should Reified's native bridge be the sole caller? No pointer encoding is
   needed while no pointers cross the result boundary.
7. Should State/Lua wrappers become opaque/non-copyable and require an owner
   token, or can documentation plus tests enforce state-bound lifetimes?
8. Is active-cycle rejection the permanent Reified rule, or will a future
   export-table cyclic-require semantics be adopted? Do not mix the two
   behaviors in one profile.
9. Should the direct C bridge validate output length before vm.zig slices its
   owned storage? The worker decoder validates lengths, but the in-process
   bridge should have the same defense (reified/src/luau/vm.zig:62-124;
   reified/src/luau/worker.zig:187-220).

## Source index

### Luaz fork

- luaz/build.zig:37-121,200-279,281-308 — Luau artifacts, C translation,
  modules, macros, and test root.
- luaz/build.zig.zon:1-20 — package version, Luau revision/hash, Zig
  fingerprint, and package files.
- luaz/README.md:12-38 — library scope and examples.
- luaz/src/Compiler.zig:10-88 — compiler result ownership/options.
- luaz/src/alloc.zig:10-45 — Zig-to-Luau allocator contract.
- luaz/src/lib.zig:6-18 — exported generic surface.
- luaz/src/State.zig:24-53,94-134,380-399,793-856,897-1006,1011-1019,
  1365-1377,1392-1487 — state, load/call, refs, sandbox, and callbacks.
- luaz/src/Lua.zig:52-104,134-146,209-525,680-725,805-843,930-1030,
  1110-1183,1225-1255,1436-1610,1635-1684,2103-2148,2295-2429,
  2571-2602 — high-level ownership, values, calls, evaluation, and sandbox.
- luaz/src/stack.zig:78-428,430-607,609-789 — push/pop/trampoline/value
  conversion and pointer/ref behavior.
- luaz/src/tests.zig:19-79,81-111,284-346,1177-1210,1340-1411,
  1363-1385,2148-2273 — callback, globals, error, coroutine, sandbox, and
  allocation baselines.
- luaz/src/handler.h:1-13 and luaz/src/handler.cpp:1-5 — global assert
  handler.

### Reified comparison sources

- reified/build.zig:84-139,481-511 — luaz module/artifact expectations and
  worker C++ linkage.
- reified/src/luau/vm.zig:1-124 — fresh VM/result/limits bridge.
- reified/src/luau/modules.zig:1-121 — supplied module frame and tests.
- reified/src/luau/vm_input.zig:1-127 — bounded input tree and tests.
- reified/src/luau/profile.zig:1-37 — build/profile preimage and hash.
- reified/src/luau/worker.zig:1-281 — worker protocol/containment.
- reified/src/luau/native/luau.cpp:1-447 — native VM, modules, input, meter,
  sandbox, and C ABI.
- reified/src/luau/native/allocator.hpp:1-64 — VM allocation budget.
- reified/src/luau/native/worker_memory.cpp:1-70 — compiler allocation and
  OS restriction.
- reified/src/luau/sdk/json.luau:1-58 — deterministic raw data encoding.

### Official Luau primary sources

- [Luau C API — VM state](https://luau.org/api/#virtual-machine-state),
  [loading bytecode](https://luau.org/api/#loading-bytecode),
  [making calls](https://luau.org/api/#making-calls),
  [registry references](https://luau.org/api/#registry-references),
  [memory](https://luau.org/api/#memory), and
  [error handling](https://luau.org/api/#error-handling).
- [Luau API — sandboxing](https://luau.org/api/#sandboxing),
  [callbacks](https://luau.org/api/#callbacks), and
  [debug hooks](https://luau.org/api/#debug-hooks).
- [Luau sandbox guidance](https://luau.org/sandbox/) and
  [Luau performance notes](https://luau.org/performance/).
- [Protected execution and longjmp](https://github.com/luau-lang/luau/blob/master/VM/src/ldo.cpp#L2099-L2167),
  [resume protection](https://github.com/luau-lang/luau/blob/master/VM/src/ldo.cpp#L3293-L3325),
  and [pcall protection](https://github.com/luau-lang/luau/blob/master/VM/src/ldo.cpp#L3403-L3484).
- [VM callback/state fields](https://github.com/luau-lang/luau/blob/master/VM/src/lstate.h#L1271-L1292),
  [allocator typedef](https://github.com/luau-lang/luau/blob/master/VM/include/lua.h#L1604-L1612),
  and [callback structure](https://github.com/luau-lang/luau/blob/master/VM/include/lua.h#L2488-L2515).
- [VM allocator contract](https://github.com/luau-lang/luau/blob/master/VM/src/lmem.cpp#L2009-L2035),
  [VM allocation accounting](https://github.com/luau-lang/luau/blob/master/VM/src/lmem.cpp#L3167-L3239),
  [compiler API](https://github.com/luau-lang/luau/blob/master/Compiler/include/Luau/Compiler.h#L560-L577),
  and [compiler diagnostics](https://github.com/luau-lang/luau/blob/master/Compiler/src/Compiler.cpp#L2301-L2342).
- [Luau cyclic-requires RFC](https://github.com/luau-lang/rfcs/blob/master/docs/support-for-cyclic-requires.md)
  — upstream module-cycle semantics are a separate choice from Reified's
  current rejection rule.
