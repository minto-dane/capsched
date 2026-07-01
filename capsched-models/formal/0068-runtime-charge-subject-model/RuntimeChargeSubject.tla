----------------------- MODULE RuntimeChargeSubject -----------------------
EXTENDS Naturals

VARIABLES
    phase,
    surface,
    proxy,
    currentCharge,
    donorCharge,
    cgroupDonorCharge,
    classCharge,
    monitorRootCharge,
    proxyTicket,
    observationOnly,
    authorityClaim,
    accepted,
    failClosed

vars == <<phase, surface, proxy, currentCharge, donorCharge,
          cgroupDonorCharge, classCharge, monitorRootCharge, proxyTicket,
          observationOnly, authorityClaim, accepted, failClosed>>

Surfaces == {
    "None",
    "SchedTick",
    "Hrtick",
    "RemoteTick",
    "TaskSchedRuntime",
    "CfsUpdateSe",
    "RtUpdateCurr",
    "DlUpdateCurr",
    "ScxUpdateCurr",
    "IdleStopService"
}

Phases == {
    "Start",
    "SurfaceSelected",
    "Classified",
    "Accepted",
    "FailClosed",
    "BadUnspecifiedCharge",
    "BadClassRuntimeAuthority",
    "BadProxyNoTicket",
    "BadRemoteTickProxy",
    "BadTaskSchedRuntimeAuthority",
    "BadCfsProxyMissingDonorCgroup"
}

TypeOK ==
    /\ phase \in Phases
    /\ surface \in Surfaces
    /\ proxy \in BOOLEAN
    /\ currentCharge \in BOOLEAN
    /\ donorCharge \in BOOLEAN
    /\ cgroupDonorCharge \in BOOLEAN
    /\ classCharge \in BOOLEAN
    /\ monitorRootCharge \in BOOLEAN
    /\ proxyTicket \in BOOLEAN
    /\ observationOnly \in BOOLEAN
    /\ authorityClaim \in BOOLEAN
    /\ accepted \in BOOLEAN
    /\ failClosed \in BOOLEAN

Init ==
    /\ phase = "Start"
    /\ surface = "None"
    /\ proxy = FALSE
    /\ currentCharge = FALSE
    /\ donorCharge = FALSE
    /\ cgroupDonorCharge = FALSE
    /\ classCharge = FALSE
    /\ monitorRootCharge = FALSE
    /\ proxyTicket = FALSE
    /\ observationOnly = FALSE
    /\ authorityClaim = FALSE
    /\ accepted = FALSE
    /\ failClosed = FALSE

SelectDomainSurface(s, p) ==
    /\ phase = "Start"
    /\ s \in Surfaces \ {"None", "TaskSchedRuntime", "IdleStopService"}
    /\ p \in BOOLEAN
    /\ surface' = s
    /\ proxy' = p
    /\ phase' = "SurfaceSelected"
    /\ UNCHANGED <<currentCharge, donorCharge, cgroupDonorCharge, classCharge,
                    monitorRootCharge, proxyTicket, observationOnly,
                    authorityClaim, accepted, failClosed>>

SelectObservationSurface ==
    /\ phase = "Start"
    /\ surface' = "TaskSchedRuntime"
    /\ observationOnly' = TRUE
    /\ authorityClaim' = FALSE
    /\ phase' = "SurfaceSelected"
    /\ UNCHANGED <<proxy, currentCharge, donorCharge, cgroupDonorCharge,
                    classCharge, monitorRootCharge, proxyTicket, accepted,
                    failClosed>>

SelectServiceSurface ==
    /\ phase = "Start"
    /\ surface' = "IdleStopService"
    /\ observationOnly' = TRUE
    /\ authorityClaim' = FALSE
    /\ phase' = "SurfaceSelected"
    /\ UNCHANGED <<proxy, currentCharge, donorCharge, cgroupDonorCharge,
                    classCharge, monitorRootCharge, proxyTicket, accepted,
                    failClosed>>

ClassifyDonorTick ==
    /\ phase = "SurfaceSelected"
    /\ surface \in {"SchedTick", "Hrtick", "RtUpdateCurr",
                    "DlUpdateCurr", "ScxUpdateCurr"}
    /\ donorCharge' = TRUE
    /\ classCharge' = TRUE
    /\ monitorRootCharge' = TRUE
    /\ proxyTicket' = proxy
    /\ currentCharge' = proxy
    /\ authorityClaim' = TRUE
    /\ phase' = "Classified"
    /\ UNCHANGED <<surface, proxy, cgroupDonorCharge, observationOnly,
                    accepted, failClosed>>

ClassifyRemoteTickNoProxy ==
    /\ phase = "SurfaceSelected"
    /\ surface = "RemoteTick"
    /\ ~proxy
    /\ currentCharge' = TRUE
    /\ donorCharge' = TRUE
    /\ classCharge' = TRUE
    /\ monitorRootCharge' = TRUE
    /\ authorityClaim' = TRUE
    /\ phase' = "Classified"
    /\ UNCHANGED <<surface, proxy, cgroupDonorCharge, proxyTicket,
                    observationOnly, accepted, failClosed>>

ClassifyCfsUpdateSe ==
    /\ phase = "SurfaceSelected"
    /\ surface = "CfsUpdateSe"
    /\ currentCharge' = TRUE
    /\ donorCharge' = TRUE
    /\ cgroupDonorCharge' = TRUE
    /\ classCharge' = TRUE
    /\ monitorRootCharge' = TRUE
    /\ proxyTicket' = proxy
    /\ authorityClaim' = TRUE
    /\ phase' = "Classified"
    /\ UNCHANGED <<surface, proxy, observationOnly, accepted, failClosed>>

ClassifyObservationOnly ==
    /\ phase = "SurfaceSelected"
    /\ surface \in {"TaskSchedRuntime", "IdleStopService"}
    /\ observationOnly
    /\ authorityClaim = FALSE
    /\ phase' = "Classified"
    /\ UNCHANGED <<surface, proxy, currentCharge, donorCharge,
                    cgroupDonorCharge, classCharge, monitorRootCharge,
                    proxyTicket, observationOnly, authorityClaim, accepted,
                    failClosed>>

AcceptAuthorityCharge ==
    /\ phase = "Classified"
    /\ authorityClaim
    /\ monitorRootCharge
    /\ (currentCharge \/ donorCharge)
    /\ (~proxy \/ proxyTicket)
    /\ (surface # "RemoteTick" \/ ~proxy)
    /\ (surface # "CfsUpdateSe" \/ ~proxy \/ cgroupDonorCharge)
    /\ accepted' = TRUE
    /\ phase' = "Accepted"
    /\ UNCHANGED <<surface, proxy, currentCharge, donorCharge,
                    cgroupDonorCharge, classCharge, monitorRootCharge,
                    proxyTicket, observationOnly, authorityClaim, failClosed>>

AcceptObservationOnly ==
    /\ phase = "Classified"
    /\ observationOnly
    /\ authorityClaim = FALSE
    /\ accepted' = TRUE
    /\ phase' = "Accepted"
    /\ UNCHANGED <<surface, proxy, currentCharge, donorCharge,
                    cgroupDonorCharge, classCharge, monitorRootCharge,
                    proxyTicket, observationOnly, authorityClaim, failClosed>>

RejectRemoteTickProxy ==
    /\ phase = "SurfaceSelected"
    /\ surface = "RemoteTick"
    /\ proxy
    /\ failClosed' = TRUE
    /\ phase' = "FailClosed"
    /\ UNCHANGED <<surface, proxy, currentCharge, donorCharge,
                    cgroupDonorCharge, classCharge, monitorRootCharge,
                    proxyTicket, observationOnly, authorityClaim, accepted>>

UnsafeUnspecifiedCharge ==
    /\ phase = "SurfaceSelected"
    /\ surface \notin {"TaskSchedRuntime", "IdleStopService"}
    /\ authorityClaim' = TRUE
    /\ accepted' = TRUE
    /\ phase' = "BadUnspecifiedCharge"
    /\ UNCHANGED <<surface, proxy, currentCharge, donorCharge,
                    cgroupDonorCharge, classCharge, monitorRootCharge,
                    proxyTicket, observationOnly, failClosed>>

UnsafeClassRuntimeAuthority ==
    /\ phase = "SurfaceSelected"
    /\ surface \notin {"TaskSchedRuntime", "IdleStopService"}
    /\ classCharge' = TRUE
    /\ monitorRootCharge' = FALSE
    /\ authorityClaim' = TRUE
    /\ accepted' = TRUE
    /\ phase' = "BadClassRuntimeAuthority"
    /\ UNCHANGED <<surface, proxy, currentCharge, donorCharge,
                    cgroupDonorCharge, proxyTicket, observationOnly,
                    failClosed>>

UnsafeProxyNoTicket ==
    /\ phase = "Classified"
    /\ proxy
    /\ proxyTicket' = FALSE
    /\ accepted' = TRUE
    /\ phase' = "BadProxyNoTicket"
    /\ UNCHANGED <<surface, proxy, currentCharge, donorCharge,
                    cgroupDonorCharge, classCharge, monitorRootCharge,
                    observationOnly, authorityClaim, failClosed>>

UnsafeRemoteTickProxy ==
    /\ phase = "SurfaceSelected"
    /\ surface = "RemoteTick"
    /\ proxy
    /\ currentCharge' = TRUE
    /\ donorCharge' = TRUE
    /\ monitorRootCharge' = TRUE
    /\ authorityClaim' = TRUE
    /\ accepted' = TRUE
    /\ phase' = "BadRemoteTickProxy"
    /\ UNCHANGED <<surface, proxy, cgroupDonorCharge, classCharge,
                    proxyTicket, observationOnly, failClosed>>

UnsafeTaskSchedRuntimeAuthority ==
    /\ phase = "SurfaceSelected"
    /\ surface = "TaskSchedRuntime"
    /\ observationOnly
    /\ authorityClaim' = TRUE
    /\ accepted' = TRUE
    /\ phase' = "BadTaskSchedRuntimeAuthority"
    /\ UNCHANGED <<surface, proxy, currentCharge, donorCharge,
                    cgroupDonorCharge, classCharge, monitorRootCharge,
                    proxyTicket, observationOnly, failClosed>>

UnsafeCfsProxyMissingDonorCgroup ==
    /\ phase = "SurfaceSelected"
    /\ surface = "CfsUpdateSe"
    /\ proxy
    /\ currentCharge' = TRUE
    /\ donorCharge' = FALSE
    /\ cgroupDonorCharge' = FALSE
    /\ monitorRootCharge' = TRUE
    /\ proxyTicket' = TRUE
    /\ authorityClaim' = TRUE
    /\ accepted' = TRUE
    /\ phase' = "BadCfsProxyMissingDonorCgroup"
    /\ UNCHANGED <<surface, proxy, classCharge, observationOnly, failClosed>>

SafeNext ==
    \/ \E s \in Surfaces: \E p \in BOOLEAN: SelectDomainSurface(s, p)
    \/ SelectObservationSurface
    \/ SelectServiceSurface
    \/ ClassifyDonorTick
    \/ ClassifyRemoteTickNoProxy
    \/ ClassifyCfsUpdateSe
    \/ ClassifyObservationOnly
    \/ AcceptAuthorityCharge
    \/ AcceptObservationOnly
    \/ RejectRemoteTickProxy

UnsafeUnspecifiedSpec ==
    Init /\ [][SafeNext \/ UnsafeUnspecifiedCharge]_vars

UnsafeClassRuntimeSpec ==
    Init /\ [][SafeNext \/ UnsafeClassRuntimeAuthority]_vars

UnsafeProxySpec ==
    Init /\ [][SafeNext \/ UnsafeProxyNoTicket]_vars

UnsafeRemoteTickSpec ==
    Init /\ [][SafeNext \/ UnsafeRemoteTickProxy]_vars

UnsafeTaskSchedRuntimeSpec ==
    Init /\ [][SafeNext \/ UnsafeTaskSchedRuntimeAuthority]_vars

UnsafeCfsProxySpec ==
    Init /\ [][SafeNext \/ UnsafeCfsProxyMissingDonorCgroup]_vars

SafeSpec ==
    Init /\ [][SafeNext]_vars

NoUnspecifiedRuntimeCharge ==
    (accepted /\ authorityClaim) =>
        /\ monitorRootCharge
        /\ (currentCharge \/ donorCharge)

NoClassRuntimeAsRootAuthority ==
    (accepted /\ authorityClaim) => monitorRootCharge

NoProxyRuntimeWithoutTicket ==
    (accepted /\ authorityClaim /\ proxy) => proxyTicket

NoRemoteTickProxyAuthority ==
    (accepted /\ authorityClaim /\ surface = "RemoteTick") => ~proxy

NoObservationOnlyAsAuthority ==
    (accepted /\ observationOnly) => ~authorityClaim

NoCfsProxyWithoutDonorCgroup ==
    (accepted /\ authorityClaim /\ surface = "CfsUpdateSe" /\ proxy) =>
        /\ donorCharge
        /\ cgroupDonorCharge

NoFailClosedAccepted ==
    failClosed => ~accepted

=============================================================================
