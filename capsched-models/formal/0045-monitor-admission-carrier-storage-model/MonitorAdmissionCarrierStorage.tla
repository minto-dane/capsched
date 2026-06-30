---------------- MODULE MonitorAdmissionCarrierStorage ----------------

CONSTANTS
    ALLOW_UNSAFE_LINUX_RESPONSE_STORE,
    ALLOW_UNSAFE_QUEUE_AS_AUTHORITY,
    ALLOW_UNSAFE_SHADOW_AS_AUTHORITY,
    ALLOW_UNSAFE_RING_REPLAY,
    ALLOW_UNSAFE_LEDGER_TAMPER,
    ALLOW_UNSAFE_REQUEST_AS_RECEIPT,
    ALLOW_UNSAFE_AUDIT_LOG_AS_AUTHORITY,
    ALLOW_UNSAFE_RAW_HANDLE_ENDPOINT

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "RequestCarried",
    "RequestCopiedByMonitor",
    "MonitorResponseMinted",
    "LinuxShadowCached",
    "ReceiptVerified",
    "EndpointDelivered",
    "BadLinuxResponseStore",
    "BadQueueAsAuthority",
    "BadShadowAsAuthority",
    "BadRingReplay",
    "BadLedgerTamper",
    "BadRequestAsReceipt",
    "BadAuditLogAsAuthority",
    "BadRawHandleEndpoint"
}

StateFields == {
    "phase",
    "requestCarried",
    "requestCarrierNonAuthority",
    "monitorCopiedRequest",
    "monitorResponseMinted",
    "monitorReceiptLedgerAuthority",
    "monitorReceiptVerified",
    "endpointDelivered",
    "linuxResponseStoreAuthority",
    "queueItemAuthority",
    "linuxShadowPresent",
    "linuxShadowAuthority",
    "ringSlotFresh",
    "ringReplayAccepted",
    "ledgerTamperAccepted",
    "requestCarrierAsReceipt",
    "auditLogAsAuthority",
    "rawHandleEndpoint",
    "badLinuxResponseStore",
    "badQueueAsAuthority",
    "badShadowAsAuthority",
    "badRingReplay",
    "badLedgerTamper",
    "badRequestAsReceipt",
    "badAuditLogAsAuthority",
    "badRawHandleEndpoint"
}

BoolFields == StateFields \ {"phase"}

TerminalPhases == {
    "EndpointDelivered",
    "BadLinuxResponseStore",
    "BadQueueAsAuthority",
    "BadShadowAsAuthority",
    "BadRingReplay",
    "BadLedgerTamper",
    "BadRequestAsReceipt",
    "BadAuditLogAsAuthority",
    "BadRawHandleEndpoint"
}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        requestCarried |-> FALSE,
        requestCarrierNonAuthority |-> FALSE,
        monitorCopiedRequest |-> FALSE,
        monitorResponseMinted |-> FALSE,
        monitorReceiptLedgerAuthority |-> FALSE,
        monitorReceiptVerified |-> FALSE,
        endpointDelivered |-> FALSE,
        linuxResponseStoreAuthority |-> FALSE,
        queueItemAuthority |-> FALSE,
        linuxShadowPresent |-> FALSE,
        linuxShadowAuthority |-> FALSE,
        ringSlotFresh |-> FALSE,
        ringReplayAccepted |-> FALSE,
        ledgerTamperAccepted |-> FALSE,
        requestCarrierAsReceipt |-> FALSE,
        auditLogAsAuthority |-> FALSE,
        rawHandleEndpoint |-> FALSE,
        badLinuxResponseStore |-> FALSE,
        badQueueAsAuthority |-> FALSE,
        badShadowAsAuthority |-> FALSE,
        badRingReplay |-> FALSE,
        badLedgerTamper |-> FALSE,
        badRequestAsReceipt |-> FALSE,
        badAuditLogAsAuthority |-> FALSE,
        badRawHandleEndpoint |-> FALSE
    ]

CarryRequest ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "RequestCarried",
            !.requestCarried = TRUE,
            !.requestCarrierNonAuthority = TRUE,
            !.ringSlotFresh = TRUE
        ]

MonitorCopiesRequest ==
    /\ state.phase = "RequestCarried"
    /\ state.requestCarried
    /\ state.requestCarrierNonAuthority
    /\ state.ringSlotFresh
    /\ state' =
        [state EXCEPT
            !.phase = "RequestCopiedByMonitor",
            !.monitorCopiedRequest = TRUE
        ]

MonitorMintsResponse ==
    /\ state.phase = "RequestCopiedByMonitor"
    /\ state.monitorCopiedRequest
    /\ state' =
        [state EXCEPT
            !.phase = "MonitorResponseMinted",
            !.monitorResponseMinted = TRUE,
            !.monitorReceiptLedgerAuthority = TRUE
        ]

CacheLinuxShadow ==
    /\ state.phase = "MonitorResponseMinted"
    /\ state.monitorResponseMinted
    /\ state.monitorReceiptLedgerAuthority
    /\ state' =
        [state EXCEPT
            !.phase = "LinuxShadowCached",
            !.linuxShadowPresent = TRUE
        ]

VerifyReceiptFromMonitorLedger ==
    /\ state.phase \in {"MonitorResponseMinted", "LinuxShadowCached"}
    /\ state.monitorResponseMinted
    /\ state.monitorReceiptLedgerAuthority
    /\ ~state.linuxShadowAuthority
    /\ state' =
        [state EXCEPT
            !.phase = "ReceiptVerified",
            !.monitorReceiptVerified = TRUE
        ]

DeliverEndpointFromVerifiedReceipt ==
    /\ state.phase = "ReceiptVerified"
    /\ state.monitorReceiptVerified
    /\ state.monitorReceiptLedgerAuthority
    /\ state.monitorResponseMinted
    /\ state' =
        [state EXCEPT
            !.phase = "EndpointDelivered",
            !.endpointDelivered = TRUE
        ]

UnsafeLinuxResponseStore ==
    /\ ALLOW_UNSAFE_LINUX_RESPONSE_STORE
    /\ state.phase = "RequestCarried"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxResponseStore",
            !.linuxResponseStoreAuthority = TRUE,
            !.badLinuxResponseStore = TRUE
        ]

UnsafeQueueAsAuthority ==
    /\ ALLOW_UNSAFE_QUEUE_AS_AUTHORITY
    /\ state.phase = "RequestCarried"
    /\ state' =
        [state EXCEPT
            !.phase = "BadQueueAsAuthority",
            !.queueItemAuthority = TRUE,
            !.badQueueAsAuthority = TRUE
        ]

UnsafeShadowAsAuthority ==
    /\ ALLOW_UNSAFE_SHADOW_AS_AUTHORITY
    /\ state.phase \in {"RequestCarried", "RequestCopiedByMonitor",
        "MonitorResponseMinted", "LinuxShadowCached"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadShadowAsAuthority",
            !.linuxShadowPresent = TRUE,
            !.linuxShadowAuthority = TRUE,
            !.badShadowAsAuthority = TRUE
        ]

UnsafeRingReplay ==
    /\ ALLOW_UNSAFE_RING_REPLAY
    /\ state.phase = "RequestCarried"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRingReplay",
            !.ringSlotFresh = FALSE,
            !.ringReplayAccepted = TRUE,
            !.badRingReplay = TRUE
        ]

UnsafeLedgerTamper ==
    /\ ALLOW_UNSAFE_LEDGER_TAMPER
    /\ state.phase \in {"MonitorResponseMinted", "LinuxShadowCached",
        "ReceiptVerified"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadLedgerTamper",
            !.ledgerTamperAccepted = TRUE,
            !.badLedgerTamper = TRUE
        ]

UnsafeRequestAsReceipt ==
    /\ ALLOW_UNSAFE_REQUEST_AS_RECEIPT
    /\ state.phase = "RequestCarried"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRequestAsReceipt",
            !.requestCarrierAsReceipt = TRUE,
            !.badRequestAsReceipt = TRUE
        ]

UnsafeAuditLogAsAuthority ==
    /\ ALLOW_UNSAFE_AUDIT_LOG_AS_AUTHORITY
    /\ state.phase \in {"RequestCarried", "RequestCopiedByMonitor",
        "MonitorResponseMinted"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadAuditLogAsAuthority",
            !.auditLogAsAuthority = TRUE,
            !.badAuditLogAsAuthority = TRUE
        ]

UnsafeRawHandleEndpoint ==
    /\ ALLOW_UNSAFE_RAW_HANDLE_ENDPOINT
    /\ state.phase \in {"RequestCarried", "RequestCopiedByMonitor",
        "MonitorResponseMinted", "LinuxShadowCached"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadRawHandleEndpoint",
            !.rawHandleEndpoint = TRUE,
            !.badRawHandleEndpoint = TRUE
        ]

StutterAtTerminal ==
    /\ state.phase \in TerminalPhases
    /\ UNCHANGED state

Next ==
    \/ CarryRequest
    \/ MonitorCopiesRequest
    \/ MonitorMintsResponse
    \/ CacheLinuxShadow
    \/ VerifyReceiptFromMonitorLedger
    \/ DeliverEndpointFromVerifiedReceipt
    \/ UnsafeLinuxResponseStore
    \/ UnsafeQueueAsAuthority
    \/ UnsafeShadowAsAuthority
    \/ UnsafeRingReplay
    \/ UnsafeLedgerTamper
    \/ UnsafeRequestAsReceipt
    \/ UnsafeAuditLogAsAuthority
    \/ UnsafeRawHandleEndpoint
    \/ StutterAtTerminal

NoLinuxOwnedResponseStoreAuthority ==
    ~state.linuxResponseStoreAuthority

NoServiceDomainQueueItemAsAuthority ==
    ~state.queueItemAuthority

NoLinuxShadowStateAsAuthority ==
    ~state.linuxShadowAuthority

NoReplayedRingSlotAccepted ==
    ~state.ringReplayAccepted

NoTamperedReceiptLedgerAccepted ==
    ~state.ledgerTamperAccepted

NoRequestCarrierTreatedAsReceipt ==
    ~state.requestCarrierAsReceipt

NoAuditOnlyLogTreatedAsAuthority ==
    ~state.auditLogAsAuthority

NoRawServiceDomainHandleEndpoint ==
    ~state.rawHandleEndpoint

NoEndpointWithoutMonitorVerifiedReceipt ==
    state.endpointDelivered =>
        (state.monitorResponseMinted /\ state.monitorReceiptLedgerAuthority /\
         state.monitorReceiptVerified)

NoBadLinuxResponseStore == ~state.badLinuxResponseStore
NoBadQueueAsAuthority == ~state.badQueueAsAuthority
NoBadShadowAsAuthority == ~state.badShadowAsAuthority
NoBadRingReplay == ~state.badRingReplay
NoBadLedgerTamper == ~state.badLedgerTamper
NoBadRequestAsReceipt == ~state.badRequestAsReceipt
NoBadAuditLogAsAuthority == ~state.badAuditLogAsAuthority
NoBadRawHandleEndpoint == ~state.badRawHandleEndpoint

=============================================================================
