-------------------------- MODULE DomainMonitor --------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS
    D1, D2,
    T1, T2,
    C1, C2,
    MV1, MV2,
    NoDomain,
    NoTask,
    NoCpu,
    NoMemView,
    MaxEpoch,
    MaxRootBudget

VARIABLES
    taskState,
    monitorEpoch,
    rootBudget,
    grant,
    selectedTask,
    activeTask,
    activeDomain,
    activeEpoch,
    activeMemView,
    runToken,
    linuxTag

vars == <<taskState, monitorEpoch, rootBudget, grant, selectedTask,
          activeTask, activeDomain, activeEpoch, activeMemView, runToken,
          linuxTag>>

Domains == {D1, D2}
Tasks == {T1, T2}
CPUs == {C1, C2}
MemViews == {MV1, MV2}

DomainOrNone == Domains \cup {NoDomain}
TaskOrNone == Tasks \cup {NoTask}
CpuOrNone == CPUs \cup {NoCpu}
MemViewOrNone == MemViews \cup {NoMemView}

Epochs == 0..MaxEpoch
Budgets == 0..MaxRootBudget
CpuSets == SUBSET CPUs
NonEmptyCpuSets == CpuSets \ {{}} 

States == {"blocked", "queued", "selected", "running", "throttled", "dead"}

TaskDomain(t) == IF t = T1 THEN D1 ELSE D2
DomainMemView(d) == IF d = D1 THEN MV1 ELSE MV2

GrantRecord == [
    valid: BOOLEAN,
    domain: DomainOrNone,
    epoch: Epochs,
    memView: MemViewOrNone,
    allowedCpus: CpuSets
]

TokenRecord == [
    valid: BOOLEAN,
    task: TaskOrNone,
    domain: DomainOrNone,
    epoch: Epochs,
    cpu: CpuOrNone,
    memView: MemViewOrNone
]

TagRecord == [
    domain: DomainOrNone,
    epoch: Epochs,
    memView: MemViewOrNone
]

GrantNone == [
    valid |-> FALSE,
    domain |-> NoDomain,
    epoch |-> 0,
    memView |-> NoMemView,
    allowedCpus |-> {}
]

TokenNone == [
    valid |-> FALSE,
    task |-> NoTask,
    domain |-> NoDomain,
    epoch |-> 0,
    cpu |-> NoCpu,
    memView |-> NoMemView
]

TagNone == [
    domain |-> NoDomain,
    epoch |-> 0,
    memView |-> NoMemView
]

TaskActive(t) ==
    t \in {activeTask[c] : c \in CPUs}

TaskSelected(t) ==
    t \in {selectedTask[c] : c \in CPUs}

ActiveTasks ==
    {activeTask[c] : c \in CPUs} \ {NoTask}

CpuIdle(c) ==
    /\ selectedTask[c] = NoTask
    /\ activeTask[c] = NoTask
    /\ activeDomain[c] = NoDomain
    /\ activeMemView[c] = NoMemView
    /\ ~runToken[c].valid

GrantMatchesTask(t) ==
    /\ t \in Tasks
    /\ grant[t].valid
    /\ grant[t].domain = TaskDomain(t)
    /\ grant[t].epoch = monitorEpoch[TaskDomain(t)]
    /\ grant[t].memView = DomainMemView(TaskDomain(t))

GrantAllowsCpu(t, c) ==
    /\ GrantMatchesTask(t)
    /\ c \in grant[t].allowedCpus

TokenMatchesActive(c) ==
    /\ c \in CPUs
    /\ runToken[c].valid
    /\ activeTask[c] \in Tasks
    /\ runToken[c].task = activeTask[c]
    /\ activeDomain[c] = runToken[c].domain
    /\ activeEpoch[c] = runToken[c].epoch
    /\ activeMemView[c] = runToken[c].memView
    /\ runToken[c].cpu = c

ActivationAllowed(c, t) ==
    /\ c \in CPUs
    /\ t \in Tasks
    /\ selectedTask[c] = t
    /\ activeTask[c] = NoTask
    /\ GrantAllowsCpu(t, c)
    /\ rootBudget[TaskDomain(t)] > 0
    /\ \A other \in CPUs \ {c}:
        activeDomain[other] = NoDomain \/ activeDomain[other] = TaskDomain(t)

TypeOK ==
    /\ D1 # D2
    /\ T1 # T2
    /\ C1 # C2
    /\ MV1 # MV2
    /\ NoDomain \notin Domains
    /\ NoTask \notin Tasks
    /\ NoCpu \notin CPUs
    /\ NoMemView \notin MemViews
    /\ MaxEpoch \in Nat
    /\ MaxRootBudget \in Nat
    /\ MaxRootBudget > 0
    /\ taskState \in [Tasks -> States]
    /\ monitorEpoch \in [Domains -> Epochs]
    /\ rootBudget \in [Domains -> Budgets]
    /\ grant \in [Tasks -> GrantRecord]
    /\ selectedTask \in [CPUs -> TaskOrNone]
    /\ activeTask \in [CPUs -> TaskOrNone]
    /\ activeDomain \in [CPUs -> DomainOrNone]
    /\ activeEpoch \in [CPUs -> Epochs]
    /\ activeMemView \in [CPUs -> MemViewOrNone]
    /\ runToken \in [CPUs -> TokenRecord]
    /\ linuxTag \in [CPUs -> TagRecord]

Init ==
    /\ taskState = [t \in Tasks |-> "blocked"]
    /\ monitorEpoch = [d \in Domains |-> 0]
    /\ rootBudget = [d \in Domains |-> MaxRootBudget]
    /\ grant = [t \in Tasks |-> GrantNone]
    /\ selectedTask = [c \in CPUs |-> NoTask]
    /\ activeTask = [c \in CPUs |-> NoTask]
    /\ activeDomain = [c \in CPUs |-> NoDomain]
    /\ activeEpoch = [c \in CPUs |-> 0]
    /\ activeMemView = [c \in CPUs |-> NoMemView]
    /\ runToken = [c \in CPUs |-> TokenNone]
    /\ linuxTag = [c \in CPUs |-> TagNone]

IssueGrant(t, allowed) ==
    /\ t \in Tasks
    /\ allowed \in NonEmptyCpuSets
    /\ taskState[t] \in {"blocked", "throttled"}
    /\ ~TaskActive(t)
    /\ ~TaskSelected(t)
    /\ grant' = [grant EXCEPT ![t] =
        [valid |-> TRUE,
         domain |-> TaskDomain(t),
         epoch |-> monitorEpoch[TaskDomain(t)],
         memView |-> DomainMemView(TaskDomain(t)),
         allowedCpus |-> allowed]]
    /\ taskState' = [taskState EXCEPT ![t] = "queued"]
    /\ UNCHANGED <<monitorEpoch, rootBudget, selectedTask, activeTask,
                    activeDomain, activeEpoch, activeMemView, runToken,
                    linuxTag>>

LinuxSelect(c, t) ==
    /\ c \in CPUs
    /\ t \in Tasks
    /\ selectedTask[c] = NoTask
    /\ activeTask[c] = NoTask
    /\ taskState[t] = "queued"
    /\ ~TaskSelected(t)
    /\ ~TaskActive(t)
    /\ selectedTask' = [selectedTask EXCEPT ![c] = t]
    /\ taskState' = [taskState EXCEPT ![t] = "selected"]
    /\ UNCHANGED <<monitorEpoch, rootBudget, grant, activeTask, activeDomain,
                    activeEpoch, activeMemView, runToken, linuxTag>>

LinuxDeselect(c) ==
    /\ c \in CPUs
    /\ selectedTask[c] # NoTask
    /\ LET t == selectedTask[c] IN
        /\ selectedTask' = [selectedTask EXCEPT ![c] = NoTask]
        /\ taskState' = [taskState EXCEPT ![t] =
            IF grant[t].valid THEN "queued" ELSE "blocked"]
    /\ UNCHANGED <<monitorEpoch, rootBudget, grant, activeTask, activeDomain,
                    activeEpoch, activeMemView, runToken, linuxTag>>

LinuxForgeTag(c, d, e, mv) ==
    /\ c \in CPUs
    /\ d \in DomainOrNone
    /\ e \in Epochs
    /\ mv \in MemViewOrNone
    /\ linuxTag' = [linuxTag EXCEPT ![c] =
        [domain |-> d, epoch |-> e, memView |-> mv]]
    /\ UNCHANGED <<taskState, monitorEpoch, rootBudget, grant, selectedTask,
                    activeTask, activeDomain, activeEpoch, activeMemView,
                    runToken>>

MonitorActivate(c) ==
    /\ c \in CPUs
    /\ selectedTask[c] # NoTask
    /\ LET t == selectedTask[c] IN
       LET d == TaskDomain(t) IN
        /\ ActivationAllowed(c, t)
        /\ selectedTask' = [selectedTask EXCEPT ![c] = NoTask]
        /\ activeTask' = [activeTask EXCEPT ![c] = t]
        /\ activeDomain' = [activeDomain EXCEPT ![c] = d]
        /\ activeEpoch' = [activeEpoch EXCEPT ![c] = monitorEpoch[d]]
        /\ activeMemView' = [activeMemView EXCEPT ![c] = DomainMemView(d)]
        /\ runToken' = [runToken EXCEPT ![c] =
            [valid |-> TRUE,
             task |-> t,
             domain |-> d,
             epoch |-> monitorEpoch[d],
             cpu |-> c,
             memView |-> DomainMemView(d)]]
        /\ taskState' = [taskState EXCEPT ![t] = "running"]
    /\ UNCHANGED <<monitorEpoch, rootBudget, grant, linuxTag>>

StopCpu(c) ==
    /\ c \in CPUs
    /\ activeTask[c] # NoTask
    /\ LET t == activeTask[c] IN
        /\ activeTask' = [activeTask EXCEPT ![c] = NoTask]
        /\ activeDomain' = [activeDomain EXCEPT ![c] = NoDomain]
        /\ activeEpoch' = [activeEpoch EXCEPT ![c] = 0]
        /\ activeMemView' = [activeMemView EXCEPT ![c] = NoMemView]
        /\ runToken' = [runToken EXCEPT ![c] = TokenNone]
        /\ taskState' = [taskState EXCEPT ![t] =
            IF GrantMatchesTask(t) /\ rootBudget[TaskDomain(t)] > 0
            THEN "queued"
            ELSE "blocked"]
    /\ UNCHANGED <<monitorEpoch, rootBudget, grant, selectedTask, linuxTag>>

CpuTick(c) ==
    /\ c \in CPUs
    /\ activeTask[c] # NoTask
    /\ TokenMatchesActive(c)
    /\ LET t == activeTask[c] IN
       LET d == activeDomain[c] IN
       LET newBudget == rootBudget[d] - 1 IN
        /\ rootBudget[d] > 0
        /\ rootBudget' = [rootBudget EXCEPT ![d] = newBudget]
        /\ IF newBudget = 0
           THEN
            /\ activeTask' = [activeTask EXCEPT ![c] = NoTask]
            /\ activeDomain' = [activeDomain EXCEPT ![c] = NoDomain]
            /\ activeEpoch' = [activeEpoch EXCEPT ![c] = 0]
            /\ activeMemView' = [activeMemView EXCEPT ![c] = NoMemView]
            /\ runToken' = [runToken EXCEPT ![c] = TokenNone]
            /\ taskState' = [taskState EXCEPT ![t] = "throttled"]
           ELSE
            /\ UNCHANGED <<activeTask, activeDomain, activeEpoch,
                            activeMemView, runToken>>
            /\ UNCHANGED taskState
    /\ UNCHANGED <<monitorEpoch, grant, selectedTask, linuxTag>>

RefillRootBudget(d) ==
    /\ d \in Domains
    /\ rootBudget[d] < MaxRootBudget
    /\ rootBudget' = [rootBudget EXCEPT ![d] = MaxRootBudget]
    /\ taskState' = [t \in Tasks |->
        IF TaskDomain(t) = d /\ taskState[t] = "throttled" /\ GrantMatchesTask(t)
        THEN "queued"
        ELSE taskState[t]]
    /\ UNCHANGED <<monitorEpoch, grant, selectedTask, activeTask, activeDomain,
                    activeEpoch, activeMemView, runToken, linuxTag>>

RevokeDomain(d) ==
    /\ d \in Domains
    /\ monitorEpoch[d] < MaxEpoch
    /\ monitorEpoch' = [monitorEpoch EXCEPT ![d] = @ + 1]
    /\ grant' = [t \in Tasks |->
        IF TaskDomain(t) = d THEN GrantNone ELSE grant[t]]
    /\ selectedTask' = [c \in CPUs |->
        IF selectedTask[c] # NoTask /\ TaskDomain(selectedTask[c]) = d
        THEN NoTask
        ELSE selectedTask[c]]
    /\ activeTask' = [c \in CPUs |->
        IF activeTask[c] # NoTask /\ activeDomain[c] = d
        THEN NoTask
        ELSE activeTask[c]]
    /\ activeDomain' = [c \in CPUs |->
        IF activeDomain[c] = d THEN NoDomain ELSE activeDomain[c]]
    /\ activeEpoch' = [c \in CPUs |->
        IF activeDomain[c] = d THEN 0 ELSE activeEpoch[c]]
    /\ activeMemView' = [c \in CPUs |->
        IF activeDomain[c] = d THEN NoMemView ELSE activeMemView[c]]
    /\ runToken' = [c \in CPUs |->
        IF runToken[c].valid /\ runToken[c].domain = d
        THEN TokenNone
        ELSE runToken[c]]
    /\ taskState' = [t \in Tasks |->
        IF TaskDomain(t) = d /\ taskState[t] # "dead"
        THEN "blocked"
        ELSE taskState[t]]
    /\ UNCHANGED <<rootBudget, linuxTag>>

KillTask(t) ==
    /\ t \in Tasks
    /\ taskState[t] # "dead"
    /\ taskState' = [taskState EXCEPT ![t] = "dead"]
    /\ grant' = [grant EXCEPT ![t] = GrantNone]
    /\ selectedTask' = [c \in CPUs |->
        IF selectedTask[c] = t THEN NoTask ELSE selectedTask[c]]
    /\ activeTask' = [c \in CPUs |->
        IF activeTask[c] = t THEN NoTask ELSE activeTask[c]]
    /\ activeDomain' = [c \in CPUs |->
        IF activeTask[c] = t THEN NoDomain ELSE activeDomain[c]]
    /\ activeEpoch' = [c \in CPUs |->
        IF activeTask[c] = t THEN 0 ELSE activeEpoch[c]]
    /\ activeMemView' = [c \in CPUs |->
        IF activeTask[c] = t THEN NoMemView ELSE activeMemView[c]]
    /\ runToken' = [c \in CPUs |->
        IF runToken[c].valid /\ runToken[c].task = t
        THEN TokenNone
        ELSE runToken[c]]
    /\ UNCHANGED <<monitorEpoch, rootBudget, linuxTag>>

Next ==
    \/ \E t \in Tasks, allowed \in NonEmptyCpuSets:
        IssueGrant(t, allowed)
    \/ \E c \in CPUs, t \in Tasks:
        LinuxSelect(c, t)
    \/ \E c \in CPUs:
        LinuxDeselect(c)
    \/ \E c \in CPUs, d \in DomainOrNone, e \in Epochs, mv \in MemViewOrNone:
        LinuxForgeTag(c, d, e, mv)
    \/ \E c \in CPUs:
        MonitorActivate(c)
    \/ \E c \in CPUs:
        StopCpu(c)
    \/ \E c \in CPUs:
        CpuTick(c)
    \/ \E d \in Domains:
        RefillRootBudget(d)
    \/ \E d \in Domains:
        RevokeDomain(d)
    \/ \E t \in Tasks:
        KillTask(t)

Spec == Init /\ [][Next]_vars

NoActiveWithoutMonitorToken ==
    \A c \in CPUs:
        activeTask[c] # NoTask => TokenMatchesActive(c)

NoActiveWithoutGrant ==
    \A c \in CPUs:
        activeTask[c] # NoTask =>
            LET t == activeTask[c] IN
                /\ GrantMatchesTask(t)
                /\ runToken[c].domain = grant[t].domain
                /\ runToken[c].epoch = grant[t].epoch
                /\ runToken[c].memView = grant[t].memView

NoActiveWithStaleEpoch ==
    \A c \in CPUs:
        activeTask[c] # NoTask =>
            activeEpoch[c] = monitorEpoch[activeDomain[c]]

NoActiveWithWrongMemoryView ==
    \A c \in CPUs:
        activeTask[c] # NoTask =>
            activeMemView[c] = DomainMemView(activeDomain[c])

NoActiveOutsideAllowedCpu ==
    \A c \in CPUs:
        activeTask[c] # NoTask =>
            c \in grant[activeTask[c]].allowedCpus

NoActiveWithoutRootBudget ==
    \A c \in CPUs:
        activeTask[c] # NoTask =>
            rootBudget[activeDomain[c]] > 0

NoTokenAfterRevocation ==
    \A c \in CPUs:
        runToken[c].valid =>
            runToken[c].epoch = monitorEpoch[runToken[c].domain]

NoLinuxTagConfersAuthority ==
    \A c \in CPUs:
        ~runToken[c].valid =>
            /\ activeTask[c] = NoTask
            /\ activeDomain[c] = NoDomain
            /\ activeMemView[c] = NoMemView

NoForbiddenCoTenancy ==
    \A c1 \in CPUs:
        \A c2 \in CPUs:
            /\ activeDomain[c1] # NoDomain
            /\ activeDomain[c2] # NoDomain
            => activeDomain[c1] = activeDomain[c2]

NoTaskOnTwoCpus ==
    \A t \in Tasks:
        Cardinality({c \in CPUs : activeTask[c] = t}) <= 1

NoBudgetUnderflow ==
    /\ \A d \in Domains:
        rootBudget[d] >= 0
    /\ \A c \in CPUs:
        activeTask[c] # NoTask => rootBudget[activeDomain[c]] >= 0

=============================================================================
