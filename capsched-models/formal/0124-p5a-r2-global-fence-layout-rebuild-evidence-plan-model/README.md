# Formal 0124: P5A-R2 Global-Fence Layout/Rebuild Evidence Plan

Date: 2026-07-13

Status: evidence-plan model. No Linux patch, hot field, rebuild prototype, or
runtime/performance claim is approved.

The model gates the evidence plan required before the conservative global
generation fence may receive even a disposable layout or rebuild candidate.
It requires architecture-local x86_64/arm64 baselines, strict structure-growth
and offset envelopes, staged build-only/layout-only/test-only work, an oracle
for wrap-aware tree/current/group correctness, publication-race coverage,
source-proved bottom-up traversal, and explicit live rq-lock latency rejection
limits.

The safe model reaches `Ready` only with the full evidence contract. Thirty-two
unsafe configurations each remove one required evidence element or add one
premature implementation/runtime/protection/cost claim and must produce a
`Safety` counterexample.
