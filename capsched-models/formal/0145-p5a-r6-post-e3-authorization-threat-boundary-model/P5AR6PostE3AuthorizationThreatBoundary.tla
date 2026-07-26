---------- MODULE P5AR6PostE3AuthorizationThreatBoundary ----------
EXTENDS Naturals

CONSTANT Fault

VARIABLES
    phase,
    threatModelBound,
    planPassed,
    sourceGatePassed,
    matrixPassed,
    closurePassedTwice,
    claimLedgerComplete,
    driftObserved,
    driftClassified,
    mergeTreeClean,
    exactSourceScope,
    syntheticSourceAccepted,
    syntheticCorrectnessAccepted,
    e4PlanDraftAllowed,
    e4PlanAccepted,
    e4SourceAllowed,
    liveSchedulerAllowed,
    primaryChangeAllowed,
    patchQueueChangeAllowed,
    runtimeClaim,
    budgetConflated,
    asyncServiceClaim,
    memoryViewTLBClaim,
    deviceDMAIOMMUClaim,
    monitorClaim,
    clusterClaim,
    bareMetalPerformanceClaim,
    productionDeploymentClaim,
    multiClusterDatacenterClaim

vars == <<
    phase,
    threatModelBound,
    planPassed,
    sourceGatePassed,
    matrixPassed,
    closurePassedTwice,
    claimLedgerComplete,
    driftObserved,
    driftClassified,
    mergeTreeClean,
    exactSourceScope,
    syntheticSourceAccepted,
    syntheticCorrectnessAccepted,
    e4PlanDraftAllowed,
    e4PlanAccepted,
    e4SourceAllowed,
    liveSchedulerAllowed,
    primaryChangeAllowed,
    patchQueueChangeAllowed,
    runtimeClaim,
    budgetConflated,
    asyncServiceClaim,
    memoryViewTLBClaim,
    deviceDMAIOMMUClaim,
    monitorClaim,
    clusterClaim,
    bareMetalPerformanceClaim,
    productionDeploymentClaim,
    multiClusterDatacenterClaim
>>

Init ==
    /\ phase = "Start"
    /\ threatModelBound = FALSE
    /\ planPassed = FALSE
    /\ sourceGatePassed = FALSE
    /\ matrixPassed = FALSE
    /\ closurePassedTwice = FALSE
    /\ claimLedgerComplete = FALSE
    /\ driftObserved = FALSE
    /\ driftClassified = FALSE
    /\ mergeTreeClean = FALSE
    /\ exactSourceScope = FALSE
    /\ syntheticSourceAccepted = FALSE
    /\ syntheticCorrectnessAccepted = FALSE
    /\ e4PlanDraftAllowed = FALSE
    /\ e4PlanAccepted = FALSE
    /\ e4SourceAllowed = FALSE
    /\ liveSchedulerAllowed = FALSE
    /\ primaryChangeAllowed = FALSE
    /\ patchQueueChangeAllowed = FALSE
    /\ runtimeClaim = FALSE
    /\ budgetConflated = FALSE
    /\ asyncServiceClaim = FALSE
    /\ memoryViewTLBClaim = FALSE
    /\ deviceDMAIOMMUClaim = FALSE
    /\ monitorClaim = FALSE
    /\ clusterClaim = FALSE
    /\ bareMetalPerformanceClaim = FALSE
    /\ productionDeploymentClaim = FALSE
    /\ multiClusterDatacenterClaim = FALSE

RecordEvidence ==
    /\ phase = "Start"
    /\ phase' = "EvidenceRecorded"
    /\ threatModelBound' = (Fault # "MissingThreatModel")
    /\ planPassed' = (Fault # "MissingPlan")
    /\ sourceGatePassed' = (Fault # "MissingSourceGate")
    /\ matrixPassed' = (Fault # "MissingMatrix")
    /\ closurePassedTwice' = (Fault # "MissingClosure")
    /\ UNCHANGED <<claimLedgerComplete, driftObserved, driftClassified,
                    mergeTreeClean, exactSourceScope,
                    syntheticSourceAccepted, syntheticCorrectnessAccepted,
                    e4PlanDraftAllowed, e4PlanAccepted, e4SourceAllowed,
                    liveSchedulerAllowed, primaryChangeAllowed,
                    patchQueueChangeAllowed, runtimeClaim, budgetConflated,
                    asyncServiceClaim, memoryViewTLBClaim,
                    deviceDMAIOMMUClaim, monitorClaim, clusterClaim,
                    bareMetalPerformanceClaim, productionDeploymentClaim,
                    multiClusterDatacenterClaim>>

RecordReview ==
    /\ phase = "EvidenceRecorded"
    /\ phase' = "ReviewRecorded"
    /\ claimLedgerComplete' = (Fault # "MissingClaimLedger")
    /\ driftObserved' = (Fault # "MissingDriftObservation")
    /\ driftClassified' = (Fault # "UnclassifiedTouchedPathDrift")
    /\ mergeTreeClean' = (Fault # "MergeConflict")
    /\ exactSourceScope' = (Fault # "SourceScopeBroadened")
    /\ UNCHANGED <<threatModelBound, planPassed, sourceGatePassed,
                    matrixPassed, closurePassedTwice,
                    syntheticSourceAccepted, syntheticCorrectnessAccepted,
                    e4PlanDraftAllowed, e4PlanAccepted, e4SourceAllowed,
                    liveSchedulerAllowed, primaryChangeAllowed,
                    patchQueueChangeAllowed, runtimeClaim, budgetConflated,
                    asyncServiceClaim, memoryViewTLBClaim,
                    deviceDMAIOMMUClaim, monitorClaim, clusterClaim,
                    bareMetalPerformanceClaim, productionDeploymentClaim,
                    multiClusterDatacenterClaim>>

AuthorizeScopedNextStep ==
    /\ phase = "ReviewRecorded"
    /\ phase' = "Authorized"
    /\ syntheticSourceAccepted' = TRUE
    /\ syntheticCorrectnessAccepted' = TRUE
    /\ e4PlanDraftAllowed' = TRUE
    /\ e4PlanAccepted' = (Fault = "PrematureE4PlanAccepted")
    /\ e4SourceAllowed' = (Fault = "PrematureE4Source")
    /\ liveSchedulerAllowed' = (Fault = "LiveSchedulerAttachment")
    /\ primaryChangeAllowed' = (Fault = "PrimaryOrPatchQueueChange")
    /\ patchQueueChangeAllowed' = (Fault = "PrimaryOrPatchQueueChange")
    /\ runtimeClaim' = (Fault = "RuntimeClaim")
    /\ budgetConflated' = (Fault = "RuntimeBudgetConflation")
    /\ asyncServiceClaim' = (Fault = "AsyncServiceClaim")
    /\ memoryViewTLBClaim' = (Fault = "MemoryViewTLBClaim")
    /\ deviceDMAIOMMUClaim' = (Fault = "DeviceDMAIOMMUClaim")
    /\ monitorClaim' = (Fault = "MonitorClaim")
    /\ clusterClaim' = (Fault = "ClusterClaim")
    /\ bareMetalPerformanceClaim' = (Fault = "BareMetalPerformanceClaim")
    /\ productionDeploymentClaim' = (Fault = "ProductionDeploymentClaim")
    /\ multiClusterDatacenterClaim' =
        (Fault = "MultiClusterDatacenterClaim")
    /\ UNCHANGED <<threatModelBound, planPassed, sourceGatePassed,
                    matrixPassed, closurePassedTwice, claimLedgerComplete,
                    driftObserved, driftClassified, mergeTreeClean,
                    exactSourceScope>>

StutterAuthorized ==
    /\ phase = "Authorized"
    /\ UNCHANGED vars

Next ==
    \/ RecordEvidence
    \/ RecordReview
    \/ AuthorizeScopedNextStep
    \/ StutterAuthorized

Spec == Init /\ [][Next]_vars

AcceptancePreconditions ==
    (syntheticSourceAccepted \/ syntheticCorrectnessAccepted \/
     e4PlanDraftAllowed) =>
        /\ threatModelBound
        /\ planPassed
        /\ sourceGatePassed
        /\ matrixPassed
        /\ closurePassedTwice
        /\ claimLedgerComplete
        /\ driftObserved
        /\ driftClassified
        /\ mergeTreeClean
        /\ exactSourceScope

ScopedAcceptanceAligned ==
    /\ syntheticSourceAccepted = syntheticCorrectnessAccepted
    /\ syntheticCorrectnessAccepted = e4PlanDraftAllowed

NoPrematureSourceOrMutation ==
    /\ ~e4PlanAccepted
    /\ ~e4SourceAllowed
    /\ ~liveSchedulerAllowed
    /\ ~primaryChangeAllowed
    /\ ~patchQueueChangeAllowed

NoThreatBoundaryOverclaim ==
    /\ ~runtimeClaim
    /\ ~budgetConflated
    /\ ~asyncServiceClaim
    /\ ~memoryViewTLBClaim
    /\ ~deviceDMAIOMMUClaim
    /\ ~monitorClaim
    /\ ~clusterClaim
    /\ ~bareMetalPerformanceClaim
    /\ ~productionDeploymentClaim
    /\ ~multiClusterDatacenterClaim

Safety ==
    /\ AcceptancePreconditions
    /\ ScopedAcceptanceAligned
    /\ NoPrematureSourceOrMutation
    /\ NoThreatBoundaryOverclaim

=============================================================================
