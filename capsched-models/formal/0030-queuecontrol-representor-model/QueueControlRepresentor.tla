----------------------- MODULE QueueControlRepresentor -----------------------
EXTENDS Naturals

VARIABLES
    phase,
    queueLive,
    queueEpochFresh,
    lowerQueueLive,
    lowerQueueEpochFresh,
    queueControlCap,
    representorForwardCap,
    runCap,
    netdevReachable,
    devlinkReachable,
    controlBudget,
    serviceBudget,
    controlChanged,
    devlinkRateChanged,
    vfSfLifecycleChanged,
    representorMetadataSet,
    lowerSubmit,
    representorForwarded,
    revoked,
    controlViaRunCap,
    controlViaNetdev,
    forwardViaNetdev,
    staleLowerForward,
    forwardWithoutServiceBudget,
    controlAfterRevoke,
    forwardAfterRevoke

vars == <<phase, queueLive, queueEpochFresh, lowerQueueLive,
          lowerQueueEpochFresh, queueControlCap, representorForwardCap,
          runCap, netdevReachable, devlinkReachable, controlBudget,
          serviceBudget, controlChanged, devlinkRateChanged,
          vfSfLifecycleChanged, representorMetadataSet, lowerSubmit,
          representorForwarded, revoked, controlViaRunCap, controlViaNetdev,
          forwardViaNetdev, staleLowerForward, forwardWithoutServiceBudget,
          controlAfterRevoke, forwardAfterRevoke>>

Phases == {
    "Start",
    "ControlReady",
    "RepresentorReady",
    "Controlled",
    "Forwarded",
    "Revoked",
    "BadDevlinkViaRunCap",
    "BadDevlinkViaNetdev",
    "BadRepresentorNoCap",
    "BadRepresentorNoLowerLease",
    "BadRepresentorStaleLower",
    "BadRepresentorViaNetdev",
    "BadForwardNoServiceBudget",
    "BadControlAfterRevoke",
    "BadForwardAfterRevoke"
}

TypeOK ==
    /\ phase \in Phases
    /\ queueLive \in BOOLEAN
    /\ queueEpochFresh \in BOOLEAN
    /\ lowerQueueLive \in BOOLEAN
    /\ lowerQueueEpochFresh \in BOOLEAN
    /\ queueControlCap \in BOOLEAN
    /\ representorForwardCap \in BOOLEAN
    /\ runCap \in BOOLEAN
    /\ netdevReachable \in BOOLEAN
    /\ devlinkReachable \in BOOLEAN
    /\ controlBudget \in BOOLEAN
    /\ serviceBudget \in BOOLEAN
    /\ controlChanged \in BOOLEAN
    /\ devlinkRateChanged \in BOOLEAN
    /\ vfSfLifecycleChanged \in BOOLEAN
    /\ representorMetadataSet \in BOOLEAN
    /\ lowerSubmit \in BOOLEAN
    /\ representorForwarded \in BOOLEAN
    /\ revoked \in BOOLEAN
    /\ controlViaRunCap \in BOOLEAN
    /\ controlViaNetdev \in BOOLEAN
    /\ forwardViaNetdev \in BOOLEAN
    /\ staleLowerForward \in BOOLEAN
    /\ forwardWithoutServiceBudget \in BOOLEAN
    /\ controlAfterRevoke \in BOOLEAN
    /\ forwardAfterRevoke \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ queueLive = FALSE
    /\ queueEpochFresh = FALSE
    /\ lowerQueueLive = FALSE
    /\ lowerQueueEpochFresh = FALSE
    /\ queueControlCap = FALSE
    /\ representorForwardCap = FALSE
    /\ runCap = FALSE
    /\ netdevReachable = FALSE
    /\ devlinkReachable = FALSE
    /\ controlBudget = FALSE
    /\ serviceBudget = FALSE
    /\ controlChanged = FALSE
    /\ devlinkRateChanged = FALSE
    /\ vfSfLifecycleChanged = FALSE
    /\ representorMetadataSet = FALSE
    /\ lowerSubmit = FALSE
    /\ representorForwarded = FALSE
    /\ revoked = FALSE
    /\ controlViaRunCap = FALSE
    /\ controlViaNetdev = FALSE
    /\ forwardViaNetdev = FALSE
    /\ staleLowerForward = FALSE
    /\ forwardWithoutServiceBudget = FALSE
    /\ controlAfterRevoke = FALSE
    /\ forwardAfterRevoke = FALSE

PrepareQueueControl ==
    /\ phase = "Start"
    /\ queueLive' = TRUE
    /\ queueEpochFresh' = TRUE
    /\ queueControlCap' = TRUE
    /\ devlinkReachable' = TRUE
    /\ controlBudget' = TRUE
    /\ serviceBudget' = TRUE
    /\ phase' = "ControlReady"
    /\ UNCHANGED <<lowerQueueLive, lowerQueueEpochFresh,
                    representorForwardCap, runCap, netdevReachable,
                    controlChanged, devlinkRateChanged, vfSfLifecycleChanged,
                    representorMetadataSet, lowerSubmit, representorForwarded,
                    revoked, controlViaRunCap, controlViaNetdev,
                    forwardViaNetdev, staleLowerForward,
                    forwardWithoutServiceBudget, controlAfterRevoke,
                    forwardAfterRevoke>>

PrepareRepresentor ==
    /\ phase = "Start"
    /\ queueLive' = TRUE
    /\ queueEpochFresh' = TRUE
    /\ lowerQueueLive' = TRUE
    /\ lowerQueueEpochFresh' = TRUE
    /\ representorForwardCap' = TRUE
    /\ netdevReachable' = TRUE
    /\ serviceBudget' = TRUE
    /\ phase' = "RepresentorReady"
    /\ UNCHANGED <<queueControlCap, runCap, devlinkReachable, controlBudget,
                    controlChanged, devlinkRateChanged, vfSfLifecycleChanged,
                    representorMetadataSet, lowerSubmit, representorForwarded,
                    revoked, controlViaRunCap, controlViaNetdev,
                    forwardViaNetdev, staleLowerForward,
                    forwardWithoutServiceBudget, controlAfterRevoke,
                    forwardAfterRevoke>>

ApplyQueueControl ==
    /\ phase = "ControlReady"
    /\ queueLive
    /\ queueEpochFresh
    /\ queueControlCap
    /\ devlinkReachable
    /\ controlBudget
    /\ controlChanged' = TRUE
    /\ devlinkRateChanged' = TRUE
    /\ vfSfLifecycleChanged' = TRUE
    /\ controlBudget' = FALSE
    /\ phase' = "Controlled"
    /\ UNCHANGED <<queueLive, queueEpochFresh, lowerQueueLive,
                    lowerQueueEpochFresh, queueControlCap,
                    representorForwardCap, runCap, netdevReachable,
                    devlinkReachable, serviceBudget, representorMetadataSet,
                    lowerSubmit, representorForwarded, revoked,
                    controlViaRunCap, controlViaNetdev, forwardViaNetdev,
                    staleLowerForward, forwardWithoutServiceBudget,
                    controlAfterRevoke, forwardAfterRevoke>>

ForwardRepresentor ==
    /\ phase = "RepresentorReady"
    /\ queueLive
    /\ queueEpochFresh
    /\ lowerQueueLive
    /\ lowerQueueEpochFresh
    /\ representorForwardCap
    /\ netdevReachable
    /\ serviceBudget
    /\ representorMetadataSet' = TRUE
    /\ lowerSubmit' = TRUE
    /\ representorForwarded' = TRUE
    /\ phase' = "Forwarded"
    /\ UNCHANGED <<queueLive, queueEpochFresh, lowerQueueLive,
                    lowerQueueEpochFresh, queueControlCap,
                    representorForwardCap, runCap, netdevReachable,
                    devlinkReachable, controlBudget, serviceBudget,
                    controlChanged, devlinkRateChanged, vfSfLifecycleChanged,
                    revoked, controlViaRunCap, controlViaNetdev,
                    forwardViaNetdev, staleLowerForward,
                    forwardWithoutServiceBudget, controlAfterRevoke,
                    forwardAfterRevoke>>

Revoke ==
    /\ phase \in {"ControlReady", "RepresentorReady"}
    /\ queueLive
    /\ queueLive' = FALSE
    /\ queueEpochFresh' = FALSE
    /\ lowerQueueLive' = FALSE
    /\ lowerQueueEpochFresh' = FALSE
    /\ queueControlCap' = FALSE
    /\ representorForwardCap' = FALSE
    /\ controlBudget' = FALSE
    /\ serviceBudget' = FALSE
    /\ revoked' = TRUE
    /\ phase' = "Revoked"
    /\ UNCHANGED <<runCap, netdevReachable, devlinkReachable,
                    controlChanged, devlinkRateChanged, vfSfLifecycleChanged,
                    representorMetadataSet, lowerSubmit, representorForwarded,
                    controlViaRunCap, controlViaNetdev, forwardViaNetdev,
                    staleLowerForward, forwardWithoutServiceBudget,
                    controlAfterRevoke, forwardAfterRevoke>>

UnsafeDevlinkViaRunCap ==
    /\ phase = "ControlReady"
    /\ runCap' = TRUE
    /\ queueControlCap' = FALSE
    /\ controlViaRunCap' = TRUE
    /\ controlChanged' = TRUE
    /\ devlinkRateChanged' = TRUE
    /\ phase' = "BadDevlinkViaRunCap"
    /\ UNCHANGED <<queueLive, queueEpochFresh, lowerQueueLive,
                    lowerQueueEpochFresh, representorForwardCap,
                    netdevReachable, devlinkReachable, controlBudget,
                    serviceBudget, vfSfLifecycleChanged,
                    representorMetadataSet, lowerSubmit, representorForwarded,
                    revoked, controlViaNetdev, forwardViaNetdev,
                    staleLowerForward, forwardWithoutServiceBudget,
                    controlAfterRevoke, forwardAfterRevoke>>

UnsafeDevlinkViaNetdev ==
    /\ phase = "ControlReady"
    /\ netdevReachable' = TRUE
    /\ queueControlCap' = FALSE
    /\ controlViaNetdev' = TRUE
    /\ controlChanged' = TRUE
    /\ phase' = "BadDevlinkViaNetdev"
    /\ UNCHANGED <<queueLive, queueEpochFresh, lowerQueueLive,
                    lowerQueueEpochFresh, representorForwardCap, runCap,
                    devlinkReachable, controlBudget, serviceBudget,
                    devlinkRateChanged, vfSfLifecycleChanged,
                    representorMetadataSet, lowerSubmit, representorForwarded,
                    revoked, controlViaRunCap, forwardViaNetdev,
                    staleLowerForward, forwardWithoutServiceBudget,
                    controlAfterRevoke, forwardAfterRevoke>>

UnsafeRepresentorNoCap ==
    /\ phase = "RepresentorReady"
    /\ representorForwardCap' = FALSE
    /\ lowerSubmit' = TRUE
    /\ representorForwarded' = TRUE
    /\ phase' = "BadRepresentorNoCap"
    /\ UNCHANGED <<queueLive, queueEpochFresh, lowerQueueLive,
                    lowerQueueEpochFresh, queueControlCap, runCap,
                    netdevReachable, devlinkReachable, controlBudget,
                    serviceBudget, controlChanged, devlinkRateChanged,
                    vfSfLifecycleChanged, representorMetadataSet, revoked,
                    controlViaRunCap, controlViaNetdev, forwardViaNetdev,
                    staleLowerForward, forwardWithoutServiceBudget,
                    controlAfterRevoke, forwardAfterRevoke>>

UnsafeRepresentorNoLowerLease ==
    /\ phase = "RepresentorReady"
    /\ lowerQueueLive' = FALSE
    /\ lowerSubmit' = TRUE
    /\ representorForwarded' = TRUE
    /\ phase' = "BadRepresentorNoLowerLease"
    /\ UNCHANGED <<queueLive, queueEpochFresh, lowerQueueEpochFresh,
                    queueControlCap, representorForwardCap, runCap,
                    netdevReachable, devlinkReachable, controlBudget,
                    serviceBudget, controlChanged, devlinkRateChanged,
                    vfSfLifecycleChanged, representorMetadataSet, revoked,
                    controlViaRunCap, controlViaNetdev, forwardViaNetdev,
                    staleLowerForward, forwardWithoutServiceBudget,
                    controlAfterRevoke, forwardAfterRevoke>>

UnsafeRepresentorStaleLower ==
    /\ phase = "RepresentorReady"
    /\ lowerQueueEpochFresh' = FALSE
    /\ staleLowerForward' = TRUE
    /\ lowerSubmit' = TRUE
    /\ representorForwarded' = TRUE
    /\ phase' = "BadRepresentorStaleLower"
    /\ UNCHANGED <<queueLive, queueEpochFresh, lowerQueueLive,
                    queueControlCap, representorForwardCap, runCap,
                    netdevReachable, devlinkReachable, controlBudget,
                    serviceBudget, controlChanged, devlinkRateChanged,
                    vfSfLifecycleChanged, representorMetadataSet, revoked,
                    controlViaRunCap, controlViaNetdev, forwardViaNetdev,
                    forwardWithoutServiceBudget, controlAfterRevoke,
                    forwardAfterRevoke>>

UnsafeRepresentorViaNetdev ==
    /\ phase = "RepresentorReady"
    /\ netdevReachable
    /\ representorForwardCap' = FALSE
    /\ forwardViaNetdev' = TRUE
    /\ lowerSubmit' = TRUE
    /\ representorForwarded' = TRUE
    /\ phase' = "BadRepresentorViaNetdev"
    /\ UNCHANGED <<queueLive, queueEpochFresh, lowerQueueLive,
                    lowerQueueEpochFresh, queueControlCap, runCap,
                    netdevReachable, devlinkReachable, controlBudget,
                    serviceBudget, controlChanged, devlinkRateChanged,
                    vfSfLifecycleChanged, representorMetadataSet, revoked,
                    controlViaRunCap, controlViaNetdev, staleLowerForward,
                    forwardWithoutServiceBudget, controlAfterRevoke,
                    forwardAfterRevoke>>

UnsafeForwardNoServiceBudget ==
    /\ phase = "RepresentorReady"
    /\ serviceBudget' = FALSE
    /\ forwardWithoutServiceBudget' = TRUE
    /\ lowerSubmit' = TRUE
    /\ representorForwarded' = TRUE
    /\ phase' = "BadForwardNoServiceBudget"
    /\ UNCHANGED <<queueLive, queueEpochFresh, lowerQueueLive,
                    lowerQueueEpochFresh, queueControlCap,
                    representorForwardCap, runCap, netdevReachable,
                    devlinkReachable, controlBudget, controlChanged,
                    devlinkRateChanged, vfSfLifecycleChanged,
                    representorMetadataSet, revoked, controlViaRunCap,
                    controlViaNetdev, forwardViaNetdev, staleLowerForward,
                    controlAfterRevoke, forwardAfterRevoke>>

UnsafeControlAfterRevoke ==
    /\ phase = "ControlReady"
    /\ revoked' = TRUE
    /\ queueLive' = FALSE
    /\ controlChanged' = TRUE
    /\ controlAfterRevoke' = TRUE
    /\ phase' = "BadControlAfterRevoke"
    /\ UNCHANGED <<queueEpochFresh, lowerQueueLive, lowerQueueEpochFresh,
                    queueControlCap, representorForwardCap, runCap,
                    netdevReachable, devlinkReachable, controlBudget,
                    serviceBudget, devlinkRateChanged, vfSfLifecycleChanged,
                    representorMetadataSet, lowerSubmit, representorForwarded,
                    controlViaRunCap, controlViaNetdev, forwardViaNetdev,
                    staleLowerForward, forwardWithoutServiceBudget,
                    forwardAfterRevoke>>

UnsafeForwardAfterRevoke ==
    /\ phase = "RepresentorReady"
    /\ revoked' = TRUE
    /\ queueLive' = FALSE
    /\ lowerQueueLive' = FALSE
    /\ lowerSubmit' = TRUE
    /\ representorForwarded' = TRUE
    /\ forwardAfterRevoke' = TRUE
    /\ phase' = "BadForwardAfterRevoke"
    /\ UNCHANGED <<queueEpochFresh, lowerQueueEpochFresh, queueControlCap,
                    representorForwardCap, runCap, netdevReachable,
                    devlinkReachable, controlBudget, serviceBudget,
                    controlChanged, devlinkRateChanged, vfSfLifecycleChanged,
                    representorMetadataSet, controlViaRunCap,
                    controlViaNetdev, forwardViaNetdev, staleLowerForward,
                    forwardWithoutServiceBudget, controlAfterRevoke>>

SafeNext ==
    \/ PrepareQueueControl
    \/ PrepareRepresentor
    \/ ApplyQueueControl
    \/ ForwardRepresentor
    \/ Revoke

SafeSpec == Init /\ [][SafeNext]_vars

UnsafeDevlinkViaRunCapSpec == Init /\ [][SafeNext \/ UnsafeDevlinkViaRunCap]_vars
UnsafeDevlinkViaNetdevSpec == Init /\ [][SafeNext \/ UnsafeDevlinkViaNetdev]_vars
UnsafeRepresentorNoCapSpec == Init /\ [][SafeNext \/ UnsafeRepresentorNoCap]_vars
UnsafeRepresentorNoLowerLeaseSpec == Init /\ [][SafeNext \/ UnsafeRepresentorNoLowerLease]_vars
UnsafeRepresentorStaleLowerSpec == Init /\ [][SafeNext \/ UnsafeRepresentorStaleLower]_vars
UnsafeRepresentorViaNetdevSpec == Init /\ [][SafeNext \/ UnsafeRepresentorViaNetdev]_vars
UnsafeForwardNoServiceBudgetSpec == Init /\ [][SafeNext \/ UnsafeForwardNoServiceBudget]_vars
UnsafeControlAfterRevokeSpec == Init /\ [][SafeNext \/ UnsafeControlAfterRevoke]_vars
UnsafeForwardAfterRevokeSpec == Init /\ [][SafeNext \/ UnsafeForwardAfterRevoke]_vars

NoQueueControlWithoutCap ==
    controlChanged =>
        /\ queueLive
        /\ queueEpochFresh
        /\ queueControlCap
        /\ ~controlViaRunCap
        /\ ~controlViaNetdev

NoRunCapAsQueueControl ==
    ~controlViaRunCap

NoNetdevReachabilityAsQueueControl ==
    ~controlViaNetdev

NoRepresentorForwardWithoutDerivation ==
    representorForwarded =>
        /\ queueLive
        /\ queueEpochFresh
        /\ lowerQueueLive
        /\ lowerQueueEpochFresh
        /\ representorForwardCap
        /\ serviceBudget
        /\ lowerSubmit
        /\ ~forwardViaNetdev
        /\ ~staleLowerForward
        /\ ~forwardWithoutServiceBudget

NoPlainNetdevRepresentorForward ==
    ~forwardViaNetdev

NoControlOrForwardAfterRevoke ==
    /\ ~(controlAfterRevoke /\ controlChanged)
    /\ ~(forwardAfterRevoke /\ representorForwarded)
    /\ revoked => /\ ~queueLive
                  /\ ~lowerQueueLive

=============================================================================
