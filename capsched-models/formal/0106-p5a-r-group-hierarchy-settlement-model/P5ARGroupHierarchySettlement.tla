---------- MODULE P5ARGroupHierarchySettlement ----------
EXTENDS Naturals

VARIABLES
    phase,
    selectedGroup,
    leafDenied,
    pathDenied,
    allowedSiblingExists,
    childExhausted,
    parentSkipped,
    parentSkipJustified,
    sameDeniedLeafRepicked,
    taskOfGroupEntity,
    childExhaustionSource,
    pathEvidenceAsAuthority,
    coreDlProxyScxSettledOrExcluded,
    behaviorPatchApproved,
    cfsDenyAndRepickApproved,
    runtimeCoverageClaim,
    productionProtectionClaim,
    costEfficiencyClaim,
    datacenterReadinessClaim

vars == <<phase, selectedGroup, leafDenied, pathDenied, allowedSiblingExists,
          childExhausted, parentSkipped, parentSkipJustified,
          sameDeniedLeafRepicked, taskOfGroupEntity, childExhaustionSource,
          pathEvidenceAsAuthority, coreDlProxyScxSettledOrExcluded,
          behaviorPatchApproved, cfsDenyAndRepickApproved,
          runtimeCoverageClaim, productionProtectionClaim,
          costEfficiencyClaim, datacenterReadinessClaim>>

Phases == {
    "Start",
    "GroupSelected",
    "LeafDenied",
    "SiblingPicked",
    "ChildExhausted",
    "ParentSkipJustified",
    "BadParentOverDenied",
    "BadSkipWithoutExhaustion",
    "BadSameDeniedLeafRepicked",
    "BadTaskOfGroupEntity",
    "BadNrQueuedAlias",
    "BadSleepAlias",
    "BadThrottleAlias",
    "BadDelayedDequeueAlias",
    "BadYieldAlias",
    "BadEevdfLagAlias",
    "BadPathEvidenceAuthority",
    "BadCrossPathOverclaim",
    "BadBehaviorOverclaim"
}

ExhaustionSources == {
    "none",
    "explicit_supported_descendant_exhaustion",
    "nr_queued_zero",
    "sleep",
    "throttle",
    "delayed_dequeue",
    "yield",
    "eevdf_lag"
}

Base ==
    [ phase |-> "Start",
      selectedGroup |-> FALSE,
      leafDenied |-> FALSE,
      pathDenied |-> FALSE,
      allowedSiblingExists |-> TRUE,
      childExhausted |-> FALSE,
      parentSkipped |-> FALSE,
      parentSkipJustified |-> FALSE,
      sameDeniedLeafRepicked |-> FALSE,
      taskOfGroupEntity |-> FALSE,
      childExhaustionSource |-> "none",
      pathEvidenceAsAuthority |-> FALSE,
      coreDlProxyScxSettledOrExcluded |-> FALSE,
      behaviorPatchApproved |-> FALSE,
      cfsDenyAndRepickApproved |-> FALSE,
      runtimeCoverageClaim |-> FALSE,
      productionProtectionClaim |-> FALSE,
      costEfficiencyClaim |-> FALSE,
      datacenterReadinessClaim |-> FALSE ]

SetState(s) ==
    /\ phase = s.phase
    /\ selectedGroup = s.selectedGroup
    /\ leafDenied = s.leafDenied
    /\ pathDenied = s.pathDenied
    /\ allowedSiblingExists = s.allowedSiblingExists
    /\ childExhausted = s.childExhausted
    /\ parentSkipped = s.parentSkipped
    /\ parentSkipJustified = s.parentSkipJustified
    /\ sameDeniedLeafRepicked = s.sameDeniedLeafRepicked
    /\ taskOfGroupEntity = s.taskOfGroupEntity
    /\ childExhaustionSource = s.childExhaustionSource
    /\ pathEvidenceAsAuthority = s.pathEvidenceAsAuthority
    /\ coreDlProxyScxSettledOrExcluded = s.coreDlProxyScxSettledOrExcluded
    /\ behaviorPatchApproved = s.behaviorPatchApproved
    /\ cfsDenyAndRepickApproved = s.cfsDenyAndRepickApproved
    /\ runtimeCoverageClaim = s.runtimeCoverageClaim
    /\ productionProtectionClaim = s.productionProtectionClaim
    /\ costEfficiencyClaim = s.costEfficiencyClaim
    /\ datacenterReadinessClaim = s.datacenterReadinessClaim

Init == SetState(Base)

SelectGroup ==
    /\ phase = "Start"
    /\ selectedGroup' = TRUE
    /\ phase' = "GroupSelected"
    /\ UNCHANGED <<leafDenied, pathDenied, allowedSiblingExists,
                    childExhausted, parentSkipped, parentSkipJustified,
                    sameDeniedLeafRepicked, taskOfGroupEntity,
                    childExhaustionSource, pathEvidenceAsAuthority,
                    coreDlProxyScxSettledOrExcluded, behaviorPatchApproved,
                    cfsDenyAndRepickApproved, runtimeCoverageClaim,
                    productionProtectionClaim, costEfficiencyClaim,
                    datacenterReadinessClaim>>

DenyLeaf ==
    /\ phase = "GroupSelected"
    /\ selectedGroup
    /\ leafDenied' = TRUE
    /\ pathDenied' = TRUE
    /\ allowedSiblingExists' \in BOOLEAN
    /\ phase' = "LeafDenied"
    /\ UNCHANGED <<selectedGroup, childExhausted,
                    parentSkipped, parentSkipJustified,
                    sameDeniedLeafRepicked, taskOfGroupEntity,
                    childExhaustionSource, pathEvidenceAsAuthority,
                    coreDlProxyScxSettledOrExcluded, behaviorPatchApproved,
                    cfsDenyAndRepickApproved, runtimeCoverageClaim,
                    productionProtectionClaim, costEfficiencyClaim,
                    datacenterReadinessClaim>>

PickAllowedSibling ==
    /\ phase = "LeafDenied"
    /\ leafDenied
    /\ allowedSiblingExists
    /\ ~parentSkipped
    /\ phase' = "SiblingPicked"
    /\ UNCHANGED <<selectedGroup, leafDenied, pathDenied,
                    allowedSiblingExists, childExhausted, parentSkipped,
                    parentSkipJustified, sameDeniedLeafRepicked,
                    taskOfGroupEntity, childExhaustionSource,
                    pathEvidenceAsAuthority, coreDlProxyScxSettledOrExcluded,
                    behaviorPatchApproved, cfsDenyAndRepickApproved,
                    runtimeCoverageClaim, productionProtectionClaim,
                    costEfficiencyClaim, datacenterReadinessClaim>>

ProveChildExhausted ==
    /\ phase = "LeafDenied"
    /\ leafDenied
    /\ ~allowedSiblingExists
    /\ childExhausted' = TRUE
    /\ childExhaustionSource' = "explicit_supported_descendant_exhaustion"
    /\ phase' = "ChildExhausted"
    /\ UNCHANGED <<selectedGroup, leafDenied, pathDenied,
                    allowedSiblingExists, parentSkipped, parentSkipJustified,
                    sameDeniedLeafRepicked, taskOfGroupEntity,
                    pathEvidenceAsAuthority, coreDlProxyScxSettledOrExcluded,
                    behaviorPatchApproved, cfsDenyAndRepickApproved,
                    runtimeCoverageClaim, productionProtectionClaim,
                    costEfficiencyClaim, datacenterReadinessClaim>>

JustifyParentSkip ==
    /\ phase = "ChildExhausted"
    /\ childExhausted
    /\ childExhaustionSource = "explicit_supported_descendant_exhaustion"
    /\ ~allowedSiblingExists
    /\ parentSkipped' = TRUE
    /\ parentSkipJustified' = TRUE
    /\ phase' = "ParentSkipJustified"
    /\ UNCHANGED <<selectedGroup, leafDenied, pathDenied,
                    allowedSiblingExists, childExhausted,
                    sameDeniedLeafRepicked, taskOfGroupEntity,
                    childExhaustionSource, pathEvidenceAsAuthority,
                    coreDlProxyScxSettledOrExcluded, behaviorPatchApproved,
                    cfsDenyAndRepickApproved, runtimeCoverageClaim,
                    productionProtectionClaim, costEfficiencyClaim,
                    datacenterReadinessClaim>>

StutterDone ==
    /\ phase \in {"SiblingPicked", "ParentSkipJustified"}
    /\ UNCHANGED vars

Next ==
    \/ SelectGroup
    \/ DenyLeaf
    \/ PickAllowedSibling
    \/ ProveChildExhausted
    \/ JustifyParentSkip
    \/ StutterDone

SafeSpec == Init /\ [][Next]_vars

UnsafeParentOverDeniedSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadParentOverDenied",
                             !.selectedGroup = TRUE,
                             !.leafDenied = TRUE,
                             !.allowedSiblingExists = TRUE,
                             !.parentSkipped = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeSkipWithoutExhaustionSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadSkipWithoutExhaustion",
                             !.selectedGroup = TRUE,
                             !.leafDenied = TRUE,
                             !.childExhausted = FALSE,
                             !.parentSkipped = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeSameDeniedLeafRepickedSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadSameDeniedLeafRepicked",
                             !.leafDenied = TRUE,
                             !.sameDeniedLeafRepicked = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeTaskOfGroupEntitySpec ==
    /\ SetState([Base EXCEPT !.phase = "BadTaskOfGroupEntity",
                             !.selectedGroup = TRUE,
                             !.taskOfGroupEntity = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeNrQueuedAliasSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadNrQueuedAlias",
                             !.childExhausted = TRUE,
                             !.childExhaustionSource = "nr_queued_zero"])
    /\ [][UNCHANGED vars]_vars

UnsafeSleepAliasSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadSleepAlias",
                             !.childExhausted = TRUE,
                             !.childExhaustionSource = "sleep"])
    /\ [][UNCHANGED vars]_vars

UnsafeThrottleAliasSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadThrottleAlias",
                             !.childExhausted = TRUE,
                             !.childExhaustionSource = "throttle"])
    /\ [][UNCHANGED vars]_vars

UnsafeDelayedDequeueAliasSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadDelayedDequeueAlias",
                             !.childExhausted = TRUE,
                             !.childExhaustionSource = "delayed_dequeue"])
    /\ [][UNCHANGED vars]_vars

UnsafeYieldAliasSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadYieldAlias",
                             !.childExhausted = TRUE,
                             !.childExhaustionSource = "yield"])
    /\ [][UNCHANGED vars]_vars

UnsafeEevdfLagAliasSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadEevdfLagAlias",
                             !.childExhausted = TRUE,
                             !.childExhaustionSource = "eevdf_lag"])
    /\ [][UNCHANGED vars]_vars

UnsafePathEvidenceAuthoritySpec ==
    /\ SetState([Base EXCEPT !.phase = "BadPathEvidenceAuthority",
                             !.pathDenied = TRUE,
                             !.pathEvidenceAsAuthority = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeCrossPathOverclaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadCrossPathOverclaim",
                             !.coreDlProxyScxSettledOrExcluded = TRUE])
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

TypeOK ==
    /\ phase \in Phases
    /\ selectedGroup \in BOOLEAN
    /\ leafDenied \in BOOLEAN
    /\ pathDenied \in BOOLEAN
    /\ allowedSiblingExists \in BOOLEAN
    /\ childExhausted \in BOOLEAN
    /\ parentSkipped \in BOOLEAN
    /\ parentSkipJustified \in BOOLEAN
    /\ sameDeniedLeafRepicked \in BOOLEAN
    /\ taskOfGroupEntity \in BOOLEAN
    /\ childExhaustionSource \in ExhaustionSources
    /\ pathEvidenceAsAuthority \in BOOLEAN
    /\ coreDlProxyScxSettledOrExcluded \in BOOLEAN
    /\ behaviorPatchApproved \in BOOLEAN
    /\ cfsDenyAndRepickApproved \in BOOLEAN
    /\ runtimeCoverageClaim \in BOOLEAN
    /\ productionProtectionClaim \in BOOLEAN
    /\ costEfficiencyClaim \in BOOLEAN
    /\ datacenterReadinessClaim \in BOOLEAN

NoParentOverDenied ==
    ~(parentSkipped /\ allowedSiblingExists)

ParentSkipRequiresChildExhaustion ==
    parentSkipped => (childExhausted /\ parentSkipJustified)

NoSameDeniedLeafRepicked ==
    ~sameDeniedLeafRepicked

NoTaskOfGroupEntity ==
    ~taskOfGroupEntity

NoAccountingAliasExhaustion ==
    childExhausted => childExhaustionSource = "explicit_supported_descendant_exhaustion"

NoPathEvidenceAuthority ==
    ~pathEvidenceAsAuthority

NoCrossPathOverclaim ==
    ~coreDlProxyScxSettledOrExcluded

NoBehaviorOverclaim ==
    /\ ~behaviorPatchApproved
    /\ ~cfsDenyAndRepickApproved
    /\ ~runtimeCoverageClaim
    /\ ~productionProtectionClaim
    /\ ~costEfficiencyClaim
    /\ ~datacenterReadinessClaim

Safety ==
    /\ TypeOK
    /\ NoParentOverDenied
    /\ ParentSkipRequiresChildExhaustion
    /\ NoSameDeniedLeafRepicked
    /\ NoTaskOfGroupEntity
    /\ NoAccountingAliasExhaustion
    /\ NoPathEvidenceAuthority
    /\ NoCrossPathOverclaim
    /\ NoBehaviorOverclaim

====
