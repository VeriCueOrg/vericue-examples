#!/bin/sh
# The canonical scenario in C++ (GoogleTest), run over both transports.
#
# The scenario steps are written once and run by two fixtures - the shipped
# <vericue/gtest_fixture.h> over TCP, and a local-IPC fixture defined in the
# example. This script starts demo_app on each transport in turn and selects
# the matching suite with --gtest_filter.
#
# Usage: clients/cpp/run.sh [extra gtest arguments...]
# Environment: CMAKE_PREFIX_PATH=<qt>;<vericue>  where to find Qt and veriCue
#              VERICUE_DEMO_APP=<path>           use this demo_app binary
#              VERICUE_TRANSPORTS="local tcp"    restrict to one transport

set -eu

FLOW_NAME=clients-cpp
unset CDPATH
here=$(cd -- "$(dirname -- "$0")" && pwd)
FLOW_REPO_ROOT=$(cd -- "$here/../.." && pwd)
export FLOW_REPO_ROOT
. "$FLOW_REPO_ROOT/flows/lib.sh"

app_pid=""
log=$(mktemp "${TMPDIR:-/tmp}/vericue-clients-cpp.XXXXXX")

cleanup() {
    flow_stop_app "$app_pid"
    rm -f "$log"
}
trap cleanup EXIT INT TERM

flow_headless_default

VERICUE_ARTIFACT_DIR=${VERICUE_ARTIFACT_DIR:-$here/artifacts}
export VERICUE_ARTIFACT_DIR

binary=$here/build/vericue-demo-scenario-cpp
if [ ! -x "$binary" ]; then
    flow_step "Building the GoogleTest scenario"
    cmake -S "$here" -B "$here/build" -DCMAKE_BUILD_TYPE=Release \
        ${CMAKE_PREFIX_PATH:+-DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH"} \
        || flow_die "cmake configure failed. Point CMAKE_PREFIX_PATH at your Qt
and your veriCue install, for example:
  CMAKE_PREFIX_PATH=\"\$HOME/Qt/6.7.1/gcc_64;/opt/vericue\" clients/cpp/run.sh"
    cmake --build "$here/build" --parallel
fi

for transport in ${VERICUE_TRANSPORTS:-local tcp}; do
    case $transport in
    local) filter='LocalEndpointTest.*' ;;
    tcp)   filter='DemoScenarioTest.*' ;;
    *)     flow_die "unknown transport '$transport' - use 'local' or 'tcp'" ;;
    esac

    flow_step "C++ scenario over $transport"
    flow_start_demo_app "$transport" "$log"
    app_pid=$FLOW_APP_PID

    "$binary" --gtest_filter="$filter" "$@"

    flow_stop_app "$app_pid"
    app_pid=""
done

flow_step "C++ scenario passed on: ${VERICUE_TRANSPORTS:-local tcp}"
printf 'Artifacts: %s\n' "$VERICUE_ARTIFACT_DIR"
