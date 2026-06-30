-------------------- MODULE VfEpochHandoff --------------------

CONSTANTS
    ALLOW_UNSAFE_VF_ID_REUSE,
    ALLOW_UNSAFE_VSI_REUSE,
    ALLOW_UNSAFE_QUEUE_REASSIGN_STALE_DMA,
    ALLOW_UNSAFE_IRQ_REASSIGN_STALE_ROUTE,
    ALLOW_UNSAFE_FDIR_CONTEXT_SURVIVES,
    ALLOW_UNSAFE_MAILBOX_AFTER_RESET,
    ALLOW_UNSAFE_ALLOWLIST_SURVIVES,
    ALLOW_UNSAFE_SERVICE_REPLAY_OLD_EPOCH

VARIABLE state

vars == <<state>>

Phases == {
    "OldActive",
    "Resetting",
    "QueuesQuiesced",
    "RoutesRevoked",
    "AsyncCleared",
    "EpochBumped",
    "NewBound",
    "Reopened",
    "NewEffect",
    "BadVfIdReuse",
    "BadVsiReuse",
    "BadQueueReassignStaleDma",
    "BadIrqReassignStaleRoute",
    "BadFdirContextSurvives",
    "BadMailboxAfterReset",
    "BadAllowlistSurvives",
    "BadServiceReplayOldEpoch"
}

StateFields == {
    "phase",
    "oldDomainLive",
    "newDomainLive",
    "vfIdSame",
    "oldVfEpoch",
    "newVfEpoch",
    "domainBindingFresh",
    "resetStarted",
    "mailboxEmbargo",
    "mailboxOpen",
    "mailboxAccepted",
    "vsiOldGeneration",
    "vsiNewGeneration",
    "queueOldLease",
    "queueNewLease",
    "queueQuiesced",
    "dmaOldLive",
    "dmaRevoked",
    "irqOldLive",
    "irqRevoked",
    "fdirPending",
    "fdirCleared",
    "fdirCompletedNew",
    "allowlistOld",
    "allowlistReset",
    "serviceReplayFresh",
    "replayEffect",
    "effectNewDomain",
    "badVfIdReuse",
    "badVsiReuse",
    "badQueueReassignStaleDma",
    "badIrqReassignStaleRoute",
    "badFdirContextSurvives",
    "badMailboxAfterReset",
    "badAllowlistSurvives",
    "badServiceReplayOldEpoch"
}

BoolFields == StateFields \ {"phase"}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "OldActive",
        oldDomainLive |-> TRUE,
        newDomainLive |-> FALSE,
        vfIdSame |-> TRUE,
        oldVfEpoch |-> TRUE,
        newVfEpoch |-> FALSE,
        domainBindingFresh |-> FALSE,
        resetStarted |-> FALSE,
        mailboxEmbargo |-> FALSE,
        mailboxOpen |-> TRUE,
        mailboxAccepted |-> FALSE,
        vsiOldGeneration |-> TRUE,
        vsiNewGeneration |-> FALSE,
        queueOldLease |-> TRUE,
        queueNewLease |-> FALSE,
        queueQuiesced |-> FALSE,
        dmaOldLive |-> TRUE,
        dmaRevoked |-> FALSE,
        irqOldLive |-> TRUE,
        irqRevoked |-> FALSE,
        fdirPending |-> TRUE,
        fdirCleared |-> FALSE,
        fdirCompletedNew |-> FALSE,
        allowlistOld |-> TRUE,
        allowlistReset |-> FALSE,
        serviceReplayFresh |-> FALSE,
        replayEffect |-> FALSE,
        effectNewDomain |-> FALSE,
        badVfIdReuse |-> FALSE,
        badVsiReuse |-> FALSE,
        badQueueReassignStaleDma |-> FALSE,
        badIrqReassignStaleRoute |-> FALSE,
        badFdirContextSurvives |-> FALSE,
        badMailboxAfterReset |-> FALSE,
        badAllowlistSurvives |-> FALSE,
        badServiceReplayOldEpoch |-> FALSE
        ]

StartReset ==
    /\ state.phase = "OldActive"
    /\ state.oldDomainLive
    /\ state.mailboxOpen
    /\ state' =
        [state EXCEPT
            !.phase = "Resetting",
            !.oldDomainLive = FALSE,
            !.resetStarted = TRUE,
            !.mailboxEmbargo = TRUE,
            !.mailboxOpen = FALSE
        ]

QuiesceQueues ==
    /\ state.phase = "Resetting"
    /\ state.resetStarted
    /\ state' =
        [state EXCEPT
            !.phase = "QueuesQuiesced",
            !.queueOldLease = FALSE,
            !.queueQuiesced = TRUE
        ]

RevokeRoutes ==
    /\ state.phase = "QueuesQuiesced"
    /\ state.queueQuiesced
    /\ state' =
        [state EXCEPT
            !.phase = "RoutesRevoked",
            !.dmaOldLive = FALSE,
            !.dmaRevoked = TRUE,
            !.irqOldLive = FALSE,
            !.irqRevoked = TRUE
        ]

ClearAsyncAndAllowlist ==
    /\ state.phase = "RoutesRevoked"
    /\ state.dmaRevoked
    /\ state.irqRevoked
    /\ state' =
        [state EXCEPT
            !.phase = "AsyncCleared",
            !.fdirPending = FALSE,
            !.fdirCleared = TRUE,
            !.allowlistOld = FALSE,
            !.allowlistReset = TRUE
        ]

BumpEpoch ==
    /\ state.phase = "AsyncCleared"
    /\ state.fdirCleared
    /\ state.allowlistReset
    /\ state' =
        [state EXCEPT
            !.phase = "EpochBumped",
            !.oldVfEpoch = FALSE,
            !.newVfEpoch = TRUE,
            !.domainBindingFresh = TRUE,
            !.vsiOldGeneration = FALSE,
            !.vsiNewGeneration = TRUE,
            !.queueNewLease = TRUE
        ]

BindNewDomain ==
    /\ state.phase = "EpochBumped"
    /\ state.newVfEpoch
    /\ state.domainBindingFresh
    /\ state.vsiNewGeneration
    /\ state.queueNewLease
    /\ state' =
        [state EXCEPT
            !.phase = "NewBound",
            !.newDomainLive = TRUE,
            !.serviceReplayFresh = TRUE
        ]

ReopenMailbox ==
    /\ state.phase = "NewBound"
    /\ state.newDomainLive
    /\ state.serviceReplayFresh
    /\ state' =
        [state EXCEPT
            !.phase = "Reopened",
            !.mailboxEmbargo = FALSE,
            !.mailboxOpen = TRUE
        ]

ProduceNewEffect ==
    /\ state.phase = "Reopened"
    /\ state.newDomainLive
    /\ state.newVfEpoch
    /\ state.domainBindingFresh
    /\ state.vsiNewGeneration
    /\ state.queueNewLease
    /\ state.queueQuiesced
    /\ state.dmaRevoked
    /\ state.irqRevoked
    /\ state.fdirCleared
    /\ ~state.fdirPending
    /\ state.allowlistReset
    /\ ~state.allowlistOld
    /\ state.serviceReplayFresh
    /\ state.mailboxOpen
    /\ ~state.mailboxEmbargo
    /\ state' =
        [state EXCEPT
            !.phase = "NewEffect",
            !.effectNewDomain = TRUE
        ]

UnsafeVfIdReuse ==
    /\ ALLOW_UNSAFE_VF_ID_REUSE
    /\ state.phase = "Resetting"
    /\ state.vfIdSame
    /\ state.oldVfEpoch
    /\ state' =
        [state EXCEPT
            !.phase = "BadVfIdReuse",
            !.newDomainLive = TRUE,
            !.effectNewDomain = TRUE,
            !.badVfIdReuse = TRUE
        ]

UnsafeVsiReuse ==
    /\ ALLOW_UNSAFE_VSI_REUSE
    /\ state.phase \in {"RoutesRevoked", "AsyncCleared"}
    /\ state.vsiOldGeneration
    /\ ~state.vsiNewGeneration
    /\ state' =
        [state EXCEPT
            !.phase = "BadVsiReuse",
            !.newDomainLive = TRUE,
            !.newVfEpoch = TRUE,
            !.oldVfEpoch = FALSE,
            !.domainBindingFresh = TRUE,
            !.effectNewDomain = TRUE,
            !.badVsiReuse = TRUE
        ]

UnsafeQueueReassignStaleDma ==
    /\ ALLOW_UNSAFE_QUEUE_REASSIGN_STALE_DMA
    /\ state.phase = "QueuesQuiesced"
    /\ state.dmaOldLive
    /\ ~state.dmaRevoked
    /\ state' =
        [state EXCEPT
            !.phase = "BadQueueReassignStaleDma",
            !.newDomainLive = TRUE,
            !.newVfEpoch = TRUE,
            !.oldVfEpoch = FALSE,
            !.domainBindingFresh = TRUE,
            !.vsiOldGeneration = FALSE,
            !.vsiNewGeneration = TRUE,
            !.queueNewLease = TRUE,
            !.effectNewDomain = TRUE,
            !.badQueueReassignStaleDma = TRUE
        ]

UnsafeIrqReassignStaleRoute ==
    /\ ALLOW_UNSAFE_IRQ_REASSIGN_STALE_ROUTE
    /\ state.phase = "QueuesQuiesced"
    /\ state.irqOldLive
    /\ ~state.irqRevoked
    /\ state' =
        [state EXCEPT
            !.phase = "BadIrqReassignStaleRoute",
            !.newDomainLive = TRUE,
            !.newVfEpoch = TRUE,
            !.oldVfEpoch = FALSE,
            !.domainBindingFresh = TRUE,
            !.vsiOldGeneration = FALSE,
            !.vsiNewGeneration = TRUE,
            !.queueNewLease = TRUE,
            !.dmaOldLive = FALSE,
            !.dmaRevoked = TRUE,
            !.effectNewDomain = TRUE,
            !.badIrqReassignStaleRoute = TRUE
        ]

UnsafeFdirContextSurvives ==
    /\ ALLOW_UNSAFE_FDIR_CONTEXT_SURVIVES
    /\ state.phase = "RoutesRevoked"
    /\ state.fdirPending
    /\ ~state.fdirCleared
    /\ state' =
        [state EXCEPT
            !.phase = "BadFdirContextSurvives",
            !.oldVfEpoch = FALSE,
            !.newVfEpoch = TRUE,
            !.domainBindingFresh = TRUE,
            !.vsiOldGeneration = FALSE,
            !.vsiNewGeneration = TRUE,
            !.queueNewLease = TRUE,
            !.newDomainLive = TRUE,
            !.fdirCompletedNew = TRUE,
            !.effectNewDomain = TRUE,
            !.badFdirContextSurvives = TRUE
        ]

UnsafeMailboxAfterReset ==
    /\ ALLOW_UNSAFE_MAILBOX_AFTER_RESET
    /\ state.phase = "Resetting"
    /\ state.resetStarted
    /\ state.mailboxEmbargo
    /\ state' =
        [state EXCEPT
            !.phase = "BadMailboxAfterReset",
            !.mailboxAccepted = TRUE,
            !.badMailboxAfterReset = TRUE
        ]

UnsafeAllowlistSurvives ==
    /\ ALLOW_UNSAFE_ALLOWLIST_SURVIVES
    /\ state.phase = "RoutesRevoked"
    /\ state.allowlistOld
    /\ ~state.allowlistReset
    /\ state' =
        [state EXCEPT
            !.phase = "BadAllowlistSurvives",
            !.oldVfEpoch = FALSE,
            !.newVfEpoch = TRUE,
            !.domainBindingFresh = TRUE,
            !.vsiOldGeneration = FALSE,
            !.vsiNewGeneration = TRUE,
            !.queueNewLease = TRUE,
            !.newDomainLive = TRUE,
            !.fdirPending = FALSE,
            !.fdirCleared = TRUE,
            !.effectNewDomain = TRUE,
            !.badAllowlistSurvives = TRUE
        ]

UnsafeServiceReplayOldEpoch ==
    /\ ALLOW_UNSAFE_SERVICE_REPLAY_OLD_EPOCH
    /\ state.phase = "Resetting"
    /\ ~state.serviceReplayFresh
    /\ state.oldVfEpoch
    /\ state' =
        [state EXCEPT
            !.phase = "BadServiceReplayOldEpoch",
            !.replayEffect = TRUE,
            !.badServiceReplayOldEpoch = TRUE
        ]

Next ==
    \/ StartReset
    \/ QuiesceQueues
    \/ RevokeRoutes
    \/ ClearAsyncAndAllowlist
    \/ BumpEpoch
    \/ BindNewDomain
    \/ ReopenMailbox
    \/ ProduceNewEffect
    \/ UnsafeVfIdReuse
    \/ UnsafeVsiReuse
    \/ UnsafeQueueReassignStaleDma
    \/ UnsafeIrqReassignStaleRoute
    \/ UnsafeFdirContextSurvives
    \/ UnsafeMailboxAfterReset
    \/ UnsafeAllowlistSurvives
    \/ UnsafeServiceReplayOldEpoch

Spec ==
    Init /\ [][Next]_vars

NoNewDomainEffectFromOldVfEpoch ==
    state.effectNewDomain =>
        /\ state.newVfEpoch
        /\ ~state.oldVfEpoch
        /\ state.domainBindingFresh

NoVsiReuseWithoutGeneration ==
    state.effectNewDomain =>
        /\ state.vsiNewGeneration
        /\ ~state.vsiOldGeneration

NoQueueReassignBeforeDmaIrqRevoke ==
    state.effectNewDomain =>
        /\ state.queueQuiesced
        /\ state.dmaRevoked
        /\ ~state.dmaOldLive
        /\ state.irqRevoked
        /\ ~state.irqOldLive

NoFdirCompletionAfterEpochChange ==
    state.fdirCompletedNew =>
        /\ state.newVfEpoch
        /\ state.fdirCleared
        /\ ~state.fdirPending

NoMailboxAcceptedDuringResetOrOldEpoch ==
    state.mailboxAccepted =>
        /\ state.newVfEpoch
        /\ state.domainBindingFresh
        /\ ~state.mailboxEmbargo
        /\ state.mailboxOpen

NoAllowlistSurvivalAcrossReset ==
    state.effectNewDomain =>
        /\ state.allowlistReset
        /\ ~state.allowlistOld

NoServiceReplayWithoutFreshAuth ==
    state.replayEffect =>
        /\ state.serviceReplayFresh
        /\ state.newVfEpoch
        /\ state.domainBindingFresh

NoBadVfIdReuse ==
    ~state.badVfIdReuse

NoBadVsiReuse ==
    ~state.badVsiReuse

NoBadQueueReassignStaleDma ==
    ~state.badQueueReassignStaleDma

NoBadIrqReassignStaleRoute ==
    ~state.badIrqReassignStaleRoute

NoBadFdirContextSurvives ==
    ~state.badFdirContextSurvives

NoBadMailboxAfterReset ==
    ~state.badMailboxAfterReset

NoBadAllowlistSurvives ==
    ~state.badAllowlistSurvives

NoBadServiceReplayOldEpoch ==
    ~state.badServiceReplayOldEpoch

=============================================================================
