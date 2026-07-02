# P4 Allow-Only Skeleton Gate

This model records the post-patch P4 state:

```text
P4 skeleton recorded == true
P4 accepted == false until full build and QEMU validation pass
P5 denial approved == false
```

It rejects helper non-ALLOW returns, missing source/replay/checkpatch/build
evidence, scheduler branching on validation results, emitted validation helper
symbols, ABI/monitor/budget side effects, runtime-denial claims, and
protection/cost/deployment overclaims.
