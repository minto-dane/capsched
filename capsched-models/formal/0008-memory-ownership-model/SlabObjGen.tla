----------------------------- MODULE SlabObjGen -----------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS
    D1, D2,
    P1, P2,
    O1, O2,
    NoDomain,
    NoPage,
    NoObject,
    MaxEpoch,
    MaxGen

VARIABLES
    domainEpoch,
    pageOwner,
    pageEpoch,
    pageKind,
    objLive,
    objPage,
    objDomain,
    objGen,
    objUse,
    linuxShadowObject

vars == <<domainEpoch, pageOwner, pageEpoch, pageKind, objLive, objPage,
          objDomain, objGen, objUse, linuxShadowObject>>

Domains == {D1, D2}
Pages == {P1, P2}
Objects == {O1, O2}
DomainOrNone == Domains \cup {NoDomain}
PageOrNone == Pages \cup {NoPage}
ObjectOrNone == Objects \cup {NoObject}
Epochs == 0..MaxEpoch
Gens == 0..MaxGen
Kinds == {"free", "owned"}

UseRecord == [
    valid: BOOLEAN,
    object: ObjectOrNone,
    page: PageOrNone,
    domain: DomainOrNone,
    gen: Gens,
    epoch: Epochs
]

UseNone == [
    valid |-> FALSE,
    object |-> NoObject,
    page |-> NoPage,
    domain |-> NoDomain,
    gen |-> 0,
    epoch |-> 0
]

PageLiveForDomain(p, d) ==
    IF p \in Pages /\ d \in Domains
    THEN
        /\ pageKind[p] = "owned"
        /\ pageOwner[p] = d
        /\ pageEpoch[p] = domainEpoch[d]
    ELSE FALSE

LiveObjectsOnPage(p) ==
    {o \in Objects : objLive[o] /\ objPage[o] = p}

IncGen(g) ==
    IF g < MaxGen THEN g + 1 ELSE g

ObjectUseLive(o) ==
    IF o \in Objects /\ objUse[o].valid /\ objPage[o] \in Pages /\
       objDomain[o] \in Domains
    THEN
        /\ objUse[o].object = o
        /\ objLive[o]
        /\ objUse[o].page = objPage[o]
        /\ objUse[o].domain = objDomain[o]
        /\ objUse[o].gen = objGen[o]
        /\ objUse[o].epoch = domainEpoch[objDomain[o]]
        /\ PageLiveForDomain(objPage[o], objDomain[o])
    ELSE FALSE

TypeOK ==
    /\ D1 # D2
    /\ P1 # P2
    /\ O1 # O2
    /\ NoDomain \notin Domains
    /\ NoPage \notin Pages
    /\ NoObject \notin Objects
    /\ MaxEpoch \in Nat
    /\ MaxGen \in Nat
    /\ MaxEpoch > 0
    /\ MaxGen > 0
    /\ domainEpoch \in [Domains -> Epochs]
    /\ pageOwner \in [Pages -> DomainOrNone]
    /\ pageEpoch \in [Pages -> Epochs]
    /\ pageKind \in [Pages -> Kinds]
    /\ objLive \in [Objects -> BOOLEAN]
    /\ objPage \in [Objects -> PageOrNone]
    /\ objDomain \in [Objects -> DomainOrNone]
    /\ objGen \in [Objects -> Gens]
    /\ objUse \in [Objects -> UseRecord]
    /\ linuxShadowObject \in [Objects -> BOOLEAN]

Init ==
    /\ domainEpoch = [d \in Domains |-> 0]
    /\ pageOwner = [p \in Pages |-> NoDomain]
    /\ pageEpoch = [p \in Pages |-> 0]
    /\ pageKind = [p \in Pages |-> "free"]
    /\ objLive = [o \in Objects |-> FALSE]
    /\ objPage = [o \in Objects |-> NoPage]
    /\ objDomain = [o \in Objects |-> NoDomain]
    /\ objGen = [o \in Objects |-> 0]
    /\ objUse = [o \in Objects |-> UseNone]
    /\ linuxShadowObject = [o \in Objects |-> FALSE]

ForgeLinuxObjectShadow(o) ==
    /\ o \in Objects
    /\ linuxShadowObject' = [linuxShadowObject EXCEPT ![o] = TRUE]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageKind, objLive,
                    objPage, objDomain, objGen, objUse>>

AllocPage(p, d) ==
    /\ p \in Pages
    /\ d \in Domains
    /\ pageKind[p] = "free"
    /\ LiveObjectsOnPage(p) = {}
    /\ pageOwner' = [pageOwner EXCEPT ![p] = d]
    /\ pageEpoch' = [pageEpoch EXCEPT ![p] = domainEpoch[d]]
    /\ pageKind' = [pageKind EXCEPT ![p] = "owned"]
    /\ UNCHANGED <<domainEpoch, objLive, objPage, objDomain, objGen, objUse,
                    linuxShadowObject>>

FreePage(p) ==
    /\ p \in Pages
    /\ pageKind[p] = "owned"
    /\ LiveObjectsOnPage(p) = {}
    /\ pageOwner' = [pageOwner EXCEPT ![p] = NoDomain]
    /\ pageEpoch' = [pageEpoch EXCEPT ![p] = 0]
    /\ pageKind' = [pageKind EXCEPT ![p] = "free"]
    /\ UNCHANGED <<domainEpoch, objLive, objPage, objDomain, objGen, objUse,
                    linuxShadowObject>>

AllocObject(o, p, d) ==
    /\ o \in Objects
    /\ p \in Pages
    /\ d \in Domains
    /\ ~objLive[o]
    /\ PageLiveForDomain(p, d)
    /\ objLive' = [objLive EXCEPT ![o] = TRUE]
    /\ objPage' = [objPage EXCEPT ![o] = p]
    /\ objDomain' = [objDomain EXCEPT ![o] = d]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageKind, objGen,
                    objUse, linuxShadowObject>>

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
         gen |-> objGen[o],
         epoch |-> domainEpoch[objDomain[o]]]]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageKind, objLive,
                    objPage, objDomain, objGen, linuxShadowObject>>

EndObjectUse(o) ==
    /\ o \in Objects
    /\ objUse[o].valid
    /\ objUse' = [objUse EXCEPT ![o] = UseNone]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageKind, objLive,
                    objPage, objDomain, objGen, linuxShadowObject>>

FreeObject(o) ==
    /\ o \in Objects
    /\ objLive[o]
    /\ ~objUse[o].valid
    /\ objLive' = [objLive EXCEPT ![o] = FALSE]
    /\ objPage' = [objPage EXCEPT ![o] = NoPage]
    /\ objDomain' = [objDomain EXCEPT ![o] = NoDomain]
    /\ objGen' = [objGen EXCEPT ![o] = IncGen(@)]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageKind, objUse,
                    linuxShadowObject>>

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
    /\ UNCHANGED linuxShadowObject

Next ==
    \/ \E o \in Objects:
        ForgeLinuxObjectShadow(o)
    \/ \E p \in Pages, d \in Domains:
        AllocPage(p, d)
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
    \/ \E d \in Domains:
        RevokeDomain(d)

Spec == Init /\ [][Next]_vars

NoObjectUseWithoutLiveGeneration ==
    \A o \in Objects:
        objUse[o].valid => ObjectUseLive(o)

NoObjectUseAcrossPageOwner ==
    \A o \in Objects:
        objUse[o].valid =>
            /\ objUse[o].page \in Pages
            /\ pageOwner[objUse[o].page] = objUse[o].domain

NoFreePageHasLiveObject ==
    \A p \in Pages:
        pageKind[p] = "free" => LiveObjectsOnPage(p) = {}

NoLinuxObjectShadowConfersAuthority ==
    \A o \in Objects:
        linuxShadowObject[o] /\ objUse[o].valid => ObjectUseLive(o)

=============================================================================
