---------- MODULE FinalDenySourceShapeGate ----------
EXTENDS Naturals

VARIABLES
    phase,
    eligible,
    candidate,
    denied,
    retryCount,
    retryBudget,
    preSettleValidated,
    classSettled,
    rollbackProved,
    ineligibleVisible,
    retryEpochFresh,
    balanceClean,
    coreCacheInvalidated,
    scxHeadSelectable,
    proxySubjectResolved,
    rqCurrPublished,
    running,
    failClosed,
    postSettleDenyWithoutRollback,
    sameCandidateRepick,
    pickerInvisible,
    scxHeadLivelock,
    coreCachedPickBypass,
    proxySubjectMismatch,
    failClosedWithEligibleCandidate,
    retryTaskAuthority,
    idleFallbackAuthority,
    schedExtFallbackAuthority,
    behaviorChangeClaim,
    runtimeCoverageClaim,
    monitorVerifiedClaim,
    protectionClaim,
    costEfficiencyClaim

vars == <<phase, eligible, candidate, denied, retryCount, retryBudget,
          preSettleValidated, classSettled, rollbackProved,
          ineligibleVisible, retryEpochFresh, balanceClean,
          coreCacheInvalidated, scxHeadSelectable, proxySubjectResolved,
          rqCurrPublished, running, failClosed,
          postSettleDenyWithoutRollback, sameCandidateRepick,
          pickerInvisible, scxHeadLivelock, coreCachedPickBypass,
          proxySubjectMismatch, failClosedWithEligibleCandidate,
          retryTaskAuthority, idleFallbackAuthority,
          schedExtFallbackAuthority, behaviorChangeClaim,
          runtimeCoverageClaim, monitorVerifiedClaim, protectionClaim,
          costEfficiencyClaim>>

Tasks == {"A", "B"}
NoTask == "none"
TaskOrNone == Tasks \cup {NoTask}

GoodPhases == {
    "Start",
    "PickedBadPreSettle",
    "DeniedPreSettle",
    "PickedGoodPreSettle",
    "DoneRun",
    "DoneFailClosed"
}

BadPhases == {
    "BadPostSettleDenyWithoutRollback",
    "BadClassPickerInvisible",
    "BadSameCandidateRepick",
    "BadScxHeadLivelock",
    "BadCoreCachedPickBypass",
    "BadProxySubjectMismatch",
    "BadFailClosedWithEligibleCandidate",
    "BadRetryTaskAuthority",
    "BadIdleFallbackAuthority",
    "BadSchedExtFallbackAuthority",
    "BadBehaviorChangeClaim",
    "BadRuntimeCoverageClaim",
    "BadMonitorVerifiedClaim",
    "BadProtectionClaim",
    "BadCostEfficiencyClaim"
}

Phases == GoodPhases \cup BadPhases
TerminalGoodPhases == {"DoneRun", "DoneFailClosed"}
EligibleNow == eligible \ denied

TypeOK ==
    /\ phase \in Phases
    /\ eligible \subseteq Tasks
    /\ candidate \in TaskOrNone
    /\ denied \subseteq Tasks
    /\ retryCount \in 0..3
    /\ retryBudget \in 0..2
    /\ preSettleValidated \in BOOLEAN
    /\ classSettled \in BOOLEAN
    /\ rollbackProved \in BOOLEAN
    /\ ineligibleVisible \in BOOLEAN
    /\ retryEpochFresh \in BOOLEAN
    /\ balanceClean \in BOOLEAN
    /\ coreCacheInvalidated \in BOOLEAN
    /\ scxHeadSelectable \in BOOLEAN
    /\ proxySubjectResolved \in BOOLEAN
    /\ rqCurrPublished \in BOOLEAN
    /\ running \in BOOLEAN
    /\ failClosed \in BOOLEAN
    /\ postSettleDenyWithoutRollback \in BOOLEAN
    /\ sameCandidateRepick \in BOOLEAN
    /\ pickerInvisible \in BOOLEAN
    /\ scxHeadLivelock \in BOOLEAN
    /\ coreCachedPickBypass \in BOOLEAN
    /\ proxySubjectMismatch \in BOOLEAN
    /\ failClosedWithEligibleCandidate \in BOOLEAN
    /\ retryTaskAuthority \in BOOLEAN
    /\ idleFallbackAuthority \in BOOLEAN
    /\ schedExtFallbackAuthority \in BOOLEAN
    /\ behaviorChangeClaim \in BOOLEAN
    /\ runtimeCoverageClaim \in BOOLEAN
    /\ monitorVerifiedClaim \in BOOLEAN
    /\ protectionClaim \in BOOLEAN
    /\ costEfficiencyClaim \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ eligible = Tasks
    /\ candidate = NoTask
    /\ denied = {}
    /\ retryCount = 0
    /\ retryBudget = 2
    /\ preSettleValidated = FALSE
    /\ classSettled = FALSE
    /\ rollbackProved = FALSE
    /\ ineligibleVisible = FALSE
    /\ retryEpochFresh = FALSE
    /\ balanceClean = TRUE
    /\ coreCacheInvalidated = TRUE
    /\ scxHeadSelectable = FALSE
    /\ proxySubjectResolved = TRUE
    /\ rqCurrPublished = FALSE
    /\ running = FALSE
    /\ failClosed = FALSE
    /\ postSettleDenyWithoutRollback = FALSE
    /\ sameCandidateRepick = FALSE
    /\ pickerInvisible = FALSE
    /\ scxHeadLivelock = FALSE
    /\ coreCachedPickBypass = FALSE
    /\ proxySubjectMismatch = FALSE
    /\ failClosedWithEligibleCandidate = FALSE
    /\ retryTaskAuthority = FALSE
    /\ idleFallbackAuthority = FALSE
    /\ schedExtFallbackAuthority = FALSE
    /\ behaviorChangeClaim = FALSE
    /\ runtimeCoverageClaim = FALSE
    /\ monitorVerifiedClaim = FALSE
    /\ protectionClaim = FALSE
    /\ costEfficiencyClaim = FALSE

PickBadPreSettle ==
    /\ phase = "Start"
    /\ "A" \in eligible
    /\ candidate' = "A"
    /\ preSettleValidated' = TRUE
    /\ classSettled' = FALSE
    /\ phase' = "PickedBadPreSettle"
    /\ UNCHANGED <<eligible, denied, retryCount, retryBudget,
                    rollbackProved, ineligibleVisible, retryEpochFresh,
                    balanceClean, coreCacheInvalidated, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    failClosed, postSettleDenyWithoutRollback,
                    sameCandidateRepick, pickerInvisible, scxHeadLivelock,
                    coreCachedPickBypass, proxySubjectMismatch,
                    failClosedWithEligibleCandidate, retryTaskAuthority,
                    idleFallbackAuthority, schedExtFallbackAuthority,
                    behaviorChangeClaim, runtimeCoverageClaim,
                    monitorVerifiedClaim, protectionClaim,
                    costEfficiencyClaim>>

PickOnlyBadPreSettle ==
    /\ phase = "Start"
    /\ eligible' = {"A"}
    /\ candidate' = "A"
    /\ preSettleValidated' = TRUE
    /\ classSettled' = FALSE
    /\ phase' = "PickedBadPreSettle"
    /\ UNCHANGED <<denied, retryCount, retryBudget, rollbackProved,
                    ineligibleVisible, retryEpochFresh, balanceClean,
                    coreCacheInvalidated, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    failClosed, postSettleDenyWithoutRollback,
                    sameCandidateRepick, pickerInvisible, scxHeadLivelock,
                    coreCachedPickBypass, proxySubjectMismatch,
                    failClosedWithEligibleCandidate, retryTaskAuthority,
                    idleFallbackAuthority, schedExtFallbackAuthority,
                    behaviorChangeClaim, runtimeCoverageClaim,
                    monitorVerifiedClaim, protectionClaim,
                    costEfficiencyClaim>>

DenyBeforeSettlement ==
    /\ phase = "PickedBadPreSettle"
    /\ candidate = "A"
    /\ preSettleValidated
    /\ ~classSettled
    /\ retryCount < retryBudget
    /\ denied' = denied \cup {candidate}
    /\ retryCount' = retryCount + 1
    /\ ineligibleVisible' = TRUE
    /\ retryEpochFresh' = TRUE
    /\ balanceClean' = TRUE
    /\ coreCacheInvalidated' = TRUE
    /\ scxHeadSelectable' = FALSE
    /\ proxySubjectResolved' = TRUE
    /\ phase' = "DeniedPreSettle"
    /\ UNCHANGED <<eligible, candidate, retryBudget, preSettleValidated,
                    classSettled, rollbackProved, rqCurrPublished, running,
                    failClosed, postSettleDenyWithoutRollback,
                    sameCandidateRepick, pickerInvisible, scxHeadLivelock,
                    coreCachedPickBypass, proxySubjectMismatch,
                    failClosedWithEligibleCandidate, retryTaskAuthority,
                    idleFallbackAuthority, schedExtFallbackAuthority,
                    behaviorChangeClaim, runtimeCoverageClaim,
                    monitorVerifiedClaim, protectionClaim,
                    costEfficiencyClaim>>

RetryPickGood ==
    /\ phase = "DeniedPreSettle"
    /\ "B" \in EligibleNow
    /\ ineligibleVisible
    /\ retryEpochFresh
    /\ balanceClean
    /\ coreCacheInvalidated
    /\ proxySubjectResolved
    /\ ~scxHeadSelectable
    /\ candidate' = "B"
    /\ preSettleValidated' = TRUE
    /\ phase' = "PickedGoodPreSettle"
    /\ UNCHANGED <<eligible, denied, retryCount, retryBudget, classSettled,
                    rollbackProved, ineligibleVisible, retryEpochFresh,
                    balanceClean, coreCacheInvalidated, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    failClosed, postSettleDenyWithoutRollback,
                    sameCandidateRepick, pickerInvisible, scxHeadLivelock,
                    coreCachedPickBypass, proxySubjectMismatch,
                    failClosedWithEligibleCandidate, retryTaskAuthority,
                    idleFallbackAuthority, schedExtFallbackAuthority,
                    behaviorChangeClaim, runtimeCoverageClaim,
                    monitorVerifiedClaim, protectionClaim,
                    costEfficiencyClaim>>

CommitGood ==
    /\ phase = "PickedGoodPreSettle"
    /\ candidate = "B"
    /\ candidate \notin denied
    /\ preSettleValidated
    /\ classSettled' = TRUE
    /\ rqCurrPublished' = TRUE
    /\ running' = TRUE
    /\ phase' = "DoneRun"
    /\ UNCHANGED <<eligible, candidate, denied, retryCount, retryBudget,
                    preSettleValidated, rollbackProved, ineligibleVisible,
                    retryEpochFresh, balanceClean, coreCacheInvalidated,
                    scxHeadSelectable, proxySubjectResolved, failClosed,
                    postSettleDenyWithoutRollback, sameCandidateRepick,
                    pickerInvisible, scxHeadLivelock, coreCachedPickBypass,
                    proxySubjectMismatch, failClosedWithEligibleCandidate,
                    retryTaskAuthority, idleFallbackAuthority,
                    schedExtFallbackAuthority, behaviorChangeClaim,
                    runtimeCoverageClaim, monitorVerifiedClaim,
                    protectionClaim, costEfficiencyClaim>>

FailClosedAfterExhaustion ==
    /\ phase = "DeniedPreSettle"
    /\ EligibleNow = {}
    /\ ineligibleVisible
    /\ retryEpochFresh
    /\ balanceClean
    /\ coreCacheInvalidated
    /\ failClosed' = TRUE
    /\ phase' = "DoneFailClosed"
    /\ UNCHANGED <<eligible, candidate, denied, retryCount, retryBudget,
                    preSettleValidated, classSettled, rollbackProved,
                    ineligibleVisible, retryEpochFresh, balanceClean,
                    coreCacheInvalidated, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    postSettleDenyWithoutRollback, sameCandidateRepick,
                    pickerInvisible, scxHeadLivelock, coreCachedPickBypass,
                    proxySubjectMismatch, failClosedWithEligibleCandidate,
                    retryTaskAuthority, idleFallbackAuthority,
                    schedExtFallbackAuthority, behaviorChangeClaim,
                    runtimeCoverageClaim, monitorVerifiedClaim,
                    protectionClaim, costEfficiencyClaim>>

TerminalStutter ==
    /\ phase \in TerminalGoodPhases
    /\ UNCHANGED vars

Next ==
    \/ PickBadPreSettle
    \/ PickOnlyBadPreSettle
    \/ DenyBeforeSettlement
    \/ RetryPickGood
    \/ CommitGood
    \/ FailClosedAfterExhaustion
    \/ TerminalStutter

UnsafePostSettleDenyWithoutRollback ==
    /\ phase = "Start"
    /\ candidate' = "A"
    /\ classSettled' = TRUE
    /\ rollbackProved' = FALSE
    /\ postSettleDenyWithoutRollback' = TRUE
    /\ phase' = "BadPostSettleDenyWithoutRollback"
    /\ UNCHANGED <<eligible, denied, retryCount, retryBudget,
                    preSettleValidated, ineligibleVisible, retryEpochFresh,
                    balanceClean, coreCacheInvalidated, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    failClosed, sameCandidateRepick, pickerInvisible,
                    scxHeadLivelock, coreCachedPickBypass,
                    proxySubjectMismatch, failClosedWithEligibleCandidate,
                    retryTaskAuthority, idleFallbackAuthority,
                    schedExtFallbackAuthority, behaviorChangeClaim,
                    runtimeCoverageClaim, monitorVerifiedClaim,
                    protectionClaim, costEfficiencyClaim>>

UnsafeClassPickerInvisible ==
    /\ phase = "Start"
    /\ candidate' = "A"
    /\ denied' = {"A"}
    /\ ineligibleVisible' = FALSE
    /\ pickerInvisible' = TRUE
    /\ phase' = "BadClassPickerInvisible"
    /\ UNCHANGED <<eligible, retryCount, retryBudget, preSettleValidated,
                    classSettled, rollbackProved, retryEpochFresh,
                    balanceClean, coreCacheInvalidated, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    failClosed, postSettleDenyWithoutRollback,
                    sameCandidateRepick, scxHeadLivelock,
                    coreCachedPickBypass, proxySubjectMismatch,
                    failClosedWithEligibleCandidate, retryTaskAuthority,
                    idleFallbackAuthority, schedExtFallbackAuthority,
                    behaviorChangeClaim, runtimeCoverageClaim,
                    monitorVerifiedClaim, protectionClaim,
                    costEfficiencyClaim>>

UnsafeSameCandidateRepick ==
    /\ phase = "Start"
    /\ candidate' = "A"
    /\ denied' = {"A"}
    /\ ineligibleVisible' = TRUE
    /\ sameCandidateRepick' = TRUE
    /\ phase' = "BadSameCandidateRepick"
    /\ UNCHANGED <<eligible, retryCount, retryBudget, preSettleValidated,
                    classSettled, rollbackProved, retryEpochFresh,
                    balanceClean, coreCacheInvalidated, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    failClosed, postSettleDenyWithoutRollback,
                    pickerInvisible, scxHeadLivelock, coreCachedPickBypass,
                    proxySubjectMismatch, failClosedWithEligibleCandidate,
                    retryTaskAuthority, idleFallbackAuthority,
                    schedExtFallbackAuthority, behaviorChangeClaim,
                    runtimeCoverageClaim, monitorVerifiedClaim,
                    protectionClaim, costEfficiencyClaim>>

UnsafeScxHeadLivelock ==
    /\ phase = "Start"
    /\ candidate' = "A"
    /\ denied' = {"A"}
    /\ ineligibleVisible' = TRUE
    /\ scxHeadSelectable' = TRUE
    /\ scxHeadLivelock' = TRUE
    /\ phase' = "BadScxHeadLivelock"
    /\ UNCHANGED <<eligible, retryCount, retryBudget, preSettleValidated,
                    classSettled, rollbackProved, retryEpochFresh,
                    balanceClean, coreCacheInvalidated, proxySubjectResolved,
                    rqCurrPublished, running, failClosed,
                    postSettleDenyWithoutRollback, sameCandidateRepick,
                    pickerInvisible, coreCachedPickBypass,
                    proxySubjectMismatch, failClosedWithEligibleCandidate,
                    retryTaskAuthority, idleFallbackAuthority,
                    schedExtFallbackAuthority, behaviorChangeClaim,
                    runtimeCoverageClaim, monitorVerifiedClaim,
                    protectionClaim, costEfficiencyClaim>>

UnsafeCoreCachedPickBypass ==
    /\ phase = "Start"
    /\ candidate' = "A"
    /\ denied' = {"A"}
    /\ coreCacheInvalidated' = FALSE
    /\ coreCachedPickBypass' = TRUE
    /\ phase' = "BadCoreCachedPickBypass"
    /\ UNCHANGED <<eligible, retryCount, retryBudget, preSettleValidated,
                    classSettled, rollbackProved, ineligibleVisible,
                    retryEpochFresh, balanceClean, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    failClosed, postSettleDenyWithoutRollback,
                    sameCandidateRepick, pickerInvisible, scxHeadLivelock,
                    proxySubjectMismatch, failClosedWithEligibleCandidate,
                    retryTaskAuthority, idleFallbackAuthority,
                    schedExtFallbackAuthority, behaviorChangeClaim,
                    runtimeCoverageClaim, monitorVerifiedClaim,
                    protectionClaim, costEfficiencyClaim>>

UnsafeProxySubjectMismatch ==
    /\ phase = "Start"
    /\ candidate' = "A"
    /\ proxySubjectResolved' = FALSE
    /\ proxySubjectMismatch' = TRUE
    /\ phase' = "BadProxySubjectMismatch"
    /\ UNCHANGED <<eligible, denied, retryCount, retryBudget,
                    preSettleValidated, classSettled, rollbackProved,
                    ineligibleVisible, retryEpochFresh, balanceClean,
                    coreCacheInvalidated, scxHeadSelectable, rqCurrPublished,
                    running, failClosed, postSettleDenyWithoutRollback,
                    sameCandidateRepick, pickerInvisible, scxHeadLivelock,
                    coreCachedPickBypass, failClosedWithEligibleCandidate,
                    retryTaskAuthority, idleFallbackAuthority,
                    schedExtFallbackAuthority, behaviorChangeClaim,
                    runtimeCoverageClaim, monitorVerifiedClaim,
                    protectionClaim, costEfficiencyClaim>>

UnsafeFailClosedWithEligibleCandidate ==
    /\ phase = "Start"
    /\ denied' = {"A"}
    /\ failClosed' = TRUE
    /\ failClosedWithEligibleCandidate' = TRUE
    /\ phase' = "BadFailClosedWithEligibleCandidate"
    /\ UNCHANGED <<eligible, candidate, retryCount, retryBudget,
                    preSettleValidated, classSettled, rollbackProved,
                    ineligibleVisible, retryEpochFresh, balanceClean,
                    coreCacheInvalidated, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    postSettleDenyWithoutRollback, sameCandidateRepick,
                    pickerInvisible, scxHeadLivelock, coreCachedPickBypass,
                    proxySubjectMismatch, retryTaskAuthority,
                    idleFallbackAuthority, schedExtFallbackAuthority,
                    behaviorChangeClaim, runtimeCoverageClaim,
                    monitorVerifiedClaim, protectionClaim,
                    costEfficiencyClaim>>

UnsafeRetryTaskAuthority ==
    /\ phase = "Start"
    /\ retryTaskAuthority' = TRUE
    /\ phase' = "BadRetryTaskAuthority"
    /\ UNCHANGED <<eligible, candidate, denied, retryCount, retryBudget,
                    preSettleValidated, classSettled, rollbackProved,
                    ineligibleVisible, retryEpochFresh, balanceClean,
                    coreCacheInvalidated, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    failClosed, postSettleDenyWithoutRollback,
                    sameCandidateRepick, pickerInvisible, scxHeadLivelock,
                    coreCachedPickBypass, proxySubjectMismatch,
                    failClosedWithEligibleCandidate, idleFallbackAuthority,
                    schedExtFallbackAuthority, behaviorChangeClaim,
                    runtimeCoverageClaim, monitorVerifiedClaim,
                    protectionClaim, costEfficiencyClaim>>

UnsafeIdleFallbackAuthority ==
    /\ phase = "Start"
    /\ idleFallbackAuthority' = TRUE
    /\ phase' = "BadIdleFallbackAuthority"
    /\ UNCHANGED <<eligible, candidate, denied, retryCount, retryBudget,
                    preSettleValidated, classSettled, rollbackProved,
                    ineligibleVisible, retryEpochFresh, balanceClean,
                    coreCacheInvalidated, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    failClosed, postSettleDenyWithoutRollback,
                    sameCandidateRepick, pickerInvisible, scxHeadLivelock,
                    coreCachedPickBypass, proxySubjectMismatch,
                    failClosedWithEligibleCandidate, retryTaskAuthority,
                    schedExtFallbackAuthority, behaviorChangeClaim,
                    runtimeCoverageClaim, monitorVerifiedClaim,
                    protectionClaim, costEfficiencyClaim>>

UnsafeSchedExtFallbackAuthority ==
    /\ phase = "Start"
    /\ schedExtFallbackAuthority' = TRUE
    /\ phase' = "BadSchedExtFallbackAuthority"
    /\ UNCHANGED <<eligible, candidate, denied, retryCount, retryBudget,
                    preSettleValidated, classSettled, rollbackProved,
                    ineligibleVisible, retryEpochFresh, balanceClean,
                    coreCacheInvalidated, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    failClosed, postSettleDenyWithoutRollback,
                    sameCandidateRepick, pickerInvisible, scxHeadLivelock,
                    coreCachedPickBypass, proxySubjectMismatch,
                    failClosedWithEligibleCandidate, retryTaskAuthority,
                    idleFallbackAuthority, behaviorChangeClaim,
                    runtimeCoverageClaim, monitorVerifiedClaim,
                    protectionClaim, costEfficiencyClaim>>

UnsafeBehaviorChangeClaim ==
    /\ phase = "Start"
    /\ behaviorChangeClaim' = TRUE
    /\ phase' = "BadBehaviorChangeClaim"
    /\ UNCHANGED <<eligible, candidate, denied, retryCount, retryBudget,
                    preSettleValidated, classSettled, rollbackProved,
                    ineligibleVisible, retryEpochFresh, balanceClean,
                    coreCacheInvalidated, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    failClosed, postSettleDenyWithoutRollback,
                    sameCandidateRepick, pickerInvisible, scxHeadLivelock,
                    coreCachedPickBypass, proxySubjectMismatch,
                    failClosedWithEligibleCandidate, retryTaskAuthority,
                    idleFallbackAuthority, schedExtFallbackAuthority,
                    runtimeCoverageClaim, monitorVerifiedClaim,
                    protectionClaim, costEfficiencyClaim>>

UnsafeRuntimeCoverageClaim ==
    /\ phase = "Start"
    /\ runtimeCoverageClaim' = TRUE
    /\ phase' = "BadRuntimeCoverageClaim"
    /\ UNCHANGED <<eligible, candidate, denied, retryCount, retryBudget,
                    preSettleValidated, classSettled, rollbackProved,
                    ineligibleVisible, retryEpochFresh, balanceClean,
                    coreCacheInvalidated, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    failClosed, postSettleDenyWithoutRollback,
                    sameCandidateRepick, pickerInvisible, scxHeadLivelock,
                    coreCachedPickBypass, proxySubjectMismatch,
                    failClosedWithEligibleCandidate, retryTaskAuthority,
                    idleFallbackAuthority, schedExtFallbackAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim, costEfficiencyClaim>>

UnsafeMonitorVerifiedClaim ==
    /\ phase = "Start"
    /\ monitorVerifiedClaim' = TRUE
    /\ phase' = "BadMonitorVerifiedClaim"
    /\ UNCHANGED <<eligible, candidate, denied, retryCount, retryBudget,
                    preSettleValidated, classSettled, rollbackProved,
                    ineligibleVisible, retryEpochFresh, balanceClean,
                    coreCacheInvalidated, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    failClosed, postSettleDenyWithoutRollback,
                    sameCandidateRepick, pickerInvisible, scxHeadLivelock,
                    coreCachedPickBypass, proxySubjectMismatch,
                    failClosedWithEligibleCandidate, retryTaskAuthority,
                    idleFallbackAuthority, schedExtFallbackAuthority,
                    behaviorChangeClaim, runtimeCoverageClaim,
                    protectionClaim, costEfficiencyClaim>>

UnsafeProtectionClaim ==
    /\ phase = "Start"
    /\ protectionClaim' = TRUE
    /\ phase' = "BadProtectionClaim"
    /\ UNCHANGED <<eligible, candidate, denied, retryCount, retryBudget,
                    preSettleValidated, classSettled, rollbackProved,
                    ineligibleVisible, retryEpochFresh, balanceClean,
                    coreCacheInvalidated, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    failClosed, postSettleDenyWithoutRollback,
                    sameCandidateRepick, pickerInvisible, scxHeadLivelock,
                    coreCachedPickBypass, proxySubjectMismatch,
                    failClosedWithEligibleCandidate, retryTaskAuthority,
                    idleFallbackAuthority, schedExtFallbackAuthority,
                    behaviorChangeClaim, runtimeCoverageClaim,
                    monitorVerifiedClaim, costEfficiencyClaim>>

UnsafeCostEfficiencyClaim ==
    /\ phase = "Start"
    /\ costEfficiencyClaim' = TRUE
    /\ phase' = "BadCostEfficiencyClaim"
    /\ UNCHANGED <<eligible, candidate, denied, retryCount, retryBudget,
                    preSettleValidated, classSettled, rollbackProved,
                    ineligibleVisible, retryEpochFresh, balanceClean,
                    coreCacheInvalidated, scxHeadSelectable,
                    proxySubjectResolved, rqCurrPublished, running,
                    failClosed, postSettleDenyWithoutRollback,
                    sameCandidateRepick, pickerInvisible, scxHeadLivelock,
                    coreCachedPickBypass, proxySubjectMismatch,
                    failClosedWithEligibleCandidate, retryTaskAuthority,
                    idleFallbackAuthority, schedExtFallbackAuthority,
                    behaviorChangeClaim, runtimeCoverageClaim,
                    monitorVerifiedClaim, protectionClaim>>

UnsafePostSettleDenyWithoutRollbackSpec ==
    Init /\ [][UnsafePostSettleDenyWithoutRollback]_vars
UnsafeClassPickerInvisibleSpec ==
    Init /\ [][UnsafeClassPickerInvisible]_vars
UnsafeSameCandidateRepickSpec ==
    Init /\ [][UnsafeSameCandidateRepick]_vars
UnsafeScxHeadLivelockSpec ==
    Init /\ [][UnsafeScxHeadLivelock]_vars
UnsafeCoreCachedPickBypassSpec ==
    Init /\ [][UnsafeCoreCachedPickBypass]_vars
UnsafeProxySubjectMismatchSpec ==
    Init /\ [][UnsafeProxySubjectMismatch]_vars
UnsafeFailClosedWithEligibleCandidateSpec ==
    Init /\ [][UnsafeFailClosedWithEligibleCandidate]_vars
UnsafeRetryTaskAuthoritySpec ==
    Init /\ [][UnsafeRetryTaskAuthority]_vars
UnsafeIdleFallbackAuthoritySpec ==
    Init /\ [][UnsafeIdleFallbackAuthority]_vars
UnsafeSchedExtFallbackAuthoritySpec ==
    Init /\ [][UnsafeSchedExtFallbackAuthority]_vars
UnsafeBehaviorChangeClaimSpec ==
    Init /\ [][UnsafeBehaviorChangeClaim]_vars
UnsafeRuntimeCoverageClaimSpec ==
    Init /\ [][UnsafeRuntimeCoverageClaim]_vars
UnsafeMonitorVerifiedClaimSpec ==
    Init /\ [][UnsafeMonitorVerifiedClaim]_vars
UnsafeProtectionClaimSpec ==
    Init /\ [][UnsafeProtectionClaim]_vars
UnsafeCostEfficiencyClaimSpec ==
    Init /\ [][UnsafeCostEfficiencyClaim]_vars

Spec == Init /\ [][Next]_vars

NoPostSettleDenyWithoutRollback ==
    ~postSettleDenyWithoutRollback

NoDeniedCandidateRuns ==
    ~(running /\ candidate \in denied)

NoSameCandidateRepick ==
    ~sameCandidateRepick

NoPickerInvisibleIneligibility ==
    ~pickerInvisible

NoScxHeadLivelock ==
    ~scxHeadLivelock

NoCoreCachedPickBypass ==
    ~coreCachedPickBypass

NoProxySubjectMismatch ==
    ~proxySubjectMismatch

NoFailClosedWithEligibleCandidate ==
    /\ ~failClosedWithEligibleCandidate
    /\ ~(failClosed /\ EligibleNow # {})

NoAuthoritySubstitution ==
    /\ ~retryTaskAuthority
    /\ ~idleFallbackAuthority
    /\ ~schedExtFallbackAuthority

NoNonClaimOverreach ==
    /\ ~behaviorChangeClaim
    /\ ~runtimeCoverageClaim
    /\ ~monitorVerifiedClaim
    /\ ~protectionClaim
    /\ ~costEfficiencyClaim

Safety ==
    /\ TypeOK
    /\ NoPostSettleDenyWithoutRollback
    /\ NoDeniedCandidateRuns
    /\ NoSameCandidateRepick
    /\ NoPickerInvisibleIneligibility
    /\ NoScxHeadLivelock
    /\ NoCoreCachedPickBypass
    /\ NoProxySubjectMismatch
    /\ NoFailClosedWithEligibleCandidate
    /\ NoAuthoritySubstitution
    /\ NoNonClaimOverreach

====
