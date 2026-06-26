------------------------ MODULE MemoryWorkProvenance ------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS
    D1, D2,
    P1, P2,
    W1, W2,
    NoDomain,
    NoPage,
    MaxEpoch,
    MaxTicket

VARIABLES
    domainEpoch,
    pageOwner,
    pageEpoch,
    pageKind,
    workState,
    workPage,
    workDomain,
    workEpoch,
    workTicket,
    linuxShadowWork

vars == <<domainEpoch, pageOwner, pageEpoch, pageKind, workState, workPage,
          workDomain, workEpoch, workTicket, linuxShadowWork>>

Domains == {D1, D2}
Pages == {P1, P2}
Works == {W1, W2}
DomainOrNone == Domains \cup {NoDomain}
PageOrNone == Pages \cup {NoPage}
Epochs == 0..MaxEpoch
Tickets == 0..MaxTicket
Kinds == {"free", "owned"}
WorkStates == {"idle", "queued", "executing", "done", "cancelled"}
PendingWorkStates == {"queued", "executing"}

PageLiveForDomain(p, d) ==
    IF p \in Pages /\ d \in Domains
    THEN
        /\ pageKind[p] = "owned"
        /\ pageOwner[p] = d
        /\ pageEpoch[p] = domainEpoch[d]
    ELSE FALSE

PendingWorkOnPage(p) ==
    {w \in Works : workState[w] \in PendingWorkStates /\ workPage[w] = p}

WorkLive(w) ==
    IF w \in Works /\ workPage[w] \in Pages /\ workDomain[w] \in Domains
    THEN
        /\ workState[w] \in PendingWorkStates
        /\ workEpoch[w] = domainEpoch[workDomain[w]]
        /\ workTicket[w] > 0
        /\ PageLiveForDomain(workPage[w], workDomain[w])
    ELSE FALSE

TypeOK ==
    /\ D1 # D2
    /\ P1 # P2
    /\ W1 # W2
    /\ NoDomain \notin Domains
    /\ NoPage \notin Pages
    /\ MaxEpoch \in Nat
    /\ MaxTicket \in Nat
    /\ MaxEpoch > 0
    /\ MaxTicket > 0
    /\ domainEpoch \in [Domains -> Epochs]
    /\ pageOwner \in [Pages -> DomainOrNone]
    /\ pageEpoch \in [Pages -> Epochs]
    /\ pageKind \in [Pages -> Kinds]
    /\ workState \in [Works -> WorkStates]
    /\ workPage \in [Works -> PageOrNone]
    /\ workDomain \in [Works -> DomainOrNone]
    /\ workEpoch \in [Works -> Epochs]
    /\ workTicket \in [Works -> Tickets]
    /\ linuxShadowWork \in [Works -> BOOLEAN]

Init ==
    /\ domainEpoch = [d \in Domains |-> 0]
    /\ pageOwner = [p \in Pages |-> NoDomain]
    /\ pageEpoch = [p \in Pages |-> 0]
    /\ pageKind = [p \in Pages |-> "free"]
    /\ workState = [w \in Works |-> "idle"]
    /\ workPage = [w \in Works |-> NoPage]
    /\ workDomain = [w \in Works |-> NoDomain]
    /\ workEpoch = [w \in Works |-> 0]
    /\ workTicket = [w \in Works |-> 0]
    /\ linuxShadowWork = [w \in Works |-> FALSE]

ForgeLinuxWorkShadow(w) ==
    /\ w \in Works
    /\ linuxShadowWork' = [linuxShadowWork EXCEPT ![w] = TRUE]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageKind, workState,
                    workPage, workDomain, workEpoch, workTicket>>

AllocPage(p, d) ==
    /\ p \in Pages
    /\ d \in Domains
    /\ pageKind[p] = "free"
    /\ PendingWorkOnPage(p) = {}
    /\ pageOwner' = [pageOwner EXCEPT ![p] = d]
    /\ pageEpoch' = [pageEpoch EXCEPT ![p] = domainEpoch[d]]
    /\ pageKind' = [pageKind EXCEPT ![p] = "owned"]
    /\ UNCHANGED <<domainEpoch, workState, workPage, workDomain, workEpoch,
                    workTicket, linuxShadowWork>>

FreePage(p) ==
    /\ p \in Pages
    /\ pageKind[p] = "owned"
    /\ PendingWorkOnPage(p) = {}
    /\ pageOwner' = [pageOwner EXCEPT ![p] = NoDomain]
    /\ pageEpoch' = [pageEpoch EXCEPT ![p] = 0]
    /\ pageKind' = [pageKind EXCEPT ![p] = "free"]
    /\ UNCHANGED <<domainEpoch, workState, workPage, workDomain, workEpoch,
                    workTicket, linuxShadowWork>>

QueueMemoryWork(w, d, p) ==
    /\ w \in Works
    /\ d \in Domains
    /\ p \in Pages
    /\ workState[w] \in {"idle", "done", "cancelled"}
    /\ PageLiveForDomain(p, d)
    /\ workState' = [workState EXCEPT ![w] = "queued"]
    /\ workPage' = [workPage EXCEPT ![w] = p]
    /\ workDomain' = [workDomain EXCEPT ![w] = d]
    /\ workEpoch' = [workEpoch EXCEPT ![w] = domainEpoch[d]]
    /\ workTicket' = [workTicket EXCEPT ![w] = MaxTicket]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageKind,
                    linuxShadowWork>>

StartMemoryWork(w) ==
    /\ w \in Works
    /\ workState[w] = "queued"
    /\ WorkLive(w)
    /\ workState' = [workState EXCEPT ![w] = "executing"]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageKind, workPage,
                    workDomain, workEpoch, workTicket, linuxShadowWork>>

FinishMemoryWork(w) ==
    /\ w \in Works
    /\ workState[w] = "executing"
    /\ WorkLive(w)
    /\ workState' = [workState EXCEPT ![w] = "done"]
    /\ workPage' = [workPage EXCEPT ![w] = NoPage]
    /\ workDomain' = [workDomain EXCEPT ![w] = NoDomain]
    /\ workEpoch' = [workEpoch EXCEPT ![w] = 0]
    /\ workTicket' = [workTicket EXCEPT ![w] = 0]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageKind,
                    linuxShadowWork>>

CancelMemoryWork(w) ==
    /\ w \in Works
    /\ workState[w] \in PendingWorkStates
    /\ workState' = [workState EXCEPT ![w] = "cancelled"]
    /\ workPage' = [workPage EXCEPT ![w] = NoPage]
    /\ workDomain' = [workDomain EXCEPT ![w] = NoDomain]
    /\ workEpoch' = [workEpoch EXCEPT ![w] = 0]
    /\ workTicket' = [workTicket EXCEPT ![w] = 0]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageKind,
                    linuxShadowWork>>

RevokeDomain(d) ==
    /\ d \in Domains
    /\ domainEpoch[d] < MaxEpoch
    /\ domainEpoch' = [domainEpoch EXCEPT ![d] = @ + 1]
    /\ pageOwner' = [p \in Pages |->
        IF pageOwner[p] = d THEN NoDomain ELSE pageOwner[p]]
    /\ pageEpoch' = [p \in Pages |->
        IF pageOwner[p] = d THEN 0 ELSE pageEpoch[p]]
    /\ pageKind' = [p \in Pages |->
        IF pageOwner[p] = d THEN "free" ELSE pageKind[p]]
    /\ workState' = [w \in Works |->
        IF workDomain[w] = d THEN "cancelled" ELSE workState[w]]
    /\ workPage' = [w \in Works |->
        IF workDomain[w] = d THEN NoPage ELSE workPage[w]]
    /\ workDomain' = [w \in Works |->
        IF workDomain[w] = d THEN NoDomain ELSE workDomain[w]]
    /\ workEpoch' = [w \in Works |->
        IF workDomain[w] = d THEN 0 ELSE workEpoch[w]]
    /\ workTicket' = [w \in Works |->
        IF workDomain[w] = d THEN 0 ELSE workTicket[w]]
    /\ UNCHANGED linuxShadowWork

Next ==
    \/ \E w \in Works:
        ForgeLinuxWorkShadow(w)
    \/ \E p \in Pages, d \in Domains:
        AllocPage(p, d)
    \/ \E p \in Pages:
        FreePage(p)
    \/ \E w \in Works, d \in Domains, p \in Pages:
        QueueMemoryWork(w, d, p)
    \/ \E w \in Works:
        StartMemoryWork(w)
    \/ \E w \in Works:
        FinishMemoryWork(w)
    \/ \E w \in Works:
        CancelMemoryWork(w)
    \/ \E d \in Domains:
        RevokeDomain(d)

Spec == Init /\ [][Next]_vars

NoWorkExecutionWithoutProvenanceTicket ==
    \A w \in Works:
        workState[w] = "executing" => WorkLive(w)

NoQueuedWorkWithoutLivePage ==
    \A w \in Works:
        workState[w] = "queued" => WorkLive(w)

NoFreePageHasPendingWork ==
    \A p \in Pages:
        pageKind[p] = "free" => PendingWorkOnPage(p) = {}

NoLinuxWorkShadowConfersExecution ==
    \A w \in Works:
        linuxShadowWork[w] /\ workState[w] = "executing" => WorkLive(w)

=============================================================================

