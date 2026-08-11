# AI Handoff

Updated: 2026-08-11

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

```text
v1 claim inventory/local-contract coverage:
  historically complete under N-155

final compositional model:
  reopened and incomplete

ROOTSCHED-001:
  model-supported at EC1; production refinement and composition remain open

RESIDENCY-001:
  model-supported at EC1 only for a fixed pre-admitted finite one-shot reference

RESIDENCY-DYN-001:
  open; Candidate-4 is a pre-full local checkpoint only. Its authority-disjoint
  capture boundary closes G1-G5 locally at EC0 after 153 hostile mutations,
  13 derived checks, and bounded Linux mechanism regressions; G6/G7 and full
  child/parent reachability plus commutation have not run

model-construction method:
  GPT-5.6 Sol maximum-effort architecture synthesis, hostile contradiction
  search, and minimality first; machine-readable checks next; TLA+ only after
  externally rooted K0 and semantic freeze

R11 machine IR / Formal 0150 / TLA+:
  unauthorized until complete F0-F3 and an executable externally rooted K0

Linux implementation:
  historical scaffold and experimental prototypes only

Monitor implementation:
  absent

protection/cost/deployment claims:
  false
```

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
`14ca4b5424f448462ff0868689f278f412ee43fe2d32d8372a8cacc78d4fd075`;
its strict validator passes 153 hostile mutations and 13 derived semantic
checks. The contract
requires a dedicated candidate UID, root-owned snapshot/plan/pipes/evidence,
pre-exec `clone3(CLONE_INTO_CGROUP | CLONE_PIDFD)`, nondelegated cgroup v2,
`cgroup.kill`, `populated 0`, guardian-owned supervisor failure cleanup, atomic
fsynced publication, and finalized-byte-only reduction.

Validation 0315 records the bounded implementation result. The strict C build,
launcher basic case, 10 launcher hostile cases, five hostile snapshot objects,
five-component supervisor smoke run, three guardian recovery cases, and three
authority-separated reducer cases all pass on `domainlease-dev`. A deterministic
read-only EROFS toolchain image exists at digest
`4fadeb77fe5019e0a9ea22ea43b79f07923f587fa90b9636164ab9e396de34ac`.
This closes G3-G5 locally without granting semantic or external credit. A clean
reviewed-commit install is next; the exact long capture G6 and reduction of its
real finalized bytes G7 remain absent.

Candidate-4 itself binds
strict nested schemas, exact action registries, producer/checker agreement,
reachable-action commutation membership, exact witness-count equality and
nonterminal-state bounds, raw component receipt bytes, claim predicates,
timeout classification, and bounded process-group cleanup. The historical fast
component receipts are still candidate-validator observations checked by the
same-UID outer runner; the new root mechanism fixtures do not retroactively make
them authority-disjoint evidence. The full campaign is `NOT_RUN`, so all three
full-only local claims remain `NOT_RUN`, seven refinement claims remain
`OPEN_REFINEMENT`, and F0, R11, K0/G0, protection, and model completion remain
false.

After the clean install, start and monitor the exact detached campaign with:

```sh
./capsched-models/validation/f0-c4-capture/start-candidate4-full-capture.sh
./capsched-models/validation/f0-c4-capture/monitor-candidate4-full-capture.sh RUN_ID 30
```

The monitor refreshes the percentage, units, evidence, and journal every 30
seconds. Stopping the monitor does not stop the VM capture.

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
git clone --recurse-submodules https://github.com/minto-dane/linux-cap.git
cd linux-cap/capsched
./capsched-ai/state/check-current-state.sh
python3 -I -S -B capsched-models/validation/validate-f0-supervisor-lts-v3.py
```

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

Required host tools are Git, Bash, jq, awk, `sha256sum`, Python 3, and the
Python `jsonschema` package with Draft 2020-12 support. The fast validator is
the restart smoke test. Do not launch `run-f0-supervisor-v3-full.sh` until the
authority-disjoint launcher contract and immutable capture are ready.
