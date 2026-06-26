------------------------ MODULE ClusterEpochRevoke ------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS
    D1, D2,
    N1, N2,
    L1, L2,
    NoDomain,
    NoLease,
    MaxEpoch

VARIABLES
    clusterEpoch,
    leaseValid,
    leaseDomain,
    leaseEpoch,
    leaseNodes,
    localValid,
    localDomain,
    localEpoch,
    activeLease,
    activeDomain,
    activeEpoch,
    mutableClaim

vars == <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch, leaseNodes,
          localValid, localDomain, localEpoch, activeLease, activeDomain,
          activeEpoch, mutableClaim>>

Domains == {D1, D2}
Nodes == {N1, N2}
Leases == {L1, L2}

DomainOrNone == Domains \cup {NoDomain}
LeaseOrNone == Leases \cup {NoLease}

Epochs == 0..MaxEpoch
NodeSets == SUBSET Nodes
NonEmptyNodeSets == NodeSets \ {{}}

LeaseUsesDomain(l, d) ==
    /\ l \in Leases
    /\ d \in Domains
    /\ leaseValid[l]
    /\ leaseDomain[l] = d

LocalLive(n, l) ==
    /\ n \in Nodes
    /\ l \in Leases
    /\ localValid[n][l]
    /\ leaseValid[l]
    /\ localDomain[n][l] = leaseDomain[l]
    /\ localEpoch[n][l] = leaseEpoch[l]
    /\ localEpoch[n][l] = clusterEpoch[localDomain[n][l]]
    /\ n \in leaseNodes[l]

TypeOK ==
    /\ D1 # D2
    /\ N1 # N2
    /\ L1 # L2
    /\ NoDomain \notin Domains
    /\ NoLease \notin Leases
    /\ MaxEpoch \in Nat
    /\ clusterEpoch \in [Domains -> Epochs]
    /\ leaseValid \in [Leases -> BOOLEAN]
    /\ leaseDomain \in [Leases -> DomainOrNone]
    /\ leaseEpoch \in [Leases -> Epochs]
    /\ leaseNodes \in [Leases -> NodeSets]
    /\ localValid \in [Nodes -> [Leases -> BOOLEAN]]
    /\ localDomain \in [Nodes -> [Leases -> DomainOrNone]]
    /\ localEpoch \in [Nodes -> [Leases -> Epochs]]
    /\ activeLease \in [Nodes -> LeaseOrNone]
    /\ activeDomain \in [Nodes -> DomainOrNone]
    /\ activeEpoch \in [Nodes -> Epochs]
    /\ mutableClaim \in [Nodes -> BOOLEAN]

Init ==
    /\ clusterEpoch = [d \in Domains |-> 0]
    /\ leaseValid = [l \in Leases |-> FALSE]
    /\ leaseDomain = [l \in Leases |-> NoDomain]
    /\ leaseEpoch = [l \in Leases |-> 0]
    /\ leaseNodes = [l \in Leases |-> {}]
    /\ localValid = [n \in Nodes |-> [l \in Leases |-> FALSE]]
    /\ localDomain = [n \in Nodes |-> [l \in Leases |-> NoDomain]]
    /\ localEpoch = [n \in Nodes |-> [l \in Leases |-> 0]]
    /\ activeLease = [n \in Nodes |-> NoLease]
    /\ activeDomain = [n \in Nodes |-> NoDomain]
    /\ activeEpoch = [n \in Nodes |-> 0]
    /\ mutableClaim = [n \in Nodes |-> FALSE]

IssueLease(l, d, nodes) ==
    /\ l \in Leases
    /\ d \in Domains
    /\ nodes \in NonEmptyNodeSets
    /\ ~leaseValid[l]
    /\ leaseValid' = [leaseValid EXCEPT ![l] = TRUE]
    /\ leaseDomain' = [leaseDomain EXCEPT ![l] = d]
    /\ leaseEpoch' = [leaseEpoch EXCEPT ![l] = clusterEpoch[d]]
    /\ leaseNodes' = [leaseNodes EXCEPT ![l] = nodes]
    /\ UNCHANGED <<clusterEpoch, localValid, localDomain, localEpoch,
                    activeLease, activeDomain, activeEpoch, mutableClaim>>

CompileLocal(n, l) ==
    /\ n \in Nodes
    /\ l \in Leases
    /\ leaseValid[l]
    /\ leaseEpoch[l] = clusterEpoch[leaseDomain[l]]
    /\ n \in leaseNodes[l]
    /\ ~localValid[n][l]
    /\ localValid' = [localValid EXCEPT ![n] =
        [localValid[n] EXCEPT ![l] = TRUE]]
    /\ localDomain' = [localDomain EXCEPT ![n] =
        [localDomain[n] EXCEPT ![l] = leaseDomain[l]]]
    /\ localEpoch' = [localEpoch EXCEPT ![n] =
        [localEpoch[n] EXCEPT ![l] = leaseEpoch[l]]]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, activeLease, activeDomain, activeEpoch,
                    mutableClaim>>

ForgeMutableClaim(n) ==
    /\ n \in Nodes
    /\ mutableClaim' = [mutableClaim EXCEPT ![n] = TRUE]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, localValid, localDomain, localEpoch,
                    activeLease, activeDomain, activeEpoch>>

ActivateLocal(n, l) ==
    /\ n \in Nodes
    /\ l \in Leases
    /\ activeLease[n] = NoLease
    /\ LocalLive(n, l)
    /\ activeLease' = [activeLease EXCEPT ![n] = l]
    /\ activeDomain' = [activeDomain EXCEPT ![n] = localDomain[n][l]]
    /\ activeEpoch' = [activeEpoch EXCEPT ![n] = localEpoch[n][l]]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, localValid, localDomain, localEpoch,
                    mutableClaim>>

StopNode(n) ==
    /\ n \in Nodes
    /\ activeLease[n] # NoLease
    /\ activeLease' = [activeLease EXCEPT ![n] = NoLease]
    /\ activeDomain' = [activeDomain EXCEPT ![n] = NoDomain]
    /\ activeEpoch' = [activeEpoch EXCEPT ![n] = 0]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, localValid, localDomain, localEpoch,
                    mutableClaim>>

RevokeLease(l) ==
    /\ l \in Leases
    /\ leaseValid[l]
    /\ leaseValid' = [leaseValid EXCEPT ![l] = FALSE]
    /\ localValid' = [n \in Nodes |->
        [x \in Leases |-> IF x = l THEN FALSE ELSE localValid[n][x]]]
    /\ localDomain' = [n \in Nodes |->
        [x \in Leases |-> IF x = l THEN NoDomain ELSE localDomain[n][x]]]
    /\ localEpoch' = [n \in Nodes |->
        [x \in Leases |-> IF x = l THEN 0 ELSE localEpoch[n][x]]]
    /\ activeLease' = [n \in Nodes |->
        IF activeLease[n] = l THEN NoLease ELSE activeLease[n]]
    /\ activeDomain' = [n \in Nodes |->
        IF activeLease[n] = l THEN NoDomain ELSE activeDomain[n]]
    /\ activeEpoch' = [n \in Nodes |->
        IF activeLease[n] = l THEN 0 ELSE activeEpoch[n]]
    /\ UNCHANGED <<clusterEpoch, leaseDomain, leaseEpoch, leaseNodes,
                    mutableClaim>>

RevokeDomain(d) ==
    /\ d \in Domains
    /\ clusterEpoch[d] < MaxEpoch
    /\ clusterEpoch' = [clusterEpoch EXCEPT ![d] = @ + 1]
    /\ leaseValid' = [l \in Leases |->
        IF LeaseUsesDomain(l, d) THEN FALSE ELSE leaseValid[l]]
    /\ localValid' = [n \in Nodes |->
        [l \in Leases |->
            IF LeaseUsesDomain(l, d) THEN FALSE ELSE localValid[n][l]]]
    /\ localDomain' = [n \in Nodes |->
        [l \in Leases |->
            IF LeaseUsesDomain(l, d) THEN NoDomain ELSE localDomain[n][l]]]
    /\ localEpoch' = [n \in Nodes |->
        [l \in Leases |->
            IF LeaseUsesDomain(l, d) THEN 0 ELSE localEpoch[n][l]]]
    /\ activeLease' = [n \in Nodes |->
        IF activeDomain[n] = d THEN NoLease ELSE activeLease[n]]
    /\ activeDomain' = [n \in Nodes |->
        IF activeDomain[n] = d THEN NoDomain ELSE activeDomain[n]]
    /\ activeEpoch' = [n \in Nodes |->
        IF activeDomain[n] = d THEN 0 ELSE activeEpoch[n]]
    /\ UNCHANGED <<leaseDomain, leaseEpoch, leaseNodes, mutableClaim>>

Next ==
    \/ \E l \in Leases, d \in Domains, nodes \in NonEmptyNodeSets:
        IssueLease(l, d, nodes)
    \/ \E n \in Nodes, l \in Leases:
        CompileLocal(n, l)
    \/ \E n \in Nodes:
        ForgeMutableClaim(n)
    \/ \E n \in Nodes, l \in Leases:
        ActivateLocal(n, l)
    \/ \E n \in Nodes:
        StopNode(n)
    \/ \E l \in Leases:
        RevokeLease(l)
    \/ \E d \in Domains:
        RevokeDomain(d)

Spec == Init /\ [][Next]_vars

NoLocalContextWithoutLiveEpoch ==
    \A n \in Nodes:
        \A l \in Leases:
            localValid[n][l] => LocalLive(n, l)

NoActiveWithoutLiveEpoch ==
    \A n \in Nodes:
        activeLease[n] # NoLease =>
            /\ LocalLive(n, activeLease[n])
            /\ activeDomain[n] = localDomain[n][activeLease[n]]
            /\ activeEpoch[n] = localEpoch[n][activeLease[n]]

NoActiveAfterDomainRevoke ==
    \A n \in Nodes:
        activeDomain[n] # NoDomain =>
            /\ activeEpoch[n] = clusterEpoch[activeDomain[n]]
            /\ activeLease[n] \in Leases
            /\ leaseValid[activeLease[n]]

NoMutableClaimConfersExecution ==
    \A n \in Nodes:
        mutableClaim[n] /\ activeLease[n] = NoLease =>
            /\ activeDomain[n] = NoDomain
            /\ activeEpoch[n] = 0

=============================================================================
