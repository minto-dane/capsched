---------- MODULE P5AR2ExpandedLayoutProbePatchPlan ----------
EXTENDS Naturals

VARIABLES phase, evidence

vars == <<phase, evidence>>

BaseEvidence ==
    [ priorPlanPassed |-> FALSE,
      arm64BaselinePassed |-> FALSE,
      slot0014 |-> FALSE,
      oneProbeFileOnly |-> FALSE,
      kconfigFrozen |-> FALSE,
      makefileFrozen |-> FALSE,
      normalBuildProbeAbsent |-> FALSE,
      existingSymbolsPreserved |-> FALSE,
      exactAddedSymbols |-> FALSE,
      flagAreaMeasured |-> FALSE,
      execStartMeasured |-> FALSE,
      avgMeasured |-> FALSE,
      clockTaskMeasured |-> FALSE,
      cachelineWidthMeasured |-> FALSE,
      cachelineIndicesDerived |-> FALSE,
      candidateAbsenceHonest |-> FALSE,
      archLocalComparison |-> FALSE,
      replayRequired |-> FALSE,
      sourceReviewRequired |-> FALSE,
      linuxPatchCreated |-> FALSE,
      wrongSlot |-> FALSE,
      unboundedPaths |-> FALSE,
      kconfigModified |-> FALSE,
      makefileModified |-> FALSE,
      probeBuiltNormally |-> FALSE,
      candidateFieldsPretended |-> FALSE,
      exportedSymbol |-> FALSE,
      runtimeCallsite |-> FALSE,
      publicAbi |-> FALSE,
      hotField |-> FALSE,
      behavior |-> FALSE,
      crossArchIdentity |-> FALSE,
      protectionClaim |-> FALSE ]

ReadyEvidence ==
    [ BaseEvidence EXCEPT
        !.priorPlanPassed = TRUE,
        !.arm64BaselinePassed = TRUE,
        !.slot0014 = TRUE,
        !.oneProbeFileOnly = TRUE,
        !.kconfigFrozen = TRUE,
        !.makefileFrozen = TRUE,
        !.normalBuildProbeAbsent = TRUE,
        !.existingSymbolsPreserved = TRUE,
        !.exactAddedSymbols = TRUE,
        !.flagAreaMeasured = TRUE,
        !.execStartMeasured = TRUE,
        !.avgMeasured = TRUE,
        !.clockTaskMeasured = TRUE,
        !.cachelineWidthMeasured = TRUE,
        !.cachelineIndicesDerived = TRUE,
        !.candidateAbsenceHonest = TRUE,
        !.archLocalComparison = TRUE,
        !.replayRequired = TRUE,
        !.sourceReviewRequired = TRUE ]

Init == phase = "Start" /\ evidence = BaseEvidence

RecordBasis ==
    /\ phase = "Start"
    /\ phase' = "Basis"
    /\ evidence' = [evidence EXCEPT
        !.priorPlanPassed = TRUE,
        !.arm64BaselinePassed = TRUE,
        !.slot0014 = TRUE]

RecordContract ==
    /\ phase = "Basis"
    /\ phase' = "Contract"
    /\ evidence' = [evidence EXCEPT
        !.oneProbeFileOnly = TRUE,
        !.kconfigFrozen = TRUE,
        !.makefileFrozen = TRUE,
        !.normalBuildProbeAbsent = TRUE,
        !.existingSymbolsPreserved = TRUE,
        !.exactAddedSymbols = TRUE,
        !.flagAreaMeasured = TRUE,
        !.execStartMeasured = TRUE,
        !.avgMeasured = TRUE,
        !.clockTaskMeasured = TRUE]

RecordEvidenceBoundary ==
    /\ phase = "Contract"
    /\ phase' = "Ready"
    /\ evidence' = [evidence EXCEPT
        !.cachelineWidthMeasured = TRUE,
        !.cachelineIndicesDerived = TRUE,
        !.candidateAbsenceHonest = TRUE,
        !.archLocalComparison = TRUE,
        !.replayRequired = TRUE,
        !.sourceReviewRequired = TRUE]

Done == phase = "Ready" /\ UNCHANGED vars
Next == RecordBasis \/ RecordContract \/ RecordEvidenceBoundary \/ Done
SafeSpec == Init /\ [][Next]_vars

SetReady(e) == phase = "Ready" /\ evidence = e
UnsafeMissingPriorSpec == SetReady([ReadyEvidence EXCEPT !.priorPlanPassed = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeWrongSlotSpec == SetReady([ReadyEvidence EXCEPT !.wrongSlot = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeUnboundedPathsSpec == SetReady([ReadyEvidence EXCEPT !.unboundedPaths = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeKconfigModifiedSpec == SetReady([ReadyEvidence EXCEPT !.kconfigModified = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeMakefileModifiedSpec == SetReady([ReadyEvidence EXCEPT !.makefileModified = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeNormalBuildProbeSpec == SetReady([ReadyEvidence EXCEPT !.probeBuiltNormally = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingFlagFieldsSpec == SetReady([ReadyEvidence EXCEPT !.flagAreaMeasured = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingExecStartSpec == SetReady([ReadyEvidence EXCEPT !.execStartMeasured = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingAvgSpec == SetReady([ReadyEvidence EXCEPT !.avgMeasured = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingClockTaskSpec == SetReady([ReadyEvidence EXCEPT !.clockTaskMeasured = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingCachelineSpec == SetReady([ReadyEvidence EXCEPT !.cachelineWidthMeasured = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeCandidateFieldsPretendedSpec == SetReady([ReadyEvidence EXCEPT !.candidateFieldsPretended = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeExportedSpec == SetReady([ReadyEvidence EXCEPT !.exportedSymbol = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeRuntimeCallsiteSpec == SetReady([ReadyEvidence EXCEPT !.runtimeCallsite = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeAbiSpec == SetReady([ReadyEvidence EXCEPT !.publicAbi = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeHotFieldSpec == SetReady([ReadyEvidence EXCEPT !.hotField = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeBehaviorSpec == SetReady([ReadyEvidence EXCEPT !.behavior = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeCrossArchIdentitySpec == SetReady([ReadyEvidence EXCEPT !.crossArchIdentity = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingReplaySpec == SetReady([ReadyEvidence EXCEPT !.replayRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeProtectionClaimSpec == SetReady([ReadyEvidence EXCEPT !.protectionClaim = TRUE]) /\ [][UNCHANGED vars]_vars

Requirements ==
    /\ evidence.priorPlanPassed
    /\ evidence.arm64BaselinePassed
    /\ evidence.slot0014
    /\ evidence.oneProbeFileOnly
    /\ evidence.kconfigFrozen
    /\ evidence.makefileFrozen
    /\ evidence.normalBuildProbeAbsent
    /\ evidence.existingSymbolsPreserved
    /\ evidence.exactAddedSymbols
    /\ evidence.flagAreaMeasured
    /\ evidence.execStartMeasured
    /\ evidence.avgMeasured
    /\ evidence.clockTaskMeasured
    /\ evidence.cachelineWidthMeasured
    /\ evidence.cachelineIndicesDerived
    /\ evidence.candidateAbsenceHonest
    /\ evidence.archLocalComparison
    /\ evidence.replayRequired
    /\ evidence.sourceReviewRequired

ForbiddenClear ==
    /\ ~evidence.linuxPatchCreated
    /\ ~evidence.wrongSlot
    /\ ~evidence.unboundedPaths
    /\ ~evidence.kconfigModified
    /\ ~evidence.makefileModified
    /\ ~evidence.probeBuiltNormally
    /\ ~evidence.candidateFieldsPretended
    /\ ~evidence.exportedSymbol
    /\ ~evidence.runtimeCallsite
    /\ ~evidence.publicAbi
    /\ ~evidence.hotField
    /\ ~evidence.behavior
    /\ ~evidence.crossArchIdentity
    /\ ~evidence.protectionClaim

Safety == phase = "Ready" => Requirements /\ ForbiddenClear

=============================================================================
