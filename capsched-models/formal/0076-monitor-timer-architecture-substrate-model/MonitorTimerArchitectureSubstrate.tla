---------------- MODULE MonitorTimerArchitectureSubstrate ----------------
EXTENDS Naturals

VARIABLES
    phase,
    selectedArch,
    substrate,
    timerOwner,
    monitorStateProtected,
    activeMemoryView,
    cpuBound,
    activationGenerationFresh,
    sealedRunToken,
    domainEpochFresh,
    rootBudgetRemaining,
    timerArmed,
    expiryTrapDelivered,
    running,
    failClosed,
    deadlineMutableByLinux,
    nohzControlsTimer,
    boundedOverrun,
    auditReceipt,
    linuxMintedReceipt,
    protectionClaim

vars == <<phase, selectedArch, substrate, timerOwner, monitorStateProtected,
          activeMemoryView, cpuBound, activationGenerationFresh,
          sealedRunToken, domainEpochFresh, rootBudgetRemaining, timerArmed,
          expiryTrapDelivered, running, failClosed, deadlineMutableByLinux,
          nohzControlsTimer, boundedOverrun, auditReceipt, linuxMintedReceipt,
          protectionClaim>>

Phases == {
    "Start",
    "SubstrateChosen",
    "Activated",
    "Running",
    "ExpiredFailClosed",
    "BadRunWithoutSubstrate",
    "BadWrongArchSubstrate",
    "BadLinuxHrtimerRoot",
    "BadLinuxSchedTickRoot",
    "BadKvmGuestTimerRoot",
    "BadKvmHrtimerFallbackRoot",
    "BadArm64KvmArchTimerRoot",
    "BadArm64KvmSoftHrtimerRoot",
    "BadPkvmStage2AsTimer",
    "BadPkvmStage2PlusLinuxTimer",
    "BadRunWithoutMonitorTimer",
    "BadRunWithoutToken",
    "BadRunWithStaleEpoch",
    "BadRunWithUnprotectedMonitorState",
    "BadRunWithoutRootBudget",
    "BadRunMissingBindingTuple",
    "BadDeadlineRetimedByLinux",
    "BadExpiryStillRunning",
    "BadNoHzControlsMonitor",
    "BadUnboundedOverrun",
    "BadLinuxMintedReceipt",
    "BadReceiptWithoutExpiry",
    "BadProtectionClaim"
}

Architectures == {"None", "X86", "ARM64"}

Substrates == {
    "None",
    "MonitorX86VmxRoot",
    "MonitorArm64El2",
    "LinuxHrtimer",
    "LinuxSchedTick",
    "KvmGuestVmxTimer",
    "KvmVmxHrtimerFallback",
    "Arm64KvmArchTimer",
    "Arm64KvmSoftHrtimer",
    "PkvmStage2Memory"
}

Owners == {"None", "Monitor", "Linux", "KvmGuest", "PkvmMemory"}

TypeOK ==
    /\ phase \in Phases
    /\ selectedArch \in Architectures
    /\ substrate \in Substrates
    /\ timerOwner \in Owners
    /\ monitorStateProtected \in BOOLEAN
    /\ activeMemoryView \in BOOLEAN
    /\ cpuBound \in BOOLEAN
    /\ activationGenerationFresh \in BOOLEAN
    /\ sealedRunToken \in BOOLEAN
    /\ domainEpochFresh \in BOOLEAN
    /\ rootBudgetRemaining \in BOOLEAN
    /\ timerArmed \in BOOLEAN
    /\ expiryTrapDelivered \in BOOLEAN
    /\ running \in BOOLEAN
    /\ failClosed \in BOOLEAN
    /\ deadlineMutableByLinux \in BOOLEAN
    /\ nohzControlsTimer \in BOOLEAN
    /\ boundedOverrun \in BOOLEAN
    /\ auditReceipt \in BOOLEAN
    /\ linuxMintedReceipt \in BOOLEAN
    /\ protectionClaim \in BOOLEAN

MonitorArchSubstrate ==
    \/ /\ selectedArch = "X86"
       /\ substrate = "MonitorX86VmxRoot"
    \/ /\ selectedArch = "ARM64"
       /\ substrate = "MonitorArm64El2"

SubstrateMatchesArch ==
    /\ selectedArch = "X86" => substrate # "MonitorArm64El2"
    /\ selectedArch = "ARM64" => substrate # "MonitorX86VmxRoot"

MonitorTimerReady ==
    /\ MonitorArchSubstrate
    /\ timerOwner = "Monitor"
    /\ timerArmed

BindingTupleReady ==
    /\ monitorStateProtected
    /\ activeMemoryView
    /\ cpuBound
    /\ activationGenerationFresh
    /\ sealedRunToken
    /\ domainEpochFresh
    /\ rootBudgetRemaining

ActivationRootReady ==
    /\ MonitorTimerReady
    /\ BindingTupleReady
    /\ boundedOverrun
    /\ ~deadlineMutableByLinux
    /\ ~nohzControlsTimer
    /\ ~linuxMintedReceipt

Init ==
    /\ phase = "Start"
    /\ selectedArch = "None"
    /\ substrate = "None"
    /\ timerOwner = "None"
    /\ monitorStateProtected = FALSE
    /\ activeMemoryView = FALSE
    /\ cpuBound = FALSE
    /\ activationGenerationFresh = FALSE
    /\ sealedRunToken = FALSE
    /\ domainEpochFresh = FALSE
    /\ rootBudgetRemaining = FALSE
    /\ timerArmed = FALSE
    /\ expiryTrapDelivered = FALSE
    /\ running = FALSE
    /\ failClosed = FALSE
    /\ deadlineMutableByLinux = FALSE
    /\ nohzControlsTimer = FALSE
    /\ boundedOverrun = FALSE
    /\ auditReceipt = FALSE
    /\ linuxMintedReceipt = FALSE
    /\ protectionClaim = FALSE

ChooseX86VmxMonitorSubstrate ==
    /\ phase = "Start"
    /\ selectedArch' = "X86"
    /\ substrate' = "MonitorX86VmxRoot"
    /\ timerOwner' = "Monitor"
    /\ monitorStateProtected' = TRUE
    /\ boundedOverrun' = TRUE
    /\ phase' = "SubstrateChosen"
    /\ UNCHANGED <<activeMemoryView, cpuBound, activationGenerationFresh,
                    sealedRunToken, domainEpochFresh, rootBudgetRemaining,
                    timerArmed, expiryTrapDelivered, running, failClosed,
                    deadlineMutableByLinux, nohzControlsTimer, auditReceipt,
                    linuxMintedReceipt, protectionClaim>>

ChooseArm64El2MonitorSubstrate ==
    /\ phase = "Start"
    /\ selectedArch' = "ARM64"
    /\ substrate' = "MonitorArm64El2"
    /\ timerOwner' = "Monitor"
    /\ monitorStateProtected' = TRUE
    /\ boundedOverrun' = TRUE
    /\ phase' = "SubstrateChosen"
    /\ UNCHANGED <<activeMemoryView, cpuBound, activationGenerationFresh,
                    sealedRunToken, domainEpochFresh, rootBudgetRemaining,
                    timerArmed, expiryTrapDelivered, running, failClosed,
                    deadlineMutableByLinux, nohzControlsTimer, auditReceipt,
                    linuxMintedReceipt, protectionClaim>>

ActivateMonitorRootTimer ==
    /\ phase = "SubstrateChosen"
    /\ MonitorArchSubstrate
    /\ timerOwner = "Monitor"
    /\ monitorStateProtected
    /\ activeMemoryView' = TRUE
    /\ cpuBound' = TRUE
    /\ activationGenerationFresh' = TRUE
    /\ sealedRunToken' = TRUE
    /\ domainEpochFresh' = TRUE
    /\ rootBudgetRemaining' = TRUE
    /\ timerArmed' = TRUE
    /\ phase' = "Activated"
    /\ UNCHANGED <<selectedArch, substrate, timerOwner, monitorStateProtected,
                    expiryTrapDelivered, running, failClosed,
                    deadlineMutableByLinux, nohzControlsTimer,
                    boundedOverrun, auditReceipt, linuxMintedReceipt,
                    protectionClaim>>

RunWithMonitorRoot ==
    /\ phase = "Activated"
    /\ ActivationRootReady
    /\ running' = TRUE
    /\ phase' = "Running"
    /\ UNCHANGED <<selectedArch, substrate, timerOwner, monitorStateProtected,
                    activeMemoryView, cpuBound, activationGenerationFresh,
                    sealedRunToken, domainEpochFresh, rootBudgetRemaining,
                    timerArmed, expiryTrapDelivered, failClosed,
                    deadlineMutableByLinux, nohzControlsTimer,
                    boundedOverrun, auditReceipt, linuxMintedReceipt,
                    protectionClaim>>

ExpireFailClosed ==
    /\ phase = "Running"
    /\ running
    /\ expiryTrapDelivered' = TRUE
    /\ running' = FALSE
    /\ failClosed' = TRUE
    /\ rootBudgetRemaining' = FALSE
    /\ auditReceipt' = TRUE
    /\ phase' = "ExpiredFailClosed"
    /\ UNCHANGED <<selectedArch, substrate, timerOwner, monitorStateProtected,
                    activeMemoryView, cpuBound, activationGenerationFresh,
                    sealedRunToken, domainEpochFresh, timerArmed,
                    deadlineMutableByLinux, nohzControlsTimer,
                    boundedOverrun, linuxMintedReceipt, protectionClaim>>

TerminalStutter ==
    /\ phase = "ExpiredFailClosed"
    /\ UNCHANGED vars

SafeNext ==
    \/ ChooseX86VmxMonitorSubstrate
    \/ ChooseArm64El2MonitorSubstrate
    \/ ActivateMonitorRootTimer
    \/ RunWithMonitorRoot
    \/ ExpireFailClosed
    \/ TerminalStutter

UnsafeRunWithoutSubstrate ==
    /\ phase = "Start"
    /\ selectedArch' = "None"
    /\ substrate' = "None"
    /\ timerOwner' = "Monitor"
    /\ monitorStateProtected' = TRUE
    /\ activeMemoryView' = TRUE
    /\ cpuBound' = TRUE
    /\ activationGenerationFresh' = TRUE
    /\ sealedRunToken' = TRUE
    /\ domainEpochFresh' = TRUE
    /\ rootBudgetRemaining' = TRUE
    /\ timerArmed' = TRUE
    /\ boundedOverrun' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunWithoutSubstrate"
    /\ UNCHANGED <<expiryTrapDelivered, failClosed, deadlineMutableByLinux,
                    nohzControlsTimer, auditReceipt, linuxMintedReceipt,
                    protectionClaim>>

UnsafeWrongArchSubstrate ==
    /\ phase = "Start"
    /\ selectedArch' = "X86"
    /\ substrate' = "MonitorArm64El2"
    /\ timerOwner' = "Monitor"
    /\ monitorStateProtected' = TRUE
    /\ activeMemoryView' = TRUE
    /\ cpuBound' = TRUE
    /\ activationGenerationFresh' = TRUE
    /\ sealedRunToken' = TRUE
    /\ domainEpochFresh' = TRUE
    /\ rootBudgetRemaining' = TRUE
    /\ timerArmed' = TRUE
    /\ boundedOverrun' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadWrongArchSubstrate"
    /\ UNCHANGED <<expiryTrapDelivered, failClosed, deadlineMutableByLinux,
                    nohzControlsTimer, auditReceipt, linuxMintedReceipt,
                    protectionClaim>>

UnsafeLinuxHrtimerRoot ==
    /\ phase = "Start"
    /\ selectedArch' = "X86"
    /\ substrate' = "LinuxHrtimer"
    /\ timerOwner' = "Linux"
    /\ running' = TRUE
    /\ phase' = "BadLinuxHrtimerRoot"
    /\ UNCHANGED <<monitorStateProtected, activeMemoryView, cpuBound,
                    activationGenerationFresh, sealedRunToken,
                    domainEpochFresh, rootBudgetRemaining, timerArmed,
                    expiryTrapDelivered, failClosed, deadlineMutableByLinux,
                    nohzControlsTimer, boundedOverrun, auditReceipt,
                    linuxMintedReceipt, protectionClaim>>

UnsafeLinuxSchedTickRoot ==
    /\ phase = "Start"
    /\ selectedArch' = "X86"
    /\ substrate' = "LinuxSchedTick"
    /\ timerOwner' = "Linux"
    /\ running' = TRUE
    /\ phase' = "BadLinuxSchedTickRoot"
    /\ UNCHANGED <<monitorStateProtected, activeMemoryView, cpuBound,
                    activationGenerationFresh, sealedRunToken,
                    domainEpochFresh, rootBudgetRemaining, timerArmed,
                    expiryTrapDelivered, failClosed, deadlineMutableByLinux,
                    nohzControlsTimer, boundedOverrun, auditReceipt,
                    linuxMintedReceipt, protectionClaim>>

UnsafeKvmGuestTimerRoot ==
    /\ phase = "Start"
    /\ selectedArch' = "X86"
    /\ substrate' = "KvmGuestVmxTimer"
    /\ timerOwner' = "KvmGuest"
    /\ running' = TRUE
    /\ phase' = "BadKvmGuestTimerRoot"
    /\ UNCHANGED <<monitorStateProtected, activeMemoryView, cpuBound,
                    activationGenerationFresh, sealedRunToken,
                    domainEpochFresh, rootBudgetRemaining, timerArmed,
                    expiryTrapDelivered, failClosed, deadlineMutableByLinux,
                    nohzControlsTimer, boundedOverrun, auditReceipt,
                    linuxMintedReceipt, protectionClaim>>

UnsafeKvmHrtimerFallbackRoot ==
    /\ phase = "Start"
    /\ selectedArch' = "X86"
    /\ substrate' = "KvmVmxHrtimerFallback"
    /\ timerOwner' = "Linux"
    /\ running' = TRUE
    /\ phase' = "BadKvmHrtimerFallbackRoot"
    /\ UNCHANGED <<monitorStateProtected, activeMemoryView, cpuBound,
                    activationGenerationFresh, sealedRunToken,
                    domainEpochFresh, rootBudgetRemaining, timerArmed,
                    expiryTrapDelivered, failClosed, deadlineMutableByLinux,
                    nohzControlsTimer, boundedOverrun, auditReceipt,
                    linuxMintedReceipt, protectionClaim>>

UnsafeArm64KvmArchTimerRoot ==
    /\ phase = "Start"
    /\ selectedArch' = "ARM64"
    /\ substrate' = "Arm64KvmArchTimer"
    /\ timerOwner' = "KvmGuest"
    /\ running' = TRUE
    /\ phase' = "BadArm64KvmArchTimerRoot"
    /\ UNCHANGED <<monitorStateProtected, activeMemoryView, cpuBound,
                    activationGenerationFresh, sealedRunToken,
                    domainEpochFresh, rootBudgetRemaining, timerArmed,
                    expiryTrapDelivered, failClosed, deadlineMutableByLinux,
                    nohzControlsTimer, boundedOverrun, auditReceipt,
                    linuxMintedReceipt, protectionClaim>>

UnsafeArm64KvmSoftHrtimerRoot ==
    /\ phase = "Start"
    /\ selectedArch' = "ARM64"
    /\ substrate' = "Arm64KvmSoftHrtimer"
    /\ timerOwner' = "Linux"
    /\ running' = TRUE
    /\ phase' = "BadArm64KvmSoftHrtimerRoot"
    /\ UNCHANGED <<monitorStateProtected, activeMemoryView, cpuBound,
                    activationGenerationFresh, sealedRunToken,
                    domainEpochFresh, rootBudgetRemaining, timerArmed,
                    expiryTrapDelivered, failClosed, deadlineMutableByLinux,
                    nohzControlsTimer, boundedOverrun, auditReceipt,
                    linuxMintedReceipt, protectionClaim>>

UnsafePkvmStage2AsTimer ==
    /\ phase = "Start"
    /\ selectedArch' = "ARM64"
    /\ substrate' = "PkvmStage2Memory"
    /\ timerOwner' = "PkvmMemory"
    /\ monitorStateProtected' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadPkvmStage2AsTimer"
    /\ UNCHANGED <<activeMemoryView, cpuBound, activationGenerationFresh,
                    sealedRunToken, domainEpochFresh, rootBudgetRemaining,
                    timerArmed, expiryTrapDelivered, failClosed,
                    deadlineMutableByLinux, nohzControlsTimer,
                    boundedOverrun, auditReceipt, linuxMintedReceipt,
                    protectionClaim>>

UnsafePkvmStage2PlusLinuxTimer ==
    /\ phase = "Start"
    /\ selectedArch' = "ARM64"
    /\ substrate' = "PkvmStage2Memory"
    /\ timerOwner' = "Linux"
    /\ monitorStateProtected' = TRUE
    /\ timerArmed' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadPkvmStage2PlusLinuxTimer"
    /\ UNCHANGED <<activeMemoryView, cpuBound, activationGenerationFresh,
                    sealedRunToken, domainEpochFresh, rootBudgetRemaining,
                    expiryTrapDelivered, failClosed, deadlineMutableByLinux,
                    nohzControlsTimer, boundedOverrun, auditReceipt,
                    linuxMintedReceipt, protectionClaim>>

UnsafeRunWithoutMonitorTimer ==
    /\ phase = "Start"
    /\ selectedArch' = "X86"
    /\ substrate' = "MonitorX86VmxRoot"
    /\ timerOwner' = "None"
    /\ timerArmed' = FALSE
    /\ monitorStateProtected' = TRUE
    /\ activeMemoryView' = TRUE
    /\ cpuBound' = TRUE
    /\ activationGenerationFresh' = TRUE
    /\ sealedRunToken' = TRUE
    /\ domainEpochFresh' = TRUE
    /\ rootBudgetRemaining' = TRUE
    /\ boundedOverrun' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunWithoutMonitorTimer"
    /\ UNCHANGED <<expiryTrapDelivered, failClosed, deadlineMutableByLinux,
                    nohzControlsTimer, auditReceipt, linuxMintedReceipt,
                    protectionClaim>>

UnsafeRunWithoutToken ==
    /\ phase = "Start"
    /\ selectedArch' = "X86"
    /\ substrate' = "MonitorX86VmxRoot"
    /\ timerOwner' = "Monitor"
    /\ timerArmed' = TRUE
    /\ monitorStateProtected' = TRUE
    /\ activeMemoryView' = TRUE
    /\ cpuBound' = TRUE
    /\ activationGenerationFresh' = TRUE
    /\ domainEpochFresh' = TRUE
    /\ rootBudgetRemaining' = TRUE
    /\ boundedOverrun' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunWithoutToken"
    /\ UNCHANGED <<sealedRunToken, expiryTrapDelivered, failClosed,
                    deadlineMutableByLinux, nohzControlsTimer, auditReceipt,
                    linuxMintedReceipt, protectionClaim>>

UnsafeRunWithStaleEpoch ==
    /\ phase = "Start"
    /\ selectedArch' = "X86"
    /\ substrate' = "MonitorX86VmxRoot"
    /\ timerOwner' = "Monitor"
    /\ timerArmed' = TRUE
    /\ monitorStateProtected' = TRUE
    /\ activeMemoryView' = TRUE
    /\ cpuBound' = TRUE
    /\ activationGenerationFresh' = TRUE
    /\ sealedRunToken' = TRUE
    /\ rootBudgetRemaining' = TRUE
    /\ boundedOverrun' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunWithStaleEpoch"
    /\ UNCHANGED <<domainEpochFresh, expiryTrapDelivered, failClosed,
                    deadlineMutableByLinux, nohzControlsTimer, auditReceipt,
                    linuxMintedReceipt, protectionClaim>>

UnsafeRunWithUnprotectedMonitorState ==
    /\ phase = "Start"
    /\ selectedArch' = "X86"
    /\ substrate' = "MonitorX86VmxRoot"
    /\ timerOwner' = "Monitor"
    /\ timerArmed' = TRUE
    /\ activeMemoryView' = TRUE
    /\ cpuBound' = TRUE
    /\ activationGenerationFresh' = TRUE
    /\ sealedRunToken' = TRUE
    /\ domainEpochFresh' = TRUE
    /\ rootBudgetRemaining' = TRUE
    /\ boundedOverrun' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunWithUnprotectedMonitorState"
    /\ UNCHANGED <<monitorStateProtected, expiryTrapDelivered, failClosed,
                    deadlineMutableByLinux, nohzControlsTimer, auditReceipt,
                    linuxMintedReceipt, protectionClaim>>

UnsafeRunWithoutRootBudget ==
    /\ phase = "Start"
    /\ selectedArch' = "X86"
    /\ substrate' = "MonitorX86VmxRoot"
    /\ timerOwner' = "Monitor"
    /\ timerArmed' = TRUE
    /\ monitorStateProtected' = TRUE
    /\ activeMemoryView' = TRUE
    /\ cpuBound' = TRUE
    /\ activationGenerationFresh' = TRUE
    /\ sealedRunToken' = TRUE
    /\ domainEpochFresh' = TRUE
    /\ boundedOverrun' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunWithoutRootBudget"
    /\ UNCHANGED <<rootBudgetRemaining, expiryTrapDelivered, failClosed,
                    deadlineMutableByLinux, nohzControlsTimer, auditReceipt,
                    linuxMintedReceipt, protectionClaim>>

UnsafeRunMissingBindingTuple ==
    /\ phase = "Start"
    /\ selectedArch' = "X86"
    /\ substrate' = "MonitorX86VmxRoot"
    /\ timerOwner' = "Monitor"
    /\ timerArmed' = TRUE
    /\ monitorStateProtected' = TRUE
    /\ activeMemoryView' = FALSE
    /\ cpuBound' = FALSE
    /\ activationGenerationFresh' = FALSE
    /\ sealedRunToken' = TRUE
    /\ domainEpochFresh' = TRUE
    /\ rootBudgetRemaining' = TRUE
    /\ boundedOverrun' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadRunMissingBindingTuple"
    /\ UNCHANGED <<expiryTrapDelivered, failClosed, deadlineMutableByLinux,
                    nohzControlsTimer, auditReceipt, linuxMintedReceipt,
                    protectionClaim>>

UnsafeDeadlineRetimedByLinux ==
    /\ phase = "Start"
    /\ selectedArch' = "X86"
    /\ substrate' = "MonitorX86VmxRoot"
    /\ timerOwner' = "Monitor"
    /\ timerArmed' = TRUE
    /\ monitorStateProtected' = TRUE
    /\ activeMemoryView' = TRUE
    /\ cpuBound' = TRUE
    /\ activationGenerationFresh' = TRUE
    /\ sealedRunToken' = TRUE
    /\ domainEpochFresh' = TRUE
    /\ rootBudgetRemaining' = TRUE
    /\ boundedOverrun' = TRUE
    /\ deadlineMutableByLinux' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadDeadlineRetimedByLinux"
    /\ UNCHANGED <<expiryTrapDelivered, failClosed, nohzControlsTimer,
                    auditReceipt, linuxMintedReceipt, protectionClaim>>

UnsafeExpiryStillRunning ==
    /\ phase = "Start"
    /\ selectedArch' = "X86"
    /\ substrate' = "MonitorX86VmxRoot"
    /\ timerOwner' = "Monitor"
    /\ timerArmed' = TRUE
    /\ expiryTrapDelivered' = TRUE
    /\ running' = TRUE
    /\ failClosed' = FALSE
    /\ phase' = "BadExpiryStillRunning"
    /\ UNCHANGED <<monitorStateProtected, activeMemoryView, cpuBound,
                    activationGenerationFresh, sealedRunToken,
                    domainEpochFresh, rootBudgetRemaining,
                    deadlineMutableByLinux, nohzControlsTimer,
                    boundedOverrun, auditReceipt, linuxMintedReceipt,
                    protectionClaim>>

UnsafeNoHzControlsMonitor ==
    /\ phase = "Start"
    /\ nohzControlsTimer' = TRUE
    /\ running' = TRUE
    /\ phase' = "BadNoHzControlsMonitor"
    /\ UNCHANGED <<selectedArch, substrate, timerOwner, monitorStateProtected,
                    activeMemoryView, cpuBound, activationGenerationFresh,
                    sealedRunToken, domainEpochFresh, rootBudgetRemaining,
                    timerArmed, expiryTrapDelivered, failClosed,
                    deadlineMutableByLinux, boundedOverrun, auditReceipt,
                    linuxMintedReceipt, protectionClaim>>

UnsafeUnboundedOverrun ==
    /\ phase = "Start"
    /\ selectedArch' = "X86"
    /\ substrate' = "MonitorX86VmxRoot"
    /\ timerOwner' = "Monitor"
    /\ timerArmed' = TRUE
    /\ monitorStateProtected' = TRUE
    /\ activeMemoryView' = TRUE
    /\ cpuBound' = TRUE
    /\ activationGenerationFresh' = TRUE
    /\ sealedRunToken' = TRUE
    /\ domainEpochFresh' = TRUE
    /\ rootBudgetRemaining' = TRUE
    /\ boundedOverrun' = FALSE
    /\ running' = TRUE
    /\ phase' = "BadUnboundedOverrun"
    /\ UNCHANGED <<expiryTrapDelivered, failClosed, deadlineMutableByLinux,
                    nohzControlsTimer, auditReceipt, linuxMintedReceipt,
                    protectionClaim>>

UnsafeLinuxMintedReceipt ==
    /\ phase = "Start"
    /\ linuxMintedReceipt' = TRUE
    /\ auditReceipt' = TRUE
    /\ phase' = "BadLinuxMintedReceipt"
    /\ UNCHANGED <<selectedArch, substrate, timerOwner, monitorStateProtected,
                    activeMemoryView, cpuBound, activationGenerationFresh,
                    sealedRunToken, domainEpochFresh, rootBudgetRemaining,
                    timerArmed, expiryTrapDelivered, running, failClosed,
                    deadlineMutableByLinux, nohzControlsTimer,
                    boundedOverrun, protectionClaim>>

UnsafeReceiptWithoutExpiry ==
    /\ phase = "Start"
    /\ selectedArch' = "X86"
    /\ substrate' = "MonitorX86VmxRoot"
    /\ timerOwner' = "Monitor"
    /\ auditReceipt' = TRUE
    /\ expiryTrapDelivered' = FALSE
    /\ phase' = "BadReceiptWithoutExpiry"
    /\ UNCHANGED <<monitorStateProtected, activeMemoryView, cpuBound,
                    activationGenerationFresh, sealedRunToken,
                    domainEpochFresh, rootBudgetRemaining, timerArmed,
                    running, failClosed, deadlineMutableByLinux,
                    nohzControlsTimer, boundedOverrun, linuxMintedReceipt,
                    protectionClaim>>

UnsafeProtectionClaim ==
    /\ phase = "Start"
    /\ protectionClaim' = TRUE
    /\ phase' = "BadProtectionClaim"
    /\ UNCHANGED <<selectedArch, substrate, timerOwner, monitorStateProtected,
                    activeMemoryView, cpuBound, activationGenerationFresh,
                    sealedRunToken, domainEpochFresh, rootBudgetRemaining,
                    timerArmed, expiryTrapDelivered, running, failClosed,
                    deadlineMutableByLinux, nohzControlsTimer,
                    boundedOverrun, auditReceipt, linuxMintedReceipt>>

SpecUnsafeRunWithoutSubstrate ==
    Init /\ [][UnsafeRunWithoutSubstrate]_vars

SpecUnsafeWrongArchSubstrate ==
    Init /\ [][UnsafeWrongArchSubstrate]_vars

SpecUnsafeLinuxHrtimerRoot ==
    Init /\ [][UnsafeLinuxHrtimerRoot]_vars

SpecUnsafeLinuxSchedTickRoot ==
    Init /\ [][UnsafeLinuxSchedTickRoot]_vars

SpecUnsafeKvmGuestTimerRoot ==
    Init /\ [][UnsafeKvmGuestTimerRoot]_vars

SpecUnsafeKvmHrtimerFallbackRoot ==
    Init /\ [][UnsafeKvmHrtimerFallbackRoot]_vars

SpecUnsafeArm64KvmArchTimerRoot ==
    Init /\ [][UnsafeArm64KvmArchTimerRoot]_vars

SpecUnsafeArm64KvmSoftHrtimerRoot ==
    Init /\ [][UnsafeArm64KvmSoftHrtimerRoot]_vars

SpecUnsafePkvmStage2AsTimer ==
    Init /\ [][UnsafePkvmStage2AsTimer]_vars

SpecUnsafePkvmStage2PlusLinuxTimer ==
    Init /\ [][UnsafePkvmStage2PlusLinuxTimer]_vars

SpecUnsafeRunWithoutMonitorTimer ==
    Init /\ [][UnsafeRunWithoutMonitorTimer]_vars

SpecUnsafeRunWithoutToken ==
    Init /\ [][UnsafeRunWithoutToken]_vars

SpecUnsafeRunWithStaleEpoch ==
    Init /\ [][UnsafeRunWithStaleEpoch]_vars

SpecUnsafeRunWithUnprotectedMonitorState ==
    Init /\ [][UnsafeRunWithUnprotectedMonitorState]_vars

SpecUnsafeRunWithoutRootBudget ==
    Init /\ [][UnsafeRunWithoutRootBudget]_vars

SpecUnsafeRunMissingBindingTuple ==
    Init /\ [][UnsafeRunMissingBindingTuple]_vars

SpecUnsafeDeadlineRetimedByLinux ==
    Init /\ [][UnsafeDeadlineRetimedByLinux]_vars

SpecUnsafeExpiryStillRunning ==
    Init /\ [][UnsafeExpiryStillRunning]_vars

SpecUnsafeNoHzControlsMonitor ==
    Init /\ [][UnsafeNoHzControlsMonitor]_vars

SpecUnsafeUnboundedOverrun ==
    Init /\ [][UnsafeUnboundedOverrun]_vars

SpecUnsafeLinuxMintedReceipt ==
    Init /\ [][UnsafeLinuxMintedReceipt]_vars

SpecUnsafeReceiptWithoutExpiry ==
    Init /\ [][UnsafeReceiptWithoutExpiry]_vars

SpecUnsafeProtectionClaim ==
    Init /\ [][UnsafeProtectionClaim]_vars

SafeSpec ==
    Init /\ [][SafeNext]_vars

NoRunWithoutMonitorArchSubstrate ==
    running => MonitorArchSubstrate

NoRunWithoutArchitectureSubstrate ==
    NoRunWithoutMonitorArchSubstrate

NoArchitectureAlias ==
    running => SubstrateMatchesArch

NoRunWithoutMonitorOwnedTimer ==
    running => MonitorTimerReady

NoLinuxTimerAsRoot ==
    running => /\ substrate # "LinuxHrtimer"
               /\ substrate # "LinuxSchedTick"
               /\ timerOwner # "Linux"

NoKvmGuestTimerAsRoot ==
    running => /\ substrate # "KvmGuestVmxTimer"
               /\ substrate # "KvmVmxHrtimerFallback"

NoArm64KvmTimerAsRoot ==
    running => /\ substrate # "Arm64KvmArchTimer"
               /\ substrate # "Arm64KvmSoftHrtimer"

NoArmHostHrtimerAsRoot ==
    running => substrate # "Arm64KvmSoftHrtimer"

NoPkvmStage2AsTimerRoot ==
    running => substrate # "PkvmStage2Memory"

NoPkvmStage2AsTimer ==
    NoPkvmStage2AsTimerRoot

NoRunWithoutProtectedMonitorState ==
    running => monitorStateProtected

NoRunWithoutBindingTuple ==
    running => BindingTupleReady

NoRunWithoutSealedToken ==
    running => sealedRunToken

NoRunWithStaleEpoch ==
    running => domainEpochFresh

NoRunWithoutRootBudget ==
    running => rootBudgetRemaining

NoMutableDeadlineAfterActivation ==
    running => ~deadlineMutableByLinux

NoRunningAfterExpiry ==
    expiryTrapDelivered => /\ ~running /\ failClosed

NoExpiredOrRevokedRunning ==
    /\ (expiryTrapDelivered => /\ ~running /\ failClosed)
    /\ (running => /\ domainEpochFresh /\ rootBudgetRemaining)

NoNoHzControlsMonitorTimer ==
    ~nohzControlsTimer

NoUnboundedOverrun ==
    running => boundedOverrun

NoLinuxMintedReceipt ==
    ~linuxMintedReceipt

NoReceiptWithoutMonitorExpiry ==
    auditReceipt => /\ expiryTrapDelivered
                    /\ timerOwner = "Monitor"
                    /\ ~linuxMintedReceipt

NoProtectionClaim ==
    ~protectionClaim

=============================================================================
