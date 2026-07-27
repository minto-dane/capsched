---------- MODULE P5AR6E4LocalQuantumMeasurementPlan ----------
EXTENDS Naturals, FiniteSets

CONSTANT Fault

InputFaults == {
    "MissingPostE3Authorization",
    "MissingThreatModel",
    "MissingE3Evidence",
    "MissingClaimLedger",
    "StaleUpstreamDrift",
    "UnclassifiedUpstreamDrift",
    "MergeConflict",
    "CandidateRemoteMismatch"
}

SourceFaults == {
    "WrongFutureParent",
    "BroadenedSourceScope",
    "E3HelperChanged",
    "E3MatrixNotRetained",
    "E4NotDefaultOff",
    "E4SelectedNormally",
    "DisabledArtifactPresent",
    "PublicSurfaceAdded",
    "LiveSchedulerAttachment"
}

CommonMeasurementFaults == {
    "MissingPairedControl",
    "StorageAllocatedInsideInterval",
    "LocalClockMissing",
    "LockOrIrqShellMismatch",
    "SortPrintAssertInsideInterval",
    "TimingSleepUsed",
    "ClockRegressionAccepted",
    "VcpuMigrationAccepted",
    "RawRowsMissing",
    "WarningAccepted"
}

FamilyContractFaults == {
    "PublicationFamilyMissing",
    "LeafFamilyMissing",
    "AggregateFamilyMissing",
    "CandidateFamilyMissing",
    "CompleteFamilyMissing",
    "ReconcileFamilyMissing",
    "SlotTaskFamilyMissing",
    "EevdfBaselineMisclaimed",
    "CurrentFamilyMissing",
    "CurrentRequestClaimedComplete",
    "OfflineFamilyMissing"
}

MatrixFaults == {
    "ActiveSlotAxisReduced",
    "MaskPatternAxisReduced",
    "CurrentSlotAxisReduced",
    "NewlyAllowedAxisReduced",
    "InnerTaskAxisReduced",
    "CgroupDepthAxisReduced",
    "PublicationBurstAxisReduced"
}

ClassificationFaults == {
    "OrdinaryThresholdRelaxed",
    "OfflineThresholdRelaxed",
    "BaseSliceUsedAsBudget",
    "Arm64NotFirst",
    "Arm64RejectionContinues",
    "GlobalSettlementClaim"
}

AuthorizationFaults == {
    "MeasurementStartBeforeSourceGate",
    "PlanClaimsMeasurementAccepted",
    "R6BehaviorSourceAuthorized",
    "PrimaryLinuxChange",
    "PatchQueueChange"
}

ClaimFaults == {
    "RuntimeClaim",
    "RuntimeBudgetClaim",
    "AsyncServiceClaim",
    "MemoryViewTLBClaim",
    "DeviceDMAIOMMUClaim",
    "MonitorClaim",
    "ClusterClaim",
    "BareMetalClaim",
    "PerformanceClaim",
    "CostClaim",
    "ProductionClaim",
    "DeploymentClaim",
    "MultiNodeClaim",
    "MultiClusterClaim",
    "DatacenterClaim"
}

Phases == {
    "Ready",
    "Bound",
    "Published",
    "LeafUpdated",
    "Aggregated",
    "CandidateScanned",
    "QueryComplete",
    "Reconciled",
    "Checked",
    "StopRequested",
    "StopObserved",
    "OfflineHidden",
    "Drained",
    "Authorized"
}

VARIABLES
    phase,
    inputBindingsSafe,
    sourceBoundarySafe,
    commonMeasurementSafe,
    familyContractSafe,
    matrixContractSafe,
    classificationSafe,
    authorizationBoundarySafe,
    claimBoundarySafe,
    pairsPerCell,
    matrixCells,
    publicationWork,
    leafAncestors,
    aggregateVisits,
    candidateVisits,
    completeVisits,
    reconcileVisits,
    taskCheck,
    currentRequest,
    currentObserved,
    accepting,
    visible,
    drainUnderLock,
    refs,
    rcuGrace,
    planAccepted,
    sourceDraftAllowed,
    sourceCreated,
    measurementStarted

vars == <<
    phase,
    inputBindingsSafe,
    sourceBoundarySafe,
    commonMeasurementSafe,
    familyContractSafe,
    matrixContractSafe,
    classificationSafe,
    authorizationBoundarySafe,
    claimBoundarySafe,
    pairsPerCell,
    matrixCells,
    publicationWork,
    leafAncestors,
    aggregateVisits,
    candidateVisits,
    completeVisits,
    reconcileVisits,
    taskCheck,
    currentRequest,
    currentObserved,
    accepting,
    visible,
    drainUnderLock,
    refs,
    rcuGrace,
    planAccepted,
    sourceDraftAllowed,
    sourceCreated,
    measurementStarted
>>

Init ==
    /\ phase = "Ready"
    /\ inputBindingsSafe = ~(Fault \in InputFaults)
    /\ sourceBoundarySafe = ~(Fault \in SourceFaults)
    /\ commonMeasurementSafe = ~(Fault \in CommonMeasurementFaults)
    /\ familyContractSafe = ~(Fault \in FamilyContractFaults)
    /\ matrixContractSafe = ~(Fault \in MatrixFaults)
    /\ classificationSafe = ~(Fault \in ClassificationFaults)
    /\ authorizationBoundarySafe = ~(Fault \in AuthorizationFaults)
    /\ claimBoundarySafe = ~(Fault \in ClaimFaults)
    /\ pairsPerCell = IF Fault = "PairCountReduced" THEN 9999 ELSE 10000
    /\ matrixCells = IF Fault = "MatrixCellCountReduced" THEN 854 ELSE 855
    /\ publicationWork =
        IF Fault = "PublicationVariableWork" THEN 64 ELSE 1
    /\ leafAncestors =
        IF Fault = "LeafAncestorOverflow" THEN 7 ELSE 6
    /\ aggregateVisits =
        IF Fault = "AggregateVisitOverflow" THEN 128 ELSE 127
    /\ candidateVisits =
        IF Fault = "CandidateVisitOverflow" THEN 128 ELSE 127
    /\ completeVisits =
        IF Fault = "CompleteVisitOverflow" THEN 255 ELSE 254
    /\ reconcileVisits =
        IF Fault = "ReconcileVisitOverflow" THEN 65 ELSE 64
    /\ taskCheck = (Fault # "FinalTaskCheckMissing")
    /\ currentRequest = 0
    /\ currentObserved = 0
    /\ accepting = TRUE
    /\ visible = TRUE
    /\ drainUnderLock = (Fault = "SleepableDrainUnderRqLock")
    /\ refs = 2
    /\ rcuGrace = FALSE
    /\ planAccepted = FALSE
    /\ sourceDraftAllowed = FALSE
    /\ sourceCreated = FALSE
    /\ measurementStarted = (Fault = "MeasurementStartBeforeSourceGate")

BindInputs ==
    /\ phase = "Ready"
    /\ phase' = "Bound"
    /\ UNCHANGED <<inputBindingsSafe, sourceBoundarySafe,
                    commonMeasurementSafe, familyContractSafe,
                    matrixContractSafe, classificationSafe,
                    authorizationBoundarySafe, claimBoundarySafe,
                    pairsPerCell, matrixCells, publicationWork,
                    leafAncestors, aggregateVisits, candidateVisits,
                    completeVisits, reconcileVisits, taskCheck,
                    currentRequest, currentObserved, accepting, visible,
                    drainUnderLock, refs, rcuGrace, planAccepted,
                    sourceDraftAllowed, sourceCreated, measurementStarted>>

MeasurePublication ==
    /\ phase = "Bound"
    /\ phase' = "Published"
    /\ UNCHANGED <<inputBindingsSafe, sourceBoundarySafe,
                    commonMeasurementSafe, familyContractSafe,
                    matrixContractSafe, classificationSafe,
                    authorizationBoundarySafe, claimBoundarySafe,
                    pairsPerCell, matrixCells, publicationWork,
                    leafAncestors, aggregateVisits, candidateVisits,
                    completeVisits, reconcileVisits, taskCheck,
                    currentRequest, currentObserved, accepting, visible,
                    drainUnderLock, refs, rcuGrace, planAccepted,
                    sourceDraftAllowed, sourceCreated, measurementStarted>>

MeasureLeafUpdate ==
    /\ phase = "Published"
    /\ phase' = "LeafUpdated"
    /\ UNCHANGED <<inputBindingsSafe, sourceBoundarySafe,
                    commonMeasurementSafe, familyContractSafe,
                    matrixContractSafe, classificationSafe,
                    authorizationBoundarySafe, claimBoundarySafe,
                    pairsPerCell, matrixCells, publicationWork,
                    leafAncestors, aggregateVisits, candidateVisits,
                    completeVisits, reconcileVisits, taskCheck,
                    currentRequest, currentObserved, accepting, visible,
                    drainUnderLock, refs, rcuGrace, planAccepted,
                    sourceDraftAllowed, sourceCreated, measurementStarted>>

MeasureAggregate ==
    /\ phase = "LeafUpdated"
    /\ phase' = "Aggregated"
    /\ UNCHANGED <<inputBindingsSafe, sourceBoundarySafe,
                    commonMeasurementSafe, familyContractSafe,
                    matrixContractSafe, classificationSafe,
                    authorizationBoundarySafe, claimBoundarySafe,
                    pairsPerCell, matrixCells, publicationWork,
                    leafAncestors, aggregateVisits, candidateVisits,
                    completeVisits, reconcileVisits, taskCheck,
                    currentRequest, currentObserved, accepting, visible,
                    drainUnderLock, refs, rcuGrace, planAccepted,
                    sourceDraftAllowed, sourceCreated, measurementStarted>>

MeasureCandidate ==
    /\ phase = "Aggregated"
    /\ phase' = "CandidateScanned"
    /\ UNCHANGED <<inputBindingsSafe, sourceBoundarySafe,
                    commonMeasurementSafe, familyContractSafe,
                    matrixContractSafe, classificationSafe,
                    authorizationBoundarySafe, claimBoundarySafe,
                    pairsPerCell, matrixCells, publicationWork,
                    leafAncestors, aggregateVisits, candidateVisits,
                    completeVisits, reconcileVisits, taskCheck,
                    currentRequest, currentObserved, accepting, visible,
                    drainUnderLock, refs, rcuGrace, planAccepted,
                    sourceDraftAllowed, sourceCreated, measurementStarted>>

MeasureCompleteQuery ==
    /\ phase = "CandidateScanned"
    /\ phase' = "QueryComplete"
    /\ UNCHANGED <<inputBindingsSafe, sourceBoundarySafe,
                    commonMeasurementSafe, familyContractSafe,
                    matrixContractSafe, classificationSafe,
                    authorizationBoundarySafe, claimBoundarySafe,
                    pairsPerCell, matrixCells, publicationWork,
                    leafAncestors, aggregateVisits, candidateVisits,
                    completeVisits, reconcileVisits, taskCheck,
                    currentRequest, currentObserved, accepting, visible,
                    drainUnderLock, refs, rcuGrace, planAccepted,
                    sourceDraftAllowed, sourceCreated, measurementStarted>>

MeasureReconcile ==
    /\ phase = "QueryComplete"
    /\ phase' = "Reconciled"
    /\ UNCHANGED <<inputBindingsSafe, sourceBoundarySafe,
                    commonMeasurementSafe, familyContractSafe,
                    matrixContractSafe, classificationSafe,
                    authorizationBoundarySafe, claimBoundarySafe,
                    pairsPerCell, matrixCells, publicationWork,
                    leafAncestors, aggregateVisits, candidateVisits,
                    completeVisits, reconcileVisits, taskCheck,
                    currentRequest, currentObserved, accepting, visible,
                    drainUnderLock, refs, rcuGrace, planAccepted,
                    sourceDraftAllowed, sourceCreated, measurementStarted>>

MeasureFinalCheck ==
    /\ phase = "Reconciled"
    /\ phase' = "Checked"
    /\ UNCHANGED <<inputBindingsSafe, sourceBoundarySafe,
                    commonMeasurementSafe, familyContractSafe,
                    matrixContractSafe, classificationSafe,
                    authorizationBoundarySafe, claimBoundarySafe,
                    pairsPerCell, matrixCells, publicationWork,
                    leafAncestors, aggregateVisits, candidateVisits,
                    completeVisits, reconcileVisits, taskCheck,
                    currentRequest, currentObserved, accepting, visible,
                    drainUnderLock, refs, rcuGrace, planAccepted,
                    sourceDraftAllowed, sourceCreated, measurementStarted>>

RequestCurrentStop ==
    /\ phase = "Checked"
    /\ phase' = "StopRequested"
    /\ currentRequest' = 1
    /\ UNCHANGED <<inputBindingsSafe, sourceBoundarySafe,
                    commonMeasurementSafe, familyContractSafe,
                    matrixContractSafe, classificationSafe,
                    authorizationBoundarySafe, claimBoundarySafe,
                    pairsPerCell, matrixCells, publicationWork,
                    leafAncestors, aggregateVisits, candidateVisits,
                    completeVisits, reconcileVisits, taskCheck,
                    currentObserved, accepting, visible, drainUnderLock,
                    refs, rcuGrace, planAccepted, sourceDraftAllowed,
                    sourceCreated, measurementStarted>>

ObserveCurrentStop ==
    /\ phase = "StopRequested"
    /\ Fault # "MissingCurrentObservation"
    /\ phase' = "StopObserved"
    /\ currentObserved' = currentRequest
    /\ UNCHANGED <<inputBindingsSafe, sourceBoundarySafe,
                    commonMeasurementSafe, familyContractSafe,
                    matrixContractSafe, classificationSafe,
                    authorizationBoundarySafe, claimBoundarySafe,
                    pairsPerCell, matrixCells, publicationWork,
                    leafAncestors, aggregateVisits, candidateVisits,
                    completeVisits, reconcileVisits, taskCheck,
                    currentRequest, accepting, visible, drainUnderLock,
                    refs, rcuGrace, planAccepted, sourceDraftAllowed,
                    sourceCreated, measurementStarted>>

HideOffline ==
    /\ phase = "StopObserved"
    /\ phase' = "OfflineHidden"
    /\ accepting' = (Fault = "OfflineVisibleDuringDrain")
    /\ visible' = (Fault = "OfflineVisibleDuringDrain")
    /\ UNCHANGED <<inputBindingsSafe, sourceBoundarySafe,
                    commonMeasurementSafe, familyContractSafe,
                    matrixContractSafe, classificationSafe,
                    authorizationBoundarySafe, claimBoundarySafe,
                    pairsPerCell, matrixCells, publicationWork,
                    leafAncestors, aggregateVisits, candidateVisits,
                    completeVisits, reconcileVisits, taskCheck,
                    currentRequest, currentObserved, drainUnderLock,
                    refs, rcuGrace, planAccepted, sourceDraftAllowed,
                    sourceCreated, measurementStarted>>

DrainOffline ==
    /\ phase = "OfflineHidden"
    /\ Fault # "MissingOfflineDrain"
    /\ phase' = "Drained"
    /\ refs' = 0
    /\ rcuGrace' = TRUE
    /\ UNCHANGED <<inputBindingsSafe, sourceBoundarySafe,
                    commonMeasurementSafe, familyContractSafe,
                    matrixContractSafe, classificationSafe,
                    authorizationBoundarySafe, claimBoundarySafe,
                    pairsPerCell, matrixCells, publicationWork,
                    leafAncestors, aggregateVisits, candidateVisits,
                    completeVisits, reconcileVisits, taskCheck,
                    currentRequest, currentObserved, accepting, visible,
                    drainUnderLock, planAccepted, sourceDraftAllowed,
                    sourceCreated, measurementStarted>>

AuthorizePlan ==
    /\ phase = "Drained"
    /\ phase' = "Authorized"
    /\ planAccepted' = TRUE
    /\ sourceDraftAllowed' = TRUE
    /\ UNCHANGED <<inputBindingsSafe, sourceBoundarySafe,
                    commonMeasurementSafe, familyContractSafe,
                    matrixContractSafe, classificationSafe,
                    authorizationBoundarySafe, claimBoundarySafe,
                    pairsPerCell, matrixCells, publicationWork,
                    leafAncestors, aggregateVisits, candidateVisits,
                    completeVisits, reconcileVisits, taskCheck,
                    currentRequest, currentObserved, accepting, visible,
                    drainUnderLock, refs, rcuGrace, sourceCreated,
                    measurementStarted>>

Next ==
    \/ BindInputs
    \/ MeasurePublication
    \/ MeasureLeafUpdate
    \/ MeasureAggregate
    \/ MeasureCandidate
    \/ MeasureCompleteQuery
    \/ MeasureReconcile
    \/ MeasureFinalCheck
    \/ RequestCurrentStop
    \/ ObserveCurrentStop
    \/ HideOffline
    \/ DrainOffline
    \/ AuthorizePlan

Spec ==
    /\ Init
    /\ [][Next]_vars
    /\ WF_vars(BindInputs)
    /\ WF_vars(MeasurePublication)
    /\ WF_vars(MeasureLeafUpdate)
    /\ WF_vars(MeasureAggregate)
    /\ WF_vars(MeasureCandidate)
    /\ WF_vars(MeasureCompleteQuery)
    /\ WF_vars(MeasureReconcile)
    /\ WF_vars(MeasureFinalCheck)
    /\ WF_vars(RequestCurrentStop)
    /\ WF_vars(ObserveCurrentStop)
    /\ WF_vars(HideOffline)
    /\ WF_vars(DrainOffline)
    /\ WF_vars(AuthorizePlan)

TypeOK ==
    /\ phase \in Phases
    /\ inputBindingsSafe \in BOOLEAN
    /\ sourceBoundarySafe \in BOOLEAN
    /\ commonMeasurementSafe \in BOOLEAN
    /\ familyContractSafe \in BOOLEAN
    /\ matrixContractSafe \in BOOLEAN
    /\ classificationSafe \in BOOLEAN
    /\ authorizationBoundarySafe \in BOOLEAN
    /\ claimBoundarySafe \in BOOLEAN
    /\ pairsPerCell \in {9999, 10000}
    /\ matrixCells \in {854, 855}
    /\ publicationWork \in {1, 64}
    /\ leafAncestors \in {6, 7}
    /\ aggregateVisits \in {127, 128}
    /\ candidateVisits \in {127, 128}
    /\ completeVisits \in {254, 255}
    /\ reconcileVisits \in {64, 65}
    /\ taskCheck \in BOOLEAN
    /\ currentRequest \in 0..1
    /\ currentObserved \in 0..1
    /\ accepting \in BOOLEAN
    /\ visible \in BOOLEAN
    /\ drainUnderLock \in BOOLEAN
    /\ refs \in 0..2
    /\ rcuGrace \in BOOLEAN
    /\ planAccepted \in BOOLEAN
    /\ sourceDraftAllowed \in BOOLEAN
    /\ sourceCreated \in BOOLEAN
    /\ measurementStarted \in BOOLEAN

MeasurementPlanSafety ==
    /\ inputBindingsSafe
    /\ sourceBoundarySafe
    /\ commonMeasurementSafe
    /\ familyContractSafe
    /\ matrixContractSafe
    /\ classificationSafe
    /\ authorizationBoundarySafe
    /\ claimBoundarySafe
    /\ pairsPerCell = 10000
    /\ matrixCells = 855
    /\ publicationWork = 1
    /\ leafAncestors = 6
    /\ aggregateVisits = 127
    /\ candidateVisits = 127
    /\ completeVisits = 254
    /\ reconcileVisits = 64
    /\ taskCheck
    /\ ~drainUnderLock
    /\ (phase \in {"StopObserved", "OfflineHidden", "Drained", "Authorized"}
        => currentObserved = currentRequest)
    /\ (phase \in {"OfflineHidden", "Drained", "Authorized"}
        => ~accepting /\ ~visible)
    /\ (phase \in {"Drained", "Authorized"} => refs = 0 /\ rcuGrace)
    /\ (sourceDraftAllowed =>
        planAccepted /\ ~sourceCreated /\ ~measurementStarted)
    /\ (planAccepted => phase = "Authorized")

CurrentObservationProgress ==
    [](phase = "StopRequested" => <>(currentObserved = currentRequest))

OfflineDrainProgress ==
    [](phase = "OfflineHidden" => <>(refs = 0 /\ rcuGrace))

=============================================================================
