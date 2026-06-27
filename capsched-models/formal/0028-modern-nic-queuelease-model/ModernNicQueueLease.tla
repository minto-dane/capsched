------------------------ MODULE ModernNicQueueLease ------------------------
EXTENDS Naturals

VARIABLES
    phase,
    queueBound,
    queueLive,
    epochFresh,
    irqRouteLive,
    napiOwned,
    queueBudget,
    serviceBudget,
    queueControlCap,
    runCapOnly,
    controlChanged,
    skbSubmitCap,
    skbIommuLive,
    xdpFrameCap,
    xdpFrameDmaLive,
    xdpTxCap,
    pagePoolOwned,
    afxdpCap,
    xskOwned,
    reprCap,
    lowerQueueLease,
    representorForwarded,
    serviceAuthority,
    serviceWorkRan,
    serviceChargedToLast,
    callerEffectFromService,
    submitClass,
    ledgerClass,
    descriptorPublished,
    doorbellRung,
    submitted,
    inFlight,
    completionPending,
    completionRunning,
    delivered,
    revoked,
    badClassCollapse,
    ambientCompletion,
    submitWithoutBind,
    submitWithoutBudget,
    staleDelivery

vars == <<phase, queueBound, queueLive, epochFresh, irqRouteLive, napiOwned,
          queueBudget, serviceBudget, queueControlCap, runCapOnly,
          controlChanged, skbSubmitCap, skbIommuLive, xdpFrameCap,
          xdpFrameDmaLive, xdpTxCap, pagePoolOwned, afxdpCap, xskOwned,
          reprCap, lowerQueueLease, representorForwarded, serviceAuthority,
          serviceWorkRan, serviceChargedToLast, callerEffectFromService,
          submitClass, ledgerClass, descriptorPublished, doorbellRung,
          submitted, inFlight, completionPending, completionRunning,
          delivered, revoked, badClassCollapse, ambientCompletion,
          submitWithoutBind, submitWithoutBudget, staleDelivery>>

SubmitClasses == {"SKB", "XDP_FRAME", "XDP_TX_PAGE_POOL", "AF_XDP"}

Classes == SubmitClasses \cup {"None"}

Phases == {
    "Start",
    "Ready",
    "Submitted",
    "CompletionPending",
    "CompletionRunning",
    "Settled",
    "Revoked",
    "ControlChanged",
    "RepresentorForwarded",
    "ServiceMaintained",
    "BadSubmitNoBind",
    "BadSubmitNoBudget",
    "BadSKBNoIommu",
    "BadXDPUsesSKBLedger",
    "BadAFXDPNoXSK",
    "BadRepresentorNoDerive",
    "BadDevlinkViaRunCap",
    "BadServiceLastCaller",
    "BadAmbientCompletion",
    "BadDeliverAfterRevoke"
}

TypeOK ==
    /\ phase \in Phases
    /\ queueBound \in BOOLEAN
    /\ queueLive \in BOOLEAN
    /\ epochFresh \in BOOLEAN
    /\ irqRouteLive \in BOOLEAN
    /\ napiOwned \in BOOLEAN
    /\ queueBudget \in BOOLEAN
    /\ serviceBudget \in BOOLEAN
    /\ queueControlCap \in BOOLEAN
    /\ runCapOnly \in BOOLEAN
    /\ controlChanged \in BOOLEAN
    /\ skbSubmitCap \in BOOLEAN
    /\ skbIommuLive \in BOOLEAN
    /\ xdpFrameCap \in BOOLEAN
    /\ xdpFrameDmaLive \in BOOLEAN
    /\ xdpTxCap \in BOOLEAN
    /\ pagePoolOwned \in BOOLEAN
    /\ afxdpCap \in BOOLEAN
    /\ xskOwned \in BOOLEAN
    /\ reprCap \in BOOLEAN
    /\ lowerQueueLease \in BOOLEAN
    /\ representorForwarded \in BOOLEAN
    /\ serviceAuthority \in BOOLEAN
    /\ serviceWorkRan \in BOOLEAN
    /\ serviceChargedToLast \in BOOLEAN
    /\ callerEffectFromService \in BOOLEAN
    /\ submitClass \in Classes
    /\ ledgerClass \in Classes
    /\ descriptorPublished \in BOOLEAN
    /\ doorbellRung \in BOOLEAN
    /\ submitted \in BOOLEAN
    /\ inFlight \in BOOLEAN
    /\ completionPending \in BOOLEAN
    /\ completionRunning \in BOOLEAN
    /\ delivered \in BOOLEAN
    /\ revoked \in BOOLEAN
    /\ badClassCollapse \in BOOLEAN
    /\ ambientCompletion \in BOOLEAN
    /\ submitWithoutBind \in BOOLEAN
    /\ submitWithoutBudget \in BOOLEAN
    /\ staleDelivery \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ queueBound = FALSE
    /\ queueLive = FALSE
    /\ epochFresh = FALSE
    /\ irqRouteLive = FALSE
    /\ napiOwned = FALSE
    /\ queueBudget = FALSE
    /\ serviceBudget = FALSE
    /\ queueControlCap = FALSE
    /\ runCapOnly = FALSE
    /\ controlChanged = FALSE
    /\ skbSubmitCap = FALSE
    /\ skbIommuLive = FALSE
    /\ xdpFrameCap = FALSE
    /\ xdpFrameDmaLive = FALSE
    /\ xdpTxCap = FALSE
    /\ pagePoolOwned = FALSE
    /\ afxdpCap = FALSE
    /\ xskOwned = FALSE
    /\ reprCap = FALSE
    /\ lowerQueueLease = FALSE
    /\ representorForwarded = FALSE
    /\ serviceAuthority = FALSE
    /\ serviceWorkRan = FALSE
    /\ serviceChargedToLast = FALSE
    /\ callerEffectFromService = FALSE
    /\ submitClass = "None"
    /\ ledgerClass = "None"
    /\ descriptorPublished = FALSE
    /\ doorbellRung = FALSE
    /\ submitted = FALSE
    /\ inFlight = FALSE
    /\ completionPending = FALSE
    /\ completionRunning = FALSE
    /\ delivered = FALSE
    /\ revoked = FALSE
    /\ badClassCollapse = FALSE
    /\ ambientCompletion = FALSE
    /\ submitWithoutBind = FALSE
    /\ submitWithoutBudget = FALSE
    /\ staleDelivery = FALSE

PrepareQueueBind ==
    /\ phase = "Start"
    /\ queueBound' = TRUE
    /\ queueLive' = TRUE
    /\ epochFresh' = TRUE
    /\ irqRouteLive' = TRUE
    /\ napiOwned' = TRUE
    /\ queueBudget' = TRUE
    /\ serviceBudget' = TRUE
    /\ serviceAuthority' = TRUE
    /\ phase' = "Ready"
    /\ UNCHANGED <<queueControlCap, runCapOnly, controlChanged,
                    skbSubmitCap, skbIommuLive, xdpFrameCap,
                    xdpFrameDmaLive, xdpTxCap, pagePoolOwned, afxdpCap,
                    xskOwned, reprCap, lowerQueueLease,
                    representorForwarded, serviceWorkRan,
                    serviceChargedToLast, callerEffectFromService,
                    submitClass, ledgerClass, descriptorPublished,
                    doorbellRung, submitted, inFlight, completionPending,
                    completionRunning, delivered, revoked, badClassCollapse,
                    ambientCompletion, submitWithoutBind, submitWithoutBudget,
                    staleDelivery>>

AuthorizeSKB ==
    /\ phase = "Ready"
    /\ skbSubmitCap' = TRUE
    /\ skbIommuLive' = TRUE
    /\ UNCHANGED <<phase, queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, xdpFrameCap, xdpFrameDmaLive,
                    xdpTxCap, pagePoolOwned, afxdpCap, xskOwned, reprCap,
                    lowerQueueLease, representorForwarded, serviceAuthority,
                    serviceWorkRan, serviceChargedToLast,
                    callerEffectFromService, submitClass, ledgerClass,
                    descriptorPublished, doorbellRung, submitted, inFlight,
                    completionPending, completionRunning, delivered, revoked,
                    badClassCollapse, ambientCompletion, submitWithoutBind,
                    submitWithoutBudget, staleDelivery>>

AuthorizeXDPFrame ==
    /\ phase = "Ready"
    /\ xdpFrameCap' = TRUE
    /\ xdpFrameDmaLive' = TRUE
    /\ UNCHANGED <<phase, queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, skbSubmitCap, skbIommuLive,
                    xdpTxCap, pagePoolOwned, afxdpCap, xskOwned, reprCap,
                    lowerQueueLease, representorForwarded, serviceAuthority,
                    serviceWorkRan, serviceChargedToLast,
                    callerEffectFromService, submitClass, ledgerClass,
                    descriptorPublished, doorbellRung, submitted, inFlight,
                    completionPending, completionRunning, delivered, revoked,
                    badClassCollapse, ambientCompletion, submitWithoutBind,
                    submitWithoutBudget, staleDelivery>>

AuthorizeXDPTx ==
    /\ phase = "Ready"
    /\ xdpTxCap' = TRUE
    /\ pagePoolOwned' = TRUE
    /\ UNCHANGED <<phase, queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, skbSubmitCap, skbIommuLive,
                    xdpFrameCap, xdpFrameDmaLive, afxdpCap, xskOwned, reprCap,
                    lowerQueueLease, representorForwarded, serviceAuthority,
                    serviceWorkRan, serviceChargedToLast,
                    callerEffectFromService, submitClass, ledgerClass,
                    descriptorPublished, doorbellRung, submitted, inFlight,
                    completionPending, completionRunning, delivered, revoked,
                    badClassCollapse, ambientCompletion, submitWithoutBind,
                    submitWithoutBudget, staleDelivery>>

AuthorizeAFXDP ==
    /\ phase = "Ready"
    /\ afxdpCap' = TRUE
    /\ xskOwned' = TRUE
    /\ UNCHANGED <<phase, queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, skbSubmitCap, skbIommuLive,
                    xdpFrameCap, xdpFrameDmaLive, xdpTxCap, pagePoolOwned,
                    reprCap, lowerQueueLease, representorForwarded,
                    serviceAuthority, serviceWorkRan, serviceChargedToLast,
                    callerEffectFromService, submitClass, ledgerClass,
                    descriptorPublished, doorbellRung, submitted, inFlight,
                    completionPending, completionRunning, delivered, revoked,
                    badClassCollapse, ambientCompletion, submitWithoutBind,
                    submitWithoutBudget, staleDelivery>>

AuthorizeQueueControl ==
    /\ phase = "Ready"
    /\ queueControlCap' = TRUE
    /\ UNCHANGED <<phase, queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, runCapOnly,
                    controlChanged, skbSubmitCap, skbIommuLive, xdpFrameCap,
                    xdpFrameDmaLive, xdpTxCap, pagePoolOwned, afxdpCap,
                    xskOwned, reprCap, lowerQueueLease,
                    representorForwarded, serviceAuthority, serviceWorkRan,
                    serviceChargedToLast, callerEffectFromService,
                    submitClass, ledgerClass, descriptorPublished,
                    doorbellRung, submitted, inFlight, completionPending,
                    completionRunning, delivered, revoked, badClassCollapse,
                    ambientCompletion, submitWithoutBind, submitWithoutBudget,
                    staleDelivery>>

AuthorizeRepresentor ==
    /\ phase = "Ready"
    /\ reprCap' = TRUE
    /\ lowerQueueLease' = TRUE
    /\ UNCHANGED <<phase, queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, skbSubmitCap, skbIommuLive,
                    xdpFrameCap, xdpFrameDmaLive, xdpTxCap, pagePoolOwned,
                    afxdpCap, xskOwned, representorForwarded,
                    serviceAuthority, serviceWorkRan, serviceChargedToLast,
                    callerEffectFromService, submitClass, ledgerClass,
                    descriptorPublished, doorbellRung, submitted, inFlight,
                    completionPending, completionRunning, delivered, revoked,
                    badClassCollapse, ambientCompletion, submitWithoutBind,
                    submitWithoutBudget, staleDelivery>>

SubmitWith(cls) ==
    /\ phase = "Ready"
    /\ queueBound
    /\ queueLive
    /\ epochFresh
    /\ irqRouteLive
    /\ napiOwned
    /\ queueBudget
    /\ ~submitted
    /\ IF cls = "SKB"
       THEN /\ skbSubmitCap
            /\ skbIommuLive
       ELSE IF cls = "XDP_FRAME"
       THEN /\ xdpFrameCap
            /\ xdpFrameDmaLive
       ELSE IF cls = "XDP_TX_PAGE_POOL"
       THEN /\ xdpTxCap
            /\ pagePoolOwned
       ELSE /\ afxdpCap
            /\ xskOwned
    /\ submitClass' = cls
    /\ ledgerClass' = cls
    /\ descriptorPublished' = TRUE
    /\ doorbellRung' = TRUE
    /\ submitted' = TRUE
    /\ inFlight' = TRUE
    /\ queueBudget' = FALSE
    /\ phase' = "Submitted"
    /\ UNCHANGED <<queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, serviceBudget, queueControlCap, runCapOnly,
                    controlChanged, skbSubmitCap, skbIommuLive, xdpFrameCap,
                    xdpFrameDmaLive, xdpTxCap, pagePoolOwned, afxdpCap,
                    xskOwned, reprCap, lowerQueueLease,
                    representorForwarded, serviceAuthority, serviceWorkRan,
                    serviceChargedToLast, callerEffectFromService,
                    completionPending, completionRunning, delivered, revoked,
                    badClassCollapse, ambientCompletion, submitWithoutBind,
                    submitWithoutBudget, staleDelivery>>

SubmitSKB == SubmitWith("SKB")
SubmitXDPFrame == SubmitWith("XDP_FRAME")
SubmitXDPTx == SubmitWith("XDP_TX_PAGE_POOL")
SubmitAFXDP == SubmitWith("AF_XDP")

DeviceCompletionEvent ==
    /\ phase = "Submitted"
    /\ submitted
    /\ inFlight
    /\ submitClass = ledgerClass
    /\ ledgerClass \in SubmitClasses
    /\ completionPending' = TRUE
    /\ phase' = "CompletionPending"
    /\ UNCHANGED <<queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, skbSubmitCap, skbIommuLive,
                    xdpFrameCap, xdpFrameDmaLive, xdpTxCap, pagePoolOwned,
                    afxdpCap, xskOwned, reprCap, lowerQueueLease,
                    representorForwarded, serviceAuthority, serviceWorkRan,
                    serviceChargedToLast, callerEffectFromService,
                    submitClass, ledgerClass, descriptorPublished,
                    doorbellRung, submitted, inFlight, completionRunning,
                    delivered, revoked, badClassCollapse, ambientCompletion,
                    submitWithoutBind, submitWithoutBudget, staleDelivery>>

RunCompletion ==
    /\ phase = "CompletionPending"
    /\ completionPending
    /\ serviceBudget
    /\ submitClass = ledgerClass
    /\ ledgerClass \in SubmitClasses
    /\ completionPending' = FALSE
    /\ completionRunning' = TRUE
    /\ phase' = "CompletionRunning"
    /\ UNCHANGED <<queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, skbSubmitCap, skbIommuLive,
                    xdpFrameCap, xdpFrameDmaLive, xdpTxCap, pagePoolOwned,
                    afxdpCap, xskOwned, reprCap, lowerQueueLease,
                    representorForwarded, serviceAuthority, serviceWorkRan,
                    serviceChargedToLast, callerEffectFromService,
                    submitClass, ledgerClass, descriptorPublished,
                    doorbellRung, submitted, inFlight, delivered, revoked,
                    badClassCollapse, ambientCompletion, submitWithoutBind,
                    submitWithoutBudget, staleDelivery>>

SettleCompletion ==
    /\ phase = "CompletionRunning"
    /\ completionRunning
    /\ serviceBudget
    /\ submitClass = ledgerClass
    /\ ledgerClass \in SubmitClasses
    /\ descriptorPublished' = FALSE
    /\ doorbellRung' = FALSE
    /\ submitted' = FALSE
    /\ inFlight' = FALSE
    /\ completionRunning' = FALSE
    /\ delivered' = TRUE
    /\ submitClass' = "None"
    /\ ledgerClass' = "None"
    /\ phase' = "Settled"
    /\ UNCHANGED <<queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, skbSubmitCap, skbIommuLive,
                    xdpFrameCap, xdpFrameDmaLive, xdpTxCap, pagePoolOwned,
                    afxdpCap, xskOwned, reprCap, lowerQueueLease,
                    representorForwarded, serviceAuthority, serviceWorkRan,
                    serviceChargedToLast, callerEffectFromService,
                    completionPending, revoked, badClassCollapse,
                    ambientCompletion, submitWithoutBind, submitWithoutBudget,
                    staleDelivery>>

QueueControlChange ==
    /\ phase = "Ready"
    /\ queueControlCap
    /\ controlChanged' = TRUE
    /\ phase' = "ControlChanged"
    /\ UNCHANGED <<queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, skbSubmitCap, skbIommuLive, xdpFrameCap,
                    xdpFrameDmaLive, xdpTxCap, pagePoolOwned, afxdpCap,
                    xskOwned, reprCap, lowerQueueLease,
                    representorForwarded, serviceAuthority, serviceWorkRan,
                    serviceChargedToLast, callerEffectFromService,
                    submitClass, ledgerClass, descriptorPublished,
                    doorbellRung, submitted, inFlight, completionPending,
                    completionRunning, delivered, revoked, badClassCollapse,
                    ambientCompletion, submitWithoutBind, submitWithoutBudget,
                    staleDelivery>>

RepresentorForward ==
    /\ phase = "Ready"
    /\ reprCap
    /\ lowerQueueLease
    /\ representorForwarded' = TRUE
    /\ phase' = "RepresentorForwarded"
    /\ UNCHANGED <<queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, skbSubmitCap, skbIommuLive,
                    xdpFrameCap, xdpFrameDmaLive, xdpTxCap, pagePoolOwned,
                    afxdpCap, xskOwned, reprCap, lowerQueueLease,
                    serviceAuthority, serviceWorkRan, serviceChargedToLast,
                    callerEffectFromService, submitClass, ledgerClass,
                    descriptorPublished, doorbellRung, submitted, inFlight,
                    completionPending, completionRunning, delivered, revoked,
                    badClassCollapse, ambientCompletion, submitWithoutBind,
                    submitWithoutBudget, staleDelivery>>

ServiceMaintenance ==
    /\ phase = "Ready"
    /\ serviceAuthority
    /\ serviceWorkRan' = TRUE
    /\ phase' = "ServiceMaintained"
    /\ UNCHANGED <<queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, skbSubmitCap, skbIommuLive,
                    xdpFrameCap, xdpFrameDmaLive, xdpTxCap, pagePoolOwned,
                    afxdpCap, xskOwned, reprCap, lowerQueueLease,
                    representorForwarded, serviceAuthority,
                    serviceChargedToLast, callerEffectFromService,
                    submitClass, ledgerClass, descriptorPublished,
                    doorbellRung, submitted, inFlight, completionPending,
                    completionRunning, delivered, revoked, badClassCollapse,
                    ambientCompletion, submitWithoutBind, submitWithoutBudget,
                    staleDelivery>>

RevokeQueue ==
    /\ phase \in {"Ready", "Submitted", "CompletionPending",
                  "CompletionRunning"}
    /\ queueLive
    /\ queueBound' = FALSE
    /\ queueLive' = FALSE
    /\ epochFresh' = FALSE
    /\ irqRouteLive' = FALSE
    /\ napiOwned' = FALSE
    /\ queueBudget' = FALSE
    /\ serviceBudget' = FALSE
    /\ descriptorPublished' = FALSE
    /\ doorbellRung' = FALSE
    /\ submitted' = FALSE
    /\ inFlight' = FALSE
    /\ completionPending' = FALSE
    /\ completionRunning' = FALSE
    /\ submitClass' = "None"
    /\ ledgerClass' = "None"
    /\ revoked' = TRUE
    /\ phase' = "Revoked"
    /\ UNCHANGED <<queueControlCap, runCapOnly, controlChanged,
                    skbSubmitCap, skbIommuLive, xdpFrameCap,
                    xdpFrameDmaLive, xdpTxCap, pagePoolOwned, afxdpCap,
                    xskOwned, reprCap, lowerQueueLease,
                    representorForwarded, serviceAuthority, serviceWorkRan,
                    serviceChargedToLast, callerEffectFromService,
                    delivered, badClassCollapse, ambientCompletion,
                    submitWithoutBind, submitWithoutBudget, staleDelivery>>

UnsafeSubmitNoBind ==
    /\ phase = "Start"
    /\ submitWithoutBind' = TRUE
    /\ submitClass' = "SKB"
    /\ ledgerClass' = "SKB"
    /\ descriptorPublished' = TRUE
    /\ doorbellRung' = TRUE
    /\ submitted' = TRUE
    /\ inFlight' = TRUE
    /\ phase' = "BadSubmitNoBind"
    /\ UNCHANGED <<queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, skbSubmitCap, skbIommuLive,
                    xdpFrameCap, xdpFrameDmaLive, xdpTxCap, pagePoolOwned,
                    afxdpCap, xskOwned, reprCap, lowerQueueLease,
                    representorForwarded, serviceAuthority, serviceWorkRan,
                    serviceChargedToLast, callerEffectFromService,
                    completionPending, completionRunning, delivered, revoked,
                    badClassCollapse, ambientCompletion, submitWithoutBudget,
                    staleDelivery>>

UnsafeSubmitNoBudget ==
    /\ phase = "Ready"
    /\ queueBound
    /\ queueLive
    /\ epochFresh
    /\ queueBudget' = FALSE
    /\ submitWithoutBudget' = TRUE
    /\ submitClass' = "SKB"
    /\ ledgerClass' = "SKB"
    /\ descriptorPublished' = TRUE
    /\ doorbellRung' = TRUE
    /\ submitted' = TRUE
    /\ inFlight' = TRUE
    /\ phase' = "BadSubmitNoBudget"
    /\ UNCHANGED <<queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, serviceBudget, queueControlCap, runCapOnly,
                    controlChanged, skbSubmitCap, skbIommuLive, xdpFrameCap,
                    xdpFrameDmaLive, xdpTxCap, pagePoolOwned, afxdpCap,
                    xskOwned, reprCap, lowerQueueLease,
                    representorForwarded, serviceAuthority, serviceWorkRan,
                    serviceChargedToLast, callerEffectFromService,
                    completionPending, completionRunning, delivered, revoked,
                    badClassCollapse, ambientCompletion, submitWithoutBind,
                    staleDelivery>>

UnsafeSKBNoIommu ==
    /\ phase = "Ready"
    /\ queueBound
    /\ queueLive
    /\ epochFresh
    /\ irqRouteLive
    /\ napiOwned
    /\ skbSubmitCap' = TRUE
    /\ skbIommuLive' = FALSE
    /\ submitClass' = "SKB"
    /\ ledgerClass' = "SKB"
    /\ descriptorPublished' = TRUE
    /\ doorbellRung' = TRUE
    /\ submitted' = TRUE
    /\ inFlight' = TRUE
    /\ phase' = "BadSKBNoIommu"
    /\ UNCHANGED <<queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, xdpFrameCap, xdpFrameDmaLive,
                    xdpTxCap, pagePoolOwned, afxdpCap, xskOwned, reprCap,
                    lowerQueueLease, representorForwarded, serviceAuthority,
                    serviceWorkRan, serviceChargedToLast,
                    callerEffectFromService, completionPending,
                    completionRunning, delivered, revoked, badClassCollapse,
                    ambientCompletion, submitWithoutBind, submitWithoutBudget,
                    staleDelivery>>

UnsafeXDPUsesSKBLedger ==
    /\ phase = "Ready"
    /\ queueBound
    /\ queueLive
    /\ epochFresh
    /\ irqRouteLive
    /\ napiOwned
    /\ skbSubmitCap' = TRUE
    /\ skbIommuLive' = TRUE
    /\ submitClass' = "XDP_FRAME"
    /\ ledgerClass' = "SKB"
    /\ badClassCollapse' = TRUE
    /\ descriptorPublished' = TRUE
    /\ doorbellRung' = TRUE
    /\ submitted' = TRUE
    /\ inFlight' = TRUE
    /\ phase' = "BadXDPUsesSKBLedger"
    /\ UNCHANGED <<queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, xdpFrameCap, xdpFrameDmaLive,
                    xdpTxCap, pagePoolOwned, afxdpCap, xskOwned, reprCap,
                    lowerQueueLease, representorForwarded, serviceAuthority,
                    serviceWorkRan, serviceChargedToLast,
                    callerEffectFromService, completionPending,
                    completionRunning, delivered, revoked, ambientCompletion,
                    submitWithoutBind, submitWithoutBudget, staleDelivery>>

UnsafeAFXDPNoXSK ==
    /\ phase = "Ready"
    /\ queueBound
    /\ queueLive
    /\ epochFresh
    /\ irqRouteLive
    /\ napiOwned
    /\ afxdpCap' = TRUE
    /\ xskOwned' = FALSE
    /\ submitClass' = "AF_XDP"
    /\ ledgerClass' = "AF_XDP"
    /\ descriptorPublished' = TRUE
    /\ doorbellRung' = TRUE
    /\ submitted' = TRUE
    /\ inFlight' = TRUE
    /\ phase' = "BadAFXDPNoXSK"
    /\ UNCHANGED <<queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, skbSubmitCap, skbIommuLive,
                    xdpFrameCap, xdpFrameDmaLive, xdpTxCap, pagePoolOwned,
                    reprCap, lowerQueueLease, representorForwarded,
                    serviceAuthority, serviceWorkRan, serviceChargedToLast,
                    callerEffectFromService, completionPending,
                    completionRunning, delivered, revoked, badClassCollapse,
                    ambientCompletion, submitWithoutBind, submitWithoutBudget,
                    staleDelivery>>

UnsafeRepresentorNoDerive ==
    /\ phase = "Ready"
    /\ representorForwarded' = TRUE
    /\ phase' = "BadRepresentorNoDerive"
    /\ UNCHANGED <<queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, skbSubmitCap, skbIommuLive,
                    xdpFrameCap, xdpFrameDmaLive, xdpTxCap, pagePoolOwned,
                    afxdpCap, xskOwned, reprCap, lowerQueueLease,
                    serviceAuthority, serviceWorkRan, serviceChargedToLast,
                    callerEffectFromService, submitClass, ledgerClass,
                    descriptorPublished, doorbellRung, submitted, inFlight,
                    completionPending, completionRunning, delivered, revoked,
                    badClassCollapse, ambientCompletion, submitWithoutBind,
                    submitWithoutBudget, staleDelivery>>

UnsafeDevlinkViaRunCap ==
    /\ phase = "Ready"
    /\ runCapOnly' = TRUE
    /\ queueControlCap' = FALSE
    /\ controlChanged' = TRUE
    /\ phase' = "BadDevlinkViaRunCap"
    /\ UNCHANGED <<queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, skbSubmitCap,
                    skbIommuLive, xdpFrameCap, xdpFrameDmaLive, xdpTxCap,
                    pagePoolOwned, afxdpCap, xskOwned, reprCap,
                    lowerQueueLease, representorForwarded, serviceAuthority,
                    serviceWorkRan, serviceChargedToLast,
                    callerEffectFromService, submitClass, ledgerClass,
                    descriptorPublished, doorbellRung, submitted, inFlight,
                    completionPending, completionRunning, delivered, revoked,
                    badClassCollapse, ambientCompletion, submitWithoutBind,
                    submitWithoutBudget, staleDelivery>>

UnsafeServiceLastCaller ==
    /\ phase = "Ready"
    /\ serviceAuthority
    /\ serviceWorkRan' = TRUE
    /\ serviceChargedToLast' = TRUE
    /\ callerEffectFromService' = TRUE
    /\ phase' = "BadServiceLastCaller"
    /\ UNCHANGED <<queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, skbSubmitCap, skbIommuLive,
                    xdpFrameCap, xdpFrameDmaLive, xdpTxCap, pagePoolOwned,
                    afxdpCap, xskOwned, reprCap, lowerQueueLease,
                    representorForwarded, serviceAuthority, submitClass,
                    ledgerClass, descriptorPublished, doorbellRung,
                    submitted, inFlight, completionPending,
                    completionRunning, delivered, revoked, badClassCollapse,
                    ambientCompletion, submitWithoutBind, submitWithoutBudget,
                    staleDelivery>>

UnsafeAmbientCompletion ==
    /\ phase = "CompletionPending"
    /\ completionPending
    /\ serviceBudget' = FALSE
    /\ ambientCompletion' = TRUE
    /\ completionPending' = FALSE
    /\ completionRunning' = TRUE
    /\ phase' = "BadAmbientCompletion"
    /\ UNCHANGED <<queueBound, queueLive, epochFresh, irqRouteLive,
                    napiOwned, queueBudget, queueControlCap, runCapOnly,
                    controlChanged, skbSubmitCap, skbIommuLive, xdpFrameCap,
                    xdpFrameDmaLive, xdpTxCap, pagePoolOwned, afxdpCap,
                    xskOwned, reprCap, lowerQueueLease,
                    representorForwarded, serviceAuthority, serviceWorkRan,
                    serviceChargedToLast, callerEffectFromService,
                    submitClass, ledgerClass, descriptorPublished,
                    doorbellRung, submitted, inFlight, delivered, revoked,
                    badClassCollapse, submitWithoutBind, submitWithoutBudget,
                    staleDelivery>>

UnsafeDeliverAfterRevoke ==
    /\ phase \in {"Submitted", "CompletionPending"}
    /\ queueLive' = FALSE
    /\ epochFresh' = FALSE
    /\ irqRouteLive' = FALSE
    /\ napiOwned' = FALSE
    /\ revoked' = TRUE
    /\ delivered' = TRUE
    /\ staleDelivery' = TRUE
    /\ phase' = "BadDeliverAfterRevoke"
    /\ UNCHANGED <<queueBound, queueBudget, serviceBudget, queueControlCap,
                    runCapOnly, controlChanged, skbSubmitCap, skbIommuLive,
                    xdpFrameCap, xdpFrameDmaLive, xdpTxCap, pagePoolOwned,
                    afxdpCap, xskOwned, reprCap, lowerQueueLease,
                    representorForwarded, serviceAuthority, serviceWorkRan,
                    serviceChargedToLast, callerEffectFromService,
                    submitClass, ledgerClass, descriptorPublished,
                    doorbellRung, submitted, inFlight, completionPending,
                    completionRunning, badClassCollapse, ambientCompletion,
                    submitWithoutBind, submitWithoutBudget>>

SafeNext ==
    \/ PrepareQueueBind
    \/ AuthorizeSKB
    \/ AuthorizeXDPFrame
    \/ AuthorizeXDPTx
    \/ AuthorizeAFXDP
    \/ AuthorizeQueueControl
    \/ AuthorizeRepresentor
    \/ SubmitSKB
    \/ SubmitXDPFrame
    \/ SubmitXDPTx
    \/ SubmitAFXDP
    \/ DeviceCompletionEvent
    \/ RunCompletion
    \/ SettleCompletion
    \/ QueueControlChange
    \/ RepresentorForward
    \/ ServiceMaintenance
    \/ RevokeQueue

SafeSpec == Init /\ [][SafeNext]_vars

UnsafeSubmitNoBindSpec == Init /\ [][SafeNext \/ UnsafeSubmitNoBind]_vars
UnsafeSubmitNoBudgetSpec == Init /\ [][SafeNext \/ UnsafeSubmitNoBudget]_vars
UnsafeSKBNoIommuSpec == Init /\ [][SafeNext \/ UnsafeSKBNoIommu]_vars
UnsafeXDPUsesSKBLedgerSpec == Init /\ [][SafeNext \/ UnsafeXDPUsesSKBLedger]_vars
UnsafeAFXDPNoXSKSpec == Init /\ [][SafeNext \/ UnsafeAFXDPNoXSK]_vars
UnsafeRepresentorNoDeriveSpec == Init /\ [][SafeNext \/ UnsafeRepresentorNoDerive]_vars
UnsafeDevlinkViaRunCapSpec == Init /\ [][SafeNext \/ UnsafeDevlinkViaRunCap]_vars
UnsafeServiceLastCallerSpec == Init /\ [][SafeNext \/ UnsafeServiceLastCaller]_vars
UnsafeAmbientCompletionSpec == Init /\ [][SafeNext \/ UnsafeAmbientCompletion]_vars
UnsafeDeliverAfterRevokeSpec == Init /\ [][SafeNext \/ UnsafeDeliverAfterRevoke]_vars

NoSubmitWithoutQueueBind ==
    submitted =>
        /\ queueBound
        /\ queueLive
        /\ epochFresh
        /\ irqRouteLive
        /\ napiOwned
        /\ ~submitWithoutBind

NoSubmitWithoutBudget ==
    ~submitWithoutBudget

NoDescriptorDoorbellWithoutTypedLedger ==
    (descriptorPublished \/ doorbellRung) =>
        /\ submitted
        /\ submitClass = ledgerClass
        /\ ledgerClass \in SubmitClasses
        /\ ~badClassCollapse

NoSubmitClassCollapse ==
    submitted =>
        /\ submitClass = ledgerClass
        /\ IF submitClass = "SKB"
           THEN /\ skbSubmitCap
                /\ skbIommuLive
           ELSE TRUE
        /\ IF submitClass = "XDP_FRAME"
           THEN /\ xdpFrameCap
                /\ xdpFrameDmaLive
           ELSE TRUE
        /\ IF submitClass = "XDP_TX_PAGE_POOL"
           THEN /\ xdpTxCap
                /\ pagePoolOwned
           ELSE TRUE
        /\ IF submitClass = "AF_XDP"
           THEN /\ afxdpCap
                /\ xskOwned
           ELSE TRUE

NoCompletionWithoutTypedLedgerAndServiceBudget ==
    completionRunning =>
        /\ serviceBudget
        /\ submitClass = ledgerClass
        /\ ledgerClass \in SubmitClasses
        /\ ~ambientCompletion

NoRepresentorForwardWithoutDerivation ==
    representorForwarded =>
        /\ reprCap
        /\ lowerQueueLease

NoQueueControlWithoutQueueControlCap ==
    controlChanged =>
        /\ queueControlCap
        /\ ~runCapOnly

NoServiceWorkAsCallerEffect ==
    serviceWorkRan =>
        /\ serviceAuthority
        /\ ~serviceChargedToLast
        /\ ~callerEffectFromService

NoDeliveryAfterRevoke ==
    delivered =>
        /\ ~revoked
        /\ ~staleDelivery

NoOutstandingAfterRevoke ==
    revoked =>
        /\ ~submitted
        /\ ~inFlight
        /\ ~completionPending
        /\ ~completionRunning
        /\ ~descriptorPublished
        /\ ~doorbellRung
        /\ submitClass = "None"
        /\ ledgerClass = "None"

=============================================================================
