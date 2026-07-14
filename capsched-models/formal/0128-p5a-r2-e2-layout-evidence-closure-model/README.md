# Formal 0128: P5A-R2 E2 Layout Evidence Closure

Date: 2026-07-14

Status: evidence-acceptance boundary model. It can freeze the exact disposable
E2 layout for E3 planning but cannot accept production layout or E3 source.

The model requires exact arm64 and x86_64 passed results, immutable source
identity, normal-build absence, exact symbol/table accounting, zero growth,
protected measurements, field bounds, and architecture-local offsets. It
separates E3 planning permission from worktree/source/runtime approval.
Twenty-four unsafe configurations must violate `Safety`.
