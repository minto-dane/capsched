------------------------- MODULE MemoryOwnership -------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS
    D1, D2,
    P1, P2,
    O1, O2,
    W1, W2,
    NoDomain,
    NoPage,
    NoObject,
    NoWork,
    MaxEpoch,
    MaxGen,
    MaxTicket

VARIABLES
    domainEpoch,
    pageOwner,
    pageEpoch,
    pageGen,
    pageKind,
    cacheDomain,
    mapped,
    linuxShadowPage,
    objLive,
    objPage,
    objDomain,
    objGen,
    objUse,
    linuxShadowObject,
    workState,
    workPage,
    workDomain,
    workEpoch,
    workTicket,
    linuxShadowWork

vars == <<domainEpoch, pageOwner, pageEpoch, pageGen, pageKind, cacheDomain,
          mapped, linuxShadowPage, objLive, objPage, objDomain, objGen,
          objUse, linuxShadowObject, workState, workPage, workDomain,
          workEpoch, workTicket, linuxShadowWork>>

Domains == {D1, D2}
Pages == {P1, P2}
Objects == {O1, O2}
Works == {W1, W2}

DomainOrNone == Domains \cup {NoDomain}
PageOrNone == Pages \cup {NoPage}
ObjectOrNone == Objects \cup {NoObject}
WorkOrNone == Works \cup {NoWork}

Epochs == 0..MaxEpoch
Gens == 0..MaxGen
Tickets == 0..MaxTicket

Kinds == {"free", "private", "cache", "sealed"}
WorkStates == {"idle", "queued", "executing", "done", "cancelled"}
PendingWorkStates == {"queued", "executing"}

UseRecord == [
    valid: BOOLEAN,
    object: ObjectOrNone,
    page: PageOrNone,
    domain: DomainOrNone,
    objectGen: Gens,
    pageGen: Gens,
    epoch: Epochs
]

UseNone == [
    valid |-> FALSE,
    object |-> NoObject,
    page |-> NoPage,
    domain |-> NoDomain,
    objectGen |-> 0,
    pageGen |-> 0,
    epoch |-> 0
]

MappedDomains(p) ==
    {d \in Domains : p \in mapped[d]}

NoMappings(p) ==
    MappedDomains(p) = {}

MutableKind(k) ==
    k \in {"private", "cache"}

PageLiveForDomain(p, d) ==
    IF p \in Pages /\ d \in Domains
    THEN
        /\ pageOwner[p] = d
        /\ pageEpoch[p] = domainEpoch[d]
        /\ MutableKind(pageKind[p])
    ELSE FALSE

PageMappableBy(p, d) ==
    /\ p \in Pages
    /\ d \in Domains
    /\ \/ PageLiveForDomain(p, d)
       \/ pageKind[p] = "sealed"

LiveObjectsOnPage(p) ==
    {o \in Objects : objLive[o] /\ objPage[o] = p}

PendingWorkOnPage(p) ==
    {w \in Works : workState[w] \in PendingWorkStates /\ workPage[w] = p}

ObjectUseLive(o) ==
    IF o \in Objects /\ objUse[o].valid /\ objPage[o] \in Pages /\
       objDomain[o] \in Domains
    THEN
        /\ objUse[o].object = o
        /\ objLive[o]
        /\ objUse[o].page = objPage[o]
        /\ objUse[o].domain = objDomain[o]
        /\ objUse[o].objectGen = objGen[o]
        /\ objUse[o].pageGen = pageGen[objPage[o]]
        /\ objUse[o].epoch = domainEpoch[objDomain[o]]
        /\ PageLiveForDomain(objPage[o], objDomain[o])
    ELSE FALSE

WorkLive(w) ==
    /\ w \in Works
    /\ workState[w] \in PendingWorkStates
    /\ workPage[w] \in Pages
    /\ workDomain[w] \in Domains
    /\ workEpoch[w] = domainEpoch[workDomain[w]]
    /\ workTicket[w] > 0
    /\ PageLiveForDomain(workPage[w], workDomain[w])

IncGen(g) ==
    IF g < MaxGen THEN g + 1 ELSE g

TypeOK ==
    /\ D1 # D2
    /\ P1 # P2
    /\ O1 # O2
    /\ W1 # W2
    /\ NoDomain \notin Domains
    /\ NoPage \notin Pages
    /\ NoObject \notin Objects
    /\ NoWork \notin Works
    /\ MaxEpoch \in Nat
    /\ MaxGen \in Nat
    /\ MaxTicket \in Nat
    /\ MaxEpoch > 0
    /\ MaxGen > 0
    /\ MaxTicket > 0
    /\ domainEpoch \in [Domains -> Epochs]
    /\ pageOwner \in [Pages -> DomainOrNone]
    /\ pageEpoch \in [Pages -> Epochs]
    /\ pageGen \in [Pages -> Gens]
    /\ pageKind \in [Pages -> Kinds]
    /\ cacheDomain \in [Pages -> DomainOrNone]
    /\ mapped \in [Domains -> SUBSET Pages]
    /\ linuxShadowPage \in [Pages -> BOOLEAN]
    /\ objLive \in [Objects -> BOOLEAN]
    /\ objPage \in [Objects -> PageOrNone]
    /\ objDomain \in [Objects -> DomainOrNone]
    /\ objGen \in [Objects -> Gens]
    /\ objUse \in [Objects -> UseRecord]
    /\ linuxShadowObject \in [Objects -> BOOLEAN]
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
    /\ pageGen = [p \in Pages |-> 0]
    /\ pageKind = [p \in Pages |-> "free"]
    /\ cacheDomain = [p \in Pages |-> NoDomain]
    /\ mapped = [d \in Domains |-> {}]
    /\ linuxShadowPage = [p \in Pages |-> FALSE]
    /\ objLive = [o \in Objects |-> FALSE]
    /\ objPage = [o \in Objects |-> NoPage]
    /\ objDomain = [o \in Objects |-> NoDomain]
    /\ objGen = [o \in Objects |-> 0]
    /\ objUse = [o \in Objects |-> UseNone]
    /\ linuxShadowObject = [o \in Objects |-> FALSE]
    /\ workState = [w \in Works |-> "idle"]
    /\ workPage = [w \in Works |-> NoPage]
    /\ workDomain = [w \in Works |-> NoDomain]
    /\ workEpoch = [w \in Works |-> 0]
    /\ workTicket = [w \in Works |-> 0]
    /\ linuxShadowWork = [w \in Works |-> FALSE]

ForgeLinuxPageShadow(p) ==
    /\ p \in Pages
    /\ linuxShadowPage' = [linuxShadowPage EXCEPT ![p] = TRUE]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageGen, pageKind,
                    cacheDomain, mapped, objLive, objPage, objDomain, objGen,
                    objUse, linuxShadowObject, workState, workPage, workDomain,
                    workEpoch, workTicket, linuxShadowWork>>

ForgeLinuxObjectShadow(o) ==
    /\ o \in Objects
    /\ linuxShadowObject' = [linuxShadowObject EXCEPT ![o] = TRUE]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageGen, pageKind,
                    cacheDomain, mapped, linuxShadowPage, objLive, objPage,
                    objDomain, objGen, objUse, workState, workPage, workDomain,
                    workEpoch, workTicket, linuxShadowWork>>

ForgeLinuxWorkShadow(w) ==
    /\ w \in Works
    /\ linuxShadowWork' = [linuxShadowWork EXCEPT ![w] = TRUE]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageGen, pageKind,
                    cacheDomain, mapped, linuxShadowPage, objLive, objPage,
                    objDomain, objGen, objUse, linuxShadowObject, workState,
                    workPage, workDomain, workEpoch, workTicket>>

AllocPrivatePage(p, d) ==
    /\ p \in Pages
    /\ d \in Domains
    /\ pageKind[p] = "free"
    /\ NoMappings(p)
    /\ LiveObjectsOnPage(p) = {}
    /\ PendingWorkOnPage(p) = {}
    /\ pageOwner' = [pageOwner EXCEPT ![p] = d]
    /\ pageEpoch' = [pageEpoch EXCEPT ![p] = domainEpoch[d]]
    /\ pageKind' = [pageKind EXCEPT ![p] = "private"]
    /\ cacheDomain' = [cacheDomain EXCEPT ![p] = NoDomain]
    /\ UNCHANGED <<domainEpoch, pageGen, mapped, linuxShadowPage, objLive,
                    objPage, objDomain, objGen, objUse, linuxShadowObject,
                    workState, workPage, workDomain, workEpoch, workTicket,
                    linuxShadowWork>>

AllocCachePage(p, d) ==
    /\ p \in Pages
    /\ d \in Domains
    /\ pageKind[p] = "free"
    /\ NoMappings(p)
    /\ LiveObjectsOnPage(p) = {}
    /\ PendingWorkOnPage(p) = {}
    /\ pageOwner' = [pageOwner EXCEPT ![p] = d]
    /\ pageEpoch' = [pageEpoch EXCEPT ![p] = domainEpoch[d]]
    /\ pageKind' = [pageKind EXCEPT ![p] = "cache"]
    /\ cacheDomain' = [cacheDomain EXCEPT ![p] = d]
    /\ UNCHANGED <<domainEpoch, pageGen, mapped, linuxShadowPage, objLive,
                    objPage, objDomain, objGen, objUse, linuxShadowObject,
                    workState, workPage, workDomain, workEpoch, workTicket,
                    linuxShadowWork>>

SealSharedPage(p) ==
    /\ p \in Pages
    /\ pageKind[p] = "free"
    /\ NoMappings(p)
    /\ LiveObjectsOnPage(p) = {}
    /\ PendingWorkOnPage(p) = {}
    /\ pageOwner' = [pageOwner EXCEPT ![p] = NoDomain]
    /\ pageEpoch' = [pageEpoch EXCEPT ![p] = 0]
    /\ pageKind' = [pageKind EXCEPT ![p] = "sealed"]
    /\ cacheDomain' = [cacheDomain EXCEPT ![p] = NoDomain]
    /\ UNCHANGED <<domainEpoch, pageGen, mapped, linuxShadowPage, objLive,
                    objPage, objDomain, objGen, objUse, linuxShadowObject,
                    workState, workPage, workDomain, workEpoch, workTicket,
                    linuxShadowWork>>

MapPage(d, p) ==
    /\ d \in Domains
    /\ p \in Pages
    /\ PageMappableBy(p, d)
    /\ mapped' = [mapped EXCEPT ![d] = @ \cup {p}]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageGen, pageKind,
                    cacheDomain, linuxShadowPage, objLive, objPage, objDomain,
                    objGen, objUse, linuxShadowObject, workState, workPage,
                    workDomain, workEpoch, workTicket, linuxShadowWork>>

UnmapPage(d, p) ==
    /\ d \in Domains
    /\ p \in Pages
    /\ p \in mapped[d]
    /\ mapped' = [mapped EXCEPT ![d] = @ \ {p}]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageGen, pageKind,
                    cacheDomain, linuxShadowPage, objLive, objPage, objDomain,
                    objGen, objUse, linuxShadowObject, workState, workPage,
                    workDomain, workEpoch, workTicket, linuxShadowWork>>

FreePage(p) ==
    /\ p \in Pages
    /\ pageKind[p] # "free"
    /\ NoMappings(p)
    /\ LiveObjectsOnPage(p) = {}
    /\ PendingWorkOnPage(p) = {}
    /\ pageOwner' = [pageOwner EXCEPT ![p] = NoDomain]
    /\ pageEpoch' = [pageEpoch EXCEPT ![p] = 0]
    /\ pageKind' = [pageKind EXCEPT ![p] = "free"]
    /\ cacheDomain' = [cacheDomain EXCEPT ![p] = NoDomain]
    /\ pageGen' = [pageGen EXCEPT ![p] = IncGen(@)]
    /\ UNCHANGED <<domainEpoch, mapped, linuxShadowPage, objLive, objPage,
                    objDomain, objGen, objUse, linuxShadowObject, workState,
                    workPage, workDomain, workEpoch, workTicket,
                    linuxShadowWork>>

AllocObject(o, p, d) ==
    /\ o \in Objects
    /\ p \in Pages
    /\ d \in Domains
    /\ ~objLive[o]
    /\ PageLiveForDomain(p, d)
    /\ objLive' = [objLive EXCEPT ![o] = TRUE]
    /\ objPage' = [objPage EXCEPT ![o] = p]
    /\ objDomain' = [objDomain EXCEPT ![o] = d]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageGen, pageKind,
                    cacheDomain, mapped, linuxShadowPage, objGen, objUse,
                    linuxShadowObject, workState, workPage, workDomain,
                    workEpoch, workTicket, linuxShadowWork>>

StartObjectUse(o) ==
    /\ o \in Objects
    /\ objLive[o]
    /\ ~objUse[o].valid
    /\ PageLiveForDomain(objPage[o], objDomain[o])
    /\ objUse' = [objUse EXCEPT ![o] =
        [valid |-> TRUE,
         object |-> o,
         page |-> objPage[o],
         domain |-> objDomain[o],
         objectGen |-> objGen[o],
         pageGen |-> pageGen[objPage[o]],
         epoch |-> domainEpoch[objDomain[o]]]]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageGen, pageKind,
                    cacheDomain, mapped, linuxShadowPage, objLive, objPage,
                    objDomain, objGen, linuxShadowObject, workState, workPage,
                    workDomain, workEpoch, workTicket, linuxShadowWork>>

EndObjectUse(o) ==
    /\ o \in Objects
    /\ objUse[o].valid
    /\ objUse' = [objUse EXCEPT ![o] = UseNone]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageGen, pageKind,
                    cacheDomain, mapped, linuxShadowPage, objLive, objPage,
                    objDomain, objGen, linuxShadowObject, workState, workPage,
                    workDomain, workEpoch, workTicket, linuxShadowWork>>

FreeObject(o) ==
    /\ o \in Objects
    /\ objLive[o]
    /\ ~objUse[o].valid
    /\ objLive' = [objLive EXCEPT ![o] = FALSE]
    /\ objPage' = [objPage EXCEPT ![o] = NoPage]
    /\ objDomain' = [objDomain EXCEPT ![o] = NoDomain]
    /\ objGen' = [objGen EXCEPT ![o] = IncGen(@)]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageGen, pageKind,
                    cacheDomain, mapped, linuxShadowPage, objUse,
                    linuxShadowObject, workState, workPage, workDomain,
                    workEpoch, workTicket, linuxShadowWork>>

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
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageGen, pageKind,
                    cacheDomain, mapped, linuxShadowPage, objLive, objPage,
                    objDomain, objGen, objUse, linuxShadowObject,
                    linuxShadowWork>>

StartMemoryWork(w) ==
    /\ w \in Works
    /\ workState[w] = "queued"
    /\ WorkLive(w)
    /\ workState' = [workState EXCEPT ![w] = "executing"]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageGen, pageKind,
                    cacheDomain, mapped, linuxShadowPage, objLive, objPage,
                    objDomain, objGen, objUse, linuxShadowObject, workPage,
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
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageGen, pageKind,
                    cacheDomain, mapped, linuxShadowPage, objLive, objPage,
                    objDomain, objGen, objUse, linuxShadowObject,
                    linuxShadowWork>>

CancelMemoryWork(w) ==
    /\ w \in Works
    /\ workState[w] \in PendingWorkStates
    /\ workState' = [workState EXCEPT ![w] = "cancelled"]
    /\ workPage' = [workPage EXCEPT ![w] = NoPage]
    /\ workDomain' = [workDomain EXCEPT ![w] = NoDomain]
    /\ workEpoch' = [workEpoch EXCEPT ![w] = 0]
    /\ workTicket' = [workTicket EXCEPT ![w] = 0]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageGen, pageKind,
                    cacheDomain, mapped, linuxShadowPage, objLive, objPage,
                    objDomain, objGen, objUse, linuxShadowObject,
                    linuxShadowWork>>

RevokeDomain(d) ==
    /\ d \in Domains
    /\ domainEpoch[d] < MaxEpoch
    /\ LET owned == {p \in Pages : pageOwner[p] = d} IN
        /\ domainEpoch' = [domainEpoch EXCEPT ![d] = @ + 1]
        /\ pageOwner' = [p \in Pages |->
            IF p \in owned THEN NoDomain ELSE pageOwner[p]]
        /\ pageEpoch' = [p \in Pages |->
            IF p \in owned THEN 0 ELSE pageEpoch[p]]
        /\ pageKind' = [p \in Pages |->
            IF p \in owned THEN "free" ELSE pageKind[p]]
        /\ cacheDomain' = [p \in Pages |->
            IF p \in owned THEN NoDomain ELSE cacheDomain[p]]
        /\ pageGen' = [p \in Pages |->
            IF p \in owned THEN IncGen(pageGen[p]) ELSE pageGen[p]]
        /\ mapped' = [x \in Domains |-> mapped[x] \ owned]
        /\ objLive' = [o \in Objects |->
            IF objDomain[o] = d THEN FALSE ELSE objLive[o]]
        /\ objPage' = [o \in Objects |->
            IF objDomain[o] = d THEN NoPage ELSE objPage[o]]
        /\ objDomain' = [o \in Objects |->
            IF objDomain[o] = d THEN NoDomain ELSE objDomain[o]]
        /\ objGen' = [o \in Objects |->
            IF objDomain[o] = d THEN IncGen(objGen[o]) ELSE objGen[o]]
        /\ objUse' = [o \in Objects |->
            IF objUse[o].valid /\ objUse[o].domain = d
            THEN UseNone
            ELSE objUse[o]]
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
    /\ UNCHANGED <<linuxShadowPage, linuxShadowObject, linuxShadowWork>>

Next ==
    \/ \E p \in Pages:
        ForgeLinuxPageShadow(p)
    \/ \E o \in Objects:
        ForgeLinuxObjectShadow(o)
    \/ \E w \in Works:
        ForgeLinuxWorkShadow(w)
    \/ \E p \in Pages, d \in Domains:
        AllocPrivatePage(p, d)
    \/ \E p \in Pages, d \in Domains:
        AllocCachePage(p, d)
    \/ \E p \in Pages:
        SealSharedPage(p)
    \/ \E d \in Domains, p \in Pages:
        MapPage(d, p)
    \/ \E d \in Domains, p \in Pages:
        UnmapPage(d, p)
    \/ \E p \in Pages:
        FreePage(p)
    \/ \E o \in Objects, p \in Pages, d \in Domains:
        AllocObject(o, p, d)
    \/ \E o \in Objects:
        StartObjectUse(o)
    \/ \E o \in Objects:
        EndObjectUse(o)
    \/ \E o \in Objects:
        FreeObject(o)
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

NoMappingWithoutMonitorAuthority ==
    \A d \in Domains:
        \A p \in mapped[d]:
            PageMappableBy(p, d)

NoMutablePageMappedAcrossDomains ==
    \A p \in Pages:
        MutableKind(pageKind[p]) =>
            MappedDomains(p) \subseteq {pageOwner[p]}

NoFreePageMappedOrReferenced ==
    \A p \in Pages:
        pageKind[p] = "free" =>
            /\ NoMappings(p)
            /\ LiveObjectsOnPage(p) = {}
            /\ PendingWorkOnPage(p) = {}

NoStaleEpochMapping ==
    \A d \in Domains:
        \A p \in mapped[d]:
            MutableKind(pageKind[p]) =>
                /\ pageOwner[p] = d
                /\ pageEpoch[p] = domainEpoch[d]

NoLinuxShadowConfersMappingAuthority ==
    \A p \in Pages:
        linuxShadowPage[p] /\ pageKind[p] = "free" =>
            NoMappings(p)

NoMutablePageCacheSharing ==
    \A p \in Pages:
        pageKind[p] = "cache" =>
            /\ cacheDomain[p] = pageOwner[p]
            /\ cacheDomain[p] \in Domains
            /\ MappedDomains(p) \subseteq {cacheDomain[p]}

NoObjectUseWithoutLiveGeneration ==
    \A o \in Objects:
        objUse[o].valid => ObjectUseLive(o)

NoObjectUseAcrossPageOwner ==
    \A o \in Objects:
        objUse[o].valid =>
            /\ objUse[o].page \in Pages
            /\ pageOwner[objUse[o].page] = objUse[o].domain

NoWorkExecutionWithoutProvenanceTicket ==
    \A w \in Works:
        workState[w] = "executing" => WorkLive(w)

NoSealedPageHasMutableOwner ==
    \A p \in Pages:
        pageKind[p] = "sealed" =>
            /\ pageOwner[p] = NoDomain
            /\ cacheDomain[p] = NoDomain

=============================================================================
