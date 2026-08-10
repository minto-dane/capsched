# Dynamic Residency F0 v5 Machine Draft-1 Parity Rejection

## Status

The exact first `DL-F0-5` machine-grammar construction passes its local
structural checker and all 38 structural mutations. It is nevertheless locally
rejected as a representation of Parts 00-02. This is negative design evidence,
not F0 acceptance or external assurance.

The machine-readable disposition is
`dynamic-residency-f0-v5-machine-draft1-parity-rejection-v1.json`.

## Exact Evidence

```text
machine grammar draft-1
  e8a8436845a6a0c97fae9be37883babaf565a8ecde4a94f5c7be61247d4899b6

meta-schema
  8bcf8f2d9361c7a90cced188756c0b3fc6aae0ed20e63e83a0290b56b9999508

shape checker
  bb1975251c1329f786275da22e697e4655919f0a6044127df1fdca71611d0373
  output f8c47329bd8d75f6ca05d2d2c05050848091e66e31add59c102e0f26b71d1166

mutation runner
  99e06a9294a939ae59f06b88b7dbc89831d79d9a7a8f57601b7fb3fa32f99402
  38/38 rejected at the expected structural class
  output 41ebb1ddf832c286304edfa5ffb2b910ee0a1accfac2c944274e45d74a455551
```

The checker read each JSON file once, rejected duplicate keys and unsafe
scalars before schema validation, pinned the meta-schema, checked the exact
three normative paths and 10/12/10 heading ranges, built a global constructor
symbol table, closed unions and bindings, resolved every field kind, classified
all roots, checked forbidden-node disjointness, and retained every promotion
flag as false.

## Review Provenance

| Axis | Session | Result |
| --- | --- | --- |
| grammar/meta-schema self-description | `019fea0f-eebf-7a20-98a3-5b840126bbc6` | local advisory reject |
| Markdown-to-AST semantic parity | `019fea10-0337-7742-aecf-5a2fb4107656` | local advisory reject |
| validator and mutation oracle | `019fea10-1c3d-7703-b0f4-085ec5766d2e` | local advisory reject |

These are independent local read-only analyses. None has an F3 external role.

## Direct Contradictions

1. `DECL_ACTION` declares a parameter sort but no parameter variable. A
   `TERM_VARIABLE` therefore cannot be linked to the exact PARAM binder without
   an undocumented reserved name.
2. The prose requires explicit polymorphic result sorts, while recursive AST
   positions contain unannotated constructor nodes.
3. Qty addition/subtraction has no machine binding from a Qty sort to its
   nominal arithmetic-result Variant.
4. The class-premise inventory cannot represent its stated Atom carrier and
   exact cardinality constraints without an undocumented lowering.
5. `SCOPE_EXACT` points to a finite profile and therefore narrows arbitrary
   `InstanceWF` interpretations to executable finite instances.

## Missing Dependency Closure

The draft has no complete machine representation for finite states, locations,
cells, event bundles, dependent labels, transitions, or finite runs. It also has
no recursive typing/provenance/Eval/Reads rule tables, generated Apply/Bundle/
BranchStep/Step rules, three WF judgments, claim-bound witness packages,
morphisms, theorem statements, proof objects, replay objects, checker protocol,
or reject taxonomy.

The completion ledger named many of these gaps but omitted enough of them that
removing one vague label could falsely look like progress. Every gap in the
successor must have a positive closure predicate and a required artifact or
rule family.

## Representation Risks

- Minimum-only node tables allowed a field signature or extra constructor to
  change under the same draft identity.
- Primitive kinds had names but no exact JSON representation.
- Collection suffixes fixed cardinality but not sequence/set/map identity,
  uniqueness, or canonical order.
- Model, profile, and scope entry points were implicit.
- A candidate-controlled meta-schema could not authenticate itself; the local
  checker had to pin it independently.

## Successor Order

ADR-0021 requires the next construction to close, in order:

```text
1. checked Term wrapper, explicit binders, arithmetic binding, Atom class
2. primitive wire types, roots, exact collection/canonicalization policies
3. arbitrary exact-interpretation reference and real Scope union
4. finite state/event/label/transition/run replay carriers
5. exact surface digest and strict generated schemas
6. typing/provenance/Eval/Reads/transition/WF rule tables and checker
7. claim packages, mutations, replay, morphisms, theorem/proof/checker grammar
8. bidirectional parity ledger, semantic mutants, exact fresh hostile review
```

No later phase may cite the 38/38 result as semantic validation.
