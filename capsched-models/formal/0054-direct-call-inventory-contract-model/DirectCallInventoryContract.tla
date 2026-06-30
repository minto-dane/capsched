---------------------- MODULE DirectCallInventoryContract --------------------

CONSTANTS
    ALLOW_UNSAFE_LINUX_MODIFICATION,
    ALLOW_UNSAFE_ROOT_REQUIRED,
    ALLOW_UNSAFE_TRACEFS_WRITE,
    ALLOW_UNSAFE_PUBLIC_TRACEPOINT_ABI,
    ALLOW_UNSAFE_PROBE_ATTACHMENT,
    ALLOW_UNSAFE_OUTPUT_INCOMPLETE,
    ALLOW_UNSAFE_SAFETY_FLAGS_MISSING,
    ALLOW_UNSAFE_MISSING_AS_NO_OBLIGATION,
    ALLOW_UNSAFE_ANCHOR_AS_AUTHORITY,
    ALLOW_UNSAFE_TRACE_AS_AUTHORITY,
    ALLOW_UNSAFE_RUNTIME_OBSERVATION_CLAIM,
    ALLOW_UNSAFE_RAW_HANDLE_EXPOSURE,
    ALLOW_UNSAFE_MONITOR_VERIFIED,
    ALLOW_UNSAFE_PROTECTION_CLAIM,
    ALLOW_UNSAFE_BEHAVIOR_CHANGE

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "ContractLoaded",
    "OutputsDeclared",
    "RowsClassified",
    "InventoryAccepted",
    "BadLinuxModification",
    "BadRootRequired",
    "BadTracefsWrite",
    "BadPublicTracepointAbi",
    "BadProbeAttachment",
    "BadOutputIncomplete",
    "BadSafetyFlagsMissing",
    "BadMissingAsNoObligation",
    "BadAnchorAsAuthority",
    "BadTraceAsAuthority",
    "BadRuntimeObservationClaim",
    "BadRawHandleExposure",
    "BadMonitorVerified",
    "BadProtectionClaim",
    "BadBehaviorChange"
}

StateFields == {
    "phase",
    "contractLoaded",
    "sourceOnly",
    "outputComplete",
    "requiredFieldsPresent",
    "safetyFlagsPresent",
    "linuxModified",
    "sourceOnlyRequiresRoot",
    "tracefsWritten",
    "publicTracepointAbi",
    "probesAttached",
    "missingRowsRecordedAsGaps",
    "missingAnchorNoObligation",
    "anchorsAvailable",
    "anchorAuthority",
    "tracePlanOnly",
    "traceAuthority",
    "runtimeObservationClaim",
    "rawHandleExposure",
    "monitorVerified",
    "protectionClaim",
    "behaviorChange",
    "inventoryAccepted",
    "badLinuxModification",
    "badRootRequired",
    "badTracefsWrite",
    "badPublicTracepointAbi",
    "badProbeAttachment",
    "badOutputIncomplete",
    "badSafetyFlagsMissing",
    "badMissingAsNoObligation",
    "badAnchorAsAuthority",
    "badTraceAsAuthority",
    "badRuntimeObservationClaim",
    "badRawHandleExposure",
    "badMonitorVerified",
    "badProtectionClaim",
    "badBehaviorChange"
}

BoolFields == StateFields \ {"phase"}

TerminalPhases == {
    "InventoryAccepted",
    "BadLinuxModification",
    "BadRootRequired",
    "BadTracefsWrite",
    "BadPublicTracepointAbi",
    "BadProbeAttachment",
    "BadOutputIncomplete",
    "BadSafetyFlagsMissing",
    "BadMissingAsNoObligation",
    "BadAnchorAsAuthority",
    "BadTraceAsAuthority",
    "BadRuntimeObservationClaim",
    "BadRawHandleExposure",
    "BadMonitorVerified",
    "BadProtectionClaim",
    "BadBehaviorChange"
}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        contractLoaded |-> FALSE,
        sourceOnly |-> FALSE,
        outputComplete |-> FALSE,
        requiredFieldsPresent |-> FALSE,
        safetyFlagsPresent |-> FALSE,
        linuxModified |-> FALSE,
        sourceOnlyRequiresRoot |-> FALSE,
        tracefsWritten |-> FALSE,
        publicTracepointAbi |-> FALSE,
        probesAttached |-> FALSE,
        missingRowsRecordedAsGaps |-> FALSE,
        missingAnchorNoObligation |-> FALSE,
        anchorsAvailable |-> FALSE,
        anchorAuthority |-> FALSE,
        tracePlanOnly |-> FALSE,
        traceAuthority |-> FALSE,
        runtimeObservationClaim |-> FALSE,
        rawHandleExposure |-> FALSE,
        monitorVerified |-> FALSE,
        protectionClaim |-> FALSE,
        behaviorChange |-> FALSE,
        inventoryAccepted |-> FALSE,
        badLinuxModification |-> FALSE,
        badRootRequired |-> FALSE,
        badTracefsWrite |-> FALSE,
        badPublicTracepointAbi |-> FALSE,
        badProbeAttachment |-> FALSE,
        badOutputIncomplete |-> FALSE,
        badSafetyFlagsMissing |-> FALSE,
        badMissingAsNoObligation |-> FALSE,
        badAnchorAsAuthority |-> FALSE,
        badTraceAsAuthority |-> FALSE,
        badRuntimeObservationClaim |-> FALSE,
        badRawHandleExposure |-> FALSE,
        badMonitorVerified |-> FALSE,
        badProtectionClaim |-> FALSE,
        badBehaviorChange |-> FALSE
    ]

LoadContract ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "ContractLoaded",
            !.contractLoaded = TRUE,
            !.sourceOnly = TRUE
        ]

DeclareOutputs ==
    /\ state.phase = "ContractLoaded"
    /\ state.contractLoaded
    /\ state.sourceOnly
    /\ ~state.linuxModified
    /\ ~state.sourceOnlyRequiresRoot
    /\ ~state.tracefsWritten
    /\ state' =
        [state EXCEPT
            !.phase = "OutputsDeclared",
            !.outputComplete = TRUE,
            !.requiredFieldsPresent = TRUE,
            !.safetyFlagsPresent = TRUE
        ]

ClassifyRows ==
    /\ state.phase = "OutputsDeclared"
    /\ state.outputComplete
    /\ state.requiredFieldsPresent
    /\ state.safetyFlagsPresent
    /\ ~state.publicTracepointAbi
    /\ ~state.probesAttached
    /\ state' =
        [state EXCEPT
            !.phase = "RowsClassified",
            !.missingRowsRecordedAsGaps = TRUE,
            !.anchorsAvailable = TRUE,
            !.tracePlanOnly = TRUE
        ]

AcceptInventory ==
    /\ state.phase = "RowsClassified"
    /\ state.contractLoaded
    /\ state.sourceOnly
    /\ state.outputComplete
    /\ state.requiredFieldsPresent
    /\ state.safetyFlagsPresent
    /\ state.missingRowsRecordedAsGaps
    /\ state.tracePlanOnly
    /\ ~state.linuxModified
    /\ ~state.sourceOnlyRequiresRoot
    /\ ~state.tracefsWritten
    /\ ~state.publicTracepointAbi
    /\ ~state.probesAttached
    /\ ~state.missingAnchorNoObligation
    /\ ~state.anchorAuthority
    /\ ~state.traceAuthority
    /\ ~state.runtimeObservationClaim
    /\ ~state.rawHandleExposure
    /\ ~state.monitorVerified
    /\ ~state.protectionClaim
    /\ ~state.behaviorChange
    /\ state' =
        [state EXCEPT
            !.phase = "InventoryAccepted",
            !.inventoryAccepted = TRUE
        ]

UnsafeLinuxModification ==
    /\ ALLOW_UNSAFE_LINUX_MODIFICATION
    /\ state.phase = "ContractLoaded"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxModification",
            !.linuxModified = TRUE,
            !.inventoryAccepted = TRUE,
            !.badLinuxModification = TRUE
        ]

UnsafeRootRequired ==
    /\ ALLOW_UNSAFE_ROOT_REQUIRED
    /\ state.phase = "ContractLoaded"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRootRequired",
            !.sourceOnlyRequiresRoot = TRUE,
            !.inventoryAccepted = TRUE,
            !.badRootRequired = TRUE
        ]

UnsafeTracefsWrite ==
    /\ ALLOW_UNSAFE_TRACEFS_WRITE
    /\ state.phase = "ContractLoaded"
    /\ state' =
        [state EXCEPT
            !.phase = "BadTracefsWrite",
            !.tracefsWritten = TRUE,
            !.inventoryAccepted = TRUE,
            !.badTracefsWrite = TRUE
        ]

UnsafePublicTracepointAbi ==
    /\ ALLOW_UNSAFE_PUBLIC_TRACEPOINT_ABI
    /\ state.phase = "OutputsDeclared"
    /\ state' =
        [state EXCEPT
            !.phase = "BadPublicTracepointAbi",
            !.publicTracepointAbi = TRUE,
            !.inventoryAccepted = TRUE,
            !.badPublicTracepointAbi = TRUE
        ]

UnsafeProbeAttachment ==
    /\ ALLOW_UNSAFE_PROBE_ATTACHMENT
    /\ state.phase = "OutputsDeclared"
    /\ state' =
        [state EXCEPT
            !.phase = "BadProbeAttachment",
            !.probesAttached = TRUE,
            !.inventoryAccepted = TRUE,
            !.badProbeAttachment = TRUE
        ]

UnsafeOutputIncomplete ==
    /\ ALLOW_UNSAFE_OUTPUT_INCOMPLETE
    /\ state.phase = "ContractLoaded"
    /\ state' =
        [state EXCEPT
            !.phase = "BadOutputIncomplete",
            !.outputComplete = FALSE,
            !.requiredFieldsPresent = FALSE,
            !.inventoryAccepted = TRUE,
            !.badOutputIncomplete = TRUE
        ]

UnsafeSafetyFlagsMissing ==
    /\ ALLOW_UNSAFE_SAFETY_FLAGS_MISSING
    /\ state.phase = "OutputsDeclared"
    /\ state' =
        [state EXCEPT
            !.phase = "BadSafetyFlagsMissing",
            !.safetyFlagsPresent = FALSE,
            !.inventoryAccepted = TRUE,
            !.badSafetyFlagsMissing = TRUE
        ]

UnsafeMissingAsNoObligation ==
    /\ ALLOW_UNSAFE_MISSING_AS_NO_OBLIGATION
    /\ state.phase = "RowsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadMissingAsNoObligation",
            !.missingAnchorNoObligation = TRUE,
            !.inventoryAccepted = TRUE,
            !.badMissingAsNoObligation = TRUE
        ]

UnsafeAnchorAsAuthority ==
    /\ ALLOW_UNSAFE_ANCHOR_AS_AUTHORITY
    /\ state.phase = "RowsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadAnchorAsAuthority",
            !.anchorAuthority = TRUE,
            !.inventoryAccepted = TRUE,
            !.badAnchorAsAuthority = TRUE
        ]

UnsafeTraceAsAuthority ==
    /\ ALLOW_UNSAFE_TRACE_AS_AUTHORITY
    /\ state.phase = "RowsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadTraceAsAuthority",
            !.traceAuthority = TRUE,
            !.inventoryAccepted = TRUE,
            !.badTraceAsAuthority = TRUE
        ]

UnsafeRuntimeObservationClaim ==
    /\ ALLOW_UNSAFE_RUNTIME_OBSERVATION_CLAIM
    /\ state.phase = "RowsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRuntimeObservationClaim",
            !.runtimeObservationClaim = TRUE,
            !.inventoryAccepted = TRUE,
            !.badRuntimeObservationClaim = TRUE
        ]

UnsafeRawHandleExposure ==
    /\ ALLOW_UNSAFE_RAW_HANDLE_EXPOSURE
    /\ state.phase = "RowsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRawHandleExposure",
            !.rawHandleExposure = TRUE,
            !.inventoryAccepted = TRUE,
            !.badRawHandleExposure = TRUE
        ]

UnsafeMonitorVerified ==
    /\ ALLOW_UNSAFE_MONITOR_VERIFIED
    /\ state.phase = "RowsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadMonitorVerified",
            !.monitorVerified = TRUE,
            !.inventoryAccepted = TRUE,
            !.badMonitorVerified = TRUE
        ]

UnsafeProtectionClaim ==
    /\ ALLOW_UNSAFE_PROTECTION_CLAIM
    /\ state.phase = "RowsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadProtectionClaim",
            !.protectionClaim = TRUE,
            !.inventoryAccepted = TRUE,
            !.badProtectionClaim = TRUE
        ]

UnsafeBehaviorChange ==
    /\ ALLOW_UNSAFE_BEHAVIOR_CHANGE
    /\ state.phase = "RowsClassified"
    /\ state' =
        [state EXCEPT
            !.phase = "BadBehaviorChange",
            !.behaviorChange = TRUE,
            !.inventoryAccepted = TRUE,
            !.badBehaviorChange = TRUE
        ]

StutterAtTerminal ==
    /\ state.phase \in TerminalPhases
    /\ UNCHANGED state

Next ==
    \/ LoadContract
    \/ DeclareOutputs
    \/ ClassifyRows
    \/ AcceptInventory
    \/ UnsafeLinuxModification
    \/ UnsafeRootRequired
    \/ UnsafeTracefsWrite
    \/ UnsafePublicTracepointAbi
    \/ UnsafeProbeAttachment
    \/ UnsafeOutputIncomplete
    \/ UnsafeSafetyFlagsMissing
    \/ UnsafeMissingAsNoObligation
    \/ UnsafeAnchorAsAuthority
    \/ UnsafeTraceAsAuthority
    \/ UnsafeRuntimeObservationClaim
    \/ UnsafeRawHandleExposure
    \/ UnsafeMonitorVerified
    \/ UnsafeProtectionClaim
    \/ UnsafeBehaviorChange
    \/ StutterAtTerminal

AcceptanceRequiresOutputs ==
    state.inventoryAccepted =>
        (state.outputComplete /\ state.requiredFieldsPresent /\ state.safetyFlagsPresent)

AcceptanceRequiresGaps ==
    state.inventoryAccepted => state.missingRowsRecordedAsGaps

AcceptanceRequiresSourceOnly ==
    state.inventoryAccepted => state.sourceOnly

NoLinuxModification ==
    ~state.linuxModified

NoSourceOnlyRootRequirement ==
    ~state.sourceOnlyRequiresRoot

NoTracefsWrite ==
    ~state.tracefsWritten

NoPublicTracepointAbi ==
    ~state.publicTracepointAbi

NoProbeAttachment ==
    ~state.probesAttached

MissingAnchorsRemainObligations ==
    ~state.missingAnchorNoObligation

AnchorsAreNotAuthority ==
    ~state.anchorAuthority

TracePlanIsNotAuthority ==
    ~state.traceAuthority

NoRuntimeObservationClaim ==
    ~state.runtimeObservationClaim

NoRawHandleExposure ==
    ~state.rawHandleExposure

NoMonitorVerifiedClaim ==
    ~state.monitorVerified

NoProtectionClaim ==
    ~state.protectionClaim

NoBehaviorChange ==
    ~state.behaviorChange

NoBadLinuxModification == ~state.badLinuxModification

NoBadRootRequired == ~state.badRootRequired

NoBadTracefsWrite == ~state.badTracefsWrite

NoBadPublicTracepointAbi == ~state.badPublicTracepointAbi

NoBadProbeAttachment == ~state.badProbeAttachment

NoBadOutputIncomplete == ~state.badOutputIncomplete

NoBadSafetyFlagsMissing == ~state.badSafetyFlagsMissing

NoBadMissingAsNoObligation == ~state.badMissingAsNoObligation

NoBadAnchorAsAuthority == ~state.badAnchorAsAuthority

NoBadTraceAsAuthority == ~state.badTraceAsAuthority

NoBadRuntimeObservationClaim == ~state.badRuntimeObservationClaim

NoBadRawHandleExposure == ~state.badRawHandleExposure

NoBadMonitorVerified == ~state.badMonitorVerified

NoBadProtectionClaim == ~state.badProtectionClaim

NoBadBehaviorChange == ~state.badBehaviorChange

Spec == Init /\ [][Next]_vars

=============================================================================
