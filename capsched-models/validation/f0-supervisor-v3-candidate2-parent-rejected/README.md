# Supervisor v3 Candidate 2 Parent Rejection

Disposition: `REJECTED`. These bytes are immutable counterexample evidence and
must not be edited in place.

The review covered the exact files in `MANIFEST.sha256`. Reviewer
`019febea-5f2e-7f90-a811-3e7bad7505eb` reproduced the existing 504-case local
mutation pass, then found reachable or structurally accepted counterexamples:

1. A generation-0 publication commitment can complete after a generation-1
   recovery fence.
2. The shared store-attack bound can be exhausted by grant replay, suppressing
   the later post-owner-failure publication attack.
3. A tombstone head conflict does not identify the winning content or writer
   generation.
4. Active-child certificates are fixtures rather than a product-continuous
   execution witness.
5. The owner-failure notice phase is not bound into its parent receipt.
6. Write-field allowlists accept non-stall no-ops and cross-action relabeling.
7. Store security events are not bound to a nonce, commitment, observed head,
   or controller generation.

No full campaign result or F0 credit was granted to this candidate.
