---------- MODULE P5AR2E2DisposableLayoutCandidatePlan ----------
EXTENDS Naturals

CONSTANT Fault

E1Passed == Fault # "MissingE1"
Disposable == Fault # "NotDisposable"
PrimaryUnchanged == Fault # "PrimaryBranchModified"
PatchQueueUnchanged == Fault # "PatchQueueModified"
ExactPaths == Fault # "PathScopeEscaped"
MakefileFrozen == Fault # "MakefileModified"
DefaultOff == Fault # "CandidateNotDefaultOff"
NormalNotSelect == Fault # "NormalConfigSelectsCandidate"
ValidByte == Fault # "MissingValidByte"
ValidUsesHole == Fault # "ValidityHoleNotUsed"
MinimumField == Fault # "MissingMinimum"
MinimumU64 == Fault # "MinimumNotU64"
BuiltGeneration == Fault # "MissingBuiltGeneration"
GenerationU64 == Fault # "GenerationNotU64"
SummaryState == Fault # "MissingSummaryState"
StateByte == Fault # "StateNotByte"
NoCallbackCarrier == Fault # "CallbackCarrierAdded"
NoCfsField == Fault # "CfsRqChanged"
NoTaskField == Fault # "TaskStructChanged"
NoRuntimeCode == Fault # "RuntimeCodeAdded"
NoPublicAbi == Fault # "PublicAbiAdded"
NormalCandidateAbsent == Fault # "NormalCandidatePresent"
ExactProbeSymbols == Fault # "WrongProbeSymbols"
Arm64Baseline == Fault # "MissingArm64Baseline"
ArchLocalOnly == Fault # "CrossArchIdentityClaim"
SchedEntityEnvelope == Fault # "SchedEntityDeltaExceeded"
RqEnvelope == Fault # "RqDeltaExceeded"
ProtectedOffsets == Fault # "ProtectedOffsetShift"
NoBehaviorClaim == Fault # "BehaviorClaim"
NoProtectionClaim == Fault # "ProtectionClaim"

VARIABLE phase

Init == phase = "Start"
RecordBasis == phase = "Start" /\ phase' = "Basis"
RecordCandidate == phase = "Basis" /\ phase' = "Candidate"
RecordEvidence == phase = "Candidate" /\ phase' = "Ready"
Done == phase = "Ready" /\ UNCHANGED phase
Next == RecordBasis \/ RecordCandidate \/ RecordEvidence \/ Done
Spec == Init /\ [][Next]_phase

Contract ==
    /\ E1Passed
    /\ Disposable
    /\ PrimaryUnchanged
    /\ PatchQueueUnchanged
    /\ ExactPaths
    /\ MakefileFrozen
    /\ DefaultOff
    /\ NormalNotSelect
    /\ ValidByte
    /\ ValidUsesHole
    /\ MinimumField
    /\ MinimumU64
    /\ BuiltGeneration
    /\ GenerationU64
    /\ SummaryState
    /\ StateByte
    /\ NoCallbackCarrier
    /\ NoCfsField
    /\ NoTaskField
    /\ NoRuntimeCode
    /\ NoPublicAbi
    /\ NormalCandidateAbsent
    /\ ExactProbeSymbols
    /\ Arm64Baseline
    /\ ArchLocalOnly
    /\ SchedEntityEnvelope
    /\ RqEnvelope
    /\ ProtectedOffsets
    /\ NoBehaviorClaim
    /\ NoProtectionClaim

Safety == phase = "Ready" => Contract

=============================================================================
