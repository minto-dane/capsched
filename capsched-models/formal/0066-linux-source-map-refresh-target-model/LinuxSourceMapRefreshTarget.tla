----------------------- MODULE LinuxSourceMapRefreshTarget -----------------------
EXTENDS Naturals

CONSTANTS
    ALLOW_UNSAFE_SELECT_WITHOUT_GATE,
    ALLOW_UNSAFE_SELECT_STALE_PATCH_TARGET,
    ALLOW_UNSAFE_SELECT_NEARBY_DRIFT_ONLY,
    ALLOW_UNSAFE_LINUX_PATCH_APPROVAL,
    ALLOW_UNSAFE_RUNTIME_CLAIM,
    ALLOW_UNSAFE_PROTECTION_CLAIM,
    ALLOW_UNSAFE_ASYNC_NAME_MOVEMENT

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "GateRead",
    "CandidatesCompared",
    "SchedulerAuthoritySelected",
    "PatchMovementBlocked",
    "Accepted",
    "BadSelectWithoutGate",
    "BadSelectStalePatchTarget",
    "BadSelectNearbyDriftOnly",
    "BadLinuxPatchApproval",
    "BadRuntimeClaim",
    "BadProtectionClaim",
    "BadAsyncNameMovement"
}

TerminalPhases == {
    "Accepted",
    "BadSelectWithoutGate",
    "BadSelectStalePatchTarget",
    "BadSelectNearbyDriftOnly",
    "BadLinuxPatchApproval",
    "BadRuntimeClaim",
    "BadProtectionClaim",
    "BadAsyncNameMovement"
}

StateFields == {
    "phase",
    "freshnessGateRead",
    "modelFresh",
    "modelRefreshRequiredGroups",
    "nearbyNonIntersectingDriftOnly",
    "candidatesCompared",
    "selectedSchedulerAuthorityCore",
    "selectedSourceMapRefreshTarget",
    "selectedLinuxPatchTarget",
    "selectedStaleTarget",
    "selectedNearbyDriftOnly",
    "patchMovementBlocked",
    "asyncNameMovement",
    "linuxPatchApproved",
    "runtimeCoverageClaim",
    "protectionClaim",
    "accepted"
}

NonBoolFields == {"phase", "modelRefreshRequiredGroups"}
BoolFields == StateFields \ NonBoolFields

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ state.modelRefreshRequiredGroups \in 0..9
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        freshnessGateRead |-> FALSE,
        modelFresh |-> FALSE,
        modelRefreshRequiredGroups |-> 0,
        nearbyNonIntersectingDriftOnly |-> FALSE,
        candidatesCompared |-> FALSE,
        selectedSchedulerAuthorityCore |-> FALSE,
        selectedSourceMapRefreshTarget |-> FALSE,
        selectedLinuxPatchTarget |-> FALSE,
        selectedStaleTarget |-> FALSE,
        selectedNearbyDriftOnly |-> FALSE,
        patchMovementBlocked |-> FALSE,
        asyncNameMovement |-> FALSE,
        linuxPatchApproved |-> FALSE,
        runtimeCoverageClaim |-> FALSE,
        protectionClaim |-> FALSE,
        accepted |-> FALSE
    ]

ReadGate ==
    /\ state.phase = "Start"
    /\ state' = [state EXCEPT
        !.phase = "GateRead",
        !.freshnessGateRead = TRUE,
        !.modelFresh = TRUE,
        !.modelRefreshRequiredGroups = 0,
        !.nearbyNonIntersectingDriftOnly = TRUE]

CompareCandidates ==
    /\ state.phase = "GateRead"
    /\ state.freshnessGateRead
    /\ state.modelFresh
    /\ state.modelRefreshRequiredGroups = 0
    /\ state' = [state EXCEPT
        !.phase = "CandidatesCompared",
        !.candidatesCompared = TRUE]

SelectSchedulerAuthority ==
    /\ state.phase = "CandidatesCompared"
    /\ state.candidatesCompared
    /\ state' = [state EXCEPT
        !.phase = "SchedulerAuthoritySelected",
        !.selectedSchedulerAuthorityCore = TRUE,
        !.selectedSourceMapRefreshTarget = TRUE,
        !.selectedLinuxPatchTarget = FALSE,
        !.selectedStaleTarget = FALSE,
        !.selectedNearbyDriftOnly = FALSE]

BlockPatchMovement ==
    /\ state.phase = "SchedulerAuthoritySelected"
    /\ state.selectedSchedulerAuthorityCore
    /\ state.selectedSourceMapRefreshTarget
    /\ ~state.selectedLinuxPatchTarget
    /\ state' = [state EXCEPT
        !.phase = "PatchMovementBlocked",
        !.patchMovementBlocked = TRUE,
        !.linuxPatchApproved = FALSE,
        !.asyncNameMovement = FALSE]

AcceptSelection ==
    /\ state.phase = "PatchMovementBlocked"
    /\ state.patchMovementBlocked
    /\ state' = [state EXCEPT
        !.phase = "Accepted",
        !.accepted = TRUE]

BadSelectWithoutGate ==
    /\ ALLOW_UNSAFE_SELECT_WITHOUT_GATE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadSelectWithoutGate",
        !.selectedSchedulerAuthorityCore = TRUE,
        !.selectedSourceMapRefreshTarget = TRUE]

BadSelectStalePatchTarget ==
    /\ ALLOW_UNSAFE_SELECT_STALE_PATCH_TARGET
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadSelectStalePatchTarget",
        !.freshnessGateRead = TRUE,
        !.modelFresh = FALSE,
        !.modelRefreshRequiredGroups = 1,
        !.selectedStaleTarget = TRUE,
        !.selectedLinuxPatchTarget = TRUE]

BadSelectNearbyDriftOnly ==
    /\ ALLOW_UNSAFE_SELECT_NEARBY_DRIFT_ONLY
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadSelectNearbyDriftOnly",
        !.freshnessGateRead = TRUE,
        !.nearbyNonIntersectingDriftOnly = TRUE,
        !.selectedNearbyDriftOnly = TRUE,
        !.selectedSourceMapRefreshTarget = TRUE]

BadLinuxPatchApproval ==
    /\ ALLOW_UNSAFE_LINUX_PATCH_APPROVAL
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadLinuxPatchApproval",
        !.freshnessGateRead = TRUE,
        !.candidatesCompared = TRUE,
        !.selectedSchedulerAuthorityCore = TRUE,
        !.linuxPatchApproved = TRUE,
        !.selectedLinuxPatchTarget = TRUE]

BadRuntimeClaim ==
    /\ ALLOW_UNSAFE_RUNTIME_CLAIM
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadRuntimeClaim",
        !.runtimeCoverageClaim = TRUE]

BadProtectionClaim ==
    /\ ALLOW_UNSAFE_PROTECTION_CLAIM
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadProtectionClaim",
        !.protectionClaim = TRUE]

BadAsyncNameMovement ==
    /\ ALLOW_UNSAFE_ASYNC_NAME_MOVEMENT
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadAsyncNameMovement",
        !.asyncNameMovement = TRUE]

Next ==
    \/ ReadGate
    \/ CompareCandidates
    \/ SelectSchedulerAuthority
    \/ BlockPatchMovement
    \/ AcceptSelection
    \/ BadSelectWithoutGate
    \/ BadSelectStalePatchTarget
    \/ BadSelectNearbyDriftOnly
    \/ BadLinuxPatchApproval
    \/ BadRuntimeClaim
    \/ BadProtectionClaim
    \/ BadAsyncNameMovement

Spec == Init /\ [][Next]_vars

SelectionRequiresGate ==
    state.selectedSourceMapRefreshTarget => state.freshnessGateRead

NoStalePatchTargetSelection ==
    ~(state.selectedStaleTarget /\ state.selectedLinuxPatchTarget)

NoNearbyDriftOnlyPrimaryTarget ==
    ~state.selectedNearbyDriftOnly

NoLinuxPatchApproval ==
    ~state.linuxPatchApproved

NoAsyncNameMovement ==
    ~state.asyncNameMovement

NoRuntimeCoverageClaim ==
    ~state.runtimeCoverageClaim

NoProtectionClaim ==
    ~state.protectionClaim

AcceptedRequiresSchedulerAuthoritySourceRefresh ==
    state.accepted =>
        /\ state.selectedSchedulerAuthorityCore
        /\ state.selectedSourceMapRefreshTarget
        /\ ~state.selectedLinuxPatchTarget
        /\ state.patchMovementBlocked
        /\ state.modelFresh
        /\ state.modelRefreshRequiredGroups = 0

================================================================================
