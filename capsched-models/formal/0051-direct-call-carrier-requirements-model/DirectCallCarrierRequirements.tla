-------------------- MODULE DirectCallCarrierRequirements --------------------

CONSTANTS
    ALLOW_UNSAFE_VALIDATE_BEFORE_COPY,
    ALLOW_UNSAFE_CARRIER_SELECTION_AS_APPROVAL,
    ALLOW_UNSAFE_SUCCESS_WITHOUT_ATTEMPT,
    ALLOW_UNSAFE_LEDGER_BEFORE_REPLAY,
    ALLOW_UNSAFE_SAME_NONCE_DIFF_DIGEST_SUCCESS,
    ALLOW_UNSAFE_RESPONSE_WITHOUT_LEDGER,
    ALLOW_UNSAFE_SHADOW_WITHOUT_SHARED_GENERATION,
    ALLOW_UNSAFE_TIMEOUT_AS_MONITOR_FAILURE,
    ALLOW_UNSAFE_TRANSPORT_OBSERVATION_AS_RECEIPT,
    ALLOW_UNSAFE_CONTROL_PRIORITY_BYPASS,
    ALLOW_UNSAFE_CARRIER_SEQUENCE_REPLAY,
    ALLOW_UNSAFE_DIRECT_ONLY_NAMESPACE

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "CarrierSelected",
    "LinuxRequestBuilt",
    "MonitorEntered",
    "BoundsChecked",
    "RequestCopied",
    "RequestCanonicalized",
    "DigestChecked",
    "RequestValidated",
    "SharedReplayConsumed",
    "SharedLedgerWritten",
    "ResponseHandleReturned",
    "ShadowRefreshed",
    "LinuxTimeoutObserved",
    "ControlSelected",
    "ControlEntered",
    "ControlCopied",
    "ControlValidated",
    "ControlReplayBudgetEpochChecked",
    "RevokeLedgerWritten",
    "RevokeComplete",
    "BadValidateBeforeCopy",
    "BadCarrierSelectionAsApproval",
    "BadSuccessWithoutAttempt",
    "BadLedgerBeforeReplay",
    "BadSameNonceDiffDigestSuccess",
    "BadResponseWithoutLedger",
    "BadShadowWithoutSharedGeneration",
    "BadTimeoutAsMonitorFailure",
    "BadTransportObservationAsReceipt",
    "BadControlPriorityBypass",
    "BadCarrierSequenceReplay",
    "BadDirectOnlyNamespace"
}

StateFields == {
    "phase",
    "directCarrierSelected",
    "carrierSelectionApproved",
    "linuxRequestBuilt",
    "monitorEntry",
    "boundedLengthChecked",
    "requestCopied",
    "requestCanonicalized",
    "digestChecked",
    "digestMismatch",
    "requestValidated",
    "canonicalAttemptAssigned",
    "sharedReplayConsumed",
    "sharedLedgerWritten",
    "successReceiptMinted",
    "responseHandleReturned",
    "responseHandleBackedByLedger",
    "shadowRefreshed",
    "shadowFromSharedGeneration",
    "linuxTimeoutObserved",
    "transportObservation",
    "terminalMonitorFailure",
    "transportObservationAsReceipt",
    "controlPrioritySelected",
    "controlMonitorEntry",
    "controlRequestCopied",
    "controlValidated",
    "controlReplayChecked",
    "controlBudgetChecked",
    "controlEpochChecked",
    "revokeLedgerWritten",
    "revokeComplete",
    "carrierSequenceUsedForReplay",
    "carrierNeutralReplay",
    "carrierNeutralLedger",
    "sharedShadowNamespace",
    "directOnlyReplayNamespace",
    "directOnlyLedgerNamespace",
    "directOnlyShadowNamespace",
    "badValidateBeforeCopy",
    "badCarrierSelectionAsApproval",
    "badSuccessWithoutAttempt",
    "badLedgerBeforeReplay",
    "badSameNonceDiffDigestSuccess",
    "badResponseWithoutLedger",
    "badShadowWithoutSharedGeneration",
    "badTimeoutAsMonitorFailure",
    "badTransportObservationAsReceipt",
    "badControlPriorityBypass",
    "badCarrierSequenceReplay",
    "badDirectOnlyNamespace"
}

BoolFields == StateFields \ {"phase"}

TerminalPhases == {
    "ShadowRefreshed",
    "LinuxTimeoutObserved",
    "RevokeComplete",
    "BadValidateBeforeCopy",
    "BadCarrierSelectionAsApproval",
    "BadSuccessWithoutAttempt",
    "BadLedgerBeforeReplay",
    "BadSameNonceDiffDigestSuccess",
    "BadResponseWithoutLedger",
    "BadShadowWithoutSharedGeneration",
    "BadTimeoutAsMonitorFailure",
    "BadTransportObservationAsReceipt",
    "BadControlPriorityBypass",
    "BadCarrierSequenceReplay",
    "BadDirectOnlyNamespace"
}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        directCarrierSelected |-> FALSE,
        carrierSelectionApproved |-> FALSE,
        linuxRequestBuilt |-> FALSE,
        monitorEntry |-> FALSE,
        boundedLengthChecked |-> FALSE,
        requestCopied |-> FALSE,
        requestCanonicalized |-> FALSE,
        digestChecked |-> FALSE,
        digestMismatch |-> FALSE,
        requestValidated |-> FALSE,
        canonicalAttemptAssigned |-> FALSE,
        sharedReplayConsumed |-> FALSE,
        sharedLedgerWritten |-> FALSE,
        successReceiptMinted |-> FALSE,
        responseHandleReturned |-> FALSE,
        responseHandleBackedByLedger |-> FALSE,
        shadowRefreshed |-> FALSE,
        shadowFromSharedGeneration |-> FALSE,
        linuxTimeoutObserved |-> FALSE,
        transportObservation |-> FALSE,
        terminalMonitorFailure |-> FALSE,
        transportObservationAsReceipt |-> FALSE,
        controlPrioritySelected |-> FALSE,
        controlMonitorEntry |-> FALSE,
        controlRequestCopied |-> FALSE,
        controlValidated |-> FALSE,
        controlReplayChecked |-> FALSE,
        controlBudgetChecked |-> FALSE,
        controlEpochChecked |-> FALSE,
        revokeLedgerWritten |-> FALSE,
        revokeComplete |-> FALSE,
        carrierSequenceUsedForReplay |-> FALSE,
        carrierNeutralReplay |-> FALSE,
        carrierNeutralLedger |-> FALSE,
        sharedShadowNamespace |-> FALSE,
        directOnlyReplayNamespace |-> FALSE,
        directOnlyLedgerNamespace |-> FALSE,
        directOnlyShadowNamespace |-> FALSE,
        badValidateBeforeCopy |-> FALSE,
        badCarrierSelectionAsApproval |-> FALSE,
        badSuccessWithoutAttempt |-> FALSE,
        badLedgerBeforeReplay |-> FALSE,
        badSameNonceDiffDigestSuccess |-> FALSE,
        badResponseWithoutLedger |-> FALSE,
        badShadowWithoutSharedGeneration |-> FALSE,
        badTimeoutAsMonitorFailure |-> FALSE,
        badTransportObservationAsReceipt |-> FALSE,
        badControlPriorityBypass |-> FALSE,
        badCarrierSequenceReplay |-> FALSE,
        badDirectOnlyNamespace |-> FALSE
    ]

SelectDirectCarrier ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "CarrierSelected",
            !.directCarrierSelected = TRUE,
            !.carrierNeutralReplay = TRUE,
            !.carrierNeutralLedger = TRUE,
            !.sharedShadowNamespace = TRUE
        ]

BuildLinuxRequest ==
    /\ state.phase = "CarrierSelected"
    /\ state.directCarrierSelected
    /\ ~state.carrierSelectionApproved
    /\ state' =
        [state EXCEPT
            !.phase = "LinuxRequestBuilt",
            !.linuxRequestBuilt = TRUE
        ]

EnterMonitor ==
    /\ state.phase = "LinuxRequestBuilt"
    /\ state.linuxRequestBuilt
    /\ state' =
        [state EXCEPT
            !.phase = "MonitorEntered",
            !.monitorEntry = TRUE,
            !.canonicalAttemptAssigned = TRUE
        ]

CheckBounds ==
    /\ state.phase = "MonitorEntered"
    /\ state.monitorEntry
    /\ state' =
        [state EXCEPT
            !.phase = "BoundsChecked",
            !.boundedLengthChecked = TRUE
        ]

CopyRequest ==
    /\ state.phase = "BoundsChecked"
    /\ state.boundedLengthChecked
    /\ state' =
        [state EXCEPT
            !.phase = "RequestCopied",
            !.requestCopied = TRUE
        ]

CanonicalizeRequest ==
    /\ state.phase = "RequestCopied"
    /\ state.requestCopied
    /\ state' =
        [state EXCEPT
            !.phase = "RequestCanonicalized",
            !.requestCanonicalized = TRUE
        ]

CheckDigest ==
    /\ state.phase = "RequestCanonicalized"
    /\ state.requestCanonicalized
    /\ state' =
        [state EXCEPT
            !.phase = "DigestChecked",
            !.digestChecked = TRUE
        ]

ValidateRequest ==
    /\ state.phase = "DigestChecked"
    /\ state.digestChecked
    /\ state.requestCanonicalized
    /\ state.requestCopied
    /\ state.boundedLengthChecked
    /\ ~state.digestMismatch
    /\ state' =
        [state EXCEPT
            !.phase = "RequestValidated",
            !.requestValidated = TRUE
        ]

ConsumeSharedReplay ==
    /\ state.phase = "RequestValidated"
    /\ state.requestValidated
    /\ state.canonicalAttemptAssigned
    /\ state.carrierNeutralReplay
    /\ state' =
        [state EXCEPT
            !.phase = "SharedReplayConsumed",
            !.sharedReplayConsumed = TRUE
        ]

WriteSharedLedger ==
    /\ state.phase = "SharedReplayConsumed"
    /\ state.sharedReplayConsumed
    /\ state.carrierNeutralLedger
    /\ state.canonicalAttemptAssigned
    /\ state' =
        [state EXCEPT
            !.phase = "SharedLedgerWritten",
            !.sharedLedgerWritten = TRUE,
            !.successReceiptMinted = TRUE
        ]

ReturnResponseHandle ==
    /\ state.phase = "SharedLedgerWritten"
    /\ state.sharedLedgerWritten
    /\ state.successReceiptMinted
    /\ state' =
        [state EXCEPT
            !.phase = "ResponseHandleReturned",
            !.responseHandleReturned = TRUE,
            !.responseHandleBackedByLedger = TRUE
        ]

RefreshShadow ==
    /\ state.phase = "ResponseHandleReturned"
    /\ state.responseHandleBackedByLedger
    /\ state.sharedShadowNamespace
    /\ state' =
        [state EXCEPT
            !.phase = "ShadowRefreshed",
            !.shadowRefreshed = TRUE,
            !.shadowFromSharedGeneration = TRUE
        ]

ObserveLinuxTimeout ==
    /\ state.phase \in {"CarrierSelected", "LinuxRequestBuilt"}
    /\ ~state.monitorEntry
    /\ state' =
        [state EXCEPT
            !.phase = "LinuxTimeoutObserved",
            !.linuxTimeoutObserved = TRUE,
            !.transportObservation = TRUE
        ]

SelectControlPriority ==
    /\ state.phase = "ShadowRefreshed"
    /\ state.shadowRefreshed
    /\ state' =
        [state EXCEPT
            !.phase = "ControlSelected",
            !.controlPrioritySelected = TRUE
        ]

EnterControlMonitor ==
    /\ state.phase = "ControlSelected"
    /\ state.controlPrioritySelected
    /\ state' =
        [state EXCEPT
            !.phase = "ControlEntered",
            !.controlMonitorEntry = TRUE
        ]

CopyControlRequest ==
    /\ state.phase = "ControlEntered"
    /\ state.controlMonitorEntry
    /\ state' =
        [state EXCEPT
            !.phase = "ControlCopied",
            !.controlRequestCopied = TRUE
        ]

ValidateControlRequest ==
    /\ state.phase = "ControlCopied"
    /\ state.controlRequestCopied
    /\ state' =
        [state EXCEPT
            !.phase = "ControlValidated",
            !.controlValidated = TRUE
        ]

CheckControlReplayBudgetEpoch ==
    /\ state.phase = "ControlValidated"
    /\ state.controlValidated
    /\ state' =
        [state EXCEPT
            !.phase = "ControlReplayBudgetEpochChecked",
            !.controlReplayChecked = TRUE,
            !.controlBudgetChecked = TRUE,
            !.controlEpochChecked = TRUE
        ]

WriteRevokeLedger ==
    /\ state.phase = "ControlReplayBudgetEpochChecked"
    /\ state.controlReplayChecked
    /\ state.controlBudgetChecked
    /\ state.controlEpochChecked
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeLedgerWritten",
            !.revokeLedgerWritten = TRUE
        ]

CompleteRevoke ==
    /\ state.phase = "RevokeLedgerWritten"
    /\ state.revokeLedgerWritten
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeComplete",
            !.revokeComplete = TRUE
        ]

UnsafeValidateBeforeCopy ==
    /\ ALLOW_UNSAFE_VALIDATE_BEFORE_COPY
    /\ state.phase = "MonitorEntered"
    /\ state' =
        [state EXCEPT
            !.phase = "BadValidateBeforeCopy",
            !.requestValidated = TRUE,
            !.badValidateBeforeCopy = TRUE
        ]

UnsafeCarrierSelectionAsApproval ==
    /\ ALLOW_UNSAFE_CARRIER_SELECTION_AS_APPROVAL
    /\ state.phase = "CarrierSelected"
    /\ state' =
        [state EXCEPT
            !.phase = "BadCarrierSelectionAsApproval",
            !.carrierSelectionApproved = TRUE,
            !.successReceiptMinted = TRUE,
            !.badCarrierSelectionAsApproval = TRUE
        ]

UnsafeSuccessWithoutAttempt ==
    /\ ALLOW_UNSAFE_SUCCESS_WITHOUT_ATTEMPT
    /\ state.phase = "CarrierSelected"
    /\ state' =
        [state EXCEPT
            !.phase = "BadSuccessWithoutAttempt",
            !.successReceiptMinted = TRUE,
            !.badSuccessWithoutAttempt = TRUE
        ]

UnsafeLedgerBeforeReplay ==
    /\ ALLOW_UNSAFE_LEDGER_BEFORE_REPLAY
    /\ state.phase = "RequestValidated"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLedgerBeforeReplay",
            !.sharedLedgerWritten = TRUE,
            !.successReceiptMinted = TRUE,
            !.badLedgerBeforeReplay = TRUE
        ]

UnsafeSameNonceDiffDigestSuccess ==
    /\ ALLOW_UNSAFE_SAME_NONCE_DIFF_DIGEST_SUCCESS
    /\ state.phase = "DigestChecked"
    /\ state' =
        [state EXCEPT
            !.phase = "BadSameNonceDiffDigestSuccess",
            !.digestMismatch = TRUE,
            !.sharedReplayConsumed = TRUE,
            !.sharedLedgerWritten = TRUE,
            !.successReceiptMinted = TRUE,
            !.badSameNonceDiffDigestSuccess = TRUE
        ]

UnsafeResponseWithoutLedger ==
    /\ ALLOW_UNSAFE_RESPONSE_WITHOUT_LEDGER
    /\ state.phase = "RequestValidated"
    /\ state' =
        [state EXCEPT
            !.phase = "BadResponseWithoutLedger",
            !.responseHandleReturned = TRUE,
            !.badResponseWithoutLedger = TRUE
        ]

UnsafeShadowWithoutSharedGeneration ==
    /\ ALLOW_UNSAFE_SHADOW_WITHOUT_SHARED_GENERATION
    /\ state.phase = "ResponseHandleReturned"
    /\ state' =
        [state EXCEPT
            !.phase = "BadShadowWithoutSharedGeneration",
            !.shadowRefreshed = TRUE,
            !.shadowFromSharedGeneration = FALSE,
            !.badShadowWithoutSharedGeneration = TRUE
        ]

UnsafeTimeoutAsMonitorFailure ==
    /\ ALLOW_UNSAFE_TIMEOUT_AS_MONITOR_FAILURE
    /\ state.phase = "LinuxTimeoutObserved"
    /\ state.linuxTimeoutObserved
    /\ state' =
        [state EXCEPT
            !.phase = "BadTimeoutAsMonitorFailure",
            !.terminalMonitorFailure = TRUE,
            !.badTimeoutAsMonitorFailure = TRUE
        ]

UnsafeTransportObservationAsReceipt ==
    /\ ALLOW_UNSAFE_TRANSPORT_OBSERVATION_AS_RECEIPT
    /\ state.phase = "LinuxTimeoutObserved"
    /\ state.transportObservation
    /\ state' =
        [state EXCEPT
            !.phase = "BadTransportObservationAsReceipt",
            !.transportObservationAsReceipt = TRUE,
            !.successReceiptMinted = TRUE,
            !.badTransportObservationAsReceipt = TRUE
        ]

UnsafeControlPriorityBypass ==
    /\ ALLOW_UNSAFE_CONTROL_PRIORITY_BYPASS
    /\ state.phase = "ControlSelected"
    /\ state.controlPrioritySelected
    /\ state' =
        [state EXCEPT
            !.phase = "BadControlPriorityBypass",
            !.revokeLedgerWritten = TRUE,
            !.revokeComplete = TRUE,
            !.badControlPriorityBypass = TRUE
        ]

UnsafeCarrierSequenceReplay ==
    /\ ALLOW_UNSAFE_CARRIER_SEQUENCE_REPLAY
    /\ state.phase = "CarrierSelected"
    /\ state' =
        [state EXCEPT
            !.phase = "BadCarrierSequenceReplay",
            !.carrierSequenceUsedForReplay = TRUE,
            !.sharedReplayConsumed = TRUE,
            !.sharedLedgerWritten = TRUE,
            !.successReceiptMinted = TRUE,
            !.badCarrierSequenceReplay = TRUE
        ]

UnsafeDirectOnlyNamespace ==
    /\ ALLOW_UNSAFE_DIRECT_ONLY_NAMESPACE
    /\ state.phase = "SharedLedgerWritten"
    /\ state' =
        [state EXCEPT
            !.phase = "BadDirectOnlyNamespace",
            !.directOnlyReplayNamespace = TRUE,
            !.directOnlyLedgerNamespace = TRUE,
            !.directOnlyShadowNamespace = TRUE,
            !.badDirectOnlyNamespace = TRUE
        ]

StutterAtTerminal ==
    /\ state.phase \in TerminalPhases
    /\ UNCHANGED state

Next ==
    \/ SelectDirectCarrier
    \/ BuildLinuxRequest
    \/ EnterMonitor
    \/ CheckBounds
    \/ CopyRequest
    \/ CanonicalizeRequest
    \/ CheckDigest
    \/ ValidateRequest
    \/ ConsumeSharedReplay
    \/ WriteSharedLedger
    \/ ReturnResponseHandle
    \/ RefreshShadow
    \/ ObserveLinuxTimeout
    \/ SelectControlPriority
    \/ EnterControlMonitor
    \/ CopyControlRequest
    \/ ValidateControlRequest
    \/ CheckControlReplayBudgetEpoch
    \/ WriteRevokeLedger
    \/ CompleteRevoke
    \/ UnsafeValidateBeforeCopy
    \/ UnsafeCarrierSelectionAsApproval
    \/ UnsafeSuccessWithoutAttempt
    \/ UnsafeLedgerBeforeReplay
    \/ UnsafeSameNonceDiffDigestSuccess
    \/ UnsafeResponseWithoutLedger
    \/ UnsafeShadowWithoutSharedGeneration
    \/ UnsafeTimeoutAsMonitorFailure
    \/ UnsafeTransportObservationAsReceipt
    \/ UnsafeControlPriorityBypass
    \/ UnsafeCarrierSequenceReplay
    \/ UnsafeDirectOnlyNamespace
    \/ StutterAtTerminal

ValidationRequiresBoundedCopyFreeze ==
    state.requestValidated =>
        (state.monitorEntry /\ state.boundedLengthChecked /\
         state.requestCopied /\ state.requestCanonicalized /\ state.digestChecked)

CarrierSelectionIsNotApproval ==
    ~state.carrierSelectionApproved

SuccessRequiresCanonicalAttempt ==
    state.successReceiptMinted => state.canonicalAttemptAssigned

SuccessRequiresSharedReplay ==
    state.successReceiptMinted => state.sharedReplayConsumed

LedgerRequiresSharedReplay ==
    state.sharedLedgerWritten => state.sharedReplayConsumed

NoSameNonceDifferentDigestSuccess ==
    state.digestMismatch => ~state.successReceiptMinted

ResponseRequiresLedger ==
    state.responseHandleReturned =>
        (state.sharedLedgerWritten /\ state.responseHandleBackedByLedger)

ShadowRequiresSharedGeneration ==
    state.shadowRefreshed =>
        (state.responseHandleBackedByLedger /\ state.shadowFromSharedGeneration /\
         state.sharedShadowNamespace)

LinuxTimeoutIsNotMonitorFailure ==
    state.linuxTimeoutObserved => ~state.terminalMonitorFailure

TransportObservationIsNotReceipt ==
    ~(state.transportObservationAsReceipt /\ state.successReceiptMinted)

ControlRevokeRequiresReplayBudgetEpoch ==
    state.revokeComplete =>
        (state.controlReplayChecked /\ state.controlBudgetChecked /\
         state.controlEpochChecked /\ state.revokeLedgerWritten)

CarrierSequenceIsNotReplayAuthority ==
    ~state.carrierSequenceUsedForReplay

DirectCallKeepsCarrierNeutralNamespaces ==
    ~(state.directOnlyReplayNamespace \/ state.directOnlyLedgerNamespace \/
      state.directOnlyShadowNamespace)

NoBadValidateBeforeCopy == ~state.badValidateBeforeCopy

NoBadCarrierSelectionAsApproval == ~state.badCarrierSelectionAsApproval

NoBadSuccessWithoutAttempt == ~state.badSuccessWithoutAttempt

NoBadLedgerBeforeReplay == ~state.badLedgerBeforeReplay

NoBadSameNonceDiffDigestSuccess == ~state.badSameNonceDiffDigestSuccess

NoBadResponseWithoutLedger == ~state.badResponseWithoutLedger

NoBadShadowWithoutSharedGeneration == ~state.badShadowWithoutSharedGeneration

NoBadTimeoutAsMonitorFailure == ~state.badTimeoutAsMonitorFailure

NoBadTransportObservationAsReceipt == ~state.badTransportObservationAsReceipt

NoBadControlPriorityBypass == ~state.badControlPriorityBypass

NoBadCarrierSequenceReplay == ~state.badCarrierSequenceReplay

NoBadDirectOnlyNamespace == ~state.badDirectOnlyNamespace

Spec == Init /\ [][Next]_vars

=============================================================================
