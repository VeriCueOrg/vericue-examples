#!/bin/sh
# The canonical scenario in Python (pytest), run over both transports.
#
# The scenario itself never mentions a transport: it reads VERICUE_ENDPOINT or
# VERICUE_HOST/VERICUE_PORT/VERICUE_TOKEN from the environment (see
# conftest.py). This script starts demo_app twice - once on local IPC, once on
# TCP with a per-run token - and runs the same test module against each.
#
# Usage: clients/python/run.sh [pytest arguments...]
# Environment: PYTHON=<interpreter>    python that can import vericue + pytest
#              VERICUE_DEMO_APP=<path> use this demo_app binary
#              VERICUE_TRANSPORTS="local tcp" restrict to one transport

set -eu

FLOW_NAME=clients-python
unset CDPATH
here=$(cd -- "$(dirname -- "$0")" && pwd)
FLOW_REPO_ROOT=$(cd -- "$here/../.." && pwd)
export FLOW_REPO_ROOT
. "$FLOW_REPO_ROOT/flows/lib.sh"

app_pid=""
log=$(mktemp "${TMPDIR:-/tmp}/vericue-clients-python.XXXXXX")

cleanup() {
    flow_stop_app "$app_pid"
    rm -f "$log"
}
trap cleanup EXIT INT TERM

flow_python
flow_headless_default
"$FLOW_PYTHON" -c 'import pytest, pytest_asyncio' >/dev/null 2>&1 || flow_die \
    "pytest and pytest-asyncio are needed for this scenario:
  $FLOW_PYTHON -m pip install vericue pytest pytest-asyncio"

VERICUE_ARTIFACT_DIR=${VERICUE_ARTIFACT_DIR:-$here/artifacts}
export VERICUE_ARTIFACT_DIR

for transport in ${VERICUE_TRANSPORTS:-local tcp}; do
    flow_step "Python scenario over $transport"
    flow_start_demo_app "$transport" "$log"
    app_pid=$FLOW_APP_PID

    # The report paths are given explicitly: the shipped pytest plugin
    # otherwise writes vericue_report.{html,xml} into the current directory.
    "$FLOW_PYTHON" -m pytest "$here/test_demo_scenario.py" -v \
        --vericue-report-html="$VERICUE_ARTIFACT_DIR/vericue-report-$transport.html" \
        --vericue-report-xml="$VERICUE_ARTIFACT_DIR/vericue-report-$transport.xml" \
        --vericue-report-name="veriCue demo_app scenario ($transport)" "$@"

    flow_stop_app "$app_pid"
    app_pid=""
done

flow_step "Python scenario passed on: ${VERICUE_TRANSPORTS:-local tcp}"
printf 'Artifacts: %s\n' "$VERICUE_ARTIFACT_DIR"
