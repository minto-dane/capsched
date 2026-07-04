---------- MODULE P5AR2InvalidationSourceMap ----------
EXTENDS Naturals

VARIABLES
    phase,
    priorSelectorGatePassed,
    sourceAnchorsChecked,
    lifecycleResetMapped,
    forkGenerationMapped,
    execGenerationMapped,
    exitInvalidationMapped,
    affinityMaskMapped,
    queuedMoveMapped,
    setTaskCpuMapped,
    fairMigrationMapped,
    cgroupMoveMapped,
    cpusetUpdateMapped,
    budgetChargeMapped,
    throttleMapped,
    unthrottleRefillMapped,
    currentEntityMapped,
    groupSummaryMapped,
    monitorReceiptFutureMapped,
    lockBoundaryRecorded,
    noEnqueueOnlyAssumption,
    linuxPatchApproved,
    runtimeDenialClaim,
    completeCfsClaim,
    hotLayoutClaim,
    monitorClaim,
    productionClaim,
    costClaim,
    datacenterClaim

vars == <<phase, priorSelectorGatePassed, sourceAnchorsChecked,
          lifecycleResetMapped, forkGenerationMapped, execGenerationMapped,
          exitInvalidationMapped, affinityMaskMapped, queuedMoveMapped,
          setTaskCpuMapped, fairMigrationMapped, cgroupMoveMapped,
          cpusetUpdateMapped, budgetChargeMapped, throttleMapped,
          unthrottleRefillMapped, currentEntityMapped, groupSummaryMapped,
          monitorReceiptFutureMapped, lockBoundaryRecorded,
          noEnqueueOnlyAssumption, linuxPatchApproved, runtimeDenialClaim,
          completeCfsClaim, hotLayoutClaim, monitorClaim, productionClaim,
          costClaim, datacenterClaim>>

Base ==
    [ phase |-> "Start",
      priorSelectorGatePassed |-> FALSE,
      sourceAnchorsChecked |-> FALSE,
      lifecycleResetMapped |-> FALSE,
      forkGenerationMapped |-> FALSE,
      execGenerationMapped |-> FALSE,
      exitInvalidationMapped |-> FALSE,
      affinityMaskMapped |-> FALSE,
      queuedMoveMapped |-> FALSE,
      setTaskCpuMapped |-> FALSE,
      fairMigrationMapped |-> FALSE,
      cgroupMoveMapped |-> FALSE,
      cpusetUpdateMapped |-> FALSE,
      budgetChargeMapped |-> FALSE,
      throttleMapped |-> FALSE,
      unthrottleRefillMapped |-> FALSE,
      currentEntityMapped |-> FALSE,
      groupSummaryMapped |-> FALSE,
      monitorReceiptFutureMapped |-> FALSE,
      lockBoundaryRecorded |-> FALSE,
      noEnqueueOnlyAssumption |-> FALSE,
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
    /\ priorSelectorGatePassed = s.priorSelectorGatePassed
    /\ sourceAnchorsChecked = s.sourceAnchorsChecked
    /\ lifecycleResetMapped = s.lifecycleResetMapped
    /\ forkGenerationMapped = s.forkGenerationMapped
    /\ execGenerationMapped = s.execGenerationMapped
    /\ exitInvalidationMapped = s.exitInvalidationMapped
    /\ affinityMaskMapped = s.affinityMaskMapped
    /\ queuedMoveMapped = s.queuedMoveMapped
    /\ setTaskCpuMapped = s.setTaskCpuMapped
    /\ fairMigrationMapped = s.fairMigrationMapped
    /\ cgroupMoveMapped = s.cgroupMoveMapped
    /\ cpusetUpdateMapped = s.cpusetUpdateMapped
    /\ budgetChargeMapped = s.budgetChargeMapped
    /\ throttleMapped = s.throttleMapped
    /\ unthrottleRefillMapped = s.unthrottleRefillMapped
    /\ currentEntityMapped = s.currentEntityMapped
    /\ groupSummaryMapped = s.groupSummaryMapped
    /\ monitorReceiptFutureMapped = s.monitorReceiptFutureMapped
    /\ lockBoundaryRecorded = s.lockBoundaryRecorded
    /\ noEnqueueOnlyAssumption = s.noEnqueueOnlyAssumption
    /\ linuxPatchApproved = s.linuxPatchApproved
    /\ runtimeDenialClaim = s.runtimeDenialClaim
    /\ completeCfsClaim = s.completeCfsClaim
    /\ hotLayoutClaim = s.hotLayoutClaim
    /\ monitorClaim = s.monitorClaim
    /\ productionClaim = s.productionClaim
    /\ costClaim = s.costClaim
    /\ datacenterClaim = s.datacenterClaim

Init == SetState(Base)

RecordLifecycle ==
    /\ phase = "Start"
    /\ priorSelectorGatePassed' = TRUE
    /\ sourceAnchorsChecked' = TRUE
    /\ lifecycleResetMapped' = TRUE
    /\ forkGenerationMapped' = TRUE
    /\ execGenerationMapped' = TRUE
    /\ exitInvalidationMapped' = TRUE
    /\ phase' = "LifecycleMapped"
    /\ UNCHANGED <<affinityMaskMapped, queuedMoveMapped, setTaskCpuMapped,
                    fairMigrationMapped, cgroupMoveMapped, cpusetUpdateMapped,
                    budgetChargeMapped, throttleMapped, unthrottleRefillMapped,
                    currentEntityMapped, groupSummaryMapped,
                    monitorReceiptFutureMapped, lockBoundaryRecorded,
                    noEnqueueOnlyAssumption, linuxPatchApproved,
                    runtimeDenialClaim, completeCfsClaim, hotLayoutClaim,
                    monitorClaim, productionClaim, costClaim, datacenterClaim>>

RecordPlacement ==
    /\ phase = "LifecycleMapped"
    /\ affinityMaskMapped' = TRUE
    /\ queuedMoveMapped' = TRUE
    /\ setTaskCpuMapped' = TRUE
    /\ fairMigrationMapped' = TRUE
    /\ phase' = "PlacementMapped"
    /\ UNCHANGED <<priorSelectorGatePassed, sourceAnchorsChecked,
                    lifecycleResetMapped, forkGenerationMapped,
                    execGenerationMapped, exitInvalidationMapped,
                    cgroupMoveMapped, cpusetUpdateMapped, budgetChargeMapped,
                    throttleMapped, unthrottleRefillMapped,
                    currentEntityMapped, groupSummaryMapped,
                    monitorReceiptFutureMapped, lockBoundaryRecorded,
                    noEnqueueOnlyAssumption, linuxPatchApproved,
                    runtimeDenialClaim, completeCfsClaim, hotLayoutClaim,
                    monitorClaim, productionClaim, costClaim, datacenterClaim>>

RecordBudget ==
    /\ phase = "PlacementMapped"
    /\ budgetChargeMapped' = TRUE
    /\ throttleMapped' = TRUE
    /\ unthrottleRefillMapped' = TRUE
    /\ phase' = "BudgetMapped"
    /\ UNCHANGED <<priorSelectorGatePassed, sourceAnchorsChecked,
                    lifecycleResetMapped, forkGenerationMapped,
                    execGenerationMapped, exitInvalidationMapped,
                    affinityMaskMapped, queuedMoveMapped, setTaskCpuMapped,
                    fairMigrationMapped, cgroupMoveMapped, cpusetUpdateMapped,
                    currentEntityMapped, groupSummaryMapped,
                    monitorReceiptFutureMapped, lockBoundaryRecorded,
                    noEnqueueOnlyAssumption, linuxPatchApproved,
                    runtimeDenialClaim, completeCfsClaim, hotLayoutClaim,
                    monitorClaim, productionClaim, costClaim, datacenterClaim>>

RecordGroupCurrent ==
    /\ phase = "BudgetMapped"
    /\ cgroupMoveMapped' = TRUE
    /\ cpusetUpdateMapped' = TRUE
    /\ currentEntityMapped' = TRUE
    /\ groupSummaryMapped' = TRUE
    /\ phase' = "GroupCurrentMapped"
    /\ UNCHANGED <<priorSelectorGatePassed, sourceAnchorsChecked,
                    lifecycleResetMapped, forkGenerationMapped,
                    execGenerationMapped, exitInvalidationMapped,
                    affinityMaskMapped, queuedMoveMapped, setTaskCpuMapped,
                    fairMigrationMapped, budgetChargeMapped, throttleMapped,
                    unthrottleRefillMapped, monitorReceiptFutureMapped,
                    lockBoundaryRecorded, noEnqueueOnlyAssumption,
                    linuxPatchApproved, runtimeDenialClaim, completeCfsClaim,
                    hotLayoutClaim, monitorClaim, productionClaim, costClaim,
                    datacenterClaim>>

RecordBoundary ==
    /\ phase = "GroupCurrentMapped"
    /\ monitorReceiptFutureMapped' = TRUE
    /\ lockBoundaryRecorded' = TRUE
    /\ noEnqueueOnlyAssumption' = TRUE
    /\ phase' = "MapReady"
    /\ UNCHANGED <<priorSelectorGatePassed, sourceAnchorsChecked,
                    lifecycleResetMapped, forkGenerationMapped,
                    execGenerationMapped, exitInvalidationMapped,
                    affinityMaskMapped, queuedMoveMapped, setTaskCpuMapped,
                    fairMigrationMapped, cgroupMoveMapped, cpusetUpdateMapped,
                    budgetChargeMapped, throttleMapped, unthrottleRefillMapped,
                    currentEntityMapped, groupSummaryMapped,
                    linuxPatchApproved, runtimeDenialClaim, completeCfsClaim,
                    hotLayoutClaim, monitorClaim, productionClaim, costClaim,
                    datacenterClaim>>

StutterDone ==
    /\ phase = "MapReady"
    /\ UNCHANGED vars

Next ==
    \/ RecordLifecycle
    \/ RecordPlacement
    \/ RecordBudget
    \/ RecordGroupCurrent
    \/ RecordBoundary
    \/ StutterDone

SafeSpec == Init /\ [][Next]_vars

MapReadyState ==
    [ Base EXCEPT
        !.phase = "MapReady",
        !.priorSelectorGatePassed = TRUE,
        !.sourceAnchorsChecked = TRUE,
        !.lifecycleResetMapped = TRUE,
        !.forkGenerationMapped = TRUE,
        !.execGenerationMapped = TRUE,
        !.exitInvalidationMapped = TRUE,
        !.affinityMaskMapped = TRUE,
        !.queuedMoveMapped = TRUE,
        !.setTaskCpuMapped = TRUE,
        !.fairMigrationMapped = TRUE,
        !.cgroupMoveMapped = TRUE,
        !.cpusetUpdateMapped = TRUE,
        !.budgetChargeMapped = TRUE,
        !.throttleMapped = TRUE,
        !.unthrottleRefillMapped = TRUE,
        !.currentEntityMapped = TRUE,
        !.groupSummaryMapped = TRUE,
        !.monitorReceiptFutureMapped = TRUE,
        !.lockBoundaryRecorded = TRUE,
        !.noEnqueueOnlyAssumption = TRUE ]

UnsafeMissingLifecycleSpec ==
    /\ SetState([MapReadyState EXCEPT !.lifecycleResetMapped = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingForkExecExitSpec ==
    /\ SetState([MapReadyState EXCEPT
                    !.forkGenerationMapped = FALSE,
                    !.execGenerationMapped = FALSE,
                    !.exitInvalidationMapped = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingAffinitySpec ==
    /\ SetState([MapReadyState EXCEPT !.affinityMaskMapped = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingQueuedMoveSpec ==
    /\ SetState([MapReadyState EXCEPT !.queuedMoveMapped = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingSetTaskCpuSpec ==
    /\ SetState([MapReadyState EXCEPT !.setTaskCpuMapped = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingFairMigrationSpec ==
    /\ SetState([MapReadyState EXCEPT !.fairMigrationMapped = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingCgroupMoveSpec ==
    /\ SetState([MapReadyState EXCEPT !.cgroupMoveMapped = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingCpusetUpdateSpec ==
    /\ SetState([MapReadyState EXCEPT !.cpusetUpdateMapped = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingBudgetChargeSpec ==
    /\ SetState([MapReadyState EXCEPT !.budgetChargeMapped = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingThrottleRefillSpec ==
    /\ SetState([MapReadyState EXCEPT
                    !.throttleMapped = FALSE,
                    !.unthrottleRefillMapped = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingCurrentEntitySpec ==
    /\ SetState([MapReadyState EXCEPT !.currentEntityMapped = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingGroupSummarySpec ==
    /\ SetState([MapReadyState EXCEPT !.groupSummaryMapped = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingMonitorReceiptSpec ==
    /\ SetState([MapReadyState EXCEPT !.monitorReceiptFutureMapped = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingLockBoundarySpec ==
    /\ SetState([MapReadyState EXCEPT !.lockBoundaryRecorded = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeEnqueueOnlyAssumptionSpec ==
    /\ SetState([MapReadyState EXCEPT !.noEnqueueOnlyAssumption = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeLinuxPatchApprovedSpec ==
    /\ SetState([MapReadyState EXCEPT !.linuxPatchApproved = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeRuntimeProtectionCostClaimSpec ==
    /\ SetState([MapReadyState EXCEPT
                    !.runtimeDenialClaim = TRUE,
                    !.completeCfsClaim = TRUE,
                    !.hotLayoutClaim = TRUE,
                    !.monitorClaim = TRUE,
                    !.productionClaim = TRUE,
                    !.costClaim = TRUE,
                    !.datacenterClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

MapReadyPreconditions ==
    phase # "MapReady" \/
        /\ priorSelectorGatePassed
        /\ sourceAnchorsChecked
        /\ lifecycleResetMapped
        /\ forkGenerationMapped
        /\ execGenerationMapped
        /\ exitInvalidationMapped
        /\ affinityMaskMapped
        /\ queuedMoveMapped
        /\ setTaskCpuMapped
        /\ fairMigrationMapped
        /\ cgroupMoveMapped
        /\ cpusetUpdateMapped
        /\ budgetChargeMapped
        /\ throttleMapped
        /\ unthrottleRefillMapped
        /\ currentEntityMapped
        /\ groupSummaryMapped
        /\ monitorReceiptFutureMapped
        /\ lockBoundaryRecorded
        /\ noEnqueueOnlyAssumption

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
    /\ MapReadyPreconditions
    /\ NonClaims

=============================================================================
