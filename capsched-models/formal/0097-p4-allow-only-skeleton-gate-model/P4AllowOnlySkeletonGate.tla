---------- MODULE P4AllowOnlySkeletonGate ----------

VARIABLE gate

vars == <<gate>>

Phase == {
    "P4SkeletonRecorded",
    "BadNoSourceCheck",
    "BadNoReplay",
    "BadHelperNonAllow",
    "BadSchedulerBranch",
    "BadMissingCallsites",
    "BadCheckpatch",
    "BadTargetedBuild",
    "BadEmittedSymbol",
    "BadAuthoritySideEffect",
    "BadAcceptedWithoutFullValidation",
    "BadRuntimeDenial",
    "BadProtectionClaim"
}

GateFields == {
    "phase",
    "sourceChecked",
    "workCommitMatches",
    "patchQueueReplayExact",
    "checkpatchClean",
    "targetedBuildPassed",
    "helperCountCorrect",
    "callsiteCountCorrect",
    "helpersReturnOnlyAllow",
    "nonAllowReturnsFound",
    "schedulerBranchesOnValidationResult",
    "validationSymbolsEmitted",
    "abiAdded",
    "monitorCallReachable",
    "budgetChargeReachable",
    "p4SkeletonRecorded",
    "fullBuildPassed",
    "qemuPassed",
    "p4Accepted",
    "runtimeDenialApproved",
    "runtimeCoverageClaim",
    "p5DenialApproved",
    "monitorVerificationClaim",
    "productionProtectionClaim",
    "hypervisorGradeClaim",
    "costEfficiencyClaim",
    "deploymentReadinessClaim",
    "nonClaimsRecorded"
}

BaseGate == [
    phase |-> "P4SkeletonRecorded",
    sourceChecked |-> TRUE,
    workCommitMatches |-> TRUE,
    patchQueueReplayExact |-> TRUE,
    checkpatchClean |-> TRUE,
    targetedBuildPassed |-> TRUE,
    helperCountCorrect |-> TRUE,
    callsiteCountCorrect |-> TRUE,
    helpersReturnOnlyAllow |-> TRUE,
    nonAllowReturnsFound |-> FALSE,
    schedulerBranchesOnValidationResult |-> FALSE,
    validationSymbolsEmitted |-> FALSE,
    abiAdded |-> FALSE,
    monitorCallReachable |-> FALSE,
    budgetChargeReachable |-> FALSE,
    p4SkeletonRecorded |-> TRUE,
    fullBuildPassed |-> FALSE,
    qemuPassed |-> FALSE,
    p4Accepted |-> FALSE,
    runtimeDenialApproved |-> FALSE,
    runtimeCoverageClaim |-> FALSE,
    p5DenialApproved |-> FALSE,
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

UnsafeNoReplaySpec ==
    gate = [BaseGate EXCEPT !.phase = "BadNoReplay",
                            !.patchQueueReplayExact = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeHelperNonAllowSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadHelperNonAllow",
                            !.helpersReturnOnlyAllow = FALSE,
                            !.nonAllowReturnsFound = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeSchedulerBranchSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadSchedulerBranch",
                            !.schedulerBranchesOnValidationResult = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeMissingCallsitesSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadMissingCallsites",
                            !.callsiteCountCorrect = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeCheckpatchSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadCheckpatch",
                            !.checkpatchClean = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeTargetedBuildSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadTargetedBuild",
                            !.targetedBuildPassed = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeEmittedSymbolSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadEmittedSymbol",
                            !.validationSymbolsEmitted = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeAuthoritySideEffectSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadAuthoritySideEffect",
                            !.abiAdded = TRUE,
                            !.monitorCallReachable = TRUE,
                            !.budgetChargeReachable = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeAcceptedWithoutFullValidationSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadAcceptedWithoutFullValidation",
                            !.p4Accepted = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRuntimeDenialSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadRuntimeDenial",
                            !.runtimeDenialApproved = TRUE,
                            !.p5DenialApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeProtectionClaimSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadProtectionClaim",
                            !.monitorVerificationClaim = TRUE,
                            !.productionProtectionClaim = TRUE,
                            !.hypervisorGradeClaim = TRUE,
                            !.costEfficiencyClaim = TRUE,
                            !.deploymentReadinessClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

BoolFieldOK(f) == gate[f] \in BOOLEAN

TypeOK ==
    /\ DOMAIN gate = GateFields
    /\ gate.phase \in Phase
    /\ \A f \in GateFields \ {"phase"}: BoolFieldOK(f)

RecordedSkeletonPreconditions ==
    /\ gate.sourceChecked
    /\ gate.workCommitMatches
    /\ gate.patchQueueReplayExact
    /\ gate.checkpatchClean
    /\ gate.targetedBuildPassed
    /\ gate.helperCountCorrect
    /\ gate.callsiteCountCorrect
    /\ gate.helpersReturnOnlyAllow
    /\ ~gate.nonAllowReturnsFound
    /\ ~gate.schedulerBranchesOnValidationResult
    /\ ~gate.validationSymbolsEmitted
    /\ ~gate.abiAdded
    /\ ~gate.monitorCallReachable
    /\ ~gate.budgetChargeReachable
    /\ gate.nonClaimsRecorded

FullAcceptancePreconditions ==
    /\ RecordedSkeletonPreconditions
    /\ gate.fullBuildPassed
    /\ gate.qemuPassed

NoSkeletonRecordWithoutPreconditions ==
    gate.p4SkeletonRecorded => RecordedSkeletonPreconditions

NoP4AcceptanceWithoutFullValidation ==
    gate.p4Accepted => FullAcceptancePreconditions

NoRuntimeDenialFromP4Skeleton ==
    /\ ~gate.runtimeDenialApproved
    /\ ~gate.p5DenialApproved

NoRuntimeCoverageClaimFromTargetedBuild ==
    ~gate.runtimeCoverageClaim

NoProtectionOrCostClaimFromP4Skeleton ==
    /\ ~gate.monitorVerificationClaim
    /\ ~gate.productionProtectionClaim
    /\ ~gate.hypervisorGradeClaim
    /\ ~gate.costEfficiencyClaim
    /\ ~gate.deploymentReadinessClaim

Safety ==
    /\ TypeOK
    /\ NoSkeletonRecordWithoutPreconditions
    /\ NoP4AcceptanceWithoutFullValidation
    /\ NoRuntimeDenialFromP4Skeleton
    /\ NoRuntimeCoverageClaimFromTargetedBuild
    /\ NoProtectionOrCostClaimFromP4Skeleton

====
