---------------------- MODULE XdpAfxdpMemoryOwnership ----------------------
EXTENDS Naturals

VARIABLES
    phase,
    queueLive,
    epochFresh,
    memoryViewLive,
    iommuLive,
    queueBudget,
    serviceBudget,
    pagePoolCap,
    pagePoolOwned,
    pagePoolDmaLive,
    pagePoolReturned,
    xskCap,
    xskPoolBound,
    xskUmemOwned,
    xskDescFrozen,
    xskDmaLive,
    xskReturned,
    submitClass,
    submitted,
    xdpTxSubmitted,
    afxdpSubmitted,
    ledgerLive,
    descriptorPublished,
    doorbellRung,
    completionPending,
    completionRunning,
    completed,
    returned,
    revoked,
    submitWithoutBudget,
    ambientDesc,
    crossDomainDma,
    doubleReturn,
    staleReturn

vars == <<phase, queueLive, epochFresh, memoryViewLive, iommuLive,
          queueBudget, serviceBudget, pagePoolCap, pagePoolOwned,
          pagePoolDmaLive, pagePoolReturned, xskCap, xskPoolBound,
          xskUmemOwned, xskDescFrozen, xskDmaLive, xskReturned,
          submitClass, submitted, xdpTxSubmitted, afxdpSubmitted,
          ledgerLive, descriptorPublished, doorbellRung, completionPending,
          completionRunning, completed, returned, revoked,
          submitWithoutBudget, ambientDesc, crossDomainDma, doubleReturn,
          staleReturn>>

SubmitClasses == {"None", "XDP_TX_PAGE_POOL", "AF_XDP"}

Phases == {
    "Start",
    "PagePoolReady",
    "XSKReady",
    "Submitted",
    "CompletionPending",
    "CompletionRunning",
    "Returned",
    "Revoked",
    "BadXDPTxNoPagePool",
    "BadAFXDPNoXSK",
    "BadDmaNoMemoryView",
    "BadAmbientXSKDesc",
    "BadCrossDomainDma",
    "BadCompletionNoLedger",
    "BadDoubleReturn",
    "BadReturnAfterRevoke",
    "BadSubmitNoBudget"
}

TypeOK ==
    /\ phase \in Phases
    /\ queueLive \in BOOLEAN
    /\ epochFresh \in BOOLEAN
    /\ memoryViewLive \in BOOLEAN
    /\ iommuLive \in BOOLEAN
    /\ queueBudget \in BOOLEAN
    /\ serviceBudget \in BOOLEAN
    /\ pagePoolCap \in BOOLEAN
    /\ pagePoolOwned \in BOOLEAN
    /\ pagePoolDmaLive \in BOOLEAN
    /\ pagePoolReturned \in BOOLEAN
    /\ xskCap \in BOOLEAN
    /\ xskPoolBound \in BOOLEAN
    /\ xskUmemOwned \in BOOLEAN
    /\ xskDescFrozen \in BOOLEAN
    /\ xskDmaLive \in BOOLEAN
    /\ xskReturned \in BOOLEAN
    /\ submitClass \in SubmitClasses
    /\ submitted \in BOOLEAN
    /\ xdpTxSubmitted \in BOOLEAN
    /\ afxdpSubmitted \in BOOLEAN
    /\ ledgerLive \in BOOLEAN
    /\ descriptorPublished \in BOOLEAN
    /\ doorbellRung \in BOOLEAN
    /\ completionPending \in BOOLEAN
    /\ completionRunning \in BOOLEAN
    /\ completed \in BOOLEAN
    /\ returned \in BOOLEAN
    /\ revoked \in BOOLEAN
    /\ submitWithoutBudget \in BOOLEAN
    /\ ambientDesc \in BOOLEAN
    /\ crossDomainDma \in BOOLEAN
    /\ doubleReturn \in BOOLEAN
    /\ staleReturn \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ queueLive = FALSE
    /\ epochFresh = FALSE
    /\ memoryViewLive = FALSE
    /\ iommuLive = FALSE
    /\ queueBudget = FALSE
    /\ serviceBudget = FALSE
    /\ pagePoolCap = FALSE
    /\ pagePoolOwned = FALSE
    /\ pagePoolDmaLive = FALSE
    /\ pagePoolReturned = FALSE
    /\ xskCap = FALSE
    /\ xskPoolBound = FALSE
    /\ xskUmemOwned = FALSE
    /\ xskDescFrozen = FALSE
    /\ xskDmaLive = FALSE
    /\ xskReturned = FALSE
    /\ submitClass = "None"
    /\ submitted = FALSE
    /\ xdpTxSubmitted = FALSE
    /\ afxdpSubmitted = FALSE
    /\ ledgerLive = FALSE
    /\ descriptorPublished = FALSE
    /\ doorbellRung = FALSE
    /\ completionPending = FALSE
    /\ completionRunning = FALSE
    /\ completed = FALSE
    /\ returned = FALSE
    /\ revoked = FALSE
    /\ submitWithoutBudget = FALSE
    /\ ambientDesc = FALSE
    /\ crossDomainDma = FALSE
    /\ doubleReturn = FALSE
    /\ staleReturn = FALSE

PreparePagePool ==
    /\ phase = "Start"
    /\ queueLive' = TRUE
    /\ epochFresh' = TRUE
    /\ memoryViewLive' = TRUE
    /\ iommuLive' = TRUE
    /\ queueBudget' = TRUE
    /\ serviceBudget' = TRUE
    /\ pagePoolCap' = TRUE
    /\ pagePoolOwned' = TRUE
    /\ pagePoolDmaLive' = TRUE
    /\ phase' = "PagePoolReady"
    /\ UNCHANGED <<pagePoolReturned, xskCap, xskPoolBound, xskUmemOwned,
                    xskDescFrozen, xskDmaLive, xskReturned, submitClass,
                    submitted, xdpTxSubmitted, afxdpSubmitted, ledgerLive,
                    descriptorPublished, doorbellRung, completionPending,
                    completionRunning, completed, returned, revoked,
                    submitWithoutBudget, ambientDesc, crossDomainDma,
                    doubleReturn, staleReturn>>

PrepareXSK ==
    /\ phase = "Start"
    /\ queueLive' = TRUE
    /\ epochFresh' = TRUE
    /\ memoryViewLive' = TRUE
    /\ iommuLive' = TRUE
    /\ queueBudget' = TRUE
    /\ serviceBudget' = TRUE
    /\ xskCap' = TRUE
    /\ xskPoolBound' = TRUE
    /\ xskUmemOwned' = TRUE
    /\ xskDescFrozen' = TRUE
    /\ xskDmaLive' = TRUE
    /\ phase' = "XSKReady"
    /\ UNCHANGED <<pagePoolCap, pagePoolOwned, pagePoolDmaLive,
                    pagePoolReturned, xskReturned, submitClass, submitted,
                    xdpTxSubmitted, afxdpSubmitted, ledgerLive,
                    descriptorPublished, doorbellRung, completionPending,
                    completionRunning, completed, returned, revoked,
                    submitWithoutBudget, ambientDesc, crossDomainDma,
                    doubleReturn, staleReturn>>

SubmitXDPTx ==
    /\ phase = "PagePoolReady"
    /\ queueLive
    /\ epochFresh
    /\ memoryViewLive
    /\ iommuLive
    /\ queueBudget
    /\ pagePoolCap
    /\ pagePoolOwned
    /\ pagePoolDmaLive
    /\ submitClass' = "XDP_TX_PAGE_POOL"
    /\ submitted' = TRUE
    /\ xdpTxSubmitted' = TRUE
    /\ ledgerLive' = TRUE
    /\ descriptorPublished' = TRUE
    /\ doorbellRung' = TRUE
    /\ queueBudget' = FALSE
    /\ phase' = "Submitted"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    serviceBudget, pagePoolCap, pagePoolOwned,
                    pagePoolDmaLive, pagePoolReturned, xskCap, xskPoolBound,
                    xskUmemOwned, xskDescFrozen, xskDmaLive, xskReturned,
                    afxdpSubmitted, completionPending, completionRunning,
                    completed, returned, revoked, submitWithoutBudget,
                    ambientDesc, crossDomainDma, doubleReturn, staleReturn>>

SubmitAFXDP ==
    /\ phase = "XSKReady"
    /\ queueLive
    /\ epochFresh
    /\ memoryViewLive
    /\ iommuLive
    /\ queueBudget
    /\ xskCap
    /\ xskPoolBound
    /\ xskUmemOwned
    /\ xskDescFrozen
    /\ xskDmaLive
    /\ submitClass' = "AF_XDP"
    /\ submitted' = TRUE
    /\ afxdpSubmitted' = TRUE
    /\ ledgerLive' = TRUE
    /\ descriptorPublished' = TRUE
    /\ doorbellRung' = TRUE
    /\ queueBudget' = FALSE
    /\ phase' = "Submitted"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    serviceBudget, pagePoolCap, pagePoolOwned,
                    pagePoolDmaLive, pagePoolReturned, xskCap, xskPoolBound,
                    xskUmemOwned, xskDescFrozen, xskDmaLive, xskReturned,
                    xdpTxSubmitted, completionPending, completionRunning,
                    completed, returned, revoked, submitWithoutBudget,
                    ambientDesc, crossDomainDma, doubleReturn, staleReturn>>

DeviceCompletion ==
    /\ phase = "Submitted"
    /\ submitted
    /\ ledgerLive
    /\ completionPending' = TRUE
    /\ phase' = "CompletionPending"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    queueBudget, serviceBudget, pagePoolCap, pagePoolOwned,
                    pagePoolDmaLive, pagePoolReturned, xskCap, xskPoolBound,
                    xskUmemOwned, xskDescFrozen, xskDmaLive, xskReturned,
                    submitClass, submitted, xdpTxSubmitted, afxdpSubmitted,
                    ledgerLive, descriptorPublished, doorbellRung,
                    completionRunning, completed, returned, revoked,
                    submitWithoutBudget, ambientDesc, crossDomainDma,
                    doubleReturn, staleReturn>>

RunCompletion ==
    /\ phase = "CompletionPending"
    /\ completionPending
    /\ serviceBudget
    /\ ledgerLive
    /\ completionPending' = FALSE
    /\ completionRunning' = TRUE
    /\ phase' = "CompletionRunning"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    queueBudget, serviceBudget, pagePoolCap, pagePoolOwned,
                    pagePoolDmaLive, pagePoolReturned, xskCap, xskPoolBound,
                    xskUmemOwned, xskDescFrozen, xskDmaLive, xskReturned,
                    submitClass, submitted, xdpTxSubmitted, afxdpSubmitted,
                    ledgerLive, descriptorPublished, doorbellRung, completed,
                    returned, revoked, submitWithoutBudget, ambientDesc,
                    crossDomainDma, doubleReturn, staleReturn>>

ReturnOwnedMemory ==
    /\ phase = "CompletionRunning"
    /\ completionRunning
    /\ ledgerLive
    /\ \/ /\ submitClass = "XDP_TX_PAGE_POOL"
          /\ pagePoolOwned
          /\ pagePoolReturned' = TRUE
          /\ xskReturned' = xskReturned
       \/ /\ submitClass = "AF_XDP"
          /\ xskUmemOwned
          /\ xskReturned' = TRUE
          /\ pagePoolReturned' = pagePoolReturned
    /\ descriptorPublished' = FALSE
    /\ doorbellRung' = FALSE
    /\ submitted' = FALSE
    /\ xdpTxSubmitted' = FALSE
    /\ afxdpSubmitted' = FALSE
    /\ ledgerLive' = FALSE
    /\ completionRunning' = FALSE
    /\ completed' = TRUE
    /\ returned' = TRUE
    /\ submitClass' = "None"
    /\ phase' = "Returned"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    queueBudget, serviceBudget, pagePoolCap, pagePoolOwned,
                    pagePoolDmaLive, xskCap, xskPoolBound, xskUmemOwned,
                    xskDescFrozen, xskDmaLive, completionPending, revoked,
                    submitWithoutBudget, ambientDesc, crossDomainDma,
                    doubleReturn, staleReturn>>

Revoke ==
    /\ phase \in {"PagePoolReady", "XSKReady", "Submitted",
                  "CompletionPending", "CompletionRunning"}
    /\ queueLive
    /\ queueLive' = FALSE
    /\ epochFresh' = FALSE
    /\ memoryViewLive' = FALSE
    /\ iommuLive' = FALSE
    /\ queueBudget' = FALSE
    /\ serviceBudget' = FALSE
    /\ pagePoolDmaLive' = FALSE
    /\ xskDmaLive' = FALSE
    /\ submitted' = FALSE
    /\ xdpTxSubmitted' = FALSE
    /\ afxdpSubmitted' = FALSE
    /\ ledgerLive' = FALSE
    /\ descriptorPublished' = FALSE
    /\ doorbellRung' = FALSE
    /\ completionPending' = FALSE
    /\ completionRunning' = FALSE
    /\ submitClass' = "None"
    /\ revoked' = TRUE
    /\ phase' = "Revoked"
    /\ UNCHANGED <<pagePoolCap, pagePoolOwned, pagePoolReturned, xskCap,
                    xskPoolBound, xskUmemOwned, xskDescFrozen, xskReturned,
                    completed, returned, submitWithoutBudget, ambientDesc,
                    crossDomainDma, doubleReturn, staleReturn>>

UnsafeXDPTxNoPagePool ==
    /\ phase = "PagePoolReady"
    /\ pagePoolOwned' = FALSE
    /\ submitClass' = "XDP_TX_PAGE_POOL"
    /\ submitted' = TRUE
    /\ xdpTxSubmitted' = TRUE
    /\ ledgerLive' = TRUE
    /\ descriptorPublished' = TRUE
    /\ doorbellRung' = TRUE
    /\ phase' = "BadXDPTxNoPagePool"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    queueBudget, serviceBudget, pagePoolCap, pagePoolDmaLive,
                    pagePoolReturned, xskCap, xskPoolBound, xskUmemOwned,
                    xskDescFrozen, xskDmaLive, xskReturned, afxdpSubmitted,
                    completionPending, completionRunning, completed, returned,
                    revoked, submitWithoutBudget, ambientDesc, crossDomainDma,
                    doubleReturn, staleReturn>>

UnsafeAFXDPNoXSK ==
    /\ phase = "XSKReady"
    /\ xskUmemOwned' = FALSE
    /\ submitClass' = "AF_XDP"
    /\ submitted' = TRUE
    /\ afxdpSubmitted' = TRUE
    /\ ledgerLive' = TRUE
    /\ descriptorPublished' = TRUE
    /\ doorbellRung' = TRUE
    /\ phase' = "BadAFXDPNoXSK"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    queueBudget, serviceBudget, pagePoolCap, pagePoolOwned,
                    pagePoolDmaLive, pagePoolReturned, xskCap, xskPoolBound,
                    xskDescFrozen, xskDmaLive, xskReturned, xdpTxSubmitted,
                    completionPending, completionRunning, completed, returned,
                    revoked, submitWithoutBudget, ambientDesc, crossDomainDma,
                    doubleReturn, staleReturn>>

UnsafeDmaNoMemoryView ==
    /\ phase \in {"PagePoolReady", "XSKReady"}
    /\ memoryViewLive' = FALSE
    /\ submitClass' = IF phase = "PagePoolReady"
                      THEN "XDP_TX_PAGE_POOL"
                      ELSE "AF_XDP"
    /\ submitted' = TRUE
    /\ xdpTxSubmitted' = (phase = "PagePoolReady")
    /\ afxdpSubmitted' = (phase = "XSKReady")
    /\ ledgerLive' = TRUE
    /\ descriptorPublished' = TRUE
    /\ doorbellRung' = TRUE
    /\ phase' = "BadDmaNoMemoryView"
    /\ UNCHANGED <<queueLive, epochFresh, iommuLive, queueBudget,
                    serviceBudget, pagePoolCap, pagePoolOwned,
                    pagePoolDmaLive, pagePoolReturned, xskCap, xskPoolBound,
                    xskUmemOwned, xskDescFrozen, xskDmaLive, xskReturned,
                    completionPending, completionRunning, completed, returned,
                    revoked, submitWithoutBudget, ambientDesc, crossDomainDma,
                    doubleReturn, staleReturn>>

UnsafeAmbientXSKDesc ==
    /\ phase = "XSKReady"
    /\ xskDescFrozen' = FALSE
    /\ ambientDesc' = TRUE
    /\ submitClass' = "AF_XDP"
    /\ submitted' = TRUE
    /\ afxdpSubmitted' = TRUE
    /\ ledgerLive' = TRUE
    /\ descriptorPublished' = TRUE
    /\ doorbellRung' = TRUE
    /\ phase' = "BadAmbientXSKDesc"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    queueBudget, serviceBudget, pagePoolCap, pagePoolOwned,
                    pagePoolDmaLive, pagePoolReturned, xskCap, xskPoolBound,
                    xskUmemOwned, xskDmaLive, xskReturned, xdpTxSubmitted,
                    completionPending, completionRunning, completed, returned,
                    revoked, submitWithoutBudget, crossDomainDma,
                    doubleReturn, staleReturn>>

UnsafeCrossDomainDma ==
    /\ phase \in {"PagePoolReady", "XSKReady"}
    /\ crossDomainDma' = TRUE
    /\ submitClass' = IF phase = "PagePoolReady"
                      THEN "XDP_TX_PAGE_POOL"
                      ELSE "AF_XDP"
    /\ submitted' = TRUE
    /\ xdpTxSubmitted' = (phase = "PagePoolReady")
    /\ afxdpSubmitted' = (phase = "XSKReady")
    /\ ledgerLive' = TRUE
    /\ descriptorPublished' = TRUE
    /\ doorbellRung' = TRUE
    /\ phase' = "BadCrossDomainDma"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    queueBudget, serviceBudget, pagePoolCap, pagePoolOwned,
                    pagePoolDmaLive, pagePoolReturned, xskCap, xskPoolBound,
                    xskUmemOwned, xskDescFrozen, xskDmaLive, xskReturned,
                    completionPending, completionRunning, completed, returned,
                    revoked, submitWithoutBudget, ambientDesc, doubleReturn,
                    staleReturn>>

UnsafeCompletionNoLedger ==
    /\ phase = "CompletionPending"
    /\ ledgerLive' = FALSE
    /\ completionPending' = FALSE
    /\ completionRunning' = TRUE
    /\ phase' = "BadCompletionNoLedger"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    queueBudget, serviceBudget, pagePoolCap, pagePoolOwned,
                    pagePoolDmaLive, pagePoolReturned, xskCap, xskPoolBound,
                    xskUmemOwned, xskDescFrozen, xskDmaLive, xskReturned,
                    submitClass, submitted, xdpTxSubmitted, afxdpSubmitted,
                    descriptorPublished, doorbellRung, completed, returned,
                    revoked, submitWithoutBudget, ambientDesc, crossDomainDma,
                    doubleReturn, staleReturn>>

UnsafeDoubleReturn ==
    /\ phase = "Returned"
    /\ returned
    /\ doubleReturn' = TRUE
    /\ phase' = "BadDoubleReturn"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    queueBudget, serviceBudget, pagePoolCap, pagePoolOwned,
                    pagePoolDmaLive, pagePoolReturned, xskCap, xskPoolBound,
                    xskUmemOwned, xskDescFrozen, xskDmaLive, xskReturned,
                    submitClass, submitted, xdpTxSubmitted, afxdpSubmitted,
                    ledgerLive, descriptorPublished, doorbellRung,
                    completionPending, completionRunning, completed, returned,
                    revoked, submitWithoutBudget, ambientDesc, crossDomainDma,
                    staleReturn>>

UnsafeReturnAfterRevoke ==
    /\ phase \in {"Submitted", "CompletionPending"}
    /\ revoked' = TRUE
    /\ returned' = TRUE
    /\ staleReturn' = TRUE
    /\ phase' = "BadReturnAfterRevoke"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    queueBudget, serviceBudget, pagePoolCap, pagePoolOwned,
                    pagePoolDmaLive, pagePoolReturned, xskCap, xskPoolBound,
                    xskUmemOwned, xskDescFrozen, xskDmaLive, xskReturned,
                    submitClass, submitted, xdpTxSubmitted, afxdpSubmitted,
                    ledgerLive, descriptorPublished, doorbellRung,
                    completionPending, completionRunning, completed,
                    submitWithoutBudget, ambientDesc, crossDomainDma,
                    doubleReturn>>

UnsafeSubmitNoBudget ==
    /\ phase \in {"PagePoolReady", "XSKReady"}
    /\ queueBudget' = FALSE
    /\ submitWithoutBudget' = TRUE
    /\ submitClass' = IF phase = "PagePoolReady"
                      THEN "XDP_TX_PAGE_POOL"
                      ELSE "AF_XDP"
    /\ submitted' = TRUE
    /\ xdpTxSubmitted' = (phase = "PagePoolReady")
    /\ afxdpSubmitted' = (phase = "XSKReady")
    /\ ledgerLive' = TRUE
    /\ descriptorPublished' = TRUE
    /\ doorbellRung' = TRUE
    /\ phase' = "BadSubmitNoBudget"
    /\ UNCHANGED <<queueLive, epochFresh, memoryViewLive, iommuLive,
                    serviceBudget, pagePoolCap, pagePoolOwned,
                    pagePoolDmaLive, pagePoolReturned, xskCap, xskPoolBound,
                    xskUmemOwned, xskDescFrozen, xskDmaLive, xskReturned,
                    completionPending, completionRunning, completed, returned,
                    revoked, ambientDesc, crossDomainDma, doubleReturn,
                    staleReturn>>

SafeNext ==
    \/ PreparePagePool
    \/ PrepareXSK
    \/ SubmitXDPTx
    \/ SubmitAFXDP
    \/ DeviceCompletion
    \/ RunCompletion
    \/ ReturnOwnedMemory
    \/ Revoke

SafeSpec == Init /\ [][SafeNext]_vars

UnsafeXDPTxNoPagePoolSpec == Init /\ [][SafeNext \/ UnsafeXDPTxNoPagePool]_vars
UnsafeAFXDPNoXSKSpec == Init /\ [][SafeNext \/ UnsafeAFXDPNoXSK]_vars
UnsafeDmaNoMemoryViewSpec == Init /\ [][SafeNext \/ UnsafeDmaNoMemoryView]_vars
UnsafeAmbientXSKDescSpec == Init /\ [][SafeNext \/ UnsafeAmbientXSKDesc]_vars
UnsafeCrossDomainDmaSpec == Init /\ [][SafeNext \/ UnsafeCrossDomainDma]_vars
UnsafeCompletionNoLedgerSpec == Init /\ [][SafeNext \/ UnsafeCompletionNoLedger]_vars
UnsafeDoubleReturnSpec == Init /\ [][SafeNext \/ UnsafeDoubleReturn]_vars
UnsafeReturnAfterRevokeSpec == Init /\ [][SafeNext \/ UnsafeReturnAfterRevoke]_vars
UnsafeSubmitNoBudgetSpec == Init /\ [][SafeNext \/ UnsafeSubmitNoBudget]_vars

NoXDPTxWithoutPagePoolOwnership ==
    xdpTxSubmitted =>
        /\ submitClass = "XDP_TX_PAGE_POOL"
        /\ pagePoolCap
        /\ pagePoolOwned
        /\ pagePoolDmaLive

NoAFXDPWithoutXSKOwnership ==
    afxdpSubmitted =>
        /\ submitClass = "AF_XDP"
        /\ xskCap
        /\ xskPoolBound
        /\ xskUmemOwned
        /\ xskDescFrozen
        /\ xskDmaLive
        /\ ~ambientDesc

NoDmaWithoutMemoryViewAndIommu ==
    submitted =>
        /\ queueLive
        /\ epochFresh
        /\ memoryViewLive
        /\ iommuLive
        /\ ~crossDomainDma

NoSubmitWithoutBudget ==
    ~submitWithoutBudget

NoCompletionWithoutLedgerAndServiceBudget ==
    completionRunning =>
        /\ ledgerLive
        /\ serviceBudget

NoReturnWithoutCompletion ==
    returned =>
        /\ completed
        /\ ~revoked
        /\ ~staleReturn

NoDoubleReturn ==
    ~doubleReturn

NoSubmitClassMix ==
    submitted =>
        /\ submitClass \in {"XDP_TX_PAGE_POOL", "AF_XDP"}
        /\ ~(xdpTxSubmitted /\ afxdpSubmitted)
        /\ xdpTxSubmitted => submitClass = "XDP_TX_PAGE_POOL"
        /\ afxdpSubmitted => submitClass = "AF_XDP"

NoOutstandingAfterRevoke ==
    revoked =>
        /\ ~submitted
        /\ ~xdpTxSubmitted
        /\ ~afxdpSubmitted
        /\ ~ledgerLive
        /\ ~descriptorPublished
        /\ ~doorbellRung
        /\ ~completionPending
        /\ ~completionRunning
        /\ ~pagePoolDmaLive
        /\ ~xskDmaLive

=============================================================================
