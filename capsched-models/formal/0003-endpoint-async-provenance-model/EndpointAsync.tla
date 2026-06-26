--------------------------- MODULE EndpointAsync ---------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS
    T1, T2,
    D1, D2,
    E1, E2,
    R1, R2,
    Q1, Q2,
    W1, W2,
    Send, Recv, Cmd,
    NoDomain,
    NoEndpoint,
    NoResource,
    NoRequest,
    NoOp,
    MaxEpoch,
    MaxGen,
    MaxTicket

VARIABLES
    reqState,
    domainEpoch,
    resourceGen,
    registered,
    frozenUse,
    workerReq,
    activeDomain,
    credDomain,
    ticketLeft

vars == <<reqState, domainEpoch, resourceGen, registered, frozenUse,
          workerReq, activeDomain, credDomain, ticketLeft>>

Tasks == {T1, T2}
Domains == {D1, D2}
Endpoints == {E1, E2}
Resources == {R1, R2}
Requests == {Q1, Q2}
Workers == {W1, W2}
Ops == {Send, Recv, Cmd}

DomainOrNone == Domains \cup {NoDomain}
EndpointOrNone == Endpoints \cup {NoEndpoint}
ResourceOrNone == Resources \cup {NoResource}
RequestOrNone == Requests \cup {NoRequest}
OpOrNone == Ops \cup {NoOp}

Epochs == 0..MaxEpoch
Gens == 0..MaxGen
Tickets == 0..MaxTicket

States == {
    "idle",
    "registered",
    "submitted",
    "queued_worker",
    "executing",
    "completed",
    "cancelled"
}

PendingStates == {"registered", "submitted", "queued_worker", "executing"}
UseRequiredStates == {"submitted", "queued_worker", "executing"}

TaskDomain(t) == IF t = T1 THEN D1 ELSE D2
EndpointOwner(e) == IF e = E1 THEN D1 ELSE D2
EndpointResource(e) == IF e = E1 THEN R1 ELSE R2
WorkerServiceDomain(w) == IF w = W1 THEN D1 ELSE D2

EndpointAllows(d, e, op) ==
    /\ d \in Domains
    /\ e \in Endpoints
    /\ op \in Ops
    /\ d = EndpointOwner(e)
    /\ (op \in {Send, Recv} \/ (op = Cmd /\ e = E2))

ServiceAllows(s, e, op) ==
    /\ s \in Domains
    /\ e \in Endpoints
    /\ op \in Ops
    /\ s = EndpointOwner(e)
    /\ (op \in {Send, Recv} \/ (op = Cmd /\ e = E2))

RegRecord == [
    valid: BOOLEAN,
    domain: DomainOrNone,
    epoch: Epochs,
    endpoint: EndpointOrNone,
    resource: ResourceOrNone,
    resourceGen: Gens
]

UseRecord == [
    valid: BOOLEAN,
    domain: DomainOrNone,
    epoch: Epochs,
    endpoint: EndpointOrNone,
    resource: ResourceOrNone,
    resourceGen: Gens,
    op: OpOrNone,
    serviceDomain: DomainOrNone
]

RegNone == [
    valid |-> FALSE,
    domain |-> NoDomain,
    epoch |-> 0,
    endpoint |-> NoEndpoint,
    resource |-> NoResource,
    resourceGen |-> 0
]

UseNone == [
    valid |-> FALSE,
    domain |-> NoDomain,
    epoch |-> 0,
    endpoint |-> NoEndpoint,
    resource |-> NoResource,
    resourceGen |-> 0,
    op |-> NoOp,
    serviceDomain |-> NoDomain
]

ValidRegistration(q) ==
    /\ q \in Requests
    /\ registered[q].valid
    /\ registered[q].domain \in Domains
    /\ registered[q].epoch = domainEpoch[registered[q].domain]
    /\ registered[q].endpoint \in Endpoints
    /\ registered[q].resource \in Resources
    /\ registered[q].resource = EndpointResource(registered[q].endpoint)
    /\ registered[q].resourceGen = resourceGen[registered[q].resource]
    /\ EndpointOwner(registered[q].endpoint) = registered[q].domain

ValidFrozenUse(q) ==
    /\ q \in Requests
    /\ frozenUse[q].valid
    /\ frozenUse[q].domain \in Domains
    /\ frozenUse[q].epoch = domainEpoch[frozenUse[q].domain]
    /\ frozenUse[q].endpoint \in Endpoints
    /\ frozenUse[q].resource \in Resources
    /\ frozenUse[q].resource = EndpointResource(frozenUse[q].endpoint)
    /\ frozenUse[q].resourceGen = resourceGen[frozenUse[q].resource]
    /\ frozenUse[q].op \in Ops
    /\ frozenUse[q].serviceDomain \in Domains
    /\ EndpointAllows(frozenUse[q].domain,
                      frozenUse[q].endpoint,
                      frozenUse[q].op)
    /\ ServiceAllows(frozenUse[q].serviceDomain,
                     frozenUse[q].endpoint,
                     frozenUse[q].op)
    /\ ticketLeft[q] > 0

ReqDomain(q) ==
    IF frozenUse[q].valid THEN frozenUse[q].domain
    ELSE IF registered[q].valid THEN registered[q].domain
    ELSE NoDomain

ReqResource(q) ==
    IF frozenUse[q].valid THEN frozenUse[q].resource
    ELSE IF registered[q].valid THEN registered[q].resource
    ELSE NoResource

ReqUsesDomain(q, d) ==
    /\ q \in Requests
    /\ d \in Domains
    /\ ReqDomain(q) = d

ReqUsesResource(q, r) ==
    /\ q \in Requests
    /\ r \in Resources
    /\ ReqResource(q) = r

WorkerRequests == {workerReq[w] : w \in Workers} \ {NoRequest}

WorkerOf(q) ==
    CHOOSE w \in Workers : workerReq[w] = q

TypeOK ==
    /\ T1 # T2
    /\ D1 # D2
    /\ E1 # E2
    /\ R1 # R2
    /\ Q1 # Q2
    /\ W1 # W2
    /\ Send # Recv
    /\ Send # Cmd
    /\ Recv # Cmd
    /\ NoDomain \notin Domains
    /\ NoEndpoint \notin Endpoints
    /\ NoResource \notin Resources
    /\ NoRequest \notin Requests
    /\ NoOp \notin Ops
    /\ MaxEpoch \in Nat
    /\ MaxGen \in Nat
    /\ MaxTicket \in Nat
    /\ MaxTicket > 0
    /\ reqState \in [Requests -> States]
    /\ domainEpoch \in [Domains -> Epochs]
    /\ resourceGen \in [Resources -> Gens]
    /\ registered \in [Requests -> RegRecord]
    /\ frozenUse \in [Requests -> UseRecord]
    /\ workerReq \in [Workers -> RequestOrNone]
    /\ activeDomain \in [Workers -> DomainOrNone]
    /\ credDomain \in [Requests -> DomainOrNone]
    /\ ticketLeft \in [Requests -> Tickets]

Init ==
    /\ reqState = [q \in Requests |-> "idle"]
    /\ domainEpoch = [d \in Domains |-> 0]
    /\ resourceGen = [r \in Resources |-> 0]
    /\ registered = [q \in Requests |-> RegNone]
    /\ frozenUse = [q \in Requests |-> UseNone]
    /\ workerReq = [w \in Workers |-> NoRequest]
    /\ activeDomain = [w \in Workers |-> NoDomain]
    /\ credDomain = [q \in Requests |-> NoDomain]
    /\ ticketLeft = [q \in Requests |-> 0]

RegisterEndpoint(q, t, e) ==
    /\ q \in Requests
    /\ t \in Tasks
    /\ e \in Endpoints
    /\ reqState[q] = "idle"
    /\ TaskDomain(t) = EndpointOwner(e)
    /\ reqState' = [reqState EXCEPT ![q] = "registered"]
    /\ registered' = [registered EXCEPT ![q] =
        [valid |-> TRUE,
         domain |-> TaskDomain(t),
         epoch |-> domainEpoch[TaskDomain(t)],
         endpoint |-> e,
         resource |-> EndpointResource(e),
         resourceGen |-> resourceGen[EndpointResource(e)]]]
    /\ credDomain' = [credDomain EXCEPT ![q] = TaskDomain(t)]
    /\ UNCHANGED <<domainEpoch, resourceGen, frozenUse, workerReq,
                    activeDomain, ticketLeft>>

SubmitRequest(q, op) ==
    /\ q \in Requests
    /\ op \in Ops
    /\ reqState[q] = "registered"
    /\ ValidRegistration(q)
    /\ EndpointAllows(registered[q].domain, registered[q].endpoint, op)
    /\ ticketLeft[q] = 0
    /\ reqState' = [reqState EXCEPT ![q] = "submitted"]
    /\ frozenUse' = [frozenUse EXCEPT ![q] =
        [valid |-> TRUE,
         domain |-> registered[q].domain,
         epoch |-> domainEpoch[registered[q].domain],
         endpoint |-> registered[q].endpoint,
         resource |-> registered[q].resource,
         resourceGen |-> resourceGen[registered[q].resource],
         op |-> op,
         serviceDomain |-> EndpointOwner(registered[q].endpoint)]]
    /\ ticketLeft' = [ticketLeft EXCEPT ![q] = MaxTicket]
    /\ UNCHANGED <<domainEpoch, resourceGen, registered, workerReq,
                    activeDomain, credDomain>>

QueueAsync(q) ==
    /\ q \in Requests
    /\ reqState[q] = "submitted"
    /\ ValidFrozenUse(q)
    /\ reqState' = [reqState EXCEPT ![q] = "queued_worker"]
    /\ UNCHANGED <<domainEpoch, resourceGen, registered, frozenUse, workerReq,
                    activeDomain, credDomain, ticketLeft>>

StartWorker(w, q) ==
    /\ w \in Workers
    /\ q \in Requests
    /\ reqState[q] = "queued_worker"
    /\ workerReq[w] = NoRequest
    /\ q \notin WorkerRequests
    /\ ValidFrozenUse(q)
    /\ ServiceAllows(WorkerServiceDomain(w),
                     frozenUse[q].endpoint,
                     frozenUse[q].op)
    /\ reqState' = [reqState EXCEPT ![q] = "executing"]
    /\ workerReq' = [workerReq EXCEPT ![w] = q]
    /\ activeDomain' = [activeDomain EXCEPT ![w] = frozenUse[q].domain]
    /\ UNCHANGED <<domainEpoch, resourceGen, registered, frozenUse,
                    credDomain, ticketLeft>>

CompleteRequest(w) ==
    /\ w \in Workers
    /\ workerReq[w] # NoRequest
    /\ LET q == workerReq[w] IN
        /\ reqState[q] = "executing"
        /\ ValidFrozenUse(q)
        /\ ticketLeft[q] > 0
        /\ reqState' = [reqState EXCEPT ![q] = "completed"]
        /\ ticketLeft' = [ticketLeft EXCEPT ![q] = 0]
    /\ workerReq' = [workerReq EXCEPT ![w] = NoRequest]
    /\ activeDomain' = [activeDomain EXCEPT ![w] = NoDomain]
    /\ UNCHANGED <<domainEpoch, resourceGen, registered, frozenUse,
                    credDomain>>

OverrideCred(q, d) ==
    /\ q \in Requests
    /\ d \in Domains
    /\ reqState[q] \in PendingStates
    /\ credDomain' = [credDomain EXCEPT ![q] = d]
    /\ UNCHANGED <<reqState, domainEpoch, resourceGen, registered, frozenUse,
                    workerReq, activeDomain, ticketLeft>>

CancelRequest(q) ==
    /\ q \in Requests
    /\ reqState[q] \in PendingStates
    /\ reqState' = [reqState EXCEPT ![q] = "cancelled"]
    /\ registered' = [registered EXCEPT ![q] = RegNone]
    /\ frozenUse' = [frozenUse EXCEPT ![q] = UseNone]
    /\ ticketLeft' = [ticketLeft EXCEPT ![q] = 0]
    /\ workerReq' = [w \in Workers |->
        IF workerReq[w] = q THEN NoRequest ELSE workerReq[w]]
    /\ activeDomain' = [w \in Workers |->
        IF workerReq[w] = q THEN NoDomain ELSE activeDomain[w]]
    /\ UNCHANGED <<domainEpoch, resourceGen, credDomain>>

RevokeDomain(d) ==
    /\ d \in Domains
    /\ domainEpoch[d] < MaxEpoch
    /\ domainEpoch' = [domainEpoch EXCEPT ![d] = domainEpoch[d] + 1]
    /\ reqState' = [q \in Requests |->
        IF reqState[q] \in PendingStates /\ ReqUsesDomain(q, d)
        THEN "cancelled"
        ELSE reqState[q]]
    /\ registered' = [q \in Requests |->
        IF ReqUsesDomain(q, d) THEN RegNone ELSE registered[q]]
    /\ frozenUse' = [q \in Requests |->
        IF ReqUsesDomain(q, d) THEN UseNone ELSE frozenUse[q]]
    /\ ticketLeft' = [q \in Requests |->
        IF ReqUsesDomain(q, d) THEN 0 ELSE ticketLeft[q]]
    /\ workerReq' = [w \in Workers |->
        IF workerReq[w] # NoRequest /\ ReqUsesDomain(workerReq[w], d)
        THEN NoRequest
        ELSE workerReq[w]]
    /\ activeDomain' = [w \in Workers |->
        IF workerReq[w] # NoRequest /\ ReqUsesDomain(workerReq[w], d)
        THEN NoDomain
        ELSE activeDomain[w]]
    /\ UNCHANGED <<resourceGen, credDomain>>

RevokeResource(r) ==
    /\ r \in Resources
    /\ resourceGen[r] < MaxGen
    /\ resourceGen' = [resourceGen EXCEPT ![r] = resourceGen[r] + 1]
    /\ reqState' = [q \in Requests |->
        IF reqState[q] \in PendingStates /\ ReqUsesResource(q, r)
        THEN "cancelled"
        ELSE reqState[q]]
    /\ registered' = [q \in Requests |->
        IF ReqUsesResource(q, r) THEN RegNone ELSE registered[q]]
    /\ frozenUse' = [q \in Requests |->
        IF ReqUsesResource(q, r) THEN UseNone ELSE frozenUse[q]]
    /\ ticketLeft' = [q \in Requests |->
        IF ReqUsesResource(q, r) THEN 0 ELSE ticketLeft[q]]
    /\ workerReq' = [w \in Workers |->
        IF workerReq[w] # NoRequest /\ ReqUsesResource(workerReq[w], r)
        THEN NoRequest
        ELSE workerReq[w]]
    /\ activeDomain' = [w \in Workers |->
        IF workerReq[w] # NoRequest /\ ReqUsesResource(workerReq[w], r)
        THEN NoDomain
        ELSE activeDomain[w]]
    /\ UNCHANGED <<domainEpoch, credDomain>>

Next ==
    \/ \E q \in Requests, t \in Tasks, e \in Endpoints:
        RegisterEndpoint(q, t, e)
    \/ \E q \in Requests, op \in Ops:
        SubmitRequest(q, op)
    \/ \E q \in Requests:
        QueueAsync(q)
    \/ \E w \in Workers, q \in Requests:
        StartWorker(w, q)
    \/ \E w \in Workers:
        CompleteRequest(w)
    \/ \E q \in Requests, d \in Domains:
        OverrideCred(q, d)
    \/ \E q \in Requests:
        CancelRequest(q)
    \/ \E d \in Domains:
        RevokeDomain(d)
    \/ \E r \in Resources:
        RevokeResource(r)

Spec == Init /\ [][Next]_vars

NoPendingRequestWithoutAuthority ==
    \A q \in Requests:
        /\ reqState[q] = "registered" => ValidRegistration(q)
        /\ reqState[q] \in UseRequiredStates => ValidFrozenUse(q)

NoExecutionWithoutFrozenEndpointUse ==
    \A q \in Requests:
        reqState[q] = "executing" => ValidFrozenUse(q)

NoExecutionWithStaleDomainEpoch ==
    \A q \in Requests:
        reqState[q] = "executing" =>
            frozenUse[q].epoch = domainEpoch[frozenUse[q].domain]

NoExecutionWithStaleResourceGeneration ==
    \A q \in Requests:
        reqState[q] = "executing" =>
            frozenUse[q].resourceGen = resourceGen[frozenUse[q].resource]

NoExecutionWithoutBudgetTicket ==
    \A q \in Requests:
        reqState[q] = "executing" => ticketLeft[q] > 0

NoWorkerAmbientAuthority ==
    \A w \in Workers:
        workerReq[w] # NoRequest =>
            LET q == workerReq[w] IN
                /\ reqState[q] = "executing"
                /\ ValidFrozenUse(q)
                /\ ServiceAllows(WorkerServiceDomain(w),
                                 frozenUse[q].endpoint,
                                 frozenUse[q].op)

NoCredentialOverrideChangesActiveDomain ==
    \A w \in Workers:
        workerReq[w] # NoRequest =>
            LET q == workerReq[w] IN
                activeDomain[w] = frozenUse[q].domain

NoWorkerUsesOtherDomainEndpoint ==
    \A w \in Workers:
        workerReq[w] # NoRequest =>
            LET q == workerReq[w] IN
                /\ EndpointOwner(frozenUse[q].endpoint) = frozenUse[q].domain
                /\ WorkerServiceDomain(w) = frozenUse[q].serviceDomain

NoTwoWorkersForOneRequest ==
    \A q \in Requests:
        Cardinality({w \in Workers : workerReq[w] = q}) <= 1

NoCancelledRequestOnWorker ==
    \A q \in Requests:
        reqState[q] = "cancelled" =>
            q \notin WorkerRequests

=============================================================================
