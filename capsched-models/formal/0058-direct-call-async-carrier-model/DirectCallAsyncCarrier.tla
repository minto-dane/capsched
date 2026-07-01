-------------------------- MODULE DirectCallAsyncCarrier --------------------------

CONSTANTS
    ALLOW_UNSAFE_GENERIC_WORK_AUTHORITY,
    ALLOW_UNSAFE_PENDING_OVERWRITE,
    ALLOW_UNSAFE_PENDING_REPLACE_WITHOUT_FLAG,
    ALLOW_UNSAFE_WORKER_IDENTITY_AUTHORITY,
    ALLOW_UNSAFE_SERVICE_ONLY_AUTHORITY,
    ALLOW_UNSAFE_MISSING_CALLER_FROZEN,
    ALLOW_UNSAFE_BUDGET_SERVICE_ONLY,
    ALLOW_UNSAFE_LINUX_MINTED_RECEIPT,
    ALLOW_UNSAFE_CONSUME_AFTER_REVOKE,
    ALLOW_UNSAFE_STALE_REVOKED_EXECUTION,
    ALLOW_UNSAFE_TRACE_PLAN_COVERAGE,
    ALLOW_UNSAFE_ABI_APPROVAL,
    ALLOW_UNSAFE_BEHAVIOR_CHANGE,
    ALLOW_UNSAFE_MONITOR_VERIFIED,
    ALLOW_UNSAFE_PROTECTION_CLAIM

VARIABLE state

vars == <<state>>

Callers == {"none", "callerA", "callerB"}
BudgetTickets == {"none", "ticketA", "ticketB"}
Receipts == {"none", "receiptA", "receiptB"}
Generations == {"none", "gen1", "gen2"}

Phases == {
    "Start",
    "CallerFrozen",
    "ServiceBound",
    "ReceiptMinted",
    "CarrierAllocated",
    "CarrierQueued",
    "CoalescedPendingRejected",
    "PendingProtected",
    "RevokeHandlingModeled",
    "RevokedPendingCarrierRejected",
    "WorkerReceivedCarrier",
    "ExecutedWithIntersection",
    "AsyncCarrierDesignAccepted",
    "BadGenericWorkAuthority",
    "BadPendingOverwrite",
    "BadPendingCarrierReplacement",
    "BadWorkerIdentityAuthority",
    "BadServiceOnlyAuthority",
    "BadMissingCallerFrozen",
    "BadBudgetServiceOnly",
    "BadLinuxMintedReceipt",
    "BadConsumeAfterRevoke",
    "BadStaleRevokedExecution",
    "BadTracePlanCoverage",
    "BadAbiApproval",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

StateFields == {
    "phase",
    "callerFrozen",
    "serviceAuthority",
    "monitorReceiptMinted",
    "typedCarrierAllocated",
    "carrierHasCallerFrozen",
    "carrierHasServiceAuthority",
    "carrierHasBudgetTicket",
    "carrierHasMonitorReceipt",
    "carrierCaller",
    "carrierBudgetTicket",
    "carrierReceipt",
    "carrierGeneration",
    "coalescedCaller",
    "coalescedBudgetTicket",
    "coalescedReceipt",
    "coalescedRejected",
    "workPending",
    "pendingOverwrite",
    "pendingProtected",
    "revokeHandlingModeled",
    "revoked",
    "staleCarrierRejected",
    "consumeAfterRevoke",
    "workerHasTypedCarrier",
    "workerIdentityAuthority",
    "genericWorkAuthority",
    "effectiveAuthorityIntersection",
    "serviceOnlyAuthority",
    "missingCallerFrozen",
    "budgetChargedToCaller",
    "budgetChargedToServiceOnly",
    "linuxMintedReceipt",
    "carrierConsumed",
    "traceCoverageClaim",
    "abiApproved",
    "behaviorChange",
    "monitorVerified",
    "protectionClaim",
    "asyncCarrierDesignAccepted",
    "badGenericWorkAuthority",
    "badPendingOverwrite",
    "badPendingCarrierReplacement",
    "badWorkerIdentityAuthority",
    "badServiceOnlyAuthority",
    "badMissingCallerFrozen",
    "badBudgetServiceOnly",
    "badLinuxMintedReceipt",
    "badConsumeAfterRevoke",
    "badStaleRevokedExecution",
    "badTracePlanCoverage",
    "badAbiApproval",
    "badBehaviorChange",
    "badMonitorVerified",
    "badProtectionClaim"
}

NonBoolFields == {
    "phase",
    "carrierCaller",
    "carrierBudgetTicket",
    "carrierReceipt",
    "carrierGeneration",
    "coalescedCaller",
    "coalescedBudgetTicket",
    "coalescedReceipt"
}

BoolFields == StateFields \ NonBoolFields

TerminalPhases == {
    "AsyncCarrierDesignAccepted",
    "RevokedPendingCarrierRejected",
    "BadGenericWorkAuthority",
    "BadPendingOverwrite",
    "BadPendingCarrierReplacement",
    "BadWorkerIdentityAuthority",
    "BadServiceOnlyAuthority",
    "BadMissingCallerFrozen",
    "BadBudgetServiceOnly",
    "BadLinuxMintedReceipt",
    "BadConsumeAfterRevoke",
    "BadStaleRevokedExecution",
    "BadTracePlanCoverage",
    "BadAbiApproval",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ state.carrierCaller \in Callers
    /\ state.carrierBudgetTicket \in BudgetTickets
    /\ state.carrierReceipt \in Receipts
    /\ state.carrierGeneration \in Generations
    /\ state.coalescedCaller \in Callers
    /\ state.coalescedBudgetTicket \in BudgetTickets
    /\ state.coalescedReceipt \in Receipts
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

CarrierComplete ==
    /\ state.typedCarrierAllocated
    /\ state.carrierHasCallerFrozen
    /\ state.carrierHasServiceAuthority
    /\ state.carrierHasBudgetTicket
    /\ state.carrierHasMonitorReceipt

OriginalCarrierPreserved ==
    /\ state.carrierCaller = "callerA"
    /\ state.carrierBudgetTicket = "ticketA"
    /\ state.carrierReceipt = "receiptA"
    /\ state.carrierGeneration = "gen1"

PendingCarrierPreserved ==
    state.workPending => OriginalCarrierPreserved

CoalescedSecondCallerNeverReplacesCarrier ==
    state.coalescedRejected =>
        /\ OriginalCarrierPreserved
        /\ state.coalescedCaller = "callerB"
        /\ state.coalescedBudgetTicket = "ticketB"
        /\ state.coalescedReceipt = "receiptB"

NoStaleCarrierExecution ==
    state.carrierConsumed => ~state.revoked

RevokedCarrierRejectionSafe ==
    state.staleCarrierRejected =>
        /\ state.revoked
        /\ ~state.workPending
        /\ ~state.workerHasTypedCarrier
        /\ ~state.carrierConsumed

AsyncCarrierSafe ==
    /\ state.callerFrozen
    /\ state.serviceAuthority
    /\ state.monitorReceiptMinted
    /\ CarrierComplete
    /\ OriginalCarrierPreserved
    /\ state.coalescedRejected
    /\ state.pendingProtected
    /\ state.revokeHandlingModeled
    /\ ~state.revoked
    /\ ~state.staleCarrierRejected
    /\ state.workerHasTypedCarrier
    /\ state.effectiveAuthorityIntersection
    /\ state.budgetChargedToCaller
    /\ state.carrierConsumed
    /\ ~state.genericWorkAuthority
    /\ ~state.pendingOverwrite
    /\ ~state.workerIdentityAuthority
    /\ ~state.serviceOnlyAuthority
    /\ ~state.missingCallerFrozen
    /\ ~state.budgetChargedToServiceOnly
    /\ ~state.linuxMintedReceipt
    /\ ~state.consumeAfterRevoke
    /\ ~state.traceCoverageClaim
    /\ ~state.abiApproved
    /\ ~state.behaviorChange
    /\ ~state.monitorVerified
    /\ ~state.protectionClaim

Init ==
    state = [
        phase |-> "Start",
        callerFrozen |-> FALSE,
        serviceAuthority |-> FALSE,
        monitorReceiptMinted |-> FALSE,
        typedCarrierAllocated |-> FALSE,
        carrierHasCallerFrozen |-> FALSE,
        carrierHasServiceAuthority |-> FALSE,
        carrierHasBudgetTicket |-> FALSE,
        carrierHasMonitorReceipt |-> FALSE,
        carrierCaller |-> "none",
        carrierBudgetTicket |-> "none",
        carrierReceipt |-> "none",
        carrierGeneration |-> "none",
        coalescedCaller |-> "none",
        coalescedBudgetTicket |-> "none",
        coalescedReceipt |-> "none",
        coalescedRejected |-> FALSE,
        workPending |-> FALSE,
        pendingOverwrite |-> FALSE,
        pendingProtected |-> FALSE,
        revokeHandlingModeled |-> FALSE,
        revoked |-> FALSE,
        staleCarrierRejected |-> FALSE,
        consumeAfterRevoke |-> FALSE,
        workerHasTypedCarrier |-> FALSE,
        workerIdentityAuthority |-> FALSE,
        genericWorkAuthority |-> FALSE,
        effectiveAuthorityIntersection |-> FALSE,
        serviceOnlyAuthority |-> FALSE,
        missingCallerFrozen |-> FALSE,
        budgetChargedToCaller |-> FALSE,
        budgetChargedToServiceOnly |-> FALSE,
        linuxMintedReceipt |-> FALSE,
        carrierConsumed |-> FALSE,
        traceCoverageClaim |-> FALSE,
        abiApproved |-> FALSE,
        behaviorChange |-> FALSE,
        monitorVerified |-> FALSE,
        protectionClaim |-> FALSE,
        asyncCarrierDesignAccepted |-> FALSE,
        badGenericWorkAuthority |-> FALSE,
        badPendingOverwrite |-> FALSE,
        badPendingCarrierReplacement |-> FALSE,
        badWorkerIdentityAuthority |-> FALSE,
        badServiceOnlyAuthority |-> FALSE,
        badMissingCallerFrozen |-> FALSE,
        badBudgetServiceOnly |-> FALSE,
        badLinuxMintedReceipt |-> FALSE,
        badConsumeAfterRevoke |-> FALSE,
        badStaleRevokedExecution |-> FALSE,
        badTracePlanCoverage |-> FALSE,
        badAbiApproval |-> FALSE,
        badBehaviorChange |-> FALSE,
        badMonitorVerified |-> FALSE,
        badProtectionClaim |-> FALSE
    ]

FreezeCallerAuthority ==
    /\ state.phase = "Start"
    /\ state' = [state EXCEPT !.phase = "CallerFrozen", !.callerFrozen = TRUE]

BindServiceAuthority ==
    /\ state.phase = "CallerFrozen"
    /\ state.callerFrozen
    /\ state' = [state EXCEPT !.phase = "ServiceBound", !.serviceAuthority = TRUE]

MonitorMintReceipt ==
    /\ state.phase = "ServiceBound"
    /\ state.callerFrozen
    /\ state.serviceAuthority
    /\ state' =
        [state EXCEPT
            !.phase = "ReceiptMinted",
            !.monitorReceiptMinted = TRUE
        ]

AllocateTypedCarrier ==
    /\ state.phase = "ReceiptMinted"
    /\ state.monitorReceiptMinted
    /\ state' =
        [state EXCEPT
            !.phase = "CarrierAllocated",
            !.typedCarrierAllocated = TRUE,
            !.carrierHasCallerFrozen = TRUE,
            !.carrierHasServiceAuthority = TRUE,
            !.carrierHasBudgetTicket = TRUE,
            !.carrierHasMonitorReceipt = TRUE,
            !.carrierCaller = "callerA",
            !.carrierBudgetTicket = "ticketA",
            !.carrierReceipt = "receiptA",
            !.carrierGeneration = "gen1"
        ]

QueueTypedCarrier ==
    /\ state.phase = "CarrierAllocated"
    /\ CarrierComplete
    /\ state' = [state EXCEPT !.phase = "CarrierQueued", !.workPending = TRUE]

RejectCoalescedSecondCaller ==
    /\ state.phase = "CarrierQueued"
    /\ state.workPending
    /\ OriginalCarrierPreserved
    /\ state' =
        [state EXCEPT
            !.phase = "CoalescedPendingRejected",
            !.coalescedCaller = "callerB",
            !.coalescedBudgetTicket = "ticketB",
            !.coalescedReceipt = "receiptB",
            !.coalescedRejected = TRUE
        ]

ProtectPendingCarrier ==
    /\ state.phase = "CoalescedPendingRejected"
    /\ state.workPending
    /\ state.coalescedRejected
    /\ OriginalCarrierPreserved
    /\ ~state.pendingOverwrite
    /\ state' =
        [state EXCEPT
            !.phase = "PendingProtected",
            !.pendingProtected = TRUE
        ]

ModelRevokeHandling ==
    /\ state.phase = "PendingProtected"
    /\ state.pendingProtected
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeHandlingModeled",
            !.revokeHandlingModeled = TRUE
        ]

RejectRevokedPendingCarrier ==
    /\ state.phase = "PendingProtected"
    /\ state.pendingProtected
    /\ OriginalCarrierPreserved
    /\ state' =
        [state EXCEPT
            !.phase = "RevokedPendingCarrierRejected",
            !.revokeHandlingModeled = TRUE,
            !.revoked = TRUE,
            !.staleCarrierRejected = TRUE,
            !.workPending = FALSE
        ]

WorkerReceivesCarrier ==
    /\ state.phase = "RevokeHandlingModeled"
    /\ state.revokeHandlingModeled
    /\ CarrierComplete
    /\ OriginalCarrierPreserved
    /\ state' =
        [state EXCEPT
            !.phase = "WorkerReceivedCarrier",
            !.workerHasTypedCarrier = TRUE
        ]

ExecuteWithIntersection ==
    /\ state.phase = "WorkerReceivedCarrier"
    /\ state.workerHasTypedCarrier
    /\ state.carrierHasCallerFrozen
    /\ state.carrierHasServiceAuthority
    /\ state.carrierHasBudgetTicket
    /\ state.carrierHasMonitorReceipt
    /\ OriginalCarrierPreserved
    /\ ~state.revoked
    /\ state' =
        [state EXCEPT
            !.phase = "ExecutedWithIntersection",
            !.effectiveAuthorityIntersection = TRUE,
            !.budgetChargedToCaller = TRUE,
            !.carrierConsumed = TRUE,
            !.workPending = FALSE
        ]

AcceptAsyncCarrierDesign ==
    /\ state.phase = "ExecutedWithIntersection"
    /\ AsyncCarrierSafe
    /\ state' =
        [state EXCEPT
            !.phase = "AsyncCarrierDesignAccepted",
            !.asyncCarrierDesignAccepted = TRUE
        ]

UnsafeGenericWorkAuthority ==
    /\ ALLOW_UNSAFE_GENERIC_WORK_AUTHORITY
    /\ state.phase = "CarrierQueued"
    /\ state' =
        [state EXCEPT
            !.phase = "BadGenericWorkAuthority",
            !.genericWorkAuthority = TRUE,
            !.badGenericWorkAuthority = TRUE
        ]

UnsafePendingOverwrite ==
    /\ ALLOW_UNSAFE_PENDING_OVERWRITE
    /\ state.phase = "CarrierQueued"
    /\ state.workPending
    /\ state' =
        [state EXCEPT
            !.phase = "BadPendingOverwrite",
            !.pendingOverwrite = TRUE,
            !.carrierCaller = "callerB",
            !.carrierBudgetTicket = "ticketB",
            !.carrierReceipt = "receiptB",
            !.carrierGeneration = "gen2",
            !.badPendingOverwrite = TRUE
        ]

UnsafePendingCarrierReplacement ==
    /\ ALLOW_UNSAFE_PENDING_REPLACE_WITHOUT_FLAG
    /\ state.phase = "CarrierQueued"
    /\ state.workPending
    /\ state' =
        [state EXCEPT
            !.phase = "BadPendingCarrierReplacement",
            !.carrierCaller = "callerB",
            !.carrierBudgetTicket = "ticketB",
            !.carrierReceipt = "receiptB",
            !.carrierGeneration = "gen2",
            !.badPendingCarrierReplacement = TRUE
        ]

UnsafeWorkerIdentityAuthority ==
    /\ ALLOW_UNSAFE_WORKER_IDENTITY_AUTHORITY
    /\ state.phase = "WorkerReceivedCarrier"
    /\ state' =
        [state EXCEPT
            !.phase = "BadWorkerIdentityAuthority",
            !.workerIdentityAuthority = TRUE,
            !.badWorkerIdentityAuthority = TRUE
        ]

UnsafeServiceOnlyAuthority ==
    /\ ALLOW_UNSAFE_SERVICE_ONLY_AUTHORITY
    /\ state.phase = "WorkerReceivedCarrier"
    /\ state' =
        [state EXCEPT
            !.phase = "BadServiceOnlyAuthority",
            !.serviceOnlyAuthority = TRUE,
            !.badServiceOnlyAuthority = TRUE
        ]

UnsafeMissingCallerFrozen ==
    /\ ALLOW_UNSAFE_MISSING_CALLER_FROZEN
    /\ state.phase = "ReceiptMinted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadMissingCallerFrozen",
            !.missingCallerFrozen = TRUE,
            !.carrierHasCallerFrozen = FALSE,
            !.badMissingCallerFrozen = TRUE
        ]

UnsafeBudgetServiceOnly ==
    /\ ALLOW_UNSAFE_BUDGET_SERVICE_ONLY
    /\ state.phase = "WorkerReceivedCarrier"
    /\ state' =
        [state EXCEPT
            !.phase = "BadBudgetServiceOnly",
            !.budgetChargedToServiceOnly = TRUE,
            !.badBudgetServiceOnly = TRUE
        ]

UnsafeLinuxMintedReceipt ==
    /\ ALLOW_UNSAFE_LINUX_MINTED_RECEIPT
    /\ state.phase = "ServiceBound"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxMintedReceipt",
            !.linuxMintedReceipt = TRUE,
            !.badLinuxMintedReceipt = TRUE
        ]

UnsafeConsumeAfterRevoke ==
    /\ ALLOW_UNSAFE_CONSUME_AFTER_REVOKE
    /\ state.phase = "RevokeHandlingModeled"
    /\ state' =
        [state EXCEPT
            !.phase = "BadConsumeAfterRevoke",
            !.revoked = TRUE,
            !.consumeAfterRevoke = TRUE,
            !.badConsumeAfterRevoke = TRUE
        ]

UnsafeStaleRevokedExecution ==
    /\ ALLOW_UNSAFE_STALE_REVOKED_EXECUTION
    /\ state.phase = "RevokeHandlingModeled"
    /\ state' =
        [state EXCEPT
            !.phase = "BadStaleRevokedExecution",
            !.revoked = TRUE,
            !.workerHasTypedCarrier = TRUE,
            !.effectiveAuthorityIntersection = TRUE,
            !.budgetChargedToCaller = TRUE,
            !.carrierConsumed = TRUE,
            !.workPending = FALSE,
            !.badStaleRevokedExecution = TRUE
        ]

UnsafeTracePlanCoverage ==
    /\ ALLOW_UNSAFE_TRACE_PLAN_COVERAGE
    /\ state.phase = "CarrierQueued"
    /\ state' =
        [state EXCEPT
            !.phase = "BadTracePlanCoverage",
            !.traceCoverageClaim = TRUE,
            !.badTracePlanCoverage = TRUE
        ]

UnsafeAbiApproval ==
    /\ ALLOW_UNSAFE_ABI_APPROVAL
    /\ state.phase = "CarrierQueued"
    /\ state' =
        [state EXCEPT
            !.phase = "BadAbiApproval",
            !.abiApproved = TRUE,
            !.badAbiApproval = TRUE
        ]

UnsafeBehaviorChange ==
    /\ ALLOW_UNSAFE_BEHAVIOR_CHANGE
    /\ state.phase = "CarrierQueued"
    /\ state' =
        [state EXCEPT
            !.phase = "BadBehaviorChange",
            !.behaviorChange = TRUE,
            !.badBehaviorChange = TRUE
        ]

UnsafeMonitorVerified ==
    /\ ALLOW_UNSAFE_MONITOR_VERIFIED
    /\ state.phase = "CarrierQueued"
    /\ state' =
        [state EXCEPT
            !.phase = "BadMonitorVerified",
            !.monitorVerified = TRUE,
            !.badMonitorVerified = TRUE
        ]

UnsafeProtectionClaim ==
    /\ ALLOW_UNSAFE_PROTECTION_CLAIM
    /\ state.phase = "CarrierQueued"
    /\ state' =
        [state EXCEPT
            !.phase = "BadProtectionClaim",
            !.protectionClaim = TRUE,
            !.badProtectionClaim = TRUE
        ]

Next ==
    IF state.phase \in TerminalPhases
    THEN UNCHANGED vars
    ELSE
        \/ FreezeCallerAuthority
        \/ BindServiceAuthority
        \/ MonitorMintReceipt
        \/ AllocateTypedCarrier
        \/ QueueTypedCarrier
        \/ RejectCoalescedSecondCaller
        \/ ProtectPendingCarrier
        \/ ModelRevokeHandling
        \/ RejectRevokedPendingCarrier
        \/ WorkerReceivesCarrier
        \/ ExecuteWithIntersection
        \/ AcceptAsyncCarrierDesign
        \/ UnsafeGenericWorkAuthority
        \/ UnsafePendingOverwrite
        \/ UnsafePendingCarrierReplacement
        \/ UnsafeWorkerIdentityAuthority
        \/ UnsafeServiceOnlyAuthority
        \/ UnsafeMissingCallerFrozen
        \/ UnsafeBudgetServiceOnly
        \/ UnsafeLinuxMintedReceipt
        \/ UnsafeConsumeAfterRevoke
        \/ UnsafeStaleRevokedExecution
        \/ UnsafeTracePlanCoverage
        \/ UnsafeAbiApproval
        \/ UnsafeBehaviorChange
        \/ UnsafeMonitorVerified
        \/ UnsafeProtectionClaim

AcceptedDesignRequiresAsyncCarrierSafety ==
    state.asyncCarrierDesignAccepted => AsyncCarrierSafe

NoGenericWorkAuthority == ~state.genericWorkAuthority
NoPendingOverwrite == ~state.pendingOverwrite
WorkerIdentityIsNotAuthority == ~state.workerIdentityAuthority
NoServiceOnlyAuthority == ~state.serviceOnlyAuthority
CallerFrozenRequired == ~state.missingCallerFrozen
BudgetTicketChargedToCaller == ~state.budgetChargedToServiceOnly
NoLinuxMintedReceipt == ~state.linuxMintedReceipt
NoConsumeAfterRevoke == ~state.consumeAfterRevoke
NoTraceCoverageClaim == ~state.traceCoverageClaim
NoAbiApproval == ~state.abiApproved
NoBehaviorChange == ~state.behaviorChange
NoMonitorVerifiedClaim == ~state.monitorVerified
NoProtectionClaim == ~state.protectionClaim

NoBadGenericWorkAuthority == ~state.badGenericWorkAuthority
NoBadPendingOverwrite == ~state.badPendingOverwrite
NoBadPendingCarrierReplacement == ~state.badPendingCarrierReplacement
NoBadWorkerIdentityAuthority == ~state.badWorkerIdentityAuthority
NoBadServiceOnlyAuthority == ~state.badServiceOnlyAuthority
NoBadMissingCallerFrozen == ~state.badMissingCallerFrozen
NoBadBudgetServiceOnly == ~state.badBudgetServiceOnly
NoBadLinuxMintedReceipt == ~state.badLinuxMintedReceipt
NoBadConsumeAfterRevoke == ~state.badConsumeAfterRevoke
NoBadStaleRevokedExecution == ~state.badStaleRevokedExecution
NoBadTracePlanCoverage == ~state.badTracePlanCoverage
NoBadAbiApproval == ~state.badAbiApproval
NoBadBehaviorChange == ~state.badBehaviorChange
NoBadMonitorVerified == ~state.badMonitorVerified
NoBadProtectionClaim == ~state.badProtectionClaim

=============================================================================
