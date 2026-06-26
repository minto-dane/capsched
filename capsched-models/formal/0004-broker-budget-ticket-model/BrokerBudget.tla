--------------------------- MODULE BrokerBudget ---------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS
    D1, D2,
    S1, S2,
    E1, E2,
    Q1, Q2,
    Read, Write,
    NoDomain,
    NoService,
    NoEndpoint,
    NoRequest,
    NoOp,
    MaxEpoch,
    MaxCallerBudget,
    MaxServiceBudget

VARIABLES
    reqState,
    callerEpoch,
    serviceEpoch,
    callerBudget,
    serviceBudget,
    ticket,
    frozenUse,
    activeReq,
    spent,
    forfeited

vars == <<reqState, callerEpoch, serviceEpoch, callerBudget, serviceBudget,
          ticket, frozenUse, activeReq, spent, forfeited>>

Callers == {D1, D2}
Services == {S1, S2}
Endpoints == {E1, E2}
Requests == {Q1, Q2}
Ops == {Read, Write}

DomainOrNone == Callers \cup {NoDomain}
ServiceOrNone == Services \cup {NoService}
EndpointOrNone == Endpoints \cup {NoEndpoint}
RequestOrNone == Requests \cup {NoRequest}
OpOrNone == Ops \cup {NoOp}

Epochs == 0..MaxEpoch
CallerBudgets == 0..MaxCallerBudget
ServiceBudgets == 0..MaxServiceBudget
TicketAmounts == 1..MaxCallerBudget

States == {
    "idle",
    "submitted",
    "queued_service",
    "executing",
    "service_throttled",
    "completed",
    "cancelled"
}

PendingStates == {"submitted", "queued_service", "executing", "service_throttled"}
TerminalStates == {"completed", "cancelled"}

EndpointOwner(e) == IF e = E1 THEN D1 ELSE D2
EndpointService(e) == IF e = E1 THEN S1 ELSE S2

CallerAllows(d, e, op) ==
    /\ d \in Callers
    /\ e \in Endpoints
    /\ op \in Ops
    /\ d = EndpointOwner(e)

ServiceAllows(s, e, op) ==
    /\ s \in Services
    /\ e \in Endpoints
    /\ op \in Ops
    /\ s = EndpointService(e)

TicketRecord == [
    valid: BOOLEAN,
    caller: DomainOrNone,
    callerEpoch: Epochs,
    service: ServiceOrNone,
    serviceEpoch: Epochs,
    endpoint: EndpointOrNone,
    op: OpOrNone,
    remaining: CallerBudgets
]

UseRecord == [
    valid: BOOLEAN,
    caller: DomainOrNone,
    callerEpoch: Epochs,
    service: ServiceOrNone,
    serviceEpoch: Epochs,
    endpoint: EndpointOrNone,
    op: OpOrNone
]

TicketNone == [
    valid |-> FALSE,
    caller |-> NoDomain,
    callerEpoch |-> 0,
    service |-> NoService,
    serviceEpoch |-> 0,
    endpoint |-> NoEndpoint,
    op |-> NoOp,
    remaining |-> 0
]

UseNone == [
    valid |-> FALSE,
    caller |-> NoDomain,
    callerEpoch |-> 0,
    service |-> NoService,
    serviceEpoch |-> 0,
    endpoint |-> NoEndpoint,
    op |-> NoOp
]

TicketMatchesUse(q) ==
    /\ ticket[q].valid
    /\ frozenUse[q].valid
    /\ ticket[q].caller = frozenUse[q].caller
    /\ ticket[q].callerEpoch = frozenUse[q].callerEpoch
    /\ ticket[q].service = frozenUse[q].service
    /\ ticket[q].serviceEpoch = frozenUse[q].serviceEpoch
    /\ ticket[q].endpoint = frozenUse[q].endpoint
    /\ ticket[q].op = frozenUse[q].op

ValidTicket(q) ==
    /\ q \in Requests
    /\ ticket[q].valid
    /\ ticket[q].caller \in Callers
    /\ ticket[q].service \in Services
    /\ ticket[q].endpoint \in Endpoints
    /\ ticket[q].op \in Ops
    /\ ticket[q].remaining > 0
    /\ ticket[q].callerEpoch = callerEpoch[ticket[q].caller]
    /\ ticket[q].serviceEpoch = serviceEpoch[ticket[q].service]
    /\ CallerAllows(ticket[q].caller, ticket[q].endpoint, ticket[q].op)
    /\ ServiceAllows(ticket[q].service, ticket[q].endpoint, ticket[q].op)

ValidFrozenUse(q) ==
    /\ q \in Requests
    /\ frozenUse[q].valid
    /\ frozenUse[q].caller \in Callers
    /\ frozenUse[q].service \in Services
    /\ frozenUse[q].endpoint \in Endpoints
    /\ frozenUse[q].op \in Ops
    /\ frozenUse[q].callerEpoch = callerEpoch[frozenUse[q].caller]
    /\ frozenUse[q].serviceEpoch = serviceEpoch[frozenUse[q].service]
    /\ CallerAllows(frozenUse[q].caller, frozenUse[q].endpoint, frozenUse[q].op)
    /\ ServiceAllows(frozenUse[q].service, frozenUse[q].endpoint, frozenUse[q].op)
    /\ TicketMatchesUse(q)

CanExecute(s, q) ==
    /\ s \in Services
    /\ q \in Requests
    /\ reqState[q] \in {"queued_service", "service_throttled", "executing"}
    /\ ValidTicket(q)
    /\ ValidFrozenUse(q)
    /\ ticket[q].service = s
    /\ serviceBudget[s] > 0

ActiveRequests == {activeReq[s] : s \in Services} \ {NoRequest}

RemainingForCaller(d) ==
    (IF ticket[Q1].valid /\ ticket[Q1].caller = d THEN ticket[Q1].remaining ELSE 0) +
    (IF ticket[Q2].valid /\ ticket[Q2].caller = d THEN ticket[Q2].remaining ELSE 0)

RemainingForCallerService(d, s) ==
    (IF ticket[Q1].valid /\ ticket[Q1].caller = d /\ ticket[Q1].service = s
     THEN ticket[Q1].remaining ELSE 0) +
    (IF ticket[Q2].valid /\ ticket[Q2].caller = d /\ ticket[Q2].service = s
     THEN ticket[Q2].remaining ELSE 0)

RequestUsesCaller(q, d) ==
    /\ q \in Requests
    /\ d \in Callers
    /\ ticket[q].valid
    /\ ticket[q].caller = d

RequestUsesService(q, s) ==
    /\ q \in Requests
    /\ s \in Services
    /\ ticket[q].valid
    /\ ticket[q].service = s

TypeOK ==
    /\ D1 # D2
    /\ S1 # S2
    /\ E1 # E2
    /\ Q1 # Q2
    /\ Read # Write
    /\ NoDomain \notin Callers
    /\ NoService \notin Services
    /\ NoEndpoint \notin Endpoints
    /\ NoRequest \notin Requests
    /\ NoOp \notin Ops
    /\ MaxEpoch \in Nat
    /\ MaxCallerBudget \in Nat
    /\ MaxCallerBudget > 0
    /\ MaxServiceBudget \in Nat
    /\ MaxServiceBudget > 0
    /\ reqState \in [Requests -> States]
    /\ callerEpoch \in [Callers -> Epochs]
    /\ serviceEpoch \in [Services -> Epochs]
    /\ callerBudget \in [Callers -> CallerBudgets]
    /\ serviceBudget \in [Services -> ServiceBudgets]
    /\ ticket \in [Requests -> TicketRecord]
    /\ frozenUse \in [Requests -> UseRecord]
    /\ activeReq \in [Services -> RequestOrNone]
    /\ spent \in [Callers -> CallerBudgets]
    /\ forfeited \in [Callers -> CallerBudgets]

Init ==
    /\ reqState = [q \in Requests |-> "idle"]
    /\ callerEpoch = [d \in Callers |-> 0]
    /\ serviceEpoch = [s \in Services |-> 0]
    /\ callerBudget = [d \in Callers |-> MaxCallerBudget]
    /\ serviceBudget = [s \in Services |-> MaxServiceBudget]
    /\ ticket = [q \in Requests |-> TicketNone]
    /\ frozenUse = [q \in Requests |-> UseNone]
    /\ activeReq = [s \in Services |-> NoRequest]
    /\ spent = [d \in Callers |-> 0]
    /\ forfeited = [d \in Callers |-> 0]

SubmitBrokerRequest(q, d, s, e, op, amount) ==
    /\ q \in Requests
    /\ d \in Callers
    /\ s \in Services
    /\ e \in Endpoints
    /\ op \in Ops
    /\ amount \in TicketAmounts
    /\ reqState[q] = "idle"
    /\ callerBudget[d] >= amount
    /\ CallerAllows(d, e, op)
    /\ ServiceAllows(s, e, op)
    /\ reqState' = [reqState EXCEPT ![q] = "submitted"]
    /\ callerBudget' = [callerBudget EXCEPT ![d] = @ - amount]
    /\ ticket' = [ticket EXCEPT ![q] =
        [valid |-> TRUE,
         caller |-> d,
         callerEpoch |-> callerEpoch[d],
         service |-> s,
         serviceEpoch |-> serviceEpoch[s],
         endpoint |-> e,
         op |-> op,
         remaining |-> amount]]
    /\ frozenUse' = [frozenUse EXCEPT ![q] =
        [valid |-> TRUE,
         caller |-> d,
         callerEpoch |-> callerEpoch[d],
         service |-> s,
         serviceEpoch |-> serviceEpoch[s],
         endpoint |-> e,
         op |-> op]]
    /\ UNCHANGED <<callerEpoch, serviceEpoch, serviceBudget, activeReq,
                    spent, forfeited>>

QueueService(q) ==
    /\ q \in Requests
    /\ reqState[q] = "submitted"
    /\ ValidTicket(q)
    /\ ValidFrozenUse(q)
    /\ reqState' = [reqState EXCEPT ![q] = "queued_service"]
    /\ UNCHANGED <<callerEpoch, serviceEpoch, callerBudget, serviceBudget,
                    ticket, frozenUse, activeReq, spent, forfeited>>

StartService(s, q) ==
    /\ s \in Services
    /\ q \in Requests
    /\ reqState[q] \in {"queued_service", "service_throttled"}
    /\ activeReq[s] = NoRequest
    /\ q \notin ActiveRequests
    /\ CanExecute(s, q)
    /\ reqState' = [reqState EXCEPT ![q] = "executing"]
    /\ activeReq' = [activeReq EXCEPT ![s] = q]
    /\ UNCHANGED <<callerEpoch, serviceEpoch, callerBudget, serviceBudget,
                    ticket, frozenUse, spent, forfeited>>

ServiceStep(s) ==
    /\ s \in Services
    /\ activeReq[s] # NoRequest
    /\ LET q == activeReq[s] IN
       LET d == ticket[q].caller IN
       LET newRemaining == ticket[q].remaining - 1 IN
       LET newServiceBudget == serviceBudget[s] - 1 IN
       LET newState ==
            IF newRemaining = 0 THEN "completed"
            ELSE IF newServiceBudget = 0 THEN "service_throttled"
            ELSE "executing"
       IN
        /\ reqState[q] = "executing"
        /\ CanExecute(s, q)
        /\ reqState' = [reqState EXCEPT ![q] = newState]
        /\ ticket' = [ticket EXCEPT ![q] =
            IF newRemaining = 0
            THEN TicketNone
            ELSE [ticket[q] EXCEPT !.remaining = newRemaining]]
        /\ frozenUse' = [frozenUse EXCEPT ![q] =
            IF newRemaining = 0 THEN UseNone ELSE frozenUse[q]]
        /\ serviceBudget' = [serviceBudget EXCEPT ![s] = newServiceBudget]
        /\ spent' = [spent EXCEPT ![d] = @ + 1]
        /\ activeReq' = [activeReq EXCEPT ![s] =
            IF newState = "executing" THEN q ELSE NoRequest]
    /\ UNCHANGED <<callerEpoch, serviceEpoch, callerBudget, forfeited>>

CancelRequest(q) ==
    /\ q \in Requests
    /\ reqState[q] \in PendingStates
    /\ ValidTicket(q)
    /\ LET d == ticket[q].caller IN
        /\ reqState' = [reqState EXCEPT ![q] = "cancelled"]
        /\ callerBudget' = [callerBudget EXCEPT ![d] = @ + ticket[q].remaining]
    /\ ticket' = [ticket EXCEPT ![q] = TicketNone]
    /\ frozenUse' = [frozenUse EXCEPT ![q] = UseNone]
    /\ activeReq' = [s \in Services |->
        IF activeReq[s] = q THEN NoRequest ELSE activeReq[s]]
    /\ UNCHANGED <<callerEpoch, serviceEpoch, serviceBudget, spent, forfeited>>

RevokeCaller(d) ==
    /\ d \in Callers
    /\ callerEpoch[d] < MaxEpoch
    /\ callerEpoch' = [callerEpoch EXCEPT ![d] = @ + 1]
    /\ reqState' = [q \in Requests |->
        IF reqState[q] \in PendingStates /\ RequestUsesCaller(q, d)
        THEN "cancelled"
        ELSE reqState[q]]
    /\ forfeited' = [forfeited EXCEPT ![d] = @ + RemainingForCaller(d)]
    /\ ticket' = [q \in Requests |->
        IF RequestUsesCaller(q, d) THEN TicketNone ELSE ticket[q]]
    /\ frozenUse' = [q \in Requests |->
        IF RequestUsesCaller(q, d) THEN UseNone ELSE frozenUse[q]]
    /\ activeReq' = [s \in Services |->
        IF activeReq[s] # NoRequest /\ RequestUsesCaller(activeReq[s], d)
        THEN NoRequest
        ELSE activeReq[s]]
    /\ UNCHANGED <<serviceEpoch, callerBudget, serviceBudget, spent>>

RevokeService(s) ==
    /\ s \in Services
    /\ serviceEpoch[s] < MaxEpoch
    /\ serviceEpoch' = [serviceEpoch EXCEPT ![s] = @ + 1]
    /\ reqState' = [q \in Requests |->
        IF reqState[q] \in PendingStates /\ RequestUsesService(q, s)
        THEN "cancelled"
        ELSE reqState[q]]
    /\ callerBudget' = [d \in Callers |->
        callerBudget[d] + RemainingForCallerService(d, s)]
    /\ ticket' = [q \in Requests |->
        IF RequestUsesService(q, s) THEN TicketNone ELSE ticket[q]]
    /\ frozenUse' = [q \in Requests |->
        IF RequestUsesService(q, s) THEN UseNone ELSE frozenUse[q]]
    /\ activeReq' = [svc \in Services |->
        IF activeReq[svc] # NoRequest /\ RequestUsesService(activeReq[svc], s)
        THEN NoRequest
        ELSE activeReq[svc]]
    /\ UNCHANGED <<callerEpoch, serviceBudget, spent, forfeited>>

RefillServiceBudget(s) ==
    /\ s \in Services
    /\ serviceBudget[s] < MaxServiceBudget
    /\ serviceBudget' = [serviceBudget EXCEPT ![s] = MaxServiceBudget]
    /\ UNCHANGED <<reqState, callerEpoch, serviceEpoch, callerBudget, ticket,
                    frozenUse, activeReq, spent, forfeited>>

Next ==
    \/ \E q \in Requests, d \in Callers, s \in Services,
          e \in Endpoints, op \in Ops, amount \in TicketAmounts:
        SubmitBrokerRequest(q, d, s, e, op, amount)
    \/ \E q \in Requests:
        QueueService(q)
    \/ \E s \in Services, q \in Requests:
        StartService(s, q)
    \/ \E s \in Services:
        ServiceStep(s)
    \/ \E q \in Requests:
        CancelRequest(q)
    \/ \E d \in Callers:
        RevokeCaller(d)
    \/ \E s \in Services:
        RevokeService(s)
    \/ \E s \in Services:
        RefillServiceBudget(s)

Spec == Init /\ [][Next]_vars

NoServiceExecutionWithoutTicket ==
    \A s \in Services:
        activeReq[s] # NoRequest =>
            LET q == activeReq[s] IN
                /\ reqState[q] = "executing"
                /\ ValidTicket(q)
                /\ ticket[q].remaining > 0

NoServiceExecutionWithoutFrozenUse ==
    \A s \in Services:
        activeReq[s] # NoRequest =>
            LET q == activeReq[s] IN
                /\ ValidFrozenUse(q)
                /\ TicketMatchesUse(q)

NoExecutionWithStaleCallerEpoch ==
    \A s \in Services:
        activeReq[s] # NoRequest =>
            LET q == activeReq[s] IN
                ticket[q].callerEpoch = callerEpoch[ticket[q].caller]

NoExecutionWithStaleServiceEpoch ==
    \A s \in Services:
        activeReq[s] # NoRequest =>
            LET q == activeReq[s] IN
                ticket[q].serviceEpoch = serviceEpoch[ticket[q].service]

NoServiceAmbientAuthority ==
    \A s \in Services:
        activeReq[s] # NoRequest =>
            LET q == activeReq[s] IN
                /\ ticket[q].service = s
                /\ ServiceAllows(s, ticket[q].endpoint, ticket[q].op)

NoConfusedDeputyExecution ==
    \A s \in Services:
        activeReq[s] # NoRequest =>
            LET q == activeReq[s] IN
                /\ CallerAllows(ticket[q].caller, ticket[q].endpoint, ticket[q].op)
                /\ ServiceAllows(ticket[q].service, ticket[q].endpoint, ticket[q].op)
                /\ frozenUse[q].caller = ticket[q].caller
                /\ frozenUse[q].service = ticket[q].service

NoBudgetUnderflow ==
    /\ \A d \in Callers:
        /\ callerBudget[d] >= 0
        /\ spent[d] >= 0
        /\ forfeited[d] >= 0
    /\ \A s \in Services:
        serviceBudget[s] >= 0
    /\ \A q \in Requests:
        ticket[q].remaining >= 0

CallerBudgetConserved ==
    \A d \in Callers:
        callerBudget[d] + spent[d] + forfeited[d] + RemainingForCaller(d)
            = MaxCallerBudget

NoTicketReuseAfterTerminalState ==
    \A q \in Requests:
        reqState[q] \in TerminalStates =>
            /\ ~ticket[q].valid
            /\ ~frozenUse[q].valid
            /\ q \notin ActiveRequests

NoTwoServicesForOneRequest ==
    \A q \in Requests:
        Cardinality({s \in Services : activeReq[s] = q}) <= 1

NoCancelledRequestActive ==
    \A q \in Requests:
        reqState[q] = "cancelled" => q \notin ActiveRequests

=============================================================================
