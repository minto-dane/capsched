# Analysis 0078: Direct-Call Gap Closure Design

Status: draft design with model gate

Date: 2026-06-30

## Context

N-113 classified the remaining preserved project gaps into 7 semantic
direct-call gap groups:

```text
5 high-severity future Linux/internal anchors
1 future test-only failure-injection surface
1 trace-only observation surface
```

The five high-severity groups are:

```text
DCGAP-004 request envelope builder
DCGAP-005 direct-call wrapper and arch backend
DCGAP-006 schema negotiation query path
DCGAP-007 response-handle shadow refresh
DCGAP-008 control revoke lane
```

## Design Rule

None of these gaps can be closed by adding a Linux helper alone.

They close only when the Linux-facing shape is tied to monitor-owned semantics:

```text
request envelope:
  monitor-owned canonical request image, bounded copy, digest/replay key

direct-call entry:
  monitor entry semantics, register/memory clobber rules, failure ordering

schema negotiation:
  monitor-owned schema acceptance and critical-field downgrade rejection

response shadow:
  monitor-minted response handle, epoch, lifetime, timeout, and revoke order

control revoke:
  monitor-owned revoke priority, replay budget, Domain epoch, and completion
```

Linux may eventually build envelopes, carry calls, cache shadows, or expose
internal helpers, but those are transport/cache surfaces, not authority roots.

## Hard Rejections

Reject any design that treats:

```text
Linux-built envelope as canonical authority
wrapper return code as monitor approval
Linux schema query as schema acceptance authority
timeout or cache refresh as response-handle authority
control lane priority as replay/budget/epoch bypass
trace plan as runtime coverage
test fault injection as live behavior
gap classification as ABI approval
```

## Next Model

`formal/0055-direct-call-gap-closure-model` models this as a gate:

```text
classified gaps
  -> monitor semantics modeled
  -> high gaps closed
  -> design accepted
```

The model deliberately does not approve a Linux patch. It only checks that the
gap closure design cannot imply Linux stubs, ABI, behavior change, runtime
coverage, monitor verification, or production protection.
