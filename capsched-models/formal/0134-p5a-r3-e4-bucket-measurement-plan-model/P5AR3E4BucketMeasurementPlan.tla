---------- MODULE P5AR3E4BucketMeasurementPlan ----------
EXTENDS Naturals

CONSTANT Fault

E3Evidence == Fault # "E3EvidenceMissing"
ExactSource == Fault # "SourceIdentityMoved"
DisposableScope == Fault # "ScopeExpanded"
DefaultOff == Fault # "NotDefaultOff"
SameTranslationUnit == Fault # "SeparateObject"
E3ProtocolFrozen == Fault # "E3ProtocolChanged"
SyntheticOnly == Fault # "LiveSchedulerAttached"
RealRqLock == Fault # "MockRqLock"
OneProjection == Fault # "MoreThanOneProjection"
NoLeafScan == Fault # "LeafScan"
Preallocated == Fault # "AllocationInInterval"
NoPolicyCall == Fault # "PolicyCall"
StableFresh == Fault # "FreshWithoutStableGeneration"
PairedControl == Fault # "NoPairedControl"
AlternatingOrder == Fault # "PairOrderBiased"
SaturatingDifference == Fault # "DifferenceWrapped"
FullOneProjectionMatrix == Fault # "OneProjectionMatrixReduced"
ConstantOneProjectionWork == Fault # "InnerCountChangesWork"
ExactSamples == Fault # "SamplesReduced"
FullStatistics == Fault # "StatisticsMissing"
FixedOneProjectionGate == Fault # "OneProjectionThresholdRelaxed"
BaseSliceGate == Fault # "BaseSliceIgnored"
FullHotplugMatrix == Fault # "HotplugMatrixReduced"
BoundedHotplug == Fault # "HotplugUnbounded"
FixedHotplugGate == Fault # "HotplugThresholdRelaxed"
FullFanoutMatrix == Fault # "FanoutMatrixReduced"
TargetedFanout == Fault # "FanoutUsesAllRqs"
FixedFanoutGate == Fault # "FanoutThresholdRelaxed"
FanoutAvailabilityOnly == Fault # "FanoutTreatedAsTrust"
WarningGate == Fault # "WarningIgnored"
NegativeEvidence == Fault # "RejectionHidden"
MalformedFails == Fault # "MalformedAccepted"
Arm64Required == Fault # "Arm64Missing"
X8664Required == Fault # "X8664Missing"
SameSourceBoth == Fault # "SourceDriftBetweenArch"
VirtualizationBoundary == Fault # "BareMetalClaimFromVirtual"
NoRangeReduction == Fault # "RangeReducedAfterFailure"
NoPrematureE5 == Fault # "E5SourcePremature"
NoCrossPathClaim == Fault # "CrossPathClaim"
NoProductionClaim == Fault # "ProductionClaim"

VARIABLE phase

Init == phase = "Start"
RecordBoundary == phase = "Start" /\ phase' = "Boundary"
RecordProjection == phase = "Boundary" /\ phase' = "Projection"
RecordHotplug == phase = "Projection" /\ phase' = "Hotplug"
RecordFanout == phase = "Hotplug" /\ phase' = "Fanout"
RecordClassification == phase = "Fanout" /\ phase' = "Classification"
AuthorizeDraft == phase = "Classification" /\ phase' = "Authorized"
Done == phase = "Authorized" /\ UNCHANGED phase

Next == RecordBoundary \/ RecordProjection \/ RecordHotplug \/
        RecordFanout \/ RecordClassification \/ AuthorizeDraft \/ Done

Spec == Init /\ [][Next]_phase

Contract ==
    /\ E3Evidence
    /\ ExactSource
    /\ DisposableScope
    /\ DefaultOff
    /\ SameTranslationUnit
    /\ E3ProtocolFrozen
    /\ SyntheticOnly
    /\ RealRqLock
    /\ OneProjection
    /\ NoLeafScan
    /\ Preallocated
    /\ NoPolicyCall
    /\ StableFresh
    /\ PairedControl
    /\ AlternatingOrder
    /\ SaturatingDifference
    /\ FullOneProjectionMatrix
    /\ ConstantOneProjectionWork
    /\ ExactSamples
    /\ FullStatistics
    /\ FixedOneProjectionGate
    /\ BaseSliceGate
    /\ FullHotplugMatrix
    /\ BoundedHotplug
    /\ FixedHotplugGate
    /\ FullFanoutMatrix
    /\ TargetedFanout
    /\ FixedFanoutGate
    /\ FanoutAvailabilityOnly
    /\ WarningGate
    /\ NegativeEvidence
    /\ MalformedFails
    /\ Arm64Required
    /\ X8664Required
    /\ SameSourceBoth
    /\ VirtualizationBoundary
    /\ NoRangeReduction
    /\ NoPrematureE5
    /\ NoCrossPathClaim
    /\ NoProductionClaim

Safety == phase = "Authorized" => Contract

=============================================================================
