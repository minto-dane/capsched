---------------------- MODULE DirectCallAsyncCarrierApiSketch ----------------------

EXTENDS Naturals

CONSTANTS
    ALLOW_UNSAFE_SIDE_EFFECT_BEFORE_VALIDATE,
    ALLOW_UNSAFE_IMMUTABLE_OVERWRITE,
    ALLOW_UNSAFE_SECOND_CALLER_LEAK,
    ALLOW_UNSAFE_PENDING_OVERWRITE,
    ALLOW_UNSAFE_DOUBLE_SETTLEMENT,
    ALLOW_UNSAFE_RELEASE_DROPS_LINUX_REFS,
    ALLOW_UNSAFE_CQE_SETTLEMENT_PROOF,
    ALLOW_UNSAFE_REISSUE_REFRESH,
    ALLOW_UNSAFE_AUTHORITY_INTERSECTION,
    ALLOW_UNSAFE_LINUX_OBJECT_AUTHORITY,
    ALLOW_UNSAFE_ABI_APPROVAL,
    ALLOW_UNSAFE_BEHAVIOR_CHANGE,
    ALLOW_UNSAFE_MONITOR_VERIFIED,
    ALLOW_UNSAFE_PROTECTION_CLAIM

VARIABLE state

vars == <<state>>

Surfaces == {"none", "workqueue", "io_uring"}

Phases == {
    "Start",
    "EmptyCreated",
    "Frozen",
    "Bound",
    "Published",
    "CoalescingHandled",
    "IoPrepared",
    "IoReissueHandled",
    "RevokeChecked",
    "Validated",
    "SideEffected",
    "Settled",
    "Released",
    "Accepted",
    "BadSideEffectBeforeValidate",
    "BadImmutableOverwrite",
    "BadSecondCallerLeak",
    "BadPendingOverwrite",
    "BadDoubleSettlement",
    "BadReleaseDropsLinuxRefs",
    "BadCqeSettlementProof",
    "BadReissueRefresh",
    "BadAuthorityIntersection",
    "BadLinuxObjectAuthority",
    "BadAbiApproval",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

TerminalPhases == {
    "Accepted",
    "BadSideEffectBeforeValidate",
    "BadImmutableOverwrite",
    "BadSecondCallerLeak",
    "BadPendingOverwrite",
    "BadDoubleSettlement",
    "BadReleaseDropsLinuxRefs",
    "BadCqeSettlementProof",
    "BadReissueRefresh",
    "BadAuthorityIntersection",
    "BadLinuxObjectAuthority",
    "BadAbiApproval",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

SecondCandidateStates == {
    "none",
    "rejected_settled_released",
    "leaked",
    "overwritten"
}

StateFields == {
    "phase",
    "surface",
    "carrierCreated",
    "frozen",
    "bound",
    "published",
    "coalescedSecond",
    "secondCandidateState",
    "ioPrepared",
    "reissueHandled",
    "revokeChecked",
    "validated",
    "sideEffect",
    "settled",
    "released",
    "settlementCount",
    "immutableOverwrite",
    "pendingOverwrite",
    "releaseDropsLinuxRefs",
    "cqeSettlementProof",
    "reissueRefresh",
    "linuxObjectAuthority",
    "effectiveSubsetCaller",
    "effectiveSubsetService",
    "abiApproved",
    "behaviorChange",
    "monitorVerified",
    "protectionClaim",
    "accepted"
}

NonBoolFields == {"phase", "surface", "secondCandidateState", "settlementCount"}
BoolFields == StateFields \ NonBoolFields

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ state.surface \in Surfaces
    /\ state.secondCandidateState \in SecondCandidateStates
    /\ state.settlementCount \in 0..2
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        surface |-> "none",
        carrierCreated |-> FALSE,
        frozen |-> FALSE,
        bound |-> FALSE,
        published |-> FALSE,
        coalescedSecond |-> FALSE,
        secondCandidateState |-> "none",
        ioPrepared |-> FALSE,
        reissueHandled |-> FALSE,
        revokeChecked |-> FALSE,
        validated |-> FALSE,
        sideEffect |-> FALSE,
        settled |-> FALSE,
        released |-> FALSE,
        settlementCount |-> 0,
        immutableOverwrite |-> FALSE,
        pendingOverwrite |-> FALSE,
        releaseDropsLinuxRefs |-> FALSE,
        cqeSettlementProof |-> FALSE,
        reissueRefresh |-> FALSE,
        linuxObjectAuthority |-> FALSE,
        effectiveSubsetCaller |-> FALSE,
        effectiveSubsetService |-> FALSE,
        abiApproved |-> FALSE,
        behaviorChange |-> FALSE,
        monitorVerified |-> FALSE,
        protectionClaim |-> FALSE,
        accepted |-> FALSE
    ]

CreateWorkqueueCarrier ==
    /\ state.phase = "Start"
    /\ state' = [state EXCEPT
        !.phase = "EmptyCreated",
        !.surface = "workqueue",
        !.carrierCreated = TRUE]

CreateIoUringCarrier ==
    /\ state.phase = "Start"
    /\ state' = [state EXCEPT
        !.phase = "EmptyCreated",
        !.surface = "io_uring",
        !.carrierCreated = TRUE]

FreezeCarrier ==
    /\ state.phase = "EmptyCreated"
    /\ state.carrierCreated
    /\ state' = [state EXCEPT
        !.phase = "Frozen",
        !.frozen = TRUE]

BindCarrier ==
    /\ state.phase = "Frozen"
    /\ state.frozen
    /\ state' = [state EXCEPT
        !.phase = "Bound",
        !.bound = TRUE]

PublishWorkqueueCarrier ==
    /\ state.phase = "Bound"
    /\ state.surface = "workqueue"
    /\ state.frozen
    /\ state.bound
    /\ state' = [state EXCEPT
        !.phase = "Published",
        !.published = TRUE]

HandleWorkqueueCoalescing ==
    /\ state.phase = "Published"
    /\ state.surface = "workqueue"
    /\ state' = [state EXCEPT
        !.phase = "CoalescingHandled",
        !.coalescedSecond = TRUE,
        !.secondCandidateState = "rejected_settled_released"]

PrepareIoUringRequest ==
    /\ state.phase = "Bound"
    /\ state.surface = "io_uring"
    /\ state' = [state EXCEPT
        !.phase = "IoPrepared",
        !.ioPrepared = TRUE,
        !.published = TRUE]

HandleIoUringReissue ==
    /\ state.phase = "IoPrepared"
    /\ state.surface = "io_uring"
    /\ state' = [state EXCEPT
        !.phase = "IoReissueHandled",
        !.reissueHandled = TRUE]

RevokeCheckCarrier ==
    /\ state.phase \in {"CoalescingHandled", "IoReissueHandled"}
    /\ state' = [state EXCEPT
        !.phase = "RevokeChecked",
        !.revokeChecked = TRUE]

ValidateCarrier ==
    /\ state.phase = "RevokeChecked"
    /\ state.revokeChecked
    /\ state' = [state EXCEPT
        !.phase = "Validated",
        !.validated = TRUE,
        !.effectiveSubsetCaller = TRUE,
        !.effectiveSubsetService = TRUE]

DoSideEffect ==
    /\ state.phase = "Validated"
    /\ state.validated
    /\ state.revokeChecked
    /\ state.effectiveSubsetCaller
    /\ state.effectiveSubsetService
    /\ state' = [state EXCEPT
        !.phase = "SideEffected",
        !.sideEffect = TRUE]

SettleCarrier ==
    /\ state.phase = "SideEffected"
    /\ state.sideEffect
    /\ state' = [state EXCEPT
        !.phase = "Settled",
        !.settled = TRUE,
        !.settlementCount = 1]

ReleaseCarrier ==
    /\ state.phase = "Settled"
    /\ state.settled
    /\ state.settlementCount = 1
    /\ state' = [state EXCEPT
        !.phase = "Released",
        !.released = TRUE]

AcceptDesign ==
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

BadSecondCallerLeak ==
    /\ ALLOW_UNSAFE_SECOND_CALLER_LEAK
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadSecondCallerLeak",
        !.coalescedSecond = TRUE,
        !.secondCandidateState = "leaked"]

BadPendingOverwrite ==
    /\ ALLOW_UNSAFE_PENDING_OVERWRITE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadPendingOverwrite",
        !.pendingOverwrite = TRUE,
        !.secondCandidateState = "overwritten"]

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

BadCqeSettlementProof ==
    /\ ALLOW_UNSAFE_CQE_SETTLEMENT_PROOF
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadCqeSettlementProof",
        !.cqeSettlementProof = TRUE]

BadReissueRefresh ==
    /\ ALLOW_UNSAFE_REISSUE_REFRESH
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadReissueRefresh",
        !.reissueRefresh = TRUE]

BadAuthorityIntersection ==
    /\ ALLOW_UNSAFE_AUTHORITY_INTERSECTION
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadAuthorityIntersection",
        !.validated = TRUE,
        !.effectiveSubsetCaller = FALSE,
        !.effectiveSubsetService = TRUE]

BadLinuxObjectAuthority ==
    /\ ALLOW_UNSAFE_LINUX_OBJECT_AUTHORITY
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadLinuxObjectAuthority",
        !.linuxObjectAuthority = TRUE]

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
        \/ CreateWorkqueueCarrier
        \/ CreateIoUringCarrier
        \/ FreezeCarrier
        \/ BindCarrier
        \/ PublishWorkqueueCarrier
        \/ HandleWorkqueueCoalescing
        \/ PrepareIoUringRequest
        \/ HandleIoUringReissue
        \/ RevokeCheckCarrier
        \/ ValidateCarrier
        \/ DoSideEffect
        \/ SettleCarrier
        \/ ReleaseCarrier
        \/ AcceptDesign
        \/ BadSideEffectBeforeValidate
        \/ BadImmutableOverwrite
        \/ BadSecondCallerLeak
        \/ BadPendingOverwrite
        \/ BadDoubleSettlement
        \/ BadReleaseDropsLinuxRefs
        \/ BadCqeSettlementProof
        \/ BadReissueRefresh
        \/ BadAuthorityIntersection
        \/ BadLinuxObjectAuthority
        \/ BadAbiApproval
        \/ BadBehaviorChange
        \/ BadMonitorVerified
        \/ BadProtectionClaim

Spec == Init /\ [][Next]_vars

NoSideEffectBeforeValidate ==
    state.sideEffect => /\ state.validated
                        /\ state.revokeChecked
                        /\ state.effectiveSubsetCaller
                        /\ state.effectiveSubsetService

NoImmutableOverwrite == ~state.immutableOverwrite

NoSecondCallerLeak == state.secondCandidateState # "leaked"

NoPendingOverwrite == ~state.pendingOverwrite

SettlementAtMostOnce == state.settlementCount <= 1

ReleasedOnlyAfterSettlement == state.released => state.settlementCount = 1

ReleaseDoesNotDropLinuxRefs == ~state.releaseDropsLinuxRefs

NoCqeSettlementProof == ~state.cqeSettlementProof

NoReissueRefresh == ~state.reissueRefresh

NoLinuxObjectAuthority == ~state.linuxObjectAuthority

EffectiveAuthorityIsIntersection ==
    state.validated => /\ state.effectiveSubsetCaller
                       /\ state.effectiveSubsetService

NoAbiApproval == ~state.abiApproved

NoBehaviorChange == ~state.behaviorChange

NoMonitorVerifiedClaim == ~state.monitorVerified

NoProtectionClaim == ~state.protectionClaim

AcceptedImpliesSketchSafety ==
    state.accepted =>
        /\ state.frozen
        /\ state.bound
        /\ state.published
        /\ state.revokeChecked
        /\ state.validated
        /\ state.sideEffect
        /\ state.settlementCount = 1
        /\ state.released
        /\ ~state.immutableOverwrite
        /\ ~state.pendingOverwrite
        /\ ~state.releaseDropsLinuxRefs
        /\ ~state.cqeSettlementProof
        /\ ~state.reissueRefresh
        /\ ~state.linuxObjectAuthority
        /\ ~state.abiApproved
        /\ ~state.behaviorChange
        /\ ~state.monitorVerified
        /\ ~state.protectionClaim

=============================================================================
