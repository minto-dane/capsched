-------------------- MODULE LocalDomainDeviceLeaseAdmission --------------------

CONSTANTS
    ALLOW_UNSAFE_COMPILE_BAD_CLUSTER,
    ALLOW_UNSAFE_COMPILE_SERVICE_MISMATCH,
    ALLOW_UNSAFE_COMPILE_TARGET_MISMATCH,
    ALLOW_UNSAFE_RECEIPT_BEFORE_COMPILE,
    ALLOW_UNSAFE_RECEIPT_DURING_REVOKE,
    ALLOW_UNSAFE_REUSE_BEFORE_REVOKE_COMPLETE,
    ALLOW_UNSAFE_AUDIT_ONLY_ACCEPT

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "ClusterLeaseIssued",
    "LeaseReceived",
    "ClusterChecked",
    "ServiceAdmitted",
    "DeviceRootBound",
    "TargetChecked",
    "LocalLeaseCompiled",
    "ReceiptsMinted",
    "EndpointsDelivered",
    "RevokeRequested",
    "ReceiptEmbargoed",
    "DerivedReceiptsRevoked",
    "RevokeComplete",
    "Rejected",
    "BadCompileBadCluster",
    "BadCompileServiceMismatch",
    "BadCompileTargetMismatch",
    "BadReceiptBeforeCompile",
    "BadReceiptDuringRevoke",
    "BadReuseBeforeRevokeComplete",
    "BadAuditOnlyAccept"
}

RejectReasons == {
    "none",
    "bad_cluster_signature",
    "stale_cluster_epoch",
    "cluster_lease_revoked",
    "service_domain_mismatch",
    "device_root_missing",
    "target_domain_mismatch",
    "target_epoch_or_budget_invalid"
}

StateFields == {
    "phase",
    "rejectReason",
    "clusterLeaseIssued",
    "clusterLeaseReceived",
    "clusterCheckedOk",
    "clusterEpochFresh",
    "clusterLeaseNotRevoked",
    "serviceAdmitted",
    "serviceDomainMatches",
    "deviceRootBound",
    "targetDomainMatches",
    "targetEpochFresh",
    "rootBudgetAvailable",
    "localLeaseCompiled",
    "localLeaseLive",
    "receiptLive",
    "endpointLive",
    "revokeRequested",
    "newReceiptEmbargo",
    "derivedReceiptsRevoked",
    "revokeComplete",
    "rejected",
    "newReceiptAfterRevoke",
    "leaseReusedBeforeRevokeComplete",
    "auditOnlyAccepted",
    "badCompileBadCluster",
    "badCompileServiceMismatch",
    "badCompileTargetMismatch",
    "badReceiptBeforeCompile",
    "badReceiptDuringRevoke",
    "badReuseBeforeRevokeComplete",
    "badAuditOnlyAccept"
}

BoolFields == StateFields \ {"phase", "rejectReason"}

TerminalPhases == {
    "Rejected",
    "RevokeComplete",
    "BadCompileBadCluster",
    "BadCompileServiceMismatch",
    "BadCompileTargetMismatch",
    "BadReceiptBeforeCompile",
    "BadReceiptDuringRevoke",
    "BadReuseBeforeRevokeComplete",
    "BadAuditOnlyAccept"
}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ state.rejectReason \in RejectReasons
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        rejectReason |-> "none",
        clusterLeaseIssued |-> FALSE,
        clusterLeaseReceived |-> FALSE,
        clusterCheckedOk |-> FALSE,
        clusterEpochFresh |-> FALSE,
        clusterLeaseNotRevoked |-> FALSE,
        serviceAdmitted |-> FALSE,
        serviceDomainMatches |-> FALSE,
        deviceRootBound |-> FALSE,
        targetDomainMatches |-> FALSE,
        targetEpochFresh |-> FALSE,
        rootBudgetAvailable |-> FALSE,
        localLeaseCompiled |-> FALSE,
        localLeaseLive |-> FALSE,
        receiptLive |-> FALSE,
        endpointLive |-> FALSE,
        revokeRequested |-> FALSE,
        newReceiptEmbargo |-> FALSE,
        derivedReceiptsRevoked |-> FALSE,
        revokeComplete |-> FALSE,
        rejected |-> FALSE,
        newReceiptAfterRevoke |-> FALSE,
        leaseReusedBeforeRevokeComplete |-> FALSE,
        auditOnlyAccepted |-> FALSE,
        badCompileBadCluster |-> FALSE,
        badCompileServiceMismatch |-> FALSE,
        badCompileTargetMismatch |-> FALSE,
        badReceiptBeforeCompile |-> FALSE,
        badReceiptDuringRevoke |-> FALSE,
        badReuseBeforeRevokeComplete |-> FALSE,
        badAuditOnlyAccept |-> FALSE
    ]

Reject(reason) ==
    state' =
        [state EXCEPT
            !.phase = "Rejected",
            !.rejectReason = reason,
            !.rejected = TRUE
        ]

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
            !.phase = "LeaseReceived",
            !.clusterLeaseReceived = TRUE
        ]

MonitorCheckClusterLease ==
    /\ state.phase = "LeaseReceived"
    /\ state.clusterLeaseReceived
    /\ state' =
        [state EXCEPT
            !.phase = "ClusterChecked",
            !.clusterCheckedOk = TRUE,
            !.clusterEpochFresh = TRUE,
            !.clusterLeaseNotRevoked = TRUE
        ]

RejectBadClusterSignature ==
    /\ state.phase = "LeaseReceived"
    /\ Reject("bad_cluster_signature")

RejectStaleClusterEpoch ==
    /\ state.phase = "LeaseReceived"
    /\ Reject("stale_cluster_epoch")

RejectClusterLeaseRevoked ==
    /\ state.phase = "LeaseReceived"
    /\ Reject("cluster_lease_revoked")

AdmitServiceDomain ==
    /\ state.phase = "ClusterChecked"
    /\ state.clusterCheckedOk
    /\ state.clusterEpochFresh
    /\ state.clusterLeaseNotRevoked
    /\ state' =
        [state EXCEPT
            !.phase = "ServiceAdmitted",
            !.serviceAdmitted = TRUE,
            !.serviceDomainMatches = TRUE
        ]

RejectServiceDomainMismatch ==
    /\ state.phase = "ClusterChecked"
    /\ Reject("service_domain_mismatch")

BindDeviceRoot ==
    /\ state.phase = "ServiceAdmitted"
    /\ state.serviceAdmitted
    /\ state.serviceDomainMatches
    /\ state' =
        [state EXCEPT
            !.phase = "DeviceRootBound",
            !.deviceRootBound = TRUE
        ]

RejectDeviceRootMissing ==
    /\ state.phase = "ServiceAdmitted"
    /\ Reject("device_root_missing")

CheckTargetEpochBudget ==
    /\ state.phase = "DeviceRootBound"
    /\ state.deviceRootBound
    /\ state' =
        [state EXCEPT
            !.phase = "TargetChecked",
            !.targetDomainMatches = TRUE,
            !.targetEpochFresh = TRUE,
            !.rootBudgetAvailable = TRUE
        ]

RejectTargetDomainMismatch ==
    /\ state.phase = "DeviceRootBound"
    /\ Reject("target_domain_mismatch")

RejectTargetEpochBudgetInvalid ==
    /\ state.phase = "DeviceRootBound"
    /\ Reject("target_epoch_or_budget_invalid")

CompileLocalLease ==
    /\ state.phase = "TargetChecked"
    /\ state.clusterCheckedOk
    /\ state.clusterEpochFresh
    /\ state.clusterLeaseNotRevoked
    /\ state.serviceAdmitted
    /\ state.serviceDomainMatches
    /\ state.deviceRootBound
    /\ state.targetDomainMatches
    /\ state.targetEpochFresh
    /\ state.rootBudgetAvailable
    /\ state' =
        [state EXCEPT
            !.phase = "LocalLeaseCompiled",
            !.localLeaseCompiled = TRUE,
            !.localLeaseLive = TRUE
        ]

MintReceipts ==
    /\ state.phase = "LocalLeaseCompiled"
    /\ state.localLeaseLive
    /\ ~state.revokeRequested
    /\ state' =
        [state EXCEPT
            !.phase = "ReceiptsMinted",
            !.receiptLive = TRUE
        ]

DeliverEndpoints ==
    /\ state.phase = "ReceiptsMinted"
    /\ state.localLeaseLive
    /\ state.receiptLive
    /\ ~state.revokeRequested
    /\ state' =
        [state EXCEPT
            !.phase = "EndpointsDelivered",
            !.endpointLive = TRUE
        ]

RequestRevoke ==
    /\ state.phase = "EndpointsDelivered"
    /\ state.localLeaseLive
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeRequested",
            !.revokeRequested = TRUE
        ]

EmbargoNewReceipts ==
    /\ state.phase = "RevokeRequested"
    /\ state.revokeRequested
    /\ state' =
        [state EXCEPT
            !.phase = "ReceiptEmbargoed",
            !.newReceiptEmbargo = TRUE
        ]

RevokeDerivedReceipts ==
    /\ state.phase = "ReceiptEmbargoed"
    /\ state.newReceiptEmbargo
    /\ state' =
        [state EXCEPT
            !.phase = "DerivedReceiptsRevoked",
            !.receiptLive = FALSE,
            !.endpointLive = FALSE,
            !.derivedReceiptsRevoked = TRUE
        ]

CompleteRevoke ==
    /\ state.phase = "DerivedReceiptsRevoked"
    /\ state.derivedReceiptsRevoked
    /\ state' =
        [state EXCEPT
            !.phase = "RevokeComplete",
            !.localLeaseLive = FALSE,
            !.revokeComplete = TRUE
        ]

UnsafeCompileBadCluster ==
    /\ ALLOW_UNSAFE_COMPILE_BAD_CLUSTER
    /\ state.phase \in {"Start", "ClusterLeaseIssued", "LeaseReceived", "Rejected"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadCompileBadCluster",
            !.localLeaseCompiled = TRUE,
            !.localLeaseLive = TRUE,
            !.badCompileBadCluster = TRUE
        ]

UnsafeCompileServiceMismatch ==
    /\ ALLOW_UNSAFE_COMPILE_SERVICE_MISMATCH
    /\ state.phase = "ClusterChecked"
    /\ state' =
        [state EXCEPT
            !.phase = "BadCompileServiceMismatch",
            !.localLeaseCompiled = TRUE,
            !.localLeaseLive = TRUE,
            !.badCompileServiceMismatch = TRUE
        ]

UnsafeCompileTargetMismatch ==
    /\ ALLOW_UNSAFE_COMPILE_TARGET_MISMATCH
    /\ state.phase = "DeviceRootBound"
    /\ state' =
        [state EXCEPT
            !.phase = "BadCompileTargetMismatch",
            !.localLeaseCompiled = TRUE,
            !.localLeaseLive = TRUE,
            !.badCompileTargetMismatch = TRUE
        ]

UnsafeReceiptBeforeCompile ==
    /\ ALLOW_UNSAFE_RECEIPT_BEFORE_COMPILE
    /\ state.phase \in {"Start", "ClusterLeaseIssued", "LeaseReceived",
        "ClusterChecked", "ServiceAdmitted", "DeviceRootBound", "TargetChecked"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadReceiptBeforeCompile",
            !.receiptLive = TRUE,
            !.badReceiptBeforeCompile = TRUE
        ]

UnsafeReceiptDuringRevoke ==
    /\ ALLOW_UNSAFE_RECEIPT_DURING_REVOKE
    /\ state.phase \in {"RevokeRequested", "ReceiptEmbargoed"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadReceiptDuringRevoke",
            !.receiptLive = TRUE,
            !.newReceiptAfterRevoke = TRUE,
            !.badReceiptDuringRevoke = TRUE
        ]

UnsafeReuseBeforeRevokeComplete ==
    /\ ALLOW_UNSAFE_REUSE_BEFORE_REVOKE_COMPLETE
    /\ state.phase \in {"RevokeRequested", "ReceiptEmbargoed", "DerivedReceiptsRevoked"}
    /\ state' =
        [state EXCEPT
            !.phase = "BadReuseBeforeRevokeComplete",
            !.localLeaseLive = TRUE,
            !.leaseReusedBeforeRevokeComplete = TRUE,
            !.badReuseBeforeRevokeComplete = TRUE
        ]

UnsafeAuditOnlyAccept ==
    /\ ALLOW_UNSAFE_AUDIT_ONLY_ACCEPT
    /\ state.phase = "TargetChecked"
    /\ state' =
        [state EXCEPT
            !.phase = "BadAuditOnlyAccept",
            !.localLeaseCompiled = TRUE,
            !.localLeaseLive = TRUE,
            !.auditOnlyAccepted = TRUE,
            !.badAuditOnlyAccept = TRUE
        ]

StutterAtTerminal ==
    /\ state.phase \in TerminalPhases
    /\ UNCHANGED state

Next ==
    \/ IssueClusterLease
    \/ ReceiveClusterLeaseOnNode
    \/ MonitorCheckClusterLease
    \/ RejectBadClusterSignature
    \/ RejectStaleClusterEpoch
    \/ RejectClusterLeaseRevoked
    \/ AdmitServiceDomain
    \/ RejectServiceDomainMismatch
    \/ BindDeviceRoot
    \/ RejectDeviceRootMissing
    \/ CheckTargetEpochBudget
    \/ RejectTargetDomainMismatch
    \/ RejectTargetEpochBudgetInvalid
    \/ CompileLocalLease
    \/ MintReceipts
    \/ DeliverEndpoints
    \/ RequestRevoke
    \/ EmbargoNewReceipts
    \/ RevokeDerivedReceipts
    \/ CompleteRevoke
    \/ UnsafeCompileBadCluster
    \/ UnsafeCompileServiceMismatch
    \/ UnsafeCompileTargetMismatch
    \/ UnsafeReceiptBeforeCompile
    \/ UnsafeReceiptDuringRevoke
    \/ UnsafeReuseBeforeRevokeComplete
    \/ UnsafeAuditOnlyAccept
    \/ StutterAtTerminal

NoLocalLeaseAfterRejection ==
    state.rejected => ~(state.localLeaseLive \/ state.receiptLive \/ state.endpointLive)

NoLocalLeaseWithoutCheckedClusterLease ==
    state.localLeaseLive => state.clusterCheckedOk

NoLocalLeaseWithoutMatchingServiceDomain ==
    state.localLeaseLive => state.serviceDomainMatches

NoLocalLeaseWithoutMonitorDeviceRoot ==
    state.localLeaseLive => state.deviceRootBound

NoLocalLeaseWithoutMatchingTargetDomain ==
    state.localLeaseLive => state.targetDomainMatches

NoLocalLeaseWithoutTargetEpochBudget ==
    state.localLeaseLive => (state.targetEpochFresh /\ state.rootBudgetAvailable)

NoReceiptBeforeLocalLease ==
    state.receiptLive => state.localLeaseCompiled

NoEndpointBeforeLocalLease ==
    state.endpointLive => state.localLeaseCompiled

NoNewReceiptDuringRevoke ==
    ~state.newReceiptAfterRevoke

NoReuseBeforeRevokeComplete ==
    ~state.leaseReusedBeforeRevokeComplete

NoAuditOnlyAdmissionOrRevoke ==
    ~state.auditOnlyAccepted

NoRevokeCompleteWithLiveDerived ==
    state.revokeComplete => ~(state.receiptLive \/ state.endpointLive)

NoBadCompileBadCluster == ~state.badCompileBadCluster
NoBadCompileServiceMismatch == ~state.badCompileServiceMismatch
NoBadCompileTargetMismatch == ~state.badCompileTargetMismatch
NoBadReceiptBeforeCompile == ~state.badReceiptBeforeCompile
NoBadReceiptDuringRevoke == ~state.badReceiptDuringRevoke
NoBadReuseBeforeRevokeComplete == ~state.badReuseBeforeRevokeComplete
NoBadAuditOnlyAccept == ~state.badAuditOnlyAccept

=============================================================================
