# P5A-R6 Sealed Masked Domain Forest Model

The bounded trace separates a generation-sealed authorization mask from
explicitly mutable per-domain and fixed-depth top-selector state.

The safe model performs an ordinary selector mutation, selects an allowed
domain, publishes a constant-work revocation, and separately observes the
current task stop. Safety requires an exact sealed receipt, frozen slot map,
bounded top selector with an exact 127-node worst case, live selector summary,
verified task slot, pre-admission allocation, denied-branch exclusion, and no
premature source or production claim. The model does not claim logarithmic
selection for an arbitrary allowed mask. Two liveness properties cover
allowed-domain selection and revoked current-task stop.

Unsafe safety configurations break one exact contract field. Unsafe liveness
configurations omit allowed progress or current-stop completion. This is an
architecture gate, not a layout, implementation, fairness, performance, or
production proof.
