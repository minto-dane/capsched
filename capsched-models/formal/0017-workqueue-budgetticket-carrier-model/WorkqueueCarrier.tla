------------------------ MODULE WorkqueueCarrier ------------------------
EXTENDS Naturals

VARIABLES
    phase,
    prepared,
    queued,
    delayed,
    pending,
    running,
    completed,
    canceled,
    callerLive,
    serviceLive,
    budgetLive,
    endpointFrozen,
    refsHeld,
    ambientUsed,
    overwritten,
    mergeMode

vars == <<phase, prepared, queued, delayed, pending, running, completed,
          canceled, callerLive, serviceLive, budgetLive, endpointFrozen,
          refsHeld, ambientUsed, overwritten, mergeMode>>

Phases == {
    "Start",
    "Prepared",
    "Queued",
    "Delayed",
    "Running",
    "Completed",
    "Canceled",
    "RevokedClosed",
    "BadQueueNoCarrier",
    "BadAmbientRun",
    "BadRunAfterRevoke",
    "BadOverwritePending",
    "BadDeadRefs"
}

TypeOK ==
    /\ phase \in Phases
    /\ prepared \in BOOLEAN
    /\ queued \in BOOLEAN
    /\ delayed \in BOOLEAN
    /\ pending \in BOOLEAN
    /\ running \in BOOLEAN
    /\ completed \in BOOLEAN
    /\ canceled \in BOOLEAN
    /\ callerLive \in BOOLEAN
    /\ serviceLive \in BOOLEAN
    /\ budgetLive \in BOOLEAN
    /\ endpointFrozen \in BOOLEAN
    /\ refsHeld \in BOOLEAN
    /\ ambientUsed \in BOOLEAN
    /\ overwritten \in BOOLEAN
    /\ mergeMode \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ prepared = FALSE
    /\ queued = FALSE
    /\ delayed = FALSE
    /\ pending = FALSE
    /\ running = FALSE
    /\ completed = FALSE
    /\ canceled = FALSE
    /\ callerLive = FALSE
    /\ serviceLive = FALSE
    /\ budgetLive = FALSE
    /\ endpointFrozen = FALSE
    /\ refsHeld = FALSE
    /\ ambientUsed = FALSE
    /\ overwritten = FALSE
    /\ mergeMode = FALSE

PrepareCarrier ==
    /\ phase = "Start"
    /\ prepared' = TRUE
    /\ callerLive' = TRUE
    /\ serviceLive' = TRUE
    /\ budgetLive' = TRUE
    /\ endpointFrozen' = TRUE
    /\ refsHeld' = TRUE
    /\ phase' = "Prepared"
    /\ UNCHANGED <<queued, delayed, pending, running, completed, canceled,
                    ambientUsed, overwritten, mergeMode>>

QueuePreparedWork ==
    /\ phase = "Prepared"
    /\ prepared
    /\ callerLive
    /\ serviceLive
    /\ budgetLive
    /\ endpointFrozen
    /\ queued' = TRUE
    /\ pending' = TRUE
    /\ phase' = "Queued"
    /\ UNCHANGED <<prepared, delayed, running, completed, canceled,
                    callerLive, serviceLive, budgetLive, endpointFrozen,
                    refsHeld, ambientUsed, overwritten, mergeMode>>

QueueDelayedWork ==
    /\ phase = "Prepared"
    /\ prepared
    /\ callerLive
    /\ serviceLive
    /\ budgetLive
    /\ endpointFrozen
    /\ delayed' = TRUE
    /\ phase' = "Delayed"
    /\ UNCHANGED <<prepared, queued, pending, running, completed, canceled,
                    callerLive, serviceLive, budgetLive, endpointFrozen,
                    refsHeld, ambientUsed, overwritten, mergeMode>>

TimerFireQueue ==
    /\ phase = "Delayed"
    /\ delayed
    /\ prepared
    /\ callerLive
    /\ serviceLive
    /\ budgetLive
    /\ endpointFrozen
    /\ delayed' = FALSE
    /\ queued' = TRUE
    /\ pending' = TRUE
    /\ phase' = "Queued"
    /\ UNCHANGED <<prepared, running, completed, canceled, callerLive,
                    serviceLive, budgetLive, endpointFrozen, refsHeld,
                    ambientUsed, overwritten, mergeMode>>

DispatchToWorker ==
    /\ phase = "Queued"
    /\ pending
    /\ prepared
    /\ callerLive
    /\ serviceLive
    /\ budgetLive
    /\ endpointFrozen
    /\ pending' = FALSE
    /\ queued' = FALSE
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<prepared, delayed, completed, canceled, callerLive,
                    serviceLive, budgetLive, endpointFrozen, refsHeld,
                    ambientUsed, overwritten, mergeMode>>

CompleteWork ==
    /\ phase = "Running"
    /\ running
    /\ running' = FALSE
    /\ completed' = TRUE
    /\ prepared' = FALSE
    /\ callerLive' = FALSE
    /\ serviceLive' = FALSE
    /\ budgetLive' = FALSE
    /\ endpointFrozen' = FALSE
    /\ refsHeld' = FALSE
    /\ phase' = "Completed"
    /\ UNCHANGED <<queued, delayed, pending, canceled, ambientUsed,
                    overwritten, mergeMode>>

CancelPendingWork ==
    /\ phase \in {"Queued", "Delayed"}
    /\ ~running
    /\ queued' = FALSE
    /\ delayed' = FALSE
    /\ pending' = FALSE
    /\ canceled' = TRUE
    /\ prepared' = FALSE
    /\ callerLive' = FALSE
    /\ serviceLive' = FALSE
    /\ budgetLive' = FALSE
    /\ endpointFrozen' = FALSE
    /\ refsHeld' = FALSE
    /\ phase' = "Canceled"
    /\ UNCHANGED <<running, completed, ambientUsed, overwritten, mergeMode>>

RevokeBeforeRun ==
    /\ phase \in {"Queued", "Delayed"}
    /\ ~running
    /\ callerLive
    /\ callerLive' = FALSE
    /\ queued' = FALSE
    /\ delayed' = FALSE
    /\ pending' = FALSE
    /\ prepared' = FALSE
    /\ budgetLive' = FALSE
    /\ endpointFrozen' = FALSE
    /\ refsHeld' = FALSE
    /\ phase' = "RevokedClosed"
    /\ UNCHANGED <<running, completed, canceled, serviceLive, ambientUsed,
                    overwritten, mergeMode>>

RevokeRunning ==
    /\ phase = "Running"
    /\ running
    /\ callerLive
    /\ callerLive' = FALSE
    /\ running' = FALSE
    /\ prepared' = FALSE
    /\ budgetLive' = FALSE
    /\ endpointFrozen' = FALSE
    /\ refsHeld' = FALSE
    /\ phase' = "RevokedClosed"
    /\ UNCHANGED <<queued, delayed, pending, completed, canceled,
                    serviceLive, ambientUsed, overwritten, mergeMode>>

UnsafeQueueWithoutCarrier ==
    /\ phase = "Start"
    /\ ~prepared
    /\ queued' = TRUE
    /\ pending' = TRUE
    /\ phase' = "BadQueueNoCarrier"
    /\ UNCHANGED <<prepared, delayed, running, completed, canceled,
                    callerLive, serviceLive, budgetLive, endpointFrozen,
                    refsHeld, ambientUsed, overwritten, mergeMode>>

UnsafeAmbientWorkerRun ==
    /\ phase = "Queued"
    /\ pending
    /\ ambientUsed' = TRUE
    /\ pending' = FALSE
    /\ queued' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadAmbientRun"
    /\ UNCHANGED <<prepared, delayed, completed, canceled, callerLive,
                    serviceLive, budgetLive, endpointFrozen, refsHeld,
                    overwritten, mergeMode>>

UnsafeRunAfterCallerRevoke ==
    /\ phase = "Queued"
    /\ pending
    /\ callerLive' = FALSE
    /\ pending' = FALSE
    /\ queued' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadRunAfterRevoke"
    /\ UNCHANGED <<prepared, delayed, completed, canceled, serviceLive,
                    budgetLive, endpointFrozen, refsHeld, ambientUsed,
                    overwritten, mergeMode>>

UnsafeOverwritePendingCarrier ==
    /\ phase = "Queued"
    /\ pending
    /\ ~mergeMode
    /\ overwritten' = TRUE
    /\ phase' = "BadOverwritePending"
    /\ UNCHANGED <<prepared, queued, delayed, pending, running, completed,
                    canceled, callerLive, serviceLive, budgetLive,
                    endpointFrozen, refsHeld, ambientUsed, mergeMode>>

UnsafeCompleteKeepingRefs ==
    /\ phase = "Running"
    /\ running
    /\ running' = FALSE
    /\ completed' = TRUE
    /\ phase' = "BadDeadRefs"
    /\ UNCHANGED <<prepared, queued, delayed, pending, canceled, callerLive,
                    serviceLive, budgetLive, endpointFrozen, refsHeld,
                    ambientUsed, overwritten, mergeMode>>

SafeNext ==
    \/ PrepareCarrier
    \/ QueuePreparedWork
    \/ QueueDelayedWork
    \/ TimerFireQueue
    \/ DispatchToWorker
    \/ CompleteWork
    \/ CancelPendingWork
    \/ RevokeBeforeRun
    \/ RevokeRunning

SafeSpec == Init /\ [][SafeNext]_vars

UnsafeNoCarrierSpec ==
    Init /\ [][SafeNext \/ UnsafeQueueWithoutCarrier]_vars

UnsafeAmbientSpec ==
    Init /\ [][SafeNext \/ UnsafeAmbientWorkerRun]_vars

UnsafeRevokeSpec ==
    Init /\ [][SafeNext \/ UnsafeRunAfterCallerRevoke]_vars

UnsafeOverwriteSpec ==
    Init /\ [][SafeNext \/ UnsafeOverwritePendingCarrier]_vars

UnsafeDeadRefsSpec ==
    Init /\ [][SafeNext \/ UnsafeCompleteKeepingRefs]_vars

NoWorkQueueWithoutCarrier ==
    (queued \/ delayed \/ pending) => prepared

NoRunWithoutBudgetTicket ==
    running =>
        /\ budgetLive
        /\ endpointFrozen
        /\ refsHeld

NoRunAfterCallerRevoke ==
    running =>
        /\ callerLive
        /\ serviceLive

NoWorkerAmbientAuthority ==
    ~ambientUsed

NoCarrierOverwriteWhilePending ==
    (pending /\ ~mergeMode) => ~overwritten

NoDeadCarrierRefs ==
    (completed \/ canceled \/ phase = "RevokedClosed") =>
        /\ ~prepared
        /\ ~queued
        /\ ~delayed
        /\ ~pending
        /\ ~running
        /\ ~callerLive
        /\ ~budgetLive
        /\ ~endpointFrozen
        /\ ~refsHeld

=============================================================================
