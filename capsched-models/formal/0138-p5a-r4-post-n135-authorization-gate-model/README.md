# Formal 0138: P5A-R4 Post-N135 Authorization Gate

Status: checked with safe pass and 15 expected unsafe counterexamples in
validation/0256

Date: 2026-07-18

## Purpose

Model the separately reviewed transition after N-135. The safe trace accepts
the exact R4-E3 source and concurrency semantics only for the closed virtual
synthetic protocol, then permits drafting an R4-E4 plan without permitting
R4-E4 source or any live Linux boundary.

Acceptance requires the governing plan and source gate, the complete matrix,
two independent closures, a complete claim-ledger row, fresh upstream
observation, fresh touched paths, and a clean candidate merge-tree.

Fifteen unsafe configurations independently remove one prerequisite or add a
forbidden authorization/claim:

```text
missing plan
missing source gate
missing matrix
missing independent closure
missing claim ledger
missing upstream refresh
touched-path drift
merge conflict
premature R4-E4 acceptance/source
primary or patch-queue mutation
runtime claim
bare-metal claim
production claim
multi-cluster/datacenter claim
N-136 runtime-budget conflation
```

The model does not prove Linux runtime behavior. It checks only that the
authorization transition cannot outgrow its recorded evidence.
