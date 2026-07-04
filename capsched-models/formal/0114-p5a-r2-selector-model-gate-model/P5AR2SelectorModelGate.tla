---------- MODULE P5AR2SelectorModelGate ----------
EXTENDS Naturals

VARIABLES
    phase,
    priorBoundaryRecorded,
    selectorDirectionRecorded,
    sourceAnchorsChecked,
    pickerVisibleBeforeSelection,
    frozenBeforeEnqueue,
    taskLocalCacheOnly,
    callerIndependentCache,
    invalidationModeled,
    generationEpochModeled,
    budgetRefillModeled,
    affinityCpusetModeled,
    migrationGroupRefreshModeled,
    receiptExitInvalidationModeled,
    groupSummaryModeled,
    eevdfCompatibleMinSummary,
    booleanOnlySummaryRejected,
    currentEntityModeled,
    failClosedSettlementModeled,
    crossPathSettledOrExcluded,
    cfsAccountingSeparated,
    outerDomainConstraintRecorded,
    noPostFilterProduction,
    noUnboundedScan,
    noSyntheticAuthority,
    noPickTimePolicyLookup,
    layoutEvidenceRequired,
    benchmarkEvidenceRequired,
    linuxPatchApproved,
    runtimeDenialClaim,
    cfsDenyRepickClaim,
    hotLayoutChangeApproved,
    monitorClaim,
    productionClaim,
    costClaim,
    deploymentClaim,
    datacenterClaim

vars == <<phase, priorBoundaryRecorded, selectorDirectionRecorded,
          sourceAnchorsChecked, pickerVisibleBeforeSelection,
          frozenBeforeEnqueue, taskLocalCacheOnly, callerIndependentCache,
          invalidationModeled, generationEpochModeled, budgetRefillModeled,
          affinityCpusetModeled, migrationGroupRefreshModeled,
          receiptExitInvalidationModeled, groupSummaryModeled,
          eevdfCompatibleMinSummary, booleanOnlySummaryRejected,
          currentEntityModeled, failClosedSettlementModeled,
          crossPathSettledOrExcluded, cfsAccountingSeparated,
          outerDomainConstraintRecorded,
          noPostFilterProduction, noUnboundedScan, noSyntheticAuthority,
          noPickTimePolicyLookup, layoutEvidenceRequired,
          benchmarkEvidenceRequired, linuxPatchApproved, runtimeDenialClaim,
          cfsDenyRepickClaim, hotLayoutChangeApproved, monitorClaim,
          productionClaim, costClaim, deploymentClaim, datacenterClaim>>

Base ==
    [ phase |-> "Start",
      priorBoundaryRecorded |-> FALSE,
      selectorDirectionRecorded |-> FALSE,
      sourceAnchorsChecked |-> FALSE,
      pickerVisibleBeforeSelection |-> FALSE,
      frozenBeforeEnqueue |-> FALSE,
      taskLocalCacheOnly |-> FALSE,
      callerIndependentCache |-> FALSE,
      invalidationModeled |-> FALSE,
      generationEpochModeled |-> FALSE,
      budgetRefillModeled |-> FALSE,
      affinityCpusetModeled |-> FALSE,
      migrationGroupRefreshModeled |-> FALSE,
      receiptExitInvalidationModeled |-> FALSE,
      groupSummaryModeled |-> FALSE,
      eevdfCompatibleMinSummary |-> FALSE,
      booleanOnlySummaryRejected |-> FALSE,
      currentEntityModeled |-> FALSE,
      failClosedSettlementModeled |-> FALSE,
      crossPathSettledOrExcluded |-> FALSE,
      cfsAccountingSeparated |-> FALSE,
      outerDomainConstraintRecorded |-> FALSE,
      noPostFilterProduction |-> FALSE,
      noUnboundedScan |-> FALSE,
      noSyntheticAuthority |-> FALSE,
      noPickTimePolicyLookup |-> FALSE,
      layoutEvidenceRequired |-> FALSE,
      benchmarkEvidenceRequired |-> FALSE,
      linuxPatchApproved |-> FALSE,
      runtimeDenialClaim |-> FALSE,
      cfsDenyRepickClaim |-> FALSE,
      hotLayoutChangeApproved |-> FALSE,
      monitorClaim |-> FALSE,
      productionClaim |-> FALSE,
      costClaim |-> FALSE,
      deploymentClaim |-> FALSE,
      datacenterClaim |-> FALSE ]

SetState(s) ==
    /\ phase = s.phase
    /\ priorBoundaryRecorded = s.priorBoundaryRecorded
    /\ selectorDirectionRecorded = s.selectorDirectionRecorded
    /\ sourceAnchorsChecked = s.sourceAnchorsChecked
    /\ pickerVisibleBeforeSelection = s.pickerVisibleBeforeSelection
    /\ frozenBeforeEnqueue = s.frozenBeforeEnqueue
    /\ taskLocalCacheOnly = s.taskLocalCacheOnly
    /\ callerIndependentCache = s.callerIndependentCache
    /\ invalidationModeled = s.invalidationModeled
    /\ generationEpochModeled = s.generationEpochModeled
    /\ budgetRefillModeled = s.budgetRefillModeled
    /\ affinityCpusetModeled = s.affinityCpusetModeled
    /\ migrationGroupRefreshModeled = s.migrationGroupRefreshModeled
    /\ receiptExitInvalidationModeled = s.receiptExitInvalidationModeled
    /\ groupSummaryModeled = s.groupSummaryModeled
    /\ eevdfCompatibleMinSummary = s.eevdfCompatibleMinSummary
    /\ booleanOnlySummaryRejected = s.booleanOnlySummaryRejected
    /\ currentEntityModeled = s.currentEntityModeled
    /\ failClosedSettlementModeled = s.failClosedSettlementModeled
    /\ crossPathSettledOrExcluded = s.crossPathSettledOrExcluded
    /\ cfsAccountingSeparated = s.cfsAccountingSeparated
    /\ outerDomainConstraintRecorded = s.outerDomainConstraintRecorded
    /\ noPostFilterProduction = s.noPostFilterProduction
    /\ noUnboundedScan = s.noUnboundedScan
    /\ noSyntheticAuthority = s.noSyntheticAuthority
    /\ noPickTimePolicyLookup = s.noPickTimePolicyLookup
    /\ layoutEvidenceRequired = s.layoutEvidenceRequired
    /\ benchmarkEvidenceRequired = s.benchmarkEvidenceRequired
    /\ linuxPatchApproved = s.linuxPatchApproved
    /\ runtimeDenialClaim = s.runtimeDenialClaim
    /\ cfsDenyRepickClaim = s.cfsDenyRepickClaim
    /\ hotLayoutChangeApproved = s.hotLayoutChangeApproved
    /\ monitorClaim = s.monitorClaim
    /\ productionClaim = s.productionClaim
    /\ costClaim = s.costClaim
    /\ deploymentClaim = s.deploymentClaim
    /\ datacenterClaim = s.datacenterClaim

Init == SetState(Base)

RecordDirection ==
    /\ phase = "Start"
    /\ priorBoundaryRecorded' = TRUE
    /\ selectorDirectionRecorded' = TRUE
    /\ sourceAnchorsChecked' = TRUE
    /\ noPostFilterProduction' = TRUE
    /\ noUnboundedScan' = TRUE
    /\ noSyntheticAuthority' = TRUE
    /\ noPickTimePolicyLookup' = TRUE
    /\ phase' = "DirectionRecorded"
    /\ UNCHANGED <<pickerVisibleBeforeSelection, frozenBeforeEnqueue,
                    taskLocalCacheOnly, callerIndependentCache,
                    invalidationModeled, generationEpochModeled,
                    budgetRefillModeled, affinityCpusetModeled,
                    migrationGroupRefreshModeled,
                    receiptExitInvalidationModeled, groupSummaryModeled,
                    eevdfCompatibleMinSummary, booleanOnlySummaryRejected,
                    currentEntityModeled, failClosedSettlementModeled,
                    crossPathSettledOrExcluded, cfsAccountingSeparated,
                    outerDomainConstraintRecorded, layoutEvidenceRequired,
                    benchmarkEvidenceRequired, linuxPatchApproved,
                    runtimeDenialClaim, cfsDenyRepickClaim,
                    hotLayoutChangeApproved, monitorClaim, productionClaim,
                    costClaim, deploymentClaim, datacenterClaim>>

RecordFrozenEligibility ==
    /\ phase = "DirectionRecorded"
    /\ pickerVisibleBeforeSelection' = TRUE
    /\ frozenBeforeEnqueue' = TRUE
    /\ taskLocalCacheOnly' = TRUE
    /\ callerIndependentCache' = TRUE
    /\ invalidationModeled' = TRUE
    /\ generationEpochModeled' = TRUE
    /\ budgetRefillModeled' = TRUE
    /\ affinityCpusetModeled' = TRUE
    /\ migrationGroupRefreshModeled' = TRUE
    /\ receiptExitInvalidationModeled' = TRUE
    /\ phase' = "FrozenEligibilityRecorded"
    /\ UNCHANGED <<priorBoundaryRecorded, selectorDirectionRecorded,
                    sourceAnchorsChecked, groupSummaryModeled,
                    eevdfCompatibleMinSummary, booleanOnlySummaryRejected,
                    currentEntityModeled, failClosedSettlementModeled,
                    crossPathSettledOrExcluded, cfsAccountingSeparated,
                    outerDomainConstraintRecorded, noPostFilterProduction,
                    noUnboundedScan, noSyntheticAuthority,
                    noPickTimePolicyLookup, layoutEvidenceRequired,
                    benchmarkEvidenceRequired, linuxPatchApproved,
                    runtimeDenialClaim, cfsDenyRepickClaim,
                    hotLayoutChangeApproved, monitorClaim, productionClaim,
                    costClaim, deploymentClaim, datacenterClaim>>

RecordSelectorSemantics ==
    /\ phase = "FrozenEligibilityRecorded"
    /\ groupSummaryModeled' = TRUE
    /\ eevdfCompatibleMinSummary' = TRUE
    /\ booleanOnlySummaryRejected' = TRUE
    /\ currentEntityModeled' = TRUE
    /\ failClosedSettlementModeled' = TRUE
    /\ crossPathSettledOrExcluded' = TRUE
    /\ cfsAccountingSeparated' = TRUE
    /\ outerDomainConstraintRecorded' = TRUE
    /\ phase' = "SelectorSemanticsRecorded"
    /\ UNCHANGED <<priorBoundaryRecorded, selectorDirectionRecorded,
                    sourceAnchorsChecked, pickerVisibleBeforeSelection,
                    frozenBeforeEnqueue, taskLocalCacheOnly,
                    callerIndependentCache, invalidationModeled,
                    generationEpochModeled, budgetRefillModeled,
                    affinityCpusetModeled, migrationGroupRefreshModeled,
                    receiptExitInvalidationModeled,
                    noPostFilterProduction, noUnboundedScan,
                    noSyntheticAuthority, noPickTimePolicyLookup,
                    layoutEvidenceRequired, benchmarkEvidenceRequired,
                    linuxPatchApproved, runtimeDenialClaim,
                    cfsDenyRepickClaim, hotLayoutChangeApproved,
                    monitorClaim, productionClaim, costClaim,
                    deploymentClaim, datacenterClaim>>

RecordEvidenceGates ==
    /\ phase = "SelectorSemanticsRecorded"
    /\ layoutEvidenceRequired' = TRUE
    /\ benchmarkEvidenceRequired' = TRUE
    /\ phase' = "GateReady"
    /\ UNCHANGED <<priorBoundaryRecorded, selectorDirectionRecorded,
                    sourceAnchorsChecked, pickerVisibleBeforeSelection,
                    frozenBeforeEnqueue, taskLocalCacheOnly,
                    callerIndependentCache, invalidationModeled,
                    generationEpochModeled, budgetRefillModeled,
                    affinityCpusetModeled, migrationGroupRefreshModeled,
                    receiptExitInvalidationModeled, groupSummaryModeled,
                    eevdfCompatibleMinSummary, booleanOnlySummaryRejected,
                    currentEntityModeled, failClosedSettlementModeled,
                    crossPathSettledOrExcluded,
                    cfsAccountingSeparated, outerDomainConstraintRecorded,
                    noPostFilterProduction, noUnboundedScan,
                    noSyntheticAuthority, noPickTimePolicyLookup,
                    linuxPatchApproved, runtimeDenialClaim,
                    cfsDenyRepickClaim, hotLayoutChangeApproved,
                    monitorClaim, productionClaim, costClaim,
                    deploymentClaim, datacenterClaim>>

StutterDone ==
    /\ phase = "GateReady"
    /\ UNCHANGED vars

Next ==
    \/ RecordDirection
    \/ RecordFrozenEligibility
    \/ RecordSelectorSemantics
    \/ RecordEvidenceGates
    \/ StutterDone

SafeSpec == Init /\ [][Next]_vars

GateReadyState ==
    [ Base EXCEPT
        !.phase = "GateReady",
        !.priorBoundaryRecorded = TRUE,
        !.selectorDirectionRecorded = TRUE,
        !.sourceAnchorsChecked = TRUE,
        !.pickerVisibleBeforeSelection = TRUE,
        !.frozenBeforeEnqueue = TRUE,
        !.taskLocalCacheOnly = TRUE,
        !.callerIndependentCache = TRUE,
        !.invalidationModeled = TRUE,
        !.generationEpochModeled = TRUE,
        !.budgetRefillModeled = TRUE,
        !.affinityCpusetModeled = TRUE,
        !.migrationGroupRefreshModeled = TRUE,
        !.receiptExitInvalidationModeled = TRUE,
        !.groupSummaryModeled = TRUE,
        !.eevdfCompatibleMinSummary = TRUE,
        !.booleanOnlySummaryRejected = TRUE,
        !.currentEntityModeled = TRUE,
        !.failClosedSettlementModeled = TRUE,
        !.crossPathSettledOrExcluded = TRUE,
        !.cfsAccountingSeparated = TRUE,
        !.outerDomainConstraintRecorded = TRUE,
        !.noPostFilterProduction = TRUE,
        !.noUnboundedScan = TRUE,
        !.noSyntheticAuthority = TRUE,
        !.noPickTimePolicyLookup = TRUE,
        !.layoutEvidenceRequired = TRUE,
        !.benchmarkEvidenceRequired = TRUE ]

UnsafeMissingFrozenBeforeEnqueueSpec ==
    /\ SetState([GateReadyState EXCEPT !.frozenBeforeEnqueue = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeCallerDependentCacheSpec ==
    /\ SetState([GateReadyState EXCEPT !.callerIndependentCache = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingInvalidationSpec ==
    /\ SetState([GateReadyState EXCEPT !.invalidationModeled = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingGenerationEpochSpec ==
    /\ SetState([GateReadyState EXCEPT !.generationEpochModeled = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingBudgetAffinitySpec ==
    /\ SetState([GateReadyState EXCEPT
                    !.budgetRefillModeled = FALSE,
                    !.affinityCpusetModeled = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingMigrationGroupRefreshSpec ==
    /\ SetState([GateReadyState EXCEPT !.migrationGroupRefreshModeled = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingReceiptExitInvalidationSpec ==
    /\ SetState([GateReadyState EXCEPT !.receiptExitInvalidationModeled = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingGroupSummarySpec ==
    /\ SetState([GateReadyState EXCEPT !.groupSummaryModeled = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingEevdfMinSummarySpec ==
    /\ SetState([GateReadyState EXCEPT !.eevdfCompatibleMinSummary = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeBooleanOnlySummarySpec ==
    /\ SetState([GateReadyState EXCEPT !.booleanOnlySummaryRejected = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingCurrentEntitySpec ==
    /\ SetState([GateReadyState EXCEPT !.currentEntityModeled = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingFailClosedSpec ==
    /\ SetState([GateReadyState EXCEPT !.failClosedSettlementModeled = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingCrossPathSpec ==
    /\ SetState([GateReadyState EXCEPT !.crossPathSettledOrExcluded = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingOuterDomainConstraintSpec ==
    /\ SetState([GateReadyState EXCEPT !.outerDomainConstraintRecorded = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafePostFilterProductionSpec ==
    /\ SetState([GateReadyState EXCEPT !.noPostFilterProduction = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeUnboundedScanSpec ==
    /\ SetState([GateReadyState EXCEPT !.noUnboundedScan = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeSyntheticAuthoritySpec ==
    /\ SetState([GateReadyState EXCEPT !.noSyntheticAuthority = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafePickTimePolicyLookupSpec ==
    /\ SetState([GateReadyState EXCEPT !.noPickTimePolicyLookup = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeLinuxPatchApprovedSpec ==
    /\ SetState([GateReadyState EXCEPT !.linuxPatchApproved = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeHotLayoutApprovedSpec ==
    /\ SetState([GateReadyState EXCEPT !.hotLayoutChangeApproved = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeRuntimeProtectionCostClaimSpec ==
    /\ SetState([GateReadyState EXCEPT
                    !.runtimeDenialClaim = TRUE,
                    !.cfsDenyRepickClaim = TRUE,
                    !.monitorClaim = TRUE,
                    !.productionClaim = TRUE,
                    !.costClaim = TRUE,
                    !.deploymentClaim = TRUE,
                    !.datacenterClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

GateReadyPreconditions ==
    phase # "GateReady" \/
        /\ priorBoundaryRecorded
        /\ selectorDirectionRecorded
        /\ sourceAnchorsChecked
        /\ pickerVisibleBeforeSelection
        /\ frozenBeforeEnqueue
        /\ taskLocalCacheOnly
        /\ callerIndependentCache
        /\ invalidationModeled
        /\ generationEpochModeled
        /\ budgetRefillModeled
        /\ affinityCpusetModeled
        /\ migrationGroupRefreshModeled
        /\ receiptExitInvalidationModeled
        /\ groupSummaryModeled
        /\ eevdfCompatibleMinSummary
        /\ booleanOnlySummaryRejected
        /\ currentEntityModeled
        /\ failClosedSettlementModeled
        /\ crossPathSettledOrExcluded
        /\ cfsAccountingSeparated
        /\ outerDomainConstraintRecorded
        /\ noPostFilterProduction
        /\ noUnboundedScan
        /\ noSyntheticAuthority
        /\ noPickTimePolicyLookup
        /\ layoutEvidenceRequired
        /\ benchmarkEvidenceRequired

NonClaims ==
    /\ ~linuxPatchApproved
    /\ ~runtimeDenialClaim
    /\ ~cfsDenyRepickClaim
    /\ ~hotLayoutChangeApproved
    /\ ~monitorClaim
    /\ ~productionClaim
    /\ ~costClaim
    /\ ~deploymentClaim
    /\ ~datacenterClaim

Safety ==
    /\ GateReadyPreconditions
    /\ NonClaims

=============================================================================
