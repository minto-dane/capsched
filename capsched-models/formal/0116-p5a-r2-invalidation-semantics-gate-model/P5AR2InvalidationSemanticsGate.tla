---------- MODULE P5AR2InvalidationSemanticsGate ----------
EXTENDS Naturals

VARIABLES
    phase,
    priorSourceMapPassed,
    summaryStatesDefined,
    freshStateDefined,
    staleStateDefined,
    refreshingStateDefined,
    blockedStateDefined,
    leafPropagationDefined,
    currentPropagationDefined,
    groupPropagationDefined,
    monitorRevokePropagationDefined,
    lockOwnershipDefined,
    refreshRequiresFrozenAuthority,
    refreshRequiresEpochGenerationCheck,
    refreshRequiresBudgetAffinityCheck,
    pickerTrustsOnlyFresh,
    staleBlocksPickerTrust,
    refreshingBlocksPickerTrust,
    blockedBlocksPickerTrust,
    groupSummaryNoFalsePositive,
    groupSummaryNoSilentFalseNegative,
    currentEntitySeparateFromTree,
    failClosedWhenNoFreshSummary,
    noInPlaceStaleToFreshWithoutRefresh,
    noEnqueueOnlyRefresh,
    noLinuxPolicyLookupInPicker,
    noMonitorCallInPicker,
    outerDomainConstraintPreserved,
    linuxPatchApproved,
    runtimeDenialClaim,
    completeCfsClaim,
    hotLayoutClaim,
    monitorClaim,
    productionClaim,
    costClaim,
    datacenterClaim

vars == <<phase, priorSourceMapPassed, summaryStatesDefined,
          freshStateDefined, staleStateDefined, refreshingStateDefined,
          blockedStateDefined, leafPropagationDefined,
          currentPropagationDefined, groupPropagationDefined,
          monitorRevokePropagationDefined, lockOwnershipDefined,
          refreshRequiresFrozenAuthority,
          refreshRequiresEpochGenerationCheck,
          refreshRequiresBudgetAffinityCheck, pickerTrustsOnlyFresh,
          staleBlocksPickerTrust, refreshingBlocksPickerTrust,
          blockedBlocksPickerTrust, groupSummaryNoFalsePositive,
          groupSummaryNoSilentFalseNegative, currentEntitySeparateFromTree,
          failClosedWhenNoFreshSummary, noInPlaceStaleToFreshWithoutRefresh,
          noEnqueueOnlyRefresh, noLinuxPolicyLookupInPicker,
          noMonitorCallInPicker, outerDomainConstraintPreserved,
          linuxPatchApproved, runtimeDenialClaim, completeCfsClaim,
          hotLayoutClaim, monitorClaim, productionClaim, costClaim,
          datacenterClaim>>

Base ==
    [ phase |-> "Start",
      priorSourceMapPassed |-> FALSE,
      summaryStatesDefined |-> FALSE,
      freshStateDefined |-> FALSE,
      staleStateDefined |-> FALSE,
      refreshingStateDefined |-> FALSE,
      blockedStateDefined |-> FALSE,
      leafPropagationDefined |-> FALSE,
      currentPropagationDefined |-> FALSE,
      groupPropagationDefined |-> FALSE,
      monitorRevokePropagationDefined |-> FALSE,
      lockOwnershipDefined |-> FALSE,
      refreshRequiresFrozenAuthority |-> FALSE,
      refreshRequiresEpochGenerationCheck |-> FALSE,
      refreshRequiresBudgetAffinityCheck |-> FALSE,
      pickerTrustsOnlyFresh |-> FALSE,
      staleBlocksPickerTrust |-> FALSE,
      refreshingBlocksPickerTrust |-> FALSE,
      blockedBlocksPickerTrust |-> FALSE,
      groupSummaryNoFalsePositive |-> FALSE,
      groupSummaryNoSilentFalseNegative |-> FALSE,
      currentEntitySeparateFromTree |-> FALSE,
      failClosedWhenNoFreshSummary |-> FALSE,
      noInPlaceStaleToFreshWithoutRefresh |-> FALSE,
      noEnqueueOnlyRefresh |-> FALSE,
      noLinuxPolicyLookupInPicker |-> FALSE,
      noMonitorCallInPicker |-> FALSE,
      outerDomainConstraintPreserved |-> FALSE,
      linuxPatchApproved |-> FALSE,
      runtimeDenialClaim |-> FALSE,
      completeCfsClaim |-> FALSE,
      hotLayoutClaim |-> FALSE,
      monitorClaim |-> FALSE,
      productionClaim |-> FALSE,
      costClaim |-> FALSE,
      datacenterClaim |-> FALSE ]

SetState(s) ==
    /\ phase = s.phase
    /\ priorSourceMapPassed = s.priorSourceMapPassed
    /\ summaryStatesDefined = s.summaryStatesDefined
    /\ freshStateDefined = s.freshStateDefined
    /\ staleStateDefined = s.staleStateDefined
    /\ refreshingStateDefined = s.refreshingStateDefined
    /\ blockedStateDefined = s.blockedStateDefined
    /\ leafPropagationDefined = s.leafPropagationDefined
    /\ currentPropagationDefined = s.currentPropagationDefined
    /\ groupPropagationDefined = s.groupPropagationDefined
    /\ monitorRevokePropagationDefined = s.monitorRevokePropagationDefined
    /\ lockOwnershipDefined = s.lockOwnershipDefined
    /\ refreshRequiresFrozenAuthority = s.refreshRequiresFrozenAuthority
    /\ refreshRequiresEpochGenerationCheck = s.refreshRequiresEpochGenerationCheck
    /\ refreshRequiresBudgetAffinityCheck = s.refreshRequiresBudgetAffinityCheck
    /\ pickerTrustsOnlyFresh = s.pickerTrustsOnlyFresh
    /\ staleBlocksPickerTrust = s.staleBlocksPickerTrust
    /\ refreshingBlocksPickerTrust = s.refreshingBlocksPickerTrust
    /\ blockedBlocksPickerTrust = s.blockedBlocksPickerTrust
    /\ groupSummaryNoFalsePositive = s.groupSummaryNoFalsePositive
    /\ groupSummaryNoSilentFalseNegative = s.groupSummaryNoSilentFalseNegative
    /\ currentEntitySeparateFromTree = s.currentEntitySeparateFromTree
    /\ failClosedWhenNoFreshSummary = s.failClosedWhenNoFreshSummary
    /\ noInPlaceStaleToFreshWithoutRefresh = s.noInPlaceStaleToFreshWithoutRefresh
    /\ noEnqueueOnlyRefresh = s.noEnqueueOnlyRefresh
    /\ noLinuxPolicyLookupInPicker = s.noLinuxPolicyLookupInPicker
    /\ noMonitorCallInPicker = s.noMonitorCallInPicker
    /\ outerDomainConstraintPreserved = s.outerDomainConstraintPreserved
    /\ linuxPatchApproved = s.linuxPatchApproved
    /\ runtimeDenialClaim = s.runtimeDenialClaim
    /\ completeCfsClaim = s.completeCfsClaim
    /\ hotLayoutClaim = s.hotLayoutClaim
    /\ monitorClaim = s.monitorClaim
    /\ productionClaim = s.productionClaim
    /\ costClaim = s.costClaim
    /\ datacenterClaim = s.datacenterClaim

Init == SetState(Base)

RecordStates ==
    /\ phase = "Start"
    /\ priorSourceMapPassed' = TRUE
    /\ summaryStatesDefined' = TRUE
    /\ freshStateDefined' = TRUE
    /\ staleStateDefined' = TRUE
    /\ refreshingStateDefined' = TRUE
    /\ blockedStateDefined' = TRUE
    /\ phase' = "StatesRecorded"
    /\ UNCHANGED <<leafPropagationDefined, currentPropagationDefined,
                    groupPropagationDefined, monitorRevokePropagationDefined,
                    lockOwnershipDefined, refreshRequiresFrozenAuthority,
                    refreshRequiresEpochGenerationCheck,
                    refreshRequiresBudgetAffinityCheck, pickerTrustsOnlyFresh,
                    staleBlocksPickerTrust, refreshingBlocksPickerTrust,
                    blockedBlocksPickerTrust, groupSummaryNoFalsePositive,
                    groupSummaryNoSilentFalseNegative,
                    currentEntitySeparateFromTree,
                    failClosedWhenNoFreshSummary,
                    noInPlaceStaleToFreshWithoutRefresh, noEnqueueOnlyRefresh,
                    noLinuxPolicyLookupInPicker, noMonitorCallInPicker,
                    outerDomainConstraintPreserved, linuxPatchApproved,
                    runtimeDenialClaim, completeCfsClaim, hotLayoutClaim,
                    monitorClaim, productionClaim, costClaim, datacenterClaim>>

RecordPropagation ==
    /\ phase = "StatesRecorded"
    /\ leafPropagationDefined' = TRUE
    /\ currentPropagationDefined' = TRUE
    /\ groupPropagationDefined' = TRUE
    /\ monitorRevokePropagationDefined' = TRUE
    /\ lockOwnershipDefined' = TRUE
    /\ phase' = "PropagationRecorded"
    /\ UNCHANGED <<priorSourceMapPassed, summaryStatesDefined,
                    freshStateDefined, staleStateDefined,
                    refreshingStateDefined, blockedStateDefined,
                    refreshRequiresFrozenAuthority,
                    refreshRequiresEpochGenerationCheck,
                    refreshRequiresBudgetAffinityCheck, pickerTrustsOnlyFresh,
                    staleBlocksPickerTrust, refreshingBlocksPickerTrust,
                    blockedBlocksPickerTrust, groupSummaryNoFalsePositive,
                    groupSummaryNoSilentFalseNegative,
                    currentEntitySeparateFromTree,
                    failClosedWhenNoFreshSummary,
                    noInPlaceStaleToFreshWithoutRefresh, noEnqueueOnlyRefresh,
                    noLinuxPolicyLookupInPicker, noMonitorCallInPicker,
                    outerDomainConstraintPreserved, linuxPatchApproved,
                    runtimeDenialClaim, completeCfsClaim, hotLayoutClaim,
                    monitorClaim, productionClaim, costClaim, datacenterClaim>>

RecordRefreshRules ==
    /\ phase = "PropagationRecorded"
    /\ refreshRequiresFrozenAuthority' = TRUE
    /\ refreshRequiresEpochGenerationCheck' = TRUE
    /\ refreshRequiresBudgetAffinityCheck' = TRUE
    /\ noInPlaceStaleToFreshWithoutRefresh' = TRUE
    /\ noEnqueueOnlyRefresh' = TRUE
    /\ phase' = "RefreshRulesRecorded"
    /\ UNCHANGED <<priorSourceMapPassed, summaryStatesDefined,
                    freshStateDefined, staleStateDefined,
                    refreshingStateDefined, blockedStateDefined,
                    leafPropagationDefined, currentPropagationDefined,
                    groupPropagationDefined, monitorRevokePropagationDefined,
                    lockOwnershipDefined, pickerTrustsOnlyFresh,
                    staleBlocksPickerTrust, refreshingBlocksPickerTrust,
                    blockedBlocksPickerTrust, groupSummaryNoFalsePositive,
                    groupSummaryNoSilentFalseNegative,
                    currentEntitySeparateFromTree,
                    failClosedWhenNoFreshSummary,
                    noLinuxPolicyLookupInPicker, noMonitorCallInPicker,
                    outerDomainConstraintPreserved, linuxPatchApproved,
                    runtimeDenialClaim, completeCfsClaim, hotLayoutClaim,
                    monitorClaim, productionClaim, costClaim, datacenterClaim>>

RecordPickerRules ==
    /\ phase = "RefreshRulesRecorded"
    /\ pickerTrustsOnlyFresh' = TRUE
    /\ staleBlocksPickerTrust' = TRUE
    /\ refreshingBlocksPickerTrust' = TRUE
    /\ blockedBlocksPickerTrust' = TRUE
    /\ groupSummaryNoFalsePositive' = TRUE
    /\ groupSummaryNoSilentFalseNegative' = TRUE
    /\ currentEntitySeparateFromTree' = TRUE
    /\ failClosedWhenNoFreshSummary' = TRUE
    /\ noLinuxPolicyLookupInPicker' = TRUE
    /\ noMonitorCallInPicker' = TRUE
    /\ outerDomainConstraintPreserved' = TRUE
    /\ phase' = "SemanticsReady"
    /\ UNCHANGED <<priorSourceMapPassed, summaryStatesDefined,
                    freshStateDefined, staleStateDefined,
                    refreshingStateDefined, blockedStateDefined,
                    leafPropagationDefined, currentPropagationDefined,
                    groupPropagationDefined, monitorRevokePropagationDefined,
                    lockOwnershipDefined, refreshRequiresFrozenAuthority,
                    refreshRequiresEpochGenerationCheck,
                    refreshRequiresBudgetAffinityCheck,
                    noInPlaceStaleToFreshWithoutRefresh, noEnqueueOnlyRefresh,
                    linuxPatchApproved, runtimeDenialClaim, completeCfsClaim,
                    hotLayoutClaim, monitorClaim, productionClaim, costClaim,
                    datacenterClaim>>

StutterDone ==
    /\ phase = "SemanticsReady"
    /\ UNCHANGED vars

Next ==
    \/ RecordStates
    \/ RecordPropagation
    \/ RecordRefreshRules
    \/ RecordPickerRules
    \/ StutterDone

SafeSpec == Init /\ [][Next]_vars

ReadyState ==
    [ Base EXCEPT
        !.phase = "SemanticsReady",
        !.priorSourceMapPassed = TRUE,
        !.summaryStatesDefined = TRUE,
        !.freshStateDefined = TRUE,
        !.staleStateDefined = TRUE,
        !.refreshingStateDefined = TRUE,
        !.blockedStateDefined = TRUE,
        !.leafPropagationDefined = TRUE,
        !.currentPropagationDefined = TRUE,
        !.groupPropagationDefined = TRUE,
        !.monitorRevokePropagationDefined = TRUE,
        !.lockOwnershipDefined = TRUE,
        !.refreshRequiresFrozenAuthority = TRUE,
        !.refreshRequiresEpochGenerationCheck = TRUE,
        !.refreshRequiresBudgetAffinityCheck = TRUE,
        !.pickerTrustsOnlyFresh = TRUE,
        !.staleBlocksPickerTrust = TRUE,
        !.refreshingBlocksPickerTrust = TRUE,
        !.blockedBlocksPickerTrust = TRUE,
        !.groupSummaryNoFalsePositive = TRUE,
        !.groupSummaryNoSilentFalseNegative = TRUE,
        !.currentEntitySeparateFromTree = TRUE,
        !.failClosedWhenNoFreshSummary = TRUE,
        !.noInPlaceStaleToFreshWithoutRefresh = TRUE,
        !.noEnqueueOnlyRefresh = TRUE,
        !.noLinuxPolicyLookupInPicker = TRUE,
        !.noMonitorCallInPicker = TRUE,
        !.outerDomainConstraintPreserved = TRUE ]

UnsafeMissingSummaryStatesSpec ==
    /\ SetState([ReadyState EXCEPT !.summaryStatesDefined = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingFreshStaleBlockedSpec ==
    /\ SetState([ReadyState EXCEPT
                    !.freshStateDefined = FALSE,
                    !.staleStateDefined = FALSE,
                    !.blockedStateDefined = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingRefreshingSpec ==
    /\ SetState([ReadyState EXCEPT !.refreshingStateDefined = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingLeafPropagationSpec ==
    /\ SetState([ReadyState EXCEPT !.leafPropagationDefined = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingCurrentPropagationSpec ==
    /\ SetState([ReadyState EXCEPT !.currentPropagationDefined = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingGroupPropagationSpec ==
    /\ SetState([ReadyState EXCEPT !.groupPropagationDefined = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingMonitorRevokePropagationSpec ==
    /\ SetState([ReadyState EXCEPT !.monitorRevokePropagationDefined = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingLockOwnershipSpec ==
    /\ SetState([ReadyState EXCEPT !.lockOwnershipDefined = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingFrozenAuthorityRefreshSpec ==
    /\ SetState([ReadyState EXCEPT !.refreshRequiresFrozenAuthority = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingEpochGenerationRefreshSpec ==
    /\ SetState([ReadyState EXCEPT !.refreshRequiresEpochGenerationCheck = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingBudgetAffinityRefreshSpec ==
    /\ SetState([ReadyState EXCEPT !.refreshRequiresBudgetAffinityCheck = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafePickerTrustsStaleSpec ==
    /\ SetState([ReadyState EXCEPT
                    !.pickerTrustsOnlyFresh = FALSE,
                    !.staleBlocksPickerTrust = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafePickerTrustsRefreshingOrBlockedSpec ==
    /\ SetState([ReadyState EXCEPT
                    !.refreshingBlocksPickerTrust = FALSE,
                    !.blockedBlocksPickerTrust = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeGroupSummaryFalsePositiveSpec ==
    /\ SetState([ReadyState EXCEPT !.groupSummaryNoFalsePositive = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeGroupSummarySilentFalseNegativeSpec ==
    /\ SetState([ReadyState EXCEPT !.groupSummaryNoSilentFalseNegative = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeCurrentTreeCollapseSpec ==
    /\ SetState([ReadyState EXCEPT !.currentEntitySeparateFromTree = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeNoFailClosedSpec ==
    /\ SetState([ReadyState EXCEPT !.failClosedWhenNoFreshSummary = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeInPlaceStaleToFreshSpec ==
    /\ SetState([ReadyState EXCEPT !.noInPlaceStaleToFreshWithoutRefresh = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeEnqueueOnlyRefreshSpec ==
    /\ SetState([ReadyState EXCEPT !.noEnqueueOnlyRefresh = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafePolicyOrMonitorCallInPickerSpec ==
    /\ SetState([ReadyState EXCEPT
                    !.noLinuxPolicyLookupInPicker = FALSE,
                    !.noMonitorCallInPicker = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingOuterDomainConstraintSpec ==
    /\ SetState([ReadyState EXCEPT !.outerDomainConstraintPreserved = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeLinuxPatchApprovedSpec ==
    /\ SetState([ReadyState EXCEPT !.linuxPatchApproved = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeRuntimeProtectionCostClaimSpec ==
    /\ SetState([ReadyState EXCEPT
                    !.runtimeDenialClaim = TRUE,
                    !.completeCfsClaim = TRUE,
                    !.hotLayoutClaim = TRUE,
                    !.monitorClaim = TRUE,
                    !.productionClaim = TRUE,
                    !.costClaim = TRUE,
                    !.datacenterClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

ReadyPreconditions ==
    phase # "SemanticsReady" \/
        /\ priorSourceMapPassed
        /\ summaryStatesDefined
        /\ freshStateDefined
        /\ staleStateDefined
        /\ refreshingStateDefined
        /\ blockedStateDefined
        /\ leafPropagationDefined
        /\ currentPropagationDefined
        /\ groupPropagationDefined
        /\ monitorRevokePropagationDefined
        /\ lockOwnershipDefined
        /\ refreshRequiresFrozenAuthority
        /\ refreshRequiresEpochGenerationCheck
        /\ refreshRequiresBudgetAffinityCheck
        /\ pickerTrustsOnlyFresh
        /\ staleBlocksPickerTrust
        /\ refreshingBlocksPickerTrust
        /\ blockedBlocksPickerTrust
        /\ groupSummaryNoFalsePositive
        /\ groupSummaryNoSilentFalseNegative
        /\ currentEntitySeparateFromTree
        /\ failClosedWhenNoFreshSummary
        /\ noInPlaceStaleToFreshWithoutRefresh
        /\ noEnqueueOnlyRefresh
        /\ noLinuxPolicyLookupInPicker
        /\ noMonitorCallInPicker
        /\ outerDomainConstraintPreserved

NonClaims ==
    /\ ~linuxPatchApproved
    /\ ~runtimeDenialClaim
    /\ ~completeCfsClaim
    /\ ~hotLayoutClaim
    /\ ~monitorClaim
    /\ ~productionClaim
    /\ ~costClaim
    /\ ~datacenterClaim

Safety ==
    /\ ReadyPreconditions
    /\ NonClaims

=============================================================================
