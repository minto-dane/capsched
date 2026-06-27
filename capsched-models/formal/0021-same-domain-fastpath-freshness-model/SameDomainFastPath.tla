---------------------- MODULE SameDomainFastPath ----------------------
EXTENDS Naturals

VARIABLES
    phase,
    sameDomain,
    monitorActive,
    epochFresh,
    memViewFresh,
    rootBudget,
    schedBudget,
    frozenFresh,
    selected,
    fastPathTaken,
    monitorCalled,
    running,
    revokePending,
    nohzTickStopped,
    monitorTimerArmed,
    failClosed

vars == <<phase, sameDomain, monitorActive, epochFresh, memViewFresh,
          rootBudget, schedBudget, frozenFresh, selected, fastPathTaken,
          monitorCalled, running, revokePending, nohzTickStopped,
          monitorTimerArmed, failClosed>>

Phases == {
    "Start",
    "MonitorActive",
    "Selected",
    "FastPathReady",
    "Running",
    "NoHzRunning",
    "StaleClosed",
    "BudgetClosed",
    "BadFastPathStaleEpoch",
    "BadFastPathStaleMemView",
    "BadRunNoBudget",
    "BadNoHzNoTimer",
    "BadRevokeRun",
    "BadSelectedBudgetRun"
}

TypeOK ==
    /\ phase \in Phases
    /\ sameDomain \in BOOLEAN
    /\ monitorActive \in BOOLEAN
    /\ epochFresh \in BOOLEAN
    /\ memViewFresh \in BOOLEAN
    /\ rootBudget \in BOOLEAN
    /\ schedBudget \in BOOLEAN
    /\ frozenFresh \in BOOLEAN
    /\ selected \in BOOLEAN
    /\ fastPathTaken \in BOOLEAN
    /\ monitorCalled \in BOOLEAN
    /\ running \in BOOLEAN
    /\ revokePending \in BOOLEAN
    /\ nohzTickStopped \in BOOLEAN
    /\ monitorTimerArmed \in BOOLEAN
    /\ failClosed \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ sameDomain = FALSE
    /\ monitorActive = FALSE
    /\ epochFresh = FALSE
    /\ memViewFresh = FALSE
    /\ rootBudget = FALSE
    /\ schedBudget = FALSE
    /\ frozenFresh = FALSE
    /\ selected = FALSE
    /\ fastPathTaken = FALSE
    /\ monitorCalled = FALSE
    /\ running = FALSE
    /\ revokePending = FALSE
    /\ nohzTickStopped = FALSE
    /\ monitorTimerArmed = FALSE
    /\ failClosed = FALSE

MonitorActivate ==
    /\ phase = "Start"
    /\ monitorActive' = TRUE
    /\ epochFresh' = TRUE
    /\ memViewFresh' = TRUE
    /\ rootBudget' = TRUE
    /\ schedBudget' = TRUE
    /\ frozenFresh' = TRUE
    /\ monitorCalled' = TRUE
    /\ phase' = "MonitorActive"
    /\ UNCHANGED <<sameDomain, selected, fastPathTaken, running,
                    revokePending, nohzTickStopped, monitorTimerArmed,
                    failClosed>>

SelectSameDomainCandidate ==
    /\ phase = "MonitorActive"
    /\ monitorActive
    /\ epochFresh
    /\ memViewFresh
    /\ rootBudget
    /\ schedBudget
    /\ frozenFresh
    /\ sameDomain' = TRUE
    /\ selected' = TRUE
    /\ phase' = "Selected"
    /\ UNCHANGED <<monitorActive, epochFresh, memViewFresh, rootBudget,
                    schedBudget, frozenFresh, fastPathTaken, monitorCalled,
                    running, revokePending, nohzTickStopped,
                    monitorTimerArmed, failClosed>>

SameDomainFastPathCheck ==
    /\ phase = "Selected"
    /\ sameDomain
    /\ selected
    /\ monitorActive
    /\ epochFresh
    /\ memViewFresh
    /\ rootBudget
    /\ schedBudget
    /\ frozenFresh
    /\ fastPathTaken' = TRUE
    /\ phase' = "FastPathReady"
    /\ UNCHANGED <<sameDomain, monitorActive, epochFresh, memViewFresh,
                    rootBudget, schedBudget, frozenFresh, selected,
                    monitorCalled, running, revokePending, nohzTickStopped,
                    monitorTimerArmed, failClosed>>

RunAfterFastPath ==
    /\ phase = "FastPathReady"
    /\ fastPathTaken
    /\ monitorActive
    /\ epochFresh
    /\ memViewFresh
    /\ rootBudget
    /\ schedBudget
    /\ frozenFresh
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<sameDomain, monitorActive, epochFresh, memViewFresh,
                    rootBudget, schedBudget, frozenFresh, selected,
                    fastPathTaken, monitorCalled, revokePending,
                    nohzTickStopped, monitorTimerArmed, failClosed>>

NoHzRunWithMonitorTimer ==
    /\ phase = "Running"
    /\ running
    /\ rootBudget
    /\ schedBudget
    /\ monitorTimerArmed' = TRUE
    /\ nohzTickStopped' = TRUE
    /\ phase' = "NoHzRunning"
    /\ UNCHANGED <<sameDomain, monitorActive, epochFresh, memViewFresh,
                    rootBudget, schedBudget, frozenFresh, selected,
                    fastPathTaken, monitorCalled, running, revokePending,
                    failClosed>>

RevokeBeforeRunCloses ==
    /\ phase \in {"Selected", "FastPathReady", "Running", "NoHzRunning"}
    /\ epochFresh' = FALSE
    /\ memViewFresh' = FALSE
    /\ selected' = FALSE
    /\ fastPathTaken' = FALSE
    /\ running' = FALSE
    /\ revokePending' = TRUE
    /\ failClosed' = TRUE
    /\ phase' = "StaleClosed"
    /\ UNCHANGED <<sameDomain, monitorActive, rootBudget, schedBudget,
                    frozenFresh, monitorCalled, nohzTickStopped,
                    monitorTimerArmed>>

BudgetExhaustCloses ==
    /\ phase \in {"Selected", "FastPathReady", "Running", "NoHzRunning"}
    /\ rootBudget' = FALSE
    /\ schedBudget' = FALSE
    /\ selected' = FALSE
    /\ fastPathTaken' = FALSE
    /\ running' = FALSE
    /\ failClosed' = TRUE
    /\ phase' = "BudgetClosed"
    /\ UNCHANGED <<sameDomain, monitorActive, epochFresh, memViewFresh,
                    frozenFresh, monitorCalled, revokePending,
                    nohzTickStopped, monitorTimerArmed>>

MonitorRevalidates ==
    /\ phase = "StaleClosed"
    /\ revokePending
    /\ monitorCalled' = TRUE
    /\ epochFresh' = TRUE
    /\ memViewFresh' = TRUE
    /\ rootBudget' = TRUE
    /\ schedBudget' = TRUE
    /\ frozenFresh' = TRUE
    /\ selected' = TRUE
    /\ revokePending' = FALSE
    /\ failClosed' = FALSE
    /\ phase' = "Selected"
    /\ UNCHANGED <<sameDomain, monitorActive, fastPathTaken, running,
                    nohzTickStopped, monitorTimerArmed>>

UnsafeFastPathStaleEpoch ==
    /\ phase = "Selected"
    /\ selected
    /\ epochFresh' = FALSE
    /\ fastPathTaken' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadFastPathStaleEpoch"
    /\ UNCHANGED <<sameDomain, monitorActive, memViewFresh, rootBudget,
                    schedBudget, frozenFresh, selected, monitorCalled,
                    revokePending, nohzTickStopped, monitorTimerArmed,
                    failClosed>>

UnsafeFastPathStaleMemView ==
    /\ phase = "Selected"
    /\ selected
    /\ memViewFresh' = FALSE
    /\ fastPathTaken' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadFastPathStaleMemView"
    /\ UNCHANGED <<sameDomain, monitorActive, epochFresh, rootBudget,
                    schedBudget, frozenFresh, selected, monitorCalled,
                    revokePending, nohzTickStopped, monitorTimerArmed,
                    failClosed>>

UnsafeRunWithoutBudget ==
    /\ phase = "FastPathReady"
    /\ fastPathTaken
    /\ rootBudget' = FALSE
    /\ schedBudget' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadRunNoBudget"
    /\ UNCHANGED <<sameDomain, monitorActive, epochFresh, memViewFresh,
                    frozenFresh, selected, fastPathTaken, monitorCalled,
                    revokePending, nohzTickStopped, monitorTimerArmed,
                    failClosed>>

UnsafeNoHzWithoutTimer ==
    /\ phase = "Running"
    /\ running
    /\ nohzTickStopped' = TRUE
    /\ monitorTimerArmed' = FALSE
    /\ phase' = "BadNoHzNoTimer"
    /\ UNCHANGED <<sameDomain, monitorActive, epochFresh, memViewFresh,
                    rootBudget, schedBudget, frozenFresh, selected,
                    fastPathTaken, monitorCalled, running, revokePending,
                    failClosed>>

UnsafeRevokeWhileRunning ==
    /\ phase = "Running"
    /\ running
    /\ epochFresh' = FALSE
    /\ memViewFresh' = FALSE
    /\ revokePending' = TRUE
    /\ phase' = "BadRevokeRun"
    /\ UNCHANGED <<sameDomain, monitorActive, rootBudget, schedBudget,
                    frozenFresh, selected, fastPathTaken, monitorCalled,
                    running, nohzTickStopped, monitorTimerArmed, failClosed>>

UnsafeSelectedBudgetStaleRun ==
    /\ phase = "Selected"
    /\ selected
    /\ rootBudget' = FALSE
    /\ schedBudget' = FALSE
    /\ fastPathTaken' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadSelectedBudgetRun"
    /\ UNCHANGED <<sameDomain, monitorActive, epochFresh, memViewFresh,
                    frozenFresh, selected, monitorCalled, revokePending,
                    nohzTickStopped, monitorTimerArmed, failClosed>>

SafeNext ==
    \/ MonitorActivate
    \/ SelectSameDomainCandidate
    \/ SameDomainFastPathCheck
    \/ RunAfterFastPath
    \/ NoHzRunWithMonitorTimer
    \/ RevokeBeforeRunCloses
    \/ BudgetExhaustCloses
    \/ MonitorRevalidates

SafeSpec == Init /\ [][SafeNext]_vars

UnsafeFastPathStaleEpochSpec ==
    Init /\ [][SafeNext \/ UnsafeFastPathStaleEpoch]_vars

UnsafeFastPathStaleMemViewSpec ==
    Init /\ [][SafeNext \/ UnsafeFastPathStaleMemView]_vars

UnsafeRunNoBudgetSpec ==
    Init /\ [][SafeNext \/ UnsafeRunWithoutBudget]_vars

UnsafeNoHzNoTimerSpec ==
    Init /\ [][SafeNext \/ UnsafeNoHzWithoutTimer]_vars

UnsafeRevokeRunSpec ==
    Init /\ [][SafeNext \/ UnsafeRevokeWhileRunning]_vars

UnsafeSelectedBudgetSpec ==
    Init /\ [][SafeNext \/ UnsafeSelectedBudgetStaleRun]_vars

NoFastPathWithStaleMonitor ==
    fastPathTaken => monitorActive /\ epochFresh /\ memViewFresh

NoRunWithStaleMonitor ==
    running => monitorActive /\ epochFresh /\ memViewFresh /\ frozenFresh

NoRunWithoutBudget ==
    running => rootBudget /\ schedBudget

NoNoHzBudgetWithoutMonitorTimer ==
    (running /\ nohzTickStopped) => monitorTimerArmed

NoRevokePendingRun ==
    revokePending => ~running

NoSelectedBudgetStaleRun ==
    (selected /\ (~rootBudget \/ ~schedBudget)) => ~running /\ ~fastPathTaken

=============================================================================
