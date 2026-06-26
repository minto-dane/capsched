--------------------------- MODULE RunnableLease ---------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS
    T1, T2,
    D1, D2,
    C1, C2,
    SC1, SC2,
    NoTask,
    NoDomain,
    NoCtx,
    MaxBudget,
    MaxEpoch,
    MaxGen

VARIABLES
    tstate,
    tgen,
    pgen,
    depoch,
    cap,
    grant,
    budget,
    currentDom,
    selected,
    running

vars == <<tstate, tgen, pgen, depoch, cap, grant, budget, currentDom, selected, running>>

Tasks == {T1, T2}
Domains == {D1, D2}
CPUs == {C1, C2}
SchedCtxs == {SC1, SC2}

States == {
    "blocked",
    "waking",
    "remote_wake_pending",
    "runnable_delayed",
    "queued",
    "throttled",
    "migrating",
    "selected",
    "running",
    "exiting",
    "dead_but_referenced"
}

Epochs == 0..MaxEpoch
Gens == 0..MaxGen
Budgets == 0..MaxBudget

TaskOrNone == Tasks \cup {NoTask}
DomainOrNone == Domains \cup {NoDomain}
CtxOrNone == SchedCtxs \cup {NoCtx}

TaskDom(t) == IF t = T1 THEN D1 ELSE D2
CtxOwnerOf(sc) == IF sc = SC1 THEN D1 ELSE D2

CtxAllowedSet(sc) == IF sc = SC1 THEN {C1, C2} ELSE {C1, C2}
AffinityAllowedSet(t) == IF t = T1 THEN {C1, C2} ELSE {C1, C2}
CpusetAllowedSet(t) == IF t = T1 THEN {C1, C2} ELSE {C1, C2}
DomainAllowedSet(d) == IF d = D1 THEN {C1, C2} ELSE {C1, C2}

PolicyAllowsRun(t) == t \in Tasks

AllowedSet(t, sc, d) ==
    CtxAllowedSet(sc) \cap AffinityAllowedSet(t) \cap
    CpusetAllowedSet(t) \cap DomainAllowedSet(d)

MonitorAllowsRun(d, e, c) ==
    /\ d \in Domains
    /\ e \in Epochs
    /\ c \in CPUs

CapRecord == [
    valid: BOOLEAN,
    taskGen: Gens,
    procGen: Gens,
    domain: DomainOrNone,
    epoch: Epochs,
    ctx: CtxOrNone
]

GrantRecord == [
    valid: BOOLEAN,
    taskGen: Gens,
    procGen: Gens,
    domain: DomainOrNone,
    epoch: Epochs,
    ctx: CtxOrNone,
    allowed: SUBSET CPUs
]

CapNone == [
    valid |-> FALSE,
    taskGen |-> 0,
    procGen |-> 0,
    domain |-> NoDomain,
    epoch |-> 0,
    ctx |-> NoCtx
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

ActiveStates == {
    "waking",
    "remote_wake_pending",
    "runnable_delayed",
    "queued",
    "throttled",
    "migrating",
    "selected",
    "running"
}

SchedulableStates == {
    "blocked",
    "waking",
    "remote_wake_pending",
    "runnable_delayed",
    "queued",
    "throttled",
    "migrating"
}

SelectedTasks == {selected[c] : c \in CPUs} \ {NoTask}
RunningTasks == {running[c] : c \in CPUs} \ {NoTask}

ValidCap(t) ==
    /\ cap[t].valid
    /\ cap[t].taskGen = tgen[t]
    /\ cap[t].procGen = pgen[t]
    /\ cap[t].domain = TaskDom(t)
    /\ cap[t].epoch = depoch[TaskDom(t)]
    /\ cap[t].ctx \in SchedCtxs
    /\ CtxOwnerOf(cap[t].ctx) = TaskDom(t)

ValidGrant(t) ==
    /\ grant[t].valid
    /\ grant[t].taskGen = tgen[t]
    /\ grant[t].procGen = pgen[t]
    /\ grant[t].domain = TaskDom(t)
    /\ grant[t].epoch = depoch[TaskDom(t)]
    /\ grant[t].ctx \in SchedCtxs
    /\ CtxOwnerOf(grant[t].ctx) = TaskDom(t)
    /\ grant[t].allowed = AllowedSet(t, grant[t].ctx, TaskDom(t))
    /\ grant[t].allowed # {}

CanRunOn(t, c) ==
    /\ ValidGrant(t)
    /\ c \in grant[t].allowed
    /\ budget[grant[t].ctx] > 0
    /\ MonitorAllowsRun(TaskDom(t), depoch[TaskDom(t)], c)

TypeOK ==
    /\ T1 # T2
    /\ D1 # D2
    /\ C1 # C2
    /\ SC1 # SC2
    /\ NoTask \notin Tasks
    /\ NoDomain \notin Domains
    /\ NoCtx \notin SchedCtxs
    /\ MaxBudget \in Nat
    /\ MaxBudget > 0
    /\ MaxEpoch \in Nat
    /\ MaxGen \in Nat
    /\ tstate \in [Tasks -> States]
    /\ tgen \in [Tasks -> Gens]
    /\ pgen \in [Tasks -> Gens]
    /\ depoch \in [Domains -> Epochs]
    /\ cap \in [Tasks -> CapRecord]
    /\ grant \in [Tasks -> GrantRecord]
    /\ budget \in [SchedCtxs -> Budgets]
    /\ currentDom \in [CPUs -> DomainOrNone]
    /\ selected \in [CPUs -> TaskOrNone]
    /\ running \in [CPUs -> TaskOrNone]

Init ==
    /\ tstate = [t \in Tasks |-> "blocked"]
    /\ tgen = [t \in Tasks |-> 0]
    /\ pgen = [t \in Tasks |-> 0]
    /\ depoch = [d \in Domains |-> 0]
    /\ cap = [t \in Tasks |-> CapNone]
    /\ grant = [t \in Tasks |-> GrantNone]
    /\ budget = [sc \in SchedCtxs |-> MaxBudget]
    /\ currentDom = [c \in CPUs |-> NoDomain]
    /\ selected = [c \in CPUs |-> NoTask]
    /\ running = [c \in CPUs |-> NoTask]

IssueRunCap(t, sc) ==
    /\ t \in Tasks
    /\ sc \in SchedCtxs
    /\ tstate[t] \in SchedulableStates
    /\ TaskDom(t) = CtxOwnerOf(sc)
    /\ PolicyAllowsRun(t)
    /\ cap' = [cap EXCEPT ![t] =
        [valid |-> TRUE,
         taskGen |-> tgen[t],
         procGen |-> pgen[t],
         domain |-> TaskDom(t),
         epoch |-> depoch[TaskDom(t)],
         ctx |-> sc]]
    /\ UNCHANGED <<tstate, tgen, pgen, depoch, grant, budget, currentDom, selected, running>>

FreezeRunUse(t) ==
    /\ t \in Tasks
    /\ tstate[t] \in SchedulableStates
    /\ ValidCap(t)
    /\ budget[cap[t].ctx] > 0
    /\ AllowedSet(t, cap[t].ctx, TaskDom(t)) # {}
    /\ grant' = [grant EXCEPT ![t] =
        [valid |-> TRUE,
         taskGen |-> tgen[t],
         procGen |-> pgen[t],
         domain |-> TaskDom(t),
         epoch |-> depoch[TaskDom(t)],
         ctx |-> cap[t].ctx,
         allowed |-> AllowedSet(t, cap[t].ctx, TaskDom(t))]]
    /\ UNCHANGED <<tstate, tgen, pgen, depoch, cap, budget, currentDom, selected, running>>

WakeTask(t) ==
    /\ t \in Tasks
    /\ tstate[t] = "blocked"
    /\ tstate' = [tstate EXCEPT ![t] = "waking"]
    /\ UNCHANGED <<tgen, pgen, depoch, cap, grant, budget, currentDom, selected, running>>

RemoteWakeTask(t) ==
    /\ t \in Tasks
    /\ tstate[t] = "blocked"
    /\ tstate' = [tstate EXCEPT ![t] = "remote_wake_pending"]
    /\ UNCHANGED <<tgen, pgen, depoch, cap, grant, budget, currentDom, selected, running>>

DelayRunnable(t) ==
    /\ t \in Tasks
    /\ tstate[t] \in {"waking", "remote_wake_pending"}
    /\ tstate' = [tstate EXCEPT ![t] = "runnable_delayed"]
    /\ UNCHANGED <<tgen, pgen, depoch, cap, grant, budget, currentDom, selected, running>>

EnqueueTask(t) ==
    /\ t \in Tasks
    /\ tstate[t] \in {"waking", "remote_wake_pending", "runnable_delayed", "throttled", "migrating"}
    /\ ValidGrant(t)
    /\ t \notin SelectedTasks
    /\ t \notin RunningTasks
    /\ tstate' = [tstate EXCEPT ![t] = "queued"]
    /\ UNCHANGED <<tgen, pgen, depoch, cap, grant, budget, currentDom, selected, running>>

PickTask(c, t) ==
    /\ c \in CPUs
    /\ t \in Tasks
    /\ tstate[t] = "queued"
    /\ selected[c] = NoTask
    /\ running[c] = NoTask
    /\ t \notin SelectedTasks
    /\ t \notin RunningTasks
    /\ CanRunOn(t, c)
    /\ tstate' = [tstate EXCEPT ![t] = "selected"]
    /\ selected' = [selected EXCEPT ![c] = t]
    /\ UNCHANGED <<tgen, pgen, depoch, cap, grant, budget, currentDom, running>>

ActivateDomain(c) ==
    /\ c \in CPUs
    /\ selected[c] # NoTask
    /\ LET t == selected[c] IN
        /\ CanRunOn(t, c)
        /\ currentDom' = [currentDom EXCEPT ![c] = TaskDom(t)]
        /\ selected' = [selected EXCEPT ![c] = NoTask]
        /\ running' = [running EXCEPT ![c] = t]
        /\ tstate' = [tstate EXCEPT ![t] = "running"]
    /\ UNCHANGED <<tgen, pgen, depoch, cap, grant, budget>>

RunTick(c) ==
    /\ c \in CPUs
    /\ running[c] # NoTask
    /\ LET t == running[c] IN
       LET sc == grant[t].ctx IN
        /\ CanRunOn(t, c)
        /\ budget[sc] > 1
        /\ budget' = [budget EXCEPT ![sc] = budget[sc] - 1]
    /\ UNCHANGED <<tstate, tgen, pgen, depoch, cap, grant, currentDom, selected, running>>

BudgetExhaust(c) ==
    /\ c \in CPUs
    /\ running[c] # NoTask
    /\ LET t == running[c] IN
       LET sc == grant[t].ctx IN
        /\ CanRunOn(t, c)
        /\ budget[sc] = 1
        /\ budget' = [budget EXCEPT ![sc] = 0]
        /\ running' = [running EXCEPT ![c] = NoTask]
        /\ currentDom' = [currentDom EXCEPT ![c] = NoDomain]
        /\ tstate' = [tstate EXCEPT ![t] = "throttled"]
    /\ UNCHANGED <<tgen, pgen, depoch, cap, grant, selected>>

DequeueTask(t) ==
    /\ t \in Tasks
    /\ tstate[t] \in {"queued", "throttled", "runnable_delayed", "waking", "remote_wake_pending", "migrating"}
    /\ t \notin SelectedTasks
    /\ t \notin RunningTasks
    /\ tstate' = [tstate EXCEPT ![t] = "blocked"]
    /\ grant' = [grant EXCEPT ![t] = GrantNone]
    /\ UNCHANGED <<tgen, pgen, depoch, cap, budget, currentDom, selected, running>>

MigrateTask(t) ==
    /\ t \in Tasks
    /\ tstate[t] = "queued"
    /\ ValidGrant(t)
    /\ t \notin SelectedTasks
    /\ t \notin RunningTasks
    /\ tstate' = [tstate EXCEPT ![t] = "migrating"]
    /\ UNCHANGED <<tgen, pgen, depoch, cap, grant, budget, currentDom, selected, running>>

ExecTask(c) ==
    /\ c \in CPUs
    /\ running[c] # NoTask
    /\ LET t == running[c] IN
        /\ pgen[t] < MaxGen
        /\ LET newp == pgen[t] + 1 IN
            /\ pgen' = [pgen EXCEPT ![t] = newp]
            /\ grant' = [grant EXCEPT ![t].procGen = newp]
        /\ cap' = [cap EXCEPT ![t] = CapNone]
    /\ UNCHANGED <<tstate, tgen, depoch, budget, currentDom, selected, running>>

ExitTask(t) ==
    /\ t \in Tasks
    /\ tstate[t] \notin {"exiting", "dead_but_referenced"}
    /\ tstate' = [tstate EXCEPT ![t] = "exiting"]
    /\ cap' = [cap EXCEPT ![t] = CapNone]
    /\ grant' = [grant EXCEPT ![t] = GrantNone]
    /\ selected' = [c \in CPUs |-> IF selected[c] = t THEN NoTask ELSE selected[c]]
    /\ running' = [c \in CPUs |-> IF running[c] = t THEN NoTask ELSE running[c]]
    /\ currentDom' = [c \in CPUs |-> IF running[c] = t THEN NoDomain ELSE currentDom[c]]
    /\ UNCHANGED <<tgen, pgen, depoch, budget>>

RevokeDomainEpoch(d) ==
    /\ d \in Domains
    /\ depoch[d] < MaxEpoch
    /\ depoch' = [depoch EXCEPT ![d] = depoch[d] + 1]
    /\ cap' = [t \in Tasks |-> IF TaskDom(t) = d THEN CapNone ELSE cap[t]]
    /\ grant' = [t \in Tasks |-> IF TaskDom(t) = d THEN GrantNone ELSE grant[t]]
    /\ tstate' = [t \in Tasks |->
        IF TaskDom(t) = d /\ tstate[t] \in ActiveStates THEN "blocked" ELSE tstate[t]]
    /\ selected' = [c \in CPUs |->
        IF selected[c] # NoTask /\ TaskDom(selected[c]) = d THEN NoTask ELSE selected[c]]
    /\ running' = [c \in CPUs |->
        IF running[c] # NoTask /\ TaskDom(running[c]) = d THEN NoTask ELSE running[c]]
    /\ currentDom' = [c \in CPUs |-> IF currentDom[c] = d THEN NoDomain ELSE currentDom[c]]
    /\ UNCHANGED <<tgen, pgen, budget>>

RevokeTaskGeneration(t) ==
    /\ t \in Tasks
    /\ tgen[t] < MaxGen
    /\ tstate[t] \in {"blocked", "exiting", "dead_but_referenced"}
    /\ tgen' = [tgen EXCEPT ![t] = tgen[t] + 1]
    /\ tstate' = [tstate EXCEPT ![t] = "dead_but_referenced"]
    /\ cap' = [cap EXCEPT ![t] = CapNone]
    /\ grant' = [grant EXCEPT ![t] = GrantNone]
    /\ UNCHANGED <<pgen, depoch, budget, currentDom, selected, running>>

Next ==
    \/ \E t \in Tasks, sc \in SchedCtxs: IssueRunCap(t, sc)
    \/ \E t \in Tasks: FreezeRunUse(t)
    \/ \E t \in Tasks: WakeTask(t)
    \/ \E t \in Tasks: RemoteWakeTask(t)
    \/ \E t \in Tasks: DelayRunnable(t)
    \/ \E t \in Tasks: EnqueueTask(t)
    \/ \E c \in CPUs, t \in Tasks: PickTask(c, t)
    \/ \E c \in CPUs: ActivateDomain(c)
    \/ \E c \in CPUs: RunTick(c)
    \/ \E c \in CPUs: BudgetExhaust(c)
    \/ \E t \in Tasks: DequeueTask(t)
    \/ \E t \in Tasks: MigrateTask(t)
    \/ \E c \in CPUs: ExecTask(c)
    \/ \E t \in Tasks: ExitTask(t)
    \/ \E d \in Domains: RevokeDomainEpoch(d)
    \/ \E t \in Tasks: RevokeTaskGeneration(t)

Spec == Init /\ [][Next]_vars

Queued(t) == tstate[t] = "queued"
SelectedOn(c) == selected[c] # NoTask
RunningOn(c) == running[c] # NoTask

NoQueuedWithoutFrozenUse ==
    \A t \in Tasks: Queued(t) => ValidGrant(t)

NoSelectedWithoutSchedContext ==
    \A c \in CPUs:
        SelectedOn(c) =>
            LET t == selected[c] IN
                /\ ValidGrant(t)
                /\ grant[t].ctx \in SchedCtxs

NoSelectedWithExhaustedBudget ==
    \A c \in CPUs:
        SelectedOn(c) =>
            LET t == selected[c] IN budget[grant[t].ctx] > 0

NoSelectedWithMismatchedTaskGeneration ==
    \A c \in CPUs:
        SelectedOn(c) =>
            LET t == selected[c] IN grant[t].taskGen = tgen[t]

NoSelectedWithMismatchedDomainEpoch ==
    \A c \in CPUs:
        SelectedOn(c) =>
            LET t == selected[c] IN grant[t].epoch = depoch[TaskDom(t)]

NoRunningWithoutDomainActivation ==
    \A c \in CPUs:
        RunningOn(c) =>
            LET t == running[c] IN
                /\ tstate[t] = "running"
                /\ ValidGrant(t)
                /\ currentDom[c] = TaskDom(t)
                /\ CanRunOn(t, c)

NoGrantReuseAfterRevocation ==
    /\ \A c \in CPUs:
        SelectedOn(c) =>
            LET t == selected[c] IN
                /\ grant[t].taskGen = tgen[t]
                /\ grant[t].procGen = pgen[t]
                /\ grant[t].epoch = depoch[TaskDom(t)]
    /\ \A c \in CPUs:
        RunningOn(c) =>
            LET t == running[c] IN
                /\ grant[t].taskGen = tgen[t]
                /\ grant[t].procGen = pgen[t]
                /\ grant[t].epoch = depoch[TaskDom(t)]

NoBudgetUnderflow ==
    \A sc \in SchedCtxs: budget[sc] \in Budgets

NoCpuOutsidePlacement ==
    /\ \A c \in CPUs:
        SelectedOn(c) =>
            LET t == selected[c] IN CanRunOn(t, c)
    /\ \A c \in CPUs:
        RunningOn(c) =>
            LET t == running[c] IN CanRunOn(t, c)

NoTaskOnTwoCpus ==
    \A t \in Tasks:
        Cardinality({c \in CPUs: selected[c] = t}) +
        Cardinality({c \in CPUs: running[c] = t}) <= 1

StateMatchesCpuMaps ==
    /\ \A c \in CPUs: SelectedOn(c) => tstate[selected[c]] = "selected"
    /\ \A c \in CPUs: RunningOn(c) => tstate[running[c]] = "running"
    /\ \A t \in Tasks:
        tstate[t] = "selected" => Cardinality({c \in CPUs: selected[c] = t}) = 1
    /\ \A t \in Tasks:
        tstate[t] = "running" => Cardinality({c \in CPUs: running[c] = t}) = 1

=============================================================================
