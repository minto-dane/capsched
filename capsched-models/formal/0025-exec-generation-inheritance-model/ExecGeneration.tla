------------------------ MODULE ExecGeneration ------------------------
EXTENDS Naturals

VARIABLES
    phase,
    domainSame,
    domainTransitionToken,
    schedCtxLive,
    runContinuation,
    execCommitted,
    checkOnly,
    processGenFresh,
    execGenIncremented,
    oldFrozenEndpointUse,
    survivingFd,
    closeOnExecFd,
    closeOnExecHandled,
    endpointDerivedPostExec,
    credsChanged,
    lsmAttenuated,
    execfdInserted,
    execfdDerived,
    oldAsyncUse,
    asyncEffect,
    oldMmapLive,
    mmapOldRevoked,
    endpointEffect,
    running,
    failClosed

vars == <<phase, domainSame, domainTransitionToken, schedCtxLive,
          runContinuation, execCommitted, checkOnly, processGenFresh,
          execGenIncremented, oldFrozenEndpointUse, survivingFd,
          closeOnExecFd, closeOnExecHandled, endpointDerivedPostExec,
          credsChanged, lsmAttenuated, execfdInserted, execfdDerived,
          oldAsyncUse, asyncEffect, oldMmapLive, mmapOldRevoked,
          endpointEffect, running, failClosed>>

Phases == {
    "Start",
    "Prepared",
    "CheckOnly",
    "ExecCommitted",
    "Running",
    "EndpointEffect",
    "AsyncEffect",
    "FailClosed",
    "BadDomainChange",
    "BadRunNoContinuation",
    "BadOldEndpointUse",
    "BadFdNoDerive",
    "BadCloseOnExecLeak",
    "BadCredAmplify",
    "BadExecfdNoDerive",
    "BadOldAsyncUse",
    "BadOldMmapLive",
    "BadCheckOnlyMutation"
}

TypeOK ==
    /\ phase \in Phases
    /\ domainSame \in BOOLEAN
    /\ domainTransitionToken \in BOOLEAN
    /\ schedCtxLive \in BOOLEAN
    /\ runContinuation \in BOOLEAN
    /\ execCommitted \in BOOLEAN
    /\ checkOnly \in BOOLEAN
    /\ processGenFresh \in BOOLEAN
    /\ execGenIncremented \in BOOLEAN
    /\ oldFrozenEndpointUse \in BOOLEAN
    /\ survivingFd \in BOOLEAN
    /\ closeOnExecFd \in BOOLEAN
    /\ closeOnExecHandled \in BOOLEAN
    /\ endpointDerivedPostExec \in BOOLEAN
    /\ credsChanged \in BOOLEAN
    /\ lsmAttenuated \in BOOLEAN
    /\ execfdInserted \in BOOLEAN
    /\ execfdDerived \in BOOLEAN
    /\ oldAsyncUse \in BOOLEAN
    /\ asyncEffect \in BOOLEAN
    /\ oldMmapLive \in BOOLEAN
    /\ mmapOldRevoked \in BOOLEAN
    /\ endpointEffect \in BOOLEAN
    /\ running \in BOOLEAN
    /\ failClosed \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ domainSame = FALSE
    /\ domainTransitionToken = FALSE
    /\ schedCtxLive = FALSE
    /\ runContinuation = FALSE
    /\ execCommitted = FALSE
    /\ checkOnly = FALSE
    /\ processGenFresh = FALSE
    /\ execGenIncremented = FALSE
    /\ oldFrozenEndpointUse = FALSE
    /\ survivingFd = FALSE
    /\ closeOnExecFd = FALSE
    /\ closeOnExecHandled = FALSE
    /\ endpointDerivedPostExec = FALSE
    /\ credsChanged = FALSE
    /\ lsmAttenuated = FALSE
    /\ execfdInserted = FALSE
    /\ execfdDerived = FALSE
    /\ oldAsyncUse = FALSE
    /\ asyncEffect = FALSE
    /\ oldMmapLive = FALSE
    /\ mmapOldRevoked = FALSE
    /\ endpointEffect = FALSE
    /\ running = FALSE
    /\ failClosed = FALSE

PrepareExec ==
    /\ phase = "Start"
    /\ domainSame' = TRUE
    /\ schedCtxLive' = TRUE
    /\ runContinuation' = TRUE
    /\ oldFrozenEndpointUse' = TRUE
    /\ survivingFd' = TRUE
    /\ closeOnExecFd' = TRUE
    /\ credsChanged' = TRUE
    /\ oldAsyncUse' = TRUE
    /\ oldMmapLive' = TRUE
    /\ phase' = "Prepared"
    /\ UNCHANGED <<domainTransitionToken, execCommitted, checkOnly,
                    processGenFresh, execGenIncremented,
                    closeOnExecHandled, endpointDerivedPostExec,
                    lsmAttenuated, execfdInserted, execfdDerived,
                    asyncEffect, mmapOldRevoked, endpointEffect, running,
                    failClosed>>

CheckOnlyExecPolicy ==
    /\ phase = "Prepared"
    /\ checkOnly' = TRUE
    /\ phase' = "CheckOnly"
    /\ UNCHANGED <<domainSame, domainTransitionToken, schedCtxLive,
                    runContinuation, execCommitted, processGenFresh,
                    execGenIncremented, oldFrozenEndpointUse, survivingFd,
                    closeOnExecFd, closeOnExecHandled,
                    endpointDerivedPostExec, credsChanged, lsmAttenuated,
                    execfdInserted, execfdDerived, oldAsyncUse, asyncEffect,
                    oldMmapLive, mmapOldRevoked, endpointEffect, running,
                    failClosed>>

CommitExecNoExecfd ==
    /\ phase = "Prepared"
    /\ domainSame
    /\ schedCtxLive
    /\ runContinuation
    /\ execCommitted' = TRUE
    /\ processGenFresh' = TRUE
    /\ execGenIncremented' = TRUE
    /\ oldFrozenEndpointUse' = FALSE
    /\ oldAsyncUse' = FALSE
    /\ closeOnExecHandled' = TRUE
    /\ endpointDerivedPostExec' = TRUE
    /\ lsmAttenuated' = TRUE
    /\ oldMmapLive' = FALSE
    /\ mmapOldRevoked' = TRUE
    /\ phase' = "ExecCommitted"
    /\ UNCHANGED <<domainSame, domainTransitionToken, schedCtxLive,
                    runContinuation, checkOnly, survivingFd, closeOnExecFd,
                    credsChanged, execfdInserted, execfdDerived, asyncEffect,
                    endpointEffect, running, failClosed>>

CommitExecWithExecfd ==
    /\ phase = "Prepared"
    /\ domainSame
    /\ schedCtxLive
    /\ runContinuation
    /\ execCommitted' = TRUE
    /\ processGenFresh' = TRUE
    /\ execGenIncremented' = TRUE
    /\ oldFrozenEndpointUse' = FALSE
    /\ oldAsyncUse' = FALSE
    /\ closeOnExecHandled' = TRUE
    /\ endpointDerivedPostExec' = TRUE
    /\ lsmAttenuated' = TRUE
    /\ execfdInserted' = TRUE
    /\ execfdDerived' = TRUE
    /\ oldMmapLive' = FALSE
    /\ mmapOldRevoked' = TRUE
    /\ phase' = "ExecCommitted"
    /\ UNCHANGED <<domainSame, domainTransitionToken, schedCtxLive,
                    runContinuation, checkOnly, survivingFd, closeOnExecFd,
                    credsChanged, asyncEffect, endpointEffect, running,
                    failClosed>>

RunAfterExec ==
    /\ phase = "ExecCommitted"
    /\ execCommitted
    /\ domainSame
    /\ schedCtxLive
    /\ runContinuation
    /\ processGenFresh
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<domainSame, domainTransitionToken, schedCtxLive,
                    runContinuation, execCommitted, checkOnly,
                    processGenFresh, execGenIncremented,
                    oldFrozenEndpointUse, survivingFd, closeOnExecFd,
                    closeOnExecHandled, endpointDerivedPostExec,
                    credsChanged, lsmAttenuated, execfdInserted,
                    execfdDerived, oldAsyncUse, asyncEffect, oldMmapLive,
                    mmapOldRevoked, endpointEffect, failClosed>>

EndpointEffectAfterExec ==
    /\ phase = "Running"
    /\ running
    /\ execCommitted
    /\ processGenFresh
    /\ endpointDerivedPostExec
    /\ closeOnExecHandled
    /\ lsmAttenuated
    /\ ~(execfdInserted /\ ~execfdDerived)
    /\ ~oldFrozenEndpointUse
    /\ ~oldMmapLive
    /\ mmapOldRevoked
    /\ endpointEffect' = TRUE
    /\ phase' = "EndpointEffect"
    /\ UNCHANGED <<domainSame, domainTransitionToken, schedCtxLive,
                    runContinuation, execCommitted, checkOnly,
                    processGenFresh, execGenIncremented,
                    oldFrozenEndpointUse, survivingFd, closeOnExecFd,
                    closeOnExecHandled, endpointDerivedPostExec,
                    credsChanged, lsmAttenuated, execfdInserted,
                    execfdDerived, oldAsyncUse, asyncEffect, oldMmapLive,
                    mmapOldRevoked, running, failClosed>>

AsyncEffectAfterExec ==
    /\ phase = "Running"
    /\ running
    /\ execCommitted
    /\ processGenFresh
    /\ ~oldAsyncUse
    /\ asyncEffect' = TRUE
    /\ phase' = "AsyncEffect"
    /\ UNCHANGED <<domainSame, domainTransitionToken, schedCtxLive,
                    runContinuation, execCommitted, checkOnly,
                    processGenFresh, execGenIncremented,
                    oldFrozenEndpointUse, survivingFd, closeOnExecFd,
                    closeOnExecHandled, endpointDerivedPostExec,
                    credsChanged, lsmAttenuated, execfdInserted,
                    execfdDerived, oldAsyncUse, oldMmapLive, mmapOldRevoked,
                    endpointEffect, running, failClosed>>

FailClosedOnBadDerivation ==
    /\ phase = "ExecCommitted"
    /\ execCommitted
    /\ ~endpointDerivedPostExec
    /\ failClosed' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<domainSame, domainTransitionToken, schedCtxLive,
                    runContinuation, execCommitted, checkOnly,
                    processGenFresh, execGenIncremented,
                    oldFrozenEndpointUse, survivingFd, closeOnExecFd,
                    closeOnExecHandled, endpointDerivedPostExec,
                    credsChanged, lsmAttenuated, execfdInserted,
                    execfdDerived, oldAsyncUse, asyncEffect, oldMmapLive,
                    mmapOldRevoked, endpointEffect, running>>

UnsafeDomainChangeNoToken ==
    /\ phase = "Prepared"
    /\ domainSame' = FALSE
    /\ domainTransitionToken' = FALSE
    /\ execCommitted' = TRUE
    /\ processGenFresh' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadDomainChange"
    /\ UNCHANGED <<schedCtxLive, runContinuation, checkOnly,
                    execGenIncremented, oldFrozenEndpointUse, survivingFd,
                    closeOnExecFd, closeOnExecHandled,
                    endpointDerivedPostExec, credsChanged, lsmAttenuated,
                    execfdInserted, execfdDerived, oldAsyncUse, asyncEffect,
                    oldMmapLive, mmapOldRevoked, endpointEffect, failClosed>>

UnsafeRunNoContinuation ==
    /\ phase = "ExecCommitted"
    /\ execCommitted
    /\ runContinuation' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadRunNoContinuation"
    /\ UNCHANGED <<domainSame, domainTransitionToken, schedCtxLive,
                    execCommitted, checkOnly, processGenFresh,
                    execGenIncremented, oldFrozenEndpointUse, survivingFd,
                    closeOnExecFd, closeOnExecHandled,
                    endpointDerivedPostExec, credsChanged, lsmAttenuated,
                    execfdInserted, execfdDerived, oldAsyncUse, asyncEffect,
                    oldMmapLive, mmapOldRevoked, endpointEffect, failClosed>>

UnsafeOldEndpointUse ==
    /\ phase = "Running"
    /\ running
    /\ execCommitted
    /\ oldFrozenEndpointUse' = TRUE
    /\ endpointEffect' = TRUE
    /\ phase' = "BadOldEndpointUse"
    /\ UNCHANGED <<domainSame, domainTransitionToken, schedCtxLive,
                    runContinuation, execCommitted, checkOnly,
                    processGenFresh, execGenIncremented, survivingFd,
                    closeOnExecFd, closeOnExecHandled,
                    endpointDerivedPostExec, credsChanged, lsmAttenuated,
                    execfdInserted, execfdDerived, oldAsyncUse, asyncEffect,
                    oldMmapLive, mmapOldRevoked, running, failClosed>>

UnsafeSurvivingFdNoDerive ==
    /\ phase = "Running"
    /\ running
    /\ execCommitted
    /\ survivingFd
    /\ endpointDerivedPostExec' = FALSE
    /\ endpointEffect' = TRUE
    /\ phase' = "BadFdNoDerive"
    /\ UNCHANGED <<domainSame, domainTransitionToken, schedCtxLive,
                    runContinuation, execCommitted, checkOnly,
                    processGenFresh, execGenIncremented,
                    oldFrozenEndpointUse, survivingFd, closeOnExecFd,
                    closeOnExecHandled, credsChanged, lsmAttenuated,
                    execfdInserted, execfdDerived, oldAsyncUse, asyncEffect,
                    oldMmapLive, mmapOldRevoked, running, failClosed>>

UnsafeCloseOnExecLeak ==
    /\ phase = "Running"
    /\ running
    /\ execCommitted
    /\ closeOnExecFd
    /\ closeOnExecHandled' = FALSE
    /\ endpointEffect' = TRUE
    /\ phase' = "BadCloseOnExecLeak"
    /\ UNCHANGED <<domainSame, domainTransitionToken, schedCtxLive,
                    runContinuation, execCommitted, checkOnly,
                    processGenFresh, execGenIncremented,
                    oldFrozenEndpointUse, survivingFd, closeOnExecFd,
                    endpointDerivedPostExec, credsChanged, lsmAttenuated,
                    execfdInserted, execfdDerived, oldAsyncUse, asyncEffect,
                    oldMmapLive, mmapOldRevoked, running, failClosed>>

UnsafeCredChangeNoAttenuation ==
    /\ phase = "Running"
    /\ running
    /\ execCommitted
    /\ credsChanged
    /\ lsmAttenuated' = FALSE
    /\ endpointEffect' = TRUE
    /\ phase' = "BadCredAmplify"
    /\ UNCHANGED <<domainSame, domainTransitionToken, schedCtxLive,
                    runContinuation, execCommitted, checkOnly,
                    processGenFresh, execGenIncremented,
                    oldFrozenEndpointUse, survivingFd, closeOnExecFd,
                    closeOnExecHandled, endpointDerivedPostExec, credsChanged,
                    execfdInserted, execfdDerived, oldAsyncUse, asyncEffect,
                    oldMmapLive, mmapOldRevoked, running, failClosed>>

UnsafeExecfdNoDerive ==
    /\ phase = "Running"
    /\ running
    /\ execCommitted
    /\ execfdInserted' = TRUE
    /\ execfdDerived' = FALSE
    /\ endpointEffect' = TRUE
    /\ phase' = "BadExecfdNoDerive"
    /\ UNCHANGED <<domainSame, domainTransitionToken, schedCtxLive,
                    runContinuation, execCommitted, checkOnly,
                    processGenFresh, execGenIncremented,
                    oldFrozenEndpointUse, survivingFd, closeOnExecFd,
                    closeOnExecHandled, endpointDerivedPostExec,
                    credsChanged, lsmAttenuated, oldAsyncUse, asyncEffect,
                    oldMmapLive, mmapOldRevoked, running, failClosed>>

UnsafeOldAsyncAfterExec ==
    /\ phase = "Running"
    /\ running
    /\ execCommitted
    /\ oldAsyncUse' = TRUE
    /\ asyncEffect' = TRUE
    /\ phase' = "BadOldAsyncUse"
    /\ UNCHANGED <<domainSame, domainTransitionToken, schedCtxLive,
                    runContinuation, execCommitted, checkOnly,
                    processGenFresh, execGenIncremented,
                    oldFrozenEndpointUse, survivingFd, closeOnExecFd,
                    closeOnExecHandled, endpointDerivedPostExec,
                    credsChanged, lsmAttenuated, execfdInserted,
                    execfdDerived, oldMmapLive, mmapOldRevoked,
                    endpointEffect, running, failClosed>>

UnsafeOldMmapSurvives ==
    /\ phase = "ExecCommitted"
    /\ execCommitted
    /\ oldMmapLive' = TRUE
    /\ mmapOldRevoked' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadOldMmapLive"
    /\ UNCHANGED <<domainSame, domainTransitionToken, schedCtxLive,
                    runContinuation, execCommitted, checkOnly,
                    processGenFresh, execGenIncremented,
                    oldFrozenEndpointUse, survivingFd, closeOnExecFd,
                    closeOnExecHandled, endpointDerivedPostExec,
                    credsChanged, lsmAttenuated, execfdInserted,
                    execfdDerived, oldAsyncUse, asyncEffect, endpointEffect,
                    failClosed>>

UnsafeCheckOnlyMutation ==
    /\ phase = "CheckOnly"
    /\ checkOnly
    /\ execCommitted' = TRUE
    /\ processGenFresh' = TRUE
    /\ execGenIncremented' = TRUE
    /\ phase' = "BadCheckOnlyMutation"
    /\ UNCHANGED <<domainSame, domainTransitionToken, schedCtxLive,
                    runContinuation, checkOnly, oldFrozenEndpointUse,
                    survivingFd, closeOnExecFd, closeOnExecHandled,
                    endpointDerivedPostExec, credsChanged, lsmAttenuated,
                    execfdInserted, execfdDerived, oldAsyncUse, asyncEffect,
                    oldMmapLive, mmapOldRevoked, endpointEffect, running,
                    failClosed>>

SafeNext ==
    PrepareExec \/ CheckOnlyExecPolicy \/ CommitExecNoExecfd \/
    CommitExecWithExecfd \/ RunAfterExec \/ EndpointEffectAfterExec \/
    AsyncEffectAfterExec \/ FailClosedOnBadDerivation

SafeSpec ==
    Init /\ [][SafeNext]_vars

UnsafeDomainSpec ==
    Init /\ [][SafeNext \/ UnsafeDomainChangeNoToken]_vars

UnsafeRunNoContinuationSpec ==
    Init /\ [][SafeNext \/ UnsafeRunNoContinuation]_vars

UnsafeOldEndpointSpec ==
    Init /\ [][SafeNext \/ UnsafeOldEndpointUse]_vars

UnsafeFdNoDeriveSpec ==
    Init /\ [][SafeNext \/ UnsafeSurvivingFdNoDerive]_vars

UnsafeCloseOnExecSpec ==
    Init /\ [][SafeNext \/ UnsafeCloseOnExecLeak]_vars

UnsafeCredAmplifySpec ==
    Init /\ [][SafeNext \/ UnsafeCredChangeNoAttenuation]_vars

UnsafeExecfdSpec ==
    Init /\ [][SafeNext \/ UnsafeExecfdNoDerive]_vars

UnsafeOldAsyncSpec ==
    Init /\ [][SafeNext \/ UnsafeOldAsyncAfterExec]_vars

UnsafeOldMmapSpec ==
    Init /\ [][SafeNext \/ UnsafeOldMmapSurvives]_vars

UnsafeCheckOnlySpec ==
    Init /\ [][SafeNext \/ UnsafeCheckOnlyMutation]_vars

NoExecDomainChangeWithoutToken ==
    execCommitted => domainSame \/ domainTransitionToken

NoRunAfterExecWithoutContinuation ==
    (running /\ execCommitted) =>
        runContinuation /\ schedCtxLive /\ processGenFresh

NoOldEndpointUseAfterExec ==
    (endpointEffect /\ execCommitted) => ~oldFrozenEndpointUse

NoSurvivingFdWithoutDerivation ==
    (endpointEffect /\ execCommitted /\ survivingFd) => endpointDerivedPostExec

NoCloseOnExecLeak ==
    (endpointEffect /\ execCommitted /\ closeOnExecFd) => closeOnExecHandled

NoCredChangeEndpointAmplification ==
    (endpointEffect /\ execCommitted /\ credsChanged) =>
        lsmAttenuated /\ endpointDerivedPostExec

NoExecfdWithoutDerivation ==
    (endpointEffect /\ execCommitted /\ execfdInserted) => execfdDerived

NoOldAsyncUseAfterExec ==
    (asyncEffect /\ execCommitted) => ~oldAsyncUse

NoOldMmapAcrossExec ==
    (running /\ execCommitted) => ~oldMmapLive /\ mmapOldRevoked

NoCheckOnlyMutation ==
    checkOnly => ~execCommitted /\ ~processGenFresh /\ ~execGenIncremented

=============================================================================
