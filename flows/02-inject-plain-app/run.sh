#!/bin/sh
# Flow 2 - zero-build-change evaluation: drive plain_app through vericue-inject.
#
# REQUIRES A veriCue BUILD NEWER THAN v0.3.5. The local-IPC default of
# vericue-inject and its VERICUE_ENDPOINT announcement are not in the v0.3.5
# package on https://dl.vericue.dev. With v0.3.5 use flows/03-tcp-explicit,
# which runs today.
#
# vericue-inject is an EVALUATION tool for Linux x64 applications that link Qt
# dynamically. It preloads a probe that starts the veriCue Runtime inside the
# target process - veriCue code runs in the application, it is not an external
# observer. For a permanent test setup embed VeriCueServer (see flow 1).
#
# plain_app is the victim on purpose: it has no veriCue include, no veriCue
# link, no veriCue code path. Nothing about it changes for this flow.
#
# What it does:
#   1. launches plain_app under vericue-inject (local IPC, the default)
#   2. reads VERICUE_ENDPOINT= from the launched process's stdout
#   3. runs scenario.py: object tree -> input -> click proven by a pushed
#      signal event -> property verification -> screenshot PNG
#   4. asks the application to close itself, then checks that the process is
#      gone and the endpoint has been removed from the filesystem
#
# Usage: flows/02-inject-plain-app/run.sh
# Environment: VERICUE_INJECT=<path>      bin/vericue-inject to use
#              VERICUE_INJECT_LIB=<path>  probe .so (needed from a build tree)
#              VERICUE_PLAIN_APP=<path>   use this plain_app binary
#              PYTHON=<interpreter>       python that can import vericue

set -eu

FLOW_NAME=flow-02-inject-plain-app
unset CDPATH
flow_dir=$(cd -- "$(dirname -- "$0")" && pwd)
FLOW_REPO_ROOT=$(cd -- "$flow_dir/../.." && pwd)
export FLOW_REPO_ROOT
. "$FLOW_REPO_ROOT/flows/lib.sh"

app_pid=""
log=$(mktemp "${TMPDIR:-/tmp}/vericue-flow-02.XXXXXX")
screenshot="${TMPDIR:-/tmp}/vericue-flow-02-plain-app.png"

cleanup() {
    if [ -n "$app_pid" ] && kill -0 "$app_pid" 2>/dev/null; then
        kill "$app_pid" 2>/dev/null || true
        wait "$app_pid" 2>/dev/null || true
    fi
    rm -f "$log"
}
trap cleanup EXIT INT TERM

[ "$(uname -s)" = "Linux" ] || flow_die "vericue-inject is Linux x64 only. On macOS embed VeriCueServer (flow 1); on Windows use TCP (flow 3)."

flow_python
flow_headless_default
flow_find_binary "the plain app (vericue-plain-app)" "${VERICUE_PLAIN_APP:-}" plain_app/vericue-plain-app
plain_app=$FLOW_BINARY
flow_find_injector

flow_step "The victim links Qt, but nothing from veriCue"
ldd "$plain_app" | grep -E 'libQt[56]Core|vericue' || true

flow_step "Launching it under $FLOW_INJECTOR (local IPC is the default transport)"
if [ -n "$FLOW_INJECT_LIB" ]; then
    VERICUE_INJECT_LIB="$FLOW_INJECT_LIB" "$FLOW_INJECTOR" -- "$plain_app" >"$log" 2>&1 &
else
    "$FLOW_INJECTOR" -- "$plain_app" >"$log" 2>&1 &
fi
app_pid=$!

flow_wait_for VERICUE_ENDPOINT "$log" "$app_pid" 20
endpoint=$FLOW_VALUE
printf 'Endpoint: %s\n' "$endpoint"
ls -l "$endpoint"

flow_step "Python client scenario against the un-instrumented application"
"$FLOW_PYTHON" "$flow_dir/scenario.py" --endpoint "$endpoint" --screenshot "$screenshot"

flow_step "Clean shutdown: the process exits and the endpoint disappears"
if flow_wait_for_exit "$app_pid" 10; then
    wait "$app_pid" 2>/dev/null || true
    app_pid=""
    printf 'Application exited.\n'
    if [ -e "$endpoint" ]; then
        flow_die "the endpoint still exists after a clean shutdown: $endpoint"
    fi
    printf 'Endpoint removed: %s\n' "$endpoint"
else
    flow_die "the application did not exit after being asked to close.
Its output was:
$(cat "$log")"
fi

flow_step "Flow 2 finished successfully"
printf 'Screenshot of the un-instrumented application: %s\n' "$screenshot"
