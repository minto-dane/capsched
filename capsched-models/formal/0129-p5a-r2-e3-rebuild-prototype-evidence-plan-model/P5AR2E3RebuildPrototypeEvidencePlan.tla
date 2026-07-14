---------- MODULE P5AR2E3RebuildPrototypeEvidencePlan ----------
EXTENDS Naturals

CONSTANT Fault

E2Closure == Fault # "E2ClosureMissing"
ExactCandidate == Fault # "CandidateMoved"
FrozenLayout == Fault # "LayoutNotFrozen"
PatchQueueFrozen == Fault # "PatchQueueMoved"
DisposableBranch == Fault # "NotDisposable"
ExactAllowedScope == Fault # "ScopeExpanded"
DefaultOff == Fault # "NotDefaultOff"
KUnitDependency == Fault # "KUnitDependencyMissing"
SameTranslationUnit == Fault # "SeparateObject"
ActualTraversals == Fault # "TraversalSubstituted"
CurrentSeparate == Fault # "CurrentFoldedIntoTree"
BottomUpNonrecursive == Fault # "HierarchyOrderOrRecursion"
IndependentOracle == Fault # "OracleSharesImplementation"
RequiredCases == Fault # "RequiredCaseMissing"
GenerationRecheck == Fault # "GenerationNotRechecked"
SaturationBlocked == Fault # "SaturationReused"
RqLockOwned == Fault # "RqLockNotOwned"
NoForbiddenLockedOps == Fault # "ForbiddenLockedOperation"
NoTopologyMutation == Fault # "TopologyMutated"
NoRuntimeConnection == Fault # "RuntimeConnected"
NoPublisherFanout == Fault # "PublisherOrFanoutAdded"
NoExportAbi == Fault # "ExportOrAbiAdded"
BuildAndKUnit == Fault # "BuildOrKUnitMissing"
NoAcceptanceClaims == Fault # "ClaimExpanded"

VARIABLE phase

Init == phase = "Start"
RecordBoundary == phase = "Start" /\ phase' = "Boundary"
RecordTraversal == phase = "Boundary" /\ phase' = "Traversal"
RecordOracle == phase = "Traversal" /\ phase' = "Oracle"
AuthorizeDraft == phase = "Oracle" /\ phase' = "Authorized"
Done == phase = "Authorized" /\ UNCHANGED phase
Next == RecordBoundary \/ RecordTraversal \/ RecordOracle \/ AuthorizeDraft \/ Done
Spec == Init /\ [][Next]_phase

Contract ==
    /\ E2Closure
    /\ ExactCandidate
    /\ FrozenLayout
    /\ PatchQueueFrozen
    /\ DisposableBranch
    /\ ExactAllowedScope
    /\ DefaultOff
    /\ KUnitDependency
    /\ SameTranslationUnit
    /\ ActualTraversals
    /\ CurrentSeparate
    /\ BottomUpNonrecursive
    /\ IndependentOracle
    /\ RequiredCases
    /\ GenerationRecheck
    /\ SaturationBlocked
    /\ RqLockOwned
    /\ NoForbiddenLockedOps
    /\ NoTopologyMutation
    /\ NoRuntimeConnection
    /\ NoPublisherFanout
    /\ NoExportAbi
    /\ BuildAndKUnit
    /\ NoAcceptanceClaims

Safety == phase = "Authorized" => Contract

=============================================================================
