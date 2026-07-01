----------------------- MODULE LinuxSourceDriftFreshnessGate -----------------------

CONSTANTS
    ALLOW_UNSAFE_PATCH_WITHOUT_OBSERVATION,
    ALLOW_UNSAFE_CLEAN_MERGE_AS_FRESHNESS,
    ALLOW_UNSAFE_PATCH_WITH_STALE_MODEL,
    ALLOW_UNSAFE_MISSING_WATCH_MAP,
    ALLOW_UNSAFE_NEW_LINUX_NAMES,
    ALLOW_UNSAFE_BEHAVIOR_CHANGE,
    ALLOW_UNSAFE_ABI,
    ALLOW_UNSAFE_PROTECTION_CLAIM,
    ALLOW_UNSAFE_MISSING_NON_CLAIMS

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "WatchMapLoaded",
    "SourceObserved",
    "GroupsClassified",
    "MergeTreeChecked",
    "FreshnessComputed",
    "PatchDeferred",
    "Accepted",
    "BadPatchWithoutObservation",
    "BadCleanMergeAsFreshness",
    "BadPatchWithStaleModel",
    "BadMissingWatchMap",
    "BadNewLinuxNames",
    "BadBehaviorChange",
    "BadAbi",
    "BadProtectionClaim",
    "BadMissingNonClaims"
}

TerminalPhases == {
    "Accepted",
    "BadPatchWithoutObservation",
    "BadCleanMergeAsFreshness",
    "BadPatchWithStaleModel",
    "BadMissingWatchMap",
    "BadNewLinuxNames",
    "BadBehaviorChange",
    "BadAbi",
    "BadProtectionClaim",
    "BadMissingNonClaims"
}

StateFields == {
    "phase",
    "watchMapLoaded",
    "sourceObserved",
    "groupsClassified",
    "nearbyNonStaleDrift",
    "staleModel",
    "mergeTreeChecked",
    "mergeTreeClean",
    "cleanMergeUsedAsSemanticFreshness",
    "freshnessComputed",
    "modelFresh",
    "concreteConsumerNeed",
    "linuxPatchApproved",
    "newLinuxNames",
    "behaviorChange",
    "abi",
    "protectionClaim",
    "nonClaimsRecorded",
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
        watchMapLoaded |-> FALSE,
        sourceObserved |-> FALSE,
        groupsClassified |-> FALSE,
        nearbyNonStaleDrift |-> FALSE,
        staleModel |-> FALSE,
        mergeTreeChecked |-> FALSE,
        mergeTreeClean |-> FALSE,
        cleanMergeUsedAsSemanticFreshness |-> FALSE,
        freshnessComputed |-> FALSE,
        modelFresh |-> FALSE,
        concreteConsumerNeed |-> FALSE,
        linuxPatchApproved |-> FALSE,
        newLinuxNames |-> FALSE,
        behaviorChange |-> FALSE,
        abi |-> FALSE,
        protectionClaim |-> FALSE,
        nonClaimsRecorded |-> FALSE,
        accepted |-> FALSE
    ]

LoadWatchMap ==
    /\ state.phase = "Start"
    /\ state' = [state EXCEPT
        !.phase = "WatchMapLoaded",
        !.watchMapLoaded = TRUE]

ObserveSource ==
    /\ state.phase = "WatchMapLoaded"
    /\ state.watchMapLoaded
    /\ state' = [state EXCEPT
        !.phase = "SourceObserved",
        !.sourceObserved = TRUE]

ClassifyGroups ==
    /\ state.phase = "SourceObserved"
    /\ state.sourceObserved
    /\ state' = [state EXCEPT
        !.phase = "GroupsClassified",
        !.groupsClassified = TRUE,
        !.nearbyNonStaleDrift = TRUE,
        !.staleModel = FALSE]

CheckMergeTree ==
    /\ state.phase = "GroupsClassified"
    /\ state.groupsClassified
    /\ state' = [state EXCEPT
        !.phase = "MergeTreeChecked",
        !.mergeTreeChecked = TRUE,
        !.mergeTreeClean = TRUE]

ComputeFreshness ==
    /\ state.phase = "MergeTreeChecked"
    /\ state.mergeTreeChecked
    /\ state.groupsClassified
    /\ ~state.staleModel
    /\ state' = [state EXCEPT
        !.phase = "FreshnessComputed",
        !.freshnessComputed = TRUE,
        !.modelFresh = TRUE,
        !.nonClaimsRecorded = TRUE]

DeferPatch ==
    /\ state.phase = "FreshnessComputed"
    /\ state.freshnessComputed
    /\ state.modelFresh
    /\ ~state.concreteConsumerNeed
    /\ state' = [state EXCEPT
        !.phase = "PatchDeferred",
        !.linuxPatchApproved = FALSE,
        !.newLinuxNames = FALSE]

AcceptGate ==
    /\ state.phase = "PatchDeferred"
    /\ state.nonClaimsRecorded
    /\ state' = [state EXCEPT
        !.phase = "Accepted",
        !.accepted = TRUE]

BadPatchWithoutObservation ==
    /\ ALLOW_UNSAFE_PATCH_WITHOUT_OBSERVATION
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadPatchWithoutObservation",
        !.watchMapLoaded = TRUE,
        !.linuxPatchApproved = TRUE]

BadCleanMergeAsFreshness ==
    /\ ALLOW_UNSAFE_CLEAN_MERGE_AS_FRESHNESS
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadCleanMergeAsFreshness",
        !.watchMapLoaded = TRUE,
        !.sourceObserved = TRUE,
        !.mergeTreeChecked = TRUE,
        !.mergeTreeClean = TRUE,
        !.groupsClassified = FALSE,
        !.cleanMergeUsedAsSemanticFreshness = TRUE,
        !.modelFresh = TRUE]

BadPatchWithStaleModel ==
    /\ ALLOW_UNSAFE_PATCH_WITH_STALE_MODEL
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadPatchWithStaleModel",
        !.watchMapLoaded = TRUE,
        !.sourceObserved = TRUE,
        !.groupsClassified = TRUE,
        !.staleModel = TRUE,
        !.freshnessComputed = TRUE,
        !.modelFresh = FALSE,
        !.linuxPatchApproved = TRUE]

BadMissingWatchMap ==
    /\ ALLOW_UNSAFE_MISSING_WATCH_MAP
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadMissingWatchMap",
        !.sourceObserved = TRUE,
        !.groupsClassified = TRUE,
        !.freshnessComputed = TRUE,
        !.modelFresh = TRUE]

BadNewLinuxNames ==
    /\ ALLOW_UNSAFE_NEW_LINUX_NAMES
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadNewLinuxNames",
        !.watchMapLoaded = TRUE,
        !.sourceObserved = TRUE,
        !.groupsClassified = TRUE,
        !.mergeTreeChecked = TRUE,
        !.mergeTreeClean = TRUE,
        !.modelFresh = TRUE,
        !.concreteConsumerNeed = FALSE,
        !.newLinuxNames = TRUE]

BadBehaviorChange ==
    /\ ALLOW_UNSAFE_BEHAVIOR_CHANGE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadBehaviorChange",
        !.behaviorChange = TRUE]

BadAbi ==
    /\ ALLOW_UNSAFE_ABI
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadAbi",
        !.abi = TRUE]

BadProtectionClaim ==
    /\ ALLOW_UNSAFE_PROTECTION_CLAIM
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadProtectionClaim",
        !.protectionClaim = TRUE]

BadMissingNonClaims ==
    /\ ALLOW_UNSAFE_MISSING_NON_CLAIMS
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadMissingNonClaims",
        !.watchMapLoaded = TRUE,
        !.sourceObserved = TRUE,
        !.groupsClassified = TRUE,
        !.mergeTreeChecked = TRUE,
        !.mergeTreeClean = TRUE,
        !.freshnessComputed = TRUE,
        !.modelFresh = TRUE,
        !.nonClaimsRecorded = FALSE]

Next ==
    \/ LoadWatchMap
    \/ ObserveSource
    \/ ClassifyGroups
    \/ CheckMergeTree
    \/ ComputeFreshness
    \/ DeferPatch
    \/ AcceptGate
    \/ BadPatchWithoutObservation
    \/ BadCleanMergeAsFreshness
    \/ BadPatchWithStaleModel
    \/ BadMissingWatchMap
    \/ BadNewLinuxNames
    \/ BadBehaviorChange
    \/ BadAbi
    \/ BadProtectionClaim
    \/ BadMissingNonClaims

Spec == Init /\ [][Next]_vars

PatchRequiresObservation ==
    state.linuxPatchApproved => /\ state.watchMapLoaded /\ state.sourceObserved /\ state.groupsClassified

FreshnessRequiresGroupClassification ==
    state.modelFresh => state.groupsClassified

GroupClassificationRequiresWatchMap ==
    state.groupsClassified => state.watchMapLoaded

CleanMergeIsNotFreshnessProof ==
    ~state.cleanMergeUsedAsSemanticFreshness

NoPatchWithStaleModel ==
    ~(state.linuxPatchApproved /\ state.staleModel)

NoNewLinuxNamesWithoutConsumer ==
    ~(state.newLinuxNames /\ ~state.concreteConsumerNeed)

NoBehaviorChange == ~state.behaviorChange
NoAbi == ~state.abi
NoProtectionClaim == ~state.protectionClaim

AcceptedRequiresNonClaims ==
    state.accepted => state.nonClaimsRecorded

FreshnessDecisionRequiresNonClaims ==
    state.freshnessComputed => state.nonClaimsRecorded

AcceptedRequiresNoPatchApproval ==
    state.accepted => /\ ~state.linuxPatchApproved /\ ~state.newLinuxNames

================================================================================
