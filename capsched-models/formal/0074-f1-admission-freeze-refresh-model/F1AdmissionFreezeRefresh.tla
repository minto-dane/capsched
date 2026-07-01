--------------------- MODULE F1AdmissionFreezeRefresh ---------------------
EXTENDS Naturals

VARIABLES
    phase,
    taskGenerationFrozen,
    domainEpochFrozen,
    schedCtxFrozen,
    placementFrozen,
    rootBudgetFrozen,
    rawCapHandle,
    taskWakingPublished,
    wakeListPublished,
    enqueueVisible,
    selectedCheapValidated,
    running,
    heavyLookupAfterPublish,
    lateDeny,
    lostWake,
    placementMintedAuthority,
    currentSelfWakeMinted,
    forkSpawnAmbient,
    failClosed,
    protectionClaim

vars == <<phase, taskGenerationFrozen, domainEpochFrozen, schedCtxFrozen,
          placementFrozen, rootBudgetFrozen, rawCapHandle,
          taskWakingPublished, wakeListPublished, enqueueVisible,
          selectedCheapValidated, running, heavyLookupAfterPublish, lateDeny,
          lostWake, placementMintedAuthority, currentSelfWakeMinted,
          forkSpawnAmbient, failClosed, protectionClaim>>

Phases == {
    "Start",
    "Frozen",
    "TaskWaking",
    "WakeListPublished",
    "Enqueued",
    "Selected",
    "Running",
    "FailClosed",
    "BadTaskWakingBeforeFreeze",
    "BadWakeListBeforeFreeze",
    "BadEnqueueBeforeFreeze",
    "BadRunMissingGeneration",
    "BadRunMissingDomainEpoch",
    "BadRunMissingSchedCtx",
    "BadRunMissingPlacement",
    "BadRunMissingBudget",
    "BadRawCapAfterPublication",
    "BadHeavyLookupAfterPublication",
    "BadLateDenyLostWake",
    "BadPlacementAuthority",
    "BadCurrentContinuationMint",
    "BadForkAmbientAuthority",
    "BadProtectionClaim"
}

TypeOK ==
    /\ phase \in Phases
    /\ taskGenerationFrozen \in BOOLEAN
    /\ domainEpochFrozen \in BOOLEAN
    /\ schedCtxFrozen \in BOOLEAN
    /\ placementFrozen \in BOOLEAN
    /\ rootBudgetFrozen \in BOOLEAN
    /\ rawCapHandle \in BOOLEAN
    /\ taskWakingPublished \in BOOLEAN
    /\ wakeListPublished \in BOOLEAN
    /\ enqueueVisible \in BOOLEAN
    /\ selectedCheapValidated \in BOOLEAN
    /\ running \in BOOLEAN
    /\ heavyLookupAfterPublish \in BOOLEAN
    /\ lateDeny \in BOOLEAN
    /\ lostWake \in BOOLEAN
    /\ placementMintedAuthority \in BOOLEAN
    /\ currentSelfWakeMinted \in BOOLEAN
    /\ forkSpawnAmbient \in BOOLEAN
    /\ failClosed \in BOOLEAN
    /\ protectionClaim \in BOOLEAN

CompleteFrozenUse ==
    /\ taskGenerationFrozen
    /\ domainEpochFrozen
    /\ schedCtxFrozen
    /\ placementFrozen
    /\ rootBudgetFrozen
    /\ ~rawCapHandle

Published ==
    \/ taskWakingPublished
    \/ wakeListPublished
    \/ enqueueVisible

Init ==
    /\ phase = "Start"
    /\ taskGenerationFrozen = FALSE
    /\ domainEpochFrozen = FALSE
    /\ schedCtxFrozen = FALSE
    /\ placementFrozen = FALSE
    /\ rootBudgetFrozen = FALSE
    /\ rawCapHandle = FALSE
    /\ taskWakingPublished = FALSE
    /\ wakeListPublished = FALSE
    /\ enqueueVisible = FALSE
    /\ selectedCheapValidated = FALSE
    /\ running = FALSE
    /\ heavyLookupAfterPublish = FALSE
    /\ lateDeny = FALSE
    /\ lostWake = FALSE
    /\ placementMintedAuthority = FALSE
    /\ currentSelfWakeMinted = FALSE
    /\ forkSpawnAmbient = FALSE
    /\ failClosed = FALSE
    /\ protectionClaim = FALSE

PrimeFrozenTuple ==
    /\ taskGenerationFrozen' = TRUE
    /\ domainEpochFrozen' = TRUE
    /\ schedCtxFrozen' = TRUE
    /\ placementFrozen' = TRUE
    /\ rootBudgetFrozen' = TRUE
    /\ rawCapHandle' = FALSE

FreezeBeforePublication ==
    /\ phase = "Start"
    /\ PrimeFrozenTuple
    /\ phase' = "Frozen"
    /\ UNCHANGED <<taskWakingPublished, wakeListPublished, enqueueVisible,
                    selectedCheapValidated, running, heavyLookupAfterPublish,
                    lateDeny, lostWake, placementMintedAuthority,
                    currentSelfWakeMinted, forkSpawnAmbient, failClosed,
                    protectionClaim>>

RejectBeforePublication ==
    /\ phase = "Start"
    /\ failClosed' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<taskGenerationFrozen, domainEpochFrozen, schedCtxFrozen,
                    placementFrozen, rootBudgetFrozen, rawCapHandle,
                    taskWakingPublished, wakeListPublished, enqueueVisible,
                    selectedCheapValidated, running, heavyLookupAfterPublish,
                    lateDeny, lostWake, placementMintedAuthority,
                    currentSelfWakeMinted, forkSpawnAmbient, protectionClaim>>

SpawnFreezeBeforeInitialEnqueue ==
    /\ phase = "Start"
    /\ PrimeFrozenTuple
    /\ enqueueVisible' = TRUE
    /\ phase' = "Enqueued"
    /\ UNCHANGED <<taskWakingPublished, wakeListPublished,
                    selectedCheapValidated, running, heavyLookupAfterPublish,
                    lateDeny, lostWake, placementMintedAuthority,
                    currentSelfWakeMinted, forkSpawnAmbient, failClosed,
                    protectionClaim>>

CurrentContinuationWithExistingUse ==
    /\ phase = "Start"
    /\ PrimeFrozenTuple
    /\ selectedCheapValidated' = TRUE
    /\ phase' = "Selected"
    /\ UNCHANGED <<taskWakingPublished, wakeListPublished, enqueueVisible,
                    running, heavyLookupAfterPublish, lateDeny, lostWake,
                    placementMintedAuthority, currentSelfWakeMinted,
                    forkSpawnAmbient, failClosed, protectionClaim>>

PublishTaskWaking ==
    /\ phase = "Frozen"
    /\ CompleteFrozenUse
    /\ taskWakingPublished' = TRUE
    /\ phase' = "TaskWaking"
    /\ UNCHANGED <<taskGenerationFrozen, domainEpochFrozen, schedCtxFrozen,
                    placementFrozen, rootBudgetFrozen, rawCapHandle,
                    wakeListPublished, enqueueVisible, selectedCheapValidated,
                    running, heavyLookupAfterPublish, lateDeny, lostWake,
                    placementMintedAuthority, currentSelfWakeMinted,
                    forkSpawnAmbient, failClosed, protectionClaim>>

PublishRemoteWakeList ==
    /\ phase = "TaskWaking"
    /\ CompleteFrozenUse
    /\ wakeListPublished' = TRUE
    /\ phase' = "WakeListPublished"
    /\ UNCHANGED <<taskGenerationFrozen, domainEpochFrozen, schedCtxFrozen,
                    placementFrozen, rootBudgetFrozen, rawCapHandle,
                    taskWakingPublished, enqueueVisible, selectedCheapValidated,
                    running, heavyLookupAfterPublish, lateDeny, lostWake,
                    placementMintedAuthority, currentSelfWakeMinted,
                    forkSpawnAmbient, failClosed, protectionClaim>>

EnqueueAfterPublication ==
    /\ phase \in {"TaskWaking", "WakeListPublished"}
    /\ CompleteFrozenUse
    /\ enqueueVisible' = TRUE
    /\ phase' = "Enqueued"
    /\ UNCHANGED <<taskGenerationFrozen, domainEpochFrozen, schedCtxFrozen,
                    placementFrozen, rootBudgetFrozen, rawCapHandle,
                    taskWakingPublished, wakeListPublished,
                    selectedCheapValidated, running, heavyLookupAfterPublish,
                    lateDeny, lostWake, placementMintedAuthority,
                    currentSelfWakeMinted, forkSpawnAmbient, failClosed,
                    protectionClaim>>

CheapSelectValidate ==
    /\ phase = "Enqueued"
    /\ CompleteFrozenUse
    /\ selectedCheapValidated' = TRUE
    /\ phase' = "Selected"
    /\ UNCHANGED <<taskGenerationFrozen, domainEpochFrozen, schedCtxFrozen,
                    placementFrozen, rootBudgetFrozen, rawCapHandle,
                    taskWakingPublished, wakeListPublished, enqueueVisible,
                    running, heavyLookupAfterPublish, lateDeny, lostWake,
                    placementMintedAuthority, currentSelfWakeMinted,
                    forkSpawnAmbient, failClosed, protectionClaim>>

RunAfterCheapValidation ==
    /\ phase = "Selected"
    /\ CompleteFrozenUse
    /\ selectedCheapValidated
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<taskGenerationFrozen, domainEpochFrozen, schedCtxFrozen,
                    placementFrozen, rootBudgetFrozen, rawCapHandle,
                    taskWakingPublished, wakeListPublished, enqueueVisible,
                    selectedCheapValidated, heavyLookupAfterPublish, lateDeny,
                    lostWake, placementMintedAuthority, currentSelfWakeMinted,
                    forkSpawnAmbient, failClosed, protectionClaim>>

TerminalStutter ==
    /\ phase \in {"Running", "FailClosed"}
    /\ UNCHANGED vars

StaleAfterPublicationFailClosed ==
    /\ phase \in {"TaskWaking", "WakeListPublished", "Enqueued", "Selected"}
    /\ Published
    /\ running = FALSE
    /\ failClosed' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<taskGenerationFrozen, domainEpochFrozen, schedCtxFrozen,
                    placementFrozen, rootBudgetFrozen, rawCapHandle,
                    taskWakingPublished, wakeListPublished, enqueueVisible,
                    selectedCheapValidated, running, heavyLookupAfterPublish,
                    lateDeny, lostWake, placementMintedAuthority,
                    currentSelfWakeMinted, forkSpawnAmbient, protectionClaim>>

SafeNext ==
    \/ FreezeBeforePublication
    \/ RejectBeforePublication
    \/ SpawnFreezeBeforeInitialEnqueue
    \/ CurrentContinuationWithExistingUse
    \/ PublishTaskWaking
    \/ PublishRemoteWakeList
    \/ EnqueueAfterPublication
    \/ CheapSelectValidate
    \/ RunAfterCheapValidation
    \/ StaleAfterPublicationFailClosed
    \/ TerminalStutter

UnsafeTaskWakingBeforeFreeze ==
    /\ phase = "Start"
    /\ taskWakingPublished' = TRUE
    /\ phase' = "BadTaskWakingBeforeFreeze"
    /\ UNCHANGED <<taskGenerationFrozen, domainEpochFrozen, schedCtxFrozen,
                    placementFrozen, rootBudgetFrozen, rawCapHandle,
                    wakeListPublished, enqueueVisible, selectedCheapValidated,
                    running, heavyLookupAfterPublish, lateDeny, lostWake,
                    placementMintedAuthority, currentSelfWakeMinted,
                    forkSpawnAmbient, failClosed, protectionClaim>>

UnsafeWakeListBeforeFreeze ==
    /\ phase = "Start"
    /\ wakeListPublished' = TRUE
    /\ phase' = "BadWakeListBeforeFreeze"
    /\ UNCHANGED <<taskGenerationFrozen, domainEpochFrozen, schedCtxFrozen,
                    placementFrozen, rootBudgetFrozen, rawCapHandle,
                    taskWakingPublished, enqueueVisible, selectedCheapValidated,
                    running, heavyLookupAfterPublish, lateDeny, lostWake,
                    placementMintedAuthority, currentSelfWakeMinted,
                    forkSpawnAmbient, failClosed, protectionClaim>>

UnsafeEnqueueBeforeFreeze ==
    /\ phase = "Start"
    /\ enqueueVisible' = TRUE
    /\ phase' = "BadEnqueueBeforeFreeze"
    /\ UNCHANGED <<taskGenerationFrozen, domainEpochFrozen, schedCtxFrozen,
                    placementFrozen, rootBudgetFrozen, rawCapHandle,
                    taskWakingPublished, wakeListPublished,
                    selectedCheapValidated, running, heavyLookupAfterPublish,
                    lateDeny, lostWake, placementMintedAuthority,
                    currentSelfWakeMinted, forkSpawnAmbient, failClosed,
                    protectionClaim>>

UnsafeRunMissingGeneration ==
    /\ phase = "Start"
    /\ taskGenerationFrozen' = FALSE
    /\ domainEpochFrozen' = TRUE
    /\ schedCtxFrozen' = TRUE
    /\ placementFrozen' = TRUE
    /\ rootBudgetFrozen' = TRUE
    /\ rawCapHandle' = FALSE
    /\ enqueueVisible' = TRUE
    /\ selectedCheapValidated' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunMissingGeneration"
    /\ UNCHANGED <<taskWakingPublished, wakeListPublished,
                    heavyLookupAfterPublish, lateDeny, lostWake,
                    placementMintedAuthority, currentSelfWakeMinted,
                    forkSpawnAmbient, failClosed, protectionClaim>>

UnsafeRunMissingDomainEpoch ==
    /\ phase = "Start"
    /\ taskGenerationFrozen' = TRUE
    /\ domainEpochFrozen' = FALSE
    /\ schedCtxFrozen' = TRUE
    /\ placementFrozen' = TRUE
    /\ rootBudgetFrozen' = TRUE
    /\ rawCapHandle' = FALSE
    /\ enqueueVisible' = TRUE
    /\ selectedCheapValidated' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunMissingDomainEpoch"
    /\ UNCHANGED <<taskWakingPublished, wakeListPublished,
                    heavyLookupAfterPublish, lateDeny, lostWake,
                    placementMintedAuthority, currentSelfWakeMinted,
                    forkSpawnAmbient, failClosed, protectionClaim>>

UnsafeRunMissingSchedCtx ==
    /\ phase = "Start"
    /\ taskGenerationFrozen' = TRUE
    /\ domainEpochFrozen' = TRUE
    /\ schedCtxFrozen' = FALSE
    /\ placementFrozen' = TRUE
    /\ rootBudgetFrozen' = TRUE
    /\ rawCapHandle' = FALSE
    /\ enqueueVisible' = TRUE
    /\ selectedCheapValidated' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunMissingSchedCtx"
    /\ UNCHANGED <<taskWakingPublished, wakeListPublished,
                    heavyLookupAfterPublish, lateDeny, lostWake,
                    placementMintedAuthority, currentSelfWakeMinted,
                    forkSpawnAmbient, failClosed, protectionClaim>>

UnsafeRunMissingPlacement ==
    /\ phase = "Start"
    /\ taskGenerationFrozen' = TRUE
    /\ domainEpochFrozen' = TRUE
    /\ schedCtxFrozen' = TRUE
    /\ placementFrozen' = FALSE
    /\ rootBudgetFrozen' = TRUE
    /\ rawCapHandle' = FALSE
    /\ enqueueVisible' = TRUE
    /\ selectedCheapValidated' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunMissingPlacement"
    /\ UNCHANGED <<taskWakingPublished, wakeListPublished,
                    heavyLookupAfterPublish, lateDeny, lostWake,
                    placementMintedAuthority, currentSelfWakeMinted,
                    forkSpawnAmbient, failClosed, protectionClaim>>

UnsafeRunMissingBudget ==
    /\ phase = "Start"
    /\ taskGenerationFrozen' = TRUE
    /\ domainEpochFrozen' = TRUE
    /\ schedCtxFrozen' = TRUE
    /\ placementFrozen' = TRUE
    /\ rootBudgetFrozen' = FALSE
    /\ rawCapHandle' = FALSE
    /\ enqueueVisible' = TRUE
    /\ selectedCheapValidated' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunMissingBudget"
    /\ UNCHANGED <<taskWakingPublished, wakeListPublished,
                    heavyLookupAfterPublish, lateDeny, lostWake,
                    placementMintedAuthority, currentSelfWakeMinted,
                    forkSpawnAmbient, failClosed, protectionClaim>>

UnsafeRawCapAfterPublication ==
    /\ phase = "Start"
    /\ taskGenerationFrozen' = TRUE
    /\ domainEpochFrozen' = TRUE
    /\ schedCtxFrozen' = TRUE
    /\ placementFrozen' = TRUE
    /\ rootBudgetFrozen' = TRUE
    /\ rawCapHandle' = TRUE
    /\ taskWakingPublished' = TRUE
    /\ phase' = "BadRawCapAfterPublication"
    /\ UNCHANGED <<wakeListPublished, enqueueVisible, selectedCheapValidated,
                    running, heavyLookupAfterPublish, lateDeny, lostWake,
                    placementMintedAuthority, currentSelfWakeMinted,
                    forkSpawnAmbient, failClosed, protectionClaim>>

UnsafeHeavyLookupAfterPublication ==
    /\ phase = "Start"
    /\ PrimeFrozenTuple
    /\ taskWakingPublished' = TRUE
    /\ heavyLookupAfterPublish' = TRUE
    /\ phase' = "BadHeavyLookupAfterPublication"
    /\ UNCHANGED <<wakeListPublished, enqueueVisible, selectedCheapValidated,
                    running, lateDeny, lostWake, placementMintedAuthority,
                    currentSelfWakeMinted, forkSpawnAmbient, failClosed,
                    protectionClaim>>

UnsafeLateDenyLostWake ==
    /\ phase = "Start"
    /\ PrimeFrozenTuple
    /\ taskWakingPublished' = TRUE
    /\ enqueueVisible' = TRUE
    /\ lateDeny' = TRUE
    /\ lostWake' = TRUE
    /\ phase' = "BadLateDenyLostWake"
    /\ UNCHANGED <<wakeListPublished, selectedCheapValidated, running,
                    heavyLookupAfterPublish, placementMintedAuthority,
                    currentSelfWakeMinted, forkSpawnAmbient, failClosed,
                    protectionClaim>>

UnsafePlacementAuthority ==
    /\ phase = "Start"
    /\ placementMintedAuthority' = TRUE
    /\ phase' = "BadPlacementAuthority"
    /\ UNCHANGED <<taskGenerationFrozen, domainEpochFrozen, schedCtxFrozen,
                    placementFrozen, rootBudgetFrozen, rawCapHandle,
                    taskWakingPublished, wakeListPublished, enqueueVisible,
                    selectedCheapValidated, running, heavyLookupAfterPublish,
                    lateDeny, lostWake, currentSelfWakeMinted,
                    forkSpawnAmbient, failClosed, protectionClaim>>

UnsafeCurrentContinuationMint ==
    /\ phase = "Start"
    /\ currentSelfWakeMinted' = TRUE
    /\ phase' = "BadCurrentContinuationMint"
    /\ UNCHANGED <<taskGenerationFrozen, domainEpochFrozen, schedCtxFrozen,
                    placementFrozen, rootBudgetFrozen, rawCapHandle,
                    taskWakingPublished, wakeListPublished, enqueueVisible,
                    selectedCheapValidated, running, heavyLookupAfterPublish,
                    lateDeny, lostWake, placementMintedAuthority,
                    forkSpawnAmbient, failClosed, protectionClaim>>

UnsafeForkAmbientAuthority ==
    /\ phase = "Start"
    /\ forkSpawnAmbient' = TRUE
    /\ enqueueVisible' = TRUE
    /\ phase' = "BadForkAmbientAuthority"
    /\ UNCHANGED <<taskGenerationFrozen, domainEpochFrozen, schedCtxFrozen,
                    placementFrozen, rootBudgetFrozen, rawCapHandle,
                    taskWakingPublished, wakeListPublished,
                    selectedCheapValidated, running, heavyLookupAfterPublish,
                    lateDeny, lostWake, placementMintedAuthority,
                    currentSelfWakeMinted, failClosed, protectionClaim>>

UnsafeProtectionClaim ==
    /\ phase = "Start"
    /\ protectionClaim' = TRUE
    /\ phase' = "BadProtectionClaim"
    /\ UNCHANGED <<taskGenerationFrozen, domainEpochFrozen, schedCtxFrozen,
                    placementFrozen, rootBudgetFrozen, rawCapHandle,
                    taskWakingPublished, wakeListPublished, enqueueVisible,
                    selectedCheapValidated, running, heavyLookupAfterPublish,
                    lateDeny, lostWake, placementMintedAuthority,
                    currentSelfWakeMinted, forkSpawnAmbient, failClosed>>

BadStutter ==
    /\ phase \in {"BadTaskWakingBeforeFreeze", "BadWakeListBeforeFreeze",
                  "BadEnqueueBeforeFreeze", "BadRunMissingGeneration",
                  "BadRunMissingDomainEpoch", "BadRunMissingSchedCtx",
                  "BadRunMissingPlacement", "BadRunMissingBudget",
                  "BadRawCapAfterPublication", "BadHeavyLookupAfterPublication",
                  "BadLateDenyLostWake", "BadPlacementAuthority",
                  "BadCurrentContinuationMint", "BadForkAmbientAuthority",
                  "BadProtectionClaim"}
    /\ UNCHANGED vars

SafeSpec == Init /\ [][SafeNext]_vars
SpecUnsafeTaskWakingBeforeFreeze == Init /\ [][UnsafeTaskWakingBeforeFreeze \/ BadStutter]_vars
SpecUnsafeWakeListBeforeFreeze == Init /\ [][UnsafeWakeListBeforeFreeze \/ BadStutter]_vars
SpecUnsafeEnqueueBeforeFreeze == Init /\ [][UnsafeEnqueueBeforeFreeze \/ BadStutter]_vars
SpecUnsafeRunMissingGeneration == Init /\ [][UnsafeRunMissingGeneration \/ BadStutter]_vars
SpecUnsafeRunMissingDomainEpoch == Init /\ [][UnsafeRunMissingDomainEpoch \/ BadStutter]_vars
SpecUnsafeRunMissingSchedCtx == Init /\ [][UnsafeRunMissingSchedCtx \/ BadStutter]_vars
SpecUnsafeRunMissingPlacement == Init /\ [][UnsafeRunMissingPlacement \/ BadStutter]_vars
SpecUnsafeRunMissingBudget == Init /\ [][UnsafeRunMissingBudget \/ BadStutter]_vars
SpecUnsafeRawCapAfterPublication == Init /\ [][UnsafeRawCapAfterPublication \/ BadStutter]_vars
SpecUnsafeHeavyLookupAfterPublication == Init /\ [][UnsafeHeavyLookupAfterPublication \/ BadStutter]_vars
SpecUnsafeLateDenyLostWake == Init /\ [][UnsafeLateDenyLostWake \/ BadStutter]_vars
SpecUnsafePlacementAuthority == Init /\ [][UnsafePlacementAuthority \/ BadStutter]_vars
SpecUnsafeCurrentContinuationMint == Init /\ [][UnsafeCurrentContinuationMint \/ BadStutter]_vars
SpecUnsafeForkAmbientAuthority == Init /\ [][UnsafeForkAmbientAuthority \/ BadStutter]_vars
SpecUnsafeProtectionClaim == Init /\ [][UnsafeProtectionClaim \/ BadStutter]_vars

NoTaskWakingWithoutFrozenUse ==
    taskWakingPublished => CompleteFrozenUse

NoWakeListWithoutFrozenUse ==
    wakeListPublished => CompleteFrozenUse

NoEnqueueWithoutFrozenUse ==
    enqueueVisible => CompleteFrozenUse

NoRunWithIncompleteFrozenUse ==
    running => CompleteFrozenUse

NoRunWithoutCheapValidation ==
    running => selectedCheapValidated

NoRawCapHandleAfterPublication ==
    Published => ~rawCapHandle

NoHeavyLookupAfterPublication ==
    Published => ~heavyLookupAfterPublish

NoLateDenyLostWake ==
    ~(lateDeny /\ lostWake)

NoPlacementAsAuthority ==
    ~placementMintedAuthority

NoCurrentContinuationMint ==
    ~currentSelfWakeMinted

NoForkAmbientAuthority ==
    ~forkSpawnAmbient

NoProtectionClaim ==
    ~protectionClaim

=============================================================================
