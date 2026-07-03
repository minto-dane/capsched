---------- MODULE P5AROverheadLayoutGate ----------
EXTENDS Naturals

VARIABLES
    phase,
    attemptLocalCarrier,
    fixedRetryBudget,
    fixedReceiptCapacity,
    preFrozenAuthority,
    candidateIdentityCompareOnly,
    linearRbTreeScan,
    fullHierarchyScan,
    domainTableLookup,
    unboundedRetry,
    persistentTaskBit,
    persistentEntityBit,
    persistentRqField,
    persistentCfsRqField,
    perCgroupDeniedMap,
    allocationInPicker,
    sleepOrMonitorInPicker,
    policyLookupInPicker,
    disabledBranchNoEvidence,
    disabledObjectGrowth,
    taskLayoutChangeNoGate,
    hotFunctionGrowthNoEvidence,
    behaviorPatchApproved,
    cfsDenyAndRepickApproved,
    runtimeCoverageClaim,
    productionProtectionClaim,
    costEfficiencyClaim,
    datacenterReadinessClaim

vars == <<phase, attemptLocalCarrier, fixedRetryBudget, fixedReceiptCapacity,
          preFrozenAuthority, candidateIdentityCompareOnly, linearRbTreeScan,
          fullHierarchyScan, domainTableLookup, unboundedRetry,
          persistentTaskBit, persistentEntityBit, persistentRqField,
          persistentCfsRqField, perCgroupDeniedMap, allocationInPicker,
          sleepOrMonitorInPicker, policyLookupInPicker,
          disabledBranchNoEvidence, disabledObjectGrowth,
          taskLayoutChangeNoGate, hotFunctionGrowthNoEvidence,
          behaviorPatchApproved, cfsDenyAndRepickApproved,
          runtimeCoverageClaim, productionProtectionClaim, costEfficiencyClaim,
          datacenterReadinessClaim>>

Phases == {
    "Start",
    "CostScopeRecorded",
    "BoundedCarrierRecorded",
    "LayoutBaselineRecorded",
    "ReadyRecorded",
    "BadLinearRbTreeScan",
    "BadFullHierarchyScan",
    "BadDomainTableLookup",
    "BadUnboundedRetry",
    "BadPersistentTaskBit",
    "BadPersistentEntityBit",
    "BadPersistentRqField",
    "BadPersistentCfsRqField",
    "BadPerCgroupMap",
    "BadAllocationInPicker",
    "BadSleepOrMonitorInPicker",
    "BadPolicyLookupInPicker",
    "BadDisabledBranchNoEvidence",
    "BadDisabledObjectGrowth",
    "BadTaskLayoutChangeNoGate",
    "BadHotFunctionGrowthNoEvidence",
    "BadBehaviorOverclaim",
    "BadCostProtectionClaim"
}

Base ==
    [ phase |-> "Start",
      attemptLocalCarrier |-> FALSE,
      fixedRetryBudget |-> FALSE,
      fixedReceiptCapacity |-> FALSE,
      preFrozenAuthority |-> FALSE,
      candidateIdentityCompareOnly |-> FALSE,
      linearRbTreeScan |-> FALSE,
      fullHierarchyScan |-> FALSE,
      domainTableLookup |-> FALSE,
      unboundedRetry |-> FALSE,
      persistentTaskBit |-> FALSE,
      persistentEntityBit |-> FALSE,
      persistentRqField |-> FALSE,
      persistentCfsRqField |-> FALSE,
      perCgroupDeniedMap |-> FALSE,
      allocationInPicker |-> FALSE,
      sleepOrMonitorInPicker |-> FALSE,
      policyLookupInPicker |-> FALSE,
      disabledBranchNoEvidence |-> FALSE,
      disabledObjectGrowth |-> FALSE,
      taskLayoutChangeNoGate |-> FALSE,
      hotFunctionGrowthNoEvidence |-> FALSE,
      behaviorPatchApproved |-> FALSE,
      cfsDenyAndRepickApproved |-> FALSE,
      runtimeCoverageClaim |-> FALSE,
      productionProtectionClaim |-> FALSE,
      costEfficiencyClaim |-> FALSE,
      datacenterReadinessClaim |-> FALSE ]

SetState(s) ==
    /\ phase = s.phase
    /\ attemptLocalCarrier = s.attemptLocalCarrier
    /\ fixedRetryBudget = s.fixedRetryBudget
    /\ fixedReceiptCapacity = s.fixedReceiptCapacity
    /\ preFrozenAuthority = s.preFrozenAuthority
    /\ candidateIdentityCompareOnly = s.candidateIdentityCompareOnly
    /\ linearRbTreeScan = s.linearRbTreeScan
    /\ fullHierarchyScan = s.fullHierarchyScan
    /\ domainTableLookup = s.domainTableLookup
    /\ unboundedRetry = s.unboundedRetry
    /\ persistentTaskBit = s.persistentTaskBit
    /\ persistentEntityBit = s.persistentEntityBit
    /\ persistentRqField = s.persistentRqField
    /\ persistentCfsRqField = s.persistentCfsRqField
    /\ perCgroupDeniedMap = s.perCgroupDeniedMap
    /\ allocationInPicker = s.allocationInPicker
    /\ sleepOrMonitorInPicker = s.sleepOrMonitorInPicker
    /\ policyLookupInPicker = s.policyLookupInPicker
    /\ disabledBranchNoEvidence = s.disabledBranchNoEvidence
    /\ disabledObjectGrowth = s.disabledObjectGrowth
    /\ taskLayoutChangeNoGate = s.taskLayoutChangeNoGate
    /\ hotFunctionGrowthNoEvidence = s.hotFunctionGrowthNoEvidence
    /\ behaviorPatchApproved = s.behaviorPatchApproved
    /\ cfsDenyAndRepickApproved = s.cfsDenyAndRepickApproved
    /\ runtimeCoverageClaim = s.runtimeCoverageClaim
    /\ productionProtectionClaim = s.productionProtectionClaim
    /\ costEfficiencyClaim = s.costEfficiencyClaim
    /\ datacenterReadinessClaim = s.datacenterReadinessClaim

Init == SetState(Base)

RecordCostScope ==
    /\ phase = "Start"
    /\ phase' = "CostScopeRecorded"
    /\ UNCHANGED <<attemptLocalCarrier, fixedRetryBudget,
                    fixedReceiptCapacity, preFrozenAuthority,
                    candidateIdentityCompareOnly, linearRbTreeScan,
                    fullHierarchyScan, domainTableLookup, unboundedRetry,
                    persistentTaskBit, persistentEntityBit, persistentRqField,
                    persistentCfsRqField, perCgroupDeniedMap,
                    allocationInPicker, sleepOrMonitorInPicker,
                    policyLookupInPicker, disabledBranchNoEvidence,
                    disabledObjectGrowth, taskLayoutChangeNoGate,
                    hotFunctionGrowthNoEvidence, behaviorPatchApproved,
                    cfsDenyAndRepickApproved, runtimeCoverageClaim,
                    productionProtectionClaim, costEfficiencyClaim,
                    datacenterReadinessClaim>>

RecordBoundedCarrier ==
    /\ phase = "CostScopeRecorded"
    /\ attemptLocalCarrier' = TRUE
    /\ fixedRetryBudget' = TRUE
    /\ fixedReceiptCapacity' = TRUE
    /\ preFrozenAuthority' = TRUE
    /\ candidateIdentityCompareOnly' = TRUE
    /\ phase' = "BoundedCarrierRecorded"
    /\ UNCHANGED <<linearRbTreeScan, fullHierarchyScan, domainTableLookup,
                    unboundedRetry, persistentTaskBit, persistentEntityBit,
                    persistentRqField, persistentCfsRqField,
                    perCgroupDeniedMap, allocationInPicker,
                    sleepOrMonitorInPicker, policyLookupInPicker,
                    disabledBranchNoEvidence, disabledObjectGrowth,
                    taskLayoutChangeNoGate, hotFunctionGrowthNoEvidence,
                    behaviorPatchApproved, cfsDenyAndRepickApproved,
                    runtimeCoverageClaim, productionProtectionClaim,
                    costEfficiencyClaim, datacenterReadinessClaim>>

RecordLayoutBaseline ==
    /\ phase = "BoundedCarrierRecorded"
    /\ phase' = "LayoutBaselineRecorded"
    /\ UNCHANGED <<attemptLocalCarrier, fixedRetryBudget,
                    fixedReceiptCapacity, preFrozenAuthority,
                    candidateIdentityCompareOnly, linearRbTreeScan,
                    fullHierarchyScan, domainTableLookup, unboundedRetry,
                    persistentTaskBit, persistentEntityBit, persistentRqField,
                    persistentCfsRqField, perCgroupDeniedMap,
                    allocationInPicker, sleepOrMonitorInPicker,
                    policyLookupInPicker, disabledBranchNoEvidence,
                    disabledObjectGrowth, taskLayoutChangeNoGate,
                    hotFunctionGrowthNoEvidence, behaviorPatchApproved,
                    cfsDenyAndRepickApproved, runtimeCoverageClaim,
                    productionProtectionClaim, costEfficiencyClaim,
                    datacenterReadinessClaim>>

RecordReady ==
    /\ phase = "LayoutBaselineRecorded"
    /\ attemptLocalCarrier
    /\ fixedRetryBudget
    /\ fixedReceiptCapacity
    /\ preFrozenAuthority
    /\ candidateIdentityCompareOnly
    /\ phase' = "ReadyRecorded"
    /\ UNCHANGED <<attemptLocalCarrier, fixedRetryBudget,
                    fixedReceiptCapacity, preFrozenAuthority,
                    candidateIdentityCompareOnly, linearRbTreeScan,
                    fullHierarchyScan, domainTableLookup, unboundedRetry,
                    persistentTaskBit, persistentEntityBit, persistentRqField,
                    persistentCfsRqField, perCgroupDeniedMap,
                    allocationInPicker, sleepOrMonitorInPicker,
                    policyLookupInPicker, disabledBranchNoEvidence,
                    disabledObjectGrowth, taskLayoutChangeNoGate,
                    hotFunctionGrowthNoEvidence, behaviorPatchApproved,
                    cfsDenyAndRepickApproved, runtimeCoverageClaim,
                    productionProtectionClaim, costEfficiencyClaim,
                    datacenterReadinessClaim>>

StutterDone ==
    /\ phase = "ReadyRecorded"
    /\ UNCHANGED vars

Next ==
    \/ RecordCostScope
    \/ RecordBoundedCarrier
    \/ RecordLayoutBaseline
    \/ RecordReady
    \/ StutterDone

SafeSpec == Init /\ [][Next]_vars

UnsafeLinearRbTreeScanSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadLinearRbTreeScan",
                             !.linearRbTreeScan = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeFullHierarchyScanSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadFullHierarchyScan",
                             !.fullHierarchyScan = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeDomainTableLookupSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadDomainTableLookup",
                             !.domainTableLookup = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeUnboundedRetrySpec ==
    /\ SetState([Base EXCEPT !.phase = "BadUnboundedRetry",
                             !.unboundedRetry = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafePersistentTaskBitSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadPersistentTaskBit",
                             !.persistentTaskBit = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafePersistentEntityBitSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadPersistentEntityBit",
                             !.persistentEntityBit = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafePersistentRqFieldSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadPersistentRqField",
                             !.persistentRqField = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafePersistentCfsRqFieldSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadPersistentCfsRqField",
                             !.persistentCfsRqField = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafePerCgroupMapSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadPerCgroupMap",
                             !.perCgroupDeniedMap = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeAllocationInPickerSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadAllocationInPicker",
                             !.allocationInPicker = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeSleepOrMonitorInPickerSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadSleepOrMonitorInPicker",
                             !.sleepOrMonitorInPicker = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafePolicyLookupInPickerSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadPolicyLookupInPicker",
                             !.policyLookupInPicker = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeDisabledBranchNoEvidenceSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadDisabledBranchNoEvidence",
                             !.disabledBranchNoEvidence = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeDisabledObjectGrowthSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadDisabledObjectGrowth",
                             !.disabledObjectGrowth = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeTaskLayoutChangeNoGateSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadTaskLayoutChangeNoGate",
                             !.taskLayoutChangeNoGate = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeHotFunctionGrowthNoEvidenceSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadHotFunctionGrowthNoEvidence",
                             !.hotFunctionGrowthNoEvidence = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeBehaviorOverclaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadBehaviorOverclaim",
                             !.behaviorPatchApproved = TRUE,
                             !.cfsDenyAndRepickApproved = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeCostProtectionClaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadCostProtectionClaim",
                             !.runtimeCoverageClaim = TRUE,
                             !.productionProtectionClaim = TRUE,
                             !.costEfficiencyClaim = TRUE,
                             !.datacenterReadinessClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

TypeOK ==
    /\ phase \in Phases
    /\ attemptLocalCarrier \in BOOLEAN
    /\ fixedRetryBudget \in BOOLEAN
    /\ fixedReceiptCapacity \in BOOLEAN
    /\ preFrozenAuthority \in BOOLEAN
    /\ candidateIdentityCompareOnly \in BOOLEAN
    /\ linearRbTreeScan \in BOOLEAN
    /\ fullHierarchyScan \in BOOLEAN
    /\ domainTableLookup \in BOOLEAN
    /\ unboundedRetry \in BOOLEAN
    /\ persistentTaskBit \in BOOLEAN
    /\ persistentEntityBit \in BOOLEAN
    /\ persistentRqField \in BOOLEAN
    /\ persistentCfsRqField \in BOOLEAN
    /\ perCgroupDeniedMap \in BOOLEAN
    /\ allocationInPicker \in BOOLEAN
    /\ sleepOrMonitorInPicker \in BOOLEAN
    /\ policyLookupInPicker \in BOOLEAN
    /\ disabledBranchNoEvidence \in BOOLEAN
    /\ disabledObjectGrowth \in BOOLEAN
    /\ taskLayoutChangeNoGate \in BOOLEAN
    /\ hotFunctionGrowthNoEvidence \in BOOLEAN
    /\ behaviorPatchApproved \in BOOLEAN
    /\ cfsDenyAndRepickApproved \in BOOLEAN
    /\ runtimeCoverageClaim \in BOOLEAN
    /\ productionProtectionClaim \in BOOLEAN
    /\ costEfficiencyClaim \in BOOLEAN
    /\ datacenterReadinessClaim \in BOOLEAN

ReadyShape ==
    phase = "ReadyRecorded" =>
        /\ attemptLocalCarrier
        /\ fixedRetryBudget
        /\ fixedReceiptCapacity
        /\ preFrozenAuthority
        /\ candidateIdentityCompareOnly

NoUnboundedSearch ==
    /\ ~linearRbTreeScan
    /\ ~fullHierarchyScan
    /\ ~domainTableLookup
    /\ ~unboundedRetry

NoPersistentHotDenialLayout ==
    /\ ~persistentTaskBit
    /\ ~persistentEntityBit
    /\ ~persistentRqField
    /\ ~persistentCfsRqField
    /\ ~perCgroupDeniedMap

NoPickerSideEffects ==
    /\ ~allocationInPicker
    /\ ~sleepOrMonitorInPicker
    /\ ~policyLookupInPicker

NoDisabledOrLayoutOverclaim ==
    /\ ~disabledBranchNoEvidence
    /\ ~disabledObjectGrowth
    /\ ~taskLayoutChangeNoGate
    /\ ~hotFunctionGrowthNoEvidence

NoBehaviorOverclaim ==
    /\ ~behaviorPatchApproved
    /\ ~cfsDenyAndRepickApproved

NoCostProtectionOverclaim ==
    /\ ~runtimeCoverageClaim
    /\ ~productionProtectionClaim
    /\ ~costEfficiencyClaim
    /\ ~datacenterReadinessClaim

Safety ==
    /\ TypeOK
    /\ ReadyShape
    /\ NoUnboundedSearch
    /\ NoPersistentHotDenialLayout
    /\ NoPickerSideEffects
    /\ NoDisabledOrLayoutOverclaim
    /\ NoBehaviorOverclaim
    /\ NoCostProtectionOverclaim

====
