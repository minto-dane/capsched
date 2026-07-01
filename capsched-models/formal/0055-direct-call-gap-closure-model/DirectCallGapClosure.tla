------------------------ MODULE DirectCallGapClosure ------------------------

CONSTANTS
    ALLOW_UNSAFE_STUB_BEFORE_GAPS_CLOSED,
    ALLOW_UNSAFE_LINUX_CANONICAL_ENVELOPE,
    ALLOW_UNSAFE_ENTRY_WITHOUT_MONITOR_SCHEMA,
    ALLOW_UNSAFE_LINUX_SCHEMA_DECISION,
    ALLOW_UNSAFE_TIMEOUT_SHADOW_REFRESH,
    ALLOW_UNSAFE_CONTROL_REVOKE_BYPASS,
    ALLOW_UNSAFE_TRACE_PLAN_AS_COVERAGE,
    ALLOW_UNSAFE_TEST_HOOK_LIVE_EFFECT,
    ALLOW_UNSAFE_ABI_APPROVAL,
    ALLOW_UNSAFE_BEHAVIOR_CHANGE,
    ALLOW_UNSAFE_MONITOR_VERIFIED,
    ALLOW_UNSAFE_PROTECTION_CLAIM

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "GapsClassified",
    "MonitorSemanticsModeled",
    "HighGapsClosed",
    "DesignAccepted",
    "BadStubBeforeGapsClosed",
    "BadLinuxCanonicalEnvelope",
    "BadEntryWithoutMonitorSchema",
    "BadLinuxSchemaDecision",
    "BadTimeoutShadowRefresh",
    "BadControlRevokeBypass",
    "BadTracePlanAsCoverage",
    "BadTestHookLiveEffect",
    "BadAbiApproval",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

StateFields == {
    "phase",
    "classified",
    "unknownGaps",
    "duplicateGroupsRecognized",
    "requestEnvelopeClosed",
    "directCallEntryClosed",
    "schemaNegotiationClosed",
    "responseShadowClosed",
    "controlRevokeClosed",
    "testHookIsolated",
    "tracePlanSeparated",
    "monitorOwnsRequestImage",
    "monitorOwnsReplay",
    "monitorOwnsSchemaAccept",
    "monitorOwnsResponseHandle",
    "monitorOwnsEpoch",
    "monitorOwnsRevokeOrdering",
    "linuxStubExists",
    "linuxCanonicalEnvelope",
    "entryWithoutMonitorSchema",
    "linuxSchemaDecision",
    "timeoutShadowRefresh",
    "controlRevokeBypass",
    "traceCoverageClaim",
    "testHookLiveEffect",
    "abiApproved",
    "behaviorChange",
    "monitorVerified",
    "protectionClaim",
    "designAccepted",
    "badStubBeforeGapsClosed",
    "badLinuxCanonicalEnvelope",
    "badEntryWithoutMonitorSchema",
    "badLinuxSchemaDecision",
    "badTimeoutShadowRefresh",
    "badControlRevokeBypass",
    "badTracePlanAsCoverage",
    "badTestHookLiveEffect",
    "badAbiApproval",
    "badBehaviorChange",
    "badMonitorVerified",
    "badProtectionClaim"
}

BoolFields == StateFields \ {"phase"}

TerminalPhases == {
    "DesignAccepted",
    "BadStubBeforeGapsClosed",
    "BadLinuxCanonicalEnvelope",
    "BadEntryWithoutMonitorSchema",
    "BadLinuxSchemaDecision",
    "BadTimeoutShadowRefresh",
    "BadControlRevokeBypass",
    "BadTracePlanAsCoverage",
    "BadTestHookLiveEffect",
    "BadAbiApproval",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

HighGapsClosed ==
    /\ state.requestEnvelopeClosed
    /\ state.directCallEntryClosed
    /\ state.schemaNegotiationClosed
    /\ state.responseShadowClosed
    /\ state.controlRevokeClosed

MonitorSemanticsPresent ==
    /\ state.monitorOwnsRequestImage
    /\ state.monitorOwnsReplay
    /\ state.monitorOwnsSchemaAccept
    /\ state.monitorOwnsResponseHandle
    /\ state.monitorOwnsEpoch
    /\ state.monitorOwnsRevokeOrdering

Init ==
    state = [
        phase |-> "Start",
        classified |-> FALSE,
        unknownGaps |-> FALSE,
        duplicateGroupsRecognized |-> FALSE,
        requestEnvelopeClosed |-> FALSE,
        directCallEntryClosed |-> FALSE,
        schemaNegotiationClosed |-> FALSE,
        responseShadowClosed |-> FALSE,
        controlRevokeClosed |-> FALSE,
        testHookIsolated |-> FALSE,
        tracePlanSeparated |-> FALSE,
        monitorOwnsRequestImage |-> FALSE,
        monitorOwnsReplay |-> FALSE,
        monitorOwnsSchemaAccept |-> FALSE,
        monitorOwnsResponseHandle |-> FALSE,
        monitorOwnsEpoch |-> FALSE,
        monitorOwnsRevokeOrdering |-> FALSE,
        linuxStubExists |-> FALSE,
        linuxCanonicalEnvelope |-> FALSE,
        entryWithoutMonitorSchema |-> FALSE,
        linuxSchemaDecision |-> FALSE,
        timeoutShadowRefresh |-> FALSE,
        controlRevokeBypass |-> FALSE,
        traceCoverageClaim |-> FALSE,
        testHookLiveEffect |-> FALSE,
        abiApproved |-> FALSE,
        behaviorChange |-> FALSE,
        monitorVerified |-> FALSE,
        protectionClaim |-> FALSE,
        designAccepted |-> FALSE,
        badStubBeforeGapsClosed |-> FALSE,
        badLinuxCanonicalEnvelope |-> FALSE,
        badEntryWithoutMonitorSchema |-> FALSE,
        badLinuxSchemaDecision |-> FALSE,
        badTimeoutShadowRefresh |-> FALSE,
        badControlRevokeBypass |-> FALSE,
        badTracePlanAsCoverage |-> FALSE,
        badTestHookLiveEffect |-> FALSE,
        badAbiApproval |-> FALSE,
        badBehaviorChange |-> FALSE,
        badMonitorVerified |-> FALSE,
        badProtectionClaim |-> FALSE
    ]

ClassifyGaps ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "GapsClassified",
            !.classified = TRUE,
            !.duplicateGroupsRecognized = TRUE,
            !.unknownGaps = FALSE
        ]

ModelMonitorSemantics ==
    /\ state.phase = "GapsClassified"
    /\ state.classified
    /\ state.duplicateGroupsRecognized
    /\ ~state.unknownGaps
    /\ state' =
        [state EXCEPT
            !.phase = "MonitorSemanticsModeled",
            !.monitorOwnsRequestImage = TRUE,
            !.monitorOwnsReplay = TRUE,
            !.monitorOwnsSchemaAccept = TRUE,
            !.monitorOwnsResponseHandle = TRUE,
            !.monitorOwnsEpoch = TRUE,
            !.monitorOwnsRevokeOrdering = TRUE,
            !.testHookIsolated = TRUE,
            !.tracePlanSeparated = TRUE
        ]

CloseHighGaps ==
    /\ state.phase = "MonitorSemanticsModeled"
    /\ MonitorSemanticsPresent
    /\ state.testHookIsolated
    /\ state.tracePlanSeparated
    /\ state' =
        [state EXCEPT
            !.phase = "HighGapsClosed",
            !.requestEnvelopeClosed = TRUE,
            !.directCallEntryClosed = TRUE,
            !.schemaNegotiationClosed = TRUE,
            !.responseShadowClosed = TRUE,
            !.controlRevokeClosed = TRUE
        ]

AcceptDesign ==
    /\ state.phase = "HighGapsClosed"
    /\ HighGapsClosed
    /\ MonitorSemanticsPresent
    /\ state.testHookIsolated
    /\ state.tracePlanSeparated
    /\ ~state.linuxStubExists
    /\ ~state.abiApproved
    /\ ~state.behaviorChange
    /\ ~state.monitorVerified
    /\ ~state.protectionClaim
    /\ state' =
        [state EXCEPT
            !.phase = "DesignAccepted",
            !.designAccepted = TRUE
        ]

UnsafeStubBeforeGapsClosed ==
    /\ ALLOW_UNSAFE_STUB_BEFORE_GAPS_CLOSED
    /\ state.phase = "GapsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadStubBeforeGapsClosed",
            !.linuxStubExists = TRUE,
            !.badStubBeforeGapsClosed = TRUE
        ]

UnsafeLinuxCanonicalEnvelope ==
    /\ ALLOW_UNSAFE_LINUX_CANONICAL_ENVELOPE
    /\ state.phase = "GapsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxCanonicalEnvelope",
            !.linuxCanonicalEnvelope = TRUE,
            !.requestEnvelopeClosed = TRUE,
            !.badLinuxCanonicalEnvelope = TRUE
        ]

UnsafeEntryWithoutMonitorSchema ==
    /\ ALLOW_UNSAFE_ENTRY_WITHOUT_MONITOR_SCHEMA
    /\ state.phase = "GapsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadEntryWithoutMonitorSchema",
            !.entryWithoutMonitorSchema = TRUE,
            !.directCallEntryClosed = TRUE,
            !.badEntryWithoutMonitorSchema = TRUE
        ]

UnsafeLinuxSchemaDecision ==
    /\ ALLOW_UNSAFE_LINUX_SCHEMA_DECISION
    /\ state.phase = "GapsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxSchemaDecision",
            !.linuxSchemaDecision = TRUE,
            !.schemaNegotiationClosed = TRUE,
            !.badLinuxSchemaDecision = TRUE
        ]

UnsafeTimeoutShadowRefresh ==
    /\ ALLOW_UNSAFE_TIMEOUT_SHADOW_REFRESH
    /\ state.phase = "GapsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadTimeoutShadowRefresh",
            !.timeoutShadowRefresh = TRUE,
            !.responseShadowClosed = TRUE,
            !.badTimeoutShadowRefresh = TRUE
        ]

UnsafeControlRevokeBypass ==
    /\ ALLOW_UNSAFE_CONTROL_REVOKE_BYPASS
    /\ state.phase = "GapsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadControlRevokeBypass",
            !.controlRevokeBypass = TRUE,
            !.controlRevokeClosed = TRUE,
            !.badControlRevokeBypass = TRUE
        ]

UnsafeTracePlanAsCoverage ==
    /\ ALLOW_UNSAFE_TRACE_PLAN_AS_COVERAGE
    /\ state.phase = "GapsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadTracePlanAsCoverage",
            !.traceCoverageClaim = TRUE,
            !.badTracePlanAsCoverage = TRUE
        ]

UnsafeTestHookLiveEffect ==
    /\ ALLOW_UNSAFE_TEST_HOOK_LIVE_EFFECT
    /\ state.phase = "GapsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadTestHookLiveEffect",
            !.testHookLiveEffect = TRUE,
            !.badTestHookLiveEffect = TRUE
        ]

UnsafeAbiApproval ==
    /\ ALLOW_UNSAFE_ABI_APPROVAL
    /\ state.phase = "GapsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadAbiApproval",
            !.abiApproved = TRUE,
            !.badAbiApproval = TRUE
        ]

UnsafeBehaviorChange ==
    /\ ALLOW_UNSAFE_BEHAVIOR_CHANGE
    /\ state.phase = "GapsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadBehaviorChange",
            !.behaviorChange = TRUE,
            !.badBehaviorChange = TRUE
        ]

UnsafeMonitorVerified ==
    /\ ALLOW_UNSAFE_MONITOR_VERIFIED
    /\ state.phase = "GapsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadMonitorVerified",
            !.monitorVerified = TRUE,
            !.badMonitorVerified = TRUE
        ]

UnsafeProtectionClaim ==
    /\ ALLOW_UNSAFE_PROTECTION_CLAIM
    /\ state.phase = "GapsClassified"
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
    \/ ClassifyGaps
    \/ ModelMonitorSemantics
    \/ CloseHighGaps
    \/ AcceptDesign
    \/ UnsafeStubBeforeGapsClosed
    \/ UnsafeLinuxCanonicalEnvelope
    \/ UnsafeEntryWithoutMonitorSchema
    \/ UnsafeLinuxSchemaDecision
    \/ UnsafeTimeoutShadowRefresh
    \/ UnsafeControlRevokeBypass
    \/ UnsafeTracePlanAsCoverage
    \/ UnsafeTestHookLiveEffect
    \/ UnsafeAbiApproval
    \/ UnsafeBehaviorChange
    \/ UnsafeMonitorVerified
    \/ UnsafeProtectionClaim
    \/ StutterAtTerminal

DesignRequiresClassification ==
    state.designAccepted => (state.classified /\ state.duplicateGroupsRecognized /\ ~state.unknownGaps)

DesignRequiresClosedHighGaps ==
    state.designAccepted => HighGapsClosed

ClosedHighGapsRequireMonitorSemantics ==
    HighGapsClosed => MonitorSemanticsPresent

NoStubBeforeGapClosure ==
    state.linuxStubExists => HighGapsClosed

NoLinuxCanonicalEnvelope ==
    ~state.linuxCanonicalEnvelope

NoEntryWithoutMonitorSchema ==
    ~state.entryWithoutMonitorSchema

NoLinuxSchemaDecision ==
    ~state.linuxSchemaDecision

NoTimeoutShadowRefresh ==
    ~state.timeoutShadowRefresh

NoControlRevokeBypass ==
    ~state.controlRevokeBypass

NoTraceCoverageClaim ==
    ~state.traceCoverageClaim

NoTestHookLiveEffect ==
    ~state.testHookLiveEffect

NoAbiApproval ==
    ~state.abiApproved

NoBehaviorChange ==
    ~state.behaviorChange

NoMonitorVerifiedClaim ==
    ~state.monitorVerified

NoProtectionClaim ==
    ~state.protectionClaim

NoBadStubBeforeGapsClosed == ~state.badStubBeforeGapsClosed
NoBadLinuxCanonicalEnvelope == ~state.badLinuxCanonicalEnvelope
NoBadEntryWithoutMonitorSchema == ~state.badEntryWithoutMonitorSchema
NoBadLinuxSchemaDecision == ~state.badLinuxSchemaDecision
NoBadTimeoutShadowRefresh == ~state.badTimeoutShadowRefresh
NoBadControlRevokeBypass == ~state.badControlRevokeBypass
NoBadTracePlanAsCoverage == ~state.badTracePlanAsCoverage
NoBadTestHookLiveEffect == ~state.badTestHookLiveEffect
NoBadAbiApproval == ~state.badAbiApproval
NoBadBehaviorChange == ~state.badBehaviorChange
NoBadMonitorVerified == ~state.badMonitorVerified
NoBadProtectionClaim == ~state.badProtectionClaim

Spec == Init /\ [][Next]_vars

=============================================================================
