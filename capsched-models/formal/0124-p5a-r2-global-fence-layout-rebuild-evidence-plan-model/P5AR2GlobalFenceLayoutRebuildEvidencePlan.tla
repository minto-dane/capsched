---------- MODULE P5AR2GlobalFenceLayoutRebuildEvidencePlan ----------
EXTENDS Naturals

CONSTANT Fault

X86Baseline == Fault # "MissingX86Baseline"
Arm64Baseline == Fault # "MissingArm64Baseline"
CompareArchToOwnBaseline == Fault # "MissingOwnArchCompare"
FieldEnvelope == Fault # "NoFieldEnvelope"
SchedEntityDeltaBounded == Fault # "SchedEntityDeltaUnbounded"
CfsRqDeltaZero == Fault # "CfsRqDeltaNonzero"
RqDeltaBounded == Fault # "RqDeltaUnbounded"
TaskDeltaZero == Fault # "TaskDeltaNonzero"
HotOffsetsUnchanged == Fault # "HotOffsetsShift"
ConfigMatrix == Fault # "MissingConfigMatrix"
ExpandedProbe == Fault # "MissingExpandedProbe"
LayoutOnlyStage == Fault # "MissingLayoutOnlyStage"
BruteForceOracle == Fault # "MissingOracle"
WrapCases == Fault # "MissingWrapCases"
PostorderProof == Fault # "MissingPostorderProof"
BottomUpProof == Fault # "MissingBottomUpProof"
AllowsUnboundedRecursion == Fault = "AllowsUnboundedRecursion"
RaceTests == Fault # "MissingRaceTests"
LockMatrix == Fault # "MissingLockMatrix"
P99Gate == Fault # "MissingP99Gate"
RawMaxGate == Fault # "MissingRawMaxGate"
WarningGate == Fault # "MissingWarningGate"
ControlledObjectDiff == Fault # "MissingControlledObjectDiff"
FunctionDisassembly == Fault # "MissingFunctionDisassembly"
PickerPerNodeGenerationCheck == Fault = "PickerPerNodeCheck"
PickerExternalWork == Fault = "PickerExternalWork"
RuntimeEvidenceSeparated == Fault # "MissingRuntimeSeparation"
LinuxPatchApproved == Fault = "LinuxPatchApproved"
HotFieldApproved == Fault = "HotFieldApproved"
RuntimeClaim == Fault = "RuntimeClaim"
ProtectionClaim == Fault = "ProtectionClaim"
CostClaim == Fault = "CostClaim"

VARIABLE phase

Init == phase = "Start"

RecordBaselines ==
    /\ phase = "Start"
    /\ phase' = "Baselines"

PlanLayout ==
    /\ phase = "Baselines"
    /\ phase' = "LayoutPlan"

PlanRebuild ==
    /\ phase = "LayoutPlan"
    /\ phase' = "RebuildPlan"

Finish ==
    /\ phase = "RebuildPlan"
    /\ phase' = "Ready"

StayReady ==
    /\ phase = "Ready"
    /\ UNCHANGED phase

Next == RecordBaselines \/ PlanLayout \/ PlanRebuild \/ Finish \/ StayReady

Spec == Init /\ [][Next]_phase

EvidenceContract ==
    /\ X86Baseline
    /\ Arm64Baseline
    /\ CompareArchToOwnBaseline
    /\ FieldEnvelope
    /\ SchedEntityDeltaBounded
    /\ CfsRqDeltaZero
    /\ RqDeltaBounded
    /\ TaskDeltaZero
    /\ HotOffsetsUnchanged
    /\ ConfigMatrix
    /\ ExpandedProbe
    /\ LayoutOnlyStage
    /\ BruteForceOracle
    /\ WrapCases
    /\ PostorderProof
    /\ BottomUpProof
    /\ ~AllowsUnboundedRecursion
    /\ RaceTests
    /\ LockMatrix
    /\ P99Gate
    /\ RawMaxGate
    /\ WarningGate
    /\ ControlledObjectDiff
    /\ FunctionDisassembly
    /\ ~PickerPerNodeGenerationCheck
    /\ ~PickerExternalWork
    /\ RuntimeEvidenceSeparated
    /\ ~LinuxPatchApproved
    /\ ~HotFieldApproved
    /\ ~RuntimeClaim
    /\ ~ProtectionClaim
    /\ ~CostClaim

Safety == phase = "Ready" => EvidenceContract

======================================================
