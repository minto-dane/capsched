# Analysis Index

Updated: 2026-08-11

## Current Analysis Notes

| ID | Status | Title |
| --- | --- | --- |
| 0001 | Draft | Initial Linux Source Map |
| 0002 | Draft | Scheduler Execution Spine |
| 0003 | Draft | Task Lifecycle and Identity |
| 0004 | Draft | Existing Resource Controls and Compatibility |
| 0005 | Draft | Async Provenance Risk Map |
| 0006 | Draft | Cluster Domain Capability Mapping |
| 0007 | Draft | Capability Invariant Matrix |
| 0008 | Draft | Policy Front-Ends and Capability Issuance |
| 0009 | Draft | Mutable Kernel State Boundary Map |
| 0010 | Draft | Dangerous Surfaces and Service Domains |
| 0011 | Draft | Network Socket Endpoint Map |
| 0012 | Draft | io_uring Registered Resource Provenance |
| 0013 | Draft | BPF Programmable Policy Boundary |
| 0014 | Draft | Scheduler Topology and Cluster Partition Map |
| 0015 | Draft | Endpoint Async Linux Attachment Map |
| 0016 | Updated | Device IOMMU and Queue Lease Map |
| 0017 | Draft | MM Allocator and Page Cache Domain State Map |
| 0018 | Draft | Protection Claim Evidence Map |
| 0019 | Draft | Wakeup, Enqueue, and Runnable-State Coverage |
| 0020 | Completed | QEMU ftrace and Symbol Eligibility for Slice 0C |
| 0021 | Draft synthesis | Slice 0C Observation Synthesis and Hook-Placement Constraints |
| 0022 | Draft methodology, revised after critical review | Behavior Tagging Methodology for Mechanical Design Selection |
| 0023 | Review complete, schema v2 required | Critical Review of Behavior Tagging Before Schema Finalization |
| 0024 | Accepted analysis direction | Invariant-Driven Design and the Role of Tags |
| 0025 | Draft state machine, source-only refresh applied | Linux Scheduler Authority State Machine |
| 0026 | Draft obligation matrix, source-only refresh applied | Scheduler Hook Proof Obligation Matrix |
| 0027 | Draft schema and v2 retagging complete for gap analysis | Schema v2 Derived from the Scheduler Authority Model |
| 0028 | Draft source map, source-only refresh applied | Tick and Runtime Budget Source Map |
| 0029 | Draft source map | Fork, Clone, Exec, and Exit Identity Propagation Map |
| 0030 | Draft boundary map | TASK_WAKING Failability Boundary Map |
| 0031 | Draft dependency map with TLC-backed design filter | F1 Admission-Freeze Data Dependencies |
| 0032 | Draft source map with TLC-backed design filter | Block, Wait, and Register Authority Preparation |
| 0033 | Draft lifecycle map with TLC-backed design filter | Task-Local Resumable-Run Lifecycle |
| 0034 | Draft carrier map with TLC-backed design filter | Workqueue and kthread_work BudgetTicket Carrier |
| 0035 | Draft endpoint map with TLC-backed design filter | Shared Futex Endpoint Authority |
| 0036 | Draft dependency-authority map with TLC-backed design filter | PI, RT, and ww_mutex Priority Donation Authority |
| 0037 | Draft placement map with TLC-backed design filter | Placement Refresh, Affinity, cpuset, Hotplug Authority |
| 0038 | Draft monitor-fast-path map with TLC-backed design filter | Same-Domain Monitor Fast Path and Budget Freshness |
| 0039 | Draft budget map with TLC-backed design filter | Root Budget, SchedContext Budget, and NO_HZ Overrun Boundary |
| 0040 | Draft selected-state map with TLC-backed design filter | Class-Specific Selected-State Boundary |
| 0041 | Draft endpoint semantics map with TLC-backed design filter | Wider Endpoint Capability Semantics |
| 0042 | Draft exec boundary map with TLC-backed design filter | Exec Generation and Inherited Endpoint Semantics |
| 0043 | Draft inheritance-class map with TLC-backed design filter | Post-Exec Resource Inheritance Classes |
| 0044 | Draft trace-only coverage map | Post-Exec Resource Trace-Only Coverage Map |
| 0045 | Draft design boundary | Workqueue Internal Redesign Boundary |
| 0046 | Draft taxonomy | Workqueue Origin Taxonomy |
| 0047 | Draft source-inventory map | drivers/net Workqueue Origin Map |
| 0048 | Draft representative source map | usbnet Workqueue Source Map |
| 0049 | Draft representative Ethernet source map | e1000e QueueLease Source Map |
| 0050 | Draft settlement semantics with TLC-backed design filter | Aggregate QueueLease Settlement Semantics |
| 0051 | Draft observation-only plan | Linux Queue/Descriptor Ledger Observation Plan |
| 0052 | Draft modern NIC source map | Intel ice Modern NIC QueueLease Source Map |
| 0053 | Draft revoke source map | Intel ice Modern NIC Revoke Source Map |
| 0054 | Draft source map with model gate | Monitor IRQ Route Invalidation Source Map |
| 0055 | Draft source map with model gate | Monitor DMA/IOMMU and MemoryView Invalidation Source Map |
| 0056 | Draft source map with model gate | XSK and Page-Pool Quarantine Source Map |
| 0057 | Draft source map with model gate | Representor Lower QueueLease Source Map |
| 0058 | Draft source map with model gate | ICE ServiceWork Carrier Source Map |
| 0059 | Draft source map with model gate | ICE VF Mailbox Queue Carrier Source Map |
| 0060 | Draft source map with model gate | ICE VF Epoch and Handoff Source Map |
| 0061 | Draft architecture map with model gate | Modern NIC HyperTag Interface and Service Domain Split |
| 0062 | Draft implementation-readiness map with model gate | Modern NIC HyperTag Readiness Probe Map |
| 0063 | Draft observation ledger | Modern NIC HyperTag Observation Ledger |
| 0064 | Draft external-gap map with model gate | Local Domain Device Lease Compilation |
| 0065 | Draft observation contract | Local Domain Device Lease Observation Contract |
| 0066 | Draft admission protocol with model gate | Local Domain Device Lease Admission Protocol |
| 0067 | Draft interface boundary with model gate | Local Monitor Admission Interface Boundary |
| 0068 | Draft choice gate with model | Local Monitor Admission Carrier and Receipt Storage |
| 0069 | Draft semantic ABI candidate with model gate | Local Monitor Admission ABI Semantics Candidate |
| 0070 | Draft implementation-facing sketch comparison with model gate | Local Monitor Admission Carrier Sketch Comparison |
| 0071 | Draft reference ABI sketch with model gate | Direct-Call Reference ABI Sketch |
| 0072 | Draft throughput refinement sketch with model gate | Monitor-Owned Ring Refinement Sketch |
| 0073 | Draft combined carrier plan with model gate | Combined Direct-Call and Ring Admission Carrier Plan |
| 0074 | Draft implementation-facing carrier requirements with model gate | Direct-Call Carrier Requirements Gate |
| 0075 | Draft semantic schema candidate with model gate | Direct-Call Semantic Schema and Compatibility |
| 0076 | Draft no-code attachment/readiness map with model gate | Direct-Call Attachment Readiness Map |
| 0077 | Draft no-code inventory contract with model gate | Direct-Call Trace/Source Inventory Contract |
| 0078 | Draft direct-call gap closure design with model gate | Direct-Call Gap Closure Design |
| 0079 | Draft monitor-owned receipt schema with model gate | Direct-Call Monitor Receipt Schema |
| 0080 | Draft source-only map | Direct-Call Receipt Consumer Source Map |
| 0081 | Draft source-only async carrier map | Direct-Call Async Workqueue and io_uring Source Map |
| 0082 | Draft no-patch lifetime table | Direct-Call Async Carrier Lifetime Table |
| 0083 | Accepted no-behavior API direction | Direct-Call Async Carrier API Direction |
| 0084 | Draft refinement model input | Direct-Call Workqueue Adapter Refinement |
| 0085 | Draft refinement model input | Direct-Call io_uring Adapter Refinement |
| 0086 | Current-source review complete; no new Linux patch recommended | Linux Upstream Drift and Maintenance Review |
| 0087 | Automation contract drafted and executed | Linux Source-Drift Automation and Model-Freshness Gate |
| 0088 | Target selected for source-only refresh | Linux Source-Map Refresh Target Selection |
| 0089 | Draft model gate with TLC-backed design filter | Scheduler Authority Refinement Gate |
| 0090 | Draft model gate with TLC-backed design filter | Runtime Charge Subject Map |
| 0091 | Draft model gate with TLC-backed design filter | Scheduler Server Ticket Map |
| 0092 | Draft trace-only coverage gate with TLC-backed design filter | Runtime Coverage Gate |
| 0093 | Draft monitor-root budget event model with TLC-backed design filter | Monitor Root Budget Timer |
| 0094 | Draft model gate with TLC-backed design filter | Server Epoch Relation |
| 0095 | Draft model gate with TLC-backed design filter | Deadline CBS/GRUB Compatibility |
| 0096 | Draft model gate with TLC-backed design filter | F1 Admission-Freeze Refresh |
| 0097 | Draft integration model gate with TLC-backed design filter | Scheduler Authority Integration Gate |
| 0098 | Draft architecture-substrate model gate with TLC-backed design filter | Monitor Timer Architecture Substrate |
| 0099 | Draft integration model gate with TLC-backed design filter | Placement, Affinity, and Hotplug Integration Gate |
| 0100 | Draft hook-placement model gate with TLC-backed design filter | Final Run/Move Revalidation Hook Placement Gate |
| 0101 | Draft model gate with TLC-backed design filter | Final Deny Retry and Ineligibility Gate |
| 0102 | Draft model gate with TLC-backed design filter | Task FrozenRun Lifetime and Locking Gate |
| 0103 | Draft integration model gate with TLC-backed design filter | Lifecycle Identity Propagation Integration Gate |
| 0104 | Draft integration model gate with TLC-backed design filter | Exit/Revoke Pending Authority Drain Gate |
| 0105 | Draft completion gate with TLC-backed design filter | Model Completeness Ledger Gate |
| 0106 | Draft model gate with TLC-backed design filter | TCB Boundary Gate |
| 0107 | Draft model gate with TLC-backed design filter | Side-Channel and Co-Tenancy Policy Gate |
| 0108 | Draft model gate with TLC-backed design filter | Evaluation Contract Gate |
| 0109 | Final model-only completion gate | Final Model Completeness Ledger |
| 0110 | Accepted terminology gate | Terminology Freeze and Rename Risk Review |
| 0111 | Covered by implementation gate | SchedExecLease L0 Readiness and Vertical Slice Design |
| 0112 | Design-only source verification | SchedExecLease P3/P4 Source-Verified Design Boundary |
| 0113 | Design-readiness audit; not complete | Implementation-Ready Completion Audit |
| 0114 | Source-verified design boundary | sched_ext, Core Scheduling, and Proxy Coverage Boundary |
| 0115 | Source-verified B2 design constraint | Bounded Retry and Ineligibility Source Design |
| 0116 | Design-only negative validation plan | Negative Denial Validation Plan |
| 0117 | Design-only path classification with TLC-backed gate | Scheduler Path Classification for P5 |
| 0118 | Design-only claim ledger gate with TLC-backed overclaim rejection | Implementation Claim Ledger Gate |
| 0119 | Design-only implementation-reopen drift gate with fresh upstream observation | Implementation Reopen Upstream Drift Gate |
| 0120 | Final design-ready audit passed; implementation unapproved | Final Implementation-Ready Audit |
| 0121 | P3 overclaim review passed; only placement-only no-behavior compatibility may be claimed | SchedExecLease P3 Overclaim Review |
| 0122 | P4 pre-entry gate passed for allow-all/no-denial scope; P5 denial remains blocked | SchedExecLease P4 Pre-Entry Risk Gate |
| 0123 | P4 paused pending scoped drift closure and anchor evidence hardening | SchedExecLease P4 Pre-Implementation Critical Audit |
| 0124 | P4 candidate-scoped drift blocker closed; implementation still paused pending anchors | Candidate-Scoped Drift Closure Gate |
| 0125 | P4 anchor manifest complete; implementation still paused pending observability and helper proof | SchedExecLease P4 Anchor Manifest |
| 0126 | Static final-run anchor observability complete; runtime coverage remains unproven | SchedExecLease P4 Static Final-Run Observability |
| 0127 | P4 allow-all/no-denial helper proof complete; P4 implementation still not applied | SchedExecLease P4 Allow-All Helper Proof |
| 0128 | P4 allow-only compatibility slice closed after final overclaim/security review; P5 remains blocked | SchedExecLease P4 Final Overclaim and Security Review |
| 0129 | P5 readiness refreshed after P4; denial remains blocked | SchedExecLease P5 Readiness Refresh After P4 |
| 0130 | P5A scope decomposed; no Linux implementation approved | SchedExecLease P5A Scope Proposal |
| 0131 | P5A0 no-behavior infrastructure proposal recorded; no Linux patch approved | SchedExecLease P5A0 No-Behavior Infrastructure Proposal |
| 0132 | P5A0.E prepatch evidence recorded; no Linux patch approved | SchedExecLease P5A0.E Prepatch Evidence |
| 0133 | P5A0.P1 patch plan recorded; no Linux patch approved | SchedExecLease P5A0.P1 No-Behavior Patch Plan |
| 0134 | Subagent-assisted audit; P5A-R/M remain blocked and P5A0.P1 full acceptance evidence is enumerated | SchedExecLease P5A-R/M and P5A0.P1 Acceptance Audit |
| 0135 | Source-map validated; P5A-R remains blocked pending picker-visible CFS ineligibility | SchedExecLease P5A-R CFS Picker Eligibility Source Map |
| 0136 | Formal gate recorded; P5A-R behavior remains unapproved pending source-shape and hierarchy settlement | SchedExecLease P5A-R Picker Ineligibility Gate |
| 0137 | Source-shape gate recorded; EEVDF return dominance checked but hierarchy settlement remains open | SchedExecLease P5A-R EEVDF Return Dominance |
| 0138 | Source/formal gate recorded; group hierarchy settlement checked at pre-code level | SchedExecLease P5A-R Group Hierarchy Settlement |
| 0139 | Source/formal gate recorded; ordinary-CFS-only cross-path exclusion/settlement checked | SchedExecLease P5A-R Cross-Path Exclusion/Settlement |
| 0140 | Source/formal gate recorded; P5A-R overhead/layout constraints checked | SchedExecLease P5A-R Overhead and Layout Gate |
| 0141 | Source/formal validation-plan gate recorded; future P5A-R negative tests enumerated | SchedExecLease P5A-R Negative Validation Plan |
| 0142 | Final audit passed for ordinary-CFS-only patch drafting; behavior remains unaccepted | SchedExecLease P5A-R Implementation-Ready Audit |
| 0143 | Upstream/source-shape refresh passed; P5A-R direct scheduler shape fresh for 0009 draft | SchedExecLease P5A-R Upstream Drift Source-Shape Refresh |
| 0144 | Test-only negative runtime harness design recorded; no Linux patch approved | SchedExecLease P5A-R 0009 Negative Runtime Harness |
| 0145 | 0012 boundary review recorded; synthetic QEMU claim only, production acceptance blocked | SchedExecLease P5A-R 0012 Acceptance Boundary |
| 0146 | P5A-R2 selector direction recorded; production path moves away from post-filter fallback | SchedExecLease P5A-R2 Selector Direction |
| 0147 | P5A-R2 selector model gate defined; EEVDF-compatible min-pickable summary required | SchedExecLease P5A-R2 Selector Model Gate |
| 0148 | P5A-R2 invalidation source map defined; enqueue/dequeue-only summary freshness rejected | SchedExecLease P5A-R2 Invalidation Source Map |
| 0149 | P5A-R2 invalidation semantics gate defined; stale/refreshing/blocked summaries cannot be picker proof | SchedExecLease P5A-R2 Invalidation Semantics Gate |
| 0150 | P5A-R2 selector patch-plan gate defined; 0012 fallback extension rejected for production | SchedExecLease P5A-R2 Selector Patch Plan |
| 0151 | P5A-R2 minimal source sketch defined; EEVDF fresh-summary placement sketched without Linux patch approval | SchedExecLease P5A-R2 Minimal Source Sketch |
| 0152 | P5A-R2 layout/overhead evidence plan defined; hot-field and cost claims gated before any behavior patch | SchedExecLease P5A-R2 Layout and Overhead Evidence Plan |
| 0153 | P5A-R2 no-behavior layout probe patch plan defined; 0013 reserved for build-only probe infrastructure | SchedExecLease P5A-R2 Layout Probe Patch Plan |
| 0154 | Literal U64_MAX vruntime sentinel rejected; explicit validity plus wrap-aware minimum required | SchedExecLease P5A-R2 Vruntime Sentinel Gate |
| 0155 | Source/locking update closure mapped; shared epoch, budget, monitor, and selector fanout remains an implementation blocker | SchedExecLease P5A-R2 Summary Update-Closure Map |
| 0156 | Conservative versioned global invalidation fence selected; generation mismatch blocks picker trust before all-rq rebuild fanout | SchedExecLease P5A-R2 Versioned Global Invalidation Fence |
| 0157 | Global-fence layout/rebuild evidence plan fixes hot-structure growth envelopes and 25us/50us rq-lock rejection limits | SchedExecLease P5A-R2 Global-Fence Layout/Rebuild Evidence Plan |
| 0158 | Patch 0014 reserved for a one-file, 51-symbol expanded default-off probe; candidate fields and behavior remain forbidden | SchedExecLease P5A-R2 Expanded Layout Probe Patch Plan |
| 0159 | E2 constrained to a disposable four-field, default-off arm64 layout candidate; primary Linux and patch queue remain frozen | SchedExecLease P5A-R2 E2 Disposable Layout Candidate Plan |
| 0160 | x86_64 E2 constrained to fresh same-toolchain E1/candidate cross-builds with architecture-local envelopes and no runtime inference | SchedExecLease P5A-R2 E2 x86_64 Layout Evidence Plan |
| 0161 | Cross-architecture E2 evidence closure separates exact disposable E3 planning input from production layout or source approval | SchedExecLease P5A-R2 E2 Layout Evidence Closure |
| 0162 | E3 constrained to an exact disposable two-file real-traversal KUnit prototype with independent-oracle and controlled-build gates | SchedExecLease P5A-R2 E3 Rebuild Prototype Evidence Plan |
| 0163 | E4 fixes a paired-control 35-cell lock-hold rejection experiment with immutable 25us/50us limits and two-architecture staging | SchedExecLease P5A-R2 E4 Lock-Hold Measurement Plan |
| 0164 | Attempt-1 base-slice assertion corrected to distinguish the fixed normalized threshold basis from the separately recorded runtime-scaled value | SchedExecLease P5A-R2 E4 Normalized Base-Slice Correction |
| 0165 | Valid arm64 evidence breaches 36 fixed gates across 20/35 cells and rejects the full O(n) rq-locked rebuild without launching x86_64 | SchedExecLease P5A-R2 E4 Arm64 Lock-Hold Rejection |
| 0166 | Bucket-local Candidate C projection selected: indexed active-rq fanout, snapshot/insertion handshake, and one-bucket rq-lock work replace all-leaf rebuild | SchedExecLease P5A-R3 Bucket-Local Targeted Projection |
| 0167 | R3-E1 fixes B_max=64, sparse private projections, zero ordinary hot-structure growth, unbound-work/hotplug/drain lifetime, exact two-file E2 scope, and later rejection thresholds | SchedExecLease P5A-R3 E1 Source/Locking/Lifetime Evidence Plan |
| 0168 | R3-E3 fixes an exact same-TU two-file KUnit prototype with B_max/fault/race/oracle matrices and four arm64/x86_64 diagnostic boots | SchedExecLease P5A-R3 E3 Bucket Concurrency Evidence Plan |
| 0169 | R3-E4 fixes a default-off same-TU rejection experiment with real rq locking, paired controls, 32 one-projection, 5 hotplug, and 5 targeted-fanout cells, immutable limits, and virtual-evidence non-claims | SchedExecLease P5A-R3 E4 Bucket Measurement Plan |
| 0170 | Exact direct-E3-child two-file E4 draft implements the 42-cell measurement suite, shared transition helpers, strict style, dual-arch compile smoke, and keeps measurement blocked on independent gates | SchedExecLease P5A-R3 E4 Bucket Measurement Source Draft |
| 0171 | Complete arm64 E4 evidence rejects 19/42 cells and 26 fixed gates while preserving clean QEMU/KUnit/warning/artifact and deterministic postprocess evidence | SchedExecLease P5A-R3 E4 Arm64 Bucket Measurement Rejection |
| 0172 | R4 selects an O(1) generation fence with coalesced notifier/pull recovery, conditional 2*A/B_max logical bounds, and separate current stop requests | SchedExecLease P5A-R4 Generation-Fenced Coalesced Pull Recovery |
| 0173 | R4-E1 fixes finite storage, the rq-locked irq-work to unbound-work bridge, cursor restart/late admission, one-projection recovery, current observation, and sleepable hotplug/RCU drain before layout source | SchedExecLease P5A-R4 E1 Dispatch and Lifetime Evidence Plan |
| 0174 | R4-E3 fixes the exact direct-E2-child same-TU synthetic KUnit boundary, independent receipts/oracle, 36 forced concurrency cases, six fault sites, and six dual-architecture diagnostic boots | SchedExecLease P5A-R4 E3 Concurrency and Diagnostic Evidence Plan |
| 0175 | Post-N-135 gate adds the exact claim-ledger row and fresh touched-path drift proof, accepts only the disposable virtual synthetic R4-E3 boundary, and authorizes source-free R4-E4 plan drafting | SchedExecLease P5A-R4 Post-N135 Authorization Gate |
| 0176 | Source-free R4-E4 local-quantum rejection plan; later completed as valid negative R4 evidence | SchedExecLease P5A-R4 E4 Local-Quantum Measurement Plan |
| 0177 | R5 successor selected from the R4 rejection; later rejected by selector-coherence analysis | SchedExecLease P5A-R5 Generation-Sealed Immutable Projection |
| 0178 | R5 rejected before source because ordinary EEVDF progress invalidates an immutable selector view | SchedExecLease P5A-R5 E1 EEVDF Selector-Coherence Rejection |
| 0179 | R6 bounded local selector selected as a source-free candidate; final architecture role reopened by 0185 | SchedExecLease P5A-R6 Sealed Masked Domain Forest |
| 0180 | R6-E1 bounded layout and local fairness evidence plan accepted for disposable probing | SchedExecLease P5A-R6 E1 Domain Forest Evidence Plan |
| 0181 | R6-E3 source-free correctness/concurrency plan accepted for exact disposable source | SchedExecLease P5A-R6 E3 Correctness and Concurrency Evidence Plan |
| 0182 | R6 post-E3 authorization boundary closed for exact disposable evidence only | SchedExecLease P5A-R6 Post-E3 Authorization Threat Boundary |
| 0183 | R6-E4 local selector measurement plan accepted; assurance promotion paused by 0185 | SchedExecLease P5A-R6 E4 Local-Quantum Measurement Plan |
| 0184 | Exact disposable R6-E4 source and regression lineage retained; no live scheduler or system claim | SchedExecLease P5A-R6 E4 Local-Quantum Measurement Source |
| 0185 | Accepted goal-conformance audit; N-155 scoped, system composition reopened, R6 treated only as a local residency candidate | Final Goal Conformance and Compositional Model Reopen |
| 0186 | Accepted Evidence Capsule v1 trust boundary; structural tooling passes 0287 and ROOTSCHED/RESIDENCY are scoped EC1 consumers in 0288/0289, while broader revalidation remains open | Evidence Capsule Trust Boundary and Migration |
| 0187 | Accepted Monitor-owned root-scheduling reference contract; two safe modes and ten targeted faults modeled without selecting an implementation | Monitor-Owned Root Scheduling Reference Contract |
| 0188 | RESIDENCY-001 finite pre-admitted one-shot reference is Model-supported at EC1; four deterministic safe scenarios and 22 faults replay, while RESIDENCY-DYN-001 and implementation remain open | Global Domain Identity and Bounded Residency Reference Contract |
| 0189 | Architecture candidate pending externally attested hostile freeze; adds boot-fixed NodeConfig/hierarchy bounds, parent-conserved physical execution and control/target service, typed partition/global-placement imports, total failure cover/charged cleanup, joint activation receipts, management bootstrap, source-first scoped failure/audit, 93-space namespace algebra, and restart reconciliation without an executable-model claim | Dynamic Admission and Recurring Residency Architecture Contract |
| 0190 | All 32 first-round and 12 pre-rereview self-audit blockers have candidate resolutions and named residual executable obligations; every item remains pending independent re-review and architecture freeze is not accepted | Dynamic Residency Pre-Freeze Hostile Review Disposition |
| 0191 | Four independent second-round reviews all returned FREEZE=NO; all 36 reviewer blockers plus 8 integration self-audit findings retain provenance and have candidate redesigns, but only a fresh third round may close them | Dynamic Residency Second Hostile Review and Redesign |
| 0192 | Executable pre-formal exact 20-scenario witness covers hierarchy, exact physical occurrence partitions, per-target control, partition import, global placement, least-fixed-point failure cover, joint activation and delivery settlement, management bootstrap, disjoint commits, recurring progress, apply failure, retirement, crash/audit, transfer, namespace wear, independent watchdog, settlement prefix, and lifecycle writers without claiming proof or freeze | Dynamic Residency Pre-Formal Two-Lane Witness |
| 0193 | Four fresh third-round reviews returned FREEZE=NO and exposed source replay/fence crash cuts, source-health exhaustion, single-writer, cancellation lifecycle, read dependencies, clock/service capacity, deterministic transfer, bounded recycle, aggregate bottlenecks, quadratic proof, assurance, schema, witness, and vocabulary blockers; redesign remains pending fresh review | Dynamic Residency Third Hostile Review and Redesign |
| 0194 | Selects externally pinned, signed, immutable-capsule assurance v2 with blind four-role assignment, deterministic aggregate, two-of-three decision signatures, derived freeze record, and a cryptographically separate non-freezing fixture mode; no real campaign or freeze is claimed | Architecture Freeze External Assurance Protocol v2 |
| 0195 | Independent datacenter/composition review returned FREEZE=NO for eight missing interfaces; NodeConfig hierarchy, physical CPU conservation, target-local turns, typed partition import, global placement fencing, total failure cover, joint activation, and management bootstrap are integrated but remain open pending validator and fresh attested review | Dynamic Residency Datacenter and Composition Boundary Review |
| 0196 | Fourth hostile counterexample review records 16 open execution, service, activation, placement, migration, failure, capacity, clock, lifecycle, and validator defects; redesign is integrated but remains unclosed pending strict mutation coverage and fresh review | Dynamic Residency Fourth Hostile Counterexample Review |
| 0197 | Hostile review of Assurance Protocol v2 records 20 open protocol and verifier defects; v2.1.2 fixture mechanics are repaired, but real external retention, signatures, hermetic semantic runners, and campaign evidence remain unimplemented | Architecture Freeze Assurance v2 Hostile Review |
| 0198 | Fifth hostile architecture/proof review records 19 open counterexamples spanning exact execution sets, clock normalization, activation identity and settlement, failure fixed points, ancestor cleanup charge, proof dependency, migration, and interface-conditional claims; redesign plus 322 targeted mutations and 8,119 malformed type/container replacements pass, while fresh review and formal refinement remain pending | Dynamic Residency Fifth Hostile Architecture and Proof Review |
| 0199 | Four fresh independent internal hostile reviews reject exact candidate `24bb1320...174f` with 21 canonical authority, activation, delegation, boundary, transfer, failure, liveness, calendar, refinement, and assurance blockers; the digest is preserved as a regression target and TLA+ remains unauthorized | Dynamic Residency Sixth Fresh Hostile Review Rejection |
| 0200 | Exact R6 v2 successor draft attempted acyclic authority, opportunity-keyed activation, typed receipts, bounded failure/transfer, nonvacuous liveness, and proof ordering, but four later hostile reviews found real schema-derived cycles, transaction gaps, and formal incompleteness; exact snapshot is rejected and retained | Dynamic Residency R6 Successor Semantic Architecture |
| 0201 | Assurance v3 candidate defines exact schemas for the complete root/policy, durable witness, retained candidate, semantic-runner, review, campaign-log, and decision chain; persisted exact-root extension prevents admitted-event forks under the stated threshold, strict success receipts and nonvacuous review payloads replace digest-only acceptance, while real tooling and external evidence remain absent | Architecture Freeze External Assurance Protocol v3 |
| 0202 | Sixteen required R6 counterexamples were structured and pinned, but witness implementation stopped before validation when the parent contract failed hostile review; the draft is retained only as R7 counterexample input | Dynamic Residency R6 Executable Witness Draft |
| 0203 | Four independent reviews reject exact R6 v2 with 40 normalized findings, separate 32 local semantic-IR blockers from 8 later system-completion obligations, and require schema-derived dependencies, exact action IR, crash/interleaving traces, and validator meta-mutation before TLA+ | Dynamic Residency R7 Hostile Review Rejection |
| 0204 | R7 pre-IR design proposed schema-derived authority, horizon separation, CAS attempts, protected entry, no-hole closure, typed transfer, item work, rank/refinement, and proof ledgers, but fresh review found staging, entry root, stop, closure, lost-effect, bounded-history, and formal-completeness blockers; exact snapshot is rejected | Dynamic Residency R7 Executable Semantic IR Architecture |
| 0205 | Four hostile reviews reject exact R7 pre-IR design and fix R8 choices: early staging identity, activation input core, constant-size entry outcome, one runtime stop authority, sealed publication, generation-safe failure closure, replicate-before-execute continuity, bounded suffixes, context reuse hot path, complete clean Init/Next/proof/claim IR, and validator meta-mutation | Dynamic Residency R8 Pre-IR Hostile Review Rejection |
| 0206 | R8 proposed bounded dynamic residency, protected ready/portal state, per-use authority, CPU-enable entry truth, escrowed runtime, sealed publication, failure closure, no-reissue transfer, and bounded recurrence, but four exact reviews found 40 normalized authority, physical-entry, recovery, settlement, transfer, proof, and cost-shape blockers; exact snapshot is rejected | Dynamic Residency R8 Semantic Closure Architecture |
| 0207 | Four independent reviews reject exact R8 snapshot `4f30f2b8...7b5b`; 54 raw findings normalize to 40 local blockers, and R9 is fixed around parent-conserved authority, residency aggregates, constant-size dispatch, provider-owned physical entry, deterministic recovery, source-fence-first transfer, and closed formula/proof registries | Dynamic Residency R9 Pre-IR Hostile Review Rejection |
| 0208 | R9 integrated parent-conserved authority, process-leaf spawn, typed async carriers, dynamic admission, residency aggregates, provider-owned entry/quantum truth, settlement, failure/transfer, 77 cell kinds, 138 action names, and 43 crash cuts, but exact review found 42 normalized machine-closure, authority, causality, recovery, and distributed-state blockers; exact snapshot is rejected | Dynamic Residency R9 Closed Semantic Architecture |
| 0209 | Four exact read-only reviews reject R9 snapshot `f7e9f3df...11362`; 78 raw findings map losslessly to 42 blockers and fix R10 around a normative typed IR, actor/writer separation, single-shard deterministic transactions, exact object/action formulas, causal attempt/claim/entry identities, effective revocation after stop, sealed publication, failure epochs, and destination-bound one-use transfer | Dynamic Residency R10 Pre-IR Hostile Review Rejection |
| 0210 | Concurrent read-only tooling audit rejects R10 machine-IR readiness after 18 hostile accepted variants normalize to 14 validator/evidence failures; negative-only evidence fixes draft-only status, typed AST contexts, transitive reads, generation-keyed recovery, exact concrete frames, and manifest-last publication while leaving executable witnesses/mutations, imports, allocator closure, instance completeness, provider/rank checks, and exact re-review open | Dynamic Residency R10 Machine-IR Tooling Hostile Audit |
| 0211 | Concurrent trust-boundary audit rejects R10 promotion despite 29 local structural mutations because evidence can hash different bytes than those tested, validator and harness self-certify through shared code, candidate-controlled expectations and semantic-vacuity gaps remain, imports are not source-derived, and no external promotion authority exists | Dynamic Residency R10 Assurance Trust-Boundary Audit |
| 0212 | Exact R10 validator accepts all 13 semantic-vacuity counterexamples, including TRUE conservation, empty proof support, fabricated claims and blockers, prepublished provider receipts, vacuous progress, weakened model profiles, inflated atomicity, collapsed CPU consistency metadata, and demoted authority state; closure is split into IR derivation, external policy, and final formal proof | Dynamic Residency R10 Semantic-Vacuity Counterexamples |
| 0213 | R10 is retained as a rejected typed-IR experiment after 26/42 pending blockers, 13/13 accepted semantic-vacuity mutants, ambient executable Init, unreachable provider entry, and non-independent promotion; R11 is fixed as a policy-derived modular D0-D17 architecture with empty executable Init, ordinary management, explicit async alias role uses, provider-rooted entry, full conservation, W0-W12, two lanes, and two clusters | Dynamic Residency R10 Rejection and R11 Successor Architecture |
| 0214 | Exact R11 G0 v1 is rejected before external review after three local hostile reviews, 12/12 accepted semantic weakenings, and 5/5 schema-admitted forged positives; epoch 2 requires a backend-neutral typed logic, executable external templates, exact product writers and branches, generated scenario interactions/cuts, real assurance faults, and an independently rooted executable gate | Dynamic Residency R11 G0 v1 Rejection and Epoch-2 Semantic Kernel |
| 0215 | The first epoch-2 kernel v2 is rejected before implementation by three local hostile reviews; v3 separates K0 foundation, K1 candidate, K2 semantic freeze, and K3 proof/evidence, defines parametric carrier/state/action/event/trace denotation, phase-safe total terms, explicit stutter/enabledness/fairness, transaction durability, network behavior, two-trace noninterference, fourteen scenario generators, and Protocol-v3.1 external roots | Dynamic Residency Epoch-2 Kernel v2 Rejection and v3 Denotation |
| 0216 | Exact v3 passes deterministic local shape checks but four exact-hash local reviews reject its incomplete typed model/action/frame semantics, vacuous claim extensions, abstract-to-physical gap, candidate-narrowable compromise model, and absent K0 source-set closure; v4 is decomposed into F0 calculus, F1 claims, F2 platform/threat refinement, and F3 external policy/assurance | Dynamic Residency Semantic Foundation v3 Rejection and v4 Layering |
| 0217 | Exact F0 v4 passes identity checks and 21/21 structural mutations but four exact-hash local reviews reject its unconstructible events, unbound parameter invariants, omittable actions, undefined footprints, coarse nested-map locations, empty claim classes, claim-unbound nonvacuity, and undefined extension/platform morphisms; F0 v5 must close grammar, batches, morphisms, and proof identity before F1 | Dynamic Residency F0 v4 Hostile Rejection and v5 Closure |
| 0218 | Exact F0 v5 machine draft-1 passes local structural checks and 38/38 structural mutations but is rejected for missing action binders, checked common term sorts, Qty result binding, Atom premises, arbitrary exact scope, runtime carriers, recursive semantic rules, and claim/proof machinery | Dynamic Residency F0 v5 Machine Draft-1 Parity Rejection |
| 0219 | F0 v5 source-static and immutable link-construction substage locally closed after two post-implementation audits; byte-only snapshots, local source-byte cross-reconstruction, 7 typed preimage policies, resource bounds, and 61/83/23/51/56/21 hostile families pass, while Eval, Reads, transition, WF, external review, F0, and G0 remain false | Dynamic Residency F0 v5 Static Semantics and Immutable Link Closure |
| 0220 | Source-derived checked occurrences and immutable finite requests remove caller term/Gamma/Delta/provenance choice; ValidationContext, dual resource profiles, pre-link product metering, and exact taxonomy dispatch exist locally, while snapshot-executed code, whole-pipeline metering, supervisor, POST/EVENT roots, metatheory, F0, and G0 remain open | Dynamic Residency F0 v5 Checked Evaluation Trust Boundary |
| 0221 | Historical pre-normative supervisor v1 candidate; exact bytes are locally rejected by 0222 for hidden classification state, early fallback, missing EOF/quiescence, fault-to-Resource laundering, unsupervised parsing, replayable receipts, and incomplete scope cleanup | Dynamic Residency F0 v5 Supervised Evaluation Protocol |
| 0222 | Two independent local hostile reviews reject supervisor v1: hidden state and early fallback break observation-order invariance, EOF and quiescence are absent, quota can launder faults, requester/result parsing escapes supervision, run receipts are replayable, and pidfd does not prove scope cleanup; no F0/G0 or external credit follows | Dynamic Residency F0 v5 Supervisor v1 Hostile Rejection |
| 0223 | Pre-normative supervisor v2 separates guardian, opaque transport supervision, bounded semantic workers, and independent checking; binds every receipt to a fresh RunId ledger; requires charged sandbox-ready release, EOF and scope quiescence, pure total classification, fault-before-Resource precedence, guardian Abandoned semantics, and mechanism-specific Linux refinement | Dynamic Residency F0 v5 Supervised Evaluation Protocol v2 |
| 0224 | Three fresh local reviews reject supervisor v2 as an LTS or semantic-verdict boundary: its 82,944 products are an unconstrained truth table, trace order is erased, quiescence and receipts are oracles, candidate frames become Success, quota laundering and seal contradictions remain, and external ownership/publication replay are open | Dynamic Residency F0 v5 Supervisor v2 Hostile Rejection |
| 0225 | Exact executable v3 draft-0 is locally rejected after 10,648 reachable states per role expose 273 nonterminal deadlocks and 686 prefixes with no terminal path; three reviews also reject scope closure, receipt authenticity, winner stability, external ownership, child composition, crash recovery, publication durability, and an action registry with zero exact matches | Dynamic Residency F0 v5 Supervisor v3 Draft-0 Hostile Rejection |
| 0226 | Candidate-4 reaches a restartable pre-full local checkpoint after child 274, parent 715, and runner 44 hostile cases plus the fast validator pass; raw component receipts, exact nested schemas, role agreement, reachable commutation membership, realizable cardinality and edge bounds, claim predicates, and lifecycle cleanup are locally bound, while full reachability/commutation are not run and external containment, R11, G0, F0, and protection remain false | Dynamic Residency F0 v5 Supervisor v3 Candidate-4 Pre-Full Local Closure |
| 0227 | GPT-5.6 Sol maximum-effort synthesis, contradiction, and minimality are fixed as non-authoritative primary construction passes while TLA+ is terminal-only; exact contract `14ca4b...fd075` fixes eight roles, 13 typed object classes, 17 fail-closed platform requirements, split capture/guardian/reduction lifecycles, 30 invariants, seven gates, and the four-claim local ceiling; G1-G5 now pass locally while G6/G7 remain open | Dynamic Residency F0 Candidate-4 Authority-Disjoint Capture Contract |

## Planned Analysis Notes

1. BPF verifier/JIT TCB sub-map if BPF becomes a policy front-end.
2. Broker BudgetTicket and service Domain charging map.
3. Workqueue origin QEMU stack-trace observation runner.
4. Slice 0C trace-only observation patch map only if schema/modeling requires it.
5. Queue/descriptor trace-only patch map only if readiness gaps require it.

## Behavior Tag Artifacts

| Path | Status | Purpose |
| --- | --- | --- |
| `behavior-tags/slice0c-scheduler-behavior-tags.json` | Draft v1, not solver-eligible | Exploratory Slice 0C behavior tag ledger |
| `behavior-tags/schema-v2-requirements.json` | Requirements only | Mandatory fields and hard reject rules for schema v2 |
| `behavior-tags/schema-v2.json` | Draft contract | Machine-readable schema v2 contract for gap analysis and hard reject |
| `behavior-tags/slice0c-scheduler-behavior-tags-v2.json` | Draft v2, gap-analysis only | Slice 0C behavior paths retagged under schema v2 |
| `workqueue-origin-taxonomy-v1.json` | Draft contract | Machine-readable workqueue origin taxonomy for async source tagging |
| `usbnet-workqueue-source-map-v1.json` | Draft source map | Machine-readable representative usbnet workqueue/container/effect mapping |
| `e1000e-queuelease-source-map-v1.json` | Draft source map | Machine-readable representative Ethernet ring/IRQ/NAPI/QueueLease mapping |
| `queue-descriptor-ledger-tags-v1.json` | Draft observation schema | Machine-readable observation-only queue/descriptor ledger event and tag contract |
| `ice-modern-nic-queuelease-source-map-v1.json` | Draft source map | Machine-readable modern NIC QueueLease mapping for ice SKB/XDP/AF_XDP/devlink/representor paths |
| `ice-modern-nic-revoke-source-map-v1.json` | Draft source map | Machine-readable modern NIC revoke/drain/quarantine source map for ice paths |
| `monitor-irq-route-invalidation-source-map-v1.json` | Draft source map | Machine-readable IRQ route invalidation mapping across ice, VFIO, iommufd, MSI/MSI-X, and interrupt remapping |
| `monitor-dma-iommu-memoryview-invalidation-source-map-v1.json` | Draft source map | Machine-readable DMA/IOMMU/MemoryView invalidation mapping across ice, DMA API, IOMMU core, iommufd, VFIO, and arch IOMMU backends |
| `xsk-pagepool-quarantine-source-map-v1.json` | Draft source map | Machine-readable stale XSK/page-pool completion quarantine and packet memory return map |
| `representor-lower-queuelease-source-map-v1.json` | Draft source map | Machine-readable representor forwarding, bridge/FDB/VLAN/TC offload, and lower QueueLease derivation map |
| `ice-servicework-carrier-source-map-v1.json` | Draft source map | Machine-readable ICE service-work carrier, coalescing, VF mailbox, PTP/DPLL, eswitch, LAG, and reset/rebuild authority map |
| `ice-vf-mailbox-carrier-source-map-v1.json` | Draft source map | Machine-readable ICE VF mailbox queue/DMA/IRQ/budget/FDIR carrier authority map |
| `ice-vf-epoch-handoff-source-map-v1.json` | Draft source map | Machine-readable ICE VF reset/reassignment, VF epoch, VSI generation, queue/IRQ/DMA, FDIR, mailbox, and service replay handoff map |
| `modern-nic-hypertag-interface-map-v1.json` | Draft architecture map | Machine-readable HyperTag Monitor, Linux service/driver Domain, target endpoint, and modern NIC receipt split map |
| `modern-nic-hypertag-readiness-probe-map-v1.json` | Draft readiness map | Machine-readable observation-only probe and inert-stub mapping for modern NIC HyperTag receipts/carriers |
| `modern-nic-hypertag-observation-ledger-v1.json` | Draft observation ledger seed | Machine-readable source-anchor seed for the modern NIC HyperTag observation ledger runner |
| `local-domain-device-lease-compilation-v1.json` | Draft external-gap map | Machine-readable root-management/local monitor compilation boundary for LocalDomainDeviceLease |
| `local-domain-device-lease-observation-contract-v1.json` | Draft observation contract | Machine-readable LocalDomainDeviceLease row contract, dependency rules, safety flags, and forbidden authority collapses |
| `local-domain-device-lease-admission-protocol-v1.json` | Draft admission protocol | Machine-readable root-management/local monitor admission path, failure modes, revoke ordering, and invariant list |
| `local-monitor-admission-interface-boundary-v1.json` | Draft interface boundary | Machine-readable local monitor request/response object boundary, freshness fields, attachment points, and forbidden exposures |
| `local-monitor-admission-carrier-storage-v1.json` | Draft choice gate | Machine-readable local monitor carrier/storage choice gate and authority-collapse rejection map |
| `local-monitor-admission-abi-semantics-v0.json` | Draft semantic ABI candidate | Machine-readable LocalMonitorAdmissionABI-v0 request/response, ledger, replay, shadow, failure, and revoke semantics |
| `local-monitor-admission-carrier-sketch-comparison-v1.json` | Draft sketch comparison | Machine-readable direct-call-first versus monitor-owned-ring-first carrier sketch comparison |
| `direct-call-reference-abi-sketch-v1.json` | Draft reference ABI sketch | Machine-readable direct-call reference semantics for monitor entry, request copy, replay, ledger, response handle, shadow refresh, and revoke |
| `monitor-owned-ring-refinement-sketch-v1.json` | Draft throughput refinement sketch | Machine-readable monitor-owned ring refinement semantics for slot claim, slot epochs, batch boundaries, response publication, drain, and DoS accounting |
| `combined-admission-carriers-plan-v1.json` | Draft combined carrier plan | Machine-readable direct-call plus monitor-owned-ring admission carrier semantics for shared attempt, replay, ledger, shadow, fallback, and revoke ordering |
| `direct-call-carrier-requirements-v1.json` | Draft implementation-facing requirements | Machine-readable direct-call carrier requirements for request envelopes, bounded copy, replay keys, ledger rows, response handles, errors, shadow generation, control lane, and future ring compatibility |
| `direct-call-schema-compatibility-v1.json` | Draft semantic schema candidate | Machine-readable direct-call schema compatibility rules for schema negotiation, field criticality, downgrade rejection, response/ledger/error schemas, and ring-compatible namespaces |
| `direct-call-attachment-readiness-v1.json` | Draft no-code attachment/readiness map | Machine-readable direct-call Linux/monitor attachment rows, safety flags, monitor responsibilities, inert stub constraints, failure-injection boundaries, and ring compatibility requirements |
| `direct-call-trace-source-inventory-contract-v1.json` | Draft no-code inventory contract | Machine-readable source-only direct-call inventory runner contract, seed rows, output schema, safety flags, stop conditions, and optional tracefs-plan boundary |
| `direct-call-monitor-receipt-schema-v1.json` | Draft monitor-owned receipt schema | Machine-readable direct-call receipt families for request image, schema, entry result, response handle, and revoke completion |
| `direct-call-receipt-consumer-source-map-v1.json` | Draft source map | Machine-readable Linux-facing receipt-consumer candidate/exclusion map for N-117, with 20 current source anchors and 7 preserved future gap/plan rows |
| `direct-call-async-workqueue-source-map-v1.json` | Draft source map | Machine-readable generic workqueue async-carrier exclusion and typed-wrapper source map for N-122 |
| `direct-call-async-io-uring-source-map-v1.json` | Draft source map | Machine-readable io_uring request/resource/io-wq async-carrier source map for N-122 |
| `direct-call-async-carrier-lifetime-table-v1.json` | Draft lifetime table | Machine-readable workqueue/io_uring async carrier lifetime obligations for N-123 |
| `direct-call-async-carrier-api-direction-v1.json` | Accepted no-behavior API direction | Machine-readable workqueue-only vs io_uring-only vs shared internal carrier choice for N-124 |
| `direct-call-workqueue-adapter-refinement-v1.json` | Draft refinement model input | Machine-readable workqueue adapter state, transition, unsafe-case, and non-claim contract for N-127 |
| `direct-call-io-uring-adapter-refinement-v1.json` | Draft refinement model input | Machine-readable io_uring adapter request/resource/worker/completion state, unsafe-case, and non-claim contract for N-128 |
| `linux-upstream-drift-maintenance-review-v1.json` | Current-source maintenance gate | Machine-readable upstream drift, merge-tree, no-patch decision, future no-behavior patch gate, drift classes, unsafe patterns, and safety flags for N-131 |
| `linux-source-drift-model-freshness-gate-v1.json` | Automation contract | Machine-readable watch groups, affected artifacts, stale-if-changed rules, blocked patch classes, and non-claim constraints for N-132 |
| `linux-source-map-refresh-target-selection-v1.json` | Target selection | Machine-readable candidate comparison and source-only scheduler_authority_core refresh target selection for N-133 |
| `linux-scheduler-authority-core-refresh-v1.json` | Source-only refresh contract | Machine-readable scheduler authority anchors, refreshed rules, updated artifacts, and safety flags for N-134 |
| `scheduler-authority-refinement-gate-v1.json` | Draft model gate | Machine-readable TASK_WAKING, donor/current/proxy budget, and selected-state refinement gate for N-135 |
| `runtime-charge-subject-v1.json` | Draft model gate | Machine-readable runtime charge subject map for N-136 |
| `implementation-ready-completion-audit-v1.json` | Design-readiness audit | Machine-readable implementation-ready completion status, blockers, and next design order |
| `sched-ext-core-proxy-coverage-boundary-v1.json` | Source-verified coverage boundary | Machine-readable sched_ext/core/proxy open classifications, source surfaces, required decisions, and forbidden assumptions |
| `bounded-retry-ineligibility-source-design-v1.json` | Source-verified B2 design constraint | Machine-readable bounded retry/ineligibility source shape, allowed shapes, forbidden shapes, and future model refresh requirements |
| `negative-denial-validation-plan-v1.json` | Design-only negative validation plan | Machine-readable negative denial test obligations, future observables, path classification requirements, and non-claim safety flags |
| `scheduler-path-classification-for-p5-v1.json` | Design-only path classification | Machine-readable P5 supported/disabled/excluded scheduler path classification and claim-scope guard |
| `implementation-claim-ledger-gate-v1.json` | Design-only claim ledger gate | Machine-readable evidence-class to claim-class rules and mandatory non-claim safety flags for future implementation proposals |
| `implementation-reopen-upstream-drift-gate-v1.json` | Design-only implementation-reopen drift gate | Machine-readable fresh upstream observation, touched-group freshness rules, slice reopen requirements, and non-claim safety flags |
| `final-implementation-ready-audit-v1.json` | Final design-ready audit | Machine-readable final implementation-ready design verdict, slice readiness, future patch requirements, and safety flags |
| `scheduler-server-ticket-v1.json` | Draft model gate | Machine-readable scheduler server-ticket source map and model contract for N-137 |
| `runtime-coverage-gate-v1.json` | Draft trace-only coverage gate | Machine-readable current/donor/proxy/server runtime coverage contract for N-138 |
| `monitor-root-budget-timer-v1.json` | Draft monitor-root budget event model | Machine-readable monitor-owned root budget timer contract for N-139 |
| `server-epoch-relation-v1.json` | Draft model gate | Machine-readable server-kind/server-epoch freshness contract for N-140 |
| `deadline-cbs-grub-compat-v1.json` | Draft model gate | Machine-readable Linux SCHED_DEADLINE CBS/GRUB compatibility and authority-separation contract for N-141 |
| `f1-admission-freeze-refresh-v1.json` | Draft model gate | Machine-readable F1 wake publication and FrozenRunUse boundary contract for N-142 |
| `scheduler-authority-integration-gate-v1.json` | Draft integration model gate | Machine-readable integrated scheduler execution gate for N-143 |
| `monitor-timer-architecture-substrate-v1.json` | Draft architecture-substrate model gate | Machine-readable x86 VMX-root, arm64 EL2, KVM guest timer, Linux timer, and pKVM stage-2 substitution rejection contract for N-144 |
| `placement-affinity-hotplug-integration-gate-v1.json` | Draft integration model gate | Machine-readable placement, affinity, cpuset, hotplug, class-selection, sched_ext, core-scheduling, and Linux-exception integration gate for N-145 |
| `final-run-move-revalidation-hook-placement-gate-v1.json` | Draft hook-placement model gate | Machine-readable final run/move tuple-consumption boundary, stale tuple rejection, and Linux selected/move non-authority contract for N-146 |
| `final-deny-retry-ineligibility-gate-v1.json` | Draft model gate | Machine-readable final run denial retry, ineligibility, fail-closed, and non-authority contract for N-147 |
| `task-frozen-run-lifetime-locking-gate-v1.json` | Draft model gate | Machine-readable task lifetime, generation, RCU-only rejection, rq/pi locking, migration, release, and denied-candidate settlement contract for N-148 |
| `lifecycle-identity-propagation-integration-gate-v1.json` | Draft integration model gate | Machine-readable fork/clone, exec, and exit identity propagation contract for N-149 |
| `exit-revoke-pending-authority-drain-gate-v1.json` | Draft integration model gate | Machine-readable global exit/revoke pending-authority inventory, drain, receipt, settlement, and non-claim contract for N-150 |
| `model-completeness-ledger-gate-v1.json` | Negative completion gate | Machine-readable current model-completeness audit and remaining model-only blockers for N-151 |
| `tcb-boundary-gate-v1.json` | Draft model gate | Machine-readable HyperTag Monitor and service-domain TCB boundary contract for N-152 |
| `side-channel-cotenancy-policy-gate-v1.json` | Draft model gate | Machine-readable explicit co-tenancy and side-channel policy contract for N-153 |
| `evaluation-contract-gate-v1.json` | Draft model gate | Machine-readable production protection and cost-efficiency evaluation contract for N-154 |
| `final-model-completeness-ledger-v1.json` | Final completion ledger | Machine-readable final model-only completion audit for N-155 |
| `final-goal-conformance-and-compositional-model-reopen-v1.json` | Accepted architecture audit | Machine-readable N-174 scope correction, reopened requirements, R6 disposition, and model work order |
| `evidence-capsule-trust-boundary-and-migration-v1.json` | Accepted assurance contract | Machine-readable producer/collector/validator split, capture state, provenance, evidence levels, and migration policy |
| `monitor-owned-root-scheduling-reference-contract-v1.json` | Accepted model-supported reference contract | Machine-readable N-175 Monitor/Linux ownership split, fairness assumptions, safety/liveness obligations, counterexamples, and non-claims |
| `global-domain-identity-bounded-residency-reference-contract-v1.json` | EC1 model-supported finite reference contract | Machine-readable N-176 fixed pre-admitted global identity, bounded per-CPU projection, version algebra, ownership, one-shot progress assumptions, counterexamples, evidence identity, and non-claims |
| `dynamic-admission-recurring-residency-architecture-contract-v1.json` | Architecture candidate pending externally attested hostile freeze | Machine-readable N-177 NodeConfig/hierarchy, typed lease/placement import, parent-conserved physical execution/control/target service, total failure cover and charged cleanup, joint activation receipt, management bootstrap, nonblocking sharded apply, 93-space namespace/restart algebra, scale, and formal-decomposition contract |
| `f0-c4-authority-disjoint-capture-contract-v1.json` | Architecture contract; G1-G5 locally closed, exact capture/reduction pending | Machine-readable GPT-primary/TLA-terminal reasoning profile, exact Candidate-4 claim ceiling, eight authority-disjoint roles, 13 typed object classes, root-owned snapshot/plan/evidence boundary, cgroup-v2/pidfd containment, split capture/guardian/reduction lifecycles, failures, finite resources, 30 invariants, seven gates, authorization, and nonclaims |
| `dynamic-admission-recurring-residency-pre-freeze-review-disposition-v1.json` | Candidate responses recorded; independent re-review required | Machine-readable 32 first-round plus 12 self-audit finding disposition ledger with candidate resolutions, mechanical gates, residual model obligations, and strict non-claims |
| `dynamic-admission-recurring-residency-second-hostile-review-disposition-v1.json` | Second-round blockers redesigned; fresh third-round review required | Machine-readable provenance-preserving ledger for 8 security, 11 formal, 5 scale, 12 integration, and 8 self-audit findings with exact pending status and non-claims |
| `dynamic-residency-preformal-two-lane-witness-v1.json` | Non-executable architecture witness; review pending | Machine-readable two-lane topology, typed sole-writer map, exact 20 executable architecture traces, typed external/internal rely boundary, R2/R3/datacenter/R4/R5 finding partition, and proof/freeze non-claims |
| `dynamic-residency-third-hostile-review-disposition-v1.json` | Third-round blockers open | Machine-readable 20 reviewer plus 13 self-audit blocker ledger, candidate redesigns, residual obligations, and strict non-claims |
| `architecture-freeze-external-assurance-protocol-v2.json` | External assurance protocol selected; real campaign pending | Machine-readable externally pinned trust, immutable capsule, blind roster, four signed reviews, deterministic aggregate, threshold decision, derived freeze, and non-freezing fixture separation |
| `dynamic-residency-datacenter-composition-boundary-review-v1.json` | Eight composition blockers open | Machine-readable N-182 NodeConfig, physical execution, target turn, partition import, global placement, total failure cover, joint activation, and management-bootstrap review disposition |
| `dynamic-residency-fourth-hostile-counterexample-review-v1.json` | Fourth-round blockers open | Machine-readable 16 counterexample findings, integrated redesign mapping, residual obligations, and strict non-claims |
| `architecture-freeze-assurance-v2-hostile-review-v1.json` | Assurance v2 defects open; fixture mechanics repaired | Machine-readable 20 protocol/verifier findings, v2.1.2 disposition, fixture-versus-real separation, and real-campaign non-claims |
| `dynamic-residency-fifth-hostile-architecture-and-proof-review-v1.json` | Fifth-round blockers open | Machine-readable 19 architecture/proof counterexamples, exact R5 witness coverage, integrated redesign mapping, and freeze/formalization non-claims |
| `terminology-freeze-rename-risk-review-v1.json` | Public vocabulary lock | Machine-readable N-156 terminology freeze, inventory, and alias policy |
| `sched-exec-lease-p4-pre-entry-risk-gate-v1.json` | P4 pre-entry gate | Machine-readable P4 allow-all/no-denial pre-entry evidence, generated-code review, QEMU matrix, drift, security-diff preflight, and non-claim constraints |
| `sched-exec-lease-p4-pre-implementation-critical-audit-v1.json` | P4 pause gate | Machine-readable P4 pre-implementation multi-axis audit, hardened fresh drift result, stale global D4 finding, axis verdicts, and reopen criteria |
| `candidate-scoped-drift-closure-gate-v1.json` | Candidate-scope gate | Machine-readable P4 candidate-scoped drift closure, non-candidate stale containment, formal result summary, remaining P4 blockers, and non-claims |
| `sched-exec-lease-p4-anchor-manifest-v1.json` | P4 anchor manifest | Machine-readable P4 final-run/common-move/locked-move anchor windows, source-order constraints, explicit non-coverage, remaining blockers, and non-claims |
| `sched-exec-lease-p4-static-final-run-observability-v1.json` | Static final-run observability | Machine-readable P4 final-run static pre-rq-curr observability, P3 marker negative observation, remaining blockers, and non-claims |
| `sched-exec-lease-p4-allow-all-helper-proof-v1.json` | P4 allow-all helper proof | Machine-readable P4 allow-only/no-denial helper contract, current-tree source check, remaining patch acceptance requirements, and non-claims |
| `sched-exec-lease-p4-final-overclaim-security-review-v1.json` | P4 final review | Machine-readable P4 final overclaim/security review, accepted compatibility evidence, zero finding result, allowed claim, forbidden claims, and next gate |
| `sched-exec-lease-p5-readiness-refresh-after-p4-v1.json` | P5 blocked refresh | Machine-readable post-P4 P5 readiness refresh, run/move denial blockers, source facts, preconditions, and non-claims |
| `sched-exec-lease-p5a-scope-proposal-v1.json` | P5A scope proposal | Machine-readable P5A0/P5A-R/P5A-M/P5A-V decomposition, narrowed run/move blockers, forbidden claims, and review order |
| `sched-exec-lease-p5a0-no-behavior-infrastructure-proposal-v1.json` | P5A0 proposal | Machine-readable no-behavior infrastructure proposal, future patch constraints, move/run/test/setup shapes, required validation, and non-claims |
| `sched-exec-lease-p5a0-e-prepatch-evidence-v1.json` | P5A0.E evidence | Machine-readable prepatch evidence package, candidate-scoped drift, future patch identity, source observations, low-overhead constraints, and non-claims |
| `sched-exec-lease-p5a0-p1-no-behavior-patch-plan-v1.json` | P5A0.P1 patch plan | Machine-readable no-behavior patch-plan gate, per-0008 delta rule, lifecycle freeze, no-overhead acceptance evidence, and non-claims |
| `sched-exec-lease-p5a-r-m-and-p5a0-p1-acceptance-audit-v1.json` | P5A blockers and acceptance audit | Machine-readable P5A-R picker blocker, P5A-M move settlement blocker, P5A0.P1 full-acceptance evidence gap, and forbidden claims |
| `sched-exec-lease-p5a-r-cfs-picker-eligibility-source-map-v1.json` | P5A-R CFS picker source map | Machine-readable CFS picker eligibility anchors, denied-candidate blockers, bounded-retry requirements, cross-path exclusions, and non-claims |
| `sched-exec-lease-p5a-r-picker-ineligibility-gate-v1.json` | P5A-R formal gate | Machine-readable attempt-local ineligibility, bounded retry, cost/layout, EEVDF return coverage, cross-path settlement, and non-claim gate |
| `sched-exec-lease-p5a-r-eevdf-return-dominance-v1.json` | P5A-R source-shape gate | Machine-readable EEVDF return-site dominance, semantic candidate families, source-shape outputs, drift handling, and non-claim gate |
| `sched-exec-lease-p5a-r-group-hierarchy-settlement-v1.json` | P5A-R hierarchy gate | Machine-readable leaf/path/child-exhaustion/parent-skip distinctions, source anchors, formal results, and non-claim gate |
| `sched-exec-lease-p5a-r-cross-path-exclusion-settlement-v1.json` | P5A-R cross-path gate | Machine-readable ordinary-CFS-only cross-path exclusion/settlement contract for core, DL server, proxy, sched_ext, class-loop, source anchors, formal results, and non-claim gate |
| `sched-exec-lease-p5a-r-overhead-layout-gate-v1.json` | P5A-R overhead/layout gate | Machine-readable no-O(n), no-hot-layout, disabled-overhead, source-shape, formal-result, and non-claim gate |
| `sched-exec-lease-p5a-r-negative-validation-plan-v1.json` | P5A-R negative validation plan | Machine-readable negative test families, required observables, validation layers, formal result, and non-claim gate |
| `sched-exec-lease-p5a-r-0009-negative-runtime-harness-v1.json` | P5A-R 0009 negative harness design | Machine-readable test-only CFS denial harness boundary, synthetic denial predicate, targeted negative families, and non-claim gate |
| `sched-exec-lease-p5a-r-0012-acceptance-boundary-v1.json` | P5A-R 0012 boundary review | Machine-readable accepted/blocked claim set and production design blockers after validation/0186 |
| `sched-exec-lease-p5a-r2-selector-direction-v1.json` | P5A-R2 selector direction | Machine-readable candidate matrix for picker-visible lease eligibility, separate eligible timeline, lease bucket before CFS, bounded window, and explicit quarantine settlement |
| `sched-exec-lease-p5a-r2-selector-model-gate-v1.json` | P5A-R2 selector model gate | Machine-readable selector gate conditions, source anchors, EEVDF-compatible min-pickable summary requirement, unsafe families, and non-claim flags |
| `sched-exec-lease-p5a-r2-invalidation-source-map-v1.json` | P5A-R2 invalidation source map | Machine-readable Linux source anchors for lifecycle, affinity, migration, group, cpuset, budget, current, and future monitor receipt invalidation families |
| `sched-exec-lease-p5a-r2-invalidation-semantics-gate-v1.json` | P5A-R2 invalidation semantics gate | Machine-readable Fresh/Stale/Refreshing/Blocked summary semantics, propagation rules, refresh preconditions, picker trust rules, unsafe families, and non-claim flags |
| `sched-exec-lease-p5a-r2-selector-patch-plan-v1.json` | P5A-R2 selector patch plan | Machine-readable source/design patch-plan gate rejecting production extension of 0012 fallback and requiring EEVDF-compatible fresh summaries, evidence gates, and non-claim flags |
| `sched-exec-lease-p5a-r2-minimal-source-sketch-v1.json` | P5A-R2 minimal source sketch | Machine-readable minimal EEVDF fresh-summary sketch, source anchors, hot-layout evidence requirements, unsafe families, and non-claim flags |
| `sched-exec-lease-p5a-r2-layout-overhead-evidence-plan-v1.json` | P5A-R2 layout/overhead evidence plan | Machine-readable evidence contract for layout probes, disabled overhead, object/function deltas, negative stale-summary tests, and non-claim flags |
| `sched-exec-lease-p5a-r2-layout-probe-patch-plan-v1.json` | P5A-R2 layout probe patch plan | Machine-readable no-behavior 0013 probe-patch contract, source anchors, absence checks, measurement requirements, and non-claim flags |
| `sched-exec-lease-p5a-r2-vruntime-sentinel-gate-v1.json` | P5A-R2 vruntime representation gate | Machine-readable literal-sentinel counterexample, validity-plus-wrap-min contract, group/current boundaries, source anchors, and non-claim flags |
| `sched-exec-lease-p5a-r2-summary-update-closure-map-v1.json` | P5A-R2 update-closure gate | Machine-readable rb/current/group/lifecycle/budget/placement/throttle/shared-event closure map, rq-lock ownership, unresolved shared invalidation mechanisms, source anchors, and non-claim flags |
| `sched-exec-lease-p5a-r2-versioned-global-invalidation-fence-v1.json` | P5A-R2 shared invalidation architecture | Machine-readable global generation publication, picker fence, all-rq rebuild, mutation integration, targeted-fanout prerequisites, outer-selector boundary, and non-claim flags |
| `sched-exec-lease-p5a-r2-global-fence-layout-rebuild-evidence-plan-v1.json` | P5A-R2 implementation evidence plan | Machine-readable architecture baselines, candidate layout envelopes, rebuild oracle/race requirements, live lock-hold matrix and rejection limits, build/disassembly gates, and non-claim flags |
| `sched-exec-lease-p5a-r2-expanded-layout-probe-patch-plan-v1.json` | P5A-R2 expanded probe patch plan | Machine-readable 0014 one-file scope, exact 51-symbol contract, cacheline derivation, candidate-field absence boundary, validation requirements, and non-claim flags |
| `sched-exec-lease-p5a-r2-e2-disposable-layout-candidate-plan-v1.json` | P5A-R2 E2 disposable layout plan | Machine-readable disposable-worktree boundary, four provisional fields, 59-symbol conditional probe contract, arm64 growth/offset gates, build matrix, and non-claim flags |
| `sched-exec-lease-p5a-r2-e2-x86_64-layout-evidence-plan-v1.json` | P5A-R2 E2 x86_64 evidence plan | Exact E1/candidate identities, arm64 prerequisite, x86_64 cross-toolchain matrix, 51+8 symbol comparison, architecture-local growth gates, and non-claim flags |
| `sched-exec-lease-p5a-r2-e2-layout-evidence-closure-v1.json` | P5A-R2 E2 evidence closure | Exact hashed arm64/x86_64 results, immutable four-field candidate, architecture-local offsets, E3-plan-only freeze, and production/source non-claims |
| `sched-exec-lease-p5a-r2-e3-rebuild-prototype-evidence-plan-v1.json` | P5A-R2 E3 rebuild evidence plan | Exact E2 parent, disposable two-file source boundary, real traversal and independent-oracle obligations, controlled build/QEMU matrix, and production non-claims |
| `sched-exec-lease-p5a-r2-e4-lock-hold-measurement-plan-v1.json` | P5A-R2 E4 lock-hold plan | Exact E3 boundary, real irq/rq lock timing interval, paired controls, immutable 35-cell/10,000-sample matrix, fixed rejection limits, architecture split, and non-claims |
| `sched-exec-lease-p5a-r2-e4-arm64-lock-hold-rejection-v1.json` | P5A-R2 E4 arm64 rejection | Exact source/result hashes, complete 35-cell evidence, breach accounting, full-locked-rebuild rejection, x86_64 stop, and successor-gate boundary |
| `sched-exec-lease-p5a-r3-bucket-local-targeted-projection-v1.json` | P5A-R3 bucket-local successor | E4 rejection trigger, authority-equivalent bucket key, active-rq index and handshake, one-bucket work/lifetime bounds, staged source boundary, and non-claims |
| `sched-exec-lease-p5a-r3-e1-source-locking-lifetime-evidence-plan-v1.json` | P5A-R3 E1 pre-source plan | Finite B_max/depth/memory envelopes, exact two-file E2 layout scope, rq/membership/work ownership, hotplug and RCU drain, E3 race cases, E4 rejection limits, and non-claims |
| `sched-exec-lease-p5a-r3-e3-bucket-concurrency-evidence-plan-v1.json` | P5A-R3 E3 pre-source plan | Exact E2 child/two-file same-TU KUnit boundary, B_max and allocation faults, deterministic publication/work/migration/hotplug/retirement races, independent oracle, sanitizer matrix, and non-claims |
| `sched-exec-lease-p5a-r3-e4-bucket-measurement-plan-v1.json` | P5A-R3 E4 pre-source plan | Exact E3 child/two-file same-TU boundary, real rq-lock one-projection and bounded hotplug timing, targeted fanout availability, paired controls, immutable 42-cell/10,000-pair gates, architecture split, and non-claims |
| `sched-exec-lease-p5a-r3-e4-arm64-bucket-measurement-rejection-v1.json` | P5A-R3 E4 arm64 rejection | Exact complete 42-cell result, post-QEMU parser recovery provenance, 19 rejected cells, 26 breach accounting, R3/x86/E5 stop, and asynchronous-successor gate boundary |
| `sched-exec-lease-p5a-r4-generation-fenced-coalesced-pull-recovery-v1.json` | P5A-R4 successor architecture | Exact R3 trigger, O(1) publication/picker fence, one notifier/owner, newest-generation coalescing, stable-window logical bounds, current-stop separation, source anchors, faults, and non-claims |
| `sched-exec-lease-p5a-r4-e1-dispatch-lifetime-evidence-plan-v1.json` | P5A-R4 E1 pre-source plan | Finite R4 storage/admission, rejected balance callback, irq-work-to-unbound-work bridge, notifier cursor/restart, one-rq owner, hotplug/RCU drain, E3/E4 gates, and non-claims |
| `sched-exec-lease-p5a-r4-e3-concurrency-diagnostic-evidence-plan-v1.json` | P5A-R4 E3 pre-source plan | Exact E2 identity, two-file same-TU KUnit boundary, real irq/work/lock/RCU synthetic protocol, independent receipts/oracle, 36 forced cases, six allocation faults, six dual-architecture diagnostic boots, 76 formal faults, and non-claims |
| `sched-exec-lease-p5a-r4-post-n135-authorization-gate-v1.json` | P5A-R4 post-evidence authorization gate | Exact N-135 hashes, 14-field claim ledger, current upstream touched-path freshness, scope-qualified R4-E3 synthetic acceptance, R4-E4 plan-draft-only authorization, and runtime/production non-claims |
| `sched-exec-lease-p5a-r4-e4-local-quantum-measurement-plan-v1.json` | P5A-R4 E4 local-quantum measurement plan | Exact post-N-135/candidate binding, 14-field claim ledger, refreshed touched-path freshness, seven bounded measurement families, immutable 682-cell/10,000-pair rejection contract, no global settlement gate, separate N-136 boundary, and runtime/production non-claims |
| `sched-exec-lease-p5a-r5-generation-sealed-immutable-projection-v1.json` | P5A-R5 generation-sealed immutable projection successor | Exact closed R4 trigger and distribution, out-of-rq-lock immutable view compilation, sealed receipt, O(1) RCU install, fail-closed picker fence, separate current stop, lifetime/hotplug obligations, and source/runtime non-claims |
| `sched-exec-lease-p5a-r5-e1-eevdf-selector-coherence-rejection-v1.json` | P5A-R5 E1 EEVDF selector-coherence rejection | Exact R5 prerequisite, current dynamic EEVDF tree/augmentation/weighted-state anchors, immutable-view contradiction, safe stale refusal, stale-trust and allowed-progress counterexamples, pre-source rejection, and non-claims |
| `sched-exec-lease-p5a-r6-sealed-masked-domain-forest-v1.json` | P5A-R6 sealed masked domain forest successor | Exact R5 rejection trigger, three-candidate comparison, immutable 64-bit authorization plane, mutable per-slot EEVDF queues and fixed-depth top selector, task/lifetime/fairness boundaries, and source/runtime non-claims |
| `sched-exec-lease-p5a-r6-e1-domain-forest-evidence-plan-v1.json` | P5A-R6 E1 domain-forest evidence plan | Exact R6 binding, sealed root-domain/cgroup composition, 64-slot two-phase 254-visit selector, equal-domain fairness, 98,304-byte private-rq envelope, task/migration/hotplug lifetime, exact E2 scope, E3/E4 rejection gates, and non-claims |
| `sched-exec-lease-p5a-r6-e3-correctness-concurrency-evidence-plan-v1.json` | P5A-R6 E3 correctness/concurrency evidence plan | Exact closed E2 binding, two-file same-TU default-off KUnit boundary, independent 64-leaf oracle, 55 mask/fairness/hierarchy/task/migration/current/hotplug/lifetime cases, four diagnostic profiles, 79 safety plus 3 liveness faults, and non-claims |
| `dynamic-residency-f0-v5-supervisor-v3-candidate4-pre-full-local-closure-v1.json` | Candidate-4 pre-full local checkpoint | Exact Candidate-4 inputs, claim registry, 1,033 fast hostile regressions, same-UID evidence properties, full `NOT_RUN` status, unclosed authority-disjoint assurance, and all-false external authorization |
