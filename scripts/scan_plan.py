#!/usr/bin/env python3
"""Scan a Terraform plan JSON for destructive actions.

The guard fails when a plan would delete (or replace, which includes a delete)
a resource that is not explicitly listed in the module's
testing/.checkov-allowlist.json.

Allowlist schema:

    {
      "allowed_deletes": [
        {
          "address": "aws_s3_bucket.example",
          "action": "delete",          # delete | replace | any
          "reason": "reviewed in CHG-1234"
        }
      ]
    }

Usage:
    scan_plan.py --plan plan.json --allowlist testing/.checkov-allowlist.json
    scan_plan.py --self-test
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
FIXTURES = HERE / "testdata"


def load_allowlist(path: Path) -> list[dict]:
    if not path.exists():
        return []
    data = json.loads(path.read_text())
    return data.get("allowed_deletes", [])


def classify(actions: list[str]) -> str | None:
    if "delete" not in actions:
        return None
    if "create" in actions:
        return "replace"
    return "delete"


def scan(plan: dict, allowlist: list[dict]) -> list[dict]:
    violations: list[dict] = []
    for change in plan.get("resource_changes", []):
        actions = change.get("change", {}).get("actions", [])
        kind = classify(actions)
        if kind is None:
            continue
        address = change.get("address", "<unknown>")
        allowed = any(
            entry.get("address") == address
            and entry.get("action", "any") in ("any", kind)
            for entry in allowlist
        )
        if allowed:
            continue
        violations.append(
            {
                "address": address,
                "action": kind,
                "actions": actions,
                "module": change.get("module_address", "root"),
                "type": change.get("type", "unknown"),
            }
        )
    return violations


def report(violations: list[dict]) -> None:
    if not violations:
        print("destroy-guard: no destructive actions planned")
        return
    print(f"destroy-guard: {len(violations)} destructive action(s) not allowlisted:")
    for violation in violations:
        print(
            f"  - {violation['action']:<8} {violation['address']} "
            f"(module: {violation['module']}, actions: {violation['actions']})"
        )
    print(
        "\nAdd a reviewed entry to testing/.checkov-allowlist.json only after "
        "confirming the blast radius and the backup/restore path."
    )


def self_test() -> int:
    cases = [
        ("plan-clean.json", "allowlist-empty.json", 0),
        ("plan-with-delete.json", "allowlist-empty.json", 1),
        ("plan-with-replace.json", "allowlist-empty.json", 1),
        ("plan-with-delete.json", "allowlist-permits-delete.json", 0),
        ("plan-with-replace.json", "allowlist-permits-delete.json", 1),
    ]
    failures = 0
    for plan_name, allowlist_name, expected in cases:
        plan = json.loads((FIXTURES / plan_name).read_text())
        allowlist = load_allowlist(FIXTURES / allowlist_name)
        actual = 1 if scan(plan, allowlist) else 0
        status = "ok" if actual == expected else "FAILED"
        print(f"self-test {plan_name} + {allowlist_name}: expected {expected}, got {actual} [{status}]")
        if actual != expected:
            failures += 1
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--allowlist", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        failures = self_test()
        if failures:
            print(f"destroy-guard self-test: {failures} case(s) failed", file=sys.stderr)
            return 1
        print("destroy-guard self-test: all cases passed")
        return 0

    if not args.plan or not args.allowlist:
        parser.error("--plan and --allowlist are required unless --self-test is used")

    plan = json.loads(args.plan.read_text())
    violations = scan(plan, load_allowlist(args.allowlist))
    report(violations)
    return 1 if violations else 0


if __name__ == "__main__":
    raise SystemExit(main())
