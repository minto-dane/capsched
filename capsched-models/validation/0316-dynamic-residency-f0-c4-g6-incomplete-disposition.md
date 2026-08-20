# Dynamic Residency F0 Candidate-4 G6 Incomplete Disposition

## Result

Run `candidate4-full-20260811T210659Z` finalized fail-closed:

```text
capture_status: RAW_CAPTURE_INCOMPLETE
candidate_bytes_positive_eligible: false
reduction_performed: false
G6 closed: false
G7 eligible: false
```

The public-safe machine record is
`f0-c4-g6-incomplete-observation-v1.json`, SHA-256
`45d937f8922b08a7c6b54ac94a6bbd414313c1a7ff2c0f9b304e94f7b3df3d4f`.
Root-owned raw evidence remains on the dedicated VM and is not copied into the
public repository.

## Bound Identities

```text
installed source commit:
  7895631bcc778b53102486d1767bcccdb2d327af
installed artifact manifest:
  3365ef80c5fad74eeb5b4df45167004bc0cb27467a49a0626b9b798dbb3785f2
capture contract:
  14ca4b5424f448462ff0868689f278f412ee43fe2d32d8372a8cacc78d4fd075
toolchain EROFS image:
  4fadeb77fe5019e0a9ea22ea43b79f07923f587fa90b9636164ab9e396de34ac
toolchain identity:
  e997ecc4d95f1a190ded73e4be1f33227e1f34f1f76ec2bf94a97715bd717842
input root:
  7c3f51c54a54e79651a8750b59ba0c7fb107175e3f60a324e532e402298adebc
raw commit:
  2aebf8fd23e037ab5aa7e6ed8d7c49e1533794c6d9a33b8dc0ce299750d4782b
capture manifest:
  40ac44d7efddb5476ed0e54c7fdc0e8bc6a2ba529cc493fb01cabfac790dca7a
```

The capture completed `static-registries` and `tests`, then the
`child-bundle-producer` exited nonzero.  Its root-owned lifecycle receipt is
SHA-256 `9ceadd6dd0b0f785af7d3bb155205ea4964dfc537e34053d1d498386a78d4cb3`;
stderr is SHA-256
`af97a297a25f194568c9ddcaa490aa60aeb181618b052551325abc0e1d826802`.
The supervisor used `cgroup.kill` and observed `populated 0`.

## Semantic Failure

The exact failure was:

```text
F05-SPV3-ACTION-EFFECT: OBS-032-DESCENDANTS-EXIT:hidden_work
```

This is a Candidate-4 action-effect policy mismatch, not a capture containment,
storage, toolchain, or guardian failure.  Analysis 0228 explains the reachable
interleaving and successor repair.

## Disposition

G1-G5 remain locally closed as mechanism gates.  G6 remains open because no
complete capture exists.  G7 is blocked and no reducer may consume this result
as positive evidence.  The three full-only local claims remain `NOT_RUN` for
the repaired input set, all seven refinement claims remain open, and F0, R11,
K0/G0, semantic freeze, TLA+, Linux/Monitor implementation, protection,
performance, cost, cluster, and deployment claims remain false or open.
