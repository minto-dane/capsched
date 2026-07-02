---------- MODULE SchedulerPathClassificationGate ----------
EXTENDS Naturals

VARIABLES
    phase,
    cfsRunStatus,
    commonMoveStatus,
    fairBalanceStatus,
    rtStatus,
    dlStatus,
    schedExtStatus,
    coreStatus,
    proxyStatus,
    asyncStatus,
    internalKthreadStatus,
    cfsEvidence,
    commonMoveEvidence,
    rtEvidence,
    dlEvidence,
    schedExtEvidence,
    coreEvidence,
    proxyEvidence,
    asyncEvidence,
    negativeTestsMapped,
    runtimeCoverageClaim,
    implementationApproved,
    productionProtectionClaim,
    costEfficiencyClaim,
    unknownPathOpen,
    supportedWithoutEvidence,
    coverageOverExcluded,
    disabledPathRuns,
    fallbackAuthority,
    workqueueCallerAuthority,
    internalKthreadOrdinaryAuthority

vars == <<phase, cfsRunStatus, commonMoveStatus, fairBalanceStatus,
          rtStatus, dlStatus, schedExtStatus, coreStatus, proxyStatus,
          asyncStatus, internalKthreadStatus, cfsEvidence,
          commonMoveEvidence, rtEvidence, dlEvidence, schedExtEvidence,
          coreEvidence, proxyEvidence, asyncEvidence, negativeTestsMapped,
          runtimeCoverageClaim, implementationApproved,
          productionProtectionClaim, costEfficiencyClaim, unknownPathOpen,
          supportedWithoutEvidence, coverageOverExcluded, disabledPathRuns,
          fallbackAuthority, workqueueCallerAuthority,
          internalKthreadOrdinaryAuthority>>

Status == {"supported", "disabled", "excluded", "open"}
Phases == {
    "Classified",
    "BadUnknownPathOpen",
    "BadSupportedWithoutEvidence",
    "BadCoverageOverExcluded",
    "BadDisabledPathRuns",
    "BadFallbackAuthority",
    "BadWorkqueueCallerAuthority",
    "BadInternalKthreadOrdinaryAuthority",
    "BadImplementationApproval",
    "BadProductionProtectionClaim",
    "BadCostEfficiencyClaim"
}

AllClassified ==
    /\ cfsRunStatus # "open"
    /\ commonMoveStatus # "open"
    /\ fairBalanceStatus # "open"
    /\ rtStatus # "open"
    /\ dlStatus # "open"
    /\ schedExtStatus # "open"
    /\ coreStatus # "open"
    /\ proxyStatus # "open"
    /\ asyncStatus # "open"
    /\ internalKthreadStatus # "open"

SupportedEvidenceOK ==
    /\ (cfsRunStatus = "supported" => cfsEvidence)
    /\ (commonMoveStatus = "supported" => commonMoveEvidence)
    /\ (rtStatus = "supported" => rtEvidence)
    /\ (dlStatus = "supported" => dlEvidence)
    /\ (schedExtStatus = "supported" => schedExtEvidence)
    /\ (coreStatus = "supported" => coreEvidence)
    /\ (proxyStatus = "supported" => proxyEvidence)
    /\ (asyncStatus = "supported" => asyncEvidence)

AllBroadRuntimePathsSupported ==
    /\ cfsRunStatus = "supported"
    /\ commonMoveStatus = "supported"
    /\ fairBalanceStatus = "supported"
    /\ rtStatus = "supported"
    /\ dlStatus = "supported"
    /\ schedExtStatus = "supported"
    /\ coreStatus = "supported"
    /\ proxyStatus = "supported"
    /\ asyncStatus = "supported"

TypeOK ==
    /\ phase \in Phases
    /\ cfsRunStatus \in Status
    /\ commonMoveStatus \in Status
    /\ fairBalanceStatus \in Status
    /\ rtStatus \in Status
    /\ dlStatus \in Status
    /\ schedExtStatus \in Status
    /\ coreStatus \in Status
    /\ proxyStatus \in Status
    /\ asyncStatus \in Status
    /\ internalKthreadStatus \in Status
    /\ cfsEvidence \in BOOLEAN
    /\ commonMoveEvidence \in BOOLEAN
    /\ rtEvidence \in BOOLEAN
    /\ dlEvidence \in BOOLEAN
    /\ schedExtEvidence \in BOOLEAN
    /\ coreEvidence \in BOOLEAN
    /\ proxyEvidence \in BOOLEAN
    /\ asyncEvidence \in BOOLEAN
    /\ negativeTestsMapped \in BOOLEAN
    /\ runtimeCoverageClaim \in BOOLEAN
    /\ implementationApproved \in BOOLEAN
    /\ productionProtectionClaim \in BOOLEAN
    /\ costEfficiencyClaim \in BOOLEAN
    /\ unknownPathOpen \in BOOLEAN
    /\ supportedWithoutEvidence \in BOOLEAN
    /\ coverageOverExcluded \in BOOLEAN
    /\ disabledPathRuns \in BOOLEAN
    /\ fallbackAuthority \in BOOLEAN
    /\ workqueueCallerAuthority \in BOOLEAN
    /\ internalKthreadOrdinaryAuthority \in BOOLEAN

Init ==
    /\ phase = "Classified"
    /\ cfsRunStatus = "supported"
    /\ commonMoveStatus = "supported"
    /\ fairBalanceStatus = "excluded"
    /\ rtStatus = "excluded"
    /\ dlStatus = "excluded"
    /\ schedExtStatus = "disabled"
    /\ coreStatus = "disabled"
    /\ proxyStatus = "disabled"
    /\ asyncStatus = "excluded"
    /\ internalKthreadStatus = "excluded"
    /\ cfsEvidence = TRUE
    /\ commonMoveEvidence = TRUE
    /\ rtEvidence = FALSE
    /\ dlEvidence = FALSE
    /\ schedExtEvidence = FALSE
    /\ coreEvidence = FALSE
    /\ proxyEvidence = FALSE
    /\ asyncEvidence = FALSE
    /\ negativeTestsMapped = TRUE
    /\ runtimeCoverageClaim = FALSE
    /\ implementationApproved = FALSE
    /\ productionProtectionClaim = FALSE
    /\ costEfficiencyClaim = FALSE
    /\ unknownPathOpen = FALSE
    /\ supportedWithoutEvidence = FALSE
    /\ coverageOverExcluded = FALSE
    /\ disabledPathRuns = FALSE
    /\ fallbackAuthority = FALSE
    /\ workqueueCallerAuthority = FALSE
    /\ internalKthreadOrdinaryAuthority = FALSE

ClassifiedStutter ==
    /\ phase = "Classified"
    /\ UNCHANGED vars

BadStutter ==
    /\ phase # "Classified"
    /\ UNCHANGED vars

Spec == Init /\ [][ClassifiedStutter]_vars

UnsafeUnknownPathOpenStep ==
    Init
    /\ schedExtStatus' = "open"
    /\ unknownPathOpen' = TRUE
    /\ phase' = "BadUnknownPathOpen"
    /\ UNCHANGED <<cfsRunStatus, commonMoveStatus, fairBalanceStatus,
                    rtStatus, dlStatus, coreStatus, proxyStatus, asyncStatus,
                    internalKthreadStatus, cfsEvidence, commonMoveEvidence,
                    rtEvidence, dlEvidence, schedExtEvidence, coreEvidence,
                    proxyEvidence, asyncEvidence, negativeTestsMapped,
                    runtimeCoverageClaim, implementationApproved,
                    productionProtectionClaim, costEfficiencyClaim,
                    supportedWithoutEvidence, coverageOverExcluded,
                    disabledPathRuns, fallbackAuthority,
                    workqueueCallerAuthority, internalKthreadOrdinaryAuthority>>

UnsafeSupportedWithoutEvidenceStep ==
    Init
    /\ rtStatus' = "supported"
    /\ rtEvidence' = FALSE
    /\ supportedWithoutEvidence' = TRUE
    /\ phase' = "BadSupportedWithoutEvidence"
    /\ UNCHANGED <<cfsRunStatus, commonMoveStatus, fairBalanceStatus,
                    dlStatus, schedExtStatus, coreStatus, proxyStatus,
                    asyncStatus, internalKthreadStatus, cfsEvidence,
                    commonMoveEvidence, dlEvidence, schedExtEvidence,
                    coreEvidence, proxyEvidence, asyncEvidence,
                    negativeTestsMapped, runtimeCoverageClaim,
                    implementationApproved, productionProtectionClaim,
                    costEfficiencyClaim, unknownPathOpen,
                    coverageOverExcluded, disabledPathRuns, fallbackAuthority,
                    workqueueCallerAuthority, internalKthreadOrdinaryAuthority>>

UnsafeCoverageOverExcludedStep ==
    Init
    /\ runtimeCoverageClaim' = TRUE
    /\ coverageOverExcluded' = TRUE
    /\ phase' = "BadCoverageOverExcluded"
    /\ UNCHANGED <<cfsRunStatus, commonMoveStatus, fairBalanceStatus,
                    rtStatus, dlStatus, schedExtStatus, coreStatus,
                    proxyStatus, asyncStatus, internalKthreadStatus,
                    cfsEvidence, commonMoveEvidence, rtEvidence, dlEvidence,
                    schedExtEvidence, coreEvidence, proxyEvidence,
                    asyncEvidence, negativeTestsMapped, implementationApproved,
                    productionProtectionClaim, costEfficiencyClaim,
                    unknownPathOpen, supportedWithoutEvidence,
                    disabledPathRuns, fallbackAuthority,
                    workqueueCallerAuthority, internalKthreadOrdinaryAuthority>>

UnsafeDisabledPathRunsStep ==
    Init
    /\ disabledPathRuns' = TRUE
    /\ phase' = "BadDisabledPathRuns"
    /\ UNCHANGED <<cfsRunStatus, commonMoveStatus, fairBalanceStatus,
                    rtStatus, dlStatus, schedExtStatus, coreStatus,
                    proxyStatus, asyncStatus, internalKthreadStatus,
                    cfsEvidence, commonMoveEvidence, rtEvidence, dlEvidence,
                    schedExtEvidence, coreEvidence, proxyEvidence,
                    asyncEvidence, negativeTestsMapped, runtimeCoverageClaim,
                    implementationApproved, productionProtectionClaim,
                    costEfficiencyClaim, unknownPathOpen,
                    supportedWithoutEvidence, coverageOverExcluded,
                    fallbackAuthority, workqueueCallerAuthority,
                    internalKthreadOrdinaryAuthority>>

UnsafeFallbackAuthorityStep ==
    Init
    /\ fallbackAuthority' = TRUE
    /\ phase' = "BadFallbackAuthority"
    /\ UNCHANGED <<cfsRunStatus, commonMoveStatus, fairBalanceStatus,
                    rtStatus, dlStatus, schedExtStatus, coreStatus,
                    proxyStatus, asyncStatus, internalKthreadStatus,
                    cfsEvidence, commonMoveEvidence, rtEvidence, dlEvidence,
                    schedExtEvidence, coreEvidence, proxyEvidence,
                    asyncEvidence, negativeTestsMapped, runtimeCoverageClaim,
                    implementationApproved, productionProtectionClaim,
                    costEfficiencyClaim, unknownPathOpen,
                    supportedWithoutEvidence, coverageOverExcluded,
                    disabledPathRuns, workqueueCallerAuthority,
                    internalKthreadOrdinaryAuthority>>

UnsafeWorkqueueCallerAuthorityStep ==
    Init
    /\ workqueueCallerAuthority' = TRUE
    /\ phase' = "BadWorkqueueCallerAuthority"
    /\ UNCHANGED <<cfsRunStatus, commonMoveStatus, fairBalanceStatus,
                    rtStatus, dlStatus, schedExtStatus, coreStatus,
                    proxyStatus, asyncStatus, internalKthreadStatus,
                    cfsEvidence, commonMoveEvidence, rtEvidence, dlEvidence,
                    schedExtEvidence, coreEvidence, proxyEvidence,
                    asyncEvidence, negativeTestsMapped, runtimeCoverageClaim,
                    implementationApproved, productionProtectionClaim,
                    costEfficiencyClaim, unknownPathOpen,
                    supportedWithoutEvidence, coverageOverExcluded,
                    disabledPathRuns, fallbackAuthority,
                    internalKthreadOrdinaryAuthority>>

UnsafeInternalKthreadOrdinaryAuthorityStep ==
    Init
    /\ internalKthreadOrdinaryAuthority' = TRUE
    /\ phase' = "BadInternalKthreadOrdinaryAuthority"
    /\ UNCHANGED <<cfsRunStatus, commonMoveStatus, fairBalanceStatus,
                    rtStatus, dlStatus, schedExtStatus, coreStatus,
                    proxyStatus, asyncStatus, internalKthreadStatus,
                    cfsEvidence, commonMoveEvidence, rtEvidence, dlEvidence,
                    schedExtEvidence, coreEvidence, proxyEvidence,
                    asyncEvidence, negativeTestsMapped, runtimeCoverageClaim,
                    implementationApproved, productionProtectionClaim,
                    costEfficiencyClaim, unknownPathOpen,
                    supportedWithoutEvidence, coverageOverExcluded,
                    disabledPathRuns, fallbackAuthority,
                    workqueueCallerAuthority>>

UnsafeImplementationApprovalStep ==
    Init
    /\ implementationApproved' = TRUE
    /\ phase' = "BadImplementationApproval"
    /\ UNCHANGED <<cfsRunStatus, commonMoveStatus, fairBalanceStatus,
                    rtStatus, dlStatus, schedExtStatus, coreStatus,
                    proxyStatus, asyncStatus, internalKthreadStatus,
                    cfsEvidence, commonMoveEvidence, rtEvidence, dlEvidence,
                    schedExtEvidence, coreEvidence, proxyEvidence,
                    asyncEvidence, negativeTestsMapped, runtimeCoverageClaim,
                    productionProtectionClaim, costEfficiencyClaim,
                    unknownPathOpen, supportedWithoutEvidence,
                    coverageOverExcluded, disabledPathRuns, fallbackAuthority,
                    workqueueCallerAuthority, internalKthreadOrdinaryAuthority>>

UnsafeProductionProtectionClaimStep ==
    Init
    /\ productionProtectionClaim' = TRUE
    /\ phase' = "BadProductionProtectionClaim"
    /\ UNCHANGED <<cfsRunStatus, commonMoveStatus, fairBalanceStatus,
                    rtStatus, dlStatus, schedExtStatus, coreStatus,
                    proxyStatus, asyncStatus, internalKthreadStatus,
                    cfsEvidence, commonMoveEvidence, rtEvidence, dlEvidence,
                    schedExtEvidence, coreEvidence, proxyEvidence,
                    asyncEvidence, negativeTestsMapped, runtimeCoverageClaim,
                    implementationApproved, costEfficiencyClaim,
                    unknownPathOpen, supportedWithoutEvidence,
                    coverageOverExcluded, disabledPathRuns, fallbackAuthority,
                    workqueueCallerAuthority, internalKthreadOrdinaryAuthority>>

UnsafeCostEfficiencyClaimStep ==
    Init
    /\ costEfficiencyClaim' = TRUE
    /\ phase' = "BadCostEfficiencyClaim"
    /\ UNCHANGED <<cfsRunStatus, commonMoveStatus, fairBalanceStatus,
                    rtStatus, dlStatus, schedExtStatus, coreStatus,
                    proxyStatus, asyncStatus, internalKthreadStatus,
                    cfsEvidence, commonMoveEvidence, rtEvidence, dlEvidence,
                    schedExtEvidence, coreEvidence, proxyEvidence,
                    asyncEvidence, negativeTestsMapped, runtimeCoverageClaim,
                    implementationApproved, productionProtectionClaim,
                    unknownPathOpen, supportedWithoutEvidence,
                    coverageOverExcluded, disabledPathRuns, fallbackAuthority,
                    workqueueCallerAuthority, internalKthreadOrdinaryAuthority>>

UnsafeUnknownPathOpenSpec == Init /\ [][UnsafeUnknownPathOpenStep \/ BadStutter]_vars
UnsafeSupportedWithoutEvidenceSpec == Init /\ [][UnsafeSupportedWithoutEvidenceStep \/ BadStutter]_vars
UnsafeCoverageOverExcludedSpec == Init /\ [][UnsafeCoverageOverExcludedStep \/ BadStutter]_vars
UnsafeDisabledPathRunsSpec == Init /\ [][UnsafeDisabledPathRunsStep \/ BadStutter]_vars
UnsafeFallbackAuthoritySpec == Init /\ [][UnsafeFallbackAuthorityStep \/ BadStutter]_vars
UnsafeWorkqueueCallerAuthoritySpec == Init /\ [][UnsafeWorkqueueCallerAuthorityStep \/ BadStutter]_vars
UnsafeInternalKthreadOrdinaryAuthoritySpec == Init /\ [][UnsafeInternalKthreadOrdinaryAuthorityStep \/ BadStutter]_vars
UnsafeImplementationApprovalSpec == Init /\ [][UnsafeImplementationApprovalStep \/ BadStutter]_vars
UnsafeProductionProtectionClaimSpec == Init /\ [][UnsafeProductionProtectionClaimStep \/ BadStutter]_vars
UnsafeCostEfficiencyClaimSpec == Init /\ [][UnsafeCostEfficiencyClaimStep \/ BadStutter]_vars

NoOpenPath ==
    /\ AllClassified
    /\ ~unknownPathOpen

NoSupportedWithoutEvidence ==
    /\ SupportedEvidenceOK
    /\ ~supportedWithoutEvidence
    /\ negativeTestsMapped

NoCoverageOverExcluded ==
    /\ ~coverageOverExcluded
    /\ (runtimeCoverageClaim => AllBroadRuntimePathsSupported)

NoDisabledPathExecution ==
    ~disabledPathRuns

NoFallbackAuthority ==
    ~fallbackAuthority

NoAsyncAuthorityCollapse ==
    /\ ~workqueueCallerAuthority
    /\ ~internalKthreadOrdinaryAuthority

NoOverclaim ==
    /\ ~implementationApproved
    /\ ~productionProtectionClaim
    /\ ~costEfficiencyClaim

Safety ==
    /\ TypeOK
    /\ NoOpenPath
    /\ NoSupportedWithoutEvidence
    /\ NoCoverageOverExcluded
    /\ NoDisabledPathExecution
    /\ NoFallbackAuthority
    /\ NoAsyncAuthorityCollapse
    /\ NoOverclaim

====
