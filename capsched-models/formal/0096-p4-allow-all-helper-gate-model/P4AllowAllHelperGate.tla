---------- MODULE P4AllowAllHelperGate ----------
EXTENDS Naturals

VARIABLE gate

vars == <<gate>>

Phase == {
    "AllowAllHelperChecked",
    "BadNoSourceCheck",
    "BadHelperReturnsRetry",
    "BadHelperReturnsIneligible",
    "BadHelperReturnsQuarantine",
    "BadNonAllowReachable",
    "BadSchedulerBranchesOnResult",
    "BadRetryBehavior",
    "BadQuarantineBehavior",
    "BadMonitorCall",
    "BadBudgetCharge",
    "BadAbi",
    "BadImplementationFromHelperProof",
    "BadRuntimeCoverageFromHelperProof",
    "BadProtectionFromHelperProof",
    "BadCostEfficiencyFromHelperProof"
}

GateFields == {
    "phase",
    "sourceChecked",
    "workCommitMatches",
    "allowHelperExists",
    "allowHelperReturnsAllow",
    "helperReturnsRetry",
    "helperReturnsIneligible",
    "helperReturnsQuarantine",
    "nonAllowEnumExists",
    "nonAllowReachableInP4",
    "schedulerBranchesOnValidationResult",
    "retryBehaviorReachable",
    "ineligibleMarkReachable",
    "quarantineReachable",
    "failClosedReachable",
    "monitorCallReachable",
    "budgetChargeReachable",
    "abiAdded",
    "allowAllHelperProofClosed",
    "noReachableDenialPathProofClosed",
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
    phase |-> "AllowAllHelperChecked",
    sourceChecked |-> TRUE,
    workCommitMatches |-> TRUE,
    allowHelperExists |-> TRUE,
    allowHelperReturnsAllow |-> TRUE,
    helperReturnsRetry |-> FALSE,
    helperReturnsIneligible |-> FALSE,
    helperReturnsQuarantine |-> FALSE,
    nonAllowEnumExists |-> TRUE,
    nonAllowReachableInP4 |-> FALSE,
    schedulerBranchesOnValidationResult |-> FALSE,
    retryBehaviorReachable |-> FALSE,
    ineligibleMarkReachable |-> FALSE,
    quarantineReachable |-> FALSE,
    failClosedReachable |-> FALSE,
    monitorCallReachable |-> FALSE,
    budgetChargeReachable |-> FALSE,
    abiAdded |-> FALSE,
    allowAllHelperProofClosed |-> TRUE,
    noReachableDenialPathProofClosed |-> TRUE,
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

UnsafeHelperReturnsRetrySpec ==
    gate = [BaseGate EXCEPT !.phase = "BadHelperReturnsRetry",
                            !.helperReturnsRetry = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeHelperReturnsIneligibleSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadHelperReturnsIneligible",
                            !.helperReturnsIneligible = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeHelperReturnsQuarantineSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadHelperReturnsQuarantine",
                            !.helperReturnsQuarantine = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeNonAllowReachableSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadNonAllowReachable",
                            !.nonAllowReachableInP4 = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeSchedulerBranchesOnResultSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadSchedulerBranchesOnResult",
                            !.schedulerBranchesOnValidationResult = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRetryBehaviorSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadRetryBehavior",
                            !.retryBehaviorReachable = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeQuarantineBehaviorSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadQuarantineBehavior",
                            !.quarantineReachable = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeMonitorCallSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadMonitorCall",
                            !.monitorCallReachable = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeBudgetChargeSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadBudgetCharge",
                            !.budgetChargeReachable = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeAbiSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadAbi",
                            !.abiAdded = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeImplementationFromHelperProofSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadImplementationFromHelperProof",
                            !.p4ImplementationApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRuntimeCoverageFromHelperProofSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadRuntimeCoverageFromHelperProof",
                            !.runtimeCoverageClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeProtectionFromHelperProofSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadProtectionFromHelperProof",
                            !.productionProtectionClaim = TRUE,
                            !.hypervisorGradeClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeCostEfficiencyFromHelperProofSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadCostEfficiencyFromHelperProof",
                            !.costEfficiencyClaim = TRUE,
                            !.deploymentReadinessClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

BoolFieldOK(f) == gate[f] \in BOOLEAN

TypeOK ==
    /\ DOMAIN gate = GateFields
    /\ gate.phase \in Phase
    /\ BoolFieldOK("sourceChecked")
    /\ BoolFieldOK("workCommitMatches")
    /\ BoolFieldOK("allowHelperExists")
    /\ BoolFieldOK("allowHelperReturnsAllow")
    /\ BoolFieldOK("helperReturnsRetry")
    /\ BoolFieldOK("helperReturnsIneligible")
    /\ BoolFieldOK("helperReturnsQuarantine")
    /\ BoolFieldOK("nonAllowEnumExists")
    /\ BoolFieldOK("nonAllowReachableInP4")
    /\ BoolFieldOK("schedulerBranchesOnValidationResult")
    /\ BoolFieldOK("retryBehaviorReachable")
    /\ BoolFieldOK("ineligibleMarkReachable")
    /\ BoolFieldOK("quarantineReachable")
    /\ BoolFieldOK("failClosedReachable")
    /\ BoolFieldOK("monitorCallReachable")
    /\ BoolFieldOK("budgetChargeReachable")
    /\ BoolFieldOK("abiAdded")
    /\ BoolFieldOK("allowAllHelperProofClosed")
    /\ BoolFieldOK("noReachableDenialPathProofClosed")
    /\ BoolFieldOK("p4ImplementationApproved")
    /\ BoolFieldOK("runtimeDenialApproved")
    /\ BoolFieldOK("runtimeCoverageClaim")
    /\ BoolFieldOK("monitorVerificationClaim")
    /\ BoolFieldOK("productionProtectionClaim")
    /\ BoolFieldOK("hypervisorGradeClaim")
    /\ BoolFieldOK("costEfficiencyClaim")
    /\ BoolFieldOK("deploymentReadinessClaim")
    /\ BoolFieldOK("nonClaimsRecorded")

AllowAllProofPreconditions ==
    /\ gate.sourceChecked
    /\ gate.workCommitMatches
    /\ gate.allowHelperExists
    /\ gate.allowHelperReturnsAllow
    /\ ~gate.helperReturnsRetry
    /\ ~gate.helperReturnsIneligible
    /\ ~gate.helperReturnsQuarantine
    /\ gate.nonAllowEnumExists
    /\ ~gate.nonAllowReachableInP4
    /\ ~gate.schedulerBranchesOnValidationResult
    /\ gate.nonClaimsRecorded

NoDenialPathReachable ==
    /\ ~gate.retryBehaviorReachable
    /\ ~gate.ineligibleMarkReachable
    /\ ~gate.quarantineReachable
    /\ ~gate.failClosedReachable
    /\ ~gate.runtimeDenialApproved

NoAuthoritySideEffects ==
    /\ ~gate.monitorCallReachable
    /\ ~gate.budgetChargeReachable
    /\ ~gate.abiAdded

NoCloseWithoutPreconditions ==
    /\ gate.allowAllHelperProofClosed => AllowAllProofPreconditions
    /\ gate.noReachableDenialPathProofClosed => NoDenialPathReachable

NoImplementationApprovalFromHelperProof ==
    ~gate.p4ImplementationApproved

NoRuntimeCoverageClaimFromHelperProof ==
    ~gate.runtimeCoverageClaim

NoMonitorOrProtectionClaimFromHelperProof ==
    /\ ~gate.monitorVerificationClaim
    /\ ~gate.productionProtectionClaim
    /\ ~gate.hypervisorGradeClaim

NoCostOrDeploymentClaimFromHelperProof ==
    /\ ~gate.costEfficiencyClaim
    /\ ~gate.deploymentReadinessClaim

Safety ==
    /\ TypeOK
    /\ NoCloseWithoutPreconditions
    /\ NoDenialPathReachable
    /\ NoAuthoritySideEffects
    /\ NoImplementationApprovalFromHelperProof
    /\ NoRuntimeCoverageClaimFromHelperProof
    /\ NoMonitorOrProtectionClaimFromHelperProof
    /\ NoCostOrDeploymentClaimFromHelperProof

====
