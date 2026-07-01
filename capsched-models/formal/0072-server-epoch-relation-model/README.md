# Formal 0072: Server Epoch Relation Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This model checks the server-kind and server-epoch relation required by
analysis/0094.

It refines the N-137 server-ticket model by making Linux server lifecycle
changes explicit. Server start, stop, replenish, parameter update, detach,
attach, fair/ext swap, and CPU teardown must invalidate or force revalidation
of any live server-borrow ticket.

## Required Meaning

```text
server-picked execution requires a live ticket
ticket.server_epoch must equal current server_epoch
ticket.server_kind must equal current server_kind
running still requires lower-task authority and monitor root budget
Linux server runtime cannot refresh or replace authority
stopped server cannot retain live picked execution
```

## Forbidden

```text
ticket surviving replenish as executable authority
ticket surviving fair/ext swap as executable authority
ticket surviving stop/detach/CPU teardown
ticket surviving parameter stop/apply/start
server kind mismatch
server pick without fresh ticket
Linux runtime as authority
protection claim without implementation
```

## Validation

Recorded in:

```text
validation/0111-server-epoch-relation-tlc.md
```

Safe TLC:

```text
107 generated states
32 distinct states
depth 6
```
