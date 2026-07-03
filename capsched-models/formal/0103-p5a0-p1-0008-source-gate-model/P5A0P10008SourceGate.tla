---------- MODULE P5A0P10008SourceGate ----------

CONSTANTS HeaderFile, ExecLeaseFile, OtherFile

VARIABLE gate

vars == <<gate>>

AllowedFiles == {HeaderFile, ExecLeaseFile}

Phase == {
    "P5A0P10008SourceAccepted",
    "BadMissingPatch",
    "BadDeltaFile",
    "BadNotCommentOnly",
    "BadCheckpatchOrReplay",
    "BadHotHelperChange",
    "BadLifecycleChange",
    "BadLayoutChange",
    "BadNonAllowOrBranch",
    "BadPublicAbiOrMonitor",
    "BadRuntimeOrProtectionClaim",
    "BadFullAcceptanceOverclaim"
}

GateFields == {
    "phase",
    "patch0008Present",
    "parentRecorded",
    "futureRecorded",
    "seriesHasExactlyOne0008",
    "patchShaRecorded",
    "seriesShaRecorded",
    "deltaFiles",
    "deltaCommentOnly",
    "checkpatchClean",
    "replayExactHead",
    "replayExactTree",
    "hotHelperBodiesUnchanged",
    "lifecycleHelperBodiesUnchanged",
    "schedExecTaskLayoutChanged",
    "taskStructLayoutChanged",
    "rqLayoutChanged",
    "schedEntityLayoutChanged",
    "cfsRqLayoutChanged",
    "helperReturnsOnlyAllow",
    "schedulerBranchesOnValidation",
    "fairPickerIneligibility",
    "runtimeDenial",
    "retry",
    "failClosed",
    "quarantine",
    "deniedReceipt",
    "runtimeStatusPublication",
    "publicAbi",
    "publicTracepointAbi",
    "exportedSymbol",
    "monitorCall",
    "monitorAbi",
    "allocation",
    "sleepOrBlockingCall",
    "lockOrRefcountTransfer",
    "staticKey",
    "printk",
    "fullBuildEvidence",
    "qemuSmokeEvidence",
    "objectLayoutEvidence",
    "runtimeCoverageClaim",
    "monitorVerificationClaim",
    "productionProtectionClaim",
    "costEfficiencyClaim",
    "deploymentReadinessClaim",
    "datacenterReadinessClaim"
}

BaseGate == [
    phase |-> "P5A0P10008SourceAccepted",
    patch0008Present |-> TRUE,
    parentRecorded |-> TRUE,
    futureRecorded |-> TRUE,
    seriesHasExactlyOne0008 |-> TRUE,
    patchShaRecorded |-> TRUE,
    seriesShaRecorded |-> TRUE,
    deltaFiles |-> AllowedFiles,
    deltaCommentOnly |-> TRUE,
    checkpatchClean |-> TRUE,
    replayExactHead |-> TRUE,
    replayExactTree |-> TRUE,
    hotHelperBodiesUnchanged |-> TRUE,
    lifecycleHelperBodiesUnchanged |-> TRUE,
    schedExecTaskLayoutChanged |-> FALSE,
    taskStructLayoutChanged |-> FALSE,
    rqLayoutChanged |-> FALSE,
    schedEntityLayoutChanged |-> FALSE,
    cfsRqLayoutChanged |-> FALSE,
    helperReturnsOnlyAllow |-> TRUE,
    schedulerBranchesOnValidation |-> FALSE,
    fairPickerIneligibility |-> FALSE,
    runtimeDenial |-> FALSE,
    retry |-> FALSE,
    failClosed |-> FALSE,
    quarantine |-> FALSE,
    deniedReceipt |-> FALSE,
    runtimeStatusPublication |-> FALSE,
    publicAbi |-> FALSE,
    publicTracepointAbi |-> FALSE,
    exportedSymbol |-> FALSE,
    monitorCall |-> FALSE,
    monitorAbi |-> FALSE,
    allocation |-> FALSE,
    sleepOrBlockingCall |-> FALSE,
    lockOrRefcountTransfer |-> FALSE,
    staticKey |-> FALSE,
    printk |-> FALSE,
    fullBuildEvidence |-> FALSE,
    qemuSmokeEvidence |-> FALSE,
    objectLayoutEvidence |-> FALSE,
    runtimeCoverageClaim |-> FALSE,
    monitorVerificationClaim |-> FALSE,
    productionProtectionClaim |-> FALSE,
    costEfficiencyClaim |-> FALSE,
    deploymentReadinessClaim |-> FALSE,
    datacenterReadinessClaim |-> FALSE
]

Init == gate = BaseGate

Spec == Init /\ [][UNCHANGED gate]_vars

UnsafeMissingPatchSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadMissingPatch",
                            !.patch0008Present = FALSE,
                            !.seriesHasExactlyOne0008 = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeDeltaFileSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadDeltaFile",
                            !.deltaFiles = AllowedFiles \cup {OtherFile}]
    /\ [][UNCHANGED gate]_vars

UnsafeNotCommentOnlySpec ==
    gate = [BaseGate EXCEPT !.phase = "BadNotCommentOnly",
                            !.deltaCommentOnly = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeCheckpatchOrReplaySpec ==
    gate = [BaseGate EXCEPT !.phase = "BadCheckpatchOrReplay",
                            !.checkpatchClean = FALSE,
                            !.replayExactHead = FALSE,
                            !.replayExactTree = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeHotHelperChangeSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadHotHelperChange",
                            !.hotHelperBodiesUnchanged = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeLifecycleChangeSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadLifecycleChange",
                            !.lifecycleHelperBodiesUnchanged = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeLayoutChangeSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadLayoutChange",
                            !.schedExecTaskLayoutChanged = TRUE,
                            !.taskStructLayoutChanged = TRUE,
                            !.rqLayoutChanged = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeNonAllowOrBranchSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadNonAllowOrBranch",
                            !.helperReturnsOnlyAllow = FALSE,
                            !.schedulerBranchesOnValidation = TRUE,
                            !.fairPickerIneligibility = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafePublicAbiOrMonitorSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadPublicAbiOrMonitor",
                            !.publicAbi = TRUE,
                            !.publicTracepointAbi = TRUE,
                            !.exportedSymbol = TRUE,
                            !.monitorCall = TRUE,
                            !.monitorAbi = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRuntimeOrProtectionClaimSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadRuntimeOrProtectionClaim",
                            !.runtimeDenial = TRUE,
                            !.retry = TRUE,
                            !.failClosed = TRUE,
                            !.quarantine = TRUE,
                            !.deniedReceipt = TRUE,
                            !.runtimeStatusPublication = TRUE,
                            !.runtimeCoverageClaim = TRUE,
                            !.monitorVerificationClaim = TRUE,
                            !.productionProtectionClaim = TRUE,
                            !.costEfficiencyClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeFullAcceptanceOverclaimSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadFullAcceptanceOverclaim",
                            !.fullBuildEvidence = TRUE,
                            !.qemuSmokeEvidence = TRUE,
                            !.objectLayoutEvidence = TRUE,
                            !.deploymentReadinessClaim = TRUE,
                            !.datacenterReadinessClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

BoolFieldOK(f) == gate[f] \in BOOLEAN

TypeOK ==
    /\ DOMAIN gate = GateFields
    /\ gate.phase \in Phase
    /\ gate.deltaFiles \subseteq {HeaderFile, ExecLeaseFile, OtherFile}
    /\ \A f \in GateFields \ {"phase", "deltaFiles"}: BoolFieldOK(f)

PatchIdentityOK ==
    /\ gate.patch0008Present
    /\ gate.parentRecorded
    /\ gate.futureRecorded
    /\ gate.seriesHasExactlyOne0008
    /\ gate.patchShaRecorded
    /\ gate.seriesShaRecorded

DeltaScopeOK ==
    /\ gate.deltaFiles = AllowedFiles
    /\ gate.deltaCommentOnly

SourceEvidenceOK ==
    /\ gate.checkpatchClean
    /\ gate.replayExactHead
    /\ gate.replayExactTree
    /\ gate.hotHelperBodiesUnchanged
    /\ gate.lifecycleHelperBodiesUnchanged
    /\ gate.helperReturnsOnlyAllow
    /\ ~gate.schedulerBranchesOnValidation
    /\ ~gate.fairPickerIneligibility

NoLayoutChange ==
    /\ ~gate.schedExecTaskLayoutChanged
    /\ ~gate.taskStructLayoutChanged
    /\ ~gate.rqLayoutChanged
    /\ ~gate.schedEntityLayoutChanged
    /\ ~gate.cfsRqLayoutChanged

NoRuntimeOrDenial ==
    /\ ~gate.runtimeDenial
    /\ ~gate.retry
    /\ ~gate.failClosed
    /\ ~gate.quarantine
    /\ ~gate.deniedReceipt
    /\ ~gate.runtimeStatusPublication

NoSurface ==
    /\ ~gate.publicAbi
    /\ ~gate.publicTracepointAbi
    /\ ~gate.exportedSymbol
    /\ ~gate.monitorCall
    /\ ~gate.monitorAbi
    /\ ~gate.allocation
    /\ ~gate.sleepOrBlockingCall
    /\ ~gate.lockOrRefcountTransfer
    /\ ~gate.staticKey
    /\ ~gate.printk

NoFullAcceptanceOverclaim ==
    /\ ~gate.fullBuildEvidence
    /\ ~gate.qemuSmokeEvidence
    /\ ~gate.objectLayoutEvidence
    /\ ~gate.runtimeCoverageClaim
    /\ ~gate.monitorVerificationClaim
    /\ ~gate.productionProtectionClaim
    /\ ~gate.costEfficiencyClaim
    /\ ~gate.deploymentReadinessClaim
    /\ ~gate.datacenterReadinessClaim

Safety ==
    /\ TypeOK
    /\ PatchIdentityOK
    /\ DeltaScopeOK
    /\ SourceEvidenceOK
    /\ NoLayoutChange
    /\ NoRuntimeOrDenial
    /\ NoSurface
    /\ NoFullAcceptanceOverclaim

====
