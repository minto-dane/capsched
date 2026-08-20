# Dynamic Residency F0 v5 Static Semantics and Immutable Link Closure

## Status

The DL-F0-5 construction now has a locally closed source-static and link-
construction substage. This is not complete `CoreSyntaxWF`, F0 acceptance,
external assurance, or model support. `Eval`, `Reads`, transition semantics,
`InstanceWF`, claims, morphisms, proof checking, F1, F2, F3, K0/G0, and TLA+
remain false or absent.

The machine-readable disposition is
`dynamic-residency-f0-v5-static-link-construction-closure-v1.json`.

## Closed Boundary

The production path now has these distinct stages:

```text
canonical Model bytes
  -> canonical wire/schema/collection validation
  -> immutable WireValidatedModelSnapshot
  -> source static checker reparses snapshot bytes
  -> linker reparses snapshot bytes and materializes construction
  -> local cross-implementation verifier reparses source and artifact bytes
```

The snapshot stores immutable bytes and validation evidence, not a mutable
decoded object. `CoreSyntaxChecker(dict)` is rejected. The explicit internal
test factory cannot claim wire validation. Link construction no longer reads
`checker.modules`, `checker.active_modules`, or any other post-check mutable
derived map.

The source checker binds 10 sort, 11 premise, 42 term, 2 update, 8 body, and 5
binder handler families. It independently rederives every term result sort,
provenance set, and lexical binder-context fingerprint. Duplicate imports,
unnamed declarations, action branches, and channel emits reject in depth even
when the production wire boundary is bypassed by a hostile unit test.

## Hostile Audit Disposition

Two fresh local read-only audits were intentionally performed after the first
implementation. They are advisory local reviews, not F3 external authorities.

| Review | Finding | Disposition |
| --- | --- | --- |
| `019feab2-ad52-75d1-b329-88ab4c9e2d46` | mutable checker state could split `ModelArtifactId` from active modules and dependency projection | closed by byte-only snapshot and producer/verifier reparse; exact post-check mutation regression added |
| same | table/registry parity did not bind link-rule values to implementation behavior | closed by an implementation-owned accepted-value contract and 56 field-level hostile mutations |
| same | direct dict checker bypassed wire uniqueness/canonicalization | closed by snapshot-only constructor plus duplicate import/unnamed declaration defense |
| same | deep JSON and 5000-digit integers escaped as host exceptions | closed by bounded iterative tree validation and stable resource rejects at wire, snapshot, static-rule, and artifact boundaries |
| `019feab2-e01a-7243-af45-d4f330738d95` | local verifier shared mutable checker state and overstated independence | closed by source-byte reparse and renamed local cross-implementation authority; `independently_validated` remains false |
| same | identity preimages and invalidation scopes were inconsistent or implicit | closed by seven machine-readable typed preimage rules and differential invalidation tests |
| same | alpha-renaming policy was unstated | construction spelling is explicitly significant; future semantic alpha policy is unresolved and blocks final semantic-ID issuance |
| same | dormant-body and carrier semantic-difference matrix was incomplete | dormant init/premise/action stability, carrier-sort sensitivity, same-module unrelated change, and alpha-renaming tests added |

The local cross verifier still shares the project and its normative rule
contract. It reduces implementation variance but is not organizationally,
cryptographically, or externally independent. Its result is therefore named
`locally_cross_reconstructed`; `linked_model_independently_validated` and
`external_review` remain false.

## Identity Contract

Seven issued construction ID kinds have exact domain, preimage field order,
stability, and binder policy rows:

```text
MODEL_ARTIFACT
MODULE_ARTIFACT
SOURCE_DECLARATION_ARTIFACT
BODY_ORIGIN
SOURCE_ACTION_ARTIFACT
LINKED_SEMANTIC_PROJECTION_CONSTRUCTION
LINKED_MODEL_CONSTRUCTION
```

`SourceDeclarationArtifactId` is declaration-node scoped and is stable under
an unrelated declaration change. `ModuleArtifactId`, `BodyOriginId`, and
`SourceActionArtifactId` are owner-module-occurrence scoped and invalidate on
that change. The action artifact is now a domain-separated typed ID whose
preimage contains a typed `ModuleArtifactId`, not a bare module digest.

No `SourceActionSemanticId`, `LinkedActionSemanticId`, `LinkedActionId`, or
`LinkedModelSemanticId` is issued. The future semantic alpha-normalization,
reference graph, state carrier, event completion, observer plan, semantic
context, and validation context are still missing.

## Exact Local Evidence

```text
grammar raw
  6717164ade360574018ad04f3ef2cd1fd51b67ec2e33ea1055ab7ebfbc619445
grammar surface
  02503654aae81c865cc1446fe707a49e9c50821603c41bb113dd017f79801039
static rules raw
  d020b64ed44b115940b4165a3aed5cdc152a72d14170dc86e48a1a3cb8fafee5
static rules canonical
  f01abcf53e359712819e34296de1dc6059bb238a17362fed171ebe38a7f51bbc
generated manifest
  f689b99b6f251d3265157a4f1760b9c264f564599fc62eb876614ebaae76635e

grammar hostile mutations       61/61
static-rule hostile mutations   83/83
wire/resource hostile mutations 23/23
Core static hostile mutations   51/51
link-rule field mutations       56/56
local cross-verifier mutations  21/21
```

These passes establish only their named local rejection and reconstruction
properties. They do not prove denotational adequacy or metatheory.

## Successor

The next admissible construction is the complete syntax-directed `Eval` and
`Reads` layer. It must define environments, finite interpretation lookup,
failure versus inconclusive behavior, exact term denotation, read footprints,
and a constructor-complete hostile oracle before transition semantics begins.
