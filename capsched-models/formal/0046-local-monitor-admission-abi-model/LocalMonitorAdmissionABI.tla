-------------------- MODULE LocalMonitorAdmissionABI --------------------

CONSTANTS
    ALLOW_UNSAFE_UNKNOWN_CLASS_ACCEPTED,
    ALLOW_UNSAFE_RESPONSE_WITHOUT_REQUEST,
    ALLOW_UNSAFE_REPLAY_ACCEPTED,
    ALLOW_UNSAFE_FAILURE_THEN_RECEIPT,
    ALLOW_UNSAFE_LINUX_LEDGER_WRITE,
    ALLOW_UNSAFE_ENDPOINT_BEFORE_RECEIPT,
    ALLOW_UNSAFE_SHADOW_AUTHORITY,
    ALLOW_UNSAFE_SHADOW_NOT_INVALIDATED,
    ALLOW_UNSAFE_NEW_RECEIPT_DURING_REVOKE,
    ALLOW_UNSAFE_REVOKE_COMPLETE_BEFORE_DERIVED

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "RequestBuilt",
    "RequestAccepted",
    "FailureResponse",
    "ReplayRejected",
    "ReceiptSetMinted",
    "DerivedReceiptsMinted",
    "ShadowMaterialized",
    "EndpointDelivered",
    "RevokeRequested",
    "RevokeStarted",
    "NewReceiptEmbargoed",
    "DerivedReceiptsRevoked",
    "ShadowInvalidated",
    "RevokeComplete",
    "BadUnknownClassAccepted",
    "BadResponseWithoutRequest",
    "BadReplayAccepted",
    "BadFailureThenReceipt",
    "BadLinuxLedgerWrite",
    "BadEndpointBeforeReceipt",
    "BadShadowAuthority",
    "BadShadowNotInvalidated",
    "BadNewReceiptDuringRevoke",
    "BadRevokeCompleteBeforeDerived"
}

StateFields == {
    "phase",
    "requestBuilt",
    "knownRequestClass",
    "requestNonceFresh",
    "replayWindowOpen",
    "requestAccepted",
    "monitorResponseMinted",
    "failureResponseMinted",
    "replayRejected",
    "receiptSetMinted",
    "derivedReceiptsMinted",
    "receiptLedgerOwnedByMonitor",
    "linuxLedgerWrite",
    "monitorReceiptVerified",
    "endpointDelivered",
    "shadowMaterialized",
    "shadowDerivedFromLedger",
    "shadowAuthoritative",
    "shadowInvalidated",
    "revokeRequested",
    "revokeStarted",
    "newReceiptEmbargoed",
    "newReceiptDuringRevoke",
    "derivedReceiptsRevoked",
    "revokeComplete",
    "badUnknownClassAccepted",
    "badResponseWithoutRequest",
    "badReplayAccepted",
    "badFailureThenReceipt",
    "badLinuxLedgerWrite",
    "badEndpointBeforeReceipt",
    "badShadowAuthority",
    "badShadowNotInvalidated",
    "badNewReceiptDuringRevoke",
    "badRevokeCompleteBeforeDerived"
}

BoolFields == StateFields \ {"phase"}

TerminalPhases == {
    "FailureResponse",
    "ReplayRejected",
    "RevokeComplete",
    "BadUnknownClassAccepted",
    "BadResponseWithoutRequest",
    "BadReplayAccepted",
    "BadFailureThenReceipt",
    "BadLinuxLedgerWrite",
    "BadEndpointBeforeReceipt",
    "BadShadowAuthority",
    "BadShadowNotInvalidated",
    "BadNewReceiptDuringRevoke",
    "BadRevokeCompleteBeforeDerived"
}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        requestBuilt |-> FALSE,
        knownRequestClass |-> FALSE,
        requestNonceFresh |-> FALSE,
        replayWindowOpen |-> FALSE,
        requestAccepted |-> FALSE,
        monitorResponseMinted |-> FALSE,
        failureResponseMinted |-> FALSE,
        replayRejected |-> FALSE,
        receiptSetMinted |-> FALSE,
        derivedReceiptsMinted |-> FALSE,
        receiptLedgerOwnedByMonitor |-> FALSE,
        linuxLedgerWrite |-> FALSE,
        monitorReceiptVerified |-> FALSE,
        endpointDelivered |-> FALSE,
        shadowMaterialized |-> FALSE,
        shadowDerivedFromLedger |-> FALSE,
        shadowAuthoritative |-> FALSE,
        shadowInvalidated |-> FALSE,
        revokeRequested |-> FALSE,
        revokeStarted |-> FALSE,
        newReceiptEmbargoed |-> FALSE,
        newReceiptDuringRevoke |-> FALSE,
        derivedReceiptsRevoked |-> FALSE,
        revokeComplete |-> FALSE,
        badUnknownClassAccepted |-> FALSE,
        badResponseWithoutRequest |-> FALSE,
        badReplayAccepted |-> FALSE,
        badFailureThenReceipt |-> FALSE,
        badLinuxLedgerWrite |-> FALSE,
        badEndpointBeforeReceipt |-> FALSE,
        badShadowAuthority |-> FALSE,
        badShadowNotInvalidated |-> FALSE,
        badNewReceiptDuringRevoke |-> FALSE,
        badRevokeCompleteBeforeDerived |-> FALSE
    ]

BuildFreshKnownRequest ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "RequestBuilt",
            !.requestBuilt = TRUE,
            !.knownRequestClass = TRUE,
            !.requestNonceFresh = TRUE,
            !.replayWindowOpen = TRUE
        ]

RejectReplayOrStaleRequest ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "ReplayRejected",
            !.requestBuilt = TRUE,
            !.knownRequestClass = TRUE,
            !.requestNonceFresh = FALSE,
            !.replayWindowOpen = FALSE,
            !.monitorResponseMinted = TRUE,
            !.replayRejected = TRUE
        ]

AcceptRequest ==
    /\ state.phase = "RequestBuilt"
    /\ state.requestBuilt
    /\ state.knownRequestClass
    /\ state.requestNonceFresh
    /\ state.replayWindowOpen
    /\ state' =
        [state EXCEPT
            !.phase = "RequestAccepted",
            !.requestAccepted = TRUE,
            !.replayWindowOpen = FALSE,
            !.monitorResponseMinted = TRUE
        ]

MintFailureResponse ==
    /\ state.phase = "RequestAccepted"
    /\ state.requestAccepted
    /\ state' =
        [state EXCEPT
            !.phase = "FailureResponse",
            !.failureResponseMinted = TRUE
        ]

MintReceiptSet ==
    /\ state.phase = "RequestAccepted"
    /\ state.requestAccepted
    /\ state.monitorResponseMinted
    /\ ~state.failureResponseMinted
    /\ state' =
        [state EXCEPT
            !.phase = "ReceiptSetMinted",
            !.receiptSetMinted = TRUE,
            !.receiptLedgerOwnedByMonitor = TRUE,
            !.monitorReceiptVerified = TRUE
        ]

MintDerivedReceipts ==
    /\ state.phase = "ReceiptSetMinted"
    /\ state.receiptSetMinted
    /\ state.receiptLedgerOwnedByMonitor
    /\ state' =
        [state EXCEPT
            !.phase = "DerivedReceiptsMinted",
            !.derivedReceiptsMinted = TRUE
        ]

MaterializeLinuxShadow ==
    /\ state.phase = "DerivedReceiptsMinted"
    /\ state.monitorReceiptVerified
    /\ state' =
        [state EXCEPT
            !.phase = "ShadowMaterialized",
            !.shadowMaterialized = TRUE,
            !.shadowDerivedFromLedger = TRUE
        ]

DeliverEndpoint ==
    /\ state.phase \in {"DerivedReceiptsMinted", "ShadowMaterialized"}
    /\ state.monitorReceiptVerified
    /\ state.receiptSetMinted
    /\ state.derivedReceiptsMinted
    /\ ~state.shadowAuthoritative
    /\ state' =
        [state EXCEPT
            !.phase = "EndpointDelivered",
            !.endpointDelivered = TRUE
        ]

RequestRevoke ==
    /\ state.phase = "EndpointDelivered"
    /\ state.endpointDelivered
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeRequested",
            !.revokeRequested = TRUE
        ]

StartRevoke ==
    /\ state.phase = "RevokeRequested"
    /\ state.revokeRequested
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeStarted",
            !.revokeStarted = TRUE
        ]

EmbargoNewReceipts ==
    /\ state.phase = "RevokeStarted"
    /\ state.revokeStarted
    /\ state' =
        [state EXCEPT
            !.phase = "NewReceiptEmbargoed",
            !.newReceiptEmbargoed = TRUE
        ]

RevokeDerivedReceipts ==
    /\ state.phase = "NewReceiptEmbargoed"
    /\ state.newReceiptEmbargoed
    /\ state' =
        [state EXCEPT
            !.phase = "DerivedReceiptsRevoked",
            !.derivedReceiptsMinted = FALSE,
            !.monitorReceiptVerified = FALSE,
            !.endpointDelivered = FALSE,
            !.derivedReceiptsRevoked = TRUE
        ]

InvalidateShadow ==
    /\ state.phase = "DerivedReceiptsRevoked"
    /\ state.derivedReceiptsRevoked
    /\ state' =
        [state EXCEPT
            !.phase = "ShadowInvalidated",
            !.shadowInvalidated = TRUE,
            !.shadowDerivedFromLedger = FALSE,
            !.shadowMaterialized = FALSE
        ]

CompleteRevoke ==
    /\ state.phase = "ShadowInvalidated"
    /\ state.derivedReceiptsRevoked
    /\ state.shadowInvalidated
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeComplete",
            !.revokeComplete = TRUE
        ]

UnsafeUnknownClassAccepted ==
    /\ ALLOW_UNSAFE_UNKNOWN_CLASS_ACCEPTED
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "BadUnknownClassAccepted",
            !.requestBuilt = TRUE,
            !.knownRequestClass = FALSE,
            !.requestNonceFresh = TRUE,
            !.requestAccepted = TRUE,
            !.monitorResponseMinted = TRUE,
            !.badUnknownClassAccepted = TRUE
        ]

UnsafeResponseWithoutRequest ==
    /\ ALLOW_UNSAFE_RESPONSE_WITHOUT_REQUEST
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "BadResponseWithoutRequest",
            !.monitorResponseMinted = TRUE,
            !.receiptSetMinted = TRUE,
            !.badResponseWithoutRequest = TRUE
        ]

UnsafeReplayAccepted ==
    /\ ALLOW_UNSAFE_REPLAY_ACCEPTED
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "BadReplayAccepted",
            !.requestBuilt = TRUE,
            !.knownRequestClass = TRUE,
            !.requestNonceFresh = FALSE,
            !.replayWindowOpen = FALSE,
            !.requestAccepted = TRUE,
            !.receiptSetMinted = TRUE,
            !.badReplayAccepted = TRUE
        ]

UnsafeFailureThenReceipt ==
    /\ ALLOW_UNSAFE_FAILURE_THEN_RECEIPT
    /\ state.phase = "FailureResponse"
    /\ state' =
        [state EXCEPT
            !.phase = "BadFailureThenReceipt",
            !.receiptSetMinted = TRUE,
            !.monitorReceiptVerified = TRUE,
            !.badFailureThenReceipt = TRUE
        ]

UnsafeLinuxLedgerWrite ==
    /\ ALLOW_UNSAFE_LINUX_LEDGER_WRITE
    /\ state.phase \in {"RequestBuilt", "RequestAccepted", "ReceiptSetMinted"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxLedgerWrite",
            !.linuxLedgerWrite = TRUE,
            !.receiptSetMinted = TRUE,
            !.badLinuxLedgerWrite = TRUE
        ]

UnsafeEndpointBeforeReceipt ==
    /\ ALLOW_UNSAFE_ENDPOINT_BEFORE_RECEIPT
    /\ state.phase \in {"Start", "RequestBuilt", "RequestAccepted"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadEndpointBeforeReceipt",
            !.endpointDelivered = TRUE,
            !.badEndpointBeforeReceipt = TRUE
        ]

UnsafeShadowAuthority ==
    /\ ALLOW_UNSAFE_SHADOW_AUTHORITY
    /\ state.phase \in {"RequestBuilt", "RequestAccepted", "ReceiptSetMinted",
        "DerivedReceiptsMinted", "ShadowMaterialized"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadShadowAuthority",
            !.shadowMaterialized = TRUE,
            !.shadowAuthoritative = TRUE,
            !.endpointDelivered = TRUE,
            !.badShadowAuthority = TRUE
        ]

UnsafeShadowNotInvalidated ==
    /\ ALLOW_UNSAFE_SHADOW_NOT_INVALIDATED
    /\ state.phase \in {"RevokeStarted", "NewReceiptEmbargoed",
        "DerivedReceiptsRevoked"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadShadowNotInvalidated",
            !.revokeComplete = TRUE,
            !.shadowMaterialized = TRUE,
            !.shadowInvalidated = FALSE,
            !.badShadowNotInvalidated = TRUE
        ]

UnsafeNewReceiptDuringRevoke ==
    /\ ALLOW_UNSAFE_NEW_RECEIPT_DURING_REVOKE
    /\ state.phase \in {"RevokeStarted", "NewReceiptEmbargoed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadNewReceiptDuringRevoke",
            !.newReceiptDuringRevoke = TRUE,
            !.receiptSetMinted = TRUE,
            !.badNewReceiptDuringRevoke = TRUE
        ]

UnsafeRevokeCompleteBeforeDerived ==
    /\ ALLOW_UNSAFE_REVOKE_COMPLETE_BEFORE_DERIVED
    /\ state.phase \in {"RevokeStarted", "NewReceiptEmbargoed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadRevokeCompleteBeforeDerived",
            !.revokeComplete = TRUE,
            !.derivedReceiptsRevoked = FALSE,
            !.badRevokeCompleteBeforeDerived = TRUE
        ]

StutterAtTerminal ==
    /\ state.phase \in TerminalPhases
    /\ UNCHANGED state

Next ==
    \/ BuildFreshKnownRequest
    \/ RejectReplayOrStaleRequest
    \/ AcceptRequest
    \/ MintFailureResponse
    \/ MintReceiptSet
    \/ MintDerivedReceipts
    \/ MaterializeLinuxShadow
    \/ DeliverEndpoint
    \/ RequestRevoke
    \/ StartRevoke
    \/ EmbargoNewReceipts
    \/ RevokeDerivedReceipts
    \/ InvalidateShadow
    \/ CompleteRevoke
    \/ UnsafeUnknownClassAccepted
    \/ UnsafeResponseWithoutRequest
    \/ UnsafeReplayAccepted
    \/ UnsafeFailureThenReceipt
    \/ UnsafeLinuxLedgerWrite
    \/ UnsafeEndpointBeforeReceipt
    \/ UnsafeShadowAuthority
    \/ UnsafeShadowNotInvalidated
    \/ UnsafeNewReceiptDuringRevoke
    \/ UnsafeRevokeCompleteBeforeDerived
    \/ StutterAtTerminal

KnownRequestClassRequiredForAccept ==
    state.requestAccepted => state.knownRequestClass

MonitorResponseRequiresRequest ==
    state.monitorResponseMinted => state.requestBuilt

AcceptedRequestRequiresFreshReplayWindow ==
    state.requestAccepted => state.requestNonceFresh

FailureTerminalForAttempt ==
    state.failureResponseMinted => ~(state.receiptSetMinted \/
        state.derivedReceiptsMinted \/ state.endpointDelivered)

MonitorOwnsReceiptLedgerWrites ==
    ~state.linuxLedgerWrite

EndpointRequiresMonitorVerifiedReceipts ==
    state.endpointDelivered =>
        (state.receiptSetMinted /\ state.derivedReceiptsMinted /\
         state.monitorReceiptVerified)

LinuxShadowIsNotAuthority ==
    ~state.shadowAuthoritative

ShadowInvalidatedBeforeRevokeComplete ==
    state.revokeComplete => state.shadowInvalidated

NoNewReceiptsDuringRevoke ==
    ~state.newReceiptDuringRevoke

RevokeCompleteRequiresDerivedRevoke ==
    state.revokeComplete => state.derivedReceiptsRevoked

NoBadUnknownClassAccepted == ~state.badUnknownClassAccepted
NoBadResponseWithoutRequest == ~state.badResponseWithoutRequest
NoBadReplayAccepted == ~state.badReplayAccepted
NoBadFailureThenReceipt == ~state.badFailureThenReceipt
NoBadLinuxLedgerWrite == ~state.badLinuxLedgerWrite
NoBadEndpointBeforeReceipt == ~state.badEndpointBeforeReceipt
NoBadShadowAuthority == ~state.badShadowAuthority
NoBadShadowNotInvalidated == ~state.badShadowNotInvalidated
NoBadNewReceiptDuringRevoke == ~state.badNewReceiptDuringRevoke
NoBadRevokeCompleteBeforeDerived == ~state.badRevokeCompleteBeforeDerived

=============================================================================
