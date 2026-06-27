---------------------- MODULE SharedFutexEndpoint ----------------------
EXTENDS Naturals

VARIABLES
    phase,
    endpointLive,
    waitCap,
    wakeCap,
    requeueSourceCap,
    requeueTargetCap,
    waiterPrepared,
    waiterQueued,
    wakeMarked,
    taskFrozen,
    running,
    requeued,
    capFailureAfterQueue,
    rollbackProven

vars == <<phase, endpointLive, waitCap, wakeCap, requeueSourceCap,
          requeueTargetCap, waiterPrepared, waiterQueued, wakeMarked,
          taskFrozen, running, requeued, capFailureAfterQueue,
          rollbackProven>>

Phases == {
    "Start",
    "WaitPrepared",
    "Queued",
    "WakeAuthorized",
    "MarkedForWake",
    "FrozenForRun",
    "Running",
    "RequeueAuthorized",
    "Requeued",
    "RevokedClosed",
    "BadWaitNoCap",
    "BadWakeNoCap",
    "BadWakeRunsTask",
    "BadRequeueNoBothCaps",
    "BadUseAfterRevoke",
    "BadLateCapFailure"
}

TypeOK ==
    /\ phase \in Phases
    /\ endpointLive \in BOOLEAN
    /\ waitCap \in BOOLEAN
    /\ wakeCap \in BOOLEAN
    /\ requeueSourceCap \in BOOLEAN
    /\ requeueTargetCap \in BOOLEAN
    /\ waiterPrepared \in BOOLEAN
    /\ waiterQueued \in BOOLEAN
    /\ wakeMarked \in BOOLEAN
    /\ taskFrozen \in BOOLEAN
    /\ running \in BOOLEAN
    /\ requeued \in BOOLEAN
    /\ capFailureAfterQueue \in BOOLEAN
    /\ rollbackProven \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ endpointLive = TRUE
    /\ waitCap = FALSE
    /\ wakeCap = FALSE
    /\ requeueSourceCap = FALSE
    /\ requeueTargetCap = FALSE
    /\ waiterPrepared = FALSE
    /\ waiterQueued = FALSE
    /\ wakeMarked = FALSE
    /\ taskFrozen = FALSE
    /\ running = FALSE
    /\ requeued = FALSE
    /\ capFailureAfterQueue = FALSE
    /\ rollbackProven = FALSE

PrepareWaitEndpoint ==
    /\ phase = "Start"
    /\ endpointLive
    /\ waitCap' = TRUE
    /\ waiterPrepared' = TRUE
    /\ phase' = "WaitPrepared"
    /\ UNCHANGED <<endpointLive, wakeCap, requeueSourceCap, requeueTargetCap,
                    waiterQueued, wakeMarked, taskFrozen, running, requeued,
                    capFailureAfterQueue, rollbackProven>>

QueueWaiter ==
    /\ phase = "WaitPrepared"
    /\ endpointLive
    /\ waitCap
    /\ waiterPrepared
    /\ waiterQueued' = TRUE
    /\ phase' = "Queued"
    /\ UNCHANGED <<endpointLive, waitCap, wakeCap, requeueSourceCap,
                    requeueTargetCap, waiterPrepared, wakeMarked, taskFrozen,
                    running, requeued, capFailureAfterQueue, rollbackProven>>

PrepareWakeEndpoint ==
    /\ phase = "Queued"
    /\ endpointLive
    /\ wakeCap' = TRUE
    /\ phase' = "WakeAuthorized"
    /\ UNCHANGED <<endpointLive, waitCap, requeueSourceCap, requeueTargetCap,
                    waiterPrepared, waiterQueued, wakeMarked, taskFrozen,
                    running, requeued, capFailureAfterQueue, rollbackProven>>

MarkForWake ==
    /\ phase = "WakeAuthorized"
    /\ endpointLive
    /\ waiterQueued
    /\ wakeCap
    /\ wakeMarked' = TRUE
    /\ waiterQueued' = FALSE
    /\ phase' = "MarkedForWake"
    /\ UNCHANGED <<endpointLive, waitCap, wakeCap, requeueSourceCap,
                    requeueTargetCap, waiterPrepared, taskFrozen, running,
                    requeued, capFailureAfterQueue, rollbackProven>>

FreezeTargetRun ==
    /\ phase = "MarkedForWake"
    /\ wakeMarked
    /\ endpointLive
    /\ taskFrozen' = TRUE
    /\ phase' = "FrozenForRun"
    /\ UNCHANGED <<endpointLive, waitCap, wakeCap, requeueSourceCap,
                    requeueTargetCap, waiterPrepared, waiterQueued, wakeMarked,
                    running, requeued, capFailureAfterQueue, rollbackProven>>

RunTarget ==
    /\ phase = "FrozenForRun"
    /\ wakeMarked
    /\ taskFrozen
    /\ endpointLive
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<endpointLive, waitCap, wakeCap, requeueSourceCap,
                    requeueTargetCap, waiterPrepared, waiterQueued, wakeMarked,
                    taskFrozen, requeued, capFailureAfterQueue, rollbackProven>>

PrepareRequeueEndpoint ==
    /\ phase = "Queued"
    /\ endpointLive
    /\ requeueSourceCap' = TRUE
    /\ requeueTargetCap' = TRUE
    /\ phase' = "RequeueAuthorized"
    /\ UNCHANGED <<endpointLive, waitCap, wakeCap, waiterPrepared,
                    waiterQueued, wakeMarked, taskFrozen, running, requeued,
                    capFailureAfterQueue, rollbackProven>>

RequeueWaiter ==
    /\ phase = "RequeueAuthorized"
    /\ endpointLive
    /\ waiterQueued
    /\ requeueSourceCap
    /\ requeueTargetCap
    /\ requeued' = TRUE
    /\ phase' = "Requeued"
    /\ UNCHANGED <<endpointLive, waitCap, wakeCap, requeueSourceCap,
                    requeueTargetCap, waiterPrepared, waiterQueued,
                    wakeMarked, taskFrozen, running, capFailureAfterQueue,
                    rollbackProven>>

RevokeEndpoint ==
    /\ phase \in {"WaitPrepared", "Queued", "WakeAuthorized", "MarkedForWake",
                  "FrozenForRun", "RequeueAuthorized", "Requeued"}
    /\ endpointLive
    /\ endpointLive' = FALSE
    /\ waitCap' = FALSE
    /\ wakeCap' = FALSE
    /\ requeueSourceCap' = FALSE
    /\ requeueTargetCap' = FALSE
    /\ waiterPrepared' = FALSE
    /\ waiterQueued' = FALSE
    /\ wakeMarked' = FALSE
    /\ taskFrozen' = FALSE
    /\ running' = FALSE
    /\ requeued' = FALSE
    /\ phase' = "RevokedClosed"
    /\ UNCHANGED <<capFailureAfterQueue, rollbackProven>>

UnsafeWaitWithoutCap ==
    /\ phase = "Start"
    /\ ~waitCap
    /\ waiterQueued' = TRUE
    /\ phase' = "BadWaitNoCap"
    /\ UNCHANGED <<endpointLive, waitCap, wakeCap, requeueSourceCap,
                    requeueTargetCap, waiterPrepared, wakeMarked, taskFrozen,
                    running, requeued, capFailureAfterQueue, rollbackProven>>

UnsafeWakeWithoutCap ==
    /\ phase = "Queued"
    /\ waiterQueued
    /\ ~wakeCap
    /\ wakeMarked' = TRUE
    /\ waiterQueued' = FALSE
    /\ phase' = "BadWakeNoCap"
    /\ UNCHANGED <<endpointLive, waitCap, wakeCap, requeueSourceCap,
                    requeueTargetCap, waiterPrepared, taskFrozen, running,
                    requeued, capFailureAfterQueue, rollbackProven>>

UnsafeWakeRunsTask ==
    /\ phase = "WakeAuthorized"
    /\ wakeCap
    /\ waiterQueued
    /\ wakeMarked' = TRUE
    /\ waiterQueued' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadWakeRunsTask"
    /\ UNCHANGED <<endpointLive, waitCap, wakeCap, requeueSourceCap,
                    requeueTargetCap, waiterPrepared, taskFrozen, requeued,
                    capFailureAfterQueue, rollbackProven>>

UnsafeRequeueWithoutBothCaps ==
    /\ phase = "Queued"
    /\ waiterQueued
    /\ requeueSourceCap' = TRUE
    /\ requeueTargetCap' = FALSE
    /\ requeued' = TRUE
    /\ phase' = "BadRequeueNoBothCaps"
    /\ UNCHANGED <<endpointLive, waitCap, wakeCap, waiterPrepared,
                    waiterQueued, wakeMarked, taskFrozen, running,
                    capFailureAfterQueue, rollbackProven>>

UnsafeUseAfterRevoke ==
    /\ phase = "Queued"
    /\ waiterQueued
    /\ endpointLive' = FALSE
    /\ wakeMarked' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadUseAfterRevoke"
    /\ UNCHANGED <<waitCap, wakeCap, requeueSourceCap, requeueTargetCap,
                    waiterPrepared, waiterQueued, taskFrozen, requeued,
                    capFailureAfterQueue, rollbackProven>>

UnsafeLateCapFailure ==
    /\ phase = "Queued"
    /\ waiterQueued
    /\ capFailureAfterQueue' = TRUE
    /\ rollbackProven' = FALSE
    /\ phase' = "BadLateCapFailure"
    /\ UNCHANGED <<endpointLive, waitCap, wakeCap, requeueSourceCap,
                    requeueTargetCap, waiterPrepared, waiterQueued,
                    wakeMarked, taskFrozen, running, requeued>>

SafeNext ==
    \/ PrepareWaitEndpoint
    \/ QueueWaiter
    \/ PrepareWakeEndpoint
    \/ MarkForWake
    \/ FreezeTargetRun
    \/ RunTarget
    \/ PrepareRequeueEndpoint
    \/ RequeueWaiter
    \/ RevokeEndpoint

SafeSpec == Init /\ [][SafeNext]_vars

UnsafeWaitSpec ==
    Init /\ [][SafeNext \/ UnsafeWaitWithoutCap]_vars

UnsafeWakeSpec ==
    Init /\ [][SafeNext \/ UnsafeWakeWithoutCap]_vars

UnsafeWakeRunsSpec ==
    Init /\ [][SafeNext \/ UnsafeWakeRunsTask]_vars

UnsafeRequeueSpec ==
    Init /\ [][SafeNext \/ UnsafeRequeueWithoutBothCaps]_vars

UnsafeRevokeSpec ==
    Init /\ [][SafeNext \/ UnsafeUseAfterRevoke]_vars

UnsafeLateFailSpec ==
    Init /\ [][SafeNext \/ UnsafeLateCapFailure]_vars

NoSharedFutexWaitWithoutWaitCap ==
    waiterQueued => waitCap

NoSharedFutexWakeWithoutWakeCap ==
    wakeMarked => wakeCap

NoWakeImpliesRun ==
    running =>
        /\ wakeMarked
        /\ taskFrozen
        /\ endpointLive

NoRequeueWithoutBothEndpointRights ==
    requeued =>
        /\ requeueSourceCap
        /\ requeueTargetCap
        /\ endpointLive

NoEndpointUseAfterRevoke ==
    ~endpointLive =>
        /\ ~waitCap
        /\ ~wakeCap
        /\ ~requeueSourceCap
        /\ ~requeueTargetCap
        /\ ~waiterQueued
        /\ ~wakeMarked
        /\ ~taskFrozen
        /\ ~running

NoLostWakeFromCapFailure ==
    capFailureAfterQueue => rollbackProven

=============================================================================
