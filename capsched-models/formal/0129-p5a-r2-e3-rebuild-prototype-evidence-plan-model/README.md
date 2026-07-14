# Formal 0129: P5A-R2 E3 Rebuild Prototype Evidence Plan

Date: 2026-07-14

Status: pre-source evidence model. It authorizes only creation of the exact
disposable two-file E3 draft after the plan gate passes.

The model separates source boundary, traversal, oracle, and authorization
phases. `Safety` requires the passed E2 closure and exact frozen candidate;
default-off same-translation-unit KUnit isolation; actual rb postorder and
bottom-up cfs_rq traversal with current separate; an independent exhaustive
oracle; start/end generation checks, saturation blocking, and rq-lock
ownership; no forbidden locked operation, topology mutation, runtime
connection, publisher/fanout, or ABI; controlled build plus arm64 QEMU KUnit;
and explicit non-claims.

Twenty-four unsafe configurations remove one indispensable contract family
each and must produce an expected `Safety` counterexample.
