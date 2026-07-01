----------------- MODULE DirectCallReceiptConsumerPlacement -----------------

CONSTANTS
    ALLOW_UNSAFE_LINUX_MINTED_RECEIPT,
    ALLOW_UNSAFE_SHADOW_AUTHORITY,
    ALLOW_UNSAFE_HOT_PATH_DIRECT_CALL,
    ALLOW_UNSAFE_POLICY_SCHEMA_AUTHORITY,
    ALLOW_UNSAFE_GENERIC_ASYNC_CONSUME,
    ALLOW_UNSAFE_FUTURE_GAP_IMPLEMENTED,
    ALLOW_UNSAFE_CONSUME_AFTER_REVOKE,
    ALLOW_UNSAFE_TRACE_PLAN_COVERAGE,
    ALLOW_UNSAFE_ABI_APPROVAL,
    ALLOW_UNSAFE_BEHAVIOR_CHANGE,
    ALLOW_UNSAFE_MONITOR_VERIFIED,
    ALLOW_UNSAFE_PROTECTION_CLAIM

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "SourceMapAccepted",
    "MonitorReceiptsBound",
    "LinuxShadowDerived",
    "HotPathBounded",
    "PolicyLifecycleSeparated",
    "GenericAsyncExcluded",
    "RevokeObserved",
    "PlacementDesignAccepted",
    "BadLinuxMintedReceipt",
    "BadShadowAuthority",
    "BadHotPathDirectCall",
    "BadPolicySchemaAuthority",
    "BadGenericAsyncConsume",
    "BadFutureGapImplemented",
    "BadConsumeAfterRevoke",
    "BadTracePlanCoverage",
    "BadAbiApproval",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

StateFields == {
    "phase",
    "sourceMapAccepted",
    "currentAnchorsObserved",
    "futureGapsPreserved",
    "monitorOwnsReceipts",
    "linuxMintedReceipt",
    "linuxShadowDerived",
    "linuxShadowAuthority",
    "hotPathBoundedCheck",
    "hotPathDirectCall",
    "policyLifecycleSeparated",
    "policySchemaAuthority",
    "genericAsyncExcluded",
    "genericAsyncConsumesReceipt",
    "typedCarrierRequired",
    "futureGapImplemented",
    "revokeReceiptMonitorOwned",
    "shadowInvalidated",
    "staleConsumeAfterRevoke",
    "traceCoverageClaim",
    "abiApproved",
    "behaviorChange",
    "monitorVerified",
    "protectionClaim",
    "placementDesignAccepted",
    "badLinuxMintedReceipt",
    "badShadowAuthority",
    "badHotPathDirectCall",
    "badPolicySchemaAuthority",
    "badGenericAsyncConsume",
    "badFutureGapImplemented",
    "badConsumeAfterRevoke",
    "badTracePlanCoverage",
    "badAbiApproval",
    "badBehaviorChange",
    "badMonitorVerified",
    "badProtectionClaim"
}

BoolFields == StateFields \ {"phase"}

TerminalPhases == {
    "PlacementDesignAccepted",
    "BadLinuxMintedReceipt",
    "BadShadowAuthority",
    "BadHotPathDirectCall",
    "BadPolicySchemaAuthority",
    "BadGenericAsyncConsume",
    "BadFutureGapImplemented",
    "BadConsumeAfterRevoke",
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

SourceMapReady ==
    /\ state.sourceMapAccepted
    /\ state.currentAnchorsObserved
    /\ state.futureGapsPreserved

LinuxMayConsumeOpaqueShadow ==
    /\ SourceMapReady
    /\ state.monitorOwnsReceipts
    /\ state.linuxShadowDerived
    /\ ~state.linuxShadowAuthority
    /\ ~state.linuxMintedReceipt

PlacementSafe ==
    /\ SourceMapReady
    /\ state.monitorOwnsReceipts
    /\ state.linuxShadowDerived
    /\ state.hotPathBoundedCheck
    /\ state.policyLifecycleSeparated
    /\ state.genericAsyncExcluded
    /\ state.typedCarrierRequired
    /\ state.revokeReceiptMonitorOwned
    /\ state.shadowInvalidated
    /\ ~state.linuxMintedReceipt
    /\ ~state.linuxShadowAuthority
    /\ ~state.hotPathDirectCall
    /\ ~state.policySchemaAuthority
    /\ ~state.genericAsyncConsumesReceipt
    /\ ~state.futureGapImplemented
    /\ ~state.staleConsumeAfterRevoke
    /\ ~state.traceCoverageClaim
    /\ ~state.abiApproved
    /\ ~state.behaviorChange
    /\ ~state.monitorVerified
    /\ ~state.protectionClaim

Init ==
    state = [
        phase |-> "Start",
        sourceMapAccepted |-> FALSE,
        currentAnchorsObserved |-> FALSE,
        futureGapsPreserved |-> FALSE,
        monitorOwnsReceipts |-> FALSE,
        linuxMintedReceipt |-> FALSE,
        linuxShadowDerived |-> FALSE,
        linuxShadowAuthority |-> FALSE,
        hotPathBoundedCheck |-> FALSE,
        hotPathDirectCall |-> FALSE,
        policyLifecycleSeparated |-> FALSE,
        policySchemaAuthority |-> FALSE,
        genericAsyncExcluded |-> FALSE,
        genericAsyncConsumesReceipt |-> FALSE,
        typedCarrierRequired |-> FALSE,
        futureGapImplemented |-> FALSE,
        revokeReceiptMonitorOwned |-> FALSE,
        shadowInvalidated |-> FALSE,
        staleConsumeAfterRevoke |-> FALSE,
        traceCoverageClaim |-> FALSE,
        abiApproved |-> FALSE,
        behaviorChange |-> FALSE,
        monitorVerified |-> FALSE,
        protectionClaim |-> FALSE,
        placementDesignAccepted |-> FALSE,
        badLinuxMintedReceipt |-> FALSE,
        badShadowAuthority |-> FALSE,
        badHotPathDirectCall |-> FALSE,
        badPolicySchemaAuthority |-> FALSE,
        badGenericAsyncConsume |-> FALSE,
        badFutureGapImplemented |-> FALSE,
        badConsumeAfterRevoke |-> FALSE,
        badTracePlanCoverage |-> FALSE,
        badAbiApproval |-> FALSE,
        badBehaviorChange |-> FALSE,
        badMonitorVerified |-> FALSE,
        badProtectionClaim |-> FALSE
    ]

AcceptSourceMap ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "SourceMapAccepted",
            !.sourceMapAccepted = TRUE,
            !.currentAnchorsObserved = TRUE,
            !.futureGapsPreserved = TRUE
        ]

BindMonitorReceipts ==
    /\ state.phase = "SourceMapAccepted"
    /\ SourceMapReady
    /\ state' =
        [state EXCEPT
            !.phase = "MonitorReceiptsBound",
            !.monitorOwnsReceipts = TRUE
        ]

DeriveLinuxShadow ==
    /\ state.phase = "MonitorReceiptsBound"
    /\ state.monitorOwnsReceipts
    /\ ~state.linuxShadowAuthority
    /\ state' =
        [state EXCEPT
            !.phase = "LinuxShadowDerived",
            !.linuxShadowDerived = TRUE
        ]

BoundHotPathCheck ==
    /\ state.phase = "LinuxShadowDerived"
    /\ LinuxMayConsumeOpaqueShadow
    /\ ~state.hotPathDirectCall
    /\ state' =
        [state EXCEPT
            !.phase = "HotPathBounded",
            !.hotPathBoundedCheck = TRUE
        ]

SeparatePolicyLifecycle ==
    /\ state.phase = "HotPathBounded"
    /\ state.hotPathBoundedCheck
    /\ ~state.policySchemaAuthority
    /\ state' =
        [state EXCEPT
            !.phase = "PolicyLifecycleSeparated",
            !.policyLifecycleSeparated = TRUE
        ]

ExcludeGenericAsync ==
    /\ state.phase = "PolicyLifecycleSeparated"
    /\ state.policyLifecycleSeparated
    /\ ~state.genericAsyncConsumesReceipt
    /\ state' =
        [state EXCEPT
            !.phase = "GenericAsyncExcluded",
            !.genericAsyncExcluded = TRUE,
            !.typedCarrierRequired = TRUE
        ]

MonitorRevoke ==
    /\ state.phase = "GenericAsyncExcluded"
    /\ state.genericAsyncExcluded
    /\ state.typedCarrierRequired
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeObserved",
            !.revokeReceiptMonitorOwned = TRUE,
            !.shadowInvalidated = TRUE
        ]

AcceptPlacementDesign ==
    /\ state.phase = "RevokeObserved"
    /\ PlacementSafe
    /\ state' =
        [state EXCEPT
            !.phase = "PlacementDesignAccepted",
            !.placementDesignAccepted = TRUE
        ]

UnsafeLinuxMintedReceipt ==
    /\ ALLOW_UNSAFE_LINUX_MINTED_RECEIPT
    /\ state.phase = "SourceMapAccepted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxMintedReceipt",
            !.linuxMintedReceipt = TRUE,
            !.badLinuxMintedReceipt = TRUE
        ]

UnsafeShadowAuthority ==
    /\ ALLOW_UNSAFE_SHADOW_AUTHORITY
    /\ state.phase = "LinuxShadowDerived"
    /\ state' =
        [state EXCEPT
            !.phase = "BadShadowAuthority",
            !.linuxShadowAuthority = TRUE,
            !.badShadowAuthority = TRUE
        ]

UnsafeHotPathDirectCall ==
    /\ ALLOW_UNSAFE_HOT_PATH_DIRECT_CALL
    /\ state.phase = "LinuxShadowDerived"
    /\ state' =
        [state EXCEPT
            !.phase = "BadHotPathDirectCall",
            !.hotPathDirectCall = TRUE,
            !.badHotPathDirectCall = TRUE
        ]

UnsafePolicySchemaAuthority ==
    /\ ALLOW_UNSAFE_POLICY_SCHEMA_AUTHORITY
    /\ state.phase = "HotPathBounded"
    /\ state' =
        [state EXCEPT
            !.phase = "BadPolicySchemaAuthority",
            !.policySchemaAuthority = TRUE,
            !.badPolicySchemaAuthority = TRUE
        ]

UnsafeGenericAsyncConsume ==
    /\ ALLOW_UNSAFE_GENERIC_ASYNC_CONSUME
    /\ state.phase = "PolicyLifecycleSeparated"
    /\ state' =
        [state EXCEPT
            !.phase = "BadGenericAsyncConsume",
            !.genericAsyncConsumesReceipt = TRUE,
            !.badGenericAsyncConsume = TRUE
        ]

UnsafeFutureGapImplemented ==
    /\ ALLOW_UNSAFE_FUTURE_GAP_IMPLEMENTED
    /\ state.phase = "SourceMapAccepted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadFutureGapImplemented",
            !.futureGapImplemented = TRUE,
            !.badFutureGapImplemented = TRUE
        ]

UnsafeConsumeAfterRevoke ==
    /\ ALLOW_UNSAFE_CONSUME_AFTER_REVOKE
    /\ state.phase = "RevokeObserved"
    /\ state.shadowInvalidated
    /\ state' =
        [state EXCEPT
            !.phase = "BadConsumeAfterRevoke",
            !.staleConsumeAfterRevoke = TRUE,
            !.badConsumeAfterRevoke = TRUE
        ]

UnsafeTracePlanCoverage ==
    /\ ALLOW_UNSAFE_TRACE_PLAN_COVERAGE
    /\ state.phase = "SourceMapAccepted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadTracePlanCoverage",
            !.traceCoverageClaim = TRUE,
            !.badTracePlanCoverage = TRUE
        ]

UnsafeAbiApproval ==
    /\ ALLOW_UNSAFE_ABI_APPROVAL
    /\ state.phase = "SourceMapAccepted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadAbiApproval",
            !.abiApproved = TRUE,
            !.badAbiApproval = TRUE
        ]

UnsafeBehaviorChange ==
    /\ ALLOW_UNSAFE_BEHAVIOR_CHANGE
    /\ state.phase = "SourceMapAccepted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadBehaviorChange",
            !.behaviorChange = TRUE,
            !.badBehaviorChange = TRUE
        ]

UnsafeMonitorVerified ==
    /\ ALLOW_UNSAFE_MONITOR_VERIFIED
    /\ state.phase = "SourceMapAccepted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadMonitorVerified",
            !.monitorVerified = TRUE,
            !.badMonitorVerified = TRUE
        ]

UnsafeProtectionClaim ==
    /\ ALLOW_UNSAFE_PROTECTION_CLAIM
    /\ state.phase = "SourceMapAccepted"
    /\ state' =
        [state EXCEPT
            !.phase = "BadProtectionClaim",
            !.protectionClaim = TRUE,
            !.badProtectionClaim = TRUE
        ]

Next ==
    IF state.phase \in TerminalPhases
    THEN UNCHANGED vars
    ELSE
        \/ AcceptSourceMap
        \/ BindMonitorReceipts
        \/ DeriveLinuxShadow
        \/ BoundHotPathCheck
        \/ SeparatePolicyLifecycle
        \/ ExcludeGenericAsync
        \/ MonitorRevoke
        \/ AcceptPlacementDesign
        \/ UnsafeLinuxMintedReceipt
        \/ UnsafeShadowAuthority
        \/ UnsafeHotPathDirectCall
        \/ UnsafePolicySchemaAuthority
        \/ UnsafeGenericAsyncConsume
        \/ UnsafeFutureGapImplemented
        \/ UnsafeConsumeAfterRevoke
        \/ UnsafeTracePlanCoverage
        \/ UnsafeAbiApproval
        \/ UnsafeBehaviorChange
        \/ UnsafeMonitorVerified
        \/ UnsafeProtectionClaim

AcceptedPlacementRequiresSafePlacement ==
    state.placementDesignAccepted => PlacementSafe

NoLinuxMintedReceipt == ~state.linuxMintedReceipt
LinuxShadowIsNotAuthority == ~state.linuxShadowAuthority
HotPathOnlyBoundedCheck == ~state.hotPathDirectCall
PolicyLifecycleNotSchemaAuthority == ~state.policySchemaAuthority
GenericAsyncExcluded == ~state.genericAsyncConsumesReceipt
FutureGapsNotImplemented == ~state.futureGapImplemented
NoConsumeAfterRevoke == ~state.staleConsumeAfterRevoke
NoTraceCoverageClaim == ~state.traceCoverageClaim
NoAbiApproval == ~state.abiApproved
NoBehaviorChange == ~state.behaviorChange
NoMonitorVerifiedClaim == ~state.monitorVerified
NoProtectionClaim == ~state.protectionClaim

NoBadLinuxMintedReceipt == ~state.badLinuxMintedReceipt
NoBadShadowAuthority == ~state.badShadowAuthority
NoBadHotPathDirectCall == ~state.badHotPathDirectCall
NoBadPolicySchemaAuthority == ~state.badPolicySchemaAuthority
NoBadGenericAsyncConsume == ~state.badGenericAsyncConsume
NoBadFutureGapImplemented == ~state.badFutureGapImplemented
NoBadConsumeAfterRevoke == ~state.badConsumeAfterRevoke
NoBadTracePlanCoverage == ~state.badTracePlanCoverage
NoBadAbiApproval == ~state.badAbiApproval
NoBadBehaviorChange == ~state.badBehaviorChange
NoBadMonitorVerified == ~state.badMonitorVerified
NoBadProtectionClaim == ~state.badProtectionClaim

=============================================================================

