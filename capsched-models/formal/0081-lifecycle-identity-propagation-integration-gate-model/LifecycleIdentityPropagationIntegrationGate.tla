---------- MODULE LifecycleIdentityPropagationIntegrationGate ----------
EXTENDS Naturals

VARIABLES
    phase,
    spawnCap,
    domainToken,
    cloneNewDomainRequested,
    childThreadClone,
    childTaskFresh,
    childProcessFresh,
    childDomainAuthorized,
    childSchedCtxBound,
    childRunCapInherited,
    childFrozenInherited,
    childRunTokenInherited,
    childPublished,
    wakeAfterIdentity,
    childRunning,
    execCommitted,
    execCheckOnly,
    execDomainStable,
    execDomainToken,
    execContinuation,
    execProgramFresh,
    oldFrozenRunUseReused,
    currentRunningAfterExec,
    exitInvalidatedTask,
    releaseSettled,
    staleTaskRuns,
    pidReuseAuthority,
    releaseAuthority,
    behaviorChangeClaim,
    monitorVerifiedClaim,
    protectionClaim

vars == <<phase, spawnCap, domainToken, cloneNewDomainRequested,
          childThreadClone, childTaskFresh, childProcessFresh,
          childDomainAuthorized, childSchedCtxBound, childRunCapInherited,
          childFrozenInherited, childRunTokenInherited, childPublished,
          wakeAfterIdentity, childRunning, execCommitted, execCheckOnly,
          execDomainStable, execDomainToken, execContinuation,
          execProgramFresh, oldFrozenRunUseReused, currentRunningAfterExec,
          exitInvalidatedTask, releaseSettled, staleTaskRuns,
          pidReuseAuthority, releaseAuthority, behaviorChangeClaim,
          monitorVerifiedClaim, protectionClaim>>

GoodPhases == {
    "Start",
    "SpawnedProcess",
    "SpawnedThread",
    "SpawnedNewDomain",
    "ChildRunning",
    "ExecPrepared",
    "ExecCommitted",
    "ExecRunning",
    "CheckOnly",
    "Exiting",
    "Released",
    "Done"
}

BadPhases == {
    "BadRunWithoutSpawnCap",
    "BadChildNoTaskGeneration",
    "BadProcessNoFreshGeneration",
    "BadAmbientRunCapInheritance",
    "BadFrozenRunUseInheritance",
    "BadRunTokenInheritance",
    "BadSchedContextUnbound",
    "BadWakeBeforeIdentity",
    "BadNewDomainWithoutToken",
    "BadCloneFlagsDomainAuthority",
    "BadExecDomainChangeWithoutToken",
    "BadExecRunNoContinuation",
    "BadExecCheckOnlyMutation",
    "BadOldFrozenAfterExec",
    "BadRunAfterExit",
    "BadPidReuseAuthority",
    "BadReleaseAuthority",
    "BadBehaviorChangeClaim",
    "BadMonitorVerifiedClaim",
    "BadProtectionClaim"
}

Phases == GoodPhases \cup BadPhases
TerminalPhases == {"ChildRunning", "ExecRunning", "CheckOnly", "Released", "Done"}

TypeOK ==
    /\ phase \in Phases
    /\ spawnCap \in BOOLEAN
    /\ domainToken \in BOOLEAN
    /\ cloneNewDomainRequested \in BOOLEAN
    /\ childThreadClone \in BOOLEAN
    /\ childTaskFresh \in BOOLEAN
    /\ childProcessFresh \in BOOLEAN
    /\ childDomainAuthorized \in BOOLEAN
    /\ childSchedCtxBound \in BOOLEAN
    /\ childRunCapInherited \in BOOLEAN
    /\ childFrozenInherited \in BOOLEAN
    /\ childRunTokenInherited \in BOOLEAN
    /\ childPublished \in BOOLEAN
    /\ wakeAfterIdentity \in BOOLEAN
    /\ childRunning \in BOOLEAN
    /\ execCommitted \in BOOLEAN
    /\ execCheckOnly \in BOOLEAN
    /\ execDomainStable \in BOOLEAN
    /\ execDomainToken \in BOOLEAN
    /\ execContinuation \in BOOLEAN
    /\ execProgramFresh \in BOOLEAN
    /\ oldFrozenRunUseReused \in BOOLEAN
    /\ currentRunningAfterExec \in BOOLEAN
    /\ exitInvalidatedTask \in BOOLEAN
    /\ releaseSettled \in BOOLEAN
    /\ staleTaskRuns \in BOOLEAN
    /\ pidReuseAuthority \in BOOLEAN
    /\ releaseAuthority \in BOOLEAN
    /\ behaviorChangeClaim \in BOOLEAN
    /\ monitorVerifiedClaim \in BOOLEAN
    /\ protectionClaim \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ spawnCap = FALSE
    /\ domainToken = FALSE
    /\ cloneNewDomainRequested = FALSE
    /\ childThreadClone = FALSE
    /\ childTaskFresh = FALSE
    /\ childProcessFresh = FALSE
    /\ childDomainAuthorized = FALSE
    /\ childSchedCtxBound = FALSE
    /\ childRunCapInherited = FALSE
    /\ childFrozenInherited = FALSE
    /\ childRunTokenInherited = FALSE
    /\ childPublished = FALSE
    /\ wakeAfterIdentity = FALSE
    /\ childRunning = FALSE
    /\ execCommitted = FALSE
    /\ execCheckOnly = FALSE
    /\ execDomainStable = FALSE
    /\ execDomainToken = FALSE
    /\ execContinuation = FALSE
    /\ execProgramFresh = FALSE
    /\ oldFrozenRunUseReused = FALSE
    /\ currentRunningAfterExec = FALSE
    /\ exitInvalidatedTask = FALSE
    /\ releaseSettled = FALSE
    /\ staleTaskRuns = FALSE
    /\ pidReuseAuthority = FALSE
    /\ releaseAuthority = FALSE
    /\ behaviorChangeClaim = FALSE
    /\ monitorVerifiedClaim = FALSE
    /\ protectionClaim = FALSE

SpawnSameDomainProcess ==
    /\ phase = "Start"
    /\ spawnCap' = TRUE
    /\ childTaskFresh' = TRUE
    /\ childProcessFresh' = TRUE
    /\ childDomainAuthorized' = TRUE
    /\ childSchedCtxBound' = TRUE
    /\ childPublished' = TRUE
    /\ wakeAfterIdentity' = TRUE
    /\ phase' = "SpawnedProcess"
    /\ UNCHANGED <<domainToken, cloneNewDomainRequested, childThreadClone,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childRunning, execCommitted,
                    execCheckOnly, execDomainStable, execDomainToken,
                    execContinuation, execProgramFresh,
                    oldFrozenRunUseReused, currentRunningAfterExec,
                    exitInvalidatedTask, releaseSettled, staleTaskRuns,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

SpawnSameDomainThread ==
    /\ phase = "Start"
    /\ spawnCap' = TRUE
    /\ childThreadClone' = TRUE
    /\ childTaskFresh' = TRUE
    /\ childProcessFresh' = FALSE
    /\ childDomainAuthorized' = TRUE
    /\ childSchedCtxBound' = TRUE
    /\ childPublished' = TRUE
    /\ wakeAfterIdentity' = TRUE
    /\ phase' = "SpawnedThread"
    /\ UNCHANGED <<domainToken, cloneNewDomainRequested,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childRunning, execCommitted,
                    execCheckOnly, execDomainStable, execDomainToken,
                    execContinuation, execProgramFresh,
                    oldFrozenRunUseReused, currentRunningAfterExec,
                    exitInvalidatedTask, releaseSettled, staleTaskRuns,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

SpawnNewDomainWithToken ==
    /\ phase = "Start"
    /\ spawnCap' = TRUE
    /\ domainToken' = TRUE
    /\ cloneNewDomainRequested' = TRUE
    /\ childTaskFresh' = TRUE
    /\ childProcessFresh' = TRUE
    /\ childDomainAuthorized' = TRUE
    /\ childSchedCtxBound' = TRUE
    /\ childPublished' = TRUE
    /\ wakeAfterIdentity' = TRUE
    /\ phase' = "SpawnedNewDomain"
    /\ UNCHANGED <<childThreadClone, childRunCapInherited,
                    childFrozenInherited, childRunTokenInherited,
                    childRunning, execCommitted, execCheckOnly,
                    execDomainStable, execDomainToken, execContinuation,
                    execProgramFresh, oldFrozenRunUseReused,
                    currentRunningAfterExec, exitInvalidatedTask,
                    releaseSettled, staleTaskRuns, pidReuseAuthority,
                    releaseAuthority, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

RunSpawnedChild ==
    /\ phase \in {"SpawnedProcess", "SpawnedThread", "SpawnedNewDomain"}
    /\ spawnCap
    /\ childTaskFresh
    /\ (childThreadClone \/ childProcessFresh)
    /\ childDomainAuthorized
    /\ childSchedCtxBound
    /\ childPublished
    /\ wakeAfterIdentity
    /\ ~childRunCapInherited
    /\ ~childFrozenInherited
    /\ ~childRunTokenInherited
    /\ childRunning' = TRUE
    /\ phase' = "ChildRunning"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    execCommitted, execCheckOnly, execDomainStable,
                    execDomainToken, execContinuation, execProgramFresh,
                    oldFrozenRunUseReused, currentRunningAfterExec,
                    exitInvalidatedTask, releaseSettled, staleTaskRuns,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

PrepareExec ==
    /\ phase = "Start"
    /\ execDomainStable' = TRUE
    /\ execContinuation' = TRUE
    /\ phase' = "ExecPrepared"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    childRunning, execCommitted, execCheckOnly,
                    execDomainToken, execProgramFresh, oldFrozenRunUseReused,
                    currentRunningAfterExec, exitInvalidatedTask,
                    releaseSettled, staleTaskRuns, pidReuseAuthority,
                    releaseAuthority, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

CheckOnlyExec ==
    /\ phase = "ExecPrepared"
    /\ execCheckOnly' = TRUE
    /\ phase' = "CheckOnly"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    childRunning, execCommitted, execDomainStable,
                    execDomainToken, execContinuation, execProgramFresh,
                    oldFrozenRunUseReused, currentRunningAfterExec,
                    exitInvalidatedTask, releaseSettled, staleTaskRuns,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

CommitExec ==
    /\ phase = "ExecPrepared"
    /\ execDomainStable
    /\ execContinuation
    /\ execCommitted' = TRUE
    /\ execProgramFresh' = TRUE
    /\ oldFrozenRunUseReused' = FALSE
    /\ phase' = "ExecCommitted"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    childRunning, execCheckOnly, execDomainStable,
                    execDomainToken, execContinuation,
                    currentRunningAfterExec, exitInvalidatedTask,
                    releaseSettled, staleTaskRuns, pidReuseAuthority,
                    releaseAuthority, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

RunAfterExec ==
    /\ phase = "ExecCommitted"
    /\ execCommitted
    /\ execDomainStable
    /\ execContinuation
    /\ execProgramFresh
    /\ ~oldFrozenRunUseReused
    /\ currentRunningAfterExec' = TRUE
    /\ phase' = "ExecRunning"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    childRunning, execCommitted, execCheckOnly,
                    execDomainStable, execDomainToken, execContinuation,
                    execProgramFresh, oldFrozenRunUseReused,
                    exitInvalidatedTask, releaseSettled, staleTaskRuns,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

ExitInvalidates ==
    /\ phase = "Start"
    /\ exitInvalidatedTask' = TRUE
    /\ phase' = "Exiting"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    childRunning, execCommitted, execCheckOnly,
                    execDomainStable, execDomainToken, execContinuation,
                    execProgramFresh, oldFrozenRunUseReused,
                    currentRunningAfterExec, releaseSettled, staleTaskRuns,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

ReleaseAfterExit ==
    /\ phase = "Exiting"
    /\ exitInvalidatedTask
    /\ releaseSettled' = TRUE
    /\ phase' = "Released"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    childRunning, execCommitted, execCheckOnly,
                    execDomainStable, execDomainToken, execContinuation,
                    execProgramFresh, oldFrozenRunUseReused,
                    currentRunningAfterExec, exitInvalidatedTask,
                    staleTaskRuns, pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

TerminalStutter ==
    /\ phase \in TerminalPhases
    /\ UNCHANGED vars

SafeNext ==
    \/ SpawnSameDomainProcess
    \/ SpawnSameDomainThread
    \/ SpawnNewDomainWithToken
    \/ RunSpawnedChild
    \/ PrepareExec
    \/ CheckOnlyExec
    \/ CommitExec
    \/ RunAfterExec
    \/ ExitInvalidates
    \/ ReleaseAfterExit
    \/ TerminalStutter

BadRunWithoutSpawnCap ==
    /\ phase = "Start"
    /\ childTaskFresh' = TRUE
    /\ childProcessFresh' = TRUE
    /\ childDomainAuthorized' = TRUE
    /\ childSchedCtxBound' = TRUE
    /\ childPublished' = TRUE
    /\ wakeAfterIdentity' = TRUE
    /\ childRunning' = TRUE
    /\ phase' = "BadRunWithoutSpawnCap"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childRunCapInherited,
                    childFrozenInherited, childRunTokenInherited,
                    execCommitted, execCheckOnly, execDomainStable,
                    execDomainToken, execContinuation, execProgramFresh,
                    oldFrozenRunUseReused, currentRunningAfterExec,
                    exitInvalidatedTask, releaseSettled, staleTaskRuns,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadChildNoTaskGeneration ==
    /\ phase = "Start"
    /\ spawnCap' = TRUE
    /\ childProcessFresh' = TRUE
    /\ childDomainAuthorized' = TRUE
    /\ childSchedCtxBound' = TRUE
    /\ childPublished' = TRUE
    /\ wakeAfterIdentity' = TRUE
    /\ childRunning' = TRUE
    /\ phase' = "BadChildNoTaskGeneration"
    /\ UNCHANGED <<domainToken, cloneNewDomainRequested, childThreadClone,
                    childTaskFresh, childRunCapInherited,
                    childFrozenInherited, childRunTokenInherited,
                    execCommitted, execCheckOnly, execDomainStable,
                    execDomainToken, execContinuation, execProgramFresh,
                    oldFrozenRunUseReused, currentRunningAfterExec,
                    exitInvalidatedTask, releaseSettled, staleTaskRuns,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadProcessNoFreshGeneration ==
    /\ phase = "Start"
    /\ spawnCap' = TRUE
    /\ childThreadClone' = FALSE
    /\ childTaskFresh' = TRUE
    /\ childProcessFresh' = FALSE
    /\ childDomainAuthorized' = TRUE
    /\ childSchedCtxBound' = TRUE
    /\ childPublished' = TRUE
    /\ wakeAfterIdentity' = TRUE
    /\ childRunning' = TRUE
    /\ phase' = "BadProcessNoFreshGeneration"
    /\ UNCHANGED <<domainToken, cloneNewDomainRequested,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, execCommitted, execCheckOnly,
                    execDomainStable, execDomainToken, execContinuation,
                    execProgramFresh, oldFrozenRunUseReused,
                    currentRunningAfterExec, exitInvalidatedTask,
                    releaseSettled, staleTaskRuns, pidReuseAuthority,
                    releaseAuthority, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

BadAmbientRunCapInheritance ==
    /\ phase = "Start"
    /\ spawnCap' = TRUE
    /\ childTaskFresh' = TRUE
    /\ childProcessFresh' = TRUE
    /\ childDomainAuthorized' = TRUE
    /\ childSchedCtxBound' = TRUE
    /\ childRunCapInherited' = TRUE
    /\ childPublished' = TRUE
    /\ wakeAfterIdentity' = TRUE
    /\ childRunning' = TRUE
    /\ phase' = "BadAmbientRunCapInheritance"
    /\ UNCHANGED <<domainToken, cloneNewDomainRequested, childThreadClone,
                    childFrozenInherited, childRunTokenInherited,
                    execCommitted, execCheckOnly, execDomainStable,
                    execDomainToken, execContinuation, execProgramFresh,
                    oldFrozenRunUseReused, currentRunningAfterExec,
                    exitInvalidatedTask, releaseSettled, staleTaskRuns,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadFrozenRunUseInheritance ==
    /\ phase = "Start"
    /\ spawnCap' = TRUE
    /\ childTaskFresh' = TRUE
    /\ childProcessFresh' = TRUE
    /\ childDomainAuthorized' = TRUE
    /\ childSchedCtxBound' = TRUE
    /\ childFrozenInherited' = TRUE
    /\ childPublished' = TRUE
    /\ wakeAfterIdentity' = TRUE
    /\ childRunning' = TRUE
    /\ phase' = "BadFrozenRunUseInheritance"
    /\ UNCHANGED <<domainToken, cloneNewDomainRequested, childThreadClone,
                    childRunCapInherited, childRunTokenInherited,
                    execCommitted, execCheckOnly, execDomainStable,
                    execDomainToken, execContinuation, execProgramFresh,
                    oldFrozenRunUseReused, currentRunningAfterExec,
                    exitInvalidatedTask, releaseSettled, staleTaskRuns,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadRunTokenInheritance ==
    /\ phase = "Start"
    /\ spawnCap' = TRUE
    /\ childTaskFresh' = TRUE
    /\ childProcessFresh' = TRUE
    /\ childDomainAuthorized' = TRUE
    /\ childSchedCtxBound' = TRUE
    /\ childRunTokenInherited' = TRUE
    /\ childPublished' = TRUE
    /\ wakeAfterIdentity' = TRUE
    /\ childRunning' = TRUE
    /\ phase' = "BadRunTokenInheritance"
    /\ UNCHANGED <<domainToken, cloneNewDomainRequested, childThreadClone,
                    childRunCapInherited, childFrozenInherited,
                    execCommitted, execCheckOnly, execDomainStable,
                    execDomainToken, execContinuation, execProgramFresh,
                    oldFrozenRunUseReused, currentRunningAfterExec,
                    exitInvalidatedTask, releaseSettled, staleTaskRuns,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadSchedContextUnbound ==
    /\ phase = "Start"
    /\ spawnCap' = TRUE
    /\ childTaskFresh' = TRUE
    /\ childProcessFresh' = TRUE
    /\ childDomainAuthorized' = TRUE
    /\ childPublished' = TRUE
    /\ wakeAfterIdentity' = TRUE
    /\ childRunning' = TRUE
    /\ phase' = "BadSchedContextUnbound"
    /\ UNCHANGED <<domainToken, cloneNewDomainRequested, childThreadClone,
                    childSchedCtxBound, childRunCapInherited,
                    childFrozenInherited, childRunTokenInherited,
                    execCommitted, execCheckOnly, execDomainStable,
                    execDomainToken, execContinuation, execProgramFresh,
                    oldFrozenRunUseReused, currentRunningAfterExec,
                    exitInvalidatedTask, releaseSettled, staleTaskRuns,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadWakeBeforeIdentity ==
    /\ phase = "Start"
    /\ spawnCap' = TRUE
    /\ childTaskFresh' = TRUE
    /\ childProcessFresh' = TRUE
    /\ childDomainAuthorized' = TRUE
    /\ childSchedCtxBound' = TRUE
    /\ childPublished' = TRUE
    /\ wakeAfterIdentity' = FALSE
    /\ childRunning' = TRUE
    /\ phase' = "BadWakeBeforeIdentity"
    /\ UNCHANGED <<domainToken, cloneNewDomainRequested, childThreadClone,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, execCommitted, execCheckOnly,
                    execDomainStable, execDomainToken, execContinuation,
                    execProgramFresh, oldFrozenRunUseReused,
                    currentRunningAfterExec, exitInvalidatedTask,
                    releaseSettled, staleTaskRuns, pidReuseAuthority,
                    releaseAuthority, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

BadNewDomainWithoutToken ==
    /\ phase = "Start"
    /\ spawnCap' = TRUE
    /\ cloneNewDomainRequested' = TRUE
    /\ childTaskFresh' = TRUE
    /\ childProcessFresh' = TRUE
    /\ childDomainAuthorized' = TRUE
    /\ childSchedCtxBound' = TRUE
    /\ childPublished' = TRUE
    /\ wakeAfterIdentity' = TRUE
    /\ childRunning' = TRUE
    /\ phase' = "BadNewDomainWithoutToken"
    /\ UNCHANGED <<domainToken, childThreadClone, childRunCapInherited,
                    childFrozenInherited, childRunTokenInherited,
                    execCommitted, execCheckOnly, execDomainStable,
                    execDomainToken, execContinuation, execProgramFresh,
                    oldFrozenRunUseReused, currentRunningAfterExec,
                    exitInvalidatedTask, releaseSettled, staleTaskRuns,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadCloneFlagsDomainAuthority ==
    /\ phase = "Start"
    /\ cloneNewDomainRequested' = TRUE
    /\ childTaskFresh' = TRUE
    /\ childProcessFresh' = TRUE
    /\ childDomainAuthorized' = TRUE
    /\ childSchedCtxBound' = TRUE
    /\ childPublished' = TRUE
    /\ wakeAfterIdentity' = TRUE
    /\ childRunning' = TRUE
    /\ phase' = "BadCloneFlagsDomainAuthority"
    /\ UNCHANGED <<spawnCap, domainToken, childThreadClone,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, execCommitted, execCheckOnly,
                    execDomainStable, execDomainToken, execContinuation,
                    execProgramFresh, oldFrozenRunUseReused,
                    currentRunningAfterExec, exitInvalidatedTask,
                    releaseSettled, staleTaskRuns, pidReuseAuthority,
                    releaseAuthority, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

BadExecDomainChangeWithoutToken ==
    /\ phase = "Start"
    /\ execCommitted' = TRUE
    /\ execDomainStable' = FALSE
    /\ execDomainToken' = FALSE
    /\ execContinuation' = TRUE
    /\ execProgramFresh' = TRUE
    /\ currentRunningAfterExec' = TRUE
    /\ phase' = "BadExecDomainChangeWithoutToken"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    childRunning, execCheckOnly, oldFrozenRunUseReused,
                    exitInvalidatedTask, releaseSettled, staleTaskRuns,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadExecRunNoContinuation ==
    /\ phase = "Start"
    /\ execCommitted' = TRUE
    /\ execDomainStable' = TRUE
    /\ execProgramFresh' = TRUE
    /\ currentRunningAfterExec' = TRUE
    /\ phase' = "BadExecRunNoContinuation"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    childRunning, execCheckOnly, execDomainToken,
                    execContinuation, oldFrozenRunUseReused,
                    exitInvalidatedTask, releaseSettled, staleTaskRuns,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadExecCheckOnlyMutation ==
    /\ phase = "Start"
    /\ execCheckOnly' = TRUE
    /\ execCommitted' = TRUE
    /\ execProgramFresh' = TRUE
    /\ phase' = "BadExecCheckOnlyMutation"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    childRunning, execDomainStable, execDomainToken,
                    execContinuation, oldFrozenRunUseReused,
                    currentRunningAfterExec, exitInvalidatedTask,
                    releaseSettled, staleTaskRuns, pidReuseAuthority,
                    releaseAuthority, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

BadOldFrozenAfterExec ==
    /\ phase = "Start"
    /\ execCommitted' = TRUE
    /\ execDomainStable' = TRUE
    /\ execContinuation' = TRUE
    /\ execProgramFresh' = TRUE
    /\ oldFrozenRunUseReused' = TRUE
    /\ currentRunningAfterExec' = TRUE
    /\ phase' = "BadOldFrozenAfterExec"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    childRunning, execCheckOnly, execDomainToken,
                    exitInvalidatedTask, releaseSettled, staleTaskRuns,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadRunAfterExit ==
    /\ phase = "Start"
    /\ exitInvalidatedTask' = TRUE
    /\ staleTaskRuns' = TRUE
    /\ phase' = "BadRunAfterExit"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    childRunning, execCommitted, execCheckOnly,
                    execDomainStable, execDomainToken, execContinuation,
                    execProgramFresh, oldFrozenRunUseReused,
                    currentRunningAfterExec, releaseSettled,
                    pidReuseAuthority, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadPidReuseAuthority ==
    /\ phase = "Start"
    /\ pidReuseAuthority' = TRUE
    /\ phase' = "BadPidReuseAuthority"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    childRunning, execCommitted, execCheckOnly,
                    execDomainStable, execDomainToken, execContinuation,
                    execProgramFresh, oldFrozenRunUseReused,
                    currentRunningAfterExec, exitInvalidatedTask,
                    releaseSettled, staleTaskRuns, releaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadReleaseAuthority ==
    /\ phase = "Start"
    /\ releaseAuthority' = TRUE
    /\ phase' = "BadReleaseAuthority"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    childRunning, execCommitted, execCheckOnly,
                    execDomainStable, execDomainToken, execContinuation,
                    execProgramFresh, oldFrozenRunUseReused,
                    currentRunningAfterExec, exitInvalidatedTask,
                    releaseSettled, staleTaskRuns, pidReuseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

BadBehaviorChangeClaim ==
    /\ phase = "Start"
    /\ behaviorChangeClaim' = TRUE
    /\ phase' = "BadBehaviorChangeClaim"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    childRunning, execCommitted, execCheckOnly,
                    execDomainStable, execDomainToken, execContinuation,
                    execProgramFresh, oldFrozenRunUseReused,
                    currentRunningAfterExec, exitInvalidatedTask,
                    releaseSettled, staleTaskRuns, pidReuseAuthority,
                    releaseAuthority, monitorVerifiedClaim,
                    protectionClaim>>

BadMonitorVerifiedClaim ==
    /\ phase = "Start"
    /\ monitorVerifiedClaim' = TRUE
    /\ phase' = "BadMonitorVerifiedClaim"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    childRunning, execCommitted, execCheckOnly,
                    execDomainStable, execDomainToken, execContinuation,
                    execProgramFresh, oldFrozenRunUseReused,
                    currentRunningAfterExec, exitInvalidatedTask,
                    releaseSettled, staleTaskRuns, pidReuseAuthority,
                    releaseAuthority, behaviorChangeClaim,
                    protectionClaim>>

BadProtectionClaim ==
    /\ phase = "Start"
    /\ protectionClaim' = TRUE
    /\ phase' = "BadProtectionClaim"
    /\ UNCHANGED <<spawnCap, domainToken, cloneNewDomainRequested,
                    childThreadClone, childTaskFresh, childProcessFresh,
                    childDomainAuthorized, childSchedCtxBound,
                    childRunCapInherited, childFrozenInherited,
                    childRunTokenInherited, childPublished, wakeAfterIdentity,
                    childRunning, execCommitted, execCheckOnly,
                    execDomainStable, execDomainToken, execContinuation,
                    execProgramFresh, oldFrozenRunUseReused,
                    currentRunningAfterExec, exitInvalidatedTask,
                    releaseSettled, staleTaskRuns, pidReuseAuthority,
                    releaseAuthority, behaviorChangeClaim,
                    monitorVerifiedClaim>>

NoBadPhase == phase \notin BadPhases
NoChildRunWithoutSpawnAuthority == childRunning => spawnCap
NoChildRunWithoutFreshTaskGeneration == childRunning => childTaskFresh
NoProcessCloneWithoutProcessGeneration ==
    childRunning => (childThreadClone \/ childProcessFresh)
NoAmbientRunAuthorityInheritance ==
    childRunning => ~childRunCapInherited /\ ~childFrozenInherited /\ ~childRunTokenInherited
NoUnboundSchedContextInheritance == childRunning => childSchedCtxBound
NoWakeBeforeIdentity == childRunning => childPublished /\ wakeAfterIdentity
NoNewDomainWithoutToken ==
    (childRunning /\ cloneNewDomainRequested) => domainToken
NoCloneFlagsAsDomainAuthority ==
    (childRunning /\ cloneNewDomainRequested) => spawnCap /\ domainToken /\ childDomainAuthorized
NoExecDomainChangeWithoutToken ==
    (currentRunningAfterExec /\ ~execDomainStable) => execDomainToken
NoRunAfterExecWithoutContinuation ==
    currentRunningAfterExec => execCommitted /\ execContinuation /\ execProgramFresh
NoCheckOnlyMutation == execCheckOnly => ~execCommitted /\ ~execProgramFresh
NoOldFrozenRunUseAfterExec == currentRunningAfterExec => ~oldFrozenRunUseReused
NoRunAfterExitInvalidation ==
    exitInvalidatedTask => ~(childRunning \/ currentRunningAfterExec \/ staleTaskRuns)
NoPidReuseAuthority == ~pidReuseAuthority
NoReleaseAuthority == ~releaseAuthority
NoNonClaimOverreach ==
    /\ ~behaviorChangeClaim
    /\ ~monitorVerifiedClaim
    /\ ~protectionClaim

Safety ==
    /\ TypeOK
    /\ NoBadPhase
    /\ NoChildRunWithoutSpawnAuthority
    /\ NoChildRunWithoutFreshTaskGeneration
    /\ NoProcessCloneWithoutProcessGeneration
    /\ NoAmbientRunAuthorityInheritance
    /\ NoUnboundSchedContextInheritance
    /\ NoWakeBeforeIdentity
    /\ NoNewDomainWithoutToken
    /\ NoCloneFlagsAsDomainAuthority
    /\ NoExecDomainChangeWithoutToken
    /\ NoRunAfterExecWithoutContinuation
    /\ NoCheckOnlyMutation
    /\ NoOldFrozenRunUseAfterExec
    /\ NoRunAfterExitInvalidation
    /\ NoPidReuseAuthority
    /\ NoReleaseAuthority
    /\ NoNonClaimOverreach

Spec == Init /\ [][SafeNext]_vars

UnsafeRunWithoutSpawnCapSpec == Init /\ [][BadRunWithoutSpawnCap]_vars
UnsafeChildNoTaskGenerationSpec == Init /\ [][BadChildNoTaskGeneration]_vars
UnsafeProcessNoFreshGenerationSpec == Init /\ [][BadProcessNoFreshGeneration]_vars
UnsafeAmbientRunCapInheritanceSpec == Init /\ [][BadAmbientRunCapInheritance]_vars
UnsafeFrozenRunUseInheritanceSpec == Init /\ [][BadFrozenRunUseInheritance]_vars
UnsafeRunTokenInheritanceSpec == Init /\ [][BadRunTokenInheritance]_vars
UnsafeSchedContextUnboundSpec == Init /\ [][BadSchedContextUnbound]_vars
UnsafeWakeBeforeIdentitySpec == Init /\ [][BadWakeBeforeIdentity]_vars
UnsafeNewDomainWithoutTokenSpec == Init /\ [][BadNewDomainWithoutToken]_vars
UnsafeCloneFlagsDomainAuthoritySpec == Init /\ [][BadCloneFlagsDomainAuthority]_vars
UnsafeExecDomainChangeWithoutTokenSpec == Init /\ [][BadExecDomainChangeWithoutToken]_vars
UnsafeExecRunNoContinuationSpec == Init /\ [][BadExecRunNoContinuation]_vars
UnsafeExecCheckOnlyMutationSpec == Init /\ [][BadExecCheckOnlyMutation]_vars
UnsafeOldFrozenAfterExecSpec == Init /\ [][BadOldFrozenAfterExec]_vars
UnsafeRunAfterExitSpec == Init /\ [][BadRunAfterExit]_vars
UnsafePidReuseAuthoritySpec == Init /\ [][BadPidReuseAuthority]_vars
UnsafeReleaseAuthoritySpec == Init /\ [][BadReleaseAuthority]_vars
UnsafeBehaviorChangeClaimSpec == Init /\ [][BadBehaviorChangeClaim]_vars
UnsafeMonitorVerifiedClaimSpec == Init /\ [][BadMonitorVerifiedClaim]_vars
UnsafeProtectionClaimSpec == Init /\ [][BadProtectionClaim]_vars

====
