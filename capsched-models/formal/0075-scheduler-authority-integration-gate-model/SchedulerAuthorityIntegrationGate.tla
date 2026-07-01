------------------- MODULE SchedulerAuthorityIntegrationGate -------------------
EXTENDS Naturals

VARIABLES
    phase,
    frozenUse,
    taskGenerationFresh,
    domainEpochFresh,
    schedCtxFresh,
    placementFresh,
    rootTicketFresh,
    published,
    selected,
    classSettled,
    retryPending,
    serverPath,
    serverTicket,
    serverEpochFresh,
    serverLive,
    lowerTaskAuthority,
    deadlinePath,
    dlAdmissionOk,
    cbsRuntimeOk,
    cbsThrottled,
    monitorTimer,
    monitorBudget,
    sealedRunToken,
    monitorEpochFresh,
    rawCapAfterPublication,
    heavyLookupAfterPublication,
    linuxRuntimeAuthority,
    serverRuntimeAuthority,
    deadlineCompatAuthority,
    placementAuthority,
    running,
    failClosed,
    protectionClaim

vars == <<phase, frozenUse, taskGenerationFresh, domainEpochFresh,
          schedCtxFresh, placementFresh, rootTicketFresh, published, selected,
          classSettled, retryPending, serverPath, serverTicket,
          serverEpochFresh, serverLive, lowerTaskAuthority, deadlinePath,
          dlAdmissionOk, cbsRuntimeOk, cbsThrottled, monitorTimer,
          monitorBudget, sealedRunToken, monitorEpochFresh,
          rawCapAfterPublication, heavyLookupAfterPublication,
          linuxRuntimeAuthority, serverRuntimeAuthority,
          deadlineCompatAuthority, placementAuthority, running, failClosed,
          protectionClaim>>

Phases == {
    "Start",
    "Frozen",
    "Published",
    "Selected",
    "Activated",
    "Running",
    "FailClosed",
    "BadPublicationWithoutFrozenTuple",
    "BadRunMissingFrozenTuple",
    "BadRunWithoutSelectedSettlement",
    "BadRunWithoutServerTicket",
    "BadRunWithStaleServerEpoch",
    "BadRunWithoutLowerTaskAuthority",
    "BadRunWithoutDLAdmission",
    "BadRunWhileCBSThrottled",
    "BadRunWithoutMonitorTimer",
    "BadLinuxRuntimeAuthority",
    "BadServerRuntimeAuthority",
    "BadDeadlineCompatibilityAuthority",
    "BadPlacementAuthority",
    "BadRawCapAfterPublication",
    "BadHeavyLookupAfterPublication",
    "BadFailClosedRunning",
    "BadProtectionClaim"
}

TypeOK ==
    /\ phase \in Phases
    /\ frozenUse \in BOOLEAN
    /\ taskGenerationFresh \in BOOLEAN
    /\ domainEpochFresh \in BOOLEAN
    /\ schedCtxFresh \in BOOLEAN
    /\ placementFresh \in BOOLEAN
    /\ rootTicketFresh \in BOOLEAN
    /\ published \in BOOLEAN
    /\ selected \in BOOLEAN
    /\ classSettled \in BOOLEAN
    /\ retryPending \in BOOLEAN
    /\ serverPath \in BOOLEAN
    /\ serverTicket \in BOOLEAN
    /\ serverEpochFresh \in BOOLEAN
    /\ serverLive \in BOOLEAN
    /\ lowerTaskAuthority \in BOOLEAN
    /\ deadlinePath \in BOOLEAN
    /\ dlAdmissionOk \in BOOLEAN
    /\ cbsRuntimeOk \in BOOLEAN
    /\ cbsThrottled \in BOOLEAN
    /\ monitorTimer \in BOOLEAN
    /\ monitorBudget \in BOOLEAN
    /\ sealedRunToken \in BOOLEAN
    /\ monitorEpochFresh \in BOOLEAN
    /\ rawCapAfterPublication \in BOOLEAN
    /\ heavyLookupAfterPublication \in BOOLEAN
    /\ linuxRuntimeAuthority \in BOOLEAN
    /\ serverRuntimeAuthority \in BOOLEAN
    /\ deadlineCompatAuthority \in BOOLEAN
    /\ placementAuthority \in BOOLEAN
    /\ running \in BOOLEAN
    /\ failClosed \in BOOLEAN
    /\ protectionClaim \in BOOLEAN

FrozenTupleComplete ==
    /\ frozenUse
    /\ taskGenerationFresh
    /\ domainEpochFresh
    /\ schedCtxFresh
    /\ placementFresh
    /\ rootTicketFresh

SelectedSettled ==
    /\ selected
    /\ classSettled
    /\ ~retryPending

ServerAuthorityOk ==
    \/ ~serverPath
    \/ /\ serverTicket
       /\ serverEpochFresh
       /\ serverLive
       /\ lowerTaskAuthority

DeadlineCompatibilityOk ==
    \/ ~deadlinePath
    \/ /\ dlAdmissionOk
       /\ cbsRuntimeOk
       /\ ~cbsThrottled

MonitorRootOk ==
    /\ monitorTimer
    /\ monitorBudget
    /\ sealedRunToken
    /\ monitorEpochFresh

Init ==
    /\ phase = "Start"
    /\ frozenUse = FALSE
    /\ taskGenerationFresh = FALSE
    /\ domainEpochFresh = FALSE
    /\ schedCtxFresh = FALSE
    /\ placementFresh = FALSE
    /\ rootTicketFresh = FALSE
    /\ published = FALSE
    /\ selected = FALSE
    /\ classSettled = FALSE
    /\ retryPending = FALSE
    /\ serverPath = FALSE
    /\ serverTicket = FALSE
    /\ serverEpochFresh = FALSE
    /\ serverLive = FALSE
    /\ lowerTaskAuthority = FALSE
    /\ deadlinePath = FALSE
    /\ dlAdmissionOk = FALSE
    /\ cbsRuntimeOk = FALSE
    /\ cbsThrottled = FALSE
    /\ monitorTimer = FALSE
    /\ monitorBudget = FALSE
    /\ sealedRunToken = FALSE
    /\ monitorEpochFresh = FALSE
    /\ rawCapAfterPublication = FALSE
    /\ heavyLookupAfterPublication = FALSE
    /\ linuxRuntimeAuthority = FALSE
    /\ serverRuntimeAuthority = FALSE
    /\ deadlineCompatAuthority = FALSE
    /\ placementAuthority = FALSE
    /\ running = FALSE
    /\ failClosed = FALSE
    /\ protectionClaim = FALSE

SetFrozenTuple ==
    /\ frozenUse' = TRUE
    /\ taskGenerationFresh' = TRUE
    /\ domainEpochFresh' = TRUE
    /\ schedCtxFresh' = TRUE
    /\ placementFresh' = TRUE
    /\ rootTicketFresh' = TRUE

NoServerPath ==
    /\ serverPath' = FALSE
    /\ serverTicket' = FALSE
    /\ serverEpochFresh' = FALSE
    /\ serverLive' = FALSE
    /\ lowerTaskAuthority' = FALSE

SetServerPath ==
    /\ serverPath' = TRUE
    /\ serverTicket' = TRUE
    /\ serverEpochFresh' = TRUE
    /\ serverLive' = TRUE
    /\ lowerTaskAuthority' = TRUE

NoDeadlinePath ==
    /\ deadlinePath' = FALSE
    /\ dlAdmissionOk' = FALSE
    /\ cbsRuntimeOk' = FALSE
    /\ cbsThrottled' = FALSE

SetDeadlinePath ==
    /\ deadlinePath' = TRUE
    /\ dlAdmissionOk' = TRUE
    /\ cbsRuntimeOk' = TRUE
    /\ cbsThrottled' = FALSE

FreezeDirect ==
    /\ phase = "Start"
    /\ SetFrozenTuple
    /\ NoServerPath
    /\ NoDeadlinePath
    /\ phase' = "Frozen"
    /\ UNCHANGED <<published, selected, classSettled, retryPending,
                    monitorTimer, monitorBudget, sealedRunToken,
                    monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, running, failClosed, protectionClaim>>

FreezeServer ==
    /\ phase = "Start"
    /\ SetFrozenTuple
    /\ SetServerPath
    /\ NoDeadlinePath
    /\ phase' = "Frozen"
    /\ UNCHANGED <<published, selected, classSettled, retryPending,
                    monitorTimer, monitorBudget, sealedRunToken,
                    monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, running, failClosed, protectionClaim>>

FreezeDeadline ==
    /\ phase = "Start"
    /\ SetFrozenTuple
    /\ NoServerPath
    /\ SetDeadlinePath
    /\ phase' = "Frozen"
    /\ UNCHANGED <<published, selected, classSettled, retryPending,
                    monitorTimer, monitorBudget, sealedRunToken,
                    monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, running, failClosed, protectionClaim>>

FreezeServerDeadline ==
    /\ phase = "Start"
    /\ SetFrozenTuple
    /\ SetServerPath
    /\ SetDeadlinePath
    /\ phase' = "Frozen"
    /\ UNCHANGED <<published, selected, classSettled, retryPending,
                    monitorTimer, monitorBudget, sealedRunToken,
                    monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, running, failClosed, protectionClaim>>

PublishWakeOrEnqueue ==
    /\ phase = "Frozen"
    /\ FrozenTupleComplete
    /\ published' = TRUE
    /\ phase' = "Published"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, selected,
                    classSettled, retryPending, serverPath, serverTicket,
                    serverEpochFresh, serverLive, lowerTaskAuthority,
                    deadlinePath, dlAdmissionOk, cbsRuntimeOk, cbsThrottled,
                    monitorTimer, monitorBudget, sealedRunToken,
                    monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, running, failClosed, protectionClaim>>

SettleSelectedState ==
    /\ phase = "Published"
    /\ FrozenTupleComplete
    /\ ServerAuthorityOk
    /\ DeadlineCompatibilityOk
    /\ selected' = TRUE
    /\ classSettled' = TRUE
    /\ retryPending' = FALSE
    /\ phase' = "Selected"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    serverPath, serverTicket, serverEpochFresh, serverLive,
                    lowerTaskAuthority, deadlinePath, dlAdmissionOk,
                    cbsRuntimeOk, cbsThrottled, monitorTimer, monitorBudget,
                    sealedRunToken, monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, running, failClosed, protectionClaim>>

MonitorActivate ==
    /\ phase = "Selected"
    /\ FrozenTupleComplete
    /\ SelectedSettled
    /\ ServerAuthorityOk
    /\ DeadlineCompatibilityOk
    /\ monitorTimer' = TRUE
    /\ monitorBudget' = TRUE
    /\ sealedRunToken' = TRUE
    /\ monitorEpochFresh' = TRUE
    /\ phase' = "Activated"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    selected, classSettled, retryPending, serverPath,
                    serverTicket, serverEpochFresh, serverLive,
                    lowerTaskAuthority, deadlinePath, dlAdmissionOk,
                    cbsRuntimeOk, cbsThrottled, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, running, failClosed, protectionClaim>>

RunAfterAllAuthority ==
    /\ phase = "Activated"
    /\ FrozenTupleComplete
    /\ SelectedSettled
    /\ ServerAuthorityOk
    /\ DeadlineCompatibilityOk
    /\ MonitorRootOk
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    selected, classSettled, retryPending, serverPath,
                    serverTicket, serverEpochFresh, serverLive,
                    lowerTaskAuthority, deadlinePath, dlAdmissionOk,
                    cbsRuntimeOk, cbsThrottled, monitorTimer, monitorBudget,
                    sealedRunToken, monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, failClosed, protectionClaim>>

FailClosedBeforeRun ==
    /\ phase \in {"Start", "Frozen", "Published", "Selected", "Activated"}
    /\ running = FALSE
    /\ failClosed' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    selected, classSettled, retryPending, serverPath,
                    serverTicket, serverEpochFresh, serverLive,
                    lowerTaskAuthority, deadlinePath, dlAdmissionOk,
                    cbsRuntimeOk, cbsThrottled, monitorTimer, monitorBudget,
                    sealedRunToken, monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, running, protectionClaim>>

TerminalStutter ==
    /\ phase \in {"Running", "FailClosed"}
    /\ UNCHANGED vars

SafeNext ==
    \/ FreezeDirect
    \/ FreezeServer
    \/ FreezeDeadline
    \/ FreezeServerDeadline
    \/ PublishWakeOrEnqueue
    \/ SettleSelectedState
    \/ MonitorActivate
    \/ RunAfterAllAuthority
    \/ FailClosedBeforeRun
    \/ TerminalStutter

UnsafePublicationWithoutFrozenTuple ==
    /\ phase = "Start"
    /\ published' = TRUE
    /\ phase' = "BadPublicationWithoutFrozenTuple"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, selected,
                    classSettled, retryPending, serverPath, serverTicket,
                    serverEpochFresh, serverLive, lowerTaskAuthority,
                    deadlinePath, dlAdmissionOk, cbsRuntimeOk, cbsThrottled,
                    monitorTimer, monitorBudget, sealedRunToken,
                    monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, running, failClosed, protectionClaim>>

BadRunCommon(badPhase) ==
    /\ running' = TRUE
    /\ phase' = badPhase

SetGoodExecutionBase ==
    /\ frozenUse' = TRUE
    /\ taskGenerationFresh' = TRUE
    /\ domainEpochFresh' = TRUE
    /\ schedCtxFresh' = TRUE
    /\ placementFresh' = TRUE
    /\ rootTicketFresh' = TRUE
    /\ published' = TRUE
    /\ selected' = TRUE
    /\ classSettled' = TRUE
    /\ retryPending' = FALSE
    /\ serverPath' = FALSE
    /\ serverTicket' = FALSE
    /\ serverEpochFresh' = FALSE
    /\ serverLive' = FALSE
    /\ lowerTaskAuthority' = FALSE
    /\ deadlinePath' = FALSE
    /\ dlAdmissionOk' = FALSE
    /\ cbsRuntimeOk' = FALSE
    /\ cbsThrottled' = FALSE
    /\ monitorTimer' = TRUE
    /\ monitorBudget' = TRUE
    /\ sealedRunToken' = TRUE
    /\ monitorEpochFresh' = TRUE
    /\ rawCapAfterPublication' = FALSE
    /\ heavyLookupAfterPublication' = FALSE
    /\ linuxRuntimeAuthority' = FALSE
    /\ serverRuntimeAuthority' = FALSE
    /\ deadlineCompatAuthority' = FALSE
    /\ placementAuthority' = FALSE
    /\ failClosed' = FALSE
    /\ protectionClaim' = FALSE

UnsafeRunMissingFrozenTuple ==
    /\ phase = "Start"
    /\ running' = TRUE
    /\ phase' = "BadRunMissingFrozenTuple"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    selected, classSettled, retryPending, serverPath,
                    serverTicket, serverEpochFresh, serverLive,
                    lowerTaskAuthority, deadlinePath, dlAdmissionOk,
                    cbsRuntimeOk, cbsThrottled, monitorTimer, monitorBudget,
                    sealedRunToken, monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, failClosed, protectionClaim>>

UnsafeRunWithoutSelectedSettlement ==
    /\ phase = "Start"
    /\ running' = TRUE
    /\ selected' = TRUE
    /\ classSettled' = FALSE
    /\ retryPending' = TRUE
    /\ phase' = "BadRunWithoutSelectedSettlement"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    serverPath, serverTicket, serverEpochFresh, serverLive,
                    lowerTaskAuthority, deadlinePath, dlAdmissionOk,
                    cbsRuntimeOk, cbsThrottled, monitorTimer, monitorBudget,
                    sealedRunToken, monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, failClosed, protectionClaim>>

UnsafeRunWithoutServerTicket ==
    /\ phase = "Start"
    /\ serverPath' = TRUE
    /\ serverTicket' = FALSE
    /\ serverEpochFresh' = TRUE
    /\ serverLive' = TRUE
    /\ lowerTaskAuthority' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunWithoutServerTicket"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    selected, classSettled, retryPending, deadlinePath,
                    dlAdmissionOk, cbsRuntimeOk, cbsThrottled, monitorTimer,
                    monitorBudget, sealedRunToken, monitorEpochFresh,
                    rawCapAfterPublication, heavyLookupAfterPublication,
                    linuxRuntimeAuthority, serverRuntimeAuthority,
                    deadlineCompatAuthority, placementAuthority, failClosed,
                    protectionClaim>>

UnsafeRunWithStaleServerEpoch ==
    /\ phase = "Start"
    /\ serverPath' = TRUE
    /\ serverTicket' = TRUE
    /\ serverEpochFresh' = FALSE
    /\ serverLive' = TRUE
    /\ lowerTaskAuthority' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunWithStaleServerEpoch"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    selected, classSettled, retryPending, deadlinePath,
                    dlAdmissionOk, cbsRuntimeOk, cbsThrottled, monitorTimer,
                    monitorBudget, sealedRunToken, monitorEpochFresh,
                    rawCapAfterPublication, heavyLookupAfterPublication,
                    linuxRuntimeAuthority, serverRuntimeAuthority,
                    deadlineCompatAuthority, placementAuthority, failClosed,
                    protectionClaim>>

UnsafeRunWithoutLowerTaskAuthority ==
    /\ phase = "Start"
    /\ serverPath' = TRUE
    /\ serverTicket' = TRUE
    /\ serverEpochFresh' = TRUE
    /\ serverLive' = TRUE
    /\ lowerTaskAuthority' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadRunWithoutLowerTaskAuthority"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    selected, classSettled, retryPending, deadlinePath,
                    dlAdmissionOk, cbsRuntimeOk, cbsThrottled, monitorTimer,
                    monitorBudget, sealedRunToken, monitorEpochFresh,
                    rawCapAfterPublication, heavyLookupAfterPublication,
                    linuxRuntimeAuthority, serverRuntimeAuthority,
                    deadlineCompatAuthority, placementAuthority, failClosed,
                    protectionClaim>>

UnsafeRunWithoutDLAdmission ==
    /\ phase = "Start"
    /\ deadlinePath' = TRUE
    /\ dlAdmissionOk' = FALSE
    /\ cbsRuntimeOk' = TRUE
    /\ cbsThrottled' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadRunWithoutDLAdmission"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    selected, classSettled, retryPending, serverPath,
                    serverTicket, serverEpochFresh, serverLive,
                    lowerTaskAuthority, monitorTimer, monitorBudget,
                    sealedRunToken, monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, failClosed, protectionClaim>>

UnsafeRunWhileCBSThrottled ==
    /\ phase = "Start"
    /\ deadlinePath' = TRUE
    /\ dlAdmissionOk' = TRUE
    /\ cbsRuntimeOk' = FALSE
    /\ cbsThrottled' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunWhileCBSThrottled"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    selected, classSettled, retryPending, serverPath,
                    serverTicket, serverEpochFresh, serverLive,
                    lowerTaskAuthority, monitorTimer, monitorBudget,
                    sealedRunToken, monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, failClosed, protectionClaim>>

UnsafeRunWithoutMonitorTimer ==
    /\ phase = "Start"
    /\ monitorTimer' = FALSE
    /\ monitorBudget' = TRUE
    /\ sealedRunToken' = TRUE
    /\ monitorEpochFresh' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunWithoutMonitorTimer"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    selected, classSettled, retryPending, serverPath,
                    serverTicket, serverEpochFresh, serverLive,
                    lowerTaskAuthority, deadlinePath, dlAdmissionOk,
                    cbsRuntimeOk, cbsThrottled, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, failClosed, protectionClaim>>

UnsafeLinuxRuntimeAuthority ==
    /\ phase = "Start"
    /\ linuxRuntimeAuthority' = TRUE
    /\ phase' = "BadLinuxRuntimeAuthority"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    selected, classSettled, retryPending, serverPath,
                    serverTicket, serverEpochFresh, serverLive,
                    lowerTaskAuthority, deadlinePath, dlAdmissionOk,
                    cbsRuntimeOk, cbsThrottled, monitorTimer, monitorBudget,
                    sealedRunToken, monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, serverRuntimeAuthority,
                    deadlineCompatAuthority, placementAuthority, running,
                    failClosed, protectionClaim>>

UnsafeServerRuntimeAuthority ==
    /\ phase = "Start"
    /\ serverRuntimeAuthority' = TRUE
    /\ phase' = "BadServerRuntimeAuthority"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    selected, classSettled, retryPending, serverPath,
                    serverTicket, serverEpochFresh, serverLive,
                    lowerTaskAuthority, deadlinePath, dlAdmissionOk,
                    cbsRuntimeOk, cbsThrottled, monitorTimer, monitorBudget,
                    sealedRunToken, monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    deadlineCompatAuthority, placementAuthority, running,
                    failClosed, protectionClaim>>

UnsafeDeadlineCompatibilityAuthority ==
    /\ phase = "Start"
    /\ deadlineCompatAuthority' = TRUE
    /\ phase' = "BadDeadlineCompatibilityAuthority"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    selected, classSettled, retryPending, serverPath,
                    serverTicket, serverEpochFresh, serverLive,
                    lowerTaskAuthority, deadlinePath, dlAdmissionOk,
                    cbsRuntimeOk, cbsThrottled, monitorTimer, monitorBudget,
                    sealedRunToken, monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, placementAuthority, running,
                    failClosed, protectionClaim>>

UnsafePlacementAuthority ==
    /\ phase = "Start"
    /\ placementAuthority' = TRUE
    /\ phase' = "BadPlacementAuthority"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    selected, classSettled, retryPending, serverPath,
                    serverTicket, serverEpochFresh, serverLive,
                    lowerTaskAuthority, deadlinePath, dlAdmissionOk,
                    cbsRuntimeOk, cbsThrottled, monitorTimer, monitorBudget,
                    sealedRunToken, monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority, running,
                    failClosed, protectionClaim>>

UnsafeRawCapAfterPublication ==
    /\ phase = "Start"
    /\ published' = TRUE
    /\ rawCapAfterPublication' = TRUE
    /\ phase' = "BadRawCapAfterPublication"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, selected,
                    classSettled, retryPending, serverPath, serverTicket,
                    serverEpochFresh, serverLive, lowerTaskAuthority,
                    deadlinePath, dlAdmissionOk, cbsRuntimeOk, cbsThrottled,
                    monitorTimer, monitorBudget, sealedRunToken,
                    monitorEpochFresh, heavyLookupAfterPublication,
                    linuxRuntimeAuthority, serverRuntimeAuthority,
                    deadlineCompatAuthority, placementAuthority, running,
                    failClosed, protectionClaim>>

UnsafeHeavyLookupAfterPublication ==
    /\ phase = "Start"
    /\ published' = TRUE
    /\ heavyLookupAfterPublication' = TRUE
    /\ phase' = "BadHeavyLookupAfterPublication"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, selected,
                    classSettled, retryPending, serverPath, serverTicket,
                    serverEpochFresh, serverLive, lowerTaskAuthority,
                    deadlinePath, dlAdmissionOk, cbsRuntimeOk, cbsThrottled,
                    monitorTimer, monitorBudget, sealedRunToken,
                    monitorEpochFresh, rawCapAfterPublication,
                    linuxRuntimeAuthority, serverRuntimeAuthority,
                    deadlineCompatAuthority, placementAuthority, running,
                    failClosed, protectionClaim>>

UnsafeFailClosedRunning ==
    /\ phase = "Start"
    /\ failClosed' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadFailClosedRunning"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    selected, classSettled, retryPending, serverPath,
                    serverTicket, serverEpochFresh, serverLive,
                    lowerTaskAuthority, deadlinePath, dlAdmissionOk,
                    cbsRuntimeOk, cbsThrottled, monitorTimer, monitorBudget,
                    sealedRunToken, monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, protectionClaim>>

UnsafeProtectionClaim ==
    /\ phase = "Start"
    /\ protectionClaim' = TRUE
    /\ phase' = "BadProtectionClaim"
    /\ UNCHANGED <<frozenUse, taskGenerationFresh, domainEpochFresh,
                    schedCtxFresh, placementFresh, rootTicketFresh, published,
                    selected, classSettled, retryPending, serverPath,
                    serverTicket, serverEpochFresh, serverLive,
                    lowerTaskAuthority, deadlinePath, dlAdmissionOk,
                    cbsRuntimeOk, cbsThrottled, monitorTimer, monitorBudget,
                    sealedRunToken, monitorEpochFresh, rawCapAfterPublication,
                    heavyLookupAfterPublication, linuxRuntimeAuthority,
                    serverRuntimeAuthority, deadlineCompatAuthority,
                    placementAuthority, running, failClosed>>

BadStutter ==
    /\ phase \in {"BadPublicationWithoutFrozenTuple", "BadRunMissingFrozenTuple",
                  "BadRunWithoutSelectedSettlement",
                  "BadRunWithoutServerTicket", "BadRunWithStaleServerEpoch",
                  "BadRunWithoutLowerTaskAuthority",
                  "BadRunWithoutDLAdmission", "BadRunWhileCBSThrottled",
                  "BadRunWithoutMonitorTimer", "BadLinuxRuntimeAuthority",
                  "BadServerRuntimeAuthority",
                  "BadDeadlineCompatibilityAuthority", "BadPlacementAuthority",
                  "BadRawCapAfterPublication",
                  "BadHeavyLookupAfterPublication", "BadFailClosedRunning",
                  "BadProtectionClaim"}
    /\ UNCHANGED vars

SafeSpec == Init /\ [][SafeNext]_vars
SpecUnsafePublicationWithoutFrozenTuple == Init /\ [][UnsafePublicationWithoutFrozenTuple \/ BadStutter]_vars
SpecUnsafeRunMissingFrozenTuple == Init /\ [][UnsafeRunMissingFrozenTuple \/ BadStutter]_vars
SpecUnsafeRunWithoutSelectedSettlement == Init /\ [][UnsafeRunWithoutSelectedSettlement \/ BadStutter]_vars
SpecUnsafeRunWithoutServerTicket == Init /\ [][UnsafeRunWithoutServerTicket \/ BadStutter]_vars
SpecUnsafeRunWithStaleServerEpoch == Init /\ [][UnsafeRunWithStaleServerEpoch \/ BadStutter]_vars
SpecUnsafeRunWithoutLowerTaskAuthority == Init /\ [][UnsafeRunWithoutLowerTaskAuthority \/ BadStutter]_vars
SpecUnsafeRunWithoutDLAdmission == Init /\ [][UnsafeRunWithoutDLAdmission \/ BadStutter]_vars
SpecUnsafeRunWhileCBSThrottled == Init /\ [][UnsafeRunWhileCBSThrottled \/ BadStutter]_vars
SpecUnsafeRunWithoutMonitorTimer == Init /\ [][UnsafeRunWithoutMonitorTimer \/ BadStutter]_vars
SpecUnsafeLinuxRuntimeAuthority == Init /\ [][UnsafeLinuxRuntimeAuthority \/ BadStutter]_vars
SpecUnsafeServerRuntimeAuthority == Init /\ [][UnsafeServerRuntimeAuthority \/ BadStutter]_vars
SpecUnsafeDeadlineCompatibilityAuthority == Init /\ [][UnsafeDeadlineCompatibilityAuthority \/ BadStutter]_vars
SpecUnsafePlacementAuthority == Init /\ [][UnsafePlacementAuthority \/ BadStutter]_vars
SpecUnsafeRawCapAfterPublication == Init /\ [][UnsafeRawCapAfterPublication \/ BadStutter]_vars
SpecUnsafeHeavyLookupAfterPublication == Init /\ [][UnsafeHeavyLookupAfterPublication \/ BadStutter]_vars
SpecUnsafeFailClosedRunning == Init /\ [][UnsafeFailClosedRunning \/ BadStutter]_vars
SpecUnsafeProtectionClaim == Init /\ [][UnsafeProtectionClaim \/ BadStutter]_vars

NoPublicationWithoutFrozenTuple ==
    published => FrozenTupleComplete

NoRunWithoutFrozenTuple ==
    running => FrozenTupleComplete

NoRunWithoutSelectedSettlement ==
    running => SelectedSettled

NoRunWithoutServerAuthority ==
    running => ServerAuthorityOk

NoRunWithoutDeadlineCompatibility ==
    running => DeadlineCompatibilityOk

NoRunWithoutMonitorRoot ==
    running => MonitorRootOk

NoRawCapAfterPublication ==
    published => ~rawCapAfterPublication

NoHeavyLookupAfterPublication ==
    published => ~heavyLookupAfterPublication

NoLinuxRuntimeAsAuthority ==
    ~linuxRuntimeAuthority

NoServerRuntimeAsAuthority ==
    ~serverRuntimeAuthority

NoDeadlineCompatibilityAsAuthority ==
    ~deadlineCompatAuthority

NoPlacementAsAuthority ==
    ~placementAuthority

NoFailClosedRunning ==
    failClosed => ~running

NoProtectionClaim ==
    ~protectionClaim

=============================================================================
