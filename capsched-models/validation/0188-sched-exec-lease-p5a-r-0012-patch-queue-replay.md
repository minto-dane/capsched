# Validation 0188: SchedExecLease P5A-R 0012 Patch Queue Replay

Date: 2026-07-04

Status: passed for patch-queue replay metadata after updating
`linux-patches/upstream/base.txt`.

## Purpose

After `0012`, `linux-patches/patches/capsched-linux-l0/series` included
patches `0009` through `0012`, but `linux-patches/upstream/base.txt` still
expected the old `0009` work commit. The recreate script checks the final HEAD
against that field, so the patch queue was not reproducible as written.

This validation fixes that metadata and records the important commit-ID
distinction.

## Result

Updated patch queue expected commit:

```text
file=linux-patches/upstream/base.txt
work_commit=1b572a3fad95b78f4ee89061ba441f77cf24e297
```

Replay command:

```text
DOMAINLEASE_LINUX_REFERENCE=/media/nia/scsiusb/dev/linux-cap/linux
DOMAINLEASE_RECREATE_FETCH=0
./linux-patches/scripts/recreate-capsched-linux-l0.sh \
  build/replay/capsched-linux-l0-0012-replay
```

Use a fresh or disposable target for recreation. The current `./linux` tree is
allowed to remain at the local commit ID while the patch queue records the
replay-normalized commit ID.

Replay final HEAD:

```text
1b572a3fad95b78f4ee89061ba441f77cf24e297
```

Local Linux working-tree HEAD:

```text
bd71af5daeae808ac948cbd12af2663151936f22
```

Tree equality:

```text
local_tree=25dbe4e04baa112ab9a872a897f67bec094df209
replay_tree=25dbe4e04baa112ab9a872a897f67bec094df209
```

## Why Commit IDs Differ

Patch `0011` was authored at:

```text
AuthorDate=2026-07-04 01:31:41 -0400
```

but the original local commit was committed at:

```text
CommitDate=2026-07-04 01:33:06 -0400
```

The recreate script uses:

```text
git am --3way --committer-date-is-author-date
```

so `0011` and descendants replay to normalized commit IDs:

```text
0011 local=38340eceafa88119ba3e0bcdc10f309bfff6462b
0011 replay=75666a9410cde534d491b1f049b7480fd965ac86

0012 local=bd71af5daeae808ac948cbd12af2663151936f22
0012 replay=1b572a3fad95b78f4ee89061ba441f77cf24e297
```

The tree hash is identical, so source/build semantics are unchanged by this
metadata normalization. Validation records that name local commits must say
"local Linux commit" and patch queue recreate records must say
"replay-normalized commit".

## Remaining Limits

This closes patch queue replay metadata only. It does not fix:

```text
0010 missing Signed-off-by in the patch queue
0010 overlong commit message line
0009 strict checkpatch style CHECK
production P5A-R acceptance blockers from validation/0187
```

No runtime denial, complete CFS deny-and-repick, runtime coverage, protection,
cost, deployment, or datacenter claim is added.
