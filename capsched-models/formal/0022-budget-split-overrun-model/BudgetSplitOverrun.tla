---------------------- MODULE BudgetSplitOverrun ----------------------
EXTENDS Naturals

VARIABLES
    phase,
    rootBudget,
    schedBudget,
    classRuntime,
    budgetEpochFresh,
    selected,
    running,
    ordinaryTickActive,
    nohzTickStopped,
    monitorTimerArmed,
    hrtickArmed,
    hrtickFloorExceeded,
    remoteTickOnly,
    classReplenished,
    classRuntimeAuthority,
    failClosed

vars == <<phase, rootBudget, schedBudget, classRuntime, budgetEpochFresh,
          selected, running, ordinaryTickActive, nohzTickStopped,
          monitorTimerArmed, hrtickArmed, hrtickFloorExceeded,
          remoteTickOnly, classReplenished, classRuntimeAuthority,
          failClosed>>

Phases == {
    "Start",
    "BudgetsPrepared",
    "Selected",
    "TimerArmed",
    "Running",
    "NoHzRunning",
    "BudgetClosed",
    "HrtickFloorClosed",
    "ClassReplenishClosed",
    "RemoteTickObservedClosed",
    "BadClassRuntimeOnlyRun",
    "BadNoHzNoTimer",
    "BadHrtickFloorRun",
    "BadRemoteTickOnlyRun",
    "BadReplenishNoEpoch"
}

TypeOK ==
    /\ phase \in Phases
    /\ rootBudget \in BOOLEAN
    /\ schedBudget \in BOOLEAN
    /\ classRuntime \in BOOLEAN
    /\ budgetEpochFresh \in BOOLEAN
    /\ selected \in BOOLEAN
    /\ running \in BOOLEAN
    /\ ordinaryTickActive \in BOOLEAN
    /\ nohzTickStopped \in BOOLEAN
    /\ monitorTimerArmed \in BOOLEAN
    /\ hrtickArmed \in BOOLEAN
    /\ hrtickFloorExceeded \in BOOLEAN
    /\ remoteTickOnly \in BOOLEAN
    /\ classReplenished \in BOOLEAN
    /\ classRuntimeAuthority \in BOOLEAN
    /\ failClosed \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ rootBudget = FALSE
    /\ schedBudget = FALSE
    /\ classRuntime = FALSE
    /\ budgetEpochFresh = FALSE
    /\ selected = FALSE
    /\ running = FALSE
    /\ ordinaryTickActive = TRUE
    /\ nohzTickStopped = FALSE
    /\ monitorTimerArmed = FALSE
    /\ hrtickArmed = FALSE
    /\ hrtickFloorExceeded = FALSE
    /\ remoteTickOnly = FALSE
    /\ classReplenished = FALSE
    /\ classRuntimeAuthority = FALSE
    /\ failClosed = FALSE

PrepareBudgets ==
    /\ phase = "Start"
    /\ rootBudget' = TRUE
    /\ schedBudget' = TRUE
    /\ classRuntime' = TRUE
    /\ budgetEpochFresh' = TRUE
    /\ phase' = "BudgetsPrepared"
    /\ UNCHANGED <<selected, running, ordinaryTickActive, nohzTickStopped,
                    monitorTimerArmed, hrtickArmed, hrtickFloorExceeded,
                    remoteTickOnly, classReplenished, classRuntimeAuthority,
                    failClosed>>

SelectWithBudgets ==
    /\ phase = "BudgetsPrepared"
    /\ rootBudget
    /\ schedBudget
    /\ classRuntime
    /\ budgetEpochFresh
    /\ selected' = TRUE
    /\ phase' = "Selected"
    /\ UNCHANGED <<rootBudget, schedBudget, classRuntime, budgetEpochFresh,
                    running, ordinaryTickActive, nohzTickStopped,
                    monitorTimerArmed, hrtickArmed, hrtickFloorExceeded,
                    remoteTickOnly, classReplenished, classRuntimeAuthority,
                    failClosed>>

ArmMonitorTimer ==
    /\ phase = "Selected"
    /\ selected
    /\ rootBudget
    /\ schedBudget
    /\ budgetEpochFresh
    /\ monitorTimerArmed' = TRUE
    /\ hrtickArmed' = TRUE
    /\ phase' = "TimerArmed"
    /\ UNCHANGED <<rootBudget, schedBudget, classRuntime, budgetEpochFresh,
                    selected, running, ordinaryTickActive, nohzTickStopped,
                    hrtickFloorExceeded, remoteTickOnly, classReplenished,
                    classRuntimeAuthority, failClosed>>

RunWithBudgets ==
    /\ phase = "TimerArmed"
    /\ selected
    /\ rootBudget
    /\ schedBudget
    /\ classRuntime
    /\ budgetEpochFresh
    /\ monitorTimerArmed
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<rootBudget, schedBudget, classRuntime, budgetEpochFresh,
                    selected, ordinaryTickActive, nohzTickStopped,
                    monitorTimerArmed, hrtickArmed, hrtickFloorExceeded,
                    remoteTickOnly, classReplenished, classRuntimeAuthority,
                    failClosed>>

EnterNoHzWithMonitorTimer ==
    /\ phase = "Running"
    /\ running
    /\ rootBudget
    /\ schedBudget
    /\ budgetEpochFresh
    /\ monitorTimerArmed
    /\ ordinaryTickActive' = FALSE
    /\ nohzTickStopped' = TRUE
    /\ phase' = "NoHzRunning"
    /\ UNCHANGED <<rootBudget, schedBudget, classRuntime, budgetEpochFresh,
                    selected, running, monitorTimerArmed, hrtickArmed,
                    hrtickFloorExceeded, remoteTickOnly, classReplenished,
                    classRuntimeAuthority, failClosed>>

BudgetExhaustCloses ==
    /\ phase \in {"Selected", "TimerArmed", "Running", "NoHzRunning"}
    /\ rootBudget' = FALSE
    /\ schedBudget' = FALSE
    /\ selected' = FALSE
    /\ running' = FALSE
    /\ failClosed' = TRUE
    /\ phase' = "BudgetClosed"
    /\ UNCHANGED <<classRuntime, budgetEpochFresh, ordinaryTickActive,
                    nohzTickStopped, monitorTimerArmed, hrtickArmed,
                    hrtickFloorExceeded, remoteTickOnly, classReplenished,
                    classRuntimeAuthority>>

HrtickFloorCloses ==
    /\ phase = "TimerArmed"
    /\ hrtickArmed
    /\ hrtickFloorExceeded' = TRUE
    /\ selected' = FALSE
    /\ running' = FALSE
    /\ failClosed' = TRUE
    /\ phase' = "HrtickFloorClosed"
    /\ UNCHANGED <<rootBudget, schedBudget, classRuntime, budgetEpochFresh,
                    ordinaryTickActive, nohzTickStopped, monitorTimerArmed,
                    hrtickArmed, remoteTickOnly, classReplenished,
                    classRuntimeAuthority>>

ClassReplenishInvalidatesEpoch ==
    /\ phase \in {"Selected", "TimerArmed", "Running", "NoHzRunning"}
    /\ classRuntime' = TRUE
    /\ classReplenished' = TRUE
    /\ budgetEpochFresh' = FALSE
    /\ selected' = FALSE
    /\ running' = FALSE
    /\ failClosed' = TRUE
    /\ phase' = "ClassReplenishClosed"
    /\ UNCHANGED <<rootBudget, schedBudget, ordinaryTickActive,
                    nohzTickStopped, monitorTimerArmed, hrtickArmed,
                    hrtickFloorExceeded, remoteTickOnly,
                    classRuntimeAuthority>>

RemoteTickObservationCloses ==
    /\ phase = "Running"
    /\ remoteTickOnly' = TRUE
    /\ selected' = FALSE
    /\ running' = FALSE
    /\ failClosed' = TRUE
    /\ phase' = "RemoteTickObservedClosed"
    /\ UNCHANGED <<rootBudget, schedBudget, classRuntime, budgetEpochFresh,
                    ordinaryTickActive, nohzTickStopped, monitorTimerArmed,
                    hrtickArmed, hrtickFloorExceeded, classReplenished,
                    classRuntimeAuthority>>

UnsafeClassRuntimeOnlyRuns ==
    /\ phase = "Selected"
    /\ classRuntime
    /\ rootBudget' = FALSE
    /\ schedBudget' = FALSE
    /\ classRuntimeAuthority' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadClassRuntimeOnlyRun"
    /\ UNCHANGED <<classRuntime, budgetEpochFresh, selected,
                    ordinaryTickActive, nohzTickStopped, monitorTimerArmed,
                    hrtickArmed, hrtickFloorExceeded, remoteTickOnly,
                    classReplenished, failClosed>>

UnsafeNoHzNoMonitorTimer ==
    /\ phase = "Running"
    /\ running
    /\ monitorTimerArmed' = FALSE
    /\ ordinaryTickActive' = FALSE
    /\ nohzTickStopped' = TRUE
    /\ phase' = "BadNoHzNoTimer"
    /\ UNCHANGED <<rootBudget, schedBudget, classRuntime, budgetEpochFresh,
                    selected, running, hrtickArmed, hrtickFloorExceeded,
                    remoteTickOnly, classReplenished, classRuntimeAuthority,
                    failClosed>>

UnsafeHrtickFloorOverrun ==
    /\ phase = "TimerArmed"
    /\ hrtickArmed
    /\ hrtickFloorExceeded' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadHrtickFloorRun"
    /\ UNCHANGED <<rootBudget, schedBudget, classRuntime, budgetEpochFresh,
                    selected, ordinaryTickActive, nohzTickStopped,
                    monitorTimerArmed, hrtickArmed, remoteTickOnly,
                    classReplenished, classRuntimeAuthority, failClosed>>

UnsafeRemoteTickOnlyRuns ==
    /\ phase = "Running"
    /\ running
    /\ remoteTickOnly' = TRUE
    /\ monitorTimerArmed' = FALSE
    /\ phase' = "BadRemoteTickOnlyRun"
    /\ UNCHANGED <<rootBudget, schedBudget, classRuntime, budgetEpochFresh,
                    selected, running, ordinaryTickActive, nohzTickStopped,
                    hrtickArmed, hrtickFloorExceeded, classReplenished,
                    classRuntimeAuthority, failClosed>>

UnsafeReplenishWithoutEpoch ==
    /\ phase = "Running"
    /\ running
    /\ classReplenished' = TRUE
    /\ budgetEpochFresh' = FALSE
    /\ phase' = "BadReplenishNoEpoch"
    /\ UNCHANGED <<rootBudget, schedBudget, classRuntime, selected, running,
                    ordinaryTickActive, nohzTickStopped, monitorTimerArmed,
                    hrtickArmed, hrtickFloorExceeded, remoteTickOnly,
                    classRuntimeAuthority, failClosed>>

SafeNext ==
    PrepareBudgets \/ SelectWithBudgets \/ ArmMonitorTimer \/
    RunWithBudgets \/ EnterNoHzWithMonitorTimer \/ BudgetExhaustCloses \/
    HrtickFloorCloses \/ ClassReplenishInvalidatesEpoch \/
    RemoteTickObservationCloses

UnsafeClassRuntimeOnlySpec ==
    Init /\ [][SafeNext \/ UnsafeClassRuntimeOnlyRuns]_vars

UnsafeNoHzNoTimerSpec ==
    Init /\ [][SafeNext \/ UnsafeNoHzNoMonitorTimer]_vars

UnsafeHrtickFloorSpec ==
    Init /\ [][SafeNext \/ UnsafeHrtickFloorOverrun]_vars

UnsafeRemoteTickOnlySpec ==
    Init /\ [][SafeNext \/ UnsafeRemoteTickOnlyRuns]_vars

UnsafeReplenishNoEpochSpec ==
    Init /\ [][SafeNext \/ UnsafeReplenishWithoutEpoch]_vars

SafeSpec ==
    Init /\ [][SafeNext]_vars

NoRunWithoutRootBudget ==
    running => rootBudget

NoRunWithoutSchedContextBudget ==
    running => schedBudget

NoRunWithStaleBudgetEpoch ==
    running => budgetEpochFresh

NoClassRuntimeAsRootAuthority ==
    ~(running /\ classRuntimeAuthority)

NoNoHzRunWithoutMonitorBudgetTimer ==
    (running /\ nohzTickStopped) => monitorTimerArmed

NoHrtickFloorClaimAsExactCap ==
    hrtickFloorExceeded => (~running /\ failClosed)

NoRemoteTickOnlyRootBudgetEnforcer ==
    (running /\ remoteTickOnly) => monitorTimerArmed

NoReplenishWithoutEpochRefresh ==
    (running /\ classReplenished) => budgetEpochFresh

=============================================================================
