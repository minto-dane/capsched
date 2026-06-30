-------------------- MODULE MonitorAdmissionCarrierSketch --------------------

CONSTANTS
    ALLOW_UNSAFE_LINUX_DIRECT_RESPONSE,
    ALLOW_UNSAFE_DIRECT_NO_REPLAY_CHECK,
    ALLOW_UNSAFE_RING_SLOT_AUTHORITY,
    ALLOW_UNSAFE_RING_RESPONSE_BEFORE_CLAIM,
    ALLOW_UNSAFE_BATCH_EPOCH_CROSSING,
    ALLOW_UNSAFE_SHADOW_FROM_CARRIER,
    ALLOW_UNSAFE_REVOKE_WITH_PENDING_RING,
    ALLOW_UNSAFE_COST_AS_SECURITY

VARIABLE state

vars == <<state>>

CarrierTypes == {"None", "Direct", "Ring"}

Phases == {
    "Start",
    "DirectSubmitted",
    "DirectReplayChecked",
    "DirectResponseMinted",
    "RingSubmitted",
    "RingSlotClaimed",
    "RingReplayChecked",
    "RingResponseMinted",
    "ShadowRefreshed",
    "RevokeStarted",
    "PendingResponsesDrained",
    "RevokeComplete",
    "BadLinuxDirectResponse",
    "BadDirectNoReplayCheck",
    "BadRingSlotAuthority",
    "BadRingResponseBeforeClaim",
    "BadBatchEpochCrossing",
    "BadShadowFromCarrier",
    "BadRevokeWithPendingRing",
    "BadCostAsSecurity"
}

StateFields == {
    "phase",
    "carrier",
    "requestCarried",
    "monitorEntryOrClaim",
    "replayChecked",
    "monitorLedgerWritten",
    "monitorResponseMinted",
    "linuxDirectResponse",
    "ringSlotAuthority",
    "ringSlotClaimedByMonitor",
    "ringResponseBeforeClaim",
    "batchEpochStable",
    "batchEpochCrossed",
    "shadowRefreshed",
    "shadowFromLedger",
    "shadowFromCarrier",
    "revokeStarted",
    "pendingRingResponses",
    "pendingResponsesDrained",
    "revokeComplete",
    "costMetricAuthority",
    "badLinuxDirectResponse",
    "badDirectNoReplayCheck",
    "badRingSlotAuthority",
    "badRingResponseBeforeClaim",
    "badBatchEpochCrossing",
    "badShadowFromCarrier",
    "badRevokeWithPendingRing",
    "badCostAsSecurity"
}

BoolFields == StateFields \ {"phase", "carrier"}

TerminalPhases == {
    "RevokeComplete",
    "BadLinuxDirectResponse",
    "BadDirectNoReplayCheck",
    "BadRingSlotAuthority",
    "BadRingResponseBeforeClaim",
    "BadBatchEpochCrossing",
    "BadShadowFromCarrier",
    "BadRevokeWithPendingRing",
    "BadCostAsSecurity"
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
        requestCarried |-> FALSE,
        monitorEntryOrClaim |-> FALSE,
        replayChecked |-> FALSE,
        monitorLedgerWritten |-> FALSE,
        monitorResponseMinted |-> FALSE,
        linuxDirectResponse |-> FALSE,
        ringSlotAuthority |-> FALSE,
        ringSlotClaimedByMonitor |-> FALSE,
        ringResponseBeforeClaim |-> FALSE,
        batchEpochStable |-> FALSE,
        batchEpochCrossed |-> FALSE,
        shadowRefreshed |-> FALSE,
        shadowFromLedger |-> FALSE,
        shadowFromCarrier |-> FALSE,
        revokeStarted |-> FALSE,
        pendingRingResponses |-> FALSE,
        pendingResponsesDrained |-> FALSE,
        revokeComplete |-> FALSE,
        costMetricAuthority |-> FALSE,
        badLinuxDirectResponse |-> FALSE,
        badDirectNoReplayCheck |-> FALSE,
        badRingSlotAuthority |-> FALSE,
        badRingResponseBeforeClaim |-> FALSE,
        badBatchEpochCrossing |-> FALSE,
        badShadowFromCarrier |-> FALSE,
        badRevokeWithPendingRing |-> FALSE,
        badCostAsSecurity |-> FALSE
    ]

SubmitDirect ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "DirectSubmitted",
            !.carrier = "Direct",
            !.requestCarried = TRUE,
            !.monitorEntryOrClaim = TRUE,
            !.batchEpochStable = TRUE
        ]

DirectReplayCheck ==
    /\ state.phase = "DirectSubmitted"
    /\ state.carrier = "Direct"
    /\ state.monitorEntryOrClaim
    /\ state' =
        [state EXCEPT
            !.phase = "DirectReplayChecked",
            !.replayChecked = TRUE
        ]

MintDirectResponse ==
    /\ state.phase = "DirectReplayChecked"
    /\ state.replayChecked
    /\ state.monitorEntryOrClaim
    /\ state' =
        [state EXCEPT
            !.phase = "DirectResponseMinted",
            !.monitorLedgerWritten = TRUE,
            !.monitorResponseMinted = TRUE
        ]

SubmitRing ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "RingSubmitted",
            !.carrier = "Ring",
            !.requestCarried = TRUE,
            !.pendingRingResponses = TRUE,
            !.batchEpochStable = TRUE
        ]

MonitorClaimsRingSlot ==
    /\ state.phase = "RingSubmitted"
    /\ state.carrier = "Ring"
    /\ state.batchEpochStable
    /\ state' =
        [state EXCEPT
            !.phase = "RingSlotClaimed",
            !.ringSlotClaimedByMonitor = TRUE,
            !.monitorEntryOrClaim = TRUE
        ]

RingReplayCheck ==
    /\ state.phase = "RingSlotClaimed"
    /\ state.ringSlotClaimedByMonitor
    /\ state' =
        [state EXCEPT
            !.phase = "RingReplayChecked",
            !.replayChecked = TRUE
        ]

MintRingResponse ==
    /\ state.phase = "RingReplayChecked"
    /\ state.replayChecked
    /\ state.ringSlotClaimedByMonitor
    /\ state.batchEpochStable
    /\ state' =
        [state EXCEPT
            !.phase = "RingResponseMinted",
            !.monitorLedgerWritten = TRUE,
            !.monitorResponseMinted = TRUE
        ]

RefreshShadowFromLedger ==
    /\ state.phase \in {"DirectResponseMinted", "RingResponseMinted"}
    /\ state.monitorLedgerWritten
    /\ state.monitorResponseMinted
    /\ state' =
        [state EXCEPT
            !.phase = "ShadowRefreshed",
            !.shadowRefreshed = TRUE,
            !.shadowFromLedger = TRUE
        ]

StartRevoke ==
    /\ state.phase = "ShadowRefreshed"
    /\ state.shadowFromLedger
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeStarted",
            !.revokeStarted = TRUE
        ]

DrainPendingResponses ==
    /\ state.phase = "RevokeStarted"
    /\ state.revokeStarted
    /\ state' =
        [state EXCEPT
            !.phase = "PendingResponsesDrained",
            !.pendingRingResponses = FALSE,
            !.pendingResponsesDrained = TRUE
        ]

CompleteRevoke ==
    /\ state.phase = "PendingResponsesDrained"
    /\ state.pendingResponsesDrained
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeComplete",
            !.revokeComplete = TRUE
        ]

UnsafeLinuxDirectResponse ==
    /\ ALLOW_UNSAFE_LINUX_DIRECT_RESPONSE
    /\ state.phase = "DirectSubmitted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxDirectResponse",
            !.linuxDirectResponse = TRUE,
            !.monitorResponseMinted = TRUE,
            !.badLinuxDirectResponse = TRUE
        ]

UnsafeDirectNoReplayCheck ==
    /\ ALLOW_UNSAFE_DIRECT_NO_REPLAY_CHECK
    /\ state.phase = "DirectSubmitted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadDirectNoReplayCheck",
            !.monitorLedgerWritten = TRUE,
            !.monitorResponseMinted = TRUE,
            !.badDirectNoReplayCheck = TRUE
        ]

UnsafeRingSlotAuthority ==
    /\ ALLOW_UNSAFE_RING_SLOT_AUTHORITY
    /\ state.phase = "RingSubmitted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRingSlotAuthority",
            !.ringSlotAuthority = TRUE,
            !.monitorResponseMinted = TRUE,
            !.badRingSlotAuthority = TRUE
        ]

UnsafeRingResponseBeforeClaim ==
    /\ ALLOW_UNSAFE_RING_RESPONSE_BEFORE_CLAIM
    /\ state.phase = "RingSubmitted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRingResponseBeforeClaim",
            !.ringResponseBeforeClaim = TRUE,
            !.monitorResponseMinted = TRUE,
            !.badRingResponseBeforeClaim = TRUE
        ]

UnsafeBatchEpochCrossing ==
    /\ ALLOW_UNSAFE_BATCH_EPOCH_CROSSING
    /\ state.phase \in {"RingSubmitted", "RingSlotClaimed", "RingReplayChecked"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadBatchEpochCrossing",
            !.batchEpochStable = FALSE,
            !.batchEpochCrossed = TRUE,
            !.monitorLedgerWritten = TRUE,
            !.badBatchEpochCrossing = TRUE
        ]

UnsafeShadowFromCarrier ==
    /\ ALLOW_UNSAFE_SHADOW_FROM_CARRIER
    /\ state.phase \in {"DirectSubmitted", "RingSubmitted", "RingSlotClaimed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadShadowFromCarrier",
            !.shadowRefreshed = TRUE,
            !.shadowFromCarrier = TRUE,
            !.badShadowFromCarrier = TRUE
        ]

UnsafeRevokeWithPendingRing ==
    /\ ALLOW_UNSAFE_REVOKE_WITH_PENDING_RING
    /\ state.phase = "RevokeStarted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRevokeWithPendingRing",
            !.pendingRingResponses = TRUE,
            !.revokeComplete = TRUE,
            !.badRevokeWithPendingRing = TRUE
        ]

UnsafeCostAsSecurity ==
    /\ ALLOW_UNSAFE_COST_AS_SECURITY
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "BadCostAsSecurity",
            !.costMetricAuthority = TRUE,
            !.badCostAsSecurity = TRUE
        ]

StutterAtTerminal ==
    /\ state.phase \in TerminalPhases
    /\ UNCHANGED state

Next ==
    \/ SubmitDirect
    \/ DirectReplayCheck
    \/ MintDirectResponse
    \/ SubmitRing
    \/ MonitorClaimsRingSlot
    \/ RingReplayCheck
    \/ MintRingResponse
    \/ RefreshShadowFromLedger
    \/ StartRevoke
    \/ DrainPendingResponses
    \/ CompleteRevoke
    \/ UnsafeLinuxDirectResponse
    \/ UnsafeDirectNoReplayCheck
    \/ UnsafeRingSlotAuthority
    \/ UnsafeRingResponseBeforeClaim
    \/ UnsafeBatchEpochCrossing
    \/ UnsafeShadowFromCarrier
    \/ UnsafeRevokeWithPendingRing
    \/ UnsafeCostAsSecurity
    \/ StutterAtTerminal

NoLinuxDirectResponseAuthority ==
    ~state.linuxDirectResponse

ResponseRequiresMonitorEntryOrClaim ==
    state.monitorResponseMinted => state.monitorEntryOrClaim

ResponseRequiresReplayCheck ==
    state.monitorResponseMinted => state.replayChecked

RingSlotIsNotAuthority ==
    ~state.ringSlotAuthority

RingResponseRequiresMonitorClaim ==
    (state.carrier = "Ring" /\ state.monitorResponseMinted) =>
        state.ringSlotClaimedByMonitor

LedgerWriteRequiresBatchEpochStability ==
    state.monitorLedgerWritten => state.batchEpochStable

NoBatchEpochCrossing ==
    ~state.batchEpochCrossed

ShadowRefreshRequiresLedger ==
    state.shadowRefreshed => (state.shadowFromLedger /\ state.monitorLedgerWritten)

NoShadowFromCarrier ==
    ~state.shadowFromCarrier

RevokeCompleteRequiresPendingDrain ==
    state.revokeComplete => state.pendingResponsesDrained

NoPendingRingAtRevokeComplete ==
    state.revokeComplete => ~state.pendingRingResponses

CostMetricIsNotSecurityAuthority ==
    ~state.costMetricAuthority

NoBadLinuxDirectResponse == ~state.badLinuxDirectResponse
NoBadDirectNoReplayCheck == ~state.badDirectNoReplayCheck
NoBadRingSlotAuthority == ~state.badRingSlotAuthority
NoBadRingResponseBeforeClaim == ~state.badRingResponseBeforeClaim
NoBadBatchEpochCrossing == ~state.badBatchEpochCrossing
NoBadShadowFromCarrier == ~state.badShadowFromCarrier
NoBadRevokeWithPendingRing == ~state.badRevokeWithPendingRing
NoBadCostAsSecurity == ~state.badCostAsSecurity

=============================================================================
