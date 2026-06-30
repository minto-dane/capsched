-------------------- MODULE CombinedAdmissionCarriers --------------------

CONSTANTS
    ALLOW_UNSAFE_SEPARATE_REPLAY_NAMESPACE,
    ALLOW_UNSAFE_DUPLICATE_SUCCESS_FALLBACK,
    ALLOW_UNSAFE_CARRIER_LOCAL_LEDGER,
    ALLOW_UNSAFE_CARRIER_SHADOW_GENERATION,
    ALLOW_UNSAFE_REVOKE_STOPS_ONE_CARRIER,
    ALLOW_UNSAFE_REVOKE_WITH_DIRECT_INFLIGHT,
    ALLOW_UNSAFE_REVOKE_WITH_RING_PENDING,
    ALLOW_UNSAFE_RING_FULL_AS_MONITOR_FAILURE,
    ALLOW_UNSAFE_RESPONSE_WITHOUT_SHARED_LEDGER,
    ALLOW_UNSAFE_EPOCH_SPLIT,
    ALLOW_UNSAFE_ATTEMPT_FROM_CARRIER_ID

VARIABLE state

vars == <<state>>

CarrierTypes == {"None", "Direct", "Ring", "FallbackDirect"}

Phases == {
    "Start",
    "DirectSubmitted",
    "FallbackDirectSubmitted",
    "DirectRequestFrozen",
    "DirectRequestValidated",
    "RingSubmitted",
    "RingFullAccounted",
    "RingSlotClaimed",
    "RingRequestFrozen",
    "RingRequestValidated",
    "SharedReplayConsumed",
    "SharedLedgerWritten",
    "DirectResponseReturned",
    "RingResponsePublished",
    "RingResponseConsumed",
    "ShadowRefreshed",
    "RevokeStarted",
    "OldEpochAdmissionsStopped",
    "NewReceiptEmbargoed",
    "AllCarriersDrained",
    "DerivedReceiptsRevoked",
    "SharedShadowInvalidated",
    "RevokeComplete",
    "BadSeparateReplayNamespace",
    "BadDuplicateSuccessFallback",
    "BadCarrierLocalLedger",
    "BadCarrierShadowGeneration",
    "BadRevokeStopsOneCarrier",
    "BadRevokeWithDirectInFlight",
    "BadRevokeWithRingPending",
    "BadRingFullAsMonitorFailure",
    "BadResponseWithoutSharedLedger",
    "BadEpochSplit",
    "BadAttemptFromCarrierId"
}

StateFields == {
    "phase",
    "carrier",
    "directSubmitted",
    "ringSubmitted",
    "fallbackRequested",
    "monitorEntry",
    "monitorSlotClaim",
    "canonicalAttemptAssigned",
    "carrierLocalAttemptUsed",
    "requestFrozen",
    "requestValidated",
    "epochsUnified",
    "carrierEpochSplit",
    "sharedReplayConsumed",
    "carrierLocalReplayConsumed",
    "sharedLedgerWritten",
    "carrierLocalLedgerWritten",
    "directSuccess",
    "ringSuccess",
    "responseReturned",
    "responsePublished",
    "shadowRefreshed",
    "shadowFromLedger",
    "sharedShadowGeneration",
    "carrierShadowGeneration",
    "ringFullAccounted",
    "ringFullConsumedReplay",
    "ringFullMonitorFailure",
    "directInFlight",
    "ringPendingSlot",
    "ringPendingResponse",
    "revokeStarted",
    "oldEpochDirectStopped",
    "oldEpochRingStopped",
    "newReceiptEmbargoed",
    "directInFlightDrained",
    "ringPendingDrained",
    "pendingResponsesDrained",
    "derivedReceiptsRevoked",
    "shadowInvalidated",
    "revokeComplete",
    "newSuccessAfterRevoke",
    "badSeparateReplayNamespace",
    "badDuplicateSuccessFallback",
    "badCarrierLocalLedger",
    "badCarrierShadowGeneration",
    "badRevokeStopsOneCarrier",
    "badRevokeWithDirectInFlight",
    "badRevokeWithRingPending",
    "badRingFullAsMonitorFailure",
    "badResponseWithoutSharedLedger",
    "badEpochSplit",
    "badAttemptFromCarrierId"
}

BoolFields == StateFields \ {"phase", "carrier"}

TerminalPhases == {
    "ShadowRefreshed",
    "RevokeComplete",
    "BadSeparateReplayNamespace",
    "BadDuplicateSuccessFallback",
    "BadCarrierLocalLedger",
    "BadCarrierShadowGeneration",
    "BadRevokeStopsOneCarrier",
    "BadRevokeWithDirectInFlight",
    "BadRevokeWithRingPending",
    "BadRingFullAsMonitorFailure",
    "BadResponseWithoutSharedLedger",
    "BadEpochSplit",
    "BadAttemptFromCarrierId"
}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ state.carrier \in CarrierTypes
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        carrier |-> "None",
        directSubmitted |-> FALSE,
        ringSubmitted |-> FALSE,
        fallbackRequested |-> FALSE,
        monitorEntry |-> FALSE,
        monitorSlotClaim |-> FALSE,
        canonicalAttemptAssigned |-> FALSE,
        carrierLocalAttemptUsed |-> FALSE,
        requestFrozen |-> FALSE,
        requestValidated |-> FALSE,
        epochsUnified |-> FALSE,
        carrierEpochSplit |-> FALSE,
        sharedReplayConsumed |-> FALSE,
        carrierLocalReplayConsumed |-> FALSE,
        sharedLedgerWritten |-> FALSE,
        carrierLocalLedgerWritten |-> FALSE,
        directSuccess |-> FALSE,
        ringSuccess |-> FALSE,
        responseReturned |-> FALSE,
        responsePublished |-> FALSE,
        shadowRefreshed |-> FALSE,
        shadowFromLedger |-> FALSE,
        sharedShadowGeneration |-> FALSE,
        carrierShadowGeneration |-> FALSE,
        ringFullAccounted |-> FALSE,
        ringFullConsumedReplay |-> FALSE,
        ringFullMonitorFailure |-> FALSE,
        directInFlight |-> FALSE,
        ringPendingSlot |-> FALSE,
        ringPendingResponse |-> FALSE,
        revokeStarted |-> FALSE,
        oldEpochDirectStopped |-> FALSE,
        oldEpochRingStopped |-> FALSE,
        newReceiptEmbargoed |-> FALSE,
        directInFlightDrained |-> FALSE,
        ringPendingDrained |-> FALSE,
        pendingResponsesDrained |-> FALSE,
        derivedReceiptsRevoked |-> FALSE,
        shadowInvalidated |-> FALSE,
        revokeComplete |-> FALSE,
        newSuccessAfterRevoke |-> FALSE,
        badSeparateReplayNamespace |-> FALSE,
        badDuplicateSuccessFallback |-> FALSE,
        badCarrierLocalLedger |-> FALSE,
        badCarrierShadowGeneration |-> FALSE,
        badRevokeStopsOneCarrier |-> FALSE,
        badRevokeWithDirectInFlight |-> FALSE,
        badRevokeWithRingPending |-> FALSE,
        badRingFullAsMonitorFailure |-> FALSE,
        badResponseWithoutSharedLedger |-> FALSE,
        badEpochSplit |-> FALSE,
        badAttemptFromCarrierId |-> FALSE
    ]

SubmitDirect ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "DirectSubmitted",
            !.carrier = "Direct",
            !.directSubmitted = TRUE,
            !.monitorEntry = TRUE,
            !.canonicalAttemptAssigned = TRUE,
            !.epochsUnified = TRUE,
            !.directInFlight = TRUE
        ]

AccountRingFull ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "RingFullAccounted",
            !.carrier = "Ring",
            !.ringFullAccounted = TRUE
        ]

SubmitFallbackDirect ==
    /\ state.phase = "RingFullAccounted"
    /\ state.ringFullAccounted
    /\ ~state.ringFullConsumedReplay
    /\ ~state.ringFullMonitorFailure
    /\ state' =
        [state EXCEPT
            !.phase = "FallbackDirectSubmitted",
            !.carrier = "FallbackDirect",
            !.fallbackRequested = TRUE,
            !.directSubmitted = TRUE,
            !.monitorEntry = TRUE,
            !.canonicalAttemptAssigned = TRUE,
            !.epochsUnified = TRUE,
            !.directInFlight = TRUE
        ]

FreezeDirectRequest ==
    /\ state.phase \in {"DirectSubmitted", "FallbackDirectSubmitted"}
    /\ state.monitorEntry
    /\ state.canonicalAttemptAssigned
    /\ state' =
        [state EXCEPT
            !.phase = "DirectRequestFrozen",
            !.requestFrozen = TRUE
        ]

ValidateDirectRequest ==
    /\ state.phase = "DirectRequestFrozen"
    /\ state.requestFrozen
    /\ state.epochsUnified
    /\ ~state.carrierEpochSplit
    /\ state' =
        [state EXCEPT
            !.phase = "DirectRequestValidated",
            !.requestValidated = TRUE
        ]

SubmitRing ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "RingSubmitted",
            !.carrier = "Ring",
            !.ringSubmitted = TRUE,
            !.ringPendingSlot = TRUE,
            !.epochsUnified = TRUE
        ]

ClaimRingSlot ==
    /\ state.phase = "RingSubmitted"
    /\ state.ringSubmitted
    /\ state.ringPendingSlot
    /\ state.epochsUnified
    /\ state' =
        [state EXCEPT
            !.phase = "RingSlotClaimed",
            !.monitorSlotClaim = TRUE,
            !.canonicalAttemptAssigned = TRUE
        ]

FreezeRingRequest ==
    /\ state.phase = "RingSlotClaimed"
    /\ state.monitorSlotClaim
    /\ state.canonicalAttemptAssigned
    /\ state' =
        [state EXCEPT
            !.phase = "RingRequestFrozen",
            !.requestFrozen = TRUE
        ]

ValidateRingRequest ==
    /\ state.phase = "RingRequestFrozen"
    /\ state.requestFrozen
    /\ state.epochsUnified
    /\ ~state.carrierEpochSplit
    /\ state' =
        [state EXCEPT
            !.phase = "RingRequestValidated",
            !.requestValidated = TRUE
        ]

ConsumeSharedReplay ==
    /\ state.phase \in {"DirectRequestValidated", "RingRequestValidated"}
    /\ state.requestValidated
    /\ state.canonicalAttemptAssigned
    /\ state' =
        [state EXCEPT
            !.phase = "SharedReplayConsumed",
            !.sharedReplayConsumed = TRUE
        ]

WriteSharedLedger ==
    /\ state.phase = "SharedReplayConsumed"
    /\ state.sharedReplayConsumed
    /\ state.canonicalAttemptAssigned
    /\ state.requestValidated
    /\ state.epochsUnified
    /\ ~state.carrierEpochSplit
    /\ state' =
        [state EXCEPT
            !.phase = "SharedLedgerWritten",
            !.sharedLedgerWritten = TRUE,
            !.directSuccess = IF state.carrier \in {"Direct", "FallbackDirect"} THEN TRUE ELSE state.directSuccess,
            !.ringSuccess = IF state.carrier = "Ring" THEN TRUE ELSE state.ringSuccess,
            !.directInFlight = IF state.carrier \in {"Direct", "FallbackDirect"} THEN FALSE ELSE state.directInFlight,
            !.ringPendingSlot = IF state.carrier = "Ring" THEN FALSE ELSE state.ringPendingSlot,
            !.ringPendingResponse = IF state.carrier = "Ring" THEN TRUE ELSE state.ringPendingResponse
        ]

ReturnDirectResponse ==
    /\ state.phase = "SharedLedgerWritten"
    /\ state.carrier \in {"Direct", "FallbackDirect"}
    /\ state.sharedLedgerWritten
    /\ state.directSuccess
    /\ state' =
        [state EXCEPT
            !.phase = "DirectResponseReturned",
            !.responseReturned = TRUE
        ]

PublishRingResponse ==
    /\ state.phase = "SharedLedgerWritten"
    /\ state.carrier = "Ring"
    /\ state.sharedLedgerWritten
    /\ state.ringSuccess
    /\ state' =
        [state EXCEPT
            !.phase = "RingResponsePublished",
            !.responsePublished = TRUE
        ]

ConsumeRingResponse ==
    /\ state.phase = "RingResponsePublished"
    /\ state.responsePublished
    /\ state.ringPendingResponse
    /\ state' =
        [state EXCEPT
            !.phase = "RingResponseConsumed",
            !.ringPendingResponse = FALSE
        ]

RefreshShadow ==
    /\ state.phase \in {"DirectResponseReturned", "RingResponseConsumed"}
    /\ state.sharedLedgerWritten
    /\ state' =
        [state EXCEPT
            !.phase = "ShadowRefreshed",
            !.shadowRefreshed = TRUE,
            !.shadowFromLedger = TRUE,
            !.sharedShadowGeneration = TRUE
        ]

StartRevoke ==
    /\ state.phase = "ShadowRefreshed"
    /\ state.shadowRefreshed
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeStarted",
            !.revokeStarted = TRUE
        ]

StopOldEpochAdmissions ==
    /\ state.phase = "RevokeStarted"
    /\ state.revokeStarted
    /\ state' =
        [state EXCEPT
            !.phase = "OldEpochAdmissionsStopped",
            !.oldEpochDirectStopped = TRUE,
            !.oldEpochRingStopped = TRUE
        ]

EmbargoNewReceipts ==
    /\ state.phase = "OldEpochAdmissionsStopped"
    /\ state.oldEpochDirectStopped
    /\ state.oldEpochRingStopped
    /\ state' =
        [state EXCEPT
            !.phase = "NewReceiptEmbargoed",
            !.newReceiptEmbargoed = TRUE
        ]

DrainAllCarriers ==
    /\ state.phase = "NewReceiptEmbargoed"
    /\ state.newReceiptEmbargoed
    /\ state' =
        [state EXCEPT
            !.phase = "AllCarriersDrained",
            !.directInFlight = FALSE,
            !.ringPendingSlot = FALSE,
            !.ringPendingResponse = FALSE,
            !.directInFlightDrained = TRUE,
            !.ringPendingDrained = TRUE,
            !.pendingResponsesDrained = TRUE
        ]

RevokeDerivedReceipts ==
    /\ state.phase = "AllCarriersDrained"
    /\ state.directInFlightDrained
    /\ state.ringPendingDrained
    /\ state.pendingResponsesDrained
    /\ state' =
        [state EXCEPT
            !.phase = "DerivedReceiptsRevoked",
            !.derivedReceiptsRevoked = TRUE
        ]

InvalidateSharedShadow ==
    /\ state.phase = "DerivedReceiptsRevoked"
    /\ state.derivedReceiptsRevoked
    /\ state' =
        [state EXCEPT
            !.phase = "SharedShadowInvalidated",
            !.shadowInvalidated = TRUE
        ]

CompleteRevoke ==
    /\ state.phase = "SharedShadowInvalidated"
    /\ state.shadowInvalidated
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeComplete",
            !.revokeComplete = TRUE
        ]

UnsafeSeparateReplayNamespace ==
    /\ ALLOW_UNSAFE_SEPARATE_REPLAY_NAMESPACE
    /\ state.phase \in {"DirectSubmitted", "FallbackDirectSubmitted", "RingSlotClaimed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadSeparateReplayNamespace",
            !.carrierLocalReplayConsumed = TRUE,
            !.sharedLedgerWritten = TRUE,
            !.directSuccess = IF state.carrier = "Ring" THEN state.directSuccess ELSE TRUE,
            !.ringSuccess = IF state.carrier = "Ring" THEN TRUE ELSE state.ringSuccess,
            !.badSeparateReplayNamespace = TRUE
        ]

UnsafeDuplicateSuccessFallback ==
    /\ ALLOW_UNSAFE_DUPLICATE_SUCCESS_FALLBACK
    /\ state.phase \in {"DirectResponseReturned", "RingResponsePublished"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadDuplicateSuccessFallback",
            !.fallbackRequested = TRUE,
            !.directSuccess = TRUE,
            !.ringSuccess = TRUE,
            !.badDuplicateSuccessFallback = TRUE
        ]

UnsafeCarrierLocalLedger ==
    /\ ALLOW_UNSAFE_CARRIER_LOCAL_LEDGER
    /\ state.phase \in {"DirectSubmitted", "RingSlotClaimed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadCarrierLocalLedger",
            !.carrierLocalLedgerWritten = TRUE,
            !.directSuccess = IF state.carrier = "Ring" THEN state.directSuccess ELSE TRUE,
            !.ringSuccess = IF state.carrier = "Ring" THEN TRUE ELSE state.ringSuccess,
            !.badCarrierLocalLedger = TRUE
        ]

UnsafeCarrierShadowGeneration ==
    /\ ALLOW_UNSAFE_CARRIER_SHADOW_GENERATION
    /\ state.phase \in {"DirectResponseReturned", "RingResponseConsumed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadCarrierShadowGeneration",
            !.shadowRefreshed = TRUE,
            !.carrierShadowGeneration = TRUE,
            !.badCarrierShadowGeneration = TRUE
        ]

UnsafeRevokeStopsOneCarrier ==
    /\ ALLOW_UNSAFE_REVOKE_STOPS_ONE_CARRIER
    /\ state.phase = "ShadowRefreshed"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRevokeStopsOneCarrier",
            !.revokeStarted = TRUE,
            !.oldEpochDirectStopped = TRUE,
            !.oldEpochRingStopped = FALSE,
            !.newReceiptEmbargoed = TRUE,
            !.directInFlightDrained = TRUE,
            !.ringPendingDrained = TRUE,
            !.pendingResponsesDrained = TRUE,
            !.derivedReceiptsRevoked = TRUE,
            !.shadowInvalidated = TRUE,
            !.revokeComplete = TRUE,
            !.badRevokeStopsOneCarrier = TRUE
        ]

UnsafeRevokeWithDirectInFlight ==
    /\ ALLOW_UNSAFE_REVOKE_WITH_DIRECT_INFLIGHT
    /\ state.phase = "DirectSubmitted"
    /\ state.directInFlight
    /\ state' =
        [state EXCEPT
            !.phase = "BadRevokeWithDirectInFlight",
            !.revokeStarted = TRUE,
            !.oldEpochDirectStopped = TRUE,
            !.oldEpochRingStopped = TRUE,
            !.newReceiptEmbargoed = TRUE,
            !.ringPendingDrained = TRUE,
            !.pendingResponsesDrained = TRUE,
            !.derivedReceiptsRevoked = TRUE,
            !.shadowInvalidated = TRUE,
            !.revokeComplete = TRUE,
            !.badRevokeWithDirectInFlight = TRUE
        ]

UnsafeRevokeWithRingPending ==
    /\ ALLOW_UNSAFE_REVOKE_WITH_RING_PENDING
    /\ state.phase \in {"RingSlotClaimed", "RingResponsePublished"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadRevokeWithRingPending",
            !.revokeStarted = TRUE,
            !.oldEpochDirectStopped = TRUE,
            !.oldEpochRingStopped = TRUE,
            !.newReceiptEmbargoed = TRUE,
            !.directInFlightDrained = TRUE,
            !.derivedReceiptsRevoked = TRUE,
            !.shadowInvalidated = TRUE,
            !.revokeComplete = TRUE,
            !.badRevokeWithRingPending = TRUE
        ]

UnsafeRingFullAsMonitorFailure ==
    /\ ALLOW_UNSAFE_RING_FULL_AS_MONITOR_FAILURE
    /\ state.phase = "RingFullAccounted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRingFullAsMonitorFailure",
            !.ringFullConsumedReplay = TRUE,
            !.ringFullMonitorFailure = TRUE,
            !.badRingFullAsMonitorFailure = TRUE
        ]

UnsafeResponseWithoutSharedLedger ==
    /\ ALLOW_UNSAFE_RESPONSE_WITHOUT_SHARED_LEDGER
    /\ state.phase \in {"DirectSubmitted", "RingSlotClaimed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadResponseWithoutSharedLedger",
            !.directSuccess = IF state.carrier = "Ring" THEN state.directSuccess ELSE TRUE,
            !.ringSuccess = IF state.carrier = "Ring" THEN TRUE ELSE state.ringSuccess,
            !.responseReturned = IF state.carrier = "Ring" THEN state.responseReturned ELSE TRUE,
            !.responsePublished = IF state.carrier = "Ring" THEN TRUE ELSE state.responsePublished,
            !.badResponseWithoutSharedLedger = TRUE
        ]

UnsafeEpochSplit ==
    /\ ALLOW_UNSAFE_EPOCH_SPLIT
    /\ state.phase \in {"DirectSubmitted", "RingSlotClaimed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadEpochSplit",
            !.carrierEpochSplit = TRUE,
            !.sharedReplayConsumed = TRUE,
            !.sharedLedgerWritten = TRUE,
            !.directSuccess = IF state.carrier = "Ring" THEN state.directSuccess ELSE TRUE,
            !.ringSuccess = IF state.carrier = "Ring" THEN TRUE ELSE state.ringSuccess,
            !.badEpochSplit = TRUE
        ]

UnsafeAttemptFromCarrierId ==
    /\ ALLOW_UNSAFE_ATTEMPT_FROM_CARRIER_ID
    /\ state.phase \in {"DirectSubmitted", "RingSlotClaimed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadAttemptFromCarrierId",
            !.canonicalAttemptAssigned = FALSE,
            !.carrierLocalAttemptUsed = TRUE,
            !.sharedReplayConsumed = TRUE,
            !.sharedLedgerWritten = TRUE,
            !.directSuccess = IF state.carrier = "Ring" THEN state.directSuccess ELSE TRUE,
            !.ringSuccess = IF state.carrier = "Ring" THEN TRUE ELSE state.ringSuccess,
            !.badAttemptFromCarrierId = TRUE
        ]

StutterAtTerminal ==
    /\ state.phase \in TerminalPhases
    /\ UNCHANGED state

Next ==
    \/ SubmitDirect
    \/ AccountRingFull
    \/ SubmitFallbackDirect
    \/ FreezeDirectRequest
    \/ ValidateDirectRequest
    \/ SubmitRing
    \/ ClaimRingSlot
    \/ FreezeRingRequest
    \/ ValidateRingRequest
    \/ ConsumeSharedReplay
    \/ WriteSharedLedger
    \/ ReturnDirectResponse
    \/ PublishRingResponse
    \/ ConsumeRingResponse
    \/ RefreshShadow
    \/ StartRevoke
    \/ StopOldEpochAdmissions
    \/ EmbargoNewReceipts
    \/ DrainAllCarriers
    \/ RevokeDerivedReceipts
    \/ InvalidateSharedShadow
    \/ CompleteRevoke
    \/ UnsafeSeparateReplayNamespace
    \/ UnsafeDuplicateSuccessFallback
    \/ UnsafeCarrierLocalLedger
    \/ UnsafeCarrierShadowGeneration
    \/ UnsafeRevokeStopsOneCarrier
    \/ UnsafeRevokeWithDirectInFlight
    \/ UnsafeRevokeWithRingPending
    \/ UnsafeRingFullAsMonitorFailure
    \/ UnsafeResponseWithoutSharedLedger
    \/ UnsafeEpochSplit
    \/ UnsafeAttemptFromCarrierId
    \/ StutterAtTerminal

LedgerRequiresMonitorAttempt ==
    state.sharedLedgerWritten =>
        (state.canonicalAttemptAssigned /\ ~state.carrierLocalAttemptUsed)

SharedLedgerRequiresSharedReplay ==
    state.sharedLedgerWritten => state.sharedReplayConsumed

CarrierLocalReplayIsNotAuthority ==
    ~state.carrierLocalReplayConsumed

NoCarrierLocalLedgerAuthority ==
    ~state.carrierLocalLedgerWritten

AtMostOneSuccessPerReplayKey ==
    ~(state.directSuccess /\ state.ringSuccess)

SuccessRequiresSharedLedger ==
    (state.directSuccess \/ state.ringSuccess) => state.sharedLedgerWritten

ResponseRequiresSharedLedger ==
    (state.responseReturned \/ state.responsePublished) =>
        state.sharedLedgerWritten

ShadowRefreshRequiresSharedGeneration ==
    state.shadowRefreshed =>
        (state.shadowFromLedger /\ state.sharedShadowGeneration /\
         state.sharedLedgerWritten /\ ~state.carrierShadowGeneration)

CarrierShadowGenerationIsNotAuthority ==
    ~state.carrierShadowGeneration

NoCarrierEpochSplit ==
    ~state.carrierEpochSplit

RingFullAccountingIsNotMonitorFailure ==
    ~(state.ringFullConsumedReplay \/ state.ringFullMonitorFailure)

RevokeCompleteStopsAllCarriers ==
    state.revokeComplete =>
        (state.oldEpochDirectStopped /\ state.oldEpochRingStopped /\
         state.newReceiptEmbargoed)

RevokeCompleteDrainsAllCarriers ==
    state.revokeComplete =>
        (~state.directInFlight /\ ~state.ringPendingSlot /\
         ~state.ringPendingResponse /\ state.directInFlightDrained /\
         state.ringPendingDrained /\ state.pendingResponsesDrained)

RevokeCompleteRequiresDerivedAndShadow ==
    state.revokeComplete =>
        (state.derivedReceiptsRevoked /\ state.shadowInvalidated)

NoNewSuccessAfterRevokeStarted ==
    ~state.newSuccessAfterRevoke

NoBadSeparateReplayNamespace == ~state.badSeparateReplayNamespace

NoBadDuplicateSuccessFallback == ~state.badDuplicateSuccessFallback

NoBadCarrierLocalLedger == ~state.badCarrierLocalLedger

NoBadCarrierShadowGeneration == ~state.badCarrierShadowGeneration

NoBadRevokeStopsOneCarrier == ~state.badRevokeStopsOneCarrier

NoBadRevokeWithDirectInFlight == ~state.badRevokeWithDirectInFlight

NoBadRevokeWithRingPending == ~state.badRevokeWithRingPending

NoBadRingFullAsMonitorFailure == ~state.badRingFullAsMonitorFailure

NoBadResponseWithoutSharedLedger == ~state.badResponseWithoutSharedLedger

NoBadEpochSplit == ~state.badEpochSplit

NoBadAttemptFromCarrierId == ~state.badAttemptFromCarrierId

Spec == Init /\ [][Next]_vars

=============================================================================
