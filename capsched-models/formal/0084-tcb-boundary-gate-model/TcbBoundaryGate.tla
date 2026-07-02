---------- MODULE TcbBoundaryGate ----------
EXTENDS Naturals

VARIABLES
    phase,
    monitorCoreBounded,
    monitorInterfaceTyped,
    monitorOwnsRootsOnly,
    driverInMonitor,
    parserInMonitor,
    policyEngineInMonitor,
    linuxMutableTrustedRoot,
    serviceDomainTypedEndpoint,
    serviceDomainLeastAuthority,
    serviceAmbientAuthority,
    rawHandleExposure,
    tcbBudgetDeclared,
    vmComparisonEnvelope,
    modelSupported,
    implementationClaim,
    productionProtectionClaim,
    costEfficiencyClaim

vars == <<phase, monitorCoreBounded, monitorInterfaceTyped,
          monitorOwnsRootsOnly, driverInMonitor, parserInMonitor,
          policyEngineInMonitor, linuxMutableTrustedRoot,
          serviceDomainTypedEndpoint, serviceDomainLeastAuthority,
          serviceAmbientAuthority, rawHandleExposure, tcbBudgetDeclared,
          vmComparisonEnvelope, modelSupported, implementationClaim,
          productionProtectionClaim, costEfficiencyClaim>>

GoodPhases == {"Start", "TcbBoundaryModeled"}

BadPhases == {
    "BadUnboundedMonitorCore",
    "BadUntypedMonitorInterface",
    "BadMonitorPolicyOrDriver",
    "BadLinuxMutableTrustedRoot",
    "BadServiceDomainAmbientAuthority",
    "BadRawHandleExposure",
    "BadMissingTcbBudget",
    "BadMissingVmComparisonEnvelope",
    "BadImplementationClaim",
    "BadProductionProtectionClaim",
    "BadCostEfficiencyClaim"
}

Phases == GoodPhases \cup BadPhases

MonitorScopeOK ==
    /\ monitorCoreBounded
    /\ monitorInterfaceTyped
    /\ monitorOwnsRootsOnly
    /\ ~driverInMonitor
    /\ ~parserInMonitor
    /\ ~policyEngineInMonitor
    /\ ~linuxMutableTrustedRoot

ServiceScopeOK ==
    /\ serviceDomainTypedEndpoint
    /\ serviceDomainLeastAuthority
    /\ ~serviceAmbientAuthority
    /\ ~rawHandleExposure

MeasurementEnvelopeOK ==
    /\ tcbBudgetDeclared
    /\ vmComparisonEnvelope

TypeOK ==
    /\ phase \in Phases
    /\ monitorCoreBounded \in BOOLEAN
    /\ monitorInterfaceTyped \in BOOLEAN
    /\ monitorOwnsRootsOnly \in BOOLEAN
    /\ driverInMonitor \in BOOLEAN
    /\ parserInMonitor \in BOOLEAN
    /\ policyEngineInMonitor \in BOOLEAN
    /\ linuxMutableTrustedRoot \in BOOLEAN
    /\ serviceDomainTypedEndpoint \in BOOLEAN
    /\ serviceDomainLeastAuthority \in BOOLEAN
    /\ serviceAmbientAuthority \in BOOLEAN
    /\ rawHandleExposure \in BOOLEAN
    /\ tcbBudgetDeclared \in BOOLEAN
    /\ vmComparisonEnvelope \in BOOLEAN
    /\ modelSupported \in BOOLEAN
    /\ implementationClaim \in BOOLEAN
    /\ productionProtectionClaim \in BOOLEAN
    /\ costEfficiencyClaim \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ monitorCoreBounded = FALSE
    /\ monitorInterfaceTyped = FALSE
    /\ monitorOwnsRootsOnly = FALSE
    /\ driverInMonitor = FALSE
    /\ parserInMonitor = FALSE
    /\ policyEngineInMonitor = FALSE
    /\ linuxMutableTrustedRoot = FALSE
    /\ serviceDomainTypedEndpoint = FALSE
    /\ serviceDomainLeastAuthority = FALSE
    /\ serviceAmbientAuthority = FALSE
    /\ rawHandleExposure = FALSE
    /\ tcbBudgetDeclared = FALSE
    /\ vmComparisonEnvelope = FALSE
    /\ modelSupported = FALSE
    /\ implementationClaim = FALSE
    /\ productionProtectionClaim = FALSE
    /\ costEfficiencyClaim = FALSE

ModelTcbBoundary ==
    /\ phase = "Start"
    /\ phase' = "TcbBoundaryModeled"
    /\ monitorCoreBounded' = TRUE
    /\ monitorInterfaceTyped' = TRUE
    /\ monitorOwnsRootsOnly' = TRUE
    /\ driverInMonitor' = FALSE
    /\ parserInMonitor' = FALSE
    /\ policyEngineInMonitor' = FALSE
    /\ linuxMutableTrustedRoot' = FALSE
    /\ serviceDomainTypedEndpoint' = TRUE
    /\ serviceDomainLeastAuthority' = TRUE
    /\ serviceAmbientAuthority' = FALSE
    /\ rawHandleExposure' = FALSE
    /\ tcbBudgetDeclared' = TRUE
    /\ vmComparisonEnvelope' = TRUE
    /\ modelSupported' = TRUE
    /\ UNCHANGED <<implementationClaim, productionProtectionClaim,
                    costEfficiencyClaim>>

TerminalStutter ==
    /\ phase = "TcbBoundaryModeled"
    /\ UNCHANGED vars

SafeNext ==
    \/ ModelTcbBoundary
    \/ TerminalStutter

Unsafe(p) ==
    /\ phase = "Start"
    /\ phase' = p
    /\ monitorCoreBounded' = (p # "BadUnboundedMonitorCore")
    /\ monitorInterfaceTyped' = (p # "BadUntypedMonitorInterface")
    /\ monitorOwnsRootsOnly' = TRUE
    /\ driverInMonitor' = (p = "BadMonitorPolicyOrDriver")
    /\ parserInMonitor' = (p = "BadMonitorPolicyOrDriver")
    /\ policyEngineInMonitor' = (p = "BadMonitorPolicyOrDriver")
    /\ linuxMutableTrustedRoot' = (p = "BadLinuxMutableTrustedRoot")
    /\ serviceDomainTypedEndpoint' = TRUE
    /\ serviceDomainLeastAuthority' = (p # "BadServiceDomainAmbientAuthority")
    /\ serviceAmbientAuthority' = (p = "BadServiceDomainAmbientAuthority")
    /\ rawHandleExposure' = (p = "BadRawHandleExposure")
    /\ tcbBudgetDeclared' = (p # "BadMissingTcbBudget")
    /\ vmComparisonEnvelope' = (p # "BadMissingVmComparisonEnvelope")
    /\ modelSupported' = TRUE
    /\ implementationClaim' = (p = "BadImplementationClaim")
    /\ productionProtectionClaim' = (p = "BadProductionProtectionClaim")
    /\ costEfficiencyClaim' = (p = "BadCostEfficiencyClaim")

NoBadPhase ==
    phase \notin BadPhases

NoModelSupportWithoutMonitorScope ==
    modelSupported => MonitorScopeOK

NoModelSupportWithoutServiceScope ==
    modelSupported => ServiceScopeOK

NoModelSupportWithoutMeasurementEnvelope ==
    modelSupported => MeasurementEnvelopeOK

NoImplementationClaim ==
    ~implementationClaim

NoProductionProtectionClaim ==
    ~productionProtectionClaim

NoCostEfficiencyClaim ==
    ~costEfficiencyClaim

Safety ==
    /\ TypeOK
    /\ NoBadPhase
    /\ NoModelSupportWithoutMonitorScope
    /\ NoModelSupportWithoutServiceScope
    /\ NoModelSupportWithoutMeasurementEnvelope
    /\ NoImplementationClaim
    /\ NoProductionProtectionClaim
    /\ NoCostEfficiencyClaim

Spec ==
    Init /\ [][SafeNext]_vars

UnsafeUnboundedMonitorCoreSpec ==
    Init /\ [][Unsafe("BadUnboundedMonitorCore")]_vars

UnsafeUntypedMonitorInterfaceSpec ==
    Init /\ [][Unsafe("BadUntypedMonitorInterface")]_vars

UnsafeMonitorPolicyOrDriverSpec ==
    Init /\ [][Unsafe("BadMonitorPolicyOrDriver")]_vars

UnsafeLinuxMutableTrustedRootSpec ==
    Init /\ [][Unsafe("BadLinuxMutableTrustedRoot")]_vars

UnsafeServiceDomainAmbientAuthoritySpec ==
    Init /\ [][Unsafe("BadServiceDomainAmbientAuthority")]_vars

UnsafeRawHandleExposureSpec ==
    Init /\ [][Unsafe("BadRawHandleExposure")]_vars

UnsafeMissingTcbBudgetSpec ==
    Init /\ [][Unsafe("BadMissingTcbBudget")]_vars

UnsafeMissingVmComparisonEnvelopeSpec ==
    Init /\ [][Unsafe("BadMissingVmComparisonEnvelope")]_vars

UnsafeImplementationClaimSpec ==
    Init /\ [][Unsafe("BadImplementationClaim")]_vars

UnsafeProductionProtectionClaimSpec ==
    Init /\ [][Unsafe("BadProductionProtectionClaim")]_vars

UnsafeCostEfficiencyClaimSpec ==
    Init /\ [][Unsafe("BadCostEfficiencyClaim")]_vars

=============================================================================
