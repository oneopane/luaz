# Minimal luaz fork plan for Reified

Accepted strategy: a minimal fork followed by narrow, separately owned Reified
adoption/extraction. This replaces the earlier public execution-engine plan;
its proposed runtime abstractions and implementation increments are retired,
not outstanding obligations.

Status: preparation only. The exact attested baseline handoff G0 is missing,
so no production fork patch is ready to execute. This revision changes only
this plan; no source inspection, implementation, build, or test was performed.

## Evidence and responsibility

The sole source evidence is docs/reified-capability-requirements.md. It records
useful dependency/build discrepancies and primitive behavior, but its proposed
capability expansion is not execution authority under this strategy. Its links
and source citations were not followed. Paths below are proposed write scopes,
not claims about uninspected files.

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

## G0: exact attested baseline handoff

G0 is a blocking handoff owned by the recorded Reified profile/contract owner.
The luaz worker must not choose between the research note's Luau 0.702 pin and
its cited 0.737 bridge assumptions. Neither is sufficient evidence of the
currently attested runtime.

The concrete deliverable is the accepted luaz-attested-baseline-v1 bundle:

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

Luaz's preparation owner checks completeness and records adoption of the exact
accepted bundle digest. Unknown pin/build facts, missing observations, or an
unresolved required-bound definition keep G0 open. This plan does not authorize
Reified inspection or baseline acquisition by the fork worker.

Initially preserve the currently attested native behavior and accounting,
including active-cycle rejection in Reified. A source/build change produces
updated build facts; an unavoidable semantic/accounting change additionally
requires an explicitly accepted new execution profile. Do not hide either
change behind a language-version string.

The smallest implementation slice, once G0 is adopted, is F0: align the resolved
dependency pin and record its provenance. If it already matches, verify and
record that fact without churning the pin. Before G0, only this preparation and
the external evidence handoff can proceed; no separate public-API scaffolding
or schema-implementation project is necessary.

## Smallest coherent package boundary

F1 must make it possible to build Reified's existing native component against
the package without separately guessing Luau source lists, flags, or include
roots. Keep the existing luaz Zig module and existing working exports.

The required outputs are:

- The exact VM/compiler native artifact set, with required luaz-owned native
  support such as the existing assert linkage. Prefer existing artifact names
  when they already provide a coherent boundary. Add one canonical
  luaz_native artifact only if it removes otherwise duplicated consumer
  source/link assembly. Do not link a second VM or compiler copy.
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

**F0 — Exact pin and provenance.** Requires accepted G0.
Write only build.zig.zon when alignment is needed, plus
tests/native_consumer/baseline.json and tests/native_consumer/fixtures.zon to
record the adopted manifest/facts and selected neutral observations.
Exit: resolved source/patch identity matches G0 and provenance is reviewable.
This does not yet claim the consumer build is coherent.

**F1 — Coherent native package and smoke test.** Depends on F0.
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

**F4 — Fork delivery checkpoint.** Depends on F0/F1 and every required F2/F3
patch; skipped conditional work must have a recorded reason.
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

F1 provides the proposed local build steps used here. At the fork delivery
boundary, use the package's selected toolchain and run normal non-incremental
checks once:

~~~sh
zig fmt --check build.zig build.zig.zon src tests/native_consumer
zig build
zig build test
zig build test-native-consumer
zig build profile
~~~

If F3a/F3b was required, also run the explicit isolated
zig build test-compiler-allocation step. Run the exact focused primitive checks
for each F2 patch and format-check every added Zig helper under build_support
or tools. Missing optional work is not a passing test; distinguish
"not required, with evidence" from "required and unresolved."

Verify the published artifact/header/module surface against the consumer smoke
test, compare generated facts with G0, and report the exact tested source/patch
identities, fingerprint, changed primitive contracts, commands/results, and any
accepted profile change. No automatic CI triggers are added.

The fork checkpoint is complete when the dependency can be acquired, built,
linked, and fingerprinted coherently; every necessary used-primitive correction
is verified; and any required allocation extension has a proven bounded scope.
If the profile owner requires a new compiler hook and its audit is unresolved,
report that checkpoint as incomplete rather than claiming the bound.

Only after this checkpoint should a separately authorized Reified workstream
adopt the package boundary and perform narrow extraction/adaptation inside
Reified. Its compact native invocation remains the owner of protected execution
and lifetime/accounting/result-copy discipline. Reified must run its own
behavioral/worker acceptance before switching the attested runtime. This plan
does not prescribe those migration steps, edit Reified, or declare adoption done.

## Deferred scope and current blockers

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

Current blocker: G0 has not supplied the exact attested source/build facts,
used-primitive/native-consumer map, and required-bound definition. F0 is the
smallest next implementation patch after that handoff. No primitive defect or
need for F3b is established by the allowed evidence; those conditional patches
must not be scheduled as mandatory work.

Actual evidence reads: the complete capability requirements document, and this
implementation plan during revisions. No source code, repository history, other
documentation, external site, Reified file, build output, or test output was
inspected. Only this Markdown plan was edited.
