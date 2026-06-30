-------------------- MODULE RepresentorLowerQueueLease --------------------
EXTENDS Naturals

CONSTANTS
    ALLOW_UNSAFE_NETDEV_ONLY_FORWARD,
    ALLOW_UNSAFE_BRIDGE_FDB_AS_LOWER_LEASE,
    ALLOW_UNSAFE_VLAN_AS_LOWER_LEASE,
    ALLOW_UNSAFE_TC_OFFLOAD_WITHOUT_CONTROL,
    ALLOW_UNSAFE_TC_OFFLOAD_STALE_DEST,
    ALLOW_UNSAFE_LAG_FORWARD_WITH_STALE_LOWER,
    ALLOW_UNSAFE_FORWARD_AFTER_REVOKE,
    ALLOW_UNSAFE_REPR_STOP_ONLY_REVOKE

VARIABLES
    phase,
    reprNetdev,
    reprForwardCap,
    metadataFresh,
    lowerDevBound,
    lowerLeaseLive,
    lowerEpochFresh,
    lowerBudget,
    bridgeFdbHit,
    bridgeVlanAllowed,
    carrierFrozen,
    tcControlCap,
    tcRuleInstalled,
    lowerSubmit,
    hwForward,
    revoked,
    reprTxStopped,
    lowerLeaseRevoked,
    badNetdevOnly,
    badBridgeAsLease,
    badVlanAsLease,
    badTcNoControl,
    badTcStaleDest,
    badLagStaleLower,
    badForwardAfterRevoke,
    badStopOnlyRevoke

vars == <<phase, reprNetdev, reprForwardCap, metadataFresh, lowerDevBound,
          lowerLeaseLive, lowerEpochFresh, lowerBudget, bridgeFdbHit,
          bridgeVlanAllowed, carrierFrozen, tcControlCap, tcRuleInstalled,
          lowerSubmit, hwForward, revoked, reprTxStopped, lowerLeaseRevoked,
          badNetdevOnly, badBridgeAsLease, badVlanAsLease, badTcNoControl,
          badTcStaleDest, badLagStaleLower, badForwardAfterRevoke,
          badStopOnlyRevoke>>

Phases == {
    "Start",
    "Prepared",
    "CarrierFrozen",
    "SoftwareForwarded",
    "TcRuleInstalled",
    "HardwareForwarded",
    "LagChanged",
    "Revoked",
    "BadNetdevOnlyForward",
    "BadBridgeFdbAsLease",
    "BadVlanAsLease",
    "BadTcNoControl",
    "BadTcStaleDest",
    "BadLagStaleLower",
    "BadForwardAfterRevoke",
    "BadStopOnlyRevoke"
}

TypeOK ==
    /\ phase \in Phases
    /\ reprNetdev \in BOOLEAN
    /\ reprForwardCap \in BOOLEAN
    /\ metadataFresh \in BOOLEAN
    /\ lowerDevBound \in BOOLEAN
    /\ lowerLeaseLive \in BOOLEAN
    /\ lowerEpochFresh \in BOOLEAN
    /\ lowerBudget \in BOOLEAN
    /\ bridgeFdbHit \in BOOLEAN
    /\ bridgeVlanAllowed \in BOOLEAN
    /\ carrierFrozen \in BOOLEAN
    /\ tcControlCap \in BOOLEAN
    /\ tcRuleInstalled \in BOOLEAN
    /\ lowerSubmit \in BOOLEAN
    /\ hwForward \in BOOLEAN
    /\ revoked \in BOOLEAN
    /\ reprTxStopped \in BOOLEAN
    /\ lowerLeaseRevoked \in BOOLEAN
    /\ badNetdevOnly \in BOOLEAN
    /\ badBridgeAsLease \in BOOLEAN
    /\ badVlanAsLease \in BOOLEAN
    /\ badTcNoControl \in BOOLEAN
    /\ badTcStaleDest \in BOOLEAN
    /\ badLagStaleLower \in BOOLEAN
    /\ badForwardAfterRevoke \in BOOLEAN
    /\ badStopOnlyRevoke \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ reprNetdev = FALSE
    /\ reprForwardCap = FALSE
    /\ metadataFresh = FALSE
    /\ lowerDevBound = FALSE
    /\ lowerLeaseLive = FALSE
    /\ lowerEpochFresh = FALSE
    /\ lowerBudget = FALSE
    /\ bridgeFdbHit = FALSE
    /\ bridgeVlanAllowed = FALSE
    /\ carrierFrozen = FALSE
    /\ tcControlCap = FALSE
    /\ tcRuleInstalled = FALSE
    /\ lowerSubmit = FALSE
    /\ hwForward = FALSE
    /\ revoked = FALSE
    /\ reprTxStopped = FALSE
    /\ lowerLeaseRevoked = FALSE
    /\ badNetdevOnly = FALSE
    /\ badBridgeAsLease = FALSE
    /\ badVlanAsLease = FALSE
    /\ badTcNoControl = FALSE
    /\ badTcStaleDest = FALSE
    /\ badLagStaleLower = FALSE
    /\ badForwardAfterRevoke = FALSE
    /\ badStopOnlyRevoke = FALSE

PrepareRepresentor ==
    /\ phase = "Start"
    /\ phase' = "Prepared"
    /\ reprNetdev' = TRUE
    /\ reprForwardCap' = TRUE
    /\ metadataFresh' = TRUE
    /\ lowerDevBound' = TRUE
    /\ lowerLeaseLive' = TRUE
    /\ lowerEpochFresh' = TRUE
    /\ lowerBudget' = TRUE
    /\ bridgeFdbHit' = TRUE
    /\ bridgeVlanAllowed' = TRUE
    /\ tcControlCap' = TRUE
    /\ UNCHANGED <<carrierFrozen, tcRuleInstalled, lowerSubmit, hwForward,
                    revoked, reprTxStopped, lowerLeaseRevoked,
                    badNetdevOnly, badBridgeAsLease, badVlanAsLease,
                    badTcNoControl, badTcStaleDest, badLagStaleLower,
                    badForwardAfterRevoke, badStopOnlyRevoke>>

FreezeRepresentorForward ==
    /\ phase = "Prepared"
    /\ reprNetdev
    /\ reprForwardCap
    /\ metadataFresh
    /\ lowerDevBound
    /\ lowerLeaseLive
    /\ lowerEpochFresh
    /\ lowerBudget
    /\ bridgeFdbHit
    /\ bridgeVlanAllowed
    /\ phase' = "CarrierFrozen"
    /\ carrierFrozen' = TRUE
    /\ UNCHANGED <<reprNetdev, reprForwardCap, metadataFresh, lowerDevBound,
                    lowerLeaseLive, lowerEpochFresh, lowerBudget,
                    bridgeFdbHit, bridgeVlanAllowed, tcControlCap,
                    tcRuleInstalled, lowerSubmit, hwForward, revoked,
                    reprTxStopped, lowerLeaseRevoked, badNetdevOnly,
                    badBridgeAsLease, badVlanAsLease, badTcNoControl,
                    badTcStaleDest, badLagStaleLower, badForwardAfterRevoke,
                    badStopOnlyRevoke>>

SoftwareForward ==
    /\ phase = "CarrierFrozen"
    /\ carrierFrozen
    /\ phase' = "SoftwareForwarded"
    /\ lowerSubmit' = TRUE
    /\ UNCHANGED <<reprNetdev, reprForwardCap, metadataFresh, lowerDevBound,
                    lowerLeaseLive, lowerEpochFresh, lowerBudget,
                    bridgeFdbHit, bridgeVlanAllowed, carrierFrozen,
                    tcControlCap, tcRuleInstalled, hwForward, revoked,
                    reprTxStopped, lowerLeaseRevoked, badNetdevOnly,
                    badBridgeAsLease, badVlanAsLease, badTcNoControl,
                    badTcStaleDest, badLagStaleLower, badForwardAfterRevoke,
                    badStopOnlyRevoke>>

InstallTcOffload ==
    /\ phase = "Prepared"
    /\ tcControlCap
    /\ lowerLeaseLive
    /\ lowerEpochFresh
    /\ lowerDevBound
    /\ bridgeFdbHit
    /\ bridgeVlanAllowed
    /\ phase' = "TcRuleInstalled"
    /\ tcRuleInstalled' = TRUE
    /\ UNCHANGED <<reprNetdev, reprForwardCap, metadataFresh, lowerDevBound,
                    lowerLeaseLive, lowerEpochFresh, lowerBudget,
                    bridgeFdbHit, bridgeVlanAllowed, carrierFrozen,
                    tcControlCap, lowerSubmit, hwForward, revoked,
                    reprTxStopped, lowerLeaseRevoked, badNetdevOnly,
                    badBridgeAsLease, badVlanAsLease, badTcNoControl,
                    badTcStaleDest, badLagStaleLower, badForwardAfterRevoke,
                    badStopOnlyRevoke>>

HardwareForward ==
    /\ phase = "TcRuleInstalled"
    /\ tcRuleInstalled
    /\ lowerLeaseLive
    /\ lowerEpochFresh
    /\ lowerDevBound
    /\ phase' = "HardwareForwarded"
    /\ hwForward' = TRUE
    /\ UNCHANGED <<reprNetdev, reprForwardCap, metadataFresh, lowerDevBound,
                    lowerLeaseLive, lowerEpochFresh, lowerBudget,
                    bridgeFdbHit, bridgeVlanAllowed, carrierFrozen,
                    tcControlCap, tcRuleInstalled, lowerSubmit, revoked,
                    reprTxStopped, lowerLeaseRevoked, badNetdevOnly,
                    badBridgeAsLease, badVlanAsLease, badTcNoControl,
                    badTcStaleDest, badLagStaleLower, badForwardAfterRevoke,
                    badStopOnlyRevoke>>

LagLowerDevChange ==
    /\ phase = "Prepared"
    /\ phase' = "LagChanged"
    /\ metadataFresh' = FALSE
    /\ lowerDevBound' = FALSE
    /\ UNCHANGED <<reprNetdev, reprForwardCap, lowerLeaseLive,
                    lowerEpochFresh, lowerBudget, bridgeFdbHit,
                    bridgeVlanAllowed, carrierFrozen, tcControlCap,
                    tcRuleInstalled, lowerSubmit, hwForward, revoked,
                    reprTxStopped, lowerLeaseRevoked, badNetdevOnly,
                    badBridgeAsLease, badVlanAsLease, badTcNoControl,
                    badTcStaleDest, badLagStaleLower, badForwardAfterRevoke,
                    badStopOnlyRevoke>>

RebindAfterLag ==
    /\ phase = "LagChanged"
    /\ lowerLeaseLive
    /\ lowerEpochFresh
    /\ phase' = "Prepared"
    /\ metadataFresh' = TRUE
    /\ lowerDevBound' = TRUE
    /\ UNCHANGED <<reprNetdev, reprForwardCap, lowerLeaseLive,
                    lowerEpochFresh, lowerBudget, bridgeFdbHit,
                    bridgeVlanAllowed, carrierFrozen, tcControlCap,
                    tcRuleInstalled, lowerSubmit, hwForward, revoked,
                    reprTxStopped, lowerLeaseRevoked, badNetdevOnly,
                    badBridgeAsLease, badVlanAsLease, badTcNoControl,
                    badTcStaleDest, badLagStaleLower, badForwardAfterRevoke,
                    badStopOnlyRevoke>>

RevokeRepresentorAndLower ==
    /\ phase \in {"Prepared", "CarrierFrozen", "SoftwareForwarded",
                  "TcRuleInstalled", "HardwareForwarded", "LagChanged"}
    /\ phase' = "Revoked"
    /\ reprForwardCap' = FALSE
    /\ metadataFresh' = FALSE
    /\ lowerDevBound' = FALSE
    /\ lowerLeaseLive' = FALSE
    /\ lowerEpochFresh' = FALSE
    /\ lowerBudget' = FALSE
    /\ carrierFrozen' = FALSE
    /\ tcControlCap' = FALSE
    /\ tcRuleInstalled' = FALSE
    /\ lowerSubmit' = FALSE
    /\ hwForward' = FALSE
    /\ revoked' = TRUE
    /\ reprTxStopped' = TRUE
    /\ lowerLeaseRevoked' = TRUE
    /\ UNCHANGED <<reprNetdev, bridgeFdbHit, bridgeVlanAllowed,
                    badNetdevOnly, badBridgeAsLease, badVlanAsLease,
                    badTcNoControl, badTcStaleDest, badLagStaleLower,
                    badForwardAfterRevoke, badStopOnlyRevoke>>

UnsafeNetdevOnlyForward ==
    /\ ALLOW_UNSAFE_NETDEV_ONLY_FORWARD
    /\ phase = "Prepared"
    /\ phase' = "BadNetdevOnlyForward"
    /\ carrierFrozen' = FALSE
    /\ lowerSubmit' = TRUE
    /\ badNetdevOnly' = TRUE
    /\ UNCHANGED <<reprNetdev, reprForwardCap, metadataFresh, lowerDevBound,
                    lowerLeaseLive, lowerEpochFresh, lowerBudget,
                    bridgeFdbHit, bridgeVlanAllowed, tcControlCap,
                    tcRuleInstalled, hwForward, revoked, reprTxStopped,
                    lowerLeaseRevoked, badBridgeAsLease, badVlanAsLease,
                    badTcNoControl, badTcStaleDest, badLagStaleLower,
                    badForwardAfterRevoke, badStopOnlyRevoke>>

UnsafeBridgeFdbAsLowerLease ==
    /\ ALLOW_UNSAFE_BRIDGE_FDB_AS_LOWER_LEASE
    /\ phase = "Prepared"
    /\ phase' = "BadBridgeFdbAsLease"
    /\ reprForwardCap' = FALSE
    /\ carrierFrozen' = TRUE
    /\ lowerLeaseLive' = FALSE
    /\ lowerEpochFresh' = FALSE
    /\ lowerSubmit' = TRUE
    /\ badBridgeAsLease' = TRUE
    /\ UNCHANGED <<reprNetdev, metadataFresh, lowerDevBound, lowerBudget,
                    bridgeFdbHit, bridgeVlanAllowed, tcControlCap,
                    tcRuleInstalled, hwForward, revoked, reprTxStopped,
                    lowerLeaseRevoked, badNetdevOnly, badVlanAsLease,
                    badTcNoControl, badTcStaleDest, badLagStaleLower,
                    badForwardAfterRevoke, badStopOnlyRevoke>>

UnsafeVlanAsLowerLease ==
    /\ ALLOW_UNSAFE_VLAN_AS_LOWER_LEASE
    /\ phase = "Prepared"
    /\ phase' = "BadVlanAsLease"
    /\ reprForwardCap' = FALSE
    /\ carrierFrozen' = TRUE
    /\ lowerLeaseLive' = FALSE
    /\ lowerEpochFresh' = FALSE
    /\ lowerSubmit' = TRUE
    /\ badVlanAsLease' = TRUE
    /\ UNCHANGED <<reprNetdev, metadataFresh, lowerDevBound, lowerBudget,
                    bridgeFdbHit, bridgeVlanAllowed, tcControlCap,
                    tcRuleInstalled, hwForward, revoked, reprTxStopped,
                    lowerLeaseRevoked, badNetdevOnly, badBridgeAsLease,
                    badTcNoControl, badTcStaleDest, badLagStaleLower,
                    badForwardAfterRevoke, badStopOnlyRevoke>>

UnsafeTcOffloadWithoutControl ==
    /\ ALLOW_UNSAFE_TC_OFFLOAD_WITHOUT_CONTROL
    /\ phase = "Prepared"
    /\ phase' = "BadTcNoControl"
    /\ tcControlCap' = FALSE
    /\ tcRuleInstalled' = TRUE
    /\ badTcNoControl' = TRUE
    /\ UNCHANGED <<reprNetdev, reprForwardCap, metadataFresh, lowerDevBound,
                    lowerLeaseLive, lowerEpochFresh, lowerBudget,
                    bridgeFdbHit, bridgeVlanAllowed, carrierFrozen,
                    lowerSubmit, hwForward, revoked, reprTxStopped,
                    lowerLeaseRevoked, badNetdevOnly, badBridgeAsLease,
                    badVlanAsLease, badTcStaleDest, badLagStaleLower,
                    badForwardAfterRevoke, badStopOnlyRevoke>>

UnsafeTcOffloadStaleDest ==
    /\ ALLOW_UNSAFE_TC_OFFLOAD_STALE_DEST
    /\ phase = "LagChanged"
    /\ phase' = "BadTcStaleDest"
    /\ tcRuleInstalled' = TRUE
    /\ badTcStaleDest' = TRUE
    /\ UNCHANGED <<reprNetdev, reprForwardCap, metadataFresh, lowerDevBound,
                    lowerLeaseLive, lowerEpochFresh, lowerBudget,
                    bridgeFdbHit, bridgeVlanAllowed, carrierFrozen,
                    tcControlCap, lowerSubmit, hwForward, revoked,
                    reprTxStopped, lowerLeaseRevoked, badNetdevOnly,
                    badBridgeAsLease, badVlanAsLease, badTcNoControl,
                    badLagStaleLower, badForwardAfterRevoke,
                    badStopOnlyRevoke>>

UnsafeLagForwardWithStaleLower ==
    /\ ALLOW_UNSAFE_LAG_FORWARD_WITH_STALE_LOWER
    /\ phase = "LagChanged"
    /\ phase' = "BadLagStaleLower"
    /\ carrierFrozen' = TRUE
    /\ lowerSubmit' = TRUE
    /\ badLagStaleLower' = TRUE
    /\ UNCHANGED <<reprNetdev, reprForwardCap, metadataFresh, lowerDevBound,
                    lowerLeaseLive, lowerEpochFresh, lowerBudget,
                    bridgeFdbHit, bridgeVlanAllowed, tcControlCap,
                    tcRuleInstalled, hwForward, revoked, reprTxStopped,
                    lowerLeaseRevoked, badNetdevOnly, badBridgeAsLease,
                    badVlanAsLease, badTcNoControl, badTcStaleDest,
                    badForwardAfterRevoke, badStopOnlyRevoke>>

UnsafeForwardAfterRevoke ==
    /\ ALLOW_UNSAFE_FORWARD_AFTER_REVOKE
    /\ phase = "Revoked"
    /\ phase' = "BadForwardAfterRevoke"
    /\ lowerSubmit' = TRUE
    /\ hwForward' = TRUE
    /\ badForwardAfterRevoke' = TRUE
    /\ UNCHANGED <<reprNetdev, reprForwardCap, metadataFresh, lowerDevBound,
                    lowerLeaseLive, lowerEpochFresh, lowerBudget,
                    bridgeFdbHit, bridgeVlanAllowed, carrierFrozen,
                    tcControlCap, tcRuleInstalled, revoked, reprTxStopped,
                    lowerLeaseRevoked, badNetdevOnly, badBridgeAsLease,
                    badVlanAsLease, badTcNoControl, badTcStaleDest,
                    badLagStaleLower, badStopOnlyRevoke>>

UnsafeRepresentorStopOnlyRevoke ==
    /\ ALLOW_UNSAFE_REPR_STOP_ONLY_REVOKE
    /\ phase = "Prepared"
    /\ phase' = "BadStopOnlyRevoke"
    /\ revoked' = TRUE
    /\ reprTxStopped' = TRUE
    /\ lowerLeaseRevoked' = FALSE
    /\ badStopOnlyRevoke' = TRUE
    /\ UNCHANGED <<reprNetdev, reprForwardCap, metadataFresh, lowerDevBound,
                    lowerLeaseLive, lowerEpochFresh, lowerBudget,
                    bridgeFdbHit, bridgeVlanAllowed, carrierFrozen,
                    tcControlCap, tcRuleInstalled, lowerSubmit, hwForward,
                    badNetdevOnly, badBridgeAsLease, badVlanAsLease,
                    badTcNoControl, badTcStaleDest, badLagStaleLower,
                    badForwardAfterRevoke>>

Next ==
    \/ PrepareRepresentor
    \/ FreezeRepresentorForward
    \/ SoftwareForward
    \/ InstallTcOffload
    \/ HardwareForward
    \/ LagLowerDevChange
    \/ RebindAfterLag
    \/ RevokeRepresentorAndLower
    \/ UnsafeNetdevOnlyForward
    \/ UnsafeBridgeFdbAsLowerLease
    \/ UnsafeVlanAsLowerLease
    \/ UnsafeTcOffloadWithoutControl
    \/ UnsafeTcOffloadStaleDest
    \/ UnsafeLagForwardWithStaleLower
    \/ UnsafeForwardAfterRevoke
    \/ UnsafeRepresentorStopOnlyRevoke

Spec == Init /\ [][Next]_vars

NoSoftwareForwardWithoutLowerDerivation ==
    lowerSubmit =>
        /\ carrierFrozen
        /\ reprForwardCap
        /\ metadataFresh
        /\ lowerDevBound
        /\ lowerLeaseLive
        /\ lowerEpochFresh
        /\ lowerBudget
        /\ ~revoked

NoNetdevOnlyLowerForward ==
    ~badNetdevOnly

NoBridgeFdbAsLowerLease ==
    ~badBridgeAsLease

NoVlanAsLowerLease ==
    ~badVlanAsLease

NoTcOffloadWithoutControlAndLowerLease ==
    tcRuleInstalled =>
        /\ tcControlCap
        /\ lowerLeaseLive
        /\ lowerEpochFresh
        /\ lowerDevBound
        /\ ~revoked

NoHardwareForwardWithoutRuleAndLease ==
    hwForward =>
        /\ tcRuleInstalled
        /\ lowerLeaseLive
        /\ lowerEpochFresh
        /\ lowerDevBound
        /\ ~revoked

NoLagForwardWithStaleLowerDev ==
    /\ ~badLagStaleLower
    /\ (lowerSubmit => lowerDevBound)

NoLowerEffectAfterRevoke ==
    revoked =>
        /\ ~lowerSubmit
        /\ ~hwForward
        /\ ~tcRuleInstalled
        /\ ~badForwardAfterRevoke

NoRepresentorStopOnlyRevoke ==
    /\ ~badStopOnlyRevoke
    /\ ((revoked /\ reprTxStopped) => lowerLeaseRevoked)

=============================================================================
