----------------------- MODULE ServerEpochRelation -----------------------
EXTENDS Naturals

VARIABLES
    phase,
    serverKind,
    serverActive,
    serverEpoch,
    ticketLive,
    ticketEpoch,
    ticketKind,
    lowerTaskAuthority,
    monitorRootBudget,
    serverRuntime,
    serverPicked,
    running,
    linuxRuntimeAuthority,
    failClosed,
    protectionClaim

vars == <<phase, serverKind, serverActive, serverEpoch, ticketLive,
          ticketEpoch, ticketKind, lowerTaskAuthority, monitorRootBudget,
          serverRuntime, serverPicked, running, linuxRuntimeAuthority,
          failClosed, protectionClaim>>

ServerKinds == {"None", "FairServer", "ExtServer", "DlServer"}

Epochs == 0..3

Phases == {
    "Start",
    "Prepared",
    "ServerStarted",
    "TicketIssued",
    "Picked",
    "Running",
    "FailClosed",
    "BadStaleAfterReplenish",
    "BadSwapKeepsTicket",
    "BadStopKeepsTicket",
    "BadPickNoTicket",
    "BadLowerTaskNoAuthority",
    "BadLinuxRuntimeAuthority",
    "BadParamChangeKeepsTicket",
    "BadCpuTeardownKeepsRun",
    "BadProtectionClaim"
}

TypeOK ==
    /\ phase \in Phases
    /\ serverKind \in ServerKinds
    /\ serverActive \in BOOLEAN
    /\ serverEpoch \in Epochs
    /\ ticketLive \in BOOLEAN
    /\ ticketEpoch \in Epochs
    /\ ticketKind \in ServerKinds
    /\ lowerTaskAuthority \in BOOLEAN
    /\ monitorRootBudget \in BOOLEAN
    /\ serverRuntime \in BOOLEAN
    /\ serverPicked \in BOOLEAN
    /\ running \in BOOLEAN
    /\ linuxRuntimeAuthority \in BOOLEAN
    /\ failClosed \in BOOLEAN
    /\ protectionClaim \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ serverKind = "None"
    /\ serverActive = FALSE
    /\ serverEpoch = 0
    /\ ticketLive = FALSE
    /\ ticketEpoch = 0
    /\ ticketKind = "None"
    /\ lowerTaskAuthority = FALSE
    /\ monitorRootBudget = FALSE
    /\ serverRuntime = FALSE
    /\ serverPicked = FALSE
    /\ running = FALSE
    /\ linuxRuntimeAuthority = FALSE
    /\ failClosed = FALSE
    /\ protectionClaim = FALSE

FreshTicket ==
    /\ ticketLive
    /\ ticketEpoch = serverEpoch
    /\ ticketKind = serverKind
    /\ serverActive

PrepareAuthority ==
    /\ phase = "Start"
    /\ lowerTaskAuthority' = TRUE
    /\ monitorRootBudget' = TRUE
    /\ phase' = "Prepared"
    /\ UNCHANGED <<serverKind, serverActive, serverEpoch, ticketLive,
                    ticketEpoch, ticketKind, serverRuntime, serverPicked,
                    running, linuxRuntimeAuthority, failClosed,
                    protectionClaim>>

StartServer(k) ==
    /\ phase = "Prepared"
    /\ k \in {"FairServer", "ExtServer", "DlServer"}
    /\ serverKind' = k
    /\ serverActive' = TRUE
    /\ serverEpoch' = 1
    /\ serverRuntime' = TRUE
    /\ phase' = "ServerStarted"
    /\ UNCHANGED <<ticketLive, ticketEpoch, ticketKind, lowerTaskAuthority,
                    monitorRootBudget, serverPicked, running,
                    linuxRuntimeAuthority, failClosed, protectionClaim>>

IssueTicket ==
    /\ phase = "ServerStarted"
    /\ serverActive
    /\ lowerTaskAuthority
    /\ monitorRootBudget
    /\ serverRuntime
    /\ ticketLive' = TRUE
    /\ ticketEpoch' = serverEpoch
    /\ ticketKind' = serverKind
    /\ phase' = "TicketIssued"
    /\ UNCHANGED <<serverKind, serverActive, serverEpoch,
                    lowerTaskAuthority, monitorRootBudget, serverRuntime,
                    serverPicked, running, linuxRuntimeAuthority, failClosed,
                    protectionClaim>>

PickLowerTask ==
    /\ phase = "TicketIssued"
    /\ FreshTicket
    /\ lowerTaskAuthority
    /\ monitorRootBudget
    /\ serverPicked' = TRUE
    /\ phase' = "Picked"
    /\ UNCHANGED <<serverKind, serverActive, serverEpoch, ticketLive,
                    ticketEpoch, ticketKind, lowerTaskAuthority,
                    monitorRootBudget, serverRuntime, running,
                    linuxRuntimeAuthority, failClosed, protectionClaim>>

RunLowerTask ==
    /\ phase = "Picked"
    /\ FreshTicket
    /\ lowerTaskAuthority
    /\ monitorRootBudget
    /\ serverPicked
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<serverKind, serverActive, serverEpoch, ticketLive,
                    ticketEpoch, ticketKind, lowerTaskAuthority,
                    monitorRootBudget, serverRuntime, serverPicked,
                    linuxRuntimeAuthority, failClosed, protectionClaim>>

InvalidateTicket(newEpoch) ==
    /\ newEpoch \in Epochs
    /\ serverEpoch' = newEpoch
    /\ ticketLive' = FALSE
    /\ ticketEpoch' = ticketEpoch
    /\ ticketKind' = "None"
    /\ serverPicked' = FALSE
    /\ running' = FALSE
    /\ failClosed' = TRUE

ReplenishInvalidates ==
    /\ phase \in {"ServerStarted", "TicketIssued", "Picked", "Running"}
    /\ InvalidateTicket(2)
    /\ serverRuntime' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<serverKind, serverActive, lowerTaskAuthority,
                    monitorRootBudget, linuxRuntimeAuthority, protectionClaim>>

SwapInvalidates(k) ==
    /\ phase \in {"ServerStarted", "TicketIssued", "Picked", "Running"}
    /\ k \in {"FairServer", "ExtServer", "DlServer"}
    /\ k # serverKind
    /\ InvalidateTicket(3)
    /\ serverKind' = k
    /\ serverActive' = TRUE
    /\ serverRuntime' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<lowerTaskAuthority, monitorRootBudget,
                    linuxRuntimeAuthority, protectionClaim>>

StopInvalidates ==
    /\ phase \in {"ServerStarted", "TicketIssued", "Picked", "Running"}
    /\ InvalidateTicket(3)
    /\ serverActive' = FALSE
    /\ serverRuntime' = FALSE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<serverKind, lowerTaskAuthority, monitorRootBudget,
                    linuxRuntimeAuthority, protectionClaim>>

ParamChangeInvalidates ==
    /\ phase \in {"ServerStarted", "TicketIssued", "Picked", "Running"}
    /\ InvalidateTicket(2)
    /\ serverActive' = TRUE
    /\ serverRuntime' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<serverKind, lowerTaskAuthority, monitorRootBudget,
                    linuxRuntimeAuthority, protectionClaim>>

CpuTeardownInvalidates ==
    /\ phase \in {"ServerStarted", "TicketIssued", "Picked", "Running"}
    /\ InvalidateTicket(3)
    /\ serverActive' = FALSE
    /\ serverRuntime' = FALSE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<serverKind, lowerTaskAuthority, monitorRootBudget,
                    linuxRuntimeAuthority, protectionClaim>>

TerminalStutter ==
    /\ phase \in {"Running", "FailClosed"}
    /\ UNCHANGED vars

UnsafeStaleAfterReplenish ==
    /\ phase \in {"TicketIssued", "Picked", "Running"}
    /\ ticketLive
    /\ serverEpoch' = 2
    /\ serverRuntime' = TRUE
    /\ serverPicked' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadStaleAfterReplenish"
    /\ UNCHANGED <<serverKind, serverActive, ticketLive, ticketEpoch,
                    ticketKind, lowerTaskAuthority, monitorRootBudget,
                    linuxRuntimeAuthority, failClosed, protectionClaim>>

UnsafeSwapKeepsTicket ==
    /\ phase \in {"TicketIssued", "Picked", "Running"}
    /\ ticketLive
    /\ serverKind' = IF serverKind = "FairServer" THEN "ExtServer"
                     ELSE "FairServer"
    /\ serverEpoch' = 3
    /\ serverActive' = TRUE
    /\ serverRuntime' = TRUE
    /\ serverPicked' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadSwapKeepsTicket"
    /\ UNCHANGED <<ticketLive, ticketEpoch, ticketKind, lowerTaskAuthority,
                    monitorRootBudget, linuxRuntimeAuthority, failClosed,
                    protectionClaim>>

UnsafeStopKeepsTicket ==
    /\ phase \in {"TicketIssued", "Picked", "Running"}
    /\ ticketLive
    /\ serverActive' = FALSE
    /\ serverRuntime' = FALSE
    /\ serverPicked' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadStopKeepsTicket"
    /\ UNCHANGED <<serverKind, serverEpoch, ticketLive, ticketEpoch,
                    ticketKind, lowerTaskAuthority, monitorRootBudget,
                    linuxRuntimeAuthority, failClosed, protectionClaim>>

UnsafePickNoTicket ==
    /\ phase = "ServerStarted"
    /\ ticketLive = FALSE
    /\ serverPicked' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadPickNoTicket"
    /\ UNCHANGED <<serverKind, serverActive, serverEpoch, ticketLive,
                    ticketEpoch, ticketKind, lowerTaskAuthority,
                    monitorRootBudget, serverRuntime, linuxRuntimeAuthority,
                    failClosed, protectionClaim>>

UnsafeLowerTaskNoAuthority ==
    /\ phase = "ServerStarted"
    /\ serverActive
    /\ ticketLive' = TRUE
    /\ ticketEpoch' = serverEpoch
    /\ ticketKind' = serverKind
    /\ lowerTaskAuthority' = FALSE
    /\ serverPicked' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadLowerTaskNoAuthority"
    /\ UNCHANGED <<serverKind, serverActive, serverEpoch, monitorRootBudget,
                    serverRuntime, linuxRuntimeAuthority, failClosed,
                    protectionClaim>>

UnsafeLinuxRuntimeAuthority ==
    /\ phase = "ServerStarted"
    /\ serverRuntime
    /\ linuxRuntimeAuthority' = TRUE
    /\ monitorRootBudget' = FALSE
    /\ ticketLive' = TRUE
    /\ ticketEpoch' = serverEpoch
    /\ ticketKind' = serverKind
    /\ serverPicked' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadLinuxRuntimeAuthority"
    /\ UNCHANGED <<serverKind, serverActive, serverEpoch,
                    lowerTaskAuthority, serverRuntime, failClosed,
                    protectionClaim>>

UnsafeParamChangeKeepsTicket ==
    /\ phase \in {"TicketIssued", "Picked", "Running"}
    /\ ticketLive
    /\ serverEpoch' = 2
    /\ serverRuntime' = TRUE
    /\ serverPicked' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadParamChangeKeepsTicket"
    /\ UNCHANGED <<serverKind, serverActive, ticketLive, ticketEpoch,
                    ticketKind, lowerTaskAuthority, monitorRootBudget,
                    linuxRuntimeAuthority, failClosed, protectionClaim>>

UnsafeCpuTeardownKeepsRun ==
    /\ phase \in {"Picked", "Running"}
    /\ ticketLive
    /\ serverActive' = FALSE
    /\ serverRuntime' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadCpuTeardownKeepsRun"
    /\ UNCHANGED <<serverKind, serverEpoch, ticketLive, ticketEpoch,
                    ticketKind, lowerTaskAuthority, monitorRootBudget,
                    serverPicked, linuxRuntimeAuthority, failClosed,
                    protectionClaim>>

UnsafeProtectionClaim ==
    /\ phase = "Running"
    /\ protectionClaim' = TRUE
    /\ phase' = "BadProtectionClaim"
    /\ UNCHANGED <<serverKind, serverActive, serverEpoch, ticketLive,
                    ticketEpoch, ticketKind, lowerTaskAuthority,
                    monitorRootBudget, serverRuntime, serverPicked, running,
                    linuxRuntimeAuthority, failClosed>>

SafeNext ==
    \/ PrepareAuthority
    \/ \E k \in {"FairServer", "ExtServer", "DlServer"}: StartServer(k)
    \/ IssueTicket
    \/ PickLowerTask
    \/ RunLowerTask
    \/ ReplenishInvalidates
    \/ \E k \in {"FairServer", "ExtServer", "DlServer"}: SwapInvalidates(k)
    \/ StopInvalidates
    \/ ParamChangeInvalidates
    \/ CpuTeardownInvalidates
    \/ TerminalStutter

SafeSpec == Init /\ [][SafeNext]_vars

SpecUnsafeStaleAfterReplenish ==
    Init /\ [][SafeNext \/ UnsafeStaleAfterReplenish]_vars

SpecUnsafeSwapKeepsTicket ==
    Init /\ [][SafeNext \/ UnsafeSwapKeepsTicket]_vars

SpecUnsafeStopKeepsTicket ==
    Init /\ [][SafeNext \/ UnsafeStopKeepsTicket]_vars

SpecUnsafePickNoTicket ==
    Init /\ [][SafeNext \/ UnsafePickNoTicket]_vars

SpecUnsafeLowerTaskNoAuthority ==
    Init /\ [][SafeNext \/ UnsafeLowerTaskNoAuthority]_vars

SpecUnsafeLinuxRuntimeAuthority ==
    Init /\ [][SafeNext \/ UnsafeLinuxRuntimeAuthority]_vars

SpecUnsafeParamChangeKeepsTicket ==
    Init /\ [][SafeNext \/ UnsafeParamChangeKeepsTicket]_vars

SpecUnsafeCpuTeardownKeepsRun ==
    Init /\ [][SafeNext \/ UnsafeCpuTeardownKeepsRun]_vars

SpecUnsafeProtectionClaim ==
    Init /\ [][SafeNext \/ UnsafeProtectionClaim]_vars

NoRunWithoutLowerTaskAuthority ==
    running => lowerTaskAuthority

NoRunWithoutMonitorRootBudget ==
    running => monitorRootBudget

NoPickWithoutFreshTicket ==
    serverPicked => FreshTicket

NoRunWithStaleServerEpoch ==
    running => FreshTicket

NoLiveTicketAcrossEpochChange ==
    ticketLive => /\ ticketEpoch = serverEpoch
                  /\ ticketKind = serverKind

NoTicketKindMismatch ==
    running => ticketKind = serverKind

NoStoppedServerWithLiveTicket ==
    ~serverActive => /\ ~ticketLive
                     /\ ~serverPicked
                     /\ ~running

NoLinuxRuntimeAsAuthority ==
    running => ~linuxRuntimeAuthority

NoFailClosedRunning ==
    failClosed => ~running

NoProtectionClaim ==
    ~protectionClaim

=============================================================================
