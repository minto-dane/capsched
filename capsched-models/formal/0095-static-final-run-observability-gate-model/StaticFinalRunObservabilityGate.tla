---------- MODULE StaticFinalRunObservabilityGate ----------
EXTENDS Naturals

VARIABLE gate

vars == <<gate>>

Phase == {
    "StaticFinalRunObserved",
    "BadNoSourceCheck",
    "BadNoStaticAnchor",
    "BadStaticAnchorAfterRqCurr",
    "BadP3MarkerAsPrecommit",
    "BadRuntimeCoverageFromStatic",
    "BadImplementationFromStatic",
    "BadRuntimeDenialFromStatic",
    "BadProtectionFromStatic",
    "BadCostEfficiencyFromStatic"
}

GateFields == {
    "phase",
    "sourceChecked",
    "workCommitMatches",
    "staticAnchorFound",
    "staticAnchorBeforeRqCurr",
    "staticAnchorBeforeContextSwitch",
    "p3MarkerFound",
    "p3MarkerAfterRqCurr",
    "p3MarkerBeforeContextSwitch",
    "p3MarkerUsedAsPrecommitAnchor",
    "staticFinalRunObservabilityClosed",
    "runtimeFinalRunCoverageProven",
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
    phase |-> "StaticFinalRunObserved",
    sourceChecked |-> TRUE,
    workCommitMatches |-> TRUE,
    staticAnchorFound |-> TRUE,
    staticAnchorBeforeRqCurr |-> TRUE,
    staticAnchorBeforeContextSwitch |-> TRUE,
    p3MarkerFound |-> TRUE,
    p3MarkerAfterRqCurr |-> TRUE,
    p3MarkerBeforeContextSwitch |-> TRUE,
    p3MarkerUsedAsPrecommitAnchor |-> FALSE,
    staticFinalRunObservabilityClosed |-> TRUE,
    runtimeFinalRunCoverageProven |-> FALSE,
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

UnsafeNoSourceCheckSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadNoSourceCheck",
                            !.sourceChecked = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeNoStaticAnchorSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadNoStaticAnchor",
                            !.staticAnchorFound = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeStaticAnchorAfterRqCurrSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadStaticAnchorAfterRqCurr",
                            !.staticAnchorBeforeRqCurr = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeP3MarkerAsPrecommitSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadP3MarkerAsPrecommit",
                            !.p3MarkerUsedAsPrecommitAnchor = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRuntimeCoverageFromStaticSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadRuntimeCoverageFromStatic",
                            !.runtimeFinalRunCoverageProven = TRUE,
                            !.runtimeCoverageClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeImplementationFromStaticSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadImplementationFromStatic",
                            !.p4ImplementationApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRuntimeDenialFromStaticSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadRuntimeDenialFromStatic",
                            !.runtimeDenialApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeProtectionFromStaticSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadProtectionFromStatic",
                            !.productionProtectionClaim = TRUE,
                            !.hypervisorGradeClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeCostEfficiencyFromStaticSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadCostEfficiencyFromStatic",
                            !.costEfficiencyClaim = TRUE,
                            !.deploymentReadinessClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

BoolFieldOK(f) == gate[f] \in BOOLEAN

TypeOK ==
    /\ DOMAIN gate = GateFields
    /\ gate.phase \in Phase
    /\ BoolFieldOK("sourceChecked")
    /\ BoolFieldOK("workCommitMatches")
    /\ BoolFieldOK("staticAnchorFound")
    /\ BoolFieldOK("staticAnchorBeforeRqCurr")
    /\ BoolFieldOK("staticAnchorBeforeContextSwitch")
    /\ BoolFieldOK("p3MarkerFound")
    /\ BoolFieldOK("p3MarkerAfterRqCurr")
    /\ BoolFieldOK("p3MarkerBeforeContextSwitch")
    /\ BoolFieldOK("p3MarkerUsedAsPrecommitAnchor")
    /\ BoolFieldOK("staticFinalRunObservabilityClosed")
    /\ BoolFieldOK("runtimeFinalRunCoverageProven")
    /\ BoolFieldOK("p4ImplementationApproved")
    /\ BoolFieldOK("runtimeDenialApproved")
    /\ BoolFieldOK("runtimeCoverageClaim")
    /\ BoolFieldOK("monitorVerificationClaim")
    /\ BoolFieldOK("productionProtectionClaim")
    /\ BoolFieldOK("hypervisorGradeClaim")
    /\ BoolFieldOK("costEfficiencyClaim")
    /\ BoolFieldOK("deploymentReadinessClaim")
    /\ BoolFieldOK("nonClaimsRecorded")

StaticObservabilityPreconditions ==
    /\ gate.sourceChecked
    /\ gate.workCommitMatches
    /\ gate.staticAnchorFound
    /\ gate.staticAnchorBeforeRqCurr
    /\ gate.staticAnchorBeforeContextSwitch
    /\ gate.p3MarkerFound
    /\ gate.p3MarkerAfterRqCurr
    /\ gate.p3MarkerBeforeContextSwitch
    /\ ~gate.p3MarkerUsedAsPrecommitAnchor
    /\ gate.nonClaimsRecorded

NoCloseWithoutStaticPreconditions ==
    gate.staticFinalRunObservabilityClosed => StaticObservabilityPreconditions

StaticDoesNotProveRuntimeCoverage ==
    /\ ~gate.runtimeFinalRunCoverageProven
    /\ ~gate.runtimeCoverageClaim

NoImplementationApprovalFromStatic ==
    ~gate.p4ImplementationApproved

NoRuntimeDenialFromStatic ==
    ~gate.runtimeDenialApproved

NoMonitorOrProtectionClaimFromStatic ==
    /\ ~gate.monitorVerificationClaim
    /\ ~gate.productionProtectionClaim
    /\ ~gate.hypervisorGradeClaim

NoCostOrDeploymentClaimFromStatic ==
    /\ ~gate.costEfficiencyClaim
    /\ ~gate.deploymentReadinessClaim

Safety ==
    /\ TypeOK
    /\ NoCloseWithoutStaticPreconditions
    /\ StaticDoesNotProveRuntimeCoverage
    /\ NoImplementationApprovalFromStatic
    /\ NoRuntimeDenialFromStatic
    /\ NoMonitorOrProtectionClaimFromStatic
    /\ NoCostOrDeploymentClaimFromStatic

====
