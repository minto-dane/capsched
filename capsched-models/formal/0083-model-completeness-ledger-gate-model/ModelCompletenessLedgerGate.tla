---------- MODULE ModelCompletenessLedgerGate ----------
EXTENDS Naturals

VARIABLES
    phase,
    coreClaimsModelSupported,
    compatibilityClassified,
    tcbModelSupported,
    sideModelSupported,
    evalModelSupported,
    modelGoalComplete,
    productionEvidence,
    productionProtectionClaim,
    ignoredOpenModelBlocker,
    prototypeAsProtection

vars == <<phase, coreClaimsModelSupported, compatibilityClassified,
          tcbModelSupported, sideModelSupported, evalModelSupported,
          modelGoalComplete, productionEvidence, productionProtectionClaim,
          ignoredOpenModelBlocker, prototypeAsProtection>>

GoodPhases == {"Start", "CurrentModelAudit", "FutureModelComplete"}

BadPhases == {
    "BadCompleteWithTcbOpen",
    "BadCompleteWithSideOpen",
    "BadCompleteWithEvalOpen",
    "BadCompleteWithoutCompatibilityClassification",
    "BadIgnoredOpenModelBlocker",
    "BadProductionClaimFromModel",
    "BadPrototypeAsProtection"
}

Phases == GoodPhases \cup BadPhases

ModelBlockersClosed ==
    /\ tcbModelSupported
    /\ sideModelSupported
    /\ evalModelSupported
    /\ compatibilityClassified

TypeOK ==
    /\ phase \in Phases
    /\ coreClaimsModelSupported \in BOOLEAN
    /\ compatibilityClassified \in BOOLEAN
    /\ tcbModelSupported \in BOOLEAN
    /\ sideModelSupported \in BOOLEAN
    /\ evalModelSupported \in BOOLEAN
    /\ modelGoalComplete \in BOOLEAN
    /\ productionEvidence \in BOOLEAN
    /\ productionProtectionClaim \in BOOLEAN
    /\ ignoredOpenModelBlocker \in BOOLEAN
    /\ prototypeAsProtection \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ coreClaimsModelSupported = FALSE
    /\ compatibilityClassified = FALSE
    /\ tcbModelSupported = FALSE
    /\ sideModelSupported = FALSE
    /\ evalModelSupported = FALSE
    /\ modelGoalComplete = FALSE
    /\ productionEvidence = FALSE
    /\ productionProtectionClaim = FALSE
    /\ ignoredOpenModelBlocker = FALSE
    /\ prototypeAsProtection = FALSE

AuditCurrentModelState ==
    /\ phase = "Start"
    /\ phase' = "CurrentModelAudit"
    /\ coreClaimsModelSupported' = TRUE
    /\ compatibilityClassified' = TRUE
    /\ tcbModelSupported' = FALSE
    /\ sideModelSupported' = FALSE
    /\ evalModelSupported' = FALSE
    /\ modelGoalComplete' = FALSE
    /\ UNCHANGED <<productionEvidence, productionProtectionClaim,
                    ignoredOpenModelBlocker, prototypeAsProtection>>

AuditFutureModelComplete ==
    /\ phase = "Start"
    /\ phase' = "FutureModelComplete"
    /\ coreClaimsModelSupported' = TRUE
    /\ compatibilityClassified' = TRUE
    /\ tcbModelSupported' = TRUE
    /\ sideModelSupported' = TRUE
    /\ evalModelSupported' = TRUE
    /\ modelGoalComplete' = TRUE
    /\ productionEvidence' = FALSE
    /\ productionProtectionClaim' = FALSE
    /\ ignoredOpenModelBlocker' = FALSE
    /\ prototypeAsProtection' = FALSE

TerminalStutter ==
    /\ phase \in {"CurrentModelAudit", "FutureModelComplete"}
    /\ UNCHANGED vars

SafeNext ==
    \/ AuditCurrentModelState
    \/ AuditFutureModelComplete
    \/ TerminalStutter

UnsafeCompleteWithTcbOpen ==
    /\ phase = "Start"
    /\ phase' = "BadCompleteWithTcbOpen"
    /\ coreClaimsModelSupported' = TRUE
    /\ compatibilityClassified' = TRUE
    /\ tcbModelSupported' = FALSE
    /\ sideModelSupported' = TRUE
    /\ evalModelSupported' = TRUE
    /\ modelGoalComplete' = TRUE
    /\ UNCHANGED <<productionEvidence, productionProtectionClaim,
                    ignoredOpenModelBlocker, prototypeAsProtection>>

UnsafeCompleteWithSideOpen ==
    /\ phase = "Start"
    /\ phase' = "BadCompleteWithSideOpen"
    /\ coreClaimsModelSupported' = TRUE
    /\ compatibilityClassified' = TRUE
    /\ tcbModelSupported' = TRUE
    /\ sideModelSupported' = FALSE
    /\ evalModelSupported' = TRUE
    /\ modelGoalComplete' = TRUE
    /\ UNCHANGED <<productionEvidence, productionProtectionClaim,
                    ignoredOpenModelBlocker, prototypeAsProtection>>

UnsafeCompleteWithEvalOpen ==
    /\ phase = "Start"
    /\ phase' = "BadCompleteWithEvalOpen"
    /\ coreClaimsModelSupported' = TRUE
    /\ compatibilityClassified' = TRUE
    /\ tcbModelSupported' = TRUE
    /\ sideModelSupported' = TRUE
    /\ evalModelSupported' = FALSE
    /\ modelGoalComplete' = TRUE
    /\ UNCHANGED <<productionEvidence, productionProtectionClaim,
                    ignoredOpenModelBlocker, prototypeAsProtection>>

UnsafeCompleteWithoutCompatibilityClassification ==
    /\ phase = "Start"
    /\ phase' = "BadCompleteWithoutCompatibilityClassification"
    /\ coreClaimsModelSupported' = TRUE
    /\ compatibilityClassified' = FALSE
    /\ tcbModelSupported' = TRUE
    /\ sideModelSupported' = TRUE
    /\ evalModelSupported' = TRUE
    /\ modelGoalComplete' = TRUE
    /\ UNCHANGED <<productionEvidence, productionProtectionClaim,
                    ignoredOpenModelBlocker, prototypeAsProtection>>

UnsafeIgnoredOpenModelBlocker ==
    /\ phase = "Start"
    /\ phase' = "BadIgnoredOpenModelBlocker"
    /\ coreClaimsModelSupported' = TRUE
    /\ compatibilityClassified' = TRUE
    /\ tcbModelSupported' = FALSE
    /\ sideModelSupported' = FALSE
    /\ evalModelSupported' = FALSE
    /\ modelGoalComplete' = TRUE
    /\ ignoredOpenModelBlocker' = TRUE
    /\ UNCHANGED <<productionEvidence, productionProtectionClaim,
                    prototypeAsProtection>>

UnsafeProductionClaimFromModel ==
    /\ phase = "Start"
    /\ phase' = "BadProductionClaimFromModel"
    /\ coreClaimsModelSupported' = TRUE
    /\ compatibilityClassified' = TRUE
    /\ tcbModelSupported' = TRUE
    /\ sideModelSupported' = TRUE
    /\ evalModelSupported' = TRUE
    /\ modelGoalComplete' = TRUE
    /\ productionEvidence' = FALSE
    /\ productionProtectionClaim' = TRUE
    /\ UNCHANGED <<ignoredOpenModelBlocker, prototypeAsProtection>>

UnsafePrototypeAsProtection ==
    /\ phase = "Start"
    /\ phase' = "BadPrototypeAsProtection"
    /\ coreClaimsModelSupported' = TRUE
    /\ compatibilityClassified' = TRUE
    /\ tcbModelSupported' = TRUE
    /\ sideModelSupported' = TRUE
    /\ evalModelSupported' = TRUE
    /\ modelGoalComplete' = TRUE
    /\ prototypeAsProtection' = TRUE
    /\ UNCHANGED <<productionEvidence, productionProtectionClaim,
                    ignoredOpenModelBlocker>>

NoBadPhase ==
    phase \notin BadPhases

NoModelCompleteWithOpenBlockers ==
    modelGoalComplete => ModelBlockersClosed

NoIgnoredOpenModelBlocker ==
    ~ignoredOpenModelBlocker

NoProductionClaimFromModelOnly ==
    productionProtectionClaim => productionEvidence

NoPrototypeAsProtection ==
    ~prototypeAsProtection

Safety ==
    /\ TypeOK
    /\ NoBadPhase
    /\ NoModelCompleteWithOpenBlockers
    /\ NoIgnoredOpenModelBlocker
    /\ NoProductionClaimFromModelOnly
    /\ NoPrototypeAsProtection

Spec ==
    Init /\ [][SafeNext]_vars

UnsafeCompleteWithTcbOpenSpec ==
    Init /\ [][UnsafeCompleteWithTcbOpen]_vars

UnsafeCompleteWithSideOpenSpec ==
    Init /\ [][UnsafeCompleteWithSideOpen]_vars

UnsafeCompleteWithEvalOpenSpec ==
    Init /\ [][UnsafeCompleteWithEvalOpen]_vars

UnsafeCompleteWithoutCompatibilityClassificationSpec ==
    Init /\ [][UnsafeCompleteWithoutCompatibilityClassification]_vars

UnsafeIgnoredOpenModelBlockerSpec ==
    Init /\ [][UnsafeIgnoredOpenModelBlocker]_vars

UnsafeProductionClaimFromModelSpec ==
    Init /\ [][UnsafeProductionClaimFromModel]_vars

UnsafePrototypeAsProtectionSpec ==
    Init /\ [][UnsafePrototypeAsProtection]_vars

=============================================================================
