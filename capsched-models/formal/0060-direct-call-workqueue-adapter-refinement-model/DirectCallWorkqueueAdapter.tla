----------------------- MODULE DirectCallWorkqueueAdapter -----------------------

EXTENDS Naturals

CONSTANTS
    ALLOW_UNSAFE_SIDE_EFFECT_BEFORE_VALIDATE,
    ALLOW_UNSAFE_PENDING_OVERWRITE,
    ALLOW_UNSAFE_SECOND_CALLER_LEAK,
    ALLOW_UNSAFE_DELAYED_RETIME_REFRESH,
    ALLOW_UNSAFE_SELF_REQUEUE_REFRESH,
    ALLOW_UNSAFE_WORKER_IDENTITY_AUTHORITY,
    ALLOW_UNSAFE_CANCEL_FLUSH_REVOKE_RECEIPT,
    ALLOW_UNSAFE_RELEASE_FREES_LINUX_WORK,
    ALLOW_UNSAFE_DOUBLE_SETTLEMENT,
    ALLOW_UNSAFE_FREEZE_AFTER_PUBLICATION,
    ALLOW_UNSAFE_SERVICE_ONLY_BUDGET,
    ALLOW_UNSAFE_RESCUER_BYPASS,
    ALLOW_UNSAFE_PENDING_CLEAR_REVOKE_RECEIPT,
    ALLOW_UNSAFE_ABI_APPROVAL,
    ALLOW_UNSAFE_BEHAVIOR_CHANGE,
    ALLOW_UNSAFE_MONITOR_VERIFIED,
    ALLOW_UNSAFE_PROTECTION_CLAIM

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "EmptyCreated",
    "Frozen",
    "Bound",
    "Published",
    "SecondHandled",
    "Retimed",
    "Dispatched",
    "RevokeChecked",
    "Validated",
    "SideEffected",
    "SelfRequeueHandled",
    "Settled",
    "Released",
    "Accepted",
    "BadSideEffectBeforeValidate",
    "BadPendingOverwrite",
    "BadSecondCallerLeak",
    "BadDelayedRetimeRefresh",
    "BadSelfRequeueRefresh",
    "BadWorkerIdentityAuthority",
    "BadCancelFlushRevokeReceipt",
    "BadReleaseFreesLinuxWork",
    "BadDoubleSettlement",
    "BadFreezeAfterPublication",
    "BadServiceOnlyBudget",
    "BadRescuerBypass",
    "BadPendingClearRevokeReceipt",
    "BadAbiApproval",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

TerminalPhases == {
    "Accepted",
    "BadSideEffectBeforeValidate",
    "BadPendingOverwrite",
    "BadSecondCallerLeak",
    "BadDelayedRetimeRefresh",
    "BadSelfRequeueRefresh",
    "BadWorkerIdentityAuthority",
    "BadCancelFlushRevokeReceipt",
    "BadReleaseFreesLinuxWork",
    "BadDoubleSettlement",
    "BadFreezeAfterPublication",
    "BadServiceOnlyBudget",
    "BadRescuerBypass",
    "BadPendingClearRevokeReceipt",
    "BadAbiApproval",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

SecondCandidateStates == {
    "none",
    "rejected_settled_released",
    "leaked",
    "overwritten"
}

StateFields == {
    "phase",
    "carrierCreated",
    "frozen",
    "bound",
    "published",
    "publishedBeforeFreeze",
    "pending",
    "firstCarrierPreserved",
    "secondCandidateState",
    "delayedRetimed",
    "selfRequeueHandled",
    "receiptRefreshed",
    "callbackEntered",
    "revokeChecked",
    "validated",
    "effectiveSubsetCaller",
    "effectiveSubsetService",
    "sideEffect",
    "settled",
    "released",
    "settlementCount",
    "budgetChargedToCaller",
    "budgetChargedToServiceOnly",
    "pendingOverwrite",
    "workerIdentityAuthority",
    "cancelFlushRevokeReceipt",
    "pendingClearRevokeReceipt",
    "rescuerBypass",
    "releaseFreesLinuxWork",
    "abiApproved",
    "behaviorChange",
    "monitorVerified",
    "protectionClaim",
    "accepted"
}

NonBoolFields == {"phase", "secondCandidateState", "settlementCount"}
BoolFields == StateFields \ NonBoolFields

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ state.secondCandidateState \in SecondCandidateStates
    /\ state.settlementCount \in 0..2
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        carrierCreated |-> FALSE,
        frozen |-> FALSE,
        bound |-> FALSE,
        published |-> FALSE,
        publishedBeforeFreeze |-> FALSE,
        pending |-> FALSE,
        firstCarrierPreserved |-> FALSE,
        secondCandidateState |-> "none",
        delayedRetimed |-> FALSE,
        selfRequeueHandled |-> FALSE,
        receiptRefreshed |-> FALSE,
        callbackEntered |-> FALSE,
        revokeChecked |-> FALSE,
        validated |-> FALSE,
        effectiveSubsetCaller |-> FALSE,
        effectiveSubsetService |-> FALSE,
        sideEffect |-> FALSE,
        settled |-> FALSE,
        released |-> FALSE,
        settlementCount |-> 0,
        budgetChargedToCaller |-> FALSE,
        budgetChargedToServiceOnly |-> FALSE,
        pendingOverwrite |-> FALSE,
        workerIdentityAuthority |-> FALSE,
        cancelFlushRevokeReceipt |-> FALSE,
        pendingClearRevokeReceipt |-> FALSE,
        rescuerBypass |-> FALSE,
        releaseFreesLinuxWork |-> FALSE,
        abiApproved |-> FALSE,
        behaviorChange |-> FALSE,
        monitorVerified |-> FALSE,
        protectionClaim |-> FALSE,
        accepted |-> FALSE
    ]

CreateEmptyCarrier ==
    /\ state.phase = "Start"
    /\ state' = [state EXCEPT
        !.phase = "EmptyCreated",
        !.carrierCreated = TRUE]

FreezeCallerTuple ==
    /\ state.phase = "EmptyCreated"
    /\ state.carrierCreated
    /\ state' = [state EXCEPT
        !.phase = "Frozen",
        !.frozen = TRUE,
        !.firstCarrierPreserved = TRUE]

BindServiceAuthority ==
    /\ state.phase = "Frozen"
    /\ state.frozen
    /\ state' = [state EXCEPT
        !.phase = "Bound",
        !.bound = TRUE]

PublishTypedWork ==
    /\ state.phase = "Bound"
    /\ state.frozen
    /\ state.bound
    /\ state' = [state EXCEPT
        !.phase = "Published",
        !.published = TRUE,
        !.pending = TRUE]

HandleQueueWorkFalseSecondCaller ==
    /\ state.phase = "Published"
    /\ state.pending
    /\ state.firstCarrierPreserved
    /\ state' = [state EXCEPT
        !.phase = "SecondHandled",
        !.secondCandidateState = "rejected_settled_released"]

HandleDelayedRetimeWithoutRefresh ==
    /\ state.phase = "SecondHandled"
    /\ state.pending
    /\ state' = [state EXCEPT
        !.phase = "Retimed",
        !.delayedRetimed = TRUE]

DispatchToWorkerCallback ==
    /\ state.phase = "Retimed"
    /\ state.pending
    /\ state.frozen
    /\ state.bound
    /\ state.firstCarrierPreserved
    /\ state' = [state EXCEPT
        !.phase = "Dispatched",
        !.pending = FALSE,
        !.callbackEntered = TRUE]

RevokeCheckBeforeCallbackUse ==
    /\ state.phase = "Dispatched"
    /\ state.callbackEntered
    /\ state' = [state EXCEPT
        !.phase = "RevokeChecked",
        !.revokeChecked = TRUE]

ValidateBeforeSideEffect ==
    /\ state.phase = "RevokeChecked"
    /\ state.revokeChecked
    /\ state' = [state EXCEPT
        !.phase = "Validated",
        !.validated = TRUE,
        !.effectiveSubsetCaller = TRUE,
        !.effectiveSubsetService = TRUE]

DoValidatedSideEffect ==
    /\ state.phase = "Validated"
    /\ state.validated
    /\ state.revokeChecked
    /\ state.effectiveSubsetCaller
    /\ state.effectiveSubsetService
    /\ state' = [state EXCEPT
        !.phase = "SideEffected",
        !.sideEffect = TRUE]

HandleSelfRequeueWithoutRefresh ==
    /\ state.phase = "SideEffected"
    /\ state.sideEffect
    /\ state' = [state EXCEPT
        !.phase = "SelfRequeueHandled",
        !.selfRequeueHandled = TRUE]

SettleOnce ==
    /\ state.phase = "SelfRequeueHandled"
    /\ state.sideEffect
    /\ state' = [state EXCEPT
        !.phase = "Settled",
        !.settled = TRUE,
        !.settlementCount = 1,
        !.budgetChargedToCaller = TRUE]

ReleaseCapschedRefsOnly ==
    /\ state.phase = "Settled"
    /\ state.settlementCount = 1
    /\ state' = [state EXCEPT
        !.phase = "Released",
        !.released = TRUE]

AcceptWorkqueueAdapter ==
    /\ state.phase = "Released"
    /\ state.released
    /\ state' = [state EXCEPT
        !.phase = "Accepted",
        !.accepted = TRUE]

BadSideEffectBeforeValidate ==
    /\ ALLOW_UNSAFE_SIDE_EFFECT_BEFORE_VALIDATE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadSideEffectBeforeValidate",
        !.sideEffect = TRUE]

BadPendingOverwrite ==
    /\ ALLOW_UNSAFE_PENDING_OVERWRITE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadPendingOverwrite",
        !.pendingOverwrite = TRUE,
        !.secondCandidateState = "overwritten"]

BadSecondCallerLeak ==
    /\ ALLOW_UNSAFE_SECOND_CALLER_LEAK
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadSecondCallerLeak",
        !.secondCandidateState = "leaked"]

BadDelayedRetimeRefresh ==
    /\ ALLOW_UNSAFE_DELAYED_RETIME_REFRESH
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadDelayedRetimeRefresh",
        !.delayedRetimed = TRUE,
        !.receiptRefreshed = TRUE]

BadSelfRequeueRefresh ==
    /\ ALLOW_UNSAFE_SELF_REQUEUE_REFRESH
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadSelfRequeueRefresh",
        !.selfRequeueHandled = TRUE,
        !.receiptRefreshed = TRUE]

BadWorkerIdentityAuthority ==
    /\ ALLOW_UNSAFE_WORKER_IDENTITY_AUTHORITY
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadWorkerIdentityAuthority",
        !.workerIdentityAuthority = TRUE]

BadCancelFlushRevokeReceipt ==
    /\ ALLOW_UNSAFE_CANCEL_FLUSH_REVOKE_RECEIPT
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadCancelFlushRevokeReceipt",
        !.cancelFlushRevokeReceipt = TRUE]

BadReleaseFreesLinuxWork ==
    /\ ALLOW_UNSAFE_RELEASE_FREES_LINUX_WORK
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadReleaseFreesLinuxWork",
        !.releaseFreesLinuxWork = TRUE]

BadDoubleSettlement ==
    /\ ALLOW_UNSAFE_DOUBLE_SETTLEMENT
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadDoubleSettlement",
        !.settlementCount = 2]

BadFreezeAfterPublication ==
    /\ ALLOW_UNSAFE_FREEZE_AFTER_PUBLICATION
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadFreezeAfterPublication",
        !.published = TRUE,
        !.pending = TRUE,
        !.publishedBeforeFreeze = TRUE]

BadServiceOnlyBudget ==
    /\ ALLOW_UNSAFE_SERVICE_ONLY_BUDGET
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadServiceOnlyBudget",
        !.budgetChargedToServiceOnly = TRUE]

BadRescuerBypass ==
    /\ ALLOW_UNSAFE_RESCUER_BYPASS
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadRescuerBypass",
        !.rescuerBypass = TRUE]

BadPendingClearRevokeReceipt ==
    /\ ALLOW_UNSAFE_PENDING_CLEAR_REVOKE_RECEIPT
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadPendingClearRevokeReceipt",
        !.pending = FALSE,
        !.pendingClearRevokeReceipt = TRUE]

BadAbiApproval ==
    /\ ALLOW_UNSAFE_ABI_APPROVAL
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadAbiApproval",
        !.abiApproved = TRUE]

BadBehaviorChange ==
    /\ ALLOW_UNSAFE_BEHAVIOR_CHANGE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadBehaviorChange",
        !.behaviorChange = TRUE]

BadMonitorVerified ==
    /\ ALLOW_UNSAFE_MONITOR_VERIFIED
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadMonitorVerified",
        !.monitorVerified = TRUE]

BadProtectionClaim ==
    /\ ALLOW_UNSAFE_PROTECTION_CLAIM
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadProtectionClaim",
        !.protectionClaim = TRUE]

Next ==
    IF state.phase \in TerminalPhases THEN
        UNCHANGED state
    ELSE
        \/ CreateEmptyCarrier
        \/ FreezeCallerTuple
        \/ BindServiceAuthority
        \/ PublishTypedWork
        \/ HandleQueueWorkFalseSecondCaller
        \/ HandleDelayedRetimeWithoutRefresh
        \/ DispatchToWorkerCallback
        \/ RevokeCheckBeforeCallbackUse
        \/ ValidateBeforeSideEffect
        \/ DoValidatedSideEffect
        \/ HandleSelfRequeueWithoutRefresh
        \/ SettleOnce
        \/ ReleaseCapschedRefsOnly
        \/ AcceptWorkqueueAdapter
        \/ BadSideEffectBeforeValidate
        \/ BadPendingOverwrite
        \/ BadSecondCallerLeak
        \/ BadDelayedRetimeRefresh
        \/ BadSelfRequeueRefresh
        \/ BadWorkerIdentityAuthority
        \/ BadCancelFlushRevokeReceipt
        \/ BadReleaseFreesLinuxWork
        \/ BadDoubleSettlement
        \/ BadFreezeAfterPublication
        \/ BadServiceOnlyBudget
        \/ BadRescuerBypass
        \/ BadPendingClearRevokeReceipt
        \/ BadAbiApproval
        \/ BadBehaviorChange
        \/ BadMonitorVerified
        \/ BadProtectionClaim

Spec == Init /\ [][Next]_vars

NoSideEffectBeforeValidate ==
    state.sideEffect => /\ state.validated
                        /\ state.revokeChecked
                        /\ state.effectiveSubsetCaller
                        /\ state.effectiveSubsetService

PublicationRequiresFrozenAndBound ==
    state.published => /\ state.frozen
                       /\ state.bound
                       /\ ~state.publishedBeforeFreeze

NoPendingOverwrite == ~state.pendingOverwrite

NoSecondCallerLeak == state.secondCandidateState # "leaked"

NoReceiptRefreshFromRetimeOrRequeue == ~state.receiptRefreshed

NoWorkerIdentityAuthority == ~state.workerIdentityAuthority

NoCancelFlushRevokeReceipt == ~state.cancelFlushRevokeReceipt

NoPendingClearRevokeReceipt == ~state.pendingClearRevokeReceipt

NoServiceOnlyBudget == ~state.budgetChargedToServiceOnly

NoRescuerBypass == ~state.rescuerBypass

ReleaseDoesNotFreeLinuxWork == ~state.releaseFreesLinuxWork

SettlementAtMostOnce == state.settlementCount <= 1

NoAbiApproval == ~state.abiApproved

NoBehaviorChange == ~state.behaviorChange

NoMonitorVerifiedClaim == ~state.monitorVerified

NoProtectionClaim == ~state.protectionClaim

AcceptedImpliesWorkqueueAdapterSafety ==
    state.accepted =>
        /\ state.frozen
        /\ state.bound
        /\ state.published
        /\ state.firstCarrierPreserved
        /\ state.secondCandidateState = "rejected_settled_released"
        /\ state.delayedRetimed
        /\ state.callbackEntered
        /\ state.revokeChecked
        /\ state.validated
        /\ state.sideEffect
        /\ state.selfRequeueHandled
        /\ state.settlementCount = 1
        /\ state.budgetChargedToCaller
        /\ ~state.budgetChargedToServiceOnly
        /\ state.released
        /\ ~state.publishedBeforeFreeze
        /\ ~state.pendingOverwrite
        /\ ~state.receiptRefreshed
        /\ ~state.workerIdentityAuthority
        /\ ~state.cancelFlushRevokeReceipt
        /\ ~state.pendingClearRevokeReceipt
        /\ ~state.rescuerBypass
        /\ ~state.releaseFreesLinuxWork
        /\ ~state.abiApproved
        /\ ~state.behaviorChange
        /\ ~state.monitorVerified
        /\ ~state.protectionClaim

=============================================================================
