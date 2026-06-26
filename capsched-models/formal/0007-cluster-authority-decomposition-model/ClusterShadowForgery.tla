----------------------- MODULE ClusterShadowForgery -----------------------
EXTENDS Naturals, FiniteSets

CONSTANTS
    D1, D2,
    N1, N2,
    L1, L2,
    E1, E2,
    NoDomain,
    NoLease,
    NoEndpoint,
    MaxEpoch

VARIABLES
    clusterEpoch,
    leaseValid,
    leaseDomain,
    leaseEpoch,
    leaseNodes,
    leaseEndpoints,
    localValid,
    localDomain,
    localEpoch,
    localEndpoints,
    activeLease,
    activeDomain,
    endpointUse,
    localShadow

vars == <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch, leaseNodes,
          leaseEndpoints, localValid, localDomain, localEpoch, localEndpoints,
          activeLease, activeDomain, endpointUse, localShadow>>

Domains == {D1, D2}
Nodes == {N1, N2}
Leases == {L1, L2}
Endpoints == {E1, E2}

DomainOrNone == Domains \cup {NoDomain}
LeaseOrNone == Leases \cup {NoLease}
EndpointOrNone == Endpoints \cup {NoEndpoint}

Epochs == 0..MaxEpoch
NodeSets == SUBSET Nodes
NonEmptyNodeSets == NodeSets \ {{}}
EndpointSets == SUBSET Endpoints
NonEmptyEndpointSets == EndpointSets \ {{}}

UseRecord == [
    valid: BOOLEAN,
    lease: LeaseOrNone,
    domain: DomainOrNone,
    epoch: Epochs,
    endpoint: EndpointOrNone
]

UseNone == [
    valid |-> FALSE,
    lease |-> NoLease,
    domain |-> NoDomain,
    epoch |-> 0,
    endpoint |-> NoEndpoint
]

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
    /\ localEndpoints[n][l] \subseteq leaseEndpoints[l]

TypeOK ==
    /\ D1 # D2
    /\ N1 # N2
    /\ L1 # L2
    /\ E1 # E2
    /\ NoDomain \notin Domains
    /\ NoLease \notin Leases
    /\ NoEndpoint \notin Endpoints
    /\ MaxEpoch \in Nat
    /\ clusterEpoch \in [Domains -> Epochs]
    /\ leaseValid \in [Leases -> BOOLEAN]
    /\ leaseDomain \in [Leases -> DomainOrNone]
    /\ leaseEpoch \in [Leases -> Epochs]
    /\ leaseNodes \in [Leases -> NodeSets]
    /\ leaseEndpoints \in [Leases -> EndpointSets]
    /\ localValid \in [Nodes -> [Leases -> BOOLEAN]]
    /\ localDomain \in [Nodes -> [Leases -> DomainOrNone]]
    /\ localEpoch \in [Nodes -> [Leases -> Epochs]]
    /\ localEndpoints \in [Nodes -> [Leases -> EndpointSets]]
    /\ activeLease \in [Nodes -> LeaseOrNone]
    /\ activeDomain \in [Nodes -> DomainOrNone]
    /\ endpointUse \in [Nodes -> UseRecord]
    /\ localShadow \in [Nodes -> BOOLEAN]

Init ==
    /\ clusterEpoch = [d \in Domains |-> 0]
    /\ leaseValid = [l \in Leases |-> FALSE]
    /\ leaseDomain = [l \in Leases |-> NoDomain]
    /\ leaseEpoch = [l \in Leases |-> 0]
    /\ leaseNodes = [l \in Leases |-> {}]
    /\ leaseEndpoints = [l \in Leases |-> {}]
    /\ localValid = [n \in Nodes |-> [l \in Leases |-> FALSE]]
    /\ localDomain = [n \in Nodes |-> [l \in Leases |-> NoDomain]]
    /\ localEpoch = [n \in Nodes |-> [l \in Leases |-> 0]]
    /\ localEndpoints = [n \in Nodes |-> [l \in Leases |-> {}]]
    /\ activeLease = [n \in Nodes |-> NoLease]
    /\ activeDomain = [n \in Nodes |-> NoDomain]
    /\ endpointUse = [n \in Nodes |-> UseNone]
    /\ localShadow = [n \in Nodes |-> FALSE]

IssueLease(l, d, nodes, eps) ==
    /\ l \in Leases
    /\ d \in Domains
    /\ nodes \in NonEmptyNodeSets
    /\ eps \in NonEmptyEndpointSets
    /\ ~leaseValid[l]
    /\ leaseValid' = [leaseValid EXCEPT ![l] = TRUE]
    /\ leaseDomain' = [leaseDomain EXCEPT ![l] = d]
    /\ leaseEpoch' = [leaseEpoch EXCEPT ![l] = clusterEpoch[d]]
    /\ leaseNodes' = [leaseNodes EXCEPT ![l] = nodes]
    /\ leaseEndpoints' = [leaseEndpoints EXCEPT ![l] = eps]
    /\ UNCHANGED <<clusterEpoch, localValid, localDomain, localEpoch,
                    localEndpoints, activeLease, activeDomain, endpointUse,
                    localShadow>>

CompileLocal(n, l, eps) ==
    /\ n \in Nodes
    /\ l \in Leases
    /\ eps \in NonEmptyEndpointSets
    /\ leaseValid[l]
    /\ leaseEpoch[l] = clusterEpoch[leaseDomain[l]]
    /\ n \in leaseNodes[l]
    /\ eps \subseteq leaseEndpoints[l]
    /\ ~localValid[n][l]
    /\ localValid' = [localValid EXCEPT ![n] =
        [localValid[n] EXCEPT ![l] = TRUE]]
    /\ localDomain' = [localDomain EXCEPT ![n] =
        [localDomain[n] EXCEPT ![l] = leaseDomain[l]]]
    /\ localEpoch' = [localEpoch EXCEPT ![n] =
        [localEpoch[n] EXCEPT ![l] = leaseEpoch[l]]]
    /\ localEndpoints' = [localEndpoints EXCEPT ![n] =
        [localEndpoints[n] EXCEPT ![l] = eps]]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, activeLease, activeDomain,
                    endpointUse, localShadow>>

ForgeLocalShadow(n) ==
    /\ n \in Nodes
    /\ localShadow' = [localShadow EXCEPT ![n] = TRUE]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, localValid, localDomain,
                    localEpoch, localEndpoints, activeLease, activeDomain,
                    endpointUse>>

ActivateLocal(n, l) ==
    /\ n \in Nodes
    /\ l \in Leases
    /\ activeLease[n] = NoLease
    /\ LocalLive(n, l)
    /\ activeLease' = [activeLease EXCEPT ![n] = l]
    /\ activeDomain' = [activeDomain EXCEPT ![n] = localDomain[n][l]]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, localValid, localDomain,
                    localEpoch, localEndpoints, endpointUse, localShadow>>

StopNode(n) ==
    /\ n \in Nodes
    /\ activeLease[n] # NoLease
    /\ activeLease' = [activeLease EXCEPT ![n] = NoLease]
    /\ activeDomain' = [activeDomain EXCEPT ![n] = NoDomain]
    /\ endpointUse' = [endpointUse EXCEPT ![n] = UseNone]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, localValid, localDomain,
                    localEpoch, localEndpoints, localShadow>>

StartEndpointUse(n, e) ==
    /\ n \in Nodes
    /\ e \in Endpoints
    /\ activeLease[n] # NoLease
    /\ endpointUse[n].valid = FALSE
    /\ LET l == activeLease[n] IN
        /\ LocalLive(n, l)
        /\ e \in localEndpoints[n][l]
        /\ endpointUse' = [endpointUse EXCEPT ![n] =
            [valid |-> TRUE,
             lease |-> l,
             domain |-> localDomain[n][l],
             epoch |-> localEpoch[n][l],
             endpoint |-> e]]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, localValid, localDomain,
                    localEpoch, localEndpoints, activeLease, activeDomain,
                    localShadow>>

CompleteEndpointUse(n) ==
    /\ n \in Nodes
    /\ endpointUse[n].valid
    /\ endpointUse' = [endpointUse EXCEPT ![n] = UseNone]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, localValid, localDomain,
                    localEpoch, localEndpoints, activeLease, activeDomain,
                    localShadow>>

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
    /\ localEndpoints' = [n \in Nodes |->
        [x \in Leases |-> IF x = l THEN {} ELSE localEndpoints[n][x]]]
    /\ activeLease' = [n \in Nodes |->
        IF activeLease[n] = l THEN NoLease ELSE activeLease[n]]
    /\ activeDomain' = [n \in Nodes |->
        IF activeLease[n] = l THEN NoDomain ELSE activeDomain[n]]
    /\ endpointUse' = [n \in Nodes |->
        IF endpointUse[n].valid /\ endpointUse[n].lease = l
        THEN UseNone
        ELSE endpointUse[n]]
    /\ UNCHANGED <<clusterEpoch, leaseDomain, leaseEpoch, leaseNodes,
                    leaseEndpoints, localShadow>>

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
    /\ localEndpoints' = [n \in Nodes |->
        [l \in Leases |->
            IF LeaseUsesDomain(l, d) THEN {} ELSE localEndpoints[n][l]]]
    /\ activeLease' = [n \in Nodes |->
        IF activeLease[n] # NoLease /\ LeaseUsesDomain(activeLease[n], d)
        THEN NoLease
        ELSE activeLease[n]]
    /\ activeDomain' = [n \in Nodes |->
        IF activeDomain[n] = d THEN NoDomain ELSE activeDomain[n]]
    /\ endpointUse' = [n \in Nodes |->
        IF endpointUse[n].valid /\ endpointUse[n].domain = d
        THEN UseNone
        ELSE endpointUse[n]]
    /\ UNCHANGED <<leaseDomain, leaseEpoch, leaseNodes, leaseEndpoints,
                    localShadow>>

Next ==
    \/ \E l \in Leases, d \in Domains, nodes \in NonEmptyNodeSets,
          eps \in NonEmptyEndpointSets:
        IssueLease(l, d, nodes, eps)
    \/ \E n \in Nodes, l \in Leases, eps \in NonEmptyEndpointSets:
        CompileLocal(n, l, eps)
    \/ \E n \in Nodes:
        ForgeLocalShadow(n)
    \/ \E n \in Nodes, l \in Leases:
        ActivateLocal(n, l)
    \/ \E n \in Nodes:
        StopNode(n)
    \/ \E n \in Nodes, e \in Endpoints:
        StartEndpointUse(n, e)
    \/ \E n \in Nodes:
        CompleteEndpointUse(n)
    \/ \E l \in Leases:
        RevokeLease(l)
    \/ \E d \in Domains:
        RevokeDomain(d)

Spec == Init /\ [][Next]_vars

NoLocalContextWithoutValidLease ==
    \A n \in Nodes:
        \A l \in Leases:
            localValid[n][l] => LocalLive(n, l)

NoActiveWithoutCompiledContext ==
    \A n \in Nodes:
        activeLease[n] # NoLease =>
            /\ LocalLive(n, activeLease[n])
            /\ activeDomain[n] = localDomain[n][activeLease[n]]

NoEndpointUseWithoutCompiledEndpointCap ==
    \A n \in Nodes:
        endpointUse[n].valid =>
            /\ activeLease[n] = endpointUse[n].lease
            /\ LocalLive(n, endpointUse[n].lease)
            /\ endpointUse[n].domain = activeDomain[n]
            /\ endpointUse[n].epoch = localEpoch[n][endpointUse[n].lease]
            /\ endpointUse[n].endpoint
                \in localEndpoints[n][endpointUse[n].lease]

NoShadowClaimConfersAuthority ==
    \A n \in Nodes:
        localShadow[n] /\ activeLease[n] = NoLease =>
            /\ activeDomain[n] = NoDomain
            /\ endpointUse[n].valid = FALSE

NoShadowEndpointClaimConfersAuthority ==
    \A n \in Nodes:
        localShadow[n] /\ endpointUse[n].valid =>
            /\ endpointUse[n].endpoint
                \in localEndpoints[n][endpointUse[n].lease]
            /\ LocalLive(n, endpointUse[n].lease)

=============================================================================
