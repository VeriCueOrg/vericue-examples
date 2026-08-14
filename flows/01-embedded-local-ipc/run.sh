#!/bin/sh
# Flow 1 - embedded veriCue Runtime on a local IPC endpoint.
#
# REQUIRES veriCue v0.4.0 OR NEWER, the current package on
# https://dl.vericue.dev. VeriCueServer::startLocal() and the VERICUE_ENDPOINT
# announcement are not in v0.3.5; on that legacy version use
# flows/03-tcp-explicit instead.
#
# Local IPC is supported on Linux and macOS. On Windows use the TCP flow.
#
# What it does:
#   1. starts demo_app, which starts the veriCue Runtime with startLocal()
#   2. reads the resolved endpoint from the app's stdout (VERICUE_ENDPOINT=...)
#   3. talks to it with the CLI (python -m vericue --endpoint ...)
#   4. runs scenario.py: object lookup -> interaction -> property assertion
#
# Usage: flows/01-embedded-local-ipc/run.sh
# Environment: VERICUE_DEMO_APP=<path>  use this demo_app binary
#              PYTHON=<interpreter>     python that can import vericue

set -eu

FLOW_NAME=flow-01-embedded-local-ipc
unset CDPATH
flow_dir=$(cd -- "$(dirname -- "$0")" && pwd)
FLOW_REPO_ROOT=$(cd -- "$flow_dir/../.." && pwd)
export FLOW_REPO_ROOT
. "$FLOW_REPO_ROOT/flows/lib.sh"

app_pid=""
log=$(mktemp "${TMPDIR:-/tmp}/vericue-flow-01.XXXXXX")

cleanup() {
    if [ -n "$app_pid" ] && kill -0 "$app_pid" 2>/dev/null; then
        kill "$app_pid" 2>/dev/null || true
        wait "$app_pid" 2>/dev/null || true
    fi
    rm -f "$log"
}
trap cleanup EXIT INT TERM

flow_python
flow_headless_default
flow_find_binary "the demo app (vericue-demo-app)" "${VERICUE_DEMO_APP:-}" demo_app/vericue-demo-app
demo_app=$FLOW_BINARY

flow_step "Starting $demo_app with an embedded veriCue Runtime on local IPC"
"$demo_app" --endpoint >"$log" 2>&1 &
app_pid=$!

# No fixed socket path and no sleeping: the endpoint is whatever the runtime
# resolved, and the app announces it on stdout.
flow_wait_for VERICUE_ENDPOINT "$log" "$app_pid" 20
endpoint=$FLOW_VALUE
printf 'Endpoint: %s\n' "$endpoint"
ls -l "$endpoint"

flow_step "CLI over the same endpoint: python -m vericue --endpoint <path> find_object"
"$FLOW_PYTHON" -m vericue --endpoint "$endpoint" find_object --path DemoMainWindow/centralWidget/okButton

flow_step "Python client scenario (lookup, interaction, property assertion)"
"$FLOW_PYTHON" "$flow_dir/scenario.py" --endpoint "$endpoint"

flow_step "Flow 1 finished successfully"
