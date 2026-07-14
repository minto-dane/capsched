---------- MODULE P5AR2E2LayoutEvidenceClosure ----------
EXTENDS Naturals

CONSTANT Fault

Arm64Passed == Fault # "Arm64Missing"
X8664Passed == Fault # "X8664Missing"
ExactResultHashes == Fault # "ResultHashMismatch"
ExactPrimary == Fault # "PrimaryMoved"
ExactCandidate == Fault # "CandidateMoved"
ExactDiff == Fault # "DiffChanged"
PatchQueueFrozen == Fault # "PatchQueueMoved"
DefaultOff == Fault # "NotDefaultOff"
NormalAbsent == Fault # "NormalCandidatePresent"
E1Counts == Fault # "E1CountMismatch"
CandidateCounts == Fault # "CandidateCountMismatch"
TableCounts == Fault # "TableCountMismatch"
NoMissingE1 == Fault # "MissingE1"
NoChangedE1 == Fault # "ChangedE1"
ZeroGrowthArm64 == Fault # "Arm64Growth"
ZeroGrowthX8664 == Fault # "X8664Growth"
ProtectedMeasurements == Fault # "ProtectedShift"
FieldsWithin == Fault # "FieldOutOfBounds"
ArchitectureLocal == Fault # "CrossArchIdentityClaim"
FreezeForPlanning == Fault # "LayoutNotFrozen"
NoPrimaryPromotion == Fault # "PrimaryPromotion"
NoE3Source == Fault # "E3SourceApproved"
NoRuntimeClaim == Fault # "RuntimeClaim"
NoProductionClaim == Fault # "ProductionClaim"

VARIABLE phase

Init == phase = "Start"
RecordSources == phase = "Start" /\ phase' = "Sources"
RecordEvidence == phase = "Sources" /\ phase' = "Evidence"
RecordDecision == phase = "Evidence" /\ phase' = "Closed"
Done == phase = "Closed" /\ UNCHANGED phase
Next == RecordSources \/ RecordEvidence \/ RecordDecision \/ Done
Spec == Init /\ [][Next]_phase

Contract ==
    /\ Arm64Passed
    /\ X8664Passed
    /\ ExactResultHashes
    /\ ExactPrimary
    /\ ExactCandidate
    /\ ExactDiff
    /\ PatchQueueFrozen
    /\ DefaultOff
    /\ NormalAbsent
    /\ E1Counts
    /\ CandidateCounts
    /\ TableCounts
    /\ NoMissingE1
    /\ NoChangedE1
    /\ ZeroGrowthArm64
    /\ ZeroGrowthX8664
    /\ ProtectedMeasurements
    /\ FieldsWithin
    /\ ArchitectureLocal
    /\ FreezeForPlanning
    /\ NoPrimaryPromotion
    /\ NoE3Source
    /\ NoRuntimeClaim
    /\ NoProductionClaim

Safety == phase = "Closed" => Contract

=============================================================================
