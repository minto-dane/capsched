---------- MODULE P5ARImplementationReadyAudit ----------
EXTENDS Naturals

VARIABLES
    phase,
    gatesComplete,
    patchPlanValidated,
    nextPatchAbsent,
    draftReady,
    acceptanceMatrixRequired,
    linuxPatchAccepted,
    runtimeDenialApproved,
    cfsDenyRepickApproved,
    broadMoveApproved,
    runtimeCoverageClaim,
    protectionClaim,
    costClaim,
    monitorClaim

vars == <<phase, gatesComplete, patchPlanValidated, nextPatchAbsent,
          draftReady, acceptanceMatrixRequired, linuxPatchAccepted,
          runtimeDenialApproved, cfsDenyRepickApproved, broadMoveApproved,
          runtimeCoverageClaim, protectionClaim, costClaim, monitorClaim>>

Base ==
    [ phase |-> "Start",
      gatesComplete |-> FALSE,
      patchPlanValidated |-> FALSE,
      nextPatchAbsent |-> FALSE,
      draftReady |-> FALSE,
      acceptanceMatrixRequired |-> FALSE,
      linuxPatchAccepted |-> FALSE,
      runtimeDenialApproved |-> FALSE,
      cfsDenyRepickApproved |-> FALSE,
      broadMoveApproved |-> FALSE,
      runtimeCoverageClaim |-> FALSE,
      protectionClaim |-> FALSE,
      costClaim |-> FALSE,
      monitorClaim |-> FALSE ]

SetState(s) ==
    /\ phase = s.phase
    /\ gatesComplete = s.gatesComplete
    /\ patchPlanValidated = s.patchPlanValidated
    /\ nextPatchAbsent = s.nextPatchAbsent
    /\ draftReady = s.draftReady
    /\ acceptanceMatrixRequired = s.acceptanceMatrixRequired
    /\ linuxPatchAccepted = s.linuxPatchAccepted
    /\ runtimeDenialApproved = s.runtimeDenialApproved
    /\ cfsDenyRepickApproved = s.cfsDenyRepickApproved
    /\ broadMoveApproved = s.broadMoveApproved
    /\ runtimeCoverageClaim = s.runtimeCoverageClaim
    /\ protectionClaim = s.protectionClaim
    /\ costClaim = s.costClaim
    /\ monitorClaim = s.monitorClaim

Init == SetState(Base)

RecordGates ==
    /\ phase = "Start"
    /\ gatesComplete' = TRUE
    /\ patchPlanValidated' = TRUE
    /\ nextPatchAbsent' = TRUE
    /\ phase' = "GatesRecorded"
    /\ UNCHANGED <<draftReady, acceptanceMatrixRequired,
                    linuxPatchAccepted, runtimeDenialApproved,
                    cfsDenyRepickApproved, broadMoveApproved,
                    runtimeCoverageClaim, protectionClaim, costClaim,
                    monitorClaim>>

RecordAcceptanceObligations ==
    /\ phase = "GatesRecorded"
    /\ acceptanceMatrixRequired' = TRUE
    /\ phase' = "AcceptanceObligationsRecorded"
    /\ UNCHANGED <<gatesComplete, patchPlanValidated, nextPatchAbsent,
                    draftReady, linuxPatchAccepted, runtimeDenialApproved,
                    cfsDenyRepickApproved, broadMoveApproved,
                    runtimeCoverageClaim, protectionClaim, costClaim,
                    monitorClaim>>

DeclareDraftReady ==
    /\ phase = "AcceptanceObligationsRecorded"
    /\ draftReady' = TRUE
    /\ phase' = "DraftReady"
    /\ UNCHANGED <<gatesComplete, patchPlanValidated, nextPatchAbsent,
                    acceptanceMatrixRequired, linuxPatchAccepted,
                    runtimeDenialApproved, cfsDenyRepickApproved,
                    broadMoveApproved, runtimeCoverageClaim, protectionClaim,
                    costClaim, monitorClaim>>

StutterDone ==
    /\ phase = "DraftReady"
    /\ UNCHANGED vars

Next ==
    \/ RecordGates
    \/ RecordAcceptanceObligations
    \/ DeclareDraftReady
    \/ StutterDone

SafeSpec == Init /\ [][Next]_vars

UnsafeMissingGatesSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftReady",
                             !.draftReady = TRUE,
                             !.patchPlanValidated = TRUE,
                             !.nextPatchAbsent = TRUE,
                             !.acceptanceMatrixRequired = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingPatchPlanSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftReady",
                             !.gatesComplete = TRUE,
                             !.nextPatchAbsent = TRUE,
                             !.acceptanceMatrixRequired = TRUE,
                             !.draftReady = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeNextPatchAlreadyExistsSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftReady",
                             !.gatesComplete = TRUE,
                             !.patchPlanValidated = TRUE,
                             !.acceptanceMatrixRequired = TRUE,
                             !.draftReady = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingAcceptanceMatrixSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftReady",
                             !.gatesComplete = TRUE,
                             !.patchPlanValidated = TRUE,
                             !.nextPatchAbsent = TRUE,
                             !.draftReady = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeAcceptedPatchSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftReady",
                             !.gatesComplete = TRUE,
                             !.patchPlanValidated = TRUE,
                             !.nextPatchAbsent = TRUE,
                             !.acceptanceMatrixRequired = TRUE,
                             !.draftReady = TRUE,
                             !.linuxPatchAccepted = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeRuntimeDenialClaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftReady",
                             !.gatesComplete = TRUE,
                             !.patchPlanValidated = TRUE,
                             !.nextPatchAbsent = TRUE,
                             !.acceptanceMatrixRequired = TRUE,
                             !.draftReady = TRUE,
                             !.runtimeDenialApproved = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeCfsDenyRepickClaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftReady",
                             !.gatesComplete = TRUE,
                             !.patchPlanValidated = TRUE,
                             !.nextPatchAbsent = TRUE,
                             !.acceptanceMatrixRequired = TRUE,
                             !.draftReady = TRUE,
                             !.cfsDenyRepickApproved = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeBroadMoveClaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftReady",
                             !.gatesComplete = TRUE,
                             !.patchPlanValidated = TRUE,
                             !.nextPatchAbsent = TRUE,
                             !.acceptanceMatrixRequired = TRUE,
                             !.draftReady = TRUE,
                             !.broadMoveApproved = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeRuntimeCoverageClaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftReady",
                             !.gatesComplete = TRUE,
                             !.patchPlanValidated = TRUE,
                             !.nextPatchAbsent = TRUE,
                             !.acceptanceMatrixRequired = TRUE,
                             !.draftReady = TRUE,
                             !.runtimeCoverageClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeProtectionCostMonitorClaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "DraftReady",
                             !.gatesComplete = TRUE,
                             !.patchPlanValidated = TRUE,
                             !.nextPatchAbsent = TRUE,
                             !.acceptanceMatrixRequired = TRUE,
                             !.draftReady = TRUE,
                             !.protectionClaim = TRUE,
                             !.costClaim = TRUE,
                             !.monitorClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

DraftReadyPreconditions ==
    draftReady =>
        /\ gatesComplete
        /\ patchPlanValidated
        /\ nextPatchAbsent
        /\ acceptanceMatrixRequired

NonClaims ==
    /\ ~linuxPatchAccepted
    /\ ~runtimeDenialApproved
    /\ ~cfsDenyRepickApproved
    /\ ~broadMoveApproved
    /\ ~runtimeCoverageClaim
    /\ ~protectionClaim
    /\ ~costClaim
    /\ ~monitorClaim

Safety ==
    /\ DraftReadyPreconditions
    /\ NonClaims

=============================================================================
