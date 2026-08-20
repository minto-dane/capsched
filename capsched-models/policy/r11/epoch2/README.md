# R11 G0 Epoch-2 Draft

This namespace contains the successor to the rejected R11 G0 v1 candidate.
It is a local draft and has no external authority.

The first `semantic-kernel-contract-v2.json` draft is rejected before
implementation and retained unchanged. It listed a closed language but did not
define its mathematical denotation and mixed pre-candidate and candidate gates.
See `REJECTED-semantic-kernel-v2.md`, ADR-0018, Analysis 0215, and Validation
0304.

The exact v3 successor is also rejected and retained unchanged. It improved the
base denotation, but four local reviews found that the typed action calculus,
claim extensions, platform refinement, and complete K0 source set were still
open. See `REJECTED-semantic-foundation-v3.md`, ADR-0019, Analysis 0216, and
Validation 0305.

The v4 successor is decomposed rather than weakened:

```text
F0  typed transition calculus and metatheory
F1  claim-specific semantics and composition
F2  platform refinement and threat over-approximation
F3  externally owned policy, coverage, mutation, and assurance package
```

The first exact F0 v4 draft is also locally rejected after four exact-hash
reviews, despite passing identity checks and 21 structural mutations. ADR-0020,
Analysis 0217, and Validation 0306 authorize only F0 v5 design. Candidate
architecture IR remains forbidden until a complete F0-F3 source set receives a
real external K0 decision.

Current authorization:

```text
local v3 structural regression  pass, rejected semantically
local F0 v4 identity checks      pass, rejected semantically
local F0 v5 design               yes
external adoption                no
K0/G0                            false
candidate R11 machine IR         no
semantic freeze                  no
TLA+                             no
model support                    no
```

The exact rejected v1 bundle remains in the parent directory and must not be
edited in place.
