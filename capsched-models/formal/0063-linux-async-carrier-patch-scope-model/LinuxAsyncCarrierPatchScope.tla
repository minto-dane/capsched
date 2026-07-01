----------------------- MODULE LinuxAsyncCarrierPatchScope -----------------------

CONSTANTS
    ALLOW_UNSAFE_LINUX_PATCH_APPROVAL,
    ALLOW_UNSAFE_WORKQUEUE_HOOK,
    ALLOW_UNSAFE_IOURING_HOOK,
    ALLOW_UNSAFE_DIRECT_CALL_ABI,
    ALLOW_UNSAFE_PUBLIC_TRACEPOINT_ABI,
    ALLOW_UNSAFE_CALLABLE_PROTOTYPE,
    ALLOW_UNSAFE_OBJECT_LAYOUT,
    ALLOW_UNSAFE_RUNTIME_STATE,
    ALLOW_UNSAFE_WORKQUEUE_IOURING_INCLUDE,
    ALLOW_UNSAFE_BEHAVIOR_CHANGE,
    ALLOW_UNSAFE_MONITOR_VERIFIED,
    ALLOW_UNSAFE_PROTECTION_CLAIM

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "CombinedGateRead",
    "PatchClassified",
    "BehaviorHooksBlocked",
    "NoBehaviorScopeRecorded",
    "ReviewPreconditionsRecorded",
    "CandidatePatchPlanAccepted",
    "Accepted",
    "BadLinuxPatchApproval",
    "BadWorkqueueHook",
    "BadIoUringHook",
    "BadDirectCallAbi",
    "BadPublicTracepointAbi",
    "BadCallablePrototype",
    "BadObjectLayout",
    "BadRuntimeState",
    "BadWorkqueueIoUringInclude",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

TerminalPhases == {
    "Accepted",
    "BadLinuxPatchApproval",
    "BadWorkqueueHook",
    "BadIoUringHook",
    "BadDirectCallAbi",
    "BadPublicTracepointAbi",
    "BadCallablePrototype",
    "BadObjectLayout",
    "BadRuntimeState",
    "BadWorkqueueIoUringInclude",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

StateFields == {
    "phase",
    "combinedGateRead",
    "patchClassified",
    "noLinuxPatchClassAllowed",
    "opaqueTypeScaffoldCandidateOnly",
    "internalStubCandidateOnly",
    "workqueueHookBlocked",
    "ioUringHookBlocked",
    "directCallAbiBlocked",
    "behaviorEnforcementBlocked",
    "reviewPreconditionsRecorded",
    "candidatePatchPlanAccepted",
    "linuxPatchApproved",
    "workqueueHook",
    "ioUringHook",
    "directCallAbi",
    "publicTracepointAbi",
    "callablePrototype",
    "objectLayout",
    "runtimeState",
    "workqueueIoUringInclude",
    "behaviorChange",
    "monitorVerified",
    "protectionClaim",
    "accepted"
}

NonBoolFields == {"phase"}
BoolFields == StateFields \ NonBoolFields

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        combinedGateRead |-> FALSE,
        patchClassified |-> FALSE,
        noLinuxPatchClassAllowed |-> FALSE,
        opaqueTypeScaffoldCandidateOnly |-> FALSE,
        internalStubCandidateOnly |-> FALSE,
        workqueueHookBlocked |-> FALSE,
        ioUringHookBlocked |-> FALSE,
        directCallAbiBlocked |-> FALSE,
        behaviorEnforcementBlocked |-> FALSE,
        reviewPreconditionsRecorded |-> FALSE,
        candidatePatchPlanAccepted |-> FALSE,
        linuxPatchApproved |-> FALSE,
        workqueueHook |-> FALSE,
        ioUringHook |-> FALSE,
        directCallAbi |-> FALSE,
        publicTracepointAbi |-> FALSE,
        callablePrototype |-> FALSE,
        objectLayout |-> FALSE,
        runtimeState |-> FALSE,
        workqueueIoUringInclude |-> FALSE,
        behaviorChange |-> FALSE,
        monitorVerified |-> FALSE,
        protectionClaim |-> FALSE,
        accepted |-> FALSE
    ]

ReadCombinedGate ==
    /\ state.phase = "Start"
    /\ state' = [state EXCEPT
        !.phase = "CombinedGateRead",
        !.combinedGateRead = TRUE]

ClassifyPatchPlan ==
    /\ state.phase = "CombinedGateRead"
    /\ state.combinedGateRead
    /\ state' = [state EXCEPT
        !.phase = "PatchClassified",
        !.patchClassified = TRUE,
        !.noLinuxPatchClassAllowed = TRUE,
        !.opaqueTypeScaffoldCandidateOnly = TRUE,
        !.internalStubCandidateOnly = TRUE]

BlockBehaviorHooks ==
    /\ state.phase = "PatchClassified"
    /\ state.patchClassified
    /\ state' = [state EXCEPT
        !.phase = "BehaviorHooksBlocked",
        !.workqueueHookBlocked = TRUE,
        !.ioUringHookBlocked = TRUE,
        !.directCallAbiBlocked = TRUE,
        !.behaviorEnforcementBlocked = TRUE]

RecordNoBehaviorScope ==
    /\ state.phase = "BehaviorHooksBlocked"
    /\ state.workqueueHookBlocked
    /\ state.ioUringHookBlocked
    /\ state.directCallAbiBlocked
    /\ state.behaviorEnforcementBlocked
    /\ state' = [state EXCEPT
        !.phase = "NoBehaviorScopeRecorded"]

RecordReviewPreconditions ==
    /\ state.phase = "NoBehaviorScopeRecorded"
    /\ state' = [state EXCEPT
        !.phase = "ReviewPreconditionsRecorded",
        !.reviewPreconditionsRecorded = TRUE]

AcceptCandidatePatchPlan ==
    /\ state.phase = "ReviewPreconditionsRecorded"
    /\ state.reviewPreconditionsRecorded
    /\ state' = [state EXCEPT
        !.phase = "CandidatePatchPlanAccepted",
        !.candidatePatchPlanAccepted = TRUE]

AcceptPlan ==
    /\ state.phase = "CandidatePatchPlanAccepted"
    /\ state.candidatePatchPlanAccepted
    /\ state' = [state EXCEPT
        !.phase = "Accepted",
        !.accepted = TRUE]

BadLinuxPatchApproval ==
    /\ ALLOW_UNSAFE_LINUX_PATCH_APPROVAL
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadLinuxPatchApproval",
        !.linuxPatchApproved = TRUE]

BadWorkqueueHook ==
    /\ ALLOW_UNSAFE_WORKQUEUE_HOOK
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadWorkqueueHook",
        !.workqueueHook = TRUE]

BadIoUringHook ==
    /\ ALLOW_UNSAFE_IOURING_HOOK
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadIoUringHook",
        !.ioUringHook = TRUE]

BadDirectCallAbi ==
    /\ ALLOW_UNSAFE_DIRECT_CALL_ABI
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadDirectCallAbi",
        !.directCallAbi = TRUE]

BadPublicTracepointAbi ==
    /\ ALLOW_UNSAFE_PUBLIC_TRACEPOINT_ABI
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadPublicTracepointAbi",
        !.publicTracepointAbi = TRUE]

BadCallablePrototype ==
    /\ ALLOW_UNSAFE_CALLABLE_PROTOTYPE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadCallablePrototype",
        !.callablePrototype = TRUE]

BadObjectLayout ==
    /\ ALLOW_UNSAFE_OBJECT_LAYOUT
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadObjectLayout",
        !.objectLayout = TRUE]

BadRuntimeState ==
    /\ ALLOW_UNSAFE_RUNTIME_STATE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadRuntimeState",
        !.runtimeState = TRUE]

BadWorkqueueIoUringInclude ==
    /\ ALLOW_UNSAFE_WORKQUEUE_IOURING_INCLUDE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadWorkqueueIoUringInclude",
        !.workqueueIoUringInclude = TRUE]

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
        \/ ReadCombinedGate
        \/ ClassifyPatchPlan
        \/ BlockBehaviorHooks
        \/ RecordNoBehaviorScope
        \/ RecordReviewPreconditions
        \/ AcceptCandidatePatchPlan
        \/ AcceptPlan
        \/ BadLinuxPatchApproval
        \/ BadWorkqueueHook
        \/ BadIoUringHook
        \/ BadDirectCallAbi
        \/ BadPublicTracepointAbi
        \/ BadCallablePrototype
        \/ BadObjectLayout
        \/ BadRuntimeState
        \/ BadWorkqueueIoUringInclude
        \/ BadBehaviorChange
        \/ BadMonitorVerified
        \/ BadProtectionClaim

Spec == Init /\ [][Next]_vars

CandidatePlanRequiresReview ==
    state.candidatePatchPlanAccepted =>
        /\ state.combinedGateRead
        /\ state.patchClassified
        /\ state.workqueueHookBlocked
        /\ state.ioUringHookBlocked
        /\ state.directCallAbiBlocked
        /\ state.behaviorEnforcementBlocked
        /\ state.reviewPreconditionsRecorded

NoLinuxPatchApproval == ~state.linuxPatchApproved

NoWorkqueueHook == ~state.workqueueHook

NoIoUringHook == ~state.ioUringHook

NoDirectCallAbi == ~state.directCallAbi

NoPublicTracepointAbi == ~state.publicTracepointAbi

NoCallablePrototype == ~state.callablePrototype

NoObjectLayout == ~state.objectLayout

NoRuntimeState == ~state.runtimeState

NoWorkqueueIoUringInclude == ~state.workqueueIoUringInclude

NoBehaviorChange == ~state.behaviorChange

NoMonitorVerifiedClaim == ~state.monitorVerified

NoProtectionClaim == ~state.protectionClaim

AcceptedImpliesPatchScopeSafety ==
    state.accepted =>
        /\ state.candidatePatchPlanAccepted
        /\ state.combinedGateRead
        /\ state.patchClassified
        /\ state.workqueueHookBlocked
        /\ state.ioUringHookBlocked
        /\ state.directCallAbiBlocked
        /\ state.behaviorEnforcementBlocked
        /\ state.reviewPreconditionsRecorded
        /\ ~state.linuxPatchApproved
        /\ ~state.workqueueHook
        /\ ~state.ioUringHook
        /\ ~state.directCallAbi
        /\ ~state.publicTracepointAbi
        /\ ~state.callablePrototype
        /\ ~state.objectLayout
        /\ ~state.runtimeState
        /\ ~state.workqueueIoUringInclude
        /\ ~state.behaviorChange
        /\ ~state.monitorVerified
        /\ ~state.protectionClaim

=============================================================================
