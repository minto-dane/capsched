-------------------- MODULE MonitorDmaIommuInvalidation --------------------
EXTENDS Naturals

CONSTANTS
    ALLOW_UNSAFE_IRQ_ONLY_REASSIGN,
    ALLOW_UNSAFE_DRIVER_UNMAP_ONLY_RECEIPT,
    ALLOW_UNSAFE_IOMMU_UNMAP_NO_IOTLB_SYNC,
    ALLOW_UNSAFE_QUEUED_FLUSH_RECEIPT,
    ALLOW_UNSAFE_PAGE_OWNER_TRANSFER_WITH_DMA_IN_FLIGHT,
    ALLOW_UNSAFE_NEW_MEMORYVIEW_BEFORE_OLD_UNMAPPED,
    ALLOW_UNSAFE_COMPLETION_AFTER_REVOKE,
    ALLOW_UNSAFE_PACKET_RETURN_BEFORE_RECEIPT

VARIABLES
    phase,
    queueTagLive,
    queueEpochFresh,
    irqInvalidated,
    descriptorLive,
    deviceDmaEnabled,
    driverDmaUnmapped,
    iommufdUnmapped,
    iommuPtePresent,
    iotlbSynced,
    flushQueued,
    dmaInFlight,
    pageOwnerOld,
    pageOwnerNew,
    oldMemoryViewMapped,
    newMemoryViewMapped,
    packetPageReturned,
    completionQuarantined,
    delivered,
    dmaInvalidationReceipt,
    revoked,
    queueReassigned,
    monitorOwnsDmaRoot,
    newWorkEmbargo,
    hwQueueQuiesced,
    hwDescriptorsDrained,
    accessUsersReleased,
    deviceDmaDomainBlocked

vars == <<phase, queueTagLive, queueEpochFresh, irqInvalidated,
          descriptorLive, deviceDmaEnabled, driverDmaUnmapped,
          iommufdUnmapped, iommuPtePresent, iotlbSynced, flushQueued,
          dmaInFlight, pageOwnerOld, pageOwnerNew, oldMemoryViewMapped,
          newMemoryViewMapped, packetPageReturned, completionQuarantined,
          delivered, dmaInvalidationReceipt, revoked, queueReassigned,
          monitorOwnsDmaRoot, newWorkEmbargo, hwQueueQuiesced,
          hwDescriptorsDrained, accessUsersReleased,
          deviceDmaDomainBlocked>>

Phases == {
    "Start",
    "Bound",
    "Revoking",
    "IrqInvalidated",
    "Stopped",
    "HwQuiesced",
    "HwDescriptorsDrained",
    "DriverUnmapped",
    "AccessReleased",
    "IommuUnmapped",
    "IotlbSynced",
    "DomainBlocked",
    "Drained",
    "OldViewUnmapped",
    "DmaInvalidated",
    "PageTransferred",
    "Reassigned",
    "BadIrqOnlyReassign",
    "BadDriverUnmapOnlyReceipt",
    "BadIommuUnmapNoIotlbSync",
    "BadQueuedFlushReceipt",
    "BadPageOwnerTransferWithDmaInFlight",
    "BadNewMemoryViewBeforeOldUnmapped",
    "BadCompletionAfterRevoke",
    "BadPacketReturnBeforeReceipt"
}

TypeOK ==
    /\ phase \in Phases
    /\ queueTagLive \in BOOLEAN
    /\ queueEpochFresh \in BOOLEAN
    /\ irqInvalidated \in BOOLEAN
    /\ descriptorLive \in BOOLEAN
    /\ deviceDmaEnabled \in BOOLEAN
    /\ driverDmaUnmapped \in BOOLEAN
    /\ iommufdUnmapped \in BOOLEAN
    /\ iommuPtePresent \in BOOLEAN
    /\ iotlbSynced \in BOOLEAN
    /\ flushQueued \in BOOLEAN
    /\ dmaInFlight \in BOOLEAN
    /\ pageOwnerOld \in BOOLEAN
    /\ pageOwnerNew \in BOOLEAN
    /\ oldMemoryViewMapped \in BOOLEAN
    /\ newMemoryViewMapped \in BOOLEAN
    /\ packetPageReturned \in BOOLEAN
    /\ completionQuarantined \in BOOLEAN
    /\ delivered \in BOOLEAN
    /\ dmaInvalidationReceipt \in BOOLEAN
    /\ revoked \in BOOLEAN
    /\ queueReassigned \in BOOLEAN
    /\ monitorOwnsDmaRoot \in BOOLEAN
    /\ newWorkEmbargo \in BOOLEAN
    /\ hwQueueQuiesced \in BOOLEAN
    /\ hwDescriptorsDrained \in BOOLEAN
    /\ accessUsersReleased \in BOOLEAN
    /\ deviceDmaDomainBlocked \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ queueTagLive = FALSE
    /\ queueEpochFresh = FALSE
    /\ irqInvalidated = FALSE
    /\ descriptorLive = FALSE
    /\ deviceDmaEnabled = FALSE
    /\ driverDmaUnmapped = FALSE
    /\ iommufdUnmapped = FALSE
    /\ iommuPtePresent = FALSE
    /\ iotlbSynced = FALSE
    /\ flushQueued = FALSE
    /\ dmaInFlight = FALSE
    /\ pageOwnerOld = FALSE
    /\ pageOwnerNew = FALSE
    /\ oldMemoryViewMapped = FALSE
    /\ newMemoryViewMapped = FALSE
    /\ packetPageReturned = FALSE
    /\ completionQuarantined = FALSE
    /\ delivered = FALSE
    /\ dmaInvalidationReceipt = FALSE
    /\ revoked = FALSE
    /\ queueReassigned = FALSE
    /\ monitorOwnsDmaRoot = FALSE
    /\ newWorkEmbargo = FALSE
    /\ hwQueueQuiesced = FALSE
    /\ hwDescriptorsDrained = FALSE
    /\ accessUsersReleased = FALSE
    /\ deviceDmaDomainBlocked = FALSE

Set(p, qtl, qef, irq, desc, devdma, drvunmap, iofdunmap, pte,
    sync, fqueued, inflight, ownerOld, ownerNew, oldMv, newMv,
    returned, quarantined, wasDelivered, receipt, wasRevoked,
    reassigned, monitorRoot, embargo, hwQuiesced, hwDescDrained,
    accessReleased, domainBlocked) ==
    /\ phase' = p
    /\ queueTagLive' = qtl
    /\ queueEpochFresh' = qef
    /\ irqInvalidated' = irq
    /\ descriptorLive' = desc
    /\ deviceDmaEnabled' = devdma
    /\ driverDmaUnmapped' = drvunmap
    /\ iommufdUnmapped' = iofdunmap
    /\ iommuPtePresent' = pte
    /\ iotlbSynced' = sync
    /\ flushQueued' = fqueued
    /\ dmaInFlight' = inflight
    /\ pageOwnerOld' = ownerOld
    /\ pageOwnerNew' = ownerNew
    /\ oldMemoryViewMapped' = oldMv
    /\ newMemoryViewMapped' = newMv
    /\ packetPageReturned' = returned
    /\ completionQuarantined' = quarantined
    /\ delivered' = wasDelivered
    /\ dmaInvalidationReceipt' = receipt
    /\ revoked' = wasRevoked
    /\ queueReassigned' = reassigned
    /\ monitorOwnsDmaRoot' = monitorRoot
    /\ newWorkEmbargo' = embargo
    /\ hwQueueQuiesced' = hwQuiesced
    /\ hwDescriptorsDrained' = hwDescDrained
    /\ accessUsersReleased' = accessReleased
    /\ deviceDmaDomainBlocked' = domainBlocked

BindQueue ==
    /\ phase = "Start"
    /\ Set("Bound", TRUE, TRUE, FALSE,
                 TRUE, TRUE, FALSE,
                 FALSE, TRUE, TRUE, FALSE,
                 TRUE, TRUE, FALSE, TRUE,
                 FALSE, FALSE, FALSE,
                 FALSE, FALSE, FALSE, FALSE,
                 TRUE, FALSE, FALSE, FALSE, FALSE, FALSE)

RevokeStart ==
    /\ phase = "Bound"
    /\ Set("Revoking", queueTagLive, FALSE, irqInvalidated,
                 descriptorLive, deviceDmaEnabled, driverDmaUnmapped,
                 iommufdUnmapped, iommuPtePresent, iotlbSynced, flushQueued,
                 dmaInFlight, pageOwnerOld, pageOwnerNew, oldMemoryViewMapped,
                 newMemoryViewMapped, packetPageReturned, completionQuarantined,
                 delivered, dmaInvalidationReceipt, TRUE, queueReassigned,
                 monitorOwnsDmaRoot, TRUE, hwQueueQuiesced,
                 hwDescriptorsDrained, accessUsersReleased,
                 deviceDmaDomainBlocked)

InvalidateIrqRoute ==
    /\ phase = "Revoking"
    /\ Set("IrqInvalidated", queueTagLive, queueEpochFresh, TRUE,
                 descriptorLive, deviceDmaEnabled, driverDmaUnmapped,
                 iommufdUnmapped, iommuPtePresent, iotlbSynced, flushQueued,
                 dmaInFlight, pageOwnerOld, pageOwnerNew, oldMemoryViewMapped,
                 newMemoryViewMapped, packetPageReturned, completionQuarantined,
                 delivered, dmaInvalidationReceipt, revoked, queueReassigned,
                 monitorOwnsDmaRoot, newWorkEmbargo, hwQueueQuiesced,
                 hwDescriptorsDrained, accessUsersReleased,
                 deviceDmaDomainBlocked)

StopQueueAndDescriptors ==
    /\ phase = "IrqInvalidated"
    /\ Set("Stopped", queueTagLive, queueEpochFresh, irqInvalidated,
                 FALSE, FALSE, driverDmaUnmapped,
                 iommufdUnmapped, iommuPtePresent, iotlbSynced, flushQueued,
                 dmaInFlight, pageOwnerOld, pageOwnerNew, oldMemoryViewMapped,
                 newMemoryViewMapped, packetPageReturned, completionQuarantined,
                 delivered, dmaInvalidationReceipt, revoked, queueReassigned,
                 monitorOwnsDmaRoot, newWorkEmbargo, hwQueueQuiesced,
                 hwDescriptorsDrained, accessUsersReleased,
                 deviceDmaDomainBlocked)

ObserveHwQueueQuiesce ==
    /\ phase = "Stopped"
    /\ Set("HwQuiesced", queueTagLive, queueEpochFresh, irqInvalidated,
                 descriptorLive, deviceDmaEnabled, driverDmaUnmapped,
                 iommufdUnmapped, iommuPtePresent, iotlbSynced, flushQueued,
                 dmaInFlight, pageOwnerOld, pageOwnerNew, oldMemoryViewMapped,
                 newMemoryViewMapped, packetPageReturned, completionQuarantined,
                 delivered, dmaInvalidationReceipt, revoked, queueReassigned,
                 monitorOwnsDmaRoot, newWorkEmbargo, TRUE,
                 hwDescriptorsDrained, accessUsersReleased,
                 deviceDmaDomainBlocked)

DrainHwOwnedDescriptors ==
    /\ phase = "HwQuiesced"
    /\ Set("HwDescriptorsDrained", queueTagLive, queueEpochFresh,
                 irqInvalidated, descriptorLive, deviceDmaEnabled,
                 driverDmaUnmapped, iommufdUnmapped, iommuPtePresent,
                 iotlbSynced, flushQueued, dmaInFlight, pageOwnerOld,
                 pageOwnerNew, oldMemoryViewMapped, newMemoryViewMapped,
                 packetPageReturned, completionQuarantined, delivered,
                 dmaInvalidationReceipt, revoked, queueReassigned,
                 monitorOwnsDmaRoot, newWorkEmbargo, hwQueueQuiesced,
                 TRUE, accessUsersReleased, deviceDmaDomainBlocked)

DriverDmaUnmap ==
    /\ phase = "HwDescriptorsDrained"
    /\ Set("DriverUnmapped", queueTagLive, queueEpochFresh, irqInvalidated,
                 descriptorLive, deviceDmaEnabled, TRUE,
                 iommufdUnmapped, iommuPtePresent, iotlbSynced, flushQueued,
                 dmaInFlight, pageOwnerOld, pageOwnerNew, oldMemoryViewMapped,
                 newMemoryViewMapped, packetPageReturned, completionQuarantined,
                 delivered, dmaInvalidationReceipt, revoked, queueReassigned,
                 monitorOwnsDmaRoot, newWorkEmbargo, hwQueueQuiesced,
                 hwDescriptorsDrained, accessUsersReleased,
                 deviceDmaDomainBlocked)

ReleaseAccessUsers ==
    /\ phase = "DriverUnmapped"
    /\ Set("AccessReleased", queueTagLive, queueEpochFresh, irqInvalidated,
                 descriptorLive, deviceDmaEnabled, driverDmaUnmapped,
                 iommufdUnmapped, iommuPtePresent, iotlbSynced, flushQueued,
                 dmaInFlight, pageOwnerOld, pageOwnerNew, oldMemoryViewMapped,
                 newMemoryViewMapped, packetPageReturned, completionQuarantined,
                 delivered, dmaInvalidationReceipt, revoked, queueReassigned,
                 monitorOwnsDmaRoot, newWorkEmbargo, hwQueueQuiesced,
                 hwDescriptorsDrained, TRUE, deviceDmaDomainBlocked)

IommuUnmapQueued ==
    /\ phase = "AccessReleased"
    /\ Set("IommuUnmapped", queueTagLive, queueEpochFresh, irqInvalidated,
                 descriptorLive, deviceDmaEnabled, driverDmaUnmapped,
                 TRUE, FALSE, FALSE, TRUE,
                 dmaInFlight, pageOwnerOld, pageOwnerNew, oldMemoryViewMapped,
                 newMemoryViewMapped, packetPageReturned, completionQuarantined,
                 delivered, dmaInvalidationReceipt, revoked, queueReassigned,
                 monitorOwnsDmaRoot, newWorkEmbargo, hwQueueQuiesced,
                 hwDescriptorsDrained, accessUsersReleased,
                 deviceDmaDomainBlocked)

IotlbFlushComplete ==
    /\ phase = "IommuUnmapped"
    /\ Set("IotlbSynced", queueTagLive, queueEpochFresh, irqInvalidated,
                 descriptorLive, deviceDmaEnabled, driverDmaUnmapped,
                 iommufdUnmapped, iommuPtePresent, TRUE, FALSE,
                 dmaInFlight, pageOwnerOld, pageOwnerNew, oldMemoryViewMapped,
                 newMemoryViewMapped, packetPageReturned, completionQuarantined,
                 delivered, dmaInvalidationReceipt, revoked, queueReassigned,
                 monitorOwnsDmaRoot, newWorkEmbargo, hwQueueQuiesced,
                 hwDescriptorsDrained, accessUsersReleased,
                 deviceDmaDomainBlocked)

BlockDmaDomain ==
    /\ phase = "IotlbSynced"
    /\ Set("DomainBlocked", queueTagLive, queueEpochFresh, irqInvalidated,
                 descriptorLive, deviceDmaEnabled, driverDmaUnmapped,
                 iommufdUnmapped, iommuPtePresent, iotlbSynced, flushQueued,
                 dmaInFlight, pageOwnerOld, pageOwnerNew, oldMemoryViewMapped,
                 newMemoryViewMapped, packetPageReturned, completionQuarantined,
                 delivered, dmaInvalidationReceipt, revoked, queueReassigned,
                 monitorOwnsDmaRoot, newWorkEmbargo, hwQueueQuiesced,
                 hwDescriptorsDrained, accessUsersReleased, TRUE)

DrainOutstandingDma ==
    /\ phase = "DomainBlocked"
    /\ Set("Drained", queueTagLive, queueEpochFresh, irqInvalidated,
                 descriptorLive, deviceDmaEnabled, driverDmaUnmapped,
                 iommufdUnmapped, iommuPtePresent, iotlbSynced, flushQueued,
                 FALSE, pageOwnerOld, pageOwnerNew, oldMemoryViewMapped,
                 newMemoryViewMapped, packetPageReturned, TRUE,
                 delivered, dmaInvalidationReceipt, revoked, queueReassigned,
                 monitorOwnsDmaRoot, newWorkEmbargo, hwQueueQuiesced,
                 hwDescriptorsDrained, accessUsersReleased,
                 deviceDmaDomainBlocked)

UnmapOldMemoryView ==
    /\ phase = "Drained"
    /\ Set("OldViewUnmapped", queueTagLive, queueEpochFresh,
                 irqInvalidated, descriptorLive, deviceDmaEnabled,
                 driverDmaUnmapped, iommufdUnmapped, iommuPtePresent,
                 iotlbSynced, flushQueued, dmaInFlight, pageOwnerOld,
                 pageOwnerNew, FALSE, newMemoryViewMapped, packetPageReturned,
                 completionQuarantined, delivered, dmaInvalidationReceipt,
                 revoked, queueReassigned, monitorOwnsDmaRoot, newWorkEmbargo,
                 hwQueueQuiesced, hwDescriptorsDrained, accessUsersReleased,
                 deviceDmaDomainBlocked)

IssueDmaReceipt ==
    /\ phase = "OldViewUnmapped"
    /\ irqInvalidated
    /\ ~queueEpochFresh
    /\ ~descriptorLive
    /\ ~deviceDmaEnabled
    /\ driverDmaUnmapped
    /\ monitorOwnsDmaRoot
    /\ newWorkEmbargo
    /\ hwQueueQuiesced
    /\ hwDescriptorsDrained
    /\ accessUsersReleased
    /\ deviceDmaDomainBlocked
    /\ iommufdUnmapped
    /\ ~iommuPtePresent
    /\ iotlbSynced
    /\ ~flushQueued
    /\ ~dmaInFlight
    /\ completionQuarantined
    /\ ~oldMemoryViewMapped
    /\ Set("DmaInvalidated", queueTagLive, queueEpochFresh,
                 irqInvalidated, descriptorLive, deviceDmaEnabled,
                 driverDmaUnmapped, iommufdUnmapped, iommuPtePresent,
                 iotlbSynced, flushQueued, dmaInFlight, pageOwnerOld,
                 pageOwnerNew, oldMemoryViewMapped, newMemoryViewMapped,
                 packetPageReturned, completionQuarantined, delivered,
                 TRUE, revoked, queueReassigned, monitorOwnsDmaRoot,
                 newWorkEmbargo, hwQueueQuiesced, hwDescriptorsDrained,
                 accessUsersReleased, deviceDmaDomainBlocked)

TransferPageOwner ==
    /\ phase = "DmaInvalidated"
    /\ dmaInvalidationReceipt
    /\ Set("PageTransferred", queueTagLive, queueEpochFresh,
                 irqInvalidated, descriptorLive, deviceDmaEnabled,
                 driverDmaUnmapped, iommufdUnmapped, iommuPtePresent,
                 iotlbSynced, flushQueued, dmaInFlight, FALSE,
                 TRUE, oldMemoryViewMapped, TRUE, TRUE,
                 completionQuarantined, delivered, dmaInvalidationReceipt,
                 revoked, queueReassigned, monitorOwnsDmaRoot, newWorkEmbargo,
                 hwQueueQuiesced, hwDescriptorsDrained, accessUsersReleased,
                 deviceDmaDomainBlocked)

ReassignWithDmaReceipt ==
    /\ phase = "PageTransferred"
    /\ dmaInvalidationReceipt
    /\ Set("Reassigned", FALSE, queueEpochFresh, irqInvalidated,
                 descriptorLive, deviceDmaEnabled, driverDmaUnmapped,
                 iommufdUnmapped, iommuPtePresent, iotlbSynced, flushQueued,
                 dmaInFlight, pageOwnerOld, pageOwnerNew, oldMemoryViewMapped,
                 newMemoryViewMapped, packetPageReturned, completionQuarantined,
                 delivered, dmaInvalidationReceipt, revoked, TRUE,
                 monitorOwnsDmaRoot, newWorkEmbargo, hwQueueQuiesced,
                 hwDescriptorsDrained, accessUsersReleased,
                 deviceDmaDomainBlocked)

UnsafeIrqOnlyReassign ==
    /\ ALLOW_UNSAFE_IRQ_ONLY_REASSIGN
    /\ phase = "IrqInvalidated"
    /\ ~dmaInvalidationReceipt
    /\ Set("BadIrqOnlyReassign", queueTagLive, queueEpochFresh,
                 irqInvalidated, descriptorLive, deviceDmaEnabled,
                 driverDmaUnmapped, iommufdUnmapped, iommuPtePresent,
                 iotlbSynced, flushQueued, dmaInFlight, pageOwnerOld,
                 pageOwnerNew, oldMemoryViewMapped, newMemoryViewMapped,
                 packetPageReturned, completionQuarantined, delivered,
                 dmaInvalidationReceipt, revoked, TRUE, monitorOwnsDmaRoot,
                 newWorkEmbargo, hwQueueQuiesced, hwDescriptorsDrained,
                 accessUsersReleased, deviceDmaDomainBlocked)

UnsafeDriverUnmapOnlyReceipt ==
    /\ ALLOW_UNSAFE_DRIVER_UNMAP_ONLY_RECEIPT
    /\ phase = "Stopped"
    /\ Set("BadDriverUnmapOnlyReceipt", queueTagLive, queueEpochFresh,
                 irqInvalidated, descriptorLive, deviceDmaEnabled, TRUE,
                 iommufdUnmapped, iommuPtePresent, iotlbSynced, flushQueued,
                 dmaInFlight, pageOwnerOld, pageOwnerNew, oldMemoryViewMapped,
                 newMemoryViewMapped, packetPageReturned, completionQuarantined,
                 delivered, TRUE, revoked, queueReassigned,
                 monitorOwnsDmaRoot, newWorkEmbargo, hwQueueQuiesced,
                 hwDescriptorsDrained, accessUsersReleased,
                 deviceDmaDomainBlocked)

UnsafeIommuUnmapNoIotlbSync ==
    /\ ALLOW_UNSAFE_IOMMU_UNMAP_NO_IOTLB_SYNC
    /\ phase = "DriverUnmapped"
    /\ Set("BadIommuUnmapNoIotlbSync", queueTagLive, queueEpochFresh,
                 irqInvalidated, descriptorLive, deviceDmaEnabled,
                 driverDmaUnmapped, TRUE, FALSE, FALSE, FALSE,
                 dmaInFlight, pageOwnerOld, pageOwnerNew, oldMemoryViewMapped,
                 newMemoryViewMapped, packetPageReturned, completionQuarantined,
                 delivered, TRUE, revoked, queueReassigned,
                 monitorOwnsDmaRoot, newWorkEmbargo, hwQueueQuiesced,
                 hwDescriptorsDrained, TRUE, deviceDmaDomainBlocked)

UnsafeQueuedFlushReceipt ==
    /\ ALLOW_UNSAFE_QUEUED_FLUSH_RECEIPT
    /\ phase = "DriverUnmapped"
    /\ Set("BadQueuedFlushReceipt", queueTagLive, queueEpochFresh,
                 irqInvalidated, descriptorLive, deviceDmaEnabled,
                 driverDmaUnmapped, TRUE, FALSE, FALSE, TRUE,
                 dmaInFlight, pageOwnerOld, pageOwnerNew, oldMemoryViewMapped,
                 newMemoryViewMapped, packetPageReturned, completionQuarantined,
                 delivered, TRUE, revoked, queueReassigned,
                 monitorOwnsDmaRoot, newWorkEmbargo, hwQueueQuiesced,
                 hwDescriptorsDrained, TRUE, deviceDmaDomainBlocked)

UnsafePageOwnerTransferWithDmaInFlight ==
    /\ ALLOW_UNSAFE_PAGE_OWNER_TRANSFER_WITH_DMA_IN_FLIGHT
    /\ phase = "IotlbSynced"
    /\ dmaInFlight
    /\ Set("BadPageOwnerTransferWithDmaInFlight", queueTagLive,
                 queueEpochFresh, irqInvalidated, descriptorLive,
                 deviceDmaEnabled, driverDmaUnmapped, iommufdUnmapped,
                 iommuPtePresent, iotlbSynced, flushQueued, dmaInFlight,
                 FALSE, TRUE, oldMemoryViewMapped, TRUE, TRUE,
                 completionQuarantined, delivered, dmaInvalidationReceipt,
                 revoked, queueReassigned, monitorOwnsDmaRoot, newWorkEmbargo,
                 hwQueueQuiesced, hwDescriptorsDrained, accessUsersReleased,
                 TRUE)

UnsafeNewMemoryViewBeforeOldUnmapped ==
    /\ ALLOW_UNSAFE_NEW_MEMORYVIEW_BEFORE_OLD_UNMAPPED
    /\ phase = "IotlbSynced"
    /\ oldMemoryViewMapped
    /\ Set("BadNewMemoryViewBeforeOldUnmapped", queueTagLive,
                 queueEpochFresh, irqInvalidated, descriptorLive,
                 deviceDmaEnabled, driverDmaUnmapped, iommufdUnmapped,
                 iommuPtePresent, iotlbSynced, flushQueued, dmaInFlight,
                 pageOwnerOld, TRUE, oldMemoryViewMapped, TRUE,
                 packetPageReturned, completionQuarantined, delivered,
                 dmaInvalidationReceipt, revoked, queueReassigned,
                 monitorOwnsDmaRoot, newWorkEmbargo, hwQueueQuiesced,
                 hwDescriptorsDrained, accessUsersReleased, TRUE)

UnsafeCompletionAfterRevoke ==
    /\ ALLOW_UNSAFE_COMPLETION_AFTER_REVOKE
    /\ phase = "Revoking"
    /\ ~completionQuarantined
    /\ Set("BadCompletionAfterRevoke", queueTagLive, queueEpochFresh,
                 irqInvalidated, descriptorLive, deviceDmaEnabled,
                 driverDmaUnmapped, iommufdUnmapped, iommuPtePresent,
                 iotlbSynced, flushQueued, dmaInFlight, pageOwnerOld,
                 pageOwnerNew, oldMemoryViewMapped, newMemoryViewMapped,
                 packetPageReturned, completionQuarantined, TRUE,
                 dmaInvalidationReceipt, revoked, queueReassigned,
                 monitorOwnsDmaRoot, newWorkEmbargo, hwQueueQuiesced,
                 hwDescriptorsDrained, accessUsersReleased,
                 deviceDmaDomainBlocked)

UnsafePacketReturnBeforeReceipt ==
    /\ ALLOW_UNSAFE_PACKET_RETURN_BEFORE_RECEIPT
    /\ phase = "Drained"
    /\ ~dmaInvalidationReceipt
    /\ Set("BadPacketReturnBeforeReceipt", queueTagLive, queueEpochFresh,
                 irqInvalidated, descriptorLive, deviceDmaEnabled,
                 driverDmaUnmapped, iommufdUnmapped, iommuPtePresent,
                 iotlbSynced, flushQueued, dmaInFlight, pageOwnerOld,
                 pageOwnerNew, oldMemoryViewMapped, newMemoryViewMapped,
                 TRUE, completionQuarantined, delivered, dmaInvalidationReceipt,
                 revoked, queueReassigned, monitorOwnsDmaRoot, newWorkEmbargo,
                 hwQueueQuiesced, hwDescriptorsDrained, accessUsersReleased,
                 deviceDmaDomainBlocked)

Next ==
    \/ BindQueue
    \/ RevokeStart
    \/ InvalidateIrqRoute
    \/ StopQueueAndDescriptors
    \/ ObserveHwQueueQuiesce
    \/ DrainHwOwnedDescriptors
    \/ DriverDmaUnmap
    \/ ReleaseAccessUsers
    \/ IommuUnmapQueued
    \/ IotlbFlushComplete
    \/ BlockDmaDomain
    \/ DrainOutstandingDma
    \/ UnmapOldMemoryView
    \/ IssueDmaReceipt
    \/ TransferPageOwner
    \/ ReassignWithDmaReceipt
    \/ UnsafeIrqOnlyReassign
    \/ UnsafeDriverUnmapOnlyReceipt
    \/ UnsafeIommuUnmapNoIotlbSync
    \/ UnsafeQueuedFlushReceipt
    \/ UnsafePageOwnerTransferWithDmaInFlight
    \/ UnsafeNewMemoryViewBeforeOldUnmapped
    \/ UnsafeCompletionAfterRevoke
    \/ UnsafePacketReturnBeforeReceipt

Spec == Init /\ [][Next]_vars

NoReceiptWithoutFullDmaInvalidation ==
    dmaInvalidationReceipt =>
        /\ revoked
        /\ irqInvalidated
        /\ ~queueEpochFresh
        /\ ~descriptorLive
        /\ ~deviceDmaEnabled
        /\ driverDmaUnmapped
        /\ monitorOwnsDmaRoot
        /\ newWorkEmbargo
        /\ hwQueueQuiesced
        /\ hwDescriptorsDrained
        /\ accessUsersReleased
        /\ deviceDmaDomainBlocked
        /\ iommufdUnmapped
        /\ ~iommuPtePresent
        /\ iotlbSynced
        /\ ~flushQueued
        /\ ~dmaInFlight
        /\ completionQuarantined
        /\ ~oldMemoryViewMapped

NoQueuedFlushAsReceipt ==
    dmaInvalidationReceipt => (~flushQueued /\ iotlbSynced)

NoReassignWithoutDmaReceipt ==
    queueReassigned => dmaInvalidationReceipt

NoPageOwnerTransferBeforeDmaSafe ==
    pageOwnerNew =>
        /\ dmaInvalidationReceipt
        /\ ~pageOwnerOld
        /\ ~oldMemoryViewMapped
        /\ ~iommuPtePresent
        /\ iotlbSynced
        /\ ~flushQueued
        /\ ~dmaInFlight
        /\ monitorOwnsDmaRoot
        /\ newWorkEmbargo
        /\ hwQueueQuiesced
        /\ hwDescriptorsDrained
        /\ accessUsersReleased
        /\ deviceDmaDomainBlocked

NoNewMemoryViewBeforeOldUnmappedAndSynced ==
    newMemoryViewMapped =>
        /\ dmaInvalidationReceipt
        /\ ~oldMemoryViewMapped
        /\ ~iommuPtePresent
        /\ iotlbSynced
        /\ ~flushQueued
        /\ ~dmaInFlight
        /\ monitorOwnsDmaRoot
        /\ newWorkEmbargo
        /\ hwQueueQuiesced
        /\ hwDescriptorsDrained
        /\ accessUsersReleased
        /\ deviceDmaDomainBlocked

NoNormalDeliveryAfterRevoke ==
    ~(revoked /\ delivered /\ ~completionQuarantined)

NoPacketReturnBeforeReceipt ==
    packetPageReturned =>
        /\ dmaInvalidationReceipt
        /\ ~oldMemoryViewMapped
        /\ ~iommuPtePresent
        /\ iotlbSynced
        /\ ~flushQueued
        /\ ~dmaInFlight
        /\ monitorOwnsDmaRoot
        /\ newWorkEmbargo
        /\ hwQueueQuiesced
        /\ hwDescriptorsDrained
        /\ accessUsersReleased
        /\ deviceDmaDomainBlocked

NoReachableOldDmaAfterReassign ==
    queueReassigned =>
        /\ ~queueTagLive
        /\ ~descriptorLive
        /\ ~deviceDmaEnabled
        /\ ~iommuPtePresent
        /\ iotlbSynced
        /\ ~flushQueued
        /\ ~dmaInFlight
        /\ ~oldMemoryViewMapped
        /\ monitorOwnsDmaRoot
        /\ newWorkEmbargo
        /\ hwQueueQuiesced
        /\ hwDescriptorsDrained
        /\ accessUsersReleased
        /\ deviceDmaDomainBlocked

=============================================================================
