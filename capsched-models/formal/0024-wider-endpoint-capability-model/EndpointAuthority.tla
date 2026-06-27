----------------------- MODULE EndpointAuthority -----------------------
EXTENDS Naturals

VARIABLES
    phase,
    path,
    basis,
    handle,
    fdLookup,
    frozenUse,
    opSpecific,
    subjectFresh,
    endpointFresh,
    generationFresh,
    lsmAllowed,
    nosecFastPath,
    running,
    derivedForReceiver,
    transferRight,
    receiverFresh,
    asyncQueued,
    workerAmbientOnly,
    budgetTicket,
    revoked,
    mmapUse,
    mmapCap,
    ioctlUse,
    ioctlTyped,
    genericFdAuthority,
    failClosed

vars == <<phase, path, basis, handle, fdLookup, frozenUse, opSpecific,
          subjectFresh, endpointFresh, generationFresh, lsmAllowed,
          nosecFastPath, running, derivedForReceiver, transferRight,
          receiverFresh, asyncQueued, workerAmbientOnly, budgetTicket,
          revoked, mmapUse, mmapCap, ioctlUse, ioctlTyped,
          genericFdAuthority, failClosed>>

Paths == {
    "None",
    "ReadWrite",
    "Socket",
    "Mmap",
    "Ioctl",
    "Transfer",
    "AsyncWorker"
}

Phases == {
    "Start",
    "BasisCreated",
    "LookedUp",
    "Frozen",
    "Derived",
    "AsyncQueued",
    "Running",
    "FailClosed",
    "BadFdLookupAuthority",
    "BadOpenBasisAllOps",
    "BadNoSecBypass",
    "BadTransferNoDerive",
    "BadAsyncAmbientWorker",
    "BadRevokedUse",
    "BadMmapReadCap",
    "BadIoctlGenericFd"
}

TypeOK ==
    /\ phase \in Phases
    /\ path \in Paths
    /\ basis \in BOOLEAN
    /\ handle \in BOOLEAN
    /\ fdLookup \in BOOLEAN
    /\ frozenUse \in BOOLEAN
    /\ opSpecific \in BOOLEAN
    /\ subjectFresh \in BOOLEAN
    /\ endpointFresh \in BOOLEAN
    /\ generationFresh \in BOOLEAN
    /\ lsmAllowed \in BOOLEAN
    /\ nosecFastPath \in BOOLEAN
    /\ running \in BOOLEAN
    /\ derivedForReceiver \in BOOLEAN
    /\ transferRight \in BOOLEAN
    /\ receiverFresh \in BOOLEAN
    /\ asyncQueued \in BOOLEAN
    /\ workerAmbientOnly \in BOOLEAN
    /\ budgetTicket \in BOOLEAN
    /\ revoked \in BOOLEAN
    /\ mmapUse \in BOOLEAN
    /\ mmapCap \in BOOLEAN
    /\ ioctlUse \in BOOLEAN
    /\ ioctlTyped \in BOOLEAN
    /\ genericFdAuthority \in BOOLEAN
    /\ failClosed \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ path = "None"
    /\ basis = FALSE
    /\ handle = FALSE
    /\ fdLookup = FALSE
    /\ frozenUse = FALSE
    /\ opSpecific = FALSE
    /\ subjectFresh = FALSE
    /\ endpointFresh = FALSE
    /\ generationFresh = FALSE
    /\ lsmAllowed = FALSE
    /\ nosecFastPath = FALSE
    /\ running = FALSE
    /\ derivedForReceiver = FALSE
    /\ transferRight = FALSE
    /\ receiverFresh = FALSE
    /\ asyncQueued = FALSE
    /\ workerAmbientOnly = FALSE
    /\ budgetTicket = FALSE
    /\ revoked = FALSE
    /\ mmapUse = FALSE
    /\ mmapCap = FALSE
    /\ ioctlUse = FALSE
    /\ ioctlTyped = FALSE
    /\ genericFdAuthority = FALSE
    /\ failClosed = FALSE

CreateEndpointBasis ==
    /\ phase = "Start"
    /\ basis' = TRUE
    /\ handle' = TRUE
    /\ subjectFresh' = TRUE
    /\ endpointFresh' = TRUE
    /\ generationFresh' = TRUE
    /\ lsmAllowed' = TRUE
    /\ phase' = "BasisCreated"
    /\ UNCHANGED <<path, fdLookup, frozenUse, opSpecific, nosecFastPath,
                    running, derivedForReceiver, transferRight,
                    receiverFresh, asyncQueued, workerAmbientOnly,
                    budgetTicket, revoked, mmapUse, mmapCap, ioctlUse,
                    ioctlTyped, genericFdAuthority, failClosed>>

LookupFd ==
    /\ phase = "BasisCreated"
    /\ basis
    /\ handle
    /\ fdLookup' = TRUE
    /\ phase' = "LookedUp"
    /\ UNCHANGED <<path, basis, handle, frozenUse, opSpecific, subjectFresh,
                    endpointFresh, generationFresh, lsmAllowed,
                    nosecFastPath, running, derivedForReceiver,
                    transferRight, receiverFresh, asyncQueued,
                    workerAmbientOnly, budgetTicket, revoked, mmapUse,
                    mmapCap, ioctlUse, ioctlTyped, genericFdAuthority,
                    failClosed>>

FreezeReadWriteUse ==
    /\ phase = "LookedUp"
    /\ basis
    /\ handle
    /\ fdLookup
    /\ subjectFresh
    /\ endpointFresh
    /\ generationFresh
    /\ lsmAllowed
    /\ frozenUse' = TRUE
    /\ opSpecific' = TRUE
    /\ path' = "ReadWrite"
    /\ phase' = "Frozen"
    /\ UNCHANGED <<basis, handle, fdLookup, subjectFresh, endpointFresh,
                    generationFresh, lsmAllowed, nosecFastPath, running,
                    derivedForReceiver, transferRight, receiverFresh,
                    asyncQueued, workerAmbientOnly, budgetTicket, revoked,
                    mmapUse, mmapCap, ioctlUse, ioctlTyped,
                    genericFdAuthority, failClosed>>

FreezeSocketNoSecUse ==
    /\ phase = "LookedUp"
    /\ basis
    /\ handle
    /\ fdLookup
    /\ subjectFresh
    /\ endpointFresh
    /\ generationFresh
    /\ lsmAllowed
    /\ frozenUse' = TRUE
    /\ opSpecific' = TRUE
    /\ nosecFastPath' = TRUE
    /\ path' = "Socket"
    /\ phase' = "Frozen"
    /\ UNCHANGED <<basis, handle, fdLookup, subjectFresh, endpointFresh,
                    generationFresh, lsmAllowed, running,
                    derivedForReceiver, transferRight, receiverFresh,
                    asyncQueued, workerAmbientOnly, budgetTicket, revoked,
                    mmapUse, mmapCap, ioctlUse, ioctlTyped,
                    genericFdAuthority, failClosed>>

FreezeMmapUse ==
    /\ phase = "LookedUp"
    /\ basis
    /\ handle
    /\ fdLookup
    /\ subjectFresh
    /\ endpointFresh
    /\ generationFresh
    /\ frozenUse' = TRUE
    /\ opSpecific' = TRUE
    /\ mmapUse' = TRUE
    /\ mmapCap' = TRUE
    /\ path' = "Mmap"
    /\ phase' = "Frozen"
    /\ UNCHANGED <<basis, handle, fdLookup, subjectFresh, endpointFresh,
                    generationFresh, lsmAllowed, nosecFastPath, running,
                    derivedForReceiver, transferRight, receiverFresh,
                    asyncQueued, workerAmbientOnly, budgetTicket, revoked,
                    ioctlUse, ioctlTyped, genericFdAuthority, failClosed>>

FreezeIoctlUse ==
    /\ phase = "LookedUp"
    /\ basis
    /\ handle
    /\ fdLookup
    /\ subjectFresh
    /\ endpointFresh
    /\ generationFresh
    /\ frozenUse' = TRUE
    /\ opSpecific' = TRUE
    /\ ioctlUse' = TRUE
    /\ ioctlTyped' = TRUE
    /\ path' = "Ioctl"
    /\ phase' = "Frozen"
    /\ UNCHANGED <<basis, handle, fdLookup, subjectFresh, endpointFresh,
                    generationFresh, lsmAllowed, nosecFastPath, running,
                    derivedForReceiver, transferRight, receiverFresh,
                    asyncQueued, workerAmbientOnly, budgetTicket, revoked,
                    mmapUse, mmapCap, genericFdAuthority, failClosed>>

DeriveForReceiver ==
    /\ phase \in {"BasisCreated", "LookedUp"}
    /\ basis
    /\ handle
    /\ subjectFresh
    /\ endpointFresh
    /\ generationFresh
    /\ derivedForReceiver' = TRUE
    /\ transferRight' = TRUE
    /\ receiverFresh' = TRUE
    /\ path' = "Transfer"
    /\ phase' = "Derived"
    /\ UNCHANGED <<basis, handle, fdLookup, frozenUse, opSpecific,
                    subjectFresh, endpointFresh, generationFresh, lsmAllowed,
                    nosecFastPath, running, asyncQueued, workerAmbientOnly,
                    budgetTicket, revoked, mmapUse, mmapCap, ioctlUse,
                    ioctlTyped, genericFdAuthority, failClosed>>

FreezeReceiverUse ==
    /\ phase = "Derived"
    /\ basis
    /\ handle
    /\ derivedForReceiver
    /\ transferRight
    /\ receiverFresh
    /\ subjectFresh
    /\ endpointFresh
    /\ generationFresh
    /\ frozenUse' = TRUE
    /\ opSpecific' = TRUE
    /\ phase' = "Frozen"
    /\ UNCHANGED <<path, basis, handle, fdLookup, subjectFresh,
                    endpointFresh, generationFresh, lsmAllowed,
                    nosecFastPath, running, derivedForReceiver,
                    transferRight, receiverFresh, asyncQueued,
                    workerAmbientOnly, budgetTicket, revoked, mmapUse,
                    mmapCap, ioctlUse, ioctlTyped, genericFdAuthority,
                    failClosed>>

QueueAsyncEndpointUse ==
    /\ phase = "Frozen"
    /\ frozenUse
    /\ opSpecific
    /\ subjectFresh
    /\ endpointFresh
    /\ generationFresh
    /\ asyncQueued' = TRUE
    /\ budgetTicket' = TRUE
    /\ path' = "AsyncWorker"
    /\ phase' = "AsyncQueued"
    /\ UNCHANGED <<basis, handle, fdLookup, frozenUse, opSpecific,
                    subjectFresh, endpointFresh, generationFresh, lsmAllowed,
                    nosecFastPath, running, derivedForReceiver,
                    transferRight, receiverFresh, workerAmbientOnly, revoked,
                    mmapUse, mmapCap, ioctlUse, ioctlTyped,
                    genericFdAuthority, failClosed>>

RunFrozenOperation ==
    /\ phase = "Frozen"
    /\ frozenUse
    /\ opSpecific
    /\ subjectFresh
    /\ endpointFresh
    /\ generationFresh
    /\ ~revoked
    /\ ~(mmapUse /\ ~mmapCap)
    /\ ~(ioctlUse /\ ~ioctlTyped)
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<path, basis, handle, fdLookup, frozenUse, opSpecific,
                    subjectFresh, endpointFresh, generationFresh, lsmAllowed,
                    nosecFastPath, derivedForReceiver, transferRight,
                    receiverFresh, asyncQueued, workerAmbientOnly,
                    budgetTicket, revoked, mmapUse, mmapCap, ioctlUse,
                    ioctlTyped, genericFdAuthority, failClosed>>

RunAsyncWorker ==
    /\ phase = "AsyncQueued"
    /\ frozenUse
    /\ opSpecific
    /\ subjectFresh
    /\ endpointFresh
    /\ generationFresh
    /\ budgetTicket
    /\ ~workerAmbientOnly
    /\ ~revoked
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<path, basis, handle, fdLookup, frozenUse, opSpecific,
                    subjectFresh, endpointFresh, generationFresh, lsmAllowed,
                    nosecFastPath, derivedForReceiver, transferRight,
                    receiverFresh, asyncQueued, workerAmbientOnly,
                    budgetTicket, revoked, mmapUse, mmapCap, ioctlUse,
                    ioctlTyped, genericFdAuthority, failClosed>>

RevokeCloses ==
    /\ phase \in {"BasisCreated", "LookedUp", "Frozen", "Derived",
                  "AsyncQueued", "Running"}
    /\ endpointFresh
    /\ endpointFresh' = FALSE
    /\ frozenUse' = FALSE
    /\ opSpecific' = FALSE
    /\ running' = FALSE
    /\ asyncQueued' = FALSE
    /\ budgetTicket' = FALSE
    /\ revoked' = TRUE
    /\ failClosed' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<path, basis, handle, fdLookup, subjectFresh,
                    generationFresh, lsmAllowed, nosecFastPath,
                    derivedForReceiver, transferRight, receiverFresh,
                    workerAmbientOnly, mmapUse, mmapCap, ioctlUse,
                    ioctlTyped, genericFdAuthority>>

UnsafeFdLookupAuthority ==
    /\ phase = "LookedUp"
    /\ fdLookup
    /\ frozenUse' = FALSE
    /\ genericFdAuthority' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadFdLookupAuthority"
    /\ UNCHANGED <<path, basis, handle, fdLookup, opSpecific, subjectFresh,
                    endpointFresh, generationFresh, lsmAllowed,
                    nosecFastPath, derivedForReceiver, transferRight,
                    receiverFresh, asyncQueued, workerAmbientOnly,
                    budgetTicket, revoked, mmapUse, mmapCap, ioctlUse,
                    ioctlTyped, failClosed>>

UnsafeOpenBasisAllOps ==
    /\ phase = "BasisCreated"
    /\ basis
    /\ handle
    /\ opSpecific' = FALSE
    /\ genericFdAuthority' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadOpenBasisAllOps"
    /\ UNCHANGED <<path, basis, handle, fdLookup, frozenUse, subjectFresh,
                    endpointFresh, generationFresh, lsmAllowed,
                    nosecFastPath, derivedForReceiver, transferRight,
                    receiverFresh, asyncQueued, workerAmbientOnly,
                    budgetTicket, revoked, mmapUse, mmapCap, ioctlUse,
                    ioctlTyped, failClosed>>

UnsafeNoSecBypass ==
    /\ phase = "LookedUp"
    /\ basis
    /\ handle
    /\ fdLookup
    /\ frozenUse' = FALSE
    /\ opSpecific' = FALSE
    /\ nosecFastPath' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadNoSecBypass"
    /\ UNCHANGED <<path, basis, handle, fdLookup, subjectFresh,
                    endpointFresh, generationFresh, lsmAllowed,
                    derivedForReceiver, transferRight, receiverFresh,
                    asyncQueued, workerAmbientOnly, budgetTicket, revoked,
                    mmapUse, mmapCap, ioctlUse, ioctlTyped,
                    genericFdAuthority, failClosed>>

UnsafeTransferNoDerive ==
    /\ phase = "BasisCreated"
    /\ basis
    /\ handle
    /\ derivedForReceiver' = TRUE
    /\ transferRight' = FALSE
    /\ receiverFresh' = TRUE
    /\ frozenUse' = TRUE
    /\ opSpecific' = TRUE
    /\ running' = TRUE
    /\ path' = "Transfer"
    /\ phase' = "BadTransferNoDerive"
    /\ UNCHANGED <<basis, handle, fdLookup, subjectFresh, endpointFresh,
                    generationFresh, lsmAllowed, nosecFastPath, asyncQueued,
                    workerAmbientOnly, budgetTicket, revoked, mmapUse,
                    mmapCap, ioctlUse, ioctlTyped, genericFdAuthority,
                    failClosed>>

UnsafeAsyncAmbientWorker ==
    /\ phase = "Frozen"
    /\ frozenUse
    /\ opSpecific
    /\ asyncQueued' = TRUE
    /\ workerAmbientOnly' = TRUE
    /\ budgetTicket' = FALSE
    /\ running' = TRUE
    /\ path' = "AsyncWorker"
    /\ phase' = "BadAsyncAmbientWorker"
    /\ UNCHANGED <<basis, handle, fdLookup, frozenUse, opSpecific,
                    subjectFresh, endpointFresh, generationFresh, lsmAllowed,
                    nosecFastPath, derivedForReceiver, transferRight,
                    receiverFresh, revoked, mmapUse, mmapCap, ioctlUse,
                    ioctlTyped, genericFdAuthority, failClosed>>

UnsafeRevokedQueuedExec ==
    /\ phase = "Frozen"
    /\ frozenUse
    /\ opSpecific
    /\ endpointFresh' = FALSE
    /\ revoked' = TRUE
    /\ asyncQueued' = TRUE
    /\ budgetTicket' = TRUE
    /\ running' = TRUE
    /\ path' = "AsyncWorker"
    /\ phase' = "BadRevokedUse"
    /\ UNCHANGED <<basis, handle, fdLookup, frozenUse, opSpecific,
                    subjectFresh, generationFresh, lsmAllowed,
                    nosecFastPath, derivedForReceiver, transferRight,
                    receiverFresh, workerAmbientOnly, mmapUse, mmapCap,
                    ioctlUse, ioctlTyped, genericFdAuthority, failClosed>>

UnsafeMmapReadCapOnly ==
    /\ phase = "LookedUp"
    /\ basis
    /\ handle
    /\ fdLookup
    /\ frozenUse' = TRUE
    /\ opSpecific' = TRUE
    /\ mmapUse' = TRUE
    /\ mmapCap' = FALSE
    /\ running' = TRUE
    /\ path' = "Mmap"
    /\ phase' = "BadMmapReadCap"
    /\ UNCHANGED <<basis, handle, fdLookup, subjectFresh, endpointFresh,
                    generationFresh, lsmAllowed, nosecFastPath,
                    derivedForReceiver, transferRight, receiverFresh,
                    asyncQueued, workerAmbientOnly, budgetTicket, revoked,
                    ioctlUse, ioctlTyped, genericFdAuthority, failClosed>>

UnsafeIoctlGenericFd ==
    /\ phase = "LookedUp"
    /\ basis
    /\ handle
    /\ fdLookup
    /\ frozenUse' = TRUE
    /\ opSpecific' = TRUE
    /\ ioctlUse' = TRUE
    /\ ioctlTyped' = FALSE
    /\ genericFdAuthority' = TRUE
    /\ running' = TRUE
    /\ path' = "Ioctl"
    /\ phase' = "BadIoctlGenericFd"
    /\ UNCHANGED <<basis, handle, fdLookup, subjectFresh, endpointFresh,
                    generationFresh, lsmAllowed, nosecFastPath,
                    derivedForReceiver, transferRight, receiverFresh,
                    asyncQueued, workerAmbientOnly, budgetTicket, revoked,
                    mmapUse, mmapCap, failClosed>>

SafeNext ==
    CreateEndpointBasis \/ LookupFd \/ FreezeReadWriteUse \/
    FreezeSocketNoSecUse \/ FreezeMmapUse \/ FreezeIoctlUse \/
    DeriveForReceiver \/ FreezeReceiverUse \/ QueueAsyncEndpointUse \/
    RunFrozenOperation \/ RunAsyncWorker \/ RevokeCloses

SafeSpec ==
    Init /\ [][SafeNext]_vars

UnsafeFdLookupSpec ==
    Init /\ [][SafeNext \/ UnsafeFdLookupAuthority]_vars

UnsafeOpenBasisSpec ==
    Init /\ [][SafeNext \/ UnsafeOpenBasisAllOps]_vars

UnsafeNoSecSpec ==
    Init /\ [][SafeNext \/ UnsafeNoSecBypass]_vars

UnsafeTransferSpec ==
    Init /\ [][SafeNext \/ UnsafeTransferNoDerive]_vars

UnsafeAsyncAmbientSpec ==
    Init /\ [][SafeNext \/ UnsafeAsyncAmbientWorker]_vars

UnsafeRevokedUseSpec ==
    Init /\ [][SafeNext \/ UnsafeRevokedQueuedExec]_vars

UnsafeMmapSpec ==
    Init /\ [][SafeNext \/ UnsafeMmapReadCapOnly]_vars

UnsafeIoctlSpec ==
    Init /\ [][SafeNext \/ UnsafeIoctlGenericFd]_vars

NoOperationWithoutFrozenEndpointUse ==
    running => frozenUse

NoFdLookupAsAuthority ==
    running => ~genericFdAuthority

NoOpenBasisAsOperationAuthority ==
    running => opSpecific

NoRunWithStaleEndpointEpoch ==
    running => subjectFresh /\ endpointFresh /\ generationFresh /\ ~revoked

NoNoSecBypass ==
    (running /\ nosecFastPath) => frozenUse /\ opSpecific

NoTransferWithoutDerivation ==
    (running /\ derivedForReceiver) => transferRight /\ receiverFresh

NoWorkerAmbientEndpointExec ==
    (running /\ asyncQueued) =>
        frozenUse /\ opSpecific /\ budgetTicket /\ ~workerAmbientOnly

NoMmapWithoutMmapCap ==
    (running /\ mmapUse) => mmapCap

NoIoctlWithoutTypedCommandCap ==
    (running /\ ioctlUse) => ioctlTyped

=============================================================================
