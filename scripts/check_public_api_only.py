#!/usr/bin/env python3
"""The flows may only use client methods the published wheel actually has.

Flow 4 shipped calling `client.get_meta(...)`, which exists on veriCue's master
and not in the published 0.5.0 client. The example therefore failed with
AttributeError against the very package it claims to demonstrate - and this
repository is the one place where "works against what a customer can install" is
the whole point.

Compares the `client.<method>(` calls in flows/ and clients/ against the
installed vericue package.

    python3 scripts/check_public_api_only.py
"""

import importlib
import inspect
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEARCH = [ROOT / "flows", ROOT / "clients"]
CALL = re.compile(r"\bclient\.([a-z_][a-z0-9_]*)\s*\(")


def available():
    try:
        module = importlib.import_module("vericue")
    except ImportError:
        return None, None
    client = getattr(module, "VeriCueClient")
    names = {name for name, _ in inspect.getmembers(client) if not name.startswith("_")}
    return names, getattr(module, "__version__", "unknown")


def main() -> int:
    names, version = available()
    if names is None:
        print("the vericue client is not installed - nothing to check against",
              file=sys.stderr)
        return 0        # not this check's job to install it

    problems = []
    for root in SEARCH:
        for path in sorted(root.rglob("*.py")):
            for lineno, line in enumerate(path.read_text().splitlines(), 1):
                for method in CALL.findall(line):
                    if method not in names:
                        problems.append(
                            f"{path.relative_to(ROOT)}:{lineno}: client.{method}() "
                            f"is not in the installed vericue {version}")

    if problems:
        print("examples call client methods the published package does not have:\n",
              file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        print("\nAn example that needs unreleased code is not an example a customer "
              "can run.", file=sys.stderr)
        return 1

    print(f"every client call in the examples exists in vericue {version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
