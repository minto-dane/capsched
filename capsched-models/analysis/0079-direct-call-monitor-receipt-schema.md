# Analysis 0079: Direct-Call Monitor Receipt Schema

Status: draft schema with model gate

Date: 2026-06-30

## Purpose

N-115 names the direct-call implementation gate. N-116 fixes the monitor-owned
receipt schema that future Linux-facing surfaces must consume.

The key rule is simple:

```text
Linux may carry, cache, or display direct-call state.
Linux may not mint direct-call authority.
```

## Receipt Families

The schema has five monitor-owned receipt families:

```text
RequestImageReceipt:
  canonical copied request image
  request digest
  replay key / nonce
  caller Domain epoch

SchemaReceipt:
  accepted schema version
  required feature set
  critical field decision
  downgrade rejection result

EntryResultReceipt:
  monitor entry result
  terminal failure or success class
  replay consumption status

ResponseHandleReceipt:
  monitor-minted response handle
  response generation
  Domain epoch
  shadow-cache generation

RevokeReceipt:
  revoke accepted
  revoke completed
  response/shadow invalidation generation
```

Linux-visible shadows are allowed only as derived cache records. They are not
receipts.

## Forbidden Collapses

Reject these shortcuts:

```text
Linux creates RequestImageReceipt
Linux accepts schema
transport/wrapper return becomes EntryResultReceipt
timeout refreshes ResponseHandleReceipt
Linux shadow cache becomes response authority
new response is issued during revoke
revoke complete while in-flight response survives
trace plan becomes runtime coverage
schema presence becomes ABI approval
```

## Failure Modes

Every future direct-call implementation gate must separately handle:

```text
terminal reject
retryable failure
timeout
schema mismatch
unknown critical field
replay collision
stale response shadow
revoke while in flight
response after revoke
Domain epoch mismatch
```

## Model

`formal/0056-direct-call-receipt-schema-model` checks that a design can only
accept the receipt schema after:

```text
request copied by monitor
schema accepted by monitor
entry result minted by monitor
response handle minted by monitor
revoke completed by monitor
Linux shadow derived and invalidated by monitor generation
```

The model remains a design gate. It does not approve Linux code, ABI, tracefs
execution, monitor verification, or production protection.
