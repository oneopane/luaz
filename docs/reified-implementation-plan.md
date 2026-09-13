# Minimal luaz fork plan for Reified

Accepted strategy: a minimal fork followed by narrow, separately owned Reified
adoption/extraction. This replaces the earlier public execution-engine plan;
its proposed runtime abstractions and implementation increments are retired,
not outstanding obligations.

Status: candidate delivery complete for the dependency-owned package boundary.
The fork is pinned to the coordinator-accepted Luau 0.737 baseline from the
Reified packaged luaz 0.6.0 dependency. The native package, public module
closure, support linkage, and deterministic build facts have been implemented
and checked locally. This is not Reified adoption: the Reified worker still
owns protected execution, policy, containment, and its own
compatibility/profile acceptance.

## Evidence and responsibility

The preparation record in docs/reified-capability-requirements.md supplied the
initial dependency/build discrepancies and primitive hypotheses, but its
proposed capability expansion is not execution authority under this strategy.
The candidate additionally inspected the Luaz build/source graph, the selected
Luau package, and the native consumer closure. Paths below describe ownership
and write scopes; they do not move Reified policy into this fork.

The fork has four responsibilities:

1. Establish the exact Luau source/build baseline and its provenance.
2. Own a coherent native build: sources, flags, includes, artifacts, and effective
   facts a consumer needs to link and fingerprint that dependency.
3. Correct objective defects in primitives that Reified actually uses.
4. Apply a narrow, pin-specific Luau/compiler allocation patch only if an
   independent route audit proves it necessary for the required bound.

The cohesive dependency build is the deep module: it hides source enumeration,
macro consistency, include layout, linkage, and build identity behind a small
consumer boundary. Existing Luau primitives remain the execution interface.
A new public runtime object model is not needed to make that build coherent.

| Owner | Responsibility |
| --- | --- |
| Luaz fork | Exact dependency identity, package-owned native build, effective facts, proven used-primitive corrections, conditionally a narrow allocation hook |
| Compact native invocation component in Reified | Longjmp landing points, native callbacks, state/ref lifetimes, module activation, VM allocator/instruction accounting, compiler-bound application, and bounded result copying |
| Reified policy and worker code | Module authorization/normalization/aliases/cycles, capability removals, serialization, failure mapping, selected limits, protocol/attestation, processes, and OS containment |

The protected native invocation component stays in Reified. Native operations
that may longjmp must land within that component; it owns the associated native
resource discipline and prevents a jump across Zig cleanup or live C++ RAII
frames. This plan does not recreate that component as a luaz API or relocate
the mixed bridge wholesale.

## G0: exact baseline record

The coordinator accepted G0 from the Reified packaged luaz 0.6.0 baseline:
Luau tag 0.737 with Zig package content hash
`N-V-__8AADetGAEcdQuTr-nq27CyCea3jnhtkeu-EYaA03Lb`. Supplied evidence maps
that tag to commit `62dbc0b4718e87fc746b02f969c91ca2a461b4cf`; Luaz records
the mapping as supplied and accepted provenance, not as an independently
resolved commit. The accepted profile is ReleaseSafe, codegen disabled,
vector-size 4, `LUA_USE_LONGJMP=1`, C++17, and libc++.

This supersedes the provisional 0.738 candidate and the older 0.702 evidence;
the fork must not retain 0.738-only mechanisms merely for compatibility.

The full profile-owner handoff remains a Reified adoption responsibility. The
fork's effective package facts are now generated and checked by `zig build
profile`; they are not a substitute for Reified's accepted worker profile or
for behavioral observations that belong to the worker.

The eventual Reified handoff may still use an accepted luaz-attested-baseline-v1 bundle:

- manifest.json: producer, attested-runtime identity, member hashes, and the
  profile/contract owner's acceptance.
- baseline.json: exact Luau revision/content hash and patches; toolchain/target;
  effective native sources, C/C++ definitions, vector size, longjmp, codegen,
  C++ standard/library/ABI and compile/link options; compiler options; the
  meanings of current externally observable accounting.
- cases.zon: a small set of neutral dependency/used-primitive fixtures, including
  any allocation-retention cases needed to evaluate the required compiler bound.
- expected.json: the attested observations and the documented normalization
  that removes worker transport details without erasing relevant behavior.

The handoff also identifies the native entry points and any Zig wrappers Reified
actually uses, the include/link inputs its native component needs, and whether
a new dependency allocation hook is required or merely a candidate improvement.
Its source inventory distinguishes Luau/luaz-owned compilation units from
Reified's consumer units; only the former belong in the package.
A compiler-bound requirement must state its charge domain, lifetime, and current
observable metrics; it must not arrive as an undefined request for "metering."

The fork candidate checks identity and effective package facts, but does not
claim acceptance of legacy accounting or a compiler allocation charge domain.
Unknown worker observations and an unresolved required-bound definition remain
open for Reified adoption; they do not block this dependency-only delivery.

Initially preserve the currently attested native behavior and accounting,
including active-cycle rejection in Reified. A source/build change produces
updated build facts; an unavoidable semantic/accounting change additionally
requires an explicitly accepted new execution profile. Do not hide either
change behind a language-version string.

The delivered dependency slice includes F0 pin/provenance alignment and F1
coherent native packaging. No separate public execution-engine API was added.

## Smallest coherent package boundary

F1 makes it possible to build Reified's existing native component against
the package without separately guessing Luau source lists, flags, or include
roots. Keep the existing luaz Zig module and existing working exports.

The required outputs are:

- The exact VM/compiler native artifact set, with the `luaz_support` artifact
  owning the single `src/handler.cpp` compilation and installed `handler.h`.
  Both public modules and the `luaz` artifact reach that support artifact; a
  consumer does not compile a second copy. Do not link a second VM or compiler
  copy.
- Package-anchored headers/include roots and the effective ABI definitions
  needed to compile a consumer's own C++ invocation component. Include only
  roots required by the observed consumer. Generated configuration headers,
  native compilation, and any C translation must agree.
- One effective build-facts representation, exposed in the form the actual
  consumer needs. The proposed local profile outputs are
  zig-out/share/luaz/build-facts.json and
  zig-out/share/luaz/build-fingerprint.txt, produced by zig build profile.
  A Zig facts module or generated header may project that same data if needed.
- A short docs/native-consumer.md identifying the actual artifact/module names,
  header surface, required link inputs, and supported baseline options.

The research note's four names—luaz, luaz_c, luaz_options, and luaz_profile—are
consumer wiring evidence, not four product semantics to implement. Retain or
add mechanical aliases only when they make the existing consumer wiring
smaller and coherent. Aliases share the same translated C types, effective
options, facts, and native graph; they do not justify separate runtime APIs.
Record the selected minimal surface in the consumer document and its smoke test.

Build facts cover exact source/patch identities, target/toolchain, all effective
ABI-affecting definitions, vector/longjmp/codegen settings, compiler defaults,
and relevant C++/link facts. Use a versioned deterministic encoding, excluding
timestamps and absolute local paths, to produce the fingerprint. A fingerprint
comparison can report expected and actual IDs; field differences require both
complete fact records. Reified composes and verifies its worker profile itself.
Caller-selected compile options belong in compatibility observations and
Reified's execution profile, not new luaz deployment configuration. The package
fingerprint covers its own sources/build, not Reified's invocation source.

Use the attested settings initially, including the recorded codegen-disabled
mode. Expose no deployment limits, removal lists, module policy, transport
constants, worker paths, or timeouts as new package options. Existing unrelated
package functionality remains unchanged.

## Objective primitive defects only

Before a primitive edit, establish all three facts: Reified uses the affected
primitive; the primitive violates its existing documented/native contract;
and a small reproducer observes that violation. Record the exact production
file and focused test before editing. Missing convenience features or a lossy
high-level API that Reified does not call are not grounds for expansion.

Possible inspection targets from the research note are allocator resize
semantics, compiler-result allocation/free ownership, raw load/status wrapping,
and native assert/linkage configuration. These are hypotheses, not established
defects. Do not rewrite Lua.zig, create a new State owner model, or add a compiler
session/result framework to address them.

A fix preserves the existing interface unless a minimal correction is required
for the demonstrated contract. Keep status and allocation/free provenance
faithful to the used primitive. Reified continues to own bounded diagnostics,
post-close result storage, and external failure interpretation.

## Conditional allocation feasibility gate

A new compiler allocation seam is conditional, not a default fork feature.
F3a evaluates only the exact compiler entry path and bound named in G0.

Produce a pin-specific inventory of reachable allocation/free routes, their
source paths/symbols, C and C++ allocation forms, output/diagnostic retention,
exception cleanup, and the existing hook/charge domain. Independently observe
the relevant backing allocation routes in an isolated test binary. Normalize
nested allocation calls, keep observer storage separate, and use a deliberate
bypass allocation to prove that the observer detects work the intended routed
counter would miss. Routed failpoints alone cannot establish completeness.

The bounded gate has three outcomes:

1. Existing primitives/build inputs suffice: record the evidence and make no
   allocation patch.
2. A small dependency-local hook is necessary and covers the complete required
   route set: prepare F3b with exact upstream file/symbol scope, ownership
   contracts, reproducer, and old/new observations.
3. Coverage requires pervasive compiler changes, a new runtime framework,
   process-wide allocation interception, or an unobservable route: the proposed
   extension is not ready. Return that concrete limitation to the profile/contract
   owner; do not expand the fork to manufacture a solution.

If F3b is justified, prefer an existing allocator context. Otherwise add a
native context/hook only at the used compiler entry and necessary internal
routes. Reified supplies and owns that context, its limits, aggregation,
accounting, and interpretation. Luaz does not introduce shared compiler-budget
objects or retain a public invocation context.

The patch must state which allocator frees each returned allocation and how long
the caller's context remains valid. Ownership transfer does not end a charge
while storage remains live; retained outputs and copy overlap follow the
accepted baseline. Compiler exceptions unwind normally within the compiler's
C++ domain; the hook must not call into the VM or trigger a Luau longjmp.
Do not place production operator-new overrides in the package.

Apply any patch to a private prepared dependency tree, never a shared dependency
cache. Include its digest in build identity. A route or accounting mismatch is
not permission to revise expected metrics from candidate output. A necessary
semantic/accounting change goes to the profile owner with a concrete proposed
new profile.

## Small patches and exact write scopes

These are future scopes, not authorization to perform them during this planning
turn. Each patch has one owner. Shared build files have one integrating writer.
Do not create optional files unless the corresponding need is demonstrated.

**F0 — Exact pin and provenance.** Delivered for the coordinator-accepted 0.737
baseline. Write build.zig.zon and the corresponding build-facts identity in
build.zig when alignment is needed, plus tests/native_consumer/baseline.json
and tests/native_consumer/fixtures.zon to record the adopted manifest/facts
and selected neutral observations.
Exit: resolved source/patch identity matches G0 and provenance is reviewable.
This does not yet claim the consumer build is coherent.

**F0 historical note.** The earlier provisional 0.738 candidate was superseded
by the accepted G0 above; its package-only receipt is retained only in local
history, not as the active baseline.

**F1 — Coherent native package and smoke test.** Delivered for the accepted
0.737 baseline.
Allowed writes: build.zig, build.zig.zon for packaged-file declarations,
build_support/NativeBuild.zig, build_support/Profile.zig,
build_support/NativeConsumerTests.zig, src/lib.zig, src/profile.zig,
src/c_api.h, tools/profile.zig, tests/native_consumer/root.zig,
tests/native_consumer/native_link.cpp, tests/native_consumer/profile.zig,
and docs/native-consumer.md.
Use existing roots/helpers where they suffice; new profile/C roots and aliases
are conditional projections, not mandatory additions. Package native sources
where they already belong; do not import Reified native source files.
Exit: B01–B04 pass with the documented minimal export surface.

**F2 — One proven used-primitive defect per patch.** Depends on F1.
Only the row justified by the recorded reproducer is opened:

| Demonstrated defect | Production scope | Focused test scope |
| --- | --- | --- |
| Used Zig allocator adapter violates pinned realloc/free contract | src/alloc.zig | tests/native_consumer/allocator.zig |
| Used compiler wrapper violates existing ownership/status contract | src/Compiler.zig | tests/native_consumer/compiler.zig |
| Used raw state wrapper has an incorrect signature/status/stack contract | src/State.zig | tests/native_consumer/state.zig |
| Required native assert support has a linkage/ABI defect | src/handler.h and src/handler.cpp | tests/native_consumer/native_link.cpp |

Test wiring may update only tests/native_consumer/root.zig and
build_support/NativeConsumerTests.zig; build.zig is opened only for necessary
native linkage. No row authorizes a general wrapper rewrite or Luau VM-source
change. Exit: D01 and the affected B/C tests pass. If no defect is reproduced,
F2 produces no production patch.

**F3a — Allocation feasibility, only if the required bound remains unresolved.**
Depends on F0/F1 and the precise G0 bound definition.
Allowed writes: docs/compiler-allocation-feasibility.md,
tests/native_consumer/compiler_allocation_audit.cpp,
tests/native_consumer/compiler_allocation_bypass.cpp,
tests/native_consumer/compiler_allocation.zig, and necessary wiring in
build.zig, build_support/NativeConsumerTests.zig, and
tests/native_consumer/root.zig.
Exit: A01 and a reviewed inventory establish one of the three outcomes above.
No production allocator changes belong to F3a. Unknown routes remain an explicit
limitation; they are not excluded to obtain a passing audit.

**F3b — Necessary narrow allocation patch.** Requires F3a outcome 2.
Allowed writes: patches/luau/compiler-allocation-context.patch,
build_support/LuauSource.zig, build.zig, build_support/NativeBuild.zig,
build_support/Profile.zig, docs/compiler-allocation-feasibility.md, and the
F3a allocation tests/wiring. Update build.zig.zon only if dependency identity or
packaged-file declarations actually change.
The patch header enumerates the exact inspected upstream files/symbols; it is
not authority for arbitrary Luau edits. Preserve existing compiler entry points
and default behavior. Exit: A01–A03 and relevant B/C tests pass, with complete
route coverage and no unexplained accounting difference.

**F4 — Fork delivery checkpoint.** Delivered for F0/F1 and the demonstrated F2
compiler exception defect. The replacement adds an artifact-owned config header
and a package-owned noexcept compiler landing point with distinct allocation-failure
and output-limit dispositions
and an inclusive output-copy ceiling. The accepted forward-repair scope is
`build.zig`, `src/Compiler.zig`, `src/compiler.{h,cpp}`, and
`tests/external_consumer/`; the native support artifact owns the wrapper and
publishes `luaz_compiler.h`. F3a/F3b compiler allocation accounting remains
conditional on a Reified charge-domain decision; the consumer retains its meter.
Write only docs/native-consumer.md and, when present,
docs/compiler-allocation-feasibility.md for the final tested facts, patch list,
and handoff. Repair code only within the responsible earlier scope.
Exit: the fork-only completion checks below pass. Reified adoption has not
occurred and is not claimed as part of this checkpoint.

## Focused tests and compatibility expectations

The existing luaz suite remains a regression baseline. New tests exercise the
package boundary and used primitives, not a second implementation of Reified's
invocation policy. Native test helpers may use ordinary protected Luau calls;
they are test scaffolding, not a published protected-execution framework.

| Test | Setup/action | Required observation and preserved state |
| --- | --- | --- |
| B01 exact_dependency_facts | Compare the base dependency and effective build facts with G0, and separately verify any explicitly reviewed fork-patch overlay. | Initial baseline matches exactly; declared later patches produce the reported new identity. No guessed version, hidden flag, or claim that changed bits retain the old fingerprint. |
| B02 native_consumer_build | Compile/link a small C++ consumer using only documented package artifacts, headers, and options; import the existing Zig module and any selected aliases. | One coherent VM/compiler linkage; aliases share underlying types/facts. No Reified source or personal checkout include path is needed. |
| B03 compiler_vm_smoke | With the pinned compiler, compile a tiny source returning a known scalar, load/call it under the ordinary native protected primitive, and free bytecode/state using the existing API contract. | Correct result and balanced ownership; compiler and VM are compatible. No new invocation API is exercised. |
| B04 profile_projection | Generate profile outputs twice; vary one covered fact; compare IDs and separately compare full fact records. | Stable outputs for identical facts; changed ID for changed fact. Only full-fact comparison reports a field difference. |
| C01 used_primitive_ownership | Exercise the actual used compiler/load path through success and supported syntax/load-error cases; release each returned allocation through its documented free path. | Existing statuses/bytes preserved and allocations freed exactly once. No claim that arbitrary hostile bytecode is verified. |
| C02 used_allocator_contract | If Reified uses the affected adapter, exercise alloc/grow/shrink/equal/free, overflow, exact boundary, and old-size rules from G0. | No-fail shrink/equal and preserved old allocation on refused growth; exact accepted charges where the primitive owns them. Unused adapters do not create work. |
| D01 objective_defect_regression | Run the recorded minimal failing case before the isolated fix and afterward, then its affected group. | Existing contract repaired; unaffected public behavior preserved. A missing new convenience abstraction is not a reproducer. |
| A01 independent_route_audit | Observe inventoried compiler paths and deliberately bypass the proposed hook in the isolated audit helper. | The observer catches the bypass independently of routed counters; all required routes and lifetimes are accounted for. Test instrumentation does not enter production artifacts. |
| A02 allocation_patch_failure_paths | Only for F3b, refuse each inventoried allocation route on normal and compiler-error paths, including retained returned buffers. | Failure follows the pinned compiler contract, exceptions clean up normally, and caller-context/free lifetimes remain valid. No VM longjmp or unaccounted allocation. |
| A03 allocation_compatibility | Compare required bound/charge/retention observations with G0 for the patched used entry. | No unexplained boundary, peak, status, or ownership difference. Any necessary change has an explicitly accepted new profile. |

Reified retains the tests for active-cycle rejection, module scope/aliases,
capability removal, serialization, final output commitment, instruction counts
as exposed by its invocation, and worker/process/OS behavior. Relevant attested
observations can constrain a fork patch, but those tests do not justify moving
their implementation or policy into luaz.

Do not regenerate baseline observations from the candidate to erase mismatches.
Classify a mismatch as incorrect package facts, a primitive defect, an audit or
fixture defect, or a required compatibility change. Preserve the reproducer and
old/new observations before changing the accepted profile.

## Fork completion before Reified adoption

F1 provides the package build steps used here. At the fork delivery boundary,
the selected pinned toolchain ran these normal non-incremental checks:

~~~sh
zig fmt --check build.zig build.zig.zon src tests
zig build -Doptimize=Debug -Dcodegen=false
zig build test -Doptimize=Debug -Dcodegen=false
zig build test-native-consumer -Doptimize=Debug -Dcodegen=false
zig build -Doptimize=ReleaseSafe -Dcodegen=false
zig build test -Doptimize=ReleaseSafe -Dcodegen=false
zig build test-native-consumer -Doptimize=ReleaseSafe -Dcodegen=false
zig build profile -Doptimize=ReleaseSafe -Dcodegen=false -Dvector-size=4
~~~

The candidate also ran the Debug and ReleaseSafe package, ordinary-test, and
native-consumer checks with codegen enabled, repeated the exact selected
profile command, and varied vector size. All checks passed. The generated
version-2 facts were stable for identical inputs and changed when vector size
changed. The final implementation revision and fingerprint are recorded in
`docs/native-consumer.md` and `tests/native_consumer/baseline.json`.

For this accepted G0 delivery, the implementation revision is
`e0274e1edd64d7245cfb0d87b7a294d98918cf62`, and the selected
ReleaseSafe/codegen-disabled/vector-size-4 profile fingerprint is
`8ed5b5cf419951d97e738404d6d01e0ed8ecf90e5212113c42c07ed5439ec477`.

The immutable implementation archive at
`https://github.com/oneopane/luaz/archive/e0274e1edd64d7245cfb0d87b7a294d98918cf62.tar.gz`
has independently reproduced Zig content hash
`luaz-0.6.0-w-BJfD6PCAAMXd_Qzhh2auiKU8Fh4yXcf9yRUYbLgW0o`.
This is the explicit changed Luaz package/profile compatibility boundary;
the selected profile fingerprint above and the unchanged Luau dependency hash
`N-V-__8AADetGAEcdQuTr-nq27CyCea3jnhtkeu-EYaA03Lb` identify different inputs.
This evidence receipt supersedes delivery receipts
`c5086fd4651998f4b31d2ef31f7dff1ab34a7d15`,
`90237af7448e85aaaa137d9ff99405302ca1b243`, and
`b34a9b1b496f885ced3628e07bcba088842b3f2a`; implementation revision
`cb7a31e28d0a7d33c3c4a37a92c31103d44cb95d`; and profile fingerprint
`522adcf844fbcfa96f7a02226093824b080273ab91295fc7bbe3966681712d9f`.
It retains current implementation `e0274e1edd64d7245cfb0d87b7a294d98918cf62`.
The exact pinned `zig fetch` command is recorded in `docs/native-consumer.md`
and the baseline.

The separate package at `tests/external_consumer` also passed `zig build test`
for Debug/ReleaseSafe with codegen disabled/enabled at vector size 4, plus
ReleaseSafe/codegen-disabled/vector-size-3. It consumes the emitted public
artifact include trees, including `luaz_config.h` and `luaz_compiler.h`, and
checks native execution and distinct compiler dispositions through both public
Zig modules. The exact 8192-space-plus-function source with a consumer-owned
4096-byte allocation budget returns `allocation_failed` with the independent
caller `meter_refused=true` latch and no live C++ allocations. An independent
simulated test-only backing failure returns `allocation_failed` with `meter_refused=false`;
the native outputs are null/zero and later calls recover. The package cannot
infer the caller's budget classification from allocation failure alone.
An allocation-budget sweep covers cleanup after successful allocations and
recovery; ordinary tests cover inclusive bytecode and diagnostic output-copy
bounds. Repeated profile output is identical, and changing vector size or using
`-Dcpu=generic` changes its fingerprint. This does not claim F3 route completeness.
Returned-copy malloc failure and internal-error branches are structurally reviewed,
not fault-injected; no production allocator or classifier hooks were added.
The ambiguous exhaustion alias is removed atomically from the fork's callers.

If F3a/F3b was required, also run the explicit isolated
zig build test-compiler-allocation step. Run the exact focused primitive checks
for each F2 patch and format-check every added Zig helper under build_support
or tools. Missing optional work is not a passing test; distinguish
"not required, with evidence" from "required and unresolved."

Verify the published artifact/header/module surface against the consumer smoke
test, compare generated facts with G0, and report the exact tested source/patch
identities, fingerprint, changed primitive contracts, commands/results, and any
accepted profile change. No automatic CI triggers are added.

The fork candidate checkpoint is complete: the dependency can be acquired,
built, linked, and fingerprinted coherently; the public `c`/`luaz` module
closure reaches one support implementation; the demonstrated compiler exception
and output-copy repair is delivered without a production allocator extension. If the
Reified profile owner later requires a new compiler hook, reopen F3a/F3b with a
reproducer and a charge-domain definition rather than treating this checkpoint
as evidence for one.

Only after this checkpoint should a separately authorized Reified workstream
adopt the package boundary and perform narrow extraction/adaptation inside
Reified. Its compact native invocation remains the owner of protected execution
and lifetime/accounting/result-copy discipline. Reified must run its own
behavioral/worker acceptance before switching the attested runtime. This plan
does not prescribe those migration steps, edit Reified, or declare adoption done.

## Deferred scope and current blockers

The candidate has no fork-local blocker. Reified adoption remains a separate
checkpoint: it must validate its worker behavior, protected lifetime boundary,
policy, containment, and profile observations against the selected package.

Do not implement these earlier proposals in this fork:

- A comprehensive public luaz execution engine or resumable-coroutine framework.
- Module exports surviving arbitrary frame teardown via a public
  ModuleFrame/tombstone lifetime system, or configurable module return/retry rules.
- General owned value graphs, projection/serialization frameworks, or arbitrary
  mediated host functions.
- Shared compiler-budget/session ownership objects, an invocation result arena,
  or a new protected state/ref ownership framework.
- Process-wide allocator overrides, worker protocols, policy allowlists, or
  wholesale migration of the Reified bridge.

A future extension requires a demonstrated consumer need, a small policy-neutral
primitive boundary, and its own scope/compatibility decision; this requirements
document alone does not authorize it. Existing Reified worker-local allocation
or containment mechanisms are outside the fork and are not changed by this plan.

The remaining handoff is not a fork-local blocker: Reified's profile owner must
still supply or accept the worker-specific source/build observations,
used-primitive/native-consumer map, and any required compiler-bound definition
before Reified adoption. The demonstrated compiler exception-boundary and
output-copy defect is delivered under F2. No additional primitive defect or
need for the F3b allocation-route patch is established by the candidate
evidence; those conditional accounting patches must not be scheduled as
mandatory work.

Actual candidate evidence includes the Luaz source/build graph, the
coordinator-accepted Luau 0.737 package identity, native consumer smoke tests,
generated build facts, and the commands recorded above. The supplied commit
mapping and G0 acceptance are recorded in the baseline and delivery documents;
the mapping was not independently resolved in this fork. Reified files and
the active Reified coding workspace were not edited or adopted.
