---------- MODULE P4AnchorManifestGate ----------
EXTENDS Naturals

VARIABLE gate

vars == <<gate>>

Phase == {
    "AnchorManifestChecked",
    "BadMissingFinalRunAnchor",
    "BadMissingCommonMoveAnchor",
    "BadMissingLockedMoveAnchor",
    "BadFinalRunAfterRqCurr",
    "BadMoveAfterDetach",
    "BadMoveAfterCpuMutation",
    "BadMissingNonCoverage",
    "BadImplementationFromManifest",
    "BadRuntimeDenialFromManifest",
    "BadRuntimeCoverageFromManifest",
    "BadProtectionFromManifest",
    "BadCostEfficiencyFromManifest"
}

GateFields == {
    "phase",
    "manifestPresent",
    "sourceChecked",
    "workCommitMatches",
    "finalRunAnchorPresent",
    "commonMoveAnchorPresent",
    "lockedMoveAnchorPresent",
    "finalRunBeforeRqCurr",
    "finalRunAfterPickProxyResolution",
    "finalRunP5DenialSafe",
    "commonMoveBeforeDetach",
    "commonMoveBeforeCpuMutation",
    "lockedMoveBeforeDetach",
    "lockedMoveBeforeCpuMutation",
    "explicitNonCoverageRecorded",
    "allowAllOnly",
    "p4ImplementationApproved",
    "runtimeDenialApproved",
    "runtimeCoverageClaim",
    "monitorVerificationClaim",
    "productionProtectionClaim",
    "hypervisorGradeClaim",
    "costEfficiencyClaim",
    "deploymentReadinessClaim",
    "nonClaimsRecorded"
}

BaseGate == [
    phase |-> "AnchorManifestChecked",
    manifestPresent |-> TRUE,
    sourceChecked |-> TRUE,
    workCommitMatches |-> TRUE,
    finalRunAnchorPresent |-> TRUE,
    commonMoveAnchorPresent |-> TRUE,
    lockedMoveAnchorPresent |-> TRUE,
    finalRunBeforeRqCurr |-> TRUE,
    finalRunAfterPickProxyResolution |-> TRUE,
    finalRunP5DenialSafe |-> FALSE,
    commonMoveBeforeDetach |-> TRUE,
    commonMoveBeforeCpuMutation |-> TRUE,
    lockedMoveBeforeDetach |-> TRUE,
    lockedMoveBeforeCpuMutation |-> TRUE,
    explicitNonCoverageRecorded |-> TRUE,
    allowAllOnly |-> TRUE,
    p4ImplementationApproved |-> FALSE,
    runtimeDenialApproved |-> FALSE,
    runtimeCoverageClaim |-> FALSE,
    monitorVerificationClaim |-> FALSE,
    productionProtectionClaim |-> FALSE,
    hypervisorGradeClaim |-> FALSE,
    costEfficiencyClaim |-> FALSE,
    deploymentReadinessClaim |-> FALSE,
    nonClaimsRecorded |-> TRUE
]

Init == gate = BaseGate

Spec == Init /\ [][UNCHANGED gate]_vars

UnsafeMissingFinalRunAnchorSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadMissingFinalRunAnchor",
                            !.finalRunAnchorPresent = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeMissingCommonMoveAnchorSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadMissingCommonMoveAnchor",
                            !.commonMoveAnchorPresent = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeMissingLockedMoveAnchorSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadMissingLockedMoveAnchor",
                            !.lockedMoveAnchorPresent = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeFinalRunAfterRqCurrSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadFinalRunAfterRqCurr",
                            !.finalRunBeforeRqCurr = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeMoveAfterDetachSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadMoveAfterDetach",
                            !.commonMoveBeforeDetach = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeMoveAfterCpuMutationSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadMoveAfterCpuMutation",
                            !.lockedMoveBeforeCpuMutation = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeMissingNonCoverageSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadMissingNonCoverage",
                            !.explicitNonCoverageRecorded = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeImplementationFromManifestSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadImplementationFromManifest",
                            !.p4ImplementationApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRuntimeDenialFromManifestSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadRuntimeDenialFromManifest",
                            !.runtimeDenialApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRuntimeCoverageFromManifestSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadRuntimeCoverageFromManifest",
                            !.runtimeCoverageClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeProtectionFromManifestSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadProtectionFromManifest",
                            !.productionProtectionClaim = TRUE,
                            !.hypervisorGradeClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeCostEfficiencyFromManifestSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadCostEfficiencyFromManifest",
                            !.costEfficiencyClaim = TRUE,
                            !.deploymentReadinessClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

BoolFieldOK(f) == gate[f] \in BOOLEAN

TypeOK ==
    /\ DOMAIN gate = GateFields
    /\ gate.phase \in Phase
    /\ BoolFieldOK("manifestPresent")
    /\ BoolFieldOK("sourceChecked")
    /\ BoolFieldOK("workCommitMatches")
    /\ BoolFieldOK("finalRunAnchorPresent")
    /\ BoolFieldOK("commonMoveAnchorPresent")
    /\ BoolFieldOK("lockedMoveAnchorPresent")
    /\ BoolFieldOK("finalRunBeforeRqCurr")
    /\ BoolFieldOK("finalRunAfterPickProxyResolution")
    /\ BoolFieldOK("finalRunP5DenialSafe")
    /\ BoolFieldOK("commonMoveBeforeDetach")
    /\ BoolFieldOK("commonMoveBeforeCpuMutation")
    /\ BoolFieldOK("lockedMoveBeforeDetach")
    /\ BoolFieldOK("lockedMoveBeforeCpuMutation")
    /\ BoolFieldOK("explicitNonCoverageRecorded")
    /\ BoolFieldOK("allowAllOnly")
    /\ BoolFieldOK("p4ImplementationApproved")
    /\ BoolFieldOK("runtimeDenialApproved")
    /\ BoolFieldOK("runtimeCoverageClaim")
    /\ BoolFieldOK("monitorVerificationClaim")
    /\ BoolFieldOK("productionProtectionClaim")
    /\ BoolFieldOK("hypervisorGradeClaim")
    /\ BoolFieldOK("costEfficiencyClaim")
    /\ BoolFieldOK("deploymentReadinessClaim")
    /\ BoolFieldOK("nonClaimsRecorded")

RequiredAnchorsPresent ==
    /\ gate.finalRunAnchorPresent
    /\ gate.commonMoveAnchorPresent
    /\ gate.lockedMoveAnchorPresent

AnchorOrderingOK ==
    /\ gate.finalRunBeforeRqCurr
    /\ gate.finalRunAfterPickProxyResolution
    /\ gate.commonMoveBeforeDetach
    /\ gate.commonMoveBeforeCpuMutation
    /\ gate.lockedMoveBeforeDetach
    /\ gate.lockedMoveBeforeCpuMutation

ManifestSound ==
    /\ gate.manifestPresent
    /\ gate.sourceChecked
    /\ gate.workCommitMatches
    /\ RequiredAnchorsPresent
    /\ AnchorOrderingOK
    /\ gate.explicitNonCoverageRecorded
    /\ gate.allowAllOnly
    /\ gate.nonClaimsRecorded

NoImplementationApprovalFromManifest ==
    gate.p4ImplementationApproved => FALSE

NoRuntimeDenialFromManifest ==
    ~gate.runtimeDenialApproved

NoP5DenialSafetyClaim ==
    ~gate.finalRunP5DenialSafe

NoRuntimeCoverageClaimFromManifest ==
    ~gate.runtimeCoverageClaim

NoMonitorOrProtectionClaimFromManifest ==
    /\ ~gate.monitorVerificationClaim
    /\ ~gate.productionProtectionClaim
    /\ ~gate.hypervisorGradeClaim

NoCostOrDeploymentClaimFromManifest ==
    /\ ~gate.costEfficiencyClaim
    /\ ~gate.deploymentReadinessClaim

Safety ==
    /\ TypeOK
    /\ ManifestSound
    /\ NoImplementationApprovalFromManifest
    /\ NoRuntimeDenialFromManifest
    /\ NoP5DenialSafetyClaim
    /\ NoRuntimeCoverageClaimFromManifest
    /\ NoMonitorOrProtectionClaimFromManifest
    /\ NoCostOrDeploymentClaimFromManifest

====
