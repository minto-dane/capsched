---------------------------- MODULE DirectMapTLB ----------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS
    D1, D2,
    P1, P2,
    C1, C2,
    NoDomain,
    NoPage,
    MaxEpoch

VARIABLES
    domainEpoch,
    pageOwner,
    pageEpoch,
    pageState,
    memView,
    directMap,
    cpuDomain,
    tlb,
    accessed,
    linuxShadowDirectMap

vars == <<domainEpoch, pageOwner, pageEpoch, pageState, memView, directMap,
          cpuDomain, tlb, accessed, linuxShadowDirectMap>>

Domains == {D1, D2}
Pages == {P1, P2}
CPUs == {C1, C2}

DomainOrNone == Domains \cup {NoDomain}
PageOrNone == Pages \cup {NoPage}
Epochs == 0..MaxEpoch
PageStates == {"free", "owned", "revoking"}

MappedDomains(p) ==
    {d \in Domains : p \in memView[d]}

DirectMapDomains(p) ==
    {d \in Domains : p \in directMap[d]}

TlbCpus(p) ==
    {c \in CPUs : p \in tlb[c]}

NoTranslations(p) ==
    /\ MappedDomains(p) = {}
    /\ DirectMapDomains(p) = {}
    /\ TlbCpus(p) = {}

PageLiveForDomain(p, d) ==
    IF p \in Pages /\ d \in Domains
    THEN
        /\ pageState[p] = "owned"
        /\ pageOwner[p] = d
        /\ pageEpoch[p] = domainEpoch[d]
    ELSE FALSE

CpuCanTranslate(c, p) ==
    IF c \in CPUs /\ p \in Pages /\ cpuDomain[c] \in Domains
    THEN
        LET d == cpuDomain[c] IN
            /\ PageLiveForDomain(p, d)
            /\ \/ p \in memView[d]
               \/ p \in directMap[d]
    ELSE FALSE

TypeOK ==
    /\ D1 # D2
    /\ P1 # P2
    /\ C1 # C2
    /\ NoDomain \notin Domains
    /\ NoPage \notin Pages
    /\ MaxEpoch \in Nat
    /\ MaxEpoch > 0
    /\ domainEpoch \in [Domains -> Epochs]
    /\ pageOwner \in [Pages -> DomainOrNone]
    /\ pageEpoch \in [Pages -> Epochs]
    /\ pageState \in [Pages -> PageStates]
    /\ memView \in [Domains -> SUBSET Pages]
    /\ directMap \in [Domains -> SUBSET Pages]
    /\ cpuDomain \in [CPUs -> DomainOrNone]
    /\ tlb \in [CPUs -> SUBSET Pages]
    /\ accessed \in [CPUs -> PageOrNone]
    /\ linuxShadowDirectMap \in [Domains -> SUBSET Pages]

Init ==
    /\ domainEpoch = [d \in Domains |-> 0]
    /\ pageOwner = [p \in Pages |-> NoDomain]
    /\ pageEpoch = [p \in Pages |-> 0]
    /\ pageState = [p \in Pages |-> "free"]
    /\ memView = [d \in Domains |-> {}]
    /\ directMap = [d \in Domains |-> {}]
    /\ cpuDomain = [c \in CPUs |-> NoDomain]
    /\ tlb = [c \in CPUs |-> {}]
    /\ accessed = [c \in CPUs |-> NoPage]
    /\ linuxShadowDirectMap = [d \in Domains |-> {}]

ForgeLinuxDirectMap(d, p) ==
    /\ d \in Domains
    /\ p \in Pages
    /\ linuxShadowDirectMap' = [linuxShadowDirectMap EXCEPT ![d] = @ \cup {p}]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageState, memView,
                    directMap, cpuDomain, tlb, accessed>>

AllocPage(p, d) ==
    /\ p \in Pages
    /\ d \in Domains
    /\ pageState[p] = "free"
    /\ NoTranslations(p)
    /\ pageOwner' = [pageOwner EXCEPT ![p] = d]
    /\ pageEpoch' = [pageEpoch EXCEPT ![p] = domainEpoch[d]]
    /\ pageState' = [pageState EXCEPT ![p] = "owned"]
    /\ UNCHANGED <<domainEpoch, memView, directMap, cpuDomain, tlb, accessed,
                    linuxShadowDirectMap>>

MapMemoryView(d, p) ==
    /\ d \in Domains
    /\ p \in Pages
    /\ PageLiveForDomain(p, d)
    /\ memView' = [memView EXCEPT ![d] = @ \cup {p}]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageState, directMap,
                    cpuDomain, tlb, accessed, linuxShadowDirectMap>>

MapDirect(d, p) ==
    /\ d \in Domains
    /\ p \in Pages
    /\ PageLiveForDomain(p, d)
    /\ directMap' = [directMap EXCEPT ![d] = @ \cup {p}]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageState, memView,
                    cpuDomain, tlb, accessed, linuxShadowDirectMap>>

ActivateCpu(c, d) ==
    /\ c \in CPUs
    /\ d \in Domains
    /\ cpuDomain' = [cpuDomain EXCEPT ![c] = d]
    /\ tlb' = [tlb EXCEPT ![c] = {}]
    /\ accessed' = [accessed EXCEPT ![c] = NoPage]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageState, memView,
                    directMap, linuxShadowDirectMap>>

DeactivateCpu(c) ==
    /\ c \in CPUs
    /\ cpuDomain[c] # NoDomain
    /\ cpuDomain' = [cpuDomain EXCEPT ![c] = NoDomain]
    /\ tlb' = [tlb EXCEPT ![c] = {}]
    /\ accessed' = [accessed EXCEPT ![c] = NoPage]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageState, memView,
                    directMap, linuxShadowDirectMap>>

LoadTlb(c, p) ==
    /\ c \in CPUs
    /\ p \in Pages
    /\ CpuCanTranslate(c, p)
    /\ tlb' = [tlb EXCEPT ![c] = @ \cup {p}]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageState, memView,
                    directMap, cpuDomain, accessed, linuxShadowDirectMap>>

AccessViaTlb(c, p) ==
    /\ c \in CPUs
    /\ p \in Pages
    /\ p \in tlb[c]
    /\ CpuCanTranslate(c, p)
    /\ accessed' = [accessed EXCEPT ![c] = p]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageState, memView,
                    directMap, cpuDomain, tlb, linuxShadowDirectMap>>

ClearAccess(c) ==
    /\ c \in CPUs
    /\ accessed[c] # NoPage
    /\ accessed' = [accessed EXCEPT ![c] = NoPage]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageState, memView,
                    directMap, cpuDomain, tlb, linuxShadowDirectMap>>

StartPageRevoke(p) ==
    /\ p \in Pages
    /\ pageState[p] = "owned"
    /\ pageState' = [pageState EXCEPT ![p] = "revoking"]
    /\ memView' = [d \in Domains |-> memView[d] \ {p}]
    /\ directMap' = [d \in Domains |-> directMap[d] \ {p}]
    /\ accessed' = [c \in CPUs |->
        IF accessed[c] = p THEN NoPage ELSE accessed[c]]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, cpuDomain, tlb,
                    linuxShadowDirectMap>>

FlushTlb(c, p) ==
    /\ c \in CPUs
    /\ p \in Pages
    /\ p \in tlb[c]
    /\ tlb' = [tlb EXCEPT ![c] = @ \ {p}]
    /\ accessed' = [accessed EXCEPT ![c] =
        IF accessed[c] = p THEN NoPage ELSE accessed[c]]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageState, memView,
                    directMap, cpuDomain, linuxShadowDirectMap>>

FinishPageRevoke(p) ==
    /\ p \in Pages
    /\ pageState[p] = "revoking"
    /\ NoTranslations(p)
    /\ pageOwner' = [pageOwner EXCEPT ![p] = NoDomain]
    /\ pageEpoch' = [pageEpoch EXCEPT ![p] = 0]
    /\ pageState' = [pageState EXCEPT ![p] = "free"]
    /\ UNCHANGED <<domainEpoch, memView, directMap, cpuDomain, tlb, accessed,
                    linuxShadowDirectMap>>

RevokeDomain(d) ==
    /\ d \in Domains
    /\ domainEpoch[d] < MaxEpoch
    /\ LET owned == {p \in Pages : pageOwner[p] = d} IN
        /\ domainEpoch' = [domainEpoch EXCEPT ![d] = @ + 1]
        /\ pageState' = [p \in Pages |->
            IF p \in owned THEN "revoking" ELSE pageState[p]]
        /\ memView' = [x \in Domains |-> memView[x] \ owned]
        /\ directMap' = [x \in Domains |-> directMap[x] \ owned]
        /\ accessed' = [c \in CPUs |->
            IF accessed[c] \in owned THEN NoPage ELSE accessed[c]]
    /\ UNCHANGED <<pageOwner, pageEpoch, cpuDomain, tlb,
                    linuxShadowDirectMap>>

Next ==
    \/ \E d \in Domains, p \in Pages:
        ForgeLinuxDirectMap(d, p)
    \/ \E p \in Pages, d \in Domains:
        AllocPage(p, d)
    \/ \E d \in Domains, p \in Pages:
        MapMemoryView(d, p)
    \/ \E d \in Domains, p \in Pages:
        MapDirect(d, p)
    \/ \E c \in CPUs, d \in Domains:
        ActivateCpu(c, d)
    \/ \E c \in CPUs:
        DeactivateCpu(c)
    \/ \E c \in CPUs, p \in Pages:
        LoadTlb(c, p)
    \/ \E c \in CPUs, p \in Pages:
        AccessViaTlb(c, p)
    \/ \E c \in CPUs:
        ClearAccess(c)
    \/ \E p \in Pages:
        StartPageRevoke(p)
    \/ \E c \in CPUs, p \in Pages:
        FlushTlb(c, p)
    \/ \E p \in Pages:
        FinishPageRevoke(p)
    \/ \E d \in Domains:
        RevokeDomain(d)

Spec == Init /\ [][Next]_vars

NoMemoryViewForeignPage ==
    \A d \in Domains:
        \A p \in memView[d]:
            PageLiveForDomain(p, d)

NoDirectMapForeignPage ==
    \A d \in Domains:
        \A p \in directMap[d]:
            PageLiveForDomain(p, d)

NoAccessWithoutCurrentAuthority ==
    \A c \in CPUs:
        accessed[c] # NoPage =>
            /\ accessed[c] \in Pages
            /\ CpuCanTranslate(c, accessed[c])
            /\ accessed[c] \in tlb[c]

NoFreePageMappedOrCached ==
    \A p \in Pages:
        pageState[p] = "free" =>
            /\ NoTranslations(p)
            /\ \A c \in CPUs:
                accessed[c] # p

NoFinishedRevokeWithStaleTlb ==
    \A p \in Pages:
        pageOwner[p] = NoDomain => TlbCpus(p) = {}

NoLinuxShadowDirectMapAuthority ==
    \A d \in Domains:
        \A p \in linuxShadowDirectMap[d]:
            ~PageLiveForDomain(p, d) => p \notin directMap[d]

NoTlbForeignActiveDomain ==
    \A c \in CPUs:
        \A p \in tlb[c]:
            cpuDomain[c] \in Domains =>
                /\ p \in Pages
                /\ pageOwner[p] = cpuDomain[c]

=============================================================================
