---------- MODULE FinalModelCompletenessLedger ----------
EXTENDS Naturals

VARIABLES
    phase,
    topChildrenModelSatisfied,
    compatibilityClassified,
    devSubclaimsClosed,
    tcbModelSupported,
    sideModelSupported,
    evalContractSupported,
    noOpenModelBlockers,
    forbiddenClaimsRecorded,
    modelGoalComplete,
    productionEvidence,
    runtimeCoverageEvidence,
    monitorVerified,
    costEvaluationResults,
    implementationEvidence,
    productionProtectionClaim,
    costEfficiencyClaim,
    runtimeCoverageClaim,
    implementationClaim,
    ignoredOpenModelBlocker,
    prototypeAsProtection,
    topProductionCompleteClaim

vars == <<phase, topChildrenModelSatisfied, compatibilityClassified,
          devSubclaimsClosed, tcbModelSupported, sideModelSupported,
          evalContractSupported, noOpenModelBlockers, forbiddenClaimsRecorded,
          modelGoalComplete, productionEvidence, runtimeCoverageEvidence,
          monitorVerified, costEvaluationResults, implementationEvidence,
          productionProtectionClaim, costEfficiencyClaim, runtimeCoverageClaim,
          implementationClaim, ignoredOpenModelBlocker, prototypeAsProtection,
          topProductionCompleteClaim>>

GoodPhases == {"Start", "ModelOnlyComplete"}

BadPhases == {
    "BadMissingTopChildren",
    "BadMissingCompatibility",
    "BadMissingDevSubclaims",
    "BadMissingTcb",
    "BadMissingSide",
    "BadMissingEval",
    "BadOpenBlockerIgnored",
    "BadMissingForbiddenClaims",
    "BadProductionProtectionClaim",
    "BadCostEfficiencyClaim",
    "BadRuntimeCoverageClaim",
    "BadImplementationClaim",
    "BadPrototypeAsProtection",
    "BadTopProductionCompleteClaim"
}

Phases == GoodPhases \cup BadPhases

ModelLedgerReady ==
    /\ topChildrenModelSatisfied
    /\ compatibilityClassified
    /\ devSubclaimsClosed
    /\ tcbModelSupported
    /\ sideModelSupported
    /\ evalContractSupported
    /\ noOpenModelBlockers
    /\ forbiddenClaimsRecorded

TypeOK ==
    /\ phase \in Phases
    /\ topChildrenModelSatisfied \in BOOLEAN
    /\ compatibilityClassified \in BOOLEAN
    /\ devSubclaimsClosed \in BOOLEAN
    /\ tcbModelSupported \in BOOLEAN
    /\ sideModelSupported \in BOOLEAN
    /\ evalContractSupported \in BOOLEAN
    /\ noOpenModelBlockers \in BOOLEAN
    /\ forbiddenClaimsRecorded \in BOOLEAN
    /\ modelGoalComplete \in BOOLEAN
    /\ productionEvidence \in BOOLEAN
    /\ runtimeCoverageEvidence \in BOOLEAN
    /\ monitorVerified \in BOOLEAN
    /\ costEvaluationResults \in BOOLEAN
    /\ implementationEvidence \in BOOLEAN
    /\ productionProtectionClaim \in BOOLEAN
    /\ costEfficiencyClaim \in BOOLEAN
    /\ runtimeCoverageClaim \in BOOLEAN
    /\ implementationClaim \in BOOLEAN
    /\ ignoredOpenModelBlocker \in BOOLEAN
    /\ prototypeAsProtection \in BOOLEAN
    /\ topProductionCompleteClaim \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ topChildrenModelSatisfied = FALSE
    /\ compatibilityClassified = FALSE
    /\ devSubclaimsClosed = FALSE
    /\ tcbModelSupported = FALSE
    /\ sideModelSupported = FALSE
    /\ evalContractSupported = FALSE
    /\ noOpenModelBlockers = FALSE
    /\ forbiddenClaimsRecorded = FALSE
    /\ modelGoalComplete = FALSE
    /\ productionEvidence = FALSE
    /\ runtimeCoverageEvidence = FALSE
    /\ monitorVerified = FALSE
    /\ costEvaluationResults = FALSE
    /\ implementationEvidence = FALSE
    /\ productionProtectionClaim = FALSE
    /\ costEfficiencyClaim = FALSE
    /\ runtimeCoverageClaim = FALSE
    /\ implementationClaim = FALSE
    /\ ignoredOpenModelBlocker = FALSE
    /\ prototypeAsProtection = FALSE
    /\ topProductionCompleteClaim = FALSE

CompleteModelOnly ==
    /\ phase = "Start"
    /\ phase' = "ModelOnlyComplete"
    /\ topChildrenModelSatisfied' = TRUE
    /\ compatibilityClassified' = TRUE
    /\ devSubclaimsClosed' = TRUE
    /\ tcbModelSupported' = TRUE
    /\ sideModelSupported' = TRUE
    /\ evalContractSupported' = TRUE
    /\ noOpenModelBlockers' = TRUE
    /\ forbiddenClaimsRecorded' = TRUE
    /\ modelGoalComplete' = TRUE
    /\ productionEvidence' = FALSE
    /\ runtimeCoverageEvidence' = FALSE
    /\ monitorVerified' = FALSE
    /\ costEvaluationResults' = FALSE
    /\ implementationEvidence' = FALSE
    /\ productionProtectionClaim' = FALSE
    /\ costEfficiencyClaim' = FALSE
    /\ runtimeCoverageClaim' = FALSE
    /\ implementationClaim' = FALSE
    /\ ignoredOpenModelBlocker' = FALSE
    /\ prototypeAsProtection' = FALSE
    /\ topProductionCompleteClaim' = FALSE

TerminalStutter ==
    /\ phase = "ModelOnlyComplete"
    /\ UNCHANGED vars

SafeNext ==
    \/ CompleteModelOnly
    \/ TerminalStutter

UnsafeBase(nextPhase, topOK, compatOK, devOK, tcbOK, sideOK, evalOK,
           blockersOK, forbidOK, prodClaim, costClaim, runtimeClaim,
           implClaim, ignored, proto, topClaim) ==
    /\ phase = "Start"
    /\ phase' = nextPhase
    /\ topChildrenModelSatisfied' = topOK
    /\ compatibilityClassified' = compatOK
    /\ devSubclaimsClosed' = devOK
    /\ tcbModelSupported' = tcbOK
    /\ sideModelSupported' = sideOK
    /\ evalContractSupported' = evalOK
    /\ noOpenModelBlockers' = blockersOK
    /\ forbiddenClaimsRecorded' = forbidOK
    /\ modelGoalComplete' = TRUE
    /\ productionEvidence' = FALSE
    /\ runtimeCoverageEvidence' = FALSE
    /\ monitorVerified' = FALSE
    /\ costEvaluationResults' = FALSE
    /\ implementationEvidence' = FALSE
    /\ productionProtectionClaim' = prodClaim
    /\ costEfficiencyClaim' = costClaim
    /\ runtimeCoverageClaim' = runtimeClaim
    /\ implementationClaim' = implClaim
    /\ ignoredOpenModelBlocker' = ignored
    /\ prototypeAsProtection' = proto
    /\ topProductionCompleteClaim' = topClaim

UnsafeMissingTopChildren ==
    UnsafeBase("BadMissingTopChildren",
               FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
               FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)

UnsafeMissingCompatibility ==
    UnsafeBase("BadMissingCompatibility",
               TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
               FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)

UnsafeMissingDevSubclaims ==
    UnsafeBase("BadMissingDevSubclaims",
               TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE,
               FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)

UnsafeMissingTcb ==
    UnsafeBase("BadMissingTcb",
               TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE,
               FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)

UnsafeMissingSide ==
    UnsafeBase("BadMissingSide",
               TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE,
               FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)

UnsafeMissingEval ==
    UnsafeBase("BadMissingEval",
               TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
               FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)

UnsafeOpenBlockerIgnored ==
    UnsafeBase("BadOpenBlockerIgnored",
               TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE,
               FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE)

UnsafeMissingForbiddenClaims ==
    UnsafeBase("BadMissingForbiddenClaims",
               TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE,
               FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)

UnsafeProductionProtectionClaim ==
    UnsafeBase("BadProductionProtectionClaim",
               TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
               TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)

UnsafeCostEfficiencyClaim ==
    UnsafeBase("BadCostEfficiencyClaim",
               TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
               FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE)

UnsafeRuntimeCoverageClaim ==
    UnsafeBase("BadRuntimeCoverageClaim",
               TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
               FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE)

UnsafeImplementationClaim ==
    UnsafeBase("BadImplementationClaim",
               TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
               FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE)

UnsafePrototypeAsProtection ==
    UnsafeBase("BadPrototypeAsProtection",
               TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
               FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE)

UnsafeTopProductionCompleteClaim ==
    UnsafeBase("BadTopProductionCompleteClaim",
               TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
               FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE)

NoBadPhase ==
    phase \notin BadPhases

NoModelCompleteWithoutReadyLedger ==
    modelGoalComplete => ModelLedgerReady

NoIgnoredOpenModelBlocker ==
    ~ignoredOpenModelBlocker

NoProductionProtectionClaimFromModelOnly ==
    productionProtectionClaim =>
        /\ productionEvidence
        /\ runtimeCoverageEvidence
        /\ monitorVerified

NoCostEfficiencyClaimFromModelOnly ==
    costEfficiencyClaim => costEvaluationResults

NoRuntimeCoverageClaimFromModelOnly ==
    runtimeCoverageClaim => runtimeCoverageEvidence

NoImplementationClaimFromModelOnly ==
    implementationClaim => implementationEvidence

NoPrototypeAsProtection ==
    ~prototypeAsProtection

NoTopProductionCompleteClaim ==
    ~topProductionCompleteClaim

Safety ==
    /\ TypeOK
    /\ NoBadPhase
    /\ NoModelCompleteWithoutReadyLedger
    /\ NoIgnoredOpenModelBlocker
    /\ NoProductionProtectionClaimFromModelOnly
    /\ NoCostEfficiencyClaimFromModelOnly
    /\ NoRuntimeCoverageClaimFromModelOnly
    /\ NoImplementationClaimFromModelOnly
    /\ NoPrototypeAsProtection
    /\ NoTopProductionCompleteClaim

Spec ==
    Init /\ [][SafeNext]_vars

UnsafeMissingTopChildrenSpec ==
    Init /\ [][UnsafeMissingTopChildren]_vars

UnsafeMissingCompatibilitySpec ==
    Init /\ [][UnsafeMissingCompatibility]_vars

UnsafeMissingDevSubclaimsSpec ==
    Init /\ [][UnsafeMissingDevSubclaims]_vars

UnsafeMissingTcbSpec ==
    Init /\ [][UnsafeMissingTcb]_vars

UnsafeMissingSideSpec ==
    Init /\ [][UnsafeMissingSide]_vars

UnsafeMissingEvalSpec ==
    Init /\ [][UnsafeMissingEval]_vars

UnsafeOpenBlockerIgnoredSpec ==
    Init /\ [][UnsafeOpenBlockerIgnored]_vars

UnsafeMissingForbiddenClaimsSpec ==
    Init /\ [][UnsafeMissingForbiddenClaims]_vars

UnsafeProductionProtectionClaimSpec ==
    Init /\ [][UnsafeProductionProtectionClaim]_vars

UnsafeCostEfficiencyClaimSpec ==
    Init /\ [][UnsafeCostEfficiencyClaim]_vars

UnsafeRuntimeCoverageClaimSpec ==
    Init /\ [][UnsafeRuntimeCoverageClaim]_vars

UnsafeImplementationClaimSpec ==
    Init /\ [][UnsafeImplementationClaim]_vars

UnsafePrototypeAsProtectionSpec ==
    Init /\ [][UnsafePrototypeAsProtection]_vars

UnsafeTopProductionCompleteClaimSpec ==
    Init /\ [][UnsafeTopProductionCompleteClaim]_vars

=============================================================================
