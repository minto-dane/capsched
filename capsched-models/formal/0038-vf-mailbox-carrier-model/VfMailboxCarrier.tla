-------------------- MODULE VfMailboxCarrier --------------------

CONSTANTS
    ALLOW_UNSAFE_VALIDATION_AS_QUEUE_AUTH,
    ALLOW_UNSAFE_DMA_WITHOUT_MEMORYVIEW,
    ALLOW_UNSAFE_ENABLE_WITHOUT_CONFIG,
    ALLOW_UNSAFE_IRQ_WITHOUT_ROUTE,
    ALLOW_UNSAFE_BUDGET_WITHOUT_AUTH,
    ALLOW_UNSAFE_FDIR_WITHOUT_OFFLOAD,
    ALLOW_UNSAFE_FDIR_COMPLETION_WITHOUT_CONTEXT,
    ALLOW_UNSAFE_EFFECT_AFTER_REVOKE

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "Validated",
    "RequestReady",
    "QueueConfigured",
    "IrqMapped",
    "BudgetProgrammed",
    "QueueEnabled",
    "FdirPending",
    "FdirDone",
    "Revoked",
    "BadValidationAsAuthority",
    "BadDmaNoMemoryView",
    "BadEnableNoConfig",
    "BadIrqNoRoute",
    "BadBudgetNoAuth",
    "BadFdirNoOffload",
    "BadFdirCompleteNoContext",
    "BadEffectAfterRevoke"
}

StateFields == {
    "phase",
    "serviceLive",
    "serviceBudget",
    "virtchnlValid",
    "opcodeAllowed",
    "vfCarrier",
    "vfEpochFresh",
    "requestFrozen",
    "queueLeaseLive",
    "queueEpochFresh",
    "queueControlCap",
    "dmaMemoryViewLive",
    "dmaReceipt",
    "queueConfigFrozen",
    "irqRouteLive",
    "irqEpochFresh",
    "queueBudgetCap",
    "offloadCap",
    "fdirContextFrozen",
    "fdirRuleFresh",
    "revoked",
    "dmaBaseProgrammed",
    "queueConfigured",
    "queueEnabled",
    "irqMapped",
    "budgetProgrammed",
    "fdirWritten",
    "fdirCompleted",
    "badValidationAsAuthority",
    "badDmaNoMemoryView",
    "badEnableNoConfig",
    "badIrqNoRoute",
    "badBudgetNoAuth",
    "badFdirNoOffload",
    "badFdirCompleteNoContext",
    "badEffectAfterRevoke"
}

BoolFields == StateFields \ {"phase"}

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        serviceLive |-> FALSE,
        serviceBudget |-> FALSE,
        virtchnlValid |-> FALSE,
        opcodeAllowed |-> FALSE,
        vfCarrier |-> FALSE,
        vfEpochFresh |-> FALSE,
        requestFrozen |-> FALSE,
        queueLeaseLive |-> FALSE,
        queueEpochFresh |-> FALSE,
        queueControlCap |-> FALSE,
        dmaMemoryViewLive |-> FALSE,
        dmaReceipt |-> FALSE,
        queueConfigFrozen |-> FALSE,
        irqRouteLive |-> FALSE,
        irqEpochFresh |-> FALSE,
        queueBudgetCap |-> FALSE,
        offloadCap |-> FALSE,
        fdirContextFrozen |-> FALSE,
        fdirRuleFresh |-> FALSE,
        revoked |-> FALSE,
        dmaBaseProgrammed |-> FALSE,
        queueConfigured |-> FALSE,
        queueEnabled |-> FALSE,
        irqMapped |-> FALSE,
        budgetProgrammed |-> FALSE,
        fdirWritten |-> FALSE,
        fdirCompleted |-> FALSE,
        badValidationAsAuthority |-> FALSE,
        badDmaNoMemoryView |-> FALSE,
        badEnableNoConfig |-> FALSE,
        badIrqNoRoute |-> FALSE,
        badBudgetNoAuth |-> FALSE,
        badFdirNoOffload |-> FALSE,
        badFdirCompleteNoContext |-> FALSE,
        badEffectAfterRevoke |-> FALSE
        ]

ReceiveValidVirtchnl ==
    /\ state.phase = "Start"
    /\ state' =
        [state EXCEPT
            !.phase = "Validated",
            !.serviceLive = TRUE,
            !.serviceBudget = TRUE,
            !.virtchnlValid = TRUE,
            !.opcodeAllowed = TRUE
        ]

PrepareVfRequestCarrier ==
    /\ state.phase = "Validated"
    /\ state.serviceLive
    /\ state.serviceBudget
    /\ state.virtchnlValid
    /\ state.opcodeAllowed
    /\ state' =
        [state EXCEPT
            !.phase = "RequestReady",
            !.vfCarrier = TRUE,
            !.vfEpochFresh = TRUE,
            !.requestFrozen = TRUE,
            !.queueLeaseLive = TRUE,
            !.queueEpochFresh = TRUE,
            !.queueControlCap = TRUE,
            !.dmaMemoryViewLive = TRUE,
            !.dmaReceipt = TRUE,
            !.irqRouteLive = TRUE,
            !.irqEpochFresh = TRUE,
            !.queueBudgetCap = TRUE,
            !.offloadCap = TRUE,
            !.fdirRuleFresh = TRUE
        ]

ConfigQueue ==
    /\ state.phase = "RequestReady"
    /\ state.serviceLive
    /\ state.serviceBudget
    /\ state.vfCarrier
    /\ state.vfEpochFresh
    /\ state.requestFrozen
    /\ state.queueLeaseLive
    /\ state.queueEpochFresh
    /\ state.queueControlCap
    /\ state.dmaMemoryViewLive
    /\ state.dmaReceipt
    /\ ~state.revoked
    /\ state' =
        [state EXCEPT
            !.phase = "QueueConfigured",
            !.dmaBaseProgrammed = TRUE,
            !.queueConfigured = TRUE,
            !.queueConfigFrozen = TRUE
        ]

MapIrq ==
    /\ state.phase \in {"RequestReady", "QueueConfigured"}
    /\ state.serviceLive
    /\ state.serviceBudget
    /\ state.vfCarrier
    /\ state.vfEpochFresh
    /\ state.irqRouteLive
    /\ state.irqEpochFresh
    /\ ~state.revoked
    /\ state' =
        [state EXCEPT
            !.phase = "IrqMapped",
            !.irqMapped = TRUE
        ]

ProgramBudget ==
    /\ state.phase \in {"RequestReady", "QueueConfigured", "IrqMapped"}
    /\ state.serviceLive
    /\ state.serviceBudget
    /\ state.vfCarrier
    /\ state.vfEpochFresh
    /\ state.queueLeaseLive
    /\ state.queueEpochFresh
    /\ state.queueBudgetCap
    /\ ~state.revoked
    /\ state' =
        [state EXCEPT
            !.phase = "BudgetProgrammed",
            !.budgetProgrammed = TRUE
        ]

EnableQueue ==
    /\ state.phase \in {"QueueConfigured", "IrqMapped", "BudgetProgrammed"}
    /\ state.serviceLive
    /\ state.serviceBudget
    /\ state.vfCarrier
    /\ state.vfEpochFresh
    /\ state.queueLeaseLive
    /\ state.queueEpochFresh
    /\ state.queueConfigured
    /\ state.queueConfigFrozen
    /\ state.dmaBaseProgrammed
    /\ ~state.revoked
    /\ state' =
        [state EXCEPT
            !.phase = "QueueEnabled",
            !.queueEnabled = TRUE
        ]

StartFdir ==
    /\ state.phase \in {"RequestReady", "QueueConfigured", "IrqMapped"}
    /\ state.serviceLive
    /\ state.serviceBudget
    /\ state.vfCarrier
    /\ state.vfEpochFresh
    /\ state.offloadCap
    /\ state.fdirRuleFresh
    /\ ~state.revoked
    /\ state' =
        [state EXCEPT
            !.phase = "FdirPending",
            !.fdirWritten = TRUE,
            !.fdirContextFrozen = TRUE
        ]

CompleteFdir ==
    /\ state.phase = "FdirPending"
    /\ state.serviceLive
    /\ state.serviceBudget
    /\ state.vfCarrier
    /\ state.vfEpochFresh
    /\ state.offloadCap
    /\ state.fdirRuleFresh
    /\ state.fdirContextFrozen
    /\ ~state.revoked
    /\ state' =
        [state EXCEPT
            !.phase = "FdirDone",
            !.fdirCompleted = TRUE
        ]

Revoke ==
    /\ state.phase \in {
            "RequestReady",
            "QueueConfigured",
            "IrqMapped",
            "BudgetProgrammed",
            "QueueEnabled",
            "FdirPending",
            "FdirDone"
        }
    /\ state' =
        [state EXCEPT
            !.phase = "Revoked",
            !.revoked = TRUE,
            !.queueLeaseLive = FALSE,
            !.queueEpochFresh = FALSE,
            !.queueControlCap = FALSE,
            !.dmaMemoryViewLive = FALSE,
            !.dmaReceipt = FALSE,
            !.queueConfigFrozen = FALSE,
            !.irqRouteLive = FALSE,
            !.irqEpochFresh = FALSE,
            !.queueBudgetCap = FALSE,
            !.offloadCap = FALSE,
            !.fdirContextFrozen = FALSE,
            !.fdirRuleFresh = FALSE,
            !.dmaBaseProgrammed = FALSE,
            !.queueConfigured = FALSE,
            !.queueEnabled = FALSE,
            !.irqMapped = FALSE,
            !.budgetProgrammed = FALSE,
            !.fdirWritten = FALSE,
            !.fdirCompleted = FALSE
        ]

UnsafeValidationAsAuthority ==
    /\ ALLOW_UNSAFE_VALIDATION_AS_QUEUE_AUTH
    /\ state.phase = "Validated"
    /\ state.virtchnlValid
    /\ state.opcodeAllowed
    /\ state' =
        [state EXCEPT
            !.phase = "BadValidationAsAuthority",
            !.queueConfigured = TRUE,
            !.badValidationAsAuthority = TRUE
        ]

UnsafeDmaWithoutMemoryView ==
    /\ ALLOW_UNSAFE_DMA_WITHOUT_MEMORYVIEW
    /\ state.phase = "RequestReady"
    /\ state' =
        [state EXCEPT
            !.phase = "BadDmaNoMemoryView",
            !.dmaMemoryViewLive = FALSE,
            !.dmaReceipt = FALSE,
            !.dmaBaseProgrammed = TRUE,
            !.queueConfigured = TRUE,
            !.badDmaNoMemoryView = TRUE
        ]

UnsafeEnableWithoutConfig ==
    /\ ALLOW_UNSAFE_ENABLE_WITHOUT_CONFIG
    /\ state.phase = "RequestReady"
    /\ state.vfCarrier
    /\ state.queueLeaseLive
    /\ state' =
        [state EXCEPT
            !.phase = "BadEnableNoConfig",
            !.queueEnabled = TRUE,
            !.badEnableNoConfig = TRUE
        ]

UnsafeIrqWithoutRoute ==
    /\ ALLOW_UNSAFE_IRQ_WITHOUT_ROUTE
    /\ state.phase = "RequestReady"
    /\ state.vfCarrier
    /\ state' =
        [state EXCEPT
            !.phase = "BadIrqNoRoute",
            !.irqRouteLive = FALSE,
            !.irqEpochFresh = FALSE,
            !.irqMapped = TRUE,
            !.badIrqNoRoute = TRUE
        ]

UnsafeBudgetWithoutAuth ==
    /\ ALLOW_UNSAFE_BUDGET_WITHOUT_AUTH
    /\ state.phase = "RequestReady"
    /\ state.vfCarrier
    /\ state' =
        [state EXCEPT
            !.phase = "BadBudgetNoAuth",
            !.queueBudgetCap = FALSE,
            !.budgetProgrammed = TRUE,
            !.badBudgetNoAuth = TRUE
        ]

UnsafeFdirWithoutOffload ==
    /\ ALLOW_UNSAFE_FDIR_WITHOUT_OFFLOAD
    /\ state.phase = "RequestReady"
    /\ state.vfCarrier
    /\ state' =
        [state EXCEPT
            !.phase = "BadFdirNoOffload",
            !.offloadCap = FALSE,
            !.fdirWritten = TRUE,
            !.badFdirNoOffload = TRUE
        ]

UnsafeFdirCompletionWithoutContext ==
    /\ ALLOW_UNSAFE_FDIR_COMPLETION_WITHOUT_CONTEXT
    /\ state.phase = "RequestReady"
    /\ state.vfCarrier
    /\ state.offloadCap
    /\ state' =
        [state EXCEPT
            !.phase = "BadFdirCompleteNoContext",
            !.fdirContextFrozen = FALSE,
            !.fdirCompleted = TRUE,
            !.badFdirCompleteNoContext = TRUE
        ]

UnsafeEffectAfterRevoke ==
    /\ ALLOW_UNSAFE_EFFECT_AFTER_REVOKE
    /\ state.phase = "Revoked"
    /\ state.revoked
    /\ state' =
        [state EXCEPT
            !.phase = "BadEffectAfterRevoke",
            !.queueEnabled = TRUE,
            !.fdirCompleted = TRUE,
            !.badEffectAfterRevoke = TRUE
        ]

Next ==
    \/ ReceiveValidVirtchnl
    \/ PrepareVfRequestCarrier
    \/ ConfigQueue
    \/ MapIrq
    \/ ProgramBudget
    \/ EnableQueue
    \/ StartFdir
    \/ CompleteFdir
    \/ Revoke
    \/ UnsafeValidationAsAuthority
    \/ UnsafeDmaWithoutMemoryView
    \/ UnsafeEnableWithoutConfig
    \/ UnsafeIrqWithoutRoute
    \/ UnsafeBudgetWithoutAuth
    \/ UnsafeFdirWithoutOffload
    \/ UnsafeFdirCompletionWithoutContext
    \/ UnsafeEffectAfterRevoke

Spec == Init /\ [][Next]_vars

NoQueueConfigFromValidationOnly ==
    state.queueConfigured =>
        /\ state.vfCarrier
        /\ state.vfEpochFresh
        /\ state.requestFrozen
        /\ state.queueLeaseLive
        /\ state.queueEpochFresh
        /\ state.queueControlCap

NoDmaRingBaseWithoutMemoryView ==
    state.dmaBaseProgrammed =>
        /\ state.dmaMemoryViewLive
        /\ state.dmaReceipt

NoQueueEnableWithoutFrozenConfig ==
    state.queueEnabled =>
        /\ state.queueConfigured
        /\ state.queueConfigFrozen
        /\ state.queueLeaseLive
        /\ state.queueEpochFresh
        /\ state.dmaBaseProgrammed

NoIrqMapWithoutRouteAuthority ==
    state.irqMapped =>
        /\ state.vfCarrier
        /\ state.irqRouteLive
        /\ state.irqEpochFresh

NoBudgetProgramWithoutBudgetCarrier ==
    state.budgetProgrammed =>
        /\ state.vfCarrier
        /\ state.queueLeaseLive
        /\ state.queueEpochFresh
        /\ state.queueBudgetCap

NoFdirWriteWithoutOffloadCarrier ==
    state.fdirWritten =>
        /\ state.vfCarrier
        /\ state.offloadCap
        /\ state.fdirRuleFresh

NoFdirCompletionWithoutFrozenContext ==
    state.fdirCompleted =>
        /\ state.vfCarrier
        /\ state.offloadCap
        /\ state.fdirRuleFresh
        /\ state.fdirContextFrozen

NoEffectAfterRevoke ==
    state.revoked =>
        ~(
            \/ state.dmaBaseProgrammed
            \/ state.queueConfigured
            \/ state.queueEnabled
            \/ state.irqMapped
            \/ state.budgetProgrammed
            \/ state.fdirWritten
            \/ state.fdirCompleted
        )

NoBadValidationAsAuthority == ~state.badValidationAsAuthority
NoBadDmaNoMemoryView == ~state.badDmaNoMemoryView
NoBadEnableNoConfig == ~state.badEnableNoConfig
NoBadIrqNoRoute == ~state.badIrqNoRoute
NoBadBudgetNoAuth == ~state.badBudgetNoAuth
NoBadFdirNoOffload == ~state.badFdirNoOffload
NoBadFdirCompleteNoContext == ~state.badFdirCompleteNoContext
NoBadEffectAfterRevoke == ~state.badEffectAfterRevoke

====================================================================
