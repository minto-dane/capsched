-------------------- MODULE DirectCallAttachmentReadiness --------------------

CONSTANTS
    ALLOW_UNSAFE_MISSING_ROW_COVERAGE,
    ALLOW_UNSAFE_AUTHORITY_CLAIM,
    ALLOW_UNSAFE_MONITOR_VERIFIED,
    ALLOW_UNSAFE_BEHAVIOR_CHANGE,
    ALLOW_UNSAFE_USER_ABI,
    ALLOW_UNSAFE_PUBLIC_TRACEPOINT_ABI,
    ALLOW_UNSAFE_PROTECTION_CLAIM,
    ALLOW_UNSAFE_STUB_AUTHORIZES,
    ALLOW_UNSAFE_STUB_CHANGES_CALLER_BEHAVIOR,
    ALLOW_UNSAFE_PROBE_AS_AUTHORITY,
    ALLOW_UNSAFE_LINUX_LEDGER_WRITE,
    ALLOW_UNSAFE_LINUX_SHADOW_FROM_TIMEOUT,
    ALLOW_UNSAFE_FAILURE_INJECTION_LIVE_EFFECT,
    ALLOW_UNSAFE_RAW_HANDLE_EXPOSURE,
    ALLOW_UNSAFE_DIRECT_ONLY_RING_INCOMPATIBLE

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "SourceAnchorsChecked",
    "RowsDeclared",
    "RequiredFlagsSet",
    "ObservationSurfacesDeclared",
    "StubConstraintsDeclared",
    "FailureInjectionDeclared",
    "RingCompatibilityDeclared",
    "CoverageChecked",
    "ReadinessAccepted",
    "BadMissingRowCoverage",
    "BadAuthorityClaim",
    "BadMonitorVerified",
    "BadBehaviorChange",
    "BadUserAbi",
    "BadPublicTracepointAbi",
    "BadProtectionClaim",
    "BadStubAuthorizes",
    "BadStubChangesCallerBehavior",
    "BadProbeAsAuthority",
    "BadLinuxLedgerWrite",
    "BadLinuxShadowFromTimeout",
    "BadFailureInjectionLiveEffect",
    "BadRawHandleExposure",
    "BadDirectOnlyRingIncompatible"
}

StateFields == {
    "phase",
    "sourceAnchorsChecked",
    "rowsDeclared",
    "allRequiredRowsPresent",
    "allRequiredFieldsPresent",
    "observationOnly",
    "authorityClaim",
    "monitorVerified",
    "behaviorChange",
    "userAbi",
    "publicTracepointAbi",
    "protectionClaim",
    "observationSurfacesDeclared",
    "probeAuthority",
    "stubConstraintsDeclared",
    "stubAuthorizes",
    "stubChangesCallerBehavior",
    "failureInjectionDeclared",
    "failureInjectionLiveEffect",
    "ringCompatibilityDeclared",
    "directOnlyRingIncompatible",
    "linuxLedgerWrite",
    "linuxResponseMint",
    "linuxShadowFromTimeout",
    "rawHandleExposure",
    "coverageChecked",
    "readinessAccepted",
    "badMissingRowCoverage",
    "badAuthorityClaim",
    "badMonitorVerified",
    "badBehaviorChange",
    "badUserAbi",
    "badPublicTracepointAbi",
    "badProtectionClaim",
    "badStubAuthorizes",
    "badStubChangesCallerBehavior",
    "badProbeAsAuthority",
    "badLinuxLedgerWrite",
    "badLinuxShadowFromTimeout",
    "badFailureInjectionLiveEffect",
    "badRawHandleExposure",
    "badDirectOnlyRingIncompatible"
}

BoolFields == StateFields \ {"phase"}

TerminalPhases == {
    "ReadinessAccepted",
    "BadMissingRowCoverage",
    "BadAuthorityClaim",
    "BadMonitorVerified",
    "BadBehaviorChange",
    "BadUserAbi",
    "BadPublicTracepointAbi",
    "BadProtectionClaim",
    "BadStubAuthorizes",
    "BadStubChangesCallerBehavior",
    "BadProbeAsAuthority",
    "BadLinuxLedgerWrite",
    "BadLinuxShadowFromTimeout",
    "BadFailureInjectionLiveEffect",
    "BadRawHandleExposure",
    "BadDirectOnlyRingIncompatible"
}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        sourceAnchorsChecked |-> FALSE,
        rowsDeclared |-> FALSE,
        allRequiredRowsPresent |-> FALSE,
        allRequiredFieldsPresent |-> FALSE,
        observationOnly |-> FALSE,
        authorityClaim |-> FALSE,
        monitorVerified |-> FALSE,
        behaviorChange |-> FALSE,
        userAbi |-> FALSE,
        publicTracepointAbi |-> FALSE,
        protectionClaim |-> FALSE,
        observationSurfacesDeclared |-> FALSE,
        probeAuthority |-> FALSE,
        stubConstraintsDeclared |-> FALSE,
        stubAuthorizes |-> FALSE,
        stubChangesCallerBehavior |-> FALSE,
        failureInjectionDeclared |-> FALSE,
        failureInjectionLiveEffect |-> FALSE,
        ringCompatibilityDeclared |-> FALSE,
        directOnlyRingIncompatible |-> FALSE,
        linuxLedgerWrite |-> FALSE,
        linuxResponseMint |-> FALSE,
        linuxShadowFromTimeout |-> FALSE,
        rawHandleExposure |-> FALSE,
        coverageChecked |-> FALSE,
        readinessAccepted |-> FALSE,
        badMissingRowCoverage |-> FALSE,
        badAuthorityClaim |-> FALSE,
        badMonitorVerified |-> FALSE,
        badBehaviorChange |-> FALSE,
        badUserAbi |-> FALSE,
        badPublicTracepointAbi |-> FALSE,
        badProtectionClaim |-> FALSE,
        badStubAuthorizes |-> FALSE,
        badStubChangesCallerBehavior |-> FALSE,
        badProbeAsAuthority |-> FALSE,
        badLinuxLedgerWrite |-> FALSE,
        badLinuxShadowFromTimeout |-> FALSE,
        badFailureInjectionLiveEffect |-> FALSE,
        badRawHandleExposure |-> FALSE,
        badDirectOnlyRingIncompatible |-> FALSE
    ]

CheckSourceAnchors ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "SourceAnchorsChecked",
            !.sourceAnchorsChecked = TRUE
        ]

DeclareRows ==
    /\ state.phase = "SourceAnchorsChecked"
    /\ state.sourceAnchorsChecked
    /\ state' =
        [state EXCEPT
            !.phase = "RowsDeclared",
            !.rowsDeclared = TRUE,
            !.allRequiredRowsPresent = TRUE,
            !.allRequiredFieldsPresent = TRUE
        ]

SetRequiredFlags ==
    /\ state.phase = "RowsDeclared"
    /\ state.rowsDeclared
    /\ state.allRequiredRowsPresent
    /\ state.allRequiredFieldsPresent
    /\ state' =
        [state EXCEPT
            !.phase = "RequiredFlagsSet",
            !.observationOnly = TRUE,
            !.authorityClaim = FALSE,
            !.monitorVerified = FALSE,
            !.behaviorChange = FALSE,
            !.userAbi = FALSE,
            !.publicTracepointAbi = FALSE,
            !.protectionClaim = FALSE
        ]

DeclareObservationSurfaces ==
    /\ state.phase = "RequiredFlagsSet"
    /\ state.observationOnly
    /\ ~state.authorityClaim
    /\ state' =
        [state EXCEPT
            !.phase = "ObservationSurfacesDeclared",
            !.observationSurfacesDeclared = TRUE
        ]

DeclareStubConstraints ==
    /\ state.phase = "ObservationSurfacesDeclared"
    /\ state.observationSurfacesDeclared
    /\ ~state.probeAuthority
    /\ state' =
        [state EXCEPT
            !.phase = "StubConstraintsDeclared",
            !.stubConstraintsDeclared = TRUE
        ]

DeclareFailureInjection ==
    /\ state.phase = "StubConstraintsDeclared"
    /\ state.stubConstraintsDeclared
    /\ ~state.stubAuthorizes
    /\ ~state.stubChangesCallerBehavior
    /\ state' =
        [state EXCEPT
            !.phase = "FailureInjectionDeclared",
            !.failureInjectionDeclared = TRUE
        ]

DeclareRingCompatibility ==
    /\ state.phase = "FailureInjectionDeclared"
    /\ state.failureInjectionDeclared
    /\ ~state.failureInjectionLiveEffect
    /\ state' =
        [state EXCEPT
            !.phase = "RingCompatibilityDeclared",
            !.ringCompatibilityDeclared = TRUE
        ]

CheckCoverage ==
    /\ state.phase = "RingCompatibilityDeclared"
    /\ state.ringCompatibilityDeclared
    /\ ~state.directOnlyRingIncompatible
    /\ state' =
        [state EXCEPT
            !.phase = "CoverageChecked",
            !.coverageChecked = TRUE
        ]

AcceptReadiness ==
    /\ state.phase = "CoverageChecked"
    /\ state.coverageChecked
    /\ state.allRequiredRowsPresent
    /\ state.allRequiredFieldsPresent
    /\ state.observationOnly
    /\ ~state.authorityClaim
    /\ ~state.monitorVerified
    /\ ~state.behaviorChange
    /\ ~state.userAbi
    /\ ~state.publicTracepointAbi
    /\ ~state.protectionClaim
    /\ ~state.stubAuthorizes
    /\ ~state.probeAuthority
    /\ ~state.linuxLedgerWrite
    /\ ~state.linuxResponseMint
    /\ ~state.linuxShadowFromTimeout
    /\ ~state.failureInjectionLiveEffect
    /\ ~state.rawHandleExposure
    /\ ~state.directOnlyRingIncompatible
    /\ state' =
        [state EXCEPT
            !.phase = "ReadinessAccepted",
            !.readinessAccepted = TRUE
        ]

UnsafeMissingRowCoverage ==
    /\ ALLOW_UNSAFE_MISSING_ROW_COVERAGE
    /\ state.phase = "RowsDeclared"
    /\ state' =
        [state EXCEPT
            !.phase = "BadMissingRowCoverage",
            !.allRequiredRowsPresent = FALSE,
            !.readinessAccepted = TRUE,
            !.badMissingRowCoverage = TRUE
        ]

UnsafeAuthorityClaim ==
    /\ ALLOW_UNSAFE_AUTHORITY_CLAIM
    /\ state.phase = "RequiredFlagsSet"
    /\ state' =
        [state EXCEPT
            !.phase = "BadAuthorityClaim",
            !.authorityClaim = TRUE,
            !.readinessAccepted = TRUE,
            !.badAuthorityClaim = TRUE
        ]

UnsafeMonitorVerified ==
    /\ ALLOW_UNSAFE_MONITOR_VERIFIED
    /\ state.phase = "RequiredFlagsSet"
    /\ state' =
        [state EXCEPT
            !.phase = "BadMonitorVerified",
            !.monitorVerified = TRUE,
            !.readinessAccepted = TRUE,
            !.badMonitorVerified = TRUE
        ]

UnsafeBehaviorChange ==
    /\ ALLOW_UNSAFE_BEHAVIOR_CHANGE
    /\ state.phase = "RequiredFlagsSet"
    /\ state' =
        [state EXCEPT
            !.phase = "BadBehaviorChange",
            !.behaviorChange = TRUE,
            !.readinessAccepted = TRUE,
            !.badBehaviorChange = TRUE
        ]

UnsafeUserAbi ==
    /\ ALLOW_UNSAFE_USER_ABI
    /\ state.phase = "RequiredFlagsSet"
    /\ state' =
        [state EXCEPT
            !.phase = "BadUserAbi",
            !.userAbi = TRUE,
            !.readinessAccepted = TRUE,
            !.badUserAbi = TRUE
        ]

UnsafePublicTracepointAbi ==
    /\ ALLOW_UNSAFE_PUBLIC_TRACEPOINT_ABI
    /\ state.phase = "RequiredFlagsSet"
    /\ state' =
        [state EXCEPT
            !.phase = "BadPublicTracepointAbi",
            !.publicTracepointAbi = TRUE,
            !.readinessAccepted = TRUE,
            !.badPublicTracepointAbi = TRUE
        ]

UnsafeProtectionClaim ==
    /\ ALLOW_UNSAFE_PROTECTION_CLAIM
    /\ state.phase = "RequiredFlagsSet"
    /\ state' =
        [state EXCEPT
            !.phase = "BadProtectionClaim",
            !.protectionClaim = TRUE,
            !.readinessAccepted = TRUE,
            !.badProtectionClaim = TRUE
        ]

UnsafeStubAuthorizes ==
    /\ ALLOW_UNSAFE_STUB_AUTHORIZES
    /\ state.phase = "StubConstraintsDeclared"
    /\ state' =
        [state EXCEPT
            !.phase = "BadStubAuthorizes",
            !.stubAuthorizes = TRUE,
            !.readinessAccepted = TRUE,
            !.badStubAuthorizes = TRUE
        ]

UnsafeStubChangesCallerBehavior ==
    /\ ALLOW_UNSAFE_STUB_CHANGES_CALLER_BEHAVIOR
    /\ state.phase = "StubConstraintsDeclared"
    /\ state' =
        [state EXCEPT
            !.phase = "BadStubChangesCallerBehavior",
            !.stubChangesCallerBehavior = TRUE,
            !.readinessAccepted = TRUE,
            !.badStubChangesCallerBehavior = TRUE
        ]

UnsafeProbeAsAuthority ==
    /\ ALLOW_UNSAFE_PROBE_AS_AUTHORITY
    /\ state.phase = "ObservationSurfacesDeclared"
    /\ state' =
        [state EXCEPT
            !.phase = "BadProbeAsAuthority",
            !.probeAuthority = TRUE,
            !.readinessAccepted = TRUE,
            !.badProbeAsAuthority = TRUE
        ]

UnsafeLinuxLedgerWrite ==
    /\ ALLOW_UNSAFE_LINUX_LEDGER_WRITE
    /\ state.phase = "ObservationSurfacesDeclared"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxLedgerWrite",
            !.linuxLedgerWrite = TRUE,
            !.linuxResponseMint = TRUE,
            !.readinessAccepted = TRUE,
            !.badLinuxLedgerWrite = TRUE
        ]

UnsafeLinuxShadowFromTimeout ==
    /\ ALLOW_UNSAFE_LINUX_SHADOW_FROM_TIMEOUT
    /\ state.phase = "ObservationSurfacesDeclared"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxShadowFromTimeout",
            !.linuxShadowFromTimeout = TRUE,
            !.readinessAccepted = TRUE,
            !.badLinuxShadowFromTimeout = TRUE
        ]

UnsafeFailureInjectionLiveEffect ==
    /\ ALLOW_UNSAFE_FAILURE_INJECTION_LIVE_EFFECT
    /\ state.phase = "FailureInjectionDeclared"
    /\ state' =
        [state EXCEPT
            !.phase = "BadFailureInjectionLiveEffect",
            !.failureInjectionLiveEffect = TRUE,
            !.readinessAccepted = TRUE,
            !.badFailureInjectionLiveEffect = TRUE
        ]

UnsafeRawHandleExposure ==
    /\ ALLOW_UNSAFE_RAW_HANDLE_EXPOSURE
    /\ state.phase = "ObservationSurfacesDeclared"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRawHandleExposure",
            !.rawHandleExposure = TRUE,
            !.readinessAccepted = TRUE,
            !.badRawHandleExposure = TRUE
        ]

UnsafeDirectOnlyRingIncompatible ==
    /\ ALLOW_UNSAFE_DIRECT_ONLY_RING_INCOMPATIBLE
    /\ state.phase = "RingCompatibilityDeclared"
    /\ state' =
        [state EXCEPT
            !.phase = "BadDirectOnlyRingIncompatible",
            !.directOnlyRingIncompatible = TRUE,
            !.readinessAccepted = TRUE,
            !.badDirectOnlyRingIncompatible = TRUE
        ]

StutterAtTerminal ==
    /\ state.phase \in TerminalPhases
    /\ UNCHANGED state

Next ==
    \/ CheckSourceAnchors
    \/ DeclareRows
    \/ SetRequiredFlags
    \/ DeclareObservationSurfaces
    \/ DeclareStubConstraints
    \/ DeclareFailureInjection
    \/ DeclareRingCompatibility
    \/ CheckCoverage
    \/ AcceptReadiness
    \/ UnsafeMissingRowCoverage
    \/ UnsafeAuthorityClaim
    \/ UnsafeMonitorVerified
    \/ UnsafeBehaviorChange
    \/ UnsafeUserAbi
    \/ UnsafePublicTracepointAbi
    \/ UnsafeProtectionClaim
    \/ UnsafeStubAuthorizes
    \/ UnsafeStubChangesCallerBehavior
    \/ UnsafeProbeAsAuthority
    \/ UnsafeLinuxLedgerWrite
    \/ UnsafeLinuxShadowFromTimeout
    \/ UnsafeFailureInjectionLiveEffect
    \/ UnsafeRawHandleExposure
    \/ UnsafeDirectOnlyRingIncompatible
    \/ StutterAtTerminal

ReadinessRequiresCoverage ==
    state.readinessAccepted =>
        (state.allRequiredRowsPresent /\ state.allRequiredFieldsPresent /\
         state.coverageChecked)

ReadinessIsObservationOnly ==
    state.readinessAccepted => state.observationOnly

NoAuthorityClaim ==
    ~state.authorityClaim

NoMonitorVerifiedClaim ==
    ~state.monitorVerified

NoBehaviorChange ==
    ~state.behaviorChange

NoUserAbi ==
    ~state.userAbi

NoPublicTracepointAbi ==
    ~state.publicTracepointAbi

NoProtectionClaim ==
    ~state.protectionClaim

NoStubAuthorization ==
    ~state.stubAuthorizes /\ ~state.stubChangesCallerBehavior

ObservationIsNotAuthority ==
    ~state.probeAuthority

NoLinuxLedgerOrResponseMint ==
    ~state.linuxLedgerWrite /\ ~state.linuxResponseMint

NoLinuxShadowFromTimeout ==
    ~state.linuxShadowFromTimeout

FailureInjectionIsNotLiveBehavior ==
    ~state.failureInjectionLiveEffect

NoRawHandleExposure ==
    ~state.rawHandleExposure

RingCompatibilityRequired ==
    state.readinessAccepted =>
        (state.ringCompatibilityDeclared /\ ~state.directOnlyRingIncompatible)

NoBadMissingRowCoverage == ~state.badMissingRowCoverage

NoBadAuthorityClaim == ~state.badAuthorityClaim

NoBadMonitorVerified == ~state.badMonitorVerified

NoBadBehaviorChange == ~state.badBehaviorChange

NoBadUserAbi == ~state.badUserAbi

NoBadPublicTracepointAbi == ~state.badPublicTracepointAbi

NoBadProtectionClaim == ~state.badProtectionClaim

NoBadStubAuthorizes == ~state.badStubAuthorizes

NoBadStubChangesCallerBehavior == ~state.badStubChangesCallerBehavior

NoBadProbeAsAuthority == ~state.badProbeAsAuthority

NoBadLinuxLedgerWrite == ~state.badLinuxLedgerWrite

NoBadLinuxShadowFromTimeout == ~state.badLinuxShadowFromTimeout

NoBadFailureInjectionLiveEffect == ~state.badFailureInjectionLiveEffect

NoBadRawHandleExposure == ~state.badRawHandleExposure

NoBadDirectOnlyRingIncompatible == ~state.badDirectOnlyRingIncompatible

Spec == Init /\ [][Next]_vars

=============================================================================
