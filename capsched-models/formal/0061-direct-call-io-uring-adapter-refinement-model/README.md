# Direct-Call io_uring Adapter Refinement Model

This model checks the io_uring side of the async-carrier adapter split.

It refines the broad N-126 API sketch into an io_uring-specific
request/resource/worker/completion model.

Safe design pressure:

```text
allocate request storage without authority
consume SQE before freezing caller authority
freeze before inline issue or io-wq publication
bind fixed file/buffer authority separately from resource liveness
preserve resource generation snapshot
select io-wq worker without worker authority
handle REQ_F_REISSUE without receipt refresh
handle cancel without monitor revoke proof
revoke_check before validate
side effects only after validate
CQE is result delivery only
settle exactly once
release only CapSched refs, not Linux request/resource refs
```

Unsafe configurations reject:

```text
side effect before validate
immutable carrier overwrite
io_kiocb authority
io_wq_work authority
req->creds, req->tctx, or SQPOLL authority
io_rsrc_node liveness authority
REQ_F_REISSUE receipt refresh
CQE settlement proof
cancel as monitor revoke receipt
double settlement
release dropping Linux refs
stale execution after revoke
linked request implicit authority inheritance
resource update mutating in-flight authority
uring_cmd without typed endpoint authority
ABI approval
behavior change
monitor verification claim
production protection claim
```

This is not Linux implementation, runtime coverage, ABI approval, monitor
verification, behavior change, or production protection.
