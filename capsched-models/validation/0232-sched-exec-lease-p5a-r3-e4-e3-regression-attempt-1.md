# Validation 0232: SchedExecLease P5A-R3 E4 Exact-Source E3 Regression Attempt 1

Date: 2026-07-16

Status: infrastructure failure before the first boot. The exact-E4-source E3
regression remains unpassed, and E4 measurement remains blocked. A fresh rerun
on Apple Container internal ext4 storage is authorized; reuse or repair of the
attempt-1 build is not.

## Attempt

Detached job `p5a-r3-e4-e3-regression`, run
`20260716T-p5a-r3-e4-e3-regression`, consumed the passed source gate from
validation/0231 and started the arm64 standard-debug image on the exact E4
commit `f20c62a2ad5aec4347dc7c8c4d81e3f7fa1f3da1`. Its build output was on the
case-sensitive APFS sparsebundle exported into the Apple Container machine by
virtiofs.

The compiler completed 10,300 compiler/link steps. The final `vmlinux.o` link
then rejected `fs/ext4/mballoc.o` as not an object, and the runner exited 1
before QEMU. No result JSON exists and no runtime case is credited.

## Storage-Corruption Classification

The rejected object was 610,096 bytes but had lost its ELF header and the first
348,160 bytes. Its SHA-256 was:

```text
657f3ac105ad4a030c1a2d9a4920808e577f9b945bdda1a864b2c1921be38e61
```

The corrupt bytes, stat data, header dump, file classification, and SHA-256 are
preserved under:

```text
build/source-check/
  sched-exec-lease-p5a-r3-e4-e3-regression-diagnostic/
    20260716T-p5a-r3-e4-e3-regression/storage-corruption/
```

Recompiling only `fs/ext4/mballoc.o` with the unchanged source, config, GCC,
and command produced a valid AArch64 ELF relocatable object with SHA-256:

```text
c7e02089edf15ec3ccae08d56a9df9f4a561680fb5c9511f2f4eb7568d0fa0bc
```

Resuming the link passed that member and reached a second unrelated damaged
member, `crypto/chacha.o`. That object was 100% zero bytes and had SHA-256:

```text
506ef5d3c506340041cbf68a345ca43578eabe352f786ad3fa34c61355c87833
```

A header scan covered 9,172 generated `.o` files after the `mballoc.o`
rebuild and identified `chacha.o` as the remaining non-ELF member. These two
independent corruptions, plus the successful same-command rebuild, classify
attempt 1 as shared-build-storage corruption under critical host capacity
pressure rather than a candidate-source, config, compiler, or linker defect.
The failed output was deleted only after both corrupt originals and the full
build/config logs were preserved.

## Corrected Rerun Contract

The runner now requires a fresh build root below
`/var/tmp/linux-cap-builds/p5a-r3-e4-e3-regression/` and verifies that it is on
the Apple Container machine's internal ext4-compatible filesystem with at
least 16 GiB available. It refuses shared-host build output.

After each successful QEMU boot, the exact booted `Image` or `bzImage` and
`kernel/sched/exec_lease.o` are compressed losslessly with zstd level 9. The
runner tests both archives and requires decompressed SHA-256 equality before
pruning that boot's intermediate build output. This preserves the tested
artifacts while bounding peak scratch use to one boot configuration rather
than four accumulated configurations.

Any future linker report that an archive member is not an object is itself
captured as a lossless zstd artifact with original, archive, and restored
SHA-256 values. It remains a run failure; the runner does not repair and accept
the same run.

Corrected config-smoke run
`20260716T-p5a-r3-e4-e3-regression-internal-smoke` passed all four fresh
configs on internal ext4:

```text
arm64 standard debug:   E3 suite on, E4 measurement off
x86_64 standard debug:  E3 suite on, E4 measurement off
arm64 generic KASAN:    E3 suite on, E4 measurement off
x86_64 strict KCSAN:    E3 suite on, E4 measurement off
```

The same smoke run then compiled `kernel/sched/exec_lease.o` on internal ext4,
validated its AArch64 ELF header, compressed it with the production zstd path,
verified decompressed SHA-256 equality at
`5399d31903cd497555c31eb55f2741c33a841f36bac3ae717673745c84705e7b`,
and removed the internal scratch tree.

The exact four-boot pass remains required before
`e4_measurement_may_start=true`. Attempt 1 and its targeted rebuild provide no
E3 regression pass, E4 measurement acceptance, runtime behavior, protection,
latency, performance, cost, deployment, or datacenter claim.
