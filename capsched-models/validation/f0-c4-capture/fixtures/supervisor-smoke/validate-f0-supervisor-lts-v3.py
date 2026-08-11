#!/usr/bin/python3
import argparse
import json


parser = argparse.ArgumentParser()
parser.add_argument("--component", required=True)
args = parser.parse_args()
print(
    "RESULT_JSON="
    + json.dumps(
        {
            "component": args.component,
            "mechanism_fixture_only": True,
            "authorization_changed": False,
        },
        sort_keys=True,
        separators=(",", ":"),
    )
)
