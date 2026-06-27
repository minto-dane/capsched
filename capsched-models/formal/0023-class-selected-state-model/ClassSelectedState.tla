---------------------- MODULE ClassSelectedState ----------------------
EXTENDS Naturals

VARIABLES
    phase,
    path,
    selected,
    frozenFresh,
    budgetFresh,
    placementFresh,
    classRevalidated,
    classStateFresh,
    coreCachedPick,
    coreSeqFresh,
    dlServerBorrow,
    serverTicket,
    scxSliceRefilled,
    scxSliceAuthority,
    proxyExec,
    donorSelected,
    ownerExecutable,
    proxyTicket,
    running,
    failClosed

vars == <<phase, path, selected, frozenFresh, budgetFresh, placementFresh,
          classRevalidated, classStateFresh, coreCachedPick, coreSeqFresh,
          dlServerBorrow, serverTicket, scxSliceRefilled, scxSliceAuthority,
          proxyExec, donorSelected, ownerExecutable, proxyTicket, running,
          failClosed>>

Paths == {
    "None",
    "Direct",
    "Core",
    "DlServer",
    "Scx",
    "Proxy"
}

Phases == {
    "Start",
    "Prepared",
    "Selected",
    "ClassRevalidated",
    "Running",
    "FailClosed",
    "BadNoFrozen",
    "BadNoClassRevalidation",
    "BadCoreCachedStale",
    "BadDlServerNoTicket",
    "BadScxSliceAuthority",
    "BadProxyNoTicket",
    "BadClassMutationRun"
}

TypeOK ==
    /\ phase \in Phases
    /\ path \in Paths
    /\ selected \in BOOLEAN
    /\ frozenFresh \in BOOLEAN
    /\ budgetFresh \in BOOLEAN
    /\ placementFresh \in BOOLEAN
    /\ classRevalidated \in BOOLEAN
    /\ classStateFresh \in BOOLEAN
    /\ coreCachedPick \in BOOLEAN
    /\ coreSeqFresh \in BOOLEAN
    /\ dlServerBorrow \in BOOLEAN
    /\ serverTicket \in BOOLEAN
    /\ scxSliceRefilled \in BOOLEAN
    /\ scxSliceAuthority \in BOOLEAN
    /\ proxyExec \in BOOLEAN
    /\ donorSelected \in BOOLEAN
    /\ ownerExecutable \in BOOLEAN
    /\ proxyTicket \in BOOLEAN
    /\ running \in BOOLEAN
    /\ failClosed \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ path = "None"
    /\ selected = FALSE
    /\ frozenFresh = FALSE
    /\ budgetFresh = FALSE
    /\ placementFresh = FALSE
    /\ classRevalidated = FALSE
    /\ classStateFresh = FALSE
    /\ coreCachedPick = FALSE
    /\ coreSeqFresh = FALSE
    /\ dlServerBorrow = FALSE
    /\ serverTicket = FALSE
    /\ scxSliceRefilled = FALSE
    /\ scxSliceAuthority = FALSE
    /\ proxyExec = FALSE
    /\ donorSelected = FALSE
    /\ ownerExecutable = FALSE
    /\ proxyTicket = FALSE
    /\ running = FALSE
    /\ failClosed = FALSE

PrepareAuthority ==
    /\ phase = "Start"
    /\ frozenFresh' = TRUE
    /\ budgetFresh' = TRUE
    /\ placementFresh' = TRUE
    /\ classStateFresh' = TRUE
    /\ coreSeqFresh' = TRUE
    /\ phase' = "Prepared"
    /\ UNCHANGED <<path, selected, classRevalidated, coreCachedPick,
                    dlServerBorrow, serverTicket, scxSliceRefilled,
                    scxSliceAuthority, proxyExec, donorSelected,
                    ownerExecutable, proxyTicket, running, failClosed>>

PickDirect ==
    /\ phase = "Prepared"
    /\ selected' = TRUE
    /\ path' = "Direct"
    /\ phase' = "Selected"
    /\ UNCHANGED <<frozenFresh, budgetFresh, placementFresh, classRevalidated,
                    classStateFresh, coreCachedPick, coreSeqFresh,
                    dlServerBorrow, serverTicket, scxSliceRefilled,
                    scxSliceAuthority, proxyExec, donorSelected,
                    ownerExecutable, proxyTicket, running, failClosed>>

PickCoreCached ==
    /\ phase = "Prepared"
    /\ selected' = TRUE
    /\ coreCachedPick' = TRUE
    /\ path' = "Core"
    /\ phase' = "Selected"
    /\ UNCHANGED <<frozenFresh, budgetFresh, placementFresh, classRevalidated,
                    classStateFresh, coreSeqFresh, dlServerBorrow,
                    serverTicket, scxSliceRefilled, scxSliceAuthority,
                    proxyExec, donorSelected, ownerExecutable, proxyTicket,
                    running, failClosed>>

PickDlServer ==
    /\ phase = "Prepared"
    /\ selected' = TRUE
    /\ dlServerBorrow' = TRUE
    /\ serverTicket' = TRUE
    /\ path' = "DlServer"
    /\ phase' = "Selected"
    /\ UNCHANGED <<frozenFresh, budgetFresh, placementFresh, classRevalidated,
                    classStateFresh, coreCachedPick, coreSeqFresh,
                    scxSliceRefilled, scxSliceAuthority, proxyExec,
                    donorSelected, ownerExecutable, proxyTicket, running,
                    failClosed>>

PickScx ==
    /\ phase = "Prepared"
    /\ selected' = TRUE
    /\ scxSliceRefilled' = TRUE
    /\ path' = "Scx"
    /\ phase' = "Selected"
    /\ UNCHANGED <<frozenFresh, budgetFresh, placementFresh, classRevalidated,
                    classStateFresh, coreCachedPick, coreSeqFresh,
                    dlServerBorrow, serverTicket, scxSliceAuthority,
                    proxyExec, donorSelected, ownerExecutable, proxyTicket,
                    running, failClosed>>

ResolveProxy ==
    /\ phase = "Prepared"
    /\ selected' = TRUE
    /\ donorSelected' = TRUE
    /\ proxyExec' = TRUE
    /\ ownerExecutable' = TRUE
    /\ proxyTicket' = TRUE
    /\ path' = "Proxy"
    /\ phase' = "Selected"
    /\ UNCHANGED <<frozenFresh, budgetFresh, placementFresh, classRevalidated,
                    classStateFresh, coreCachedPick, coreSeqFresh,
                    dlServerBorrow, serverTicket, scxSliceRefilled,
                    scxSliceAuthority, running, failClosed>>

ClassRevalidate ==
    /\ phase = "Selected"
    /\ selected
    /\ frozenFresh
    /\ budgetFresh
    /\ placementFresh
    /\ classStateFresh
    /\ ~(coreCachedPick /\ ~coreSeqFresh)
    /\ ~(dlServerBorrow /\ ~serverTicket)
    /\ ~(proxyExec /\ ~proxyTicket)
    /\ ~scxSliceAuthority
    /\ classRevalidated' = TRUE
    /\ phase' = "ClassRevalidated"
    /\ UNCHANGED <<path, selected, frozenFresh, budgetFresh, placementFresh,
                    classStateFresh, coreCachedPick, coreSeqFresh,
                    dlServerBorrow, serverTicket, scxSliceRefilled,
                    scxSliceAuthority, proxyExec, donorSelected,
                    ownerExecutable, proxyTicket, running, failClosed>>

RunAfterRevalidation ==
    /\ phase = "ClassRevalidated"
    /\ selected
    /\ frozenFresh
    /\ budgetFresh
    /\ placementFresh
    /\ classRevalidated
    /\ classStateFresh
    /\ ~(coreCachedPick /\ ~coreSeqFresh)
    /\ ~(dlServerBorrow /\ ~serverTicket)
    /\ ~(proxyExec /\ ~proxyTicket)
    /\ ~scxSliceAuthority
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<path, selected, frozenFresh, budgetFresh, placementFresh,
                    classRevalidated, classStateFresh, coreCachedPick,
                    coreSeqFresh, dlServerBorrow, serverTicket,
                    scxSliceRefilled, scxSliceAuthority, proxyExec,
                    donorSelected, ownerExecutable, proxyTicket, failClosed>>

ClassMutationCloses ==
    /\ phase \in {"Selected", "ClassRevalidated", "Running"}
    /\ classStateFresh' = FALSE
    /\ selected' = FALSE
    /\ classRevalidated' = FALSE
    /\ running' = FALSE
    /\ failClosed' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<path, frozenFresh, budgetFresh, placementFresh,
                    coreCachedPick, coreSeqFresh, dlServerBorrow,
                    serverTicket, scxSliceRefilled, scxSliceAuthority,
                    proxyExec, donorSelected, ownerExecutable, proxyTicket>>

RevokeFrozenCloses ==
    /\ phase \in {"Selected", "ClassRevalidated", "Running"}
    /\ frozenFresh' = FALSE
    /\ selected' = FALSE
    /\ classRevalidated' = FALSE
    /\ running' = FALSE
    /\ failClosed' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<path, budgetFresh, placementFresh, classStateFresh,
                    coreCachedPick, coreSeqFresh, dlServerBorrow,
                    serverTicket, scxSliceRefilled, scxSliceAuthority,
                    proxyExec, donorSelected, ownerExecutable, proxyTicket>>

UnsafeRunNoFrozen ==
    /\ phase = "Selected"
    /\ selected
    /\ frozenFresh' = FALSE
    /\ classRevalidated' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadNoFrozen"
    /\ UNCHANGED <<path, selected, budgetFresh, placementFresh,
                    classStateFresh, coreCachedPick, coreSeqFresh,
                    dlServerBorrow, serverTicket, scxSliceRefilled,
                    scxSliceAuthority, proxyExec, donorSelected,
                    ownerExecutable, proxyTicket, failClosed>>

UnsafeRunNoClassRevalidation ==
    /\ phase = "Selected"
    /\ selected
    /\ running' = TRUE
    /\ phase' = "BadNoClassRevalidation"
    /\ UNCHANGED <<path, selected, frozenFresh, budgetFresh, placementFresh,
                    classRevalidated, classStateFresh, coreCachedPick,
                    coreSeqFresh, dlServerBorrow, serverTicket,
                    scxSliceRefilled, scxSliceAuthority, proxyExec,
                    donorSelected, ownerExecutable, proxyTicket, failClosed>>

UnsafeCoreCachedStale ==
    /\ phase = "Selected"
    /\ selected
    /\ coreCachedPick' = TRUE
    /\ coreSeqFresh' = FALSE
    /\ classRevalidated' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadCoreCachedStale"
    /\ UNCHANGED <<path, selected, frozenFresh, budgetFresh, placementFresh,
                    classStateFresh, dlServerBorrow, serverTicket,
                    scxSliceRefilled, scxSliceAuthority, proxyExec,
                    donorSelected, ownerExecutable, proxyTicket, failClosed>>

UnsafeDlServerNoTicket ==
    /\ phase = "Selected"
    /\ selected
    /\ dlServerBorrow' = TRUE
    /\ serverTicket' = FALSE
    /\ classRevalidated' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadDlServerNoTicket"
    /\ UNCHANGED <<path, selected, frozenFresh, budgetFresh, placementFresh,
                    classStateFresh, coreCachedPick, coreSeqFresh,
                    scxSliceRefilled, scxSliceAuthority, proxyExec,
                    donorSelected, ownerExecutable, proxyTicket, failClosed>>

UnsafeScxSliceAuthority ==
    /\ phase = "Selected"
    /\ selected
    /\ scxSliceRefilled' = TRUE
    /\ scxSliceAuthority' = TRUE
    /\ classRevalidated' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadScxSliceAuthority"
    /\ UNCHANGED <<path, selected, frozenFresh, budgetFresh, placementFresh,
                    classStateFresh, coreCachedPick, coreSeqFresh,
                    dlServerBorrow, serverTicket, proxyExec, donorSelected,
                    ownerExecutable, proxyTicket, failClosed>>

UnsafeProxyNoTicket ==
    /\ phase = "Selected"
    /\ selected
    /\ donorSelected' = TRUE
    /\ proxyExec' = TRUE
    /\ ownerExecutable' = TRUE
    /\ proxyTicket' = FALSE
    /\ classRevalidated' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadProxyNoTicket"
    /\ UNCHANGED <<path, selected, frozenFresh, budgetFresh, placementFresh,
                    classStateFresh, coreCachedPick, coreSeqFresh,
                    dlServerBorrow, serverTicket, scxSliceRefilled,
                    scxSliceAuthority, failClosed>>

UnsafeClassMutationRun ==
    /\ phase = "ClassRevalidated"
    /\ selected
    /\ classStateFresh' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadClassMutationRun"
    /\ UNCHANGED <<path, selected, frozenFresh, budgetFresh, placementFresh,
                    classRevalidated, coreCachedPick, coreSeqFresh,
                    dlServerBorrow, serverTicket, scxSliceRefilled,
                    scxSliceAuthority, proxyExec, donorSelected,
                    ownerExecutable, proxyTicket, failClosed>>

SafeNext ==
    PrepareAuthority \/ PickDirect \/ PickCoreCached \/ PickDlServer \/
    PickScx \/ ResolveProxy \/ ClassRevalidate \/ RunAfterRevalidation \/
    ClassMutationCloses \/ RevokeFrozenCloses

SafeSpec ==
    Init /\ [][SafeNext]_vars

UnsafeNoFrozenSpec ==
    Init /\ [][SafeNext \/ UnsafeRunNoFrozen]_vars

UnsafeNoClassRevalidationSpec ==
    Init /\ [][SafeNext \/ UnsafeRunNoClassRevalidation]_vars

UnsafeCoreCachedStaleSpec ==
    Init /\ [][SafeNext \/ UnsafeCoreCachedStale]_vars

UnsafeDlServerNoTicketSpec ==
    Init /\ [][SafeNext \/ UnsafeDlServerNoTicket]_vars

UnsafeScxSliceAuthoritySpec ==
    Init /\ [][SafeNext \/ UnsafeScxSliceAuthority]_vars

UnsafeProxyNoTicketSpec ==
    Init /\ [][SafeNext \/ UnsafeProxyNoTicket]_vars

UnsafeClassMutationRunSpec ==
    Init /\ [][SafeNext \/ UnsafeClassMutationRun]_vars

NoRunWithoutFrozenUse ==
    running => frozenFresh

NoRunWithoutClassRevalidation ==
    running => classRevalidated

NoCoreCachedPickWithStaleSeq ==
    (running /\ coreCachedPick) => coreSeqFresh

NoDlServerBorrowWithoutTicket ==
    (running /\ dlServerBorrow) => serverTicket

NoScxSliceAsAuthority ==
    ~(running /\ scxSliceAuthority)

NoProxyRunWithoutProxyTicket ==
    (running /\ proxyExec) => proxyTicket

NoClassMutationRunWithoutRefresh ==
    running => classStateFresh

=============================================================================
