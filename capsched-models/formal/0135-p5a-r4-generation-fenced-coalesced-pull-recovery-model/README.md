# P5A-R4 Generation-Fenced Coalesced Pull Recovery Model

This bounded model checks the N-130 architecture decision over one bucket and
two active runqueues.

The trace deliberately includes an old-generation partial notifier pass, a
second eligible generation before a stable window, a picker mismatch, a
coalesced newest-generation update, completion and restart of the notifier
cursor, bounded per-rq recovery quanta, an ineligible publication, a separate
current reschedule request, and final Blocked settlement. The stable notifier
trace uses three quanta for two active rqs, exercising the conservative `2*A`
restart bound rather than only an uninterrupted one-pass case.

`Safety` checks that a mismatch is never trusted, publisher work stays O(1),
notifier and rq-owner depth stay one, dirty depth is bounded, the newest stable
generation is installed, current stop-request delivery is separate, and
revoked projections finish Blocked. The safe configuration also checks two
temporal properties under explicit weak fairness: stable eligible recovery and
stable revoked recovery.

The logical liveness bound is not wall-clock evidence. Infinite publication is
allowed to preserve fail-closed safety without availability; liveness applies
only after a stable window. The model does not approve source, runtime
behavior, monitor enforcement, protection, latency, performance, or cost.
