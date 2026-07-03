# P5A-R Overhead and Layout Gate Model

This model backs the pre-code overhead/layout gate for P5A-R.

It requires the first ordinary-CFS denial candidate to remain attempt-local,
bounded, pre-frozen, and free of unbounded picker scans or persistent hot denial
layout. It rejects disabled-overhead and hot-function/layout claims without
separate generated-object evidence, and rejects cost/protection claims from
model evidence alone.
