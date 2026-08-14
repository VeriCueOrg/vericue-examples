#!/bin/sh
# The CI/reporting flow: run the canonical scenario and leave behind the
# artifacts a CI system consumes.
#
# It produces three report files plus the screenshot the scenario captures:
#
#   junit.xml             pytest's own JUnit XML (--junitxml)
#   vericue-report.xml    veriCue's JUnit XML   (the shipped pytest plugin)
#   vericue-report.html   veriCue's HTML report (the shipped pytest plugin)
#   demo_app-python.png   screenshot captured by the scenario
#
# All four land in one directory (VERICUE_ARTIFACT_DIR, default
# clients/ci/artifacts) so a CI job can upload it with a single glob. The
# reports are written whether the tests pass or fail - a failing run is
# exactly when you want them - and this script exits with pytest's status.
#
# Usage: clients/ci/run.sh
# Environment: PYTHON=<interpreter>       python that can import vericue+pytest
#              VERICUE_DEMO_APP=<path>    use this demo_app binary
#              VERICUE_TRANSPORT=local|tcp  default local (Linux/macOS);
#                                           use tcp on Windows or across hosts
#              VERICUE_ARTIFACT_DIR=<dir>   where the artifacts are written

set -eu

FLOW_NAME=clients-ci
unset CDPATH
here=$(cd -- "$(dirname -- "$0")" && pwd)
FLOW_REPO_ROOT=$(cd -- "$here/../.." && pwd)
export FLOW_REPO_ROOT
. "$FLOW_REPO_ROOT/flows/lib.sh"

app_pid=""
log=$(mktemp "${TMPDIR:-/tmp}/vericue-clients-ci.XXXXXX")

cleanup() {
    flow_stop_app "$app_pid"
    rm -f "$log"
}
trap cleanup EXIT INT TERM

flow_python
flow_headless_default
"$FLOW_PYTHON" -c 'import pytest, pytest_asyncio' >/dev/null 2>&1 || flow_die \
    "pytest and pytest-asyncio are needed for this flow:
  $FLOW_PYTHON -m pip install vericue pytest pytest-asyncio"

VERICUE_ARTIFACT_DIR=${VERICUE_ARTIFACT_DIR:-$here/artifacts}
export VERICUE_ARTIFACT_DIR
rm -rf "$VERICUE_ARTIFACT_DIR"
mkdir -p "$VERICUE_ARTIFACT_DIR"

flow_step "Starting demo_app (${VERICUE_TRANSPORT:-local} transport)"
flow_start_demo_app "${VERICUE_TRANSPORT:-local}" "$log"
app_pid=$FLOW_APP_PID

flow_step "Running the scenario with reporting enabled"
status=0
"$FLOW_PYTHON" -m pytest "$FLOW_REPO_ROOT/clients/python/test_demo_scenario.py" -v \
    --junitxml="$VERICUE_ARTIFACT_DIR/junit.xml" \
    --vericue-report-xml="$VERICUE_ARTIFACT_DIR/vericue-report.xml" \
    --vericue-report-html="$VERICUE_ARTIFACT_DIR/vericue-report.html" \
    --vericue-report-name="veriCue demo_app scenario" || status=$?

flow_stop_app "$app_pid"
app_pid=""

flow_step "Artifacts in $VERICUE_ARTIFACT_DIR"
ls -l "$VERICUE_ARTIFACT_DIR"

for artifact in junit.xml vericue-report.xml vericue-report.html; do
    [ -s "$VERICUE_ARTIFACT_DIR/$artifact" ] || flow_die "$artifact was not written"
done

if [ "$status" -eq 0 ]; then
    flow_step "CI flow finished successfully"
else
    printf '\n%s: the scenario failed (pytest exit %s) - the reports above hold the detail\n' \
        "$FLOW_NAME" "$status" >&2
fi
exit "$status"
