---------- MODULE P5AR2SummaryUpdateClosure ----------
EXTENDS Naturals

CONSTANT Fault

CloseRb == Fault # "MissingRb"
CloseCurrent == Fault # "MissingCurrent"
CloseGroupProjection == Fault # "MissingGroupProjection"
CloseLifecycle == Fault # "MissingLifecycle"
CloseBudget == Fault # "MissingBudget"
ClosePlacement == Fault # "MissingPlacement"
CloseThrottleRefill == Fault # "MissingThrottleRefill"
CloseDomainEpoch == Fault # "MissingDomainEpoch"
CloseMonitorRevoke == Fault # "MissingMonitorRevoke"
CloseSelectorGeneration == Fault # "MissingSelectorGeneration"

RqLockOwned == Fault # "NoRqLock"
AncestorPropagation == Fault # "NoAncestorPropagation"
OldRqInvalidBeforeUnlock == Fault # "OldRqStaleAtUnlock"
DestinationPublishAfterActivation == Fault # "DestinationBeforeActivation"
FinalEntityRecheck == Fault # "NoFinalEntityRecheck"
SummaryKeyedToSelectorGeneration == Fault # "UnkeyedSelectorSummary"
ExistingPeltIsFreshPropagation == Fault = "TrustExistingPelt"
PickerRepairsByScan == Fault = "PickerRepairScan"
MonitorCallInPicker == Fault = "MonitorCallInPicker"
LinuxPatchApproved == Fault = "LinuxPatchApproved"
NewHotFieldApproved == Fault = "HotFieldApproved"
RuntimeClaim == Fault = "RuntimeClaim"
ProtectionClaim == Fault = "ProtectionClaim"
CostClaim == Fault = "CostClaim"

EventSet == {
    "Rb",
    "Current",
    "GroupProjection",
    "Lifecycle",
    "Budget",
    "Placement",
    "ThrottleRefill",
    "DomainEpoch",
    "MonitorRevoke",
    "SelectorGeneration"
}

CloseEvent(e) ==
    CASE e = "Rb" -> CloseRb
      [] e = "Current" -> CloseCurrent
      [] e = "GroupProjection" -> CloseGroupProjection
      [] e = "Lifecycle" -> CloseLifecycle
      [] e = "Budget" -> CloseBudget
      [] e = "Placement" -> ClosePlacement
      [] e = "ThrottleRefill" -> CloseThrottleRefill
      [] e = "DomainEpoch" -> CloseDomainEpoch
      [] e = "MonitorRevoke" -> CloseMonitorRevoke
      [] e = "SelectorGeneration" -> CloseSelectorGeneration

VARIABLES phase,
          event,
          rqLocked,
          sourceFresh,
          childValid,
          parentValid,
          destinationValid

vars == <<phase, event, rqLocked, sourceFresh, childValid, parentValid,
          destinationValid>>

Init ==
    /\ phase = "Start"
    /\ event = "None"
    /\ rqLocked = FALSE
    /\ sourceFresh = TRUE
    /\ childValid = TRUE
    /\ parentValid = TRUE
    /\ destinationValid = FALSE

ChooseEvent ==
    /\ phase = "Start"
    /\ \E e \in EventSet:
        /\ event' = e
        /\ phase' = "EventChosen"
    /\ rqLocked' = RqLockOwned
    /\ sourceFresh' = FALSE
    /\ UNCHANGED <<childValid, parentValid, destinationValid>>

RefreshChild ==
    /\ phase = "EventChosen"
    /\ phase' = "ChildRefreshed"
    /\ childValid' = IF CloseEvent(event) THEN FALSE ELSE childValid
    /\ UNCHANGED <<event, rqLocked, sourceFresh, parentValid,
                    destinationValid>>

RefreshParent ==
    /\ phase = "ChildRefreshed"
    /\ phase' = "ParentRefreshed"
    /\ parentValid' = IF AncestorPropagation /\ ~childValid
                      THEN FALSE ELSE parentValid
    /\ UNCHANGED <<event, rqLocked, sourceFresh, childValid,
                    destinationValid>>

SettleDestination ==
    /\ phase = "ParentRefreshed"
    /\ phase' = "DestinationSettled"
    /\ destinationValid' = IF event = "Placement"
                            THEN DestinationPublishAfterActivation
                            ELSE FALSE
    /\ UNCHANGED <<event, rqLocked, sourceFresh, childValid, parentValid>>

Release ==
    /\ phase = "DestinationSettled"
    /\ phase' = "Released"
    /\ rqLocked' = FALSE
    /\ UNCHANGED <<event, sourceFresh, childValid, parentValid,
                    destinationValid>>

Finish ==
    /\ phase = "Released"
    /\ phase' = "Done"
    /\ UNCHANGED <<event, rqLocked, sourceFresh, childValid, parentValid,
                    destinationValid>>

StayDone ==
    /\ phase = "Done"
    /\ UNCHANGED vars

Next ==
    ChooseEvent \/ RefreshChild \/ RefreshParent \/ SettleDestination \/
    Release \/ Finish \/ StayDone

Spec == Init /\ [][Next]_vars

ActivePhase == {
    "EventChosen", "ChildRefreshed", "ParentRefreshed",
    "DestinationSettled"
}

LockSafety == phase \in ActivePhase => rqLocked

ReleasedClosure ==
    phase \in {"Released", "Done"} /\ ~sourceFresh =>
        ~childValid /\ ~parentValid

PlacementSafety ==
    phase \in {"Released", "Done"} /\ event = "Placement" =>
        OldRqInvalidBeforeUnlock /\ destinationValid

Safety ==
    /\ LockSafety
    /\ ReleasedClosure
    /\ PlacementSafety
    /\ FinalEntityRecheck
    /\ SummaryKeyedToSelectorGeneration
    /\ ~ExistingPeltIsFreshPropagation
    /\ ~PickerRepairsByScan
    /\ ~MonitorCallInPicker
    /\ ~LinuxPatchApproved
    /\ ~NewHotFieldApproved
    /\ ~RuntimeClaim
    /\ ~ProtectionClaim
    /\ ~CostClaim

======================================================
