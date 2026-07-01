----------------------- MODULE DirectCallReceiptSchema -----------------------

CONSTANTS
    ALLOW_UNSAFE_LINUX_MINTED_RECEIPT,
    ALLOW_UNSAFE_LINUX_SCHEMA_ACCEPT,
    ALLOW_UNSAFE_WRAPPER_RETURN_RECEIPT,
    ALLOW_UNSAFE_TIMEOUT_SHADOW_REFRESH,
    ALLOW_UNSAFE_SHADOW_AUTHORITY,
    ALLOW_UNSAFE_RESPONSE_DURING_REVOKE,
    ALLOW_UNSAFE_REVOKE_WITH_INFLIGHT,
    ALLOW_UNSAFE_TRACE_PLAN_COVERAGE,
    ALLOW_UNSAFE_ABI_APPROVAL,
    ALLOW_UNSAFE_BEHAVIOR_CHANGE,
    ALLOW_UNSAFE_MONITOR_VERIFIED,
    ALLOW_UNSAFE_PROTECTION_CLAIM

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "RequestCopied",
    "SchemaAccepted",
    "EntryResultIssued",
    "ResponseMinted",
    "ShadowDerived",
    "RevokeStarted",
    "RevokeCompleted",
    "SchemaDesignAccepted",
    "BadLinuxMintedReceipt",
    "BadLinuxSchemaAccept",
    "BadWrapperReturnReceipt",
    "BadTimeoutShadowRefresh",
    "BadShadowAuthority",
    "BadResponseDuringRevoke",
    "BadRevokeWithInFlight",
    "BadTracePlanCoverage",
    "BadAbiApproval",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

StateFields == {
    "phase",
    "requestCopiedByMonitor",
    "requestDigestBound",
    "replayKeyBound",
    "domainEpochBound",
    "schemaAcceptedByMonitor",
    "criticalFieldsChecked",
    "entryResultMintedByMonitor",
    "replayConsumed",
    "responseHandleMintedByMonitor",
    "responseGenerationBound",
    "linuxShadowDerived",
    "linuxShadowAuthority",
    "revokeAcceptedByMonitor",
    "revokeCompletedByMonitor",
    "shadowInvalidatedByMonitor",
    "inFlightResponse",
    "revokeInProgress",
    "linuxMintedReceipt",
    "linuxSchemaAccept",
    "wrapperReturnReceipt",
    "timeoutShadowRefresh",
    "responseDuringRevoke",
    "revokeCompleteWithInFlight",
    "traceCoverageClaim",
    "abiApproved",
    "behaviorChange",
    "monitorVerified",
    "protectionClaim",
    "schemaDesignAccepted",
    "badLinuxMintedReceipt",
    "badLinuxSchemaAccept",
    "badWrapperReturnReceipt",
    "badTimeoutShadowRefresh",
    "badShadowAuthority",
    "badResponseDuringRevoke",
    "badRevokeWithInFlight",
    "badTracePlanCoverage",
    "badAbiApproval",
    "badBehaviorChange",
    "badMonitorVerified",
    "badProtectionClaim"
}

BoolFields == StateFields \ {"phase"}

TerminalPhases == {
    "SchemaDesignAccepted",
    "BadLinuxMintedReceipt",
    "BadLinuxSchemaAccept",
    "BadWrapperReturnReceipt",
    "BadTimeoutShadowRefresh",
    "BadShadowAuthority",
    "BadResponseDuringRevoke",
    "BadRevokeWithInFlight",
    "BadTracePlanCoverage",
    "BadAbiApproval",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

MonitorRequestReceipt ==
    /\ state.requestCopiedByMonitor
    /\ state.requestDigestBound
    /\ state.replayKeyBound
    /\ state.domainEpochBound

MonitorSchemaReceipt ==
    /\ state.schemaAcceptedByMonitor
    /\ state.criticalFieldsChecked

MonitorEntryReceipt ==
    /\ state.entryResultMintedByMonitor
    /\ state.replayConsumed

MonitorResponseReceipt ==
    /\ state.responseHandleMintedByMonitor
    /\ state.responseGenerationBound
    /\ state.domainEpochBound

MonitorRevokeReceipt ==
    /\ state.revokeAcceptedByMonitor
    /\ state.revokeCompletedByMonitor
    /\ state.shadowInvalidatedByMonitor
    /\ ~state.inFlightResponse

Init ==
    state = [
        phase |-> "Start",
        requestCopiedByMonitor |-> FALSE,
        requestDigestBound |-> FALSE,
        replayKeyBound |-> FALSE,
        domainEpochBound |-> FALSE,
        schemaAcceptedByMonitor |-> FALSE,
        criticalFieldsChecked |-> FALSE,
        entryResultMintedByMonitor |-> FALSE,
        replayConsumed |-> FALSE,
        responseHandleMintedByMonitor |-> FALSE,
        responseGenerationBound |-> FALSE,
        linuxShadowDerived |-> FALSE,
        linuxShadowAuthority |-> FALSE,
        revokeAcceptedByMonitor |-> FALSE,
        revokeCompletedByMonitor |-> FALSE,
        shadowInvalidatedByMonitor |-> FALSE,
        inFlightResponse |-> FALSE,
        revokeInProgress |-> FALSE,
        linuxMintedReceipt |-> FALSE,
        linuxSchemaAccept |-> FALSE,
        wrapperReturnReceipt |-> FALSE,
        timeoutShadowRefresh |-> FALSE,
        responseDuringRevoke |-> FALSE,
        revokeCompleteWithInFlight |-> FALSE,
        traceCoverageClaim |-> FALSE,
        abiApproved |-> FALSE,
        behaviorChange |-> FALSE,
        monitorVerified |-> FALSE,
        protectionClaim |-> FALSE,
        schemaDesignAccepted |-> FALSE,
        badLinuxMintedReceipt |-> FALSE,
        badLinuxSchemaAccept |-> FALSE,
        badWrapperReturnReceipt |-> FALSE,
        badTimeoutShadowRefresh |-> FALSE,
        badShadowAuthority |-> FALSE,
        badResponseDuringRevoke |-> FALSE,
        badRevokeWithInFlight |-> FALSE,
        badTracePlanCoverage |-> FALSE,
        badAbiApproval |-> FALSE,
        badBehaviorChange |-> FALSE,
        badMonitorVerified |-> FALSE,
        badProtectionClaim |-> FALSE
    ]

MonitorCopyRequest ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "RequestCopied",
            !.requestCopiedByMonitor = TRUE,
            !.requestDigestBound = TRUE,
            !.replayKeyBound = TRUE,
            !.domainEpochBound = TRUE
        ]

MonitorAcceptSchema ==
    /\ state.phase = "RequestCopied"
    /\ MonitorRequestReceipt
    /\ state' =
        [state EXCEPT
            !.phase = "SchemaAccepted",
            !.schemaAcceptedByMonitor = TRUE,
            !.criticalFieldsChecked = TRUE
        ]

MonitorIssueEntryResult ==
    /\ state.phase = "SchemaAccepted"
    /\ MonitorRequestReceipt
    /\ MonitorSchemaReceipt
    /\ state' =
        [state EXCEPT
            !.phase = "EntryResultIssued",
            !.entryResultMintedByMonitor = TRUE,
            !.replayConsumed = TRUE
        ]

MonitorMintResponse ==
    /\ state.phase = "EntryResultIssued"
    /\ MonitorEntryReceipt
    /\ ~state.revokeInProgress
    /\ state' =
        [state EXCEPT
            !.phase = "ResponseMinted",
            !.responseHandleMintedByMonitor = TRUE,
            !.responseGenerationBound = TRUE,
            !.inFlightResponse = TRUE
        ]

LinuxDeriveShadow ==
    /\ state.phase = "ResponseMinted"
    /\ MonitorResponseReceipt
    /\ ~state.linuxShadowAuthority
    /\ state' =
        [state EXCEPT
            !.phase = "ShadowDerived",
            !.linuxShadowDerived = TRUE
        ]

MonitorStartRevoke ==
    /\ state.phase = "ShadowDerived"
    /\ state.linuxShadowDerived
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeStarted",
            !.revokeAcceptedByMonitor = TRUE,
            !.revokeInProgress = TRUE
        ]

MonitorCompleteRevoke ==
    /\ state.phase = "RevokeStarted"
    /\ state.revokeAcceptedByMonitor
    /\ state.revokeInProgress
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeCompleted",
            !.revokeCompletedByMonitor = TRUE,
            !.shadowInvalidatedByMonitor = TRUE,
            !.inFlightResponse = FALSE,
            !.revokeInProgress = FALSE
        ]

AcceptSchemaDesign ==
    /\ state.phase = "RevokeCompleted"
    /\ MonitorRequestReceipt
    /\ MonitorSchemaReceipt
    /\ MonitorEntryReceipt
    /\ MonitorResponseReceipt
    /\ MonitorRevokeReceipt
    /\ state.linuxShadowDerived
    /\ ~state.linuxShadowAuthority
    /\ ~state.abiApproved
    /\ ~state.behaviorChange
    /\ ~state.monitorVerified
    /\ ~state.protectionClaim
    /\ state' =
        [state EXCEPT
            !.phase = "SchemaDesignAccepted",
            !.schemaDesignAccepted = TRUE
        ]

UnsafeLinuxMintedReceipt ==
    /\ ALLOW_UNSAFE_LINUX_MINTED_RECEIPT
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxMintedReceipt",
            !.linuxMintedReceipt = TRUE,
            !.badLinuxMintedReceipt = TRUE
        ]

UnsafeLinuxSchemaAccept ==
    /\ ALLOW_UNSAFE_LINUX_SCHEMA_ACCEPT
    /\ state.phase = "RequestCopied"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxSchemaAccept",
            !.linuxSchemaAccept = TRUE,
            !.schemaAcceptedByMonitor = TRUE,
            !.badLinuxSchemaAccept = TRUE
        ]

UnsafeWrapperReturnReceipt ==
    /\ ALLOW_UNSAFE_WRAPPER_RETURN_RECEIPT
    /\ state.phase = "SchemaAccepted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadWrapperReturnReceipt",
            !.wrapperReturnReceipt = TRUE,
            !.entryResultMintedByMonitor = TRUE,
            !.badWrapperReturnReceipt = TRUE
        ]

UnsafeTimeoutShadowRefresh ==
    /\ ALLOW_UNSAFE_TIMEOUT_SHADOW_REFRESH
    /\ state.phase = "ShadowDerived"
    /\ state' =
        [state EXCEPT
            !.phase = "BadTimeoutShadowRefresh",
            !.timeoutShadowRefresh = TRUE,
            !.responseGenerationBound = TRUE,
            !.badTimeoutShadowRefresh = TRUE
        ]

UnsafeShadowAuthority ==
    /\ ALLOW_UNSAFE_SHADOW_AUTHORITY
    /\ state.phase = "ShadowDerived"
    /\ state' =
        [state EXCEPT
            !.phase = "BadShadowAuthority",
            !.linuxShadowAuthority = TRUE,
            !.badShadowAuthority = TRUE
        ]

UnsafeResponseDuringRevoke ==
    /\ ALLOW_UNSAFE_RESPONSE_DURING_REVOKE
    /\ state.phase = "RevokeStarted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadResponseDuringRevoke",
            !.responseDuringRevoke = TRUE,
            !.responseHandleMintedByMonitor = TRUE,
            !.badResponseDuringRevoke = TRUE
        ]

UnsafeRevokeWithInFlight ==
    /\ ALLOW_UNSAFE_REVOKE_WITH_INFLIGHT
    /\ state.phase = "RevokeStarted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRevokeWithInFlight",
            !.revokeCompleteWithInFlight = TRUE,
            !.revokeCompletedByMonitor = TRUE,
            !.inFlightResponse = TRUE,
            !.badRevokeWithInFlight = TRUE
        ]

UnsafeTracePlanCoverage ==
    /\ ALLOW_UNSAFE_TRACE_PLAN_COVERAGE
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "BadTracePlanCoverage",
            !.traceCoverageClaim = TRUE,
            !.badTracePlanCoverage = TRUE
        ]

UnsafeAbiApproval ==
    /\ ALLOW_UNSAFE_ABI_APPROVAL
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "BadAbiApproval",
            !.abiApproved = TRUE,
            !.badAbiApproval = TRUE
        ]

UnsafeBehaviorChange ==
    /\ ALLOW_UNSAFE_BEHAVIOR_CHANGE
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "BadBehaviorChange",
            !.behaviorChange = TRUE,
            !.badBehaviorChange = TRUE
        ]

UnsafeMonitorVerified ==
    /\ ALLOW_UNSAFE_MONITOR_VERIFIED
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "BadMonitorVerified",
            !.monitorVerified = TRUE,
            !.badMonitorVerified = TRUE
        ]

UnsafeProtectionClaim ==
    /\ ALLOW_UNSAFE_PROTECTION_CLAIM
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "BadProtectionClaim",
            !.protectionClaim = TRUE,
            !.badProtectionClaim = TRUE
        ]

StutterAtTerminal ==
    /\ state.phase \in TerminalPhases
    /\ UNCHANGED state

Next ==
    \/ MonitorCopyRequest
    \/ MonitorAcceptSchema
    \/ MonitorIssueEntryResult
    \/ MonitorMintResponse
    \/ LinuxDeriveShadow
    \/ MonitorStartRevoke
    \/ MonitorCompleteRevoke
    \/ AcceptSchemaDesign
    \/ UnsafeLinuxMintedReceipt
    \/ UnsafeLinuxSchemaAccept
    \/ UnsafeWrapperReturnReceipt
    \/ UnsafeTimeoutShadowRefresh
    \/ UnsafeShadowAuthority
    \/ UnsafeResponseDuringRevoke
    \/ UnsafeRevokeWithInFlight
    \/ UnsafeTracePlanCoverage
    \/ UnsafeAbiApproval
    \/ UnsafeBehaviorChange
    \/ UnsafeMonitorVerified
    \/ UnsafeProtectionClaim
    \/ StutterAtTerminal

AcceptedDesignRequiresMonitorReceipts ==
    state.schemaDesignAccepted =>
        (MonitorRequestReceipt /\ MonitorSchemaReceipt /\ MonitorEntryReceipt /\ MonitorResponseReceipt /\ MonitorRevokeReceipt)

LinuxShadowIsNotAuthority ==
    ~state.linuxShadowAuthority

NoLinuxMintedReceipt ==
    ~state.linuxMintedReceipt

NoLinuxSchemaAccept ==
    ~state.linuxSchemaAccept

NoWrapperReturnReceipt ==
    ~state.wrapperReturnReceipt

NoTimeoutShadowRefresh ==
    ~state.timeoutShadowRefresh

NoResponseDuringRevoke ==
    ~state.responseDuringRevoke

NoRevokeCompleteWithInFlight ==
    ~state.revokeCompleteWithInFlight

NoTraceCoverageClaim ==
    ~state.traceCoverageClaim

NoAbiApproval ==
    ~state.abiApproved

NoBehaviorChange ==
    ~state.behaviorChange

NoMonitorVerifiedClaim ==
    ~state.monitorVerified

NoProtectionClaim ==
    ~state.protectionClaim

NoBadLinuxMintedReceipt == ~state.badLinuxMintedReceipt
NoBadLinuxSchemaAccept == ~state.badLinuxSchemaAccept
NoBadWrapperReturnReceipt == ~state.badWrapperReturnReceipt
NoBadTimeoutShadowRefresh == ~state.badTimeoutShadowRefresh
NoBadShadowAuthority == ~state.badShadowAuthority
NoBadResponseDuringRevoke == ~state.badResponseDuringRevoke
NoBadRevokeWithInFlight == ~state.badRevokeWithInFlight
NoBadTracePlanCoverage == ~state.badTracePlanCoverage
NoBadAbiApproval == ~state.badAbiApproval
NoBadBehaviorChange == ~state.badBehaviorChange
NoBadMonitorVerified == ~state.badMonitorVerified
NoBadProtectionClaim == ~state.badProtectionClaim

Spec == Init /\ [][Next]_vars

=============================================================================
