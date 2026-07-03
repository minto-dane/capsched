---------- MODULE P5ARNegativeValidationPlan ----------
EXTENDS Naturals

VARIABLES
    phase,
    lateDenialTest,
    deniedNotCurrTest,
    sameCandidateRepickTest,
    retryVisibilityTest,
    idleFallbackTest,
    eevdfFamilyTests,
    groupHierarchyTests,
    childExhaustionAliasTests,
    crossPathTests,
    staleIdentityTests,
    wakeupBleedTests,
    newidleLeakTests,
    overheadLayoutTests,
    claimOverreachTests,
    requiredObservables,
    validationLayers,
    behaviorPatchApproved,
    testInstrumentationApproved,
    runtimeDenialApproved,
    runtimeCoverageClaim,
    productionProtectionClaim,
    costEfficiencyClaim,
    datacenterReadinessClaim

vars == <<phase, lateDenialTest, deniedNotCurrTest, sameCandidateRepickTest,
          retryVisibilityTest, idleFallbackTest, eevdfFamilyTests,
          groupHierarchyTests, childExhaustionAliasTests, crossPathTests,
          staleIdentityTests, wakeupBleedTests, newidleLeakTests,
          overheadLayoutTests, claimOverreachTests, requiredObservables,
          validationLayers, behaviorPatchApproved, testInstrumentationApproved,
          runtimeDenialApproved, runtimeCoverageClaim, productionProtectionClaim,
          costEfficiencyClaim, datacenterReadinessClaim>>

Phases == {
    "Start",
    "CoreNegativeTestsRecorded",
    "PathNegativeTestsRecorded",
    "ObservableLayersRecorded",
    "PlanRecorded",
    "BadMissingLateDenial",
    "BadMissingDeniedNotCurr",
    "BadMissingSameCandidate",
    "BadMissingRetryVisibility",
    "BadMissingIdleFallback",
    "BadMissingEevdf",
    "BadMissingGroupHierarchy",
    "BadMissingChildAlias",
    "BadMissingCrossPath",
    "BadMissingStaleIdentity",
    "BadMissingWakeupNewidle",
    "BadMissingOverhead",
    "BadMissingObservables",
    "BadMissingLayers",
    "BadBehaviorBeforePlan",
    "BadRuntimeClaim",
    "BadCostProtectionClaim"
}

Base ==
    [ phase |-> "Start",
      lateDenialTest |-> FALSE,
      deniedNotCurrTest |-> FALSE,
      sameCandidateRepickTest |-> FALSE,
      retryVisibilityTest |-> FALSE,
      idleFallbackTest |-> FALSE,
      eevdfFamilyTests |-> FALSE,
      groupHierarchyTests |-> FALSE,
      childExhaustionAliasTests |-> FALSE,
      crossPathTests |-> FALSE,
      staleIdentityTests |-> FALSE,
      wakeupBleedTests |-> FALSE,
      newidleLeakTests |-> FALSE,
      overheadLayoutTests |-> FALSE,
      claimOverreachTests |-> FALSE,
      requiredObservables |-> FALSE,
      validationLayers |-> FALSE,
      behaviorPatchApproved |-> FALSE,
      testInstrumentationApproved |-> FALSE,
      runtimeDenialApproved |-> FALSE,
      runtimeCoverageClaim |-> FALSE,
      productionProtectionClaim |-> FALSE,
      costEfficiencyClaim |-> FALSE,
      datacenterReadinessClaim |-> FALSE ]

SetState(s) ==
    /\ phase = s.phase
    /\ lateDenialTest = s.lateDenialTest
    /\ deniedNotCurrTest = s.deniedNotCurrTest
    /\ sameCandidateRepickTest = s.sameCandidateRepickTest
    /\ retryVisibilityTest = s.retryVisibilityTest
    /\ idleFallbackTest = s.idleFallbackTest
    /\ eevdfFamilyTests = s.eevdfFamilyTests
    /\ groupHierarchyTests = s.groupHierarchyTests
    /\ childExhaustionAliasTests = s.childExhaustionAliasTests
    /\ crossPathTests = s.crossPathTests
    /\ staleIdentityTests = s.staleIdentityTests
    /\ wakeupBleedTests = s.wakeupBleedTests
    /\ newidleLeakTests = s.newidleLeakTests
    /\ overheadLayoutTests = s.overheadLayoutTests
    /\ claimOverreachTests = s.claimOverreachTests
    /\ requiredObservables = s.requiredObservables
    /\ validationLayers = s.validationLayers
    /\ behaviorPatchApproved = s.behaviorPatchApproved
    /\ testInstrumentationApproved = s.testInstrumentationApproved
    /\ runtimeDenialApproved = s.runtimeDenialApproved
    /\ runtimeCoverageClaim = s.runtimeCoverageClaim
    /\ productionProtectionClaim = s.productionProtectionClaim
    /\ costEfficiencyClaim = s.costEfficiencyClaim
    /\ datacenterReadinessClaim = s.datacenterReadinessClaim

Init == SetState(Base)

RecordCoreNegativeTests ==
    /\ phase = "Start"
    /\ lateDenialTest' = TRUE
    /\ deniedNotCurrTest' = TRUE
    /\ sameCandidateRepickTest' = TRUE
    /\ retryVisibilityTest' = TRUE
    /\ idleFallbackTest' = TRUE
    /\ phase' = "CoreNegativeTestsRecorded"
    /\ UNCHANGED <<eevdfFamilyTests, groupHierarchyTests,
                    childExhaustionAliasTests, crossPathTests,
                    staleIdentityTests, wakeupBleedTests, newidleLeakTests,
                    overheadLayoutTests, claimOverreachTests,
                    requiredObservables, validationLayers,
                    behaviorPatchApproved, testInstrumentationApproved,
                    runtimeDenialApproved, runtimeCoverageClaim,
                    productionProtectionClaim, costEfficiencyClaim,
                    datacenterReadinessClaim>>

RecordPathNegativeTests ==
    /\ phase = "CoreNegativeTestsRecorded"
    /\ eevdfFamilyTests' = TRUE
    /\ groupHierarchyTests' = TRUE
    /\ childExhaustionAliasTests' = TRUE
    /\ crossPathTests' = TRUE
    /\ staleIdentityTests' = TRUE
    /\ wakeupBleedTests' = TRUE
    /\ newidleLeakTests' = TRUE
    /\ overheadLayoutTests' = TRUE
    /\ claimOverreachTests' = TRUE
    /\ phase' = "PathNegativeTestsRecorded"
    /\ UNCHANGED <<lateDenialTest, deniedNotCurrTest,
                    sameCandidateRepickTest, retryVisibilityTest,
                    idleFallbackTest, requiredObservables, validationLayers,
                    behaviorPatchApproved, testInstrumentationApproved,
                    runtimeDenialApproved, runtimeCoverageClaim,
                    productionProtectionClaim, costEfficiencyClaim,
                    datacenterReadinessClaim>>

RecordObservablesAndLayers ==
    /\ phase = "PathNegativeTestsRecorded"
    /\ requiredObservables' = TRUE
    /\ validationLayers' = TRUE
    /\ phase' = "ObservableLayersRecorded"
    /\ UNCHANGED <<lateDenialTest, deniedNotCurrTest,
                    sameCandidateRepickTest, retryVisibilityTest,
                    idleFallbackTest, eevdfFamilyTests,
                    groupHierarchyTests, childExhaustionAliasTests,
                    crossPathTests, staleIdentityTests, wakeupBleedTests,
                    newidleLeakTests, overheadLayoutTests,
                    claimOverreachTests, behaviorPatchApproved,
                    testInstrumentationApproved, runtimeDenialApproved,
                    runtimeCoverageClaim, productionProtectionClaim,
                    costEfficiencyClaim, datacenterReadinessClaim>>

RecordPlan ==
    /\ phase = "ObservableLayersRecorded"
    /\ phase' = "PlanRecorded"
    /\ UNCHANGED <<lateDenialTest, deniedNotCurrTest,
                    sameCandidateRepickTest, retryVisibilityTest,
                    idleFallbackTest, eevdfFamilyTests,
                    groupHierarchyTests, childExhaustionAliasTests,
                    crossPathTests, staleIdentityTests, wakeupBleedTests,
                    newidleLeakTests, overheadLayoutTests,
                    claimOverreachTests, requiredObservables,
                    validationLayers, behaviorPatchApproved,
                    testInstrumentationApproved, runtimeDenialApproved,
                    runtimeCoverageClaim, productionProtectionClaim,
                    costEfficiencyClaim, datacenterReadinessClaim>>

StutterDone ==
    /\ phase = "PlanRecorded"
    /\ UNCHANGED vars

Next ==
    \/ RecordCoreNegativeTests
    \/ RecordPathNegativeTests
    \/ RecordObservablesAndLayers
    \/ RecordPlan
    \/ StutterDone

SafeSpec == Init /\ [][Next]_vars

UnsafeMissingLateDenialSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadMissingLateDenial"])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingDeniedNotCurrSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadMissingDeniedNotCurr",
                             !.lateDenialTest = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingSameCandidateSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadMissingSameCandidate",
                             !.lateDenialTest = TRUE,
                             !.deniedNotCurrTest = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingRetryVisibilitySpec ==
    /\ SetState([Base EXCEPT !.phase = "BadMissingRetryVisibility",
                             !.lateDenialTest = TRUE,
                             !.deniedNotCurrTest = TRUE,
                             !.sameCandidateRepickTest = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingIdleFallbackSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadMissingIdleFallback",
                             !.lateDenialTest = TRUE,
                             !.deniedNotCurrTest = TRUE,
                             !.sameCandidateRepickTest = TRUE,
                             !.retryVisibilityTest = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingEevdfSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadMissingEevdf",
                             !.lateDenialTest = TRUE,
                             !.deniedNotCurrTest = TRUE,
                             !.sameCandidateRepickTest = TRUE,
                             !.retryVisibilityTest = TRUE,
                             !.idleFallbackTest = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingGroupHierarchySpec ==
    /\ SetState([Base EXCEPT !.phase = "BadMissingGroupHierarchy",
                             !.lateDenialTest = TRUE,
                             !.deniedNotCurrTest = TRUE,
                             !.sameCandidateRepickTest = TRUE,
                             !.retryVisibilityTest = TRUE,
                             !.idleFallbackTest = TRUE,
                             !.eevdfFamilyTests = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingChildAliasSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadMissingChildAlias",
                             !.lateDenialTest = TRUE,
                             !.deniedNotCurrTest = TRUE,
                             !.sameCandidateRepickTest = TRUE,
                             !.retryVisibilityTest = TRUE,
                             !.idleFallbackTest = TRUE,
                             !.eevdfFamilyTests = TRUE,
                             !.groupHierarchyTests = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingCrossPathSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadMissingCrossPath",
                             !.lateDenialTest = TRUE,
                             !.deniedNotCurrTest = TRUE,
                             !.sameCandidateRepickTest = TRUE,
                             !.retryVisibilityTest = TRUE,
                             !.idleFallbackTest = TRUE,
                             !.eevdfFamilyTests = TRUE,
                             !.groupHierarchyTests = TRUE,
                             !.childExhaustionAliasTests = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingStaleIdentitySpec ==
    /\ SetState([Base EXCEPT !.phase = "BadMissingStaleIdentity",
                             !.crossPathTests = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingWakeupNewidleSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadMissingWakeupNewidle",
                             !.wakeupBleedTests = FALSE,
                             !.newidleLeakTests = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingOverheadSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadMissingOverhead",
                             !.overheadLayoutTests = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingObservablesSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadMissingObservables",
                             !.lateDenialTest = TRUE,
                             !.deniedNotCurrTest = TRUE,
                             !.sameCandidateRepickTest = TRUE,
                             !.retryVisibilityTest = TRUE,
                             !.idleFallbackTest = TRUE,
                             !.eevdfFamilyTests = TRUE,
                             !.groupHierarchyTests = TRUE,
                             !.childExhaustionAliasTests = TRUE,
                             !.crossPathTests = TRUE,
                             !.staleIdentityTests = TRUE,
                             !.wakeupBleedTests = TRUE,
                             !.newidleLeakTests = TRUE,
                             !.overheadLayoutTests = TRUE,
                             !.claimOverreachTests = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingLayersSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadMissingLayers",
                             !.requiredObservables = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeBehaviorBeforePlanSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadBehaviorBeforePlan",
                             !.behaviorPatchApproved = TRUE,
                             !.testInstrumentationApproved = TRUE,
                             !.runtimeDenialApproved = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeRuntimeClaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadRuntimeClaim",
                             !.runtimeCoverageClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeCostProtectionClaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadCostProtectionClaim",
                             !.productionProtectionClaim = TRUE,
                             !.costEfficiencyClaim = TRUE,
                             !.datacenterReadinessClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

TypeOK ==
    /\ phase \in Phases
    /\ lateDenialTest \in BOOLEAN
    /\ deniedNotCurrTest \in BOOLEAN
    /\ sameCandidateRepickTest \in BOOLEAN
    /\ retryVisibilityTest \in BOOLEAN
    /\ idleFallbackTest \in BOOLEAN
    /\ eevdfFamilyTests \in BOOLEAN
    /\ groupHierarchyTests \in BOOLEAN
    /\ childExhaustionAliasTests \in BOOLEAN
    /\ crossPathTests \in BOOLEAN
    /\ staleIdentityTests \in BOOLEAN
    /\ wakeupBleedTests \in BOOLEAN
    /\ newidleLeakTests \in BOOLEAN
    /\ overheadLayoutTests \in BOOLEAN
    /\ claimOverreachTests \in BOOLEAN
    /\ requiredObservables \in BOOLEAN
    /\ validationLayers \in BOOLEAN
    /\ behaviorPatchApproved \in BOOLEAN
    /\ testInstrumentationApproved \in BOOLEAN
    /\ runtimeDenialApproved \in BOOLEAN
    /\ runtimeCoverageClaim \in BOOLEAN
    /\ productionProtectionClaim \in BOOLEAN
    /\ costEfficiencyClaim \in BOOLEAN
    /\ datacenterReadinessClaim \in BOOLEAN

AllNegativeTestsPlanned ==
    /\ lateDenialTest
    /\ deniedNotCurrTest
    /\ sameCandidateRepickTest
    /\ retryVisibilityTest
    /\ idleFallbackTest
    /\ eevdfFamilyTests
    /\ groupHierarchyTests
    /\ childExhaustionAliasTests
    /\ crossPathTests
    /\ staleIdentityTests
    /\ wakeupBleedTests
    /\ newidleLeakTests
    /\ overheadLayoutTests
    /\ claimOverreachTests

PlanComplete ==
    /\ AllNegativeTestsPlanned
    /\ requiredObservables
    /\ validationLayers

ReadyImpliesPlanComplete ==
    phase = "PlanRecorded" => PlanComplete

NoBehaviorBeforePlan ==
    ~(behaviorPatchApproved \/ testInstrumentationApproved \/ runtimeDenialApproved)

NoRuntimeClaim ==
    ~runtimeCoverageClaim

NoCostProtectionClaim ==
    /\ ~productionProtectionClaim
    /\ ~costEfficiencyClaim
    /\ ~datacenterReadinessClaim

Safety ==
    /\ TypeOK
    /\ ReadyImpliesPlanComplete
    /\ PlanComplete \/ phase \notin {
        "BadMissingLateDenial",
        "BadMissingDeniedNotCurr",
        "BadMissingSameCandidate",
        "BadMissingRetryVisibility",
        "BadMissingIdleFallback",
        "BadMissingEevdf",
        "BadMissingGroupHierarchy",
        "BadMissingChildAlias",
        "BadMissingCrossPath",
        "BadMissingStaleIdentity",
        "BadMissingWakeupNewidle",
        "BadMissingOverhead",
        "BadMissingObservables",
        "BadMissingLayers"
      }
    /\ NoBehaviorBeforePlan
    /\ NoRuntimeClaim
    /\ NoCostProtectionClaim

====
