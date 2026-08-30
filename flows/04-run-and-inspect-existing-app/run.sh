#!/bin/sh
# Flow 4 - the current customer path: `vericue run`, then `vericue inspect`.
#
# This is the flow most customers should start with. plain_app has no veriCue
# include, no veriCue link and no veriCue code path - nothing about it changes
# for this flow - and `vericue run` starts it with the Runtime inside:
#
#     vericue run ./vericue-plain-app
#
# Element discovery is the desktop Inspector, on the same application:
#
#     vericue inspect ./vericue-plain-app
#
# The Inspector is a separate application in its own process. Its package
# carries its own Qt so it runs on a machine with no Qt installed; that Qt never
# enters the application under test.
#
# Requires the veriCue Python client v0.5.0 or newer (`pip install -U vericue`),
# which is where `vericue run` arrived. Flow 2 drives bin/vericue-inject
# directly, which is the layer underneath this one and remains supported.
#
# What the target application must provide - the Runtime uses ITS Qt, not one of
# ours: Qt Core, Qt Gui and Qt Network always, Qt Widgets only for a Widgets
# application, Qt Quick only for a Quick/QML one. QtNetwork is required even
# when the application itself never uses it.
#
# Platforms: Linux x64 and Windows x64 on documented dynamically linked Qt
# configurations (Windows is TCP only). macOS has no injection path - embed the
# Runtime there, as in flow 1.
#
# Usage: flows/04-run-and-inspect-existing-app/run.sh
# Environment: VERICUE_PLAIN_APP=<path>  use this plain_app binary
#              PYTHON=<interpreter>      python that can import vericue

set -eu

FLOW_NAME=flow-04-run-and-inspect
unset CDPATH
flow_dir=$(cd -- "$(dirname -- "$0")" && pwd)
FLOW_REPO_ROOT=$(cd -- "$flow_dir/../.." && pwd)
export FLOW_REPO_ROOT
. "$FLOW_REPO_ROOT/flows/lib.sh"

app_pid=""
announce=$(mktemp "${TMPDIR:-/tmp}/vericue-flow-04-announce.XXXXXX")
log=$(mktemp "${TMPDIR:-/tmp}/vericue-flow-04.XXXXXX")
screenshot="${TMPDIR:-/tmp}/vericue-flow-04-plain-app.png"

cleanup() {
    if [ -n "$app_pid" ] && kill -0 "$app_pid" 2>/dev/null; then
        kill "$app_pid" 2>/dev/null || true
        wait "$app_pid" 2>/dev/null || true
    fi
    rm -f "$log" "$announce"
}
trap cleanup EXIT INT TERM

[ "$(uname -s)" = "Linux" ] \
    || flow_die "This flow runs the Linux path. Windows x64 is supported too but is
TCP only - see flows/03-tcp-explicit. On macOS embed the Runtime (flow 1)."

flow_python
flow_headless_default
flow_find_binary "the plain app (vericue-plain-app)" "${VERICUE_PLAIN_APP:-}" plain_app/vericue-plain-app
plain_app=$FLOW_BINARY

"$FLOW_PYTHON" -m vericue --help >/dev/null 2>&1 \
    || flow_die "the veriCue Python client is not importable by $FLOW_PYTHON.
Install it with: $FLOW_PYTHON -m pip install -U vericue"

if ! "$FLOW_PYTHON" -m vericue run --help >/dev/null 2>&1; then
    flow_die "this veriCue client has no 'run' subcommand - it arrived in v0.5.0.
Upgrade with: $FLOW_PYTHON -m pip install -U vericue
Or use flows/02-inject-plain-app, which drives bin/vericue-inject directly."
fi

flow_step "The application links Qt, and nothing from veriCue"
ldd "$plain_app" | grep -E 'libQt[56]Core|vericue' || true

flow_step "Starting it with: vericue run $plain_app"
# --announce writes the endpoint to a file, so this script never has to parse
# the application's own stdout - the application may print anything it likes.
"$FLOW_PYTHON" -m vericue run --announce "$announce" "$plain_app" >"$log" 2>&1 &
app_pid=$!

flow_wait_for VERICUE_ENDPOINT "$announce" "$app_pid" 30
endpoint=$FLOW_VALUE
printf 'Endpoint announced in %s: %s\n' "$announce" "$endpoint"

flow_step "Element discovery: vericue inspect $plain_app"
cat <<'INSPECT'
  The same application, opened in the desktop Inspector:

      vericue inspect ./vericue-plain-app

  Point at an element and it shows the canonical path plus the code that drives
  it, in Python, C++ and C#. That is where the paths below came from; this flow
  runs unattended, so it uses them directly instead of opening a window.
INSPECT

flow_step "Python client scenario against the un-instrumented application"
"$FLOW_PYTHON" "$flow_dir/scenario.py" --endpoint "$endpoint" --screenshot "$screenshot"

flow_step "Clean shutdown: the process exits and the endpoint disappears"
if flow_wait_for_exit "$app_pid" 10; then
    wait "$app_pid" 2>/dev/null || true
    app_pid=""
    printf 'Application exited.\n'
    [ -e "$endpoint" ] && flow_die "the endpoint still exists after shutdown: $endpoint"
    printf 'Endpoint removed: %s\n' "$endpoint"
else
    flow_die "the application did not exit after being asked to close.
Its output was:
$(cat "$log")"
fi

flow_step "Flow 4 finished successfully"
printf 'Screenshot of the un-instrumented application: %s\n' "$screenshot"
