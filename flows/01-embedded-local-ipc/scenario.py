#!/usr/bin/env python3
"""Flow 1 scenario: drive demo_app over the local IPC endpoint it announced.

Requires veriCue v0.4.0 or newer (VeriCueClient.connect_local() talks
to VeriCueServer::startLocal(), which the v0.3.5 package does not have).

Run through flows/01-embedded-local-ipc/run.sh, which starts the application and
passes the endpoint it printed:

    python3 scenario.py --endpoint /run/user/1000/vericue/vericue-1234.sock
"""

import argparse
import asyncio
import sys

from vericue import VeriCueClient

WINDOW = "DemoMainWindow"
INPUT = f"{WINDOW}/centralWidget/inputField"
OK_BUTTON = f"{WINDOW}/centralWidget/okButton"
CHECKBOX = f"{WINDOW}/centralWidget/enableCheck"

_failures = 0


def check(label, actual, expected):
    """Assert without stopping at the first failure, so one run reports everything."""
    global _failures
    if actual == expected:
        print(f"  PASS  {label}: {actual!r}")
    else:
        _failures += 1
        print(f"  FAIL  {label}: expected {expected!r}, got {actual!r}")


async def run(endpoint: str, token: str | None) -> int:
    async with VeriCueClient() as client:
        # The only difference from a TCP run is this call - every command
        # below is transport independent.
        await client.connect_local(endpoint, token=token)
        print(f"Connected over local IPC: {endpoint}")
        print(f"Server version: {await client.version()}")

        print("\n1. Object lookup")
        found = await client.find_object(path=OK_BUTTON)
        print(f"  {found['path']} is a {found['className']}")
        check("okButton class", found["className"], "QPushButton")
        props = await client.get_properties(OK_BUTTON, ["text", "enabled"])
        check("okButton text", props["text"], "OK")

        print("\n2. Interaction: type into the line edit")
        await client.type_text(INPUT, "local-ipc")
        props = await client.get_properties(INPUT, ["text"])
        check("inputField text after typing", props["text"], "local-ipc")

        print("\n3. Interaction: click the checkbox, then verify its property")
        before = await client.get_properties(CHECKBOX, ["checked"])
        check("checkbox starts unchecked", before["checked"], False)
        await client.mouse_click(CHECKBOX)
        after = await client.get_properties(CHECKBOX, ["checked"])
        check("checkbox checked after the click", after["checked"], True)

        print("\n4. Property write and read back")
        await client.set_property(f"{WINDOW}/centralWidget/progressBar", "value", 77)
        props = await client.get_properties(f"{WINDOW}/centralWidget/progressBar", ["value"])
        check("progressBar value", props["value"], 77)

    return 1 if _failures else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--endpoint", required=True, help="Local IPC endpoint path")
    parser.add_argument("--token", default=None, help="Authentication token, if the app requires one")
    args = parser.parse_args()

    rc = asyncio.run(run(args.endpoint, args.token))
    print("\nScenario failed" if rc else "\nScenario passed")
    return rc


if __name__ == "__main__":
    sys.exit(main())
