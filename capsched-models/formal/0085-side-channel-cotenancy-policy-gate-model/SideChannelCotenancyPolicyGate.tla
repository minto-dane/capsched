---------- MODULE SideChannelCotenancyPolicyGate ----------
EXTENDS Naturals

VARIABLES
    phase,
    policyKnown,
    leakageClassified,
    hardBoundaryPreserved,
    monitorBindingPreserved,
    schedulerRespectsPolicy,
    smtShareAllowed,
    smtPolicyExplicit,
    coreShareAllowed,
    corePolicyExplicit,
    cacheShareAllowed,
    cachePolicyExplicit,
    numaShareAllowed,
    numaPolicyExplicit,
    deviceQueueShareAllowed,
    deviceQueuePolicyExplicit,
    clusterPlacementAllowed,
    clusterPolicyExplicit,
    performanceOverride,
    sidePolicyAsAuthorityRoot,
    modelSupported,
    productionProtectionClaim,
    costEfficiencyClaim

vars == <<phase, policyKnown, leakageClassified, hardBoundaryPreserved,
          monitorBindingPreserved, schedulerRespectsPolicy, smtShareAllowed,
          smtPolicyExplicit, coreShareAllowed, corePolicyExplicit,
          cacheShareAllowed, cachePolicyExplicit, numaShareAllowed,
          numaPolicyExplicit, deviceQueueShareAllowed,
          deviceQueuePolicyExplicit, clusterPlacementAllowed,
          clusterPolicyExplicit, performanceOverride,
          sidePolicyAsAuthorityRoot, modelSupported, productionProtectionClaim,
          costEfficiencyClaim>>

GoodPhases == {"Start", "SidePolicyModeled"}

BadPhases == {
    "BadUnknownPolicyDefaultsAllow",
    "BadSmtWithoutPolicy",
    "BadCoreWithoutPolicy",
    "BadCacheWithoutPolicy",
    "BadNumaWithoutPolicy",
    "BadDeviceQueueWithoutPolicy",
    "BadClusterPlacementWithoutPolicy",
    "BadPerformanceOverridesIsolation",
    "BadSidePolicyWeakensHardBoundary",
    "BadSchedulerIgnoresSidePolicy",
    "BadMonitorBindingMissing",
    "BadLeakageUnclassified",
    "BadSidePolicyAsAuthorityRoot",
    "BadProductionProtectionClaim",
    "BadCostEfficiencyClaim"
}

Phases == GoodPhases \cup BadPhases

ExplicitIfAllowed ==
    /\ (smtShareAllowed => smtPolicyExplicit)
    /\ (coreShareAllowed => corePolicyExplicit)
    /\ (cacheShareAllowed => cachePolicyExplicit)
    /\ (numaShareAllowed => numaPolicyExplicit)
    /\ (deviceQueueShareAllowed => deviceQueuePolicyExplicit)
    /\ (clusterPlacementAllowed => clusterPolicyExplicit)

TypeOK ==
    /\ phase \in Phases
    /\ policyKnown \in BOOLEAN
    /\ leakageClassified \in BOOLEAN
    /\ hardBoundaryPreserved \in BOOLEAN
    /\ monitorBindingPreserved \in BOOLEAN
    /\ schedulerRespectsPolicy \in BOOLEAN
    /\ smtShareAllowed \in BOOLEAN
    /\ smtPolicyExplicit \in BOOLEAN
    /\ coreShareAllowed \in BOOLEAN
    /\ corePolicyExplicit \in BOOLEAN
    /\ cacheShareAllowed \in BOOLEAN
    /\ cachePolicyExplicit \in BOOLEAN
    /\ numaShareAllowed \in BOOLEAN
    /\ numaPolicyExplicit \in BOOLEAN
    /\ deviceQueueShareAllowed \in BOOLEAN
    /\ deviceQueuePolicyExplicit \in BOOLEAN
    /\ clusterPlacementAllowed \in BOOLEAN
    /\ clusterPolicyExplicit \in BOOLEAN
    /\ performanceOverride \in BOOLEAN
    /\ sidePolicyAsAuthorityRoot \in BOOLEAN
    /\ modelSupported \in BOOLEAN
    /\ productionProtectionClaim \in BOOLEAN
    /\ costEfficiencyClaim \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ policyKnown = FALSE
    /\ leakageClassified = FALSE
    /\ hardBoundaryPreserved = FALSE
    /\ monitorBindingPreserved = FALSE
    /\ schedulerRespectsPolicy = FALSE
    /\ smtShareAllowed = FALSE
    /\ smtPolicyExplicit = FALSE
    /\ coreShareAllowed = FALSE
    /\ corePolicyExplicit = FALSE
    /\ cacheShareAllowed = FALSE
    /\ cachePolicyExplicit = FALSE
    /\ numaShareAllowed = FALSE
    /\ numaPolicyExplicit = FALSE
    /\ deviceQueueShareAllowed = FALSE
    /\ deviceQueuePolicyExplicit = FALSE
    /\ clusterPlacementAllowed = FALSE
    /\ clusterPolicyExplicit = FALSE
    /\ performanceOverride = FALSE
    /\ sidePolicyAsAuthorityRoot = FALSE
    /\ modelSupported = FALSE
    /\ productionProtectionClaim = FALSE
    /\ costEfficiencyClaim = FALSE

ModelSidePolicy ==
    /\ phase = "Start"
    /\ phase' = "SidePolicyModeled"
    /\ policyKnown' = TRUE
    /\ leakageClassified' = TRUE
    /\ hardBoundaryPreserved' = TRUE
    /\ monitorBindingPreserved' = TRUE
    /\ schedulerRespectsPolicy' = TRUE
    /\ smtShareAllowed' = TRUE
    /\ smtPolicyExplicit' = TRUE
    /\ coreShareAllowed' = TRUE
    /\ corePolicyExplicit' = TRUE
    /\ cacheShareAllowed' = TRUE
    /\ cachePolicyExplicit' = TRUE
    /\ numaShareAllowed' = TRUE
    /\ numaPolicyExplicit' = TRUE
    /\ deviceQueueShareAllowed' = TRUE
    /\ deviceQueuePolicyExplicit' = TRUE
    /\ clusterPlacementAllowed' = TRUE
    /\ clusterPolicyExplicit' = TRUE
    /\ performanceOverride' = FALSE
    /\ sidePolicyAsAuthorityRoot' = FALSE
    /\ modelSupported' = TRUE
    /\ UNCHANGED <<productionProtectionClaim, costEfficiencyClaim>>

TerminalStutter ==
    /\ phase = "SidePolicyModeled"
    /\ UNCHANGED vars

SafeNext ==
    \/ ModelSidePolicy
    \/ TerminalStutter

Unsafe(p) ==
    /\ phase = "Start"
    /\ phase' = p
    /\ policyKnown' = (p # "BadUnknownPolicyDefaultsAllow")
    /\ leakageClassified' = (p # "BadLeakageUnclassified")
    /\ hardBoundaryPreserved' = (p # "BadSidePolicyWeakensHardBoundary")
    /\ monitorBindingPreserved' = (p # "BadMonitorBindingMissing")
    /\ schedulerRespectsPolicy' = (p # "BadSchedulerIgnoresSidePolicy")
    /\ smtShareAllowed' = TRUE
    /\ smtPolicyExplicit' = (p # "BadSmtWithoutPolicy")
    /\ coreShareAllowed' = TRUE
    /\ corePolicyExplicit' = (p # "BadCoreWithoutPolicy")
    /\ cacheShareAllowed' = TRUE
    /\ cachePolicyExplicit' = (p # "BadCacheWithoutPolicy")
    /\ numaShareAllowed' = TRUE
    /\ numaPolicyExplicit' = (p # "BadNumaWithoutPolicy")
    /\ deviceQueueShareAllowed' = TRUE
    /\ deviceQueuePolicyExplicit' = (p # "BadDeviceQueueWithoutPolicy")
    /\ clusterPlacementAllowed' = TRUE
    /\ clusterPolicyExplicit' = (p # "BadClusterPlacementWithoutPolicy")
    /\ performanceOverride' = (p = "BadPerformanceOverridesIsolation")
    /\ sidePolicyAsAuthorityRoot' = (p = "BadSidePolicyAsAuthorityRoot")
    /\ modelSupported' = TRUE
    /\ productionProtectionClaim' = (p = "BadProductionProtectionClaim")
    /\ costEfficiencyClaim' = (p = "BadCostEfficiencyClaim")

NoBadPhase ==
    phase \notin BadPhases

NoModelSupportWithoutKnownPolicy ==
    modelSupported => policyKnown

NoModelSupportWithoutLeakageClassification ==
    modelSupported => leakageClassified

NoImplicitSharing ==
    modelSupported => ExplicitIfAllowed

NoPerformanceOverride ==
    ~performanceOverride

NoSidePolicyWeakensHardBoundary ==
    modelSupported => /\ hardBoundaryPreserved /\ monitorBindingPreserved

NoSchedulerBypass ==
    modelSupported => schedulerRespectsPolicy

NoSidePolicyAsAuthorityRoot ==
    ~sidePolicyAsAuthorityRoot

NoProductionProtectionClaim ==
    ~productionProtectionClaim

NoCostEfficiencyClaim ==
    ~costEfficiencyClaim

Safety ==
    /\ TypeOK
    /\ NoBadPhase
    /\ NoModelSupportWithoutKnownPolicy
    /\ NoModelSupportWithoutLeakageClassification
    /\ NoImplicitSharing
    /\ NoPerformanceOverride
    /\ NoSidePolicyWeakensHardBoundary
    /\ NoSchedulerBypass
    /\ NoSidePolicyAsAuthorityRoot
    /\ NoProductionProtectionClaim
    /\ NoCostEfficiencyClaim

Spec ==
    Init /\ [][SafeNext]_vars

UnsafeUnknownPolicyDefaultsAllowSpec ==
    Init /\ [][Unsafe("BadUnknownPolicyDefaultsAllow")]_vars

UnsafeSmtWithoutPolicySpec ==
    Init /\ [][Unsafe("BadSmtWithoutPolicy")]_vars

UnsafeCoreWithoutPolicySpec ==
    Init /\ [][Unsafe("BadCoreWithoutPolicy")]_vars

UnsafeCacheWithoutPolicySpec ==
    Init /\ [][Unsafe("BadCacheWithoutPolicy")]_vars

UnsafeNumaWithoutPolicySpec ==
    Init /\ [][Unsafe("BadNumaWithoutPolicy")]_vars

UnsafeDeviceQueueWithoutPolicySpec ==
    Init /\ [][Unsafe("BadDeviceQueueWithoutPolicy")]_vars

UnsafeClusterPlacementWithoutPolicySpec ==
    Init /\ [][Unsafe("BadClusterPlacementWithoutPolicy")]_vars

UnsafePerformanceOverridesIsolationSpec ==
    Init /\ [][Unsafe("BadPerformanceOverridesIsolation")]_vars

UnsafeSidePolicyWeakensHardBoundarySpec ==
    Init /\ [][Unsafe("BadSidePolicyWeakensHardBoundary")]_vars

UnsafeSchedulerIgnoresSidePolicySpec ==
    Init /\ [][Unsafe("BadSchedulerIgnoresSidePolicy")]_vars

UnsafeMonitorBindingMissingSpec ==
    Init /\ [][Unsafe("BadMonitorBindingMissing")]_vars

UnsafeLeakageUnclassifiedSpec ==
    Init /\ [][Unsafe("BadLeakageUnclassified")]_vars

UnsafeSidePolicyAsAuthorityRootSpec ==
    Init /\ [][Unsafe("BadSidePolicyAsAuthorityRoot")]_vars

UnsafeProductionProtectionClaimSpec ==
    Init /\ [][Unsafe("BadProductionProtectionClaim")]_vars

UnsafeCostEfficiencyClaimSpec ==
    Init /\ [][Unsafe("BadCostEfficiencyClaim")]_vars

=============================================================================
