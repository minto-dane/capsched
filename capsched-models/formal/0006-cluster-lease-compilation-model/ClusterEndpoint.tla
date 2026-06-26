-------------------------- MODULE ClusterEndpoint --------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS
    D1, D2,
    N1, N2,
    L1, L2,
    E1, E2,
    NoDomain,
    NoNode,
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
    leaseMultiNode,
    localValid,
    localEndpoints,
    activeLease,
    activeDomain,
    endpointUse,
    localShadow

vars == <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch, leaseNodes,
          leaseEndpoints, leaseMultiNode, localValid, localEndpoints,
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

ShadowRecord == [
    valid: BOOLEAN,
    lease: LeaseOrNone,
    domain: DomainOrNone,
    epoch: Epochs,
    endpoints: EndpointSets
]

UseNone == [
    valid |-> FALSE,
    lease |-> NoLease,
    domain |-> NoDomain,
    epoch |-> 0,
    endpoint |-> NoEndpoint
]

ShadowNone == [
    valid |-> FALSE,
    lease |-> NoLease,
    domain |-> NoDomain,
    epoch |-> 0,
    endpoints |-> {}
]

LeaseUsesDomain(l, d) ==
    /\ leaseValid[l]
    /\ leaseDomain[l] = d

CtxLive(n, l) ==
    /\ n \in Nodes
    /\ l \in Leases
    /\ localValid[n][l]
    /\ leaseValid[l]
    /\ leaseEpoch[l] = clusterEpoch[leaseDomain[l]]
    /\ n \in leaseNodes[l]
    /\ localEndpoints[n][l] \subseteq leaseEndpoints[l]

ActiveNodesForLease(l) ==
    {n \in Nodes : activeLease[n] = l}

TypeOK ==
    /\ D1 # D2
    /\ N1 # N2
    /\ L1 # L2
    /\ E1 # E2
    /\ NoDomain \notin Domains
    /\ NoNode \notin Nodes
    /\ NoLease \notin Leases
    /\ NoEndpoint \notin Endpoints
    /\ MaxEpoch \in Nat
    /\ clusterEpoch \in [Domains -> Epochs]
    /\ leaseValid \in [Leases -> BOOLEAN]
    /\ leaseDomain \in [Leases -> DomainOrNone]
    /\ leaseEpoch \in [Leases -> Epochs]
    /\ leaseNodes \in [Leases -> NodeSets]
    /\ leaseEndpoints \in [Leases -> EndpointSets]
    /\ leaseMultiNode \in [Leases -> BOOLEAN]
    /\ localValid \in [Nodes -> [Leases -> BOOLEAN]]
    /\ localEndpoints \in [Nodes -> [Leases -> EndpointSets]]
    /\ activeLease \in [Nodes -> LeaseOrNone]
    /\ activeDomain \in [Nodes -> DomainOrNone]
    /\ endpointUse \in [Nodes -> UseRecord]
    /\ localShadow \in [Nodes -> ShadowRecord]

Init ==
    /\ clusterEpoch = [d \in Domains |-> 0]
    /\ leaseValid = [l \in Leases |-> FALSE]
    /\ leaseDomain = [l \in Leases |-> NoDomain]
    /\ leaseEpoch = [l \in Leases |-> 0]
    /\ leaseNodes = [l \in Leases |-> {}]
    /\ leaseEndpoints = [l \in Leases |-> {}]
    /\ leaseMultiNode = [l \in Leases |-> FALSE]
    /\ localValid = [n \in Nodes |-> [l \in Leases |-> FALSE]]
    /\ localEndpoints = [n \in Nodes |-> [l \in Leases |-> {}]]
    /\ activeLease = [n \in Nodes |-> NoLease]
    /\ activeDomain = [n \in Nodes |-> NoDomain]
    /\ endpointUse = [n \in Nodes |-> UseNone]
    /\ localShadow = [n \in Nodes |-> ShadowNone]

IssueLease(l, d, nodes, eps, multi) ==
    /\ l \in Leases
    /\ d \in Domains
    /\ nodes \in NonEmptyNodeSets
    /\ eps \in NonEmptyEndpointSets
    /\ multi \in BOOLEAN
    /\ ~leaseValid[l]
    /\ leaseValid' = [leaseValid EXCEPT ![l] = TRUE]
    /\ leaseDomain' = [leaseDomain EXCEPT ![l] = d]
    /\ leaseEpoch' = [leaseEpoch EXCEPT ![l] = clusterEpoch[d]]
    /\ leaseNodes' = [leaseNodes EXCEPT ![l] = nodes]
    /\ leaseEndpoints' = [leaseEndpoints EXCEPT ![l] = eps]
    /\ leaseMultiNode' = [leaseMultiNode EXCEPT ![l] = multi]
    /\ UNCHANGED <<clusterEpoch, localValid, localEndpoints, activeLease,
                    activeDomain, endpointUse, localShadow>>

ForgeLocalShadow(n, l, d, e, eps) ==
    /\ n \in Nodes
    /\ l \in LeaseOrNone
    /\ d \in DomainOrNone
    /\ e \in Epochs
    /\ eps \in EndpointSets
    /\ localShadow' = [localShadow EXCEPT ![n] =
        [valid |-> TRUE,
         lease |-> l,
         domain |-> d,
         epoch |-> e,
         endpoints |-> eps]]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, leaseMultiNode, localValid,
                    localEndpoints, activeLease, activeDomain, endpointUse>>

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
    /\ localEndpoints' = [localEndpoints EXCEPT ![n] =
        [localEndpoints[n] EXCEPT ![l] = eps]]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, leaseMultiNode, activeLease,
                    activeDomain, endpointUse, localShadow>>

ReleaseLocal(n, l) ==
    /\ n \in Nodes
    /\ l \in Leases
    /\ CtxLive(n, l)
    /\ activeLease[n] # l
    /\ endpointUse[n].lease # l
    /\ localValid' = [localValid EXCEPT ![n] =
        [localValid[n] EXCEPT ![l] = FALSE]]
    /\ localEndpoints' = [localEndpoints EXCEPT ![n] =
        [localEndpoints[n] EXCEPT ![l] = {}]]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, leaseMultiNode, activeLease,
                    activeDomain, endpointUse, localShadow>>

ActivateLocal(n, l) ==
    /\ n \in Nodes
    /\ l \in Leases
    /\ activeLease[n] = NoLease
    /\ CtxLive(n, l)
    /\ IF leaseMultiNode[l] THEN TRUE ELSE ActiveNodesForLease(l) = {}
    /\ activeLease' = [activeLease EXCEPT ![n] = l]
    /\ activeDomain' = [activeDomain EXCEPT ![n] = leaseDomain[l]]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, leaseMultiNode, localValid,
                    localEndpoints, endpointUse, localShadow>>

StopNode(n) ==
    /\ n \in Nodes
    /\ activeLease[n] # NoLease
    /\ activeLease' = [activeLease EXCEPT ![n] = NoLease]
    /\ activeDomain' = [activeDomain EXCEPT ![n] = NoDomain]
    /\ endpointUse' = [endpointUse EXCEPT ![n] = UseNone]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, leaseMultiNode, localValid,
                    localEndpoints, localShadow>>

StartEndpointUse(n, e) ==
    /\ n \in Nodes
    /\ e \in Endpoints
    /\ activeLease[n] # NoLease
    /\ ~endpointUse[n].valid
    /\ LET l == activeLease[n] IN
        /\ CtxLive(n, l)
        /\ e \in localEndpoints[n][l]
        /\ endpointUse' = [endpointUse EXCEPT ![n] =
            [valid |-> TRUE,
             lease |-> l,
             domain |-> leaseDomain[l],
             epoch |-> leaseEpoch[l],
             endpoint |-> e]]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, leaseMultiNode, localValid,
                    localEndpoints, activeLease, activeDomain, localShadow>>

CompleteEndpointUse(n) ==
    /\ n \in Nodes
    /\ endpointUse[n].valid
    /\ endpointUse' = [endpointUse EXCEPT ![n] = UseNone]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, leaseMultiNode, localValid,
                    localEndpoints, activeLease, activeDomain, localShadow>>

RevokeLease(l) ==
    /\ l \in Leases
    /\ leaseValid[l]
    /\ leaseValid' = [leaseValid EXCEPT ![l] = FALSE]
    /\ localValid' = [n \in Nodes |->
        [x \in Leases |-> IF x = l THEN FALSE ELSE localValid[n][x]]]
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
                    leaseEndpoints, leaseMultiNode, localShadow>>

RevokeDomain(d) ==
    /\ d \in Domains
    /\ clusterEpoch[d] < MaxEpoch
    /\ clusterEpoch' = [clusterEpoch EXCEPT ![d] = @ + 1]
    /\ leaseValid' = [l \in Leases |->
        IF LeaseUsesDomain(l, d) THEN FALSE ELSE leaseValid[l]]
    /\ localValid' = [n \in Nodes |->
        [l \in Leases |->
            IF LeaseUsesDomain(l, d) THEN FALSE ELSE localValid[n][l]]]
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
                    leaseMultiNode, localShadow>>

Next ==
    \/ \E l \in Leases, d \in Domains, nodes \in NonEmptyNodeSets,
          eps \in NonEmptyEndpointSets, multi \in BOOLEAN:
        IssueLease(l, d, nodes, eps, multi)
    \/ \E n \in Nodes, l \in LeaseOrNone, d \in DomainOrNone,
          e \in Epochs, eps \in EndpointSets:
        ForgeLocalShadow(n, l, d, e, eps)
    \/ \E n \in Nodes, l \in Leases, eps \in NonEmptyEndpointSets:
        CompileLocal(n, l, eps)
    \/ \E n \in Nodes, l \in Leases:
        ReleaseLocal(n, l)
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

NoLocalEndpointContextWithoutValidLease ==
    \A n \in Nodes:
        \A l \in Leases:
            localValid[n][l] => CtxLive(n, l)

NoActiveWithoutLocalEndpointContext ==
    \A n \in Nodes:
        activeLease[n] # NoLease =>
            /\ CtxLive(n, activeLease[n])
            /\ activeDomain[n] = leaseDomain[activeLease[n]]

NoEndpointUseWithoutCompiledEndpointCap ==
    \A n \in Nodes:
        endpointUse[n].valid =>
            /\ activeLease[n] = endpointUse[n].lease
            /\ CtxLive(n, activeLease[n])
            /\ endpointUse[n].endpoint \in localEndpoints[n][activeLease[n]]
            /\ endpointUse[n].domain = activeDomain[n]
            /\ endpointUse[n].epoch = leaseEpoch[activeLease[n]]

NoEndpointUseOutsideLease ==
    \A n \in Nodes:
        endpointUse[n].valid =>
            endpointUse[n].endpoint \in leaseEndpoints[endpointUse[n].lease]

NoActiveWithStaleClusterEpoch ==
    \A n \in Nodes:
        activeLease[n] # NoLease =>
            leaseEpoch[activeLease[n]] = clusterEpoch[activeDomain[n]]

NoActiveOutsideLeaseNodeSet ==
    \A n \in Nodes:
        activeLease[n] # NoLease =>
            n \in leaseNodes[activeLease[n]]

NoShadowClaimConfersAuthority ==
    \A n \in Nodes:
        localShadow[n].valid /\ activeLease[n] = NoLease =>
            /\ activeDomain[n] = NoDomain
            /\ ~endpointUse[n].valid

NoSingleNodeLeaseActiveOnTwoNodes ==
    \A l \in Leases:
        leaseValid[l] /\ ~leaseMultiNode[l] =>
            Cardinality(ActiveNodesForLease(l)) <= 1

=============================================================================
