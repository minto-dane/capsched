---------------------- MODULE MonitorRootScheduler ----------------------
EXTENDS Naturals, Sequences

CONSTANTS
    Mgmt,
    G1,
    G2,
    BE1,
    NoDomain,
    SlackSlot,
    LeaseQuantum,
    MaxEpoch,
    FaultMode,
    EnableRevocation

Domains == {Mgmt, G1, G2, BE1}
Guaranteed == {Mgmt, G1, G2}
BestEffort == {BE1}
DomainOrNone == Domains \union {NoDomain}

RootFrame == <<Mgmt, G1, G2, SlackSlot>>
FrameLength == Len(RootFrame)
MaxWait == FrameLength + 1

FaultModes == {
    "Safe",
    "WaitForLinuxHint",
    "SkipReserved",
    "StealReserved",
    "StaleEpoch",
    "LinuxExtend",
    "ExpiryStillRunning",
    "StopAfterExpiry",
    "RevokeManagement",
    "NoTimer",
    "LinuxMint"
}

VARIABLES
    slotIndex,
    admitted,
    epoch,
    activeDomain,
    tokenDomain,
    tokenEpoch,
    tokenSlot,
    tokenSealed,
    authoritySource,
    timerArmed,
    leaseIssued,
    leaseRemaining,
    leaseConsumed,
    waitSlots,
    handoffPending,
    lastDeparted,
    linuxProposal,
    linuxOffersReserved,
    linuxExtensionRequested,
    linuxShadowSlot,
    halted,
    protectionClaim

vars ==
    <<slotIndex, admitted, epoch, activeDomain, tokenDomain, tokenEpoch,
      tokenSlot, tokenSealed, authoritySource, timerArmed, leaseIssued,
      leaseRemaining, leaseConsumed, waitSlots, handoffPending,
      lastDeparted, linuxProposal, linuxOffersReserved,
      linuxExtensionRequested, linuxShadowSlot, halted, protectionClaim>>

FrameOwner == RootFrame[slotIndex]

NextSlot(i) == IF i = FrameLength THEN 1 ELSE i + 1

AdvanceWait(served) ==
    [d \in Guaranteed |->
        IF ~admitted[d] THEN 0
        ELSE IF d = served THEN 0
        ELSE IF waitSlots[d] < MaxWait THEN waitSlots[d] + 1
        ELSE MaxWait]

ClearToken ==
    /\ tokenDomain' = NoDomain
    /\ tokenEpoch' = 0
    /\ tokenSlot' = 0
    /\ tokenSealed' = FALSE
    /\ authoritySource' = "None"

Activate(d, source, sealed, frozenEpoch, armed) ==
    /\ d \in Domains
    /\ admitted[d]
    /\ activeDomain' = d
    /\ tokenDomain' = d
    /\ tokenEpoch' = frozenEpoch
    /\ tokenSlot' = slotIndex
    /\ tokenSealed' = sealed
    /\ authoritySource' = source
    /\ timerArmed' = armed
    /\ leaseIssued' = LeaseQuantum
    /\ leaseRemaining' = LeaseQuantum
    /\ leaseConsumed' = 0
    /\ handoffPending' = FALSE
    /\ UNCHANGED <<slotIndex, admitted, epoch, waitSlots, lastDeparted,
                    linuxProposal, linuxOffersReserved,
                    linuxExtensionRequested, linuxShadowSlot, halted,
                    protectionClaim>>

Init ==
    /\ slotIndex = 1
    /\ admitted = [d \in Domains |-> TRUE]
    /\ epoch = [d \in Domains |-> 1]
    /\ activeDomain = NoDomain
    /\ tokenDomain = NoDomain
    /\ tokenEpoch = 0
    /\ tokenSlot = 0
    /\ tokenSealed = FALSE
    /\ authoritySource = "None"
    /\ timerArmed = FALSE
    /\ leaseIssued = 0
    /\ leaseRemaining = 0
    /\ leaseConsumed = 0
    /\ waitSlots = [d \in Guaranteed |-> 0]
    /\ handoffPending = FALSE
    /\ lastDeparted = NoDomain
    /\ linuxProposal = BE1
    /\ linuxOffersReserved = FALSE
    /\ linuxExtensionRequested = FALSE
    /\ linuxShadowSlot = 1
    /\ halted = FALSE
    /\ protectionClaim = FALSE

LinuxNoise ==
    /\ ~halted
    /\ \E proposal \in DomainOrNone,
          offers \in BOOLEAN,
          extension \in BOOLEAN,
          shadow \in 1..FrameLength:
        /\ linuxProposal' = proposal
        /\ linuxOffersReserved' = offers
        /\ linuxExtensionRequested' = extension
        /\ linuxShadowSlot' = shadow
    /\ UNCHANGED <<slotIndex, admitted, epoch, activeDomain, tokenDomain,
                    tokenEpoch, tokenSlot, tokenSealed, authoritySource,
                    timerArmed, leaseIssued, leaseRemaining, leaseConsumed,
                    waitSlots, handoffPending, lastDeparted, halted,
                    protectionClaim>>

MonitorDispatchReserved ==
    /\ ~halted
    /\ activeDomain = NoDomain
    /\ FrameOwner \in Guaranteed
    /\ admitted[FrameOwner]
    /\ (FaultMode # "WaitForLinuxHint" \/ linuxOffersReserved)
    /\ Activate(FrameOwner, "Monitor", TRUE, epoch[FrameOwner], TRUE)

MonitorDispatchBestEffort ==
    /\ ~halted
    /\ activeDomain = NoDomain
    /\ FrameOwner = SlackSlot
    /\ linuxProposal \in BestEffort
    /\ admitted[linuxProposal]
    /\ Activate(linuxProposal, "Monitor", TRUE,
                epoch[linuxProposal], TRUE)

MonitorCloseUnavailableSlot ==
    /\ ~halted
    /\ activeDomain = NoDomain
    /\ \/ FrameOwner = SlackSlot
       \/ /\ FrameOwner \in Guaranteed
          /\ ~admitted[FrameOwner]
    /\ slotIndex' = NextSlot(slotIndex)
    /\ waitSlots' = AdvanceWait(NoDomain)
    /\ UNCHANGED <<admitted, epoch, activeDomain, tokenDomain, tokenEpoch,
                    tokenSlot, tokenSealed, authoritySource, timerArmed,
                    leaseIssued, leaseRemaining, leaseConsumed,
                    handoffPending, lastDeparted, linuxProposal,
                    linuxOffersReserved, linuxExtensionRequested,
                    linuxShadowSlot, halted, protectionClaim>>

HardwareConsume ==
    /\ ~halted
    /\ activeDomain # NoDomain
    /\ timerArmed
    /\ leaseRemaining > 1
    /\ leaseConsumed < LeaseQuantum + 1
    /\ leaseRemaining' = leaseRemaining - 1
    /\ leaseConsumed' = leaseConsumed + 1
    /\ UNCHANGED <<slotIndex, admitted, epoch, activeDomain, tokenDomain,
                    tokenEpoch, tokenSlot, tokenSealed, authoritySource,
                    timerArmed, leaseIssued, waitSlots, handoffPending,
                    lastDeparted, linuxProposal, linuxOffersReserved,
                    linuxExtensionRequested, linuxShadowSlot, halted,
                    protectionClaim>>

MonitorExpire ==
    /\ ~halted
    /\ FaultMode \notin {"ExpiryStillRunning", "StopAfterExpiry"}
    /\ activeDomain # NoDomain
    /\ timerArmed
    /\ leaseRemaining = 1
    /\ activeDomain' = NoDomain
    /\ ClearToken
    /\ timerArmed' = FALSE
    /\ leaseRemaining' = 0
    /\ leaseConsumed' = leaseConsumed + 1
    /\ waitSlots' = AdvanceWait(activeDomain)
    /\ slotIndex' = NextSlot(slotIndex)
    /\ handoffPending' = TRUE
    /\ lastDeparted' = activeDomain
    /\ UNCHANGED <<admitted, epoch, leaseIssued, linuxProposal,
                    linuxOffersReserved, linuxExtensionRequested,
                    linuxShadowSlot, halted, protectionClaim>>

UnsafeExpiryStillRunning ==
    /\ ~halted
    /\ FaultMode = "ExpiryStillRunning"
    /\ activeDomain # NoDomain
    /\ timerArmed
    /\ leaseRemaining = 1
    /\ leaseRemaining' = 0
    /\ leaseConsumed' = leaseConsumed + 1
    /\ UNCHANGED <<slotIndex, admitted, epoch, activeDomain, tokenDomain,
                    tokenEpoch, tokenSlot, tokenSealed, authoritySource,
                    timerArmed, leaseIssued, waitSlots, handoffPending,
                    lastDeparted, linuxProposal, linuxOffersReserved,
                    linuxExtensionRequested, linuxShadowSlot, halted,
                    protectionClaim>>

UnsafeStopAfterExpiry ==
    /\ ~halted
    /\ FaultMode = "StopAfterExpiry"
    /\ activeDomain # NoDomain
    /\ timerArmed
    /\ leaseRemaining = 1
    /\ activeDomain' = NoDomain
    /\ ClearToken
    /\ timerArmed' = FALSE
    /\ leaseRemaining' = 0
    /\ leaseConsumed' = leaseConsumed + 1
    /\ waitSlots' = AdvanceWait(activeDomain)
    /\ slotIndex' = NextSlot(slotIndex)
    /\ handoffPending' = TRUE
    /\ lastDeparted' = activeDomain
    /\ halted' = TRUE
    /\ UNCHANGED <<admitted, epoch, leaseIssued, linuxProposal,
                    linuxOffersReserved, linuxExtensionRequested,
                    linuxShadowSlot, protectionClaim>>

HardwareLeaseStep ==
    \/ HardwareConsume
    \/ MonitorExpire
    \/ UnsafeExpiryStillRunning
    \/ UnsafeStopAfterExpiry

MonitorRevoke(d) ==
    /\ ~halted
    /\ EnableRevocation
    /\ d \in Guaranteed \ {Mgmt}
    /\ admitted[d]
    /\ epoch[d] < MaxEpoch
    /\ admitted' = [admitted EXCEPT ![d] = FALSE]
    /\ epoch' = [epoch EXCEPT ![d] = @ + 1]
    /\ waitSlots' = [waitSlots EXCEPT ![d] = 0]
    /\ activeDomain' = IF activeDomain = d THEN NoDomain ELSE activeDomain
    /\ tokenDomain' = IF activeDomain = d THEN NoDomain ELSE tokenDomain
    /\ tokenEpoch' = IF activeDomain = d THEN 0 ELSE tokenEpoch
    /\ tokenSlot' = IF activeDomain = d THEN 0 ELSE tokenSlot
    /\ tokenSealed' = IF activeDomain = d THEN FALSE ELSE tokenSealed
    /\ authoritySource' =
        IF activeDomain = d THEN "None" ELSE authoritySource
    /\ timerArmed' = IF activeDomain = d THEN FALSE ELSE timerArmed
    /\ leaseRemaining' = IF activeDomain = d THEN 0 ELSE leaseRemaining
    /\ handoffPending' =
        IF activeDomain = d THEN TRUE ELSE handoffPending
    /\ lastDeparted' = IF activeDomain = d THEN d ELSE lastDeparted
    /\ UNCHANGED <<slotIndex, leaseIssued, leaseConsumed, linuxProposal,
                    linuxOffersReserved, linuxExtensionRequested,
                    linuxShadowSlot, halted, protectionClaim>>

UnsafeSkipReserved ==
    /\ ~halted
    /\ FaultMode = "SkipReserved"
    /\ activeDomain = NoDomain
    /\ FrameOwner \in Guaranteed
    /\ admitted[FrameOwner]
    /\ slotIndex' = NextSlot(slotIndex)
    /\ waitSlots' = AdvanceWait(NoDomain)
    /\ UNCHANGED <<admitted, epoch, activeDomain, tokenDomain, tokenEpoch,
                    tokenSlot, tokenSealed, authoritySource, timerArmed,
                    leaseIssued, leaseRemaining, leaseConsumed,
                    handoffPending, lastDeparted, linuxProposal,
                    linuxOffersReserved, linuxExtensionRequested,
                    linuxShadowSlot, halted, protectionClaim>>

UnsafeStealReserved ==
    /\ ~halted
    /\ FaultMode = "StealReserved"
    /\ activeDomain = NoDomain
    /\ FrameOwner \in Guaranteed
    /\ linuxProposal \in BestEffort
    /\ admitted[linuxProposal]
    /\ Activate(linuxProposal, "Monitor", TRUE,
                epoch[linuxProposal], TRUE)

UnsafeStaleEpoch ==
    /\ ~halted
    /\ FaultMode = "StaleEpoch"
    /\ activeDomain = NoDomain
    /\ FrameOwner \in Guaranteed
    /\ admitted[FrameOwner]
    /\ Activate(FrameOwner, "Monitor", TRUE, 0, TRUE)

UnsafeLinuxExtend ==
    /\ ~halted
    /\ FaultMode = "LinuxExtend"
    /\ activeDomain # NoDomain
    /\ linuxExtensionRequested
    /\ leaseRemaining < LeaseQuantum
    /\ leaseRemaining' = leaseRemaining + 1
    /\ UNCHANGED <<slotIndex, admitted, epoch, activeDomain, tokenDomain,
                    tokenEpoch, tokenSlot, tokenSealed, authoritySource,
                    timerArmed, leaseIssued, leaseConsumed, waitSlots,
                    handoffPending, lastDeparted, linuxProposal,
                    linuxOffersReserved, linuxExtensionRequested,
                    linuxShadowSlot, halted, protectionClaim>>

UnsafeRevokeManagement ==
    /\ ~halted
    /\ FaultMode = "RevokeManagement"
    /\ activeDomain = NoDomain
    /\ admitted[Mgmt]
    /\ epoch[Mgmt] < MaxEpoch
    /\ admitted' = [admitted EXCEPT ![Mgmt] = FALSE]
    /\ epoch' = [epoch EXCEPT ![Mgmt] = @ + 1]
    /\ waitSlots' = [waitSlots EXCEPT ![Mgmt] = 0]
    /\ UNCHANGED <<slotIndex, activeDomain, tokenDomain, tokenEpoch,
                    tokenSlot, tokenSealed, authoritySource, timerArmed,
                    leaseIssued, leaseRemaining, leaseConsumed,
                    handoffPending, lastDeparted, linuxProposal,
                    linuxOffersReserved, linuxExtensionRequested,
                    linuxShadowSlot, halted, protectionClaim>>

UnsafeNoTimer ==
    /\ ~halted
    /\ FaultMode = "NoTimer"
    /\ activeDomain = NoDomain
    /\ FrameOwner \in Guaranteed
    /\ admitted[FrameOwner]
    /\ Activate(FrameOwner, "Monitor", TRUE, epoch[FrameOwner], FALSE)

UnsafeLinuxMint ==
    /\ ~halted
    /\ FaultMode = "LinuxMint"
    /\ activeDomain = NoDomain
    /\ FrameOwner \in Guaranteed
    /\ admitted[FrameOwner]
    /\ Activate(FrameOwner, "Linux", FALSE, epoch[FrameOwner], TRUE)

UnsafeNext ==
    \/ UnsafeSkipReserved
    \/ UnsafeStealReserved
    \/ UnsafeStaleEpoch
    \/ UnsafeLinuxExtend
    \/ UnsafeRevokeManagement
    \/ UnsafeNoTimer
    \/ UnsafeLinuxMint

Next ==
    \/ LinuxNoise
    \/ MonitorDispatchReserved
    \/ MonitorDispatchBestEffort
    \/ MonitorCloseUnavailableSlot
    \/ HardwareLeaseStep
    \/ \E d \in Guaranteed \ {Mgmt}: MonitorRevoke(d)
    \/ UnsafeNext

Spec ==
    /\ Init
    /\ [][Next]_vars
    /\ WF_vars(MonitorDispatchReserved)
    /\ WF_vars(MonitorCloseUnavailableSlot)
    /\ WF_vars(HardwareLeaseStep)

TypeOK ==
    /\ slotIndex \in 1..FrameLength
    /\ admitted \in [Domains -> BOOLEAN]
    /\ epoch \in [Domains -> 1..MaxEpoch]
    /\ activeDomain \in DomainOrNone
    /\ tokenDomain \in DomainOrNone
    /\ tokenEpoch \in 0..MaxEpoch
    /\ tokenSlot \in 0..FrameLength
    /\ tokenSealed \in BOOLEAN
    /\ authoritySource \in {"None", "Monitor", "Linux"}
    /\ timerArmed \in BOOLEAN
    /\ leaseIssued \in 0..LeaseQuantum
    /\ leaseRemaining \in 0..LeaseQuantum
    /\ leaseConsumed \in 0..(LeaseQuantum + 1)
    /\ waitSlots \in [Guaranteed -> 0..MaxWait]
    /\ handoffPending \in BOOLEAN
    /\ lastDeparted \in DomainOrNone
    /\ linuxProposal \in DomainOrNone
    /\ linuxOffersReserved \in BOOLEAN
    /\ linuxExtensionRequested \in BOOLEAN
    /\ linuxShadowSlot \in 1..FrameLength
    /\ halted \in BOOLEAN
    /\ protectionClaim \in BOOLEAN
    /\ FaultMode \in FaultModes
    /\ EnableRevocation \in BOOLEAN
    /\ LeaseQuantum > 0
    /\ MaxEpoch > 1

NoRootRunWithoutLease ==
    activeDomain # NoDomain =>
        /\ admitted[activeDomain]
        /\ tokenSealed
        /\ authoritySource = "Monitor"
        /\ tokenDomain = activeDomain
        /\ tokenEpoch = epoch[activeDomain]
        /\ tokenSlot = slotIndex
        /\ timerArmed
        /\ leaseIssued = LeaseQuantum
        /\ leaseRemaining > 0
        /\ leaseConsumed < leaseIssued

NoRootBudgetOverrun ==
    /\ activeDomain # NoDomain => leaseRemaining > 0
    /\ leaseRemaining = 0 => activeDomain = NoDomain

LinuxCannotExtendRootLease ==
    activeDomain # NoDomain =>
        /\ leaseIssued = LeaseQuantum
        /\ leaseRemaining + leaseConsumed = leaseIssued

CurrentEpochOnly ==
    activeDomain # NoDomain => tokenEpoch = epoch[activeDomain]

ReservedSlotIntegrity ==
    (activeDomain # NoDomain /\ FrameOwner \in Guaranteed) =>
        activeDomain = FrameOwner

GuaranteedOnlyUsesReservedSlot ==
    activeDomain \in Guaranteed => FrameOwner = activeDomain

BestEffortOnlyUsesSlack ==
    activeDomain \in BestEffort => FrameOwner = SlackSlot

ExpiredOrRevokedAuthorityCleared ==
    handoffPending =>
        /\ activeDomain = NoDomain
        /\ tokenDomain = NoDomain
        /\ ~tokenSealed
        /\ ~timerArmed
        /\ leaseRemaining = 0

BoundedGuaranteedWait ==
    \A d \in Guaranteed: waitSlots[d] <= FrameLength

ManagementAlwaysAdmitted == admitted[Mgmt]

LinuxCannotMintRootAuthority ==
    activeDomain # NoDomain => authoritySource = "Monitor"

NoProtectionClaim == ~protectionClaim

OtherGuaranteedAdmitted ==
    \E d \in Guaranteed: admitted[d] /\ d # lastDeparted

AdmittedGuaranteedEventuallyRuns ==
    \A d \in Guaranteed:
        [](admitted[d] ~> (activeDomain = d \/ ~admitted[d]))

GuaranteedRecurringService ==
    \A d \in Guaranteed: []<>(activeDomain = d)

ManagementRecurringService == []<>(activeDomain = Mgmt)

TrustedHandoffProgress ==
    []((handoffPending /\ OtherGuaranteedAdmitted)
       ~> (\/ activeDomain # NoDomain /\ activeDomain # lastDeparted
           \/ ~OtherGuaranteedAdmitted))

=============================================================================
