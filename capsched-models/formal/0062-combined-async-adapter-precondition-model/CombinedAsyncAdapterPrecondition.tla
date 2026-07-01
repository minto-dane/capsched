-------------------- MODULE CombinedAsyncAdapterPrecondition --------------------

CONSTANTS
    ALLOW_UNSAFE_PATCH_BEFORE_WORKQUEUE,
    ALLOW_UNSAFE_PATCH_BEFORE_IOURING,
    ALLOW_UNSAFE_BROAD_MODEL_ONLY,
    ALLOW_UNSAFE_SHARED_CORE_GENERIC_ASYNC,
    ALLOW_UNSAFE_CROSS_ADAPTER_COLLAPSE,
    ALLOW_UNSAFE_LINUX_OBJECT_AUTHORITY,
    ALLOW_UNSAFE_MISSING_EVIDENCE_SPLIT,
    ALLOW_UNSAFE_ABI_APPROVAL,
    ALLOW_UNSAFE_BEHAVIOR_CHANGE,
    ALLOW_UNSAFE_MONITOR_VERIFIED,
    ALLOW_UNSAFE_PROTECTION_CLAIM

VARIABLE state

vars == <<state>>

Phases == {
    "Start",
    "SharedCoreChecked",
    "WorkqueueChecked",
    "IoUringChecked",
    "AdaptersSeparated",
    "AuthorityAndBudgetChecked",
    "RevokeAndEvidenceChecked",
    "CandidatePatchProposalAllowed",
    "Accepted",
    "BadPatchBeforeWorkqueue",
    "BadPatchBeforeIoUring",
    "BadBroadModelOnly",
    "BadSharedCoreGenericAsync",
    "BadCrossAdapterCollapse",
    "BadLinuxObjectAuthority",
    "BadMissingEvidenceSplit",
    "BadAbiApproval",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

TerminalPhases == {
    "Accepted",
    "BadPatchBeforeWorkqueue",
    "BadPatchBeforeIoUring",
    "BadBroadModelOnly",
    "BadSharedCoreGenericAsync",
    "BadCrossAdapterCollapse",
    "BadLinuxObjectAuthority",
    "BadMissingEvidenceSplit",
    "BadAbiApproval",
    "BadBehaviorChange",
    "BadMonitorVerified",
    "BadProtectionClaim"
}

StateFields == {
    "phase",
    "sharedCoreChecked",
    "workqueueChecked",
    "ioUringChecked",
    "adapterMechanicsSeparated",
    "authorityIntersectionChecked",
    "callerBudgetSettlementChecked",
    "revokeFreshnessChecked",
    "sourceDriftChecked",
    "evidenceSplitChecked",
    "candidatePatchProposalAllowed",
    "linuxCodeApproved",
    "sharedCoreGenericAsync",
    "crossAdapterCollapse",
    "linuxObjectAuthorityAllowed",
    "abiApproved",
    "behaviorChange",
    "monitorVerified",
    "protectionClaim",
    "accepted"
}

NonBoolFields == {"phase"}
BoolFields == StateFields \ NonBoolFields

TypeOK ==
    /\ DOMAIN state = StateFields
    /\ state.phase \in Phases
    /\ \A f \in BoolFields : state[f] \in BOOLEAN

Init ==
    state = [
        phase |-> "Start",
        sharedCoreChecked |-> FALSE,
        workqueueChecked |-> FALSE,
        ioUringChecked |-> FALSE,
        adapterMechanicsSeparated |-> FALSE,
        authorityIntersectionChecked |-> FALSE,
        callerBudgetSettlementChecked |-> FALSE,
        revokeFreshnessChecked |-> FALSE,
        sourceDriftChecked |-> FALSE,
        evidenceSplitChecked |-> FALSE,
        candidatePatchProposalAllowed |-> FALSE,
        linuxCodeApproved |-> FALSE,
        sharedCoreGenericAsync |-> FALSE,
        crossAdapterCollapse |-> FALSE,
        linuxObjectAuthorityAllowed |-> FALSE,
        abiApproved |-> FALSE,
        behaviorChange |-> FALSE,
        monitorVerified |-> FALSE,
        protectionClaim |-> FALSE,
        accepted |-> FALSE
    ]

CheckSharedCore ==
    /\ state.phase = "Start"
    /\ state' = [state EXCEPT
        !.phase = "SharedCoreChecked",
        !.sharedCoreChecked = TRUE]

CheckWorkqueueAdapter ==
    /\ state.phase = "SharedCoreChecked"
    /\ state.sharedCoreChecked
    /\ state' = [state EXCEPT
        !.phase = "WorkqueueChecked",
        !.workqueueChecked = TRUE]

CheckIoUringAdapter ==
    /\ state.phase = "WorkqueueChecked"
    /\ state.workqueueChecked
    /\ state' = [state EXCEPT
        !.phase = "IoUringChecked",
        !.ioUringChecked = TRUE]

SeparateAdapterMechanics ==
    /\ state.phase = "IoUringChecked"
    /\ state.workqueueChecked
    /\ state.ioUringChecked
    /\ state' = [state EXCEPT
        !.phase = "AdaptersSeparated",
        !.adapterMechanicsSeparated = TRUE]

CheckAuthorityAndBudget ==
    /\ state.phase = "AdaptersSeparated"
    /\ state.adapterMechanicsSeparated
    /\ state' = [state EXCEPT
        !.phase = "AuthorityAndBudgetChecked",
        !.authorityIntersectionChecked = TRUE,
        !.callerBudgetSettlementChecked = TRUE]

CheckRevokeSourceEvidence ==
    /\ state.phase = "AuthorityAndBudgetChecked"
    /\ state.authorityIntersectionChecked
    /\ state.callerBudgetSettlementChecked
    /\ state' = [state EXCEPT
        !.phase = "RevokeAndEvidenceChecked",
        !.revokeFreshnessChecked = TRUE,
        !.sourceDriftChecked = TRUE,
        !.evidenceSplitChecked = TRUE]

AllowCandidatePatchProposal ==
    /\ state.phase = "RevokeAndEvidenceChecked"
    /\ state.sharedCoreChecked
    /\ state.workqueueChecked
    /\ state.ioUringChecked
    /\ state.adapterMechanicsSeparated
    /\ state.authorityIntersectionChecked
    /\ state.callerBudgetSettlementChecked
    /\ state.revokeFreshnessChecked
    /\ state.sourceDriftChecked
    /\ state.evidenceSplitChecked
    /\ state' = [state EXCEPT
        !.phase = "CandidatePatchProposalAllowed",
        !.candidatePatchProposalAllowed = TRUE]

AcceptGate ==
    /\ state.phase = "CandidatePatchProposalAllowed"
    /\ state.candidatePatchProposalAllowed
    /\ state' = [state EXCEPT
        !.phase = "Accepted",
        !.accepted = TRUE]

BadPatchBeforeWorkqueue ==
    /\ ALLOW_UNSAFE_PATCH_BEFORE_WORKQUEUE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadPatchBeforeWorkqueue",
        !.sharedCoreChecked = TRUE,
        !.candidatePatchProposalAllowed = TRUE]

BadPatchBeforeIoUring ==
    /\ ALLOW_UNSAFE_PATCH_BEFORE_IOURING
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadPatchBeforeIoUring",
        !.sharedCoreChecked = TRUE,
        !.workqueueChecked = TRUE,
        !.candidatePatchProposalAllowed = TRUE]

BadBroadModelOnly ==
    /\ ALLOW_UNSAFE_BROAD_MODEL_ONLY
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadBroadModelOnly",
        !.sharedCoreChecked = TRUE,
        !.candidatePatchProposalAllowed = TRUE]

BadSharedCoreGenericAsync ==
    /\ ALLOW_UNSAFE_SHARED_CORE_GENERIC_ASYNC
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadSharedCoreGenericAsync",
        !.sharedCoreGenericAsync = TRUE]

BadCrossAdapterCollapse ==
    /\ ALLOW_UNSAFE_CROSS_ADAPTER_COLLAPSE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadCrossAdapterCollapse",
        !.crossAdapterCollapse = TRUE]

BadLinuxObjectAuthority ==
    /\ ALLOW_UNSAFE_LINUX_OBJECT_AUTHORITY
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadLinuxObjectAuthority",
        !.linuxObjectAuthorityAllowed = TRUE]

BadMissingEvidenceSplit ==
    /\ ALLOW_UNSAFE_MISSING_EVIDENCE_SPLIT
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadMissingEvidenceSplit",
        !.candidatePatchProposalAllowed = TRUE,
        !.evidenceSplitChecked = FALSE]

BadAbiApproval ==
    /\ ALLOW_UNSAFE_ABI_APPROVAL
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadAbiApproval",
        !.abiApproved = TRUE]

BadBehaviorChange ==
    /\ ALLOW_UNSAFE_BEHAVIOR_CHANGE
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadBehaviorChange",
        !.behaviorChange = TRUE]

BadMonitorVerified ==
    /\ ALLOW_UNSAFE_MONITOR_VERIFIED
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadMonitorVerified",
        !.monitorVerified = TRUE]

BadProtectionClaim ==
    /\ ALLOW_UNSAFE_PROTECTION_CLAIM
    /\ state.phase \notin TerminalPhases
    /\ state' = [state EXCEPT
        !.phase = "BadProtectionClaim",
        !.protectionClaim = TRUE]

Next ==
    IF state.phase \in TerminalPhases THEN
        UNCHANGED state
    ELSE
        \/ CheckSharedCore
        \/ CheckWorkqueueAdapter
        \/ CheckIoUringAdapter
        \/ SeparateAdapterMechanics
        \/ CheckAuthorityAndBudget
        \/ CheckRevokeSourceEvidence
        \/ AllowCandidatePatchProposal
        \/ AcceptGate
        \/ BadPatchBeforeWorkqueue
        \/ BadPatchBeforeIoUring
        \/ BadBroadModelOnly
        \/ BadSharedCoreGenericAsync
        \/ BadCrossAdapterCollapse
        \/ BadLinuxObjectAuthority
        \/ BadMissingEvidenceSplit
        \/ BadAbiApproval
        \/ BadBehaviorChange
        \/ BadMonitorVerified
        \/ BadProtectionClaim

Spec == Init /\ [][Next]_vars

CandidatePatchRequiresBothAdapters ==
    state.candidatePatchProposalAllowed =>
        /\ state.sharedCoreChecked
        /\ state.workqueueChecked
        /\ state.ioUringChecked
        /\ state.adapterMechanicsSeparated
        /\ state.authorityIntersectionChecked
        /\ state.callerBudgetSettlementChecked
        /\ state.revokeFreshnessChecked
        /\ state.sourceDriftChecked
        /\ state.evidenceSplitChecked

NoBroadModelOnlyGate ==
    state.candidatePatchProposalAllowed =>
        /\ state.workqueueChecked
        /\ state.ioUringChecked

NoSharedCoreGenericAsync == ~state.sharedCoreGenericAsync

NoCrossAdapterCollapse == ~state.crossAdapterCollapse

NoLinuxObjectAuthority == ~state.linuxObjectAuthorityAllowed

EvidenceSplitRequired ==
    state.candidatePatchProposalAllowed => state.evidenceSplitChecked

NoLinuxCodeApproval == ~state.linuxCodeApproved

NoAbiApproval == ~state.abiApproved

NoBehaviorChange == ~state.behaviorChange

NoMonitorVerifiedClaim == ~state.monitorVerified

NoProtectionClaim == ~state.protectionClaim

AcceptedImpliesCombinedGateSafety ==
    state.accepted =>
        /\ state.candidatePatchProposalAllowed
        /\ state.sharedCoreChecked
        /\ state.workqueueChecked
        /\ state.ioUringChecked
        /\ state.adapterMechanicsSeparated
        /\ state.authorityIntersectionChecked
        /\ state.callerBudgetSettlementChecked
        /\ state.revokeFreshnessChecked
        /\ state.sourceDriftChecked
        /\ state.evidenceSplitChecked
        /\ ~state.linuxCodeApproved
        /\ ~state.sharedCoreGenericAsync
        /\ ~state.crossAdapterCollapse
        /\ ~state.linuxObjectAuthorityAllowed
        /\ ~state.abiApproved
        /\ ~state.behaviorChange
        /\ ~state.monitorVerified
        /\ ~state.protectionClaim

=============================================================================
