----------------------- MODULE PostExecResource -----------------------
EXTENDS Naturals

VARIABLES
    phase,
    kind,
    execCommitted,
    programFresh,
    fdReachable,
    closeOnExec,
    closeHandled,
    classDerived,
    regularOpMask,
    socketPolicy,
    anonPolicy,
    epollWatchDerived,
    oldReadyUsed,
    eventfdPolicy,
    kernelSignalPolicy,
    timerfdPolicy,
    oldTimerAuthority,
    ioUringRingDerived,
    ioUringRegsDerived,
    ioUringActivityCanceled,
    execfdDerived,
    effect,
    failClosed

vars == <<phase, kind, execCommitted, programFresh, fdReachable, closeOnExec,
          closeHandled, classDerived, regularOpMask, socketPolicy, anonPolicy,
          epollWatchDerived, oldReadyUsed, eventfdPolicy,
          kernelSignalPolicy, timerfdPolicy, oldTimerAuthority,
          ioUringRingDerived, ioUringRegsDerived, ioUringActivityCanceled,
          execfdDerived, effect, failClosed>>

Kinds == {
    "None",
    "Regular",
    "Socket",
    "Anon",
    "Epoll",
    "Eventfd",
    "Timerfd",
    "IoUring",
    "Execfd"
}

Phases == {
    "Start",
    "Prepared",
    "Effect",
    "FailClosed",
    "BadGenericFd",
    "BadCloseOnExec",
    "BadRegularNoMask",
    "BadSocketNoPolicy",
    "BadAnonGeneric",
    "BadEpollOldReady",
    "BadEventfdSignal",
    "BadTimerfdAuthority",
    "BadIoUringRegs",
    "BadExecfdAmbient"
}

TypeOK ==
    /\ phase \in Phases
    /\ kind \in Kinds
    /\ execCommitted \in BOOLEAN
    /\ programFresh \in BOOLEAN
    /\ fdReachable \in BOOLEAN
    /\ closeOnExec \in BOOLEAN
    /\ closeHandled \in BOOLEAN
    /\ classDerived \in BOOLEAN
    /\ regularOpMask \in BOOLEAN
    /\ socketPolicy \in BOOLEAN
    /\ anonPolicy \in BOOLEAN
    /\ epollWatchDerived \in BOOLEAN
    /\ oldReadyUsed \in BOOLEAN
    /\ eventfdPolicy \in BOOLEAN
    /\ kernelSignalPolicy \in BOOLEAN
    /\ timerfdPolicy \in BOOLEAN
    /\ oldTimerAuthority \in BOOLEAN
    /\ ioUringRingDerived \in BOOLEAN
    /\ ioUringRegsDerived \in BOOLEAN
    /\ ioUringActivityCanceled \in BOOLEAN
    /\ execfdDerived \in BOOLEAN
    /\ effect \in BOOLEAN
    /\ failClosed \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ kind = "None"
    /\ execCommitted = FALSE
    /\ programFresh = FALSE
    /\ fdReachable = FALSE
    /\ closeOnExec = FALSE
    /\ closeHandled = FALSE
    /\ classDerived = FALSE
    /\ regularOpMask = FALSE
    /\ socketPolicy = FALSE
    /\ anonPolicy = FALSE
    /\ epollWatchDerived = FALSE
    /\ oldReadyUsed = FALSE
    /\ eventfdPolicy = FALSE
    /\ kernelSignalPolicy = FALSE
    /\ timerfdPolicy = FALSE
    /\ oldTimerAuthority = FALSE
    /\ ioUringRingDerived = FALSE
    /\ ioUringRegsDerived = FALSE
    /\ ioUringActivityCanceled = FALSE
    /\ execfdDerived = FALSE
    /\ effect = FALSE
    /\ failClosed = FALSE

BasePrepared(k) ==
    /\ phase = "Start"
    /\ kind' = k
    /\ execCommitted' = TRUE
    /\ programFresh' = TRUE
    /\ fdReachable' = TRUE
    /\ closeOnExec' = FALSE
    /\ closeHandled' = TRUE
    /\ classDerived' = TRUE
    /\ phase' = "Prepared"

PrepareRegular ==
    /\ BasePrepared("Regular")
    /\ regularOpMask' = TRUE
    /\ UNCHANGED <<socketPolicy, anonPolicy, epollWatchDerived, oldReadyUsed,
                    eventfdPolicy, kernelSignalPolicy, timerfdPolicy,
                    oldTimerAuthority, ioUringRingDerived, ioUringRegsDerived,
                    ioUringActivityCanceled, execfdDerived, effect,
                    failClosed>>

PrepareSocket ==
    /\ BasePrepared("Socket")
    /\ socketPolicy' = TRUE
    /\ UNCHANGED <<regularOpMask, anonPolicy, epollWatchDerived, oldReadyUsed,
                    eventfdPolicy, kernelSignalPolicy, timerfdPolicy,
                    oldTimerAuthority, ioUringRingDerived, ioUringRegsDerived,
                    ioUringActivityCanceled, execfdDerived, effect,
                    failClosed>>

PrepareAnon ==
    /\ BasePrepared("Anon")
    /\ anonPolicy' = TRUE
    /\ UNCHANGED <<regularOpMask, socketPolicy, epollWatchDerived,
                    oldReadyUsed, eventfdPolicy, kernelSignalPolicy,
                    timerfdPolicy, oldTimerAuthority, ioUringRingDerived,
                    ioUringRegsDerived, ioUringActivityCanceled,
                    execfdDerived, effect, failClosed>>

PrepareEpoll ==
    /\ BasePrepared("Epoll")
    /\ anonPolicy' = TRUE
    /\ epollWatchDerived' = TRUE
    /\ oldReadyUsed' = FALSE
    /\ UNCHANGED <<regularOpMask, socketPolicy, eventfdPolicy,
                    kernelSignalPolicy, timerfdPolicy, oldTimerAuthority,
                    ioUringRingDerived, ioUringRegsDerived,
                    ioUringActivityCanceled, execfdDerived, effect,
                    failClosed>>

PrepareEventfd ==
    /\ BasePrepared("Eventfd")
    /\ anonPolicy' = TRUE
    /\ eventfdPolicy' = TRUE
    /\ kernelSignalPolicy' = TRUE
    /\ UNCHANGED <<regularOpMask, socketPolicy, epollWatchDerived,
                    oldReadyUsed, timerfdPolicy, oldTimerAuthority,
                    ioUringRingDerived, ioUringRegsDerived,
                    ioUringActivityCanceled, execfdDerived, effect,
                    failClosed>>

PrepareTimerfd ==
    /\ BasePrepared("Timerfd")
    /\ anonPolicy' = TRUE
    /\ timerfdPolicy' = TRUE
    /\ oldTimerAuthority' = FALSE
    /\ UNCHANGED <<regularOpMask, socketPolicy, epollWatchDerived,
                    oldReadyUsed, eventfdPolicy, kernelSignalPolicy,
                    ioUringRingDerived, ioUringRegsDerived,
                    ioUringActivityCanceled, execfdDerived, effect,
                    failClosed>>

PrepareIoUring ==
    /\ BasePrepared("IoUring")
    /\ anonPolicy' = TRUE
    /\ ioUringRingDerived' = TRUE
    /\ ioUringRegsDerived' = TRUE
    /\ ioUringActivityCanceled' = TRUE
    /\ UNCHANGED <<regularOpMask, socketPolicy, epollWatchDerived,
                    oldReadyUsed, eventfdPolicy, kernelSignalPolicy,
                    timerfdPolicy, oldTimerAuthority, execfdDerived, effect,
                    failClosed>>

PrepareExecfd ==
    /\ BasePrepared("Execfd")
    /\ execfdDerived' = TRUE
    /\ UNCHANGED <<regularOpMask, socketPolicy, anonPolicy,
                    epollWatchDerived, oldReadyUsed, eventfdPolicy,
                    kernelSignalPolicy, timerfdPolicy, oldTimerAuthority,
                    ioUringRingDerived, ioUringRegsDerived,
                    ioUringActivityCanceled, effect, failClosed>>

RunEffect ==
    /\ phase = "Prepared"
    /\ execCommitted
    /\ programFresh
    /\ fdReachable
    /\ classDerived
    /\ closeHandled
    /\ ~(kind = "Regular" /\ ~regularOpMask)
    /\ ~(kind = "Socket" /\ ~socketPolicy)
    /\ ~(kind \in {"Anon", "Epoll", "Eventfd", "Timerfd", "IoUring"} /\ ~anonPolicy)
    /\ ~(kind = "Epoll" /\ (~epollWatchDerived \/ oldReadyUsed))
    /\ ~(kind = "Eventfd" /\ (~eventfdPolicy \/ ~kernelSignalPolicy))
    /\ ~(kind = "Timerfd" /\ (~timerfdPolicy \/ oldTimerAuthority))
    /\ ~(kind = "IoUring" /\ (~ioUringRingDerived \/ ~ioUringRegsDerived \/
                              ~ioUringActivityCanceled))
    /\ ~(kind = "Execfd" /\ ~execfdDerived)
    /\ effect' = TRUE
    /\ phase' = "Effect"
    /\ UNCHANGED <<kind, execCommitted, programFresh, fdReachable,
                    closeOnExec, closeHandled, classDerived, regularOpMask,
                    socketPolicy, anonPolicy, epollWatchDerived,
                    oldReadyUsed, eventfdPolicy, kernelSignalPolicy,
                    timerfdPolicy, oldTimerAuthority, ioUringRingDerived,
                    ioUringRegsDerived, ioUringActivityCanceled,
                    execfdDerived, failClosed>>

FailClosed ==
    /\ phase = "Prepared"
    /\ ~classDerived
    /\ failClosed' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<kind, execCommitted, programFresh, fdReachable,
                    closeOnExec, closeHandled, classDerived, regularOpMask,
                    socketPolicy, anonPolicy, epollWatchDerived,
                    oldReadyUsed, eventfdPolicy, kernelSignalPolicy,
                    timerfdPolicy, oldTimerAuthority, ioUringRingDerived,
                    ioUringRegsDerived, ioUringActivityCanceled,
                    execfdDerived, effect>>

UnsafeGenericFdEffect ==
    /\ phase = "Start"
    /\ kind' = "Regular"
    /\ execCommitted' = TRUE
    /\ programFresh' = TRUE
    /\ fdReachable' = TRUE
    /\ classDerived' = FALSE
    /\ effect' = TRUE
    /\ phase' = "BadGenericFd"
    /\ UNCHANGED <<closeOnExec, closeHandled, regularOpMask, socketPolicy,
                    anonPolicy, epollWatchDerived, oldReadyUsed,
                    eventfdPolicy, kernelSignalPolicy, timerfdPolicy,
                    oldTimerAuthority, ioUringRingDerived, ioUringRegsDerived,
                    ioUringActivityCanceled, execfdDerived, failClosed>>

UnsafeCloseOnExecLeak ==
    /\ phase = "Start"
    /\ kind' = "Regular"
    /\ execCommitted' = TRUE
    /\ programFresh' = TRUE
    /\ fdReachable' = TRUE
    /\ closeOnExec' = TRUE
    /\ closeHandled' = FALSE
    /\ classDerived' = TRUE
    /\ regularOpMask' = TRUE
    /\ effect' = TRUE
    /\ phase' = "BadCloseOnExec"
    /\ UNCHANGED <<socketPolicy, anonPolicy, epollWatchDerived,
                    oldReadyUsed, eventfdPolicy, kernelSignalPolicy,
                    timerfdPolicy, oldTimerAuthority, ioUringRingDerived,
                    ioUringRegsDerived, ioUringActivityCanceled,
                    execfdDerived, failClosed>>

UnsafeRegularNoMask ==
    /\ phase = "Start"
    /\ kind' = "Regular"
    /\ execCommitted' = TRUE
    /\ programFresh' = TRUE
    /\ fdReachable' = TRUE
    /\ closeHandled' = TRUE
    /\ classDerived' = TRUE
    /\ regularOpMask' = FALSE
    /\ effect' = TRUE
    /\ phase' = "BadRegularNoMask"
    /\ UNCHANGED <<closeOnExec, socketPolicy, anonPolicy, epollWatchDerived,
                    oldReadyUsed, eventfdPolicy, kernelSignalPolicy,
                    timerfdPolicy, oldTimerAuthority, ioUringRingDerived,
                    ioUringRegsDerived, ioUringActivityCanceled,
                    execfdDerived, failClosed>>

UnsafeSocketNoPolicy ==
    /\ phase = "Start"
    /\ kind' = "Socket"
    /\ execCommitted' = TRUE
    /\ programFresh' = TRUE
    /\ fdReachable' = TRUE
    /\ closeHandled' = TRUE
    /\ classDerived' = TRUE
    /\ socketPolicy' = FALSE
    /\ effect' = TRUE
    /\ phase' = "BadSocketNoPolicy"
    /\ UNCHANGED <<closeOnExec, regularOpMask, anonPolicy,
                    epollWatchDerived, oldReadyUsed, eventfdPolicy,
                    kernelSignalPolicy, timerfdPolicy, oldTimerAuthority,
                    ioUringRingDerived, ioUringRegsDerived,
                    ioUringActivityCanceled, execfdDerived, failClosed>>

UnsafeAnonGeneric ==
    /\ phase = "Start"
    /\ kind' = "Anon"
    /\ execCommitted' = TRUE
    /\ programFresh' = TRUE
    /\ fdReachable' = TRUE
    /\ closeHandled' = TRUE
    /\ classDerived' = TRUE
    /\ anonPolicy' = FALSE
    /\ effect' = TRUE
    /\ phase' = "BadAnonGeneric"
    /\ UNCHANGED <<closeOnExec, regularOpMask, socketPolicy,
                    epollWatchDerived, oldReadyUsed, eventfdPolicy,
                    kernelSignalPolicy, timerfdPolicy, oldTimerAuthority,
                    ioUringRingDerived, ioUringRegsDerived,
                    ioUringActivityCanceled, execfdDerived, failClosed>>

UnsafeEpollOldReady ==
    /\ phase = "Start"
    /\ kind' = "Epoll"
    /\ execCommitted' = TRUE
    /\ programFresh' = TRUE
    /\ fdReachable' = TRUE
    /\ closeHandled' = TRUE
    /\ classDerived' = TRUE
    /\ anonPolicy' = TRUE
    /\ epollWatchDerived' = FALSE
    /\ oldReadyUsed' = TRUE
    /\ effect' = TRUE
    /\ phase' = "BadEpollOldReady"
    /\ UNCHANGED <<closeOnExec, regularOpMask, socketPolicy, eventfdPolicy,
                    kernelSignalPolicy, timerfdPolicy, oldTimerAuthority,
                    ioUringRingDerived, ioUringRegsDerived,
                    ioUringActivityCanceled, execfdDerived, failClosed>>

UnsafeEventfdSignal ==
    /\ phase = "Start"
    /\ kind' = "Eventfd"
    /\ execCommitted' = TRUE
    /\ programFresh' = TRUE
    /\ fdReachable' = TRUE
    /\ closeHandled' = TRUE
    /\ classDerived' = TRUE
    /\ anonPolicy' = TRUE
    /\ eventfdPolicy' = TRUE
    /\ kernelSignalPolicy' = FALSE
    /\ effect' = TRUE
    /\ phase' = "BadEventfdSignal"
    /\ UNCHANGED <<closeOnExec, regularOpMask, socketPolicy,
                    epollWatchDerived, oldReadyUsed, timerfdPolicy,
                    oldTimerAuthority, ioUringRingDerived, ioUringRegsDerived,
                    ioUringActivityCanceled, execfdDerived, failClosed>>

UnsafeTimerfdAuthority ==
    /\ phase = "Start"
    /\ kind' = "Timerfd"
    /\ execCommitted' = TRUE
    /\ programFresh' = TRUE
    /\ fdReachable' = TRUE
    /\ closeHandled' = TRUE
    /\ classDerived' = TRUE
    /\ anonPolicy' = TRUE
    /\ timerfdPolicy' = TRUE
    /\ oldTimerAuthority' = TRUE
    /\ effect' = TRUE
    /\ phase' = "BadTimerfdAuthority"
    /\ UNCHANGED <<closeOnExec, regularOpMask, socketPolicy,
                    epollWatchDerived, oldReadyUsed, eventfdPolicy,
                    kernelSignalPolicy, ioUringRingDerived,
                    ioUringRegsDerived, ioUringActivityCanceled,
                    execfdDerived, failClosed>>

UnsafeIoUringRegs ==
    /\ phase = "Start"
    /\ kind' = "IoUring"
    /\ execCommitted' = TRUE
    /\ programFresh' = TRUE
    /\ fdReachable' = TRUE
    /\ closeHandled' = TRUE
    /\ classDerived' = TRUE
    /\ anonPolicy' = TRUE
    /\ ioUringRingDerived' = TRUE
    /\ ioUringRegsDerived' = FALSE
    /\ ioUringActivityCanceled' = FALSE
    /\ effect' = TRUE
    /\ phase' = "BadIoUringRegs"
    /\ UNCHANGED <<closeOnExec, regularOpMask, socketPolicy,
                    epollWatchDerived, oldReadyUsed, eventfdPolicy,
                    kernelSignalPolicy, timerfdPolicy, oldTimerAuthority,
                    execfdDerived, failClosed>>

UnsafeExecfdAmbient ==
    /\ phase = "Start"
    /\ kind' = "Execfd"
    /\ execCommitted' = TRUE
    /\ programFresh' = TRUE
    /\ fdReachable' = TRUE
    /\ closeHandled' = TRUE
    /\ classDerived' = TRUE
    /\ execfdDerived' = FALSE
    /\ effect' = TRUE
    /\ phase' = "BadExecfdAmbient"
    /\ UNCHANGED <<closeOnExec, regularOpMask, socketPolicy, anonPolicy,
                    epollWatchDerived, oldReadyUsed, eventfdPolicy,
                    kernelSignalPolicy, timerfdPolicy, oldTimerAuthority,
                    ioUringRingDerived, ioUringRegsDerived,
                    ioUringActivityCanceled, failClosed>>

SafeNext ==
    PrepareRegular \/ PrepareSocket \/ PrepareAnon \/ PrepareEpoll \/
    PrepareEventfd \/ PrepareTimerfd \/ PrepareIoUring \/ PrepareExecfd \/
    RunEffect \/ FailClosed

SafeSpec ==
    Init /\ [][SafeNext]_vars

UnsafeGenericSpec ==
    Init /\ [][SafeNext \/ UnsafeGenericFdEffect]_vars

UnsafeCloseOnExecSpec ==
    Init /\ [][SafeNext \/ UnsafeCloseOnExecLeak]_vars

UnsafeRegularSpec ==
    Init /\ [][SafeNext \/ UnsafeRegularNoMask]_vars

UnsafeSocketSpec ==
    Init /\ [][SafeNext \/ UnsafeSocketNoPolicy]_vars

UnsafeAnonSpec ==
    Init /\ [][SafeNext \/ UnsafeAnonGeneric]_vars

UnsafeEpollSpec ==
    Init /\ [][SafeNext \/ UnsafeEpollOldReady]_vars

UnsafeEventfdSpec ==
    Init /\ [][SafeNext \/ UnsafeEventfdSignal]_vars

UnsafeTimerfdSpec ==
    Init /\ [][SafeNext \/ UnsafeTimerfdAuthority]_vars

UnsafeIoUringSpec ==
    Init /\ [][SafeNext \/ UnsafeIoUringRegs]_vars

UnsafeExecfdSpec ==
    Init /\ [][SafeNext \/ UnsafeExecfdAmbient]_vars

NoGenericFdPostExecAuthority ==
    (effect /\ execCommitted) => classDerived

NoCloseOnExecResourceLeak ==
    (effect /\ execCommitted /\ closeOnExec) => closeHandled

NoRegularFileOpWithoutMask ==
    (effect /\ execCommitted /\ kind = "Regular") => regularOpMask

NoSocketStateAmbientAuthority ==
    (effect /\ execCommitted /\ kind = "Socket") => socketPolicy

NoAnonFdGenericPolicy ==
    (effect /\ execCommitted /\ kind \in {"Anon", "Epoll", "Eventfd",
                                          "Timerfd", "IoUring"}) => anonPolicy

NoEpollOldReadinessAuthority ==
    (effect /\ execCommitted /\ kind = "Epoll") =>
        epollWatchDerived /\ ~oldReadyUsed

NoEventfdSignalLeak ==
    (effect /\ execCommitted /\ kind = "Eventfd") =>
        eventfdPolicy /\ kernelSignalPolicy

NoTimerfdOldTimerAuthority ==
    (effect /\ execCommitted /\ kind = "Timerfd") =>
        timerfdPolicy /\ ~oldTimerAuthority

NoIoUringRegisteredResourceLeak ==
    (effect /\ execCommitted /\ kind = "IoUring") =>
        ioUringRingDerived /\ ioUringRegsDerived /\ ioUringActivityCanceled

NoExecfdAmbientInheritance ==
    (effect /\ execCommitted /\ kind = "Execfd") => execfdDerived

=============================================================================
