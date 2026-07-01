---------------------- MODULE MonitorRootBudgetTimer ----------------------
EXTENDS Naturals

VARIABLES
    phase,
    runTokenSealed,
    domainEpochFresh,
    monitorOwnsTimer,
    monitorTimerArmed,
    monitorDeadlineFresh,
    rootBudget,
    active,
    running,
    monitorInterruptDelivered,
    linuxTimerArmed,
    linuxReportedCharge,
    linuxTimerAsRoot,
    linuxReportedAsRoot,
    nohzStopped,
    protectionClaim,
    accepted,
    failClosed

vars == <<phase, runTokenSealed, domainEpochFresh, monitorOwnsTimer,
          monitorTimerArmed, monitorDeadlineFresh, rootBudget, active,
          running, monitorInterruptDelivered, linuxTimerArmed,
          linuxReportedCharge, linuxTimerAsRoot, linuxReportedAsRoot,
          nohzStopped, protectionClaim, accepted, failClosed>>

Phases == {
    "Start",
    "TokenValidated",
    "Activated",
    "Running",
    "Accepted",
    "FailClosed",
    "BadNoTimer",
    "BadNoBudget",
    "BadLinuxTimerRoot",
    "BadOverrunAfterExpiry",
    "BadLinuxChargeRoot",
    "BadUnsealedToken",
    "BadEpochRevokedRun",
    "BadRunAfterInterrupt",
    "BadNoHzStopsMonitor",
    "BadProtectionClaim"
}

Budgets == 0..2

TypeOK ==
    /\ phase \in Phases
    /\ runTokenSealed \in BOOLEAN
    /\ domainEpochFresh \in BOOLEAN
    /\ monitorOwnsTimer \in BOOLEAN
    /\ monitorTimerArmed \in BOOLEAN
    /\ monitorDeadlineFresh \in BOOLEAN
    /\ rootBudget \in Budgets
    /\ active \in BOOLEAN
    /\ running \in BOOLEAN
    /\ monitorInterruptDelivered \in BOOLEAN
    /\ linuxTimerArmed \in BOOLEAN
    /\ linuxReportedCharge \in BOOLEAN
    /\ linuxTimerAsRoot \in BOOLEAN
    /\ linuxReportedAsRoot \in BOOLEAN
    /\ nohzStopped \in BOOLEAN
    /\ protectionClaim \in BOOLEAN
    /\ accepted \in BOOLEAN
    /\ failClosed \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ runTokenSealed = FALSE
    /\ domainEpochFresh = FALSE
    /\ monitorOwnsTimer = FALSE
    /\ monitorTimerArmed = FALSE
    /\ monitorDeadlineFresh = FALSE
    /\ rootBudget = 0
    /\ active = FALSE
    /\ running = FALSE
    /\ monitorInterruptDelivered = FALSE
    /\ linuxTimerArmed = FALSE
    /\ linuxReportedCharge = FALSE
    /\ linuxTimerAsRoot = FALSE
    /\ linuxReportedAsRoot = FALSE
    /\ nohzStopped = FALSE
    /\ protectionClaim = FALSE
    /\ accepted = FALSE
    /\ failClosed = FALSE

ValidateTokenAndBudget ==
    /\ phase = "Start"
    /\ runTokenSealed' = TRUE
    /\ domainEpochFresh' = TRUE
    /\ monitorOwnsTimer' = TRUE
    /\ rootBudget' = 2
    /\ phase' = "TokenValidated"
    /\ UNCHANGED <<monitorTimerArmed, monitorDeadlineFresh, active, running,
                    monitorInterruptDelivered, linuxTimerArmed,
                    linuxReportedCharge, linuxTimerAsRoot, linuxReportedAsRoot,
                    nohzStopped, protectionClaim, accepted, failClosed>>

ActivateWithMonitorTimer ==
    /\ phase = "TokenValidated"
    /\ runTokenSealed
    /\ domainEpochFresh
    /\ monitorOwnsTimer
    /\ rootBudget > 0
    /\ monitorTimerArmed' = TRUE
    /\ monitorDeadlineFresh' = TRUE
    /\ active' = TRUE
    /\ running' = TRUE
    /\ phase' = "Activated"
    /\ UNCHANGED <<runTokenSealed, domainEpochFresh, monitorOwnsTimer,
                    rootBudget, monitorInterruptDelivered, linuxTimerArmed,
                    linuxReportedCharge, linuxTimerAsRoot, linuxReportedAsRoot,
                    nohzStopped, protectionClaim, accepted, failClosed>>

LinuxEarlyTimerObservation ==
    /\ phase \in {"Activated", "Running"}
    /\ running
    /\ linuxTimerArmed' = TRUE
    /\ linuxReportedCharge' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<runTokenSealed, domainEpochFresh, monitorOwnsTimer,
                    monitorTimerArmed, monitorDeadlineFresh, rootBudget,
                    active, running, monitorInterruptDelivered,
                    linuxTimerAsRoot, linuxReportedAsRoot, nohzStopped,
                    protectionClaim, accepted, failClosed>>

NoHzStopsLinuxTickOnly ==
    /\ phase \in {"Activated", "Running"}
    /\ running
    /\ monitorTimerArmed
    /\ nohzStopped' = TRUE
    /\ linuxTimerArmed' = FALSE
    /\ phase' = "Running"
    /\ UNCHANGED <<runTokenSealed, domainEpochFresh, monitorOwnsTimer,
                    monitorTimerArmed, monitorDeadlineFresh, rootBudget,
                    active, running, monitorInterruptDelivered,
                    linuxReportedCharge, linuxTimerAsRoot, linuxReportedAsRoot,
                    protectionClaim, accepted, failClosed>>

RunOneBudgetUnit ==
    /\ phase \in {"Activated", "Running"}
    /\ running
    /\ monitorTimerArmed
    /\ monitorOwnsTimer
    /\ rootBudget = 2
    /\ rootBudget' = 1
    /\ phase' = "Running"
    /\ UNCHANGED <<runTokenSealed, domainEpochFresh, monitorOwnsTimer,
                    monitorTimerArmed, monitorDeadlineFresh, active, running,
                    monitorInterruptDelivered, linuxTimerArmed,
                    linuxReportedCharge, linuxTimerAsRoot, linuxReportedAsRoot,
                    nohzStopped, protectionClaim, accepted, failClosed>>

MonitorTimerExpires ==
    /\ phase \in {"Activated", "Running"}
    /\ running
    /\ monitorTimerArmed
    /\ monitorOwnsTimer
    /\ rootBudget = 1
    /\ rootBudget' = 0
    /\ running' = FALSE
    /\ active' = FALSE
    /\ monitorInterruptDelivered' = TRUE
    /\ failClosed' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<runTokenSealed, domainEpochFresh, monitorOwnsTimer,
                    monitorTimerArmed, monitorDeadlineFresh, linuxTimerArmed,
                    linuxReportedCharge, linuxTimerAsRoot, linuxReportedAsRoot,
                    nohzStopped, protectionClaim, accepted>>

VoluntarySwitchBeforeExpiry ==
    /\ phase \in {"Activated", "Running"}
    /\ running
    /\ rootBudget > 0
    /\ running' = FALSE
    /\ active' = FALSE
    /\ monitorTimerArmed' = FALSE
    /\ accepted' = TRUE
    /\ phase' = "Accepted"
    /\ UNCHANGED <<runTokenSealed, domainEpochFresh, monitorOwnsTimer,
                    monitorDeadlineFresh, rootBudget, monitorInterruptDelivered,
                    linuxTimerArmed, linuxReportedCharge, linuxTimerAsRoot,
                    linuxReportedAsRoot, nohzStopped, protectionClaim,
                    failClosed>>

EpochRevokeStops ==
    /\ phase \in {"Activated", "Running"}
    /\ running
    /\ domainEpochFresh' = FALSE
    /\ running' = FALSE
    /\ active' = FALSE
    /\ monitorInterruptDelivered' = TRUE
    /\ failClosed' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<runTokenSealed, monitorOwnsTimer, monitorTimerArmed,
                    monitorDeadlineFresh, rootBudget, linuxTimerArmed,
                    linuxReportedCharge, linuxTimerAsRoot, linuxReportedAsRoot,
                    nohzStopped, protectionClaim, accepted>>

TerminalStutter ==
    /\ phase \in {"Accepted", "FailClosed"}
    /\ UNCHANGED vars

UnsafeRunWithoutTimer ==
    /\ phase = "TokenValidated"
    /\ active' = TRUE
    /\ running' = TRUE
    /\ monitorTimerArmed' = FALSE
    /\ phase' = "BadNoTimer"
    /\ UNCHANGED <<runTokenSealed, domainEpochFresh, monitorOwnsTimer,
                    monitorDeadlineFresh, rootBudget, monitorInterruptDelivered,
                    linuxTimerArmed, linuxReportedCharge, linuxTimerAsRoot,
                    linuxReportedAsRoot, nohzStopped, protectionClaim,
                    accepted, failClosed>>

UnsafeRunWithoutBudget ==
    /\ phase = "Start"
    /\ runTokenSealed' = TRUE
    /\ domainEpochFresh' = TRUE
    /\ monitorOwnsTimer' = TRUE
    /\ monitorTimerArmed' = TRUE
    /\ monitorDeadlineFresh' = TRUE
    /\ rootBudget' = 0
    /\ active' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadNoBudget"
    /\ UNCHANGED <<monitorInterruptDelivered, linuxTimerArmed,
                    linuxReportedCharge, linuxTimerAsRoot, linuxReportedAsRoot,
                    nohzStopped, protectionClaim, accepted, failClosed>>

UnsafeLinuxTimerRoot ==
    /\ phase = "Start"
    /\ linuxTimerArmed' = TRUE
    /\ linuxTimerAsRoot' = TRUE
    /\ accepted' = TRUE
    /\ phase' = "BadLinuxTimerRoot"
    /\ UNCHANGED <<runTokenSealed, domainEpochFresh, monitorOwnsTimer,
                    monitorTimerArmed, monitorDeadlineFresh, rootBudget,
                    active, running, monitorInterruptDelivered,
                    linuxReportedCharge, linuxReportedAsRoot, nohzStopped,
                    protectionClaim, failClosed>>

UnsafeOverrunAfterExpiry ==
    /\ phase = "Running"
    /\ rootBudget = 1
    /\ rootBudget' = 0
    /\ running' = TRUE
    /\ active' = TRUE
    /\ monitorInterruptDelivered' = TRUE
    /\ phase' = "BadOverrunAfterExpiry"
    /\ UNCHANGED <<runTokenSealed, domainEpochFresh, monitorOwnsTimer,
                    monitorTimerArmed, monitorDeadlineFresh, linuxTimerArmed,
                    linuxReportedCharge, linuxTimerAsRoot, linuxReportedAsRoot,
                    nohzStopped, protectionClaim, accepted, failClosed>>

UnsafeLinuxChargeRoot ==
    /\ phase = "Start"
    /\ linuxReportedCharge' = TRUE
    /\ linuxReportedAsRoot' = TRUE
    /\ accepted' = TRUE
    /\ phase' = "BadLinuxChargeRoot"
    /\ UNCHANGED <<runTokenSealed, domainEpochFresh, monitorOwnsTimer,
                    monitorTimerArmed, monitorDeadlineFresh, rootBudget,
                    active, running, monitorInterruptDelivered,
                    linuxTimerArmed, linuxTimerAsRoot, nohzStopped,
                    protectionClaim, failClosed>>

UnsafeUnsealedActivation ==
    /\ phase = "Start"
    /\ domainEpochFresh' = TRUE
    /\ monitorOwnsTimer' = TRUE
    /\ monitorTimerArmed' = TRUE
    /\ monitorDeadlineFresh' = TRUE
    /\ rootBudget' = 1
    /\ active' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadUnsealedToken"
    /\ UNCHANGED <<runTokenSealed, monitorInterruptDelivered, linuxTimerArmed,
                    linuxReportedCharge, linuxTimerAsRoot, linuxReportedAsRoot,
                    nohzStopped, protectionClaim, accepted, failClosed>>

UnsafeEpochRevokedRun ==
    /\ phase = "TokenValidated"
    /\ domainEpochFresh' = FALSE
    /\ monitorTimerArmed' = TRUE
    /\ monitorDeadlineFresh' = TRUE
    /\ active' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadEpochRevokedRun"
    /\ UNCHANGED <<runTokenSealed, monitorOwnsTimer, rootBudget,
                    monitorInterruptDelivered, linuxTimerArmed,
                    linuxReportedCharge, linuxTimerAsRoot, linuxReportedAsRoot,
                    nohzStopped, protectionClaim, accepted, failClosed>>

UnsafeRunAfterInterrupt ==
    /\ phase = "Running"
    /\ monitorInterruptDelivered' = TRUE
    /\ running' = TRUE
    /\ active' = TRUE
    /\ phase' = "BadRunAfterInterrupt"
    /\ UNCHANGED <<runTokenSealed, domainEpochFresh, monitorOwnsTimer,
                    monitorTimerArmed, monitorDeadlineFresh, rootBudget,
                    linuxTimerArmed, linuxReportedCharge, linuxTimerAsRoot,
                    linuxReportedAsRoot, nohzStopped, protectionClaim,
                    accepted, failClosed>>

UnsafeNoHzStopsMonitor ==
    /\ phase = "Activated"
    /\ nohzStopped' = TRUE
    /\ monitorTimerArmed' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadNoHzStopsMonitor"
    /\ UNCHANGED <<runTokenSealed, domainEpochFresh, monitorOwnsTimer,
                    monitorDeadlineFresh, rootBudget, active,
                    monitorInterruptDelivered, linuxTimerArmed,
                    linuxReportedCharge, linuxTimerAsRoot, linuxReportedAsRoot,
                    protectionClaim, accepted, failClosed>>

UnsafeProtectionClaim ==
    /\ phase = "Start"
    /\ protectionClaim' = TRUE
    /\ accepted' = TRUE
    /\ phase' = "BadProtectionClaim"
    /\ UNCHANGED <<runTokenSealed, domainEpochFresh, monitorOwnsTimer,
                    monitorTimerArmed, monitorDeadlineFresh, rootBudget,
                    active, running, monitorInterruptDelivered,
                    linuxTimerArmed, linuxReportedCharge, linuxTimerAsRoot,
                    linuxReportedAsRoot, nohzStopped, failClosed>>

SafeNext ==
    \/ ValidateTokenAndBudget
    \/ ActivateWithMonitorTimer
    \/ LinuxEarlyTimerObservation
    \/ NoHzStopsLinuxTickOnly
    \/ RunOneBudgetUnit
    \/ MonitorTimerExpires
    \/ VoluntarySwitchBeforeExpiry
    \/ EpochRevokeStops
    \/ TerminalStutter

UnsafeNoTimerSpec ==
    Init /\ [][SafeNext \/ UnsafeRunWithoutTimer]_vars

UnsafeNoBudgetSpec ==
    Init /\ [][SafeNext \/ UnsafeRunWithoutBudget]_vars

UnsafeLinuxTimerRootSpec ==
    Init /\ [][SafeNext \/ UnsafeLinuxTimerRoot]_vars

UnsafeOverrunSpec ==
    Init /\ [][SafeNext \/ UnsafeOverrunAfterExpiry]_vars

UnsafeLinuxChargeRootSpec ==
    Init /\ [][SafeNext \/ UnsafeLinuxChargeRoot]_vars

UnsafeUnsealedTokenSpec ==
    Init /\ [][SafeNext \/ UnsafeUnsealedActivation]_vars

UnsafeEpochRevokedSpec ==
    Init /\ [][SafeNext \/ UnsafeEpochRevokedRun]_vars

UnsafeRunAfterInterruptSpec ==
    Init /\ [][SafeNext \/ UnsafeRunAfterInterrupt]_vars

UnsafeNoHzStopsMonitorSpec ==
    Init /\ [][SafeNext \/ UnsafeNoHzStopsMonitor]_vars

UnsafeProtectionClaimSpec ==
    Init /\ [][SafeNext \/ UnsafeProtectionClaim]_vars

SafeSpec ==
    Init /\ [][SafeNext]_vars

NoRunWithoutMonitorTimer ==
    running =>
        /\ monitorOwnsTimer
        /\ monitorTimerArmed
        /\ monitorDeadlineFresh

NoRunWithoutRootBudget ==
    running => rootBudget > 0

NoLinuxTimerAsRootAuthority ==
    accepted => ~linuxTimerAsRoot

NoOverrunAfterExpiry ==
    rootBudget = 0 => ~running

NoLinuxChargeAsMonitorCharge ==
    accepted => ~linuxReportedAsRoot

NoActivationWithoutSealedToken ==
    active =>
        /\ runTokenSealed
        /\ domainEpochFresh

NoEpochRevokedRunning ==
    ~domainEpochFresh => ~running

NoRunAfterMonitorInterrupt ==
    monitorInterruptDelivered => ~running

NoNoHzStopsMonitorTimer ==
    (running /\ nohzStopped) => monitorTimerArmed

NoProtectionClaim ==
    ~protectionClaim

NoFailClosedAccepted ==
    failClosed => ~accepted

=============================================================================
