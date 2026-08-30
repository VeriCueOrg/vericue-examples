#!/usr/bin/env python3
"""Flow 4 scenario: automate an application veriCue was never built into.

run.sh starts plain_app with `vericue run`; this script only receives the
endpoint that command announced. Nothing here knows how the Runtime got into the
process, which is the point - the same client code works against an embedded
server (flow 1).

    python3 scenario.py --endpoint /run/user/1000/vericue/vericue-1234.sock
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


async def run(endpoint: str, screenshot: str, quit_app: bool) -> int:
    async with VeriCueClient() as client:
        await client.connect_local(endpoint)
        print(f"Connected to the application `vericue run` started: {endpoint}")

        print("\n1. Find the element by path - the path `vericue inspect` shows you")
        found = await client.find_object(path=BUTTON)
        check("plainButton class", found["className"], "QPushButton")

        print("\n2. What state does this element expose?")
        # Every property of the real widget, read out of the live object - the
        # same values the Inspector shows beside the element you pick.
        #
        # Deliberately get_properties and not a richer introspection call: this
        # example must run against the published client, and adding a call that
        # only exists on master would make it a demo of something a customer
        # cannot install.
        props = await client.get_properties(BUTTON)
        print(f"  {len(props)} properties, including: "
              f"{', '.join(sorted(props)[:8])}")
        check("the button carries its label", props.get("text"), "Do nothing")
        check("it is enabled", props.get("enabled"), True)

        print("\n3. Type into the line edit, then read the property back")
        await client.type_text(INPUT, "started by vericue run")
        props = await client.get_properties(INPUT, ["text"])
        check("plainInput text", props["text"], "started by vericue run")

        print("\n4. Click, proven by the widget's own clicked() signal")
        # The pushed event is the proof the synthesised click reached the real
        # widget - not merely that the request was accepted.
        sub_id = await client.subscribe_signal(BUTTON, "clicked")
        await client.mouse_click(BUTTON)
        try:
            event = await client.next_event(timeout=5.0)
            check("signal that fired", event["data"]["signal"], "clicked")
            check("object that emitted it", event["path"], BUTTON)
        except asyncio.TimeoutError:
            global _failures
            _failures += 1
            print("  FAIL  no clicked() event arrived within 5s")
        await client.unsubscribe(sub_id)

        if screenshot:
            print("\n5. Screenshot of the window")
            shot = await client.screenshot(WINDOW)
            with open(screenshot, "wb") as handle:
                handle.write(base64.b64decode(shot["data"]))
            print(f"  saved {shot['width']}x{shot['height']} PNG to {screenshot}")
            check("screenshot has pixels", shot["width"] > 0 and shot["height"] > 0, True)

        if quit_app:
            print("\n6. Asking the application to close itself")
            try:
                await client.invoke_method(WINDOW, "close")
                print("  close() invoked")
            except Exception as exc:  # noqa: BLE001 - the app may go away mid-reply
                print(f"  connection ended while closing ({type(exc).__name__}: {exc})")

    return 1 if _failures else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--screenshot", default="")
    parser.add_argument("--no-quit", action="store_true")
    args = parser.parse_args()
    return asyncio.run(run(args.endpoint, args.screenshot, not args.no_quit))


if __name__ == "__main__":
    sys.exit(main())
