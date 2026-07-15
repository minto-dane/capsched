---------- MODULE P5AR3BucketLocalTargetedProjection ----------
EXTENDS Naturals, FiniteSets

CONSTANT Fault

Rqs == {"r0", "r1"}
ProjectionStates == {"Fresh", "Stale", "Blocked"}

E4RejectionRecorded == Fault # "MissingE4Rejection"
ChunkedFullRebuildRejected == Fault # "ChunkedFullRebuildSelected"
BucketKeyComplete == Fault # "BucketKeyIncomplete"
CgroupIsNotAuthority == Fault # "CgroupIsAuthority"
MembershipIndex == Fault # "MissingMembershipIndex"
PerRqRefcount == Fault # "MissingPerRqRefcount"
InsertionHandshake == Fault # "MissingInsertionHandshake"
SnapshotUnderMembershipLock == Fault # "SnapshotOutsideMembershipLock"
WorkReferenceBeforeQueue == Fault # "MissingWorkReference"
PublisherNeverTakesRqLock == Fault # "PublisherTakesRqLock"
AtMostOneBucketLock == Fault # "TwoBucketLocksHeld"
ReleaseAcquirePublication == Fault # "MissingReleaseAcquire"
PickerGenerationFence == Fault # "PickerSkipsGeneration"
FinalTaskRecheck == Fault # "PickerSkipsFinalRecheck"
WorkerRqLock == Fault # "WorkerWithoutRqLock"
NoLeafScan == Fault # "WorkerScansLeaves"
OneBucketPerLock == Fault # "WorkerUpdatesMultipleBuckets"
RecheckGenerationBeforeFresh == Fault # "RacedWorkerPublishesFresh"
MigrationExclusive == Fault # "MigrationDoubleContribution"
OldRemovalBeforeUnlock == Fault # "OldRqRemovalLate"
DestinationAfterSettlement == Fault # "DestinationPublishesEarly"
NoAllocationUnderSchedulerLock == Fault # "AllocationUnderSchedulerLock"
LifetimeRefsAndRcu == Fault # "LifetimeWithoutRefsRcu"
NoFreeWithPendingWork == Fault # "FreeWithPendingWork"
GenerationNoWrap == Fault # "GenerationWrapReuse"
SingleOuterBucketLayer == Fault # "NestedOuterBuckets"
FiniteBucketAdmission == Fault # "UnboundedBucketAdmission"
CandidateCConstraint == Fault # "MissingCandidateCConstraint"
CrossPathSettlementRequired == Fault # "CrossPathUnsettled"
LinuxSourceApproved == Fault = "LinuxSourceApproved"
RuntimeClaim == Fault = "RuntimeClaim"
ProtectionClaim == Fault = "ProtectionClaim"
PerformanceClaim == Fault = "PerformanceClaim"
CostClaim == Fault = "CostClaim"

VARIABLES phase,
          publishedGen,
          bucketEligible,
          activeRqs,
          snapshotRqs,
          queuedRqs,
          localGen,
          localState,
          trustedRqs,
          finalRecheckedRqs,
          targetGen,
          rqLocked,
          updatesUnderLock,
          leafScan,
          oldContribution,
          newContribution,
          workRefs,
          objectAlive

vars == <<phase, publishedGen, bucketEligible, activeRqs, snapshotRqs,
          queuedRqs, localGen, localState, trustedRqs, finalRecheckedRqs,
          targetGen, rqLocked, updatesUnderLock, leafScan, oldContribution,
          newContribution, workRefs, objectAlive>>

Init ==
    /\ phase = "Start"
    /\ publishedGen = 1
    /\ bucketEligible = TRUE
    /\ activeRqs = {"r0"}
    /\ snapshotRqs = {}
    /\ queuedRqs = {}
    /\ localGen = [r \in Rqs |-> 1]
    /\ localState = [r \in Rqs |-> "Fresh"]
    /\ trustedRqs = {}
    /\ finalRecheckedRqs = {}
    /\ targetGen = 0
    /\ rqLocked = FALSE
    /\ updatesUnderLock = 0
    /\ leafScan = FALSE
    /\ oldContribution = TRUE
    /\ newContribution = FALSE
    /\ workRefs = 0
    /\ objectAlive = TRUE

PublishRevoke ==
    /\ phase = "Start"
    /\ phase' = "Published"
    /\ publishedGen' = IF E4RejectionRecorded THEN 2 ELSE 1
    /\ bucketEligible' = FALSE
    /\ LET selected == IF MembershipIndex /\ SnapshotUnderMembershipLock
                        THEN activeRqs ELSE {}
       IN /\ snapshotRqs' = selected
          /\ queuedRqs' = selected
          /\ workRefs' = IF WorkReferenceBeforeQueue
                          THEN Cardinality(selected) ELSE 0
    /\ trustedRqs' = {}
    /\ finalRecheckedRqs' = {}
    /\ UNCHANGED <<activeRqs, localGen, localState, targetGen, rqLocked,
                    updatesUnderLock, leafScan, oldContribution,
                    newContribution, objectAlive>>

CheckBeforeFanout ==
    /\ phase = "Published"
    /\ phase' = "Checked"
    /\ trustedRqs' =
        {r \in activeRqs:
            localState[r] = "Fresh" /\
            (IF PickerGenerationFence
             THEN localGen[r] = publishedGen ELSE TRUE) /\
            (IF PickerGenerationFence
             THEN bucketEligible ELSE TRUE)}
    /\ finalRecheckedRqs' =
        IF FinalTaskRecheck THEN trustedRqs' ELSE {}
    /\ UNCHANGED <<publishedGen, bucketEligible, activeRqs, snapshotRqs,
                    queuedRqs, localGen, localState, targetGen, rqLocked,
                    updatesUnderLock, leafScan, oldContribution,
                    newContribution, workRefs, objectAlive>>

LateEnqueue ==
    /\ phase = "Checked"
    /\ phase' = "LateEnqueued"
    /\ activeRqs' = IF MembershipIndex
                     THEN activeRqs \cup {"r1"} ELSE activeRqs
    /\ localGen' =
        [localGen EXCEPT !["r1"] =
            IF InsertionHandshake THEN publishedGen ELSE 1]
    /\ localState' =
        [localState EXCEPT !["r1"] =
            IF InsertionHandshake /\ ~bucketEligible
            THEN "Blocked" ELSE "Fresh"]
    /\ trustedRqs' = {}
    /\ finalRecheckedRqs' = {}
    /\ UNCHANGED <<publishedGen, bucketEligible, snapshotRqs, queuedRqs,
                    targetGen, rqLocked, updatesUnderLock, leafScan,
                    oldContribution, newContribution, workRefs, objectAlive>>

BeginOneBucketWork ==
    /\ phase = "LateEnqueued"
    /\ "r0" \in queuedRqs
    /\ phase' = "Working"
    /\ targetGen' = publishedGen
    /\ rqLocked' = WorkerRqLock
    /\ updatesUnderLock' = 0
    /\ leafScan' = FALSE
    /\ trustedRqs' = {}
    /\ finalRecheckedRqs' = {}
    /\ UNCHANGED <<publishedGen, bucketEligible, activeRqs, snapshotRqs,
                    queuedRqs, localGen, localState, oldContribution,
                    newContribution, workRefs, objectAlive>>

CommitStableWork ==
    /\ phase = "Working"
    /\ targetGen = publishedGen
    /\ phase' = "Committed"
    /\ localGen' = [localGen EXCEPT !["r0"] = targetGen]
    /\ localState' =
        [localState EXCEPT !["r0"] =
            IF bucketEligible THEN "Fresh" ELSE "Blocked"]
    /\ queuedRqs' = queuedRqs \ {"r0"}
    /\ workRefs' = IF WorkReferenceBeforeQueue /\ workRefs > 0
                    THEN workRefs - 1 ELSE workRefs
    /\ rqLocked' = FALSE
    /\ updatesUnderLock' = IF OneBucketPerLock THEN 1 ELSE 2
    /\ leafScan' = ~NoLeafScan
    /\ trustedRqs' = {}
    /\ finalRecheckedRqs' = {}
    /\ UNCHANGED <<publishedGen, bucketEligible, activeRqs, snapshotRqs,
                    targetGen, oldContribution, newContribution, objectAlive>>

RepublishDuringWork ==
    /\ phase = "Working"
    /\ phase' = "Raced"
    /\ publishedGen' = IF GenerationNoWrap
                        THEN publishedGen + 1 ELSE 1
    /\ bucketEligible' = TRUE
    /\ snapshotRqs' = IF MembershipIndex /\ SnapshotUnderMembershipLock
                       THEN activeRqs ELSE {}
    /\ queuedRqs' = queuedRqs \cup snapshotRqs'
    /\ workRefs' = IF WorkReferenceBeforeQueue
                    THEN Cardinality(queuedRqs') ELSE 0
    /\ UNCHANGED <<activeRqs, localGen, localState, trustedRqs,
                    finalRecheckedRqs, targetGen, rqLocked,
                    updatesUnderLock, leafScan, oldContribution,
                    newContribution, objectAlive>>

CommitRacedWork ==
    /\ phase = "Raced"
    /\ phase' = "Committed"
    /\ localGen' = [localGen EXCEPT !["r0"] = targetGen]
    /\ localState' =
        [localState EXCEPT !["r0"] =
            IF RecheckGenerationBeforeFresh THEN "Stale" ELSE "Fresh"]
    /\ queuedRqs' =
        IF RecheckGenerationBeforeFresh
        THEN queuedRqs ELSE queuedRqs \ {"r0"}
    /\ workRefs' =
        IF RecheckGenerationBeforeFresh
        THEN workRefs
        ELSE IF WorkReferenceBeforeQueue /\ workRefs > 0
             THEN workRefs - 1 ELSE workRefs
    /\ rqLocked' = FALSE
    /\ updatesUnderLock' = IF OneBucketPerLock THEN 1 ELSE 2
    /\ leafScan' = ~NoLeafScan
    /\ trustedRqs' = {}
    /\ finalRecheckedRqs' = {}
    /\ UNCHANGED <<publishedGen, bucketEligible, activeRqs, snapshotRqs,
                    targetGen, oldContribution, newContribution, objectAlive>>

FinalPick ==
    /\ phase = "Committed"
    /\ phase' = "Picked"
    /\ trustedRqs' =
        {r \in activeRqs:
            localState[r] = "Fresh" /\
            (IF PickerGenerationFence
             THEN localGen[r] = publishedGen ELSE TRUE) /\
            (IF PickerGenerationFence
             THEN bucketEligible ELSE TRUE)}
    /\ finalRecheckedRqs' =
        IF FinalTaskRecheck THEN trustedRqs' ELSE {}
    /\ UNCHANGED <<publishedGen, bucketEligible, activeRqs, snapshotRqs,
                    queuedRqs, localGen, localState, targetGen, rqLocked,
                    updatesUnderLock, leafScan, oldContribution,
                    newContribution, workRefs, objectAlive>>

Migrate ==
    /\ phase = "Picked"
    /\ phase' = "Migrated"
    /\ oldContribution' =
        IF MigrationExclusive /\ OldRemovalBeforeUnlock THEN FALSE ELSE TRUE
    /\ newContribution' = DestinationAfterSettlement
    /\ UNCHANGED <<publishedGen, bucketEligible, activeRqs, snapshotRqs,
                    queuedRqs, localGen, localState, trustedRqs,
                    finalRecheckedRqs, targetGen, rqLocked, updatesUnderLock,
                    leafScan, workRefs, objectAlive>>

Quiesce ==
    /\ phase = "Migrated"
    /\ phase' = "Done"
    /\ activeRqs' = {}
    /\ snapshotRqs' = {}
    /\ queuedRqs' = IF workRefs = 0 THEN {} ELSE queuedRqs
    /\ objectAlive' =
        IF LifetimeRefsAndRcu /\ NoFreeWithPendingWork
        THEN ~(workRefs = 0)
        ELSE FALSE
    /\ UNCHANGED <<publishedGen, bucketEligible, localGen, localState,
                    trustedRqs, finalRecheckedRqs, targetGen, rqLocked,
                    updatesUnderLock, leafScan, oldContribution,
                    newContribution, workRefs>>

StayDone ==
    /\ phase = "Done"
    /\ UNCHANGED vars

Next ==
    PublishRevoke \/ CheckBeforeFanout \/ LateEnqueue \/
    BeginOneBucketWork \/ CommitStableWork \/ RepublishDuringWork \/
    CommitRacedWork \/ FinalPick \/ Migrate \/ Quiesce \/ StayDone

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"Start", "Published", "Checked", "LateEnqueued",
                    "Working", "Raced", "Committed", "Picked",
                    "Migrated", "Done"}
    /\ publishedGen \in Nat
    /\ bucketEligible \in BOOLEAN
    /\ activeRqs \subseteq Rqs
    /\ snapshotRqs \subseteq Rqs
    /\ queuedRqs \subseteq Rqs
    /\ localGen \in [Rqs -> Nat]
    /\ localState \in [Rqs -> ProjectionStates]
    /\ trustedRqs \subseteq Rqs
    /\ finalRecheckedRqs \subseteq Rqs
    /\ targetGen \in Nat
    /\ rqLocked \in BOOLEAN
    /\ updatesUnderLock \in Nat
    /\ leafScan \in BOOLEAN
    /\ oldContribution \in BOOLEAN
    /\ newContribution \in BOOLEAN
    /\ workRefs \in Nat
    /\ objectAlive \in BOOLEAN

NoMissedAffectedRq ==
    phase # "Start" =>
        \A r \in activeRqs:
            r \in snapshotRqs \/ r \in queuedRqs \/
            localGen[r] = publishedGen

TrustedSafety ==
    \A r \in trustedRqs:
        /\ localState[r] = "Fresh"
        /\ localGen[r] = publishedGen
        /\ bucketEligible
        /\ r \in finalRecheckedRqs

WorkerLockSafety ==
    phase \in {"Working", "Raced"} => rqLocked

OneBucketWorkSafety ==
    /\ updatesUnderLock <= 1
    /\ ~leafScan

CommittedCoherence ==
    phase \in {"Committed", "Picked", "Migrated", "Done"} =>
        \A r \in Rqs:
            localState[r] = "Fresh" => localGen[r] = publishedGen

MigrationSafety ==
    phase \in {"Migrated", "Done"} =>
        /\ ~(oldContribution /\ newContribution)
        /\ ~oldContribution
        /\ newContribution

LifetimeSafety ==
    ~objectAlive =>
        /\ workRefs = 0
        /\ activeRqs = {}
        /\ queuedRqs = {}

Safety ==
    /\ TypeOK
    /\ NoMissedAffectedRq
    /\ TrustedSafety
    /\ WorkerLockSafety
    /\ OneBucketWorkSafety
    /\ CommittedCoherence
    /\ MigrationSafety
    /\ LifetimeSafety
    /\ E4RejectionRecorded
    /\ ChunkedFullRebuildRejected
    /\ BucketKeyComplete
    /\ CgroupIsNotAuthority
    /\ MembershipIndex
    /\ PerRqRefcount
    /\ InsertionHandshake
    /\ SnapshotUnderMembershipLock
    /\ WorkReferenceBeforeQueue
    /\ PublisherNeverTakesRqLock
    /\ AtMostOneBucketLock
    /\ ReleaseAcquirePublication
    /\ PickerGenerationFence
    /\ FinalTaskRecheck
    /\ WorkerRqLock
    /\ NoLeafScan
    /\ OneBucketPerLock
    /\ RecheckGenerationBeforeFresh
    /\ MigrationExclusive
    /\ OldRemovalBeforeUnlock
    /\ DestinationAfterSettlement
    /\ NoAllocationUnderSchedulerLock
    /\ LifetimeRefsAndRcu
    /\ NoFreeWithPendingWork
    /\ GenerationNoWrap
    /\ SingleOuterBucketLayer
    /\ FiniteBucketAdmission
    /\ CandidateCConstraint
    /\ CrossPathSettlementRequired
    /\ ~LinuxSourceApproved
    /\ ~RuntimeClaim
    /\ ~ProtectionClaim
    /\ ~PerformanceClaim
    /\ ~CostClaim

==============================================================
