-------------------------- MODULE ClusterLease --------------------------
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
    MaxEpoch,
    MaxLeaseBudget

VARIABLES
    clusterEpoch,
    leaseValid,
    leaseDomain,
    leaseEpoch,
    leaseNodes,
    leaseEndpoints,
    leaseTotal,
    leaseRemaining,
    leaseMultiNode,
    localCtx,
    activeLease,
    activeDomain,
    endpointUse,
    localShadow,
    spent,
    forfeited

vars == <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch, leaseNodes,
          leaseEndpoints, leaseTotal, leaseRemaining, leaseMultiNode,
          localCtx, activeLease, activeDomain, endpointUse, localShadow,
          spent, forfeited>>

Domains == {D1, D2}
Nodes == {N1, N2}
Leases == {L1, L2}
Endpoints == {E1, E2}

DomainOrNone == Domains \cup {NoDomain}
NodeOrNone == Nodes \cup {NoNode}
LeaseOrNone == Leases \cup {NoLease}
EndpointOrNone == Endpoints \cup {NoEndpoint}

Epochs == 0..MaxEpoch
Budgets == 0..MaxLeaseBudget
LeaseAmounts == 1..MaxLeaseBudget
NodeSets == SUBSET Nodes
NonEmptyNodeSets == NodeSets \ {{}}
EndpointSets == SUBSET Endpoints
NonEmptyEndpointSets == EndpointSets \ {{}}

CtxRecord == [
    valid: BOOLEAN,
    lease: LeaseOrNone,
    domain: DomainOrNone,
    epoch: Epochs,
    node: NodeOrNone,
    budget: Budgets,
    endpoints: EndpointSets
]

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
    budget: Budgets,
    endpoints: EndpointSets
]

CtxNone == [
    valid |-> FALSE,
    lease |-> NoLease,
    domain |-> NoDomain,
    epoch |-> 0,
    node |-> NoNode,
    budget |-> 0,
    endpoints |-> {}
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
    budget |-> 0,
    endpoints |-> {}
]

LocalBudget(l) ==
    (IF localCtx[N1][l].valid THEN localCtx[N1][l].budget ELSE 0) +
    (IF localCtx[N2][l].valid THEN localCtx[N2][l].budget ELSE 0)

LeaseUsesDomain(l, d) ==
    /\ l \in Leases
    /\ d \in Domains
    /\ leaseValid[l]
    /\ leaseDomain[l] = d

CtxLive(n, l) ==
    /\ n \in Nodes
    /\ l \in Leases
    /\ localCtx[n][l].valid
    /\ leaseValid[l]
    /\ localCtx[n][l].lease = l
    /\ localCtx[n][l].domain = leaseDomain[l]
    /\ localCtx[n][l].epoch = leaseEpoch[l]
    /\ localCtx[n][l].epoch = clusterEpoch[leaseDomain[l]]
    /\ localCtx[n][l].node = n
    /\ n \in leaseNodes[l]
    /\ localCtx[n][l].endpoints \subseteq leaseEndpoints[l]

ActiveCtx(n) ==
    /\ n \in Nodes
    /\ activeLease[n] \in Leases
    /\ CtxLive(n, activeLease[n])

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
    /\ MaxLeaseBudget \in Nat
    /\ MaxLeaseBudget > 0
    /\ clusterEpoch \in [Domains -> Epochs]
    /\ leaseValid \in [Leases -> BOOLEAN]
    /\ leaseDomain \in [Leases -> DomainOrNone]
    /\ leaseEpoch \in [Leases -> Epochs]
    /\ leaseNodes \in [Leases -> NodeSets]
    /\ leaseEndpoints \in [Leases -> EndpointSets]
    /\ leaseTotal \in [Leases -> Budgets]
    /\ leaseRemaining \in [Leases -> Budgets]
    /\ leaseMultiNode \in [Leases -> BOOLEAN]
    /\ localCtx \in [Nodes -> [Leases -> CtxRecord]]
    /\ activeLease \in [Nodes -> LeaseOrNone]
    /\ activeDomain \in [Nodes -> DomainOrNone]
    /\ endpointUse \in [Nodes -> UseRecord]
    /\ localShadow \in [Nodes -> ShadowRecord]
    /\ spent \in [Leases -> Budgets]
    /\ forfeited \in [Leases -> Budgets]

Init ==
    /\ clusterEpoch = [d \in Domains |-> 0]
    /\ leaseValid = [l \in Leases |-> FALSE]
    /\ leaseDomain = [l \in Leases |-> NoDomain]
    /\ leaseEpoch = [l \in Leases |-> 0]
    /\ leaseNodes = [l \in Leases |-> {}]
    /\ leaseEndpoints = [l \in Leases |-> {}]
    /\ leaseTotal = [l \in Leases |-> 0]
    /\ leaseRemaining = [l \in Leases |-> 0]
    /\ leaseMultiNode = [l \in Leases |-> FALSE]
    /\ localCtx = [n \in Nodes |-> [l \in Leases |-> CtxNone]]
    /\ activeLease = [n \in Nodes |-> NoLease]
    /\ activeDomain = [n \in Nodes |-> NoDomain]
    /\ endpointUse = [n \in Nodes |-> UseNone]
    /\ localShadow = [n \in Nodes |-> ShadowNone]
    /\ spent = [l \in Leases |-> 0]
    /\ forfeited = [l \in Leases |-> 0]

IssueLease(l, d, nodes, eps, amount, multi) ==
    /\ l \in Leases
    /\ d \in Domains
    /\ nodes \in NonEmptyNodeSets
    /\ eps \in NonEmptyEndpointSets
    /\ amount \in LeaseAmounts
    /\ multi \in BOOLEAN
    /\ ~leaseValid[l]
    /\ leaseTotal[l] = 0
    /\ leaseValid' = [leaseValid EXCEPT ![l] = TRUE]
    /\ leaseDomain' = [leaseDomain EXCEPT ![l] = d]
    /\ leaseEpoch' = [leaseEpoch EXCEPT ![l] = clusterEpoch[d]]
    /\ leaseNodes' = [leaseNodes EXCEPT ![l] = nodes]
    /\ leaseEndpoints' = [leaseEndpoints EXCEPT ![l] = eps]
    /\ leaseTotal' = [leaseTotal EXCEPT ![l] = amount]
    /\ leaseRemaining' = [leaseRemaining EXCEPT ![l] = amount]
    /\ leaseMultiNode' = [leaseMultiNode EXCEPT ![l] = multi]
    /\ spent' = [spent EXCEPT ![l] = 0]
    /\ forfeited' = [forfeited EXCEPT ![l] = 0]
    /\ UNCHANGED <<clusterEpoch, localCtx, activeLease, activeDomain,
                    endpointUse, localShadow>>

ForgeLocalShadow(n, l, d, e, amount, eps) ==
    /\ n \in Nodes
    /\ l \in LeaseOrNone
    /\ d \in DomainOrNone
    /\ e \in Epochs
    /\ amount \in Budgets
    /\ eps \in EndpointSets
    /\ localShadow' = [localShadow EXCEPT ![n] =
        [valid |-> TRUE,
         lease |-> l,
         domain |-> d,
         epoch |-> e,
         budget |-> amount,
         endpoints |-> eps]]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, leaseTotal, leaseRemaining,
                    leaseMultiNode, localCtx, activeLease, activeDomain,
                    endpointUse, spent, forfeited>>

CompileLocal(n, l, amount, eps) ==
    /\ n \in Nodes
    /\ l \in Leases
    /\ amount \in LeaseAmounts
    /\ eps \in NonEmptyEndpointSets
    /\ leaseValid[l]
    /\ leaseEpoch[l] = clusterEpoch[leaseDomain[l]]
    /\ n \in leaseNodes[l]
    /\ amount <= leaseRemaining[l]
    /\ eps \subseteq leaseEndpoints[l]
    /\ ~localCtx[n][l].valid
    /\ localCtx' = [localCtx EXCEPT ![n] =
        [localCtx[n] EXCEPT ![l] =
            [valid |-> TRUE,
             lease |-> l,
             domain |-> leaseDomain[l],
             epoch |-> leaseEpoch[l],
             node |-> n,
             budget |-> amount,
             endpoints |-> eps]]]
    /\ leaseRemaining' = [leaseRemaining EXCEPT ![l] = @ - amount]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, leaseTotal, leaseMultiNode,
                    activeLease, activeDomain, endpointUse, localShadow,
                    spent, forfeited>>

ReleaseLocal(n, l) ==
    /\ n \in Nodes
    /\ l \in Leases
    /\ CtxLive(n, l)
    /\ activeLease[n] # l
    /\ endpointUse[n].lease # l
    /\ leaseRemaining' = [leaseRemaining EXCEPT ![l] = @ + localCtx[n][l].budget]
    /\ localCtx' = [localCtx EXCEPT ![n] =
        [localCtx[n] EXCEPT ![l] = CtxNone]]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, leaseTotal, leaseMultiNode,
                    activeLease, activeDomain, endpointUse, localShadow,
                    spent, forfeited>>

ActivateLocal(n, l) ==
    /\ n \in Nodes
    /\ l \in Leases
    /\ activeLease[n] = NoLease
    /\ CtxLive(n, l)
    /\ localCtx[n][l].budget > 0
    /\ IF leaseMultiNode[l]
       THEN TRUE
       ELSE ActiveNodesForLease(l) = {}
    /\ activeLease' = [activeLease EXCEPT ![n] = l]
    /\ activeDomain' = [activeDomain EXCEPT ![n] = localCtx[n][l].domain]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, leaseTotal, leaseRemaining,
                    leaseMultiNode, localCtx, endpointUse, localShadow,
                    spent, forfeited>>

StopNode(n) ==
    /\ n \in Nodes
    /\ activeLease[n] # NoLease
    /\ activeLease' = [activeLease EXCEPT ![n] = NoLease]
    /\ activeDomain' = [activeDomain EXCEPT ![n] = NoDomain]
    /\ endpointUse' = [endpointUse EXCEPT ![n] = UseNone]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, leaseTotal, leaseRemaining,
                    leaseMultiNode, localCtx, localShadow, spent, forfeited>>

TickNode(n) ==
    /\ n \in Nodes
    /\ activeLease[n] # NoLease
    /\ LET l == activeLease[n] IN
       LET newBudget == localCtx[n][l].budget - 1 IN
        /\ CtxLive(n, l)
        /\ localCtx[n][l].budget > 0
        /\ localCtx' = [localCtx EXCEPT ![n] =
            [localCtx[n] EXCEPT ![l] =
                [localCtx[n][l] EXCEPT !.budget = newBudget]]]
        /\ spent' = [spent EXCEPT ![l] = @ + 1]
        /\ IF newBudget = 0
           THEN
            /\ activeLease' = [activeLease EXCEPT ![n] = NoLease]
            /\ activeDomain' = [activeDomain EXCEPT ![n] = NoDomain]
            /\ endpointUse' = [endpointUse EXCEPT ![n] = UseNone]
           ELSE
            /\ UNCHANGED <<activeLease, activeDomain, endpointUse>>
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, leaseTotal, leaseRemaining,
                    leaseMultiNode, localShadow, forfeited>>

StartEndpointUse(n, e) ==
    /\ n \in Nodes
    /\ e \in Endpoints
    /\ activeLease[n] # NoLease
    /\ endpointUse[n].valid = FALSE
    /\ LET l == activeLease[n] IN
        /\ CtxLive(n, l)
        /\ e \in localCtx[n][l].endpoints
        /\ endpointUse' = [endpointUse EXCEPT ![n] =
            [valid |-> TRUE,
             lease |-> l,
             domain |-> localCtx[n][l].domain,
             epoch |-> localCtx[n][l].epoch,
             endpoint |-> e]]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, leaseTotal, leaseRemaining,
                    leaseMultiNode, localCtx, activeLease, activeDomain,
                    localShadow, spent, forfeited>>

CompleteEndpointUse(n) ==
    /\ n \in Nodes
    /\ endpointUse[n].valid
    /\ endpointUse' = [endpointUse EXCEPT ![n] = UseNone]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseEndpoints, leaseTotal, leaseRemaining,
                    leaseMultiNode, localCtx, activeLease, activeDomain,
                    localShadow, spent, forfeited>>

RevokeLease(l) ==
    /\ l \in Leases
    /\ leaseValid[l]
    /\ leaseValid' = [leaseValid EXCEPT ![l] = FALSE]
    /\ leaseRemaining' = [leaseRemaining EXCEPT ![l] = 0]
    /\ forfeited' = [forfeited EXCEPT ![l] =
        @ + leaseRemaining[l] + LocalBudget(l)]
    /\ localCtx' = [n \in Nodes |->
        [x \in Leases |->
            IF x = l THEN CtxNone ELSE localCtx[n][x]]]
    /\ activeLease' = [n \in Nodes |->
        IF activeLease[n] = l THEN NoLease ELSE activeLease[n]]
    /\ activeDomain' = [n \in Nodes |->
        IF activeLease[n] = l THEN NoDomain ELSE activeDomain[n]]
    /\ endpointUse' = [n \in Nodes |->
        IF endpointUse[n].valid /\ endpointUse[n].lease = l
        THEN UseNone
        ELSE endpointUse[n]]
    /\ UNCHANGED <<clusterEpoch, leaseDomain, leaseEpoch, leaseNodes,
                    leaseEndpoints, leaseTotal, leaseMultiNode, localShadow,
                    spent>>

RevokeDomain(d) ==
    /\ d \in Domains
    /\ clusterEpoch[d] < MaxEpoch
    /\ clusterEpoch' = [clusterEpoch EXCEPT ![d] = @ + 1]
    /\ leaseValid' = [l \in Leases |->
        IF LeaseUsesDomain(l, d) THEN FALSE ELSE leaseValid[l]]
    /\ leaseRemaining' = [l \in Leases |->
        IF LeaseUsesDomain(l, d) THEN 0 ELSE leaseRemaining[l]]
    /\ forfeited' = [l \in Leases |->
        IF LeaseUsesDomain(l, d)
        THEN forfeited[l] + leaseRemaining[l] + LocalBudget(l)
        ELSE forfeited[l]]
    /\ localCtx' = [n \in Nodes |->
        [l \in Leases |->
            IF LeaseUsesDomain(l, d) THEN CtxNone ELSE localCtx[n][l]]]
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
                    leaseTotal, leaseMultiNode, localShadow, spent>>

Next ==
    \/ \E l \in Leases, d \in Domains, nodes \in NonEmptyNodeSets,
          eps \in NonEmptyEndpointSets, amount \in LeaseAmounts,
          multi \in BOOLEAN:
        IssueLease(l, d, nodes, eps, amount, multi)
    \/ \E n \in Nodes, l \in LeaseOrNone, d \in DomainOrNone,
          e \in Epochs, amount \in Budgets, eps \in EndpointSets:
        ForgeLocalShadow(n, l, d, e, amount, eps)
    \/ \E n \in Nodes, l \in Leases, amount \in LeaseAmounts,
          eps \in NonEmptyEndpointSets:
        CompileLocal(n, l, amount, eps)
    \/ \E n \in Nodes, l \in Leases:
        ReleaseLocal(n, l)
    \/ \E n \in Nodes, l \in Leases:
        ActivateLocal(n, l)
    \/ \E n \in Nodes:
        StopNode(n)
    \/ \E n \in Nodes:
        TickNode(n)
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
            localCtx[n][l].valid => CtxLive(n, l)

NoActiveWithoutCompiledContext ==
    \A n \in Nodes:
        activeLease[n] # NoLease =>
            /\ ActiveCtx(n)
            /\ activeDomain[n] = localCtx[n][activeLease[n]].domain

NoActiveWithStaleClusterEpoch ==
    \A n \in Nodes:
        activeLease[n] # NoLease =>
            LET l == activeLease[n] IN
                localCtx[n][l].epoch = clusterEpoch[localCtx[n][l].domain]

NoActiveOutsideLeaseNodeSet ==
    \A n \in Nodes:
        activeLease[n] # NoLease =>
            n \in leaseNodes[activeLease[n]]

NoActiveWithoutLocalBudget ==
    \A n \in Nodes:
        activeLease[n] # NoLease =>
            localCtx[n][activeLease[n]].budget > 0

NoEndpointUseWithoutCompiledEndpointCap ==
    \A n \in Nodes:
        endpointUse[n].valid =>
            /\ activeLease[n] = endpointUse[n].lease
            /\ ActiveCtx(n)
            /\ endpointUse[n].endpoint \in localCtx[n][activeLease[n]].endpoints
            /\ endpointUse[n].domain = activeDomain[n]
            /\ endpointUse[n].epoch = localCtx[n][activeLease[n]].epoch

NoEndpointUseOutsideLease ==
    \A n \in Nodes:
        endpointUse[n].valid =>
            endpointUse[n].endpoint \in leaseEndpoints[endpointUse[n].lease]

NoShadowClaimConfersAuthority ==
    \A n \in Nodes:
        localShadow[n].valid /\ activeLease[n] = NoLease =>
            /\ activeDomain[n] = NoDomain
            /\ ~endpointUse[n].valid

NoSingleNodeLeaseActiveOnTwoNodes ==
    \A l \in Leases:
        leaseValid[l] /\ ~leaseMultiNode[l] =>
            Cardinality(ActiveNodesForLease(l)) <= 1

NoLeaseBudgetOversubscription ==
    \A l \in Leases:
        leaseRemaining[l] + LocalBudget(l) + spent[l] + forfeited[l]
            = leaseTotal[l]

NoBudgetUnderflow ==
    /\ \A l \in Leases:
        /\ leaseRemaining[l] >= 0
        /\ leaseTotal[l] >= 0
        /\ spent[l] >= 0
        /\ forfeited[l] >= 0
    /\ \A n \in Nodes:
        \A l \in Leases:
            localCtx[n][l].budget >= 0

=============================================================================
