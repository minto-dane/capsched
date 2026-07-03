---------- MODULE P5ARPickerIneligibilityGate ----------
EXTENDS Naturals

VARIABLES
    phase,
    runnable,
    candidate,
    denied,
    ineligible,
    retryCount,
    retryBudget,
    classStateSettled,
    rqCurrPublished,
    running,
    runningTask,
    freshAllowedCandidate,
    denialRecorded,
    coreSettledOrExcluded,
    dlServerSettledOrExcluded,
    proxySubjectDefined,
    scxSettledOrExcluded,
    accountingSeparated,
    usedSchedDelayed,
    usedRetryTaskAsAuthority,
    usedClassStateAsAuthority,
    usedIdleFallbackAsAuthority,
    usedCoreCachedPickAsAuthority,
    usedDlServerAsAuthority,
    usedProxyExecutorAsAuthority,
    usedScxDispatchAsAuthority,
    behaviorPatchApproved,
    cfsDenyAndRepickApproved,
    runtimeCoverageClaim,
    monitorVerifiedClaim,
    productionProtectionClaim,
    costEfficiencyClaim,
    datacenterReadinessClaim,
    denialAfterRqCurr,
    risk

vars == <<phase, runnable, candidate, denied, ineligible, retryCount,
          retryBudget, classStateSettled, rqCurrPublished, running,
          runningTask, freshAllowedCandidate, denialRecorded,
          coreSettledOrExcluded, dlServerSettledOrExcluded,
          proxySubjectDefined, scxSettledOrExcluded, accountingSeparated,
          usedSchedDelayed, usedRetryTaskAsAuthority,
          usedClassStateAsAuthority, usedIdleFallbackAsAuthority,
          usedCoreCachedPickAsAuthority, usedDlServerAsAuthority,
          usedProxyExecutorAsAuthority, usedScxDispatchAsAuthority,
          behaviorPatchApproved, cfsDenyAndRepickApproved,
          runtimeCoverageClaim, monitorVerifiedClaim,
          productionProtectionClaim, costEfficiencyClaim,
          datacenterReadinessClaim, denialAfterRqCurr, risk>>

Tasks == {"A", "B"}
NoTask == "none"
TaskOrNone == Tasks \cup {NoTask}

RiskFields == {
    "linearCandidateSearch",
    "unboundedRetry",
    "persistentTaskStructBit",
    "persistentSchedEntityBit",
    "persistentCfsRqField",
    "persistentRqField",
    "persistentCgroupDeniedMap",
    "wakeupPreemptBleed",
    "newidleLockDropCarrierLeak",
    "staleTaskGeneration",
    "staleExecGeneration",
    "staleDomainOrGrantEpoch",
    "cgroupMutationUnsettled",
    "singleQueuedDeniedBypass",
    "buddyBypass",
    "protectedCurrentBypass",
    "leftmostBypass",
    "heapSearchBypass",
    "finalCurrOverrideBypass",
    "dlServerRetryTaskLeak",
    "rqDlServerUnclearedOnRetry",
    "delayedDequeuePointerLeak",
    "throttleLimboAlias",
    "coreSeqMismatchUncleared",
    "hotplugOfflineLeak",
    "linuxLocalSchedExecAuthority",
    "deniedReceiptPositiveAuthority",
    "traceOrTestAuthority",
    "bpfAuthority",
    "cfsPickerStateAuthority",
    "coreEnabledWithoutSettlement",
    "proxyEnabledWithoutSettlement",
    "scxEnabledWithoutSettlement",
    "dlServerEnabledWithoutSettlement"
}

BaseRisk ==
    [ linearCandidateSearch |-> FALSE,
      unboundedRetry |-> FALSE,
      persistentTaskStructBit |-> FALSE,
      persistentSchedEntityBit |-> FALSE,
      persistentCfsRqField |-> FALSE,
      persistentRqField |-> FALSE,
      persistentCgroupDeniedMap |-> FALSE,
      wakeupPreemptBleed |-> FALSE,
      newidleLockDropCarrierLeak |-> FALSE,
      staleTaskGeneration |-> FALSE,
      staleExecGeneration |-> FALSE,
      staleDomainOrGrantEpoch |-> FALSE,
      cgroupMutationUnsettled |-> FALSE,
      singleQueuedDeniedBypass |-> FALSE,
      buddyBypass |-> FALSE,
      protectedCurrentBypass |-> FALSE,
      leftmostBypass |-> FALSE,
      heapSearchBypass |-> FALSE,
      finalCurrOverrideBypass |-> FALSE,
      dlServerRetryTaskLeak |-> FALSE,
      rqDlServerUnclearedOnRetry |-> FALSE,
      delayedDequeuePointerLeak |-> FALSE,
      throttleLimboAlias |-> FALSE,
      coreSeqMismatchUncleared |-> FALSE,
      hotplugOfflineLeak |-> FALSE,
      linuxLocalSchedExecAuthority |-> FALSE,
      deniedReceiptPositiveAuthority |-> FALSE,
      traceOrTestAuthority |-> FALSE,
      bpfAuthority |-> FALSE,
      cfsPickerStateAuthority |-> FALSE,
      coreEnabledWithoutSettlement |-> FALSE,
      proxyEnabledWithoutSettlement |-> FALSE,
      scxEnabledWithoutSettlement |-> FALSE,
      dlServerEnabledWithoutSettlement |-> FALSE ]

Phases == {
    "Start",
    "PickedDenied",
    "Denied",
    "PickedAllowed",
    "Running",
    "BadRunDeniedCandidate",
    "BadRetryWithoutIneligible",
    "BadRetryBudgetIgnored",
    "BadCommitDeniedCandidate",
    "BadDenyAfterRqCurr",
    "BadSchedDelayedSubstitution",
    "BadRetryTaskAuthority",
    "BadClassStateAuthority",
    "BadIdleFallbackAuthority",
    "BadCoreCachedPickAuthority",
    "BadDlServerAuthority",
    "BadProxyAuthority",
    "BadScxAuthority",
    "BadCrossPathUnsettled",
    "BadAccountingCollapse",
    "BadOverclaim",
    "BadUnboundedOrLinearSearch",
    "BadPersistentHotLayout",
    "BadWakeupPreemptBleed",
    "BadNewidleLockDropLeak",
    "BadStaleGenerationOrEpoch",
    "BadHierarchyMutationUnsettled",
    "BadEevdfReturnUncovered",
    "BadDlServerRetryLeak",
    "BadLifetimeAlias",
    "BadCoreSeqHotplugLeak",
    "BadLinuxLocalAuthorityForgery",
    "BadUnsupportedConfigClaim"
}

Base ==
    [ phase |-> "Start",
      runnable |-> Tasks,
      candidate |-> NoTask,
      denied |-> NoTask,
      ineligible |-> {},
      retryCount |-> 0,
      retryBudget |-> 2,
      classStateSettled |-> FALSE,
      rqCurrPublished |-> FALSE,
      running |-> FALSE,
      runningTask |-> NoTask,
      freshAllowedCandidate |-> NoTask,
      denialRecorded |-> FALSE,
      coreSettledOrExcluded |-> TRUE,
      dlServerSettledOrExcluded |-> TRUE,
      proxySubjectDefined |-> TRUE,
      scxSettledOrExcluded |-> TRUE,
      accountingSeparated |-> TRUE,
      usedSchedDelayed |-> FALSE,
      usedRetryTaskAsAuthority |-> FALSE,
      usedClassStateAsAuthority |-> FALSE,
      usedIdleFallbackAsAuthority |-> FALSE,
      usedCoreCachedPickAsAuthority |-> FALSE,
      usedDlServerAsAuthority |-> FALSE,
      usedProxyExecutorAsAuthority |-> FALSE,
      usedScxDispatchAsAuthority |-> FALSE,
      behaviorPatchApproved |-> FALSE,
      cfsDenyAndRepickApproved |-> FALSE,
      runtimeCoverageClaim |-> FALSE,
      monitorVerifiedClaim |-> FALSE,
      productionProtectionClaim |-> FALSE,
      costEfficiencyClaim |-> FALSE,
      datacenterReadinessClaim |-> FALSE,
      denialAfterRqCurr |-> FALSE ]

SetState(s) ==
    /\ phase = s.phase
    /\ runnable = s.runnable
    /\ candidate = s.candidate
    /\ denied = s.denied
    /\ ineligible = s.ineligible
    /\ retryCount = s.retryCount
    /\ retryBudget = s.retryBudget
    /\ classStateSettled = s.classStateSettled
    /\ rqCurrPublished = s.rqCurrPublished
    /\ running = s.running
    /\ runningTask = s.runningTask
    /\ freshAllowedCandidate = s.freshAllowedCandidate
    /\ denialRecorded = s.denialRecorded
    /\ coreSettledOrExcluded = s.coreSettledOrExcluded
    /\ dlServerSettledOrExcluded = s.dlServerSettledOrExcluded
    /\ proxySubjectDefined = s.proxySubjectDefined
    /\ scxSettledOrExcluded = s.scxSettledOrExcluded
    /\ accountingSeparated = s.accountingSeparated
    /\ usedSchedDelayed = s.usedSchedDelayed
    /\ usedRetryTaskAsAuthority = s.usedRetryTaskAsAuthority
    /\ usedClassStateAsAuthority = s.usedClassStateAsAuthority
    /\ usedIdleFallbackAsAuthority = s.usedIdleFallbackAsAuthority
    /\ usedCoreCachedPickAsAuthority = s.usedCoreCachedPickAsAuthority
    /\ usedDlServerAsAuthority = s.usedDlServerAsAuthority
    /\ usedProxyExecutorAsAuthority = s.usedProxyExecutorAsAuthority
    /\ usedScxDispatchAsAuthority = s.usedScxDispatchAsAuthority
    /\ behaviorPatchApproved = s.behaviorPatchApproved
    /\ cfsDenyAndRepickApproved = s.cfsDenyAndRepickApproved
    /\ runtimeCoverageClaim = s.runtimeCoverageClaim
    /\ monitorVerifiedClaim = s.monitorVerifiedClaim
    /\ productionProtectionClaim = s.productionProtectionClaim
    /\ costEfficiencyClaim = s.costEfficiencyClaim
    /\ datacenterReadinessClaim = s.datacenterReadinessClaim
    /\ denialAfterRqCurr = s.denialAfterRqCurr

Init == SetState(Base) /\ risk = BaseRisk

PickDeniedCandidate ==
    /\ phase = "Start"
    /\ "A" \in runnable
    /\ candidate' = "A"
    /\ phase' = "PickedDenied"
    /\ UNCHANGED <<runnable, denied, ineligible, retryCount, retryBudget,
                    classStateSettled, rqCurrPublished, running, runningTask,
                    freshAllowedCandidate, denialRecorded,
                    coreSettledOrExcluded, dlServerSettledOrExcluded,
                    proxySubjectDefined, scxSettledOrExcluded,
                    accountingSeparated, usedSchedDelayed,
                    usedRetryTaskAsAuthority, usedClassStateAsAuthority,
                    usedIdleFallbackAsAuthority, usedCoreCachedPickAsAuthority,
                    usedDlServerAsAuthority, usedProxyExecutorAsAuthority,
                    usedScxDispatchAsAuthority, behaviorPatchApproved,
                    cfsDenyAndRepickApproved, runtimeCoverageClaim,
                    monitorVerifiedClaim, productionProtectionClaim,
                    costEfficiencyClaim, datacenterReadinessClaim,
                    denialAfterRqCurr, risk>>

DenyBeforeSettlement ==
    /\ phase = "PickedDenied"
    /\ candidate = "A"
    /\ retryCount < retryBudget
    /\ ~classStateSettled
    /\ ~rqCurrPublished
    /\ denied' = candidate
    /\ ineligible' = ineligible \cup {candidate}
    /\ retryCount' = retryCount + 1
    /\ candidate' = NoTask
    /\ denialRecorded' = TRUE
    /\ phase' = "Denied"
    /\ UNCHANGED <<runnable, retryBudget, classStateSettled, rqCurrPublished,
                    running, runningTask, freshAllowedCandidate,
                    coreSettledOrExcluded, dlServerSettledOrExcluded,
                    proxySubjectDefined, scxSettledOrExcluded,
                    accountingSeparated, usedSchedDelayed,
                    usedRetryTaskAsAuthority, usedClassStateAsAuthority,
                    usedIdleFallbackAsAuthority, usedCoreCachedPickAsAuthority,
                    usedDlServerAsAuthority, usedProxyExecutorAsAuthority,
                    usedScxDispatchAsAuthority, behaviorPatchApproved,
                    cfsDenyAndRepickApproved, runtimeCoverageClaim,
                    monitorVerifiedClaim, productionProtectionClaim,
                    costEfficiencyClaim, datacenterReadinessClaim,
                    denialAfterRqCurr, risk>>

PickAllowedAfterRetry ==
    /\ phase = "Denied"
    /\ denied \in ineligible
    /\ "B" \in (runnable \ ineligible)
    /\ candidate' = "B"
    /\ freshAllowedCandidate' = "B"
    /\ phase' = "PickedAllowed"
    /\ UNCHANGED <<runnable, denied, ineligible, retryCount, retryBudget,
                    classStateSettled, rqCurrPublished, running, runningTask,
                    denialRecorded, coreSettledOrExcluded,
                    dlServerSettledOrExcluded, proxySubjectDefined,
                    scxSettledOrExcluded, accountingSeparated,
                    usedSchedDelayed, usedRetryTaskAsAuthority,
                    usedClassStateAsAuthority, usedIdleFallbackAsAuthority,
                    usedCoreCachedPickAsAuthority, usedDlServerAsAuthority,
                    usedProxyExecutorAsAuthority, usedScxDispatchAsAuthority,
                    behaviorPatchApproved, cfsDenyAndRepickApproved,
                    runtimeCoverageClaim, monitorVerifiedClaim,
                    productionProtectionClaim, costEfficiencyClaim,
                    datacenterReadinessClaim, denialAfterRqCurr, risk>>

CommitAllowedCandidate ==
    /\ phase = "PickedAllowed"
    /\ candidate = freshAllowedCandidate
    /\ candidate \in (runnable \ ineligible)
    /\ coreSettledOrExcluded
    /\ dlServerSettledOrExcluded
    /\ proxySubjectDefined
    /\ scxSettledOrExcluded
    /\ accountingSeparated
    /\ classStateSettled' = TRUE
    /\ rqCurrPublished' = TRUE
    /\ running' = TRUE
    /\ runningTask' = candidate
    /\ phase' = "Running"
    /\ UNCHANGED <<runnable, candidate, denied, ineligible, retryCount,
                    retryBudget, freshAllowedCandidate, denialRecorded,
                    coreSettledOrExcluded, dlServerSettledOrExcluded,
                    proxySubjectDefined, scxSettledOrExcluded,
                    accountingSeparated, usedSchedDelayed,
                    usedRetryTaskAsAuthority, usedClassStateAsAuthority,
                    usedIdleFallbackAsAuthority, usedCoreCachedPickAsAuthority,
                    usedDlServerAsAuthority, usedProxyExecutorAsAuthority,
                    usedScxDispatchAsAuthority, behaviorPatchApproved,
                    cfsDenyAndRepickApproved, runtimeCoverageClaim,
                    monitorVerifiedClaim, productionProtectionClaim,
                    costEfficiencyClaim, datacenterReadinessClaim,
                    denialAfterRqCurr, risk>>

StutterAfterRunning ==
    /\ phase = "Running"
    /\ UNCHANGED vars

Next ==
    \/ PickDeniedCandidate
    \/ DenyBeforeSettlement
    \/ PickAllowedAfterRetry
    \/ CommitAllowedCandidate
    \/ StutterAfterRunning

SafeSpec == Init /\ [][Next]_vars

UnsafeRunDeniedCandidateSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadRunDeniedCandidate",
                             !.denied = "A",
                             !.ineligible = {"A"},
                             !.classStateSettled = TRUE,
                             !.rqCurrPublished = TRUE,
                             !.running = TRUE,
                             !.runningTask = "A"])
    /\ risk = BaseRisk
    /\ [][UNCHANGED vars]_vars

UnsafeRetryWithoutIneligibleSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadRetryWithoutIneligible",
                             !.denied = "A",
                             !.retryCount = 1,
                             !.denialRecorded = TRUE])
    /\ risk = BaseRisk
    /\ [][UNCHANGED vars]_vars

UnsafeRetryBudgetIgnoredSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadRetryBudgetIgnored",
                             !.retryCount = 3,
                             !.retryBudget = 2])
    /\ risk = BaseRisk
    /\ [][UNCHANGED vars]_vars

UnsafeCommitDeniedCandidateSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadCommitDeniedCandidate",
                             !.candidate = "A",
                             !.denied = "A",
                             !.ineligible = {"A"},
                             !.freshAllowedCandidate = "A",
                             !.classStateSettled = TRUE])
    /\ risk = BaseRisk
    /\ [][UNCHANGED vars]_vars

UnsafeDenyAfterRqCurrSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadDenyAfterRqCurr",
                             !.denied = "A",
                             !.denialRecorded = TRUE,
                             !.rqCurrPublished = TRUE,
                             !.denialAfterRqCurr = TRUE])
    /\ risk = BaseRisk
    /\ [][UNCHANGED vars]_vars

UnsafeSchedDelayedSubstitutionSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadSchedDelayedSubstitution",
                             !.usedSchedDelayed = TRUE])
    /\ risk = BaseRisk
    /\ [][UNCHANGED vars]_vars

UnsafeRetryTaskAuthoritySpec ==
    /\ SetState([Base EXCEPT !.phase = "BadRetryTaskAuthority",
                             !.usedRetryTaskAsAuthority = TRUE])
    /\ risk = BaseRisk
    /\ [][UNCHANGED vars]_vars

UnsafeClassStateAuthoritySpec ==
    /\ SetState([Base EXCEPT !.phase = "BadClassStateAuthority",
                             !.usedClassStateAsAuthority = TRUE])
    /\ risk = BaseRisk
    /\ [][UNCHANGED vars]_vars

UnsafeIdleFallbackAuthoritySpec ==
    /\ SetState([Base EXCEPT !.phase = "BadIdleFallbackAuthority",
                             !.usedIdleFallbackAsAuthority = TRUE])
    /\ risk = BaseRisk
    /\ [][UNCHANGED vars]_vars

UnsafeCoreCachedPickAuthoritySpec ==
    /\ SetState([Base EXCEPT !.phase = "BadCoreCachedPickAuthority",
                             !.usedCoreCachedPickAsAuthority = TRUE])
    /\ risk = BaseRisk
    /\ [][UNCHANGED vars]_vars

UnsafeDlServerAuthoritySpec ==
    /\ SetState([Base EXCEPT !.phase = "BadDlServerAuthority",
                             !.usedDlServerAsAuthority = TRUE])
    /\ risk = BaseRisk
    /\ [][UNCHANGED vars]_vars

UnsafeProxyAuthoritySpec ==
    /\ SetState([Base EXCEPT !.phase = "BadProxyAuthority",
                             !.usedProxyExecutorAsAuthority = TRUE])
    /\ risk = BaseRisk
    /\ [][UNCHANGED vars]_vars

UnsafeScxAuthoritySpec ==
    /\ SetState([Base EXCEPT !.phase = "BadScxAuthority",
                             !.usedScxDispatchAsAuthority = TRUE])
    /\ risk = BaseRisk
    /\ [][UNCHANGED vars]_vars

UnsafeCrossPathUnsettledSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadCrossPathUnsettled",
                             !.coreSettledOrExcluded = FALSE,
                             !.dlServerSettledOrExcluded = FALSE,
                             !.proxySubjectDefined = FALSE,
                             !.scxSettledOrExcluded = FALSE])
    /\ risk = BaseRisk
    /\ [][UNCHANGED vars]_vars

UnsafeAccountingCollapseSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadAccountingCollapse",
                             !.accountingSeparated = FALSE])
    /\ risk = BaseRisk
    /\ [][UNCHANGED vars]_vars

UnsafeOverclaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadOverclaim",
                             !.behaviorPatchApproved = TRUE,
                             !.cfsDenyAndRepickApproved = TRUE,
                             !.runtimeCoverageClaim = TRUE,
                             !.monitorVerifiedClaim = TRUE,
                             !.productionProtectionClaim = TRUE,
                             !.costEfficiencyClaim = TRUE,
                             !.datacenterReadinessClaim = TRUE])
    /\ risk = BaseRisk
    /\ [][UNCHANGED vars]_vars

UnsafeUnboundedOrLinearSearchSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadUnboundedOrLinearSearch"])
    /\ risk = [BaseRisk EXCEPT !.linearCandidateSearch = TRUE,
                               !.unboundedRetry = TRUE]
    /\ [][UNCHANGED vars]_vars

UnsafePersistentHotLayoutSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadPersistentHotLayout"])
    /\ risk = [BaseRisk EXCEPT !.persistentTaskStructBit = TRUE,
                               !.persistentSchedEntityBit = TRUE,
                               !.persistentCfsRqField = TRUE,
                               !.persistentRqField = TRUE,
                               !.persistentCgroupDeniedMap = TRUE]
    /\ [][UNCHANGED vars]_vars

UnsafeWakeupPreemptBleedSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadWakeupPreemptBleed"])
    /\ risk = [BaseRisk EXCEPT !.wakeupPreemptBleed = TRUE]
    /\ [][UNCHANGED vars]_vars

UnsafeNewidleLockDropLeakSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadNewidleLockDropLeak"])
    /\ risk = [BaseRisk EXCEPT !.newidleLockDropCarrierLeak = TRUE]
    /\ [][UNCHANGED vars]_vars

UnsafeStaleGenerationOrEpochSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadStaleGenerationOrEpoch"])
    /\ risk = [BaseRisk EXCEPT !.staleTaskGeneration = TRUE,
                               !.staleExecGeneration = TRUE,
                               !.staleDomainOrGrantEpoch = TRUE]
    /\ [][UNCHANGED vars]_vars

UnsafeHierarchyMutationUnsettledSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadHierarchyMutationUnsettled"])
    /\ risk = [BaseRisk EXCEPT !.cgroupMutationUnsettled = TRUE]
    /\ [][UNCHANGED vars]_vars

UnsafeEevdfReturnUncoveredSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadEevdfReturnUncovered"])
    /\ risk = [BaseRisk EXCEPT !.singleQueuedDeniedBypass = TRUE,
                               !.buddyBypass = TRUE,
                               !.protectedCurrentBypass = TRUE,
                               !.leftmostBypass = TRUE,
                               !.heapSearchBypass = TRUE,
                               !.finalCurrOverrideBypass = TRUE]
    /\ [][UNCHANGED vars]_vars

UnsafeDlServerRetryLeakSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadDlServerRetryLeak"])
    /\ risk = [BaseRisk EXCEPT !.dlServerRetryTaskLeak = TRUE,
                               !.rqDlServerUnclearedOnRetry = TRUE]
    /\ [][UNCHANGED vars]_vars

UnsafeLifetimeAliasSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadLifetimeAlias"])
    /\ risk = [BaseRisk EXCEPT !.delayedDequeuePointerLeak = TRUE,
                               !.throttleLimboAlias = TRUE]
    /\ [][UNCHANGED vars]_vars

UnsafeCoreSeqHotplugLeakSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadCoreSeqHotplugLeak"])
    /\ risk = [BaseRisk EXCEPT !.coreSeqMismatchUncleared = TRUE,
                               !.hotplugOfflineLeak = TRUE]
    /\ [][UNCHANGED vars]_vars

UnsafeLinuxLocalAuthorityForgerySpec ==
    /\ SetState([Base EXCEPT !.phase = "BadLinuxLocalAuthorityForgery"])
    /\ risk = [BaseRisk EXCEPT !.linuxLocalSchedExecAuthority = TRUE,
                               !.deniedReceiptPositiveAuthority = TRUE,
                               !.traceOrTestAuthority = TRUE,
                               !.bpfAuthority = TRUE,
                               !.cfsPickerStateAuthority = TRUE]
    /\ [][UNCHANGED vars]_vars

UnsafeUnsupportedConfigClaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadUnsupportedConfigClaim"])
    /\ risk = [BaseRisk EXCEPT !.coreEnabledWithoutSettlement = TRUE,
                               !.proxyEnabledWithoutSettlement = TRUE,
                               !.scxEnabledWithoutSettlement = TRUE,
                               !.dlServerEnabledWithoutSettlement = TRUE]
    /\ [][UNCHANGED vars]_vars

TypeOK ==
    /\ phase \in Phases
    /\ runnable \subseteq Tasks
    /\ candidate \in TaskOrNone
    /\ denied \in TaskOrNone
    /\ ineligible \subseteq Tasks
    /\ retryCount \in 0..3
    /\ retryBudget \in 0..2
    /\ classStateSettled \in BOOLEAN
    /\ rqCurrPublished \in BOOLEAN
    /\ running \in BOOLEAN
    /\ runningTask \in TaskOrNone
    /\ freshAllowedCandidate \in TaskOrNone
    /\ denialRecorded \in BOOLEAN
    /\ coreSettledOrExcluded \in BOOLEAN
    /\ dlServerSettledOrExcluded \in BOOLEAN
    /\ proxySubjectDefined \in BOOLEAN
    /\ scxSettledOrExcluded \in BOOLEAN
    /\ accountingSeparated \in BOOLEAN
    /\ usedSchedDelayed \in BOOLEAN
    /\ usedRetryTaskAsAuthority \in BOOLEAN
    /\ usedClassStateAsAuthority \in BOOLEAN
    /\ usedIdleFallbackAsAuthority \in BOOLEAN
    /\ usedCoreCachedPickAsAuthority \in BOOLEAN
    /\ usedDlServerAsAuthority \in BOOLEAN
    /\ usedProxyExecutorAsAuthority \in BOOLEAN
    /\ usedScxDispatchAsAuthority \in BOOLEAN
    /\ behaviorPatchApproved \in BOOLEAN
    /\ cfsDenyAndRepickApproved \in BOOLEAN
    /\ runtimeCoverageClaim \in BOOLEAN
    /\ monitorVerifiedClaim \in BOOLEAN
    /\ productionProtectionClaim \in BOOLEAN
    /\ costEfficiencyClaim \in BOOLEAN
    /\ datacenterReadinessClaim \in BOOLEAN
    /\ denialAfterRqCurr \in BOOLEAN
    /\ risk \in [RiskFields -> BOOLEAN]

NoDeniedCandidateRuns ==
    running => ~(denied # NoTask /\ runningTask = denied)

DeniedCandidateVisible ==
    (denialRecorded /\ denied # NoTask) => denied \in ineligible

RetryBounded ==
    retryCount <= retryBudget

NoDeniedCommit ==
    classStateSettled => ~(candidate \in ineligible)

NoDenyAfterRqCurr ==
    ~denialAfterRqCurr

CrossPathsSettledOrExcluded ==
    /\ coreSettledOrExcluded
    /\ dlServerSettledOrExcluded
    /\ proxySubjectDefined
    /\ scxSettledOrExcluded

NoAccountingCollapse ==
    accountingSeparated

NoForbiddenSubstitution ==
    /\ ~usedSchedDelayed
    /\ ~usedRetryTaskAsAuthority
    /\ ~usedClassStateAsAuthority
    /\ ~usedIdleFallbackAsAuthority
    /\ ~usedCoreCachedPickAsAuthority
    /\ ~usedDlServerAsAuthority
    /\ ~usedProxyExecutorAsAuthority
    /\ ~usedScxDispatchAsAuthority

NoAdditionalRisk ==
    \A f \in RiskFields: ~risk[f]

NoOverclaim ==
    /\ ~behaviorPatchApproved
    /\ ~cfsDenyAndRepickApproved
    /\ ~runtimeCoverageClaim
    /\ ~monitorVerifiedClaim
    /\ ~productionProtectionClaim
    /\ ~costEfficiencyClaim
    /\ ~datacenterReadinessClaim

Safety ==
    /\ TypeOK
    /\ NoDeniedCandidateRuns
    /\ DeniedCandidateVisible
    /\ RetryBounded
    /\ NoDeniedCommit
    /\ NoDenyAfterRqCurr
    /\ CrossPathsSettledOrExcluded
    /\ NoAccountingCollapse
    /\ NoForbiddenSubstitution
    /\ NoAdditionalRisk
    /\ NoOverclaim

====
