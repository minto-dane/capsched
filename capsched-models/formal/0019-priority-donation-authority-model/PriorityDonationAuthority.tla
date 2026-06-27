---------------------- MODULE PriorityDonationAuthority ----------------------
EXTENDS Naturals

VARIABLES
    phase,
    endpointLive,
    endpointAuthority,
    lockWaitCap,
    priorityDonationCap,
    waiterBlocked,
    ownerHoldsLock,
    donationActive,
    ownerBoosted,
    ownerRunCap,
    ownerFrozen,
    proxyTicket,
    ownerRunning,
    lockReleased,
    woundIssued,
    threadControlUsed,
    blockedChainAcyclic,
    crossDomain

vars == <<phase, endpointLive, endpointAuthority, lockWaitCap,
          priorityDonationCap, waiterBlocked, ownerHoldsLock, donationActive,
          ownerBoosted, ownerRunCap, ownerFrozen, proxyTicket, ownerRunning,
          lockReleased, woundIssued, threadControlUsed, blockedChainAcyclic,
          crossDomain>>

Phases == {
    "Start",
    "EndpointPrepared",
    "WaiterBlocked",
    "DonationActive",
    "OwnerRunPrepared",
    "OwnerRunning",
    "Released",
    "Revoked",
    "Wounded",
    "BadDonationNoDependency",
    "BadDonationNoCap",
    "BadCrossDomainNoEndpoint",
    "BadRunNoRunCap",
    "BadRunNoBudget",
    "BadDonationAfterRelease",
    "BadWoundThreadControl",
    "BadProxyCycle"
}

TypeOK ==
    /\ phase \in Phases
    /\ endpointLive \in BOOLEAN
    /\ endpointAuthority \in BOOLEAN
    /\ lockWaitCap \in BOOLEAN
    /\ priorityDonationCap \in BOOLEAN
    /\ waiterBlocked \in BOOLEAN
    /\ ownerHoldsLock \in BOOLEAN
    /\ donationActive \in BOOLEAN
    /\ ownerBoosted \in BOOLEAN
    /\ ownerRunCap \in BOOLEAN
    /\ ownerFrozen \in BOOLEAN
    /\ proxyTicket \in BOOLEAN
    /\ ownerRunning \in BOOLEAN
    /\ lockReleased \in BOOLEAN
    /\ woundIssued \in BOOLEAN
    /\ threadControlUsed \in BOOLEAN
    /\ blockedChainAcyclic \in BOOLEAN
    /\ crossDomain \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ endpointLive = TRUE
    /\ endpointAuthority = FALSE
    /\ lockWaitCap = FALSE
    /\ priorityDonationCap = FALSE
    /\ waiterBlocked = FALSE
    /\ ownerHoldsLock = FALSE
    /\ donationActive = FALSE
    /\ ownerBoosted = FALSE
    /\ ownerRunCap = FALSE
    /\ ownerFrozen = FALSE
    /\ proxyTicket = FALSE
    /\ ownerRunning = FALSE
    /\ lockReleased = FALSE
    /\ woundIssued = FALSE
    /\ threadControlUsed = FALSE
    /\ blockedChainAcyclic = TRUE
    /\ crossDomain = TRUE

PrepareLockEndpoint ==
    /\ phase = "Start"
    /\ endpointLive
    /\ endpointAuthority' = TRUE
    /\ lockWaitCap' = TRUE
    /\ priorityDonationCap' = TRUE
    /\ ownerHoldsLock' = TRUE
    /\ phase' = "EndpointPrepared"
    /\ UNCHANGED <<endpointLive, waiterBlocked, donationActive, ownerBoosted,
                    ownerRunCap, ownerFrozen, proxyTicket, ownerRunning,
                    lockReleased, woundIssued, threadControlUsed,
                    blockedChainAcyclic, crossDomain>>

BlockWaiter ==
    /\ phase = "EndpointPrepared"
    /\ endpointLive
    /\ endpointAuthority
    /\ lockWaitCap
    /\ ownerHoldsLock
    /\ waiterBlocked' = TRUE
    /\ phase' = "WaiterBlocked"
    /\ UNCHANGED <<endpointLive, endpointAuthority, lockWaitCap,
                    priorityDonationCap, ownerHoldsLock, donationActive,
                    ownerBoosted, ownerRunCap, ownerFrozen, proxyTicket,
                    ownerRunning, lockReleased, woundIssued, threadControlUsed,
                    blockedChainAcyclic, crossDomain>>

ActivateDonation ==
    /\ phase = "WaiterBlocked"
    /\ endpointLive
    /\ endpointAuthority
    /\ waiterBlocked
    /\ ownerHoldsLock
    /\ priorityDonationCap
    /\ donationActive' = TRUE
    /\ ownerBoosted' = TRUE
    /\ phase' = "DonationActive"
    /\ UNCHANGED <<endpointLive, endpointAuthority, lockWaitCap,
                    priorityDonationCap, waiterBlocked, ownerHoldsLock,
                    ownerRunCap, ownerFrozen, proxyTicket, ownerRunning,
                    lockReleased, woundIssued, threadControlUsed,
                    blockedChainAcyclic, crossDomain>>

PrepareOwnerRun ==
    /\ phase = "DonationActive"
    /\ donationActive
    /\ ownerBoosted
    /\ ownerRunCap' = TRUE
    /\ ownerFrozen' = TRUE
    /\ proxyTicket' = TRUE
    /\ phase' = "OwnerRunPrepared"
    /\ UNCHANGED <<endpointLive, endpointAuthority, lockWaitCap,
                    priorityDonationCap, waiterBlocked, ownerHoldsLock,
                    donationActive, ownerBoosted, ownerRunning, lockReleased,
                    woundIssued, threadControlUsed, blockedChainAcyclic,
                    crossDomain>>

RunOwnerWithDonation ==
    /\ phase = "OwnerRunPrepared"
    /\ donationActive
    /\ ownerBoosted
    /\ ownerRunCap
    /\ ownerFrozen
    /\ proxyTicket
    /\ ownerRunning' = TRUE
    /\ phase' = "OwnerRunning"
    /\ UNCHANGED <<endpointLive, endpointAuthority, lockWaitCap,
                    priorityDonationCap, waiterBlocked, ownerHoldsLock,
                    donationActive, ownerBoosted, ownerRunCap, ownerFrozen,
                    proxyTicket, lockReleased, woundIssued, threadControlUsed,
                    blockedChainAcyclic, crossDomain>>

ReleaseLock ==
    /\ phase \in {"WaiterBlocked", "DonationActive", "OwnerRunPrepared",
                  "OwnerRunning", "Wounded"}
    /\ ownerHoldsLock
    /\ ownerHoldsLock' = FALSE
    /\ lockReleased' = TRUE
    /\ waiterBlocked' = FALSE
    /\ donationActive' = FALSE
    /\ ownerBoosted' = FALSE
    /\ ownerRunning' = FALSE
    /\ proxyTicket' = FALSE
    /\ phase' = "Released"
    /\ UNCHANGED <<endpointLive, endpointAuthority, lockWaitCap,
                    priorityDonationCap, ownerRunCap, ownerFrozen, woundIssued,
                    threadControlUsed, blockedChainAcyclic, crossDomain>>

RevokeEndpoint ==
    /\ phase \in {"EndpointPrepared", "WaiterBlocked", "DonationActive",
                  "OwnerRunPrepared", "OwnerRunning", "Wounded"}
    /\ endpointLive
    /\ endpointLive' = FALSE
    /\ endpointAuthority' = FALSE
    /\ lockWaitCap' = FALSE
    /\ priorityDonationCap' = FALSE
    /\ waiterBlocked' = FALSE
    /\ donationActive' = FALSE
    /\ ownerBoosted' = FALSE
    /\ ownerRunning' = FALSE
    /\ proxyTicket' = FALSE
    /\ phase' = "Revoked"
    /\ UNCHANGED <<ownerHoldsLock, ownerRunCap, ownerFrozen, lockReleased,
                    woundIssued, threadControlUsed, blockedChainAcyclic,
                    crossDomain>>

WoundWaiter ==
    /\ phase = "WaiterBlocked"
    /\ endpointLive
    /\ endpointAuthority
    /\ waiterBlocked
    /\ woundIssued' = TRUE
    /\ threadControlUsed' = FALSE
    /\ phase' = "Wounded"
    /\ UNCHANGED <<endpointLive, endpointAuthority, lockWaitCap,
                    priorityDonationCap, waiterBlocked, ownerHoldsLock,
                    donationActive, ownerBoosted, ownerRunCap, ownerFrozen,
                    proxyTicket, ownerRunning, lockReleased,
                    blockedChainAcyclic, crossDomain>>

UnsafeDonationNoDependency ==
    /\ phase = "Start"
    /\ donationActive' = TRUE
    /\ ownerBoosted' = TRUE
    /\ phase' = "BadDonationNoDependency"
    /\ UNCHANGED <<endpointLive, endpointAuthority, lockWaitCap,
                    priorityDonationCap, waiterBlocked, ownerHoldsLock,
                    ownerRunCap, ownerFrozen, proxyTicket, ownerRunning,
                    lockReleased, woundIssued, threadControlUsed,
                    blockedChainAcyclic, crossDomain>>

UnsafeDonationNoCap ==
    /\ phase = "WaiterBlocked"
    /\ waiterBlocked
    /\ ownerHoldsLock
    /\ priorityDonationCap' = FALSE
    /\ donationActive' = TRUE
    /\ ownerBoosted' = TRUE
    /\ phase' = "BadDonationNoCap"
    /\ UNCHANGED <<endpointLive, endpointAuthority, lockWaitCap, waiterBlocked,
                    ownerHoldsLock, ownerRunCap, ownerFrozen, proxyTicket,
                    ownerRunning, lockReleased, woundIssued, threadControlUsed,
                    blockedChainAcyclic, crossDomain>>

UnsafeCrossDomainNoEndpoint ==
    /\ phase = "Start"
    /\ crossDomain
    /\ endpointLive
    /\ endpointAuthority' = FALSE
    /\ lockWaitCap' = FALSE
    /\ priorityDonationCap' = TRUE
    /\ waiterBlocked' = TRUE
    /\ ownerHoldsLock' = TRUE
    /\ donationActive' = TRUE
    /\ ownerBoosted' = TRUE
    /\ phase' = "BadCrossDomainNoEndpoint"
    /\ UNCHANGED <<endpointLive, ownerRunCap, ownerFrozen, proxyTicket,
                    ownerRunning, lockReleased, woundIssued, threadControlUsed,
                    blockedChainAcyclic, crossDomain>>

UnsafeRunWithoutRunCap ==
    /\ phase = "DonationActive"
    /\ donationActive
    /\ ownerBoosted
    /\ ownerRunCap' = FALSE
    /\ ownerFrozen' = FALSE
    /\ proxyTicket' = TRUE
    /\ ownerRunning' = TRUE
    /\ phase' = "BadRunNoRunCap"
    /\ UNCHANGED <<endpointLive, endpointAuthority, lockWaitCap,
                    priorityDonationCap, waiterBlocked, ownerHoldsLock,
                    donationActive, ownerBoosted, lockReleased, woundIssued,
                    threadControlUsed, blockedChainAcyclic, crossDomain>>

UnsafeRunWithoutBudget ==
    /\ phase = "DonationActive"
    /\ donationActive
    /\ ownerBoosted
    /\ ownerRunCap' = TRUE
    /\ ownerFrozen' = TRUE
    /\ proxyTicket' = FALSE
    /\ ownerRunning' = TRUE
    /\ phase' = "BadRunNoBudget"
    /\ UNCHANGED <<endpointLive, endpointAuthority, lockWaitCap,
                    priorityDonationCap, waiterBlocked, ownerHoldsLock,
                    donationActive, ownerBoosted, lockReleased, woundIssued,
                    threadControlUsed, blockedChainAcyclic, crossDomain>>

UnsafeDonationAfterRelease ==
    /\ phase = "DonationActive"
    /\ donationActive
    /\ ownerBoosted
    /\ ownerHoldsLock' = FALSE
    /\ lockReleased' = TRUE
    /\ donationActive' = TRUE
    /\ phase' = "BadDonationAfterRelease"
    /\ UNCHANGED <<endpointLive, endpointAuthority, lockWaitCap,
                    priorityDonationCap, waiterBlocked, ownerBoosted,
                    ownerRunCap, ownerFrozen, proxyTicket, ownerRunning,
                    woundIssued, threadControlUsed, blockedChainAcyclic,
                    crossDomain>>

UnsafeWoundThreadControl ==
    /\ phase = "WaiterBlocked"
    /\ waiterBlocked
    /\ woundIssued' = TRUE
    /\ threadControlUsed' = TRUE
    /\ phase' = "BadWoundThreadControl"
    /\ UNCHANGED <<endpointLive, endpointAuthority, lockWaitCap,
                    priorityDonationCap, waiterBlocked, ownerHoldsLock,
                    donationActive, ownerBoosted, ownerRunCap, ownerFrozen,
                    proxyTicket, ownerRunning, lockReleased,
                    blockedChainAcyclic, crossDomain>>

UnsafeProxyCycle ==
    /\ phase = "DonationActive"
    /\ blockedChainAcyclic' = FALSE
    /\ phase' = "BadProxyCycle"
    /\ UNCHANGED <<endpointLive, endpointAuthority, lockWaitCap,
                    priorityDonationCap, waiterBlocked, ownerHoldsLock,
                    donationActive, ownerBoosted, ownerRunCap, ownerFrozen,
                    proxyTicket, ownerRunning, lockReleased, woundIssued,
                    threadControlUsed, crossDomain>>

SafeNext ==
    \/ PrepareLockEndpoint
    \/ BlockWaiter
    \/ ActivateDonation
    \/ PrepareOwnerRun
    \/ RunOwnerWithDonation
    \/ ReleaseLock
    \/ RevokeEndpoint
    \/ WoundWaiter

SafeSpec == Init /\ [][SafeNext]_vars

UnsafeNoDependencySpec ==
    Init /\ [][SafeNext \/ UnsafeDonationNoDependency]_vars

UnsafeNoDonationCapSpec ==
    Init /\ [][SafeNext \/ UnsafeDonationNoCap]_vars

UnsafeCrossDomainNoEndpointSpec ==
    Init /\ [][SafeNext \/ UnsafeCrossDomainNoEndpoint]_vars

UnsafeRunNoRunCapSpec ==
    Init /\ [][SafeNext \/ UnsafeRunWithoutRunCap]_vars

UnsafeRunNoBudgetSpec ==
    Init /\ [][SafeNext \/ UnsafeRunWithoutBudget]_vars

UnsafeDonationAfterReleaseSpec ==
    Init /\ [][SafeNext \/ UnsafeDonationAfterRelease]_vars

UnsafeWoundThreadControlSpec ==
    Init /\ [][SafeNext \/ UnsafeWoundThreadControl]_vars

UnsafeProxyCycleSpec ==
    Init /\ [][SafeNext \/ UnsafeProxyCycle]_vars

NoDonationWithoutBlockedDependency ==
    donationActive => waiterBlocked /\ ownerHoldsLock

NoDonationWithoutDonationCap ==
    donationActive => priorityDonationCap

NoCrossDomainDonationWithoutEndpoint ==
    (donationActive /\ crossDomain) => endpointLive /\ endpointAuthority /\ lockWaitCap

NoDonationCreatesRunAuthority ==
    ownerRunning => ownerRunCap /\ ownerFrozen

NoDonationCreatesBudget ==
    ownerRunning => proxyTicket

NoDonationAfterUnlockOrRevoke ==
    donationActive => ~lockReleased /\ endpointLive

NoWoundAsThreadControl ==
    woundIssued => ~threadControlUsed

NoProxyChainCycle ==
    blockedChainAcyclic

=============================================================================
