-------------------- MODULE ModernNicServiceWork --------------------
EXTENDS Naturals

CONSTANTS
    ALLOW_UNSAFE_SERVICE_AMBIENT_QUEUE_EFFECT,
    ALLOW_UNSAFE_VF_MAILBOX_WITHOUT_CARRIER,
    ALLOW_UNSAFE_LAST_CALLER_MERGE,
    ALLOW_UNSAFE_PTP_WORK_WITHOUT_CONTROL,
    ALLOW_UNSAFE_DPLL_WORK_WITHOUT_CONTROL,
    ALLOW_UNSAFE_BRIDGE_OFFLOAD_WITHOUT_AUTH,
    ALLOW_UNSAFE_LAG_REBIND_WITHOUT_LOWER_LEASE,
    ALLOW_UNSAFE_RESET_REPLAY_AFTER_REVOKE

VARIABLES
    phase,
    serviceEpochLive,
    serviceBudget,
    serviceLoopQueued,
    callerCarrier,
    callerEpochLive,
    queueLeaseLive,
    queueEpochFresh,
    controlCap,
    offloadCap,
    policyGenerationFresh,
    lowerBindingFresh,
    freshReplayAuth,
    revoked,
    queueEffect,
    controlEffect,
    offloadEffect,
    maintenanceEffect,
    resetReplay,
    multiCallerPending,
    lastCallerChosen,
    badServiceAmbient,
    badVfNoCarrier,
    badLastCallerMerge,
    badPtpNoControl,
    badDpllNoControl,
    badBridgeNoOffload,
    badLagNoLowerLease,
    badResetReplay

vars == <<phase, serviceEpochLive, serviceBudget, serviceLoopQueued,
          callerCarrier, callerEpochLive, queueLeaseLive, queueEpochFresh,
          controlCap, offloadCap, policyGenerationFresh, lowerBindingFresh,
          freshReplayAuth, revoked, queueEffect, controlEffect, offloadEffect,
          maintenanceEffect, resetReplay, multiCallerPending,
          lastCallerChosen, badServiceAmbient, badVfNoCarrier,
          badLastCallerMerge, badPtpNoControl, badDpllNoControl,
          badBridgeNoOffload, badLagNoLowerLease, badResetReplay>>

Phases == {
    "Start",
    "ServiceReady",
    "MergedQueued",
    "MaintenanceRan",
    "VfCarrierPrepared",
    "VfQueueConfigured",
    "PtpCarrierPrepared",
    "PtpControlApplied",
    "DpllCarrierPrepared",
    "DpllControlApplied",
    "PolicyEventPrepared",
    "OffloadApplied",
    "LagInvalidated",
    "LagRebound",
    "Revoked",
    "Replayed",
    "BadServiceAmbient",
    "BadVfNoCarrier",
    "BadLastCallerMerge",
    "BadPtpNoControl",
    "BadDpllNoControl",
    "BadBridgeNoOffload",
    "BadLagNoLowerLease",
    "BadResetReplay"
}

TypeOK ==
    /\ phase \in Phases
    /\ serviceEpochLive \in BOOLEAN
    /\ serviceBudget \in BOOLEAN
    /\ serviceLoopQueued \in BOOLEAN
    /\ callerCarrier \in BOOLEAN
    /\ callerEpochLive \in BOOLEAN
    /\ queueLeaseLive \in BOOLEAN
    /\ queueEpochFresh \in BOOLEAN
    /\ controlCap \in BOOLEAN
    /\ offloadCap \in BOOLEAN
    /\ policyGenerationFresh \in BOOLEAN
    /\ lowerBindingFresh \in BOOLEAN
    /\ freshReplayAuth \in BOOLEAN
    /\ revoked \in BOOLEAN
    /\ queueEffect \in BOOLEAN
    /\ controlEffect \in BOOLEAN
    /\ offloadEffect \in BOOLEAN
    /\ maintenanceEffect \in BOOLEAN
    /\ resetReplay \in BOOLEAN
    /\ multiCallerPending \in BOOLEAN
    /\ lastCallerChosen \in BOOLEAN
    /\ badServiceAmbient \in BOOLEAN
    /\ badVfNoCarrier \in BOOLEAN
    /\ badLastCallerMerge \in BOOLEAN
    /\ badPtpNoControl \in BOOLEAN
    /\ badDpllNoControl \in BOOLEAN
    /\ badBridgeNoOffload \in BOOLEAN
    /\ badLagNoLowerLease \in BOOLEAN
    /\ badResetReplay \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ serviceEpochLive = FALSE
    /\ serviceBudget = FALSE
    /\ serviceLoopQueued = FALSE
    /\ callerCarrier = FALSE
    /\ callerEpochLive = FALSE
    /\ queueLeaseLive = FALSE
    /\ queueEpochFresh = FALSE
    /\ controlCap = FALSE
    /\ offloadCap = FALSE
    /\ policyGenerationFresh = FALSE
    /\ lowerBindingFresh = FALSE
    /\ freshReplayAuth = FALSE
    /\ revoked = FALSE
    /\ queueEffect = FALSE
    /\ controlEffect = FALSE
    /\ offloadEffect = FALSE
    /\ maintenanceEffect = FALSE
    /\ resetReplay = FALSE
    /\ multiCallerPending = FALSE
    /\ lastCallerChosen = FALSE
    /\ badServiceAmbient = FALSE
    /\ badVfNoCarrier = FALSE
    /\ badLastCallerMerge = FALSE
    /\ badPtpNoControl = FALSE
    /\ badDpllNoControl = FALSE
    /\ badBridgeNoOffload = FALSE
    /\ badLagNoLowerLease = FALSE
    /\ badResetReplay = FALSE

PrepareService ==
    /\ phase = "Start"
    /\ phase' = "ServiceReady"
    /\ serviceEpochLive' = TRUE
    /\ serviceBudget' = TRUE
    /\ UNCHANGED <<serviceLoopQueued, callerCarrier, callerEpochLive,
                    queueLeaseLive, queueEpochFresh, controlCap, offloadCap,
                    policyGenerationFresh, lowerBindingFresh, freshReplayAuth,
                    revoked, queueEffect, controlEffect, offloadEffect,
                    maintenanceEffect, resetReplay, multiCallerPending,
                    lastCallerChosen, badServiceAmbient, badVfNoCarrier,
                    badLastCallerMerge, badPtpNoControl, badDpllNoControl,
                    badBridgeNoOffload, badLagNoLowerLease, badResetReplay>>

QueueMergedServiceLoop ==
    /\ phase = "ServiceReady"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ phase' = "MergedQueued"
    /\ serviceLoopQueued' = TRUE
    /\ multiCallerPending' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, callerCarrier,
                    callerEpochLive, queueLeaseLive, queueEpochFresh,
                    controlCap, offloadCap, policyGenerationFresh,
                    lowerBindingFresh, freshReplayAuth, revoked, queueEffect,
                    controlEffect, offloadEffect, maintenanceEffect,
                    resetReplay, lastCallerChosen, badServiceAmbient,
                    badVfNoCarrier, badLastCallerMerge, badPtpNoControl,
                    badDpllNoControl, badBridgeNoOffload, badLagNoLowerLease,
                    badResetReplay>>

RunServiceMaintenance ==
    /\ phase = "MergedQueued"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ phase' = "MaintenanceRan"
    /\ maintenanceEffect' = TRUE
    /\ serviceLoopQueued' = FALSE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, callerCarrier,
                    callerEpochLive, queueLeaseLive, queueEpochFresh,
                    controlCap, offloadCap, policyGenerationFresh,
                    lowerBindingFresh, freshReplayAuth, revoked, queueEffect,
                    controlEffect, offloadEffect, resetReplay,
                    multiCallerPending, lastCallerChosen, badServiceAmbient,
                    badVfNoCarrier, badLastCallerMerge, badPtpNoControl,
                    badDpllNoControl, badBridgeNoOffload, badLagNoLowerLease,
                    badResetReplay>>

PrepareVfMailboxCarrier ==
    /\ phase = "MergedQueued"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ phase' = "VfCarrierPrepared"
    /\ callerCarrier' = TRUE
    /\ callerEpochLive' = TRUE
    /\ queueLeaseLive' = TRUE
    /\ queueEpochFresh' = TRUE
    /\ controlCap' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    offloadCap, policyGenerationFresh, lowerBindingFresh,
                    freshReplayAuth, revoked, queueEffect, controlEffect,
                    offloadEffect, maintenanceEffect, resetReplay,
                    multiCallerPending, lastCallerChosen, badServiceAmbient,
                    badVfNoCarrier, badLastCallerMerge, badPtpNoControl,
                    badDpllNoControl, badBridgeNoOffload, badLagNoLowerLease,
                    badResetReplay>>

RunVfQueueControl ==
    /\ phase = "VfCarrierPrepared"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ callerCarrier
    /\ callerEpochLive
    /\ queueLeaseLive
    /\ queueEpochFresh
    /\ controlCap
    /\ phase' = "VfQueueConfigured"
    /\ queueEffect' = TRUE
    /\ controlEffect' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    callerCarrier, callerEpochLive, queueLeaseLive,
                    queueEpochFresh, controlCap, offloadCap,
                    policyGenerationFresh, lowerBindingFresh, freshReplayAuth,
                    revoked, offloadEffect, maintenanceEffect, resetReplay,
                    multiCallerPending, lastCallerChosen, badServiceAmbient,
                    badVfNoCarrier, badLastCallerMerge, badPtpNoControl,
                    badDpllNoControl, badBridgeNoOffload, badLagNoLowerLease,
                    badResetReplay>>

PreparePtpControlCarrier ==
    /\ phase = "ServiceReady"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ phase' = "PtpCarrierPrepared"
    /\ callerCarrier' = TRUE
    /\ callerEpochLive' = TRUE
    /\ controlCap' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    queueLeaseLive, queueEpochFresh, offloadCap,
                    policyGenerationFresh, lowerBindingFresh, freshReplayAuth,
                    revoked, queueEffect, controlEffect, offloadEffect,
                    maintenanceEffect, resetReplay, multiCallerPending,
                    lastCallerChosen, badServiceAmbient, badVfNoCarrier,
                    badLastCallerMerge, badPtpNoControl, badDpllNoControl,
                    badBridgeNoOffload, badLagNoLowerLease, badResetReplay>>

RunPtpControl ==
    /\ phase = "PtpCarrierPrepared"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ callerCarrier
    /\ callerEpochLive
    /\ controlCap
    /\ phase' = "PtpControlApplied"
    /\ controlEffect' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    callerCarrier, callerEpochLive, queueLeaseLive,
                    queueEpochFresh, controlCap, offloadCap,
                    policyGenerationFresh, lowerBindingFresh, freshReplayAuth,
                    revoked, queueEffect, offloadEffect, maintenanceEffect,
                    resetReplay, multiCallerPending, lastCallerChosen,
                    badServiceAmbient, badVfNoCarrier, badLastCallerMerge,
                    badPtpNoControl, badDpllNoControl, badBridgeNoOffload,
                    badLagNoLowerLease, badResetReplay>>

PrepareDpllControlCarrier ==
    /\ phase = "ServiceReady"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ phase' = "DpllCarrierPrepared"
    /\ callerCarrier' = TRUE
    /\ callerEpochLive' = TRUE
    /\ controlCap' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    queueLeaseLive, queueEpochFresh, offloadCap,
                    policyGenerationFresh, lowerBindingFresh, freshReplayAuth,
                    revoked, queueEffect, controlEffect, offloadEffect,
                    maintenanceEffect, resetReplay, multiCallerPending,
                    lastCallerChosen, badServiceAmbient, badVfNoCarrier,
                    badLastCallerMerge, badPtpNoControl, badDpllNoControl,
                    badBridgeNoOffload, badLagNoLowerLease, badResetReplay>>

RunDpllControl ==
    /\ phase = "DpllCarrierPrepared"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ callerCarrier
    /\ callerEpochLive
    /\ controlCap
    /\ phase' = "DpllControlApplied"
    /\ controlEffect' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    callerCarrier, callerEpochLive, queueLeaseLive,
                    queueEpochFresh, controlCap, offloadCap,
                    policyGenerationFresh, lowerBindingFresh, freshReplayAuth,
                    revoked, queueEffect, offloadEffect, maintenanceEffect,
                    resetReplay, multiCallerPending, lastCallerChosen,
                    badServiceAmbient, badVfNoCarrier, badLastCallerMerge,
                    badPtpNoControl, badDpllNoControl, badBridgeNoOffload,
                    badLagNoLowerLease, badResetReplay>>

PrepareBridgePolicyEvent ==
    /\ phase = "ServiceReady"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ phase' = "PolicyEventPrepared"
    /\ policyGenerationFresh' = TRUE
    /\ offloadCap' = TRUE
    /\ queueLeaseLive' = TRUE
    /\ queueEpochFresh' = TRUE
    /\ lowerBindingFresh' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    callerCarrier, callerEpochLive, controlCap,
                    freshReplayAuth, revoked, queueEffect, controlEffect,
                    offloadEffect, maintenanceEffect, resetReplay,
                    multiCallerPending, lastCallerChosen, badServiceAmbient,
                    badVfNoCarrier, badLastCallerMerge, badPtpNoControl,
                    badDpllNoControl, badBridgeNoOffload, badLagNoLowerLease,
                    badResetReplay>>

ApplyBridgeOffload ==
    /\ phase = "PolicyEventPrepared"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ policyGenerationFresh
    /\ offloadCap
    /\ queueLeaseLive
    /\ queueEpochFresh
    /\ lowerBindingFresh
    /\ phase' = "OffloadApplied"
    /\ offloadEffect' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    callerCarrier, callerEpochLive, queueLeaseLive,
                    queueEpochFresh, controlCap, offloadCap,
                    policyGenerationFresh, lowerBindingFresh, freshReplayAuth,
                    revoked, queueEffect, controlEffect, maintenanceEffect,
                    resetReplay, multiCallerPending, lastCallerChosen,
                    badServiceAmbient, badVfNoCarrier, badLastCallerMerge,
                    badPtpNoControl, badDpllNoControl, badBridgeNoOffload,
                    badLagNoLowerLease, badResetReplay>>

LagLowerDevInvalidatesBinding ==
    /\ phase = "PolicyEventPrepared"
    /\ phase' = "LagInvalidated"
    /\ lowerBindingFresh' = FALSE
    /\ queueEpochFresh' = FALSE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    callerCarrier, callerEpochLive, queueLeaseLive, controlCap,
                    offloadCap, policyGenerationFresh, freshReplayAuth,
                    revoked, queueEffect, controlEffect, offloadEffect,
                    maintenanceEffect, resetReplay, multiCallerPending,
                    lastCallerChosen, badServiceAmbient, badVfNoCarrier,
                    badLastCallerMerge, badPtpNoControl, badDpllNoControl,
                    badBridgeNoOffload, badLagNoLowerLease, badResetReplay>>

RebindLagWithFreshLowerLease ==
    /\ phase = "LagInvalidated"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ queueLeaseLive
    /\ offloadCap
    /\ policyGenerationFresh
    /\ phase' = "LagRebound"
    /\ lowerBindingFresh' = TRUE
    /\ queueEpochFresh' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    callerCarrier, callerEpochLive, queueLeaseLive, controlCap,
                    offloadCap, policyGenerationFresh, freshReplayAuth,
                    revoked, queueEffect, controlEffect, offloadEffect,
                    maintenanceEffect, resetReplay, multiCallerPending,
                    lastCallerChosen, badServiceAmbient, badVfNoCarrier,
                    badLastCallerMerge, badPtpNoControl, badDpllNoControl,
                    badBridgeNoOffload, badLagNoLowerLease, badResetReplay>>

Revoke ==
    /\ phase \in {"ServiceReady", "MergedQueued", "VfCarrierPrepared",
                  "VfQueueConfigured", "PtpCarrierPrepared",
                  "PtpControlApplied", "DpllCarrierPrepared",
                  "DpllControlApplied", "PolicyEventPrepared",
                  "OffloadApplied", "LagInvalidated", "LagRebound",
                  "MaintenanceRan"}
    /\ phase' = "Revoked"
    /\ revoked' = TRUE
    /\ callerCarrier' = FALSE
    /\ callerEpochLive' = FALSE
    /\ queueLeaseLive' = FALSE
    /\ queueEpochFresh' = FALSE
    /\ controlCap' = FALSE
    /\ offloadCap' = FALSE
    /\ policyGenerationFresh' = FALSE
    /\ lowerBindingFresh' = FALSE
    /\ serviceLoopQueued' = FALSE
    /\ queueEffect' = FALSE
    /\ controlEffect' = FALSE
    /\ offloadEffect' = FALSE
    /\ maintenanceEffect' = FALSE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, freshReplayAuth,
                    resetReplay, multiCallerPending, lastCallerChosen,
                    badServiceAmbient, badVfNoCarrier, badLastCallerMerge,
                    badPtpNoControl, badDpllNoControl, badBridgeNoOffload,
                    badLagNoLowerLease, badResetReplay>>

FreshReauthorizeAfterRevoke ==
    /\ phase = "Revoked"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ phase' = "Replayed"
    /\ freshReplayAuth' = TRUE
    /\ queueLeaseLive' = TRUE
    /\ queueEpochFresh' = TRUE
    /\ resetReplay' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    callerCarrier, callerEpochLive, controlCap, offloadCap,
                    policyGenerationFresh, lowerBindingFresh, revoked,
                    queueEffect, controlEffect, offloadEffect,
                    maintenanceEffect, multiCallerPending, lastCallerChosen,
                    badServiceAmbient, badVfNoCarrier, badLastCallerMerge,
                    badPtpNoControl, badDpllNoControl, badBridgeNoOffload,
                    badLagNoLowerLease, badResetReplay>>

UnsafeServiceAmbientQueueEffect ==
    /\ ALLOW_UNSAFE_SERVICE_AMBIENT_QUEUE_EFFECT
    /\ phase = "MergedQueued"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ phase' = "BadServiceAmbient"
    /\ queueEffect' = TRUE
    /\ badServiceAmbient' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    callerCarrier, callerEpochLive, queueLeaseLive,
                    queueEpochFresh, controlCap, offloadCap,
                    policyGenerationFresh, lowerBindingFresh, freshReplayAuth,
                    revoked, controlEffect, offloadEffect, maintenanceEffect,
                    resetReplay, multiCallerPending, lastCallerChosen,
                    badVfNoCarrier, badLastCallerMerge, badPtpNoControl,
                    badDpllNoControl, badBridgeNoOffload, badLagNoLowerLease,
                    badResetReplay>>

UnsafeVfMailboxWithoutCarrier ==
    /\ ALLOW_UNSAFE_VF_MAILBOX_WITHOUT_CARRIER
    /\ phase = "MergedQueued"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ phase' = "BadVfNoCarrier"
    /\ queueEffect' = TRUE
    /\ controlEffect' = TRUE
    /\ badVfNoCarrier' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    callerCarrier, callerEpochLive, queueLeaseLive,
                    queueEpochFresh, controlCap, offloadCap,
                    policyGenerationFresh, lowerBindingFresh, freshReplayAuth,
                    revoked, offloadEffect, maintenanceEffect, resetReplay,
                    multiCallerPending, lastCallerChosen, badServiceAmbient,
                    badLastCallerMerge, badPtpNoControl, badDpllNoControl,
                    badBridgeNoOffload, badLagNoLowerLease, badResetReplay>>

UnsafeLastCallerMerge ==
    /\ ALLOW_UNSAFE_LAST_CALLER_MERGE
    /\ phase = "MergedQueued"
    /\ multiCallerPending
    /\ phase' = "BadLastCallerMerge"
    /\ lastCallerChosen' = TRUE
    /\ queueEffect' = TRUE
    /\ callerCarrier' = TRUE
    /\ callerEpochLive' = TRUE
    /\ queueLeaseLive' = TRUE
    /\ queueEpochFresh' = TRUE
    /\ badLastCallerMerge' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    controlCap, offloadCap, policyGenerationFresh,
                    lowerBindingFresh, freshReplayAuth, revoked,
                    controlEffect, offloadEffect, maintenanceEffect,
                    resetReplay, multiCallerPending, badServiceAmbient,
                    badVfNoCarrier, badPtpNoControl, badDpllNoControl,
                    badBridgeNoOffload, badLagNoLowerLease, badResetReplay>>

UnsafePtpWorkWithoutControl ==
    /\ ALLOW_UNSAFE_PTP_WORK_WITHOUT_CONTROL
    /\ phase = "ServiceReady"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ phase' = "BadPtpNoControl"
    /\ controlEffect' = TRUE
    /\ badPtpNoControl' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    callerCarrier, callerEpochLive, queueLeaseLive,
                    queueEpochFresh, controlCap, offloadCap,
                    policyGenerationFresh, lowerBindingFresh, freshReplayAuth,
                    revoked, queueEffect, offloadEffect, maintenanceEffect,
                    resetReplay, multiCallerPending, lastCallerChosen,
                    badServiceAmbient, badVfNoCarrier, badLastCallerMerge,
                    badDpllNoControl, badBridgeNoOffload, badLagNoLowerLease,
                    badResetReplay>>

UnsafeDpllWorkWithoutControl ==
    /\ ALLOW_UNSAFE_DPLL_WORK_WITHOUT_CONTROL
    /\ phase = "ServiceReady"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ phase' = "BadDpllNoControl"
    /\ controlEffect' = TRUE
    /\ badDpllNoControl' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    callerCarrier, callerEpochLive, queueLeaseLive,
                    queueEpochFresh, controlCap, offloadCap,
                    policyGenerationFresh, lowerBindingFresh, freshReplayAuth,
                    revoked, queueEffect, offloadEffect, maintenanceEffect,
                    resetReplay, multiCallerPending, lastCallerChosen,
                    badServiceAmbient, badVfNoCarrier, badLastCallerMerge,
                    badPtpNoControl, badBridgeNoOffload, badLagNoLowerLease,
                    badResetReplay>>

UnsafeBridgeOffloadWithoutAuth ==
    /\ ALLOW_UNSAFE_BRIDGE_OFFLOAD_WITHOUT_AUTH
    /\ phase = "ServiceReady"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ phase' = "BadBridgeNoOffload"
    /\ policyGenerationFresh' = TRUE
    /\ offloadEffect' = TRUE
    /\ badBridgeNoOffload' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    callerCarrier, callerEpochLive, queueLeaseLive,
                    queueEpochFresh, controlCap, offloadCap, lowerBindingFresh,
                    freshReplayAuth, revoked, queueEffect, controlEffect,
                    maintenanceEffect, resetReplay, multiCallerPending,
                    lastCallerChosen, badServiceAmbient, badVfNoCarrier,
                    badLastCallerMerge, badPtpNoControl, badDpllNoControl,
                    badLagNoLowerLease, badResetReplay>>

UnsafeLagRebindWithoutLowerLease ==
    /\ ALLOW_UNSAFE_LAG_REBIND_WITHOUT_LOWER_LEASE
    /\ phase = "LagInvalidated"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ phase' = "BadLagNoLowerLease"
    /\ lowerBindingFresh' = TRUE
    /\ badLagNoLowerLease' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    callerCarrier, callerEpochLive, queueLeaseLive,
                    queueEpochFresh, controlCap, offloadCap,
                    policyGenerationFresh, freshReplayAuth, revoked,
                    queueEffect, controlEffect, offloadEffect,
                    maintenanceEffect, resetReplay, multiCallerPending,
                    lastCallerChosen, badServiceAmbient, badVfNoCarrier,
                    badLastCallerMerge, badPtpNoControl, badDpllNoControl,
                    badBridgeNoOffload, badResetReplay>>

UnsafeResetReplayAfterRevoke ==
    /\ ALLOW_UNSAFE_RESET_REPLAY_AFTER_REVOKE
    /\ phase = "Revoked"
    /\ serviceEpochLive
    /\ serviceBudget
    /\ phase' = "BadResetReplay"
    /\ resetReplay' = TRUE
    /\ badResetReplay' = TRUE
    /\ UNCHANGED <<serviceEpochLive, serviceBudget, serviceLoopQueued,
                    callerCarrier, callerEpochLive, queueLeaseLive,
                    queueEpochFresh, controlCap, offloadCap,
                    policyGenerationFresh, lowerBindingFresh, freshReplayAuth,
                    revoked, queueEffect, controlEffect, offloadEffect,
                    maintenanceEffect, multiCallerPending, lastCallerChosen,
                    badServiceAmbient, badVfNoCarrier, badLastCallerMerge,
                    badPtpNoControl, badDpllNoControl, badBridgeNoOffload,
                    badLagNoLowerLease>>

Next ==
    \/ PrepareService
    \/ QueueMergedServiceLoop
    \/ RunServiceMaintenance
    \/ PrepareVfMailboxCarrier
    \/ RunVfQueueControl
    \/ PreparePtpControlCarrier
    \/ RunPtpControl
    \/ PrepareDpllControlCarrier
    \/ RunDpllControl
    \/ PrepareBridgePolicyEvent
    \/ ApplyBridgeOffload
    \/ LagLowerDevInvalidatesBinding
    \/ RebindLagWithFreshLowerLease
    \/ Revoke
    \/ FreshReauthorizeAfterRevoke
    \/ UnsafeServiceAmbientQueueEffect
    \/ UnsafeVfMailboxWithoutCarrier
    \/ UnsafeLastCallerMerge
    \/ UnsafePtpWorkWithoutControl
    \/ UnsafeDpllWorkWithoutControl
    \/ UnsafeBridgeOffloadWithoutAuth
    \/ UnsafeLagRebindWithoutLowerLease
    \/ UnsafeResetReplayAfterRevoke

Spec == Init /\ [][Next]_vars

NoQueueEffectWithoutServiceCallerQueueIntersection ==
    queueEffect =>
        /\ serviceEpochLive
        /\ serviceBudget
        /\ callerCarrier
        /\ callerEpochLive
        /\ queueLeaseLive
        /\ queueEpochFresh

NoControlEffectWithoutServiceCallerControlIntersection ==
    controlEffect =>
        /\ serviceEpochLive
        /\ serviceBudget
        /\ callerCarrier
        /\ callerEpochLive
        /\ controlCap

NoOffloadEffectWithoutPolicyOffloadLowerIntersection ==
    offloadEffect =>
        /\ serviceEpochLive
        /\ serviceBudget
        /\ policyGenerationFresh
        /\ offloadCap
        /\ queueLeaseLive
        /\ queueEpochFresh
        /\ lowerBindingFresh

NoResetReplayWithoutFreshReauthorization ==
    resetReplay =>
        /\ serviceEpochLive
        /\ serviceBudget
        /\ freshReplayAuth
        /\ queueLeaseLive
        /\ queueEpochFresh

NoServiceAmbientQueueEffect == ~badServiceAmbient
NoVfMailboxEffectWithoutCarrier == ~badVfNoCarrier
NoMergedLoopLastCallerAuthority == ~badLastCallerMerge
NoPtpControlWithoutCarrier == ~badPtpNoControl
NoDpllControlWithoutCarrier == ~badDpllNoControl
NoBridgeOffloadWithoutPolicyAndControl == ~badBridgeNoOffload
NoLagRebindWithoutFreshLowerLease == ~badLagNoLowerLease
NoResetReplayAfterRevokeWithoutFreshAuth == ~badResetReplay

====
