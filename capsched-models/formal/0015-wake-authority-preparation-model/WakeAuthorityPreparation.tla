---------------------- MODULE WakeAuthorityPreparation ----------------------
EXTENDS Naturals

VARIABLES
    phase,
    prepared,
    registered,
    blocked,
    wakeQueued,
    taskWaking,
    frozen,
    enqueued,
    running,
    revoked,
    lazyDiscovery

vars == <<phase, prepared, registered, blocked, wakeQueued, taskWaking,
          frozen, enqueued, running, revoked, lazyDiscovery>>

Phases == {
    "Start",
    "Prepared",
    "Blocked",
    "WakeQReady",
    "RejectedBeforeTaskWaking",
    "Frozen",
    "TaskWaking",
    "Enqueued",
    "Running",
    "BadWakeQNoAuthority",
    "BadLazyDiscovery",
    "BadRevokedExecution"
}

TypeOK ==
    /\ phase \in Phases
    /\ prepared \in BOOLEAN
    /\ registered \in BOOLEAN
    /\ blocked \in BOOLEAN
    /\ wakeQueued \in BOOLEAN
    /\ taskWaking \in BOOLEAN
    /\ frozen \in BOOLEAN
    /\ enqueued \in BOOLEAN
    /\ running \in BOOLEAN
    /\ revoked \in BOOLEAN
    /\ lazyDiscovery \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ prepared = FALSE
    /\ registered = FALSE
    /\ blocked = FALSE
    /\ wakeQueued = FALSE
    /\ taskWaking = FALSE
    /\ frozen = FALSE
    /\ enqueued = FALSE
    /\ running = FALSE
    /\ revoked = FALSE
    /\ lazyDiscovery = FALSE

PrepareAuthority ==
    /\ phase = "Start"
    /\ prepared' = TRUE
    /\ phase' = "Prepared"
    /\ UNCHANGED <<registered, blocked, wakeQueued, taskWaking, frozen,
                    enqueued, running, revoked, lazyDiscovery>>

RegisterAndBlock ==
    /\ phase = "Prepared"
    /\ prepared
    /\ registered' = TRUE
    /\ blocked' = TRUE
    /\ phase' = "Blocked"
    /\ UNCHANGED <<prepared, wakeQueued, taskWaking, frozen, enqueued, running,
                    revoked, lazyDiscovery>>

RevokeBeforeWake ==
    /\ phase \in {"Prepared", "Blocked", "WakeQReady"}
    /\ prepared
    /\ ~revoked
    /\ revoked' = TRUE
    /\ UNCHANGED <<phase, prepared, registered, blocked, wakeQueued, taskWaking,
                    frozen, enqueued, running, lazyDiscovery>>

DirectWakeRejectRevoked ==
    /\ phase = "Blocked"
    /\ revoked
    /\ blocked' = FALSE
    /\ phase' = "RejectedBeforeTaskWaking"
    /\ UNCHANGED <<prepared, registered, wakeQueued, taskWaking, frozen,
                    enqueued, running, revoked, lazyDiscovery>>

DirectWakeFreeze ==
    /\ phase = "Blocked"
    /\ prepared
    /\ ~revoked
    /\ frozen' = TRUE
    /\ phase' = "Frozen"
    /\ UNCHANGED <<prepared, registered, blocked, wakeQueued, taskWaking,
                    enqueued, running, revoked, lazyDiscovery>>

WakeQAddPrepared ==
    /\ phase = "Blocked"
    /\ prepared
    /\ ~revoked
    /\ wakeQueued' = TRUE
    /\ phase' = "WakeQReady"
    /\ UNCHANGED <<prepared, registered, blocked, taskWaking, frozen, enqueued,
                    running, revoked, lazyDiscovery>>

WakeQRejectRevoked ==
    /\ phase = "WakeQReady"
    /\ revoked
    /\ blocked' = FALSE
    /\ phase' = "RejectedBeforeTaskWaking"
    /\ UNCHANGED <<prepared, registered, wakeQueued, taskWaking, frozen,
                    enqueued, running, revoked, lazyDiscovery>>

WakeQFreeze ==
    /\ phase = "WakeQReady"
    /\ prepared
    /\ ~revoked
    /\ frozen' = TRUE
    /\ phase' = "Frozen"
    /\ UNCHANGED <<prepared, registered, blocked, wakeQueued, taskWaking,
                    enqueued, running, revoked, lazyDiscovery>>

SetTaskWaking ==
    /\ phase = "Frozen"
    /\ frozen
    /\ prepared
    /\ ~revoked
    /\ taskWaking' = TRUE
    /\ phase' = "TaskWaking"
    /\ UNCHANGED <<prepared, registered, blocked, wakeQueued, frozen,
                    enqueued, running, revoked, lazyDiscovery>>

Enqueue ==
    /\ phase = "TaskWaking"
    /\ taskWaking
    /\ frozen
    /\ prepared
    /\ ~revoked
    /\ enqueued' = TRUE
    /\ phase' = "Enqueued"
    /\ UNCHANGED <<prepared, registered, blocked, wakeQueued, taskWaking,
                    frozen, running, revoked, lazyDiscovery>>

Run ==
    /\ phase = "Enqueued"
    /\ enqueued
    /\ prepared
    /\ ~revoked
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<prepared, registered, blocked, wakeQueued, taskWaking,
                    frozen, enqueued, revoked, lazyDiscovery>>

UnsafeWakeQAddWithoutPrepared ==
    /\ phase = "Start"
    /\ ~prepared
    /\ wakeQueued' = TRUE
    /\ phase' = "BadWakeQNoAuthority"
    /\ UNCHANGED <<prepared, registered, blocked, taskWaking, frozen, enqueued,
                    running, revoked, lazyDiscovery>>

UnsafeLazyDiscoveryAtF1 ==
    /\ phase = "Start"
    /\ ~prepared
    /\ lazyDiscovery' = TRUE
    /\ frozen' = TRUE
    /\ taskWaking' = TRUE
    /\ phase' = "BadLazyDiscovery"
    /\ UNCHANGED <<prepared, registered, blocked, wakeQueued, enqueued, running,
                    revoked>>

UnsafeIgnoreRevokeAfterWakeQ ==
    /\ phase = "WakeQReady"
    /\ revoked
    /\ frozen' = TRUE
    /\ taskWaking' = TRUE
    /\ enqueued' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRevokedExecution"
    /\ UNCHANGED <<prepared, registered, blocked, wakeQueued, revoked,
                    lazyDiscovery>>

SafeNext ==
    \/ PrepareAuthority
    \/ RegisterAndBlock
    \/ RevokeBeforeWake
    \/ DirectWakeRejectRevoked
    \/ DirectWakeFreeze
    \/ WakeQAddPrepared
    \/ WakeQRejectRevoked
    \/ WakeQFreeze
    \/ SetTaskWaking
    \/ Enqueue
    \/ Run

UnsafeNext ==
    \/ SafeNext
    \/ UnsafeWakeQAddWithoutPrepared
    \/ UnsafeLazyDiscoveryAtF1
    \/ UnsafeIgnoreRevokeAfterWakeQ

SafeSpec == Init /\ [][SafeNext]_vars
UnsafeSpec == Init /\ [][UnsafeNext]_vars

NoWakeQWithoutPreparedAuthority ==
    wakeQueued => prepared

NoF1LazyDiscovery ==
    ~lazyDiscovery

NoTaskWakingWithoutPreparedFrozenUse ==
    taskWaking =>
        /\ prepared
        /\ frozen
        /\ ~revoked

NoEnqueueWithoutPreparedFrozenUse ==
    enqueued =>
        /\ prepared
        /\ frozen
        /\ taskWaking
        /\ ~revoked

NoExecutionAfterRevocation ==
    running => ~revoked

RejectRevokedBeforeTaskWaking ==
    (phase = "RejectedBeforeTaskWaking") =>
        /\ ~taskWaking
        /\ ~enqueued
        /\ ~running

=============================================================================
