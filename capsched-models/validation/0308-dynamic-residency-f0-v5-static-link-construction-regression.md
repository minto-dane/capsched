# Dynamic Residency F0 v5 Static and Link Construction Regression

## Result

```text
grammar shape:                         PASS
grammar hostile mutations:            61/61
static rule shape:                     PASS
static rule hostile mutations:         83/83
generated schema reproducibility:      PASS
wire and resource mutations:           23/23
Core static hostile mutations:         51/51
link implementation field mutations:  56/56
local cross-verifier mutations:        21/21

Eval / Reads / transition / WF:        NOT IMPLEMENTED
external review:                       false
F0 local acceptance:                   false
K0/G0:                                 false
```

## Reproduction

```bash
python3 capsched-models/validation/validate-f0-machine-grammar-v5.py
python3 capsched-models/validation/test-f0-machine-grammar-v5-mutations.py
python3 capsched-models/validation/validate-f0-static-semantics-rules-v5.py
python3 capsched-models/validation/test-f0-static-semantics-rules-v5-mutations.py
python3 capsched-models/validation/generate-f0-strict-schemas-v5.py --check
python3 capsched-models/validation/test-f0-generated-schemas-v5.py
python3 capsched-models/validation/test-f0-core-syntax-v5.py
python3 capsched-models/validation/test-f0-linked-model-v5.py
python3 capsched-models/validation/test-f0-linked-model-validator-v5.py
```

The exact captured output SHA-256 values for this disposition were:

```text
grammar              fc7edcf5e5531935e1cdd8cc46014a50faa560ba7a333dfe491d125b6a1d24f0
grammar mutations    b91ef46d630b5f74fd66ea6682228bf18a81e7bf713513c18f681048d09c09c2
static rules         a53b20244de6fc4c72dfeaf52e270cabf3c1a28ed381c3711a4640351a3a0f78
static mutations     a8eecccc669ca8c5b7aaf6658a58c350d0c06cfcbb366bc9b6ff12fbb487eaad
generated check      99c0b0ae0ac086bdcb60b9f6196fea45712cd0dc5a36c7464593e9a21b1db9d7
wire mutations       c23bc556b62e85604450266eb7fba999e47ffab96797f30197b714da2ccfab31
Core mutations       a84a1891ad43ec8757e3bfb80c13364cde762c91457201521648a5dcc2e2e1c5
link mutations       ab4e390cd05faca674c352401f186b6ea2a36d69c699addb5c5648645b3d4fa7
cross-verifier       f9700cd5846a4511ecafb0b03b5c767e7ed86a84c8e0165faad01560f302388a
```

## Security Regressions

The campaign specifically demonstrates rejection or invariance for:

- post-check mutation of active modules and dependency maps;
- table and registry values changed together away from implemented semantics;
- direct mutable-dict checker construction;
- duplicate import and unnamed declarations below the wire layer;
- dormant action, premise, init, and claim body leakage;
- event default/source-origin laundering;
- carrier and payload sort changes hidden from construction identity;
- typed-ID kind/domain confusion and self-authorization;
- owner-module versus declaration-node invalidation scope confusion;
- deep JSON, excessive integer digits, duplicate keys, and noncanonical bytes;
- producer corruption detected by a separately implemented local reconstruction.

The local reconstruction consumes immutable source bytes rather than the
producer checker object. It is still local and shares the project rule contract,
so it is not external validation. All complete-model and protection flags stay
false.
