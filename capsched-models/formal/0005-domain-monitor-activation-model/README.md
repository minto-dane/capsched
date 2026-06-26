# Formal 0005: Domain Monitor Activation Model

Status: Checked by TLC in tiny finite model

Date: 2026-06-26

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 0b685979f27b3d42ee620ced5f707ee391a2a27f
```

## Purpose

This model makes the monitor placeholder in the Runnable Lease model more
concrete. It checks the minimum handoff rule between a Linux-selected task and a
monitor-backed execution context:

```text
No monitor token, no active DomainTag.
No active DomainTag, no execution.
```

It is still a small semantic model, not a real MMU, TLB, KVM, pKVM, or VMX-root
model.

## Files

```text
DomainMonitor.tla
DomainMonitor.cfg
notes.md
```

## Core Idea

The model separates:

```text
linuxTag:
  Mutable Linux shadow/request state. It can be forged by an adversarial Linux
  action in the model.

runGrant:
  Linux-visible grant produced before monitor activation. It carries Domain,
  epoch, MemoryView, and allowed CPUs.

runToken:
  Monitor-owned sealed activation token for one CPU and one task.

activeDomain / activeMemView:
  Monitor-owned CPU-local authority state. This is the state that matters for
  execution.

rootBudget:
  Monitor-owned per-Domain CPU budget.
```

The important distinction is that `linuxTag` may be wrong, stale, or malicious,
but it never creates active execution authority by itself.

## Encoded Safety Properties

```text
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

## Expected Validation

Run from this directory:

```text
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC DomainMonitor.tla
```

The configuration intentionally uses a tiny finite model:

```text
2 Domains
2 tasks
2 CPUs
2 MemoryViews
root budget: 0..2
epochs: 0..1
```

## Design Questions This Model Pressures

1. Linux-visible Domain labels are not authority. They are requests, cache, or
   policy state unless backed by a monitor token.
2. Cross-Domain context switch must be a monitor activation event, not only a
   scheduler bookkeeping update.
3. Monitor epoch revocation must clear active tokens, active DomainTags, and
   selected tasks for the revoked Domain.
4. Root budget is below Linux. A running Domain cannot remain active after root
   budget reaches zero.
5. Co-tenancy policy belongs in the activation decision, not only in ordinary
   scheduler placement.
