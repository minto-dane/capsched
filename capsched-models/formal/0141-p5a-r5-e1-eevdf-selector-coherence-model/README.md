# P5A-R5 E1 EEVDF Selector-Coherence Model

The bounded trace starts with a generation-matched immutable selector view,
then performs an ordinary EEVDF state mutation without changing authority
generation.

The safe configuration refuses the now-stale view and passes the safety
invariant. The unsafe configuration trusts it and must violate safety. Adding
eventual allowed selection to the safe configuration must produce a liveness
counterexample because the allowed runnable entity remains blocked.

This establishes the specific R5 E1 contradiction, not a universal scheduler
impossibility result. A future successor may use explicitly mutable,
rq-lock-maintained authorization augmentation, but that is not the immutable
selector view accepted by the R5 architecture gate.
