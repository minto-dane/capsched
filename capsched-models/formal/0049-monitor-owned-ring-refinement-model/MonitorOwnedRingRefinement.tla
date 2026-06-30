-------------------- MODULE MonitorOwnedRingRefinement --------------------

CONSTANTS
    ALLOW_UNSAFE_LINUX_SLOT_AUTHORITY,
    ALLOW_UNSAFE_RESPONSE_BEFORE_CLAIM,
    ALLOW_UNSAFE_MUTATION_AFTER_CLAIM,
    ALLOW_UNSAFE_SLOT_REUSE_WITHOUT_GENERATION,
    ALLOW_UNSAFE_BATCH_EPOCH_CROSSING,
    ALLOW_UNSAFE_LEDGER_BEFORE_REPLAY,
    ALLOW_UNSAFE_LINUX_RESPONSE_PUBLISH,
    ALLOW_UNSAFE_SHADOW_FROM_RING,
    ALLOW_UNSAFE_REVOKE_WITH_PENDING_SLOT,
    ALLOW_UNSAFE_REVOKE_WITH_PENDING_RESPONSE,
    ALLOW_UNSAFE_RING_FULL_AS_AUTHORITY

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "LinuxSlotWritten",
    "MonitorSlotClaimed",
    "RequestFrozen",
    "RequestValidated",
    "ReplayConsumed",
    "LedgerWritten",
    "ResponsePublished",
    "ResponseConsumed",
    "ShadowRefreshed",
    "RingFullAccounted",
    "RevokeStarted",
    "OldEpochAdmissionStopped",
    "NewReceiptEmbargoed",
    "PendingSlotsDrained",
    "PendingResponsesDrained",
    "DerivedReceiptsRevoked",
    "ShadowInvalidated",
    "RevokeComplete",
    "BadLinuxSlotAuthority",
    "BadResponseBeforeClaim",
    "BadMutationAfterClaim",
    "BadSlotReuseWithoutGeneration",
    "BadBatchEpochCrossing",
    "BadLedgerBeforeReplay",
    "BadLinuxResponsePublish",
    "BadShadowFromRing",
    "BadRevokeWithPendingSlot",
    "BadRevokeWithPendingResponse",
    "BadRingFullAsAuthority"
}

StateFields == {
    "phase",
    "linuxSlotWritten",
    "linuxSlotAuthority",
    "monitorSlotClaimed",
    "slotEpochOwnedByMonitor",
    "slotGenerationAdvanced",
    "requestFrozen",
    "postClaimMutationAffectsDecision",
    "requestValidated",
    "batchEpochStable",
    "batchEpochCrossed",
    "replayConsumed",
    "ledgerWritten",
    "linuxResponsePublished",
    "monitorResponsePublished",
    "responseEpochOwnedByMonitor",
    "pendingClaimedSlot",
    "pendingResponse",
    "responseConsumed",
    "shadowRefreshed",
    "shadowFromMonitor",
    "shadowFromRing",
    "ringFullAccounted",
    "ringFullAuthority",
    "revokeStarted",
    "oldEpochAdmissionStopped",
    "newReceiptEmbargoed",
    "pendingSlotsDrained",
    "pendingResponsesDrained",
    "derivedReceiptsRevoked",
    "shadowInvalidated",
    "revokeComplete",
    "badLinuxSlotAuthority",
    "badResponseBeforeClaim",
    "badMutationAfterClaim",
    "badSlotReuseWithoutGeneration",
    "badBatchEpochCrossing",
    "badLedgerBeforeReplay",
    "badLinuxResponsePublish",
    "badShadowFromRing",
    "badRevokeWithPendingSlot",
    "badRevokeWithPendingResponse",
    "badRingFullAsAuthority"
}

BoolFields == StateFields \ {"phase"}

TerminalPhases == {
    "RingFullAccounted",
    "RevokeComplete",
    "BadLinuxSlotAuthority",
    "BadResponseBeforeClaim",
    "BadMutationAfterClaim",
    "BadSlotReuseWithoutGeneration",
    "BadBatchEpochCrossing",
    "BadLedgerBeforeReplay",
    "BadLinuxResponsePublish",
    "BadShadowFromRing",
    "BadRevokeWithPendingSlot",
    "BadRevokeWithPendingResponse",
    "BadRingFullAsAuthority"
}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        linuxSlotWritten |-> FALSE,
        linuxSlotAuthority |-> FALSE,
        monitorSlotClaimed |-> FALSE,
        slotEpochOwnedByMonitor |-> FALSE,
        slotGenerationAdvanced |-> FALSE,
        requestFrozen |-> FALSE,
        postClaimMutationAffectsDecision |-> FALSE,
        requestValidated |-> FALSE,
        batchEpochStable |-> FALSE,
        batchEpochCrossed |-> FALSE,
        replayConsumed |-> FALSE,
        ledgerWritten |-> FALSE,
        linuxResponsePublished |-> FALSE,
        monitorResponsePublished |-> FALSE,
        responseEpochOwnedByMonitor |-> FALSE,
        pendingClaimedSlot |-> FALSE,
        pendingResponse |-> FALSE,
        responseConsumed |-> FALSE,
        shadowRefreshed |-> FALSE,
        shadowFromMonitor |-> FALSE,
        shadowFromRing |-> FALSE,
        ringFullAccounted |-> FALSE,
        ringFullAuthority |-> FALSE,
        revokeStarted |-> FALSE,
        oldEpochAdmissionStopped |-> FALSE,
        newReceiptEmbargoed |-> FALSE,
        pendingSlotsDrained |-> FALSE,
        pendingResponsesDrained |-> FALSE,
        derivedReceiptsRevoked |-> FALSE,
        shadowInvalidated |-> FALSE,
        revokeComplete |-> FALSE,
        badLinuxSlotAuthority |-> FALSE,
        badResponseBeforeClaim |-> FALSE,
        badMutationAfterClaim |-> FALSE,
        badSlotReuseWithoutGeneration |-> FALSE,
        badBatchEpochCrossing |-> FALSE,
        badLedgerBeforeReplay |-> FALSE,
        badLinuxResponsePublish |-> FALSE,
        badShadowFromRing |-> FALSE,
        badRevokeWithPendingSlot |-> FALSE,
        badRevokeWithPendingResponse |-> FALSE,
        badRingFullAsAuthority |-> FALSE
    ]

LinuxWritesSlot ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "LinuxSlotWritten",
            !.linuxSlotWritten = TRUE
        ]

MonitorClaimsSlot ==
    /\ state.phase = "LinuxSlotWritten"
    /\ state.linuxSlotWritten
    /\ state' =
        [state EXCEPT
            !.phase = "MonitorSlotClaimed",
            !.monitorSlotClaimed = TRUE,
            !.slotEpochOwnedByMonitor = TRUE,
            !.slotGenerationAdvanced = TRUE,
            !.pendingClaimedSlot = TRUE,
            !.batchEpochStable = TRUE
        ]

FreezeClaimedRequest ==
    /\ state.phase = "MonitorSlotClaimed"
    /\ state.monitorSlotClaimed
    /\ state.slotGenerationAdvanced
    /\ state' =
        [state EXCEPT
            !.phase = "RequestFrozen",
            !.requestFrozen = TRUE
        ]

ValidateFrozenRequest ==
    /\ state.phase = "RequestFrozen"
    /\ state.requestFrozen
    /\ state.batchEpochStable
    /\ ~state.postClaimMutationAffectsDecision
    /\ state' =
        [state EXCEPT
            !.phase = "RequestValidated",
            !.requestValidated = TRUE
        ]

ConsumeReplay ==
    /\ state.phase = "RequestValidated"
    /\ state.requestValidated
    /\ state' =
        [state EXCEPT
            !.phase = "ReplayConsumed",
            !.replayConsumed = TRUE
        ]

WriteLedger ==
    /\ state.phase = "ReplayConsumed"
    /\ state.replayConsumed
    /\ state.requestValidated
    /\ state.monitorSlotClaimed
    /\ state.batchEpochStable
    /\ state' =
        [state EXCEPT
            !.phase = "LedgerWritten",
            !.ledgerWritten = TRUE
        ]

PublishMonitorResponse ==
    /\ state.phase = "LedgerWritten"
    /\ state.ledgerWritten
    /\ state.monitorSlotClaimed
    /\ state' =
        [state EXCEPT
            !.phase = "ResponsePublished",
            !.monitorResponsePublished = TRUE,
            !.responseEpochOwnedByMonitor = TRUE,
            !.pendingResponse = TRUE,
            !.pendingClaimedSlot = FALSE
        ]

ConsumeResponse ==
    /\ state.phase = "ResponsePublished"
    /\ state.monitorResponsePublished
    /\ state.responseEpochOwnedByMonitor
    /\ state' =
        [state EXCEPT
            !.phase = "ResponseConsumed",
            !.responseConsumed = TRUE,
            !.pendingResponse = FALSE
        ]

RefreshShadowFromMonitor ==
    /\ state.phase = "ResponseConsumed"
    /\ state.responseConsumed
    /\ state.monitorResponsePublished
    /\ state.ledgerWritten
    /\ state' =
        [state EXCEPT
            !.phase = "ShadowRefreshed",
            !.shadowRefreshed = TRUE,
            !.shadowFromMonitor = TRUE
        ]

RingFullAccounting ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "RingFullAccounted",
            !.ringFullAccounted = TRUE
        ]

StartRevoke ==
    /\ state.phase = "ShadowRefreshed"
    /\ state.shadowFromMonitor
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeStarted",
            !.revokeStarted = TRUE
        ]

StopOldEpochAdmission ==
    /\ state.phase = "RevokeStarted"
    /\ state.revokeStarted
    /\ state' =
        [state EXCEPT
            !.phase = "OldEpochAdmissionStopped",
            !.oldEpochAdmissionStopped = TRUE
        ]

EmbargoNewReceipts ==
    /\ state.phase = "OldEpochAdmissionStopped"
    /\ state.oldEpochAdmissionStopped
    /\ state' =
        [state EXCEPT
            !.phase = "NewReceiptEmbargoed",
            !.newReceiptEmbargoed = TRUE
        ]

DrainPendingSlots ==
    /\ state.phase = "NewReceiptEmbargoed"
    /\ state.newReceiptEmbargoed
    /\ state' =
        [state EXCEPT
            !.phase = "PendingSlotsDrained",
            !.pendingClaimedSlot = FALSE,
            !.pendingSlotsDrained = TRUE
        ]

DrainPendingResponses ==
    /\ state.phase = "PendingSlotsDrained"
    /\ state.pendingSlotsDrained
    /\ state' =
        [state EXCEPT
            !.phase = "PendingResponsesDrained",
            !.pendingResponse = FALSE,
            !.pendingResponsesDrained = TRUE
        ]

RevokeDerivedReceipts ==
    /\ state.phase = "PendingResponsesDrained"
    /\ state.pendingResponsesDrained
    /\ state' =
        [state EXCEPT
            !.phase = "DerivedReceiptsRevoked",
            !.derivedReceiptsRevoked = TRUE
        ]

InvalidateShadow ==
    /\ state.phase = "DerivedReceiptsRevoked"
    /\ state.derivedReceiptsRevoked
    /\ state' =
        [state EXCEPT
            !.phase = "ShadowInvalidated",
            !.shadowRefreshed = FALSE,
            !.shadowInvalidated = TRUE
        ]

CompleteRevoke ==
    /\ state.phase = "ShadowInvalidated"
    /\ state.oldEpochAdmissionStopped
    /\ state.newReceiptEmbargoed
    /\ state.pendingSlotsDrained
    /\ state.pendingResponsesDrained
    /\ state.derivedReceiptsRevoked
    /\ state.shadowInvalidated
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeComplete",
            !.revokeComplete = TRUE
        ]

UnsafeLinuxSlotAuthority ==
    /\ ALLOW_UNSAFE_LINUX_SLOT_AUTHORITY
    /\ state.phase = "LinuxSlotWritten"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxSlotAuthority",
            !.linuxSlotAuthority = TRUE,
            !.ledgerWritten = TRUE,
            !.badLinuxSlotAuthority = TRUE
        ]

UnsafeResponseBeforeClaim ==
    /\ ALLOW_UNSAFE_RESPONSE_BEFORE_CLAIM
    /\ state.phase = "LinuxSlotWritten"
    /\ state' =
        [state EXCEPT
            !.phase = "BadResponseBeforeClaim",
            !.monitorResponsePublished = TRUE,
            !.badResponseBeforeClaim = TRUE
        ]

UnsafeMutationAfterClaim ==
    /\ ALLOW_UNSAFE_MUTATION_AFTER_CLAIM
    /\ state.phase \in {"MonitorSlotClaimed", "RequestFrozen"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadMutationAfterClaim",
            !.postClaimMutationAffectsDecision = TRUE,
            !.requestValidated = TRUE,
            !.badMutationAfterClaim = TRUE
        ]

UnsafeSlotReuseWithoutGeneration ==
    /\ ALLOW_UNSAFE_SLOT_REUSE_WITHOUT_GENERATION
    /\ state.phase = "MonitorSlotClaimed"
    /\ state' =
        [state EXCEPT
            !.phase = "BadSlotReuseWithoutGeneration",
            !.slotGenerationAdvanced = FALSE,
            !.requestFrozen = TRUE,
            !.badSlotReuseWithoutGeneration = TRUE
        ]

UnsafeBatchEpochCrossing ==
    /\ ALLOW_UNSAFE_BATCH_EPOCH_CROSSING
    /\ state.phase \in {"MonitorSlotClaimed", "RequestFrozen",
        "RequestValidated", "ReplayConsumed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadBatchEpochCrossing",
            !.batchEpochStable = FALSE,
            !.batchEpochCrossed = TRUE,
            !.ledgerWritten = TRUE,
            !.badBatchEpochCrossing = TRUE
        ]

UnsafeLedgerBeforeReplay ==
    /\ ALLOW_UNSAFE_LEDGER_BEFORE_REPLAY
    /\ state.phase = "RequestValidated"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLedgerBeforeReplay",
            !.ledgerWritten = TRUE,
            !.badLedgerBeforeReplay = TRUE
        ]

UnsafeLinuxResponsePublish ==
    /\ ALLOW_UNSAFE_LINUX_RESPONSE_PUBLISH
    /\ state.phase \in {"LinuxSlotWritten", "MonitorSlotClaimed",
        "RequestFrozen"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxResponsePublish",
            !.linuxResponsePublished = TRUE,
            !.monitorResponsePublished = TRUE,
            !.badLinuxResponsePublish = TRUE
        ]

UnsafeShadowFromRing ==
    /\ ALLOW_UNSAFE_SHADOW_FROM_RING
    /\ state.phase \in {"LinuxSlotWritten", "MonitorSlotClaimed",
        "ResponsePublished"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadShadowFromRing",
            !.shadowRefreshed = TRUE,
            !.shadowFromRing = TRUE,
            !.badShadowFromRing = TRUE
        ]

UnsafeRevokeWithPendingSlot ==
    /\ ALLOW_UNSAFE_REVOKE_WITH_PENDING_SLOT
    /\ state.phase \in {"RevokeStarted", "OldEpochAdmissionStopped",
        "NewReceiptEmbargoed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadRevokeWithPendingSlot",
            !.pendingClaimedSlot = TRUE,
            !.revokeComplete = TRUE,
            !.badRevokeWithPendingSlot = TRUE
        ]

UnsafeRevokeWithPendingResponse ==
    /\ ALLOW_UNSAFE_REVOKE_WITH_PENDING_RESPONSE
    /\ state.phase \in {"RevokeStarted", "OldEpochAdmissionStopped",
        "NewReceiptEmbargoed", "PendingSlotsDrained"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadRevokeWithPendingResponse",
            !.pendingResponse = TRUE,
            !.revokeComplete = TRUE,
            !.badRevokeWithPendingResponse = TRUE
        ]

UnsafeRingFullAsAuthority ==
    /\ ALLOW_UNSAFE_RING_FULL_AS_AUTHORITY
    /\ state.phase = "RingFullAccounted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRingFullAsAuthority",
            !.ringFullAuthority = TRUE,
            !.ledgerWritten = TRUE,
            !.monitorResponsePublished = TRUE,
            !.badRingFullAsAuthority = TRUE
        ]

StutterAtTerminal ==
    /\ state.phase \in TerminalPhases
    /\ UNCHANGED state

Next ==
    \/ LinuxWritesSlot
    \/ MonitorClaimsSlot
    \/ FreezeClaimedRequest
    \/ ValidateFrozenRequest
    \/ ConsumeReplay
    \/ WriteLedger
    \/ PublishMonitorResponse
    \/ ConsumeResponse
    \/ RefreshShadowFromMonitor
    \/ RingFullAccounting
    \/ StartRevoke
    \/ StopOldEpochAdmission
    \/ EmbargoNewReceipts
    \/ DrainPendingSlots
    \/ DrainPendingResponses
    \/ RevokeDerivedReceipts
    \/ InvalidateShadow
    \/ CompleteRevoke
    \/ UnsafeLinuxSlotAuthority
    \/ UnsafeResponseBeforeClaim
    \/ UnsafeMutationAfterClaim
    \/ UnsafeSlotReuseWithoutGeneration
    \/ UnsafeBatchEpochCrossing
    \/ UnsafeLedgerBeforeReplay
    \/ UnsafeLinuxResponsePublish
    \/ UnsafeShadowFromRing
    \/ UnsafeRevokeWithPendingSlot
    \/ UnsafeRevokeWithPendingResponse
    \/ UnsafeRingFullAsAuthority
    \/ StutterAtTerminal

RingSlotIsNotAuthority ==
    ~state.linuxSlotAuthority

ResponseRequiresMonitorClaim ==
    state.monitorResponsePublished => state.monitorSlotClaimed

ValidationUsesFrozenClaimedRequest ==
    state.requestValidated => (state.monitorSlotClaimed /\ state.requestFrozen /\
        ~state.postClaimMutationAffectsDecision)

SlotReuseRequiresMonitorGeneration ==
    state.requestFrozen => state.slotGenerationAdvanced

LedgerWriteRequiresStableBatchEpoch ==
    state.ledgerWritten => state.batchEpochStable

NoBatchEpochCrossing ==
    ~state.batchEpochCrossed

LedgerWriteRequiresReplayConsume ==
    state.ledgerWritten => state.replayConsumed

NoLinuxResponsePublication ==
    ~state.linuxResponsePublished

ResponsePublicationRequiresMonitorEpoch ==
    state.monitorResponsePublished => state.responseEpochOwnedByMonitor

ShadowRefreshRequiresMonitorSource ==
    state.shadowRefreshed => (state.shadowFromMonitor /\ state.ledgerWritten /\
        state.monitorResponsePublished)

NoShadowFromRing ==
    ~state.shadowFromRing

RevokeCompleteRequiresPendingSlotDrain ==
    state.revokeComplete => (state.pendingSlotsDrained /\ ~state.pendingClaimedSlot)

RevokeCompleteRequiresPendingResponseDrain ==
    state.revokeComplete => (state.pendingResponsesDrained /\ ~state.pendingResponse)

RevokeCompleteRequiresDerivedAndShadow ==
    state.revokeComplete => (state.derivedReceiptsRevoked /\ state.shadowInvalidated)

RingFullAccountingIsNotAuthority ==
    state.ringFullAccounted => ~(state.ledgerWritten \/ state.monitorResponsePublished \/
        state.shadowRefreshed \/ state.ringFullAuthority)

NoBadLinuxSlotAuthority == ~state.badLinuxSlotAuthority
NoBadResponseBeforeClaim == ~state.badResponseBeforeClaim
NoBadMutationAfterClaim == ~state.badMutationAfterClaim
NoBadSlotReuseWithoutGeneration == ~state.badSlotReuseWithoutGeneration
NoBadBatchEpochCrossing == ~state.badBatchEpochCrossing
NoBadLedgerBeforeReplay == ~state.badLedgerBeforeReplay
NoBadLinuxResponsePublish == ~state.badLinuxResponsePublish
NoBadShadowFromRing == ~state.badShadowFromRing
NoBadRevokeWithPendingSlot == ~state.badRevokeWithPendingSlot
NoBadRevokeWithPendingResponse == ~state.badRevokeWithPendingResponse
NoBadRingFullAsAuthority == ~state.badRingFullAsAuthority

=============================================================================
