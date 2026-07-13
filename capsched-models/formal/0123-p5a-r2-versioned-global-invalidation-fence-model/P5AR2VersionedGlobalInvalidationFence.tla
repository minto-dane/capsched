---------- MODULE P5AR2VersionedGlobalInvalidationFence ----------
EXTENDS Naturals

CONSTANT Fault

GenerationFence == Fault # "MissingGenerationFence"
ReleaseAcquirePublication == Fault # "MissingReleaseAcquire"
PickerChecksGeneration == Fault # "PickerSkipsGeneration"
BroadcastAllRqs == Fault # "NoAllRqBroadcast"
RqLockRebuild == Fault # "NoRqLockRebuild"
FullRebuild == Fault # "PartialRebuild"
RecheckGenerationBeforeFresh == Fault # "NoGenerationRecheck"
GenerationNoWrap == Fault # "GenerationWrap"
FinalEntityRecheck == Fault # "NoFinalEntityRecheck"
PickerRepairsByScan == Fault = "PickerRepairScan"
MonitorCallInPicker == Fault = "MonitorCallInPicker"
SelectorGenerationIsConfiguration == Fault # "PerPickSelectorGeneration"
TargetedFanoutRequiresIndex == Fault # "TargetedWithoutIndex"
ConservativeInvalidation == Fault # "NotConservative"
DomainEpochUsesFence == Fault # "DomainEpochBypassesFence"
BudgetTransitionUsesFence == Fault # "BudgetBypassesFence"
MonitorReceiptUsesFence == Fault # "MonitorReceiptBypassesFence"
RefillUsesFence == Fault # "RefillBypassesFence"
MutationIntegration == Fault # "NoMutationIntegration"
SaturationBlocks == Fault # "NoBlockedSaturation"
LinuxPatchApproved == Fault = "LinuxPatchApproved"
RuntimeClaim == Fault = "RuntimeClaim"
ProtectionClaim == Fault = "ProtectionClaim"
CostClaim == Fault = "CostClaim"

VARIABLES phase,
          publishedGen,
          builtGen,
          targetGen,
          summaryState,
          rqLocked,
          rebuiltAll,
          summaryTrusted,
          finalRechecked,
          raced

vars == <<phase, publishedGen, builtGen, targetGen, summaryState, rqLocked,
          rebuiltAll, summaryTrusted, finalRechecked, raced>>

Init ==
    /\ phase = "Start"
    /\ publishedGen = 1
    /\ builtGen = 1
    /\ targetGen = 0
    /\ summaryState = "Fresh"
    /\ rqLocked = FALSE
    /\ rebuiltAll = TRUE
    /\ summaryTrusted = FALSE
    /\ finalRechecked = FALSE
    /\ raced = FALSE

Publish ==
    /\ phase = "Start"
    /\ phase' = "Published"
    /\ publishedGen' = IF GenerationFence THEN 2 ELSE 1
    /\ rebuiltAll' = FALSE
    /\ summaryTrusted' = FALSE
    /\ finalRechecked' = FALSE
    /\ UNCHANGED <<builtGen, targetGen, summaryState, rqLocked, raced>>

PreFanoutPick ==
    /\ phase = "Published"
    /\ phase' = "PreFanoutChecked"
    /\ summaryTrusted' =
        (summaryState = "Fresh" /\
         (IF PickerChecksGeneration THEN builtGen = publishedGen ELSE TRUE))
    /\ finalRechecked' = FinalEntityRecheck
    /\ UNCHANGED <<publishedGen, builtGen, targetGen, summaryState, rqLocked,
                    rebuiltAll, raced>>

BeginRefresh ==
    /\ phase = "PreFanoutChecked"
    /\ phase' = "Refreshing"
    /\ targetGen' = publishedGen
    /\ summaryState' = IF BroadcastAllRqs THEN "Refreshing" ELSE summaryState
    /\ rqLocked' = RqLockRebuild
    /\ summaryTrusted' = FALSE
    /\ finalRechecked' = FALSE
    /\ UNCHANGED <<publishedGen, builtGen, rebuiltAll, raced>>

Rebuild ==
    /\ phase = "Refreshing"
    /\ phase' = "Rebuilt"
    /\ rebuiltAll' = FullRebuild
    /\ UNCHANGED <<publishedGen, builtGen, targetGen, summaryState, rqLocked,
                    summaryTrusted, finalRechecked, raced>>

CommitStable ==
    /\ phase = "Rebuilt"
    /\ phase' = "Committed"
    /\ builtGen' = targetGen
    /\ summaryState' = "Fresh"
    /\ rqLocked' = FALSE
    /\ UNCHANGED <<publishedGen, targetGen, rebuiltAll, summaryTrusted,
                    finalRechecked, raced>>

RepublishDuringRebuild ==
    /\ phase = "Rebuilt"
    /\ phase' = "RebuiltAfterRepublish"
    /\ publishedGen' = publishedGen + 1
    /\ raced' = TRUE
    /\ UNCHANGED <<builtGen, targetGen, summaryState, rqLocked, rebuiltAll,
                    summaryTrusted, finalRechecked>>

CommitRaced ==
    /\ phase = "RebuiltAfterRepublish"
    /\ phase' = "Committed"
    /\ builtGen' = targetGen
    /\ summaryState' = IF RecheckGenerationBeforeFresh
                       THEN "Stale" ELSE "Fresh"
    /\ rqLocked' = FALSE
    /\ UNCHANGED <<publishedGen, targetGen, rebuiltAll, summaryTrusted,
                    finalRechecked, raced>>

FinalPick ==
    /\ phase = "Committed"
    /\ phase' = "Done"
    /\ summaryTrusted' =
        (summaryState = "Fresh" /\
         (IF PickerChecksGeneration THEN builtGen = publishedGen ELSE TRUE))
    /\ finalRechecked' = FinalEntityRecheck
    /\ UNCHANGED <<publishedGen, builtGen, targetGen, summaryState, rqLocked,
                    rebuiltAll, raced>>

StayDone ==
    /\ phase = "Done"
    /\ UNCHANGED vars

Next ==
    Publish \/ PreFanoutPick \/ BeginRefresh \/ Rebuild \/ CommitStable \/
    RepublishDuringRebuild \/ CommitRaced \/ FinalPick \/ StayDone

Spec == Init /\ [][Next]_vars

LockSafety ==
    phase \in {"Refreshing", "Rebuilt", "RebuiltAfterRepublish"} => rqLocked

PreFanoutSafety ==
    phase = "PreFanoutChecked" /\ builtGen # publishedGen => ~summaryTrusted

CommitCoherence ==
    phase \in {"Committed", "Done"} /\ summaryState = "Fresh" =>
        builtGen = publishedGen

TrustedSafety ==
    summaryTrusted =>
        /\ summaryState = "Fresh"
        /\ builtGen = publishedGen
        /\ rebuiltAll
        /\ finalRechecked

Safety ==
    /\ LockSafety
    /\ PreFanoutSafety
    /\ CommitCoherence
    /\ TrustedSafety
    /\ GenerationFence
    /\ ReleaseAcquirePublication
    /\ PickerChecksGeneration
    /\ BroadcastAllRqs
    /\ FullRebuild
    /\ RecheckGenerationBeforeFresh
    /\ GenerationNoWrap
    /\ FinalEntityRecheck
    /\ ~PickerRepairsByScan
    /\ ~MonitorCallInPicker
    /\ SelectorGenerationIsConfiguration
    /\ TargetedFanoutRequiresIndex
    /\ ConservativeInvalidation
    /\ DomainEpochUsesFence
    /\ BudgetTransitionUsesFence
    /\ MonitorReceiptUsesFence
    /\ RefillUsesFence
    /\ MutationIntegration
    /\ SaturationBlocks
    /\ ~LinuxPatchApproved
    /\ ~RuntimeClaim
    /\ ~ProtectionClaim
    /\ ~CostClaim

======================================================
