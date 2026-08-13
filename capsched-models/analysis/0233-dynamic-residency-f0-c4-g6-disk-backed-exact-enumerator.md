# 0233 — Candidate-4 disk-backed exact enumerator

## Decision

The fifth authority-disjoint G6 attempt,
`candidate4-full-20260812T231441Z`, retained the packed exact-history repair but
again exhausted the sealed 7.5-GiB component boundary.  It ran for
17,709,614,432,074 monotonic nanoseconds before the child producer was killed.
The root supervisor survived, drained the component cgroup, and durably
published `RAW_CAPTURE_INCOMPLETE`; this is a capacity counterexample, not a
semantic counterexample and not positive evidence.

The exact enumerator now stores its fixed-width state columns, exact hash index,
frontier, CSR edges, and coaccessibility graph in unlinked mmap files.  The
Python transition relation, full collision equality, state identity, and
ordered histories are unchanged.  The in-memory array implementation remains
the default outside the sealed capture environment.

## Storage boundary

`F0_C4_EXACT_STORE_DIR=/WORK` selects the external store.  Each component gets
an independently formatted 128-GiB sparse loop-backed ext4 filesystem under
`/var/lib/domainlease-f0-c4/work`.  The loop uses direct I/O, and the candidate
sees a cloned `rw,nosuid,nodev,noexec` mount at `/WORK`.  This keeps dirty and
clean mmap pages reclaimable to VM-native storage without enabling swap or
allowing a hostile candidate to fill the entire VM filesystem.  Capture setup
requires the component bound plus a 10-GiB host reserve.

Spill inodes are unlinked immediately after opening.  A complete component
receipt requires no path-visible objects after exit, cgroup drain, unmount,
loop detach, and backing-file removal.  The guardian applies the same cleanup
after supervisor failure and prior-boot reconciliation.  Tool digests, host
mount identity, capacity, direct-I/O state, mount attributes, allocation after
exit, and cleanup are bound into the root receipt.

## Equivalence and limits

A same-process RAM-versus-spill prefix comparison expanded 2,000 sources and
matched the exact 20,510-state sequence, 24,920 target sequence, frontier, and
depths.  A separate 6,000-source spill profile retained 60,763 states and
74,443 edges.  Its small working set remained cached, so this is not an RSS or
performance improvement claim; the intended property is reclaimability once
the exact graph exceeds RAM.

The full G6 campaign remains unrun for these bytes.  Clean reviewed commit,
VM-native install, source transfer, and the complete short post-install suite
are prerequisites.  G6 remains open, G7 remains blocked, and F0/R11/G0,
protection, performance, cost, and deployment authority remain false.
