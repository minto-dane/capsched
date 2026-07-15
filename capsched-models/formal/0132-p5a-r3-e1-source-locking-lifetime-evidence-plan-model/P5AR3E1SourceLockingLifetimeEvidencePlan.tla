---------- MODULE P5AR3E1SourceLockingLifetimeEvidencePlan ----------
EXTENDS Naturals

CONSTANT Fault

ExactPrimary == Fault # "WrongPrimary"
RejectedLineNotParent == Fault # "RejectedLineParent"
FiniteBMax == Fault # "UnboundedBuckets"
SlotBeforeRunnable == Fault # "SlotAfterRunnable"
OverflowFailsClosed == Fault # "OverflowFallback"
SingleOuterLayer == Fault # "NestedOuterLayer"
SparseProjectionMap == Fault # "DenseProjectionMap"
PrivateMemoryBound == Fault # "PrivateMemoryOver64K"
NoOrdinaryHotGrowth == Fault # "HotObjectGrowth"
ExactE2Scope == Fault # "E2ScopeExpanded"
DefaultOff == Fault # "E2NotDefaultOff"
NoE2Callsite == Fault # "E2Callsite"
CrossArchitectureLayout == Fault # "MissingCrossArch"
ExistingProbePreserved == Fault # "ExistingProbeDrift"
RqThenOneMembership == Fault # "WrongLockOrder"
PublisherNoRq == Fault # "PublisherTakesRq"
AtMostOneBucketLock == Fault # "TwoBucketLocks"
WorkerOneProjection == Fault # "WorkerUpdatesMany"
QueueOutsideLocks == Fault # "QueueUnderLock"
CancelOutsideLocks == Fault # "CancelUnderLock"
UnboundWork == Fault # "CpuBoundWork"
WorkRefBeforeQueue == Fault # "MissingWorkRef"
QueueFalseKeepsRef == Fault # "QueueFalseDropsRef"
WorkerPublisherHandshake == Fault # "ClearRepublishRace"
OnlineInitBeforeAccept == Fault # "OnlineAcceptsEarly"
OfflineStopsAdmission == Fault # "OfflineAcceptsNew"
OfflineKeepsResidual == Fault # "OfflineForgetsResidual"
ActiveBitRequiresContribution == Fault # "ActiveBitClearedEarly"
StopEnqueueBeforeCancel == Fault # "CancelRacingEnqueue"
DrainBeforeFree == Fault # "FreeBeforeDrain"
RcuBeforeFree == Fault # "MissingRcuGrace"
GenerationNeverWraps == Fault # "GenerationWrap"
CompleteE3Matrix == Fault # "E3CasesReduced"
FixedE4Thresholds == Fault # "E4ThresholdRelaxed"
CrossPathNonClaim == Fault # "CrossPathClaim"
ProductionNonClaim == Fault # "ProductionClaim"

BMax == IF FiniteBMax THEN 64 ELSE 65
PrivateBytes == IF PrivateMemoryBound THEN 57792 ELSE 65537

VARIABLES phase,
          initialized,
          accepting,
          slots,
          contributions,
          activeBit,
          workOwned,
          workPending,
          workRunning,
          queueingDisabled,
          unpublished,
          rcuGrace,
          freed

vars == <<phase, initialized, accepting, slots, contributions, activeBit,
          workOwned, workPending, workRunning, queueingDisabled, unpublished,
          rcuGrace, freed>>

Init ==
    /\ phase = "Start"
    /\ initialized = FALSE
    /\ accepting = FALSE
    /\ slots = 0
    /\ contributions = 0
    /\ activeBit = FALSE
    /\ workOwned = FALSE
    /\ workPending = FALSE
    /\ workRunning = FALSE
    /\ queueingDisabled = FALSE
    /\ unpublished = FALSE
    /\ rcuGrace = FALSE
    /\ freed = FALSE

Online ==
    /\ phase = "Start"
    /\ phase' = "Online"
    /\ initialized' = TRUE
    /\ accepting' = OnlineInitBeforeAccept
    /\ UNCHANGED <<slots, contributions, activeBit, workOwned, workPending,
                    workRunning, queueingDisabled, unpublished, rcuGrace,
                    freed>>

Admit ==
    /\ phase = "Online"
    /\ phase' = "Admitted"
    /\ slots' = IF SlotBeforeRunnable THEN 1 ELSE 0
    /\ contributions' = 1
    /\ activeBit' = TRUE
    /\ UNCHANGED <<initialized, accepting, workOwned, workPending,
                    workRunning, queueingDisabled, unpublished, rcuGrace,
                    freed>>

Publish ==
    /\ phase = "Admitted"
    /\ phase' = "Published"
    /\ workOwned' = WorkRefBeforeQueue
    /\ workPending' = TRUE
    /\ UNCHANGED <<initialized, accepting, slots, contributions, activeBit,
                    workRunning, queueingDisabled, unpublished, rcuGrace,
                    freed>>

BeginWork ==
    /\ phase = "Published"
    /\ phase' = "Working"
    /\ workPending' = FALSE
    /\ workRunning' = TRUE
    /\ UNCHANGED <<initialized, accepting, slots, contributions, activeBit,
                    workOwned, queueingDisabled, unpublished, rcuGrace,
                    freed>>

FinishWork ==
    /\ phase = "Working"
    /\ phase' = "Settled"
    /\ workRunning' = FALSE
    /\ workOwned' = FALSE
    /\ UNCHANGED <<initialized, accepting, slots, contributions, activeBit,
                    workPending, queueingDisabled, unpublished, rcuGrace,
                    freed>>

Offline ==
    /\ phase = "Settled"
    /\ phase' = "Offline"
    /\ accepting' = ~OfflineStopsAdmission
    /\ contributions' = IF OfflineKeepsResidual THEN 0 ELSE 1
    /\ activeBit' = IF ActiveBitRequiresContribution
                     THEN contributions' # 0 ELSE FALSE
    /\ slots' = IF contributions' = 0 THEN 0 ELSE slots
    /\ UNCHANGED <<initialized, workOwned, workPending, workRunning,
                    queueingDisabled, unpublished, rcuGrace, freed>>

Retire ==
    /\ phase = "Offline"
    /\ phase' = "Retiring"
    /\ queueingDisabled' = StopEnqueueBeforeCancel
    /\ unpublished' = TRUE
    /\ UNCHANGED <<initialized, accepting, slots, contributions, activeBit,
                    workOwned, workPending, workRunning, rcuGrace, freed>>

Drain ==
    /\ phase = "Retiring"
    /\ phase' = "Drained"
    /\ workPending' = ~StopEnqueueBeforeCancel
    /\ workRunning' = FALSE
    /\ workOwned' = ~DrainBeforeFree
    /\ UNCHANGED <<initialized, accepting, slots, contributions, activeBit,
                    queueingDisabled, unpublished, rcuGrace, freed>>

WaitRcu ==
    /\ phase = "Drained"
    /\ phase' = "Rcu"
    /\ rcuGrace' = RcuBeforeFree
    /\ UNCHANGED <<initialized, accepting, slots, contributions, activeBit,
                    workOwned, workPending, workRunning, queueingDisabled,
                    unpublished, freed>>

Free ==
    /\ phase = "Rcu"
    /\ phase' = "Freed"
    /\ freed' = TRUE
    /\ UNCHANGED <<initialized, accepting, slots, contributions, activeBit,
                    workOwned, workPending, workRunning, queueingDisabled,
                    unpublished, rcuGrace>>

StayFreed == phase = "Freed" /\ UNCHANGED vars

Next == Online \/ Admit \/ Publish \/ BeginWork \/ FinishWork \/ Offline \/
        Retire \/ Drain \/ WaitRcu \/ Free \/ StayFreed

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"Start", "Online", "Admitted", "Published", "Working",
                    "Settled", "Offline", "Retiring", "Drained", "Rcu",
                    "Freed"}
    /\ initialized \in BOOLEAN
    /\ accepting \in BOOLEAN
    /\ slots \in Nat
    /\ contributions \in Nat
    /\ activeBit \in BOOLEAN
    /\ workOwned \in BOOLEAN
    /\ workPending \in BOOLEAN
    /\ workRunning \in BOOLEAN
    /\ queueingDisabled \in BOOLEAN
    /\ unpublished \in BOOLEAN
    /\ rcuGrace \in BOOLEAN
    /\ freed \in BOOLEAN

StateSafety ==
    /\ slots <= BMax
    /\ contributions > 0 => slots > 0
    /\ accepting => initialized
    /\ workPending => workOwned
    /\ workRunning => workOwned
    /\ phase \in {"Offline", "Retiring", "Drained", "Rcu", "Freed"}
       => ~accepting
    /\ ~activeBit => contributions = 0
    /\ freed =>
        /\ unpublished
        /\ queueingDisabled
        /\ contributions = 0
        /\ ~activeBit
        /\ ~workPending
        /\ ~workRunning
        /\ ~workOwned
        /\ rcuGrace

PlanContract ==
    /\ ExactPrimary
    /\ RejectedLineNotParent
    /\ FiniteBMax
    /\ SlotBeforeRunnable
    /\ OverflowFailsClosed
    /\ SingleOuterLayer
    /\ SparseProjectionMap
    /\ PrivateMemoryBound
    /\ PrivateBytes <= 65536
    /\ NoOrdinaryHotGrowth
    /\ ExactE2Scope
    /\ DefaultOff
    /\ NoE2Callsite
    /\ CrossArchitectureLayout
    /\ ExistingProbePreserved
    /\ RqThenOneMembership
    /\ PublisherNoRq
    /\ AtMostOneBucketLock
    /\ WorkerOneProjection
    /\ QueueOutsideLocks
    /\ CancelOutsideLocks
    /\ UnboundWork
    /\ WorkRefBeforeQueue
    /\ QueueFalseKeepsRef
    /\ WorkerPublisherHandshake
    /\ OnlineInitBeforeAccept
    /\ OfflineStopsAdmission
    /\ OfflineKeepsResidual
    /\ ActiveBitRequiresContribution
    /\ StopEnqueueBeforeCancel
    /\ DrainBeforeFree
    /\ RcuBeforeFree
    /\ GenerationNeverWraps
    /\ CompleteE3Matrix
    /\ FixedE4Thresholds
    /\ CrossPathNonClaim
    /\ ProductionNonClaim

Safety == TypeOK /\ StateSafety /\ PlanContract

=============================================================================
