--------------------- MODULE SchedulerAdmissionFailure ---------------------
EXTENDS Naturals

VARIABLES
    phase,
    linuxState,
    frozen,
    conditionDelivered,
    preRejected,
    onRq,
    wakeList,
    running

vars == <<phase, linuxState, frozen, conditionDelivered, preRejected,
          onRq, wakeList, running>>

Phases == {
    "Idle",
    "PreRejected",
    "Frozen",
    "TaskWakingSet",
    "RemotePending",
    "Queued",
    "Running",
    "LostWake"
}

LinuxStates == {"Blocked", "TaskWaking", "Runnable"}

TypeOK ==
    /\ phase \in Phases
    /\ linuxState \in LinuxStates
    /\ frozen \in BOOLEAN
    /\ conditionDelivered \in BOOLEAN
    /\ preRejected \in BOOLEAN
    /\ onRq \in BOOLEAN
    /\ wakeList \in BOOLEAN
    /\ running \in BOOLEAN

Init ==
    /\ phase = "Idle"
    /\ linuxState = "Blocked"
    /\ frozen = FALSE
    /\ conditionDelivered = FALSE
    /\ preRejected = FALSE
    /\ onRq = FALSE
    /\ wakeList = FALSE
    /\ running = FALSE

SafeRejectBeforeTaskWaking ==
    /\ phase = "Idle"
    /\ ~frozen
    /\ conditionDelivered' = TRUE
    /\ preRejected' = TRUE
    /\ phase' = "PreRejected"
    /\ linuxState' = "Blocked"
    /\ UNCHANGED <<frozen, onRq, wakeList, running>>

FreezeBeforeTaskWaking ==
    /\ phase = "Idle"
    /\ conditionDelivered' = TRUE
    /\ frozen' = TRUE
    /\ phase' = "Frozen"
    /\ UNCHANGED <<linuxState, preRejected, onRq, wakeList, running>>

SetTaskWakingAfterFreeze ==
    /\ phase = "Frozen"
    /\ frozen
    /\ linuxState' = "TaskWaking"
    /\ phase' = "TaskWakingSet"
    /\ UNCHANGED <<frozen, conditionDelivered, preRejected, onRq, wakeList,
                    running>>

QueueDirect ==
    /\ phase = "TaskWakingSet"
    /\ linuxState = "TaskWaking"
    /\ frozen
    /\ linuxState' = "Runnable"
    /\ onRq' = TRUE
    /\ phase' = "Queued"
    /\ UNCHANGED <<frozen, conditionDelivered, preRejected, wakeList, running>>

QueueRemote ==
    /\ phase = "TaskWakingSet"
    /\ linuxState = "TaskWaking"
    /\ frozen
    /\ wakeList' = TRUE
    /\ phase' = "RemotePending"
    /\ UNCHANGED <<linuxState, frozen, conditionDelivered, preRejected, onRq,
                    running>>

DrainRemote ==
    /\ phase = "RemotePending"
    /\ linuxState = "TaskWaking"
    /\ frozen
    /\ wakeList
    /\ wakeList' = FALSE
    /\ onRq' = TRUE
    /\ linuxState' = "Runnable"
    /\ phase' = "Queued"
    /\ UNCHANGED <<frozen, conditionDelivered, preRejected, running>>

RunTask ==
    /\ phase = "Queued"
    /\ linuxState = "Runnable"
    /\ frozen
    /\ onRq
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<linuxState, frozen, conditionDelivered, preRejected, onRq,
                    wakeList>>

UnsafeSetTaskWakingWithoutFreeze ==
    /\ phase = "Idle"
    /\ ~frozen
    /\ conditionDelivered' = TRUE
    /\ linuxState' = "TaskWaking"
    /\ phase' = "TaskWakingSet"
    /\ UNCHANGED <<frozen, preRejected, onRq, wakeList, running>>

UnsafeRollbackAfterTaskWaking ==
    /\ phase = "TaskWakingSet"
    /\ linuxState = "TaskWaking"
    /\ ~frozen
    /\ conditionDelivered
    /\ linuxState' = "Blocked"
    /\ phase' = "LostWake"
    /\ UNCHANGED <<frozen, conditionDelivered, preRejected, onRq, wakeList,
                    running>>

SafeNext ==
    \/ SafeRejectBeforeTaskWaking
    \/ FreezeBeforeTaskWaking
    \/ SetTaskWakingAfterFreeze
    \/ QueueDirect
    \/ QueueRemote
    \/ DrainRemote
    \/ RunTask

UnsafeNext ==
    \/ SafeNext
    \/ UnsafeSetTaskWakingWithoutFreeze
    \/ UnsafeRollbackAfterTaskWaking

SafeSpec == Init /\ [][SafeNext]_vars
UnsafeSpec == Init /\ [][UnsafeNext]_vars

NoTaskWakingWithoutFrozenUse ==
    linuxState = "TaskWaking" => frozen

NoRunqueueCustodyWithoutFrozenUse ==
    (onRq \/ wakeList \/ running) => frozen

NoLostWakeAfterCondition ==
    conditionDelivered /\ ~preRejected => phase # "LostWake"

PreRejectDoesNotMutateLinuxWakeState ==
    preRejected =>
        /\ phase = "PreRejected"
        /\ linuxState = "Blocked"
        /\ ~onRq
        /\ ~wakeList
        /\ ~running

=============================================================================
