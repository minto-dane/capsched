-------------------- MODULE DirectCallSchemaCompatibility --------------------

CONSTANTS
    ALLOW_UNSAFE_UNSUPPORTED_SCHEMA_ACCEPT,
    ALLOW_UNSAFE_MONITOR_MIN_DOWNGRADE,
    ALLOW_UNSAFE_CALLER_MIN_DOWNGRADE,
    ALLOW_UNSAFE_UNKNOWN_MANDATORY_ACCEPT,
    ALLOW_UNSAFE_CRITICAL_OPTIONAL_IGNORE,
    ALLOW_UNSAFE_IGNORED_OPTIONAL_AUTHORITY,
    ALLOW_UNSAFE_MISSING_REQUIRED_FEATURE,
    ALLOW_UNSAFE_REQUIRED_SAFETY_STRIPPED,
    ALLOW_UNSAFE_RESPONSE_LEDGER_INCOMPATIBLE,
    ALLOW_UNSAFE_SHADOW_FROM_UNSUPPORTED_RESPONSE,
    ALLOW_UNSAFE_UNKNOWN_SUCCESS_CODE,
    ALLOW_UNSAFE_TRANSPORT_OBSERVATION_RECEIPT,
    ALLOW_UNSAFE_DIRECT_ONLY_SCHEMA_NAMESPACE

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "SchemaProposed",
    "AbiFamilyChecked",
    "SchemaSupported",
    "MinimumsSatisfied",
    "FieldsChecked",
    "NoncriticalOptionalIgnored",
    "FeaturesChecked",
    "ResponseLedgerSchemasChecked",
    "ErrorNamespaceChecked",
    "SchemaAccepted",
    "LedgerWritten",
    "ResponseReturned",
    "ShadowRefreshed",
    "TransportObservation",
    "TerminalSchemaFailure",
    "BadUnsupportedSchemaAccept",
    "BadMonitorMinDowngrade",
    "BadCallerMinDowngrade",
    "BadUnknownMandatoryAccept",
    "BadCriticalOptionalIgnore",
    "BadIgnoredOptionalAuthority",
    "BadMissingRequiredFeature",
    "BadRequiredSafetyStripped",
    "BadResponseLedgerIncompatible",
    "BadShadowFromUnsupportedResponse",
    "BadUnknownSuccessCode",
    "BadTransportObservationReceipt",
    "BadDirectOnlySchemaNamespace"
}

StateFields == {
    "phase",
    "abiFamilyMatched",
    "semanticSchemaSupported",
    "requestClassSchemaSupported",
    "responseSchemaCompatible",
    "ledgerSchemaCompatible",
    "errorNamespaceSupported",
    "monitorMinimumSatisfied",
    "callerMinimumSatisfied",
    "mandatoryFieldsKnown",
    "mandatoryFieldsPresent",
    "criticalUnknownOptionalAbsent",
    "forbiddenFieldsAbsent",
    "noncriticalOptionalIgnored",
    "ignoredOptionalRecorded",
    "ignoredOptionalAuthority",
    "requiredFeaturesSupported",
    "monitorRequiredFeaturesCovered",
    "requiredSafetyFeaturesPresent",
    "schemaAccepted",
    "sharedReplayReady",
    "ledgerWritten",
    "successResponse",
    "responseReturned",
    "shadowRefreshed",
    "shadowFromSupportedResponse",
    "transportObservation",
    "transportObservationAsReceipt",
    "terminalSchemaFailure",
    "unknownSuccessCode",
    "directOnlySchemaNamespace",
    "carrierNeutralSchemaNamespace",
    "badUnsupportedSchemaAccept",
    "badMonitorMinDowngrade",
    "badCallerMinDowngrade",
    "badUnknownMandatoryAccept",
    "badCriticalOptionalIgnore",
    "badIgnoredOptionalAuthority",
    "badMissingRequiredFeature",
    "badRequiredSafetyStripped",
    "badResponseLedgerIncompatible",
    "badShadowFromUnsupportedResponse",
    "badUnknownSuccessCode",
    "badTransportObservationReceipt",
    "badDirectOnlySchemaNamespace"
}

BoolFields == StateFields \ {"phase"}

TerminalPhases == {
    "ShadowRefreshed",
    "TransportObservation",
    "TerminalSchemaFailure",
    "BadUnsupportedSchemaAccept",
    "BadMonitorMinDowngrade",
    "BadCallerMinDowngrade",
    "BadUnknownMandatoryAccept",
    "BadCriticalOptionalIgnore",
    "BadIgnoredOptionalAuthority",
    "BadMissingRequiredFeature",
    "BadRequiredSafetyStripped",
    "BadResponseLedgerIncompatible",
    "BadShadowFromUnsupportedResponse",
    "BadUnknownSuccessCode",
    "BadTransportObservationReceipt",
    "BadDirectOnlySchemaNamespace"
}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        abiFamilyMatched |-> FALSE,
        semanticSchemaSupported |-> FALSE,
        requestClassSchemaSupported |-> FALSE,
        responseSchemaCompatible |-> FALSE,
        ledgerSchemaCompatible |-> FALSE,
        errorNamespaceSupported |-> FALSE,
        monitorMinimumSatisfied |-> FALSE,
        callerMinimumSatisfied |-> FALSE,
        mandatoryFieldsKnown |-> FALSE,
        mandatoryFieldsPresent |-> FALSE,
        criticalUnknownOptionalAbsent |-> FALSE,
        forbiddenFieldsAbsent |-> FALSE,
        noncriticalOptionalIgnored |-> FALSE,
        ignoredOptionalRecorded |-> FALSE,
        ignoredOptionalAuthority |-> FALSE,
        requiredFeaturesSupported |-> FALSE,
        monitorRequiredFeaturesCovered |-> FALSE,
        requiredSafetyFeaturesPresent |-> FALSE,
        schemaAccepted |-> FALSE,
        sharedReplayReady |-> FALSE,
        ledgerWritten |-> FALSE,
        successResponse |-> FALSE,
        responseReturned |-> FALSE,
        shadowRefreshed |-> FALSE,
        shadowFromSupportedResponse |-> FALSE,
        transportObservation |-> FALSE,
        transportObservationAsReceipt |-> FALSE,
        terminalSchemaFailure |-> FALSE,
        unknownSuccessCode |-> FALSE,
        directOnlySchemaNamespace |-> FALSE,
        carrierNeutralSchemaNamespace |-> FALSE,
        badUnsupportedSchemaAccept |-> FALSE,
        badMonitorMinDowngrade |-> FALSE,
        badCallerMinDowngrade |-> FALSE,
        badUnknownMandatoryAccept |-> FALSE,
        badCriticalOptionalIgnore |-> FALSE,
        badIgnoredOptionalAuthority |-> FALSE,
        badMissingRequiredFeature |-> FALSE,
        badRequiredSafetyStripped |-> FALSE,
        badResponseLedgerIncompatible |-> FALSE,
        badShadowFromUnsupportedResponse |-> FALSE,
        badUnknownSuccessCode |-> FALSE,
        badTransportObservationReceipt |-> FALSE,
        badDirectOnlySchemaNamespace |-> FALSE
    ]

ProposeSchema ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "SchemaProposed",
            !.carrierNeutralSchemaNamespace = TRUE
        ]

CheckAbiFamily ==
    /\ state.phase = "SchemaProposed"
    /\ state' =
        [state EXCEPT
            !.phase = "AbiFamilyChecked",
            !.abiFamilyMatched = TRUE
        ]

CheckSchemaSupported ==
    /\ state.phase = "AbiFamilyChecked"
    /\ state.abiFamilyMatched
    /\ state' =
        [state EXCEPT
            !.phase = "SchemaSupported",
            !.semanticSchemaSupported = TRUE,
            !.requestClassSchemaSupported = TRUE
        ]

CheckMinimums ==
    /\ state.phase = "SchemaSupported"
    /\ state.semanticSchemaSupported
    /\ state.requestClassSchemaSupported
    /\ state' =
        [state EXCEPT
            !.phase = "MinimumsSatisfied",
            !.monitorMinimumSatisfied = TRUE,
            !.callerMinimumSatisfied = TRUE
        ]

CheckFields ==
    /\ state.phase = "MinimumsSatisfied"
    /\ state.monitorMinimumSatisfied
    /\ state.callerMinimumSatisfied
    /\ state' =
        [state EXCEPT
            !.phase = "FieldsChecked",
            !.mandatoryFieldsKnown = TRUE,
            !.mandatoryFieldsPresent = TRUE,
            !.criticalUnknownOptionalAbsent = TRUE,
            !.forbiddenFieldsAbsent = TRUE
        ]

IgnoreNoncriticalOptional ==
    /\ state.phase = "FieldsChecked"
    /\ state.mandatoryFieldsKnown
    /\ state.mandatoryFieldsPresent
    /\ state.criticalUnknownOptionalAbsent
    /\ state.forbiddenFieldsAbsent
    /\ state' =
        [state EXCEPT
            !.phase = "NoncriticalOptionalIgnored",
            !.noncriticalOptionalIgnored = TRUE,
            !.ignoredOptionalRecorded = TRUE
        ]

CheckFeatures ==
    /\ state.phase \in {"FieldsChecked", "NoncriticalOptionalIgnored"}
    /\ state.mandatoryFieldsKnown
    /\ state.mandatoryFieldsPresent
    /\ state.criticalUnknownOptionalAbsent
    /\ state.forbiddenFieldsAbsent
    /\ state' =
        [state EXCEPT
            !.phase = "FeaturesChecked",
            !.requiredFeaturesSupported = TRUE,
            !.monitorRequiredFeaturesCovered = TRUE,
            !.requiredSafetyFeaturesPresent = TRUE
        ]

CheckResponseLedgerSchemas ==
    /\ state.phase = "FeaturesChecked"
    /\ state.requiredFeaturesSupported
    /\ state.monitorRequiredFeaturesCovered
    /\ state.requiredSafetyFeaturesPresent
    /\ state' =
        [state EXCEPT
            !.phase = "ResponseLedgerSchemasChecked",
            !.responseSchemaCompatible = TRUE,
            !.ledgerSchemaCompatible = TRUE
        ]

CheckErrorNamespace ==
    /\ state.phase = "ResponseLedgerSchemasChecked"
    /\ state.responseSchemaCompatible
    /\ state.ledgerSchemaCompatible
    /\ state' =
        [state EXCEPT
            !.phase = "ErrorNamespaceChecked",
            !.errorNamespaceSupported = TRUE
        ]

AcceptSchema ==
    /\ state.phase = "ErrorNamespaceChecked"
    /\ state.errorNamespaceSupported
    /\ state.responseSchemaCompatible
    /\ state.ledgerSchemaCompatible
    /\ state.carrierNeutralSchemaNamespace
    /\ state' =
        [state EXCEPT
            !.phase = "SchemaAccepted",
            !.schemaAccepted = TRUE,
            !.sharedReplayReady = TRUE
        ]

WriteLedger ==
    /\ state.phase = "SchemaAccepted"
    /\ state.schemaAccepted
    /\ state.sharedReplayReady
    /\ state' =
        [state EXCEPT
            !.phase = "LedgerWritten",
            !.ledgerWritten = TRUE
        ]

ReturnSuccessResponse ==
    /\ state.phase = "LedgerWritten"
    /\ state.ledgerWritten
    /\ state.responseSchemaCompatible
    /\ state.ledgerSchemaCompatible
    /\ state.errorNamespaceSupported
    /\ state' =
        [state EXCEPT
            !.phase = "ResponseReturned",
            !.responseReturned = TRUE,
            !.successResponse = TRUE
        ]

RefreshShadow ==
    /\ state.phase = "ResponseReturned"
    /\ state.responseReturned
    /\ state.responseSchemaCompatible
    /\ state.ledgerWritten
    /\ state' =
        [state EXCEPT
            !.phase = "ShadowRefreshed",
            !.shadowRefreshed = TRUE,
            !.shadowFromSupportedResponse = TRUE
        ]

ObserveTransport ==
    /\ state.phase = "SchemaProposed"
    /\ state' =
        [state EXCEPT
            !.phase = "TransportObservation",
            !.transportObservation = TRUE
        ]

TerminalSchemaFailure ==
    /\ state.phase \in {"AbiFamilyChecked", "SchemaSupported", "MinimumsSatisfied", "FieldsChecked", "FeaturesChecked"}
    /\ state' =
        [state EXCEPT
            !.phase = "TerminalSchemaFailure",
            !.terminalSchemaFailure = TRUE
        ]

UnsafeUnsupportedSchemaAccept ==
    /\ ALLOW_UNSAFE_UNSUPPORTED_SCHEMA_ACCEPT
    /\ state.phase = "AbiFamilyChecked"
    /\ state' =
        [state EXCEPT
            !.phase = "BadUnsupportedSchemaAccept",
            !.schemaAccepted = TRUE,
            !.successResponse = TRUE,
            !.badUnsupportedSchemaAccept = TRUE
        ]

UnsafeMonitorMinDowngrade ==
    /\ ALLOW_UNSAFE_MONITOR_MIN_DOWNGRADE
    /\ state.phase = "SchemaSupported"
    /\ state' =
        [state EXCEPT
            !.phase = "BadMonitorMinDowngrade",
            !.semanticSchemaSupported = TRUE,
            !.requestClassSchemaSupported = TRUE,
            !.callerMinimumSatisfied = TRUE,
            !.schemaAccepted = TRUE,
            !.successResponse = TRUE,
            !.badMonitorMinDowngrade = TRUE
        ]

UnsafeCallerMinDowngrade ==
    /\ ALLOW_UNSAFE_CALLER_MIN_DOWNGRADE
    /\ state.phase = "SchemaSupported"
    /\ state' =
        [state EXCEPT
            !.phase = "BadCallerMinDowngrade",
            !.semanticSchemaSupported = TRUE,
            !.requestClassSchemaSupported = TRUE,
            !.monitorMinimumSatisfied = TRUE,
            !.schemaAccepted = TRUE,
            !.successResponse = TRUE,
            !.badCallerMinDowngrade = TRUE
        ]

UnsafeUnknownMandatoryAccept ==
    /\ ALLOW_UNSAFE_UNKNOWN_MANDATORY_ACCEPT
    /\ state.phase = "MinimumsSatisfied"
    /\ state' =
        [state EXCEPT
            !.phase = "BadUnknownMandatoryAccept",
            !.mandatoryFieldsKnown = FALSE,
            !.mandatoryFieldsPresent = FALSE,
            !.schemaAccepted = TRUE,
            !.successResponse = TRUE,
            !.badUnknownMandatoryAccept = TRUE
        ]

UnsafeCriticalOptionalIgnore ==
    /\ ALLOW_UNSAFE_CRITICAL_OPTIONAL_IGNORE
    /\ state.phase = "FieldsChecked"
    /\ state' =
        [state EXCEPT
            !.phase = "BadCriticalOptionalIgnore",
            !.criticalUnknownOptionalAbsent = FALSE,
            !.schemaAccepted = TRUE,
            !.successResponse = TRUE,
            !.badCriticalOptionalIgnore = TRUE
        ]

UnsafeIgnoredOptionalAuthority ==
    /\ ALLOW_UNSAFE_IGNORED_OPTIONAL_AUTHORITY
    /\ state.phase = "NoncriticalOptionalIgnored"
    /\ state.noncriticalOptionalIgnored
    /\ state' =
        [state EXCEPT
            !.phase = "BadIgnoredOptionalAuthority",
            !.ignoredOptionalAuthority = TRUE,
            !.successResponse = TRUE,
            !.badIgnoredOptionalAuthority = TRUE
        ]

UnsafeMissingRequiredFeature ==
    /\ ALLOW_UNSAFE_MISSING_REQUIRED_FEATURE
    /\ state.phase = "FieldsChecked"
    /\ state' =
        [state EXCEPT
            !.phase = "BadMissingRequiredFeature",
            !.requiredFeaturesSupported = FALSE,
            !.monitorRequiredFeaturesCovered = FALSE,
            !.schemaAccepted = TRUE,
            !.successResponse = TRUE,
            !.badMissingRequiredFeature = TRUE
        ]

UnsafeRequiredSafetyStripped ==
    /\ ALLOW_UNSAFE_REQUIRED_SAFETY_STRIPPED
    /\ state.phase = "FeaturesChecked"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRequiredSafetyStripped",
            !.requiredSafetyFeaturesPresent = FALSE,
            !.schemaAccepted = TRUE,
            !.successResponse = TRUE,
            !.badRequiredSafetyStripped = TRUE
        ]

UnsafeResponseLedgerIncompatible ==
    /\ ALLOW_UNSAFE_RESPONSE_LEDGER_INCOMPATIBLE
    /\ state.phase = "FeaturesChecked"
    /\ state' =
        [state EXCEPT
            !.phase = "BadResponseLedgerIncompatible",
            !.responseSchemaCompatible = FALSE,
            !.ledgerSchemaCompatible = FALSE,
            !.schemaAccepted = TRUE,
            !.successResponse = TRUE,
            !.badResponseLedgerIncompatible = TRUE
        ]

UnsafeShadowFromUnsupportedResponse ==
    /\ ALLOW_UNSAFE_SHADOW_FROM_UNSUPPORTED_RESPONSE
    /\ state.phase = "ResponseReturned"
    /\ state' =
        [state EXCEPT
            !.phase = "BadShadowFromUnsupportedResponse",
            !.responseSchemaCompatible = FALSE,
            !.shadowRefreshed = TRUE,
            !.badShadowFromUnsupportedResponse = TRUE
        ]

UnsafeUnknownSuccessCode ==
    /\ ALLOW_UNSAFE_UNKNOWN_SUCCESS_CODE
    /\ state.phase = "ErrorNamespaceChecked"
    /\ state' =
        [state EXCEPT
            !.phase = "BadUnknownSuccessCode",
            !.unknownSuccessCode = TRUE,
            !.successResponse = TRUE,
            !.badUnknownSuccessCode = TRUE
        ]

UnsafeTransportObservationReceipt ==
    /\ ALLOW_UNSAFE_TRANSPORT_OBSERVATION_RECEIPT
    /\ state.phase = "TransportObservation"
    /\ state.transportObservation
    /\ state' =
        [state EXCEPT
            !.phase = "BadTransportObservationReceipt",
            !.transportObservationAsReceipt = TRUE,
            !.successResponse = TRUE,
            !.badTransportObservationReceipt = TRUE
        ]

UnsafeDirectOnlySchemaNamespace ==
    /\ ALLOW_UNSAFE_DIRECT_ONLY_SCHEMA_NAMESPACE
    /\ state.phase = "SchemaAccepted"
    /\ state.schemaAccepted
    /\ state' =
        [state EXCEPT
            !.phase = "BadDirectOnlySchemaNamespace",
            !.directOnlySchemaNamespace = TRUE,
            !.carrierNeutralSchemaNamespace = FALSE,
            !.badDirectOnlySchemaNamespace = TRUE
        ]

StutterAtTerminal ==
    /\ state.phase \in TerminalPhases
    /\ UNCHANGED state

Next ==
    \/ ProposeSchema
    \/ CheckAbiFamily
    \/ CheckSchemaSupported
    \/ CheckMinimums
    \/ CheckFields
    \/ IgnoreNoncriticalOptional
    \/ CheckFeatures
    \/ CheckResponseLedgerSchemas
    \/ CheckErrorNamespace
    \/ AcceptSchema
    \/ WriteLedger
    \/ ReturnSuccessResponse
    \/ RefreshShadow
    \/ ObserveTransport
    \/ TerminalSchemaFailure
    \/ UnsafeUnsupportedSchemaAccept
    \/ UnsafeMonitorMinDowngrade
    \/ UnsafeCallerMinDowngrade
    \/ UnsafeUnknownMandatoryAccept
    \/ UnsafeCriticalOptionalIgnore
    \/ UnsafeIgnoredOptionalAuthority
    \/ UnsafeMissingRequiredFeature
    \/ UnsafeRequiredSafetyStripped
    \/ UnsafeResponseLedgerIncompatible
    \/ UnsafeShadowFromUnsupportedResponse
    \/ UnsafeUnknownSuccessCode
    \/ UnsafeTransportObservationReceipt
    \/ UnsafeDirectOnlySchemaNamespace
    \/ StutterAtTerminal

AcceptRequiresSupportedSchemas ==
    state.schemaAccepted =>
        (state.abiFamilyMatched /\ state.semanticSchemaSupported /\
         state.requestClassSchemaSupported)

AcceptRequiresMinimums ==
    state.schemaAccepted =>
        (state.monitorMinimumSatisfied /\ state.callerMinimumSatisfied)

AcceptRequiresKnownMandatoryFields ==
    state.schemaAccepted =>
        (state.mandatoryFieldsKnown /\ state.mandatoryFieldsPresent /\
         state.forbiddenFieldsAbsent)

AcceptRejectsCriticalUnknownOptional ==
    state.schemaAccepted => state.criticalUnknownOptionalAbsent

IgnoredOptionalIsNotAuthority ==
    ~state.ignoredOptionalAuthority

AcceptRequiresRequiredFeatures ==
    state.schemaAccepted =>
        (state.requiredFeaturesSupported /\ state.monitorRequiredFeaturesCovered)

NoRequiredSafetyFeatureDowngrade ==
    state.schemaAccepted => state.requiredSafetyFeaturesPresent

SuccessRequiresCompatibleResponseLedger ==
    state.successResponse =>
        (state.responseSchemaCompatible /\ state.ledgerSchemaCompatible /\
         state.errorNamespaceSupported)

ShadowRequiresSupportedResponse ==
    state.shadowRefreshed =>
        (state.responseSchemaCompatible /\ state.ledgerWritten /\
         state.shadowFromSupportedResponse)

UnknownSuccessCodeIsNotAuthority ==
    ~state.unknownSuccessCode

TransportObservationIsNotReceipt ==
    ~(state.transportObservationAsReceipt /\ state.successResponse)

SchemaNamespaceRemainsCarrierNeutral ==
    state.schemaAccepted =>
        (state.carrierNeutralSchemaNamespace /\ ~state.directOnlySchemaNamespace)

TerminalSchemaFailureIsNotSuccess ==
    state.terminalSchemaFailure => ~state.successResponse

NoBadUnsupportedSchemaAccept == ~state.badUnsupportedSchemaAccept

NoBadMonitorMinDowngrade == ~state.badMonitorMinDowngrade

NoBadCallerMinDowngrade == ~state.badCallerMinDowngrade

NoBadUnknownMandatoryAccept == ~state.badUnknownMandatoryAccept

NoBadCriticalOptionalIgnore == ~state.badCriticalOptionalIgnore

NoBadIgnoredOptionalAuthority == ~state.badIgnoredOptionalAuthority

NoBadMissingRequiredFeature == ~state.badMissingRequiredFeature

NoBadRequiredSafetyStripped == ~state.badRequiredSafetyStripped

NoBadResponseLedgerIncompatible == ~state.badResponseLedgerIncompatible

NoBadShadowFromUnsupportedResponse == ~state.badShadowFromUnsupportedResponse

NoBadUnknownSuccessCode == ~state.badUnknownSuccessCode

NoBadTransportObservationReceipt == ~state.badTransportObservationReceipt

NoBadDirectOnlySchemaNamespace == ~state.badDirectOnlySchemaNamespace

Spec == Init /\ [][Next]_vars

=============================================================================
