# AI Handoff

Updated: 2026-08-12

This file is current-state context only. Detailed chronology is in
`state/events.jsonl`, `design/compact.md`, focused model notes, and Git history.
Do not load the full chronology during routine recovery.

## Mission

DomainLease-Linux aims to provide process-through-container Domain boundaries
whose escape under arbitrary Domain-local Linux kernel-context compromise
requires breaking the Domain Monitor or an explicitly exposed typed service
endpoint, comparable to hypervisor escape.

It also targets one logical OS/authority namespace across nodes and clusters,
with node-local enforcement and higher cost efficiency than VM-based isolation
for selected datacenter workloads.

## Current Verdict

The following projection is mechanically compared with `state/state.json`, the
assurance register, the capture gate contract, current exact inputs, and the
latest durable G6 disposition by `check-current-state.sh`.

<!-- CURRENT-STATE-PROJECTION-BEGIN -->
```json
{
  "schema_version": 1,
  "updated": "2026-08-12",
  "project_phase": "f0_v5_c4_g6_open_retry_eligible",
  "completion": {
    "v1_claim_inventory_complete": true,
    "local_contract_coverage": "substantial_not_exhaustive",
    "final_compositional_model_complete": false,
    "linux_implementation_complete": false,
    "monitor_implementation_complete": false,
    "protection_evidenced": false,
    "cost_efficiency_evidenced": false,
    "deployment_ready": false
  },
  "claim_statuses": {
    "ROOTSCHED-001": "model_supported",
    "RESIDENCY-001": "model_supported",
    "RESIDENCY-DYN-001": "open",
    "ENTRY-001": "open",
    "CODE-001": "open",
    "STATE-001": "open",
    "SVC-001": "open",
    "MGMT-001": "open",
    "CLUSTER-PART-001": "open",
    "COMPOSE-001": "open",
    "GRANULARITY-001": "open",
    "EVIDENCE-001": "contract_defined"
  },
  "candidate4": {
    "current_input_artifact": "dynamic-residency-f0-v5-supervisor-v3-candidate4-packed-history-repair-v1",
    "fast_validator_status": "COMPLETE_LOCAL_C4_FAST_REGRESSION_ONLY",
    "full_validator_status": "NOT_RUN_FOR_PACKED_HISTORY_REPAIRED_INPUTS",
    "hostile_case_counts": {
      "child": 284,
      "parent": 739,
      "runner": 44,
      "total": 1067
    },
    "capture_contract_sha256": "0a695417dcb6161d6f049431dea8755821e0c4600bf990f4822b274a1f924c6d",
    "closed_gates": [
      "C4CAP-G1-CONTRACT",
      "C4CAP-G2-HOSTILE",
      "C4CAP-G3-SUPERVISOR",
      "C4CAP-G4-PLATFORM",
      "C4CAP-G5-FAULTS"
    ],
    "remaining_gates": [
      "C4CAP-G6-CAPTURE",
      "C4CAP-G7-REDUCTION"
    ],
    "clean_install": {
      "status": "PASSED_FOR_PACKED_HISTORY_REPAIRED_INPUTS",
      "installed_source_commit": "14f6deecca06ce2f23b5faeb335100af952100ea",
      "installed_manifest_sha256": "f434c7d704e4d1c5ea6aac5024121436b70af8526b3280a7e596eb1bcebb4029",
      "current_inputs_installed": true,
      "readiness_record": "capsched-models/validation/f0-c4-g6-packed-history-retry-readiness-v1.json",
      "readiness_sha256": "d9066f01b06f541a95498fdc84c99a536bcd2666824169a010ab6a7dfb9a99a4"
    },
    "g6": {
      "gate_status": "OPEN",
      "retry_eligible": true,
      "complete_capture_available": false,
      "latest_completed_attempt": {
        "run_id": "candidate4-full-20260812T184826Z",
        "status": "RAW_CAPTURE_INCOMPLETE",
        "candidate_bytes_executed": true,
        "evidence_commit_available": true,
        "observation_record": "capsched-models/validation/f0-c4-g6-fourth-oom-incomplete-observation-v1.json",
        "observation_sha256": "9956feff9988d7cf1de4fb8bdfe1f92b770c6556e42f8aa2490feaee52a252b5"
      }
    },
    "g7": {
      "gate_status": "BLOCKED",
      "blocked_reason": "NO_COMPLETE_G6_CAPTURE",
      "real_reduction_run": false
    }
  }
}
```
<!-- CURRENT-STATE-PROJECTION-END -->

ADR-0012 and Analysis 0185 are authoritative. They preserve N-155 as a narrow
historical result and add the missing system requirements. Analysis 0187,
Formal 0147, and Validation 0288 close ROOTSCHED model support. Analysis 0188,
Formal 0148, and Validation 0289 close only finite-reference RESIDENCY model
support. ADR-0014 preserves dynamic and recurring residency as a separate
mandatory requirement.

ADR-0020 and Analysis 0217 preserve exact F0 v4 as rejected. Analysis 0218 and
Validation 0307 preserve the first F0 v5 machine draft as a separate parity
rejection. Rejected bytes remain negative regression evidence and are not
repaired in place. Analysis 0219 through 0225 then record the source-static,
linked-model, checked-evaluation, supervisor, and hostile-redesign sequence.

ADR-0024 is now the active construction decision. GPT-5.6 Sol maximum-effort
reasoning is the primary architecture engine, but has no approval, evidence,
promotion, or claim authority. Design conclusions must be materialized as typed
contracts, state/action/lifecycle semantics, failure cover, invariants,
counterexamples, assume/guarantee boundaries, and explicit nonclaims. TLA+ is a
terminal post-freeze validator: it may reject frozen semantics with a
counterexample, but cannot invent or weaken them.

Analysis 0226 and Validation 0313 retain the pre-full Candidate-4 boundary.
Analysis 0227 and Validation 0314 add the current authority-disjoint capture
boundary. The exact contract digest is
`0a695417dcb6161d6f049431dea8755821e0c4600bf990f4822b274a1f924c6d`;
its strict validator passes 155 hostile mutations and 14 derived semantic
checks. The contract
requires a dedicated candidate UID, root-owned snapshot/plan/pipes/evidence,
pre-exec `clone3(CLONE_INTO_CGROUP | CLONE_PIDFD)`, nondelegated cgroup v2,
`cgroup.kill`, `populated 0`, guardian-owned supervisor failure cleanup, atomic
fsynced publication, candidate-local OOM isolation from the trusted supervisor,
and finalized-byte-only reduction.

Validation 0315 records the bounded implementation result. The strict C build,
launcher basic case, 10 launcher hostile cases, five hostile snapshot objects,
five-component supervisor smoke run, three guardian recovery cases, and three
authority-separated reducer cases all pass on `domainlease-dev`. A deterministic
read-only EROFS toolchain image existed at digest
`4fadeb77fe5019e0a9ea22ea43b79f07923f587fa90b9636164ab9e396de34ac`.
This closes G3-G5 locally without granting semantic or external credit. The
clean install from commit `7895631...` succeeded and was used by the first
candidate-executing G6 attempt.

Validation 0317 and the historical `f0-c4-g6-retry-readiness-v1.json` bind the
first repaired successor environment: clean source commit `29d53f6c...`,
installed manifest `fe1c2b0d...`, read-only EROFS image `b3ed1553...`, EROFS
manifest `0db6f68c...`, one reuse regression, and three reducer boundary cases.
That record made the now-completed OOM attempt eligible; it is not current
readiness evidence.
The machine keeps `home-mount=none`; startup streams only the eight tracked
candidate inputs from a clean commit into root-owned, read-only VM-native
staging, separate from raw evidence.

Analysis 0229 and Validation 0318 record the first OOM attempt and its resource
isolation repair. Exact semantics remained unchanged: slot-backed states,
fixed-width CSR edges, finite caches, `OOMPolicy=continue`, and component-local
cgroups removed unit-wide OOM propagation. Clean commit `a956de2...` installed
that predecessor under manifest `dc3a7b23...` and made the now-completed fourth
attempt eligible.

Analysis 0230 and Validation 0319 record that fourth attempt. The trusted
supervisor survived the child component's second 7.5-GiB boundary and durably
committed `RAW_CAPTURE_INCOMPLETE`, proving the containment repair effective,
but the exact frontier still retained too much resident metadata. The successor
uses immutable persistent child/parent receipt histories and a fixed-width
open-addressed state index. Hash matches always invoke full ordered-sequence or
full-state equality; no quotient, pruning, digest-only identity, swap, semantic
change, or production hot-path work was introduced. Linux fast regression
passes 275/715/44 and the expanded memory policy passes 19 cases. Clean reviewed
commit `1fccaca...` is now installed under manifest `bd86819a...`; launcher,
snapshot, resource, memory, reducer-binding, toolchain-reuse, supervisor,
guardian, and reducer boundary regressions all pass against the installed TCB.

Analysis 0231 and Validation 0320 record the fifth attempt and its
successor. The child producer again reached 7.5 GiB with one PID and no output,
so the retained canonical state vector—not process or log fan-out—was the
remaining pressure. A frozen field-column exact store, fixed-width cursor
frontier, and exact unique-history index reproduce the same 750,007-state child
prefix with 34.5123% lower maximum RSS. Deeper parent exploration also exposed
two latent semantic contradictions: publication preparation could precede the
durable-store controller fence, and sealed owner-failure history was inferred
from artifacts that could change later. The parent now requires the fence and
signs a typed failure-time capsule/publication/generation/commitment/ack
snapshot. This parent change is explicitly semantic; it is not hidden under the
representation-only memory repair. Fast regression passes 275/730/44 and the
memory policy passes 24 cases. Clean reviewed commit `1c076a9...` was
reconstructed from SHA-256-verified bundle `b18352d...` in VM-native
root-owned storage, passed committed-state validation, and was installed under
manifest `75d17ee...`; launcher, snapshot, resource, memory, reducer-binding,
toolchain-reuse, supervisor, guardian, and reduction-boundary regressions all
pass against that installed TCB.

Analysis 0232 and Validation 0321 record the sixth attempt and current
successor. Run `candidate4-full-20260812T184826Z` again reached the isolated
7.5-GiB bound with one PID and zero output; the supervisor survived and
durably committed `RAW_CAPTURE_INCOMPLETE`. Profiling localized the retained
heap to Python receipt, string, and predecessor graphs rather than transition
semantics. The successor serializes only accepted histories into reversible
C-backed exact arenas, uses adaptive exact references, two bounded 8,192-entry
caches, and an 80%-load collision-safe state index. Old and new stores produce
identical child/parent prefix states, hashes, frontiers, targets, actions, and
ordered receipts. The historical 750,007-state child prefix falls from
539,049,984 to 252,858,368 bytes RSS; the 545,925-state parent prefix falls
from 519,569,408 to 224,624,640 bytes. Fast regression passes 284/739/44 and
the memory policy passes 30 cases. Clean reviewed commit `14f6dee...` was
reconstructed from SHA-256-verified bundle `3249567...` in VM-native root-owned
storage, passed committed-state validation, and was installed under manifest
`f434c7d...`; the complete short post-install suite passes and G6 retry is
eligible.

Candidate-4 itself binds
strict nested schemas, exact action registries, producer/checker agreement,
reachable-action commutation membership, exact witness-count equality and
nonterminal-state bounds, raw component receipt bytes, claim predicates,
timeout classification, and bounded process-group cleanup. The historical fast
component receipts are still candidate-validator observations checked by the
same-UID outer runner; the new root mechanism fixtures do not retroactively make
them authority-disjoint evidence.

Validation 0316 records the durable incomplete G6 result. The capture mechanism
completed two static components and then preserved a fail-closed
`RAW_CAPTURE_INCOMPLETE` disposition when `child-bundle-producer` rejected
`OBS-032-DESCENDANTS-EXIT:hidden_work`. Analysis 0228 and Validation 0317 retain
the exact counterexample and add its post-exit descendant/async order to the
fast child suite. The packed-history current input passes 284 child cases;
its full campaign has not run, so all three full-only local claims remain
`NOT_RUN`, seven refinement claims remain `OPEN_REFINEMENT`, and F0, R11,
K0/G0, protection, and model completion remain false.

The structured projection reports `retry_eligible: true`. Start and monitor the
exact detached packed-history retry with:

```sh
./capsched-models/validation/f0-c4-capture/start-candidate4-full-capture.sh
./capsched-models/validation/f0-c4-capture/monitor-candidate4-full-capture.sh RUN_ID 30
```

The monitor refreshes the percentage, units, evidence, and journal every 30
seconds. Stopping the monitor does not stop the VM capture.

The first G6 start attempt `candidate4-full-20260811T203907Z` stopped before the
first progress receipt and before candidate launch because the toolchain sealer
tried to reapply directory metadata to an already mounted read-only EROFS root.
No evidence or commit marker was created. The reuse path now skips mountpoint
metadata mutation, `F0_C4_TOOLCHAIN_REUSE_PASS` binds the unchanged image digest,
and the detached starter waits for a real progress receipt before reporting
success.

The second attempt `candidate4-full-20260811T210659Z` did execute candidate
bytes and finalized incomplete. It must never be resumed, combined with a new
run, reduced as positive evidence, or described as `NOT_RUN`. Its clean
repaired successor install enabled only the third attempt.

The third candidate-running attempt `candidate4-full-20260811T223707Z` reached the child
component's 7.5-GiB cgroup limit. The installed unit's `OOMPolicy=kill` then
terminated the trusted supervisor along with the candidate. The separate root
guardian proved the component subtree empty and durably published
`GUARDIAN_INCOMPLETE_PUBLISHED`; candidate bytes are not positive-eligible and
G7 remains blocked. Its resource-repaired install enabled only the next attempt.

The fourth attempt `candidate4-full-20260812T134610Z` used that isolated TCB.
`child-bundle-producer` again reached 7.5 GiB, but the supervisor remained alive,
drained the component, and committed `RAW_CAPTURE_INCOMPLETE`. The successor
persistent frontier is clean-installed and its full short mechanism recheck
passes. The next action is a new detached G6 run; G7 remains blocked unless
that run publishes a complete committed capture.

The fifth attempt `candidate4-full-20260812T170823Z` used the persistent
frontier TCB. It finalized `RAW_CAPTURE_INCOMPLETE` at the child memory limit
while preserving the supervisor. Its compact-state successor was then
clean-installed and enabled the sixth attempt.

The sixth attempt `candidate4-full-20260812T184826Z` used that compact-state
TCB and again finalized `RAW_CAPTURE_INCOMPLETE` at 7.5 GiB. The exact packed
history successor is now clean-installed and has passed the complete short
suite; a fresh G6 retry is eligible, while G7 remains blocked.

## Current Git State

Project-control work is isolated on:

```text
branch:
  codex/reasoning-first-model-completion

semantic baseline before this state update:
  dd20d07bccab4366d85802fb5ae0e03de720cae2

reviewed prior lineage:
  75e34749b94af52338085caced75c44c70f0a1b4

stable main:
  4aa3f5427e1d3649d4de1cadcbcb8f268fb932a9

checkpoint commit:
  resolve from the branch or the superproject gitlink; it cannot be embedded
  in the bytes from which its own Git object ID is derived
```

ADR-0023 records that the GitHub superproject, project-control/model repository,
and patch queue are intentionally public by owner decision. Public visibility
is not a blocker.
Credentials, private keys, tokens, and private operational data must never be
committed.

Sibling Linux source:

```text
local branch:      capsched-linux-l0
exact handoff ref: codex/linux-l0-handoff-20260810
fork remote:       https://github.com/minto-dane/linux.git
HEAD:              74311ca1ac4937e0e62f1e0f6a3e5bfa4fc77d6f
tree:              54f685aad94f28f0027cbba18cf5e29aadce234a
base:              4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
fetched upstream/master:
        a7c7074b58d28c4206d666a12aa2e33447b3c581
```

Sibling patch queue:

```text
branch: codex/replay-clone-portability
HEAD:   3fe92f5f252cfc8e6d6e39914237a8f96d4cd79f
replay base:
        4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
replay endpoint:
        6537a57d3d4bcf61d92b0081275081d69c5ff2fd
```

The replay endpoint is the historical L0 patch-series result. It is not the
later experimental Linux head `74311ca1...`. That exact head is published at
`codex/linux-l0-handoff-20260810`; a fresh machine can either replay the
historical queue or fetch the later experimental checkpoint exactly. Neither
is a production protection boundary.

The patch-queue HEAD above adds only the intentional-public/secret-free README
policy after `16bb080...`; the replay base, patch bytes, and replay endpoint are
unchanged.

## Reopened Requirements

```text
ROOTSCHED-001
  Monitor-owned root handoff and guaranteed-Domain progress under hostile Linux

RESIDENCY-001
  fixed pre-admitted finite global identity to bounded residency reference

RESIDENCY-DYN-001
  dynamic admission/rejection, recurring service, churn/overflow, and rekey

ENTRY-001 / CODE-001
  privileged entry/return, MemoryView, stack, TLB, and shared executable integrity

STATE-001 / SVC-001 / MGMT-001
  exhaustive mutable-state ownership and bounded service/management compromise

CLUSTER-PART-001
  partitions, clocks, expiry, fencing, migration, and namespace recovery

COMPOSE-001
  explicit assume/guarantee and refinement composition

GRANULARITY-001
  complete-path security and cost envelope for process-through-container Domains

EVIDENCE-001
  validator-owned immutable evidence capsules
```

## R6 Status

R6 is retained as a bounded local selector research candidate. Its 64 slots are
not a node-wide Domain limit. The accepted interpretation is at most a per-CPU
Linux policy projection with stable DomainID/epoch and Monitor-owned
slot-generation fencing; it is neither the global registry nor authority.

R6 E4 may be reproduced as an engineering experiment, but it is paused as an
architecture, assurance, performance, or cost promotion gate. Existing exact
Git objects remain useful. Positive promotion credit needs revalidation under
ADR-0013 if R6 remains architecturally relevant.

## Evidence Status

ADR-0013 and Analysis 0186 define Evidence Capsule v1:

```text
capture bytes first
seal an immutable manifest
validate only the captured bytes
recompute summaries from retained raw evidence
bind approval to the capsule id
```

The v1 schemas, capture-first Collector, structural Verifier, and bootstrap
mutation fixtures exist under `validation/evidence-capsule-v1/`. Validation
0287 passes six positive and 32 fail-closed cases. ROOTSCHED and RESIDENCY are
the first two claim-specific consumers. Each Validator rechecks captured bytes
and raw TLC results, reruns captured configurations only after trust checks
pass, and permits only its own Open-to-Model-supported transition.

```text
run:       20260809T043801Z-rootsched-ec1
capsule:   d805b92acee2bca93a965e63925f7f48b8bf8d518043b0c55edf9ca3a3210abe
result:    99b63b6cf050b972ae1a218e2ff7adf4de9e66f490b56f83b5d55508f301ba87
decision:  3617a503b103a76e1e4a7b5e90905041f221c94d73b658ba2af901e24a261958

RESIDENCY run:
           20260809T060117Z-residency-ec1-deterministic
capsule:   efecb20ac9132caf6e20e6a8faac47704fad6429a48416910be62615163e5314
result:    9f4156a60746587a5e6e30583be5fdeeae594655d5babc44f78bc1919dea4e93
decision:  534cf2c87219962a23ae3432b4bf0a22ce2429adda85984be333a7f7dfc224fb
```

This is EC1 model evidence, not Monitor or Linux implementation evidence.
Historical migration, successor claim Validators, EC2 independence, and EC3
reproduction remain open. Codex Security plugin completion is not a project
gate, and its non-sealed diagnostic run is not assurance evidence.

## ROOTSCHED Result

The accepted reference contract is a fixed-frame Monitor-owned lower bound:

```text
management reservation -> guaranteed Domain 1 -> guaranteed Domain 2
                       -> best-effort slack
```

The Monitor owns admission, epochs, root budget/lease/timer, reserved-slot
selection, tokens, and authoritative handoff. Hostile Linux may propose hints
and schedule within the active Domain, but cannot mint, extend, or suppress
root authority. The model establishes bounded recurring service for admitted
guaranteed Domains under its explicit fairness assumptions. It does not select
the production scheduler, prove useful application progress, establish a
wall-clock bound, or support protection/performance/cost claims.

## RESIDENCY Result

The accepted reference separates global Domain identity from bounded per-CPU
residency and from exact activation authority. The Monitor owns the global
registry, current epochs, CPU incarnations, resident bindings/generations,
trusted drain references, guaranteed handoff, and management recovery path.
Linux locality and runnable state remain untrusted hints.

The finite model places five global ordinary Domains, three of them guaranteed,
over two replaceable slots, permits ordinary replicas, fences explicitly exclusive
migration source-first, drains CPU authority across hotplug, and drains all
replicas before revoke epoch commit. Deterministic producer and Validator runs
reproduce four safe state spaces and 22 targeted failures. A prior parallel
run was rejected fail-closed for a nonreproducible search-depth oracle and is
retained without claim credit.

This model starts with every Domain admitted and issues one request per
guaranteed Domain. It does not choose dynamic admission/rejection,
request/cancellation/coalescing semantics, bounded churn/overflow work, a
generation-saturation rekey protocol, or a production directory/replacement
algorithm. Those remain Open as `RESIDENCY-DYN-001`. Physical shadow backing,
MemoryView/TLB entry, root-budget conservation, Monitor/Linux implementation,
wall-clock, protection, performance, cost, and cluster claims also remain
open.

## Next Order

1. Implement the accepted v1 root-owned, dedicated-UID, nondelegated cgroup v2
   supervisor plus its service-manager guardian. Keep the implementation small,
   descriptor-relative, fail-closed, and unable to decide claims.
2. Run the root-owned feature/authority probe and hostile escape, daemonize,
   fork-bomb, timeout, output-flood, supervisor-crash, and storage-mutation
   fixtures. G3-G5 must all pass before full execution.
3. Capture exact Candidate-4 inputs, launch the full bounded child/parent
   reachability and declared-commutation campaign detached, then independently
   reduce retained raw evidence in a later session.
4. Disposition the three full-only local claims without changing any external
   claim. A local pass still does not authorize F0 or external R11 review.
5. Continue GPT-primary synthesis, contradiction search, and minimality through
   F1 claim semantics, F2 platform/threat refinement, and F3 external
   policy/generators/mutations/proof/trust; then obtain an independently rooted
   K0/G0 decision over one immutable F0-F3 source set.
6. Only after semantic freeze, materialize Formal 0150/D0-D17/W0-W12 and
   translate the frozen semantics to TLA+/other backends for final
   counterexample/proof validation and claim-specific evidence.
7. Compose `ENTRY-001 + CODE-001`, then state/service/management, cluster
   partitions, composition, and the complete-path cost contract.

## Do Not Do Yet

```text
do not add behavior-changing Linux scheduler enforcement
do not promote R6 as the node-wide architecture
do not treat Linux runqueue or selector state as root availability authority
do not claim final model completion
do not claim monitor-backed protection or cost efficiency
do not accept positive producer summaries without a captured validator capsule
do not externally review or repair the rejected R11 G0 v1 snapshot in place
do not start F1 before the exact F0 package survives local hostile closure
do not construct Formal 0150 or TLA+ before an externally accepted epoch-2 K0
```

## Long-Running Work

For TLC runs, symbolic checking, full kernel builds, QEMU/sanitizer matrices, or
measurements expected to outlive an interactive session:

1. Capture and seal exact inputs.
2. Launch through the detached job mechanism.
3. Record the launch identity and stop the interactive session.
4. Validate the completed result independently in a later session.

Do not poll a healthy long-running job merely to keep a chat session alive.

## Recovery Read Order

1. `state/state.json`
2. this file
3. `../capsched-models/analysis/0185-final-goal-conformance-and-compositional-model-reopen.md`
4. `../capsched-models/plans/0006-final-compositional-model-completion-plan.md`
5. `../capsched-ai/decisions/ADR-0020-close-f0-before-policy-with-total-actions-batches-and-morphisms.md`
6. `../capsched-models/analysis/0226-dynamic-residency-f0-v5-supervisor-v3-candidate4-pre-full-local-closure.md`
7. `../capsched-models/validation/0313-dynamic-residency-f0-v5-supervisor-v3-candidate4-pre-full-local-closure.md`
8. `../capsched-models/policy/r11/epoch2/foundation-v5/README.md`

Read Analysis 0188 and Validation 0289 as the immediate refinement baseline.
ROOTSCHED is closed reference context. Finite RESIDENCY is a lower-layer
contract for, not a substitute for, the next dynamic-residency work queue.

Use `design/compact.md` only for historical detail.

## Fresh Clone Recovery

Preferred public recovery path:

```sh
container machine run --root -n domainlease-dev --workdir / -- \
  git clone --recurse-submodules \
  --branch codex/reasoning-first-model-completion \
  https://github.com/minto-dane/linux-cap.git /opt/domainlease-recovery
container machine run --root -n domainlease-dev \
  --workdir /opt/domainlease-recovery/capsched -- \
  ./capsched-ai/state/check-current-state.sh
container machine run --root -n domainlease-dev \
  --workdir /opt/domainlease-recovery/capsched -- \
  python3 -I -S -B capsched-models/validation/validate-f0-supervisor-lts-v3.py
```

On a native Linux host with procfs, run the two inner commands directly.
macOS is not a valid runner-lifecycle test platform even when its Python and
shell syntax happen to accept the files. The Apple Container machine keeps
`home-mount=none`; recovery source and raw evidence stay on separate VM-native
roots.

The model-only recovery path above does not need a full Linux checkout. Fetch
the exact experimental Linux checkpoint only when source analysis or prototype
work resumes:

```sh
cd linux-cap
git clone --branch codex/linux-l0-handoff-20260810 \
  https://github.com/minto-dane/linux.git linux
test "$(git -C linux rev-parse HEAD)" = \
  "74311ca1ac4937e0e62f1e0f6a3e5bfa4fc77d6f"
test "$(git -C linux rev-parse 'HEAD^{tree}')" = \
  "54f685aad94f28f0027cbba18cf5e29aadce234a"
```

Required Linux-environment tools are Git, Bash, jq, awk, `sha256sum`, Python
3, and the Python `jsonschema` package with Draft 2020-12 support. The fast
validator is the restart smoke test. Do not launch
`run-f0-supervisor-v3-full.sh` directly; use the authority-disjoint capture
launcher only when the canonical projection marks G6 retry eligible.
