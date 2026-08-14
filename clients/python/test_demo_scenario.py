"""The canonical veriCue scenario, in Python (pytest + the shipped client).

The identical four steps exist in C++ (clients/cpp) and C# (clients/csharp):

    1. address a stable object and check what it is;
    2. drive a text input and read the resulting property;
    3. click a checkbox and check the state actually changed;
    4. capture a screenshot as a retained artifact.

Run it through clients/python/run.sh, which starts demo_app and exports the
endpoint. Everything below is the real shipped API - no wrappers, no mocks.
"""

import base64
import os

import pytest

from conftest import CHECKBOX, INPUT, WINDOW, artifact_dir

pytestmark = pytest.mark.asyncio(loop_scope="module")

TYPED_TEXT = "vericue"


async def test_object_is_addressable(client):
    """1. The object path resolves, and to the class we expect."""
    found = await client.find_object(path=CHECKBOX)
    assert found["className"] == "QCheckBox"
    assert found["path"] == CHECKBOX


async def test_typing_updates_the_text_property(client):
    """2. Input action: real key events, then read the property back."""
    # Start from a known value, so the assertion is an equality and not a
    # "ends with" - type_text appends at the cursor like a user would.
    await client.set_property(INPUT, "text", "")

    await client.type_text(INPUT, TYPED_TEXT)

    props = await client.get_properties(INPUT, ["text"])
    assert props["text"] == TYPED_TEXT


async def test_click_toggles_the_checkbox(client):
    """3. State change: assert against the state before the click."""
    before = (await client.get_properties(CHECKBOX, ["checked"]))["checked"]

    await client.mouse_click(CHECKBOX)

    after = (await client.get_properties(CHECKBOX, ["checked"]))["checked"]
    assert after is not before


async def test_screenshot_is_captured(client):
    """4. Screenshot of the window, written where CI can retain it."""
    shot = await client.screenshot(WINDOW)
    data = base64.b64decode(shot["data"])

    out = os.path.join(artifact_dir(), "demo_app-python.png")
    with open(out, "wb") as handle:
        handle.write(data)

    assert shot["width"] > 0 and shot["height"] > 0
    # PNG magic - proves the bytes survived the base64 round trip.
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    assert os.path.getsize(out) > 0
