"""Fixtures for the canonical veriCue scenario in Python.

The connection is configured entirely from the environment, using the same
variable names as the C++ (GoogleTest) and C# (xUnit) versions of this
scenario and as the shipped GoogleTest fixture:

    VERICUE_ENDPOINT   local IPC socket path  -> connect_local()
    VERICUE_HOST/PORT  TCP                    -> connect()
    VERICUE_TOKEN      authentication token, optional on local IPC

`clients/python/run.sh` starts demo_app and exports one of the two sets;
nothing here hard-codes a port or a socket path.

One connection is shared by the whole module: the veriCue trial licence
allows a single automation session at a time, and reconnecting per test would
buy nothing.
"""

import os

import pytest
import pytest_asyncio

from vericue import VeriCueClient

# Object paths in demo_app (examples/demo_app/main.cpp). Every widget there is
# given an explicit objectName, which is what makes these paths stable.
WINDOW = "DemoMainWindow"
INPUT = f"{WINDOW}/centralWidget/inputField"
CHECKBOX = f"{WINDOW}/centralWidget/enableCheck"


def artifact_dir() -> str:
    """Directory for screenshots and other retained evidence.

    CI overrides it with VERICUE_ARTIFACT_DIR and uploads the contents; see
    clients/ci/run.sh.
    """
    path = os.environ.get("VERICUE_ARTIFACT_DIR", "vericue-artifacts")
    os.makedirs(path, exist_ok=True)
    return path


@pytest_asyncio.fixture(scope="module", loop_scope="module")
async def client():
    """A connected VeriCueClient, over whichever transport the env selects."""
    endpoint = os.environ.get("VERICUE_ENDPOINT")
    port = os.environ.get("VERICUE_PORT")
    token = os.environ.get("VERICUE_TOKEN") or None

    if not endpoint and not port:
        pytest.skip(
            "No veriCue endpoint configured. Run clients/python/run.sh, or set "
            "VERICUE_ENDPOINT=<socket> (local IPC) or VERICUE_PORT=<n> "
            "(TCP, with VERICUE_TOKEN if the app requires one)."
        )

    connected = VeriCueClient(timeout=10.0)
    if endpoint:
        await connected.connect_local(endpoint, token=token)
    else:
        await connected.connect(
            os.environ.get("VERICUE_HOST", "127.0.0.1"), int(port), token=token
        )
    try:
        yield connected
    finally:
        await connected.disconnect()
