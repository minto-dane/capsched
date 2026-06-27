---------------------- MODULE AggregateQueueSettlement ----------------------
EXTENDS Naturals

VARIABLES
    phase,
    queueLive,
    epochFresh,
    iommuLive,
    irqLive,
    submitBudget,
    serviceBudget,
    descriptorPublished,
    tailRung,
    submitAuthorized,
    submittedWithoutBudget,
    inFlight,
    ledgerLive,
    completionPending,
    workPending,
    runningCompletion,
    dmaObserved,
    delivered,
    dropped,
    revoked,
    overwritten,
    ambientUsed,
    foreignCompletion,
    mergedAgain

vars == <<phase, queueLive, epochFresh, iommuLive, irqLive, submitBudget,
          serviceBudget, descriptorPublished, tailRung, submitAuthorized,
          submittedWithoutBudget, inFlight, ledgerLive, completionPending,
          workPending, runningCompletion, dmaObserved, delivered, dropped,
          revoked, overwritten, ambientUsed, foreignCompletion, mergedAgain>>

Phases == {
    "Start",
    "LeaseReady",
    "Submitted",
    "CompletionPending",
    "CompletionRunning",
    "Settled",
    "Revoked",
    "BadDoorbellNoLease",
    "BadSubmitNoBudget",
    "BadDmaNoIommu",
    "BadCompleteNoLedger",
    "BadCompleteNoServiceBudget",
    "BadDeliverAfterRevoke",
    "BadOverwriteLedger",
    "BadAmbientCompletion",
    "BadForeignCompletion"
}

TypeOK ==
    /\ phase \in Phases
    /\ queueLive \in BOOLEAN
    /\ epochFresh \in BOOLEAN
    /\ iommuLive \in BOOLEAN
    /\ irqLive \in BOOLEAN
    /\ submitBudget \in BOOLEAN
    /\ serviceBudget \in BOOLEAN
    /\ descriptorPublished \in BOOLEAN
    /\ tailRung \in BOOLEAN
    /\ submitAuthorized \in BOOLEAN
    /\ submittedWithoutBudget \in BOOLEAN
    /\ inFlight \in BOOLEAN
    /\ ledgerLive \in BOOLEAN
    /\ completionPending \in BOOLEAN
    /\ workPending \in BOOLEAN
    /\ runningCompletion \in BOOLEAN
    /\ dmaObserved \in BOOLEAN
    /\ delivered \in BOOLEAN
    /\ dropped \in BOOLEAN
    /\ revoked \in BOOLEAN
    /\ overwritten \in BOOLEAN
    /\ ambientUsed \in BOOLEAN
    /\ foreignCompletion \in BOOLEAN
    /\ mergedAgain \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ queueLive = FALSE
    /\ epochFresh = FALSE
    /\ iommuLive = FALSE
    /\ irqLive = FALSE
    /\ submitBudget = FALSE
    /\ serviceBudget = FALSE
    /\ descriptorPublished = FALSE
    /\ tailRung = FALSE
    /\ submitAuthorized = FALSE
    /\ submittedWithoutBudget = FALSE
    /\ inFlight = FALSE
    /\ ledgerLive = FALSE
    /\ completionPending = FALSE
    /\ workPending = FALSE
    /\ runningCompletion = FALSE
    /\ dmaObserved = FALSE
    /\ delivered = FALSE
    /\ dropped = FALSE
    /\ revoked = FALSE
    /\ overwritten = FALSE
    /\ ambientUsed = FALSE
    /\ foreignCompletion = FALSE
    /\ mergedAgain = FALSE

PrepareQueueLease ==
    /\ phase = "Start"
    /\ queueLive' = TRUE
    /\ epochFresh' = TRUE
    /\ iommuLive' = TRUE
    /\ irqLive' = TRUE
    /\ submitBudget' = TRUE
    /\ serviceBudget' = TRUE
    /\ phase' = "LeaseReady"
    /\ UNCHANGED <<descriptorPublished, tailRung, submitAuthorized,
                    submittedWithoutBudget, inFlight, ledgerLive,
                    completionPending, workPending, runningCompletion,
                    dmaObserved, delivered, dropped, revoked, overwritten,
                    ambientUsed, foreignCompletion, mergedAgain>>

SubmitDescriptor ==
    /\ phase = "LeaseReady"
    /\ queueLive
    /\ epochFresh
    /\ iommuLive
    /\ irqLive
    /\ submitBudget
    /\ serviceBudget
    /\ ~revoked
    /\ ~inFlight
    /\ descriptorPublished' = TRUE
    /\ tailRung' = TRUE
    /\ submitAuthorized' = TRUE
    /\ submitBudget' = FALSE
    /\ inFlight' = TRUE
    /\ ledgerLive' = TRUE
    /\ phase' = "Submitted"
    /\ UNCHANGED <<queueLive, epochFresh, iommuLive, irqLive, serviceBudget,
                    submittedWithoutBudget, completionPending, workPending,
                    runningCompletion, dmaObserved, delivered, dropped,
                    revoked, overwritten, ambientUsed, foreignCompletion,
                    mergedAgain>>

DeviceCompletionEvent ==
    /\ phase = "Submitted"
    /\ inFlight
    /\ ledgerLive
    /\ submitAuthorized
    /\ queueLive
    /\ iommuLive
    /\ irqLive
    /\ completionPending' = TRUE
    /\ workPending' = TRUE
    /\ dmaObserved' = TRUE
    /\ phase' = "CompletionPending"
    /\ UNCHANGED <<queueLive, epochFresh, iommuLive, irqLive, submitBudget,
                    serviceBudget, descriptorPublished, tailRung,
                    submitAuthorized, submittedWithoutBudget, inFlight,
                    ledgerLive, runningCompletion, delivered, dropped,
                    revoked, overwritten, ambientUsed, foreignCompletion,
                    mergedAgain>>

MergeDuplicateCompletionEvent ==
    /\ phase = "CompletionPending"
    /\ completionPending
    /\ workPending
    /\ ledgerLive
    /\ mergedAgain' = TRUE
    /\ UNCHANGED <<phase, queueLive, epochFresh, iommuLive, irqLive,
                    submitBudget, serviceBudget, descriptorPublished,
                    tailRung, submitAuthorized, submittedWithoutBudget,
                    inFlight, ledgerLive, completionPending, workPending,
                    runningCompletion, dmaObserved, delivered, dropped,
                    revoked, overwritten, ambientUsed, foreignCompletion>>

RunMergedCompletion ==
    /\ phase = "CompletionPending"
    /\ completionPending
    /\ workPending
    /\ ledgerLive
    /\ serviceBudget
    /\ ~ambientUsed
    /\ workPending' = FALSE
    /\ runningCompletion' = TRUE
    /\ phase' = "CompletionRunning"
    /\ UNCHANGED <<queueLive, epochFresh, iommuLive, irqLive, submitBudget,
                    serviceBudget, descriptorPublished, tailRung,
                    submitAuthorized, submittedWithoutBudget, inFlight,
                    ledgerLive, completionPending, dmaObserved, delivered,
                    dropped, revoked, overwritten, ambientUsed,
                    foreignCompletion, mergedAgain>>

SettleCompletion ==
    /\ phase = "CompletionRunning"
    /\ runningCompletion
    /\ ledgerLive
    /\ serviceBudget
    /\ queueLive
    /\ ~revoked
    /\ descriptorPublished' = FALSE
    /\ tailRung' = FALSE
    /\ submitAuthorized' = FALSE
    /\ inFlight' = FALSE
    /\ ledgerLive' = FALSE
    /\ completionPending' = FALSE
    /\ runningCompletion' = FALSE
    /\ dmaObserved' = FALSE
    /\ delivered' = TRUE
    /\ phase' = "Settled"
    /\ UNCHANGED <<queueLive, epochFresh, iommuLive, irqLive, submitBudget,
                    serviceBudget, submittedWithoutBudget, workPending,
                    dropped, revoked, overwritten, ambientUsed,
                    foreignCompletion, mergedAgain>>

RevokeQueue ==
    /\ phase \in {"LeaseReady", "Submitted", "CompletionPending",
                  "CompletionRunning"}
    /\ queueLive
    /\ queueLive' = FALSE
    /\ epochFresh' = FALSE
    /\ iommuLive' = FALSE
    /\ irqLive' = FALSE
    /\ submitBudget' = FALSE
    /\ serviceBudget' = FALSE
    /\ descriptorPublished' = FALSE
    /\ tailRung' = FALSE
    /\ submitAuthorized' = FALSE
    /\ inFlight' = FALSE
    /\ ledgerLive' = FALSE
    /\ completionPending' = FALSE
    /\ workPending' = FALSE
    /\ runningCompletion' = FALSE
    /\ dmaObserved' = FALSE
    /\ dropped' = TRUE
    /\ revoked' = TRUE
    /\ phase' = "Revoked"
    /\ UNCHANGED <<submittedWithoutBudget, delivered, overwritten,
                    ambientUsed, foreignCompletion, mergedAgain>>

UnsafeDoorbellNoLease ==
    /\ phase = "Start"
    /\ descriptorPublished' = TRUE
    /\ tailRung' = TRUE
    /\ phase' = "BadDoorbellNoLease"
    /\ UNCHANGED <<queueLive, epochFresh, iommuLive, irqLive, submitBudget,
                    serviceBudget, submitAuthorized, submittedWithoutBudget,
                    inFlight, ledgerLive, completionPending, workPending,
                    runningCompletion, dmaObserved, delivered, dropped,
                    revoked, overwritten, ambientUsed, foreignCompletion,
                    mergedAgain>>

UnsafeSubmitNoBudget ==
    /\ phase = "LeaseReady"
    /\ queueLive
    /\ epochFresh
    /\ iommuLive
    /\ irqLive
    /\ submitBudget' = FALSE
    /\ submittedWithoutBudget' = TRUE
    /\ descriptorPublished' = TRUE
    /\ tailRung' = TRUE
    /\ inFlight' = TRUE
    /\ ledgerLive' = TRUE
    /\ phase' = "BadSubmitNoBudget"
    /\ UNCHANGED <<queueLive, epochFresh, iommuLive, irqLive, serviceBudget,
                    submitAuthorized, completionPending, workPending,
                    runningCompletion, dmaObserved, delivered, dropped,
                    revoked, overwritten, ambientUsed, foreignCompletion,
                    mergedAgain>>

UnsafeDmaNoIommu ==
    /\ phase = "Submitted"
    /\ inFlight
    /\ ledgerLive
    /\ iommuLive' = FALSE
    /\ dmaObserved' = TRUE
    /\ phase' = "BadDmaNoIommu"
    /\ UNCHANGED <<queueLive, epochFresh, irqLive, submitBudget,
                    serviceBudget, descriptorPublished, tailRung,
                    submitAuthorized, submittedWithoutBudget, inFlight,
                    ledgerLive, completionPending, workPending,
                    runningCompletion, delivered, dropped, revoked,
                    overwritten, ambientUsed, foreignCompletion, mergedAgain>>

UnsafeCompleteNoLedger ==
    /\ phase = "CompletionPending"
    /\ completionPending
    /\ ledgerLive' = FALSE
    /\ workPending' = FALSE
    /\ runningCompletion' = TRUE
    /\ phase' = "BadCompleteNoLedger"
    /\ UNCHANGED <<queueLive, epochFresh, iommuLive, irqLive, submitBudget,
                    serviceBudget, descriptorPublished, tailRung,
                    submitAuthorized, submittedWithoutBudget, inFlight,
                    completionPending, dmaObserved, delivered, dropped,
                    revoked, overwritten, ambientUsed, foreignCompletion,
                    mergedAgain>>

UnsafeCompleteNoServiceBudget ==
    /\ phase = "CompletionPending"
    /\ completionPending
    /\ ledgerLive
    /\ serviceBudget' = FALSE
    /\ workPending' = FALSE
    /\ runningCompletion' = TRUE
    /\ phase' = "BadCompleteNoServiceBudget"
    /\ UNCHANGED <<queueLive, epochFresh, iommuLive, irqLive, submitBudget,
                    descriptorPublished, tailRung, submitAuthorized,
                    submittedWithoutBudget, inFlight, ledgerLive,
                    completionPending, dmaObserved, delivered, dropped,
                    revoked, overwritten, ambientUsed, foreignCompletion,
                    mergedAgain>>

UnsafeDeliverAfterRevoke ==
    /\ phase \in {"Submitted", "CompletionPending"}
    /\ queueLive' = FALSE
    /\ epochFresh' = FALSE
    /\ iommuLive' = FALSE
    /\ irqLive' = FALSE
    /\ revoked' = TRUE
    /\ delivered' = TRUE
    /\ phase' = "BadDeliverAfterRevoke"
    /\ UNCHANGED <<submitBudget, serviceBudget, descriptorPublished, tailRung,
                    submitAuthorized, submittedWithoutBudget, inFlight,
                    ledgerLive, completionPending, workPending,
                    runningCompletion, dmaObserved, dropped, overwritten,
                    ambientUsed, foreignCompletion, mergedAgain>>

UnsafeOverwriteLedger ==
    /\ phase = "CompletionPending"
    /\ completionPending
    /\ ledgerLive
    /\ overwritten' = TRUE
    /\ phase' = "BadOverwriteLedger"
    /\ UNCHANGED <<queueLive, epochFresh, iommuLive, irqLive, submitBudget,
                    serviceBudget, descriptorPublished, tailRung,
                    submitAuthorized, submittedWithoutBudget, inFlight,
                    ledgerLive, completionPending, workPending,
                    runningCompletion, dmaObserved, delivered, dropped,
                    revoked, ambientUsed, foreignCompletion, mergedAgain>>

UnsafeAmbientCompletion ==
    /\ phase = "CompletionPending"
    /\ completionPending
    /\ ledgerLive
    /\ ambientUsed' = TRUE
    /\ workPending' = FALSE
    /\ runningCompletion' = TRUE
    /\ phase' = "BadAmbientCompletion"
    /\ UNCHANGED <<queueLive, epochFresh, iommuLive, irqLive, submitBudget,
                    serviceBudget, descriptorPublished, tailRung,
                    submitAuthorized, submittedWithoutBudget, inFlight,
                    ledgerLive, completionPending, dmaObserved, delivered,
                    dropped, revoked, overwritten, foreignCompletion,
                    mergedAgain>>

UnsafeForeignCompletion ==
    /\ phase = "Submitted"
    /\ inFlight
    /\ ledgerLive
    /\ foreignCompletion' = TRUE
    /\ completionPending' = TRUE
    /\ workPending' = TRUE
    /\ phase' = "BadForeignCompletion"
    /\ UNCHANGED <<queueLive, epochFresh, iommuLive, irqLive, submitBudget,
                    serviceBudget, descriptorPublished, tailRung,
                    submitAuthorized, submittedWithoutBudget, inFlight,
                    ledgerLive, runningCompletion, dmaObserved, delivered,
                    dropped, revoked, overwritten, ambientUsed, mergedAgain>>

SafeNext ==
    \/ PrepareQueueLease
    \/ SubmitDescriptor
    \/ DeviceCompletionEvent
    \/ MergeDuplicateCompletionEvent
    \/ RunMergedCompletion
    \/ SettleCompletion
    \/ RevokeQueue

UnsafeDoorbellSpec ==
    Init /\ [][SafeNext \/ UnsafeDoorbellNoLease]_vars

UnsafeSubmitNoBudgetSpec ==
    Init /\ [][SafeNext \/ UnsafeSubmitNoBudget]_vars

UnsafeDmaNoIommuSpec ==
    Init /\ [][SafeNext \/ UnsafeDmaNoIommu]_vars

UnsafeCompleteNoLedgerSpec ==
    Init /\ [][SafeNext \/ UnsafeCompleteNoLedger]_vars

UnsafeCompleteNoServiceBudgetSpec ==
    Init /\ [][SafeNext \/ UnsafeCompleteNoServiceBudget]_vars

UnsafeDeliverAfterRevokeSpec ==
    Init /\ [][SafeNext \/ UnsafeDeliverAfterRevoke]_vars

UnsafeOverwriteSpec ==
    Init /\ [][SafeNext \/ UnsafeOverwriteLedger]_vars

UnsafeAmbientSpec ==
    Init /\ [][SafeNext \/ UnsafeAmbientCompletion]_vars

UnsafeForeignSpec ==
    Init /\ [][SafeNext \/ UnsafeForeignCompletion]_vars

SafeSpec == Init /\ [][SafeNext]_vars

NoTailWithoutLiveQueueLease ==
    tailRung =>
        /\ queueLive
        /\ epochFresh
        /\ submitAuthorized
        /\ descriptorPublished

NoSubmitWithoutBudget ==
    ~submittedWithoutBudget

NoDmaWithoutIommuAndLedger ==
    dmaObserved =>
        /\ queueLive
        /\ iommuLive
        /\ ledgerLive
        /\ submitAuthorized

NoCompletionWithoutLedgerAndServiceBudget ==
    runningCompletion =>
        /\ ledgerLive
        /\ serviceBudget
        /\ completionPending

NoDeliveryAfterRevoke ==
    delivered => ~revoked

NoLedgerOverwrite ==
    ~overwritten

NoAmbientCompletionAuthority ==
    ~ambientUsed

NoForeignCompletion ==
    ~foreignCompletion

NoOutstandingAfterRevoke ==
    revoked =>
        /\ ~inFlight
        /\ ~ledgerLive
        /\ ~completionPending
        /\ ~workPending
        /\ ~runningCompletion
        /\ ~descriptorPublished
        /\ ~tailRung
        /\ ~dmaObserved

=============================================================================
