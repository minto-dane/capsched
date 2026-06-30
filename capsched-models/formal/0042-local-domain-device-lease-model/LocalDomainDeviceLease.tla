-------------------- MODULE LocalDomainDeviceLease --------------------

CONSTANTS
    ALLOW_UNSAFE_REMOTE_LEASE_DIRECT,
    ALLOW_UNSAFE_SCHEDULER_PLACEMENT,
    ALLOW_UNSAFE_SERVICE_ADMISSION_MINTS,
    ALLOW_UNSAFE_LINUX_DEVICE_ROOT,
    ALLOW_UNSAFE_STALE_CLUSTER_EPOCH,
    ALLOW_UNSAFE_WRONG_SERVICE_DOMAIN,
    ALLOW_UNSAFE_WRONG_TARGET_DOMAIN,
    ALLOW_UNSAFE_QUEUE_RECEIPT_NO_LOCAL_LEASE,
    ALLOW_UNSAFE_AUDIT_ONLY_COMPILE

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "ClusterLeaseIssued",
    "LeaseReceivedOnNode",
    "ClusterLeaseChecked",
    "ServiceDomainAdmitted",
    "DeviceRootBound",
    "TargetBudgetChecked",
    "LocalLeaseCompiled",
    "DeviceReceiptsAllowed",
    "BadRemoteLeaseDirect",
    "BadSchedulerPlacement",
    "BadServiceAdmissionMints",
    "BadLinuxDeviceRoot",
    "BadStaleClusterEpoch",
    "BadWrongServiceDomain",
    "BadWrongTargetDomain",
    "BadQueueReceiptNoLocalLease",
    "BadAuditOnlyCompile"
}

StateFields == {
    "phase",
    "clusterLeaseIssued",
    "clusterLeaseReceived",
    "clusterSignatureValid",
    "clusterEpochFresh",
    "clusterLeaseNotRevoked",
    "schedulerPlacementOnly",
    "serviceDomainAdmitted",
    "serviceDomainMatchesLease",
    "targetDomainMatchesLease",
    "targetDomainEpochFresh",
    "rootBudgetAvailable",
    "deviceRootBoundByMonitor",
    "linuxDeviceRegistrationOnly",
    "localLeaseCompiled",
    "localLeaseMonitorMinted",
    "auditOnlyCompile",
    "queueReceiptAllowed",
    "dmaReceiptAllowed",
    "irqReceiptAllowed",
    "remoteLeaseUsedDirectly",
    "serviceAdmissionMintedLease",
    "badRemoteLeaseDirect",
    "badSchedulerPlacement",
    "badServiceAdmissionMints",
    "badLinuxDeviceRoot",
    "badStaleClusterEpoch",
    "badWrongServiceDomain",
    "badWrongTargetDomain",
    "badQueueReceiptNoLocalLease",
    "badAuditOnlyCompile"
}

BoolFields == StateFields \ {"phase"}

TerminalPhases == {
    "DeviceReceiptsAllowed",
    "BadRemoteLeaseDirect",
    "BadSchedulerPlacement",
    "BadServiceAdmissionMints",
    "BadLinuxDeviceRoot",
    "BadStaleClusterEpoch",
    "BadWrongServiceDomain",
    "BadWrongTargetDomain",
    "BadQueueReceiptNoLocalLease",
    "BadAuditOnlyCompile"
}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        clusterLeaseIssued |-> FALSE,
        clusterLeaseReceived |-> FALSE,
        clusterSignatureValid |-> FALSE,
        clusterEpochFresh |-> FALSE,
        clusterLeaseNotRevoked |-> FALSE,
        schedulerPlacementOnly |-> FALSE,
        serviceDomainAdmitted |-> FALSE,
        serviceDomainMatchesLease |-> FALSE,
        targetDomainMatchesLease |-> FALSE,
        targetDomainEpochFresh |-> FALSE,
        rootBudgetAvailable |-> FALSE,
        deviceRootBoundByMonitor |-> FALSE,
        linuxDeviceRegistrationOnly |-> FALSE,
        localLeaseCompiled |-> FALSE,
        localLeaseMonitorMinted |-> FALSE,
        auditOnlyCompile |-> FALSE,
        queueReceiptAllowed |-> FALSE,
        dmaReceiptAllowed |-> FALSE,
        irqReceiptAllowed |-> FALSE,
        remoteLeaseUsedDirectly |-> FALSE,
        serviceAdmissionMintedLease |-> FALSE,
        badRemoteLeaseDirect |-> FALSE,
        badSchedulerPlacement |-> FALSE,
        badServiceAdmissionMints |-> FALSE,
        badLinuxDeviceRoot |-> FALSE,
        badStaleClusterEpoch |-> FALSE,
        badWrongServiceDomain |-> FALSE,
        badWrongTargetDomain |-> FALSE,
        badQueueReceiptNoLocalLease |-> FALSE,
        badAuditOnlyCompile |-> FALSE
        ]

LocalLeaseReady ==
    /\ state.clusterLeaseIssued
    /\ state.clusterLeaseReceived
    /\ state.clusterSignatureValid
    /\ state.clusterEpochFresh
    /\ state.clusterLeaseNotRevoked
    /\ state.serviceDomainAdmitted
    /\ state.serviceDomainMatchesLease
    /\ state.targetDomainMatchesLease
    /\ state.targetDomainEpochFresh
    /\ state.rootBudgetAvailable
    /\ state.deviceRootBoundByMonitor
    /\ state.localLeaseCompiled
    /\ state.localLeaseMonitorMinted
    /\ ~state.auditOnlyCompile
    /\ ~state.remoteLeaseUsedDirectly
    /\ ~state.serviceAdmissionMintedLease

IssueClusterLease ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "ClusterLeaseIssued",
            !.clusterLeaseIssued = TRUE
        ]

ReceiveClusterLeaseOnNode ==
    /\ state.phase = "ClusterLeaseIssued"
    /\ state.clusterLeaseIssued
    /\ state' =
        [state EXCEPT
            !.phase = "LeaseReceivedOnNode",
            !.clusterLeaseReceived = TRUE
        ]

CheckClusterLease ==
    /\ state.phase = "LeaseReceivedOnNode"
    /\ state.clusterLeaseReceived
    /\ state' =
        [state EXCEPT
            !.phase = "ClusterLeaseChecked",
            !.clusterSignatureValid = TRUE,
            !.clusterEpochFresh = TRUE,
            !.clusterLeaseNotRevoked = TRUE
        ]

AdmitServiceDomain ==
    /\ state.phase = "ClusterLeaseChecked"
    /\ state.clusterSignatureValid
    /\ state.clusterEpochFresh
    /\ state.clusterLeaseNotRevoked
    /\ state' =
        [state EXCEPT
            !.phase = "ServiceDomainAdmitted",
            !.serviceDomainAdmitted = TRUE,
            !.serviceDomainMatchesLease = TRUE
        ]

BindDeviceRoot ==
    /\ state.phase = "ServiceDomainAdmitted"
    /\ state.serviceDomainAdmitted
    /\ state.serviceDomainMatchesLease
    /\ state' =
        [state EXCEPT
            !.phase = "DeviceRootBound",
            !.deviceRootBoundByMonitor = TRUE
        ]

CheckTargetBudget ==
    /\ state.phase = "DeviceRootBound"
    /\ state.deviceRootBoundByMonitor
    /\ state' =
        [state EXCEPT
            !.phase = "TargetBudgetChecked",
            !.targetDomainMatchesLease = TRUE,
            !.targetDomainEpochFresh = TRUE,
            !.rootBudgetAvailable = TRUE
        ]

CompileLocalLease ==
    /\ state.phase = "TargetBudgetChecked"
    /\ state.clusterSignatureValid
    /\ state.clusterEpochFresh
    /\ state.clusterLeaseNotRevoked
    /\ state.serviceDomainAdmitted
    /\ state.serviceDomainMatchesLease
    /\ state.targetDomainMatchesLease
    /\ state.targetDomainEpochFresh
    /\ state.rootBudgetAvailable
    /\ state.deviceRootBoundByMonitor
    /\ state' =
        [state EXCEPT
            !.phase = "LocalLeaseCompiled",
            !.localLeaseCompiled = TRUE,
            !.localLeaseMonitorMinted = TRUE
        ]

AllowDeviceReceipts ==
    /\ state.phase = "LocalLeaseCompiled"
    /\ LocalLeaseReady
    /\ state' =
        [state EXCEPT
            !.phase = "DeviceReceiptsAllowed",
            !.queueReceiptAllowed = TRUE,
            !.dmaReceiptAllowed = TRUE,
            !.irqReceiptAllowed = TRUE
        ]

UnsafeRemoteLeaseDirect ==
    /\ ALLOW_UNSAFE_REMOTE_LEASE_DIRECT
    /\ state.phase = "LeaseReceivedOnNode"
    /\ state' =
        [state EXCEPT
            !.phase = "BadRemoteLeaseDirect",
            !.remoteLeaseUsedDirectly = TRUE,
            !.queueReceiptAllowed = TRUE,
            !.badRemoteLeaseDirect = TRUE
        ]

UnsafeSchedulerPlacement ==
    /\ ALLOW_UNSAFE_SCHEDULER_PLACEMENT
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "BadSchedulerPlacement",
            !.schedulerPlacementOnly = TRUE,
            !.queueReceiptAllowed = TRUE,
            !.badSchedulerPlacement = TRUE
        ]

UnsafeServiceAdmissionMints ==
    /\ ALLOW_UNSAFE_SERVICE_ADMISSION_MINTS
    /\ state.phase = "ServiceDomainAdmitted"
    /\ state.serviceDomainAdmitted
    /\ state' =
        [state EXCEPT
            !.phase = "BadServiceAdmissionMints",
            !.serviceAdmissionMintedLease = TRUE,
            !.localLeaseCompiled = TRUE,
            !.queueReceiptAllowed = TRUE,
            !.badServiceAdmissionMints = TRUE
        ]

UnsafeLinuxDeviceRoot ==
    /\ ALLOW_UNSAFE_LINUX_DEVICE_ROOT
    /\ state.phase = "ServiceDomainAdmitted"
    /\ state.serviceDomainAdmitted
    /\ state' =
        [state EXCEPT
            !.phase = "BadLinuxDeviceRoot",
            !.linuxDeviceRegistrationOnly = TRUE,
            !.localLeaseCompiled = TRUE,
            !.queueReceiptAllowed = TRUE,
            !.badLinuxDeviceRoot = TRUE
        ]

UnsafeStaleClusterEpoch ==
    /\ ALLOW_UNSAFE_STALE_CLUSTER_EPOCH
    /\ state.phase = "LeaseReceivedOnNode"
    /\ state.clusterLeaseReceived
    /\ state' =
        [state EXCEPT
            !.phase = "BadStaleClusterEpoch",
            !.clusterSignatureValid = TRUE,
            !.clusterEpochFresh = FALSE,
            !.clusterLeaseNotRevoked = TRUE,
            !.localLeaseCompiled = TRUE,
            !.badStaleClusterEpoch = TRUE
        ]

UnsafeWrongServiceDomain ==
    /\ ALLOW_UNSAFE_WRONG_SERVICE_DOMAIN
    /\ state.phase = "ClusterLeaseChecked"
    /\ state.clusterSignatureValid
    /\ state.clusterEpochFresh
    /\ state.clusterLeaseNotRevoked
    /\ state' =
        [state EXCEPT
            !.phase = "BadWrongServiceDomain",
            !.serviceDomainAdmitted = TRUE,
            !.serviceDomainMatchesLease = FALSE,
            !.localLeaseCompiled = TRUE,
            !.badWrongServiceDomain = TRUE
        ]

UnsafeWrongTargetDomain ==
    /\ ALLOW_UNSAFE_WRONG_TARGET_DOMAIN
    /\ state.phase = "DeviceRootBound"
    /\ state.deviceRootBoundByMonitor
    /\ state' =
        [state EXCEPT
            !.phase = "BadWrongTargetDomain",
            !.targetDomainMatchesLease = FALSE,
            !.targetDomainEpochFresh = TRUE,
            !.rootBudgetAvailable = TRUE,
            !.localLeaseCompiled = TRUE,
            !.badWrongTargetDomain = TRUE
        ]

UnsafeQueueReceiptNoLocalLease ==
    /\ ALLOW_UNSAFE_QUEUE_RECEIPT_NO_LOCAL_LEASE
    /\ state.phase \in {"Start", "ClusterLeaseIssued", "LeaseReceivedOnNode",
        "ClusterLeaseChecked", "ServiceDomainAdmitted", "DeviceRootBound",
        "TargetBudgetChecked"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadQueueReceiptNoLocalLease",
            !.queueReceiptAllowed = TRUE,
            !.badQueueReceiptNoLocalLease = TRUE
        ]

UnsafeAuditOnlyCompile ==
    /\ ALLOW_UNSAFE_AUDIT_ONLY_COMPILE
    /\ state.phase = "TargetBudgetChecked"
    /\ state' =
        [state EXCEPT
            !.phase = "BadAuditOnlyCompile",
            !.auditOnlyCompile = TRUE,
            !.localLeaseCompiled = TRUE,
            !.queueReceiptAllowed = TRUE,
            !.badAuditOnlyCompile = TRUE
        ]

StutterAtTerminal ==
    /\ state.phase \in TerminalPhases
    /\ UNCHANGED state

Next ==
    \/ IssueClusterLease
    \/ ReceiveClusterLeaseOnNode
    \/ CheckClusterLease
    \/ AdmitServiceDomain
    \/ BindDeviceRoot
    \/ CheckTargetBudget
    \/ CompileLocalLease
    \/ AllowDeviceReceipts
    \/ UnsafeRemoteLeaseDirect
    \/ UnsafeSchedulerPlacement
    \/ UnsafeServiceAdmissionMints
    \/ UnsafeLinuxDeviceRoot
    \/ UnsafeStaleClusterEpoch
    \/ UnsafeWrongServiceDomain
    \/ UnsafeWrongTargetDomain
    \/ UnsafeQueueReceiptNoLocalLease
    \/ UnsafeAuditOnlyCompile
    \/ StutterAtTerminal

NoDeviceReceiptWithoutLocalLease ==
    (state.queueReceiptAllowed \/ state.dmaReceiptAllowed \/ state.irqReceiptAllowed)
        => LocalLeaseReady

NoRemoteLeaseDirectUse ==
    ~state.remoteLeaseUsedDirectly

NoSchedulerPlacementAsAuthority ==
    ~(state.schedulerPlacementOnly /\ state.queueReceiptAllowed)

NoServiceAdmissionMintsLease ==
    ~state.serviceAdmissionMintedLease

NoLinuxDeviceRootAsLease ==
    ~(state.linuxDeviceRegistrationOnly /\ state.localLeaseCompiled)

NoStaleClusterEpochLease ==
    state.localLeaseCompiled => state.clusterEpochFresh

NoWrongServiceDomainLease ==
    state.localLeaseCompiled => state.serviceDomainMatchesLease

NoWrongTargetDomainLease ==
    state.localLeaseCompiled => state.targetDomainMatchesLease

NoAuditOnlyCompile ==
    ~state.auditOnlyCompile

NoBadRemoteLeaseDirect == ~state.badRemoteLeaseDirect
NoBadSchedulerPlacement == ~state.badSchedulerPlacement
NoBadServiceAdmissionMints == ~state.badServiceAdmissionMints
NoBadLinuxDeviceRoot == ~state.badLinuxDeviceRoot
NoBadStaleClusterEpoch == ~state.badStaleClusterEpoch
NoBadWrongServiceDomain == ~state.badWrongServiceDomain
NoBadWrongTargetDomain == ~state.badWrongTargetDomain
NoBadQueueReceiptNoLocalLease == ~state.badQueueReceiptNoLocalLease
NoBadAuditOnlyCompile == ~state.badAuditOnlyCompile

=============================================================================
