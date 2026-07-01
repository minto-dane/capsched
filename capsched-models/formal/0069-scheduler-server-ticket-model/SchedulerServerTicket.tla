---------------------- MODULE SchedulerServerTicket ----------------------
EXTENDS Naturals

VARIABLES
    phase,
    serverKind,
    taskAuthority,
    serverStarted,
    serverTicket,
    serverEpochFresh,
    monitorRootBudget,
    serverRuntime,
    classRuntime,
    scxSlice,
    rtBandwidth,
    pickedLowerTask,
    running,
    failClosed

vars == <<phase, serverKind, taskAuthority, serverStarted, serverTicket,
          serverEpochFresh, monitorRootBudget, serverRuntime, classRuntime,
          scxSlice, rtBandwidth, pickedLowerTask, running, failClosed>>

ServerKinds == {
    "None",
    "FairServer",
    "ExtServer",
    "DlServer",
    "RtBandwidth",
    "ScxSlice"
}

Phases == {
    "Start",
    "Prepared",
    "ServerStarted",
    "TicketIssued",
    "Picked",
    "Running",
    "FailClosed",
    "BadPickNoTicket",
    "BadServerRuntimeAuthority",
    "BadRtBandwidthAuthority",
    "BadScxSliceAuthority",
    "BadReplenishNoEpoch",
    "BadStopWithLiveTicket",
    "BadLowerTaskNoAuthority"
}

TypeOK ==
    /\ phase \in Phases
    /\ serverKind \in ServerKinds
    /\ taskAuthority \in BOOLEAN
    /\ serverStarted \in BOOLEAN
    /\ serverTicket \in BOOLEAN
    /\ serverEpochFresh \in BOOLEAN
    /\ monitorRootBudget \in BOOLEAN
    /\ serverRuntime \in BOOLEAN
    /\ classRuntime \in BOOLEAN
    /\ scxSlice \in BOOLEAN
    /\ rtBandwidth \in BOOLEAN
    /\ pickedLowerTask \in BOOLEAN
    /\ running \in BOOLEAN
    /\ failClosed \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ serverKind = "None"
    /\ taskAuthority = FALSE
    /\ serverStarted = FALSE
    /\ serverTicket = FALSE
    /\ serverEpochFresh = FALSE
    /\ monitorRootBudget = FALSE
    /\ serverRuntime = FALSE
    /\ classRuntime = FALSE
    /\ scxSlice = FALSE
    /\ rtBandwidth = FALSE
    /\ pickedLowerTask = FALSE
    /\ running = FALSE
    /\ failClosed = FALSE

PrepareAuthority ==
    /\ phase = "Start"
    /\ taskAuthority' = TRUE
    /\ serverEpochFresh' = TRUE
    /\ monitorRootBudget' = TRUE
    /\ phase' = "Prepared"
    /\ UNCHANGED <<serverKind, serverStarted, serverTicket, serverRuntime,
                    classRuntime, scxSlice, rtBandwidth, pickedLowerTask,
                    running, failClosed>>

StartServer(k) ==
    /\ phase = "Prepared"
    /\ k \in {"FairServer", "ExtServer", "DlServer"}
    /\ serverKind' = k
    /\ serverStarted' = TRUE
    /\ serverRuntime' = TRUE
    /\ classRuntime' = TRUE
    /\ phase' = "ServerStarted"
    /\ UNCHANGED <<taskAuthority, serverTicket, serverEpochFresh,
                    monitorRootBudget, scxSlice, rtBandwidth,
                    pickedLowerTask, running, failClosed>>

ObserveRtBandwidth ==
    /\ phase = "Prepared"
    /\ serverKind' = "RtBandwidth"
    /\ classRuntime' = TRUE
    /\ rtBandwidth' = TRUE
    /\ phase' = "ServerStarted"
    /\ UNCHANGED <<taskAuthority, serverStarted, serverTicket,
                    serverEpochFresh, monitorRootBudget, serverRuntime,
                    scxSlice, pickedLowerTask, running, failClosed>>

ObserveScxSlice ==
    /\ phase = "Prepared"
    /\ serverKind' = "ScxSlice"
    /\ classRuntime' = TRUE
    /\ scxSlice' = TRUE
    /\ phase' = "ServerStarted"
    /\ UNCHANGED <<taskAuthority, serverStarted, serverTicket,
                    serverEpochFresh, monitorRootBudget, serverRuntime,
                    rtBandwidth, pickedLowerTask, running, failClosed>>

IssueServerTicket ==
    /\ phase = "ServerStarted"
    /\ serverKind \in {"FairServer", "ExtServer", "DlServer"}
    /\ taskAuthority
    /\ serverStarted
    /\ serverRuntime
    /\ serverEpochFresh
    /\ monitorRootBudget
    /\ serverTicket' = TRUE
    /\ phase' = "TicketIssued"
    /\ UNCHANGED <<serverKind, taskAuthority, serverStarted,
                    serverEpochFresh, monitorRootBudget, serverRuntime,
                    classRuntime, scxSlice, rtBandwidth, pickedLowerTask,
                    running, failClosed>>

PickLowerTask ==
    /\ phase = "TicketIssued"
    /\ serverTicket
    /\ taskAuthority
    /\ serverEpochFresh
    /\ monitorRootBudget
    /\ pickedLowerTask' = TRUE
    /\ phase' = "Picked"
    /\ UNCHANGED <<serverKind, taskAuthority, serverStarted, serverTicket,
                    serverEpochFresh, monitorRootBudget, serverRuntime,
                    classRuntime, scxSlice, rtBandwidth, running, failClosed>>

RunWithServerTicket ==
    /\ phase = "Picked"
    /\ pickedLowerTask
    /\ taskAuthority
    /\ serverTicket
    /\ serverEpochFresh
    /\ monitorRootBudget
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<serverKind, taskAuthority, serverStarted, serverTicket,
                    serverEpochFresh, monitorRootBudget, serverRuntime,
                    classRuntime, scxSlice, rtBandwidth, pickedLowerTask,
                    failClosed>>

ServerStopCloses ==
    /\ phase \in {"ServerStarted", "TicketIssued", "Picked", "Running"}
    /\ serverStarted' = FALSE
    /\ serverTicket' = FALSE
    /\ pickedLowerTask' = FALSE
    /\ running' = FALSE
    /\ failClosed' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<serverKind, taskAuthority, serverEpochFresh,
                    monitorRootBudget, serverRuntime, classRuntime, scxSlice,
                    rtBandwidth>>

ServerReplenishInvalidatesEpoch ==
    /\ phase \in {"TicketIssued", "Picked", "Running"}
    /\ serverRuntime' = TRUE
    /\ serverEpochFresh' = FALSE
    /\ serverTicket' = FALSE
    /\ pickedLowerTask' = FALSE
    /\ running' = FALSE
    /\ failClosed' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<serverKind, taskAuthority, serverStarted,
                    monitorRootBudget, classRuntime, scxSlice, rtBandwidth>>

UnsafePickNoTicket ==
    /\ phase = "ServerStarted"
    /\ serverKind \in {"FairServer", "ExtServer", "DlServer"}
    /\ serverTicket = FALSE
    /\ pickedLowerTask' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadPickNoTicket"
    /\ UNCHANGED <<serverKind, taskAuthority, serverStarted, serverTicket,
                    serverEpochFresh, monitorRootBudget, serverRuntime,
                    classRuntime, scxSlice, rtBandwidth, failClosed>>

UnsafeServerRuntimeAuthority ==
    /\ phase = "ServerStarted"
    /\ serverRuntime
    /\ monitorRootBudget' = FALSE
    /\ serverTicket' = FALSE
    /\ pickedLowerTask' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadServerRuntimeAuthority"
    /\ UNCHANGED <<serverKind, taskAuthority, serverStarted,
                    serverEpochFresh, serverRuntime, classRuntime, scxSlice,
                    rtBandwidth, failClosed>>

UnsafeRtBandwidthAuthority ==
    /\ phase = "ServerStarted"
    /\ serverKind = "RtBandwidth"
    /\ rtBandwidth
    /\ monitorRootBudget' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadRtBandwidthAuthority"
    /\ UNCHANGED <<serverKind, taskAuthority, serverStarted, serverTicket,
                    serverEpochFresh, serverRuntime, classRuntime, scxSlice,
                    rtBandwidth, pickedLowerTask, failClosed>>

UnsafeScxSliceAuthority ==
    /\ phase = "ServerStarted"
    /\ serverKind = "ScxSlice"
    /\ scxSlice
    /\ monitorRootBudget' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadScxSliceAuthority"
    /\ UNCHANGED <<serverKind, taskAuthority, serverStarted, serverTicket,
                    serverEpochFresh, serverRuntime, classRuntime, scxSlice,
                    rtBandwidth, pickedLowerTask, failClosed>>

UnsafeReplenishNoEpoch ==
    /\ phase = "Picked"
    /\ pickedLowerTask
    /\ serverRuntime' = TRUE
    /\ serverEpochFresh' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadReplenishNoEpoch"
    /\ UNCHANGED <<serverKind, taskAuthority, serverStarted, serverTicket,
                    monitorRootBudget, classRuntime, scxSlice, rtBandwidth,
                    pickedLowerTask, failClosed>>

UnsafeStopWithLiveTicket ==
    /\ phase = "Picked"
    /\ pickedLowerTask
    /\ serverStarted' = FALSE
    /\ serverTicket' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadStopWithLiveTicket"
    /\ UNCHANGED <<serverKind, taskAuthority, serverEpochFresh,
                    monitorRootBudget, serverRuntime, classRuntime, scxSlice,
                    rtBandwidth, pickedLowerTask, failClosed>>

UnsafeLowerTaskNoAuthority ==
    /\ phase = "TicketIssued"
    /\ taskAuthority' = FALSE
    /\ pickedLowerTask' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadLowerTaskNoAuthority"
    /\ UNCHANGED <<serverKind, serverStarted, serverTicket, serverEpochFresh,
                    monitorRootBudget, serverRuntime, classRuntime, scxSlice,
                    rtBandwidth, failClosed>>

SafeNext ==
    \/ PrepareAuthority
    \/ \E k \in ServerKinds: StartServer(k)
    \/ ObserveRtBandwidth
    \/ ObserveScxSlice
    \/ IssueServerTicket
    \/ PickLowerTask
    \/ RunWithServerTicket
    \/ ServerStopCloses
    \/ ServerReplenishInvalidatesEpoch

UnsafePickNoTicketSpec ==
    Init /\ [][SafeNext \/ UnsafePickNoTicket]_vars

UnsafeServerRuntimeSpec ==
    Init /\ [][SafeNext \/ UnsafeServerRuntimeAuthority]_vars

UnsafeRtBandwidthSpec ==
    Init /\ [][SafeNext \/ UnsafeRtBandwidthAuthority]_vars

UnsafeScxSliceSpec ==
    Init /\ [][SafeNext \/ UnsafeScxSliceAuthority]_vars

UnsafeReplenishSpec ==
    Init /\ [][SafeNext \/ UnsafeReplenishNoEpoch]_vars

UnsafeStopSpec ==
    Init /\ [][SafeNext \/ UnsafeStopWithLiveTicket]_vars

UnsafeLowerTaskSpec ==
    Init /\ [][SafeNext \/ UnsafeLowerTaskNoAuthority]_vars

SafeSpec ==
    Init /\ [][SafeNext]_vars

NoRunWithoutTaskAuthority ==
    running => taskAuthority

NoServerBorrowWithoutTicket ==
    (running /\ serverKind \in {"FairServer", "ExtServer", "DlServer"}) =>
        serverTicket

NoServerRuntimeAsRootAuthority ==
    running => monitorRootBudget

NoRtBandwidthAsRootAuthority ==
    (running /\ serverKind = "RtBandwidth") => FALSE

NoScxSliceAsRootAuthority ==
    (running /\ serverKind = "ScxSlice") => FALSE

NoRunWithStaleServerEpoch ==
    running => serverEpochFresh

NoStoppedServerWithLiveRun ==
    running => serverStarted

NoFailClosedRunning ==
    failClosed => ~running

=============================================================================
