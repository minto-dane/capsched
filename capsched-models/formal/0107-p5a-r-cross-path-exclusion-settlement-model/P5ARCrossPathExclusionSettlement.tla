---------- MODULE P5ARCrossPathExclusionSettlement ----------
EXTENDS Naturals

VARIABLES
    phase,
    ordinaryCfsScope,
    coreEnabled,
    coreExcluded,
    coreSettled,
    dlEnabled,
    dlExcluded,
    dlSettled,
    proxyEnabled,
    proxyExcluded,
    proxySettled,
    scxEnabled,
    scxExcluded,
    scxSettled,
    classLoopNonFairEnabled,
    classLoopExcluded,
    classLoopSettled,
    coreCachedPickBypass,
    coreSiblingPickBypass,
    coreCookieReplacementBypass,
    coreCookieStealBypass,
    dlFairServerBorrow,
    dlExtServerBorrow,
    proxyDonorExecutorMismatch,
    scxSwitchedAllBypass,
    scxBpfAuthorityRoot,
    classLoopUnsupportedPick,
    retryTaskAsDenialProof,
    behaviorPatchApproved,
    cfsDenyAndRepickApproved,
    runtimeCoverageClaim,
    productionProtectionClaim,
    costEfficiencyClaim,
    datacenterReadinessClaim

vars == <<phase, ordinaryCfsScope, coreEnabled, coreExcluded, coreSettled,
          dlEnabled, dlExcluded, dlSettled, proxyEnabled, proxyExcluded,
          proxySettled, scxEnabled, scxExcluded, scxSettled,
          classLoopNonFairEnabled, classLoopExcluded, classLoopSettled,
          coreCachedPickBypass, coreSiblingPickBypass,
          coreCookieReplacementBypass, coreCookieStealBypass,
          dlFairServerBorrow, dlExtServerBorrow, proxyDonorExecutorMismatch,
          scxSwitchedAllBypass, scxBpfAuthorityRoot,
          classLoopUnsupportedPick, retryTaskAsDenialProof,
          behaviorPatchApproved, cfsDenyAndRepickApproved,
          runtimeCoverageClaim, productionProtectionClaim,
          costEfficiencyClaim, datacenterReadinessClaim>>

Phases == {
    "Start",
    "OrdinaryCfsScopeRecorded",
    "CrossPathsExcluded",
    "ReadyRecorded",
    "BadCoreUnsettled",
    "BadCoreCachedPick",
    "BadCoreSiblingPick",
    "BadCoreCookieReplacement",
    "BadCoreCookieSteal",
    "BadDlUnsettled",
    "BadDlFairBorrow",
    "BadDlExtBorrow",
    "BadProxyUnsettled",
    "BadProxyMismatch",
    "BadScxUnsettled",
    "BadScxSwitchedAll",
    "BadScxAuthorityRoot",
    "BadClassLoopUnsettled",
    "BadClassLoopUnsupported",
    "BadRetryTaskDenial",
    "BadBehaviorOverclaim",
    "BadProtectionCostClaim"
}

Base ==
    [ phase |-> "Start",
      ordinaryCfsScope |-> FALSE,
      coreEnabled |-> TRUE,
      coreExcluded |-> FALSE,
      coreSettled |-> FALSE,
      dlEnabled |-> TRUE,
      dlExcluded |-> FALSE,
      dlSettled |-> FALSE,
      proxyEnabled |-> TRUE,
      proxyExcluded |-> FALSE,
      proxySettled |-> FALSE,
      scxEnabled |-> TRUE,
      scxExcluded |-> FALSE,
      scxSettled |-> FALSE,
      classLoopNonFairEnabled |-> TRUE,
      classLoopExcluded |-> FALSE,
      classLoopSettled |-> FALSE,
      coreCachedPickBypass |-> FALSE,
      coreSiblingPickBypass |-> FALSE,
      coreCookieReplacementBypass |-> FALSE,
      coreCookieStealBypass |-> FALSE,
      dlFairServerBorrow |-> FALSE,
      dlExtServerBorrow |-> FALSE,
      proxyDonorExecutorMismatch |-> FALSE,
      scxSwitchedAllBypass |-> FALSE,
      scxBpfAuthorityRoot |-> FALSE,
      classLoopUnsupportedPick |-> FALSE,
      retryTaskAsDenialProof |-> FALSE,
      behaviorPatchApproved |-> FALSE,
      cfsDenyAndRepickApproved |-> FALSE,
      runtimeCoverageClaim |-> FALSE,
      productionProtectionClaim |-> FALSE,
      costEfficiencyClaim |-> FALSE,
      datacenterReadinessClaim |-> FALSE ]

SetState(s) ==
    /\ phase = s.phase
    /\ ordinaryCfsScope = s.ordinaryCfsScope
    /\ coreEnabled = s.coreEnabled
    /\ coreExcluded = s.coreExcluded
    /\ coreSettled = s.coreSettled
    /\ dlEnabled = s.dlEnabled
    /\ dlExcluded = s.dlExcluded
    /\ dlSettled = s.dlSettled
    /\ proxyEnabled = s.proxyEnabled
    /\ proxyExcluded = s.proxyExcluded
    /\ proxySettled = s.proxySettled
    /\ scxEnabled = s.scxEnabled
    /\ scxExcluded = s.scxExcluded
    /\ scxSettled = s.scxSettled
    /\ classLoopNonFairEnabled = s.classLoopNonFairEnabled
    /\ classLoopExcluded = s.classLoopExcluded
    /\ classLoopSettled = s.classLoopSettled
    /\ coreCachedPickBypass = s.coreCachedPickBypass
    /\ coreSiblingPickBypass = s.coreSiblingPickBypass
    /\ coreCookieReplacementBypass = s.coreCookieReplacementBypass
    /\ coreCookieStealBypass = s.coreCookieStealBypass
    /\ dlFairServerBorrow = s.dlFairServerBorrow
    /\ dlExtServerBorrow = s.dlExtServerBorrow
    /\ proxyDonorExecutorMismatch = s.proxyDonorExecutorMismatch
    /\ scxSwitchedAllBypass = s.scxSwitchedAllBypass
    /\ scxBpfAuthorityRoot = s.scxBpfAuthorityRoot
    /\ classLoopUnsupportedPick = s.classLoopUnsupportedPick
    /\ retryTaskAsDenialProof = s.retryTaskAsDenialProof
    /\ behaviorPatchApproved = s.behaviorPatchApproved
    /\ cfsDenyAndRepickApproved = s.cfsDenyAndRepickApproved
    /\ runtimeCoverageClaim = s.runtimeCoverageClaim
    /\ productionProtectionClaim = s.productionProtectionClaim
    /\ costEfficiencyClaim = s.costEfficiencyClaim
    /\ datacenterReadinessClaim = s.datacenterReadinessClaim

Init == SetState(Base)

RecordOrdinaryCfsScope ==
    /\ phase = "Start"
    /\ ordinaryCfsScope' = TRUE
    /\ phase' = "OrdinaryCfsScopeRecorded"
    /\ UNCHANGED <<coreEnabled, coreExcluded, coreSettled,
                    dlEnabled, dlExcluded, dlSettled,
                    proxyEnabled, proxyExcluded, proxySettled,
                    scxEnabled, scxExcluded, scxSettled,
                    classLoopNonFairEnabled, classLoopExcluded, classLoopSettled,
                    coreCachedPickBypass, coreSiblingPickBypass,
                    coreCookieReplacementBypass, coreCookieStealBypass,
                    dlFairServerBorrow, dlExtServerBorrow,
                    proxyDonorExecutorMismatch, scxSwitchedAllBypass,
                    scxBpfAuthorityRoot, classLoopUnsupportedPick,
                    retryTaskAsDenialProof, behaviorPatchApproved,
                    cfsDenyAndRepickApproved, runtimeCoverageClaim,
                    productionProtectionClaim, costEfficiencyClaim,
                    datacenterReadinessClaim>>

ExcludeCrossPaths ==
    /\ phase = "OrdinaryCfsScopeRecorded"
    /\ coreExcluded' = TRUE
    /\ dlExcluded' = TRUE
    /\ proxyExcluded' = TRUE
    /\ scxExcluded' = TRUE
    /\ classLoopExcluded' = TRUE
    /\ phase' = "CrossPathsExcluded"
    /\ UNCHANGED <<ordinaryCfsScope, coreEnabled, coreSettled,
                    dlEnabled, dlSettled, proxyEnabled, proxySettled,
                    scxEnabled, scxSettled, classLoopNonFairEnabled,
                    classLoopSettled, coreCachedPickBypass,
                    coreSiblingPickBypass, coreCookieReplacementBypass,
                    coreCookieStealBypass, dlFairServerBorrow,
                    dlExtServerBorrow, proxyDonorExecutorMismatch,
                    scxSwitchedAllBypass, scxBpfAuthorityRoot,
                    classLoopUnsupportedPick, retryTaskAsDenialProof,
                    behaviorPatchApproved, cfsDenyAndRepickApproved,
                    runtimeCoverageClaim, productionProtectionClaim,
                    costEfficiencyClaim, datacenterReadinessClaim>>

RecordReadyBoundary ==
    /\ phase = "CrossPathsExcluded"
    /\ ordinaryCfsScope
    /\ coreExcluded
    /\ dlExcluded
    /\ proxyExcluded
    /\ scxExcluded
    /\ classLoopExcluded
    /\ phase' = "ReadyRecorded"
    /\ UNCHANGED <<ordinaryCfsScope, coreEnabled, coreExcluded, coreSettled,
                    dlEnabled, dlExcluded, dlSettled,
                    proxyEnabled, proxyExcluded, proxySettled,
                    scxEnabled, scxExcluded, scxSettled,
                    classLoopNonFairEnabled, classLoopExcluded,
                    classLoopSettled, coreCachedPickBypass,
                    coreSiblingPickBypass, coreCookieReplacementBypass,
                    coreCookieStealBypass, dlFairServerBorrow,
                    dlExtServerBorrow, proxyDonorExecutorMismatch,
                    scxSwitchedAllBypass, scxBpfAuthorityRoot,
                    classLoopUnsupportedPick, retryTaskAsDenialProof,
                    behaviorPatchApproved, cfsDenyAndRepickApproved,
                    runtimeCoverageClaim, productionProtectionClaim,
                    costEfficiencyClaim, datacenterReadinessClaim>>

StutterDone ==
    /\ phase = "ReadyRecorded"
    /\ UNCHANGED vars

Next ==
    \/ RecordOrdinaryCfsScope
    \/ ExcludeCrossPaths
    \/ RecordReadyBoundary
    \/ StutterDone

SafeSpec == Init /\ [][Next]_vars

UnsafeCoreUnsettledSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadCoreUnsettled",
                             !.ordinaryCfsScope = TRUE,
                             !.coreEnabled = TRUE,
                             !.coreExcluded = FALSE,
                             !.coreSettled = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeCoreCachedPickSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadCoreCachedPick",
                             !.coreCachedPickBypass = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeCoreSiblingPickSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadCoreSiblingPick",
                             !.coreSiblingPickBypass = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeCoreCookieReplacementSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadCoreCookieReplacement",
                             !.coreCookieReplacementBypass = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeCoreCookieStealSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadCoreCookieSteal",
                             !.coreCookieStealBypass = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeDlUnsettledSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadDlUnsettled",
                             !.ordinaryCfsScope = TRUE,
                             !.dlEnabled = TRUE,
                             !.dlExcluded = FALSE,
                             !.dlSettled = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeDlFairBorrowSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadDlFairBorrow",
                             !.dlFairServerBorrow = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeDlExtBorrowSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadDlExtBorrow",
                             !.dlExtServerBorrow = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeProxyUnsettledSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadProxyUnsettled",
                             !.ordinaryCfsScope = TRUE,
                             !.proxyEnabled = TRUE,
                             !.proxyExcluded = FALSE,
                             !.proxySettled = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeProxyMismatchSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadProxyMismatch",
                             !.proxyDonorExecutorMismatch = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeScxUnsettledSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadScxUnsettled",
                             !.ordinaryCfsScope = TRUE,
                             !.scxEnabled = TRUE,
                             !.scxExcluded = FALSE,
                             !.scxSettled = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeScxSwitchedAllSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadScxSwitchedAll",
                             !.scxSwitchedAllBypass = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeScxAuthorityRootSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadScxAuthorityRoot",
                             !.scxBpfAuthorityRoot = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeClassLoopUnsettledSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadClassLoopUnsettled",
                             !.ordinaryCfsScope = TRUE,
                             !.classLoopNonFairEnabled = TRUE,
                             !.classLoopExcluded = FALSE,
                             !.classLoopSettled = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeClassLoopUnsupportedSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadClassLoopUnsupported",
                             !.classLoopUnsupportedPick = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeRetryTaskDenialSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadRetryTaskDenial",
                             !.retryTaskAsDenialProof = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeBehaviorOverclaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadBehaviorOverclaim",
                             !.behaviorPatchApproved = TRUE,
                             !.cfsDenyAndRepickApproved = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeProtectionCostClaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "BadProtectionCostClaim",
                             !.runtimeCoverageClaim = TRUE,
                             !.productionProtectionClaim = TRUE,
                             !.costEfficiencyClaim = TRUE,
                             !.datacenterReadinessClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

TypeOK ==
    /\ phase \in Phases
    /\ ordinaryCfsScope \in BOOLEAN
    /\ coreEnabled \in BOOLEAN
    /\ coreExcluded \in BOOLEAN
    /\ coreSettled \in BOOLEAN
    /\ dlEnabled \in BOOLEAN
    /\ dlExcluded \in BOOLEAN
    /\ dlSettled \in BOOLEAN
    /\ proxyEnabled \in BOOLEAN
    /\ proxyExcluded \in BOOLEAN
    /\ proxySettled \in BOOLEAN
    /\ scxEnabled \in BOOLEAN
    /\ scxExcluded \in BOOLEAN
    /\ scxSettled \in BOOLEAN
    /\ classLoopNonFairEnabled \in BOOLEAN
    /\ classLoopExcluded \in BOOLEAN
    /\ classLoopSettled \in BOOLEAN
    /\ coreCachedPickBypass \in BOOLEAN
    /\ coreSiblingPickBypass \in BOOLEAN
    /\ coreCookieReplacementBypass \in BOOLEAN
    /\ coreCookieStealBypass \in BOOLEAN
    /\ dlFairServerBorrow \in BOOLEAN
    /\ dlExtServerBorrow \in BOOLEAN
    /\ proxyDonorExecutorMismatch \in BOOLEAN
    /\ scxSwitchedAllBypass \in BOOLEAN
    /\ scxBpfAuthorityRoot \in BOOLEAN
    /\ classLoopUnsupportedPick \in BOOLEAN
    /\ retryTaskAsDenialProof \in BOOLEAN
    /\ behaviorPatchApproved \in BOOLEAN
    /\ cfsDenyAndRepickApproved \in BOOLEAN
    /\ runtimeCoverageClaim \in BOOLEAN
    /\ productionProtectionClaim \in BOOLEAN
    /\ costEfficiencyClaim \in BOOLEAN
    /\ datacenterReadinessClaim \in BOOLEAN

CorePathSafe ==
    (~coreEnabled) \/ coreExcluded \/ coreSettled

DlPathSafe ==
    (~dlEnabled) \/ dlExcluded \/ dlSettled

ProxyPathSafe ==
    (~proxyEnabled) \/ proxyExcluded \/ proxySettled

ScxPathSafe ==
    (~scxEnabled) \/ scxExcluded \/ scxSettled

ClassLoopPathSafe ==
    (~classLoopNonFairEnabled) \/ classLoopExcluded \/ classLoopSettled

AllCrossPathsSafe ==
    /\ CorePathSafe
    /\ DlPathSafe
    /\ ProxyPathSafe
    /\ ScxPathSafe
    /\ ClassLoopPathSafe

ReadinessRequiresCrossPathSafety ==
    (ordinaryCfsScope /\ phase \notin {"Start", "OrdinaryCfsScopeRecorded"})
        => AllCrossPathsSafe

NoCoreBypass ==
    /\ ~coreCachedPickBypass
    /\ ~coreSiblingPickBypass
    /\ ~coreCookieReplacementBypass
    /\ ~coreCookieStealBypass

NoServerBorrowCollapse ==
    /\ ~dlFairServerBorrow
    /\ ~dlExtServerBorrow

NoProxyAuthorityCollapse ==
    ~proxyDonorExecutorMismatch

NoScxAuthorityRoot ==
    /\ ~scxSwitchedAllBypass
    /\ ~scxBpfAuthorityRoot

NoUnsupportedClassFallback ==
    ~classLoopUnsupportedPick

NoRetryTaskDenialProof ==
    ~retryTaskAsDenialProof

NoBehaviorOverclaim ==
    /\ ~behaviorPatchApproved
    /\ ~cfsDenyAndRepickApproved

NoProtectionCostOverclaim ==
    /\ ~runtimeCoverageClaim
    /\ ~productionProtectionClaim
    /\ ~costEfficiencyClaim
    /\ ~datacenterReadinessClaim

Safety ==
    /\ TypeOK
    /\ ReadinessRequiresCrossPathSafety
    /\ NoCoreBypass
    /\ NoServerBorrowCollapse
    /\ NoProxyAuthorityCollapse
    /\ NoScxAuthorityRoot
    /\ NoUnsupportedClassFallback
    /\ NoRetryTaskDenialProof
    /\ NoBehaviorOverclaim
    /\ NoProtectionCostOverclaim

====
