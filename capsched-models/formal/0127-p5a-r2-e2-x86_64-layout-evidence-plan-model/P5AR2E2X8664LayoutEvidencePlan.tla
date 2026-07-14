---------- MODULE P5AR2E2X8664LayoutEvidencePlan ----------
EXTENDS Naturals

CONSTANT Fault

Arm64Passed == Fault # "MissingArm64Pass"
ExactPrimary == Fault # "PrimaryMoved"
ExactCandidate == Fault # "CandidateMoved"
PatchQueueFrozen == Fault # "PatchQueueMoved"
TargetX8664 == Fault # "WrongTarget"
CrossCompiler == Fault # "MissingCrossCompiler"
FreshE1 == Fault # "MissingFreshE1"
SameToolchain == Fault # "ToolchainMismatch"
SameConfigProcedure == Fault # "ConfigProcedureMismatch"
NormalOffBuild == Fault # "MissingNormalOff"
NormalOnBuild == Fault # "MissingNormalOn"
NormalCandidateAbsent == Fault # "NormalCandidatePresent"
E1Count == Fault # "WrongE1Count"
CandidateCount == Fault # "WrongCandidateCount"
E1ValuesPreserved == Fault # "ChangedE1Value"
TableCount == Fault # "WrongTableCount"
BaselineReproduced == Fault # "BaselineMismatch"
SchedEntityEnvelope == Fault # "SchedEntityGrowth"
CfsRqEnvelope == Fault # "CfsRqGrowth"
RqEnvelope == Fault # "RqGrowth"
TaskEnvelope == Fault # "TaskGrowth"
FieldsWithin == Fault # "FieldOutOfBounds"
ArchLocalOnly == Fault # "CrossArchIdentityClaim"
NoAcceptanceOrBehavior == Fault # "AcceptanceOrBehaviorClaim"

VARIABLE phase

Init == phase = "Start"
RecordBasis == phase = "Start" /\ phase' = "Basis"
RecordBuild == phase = "Basis" /\ phase' = "Build"
RecordComparison == phase = "Build" /\ phase' = "Ready"
Done == phase = "Ready" /\ UNCHANGED phase
Next == RecordBasis \/ RecordBuild \/ RecordComparison \/ Done
Spec == Init /\ [][Next]_phase

Contract ==
    /\ Arm64Passed
    /\ ExactPrimary
    /\ ExactCandidate
    /\ PatchQueueFrozen
    /\ TargetX8664
    /\ CrossCompiler
    /\ FreshE1
    /\ SameToolchain
    /\ SameConfigProcedure
    /\ NormalOffBuild
    /\ NormalOnBuild
    /\ NormalCandidateAbsent
    /\ E1Count
    /\ CandidateCount
    /\ E1ValuesPreserved
    /\ TableCount
    /\ BaselineReproduced
    /\ SchedEntityEnvelope
    /\ CfsRqEnvelope
    /\ RqEnvelope
    /\ TaskEnvelope
    /\ FieldsWithin
    /\ ArchLocalOnly
    /\ NoAcceptanceOrBehavior

Safety == phase = "Ready" => Contract

=============================================================================
