-------------------- MODULE BoundedDomainResidency --------------------
EXTENDS Naturals, FiniteSets, Sequences

CONSTANTS
    Mgmt,
    G1,
    G2,
    G3,
    BE1,
    BE2,
    C0,
    C1,
    NoDomain,
    NoCPU,
    Scenario,
    FaultMode,
    MaxEpoch,
    MaxGeneration,
    MaxCpuIncarnation

OrdinaryDomains == {G1, G2, G3, BE1, BE2}
Domains == OrdinaryDomains \union {Mgmt}
Guaranteed == {G1, G2, G3}
BestEffort == {BE1, BE2}
ExclusiveDomains == {G1}
CPUs == {C0, C1}
DomainOrNone == Domains \union {NoDomain}
CPUOrNone == CPUs \union {NoCPU}

GuaranteedOrder == <<G1, G2, G3>>
CPUOrder == <<C0, C1>>
MaxWaitTurns == Len(GuaranteedOrder)

Scenarios == {"Admission", "Migration", "Hotplug", "Revoke"}
FaultModes == {
    "Safe",
    "WaitForLinuxHint",
    "SkipGuaranteed",
    "NoHardwareQuiesce",
    "EvictPinned",
    "ReuseGeneration",
    "StaleEpochBinding",
    "BestEffortOverwrite",
    "PublishBeforeSeal",
    "TrustStaleHandle",
    "LinuxOwnsBinding",
    "ResidentSlotIsAuthority",
    "LinuxMintsActivation",
    "ManagementBindingLost",
    "CopyBeforeSourceFence",
    "DestinationBeforeSourceStop",
    "MigrationIdentityDrift",
    "OfflineBeforeDrain",
    "LinuxMintsOnlineCPU",
    "ReuseCpuIncarnation",
    "EpochBeforeDrain",
    "ActivateDuringRevoke",
    "LinuxWritesRegistry"
}

VARIABLES
    phase,

    globalEpoch,
    lifecycle,
    admitted,
    registrySource,

    online,
    accepting,
    onlineSource,
    cpuIncarnation,

    slotState,
    slotDomain,
    slotEpoch,
    slotGeneration,
    slotCpuIncarnation,
    slotSealed,
    slotSource,
    lastRetiredGeneration,

    activeDomain,
    activeEpoch,
    activeGeneration,
    activeCpuIncarnation,
    activeSource,
    trustedPins,

    requestDomain,
    requestCPU,
    cursor,
    cpuCursor,
    served,
    everResident,
    waitTurns,

    migrationDomain,
    migrationSource,
    migrationDestination,
    migrationPhase,
    exclusiveOwner,
    placementGeneration,
    migrationActivated,

    linuxProposal,
    linuxCPU,
    linuxGeneration,

    managementBindingSealed,
    managementSource,
    unsafeEvictionObserved,
    activationIssuedDuringRevoke,
    revokingDomain,
    protectionClaim

directoryVars ==
    <<globalEpoch, lifecycle, admitted, registrySource>>

cpuVars ==
    <<online, accepting, onlineSource, cpuIncarnation>>

slotVars ==
    <<slotState, slotDomain, slotEpoch, slotGeneration,
      slotCpuIncarnation, slotSealed, slotSource,
      lastRetiredGeneration>>

activeVars ==
    <<activeDomain, activeEpoch, activeGeneration,
      activeCpuIncarnation, activeSource, trustedPins>>

requestVars ==
    <<requestDomain, requestCPU, cursor, cpuCursor,
      served, everResident, waitTurns>>

migrationVars ==
    <<migrationDomain, migrationSource, migrationDestination,
      migrationPhase, exclusiveOwner, placementGeneration,
      migrationActivated>>

linuxVars == <<linuxProposal, linuxCPU, linuxGeneration>>

controlVars ==
    <<managementBindingSealed, managementSource,
      unsafeEvictionObserved, activationIssuedDuringRevoke,
      revokingDomain, protectionClaim>>

vars ==
    <<phase, directoryVars, cpuVars, slotVars, activeVars,
      requestVars, migrationVars, linuxVars, controlVars>>

InitialSlotDomain(c) ==
    CASE Scenario = "Admission" -> IF c = C0 THEN BE1 ELSE BE2
      [] Scenario = "Migration" -> IF c = C0 THEN G1 ELSE NoDomain
      [] Scenario = "Hotplug" -> IF c = C1 THEN G2 ELSE NoDomain
      [] Scenario = "Revoke" -> G2
      [] OTHER -> NoDomain

InitialActiveDomain(c) ==
    IF FaultMode = "LinuxMintsActivation" /\ Scenario = "Admission" /\ c = C1
    THEN G3
    ELSE CASE Scenario = "Admission" -> IF c = C0 THEN BE1 ELSE NoDomain
           [] Scenario = "Migration" -> IF c = C0 THEN G1 ELSE NoDomain
           [] Scenario = "Hotplug" -> IF c = C1 THEN G2 ELSE NoDomain
           [] Scenario = "Revoke" -> G2
           [] OTHER -> NoDomain

InitialActiveGeneration(c) ==
    IF FaultMode = "LinuxMintsActivation" /\ Scenario = "Admission" /\ c = C1
    THEN 0
    ELSE IF InitialActiveDomain(c) = NoDomain THEN 0 ELSE 1

InitialActiveSource(c) ==
    IF InitialActiveDomain(c) = NoDomain THEN "None"
    ELSE IF FaultMode = "LinuxMintsActivation" /\
            Scenario = "Admission" /\ c = C1
         THEN "Linux"
    ELSE IF FaultMode = "ResidentSlotIsAuthority" /\ c = C0
         THEN "ResidentSlot"
    ELSE "Monitor"

Init ==
    /\ Scenario \in Scenarios
    /\ FaultMode \in FaultModes
    /\ phase = CASE Scenario = "Admission" -> "AdmissionIdle"
                  [] Scenario = "Migration" -> "MigrationReady"
                  [] Scenario = "Hotplug" -> "HotplugReady"
                  [] Scenario = "Revoke" -> "RevokeReady"
    /\ globalEpoch = [d \in Domains |-> 1]
    /\ lifecycle = [d \in Domains |-> "Active"]
    /\ admitted = [d \in Domains |-> TRUE]
    /\ registrySource =
        IF FaultMode = "LinuxWritesRegistry" THEN "Linux" ELSE "Monitor"
    /\ online = [c \in CPUs |-> TRUE]
    /\ accepting = [c \in CPUs |-> TRUE]
    /\ onlineSource = [c \in CPUs |-> "Monitor"]
    /\ cpuIncarnation = [c \in CPUs |-> 1]
    /\ slotDomain = [c \in CPUs |-> InitialSlotDomain(c)]
    /\ slotState =
        [c \in CPUs |->
            IF InitialSlotDomain(c) = NoDomain THEN "Empty" ELSE "Resident"]
    /\ slotEpoch =
        [c \in CPUs |-> IF InitialSlotDomain(c) = NoDomain THEN 0 ELSE 1]
    /\ slotGeneration =
        [c \in CPUs |-> IF InitialSlotDomain(c) = NoDomain THEN 0 ELSE 1]
    /\ slotCpuIncarnation =
        [c \in CPUs |-> IF InitialSlotDomain(c) = NoDomain THEN 0 ELSE 1]
    /\ slotSealed =
        [c \in CPUs |-> InitialSlotDomain(c) # NoDomain]
    /\ slotSource =
        [c \in CPUs |->
            IF InitialSlotDomain(c) = NoDomain THEN "None"
            ELSE IF FaultMode = "LinuxOwnsBinding" THEN "Linux"
            ELSE "Monitor"]
    /\ lastRetiredGeneration = [c \in CPUs |-> 0]
    /\ activeDomain = [c \in CPUs |-> InitialActiveDomain(c)]
    /\ activeEpoch =
        [c \in CPUs |-> IF InitialActiveDomain(c) = NoDomain THEN 0 ELSE 1]
    /\ activeGeneration = [c \in CPUs |-> InitialActiveGeneration(c)]
    /\ activeCpuIncarnation =
        [c \in CPUs |-> IF InitialActiveDomain(c) = NoDomain THEN 0 ELSE 1]
    /\ activeSource = [c \in CPUs |-> InitialActiveSource(c)]
    /\ trustedPins =
        [c \in CPUs |-> IF InitialActiveDomain(c) = NoDomain THEN 0 ELSE 1]
    /\ requestDomain = NoDomain
    /\ requestCPU = NoCPU
    /\ cursor = 1
    /\ cpuCursor = 1
    /\ served = {}
    /\ everResident = {}
    /\ waitTurns = [d \in Guaranteed |-> 0]
    /\ migrationDomain = NoDomain
    /\ migrationSource = NoCPU
    /\ migrationDestination = NoCPU
    /\ migrationPhase = "Idle"
    /\ exclusiveOwner = IF Scenario = "Migration" THEN C0 ELSE NoCPU
    /\ placementGeneration = 1
    /\ migrationActivated = FALSE
    /\ linuxProposal = BE1
    /\ linuxCPU = C1
    /\ linuxGeneration = 0
    /\ managementBindingSealed = (FaultMode # "ManagementBindingLost")
    /\ managementSource =
        IF FaultMode = "ManagementBindingLost" THEN "Linux" ELSE "Monitor"
    /\ unsafeEvictionObserved = FALSE
    /\ activationIssuedDuringRevoke = FALSE
    /\ revokingDomain = NoDomain
    /\ protectionClaim = FALSE

LinuxHintNoise ==
    /\ \E d \in DomainOrNone, c \in CPUs, g \in 0..MaxGeneration:
        /\ linuxProposal' = d
        /\ linuxCPU' = c
        /\ linuxGeneration' = g
    /\ UNCHANGED <<phase, directoryVars, cpuVars, slotVars, activeVars,
                    requestVars, migrationVars, controlVars>>

HardwareRelease(c) ==
    /\ FaultMode # "NoHardwareQuiesce"
    /\ c \in CPUs
    /\ activeDomain[c] # NoDomain
    /\ activeDomain' = [activeDomain EXCEPT ![c] = NoDomain]
    /\ activeEpoch' = [activeEpoch EXCEPT ![c] = 0]
    /\ activeGeneration' = [activeGeneration EXCEPT ![c] = 0]
    /\ activeCpuIncarnation' =
        [activeCpuIncarnation EXCEPT ![c] = 0]
    /\ activeSource' = [activeSource EXCEPT ![c] = "None"]
    /\ trustedPins' = [trustedPins EXCEPT ![c] = 0]
    /\ UNCHANGED <<phase, directoryVars, cpuVars, slotVars,
                    requestVars, migrationVars, linuxVars, controlVars>>

CurrentRequestedDomain == GuaranteedOrder[cursor]

IssueGuaranteedRequest ==
    /\ Scenario = "Admission"
    /\ phase = "AdmissionIdle"
    /\ cursor <= Len(GuaranteedOrder)
    /\ ~(FaultMode = "SkipGuaranteed" /\ cursor = 2)
    /\ (FaultMode # "WaitForLinuxHint" \/
        linuxProposal = CurrentRequestedDomain)
    /\ phase' = "AdmissionNeedResident"
    /\ requestDomain' = CurrentRequestedDomain
    /\ requestCPU' = NoCPU
    /\ UNCHANGED <<directoryVars, cpuVars, slotVars, activeVars,
                    cursor, cpuCursor, served, everResident, waitTurns,
                    migrationVars, linuxVars, controlVars>>

SkipGuaranteedRequest ==
    /\ Scenario = "Admission"
    /\ FaultMode = "SkipGuaranteed"
    /\ phase = "AdmissionIdle"
    /\ cursor = 2
    /\ cursor' = 3
    /\ UNCHANGED <<phase, directoryVars, cpuVars, slotVars, activeVars,
                    requestDomain, requestCPU, cpuCursor, served,
                    everResident, waitTurns, migrationVars, linuxVars,
                    controlVars>>

ResidentCPUs(d) ==
    {c \in CPUs:
        /\ online[c]
        /\ slotState[c] = "Resident"
        /\ slotDomain[c] = d
        /\ slotEpoch[c] = globalEpoch[d]
        /\ slotCpuIncarnation[c] = cpuIncarnation[c]
        /\ slotSealed[c]}

PreferredCPU == CPUOrder[cpuCursor]
OtherCPU == IF PreferredCPU = C0 THEN C1 ELSE C0
AdmissionTargetCPU ==
    IF accepting[PreferredCPU] THEN PreferredCPU
    ELSE IF accepting[OtherCPU] THEN OtherCPU
    ELSE NoCPU

PrepareResidentRequest ==
    /\ Scenario = "Admission"
    /\ phase = "AdmissionNeedResident"
    /\ requestDomain \in Guaranteed
    /\ IF ResidentCPUs(requestDomain) # {}
       THEN LET c == CHOOSE cpu \in ResidentCPUs(requestDomain): TRUE
            IN /\ requestCPU' = c
               /\ slotState' = [slotState EXCEPT ![c] = "Held"]
               /\ phase' = "AdmissionReady"
               /\ UNCHANGED <<slotDomain, slotEpoch, slotGeneration,
                               slotCpuIncarnation, slotSealed, slotSource,
                               lastRetiredGeneration>>
       ELSE LET c == AdmissionTargetCPU
            IN /\ c # NoCPU
               /\ requestCPU' = c
               /\ IF slotState[c] = "Empty"
                  THEN /\ phase' = "AdmissionBind"
                       /\ UNCHANGED slotVars
                  ELSE /\ phase' = "AdmissionDrain"
                       /\ slotState' =
                           [slotState EXCEPT ![c] = "Draining"]
                       /\ UNCHANGED <<slotDomain, slotEpoch,
                                       slotGeneration, slotCpuIncarnation,
                                       slotSealed, slotSource,
                                       lastRetiredGeneration>>
    /\ UNCHANGED <<directoryVars, cpuVars, activeVars,
                    requestDomain, cursor, cpuCursor, served,
                    everResident, waitTurns, migrationVars, linuxVars,
                    controlVars>>

RetireRequestSlot ==
    /\ Scenario = "Admission"
    /\ phase = "AdmissionDrain"
    /\ requestCPU \in CPUs
    /\ LET c == requestCPU IN
       /\ (FaultMode = "EvictPinned" \/
           (activeDomain[c] = NoDomain /\ trustedPins[c] = 0))
       /\ slotState' = [slotState EXCEPT ![c] = "Empty"]
       /\ slotDomain' = [slotDomain EXCEPT ![c] = NoDomain]
       /\ slotEpoch' = [slotEpoch EXCEPT ![c] = 0]
       /\ slotGeneration' = [slotGeneration EXCEPT ![c] = 0]
       /\ slotCpuIncarnation' =
           [slotCpuIncarnation EXCEPT ![c] = 0]
       /\ slotSealed' = [slotSealed EXCEPT ![c] = FALSE]
       /\ slotSource' = [slotSource EXCEPT ![c] = "None"]
       /\ lastRetiredGeneration' =
           [lastRetiredGeneration EXCEPT ![c] = slotGeneration[c]]
       /\ unsafeEvictionObserved' =
           (unsafeEvictionObserved \/
            activeDomain[c] # NoDomain \/ trustedPins[c] # 0)
    /\ phase' = "AdmissionBind"
    /\ UNCHANGED <<directoryVars, cpuVars, activeVars, requestVars,
                    migrationVars, linuxVars, managementBindingSealed,
                    managementSource, activationIssuedDuringRevoke,
                    revokingDomain, protectionClaim>>

BindRequest ==
    /\ Scenario = "Admission"
    /\ phase = "AdmissionBind"
    /\ requestCPU \in CPUs
    /\ LET c == requestCPU IN
       LET d == IF FaultMode = "BestEffortOverwrite"
                THEN BE1 ELSE requestDomain
       IN /\ slotState[c] = "Empty"
          /\ lastRetiredGeneration[c] < MaxGeneration
          /\ slotState' = [slotState EXCEPT ![c] = "Held"]
          /\ slotDomain' = [slotDomain EXCEPT ![c] = d]
          /\ slotEpoch' =
              [slotEpoch EXCEPT
                  ![c] = IF FaultMode = "StaleEpochBinding"
                          THEN 0 ELSE globalEpoch[d]]
          /\ slotGeneration' =
              [slotGeneration EXCEPT
                  ![c] = IF FaultMode = "ReuseGeneration"
                          THEN lastRetiredGeneration[c]
                          ELSE lastRetiredGeneration[c] + 1]
          /\ slotCpuIncarnation' =
              [slotCpuIncarnation EXCEPT ![c] = cpuIncarnation[c]]
          /\ slotSealed' =
              [slotSealed EXCEPT
                  ![c] = (FaultMode # "PublishBeforeSeal")]
          /\ slotSource' =
              [slotSource EXCEPT
                  ![c] = IF FaultMode = "LinuxOwnsBinding"
                          THEN "Linux" ELSE "Monitor"]
          /\ UNCHANGED lastRetiredGeneration
          /\ everResident' = everResident \union {requestDomain}
    /\ phase' = "AdmissionReady"
    /\ UNCHANGED <<directoryVars, cpuVars, activeVars,
                    requestDomain, requestCPU, cursor, cpuCursor,
                    served, waitTurns, migrationVars, linuxVars,
                    controlVars>>

AdvanceWait(servedDomain) ==
    [d \in Guaranteed |->
        IF d = servedDomain \/ d \in served THEN 0
        ELSE waitTurns[d] + 1]

ActivateRequest ==
    /\ Scenario = "Admission"
    /\ phase = "AdmissionReady"
    /\ requestCPU \in CPUs
    /\ requestDomain \in Guaranteed
    /\ LET c == requestCPU IN
       /\ activeDomain[c] = NoDomain
       /\ slotState[c] = "Held"
       /\ IF FaultMode = "TrustStaleHandle"
          THEN /\ activeDomain' =
                      [activeDomain EXCEPT ![c] = linuxProposal]
               /\ activeEpoch' = [activeEpoch EXCEPT ![c] = 0]
               /\ activeGeneration' =
                      [activeGeneration EXCEPT ![c] = linuxGeneration]
               /\ activeCpuIncarnation' =
                      [activeCpuIncarnation EXCEPT ![c] = cpuIncarnation[c]]
               /\ activeSource' =
                      [activeSource EXCEPT ![c] = "Linux"]
          ELSE /\ activeDomain' =
                      [activeDomain EXCEPT ![c] = requestDomain]
               /\ activeEpoch' =
                      [activeEpoch EXCEPT ![c] = slotEpoch[c]]
               /\ activeGeneration' =
                      [activeGeneration EXCEPT ![c] = slotGeneration[c]]
               /\ activeCpuIncarnation' =
                      [activeCpuIncarnation EXCEPT
                          ![c] = slotCpuIncarnation[c]]
               /\ activeSource' =
                      [activeSource EXCEPT
                          ![c] = IF FaultMode = "ResidentSlotIsAuthority"
                                  THEN "ResidentSlot" ELSE "Monitor"]
       /\ trustedPins' = [trustedPins EXCEPT ![c] = 1]
       /\ slotState' = [slotState EXCEPT ![c] = "Resident"]
       /\ UNCHANGED <<slotDomain, slotEpoch, slotGeneration,
                       slotCpuIncarnation, slotSealed, slotSource,
                       lastRetiredGeneration>>
    /\ served' = served \union {requestDomain}
    /\ everResident' = everResident \union {requestDomain}
    /\ waitTurns' = AdvanceWait(requestDomain)
    /\ requestDomain' = NoDomain
    /\ requestCPU' = NoCPU
    /\ cursor' = cursor + 1
    /\ cpuCursor' = IF cpuCursor = Len(CPUOrder) THEN 1 ELSE cpuCursor + 1
    /\ phase' =
        IF cursor = Len(GuaranteedOrder)
        THEN "AdmissionDone" ELSE "AdmissionIdle"
    /\ UNCHANGED <<directoryVars, cpuVars, migrationVars, linuxVars,
                    controlVars>>

BeginExclusiveMigration ==
    /\ Scenario = "Migration"
    /\ phase = "MigrationReady"
    /\ FaultMode \notin
        {"CopyBeforeSourceFence", "DestinationBeforeSourceStop"}
    /\ phase' = "MigrationDrain"
    /\ migrationDomain' = G1
    /\ migrationSource' = C0
    /\ migrationDestination' = C1
    /\ migrationPhase' = "DrainSource"
    /\ migrationActivated' = FALSE
    /\ slotState' = [slotState EXCEPT ![C0] = "Draining"]
    /\ UNCHANGED <<directoryVars, cpuVars, slotDomain, slotEpoch,
                    slotGeneration, slotCpuIncarnation, slotSealed,
                    slotSource, lastRetiredGeneration, activeVars,
                    requestVars, exclusiveOwner, placementGeneration,
                    linuxVars, controlVars>>

CopyMigrationBeforeFence ==
    /\ Scenario = "Migration"
    /\ FaultMode = "CopyBeforeSourceFence"
    /\ phase = "MigrationReady"
    /\ phase' = "MigrationCopied"
    /\ migrationDomain' = G1
    /\ migrationSource' = C0
    /\ migrationDestination' = C1
    /\ migrationPhase' = "CopiedBeforeFence"
    /\ migrationActivated' = FALSE
    /\ slotState' = [slotState EXCEPT ![C1] = "Held"]
    /\ slotDomain' = [slotDomain EXCEPT ![C1] = G1]
    /\ slotEpoch' = [slotEpoch EXCEPT ![C1] = globalEpoch[G1]]
    /\ slotGeneration' = [slotGeneration EXCEPT ![C1] = 1]
    /\ slotCpuIncarnation' =
        [slotCpuIncarnation EXCEPT ![C1] = cpuIncarnation[C1]]
    /\ slotSealed' = [slotSealed EXCEPT ![C1] = TRUE]
    /\ slotSource' = [slotSource EXCEPT ![C1] = "Monitor"]
    /\ UNCHANGED <<directoryVars, cpuVars, lastRetiredGeneration,
                    activeVars, requestVars, exclusiveOwner,
                    placementGeneration, linuxVars, controlVars>>

ActivateDestinationBeforeStop ==
    /\ Scenario = "Migration"
    /\ FaultMode = "DestinationBeforeSourceStop"
    /\ phase = "MigrationReady"
    /\ phase' = "MigrationDestinationActiveEarly"
    /\ migrationDomain' = G1
    /\ migrationSource' = C0
    /\ migrationDestination' = C1
    /\ migrationPhase' = "DestinationActiveBeforeSourceStop"
    /\ migrationActivated' = TRUE
    /\ slotState' = [slotState EXCEPT ![C1] = "Resident"]
    /\ slotDomain' = [slotDomain EXCEPT ![C1] = G1]
    /\ slotEpoch' = [slotEpoch EXCEPT ![C1] = globalEpoch[G1]]
    /\ slotGeneration' = [slotGeneration EXCEPT ![C1] = 1]
    /\ slotCpuIncarnation' =
        [slotCpuIncarnation EXCEPT ![C1] = cpuIncarnation[C1]]
    /\ slotSealed' = [slotSealed EXCEPT ![C1] = TRUE]
    /\ slotSource' = [slotSource EXCEPT ![C1] = "Monitor"]
    /\ activeDomain' = [activeDomain EXCEPT ![C1] = G1]
    /\ activeEpoch' = [activeEpoch EXCEPT ![C1] = globalEpoch[G1]]
    /\ activeGeneration' = [activeGeneration EXCEPT ![C1] = 1]
    /\ activeCpuIncarnation' =
        [activeCpuIncarnation EXCEPT ![C1] = cpuIncarnation[C1]]
    /\ activeSource' = [activeSource EXCEPT ![C1] = "Monitor"]
    /\ trustedPins' = [trustedPins EXCEPT ![C1] = 1]
    /\ UNCHANGED <<directoryVars, cpuVars, lastRetiredGeneration,
                    requestVars, exclusiveOwner, placementGeneration,
                    linuxVars, controlVars>>

RetireMigrationSource ==
    /\ Scenario = "Migration"
    /\ phase = "MigrationDrain"
    /\ activeDomain[C0] = NoDomain
    /\ trustedPins[C0] = 0
    /\ phase' = "MigrationSourceNeutral"
    /\ migrationPhase' = "SourceNeutral"
    /\ slotState' = [slotState EXCEPT ![C0] = "Empty"]
    /\ slotDomain' = [slotDomain EXCEPT ![C0] = NoDomain]
    /\ slotEpoch' = [slotEpoch EXCEPT ![C0] = 0]
    /\ slotGeneration' = [slotGeneration EXCEPT ![C0] = 0]
    /\ slotCpuIncarnation' = [slotCpuIncarnation EXCEPT ![C0] = 0]
    /\ slotSealed' = [slotSealed EXCEPT ![C0] = FALSE]
    /\ slotSource' = [slotSource EXCEPT ![C0] = "None"]
    /\ lastRetiredGeneration' =
        [lastRetiredGeneration EXCEPT ![C0] = slotGeneration[C0]]
    /\ exclusiveOwner' = NoCPU
    /\ UNCHANGED <<directoryVars, cpuVars, activeVars, requestVars,
                    migrationDomain, migrationSource,
                    migrationDestination, placementGeneration,
                    migrationActivated, linuxVars, controlVars>>

InstallMigrationDestination ==
    /\ Scenario = "Migration"
    /\ phase = "MigrationSourceNeutral"
    /\ slotState[C1] = "Empty"
    /\ phase' = "MigrationDestinationReady"
    /\ migrationPhase' = "DestinationReady"
    /\ slotState' = [slotState EXCEPT ![C1] = "Held"]
    /\ slotDomain' =
        [slotDomain EXCEPT
            ![C1] = IF FaultMode = "MigrationIdentityDrift" THEN G2 ELSE G1]
    /\ slotEpoch' =
        [slotEpoch EXCEPT
            ![C1] = IF FaultMode = "MigrationIdentityDrift"
                    THEN globalEpoch[G2] ELSE globalEpoch[G1]]
    /\ slotGeneration' =
        [slotGeneration EXCEPT ![C1] = lastRetiredGeneration[C1] + 1]
    /\ slotCpuIncarnation' =
        [slotCpuIncarnation EXCEPT ![C1] = cpuIncarnation[C1]]
    /\ slotSealed' = [slotSealed EXCEPT ![C1] = TRUE]
    /\ slotSource' = [slotSource EXCEPT ![C1] = "Monitor"]
    /\ UNCHANGED lastRetiredGeneration
    /\ exclusiveOwner' = C1
    /\ placementGeneration' = 2
    /\ UNCHANGED <<directoryVars, cpuVars, activeVars, requestVars,
                    migrationDomain, migrationSource,
                    migrationDestination, migrationActivated,
                    linuxVars, controlVars>>

ActivateMigrationDestination ==
    /\ Scenario = "Migration"
    /\ phase = "MigrationDestinationReady"
    /\ activeDomain[C1] = NoDomain
    /\ phase' = "MigrationDone"
    /\ migrationPhase' = "Done"
    /\ migrationActivated' = TRUE
    /\ activeDomain' = [activeDomain EXCEPT ![C1] = slotDomain[C1]]
    /\ activeEpoch' = [activeEpoch EXCEPT ![C1] = slotEpoch[C1]]
    /\ activeGeneration' =
        [activeGeneration EXCEPT ![C1] = slotGeneration[C1]]
    /\ activeCpuIncarnation' =
        [activeCpuIncarnation EXCEPT ![C1] = slotCpuIncarnation[C1]]
    /\ activeSource' = [activeSource EXCEPT ![C1] = "Monitor"]
    /\ trustedPins' = [trustedPins EXCEPT ![C1] = 1]
    /\ slotState' = [slotState EXCEPT ![C1] = "Resident"]
    /\ UNCHANGED <<directoryVars, cpuVars, slotDomain, slotEpoch,
                    slotGeneration, slotCpuIncarnation, slotSealed,
                    slotSource, lastRetiredGeneration, requestVars,
                    migrationDomain, migrationSource,
                    migrationDestination, exclusiveOwner,
                    placementGeneration, linuxVars, controlVars>>

BeginCpuOffline ==
    /\ Scenario = "Hotplug"
    /\ phase = "HotplugReady"
    /\ accepting' = [accepting EXCEPT ![C1] = FALSE]
    /\ IF FaultMode = "OfflineBeforeDrain"
       THEN /\ online' = [online EXCEPT ![C1] = FALSE]
            /\ phase' = "HotplugBad"
            /\ UNCHANGED slotVars
       ELSE /\ UNCHANGED online
            /\ phase' = "HotplugDrain"
            /\ slotState' = [slotState EXCEPT ![C1] = "Draining"]
            /\ UNCHANGED <<slotDomain, slotEpoch, slotGeneration,
                            slotCpuIncarnation, slotSealed, slotSource,
                            lastRetiredGeneration>>
    /\ UNCHANGED <<directoryVars, onlineSource, cpuIncarnation,
                    activeVars, requestVars, migrationVars, linuxVars,
                    controlVars>>

RetireHotplugSlot ==
    /\ Scenario = "Hotplug"
    /\ phase = "HotplugDrain"
    /\ activeDomain[C1] = NoDomain
    /\ trustedPins[C1] = 0
    /\ phase' = "HotplugRetired"
    /\ slotState' = [slotState EXCEPT ![C1] = "Empty"]
    /\ slotDomain' = [slotDomain EXCEPT ![C1] = NoDomain]
    /\ slotEpoch' = [slotEpoch EXCEPT ![C1] = 0]
    /\ slotGeneration' = [slotGeneration EXCEPT ![C1] = 0]
    /\ slotCpuIncarnation' = [slotCpuIncarnation EXCEPT ![C1] = 0]
    /\ slotSealed' = [slotSealed EXCEPT ![C1] = FALSE]
    /\ slotSource' = [slotSource EXCEPT ![C1] = "None"]
    /\ lastRetiredGeneration' =
        [lastRetiredGeneration EXCEPT ![C1] = slotGeneration[C1]]
    /\ UNCHANGED <<directoryVars, cpuVars, activeVars, requestVars,
                    migrationVars, linuxVars, controlVars>>

FinishCpuOffline ==
    /\ Scenario = "Hotplug"
    /\ phase = "HotplugRetired"
    /\ phase' = "HotplugOffline"
    /\ online' = [online EXCEPT ![C1] = FALSE]
    /\ onlineSource' = [onlineSource EXCEPT ![C1] = "Monitor"]
    /\ UNCHANGED <<directoryVars, accepting, cpuIncarnation,
                    slotVars, activeVars, requestVars, migrationVars,
                    linuxVars, controlVars>>

BeginCpuOnline ==
    /\ Scenario = "Hotplug"
    /\ phase = "HotplugOffline"
    /\ phase' = "HotplugDone"
    /\ online' = [online EXCEPT ![C1] = TRUE]
    /\ accepting' = [accepting EXCEPT ![C1] = TRUE]
    /\ onlineSource' =
        [onlineSource EXCEPT
            ![C1] = IF FaultMode = "LinuxMintsOnlineCPU"
                    THEN "Linux" ELSE "Monitor"]
    /\ cpuIncarnation' =
        [cpuIncarnation EXCEPT
            ![C1] = IF FaultMode = "ReuseCpuIncarnation"
                    THEN cpuIncarnation[C1] ELSE cpuIncarnation[C1] + 1]
    /\ lastRetiredGeneration' =
        [lastRetiredGeneration EXCEPT ![C1] = 0]
    /\ UNCHANGED <<directoryVars, slotState, slotDomain, slotEpoch,
                    slotGeneration, slotCpuIncarnation, slotSealed,
                    slotSource, activeVars, requestVars, migrationVars,
                    linuxVars, controlVars>>

BeginDomainRevoke ==
    /\ Scenario = "Revoke"
    /\ phase = "RevokeReady"
    /\ phase' = "RevokeDrain"
    /\ revokingDomain' = G2
    /\ activationIssuedDuringRevoke' =
        (FaultMode = "ActivateDuringRevoke")
    /\ lifecycle' =
        [lifecycle EXCEPT
            ![G2] = IF FaultMode = "EpochBeforeDrain"
                    THEN "Revoked" ELSE "Revoking"]
    /\ globalEpoch' =
        [globalEpoch EXCEPT
            ![G2] = IF FaultMode = "EpochBeforeDrain"
                    THEN 2 ELSE @]
    /\ admitted' =
        [admitted EXCEPT
            ![G2] = IF FaultMode = "EpochBeforeDrain" THEN FALSE ELSE @]
    /\ slotState' =
        [c \in CPUs |-> IF slotDomain[c] = G2 THEN "Draining"
                        ELSE slotState[c]]
    /\ UNCHANGED <<registrySource, cpuVars, slotDomain, slotEpoch,
                    slotGeneration, slotCpuIncarnation, slotSealed,
                    slotSource, lastRetiredGeneration, activeVars,
                    requestVars, migrationVars, linuxVars,
                    managementBindingSealed, managementSource,
                    unsafeEvictionObserved, protectionClaim>>

RetireRevokedBinding ==
    /\ Scenario = "Revoke"
    /\ phase = "RevokeDrain"
    /\ \E c \in CPUs:
        /\ slotDomain[c] = G2
        /\ activeDomain[c] = NoDomain
        /\ trustedPins[c] = 0
        /\ slotState' = [slotState EXCEPT ![c] = "Empty"]
        /\ slotDomain' = [slotDomain EXCEPT ![c] = NoDomain]
        /\ slotEpoch' = [slotEpoch EXCEPT ![c] = 0]
        /\ slotGeneration' = [slotGeneration EXCEPT ![c] = 0]
        /\ slotCpuIncarnation' =
            [slotCpuIncarnation EXCEPT ![c] = 0]
        /\ slotSealed' = [slotSealed EXCEPT ![c] = FALSE]
        /\ slotSource' = [slotSource EXCEPT ![c] = "None"]
        /\ lastRetiredGeneration' =
            [lastRetiredGeneration EXCEPT ![c] = slotGeneration[c]]
    /\ UNCHANGED <<phase, directoryVars, cpuVars, activeVars,
                    requestVars, migrationVars, linuxVars, controlVars>>

CompleteDomainRevoke ==
    /\ Scenario = "Revoke"
    /\ phase = "RevokeDrain"
    /\ \A c \in CPUs:
        slotDomain[c] # G2 /\ activeDomain[c] # G2
    /\ phase' = "RevokeDone"
    /\ lifecycle' = [lifecycle EXCEPT ![G2] = "Revoked"]
    /\ globalEpoch' = [globalEpoch EXCEPT ![G2] = 2]
    /\ admitted' = [admitted EXCEPT ![G2] = FALSE]
    /\ revokingDomain' = NoDomain
    /\ UNCHANGED <<registrySource, cpuVars, slotVars, activeVars,
                    requestVars, migrationVars, linuxVars,
                    managementBindingSealed, managementSource,
                    unsafeEvictionObserved, activationIssuedDuringRevoke,
                    protectionClaim>>

Next ==
    \/ LinuxHintNoise
    \/ \E c \in CPUs: HardwareRelease(c)
    \/ IssueGuaranteedRequest
    \/ SkipGuaranteedRequest
    \/ PrepareResidentRequest
    \/ RetireRequestSlot
    \/ BindRequest
    \/ ActivateRequest
    \/ BeginExclusiveMigration
    \/ CopyMigrationBeforeFence
    \/ ActivateDestinationBeforeStop
    \/ RetireMigrationSource
    \/ InstallMigrationDestination
    \/ ActivateMigrationDestination
    \/ BeginCpuOffline
    \/ RetireHotplugSlot
    \/ FinishCpuOffline
    \/ BeginCpuOnline
    \/ BeginDomainRevoke
    \/ RetireRevokedBinding
    \/ CompleteDomainRevoke

Spec ==
    /\ Init
    /\ [][Next]_vars
    /\ \A c \in CPUs: WF_vars(HardwareRelease(c))
    /\ WF_vars(IssueGuaranteedRequest)
    /\ WF_vars(SkipGuaranteedRequest)
    /\ WF_vars(PrepareResidentRequest)
    /\ WF_vars(RetireRequestSlot)
    /\ WF_vars(BindRequest)
    /\ WF_vars(ActivateRequest)
    /\ WF_vars(BeginExclusiveMigration)
    /\ WF_vars(CopyMigrationBeforeFence)
    /\ WF_vars(ActivateDestinationBeforeStop)
    /\ WF_vars(RetireMigrationSource)
    /\ WF_vars(InstallMigrationDestination)
    /\ WF_vars(ActivateMigrationDestination)
    /\ WF_vars(BeginCpuOffline)
    /\ WF_vars(RetireHotplugSlot)
    /\ WF_vars(FinishCpuOffline)
    /\ WF_vars(BeginCpuOnline)
    /\ WF_vars(BeginDomainRevoke)
    /\ WF_vars(RetireRevokedBinding)
    /\ WF_vars(CompleteDomainRevoke)

TypeOK ==
    /\ Scenario \in Scenarios
    /\ FaultMode \in FaultModes
    /\ phase \in {
        "AdmissionIdle", "AdmissionNeedResident", "AdmissionDrain",
        "AdmissionBind", "AdmissionReady", "AdmissionDone",
        "MigrationReady", "MigrationDrain", "MigrationSourceNeutral",
        "MigrationDestinationReady", "MigrationDone", "MigrationCopied",
        "MigrationDestinationActiveEarly",
        "HotplugReady", "HotplugDrain", "HotplugRetired",
        "HotplugOffline", "HotplugDone", "HotplugBad",
        "RevokeReady", "RevokeDrain", "RevokeDone"}
    /\ globalEpoch \in [Domains -> 1..MaxEpoch]
    /\ lifecycle \in [Domains -> {"Active", "Revoking", "Revoked"}]
    /\ admitted \in [Domains -> BOOLEAN]
    /\ registrySource \in {"Monitor", "Linux"}
    /\ online \in [CPUs -> BOOLEAN]
    /\ accepting \in [CPUs -> BOOLEAN]
    /\ onlineSource \in [CPUs -> {"Monitor", "Linux"}]
    /\ cpuIncarnation \in [CPUs -> 1..MaxCpuIncarnation]
    /\ slotState \in
        [CPUs -> {"Empty", "Resident", "Held", "Draining"}]
    /\ slotDomain \in [CPUs -> DomainOrNone]
    /\ slotEpoch \in [CPUs -> 0..MaxEpoch]
    /\ slotGeneration \in [CPUs -> 0..MaxGeneration]
    /\ slotCpuIncarnation \in [CPUs -> 0..MaxCpuIncarnation]
    /\ slotSealed \in [CPUs -> BOOLEAN]
    /\ slotSource \in [CPUs -> {"None", "Monitor", "Linux"}]
    /\ lastRetiredGeneration \in [CPUs -> 0..MaxGeneration]
    /\ activeDomain \in [CPUs -> DomainOrNone]
    /\ activeEpoch \in [CPUs -> 0..MaxEpoch]
    /\ activeGeneration \in [CPUs -> 0..MaxGeneration]
    /\ activeCpuIncarnation \in [CPUs -> 0..MaxCpuIncarnation]
    /\ activeSource \in
        [CPUs -> {"None", "Monitor", "Linux", "ResidentSlot"}]
    /\ trustedPins \in [CPUs -> 0..1]
    /\ requestDomain \in DomainOrNone
    /\ requestCPU \in CPUOrNone
    /\ cursor \in 1..(Len(GuaranteedOrder) + 1)
    /\ cpuCursor \in 1..Len(CPUOrder)
    /\ served \subseteq Guaranteed
    /\ everResident \subseteq Guaranteed
    /\ waitTurns \in [Guaranteed -> 0..(MaxWaitTurns + 1)]
    /\ migrationDomain \in DomainOrNone
    /\ migrationSource \in CPUOrNone
    /\ migrationDestination \in CPUOrNone
    /\ migrationPhase \in {
        "Idle", "DrainSource", "SourceNeutral", "DestinationReady",
        "Done", "CopiedBeforeFence", "DestinationActiveBeforeSourceStop"}
    /\ exclusiveOwner \in CPUOrNone
    /\ placementGeneration \in 1..2
    /\ migrationActivated \in BOOLEAN
    /\ linuxProposal \in DomainOrNone
    /\ linuxCPU \in CPUs
    /\ linuxGeneration \in 0..MaxGeneration
    /\ managementBindingSealed \in BOOLEAN
    /\ managementSource \in {"Monitor", "Linux"}
    /\ unsafeEvictionObserved \in BOOLEAN
    /\ activationIssuedDuringRevoke \in BOOLEAN
    /\ revokingDomain \in DomainOrNone
    /\ protectionClaim \in BOOLEAN

GlobalPopulationExceedsResidentCapacity ==
    Cardinality(OrdinaryDomains) > Cardinality(CPUs)

MonitorOwnsGlobalRegistry == registrySource = "Monitor"

MonitorOwnsCPUOnlineState ==
    \A c \in CPUs: onlineSource[c] = "Monitor"

EmptyBindingExact ==
    \A c \in CPUs:
        slotState[c] = "Empty" =>
            /\ slotDomain[c] = NoDomain
            /\ slotEpoch[c] = 0
            /\ slotGeneration[c] = 0
            /\ slotCpuIncarnation[c] = 0
            /\ ~slotSealed[c]
            /\ slotSource[c] = "None"

MonitorOwnsResidentBindings ==
    \A c \in CPUs:
        slotState[c] # "Empty" => slotSource[c] = "Monitor"

ResidentEpochCurrent ==
    \A c \in CPUs:
        slotState[c] # "Empty" =>
            /\ slotDomain[c] \in OrdinaryDomains
            /\ admitted[slotDomain[c]]
            /\ lifecycle[slotDomain[c]] # "Revoked"
            /\ slotEpoch[c] = globalEpoch[slotDomain[c]]
            /\ slotCpuIncarnation[c] = cpuIncarnation[c]
            /\ slotSealed[c]

ResidentBindingSealed ==
    \A c \in CPUs:
        slotState[c] # "Empty" => slotSealed[c]

SlotGenerationFresh ==
    \A c \in CPUs:
        slotState[c] # "Empty" =>
            /\ slotGeneration[c] > lastRetiredGeneration[c]
            /\ slotGeneration[c] <= MaxGeneration

NoSlotAlias ==
    /\ SlotGenerationFresh
    /\ \A c \in CPUs:
        slotState[c] # "Empty" =>
            slotCpuIncarnation[c] = cpuIncarnation[c]

ActiveBindingExact ==
    \A c \in CPUs:
        activeDomain[c] # NoDomain =>
            /\ online[c]
            /\ slotState[c] # "Empty"
            /\ slotDomain[c] = activeDomain[c]
            /\ slotEpoch[c] = activeEpoch[c]
            /\ globalEpoch[activeDomain[c]] = activeEpoch[c]
            /\ slotGeneration[c] = activeGeneration[c]
            /\ slotCpuIncarnation[c] = activeCpuIncarnation[c]
            /\ cpuIncarnation[c] = activeCpuIncarnation[c]
            /\ slotSealed[c]
            /\ activeSource[c] = "Monitor"
            /\ trustedPins[c] = 1

NoEvictWhileRunningOrReferenced == ~unsafeEvictionObserved

HeldBindingMatchesRequest ==
    \A c \in CPUs:
        slotState[c] = "Held" =>
            /\ (c = requestCPU \/
                (Scenario = "Migration" /\ c = migrationDestination))
            /\ slotSealed[c]
            /\ slotSource[c] = "Monitor"
            /\ (slotDomain[c] = requestDomain \/
                slotDomain[c] = migrationDomain)

NoDuplicateExclusiveResidency ==
    \A d \in ExclusiveDomains:
        Cardinality({c \in CPUs:
            slotState[c] # "Empty" /\ slotDomain[c] = d}) <= 1

ExclusiveAuthoritySingleCPU ==
    \A d \in ExclusiveDomains:
        Cardinality({c \in CPUs: activeDomain[c] = d}) <= 1

MigrationPreservesIdentityAndAuthority ==
    phase = "MigrationDone" =>
        /\ migrationDomain = G1
        /\ migrationSource = C0
        /\ migrationDestination = C1
        /\ migrationPhase = "Done"
        /\ slotDomain[C0] # G1
        /\ slotDomain[C1] = G1
        /\ slotEpoch[C1] = globalEpoch[G1]
        /\ exclusiveOwner = C1
        /\ placementGeneration = 2
        /\ migrationActivated

OfflineCPUHasNoAuthority ==
    \A c \in CPUs:
        ~online[c] =>
            /\ ~accepting[c]
            /\ slotState[c] = "Empty"
            /\ activeDomain[c] = NoDomain
            /\ trustedPins[c] = 0

HotplugCreatesFreshCpuIncarnation ==
    phase = "HotplugDone" =>
        /\ cpuIncarnation[C1] = 2
        /\ onlineSource[C1] = "Monitor"

NoActivationIssuedDuringRevocation == ~activationIssuedDuringRevoke

ManagementRecoveryIndependent ==
    /\ managementBindingSealed
    /\ managementSource = "Monitor"
    /\ Mgmt \notin {slotDomain[c]: c \in CPUs}

BoundedGuaranteedWait ==
    \A d \in Guaranteed: waitTurns[d] <= MaxWaitTurns

NoProtectionClaim == ~protectionClaim

GuaranteedDomainsEventuallyReceiveResidentActivation ==
    Scenario # "Admission" \/
        \A d \in Guaranteed: <> (d \in served)

PendingGuaranteedRequestEventuallyCompletes ==
    Scenario # "Admission" \/
        \A d \in Guaranteed:
            [](requestDomain = d => <> (d \in served))

ExclusiveMigrationEventuallyCompletes ==
    Scenario # "Migration" \/ <> (phase = "MigrationDone")

HotplugEventuallyQuiesces ==
    Scenario # "Hotplug" \/ <> (phase = "HotplugDone")

RevocationEventuallyCommits ==
    Scenario # "Revoke" \/ <> (phase = "RevokeDone")

=============================================================================
