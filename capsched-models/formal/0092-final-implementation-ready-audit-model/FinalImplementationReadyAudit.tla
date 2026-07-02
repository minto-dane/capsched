---------- MODULE FinalImplementationReadyAudit ----------
EXTENDS Naturals

VARIABLE audit

vars == <<audit>>

Phase == {
    "FinalAuditPassed",
    "BadDesignReadyApprovesPatch",
    "BadP3WithoutScopeReopen",
    "BadP4BeforeP3",
    "BadP5BeforeP3P4",
    "BadP5WithoutClassification",
    "BadP5RuntimeCoverage",
    "BadProtectionClaim",
    "BadCostClaim",
    "BadAbiClaim",
    "BadMissingClaimLedger",
    "BadMissingDriftGate",
    "BadMissingNonClaims"
}

AuditFields == {
    "phase",
    "designReady",
    "scopeReopenFrameworkComplete",
    "implementationScopeReopened",
    "linuxPatchApproved",
    "nextCandidateP3",
    "p3ContractPresent",
    "p4ContractPresent",
    "p5GatePresent",
    "p3ImplementedValidated",
    "p4ImplementedValidated",
    "claimLedgerGatePresent",
    "driftGateFresh",
    "pathClassificationPresent",
    "negativePlanPresent",
    "nonClaimsRecorded",
    "behaviorChangeApproved",
    "runtimeDenialApproved",
    "runtimeCoverageClaim",
    "abiClaim",
    "monitorVerifiedClaim",
    "productionProtectionClaim",
    "costEfficiencyClaim"
}

BaseAudit == [
    phase |-> "FinalAuditPassed",
    designReady |-> TRUE,
    scopeReopenFrameworkComplete |-> TRUE,
    implementationScopeReopened |-> FALSE,
    linuxPatchApproved |-> FALSE,
    nextCandidateP3 |-> TRUE,
    p3ContractPresent |-> TRUE,
    p4ContractPresent |-> TRUE,
    p5GatePresent |-> TRUE,
    p3ImplementedValidated |-> FALSE,
    p4ImplementedValidated |-> FALSE,
    claimLedgerGatePresent |-> TRUE,
    driftGateFresh |-> TRUE,
    pathClassificationPresent |-> TRUE,
    negativePlanPresent |-> TRUE,
    nonClaimsRecorded |-> TRUE,
    behaviorChangeApproved |-> FALSE,
    runtimeDenialApproved |-> FALSE,
    runtimeCoverageClaim |-> FALSE,
    abiClaim |-> FALSE,
    monitorVerifiedClaim |-> FALSE,
    productionProtectionClaim |-> FALSE,
    costEfficiencyClaim |-> FALSE
]

Init == audit = BaseAudit

Spec == Init /\ [][UNCHANGED audit]_vars

UnsafeDesignReadyApprovesPatchSpec ==
    audit = [BaseAudit EXCEPT
        !.phase = "BadDesignReadyApprovesPatch",
        !.linuxPatchApproved = TRUE]
    /\ [][UNCHANGED audit]_vars

UnsafeP3WithoutScopeReopenSpec ==
    audit = [BaseAudit EXCEPT
        !.phase = "BadP3WithoutScopeReopen",
        !.implementationScopeReopened = FALSE,
        !.linuxPatchApproved = TRUE]
    /\ [][UNCHANGED audit]_vars

UnsafeP4BeforeP3Spec ==
    audit = [BaseAudit EXCEPT
        !.phase = "BadP4BeforeP3",
        !.implementationScopeReopened = TRUE,
        !.p3ImplementedValidated = FALSE,
        !.linuxPatchApproved = TRUE,
        !.nextCandidateP3 = FALSE]
    /\ [][UNCHANGED audit]_vars

UnsafeP5BeforeP3P4Spec ==
    audit = [BaseAudit EXCEPT
        !.phase = "BadP5BeforeP3P4",
        !.implementationScopeReopened = TRUE,
        !.p3ImplementedValidated = FALSE,
        !.p4ImplementedValidated = FALSE,
        !.runtimeDenialApproved = TRUE]
    /\ [][UNCHANGED audit]_vars

UnsafeP5WithoutClassificationSpec ==
    audit = [BaseAudit EXCEPT
        !.phase = "BadP5WithoutClassification",
        !.implementationScopeReopened = TRUE,
        !.p3ImplementedValidated = TRUE,
        !.p4ImplementedValidated = TRUE,
        !.pathClassificationPresent = FALSE,
        !.runtimeDenialApproved = TRUE]
    /\ [][UNCHANGED audit]_vars

UnsafeP5RuntimeCoverageSpec ==
    audit = [BaseAudit EXCEPT
        !.phase = "BadP5RuntimeCoverage",
        !.runtimeCoverageClaim = TRUE]
    /\ [][UNCHANGED audit]_vars

UnsafeProtectionClaimSpec ==
    audit = [BaseAudit EXCEPT
        !.phase = "BadProtectionClaim",
        !.productionProtectionClaim = TRUE]
    /\ [][UNCHANGED audit]_vars

UnsafeCostClaimSpec ==
    audit = [BaseAudit EXCEPT
        !.phase = "BadCostClaim",
        !.costEfficiencyClaim = TRUE]
    /\ [][UNCHANGED audit]_vars

UnsafeAbiClaimSpec ==
    audit = [BaseAudit EXCEPT
        !.phase = "BadAbiClaim",
        !.abiClaim = TRUE]
    /\ [][UNCHANGED audit]_vars

UnsafeMissingClaimLedgerSpec ==
    audit = [BaseAudit EXCEPT
        !.phase = "BadMissingClaimLedger",
        !.claimLedgerGatePresent = FALSE,
        !.designReady = TRUE]
    /\ [][UNCHANGED audit]_vars

UnsafeMissingDriftGateSpec ==
    audit = [BaseAudit EXCEPT
        !.phase = "BadMissingDriftGate",
        !.driftGateFresh = FALSE,
        !.designReady = TRUE]
    /\ [][UNCHANGED audit]_vars

UnsafeMissingNonClaimsSpec ==
    audit = [BaseAudit EXCEPT
        !.phase = "BadMissingNonClaims",
        !.nonClaimsRecorded = FALSE,
        !.designReady = TRUE]
    /\ [][UNCHANGED audit]_vars

BoolFieldOK(f) == audit[f] \in BOOLEAN

TypeOK ==
    /\ DOMAIN audit = AuditFields
    /\ audit.phase \in Phase
    /\ BoolFieldOK("designReady")
    /\ BoolFieldOK("scopeReopenFrameworkComplete")
    /\ BoolFieldOK("implementationScopeReopened")
    /\ BoolFieldOK("linuxPatchApproved")
    /\ BoolFieldOK("nextCandidateP3")
    /\ BoolFieldOK("p3ContractPresent")
    /\ BoolFieldOK("p4ContractPresent")
    /\ BoolFieldOK("p5GatePresent")
    /\ BoolFieldOK("p3ImplementedValidated")
    /\ BoolFieldOK("p4ImplementedValidated")
    /\ BoolFieldOK("claimLedgerGatePresent")
    /\ BoolFieldOK("driftGateFresh")
    /\ BoolFieldOK("pathClassificationPresent")
    /\ BoolFieldOK("negativePlanPresent")
    /\ BoolFieldOK("nonClaimsRecorded")
    /\ BoolFieldOK("behaviorChangeApproved")
    /\ BoolFieldOK("runtimeDenialApproved")
    /\ BoolFieldOK("runtimeCoverageClaim")
    /\ BoolFieldOK("abiClaim")
    /\ BoolFieldOK("monitorVerifiedClaim")
    /\ BoolFieldOK("productionProtectionClaim")
    /\ BoolFieldOK("costEfficiencyClaim")

DesignReadyRequiresGates ==
    audit.designReady =>
        /\ audit.scopeReopenFrameworkComplete
        /\ audit.p3ContractPresent
        /\ audit.p4ContractPresent
        /\ audit.p5GatePresent
        /\ audit.claimLedgerGatePresent
        /\ audit.driftGateFresh
        /\ audit.pathClassificationPresent
        /\ audit.negativePlanPresent
        /\ audit.nonClaimsRecorded

DesignReadyDoesNotApprovePatch ==
    audit.designReady =>
        /\ ~audit.implementationScopeReopened
        /\ ~audit.linuxPatchApproved
        /\ ~audit.behaviorChangeApproved
        /\ ~audit.runtimeDenialApproved

PatchRequiresScopeReopen ==
    audit.linuxPatchApproved => audit.implementationScopeReopened

P4RequiresP3 ==
    (~audit.nextCandidateP3 /\ audit.linuxPatchApproved) => audit.p3ImplementedValidated

P5RequiresP3P4 ==
    audit.runtimeDenialApproved =>
        /\ audit.p3ImplementedValidated
        /\ audit.p4ImplementedValidated
        /\ audit.pathClassificationPresent
        /\ audit.negativePlanPresent

NoRuntimeCoverageClaim ==
    ~audit.runtimeCoverageClaim

NoAbiClaim ==
    ~audit.abiClaim

NoMonitorVerifiedClaim ==
    ~audit.monitorVerifiedClaim

NoProductionProtectionClaim ==
    ~audit.productionProtectionClaim

NoCostEfficiencyClaim ==
    ~audit.costEfficiencyClaim

Safety ==
    /\ TypeOK
    /\ DesignReadyRequiresGates
    /\ DesignReadyDoesNotApprovePatch
    /\ PatchRequiresScopeReopen
    /\ P4RequiresP3
    /\ P5RequiresP3P4
    /\ NoRuntimeCoverageClaim
    /\ NoAbiClaim
    /\ NoMonitorVerifiedClaim
    /\ NoProductionProtectionClaim
    /\ NoCostEfficiencyClaim

====
