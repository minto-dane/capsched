-------------------------- MODULE PageCacheOverlay --------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS
    D1, D2,
    B1,
    O1, O2,
    NoDomain,
    NoBase,
    MaxEpoch,
    MaxVersion,
    MaxTicket

VARIABLES
    domainEpoch,
    serviceEpoch,
    baseState,
    baseVersion,
    overlayState,
    overlayOwner,
    overlayEpoch,
    overlayBase,
    overlayBaseVersion,
    workTicket,
    workServiceEpoch,
    mappedBase,
    mappedOverlay,
    linuxShadowOwner

vars == <<domainEpoch, serviceEpoch, baseState, baseVersion, overlayState,
          overlayOwner, overlayEpoch, overlayBase, overlayBaseVersion,
          workTicket, workServiceEpoch, mappedBase, mappedOverlay,
          linuxShadowOwner>>

Domains == {D1, D2}
Bases == {B1}
Overlays == {O1, O2}

DomainOrNone == Domains \cup {NoDomain}
BaseOrNone == Bases \cup {NoBase}
Epochs == 0..MaxEpoch
Versions == 0..MaxVersion
Tickets == 0..MaxTicket

BaseStates == {"absent", "sealed"}
OverlayStates == {
    "free",
    "clean",
    "dirty",
    "queued",
    "committing",
    "conflict",
    "cancelled"
}

LiveOverlayStates == {"clean", "dirty", "queued", "committing", "conflict"}
PendingWritebackStates == {"queued", "committing"}

MappedOverlayDomains(o) ==
    {d \in Domains : o \in mappedOverlay[d]}

MappedBaseDomains(b) ==
    {d \in Domains : b \in mappedBase[d]}

NoOverlayMappings(o) ==
    MappedOverlayDomains(o) = {}

OverlayLiveForDomain(o, d) ==
    IF o \in Overlays /\ d \in Domains
    THEN
        /\ overlayState[o] \in LiveOverlayStates
        /\ overlayOwner[o] = d
        /\ overlayEpoch[o] = domainEpoch[d]
        /\ overlayBase[o] \in Bases
        /\ baseState[overlayBase[o]] = "sealed"
    ELSE FALSE

OverlayCurrent(o) ==
    /\ o \in Overlays
    /\ overlayBase[o] \in Bases
    /\ overlayBaseVersion[o] = baseVersion[overlayBase[o]]

WorkLive(o) ==
    IF o \in Overlays /\ overlayOwner[o] \in Domains
    THEN
        /\ overlayState[o] \in PendingWritebackStates
        /\ OverlayLiveForDomain(o, overlayOwner[o])
        /\ workTicket[o] > 0
        /\ workServiceEpoch[o] = serviceEpoch
    ELSE FALSE

CommittingOverlaysForBase(b) ==
    {o \in Overlays : overlayState[o] = "committing" /\ overlayBase[o] = b}

TypeOK ==
    /\ D1 # D2
    /\ O1 # O2
    /\ NoDomain \notin Domains
    /\ NoBase \notin Bases
    /\ MaxEpoch \in Nat
    /\ MaxVersion \in Nat
    /\ MaxTicket \in Nat
    /\ MaxEpoch > 0
    /\ MaxVersion > 0
    /\ MaxTicket > 0
    /\ domainEpoch \in [Domains -> Epochs]
    /\ serviceEpoch \in Epochs
    /\ baseState \in [Bases -> BaseStates]
    /\ baseVersion \in [Bases -> Versions]
    /\ overlayState \in [Overlays -> OverlayStates]
    /\ overlayOwner \in [Overlays -> DomainOrNone]
    /\ overlayEpoch \in [Overlays -> Epochs]
    /\ overlayBase \in [Overlays -> BaseOrNone]
    /\ overlayBaseVersion \in [Overlays -> Versions]
    /\ workTicket \in [Overlays -> Tickets]
    /\ workServiceEpoch \in [Overlays -> Epochs]
    /\ mappedBase \in [Domains -> SUBSET Bases]
    /\ mappedOverlay \in [Domains -> SUBSET Overlays]
    /\ linuxShadowOwner \in [Overlays -> DomainOrNone]

Init ==
    /\ domainEpoch = [d \in Domains |-> 0]
    /\ serviceEpoch = 0
    /\ baseState = [b \in Bases |-> "absent"]
    /\ baseVersion = [b \in Bases |-> 0]
    /\ overlayState = [o \in Overlays |-> "free"]
    /\ overlayOwner = [o \in Overlays |-> NoDomain]
    /\ overlayEpoch = [o \in Overlays |-> 0]
    /\ overlayBase = [o \in Overlays |-> NoBase]
    /\ overlayBaseVersion = [o \in Overlays |-> 0]
    /\ workTicket = [o \in Overlays |-> 0]
    /\ workServiceEpoch = [o \in Overlays |-> 0]
    /\ mappedBase = [d \in Domains |-> {}]
    /\ mappedOverlay = [d \in Domains |-> {}]
    /\ linuxShadowOwner = [o \in Overlays |-> NoDomain]

ForgeLinuxShadowOwner(o, d) ==
    /\ o \in Overlays
    /\ d \in Domains
    /\ linuxShadowOwner' = [linuxShadowOwner EXCEPT ![o] = d]
    /\ UNCHANGED <<domainEpoch, serviceEpoch, baseState, baseVersion,
                    overlayState, overlayOwner, overlayEpoch, overlayBase,
                    overlayBaseVersion, workTicket, workServiceEpoch,
                    mappedBase, mappedOverlay>>

CreateSealedBase(b) ==
    /\ b \in Bases
    /\ baseState[b] = "absent"
    /\ MappedBaseDomains(b) = {}
    /\ baseState' = [baseState EXCEPT ![b] = "sealed"]
    /\ baseVersion' = [baseVersion EXCEPT ![b] = 0]
    /\ UNCHANGED <<domainEpoch, serviceEpoch, overlayState, overlayOwner,
                    overlayEpoch, overlayBase, overlayBaseVersion, workTicket,
                    workServiceEpoch, mappedBase, mappedOverlay,
                    linuxShadowOwner>>

MapBase(d, b) ==
    /\ d \in Domains
    /\ b \in Bases
    /\ baseState[b] = "sealed"
    /\ mappedBase' = [mappedBase EXCEPT ![d] = @ \cup {b}]
    /\ UNCHANGED <<domainEpoch, serviceEpoch, baseState, baseVersion,
                    overlayState, overlayOwner, overlayEpoch, overlayBase,
                    overlayBaseVersion, workTicket, workServiceEpoch,
                    mappedOverlay, linuxShadowOwner>>

UnmapBase(d, b) ==
    /\ d \in Domains
    /\ b \in Bases
    /\ b \in mappedBase[d]
    /\ mappedBase' = [mappedBase EXCEPT ![d] = @ \ {b}]
    /\ UNCHANGED <<domainEpoch, serviceEpoch, baseState, baseVersion,
                    overlayState, overlayOwner, overlayEpoch, overlayBase,
                    overlayBaseVersion, workTicket, workServiceEpoch,
                    mappedOverlay, linuxShadowOwner>>

CreateOverlay(o, d, b) ==
    /\ o \in Overlays
    /\ d \in Domains
    /\ b \in Bases
    /\ overlayState[o] \in {"free", "cancelled"}
    /\ NoOverlayMappings(o)
    /\ baseState[b] = "sealed"
    /\ overlayState' = [overlayState EXCEPT ![o] = "clean"]
    /\ overlayOwner' = [overlayOwner EXCEPT ![o] = d]
    /\ overlayEpoch' = [overlayEpoch EXCEPT ![o] = domainEpoch[d]]
    /\ overlayBase' = [overlayBase EXCEPT ![o] = b]
    /\ overlayBaseVersion' = [overlayBaseVersion EXCEPT ![o] = baseVersion[b]]
    /\ workTicket' = [workTicket EXCEPT ![o] = 0]
    /\ workServiceEpoch' = [workServiceEpoch EXCEPT ![o] = serviceEpoch]
    /\ UNCHANGED <<domainEpoch, serviceEpoch, baseState, baseVersion,
                    mappedBase, mappedOverlay, linuxShadowOwner>>

MapOverlay(d, o) ==
    /\ d \in Domains
    /\ o \in Overlays
    /\ OverlayLiveForDomain(o, d)
    /\ mappedOverlay' = [mappedOverlay EXCEPT ![d] = @ \cup {o}]
    /\ UNCHANGED <<domainEpoch, serviceEpoch, baseState, baseVersion,
                    overlayState, overlayOwner, overlayEpoch, overlayBase,
                    overlayBaseVersion, workTicket, workServiceEpoch,
                    mappedBase, linuxShadowOwner>>

UnmapOverlay(d, o) ==
    /\ d \in Domains
    /\ o \in Overlays
    /\ o \in mappedOverlay[d]
    /\ mappedOverlay' = [mappedOverlay EXCEPT ![d] = @ \ {o}]
    /\ UNCHANGED <<domainEpoch, serviceEpoch, baseState, baseVersion,
                    overlayState, overlayOwner, overlayEpoch, overlayBase,
                    overlayBaseVersion, workTicket, workServiceEpoch,
                    mappedBase, linuxShadowOwner>>

DirtyOverlay(d, o) ==
    /\ d \in Domains
    /\ o \in Overlays
    /\ o \in mappedOverlay[d]
    /\ OverlayLiveForDomain(o, d)
    /\ overlayState[o] = "clean"
    /\ overlayState' = [overlayState EXCEPT ![o] = "dirty"]
    /\ UNCHANGED <<domainEpoch, serviceEpoch, baseState, baseVersion,
                    overlayOwner, overlayEpoch, overlayBase,
                    overlayBaseVersion, workTicket, workServiceEpoch,
                    mappedBase, mappedOverlay, linuxShadowOwner>>

QueueWriteback(o) ==
    /\ o \in Overlays
    /\ overlayState[o] = "dirty"
    /\ OverlayLiveForDomain(o, overlayOwner[o])
    /\ overlayState' = [overlayState EXCEPT ![o] = "queued"]
    /\ workTicket' = [workTicket EXCEPT ![o] = MaxTicket]
    /\ workServiceEpoch' = [workServiceEpoch EXCEPT ![o] = serviceEpoch]
    /\ UNCHANGED <<domainEpoch, serviceEpoch, baseState, baseVersion,
                    overlayOwner, overlayEpoch, overlayBase,
                    overlayBaseVersion, mappedBase, mappedOverlay,
                    linuxShadowOwner>>

StartCommit(o) ==
    /\ o \in Overlays
    /\ overlayState[o] = "queued"
    /\ WorkLive(o)
    /\ OverlayCurrent(o)
    /\ CommittingOverlaysForBase(overlayBase[o]) = {}
    /\ overlayState' = [overlayState EXCEPT ![o] = "committing"]
    /\ UNCHANGED <<domainEpoch, serviceEpoch, baseState, baseVersion,
                    overlayOwner, overlayEpoch, overlayBase,
                    overlayBaseVersion, workTicket, workServiceEpoch,
                    mappedBase, mappedOverlay, linuxShadowOwner>>

FinishCommit(o) ==
    /\ o \in Overlays
    /\ overlayState[o] = "committing"
    /\ WorkLive(o)
    /\ OverlayCurrent(o)
    /\ LET b == overlayBase[o] IN
        /\ baseVersion[b] < MaxVersion
        /\ baseVersion' = [baseVersion EXCEPT ![b] = @ + 1]
        /\ overlayBaseVersion' = [overlayBaseVersion EXCEPT ![o] = baseVersion[b] + 1]
    /\ overlayState' = [overlayState EXCEPT ![o] = "clean"]
    /\ workTicket' = [workTicket EXCEPT ![o] = 0]
    /\ workServiceEpoch' = [workServiceEpoch EXCEPT ![o] = serviceEpoch]
    /\ UNCHANGED <<domainEpoch, serviceEpoch, baseState, overlayOwner,
                    overlayEpoch, overlayBase, mappedBase, mappedOverlay,
                    linuxShadowOwner>>

MarkConflict(o) ==
    /\ o \in Overlays
    /\ overlayState[o] = "queued"
    /\ WorkLive(o)
    /\ ~OverlayCurrent(o)
    /\ overlayState' = [overlayState EXCEPT ![o] = "conflict"]
    /\ workTicket' = [workTicket EXCEPT ![o] = 0]
    /\ workServiceEpoch' = [workServiceEpoch EXCEPT ![o] = serviceEpoch]
    /\ UNCHANGED <<domainEpoch, serviceEpoch, baseState, baseVersion,
                    overlayOwner, overlayEpoch, overlayBase,
                    overlayBaseVersion, mappedBase, mappedOverlay,
                    linuxShadowOwner>>

CancelWriteback(o) ==
    /\ o \in Overlays
    /\ overlayState[o] \in PendingWritebackStates
    /\ OverlayLiveForDomain(o, overlayOwner[o])
    /\ overlayState' = [overlayState EXCEPT ![o] = "dirty"]
    /\ workTicket' = [workTicket EXCEPT ![o] = 0]
    /\ workServiceEpoch' = [workServiceEpoch EXCEPT ![o] = serviceEpoch]
    /\ UNCHANGED <<domainEpoch, serviceEpoch, baseState, baseVersion,
                    overlayOwner, overlayEpoch, overlayBase,
                    overlayBaseVersion, mappedBase, mappedOverlay,
                    linuxShadowOwner>>

RebaseConflict(o) ==
    /\ o \in Overlays
    /\ overlayState[o] = "conflict"
    /\ OverlayLiveForDomain(o, overlayOwner[o])
    /\ overlayBase[o] \in Bases
    /\ overlayBaseVersion' = [overlayBaseVersion EXCEPT ![o] = baseVersion[overlayBase[o]]]
    /\ overlayState' = [overlayState EXCEPT ![o] = "dirty"]
    /\ UNCHANGED <<domainEpoch, serviceEpoch, baseState, baseVersion,
                    overlayOwner, overlayEpoch, overlayBase, workTicket,
                    workServiceEpoch, mappedBase, mappedOverlay,
                    linuxShadowOwner>>

FreeOverlay(o) ==
    /\ o \in Overlays
    /\ overlayState[o] \in {"clean", "dirty", "conflict", "cancelled"}
    /\ NoOverlayMappings(o)
    /\ overlayState' = [overlayState EXCEPT ![o] = "free"]
    /\ overlayOwner' = [overlayOwner EXCEPT ![o] = NoDomain]
    /\ overlayEpoch' = [overlayEpoch EXCEPT ![o] = 0]
    /\ overlayBase' = [overlayBase EXCEPT ![o] = NoBase]
    /\ overlayBaseVersion' = [overlayBaseVersion EXCEPT ![o] = 0]
    /\ workTicket' = [workTicket EXCEPT ![o] = 0]
    /\ workServiceEpoch' = [workServiceEpoch EXCEPT ![o] = 0]
    /\ UNCHANGED <<domainEpoch, serviceEpoch, baseState, baseVersion,
                    mappedBase, mappedOverlay, linuxShadowOwner>>

RevokeDomain(d) ==
    /\ d \in Domains
    /\ domainEpoch[d] < MaxEpoch
    /\ LET owned == {o \in Overlays : overlayOwner[o] = d} IN
        /\ domainEpoch' = [domainEpoch EXCEPT ![d] = @ + 1]
        /\ overlayState' = [o \in Overlays |->
            IF o \in owned THEN "free" ELSE overlayState[o]]
        /\ overlayOwner' = [o \in Overlays |->
            IF o \in owned THEN NoDomain ELSE overlayOwner[o]]
        /\ overlayEpoch' = [o \in Overlays |->
            IF o \in owned THEN 0 ELSE overlayEpoch[o]]
        /\ overlayBase' = [o \in Overlays |->
            IF o \in owned THEN NoBase ELSE overlayBase[o]]
        /\ overlayBaseVersion' = [o \in Overlays |->
            IF o \in owned THEN 0 ELSE overlayBaseVersion[o]]
        /\ workTicket' = [o \in Overlays |->
            IF o \in owned THEN 0 ELSE workTicket[o]]
        /\ workServiceEpoch' = [o \in Overlays |->
            IF o \in owned THEN 0 ELSE workServiceEpoch[o]]
        /\ mappedOverlay' = [x \in Domains |-> mappedOverlay[x] \ owned]
    /\ UNCHANGED <<serviceEpoch, baseState, baseVersion, mappedBase,
                    linuxShadowOwner>>

RevokeService ==
    /\ serviceEpoch < MaxEpoch
    /\ serviceEpoch' = serviceEpoch + 1
    /\ overlayState' = [o \in Overlays |->
        IF overlayState[o] \in PendingWritebackStates
        THEN "dirty"
        ELSE overlayState[o]]
    /\ workTicket' = [o \in Overlays |->
        IF overlayState[o] \in PendingWritebackStates
        THEN 0
        ELSE workTicket[o]]
    /\ workServiceEpoch' = [o \in Overlays |->
        IF overlayState[o] \in PendingWritebackStates
        THEN 0
        ELSE workServiceEpoch[o]]
    /\ UNCHANGED <<domainEpoch, baseState, baseVersion, overlayOwner,
                    overlayEpoch, overlayBase, overlayBaseVersion, mappedBase,
                    mappedOverlay, linuxShadowOwner>>

Next ==
    \/ \E o \in Overlays, d \in Domains:
        ForgeLinuxShadowOwner(o, d)
    \/ \E b \in Bases:
        CreateSealedBase(b)
    \/ \E d \in Domains, b \in Bases:
        MapBase(d, b)
    \/ \E d \in Domains, b \in Bases:
        UnmapBase(d, b)
    \/ \E o \in Overlays, d \in Domains, b \in Bases:
        CreateOverlay(o, d, b)
    \/ \E d \in Domains, o \in Overlays:
        MapOverlay(d, o)
    \/ \E d \in Domains, o \in Overlays:
        UnmapOverlay(d, o)
    \/ \E d \in Domains, o \in Overlays:
        DirtyOverlay(d, o)
    \/ \E o \in Overlays:
        QueueWriteback(o)
    \/ \E o \in Overlays:
        StartCommit(o)
    \/ \E o \in Overlays:
        FinishCommit(o)
    \/ \E o \in Overlays:
        MarkConflict(o)
    \/ \E o \in Overlays:
        CancelWriteback(o)
    \/ \E o \in Overlays:
        RebaseConflict(o)
    \/ \E o \in Overlays:
        FreeOverlay(o)
    \/ \E d \in Domains:
        RevokeDomain(d)
    \/ RevokeService

Spec == Init /\ [][Next]_vars

NoOverlayMappingWithoutLiveOwner ==
    \A d \in Domains:
        \A o \in mappedOverlay[d]:
            OverlayLiveForDomain(o, d)

NoMutableOverlayMappedAcrossDomains ==
    \A o \in Overlays:
        overlayState[o] \in LiveOverlayStates =>
            MappedOverlayDomains(o) \subseteq {overlayOwner[o]}

NoFreeOverlayMappedOrPending ==
    \A o \in Overlays:
        overlayState[o] = "free" =>
            /\ NoOverlayMappings(o)
            /\ overlayOwner[o] = NoDomain
            /\ overlayBase[o] = NoBase
            /\ workTicket[o] = 0

NoWritebackWithoutProvenanceTicket ==
    \A o \in Overlays:
        overlayState[o] \in PendingWritebackStates => WorkLive(o)

NoStaleOverlayCanCommit ==
    \A o \in Overlays:
        overlayState[o] = "committing" => OverlayCurrent(o)

NoLinuxShadowOwnerAuthority ==
    \A o \in Overlays:
        \A d \in Domains:
            linuxShadowOwner[o] = d /\ ~OverlayLiveForDomain(o, d) =>
                /\ o \notin mappedOverlay[d]
                /\ ~(overlayState[o] \in PendingWritebackStates /\ overlayOwner[o] = d)

NoBaseMissingForLiveOverlay ==
    \A o \in Overlays:
        overlayState[o] \in LiveOverlayStates =>
            /\ overlayBase[o] \in Bases
            /\ baseState[overlayBase[o]] = "sealed"

=============================================================================
