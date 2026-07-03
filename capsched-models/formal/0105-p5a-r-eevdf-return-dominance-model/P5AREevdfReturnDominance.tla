---------- MODULE P5AREevdfReturnDominance ----------
EXTENDS Naturals

VARIABLES
    phase,
    selectedPath,
    dominatedPaths,
    schedulePickGated,
    wakeupSeparated,
    hotCostPreserved,
    symbolShapeChecked,
    lineOnlyGate,
    behaviorPatchApproved,
    cfsDenyAndRepickApproved,
    groupHierarchySettlementApproved,
    runtimeCoverageClaim,
    productionProtectionClaim,
    costEfficiencyClaim,
    datacenterReadinessClaim

vars == <<phase, selectedPath, dominatedPaths, schedulePickGated,
          wakeupSeparated, hotCostPreserved, symbolShapeChecked, lineOnlyGate,
          behaviorPatchApproved, cfsDenyAndRepickApproved,
          groupHierarchySettlementApproved, runtimeCoverageClaim,
          productionProtectionClaim, costEfficiencyClaim,
          datacenterReadinessClaim>>

NoPath == "none"
ReturnPaths == {
    "singleton",
    "nextBuddy",
    "protectedCurrent",
    "leftmostFunnel",
    "heapFunnel",
    "finalCurrentOverride"
}
PathOrNone == ReturnPaths \cup {NoPath}

Phases == {
    "Start",
    "Checked",
    "BadSingletonUndominated",
    "BadNextBuddyUndominated",
    "BadProtectedCurrentUndominated",
    "BadLeftmostFunnelUndominated",
    "BadHeapFunnelUndominated",
    "BadFinalCurrentOverrideUndominated",
    "BadWakeupBleed",
    "BadHotCostBreakage",
    "BadLineOnlyGate",
    "BadBehaviorOverclaim",
    "BadHierarchyOverclaim"
}

Base ==
    [ phase |-> "Start",
      selectedPath |-> NoPath,
      dominatedPaths |-> ReturnPaths,
      schedulePickGated |-> TRUE,
      wakeupSeparated |-> TRUE,
      hotCostPreserved |-> TRUE,
      symbolShapeChecked |-> TRUE,
      lineOnlyGate |-> FALSE,
      behaviorPatchApproved |-> FALSE,
      cfsDenyAndRepickApproved |-> FALSE,
      groupHierarchySettlementApproved |-> FALSE,
      runtimeCoverageClaim |-> FALSE,
      productionProtectionClaim |-> FALSE,
      costEfficiencyClaim |-> FALSE,
      datacenterReadinessClaim |-> FALSE ]

SetState(s) ==
    /\ phase = s.phase
    /\ selectedPath = s.selectedPath
    /\ dominatedPaths = s.dominatedPaths
    /\ schedulePickGated = s.schedulePickGated
    /\ wakeupSeparated = s.wakeupSeparated
    /\ hotCostPreserved = s.hotCostPreserved
    /\ symbolShapeChecked = s.symbolShapeChecked
    /\ lineOnlyGate = s.lineOnlyGate
    /\ behaviorPatchApproved = s.behaviorPatchApproved
    /\ cfsDenyAndRepickApproved = s.cfsDenyAndRepickApproved
    /\ groupHierarchySettlementApproved = s.groupHierarchySettlementApproved
    /\ runtimeCoverageClaim = s.runtimeCoverageClaim
    /\ productionProtectionClaim = s.productionProtectionClaim
    /\ costEfficiencyClaim = s.costEfficiencyClaim
    /\ datacenterReadinessClaim = s.datacenterReadinessClaim

Init == SetState(Base)

CheckPath ==
    /\ phase = "Start"
    /\ selectedPath' \in ReturnPaths
    /\ phase' = "Checked"
    /\ UNCHANGED <<dominatedPaths, schedulePickGated, wakeupSeparated,
                    hotCostPreserved, symbolShapeChecked, lineOnlyGate,
                    behaviorPatchApproved, cfsDenyAndRepickApproved,
                    groupHierarchySettlementApproved, runtimeCoverageClaim,
                    productionProtectionClaim, costEfficiencyClaim,
                    datacenterReadinessClaim>>

StutterChecked ==
    /\ phase = "Checked"
    /\ UNCHANGED vars

Next ==
    \/ CheckPath
    \/ StutterChecked

SafeSpec == Init /\ [][Next]_vars

UnsafeSingletonUndominatedSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadSingletonUndominated",
                             !.selectedPath = "singleton",
                             !.dominatedPaths = ReturnPaths \ {"singleton"}])
    /\ [][UNCHANGED vars]_vars

UnsafeNextBuddyUndominatedSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadNextBuddyUndominated",
                             !.selectedPath = "nextBuddy",
                             !.dominatedPaths = ReturnPaths \ {"nextBuddy"}])
    /\ [][UNCHANGED vars]_vars

UnsafeProtectedCurrentUndominatedSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadProtectedCurrentUndominated",
                             !.selectedPath = "protectedCurrent",
                             !.dominatedPaths = ReturnPaths \ {"protectedCurrent"}])
    /\ [][UNCHANGED vars]_vars

UnsafeLeftmostFunnelUndominatedSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadLeftmostFunnelUndominated",
                             !.selectedPath = "leftmostFunnel",
                             !.dominatedPaths = ReturnPaths \ {"leftmostFunnel"}])
    /\ [][UNCHANGED vars]_vars

UnsafeHeapFunnelUndominatedSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadHeapFunnelUndominated",
                             !.selectedPath = "heapFunnel",
                             !.dominatedPaths = ReturnPaths \ {"heapFunnel"}])
    /\ [][UNCHANGED vars]_vars

UnsafeFinalCurrentOverrideUndominatedSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadFinalCurrentOverrideUndominated",
                             !.selectedPath = "finalCurrentOverride",
                             !.dominatedPaths = ReturnPaths \ {"finalCurrentOverride"}])
    /\ [][UNCHANGED vars]_vars

UnsafeWakeupBleedSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadWakeupBleed",
                             !.schedulePickGated = FALSE,
                             !.wakeupSeparated = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeHotCostBreakageSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadHotCostBreakage",
                             !.hotCostPreserved = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeLineOnlyGateSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadLineOnlyGate",
                             !.symbolShapeChecked = FALSE,
                             !.lineOnlyGate = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeBehaviorOverclaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadBehaviorOverclaim",
                             !.behaviorPatchApproved = TRUE,
                             !.cfsDenyAndRepickApproved = TRUE,
                             !.runtimeCoverageClaim = TRUE,
                             !.productionProtectionClaim = TRUE,
                             !.costEfficiencyClaim = TRUE,
                             !.datacenterReadinessClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeHierarchyOverclaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadHierarchyOverclaim",
                             !.groupHierarchySettlementApproved = TRUE])
    /\ [][UNCHANGED vars]_vars

TypeOK ==
    /\ phase \in Phases
    /\ selectedPath \in PathOrNone
    /\ dominatedPaths \subseteq ReturnPaths
    /\ schedulePickGated \in BOOLEAN
    /\ wakeupSeparated \in BOOLEAN
    /\ hotCostPreserved \in BOOLEAN
    /\ symbolShapeChecked \in BOOLEAN
    /\ lineOnlyGate \in BOOLEAN
    /\ behaviorPatchApproved \in BOOLEAN
    /\ cfsDenyAndRepickApproved \in BOOLEAN
    /\ groupHierarchySettlementApproved \in BOOLEAN
    /\ runtimeCoverageClaim \in BOOLEAN
    /\ productionProtectionClaim \in BOOLEAN
    /\ costEfficiencyClaim \in BOOLEAN
    /\ datacenterReadinessClaim \in BOOLEAN

SelectedPathDominated ==
    selectedPath = NoPath \/ selectedPath \in dominatedPaths

NoWakeupBleed ==
    schedulePickGated /\ wakeupSeparated

NoHotCostBreakage ==
    hotCostPreserved

NoLineOnlyGate ==
    symbolShapeChecked /\ ~lineOnlyGate

NoBehaviorOverclaim ==
    /\ ~behaviorPatchApproved
    /\ ~cfsDenyAndRepickApproved
    /\ ~runtimeCoverageClaim
    /\ ~productionProtectionClaim
    /\ ~costEfficiencyClaim
    /\ ~datacenterReadinessClaim

NoHierarchyOverclaim ==
    ~groupHierarchySettlementApproved

Safety ==
    /\ TypeOK
    /\ SelectedPathDominated
    /\ NoWakeupBleed
    /\ NoHotCostBreakage
    /\ NoLineOnlyGate
    /\ NoBehaviorOverclaim
    /\ NoHierarchyOverclaim

====
