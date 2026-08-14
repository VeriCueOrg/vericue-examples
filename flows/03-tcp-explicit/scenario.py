#!/usr/bin/env python3
"""Flow 3 scenario: drive demo_app over TCP, with authentication.

Works with the released v0.3.5 package - this flow uses no local IPC.

    python3 scenario.py --host 127.0.0.1 --port 38123 --token <token>
"""

import argparse
import asyncio
import sys

from vericue import ServerError, VeriCueClient

WINDOW = "DemoMainWindow"
INPUT = f"{WINDOW}/centralWidget/inputField"
CHECKBOX = f"{WINDOW}/centralWidget/enableCheck"

# 1007 authentication_required, 1008 authentication_failed.
AUTH_ERROR_CODES = (1007, 1008)

_failures = 0


def check(label, actual, expected):
    global _failures
    if actual == expected:
        print(f"  PASS  {label}: {actual!r}")
    else:
        _failures += 1
        print(f"  FAIL  {label}: expected {expected!r}, got {actual!r}")


def fail(label, detail):
    global _failures
    _failures += 1
    print(f"  FAIL  {label}: {detail}")


async def run(host: str, port: int, token: str) -> int:
    print("1. A TCP port is reachable by anything that can route to this host,")
    print("   so the port is useless without the token:")
    unauthenticated = VeriCueClient(timeout=5.0)
    try:
        await unauthenticated.connect(host, port)
        fail("connection without a token", "the server accepted it")
    except ServerError as exc:
        if exc.code in AUTH_ERROR_CODES:
            print(f"  PASS  rejected without a token: error {exc.code} ({exc})")
        else:
            fail("connection without a token", f"unexpected error {exc.code}: {exc}")
    finally:
        await unauthenticated.disconnect()

    # The refused connection still occupied an automation session for a moment;
    # give the server the round trip it needs to release it before reconnecting.
    await asyncio.sleep(0.5)

    async with VeriCueClient() as client:
        await client.connect(host, port, token=token)
        print(f"\n2. Authenticated over TCP: {host}:{port}")
        print(f"   server version: {await client.version()}")

        print("\n3. Object lookup")
        found = await client.find_object(path=CHECKBOX)
        check("enableCheck class", found["className"], "QCheckBox")

        print("\n4. Interaction and property assertion")
        await client.type_text(INPUT, "over-tcp")
        props = await client.get_properties(INPUT, ["text"])
        check("inputField text after typing", props["text"], "over-tcp")

        await client.mouse_click(CHECKBOX)
        props = await client.get_properties(CHECKBOX, ["checked"])
        check("checkbox checked after the click", props["checked"], True)

    return 1 if _failures else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--token", required=True)
    args = parser.parse_args()

    rc = asyncio.run(run(args.host, args.port, args.token))
    print("\nScenario failed" if rc else "\nScenario passed")
    return rc


if __name__ == "__main__":
    sys.exit(main())
