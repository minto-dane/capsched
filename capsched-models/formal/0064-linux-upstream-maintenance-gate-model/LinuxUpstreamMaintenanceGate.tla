------------------------- MODULE LinuxUpstreamMaintenanceGate -------------------------

CONSTANTS
    ALLOW_UNSAFE_APPROVE_WITHOUT_NEED,
    ALLOW_UNSAFE_APPROVE_WITHOUT_FETCH,
    ALLOW_UNSAFE_APPROVE_WITHOUT_WATCHED_DIFF,
    ALLOW_UNSAFE_APPROVE_WITHOUT_MERGE_TREE,
    ALLOW_UNSAFE_BEHAVIOR_CHANGE,
    ALLOW_UNSAFE_HOOK,
    ALLOW_UNSAFE_ABI,
    ALLOW_UNSAFE_OBJECT_LAYOUT,
    ALLOW_UNSAFE_RUNTIME_STATE,
    ALLOW_UNSAFE_PROTECTION_CLAIM

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "PatchFootprintRead",
    "UpstreamFetched",
    "WatchedDiffReviewed",
    "MergeTreeChecked",
    "ValueAssessed",
    "DecisionDeferred",
    "Accepted",
    "BadApproveWithoutNeed",
    "BadApproveWithoutFetch",
    "BadApproveWithoutWatchedDiff",
    "BadApproveWithoutMergeTree",
    "BadBehaviorChange",
    "BadHook",
    "BadAbi",
    "BadObjectLayout",
    "BadRuntimeState",
    "BadProtectionClaim"
}

TerminalPhases == {
    "Accepted",
    "BadApproveWithoutNeed",
    "BadApproveWithoutFetch",
    "BadApproveWithoutWatchedDiff",
    "BadApproveWithoutMergeTree",
    "BadBehaviorChange",
    "BadHook",
    "BadAbi",
    "BadObjectLayout",
    "BadRuntimeState",
    "BadProtectionClaim"
}

StateFields == {
    "phase",
    "patchFootprintRead",
    "l0FootprintSmall",
    "upstreamFetched",
    "watchedDiffReviewed",
    "directFootprintDrift",
    "futureAttachmentDrift",
    "semanticDriftRequiresRefresh",
    "mergeTreeChecked",
    "mergeTreeClean",
    "concreteConsumerNeed",
    "valueAssessed",
    "noBehaviorPatchDeferred",
    "noBehaviorPatchApproved",
    "behaviorChange",
    "hook",
    "abi",
    "objectLayout",
    "runtimeState",
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
        patchFootprintRead |-> FALSE,
        l0FootprintSmall |-> FALSE,
        upstreamFetched |-> FALSE,
        watchedDiffReviewed |-> FALSE,
        directFootprintDrift |-> FALSE,
        futureAttachmentDrift |-> FALSE,
        semanticDriftRequiresRefresh |-> FALSE,
        mergeTreeChecked |-> FALSE,
        mergeTreeClean |-> FALSE,
        concreteConsumerNeed |-> FALSE,
        valueAssessed |-> FALSE,
        noBehaviorPatchDeferred |-> FALSE,
        noBehaviorPatchApproved |-> FALSE,
        behaviorChange |-> FALSE,
        hook |-> FALSE,
        abi |-> FALSE,
        objectLayout |-> FALSE,
        runtimeState |-> FALSE,
        protectionClaim |-> FALSE,
        accepted |-> FALSE
    ]

ReadPatchFootprint ==
    /\ state.phase = "Start"
    /\ state' = [state EXCEPT
        !.phase = "PatchFootprintRead",
        !.patchFootprintRead = TRUE,
        !.l0FootprintSmall = TRUE]

FetchUpstream ==
    /\ state.phase = "PatchFootprintRead"
    /\ state.patchFootprintRead
    /\ state' = [state EXCEPT
        !.phase = "UpstreamFetched",
        !.upstreamFetched = TRUE]

ReviewWatchedDiff ==
    /\ state.phase = "UpstreamFetched"
    /\ state.upstreamFetched
    /\ state' = [state EXCEPT
        !.phase = "WatchedDiffReviewed",
        !.watchedDiffReviewed = TRUE,
        !.directFootprintDrift = FALSE,
        !.futureAttachmentDrift = FALSE,
        !.semanticDriftRequiresRefresh = FALSE]

CheckMergeTree ==
    /\ state.phase = "WatchedDiffReviewed"
    /\ state.watchedDiffReviewed
    /\ state' = [state EXCEPT
        !.phase = "MergeTreeChecked",
        !.mergeTreeChecked = TRUE,
        !.mergeTreeClean = TRUE]

AssessValue ==
    /\ state.phase = "MergeTreeChecked"
    /\ state.mergeTreeChecked
    /\ state.mergeTreeClean
    /\ state' = [state EXCEPT
        !.phase = "ValueAssessed",
        !.valueAssessed = TRUE,
        !.concreteConsumerNeed = FALSE]

DeferNoBehaviorPatch ==
    /\ state.phase = "ValueAssessed"
    /\ state.valueAssessed
    /\ ~state.concreteConsumerNeed
    /\ state' = [state EXCEPT
        !.phase = "DecisionDeferred",
        !.noBehaviorPatchDeferred = TRUE,
        !.noBehaviorPatchApproved = FALSE]

AcceptDeferredDecision ==
    /\ state.phase = "DecisionDeferred"
    /\ state.noBehaviorPatchDeferred
    /\ state' = [state EXCEPT
        !.phase = "Accepted",
        !.accepted = TRUE]

BadApproveWithoutNeed ==
    /\ ALLOW_UNSAFE_APPROVE_WITHOUT_NEED
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadApproveWithoutNeed",
        !.upstreamFetched = TRUE,
        !.watchedDiffReviewed = TRUE,
        !.mergeTreeChecked = TRUE,
        !.mergeTreeClean = TRUE,
        !.concreteConsumerNeed = FALSE,
        !.noBehaviorPatchApproved = TRUE]

BadApproveWithoutFetch ==
    /\ ALLOW_UNSAFE_APPROVE_WITHOUT_FETCH
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadApproveWithoutFetch",
        !.concreteConsumerNeed = TRUE,
        !.watchedDiffReviewed = TRUE,
        !.mergeTreeChecked = TRUE,
        !.mergeTreeClean = TRUE,
        !.noBehaviorPatchApproved = TRUE]

BadApproveWithoutWatchedDiff ==
    /\ ALLOW_UNSAFE_APPROVE_WITHOUT_WATCHED_DIFF
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadApproveWithoutWatchedDiff",
        !.upstreamFetched = TRUE,
        !.concreteConsumerNeed = TRUE,
        !.mergeTreeChecked = TRUE,
        !.mergeTreeClean = TRUE,
        !.noBehaviorPatchApproved = TRUE]

BadApproveWithoutMergeTree ==
    /\ ALLOW_UNSAFE_APPROVE_WITHOUT_MERGE_TREE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadApproveWithoutMergeTree",
        !.upstreamFetched = TRUE,
        !.watchedDiffReviewed = TRUE,
        !.concreteConsumerNeed = TRUE,
        !.mergeTreeChecked = TRUE,
        !.mergeTreeClean = FALSE,
        !.noBehaviorPatchApproved = TRUE]

BadBehaviorChange ==
    /\ ALLOW_UNSAFE_BEHAVIOR_CHANGE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadBehaviorChange",
        !.behaviorChange = TRUE]

BadHook ==
    /\ ALLOW_UNSAFE_HOOK
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadHook",
        !.hook = TRUE]

BadAbi ==
    /\ ALLOW_UNSAFE_ABI
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadAbi",
        !.abi = TRUE]

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

BadProtectionClaim ==
    /\ ALLOW_UNSAFE_PROTECTION_CLAIM
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadProtectionClaim",
        !.protectionClaim = TRUE]

Next ==
    \/ ReadPatchFootprint
    \/ FetchUpstream
    \/ ReviewWatchedDiff
    \/ CheckMergeTree
    \/ AssessValue
    \/ DeferNoBehaviorPatch
    \/ AcceptDeferredDecision
    \/ BadApproveWithoutNeed
    \/ BadApproveWithoutFetch
    \/ BadApproveWithoutWatchedDiff
    \/ BadApproveWithoutMergeTree
    \/ BadBehaviorChange
    \/ BadHook
    \/ BadAbi
    \/ BadObjectLayout
    \/ BadRuntimeState
    \/ BadProtectionClaim

Spec == Init /\ [][Next]_vars

NoCurrentPatchApproval == ~state.noBehaviorPatchApproved

NoApprovalWithoutNeed ==
    ~(state.noBehaviorPatchApproved /\ ~state.concreteConsumerNeed)

NoApprovalWithoutFetch ==
    ~(state.noBehaviorPatchApproved /\ ~state.upstreamFetched)

NoApprovalWithoutWatchedDiff ==
    ~(state.noBehaviorPatchApproved /\ ~state.watchedDiffReviewed)

NoApprovalWithoutMergeTree ==
    ~(state.noBehaviorPatchApproved /\ ~state.mergeTreeClean)

NoBehaviorChange == ~state.behaviorChange
NoHook == ~state.hook
NoAbi == ~state.abi
NoObjectLayout == ~state.objectLayout
NoRuntimeState == ~state.runtimeState
NoProtectionClaim == ~state.protectionClaim

AcceptedRequiresReviewedDefer ==
    state.accepted =>
        /\ state.patchFootprintRead
        /\ state.upstreamFetched
        /\ state.watchedDiffReviewed
        /\ state.mergeTreeChecked
        /\ state.mergeTreeClean
        /\ state.valueAssessed
        /\ state.noBehaviorPatchDeferred
        /\ ~state.noBehaviorPatchApproved
        /\ ~state.directFootprintDrift
        /\ ~state.futureAttachmentDrift
        /\ ~state.semanticDriftRequiresRefresh

================================================================================
