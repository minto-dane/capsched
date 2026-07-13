---------- MODULE P5AR2VruntimeSentinelGate ----------
EXTENDS Naturals

CONSTANTS UseLiteralSentinel,
          ExplicitValidity,
          InvalidNumericIgnored,
          ValueRequiredWhenValid,
          WrapAwareMinimum,
          PickerGuardsValidity,
          BooleanOnlySummary,
          CurrentSeparate,
          GroupProjectsChild,
          RqLockOwned,
          EnqueueOnlyRefresh,
          SourceBasisChecked,
          LayoutBaselineChecked,
          LinuxPatchApproved,
          RuntimeClaim,
          ProtectionClaim,
          MonitorCallInPicker,
          CostClaim

VARIABLES phase, summaryValid, numericUsed

vars == <<phase, summaryValid, numericUsed>>

Init ==
    /\ phase = "Start"
    /\ summaryValid = FALSE
    /\ numericUsed = FALSE

RecordSource ==
    /\ phase = "Start"
    /\ phase' = "SourceChecked"
    /\ UNCHANGED <<summaryValid, numericUsed>>

DefineRepresentation ==
    /\ phase = "SourceChecked"
    /\ phase' = "RepresentationDefined"
    /\ summaryValid' = FALSE
    /\ numericUsed' = FALSE

PublishFresh ==
    /\ phase = "RepresentationDefined"
    /\ phase' = "FreshPublished"
    /\ summaryValid' = TRUE
    /\ numericUsed' = ValueRequiredWhenValid

Invalidate ==
    /\ phase = "FreshPublished"
    /\ phase' = "Invalidated"
    /\ summaryValid' = FALSE
    /\ numericUsed' = ~InvalidNumericIgnored

Finish ==
    /\ phase = "Invalidated"
    /\ phase' = "Done"
    /\ UNCHANGED <<summaryValid, numericUsed>>

StayDone ==
    /\ phase = "Done"
    /\ UNCHANGED vars

Next ==
    RecordSource \/ DefineRepresentation \/ PublishFresh \/ Invalidate \/
    Finish \/ StayDone

Safety ==
    /\ ~UseLiteralSentinel
    /\ ExplicitValidity
    /\ WrapAwareMinimum
    /\ PickerGuardsValidity
    /\ ~BooleanOnlySummary
    /\ CurrentSeparate
    /\ GroupProjectsChild
    /\ RqLockOwned
    /\ ~EnqueueOnlyRefresh
    /\ SourceBasisChecked
    /\ LayoutBaselineChecked
    /\ ~LinuxPatchApproved
    /\ ~RuntimeClaim
    /\ ~ProtectionClaim
    /\ ~MonitorCallInPicker
    /\ ~CostClaim
    /\ (summaryValid \/ ~numericUsed)
    /\ (~summaryValid \/ numericUsed)

Spec == Init /\ [][Next]_vars

=============================================================
