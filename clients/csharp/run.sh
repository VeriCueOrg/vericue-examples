#!/bin/sh
# The canonical scenario in C# (xUnit), run over both transports.
#
# The scenario itself never mentions a transport: it reads VERICUE_ENDPOINT or
# VERICUE_HOST/VERICUE_PORT/VERICUE_TOKEN from the environment (see
# DemoScenarioTests.cs). This script starts demo_app twice - once on local
# IPC, once on TCP with a per-run token - and runs `dotnet test` against each.
#
# Usage: clients/csharp/run.sh [extra dotnet test arguments...]
# Environment: DOTNET=<path>                     dotnet 8 executable
#              VERICUE_DEMO_APP=<path>           use this demo_app binary
#              VERICUE_TRANSPORTS="local tcp"    restrict to one transport

set -eu

FLOW_NAME=clients-csharp
unset CDPATH
here=$(cd -- "$(dirname -- "$0")" && pwd)
FLOW_REPO_ROOT=$(cd -- "$here/../.." && pwd)
export FLOW_REPO_ROOT
. "$FLOW_REPO_ROOT/flows/lib.sh"

app_pid=""
log=$(mktemp "${TMPDIR:-/tmp}/vericue-clients-csharp.XXXXXX")

cleanup() {
    flow_stop_app "$app_pid"
    rm -f "$log"
}
trap cleanup EXIT INT TERM

dotnet_bin=${DOTNET:-$(command -v dotnet 2>/dev/null || true)}
[ -n "$dotnet_bin" ] || flow_die "dotnet not found. Install the .NET 8 SDK, or set
DOTNET=/path/to/dotnet (a user install usually lives in \$HOME/.dotnet)."

flow_headless_default

VERICUE_ARTIFACT_DIR=${VERICUE_ARTIFACT_DIR:-$here/artifacts}
export VERICUE_ARTIFACT_DIR

flow_step "Restoring and building the xUnit project"
"$dotnet_bin" build "$here" --nologo

for transport in ${VERICUE_TRANSPORTS:-local tcp}; do
    flow_step "C# scenario over $transport"
    flow_start_demo_app "$transport" "$log"
    app_pid=$FLOW_APP_PID

    "$dotnet_bin" test "$here" --no-build --nologo "$@"

    flow_stop_app "$app_pid"
    app_pid=""
done

flow_step "C# scenario passed on: ${VERICUE_TRANSPORTS:-local tcp}"
printf 'Artifacts: %s\n' "$VERICUE_ARTIFACT_DIR"
