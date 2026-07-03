---------- MODULE P5AR0009SourceGate ----------
EXTENDS Naturals

VARIABLES
    phase,
    linuxDrafted,
    patchQueueRecorded,
    sourceCheckerPassed,
    ordinaryCfsOnly,
    preSettlePicker,
    attemptLocalCarrier,
    boundedReceipts,
    groupSettlementCarrier,
    crossPathPredicate,
    staticKeyDormant,
    noPublicAbi,
    noTraceAbi,
    noMonitorCall,
    noExportedSymbol,
    noONScan,
    noPersistentHotLayout,
    patchAccepted,
    runtimeDenialClaim,
    cfsDenyRepickClaim,
    productionClaim,
    costClaim

vars == <<phase, linuxDrafted, patchQueueRecorded, sourceCheckerPassed,
          ordinaryCfsOnly, preSettlePicker, attemptLocalCarrier,
          boundedReceipts, groupSettlementCarrier, crossPathPredicate,
          staticKeyDormant, noPublicAbi, noTraceAbi, noMonitorCall,
          noExportedSymbol, noONScan, noPersistentHotLayout, patchAccepted,
          runtimeDenialClaim, cfsDenyRepickClaim, productionClaim, costClaim>>

Base ==
    [ phase |-> "Start",
      linuxDrafted |-> FALSE,
      patchQueueRecorded |-> FALSE,
      sourceCheckerPassed |-> FALSE,
      ordinaryCfsOnly |-> FALSE,
      preSettlePicker |-> FALSE,
      attemptLocalCarrier |-> FALSE,
      boundedReceipts |-> FALSE,
      groupSettlementCarrier |-> FALSE,
      crossPathPredicate |-> FALSE,
      staticKeyDormant |-> FALSE,
      noPublicAbi |-> FALSE,
      noTraceAbi |-> FALSE,
      noMonitorCall |-> FALSE,
      noExportedSymbol |-> FALSE,
      noONScan |-> FALSE,
      noPersistentHotLayout |-> FALSE,
      patchAccepted |-> FALSE,
      runtimeDenialClaim |-> FALSE,
      cfsDenyRepickClaim |-> FALSE,
      productionClaim |-> FALSE,
      costClaim |-> FALSE ]

SetState(s) ==
    /\ phase = s.phase
    /\ linuxDrafted = s.linuxDrafted
    /\ patchQueueRecorded = s.patchQueueRecorded
    /\ sourceCheckerPassed = s.sourceCheckerPassed
    /\ ordinaryCfsOnly = s.ordinaryCfsOnly
    /\ preSettlePicker = s.preSettlePicker
    /\ attemptLocalCarrier = s.attemptLocalCarrier
    /\ boundedReceipts = s.boundedReceipts
    /\ groupSettlementCarrier = s.groupSettlementCarrier
    /\ crossPathPredicate = s.crossPathPredicate
    /\ staticKeyDormant = s.staticKeyDormant
    /\ noPublicAbi = s.noPublicAbi
    /\ noTraceAbi = s.noTraceAbi
    /\ noMonitorCall = s.noMonitorCall
    /\ noExportedSymbol = s.noExportedSymbol
    /\ noONScan = s.noONScan
    /\ noPersistentHotLayout = s.noPersistentHotLayout
    /\ patchAccepted = s.patchAccepted
    /\ runtimeDenialClaim = s.runtimeDenialClaim
    /\ cfsDenyRepickClaim = s.cfsDenyRepickClaim
    /\ productionClaim = s.productionClaim
    /\ costClaim = s.costClaim

Init == SetState(Base)

RecordLinuxDraft ==
    /\ phase = "Start"
    /\ linuxDrafted' = TRUE
    /\ ordinaryCfsOnly' = TRUE
    /\ preSettlePicker' = TRUE
    /\ attemptLocalCarrier' = TRUE
    /\ boundedReceipts' = TRUE
    /\ groupSettlementCarrier' = TRUE
    /\ crossPathPredicate' = TRUE
    /\ staticKeyDormant' = TRUE
    /\ noPublicAbi' = TRUE
    /\ noTraceAbi' = TRUE
    /\ noMonitorCall' = TRUE
    /\ noExportedSymbol' = TRUE
    /\ noONScan' = TRUE
    /\ noPersistentHotLayout' = TRUE
    /\ phase' = "LinuxDraftRecorded"
    /\ UNCHANGED <<patchQueueRecorded, sourceCheckerPassed, patchAccepted,
                    runtimeDenialClaim, cfsDenyRepickClaim, productionClaim,
                    costClaim>>

RecordPatchQueue ==
    /\ phase = "LinuxDraftRecorded"
    /\ patchQueueRecorded' = TRUE
    /\ phase' = "PatchQueueRecorded"
    /\ UNCHANGED <<linuxDrafted, sourceCheckerPassed, ordinaryCfsOnly,
                    preSettlePicker, attemptLocalCarrier, boundedReceipts,
                    groupSettlementCarrier, crossPathPredicate, staticKeyDormant,
                    noPublicAbi, noTraceAbi, noMonitorCall, noExportedSymbol,
                    noONScan, noPersistentHotLayout, patchAccepted,
                    runtimeDenialClaim, cfsDenyRepickClaim, productionClaim,
                    costClaim>>

PassSourceGate ==
    /\ phase = "PatchQueueRecorded"
    /\ sourceCheckerPassed' = TRUE
    /\ phase' = "SourceGatePassed"
    /\ UNCHANGED <<linuxDrafted, patchQueueRecorded, ordinaryCfsOnly,
                    preSettlePicker, attemptLocalCarrier, boundedReceipts,
                    groupSettlementCarrier, crossPathPredicate, staticKeyDormant,
                    noPublicAbi, noTraceAbi, noMonitorCall, noExportedSymbol,
                    noONScan, noPersistentHotLayout, patchAccepted,
                    runtimeDenialClaim, cfsDenyRepickClaim, productionClaim,
                    costClaim>>

StutterDone ==
    /\ phase = "SourceGatePassed"
    /\ UNCHANGED vars

Next ==
    \/ RecordLinuxDraft
    \/ RecordPatchQueue
    \/ PassSourceGate
    \/ StutterDone

SafeSpec == Init /\ [][Next]_vars

RequiredForSourceGate ==
    /\ linuxDrafted
    /\ patchQueueRecorded
    /\ sourceCheckerPassed
    /\ ordinaryCfsOnly
    /\ preSettlePicker
    /\ attemptLocalCarrier
    /\ boundedReceipts
    /\ groupSettlementCarrier
    /\ crossPathPredicate
    /\ staticKeyDormant
    /\ noPublicAbi
    /\ noTraceAbi
    /\ noMonitorCall
    /\ noExportedSymbol
    /\ noONScan
    /\ noPersistentHotLayout

NoOverclaim ==
    /\ patchAccepted = FALSE
    /\ runtimeDenialClaim = FALSE
    /\ cfsDenyRepickClaim = FALSE
    /\ productionClaim = FALSE
    /\ costClaim = FALSE

Safety ==
    (phase # "SourceGatePassed") \/ (RequiredForSourceGate /\ NoOverclaim)

UnsafeMissingPatchQueueSpec ==
    /\ SetState([Base EXCEPT !.phase = "SourceGatePassed",
                             !.linuxDrafted = TRUE,
                             !.sourceCheckerPassed = TRUE,
                             !.ordinaryCfsOnly = TRUE,
                             !.preSettlePicker = TRUE,
                             !.attemptLocalCarrier = TRUE,
                             !.boundedReceipts = TRUE,
                             !.groupSettlementCarrier = TRUE,
                             !.crossPathPredicate = TRUE,
                             !.staticKeyDormant = TRUE,
                             !.noPublicAbi = TRUE,
                             !.noTraceAbi = TRUE,
                             !.noMonitorCall = TRUE,
                             !.noExportedSymbol = TRUE,
                             !.noONScan = TRUE,
                             !.noPersistentHotLayout = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingSourceCheckerSpec ==
    /\ SetState([Base EXCEPT !.phase = "SourceGatePassed",
                             !.linuxDrafted = TRUE,
                             !.patchQueueRecorded = TRUE,
                             !.ordinaryCfsOnly = TRUE,
                             !.preSettlePicker = TRUE,
                             !.attemptLocalCarrier = TRUE,
                             !.boundedReceipts = TRUE,
                             !.groupSettlementCarrier = TRUE,
                             !.crossPathPredicate = TRUE,
                             !.staticKeyDormant = TRUE,
                             !.noPublicAbi = TRUE,
                             !.noTraceAbi = TRUE,
                             !.noMonitorCall = TRUE,
                             !.noExportedSymbol = TRUE,
                             !.noONScan = TRUE,
                             !.noPersistentHotLayout = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingOrdinaryScopeSpec ==
    /\ SetState([Base EXCEPT !.phase = "SourceGatePassed",
                             !.linuxDrafted = TRUE,
                             !.patchQueueRecorded = TRUE,
                             !.sourceCheckerPassed = TRUE,
                             !.preSettlePicker = TRUE,
                             !.attemptLocalCarrier = TRUE,
                             !.boundedReceipts = TRUE,
                             !.groupSettlementCarrier = TRUE,
                             !.crossPathPredicate = TRUE,
                             !.staticKeyDormant = TRUE,
                             !.noPublicAbi = TRUE,
                             !.noTraceAbi = TRUE,
                             !.noMonitorCall = TRUE,
                             !.noExportedSymbol = TRUE,
                             !.noONScan = TRUE,
                             !.noPersistentHotLayout = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingPreSettleSpec ==
    /\ SetState([Base EXCEPT !.phase = "SourceGatePassed",
                             !.linuxDrafted = TRUE,
                             !.patchQueueRecorded = TRUE,
                             !.sourceCheckerPassed = TRUE,
                             !.ordinaryCfsOnly = TRUE,
                             !.attemptLocalCarrier = TRUE,
                             !.boundedReceipts = TRUE,
                             !.groupSettlementCarrier = TRUE,
                             !.crossPathPredicate = TRUE,
                             !.staticKeyDormant = TRUE,
                             !.noPublicAbi = TRUE,
                             !.noTraceAbi = TRUE,
                             !.noMonitorCall = TRUE,
                             !.noExportedSymbol = TRUE,
                             !.noONScan = TRUE,
                             !.noPersistentHotLayout = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingBoundedCarrierSpec ==
    /\ SetState([Base EXCEPT !.phase = "SourceGatePassed",
                             !.linuxDrafted = TRUE,
                             !.patchQueueRecorded = TRUE,
                             !.sourceCheckerPassed = TRUE,
                             !.ordinaryCfsOnly = TRUE,
                             !.preSettlePicker = TRUE,
                             !.attemptLocalCarrier = TRUE,
                             !.groupSettlementCarrier = TRUE,
                             !.crossPathPredicate = TRUE,
                             !.staticKeyDormant = TRUE,
                             !.noPublicAbi = TRUE,
                             !.noTraceAbi = TRUE,
                             !.noMonitorCall = TRUE,
                             !.noExportedSymbol = TRUE,
                             !.noONScan = TRUE,
                             !.noPersistentHotLayout = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingCrossPathSpec ==
    /\ SetState([Base EXCEPT !.phase = "SourceGatePassed",
                             !.linuxDrafted = TRUE,
                             !.patchQueueRecorded = TRUE,
                             !.sourceCheckerPassed = TRUE,
                             !.ordinaryCfsOnly = TRUE,
                             !.preSettlePicker = TRUE,
                             !.attemptLocalCarrier = TRUE,
                             !.boundedReceipts = TRUE,
                             !.groupSettlementCarrier = TRUE,
                             !.staticKeyDormant = TRUE,
                             !.noPublicAbi = TRUE,
                             !.noTraceAbi = TRUE,
                             !.noMonitorCall = TRUE,
                             !.noExportedSymbol = TRUE,
                             !.noONScan = TRUE,
                             !.noPersistentHotLayout = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafePublicAbiSpec ==
    /\ SetState([Base EXCEPT !.phase = "SourceGatePassed",
                             !.linuxDrafted = TRUE,
                             !.patchQueueRecorded = TRUE,
                             !.sourceCheckerPassed = TRUE,
                             !.ordinaryCfsOnly = TRUE,
                             !.preSettlePicker = TRUE,
                             !.attemptLocalCarrier = TRUE,
                             !.boundedReceipts = TRUE,
                             !.groupSettlementCarrier = TRUE,
                             !.crossPathPredicate = TRUE,
                             !.staticKeyDormant = TRUE,
                             !.noTraceAbi = TRUE,
                             !.noMonitorCall = TRUE,
                             !.noExportedSymbol = TRUE,
                             !.noONScan = TRUE,
                             !.noPersistentHotLayout = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMonitorCallSpec ==
    /\ SetState([Base EXCEPT !.phase = "SourceGatePassed",
                             !.linuxDrafted = TRUE,
                             !.patchQueueRecorded = TRUE,
                             !.sourceCheckerPassed = TRUE,
                             !.ordinaryCfsOnly = TRUE,
                             !.preSettlePicker = TRUE,
                             !.attemptLocalCarrier = TRUE,
                             !.boundedReceipts = TRUE,
                             !.groupSettlementCarrier = TRUE,
                             !.crossPathPredicate = TRUE,
                             !.staticKeyDormant = TRUE,
                             !.noPublicAbi = TRUE,
                             !.noTraceAbi = TRUE,
                             !.noExportedSymbol = TRUE,
                             !.noONScan = TRUE,
                             !.noPersistentHotLayout = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeAcceptedPatchSpec ==
    /\ SetState([Base EXCEPT !.phase = "SourceGatePassed",
                             !.linuxDrafted = TRUE,
                             !.patchQueueRecorded = TRUE,
                             !.sourceCheckerPassed = TRUE,
                             !.ordinaryCfsOnly = TRUE,
                             !.preSettlePicker = TRUE,
                             !.attemptLocalCarrier = TRUE,
                             !.boundedReceipts = TRUE,
                             !.groupSettlementCarrier = TRUE,
                             !.crossPathPredicate = TRUE,
                             !.staticKeyDormant = TRUE,
                             !.noPublicAbi = TRUE,
                             !.noTraceAbi = TRUE,
                             !.noMonitorCall = TRUE,
                             !.noExportedSymbol = TRUE,
                             !.noONScan = TRUE,
                             !.noPersistentHotLayout = TRUE,
                             !.patchAccepted = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeRuntimeProtectionCostClaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "SourceGatePassed",
                             !.linuxDrafted = TRUE,
                             !.patchQueueRecorded = TRUE,
                             !.sourceCheckerPassed = TRUE,
                             !.ordinaryCfsOnly = TRUE,
                             !.preSettlePicker = TRUE,
                             !.attemptLocalCarrier = TRUE,
                             !.boundedReceipts = TRUE,
                             !.groupSettlementCarrier = TRUE,
                             !.crossPathPredicate = TRUE,
                             !.staticKeyDormant = TRUE,
                             !.noPublicAbi = TRUE,
                             !.noTraceAbi = TRUE,
                             !.noMonitorCall = TRUE,
                             !.noExportedSymbol = TRUE,
                             !.noONScan = TRUE,
                             !.noPersistentHotLayout = TRUE,
                             !.runtimeDenialClaim = TRUE,
                             !.cfsDenyRepickClaim = TRUE,
                             !.productionClaim = TRUE,
                             !.costClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

=============================================================================
