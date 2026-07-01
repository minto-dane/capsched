---------- MODULE TaskFrozenRunLifetimeLockingGate ----------
EXTENDS Naturals

VARIABLES
    phase,
    taskLive,
    taskGeneration,
    frozenGeneration,
    taskRefHeld,
    rcuReadHeld,
    rqLockHeld,
    piLockHeld,
    onRq,
    migrating,
    frozenIssued,
    frozenConsumed,
    frozenReleased,
    releaseCount,
    releaseAfterSettled,
    deniedRecorded,
    retrySafe,
    retryStableLifetime,
    runCommitted,
    running,
    commitStableLifetime,
    commitTaskLive,
    commitFreshGeneration,
    commitNoMigration,
    commitBeforeRelease,
    moveSettled,
    moveLockValid,
    failedClosed,
    exitInvalidationHandled,
    behaviorChangeClaim,
    monitorVerifiedClaim,
    protectionClaim

vars == <<phase, taskLive, taskGeneration, frozenGeneration, taskRefHeld,
          rcuReadHeld, rqLockHeld, piLockHeld, onRq, migrating, frozenIssued,
          frozenConsumed, frozenReleased, releaseCount, releaseAfterSettled,
          deniedRecorded, retrySafe, retryStableLifetime, runCommitted,
          running, commitStableLifetime, commitTaskLive, commitFreshGeneration,
          commitNoMigration, commitBeforeRelease, moveSettled, moveLockValid,
          failedClosed, exitInvalidationHandled, behaviorChangeClaim,
          monitorVerifiedClaim, protectionClaim>>

GoodPhases == {
    "Start",
    "Stable",
    "Frozen",
    "Running",
    "Denied",
    "Exited",
    "Moved",
    "FailClosedExit",
    "DoneRun",
    "DoneDeny",
    "DoneExit",
    "DoneMove"
}

BadPhases == {
    "BadRunAfterFree",
    "BadRunWithoutStableLifetime",
    "BadRcuOnlyAuthority",
    "BadRawPointerAuthority",
    "BadRunWhileMigrating",
    "BadStaleGenerationRun",
    "BadUseAfterRelease",
    "BadReleaseBeforeDenySettled",
    "BadDoubleRelease",
    "BadRefLeak",
    "BadMoveWithoutRqLock",
    "BadRetryWithoutStableLifetime",
    "BadExitInvalidationIgnored",
    "BadBehaviorChangeClaim",
    "BadMonitorVerifiedClaim",
    "BadProtectionClaim"
}

Phases == GoodPhases \cup BadPhases
TerminalPhases == {"DoneRun", "DoneDeny", "DoneExit", "DoneMove"}

StableLifetimeNow ==
    taskLive /\ (taskRefHeld \/ rqLockHeld) /\ ~migrating

FreshFrozenNow ==
    frozenIssued /\ ~frozenReleased /\ frozenGeneration = taskGeneration

TypeOK ==
    /\ phase \in Phases
    /\ taskLive \in BOOLEAN
    /\ taskGeneration \in 1..2
    /\ frozenGeneration \in 0..2
    /\ taskRefHeld \in BOOLEAN
    /\ rcuReadHeld \in BOOLEAN
    /\ rqLockHeld \in BOOLEAN
    /\ piLockHeld \in BOOLEAN
    /\ onRq \in BOOLEAN
    /\ migrating \in BOOLEAN
    /\ frozenIssued \in BOOLEAN
    /\ frozenConsumed \in BOOLEAN
    /\ frozenReleased \in BOOLEAN
    /\ releaseCount \in 0..2
    /\ releaseAfterSettled \in BOOLEAN
    /\ deniedRecorded \in BOOLEAN
    /\ retrySafe \in BOOLEAN
    /\ retryStableLifetime \in BOOLEAN
    /\ runCommitted \in BOOLEAN
    /\ running \in BOOLEAN
    /\ commitStableLifetime \in BOOLEAN
    /\ commitTaskLive \in BOOLEAN
    /\ commitFreshGeneration \in BOOLEAN
    /\ commitNoMigration \in BOOLEAN
    /\ commitBeforeRelease \in BOOLEAN
    /\ moveSettled \in BOOLEAN
    /\ moveLockValid \in BOOLEAN
    /\ failedClosed \in BOOLEAN
    /\ exitInvalidationHandled \in BOOLEAN
    /\ behaviorChangeClaim \in BOOLEAN
    /\ monitorVerifiedClaim \in BOOLEAN
    /\ protectionClaim \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ taskLive = TRUE
    /\ taskGeneration = 1
    /\ frozenGeneration = 0
    /\ taskRefHeld = FALSE
    /\ rcuReadHeld = FALSE
    /\ rqLockHeld = FALSE
    /\ piLockHeld = FALSE
    /\ onRq = TRUE
    /\ migrating = FALSE
    /\ frozenIssued = FALSE
    /\ frozenConsumed = FALSE
    /\ frozenReleased = FALSE
    /\ releaseCount = 0
    /\ releaseAfterSettled = FALSE
    /\ deniedRecorded = FALSE
    /\ retrySafe = FALSE
    /\ retryStableLifetime = FALSE
    /\ runCommitted = FALSE
    /\ running = FALSE
    /\ commitStableLifetime = FALSE
    /\ commitTaskLive = FALSE
    /\ commitFreshGeneration = FALSE
    /\ commitNoMigration = FALSE
    /\ commitBeforeRelease = FALSE
    /\ moveSettled = FALSE
    /\ moveLockValid = FALSE
    /\ failedClosed = FALSE
    /\ exitInvalidationHandled = FALSE
    /\ behaviorChangeClaim = FALSE
    /\ monitorVerifiedClaim = FALSE
    /\ protectionClaim = FALSE

AcquireStableLifetime ==
    /\ phase = "Start"
    /\ taskLive
    /\ taskRefHeld' = TRUE
    /\ rcuReadHeld' = TRUE
    /\ rqLockHeld' = TRUE
    /\ piLockHeld' = TRUE
    /\ phase' = "Stable"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, onRq,
                    migrating, frozenIssued, frozenConsumed, frozenReleased,
                    releaseCount, releaseAfterSettled, deniedRecorded,
                    retrySafe, retryStableLifetime, runCommitted, running,
                    commitStableLifetime, commitTaskLive,
                    commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

FreezeCandidate ==
    /\ phase = "Stable"
    /\ StableLifetimeNow
    /\ frozenIssued' = TRUE
    /\ frozenGeneration' = taskGeneration
    /\ phase' = "Frozen"
    /\ UNCHANGED <<taskLive, taskGeneration, taskRefHeld, rcuReadHeld,
                    rqLockHeld, piLockHeld, onRq, migrating, frozenConsumed,
                    frozenReleased, releaseCount, releaseAfterSettled,
                    deniedRecorded, retrySafe, retryStableLifetime,
                    runCommitted, running, commitStableLifetime,
                    commitTaskLive, commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

CommitRun ==
    /\ phase = "Frozen"
    /\ StableLifetimeNow
    /\ FreshFrozenNow
    /\ onRq
    /\ frozenConsumed' = TRUE
    /\ runCommitted' = TRUE
    /\ running' = TRUE
    /\ commitStableLifetime' = TRUE
    /\ commitTaskLive' = TRUE
    /\ commitFreshGeneration' = TRUE
    /\ commitNoMigration' = TRUE
    /\ commitBeforeRelease' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, taskRefHeld,
                    rcuReadHeld, rqLockHeld, piLockHeld, onRq, migrating,
                    frozenIssued, frozenReleased, releaseCount,
                    releaseAfterSettled, deniedRecorded, retrySafe,
                    retryStableLifetime, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

DenyCandidate ==
    /\ phase = "Frozen"
    /\ StableLifetimeNow
    /\ FreshFrozenNow
    /\ deniedRecorded' = TRUE
    /\ retrySafe' = TRUE
    /\ retryStableLifetime' = TRUE
    /\ releaseAfterSettled' = TRUE
    /\ phase' = "Denied"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, taskRefHeld,
                    rcuReadHeld, rqLockHeld, piLockHeld, onRq, migrating,
                    frozenIssued, frozenConsumed, frozenReleased,
                    releaseCount, runCommitted, running,
                    commitStableLifetime, commitTaskLive,
                    commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

TaskExitInvalidatesTuple ==
    /\ phase = "Frozen"
    /\ taskLive
    /\ taskLive' = FALSE
    /\ taskGeneration' = 2
    /\ onRq' = FALSE
    /\ phase' = "Exited"
    /\ UNCHANGED <<frozenGeneration, taskRefHeld, rcuReadHeld, rqLockHeld,
                    piLockHeld, migrating, frozenIssued, frozenConsumed,
                    frozenReleased, releaseCount, releaseAfterSettled,
                    deniedRecorded, retrySafe, retryStableLifetime,
                    runCommitted, running, commitStableLifetime,
                    commitTaskLive, commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

FailClosedAfterExit ==
    /\ phase = "Exited"
    /\ ~taskLive
    /\ frozenIssued
    /\ frozenGeneration # taskGeneration
    /\ failedClosed' = TRUE
    /\ exitInvalidationHandled' = TRUE
    /\ releaseAfterSettled' = TRUE
    /\ phase' = "FailClosedExit"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, taskRefHeld,
                    rcuReadHeld, rqLockHeld, piLockHeld, onRq, migrating,
                    frozenIssued, frozenConsumed, frozenReleased,
                    releaseCount, deniedRecorded, retrySafe,
                    retryStableLifetime, runCommitted, running,
                    commitStableLifetime, commitTaskLive,
                    commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

MoveQueuedTaskWithLock ==
    /\ phase = "Frozen"
    /\ StableLifetimeNow
    /\ FreshFrozenNow
    /\ rqLockHeld
    /\ moveSettled' = TRUE
    /\ moveLockValid' = TRUE
    /\ releaseAfterSettled' = TRUE
    /\ phase' = "Moved"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, taskRefHeld,
                    rcuReadHeld, rqLockHeld, piLockHeld, onRq, migrating,
                    frozenIssued, frozenConsumed, frozenReleased,
                    releaseCount, deniedRecorded, retrySafe,
                    retryStableLifetime, runCommitted, running,
                    commitStableLifetime, commitTaskLive,
                    commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, failedClosed,
                    exitInvalidationHandled, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

ReleaseAfterRun ==
    /\ phase = "Running"
    /\ runCommitted
    /\ releaseCount' = 1
    /\ frozenReleased' = TRUE
    /\ releaseAfterSettled' = TRUE
    /\ taskRefHeld' = FALSE
    /\ rcuReadHeld' = FALSE
    /\ rqLockHeld' = FALSE
    /\ piLockHeld' = FALSE
    /\ phase' = "DoneRun"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, onRq,
                    migrating, frozenIssued, frozenConsumed, deniedRecorded,
                    retrySafe, retryStableLifetime, runCommitted, running,
                    commitStableLifetime, commitTaskLive,
                    commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

ReleaseAfterDeny ==
    /\ phase = "Denied"
    /\ deniedRecorded
    /\ retrySafe
    /\ releaseCount' = 1
    /\ frozenReleased' = TRUE
    /\ taskRefHeld' = FALSE
    /\ rcuReadHeld' = FALSE
    /\ rqLockHeld' = FALSE
    /\ piLockHeld' = FALSE
    /\ phase' = "DoneDeny"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, onRq,
                    migrating, frozenIssued, frozenConsumed,
                    releaseAfterSettled, deniedRecorded, retrySafe,
                    retryStableLifetime, runCommitted, running,
                    commitStableLifetime, commitTaskLive,
                    commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

ReleaseAfterExit ==
    /\ phase = "FailClosedExit"
    /\ failedClosed
    /\ exitInvalidationHandled
    /\ releaseCount' = 1
    /\ frozenReleased' = TRUE
    /\ taskRefHeld' = FALSE
    /\ rcuReadHeld' = FALSE
    /\ rqLockHeld' = FALSE
    /\ piLockHeld' = FALSE
    /\ phase' = "DoneExit"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, onRq,
                    migrating, frozenIssued, frozenConsumed,
                    releaseAfterSettled, deniedRecorded, retrySafe,
                    retryStableLifetime, runCommitted, running,
                    commitStableLifetime, commitTaskLive,
                    commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

ReleaseAfterMove ==
    /\ phase = "Moved"
    /\ moveSettled
    /\ moveLockValid
    /\ releaseCount' = 1
    /\ frozenReleased' = TRUE
    /\ taskRefHeld' = FALSE
    /\ rcuReadHeld' = FALSE
    /\ rqLockHeld' = FALSE
    /\ piLockHeld' = FALSE
    /\ phase' = "DoneMove"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, onRq,
                    migrating, frozenIssued, frozenConsumed,
                    releaseAfterSettled, deniedRecorded, retrySafe,
                    retryStableLifetime, runCommitted, running,
                    commitStableLifetime, commitTaskLive,
                    commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

TerminalStutter ==
    /\ phase \in TerminalPhases
    /\ UNCHANGED vars

SafeNext ==
    \/ AcquireStableLifetime
    \/ FreezeCandidate
    \/ CommitRun
    \/ DenyCandidate
    \/ TaskExitInvalidatesTuple
    \/ FailClosedAfterExit
    \/ MoveQueuedTaskWithLock
    \/ ReleaseAfterRun
    \/ ReleaseAfterDeny
    \/ ReleaseAfterExit
    \/ ReleaseAfterMove
    \/ TerminalStutter

BadRunAfterFree ==
    /\ phase = "Start"
    /\ taskLive' = FALSE
    /\ taskGeneration' = 2
    /\ frozenGeneration' = 1
    /\ frozenIssued' = TRUE
    /\ frozenConsumed' = TRUE
    /\ runCommitted' = TRUE
    /\ running' = TRUE
    /\ commitStableLifetime' = TRUE
    /\ commitTaskLive' = FALSE
    /\ commitFreshGeneration' = FALSE
    /\ commitNoMigration' = TRUE
    /\ commitBeforeRelease' = TRUE
    /\ phase' = "BadRunAfterFree"
    /\ UNCHANGED <<taskRefHeld, rcuReadHeld, rqLockHeld, piLockHeld, onRq,
                    migrating, frozenReleased, releaseCount,
                    releaseAfterSettled, deniedRecorded, retrySafe,
                    retryStableLifetime, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadRunWithoutStableLifetime ==
    /\ phase = "Start"
    /\ frozenGeneration' = taskGeneration
    /\ frozenIssued' = TRUE
    /\ frozenConsumed' = TRUE
    /\ runCommitted' = TRUE
    /\ running' = TRUE
    /\ commitStableLifetime' = FALSE
    /\ commitTaskLive' = TRUE
    /\ commitFreshGeneration' = TRUE
    /\ commitNoMigration' = TRUE
    /\ commitBeforeRelease' = TRUE
    /\ phase' = "BadRunWithoutStableLifetime"
    /\ UNCHANGED <<taskLive, taskGeneration, taskRefHeld, rcuReadHeld,
                    rqLockHeld, piLockHeld, onRq, migrating, frozenReleased,
                    releaseCount, releaseAfterSettled, deniedRecorded,
                    retrySafe, retryStableLifetime, moveSettled,
                    moveLockValid, failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadRcuOnlyAuthority ==
    /\ phase = "Start"
    /\ rcuReadHeld' = TRUE
    /\ frozenGeneration' = taskGeneration
    /\ frozenIssued' = TRUE
    /\ frozenConsumed' = TRUE
    /\ runCommitted' = TRUE
    /\ running' = TRUE
    /\ commitStableLifetime' = FALSE
    /\ commitTaskLive' = TRUE
    /\ commitFreshGeneration' = TRUE
    /\ commitNoMigration' = TRUE
    /\ commitBeforeRelease' = TRUE
    /\ phase' = "BadRcuOnlyAuthority"
    /\ UNCHANGED <<taskLive, taskGeneration, taskRefHeld, rqLockHeld,
                    piLockHeld, onRq, migrating, frozenReleased,
                    releaseCount, releaseAfterSettled, deniedRecorded,
                    retrySafe, retryStableLifetime, moveSettled,
                    moveLockValid, failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadRawPointerAuthority ==
    /\ phase = "Start"
    /\ frozenGeneration' = taskGeneration
    /\ frozenIssued' = TRUE
    /\ frozenConsumed' = TRUE
    /\ runCommitted' = TRUE
    /\ running' = TRUE
    /\ commitStableLifetime' = FALSE
    /\ commitTaskLive' = TRUE
    /\ commitFreshGeneration' = TRUE
    /\ commitNoMigration' = TRUE
    /\ commitBeforeRelease' = TRUE
    /\ phase' = "BadRawPointerAuthority"
    /\ UNCHANGED <<taskLive, taskGeneration, taskRefHeld, rcuReadHeld,
                    rqLockHeld, piLockHeld, onRq, migrating, frozenReleased,
                    releaseCount, releaseAfterSettled, deniedRecorded,
                    retrySafe, retryStableLifetime, moveSettled,
                    moveLockValid, failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadRunWhileMigrating ==
    /\ phase = "Start"
    /\ migrating' = TRUE
    /\ frozenGeneration' = taskGeneration
    /\ frozenIssued' = TRUE
    /\ frozenConsumed' = TRUE
    /\ runCommitted' = TRUE
    /\ running' = TRUE
    /\ commitStableLifetime' = TRUE
    /\ commitTaskLive' = TRUE
    /\ commitFreshGeneration' = TRUE
    /\ commitNoMigration' = FALSE
    /\ commitBeforeRelease' = TRUE
    /\ phase' = "BadRunWhileMigrating"
    /\ UNCHANGED <<taskLive, taskGeneration, taskRefHeld, rcuReadHeld,
                    rqLockHeld, piLockHeld, onRq, frozenReleased,
                    releaseCount, releaseAfterSettled, deniedRecorded,
                    retrySafe, retryStableLifetime, moveSettled,
                    moveLockValid, failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadStaleGenerationRun ==
    /\ phase = "Start"
    /\ taskGeneration' = 2
    /\ frozenGeneration' = 1
    /\ frozenIssued' = TRUE
    /\ frozenConsumed' = TRUE
    /\ runCommitted' = TRUE
    /\ running' = TRUE
    /\ commitStableLifetime' = TRUE
    /\ commitTaskLive' = TRUE
    /\ commitFreshGeneration' = FALSE
    /\ commitNoMigration' = TRUE
    /\ commitBeforeRelease' = TRUE
    /\ phase' = "BadStaleGenerationRun"
    /\ UNCHANGED <<taskLive, taskRefHeld, rcuReadHeld, rqLockHeld,
                    piLockHeld, onRq, migrating, frozenReleased,
                    releaseCount, releaseAfterSettled, deniedRecorded,
                    retrySafe, retryStableLifetime, moveSettled,
                    moveLockValid, failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadUseAfterRelease ==
    /\ phase = "Start"
    /\ frozenReleased' = TRUE
    /\ releaseCount' = 1
    /\ frozenGeneration' = taskGeneration
    /\ frozenIssued' = TRUE
    /\ frozenConsumed' = TRUE
    /\ runCommitted' = TRUE
    /\ running' = TRUE
    /\ commitStableLifetime' = TRUE
    /\ commitTaskLive' = TRUE
    /\ commitFreshGeneration' = TRUE
    /\ commitNoMigration' = TRUE
    /\ commitBeforeRelease' = FALSE
    /\ phase' = "BadUseAfterRelease"
    /\ UNCHANGED <<taskLive, taskGeneration, taskRefHeld, rcuReadHeld,
                    rqLockHeld, piLockHeld, onRq, migrating,
                    releaseAfterSettled, deniedRecorded, retrySafe,
                    retryStableLifetime, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadReleaseBeforeDenySettled ==
    /\ phase = "Start"
    /\ frozenIssued' = TRUE
    /\ frozenReleased' = TRUE
    /\ releaseCount' = 1
    /\ releaseAfterSettled' = FALSE
    /\ phase' = "BadReleaseBeforeDenySettled"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, taskRefHeld,
                    rcuReadHeld, rqLockHeld, piLockHeld, onRq, migrating,
                    frozenConsumed, deniedRecorded, retrySafe,
                    retryStableLifetime, runCommitted, running,
                    commitStableLifetime, commitTaskLive,
                    commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadDoubleRelease ==
    /\ phase = "Start"
    /\ frozenIssued' = TRUE
    /\ frozenReleased' = TRUE
    /\ releaseCount' = 2
    /\ releaseAfterSettled' = TRUE
    /\ phase' = "BadDoubleRelease"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, taskRefHeld,
                    rcuReadHeld, rqLockHeld, piLockHeld, onRq, migrating,
                    frozenConsumed, deniedRecorded, retrySafe,
                    retryStableLifetime, runCommitted, running,
                    commitStableLifetime, commitTaskLive,
                    commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadRefLeak ==
    /\ phase = "Start"
    /\ taskRefHeld' = TRUE
    /\ rqLockHeld' = TRUE
    /\ piLockHeld' = TRUE
    /\ frozenReleased' = TRUE
    /\ releaseCount' = 1
    /\ releaseAfterSettled' = TRUE
    /\ phase' = "DoneRun"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, rcuReadHeld,
                    onRq, migrating, frozenIssued, frozenConsumed,
                    deniedRecorded, retrySafe, retryStableLifetime,
                    runCommitted, running, commitStableLifetime,
                    commitTaskLive, commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadMoveWithoutRqLock ==
    /\ phase = "Start"
    /\ frozenIssued' = TRUE
    /\ moveSettled' = TRUE
    /\ moveLockValid' = FALSE
    /\ phase' = "BadMoveWithoutRqLock"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, taskRefHeld,
                    rcuReadHeld, rqLockHeld, piLockHeld, onRq, migrating,
                    frozenConsumed, frozenReleased, releaseCount,
                    releaseAfterSettled, deniedRecorded, retrySafe,
                    retryStableLifetime, runCommitted, running,
                    commitStableLifetime, commitTaskLive,
                    commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, failedClosed,
                    exitInvalidationHandled, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

BadRetryWithoutStableLifetime ==
    /\ phase = "Start"
    /\ deniedRecorded' = TRUE
    /\ retrySafe' = TRUE
    /\ retryStableLifetime' = FALSE
    /\ phase' = "BadRetryWithoutStableLifetime"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, taskRefHeld,
                    rcuReadHeld, rqLockHeld, piLockHeld, onRq, migrating,
                    frozenIssued, frozenConsumed, frozenReleased,
                    releaseCount, releaseAfterSettled, runCommitted,
                    running, commitStableLifetime, commitTaskLive,
                    commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadExitInvalidationIgnored ==
    /\ phase = "Start"
    /\ taskLive' = FALSE
    /\ taskGeneration' = 2
    /\ frozenGeneration' = 1
    /\ frozenIssued' = TRUE
    /\ failedClosed' = TRUE
    /\ exitInvalidationHandled' = FALSE
    /\ phase' = "BadExitInvalidationIgnored"
    /\ UNCHANGED <<taskRefHeld, rcuReadHeld, rqLockHeld, piLockHeld, onRq,
                    migrating, frozenConsumed, frozenReleased, releaseCount,
                    releaseAfterSettled, deniedRecorded, retrySafe,
                    retryStableLifetime, runCommitted, running,
                    commitStableLifetime, commitTaskLive,
                    commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadBehaviorChangeClaim ==
    /\ phase = "Start"
    /\ behaviorChangeClaim' = TRUE
    /\ phase' = "BadBehaviorChangeClaim"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, taskRefHeld,
                    rcuReadHeld, rqLockHeld, piLockHeld, onRq, migrating,
                    frozenIssued, frozenConsumed, frozenReleased,
                    releaseCount, releaseAfterSettled, deniedRecorded,
                    retrySafe, retryStableLifetime, runCommitted, running,
                    commitStableLifetime, commitTaskLive,
                    commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    monitorVerifiedClaim, protectionClaim>>

BadMonitorVerifiedClaim ==
    /\ phase = "Start"
    /\ monitorVerifiedClaim' = TRUE
    /\ phase' = "BadMonitorVerifiedClaim"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, taskRefHeld,
                    rcuReadHeld, rqLockHeld, piLockHeld, onRq, migrating,
                    frozenIssued, frozenConsumed, frozenReleased,
                    releaseCount, releaseAfterSettled, deniedRecorded,
                    retrySafe, retryStableLifetime, runCommitted, running,
                    commitStableLifetime, commitTaskLive,
                    commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, protectionClaim>>

BadProtectionClaim ==
    /\ phase = "Start"
    /\ protectionClaim' = TRUE
    /\ phase' = "BadProtectionClaim"
    /\ UNCHANGED <<taskLive, taskGeneration, frozenGeneration, taskRefHeld,
                    rcuReadHeld, rqLockHeld, piLockHeld, onRq, migrating,
                    frozenIssued, frozenConsumed, frozenReleased,
                    releaseCount, releaseAfterSettled, deniedRecorded,
                    retrySafe, retryStableLifetime, runCommitted, running,
                    commitStableLifetime, commitTaskLive,
                    commitFreshGeneration, commitNoMigration,
                    commitBeforeRelease, moveSettled, moveLockValid,
                    failedClosed, exitInvalidationHandled,
                    behaviorChangeClaim, monitorVerifiedClaim>>

NoBadPhase == phase \notin BadPhases
NoRunAfterFree == runCommitted => commitTaskLive
NoRunWithoutStableLifetime == runCommitted => commitStableLifetime
NoRunWhileMigrating == runCommitted => commitNoMigration
NoStaleGenerationRun == runCommitted => commitFreshGeneration
NoUseAfterRelease == runCommitted => commitBeforeRelease
NoReleaseBeforeDenySettled == releaseCount = 0 \/ releaseAfterSettled
NoDoubleRelease == releaseCount <= 1
NoRefLeakAtTerminal ==
    phase \in TerminalPhases => ~taskRefHeld /\ ~rqLockHeld /\ ~piLockHeld
NoMoveWithoutRqLock == moveSettled => moveLockValid
NoRetryWithoutStableLifetime == retrySafe => retryStableLifetime
NoExitInvalidationIgnored == (failedClosed /\ ~taskLive) => exitInvalidationHandled
NoNonClaimOverreach ==
    /\ ~behaviorChangeClaim
    /\ ~monitorVerifiedClaim
    /\ ~protectionClaim

Safety ==
    /\ TypeOK
    /\ NoBadPhase
    /\ NoRunAfterFree
    /\ NoRunWithoutStableLifetime
    /\ NoRunWhileMigrating
    /\ NoStaleGenerationRun
    /\ NoUseAfterRelease
    /\ NoReleaseBeforeDenySettled
    /\ NoDoubleRelease
    /\ NoRefLeakAtTerminal
    /\ NoMoveWithoutRqLock
    /\ NoRetryWithoutStableLifetime
    /\ NoExitInvalidationIgnored
    /\ NoNonClaimOverreach

Spec == Init /\ [][SafeNext]_vars

UnsafeRunAfterFreeSpec == Init /\ [][BadRunAfterFree]_vars
UnsafeRunWithoutStableLifetimeSpec == Init /\ [][BadRunWithoutStableLifetime]_vars
UnsafeRcuOnlyAuthoritySpec == Init /\ [][BadRcuOnlyAuthority]_vars
UnsafeRawPointerAuthoritySpec == Init /\ [][BadRawPointerAuthority]_vars
UnsafeRunWhileMigratingSpec == Init /\ [][BadRunWhileMigrating]_vars
UnsafeStaleGenerationRunSpec == Init /\ [][BadStaleGenerationRun]_vars
UnsafeUseAfterReleaseSpec == Init /\ [][BadUseAfterRelease]_vars
UnsafeReleaseBeforeDenySettledSpec == Init /\ [][BadReleaseBeforeDenySettled]_vars
UnsafeDoubleReleaseSpec == Init /\ [][BadDoubleRelease]_vars
UnsafeRefLeakSpec == Init /\ [][BadRefLeak]_vars
UnsafeMoveWithoutRqLockSpec == Init /\ [][BadMoveWithoutRqLock]_vars
UnsafeRetryWithoutStableLifetimeSpec == Init /\ [][BadRetryWithoutStableLifetime]_vars
UnsafeExitInvalidationIgnoredSpec == Init /\ [][BadExitInvalidationIgnored]_vars
UnsafeBehaviorChangeClaimSpec == Init /\ [][BadBehaviorChangeClaim]_vars
UnsafeMonitorVerifiedClaimSpec == Init /\ [][BadMonitorVerifiedClaim]_vars
UnsafeProtectionClaimSpec == Init /\ [][BadProtectionClaim]_vars

====
