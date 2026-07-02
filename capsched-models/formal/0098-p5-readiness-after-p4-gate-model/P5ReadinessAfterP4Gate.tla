---------- MODULE P5ReadinessAfterP4Gate ----------

VARIABLE gate

vars == <<gate>>

Phase == {
    "P5BlockedAfterP4",
    "BadNoSourceCheck",
    "BadRunDenyAtCurrentP4Hook",
    "BadP5ApprovedWithPostSettleRunHook",
    "BadP5ApprovedWithoutMoveStatus",
    "BadP5ApprovedWithoutNegativeTests",
    "BadP5ApprovedWithoutPathClassification",
    "BadRuntimeCoverageClaim",
    "BadProtectionClaim",
    "BadCostOrDeploymentClaim"
}

GateFields == {
    "phase",
    "sourceChecked",
    "linuxHeadMatchesP4",
    "p4Closed",
    "p4HelpersAllowOnly",
    "schedulerBranchesOnValidationResult",
    "runHookBeforeRqCurr",
    "runHookBeforeContextSwitch",
    "runHookPreClassSettle",
    "runRollbackProved",
    "runDenyAtCurrentP4Hook",
    "moveHooksBeforeMutation",
    "moveStatusPlumbing",
    "negativeTestsDesigned",
    "pathClassificationFresh",
    "unsupportedPathClaims",
    "p5Approved",
    "runtimeDenialApproved",
    "runtimeCoverageClaim",
    "monitorVerificationClaim",
    "productionProtectionClaim",
    "hypervisorGradeClaim",
    "costEfficiencyClaim",
    "deploymentReadinessClaim",
    "p5Blocked",
    "nonClaimsRecorded"
}

BaseGate == [
    phase |-> "P5BlockedAfterP4",
    sourceChecked |-> TRUE,
    linuxHeadMatchesP4 |-> TRUE,
    p4Closed |-> TRUE,
    p4HelpersAllowOnly |-> TRUE,
    schedulerBranchesOnValidationResult |-> FALSE,
    runHookBeforeRqCurr |-> TRUE,
    runHookBeforeContextSwitch |-> TRUE,
    runHookPreClassSettle |-> FALSE,
    runRollbackProved |-> FALSE,
    runDenyAtCurrentP4Hook |-> FALSE,
    moveHooksBeforeMutation |-> TRUE,
    moveStatusPlumbing |-> FALSE,
    negativeTestsDesigned |-> FALSE,
    pathClassificationFresh |-> TRUE,
    unsupportedPathClaims |-> FALSE,
    p5Approved |-> FALSE,
    runtimeDenialApproved |-> FALSE,
    runtimeCoverageClaim |-> FALSE,
    monitorVerificationClaim |-> FALSE,
    productionProtectionClaim |-> FALSE,
    hypervisorGradeClaim |-> FALSE,
    costEfficiencyClaim |-> FALSE,
    deploymentReadinessClaim |-> FALSE,
    p5Blocked |-> TRUE,
    nonClaimsRecorded |-> TRUE
]

Init == gate = BaseGate

Spec == Init /\ [][UNCHANGED gate]_vars

UnsafeNoSourceCheckSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadNoSourceCheck",
                            !.sourceChecked = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeRunDenyAtCurrentP4HookSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadRunDenyAtCurrentP4Hook",
                            !.runDenyAtCurrentP4Hook = TRUE,
                            !.runtimeDenialApproved = TRUE,
                            !.p5Approved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeP5ApprovedWithPostSettleRunHookSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadP5ApprovedWithPostSettleRunHook",
                            !.p5Approved = TRUE,
                            !.runtimeDenialApproved = TRUE,
                            !.p5Blocked = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeP5ApprovedWithoutMoveStatusSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadP5ApprovedWithoutMoveStatus",
                            !.runHookPreClassSettle = TRUE,
                            !.negativeTestsDesigned = TRUE,
                            !.p5Approved = TRUE,
                            !.runtimeDenialApproved = TRUE,
                            !.p5Blocked = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeP5ApprovedWithoutNegativeTestsSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadP5ApprovedWithoutNegativeTests",
                            !.runHookPreClassSettle = TRUE,
                            !.moveStatusPlumbing = TRUE,
                            !.p5Approved = TRUE,
                            !.runtimeDenialApproved = TRUE,
                            !.p5Blocked = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeP5ApprovedWithoutPathClassificationSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadP5ApprovedWithoutPathClassification",
                            !.runHookPreClassSettle = TRUE,
                            !.moveStatusPlumbing = TRUE,
                            !.negativeTestsDesigned = TRUE,
                            !.pathClassificationFresh = FALSE,
                            !.p5Approved = TRUE,
                            !.runtimeDenialApproved = TRUE,
                            !.p5Blocked = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeRuntimeCoverageClaimSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadRuntimeCoverageClaim",
                            !.runtimeCoverageClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeProtectionClaimSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadProtectionClaim",
                            !.monitorVerificationClaim = TRUE,
                            !.productionProtectionClaim = TRUE,
                            !.hypervisorGradeClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeCostOrDeploymentClaimSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadCostOrDeploymentClaim",
                            !.costEfficiencyClaim = TRUE,
                            !.deploymentReadinessClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

BoolFieldOK(f) == gate[f] \in BOOLEAN

TypeOK ==
    /\ DOMAIN gate = GateFields
    /\ gate.phase \in Phase
    /\ \A f \in GateFields \ {"phase"}: BoolFieldOK(f)

SourceEvidenceOK ==
    /\ gate.sourceChecked
    /\ gate.linuxHeadMatchesP4
    /\ gate.p4Closed
    /\ gate.p4HelpersAllowOnly
    /\ ~gate.schedulerBranchesOnValidationResult
    /\ gate.runHookBeforeRqCurr
    /\ gate.runHookBeforeContextSwitch
    /\ gate.moveHooksBeforeMutation
    /\ gate.nonClaimsRecorded

RunDenialShapeOK ==
    /\ ~gate.runDenyAtCurrentP4Hook
    /\ gate.runHookPreClassSettle \/ gate.runRollbackProved

MoveDenialShapeOK ==
    gate.moveStatusPlumbing

P5ApprovalPreconditions ==
    /\ SourceEvidenceOK
    /\ RunDenialShapeOK
    /\ MoveDenialShapeOK
    /\ gate.negativeTestsDesigned
    /\ gate.pathClassificationFresh
    /\ ~gate.unsupportedPathClaims

NoP5ApprovalWithoutPreconditions ==
    gate.p5Approved => P5ApprovalPreconditions

NoRuntimeDenialWithoutP5Approval ==
    gate.runtimeDenialApproved => gate.p5Approved

NoCurrentP4HookAsDenyHook ==
    gate.runtimeDenialApproved => ~gate.runDenyAtCurrentP4Hook

NoP5BlockedAndApprovedTogether ==
    gate.p5Approved => ~gate.p5Blocked

CurrentGateMustRemainBlocked ==
    gate.phase = "P5BlockedAfterP4" => gate.p5Blocked /\ ~gate.p5Approved

NoRuntimeCoverageClaim ==
    ~gate.runtimeCoverageClaim

NoProtectionClaim ==
    /\ ~gate.monitorVerificationClaim
    /\ ~gate.productionProtectionClaim
    /\ ~gate.hypervisorGradeClaim

NoCostOrDeploymentClaim ==
    /\ ~gate.costEfficiencyClaim
    /\ ~gate.deploymentReadinessClaim

Safety ==
    /\ TypeOK
    /\ SourceEvidenceOK
    /\ NoP5ApprovalWithoutPreconditions
    /\ NoRuntimeDenialWithoutP5Approval
    /\ NoCurrentP4HookAsDenyHook
    /\ NoP5BlockedAndApprovedTogether
    /\ CurrentGateMustRemainBlocked
    /\ NoRuntimeCoverageClaim
    /\ NoProtectionClaim
    /\ NoCostOrDeploymentClaim

====
