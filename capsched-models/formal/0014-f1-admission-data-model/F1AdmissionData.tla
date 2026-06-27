-------------------------- MODULE F1AdmissionData --------------------------
EXTENDS Naturals

CONSTANTS
    RunCap,
    SchedCtx,
    Domain,
    Generation,
    FrozenSlot,
    Placement,
    Budget,
    NoField

VARIABLES
    phase,
    dataReady,
    piLock,
    frozen,
    taskWaking,
    slowOp,
    allocation,
    monitorCall,
    selectedCpuAllowed,
    queued,
    rejected

vars == <<phase, dataReady, piLock, frozen, taskWaking, slowOp, allocation,
          monitorCall, selectedCpuAllowed, queued, rejected>>

Fields == {RunCap, SchedCtx, Domain, Generation, FrozenSlot, Placement, Budget}

Phases == {
    "F1",
    "Rejected",
    "Frozen",
    "TaskWaking",
    "SelectedCpu",
    "Queued",
    "BadSlowOp",
    "BadAllocation",
    "BadMonitorCall",
    "BadMissingData",
    "BadPlacement"
}

TypeOK ==
    /\ RunCap \in Fields
    /\ SchedCtx \in Fields
    /\ Domain \in Fields
    /\ Generation \in Fields
    /\ FrozenSlot \in Fields
    /\ Placement \in Fields
    /\ Budget \in Fields
    /\ NoField \notin Fields
    /\ phase \in Phases
    /\ dataReady \in [Fields -> BOOLEAN]
    /\ piLock \in BOOLEAN
    /\ frozen \in BOOLEAN
    /\ taskWaking \in BOOLEAN
    /\ slowOp \in BOOLEAN
    /\ allocation \in BOOLEAN
    /\ monitorCall \in BOOLEAN
    /\ selectedCpuAllowed \in BOOLEAN
    /\ queued \in BOOLEAN
    /\ rejected \in BOOLEAN

AllRequiredReady ==
    \A f \in Fields: dataReady[f]

PlacementReady ==
    dataReady[Placement]

Init ==
    /\ phase = "F1"
    /\ dataReady \in [Fields -> BOOLEAN]
    /\ piLock = TRUE
    /\ frozen = FALSE
    /\ taskWaking = FALSE
    /\ slowOp = FALSE
    /\ allocation = FALSE
    /\ monitorCall = FALSE
    /\ selectedCpuAllowed = FALSE
    /\ queued = FALSE
    /\ rejected = FALSE

RejectMissingBeforeTaskWaking ==
    /\ phase = "F1"
    /\ ~AllRequiredReady
    /\ rejected' = TRUE
    /\ phase' = "Rejected"
    /\ piLock' = FALSE
    /\ UNCHANGED <<dataReady, frozen, taskWaking, slowOp, allocation,
                    monitorCall, selectedCpuAllowed, queued>>

FreezeIfAllLocalDataReady ==
    /\ phase = "F1"
    /\ AllRequiredReady
    /\ frozen' = TRUE
    /\ phase' = "Frozen"
    /\ UNCHANGED <<dataReady, piLock, taskWaking, slowOp, allocation,
                    monitorCall, selectedCpuAllowed, queued, rejected>>

SetTaskWaking ==
    /\ phase = "Frozen"
    /\ frozen
    /\ taskWaking' = TRUE
    /\ phase' = "TaskWaking"
    /\ piLock' = TRUE
    /\ UNCHANGED <<dataReady, frozen, slowOp, allocation, monitorCall,
                    selectedCpuAllowed, queued, rejected>>

SelectCpuWithinEnvelope ==
    /\ phase = "TaskWaking"
    /\ taskWaking
    /\ frozen
    /\ PlacementReady
    /\ selectedCpuAllowed' = TRUE
    /\ phase' = "SelectedCpu"
    /\ UNCHANGED <<dataReady, piLock, frozen, taskWaking, slowOp, allocation,
                    monitorCall, queued, rejected>>

QueueAfterAllowedSelection ==
    /\ phase = "SelectedCpu"
    /\ frozen
    /\ selectedCpuAllowed
    /\ queued' = TRUE
    /\ phase' = "Queued"
    /\ piLock' = FALSE
    /\ UNCHANGED <<dataReady, frozen, taskWaking, slowOp, allocation,
                    monitorCall, selectedCpuAllowed, rejected>>

UnsafeSlowLookupUnderPiLock ==
    /\ phase = "F1"
    /\ piLock
    /\ ~AllRequiredReady
    /\ slowOp' = TRUE
    /\ phase' = "BadSlowOp"
    /\ UNCHANGED <<dataReady, piLock, frozen, taskWaking, allocation,
                    monitorCall, selectedCpuAllowed, queued, rejected>>

UnsafeAllocateFrozenSlotUnderPiLock ==
    /\ phase = "F1"
    /\ piLock
    /\ ~dataReady[FrozenSlot]
    /\ allocation' = TRUE
    /\ phase' = "BadAllocation"
    /\ UNCHANGED <<dataReady, piLock, frozen, taskWaking, slowOp,
                    monitorCall, selectedCpuAllowed, queued, rejected>>

UnsafeMonitorCallUnderPiLock ==
    /\ phase = "F1"
    /\ piLock
    /\ ~AllRequiredReady
    /\ monitorCall' = TRUE
    /\ phase' = "BadMonitorCall"
    /\ UNCHANGED <<dataReady, piLock, frozen, taskWaking, slowOp, allocation,
                    selectedCpuAllowed, queued, rejected>>

UnsafeFreezeWithMissingData ==
    /\ phase = "F1"
    /\ ~AllRequiredReady
    /\ frozen' = TRUE
    /\ phase' = "BadMissingData"
    /\ UNCHANGED <<dataReady, piLock, taskWaking, slowOp, allocation,
                    monitorCall, selectedCpuAllowed, queued, rejected>>

UnsafeFreezeWithoutPlacementEnvelope ==
    /\ phase = "F1"
    /\ ~PlacementReady
    /\ \A f \in Fields \ {Placement}: dataReady[f]
    /\ frozen' = TRUE
    /\ phase' = "Frozen"
    /\ UNCHANGED <<dataReady, piLock, taskWaking, slowOp, allocation,
                    monitorCall, selectedCpuAllowed, queued, rejected>>

UnsafeSelectCpuOutsideEnvelope ==
    /\ phase = "TaskWaking"
    /\ taskWaking
    /\ frozen
    /\ ~PlacementReady
    /\ selectedCpuAllowed' = FALSE
    /\ queued' = TRUE
    /\ phase' = "BadPlacement"
    /\ piLock' = FALSE
    /\ UNCHANGED <<dataReady, frozen, taskWaking, slowOp, allocation,
                    monitorCall, rejected>>

SafeNext ==
    \/ RejectMissingBeforeTaskWaking
    \/ FreezeIfAllLocalDataReady
    \/ SetTaskWaking
    \/ SelectCpuWithinEnvelope
    \/ QueueAfterAllowedSelection

UnsafeNext ==
    \/ SafeNext
    \/ UnsafeSlowLookupUnderPiLock
    \/ UnsafeAllocateFrozenSlotUnderPiLock
    \/ UnsafeMonitorCallUnderPiLock
    \/ UnsafeFreezeWithMissingData
    \/ UnsafeFreezeWithoutPlacementEnvelope
    \/ UnsafeSelectCpuOutsideEnvelope

SafeSpec == Init /\ [][SafeNext]_vars
UnsafeSpec == Init /\ [][UnsafeNext]_vars

NoSlowOperationUnderPiLock ==
    piLock => ~slowOp

NoAllocationUnderPiLock ==
    piLock => ~allocation

NoMonitorCallUnderPiLock ==
    piLock => ~monitorCall

NoTaskWakingWithoutFrozenUse ==
    taskWaking => frozen

NoFreezeWithoutAllRequiredLocalData ==
    frozen => AllRequiredReady

NoQueuedWithoutPlacementEnvelope ==
    queued => selectedCpuAllowed

NoMissingDataAfterTaskWaking ==
    taskWaking => AllRequiredReady

RejectBeforeTaskWakingOnly ==
    rejected =>
        /\ phase = "Rejected"
        /\ ~taskWaking
        /\ ~queued

=============================================================================
