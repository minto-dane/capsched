---------- MODULE ImplementationReopenDriftGate ----------
EXTENDS Naturals

VARIABLE gate

vars == <<gate>>

Slice == {"P3", "P4", "P5"}

Phase == {
    "ReopenGateChecked",
    "BadNoFreshFetch",
    "BadNoSourceDriftRun",
    "BadUnknownGroupClassification",
    "BadCleanMergeAsFreshness",
    "BadStaleModelReopen",
    "BadTouchedGroupStale",
    "BadMissingClaimLedger",
    "BadP5MissingPathClassification",
    "BadP5MissingNegativePlan",
    "BadBehaviorChangeFromDrift",
    "BadRuntimeCoverageFromDrift",
    "BadAbiFromDrift",
    "BadMonitorVerificationFromDrift",
    "BadProductionProtectionFromDrift",
    "BadCostEfficiencyFromDrift"
}

GateFields == {
    "phase",
    "slice",
    "freshFetch",
    "sourceDriftRun",
    "exactCommitsRecorded",
    "groupsClassified",
    "mergeTreeChecked",
    "mergeTreeClean",
    "cleanMergeUsedAsFreshness",
    "modelFresh",
    "touchedGroupsFresh",
    "claimLedgerPresent",
    "sliceGatesPresent",
    "p5PathClassificationPresent",
    "p5NegativePlanPresent",
    "implementationScopeReopened",
    "linuxPatchApproved",
    "behaviorChange",
    "runtimeCoverageClaim",
    "abiClaim",
    "monitorVerificationClaim",
    "productionProtectionClaim",
    "costEfficiencyClaim",
    "nonClaimsRecorded"
}

BaseGate == [
    phase |-> "ReopenGateChecked",
    slice |-> "P5",
    freshFetch |-> TRUE,
    sourceDriftRun |-> TRUE,
    exactCommitsRecorded |-> TRUE,
    groupsClassified |-> TRUE,
    mergeTreeChecked |-> TRUE,
    mergeTreeClean |-> TRUE,
    cleanMergeUsedAsFreshness |-> FALSE,
    modelFresh |-> TRUE,
    touchedGroupsFresh |-> TRUE,
    claimLedgerPresent |-> TRUE,
    sliceGatesPresent |-> TRUE,
    p5PathClassificationPresent |-> TRUE,
    p5NegativePlanPresent |-> TRUE,
    implementationScopeReopened |-> FALSE,
    linuxPatchApproved |-> FALSE,
    behaviorChange |-> FALSE,
    runtimeCoverageClaim |-> FALSE,
    abiClaim |-> FALSE,
    monitorVerificationClaim |-> FALSE,
    productionProtectionClaim |-> FALSE,
    costEfficiencyClaim |-> FALSE,
    nonClaimsRecorded |-> TRUE
]

Init == gate = BaseGate

Spec == Init /\ [][UNCHANGED gate]_vars

UnsafeNoFreshFetchSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadNoFreshFetch",
        !.freshFetch = FALSE,
        !.implementationScopeReopened = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeNoSourceDriftRunSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadNoSourceDriftRun",
        !.sourceDriftRun = FALSE,
        !.implementationScopeReopened = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeUnknownGroupClassificationSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadUnknownGroupClassification",
        !.groupsClassified = FALSE,
        !.implementationScopeReopened = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeCleanMergeAsFreshnessSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadCleanMergeAsFreshness",
        !.groupsClassified = FALSE,
        !.cleanMergeUsedAsFreshness = TRUE,
        !.modelFresh = TRUE,
        !.implementationScopeReopened = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeStaleModelReopenSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadStaleModelReopen",
        !.modelFresh = FALSE,
        !.implementationScopeReopened = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeTouchedGroupStaleSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadTouchedGroupStale",
        !.touchedGroupsFresh = FALSE,
        !.implementationScopeReopened = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeMissingClaimLedgerSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadMissingClaimLedger",
        !.claimLedgerPresent = FALSE,
        !.implementationScopeReopened = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeP5MissingPathClassificationSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadP5MissingPathClassification",
        !.p5PathClassificationPresent = FALSE,
        !.implementationScopeReopened = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeP5MissingNegativePlanSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadP5MissingNegativePlan",
        !.p5NegativePlanPresent = FALSE,
        !.implementationScopeReopened = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeBehaviorChangeFromDriftSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadBehaviorChangeFromDrift",
        !.behaviorChange = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRuntimeCoverageFromDriftSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadRuntimeCoverageFromDrift",
        !.runtimeCoverageClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeAbiFromDriftSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadAbiFromDrift",
        !.abiClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeMonitorVerificationFromDriftSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadMonitorVerificationFromDrift",
        !.monitorVerificationClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeProductionProtectionFromDriftSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadProductionProtectionFromDrift",
        !.productionProtectionClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeCostEfficiencyFromDriftSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadCostEfficiencyFromDrift",
        !.costEfficiencyClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

BoolFieldOK(f) == gate[f] \in BOOLEAN

TypeOK ==
    /\ DOMAIN gate = GateFields
    /\ gate.phase \in Phase
    /\ gate.slice \in Slice
    /\ BoolFieldOK("freshFetch")
    /\ BoolFieldOK("sourceDriftRun")
    /\ BoolFieldOK("exactCommitsRecorded")
    /\ BoolFieldOK("groupsClassified")
    /\ BoolFieldOK("mergeTreeChecked")
    /\ BoolFieldOK("mergeTreeClean")
    /\ BoolFieldOK("cleanMergeUsedAsFreshness")
    /\ BoolFieldOK("modelFresh")
    /\ BoolFieldOK("touchedGroupsFresh")
    /\ BoolFieldOK("claimLedgerPresent")
    /\ BoolFieldOK("sliceGatesPresent")
    /\ BoolFieldOK("p5PathClassificationPresent")
    /\ BoolFieldOK("p5NegativePlanPresent")
    /\ BoolFieldOK("implementationScopeReopened")
    /\ BoolFieldOK("linuxPatchApproved")
    /\ BoolFieldOK("behaviorChange")
    /\ BoolFieldOK("runtimeCoverageClaim")
    /\ BoolFieldOK("abiClaim")
    /\ BoolFieldOK("monitorVerificationClaim")
    /\ BoolFieldOK("productionProtectionClaim")
    /\ BoolFieldOK("costEfficiencyClaim")
    /\ BoolFieldOK("nonClaimsRecorded")

ObservationComplete ==
    /\ gate.freshFetch
    /\ gate.sourceDriftRun
    /\ gate.exactCommitsRecorded
    /\ gate.groupsClassified
    /\ gate.mergeTreeChecked

FreshnessComplete ==
    /\ ObservationComplete
    /\ gate.modelFresh
    /\ gate.touchedGroupsFresh
    /\ ~gate.cleanMergeUsedAsFreshness

ReopenPreconditions ==
    /\ FreshnessComplete
    /\ gate.claimLedgerPresent
    /\ gate.sliceGatesPresent
    /\ gate.nonClaimsRecorded
    /\ (gate.slice = "P5" => /\ gate.p5PathClassificationPresent
                              /\ gate.p5NegativePlanPresent)

NoReopenWithoutPreconditions ==
    gate.implementationScopeReopened => ReopenPreconditions

NoPatchWithoutReopen ==
    gate.linuxPatchApproved => gate.implementationScopeReopened

CleanMergeIsNotFreshness ==
    ~gate.cleanMergeUsedAsFreshness

NoBehaviorChangeFromDrift ==
    ~gate.behaviorChange

NoRuntimeCoverageFromDrift ==
    ~gate.runtimeCoverageClaim

NoAbiFromDrift ==
    ~gate.abiClaim

NoMonitorVerificationFromDrift ==
    ~gate.monitorVerificationClaim

NoProductionProtectionFromDrift ==
    ~gate.productionProtectionClaim

NoCostEfficiencyFromDrift ==
    ~gate.costEfficiencyClaim

Safety ==
    /\ TypeOK
    /\ NoReopenWithoutPreconditions
    /\ NoPatchWithoutReopen
    /\ CleanMergeIsNotFreshness
    /\ NoBehaviorChangeFromDrift
    /\ NoRuntimeCoverageFromDrift
    /\ NoAbiFromDrift
    /\ NoMonitorVerificationFromDrift
    /\ NoProductionProtectionFromDrift
    /\ NoCostEfficiencyFromDrift

====
