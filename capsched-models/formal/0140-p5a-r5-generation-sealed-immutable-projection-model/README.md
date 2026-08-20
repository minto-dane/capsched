# P5A-R5 Generation-Sealed Immutable Projection Model

This bounded model checks the source-free R5 successor decision over one
authority descriptor and two demanded runqueues.

The trace release-publishes a new generation and membership sequence, observes
both old views as untrusted, coalesces one compile owner per rq, builds sealed
views outside rq-lock install phases, installs exact-generation views in
constant work, publishes revocation, records a separate current-stop
observation, and installs explicit Blocked views.

`Safety` checks that stale state is never trusted, publisher and install work
remain bounded, owner depth remains one, exact generation/membership receipts
are installed, current-stop observation remains separate, and the terminal
revoked state is Blocked. Two weak-fair temporal properties check stable
eligible demand installation and stable revoked demand blocking.

The model also converts every missing trigger, receipt, lock/lifetime rule,
failure behavior, or claim boundary in the JSON contract into an expected
unsafe counterexample. It does not prove a Linux representation, scheduler
behavior, monitor authority, latency, performance, protection, or production
readiness.
