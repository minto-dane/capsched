---------- MODULE FinalRunMoveRevalidationHookPlacementGate ----------
EXTENDS Naturals

VARIABLES
    phase,
    taskKind,
    domainGrant,
    schedContextGrant,
    runCapGrant,
    runAuthority,
    taskGen,
    domainEpoch,
    schedCtxEpoch,
    runCapEpoch,
    moveSeq,
    coreSeq,
    scxSeq,
    capEnvelope,
    linuxMask,
    activeMask,
    monitorCpuSet,
    memoryViewCpuSet,
    currentCpu,
    selectedCpu,
    runCpu,
    destCpu,
    edgeKind,
    tupleKind,
    tupleEdge,
    tupleDest,
    tupleTaskGen,
    tupleDomainEpoch,
    tupleSchedCtxEpoch,
    tupleRunCapEpoch,
    tupleMoveSeq,
    tupleCoreSeq,
    tupleScxSeq,
    tupleIssued,
    tupleConsumed,
    migrationPending,
    rqCurrCommitted,
    contextSwitched,
    running,
    moveCommitted,
    failClosed,
    pickNextAuthority,
    setTaskCpuAuthority,
    moveQueuedAuthority,
    attachTaskAuthority,
    fairBalanceAuthority,
    rtPushPullAuthority,
    dlPushPullAuthority,
    scxDispatchAuthority,
    coreSchedulingAuthority,
    proxyMigrateAuthority,
    hotplugPushAuthority,
    migrationStopAuthority,
    linuxExceptionAuthority,
    hookAfterRqCurrCommit,
    linuxHookApproved,
    behaviorChangeClaim,
    monitorVerifiedClaim,
    protectionClaim

vars == <<phase, taskKind, domainGrant, schedContextGrant, runCapGrant,
          runAuthority, taskGen, domainEpoch, schedCtxEpoch, runCapEpoch,
          moveSeq, coreSeq, scxSeq, capEnvelope, linuxMask, activeMask,
          monitorCpuSet, memoryViewCpuSet, currentCpu, selectedCpu, runCpu,
          destCpu, edgeKind, tupleKind, tupleEdge, tupleDest, tupleTaskGen,
          tupleDomainEpoch, tupleSchedCtxEpoch, tupleRunCapEpoch,
          tupleMoveSeq, tupleCoreSeq, tupleScxSeq, tupleIssued,
          tupleConsumed, migrationPending, rqCurrCommitted, contextSwitched,
          running, moveCommitted, failClosed, pickNextAuthority,
          setTaskCpuAuthority, moveQueuedAuthority, attachTaskAuthority,
          fairBalanceAuthority, rtPushPullAuthority, dlPushPullAuthority,
          scxDispatchAuthority, coreSchedulingAuthority, proxyMigrateAuthority,
          hotplugPushAuthority, migrationStopAuthority, linuxExceptionAuthority,
          hookAfterRqCurrCommit, linuxHookApproved, behaviorChangeClaim,
          monitorVerifiedClaim, protectionClaim>>

CPUS == {"cpu0", "cpu1"}
NoCpu == "none"
CpuOrNone == CPUS \cup {NoCpu}
Epochs == 0..2

TaskKinds == {"OrdinaryDomain", "ServiceKthread", "PerCpuKthread"}
TupleKinds == {"None", "Run", "Move"}

RunEdges == {"ContextSwitch", "DlServerPick"}
MoveEdges == {
    "MoveQueuedTask",
    "FairDetachAttach",
    "ActiveBalance",
    "RtPushPull",
    "DlPushPull",
    "ScxDispatch",
    "CoreSteal",
    "HotplugPush",
    "AffinityMigration",
    "ProxyMigrate"
}
EdgeKinds == RunEdges \cup MoveEdges \cup {"None"}

Phases == {
    "Start",
    "AuthorityIssued",
    "MoveValidated",
    "Moved",
    "RunValidated",
    "Running",
    "Invalidated",
    "FailClosed",
    "BadRunWithoutValidation",
    "BadMoveWithoutValidation",
    "BadRunWithStaleValidation",
    "BadMoveWithStaleValidation",
    "BadRunUsingMoveValidation",
    "BadMoveUsingRunValidation",
    "BadRunDestMismatch",
    "BadMoveDestMismatch",
    "BadRunOutsideFreshSet",
    "BadMoveOutsideFreshSet",
    "BadRunWithPendingMigration",
    "BadMoveWithPendingMigration",
    "BadNoIntersectionRun",
    "BadEdgeMismatch",
    "BadTaskGenStale",
    "BadDomainEpochStale",
    "BadSchedCtxEpochStale",
    "BadRunCapEpochStale",
    "BadMoveSeqStale",
    "BadCoreSeqStale",
    "BadScxSeqStale",
    "BadHookAfterRqCurrCommit",
    "BadPickNextAuthority",
    "BadSetTaskCpuAuthority",
    "BadMoveQueuedAuthority",
    "BadAttachTaskAuthority",
    "BadFairBalanceAuthority",
    "BadRtPushPullAuthority",
    "BadDlPushPullAuthority",
    "BadScxDispatchAuthority",
    "BadCoreSchedulingAuthority",
    "BadProxyMigrateAuthority",
    "BadHotplugPushAuthority",
    "BadMigrationStopAuthority",
    "BadLinuxExceptionAuthority",
    "BadLinuxHookApproved",
    "BadBehaviorChangeClaim",
    "BadMonitorVerifiedClaim",
    "BadProtectionClaim"
}

TypeOK ==
    /\ phase \in Phases
    /\ taskKind \in TaskKinds
    /\ domainGrant \in BOOLEAN
    /\ schedContextGrant \in BOOLEAN
    /\ runCapGrant \in BOOLEAN
    /\ runAuthority \in BOOLEAN
    /\ taskGen \in Epochs
    /\ domainEpoch \in Epochs
    /\ schedCtxEpoch \in Epochs
    /\ runCapEpoch \in Epochs
    /\ moveSeq \in Epochs
    /\ coreSeq \in Epochs
    /\ scxSeq \in Epochs
    /\ capEnvelope \subseteq CPUS
    /\ linuxMask \subseteq CPUS
    /\ activeMask \subseteq CPUS
    /\ monitorCpuSet \subseteq CPUS
    /\ memoryViewCpuSet \subseteq CPUS
    /\ currentCpu \in CpuOrNone
    /\ selectedCpu \in CpuOrNone
    /\ runCpu \in CpuOrNone
    /\ destCpu \in CpuOrNone
    /\ edgeKind \in EdgeKinds
    /\ tupleKind \in TupleKinds
    /\ tupleEdge \in EdgeKinds
    /\ tupleDest \in CpuOrNone
    /\ tupleTaskGen \in Epochs
    /\ tupleDomainEpoch \in Epochs
    /\ tupleSchedCtxEpoch \in Epochs
    /\ tupleRunCapEpoch \in Epochs
    /\ tupleMoveSeq \in Epochs
    /\ tupleCoreSeq \in Epochs
    /\ tupleScxSeq \in Epochs
    /\ tupleIssued \in BOOLEAN
    /\ tupleConsumed \in BOOLEAN
    /\ migrationPending \in BOOLEAN
    /\ rqCurrCommitted \in BOOLEAN
    /\ contextSwitched \in BOOLEAN
    /\ running \in BOOLEAN
    /\ moveCommitted \in BOOLEAN
    /\ failClosed \in BOOLEAN
    /\ pickNextAuthority \in BOOLEAN
    /\ setTaskCpuAuthority \in BOOLEAN
    /\ moveQueuedAuthority \in BOOLEAN
    /\ attachTaskAuthority \in BOOLEAN
    /\ fairBalanceAuthority \in BOOLEAN
    /\ rtPushPullAuthority \in BOOLEAN
    /\ dlPushPullAuthority \in BOOLEAN
    /\ scxDispatchAuthority \in BOOLEAN
    /\ coreSchedulingAuthority \in BOOLEAN
    /\ proxyMigrateAuthority \in BOOLEAN
    /\ hotplugPushAuthority \in BOOLEAN
    /\ migrationStopAuthority \in BOOLEAN
    /\ linuxExceptionAuthority \in BOOLEAN
    /\ hookAfterRqCurrCommit \in BOOLEAN
    /\ linuxHookApproved \in BOOLEAN
    /\ behaviorChangeClaim \in BOOLEAN
    /\ monitorVerifiedClaim \in BOOLEAN
    /\ protectionClaim \in BOOLEAN

GrantAuthority ==
    /\ domainGrant
    /\ schedContextGrant
    /\ runCapGrant
    /\ runAuthority

FreshAllowed ==
    capEnvelope \cap linuxMask \cap activeMask \cap monitorCpuSet \cap
    memoryViewCpuSet

TupleMatches(kind, edge, cpu) ==
    /\ tupleIssued
    /\ ~tupleConsumed
    /\ tupleKind = kind
    /\ tupleEdge = edge
    /\ tupleDest = cpu
    /\ tupleTaskGen = taskGen
    /\ tupleDomainEpoch = domainEpoch
    /\ tupleSchedCtxEpoch = schedCtxEpoch
    /\ tupleRunCapEpoch = runCapEpoch
    /\ tupleMoveSeq = moveSeq
    /\ tupleCoreSeq = coreSeq
    /\ tupleScxSeq = scxSeq
    /\ cpu \in FreshAllowed
    /\ ~migrationPending

NoLinuxAuthorityFlags ==
    /\ ~pickNextAuthority
    /\ ~setTaskCpuAuthority
    /\ ~moveQueuedAuthority
    /\ ~attachTaskAuthority
    /\ ~fairBalanceAuthority
    /\ ~rtPushPullAuthority
    /\ ~dlPushPullAuthority
    /\ ~scxDispatchAuthority
    /\ ~coreSchedulingAuthority
    /\ ~proxyMigrateAuthority
    /\ ~hotplugPushAuthority
    /\ ~migrationStopAuthority
    /\ ~linuxExceptionAuthority
    /\ ~hookAfterRqCurrCommit
    /\ ~linuxHookApproved
    /\ ~behaviorChangeClaim
    /\ ~monitorVerifiedClaim
    /\ ~protectionClaim

RunReady ==
    /\ taskKind = "OrdinaryDomain"
    /\ GrantAuthority
    /\ edgeKind \in RunEdges
    /\ selectedCpu \in CPUS
    /\ TupleMatches("Run", edgeKind, selectedCpu)
    /\ NoLinuxAuthorityFlags

MoveReady ==
    /\ taskKind = "OrdinaryDomain"
    /\ GrantAuthority
    /\ edgeKind \in MoveEdges
    /\ destCpu \in CPUS
    /\ TupleMatches("Move", edgeKind, destCpu)
    /\ NoLinuxAuthorityFlags

Init ==
    /\ phase = "Start"
    /\ taskKind = "OrdinaryDomain"
    /\ domainGrant = FALSE
    /\ schedContextGrant = FALSE
    /\ runCapGrant = FALSE
    /\ runAuthority = FALSE
    /\ taskGen = 0
    /\ domainEpoch = 0
    /\ schedCtxEpoch = 0
    /\ runCapEpoch = 0
    /\ moveSeq = 0
    /\ coreSeq = 0
    /\ scxSeq = 0
    /\ capEnvelope = CPUS
    /\ linuxMask = CPUS
    /\ activeMask = CPUS
    /\ monitorCpuSet = CPUS
    /\ memoryViewCpuSet = CPUS
    /\ currentCpu = "cpu0"
    /\ selectedCpu = NoCpu
    /\ runCpu = NoCpu
    /\ destCpu = NoCpu
    /\ edgeKind = "None"
    /\ tupleKind = "None"
    /\ tupleEdge = "None"
    /\ tupleDest = NoCpu
    /\ tupleTaskGen = 0
    /\ tupleDomainEpoch = 0
    /\ tupleSchedCtxEpoch = 0
    /\ tupleRunCapEpoch = 0
    /\ tupleMoveSeq = 0
    /\ tupleCoreSeq = 0
    /\ tupleScxSeq = 0
    /\ tupleIssued = FALSE
    /\ tupleConsumed = FALSE
    /\ migrationPending = FALSE
    /\ rqCurrCommitted = FALSE
    /\ contextSwitched = FALSE
    /\ running = FALSE
    /\ moveCommitted = FALSE
    /\ failClosed = FALSE
    /\ pickNextAuthority = FALSE
    /\ setTaskCpuAuthority = FALSE
    /\ moveQueuedAuthority = FALSE
    /\ attachTaskAuthority = FALSE
    /\ fairBalanceAuthority = FALSE
    /\ rtPushPullAuthority = FALSE
    /\ dlPushPullAuthority = FALSE
    /\ scxDispatchAuthority = FALSE
    /\ coreSchedulingAuthority = FALSE
    /\ proxyMigrateAuthority = FALSE
    /\ hotplugPushAuthority = FALSE
    /\ migrationStopAuthority = FALSE
    /\ linuxExceptionAuthority = FALSE
    /\ hookAfterRqCurrCommit = FALSE
    /\ linuxHookApproved = FALSE
    /\ behaviorChangeClaim = FALSE
    /\ monitorVerifiedClaim = FALSE
    /\ protectionClaim = FALSE

IssueAuthority ==
    /\ phase = "Start"
    /\ domainGrant' = TRUE
    /\ schedContextGrant' = TRUE
    /\ runCapGrant' = TRUE
    /\ runAuthority' = TRUE
    /\ taskGen' = 1
    /\ domainEpoch' = 1
    /\ schedCtxEpoch' = 1
    /\ runCapEpoch' = 1
    /\ phase' = "AuthorityIssued"
    /\ UNCHANGED <<taskKind, moveSeq, coreSeq, scxSeq, capEnvelope, linuxMask,
                    activeMask, monitorCpuSet, memoryViewCpuSet, currentCpu,
                    selectedCpu, runCpu, destCpu, edgeKind, tupleKind,
                    tupleEdge, tupleDest, tupleTaskGen, tupleDomainEpoch,
                    tupleSchedCtxEpoch, tupleRunCapEpoch, tupleMoveSeq,
                    tupleCoreSeq, tupleScxSeq, tupleIssued, tupleConsumed,
                    migrationPending, rqCurrCommitted, contextSwitched,
                    running, moveCommitted, failClosed, pickNextAuthority,
                    setTaskCpuAuthority, moveQueuedAuthority,
                    attachTaskAuthority, fairBalanceAuthority,
                    rtPushPullAuthority, dlPushPullAuthority,
                    scxDispatchAuthority, coreSchedulingAuthority,
                    proxyMigrateAuthority, hotplugPushAuthority,
                    migrationStopAuthority, linuxExceptionAuthority,
                    hookAfterRqCurrCommit, linuxHookApproved,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

TupleSnapshot(kind, edge, cpu) ==
    /\ tupleKind' = kind
    /\ tupleEdge' = edge
    /\ tupleDest' = cpu
    /\ tupleTaskGen' = taskGen
    /\ tupleDomainEpoch' = domainEpoch
    /\ tupleSchedCtxEpoch' = schedCtxEpoch
    /\ tupleRunCapEpoch' = runCapEpoch
    /\ tupleMoveSeq' = moveSeq
    /\ tupleCoreSeq' = coreSeq
    /\ tupleScxSeq' = scxSeq
    /\ tupleIssued' = TRUE
    /\ tupleConsumed' = FALSE

PrepareMoveTuple ==
    /\ phase = "AuthorityIssued"
    /\ GrantAuthority
    /\ "cpu1" \in FreshAllowed
    /\ edgeKind' = "FairDetachAttach"
    /\ destCpu' = "cpu1"
    /\ selectedCpu' = NoCpu
    /\ TupleSnapshot("Move", "FairDetachAttach", "cpu1")
    /\ migrationPending' = FALSE
    /\ phase' = "MoveValidated"
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, taskGen, domainEpoch, schedCtxEpoch,
                    runCapEpoch, moveSeq, coreSeq, scxSeq, capEnvelope,
                    linuxMask, activeMask, monitorCpuSet, memoryViewCpuSet,
                    currentCpu, runCpu, rqCurrCommitted, contextSwitched,
                    running, moveCommitted, failClosed, pickNextAuthority,
                    setTaskCpuAuthority, moveQueuedAuthority,
                    attachTaskAuthority, fairBalanceAuthority,
                    rtPushPullAuthority, dlPushPullAuthority,
                    scxDispatchAuthority, coreSchedulingAuthority,
                    proxyMigrateAuthority, hotplugPushAuthority,
                    migrationStopAuthority, linuxExceptionAuthority,
                    hookAfterRqCurrCommit, linuxHookApproved,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

CommitMove ==
    /\ phase = "MoveValidated"
    /\ MoveReady
    /\ currentCpu' = destCpu
    /\ moveCommitted' = TRUE
    /\ tupleConsumed' = TRUE
    /\ phase' = "Moved"
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, taskGen, domainEpoch, schedCtxEpoch,
                    runCapEpoch, moveSeq, coreSeq, scxSeq, capEnvelope,
                    linuxMask, activeMask, monitorCpuSet, memoryViewCpuSet,
                    selectedCpu, runCpu, destCpu, edgeKind, tupleKind,
                    tupleEdge, tupleDest, tupleTaskGen, tupleDomainEpoch,
                    tupleSchedCtxEpoch, tupleRunCapEpoch, tupleMoveSeq,
                    tupleCoreSeq, tupleScxSeq, tupleIssued,
                    migrationPending, rqCurrCommitted, contextSwitched,
                    running, failClosed, pickNextAuthority,
                    setTaskCpuAuthority, moveQueuedAuthority,
                    attachTaskAuthority, fairBalanceAuthority,
                    rtPushPullAuthority, dlPushPullAuthority,
                    scxDispatchAuthority, coreSchedulingAuthority,
                    proxyMigrateAuthority, hotplugPushAuthority,
                    migrationStopAuthority, linuxExceptionAuthority,
                    hookAfterRqCurrCommit, linuxHookApproved,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

PrepareRunTuple ==
    /\ phase \in {"AuthorityIssued", "Moved"}
    /\ GrantAuthority
    /\ currentCpu \in FreshAllowed
    /\ selectedCpu' = currentCpu
    /\ runCpu' = NoCpu
    /\ destCpu' = NoCpu
    /\ edgeKind' = "ContextSwitch"
    /\ TupleSnapshot("Run", "ContextSwitch", currentCpu)
    /\ moveCommitted' = FALSE
    /\ migrationPending' = FALSE
    /\ phase' = "RunValidated"
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, taskGen, domainEpoch, schedCtxEpoch,
                    runCapEpoch, moveSeq, coreSeq, scxSeq, capEnvelope,
                    linuxMask, activeMask, monitorCpuSet, memoryViewCpuSet,
                    currentCpu, rqCurrCommitted, contextSwitched, running,
                    failClosed, pickNextAuthority, setTaskCpuAuthority,
                    moveQueuedAuthority, attachTaskAuthority,
                    fairBalanceAuthority, rtPushPullAuthority,
                    dlPushPullAuthority, scxDispatchAuthority,
                    coreSchedulingAuthority, proxyMigrateAuthority,
                    hotplugPushAuthority, migrationStopAuthority,
                    linuxExceptionAuthority, hookAfterRqCurrCommit,
                    linuxHookApproved, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

CommitRun ==
    /\ phase = "RunValidated"
    /\ RunReady
    /\ runCpu' = selectedCpu
    /\ rqCurrCommitted' = TRUE
    /\ contextSwitched' = TRUE
    /\ running' = TRUE
    /\ tupleConsumed' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, taskGen, domainEpoch, schedCtxEpoch,
                    runCapEpoch, moveSeq, coreSeq, scxSeq, capEnvelope,
                    linuxMask, activeMask, monitorCpuSet, memoryViewCpuSet,
                    currentCpu, selectedCpu, destCpu, edgeKind, tupleKind,
                    tupleEdge, tupleDest, tupleTaskGen, tupleDomainEpoch,
                    tupleSchedCtxEpoch, tupleRunCapEpoch, tupleMoveSeq,
                    tupleCoreSeq, tupleScxSeq, tupleIssued,
                    migrationPending, moveCommitted, failClosed,
                    pickNextAuthority, setTaskCpuAuthority,
                    moveQueuedAuthority, attachTaskAuthority,
                    fairBalanceAuthority, rtPushPullAuthority,
                    dlPushPullAuthority, scxDispatchAuthority,
                    coreSchedulingAuthority, proxyMigrateAuthority,
                    hotplugPushAuthority, migrationStopAuthority,
                    linuxExceptionAuthority, hookAfterRqCurrCommit,
                    linuxHookApproved, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

InvalidateAfterTuple ==
    /\ phase \in {"MoveValidated", "RunValidated"}
    /\ domainEpoch < 2
    /\ domainEpoch' = domainEpoch + 1
    /\ migrationPending' = TRUE
    /\ running' = FALSE
    /\ moveCommitted' = FALSE
    /\ phase' = "Invalidated"
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, taskGen, schedCtxEpoch, runCapEpoch,
                    moveSeq, coreSeq, scxSeq, capEnvelope, linuxMask,
                    activeMask, monitorCpuSet, memoryViewCpuSet, currentCpu,
                    selectedCpu, runCpu, destCpu, edgeKind, tupleKind,
                    tupleEdge, tupleDest, tupleTaskGen, tupleDomainEpoch,
                    tupleSchedCtxEpoch, tupleRunCapEpoch, tupleMoveSeq,
                    tupleCoreSeq, tupleScxSeq, tupleIssued, tupleConsumed,
                    rqCurrCommitted, contextSwitched, failClosed,
                    pickNextAuthority, setTaskCpuAuthority,
                    moveQueuedAuthority, attachTaskAuthority,
                    fairBalanceAuthority, rtPushPullAuthority,
                    dlPushPullAuthority, scxDispatchAuthority,
                    coreSchedulingAuthority, proxyMigrateAuthority,
                    hotplugPushAuthority, migrationStopAuthority,
                    linuxExceptionAuthority, hookAfterRqCurrCommit,
                    linuxHookApproved, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

InvalidateMoveSeqAfterTuple ==
    /\ phase \in {"MoveValidated", "RunValidated"}
    /\ moveSeq < 2
    /\ moveSeq' = moveSeq + 1
    /\ migrationPending' = TRUE
    /\ running' = FALSE
    /\ moveCommitted' = FALSE
    /\ phase' = "Invalidated"
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, taskGen, domainEpoch, schedCtxEpoch,
                    runCapEpoch, coreSeq, scxSeq, capEnvelope, linuxMask,
                    activeMask, monitorCpuSet, memoryViewCpuSet, currentCpu,
                    selectedCpu, runCpu, destCpu, edgeKind, tupleKind,
                    tupleEdge, tupleDest, tupleTaskGen, tupleDomainEpoch,
                    tupleSchedCtxEpoch, tupleRunCapEpoch, tupleMoveSeq,
                    tupleCoreSeq, tupleScxSeq, tupleIssued, tupleConsumed,
                    rqCurrCommitted, contextSwitched, failClosed,
                    pickNextAuthority, setTaskCpuAuthority,
                    moveQueuedAuthority, attachTaskAuthority,
                    fairBalanceAuthority, rtPushPullAuthority,
                    dlPushPullAuthority, scxDispatchAuthority,
                    coreSchedulingAuthority, proxyMigrateAuthority,
                    hotplugPushAuthority, migrationStopAuthority,
                    linuxExceptionAuthority, hookAfterRqCurrCommit,
                    linuxHookApproved, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

InvalidateCoreScxAfterTuple ==
    /\ phase \in {"MoveValidated", "RunValidated"}
    /\ coreSeq < 2
    /\ scxSeq < 2
    /\ coreSeq' = coreSeq + 1
    /\ scxSeq' = scxSeq + 1
    /\ migrationPending' = TRUE
    /\ running' = FALSE
    /\ moveCommitted' = FALSE
    /\ phase' = "Invalidated"
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, taskGen, domainEpoch, schedCtxEpoch,
                    runCapEpoch, moveSeq, capEnvelope, linuxMask, activeMask,
                    monitorCpuSet, memoryViewCpuSet, currentCpu, selectedCpu,
                    runCpu, destCpu, edgeKind, tupleKind, tupleEdge,
                    tupleDest, tupleTaskGen, tupleDomainEpoch,
                    tupleSchedCtxEpoch, tupleRunCapEpoch, tupleMoveSeq,
                    tupleCoreSeq, tupleScxSeq, tupleIssued, tupleConsumed,
                    rqCurrCommitted, contextSwitched, failClosed,
                    pickNextAuthority, setTaskCpuAuthority,
                    moveQueuedAuthority, attachTaskAuthority,
                    fairBalanceAuthority, rtPushPullAuthority,
                    dlPushPullAuthority, scxDispatchAuthority,
                    coreSchedulingAuthority, proxyMigrateAuthority,
                    hotplugPushAuthority, migrationStopAuthority,
                    linuxExceptionAuthority, hookAfterRqCurrCommit,
                    linuxHookApproved, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

InvalidateToNoIntersection ==
    /\ phase \in {"MoveValidated", "RunValidated"}
    /\ domainEpoch < 2
    /\ domainEpoch' = domainEpoch + 1
    /\ linuxMask' = {}
    /\ migrationPending' = TRUE
    /\ running' = FALSE
    /\ moveCommitted' = FALSE
    /\ phase' = "Invalidated"
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, taskGen, schedCtxEpoch, runCapEpoch,
                    moveSeq, coreSeq, scxSeq, capEnvelope, activeMask,
                    monitorCpuSet, memoryViewCpuSet, currentCpu, selectedCpu,
                    runCpu, destCpu, edgeKind, tupleKind, tupleEdge,
                    tupleDest, tupleTaskGen, tupleDomainEpoch,
                    tupleSchedCtxEpoch, tupleRunCapEpoch, tupleMoveSeq,
                    tupleCoreSeq, tupleScxSeq, tupleIssued, tupleConsumed,
                    rqCurrCommitted, contextSwitched, failClosed,
                    pickNextAuthority, setTaskCpuAuthority,
                    moveQueuedAuthority, attachTaskAuthority,
                    fairBalanceAuthority, rtPushPullAuthority,
                    dlPushPullAuthority, scxDispatchAuthority,
                    coreSchedulingAuthority, proxyMigrateAuthority,
                    hotplugPushAuthority, migrationStopAuthority,
                    linuxExceptionAuthority, hookAfterRqCurrCommit,
                    linuxHookApproved, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

RevalidateAfterInvalidation ==
    /\ phase = "Invalidated"
    /\ FreshAllowed # {}
    /\ tupleKind' = "None"
    /\ tupleEdge' = "None"
    /\ tupleDest' = NoCpu
    /\ tupleIssued' = FALSE
    /\ tupleConsumed' = FALSE
    /\ migrationPending' = FALSE
    /\ phase' = "AuthorityIssued"
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, taskGen, domainEpoch, schedCtxEpoch,
                    runCapEpoch, moveSeq, coreSeq, scxSeq, capEnvelope,
                    linuxMask, activeMask, monitorCpuSet, memoryViewCpuSet,
                    currentCpu, selectedCpu, runCpu, destCpu, edgeKind,
                    tupleTaskGen, tupleDomainEpoch, tupleSchedCtxEpoch,
                    tupleRunCapEpoch, tupleMoveSeq, tupleCoreSeq,
                    tupleScxSeq, rqCurrCommitted, contextSwitched, running,
                    moveCommitted, failClosed, pickNextAuthority,
                    setTaskCpuAuthority, moveQueuedAuthority,
                    attachTaskAuthority, fairBalanceAuthority,
                    rtPushPullAuthority, dlPushPullAuthority,
                    scxDispatchAuthority, coreSchedulingAuthority,
                    proxyMigrateAuthority, hotplugPushAuthority,
                    migrationStopAuthority, linuxExceptionAuthority,
                    hookAfterRqCurrCommit, linuxHookApproved,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

NoIntersectionFailClosed ==
    /\ phase = "Invalidated"
    /\ FreshAllowed = {}
    /\ failClosed' = TRUE
    /\ migrationPending' = FALSE
    /\ running' = FALSE
    /\ moveCommitted' = FALSE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, taskGen, domainEpoch, schedCtxEpoch,
                    runCapEpoch, moveSeq, coreSeq, scxSeq, capEnvelope,
                    linuxMask, activeMask, monitorCpuSet, memoryViewCpuSet,
                    currentCpu, selectedCpu, runCpu, destCpu, edgeKind,
                    tupleKind, tupleEdge, tupleDest, tupleTaskGen,
                    tupleDomainEpoch, tupleSchedCtxEpoch, tupleRunCapEpoch,
                    tupleMoveSeq, tupleCoreSeq, tupleScxSeq, tupleIssued,
                    tupleConsumed, rqCurrCommitted, contextSwitched,
                    pickNextAuthority, setTaskCpuAuthority,
                    moveQueuedAuthority, attachTaskAuthority,
                    fairBalanceAuthority, rtPushPullAuthority,
                    dlPushPullAuthority, scxDispatchAuthority,
                    coreSchedulingAuthority, proxyMigrateAuthority,
                    hotplugPushAuthority, migrationStopAuthority,
                    linuxExceptionAuthority, hookAfterRqCurrCommit,
                    linuxHookApproved, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

TerminalStutter ==
    /\ phase \in {"Running", "FailClosed"}
    /\ UNCHANGED vars

SafeNext ==
    \/ IssueAuthority
    \/ PrepareMoveTuple
    \/ CommitMove
    \/ PrepareRunTuple
    \/ CommitRun
    \/ InvalidateAfterTuple
    \/ InvalidateMoveSeqAfterTuple
    \/ InvalidateCoreScxAfterTuple
    \/ InvalidateToNoIntersection
    \/ RevalidateAfterInvalidation
    \/ NoIntersectionFailClosed
    \/ TerminalStutter

BadCommon(cpuMask, active, mon, mem) ==
    /\ phase = "Start"
    /\ taskKind' = "OrdinaryDomain"
    /\ domainGrant' = TRUE
    /\ schedContextGrant' = TRUE
    /\ runCapGrant' = TRUE
    /\ runAuthority' = TRUE
    /\ taskGen' = 1
    /\ domainEpoch' = 1
    /\ schedCtxEpoch' = 1
    /\ runCapEpoch' = 1
    /\ moveSeq' = 1
    /\ coreSeq' = 1
    /\ scxSeq' = 1
    /\ capEnvelope' = CPUS
    /\ linuxMask' = cpuMask
    /\ activeMask' = active
    /\ monitorCpuSet' = mon
    /\ memoryViewCpuSet' = mem
    /\ failClosed' = FALSE

BadFlags(sel, stc, mvq, att, fair, rt, dl, scx, core, proxy, hotplug,
         migration, exc, afterCurr, hook, behavior, monver, protect) ==
    /\ pickNextAuthority' = sel
    /\ setTaskCpuAuthority' = stc
    /\ moveQueuedAuthority' = mvq
    /\ attachTaskAuthority' = att
    /\ fairBalanceAuthority' = fair
    /\ rtPushPullAuthority' = rt
    /\ dlPushPullAuthority' = dl
    /\ scxDispatchAuthority' = scx
    /\ coreSchedulingAuthority' = core
    /\ proxyMigrateAuthority' = proxy
    /\ hotplugPushAuthority' = hotplug
    /\ migrationStopAuthority' = migration
    /\ linuxExceptionAuthority' = exc
    /\ hookAfterRqCurrCommit' = afterCurr
    /\ linuxHookApproved' = hook
    /\ behaviorChangeClaim' = behavior
    /\ monitorVerifiedClaim' = monver
    /\ protectionClaim' = protect

NoBadFlags ==
    BadFlags(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)

BadRunWithSets(cpuMask, active, mon, mem,
       tupleIssuedP, tupleConsumedP, tupleKindP, tupleEdgeP, tupleDestP,
       tupleTaskGenP, tupleDomainEpochP, tupleSchedCtxEpochP,
       tupleRunCapEpochP, tupleMoveSeqP, tupleCoreSeqP, tupleScxSeqP,
       pendingP, badPhase) ==
    /\ BadCommon(cpuMask, active, mon, mem)
    /\ currentCpu' = "cpu0"
    /\ selectedCpu' = "cpu0"
    /\ runCpu' = "cpu0"
    /\ destCpu' = NoCpu
    /\ edgeKind' = "ContextSwitch"
    /\ tupleKind' = tupleKindP
    /\ tupleEdge' = tupleEdgeP
    /\ tupleDest' = tupleDestP
    /\ tupleTaskGen' = tupleTaskGenP
    /\ tupleDomainEpoch' = tupleDomainEpochP
    /\ tupleSchedCtxEpoch' = tupleSchedCtxEpochP
    /\ tupleRunCapEpoch' = tupleRunCapEpochP
    /\ tupleMoveSeq' = tupleMoveSeqP
    /\ tupleCoreSeq' = tupleCoreSeqP
    /\ tupleScxSeq' = tupleScxSeqP
    /\ tupleIssued' = tupleIssuedP
    /\ tupleConsumed' = tupleConsumedP
    /\ migrationPending' = pendingP
    /\ rqCurrCommitted' = TRUE
    /\ contextSwitched' = TRUE
    /\ running' = TRUE
    /\ moveCommitted' = FALSE
    /\ NoBadFlags
    /\ phase' = badPhase

BadRun(tupleIssuedP, tupleConsumedP, tupleKindP, tupleEdgeP, tupleDestP,
       tupleTaskGenP, tupleDomainEpochP, tupleSchedCtxEpochP,
       tupleRunCapEpochP, tupleMoveSeqP, tupleCoreSeqP, tupleScxSeqP,
       pendingP, badPhase) ==
    BadRunWithSets(CPUS, CPUS, CPUS, CPUS,
       tupleIssuedP, tupleConsumedP, tupleKindP, tupleEdgeP, tupleDestP,
       tupleTaskGenP, tupleDomainEpochP, tupleSchedCtxEpochP,
       tupleRunCapEpochP, tupleMoveSeqP, tupleCoreSeqP, tupleScxSeqP,
       pendingP, badPhase)

BadMoveWithSets(cpuMask, active, mon, mem,
        tupleIssuedP, tupleConsumedP, tupleKindP, tupleEdgeP, tupleDestP,
        tupleTaskGenP, tupleDomainEpochP, tupleSchedCtxEpochP,
        tupleRunCapEpochP, tupleMoveSeqP, tupleCoreSeqP, tupleScxSeqP,
        pendingP, badPhase) ==
    /\ BadCommon(cpuMask, active, mon, mem)
    /\ currentCpu' = "cpu1"
    /\ selectedCpu' = NoCpu
    /\ runCpu' = NoCpu
    /\ destCpu' = "cpu1"
    /\ edgeKind' = "FairDetachAttach"
    /\ tupleKind' = tupleKindP
    /\ tupleEdge' = tupleEdgeP
    /\ tupleDest' = tupleDestP
    /\ tupleTaskGen' = tupleTaskGenP
    /\ tupleDomainEpoch' = tupleDomainEpochP
    /\ tupleSchedCtxEpoch' = tupleSchedCtxEpochP
    /\ tupleRunCapEpoch' = tupleRunCapEpochP
    /\ tupleMoveSeq' = tupleMoveSeqP
    /\ tupleCoreSeq' = tupleCoreSeqP
    /\ tupleScxSeq' = tupleScxSeqP
    /\ tupleIssued' = tupleIssuedP
    /\ tupleConsumed' = tupleConsumedP
    /\ migrationPending' = pendingP
    /\ rqCurrCommitted' = FALSE
    /\ contextSwitched' = FALSE
    /\ running' = FALSE
    /\ moveCommitted' = TRUE
    /\ NoBadFlags
    /\ phase' = badPhase

BadMove(tupleIssuedP, tupleConsumedP, tupleKindP, tupleEdgeP, tupleDestP,
        tupleTaskGenP, tupleDomainEpochP, tupleSchedCtxEpochP,
        tupleRunCapEpochP, tupleMoveSeqP, tupleCoreSeqP, tupleScxSeqP,
        pendingP, badPhase) ==
    BadMoveWithSets(CPUS, CPUS, CPUS, CPUS,
        tupleIssuedP, tupleConsumedP, tupleKindP, tupleEdgeP, tupleDestP,
        tupleTaskGenP, tupleDomainEpochP, tupleSchedCtxEpochP,
        tupleRunCapEpochP, tupleMoveSeqP, tupleCoreSeqP, tupleScxSeqP,
        pendingP, badPhase)

UnsafeRunWithoutValidation ==
    BadRun(FALSE, FALSE, "Run", "ContextSwitch", "cpu0", 1, 1, 1, 1, 1, 1, 1,
           FALSE, "BadRunWithoutValidation")

UnsafeMoveWithoutValidation ==
    BadMove(FALSE, FALSE, "Move", "FairDetachAttach", "cpu1", 1, 1, 1, 1, 1, 1, 1,
            FALSE, "BadMoveWithoutValidation")

UnsafeRunWithStaleValidation ==
    BadRun(TRUE, TRUE, "Run", "ContextSwitch", "cpu0", 1, 0, 1, 1, 1, 1, 1,
           FALSE, "BadRunWithStaleValidation")

UnsafeMoveWithStaleValidation ==
    BadMove(TRUE, TRUE, "Move", "FairDetachAttach", "cpu1", 1, 0, 1, 1, 1, 1, 1,
            FALSE, "BadMoveWithStaleValidation")

UnsafeRunUsingMoveValidation ==
    BadRun(TRUE, TRUE, "Move", "ContextSwitch", "cpu0", 1, 1, 1, 1, 1, 1, 1,
           FALSE, "BadRunUsingMoveValidation")

UnsafeMoveUsingRunValidation ==
    BadMove(TRUE, TRUE, "Run", "FairDetachAttach", "cpu1", 1, 1, 1, 1, 1, 1, 1,
            FALSE, "BadMoveUsingRunValidation")

UnsafeRunDestMismatch ==
    BadRun(TRUE, TRUE, "Run", "ContextSwitch", "cpu1", 1, 1, 1, 1, 1, 1, 1,
           FALSE, "BadRunDestMismatch")

UnsafeMoveDestMismatch ==
    BadMove(TRUE, TRUE, "Move", "FairDetachAttach", "cpu0", 1, 1, 1, 1, 1, 1, 1,
            FALSE, "BadMoveDestMismatch")

UnsafeRunOutsideFreshSet ==
    BadRunWithSets({"cpu1"}, CPUS, CPUS, CPUS,
        TRUE, TRUE, "Run", "ContextSwitch", "cpu0", 1, 1, 1, 1, 1, 1, 1,
        FALSE, "BadRunOutsideFreshSet")

UnsafeMoveOutsideFreshSet ==
    BadMoveWithSets({"cpu0"}, CPUS, CPUS, CPUS,
        TRUE, TRUE, "Move", "FairDetachAttach", "cpu1", 1, 1, 1, 1, 1, 1, 1,
        FALSE, "BadMoveOutsideFreshSet")

UnsafeRunWithPendingMigration ==
    BadRun(TRUE, TRUE, "Run", "ContextSwitch", "cpu0", 1, 1, 1, 1, 1, 1, 1,
           TRUE, "BadRunWithPendingMigration")

UnsafeMoveWithPendingMigration ==
    BadMove(TRUE, TRUE, "Move", "FairDetachAttach", "cpu1", 1, 1, 1, 1, 1, 1, 1,
            TRUE, "BadMoveWithPendingMigration")

UnsafeNoIntersectionRun ==
    BadRunWithSets({}, CPUS, CPUS, CPUS,
        TRUE, TRUE, "Run", "ContextSwitch", "cpu0", 1, 1, 1, 1, 1, 1, 1,
        FALSE, "BadNoIntersectionRun")

UnsafeEdgeMismatch ==
    BadRun(TRUE, TRUE, "Run", "DlServerPick", "cpu0", 1, 1, 1, 1, 1, 1, 1,
           FALSE, "BadEdgeMismatch")

UnsafeTaskGenStale ==
    BadRun(TRUE, TRUE, "Run", "ContextSwitch", "cpu0", 0, 1, 1, 1, 1, 1, 1,
           FALSE, "BadTaskGenStale")

UnsafeDomainEpochStale ==
    BadRun(TRUE, TRUE, "Run", "ContextSwitch", "cpu0", 1, 0, 1, 1, 1, 1, 1,
           FALSE, "BadDomainEpochStale")

UnsafeSchedCtxEpochStale ==
    BadRun(TRUE, TRUE, "Run", "ContextSwitch", "cpu0", 1, 1, 0, 1, 1, 1, 1,
           FALSE, "BadSchedCtxEpochStale")

UnsafeRunCapEpochStale ==
    BadRun(TRUE, TRUE, "Run", "ContextSwitch", "cpu0", 1, 1, 1, 0, 1, 1, 1,
           FALSE, "BadRunCapEpochStale")

UnsafeMoveSeqStale ==
    BadMove(TRUE, TRUE, "Move", "FairDetachAttach", "cpu1", 1, 1, 1, 1, 0, 1, 1,
            FALSE, "BadMoveSeqStale")

UnsafeCoreSeqStale ==
    BadRun(TRUE, TRUE, "Run", "ContextSwitch", "cpu0", 1, 1, 1, 1, 1, 0, 1,
           FALSE, "BadCoreSeqStale")

UnsafeScxSeqStale ==
    BadRun(TRUE, TRUE, "Run", "ContextSwitch", "cpu0", 1, 1, 1, 1, 1, 1, 0,
           FALSE, "BadScxSeqStale")

UnsafeHookAfterRqCurrCommit ==
    /\ BadCommon(CPUS, CPUS, CPUS, CPUS)
    /\ currentCpu' = "cpu0"
    /\ selectedCpu' = "cpu0"
    /\ runCpu' = "cpu0"
    /\ destCpu' = NoCpu
    /\ edgeKind' = "ContextSwitch"
    /\ tupleKind' = "Run"
    /\ tupleEdge' = "ContextSwitch"
    /\ tupleDest' = "cpu0"
    /\ tupleTaskGen' = 1
    /\ tupleDomainEpoch' = 1
    /\ tupleSchedCtxEpoch' = 1
    /\ tupleRunCapEpoch' = 1
    /\ tupleMoveSeq' = 1
    /\ tupleCoreSeq' = 1
    /\ tupleScxSeq' = 1
    /\ tupleIssued' = TRUE
    /\ tupleConsumed' = TRUE
    /\ migrationPending' = FALSE
    /\ rqCurrCommitted' = TRUE
    /\ contextSwitched' = TRUE
    /\ running' = TRUE
    /\ moveCommitted' = FALSE
    /\ BadFlags(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE,
                FALSE, FALSE)
    /\ phase' = "BadHookAfterRqCurrCommit"

UnsafeFlagRun(sel, stc, mvq, att, fair, rt, dl, scx, core, proxy, hotplug,
              migration, exc, afterCurr, hook, behavior, monver, protect,
              badPhase) ==
    /\ BadCommon(CPUS, CPUS, CPUS, CPUS)
    /\ currentCpu' = "cpu0"
    /\ selectedCpu' = "cpu0"
    /\ runCpu' = "cpu0"
    /\ destCpu' = NoCpu
    /\ edgeKind' = "ContextSwitch"
    /\ tupleKind' = "Run"
    /\ tupleEdge' = "ContextSwitch"
    /\ tupleDest' = "cpu0"
    /\ tupleTaskGen' = 1
    /\ tupleDomainEpoch' = 1
    /\ tupleSchedCtxEpoch' = 1
    /\ tupleRunCapEpoch' = 1
    /\ tupleMoveSeq' = 1
    /\ tupleCoreSeq' = 1
    /\ tupleScxSeq' = 1
    /\ tupleIssued' = TRUE
    /\ tupleConsumed' = TRUE
    /\ migrationPending' = FALSE
    /\ rqCurrCommitted' = TRUE
    /\ contextSwitched' = TRUE
    /\ running' = TRUE
    /\ moveCommitted' = FALSE
    /\ BadFlags(sel, stc, mvq, att, fair, rt, dl, scx, core, proxy, hotplug,
                migration, exc, afterCurr, hook, behavior, monver, protect)
    /\ phase' = badPhase

UnsafePickNextAuthority ==
    UnsafeFlagRun(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, "BadPickNextAuthority")

UnsafeSetTaskCpuAuthority ==
    UnsafeFlagRun(FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, "BadSetTaskCpuAuthority")

UnsafeMoveQueuedAuthority ==
    UnsafeFlagRun(FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, "BadMoveQueuedAuthority")

UnsafeAttachTaskAuthority ==
    UnsafeFlagRun(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, "BadAttachTaskAuthority")

UnsafeFairBalanceAuthority ==
    UnsafeFlagRun(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, "BadFairBalanceAuthority")

UnsafeRtPushPullAuthority ==
    UnsafeFlagRun(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE,
                  FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, "BadRtPushPullAuthority")

UnsafeDlPushPullAuthority ==
    UnsafeFlagRun(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE,
                  FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, "BadDlPushPullAuthority")

UnsafeScxDispatchAuthority ==
    UnsafeFlagRun(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE,
                  FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, "BadScxDispatchAuthority")

UnsafeCoreSchedulingAuthority ==
    UnsafeFlagRun(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, "BadCoreSchedulingAuthority")

UnsafeProxyMigrateAuthority ==
    UnsafeFlagRun(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, "BadProxyMigrateAuthority")

UnsafeHotplugPushAuthority ==
    UnsafeFlagRun(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, "BadHotplugPushAuthority")

UnsafeMigrationStopAuthority ==
    UnsafeFlagRun(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, "BadMigrationStopAuthority")

UnsafeLinuxExceptionAuthority ==
    UnsafeFlagRun(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, "BadLinuxExceptionAuthority")

UnsafeLinuxHookApproved ==
    UnsafeFlagRun(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE,
                  FALSE, FALSE, "BadLinuxHookApproved")

UnsafeBehaviorChangeClaim ==
    UnsafeFlagRun(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE,
                  FALSE, FALSE, "BadBehaviorChangeClaim")

UnsafeMonitorVerifiedClaim ==
    UnsafeFlagRun(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  TRUE, FALSE, "BadMonitorVerifiedClaim")

UnsafeProtectionClaim ==
    UnsafeFlagRun(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                  FALSE, TRUE, "BadProtectionClaim")

SpecUnsafeRunWithoutValidation == Init /\ [][UnsafeRunWithoutValidation]_vars
SpecUnsafeMoveWithoutValidation == Init /\ [][UnsafeMoveWithoutValidation]_vars
SpecUnsafeRunWithStaleValidation == Init /\ [][UnsafeRunWithStaleValidation]_vars
SpecUnsafeMoveWithStaleValidation == Init /\ [][UnsafeMoveWithStaleValidation]_vars
SpecUnsafeRunUsingMoveValidation == Init /\ [][UnsafeRunUsingMoveValidation]_vars
SpecUnsafeMoveUsingRunValidation == Init /\ [][UnsafeMoveUsingRunValidation]_vars
SpecUnsafeRunDestMismatch == Init /\ [][UnsafeRunDestMismatch]_vars
SpecUnsafeMoveDestMismatch == Init /\ [][UnsafeMoveDestMismatch]_vars
SpecUnsafeRunOutsideFreshSet == Init /\ [][UnsafeRunOutsideFreshSet]_vars
SpecUnsafeMoveOutsideFreshSet == Init /\ [][UnsafeMoveOutsideFreshSet]_vars
SpecUnsafeRunWithPendingMigration == Init /\ [][UnsafeRunWithPendingMigration]_vars
SpecUnsafeMoveWithPendingMigration == Init /\ [][UnsafeMoveWithPendingMigration]_vars
SpecUnsafeNoIntersectionRun == Init /\ [][UnsafeNoIntersectionRun]_vars
SpecUnsafeEdgeMismatch == Init /\ [][UnsafeEdgeMismatch]_vars
SpecUnsafeTaskGenStale == Init /\ [][UnsafeTaskGenStale]_vars
SpecUnsafeDomainEpochStale == Init /\ [][UnsafeDomainEpochStale]_vars
SpecUnsafeSchedCtxEpochStale == Init /\ [][UnsafeSchedCtxEpochStale]_vars
SpecUnsafeRunCapEpochStale == Init /\ [][UnsafeRunCapEpochStale]_vars
SpecUnsafeMoveSeqStale == Init /\ [][UnsafeMoveSeqStale]_vars
SpecUnsafeCoreSeqStale == Init /\ [][UnsafeCoreSeqStale]_vars
SpecUnsafeScxSeqStale == Init /\ [][UnsafeScxSeqStale]_vars
SpecUnsafeHookAfterRqCurrCommit == Init /\ [][UnsafeHookAfterRqCurrCommit]_vars
SpecUnsafePickNextAuthority == Init /\ [][UnsafePickNextAuthority]_vars
SpecUnsafeSetTaskCpuAuthority == Init /\ [][UnsafeSetTaskCpuAuthority]_vars
SpecUnsafeMoveQueuedAuthority == Init /\ [][UnsafeMoveQueuedAuthority]_vars
SpecUnsafeAttachTaskAuthority == Init /\ [][UnsafeAttachTaskAuthority]_vars
SpecUnsafeFairBalanceAuthority == Init /\ [][UnsafeFairBalanceAuthority]_vars
SpecUnsafeRtPushPullAuthority == Init /\ [][UnsafeRtPushPullAuthority]_vars
SpecUnsafeDlPushPullAuthority == Init /\ [][UnsafeDlPushPullAuthority]_vars
SpecUnsafeScxDispatchAuthority == Init /\ [][UnsafeScxDispatchAuthority]_vars
SpecUnsafeCoreSchedulingAuthority == Init /\ [][UnsafeCoreSchedulingAuthority]_vars
SpecUnsafeProxyMigrateAuthority == Init /\ [][UnsafeProxyMigrateAuthority]_vars
SpecUnsafeHotplugPushAuthority == Init /\ [][UnsafeHotplugPushAuthority]_vars
SpecUnsafeMigrationStopAuthority == Init /\ [][UnsafeMigrationStopAuthority]_vars
SpecUnsafeLinuxExceptionAuthority == Init /\ [][UnsafeLinuxExceptionAuthority]_vars
SpecUnsafeLinuxHookApproved == Init /\ [][UnsafeLinuxHookApproved]_vars
SpecUnsafeBehaviorChangeClaim == Init /\ [][UnsafeBehaviorChangeClaim]_vars
SpecUnsafeMonitorVerifiedClaim == Init /\ [][UnsafeMonitorVerifiedClaim]_vars
SpecUnsafeProtectionClaim == Init /\ [][UnsafeProtectionClaim]_vars

SafeSpec == Init /\ [][SafeNext]_vars

CommittedTupleMatches(kind, edge, cpu) ==
    /\ tupleIssued
    /\ tupleConsumed
    /\ tupleKind = kind
    /\ tupleEdge = edge
    /\ tupleDest = cpu
    /\ tupleTaskGen = taskGen
    /\ tupleDomainEpoch = domainEpoch
    /\ tupleSchedCtxEpoch = schedCtxEpoch
    /\ tupleRunCapEpoch = runCapEpoch
    /\ tupleMoveSeq = moveSeq
    /\ tupleCoreSeq = coreSeq
    /\ tupleScxSeq = scxSeq
    /\ cpu \in FreshAllowed

NoRunWithoutFinalRevalidation ==
    running =>
        /\ rqCurrCommitted
        /\ contextSwitched
        /\ edgeKind \in RunEdges
        /\ CommittedTupleMatches("Run", edgeKind, runCpu)

NoMoveWithoutRevalidation ==
    moveCommitted =>
        /\ edgeKind \in MoveEdges
        /\ CommittedTupleMatches("Move", edgeKind, currentCpu)

NoRunMoveWithoutGrantAuthority ==
    (running \/ moveCommitted) => GrantAuthority

NoRunOutsideFreshSet ==
    running => runCpu \in FreshAllowed

NoMoveOutsideFreshSet ==
    moveCommitted => currentCpu \in FreshAllowed

NoRunOrMoveWithPendingMigration ==
    (running \/ moveCommitted) => ~migrationPending

NoNoIntersectionRunMove ==
    FreshAllowed = {} => /\ ~running
                         /\ ~moveCommitted

NoMoveTupleRunsTask ==
    running => tupleKind = "Run"

NoRunTupleMovesTask ==
    moveCommitted => tupleKind = "Move"

NoTupleEdgeMismatch ==
    (running \/ moveCommitted) => tupleEdge = edgeKind

NoHookAfterRqCurrCommit ==
    ~hookAfterRqCurrCommit

NoLinuxSelectedOrMoveAsAuthority ==
    /\ ~pickNextAuthority
    /\ ~setTaskCpuAuthority
    /\ ~moveQueuedAuthority
    /\ ~attachTaskAuthority
    /\ ~fairBalanceAuthority
    /\ ~rtPushPullAuthority
    /\ ~dlPushPullAuthority
    /\ ~scxDispatchAuthority
    /\ ~coreSchedulingAuthority
    /\ ~proxyMigrateAuthority
    /\ ~hotplugPushAuthority
    /\ ~migrationStopAuthority

NoLinuxExceptionAsOrdinaryAuthority ==
    (taskKind = "OrdinaryDomain" /\ (running \/ moveCommitted)) =>
        ~linuxExceptionAuthority

NoNonClaimOverreach ==
    /\ ~linuxHookApproved
    /\ ~behaviorChangeClaim
    /\ ~monitorVerifiedClaim
    /\ ~protectionClaim

=============================================================================
