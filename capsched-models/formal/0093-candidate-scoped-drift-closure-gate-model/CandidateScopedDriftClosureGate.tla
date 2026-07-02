---------- MODULE CandidateScopedDriftClosureGate ----------
EXTENDS Naturals

VARIABLE gate

vars == <<gate>>

Candidate == {"P4SchedulerAllowAll"}

Phase == {
    "CandidateScopeChecked",
    "BadUnknownScope",
    "BadCloseWithoutFreshFetch",
    "BadCloseWithoutSourceRun",
    "BadCloseWithoutWatchPathExistence",
    "BadCloseWithFootprintMismatch",
    "BadCloseWithCandidateStale",
    "BadCloseWithoutNonCandidateRecord",
    "BadGlobalFreshFromScopedGate",
    "BadImplementationWithoutAnchors",
    "BadRuntimeDenialFromP4",
    "BadRuntimeCoverageFromScopedGate",
    "BadMonitorVerificationFromScopedGate",
    "BadProtectionFromScopedGate",
    "BadCostEfficiencyFromScopedGate"
}

GateFields == {
    "phase",
    "candidate",
    "candidateScopeKnown",
    "freshFetch",
    "sourceDriftRun",
    "exactCommitsRecorded",
    "watchPathExistenceChecked",
    "patchFootprintMatchesActual",
    "groupsClassified",
    "mergeTreeChecked",
    "mergeTreeClean",
    "cleanMergeUsedAsFreshness",
    "globalModelFresh",
    "staleGroupsExist",
    "staleGroupsInCandidateScope",
    "touchedGroupsFresh",
    "claimGroupsFresh",
    "nonCandidateStaleRecorded",
    "nonCandidateStaleBlocksBroadClaims",
    "candidateScopeDriftClosed",
    "globalAllAnglesFreshClaim",
    "claimLedgerPresent",
    "nonClaimsRecorded",
    "finalRunAnchorManifestPresent",
    "queuedMoveAnchorManifestPresent",
    "anchorObservabilityPresent",
    "p4ImplementationApproved",
    "p4RuntimeDenialApproved",
    "runtimeCoverageClaim",
    "monitorVerificationClaim",
    "productionProtectionClaim",
    "hypervisorGradeClaim",
    "costEfficiencyClaim",
    "deploymentReadinessClaim"
}

BaseGate == [
    phase |-> "CandidateScopeChecked",
    candidate |-> "P4SchedulerAllowAll",
    candidateScopeKnown |-> TRUE,
    freshFetch |-> TRUE,
    sourceDriftRun |-> TRUE,
    exactCommitsRecorded |-> TRUE,
    watchPathExistenceChecked |-> TRUE,
    patchFootprintMatchesActual |-> TRUE,
    groupsClassified |-> TRUE,
    mergeTreeChecked |-> TRUE,
    mergeTreeClean |-> TRUE,
    cleanMergeUsedAsFreshness |-> FALSE,
    globalModelFresh |-> FALSE,
    staleGroupsExist |-> TRUE,
    staleGroupsInCandidateScope |-> FALSE,
    touchedGroupsFresh |-> TRUE,
    claimGroupsFresh |-> TRUE,
    nonCandidateStaleRecorded |-> TRUE,
    nonCandidateStaleBlocksBroadClaims |-> TRUE,
    candidateScopeDriftClosed |-> TRUE,
    globalAllAnglesFreshClaim |-> FALSE,
    claimLedgerPresent |-> TRUE,
    nonClaimsRecorded |-> TRUE,
    finalRunAnchorManifestPresent |-> FALSE,
    queuedMoveAnchorManifestPresent |-> FALSE,
    anchorObservabilityPresent |-> FALSE,
    p4ImplementationApproved |-> FALSE,
    p4RuntimeDenialApproved |-> FALSE,
    runtimeCoverageClaim |-> FALSE,
    monitorVerificationClaim |-> FALSE,
    productionProtectionClaim |-> FALSE,
    hypervisorGradeClaim |-> FALSE,
    costEfficiencyClaim |-> FALSE,
    deploymentReadinessClaim |-> FALSE
]

Init == gate = BaseGate

Spec == Init /\ [][UNCHANGED gate]_vars

UnsafeUnknownScopeSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadUnknownScope",
        !.candidateScopeKnown = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeCloseWithoutFreshFetchSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadCloseWithoutFreshFetch",
        !.freshFetch = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeCloseWithoutSourceRunSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadCloseWithoutSourceRun",
        !.sourceDriftRun = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeCloseWithoutWatchPathExistenceSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadCloseWithoutWatchPathExistence",
        !.watchPathExistenceChecked = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeCloseWithFootprintMismatchSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadCloseWithFootprintMismatch",
        !.patchFootprintMatchesActual = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeCloseWithCandidateStaleSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadCloseWithCandidateStale",
        !.staleGroupsInCandidateScope = TRUE,
        !.touchedGroupsFresh = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeCloseWithoutNonCandidateRecordSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadCloseWithoutNonCandidateRecord",
        !.nonCandidateStaleRecorded = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeGlobalFreshFromScopedGateSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadGlobalFreshFromScopedGate",
        !.globalAllAnglesFreshClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeImplementationWithoutAnchorsSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadImplementationWithoutAnchors",
        !.p4ImplementationApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRuntimeDenialFromP4Spec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadRuntimeDenialFromP4",
        !.p4RuntimeDenialApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRuntimeCoverageFromScopedGateSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadRuntimeCoverageFromScopedGate",
        !.runtimeCoverageClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeMonitorVerificationFromScopedGateSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadMonitorVerificationFromScopedGate",
        !.monitorVerificationClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeProtectionFromScopedGateSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadProtectionFromScopedGate",
        !.productionProtectionClaim = TRUE,
        !.hypervisorGradeClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeCostEfficiencyFromScopedGateSpec ==
    gate = [BaseGate EXCEPT
        !.phase = "BadCostEfficiencyFromScopedGate",
        !.costEfficiencyClaim = TRUE,
        !.deploymentReadinessClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

BoolFieldOK(f) == gate[f] \in BOOLEAN

TypeOK ==
    /\ DOMAIN gate = GateFields
    /\ gate.phase \in Phase
    /\ gate.candidate \in Candidate
    /\ BoolFieldOK("candidateScopeKnown")
    /\ BoolFieldOK("freshFetch")
    /\ BoolFieldOK("sourceDriftRun")
    /\ BoolFieldOK("exactCommitsRecorded")
    /\ BoolFieldOK("watchPathExistenceChecked")
    /\ BoolFieldOK("patchFootprintMatchesActual")
    /\ BoolFieldOK("groupsClassified")
    /\ BoolFieldOK("mergeTreeChecked")
    /\ BoolFieldOK("mergeTreeClean")
    /\ BoolFieldOK("cleanMergeUsedAsFreshness")
    /\ BoolFieldOK("globalModelFresh")
    /\ BoolFieldOK("staleGroupsExist")
    /\ BoolFieldOK("staleGroupsInCandidateScope")
    /\ BoolFieldOK("touchedGroupsFresh")
    /\ BoolFieldOK("claimGroupsFresh")
    /\ BoolFieldOK("nonCandidateStaleRecorded")
    /\ BoolFieldOK("nonCandidateStaleBlocksBroadClaims")
    /\ BoolFieldOK("candidateScopeDriftClosed")
    /\ BoolFieldOK("globalAllAnglesFreshClaim")
    /\ BoolFieldOK("claimLedgerPresent")
    /\ BoolFieldOK("nonClaimsRecorded")
    /\ BoolFieldOK("finalRunAnchorManifestPresent")
    /\ BoolFieldOK("queuedMoveAnchorManifestPresent")
    /\ BoolFieldOK("anchorObservabilityPresent")
    /\ BoolFieldOK("p4ImplementationApproved")
    /\ BoolFieldOK("p4RuntimeDenialApproved")
    /\ BoolFieldOK("runtimeCoverageClaim")
    /\ BoolFieldOK("monitorVerificationClaim")
    /\ BoolFieldOK("productionProtectionClaim")
    /\ BoolFieldOK("hypervisorGradeClaim")
    /\ BoolFieldOK("costEfficiencyClaim")
    /\ BoolFieldOK("deploymentReadinessClaim")

ObservationComplete ==
    /\ gate.freshFetch
    /\ gate.sourceDriftRun
    /\ gate.exactCommitsRecorded
    /\ gate.watchPathExistenceChecked
    /\ gate.patchFootprintMatchesActual
    /\ gate.groupsClassified
    /\ gate.mergeTreeChecked
    /\ ~gate.cleanMergeUsedAsFreshness

CandidateGroupsFresh ==
    /\ gate.candidateScopeKnown
    /\ gate.touchedGroupsFresh
    /\ gate.claimGroupsFresh
    /\ ~gate.staleGroupsInCandidateScope

NonCandidateStaleHandled ==
    (gate.staleGroupsExist /\ ~gate.globalModelFresh /\ gate.candidateScopeDriftClosed) =>
        /\ gate.nonCandidateStaleRecorded
        /\ gate.nonCandidateStaleBlocksBroadClaims
        /\ ~gate.globalAllAnglesFreshClaim

ScopedDriftPreconditions ==
    /\ ObservationComplete
    /\ CandidateGroupsFresh
    /\ gate.claimLedgerPresent
    /\ gate.nonClaimsRecorded
    /\ NonCandidateStaleHandled

NoScopedDriftClosureWithoutPreconditions ==
    gate.candidateScopeDriftClosed => ScopedDriftPreconditions

NoImplementationApprovalWithoutAnchors ==
    gate.p4ImplementationApproved =>
        /\ gate.candidateScopeDriftClosed
        /\ gate.finalRunAnchorManifestPresent
        /\ gate.queuedMoveAnchorManifestPresent
        /\ gate.anchorObservabilityPresent

ScopedDriftDoesNotProveGlobalFreshness ==
    (gate.candidateScopeDriftClosed /\ gate.staleGroupsExist /\ ~gate.globalModelFresh) =>
        ~gate.globalAllAnglesFreshClaim

NoP4RuntimeDenialFromScopedDrift ==
    ~gate.p4RuntimeDenialApproved

NoRuntimeCoverageClaimFromScopedDrift ==
    ~gate.runtimeCoverageClaim

NoMonitorVerificationClaimFromScopedDrift ==
    ~gate.monitorVerificationClaim

NoProtectionClaimFromScopedDrift ==
    /\ ~gate.productionProtectionClaim
    /\ ~gate.hypervisorGradeClaim

NoCostOrDeploymentClaimFromScopedDrift ==
    /\ ~gate.costEfficiencyClaim
    /\ ~gate.deploymentReadinessClaim

CleanMergeIsNotFreshness ==
    ~gate.cleanMergeUsedAsFreshness

Safety ==
    /\ TypeOK
    /\ NoScopedDriftClosureWithoutPreconditions
    /\ NoImplementationApprovalWithoutAnchors
    /\ ScopedDriftDoesNotProveGlobalFreshness
    /\ NoP4RuntimeDenialFromScopedDrift
    /\ NoRuntimeCoverageClaimFromScopedDrift
    /\ NoMonitorVerificationClaimFromScopedDrift
    /\ NoProtectionClaimFromScopedDrift
    /\ NoCostOrDeploymentClaimFromScopedDrift
    /\ CleanMergeIsNotFreshness

====
