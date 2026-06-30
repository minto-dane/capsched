-------------------- MODULE LocalMonitorAdmissionInterface --------------------

CONSTANTS
    ALLOW_UNSAFE_LINUX_MINTS_RESPONSE,
    ALLOW_UNSAFE_REPLAY_ACCEPTED,
    ALLOW_UNSAFE_FAILURE_THEN_COMPILE,
    ALLOW_UNSAFE_RECEIPT_WITHOUT_MONITOR_RESPONSE,
    ALLOW_UNSAFE_ENDPOINT_WITHOUT_RECEIPTS,
    ALLOW_UNSAFE_REVOKE_COMPLETE_WITH_LIVE_DERIVED,
    ALLOW_UNSAFE_RAW_SERVICE_HANDLE

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "AdmissionRequestBuilt",
    "RequestAccepted",
    "FailureResponseMinted",
    "CompileResponseMinted",
    "DeviceReceiptsMinted",
    "EndpointDelivered",
    "RevokeRequestBuilt",
    "RevokeStarted",
    "ReceiptEmbargoed",
    "DerivedReceiptsRevoked",
    "RevokeComplete",
    "BadLinuxMintsResponse",
    "BadReplayAccepted",
    "BadFailureThenCompile",
    "BadReceiptWithoutMonitorResponse",
    "BadEndpointWithoutReceipts",
    "BadRevokeCompleteWithLiveDerived",
    "BadRawServiceHandle"
}

StateFields == {
    "phase",
    "admissionRequestBuilt",
    "requestNonceFresh",
    "requestGenerationFresh",
    "monitorEpochFresh",
    "clusterEpochFresh",
    "serviceEpochFresh",
    "targetEpochFresh",
    "deviceRootEpochFresh",
    "requestAccepted",
    "monitorResponseMinted",
    "linuxResponseMinted",
    "failureReceiptMinted",
    "localLeaseReceiptMinted",
    "deviceReceiptsMinted",
    "typedEndpointDelivered",
    "replayAccepted",
    "rawServiceHandleExposed",
    "revokeRequestBuilt",
    "revokeStartedReceipt",
    "newReceiptEmbargoReceipt",
    "derivedRevokeReceipt",
    "revokeCompleteReceipt",
    "derivedReceiptsLive",
    "badLinuxMintsResponse",
    "badReplayAccepted",
    "badFailureThenCompile",
    "badReceiptWithoutMonitorResponse",
    "badEndpointWithoutReceipts",
    "badRevokeCompleteWithLiveDerived",
    "badRawServiceHandle"
}

BoolFields == StateFields \ {"phase"}

TerminalPhases == {
    "FailureResponseMinted",
    "RevokeComplete",
    "BadLinuxMintsResponse",
    "BadReplayAccepted",
    "BadFailureThenCompile",
    "BadReceiptWithoutMonitorResponse",
    "BadEndpointWithoutReceipts",
    "BadRevokeCompleteWithLiveDerived",
    "BadRawServiceHandle"
}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        admissionRequestBuilt |-> FALSE,
        requestNonceFresh |-> FALSE,
        requestGenerationFresh |-> FALSE,
        monitorEpochFresh |-> FALSE,
        clusterEpochFresh |-> FALSE,
        serviceEpochFresh |-> FALSE,
        targetEpochFresh |-> FALSE,
        deviceRootEpochFresh |-> FALSE,
        requestAccepted |-> FALSE,
        monitorResponseMinted |-> FALSE,
        linuxResponseMinted |-> FALSE,
        failureReceiptMinted |-> FALSE,
        localLeaseReceiptMinted |-> FALSE,
        deviceReceiptsMinted |-> FALSE,
        typedEndpointDelivered |-> FALSE,
        replayAccepted |-> FALSE,
        rawServiceHandleExposed |-> FALSE,
        revokeRequestBuilt |-> FALSE,
        revokeStartedReceipt |-> FALSE,
        newReceiptEmbargoReceipt |-> FALSE,
        derivedRevokeReceipt |-> FALSE,
        revokeCompleteReceipt |-> FALSE,
        derivedReceiptsLive |-> FALSE,
        badLinuxMintsResponse |-> FALSE,
        badReplayAccepted |-> FALSE,
        badFailureThenCompile |-> FALSE,
        badReceiptWithoutMonitorResponse |-> FALSE,
        badEndpointWithoutReceipts |-> FALSE,
        badRevokeCompleteWithLiveDerived |-> FALSE,
        badRawServiceHandle |-> FALSE
    ]

BuildAdmissionRequest ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "AdmissionRequestBuilt",
            !.admissionRequestBuilt = TRUE,
            !.requestNonceFresh = TRUE,
            !.requestGenerationFresh = TRUE,
            !.clusterEpochFresh = TRUE,
            !.serviceEpochFresh = TRUE,
            !.targetEpochFresh = TRUE,
            !.deviceRootEpochFresh = TRUE
        ]

AcceptRequestByMonitor ==
    /\ state.phase = "AdmissionRequestBuilt"
    /\ state.admissionRequestBuilt
    /\ state.requestNonceFresh
    /\ state.requestGenerationFresh
    /\ state.clusterEpochFresh
    /\ state.serviceEpochFresh
    /\ state.targetEpochFresh
    /\ state.deviceRootEpochFresh
    /\ state' =
        [state EXCEPT
            !.phase = "RequestAccepted",
            !.requestAccepted = TRUE,
            !.monitorEpochFresh = TRUE
        ]

MintFailureReceipt ==
    /\ state.phase = "RequestAccepted"
    /\ state.requestAccepted
    /\ state' =
        [state EXCEPT
            !.phase = "FailureResponseMinted",
            !.monitorResponseMinted = TRUE,
            !.failureReceiptMinted = TRUE
        ]

MintCompileResponse ==
    /\ state.phase = "RequestAccepted"
    /\ state.requestAccepted
    /\ state.monitorEpochFresh
    /\ ~state.failureReceiptMinted
    /\ state' =
        [state EXCEPT
            !.phase = "CompileResponseMinted",
            !.monitorResponseMinted = TRUE,
            !.localLeaseReceiptMinted = TRUE
        ]

MintDeviceReceipts ==
    /\ state.phase = "CompileResponseMinted"
    /\ state.monitorResponseMinted
    /\ state.localLeaseReceiptMinted
    /\ state' =
        [state EXCEPT
            !.phase = "DeviceReceiptsMinted",
            !.deviceReceiptsMinted = TRUE,
            !.derivedReceiptsLive = TRUE
        ]

DeliverTypedEndpoint ==
    /\ state.phase = "DeviceReceiptsMinted"
    /\ state.deviceReceiptsMinted
    /\ state.derivedReceiptsLive
    /\ state' =
        [state EXCEPT
            !.phase = "EndpointDelivered",
            !.typedEndpointDelivered = TRUE
        ]

BuildRevokeRequest ==
    /\ state.phase = "EndpointDelivered"
    /\ state.localLeaseReceiptMinted
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeRequestBuilt",
            !.revokeRequestBuilt = TRUE
        ]

MintRevokeStartedReceipt ==
    /\ state.phase = "RevokeRequestBuilt"
    /\ state.revokeRequestBuilt
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeStarted",
            !.revokeStartedReceipt = TRUE
        ]

MintNewReceiptEmbargoReceipt ==
    /\ state.phase = "RevokeStarted"
    /\ state.revokeStartedReceipt
    /\ state' =
        [state EXCEPT
            !.phase = "ReceiptEmbargoed",
            !.newReceiptEmbargoReceipt = TRUE
        ]

MintDerivedRevokeReceipt ==
    /\ state.phase = "ReceiptEmbargoed"
    /\ state.newReceiptEmbargoReceipt
    /\ state' =
        [state EXCEPT
            !.phase = "DerivedReceiptsRevoked",
            !.derivedReceiptsLive = FALSE,
            !.derivedRevokeReceipt = TRUE
        ]

MintRevokeCompleteReceipt ==
    /\ state.phase = "DerivedReceiptsRevoked"
    /\ state.derivedRevokeReceipt
    /\ ~state.derivedReceiptsLive
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeComplete",
            !.revokeCompleteReceipt = TRUE
        ]

UnsafeLinuxMintsResponse ==
    /\ ALLOW_UNSAFE_LINUX_MINTS_RESPONSE
    /\ state.phase = "AdmissionRequestBuilt"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxMintsResponse",
            !.linuxResponseMinted = TRUE,
            !.localLeaseReceiptMinted = TRUE,
            !.badLinuxMintsResponse = TRUE
        ]

UnsafeReplayAccepted ==
    /\ ALLOW_UNSAFE_REPLAY_ACCEPTED
    /\ state.phase = "AdmissionRequestBuilt"
    /\ state' =
        [state EXCEPT
            !.phase = "BadReplayAccepted",
            !.replayAccepted = TRUE,
            !.monitorResponseMinted = TRUE,
            !.badReplayAccepted = TRUE
        ]

UnsafeFailureThenCompile ==
    /\ ALLOW_UNSAFE_FAILURE_THEN_COMPILE
    /\ state.phase = "FailureResponseMinted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadFailureThenCompile",
            !.localLeaseReceiptMinted = TRUE,
            !.badFailureThenCompile = TRUE
        ]

UnsafeReceiptWithoutMonitorResponse ==
    /\ ALLOW_UNSAFE_RECEIPT_WITHOUT_MONITOR_RESPONSE
    /\ state.phase \in {"Start", "AdmissionRequestBuilt", "RequestAccepted"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadReceiptWithoutMonitorResponse",
            !.deviceReceiptsMinted = TRUE,
            !.derivedReceiptsLive = TRUE,
            !.badReceiptWithoutMonitorResponse = TRUE
        ]

UnsafeEndpointWithoutReceipts ==
    /\ ALLOW_UNSAFE_ENDPOINT_WITHOUT_RECEIPTS
    /\ state.phase \in {"Start", "AdmissionRequestBuilt", "RequestAccepted",
        "CompileResponseMinted"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadEndpointWithoutReceipts",
            !.typedEndpointDelivered = TRUE,
            !.badEndpointWithoutReceipts = TRUE
        ]

UnsafeRevokeCompleteWithLiveDerived ==
    /\ ALLOW_UNSAFE_REVOKE_COMPLETE_WITH_LIVE_DERIVED
    /\ state.phase \in {"RevokeStarted", "ReceiptEmbargoed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadRevokeCompleteWithLiveDerived",
            !.derivedReceiptsLive = TRUE,
            !.revokeCompleteReceipt = TRUE,
            !.badRevokeCompleteWithLiveDerived = TRUE
        ]

UnsafeRawServiceHandle ==
    /\ ALLOW_UNSAFE_RAW_SERVICE_HANDLE
    /\ state.phase \in {"RequestAccepted", "CompileResponseMinted",
        "DeviceReceiptsMinted"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadRawServiceHandle",
            !.rawServiceHandleExposed = TRUE,
            !.typedEndpointDelivered = TRUE,
            !.badRawServiceHandle = TRUE
        ]

StutterAtTerminal ==
    /\ state.phase \in TerminalPhases
    /\ UNCHANGED state

Next ==
    \/ BuildAdmissionRequest
    \/ AcceptRequestByMonitor
    \/ MintFailureReceipt
    \/ MintCompileResponse
    \/ MintDeviceReceipts
    \/ DeliverTypedEndpoint
    \/ BuildRevokeRequest
    \/ MintRevokeStartedReceipt
    \/ MintNewReceiptEmbargoReceipt
    \/ MintDerivedRevokeReceipt
    \/ MintRevokeCompleteReceipt
    \/ UnsafeLinuxMintsResponse
    \/ UnsafeReplayAccepted
    \/ UnsafeFailureThenCompile
    \/ UnsafeReceiptWithoutMonitorResponse
    \/ UnsafeEndpointWithoutReceipts
    \/ UnsafeRevokeCompleteWithLiveDerived
    \/ UnsafeRawServiceHandle
    \/ StutterAtTerminal

NoLinuxMintedMonitorResponse ==
    ~state.linuxResponseMinted

NoReplayedAdmissionResponse ==
    ~state.replayAccepted

FailureReceiptTerminatesAttempt ==
    state.failureReceiptMinted => ~(state.localLeaseReceiptMinted \/
        state.deviceReceiptsMinted \/ state.typedEndpointDelivered)

NoDeviceReceiptWithoutMonitorLocalLeaseResponse ==
    state.deviceReceiptsMinted => (state.monitorResponseMinted /\
        state.localLeaseReceiptMinted)

NoTypedEndpointWithoutMonitorDeviceReceipts ==
    state.typedEndpointDelivered => state.deviceReceiptsMinted

NoLocalLeaseReuseBeforeRevokeComplete ==
    state.revokeCompleteReceipt => state.derivedRevokeReceipt

NoRevokeCompleteWithLiveDerivedReceipts ==
    state.revokeCompleteReceipt => ~state.derivedReceiptsLive

NoRawServiceDomainHandleEscapes ==
    ~state.rawServiceHandleExposed

NoBadLinuxMintsResponse == ~state.badLinuxMintsResponse
NoBadReplayAccepted == ~state.badReplayAccepted
NoBadFailureThenCompile == ~state.badFailureThenCompile
NoBadReceiptWithoutMonitorResponse == ~state.badReceiptWithoutMonitorResponse
NoBadEndpointWithoutReceipts == ~state.badEndpointWithoutReceipts
NoBadRevokeCompleteWithLiveDerived == ~state.badRevokeCompleteWithLiveDerived
NoBadRawServiceHandle == ~state.badRawServiceHandle

=============================================================================
