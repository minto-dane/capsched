---------------------- MODULE VFIrqRevokeOwnership ----------------------
EXTENDS Naturals

CONSTANTS
    ALLOW_UNSAFE_VF_HOST_SYNC_ASSUME,
    ALLOW_UNSAFE_VF_COMPLETION_AFTER_REVOKE,
    ALLOW_UNSAFE_REASSIGN_WITHOUT_OWNER_QUIESCE,
    ALLOW_UNSAFE_HOST_REASSIGN_NO_SYNC,
    ALLOW_UNSAFE_MONITOR_REASSIGN_NO_INVALIDATE

VARIABLES
    phase,
    vsiKind,
    irqOwner,
    queueLive,
    queueEpochFresh,
    irqRouteLive,
    irqMasked,
    hostSynchronizeDone,
    monitorIrqInvalidated,
    napiDisabled,
    irqHandlerRunning,
    completionPending,
    completionQuarantined,
    completionDelivered,
    revoked,
    queueReassigned,
    hostSyncAssumedForVF

vars == <<phase, vsiKind, irqOwner, queueLive, queueEpochFresh,
          irqRouteLive, irqMasked, hostSynchronizeDone,
          monitorIrqInvalidated, napiDisabled, irqHandlerRunning,
          completionPending, completionQuarantined, completionDelivered,
          revoked, queueReassigned, hostSyncAssumedForVF>>

VsiKinds == {"None", "PF", "VF"}
IrqOwners == {"None", "Host", "VF", "Monitor"}

Phases == {
    "Start",
    "Bound",
    "Revoking",
    "Quiesced",
    "Quarantined",
    "Reassigned",
    "BadVFHostSyncAssumed",
    "BadDeliveryAfterRevoke",
    "BadReassignWithoutOwnerQuiesce",
    "BadHostReassignNoSync",
    "BadMonitorReassignNoInvalidate"
}

TypeOK ==
    /\ phase \in Phases
    /\ vsiKind \in VsiKinds
    /\ irqOwner \in IrqOwners
    /\ queueLive \in BOOLEAN
    /\ queueEpochFresh \in BOOLEAN
    /\ irqRouteLive \in BOOLEAN
    /\ irqMasked \in BOOLEAN
    /\ hostSynchronizeDone \in BOOLEAN
    /\ monitorIrqInvalidated \in BOOLEAN
    /\ napiDisabled \in BOOLEAN
    /\ irqHandlerRunning \in BOOLEAN
    /\ completionPending \in BOOLEAN
    /\ completionQuarantined \in BOOLEAN
    /\ completionDelivered \in BOOLEAN
    /\ revoked \in BOOLEAN
    /\ queueReassigned \in BOOLEAN
    /\ hostSyncAssumedForVF \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ vsiKind = "None"
    /\ irqOwner = "None"
    /\ queueLive = FALSE
    /\ queueEpochFresh = FALSE
    /\ irqRouteLive = FALSE
    /\ irqMasked = FALSE
    /\ hostSynchronizeDone = FALSE
    /\ monitorIrqInvalidated = FALSE
    /\ napiDisabled = FALSE
    /\ irqHandlerRunning = FALSE
    /\ completionPending = FALSE
    /\ completionQuarantined = FALSE
    /\ completionDelivered = FALSE
    /\ revoked = FALSE
    /\ queueReassigned = FALSE
    /\ hostSyncAssumedForVF = FALSE

BindHostOwnedPF ==
    /\ phase = "Start"
    /\ phase' = "Bound"
    /\ vsiKind' = "PF"
    /\ irqOwner' = "Host"
    /\ queueLive' = TRUE
    /\ queueEpochFresh' = TRUE
    /\ irqRouteLive' = TRUE
    /\ irqHandlerRunning' = TRUE
    /\ completionPending' = TRUE
    /\ UNCHANGED <<irqMasked, hostSynchronizeDone,
                    monitorIrqInvalidated, napiDisabled,
                    completionQuarantined, completionDelivered, revoked,
                    queueReassigned, hostSyncAssumedForVF>>

BindVFOwnedVF ==
    /\ phase = "Start"
    /\ phase' = "Bound"
    /\ vsiKind' = "VF"
    /\ irqOwner' = "VF"
    /\ queueLive' = TRUE
    /\ queueEpochFresh' = TRUE
    /\ irqRouteLive' = TRUE
    /\ irqHandlerRunning' = TRUE
    /\ completionPending' = TRUE
    /\ UNCHANGED <<irqMasked, hostSynchronizeDone,
                    monitorIrqInvalidated, napiDisabled,
                    completionQuarantined, completionDelivered, revoked,
                    queueReassigned, hostSyncAssumedForVF>>

BindMonitorOwnedVF ==
    /\ phase = "Start"
    /\ phase' = "Bound"
    /\ vsiKind' = "VF"
    /\ irqOwner' = "Monitor"
    /\ queueLive' = TRUE
    /\ queueEpochFresh' = TRUE
    /\ irqRouteLive' = TRUE
    /\ irqHandlerRunning' = TRUE
    /\ completionPending' = TRUE
    /\ UNCHANGED <<irqMasked, hostSynchronizeDone,
                    monitorIrqInvalidated, napiDisabled,
                    completionQuarantined, completionDelivered, revoked,
                    queueReassigned, hostSyncAssumedForVF>>

MaskForRevoke ==
    /\ phase = "Bound"
    /\ phase' = "Revoking"
    /\ irqMasked' = TRUE
    /\ revoked' = TRUE
    /\ queueEpochFresh' = FALSE
    /\ UNCHANGED <<vsiKind, irqOwner, queueLive, irqRouteLive,
                    hostSynchronizeDone, monitorIrqInvalidated, napiDisabled,
                    irqHandlerRunning, completionPending,
                    completionQuarantined, completionDelivered,
                    queueReassigned, hostSyncAssumedForVF>>

HostSynchronize ==
    /\ phase = "Revoking"
    /\ irqOwner = "Host"
    /\ hostSynchronizeDone' = TRUE
    /\ irqHandlerRunning' = FALSE
    /\ UNCHANGED <<phase, vsiKind, irqOwner, queueLive, queueEpochFresh,
                    irqRouteLive, irqMasked, monitorIrqInvalidated,
                    napiDisabled, completionPending, completionQuarantined,
                    completionDelivered, revoked, queueReassigned,
                    hostSyncAssumedForVF>>

MonitorInvalidateIrq ==
    /\ phase = "Revoking"
    /\ irqOwner \in {"VF", "Monitor"}
    /\ monitorIrqInvalidated' = TRUE
    /\ irqRouteLive' = FALSE
    /\ irqHandlerRunning' = FALSE
    /\ UNCHANGED <<phase, vsiKind, irqOwner, queueLive, queueEpochFresh,
                    irqMasked, hostSynchronizeDone, napiDisabled,
                    completionPending, completionQuarantined,
                    completionDelivered, revoked, queueReassigned,
                    hostSyncAssumedForVF>>

HostIrqQuiesced ==
    /\ irqOwner = "Host"
    /\ hostSynchronizeDone
    /\ ~irqHandlerRunning

MonitorIrqQuiesced ==
    /\ irqOwner \in {"VF", "Monitor"}
    /\ monitorIrqInvalidated
    /\ ~irqRouteLive
    /\ ~irqHandlerRunning

OwnerIrqQuiesced == HostIrqQuiesced \/ MonitorIrqQuiesced

DrainAfterQuiesce ==
    /\ phase = "Revoking"
    /\ OwnerIrqQuiesced
    /\ phase' = "Quiesced"
    /\ napiDisabled' = TRUE
    /\ completionPending' = FALSE
    /\ completionQuarantined' = FALSE
    /\ UNCHANGED <<vsiKind, irqOwner, queueLive, queueEpochFresh,
                    irqRouteLive, irqMasked, hostSynchronizeDone,
                    monitorIrqInvalidated, irqHandlerRunning,
                    completionDelivered, revoked, queueReassigned,
                    hostSyncAssumedForVF>>

QuarantineAfterQuiesce ==
    /\ phase = "Revoking"
    /\ OwnerIrqQuiesced
    /\ phase' = "Quarantined"
    /\ napiDisabled' = TRUE
    /\ completionPending' = TRUE
    /\ completionQuarantined' = TRUE
    /\ UNCHANGED <<vsiKind, irqOwner, queueLive, queueEpochFresh,
                    irqRouteLive, irqMasked, hostSynchronizeDone,
                    monitorIrqInvalidated, irqHandlerRunning,
                    completionDelivered, revoked, queueReassigned,
                    hostSyncAssumedForVF>>

ReassignAfterTerminal ==
    /\ phase \in {"Quiesced", "Quarantined"}
    /\ OwnerIrqQuiesced
    /\ phase' = "Reassigned"
    /\ queueLive' = FALSE
    /\ queueReassigned' = TRUE
    /\ irqRouteLive' = FALSE
    /\ UNCHANGED <<vsiKind, irqOwner, queueEpochFresh, irqMasked,
                    hostSynchronizeDone, monitorIrqInvalidated, napiDisabled,
                    irqHandlerRunning, completionPending, completionQuarantined,
                    completionDelivered, revoked, hostSyncAssumedForVF>>

UnsafeAssumeHostSyncForVF ==
    /\ ALLOW_UNSAFE_VF_HOST_SYNC_ASSUME
    /\ phase = "Revoking"
    /\ vsiKind = "VF"
    /\ phase' = "BadVFHostSyncAssumed"
    /\ hostSynchronizeDone' = TRUE
    /\ hostSyncAssumedForVF' = TRUE
    /\ irqHandlerRunning' = FALSE
    /\ UNCHANGED <<vsiKind, irqOwner, queueLive, queueEpochFresh,
                    irqRouteLive, irqMasked, monitorIrqInvalidated,
                    napiDisabled, completionPending, completionQuarantined,
                    completionDelivered, revoked, queueReassigned>>

UnsafeDeliverAfterRevoke ==
    /\ ALLOW_UNSAFE_VF_COMPLETION_AFTER_REVOKE
    /\ phase = "Revoking"
    /\ completionPending
    /\ irqHandlerRunning
    /\ phase' = "BadDeliveryAfterRevoke"
    /\ completionDelivered' = TRUE
    /\ UNCHANGED <<vsiKind, irqOwner, queueLive, queueEpochFresh,
                    irqRouteLive, irqMasked, hostSynchronizeDone,
                    monitorIrqInvalidated, napiDisabled, irqHandlerRunning,
                    completionPending, completionQuarantined, revoked,
                    queueReassigned, hostSyncAssumedForVF>>

UnsafeReassignWithoutOwnerQuiesce ==
    /\ ALLOW_UNSAFE_REASSIGN_WITHOUT_OWNER_QUIESCE
    /\ phase = "Revoking"
    /\ ~OwnerIrqQuiesced
    /\ phase' = "BadReassignWithoutOwnerQuiesce"
    /\ queueReassigned' = TRUE
    /\ queueLive' = FALSE
    /\ UNCHANGED <<vsiKind, irqOwner, queueEpochFresh, irqRouteLive,
                    irqMasked, hostSynchronizeDone, monitorIrqInvalidated,
                    napiDisabled, irqHandlerRunning, completionPending,
                    completionQuarantined, completionDelivered, revoked,
                    hostSyncAssumedForVF>>

UnsafeHostReassignNoSync ==
    /\ ALLOW_UNSAFE_HOST_REASSIGN_NO_SYNC
    /\ phase = "Revoking"
    /\ irqOwner = "Host"
    /\ ~hostSynchronizeDone
    /\ phase' = "BadHostReassignNoSync"
    /\ queueReassigned' = TRUE
    /\ queueLive' = FALSE
    /\ UNCHANGED <<vsiKind, irqOwner, queueEpochFresh, irqRouteLive,
                    irqMasked, hostSynchronizeDone, monitorIrqInvalidated,
                    napiDisabled, irqHandlerRunning, completionPending,
                    completionQuarantined, completionDelivered, revoked,
                    hostSyncAssumedForVF>>

UnsafeMonitorReassignNoInvalidate ==
    /\ ALLOW_UNSAFE_MONITOR_REASSIGN_NO_INVALIDATE
    /\ phase = "Revoking"
    /\ irqOwner = "Monitor"
    /\ ~monitorIrqInvalidated
    /\ phase' = "BadMonitorReassignNoInvalidate"
    /\ queueReassigned' = TRUE
    /\ queueLive' = FALSE
    /\ UNCHANGED <<vsiKind, irqOwner, queueEpochFresh, irqRouteLive,
                    irqMasked, hostSynchronizeDone, monitorIrqInvalidated,
                    napiDisabled, irqHandlerRunning, completionPending,
                    completionQuarantined, completionDelivered, revoked,
                    hostSyncAssumedForVF>>

Next ==
    \/ BindHostOwnedPF
    \/ BindVFOwnedVF
    \/ BindMonitorOwnedVF
    \/ MaskForRevoke
    \/ HostSynchronize
    \/ MonitorInvalidateIrq
    \/ DrainAfterQuiesce
    \/ QuarantineAfterQuiesce
    \/ ReassignAfterTerminal
    \/ UnsafeAssumeHostSyncForVF
    \/ UnsafeDeliverAfterRevoke
    \/ UnsafeReassignWithoutOwnerQuiesce
    \/ UnsafeHostReassignNoSync
    \/ UnsafeMonitorReassignNoInvalidate

SafeSpec == Init /\ [][Next]_vars

NoVFHostSyncAssumption ==
    ~(vsiKind = "VF" /\ hostSyncAssumedForVF)

NoDeliveryAfterRevoke ==
    ~(revoked /\ completionDelivered /\ ~completionQuarantined)

NoReassignWithoutOwnerIrqQuiesce ==
    queueReassigned => OwnerIrqQuiesced

NoHostOwnedReassignWithoutSync ==
    (queueReassigned /\ irqOwner = "Host") => hostSynchronizeDone

NoVFReassignWithoutMonitorInvalidation ==
    (queueReassigned /\ irqOwner = "VF") => MonitorIrqQuiesced

NoMonitorOwnedReassignWithoutInvalidation ==
    (queueReassigned /\ irqOwner = "Monitor") => MonitorIrqQuiesced

NoIrqRouteLiveAfterTerminal ==
    queueReassigned => ~irqRouteLive

NoCompletionRunningAfterTerminal ==
    queueReassigned => ~irqHandlerRunning

=============================================================================
