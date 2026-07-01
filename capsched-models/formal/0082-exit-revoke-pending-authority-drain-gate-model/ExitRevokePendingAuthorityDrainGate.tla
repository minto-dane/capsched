---------- MODULE ExitRevokePendingAuthorityDrainGate ----------
EXTENDS Naturals

VARIABLES
    phase,
    embargoStarted,
    inventoryKeyComplete,
    drainStarted,
    drainComplete,
    queuedUse,
    selectedUse,
    deniedCandidate,
    moveTuple,
    remoteWake,
    taskWorkCarrier,
    workqueueCarrier,
    ioUringCarrier,
    timerCarrier,
    rcuCallbackCarrier,
    softirqCarrier,
    endpointUse,
    directCallCarrier,
    ringCarrier,
    derivedReceipt,
    deviceQueueCarrier,
    budgetReservation,
    serverBorrowTicket,
    rootRunToken,
    unknownCarrier,
    budgetSettled,
    budgetSettleCount,
    schedulerEffect,
    asyncEffect,
    endpointEffect,
    monitorAdmissionEffect,
    deviceEffect,
    budgetEffect,
    rootExecutionEffect,
    budgetLeak,
    linuxCancelReceipt,
    flushAuthority,
    pendingClearReceipt,
    cqeSettlementAuthority,
    auditOnlyDrainReceipt,
    rcuVisibilityAuthority,
    pidReuseAuthority,
    earlyReleaseAuthority,
    behaviorChangeClaim,
    monitorVerifiedClaim,
    protectionClaim

vars == <<phase, embargoStarted, inventoryKeyComplete, drainStarted,
          drainComplete, queuedUse, selectedUse, deniedCandidate, moveTuple,
          remoteWake, taskWorkCarrier, workqueueCarrier, ioUringCarrier,
          timerCarrier, rcuCallbackCarrier, softirqCarrier, endpointUse,
          directCallCarrier, ringCarrier, derivedReceipt, deviceQueueCarrier,
          budgetReservation, serverBorrowTicket, rootRunToken, unknownCarrier,
          budgetSettled, budgetSettleCount, schedulerEffect, asyncEffect,
          endpointEffect, monitorAdmissionEffect, deviceEffect, budgetEffect,
          rootExecutionEffect, budgetLeak, linuxCancelReceipt, flushAuthority,
          pendingClearReceipt, cqeSettlementAuthority, auditOnlyDrainReceipt,
          rcuVisibilityAuthority, pidReuseAuthority, earlyReleaseAuthority,
          behaviorChangeClaim, monitorVerifiedClaim, protectionClaim>>

GoodPhases == {
    "Start",
    "PendingInventory",
    "ExitDrainStarted",
    "RevokeDrainStarted",
    "SchedulerDrained",
    "AsyncDrained",
    "EndpointDrained",
    "MonitorAdmissionDrained",
    "DeviceDrained",
    "BudgetAndRootSettled",
    "DrainComplete"
}

BadPhases == {
    "BadExitCompleteWithRemoteWakePending",
    "BadExitCompleteWithQueuedFrozenRunUse",
    "BadExitReleaseBeforeDrainSettlement",
    "BadPidReuseMatchesPendingAuthority",
    "BadRevokeCompleteWithWorkqueuePendingCarrier",
    "BadWorkqueueCancelFlushAsDrainReceipt",
    "BadWorkqueuePendingClearAsRevokeReceipt",
    "BadWorkqueueSelfRequeueOldCarrier",
    "BadIoUringCancelAsDrainReceipt",
    "BadIoUringCqeAfterRevokeComplete",
    "BadIoUringLinkedReissueOldAuthority",
    "BadEndpointUseAfterExitOrRevoke",
    "BadFutexWaiterWakeAfterEndpointRevoke",
    "BadDirectCallRevokeCompleteWithInFlight",
    "BadRingRevokeCompleteWithPendingSlotOrResponse",
    "BadDerivedReceiptLiveAfterRevokeComplete",
    "BadDeviceQueueReassignBeforeDrain",
    "BadBudgetTicketRefundBeforeCarrierTerminal",
    "BadServerBorrowTicketSurvivesExitOrRevoke",
    "BadRootTimerOrRunTokenLiveAfterExit",
    "BadAuditOnlyDrainAccepted",
    "BadUnknownPendingCarrierTreatedAsDrained",
    "BadBudgetReservationLeak",
    "BadBudgetDoubleSettle",
    "BadRcuVisibilityAuthority",
    "BadBehaviorChangeClaim",
    "BadMonitorVerifiedClaim",
    "BadProtectionClaim"
}

Phases == GoodPhases \cup BadPhases

SchedulerClear ==
    /\ ~queuedUse
    /\ ~selectedUse
    /\ ~deniedCandidate
    /\ ~moveTuple
    /\ ~remoteWake

AsyncClear ==
    /\ ~taskWorkCarrier
    /\ ~workqueueCarrier
    /\ ~ioUringCarrier
    /\ ~timerCarrier
    /\ ~rcuCallbackCarrier
    /\ ~softirqCarrier

MonitorAdmissionClear ==
    /\ ~directCallCarrier
    /\ ~ringCarrier
    /\ ~derivedReceipt

BudgetAndRootClear ==
    /\ ~budgetReservation
    /\ ~serverBorrowTicket
    /\ ~rootRunToken

AllPendingClear ==
    /\ SchedulerClear
    /\ AsyncClear
    /\ ~endpointUse
    /\ MonitorAdmissionClear
    /\ ~deviceQueueCarrier
    /\ BudgetAndRootClear
    /\ ~unknownCarrier

TypeOK ==
    /\ phase \in Phases
    /\ embargoStarted \in BOOLEAN
    /\ inventoryKeyComplete \in BOOLEAN
    /\ drainStarted \in BOOLEAN
    /\ drainComplete \in BOOLEAN
    /\ queuedUse \in BOOLEAN
    /\ selectedUse \in BOOLEAN
    /\ deniedCandidate \in BOOLEAN
    /\ moveTuple \in BOOLEAN
    /\ remoteWake \in BOOLEAN
    /\ taskWorkCarrier \in BOOLEAN
    /\ workqueueCarrier \in BOOLEAN
    /\ ioUringCarrier \in BOOLEAN
    /\ timerCarrier \in BOOLEAN
    /\ rcuCallbackCarrier \in BOOLEAN
    /\ softirqCarrier \in BOOLEAN
    /\ endpointUse \in BOOLEAN
    /\ directCallCarrier \in BOOLEAN
    /\ ringCarrier \in BOOLEAN
    /\ derivedReceipt \in BOOLEAN
    /\ deviceQueueCarrier \in BOOLEAN
    /\ budgetReservation \in BOOLEAN
    /\ serverBorrowTicket \in BOOLEAN
    /\ rootRunToken \in BOOLEAN
    /\ unknownCarrier \in BOOLEAN
    /\ budgetSettled \in BOOLEAN
    /\ budgetSettleCount \in Nat
    /\ schedulerEffect \in BOOLEAN
    /\ asyncEffect \in BOOLEAN
    /\ endpointEffect \in BOOLEAN
    /\ monitorAdmissionEffect \in BOOLEAN
    /\ deviceEffect \in BOOLEAN
    /\ budgetEffect \in BOOLEAN
    /\ rootExecutionEffect \in BOOLEAN
    /\ budgetLeak \in BOOLEAN
    /\ linuxCancelReceipt \in BOOLEAN
    /\ flushAuthority \in BOOLEAN
    /\ pendingClearReceipt \in BOOLEAN
    /\ cqeSettlementAuthority \in BOOLEAN
    /\ auditOnlyDrainReceipt \in BOOLEAN
    /\ rcuVisibilityAuthority \in BOOLEAN
    /\ pidReuseAuthority \in BOOLEAN
    /\ earlyReleaseAuthority \in BOOLEAN
    /\ behaviorChangeClaim \in BOOLEAN
    /\ monitorVerifiedClaim \in BOOLEAN
    /\ protectionClaim \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ embargoStarted = FALSE
    /\ inventoryKeyComplete = FALSE
    /\ drainStarted = FALSE
    /\ drainComplete = FALSE
    /\ queuedUse = FALSE
    /\ selectedUse = FALSE
    /\ deniedCandidate = FALSE
    /\ moveTuple = FALSE
    /\ remoteWake = FALSE
    /\ taskWorkCarrier = FALSE
    /\ workqueueCarrier = FALSE
    /\ ioUringCarrier = FALSE
    /\ timerCarrier = FALSE
    /\ rcuCallbackCarrier = FALSE
    /\ softirqCarrier = FALSE
    /\ endpointUse = FALSE
    /\ directCallCarrier = FALSE
    /\ ringCarrier = FALSE
    /\ derivedReceipt = FALSE
    /\ deviceQueueCarrier = FALSE
    /\ budgetReservation = FALSE
    /\ serverBorrowTicket = FALSE
    /\ rootRunToken = FALSE
    /\ unknownCarrier = FALSE
    /\ budgetSettled = FALSE
    /\ budgetSettleCount = 0
    /\ schedulerEffect = FALSE
    /\ asyncEffect = FALSE
    /\ endpointEffect = FALSE
    /\ monitorAdmissionEffect = FALSE
    /\ deviceEffect = FALSE
    /\ budgetEffect = FALSE
    /\ rootExecutionEffect = FALSE
    /\ budgetLeak = FALSE
    /\ linuxCancelReceipt = FALSE
    /\ flushAuthority = FALSE
    /\ pendingClearReceipt = FALSE
    /\ cqeSettlementAuthority = FALSE
    /\ auditOnlyDrainReceipt = FALSE
    /\ rcuVisibilityAuthority = FALSE
    /\ pidReuseAuthority = FALSE
    /\ earlyReleaseAuthority = FALSE
    /\ behaviorChangeClaim = FALSE
    /\ monitorVerifiedClaim = FALSE
    /\ protectionClaim = FALSE

PreparePendingInventory ==
    /\ phase = "Start"
    /\ phase' = "PendingInventory"
    /\ inventoryKeyComplete' = TRUE
    /\ queuedUse' = TRUE
    /\ selectedUse' = TRUE
    /\ deniedCandidate' = TRUE
    /\ moveTuple' = TRUE
    /\ remoteWake' = TRUE
    /\ taskWorkCarrier' = TRUE
    /\ workqueueCarrier' = TRUE
    /\ ioUringCarrier' = TRUE
    /\ timerCarrier' = TRUE
    /\ rcuCallbackCarrier' = TRUE
    /\ softirqCarrier' = TRUE
    /\ endpointUse' = TRUE
    /\ directCallCarrier' = TRUE
    /\ ringCarrier' = TRUE
    /\ derivedReceipt' = TRUE
    /\ deviceQueueCarrier' = TRUE
    /\ budgetReservation' = TRUE
    /\ serverBorrowTicket' = TRUE
    /\ rootRunToken' = TRUE
    /\ unknownCarrier' = FALSE
    /\ UNCHANGED <<embargoStarted, drainStarted, drainComplete,
                    budgetSettled, budgetSettleCount, schedulerEffect,
                    asyncEffect, endpointEffect, monitorAdmissionEffect,
                    deviceEffect, budgetEffect, rootExecutionEffect,
                    budgetLeak, linuxCancelReceipt, flushAuthority,
                    pendingClearReceipt, cqeSettlementAuthority,
                    auditOnlyDrainReceipt, rcuVisibilityAuthority,
                    pidReuseAuthority, earlyReleaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

StartExitDrain ==
    /\ phase = "PendingInventory"
    /\ phase' = "ExitDrainStarted"
    /\ embargoStarted' = TRUE
    /\ drainStarted' = TRUE
    /\ UNCHANGED <<inventoryKeyComplete, drainComplete, queuedUse,
                    selectedUse, deniedCandidate, moveTuple, remoteWake,
                    taskWorkCarrier, workqueueCarrier, ioUringCarrier,
                    timerCarrier, rcuCallbackCarrier, softirqCarrier,
                    endpointUse, directCallCarrier, ringCarrier,
                    derivedReceipt, deviceQueueCarrier, budgetReservation,
                    serverBorrowTicket, rootRunToken, unknownCarrier,
                    budgetSettled, budgetSettleCount, schedulerEffect,
                    asyncEffect, endpointEffect, monitorAdmissionEffect,
                    deviceEffect, budgetEffect, rootExecutionEffect,
                    budgetLeak, linuxCancelReceipt, flushAuthority,
                    pendingClearReceipt, cqeSettlementAuthority,
                    auditOnlyDrainReceipt, rcuVisibilityAuthority,
                    pidReuseAuthority, earlyReleaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

StartRevokeDrain ==
    /\ phase = "PendingInventory"
    /\ phase' = "RevokeDrainStarted"
    /\ embargoStarted' = TRUE
    /\ drainStarted' = TRUE
    /\ UNCHANGED <<inventoryKeyComplete, drainComplete, queuedUse,
                    selectedUse, deniedCandidate, moveTuple, remoteWake,
                    taskWorkCarrier, workqueueCarrier, ioUringCarrier,
                    timerCarrier, rcuCallbackCarrier, softirqCarrier,
                    endpointUse, directCallCarrier, ringCarrier,
                    derivedReceipt, deviceQueueCarrier, budgetReservation,
                    serverBorrowTicket, rootRunToken, unknownCarrier,
                    budgetSettled, budgetSettleCount, schedulerEffect,
                    asyncEffect, endpointEffect, monitorAdmissionEffect,
                    deviceEffect, budgetEffect, rootExecutionEffect,
                    budgetLeak, linuxCancelReceipt, flushAuthority,
                    pendingClearReceipt, cqeSettlementAuthority,
                    auditOnlyDrainReceipt, rcuVisibilityAuthority,
                    pidReuseAuthority, earlyReleaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

DrainSchedulerInventory ==
    /\ phase \in {"ExitDrainStarted", "RevokeDrainStarted"}
    /\ phase' = "SchedulerDrained"
    /\ queuedUse' = FALSE
    /\ selectedUse' = FALSE
    /\ deniedCandidate' = FALSE
    /\ moveTuple' = FALSE
    /\ remoteWake' = FALSE
    /\ UNCHANGED <<embargoStarted, inventoryKeyComplete, drainStarted,
                    drainComplete, taskWorkCarrier, workqueueCarrier,
                    ioUringCarrier, timerCarrier, rcuCallbackCarrier,
                    softirqCarrier, endpointUse, directCallCarrier,
                    ringCarrier, derivedReceipt, deviceQueueCarrier,
                    budgetReservation, serverBorrowTicket, rootRunToken,
                    unknownCarrier, budgetSettled, budgetSettleCount,
                    schedulerEffect, asyncEffect, endpointEffect,
                    monitorAdmissionEffect, deviceEffect, budgetEffect,
                    rootExecutionEffect, budgetLeak, linuxCancelReceipt,
                    flushAuthority, pendingClearReceipt,
                    cqeSettlementAuthority, auditOnlyDrainReceipt,
                    rcuVisibilityAuthority, pidReuseAuthority,
                    earlyReleaseAuthority, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

DrainAsyncInventory ==
    /\ phase = "SchedulerDrained"
    /\ phase' = "AsyncDrained"
    /\ taskWorkCarrier' = FALSE
    /\ workqueueCarrier' = FALSE
    /\ ioUringCarrier' = FALSE
    /\ timerCarrier' = FALSE
    /\ rcuCallbackCarrier' = FALSE
    /\ softirqCarrier' = FALSE
    /\ UNCHANGED <<embargoStarted, inventoryKeyComplete, drainStarted,
                    drainComplete, queuedUse, selectedUse, deniedCandidate,
                    moveTuple, remoteWake, endpointUse, directCallCarrier,
                    ringCarrier, derivedReceipt, deviceQueueCarrier,
                    budgetReservation, serverBorrowTicket, rootRunToken,
                    unknownCarrier, budgetSettled, budgetSettleCount,
                    schedulerEffect, asyncEffect, endpointEffect,
                    monitorAdmissionEffect, deviceEffect, budgetEffect,
                    rootExecutionEffect, budgetLeak, linuxCancelReceipt,
                    flushAuthority, pendingClearReceipt,
                    cqeSettlementAuthority, auditOnlyDrainReceipt,
                    rcuVisibilityAuthority, pidReuseAuthority,
                    earlyReleaseAuthority, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

DrainEndpointInventory ==
    /\ phase = "AsyncDrained"
    /\ phase' = "EndpointDrained"
    /\ endpointUse' = FALSE
    /\ UNCHANGED <<embargoStarted, inventoryKeyComplete, drainStarted,
                    drainComplete, queuedUse, selectedUse, deniedCandidate,
                    moveTuple, remoteWake, taskWorkCarrier, workqueueCarrier,
                    ioUringCarrier, timerCarrier, rcuCallbackCarrier,
                    softirqCarrier, directCallCarrier, ringCarrier,
                    derivedReceipt, deviceQueueCarrier, budgetReservation,
                    serverBorrowTicket, rootRunToken, unknownCarrier,
                    budgetSettled, budgetSettleCount, schedulerEffect,
                    asyncEffect, endpointEffect, monitorAdmissionEffect,
                    deviceEffect, budgetEffect, rootExecutionEffect,
                    budgetLeak, linuxCancelReceipt, flushAuthority,
                    pendingClearReceipt, cqeSettlementAuthority,
                    auditOnlyDrainReceipt, rcuVisibilityAuthority,
                    pidReuseAuthority, earlyReleaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

DrainMonitorAdmissionInventory ==
    /\ phase = "EndpointDrained"
    /\ phase' = "MonitorAdmissionDrained"
    /\ directCallCarrier' = FALSE
    /\ ringCarrier' = FALSE
    /\ derivedReceipt' = FALSE
    /\ UNCHANGED <<embargoStarted, inventoryKeyComplete, drainStarted,
                    drainComplete, queuedUse, selectedUse, deniedCandidate,
                    moveTuple, remoteWake, taskWorkCarrier, workqueueCarrier,
                    ioUringCarrier, timerCarrier, rcuCallbackCarrier,
                    softirqCarrier, endpointUse, deviceQueueCarrier,
                    budgetReservation, serverBorrowTicket, rootRunToken,
                    unknownCarrier, budgetSettled, budgetSettleCount,
                    schedulerEffect, asyncEffect, endpointEffect,
                    monitorAdmissionEffect, deviceEffect, budgetEffect,
                    rootExecutionEffect, budgetLeak, linuxCancelReceipt,
                    flushAuthority, pendingClearReceipt,
                    cqeSettlementAuthority, auditOnlyDrainReceipt,
                    rcuVisibilityAuthority, pidReuseAuthority,
                    earlyReleaseAuthority, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

DrainDeviceInventory ==
    /\ phase = "MonitorAdmissionDrained"
    /\ phase' = "DeviceDrained"
    /\ deviceQueueCarrier' = FALSE
    /\ UNCHANGED <<embargoStarted, inventoryKeyComplete, drainStarted,
                    drainComplete, queuedUse, selectedUse, deniedCandidate,
                    moveTuple, remoteWake, taskWorkCarrier, workqueueCarrier,
                    ioUringCarrier, timerCarrier, rcuCallbackCarrier,
                    softirqCarrier, endpointUse, directCallCarrier,
                    ringCarrier, derivedReceipt, budgetReservation,
                    serverBorrowTicket, rootRunToken, unknownCarrier,
                    budgetSettled, budgetSettleCount, schedulerEffect,
                    asyncEffect, endpointEffect, monitorAdmissionEffect,
                    deviceEffect, budgetEffect, rootExecutionEffect,
                    budgetLeak, linuxCancelReceipt, flushAuthority,
                    pendingClearReceipt, cqeSettlementAuthority,
                    auditOnlyDrainReceipt, rcuVisibilityAuthority,
                    pidReuseAuthority, earlyReleaseAuthority,
                    behaviorChangeClaim, monitorVerifiedClaim,
                    protectionClaim>>

SettleBudgetAndRootInventory ==
    /\ phase = "DeviceDrained"
    /\ phase' = "BudgetAndRootSettled"
    /\ budgetReservation' = FALSE
    /\ serverBorrowTicket' = FALSE
    /\ rootRunToken' = FALSE
    /\ budgetSettled' = TRUE
    /\ budgetSettleCount' = budgetSettleCount + 1
    /\ UNCHANGED <<embargoStarted, inventoryKeyComplete, drainStarted,
                    drainComplete, queuedUse, selectedUse, deniedCandidate,
                    moveTuple, remoteWake, taskWorkCarrier, workqueueCarrier,
                    ioUringCarrier, timerCarrier, rcuCallbackCarrier,
                    softirqCarrier, endpointUse, directCallCarrier,
                    ringCarrier, derivedReceipt, deviceQueueCarrier,
                    unknownCarrier, schedulerEffect, asyncEffect,
                    endpointEffect, monitorAdmissionEffect, deviceEffect,
                    budgetEffect, rootExecutionEffect, budgetLeak,
                    linuxCancelReceipt, flushAuthority, pendingClearReceipt,
                    cqeSettlementAuthority, auditOnlyDrainReceipt,
                    rcuVisibilityAuthority, pidReuseAuthority,
                    earlyReleaseAuthority, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

CompleteDrain ==
    /\ phase = "BudgetAndRootSettled"
    /\ inventoryKeyComplete
    /\ AllPendingClear
    /\ budgetSettled
    /\ budgetSettleCount = 1
    /\ phase' = "DrainComplete"
    /\ drainComplete' = TRUE
    /\ UNCHANGED <<embargoStarted, inventoryKeyComplete, drainStarted,
                    queuedUse, selectedUse, deniedCandidate, moveTuple,
                    remoteWake, taskWorkCarrier, workqueueCarrier,
                    ioUringCarrier, timerCarrier, rcuCallbackCarrier,
                    softirqCarrier, endpointUse, directCallCarrier,
                    ringCarrier, derivedReceipt, deviceQueueCarrier,
                    budgetReservation, serverBorrowTicket, rootRunToken,
                    unknownCarrier, budgetSettled, budgetSettleCount,
                    schedulerEffect, asyncEffect, endpointEffect,
                    monitorAdmissionEffect, deviceEffect, budgetEffect,
                    rootExecutionEffect, budgetLeak, linuxCancelReceipt,
                    flushAuthority, pendingClearReceipt,
                    cqeSettlementAuthority, auditOnlyDrainReceipt,
                    rcuVisibilityAuthority, pidReuseAuthority,
                    earlyReleaseAuthority, behaviorChangeClaim,
                    monitorVerifiedClaim, protectionClaim>>

TerminalStutter ==
    /\ phase = "DrainComplete"
    /\ UNCHANGED vars

SafeNext ==
    \/ PreparePendingInventory
    \/ StartExitDrain
    \/ StartRevokeDrain
    \/ DrainSchedulerInventory
    \/ DrainAsyncInventory
    \/ DrainEndpointInventory
    \/ DrainMonitorAdmissionInventory
    \/ DrainDeviceInventory
    \/ SettleBudgetAndRootInventory
    \/ CompleteDrain
    \/ TerminalStutter

SchedulerBad == {
    "BadExitCompleteWithRemoteWakePending",
    "BadExitCompleteWithQueuedFrozenRunUse",
    "BadFutexWaiterWakeAfterEndpointRevoke"
}

AsyncBad == {
    "BadRevokeCompleteWithWorkqueuePendingCarrier",
    "BadWorkqueueSelfRequeueOldCarrier",
    "BadIoUringLinkedReissueOldAuthority"
}

EndpointBad == {
    "BadEndpointUseAfterExitOrRevoke",
    "BadFutexWaiterWakeAfterEndpointRevoke"
}

MonitorAdmissionBad == {
    "BadDirectCallRevokeCompleteWithInFlight",
    "BadRingRevokeCompleteWithPendingSlotOrResponse",
    "BadDerivedReceiptLiveAfterRevokeComplete"
}

DeviceBad == {"BadDeviceQueueReassignBeforeDrain"}

BudgetBad == {
    "BadBudgetTicketRefundBeforeCarrierTerminal",
    "BadServerBorrowTicketSurvivesExitOrRevoke"
}

RootBad == {"BadRootTimerOrRunTokenLiveAfterExit"}

Unsafe(p) ==
    /\ phase = "Start"
    /\ phase' = p
    /\ embargoStarted' = TRUE
    /\ inventoryKeyComplete' = (p # "BadUnknownPendingCarrierTreatedAsDrained")
    /\ drainStarted' = TRUE
    /\ drainComplete' = TRUE
    /\ queuedUse' = (p = "BadExitCompleteWithQueuedFrozenRunUse")
    /\ selectedUse' = (p = "BadExitCompleteWithQueuedFrozenRunUse")
    /\ deniedCandidate' = (p = "BadExitCompleteWithQueuedFrozenRunUse")
    /\ moveTuple' = (p = "BadExitCompleteWithQueuedFrozenRunUse")
    /\ remoteWake' = (p \in {"BadExitCompleteWithRemoteWakePending",
                             "BadFutexWaiterWakeAfterEndpointRevoke"})
    /\ taskWorkCarrier' = FALSE
    /\ workqueueCarrier' = (p \in {"BadRevokeCompleteWithWorkqueuePendingCarrier",
                                  "BadWorkqueueSelfRequeueOldCarrier",
                                  "BadBudgetTicketRefundBeforeCarrierTerminal"})
    /\ ioUringCarrier' = (p \in {"BadIoUringLinkedReissueOldAuthority",
                                "BadIoUringCqeAfterRevokeComplete"})
    /\ timerCarrier' = FALSE
    /\ rcuCallbackCarrier' = FALSE
    /\ softirqCarrier' = FALSE
    /\ endpointUse' = (p \in {"BadEndpointUseAfterExitOrRevoke",
                              "BadFutexWaiterWakeAfterEndpointRevoke"})
    /\ directCallCarrier' = (p = "BadDirectCallRevokeCompleteWithInFlight")
    /\ ringCarrier' = (p = "BadRingRevokeCompleteWithPendingSlotOrResponse")
    /\ derivedReceipt' = (p = "BadDerivedReceiptLiveAfterRevokeComplete")
    /\ deviceQueueCarrier' = (p = "BadDeviceQueueReassignBeforeDrain")
    /\ budgetReservation' = (p \in {"BadBudgetReservationLeak",
                                   "BadBudgetTicketRefundBeforeCarrierTerminal"})
    /\ serverBorrowTicket' = (p = "BadServerBorrowTicketSurvivesExitOrRevoke")
    /\ rootRunToken' = (p = "BadRootTimerOrRunTokenLiveAfterExit")
    /\ unknownCarrier' = (p = "BadUnknownPendingCarrierTreatedAsDrained")
    /\ budgetSettled' = (p # "BadBudgetReservationLeak")
    /\ budgetSettleCount' =
        IF p = "BadBudgetDoubleSettle" THEN 2
        ELSE IF p = "BadBudgetReservationLeak" THEN 0
        ELSE 1
    /\ schedulerEffect' = (p \in SchedulerBad)
    /\ asyncEffect' = (p \in AsyncBad)
    /\ endpointEffect' = (p \in EndpointBad)
    /\ monitorAdmissionEffect' = (p \in MonitorAdmissionBad)
    /\ deviceEffect' = (p \in DeviceBad)
    /\ budgetEffect' = (p \in BudgetBad)
    /\ rootExecutionEffect' = (p \in RootBad)
    /\ budgetLeak' = (p = "BadBudgetReservationLeak")
    /\ linuxCancelReceipt' = (p \in {"BadWorkqueueCancelFlushAsDrainReceipt",
                                    "BadIoUringCancelAsDrainReceipt"})
    /\ flushAuthority' = (p = "BadWorkqueueCancelFlushAsDrainReceipt")
    /\ pendingClearReceipt' = (p = "BadWorkqueuePendingClearAsRevokeReceipt")
    /\ cqeSettlementAuthority' = (p = "BadIoUringCqeAfterRevokeComplete")
    /\ auditOnlyDrainReceipt' = (p = "BadAuditOnlyDrainAccepted")
    /\ rcuVisibilityAuthority' = (p = "BadRcuVisibilityAuthority")
    /\ pidReuseAuthority' = (p = "BadPidReuseMatchesPendingAuthority")
    /\ earlyReleaseAuthority' = (p = "BadExitReleaseBeforeDrainSettlement")
    /\ behaviorChangeClaim' = (p = "BadBehaviorChangeClaim")
    /\ monitorVerifiedClaim' = (p = "BadMonitorVerifiedClaim")
    /\ protectionClaim' = (p = "BadProtectionClaim")

NoBadPhase ==
    phase \notin BadPhases

NoSchedulerEffectAfterDrain ==
    drainStarted => ~schedulerEffect

NoAsyncEffectAfterDrain ==
    drainStarted => ~asyncEffect

NoEndpointEffectAfterDrain ==
    drainStarted => ~endpointEffect

NoMonitorAdmissionEffectAfterDrain ==
    drainStarted => ~monitorAdmissionEffect

NoDeviceEffectAfterDrain ==
    drainStarted => ~deviceEffect

NoBudgetSpendAfterDrain ==
    drainStarted => ~budgetEffect

NoRootExecutionAfterDrain ==
    drainStarted => ~rootExecutionEffect

NoPendingCarrierSurvivesComplete ==
    drainComplete => /\ inventoryKeyComplete /\ AllPendingClear

NoUnknownCarrierDefaultDrain ==
    drainComplete => /\ inventoryKeyComplete /\ ~unknownCarrier

NoBudgetLeakAfterComplete ==
    drainComplete => /\ budgetSettled /\ budgetSettleCount = 1 /\ ~budgetLeak

NoBudgetDoubleSettle ==
    budgetSettleCount <= 1

NoLinuxCleanupAsAuthorityReceipt ==
    /\ ~linuxCancelReceipt
    /\ ~flushAuthority
    /\ ~pendingClearReceipt
    /\ ~cqeSettlementAuthority
    /\ ~auditOnlyDrainReceipt

NoRcuVisibilityAuthority ==
    ~rcuVisibilityAuthority

NoPidReuseAuthority ==
    ~pidReuseAuthority

NoEarlyReleaseAuthority ==
    ~earlyReleaseAuthority

NoNonClaimOverreach ==
    /\ ~behaviorChangeClaim
    /\ ~monitorVerifiedClaim
    /\ ~protectionClaim

Safety ==
    /\ TypeOK
    /\ NoBadPhase
    /\ NoSchedulerEffectAfterDrain
    /\ NoAsyncEffectAfterDrain
    /\ NoEndpointEffectAfterDrain
    /\ NoMonitorAdmissionEffectAfterDrain
    /\ NoDeviceEffectAfterDrain
    /\ NoBudgetSpendAfterDrain
    /\ NoRootExecutionAfterDrain
    /\ NoPendingCarrierSurvivesComplete
    /\ NoUnknownCarrierDefaultDrain
    /\ NoBudgetLeakAfterComplete
    /\ NoBudgetDoubleSettle
    /\ NoLinuxCleanupAsAuthorityReceipt
    /\ NoRcuVisibilityAuthority
    /\ NoPidReuseAuthority
    /\ NoEarlyReleaseAuthority
    /\ NoNonClaimOverreach

Spec ==
    Init /\ [][SafeNext]_vars

UnsafeExitCompleteWithRemoteWakePendingSpec ==
    Init /\ [][Unsafe("BadExitCompleteWithRemoteWakePending")]_vars

UnsafeExitCompleteWithQueuedFrozenRunUseSpec ==
    Init /\ [][Unsafe("BadExitCompleteWithQueuedFrozenRunUse")]_vars

UnsafeExitReleaseBeforeDrainSettlementSpec ==
    Init /\ [][Unsafe("BadExitReleaseBeforeDrainSettlement")]_vars

UnsafePidReuseMatchesPendingAuthoritySpec ==
    Init /\ [][Unsafe("BadPidReuseMatchesPendingAuthority")]_vars

UnsafeRevokeCompleteWithWorkqueuePendingCarrierSpec ==
    Init /\ [][Unsafe("BadRevokeCompleteWithWorkqueuePendingCarrier")]_vars

UnsafeWorkqueueCancelFlushAsDrainReceiptSpec ==
    Init /\ [][Unsafe("BadWorkqueueCancelFlushAsDrainReceipt")]_vars

UnsafeWorkqueuePendingClearAsRevokeReceiptSpec ==
    Init /\ [][Unsafe("BadWorkqueuePendingClearAsRevokeReceipt")]_vars

UnsafeWorkqueueSelfRequeueOldCarrierSpec ==
    Init /\ [][Unsafe("BadWorkqueueSelfRequeueOldCarrier")]_vars

UnsafeIoUringCancelAsDrainReceiptSpec ==
    Init /\ [][Unsafe("BadIoUringCancelAsDrainReceipt")]_vars

UnsafeIoUringCqeAfterRevokeCompleteSpec ==
    Init /\ [][Unsafe("BadIoUringCqeAfterRevokeComplete")]_vars

UnsafeIoUringLinkedReissueOldAuthoritySpec ==
    Init /\ [][Unsafe("BadIoUringLinkedReissueOldAuthority")]_vars

UnsafeEndpointUseAfterExitOrRevokeSpec ==
    Init /\ [][Unsafe("BadEndpointUseAfterExitOrRevoke")]_vars

UnsafeFutexWaiterWakeAfterEndpointRevokeSpec ==
    Init /\ [][Unsafe("BadFutexWaiterWakeAfterEndpointRevoke")]_vars

UnsafeDirectCallRevokeCompleteWithInFlightSpec ==
    Init /\ [][Unsafe("BadDirectCallRevokeCompleteWithInFlight")]_vars

UnsafeRingRevokeCompleteWithPendingSlotOrResponseSpec ==
    Init /\ [][Unsafe("BadRingRevokeCompleteWithPendingSlotOrResponse")]_vars

UnsafeDerivedReceiptLiveAfterRevokeCompleteSpec ==
    Init /\ [][Unsafe("BadDerivedReceiptLiveAfterRevokeComplete")]_vars

UnsafeDeviceQueueReassignBeforeDrainSpec ==
    Init /\ [][Unsafe("BadDeviceQueueReassignBeforeDrain")]_vars

UnsafeBudgetTicketRefundBeforeCarrierTerminalSpec ==
    Init /\ [][Unsafe("BadBudgetTicketRefundBeforeCarrierTerminal")]_vars

UnsafeServerBorrowTicketSurvivesExitOrRevokeSpec ==
    Init /\ [][Unsafe("BadServerBorrowTicketSurvivesExitOrRevoke")]_vars

UnsafeRootTimerOrRunTokenLiveAfterExitSpec ==
    Init /\ [][Unsafe("BadRootTimerOrRunTokenLiveAfterExit")]_vars

UnsafeAuditOnlyDrainAcceptedSpec ==
    Init /\ [][Unsafe("BadAuditOnlyDrainAccepted")]_vars

UnsafeUnknownPendingCarrierTreatedAsDrainedSpec ==
    Init /\ [][Unsafe("BadUnknownPendingCarrierTreatedAsDrained")]_vars

UnsafeBudgetReservationLeakSpec ==
    Init /\ [][Unsafe("BadBudgetReservationLeak")]_vars

UnsafeBudgetDoubleSettleSpec ==
    Init /\ [][Unsafe("BadBudgetDoubleSettle")]_vars

UnsafeRcuVisibilityAuthoritySpec ==
    Init /\ [][Unsafe("BadRcuVisibilityAuthority")]_vars

UnsafeBehaviorChangeClaimSpec ==
    Init /\ [][Unsafe("BadBehaviorChangeClaim")]_vars

UnsafeMonitorVerifiedClaimSpec ==
    Init /\ [][Unsafe("BadMonitorVerifiedClaim")]_vars

UnsafeProtectionClaimSpec ==
    Init /\ [][Unsafe("BadProtectionClaim")]_vars

=============================================================================
