-------------------- MODULE NicHypertagReadinessGate --------------------

CONSTANTS
    ALLOW_UNSAFE_BEHAVIOR_BEFORE_GATE,
    ALLOW_UNSAFE_PROBE_AS_AUTHORITY,
    ALLOW_UNSAFE_STUB_ENFORCES,
    ALLOW_UNSAFE_MISSING_RECEIPT_COVERAGE,
    ALLOW_UNSAFE_RAW_ENDPOINT_STUB,
    ALLOW_UNSAFE_PROTECTION_CLAIM

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "ReceiptInventoryComplete",
    "ObservationProbeMapComplete",
    "InertStubsDefined",
    "ModelGatePassed",
    "AssuranceLinked",
    "BehaviorPatchApproved",
    "BadBehaviorBeforeGate",
    "BadProbeAsAuthority",
    "BadStubEnforces",
    "BadMissingCoverage",
    "BadRawEndpointStub",
    "BadProtectionClaim"
}

StateFields == {
    "phase",
    "receiptInventoryComplete",
    "probeMapComplete",
    "allRowsHaveForbiddenShortcuts",
    "probesObservationOnly",
    "probesAuthorityClaim",
    "stubsInert",
    "stubChangesBehavior",
    "stubNoRawEndpoint",
    "missingReceiptCoverage",
    "modelGatePassed",
    "assuranceGateLinked",
    "behaviorPatchApproved",
    "protectionClaim",
    "badBehaviorBeforeGate",
    "badProbeAsAuthority",
    "badStubEnforces",
    "badMissingCoverage",
    "badRawEndpointStub",
    "badProtectionClaim"
}

BoolFields == StateFields \ {"phase"}

TerminalPhases == {
    "BehaviorPatchApproved",
    "BadBehaviorBeforeGate",
    "BadProbeAsAuthority",
    "BadStubEnforces",
    "BadMissingCoverage",
    "BadRawEndpointStub",
    "BadProtectionClaim"
}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        receiptInventoryComplete |-> FALSE,
        probeMapComplete |-> FALSE,
        allRowsHaveForbiddenShortcuts |-> FALSE,
        probesObservationOnly |-> FALSE,
        probesAuthorityClaim |-> FALSE,
        stubsInert |-> FALSE,
        stubChangesBehavior |-> FALSE,
        stubNoRawEndpoint |-> FALSE,
        missingReceiptCoverage |-> TRUE,
        modelGatePassed |-> FALSE,
        assuranceGateLinked |-> FALSE,
        behaviorPatchApproved |-> FALSE,
        protectionClaim |-> FALSE,
        badBehaviorBeforeGate |-> FALSE,
        badProbeAsAuthority |-> FALSE,
        badStubEnforces |-> FALSE,
        badMissingCoverage |-> FALSE,
        badRawEndpointStub |-> FALSE,
        badProtectionClaim |-> FALSE
        ]

ReadinessGateSatisfied ==
    /\ state.receiptInventoryComplete
    /\ state.probeMapComplete
    /\ state.allRowsHaveForbiddenShortcuts
    /\ state.probesObservationOnly
    /\ ~state.probesAuthorityClaim
    /\ state.stubsInert
    /\ ~state.stubChangesBehavior
    /\ state.stubNoRawEndpoint
    /\ ~state.missingReceiptCoverage
    /\ state.modelGatePassed
    /\ state.assuranceGateLinked
    /\ ~state.protectionClaim

CompleteReceiptInventory ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "ReceiptInventoryComplete",
            !.receiptInventoryComplete = TRUE,
            !.missingReceiptCoverage = FALSE
        ]

CompleteObservationProbeMap ==
    /\ state.phase = "ReceiptInventoryComplete"
    /\ state.receiptInventoryComplete
    /\ ~state.missingReceiptCoverage
    /\ state' =
        [state EXCEPT
            !.phase = "ObservationProbeMapComplete",
            !.probeMapComplete = TRUE,
            !.allRowsHaveForbiddenShortcuts = TRUE,
            !.probesObservationOnly = TRUE,
            !.probesAuthorityClaim = FALSE
        ]

DefineInertStubs ==
    /\ state.phase = "ObservationProbeMapComplete"
    /\ state.probeMapComplete
    /\ state.probesObservationOnly
    /\ ~state.probesAuthorityClaim
    /\ state' =
        [state EXCEPT
            !.phase = "InertStubsDefined",
            !.stubsInert = TRUE,
            !.stubChangesBehavior = FALSE,
            !.stubNoRawEndpoint = TRUE
        ]

PassModelGate ==
    /\ state.phase = "InertStubsDefined"
    /\ state.receiptInventoryComplete
    /\ state.probeMapComplete
    /\ state.allRowsHaveForbiddenShortcuts
    /\ state.probesObservationOnly
    /\ ~state.probesAuthorityClaim
    /\ state.stubsInert
    /\ ~state.stubChangesBehavior
    /\ state.stubNoRawEndpoint
    /\ ~state.missingReceiptCoverage
    /\ state' =
        [state EXCEPT
            !.phase = "ModelGatePassed",
            !.modelGatePassed = TRUE
        ]

LinkAssuranceGate ==
    /\ state.phase = "ModelGatePassed"
    /\ state.modelGatePassed
    /\ ~state.protectionClaim
    /\ state' =
        [state EXCEPT
            !.phase = "AssuranceLinked",
            !.assuranceGateLinked = TRUE
        ]

ApproveBehaviorPatch ==
    /\ state.phase = "AssuranceLinked"
    /\ ReadinessGateSatisfied
    /\ state' =
        [state EXCEPT
            !.phase = "BehaviorPatchApproved",
            !.behaviorPatchApproved = TRUE
        ]

UnsafeBehaviorBeforeGate ==
    /\ ALLOW_UNSAFE_BEHAVIOR_BEFORE_GATE
    /\ state.phase \in {"Start", "ReceiptInventoryComplete",
        "ObservationProbeMapComplete", "InertStubsDefined", "ModelGatePassed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadBehaviorBeforeGate",
            !.behaviorPatchApproved = TRUE,
            !.badBehaviorBeforeGate = TRUE
        ]

UnsafeProbeAsAuthority ==
    /\ ALLOW_UNSAFE_PROBE_AS_AUTHORITY
    /\ state.phase = "ObservationProbeMapComplete"
    /\ state' =
        [state EXCEPT
            !.phase = "BadProbeAsAuthority",
            !.probesAuthorityClaim = TRUE,
            !.badProbeAsAuthority = TRUE
        ]

UnsafeStubEnforces ==
    /\ ALLOW_UNSAFE_STUB_ENFORCES
    /\ state.phase = "InertStubsDefined"
    /\ state' =
        [state EXCEPT
            !.phase = "BadStubEnforces",
            !.stubChangesBehavior = TRUE,
            !.badStubEnforces = TRUE
        ]

UnsafeMissingCoverage ==
    /\ ALLOW_UNSAFE_MISSING_RECEIPT_COVERAGE
    /\ state.phase = "ReceiptInventoryComplete"
    /\ state' =
        [state EXCEPT
            !.phase = "BadMissingCoverage",
            !.missingReceiptCoverage = TRUE,
            !.modelGatePassed = TRUE,
            !.badMissingCoverage = TRUE
        ]

UnsafeRawEndpointStub ==
    /\ ALLOW_UNSAFE_RAW_ENDPOINT_STUB
    /\ state.phase = "InertStubsDefined"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRawEndpointStub",
            !.stubNoRawEndpoint = FALSE,
            !.badRawEndpointStub = TRUE
        ]

UnsafeProtectionClaim ==
    /\ ALLOW_UNSAFE_PROTECTION_CLAIM
    /\ state.phase \in {"ReceiptInventoryComplete", "ObservationProbeMapComplete",
        "InertStubsDefined", "ModelGatePassed", "AssuranceLinked"}
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
    \/ CompleteReceiptInventory
    \/ CompleteObservationProbeMap
    \/ DefineInertStubs
    \/ PassModelGate
    \/ LinkAssuranceGate
    \/ ApproveBehaviorPatch
    \/ UnsafeBehaviorBeforeGate
    \/ UnsafeProbeAsAuthority
    \/ UnsafeStubEnforces
    \/ UnsafeMissingCoverage
    \/ UnsafeRawEndpointStub
    \/ UnsafeProtectionClaim
    \/ StutterAtTerminal

NoBehaviorPatchBeforeGate ==
    state.behaviorPatchApproved => ReadinessGateSatisfied

NoProbeAsAuthority ==
    ~state.probesAuthorityClaim

NoStubEnforces ==
    ~state.stubChangesBehavior

NoMissingReceiptCoverage ==
    ~state.missingReceiptCoverage \/ state.phase = "Start"

NoRawEndpointStub ==
    state.stubNoRawEndpoint \/
        state.phase \in {"Start", "ReceiptInventoryComplete",
        "ObservationProbeMapComplete"}

NoProtectionClaim ==
    ~state.protectionClaim

NoBadBehaviorBeforeGate == ~state.badBehaviorBeforeGate
NoBadProbeAsAuthority == ~state.badProbeAsAuthority
NoBadStubEnforces == ~state.badStubEnforces
NoBadMissingCoverage == ~state.badMissingCoverage
NoBadRawEndpointStub == ~state.badRawEndpointStub
NoBadProtectionClaim == ~state.badProtectionClaim

=============================================================================
