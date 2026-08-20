# Validation 0249: SchedExecLease P5A-R4 E3 Corrected Source-Gate Closure

Date: 2026-07-17

Status: the corrected direct-E2-child source gate is independently closed.
Only a complete, unreduced retry of all six diagnostic boots is authorized.
No source or concurrency-correctness claim is accepted.

## Corrected Source Gate

Run `20260717T-p5a-r4-e3-source-gate-r3` binds:

```text
candidate: da9ce9159b3450c28c8faf8dceac671fb7bfeba2
parent:    a429fc30252ac6af94c51d96cd4ac24e72d9f83b
tree:      58c6510c6f517004e37107786d006bb8333b79b8
diff sha:  096d99b527bd1b433ecd07165696830f9316d07cc67484687d95cd2c2a846f08
result:    f76ea8d4aef69a89cf93be4f20dfb3ce6bfa9f25ede61cfa9b92048d775f9b24
runner:    bbbd4090d37c6836a89b47fa8709e1aa21b4998ba3e067dd30dd6f4c83df4c27
```

The gate rebuilt the exact E2 parent and corrected candidate in four fresh
modes on arm64 and x86_64. It preserved all 58 R4-private and 51 expanded
values, emitted no disabled E3 symbol/relocation/string/initcall, and reported
zero W=1 compiler diagnostics.

Two x86_64 initial builds detected sub-3ms future mtimes in objtool command
files. The runner immediately rebuilt the same targets. Closure requires the
eight initial warning lines to occur only in layout-on/test-off and test-on,
requires exactly those two verification logs to be nonempty, and rejects any
compiler diagnostic or clock-skew line in every verification log. The final
clock-skew count is zero; the retries are retained evidence, not erased.

## Independent Closures

The same closure runner, SHA-256
`ac1e02336e490d7d74d58cb52128990a4e50f7389b9bb356981f8cedd7300271`,
ran twice:

```text
r3 result: f6763fbb940c42d67390cae46c20e148f86020a3c2af4431e12562c198fcf613
r4 result: 92e9918d0c04147a9b78c66744081cf165564458204a18c43501d82617318e6e
normalized: 01ca034cf59238314882bce35eeffb617b093ca9d4e99b2bbefe48096f3c04a6
snapshot manifest: f86d75d264c09de2ea50a06fcbaf06599a58557373aba04b8b2e7429bdfeaec9
```

Each closure copied all 105 source-gate artifacts read-only, compared
before/after/snapshot manifests, revalidated the plan and N-133 inputs,
recomputed Git identity and every source blob, audited eight build and eight
verification logs, and proved build scratch plus temporary worktrees absent.
Both closures also bind the prior 34/36 six-boot rejection record SHA-256
`c67648292f091d79e752c174f4360deee6b0a22ae696d7cbf76d5fd13cc22871`
and its original console/KTAP hashes.

## Authorization Boundary

N-134 is complete for corrected candidate `da9ce915...`. The previous failed
matrix is not converted into a partial pass, and its five unstarted boots are
not credited. A fresh runner must resolve the exact six configurations and
then execute all six with no reduction. R4-E3 source correctness, concurrency
correctness, runtime scheduler behavior, production protection, deployment,
multi-node, multi-cluster, and datacenter readiness remain false.
