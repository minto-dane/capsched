---------- MODULE FinalDenyRetryIneligibilityGate ----------
EXTENDS Naturals

VARIABLES
    phase,
    runnable,
    candidate,
    deniedCandidate,
    ineligible,
    retryCount,
    retryBudget,
    freshTupleTask,
    freshTupleIssued,
    freshTupleConsumed,
    denialRecorded,
    retryRequested,
    classStateNeutralized,
    balanceCallbacksCleared,
    rqCurrCommitted,
    contextSwitched,
    running,
    runningTask,
    failClosed,
    denyAfterRqCurrCommit,
    sameDeniedCandidateReused,
    retryWithoutProgress,
    failClosedWithEligibleCandidate,
    silentDropWithoutRetryOrFailClosed,
    classStateAuthority,
    retryTaskAuthority,
    idleFallbackAuthority,
    schedExtFallbackAuthority,
    coreCachedPickAuthority,
    behaviorChangeClaim,
    monitorVerifiedClaim,
    protectionClaim

vars == <<phase, runnable, candidate, deniedCandidate, ineligible,
          retryCount, retryBudget, freshTupleTask, freshTupleIssued,
          freshTupleConsumed, denialRecorded, retryRequested,
          classStateNeutralized, balanceCallbacksCleared, rqCurrCommitted,
          contextSwitched, running, runningTask, failClosed,
          denyAfterRqCurrCommit, sameDeniedCandidateReused,
          retryWithoutProgress, failClosedWithEligibleCandidate,
          silentDropWithoutRetryOrFailClosed, classStateAuthority,
          retryTaskAuthority, idleFallbackAuthority, schedExtFallbackAuthority,
          coreCachedPickAuthority, behaviorChangeClaim, monitorVerifiedClaim,
          protectionClaim>>

Tasks == {"A", "B"}
NoTask == "none"
TaskOrNone == Tasks \cup {NoTask}
Phases == {
    "Start",
    "PickedBad",
    "Denied",
    "Retrying",
    "PickedGood",
    "Running",
    "FailClosed",
    "BadRunDeniedCandidate",
    "BadRetrySameCandidate",
    "BadDenyAfterRqCurrCommit",
    "BadDenyWithoutIneligible",
    "BadRetryWithoutProgress",
    "BadFailClosedWithEligibleCandidate",
    "BadRunWithoutFreshTupleAfterRetry",
    "BadSilentDropWithoutRetryOrFailClosed",
    "BadRetryBudgetIgnored",
    "BadClassStateAuthority",
    "BadRetryTaskAuthority",
    "BadIdleFallbackAuthority",
    "BadSchedExtFallbackAuthority",
    "BadCoreCachedPickAuthority",
    "BadBehaviorChangeClaim",
    "BadMonitorVerifiedClaim",
    "BadProtectionClaim"
}

Eligible == runnable \ ineligible

TypeOK ==
    /\ phase \in Phases
    /\ runnable \subseteq Tasks
    /\ candidate \in TaskOrNone
    /\ deniedCandidate \in TaskOrNone
    /\ ineligible \subseteq Tasks
    /\ retryCount \in 0..3
    /\ retryBudget \in 0..2
    /\ freshTupleTask \in TaskOrNone
    /\ freshTupleIssued \in BOOLEAN
    /\ freshTupleConsumed \in BOOLEAN
    /\ denialRecorded \in BOOLEAN
    /\ retryRequested \in BOOLEAN
    /\ classStateNeutralized \in BOOLEAN
    /\ balanceCallbacksCleared \in BOOLEAN
    /\ rqCurrCommitted \in BOOLEAN
    /\ contextSwitched \in BOOLEAN
    /\ running \in BOOLEAN
    /\ runningTask \in TaskOrNone
    /\ failClosed \in BOOLEAN
    /\ denyAfterRqCurrCommit \in BOOLEAN
    /\ sameDeniedCandidateReused \in BOOLEAN
    /\ retryWithoutProgress \in BOOLEAN
    /\ failClosedWithEligibleCandidate \in BOOLEAN
    /\ silentDropWithoutRetryOrFailClosed \in BOOLEAN
    /\ classStateAuthority \in BOOLEAN
    /\ retryTaskAuthority \in BOOLEAN
    /\ idleFallbackAuthority \in BOOLEAN
    /\ schedExtFallbackAuthority \in BOOLEAN
    /\ coreCachedPickAuthority \in BOOLEAN
    /\ behaviorChangeClaim \in BOOLEAN
    /\ monitorVerifiedClaim \in BOOLEAN
    /\ protectionClaim \in BOOLEAN

NoAuthorityFlags ==
    /\ ~classStateAuthority
    /\ ~retryTaskAuthority
    /\ ~idleFallbackAuthority
    /\ ~schedExtFallbackAuthority
    /\ ~coreCachedPickAuthority
    /\ ~behaviorChangeClaim
    /\ ~monitorVerifiedClaim
    /\ ~protectionClaim

Init ==
    /\ phase = "Start"
    /\ runnable = Tasks
    /\ candidate = NoTask
    /\ deniedCandidate = NoTask
    /\ ineligible = {}
    /\ retryCount = 0
    /\ retryBudget = 2
    /\ freshTupleTask = NoTask
    /\ freshTupleIssued = FALSE
    /\ freshTupleConsumed = FALSE
    /\ denialRecorded = FALSE
    /\ retryRequested = FALSE
    /\ classStateNeutralized = FALSE
    /\ balanceCallbacksCleared = FALSE
    /\ rqCurrCommitted = FALSE
    /\ contextSwitched = FALSE
    /\ running = FALSE
    /\ runningTask = NoTask
    /\ failClosed = FALSE
    /\ denyAfterRqCurrCommit = FALSE
    /\ sameDeniedCandidateReused = FALSE
    /\ retryWithoutProgress = FALSE
    /\ failClosedWithEligibleCandidate = FALSE
    /\ silentDropWithoutRetryOrFailClosed = FALSE
    /\ classStateAuthority = FALSE
    /\ retryTaskAuthority = FALSE
    /\ idleFallbackAuthority = FALSE
    /\ schedExtFallbackAuthority = FALSE
    /\ coreCachedPickAuthority = FALSE
    /\ behaviorChangeClaim = FALSE
    /\ monitorVerifiedClaim = FALSE
    /\ protectionClaim = FALSE

PickBad ==
    /\ phase = "Start"
    /\ "A" \in Eligible
    /\ candidate' = "A"
    /\ phase' = "PickedBad"
    /\ UNCHANGED <<runnable, deniedCandidate, ineligible, retryCount,
                    retryBudget, freshTupleTask, freshTupleIssued,
                    freshTupleConsumed, denialRecorded, retryRequested,
                    classStateNeutralized, balanceCallbacksCleared,
                    rqCurrCommitted, contextSwitched, running, runningTask,
                    failClosed, denyAfterRqCurrCommit,
                    sameDeniedCandidateReused, retryWithoutProgress,
                    failClosedWithEligibleCandidate,
                    silentDropWithoutRetryOrFailClosed, classStateAuthority,
                    retryTaskAuthority, idleFallbackAuthority,
                    schedExtFallbackAuthority, coreCachedPickAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

DenyCandidate ==
    /\ phase = "PickedBad"
    /\ candidate = "A"
    /\ retryCount < retryBudget
    /\ deniedCandidate' = candidate
    /\ ineligible' = ineligible \cup {candidate}
    /\ retryCount' = retryCount + 1
    /\ denialRecorded' = TRUE
    /\ retryRequested' = TRUE
    /\ classStateNeutralized' = TRUE
    /\ balanceCallbacksCleared' = TRUE
    /\ freshTupleTask' = NoTask
    /\ freshTupleIssued' = FALSE
    /\ freshTupleConsumed' = FALSE
    /\ rqCurrCommitted' = FALSE
    /\ contextSwitched' = FALSE
    /\ running' = FALSE
    /\ runningTask' = NoTask
    /\ failClosed' = FALSE
    /\ phase' = "Denied"
    /\ UNCHANGED <<runnable, candidate, retryBudget, denyAfterRqCurrCommit,
                    sameDeniedCandidateReused, retryWithoutProgress,
                    failClosedWithEligibleCandidate,
                    silentDropWithoutRetryOrFailClosed, classStateAuthority,
                    retryTaskAuthority, idleFallbackAuthority,
                    schedExtFallbackAuthority, coreCachedPickAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

RetryAfterDeny ==
    /\ phase = "Denied"
    /\ deniedCandidate \in ineligible
    /\ classStateNeutralized
    /\ balanceCallbacksCleared
    /\ retryRequested
    /\ Eligible # {}
    /\ candidate' = NoTask
    /\ phase' = "Retrying"
    /\ UNCHANGED <<runnable, deniedCandidate, ineligible, retryCount,
                    retryBudget, freshTupleTask, freshTupleIssued,
                    freshTupleConsumed, denialRecorded, retryRequested,
                    classStateNeutralized, balanceCallbacksCleared,
                    rqCurrCommitted, contextSwitched, running, runningTask,
                    failClosed, denyAfterRqCurrCommit,
                    sameDeniedCandidateReused, retryWithoutProgress,
                    failClosedWithEligibleCandidate,
                    silentDropWithoutRetryOrFailClosed, classStateAuthority,
                    retryTaskAuthority, idleFallbackAuthority,
                    schedExtFallbackAuthority, coreCachedPickAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

PickGoodAfterRetry ==
    /\ phase = "Retrying"
    /\ "B" \in Eligible
    /\ candidate' = "B"
    /\ freshTupleTask' = "B"
    /\ freshTupleIssued' = TRUE
    /\ freshTupleConsumed' = FALSE
    /\ phase' = "PickedGood"
    /\ UNCHANGED <<runnable, deniedCandidate, ineligible, retryCount,
                    retryBudget, denialRecorded, retryRequested,
                    classStateNeutralized, balanceCallbacksCleared,
                    rqCurrCommitted, contextSwitched, running, runningTask,
                    failClosed, denyAfterRqCurrCommit,
                    sameDeniedCandidateReused, retryWithoutProgress,
                    failClosedWithEligibleCandidate,
                    silentDropWithoutRetryOrFailClosed, classStateAuthority,
                    retryTaskAuthority, idleFallbackAuthority,
                    schedExtFallbackAuthority, coreCachedPickAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

CommitGood ==
    /\ phase = "PickedGood"
    /\ candidate = "B"
    /\ candidate \in Eligible
    /\ freshTupleIssued
    /\ ~freshTupleConsumed
    /\ freshTupleTask = candidate
    /\ NoAuthorityFlags
    /\ freshTupleConsumed' = TRUE
    /\ rqCurrCommitted' = TRUE
    /\ contextSwitched' = TRUE
    /\ running' = TRUE
    /\ runningTask' = candidate
    /\ failClosed' = FALSE
    /\ retryRequested' = FALSE
    /\ phase' = "Running"
    /\ UNCHANGED <<runnable, candidate, deniedCandidate, ineligible, retryCount,
                    retryBudget, freshTupleTask, freshTupleIssued,
                    denialRecorded, classStateNeutralized,
                    balanceCallbacksCleared, denyAfterRqCurrCommit,
                    sameDeniedCandidateReused, retryWithoutProgress,
                    failClosedWithEligibleCandidate,
                    silentDropWithoutRetryOrFailClosed, classStateAuthority,
                    retryTaskAuthority, idleFallbackAuthority,
                    schedExtFallbackAuthority, coreCachedPickAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

PickOnlyBad ==
    /\ phase = "Start"
    /\ runnable' = {"A"}
    /\ candidate' = "A"
    /\ phase' = "PickedBad"
    /\ UNCHANGED <<deniedCandidate, ineligible, retryCount, retryBudget,
                    freshTupleTask, freshTupleIssued, freshTupleConsumed,
                    denialRecorded, retryRequested, classStateNeutralized,
                    balanceCallbacksCleared, rqCurrCommitted, contextSwitched,
                    running, runningTask, failClosed, denyAfterRqCurrCommit,
                    sameDeniedCandidateReused, retryWithoutProgress,
                    failClosedWithEligibleCandidate,
                    silentDropWithoutRetryOrFailClosed, classStateAuthority,
                    retryTaskAuthority, idleFallbackAuthority,
                    schedExtFallbackAuthority, coreCachedPickAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

FailClosedAfterDeny ==
    /\ phase = "Denied"
    /\ Eligible = {}
    /\ deniedCandidate \in ineligible
    /\ classStateNeutralized
    /\ balanceCallbacksCleared
    /\ failClosed' = TRUE
    /\ retryRequested' = FALSE
    /\ rqCurrCommitted' = FALSE
    /\ contextSwitched' = FALSE
    /\ running' = FALSE
    /\ runningTask' = NoTask
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<runnable, candidate, deniedCandidate, ineligible, retryCount,
                    retryBudget, freshTupleTask, freshTupleIssued,
                    freshTupleConsumed, denialRecorded,
                    classStateNeutralized, balanceCallbacksCleared,
                    denyAfterRqCurrCommit, sameDeniedCandidateReused,
                    retryWithoutProgress, failClosedWithEligibleCandidate,
                    silentDropWithoutRetryOrFailClosed, classStateAuthority,
                    retryTaskAuthority, idleFallbackAuthority,
                    schedExtFallbackAuthority, coreCachedPickAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

TerminalStutter ==
    /\ phase \in {"Running", "FailClosed"}
    /\ UNCHANGED vars

SafeNext ==
    \/ PickBad
    \/ DenyCandidate
    \/ RetryAfterDeny
    \/ PickGoodAfterRetry
    \/ CommitGood
    \/ PickOnlyBad
    \/ FailClosedAfterDeny
    \/ TerminalStutter

BadState(runnableP, candidateP, deniedCandidateP, ineligibleP,
         retryCountP, retryBudgetP, freshTupleTaskP, freshTupleIssuedP,
         freshTupleConsumedP, denialRecordedP, retryRequestedP,
         classStateNeutralizedP, balanceCallbacksClearedP,
         rqCurrCommittedP, contextSwitchedP, runningP, runningTaskP,
         failClosedP, denyAfterCurrP, sameDeniedP, retryNoProgressP,
         failClosedWithEligibleP, silentDropP, classAuthorityP,
         retryAuthorityP, idleAuthorityP, scxAuthorityP, coreAuthorityP,
         behaviorP, monitorP, protectionP, badPhase) ==
    /\ phase = "Start"
    /\ runnable' = runnableP
    /\ candidate' = candidateP
    /\ deniedCandidate' = deniedCandidateP
    /\ ineligible' = ineligibleP
    /\ retryCount' = retryCountP
    /\ retryBudget' = retryBudgetP
    /\ freshTupleTask' = freshTupleTaskP
    /\ freshTupleIssued' = freshTupleIssuedP
    /\ freshTupleConsumed' = freshTupleConsumedP
    /\ denialRecorded' = denialRecordedP
    /\ retryRequested' = retryRequestedP
    /\ classStateNeutralized' = classStateNeutralizedP
    /\ balanceCallbacksCleared' = balanceCallbacksClearedP
    /\ rqCurrCommitted' = rqCurrCommittedP
    /\ contextSwitched' = contextSwitchedP
    /\ running' = runningP
    /\ runningTask' = runningTaskP
    /\ failClosed' = failClosedP
    /\ denyAfterRqCurrCommit' = denyAfterCurrP
    /\ sameDeniedCandidateReused' = sameDeniedP
    /\ retryWithoutProgress' = retryNoProgressP
    /\ failClosedWithEligibleCandidate' = failClosedWithEligibleP
    /\ silentDropWithoutRetryOrFailClosed' = silentDropP
    /\ classStateAuthority' = classAuthorityP
    /\ retryTaskAuthority' = retryAuthorityP
    /\ idleFallbackAuthority' = idleAuthorityP
    /\ schedExtFallbackAuthority' = scxAuthorityP
    /\ coreCachedPickAuthority' = coreAuthorityP
    /\ behaviorChangeClaim' = behaviorP
    /\ monitorVerifiedClaim' = monitorP
    /\ protectionClaim' = protectionP
    /\ phase' = badPhase

DefaultBad(freshTask, issued, consumed, rqCurr, switched, isRunning,
           runTask, isFailClosed, badPhase) ==
    BadState(Tasks, "A", "A", {}, 1, 2, freshTask, issued, consumed,
             TRUE, FALSE, FALSE, FALSE, rqCurr, switched, isRunning, runTask,
             isFailClosed, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, badPhase)

UnsafeRunDeniedCandidate ==
    DefaultBad("A", TRUE, TRUE, TRUE, TRUE, TRUE, "A", FALSE,
               "BadRunDeniedCandidate")

UnsafeRetrySameCandidate ==
    BadState(Tasks, "A", "A", {}, 1, 2, NoTask, FALSE, FALSE, TRUE,
             TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, NoTask, FALSE, FALSE,
             TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
             FALSE, FALSE, FALSE, "BadRetrySameCandidate")

UnsafeDenyAfterRqCurrCommit ==
    BadState(Tasks, "A", "A", {}, 1, 2, NoTask, FALSE, FALSE, TRUE,
             FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, NoTask, FALSE, TRUE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
             FALSE, FALSE, FALSE, "BadDenyAfterRqCurrCommit")

UnsafeDenyWithoutIneligible ==
    BadState(Tasks, "A", "A", {}, 1, 2, NoTask, FALSE, FALSE, TRUE,
             TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, NoTask, FALSE, FALSE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
             FALSE, FALSE, FALSE, "BadDenyWithoutIneligible")

UnsafeRetryWithoutProgress ==
    BadState(Tasks, "A", "A", {}, 1, 2, NoTask, FALSE, FALSE, TRUE,
             TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, NoTask, FALSE, FALSE,
             FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
             FALSE, FALSE, FALSE, "BadRetryWithoutProgress")

UnsafeFailClosedWithEligibleCandidate ==
    BadState(Tasks, "A", "A", {"A"}, 1, 2, NoTask, FALSE, FALSE, TRUE,
             FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, NoTask, TRUE, FALSE,
             FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
             FALSE, FALSE, FALSE, "BadFailClosedWithEligibleCandidate")

UnsafeRunWithoutFreshTupleAfterRetry ==
    BadState(Tasks, "B", "A", {"A"}, 1, 2, NoTask, FALSE, FALSE, TRUE,
             FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, "B", FALSE, FALSE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
             FALSE, FALSE, FALSE, "BadRunWithoutFreshTupleAfterRetry")

UnsafeSilentDropWithoutRetryOrFailClosed ==
    BadState(Tasks, "A", "A", {}, 1, 2, NoTask, FALSE, FALSE, TRUE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NoTask, FALSE, FALSE,
             FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE,
             FALSE, FALSE, FALSE, "BadSilentDropWithoutRetryOrFailClosed")

UnsafeRetryBudgetIgnored ==
    BadState(Tasks, "A", "A", {"A"}, 3, 2, NoTask, FALSE, FALSE, TRUE,
             TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, NoTask, FALSE, FALSE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
             FALSE, FALSE, FALSE, "BadRetryBudgetIgnored")

UnsafeClassStateAuthority ==
    BadState(Tasks, "A", "A", {}, 1, 2, NoTask, FALSE, FALSE, TRUE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NoTask, FALSE, FALSE,
             FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE,
             FALSE, FALSE, FALSE, "BadClassStateAuthority")

UnsafeRetryTaskAuthority ==
    BadState(Tasks, "A", "A", {}, 1, 2, NoTask, FALSE, FALSE, TRUE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NoTask, FALSE, FALSE,
             FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE,
             FALSE, FALSE, FALSE, "BadRetryTaskAuthority")

UnsafeIdleFallbackAuthority ==
    BadState(Tasks, "A", "A", {}, 1, 2, NoTask, FALSE, FALSE, TRUE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NoTask, FALSE, FALSE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE,
             FALSE, FALSE, FALSE, "BadIdleFallbackAuthority")

UnsafeSchedExtFallbackAuthority ==
    BadState(Tasks, "A", "A", {}, 1, 2, NoTask, FALSE, FALSE, TRUE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NoTask, FALSE, FALSE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE,
             FALSE, FALSE, FALSE, "BadSchedExtFallbackAuthority")

UnsafeCoreCachedPickAuthority ==
    BadState(Tasks, "A", "A", {}, 1, 2, NoTask, FALSE, FALSE, TRUE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NoTask, FALSE, FALSE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE,
             FALSE, FALSE, FALSE, "BadCoreCachedPickAuthority")

UnsafeBehaviorChangeClaim ==
    BadState(Tasks, "A", "A", {}, 1, 2, NoTask, FALSE, FALSE, TRUE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NoTask, FALSE, FALSE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
             TRUE, FALSE, FALSE, "BadBehaviorChangeClaim")

UnsafeMonitorVerifiedClaim ==
    BadState(Tasks, "A", "A", {}, 1, 2, NoTask, FALSE, FALSE, TRUE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NoTask, FALSE, FALSE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
             FALSE, TRUE, FALSE, "BadMonitorVerifiedClaim")

UnsafeProtectionClaim ==
    BadState(Tasks, "A", "A", {}, 1, 2, NoTask, FALSE, FALSE, TRUE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NoTask, FALSE, FALSE,
             FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
             FALSE, FALSE, TRUE, "BadProtectionClaim")

SpecUnsafeRunDeniedCandidate == Init /\ [][UnsafeRunDeniedCandidate]_vars
SpecUnsafeRetrySameCandidate == Init /\ [][UnsafeRetrySameCandidate]_vars
SpecUnsafeDenyAfterRqCurrCommit == Init /\ [][UnsafeDenyAfterRqCurrCommit]_vars
SpecUnsafeDenyWithoutIneligible == Init /\ [][UnsafeDenyWithoutIneligible]_vars
SpecUnsafeRetryWithoutProgress == Init /\ [][UnsafeRetryWithoutProgress]_vars
SpecUnsafeFailClosedWithEligibleCandidate == Init /\ [][UnsafeFailClosedWithEligibleCandidate]_vars
SpecUnsafeRunWithoutFreshTupleAfterRetry == Init /\ [][UnsafeRunWithoutFreshTupleAfterRetry]_vars
SpecUnsafeSilentDropWithoutRetryOrFailClosed == Init /\ [][UnsafeSilentDropWithoutRetryOrFailClosed]_vars
SpecUnsafeRetryBudgetIgnored == Init /\ [][UnsafeRetryBudgetIgnored]_vars
SpecUnsafeClassStateAuthority == Init /\ [][UnsafeClassStateAuthority]_vars
SpecUnsafeRetryTaskAuthority == Init /\ [][UnsafeRetryTaskAuthority]_vars
SpecUnsafeIdleFallbackAuthority == Init /\ [][UnsafeIdleFallbackAuthority]_vars
SpecUnsafeSchedExtFallbackAuthority == Init /\ [][UnsafeSchedExtFallbackAuthority]_vars
SpecUnsafeCoreCachedPickAuthority == Init /\ [][UnsafeCoreCachedPickAuthority]_vars
SpecUnsafeBehaviorChangeClaim == Init /\ [][UnsafeBehaviorChangeClaim]_vars
SpecUnsafeMonitorVerifiedClaim == Init /\ [][UnsafeMonitorVerifiedClaim]_vars
SpecUnsafeProtectionClaim == Init /\ [][UnsafeProtectionClaim]_vars

SafeSpec == Init /\ [][SafeNext]_vars

NoDeniedCandidateRuns ==
    running => runningTask # deniedCandidate

NoRunWithoutFreshTuple ==
    running =>
        /\ freshTupleIssued
        /\ freshTupleConsumed
        /\ freshTupleTask = runningTask
        /\ runningTask \in Eligible

NoRetryWithoutIneligibility ==
    retryRequested =>
        /\ deniedCandidate \in ineligible
        /\ classStateNeutralized
        /\ balanceCallbacksCleared

NoRetrySameDeniedCandidate ==
    ~sameDeniedCandidateReused

NoDenyAfterRqCurrCommit ==
    ~denyAfterRqCurrCommit

NoRetryWithoutProgress ==
    /\ ~retryWithoutProgress
    /\ retryCount <= retryBudget

NoFailClosedWithEligibleCandidate ==
    failClosed => Eligible = {}

NoSilentDropWithoutRetryOrFailClosed ==
    ~silentDropWithoutRetryOrFailClosed

NoAuthoritySubstitution ==
    /\ ~classStateAuthority
    /\ ~retryTaskAuthority
    /\ ~idleFallbackAuthority
    /\ ~schedExtFallbackAuthority
    /\ ~coreCachedPickAuthority

NoNonClaimOverreach ==
    /\ ~behaviorChangeClaim
    /\ ~monitorVerifiedClaim
    /\ ~protectionClaim

=============================================================================
