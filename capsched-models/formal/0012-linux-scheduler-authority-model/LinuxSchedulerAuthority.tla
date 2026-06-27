---------------------- MODULE LinuxSchedulerAuthority ----------------------
EXTENDS Naturals, FiniteSets

CONSTANTS
    T1, T2,
    D1, D2,
    C1, C2,
    SC1, SC2,
    NoTask,
    NoDomain,
    NoCpu,
    NoCtx,
    MaxEpoch,
    MaxGen,
    MaxBudget

VARIABLES
    taskState,
    taskGen,
    procGen,
    domainEpoch,
    grant,
    budget,
    selected,
    running,
    activeDomain,
    activeEpoch,
    runToken

vars == <<taskState, taskGen, procGen, domainEpoch, grant, budget,
          selected, running, activeDomain, activeEpoch, runToken>>

Tasks == {T1, T2}
Domains == {D1, D2}
CPUs == {C1, C2}
SchedCtxs == {SC1, SC2}

TaskOrNone == Tasks \cup {NoTask}
DomainOrNone == Domains \cup {NoDomain}
CpuOrNone == CPUs \cup {NoCpu}
CtxOrNone == SchedCtxs \cup {NoCtx}

Epochs == 0..MaxEpoch
Gens == 0..MaxGen
Budgets == 0..MaxBudget

States == {
    "Blocked",
    "Spawned",
    "RemotePendingWake",
    "FrozenRunnable",
    "Queued",
    "DelayedQueued",
    "MigratingQueued",
    "Selected",
    "Running",
    "CurrentContinuation",
    "Throttled",
    "Dead"
}

RunnableCustodyStates == {
    "Queued",
    "DelayedQueued",
    "MigratingQueued",
    "Selected",
    "Running",
    "CurrentContinuation"
}

RunningStates == {"Running", "CurrentContinuation"}
LiveStates == States \ {"Dead"}

TaskDom(t) == IF t = T1 THEN D1 ELSE D2
CtxOwner(sc) == IF sc = SC1 THEN D1 ELSE D2

AllowedCpus(t, sc) ==
    IF /\ t \in Tasks
       /\ sc \in SchedCtxs
       /\ TaskDom(t) = CtxOwner(sc)
    THEN CPUs
    ELSE {}

GrantRecord == [
    valid: BOOLEAN,
    taskGen: Gens,
    procGen: Gens,
    domain: DomainOrNone,
    epoch: Epochs,
    ctx: CtxOrNone,
    allowed: SUBSET CPUs
]

TokenRecord == [
    valid: BOOLEAN,
    task: TaskOrNone,
    domain: DomainOrNone,
    epoch: Epochs,
    cpu: CpuOrNone,
    ctx: CtxOrNone
]

GrantNone == [
    valid |-> FALSE,
    taskGen |-> 0,
    procGen |-> 0,
    domain |-> NoDomain,
    epoch |-> 0,
    ctx |-> NoCtx,
    allowed |-> {}
]

TokenNone == [
    valid |-> FALSE,
    task |-> NoTask,
    domain |-> NoDomain,
    epoch |-> 0,
    cpu |-> NoCpu,
    ctx |-> NoCtx
]

SelectedTasks == {selected[c] : c \in CPUs} \ {NoTask}
RunningTasks == {running[c] : c \in CPUs} \ {NoTask}

TaskSelected(t) == t \in SelectedTasks
TaskRunning(t) == t \in RunningTasks

ValidGrant(t) ==
    /\ t \in Tasks
    /\ grant[t].valid
    /\ grant[t].taskGen = taskGen[t]
    /\ grant[t].procGen = procGen[t]
    /\ grant[t].domain = TaskDom(t)
    /\ grant[t].epoch = domainEpoch[TaskDom(t)]
    /\ grant[t].ctx \in SchedCtxs
    /\ CtxOwner(grant[t].ctx) = TaskDom(t)
    /\ grant[t].allowed = AllowedCpus(t, grant[t].ctx)
    /\ grant[t].allowed # {}

CanRunOn(t, c) ==
    /\ ValidGrant(t)
    /\ c \in grant[t].allowed
    /\ budget[grant[t].ctx] > 0

TokenMatchesCpu(c) ==
    /\ c \in CPUs
    /\ runToken[c].valid
    /\ running[c] \in Tasks
    /\ runToken[c].task = running[c]
    /\ runToken[c].domain = TaskDom(running[c])
    /\ runToken[c].epoch = domainEpoch[TaskDom(running[c])]
    /\ runToken[c].cpu = c
    /\ runToken[c].ctx = grant[running[c]].ctx
    /\ activeDomain[c] = runToken[c].domain
    /\ activeEpoch[c] = runToken[c].epoch

CpuIdle(c) ==
    /\ selected[c] = NoTask
    /\ running[c] = NoTask
    /\ activeDomain[c] = NoDomain
    /\ activeEpoch[c] = 0
    /\ ~runToken[c].valid

ClearSelectedForTask(sel, t) ==
    [c \in CPUs |-> IF sel[c] = t THEN NoTask ELSE sel[c]]

ClearRunningForTask(run, t) ==
    [c \in CPUs |-> IF run[c] = t THEN NoTask ELSE run[c]]

ClearActiveDomainForTask(run, act, t) ==
    [c \in CPUs |-> IF run[c] = t THEN NoDomain ELSE act[c]]

ClearActiveEpochForTask(run, act, t) ==
    [c \in CPUs |-> IF run[c] = t THEN 0 ELSE act[c]]

ClearTokenForTask(tok, t) ==
    [c \in CPUs |-> IF tok[c].task = t THEN TokenNone ELSE tok[c]]

ClearSelectedForDomain(d) ==
    [c \in CPUs |->
        IF selected[c] \in Tasks /\ TaskDom(selected[c]) = d
        THEN NoTask
        ELSE selected[c]]

ClearRunningForDomain(d) ==
    [c \in CPUs |->
        IF running[c] \in Tasks /\ TaskDom(running[c]) = d
        THEN NoTask
        ELSE running[c]]

ClearActiveDomainForDomain(d) ==
    [c \in CPUs |->
        IF running[c] \in Tasks /\ TaskDom(running[c]) = d
        THEN NoDomain
        ELSE activeDomain[c]]

ClearActiveEpochForDomain(d) ==
    [c \in CPUs |->
        IF running[c] \in Tasks /\ TaskDom(running[c]) = d
        THEN 0
        ELSE activeEpoch[c]]

ClearTokenForDomain(d) ==
    [c \in CPUs |->
        IF runToken[c].task \in Tasks /\ TaskDom(runToken[c].task) = d
        THEN TokenNone
        ELSE runToken[c]]

IssueGrant(t, sc) ==
    [valid |-> TRUE,
     taskGen |-> taskGen[t],
     procGen |-> procGen[t],
     domain |-> TaskDom(t),
     epoch |-> domainEpoch[TaskDom(t)],
     ctx |-> sc,
     allowed |-> AllowedCpus(t, sc)]

TypeOK ==
    /\ T1 # T2
    /\ D1 # D2
    /\ C1 # C2
    /\ SC1 # SC2
    /\ NoTask \notin Tasks
    /\ NoDomain \notin Domains
    /\ NoCpu \notin CPUs
    /\ NoCtx \notin SchedCtxs
    /\ MaxEpoch \in Nat
    /\ MaxGen \in Nat
    /\ MaxBudget \in Nat
    /\ MaxBudget > 0
    /\ taskState \in [Tasks -> States]
    /\ taskGen \in [Tasks -> Gens]
    /\ procGen \in [Tasks -> Gens]
    /\ domainEpoch \in [Domains -> Epochs]
    /\ grant \in [Tasks -> GrantRecord]
    /\ budget \in [SchedCtxs -> Budgets]
    /\ selected \in [CPUs -> TaskOrNone]
    /\ running \in [CPUs -> TaskOrNone]
    /\ activeDomain \in [CPUs -> DomainOrNone]
    /\ activeEpoch \in [CPUs -> Epochs]
    /\ runToken \in [CPUs -> TokenRecord]

Init ==
    /\ taskState = [t \in Tasks |-> "Blocked"]
    /\ taskGen = [t \in Tasks |-> 0]
    /\ procGen = [t \in Tasks |-> 0]
    /\ domainEpoch = [d \in Domains |-> 0]
    /\ grant = [t \in Tasks |-> GrantNone]
    /\ budget = [sc \in SchedCtxs |-> MaxBudget]
    /\ selected = [c \in CPUs |-> NoTask]
    /\ running = [c \in CPUs |-> NoTask]
    /\ activeDomain = [c \in CPUs |-> NoDomain]
    /\ activeEpoch = [c \in CPUs |-> 0]
    /\ runToken = [c \in CPUs |-> TokenNone]

SpawnTask(t) ==
    /\ t \in Tasks
    /\ taskState[t] \in {"Blocked", "Dead"}
    /\ ~TaskSelected(t)
    /\ ~TaskRunning(t)
    /\ taskGen[t] < MaxGen
    /\ procGen[t] < MaxGen
    /\ taskState' = [taskState EXCEPT ![t] = "Spawned"]
    /\ taskGen' = [taskGen EXCEPT ![t] = @ + 1]
    /\ procGen' = [procGen EXCEPT ![t] = @ + 1]
    /\ grant' = [grant EXCEPT ![t] = GrantNone]
    /\ UNCHANGED <<domainEpoch, budget, selected, running,
                    activeDomain, activeEpoch, runToken>>

FreezeSpawned(t, sc) ==
    /\ t \in Tasks
    /\ sc \in SchedCtxs
    /\ taskState[t] = "Spawned"
    /\ CtxOwner(sc) = TaskDom(t)
    /\ budget[sc] > 0
    /\ taskState' = [taskState EXCEPT ![t] = "FrozenRunnable"]
    /\ grant' = [grant EXCEPT ![t] = IssueGrant(t, sc)]
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, budget, selected,
                    running, activeDomain, activeEpoch, runToken>>

FreezeBlockedWake(t, sc) ==
    /\ t \in Tasks
    /\ sc \in SchedCtxs
    /\ taskState[t] = "Blocked"
    /\ CtxOwner(sc) = TaskDom(t)
    /\ budget[sc] > 0
    /\ ~TaskSelected(t)
    /\ ~TaskRunning(t)
    /\ taskState' = [taskState EXCEPT ![t] = "FrozenRunnable"]
    /\ grant' = [grant EXCEPT ![t] = IssueGrant(t, sc)]
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, budget, selected,
                    running, activeDomain, activeEpoch, runToken>>

RemoteWake(t) ==
    /\ t \in Tasks
    /\ taskState[t] = "Blocked"
    /\ ~TaskSelected(t)
    /\ ~TaskRunning(t)
    /\ taskState' = [taskState EXCEPT ![t] = "RemotePendingWake"]
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, grant, budget, selected,
                    running, activeDomain, activeEpoch, runToken>>

ActivateRemoteWake(t, sc) ==
    /\ t \in Tasks
    /\ sc \in SchedCtxs
    /\ taskState[t] = "RemotePendingWake"
    /\ CtxOwner(sc) = TaskDom(t)
    /\ budget[sc] > 0
    /\ taskState' = [taskState EXCEPT ![t] = "FrozenRunnable"]
    /\ grant' = [grant EXCEPT ![t] = IssueGrant(t, sc)]
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, budget, selected,
                    running, activeDomain, activeEpoch, runToken>>

EnqueueTask(t) ==
    /\ t \in Tasks
    /\ taskState[t] = "FrozenRunnable"
    /\ ValidGrant(t)
    /\ ~TaskSelected(t)
    /\ ~TaskRunning(t)
    /\ taskState' = [taskState EXCEPT ![t] = "Queued"]
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, grant, budget, selected,
                    running, activeDomain, activeEpoch, runToken>>

AlreadyRunnableWake(t) ==
    /\ t \in Tasks
    /\ taskState[t] \in {"Queued", "DelayedQueued"}
    /\ ValidGrant(t)
    /\ ~TaskSelected(t)
    /\ ~TaskRunning(t)
    /\ taskState' = [taskState EXCEPT ![t] =
        IF taskState[t] = "Queued" THEN "DelayedQueued" ELSE "Queued"]
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, grant, budget, selected,
                    running, activeDomain, activeEpoch, runToken>>

StartMigration(t) ==
    /\ t \in Tasks
    /\ taskState[t] = "Queued"
    /\ ValidGrant(t)
    /\ ~TaskSelected(t)
    /\ ~TaskRunning(t)
    /\ taskState' = [taskState EXCEPT ![t] = "MigratingQueued"]
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, grant, budget, selected,
                    running, activeDomain, activeEpoch, runToken>>

FinishMigration(t) ==
    /\ t \in Tasks
    /\ taskState[t] = "MigratingQueued"
    /\ ValidGrant(t)
    /\ ~TaskSelected(t)
    /\ ~TaskRunning(t)
    /\ taskState' = [taskState EXCEPT ![t] = "Queued"]
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, grant, budget, selected,
                    running, activeDomain, activeEpoch, runToken>>

PickTask(c, t) ==
    /\ c \in CPUs
    /\ t \in Tasks
    /\ taskState[t] \in {"Queued", "DelayedQueued"}
    /\ selected[c] = NoTask
    /\ running[c] = NoTask
    /\ ~TaskSelected(t)
    /\ ~TaskRunning(t)
    /\ ValidGrant(t)
    /\ c \in grant[t].allowed
    /\ taskState' = [taskState EXCEPT ![t] = "Selected"]
    /\ selected' = [selected EXCEPT ![c] = t]
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, grant, budget, running,
                    activeDomain, activeEpoch, runToken>>

SelectedBudgetFail(c) ==
    /\ c \in CPUs
    /\ selected[c] \in Tasks
    /\ LET t == selected[c] IN
        /\ ValidGrant(t)
        /\ budget[grant[t].ctx] = 0
        /\ taskState' = [taskState EXCEPT ![t] = "Throttled"]
        /\ selected' = [selected EXCEPT ![c] = NoTask]
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, grant, budget, running,
                    activeDomain, activeEpoch, runToken>>

SwitchActivate(c) ==
    /\ c \in CPUs
    /\ selected[c] \in Tasks
    /\ LET t == selected[c] IN
        /\ CanRunOn(t, c)
        /\ taskState' = [taskState EXCEPT ![t] = "Running"]
        /\ selected' = [selected EXCEPT ![c] = NoTask]
        /\ running' = [running EXCEPT ![c] = t]
        /\ activeDomain' = [activeDomain EXCEPT ![c] = TaskDom(t)]
        /\ activeEpoch' = [activeEpoch EXCEPT ![c] = domainEpoch[TaskDom(t)]]
        /\ runToken' = [runToken EXCEPT ![c] =
            [valid |-> TRUE,
             task |-> t,
             domain |-> TaskDom(t),
             epoch |-> domainEpoch[TaskDom(t)],
             cpu |-> c,
             ctx |-> grant[t].ctx]]
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, grant, budget>>

SelfWake(c) ==
    /\ c \in CPUs
    /\ running[c] \in Tasks
    /\ taskState[running[c]] = "Running"
    /\ taskState' = [taskState EXCEPT ![running[c]] = "CurrentContinuation"]
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, grant, budget, selected,
                    running, activeDomain, activeEpoch, runToken>>

ContinueCurrent(c) ==
    /\ c \in CPUs
    /\ running[c] \in Tasks
    /\ taskState[running[c]] = "CurrentContinuation"
    /\ taskState' = [taskState EXCEPT ![running[c]] = "Running"]
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, grant, budget, selected,
                    running, activeDomain, activeEpoch, runToken>>

TickContinue(c) ==
    /\ c \in CPUs
    /\ running[c] \in Tasks
    /\ taskState[running[c]] \in RunningStates
    /\ ValidGrant(running[c])
    /\ budget[grant[running[c]].ctx] > 1
    /\ budget' = [budget EXCEPT ![grant[running[c]].ctx] = @ - 1]
    /\ UNCHANGED <<taskState, taskGen, procGen, domainEpoch, grant, selected,
                    running, activeDomain, activeEpoch, runToken>>

TickExhaust(c) ==
    /\ c \in CPUs
    /\ running[c] \in Tasks
    /\ taskState[running[c]] \in RunningStates
    /\ ValidGrant(running[c])
    /\ budget[grant[running[c]].ctx] = 1
    /\ LET t == running[c] IN
        /\ budget' = [budget EXCEPT ![grant[t].ctx] = 0]
        /\ taskState' = [taskState EXCEPT ![t] = "Throttled"]
        /\ running' = [running EXCEPT ![c] = NoTask]
        /\ activeDomain' = [activeDomain EXCEPT ![c] = NoDomain]
        /\ activeEpoch' = [activeEpoch EXCEPT ![c] = 0]
        /\ runToken' = [runToken EXCEPT ![c] = TokenNone]
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, grant, selected>>

Replenish(sc) ==
    /\ sc \in SchedCtxs
    /\ budget[sc] < MaxBudget
    /\ budget' = [budget EXCEPT ![sc] = MaxBudget]
    /\ UNCHANGED <<taskState, taskGen, procGen, domainEpoch, grant, selected,
                    running, activeDomain, activeEpoch, runToken>>

Unthrottle(t) ==
    /\ t \in Tasks
    /\ taskState[t] = "Throttled"
    /\ ValidGrant(t)
    /\ budget[grant[t].ctx] > 0
    /\ ~TaskSelected(t)
    /\ ~TaskRunning(t)
    /\ taskState' = [taskState EXCEPT ![t] = "Queued"]
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, grant, budget, selected,
                    running, activeDomain, activeEpoch, runToken>>

YieldOrBlock(c) ==
    /\ c \in CPUs
    /\ running[c] \in Tasks
    /\ taskState[running[c]] \in RunningStates
    /\ LET t == running[c] IN
        /\ taskState' = [taskState EXCEPT ![t] = "Blocked"]
        /\ running' = [running EXCEPT ![c] = NoTask]
        /\ activeDomain' = [activeDomain EXCEPT ![c] = NoDomain]
        /\ activeEpoch' = [activeEpoch EXCEPT ![c] = 0]
        /\ runToken' = [runToken EXCEPT ![c] = TokenNone]
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, grant, budget, selected>>

ExitTask(t) ==
    /\ t \in Tasks
    /\ taskState[t] \in LiveStates
    /\ taskState' = [taskState EXCEPT ![t] = "Dead"]
    /\ grant' = [grant EXCEPT ![t] = GrantNone]
    /\ selected' = ClearSelectedForTask(selected, t)
    /\ running' = ClearRunningForTask(running, t)
    /\ activeDomain' = ClearActiveDomainForTask(running, activeDomain, t)
    /\ activeEpoch' = ClearActiveEpochForTask(running, activeEpoch, t)
    /\ runToken' = ClearTokenForTask(runToken, t)
    /\ UNCHANGED <<taskGen, procGen, domainEpoch, budget>>

RevokeDomain(d) ==
    /\ d \in Domains
    /\ domainEpoch[d] < MaxEpoch
    /\ domainEpoch' = [domainEpoch EXCEPT ![d] = @ + 1]
    /\ taskState' = [t \in Tasks |->
        IF TaskDom(t) = d /\ taskState[t] # "Dead"
        THEN "Blocked"
        ELSE taskState[t]]
    /\ grant' = [t \in Tasks |->
        IF TaskDom(t) = d THEN GrantNone ELSE grant[t]]
    /\ selected' = ClearSelectedForDomain(d)
    /\ running' = ClearRunningForDomain(d)
    /\ activeDomain' = ClearActiveDomainForDomain(d)
    /\ activeEpoch' = ClearActiveEpochForDomain(d)
    /\ runToken' = ClearTokenForDomain(d)
    /\ UNCHANGED <<taskGen, procGen, budget>>

Next ==
    \/ \E t \in Tasks: SpawnTask(t)
    \/ \E t \in Tasks: \E sc \in SchedCtxs: FreezeSpawned(t, sc)
    \/ \E t \in Tasks: \E sc \in SchedCtxs: FreezeBlockedWake(t, sc)
    \/ \E t \in Tasks: RemoteWake(t)
    \/ \E t \in Tasks: \E sc \in SchedCtxs: ActivateRemoteWake(t, sc)
    \/ \E t \in Tasks: EnqueueTask(t)
    \/ \E t \in Tasks: AlreadyRunnableWake(t)
    \/ \E t \in Tasks: StartMigration(t)
    \/ \E t \in Tasks: FinishMigration(t)
    \/ \E c \in CPUs: \E t \in Tasks: PickTask(c, t)
    \/ \E c \in CPUs: SelectedBudgetFail(c)
    \/ \E c \in CPUs: SwitchActivate(c)
    \/ \E c \in CPUs: SelfWake(c)
    \/ \E c \in CPUs: ContinueCurrent(c)
    \/ \E c \in CPUs: TickContinue(c)
    \/ \E c \in CPUs: TickExhaust(c)
    \/ \E sc \in SchedCtxs: Replenish(sc)
    \/ \E t \in Tasks: Unthrottle(t)
    \/ \E c \in CPUs: YieldOrBlock(c)
    \/ \E t \in Tasks: ExitTask(t)
    \/ \E d \in Domains: RevokeDomain(d)

Spec == Init /\ [][Next]_vars

NoCustodyWithoutValidGrant ==
    \A t \in Tasks:
        taskState[t] \in RunnableCustodyStates => ValidGrant(t)

NoRemotePendingRuns ==
    \A t \in Tasks:
        taskState[t] = "RemotePendingWake" =>
            /\ ~TaskSelected(t)
            /\ ~TaskRunning(t)

NoRunningWithoutToken ==
    \A c \in CPUs:
        running[c] # NoTask => TokenMatchesCpu(c)

NoRunningWithoutBudget ==
    \A c \in CPUs:
        running[c] # NoTask => budget[grant[running[c]].ctx] > 0

NoStaleActiveEpoch ==
    \A c \in CPUs:
        running[c] # NoTask =>
            activeEpoch[c] = domainEpoch[TaskDom(running[c])]

NoDeadAuthority ==
    \A t \in Tasks:
        taskState[t] = "Dead" =>
            /\ ~grant[t].valid
            /\ ~TaskSelected(t)
            /\ ~TaskRunning(t)

NoTaskSelectedTwice ==
    \A t \in Tasks:
        Cardinality({c \in CPUs : selected[c] = t}) <= 1

NoTaskRunsTwice ==
    \A t \in Tasks:
        Cardinality({c \in CPUs : running[c] = t}) <= 1

NoSelectedAndRunningSameTask ==
    \A t \in Tasks:
        ~(TaskSelected(t) /\ TaskRunning(t))

NoSelectedOnBusyCpu ==
    \A c \in CPUs:
        selected[c] # NoTask => running[c] = NoTask

CpuIdleShape ==
    \A c \in CPUs:
        running[c] = NoTask /\ selected[c] = NoTask =>
            /\ activeDomain[c] = NoDomain
            /\ ~runToken[c].valid

=============================================================================
