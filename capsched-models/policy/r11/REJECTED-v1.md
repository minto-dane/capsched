# R11 G0 v1 Rejected Snapshot

The exact v1 candidate identified by:

```text
g0-candidate-bundle-v1.json
7073 bytes
bcdd6c26c5a651f7630df5d218cbd6fb2f20922e2e03cdf109b68b69a7250037
```

is retained unchanged as negative evidence. Its local integrity checks pass,
but 12 semantic weakenings and five forged-positive review/gate conditions are
accepted by the current checker or schemas. It was rejected before external
review and cannot authorize IR construction, freeze, TLA+, model support, or a
protection claim.

See ADR-0017, Analysis 0214, and Validation 0303. Successor work belongs in the
new `epoch2/` namespace; do not repair the captured v1 artifacts in place.
