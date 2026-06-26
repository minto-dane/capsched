----------------------------- MODULE QueueLease -----------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS
    D1, D2,
    Q1, Q2,
    B1, B2,
    I1, I2,
    NoDomain,
    NoBuffer,
    NoIrq,
    MaxEpoch,
    MaxBudget

VARIABLES
    domainEpoch,
    bufferState,
    bufferOwner,
    bufferEpoch,
    queueState,
    queueOwner,
    queueEpoch,
    queueBudget,
    queueIrq,
    irqTarget,
    irqEpoch,
    irqPending,
    iommuMap,
    submitted,
    dmaAccess,
    linuxShadowQueueOwner,
    linuxShadowIommu

vars == <<domainEpoch, bufferState, bufferOwner, bufferEpoch, queueState,
          queueOwner, queueEpoch, queueBudget, queueIrq, irqTarget, irqEpoch,
          irqPending, iommuMap, submitted, dmaAccess, linuxShadowQueueOwner,
          linuxShadowIommu>>

Domains == {D1, D2}
Queues == {Q1, Q2}
Buffers == {B1, B2}
Irqs == {I1, I2}

DomainOrNone == Domains \cup {NoDomain}
BufferOrNone == Buffers \cup {NoBuffer}
IrqOrNone == Irqs \cup {NoIrq}
Epochs == 0..MaxEpoch
Budgets == 0..MaxBudget

BufferStates == {"free", "owned", "revoking"}
QueueStates == {"free", "leased", "revoking"}

MappedQueuesForBuffer(b) ==
    {q \in Queues : b \in iommuMap[q]}

DmaQueuesForBuffer(b) ==
    {q \in Queues : dmaAccess[q] = b}

QueuesUsingIrq(i) ==
    {q \in Queues : queueIrq[q] = i /\ queueState[q] = "leased"}

QueuesReferencingIrq(i) ==
    {q \in Queues : queueIrq[q] = i /\ queueState[q] # "free"}

NoIommuOrDma(b) ==
    /\ MappedQueuesForBuffer(b) = {}
    /\ DmaQueuesForBuffer(b) = {}

BufferLiveForDomain(b, d) ==
    IF b \in Buffers /\ d \in Domains
    THEN
        /\ bufferState[b] = "owned"
        /\ bufferOwner[b] = d
        /\ bufferEpoch[b] = domainEpoch[d]
    ELSE FALSE

QueueLiveForDomain(q, d) ==
    IF q \in Queues /\ d \in Domains
    THEN
        /\ queueState[q] = "leased"
        /\ queueOwner[q] = d
        /\ queueEpoch[q] = domainEpoch[d]
        /\ queueIrq[q] \in Irqs
        /\ irqTarget[queueIrq[q]] = d
        /\ irqEpoch[queueIrq[q]] = domainEpoch[d]
    ELSE FALSE

QueueLive(q) ==
    IF q \in Queues /\ queueOwner[q] \in Domains
    THEN QueueLiveForDomain(q, queueOwner[q])
    ELSE FALSE

IommuMapLive(q, b) ==
    /\ q \in Queues
    /\ b \in Buffers
    /\ QueueLive(q)
    /\ b \in iommuMap[q]
    /\ BufferLiveForDomain(b, queueOwner[q])

TypeOK ==
    /\ D1 # D2
    /\ Q1 # Q2
    /\ B1 # B2
    /\ I1 # I2
    /\ NoDomain \notin Domains
    /\ NoBuffer \notin Buffers
    /\ NoIrq \notin Irqs
    /\ MaxEpoch \in Nat
    /\ MaxBudget \in Nat
    /\ MaxEpoch > 0
    /\ MaxBudget > 0
    /\ domainEpoch \in [Domains -> Epochs]
    /\ bufferState \in [Buffers -> BufferStates]
    /\ bufferOwner \in [Buffers -> DomainOrNone]
    /\ bufferEpoch \in [Buffers -> Epochs]
    /\ queueState \in [Queues -> QueueStates]
    /\ queueOwner \in [Queues -> DomainOrNone]
    /\ queueEpoch \in [Queues -> Epochs]
    /\ queueBudget \in [Queues -> Budgets]
    /\ queueIrq \in [Queues -> IrqOrNone]
    /\ irqTarget \in [Irqs -> DomainOrNone]
    /\ irqEpoch \in [Irqs -> Epochs]
    /\ irqPending \in [Irqs -> DomainOrNone]
    /\ iommuMap \in [Queues -> SUBSET Buffers]
    /\ submitted \in [Queues -> BOOLEAN]
    /\ dmaAccess \in [Queues -> BufferOrNone]
    /\ linuxShadowQueueOwner \in [Queues -> DomainOrNone]
    /\ linuxShadowIommu \in [Queues -> SUBSET Buffers]

Init ==
    /\ domainEpoch = [d \in Domains |-> 0]
    /\ bufferState = [b \in Buffers |-> "free"]
    /\ bufferOwner = [b \in Buffers |-> NoDomain]
    /\ bufferEpoch = [b \in Buffers |-> 0]
    /\ queueState = [q \in Queues |-> "free"]
    /\ queueOwner = [q \in Queues |-> NoDomain]
    /\ queueEpoch = [q \in Queues |-> 0]
    /\ queueBudget = [q \in Queues |-> 0]
    /\ queueIrq = [q \in Queues |-> NoIrq]
    /\ irqTarget = [i \in Irqs |-> NoDomain]
    /\ irqEpoch = [i \in Irqs |-> 0]
    /\ irqPending = [i \in Irqs |-> NoDomain]
    /\ iommuMap = [q \in Queues |-> {}]
    /\ submitted = [q \in Queues |-> FALSE]
    /\ dmaAccess = [q \in Queues |-> NoBuffer]
    /\ linuxShadowQueueOwner = [q \in Queues |-> NoDomain]
    /\ linuxShadowIommu = [q \in Queues |-> {}]

ForgeLinuxQueueOwner(q, d) ==
    /\ q \in Queues
    /\ d \in Domains
    /\ linuxShadowQueueOwner' = [linuxShadowQueueOwner EXCEPT ![q] = d]
    /\ UNCHANGED <<domainEpoch, bufferState, bufferOwner, bufferEpoch,
                    queueState, queueOwner, queueEpoch, queueBudget, queueIrq,
                    irqTarget, irqEpoch, irqPending, iommuMap, submitted,
                    dmaAccess, linuxShadowIommu>>

ForgeLinuxIommu(q, b) ==
    /\ q \in Queues
    /\ b \in Buffers
    /\ linuxShadowIommu' = [linuxShadowIommu EXCEPT ![q] = @ \cup {b}]
    /\ UNCHANGED <<domainEpoch, bufferState, bufferOwner, bufferEpoch,
                    queueState, queueOwner, queueEpoch, queueBudget, queueIrq,
                    irqTarget, irqEpoch, irqPending, iommuMap, submitted,
                    dmaAccess, linuxShadowQueueOwner>>

AllocBuffer(b, d) ==
    /\ b \in Buffers
    /\ d \in Domains
    /\ bufferState[b] = "free"
    /\ NoIommuOrDma(b)
    /\ bufferState' = [bufferState EXCEPT ![b] = "owned"]
    /\ bufferOwner' = [bufferOwner EXCEPT ![b] = d]
    /\ bufferEpoch' = [bufferEpoch EXCEPT ![b] = domainEpoch[d]]
    /\ UNCHANGED <<domainEpoch, queueState, queueOwner, queueEpoch,
                    queueBudget, queueIrq, irqTarget, irqEpoch, irqPending,
                    iommuMap, submitted, dmaAccess, linuxShadowQueueOwner,
                    linuxShadowIommu>>

FinishBufferRevoke(b) ==
    /\ b \in Buffers
    /\ bufferState[b] = "revoking"
    /\ NoIommuOrDma(b)
    /\ bufferState' = [bufferState EXCEPT ![b] = "free"]
    /\ bufferOwner' = [bufferOwner EXCEPT ![b] = NoDomain]
    /\ bufferEpoch' = [bufferEpoch EXCEPT ![b] = 0]
    /\ UNCHANGED <<domainEpoch, queueState, queueOwner, queueEpoch,
                    queueBudget, queueIrq, irqTarget, irqEpoch, irqPending,
                    iommuMap, submitted, dmaAccess, linuxShadowQueueOwner,
                    linuxShadowIommu>>

LeaseQueue(q, d, i) ==
    /\ q \in Queues
    /\ d \in Domains
    /\ i \in Irqs
    /\ queueState[q] = "free"
    /\ queueIrq[q] = NoIrq
    /\ irqTarget[i] = NoDomain
    /\ QueuesReferencingIrq(i) = {}
    /\ queueState' = [queueState EXCEPT ![q] = "leased"]
    /\ queueOwner' = [queueOwner EXCEPT ![q] = d]
    /\ queueEpoch' = [queueEpoch EXCEPT ![q] = domainEpoch[d]]
    /\ queueBudget' = [queueBudget EXCEPT ![q] = MaxBudget]
    /\ queueIrq' = [queueIrq EXCEPT ![q] = i]
    /\ irqTarget' = [irqTarget EXCEPT ![i] = d]
    /\ irqEpoch' = [irqEpoch EXCEPT ![i] = domainEpoch[d]]
    /\ irqPending' = [irqPending EXCEPT ![i] = NoDomain]
    /\ UNCHANGED <<domainEpoch, bufferState, bufferOwner, bufferEpoch,
                    iommuMap, submitted, dmaAccess, linuxShadowQueueOwner,
                    linuxShadowIommu>>

MapQueueDma(q, b) ==
    /\ q \in Queues
    /\ b \in Buffers
    /\ QueueLive(q)
    /\ BufferLiveForDomain(b, queueOwner[q])
    /\ iommuMap' = [iommuMap EXCEPT ![q] = @ \cup {b}]
    /\ UNCHANGED <<domainEpoch, bufferState, bufferOwner, bufferEpoch,
                    queueState, queueOwner, queueEpoch, queueBudget, queueIrq,
                    irqTarget, irqEpoch, irqPending, submitted, dmaAccess,
                    linuxShadowQueueOwner, linuxShadowIommu>>

RingDoorbell(q) ==
    /\ q \in Queues
    /\ QueueLive(q)
    /\ queueBudget[q] > 0
    /\ ~submitted[q]
    /\ submitted' = [submitted EXCEPT ![q] = TRUE]
    /\ queueBudget' = [queueBudget EXCEPT ![q] = @ - 1]
    /\ UNCHANGED <<domainEpoch, bufferState, bufferOwner, bufferEpoch,
                    queueState, queueOwner, queueEpoch, queueIrq, irqTarget,
                    irqEpoch, irqPending, iommuMap, dmaAccess,
                    linuxShadowQueueOwner, linuxShadowIommu>>

DeviceDma(q, b) ==
    /\ q \in Queues
    /\ b \in Buffers
    /\ submitted[q]
    /\ IommuMapLive(q, b)
    /\ dmaAccess' = [dmaAccess EXCEPT ![q] = b]
    /\ UNCHANGED <<domainEpoch, bufferState, bufferOwner, bufferEpoch,
                    queueState, queueOwner, queueEpoch, queueBudget, queueIrq,
                    irqTarget, irqEpoch, irqPending, iommuMap, submitted,
                    linuxShadowQueueOwner, linuxShadowIommu>>

CompleteDma(q) ==
    /\ q \in Queues
    /\ dmaAccess[q] # NoBuffer
    /\ dmaAccess' = [dmaAccess EXCEPT ![q] = NoBuffer]
    /\ UNCHANGED <<domainEpoch, bufferState, bufferOwner, bufferEpoch,
                    queueState, queueOwner, queueEpoch, queueBudget, queueIrq,
                    irqTarget, irqEpoch, irqPending, iommuMap, submitted,
                    linuxShadowQueueOwner, linuxShadowIommu>>

DeliverIrq(q) ==
    /\ q \in Queues
    /\ QueueLive(q)
    /\ submitted[q]
    /\ LET i == queueIrq[q] IN
        /\ i \in Irqs
        /\ irqTarget[i] = queueOwner[q]
        /\ irqEpoch[i] = queueEpoch[q]
        /\ irqPending' = [irqPending EXCEPT ![i] = queueOwner[q]]
    /\ submitted' = [submitted EXCEPT ![q] = FALSE]
    /\ dmaAccess' = [dmaAccess EXCEPT ![q] = NoBuffer]
    /\ UNCHANGED <<domainEpoch, bufferState, bufferOwner, bufferEpoch,
                    queueState, queueOwner, queueEpoch, queueBudget, queueIrq,
                    irqTarget, irqEpoch, iommuMap, linuxShadowQueueOwner,
                    linuxShadowIommu>>

ClearIrq(i) ==
    /\ i \in Irqs
    /\ irqPending[i] # NoDomain
    /\ irqPending' = [irqPending EXCEPT ![i] = NoDomain]
    /\ UNCHANGED <<domainEpoch, bufferState, bufferOwner, bufferEpoch,
                    queueState, queueOwner, queueEpoch, queueBudget, queueIrq,
                    irqTarget, irqEpoch, iommuMap, submitted, dmaAccess,
                    linuxShadowQueueOwner, linuxShadowIommu>>

StartQueueRevoke(q) ==
    /\ q \in Queues
    /\ queueState[q] = "leased"
    /\ LET i == queueIrq[q] IN
        /\ queueState' = [queueState EXCEPT ![q] = "revoking"]
        /\ queueBudget' = [queueBudget EXCEPT ![q] = 0]
        /\ iommuMap' = [iommuMap EXCEPT ![q] = {}]
        /\ submitted' = [submitted EXCEPT ![q] = FALSE]
        /\ dmaAccess' = [dmaAccess EXCEPT ![q] = NoBuffer]
        /\ irqTarget' = [irqTarget EXCEPT ![i] = NoDomain]
        /\ irqEpoch' = [irqEpoch EXCEPT ![i] = 0]
        /\ irqPending' = [irqPending EXCEPT ![i] = NoDomain]
    /\ UNCHANGED <<domainEpoch, bufferState, bufferOwner, bufferEpoch,
                    queueOwner, queueEpoch, queueIrq, linuxShadowQueueOwner,
                    linuxShadowIommu>>

FinishQueueRevoke(q) ==
    /\ q \in Queues
    /\ queueState[q] = "revoking"
    /\ iommuMap[q] = {}
    /\ ~submitted[q]
    /\ dmaAccess[q] = NoBuffer
    /\ queueIrq[q] \in Irqs
    /\ irqTarget[queueIrq[q]] = NoDomain
    /\ irqPending[queueIrq[q]] = NoDomain
    /\ queueState' = [queueState EXCEPT ![q] = "free"]
    /\ queueOwner' = [queueOwner EXCEPT ![q] = NoDomain]
    /\ queueEpoch' = [queueEpoch EXCEPT ![q] = 0]
    /\ queueBudget' = [queueBudget EXCEPT ![q] = 0]
    /\ queueIrq' = [queueIrq EXCEPT ![q] = NoIrq]
    /\ UNCHANGED <<domainEpoch, bufferState, bufferOwner, bufferEpoch,
                    irqTarget, irqEpoch, irqPending, iommuMap, submitted,
                    dmaAccess, linuxShadowQueueOwner, linuxShadowIommu>>

RevokeDomain(d) ==
    /\ d \in Domains
    /\ domainEpoch[d] < MaxEpoch
    /\ LET ownedQueues == {q \in Queues : queueOwner[q] = d} IN
       LET ownedBuffers == {b \in Buffers : bufferOwner[b] = d} IN
        /\ domainEpoch' = [domainEpoch EXCEPT ![d] = @ + 1]
        /\ bufferState' = [b \in Buffers |->
            IF b \in ownedBuffers THEN "revoking" ELSE bufferState[b]]
        /\ queueState' = [q \in Queues |->
            IF q \in ownedQueues THEN "revoking" ELSE queueState[q]]
        /\ queueBudget' = [q \in Queues |->
            IF q \in ownedQueues THEN 0 ELSE queueBudget[q]]
        /\ iommuMap' = [q \in Queues |->
            IF q \in ownedQueues
            THEN {}
            ELSE iommuMap[q] \ ownedBuffers]
        /\ submitted' = [q \in Queues |->
            IF q \in ownedQueues THEN FALSE ELSE submitted[q]]
        /\ dmaAccess' = [q \in Queues |->
            IF q \in ownedQueues \/ dmaAccess[q] \in ownedBuffers
            THEN NoBuffer
            ELSE dmaAccess[q]]
        /\ irqTarget' = [i \in Irqs |->
            IF irqTarget[i] = d THEN NoDomain ELSE irqTarget[i]]
        /\ irqEpoch' = [i \in Irqs |->
            IF irqTarget[i] = d THEN 0 ELSE irqEpoch[i]]
        /\ irqPending' = [i \in Irqs |->
            IF irqPending[i] = d THEN NoDomain ELSE irqPending[i]]
    /\ UNCHANGED <<bufferOwner, bufferEpoch, queueOwner, queueEpoch, queueIrq,
                    linuxShadowQueueOwner, linuxShadowIommu>>

Next ==
    \/ \E q \in Queues, d \in Domains:
        ForgeLinuxQueueOwner(q, d)
    \/ \E q \in Queues, b \in Buffers:
        ForgeLinuxIommu(q, b)
    \/ \E b \in Buffers, d \in Domains:
        AllocBuffer(b, d)
    \/ \E b \in Buffers:
        FinishBufferRevoke(b)
    \/ \E q \in Queues, d \in Domains, i \in Irqs:
        LeaseQueue(q, d, i)
    \/ \E q \in Queues, b \in Buffers:
        MapQueueDma(q, b)
    \/ \E q \in Queues:
        RingDoorbell(q)
    \/ \E q \in Queues, b \in Buffers:
        DeviceDma(q, b)
    \/ \E q \in Queues:
        CompleteDma(q)
    \/ \E q \in Queues:
        DeliverIrq(q)
    \/ \E i \in Irqs:
        ClearIrq(i)
    \/ \E q \in Queues:
        StartQueueRevoke(q)
    \/ \E q \in Queues:
        FinishQueueRevoke(q)
    \/ \E d \in Domains:
        RevokeDomain(d)

Spec == Init /\ [][Next]_vars

NoDoorbellWithoutLiveQueueLease ==
    \A q \in Queues:
        submitted[q] => QueueLive(q)

NoIommuMapWithoutQueueAndBufferAuthority ==
    \A q \in Queues:
        \A b \in iommuMap[q]:
            /\ QueueLive(q)
            /\ BufferLiveForDomain(b, queueOwner[q])

NoDmaWithoutIommuMap ==
    \A q \in Queues:
        dmaAccess[q] # NoBuffer =>
            IommuMapLive(q, dmaAccess[q])

NoIrqRouteForeign ==
    \A q \in Queues:
        queueState[q] = "leased" =>
            /\ QueueLive(q)
            /\ queueIrq[q] \in Irqs
            /\ irqTarget[queueIrq[q]] = queueOwner[q]
            /\ irqEpoch[queueIrq[q]] = queueEpoch[q]

NoIrqDeliveryForeign ==
    \A i \in Irqs:
        irqPending[i] # NoDomain =>
            /\ irqTarget[i] = irqPending[i]
            /\ irqEpoch[i] = domainEpoch[irqPending[i]]

NoIrqAliasedAcrossQueues ==
    \A i \in Irqs:
        Cardinality(QueuesReferencingIrq(i)) <= 1

NoRevokedQueueHasAuthority ==
    \A q \in Queues:
        queueState[q] # "leased" =>
            /\ iommuMap[q] = {}
            /\ ~submitted[q]
            /\ dmaAccess[q] = NoBuffer
            /\ queueBudget[q] = 0

NoFreeOrRevokingBufferMappedOrDma ==
    \A b \in Buffers:
        bufferState[b] # "owned" => NoIommuOrDma(b)

NoLinuxShadowQueueAuthority ==
    \A q \in Queues:
        \A d \in Domains:
            linuxShadowQueueOwner[q] = d /\ ~QueueLiveForDomain(q, d) =>
                ~(submitted[q] /\ queueOwner[q] = d)

NoLinuxShadowIommuAuthority ==
    \A q \in Queues:
        \A b \in linuxShadowIommu[q]:
            b \notin iommuMap[q] => dmaAccess[q] # b

NoStaleQueueEpoch ==
    \A q \in Queues:
        queueState[q] = "leased" =>
            /\ queueOwner[q] \in Domains
            /\ queueEpoch[q] = domainEpoch[queueOwner[q]]

=============================================================================
