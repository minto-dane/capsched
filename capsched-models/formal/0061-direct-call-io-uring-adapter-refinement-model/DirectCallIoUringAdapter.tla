------------------------ MODULE DirectCallIoUringAdapter ------------------------

EXTENDS Naturals

CONSTANTS
    ALLOW_UNSAFE_SIDE_EFFECT_BEFORE_VALIDATE,
    ALLOW_UNSAFE_IMMUTABLE_OVERWRITE,
    ALLOW_UNSAFE_IO_KIOCB_AUTHORITY,
    ALLOW_UNSAFE_CRED_TCTX_AUTHORITY,
    ALLOW_UNSAFE_RSRC_NODE_AUTHORITY,
    ALLOW_UNSAFE_IO_WQ_WORK_AUTHORITY,
    ALLOW_UNSAFE_REISSUE_REFRESH,
    ALLOW_UNSAFE_CQE_SETTLEMENT_PROOF,
    ALLOW_UNSAFE_CANCEL_REVOKE_RECEIPT,
    ALLOW_UNSAFE_DOUBLE_SETTLEMENT,
    ALLOW_UNSAFE_RELEASE_DROPS_LINUX_REFS,
    ALLOW_UNSAFE_STALE_EXECUTE_AFTER_REVOKE,
    ALLOW_UNSAFE_LINK_INHERIT_WITHOUT_CARRIER,
    ALLOW_UNSAFE_RESOURCE_UPDATE_MUTATES_INFLIGHT,
    ALLOW_UNSAFE_URING_CMD_WITHOUT_ENDPOINT,
    ALLOW_UNSAFE_ABI_APPROVAL,
    ALLOW_UNSAFE_BEHAVIOR_CHANGE,
    ALLOW_UNSAFE_MONITOR_VERIFIED,
    ALLOW_UNSAFE_PROTECTION_CLAIM

VARIABLE state

vars == <<state>>

Paths == {"none", "inline", "io_wq"}

Phases == {
    "Start",
    "RequestAllocated",
    "SqeConsumed",
    "Frozen",
    "ResourceBound",
    "InlineReady",
    "IoWqQueued",
    "WorkerSelected",
    "ReissueHandled",
    "RevokeChecked",
    "Validated",
    "SideEffected",
    "CqePosted",
    "Settled",
    "Released",
    "Accepted",
    "BadSideEffectBeforeValidate",
    "BadImmutableOverwrite",
    "BadIoKiocbAuthority",
    "BadCredTctxAuthority",
    "BadRsrcNodeAuthority",
    "BadIoWqWorkAuthority",
    "BadReissueRefresh",
    "BadCqeSettlementProof",
    "BadCancelRevokeReceipt",
    "BadDoubleSettlement",
    "BadReleaseDropsLinuxRefs",
    "BadStaleExecuteAfterRevoke",
    "BadLinkInheritWithoutCarrier",
    "BadResourceUpdateMutatesInflight",
    "BadUringCmdWithoutEndpoint",
    "BadAbiApproval",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

TerminalPhases == {
    "Accepted",
    "BadSideEffectBeforeValidate",
    "BadImmutableOverwrite",
    "BadIoKiocbAuthority",
    "BadCredTctxAuthority",
    "BadRsrcNodeAuthority",
    "BadIoWqWorkAuthority",
    "BadReissueRefresh",
    "BadCqeSettlementProof",
    "BadCancelRevokeReceipt",
    "BadDoubleSettlement",
    "BadReleaseDropsLinuxRefs",
    "BadStaleExecuteAfterRevoke",
    "BadLinkInheritWithoutCarrier",
    "BadResourceUpdateMutatesInflight",
    "BadUringCmdWithoutEndpoint",
    "BadAbiApproval",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

StateFields == {
    "phase",
    "path",
    "requestAllocated",
    "sqeConsumed",
    "frozen",
    "resourceBound",
    "resourceGenerationSnap",
    "inlineReady",
    "ioWqQueued",
    "workerSelected",
    "reissueHandled",
    "cancelSeen",
    "revokeChecked",
    "validated",
    "effectiveSubsetCaller",
    "effectiveSubsetResource",
    "sideEffect",
    "cqePosted",
    "settled",
    "released",
    "settlementCount",
    "immutableOverwrite",
    "ioKiocbAuthority",
    "credTctxAuthority",
    "rsrcNodeAuthority",
    "ioWqWorkAuthority",
    "reissueRefresh",
    "cqeSettlementProof",
    "cancelRevokeReceipt",
    "releaseDropsLinuxRefs",
    "revoked",
    "staleRejected",
    "staleExecuted",
    "linkInheritWithoutCarrier",
    "resourceUpdateMutatesInflight",
    "uringCmdWithoutEndpoint",
    "abiApproved",
    "behaviorChange",
    "monitorVerified",
    "protectionClaim",
    "accepted"
}

NonBoolFields == {"phase", "path", "settlementCount"}
BoolFields == StateFields \ NonBoolFields

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ state.path \in Paths
    /\ state.settlementCount \in 0..2
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        path |-> "none",
        requestAllocated |-> FALSE,
        sqeConsumed |-> FALSE,
        frozen |-> FALSE,
        resourceBound |-> FALSE,
        resourceGenerationSnap |-> FALSE,
        inlineReady |-> FALSE,
        ioWqQueued |-> FALSE,
        workerSelected |-> FALSE,
        reissueHandled |-> FALSE,
        cancelSeen |-> FALSE,
        revokeChecked |-> FALSE,
        validated |-> FALSE,
        effectiveSubsetCaller |-> FALSE,
        effectiveSubsetResource |-> FALSE,
        sideEffect |-> FALSE,
        cqePosted |-> FALSE,
        settled |-> FALSE,
        released |-> FALSE,
        settlementCount |-> 0,
        immutableOverwrite |-> FALSE,
        ioKiocbAuthority |-> FALSE,
        credTctxAuthority |-> FALSE,
        rsrcNodeAuthority |-> FALSE,
        ioWqWorkAuthority |-> FALSE,
        reissueRefresh |-> FALSE,
        cqeSettlementProof |-> FALSE,
        cancelRevokeReceipt |-> FALSE,
        releaseDropsLinuxRefs |-> FALSE,
        revoked |-> FALSE,
        staleRejected |-> FALSE,
        staleExecuted |-> FALSE,
        linkInheritWithoutCarrier |-> FALSE,
        resourceUpdateMutatesInflight |-> FALSE,
        uringCmdWithoutEndpoint |-> FALSE,
        abiApproved |-> FALSE,
        behaviorChange |-> FALSE,
        monitorVerified |-> FALSE,
        protectionClaim |-> FALSE,
        accepted |-> FALSE
    ]

AllocateRequestStorage ==
    /\ state.phase = "Start"
    /\ state' = [state EXCEPT
        !.phase = "RequestAllocated",
        !.requestAllocated = TRUE]

ConsumeSqeFields ==
    /\ state.phase = "RequestAllocated"
    /\ state.requestAllocated
    /\ state' = [state EXCEPT
        !.phase = "SqeConsumed",
        !.sqeConsumed = TRUE]

FreezeCallerTuple ==
    /\ state.phase = "SqeConsumed"
    /\ state.sqeConsumed
    /\ state' = [state EXCEPT
        !.phase = "Frozen",
        !.frozen = TRUE]

BindResourceAuthority ==
    /\ state.phase = "Frozen"
    /\ state.frozen
    /\ state' = [state EXCEPT
        !.phase = "ResourceBound",
        !.resourceBound = TRUE,
        !.resourceGenerationSnap = TRUE]

PrepareInlineIssue ==
    /\ state.phase = "ResourceBound"
    /\ state.resourceBound
    /\ state.resourceGenerationSnap
    /\ state' = [state EXCEPT
        !.phase = "InlineReady",
        !.path = "inline",
        !.inlineReady = TRUE]

QueueIoWqRequest ==
    /\ state.phase = "ResourceBound"
    /\ state.resourceBound
    /\ state.resourceGenerationSnap
    /\ state' = [state EXCEPT
        !.phase = "IoWqQueued",
        !.path = "io_wq",
        !.ioWqQueued = TRUE]

SelectIoWqWorker ==
    /\ state.phase = "IoWqQueued"
    /\ state.ioWqQueued
    /\ state' = [state EXCEPT
        !.phase = "WorkerSelected",
        !.workerSelected = TRUE]

HandleReissueWithoutRefresh ==
    /\ state.phase \in {"InlineReady", "WorkerSelected"}
    /\ state.frozen
    /\ state.resourceBound
    /\ state' = [state EXCEPT
        !.phase = "ReissueHandled",
        !.reissueHandled = TRUE]

RevokeCheck ==
    /\ state.phase = "ReissueHandled"
    /\ state.reissueHandled
    /\ state' = [state EXCEPT
        !.phase = "RevokeChecked",
        !.revokeChecked = TRUE]

Validate ==
    /\ state.phase = "RevokeChecked"
    /\ state.revokeChecked
    /\ state' = [state EXCEPT
        !.phase = "Validated",
        !.validated = TRUE,
        !.effectiveSubsetCaller = TRUE,
        !.effectiveSubsetResource = TRUE]

DoSideEffect ==
    /\ state.phase = "Validated"
    /\ state.validated
    /\ state.revokeChecked
    /\ state.effectiveSubsetCaller
    /\ state.effectiveSubsetResource
    /\ state' = [state EXCEPT
        !.phase = "SideEffected",
        !.sideEffect = TRUE]

PostCqeResultOnly ==
    /\ state.phase = "SideEffected"
    /\ state.sideEffect
    /\ state' = [state EXCEPT
        !.phase = "CqePosted",
        !.cqePosted = TRUE]

SettleOnce ==
    /\ state.phase = "CqePosted"
    /\ state.cqePosted
    /\ state' = [state EXCEPT
        !.phase = "Settled",
        !.settled = TRUE,
        !.settlementCount = 1]

ReleaseCapschedRefsOnly ==
    /\ state.phase = "Settled"
    /\ state.settlementCount = 1
    /\ state' = [state EXCEPT
        !.phase = "Released",
        !.released = TRUE]

AcceptIoUringAdapter ==
    /\ state.phase = "Released"
    /\ state.released
    /\ state' = [state EXCEPT
        !.phase = "Accepted",
        !.accepted = TRUE]

BadSideEffectBeforeValidate ==
    /\ ALLOW_UNSAFE_SIDE_EFFECT_BEFORE_VALIDATE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadSideEffectBeforeValidate",
        !.sideEffect = TRUE]

BadImmutableOverwrite ==
    /\ ALLOW_UNSAFE_IMMUTABLE_OVERWRITE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadImmutableOverwrite",
        !.immutableOverwrite = TRUE]

BadIoKiocbAuthority ==
    /\ ALLOW_UNSAFE_IO_KIOCB_AUTHORITY
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadIoKiocbAuthority",
        !.ioKiocbAuthority = TRUE]

BadCredTctxAuthority ==
    /\ ALLOW_UNSAFE_CRED_TCTX_AUTHORITY
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadCredTctxAuthority",
        !.credTctxAuthority = TRUE]

BadRsrcNodeAuthority ==
    /\ ALLOW_UNSAFE_RSRC_NODE_AUTHORITY
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadRsrcNodeAuthority",
        !.rsrcNodeAuthority = TRUE]

BadIoWqWorkAuthority ==
    /\ ALLOW_UNSAFE_IO_WQ_WORK_AUTHORITY
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadIoWqWorkAuthority",
        !.ioWqWorkAuthority = TRUE]

BadReissueRefresh ==
    /\ ALLOW_UNSAFE_REISSUE_REFRESH
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadReissueRefresh",
        !.reissueRefresh = TRUE]

BadCqeSettlementProof ==
    /\ ALLOW_UNSAFE_CQE_SETTLEMENT_PROOF
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadCqeSettlementProof",
        !.cqeSettlementProof = TRUE]

BadCancelRevokeReceipt ==
    /\ ALLOW_UNSAFE_CANCEL_REVOKE_RECEIPT
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadCancelRevokeReceipt",
        !.cancelSeen = TRUE,
        !.cancelRevokeReceipt = TRUE]

BadDoubleSettlement ==
    /\ ALLOW_UNSAFE_DOUBLE_SETTLEMENT
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadDoubleSettlement",
        !.settlementCount = 2]

BadReleaseDropsLinuxRefs ==
    /\ ALLOW_UNSAFE_RELEASE_DROPS_LINUX_REFS
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadReleaseDropsLinuxRefs",
        !.releaseDropsLinuxRefs = TRUE]

BadStaleExecuteAfterRevoke ==
    /\ ALLOW_UNSAFE_STALE_EXECUTE_AFTER_REVOKE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadStaleExecuteAfterRevoke",
        !.revoked = TRUE,
        !.staleExecuted = TRUE,
        !.sideEffect = TRUE]

BadLinkInheritWithoutCarrier ==
    /\ ALLOW_UNSAFE_LINK_INHERIT_WITHOUT_CARRIER
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadLinkInheritWithoutCarrier",
        !.linkInheritWithoutCarrier = TRUE]

BadResourceUpdateMutatesInflight ==
    /\ ALLOW_UNSAFE_RESOURCE_UPDATE_MUTATES_INFLIGHT
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadResourceUpdateMutatesInflight",
        !.resourceUpdateMutatesInflight = TRUE]

BadUringCmdWithoutEndpoint ==
    /\ ALLOW_UNSAFE_URING_CMD_WITHOUT_ENDPOINT
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadUringCmdWithoutEndpoint",
        !.uringCmdWithoutEndpoint = TRUE]

BadAbiApproval ==
    /\ ALLOW_UNSAFE_ABI_APPROVAL
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadAbiApproval",
        !.abiApproved = TRUE]

BadBehaviorChange ==
    /\ ALLOW_UNSAFE_BEHAVIOR_CHANGE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadBehaviorChange",
        !.behaviorChange = TRUE]

BadMonitorVerified ==
    /\ ALLOW_UNSAFE_MONITOR_VERIFIED
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadMonitorVerified",
        !.monitorVerified = TRUE]

BadProtectionClaim ==
    /\ ALLOW_UNSAFE_PROTECTION_CLAIM
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadProtectionClaim",
        !.protectionClaim = TRUE]

Next ==
    IF state.phase \in TerminalPhases THEN
        UNCHANGED state
    ELSE
        \/ AllocateRequestStorage
        \/ ConsumeSqeFields
        \/ FreezeCallerTuple
        \/ BindResourceAuthority
        \/ PrepareInlineIssue
        \/ QueueIoWqRequest
        \/ SelectIoWqWorker
        \/ HandleReissueWithoutRefresh
        \/ RevokeCheck
        \/ Validate
        \/ DoSideEffect
        \/ PostCqeResultOnly
        \/ SettleOnce
        \/ ReleaseCapschedRefsOnly
        \/ AcceptIoUringAdapter
        \/ BadSideEffectBeforeValidate
        \/ BadImmutableOverwrite
        \/ BadIoKiocbAuthority
        \/ BadCredTctxAuthority
        \/ BadRsrcNodeAuthority
        \/ BadIoWqWorkAuthority
        \/ BadReissueRefresh
        \/ BadCqeSettlementProof
        \/ BadCancelRevokeReceipt
        \/ BadDoubleSettlement
        \/ BadReleaseDropsLinuxRefs
        \/ BadStaleExecuteAfterRevoke
        \/ BadLinkInheritWithoutCarrier
        \/ BadResourceUpdateMutatesInflight
        \/ BadUringCmdWithoutEndpoint
        \/ BadAbiApproval
        \/ BadBehaviorChange
        \/ BadMonitorVerified
        \/ BadProtectionClaim

Spec == Init /\ [][Next]_vars

NoSideEffectBeforeValidate ==
    state.sideEffect => /\ state.frozen
                        /\ state.resourceBound
                        /\ state.revokeChecked
                        /\ state.validated
                        /\ state.effectiveSubsetCaller
                        /\ state.effectiveSubsetResource
                        /\ ~state.revoked

FreezeBeforeIssueOrIoWq ==
    (state.inlineReady \/ state.ioWqQueued \/ state.workerSelected) =>
        /\ state.frozen
        /\ state.resourceBound
        /\ state.resourceGenerationSnap

NoImmutableOverwrite == ~state.immutableOverwrite

NoLinuxObjectAuthority ==
    /\ ~state.ioKiocbAuthority
    /\ ~state.credTctxAuthority
    /\ ~state.rsrcNodeAuthority
    /\ ~state.ioWqWorkAuthority

NoReissueRefresh == ~state.reissueRefresh

NoCqeSettlementProof == ~state.cqeSettlementProof

NoCancelRevokeReceipt == ~state.cancelRevokeReceipt

SettlementAtMostOnce == state.settlementCount <= 1

ReleaseDoesNotDropLinuxRefs == ~state.releaseDropsLinuxRefs

NoStaleExecutionAfterRevoke == ~state.staleExecuted

NoImplicitLinkAuthority == ~state.linkInheritWithoutCarrier

NoResourceUpdateMutatesInflight == ~state.resourceUpdateMutatesInflight

NoUringCmdWithoutEndpoint == ~state.uringCmdWithoutEndpoint

EffectiveAuthorityIsIntersection ==
    state.validated => /\ state.effectiveSubsetCaller
                       /\ state.effectiveSubsetResource

NoAbiApproval == ~state.abiApproved

NoBehaviorChange == ~state.behaviorChange

NoMonitorVerifiedClaim == ~state.monitorVerified

NoProtectionClaim == ~state.protectionClaim

AcceptedImpliesIoUringAdapterSafety ==
    state.accepted =>
        /\ state.requestAllocated
        /\ state.sqeConsumed
        /\ state.frozen
        /\ state.resourceBound
        /\ state.resourceGenerationSnap
        /\ state.reissueHandled
        /\ state.revokeChecked
        /\ state.validated
        /\ state.sideEffect
        /\ state.cqePosted
        /\ state.settlementCount = 1
        /\ state.released
        /\ ~state.immutableOverwrite
        /\ ~state.ioKiocbAuthority
        /\ ~state.credTctxAuthority
        /\ ~state.rsrcNodeAuthority
        /\ ~state.ioWqWorkAuthority
        /\ ~state.reissueRefresh
        /\ ~state.cqeSettlementProof
        /\ ~state.cancelRevokeReceipt
        /\ ~state.releaseDropsLinuxRefs
        /\ ~state.staleExecuted
        /\ ~state.linkInheritWithoutCarrier
        /\ ~state.resourceUpdateMutatesInflight
        /\ ~state.uringCmdWithoutEndpoint
        /\ ~state.abiApproved
        /\ ~state.behaviorChange
        /\ ~state.monitorVerified
        /\ ~state.protectionClaim

=============================================================================
