----------------------- MODULE TaskLocalRunState -----------------------
EXTENDS Naturals

VARIABLES
    phase,
    childRawCopy,
    childReset,
    childPrepared,
    childQueued,
    childRunning,
    childInheritedFrozen,
    childOwnedRefs,
    resumablePrepared,
    blocked,
    taskWaking,
    enqueued,
    frozenValid,
    selectedValid,
    runningValid,
    revoked,
    exiting,
    dead

vars == <<phase, childRawCopy, childReset, childPrepared, childQueued,
          childRunning, childInheritedFrozen, childOwnedRefs,
          resumablePrepared, blocked, taskWaking, enqueued, frozenValid,
          selectedValid, runningValid, revoked, exiting, dead>>

Phases == {
    "Start",
    "ForkCopied",
    "ForkReset",
    "SpawnPrepared",
    "NewTaskQueued",
    "Selected",
    "Running",
    "TaskBlocked",
    "FrozenForWake",
    "TaskWaking",
    "Enqueued",
    "RevokedBlocked",
    "RevokedClosed",
    "WakeRejected",
    "Exiting",
    "Dead",
    "BadForkGrantInheritance",
    "BadWakeNewNoPrep",
    "BadFrozenAfterRevoke",
    "BadDeadAuthority"
}

TypeOK ==
    /\ phase \in Phases
    /\ childRawCopy \in BOOLEAN
    /\ childReset \in BOOLEAN
    /\ childPrepared \in BOOLEAN
    /\ childQueued \in BOOLEAN
    /\ childRunning \in BOOLEAN
    /\ childInheritedFrozen \in BOOLEAN
    /\ childOwnedRefs \in BOOLEAN
    /\ resumablePrepared \in BOOLEAN
    /\ blocked \in BOOLEAN
    /\ taskWaking \in BOOLEAN
    /\ enqueued \in BOOLEAN
    /\ frozenValid \in BOOLEAN
    /\ selectedValid \in BOOLEAN
    /\ runningValid \in BOOLEAN
    /\ revoked \in BOOLEAN
    /\ exiting \in BOOLEAN
    /\ dead \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ childRawCopy = FALSE
    /\ childReset = FALSE
    /\ childPrepared = FALSE
    /\ childQueued = FALSE
    /\ childRunning = FALSE
    /\ childInheritedFrozen = FALSE
    /\ childOwnedRefs = FALSE
    /\ resumablePrepared = FALSE
    /\ blocked = FALSE
    /\ taskWaking = FALSE
    /\ enqueued = FALSE
    /\ frozenValid = FALSE
    /\ selectedValid = FALSE
    /\ runningValid = FALSE
    /\ revoked = FALSE
    /\ exiting = FALSE
    /\ dead = FALSE

DupChildRawCopy ==
    /\ phase = "Start"
    /\ childRawCopy' = TRUE
    /\ childInheritedFrozen' = TRUE
    /\ phase' = "ForkCopied"
    /\ UNCHANGED <<childReset, childPrepared, childQueued, childRunning,
                    childOwnedRefs, resumablePrepared, blocked, taskWaking,
                    enqueued, frozenValid, selectedValid, runningValid,
                    revoked, exiting, dead>>

ResetChildAfterDup ==
    /\ phase = "ForkCopied"
    /\ childRawCopy
    /\ childReset' = TRUE
    /\ childPrepared' = FALSE
    /\ childQueued' = FALSE
    /\ childRunning' = FALSE
    /\ childInheritedFrozen' = FALSE
    /\ childOwnedRefs' = FALSE
    /\ resumablePrepared' = FALSE
    /\ frozenValid' = FALSE
    /\ selectedValid' = FALSE
    /\ runningValid' = FALSE
    /\ phase' = "ForkReset"
    /\ UNCHANGED <<childRawCopy, blocked, taskWaking, enqueued, revoked,
                    exiting, dead>>

SpawnPrepare ==
    /\ phase = "ForkReset"
    /\ childReset
    /\ ~childInheritedFrozen
    /\ childPrepared' = TRUE
    /\ childOwnedRefs' = TRUE
    /\ resumablePrepared' = TRUE
    /\ phase' = "SpawnPrepared"
    /\ UNCHANGED <<childRawCopy, childReset, childQueued, childRunning,
                    childInheritedFrozen, blocked, taskWaking, enqueued,
                    frozenValid, selectedValid, runningValid, revoked,
                    exiting, dead>>

WakeNewTask ==
    /\ phase = "SpawnPrepared"
    /\ childPrepared
    /\ resumablePrepared
    /\ ~revoked
    /\ childQueued' = TRUE
    /\ enqueued' = TRUE
    /\ frozenValid' = TRUE
    /\ phase' = "NewTaskQueued"
    /\ UNCHANGED <<childRawCopy, childReset, childPrepared, childRunning,
                    childInheritedFrozen, childOwnedRefs, resumablePrepared,
                    blocked, taskWaking, selectedValid, runningValid, revoked,
                    exiting, dead>>

PickTask ==
    /\ phase \in {"NewTaskQueued", "Enqueued"}
    /\ enqueued
    /\ frozenValid
    /\ ~revoked
    /\ selectedValid' = TRUE
    /\ phase' = "Selected"
    /\ UNCHANGED <<childRawCopy, childReset, childPrepared, childQueued,
                    childRunning, childInheritedFrozen, childOwnedRefs,
                    resumablePrepared, blocked, taskWaking, enqueued,
                    frozenValid, runningValid, revoked, exiting, dead>>

SwitchToTask ==
    /\ phase = "Selected"
    /\ selectedValid
    /\ frozenValid
    /\ ~revoked
    /\ runningValid' = TRUE
    /\ childRunning' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<childRawCopy, childReset, childPrepared, childQueued,
                    childInheritedFrozen, childOwnedRefs, resumablePrepared,
                    blocked, taskWaking, enqueued, frozenValid, selectedValid,
                    revoked, exiting, dead>>

BlockRunningTask ==
    /\ phase = "Running"
    /\ runningValid
    /\ childRunning' = FALSE
    /\ childQueued' = FALSE
    /\ blocked' = TRUE
    /\ taskWaking' = FALSE
    /\ enqueued' = FALSE
    /\ frozenValid' = FALSE
    /\ selectedValid' = FALSE
    /\ runningValid' = FALSE
    /\ phase' = "TaskBlocked"
    /\ UNCHANGED <<childRawCopy, childReset, childPrepared,
                    childInheritedFrozen, childOwnedRefs, resumablePrepared,
                    revoked, exiting, dead>>

FreezeForOrdinaryWake ==
    /\ phase = "TaskBlocked"
    /\ childPrepared
    /\ resumablePrepared
    /\ blocked
    /\ ~revoked
    /\ frozenValid' = TRUE
    /\ phase' = "FrozenForWake"
    /\ UNCHANGED <<childRawCopy, childReset, childPrepared, childQueued,
                    childRunning, childInheritedFrozen, childOwnedRefs,
                    resumablePrepared, blocked, taskWaking, enqueued,
                    selectedValid, runningValid, revoked, exiting, dead>>

SetTaskWaking ==
    /\ phase = "FrozenForWake"
    /\ frozenValid
    /\ resumablePrepared
    /\ ~revoked
    /\ taskWaking' = TRUE
    /\ phase' = "TaskWaking"
    /\ UNCHANGED <<childRawCopy, childReset, childPrepared, childQueued,
                    childRunning, childInheritedFrozen, childOwnedRefs,
                    resumablePrepared, blocked, enqueued, frozenValid,
                    selectedValid, runningValid, revoked, exiting, dead>>

EnqueueWake ==
    /\ phase = "TaskWaking"
    /\ taskWaking
    /\ frozenValid
    /\ ~revoked
    /\ childQueued' = TRUE
    /\ blocked' = FALSE
    /\ enqueued' = TRUE
    /\ phase' = "Enqueued"
    /\ UNCHANGED <<childRawCopy, childReset, childPrepared, childRunning,
                    childInheritedFrozen, childOwnedRefs, resumablePrepared,
                    taskWaking, frozenValid, selectedValid, runningValid,
                    revoked, exiting, dead>>

RevokeWhileBlocked ==
    /\ phase = "TaskBlocked"
    /\ blocked
    /\ ~revoked
    /\ revoked' = TRUE
    /\ resumablePrepared' = FALSE
    /\ phase' = "RevokedBlocked"
    /\ UNCHANGED <<childRawCopy, childReset, childPrepared, childQueued,
                    childRunning, childInheritedFrozen, childOwnedRefs,
                    blocked, taskWaking, enqueued, frozenValid, selectedValid,
                    runningValid, exiting, dead>>

RevokeDerivedUse ==
    /\ phase \in {"FrozenForWake", "TaskWaking", "Enqueued", "Selected", "Running"}
    /\ ~revoked
    /\ revoked' = TRUE
    /\ resumablePrepared' = FALSE
    /\ childQueued' = FALSE
    /\ childRunning' = FALSE
    /\ blocked' = FALSE
    /\ taskWaking' = FALSE
    /\ enqueued' = FALSE
    /\ frozenValid' = FALSE
    /\ selectedValid' = FALSE
    /\ runningValid' = FALSE
    /\ phase' = "RevokedClosed"
    /\ UNCHANGED <<childRawCopy, childReset, childPrepared,
                    childInheritedFrozen, childOwnedRefs, exiting, dead>>

RejectRevokedWake ==
    /\ phase = "RevokedBlocked"
    /\ revoked
    /\ blocked' = FALSE
    /\ phase' = "WakeRejected"
    /\ UNCHANGED <<childRawCopy, childReset, childPrepared, childQueued,
                    childRunning, childInheritedFrozen, childOwnedRefs,
                    resumablePrepared, taskWaking, enqueued, frozenValid,
                    selectedValid, runningValid, revoked, exiting, dead>>

ExitClean ==
    /\ phase \notin {"Start", "Exiting", "Dead"}
    /\ ~dead
    /\ exiting' = TRUE
    /\ childPrepared' = FALSE
    /\ childQueued' = FALSE
    /\ childRunning' = FALSE
    /\ childInheritedFrozen' = FALSE
    /\ childOwnedRefs' = FALSE
    /\ resumablePrepared' = FALSE
    /\ blocked' = FALSE
    /\ taskWaking' = FALSE
    /\ enqueued' = FALSE
    /\ frozenValid' = FALSE
    /\ selectedValid' = FALSE
    /\ runningValid' = FALSE
    /\ phase' = "Exiting"
    /\ UNCHANGED <<childRawCopy, childReset, revoked, dead>>

FinishDead ==
    /\ phase = "Exiting"
    /\ exiting
    /\ dead' = TRUE
    /\ phase' = "Dead"
    /\ UNCHANGED <<childRawCopy, childReset, childPrepared, childQueued,
                    childRunning, childInheritedFrozen, childOwnedRefs,
                    resumablePrepared, blocked, taskWaking, enqueued,
                    frozenValid, selectedValid, runningValid, revoked,
                    exiting>>

UnsafePrepareWithInherited ==
    /\ phase = "ForkCopied"
    /\ childInheritedFrozen
    /\ childPrepared' = TRUE
    /\ childOwnedRefs' = TRUE
    /\ resumablePrepared' = TRUE
    /\ phase' = "BadForkGrantInheritance"
    /\ UNCHANGED <<childRawCopy, childReset, childQueued, childRunning,
                    childInheritedFrozen, blocked, taskWaking, enqueued,
                    frozenValid, selectedValid, runningValid, revoked,
                    exiting, dead>>

UnsafeWakeNewWithoutPrepared ==
    /\ phase = "ForkReset"
    /\ ~childPrepared
    /\ childQueued' = TRUE
    /\ childRunning' = TRUE
    /\ enqueued' = TRUE
    /\ runningValid' = TRUE
    /\ phase' = "BadWakeNewNoPrep"
    /\ UNCHANGED <<childRawCopy, childReset, childPrepared,
                    childInheritedFrozen, childOwnedRefs, resumablePrepared,
                    blocked, taskWaking, frozenValid, selectedValid, revoked,
                    exiting, dead>>

UnsafeRunAfterRevoke ==
    /\ phase = "RevokedBlocked"
    /\ revoked
    /\ resumablePrepared' = TRUE
    /\ taskWaking' = TRUE
    /\ enqueued' = TRUE
    /\ frozenValid' = TRUE
    /\ selectedValid' = TRUE
    /\ runningValid' = TRUE
    /\ childQueued' = TRUE
    /\ childRunning' = TRUE
    /\ phase' = "BadFrozenAfterRevoke"
    /\ UNCHANGED <<childRawCopy, childReset, childPrepared,
                    childInheritedFrozen, childOwnedRefs, blocked, revoked,
                    exiting, dead>>

UnsafeDeadWithAuthority ==
    /\ phase = "Running"
    /\ runningValid
    /\ exiting' = TRUE
    /\ dead' = TRUE
    /\ phase' = "BadDeadAuthority"
    /\ UNCHANGED <<childRawCopy, childReset, childPrepared, childQueued,
                    childRunning, childInheritedFrozen, childOwnedRefs,
                    resumablePrepared, blocked, taskWaking, enqueued,
                    frozenValid, selectedValid, runningValid, revoked>>

SafeNext ==
    \/ DupChildRawCopy
    \/ ResetChildAfterDup
    \/ SpawnPrepare
    \/ WakeNewTask
    \/ PickTask
    \/ SwitchToTask
    \/ BlockRunningTask
    \/ FreezeForOrdinaryWake
    \/ SetTaskWaking
    \/ EnqueueWake
    \/ RevokeWhileBlocked
    \/ RevokeDerivedUse
    \/ RejectRevokedWake
    \/ ExitClean
    \/ FinishDead

SafeSpec == Init /\ [][SafeNext]_vars

UnsafeForkSpec ==
    Init /\ [][SafeNext \/ UnsafePrepareWithInherited]_vars

UnsafeWakeNewSpec ==
    Init /\ [][SafeNext \/ UnsafeWakeNewWithoutPrepared]_vars

UnsafeRevokeSpec ==
    Init /\ [][SafeNext \/ UnsafeRunAfterRevoke]_vars

UnsafeExitSpec ==
    Init /\ [][SafeNext \/ UnsafeDeadWithAuthority]_vars

NoForkGrantInheritance ==
    (childPrepared \/ childQueued \/ taskWaking \/ enqueued \/ childRunning) =>
        ~childInheritedFrozen

NoInitialRunWithoutPreparedState ==
    (childQueued \/ childRunning \/ enqueued) => childPrepared

NoTaskWakingWithoutFrozenUse ==
    taskWaking =>
        /\ frozenValid
        /\ resumablePrepared
        /\ ~revoked

NoFrozenUseAfterRevoke ==
    revoked =>
        /\ ~frozenValid
        /\ ~selectedValid
        /\ ~runningValid

NoDeadTaskAuthority ==
    dead =>
        /\ ~childPrepared
        /\ ~childQueued
        /\ ~childRunning
        /\ ~childInheritedFrozen
        /\ ~childOwnedRefs
        /\ ~resumablePrepared
        /\ ~blocked
        /\ ~taskWaking
        /\ ~enqueued
        /\ ~frozenValid
        /\ ~selectedValid
        /\ ~runningValid

NoOwnedRefsBeforeReset ==
    childOwnedRefs =>
        /\ childReset
        /\ childPrepared
        /\ ~childInheritedFrozen

NoRunWithoutSelectedUse ==
    runningValid =>
        /\ selectedValid
        /\ frozenValid
        /\ ~revoked

=============================================================================
