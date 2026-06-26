-------------------------- MODULE ClusterBudget --------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS
    D1, D2,
    N1, N2,
    L1, L2,
    NoDomain,
    NoNode,
    NoLease,
    MaxEpoch,
    MaxLeaseBudget

VARIABLES
    clusterEpoch,
    leaseValid,
    leaseDomain,
    leaseEpoch,
    leaseNodes,
    leaseTotal,
    leaseRemaining,
    leaseMultiNode,
    localValid,
    localBudget,
    activeLease,
    activeDomain,
    localShadow,
    spent,
    forfeited

vars == <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch, leaseNodes,
          leaseTotal, leaseRemaining, leaseMultiNode, localValid, localBudget,
          activeLease, activeDomain, localShadow, spent, forfeited>>

Domains == {D1, D2}
Nodes == {N1, N2}
Leases == {L1, L2}

DomainOrNone == Domains \cup {NoDomain}
LeaseOrNone == Leases \cup {NoLease}

Epochs == 0..MaxEpoch
Budgets == 0..MaxLeaseBudget
LeaseAmounts == 1..MaxLeaseBudget
NodeSets == SUBSET Nodes
NonEmptyNodeSets == NodeSets \ {{}}

ShadowRecord == [
    valid: BOOLEAN,
    lease: LeaseOrNone,
    domain: DomainOrNone,
    epoch: Epochs,
    budget: Budgets
]

ShadowNone == [
    valid |-> FALSE,
    lease |-> NoLease,
    domain |-> NoDomain,
    epoch |-> 0,
    budget |-> 0
]

LocalBudgetSum(l) ==
    (IF localValid[N1][l] THEN localBudget[N1][l] ELSE 0) +
    (IF localValid[N2][l] THEN localBudget[N2][l] ELSE 0)

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

ActiveNodesForLease(l) ==
    {n \in Nodes : activeLease[n] = l}

TypeOK ==
    /\ D1 # D2
    /\ N1 # N2
    /\ L1 # L2
    /\ NoDomain \notin Domains
    /\ NoNode \notin Nodes
    /\ NoLease \notin Leases
    /\ MaxEpoch \in Nat
    /\ MaxLeaseBudget \in Nat
    /\ MaxLeaseBudget > 0
    /\ clusterEpoch \in [Domains -> Epochs]
    /\ leaseValid \in [Leases -> BOOLEAN]
    /\ leaseDomain \in [Leases -> DomainOrNone]
    /\ leaseEpoch \in [Leases -> Epochs]
    /\ leaseNodes \in [Leases -> NodeSets]
    /\ leaseTotal \in [Leases -> Budgets]
    /\ leaseRemaining \in [Leases -> Budgets]
    /\ leaseMultiNode \in [Leases -> BOOLEAN]
    /\ localValid \in [Nodes -> [Leases -> BOOLEAN]]
    /\ localBudget \in [Nodes -> [Leases -> Budgets]]
    /\ activeLease \in [Nodes -> LeaseOrNone]
    /\ activeDomain \in [Nodes -> DomainOrNone]
    /\ localShadow \in [Nodes -> ShadowRecord]
    /\ spent \in [Leases -> Budgets]
    /\ forfeited \in [Leases -> Budgets]

Init ==
    /\ clusterEpoch = [d \in Domains |-> 0]
    /\ leaseValid = [l \in Leases |-> FALSE]
    /\ leaseDomain = [l \in Leases |-> NoDomain]
    /\ leaseEpoch = [l \in Leases |-> 0]
    /\ leaseNodes = [l \in Leases |-> {}]
    /\ leaseTotal = [l \in Leases |-> 0]
    /\ leaseRemaining = [l \in Leases |-> 0]
    /\ leaseMultiNode = [l \in Leases |-> FALSE]
    /\ localValid = [n \in Nodes |-> [l \in Leases |-> FALSE]]
    /\ localBudget = [n \in Nodes |-> [l \in Leases |-> 0]]
    /\ activeLease = [n \in Nodes |-> NoLease]
    /\ activeDomain = [n \in Nodes |-> NoDomain]
    /\ localShadow = [n \in Nodes |-> ShadowNone]
    /\ spent = [l \in Leases |-> 0]
    /\ forfeited = [l \in Leases |-> 0]

IssueLease(l, d, nodes, amount, multi) ==
    /\ l \in Leases
    /\ d \in Domains
    /\ nodes \in NonEmptyNodeSets
    /\ amount \in LeaseAmounts
    /\ multi \in BOOLEAN
    /\ ~leaseValid[l]
    /\ leaseTotal[l] = 0
    /\ leaseValid' = [leaseValid EXCEPT ![l] = TRUE]
    /\ leaseDomain' = [leaseDomain EXCEPT ![l] = d]
    /\ leaseEpoch' = [leaseEpoch EXCEPT ![l] = clusterEpoch[d]]
    /\ leaseNodes' = [leaseNodes EXCEPT ![l] = nodes]
    /\ leaseTotal' = [leaseTotal EXCEPT ![l] = amount]
    /\ leaseRemaining' = [leaseRemaining EXCEPT ![l] = amount]
    /\ leaseMultiNode' = [leaseMultiNode EXCEPT ![l] = multi]
    /\ spent' = [spent EXCEPT ![l] = 0]
    /\ forfeited' = [forfeited EXCEPT ![l] = 0]
    /\ UNCHANGED <<clusterEpoch, localValid, localBudget, activeLease,
                    activeDomain, localShadow>>

ForgeLocalShadow(n, l, d, e, amount) ==
    /\ n \in Nodes
    /\ l \in LeaseOrNone
    /\ d \in DomainOrNone
    /\ e \in Epochs
    /\ amount \in Budgets
    /\ localShadow' = [localShadow EXCEPT ![n] =
        [valid |-> TRUE,
         lease |-> l,
         domain |-> d,
         epoch |-> e,
         budget |-> amount]]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseTotal, leaseRemaining, leaseMultiNode,
                    localValid, localBudget, activeLease, activeDomain,
                    spent, forfeited>>

CompileLocal(n, l, amount) ==
    /\ n \in Nodes
    /\ l \in Leases
    /\ amount \in LeaseAmounts
    /\ leaseValid[l]
    /\ leaseEpoch[l] = clusterEpoch[leaseDomain[l]]
    /\ n \in leaseNodes[l]
    /\ amount <= leaseRemaining[l]
    /\ ~localValid[n][l]
    /\ localValid' = [localValid EXCEPT ![n] =
        [localValid[n] EXCEPT ![l] = TRUE]]
    /\ localBudget' = [localBudget EXCEPT ![n] =
        [localBudget[n] EXCEPT ![l] = amount]]
    /\ leaseRemaining' = [leaseRemaining EXCEPT ![l] = @ - amount]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseTotal, leaseMultiNode, activeLease,
                    activeDomain, localShadow, spent, forfeited>>

ReleaseLocal(n, l) ==
    /\ n \in Nodes
    /\ l \in Leases
    /\ CtxLive(n, l)
    /\ activeLease[n] # l
    /\ leaseRemaining' = [leaseRemaining EXCEPT ![l] = @ + localBudget[n][l]]
    /\ localValid' = [localValid EXCEPT ![n] =
        [localValid[n] EXCEPT ![l] = FALSE]]
    /\ localBudget' = [localBudget EXCEPT ![n] =
        [localBudget[n] EXCEPT ![l] = 0]]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseTotal, leaseMultiNode, activeLease,
                    activeDomain, localShadow, spent, forfeited>>

ActivateLocal(n, l) ==
    /\ n \in Nodes
    /\ l \in Leases
    /\ activeLease[n] = NoLease
    /\ CtxLive(n, l)
    /\ localBudget[n][l] > 0
    /\ IF leaseMultiNode[l] THEN TRUE ELSE ActiveNodesForLease(l) = {}
    /\ activeLease' = [activeLease EXCEPT ![n] = l]
    /\ activeDomain' = [activeDomain EXCEPT ![n] = leaseDomain[l]]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseTotal, leaseRemaining, leaseMultiNode,
                    localValid, localBudget, localShadow, spent, forfeited>>

StopNode(n) ==
    /\ n \in Nodes
    /\ activeLease[n] # NoLease
    /\ activeLease' = [activeLease EXCEPT ![n] = NoLease]
    /\ activeDomain' = [activeDomain EXCEPT ![n] = NoDomain]
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseTotal, leaseRemaining, leaseMultiNode,
                    localValid, localBudget, localShadow, spent, forfeited>>

TickNode(n) ==
    /\ n \in Nodes
    /\ activeLease[n] # NoLease
    /\ LET l == activeLease[n] IN
       LET newBudget == localBudget[n][l] - 1 IN
        /\ CtxLive(n, l)
        /\ localBudget[n][l] > 0
        /\ localBudget' = [localBudget EXCEPT ![n] =
            [localBudget[n] EXCEPT ![l] = newBudget]]
        /\ spent' = [spent EXCEPT ![l] = @ + 1]
        /\ IF newBudget = 0
           THEN
            /\ activeLease' = [activeLease EXCEPT ![n] = NoLease]
            /\ activeDomain' = [activeDomain EXCEPT ![n] = NoDomain]
           ELSE
            /\ UNCHANGED <<activeLease, activeDomain>>
    /\ UNCHANGED <<clusterEpoch, leaseValid, leaseDomain, leaseEpoch,
                    leaseNodes, leaseTotal, leaseRemaining, leaseMultiNode,
                    localValid, localShadow, forfeited>>

RevokeLease(l) ==
    /\ l \in Leases
    /\ leaseValid[l]
    /\ leaseValid' = [leaseValid EXCEPT ![l] = FALSE]
    /\ leaseRemaining' = [leaseRemaining EXCEPT ![l] = 0]
    /\ forfeited' = [forfeited EXCEPT ![l] =
        @ + leaseRemaining[l] + LocalBudgetSum(l)]
    /\ localValid' = [n \in Nodes |->
        [x \in Leases |-> IF x = l THEN FALSE ELSE localValid[n][x]]]
    /\ localBudget' = [n \in Nodes |->
        [x \in Leases |-> IF x = l THEN 0 ELSE localBudget[n][x]]]
    /\ activeLease' = [n \in Nodes |->
        IF activeLease[n] = l THEN NoLease ELSE activeLease[n]]
    /\ activeDomain' = [n \in Nodes |->
        IF activeLease[n] = l THEN NoDomain ELSE activeDomain[n]]
    /\ UNCHANGED <<clusterEpoch, leaseDomain, leaseEpoch, leaseNodes,
                    leaseTotal, leaseMultiNode, localShadow, spent>>

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
        THEN forfeited[l] + leaseRemaining[l] + LocalBudgetSum(l)
        ELSE forfeited[l]]
    /\ localValid' = [n \in Nodes |->
        [l \in Leases |->
            IF LeaseUsesDomain(l, d) THEN FALSE ELSE localValid[n][l]]]
    /\ localBudget' = [n \in Nodes |->
        [l \in Leases |->
            IF LeaseUsesDomain(l, d) THEN 0 ELSE localBudget[n][l]]]
    /\ activeLease' = [n \in Nodes |->
        IF activeLease[n] # NoLease /\ LeaseUsesDomain(activeLease[n], d)
        THEN NoLease
        ELSE activeLease[n]]
    /\ activeDomain' = [n \in Nodes |->
        IF activeDomain[n] = d THEN NoDomain ELSE activeDomain[n]]
    /\ UNCHANGED <<leaseDomain, leaseEpoch, leaseNodes, leaseTotal,
                    leaseMultiNode, localShadow, spent>>

Next ==
    \/ \E l \in Leases, d \in Domains, nodes \in NonEmptyNodeSets,
          amount \in LeaseAmounts, multi \in BOOLEAN:
        IssueLease(l, d, nodes, amount, multi)
    \/ \E n \in Nodes, l \in LeaseOrNone, d \in DomainOrNone,
          e \in Epochs, amount \in Budgets:
        ForgeLocalShadow(n, l, d, e, amount)
    \/ \E n \in Nodes, l \in Leases, amount \in LeaseAmounts:
        CompileLocal(n, l, amount)
    \/ \E n \in Nodes, l \in Leases:
        ReleaseLocal(n, l)
    \/ \E n \in Nodes, l \in Leases:
        ActivateLocal(n, l)
    \/ \E n \in Nodes:
        StopNode(n)
    \/ \E n \in Nodes:
        TickNode(n)
    \/ \E l \in Leases:
        RevokeLease(l)
    \/ \E d \in Domains:
        RevokeDomain(d)

Spec == Init /\ [][Next]_vars

NoLocalBudgetWithoutValidLease ==
    \A n \in Nodes:
        \A l \in Leases:
            localValid[n][l] => CtxLive(n, l)

NoActiveWithoutLocalBudgetContext ==
    \A n \in Nodes:
        activeLease[n] # NoLease =>
            /\ CtxLive(n, activeLease[n])
            /\ activeDomain[n] = leaseDomain[activeLease[n]]
            /\ localBudget[n][activeLease[n]] > 0

NoActiveWithStaleClusterEpoch ==
    \A n \in Nodes:
        activeLease[n] # NoLease =>
            leaseEpoch[activeLease[n]] = clusterEpoch[activeDomain[n]]

NoActiveOutsideLeaseNodeSet ==
    \A n \in Nodes:
        activeLease[n] # NoLease =>
            n \in leaseNodes[activeLease[n]]

NoSingleNodeLeaseActiveOnTwoNodes ==
    \A l \in Leases:
        leaseValid[l] /\ ~leaseMultiNode[l] =>
            Cardinality(ActiveNodesForLease(l)) <= 1

NoShadowClaimConfersAuthority ==
    \A n \in Nodes:
        localShadow[n].valid /\ activeLease[n] = NoLease =>
            activeDomain[n] = NoDomain

LeaseBudgetConserved ==
    \A l \in Leases:
        leaseRemaining[l] + LocalBudgetSum(l) + spent[l] + forfeited[l]
            = leaseTotal[l]

NoBudgetUnderflow ==
    /\ \A l \in Leases:
        /\ leaseRemaining[l] >= 0
        /\ leaseTotal[l] >= 0
        /\ spent[l] >= 0
        /\ forfeited[l] >= 0
    /\ \A n \in Nodes:
        \A l \in Leases:
            localBudget[n][l] >= 0

=============================================================================
