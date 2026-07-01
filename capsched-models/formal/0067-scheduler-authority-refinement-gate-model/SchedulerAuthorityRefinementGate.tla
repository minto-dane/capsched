---------------- MODULE SchedulerAuthorityRefinementGate ----------------
EXTENDS Naturals

VARIABLES
    phase,
    frozen,
    taskWaking,
    queued,
    selected,
    classSettled,
    retryPending,
    donorEqualsCurrent,
    donorBudgetFresh,
    executorAuthorityFresh,
    proxyTicket,
    running,
    failClosed

vars == <<phase, frozen, taskWaking, queued, selected, classSettled,
          retryPending, donorEqualsCurrent, donorBudgetFresh,
          executorAuthorityFresh, proxyTicket, running, failClosed>>

Phases == {
    "Start",
    "Frozen",
    "TaskWaking",
    "Queued",
    "Selected",
    "ClassSettled",
    "Running",
    "FailClosed",
    "BadTaskWakingWithoutFreeze",
    "BadCurrentOnlyProxyRun",
    "BadRunAfterRetry",
    "BadRunWithoutClassSettlement"
}

TypeOK ==
    /\ phase \in Phases
    /\ frozen \in BOOLEAN
    /\ taskWaking \in BOOLEAN
    /\ queued \in BOOLEAN
    /\ selected \in BOOLEAN
    /\ classSettled \in BOOLEAN
    /\ retryPending \in BOOLEAN
    /\ donorEqualsCurrent \in BOOLEAN
    /\ donorBudgetFresh \in BOOLEAN
    /\ executorAuthorityFresh \in BOOLEAN
    /\ proxyTicket \in BOOLEAN
    /\ running \in BOOLEAN
    /\ failClosed \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ frozen = FALSE
    /\ taskWaking = FALSE
    /\ queued = FALSE
    /\ selected = FALSE
    /\ classSettled = FALSE
    /\ retryPending = FALSE
    /\ donorEqualsCurrent = TRUE
    /\ donorBudgetFresh = FALSE
    /\ executorAuthorityFresh = FALSE
    /\ proxyTicket = FALSE
    /\ running = FALSE
    /\ failClosed = FALSE

FreezeBeforeTaskWaking ==
    /\ phase = "Start"
    /\ frozen' = TRUE
    /\ donorBudgetFresh' = TRUE
    /\ executorAuthorityFresh' = TRUE
    /\ phase' = "Frozen"
    /\ UNCHANGED <<taskWaking, queued, selected, classSettled, retryPending,
                    donorEqualsCurrent, proxyTicket, running, failClosed>>

SetTaskWakingAfterFreeze ==
    /\ phase = "Frozen"
    /\ frozen
    /\ taskWaking' = TRUE
    /\ phase' = "TaskWaking"
    /\ UNCHANGED <<frozen, queued, selected, classSettled, retryPending,
                    donorEqualsCurrent, donorBudgetFresh,
                    executorAuthorityFresh, proxyTicket, running, failClosed>>

EnqueueAfterTaskWaking ==
    /\ phase = "TaskWaking"
    /\ frozen
    /\ taskWaking
    /\ queued' = TRUE
    /\ phase' = "Queued"
    /\ UNCHANGED <<frozen, taskWaking, selected, classSettled, retryPending,
                    donorEqualsCurrent, donorBudgetFresh,
                    executorAuthorityFresh, proxyTicket, running, failClosed>>

SelectDirect ==
    /\ phase = "Queued"
    /\ queued
    /\ frozen
    /\ donorEqualsCurrent' = TRUE
    /\ selected' = TRUE
    /\ classSettled' = FALSE
    /\ phase' = "Selected"
    /\ UNCHANGED <<frozen, taskWaking, queued, retryPending,
                    donorBudgetFresh, executorAuthorityFresh, proxyTicket,
                    running, failClosed>>

SelectProxy ==
    /\ phase = "Queued"
    /\ queued
    /\ frozen
    /\ donorEqualsCurrent' = FALSE
    /\ proxyTicket' = TRUE
    /\ selected' = TRUE
    /\ classSettled' = FALSE
    /\ phase' = "Selected"
    /\ UNCHANGED <<frozen, taskWaking, queued, retryPending,
                    donorBudgetFresh, executorAuthorityFresh, running,
                    failClosed>>

SettleClassSelection ==
    /\ phase = "Selected"
    /\ selected
    /\ frozen
    /\ ~retryPending
    /\ donorBudgetFresh
    /\ executorAuthorityFresh
    /\ (donorEqualsCurrent \/ proxyTicket)
    /\ classSettled' = TRUE
    /\ phase' = "ClassSettled"
    /\ UNCHANGED <<frozen, taskWaking, queued, selected, retryPending,
                    donorEqualsCurrent, donorBudgetFresh,
                    executorAuthorityFresh, proxyTicket, running, failClosed>>

RunDirectAfterSettlement ==
    /\ phase = "ClassSettled"
    /\ selected
    /\ classSettled
    /\ frozen
    /\ donorEqualsCurrent
    /\ donorBudgetFresh
    /\ executorAuthorityFresh
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<frozen, taskWaking, queued, selected, classSettled,
                    retryPending, donorEqualsCurrent, donorBudgetFresh,
                    executorAuthorityFresh, proxyTicket, failClosed>>

RunProxyAfterSettlement ==
    /\ phase = "ClassSettled"
    /\ selected
    /\ classSettled
    /\ frozen
    /\ ~donorEqualsCurrent
    /\ donorBudgetFresh
    /\ executorAuthorityFresh
    /\ proxyTicket
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<frozen, taskWaking, queued, selected, classSettled,
                    retryPending, donorEqualsCurrent, donorBudgetFresh,
                    executorAuthorityFresh, proxyTicket, failClosed>>

RetryInvalidatesSelectedUse ==
    /\ phase = "Selected"
    /\ selected
    /\ retryPending' = TRUE
    /\ selected' = FALSE
    /\ classSettled' = FALSE
    /\ failClosed' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<frozen, taskWaking, queued, donorEqualsCurrent,
                    donorBudgetFresh, executorAuthorityFresh, proxyTicket,
                    running>>

BudgetOrAuthorityRevocationCloses ==
    /\ phase \in {"Selected", "ClassSettled", "Running"}
    /\ donorBudgetFresh' = FALSE
    /\ executorAuthorityFresh' = FALSE
    /\ selected' = FALSE
    /\ classSettled' = FALSE
    /\ running' = FALSE
    /\ failClosed' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<frozen, taskWaking, queued, retryPending,
                    donorEqualsCurrent, proxyTicket>>

UnsafeTaskWakingWithoutFreeze ==
    /\ phase = "Start"
    /\ frozen = FALSE
    /\ taskWaking' = TRUE
    /\ phase' = "BadTaskWakingWithoutFreeze"
    /\ UNCHANGED <<frozen, queued, selected, classSettled, retryPending,
                    donorEqualsCurrent, donorBudgetFresh,
                    executorAuthorityFresh, proxyTicket, running, failClosed>>

UnsafeCurrentOnlyProxyRun ==
    /\ phase = "ClassSettled"
    /\ selected
    /\ classSettled
    /\ frozen
    /\ donorEqualsCurrent' = FALSE
    /\ donorBudgetFresh' = FALSE
    /\ executorAuthorityFresh' = TRUE
    /\ proxyTicket' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadCurrentOnlyProxyRun"
    /\ UNCHANGED <<frozen, taskWaking, queued, selected, classSettled,
                    retryPending, failClosed>>

UnsafeRunAfterRetry ==
    /\ phase = "Selected"
    /\ selected
    /\ retryPending' = TRUE
    /\ classSettled' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadRunAfterRetry"
    /\ UNCHANGED <<frozen, taskWaking, queued, selected, donorEqualsCurrent,
                    donorBudgetFresh, executorAuthorityFresh, proxyTicket,
                    failClosed>>

UnsafeRunWithoutClassSettlement ==
    /\ phase = "Selected"
    /\ selected
    /\ classSettled = FALSE
    /\ running' = TRUE
    /\ phase' = "BadRunWithoutClassSettlement"
    /\ UNCHANGED <<frozen, taskWaking, queued, selected, classSettled,
                    retryPending, donorEqualsCurrent, donorBudgetFresh,
                    executorAuthorityFresh, proxyTicket, failClosed>>

SafeNext ==
    \/ FreezeBeforeTaskWaking
    \/ SetTaskWakingAfterFreeze
    \/ EnqueueAfterTaskWaking
    \/ SelectDirect
    \/ SelectProxy
    \/ SettleClassSelection
    \/ RunDirectAfterSettlement
    \/ RunProxyAfterSettlement
    \/ RetryInvalidatesSelectedUse
    \/ BudgetOrAuthorityRevocationCloses

UnsafeTaskWakingSpec ==
    Init /\ [][SafeNext \/ UnsafeTaskWakingWithoutFreeze]_vars

UnsafeCurrentOnlyProxySpec ==
    Init /\ [][SafeNext \/ UnsafeCurrentOnlyProxyRun]_vars

UnsafeRetrySpec ==
    Init /\ [][SafeNext \/ UnsafeRunAfterRetry]_vars

UnsafeNoClassSettlementSpec ==
    Init /\ [][SafeNext \/ UnsafeRunWithoutClassSettlement]_vars

SafeSpec ==
    Init /\ [][SafeNext]_vars

NoTaskWakingWithoutFrozenUse ==
    taskWaking => frozen

NoRunWithoutFrozenUse ==
    running => frozen

NoRunWithoutSettledSelection ==
    running => (selected /\ classSettled /\ ~retryPending)

NoRunWithoutDonorBudget ==
    running => donorBudgetFresh

NoRunWithoutExecutorAuthority ==
    running => executorAuthorityFresh

NoProxyRunWithoutProxyTicket ==
    (running /\ ~donorEqualsCurrent) => proxyTicket

NoFailClosedRunning ==
    failClosed => ~running

=============================================================================
