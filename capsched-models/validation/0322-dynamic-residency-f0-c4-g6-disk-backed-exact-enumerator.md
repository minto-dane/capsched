# 0322 — Candidate-4 disk-backed exact enumerator validation

## Durable predecessor failure

Run `candidate4-full-20260812T231441Z` used clean source commit
`979bba2b16768f33ba131916e26de3730aa33057`, the installed TCB from
`14f6deecca06ce2f23b5faeb335100af952100ea`, and capture contract
`0a695417dcb6161d6f049431dea8755821e0c4600bf990f4822b274a1f924c6d`.
The child producer reached 8,053,063,680 bytes, received signal 9, and left a
durable root-owned `RAW_CAPTURE_INCOMPLETE` commit.  The exact observation is
`f0-c4-g6-fifth-oom-incomplete-observation-v1.json`.

## Local successor results

The current uninstalled successor passed:

- child/parent/runner hostile baselines: 284/739/44;
- capture contract: 155 hostile mutations and 14 derived checks;
- launcher: one basic and ten hostile cases;
- source snapshot: five hostile cases;
- model memory policy: 31 cases, including unlinked spill arrays and ENOSPC
  descriptor cleanup;
- RAM/spill exact-prefix equivalence: 2,000 expanded, 20,510 states, 24,920
  edges, exact state/frontier/depth/target sequence equality;
- resource policy: 17 checks;
- external-memory guardian recovery: one live mount/loop teardown case;
- five-component supervisor smoke, with five ext4/direct-I/O setup and cleanup
  receipts and no leaked loop devices;
- guardian recovery: three cases;
- reducer boundary: three cases.

The fixed contract canonical digest is
`d5a1b44fc61d3f52542c1596dfe01ed510201486be8b2768ccb4a8901e72effe`.
The current exact-input root is
`4fb77f43f8ec9239fa4784a74fc7086fed1081af7888588ca58270840c5025a0`.

## Disposition

Clean reviewed commit `65d9827916f669363f2a82118b90dee2a7ff664c`
passed committed-state validation, was transferred by complete-history Git
bundle `9dd9c1d426251027a6e9b9890f5e70b4357d6bfc05d5bab8eed7fdd8fc91d252`,
and was installed under artifact manifest
`1c688a1017b59a0763fd0fec29b55b6f4f0a23ea0decffc149072215fe56eb7d`.
The post-install suite repeated every result listed above, plus immutable
toolchain reuse, against installed or byte-identical reviewed artifacts.  A
fresh G6 run is eligible.  No complete G6 capture exists, G7 remains blocked,
and no external or production claim changes.
