#!/usr/bin/env python3
"""Validate the DL-F0-5 construction-draft static semantics rule table."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import f0_static_rules_v5 as static_rules


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rules", type=Path, default=static_rules.RULES_PATH)
    parser.add_argument("--grammar", type=Path, default=static_rules.GRAMMAR_PATH)
    args = parser.parse_args()
    contract = static_rules.load_contract(args.rules, args.grammar)
    print(json.dumps(static_rules.result(contract), sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except static_rules.Reject as exc:
        print(
            json.dumps(
                {
                    "status": "rejected",
                    "reject_id": exc.reject_id,
                    "detail": exc.detail,
                    "static_rule_table_complete": False,
                    "CoreSyntaxWF": False,
                    "F0_local_acceptance": False,
                    "protection_claim": False,
                },
                sort_keys=True,
                separators=(",", ":"),
            )
        )
        raise SystemExit(1)
