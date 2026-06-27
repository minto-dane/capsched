---------------------- MODULE PlacementRefreshAuthority ----------------------
EXTENDS Naturals

VARIABLES
    phase,
    capEnvelopeLive,
    cpuInFrozen,
    cpuInCurrentMask,
    cpuActive,
    placementFresh,
    frozenLive,
    queued,
    selected,
    running,
    migrationPending,
    noIntersection,
    cpuFallbackExpanded,
    failClosed

vars == <<phase, capEnvelopeLive, cpuInFrozen, cpuInCurrentMask, cpuActive,
          placementFresh, frozenLive, queued, selected, running,
          migrationPending, noIntersection, cpuFallbackExpanded, failClosed>>

Phases == {
    "Start",
    "Prepared",
    "FrozenQueued",
    "Selected",
    "Running",
    "Invalidated",
    "Refrozen",
    "FailClosed",
    "BadRunStalePlacement",
    "BadSelectedOutsideFrozen",
    "BadQueuedMoveOutsideFrozen",
    "BadFallbackExpansion",
    "BadRunInactiveCpu",
    "BadMigrationPendingRun"
}

TypeOK ==
    /\ phase \in Phases
    /\ capEnvelopeLive \in BOOLEAN
    /\ cpuInFrozen \in BOOLEAN
    /\ cpuInCurrentMask \in BOOLEAN
    /\ cpuActive \in BOOLEAN
    /\ placementFresh \in BOOLEAN
    /\ frozenLive \in BOOLEAN
    /\ queued \in BOOLEAN
    /\ selected \in BOOLEAN
    /\ running \in BOOLEAN
    /\ migrationPending \in BOOLEAN
    /\ noIntersection \in BOOLEAN
    /\ cpuFallbackExpanded \in BOOLEAN
    /\ failClosed \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ capEnvelopeLive = TRUE
    /\ cpuInFrozen = FALSE
    /\ cpuInCurrentMask = FALSE
    /\ cpuActive = TRUE
    /\ placementFresh = FALSE
    /\ frozenLive = FALSE
    /\ queued = FALSE
    /\ selected = FALSE
    /\ running = FALSE
    /\ migrationPending = FALSE
    /\ noIntersection = FALSE
    /\ cpuFallbackExpanded = FALSE
    /\ failClosed = FALSE

PreparePlacement ==
    /\ phase = "Start"
    /\ capEnvelopeLive
    /\ cpuActive
    /\ cpuInCurrentMask' = TRUE
    /\ placementFresh' = TRUE
    /\ phase' = "Prepared"
    /\ UNCHANGED <<capEnvelopeLive, cpuInFrozen, cpuActive, frozenLive, queued,
                    selected, running, migrationPending, noIntersection,
                    cpuFallbackExpanded, failClosed>>

FreezeRunUse ==
    /\ phase = "Prepared"
    /\ capEnvelopeLive
    /\ cpuInCurrentMask
    /\ cpuActive
    /\ placementFresh
    /\ cpuInFrozen' = TRUE
    /\ frozenLive' = TRUE
    /\ queued' = TRUE
    /\ phase' = "FrozenQueued"
    /\ UNCHANGED <<capEnvelopeLive, cpuInCurrentMask, cpuActive,
                    placementFresh, selected, running, migrationPending,
                    noIntersection, cpuFallbackExpanded, failClosed>>

SelectForRun ==
    /\ phase \in {"FrozenQueued", "Refrozen"}
    /\ frozenLive
    /\ queued
    /\ cpuInFrozen
    /\ cpuInCurrentMask
    /\ cpuActive
    /\ placementFresh
    /\ queued' = FALSE
    /\ selected' = TRUE
    /\ phase' = "Selected"
    /\ UNCHANGED <<capEnvelopeLive, cpuInFrozen, cpuInCurrentMask, cpuActive,
                    placementFresh, frozenLive, running, migrationPending,
                    noIntersection, cpuFallbackExpanded, failClosed>>

RunSelected ==
    /\ phase = "Selected"
    /\ selected
    /\ frozenLive
    /\ cpuInFrozen
    /\ cpuInCurrentMask
    /\ cpuActive
    /\ placementFresh
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<capEnvelopeLive, cpuInFrozen, cpuInCurrentMask, cpuActive,
                    placementFresh, frozenLive, queued, selected,
                    migrationPending, noIntersection, cpuFallbackExpanded,
                    failClosed>>

AffinityShrinkInvalidates ==
    /\ phase \in {"FrozenQueued", "Selected"}
    /\ frozenLive
    /\ cpuInCurrentMask' = FALSE
    /\ placementFresh' = FALSE
    /\ frozenLive' = FALSE
    /\ queued' = FALSE
    /\ selected' = FALSE
    /\ migrationPending' = TRUE
    /\ phase' = "Invalidated"
    /\ UNCHANGED <<capEnvelopeLive, cpuInFrozen, cpuActive, running,
                    noIntersection, cpuFallbackExpanded, failClosed>>

CpuHotplugDeactivate ==
    /\ phase \in {"FrozenQueued", "Selected"}
    /\ cpuActive
    /\ cpuActive' = FALSE
    /\ placementFresh' = FALSE
    /\ frozenLive' = FALSE
    /\ queued' = FALSE
    /\ selected' = FALSE
    /\ migrationPending' = TRUE
    /\ phase' = "Invalidated"
    /\ UNCHANGED <<capEnvelopeLive, cpuInFrozen, cpuInCurrentMask, running,
                    noIntersection, cpuFallbackExpanded, failClosed>>

RefreshPlacement ==
    /\ phase = "Invalidated"
    /\ migrationPending
    /\ capEnvelopeLive
    /\ cpuActive
    /\ ~noIntersection
    /\ cpuInCurrentMask' = TRUE
    /\ cpuInFrozen' = TRUE
    /\ placementFresh' = TRUE
    /\ frozenLive' = TRUE
    /\ queued' = TRUE
    /\ selected' = FALSE
    /\ running' = FALSE
    /\ migrationPending' = FALSE
    /\ phase' = "Refrozen"
    /\ UNCHANGED <<capEnvelopeLive, cpuActive, noIntersection,
                    cpuFallbackExpanded, failClosed>>

NoIntersectionFailClosed ==
    /\ phase = "Invalidated"
    /\ migrationPending
    /\ noIntersection' = TRUE
    /\ failClosed' = TRUE
    /\ running' = FALSE
    /\ migrationPending' = FALSE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<capEnvelopeLive, cpuInFrozen, cpuInCurrentMask, cpuActive,
                    placementFresh, frozenLive, queued, selected,
                    cpuFallbackExpanded>>

UnsafeRunAfterAffinityShrink ==
    /\ phase = "FrozenQueued"
    /\ frozenLive
    /\ cpuInCurrentMask' = FALSE
    /\ placementFresh' = FALSE
    /\ queued' = FALSE
    /\ selected' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunStalePlacement"
    /\ UNCHANGED <<capEnvelopeLive, cpuInFrozen, cpuActive, frozenLive,
                    migrationPending, noIntersection, cpuFallbackExpanded,
                    failClosed>>

UnsafeSelectedOutsideFrozen ==
    /\ phase = "Prepared"
    /\ cpuInFrozen' = FALSE
    /\ frozenLive' = FALSE
    /\ selected' = TRUE
    /\ phase' = "BadSelectedOutsideFrozen"
    /\ UNCHANGED <<capEnvelopeLive, cpuInCurrentMask, cpuActive,
                    placementFresh, queued, running, migrationPending,
                    noIntersection, cpuFallbackExpanded, failClosed>>

UnsafeQueuedMoveOutsideFrozen ==
    /\ phase = "FrozenQueued"
    /\ frozenLive
    /\ cpuInFrozen' = FALSE
    /\ queued' = TRUE
    /\ phase' = "BadQueuedMoveOutsideFrozen"
    /\ UNCHANGED <<capEnvelopeLive, cpuInCurrentMask, cpuActive,
                    placementFresh, frozenLive, selected, running,
                    migrationPending, noIntersection, cpuFallbackExpanded,
                    failClosed>>

UnsafeFallbackExpansion ==
    /\ phase = "Invalidated"
    /\ migrationPending
    /\ noIntersection' = TRUE
    /\ cpuFallbackExpanded' = TRUE
    /\ failClosed' = FALSE
    /\ cpuInCurrentMask' = TRUE
    /\ cpuInFrozen' = TRUE
    /\ frozenLive' = TRUE
    /\ running' = TRUE
    /\ migrationPending' = FALSE
    /\ phase' = "BadFallbackExpansion"
    /\ UNCHANGED <<capEnvelopeLive, cpuActive, placementFresh, queued,
                    selected>>

UnsafeRunInactiveCpu ==
    /\ phase = "Selected"
    /\ selected
    /\ cpuActive' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadRunInactiveCpu"
    /\ UNCHANGED <<capEnvelopeLive, cpuInFrozen, cpuInCurrentMask,
                    placementFresh, frozenLive, queued, selected,
                    migrationPending, noIntersection, cpuFallbackExpanded,
                    failClosed>>

UnsafeMigrationPendingRun ==
    /\ phase = "Invalidated"
    /\ migrationPending
    /\ running' = TRUE
    /\ phase' = "BadMigrationPendingRun"
    /\ UNCHANGED <<capEnvelopeLive, cpuInFrozen, cpuInCurrentMask, cpuActive,
                    placementFresh, frozenLive, queued, selected,
                    migrationPending, noIntersection, cpuFallbackExpanded,
                    failClosed>>

SafeNext ==
    \/ PreparePlacement
    \/ FreezeRunUse
    \/ SelectForRun
    \/ RunSelected
    \/ AffinityShrinkInvalidates
    \/ CpuHotplugDeactivate
    \/ RefreshPlacement
    \/ NoIntersectionFailClosed

SafeSpec == Init /\ [][SafeNext]_vars

UnsafeRunStaleSpec ==
    Init /\ [][SafeNext \/ UnsafeRunAfterAffinityShrink]_vars

UnsafeSelectedSpec ==
    Init /\ [][SafeNext \/ UnsafeSelectedOutsideFrozen]_vars

UnsafeQueuedMoveSpec ==
    Init /\ [][SafeNext \/ UnsafeQueuedMoveOutsideFrozen]_vars

UnsafeFallbackSpec ==
    Init /\ [][SafeNext \/ UnsafeFallbackExpansion]_vars

UnsafeInactiveSpec ==
    Init /\ [][SafeNext \/ UnsafeRunInactiveCpu]_vars

UnsafeMigrationPendingSpec ==
    Init /\ [][SafeNext \/ UnsafeMigrationPendingRun]_vars

NoRunOutsideCurrentPlacement ==
    running => frozenLive /\ cpuInFrozen /\ cpuInCurrentMask /\
               placementFresh /\ capEnvelopeLive

NoSelectedOutsideFrozenEnvelope ==
    selected => frozenLive /\ cpuInFrozen /\ cpuInCurrentMask /\ placementFresh

NoQueuedMoveOutsideFrozenEnvelope ==
    queued => frozenLive /\ cpuInFrozen /\ cpuInCurrentMask /\ placementFresh

NoFallbackExpansionCreatesAuthority ==
    cpuFallbackExpanded => failClosed /\ ~running

NoRunOnInactiveCpu ==
    running => cpuActive

NoMigrationPendingRuns ==
    migrationPending => ~running

=============================================================================
