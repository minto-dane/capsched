-------------------- MODULE DirectCallReferenceABI --------------------

CONSTANTS
    ALLOW_UNSAFE_VALIDATE_LINUX_MUTABLE,
    ALLOW_UNSAFE_SUCCESS_WITHOUT_ENTRY,
    ALLOW_UNSAFE_LEDGER_WITHOUT_COPY_VALIDATION,
    ALLOW_UNSAFE_LEDGER_BEFORE_REPLAY,
    ALLOW_UNSAFE_LINUX_LEDGER_WRITE,
    ALLOW_UNSAFE_RESPONSE_WITHOUT_LEDGER,
    ALLOW_UNSAFE_SHADOW_FROM_REQUEST,
    ALLOW_UNSAFE_SHADOW_AUTHORITY,
    ALLOW_UNSAFE_FAILURE_THEN_RECEIPT,
    ALLOW_UNSAFE_REVOKE_WITHOUT_EMBARGO,
    ALLOW_UNSAFE_REVOKE_WITH_INFLIGHT,
    ALLOW_UNSAFE_REVOKE_BEFORE_DERIVED_SHADOW

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "LinuxRequestBuilt",
    "MonitorEntered",
    "RequestCopied",
    "RequestValidated",
    "ReplayConsumed",
    "SuccessLedgerWritten",
    "ResponseHandleMinted",
    "ShadowRefreshed",
    "FailureResponse",
    "RevokeRequestBuilt",
    "RevokeEntered",
    "RevokeRequestCopied",
    "RevokeValidated",
    "RevokeReplayConsumed",
    "RevokeStarted",
    "NewReceiptEmbargoed",
    "InFlightDrained",
    "DerivedReceiptsRevoked",
    "ShadowInvalidated",
    "RevokeComplete",
    "BadValidateLinuxMutable",
    "BadSuccessWithoutEntry",
    "BadLedgerWithoutCopyValidation",
    "BadLedgerBeforeReplay",
    "BadLinuxLedgerWrite",
    "BadResponseWithoutLedger",
    "BadShadowFromRequest",
    "BadShadowAuthority",
    "BadFailureThenReceipt",
    "BadRevokeWithoutEmbargo",
    "BadRevokeWithInFlight",
    "BadRevokeBeforeDerivedShadow"
}

StateFields == {
    "phase",
    "linuxRequestBuilt",
    "monitorEntry",
    "requestCopied",
    "linuxMutableValidated",
    "requestValidated",
    "replayConsumed",
    "successLedgerWritten",
    "linuxLedgerWrite",
    "responseHandleMinted",
    "shadowRefreshed",
    "shadowFromHandle",
    "shadowFromRequest",
    "shadowAuthoritative",
    "failureResponse",
    "receiptAfterFailure",
    "inFlightDirect",
    "revokeRequestBuilt",
    "revokeEntry",
    "revokeRequestCopied",
    "revokeValidated",
    "revokeReplayConsumed",
    "revokeStarted",
    "newReceiptEmbargoed",
    "inFlightDrained",
    "derivedReceiptsRevoked",
    "shadowInvalidated",
    "revokeComplete",
    "badValidateLinuxMutable",
    "badSuccessWithoutEntry",
    "badLedgerWithoutCopyValidation",
    "badLedgerBeforeReplay",
    "badLinuxLedgerWrite",
    "badResponseWithoutLedger",
    "badShadowFromRequest",
    "badShadowAuthority",
    "badFailureThenReceipt",
    "badRevokeWithoutEmbargo",
    "badRevokeWithInFlight",
    "badRevokeBeforeDerivedShadow"
}

BoolFields == StateFields \ {"phase"}

TerminalPhases == {
    "FailureResponse",
    "RevokeComplete",
    "BadValidateLinuxMutable",
    "BadSuccessWithoutEntry",
    "BadLedgerWithoutCopyValidation",
    "BadLedgerBeforeReplay",
    "BadLinuxLedgerWrite",
    "BadResponseWithoutLedger",
    "BadShadowFromRequest",
    "BadShadowAuthority",
    "BadFailureThenReceipt",
    "BadRevokeWithoutEmbargo",
    "BadRevokeWithInFlight",
    "BadRevokeBeforeDerivedShadow"
}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        linuxRequestBuilt |-> FALSE,
        monitorEntry |-> FALSE,
        requestCopied |-> FALSE,
        linuxMutableValidated |-> FALSE,
        requestValidated |-> FALSE,
        replayConsumed |-> FALSE,
        successLedgerWritten |-> FALSE,
        linuxLedgerWrite |-> FALSE,
        responseHandleMinted |-> FALSE,
        shadowRefreshed |-> FALSE,
        shadowFromHandle |-> FALSE,
        shadowFromRequest |-> FALSE,
        shadowAuthoritative |-> FALSE,
        failureResponse |-> FALSE,
        receiptAfterFailure |-> FALSE,
        inFlightDirect |-> FALSE,
        revokeRequestBuilt |-> FALSE,
        revokeEntry |-> FALSE,
        revokeRequestCopied |-> FALSE,
        revokeValidated |-> FALSE,
        revokeReplayConsumed |-> FALSE,
        revokeStarted |-> FALSE,
        newReceiptEmbargoed |-> FALSE,
        inFlightDrained |-> FALSE,
        derivedReceiptsRevoked |-> FALSE,
        shadowInvalidated |-> FALSE,
        revokeComplete |-> FALSE,
        badValidateLinuxMutable |-> FALSE,
        badSuccessWithoutEntry |-> FALSE,
        badLedgerWithoutCopyValidation |-> FALSE,
        badLedgerBeforeReplay |-> FALSE,
        badLinuxLedgerWrite |-> FALSE,
        badResponseWithoutLedger |-> FALSE,
        badShadowFromRequest |-> FALSE,
        badShadowAuthority |-> FALSE,
        badFailureThenReceipt |-> FALSE,
        badRevokeWithoutEmbargo |-> FALSE,
        badRevokeWithInFlight |-> FALSE,
        badRevokeBeforeDerivedShadow |-> FALSE
    ]

BuildLinuxRequest ==
    /\ state.phase = "Start"
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
            !.inFlightDirect = TRUE
        ]

CopyRequest ==
    /\ state.phase = "MonitorEntered"
    /\ state.monitorEntry
    /\ state' =
        [state EXCEPT
            !.phase = "RequestCopied",
            !.requestCopied = TRUE
        ]

ValidateCopiedRequest ==
    /\ state.phase = "RequestCopied"
    /\ state.requestCopied
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

WriteSuccessLedger ==
    /\ state.phase = "ReplayConsumed"
    /\ state.monitorEntry
    /\ state.requestCopied
    /\ state.requestValidated
    /\ state.replayConsumed
    /\ state' =
        [state EXCEPT
            !.phase = "SuccessLedgerWritten",
            !.successLedgerWritten = TRUE
        ]

MintResponseHandle ==
    /\ state.phase = "SuccessLedgerWritten"
    /\ state.successLedgerWritten
    /\ state' =
        [state EXCEPT
            !.phase = "ResponseHandleMinted",
            !.responseHandleMinted = TRUE,
            !.inFlightDirect = FALSE
        ]

RefreshShadowFromHandle ==
    /\ state.phase = "ResponseHandleMinted"
    /\ state.responseHandleMinted
    /\ state.successLedgerWritten
    /\ state' =
        [state EXCEPT
            !.phase = "ShadowRefreshed",
            !.shadowRefreshed = TRUE,
            !.shadowFromHandle = TRUE
        ]

MintFailureResponse ==
    /\ state.phase = "RequestValidated"
    /\ state.requestValidated
    /\ state' =
        [state EXCEPT
            !.phase = "FailureResponse",
            !.failureResponse = TRUE,
            !.inFlightDirect = FALSE
        ]

BuildRevokeRequest ==
    /\ state.phase = "ShadowRefreshed"
    /\ state.shadowFromHandle
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeRequestBuilt",
            !.revokeRequestBuilt = TRUE
        ]

EnterRevoke ==
    /\ state.phase = "RevokeRequestBuilt"
    /\ state.revokeRequestBuilt
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeEntered",
            !.revokeEntry = TRUE,
            !.inFlightDirect = TRUE
        ]

CopyRevokeRequest ==
    /\ state.phase = "RevokeEntered"
    /\ state.revokeEntry
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeRequestCopied",
            !.revokeRequestCopied = TRUE
        ]

ValidateRevokeRequest ==
    /\ state.phase = "RevokeRequestCopied"
    /\ state.revokeRequestCopied
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeValidated",
            !.revokeValidated = TRUE
        ]

ConsumeRevokeReplay ==
    /\ state.phase = "RevokeValidated"
    /\ state.revokeValidated
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeReplayConsumed",
            !.revokeReplayConsumed = TRUE
        ]

StartRevoke ==
    /\ state.phase = "RevokeReplayConsumed"
    /\ state.revokeReplayConsumed
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

DrainInFlightDirectCalls ==
    /\ state.phase = "NewReceiptEmbargoed"
    /\ state.newReceiptEmbargoed
    /\ state' =
        [state EXCEPT
            !.phase = "InFlightDrained",
            !.inFlightDirect = FALSE,
            !.inFlightDrained = TRUE
        ]

RevokeDerivedReceipts ==
    /\ state.phase = "InFlightDrained"
    /\ state.inFlightDrained
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
    /\ state.newReceiptEmbargoed
    /\ state.inFlightDrained
    /\ state.derivedReceiptsRevoked
    /\ state.shadowInvalidated
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeComplete",
            !.revokeComplete = TRUE
        ]

UnsafeValidateLinuxMutable ==
    /\ ALLOW_UNSAFE_VALIDATE_LINUX_MUTABLE
    /\ state.phase = "MonitorEntered"
    /\ state' =
        [state EXCEPT
            !.phase = "BadValidateLinuxMutable",
            !.linuxMutableValidated = TRUE,
            !.requestValidated = TRUE,
            !.badValidateLinuxMutable = TRUE
        ]

UnsafeSuccessWithoutEntry ==
    /\ ALLOW_UNSAFE_SUCCESS_WITHOUT_ENTRY
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "BadSuccessWithoutEntry",
            !.successLedgerWritten = TRUE,
            !.responseHandleMinted = TRUE,
            !.badSuccessWithoutEntry = TRUE
        ]

UnsafeLedgerWithoutCopyValidation ==
    /\ ALLOW_UNSAFE_LEDGER_WITHOUT_COPY_VALIDATION
    /\ state.phase \in {"MonitorEntered", "RequestCopied"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadLedgerWithoutCopyValidation",
            !.successLedgerWritten = TRUE,
            !.badLedgerWithoutCopyValidation = TRUE
        ]

UnsafeLedgerBeforeReplay ==
    /\ ALLOW_UNSAFE_LEDGER_BEFORE_REPLAY
    /\ state.phase = "RequestValidated"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLedgerBeforeReplay",
            !.successLedgerWritten = TRUE,
            !.badLedgerBeforeReplay = TRUE
        ]

UnsafeLinuxLedgerWrite ==
    /\ ALLOW_UNSAFE_LINUX_LEDGER_WRITE
    /\ state.phase \in {"LinuxRequestBuilt", "MonitorEntered",
        "RequestCopied", "RequestValidated"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxLedgerWrite",
            !.linuxLedgerWrite = TRUE,
            !.successLedgerWritten = TRUE,
            !.badLinuxLedgerWrite = TRUE
        ]

UnsafeResponseWithoutLedger ==
    /\ ALLOW_UNSAFE_RESPONSE_WITHOUT_LEDGER
    /\ state.phase \in {"MonitorEntered", "RequestCopied", "RequestValidated"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadResponseWithoutLedger",
            !.responseHandleMinted = TRUE,
            !.badResponseWithoutLedger = TRUE
        ]

UnsafeShadowFromRequest ==
    /\ ALLOW_UNSAFE_SHADOW_FROM_REQUEST
    /\ state.phase \in {"LinuxRequestBuilt", "MonitorEntered", "RequestCopied"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadShadowFromRequest",
            !.shadowRefreshed = TRUE,
            !.shadowFromRequest = TRUE,
            !.badShadowFromRequest = TRUE
        ]

UnsafeShadowAuthority ==
    /\ ALLOW_UNSAFE_SHADOW_AUTHORITY
    /\ state.phase \in {"ResponseHandleMinted", "ShadowRefreshed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadShadowAuthority",
            !.shadowRefreshed = TRUE,
            !.shadowAuthoritative = TRUE,
            !.badShadowAuthority = TRUE
        ]

UnsafeFailureThenReceipt ==
    /\ ALLOW_UNSAFE_FAILURE_THEN_RECEIPT
    /\ state.phase = "FailureResponse"
    /\ state' =
        [state EXCEPT
            !.phase = "BadFailureThenReceipt",
            !.receiptAfterFailure = TRUE,
            !.successLedgerWritten = TRUE,
            !.badFailureThenReceipt = TRUE
        ]

UnsafeRevokeWithoutEmbargo ==
    /\ ALLOW_UNSAFE_REVOKE_WITHOUT_EMBARGO
    /\ state.phase \in {"RevokeStarted", "RevokeReplayConsumed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadRevokeWithoutEmbargo",
            !.revokeComplete = TRUE,
            !.badRevokeWithoutEmbargo = TRUE
        ]

UnsafeRevokeWithInFlight ==
    /\ ALLOW_UNSAFE_REVOKE_WITH_INFLIGHT
    /\ state.phase \in {"RevokeStarted", "NewReceiptEmbargoed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadRevokeWithInFlight",
            !.inFlightDirect = TRUE,
            !.revokeComplete = TRUE,
            !.badRevokeWithInFlight = TRUE
        ]

UnsafeRevokeBeforeDerivedShadow ==
    /\ ALLOW_UNSAFE_REVOKE_BEFORE_DERIVED_SHADOW
    /\ state.phase \in {"NewReceiptEmbargoed", "InFlightDrained",
        "DerivedReceiptsRevoked"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadRevokeBeforeDerivedShadow",
            !.revokeComplete = TRUE,
            !.badRevokeBeforeDerivedShadow = TRUE
        ]

StutterAtTerminal ==
    /\ state.phase \in TerminalPhases
    /\ UNCHANGED state

Next ==
    \/ BuildLinuxRequest
    \/ EnterMonitor
    \/ CopyRequest
    \/ ValidateCopiedRequest
    \/ ConsumeReplay
    \/ WriteSuccessLedger
    \/ MintResponseHandle
    \/ RefreshShadowFromHandle
    \/ MintFailureResponse
    \/ BuildRevokeRequest
    \/ EnterRevoke
    \/ CopyRevokeRequest
    \/ ValidateRevokeRequest
    \/ ConsumeRevokeReplay
    \/ StartRevoke
    \/ EmbargoNewReceipts
    \/ DrainInFlightDirectCalls
    \/ RevokeDerivedReceipts
    \/ InvalidateShadow
    \/ CompleteRevoke
    \/ UnsafeValidateLinuxMutable
    \/ UnsafeSuccessWithoutEntry
    \/ UnsafeLedgerWithoutCopyValidation
    \/ UnsafeLedgerBeforeReplay
    \/ UnsafeLinuxLedgerWrite
    \/ UnsafeResponseWithoutLedger
    \/ UnsafeShadowFromRequest
    \/ UnsafeShadowAuthority
    \/ UnsafeFailureThenReceipt
    \/ UnsafeRevokeWithoutEmbargo
    \/ UnsafeRevokeWithInFlight
    \/ UnsafeRevokeBeforeDerivedShadow
    \/ StutterAtTerminal

NoValidationFromLinuxMutableRequest ==
    ~state.linuxMutableValidated

ValidationRequiresCopiedRequest ==
    state.requestValidated => state.requestCopied

SuccessRequiresMonitorEntry ==
    state.successLedgerWritten => state.monitorEntry

SuccessLedgerRequiresCopiedValidation ==
    state.successLedgerWritten => (state.requestCopied /\ state.requestValidated)

SuccessLedgerRequiresReplayConsume ==
    state.successLedgerWritten => state.replayConsumed

NoLinuxLedgerWrite ==
    ~state.linuxLedgerWrite

ResponseHandleRequiresLedger ==
    state.responseHandleMinted => state.successLedgerWritten

ShadowRefreshRequiresHandle ==
    state.shadowRefreshed => (state.shadowFromHandle /\ state.responseHandleMinted)

NoShadowFromRequest ==
    ~state.shadowFromRequest

LinuxShadowIsNotAuthority ==
    ~state.shadowAuthoritative

NoReceiptAfterFailure ==
    ~state.receiptAfterFailure

RevokeCompleteRequiresEmbargo ==
    state.revokeComplete => state.newReceiptEmbargoed

RevokeCompleteRequiresInFlightDrain ==
    state.revokeComplete => (state.inFlightDrained /\ ~state.inFlightDirect)

RevokeCompleteRequiresDerivedAndShadow ==
    state.revokeComplete => (state.derivedReceiptsRevoked /\
        state.shadowInvalidated)

NoBadValidateLinuxMutable == ~state.badValidateLinuxMutable
NoBadSuccessWithoutEntry == ~state.badSuccessWithoutEntry
NoBadLedgerWithoutCopyValidation == ~state.badLedgerWithoutCopyValidation
NoBadLedgerBeforeReplay == ~state.badLedgerBeforeReplay
NoBadLinuxLedgerWrite == ~state.badLinuxLedgerWrite
NoBadResponseWithoutLedger == ~state.badResponseWithoutLedger
NoBadShadowFromRequest == ~state.badShadowFromRequest
NoBadShadowAuthority == ~state.badShadowAuthority
NoBadFailureThenReceipt == ~state.badFailureThenReceipt
NoBadRevokeWithoutEmbargo == ~state.badRevokeWithoutEmbargo
NoBadRevokeWithInFlight == ~state.badRevokeWithInFlight
NoBadRevokeBeforeDerivedShadow == ~state.badRevokeBeforeDerivedShadow

=============================================================================
