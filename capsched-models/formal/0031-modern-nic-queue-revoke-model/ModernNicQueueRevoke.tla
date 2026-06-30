------------------------ MODULE ModernNicQueueRevoke ------------------------

VARIABLES
    phase,
    queueLive,
    epochFresh,
    memoryViewLive,
    iommuLive,
    irqRouteLive,
    queueBudget,
    serviceBudget,
    queueControlCap,
    representorForwardCap,
    serviceAuthority,
    submitBlocked,
    revokeStarted,
    revokeEpochBumped,
    irqMasked,
    iommuInvalidated,
    submitLedgerLive,
    descriptorLive,
    doorbellRung,
    dmaInFlight,
    completionPending,
    completionRunning,
    controlInFlight,
    representorInFlight,
    serviceWorkPending,
    drained,
    quarantined,
    queueReassigned,
    delivered,
    staleSubmit,
    staleCompletion,
    staleControl,
    staleRepresentor,
    staleService,
    earlyLedgerClear,
    reassignWithoutDrain,
    reassignWithoutIommu,
    quarantineDelivery

vars == <<phase, queueLive, epochFresh, memoryViewLive, iommuLive,
          irqRouteLive, queueBudget, serviceBudget, queueControlCap,
          representorForwardCap, serviceAuthority, submitBlocked,
          revokeStarted, revokeEpochBumped, irqMasked, iommuInvalidated,
          submitLedgerLive, descriptorLive, doorbellRung, dmaInFlight,
          completionPending, completionRunning, controlInFlight,
          representorInFlight, serviceWorkPending, drained, quarantined,
          queueReassigned, delivered, staleSubmit, staleCompletion,
          staleControl, staleRepresentor, staleService, earlyLedgerClear,
          reassignWithoutDrain, reassignWithoutIommu, quarantineDelivery>>

Phases == {
    "Start",
    "Outstanding",
    "Revoking",
    "Drained",
    "Quarantined",
    "Reassigned",
    "BadSubmitAfterRevoke",
    "BadCompletionAfterRevoke",
    "BadControlAfterRevoke",
    "BadRepresentorAfterRevoke",
    "BadServiceAfterRevoke",
    "BadLedgerClearBeforeDrain",
    "BadReassignWithoutDrain",
    "BadReassignWithoutIommu",
    "BadQuarantineDelivery"
}

TypeOK ==
    /\ phase \in Phases
    /\ queueLive \in BOOLEAN
    /\ epochFresh \in BOOLEAN
    /\ memoryViewLive \in BOOLEAN
    /\ iommuLive \in BOOLEAN
    /\ irqRouteLive \in BOOLEAN
    /\ queueBudget \in BOOLEAN
    /\ serviceBudget \in BOOLEAN
    /\ queueControlCap \in BOOLEAN
    /\ representorForwardCap \in BOOLEAN
    /\ serviceAuthority \in BOOLEAN
    /\ submitBlocked \in BOOLEAN
    /\ revokeStarted \in BOOLEAN
    /\ revokeEpochBumped \in BOOLEAN
    /\ irqMasked \in BOOLEAN
    /\ iommuInvalidated \in BOOLEAN
    /\ submitLedgerLive \in BOOLEAN
    /\ descriptorLive \in BOOLEAN
    /\ doorbellRung \in BOOLEAN
    /\ dmaInFlight \in BOOLEAN
    /\ completionPending \in BOOLEAN
    /\ completionRunning \in BOOLEAN
    /\ controlInFlight \in BOOLEAN
    /\ representorInFlight \in BOOLEAN
    /\ serviceWorkPending \in BOOLEAN
    /\ drained \in BOOLEAN
    /\ quarantined \in BOOLEAN
    /\ queueReassigned \in BOOLEAN
    /\ delivered \in BOOLEAN
    /\ staleSubmit \in BOOLEAN
    /\ staleCompletion \in BOOLEAN
    /\ staleControl \in BOOLEAN
    /\ staleRepresentor \in BOOLEAN
    /\ staleService \in BOOLEAN
    /\ earlyLedgerClear \in BOOLEAN
    /\ reassignWithoutDrain \in BOOLEAN
    /\ reassignWithoutIommu \in BOOLEAN
    /\ quarantineDelivery \in BOOLEAN

NoOutstanding ==
    /\ submitLedgerLive = FALSE
    /\ descriptorLive = FALSE
    /\ doorbellRung = FALSE
    /\ dmaInFlight = FALSE
    /\ completionPending = FALSE
    /\ completionRunning = FALSE
    /\ controlInFlight = FALSE
    /\ representorInFlight = FALSE
    /\ serviceWorkPending = FALSE

Init ==
    /\ phase = "Start"
    /\ queueLive = FALSE
    /\ epochFresh = FALSE
    /\ memoryViewLive = FALSE
    /\ iommuLive = FALSE
    /\ irqRouteLive = FALSE
    /\ queueBudget = FALSE
    /\ serviceBudget = FALSE
    /\ queueControlCap = FALSE
    /\ representorForwardCap = FALSE
    /\ serviceAuthority = FALSE
    /\ submitBlocked = FALSE
    /\ revokeStarted = FALSE
    /\ revokeEpochBumped = FALSE
    /\ irqMasked = FALSE
    /\ iommuInvalidated = FALSE
    /\ submitLedgerLive = FALSE
    /\ descriptorLive = FALSE
    /\ doorbellRung = FALSE
    /\ dmaInFlight = FALSE
    /\ completionPending = FALSE
    /\ completionRunning = FALSE
    /\ controlInFlight = FALSE
    /\ representorInFlight = FALSE
    /\ serviceWorkPending = FALSE
    /\ drained = FALSE
    /\ quarantined = FALSE
    /\ queueReassigned = FALSE
    /\ delivered = FALSE
    /\ staleSubmit = FALSE
    /\ staleCompletion = FALSE
    /\ staleControl = FALSE
    /\ staleRepresentor = FALSE
    /\ staleService = FALSE
    /\ earlyLedgerClear = FALSE
    /\ reassignWithoutDrain = FALSE
    /\ reassignWithoutIommu = FALSE
    /\ quarantineDelivery = FALSE

PrepareOutstanding ==
    /\ phase = "Start"
    /\ queueLive' = TRUE
    /\ epochFresh' = TRUE
    /\ memoryViewLive' = TRUE
    /\ iommuLive' = TRUE
    /\ irqRouteLive' = TRUE
    /\ queueBudget' = TRUE
    /\ serviceBudget' = TRUE
    /\ queueControlCap' = TRUE
    /\ representorForwardCap' = TRUE
    /\ serviceAuthority' = TRUE
    /\ submitLedgerLive' = TRUE
    /\ descriptorLive' = TRUE
    /\ doorbellRung' = TRUE
    /\ dmaInFlight' = TRUE
    /\ completionPending' = TRUE
    /\ controlInFlight' = TRUE
    /\ representorInFlight' = TRUE
    /\ serviceWorkPending' = TRUE
    /\ phase' = "Outstanding"
    /\ UNCHANGED <<submitBlocked, revokeStarted, revokeEpochBumped,
                    irqMasked, iommuInvalidated, completionRunning, drained,
                    quarantined, queueReassigned, delivered, staleSubmit,
                    staleCompletion, staleControl, staleRepresentor,
                    staleService, earlyLedgerClear, reassignWithoutDrain,
                    reassignWithoutIommu, quarantineDelivery>>

StartRevoke ==
    /\ phase = "Outstanding"
    /\ queueLive
    /\ revokeStarted' = TRUE
    /\ revokeEpochBumped' = TRUE
    /\ submitBlocked' = TRUE
    /\ irqMasked' = TRUE
    /\ queueLive' = FALSE
    /\ epochFresh' = FALSE
    /\ queueBudget' = FALSE
    /\ queueControlCap' = FALSE
    /\ representorForwardCap' = FALSE
    /\ phase' = "Revoking"
    /\ UNCHANGED <<memoryViewLive, iommuLive, irqRouteLive, serviceBudget,
                    serviceAuthority, iommuInvalidated, submitLedgerLive,
                    descriptorLive, doorbellRung, dmaInFlight,
                    completionPending, completionRunning, controlInFlight,
                    representorInFlight, serviceWorkPending, drained,
                    quarantined, queueReassigned, delivered, staleSubmit,
                    staleCompletion, staleControl, staleRepresentor,
                    staleService, earlyLedgerClear, reassignWithoutDrain,
                    reassignWithoutIommu, quarantineDelivery>>

DrainToQuiescent ==
    /\ phase = "Revoking"
    /\ revokeStarted
    /\ submitLedgerLive' = FALSE
    /\ descriptorLive' = FALSE
    /\ doorbellRung' = FALSE
    /\ dmaInFlight' = FALSE
    /\ completionPending' = FALSE
    /\ completionRunning' = FALSE
    /\ controlInFlight' = FALSE
    /\ representorInFlight' = FALSE
    /\ serviceWorkPending' = FALSE
    /\ memoryViewLive' = FALSE
    /\ iommuLive' = FALSE
    /\ irqRouteLive' = FALSE
    /\ iommuInvalidated' = TRUE
    /\ serviceBudget' = FALSE
    /\ drained' = TRUE
    /\ phase' = "Drained"
    /\ UNCHANGED <<queueLive, epochFresh, queueBudget, queueControlCap,
                    representorForwardCap, serviceAuthority, submitBlocked,
                    revokeStarted, revokeEpochBumped, irqMasked, quarantined,
                    queueReassigned, delivered, staleSubmit, staleCompletion,
                    staleControl, staleRepresentor, staleService,
                    earlyLedgerClear, reassignWithoutDrain,
                    reassignWithoutIommu, quarantineDelivery>>

QuarantineUnsettled ==
    /\ phase = "Revoking"
    /\ revokeStarted
    /\ submitLedgerLive' = FALSE
    /\ descriptorLive' = FALSE
    /\ doorbellRung' = FALSE
    /\ dmaInFlight' = FALSE
    /\ completionPending' = FALSE
    /\ completionRunning' = FALSE
    /\ controlInFlight' = FALSE
    /\ representorInFlight' = FALSE
    /\ serviceWorkPending' = FALSE
    /\ memoryViewLive' = FALSE
    /\ iommuLive' = FALSE
    /\ irqRouteLive' = FALSE
    /\ iommuInvalidated' = TRUE
    /\ serviceBudget' = FALSE
    /\ quarantined' = TRUE
    /\ phase' = "Quarantined"
    /\ UNCHANGED <<queueLive, epochFresh, queueBudget, queueControlCap,
                    representorForwardCap, serviceAuthority, submitBlocked,
                    revokeStarted, revokeEpochBumped, irqMasked, drained,
                    queueReassigned, delivered, staleSubmit, staleCompletion,
                    staleControl, staleRepresentor, staleService,
                    earlyLedgerClear, reassignWithoutDrain,
                    reassignWithoutIommu, quarantineDelivery>>

ReassignQueue ==
    /\ phase \in {"Drained", "Quarantined"}
    /\ NoOutstanding
    /\ iommuInvalidated
    /\ irqMasked
    /\ (drained \/ quarantined)
    /\ queueLive' = TRUE
    /\ epochFresh' = TRUE
    /\ memoryViewLive' = TRUE
    /\ iommuLive' = TRUE
    /\ irqRouteLive' = TRUE
    /\ queueBudget' = TRUE
    /\ queueReassigned' = TRUE
    /\ phase' = "Reassigned"
    /\ UNCHANGED <<serviceBudget, queueControlCap, representorForwardCap,
                    serviceAuthority, submitBlocked, revokeStarted,
                    revokeEpochBumped, irqMasked, iommuInvalidated,
                    submitLedgerLive, descriptorLive, doorbellRung,
                    dmaInFlight, completionPending, completionRunning,
                    controlInFlight, representorInFlight, serviceWorkPending,
                    drained, quarantined, delivered, staleSubmit,
                    staleCompletion, staleControl, staleRepresentor,
                    staleService, earlyLedgerClear, reassignWithoutDrain,
                    reassignWithoutIommu, quarantineDelivery>>

UnsafeSubmitAfterRevoke ==
    /\ phase = "Revoking"
    /\ revokeStarted
    /\ staleSubmit' = TRUE
    /\ descriptorLive' = TRUE
    /\ doorbellRung' = TRUE
    /\ dmaInFlight' = TRUE
    /\ phase' = "BadSubmitAfterRevoke"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    irqRouteLive, queueBudget, serviceBudget,
                    queueControlCap, representorForwardCap, serviceAuthority,
                    submitBlocked, revokeStarted, revokeEpochBumped,
                    irqMasked, iommuInvalidated, submitLedgerLive,
                    completionPending, completionRunning, controlInFlight,
                    representorInFlight, serviceWorkPending, drained,
                    quarantined, queueReassigned, delivered, staleCompletion,
                    staleControl, staleRepresentor, staleService,
                    earlyLedgerClear, reassignWithoutDrain,
                    reassignWithoutIommu, quarantineDelivery>>

UnsafeCompletionAfterRevoke ==
    /\ phase = "Revoking"
    /\ revokeStarted
    /\ completionPending
    /\ staleCompletion' = TRUE
    /\ completionRunning' = TRUE
    /\ delivered' = TRUE
    /\ phase' = "BadCompletionAfterRevoke"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    irqRouteLive, queueBudget, serviceBudget,
                    queueControlCap, representorForwardCap, serviceAuthority,
                    submitBlocked, revokeStarted, revokeEpochBumped,
                    irqMasked, iommuInvalidated, submitLedgerLive,
                    descriptorLive, doorbellRung, dmaInFlight,
                    completionPending, controlInFlight, representorInFlight,
                    serviceWorkPending, drained, quarantined,
                    queueReassigned, staleSubmit, staleControl,
                    staleRepresentor, staleService, earlyLedgerClear,
                    reassignWithoutDrain, reassignWithoutIommu,
                    quarantineDelivery>>

UnsafeControlAfterRevoke ==
    /\ phase = "Revoking"
    /\ revokeStarted
    /\ staleControl' = TRUE
    /\ controlInFlight' = TRUE
    /\ phase' = "BadControlAfterRevoke"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    irqRouteLive, queueBudget, serviceBudget,
                    queueControlCap, representorForwardCap, serviceAuthority,
                    submitBlocked, revokeStarted, revokeEpochBumped,
                    irqMasked, iommuInvalidated, submitLedgerLive,
                    descriptorLive, doorbellRung, dmaInFlight,
                    completionPending, completionRunning,
                    representorInFlight, serviceWorkPending, drained,
                    quarantined, queueReassigned, delivered, staleSubmit,
                    staleCompletion, staleRepresentor, staleService,
                    earlyLedgerClear, reassignWithoutDrain,
                    reassignWithoutIommu, quarantineDelivery>>

UnsafeRepresentorAfterRevoke ==
    /\ phase = "Revoking"
    /\ revokeStarted
    /\ staleRepresentor' = TRUE
    /\ representorInFlight' = TRUE
    /\ phase' = "BadRepresentorAfterRevoke"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    irqRouteLive, queueBudget, serviceBudget,
                    queueControlCap, representorForwardCap, serviceAuthority,
                    submitBlocked, revokeStarted, revokeEpochBumped,
                    irqMasked, iommuInvalidated, submitLedgerLive,
                    descriptorLive, doorbellRung, dmaInFlight,
                    completionPending, completionRunning, controlInFlight,
                    serviceWorkPending, drained, quarantined,
                    queueReassigned, delivered, staleSubmit, staleCompletion,
                    staleControl, staleService, earlyLedgerClear,
                    reassignWithoutDrain, reassignWithoutIommu,
                    quarantineDelivery>>

UnsafeServiceAfterRevoke ==
    /\ phase = "Revoking"
    /\ revokeStarted
    /\ staleService' = TRUE
    /\ serviceWorkPending' = TRUE
    /\ phase' = "BadServiceAfterRevoke"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    irqRouteLive, queueBudget, serviceBudget,
                    queueControlCap, representorForwardCap, serviceAuthority,
                    submitBlocked, revokeStarted, revokeEpochBumped,
                    irqMasked, iommuInvalidated, submitLedgerLive,
                    descriptorLive, doorbellRung, dmaInFlight,
                    completionPending, completionRunning, controlInFlight,
                    representorInFlight, drained, quarantined,
                    queueReassigned, delivered, staleSubmit, staleCompletion,
                    staleControl, staleRepresentor, earlyLedgerClear,
                    reassignWithoutDrain, reassignWithoutIommu,
                    quarantineDelivery>>

UnsafeClearLedgerBeforeDrain ==
    /\ phase = "Revoking"
    /\ dmaInFlight
    /\ submitLedgerLive' = FALSE
    /\ earlyLedgerClear' = TRUE
    /\ phase' = "BadLedgerClearBeforeDrain"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    irqRouteLive, queueBudget, serviceBudget,
                    queueControlCap, representorForwardCap, serviceAuthority,
                    submitBlocked, revokeStarted, revokeEpochBumped,
                    irqMasked, iommuInvalidated, descriptorLive, doorbellRung,
                    dmaInFlight, completionPending, completionRunning,
                    controlInFlight, representorInFlight, serviceWorkPending,
                    drained, quarantined, queueReassigned, delivered,
                    staleSubmit, staleCompletion, staleControl,
                    staleRepresentor, staleService, reassignWithoutDrain,
                    reassignWithoutIommu, quarantineDelivery>>

UnsafeReassignWithoutDrain ==
    /\ phase = "Revoking"
    /\ (dmaInFlight \/ completionPending \/ controlInFlight \/
        representorInFlight \/ serviceWorkPending)
    /\ reassignWithoutDrain' = TRUE
    /\ queueReassigned' = TRUE
    /\ queueLive' = TRUE
    /\ epochFresh' = TRUE
    /\ phase' = "BadReassignWithoutDrain"
    /\ UNCHANGED <<memoryViewLive, iommuLive, irqRouteLive, queueBudget,
                    serviceBudget, queueControlCap, representorForwardCap,
                    serviceAuthority, submitBlocked, revokeStarted,
                    revokeEpochBumped, irqMasked, iommuInvalidated,
                    submitLedgerLive, descriptorLive, doorbellRung,
                    dmaInFlight, completionPending, completionRunning,
                    controlInFlight, representorInFlight, serviceWorkPending,
                    drained, quarantined, delivered, staleSubmit,
                    staleCompletion, staleControl, staleRepresentor,
                    staleService, earlyLedgerClear, reassignWithoutIommu,
                    quarantineDelivery>>

UnsafeReassignWithoutIommu ==
    /\ phase = "Revoking"
    /\ reassignWithoutIommu' = TRUE
    /\ queueReassigned' = TRUE
    /\ queueLive' = TRUE
    /\ epochFresh' = TRUE
    /\ submitLedgerLive' = FALSE
    /\ descriptorLive' = FALSE
    /\ doorbellRung' = FALSE
    /\ dmaInFlight' = FALSE
    /\ completionPending' = FALSE
    /\ completionRunning' = FALSE
    /\ controlInFlight' = FALSE
    /\ representorInFlight' = FALSE
    /\ serviceWorkPending' = FALSE
    /\ phase' = "BadReassignWithoutIommu"
    /\ UNCHANGED <<memoryViewLive, iommuLive, irqRouteLive, queueBudget,
                    serviceBudget, queueControlCap, representorForwardCap,
                    serviceAuthority, submitBlocked, revokeStarted,
                    revokeEpochBumped, irqMasked, iommuInvalidated, drained,
                    quarantined, delivered, staleSubmit, staleCompletion,
                    staleControl, staleRepresentor, staleService,
                    earlyLedgerClear, reassignWithoutDrain,
                    quarantineDelivery>>

UnsafeQuarantineDelivery ==
    /\ phase = "Quarantined"
    /\ quarantined
    /\ delivered' = TRUE
    /\ quarantineDelivery' = TRUE
    /\ phase' = "BadQuarantineDelivery"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    irqRouteLive, queueBudget, serviceBudget,
                    queueControlCap, representorForwardCap, serviceAuthority,
                    submitBlocked, revokeStarted, revokeEpochBumped,
                    irqMasked, iommuInvalidated, submitLedgerLive,
                    descriptorLive, doorbellRung, dmaInFlight,
                    completionPending, completionRunning, controlInFlight,
                    representorInFlight, serviceWorkPending, drained,
                    quarantined, queueReassigned, staleSubmit,
                    staleCompletion, staleControl, staleRepresentor,
                    staleService, earlyLedgerClear, reassignWithoutDrain,
                    reassignWithoutIommu>>

SafeNext ==
    \/ PrepareOutstanding
    \/ StartRevoke
    \/ DrainToQuiescent
    \/ QuarantineUnsettled
    \/ ReassignQueue

UnsafeSubmitAfterRevokeNext ==
    \/ PrepareOutstanding
    \/ StartRevoke
    \/ UnsafeSubmitAfterRevoke

UnsafeCompletionAfterRevokeNext ==
    \/ PrepareOutstanding
    \/ StartRevoke
    \/ UnsafeCompletionAfterRevoke

UnsafeControlAfterRevokeNext ==
    \/ PrepareOutstanding
    \/ StartRevoke
    \/ UnsafeControlAfterRevoke

UnsafeRepresentorAfterRevokeNext ==
    \/ PrepareOutstanding
    \/ StartRevoke
    \/ UnsafeRepresentorAfterRevoke

UnsafeServiceAfterRevokeNext ==
    \/ PrepareOutstanding
    \/ StartRevoke
    \/ UnsafeServiceAfterRevoke

UnsafeClearLedgerBeforeDrainNext ==
    \/ PrepareOutstanding
    \/ StartRevoke
    \/ UnsafeClearLedgerBeforeDrain

UnsafeReassignWithoutDrainNext ==
    \/ PrepareOutstanding
    \/ StartRevoke
    \/ UnsafeReassignWithoutDrain

UnsafeReassignWithoutIommuNext ==
    \/ PrepareOutstanding
    \/ StartRevoke
    \/ UnsafeReassignWithoutIommu

UnsafeQuarantineDeliveryNext ==
    \/ PrepareOutstanding
    \/ StartRevoke
    \/ QuarantineUnsettled
    \/ UnsafeQuarantineDelivery

SafeSpec == Init /\ [][SafeNext]_vars
UnsafeSubmitAfterRevokeSpec == Init /\ [][UnsafeSubmitAfterRevokeNext]_vars
UnsafeCompletionAfterRevokeSpec == Init /\ [][UnsafeCompletionAfterRevokeNext]_vars
UnsafeControlAfterRevokeSpec == Init /\ [][UnsafeControlAfterRevokeNext]_vars
UnsafeRepresentorAfterRevokeSpec == Init /\ [][UnsafeRepresentorAfterRevokeNext]_vars
UnsafeServiceAfterRevokeSpec == Init /\ [][UnsafeServiceAfterRevokeNext]_vars
UnsafeClearLedgerBeforeDrainSpec == Init /\ [][UnsafeClearLedgerBeforeDrainNext]_vars
UnsafeReassignWithoutDrainSpec == Init /\ [][UnsafeReassignWithoutDrainNext]_vars
UnsafeReassignWithoutIommuSpec == Init /\ [][UnsafeReassignWithoutIommuNext]_vars
UnsafeQuarantineDeliverySpec == Init /\ [][UnsafeQuarantineDeliveryNext]_vars

NoSubmitAfterRevoke == ~staleSubmit

NoDeliveryAfterRevoke ==
    /\ ~staleCompletion
    /\ ~(revokeStarted /\ delivered)

NoControlAfterRevoke == ~staleControl

NoRepresentorForwardAfterRevoke == ~staleRepresentor

NoServiceWorkAfterRevoke == ~staleService

NoLedgerClearBeforeDrain ==
    ~earlyLedgerClear

NoReassignBeforeDrainOrQuarantine ==
    queueReassigned =>
        /\ (drained \/ quarantined)
        /\ NoOutstanding
        /\ ~reassignWithoutDrain

NoReassignWithoutIommuAndIrqInvalidation ==
    queueReassigned =>
        /\ iommuInvalidated
        /\ irqMasked
        /\ ~reassignWithoutIommu

NoQuarantineDelivery ==
    /\ ~quarantineDelivery
    /\ ~(quarantined /\ delivered)

NoOutstandingAfterTerminal ==
    (drained \/ quarantined \/ queueReassigned) => NoOutstanding

NoOldControlAuthorityAfterRevoke ==
    (revokeStarted /\ ~queueReassigned) =>
        /\ queueControlCap = FALSE
        /\ representorForwardCap = FALSE
        /\ queueBudget = FALSE

=============================================================================
