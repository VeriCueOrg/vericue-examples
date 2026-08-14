#!/usr/bin/env python3
"""Flow 2 scenario: drive an application that never linked veriCue.

plain_app is launched by run.sh through vericue-inject; this script only sees
the local endpoint the injected veriCue Runtime announced.

Requires a veriCue build newer than v0.3.5 (local IPC).

    python3 scenario.py --endpoint /run/user/1000/vericue/vericue-1234.sock \
                        --screenshot /tmp/plain-app.png
"""

import argparse
import asyncio
import base64
import sys

from vericue import VeriCueClient

WINDOW = "PlainWindow"
INPUT = f"{WINDOW}/centralWidget/plainInput"
BUTTON = f"{WINDOW}/centralWidget/plainButton"

_failures = 0


def check(label, actual, expected):
    global _failures
    if actual == expected:
        print(f"  PASS  {label}: {actual!r}")
    else:
        _failures += 1
        print(f"  FAIL  {label}: expected {expected!r}, got {actual!r}")


def walk(nodes, depth=0):
    for node in nodes:
        print(f"  {'  ' * depth}{node.get('path', node.get('objectName'))} "
              f"[{node.get('className')}]")
        walk(node.get("children", []), depth + 1)


async def run(endpoint: str, screenshot: str, quit_app: bool) -> int:
    async with VeriCueClient() as client:
        await client.connect_local(endpoint)
        print(f"Connected over local IPC: {endpoint}")

        print("\n1. Object discovery inside an application with zero veriCue code")
        tree = await client.get_object_tree(root=WINDOW, depth=3)
        walk(tree)
        found = await client.find_object(path=BUTTON)
        check("plainButton class", found["className"], "QPushButton")

        print("\n2. Input: type into the line edit, then read the property back")
        await client.type_text(INPUT, "injected")
        props = await client.get_properties(INPUT, ["text"])
        check("plainInput text after typing", props["text"], "injected")

        print("\n3. Click: proven by the button's own clicked() signal")
        # The pushed signal event is the proof that the synthesized click
        # reached the real widget, not just that the request was accepted.
        sub_id = await client.subscribe_signal(BUTTON, "clicked")
        await client.mouse_click(BUTTON)
        try:
            event = await client.next_event(timeout=5.0)
            print(f"  event: {event['event']} {event['data']} from {event['path']}")
            check("event type", event["event"], "signal_emitted")
            check("signal that fired", event["data"]["signal"], "clicked")
            check("object that emitted it", event["path"], BUTTON)
        except asyncio.TimeoutError:
            global _failures
            _failures += 1
            print("  FAIL  no clicked() event arrived within 5s")
        await client.unsubscribe(sub_id)

        print("\n4. Screenshot of the window")
        shot = await client.screenshot(WINDOW)
        with open(screenshot, "wb") as handle:
            handle.write(base64.b64decode(shot["data"]))
        print(f"  saved {shot['width']}x{shot['height']} PNG to {screenshot}")
        check("screenshot has pixels", shot["width"] > 0 and shot["height"] > 0, True)

        if quit_app:
            print("\n5. Asking the application to close itself (clean shutdown)")
            try:
                await client.invoke_method(WINDOW, "close")
                print("  close() invoked")
            except Exception as exc:  # noqa: BLE001 - the app may go away mid-reply
                # Expected race: the process can finish quitting before the
                # response is flushed. run.sh verifies the outcome instead.
                print(f"  connection ended while closing ({type(exc).__name__}: {exc})")

    return 1 if _failures else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--endpoint", required=True, help="Local IPC endpoint path")
    parser.add_argument("--screenshot", required=True, help="Where to write the PNG")
    parser.add_argument("--keep-running", action="store_true",
                        help="Do not ask the application to close at the end")
    args = parser.parse_args()

    rc = asyncio.run(run(args.endpoint, args.screenshot, not args.keep_running))
    print("\nScenario failed" if rc else "\nScenario passed")
    return rc


if __name__ == "__main__":
    sys.exit(main())
