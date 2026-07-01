---------------------- MODULE DeadlineCbsGrubCompat ----------------------
EXTENDS Naturals

VARIABLES
    phase,
    capschedRunUse,
    monitorRootBudget,
    dlParamsValid,
    dlAdmissionOk,
    dlRuntimeAvailable,
    cbsThrottled,
    grubReclaimActive,
    inactiveTimerActive,
    linuxAdmissionAuthority,
    cbsReplenishAuthority,
    grubBudgetAuthority,
    dlRuntimeBudgetAuthority,
    inactiveTimerAuthority,
    dynamicGetattrAuthority,
    overrunNotificationAuthority,
    running,
    failClosed,
    protectionClaim

vars == <<phase, capschedRunUse, monitorRootBudget, dlParamsValid,
          dlAdmissionOk, dlRuntimeAvailable, cbsThrottled,
          grubReclaimActive, inactiveTimerActive, linuxAdmissionAuthority,
          cbsReplenishAuthority, grubBudgetAuthority, dlRuntimeBudgetAuthority,
          inactiveTimerAuthority, dynamicGetattrAuthority,
          overrunNotificationAuthority, running, failClosed,
          protectionClaim>>

Phases == {
    "Start",
    "CapReady",
    "DLValidated",
    "DLAdmitted",
    "Enqueued",
    "Running",
    "BlockedByCBS",
    "CompatObserved",
    "FailClosed",
    "BadAdmissionAuthority",
    "BadCBSReplenishAuthority",
    "BadGRUBBudget",
    "BadDLRuntimeBudget",
    "BadInactiveTimerAuthority",
    "BadDynamicGetattrAuthority",
    "BadOverrunNotification",
    "BadNoDLAdmission",
    "BadCBSThrottledRun",
    "BadProtectionClaim"
}

TypeOK ==
    /\ phase \in Phases
    /\ capschedRunUse \in BOOLEAN
    /\ monitorRootBudget \in BOOLEAN
    /\ dlParamsValid \in BOOLEAN
    /\ dlAdmissionOk \in BOOLEAN
    /\ dlRuntimeAvailable \in BOOLEAN
    /\ cbsThrottled \in BOOLEAN
    /\ grubReclaimActive \in BOOLEAN
    /\ inactiveTimerActive \in BOOLEAN
    /\ linuxAdmissionAuthority \in BOOLEAN
    /\ cbsReplenishAuthority \in BOOLEAN
    /\ grubBudgetAuthority \in BOOLEAN
    /\ dlRuntimeBudgetAuthority \in BOOLEAN
    /\ inactiveTimerAuthority \in BOOLEAN
    /\ dynamicGetattrAuthority \in BOOLEAN
    /\ overrunNotificationAuthority \in BOOLEAN
    /\ running \in BOOLEAN
    /\ failClosed \in BOOLEAN
    /\ protectionClaim \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ capschedRunUse = FALSE
    /\ monitorRootBudget = FALSE
    /\ dlParamsValid = FALSE
    /\ dlAdmissionOk = FALSE
    /\ dlRuntimeAvailable = FALSE
    /\ cbsThrottled = FALSE
    /\ grubReclaimActive = FALSE
    /\ inactiveTimerActive = FALSE
    /\ linuxAdmissionAuthority = FALSE
    /\ cbsReplenishAuthority = FALSE
    /\ grubBudgetAuthority = FALSE
    /\ dlRuntimeBudgetAuthority = FALSE
    /\ inactiveTimerAuthority = FALSE
    /\ dynamicGetattrAuthority = FALSE
    /\ overrunNotificationAuthority = FALSE
    /\ running = FALSE
    /\ failClosed = FALSE
    /\ protectionClaim = FALSE

PrepareCapSched ==
    /\ phase = "Start"
    /\ capschedRunUse' = TRUE
    /\ monitorRootBudget' = TRUE
    /\ phase' = "CapReady"
    /\ UNCHANGED <<dlParamsValid, dlAdmissionOk, dlRuntimeAvailable,
                    cbsThrottled, grubReclaimActive, inactiveTimerActive,
                    linuxAdmissionAuthority, cbsReplenishAuthority,
                    grubBudgetAuthority, dlRuntimeBudgetAuthority,
                    inactiveTimerAuthority, dynamicGetattrAuthority,
                    overrunNotificationAuthority, running, failClosed,
                    protectionClaim>>

ValidateDLParams ==
    /\ phase = "CapReady"
    /\ dlParamsValid' = TRUE
    /\ phase' = "DLValidated"
    /\ UNCHANGED <<capschedRunUse, monitorRootBudget, dlAdmissionOk,
                    dlRuntimeAvailable, cbsThrottled, grubReclaimActive,
                    inactiveTimerActive, linuxAdmissionAuthority,
                    cbsReplenishAuthority, grubBudgetAuthority,
                    dlRuntimeBudgetAuthority, inactiveTimerAuthority,
                    dynamicGetattrAuthority, overrunNotificationAuthority,
                    running, failClosed, protectionClaim>>

AdmitDeadline ==
    /\ phase = "DLValidated"
    /\ dlParamsValid
    /\ dlAdmissionOk' = TRUE
    /\ dlRuntimeAvailable' = TRUE
    /\ cbsThrottled' = FALSE
    /\ phase' = "DLAdmitted"
    /\ UNCHANGED <<capschedRunUse, monitorRootBudget, dlParamsValid,
                    grubReclaimActive, inactiveTimerActive,
                    linuxAdmissionAuthority, cbsReplenishAuthority,
                    grubBudgetAuthority, dlRuntimeBudgetAuthority,
                    inactiveTimerAuthority, dynamicGetattrAuthority,
                    overrunNotificationAuthority, running, failClosed,
                    protectionClaim>>

ObserveGRUB ==
    /\ phase \in {"DLAdmitted", "Enqueued", "Running"}
    /\ grubReclaimActive' = TRUE
    /\ phase' = "CompatObserved"
    /\ UNCHANGED <<capschedRunUse, monitorRootBudget, dlParamsValid,
                    dlAdmissionOk, dlRuntimeAvailable, cbsThrottled,
                    inactiveTimerActive, linuxAdmissionAuthority,
                    cbsReplenishAuthority, grubBudgetAuthority,
                    dlRuntimeBudgetAuthority, inactiveTimerAuthority,
                    dynamicGetattrAuthority, overrunNotificationAuthority,
                    running, failClosed, protectionClaim>>

ObserveInactiveTimer ==
    /\ phase \in {"DLAdmitted", "Enqueued", "Running", "BlockedByCBS"}
    /\ inactiveTimerActive' = TRUE
    /\ phase' = "CompatObserved"
    /\ UNCHANGED <<capschedRunUse, monitorRootBudget, dlParamsValid,
                    dlAdmissionOk, dlRuntimeAvailable, cbsThrottled,
                    grubReclaimActive, linuxAdmissionAuthority,
                    cbsReplenishAuthority, grubBudgetAuthority,
                    dlRuntimeBudgetAuthority, inactiveTimerAuthority,
                    dynamicGetattrAuthority, overrunNotificationAuthority,
                    running, failClosed, protectionClaim>>

EnqueueWithDL ==
    /\ phase \in {"DLAdmitted", "CompatObserved"}
    /\ capschedRunUse
    /\ monitorRootBudget
    /\ dlParamsValid
    /\ dlAdmissionOk
    /\ dlRuntimeAvailable
    /\ ~cbsThrottled
    /\ running' = FALSE
    /\ phase' = "Enqueued"
    /\ UNCHANGED <<capschedRunUse, monitorRootBudget, dlParamsValid,
                    dlAdmissionOk, dlRuntimeAvailable, cbsThrottled,
                    grubReclaimActive, inactiveTimerActive,
                    linuxAdmissionAuthority, cbsReplenishAuthority,
                    grubBudgetAuthority, dlRuntimeBudgetAuthority,
                    inactiveTimerAuthority, dynamicGetattrAuthority,
                    overrunNotificationAuthority, failClosed,
                    protectionClaim>>

RunWithCapSchedAndDL ==
    /\ phase = "Enqueued"
    /\ capschedRunUse
    /\ monitorRootBudget
    /\ dlParamsValid
    /\ dlAdmissionOk
    /\ dlRuntimeAvailable
    /\ ~cbsThrottled
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<capschedRunUse, monitorRootBudget, dlParamsValid,
                    dlAdmissionOk, dlRuntimeAvailable, cbsThrottled,
                    grubReclaimActive, inactiveTimerActive,
                    linuxAdmissionAuthority, cbsReplenishAuthority,
                    grubBudgetAuthority, dlRuntimeBudgetAuthority,
                    inactiveTimerAuthority, dynamicGetattrAuthority,
                    overrunNotificationAuthority, failClosed,
                    protectionClaim>>

CBSThrottleStops ==
    /\ phase \in {"Enqueued", "Running"}
    /\ dlRuntimeAvailable' = FALSE
    /\ cbsThrottled' = TRUE
    /\ running' = FALSE
    /\ failClosed' = TRUE
    /\ phase' = "BlockedByCBS"
    /\ UNCHANGED <<capschedRunUse, monitorRootBudget, dlParamsValid,
                    dlAdmissionOk, grubReclaimActive, inactiveTimerActive,
                    linuxAdmissionAuthority, cbsReplenishAuthority,
                    grubBudgetAuthority, dlRuntimeBudgetAuthority,
                    inactiveTimerAuthority, dynamicGetattrAuthority,
                    overrunNotificationAuthority, protectionClaim>>

CBSReplenishRestoresDLOnly ==
    /\ phase = "BlockedByCBS"
    /\ capschedRunUse
    /\ dlAdmissionOk
    /\ dlRuntimeAvailable' = TRUE
    /\ cbsThrottled' = FALSE
    /\ running' = FALSE
    /\ failClosed' = FALSE
    /\ phase' = "DLAdmitted"
    /\ UNCHANGED <<capschedRunUse, monitorRootBudget, dlParamsValid,
                    dlAdmissionOk, grubReclaimActive, inactiveTimerActive,
                    linuxAdmissionAuthority, cbsReplenishAuthority,
                    grubBudgetAuthority, dlRuntimeBudgetAuthority,
                    inactiveTimerAuthority, dynamicGetattrAuthority,
                    overrunNotificationAuthority, protectionClaim>>

TerminalStutter ==
    /\ phase \in {"Running", "CompatObserved"}
    /\ UNCHANGED vars

UnsafeAdmissionMintsRun ==
    /\ phase = "DLValidated"
    /\ capschedRunUse' = FALSE
    /\ dlAdmissionOk' = TRUE
    /\ dlRuntimeAvailable' = TRUE
    /\ linuxAdmissionAuthority' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadAdmissionAuthority"
    /\ UNCHANGED <<monitorRootBudget, dlParamsValid, cbsThrottled,
                    grubReclaimActive, inactiveTimerActive,
                    cbsReplenishAuthority, grubBudgetAuthority,
                    dlRuntimeBudgetAuthority, inactiveTimerAuthority,
                    dynamicGetattrAuthority, overrunNotificationAuthority,
                    failClosed, protectionClaim>>

UnsafeCBSReplenishMintsRun ==
    /\ phase = "BlockedByCBS"
    /\ capschedRunUse' = FALSE
    /\ cbsReplenishAuthority' = TRUE
    /\ dlRuntimeAvailable' = TRUE
    /\ cbsThrottled' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadCBSReplenishAuthority"
    /\ UNCHANGED <<monitorRootBudget, dlParamsValid, dlAdmissionOk,
                    grubReclaimActive, inactiveTimerActive,
                    linuxAdmissionAuthority, grubBudgetAuthority,
                    dlRuntimeBudgetAuthority, inactiveTimerAuthority,
                    dynamicGetattrAuthority, overrunNotificationAuthority,
                    failClosed, protectionClaim>>

UnsafeGRUBMintsBudget ==
    /\ phase \in {"DLAdmitted", "Enqueued"}
    /\ monitorRootBudget' = TRUE
    /\ grubReclaimActive' = TRUE
    /\ grubBudgetAuthority' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadGRUBBudget"
    /\ UNCHANGED <<capschedRunUse, dlParamsValid, dlAdmissionOk,
                    dlRuntimeAvailable, cbsThrottled, inactiveTimerActive,
                    linuxAdmissionAuthority, cbsReplenishAuthority,
                    dlRuntimeBudgetAuthority, inactiveTimerAuthority,
                    dynamicGetattrAuthority, overrunNotificationAuthority,
                    failClosed, protectionClaim>>

UnsafeDLRuntimeAsBudget ==
    /\ phase \in {"DLAdmitted", "Enqueued"}
    /\ dlRuntimeAvailable
    /\ monitorRootBudget' = FALSE
    /\ dlRuntimeBudgetAuthority' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadDLRuntimeBudget"
    /\ UNCHANGED <<capschedRunUse, dlParamsValid, dlAdmissionOk,
                    dlRuntimeAvailable, cbsThrottled, grubReclaimActive,
                    inactiveTimerActive, linuxAdmissionAuthority,
                    cbsReplenishAuthority, grubBudgetAuthority,
                    inactiveTimerAuthority, dynamicGetattrAuthority,
                    overrunNotificationAuthority, failClosed,
                    protectionClaim>>

UnsafeInactiveTimerAuthority ==
    /\ phase \in {"DLAdmitted", "BlockedByCBS", "CompatObserved"}
    /\ capschedRunUse' = FALSE
    /\ inactiveTimerActive' = TRUE
    /\ inactiveTimerAuthority' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadInactiveTimerAuthority"
    /\ UNCHANGED <<monitorRootBudget, dlParamsValid, dlAdmissionOk,
                    dlRuntimeAvailable, cbsThrottled, grubReclaimActive,
                    linuxAdmissionAuthority, cbsReplenishAuthority,
                    grubBudgetAuthority, dlRuntimeBudgetAuthority,
                    dynamicGetattrAuthority, overrunNotificationAuthority,
                    failClosed, protectionClaim>>

UnsafeDynamicGetattrAuthority ==
    /\ phase \in {"DLAdmitted", "Enqueued", "Running"}
    /\ dynamicGetattrAuthority' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadDynamicGetattrAuthority"
    /\ UNCHANGED <<capschedRunUse, monitorRootBudget, dlParamsValid,
                    dlAdmissionOk, dlRuntimeAvailable, cbsThrottled,
                    grubReclaimActive, inactiveTimerActive,
                    linuxAdmissionAuthority, cbsReplenishAuthority,
                    grubBudgetAuthority, dlRuntimeBudgetAuthority,
                    inactiveTimerAuthority, overrunNotificationAuthority,
                    failClosed, protectionClaim>>

UnsafeOverrunNotification ==
    /\ phase \in {"DLAdmitted", "Enqueued", "Running"}
    /\ overrunNotificationAuthority' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadOverrunNotification"
    /\ UNCHANGED <<capschedRunUse, monitorRootBudget, dlParamsValid,
                    dlAdmissionOk, dlRuntimeAvailable, cbsThrottled,
                    grubReclaimActive, inactiveTimerActive,
                    linuxAdmissionAuthority, cbsReplenishAuthority,
                    grubBudgetAuthority, dlRuntimeBudgetAuthority,
                    inactiveTimerAuthority, dynamicGetattrAuthority,
                    failClosed, protectionClaim>>

UnsafeRunWithoutDLAdmission ==
    /\ phase = "CapReady"
    /\ dlParamsValid' = FALSE
    /\ dlAdmissionOk' = FALSE
    /\ dlRuntimeAvailable' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadNoDLAdmission"
    /\ UNCHANGED <<capschedRunUse, monitorRootBudget, cbsThrottled,
                    grubReclaimActive, inactiveTimerActive,
                    linuxAdmissionAuthority, cbsReplenishAuthority,
                    grubBudgetAuthority, dlRuntimeBudgetAuthority,
                    inactiveTimerAuthority, dynamicGetattrAuthority,
                    overrunNotificationAuthority, failClosed,
                    protectionClaim>>

UnsafeRunWhileCBSThrottled ==
    /\ phase \in {"DLAdmitted", "Enqueued", "BlockedByCBS"}
    /\ dlRuntimeAvailable' = FALSE
    /\ cbsThrottled' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadCBSThrottledRun"
    /\ UNCHANGED <<capschedRunUse, monitorRootBudget, dlParamsValid,
                    dlAdmissionOk, grubReclaimActive, inactiveTimerActive,
                    linuxAdmissionAuthority, cbsReplenishAuthority,
                    grubBudgetAuthority, dlRuntimeBudgetAuthority,
                    inactiveTimerAuthority, dynamicGetattrAuthority,
                    overrunNotificationAuthority, failClosed,
                    protectionClaim>>

UnsafeProtectionClaim ==
    /\ phase = "Running"
    /\ protectionClaim' = TRUE
    /\ phase' = "BadProtectionClaim"
    /\ UNCHANGED <<capschedRunUse, monitorRootBudget, dlParamsValid,
                    dlAdmissionOk, dlRuntimeAvailable, cbsThrottled,
                    grubReclaimActive, inactiveTimerActive,
                    linuxAdmissionAuthority, cbsReplenishAuthority,
                    grubBudgetAuthority, dlRuntimeBudgetAuthority,
                    inactiveTimerAuthority, dynamicGetattrAuthority,
                    overrunNotificationAuthority, running, failClosed>>

SafeNext ==
    \/ PrepareCapSched
    \/ ValidateDLParams
    \/ AdmitDeadline
    \/ ObserveGRUB
    \/ ObserveInactiveTimer
    \/ EnqueueWithDL
    \/ RunWithCapSchedAndDL
    \/ CBSThrottleStops
    \/ CBSReplenishRestoresDLOnly
    \/ TerminalStutter

SafeSpec == Init /\ [][SafeNext]_vars

SpecUnsafeAdmissionMintsRun ==
    Init /\ [][SafeNext \/ UnsafeAdmissionMintsRun]_vars

SpecUnsafeCBSReplenishMintsRun ==
    Init /\ [][SafeNext \/ UnsafeCBSReplenishMintsRun]_vars

SpecUnsafeGRUBMintsBudget ==
    Init /\ [][SafeNext \/ UnsafeGRUBMintsBudget]_vars

SpecUnsafeDLRuntimeAsBudget ==
    Init /\ [][SafeNext \/ UnsafeDLRuntimeAsBudget]_vars

SpecUnsafeInactiveTimerAuthority ==
    Init /\ [][SafeNext \/ UnsafeInactiveTimerAuthority]_vars

SpecUnsafeDynamicGetattrAuthority ==
    Init /\ [][SafeNext \/ UnsafeDynamicGetattrAuthority]_vars

SpecUnsafeOverrunNotification ==
    Init /\ [][SafeNext \/ UnsafeOverrunNotification]_vars

SpecUnsafeRunWithoutDLAdmission ==
    Init /\ [][SafeNext \/ UnsafeRunWithoutDLAdmission]_vars

SpecUnsafeRunWhileCBSThrottled ==
    Init /\ [][SafeNext \/ UnsafeRunWhileCBSThrottled]_vars

SpecUnsafeProtectionClaim ==
    Init /\ [][SafeNext \/ UnsafeProtectionClaim]_vars

NoRunWithoutCapSchedRunUse ==
    running => capschedRunUse

NoRunWithoutMonitorRootBudget ==
    running => monitorRootBudget

NoRunWithoutDLAdmission ==
    running => /\ dlParamsValid
               /\ dlAdmissionOk

NoRunWithoutCBSRuntime ==
    running => /\ dlRuntimeAvailable
               /\ ~cbsThrottled

NoLinuxAdmissionAsAuthority ==
    ~linuxAdmissionAuthority

NoCBSReplenishAsAuthority ==
    ~cbsReplenishAuthority

NoGRUBAsMonitorBudget ==
    ~grubBudgetAuthority

NoDLRuntimeAsMonitorBudget ==
    ~dlRuntimeBudgetAuthority

NoInactiveTimerAsAuthority ==
    ~inactiveTimerAuthority

NoDynamicGetattrAsAuthority ==
    ~dynamicGetattrAuthority

NoOverrunNotificationAsEnforcement ==
    ~overrunNotificationAuthority

NoFailClosedRunning ==
    failClosed => ~running

NoProtectionClaim ==
    ~protectionClaim

=============================================================================
