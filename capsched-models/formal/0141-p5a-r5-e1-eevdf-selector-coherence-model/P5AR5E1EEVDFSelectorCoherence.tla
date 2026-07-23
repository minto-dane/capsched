---------- MODULE P5AR5E1EEVDFSelectorCoherence ----------
EXTENDS Naturals

CONSTANT TrustStale

VARIABLES phase, authorityGeneration, selectorVersion, viewVersion,
          allowedRunnable, selectedAllowed, staleTrusted

vars == <<phase, authorityGeneration, selectorVersion, viewVersion,
          allowedRunnable, selectedAllowed, staleTrusted>>

Init ==
    /\ phase = "Installed"
    /\ authorityGeneration = 1
    /\ selectorVersion = 1
    /\ viewVersion = 1
    /\ allowedRunnable = TRUE
    /\ selectedAllowed = FALSE
    /\ staleTrusted = FALSE

OrdinarySchedulerMutation ==
    /\ phase = "Installed"
    /\ phase' = "Mutated"
    /\ selectorVersion' = 2
    /\ UNCHANGED <<authorityGeneration, viewVersion, allowedRunnable,
                    selectedAllowed, staleTrusted>>

PickAfterMutation ==
    /\ phase = "Mutated"
    /\ phase' = "Done"
    /\ staleTrusted' = TrustStale /\ viewVersion # selectorVersion
    /\ selectedAllowed' = IF TrustStale THEN TRUE ELSE FALSE
    /\ UNCHANGED <<authorityGeneration, selectorVersion, viewVersion,
                    allowedRunnable>>

Next == OrdinarySchedulerMutation \/ PickAfterMutation

Spec ==
    /\ Init
    /\ [][Next]_vars
    /\ WF_vars(OrdinarySchedulerMutation)
    /\ WF_vars(PickAfterMutation)

TypeOK ==
    /\ phase \in {"Installed", "Mutated", "Done"}
    /\ authorityGeneration = 1
    /\ selectorVersion \in 1..2
    /\ viewVersion = 1
    /\ allowedRunnable \in BOOLEAN
    /\ selectedAllowed \in BOOLEAN
    /\ staleTrusted \in BOOLEAN

Safety ==
    /\ ~staleTrusted
    /\ (selectedAllowed => viewVersion = selectorVersion)

AllowedProgress ==
    [](phase = "Mutated" /\ allowedRunnable => <>selectedAllowed)

=============================================================================
