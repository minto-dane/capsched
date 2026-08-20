---------- MODULE P5AR4E4LocalQuantumMeasurementPlan ----------
EXTENDS Naturals

CONSTANT Fault

VARIABLES
    phase,
    postGatePassed,
    candidateFrozen,
    claimLedgerComplete,
    exactScope,
    defaultOff,
    sameTU,
    e3Frozen,
    noLiveAttachment,
    n136Separate,
    realContexts,
    pairedControl,
    alternatingOrder,
    saturatingDifference,
    fullSamples,
    statisticsComplete,
    allMatricesComplete,
    localGatesFixed,
    lockDrainGateFixed,
    asyncGatesFixed,
    baseSliceNotBudget,
    noGlobalSettlementGate,
    logicalCountsComplete,
    negativeEvidencePreserved,
    rangeFrozen,
    dualArchSameSource,
    planAccepted,
    sourceDraftAllowed,
    measurementAllowed,
    behaviorAllowed,
    primaryChangeAllowed,
    patchQueueChangeAllowed,
    runtimeClaim,
    bareMetalClaim,
    performanceClaim,
    monitorClaim,
    productionClaim,
    multiClusterClaim,
    datacenterClaim

vars == <<
    phase,
    postGatePassed,
    candidateFrozen,
    claimLedgerComplete,
    exactScope,
    defaultOff,
    sameTU,
    e3Frozen,
    noLiveAttachment,
    n136Separate,
    realContexts,
    pairedControl,
    alternatingOrder,
    saturatingDifference,
    fullSamples,
    statisticsComplete,
    allMatricesComplete,
    localGatesFixed,
    lockDrainGateFixed,
    asyncGatesFixed,
    baseSliceNotBudget,
    noGlobalSettlementGate,
    logicalCountsComplete,
    negativeEvidencePreserved,
    rangeFrozen,
    dualArchSameSource,
    planAccepted,
    sourceDraftAllowed,
    measurementAllowed,
    behaviorAllowed,
    primaryChangeAllowed,
    patchQueueChangeAllowed,
    runtimeClaim,
    bareMetalClaim,
    performanceClaim,
    monitorClaim,
    productionClaim,
    multiClusterClaim,
    datacenterClaim
>>

Init ==
    /\ phase = "Start"
    /\ postGatePassed = FALSE
    /\ candidateFrozen = FALSE
    /\ claimLedgerComplete = FALSE
    /\ exactScope = FALSE
    /\ defaultOff = FALSE
    /\ sameTU = FALSE
    /\ e3Frozen = FALSE
    /\ noLiveAttachment = FALSE
    /\ n136Separate = FALSE
    /\ realContexts = FALSE
    /\ pairedControl = FALSE
    /\ alternatingOrder = FALSE
    /\ saturatingDifference = FALSE
    /\ fullSamples = FALSE
    /\ statisticsComplete = FALSE
    /\ allMatricesComplete = FALSE
    /\ localGatesFixed = FALSE
    /\ lockDrainGateFixed = FALSE
    /\ asyncGatesFixed = FALSE
    /\ baseSliceNotBudget = FALSE
    /\ noGlobalSettlementGate = FALSE
    /\ logicalCountsComplete = FALSE
    /\ negativeEvidencePreserved = FALSE
    /\ rangeFrozen = FALSE
    /\ dualArchSameSource = FALSE
    /\ planAccepted = FALSE
    /\ sourceDraftAllowed = FALSE
    /\ measurementAllowed = FALSE
    /\ behaviorAllowed = FALSE
    /\ primaryChangeAllowed = FALSE
    /\ patchQueueChangeAllowed = FALSE
    /\ runtimeClaim = FALSE
    /\ bareMetalClaim = FALSE
    /\ performanceClaim = FALSE
    /\ monitorClaim = FALSE
    /\ productionClaim = FALSE
    /\ multiClusterClaim = FALSE
    /\ datacenterClaim = FALSE

RecordPrerequisites ==
    /\ phase = "Start"
    /\ phase' = "PrerequisitesRecorded"
    /\ postGatePassed' = (Fault # "PostGateMissing")
    /\ candidateFrozen' = (Fault # "CandidateIdentityMoved")
    /\ claimLedgerComplete' = (Fault # "ClaimLedgerMissing")
    /\ UNCHANGED <<exactScope, defaultOff, sameTU, e3Frozen,
                    noLiveAttachment, n136Separate, realContexts,
                    pairedControl, alternatingOrder, saturatingDifference,
                    fullSamples, statisticsComplete, allMatricesComplete,
                    localGatesFixed, lockDrainGateFixed, asyncGatesFixed,
                    baseSliceNotBudget, noGlobalSettlementGate,
                    logicalCountsComplete, negativeEvidencePreserved,
                    rangeFrozen, dualArchSameSource, planAccepted,
                    sourceDraftAllowed, measurementAllowed, behaviorAllowed,
                    primaryChangeAllowed, patchQueueChangeAllowed,
                    runtimeClaim, bareMetalClaim, performanceClaim,
                    monitorClaim, productionClaim, multiClusterClaim,
                    datacenterClaim>>

RecordMeasurementContract ==
    /\ phase = "PrerequisitesRecorded"
    /\ phase' = "ContractRecorded"
    /\ exactScope' = (Fault # "SourceScopeExpanded")
    /\ defaultOff' = (Fault # "NotDefaultOff")
    /\ sameTU' = (Fault # "SeparateObject")
    /\ e3Frozen' = (Fault # "E3ProtocolChanged")
    /\ noLiveAttachment' = (Fault # "LiveSchedulerAttached")
    /\ n136Separate' = (Fault # "N136Conflated")
    /\ realContexts' = (Fault # "RealContextsMissing")
    /\ pairedControl' = (Fault # "UnpairedControl")
    /\ alternatingOrder' = (Fault # "PairOrderBiased")
    /\ saturatingDifference' = (Fault # "DifferenceWrapped")
    /\ fullSamples' = (Fault # "SamplesReduced")
    /\ statisticsComplete' = (Fault # "StatisticsMissing")
    /\ allMatricesComplete' =
        ~(Fault \in {
            "PublicationMatrixReduced",
            "PickerMatrixReduced",
            "IrqMatrixReduced",
            "RecoveryMatrixReduced",
            "NotifierMatrixReduced",
            "CurrentMatrixReduced",
            "OfflineMatrixReduced"
        })
    /\ localGatesFixed' = (Fault # "LocalThresholdRelaxed")
    /\ lockDrainGateFixed' = (Fault # "LockDrainThresholdRelaxed")
    /\ asyncGatesFixed' = (Fault # "AsyncThresholdRelaxed")
    /\ baseSliceNotBudget' = (Fault # "BaseSliceBudgetClaim")
    /\ noGlobalSettlementGate' =
        (Fault # "GlobalSettlementThresholdRestored")
    /\ logicalCountsComplete' = (Fault # "LogicalCountsMissing")
    /\ negativeEvidencePreserved' =
        ~(Fault \in {"WarningIgnored", "RejectionHidden",
                     "MalformedAccepted"})
    /\ rangeFrozen' = (Fault # "RangeReducedAfterFailure")
    /\ dualArchSameSource' =
        ~(Fault \in {"SingleArchitectureAccepted",
                     "SourceDriftBetweenArch"})
    /\ UNCHANGED <<postGatePassed, candidateFrozen,
                    claimLedgerComplete, planAccepted, sourceDraftAllowed,
                    measurementAllowed, behaviorAllowed,
                    primaryChangeAllowed, patchQueueChangeAllowed,
                    runtimeClaim, bareMetalClaim, performanceClaim,
                    monitorClaim, productionClaim, multiClusterClaim,
                    datacenterClaim>>

AuthorizePlanOnly ==
    /\ phase = "ContractRecorded"
    /\ phase' = "PlanAuthorized"
    /\ planAccepted' = (Fault # "SourceStartBeforePlan")
    /\ sourceDraftAllowed' = TRUE
    /\ measurementAllowed' =
        (Fault = "MeasurementStartBeforeSourceGate")
    /\ behaviorAllowed' = (Fault = "BehaviorSourcePremature")
    /\ primaryChangeAllowed' =
        (Fault = "PrimaryOrPatchQueueMutation")
    /\ patchQueueChangeAllowed' =
        (Fault = "PrimaryOrPatchQueueMutation")
    /\ runtimeClaim' = (Fault = "RuntimeClaim")
    /\ bareMetalClaim' = (Fault = "BareMetalClaimFromVirtual")
    /\ performanceClaim' = (Fault = "PerformanceOrCostClaim")
    /\ monitorClaim' = (Fault = "MonitorClaim")
    /\ productionClaim' =
        (Fault = "ProductionMultiClusterDatacenterClaim")
    /\ multiClusterClaim' =
        (Fault = "ProductionMultiClusterDatacenterClaim")
    /\ datacenterClaim' =
        (Fault = "ProductionMultiClusterDatacenterClaim")
    /\ UNCHANGED <<postGatePassed, candidateFrozen,
                    claimLedgerComplete, exactScope, defaultOff, sameTU,
                    e3Frozen, noLiveAttachment, n136Separate, realContexts,
                    pairedControl, alternatingOrder, saturatingDifference,
                    fullSamples, statisticsComplete, allMatricesComplete,
                    localGatesFixed, lockDrainGateFixed, asyncGatesFixed,
                    baseSliceNotBudget, noGlobalSettlementGate,
                    logicalCountsComplete, negativeEvidencePreserved,
                    rangeFrozen, dualArchSameSource>>

StutterAuthorized ==
    /\ phase = "PlanAuthorized"
    /\ UNCHANGED vars

Next ==
    \/ RecordPrerequisites
    \/ RecordMeasurementContract
    \/ AuthorizePlanOnly
    \/ StutterAuthorized

Spec == Init /\ [][Next]_vars

SourceDraftPreconditions ==
    sourceDraftAllowed =>
        /\ postGatePassed
        /\ candidateFrozen
        /\ claimLedgerComplete
        /\ exactScope
        /\ defaultOff
        /\ sameTU
        /\ e3Frozen
        /\ noLiveAttachment
        /\ n136Separate
        /\ realContexts
        /\ pairedControl
        /\ alternatingOrder
        /\ saturatingDifference
        /\ fullSamples
        /\ statisticsComplete
        /\ allMatricesComplete
        /\ localGatesFixed
        /\ lockDrainGateFixed
        /\ asyncGatesFixed
        /\ baseSliceNotBudget
        /\ noGlobalSettlementGate
        /\ logicalCountsComplete
        /\ negativeEvidencePreserved
        /\ rangeFrozen
        /\ dualArchSameSource
        /\ planAccepted

PlanOnlyAuthorization ==
    /\ ~measurementAllowed
    /\ ~behaviorAllowed
    /\ ~primaryChangeAllowed
    /\ ~patchQueueChangeAllowed

NoUnsupportedClaim ==
    /\ ~runtimeClaim
    /\ ~bareMetalClaim
    /\ ~performanceClaim
    /\ ~monitorClaim
    /\ ~productionClaim
    /\ ~multiClusterClaim
    /\ ~datacenterClaim

TypeOK ==
    /\ phase \in {"Start", "PrerequisitesRecorded", "ContractRecorded",
                    "PlanAuthorized"}
    /\ postGatePassed \in BOOLEAN
    /\ candidateFrozen \in BOOLEAN
    /\ claimLedgerComplete \in BOOLEAN
    /\ exactScope \in BOOLEAN
    /\ defaultOff \in BOOLEAN
    /\ sameTU \in BOOLEAN
    /\ e3Frozen \in BOOLEAN
    /\ noLiveAttachment \in BOOLEAN
    /\ n136Separate \in BOOLEAN
    /\ realContexts \in BOOLEAN
    /\ pairedControl \in BOOLEAN
    /\ alternatingOrder \in BOOLEAN
    /\ saturatingDifference \in BOOLEAN
    /\ fullSamples \in BOOLEAN
    /\ statisticsComplete \in BOOLEAN
    /\ allMatricesComplete \in BOOLEAN
    /\ localGatesFixed \in BOOLEAN
    /\ lockDrainGateFixed \in BOOLEAN
    /\ asyncGatesFixed \in BOOLEAN
    /\ baseSliceNotBudget \in BOOLEAN
    /\ noGlobalSettlementGate \in BOOLEAN
    /\ logicalCountsComplete \in BOOLEAN
    /\ negativeEvidencePreserved \in BOOLEAN
    /\ rangeFrozen \in BOOLEAN
    /\ dualArchSameSource \in BOOLEAN
    /\ planAccepted \in BOOLEAN
    /\ sourceDraftAllowed \in BOOLEAN
    /\ measurementAllowed \in BOOLEAN
    /\ behaviorAllowed \in BOOLEAN
    /\ primaryChangeAllowed \in BOOLEAN
    /\ patchQueueChangeAllowed \in BOOLEAN
    /\ runtimeClaim \in BOOLEAN
    /\ bareMetalClaim \in BOOLEAN
    /\ performanceClaim \in BOOLEAN
    /\ monitorClaim \in BOOLEAN
    /\ productionClaim \in BOOLEAN
    /\ multiClusterClaim \in BOOLEAN
    /\ datacenterClaim \in BOOLEAN

Safety ==
    /\ TypeOK
    /\ SourceDraftPreconditions
    /\ PlanOnlyAuthorization
    /\ NoUnsupportedClaim

=============================================================================
