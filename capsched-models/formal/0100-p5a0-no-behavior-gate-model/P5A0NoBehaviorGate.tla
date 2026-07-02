---------- MODULE P5A0NoBehaviorGate ----------

VARIABLE gate

vars == <<gate>>

Phase == {
    "P5A0ProposalRecorded",
    "BadLinuxPatchApproved",
    "BadBehaviorChange",
    "BadNonAllowBranch",
    "BadRuntimeDenial",
    "BadRetryFailClosedQuarantine",
    "BadPublicAbiOrMonitor",
    "BadMoveStatusBehavior",
    "BadRunP4Denial",
    "BadPublicTestHarness",
    "BadSetupBehaviorChange",
    "BadMissingPrePatchEvidence",
    "BadProtectionCostOrDeploymentClaim"
}

GateFields == {
    "phase",
    "sourceChecked",
    "p5aScopeRecorded",
    "p5a0ProposalRecorded",
    "linuxPatchApproved",
    "behaviorChangeApproved",
    "configOffBehaviorImpact",
    "configOnNonAllowReachable",
    "helperReturnsOnlyAllow",
    "schedulerBranchesOnNonAllow",
    "runtimeDenialApproved",
    "retryApproved",
    "failClosedApproved",
    "quarantineApproved",
    "publicAbi",
    "monitorCall",
    "moveStatusPlumbingPlanned",
    "moveNonAllowReachableInP5A0",
    "movePlacementMutationOnNonAllow",
    "runFinalHookUsedAsDenialHook",
    "testHarnessInternalOnly",
    "testHarnessPublicAbi",
    "setupDisablePlanned",
    "setupBehaviorChanged",
    "requiredPrePatchEvidencePlanned",
    "acceptanceValidationPlanned",
    "protectionClaim",
    "costEfficiencyClaim",
    "deploymentReadinessClaim",
    "nonClaimsRecorded"
}

BaseGate == [
    phase |-> "P5A0ProposalRecorded",
    sourceChecked |-> TRUE,
    p5aScopeRecorded |-> TRUE,
    p5a0ProposalRecorded |-> TRUE,
    linuxPatchApproved |-> FALSE,
    behaviorChangeApproved |-> FALSE,
    configOffBehaviorImpact |-> FALSE,
    configOnNonAllowReachable |-> FALSE,
    helperReturnsOnlyAllow |-> TRUE,
    schedulerBranchesOnNonAllow |-> FALSE,
    runtimeDenialApproved |-> FALSE,
    retryApproved |-> FALSE,
    failClosedApproved |-> FALSE,
    quarantineApproved |-> FALSE,
    publicAbi |-> FALSE,
    monitorCall |-> FALSE,
    moveStatusPlumbingPlanned |-> TRUE,
    moveNonAllowReachableInP5A0 |-> FALSE,
    movePlacementMutationOnNonAllow |-> FALSE,
    runFinalHookUsedAsDenialHook |-> FALSE,
    testHarnessInternalOnly |-> TRUE,
    testHarnessPublicAbi |-> FALSE,
    setupDisablePlanned |-> TRUE,
    setupBehaviorChanged |-> FALSE,
    requiredPrePatchEvidencePlanned |-> TRUE,
    acceptanceValidationPlanned |-> TRUE,
    protectionClaim |-> FALSE,
    costEfficiencyClaim |-> FALSE,
    deploymentReadinessClaim |-> FALSE,
    nonClaimsRecorded |-> TRUE
]

Init == gate = BaseGate

Spec == Init /\ [][UNCHANGED gate]_vars

UnsafeLinuxPatchApprovedSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadLinuxPatchApproved",
                            !.linuxPatchApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeBehaviorChangeSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadBehaviorChange",
                            !.behaviorChangeApproved = TRUE,
                            !.configOffBehaviorImpact = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeNonAllowBranchSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadNonAllowBranch",
                            !.configOnNonAllowReachable = TRUE,
                            !.helperReturnsOnlyAllow = FALSE,
                            !.schedulerBranchesOnNonAllow = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRuntimeDenialSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadRuntimeDenial",
                            !.runtimeDenialApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRetryFailClosedQuarantineSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadRetryFailClosedQuarantine",
                            !.retryApproved = TRUE,
                            !.failClosedApproved = TRUE,
                            !.quarantineApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafePublicAbiOrMonitorSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadPublicAbiOrMonitor",
                            !.publicAbi = TRUE,
                            !.monitorCall = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeMoveStatusBehaviorSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadMoveStatusBehavior",
                            !.moveNonAllowReachableInP5A0 = TRUE,
                            !.movePlacementMutationOnNonAllow = TRUE,
                            !.behaviorChangeApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRunP4DenialSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadRunP4Denial",
                            !.runFinalHookUsedAsDenialHook = TRUE,
                            !.runtimeDenialApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafePublicTestHarnessSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadPublicTestHarness",
                            !.testHarnessInternalOnly = FALSE,
                            !.testHarnessPublicAbi = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeSetupBehaviorChangeSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadSetupBehaviorChange",
                            !.setupBehaviorChanged = TRUE,
                            !.behaviorChangeApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeMissingPrePatchEvidenceSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadMissingPrePatchEvidence",
                            !.requiredPrePatchEvidencePlanned = FALSE,
                            !.acceptanceValidationPlanned = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeProtectionCostOrDeploymentClaimSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadProtectionCostOrDeploymentClaim",
                            !.protectionClaim = TRUE,
                            !.costEfficiencyClaim = TRUE,
                            !.deploymentReadinessClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

BoolFieldOK(f) == gate[f] \in BOOLEAN

TypeOK ==
    /\ DOMAIN gate = GateFields
    /\ gate.phase \in Phase
    /\ \A f \in GateFields \ {"phase"}: BoolFieldOK(f)

ProposalPreconditions ==
    /\ gate.sourceChecked
    /\ gate.p5aScopeRecorded
    /\ gate.requiredPrePatchEvidencePlanned
    /\ gate.acceptanceValidationPlanned
    /\ gate.nonClaimsRecorded

NoProposalWithoutPreconditions ==
    gate.p5a0ProposalRecorded => ProposalPreconditions

NoLinuxPatchFromProposal ==
    ~gate.linuxPatchApproved

NoBehaviorFromP5A0Proposal ==
    /\ ~gate.behaviorChangeApproved
    /\ ~gate.configOffBehaviorImpact
    /\ ~gate.configOnNonAllowReachable
    /\ gate.helperReturnsOnlyAllow
    /\ ~gate.schedulerBranchesOnNonAllow

NoRuntimeDenialFamily ==
    /\ ~gate.runtimeDenialApproved
    /\ ~gate.retryApproved
    /\ ~gate.failClosedApproved
    /\ ~gate.quarantineApproved

NoPublicOrMonitorSurface ==
    /\ ~gate.publicAbi
    /\ ~gate.monitorCall

MoveStatusIsOnlyPlanned ==
    /\ gate.moveStatusPlumbingPlanned
    /\ ~gate.moveNonAllowReachableInP5A0
    /\ ~gate.movePlacementMutationOnNonAllow

RunHookIsNotDenialHook ==
    ~gate.runFinalHookUsedAsDenialHook

TestHarnessIsInternalOnly ==
    /\ gate.testHarnessInternalOnly
    /\ ~gate.testHarnessPublicAbi

SetupDisableDoesNotChangeRuntime ==
    /\ gate.setupDisablePlanned
    /\ ~gate.setupBehaviorChanged

NoProductionOrCostClaim ==
    /\ ~gate.protectionClaim
    /\ ~gate.costEfficiencyClaim
    /\ ~gate.deploymentReadinessClaim

Safety ==
    /\ TypeOK
    /\ NoProposalWithoutPreconditions
    /\ NoLinuxPatchFromProposal
    /\ NoBehaviorFromP5A0Proposal
    /\ NoRuntimeDenialFamily
    /\ NoPublicOrMonitorSurface
    /\ MoveStatusIsOnlyPlanned
    /\ RunHookIsNotDenialHook
    /\ TestHarnessIsInternalOnly
    /\ SetupDisableDoesNotChangeRuntime
    /\ NoProductionOrCostClaim

====
