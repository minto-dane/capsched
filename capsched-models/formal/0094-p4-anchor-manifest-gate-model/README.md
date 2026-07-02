# P4 Anchor Manifest Gate

This model checks the semantic shape of the P4 anchor manifest.

The source checker proves the concrete Linux patterns and line ordering. This
TLA model proves the manifest cannot be treated as:

- P4 implementation approval;
- P4 runtime denial approval;
- P5 denial safety;
- runtime coverage evidence;
- monitor verification;
- production or hypervisor-grade protection;
- cost-efficiency or deployment readiness.

The safe state has all three P4 anchors present:

```text
A1 final run allow-all join
A2 common queued move allow-all edge
A3 double-rq locked queued move allow-all edge
```

It also records explicit non-coverage for fair direct movement, sched_ext,
core/proxy, async, hotplug, monitor, and production protection paths.
