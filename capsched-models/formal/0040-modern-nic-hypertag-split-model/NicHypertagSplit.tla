-------------------- MODULE NicHypertagSplit --------------------

CONSTANTS
    ALLOW_UNSAFE_SERVICE_MINTS_ROOT,
    ALLOW_UNSAFE_LINUX_DMA_AS_RECEIPT,
    ALLOW_UNSAFE_LINUX_IRQ_AS_RECEIPT,
    ALLOW_UNSAFE_RAW_ENDPOINT,
    ALLOW_UNSAFE_ACTIVATE_NO_DMA_IRQ,
    ALLOW_UNSAFE_SERVICE_REPLAY_OLD_EPOCH,
    ALLOW_UNSAFE_REMOTE_LEASE_DIRECT,
    ALLOW_UNSAFE_AUDIT_ONLY_MONITOR,
    ALLOW_UNSAFE_PER_PACKET_TRAP

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "LocalLeaseCompiled",
    "DeviceRootRegistered",
    "ServicePolicyApproved",
    "VfAndQueueBound",
    "DmaIrqBound",
    "TypedEndpointsIssued",
    "ServiceCarrierFrozen",
    "QueueActivated",
    "DataPlaneRunning",
    "BadServiceMint",
    "BadLinuxDma",
    "BadLinuxIrq",
    "BadRawEndpoint",
    "BadActivateNoDmaIrq",
    "BadServiceReplay",
    "BadRemoteLeaseDirect",
    "BadAuditOnly",
    "BadPacketTrap"
}

StateFields == {
    "phase",
    "localLeaseCompiled",
    "deviceRootReceipt",
    "servicePolicy",
    "vfEpochReceipt",
    "queueLeaseReceipt",
    "queueEpochFresh",
    "dmaReceipt",
    "irqReceipt",
    "ledgerRootReceipt",
    "typedEndpoints",
    "serviceCarrierFresh",
    "queueActivated",
    "packetEffect",
    "monitorTrapPerPacket",
    "serviceMintedRoot",
    "linuxDmaAsReceipt",
    "linuxIrqAsReceipt",
    "rawEndpoint",
    "serviceReplayOldEpoch",
    "remoteLeaseDirect",
    "effectBeforeReceipt",
    "badServiceMint",
    "badLinuxDma",
    "badLinuxIrq",
    "badRawEndpoint",
    "badActivateNoDmaIrq",
    "badServiceReplay",
    "badRemoteLeaseDirect",
    "badAuditOnly",
    "badPacketTrap"
}

BoolFields == StateFields \ {"phase"}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        localLeaseCompiled |-> FALSE,
        deviceRootReceipt |-> FALSE,
        servicePolicy |-> FALSE,
        vfEpochReceipt |-> FALSE,
        queueLeaseReceipt |-> FALSE,
        queueEpochFresh |-> FALSE,
        dmaReceipt |-> FALSE,
        irqReceipt |-> FALSE,
        ledgerRootReceipt |-> FALSE,
        typedEndpoints |-> FALSE,
        serviceCarrierFresh |-> FALSE,
        queueActivated |-> FALSE,
        packetEffect |-> FALSE,
        monitorTrapPerPacket |-> FALSE,
        serviceMintedRoot |-> FALSE,
        linuxDmaAsReceipt |-> FALSE,
        linuxIrqAsReceipt |-> FALSE,
        rawEndpoint |-> FALSE,
        serviceReplayOldEpoch |-> FALSE,
        remoteLeaseDirect |-> FALSE,
        effectBeforeReceipt |-> FALSE,
        badServiceMint |-> FALSE,
        badLinuxDma |-> FALSE,
        badLinuxIrq |-> FALSE,
        badRawEndpoint |-> FALSE,
        badActivateNoDmaIrq |-> FALSE,
        badServiceReplay |-> FALSE,
        badRemoteLeaseDirect |-> FALSE,
        badAuditOnly |-> FALSE,
        badPacketTrap |-> FALSE
        ]

CompileLocalLease ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "LocalLeaseCompiled",
            !.localLeaseCompiled = TRUE
        ]

RegisterDeviceRoot ==
    /\ state.phase = "LocalLeaseCompiled"
    /\ state.localLeaseCompiled
    /\ state' =
        [state EXCEPT
            !.phase = "DeviceRootRegistered",
            !.deviceRootReceipt = TRUE
        ]

ApproveServicePolicy ==
    /\ state.phase = "DeviceRootRegistered"
    /\ state.deviceRootReceipt
    /\ state' =
        [state EXCEPT
            !.phase = "ServicePolicyApproved",
            !.servicePolicy = TRUE
        ]

BindVfAndQueue ==
    /\ state.phase = "ServicePolicyApproved"
    /\ state.localLeaseCompiled
    /\ state.deviceRootReceipt
    /\ state.servicePolicy
    /\ state' =
        [state EXCEPT
            !.phase = "VfAndQueueBound",
            !.vfEpochReceipt = TRUE,
            !.queueLeaseReceipt = TRUE,
            !.queueEpochFresh = TRUE
        ]

BindDmaIrq ==
    /\ state.phase = "VfAndQueueBound"
    /\ state.vfEpochReceipt
    /\ state.queueLeaseReceipt
    /\ state.queueEpochFresh
    /\ state' =
        [state EXCEPT
            !.phase = "DmaIrqBound",
            !.dmaReceipt = TRUE,
            !.irqReceipt = TRUE,
            !.ledgerRootReceipt = TRUE
        ]

IssueTypedEndpoints ==
    /\ state.phase = "DmaIrqBound"
    /\ state.dmaReceipt
    /\ state.irqReceipt
    /\ state.ledgerRootReceipt
    /\ state' =
        [state EXCEPT
            !.phase = "TypedEndpointsIssued",
            !.typedEndpoints = TRUE
        ]

FreezeServiceCarrier ==
    /\ state.phase = "TypedEndpointsIssued"
    /\ state.typedEndpoints
    /\ state' =
        [state EXCEPT
            !.phase = "ServiceCarrierFrozen",
            !.serviceCarrierFresh = TRUE
        ]

ActivateQueue ==
    /\ state.phase = "ServiceCarrierFrozen"
    /\ state.localLeaseCompiled
    /\ state.deviceRootReceipt
    /\ state.servicePolicy
    /\ state.vfEpochReceipt
    /\ state.queueLeaseReceipt
    /\ state.queueEpochFresh
    /\ state.dmaReceipt
    /\ state.irqReceipt
    /\ state.ledgerRootReceipt
    /\ state.typedEndpoints
    /\ state.serviceCarrierFresh
    /\ state' =
        [state EXCEPT
            !.phase = "QueueActivated",
            !.queueActivated = TRUE
        ]

RunDataPlane ==
    /\ state.phase = "QueueActivated"
    /\ state.queueActivated
    /\ state.typedEndpoints
    /\ state.ledgerRootReceipt
    /\ ~state.monitorTrapPerPacket
    /\ state' =
        [state EXCEPT
            !.phase = "DataPlaneRunning",
            !.packetEffect = TRUE
        ]

UnsafeServiceMintsRoot ==
    /\ ALLOW_UNSAFE_SERVICE_MINTS_ROOT
    /\ state.phase \in {"Start", "ServicePolicyApproved"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadServiceMint",
            !.servicePolicy = TRUE,
            !.queueLeaseReceipt = TRUE,
            !.serviceMintedRoot = TRUE,
            !.queueActivated = TRUE,
            !.packetEffect = TRUE,
            !.badServiceMint = TRUE
        ]

UnsafeLinuxDmaAsReceipt ==
    /\ ALLOW_UNSAFE_LINUX_DMA_AS_RECEIPT
    /\ state.phase = "VfAndQueueBound"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxDma",
            !.linuxDmaAsReceipt = TRUE,
            !.irqReceipt = TRUE,
            !.ledgerRootReceipt = TRUE,
            !.typedEndpoints = TRUE,
            !.serviceCarrierFresh = TRUE,
            !.queueActivated = TRUE,
            !.packetEffect = TRUE,
            !.badLinuxDma = TRUE
        ]

UnsafeLinuxIrqAsReceipt ==
    /\ ALLOW_UNSAFE_LINUX_IRQ_AS_RECEIPT
    /\ state.phase = "VfAndQueueBound"
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxIrq",
            !.linuxIrqAsReceipt = TRUE,
            !.dmaReceipt = TRUE,
            !.ledgerRootReceipt = TRUE,
            !.typedEndpoints = TRUE,
            !.serviceCarrierFresh = TRUE,
            !.queueActivated = TRUE,
            !.packetEffect = TRUE,
            !.badLinuxIrq = TRUE
        ]

UnsafeRawEndpoint ==
    /\ ALLOW_UNSAFE_RAW_ENDPOINT
    /\ state.phase = "DmaIrqBound"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRawEndpoint",
            !.rawEndpoint = TRUE,
            !.serviceCarrierFresh = TRUE,
            !.queueActivated = TRUE,
            !.packetEffect = TRUE,
            !.badRawEndpoint = TRUE
        ]

UnsafeActivateNoDmaIrq ==
    /\ ALLOW_UNSAFE_ACTIVATE_NO_DMA_IRQ
    /\ state.phase = "VfAndQueueBound"
    /\ ~state.dmaReceipt
    /\ ~state.irqReceipt
    /\ state' =
        [state EXCEPT
            !.phase = "BadActivateNoDmaIrq",
            !.typedEndpoints = TRUE,
            !.serviceCarrierFresh = TRUE,
            !.queueActivated = TRUE,
            !.packetEffect = TRUE,
            !.badActivateNoDmaIrq = TRUE
        ]

UnsafeServiceReplayOldEpoch ==
    /\ ALLOW_UNSAFE_SERVICE_REPLAY_OLD_EPOCH
    /\ state.phase = "VfAndQueueBound"
    /\ state.queueEpochFresh
    /\ state' =
        [state EXCEPT
            !.phase = "BadServiceReplay",
            !.queueEpochFresh = FALSE,
            !.serviceReplayOldEpoch = TRUE,
            !.queueActivated = TRUE,
            !.packetEffect = TRUE,
            !.badServiceReplay = TRUE
        ]

UnsafeRemoteLeaseDirect ==
    /\ ALLOW_UNSAFE_REMOTE_LEASE_DIRECT
    /\ state.phase = "Start"
    /\ ~state.localLeaseCompiled
    /\ state' =
        [state EXCEPT
            !.phase = "BadRemoteLeaseDirect",
            !.remoteLeaseDirect = TRUE,
            !.deviceRootReceipt = TRUE,
            !.queueLeaseReceipt = TRUE,
            !.queueEpochFresh = TRUE,
            !.dmaReceipt = TRUE,
            !.irqReceipt = TRUE,
            !.ledgerRootReceipt = TRUE,
            !.typedEndpoints = TRUE,
            !.serviceCarrierFresh = TRUE,
            !.queueActivated = TRUE,
            !.packetEffect = TRUE,
            !.badRemoteLeaseDirect = TRUE
        ]

UnsafeAuditOnlyMonitor ==
    /\ ALLOW_UNSAFE_AUDIT_ONLY_MONITOR
    /\ state.phase = "ServicePolicyApproved"
    /\ state' =
        [state EXCEPT
            !.phase = "BadAuditOnly",
            !.effectBeforeReceipt = TRUE,
            !.packetEffect = TRUE,
            !.badAuditOnly = TRUE
        ]

UnsafePerPacketTrap ==
    /\ ALLOW_UNSAFE_PER_PACKET_TRAP
    /\ state.phase = "QueueActivated"
    /\ state.queueActivated
    /\ state' =
        [state EXCEPT
            !.phase = "BadPacketTrap",
            !.monitorTrapPerPacket = TRUE,
            !.packetEffect = TRUE,
            !.badPacketTrap = TRUE
        ]

Next ==
    \/ CompileLocalLease
    \/ RegisterDeviceRoot
    \/ ApproveServicePolicy
    \/ BindVfAndQueue
    \/ BindDmaIrq
    \/ IssueTypedEndpoints
    \/ FreezeServiceCarrier
    \/ ActivateQueue
    \/ RunDataPlane
    \/ UnsafeServiceMintsRoot
    \/ UnsafeLinuxDmaAsReceipt
    \/ UnsafeLinuxIrqAsReceipt
    \/ UnsafeRawEndpoint
    \/ UnsafeActivateNoDmaIrq
    \/ UnsafeServiceReplayOldEpoch
    \/ UnsafeRemoteLeaseDirect
    \/ UnsafeAuditOnlyMonitor
    \/ UnsafePerPacketTrap

Spec ==
    Init /\ [][Next]_vars

NoEffectWithoutMonitorRoots ==
    state.packetEffect =>
        /\ state.localLeaseCompiled
        /\ state.deviceRootReceipt
        /\ state.servicePolicy
        /\ state.vfEpochReceipt
        /\ state.queueLeaseReceipt
        /\ state.queueEpochFresh
        /\ state.dmaReceipt
        /\ state.irqReceipt
        /\ state.ledgerRootReceipt
        /\ state.typedEndpoints
        /\ state.serviceCarrierFresh
        /\ ~state.rawEndpoint
        /\ ~state.remoteLeaseDirect
        /\ ~state.effectBeforeReceipt

NoServiceMintedMonitorRoot ==
    ~state.serviceMintedRoot

NoLinuxDmaAsReceipt ==
    ~state.linuxDmaAsReceipt

NoLinuxIrqAsReceipt ==
    ~state.linuxIrqAsReceipt

NoRawEndpointToTarget ==
    ~state.rawEndpoint

NoQueueActivationWithoutDmaIrq ==
    state.queueActivated =>
        /\ state.dmaReceipt
        /\ state.irqReceipt
        /\ state.ledgerRootReceipt

NoServiceReplayOldEpoch ==
    ~state.serviceReplayOldEpoch

NoRemoteLeaseDirectUse ==
    ~state.remoteLeaseDirect

NoAuditOnlyMonitor ==
    ~state.effectBeforeReceipt

NoPerPacketMonitorTrap ==
    state.packetEffect => ~state.monitorTrapPerPacket

NoBadServiceMint ==
    ~state.badServiceMint

NoBadLinuxDma ==
    ~state.badLinuxDma

NoBadLinuxIrq ==
    ~state.badLinuxIrq

NoBadRawEndpoint ==
    ~state.badRawEndpoint

NoBadActivateNoDmaIrq ==
    ~state.badActivateNoDmaIrq

NoBadServiceReplay ==
    ~state.badServiceReplay

NoBadRemoteLeaseDirect ==
    ~state.badRemoteLeaseDirect

NoBadAuditOnly ==
    ~state.badAuditOnly

NoBadPacketTrap ==
    ~state.badPacketTrap

=============================================================================
