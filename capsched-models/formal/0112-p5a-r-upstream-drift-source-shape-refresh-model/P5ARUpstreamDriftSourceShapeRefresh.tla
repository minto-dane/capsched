---------- MODULE P5ARUpstreamDriftSourceShapeRefresh ----------
EXTENDS Naturals

VARIABLES
    phase,
    upstreamFetched,
    upstreamAdvanced,
    previousIsAncestor,
    mergeTreeClean,
    directSchedulerShapeFresh,
    lifecycleDriftPresent,
    ordinaryCfsDraftAllowed,
    lifecycleFreshnessClaim,
    globalFreshnessClaim,
    linuxPatchAccepted,
    runtimeDenialApproved,
    protectionClaim,
    costClaim

vars == <<phase, upstreamFetched, upstreamAdvanced, previousIsAncestor,
          mergeTreeClean, directSchedulerShapeFresh, lifecycleDriftPresent,
          ordinaryCfsDraftAllowed, lifecycleFreshnessClaim,
          globalFreshnessClaim, linuxPatchAccepted, runtimeDenialApproved,
          protectionClaim, costClaim>>

Base ==
    [ phase |-> "Start",
      upstreamFetched |-> FALSE,
      upstreamAdvanced |-> FALSE,
      previousIsAncestor |-> FALSE,
      mergeTreeClean |-> FALSE,
      directSchedulerShapeFresh |-> FALSE,
      lifecycleDriftPresent |-> FALSE,
      ordinaryCfsDraftAllowed |-> FALSE,
      lifecycleFreshnessClaim |-> FALSE,
      globalFreshnessClaim |-> FALSE,
      linuxPatchAccepted |-> FALSE,
      runtimeDenialApproved |-> FALSE,
      protectionClaim |-> FALSE,
      costClaim |-> FALSE ]

SetState(s) ==
    /\ phase = s.phase
    /\ upstreamFetched = s.upstreamFetched
    /\ upstreamAdvanced = s.upstreamAdvanced
    /\ previousIsAncestor = s.previousIsAncestor
    /\ mergeTreeClean = s.mergeTreeClean
    /\ directSchedulerShapeFresh = s.directSchedulerShapeFresh
    /\ lifecycleDriftPresent = s.lifecycleDriftPresent
    /\ ordinaryCfsDraftAllowed = s.ordinaryCfsDraftAllowed
    /\ lifecycleFreshnessClaim = s.lifecycleFreshnessClaim
    /\ globalFreshnessClaim = s.globalFreshnessClaim
    /\ linuxPatchAccepted = s.linuxPatchAccepted
    /\ runtimeDenialApproved = s.runtimeDenialApproved
    /\ protectionClaim = s.protectionClaim
    /\ costClaim = s.costClaim

Init == SetState(Base)

RecordFetchAndDrift ==
    /\ phase = "Start"
    /\ upstreamFetched' = TRUE
    /\ upstreamAdvanced' = TRUE
    /\ previousIsAncestor' = TRUE
    /\ lifecycleDriftPresent' = TRUE
    /\ phase' = "DriftRecorded"
    /\ UNCHANGED <<mergeTreeClean, directSchedulerShapeFresh,
                    ordinaryCfsDraftAllowed, lifecycleFreshnessClaim,
                    globalFreshnessClaim, linuxPatchAccepted,
                    runtimeDenialApproved, protectionClaim, costClaim>>

RecordShapeAndMerge ==
    /\ phase = "DriftRecorded"
    /\ mergeTreeClean' = TRUE
    /\ directSchedulerShapeFresh' = TRUE
    /\ phase' = "ShapeFresh"
    /\ UNCHANGED <<upstreamFetched, upstreamAdvanced, previousIsAncestor,
                    lifecycleDriftPresent, ordinaryCfsDraftAllowed,
                    lifecycleFreshnessClaim, globalFreshnessClaim,
                    linuxPatchAccepted, runtimeDenialApproved, protectionClaim,
                    costClaim>>

AllowNarrowDraft ==
    /\ phase = "ShapeFresh"
    /\ ordinaryCfsDraftAllowed' = TRUE
    /\ phase' = "DraftStillReviewable"
    /\ UNCHANGED <<upstreamFetched, upstreamAdvanced, previousIsAncestor,
                    mergeTreeClean, directSchedulerShapeFresh,
                    lifecycleDriftPresent, lifecycleFreshnessClaim,
                    globalFreshnessClaim, linuxPatchAccepted,
                    runtimeDenialApproved, protectionClaim, costClaim>>

StutterDone ==
    /\ phase = "DraftStillReviewable"
    /\ UNCHANGED vars

Next ==
    \/ RecordFetchAndDrift
    \/ RecordShapeAndMerge
    \/ AllowNarrowDraft
    \/ StutterDone

SafeSpec == Init /\ [][Next]_vars

UnsafeNoFetchSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftStillReviewable",
                             !.ordinaryCfsDraftAllowed = TRUE,
                             !.mergeTreeClean = TRUE,
                             !.directSchedulerShapeFresh = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafePreviousNotAncestorSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftStillReviewable",
                             !.upstreamFetched = TRUE,
                             !.upstreamAdvanced = TRUE,
                             !.ordinaryCfsDraftAllowed = TRUE,
                             !.mergeTreeClean = TRUE,
                             !.directSchedulerShapeFresh = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMergeConflictSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftStillReviewable",
                             !.upstreamFetched = TRUE,
                             !.upstreamAdvanced = TRUE,
                             !.previousIsAncestor = TRUE,
                             !.ordinaryCfsDraftAllowed = TRUE,
                             !.directSchedulerShapeFresh = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeDirectShapeDriftSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftStillReviewable",
                             !.upstreamFetched = TRUE,
                             !.upstreamAdvanced = TRUE,
                             !.previousIsAncestor = TRUE,
                             !.mergeTreeClean = TRUE,
                             !.ordinaryCfsDraftAllowed = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeLifecycleFreshnessClaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftStillReviewable",
                             !.upstreamFetched = TRUE,
                             !.upstreamAdvanced = TRUE,
                             !.previousIsAncestor = TRUE,
                             !.mergeTreeClean = TRUE,
                             !.directSchedulerShapeFresh = TRUE,
                             !.lifecycleDriftPresent = TRUE,
                             !.ordinaryCfsDraftAllowed = TRUE,
                             !.lifecycleFreshnessClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeGlobalFreshnessClaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftStillReviewable",
                             !.upstreamFetched = TRUE,
                             !.upstreamAdvanced = TRUE,
                             !.previousIsAncestor = TRUE,
                             !.mergeTreeClean = TRUE,
                             !.directSchedulerShapeFresh = TRUE,
                             !.lifecycleDriftPresent = TRUE,
                             !.ordinaryCfsDraftAllowed = TRUE,
                             !.globalFreshnessClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafePatchAcceptedSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftStillReviewable",
                             !.upstreamFetched = TRUE,
                             !.upstreamAdvanced = TRUE,
                             !.previousIsAncestor = TRUE,
                             !.mergeTreeClean = TRUE,
                             !.directSchedulerShapeFresh = TRUE,
                             !.ordinaryCfsDraftAllowed = TRUE,
                             !.linuxPatchAccepted = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeRuntimeClaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftStillReviewable",
                             !.upstreamFetched = TRUE,
                             !.upstreamAdvanced = TRUE,
                             !.previousIsAncestor = TRUE,
                             !.mergeTreeClean = TRUE,
                             !.directSchedulerShapeFresh = TRUE,
                             !.ordinaryCfsDraftAllowed = TRUE,
                             !.runtimeDenialApproved = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeProtectionCostClaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftStillReviewable",
                             !.upstreamFetched = TRUE,
                             !.upstreamAdvanced = TRUE,
                             !.previousIsAncestor = TRUE,
                             !.mergeTreeClean = TRUE,
                             !.directSchedulerShapeFresh = TRUE,
                             !.ordinaryCfsDraftAllowed = TRUE,
                             !.protectionClaim = TRUE,
                             !.costClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

DraftPreconditions ==
    ordinaryCfsDraftAllowed =>
        /\ upstreamFetched
        /\ previousIsAncestor
        /\ mergeTreeClean
        /\ directSchedulerShapeFresh

NoOverclaim ==
    /\ ~(lifecycleDriftPresent /\ lifecycleFreshnessClaim)
    /\ ~globalFreshnessClaim
    /\ ~linuxPatchAccepted
    /\ ~runtimeDenialApproved
    /\ ~protectionClaim
    /\ ~costClaim

Safety ==
    /\ DraftPreconditions
    /\ NoOverclaim

=============================================================================
