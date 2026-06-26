# Validation 0007: Domain Monitor Activation TLC Check

Status: Passed for tiny finite model

Date: 2026-06-26

## Scope

Formal model:

```text
capsched/capsched-models/formal/0005-domain-monitor-activation-model/
```

This validation checks the `DomainMonitor.tla` model with TLC. The model is a
small finite state machine for the boundary between Linux-selected work and a
monitor-owned active DomainTag, MemoryView, RunToken, and root CPU budget.

## Commands

Run from:

```text
/media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/formal/0005-domain-monitor-activation-model
```

Primary command:

```text
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC DomainMonitor.tla
```

Second command, same model and invariants, different fingerprint index and
parallel workers:

```text
java -XX:+UseParallelGC -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC -workers 8 -fp 1 DomainMonitor.tla
```

## Configuration

```text
2 Domains
2 tasks
2 CPUs
2 MemoryViews
root budget: 0..2
epochs: 0..1
```

Config file:

```text
DomainMonitor.cfg
```

## Checked Invariants

```text
TypeOK
NoActiveWithoutMonitorToken
NoActiveWithoutGrant
NoActiveWithStaleEpoch
NoActiveWithWrongMemoryView
NoActiveOutsideAllowedCpu
NoActiveWithoutRootBudget
NoTokenAfterRevocation
NoLinuxTagConfersAuthority
NoForbiddenCoTenancy
NoTaskOnTwoCpus
NoBudgetUnderflow
```

## TLC Result

Primary run:

```text
TLC2 Version 2.19 of 08 August 2024
Model checking completed. No error has been found.
82993249 states generated
1916784 distinct states found
0 states left on queue
complete state graph depth: 19
finished in 04min 48s
```

Second run:

```text
TLC2 Version 2.19 of 08 August 2024
Model checking completed. No error has been found.
82993249 states generated
1916784 distinct states found
0 states left on queue
complete state graph depth: 19
finished in 03min 05s
```

## Interpretation

For this finite model, TLC found no counterexample to the core monitor
activation claim:

```text
No monitor token, no active DomainTag.
No active DomainTag, no execution.
```

The model deliberately allows Linux to forge mutable `linuxTag` shadow state.
The checked invariants require that this forged Linux state cannot create active
execution authority without monitor-owned `runToken`, `activeDomain`, and
`activeMemView` state.

The model also reinforces:

```text
Cross-Domain activation is a monitor decision.
Epoch revocation clears active tokens and active DomainTags.
Root CPU budget must be enforceable below Linux scheduler policy.
Co-tenancy policy is part of the activation boundary.
```

## Limits

This validation does not prove a real HyperTag Monitor, EPT/stage-2 switching,
TLB shootdown, interrupt return sequencing, IOMMU isolation, Linux context
switch locking, or side-channel safety. It is a semantic gate for monitor-owned
Domain activation only.
