#!/bin/sh
# Flow 3 - explicit TCP transport, with an ephemeral port and a token.
#
# THIS FLOW RUNS WITH THE RELEASED v0.3.5 PACKAGE. It uses no local IPC, so it
# is the flow to start with until a build newer than v0.3.5 is available.
#
# TCP is the right transport when the client is not on the same machine as the
# application: another host, a container, a device on the bench - and it is the
# transport to use on Windows, where local IPC is not supported.
#
# Two habits this flow demonstrates:
#   * --port 0 lets the OS pick a free port; the app announces the real one as
#     VERICUE_PORT=<n>. Nothing here collides with a hard-coded 4242.
#   * a TCP port is reachable by anything that can route to the host, so the
#     runtime is started with a token and the scenario shows an unauthenticated
#     client being refused. The token is generated per run - never commit one.
#
# Usage: flows/03-tcp-explicit/run.sh
# Environment: VERICUE_DEMO_APP=<path>  use this demo_app binary
#              PYTHON=<interpreter>     python that can import vericue

set -eu

FLOW_NAME=flow-03-tcp-explicit
unset CDPATH
flow_dir=$(cd -- "$(dirname -- "$0")" && pwd)
FLOW_REPO_ROOT=$(cd -- "$flow_dir/../.." && pwd)
export FLOW_REPO_ROOT
. "$FLOW_REPO_ROOT/flows/lib.sh"

app_pid=""
log=$(mktemp "${TMPDIR:-/tmp}/vericue-flow-03.XXXXXX")

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
flow_random_token

flow_step "Starting $demo_app on an ephemeral TCP port, token required"
"$demo_app" --port 0 --token "$FLOW_TOKEN" >"$log" 2>&1 &
app_pid=$!

flow_wait_for VERICUE_PORT "$log" "$app_pid" 20
port=$FLOW_VALUE
printf 'Port: %s (chosen by the OS, announced by the application)\n' "$port"

flow_step "CLI over TCP: python -m vericue --port <n> --token <token> ping"
"$FLOW_PYTHON" -m vericue --port "$port" --token "$FLOW_TOKEN" ping

flow_step "Python client scenario (auth refusal, lookup, interaction, assertion)"
"$FLOW_PYTHON" "$flow_dir/scenario.py" --host 127.0.0.1 --port "$port" --token "$FLOW_TOKEN"

flow_step "Flow 3 finished successfully"
