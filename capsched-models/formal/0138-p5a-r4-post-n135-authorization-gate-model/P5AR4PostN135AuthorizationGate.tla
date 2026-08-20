---------- MODULE P5AR4PostN135AuthorizationGate ----------
EXTENDS Naturals

CONSTANT Fault

VARIABLES
    phase,
    planPassed,
    sourceGatePassed,
    matrixPassed,
    closurePassedTwice,
    claimLedgerComplete,
    driftFetched,
    touchedPathsFresh,
    mergeTreeClean,
    syntheticSourceAccepted,
    syntheticConcurrencyAccepted,
    e4PlanDraftAllowed,
    e4PlanAccepted,
    e4SourceAllowed,
    primaryChangeAllowed,
    patchQueueChangeAllowed,
    runtimeClaim,
    bareMetalClaim,
    productionClaim,
    multiClusterClaim,
    datacenterClaim,
    n136Conflated

vars == <<
    phase,
    planPassed,
    sourceGatePassed,
    matrixPassed,
    closurePassedTwice,
    claimLedgerComplete,
    driftFetched,
    touchedPathsFresh,
    mergeTreeClean,
    syntheticSourceAccepted,
    syntheticConcurrencyAccepted,
    e4PlanDraftAllowed,
    e4PlanAccepted,
    e4SourceAllowed,
    primaryChangeAllowed,
    patchQueueChangeAllowed,
    runtimeClaim,
    bareMetalClaim,
    productionClaim,
    multiClusterClaim,
    datacenterClaim,
    n136Conflated
>>

Init ==
    /\ phase = "Start"
    /\ planPassed = FALSE
    /\ sourceGatePassed = FALSE
    /\ matrixPassed = FALSE
    /\ closurePassedTwice = FALSE
    /\ claimLedgerComplete = FALSE
    /\ driftFetched = FALSE
    /\ touchedPathsFresh = FALSE
    /\ mergeTreeClean = FALSE
    /\ syntheticSourceAccepted = FALSE
    /\ syntheticConcurrencyAccepted = FALSE
    /\ e4PlanDraftAllowed = FALSE
    /\ e4PlanAccepted = FALSE
    /\ e4SourceAllowed = FALSE
    /\ primaryChangeAllowed = FALSE
    /\ patchQueueChangeAllowed = FALSE
    /\ runtimeClaim = FALSE
    /\ bareMetalClaim = FALSE
    /\ productionClaim = FALSE
    /\ multiClusterClaim = FALSE
    /\ datacenterClaim = FALSE
    /\ n136Conflated = FALSE

RecordN135 ==
    /\ phase = "Start"
    /\ phase' = "EvidenceRecorded"
    /\ planPassed' = (Fault # "MissingPlan")
    /\ sourceGatePassed' = (Fault # "MissingSourceGate")
    /\ matrixPassed' = (Fault # "MissingMatrix")
    /\ closurePassedTwice' = (Fault # "MissingClosure")
    /\ UNCHANGED <<claimLedgerComplete, driftFetched, touchedPathsFresh,
                    mergeTreeClean, syntheticSourceAccepted,
                    syntheticConcurrencyAccepted, e4PlanDraftAllowed,
                    e4PlanAccepted, e4SourceAllowed, primaryChangeAllowed,
                    patchQueueChangeAllowed, runtimeClaim, bareMetalClaim,
                    productionClaim, multiClusterClaim, datacenterClaim,
                    n136Conflated>>

RecordReview ==
    /\ phase = "EvidenceRecorded"
    /\ phase' = "ReviewRecorded"
    /\ claimLedgerComplete' = (Fault # "MissingClaimLedger")
    /\ driftFetched' = (Fault # "MissingDrift")
    /\ touchedPathsFresh' = (Fault # "TouchedPathDrift")
    /\ mergeTreeClean' = (Fault # "MergeConflict")
    /\ UNCHANGED <<planPassed, sourceGatePassed, matrixPassed,
                    closurePassedTwice, syntheticSourceAccepted,
                    syntheticConcurrencyAccepted, e4PlanDraftAllowed,
                    e4PlanAccepted, e4SourceAllowed, primaryChangeAllowed,
                    patchQueueChangeAllowed, runtimeClaim, bareMetalClaim,
                    productionClaim, multiClusterClaim, datacenterClaim,
                    n136Conflated>>

AuthorizeScopedNextStep ==
    /\ phase = "ReviewRecorded"
    /\ phase' = "Authorized"
    /\ syntheticSourceAccepted' = TRUE
    /\ syntheticConcurrencyAccepted' = TRUE
    /\ e4PlanDraftAllowed' = TRUE
    /\ e4PlanAccepted' = (Fault = "E4SourcePremature")
    /\ e4SourceAllowed' = (Fault = "E4SourcePremature")
    /\ primaryChangeAllowed' = (Fault = "PrimaryOrPatchQueueChange")
    /\ patchQueueChangeAllowed' = (Fault = "PrimaryOrPatchQueueChange")
    /\ runtimeClaim' = (Fault = "RuntimeClaim")
    /\ bareMetalClaim' = (Fault = "BareMetalClaim")
    /\ productionClaim' = (Fault = "ProductionClaim")
    /\ multiClusterClaim' = (Fault = "MultiClusterDatacenterClaim")
    /\ datacenterClaim' = (Fault = "MultiClusterDatacenterClaim")
    /\ n136Conflated' = (Fault = "N136Conflation")
    /\ UNCHANGED <<planPassed, sourceGatePassed, matrixPassed,
                    closurePassedTwice, claimLedgerComplete, driftFetched,
                    touchedPathsFresh, mergeTreeClean>>

StutterAuthorized ==
    /\ phase = "Authorized"
    /\ UNCHANGED vars

Next ==
    \/ RecordN135
    \/ RecordReview
    \/ AuthorizeScopedNextStep
    \/ StutterAuthorized

Spec == Init /\ [][Next]_vars

AcceptancePreconditions ==
    (syntheticSourceAccepted \/ syntheticConcurrencyAccepted \/
     e4PlanDraftAllowed) =>
        /\ planPassed
        /\ sourceGatePassed
        /\ matrixPassed
        /\ closurePassedTwice
        /\ claimLedgerComplete
        /\ driftFetched
        /\ touchedPathsFresh
        /\ mergeTreeClean

ScopedAcceptanceAligned ==
    /\ syntheticSourceAccepted = syntheticConcurrencyAccepted
    /\ syntheticConcurrencyAccepted = e4PlanDraftAllowed

NoPrematureSourceOrPrimaryMutation ==
    /\ ~e4PlanAccepted
    /\ ~e4SourceAllowed
    /\ ~primaryChangeAllowed
    /\ ~patchQueueChangeAllowed

NoRuntimeOrProductionOverclaim ==
    /\ ~runtimeClaim
    /\ ~bareMetalClaim
    /\ ~productionClaim
    /\ ~multiClusterClaim
    /\ ~datacenterClaim
    /\ ~n136Conflated

Safety ==
    /\ AcceptancePreconditions
    /\ ScopedAcceptanceAligned
    /\ NoPrematureSourceOrPrimaryMutation
    /\ NoRuntimeOrProductionOverclaim

=============================================================================
