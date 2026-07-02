---------- MODULE EvaluationContractGate ----------
EXTENDS Naturals

VARIABLES
    phase,
    exploitContainmentContract,
    crossDomainMemoryContract,
    crossDomainDmaContract,
    crossDomainControlContract,
    monitorEscapeContract,
    kvmBaseline,
    firecrackerBaseline,
    containerBaseline,
    workloadEnvelope,
    throughputMetric,
    tailLatencyMetric,
    densityMetric,
    operationalCostMetric,
    securityPassCriteria,
    costPassCriteria,
    negativeResultPolicy,
    microbenchOnly,
    modelSupported,
    productionProtectionClaim,
    costEfficiencyClaim,
    evaluationResultClaim

vars == <<phase, exploitContainmentContract, crossDomainMemoryContract,
          crossDomainDmaContract, crossDomainControlContract,
          monitorEscapeContract, kvmBaseline, firecrackerBaseline,
          containerBaseline, workloadEnvelope, throughputMetric,
          tailLatencyMetric, densityMetric, operationalCostMetric,
          securityPassCriteria, costPassCriteria, negativeResultPolicy,
          microbenchOnly, modelSupported, productionProtectionClaim,
          costEfficiencyClaim, evaluationResultClaim>>

GoodPhases == {"Start", "EvaluationContractModeled"}

BadPhases == {
    "BadMissingExploitContainment",
    "BadMissingCrossDomainMemory",
    "BadMissingCrossDomainDma",
    "BadMissingCrossDomainControl",
    "BadMissingMonitorEscape",
    "BadMissingKvmBaseline",
    "BadMissingFirecrackerBaseline",
    "BadMissingContainerBaseline",
    "BadMissingWorkloadEnvelope",
    "BadMissingThroughput",
    "BadMissingTailLatency",
    "BadMissingDensity",
    "BadMissingOperationalCost",
    "BadMissingSecurityPassCriteria",
    "BadMissingCostPassCriteria",
    "BadMissingNegativeResultPolicy",
    "BadMicrobenchOnly",
    "BadProtectionClaimFromContract",
    "BadCostClaimFromContract",
    "BadEvaluationResultClaimFromContract"
}

Phases == GoodPhases \cup BadPhases

SecurityContractOK ==
    /\ exploitContainmentContract
    /\ crossDomainMemoryContract
    /\ crossDomainDmaContract
    /\ crossDomainControlContract
    /\ monitorEscapeContract
    /\ securityPassCriteria
    /\ negativeResultPolicy

CostContractOK ==
    /\ kvmBaseline
    /\ firecrackerBaseline
    /\ containerBaseline
    /\ workloadEnvelope
    /\ throughputMetric
    /\ tailLatencyMetric
    /\ densityMetric
    /\ operationalCostMetric
    /\ costPassCriteria
    /\ ~microbenchOnly

TypeOK ==
    /\ phase \in Phases
    /\ exploitContainmentContract \in BOOLEAN
    /\ crossDomainMemoryContract \in BOOLEAN
    /\ crossDomainDmaContract \in BOOLEAN
    /\ crossDomainControlContract \in BOOLEAN
    /\ monitorEscapeContract \in BOOLEAN
    /\ kvmBaseline \in BOOLEAN
    /\ firecrackerBaseline \in BOOLEAN
    /\ containerBaseline \in BOOLEAN
    /\ workloadEnvelope \in BOOLEAN
    /\ throughputMetric \in BOOLEAN
    /\ tailLatencyMetric \in BOOLEAN
    /\ densityMetric \in BOOLEAN
    /\ operationalCostMetric \in BOOLEAN
    /\ securityPassCriteria \in BOOLEAN
    /\ costPassCriteria \in BOOLEAN
    /\ negativeResultPolicy \in BOOLEAN
    /\ microbenchOnly \in BOOLEAN
    /\ modelSupported \in BOOLEAN
    /\ productionProtectionClaim \in BOOLEAN
    /\ costEfficiencyClaim \in BOOLEAN
    /\ evaluationResultClaim \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ exploitContainmentContract = FALSE
    /\ crossDomainMemoryContract = FALSE
    /\ crossDomainDmaContract = FALSE
    /\ crossDomainControlContract = FALSE
    /\ monitorEscapeContract = FALSE
    /\ kvmBaseline = FALSE
    /\ firecrackerBaseline = FALSE
    /\ containerBaseline = FALSE
    /\ workloadEnvelope = FALSE
    /\ throughputMetric = FALSE
    /\ tailLatencyMetric = FALSE
    /\ densityMetric = FALSE
    /\ operationalCostMetric = FALSE
    /\ securityPassCriteria = FALSE
    /\ costPassCriteria = FALSE
    /\ negativeResultPolicy = FALSE
    /\ microbenchOnly = FALSE
    /\ modelSupported = FALSE
    /\ productionProtectionClaim = FALSE
    /\ costEfficiencyClaim = FALSE
    /\ evaluationResultClaim = FALSE

ModelEvaluationContract ==
    /\ phase = "Start"
    /\ phase' = "EvaluationContractModeled"
    /\ exploitContainmentContract' = TRUE
    /\ crossDomainMemoryContract' = TRUE
    /\ crossDomainDmaContract' = TRUE
    /\ crossDomainControlContract' = TRUE
    /\ monitorEscapeContract' = TRUE
    /\ kvmBaseline' = TRUE
    /\ firecrackerBaseline' = TRUE
    /\ containerBaseline' = TRUE
    /\ workloadEnvelope' = TRUE
    /\ throughputMetric' = TRUE
    /\ tailLatencyMetric' = TRUE
    /\ densityMetric' = TRUE
    /\ operationalCostMetric' = TRUE
    /\ securityPassCriteria' = TRUE
    /\ costPassCriteria' = TRUE
    /\ negativeResultPolicy' = TRUE
    /\ microbenchOnly' = FALSE
    /\ modelSupported' = TRUE
    /\ UNCHANGED <<productionProtectionClaim, costEfficiencyClaim,
                    evaluationResultClaim>>

TerminalStutter ==
    /\ phase = "EvaluationContractModeled"
    /\ UNCHANGED vars

SafeNext ==
    \/ ModelEvaluationContract
    \/ TerminalStutter

Unsafe(p) ==
    /\ phase = "Start"
    /\ phase' = p
    /\ exploitContainmentContract' = (p # "BadMissingExploitContainment")
    /\ crossDomainMemoryContract' = (p # "BadMissingCrossDomainMemory")
    /\ crossDomainDmaContract' = (p # "BadMissingCrossDomainDma")
    /\ crossDomainControlContract' = (p # "BadMissingCrossDomainControl")
    /\ monitorEscapeContract' = (p # "BadMissingMonitorEscape")
    /\ kvmBaseline' = (p # "BadMissingKvmBaseline")
    /\ firecrackerBaseline' = (p # "BadMissingFirecrackerBaseline")
    /\ containerBaseline' = (p # "BadMissingContainerBaseline")
    /\ workloadEnvelope' = (p # "BadMissingWorkloadEnvelope")
    /\ throughputMetric' = (p # "BadMissingThroughput")
    /\ tailLatencyMetric' = (p # "BadMissingTailLatency")
    /\ densityMetric' = (p # "BadMissingDensity")
    /\ operationalCostMetric' = (p # "BadMissingOperationalCost")
    /\ securityPassCriteria' = (p # "BadMissingSecurityPassCriteria")
    /\ costPassCriteria' = (p # "BadMissingCostPassCriteria")
    /\ negativeResultPolicy' = (p # "BadMissingNegativeResultPolicy")
    /\ microbenchOnly' = (p = "BadMicrobenchOnly")
    /\ modelSupported' = TRUE
    /\ productionProtectionClaim' = (p = "BadProtectionClaimFromContract")
    /\ costEfficiencyClaim' = (p = "BadCostClaimFromContract")
    /\ evaluationResultClaim' = (p = "BadEvaluationResultClaimFromContract")

NoBadPhase ==
    phase \notin BadPhases

NoModelSupportWithoutSecurityContract ==
    modelSupported => SecurityContractOK

NoModelSupportWithoutCostContract ==
    modelSupported => CostContractOK

NoProductionProtectionClaim ==
    ~productionProtectionClaim

NoCostEfficiencyClaim ==
    ~costEfficiencyClaim

NoEvaluationResultClaim ==
    ~evaluationResultClaim

Safety ==
    /\ TypeOK
    /\ NoBadPhase
    /\ NoModelSupportWithoutSecurityContract
    /\ NoModelSupportWithoutCostContract
    /\ NoProductionProtectionClaim
    /\ NoCostEfficiencyClaim
    /\ NoEvaluationResultClaim

Spec ==
    Init /\ [][SafeNext]_vars

UnsafeMissingExploitContainmentSpec ==
    Init /\ [][Unsafe("BadMissingExploitContainment")]_vars

UnsafeMissingCrossDomainMemorySpec ==
    Init /\ [][Unsafe("BadMissingCrossDomainMemory")]_vars

UnsafeMissingCrossDomainDmaSpec ==
    Init /\ [][Unsafe("BadMissingCrossDomainDma")]_vars

UnsafeMissingCrossDomainControlSpec ==
    Init /\ [][Unsafe("BadMissingCrossDomainControl")]_vars

UnsafeMissingMonitorEscapeSpec ==
    Init /\ [][Unsafe("BadMissingMonitorEscape")]_vars

UnsafeMissingKvmBaselineSpec ==
    Init /\ [][Unsafe("BadMissingKvmBaseline")]_vars

UnsafeMissingFirecrackerBaselineSpec ==
    Init /\ [][Unsafe("BadMissingFirecrackerBaseline")]_vars

UnsafeMissingContainerBaselineSpec ==
    Init /\ [][Unsafe("BadMissingContainerBaseline")]_vars

UnsafeMissingWorkloadEnvelopeSpec ==
    Init /\ [][Unsafe("BadMissingWorkloadEnvelope")]_vars

UnsafeMissingThroughputSpec ==
    Init /\ [][Unsafe("BadMissingThroughput")]_vars

UnsafeMissingTailLatencySpec ==
    Init /\ [][Unsafe("BadMissingTailLatency")]_vars

UnsafeMissingDensitySpec ==
    Init /\ [][Unsafe("BadMissingDensity")]_vars

UnsafeMissingOperationalCostSpec ==
    Init /\ [][Unsafe("BadMissingOperationalCost")]_vars

UnsafeMissingSecurityPassCriteriaSpec ==
    Init /\ [][Unsafe("BadMissingSecurityPassCriteria")]_vars

UnsafeMissingCostPassCriteriaSpec ==
    Init /\ [][Unsafe("BadMissingCostPassCriteria")]_vars

UnsafeMissingNegativeResultPolicySpec ==
    Init /\ [][Unsafe("BadMissingNegativeResultPolicy")]_vars

UnsafeMicrobenchOnlySpec ==
    Init /\ [][Unsafe("BadMicrobenchOnly")]_vars

UnsafeProtectionClaimFromContractSpec ==
    Init /\ [][Unsafe("BadProtectionClaimFromContract")]_vars

UnsafeCostClaimFromContractSpec ==
    Init /\ [][Unsafe("BadCostClaimFromContract")]_vars

UnsafeEvaluationResultClaimFromContractSpec ==
    Init /\ [][Unsafe("BadEvaluationResultClaimFromContract")]_vars

=============================================================================
