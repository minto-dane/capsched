# Direct-Call Gap Closure Model

This model checks the N-114 direct-call gap-closure gate.

It starts from the N-113 classification:

```text
14 preserved gap rows
7 semantic gap groups
5 high-severity future Linux/internal anchor groups
```

The safe model accepts only a design-level closure where all five high-severity
groups are tied to monitor-owned request schema, replay, response handle, epoch,
and revoke-ordering semantics. It does not approve Linux stubs, ABI, tracepoints,
behavior changes, monitor verification claims, or production protection claims.

Unsafe configurations check the rejected shortcuts:

```text
Linux stub before gap closure
Linux-built envelope as canonical monitor image
direct-call entry without monitor schema
Linux schema decision
timeout refresh of response authority
control revoke priority bypass
trace plan as runtime coverage
test hook live effect
ABI approval
behavior change
monitor verification claim
protection claim
```
