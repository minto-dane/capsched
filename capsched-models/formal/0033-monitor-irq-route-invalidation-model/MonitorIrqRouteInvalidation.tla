-------------------- MODULE MonitorIrqRouteInvalidation --------------------
EXTENDS Naturals

CONSTANTS
    ALLOW_UNSAFE_INTERRUPT_OVERRIDE,
    ALLOW_UNSAFE_EVENTFD_DELIVERY_AFTER_REVOKE,
    ALLOW_UNSAFE_REASSIGN_WITHOUT_RECEIPT,
    ALLOW_UNSAFE_RECEIPT_WITHOUT_IEC_FLUSH,
    ALLOW_UNSAFE_RECEIPT_WITH_POSTED_STATE,
    ALLOW_UNSAFE_RECEIPT_WITH_EVENTFD

VARIABLES
    phase,
    routeTagLive,
    routeEpochFresh,
    isolatedMsi,
    unsafeInterruptOverride,
    eventfdLive,
    linuxIrqLive,
    msiVectorAllocated,
    irtePresent,
    iecFlushed,
    postedStateLive,
    routeInvalidationReceipt,
    revoked,
    completionQuarantined,
    delivered,
    queueReassigned

vars == <<phase, routeTagLive, routeEpochFresh, isolatedMsi,
          unsafeInterruptOverride, eventfdLive, linuxIrqLive,
          msiVectorAllocated, irtePresent, iecFlushed, postedStateLive,
          routeInvalidationReceipt, revoked, completionQuarantined,
          delivered, queueReassigned>>

Phases == {
    "Start",
    "Bound",
    "Revoking",
    "Detached",
    "IrteCleared",
    "Invalidated",
    "Reassigned",
    "BadUnsafeInterruptOverride",
    "BadEventfdDeliveryAfterRevoke",
    "BadReassignWithoutReceipt",
    "BadReceiptWithoutIecFlush",
    "BadReceiptWithPostedState",
    "BadReceiptWithEventfd"
}

TypeOK ==
    /\ phase \in Phases
    /\ routeTagLive \in BOOLEAN
    /\ routeEpochFresh \in BOOLEAN
    /\ isolatedMsi \in BOOLEAN
    /\ unsafeInterruptOverride \in BOOLEAN
    /\ eventfdLive \in BOOLEAN
    /\ linuxIrqLive \in BOOLEAN
    /\ msiVectorAllocated \in BOOLEAN
    /\ irtePresent \in BOOLEAN
    /\ iecFlushed \in BOOLEAN
    /\ postedStateLive \in BOOLEAN
    /\ routeInvalidationReceipt \in BOOLEAN
    /\ revoked \in BOOLEAN
    /\ completionQuarantined \in BOOLEAN
    /\ delivered \in BOOLEAN
    /\ queueReassigned \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ routeTagLive = FALSE
    /\ routeEpochFresh = FALSE
    /\ isolatedMsi = FALSE
    /\ unsafeInterruptOverride = FALSE
    /\ eventfdLive = FALSE
    /\ linuxIrqLive = FALSE
    /\ msiVectorAllocated = FALSE
    /\ irtePresent = FALSE
    /\ iecFlushed = FALSE
    /\ postedStateLive = FALSE
    /\ routeInvalidationReceipt = FALSE
    /\ revoked = FALSE
    /\ completionQuarantined = FALSE
    /\ delivered = FALSE
    /\ queueReassigned = FALSE

BindSecureRoute ==
    /\ phase = "Start"
    /\ phase' = "Bound"
    /\ routeTagLive' = TRUE
    /\ routeEpochFresh' = TRUE
    /\ isolatedMsi' = TRUE
    /\ eventfdLive' = TRUE
    /\ linuxIrqLive' = TRUE
    /\ msiVectorAllocated' = TRUE
    /\ irtePresent' = TRUE
    /\ iecFlushed' = FALSE
    /\ postedStateLive' = FALSE
    /\ UNCHANGED <<unsafeInterruptOverride, routeInvalidationReceipt,
                    revoked, completionQuarantined, delivered,
                    queueReassigned>>

BindSecurePostedRoute ==
    /\ phase = "Start"
    /\ phase' = "Bound"
    /\ routeTagLive' = TRUE
    /\ routeEpochFresh' = TRUE
    /\ isolatedMsi' = TRUE
    /\ eventfdLive' = TRUE
    /\ linuxIrqLive' = TRUE
    /\ msiVectorAllocated' = TRUE
    /\ irtePresent' = TRUE
    /\ iecFlushed' = FALSE
    /\ postedStateLive' = TRUE
    /\ UNCHANGED <<unsafeInterruptOverride, routeInvalidationReceipt,
                    revoked, completionQuarantined, delivered,
                    queueReassigned>>

RevokeStart ==
    /\ phase = "Bound"
    /\ phase' = "Revoking"
    /\ revoked' = TRUE
    /\ routeEpochFresh' = FALSE
    /\ UNCHANGED <<routeTagLive, isolatedMsi, unsafeInterruptOverride,
                    eventfdLive, linuxIrqLive, msiVectorAllocated,
                    irtePresent, iecFlushed, postedStateLive,
                    routeInvalidationReceipt, completionQuarantined,
                    delivered, queueReassigned>>

DetachDeliveryAndLinuxIrq ==
    /\ phase = "Revoking"
    /\ phase' = "Detached"
    /\ eventfdLive' = FALSE
    /\ linuxIrqLive' = FALSE
    /\ msiVectorAllocated' = FALSE
    /\ completionQuarantined' = TRUE
    /\ UNCHANGED <<routeTagLive, routeEpochFresh, isolatedMsi,
                    unsafeInterruptOverride, irtePresent, iecFlushed,
                    postedStateLive, routeInvalidationReceipt, revoked,
                    delivered, queueReassigned>>

ClearIrte ==
    /\ phase = "Detached"
    /\ phase' = "IrteCleared"
    /\ irtePresent' = FALSE
    /\ iecFlushed' = FALSE
    /\ UNCHANGED <<routeTagLive, routeEpochFresh, isolatedMsi,
                    unsafeInterruptOverride, eventfdLive, linuxIrqLive,
                    msiVectorAllocated, postedStateLive,
                    routeInvalidationReceipt, revoked,
                    completionQuarantined, delivered, queueReassigned>>

FlushIecAndClearPosted ==
    /\ phase = "IrteCleared"
    /\ phase' = "IrteCleared"
    /\ iecFlushed' = TRUE
    /\ postedStateLive' = FALSE
    /\ UNCHANGED <<routeTagLive, routeEpochFresh, isolatedMsi,
                    unsafeInterruptOverride, eventfdLive, linuxIrqLive,
                    msiVectorAllocated, irtePresent,
                    routeInvalidationReceipt, revoked,
                    completionQuarantined, delivered, queueReassigned>>

IssueReceipt ==
    /\ phase = "IrteCleared"
    /\ isolatedMsi
    /\ ~unsafeInterruptOverride
    /\ ~eventfdLive
    /\ ~linuxIrqLive
    /\ ~msiVectorAllocated
    /\ ~irtePresent
    /\ iecFlushed
    /\ ~postedStateLive
    /\ completionQuarantined
    /\ phase' = "Invalidated"
    /\ routeInvalidationReceipt' = TRUE
    /\ UNCHANGED <<routeTagLive, routeEpochFresh, isolatedMsi,
                    unsafeInterruptOverride, eventfdLive, linuxIrqLive,
                    msiVectorAllocated, irtePresent, iecFlushed,
                    postedStateLive, revoked, completionQuarantined,
                    delivered, queueReassigned>>

ReassignWithReceipt ==
    /\ phase = "Invalidated"
    /\ routeInvalidationReceipt
    /\ phase' = "Reassigned"
    /\ queueReassigned' = TRUE
    /\ routeTagLive' = FALSE
    /\ routeEpochFresh' = FALSE
    /\ UNCHANGED <<isolatedMsi, unsafeInterruptOverride, eventfdLive,
                    linuxIrqLive, msiVectorAllocated, irtePresent,
                    iecFlushed, postedStateLive, routeInvalidationReceipt,
                    revoked, completionQuarantined, delivered>>

UnsafeInterruptOverrideRoute ==
    /\ ALLOW_UNSAFE_INTERRUPT_OVERRIDE
    /\ phase = "Start"
    /\ phase' = "BadUnsafeInterruptOverride"
    /\ routeTagLive' = TRUE
    /\ routeEpochFresh' = TRUE
    /\ isolatedMsi' = FALSE
    /\ unsafeInterruptOverride' = TRUE
    /\ eventfdLive' = TRUE
    /\ linuxIrqLive' = TRUE
    /\ msiVectorAllocated' = TRUE
    /\ irtePresent' = TRUE
    /\ UNCHANGED <<iecFlushed, postedStateLive, routeInvalidationReceipt,
                    revoked, completionQuarantined, delivered,
                    queueReassigned>>

UnsafeEventfdDeliveryAfterRevoke ==
    /\ ALLOW_UNSAFE_EVENTFD_DELIVERY_AFTER_REVOKE
    /\ phase = "Revoking"
    /\ eventfdLive
    /\ phase' = "BadEventfdDeliveryAfterRevoke"
    /\ delivered' = TRUE
    /\ UNCHANGED <<routeTagLive, routeEpochFresh, isolatedMsi,
                    unsafeInterruptOverride, eventfdLive, linuxIrqLive,
                    msiVectorAllocated, irtePresent, iecFlushed,
                    postedStateLive, routeInvalidationReceipt, revoked,
                    completionQuarantined, queueReassigned>>

UnsafeReassignWithoutReceipt ==
    /\ ALLOW_UNSAFE_REASSIGN_WITHOUT_RECEIPT
    /\ phase = "Revoking"
    /\ ~routeInvalidationReceipt
    /\ phase' = "BadReassignWithoutReceipt"
    /\ queueReassigned' = TRUE
    /\ UNCHANGED <<routeTagLive, routeEpochFresh, isolatedMsi,
                    unsafeInterruptOverride, eventfdLive, linuxIrqLive,
                    msiVectorAllocated, irtePresent, iecFlushed,
                    postedStateLive, routeInvalidationReceipt, revoked,
                    completionQuarantined, delivered>>

UnsafeReceiptWithoutIecFlush ==
    /\ ALLOW_UNSAFE_RECEIPT_WITHOUT_IEC_FLUSH
    /\ phase = "IrteCleared"
    /\ ~iecFlushed
    /\ phase' = "BadReceiptWithoutIecFlush"
    /\ routeInvalidationReceipt' = TRUE
    /\ UNCHANGED <<routeTagLive, routeEpochFresh, isolatedMsi,
                    unsafeInterruptOverride, eventfdLive, linuxIrqLive,
                    msiVectorAllocated, irtePresent, iecFlushed,
                    postedStateLive, revoked, completionQuarantined,
                    delivered, queueReassigned>>

UnsafeReceiptWithPostedState ==
    /\ ALLOW_UNSAFE_RECEIPT_WITH_POSTED_STATE
    /\ phase = "IrteCleared"
    /\ postedStateLive
    /\ phase' = "BadReceiptWithPostedState"
    /\ routeInvalidationReceipt' = TRUE
    /\ UNCHANGED <<routeTagLive, routeEpochFresh, isolatedMsi,
                    unsafeInterruptOverride, eventfdLive, linuxIrqLive,
                    msiVectorAllocated, irtePresent, iecFlushed,
                    postedStateLive, revoked, completionQuarantined,
                    delivered, queueReassigned>>

UnsafeReceiptWithEventfd ==
    /\ ALLOW_UNSAFE_RECEIPT_WITH_EVENTFD
    /\ phase = "Revoking"
    /\ eventfdLive
    /\ phase' = "BadReceiptWithEventfd"
    /\ routeInvalidationReceipt' = TRUE
    /\ UNCHANGED <<routeTagLive, routeEpochFresh, isolatedMsi,
                    unsafeInterruptOverride, eventfdLive, linuxIrqLive,
                    msiVectorAllocated, irtePresent, iecFlushed,
                    postedStateLive, revoked, completionQuarantined,
                    delivered, queueReassigned>>

Next ==
    \/ BindSecureRoute
    \/ BindSecurePostedRoute
    \/ RevokeStart
    \/ DetachDeliveryAndLinuxIrq
    \/ ClearIrte
    \/ FlushIecAndClearPosted
    \/ IssueReceipt
    \/ ReassignWithReceipt
    \/ UnsafeInterruptOverrideRoute
    \/ UnsafeEventfdDeliveryAfterRevoke
    \/ UnsafeReassignWithoutReceipt
    \/ UnsafeReceiptWithoutIecFlush
    \/ UnsafeReceiptWithPostedState
    \/ UnsafeReceiptWithEventfd

Spec == Init /\ [][Next]_vars

NoUnsafeInterruptRoute ==
    routeTagLive => (isolatedMsi /\ ~unsafeInterruptOverride)

NoDeliveryAfterRevoke ==
    ~(revoked /\ delivered /\ ~completionQuarantined)

NoDeliveryWithoutFreshEpoch ==
    delivered => (routeTagLive /\ routeEpochFresh)

NoReceiptWithoutFullInvalidation ==
    routeInvalidationReceipt =>
        /\ isolatedMsi
        /\ ~unsafeInterruptOverride
        /\ ~eventfdLive
        /\ ~linuxIrqLive
        /\ ~msiVectorAllocated
        /\ ~irtePresent
        /\ iecFlushed
        /\ ~postedStateLive
        /\ completionQuarantined

NoReassignWithoutReceipt ==
    queueReassigned => routeInvalidationReceipt

NoRouteTagAfterReassign ==
    queueReassigned => (~routeTagLive /\ ~routeEpochFresh)

NoPostedStateAfterReceipt ==
    routeInvalidationReceipt => ~postedStateLive

NoEventfdAfterReceipt ==
    routeInvalidationReceipt => ~eventfdLive

=============================================================================
