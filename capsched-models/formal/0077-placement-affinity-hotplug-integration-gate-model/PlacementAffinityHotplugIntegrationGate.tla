--------------- MODULE PlacementAffinityHotplugIntegrationGate ---------------
EXTENDS Naturals

VARIABLES
    phase,
    taskKind,
    domainGrant,
    schedContextGrant,
    runCapGrant,
    runAuthority,
    serviceAuthority,
    currentEpoch,
    placementEpoch,
    capEnvelope,
    linuxMask,
    activeMask,
    onlineMask,
    monitorCpuSet,
    memoryViewCpuSet,
    frozenAllowed,
    placementFrozen,
    selectedCpu,
    selectedSettled,
    runCpu,
    migrationPending,
    running,
    failClosed,
    selectedCpuAuthority,
    placementMintedAuthority,
    fallbackExpandedAuthority,
    forceAffinityAuthority,
    cpusetFallbackAuthority,
    classSelectionAuthority,
    scxSelectionAuthority,
    coreStealAuthority,
    schedExecAuthority,
    migrateDisableAuthority,
    perCpuKthreadAuthority,
    protectionClaim

vars == <<phase, taskKind, domainGrant, schedContextGrant, runCapGrant,
          runAuthority, serviceAuthority, currentEpoch, placementEpoch,
          capEnvelope, linuxMask, activeMask, onlineMask, monitorCpuSet,
          memoryViewCpuSet, frozenAllowed, placementFrozen, selectedCpu,
          selectedSettled, runCpu, migrationPending, running, failClosed,
          selectedCpuAuthority, placementMintedAuthority,
          fallbackExpandedAuthority, forceAffinityAuthority,
          cpusetFallbackAuthority, classSelectionAuthority,
          scxSelectionAuthority, coreStealAuthority, schedExecAuthority,
          migrateDisableAuthority, perCpuKthreadAuthority, protectionClaim>>

authorityFlags == <<selectedCpuAuthority, placementMintedAuthority,
                    fallbackExpandedAuthority, forceAffinityAuthority,
                    cpusetFallbackAuthority, classSelectionAuthority,
                    scxSelectionAuthority, coreStealAuthority,
                    schedExecAuthority, migrateDisableAuthority,
                    perCpuKthreadAuthority, protectionClaim>>

CPUS == {"cpu0", "cpu1"}
NoCpu == "none"
CpuOrNone == CPUS \cup {NoCpu}
Epochs == 0..2

TaskKinds == {"OrdinaryDomain", "ServiceKthread", "PerCpuKthread"}

Phases == {
    "Start",
    "AuthorityIssued",
    "Frozen",
    "Selected",
    "Running",
    "Invalidated",
    "FailClosed",
    "BadRunWithoutFrozenPlacement",
    "BadRunWithStalePlacement",
    "BadRunOutsideLinuxMask",
    "BadRunInactiveCpu",
    "BadRunWithoutMonitorCpuBinding",
    "BadRunWithoutMemoryViewBinding",
    "BadRunWhileMigrationPending",
    "BadSelectedCpuAuthority",
    "BadPlacementMintedAuthority",
    "BadFallbackExpansionAuthority",
    "BadForceAffinityAuthority",
    "BadCpusetFallbackAuthority",
    "BadClassSelectionAuthority",
    "BadScxSelectionAuthority",
    "BadCoreStealAuthority",
    "BadSchedExecAuthority",
    "BadMigrateDisableAuthority",
    "BadPerCpuKthreadAuthority",
    "BadNoIntersectionRuns",
    "BadProtectionClaim"
}

TypeOK ==
    /\ phase \in Phases
    /\ taskKind \in TaskKinds
    /\ domainGrant \in BOOLEAN
    /\ schedContextGrant \in BOOLEAN
    /\ runCapGrant \in BOOLEAN
    /\ runAuthority \in BOOLEAN
    /\ serviceAuthority \in BOOLEAN
    /\ currentEpoch \in Epochs
    /\ placementEpoch \in Epochs
    /\ capEnvelope \subseteq CPUS
    /\ linuxMask \subseteq CPUS
    /\ activeMask \subseteq onlineMask
    /\ onlineMask \subseteq CPUS
    /\ monitorCpuSet \subseteq CPUS
    /\ memoryViewCpuSet \subseteq CPUS
    /\ frozenAllowed \subseteq CPUS
    /\ placementFrozen \in BOOLEAN
    /\ selectedCpu \in CpuOrNone
    /\ selectedSettled \in BOOLEAN
    /\ runCpu \in CpuOrNone
    /\ migrationPending \in BOOLEAN
    /\ running \in BOOLEAN
    /\ failClosed \in BOOLEAN
    /\ selectedCpuAuthority \in BOOLEAN
    /\ placementMintedAuthority \in BOOLEAN
    /\ fallbackExpandedAuthority \in BOOLEAN
    /\ forceAffinityAuthority \in BOOLEAN
    /\ cpusetFallbackAuthority \in BOOLEAN
    /\ classSelectionAuthority \in BOOLEAN
    /\ scxSelectionAuthority \in BOOLEAN
    /\ coreStealAuthority \in BOOLEAN
    /\ schedExecAuthority \in BOOLEAN
    /\ migrateDisableAuthority \in BOOLEAN
    /\ perCpuKthreadAuthority \in BOOLEAN
    /\ protectionClaim \in BOOLEAN

GrantAuthority ==
    /\ domainGrant
    /\ schedContextGrant
    /\ runCapGrant

FreshAllowed ==
    capEnvelope \cap linuxMask \cap activeMask \cap monitorCpuSet \cap
    memoryViewCpuSet

FrozenPlacementReady ==
    /\ placementFrozen
    /\ placementEpoch = currentEpoch
    /\ frozenAllowed = FreshAllowed
    /\ frozenAllowed # {}

NoLinuxAuthorityFlags ==
    /\ ~selectedCpuAuthority
    /\ ~placementMintedAuthority
    /\ ~fallbackExpandedAuthority
    /\ ~forceAffinityAuthority
    /\ ~cpusetFallbackAuthority
    /\ ~classSelectionAuthority
    /\ ~scxSelectionAuthority
    /\ ~coreStealAuthority
    /\ ~schedExecAuthority
    /\ ~migrateDisableAuthority
    /\ ~perCpuKthreadAuthority
    /\ ~protectionClaim

ExecutionReady(cpu) ==
    /\ taskKind = "OrdinaryDomain"
    /\ runAuthority
    /\ GrantAuthority
    /\ FrozenPlacementReady
    /\ selectedSettled
    /\ selectedCpu = cpu
    /\ cpu \in frozenAllowed
    /\ cpu \in linuxMask
    /\ cpu \in activeMask
    /\ cpu \in monitorCpuSet
    /\ cpu \in memoryViewCpuSet
    /\ ~migrationPending
    /\ NoLinuxAuthorityFlags

Init ==
    /\ phase = "Start"
    /\ taskKind = "OrdinaryDomain"
    /\ domainGrant = FALSE
    /\ schedContextGrant = FALSE
    /\ runCapGrant = FALSE
    /\ runAuthority = FALSE
    /\ serviceAuthority = FALSE
    /\ currentEpoch = 0
    /\ placementEpoch = 0
    /\ capEnvelope = CPUS
    /\ linuxMask = CPUS
    /\ activeMask = CPUS
    /\ onlineMask = CPUS
    /\ monitorCpuSet = CPUS
    /\ memoryViewCpuSet = CPUS
    /\ frozenAllowed = {}
    /\ placementFrozen = FALSE
    /\ selectedCpu = NoCpu
    /\ selectedSettled = FALSE
    /\ runCpu = NoCpu
    /\ migrationPending = FALSE
    /\ running = FALSE
    /\ failClosed = FALSE
    /\ selectedCpuAuthority = FALSE
    /\ placementMintedAuthority = FALSE
    /\ fallbackExpandedAuthority = FALSE
    /\ forceAffinityAuthority = FALSE
    /\ cpusetFallbackAuthority = FALSE
    /\ classSelectionAuthority = FALSE
    /\ scxSelectionAuthority = FALSE
    /\ coreStealAuthority = FALSE
    /\ schedExecAuthority = FALSE
    /\ migrateDisableAuthority = FALSE
    /\ perCpuKthreadAuthority = FALSE
    /\ protectionClaim = FALSE

IssueRunAuthority ==
    /\ phase = "Start"
    /\ domainGrant' = TRUE
    /\ schedContextGrant' = TRUE
    /\ runCapGrant' = TRUE
    /\ runAuthority' = TRUE
    /\ currentEpoch' = 1
    /\ phase' = "AuthorityIssued"
    /\ UNCHANGED <<taskKind, serviceAuthority, placementEpoch, capEnvelope,
                    linuxMask, activeMask, onlineMask, monitorCpuSet,
                    memoryViewCpuSet, frozenAllowed, placementFrozen,
                    selectedCpu, selectedSettled, runCpu, migrationPending,
                    running, failClosed, selectedCpuAuthority,
                    placementMintedAuthority, fallbackExpandedAuthority,
                    forceAffinityAuthority, cpusetFallbackAuthority,
                    classSelectionAuthority, scxSelectionAuthority,
                    coreStealAuthority, schedExecAuthority,
                    migrateDisableAuthority, perCpuKthreadAuthority,
                    protectionClaim>>

FreezePlacementFromAuthority ==
    /\ phase \in {"AuthorityIssued", "Invalidated"}
    /\ runAuthority
    /\ GrantAuthority
    /\ FreshAllowed # {}
    /\ placementFrozen' = TRUE
    /\ placementEpoch' = currentEpoch
    /\ frozenAllowed' = FreshAllowed
    /\ selectedCpu' = NoCpu
    /\ selectedSettled' = FALSE
    /\ runCpu' = NoCpu
    /\ migrationPending' = FALSE
    /\ running' = FALSE
    /\ failClosed' = FALSE
    /\ phase' = "Frozen"
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, serviceAuthority, currentEpoch,
                    capEnvelope, linuxMask, activeMask, onlineMask,
                    monitorCpuSet, memoryViewCpuSet,
                    selectedCpuAuthority, placementMintedAuthority,
                    fallbackExpandedAuthority, forceAffinityAuthority,
                    cpusetFallbackAuthority, classSelectionAuthority,
                    scxSelectionAuthority, coreStealAuthority,
                    schedExecAuthority, migrateDisableAuthority,
                    perCpuKthreadAuthority, protectionClaim>>

SelectByLinuxWithinFrozen ==
    /\ phase = "Frozen"
    /\ FrozenPlacementReady
    /\ \E c \in CPUS:
        /\ c \in frozenAllowed
        /\ selectedCpu' = c
    /\ selectedSettled' = TRUE
    /\ phase' = "Selected"
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, serviceAuthority, currentEpoch,
                    placementEpoch, capEnvelope, linuxMask, activeMask,
                    onlineMask, monitorCpuSet, memoryViewCpuSet,
                    frozenAllowed, placementFrozen, runCpu,
                    migrationPending, running, failClosed,
                    selectedCpuAuthority, placementMintedAuthority,
                    fallbackExpandedAuthority, forceAffinityAuthority,
                    cpusetFallbackAuthority, classSelectionAuthority,
                    scxSelectionAuthority, coreStealAuthority,
                    schedExecAuthority, migrateDisableAuthority,
                    perCpuKthreadAuthority, protectionClaim>>

RunSelected ==
    /\ phase = "Selected"
    /\ ExecutionReady(selectedCpu)
    /\ runCpu' = selectedCpu
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, serviceAuthority, currentEpoch,
                    placementEpoch, capEnvelope, linuxMask, activeMask,
                    onlineMask, monitorCpuSet, memoryViewCpuSet,
                    frozenAllowed, placementFrozen, selectedCpu,
                    selectedSettled, migrationPending, failClosed,
                    selectedCpuAuthority, placementMintedAuthority,
                    fallbackExpandedAuthority, forceAffinityAuthority,
                    cpusetFallbackAuthority, classSelectionAuthority,
                    scxSelectionAuthority, coreStealAuthority,
                    schedExecAuthority, migrateDisableAuthority,
                    perCpuKthreadAuthority, protectionClaim>>

InvalidateCommon ==
    /\ currentEpoch < 2
    /\ currentEpoch' = currentEpoch + 1
    /\ placementFrozen' = FALSE
    /\ placementEpoch' = placementEpoch
    /\ frozenAllowed' = {}
    /\ selectedCpu' = NoCpu
    /\ selectedSettled' = FALSE
    /\ runCpu' = NoCpu
    /\ migrationPending' = TRUE
    /\ running' = FALSE
    /\ failClosed' = FALSE
    /\ phase' = "Invalidated"

AffinityOrCpusetInvalidates ==
    /\ phase \in {"Frozen", "Selected", "Running"}
    /\ \E c \in CPUS:
        /\ c \in linuxMask
        /\ linuxMask' = linuxMask \ {c}
    /\ InvalidateCommon
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, serviceAuthority, capEnvelope, activeMask,
                    onlineMask, monitorCpuSet, memoryViewCpuSet,
                    selectedCpuAuthority, placementMintedAuthority,
                    fallbackExpandedAuthority, forceAffinityAuthority,
                    cpusetFallbackAuthority, classSelectionAuthority,
                    scxSelectionAuthority, coreStealAuthority,
                    schedExecAuthority, migrateDisableAuthority,
                    perCpuKthreadAuthority, protectionClaim>>

CpuHotplugInvalidates ==
    /\ phase \in {"Frozen", "Selected", "Running"}
    /\ \E c \in CPUS:
        /\ c \in activeMask
        /\ activeMask' = activeMask \ {c}
    /\ InvalidateCommon
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, serviceAuthority, capEnvelope, linuxMask,
                    onlineMask, monitorCpuSet, memoryViewCpuSet,
                    selectedCpuAuthority, placementMintedAuthority,
                    fallbackExpandedAuthority, forceAffinityAuthority,
                    cpusetFallbackAuthority, classSelectionAuthority,
                    scxSelectionAuthority, coreStealAuthority,
                    schedExecAuthority, migrateDisableAuthority,
                    perCpuKthreadAuthority, protectionClaim>>

MonitorCpuBindingInvalidates ==
    /\ phase \in {"Frozen", "Selected", "Running"}
    /\ \E c \in CPUS:
        /\ c \in monitorCpuSet
        /\ monitorCpuSet' = monitorCpuSet \ {c}
    /\ InvalidateCommon
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, serviceAuthority, capEnvelope, linuxMask,
                    activeMask, onlineMask, memoryViewCpuSet,
                    selectedCpuAuthority, placementMintedAuthority,
                    fallbackExpandedAuthority, forceAffinityAuthority,
                    cpusetFallbackAuthority, classSelectionAuthority,
                    scxSelectionAuthority, coreStealAuthority,
                    schedExecAuthority, migrateDisableAuthority,
                    perCpuKthreadAuthority, protectionClaim>>

MemoryViewCpuBindingInvalidates ==
    /\ phase \in {"Frozen", "Selected", "Running"}
    /\ \E c \in CPUS:
        /\ c \in memoryViewCpuSet
        /\ memoryViewCpuSet' = memoryViewCpuSet \ {c}
    /\ InvalidateCommon
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, serviceAuthority, capEnvelope, linuxMask,
                    activeMask, onlineMask, monitorCpuSet,
                    selectedCpuAuthority, placementMintedAuthority,
                    fallbackExpandedAuthority, forceAffinityAuthority,
                    cpusetFallbackAuthority, classSelectionAuthority,
                    scxSelectionAuthority, coreStealAuthority,
                    schedExecAuthority, migrateDisableAuthority,
                    perCpuKthreadAuthority, protectionClaim>>

NoIntersectionFailClosed ==
    /\ phase = "Invalidated"
    /\ FreshAllowed = {}
    /\ failClosed' = TRUE
    /\ migrationPending' = FALSE
    /\ running' = FALSE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<taskKind, domainGrant, schedContextGrant, runCapGrant,
                    runAuthority, serviceAuthority, currentEpoch,
                    placementEpoch, capEnvelope, linuxMask, activeMask,
                    onlineMask, monitorCpuSet, memoryViewCpuSet,
                    frozenAllowed, placementFrozen, selectedCpu,
                    selectedSettled, runCpu, selectedCpuAuthority,
                    placementMintedAuthority, fallbackExpandedAuthority,
                    forceAffinityAuthority, cpusetFallbackAuthority,
                    classSelectionAuthority, scxSelectionAuthority,
                    coreStealAuthority, schedExecAuthority,
                    migrateDisableAuthority, perCpuKthreadAuthority,
                    protectionClaim>>

TerminalStutter ==
    /\ phase \in {"Running", "FailClosed"}
    /\ UNCHANGED vars

SafeNext ==
    \/ IssueRunAuthority
    \/ FreezePlacementFromAuthority
    \/ SelectByLinuxWithinFrozen
    \/ RunSelected
    \/ AffinityOrCpusetInvalidates
    \/ CpuHotplugInvalidates
    \/ MonitorCpuBindingInvalidates
    \/ MemoryViewCpuBindingInvalidates
    \/ NoIntersectionFailClosed
    \/ TerminalStutter

SetUnsafeFlags(sel, place, fallback, force, cpuset, class, scx, core, exec,
               mig, percpu, protect) ==
    /\ selectedCpuAuthority' = sel
    /\ placementMintedAuthority' = place
    /\ fallbackExpandedAuthority' = fallback
    /\ forceAffinityAuthority' = force
    /\ cpusetFallbackAuthority' = cpuset
    /\ classSelectionAuthority' = class
    /\ scxSelectionAuthority' = scx
    /\ coreStealAuthority' = core
    /\ schedExecAuthority' = exec
    /\ migrateDisableAuthority' = mig
    /\ perCpuKthreadAuthority' = percpu
    /\ protectionClaim' = protect

UnsafeCommonAuthority ==
    /\ phase = "Start"
    /\ taskKind' = "OrdinaryDomain"
    /\ domainGrant' = TRUE
    /\ schedContextGrant' = TRUE
    /\ runCapGrant' = TRUE
    /\ runAuthority' = TRUE
    /\ serviceAuthority' = FALSE

UnsafeCommonGoodMasks ==
    /\ capEnvelope' = CPUS
    /\ linuxMask' = CPUS
    /\ activeMask' = CPUS
    /\ onlineMask' = CPUS
    /\ monitorCpuSet' = CPUS
    /\ memoryViewCpuSet' = CPUS

UnsafeCommonGoodRun ==
    /\ selectedCpu' = "cpu0"
    /\ selectedSettled' = TRUE
    /\ runCpu' = "cpu0"
    /\ migrationPending' = FALSE
    /\ running' = TRUE
    /\ failClosed' = FALSE

UnsafeGoodPlacement ==
    /\ currentEpoch' = 1
    /\ placementEpoch' = 1
    /\ placementFrozen' = TRUE
    /\ frozenAllowed' = CPUS

UnsafeRunWithoutFrozenPlacement ==
    /\ UnsafeCommonAuthority
    /\ UnsafeCommonGoodMasks
    /\ currentEpoch' = 1
    /\ placementEpoch' = 1
    /\ placementFrozen' = FALSE
    /\ frozenAllowed' = CPUS
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, FALSE)
    /\ phase' = "BadRunWithoutFrozenPlacement"

UnsafeRunWithStalePlacement ==
    /\ UnsafeCommonAuthority
    /\ UnsafeCommonGoodMasks
    /\ currentEpoch' = 1
    /\ placementEpoch' = 0
    /\ placementFrozen' = TRUE
    /\ frozenAllowed' = CPUS
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, FALSE)
    /\ phase' = "BadRunWithStalePlacement"

UnsafeRunOutsideLinuxMask ==
    /\ UnsafeCommonAuthority
    /\ capEnvelope' = CPUS
    /\ linuxMask' = {"cpu1"}
    /\ activeMask' = CPUS
    /\ onlineMask' = CPUS
    /\ monitorCpuSet' = CPUS
    /\ memoryViewCpuSet' = CPUS
    /\ UnsafeGoodPlacement
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, FALSE)
    /\ phase' = "BadRunOutsideLinuxMask"

UnsafeRunInactiveCpu ==
    /\ UnsafeCommonAuthority
    /\ capEnvelope' = CPUS
    /\ linuxMask' = CPUS
    /\ activeMask' = {"cpu1"}
    /\ onlineMask' = CPUS
    /\ monitorCpuSet' = CPUS
    /\ memoryViewCpuSet' = CPUS
    /\ UnsafeGoodPlacement
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, FALSE)
    /\ phase' = "BadRunInactiveCpu"

UnsafeRunWithoutMonitorCpuBinding ==
    /\ UnsafeCommonAuthority
    /\ capEnvelope' = CPUS
    /\ linuxMask' = CPUS
    /\ activeMask' = CPUS
    /\ onlineMask' = CPUS
    /\ monitorCpuSet' = {"cpu1"}
    /\ memoryViewCpuSet' = CPUS
    /\ UnsafeGoodPlacement
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, FALSE)
    /\ phase' = "BadRunWithoutMonitorCpuBinding"

UnsafeRunWithoutMemoryViewBinding ==
    /\ UnsafeCommonAuthority
    /\ capEnvelope' = CPUS
    /\ linuxMask' = CPUS
    /\ activeMask' = CPUS
    /\ onlineMask' = CPUS
    /\ monitorCpuSet' = CPUS
    /\ memoryViewCpuSet' = {"cpu1"}
    /\ UnsafeGoodPlacement
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, FALSE)
    /\ phase' = "BadRunWithoutMemoryViewBinding"

UnsafeRunWhileMigrationPending ==
    /\ UnsafeCommonAuthority
    /\ UnsafeCommonGoodMasks
    /\ UnsafeGoodPlacement
    /\ selectedCpu' = "cpu0"
    /\ selectedSettled' = TRUE
    /\ runCpu' = "cpu0"
    /\ migrationPending' = TRUE
    /\ running' = TRUE
    /\ failClosed' = FALSE
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, FALSE)
    /\ phase' = "BadRunWhileMigrationPending"

UnsafeSelectedCpuAuthority ==
    /\ UnsafeCommonAuthority
    /\ UnsafeCommonGoodMasks
    /\ UnsafeGoodPlacement
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, FALSE)
    /\ phase' = "BadSelectedCpuAuthority"

UnsafePlacementMintedAuthority ==
    /\ phase = "Start"
    /\ taskKind' = "OrdinaryDomain"
    /\ domainGrant' = FALSE
    /\ schedContextGrant' = FALSE
    /\ runCapGrant' = FALSE
    /\ runAuthority' = TRUE
    /\ serviceAuthority' = FALSE
    /\ UnsafeCommonGoodMasks
    /\ UnsafeGoodPlacement
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, FALSE)
    /\ phase' = "BadPlacementMintedAuthority"

UnsafeFallbackExpansionAuthority ==
    /\ UnsafeCommonAuthority
    /\ UnsafeCommonGoodMasks
    /\ UnsafeGoodPlacement
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, FALSE)
    /\ phase' = "BadFallbackExpansionAuthority"

UnsafeForceAffinityAuthority ==
    /\ UnsafeCommonAuthority
    /\ UnsafeCommonGoodMasks
    /\ UnsafeGoodPlacement
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, FALSE)
    /\ phase' = "BadForceAffinityAuthority"

UnsafeCpusetFallbackAuthority ==
    /\ UnsafeCommonAuthority
    /\ UnsafeCommonGoodMasks
    /\ UnsafeGoodPlacement
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, FALSE)
    /\ phase' = "BadCpusetFallbackAuthority"

UnsafeClassSelectionAuthority ==
    /\ UnsafeCommonAuthority
    /\ UnsafeCommonGoodMasks
    /\ UnsafeGoodPlacement
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, FALSE)
    /\ phase' = "BadClassSelectionAuthority"

UnsafeScxSelectionAuthority ==
    /\ UnsafeCommonAuthority
    /\ UnsafeCommonGoodMasks
    /\ UnsafeGoodPlacement
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE,
                      FALSE, FALSE, FALSE, FALSE)
    /\ phase' = "BadScxSelectionAuthority"

UnsafeCoreStealAuthority ==
    /\ UnsafeCommonAuthority
    /\ UnsafeCommonGoodMasks
    /\ UnsafeGoodPlacement
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE,
                      FALSE, FALSE, FALSE, FALSE)
    /\ phase' = "BadCoreStealAuthority"

UnsafeSchedExecAuthority ==
    /\ UnsafeCommonAuthority
    /\ UnsafeCommonGoodMasks
    /\ UnsafeGoodPlacement
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                      TRUE, FALSE, FALSE, FALSE)
    /\ phase' = "BadSchedExecAuthority"

UnsafeMigrateDisableAuthority ==
    /\ UnsafeCommonAuthority
    /\ UnsafeCommonGoodMasks
    /\ UnsafeGoodPlacement
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                      FALSE, TRUE, FALSE, FALSE)
    /\ phase' = "BadMigrateDisableAuthority"

UnsafePerCpuKthreadAuthority ==
    /\ UnsafeCommonAuthority
    /\ UnsafeCommonGoodMasks
    /\ UnsafeGoodPlacement
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, TRUE, FALSE)
    /\ phase' = "BadPerCpuKthreadAuthority"

UnsafeNoIntersectionRuns ==
    /\ UnsafeCommonAuthority
    /\ capEnvelope' = {"cpu0"}
    /\ linuxMask' = {"cpu1"}
    /\ activeMask' = CPUS
    /\ onlineMask' = CPUS
    /\ monitorCpuSet' = CPUS
    /\ memoryViewCpuSet' = CPUS
    /\ currentEpoch' = 1
    /\ placementEpoch' = 1
    /\ placementFrozen' = TRUE
    /\ frozenAllowed' = {"cpu0"}
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, FALSE)
    /\ phase' = "BadNoIntersectionRuns"

UnsafeProtectionClaim ==
    /\ UnsafeCommonAuthority
    /\ UnsafeCommonGoodMasks
    /\ UnsafeGoodPlacement
    /\ UnsafeCommonGoodRun
    /\ SetUnsafeFlags(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, TRUE)
    /\ phase' = "BadProtectionClaim"

SpecUnsafeRunWithoutFrozenPlacement ==
    Init /\ [][UnsafeRunWithoutFrozenPlacement]_vars

SpecUnsafeRunWithStalePlacement ==
    Init /\ [][UnsafeRunWithStalePlacement]_vars

SpecUnsafeRunOutsideLinuxMask ==
    Init /\ [][UnsafeRunOutsideLinuxMask]_vars

SpecUnsafeRunInactiveCpu ==
    Init /\ [][UnsafeRunInactiveCpu]_vars

SpecUnsafeRunWithoutMonitorCpuBinding ==
    Init /\ [][UnsafeRunWithoutMonitorCpuBinding]_vars

SpecUnsafeRunWithoutMemoryViewBinding ==
    Init /\ [][UnsafeRunWithoutMemoryViewBinding]_vars

SpecUnsafeRunWhileMigrationPending ==
    Init /\ [][UnsafeRunWhileMigrationPending]_vars

SpecUnsafeSelectedCpuAuthority ==
    Init /\ [][UnsafeSelectedCpuAuthority]_vars

SpecUnsafePlacementMintedAuthority ==
    Init /\ [][UnsafePlacementMintedAuthority]_vars

SpecUnsafeFallbackExpansionAuthority ==
    Init /\ [][UnsafeFallbackExpansionAuthority]_vars

SpecUnsafeForceAffinityAuthority ==
    Init /\ [][UnsafeForceAffinityAuthority]_vars

SpecUnsafeCpusetFallbackAuthority ==
    Init /\ [][UnsafeCpusetFallbackAuthority]_vars

SpecUnsafeClassSelectionAuthority ==
    Init /\ [][UnsafeClassSelectionAuthority]_vars

SpecUnsafeScxSelectionAuthority ==
    Init /\ [][UnsafeScxSelectionAuthority]_vars

SpecUnsafeCoreStealAuthority ==
    Init /\ [][UnsafeCoreStealAuthority]_vars

SpecUnsafeSchedExecAuthority ==
    Init /\ [][UnsafeSchedExecAuthority]_vars

SpecUnsafeMigrateDisableAuthority ==
    Init /\ [][UnsafeMigrateDisableAuthority]_vars

SpecUnsafePerCpuKthreadAuthority ==
    Init /\ [][UnsafePerCpuKthreadAuthority]_vars

SpecUnsafeNoIntersectionRuns ==
    Init /\ [][UnsafeNoIntersectionRuns]_vars

SpecUnsafeProtectionClaim ==
    Init /\ [][UnsafeProtectionClaim]_vars

SafeSpec ==
    Init /\ [][SafeNext]_vars

NoRunWithoutGrantAuthority ==
    running => GrantAuthority

NoRunWithoutFrozenPlacement ==
    running => placementFrozen

NoRunWithStalePlacement ==
    running => placementEpoch = currentEpoch

FrozenAllowedIsDerived ==
    placementFrozen => /\ frozenAllowed = FreshAllowed
                       /\ frozenAllowed # {}

NoRunCpuMismatch ==
    running => /\ runCpu = selectedCpu
               /\ selectedSettled

NoRunOutsideFrozenCpu ==
    running => runCpu \in frozenAllowed

NoRunOutsideLinuxCurrentMask ==
    running => runCpu \in linuxMask

NoRunOnInactiveCpu ==
    running => runCpu \in activeMask

NoRunWithoutMonitorCpuBinding ==
    running => runCpu \in monitorCpuSet

NoRunWithoutMemoryViewBinding ==
    running => runCpu \in memoryViewCpuSet

NoRunWhileMigrationPending ==
    running => ~migrationPending

NoNoIntersectionRun ==
    FreshAllowed = {} => ~running

NoSelectionAsAuthority ==
    /\ ~selectedCpuAuthority
    /\ ~classSelectionAuthority
    /\ ~scxSelectionAuthority
    /\ ~coreStealAuthority
    /\ ~schedExecAuthority

NoFallbackAsAuthority ==
    /\ ~fallbackExpandedAuthority
    /\ ~forceAffinityAuthority
    /\ ~cpusetFallbackAuthority

NoLinuxExceptionAsDomainAuthority ==
    (running /\ taskKind = "OrdinaryDomain") =>
        /\ ~migrateDisableAuthority
        /\ ~perCpuKthreadAuthority

NoPlacementMintedAuthority ==
    runAuthority => /\ GrantAuthority
                    /\ ~placementMintedAuthority

NoProtectionClaim ==
    ~protectionClaim

=============================================================================
