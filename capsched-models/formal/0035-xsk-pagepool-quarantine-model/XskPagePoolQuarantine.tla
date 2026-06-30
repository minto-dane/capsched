---------------------- MODULE XskPagePoolQuarantine ----------------------
EXTENDS Naturals

CONSTANTS
    ALLOW_UNSAFE_XSK_CQ_SUBMIT_AFTER_REVOKE,
    ALLOW_UNSAFE_XSK_FREE_LIST_RETURN_AFTER_REVOKE,
    ALLOW_UNSAFE_PAGE_POOL_RECYCLE_AFTER_REVOKE,
    ALLOW_UNSAFE_PACKET_RETURN_BEFORE_DMA_RECEIPT,
    ALLOW_UNSAFE_PAGE_OWNER_BEFORE_QUARANTINE,
    ALLOW_UNSAFE_RETURN_WITHOUT_GENERATION_RESET,
    ALLOW_UNSAFE_DOUBLE_RETURN,
    ALLOW_UNSAFE_REASSIGN_BEFORE_SETTLEMENT

VARIABLES
    phase,
    queueEpochFresh,
    xskPoolEpochFresh,
    pagePoolEpochFresh,
    revoked,
    dmaReceipt,
    xskDescInHw,
    xskCqReserved,
    xskCqSubmitted,
    xskCompletionQuarantined,
    xskFreeListReturn,
    pagePoolFrameInHw,
    pagePoolNormalRecycle,
    pagePoolQuarantined,
    staleCompletionClassified,
    packetGenerationReset,
    pageOwnerOld,
    pageOwnerNew,
    packetReturned,
    doubleReturned,
    queueReassigned

vars == <<phase, queueEpochFresh, xskPoolEpochFresh, pagePoolEpochFresh,
          revoked, dmaReceipt, xskDescInHw, xskCqReserved, xskCqSubmitted,
          xskCompletionQuarantined, xskFreeListReturn, pagePoolFrameInHw,
          pagePoolNormalRecycle, pagePoolQuarantined,
          staleCompletionClassified, packetGenerationReset, pageOwnerOld,
          pageOwnerNew, packetReturned, doubleReturned, queueReassigned>>

Phases == {
    "Start",
    "Bound",
    "Outstanding",
    "Revoked",
    "DmaInvalidated",
    "Classified",
    "XskQuarantined",
    "PagePoolQuarantined",
    "GenerationReset",
    "Returned",
    "Reassigned",
    "BadXskCqSubmitAfterRevoke",
    "BadXskFreeListReturnAfterRevoke",
    "BadPagePoolRecycleAfterRevoke",
    "BadPacketReturnBeforeDmaReceipt",
    "BadPageOwnerBeforeQuarantine",
    "BadReturnWithoutGenerationReset",
    "BadDoubleReturn",
    "BadReassignBeforeSettlement"
}

TypeOK ==
    /\ phase \in Phases
    /\ queueEpochFresh \in BOOLEAN
    /\ xskPoolEpochFresh \in BOOLEAN
    /\ pagePoolEpochFresh \in BOOLEAN
    /\ revoked \in BOOLEAN
    /\ dmaReceipt \in BOOLEAN
    /\ xskDescInHw \in BOOLEAN
    /\ xskCqReserved \in BOOLEAN
    /\ xskCqSubmitted \in BOOLEAN
    /\ xskCompletionQuarantined \in BOOLEAN
    /\ xskFreeListReturn \in BOOLEAN
    /\ pagePoolFrameInHw \in BOOLEAN
    /\ pagePoolNormalRecycle \in BOOLEAN
    /\ pagePoolQuarantined \in BOOLEAN
    /\ staleCompletionClassified \in BOOLEAN
    /\ packetGenerationReset \in BOOLEAN
    /\ pageOwnerOld \in BOOLEAN
    /\ pageOwnerNew \in BOOLEAN
    /\ packetReturned \in BOOLEAN
    /\ doubleReturned \in BOOLEAN
    /\ queueReassigned \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ queueEpochFresh = FALSE
    /\ xskPoolEpochFresh = FALSE
    /\ pagePoolEpochFresh = FALSE
    /\ revoked = FALSE
    /\ dmaReceipt = FALSE
    /\ xskDescInHw = FALSE
    /\ xskCqReserved = FALSE
    /\ xskCqSubmitted = FALSE
    /\ xskCompletionQuarantined = FALSE
    /\ xskFreeListReturn = FALSE
    /\ pagePoolFrameInHw = FALSE
    /\ pagePoolNormalRecycle = FALSE
    /\ pagePoolQuarantined = FALSE
    /\ staleCompletionClassified = FALSE
    /\ packetGenerationReset = FALSE
    /\ pageOwnerOld = FALSE
    /\ pageOwnerNew = FALSE
    /\ packetReturned = FALSE
    /\ doubleReturned = FALSE
    /\ queueReassigned = FALSE

Set(p, qef, xef, pef, rev, dma, xhw, cqres, cqsub, xq, xfree,
    phw, precycle, pq, classified, genreset, ownerOld, ownerNew,
    returned, doubleRet, reassigned) ==
    /\ phase' = p
    /\ queueEpochFresh' = qef
    /\ xskPoolEpochFresh' = xef
    /\ pagePoolEpochFresh' = pef
    /\ revoked' = rev
    /\ dmaReceipt' = dma
    /\ xskDescInHw' = xhw
    /\ xskCqReserved' = cqres
    /\ xskCqSubmitted' = cqsub
    /\ xskCompletionQuarantined' = xq
    /\ xskFreeListReturn' = xfree
    /\ pagePoolFrameInHw' = phw
    /\ pagePoolNormalRecycle' = precycle
    /\ pagePoolQuarantined' = pq
    /\ staleCompletionClassified' = classified
    /\ packetGenerationReset' = genreset
    /\ pageOwnerOld' = ownerOld
    /\ pageOwnerNew' = ownerNew
    /\ packetReturned' = returned
    /\ doubleReturned' = doubleRet
    /\ queueReassigned' = reassigned

BindFreshPools ==
    /\ phase = "Start"
    /\ Set("Bound", TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE,
           FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
           TRUE, FALSE, FALSE, FALSE, FALSE)

SubmitOutstandingPacketMemory ==
    /\ phase = "Bound"
    /\ Set("Outstanding", queueEpochFresh, xskPoolEpochFresh,
           pagePoolEpochFresh, revoked, dmaReceipt, TRUE, TRUE, FALSE,
           FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, packetGenerationReset,
           pageOwnerOld, pageOwnerNew, packetReturned, doubleReturned,
           queueReassigned)

RevokeQueueEpoch ==
    /\ phase = "Outstanding"
    /\ Set("Revoked", FALSE, FALSE, FALSE, TRUE, dmaReceipt, xskDescInHw,
           xskCqReserved, xskCqSubmitted, xskCompletionQuarantined,
           xskFreeListReturn, pagePoolFrameInHw, pagePoolNormalRecycle,
           pagePoolQuarantined, staleCompletionClassified,
           packetGenerationReset, pageOwnerOld, pageOwnerNew,
           packetReturned, doubleReturned, queueReassigned)

ApplyDmaReceipt ==
    /\ phase = "Revoked"
    /\ Set("DmaInvalidated", queueEpochFresh, xskPoolEpochFresh,
           pagePoolEpochFresh, revoked, TRUE, xskDescInHw, xskCqReserved,
           xskCqSubmitted, xskCompletionQuarantined, xskFreeListReturn,
           pagePoolFrameInHw, pagePoolNormalRecycle, pagePoolQuarantined,
           staleCompletionClassified, packetGenerationReset, pageOwnerOld,
           pageOwnerNew, packetReturned, doubleReturned, queueReassigned)

ClassifyStaleCompletion ==
    /\ phase = "DmaInvalidated"
    /\ dmaReceipt
    /\ Set("Classified", queueEpochFresh, xskPoolEpochFresh,
           pagePoolEpochFresh, revoked, dmaReceipt, xskDescInHw,
           xskCqReserved, xskCqSubmitted, xskCompletionQuarantined,
           xskFreeListReturn, pagePoolFrameInHw, pagePoolNormalRecycle,
           pagePoolQuarantined, TRUE, packetGenerationReset, pageOwnerOld,
           pageOwnerNew, packetReturned, doubleReturned, queueReassigned)

QuarantineXskCompletion ==
    /\ phase = "Classified"
    /\ staleCompletionClassified
    /\ Set("XskQuarantined", queueEpochFresh, xskPoolEpochFresh,
           pagePoolEpochFresh, revoked, dmaReceipt, FALSE, FALSE, FALSE,
           TRUE, FALSE, pagePoolFrameInHw, pagePoolNormalRecycle,
           pagePoolQuarantined, staleCompletionClassified,
           packetGenerationReset, pageOwnerOld, pageOwnerNew,
           packetReturned, doubleReturned, queueReassigned)

QuarantinePagePoolFrame ==
    /\ phase = "XskQuarantined"
    /\ xskCompletionQuarantined
    /\ Set("PagePoolQuarantined", queueEpochFresh, xskPoolEpochFresh,
           pagePoolEpochFresh, revoked, dmaReceipt, xskDescInHw,
           xskCqReserved, xskCqSubmitted, xskCompletionQuarantined,
           xskFreeListReturn, FALSE, FALSE, TRUE, staleCompletionClassified,
           packetGenerationReset, pageOwnerOld, pageOwnerNew,
           packetReturned, doubleReturned, queueReassigned)

ResetPacketGeneration ==
    /\ phase = "PagePoolQuarantined"
    /\ pagePoolQuarantined
    /\ Set("GenerationReset", queueEpochFresh, xskPoolEpochFresh,
           pagePoolEpochFresh, revoked, dmaReceipt, xskDescInHw,
           xskCqReserved, xskCqSubmitted, xskCompletionQuarantined,
           xskFreeListReturn, pagePoolFrameInHw, pagePoolNormalRecycle,
           pagePoolQuarantined, staleCompletionClassified, TRUE,
           pageOwnerOld, pageOwnerNew, packetReturned, doubleReturned,
           queueReassigned)

ReturnPacketMemory ==
    /\ phase = "GenerationReset"
    /\ dmaReceipt
    /\ xskCompletionQuarantined
    /\ pagePoolQuarantined
    /\ packetGenerationReset
    /\ Set("Returned", queueEpochFresh, xskPoolEpochFresh,
           pagePoolEpochFresh, revoked, dmaReceipt, xskDescInHw,
           xskCqReserved, xskCqSubmitted, xskCompletionQuarantined,
           xskFreeListReturn, pagePoolFrameInHw, pagePoolNormalRecycle,
           pagePoolQuarantined, staleCompletionClassified,
           packetGenerationReset, FALSE, TRUE, TRUE, doubleReturned,
           queueReassigned)

ReassignAfterSettlement ==
    /\ phase = "Returned"
    /\ packetReturned
    /\ Set("Reassigned", queueEpochFresh, xskPoolEpochFresh,
           pagePoolEpochFresh, revoked, dmaReceipt, xskDescInHw,
           xskCqReserved, xskCqSubmitted, xskCompletionQuarantined,
           xskFreeListReturn, pagePoolFrameInHw, pagePoolNormalRecycle,
           pagePoolQuarantined, staleCompletionClassified,
           packetGenerationReset, pageOwnerOld, pageOwnerNew,
           packetReturned, doubleReturned, TRUE)

UnsafeXskCqSubmitAfterRevoke ==
    /\ ALLOW_UNSAFE_XSK_CQ_SUBMIT_AFTER_REVOKE
    /\ phase = "Revoked"
    /\ Set("BadXskCqSubmitAfterRevoke", queueEpochFresh, xskPoolEpochFresh,
           pagePoolEpochFresh, revoked, dmaReceipt, xskDescInHw,
           xskCqReserved, TRUE, xskCompletionQuarantined,
           xskFreeListReturn, pagePoolFrameInHw, pagePoolNormalRecycle,
           pagePoolQuarantined, staleCompletionClassified,
           packetGenerationReset, pageOwnerOld, pageOwnerNew,
           packetReturned, doubleReturned, queueReassigned)

UnsafeXskFreeListReturnAfterRevoke ==
    /\ ALLOW_UNSAFE_XSK_FREE_LIST_RETURN_AFTER_REVOKE
    /\ phase = "Revoked"
    /\ Set("BadXskFreeListReturnAfterRevoke", queueEpochFresh,
           xskPoolEpochFresh, pagePoolEpochFresh, revoked, dmaReceipt,
           FALSE, FALSE, xskCqSubmitted, xskCompletionQuarantined,
           TRUE, pagePoolFrameInHw, pagePoolNormalRecycle,
           pagePoolQuarantined, staleCompletionClassified,
           packetGenerationReset, pageOwnerOld, pageOwnerNew,
           packetReturned, doubleReturned, queueReassigned)

UnsafePagePoolRecycleAfterRevoke ==
    /\ ALLOW_UNSAFE_PAGE_POOL_RECYCLE_AFTER_REVOKE
    /\ phase = "Revoked"
    /\ Set("BadPagePoolRecycleAfterRevoke", queueEpochFresh,
           xskPoolEpochFresh, pagePoolEpochFresh, revoked, dmaReceipt,
           xskDescInHw, xskCqReserved, xskCqSubmitted,
           xskCompletionQuarantined, xskFreeListReturn, FALSE, TRUE,
           pagePoolQuarantined, staleCompletionClassified,
           packetGenerationReset, pageOwnerOld, pageOwnerNew,
           packetReturned, doubleReturned, queueReassigned)

UnsafePacketReturnBeforeDmaReceipt ==
    /\ ALLOW_UNSAFE_PACKET_RETURN_BEFORE_DMA_RECEIPT
    /\ phase = "Revoked"
    /\ ~dmaReceipt
    /\ Set("BadPacketReturnBeforeDmaReceipt", queueEpochFresh,
           xskPoolEpochFresh, pagePoolEpochFresh, revoked, dmaReceipt,
           xskDescInHw, xskCqReserved, xskCqSubmitted,
           xskCompletionQuarantined, xskFreeListReturn, pagePoolFrameInHw,
           pagePoolNormalRecycle, pagePoolQuarantined,
           staleCompletionClassified, packetGenerationReset, FALSE, TRUE,
           TRUE, doubleReturned, queueReassigned)

UnsafePageOwnerBeforeQuarantine ==
    /\ ALLOW_UNSAFE_PAGE_OWNER_BEFORE_QUARANTINE
    /\ phase = "DmaInvalidated"
    /\ Set("BadPageOwnerBeforeQuarantine", queueEpochFresh,
           xskPoolEpochFresh, pagePoolEpochFresh, revoked, dmaReceipt,
           xskDescInHw, xskCqReserved, xskCqSubmitted,
           xskCompletionQuarantined, xskFreeListReturn, pagePoolFrameInHw,
           pagePoolNormalRecycle, pagePoolQuarantined,
           staleCompletionClassified, packetGenerationReset, FALSE, TRUE,
           packetReturned, doubleReturned, queueReassigned)

UnsafeReturnWithoutGenerationReset ==
    /\ ALLOW_UNSAFE_RETURN_WITHOUT_GENERATION_RESET
    /\ phase = "PagePoolQuarantined"
    /\ ~packetGenerationReset
    /\ Set("BadReturnWithoutGenerationReset", queueEpochFresh,
           xskPoolEpochFresh, pagePoolEpochFresh, revoked, dmaReceipt,
           xskDescInHw, xskCqReserved, xskCqSubmitted,
           xskCompletionQuarantined, xskFreeListReturn, pagePoolFrameInHw,
           pagePoolNormalRecycle, pagePoolQuarantined,
           staleCompletionClassified, packetGenerationReset, FALSE, TRUE,
           TRUE, doubleReturned, queueReassigned)

UnsafeDoubleReturn ==
    /\ ALLOW_UNSAFE_DOUBLE_RETURN
    /\ phase = "PagePoolQuarantined"
    /\ Set("BadDoubleReturn", queueEpochFresh, xskPoolEpochFresh,
           pagePoolEpochFresh, revoked, dmaReceipt, xskDescInHw,
           xskCqReserved, xskCqSubmitted, TRUE, TRUE, pagePoolFrameInHw,
           TRUE, TRUE, staleCompletionClassified, TRUE, FALSE, TRUE,
           TRUE, TRUE, queueReassigned)

UnsafeReassignBeforeSettlement ==
    /\ ALLOW_UNSAFE_REASSIGN_BEFORE_SETTLEMENT
    /\ phase = "DmaInvalidated"
    /\ Set("BadReassignBeforeSettlement", queueEpochFresh,
           xskPoolEpochFresh, pagePoolEpochFresh, revoked, dmaReceipt,
           xskDescInHw, xskCqReserved, xskCqSubmitted,
           xskCompletionQuarantined, xskFreeListReturn, pagePoolFrameInHw,
           pagePoolNormalRecycle, pagePoolQuarantined,
           staleCompletionClassified, packetGenerationReset, pageOwnerOld,
           pageOwnerNew, packetReturned, doubleReturned, TRUE)

Next ==
    \/ BindFreshPools
    \/ SubmitOutstandingPacketMemory
    \/ RevokeQueueEpoch
    \/ ApplyDmaReceipt
    \/ ClassifyStaleCompletion
    \/ QuarantineXskCompletion
    \/ QuarantinePagePoolFrame
    \/ ResetPacketGeneration
    \/ ReturnPacketMemory
    \/ ReassignAfterSettlement
    \/ UnsafeXskCqSubmitAfterRevoke
    \/ UnsafeXskFreeListReturnAfterRevoke
    \/ UnsafePagePoolRecycleAfterRevoke
    \/ UnsafePacketReturnBeforeDmaReceipt
    \/ UnsafePageOwnerBeforeQuarantine
    \/ UnsafeReturnWithoutGenerationReset
    \/ UnsafeDoubleReturn
    \/ UnsafeReassignBeforeSettlement

Spec == Init /\ [][Next]_vars

NoXskCqSubmitAfterRevokeWithoutFreshEpoch ==
    xskCqSubmitted => (~revoked /\ queueEpochFresh /\ xskPoolEpochFresh)

NoXskFreeListReturnAfterRevokeWithoutQuarantine ==
    xskFreeListReturn => (~revoked /\ xskPoolEpochFresh)

NoPagePoolNormalRecycleAfterRevoke ==
    pagePoolNormalRecycle => (~revoked /\ pagePoolEpochFresh)

NoPacketReturnBeforeDmaReceipt ==
    packetReturned => dmaReceipt

NoPageOwnerTransferBeforeQuarantine ==
    pageOwnerNew =>
        /\ dmaReceipt
        /\ xskCompletionQuarantined
        /\ pagePoolQuarantined
        /\ staleCompletionClassified

NoPacketReturnWithoutGenerationReset ==
    packetReturned => packetGenerationReset

NoDoubleReturn ==
    ~doubleReturned

NoReassignBeforeSettlement ==
    queueReassigned =>
        /\ packetReturned
        /\ dmaReceipt
        /\ xskCompletionQuarantined
        /\ pagePoolQuarantined
        /\ packetGenerationReset

NoOutstandingAfterReassign ==
    queueReassigned =>
        /\ ~xskDescInHw
        /\ ~xskCqReserved
        /\ ~pagePoolFrameInHw

=============================================================================
