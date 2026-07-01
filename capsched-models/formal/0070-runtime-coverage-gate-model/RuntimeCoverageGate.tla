------------------------ MODULE RuntimeCoverageGate ------------------------
EXTENDS Naturals

VARIABLES
    phase,
    currentObserved,
    donorObserved,
    proxyCase,
    proxyRelationObserved,
    serverCase,
    serverLifecycleObserved,
    serverRuntimeObserved,
    serverEpochObserved,
    classSurfaceObserved,
    evidenceClassTagged,
    traceOnly,
    remoteTickOnly,
    schedStatOnly,
    authorityClaim,
    enforcementClaim,
    protectionClaim,
    accepted,
    failClosed

vars == <<phase, currentObserved, donorObserved, proxyCase,
          proxyRelationObserved, serverCase, serverLifecycleObserved,
          serverRuntimeObserved, serverEpochObserved, classSurfaceObserved,
          evidenceClassTagged, traceOnly, remoteTickOnly, schedStatOnly,
          authorityClaim, enforcementClaim, protectionClaim, accepted,
          failClosed>>

Phases == {
    "Start",
    "CurrentDonorCollected",
    "ProxyCollected",
    "ServerCollected",
    "Classified",
    "Accepted",
    "FailClosed",
    "BadMissingCurrent",
    "BadMissingDonor",
    "BadMissingProxyRelation",
    "BadMissingServerCoverage",
    "BadMissingEvidenceClass",
    "BadSchedStatAuthority",
    "BadRemoteTickProxyCoverage",
    "BadTraceProtection",
    "BadServerLifecycleOnly",
    "BadClassRuntimeRoot"
}

TypeOK ==
    /\ phase \in Phases
    /\ currentObserved \in BOOLEAN
    /\ donorObserved \in BOOLEAN
    /\ proxyCase \in BOOLEAN
    /\ proxyRelationObserved \in BOOLEAN
    /\ serverCase \in BOOLEAN
    /\ serverLifecycleObserved \in BOOLEAN
    /\ serverRuntimeObserved \in BOOLEAN
    /\ serverEpochObserved \in BOOLEAN
    /\ classSurfaceObserved \in BOOLEAN
    /\ evidenceClassTagged \in BOOLEAN
    /\ traceOnly \in BOOLEAN
    /\ remoteTickOnly \in BOOLEAN
    /\ schedStatOnly \in BOOLEAN
    /\ authorityClaim \in BOOLEAN
    /\ enforcementClaim \in BOOLEAN
    /\ protectionClaim \in BOOLEAN
    /\ accepted \in BOOLEAN
    /\ failClosed \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ currentObserved = FALSE
    /\ donorObserved = FALSE
    /\ proxyCase = FALSE
    /\ proxyRelationObserved = FALSE
    /\ serverCase = FALSE
    /\ serverLifecycleObserved = FALSE
    /\ serverRuntimeObserved = FALSE
    /\ serverEpochObserved = FALSE
    /\ classSurfaceObserved = FALSE
    /\ evidenceClassTagged = FALSE
    /\ traceOnly = FALSE
    /\ remoteTickOnly = FALSE
    /\ schedStatOnly = FALSE
    /\ authorityClaim = FALSE
    /\ enforcementClaim = FALSE
    /\ protectionClaim = FALSE
    /\ accepted = FALSE
    /\ failClosed = FALSE

CollectCurrentDonor(p, s) ==
    /\ phase = "Start"
    /\ p \in BOOLEAN
    /\ s \in BOOLEAN
    /\ currentObserved' = TRUE
    /\ donorObserved' = TRUE
    /\ proxyCase' = p
    /\ serverCase' = s
    /\ classSurfaceObserved' = TRUE
    /\ evidenceClassTagged' = TRUE
    /\ traceOnly' = TRUE
    /\ phase' = "CurrentDonorCollected"
    /\ UNCHANGED <<proxyRelationObserved, serverLifecycleObserved,
                    serverRuntimeObserved, serverEpochObserved,
                    remoteTickOnly, schedStatOnly, authorityClaim,
                    enforcementClaim, protectionClaim, accepted, failClosed>>

CollectProxyRelation ==
    /\ phase = "CurrentDonorCollected"
    /\ proxyCase
    /\ proxyRelationObserved' = TRUE
    /\ phase' = "ProxyCollected"
    /\ UNCHANGED <<currentObserved, donorObserved, proxyCase, serverCase,
                    serverLifecycleObserved, serverRuntimeObserved,
                    serverEpochObserved, classSurfaceObserved,
                    evidenceClassTagged, traceOnly, remoteTickOnly,
                    schedStatOnly, authorityClaim, enforcementClaim,
                    protectionClaim, accepted, failClosed>>

SkipNoProxy ==
    /\ phase = "CurrentDonorCollected"
    /\ ~proxyCase
    /\ phase' = "ProxyCollected"
    /\ UNCHANGED <<currentObserved, donorObserved, proxyCase,
                    proxyRelationObserved, serverCase, serverLifecycleObserved,
                    serverRuntimeObserved, serverEpochObserved,
                    classSurfaceObserved, evidenceClassTagged, traceOnly,
                    remoteTickOnly, schedStatOnly, authorityClaim,
                    enforcementClaim, protectionClaim, accepted, failClosed>>

CollectServerCoverage ==
    /\ phase = "ProxyCollected"
    /\ serverCase
    /\ serverLifecycleObserved' = TRUE
    /\ serverRuntimeObserved' = TRUE
    /\ serverEpochObserved' = TRUE
    /\ phase' = "ServerCollected"
    /\ UNCHANGED <<currentObserved, donorObserved, proxyCase,
                    proxyRelationObserved, serverCase, classSurfaceObserved,
                    evidenceClassTagged, traceOnly, remoteTickOnly,
                    schedStatOnly, authorityClaim, enforcementClaim,
                    protectionClaim, accepted, failClosed>>

SkipNoServer ==
    /\ phase = "ProxyCollected"
    /\ ~serverCase
    /\ phase' = "ServerCollected"
    /\ UNCHANGED <<currentObserved, donorObserved, proxyCase,
                    proxyRelationObserved, serverCase, serverLifecycleObserved,
                    serverRuntimeObserved, serverEpochObserved,
                    classSurfaceObserved, evidenceClassTagged, traceOnly,
                    remoteTickOnly, schedStatOnly, authorityClaim,
                    enforcementClaim, protectionClaim, accepted, failClosed>>

ClassifyCoverage ==
    /\ phase = "ServerCollected"
    /\ evidenceClassTagged
    /\ traceOnly
    /\ phase' = "Classified"
    /\ UNCHANGED <<currentObserved, donorObserved, proxyCase,
                    proxyRelationObserved, serverCase, serverLifecycleObserved,
                    serverRuntimeObserved, serverEpochObserved,
                    classSurfaceObserved, evidenceClassTagged, traceOnly,
                    remoteTickOnly, schedStatOnly, authorityClaim,
                    enforcementClaim, protectionClaim, accepted, failClosed>>

AcceptCoverage ==
    /\ phase = "Classified"
    /\ currentObserved
    /\ donorObserved
    /\ (~proxyCase \/ proxyRelationObserved)
    /\ (~serverCase \/
        (serverLifecycleObserved /\ serverRuntimeObserved /\ serverEpochObserved))
    /\ classSurfaceObserved
    /\ evidenceClassTagged
    /\ traceOnly
    /\ ~authorityClaim
    /\ ~enforcementClaim
    /\ ~protectionClaim
    /\ accepted' = TRUE
    /\ phase' = "Accepted"
    /\ UNCHANGED <<currentObserved, donorObserved, proxyCase,
                    proxyRelationObserved, serverCase, serverLifecycleObserved,
                    serverRuntimeObserved, serverEpochObserved,
                    classSurfaceObserved, evidenceClassTagged, traceOnly,
                    remoteTickOnly, schedStatOnly, authorityClaim,
                    enforcementClaim, protectionClaim, failClosed>>

RejectIncomplete ==
    /\ phase \in {"CurrentDonorCollected", "ProxyCollected", "ServerCollected",
                  "Classified"}
    /\ accepted = FALSE
    /\ failClosed' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<currentObserved, donorObserved, proxyCase,
                    proxyRelationObserved, serverCase, serverLifecycleObserved,
                    serverRuntimeObserved, serverEpochObserved,
                    classSurfaceObserved, evidenceClassTagged, traceOnly,
                    remoteTickOnly, schedStatOnly, authorityClaim,
                    enforcementClaim, protectionClaim, accepted>>

TerminalStutter ==
    /\ phase \in {"Accepted", "FailClosed"}
    /\ UNCHANGED vars

UnsafeMissingCurrent ==
    /\ phase = "Start"
    /\ donorObserved' = TRUE
    /\ evidenceClassTagged' = TRUE
    /\ traceOnly' = TRUE
    /\ accepted' = TRUE
    /\ phase' = "BadMissingCurrent"
    /\ UNCHANGED <<currentObserved, proxyCase, proxyRelationObserved,
                    serverCase, serverLifecycleObserved, serverRuntimeObserved,
                    serverEpochObserved, classSurfaceObserved, remoteTickOnly,
                    schedStatOnly, authorityClaim, enforcementClaim,
                    protectionClaim, failClosed>>

UnsafeMissingDonor ==
    /\ phase = "Start"
    /\ currentObserved' = TRUE
    /\ evidenceClassTagged' = TRUE
    /\ traceOnly' = TRUE
    /\ accepted' = TRUE
    /\ phase' = "BadMissingDonor"
    /\ UNCHANGED <<donorObserved, proxyCase, proxyRelationObserved,
                    serverCase, serverLifecycleObserved, serverRuntimeObserved,
                    serverEpochObserved, classSurfaceObserved, remoteTickOnly,
                    schedStatOnly, authorityClaim, enforcementClaim,
                    protectionClaim, failClosed>>

UnsafeMissingProxyRelation ==
    /\ phase = "CurrentDonorCollected"
    /\ proxyCase
    /\ proxyRelationObserved = FALSE
    /\ accepted' = TRUE
    /\ phase' = "BadMissingProxyRelation"
    /\ UNCHANGED <<currentObserved, donorObserved, proxyCase,
                    proxyRelationObserved, serverCase, serverLifecycleObserved,
                    serverRuntimeObserved, serverEpochObserved,
                    classSurfaceObserved, evidenceClassTagged, traceOnly,
                    remoteTickOnly, schedStatOnly, authorityClaim,
                    enforcementClaim, protectionClaim, failClosed>>

UnsafeMissingServerCoverage ==
    /\ phase = "ProxyCollected"
    /\ serverCase
    /\ serverRuntimeObserved = FALSE
    /\ serverEpochObserved = FALSE
    /\ accepted' = TRUE
    /\ phase' = "BadMissingServerCoverage"
    /\ UNCHANGED <<currentObserved, donorObserved, proxyCase,
                    proxyRelationObserved, serverCase, serverLifecycleObserved,
                    serverRuntimeObserved, serverEpochObserved,
                    classSurfaceObserved, evidenceClassTagged, traceOnly,
                    remoteTickOnly, schedStatOnly, authorityClaim,
                    enforcementClaim, protectionClaim, failClosed>>

UnsafeMissingEvidenceClass ==
    /\ phase = "Start"
    /\ currentObserved' = TRUE
    /\ donorObserved' = TRUE
    /\ classSurfaceObserved' = TRUE
    /\ traceOnly' = TRUE
    /\ accepted' = TRUE
    /\ phase' = "BadMissingEvidenceClass"
    /\ UNCHANGED <<proxyCase, proxyRelationObserved, serverCase,
                    serverLifecycleObserved, serverRuntimeObserved,
                    serverEpochObserved, evidenceClassTagged, remoteTickOnly,
                    schedStatOnly, authorityClaim, enforcementClaim,
                    protectionClaim, failClosed>>

UnsafeSchedStatAuthority ==
    /\ phase = "Start"
    /\ currentObserved' = TRUE
    /\ donorObserved' = TRUE
    /\ classSurfaceObserved' = TRUE
    /\ evidenceClassTagged' = TRUE
    /\ traceOnly' = TRUE
    /\ schedStatOnly' = TRUE
    /\ authorityClaim' = TRUE
    /\ accepted' = TRUE
    /\ phase' = "BadSchedStatAuthority"
    /\ UNCHANGED <<proxyCase, proxyRelationObserved, serverCase,
                    serverLifecycleObserved, serverRuntimeObserved,
                    serverEpochObserved, remoteTickOnly, enforcementClaim,
                    protectionClaim, failClosed>>

UnsafeRemoteTickProxyCoverage ==
    /\ phase = "Start"
    /\ currentObserved' = TRUE
    /\ donorObserved' = TRUE
    /\ proxyCase' = TRUE
    /\ remoteTickOnly' = TRUE
    /\ evidenceClassTagged' = TRUE
    /\ traceOnly' = TRUE
    /\ accepted' = TRUE
    /\ phase' = "BadRemoteTickProxyCoverage"
    /\ UNCHANGED <<proxyRelationObserved, serverCase, serverLifecycleObserved,
                    serverRuntimeObserved, serverEpochObserved,
                    classSurfaceObserved, schedStatOnly, authorityClaim,
                    enforcementClaim, protectionClaim, failClosed>>

UnsafeTraceProtection ==
    /\ phase = "Start"
    /\ currentObserved' = TRUE
    /\ donorObserved' = TRUE
    /\ classSurfaceObserved' = TRUE
    /\ evidenceClassTagged' = TRUE
    /\ traceOnly' = TRUE
    /\ protectionClaim' = TRUE
    /\ accepted' = TRUE
    /\ phase' = "BadTraceProtection"
    /\ UNCHANGED <<proxyCase, proxyRelationObserved, serverCase,
                    serverLifecycleObserved, serverRuntimeObserved,
                    serverEpochObserved, remoteTickOnly, schedStatOnly,
                    authorityClaim, enforcementClaim, failClosed>>

UnsafeServerLifecycleOnly ==
    /\ phase = "Start"
    /\ currentObserved' = TRUE
    /\ donorObserved' = TRUE
    /\ serverCase' = TRUE
    /\ serverLifecycleObserved' = TRUE
    /\ serverRuntimeObserved' = FALSE
    /\ serverEpochObserved' = FALSE
    /\ classSurfaceObserved' = TRUE
    /\ evidenceClassTagged' = TRUE
    /\ traceOnly' = TRUE
    /\ accepted' = TRUE
    /\ phase' = "BadServerLifecycleOnly"
    /\ UNCHANGED <<proxyCase, proxyRelationObserved, remoteTickOnly,
                    schedStatOnly, authorityClaim, enforcementClaim,
                    protectionClaim, failClosed>>

UnsafeClassRuntimeRoot ==
    /\ phase = "Start"
    /\ currentObserved' = TRUE
    /\ donorObserved' = TRUE
    /\ classSurfaceObserved' = TRUE
    /\ evidenceClassTagged' = TRUE
    /\ traceOnly' = TRUE
    /\ authorityClaim' = TRUE
    /\ enforcementClaim' = TRUE
    /\ accepted' = TRUE
    /\ phase' = "BadClassRuntimeRoot"
    /\ UNCHANGED <<proxyCase, proxyRelationObserved, serverCase,
                    serverLifecycleObserved, serverRuntimeObserved,
                    serverEpochObserved, remoteTickOnly, schedStatOnly,
                    protectionClaim, failClosed>>

SafeNext ==
    \/ \E p \in BOOLEAN: \E s \in BOOLEAN: CollectCurrentDonor(p, s)
    \/ CollectProxyRelation
    \/ SkipNoProxy
    \/ CollectServerCoverage
    \/ SkipNoServer
    \/ ClassifyCoverage
    \/ AcceptCoverage
    \/ RejectIncomplete
    \/ TerminalStutter

UnsafeMissingCurrentSpec ==
    Init /\ [][SafeNext \/ UnsafeMissingCurrent]_vars

UnsafeMissingDonorSpec ==
    Init /\ [][SafeNext \/ UnsafeMissingDonor]_vars

UnsafeMissingProxySpec ==
    Init /\ [][SafeNext \/ UnsafeMissingProxyRelation]_vars

UnsafeMissingServerSpec ==
    Init /\ [][SafeNext \/ UnsafeMissingServerCoverage]_vars

UnsafeMissingEvidenceSpec ==
    Init /\ [][SafeNext \/ UnsafeMissingEvidenceClass]_vars

UnsafeSchedStatSpec ==
    Init /\ [][SafeNext \/ UnsafeSchedStatAuthority]_vars

UnsafeRemoteTickSpec ==
    Init /\ [][SafeNext \/ UnsafeRemoteTickProxyCoverage]_vars

UnsafeTraceProtectionSpec ==
    Init /\ [][SafeNext \/ UnsafeTraceProtection]_vars

UnsafeServerLifecycleSpec ==
    Init /\ [][SafeNext \/ UnsafeServerLifecycleOnly]_vars

UnsafeClassRuntimeRootSpec ==
    Init /\ [][SafeNext \/ UnsafeClassRuntimeRoot]_vars

SafeSpec ==
    Init /\ [][SafeNext]_vars

NoAcceptWithoutCurrent ==
    accepted => currentObserved

NoAcceptWithoutDonor ==
    accepted => donorObserved

NoAcceptProxyWithoutRelation ==
    (accepted /\ proxyCase) => proxyRelationObserved

NoAcceptServerWithoutFullCoverage ==
    (accepted /\ serverCase) =>
        /\ serverLifecycleObserved
        /\ serverRuntimeObserved
        /\ serverEpochObserved

NoAcceptWithoutEvidenceClass ==
    accepted => evidenceClassTagged

NoSchedStatOnlyAuthority ==
    (accepted /\ schedStatOnly) => ~authorityClaim

NoRemoteTickOnlyProxyCoverage ==
    (accepted /\ remoteTickOnly) => ~proxyCase

NoTraceOnlyProtectionClaim ==
    (accepted /\ traceOnly) =>
        /\ ~protectionClaim
        /\ ~enforcementClaim

NoServerLifecycleOnlyCoverage ==
    (accepted /\ serverCase /\ serverLifecycleObserved) =>
        /\ serverRuntimeObserved
        /\ serverEpochObserved

NoClassRuntimeAsRootEvidence ==
    (accepted /\ classSurfaceObserved) =>
        /\ ~authorityClaim
        /\ ~enforcementClaim

NoFailClosedAccepted ==
    failClosed => ~accepted

=============================================================================
