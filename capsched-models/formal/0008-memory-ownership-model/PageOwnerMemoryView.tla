------------------------ MODULE PageOwnerMemoryView ------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS
    D1, D2,
    P1, P2,
    NoDomain,
    MaxEpoch

VARIABLES
    domainEpoch,
    pageOwner,
    pageEpoch,
    pageKind,
    cacheDomain,
    mapped,
    linuxShadowPage

vars == <<domainEpoch, pageOwner, pageEpoch, pageKind, cacheDomain, mapped,
          linuxShadowPage>>

Domains == {D1, D2}
Pages == {P1, P2}
DomainOrNone == Domains \cup {NoDomain}
Epochs == 0..MaxEpoch
Kinds == {"free", "private", "cache", "sealed"}

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

TypeOK ==
    /\ D1 # D2
    /\ P1 # P2
    /\ NoDomain \notin Domains
    /\ MaxEpoch \in Nat
    /\ MaxEpoch > 0
    /\ domainEpoch \in [Domains -> Epochs]
    /\ pageOwner \in [Pages -> DomainOrNone]
    /\ pageEpoch \in [Pages -> Epochs]
    /\ pageKind \in [Pages -> Kinds]
    /\ cacheDomain \in [Pages -> DomainOrNone]
    /\ mapped \in [Domains -> SUBSET Pages]
    /\ linuxShadowPage \in [Pages -> BOOLEAN]

Init ==
    /\ domainEpoch = [d \in Domains |-> 0]
    /\ pageOwner = [p \in Pages |-> NoDomain]
    /\ pageEpoch = [p \in Pages |-> 0]
    /\ pageKind = [p \in Pages |-> "free"]
    /\ cacheDomain = [p \in Pages |-> NoDomain]
    /\ mapped = [d \in Domains |-> {}]
    /\ linuxShadowPage = [p \in Pages |-> FALSE]

ForgeLinuxPageShadow(p) ==
    /\ p \in Pages
    /\ linuxShadowPage' = [linuxShadowPage EXCEPT ![p] = TRUE]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageKind, cacheDomain,
                    mapped>>

AllocPrivatePage(p, d) ==
    /\ p \in Pages
    /\ d \in Domains
    /\ pageKind[p] = "free"
    /\ NoMappings(p)
    /\ pageOwner' = [pageOwner EXCEPT ![p] = d]
    /\ pageEpoch' = [pageEpoch EXCEPT ![p] = domainEpoch[d]]
    /\ pageKind' = [pageKind EXCEPT ![p] = "private"]
    /\ cacheDomain' = [cacheDomain EXCEPT ![p] = NoDomain]
    /\ UNCHANGED <<domainEpoch, mapped, linuxShadowPage>>

AllocCachePage(p, d) ==
    /\ p \in Pages
    /\ d \in Domains
    /\ pageKind[p] = "free"
    /\ NoMappings(p)
    /\ pageOwner' = [pageOwner EXCEPT ![p] = d]
    /\ pageEpoch' = [pageEpoch EXCEPT ![p] = domainEpoch[d]]
    /\ pageKind' = [pageKind EXCEPT ![p] = "cache"]
    /\ cacheDomain' = [cacheDomain EXCEPT ![p] = d]
    /\ UNCHANGED <<domainEpoch, mapped, linuxShadowPage>>

SealSharedPage(p) ==
    /\ p \in Pages
    /\ pageKind[p] = "free"
    /\ NoMappings(p)
    /\ pageOwner' = [pageOwner EXCEPT ![p] = NoDomain]
    /\ pageEpoch' = [pageEpoch EXCEPT ![p] = 0]
    /\ pageKind' = [pageKind EXCEPT ![p] = "sealed"]
    /\ cacheDomain' = [cacheDomain EXCEPT ![p] = NoDomain]
    /\ UNCHANGED <<domainEpoch, mapped, linuxShadowPage>>

MapPage(d, p) ==
    /\ d \in Domains
    /\ p \in Pages
    /\ PageMappableBy(p, d)
    /\ mapped' = [mapped EXCEPT ![d] = @ \cup {p}]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageKind, cacheDomain,
                    linuxShadowPage>>

UnmapPage(d, p) ==
    /\ d \in Domains
    /\ p \in Pages
    /\ p \in mapped[d]
    /\ mapped' = [mapped EXCEPT ![d] = @ \ {p}]
    /\ UNCHANGED <<domainEpoch, pageOwner, pageEpoch, pageKind, cacheDomain,
                    linuxShadowPage>>

FreePage(p) ==
    /\ p \in Pages
    /\ pageKind[p] # "free"
    /\ NoMappings(p)
    /\ pageOwner' = [pageOwner EXCEPT ![p] = NoDomain]
    /\ pageEpoch' = [pageEpoch EXCEPT ![p] = 0]
    /\ pageKind' = [pageKind EXCEPT ![p] = "free"]
    /\ cacheDomain' = [cacheDomain EXCEPT ![p] = NoDomain]
    /\ UNCHANGED <<domainEpoch, mapped, linuxShadowPage>>

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
        /\ mapped' = [x \in Domains |-> mapped[x] \ owned]
    /\ UNCHANGED linuxShadowPage

Next ==
    \/ \E p \in Pages:
        ForgeLinuxPageShadow(p)
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

NoFreePageMapped ==
    \A p \in Pages:
        pageKind[p] = "free" => NoMappings(p)

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

NoSealedPageHasMutableOwner ==
    \A p \in Pages:
        pageKind[p] = "sealed" =>
            /\ pageOwner[p] = NoDomain
            /\ cacheDomain[p] = NoDomain

=============================================================================

