---------- MODULE P5AR2E4LockHoldMeasurementPlan ----------
EXTENDS Naturals

CONSTANT Fault

E3Evidence == Fault # "E3EvidenceMissing"
ExactSource == Fault # "SourceIdentityMoved"
DisposableScope == Fault # "ScopeExpanded"
DefaultOff == Fault # "NotDefaultOff"
SameTranslationUnit == Fault # "SeparateObject"
ExactRebuild == Fault # "RebuildSubstituted"
RealStructures == Fault # "StructuresMocked"
SyntheticNonClaim == Fault # "SyntheticClaimExpanded"
O1LeafCallback == Fault # "LinearCallbackTimed"
Preallocation == Fault # "AllocationInInterval"
ActualIrqRqLock == Fault # "LockIntervalSubstituted"
PairedControl == Fault # "ControlMissing"
AlternatingOrder == Fault # "PairOrderBiased"
CorrectDifference == Fault # "DifferenceWrapped"
NoLockedSideEffects == Fault # "LockedSideEffect"
FullMatrix == Fault # "MatrixReduced"
ExactSamples == Fault # "SamplesReduced"
AllStatistics == Fault # "StatisticsMissing"
FixedGate == Fault # "ThresholdRelaxed"
WarningGate == Fault # "WarningIgnored"
NegativeEvidence == Fault # "RejectionHidden"
MalformedFails == Fault # "MalformedAccepted"
Arm64Required == Fault # "Arm64Missing"
X8664Required == Fault # "X8664Missing"
SameSourceBoth == Fault # "ArchitectureSourceDrift"
VirtualizationBoundary == Fault # "BareMetalClaimFromVirtual"
NoRangeReduction == Fault # "RangeReducedAfterFailure"
NoAcceptanceClaims == Fault # "ClaimExpanded"

VARIABLE phase

Init == phase = "Start"
RecordBoundary == phase = "Start" /\ phase' = "Boundary"
RecordInterval == phase = "Boundary" /\ phase' = "Interval"
RecordMatrix == phase = "Interval" /\ phase' = "Matrix"
AuthorizeDraft == phase = "Matrix" /\ phase' = "Authorized"
Done == phase = "Authorized" /\ UNCHANGED phase
Next == RecordBoundary \/ RecordInterval \/ RecordMatrix \/ AuthorizeDraft \/ Done
Spec == Init /\ [][Next]_phase

Contract ==
    /\ E3Evidence
    /\ ExactSource
    /\ DisposableScope
    /\ DefaultOff
    /\ SameTranslationUnit
    /\ ExactRebuild
    /\ RealStructures
    /\ SyntheticNonClaim
    /\ O1LeafCallback
    /\ Preallocation
    /\ ActualIrqRqLock
    /\ PairedControl
    /\ AlternatingOrder
    /\ CorrectDifference
    /\ NoLockedSideEffects
    /\ FullMatrix
    /\ ExactSamples
    /\ AllStatistics
    /\ FixedGate
    /\ WarningGate
    /\ NegativeEvidence
    /\ MalformedFails
    /\ Arm64Required
    /\ X8664Required
    /\ SameSourceBoth
    /\ VirtualizationBoundary
    /\ NoRangeReduction
    /\ NoAcceptanceClaims

Safety == phase = "Authorized" => Contract

=============================================================================
