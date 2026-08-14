# Shared helpers for the veriCue example flows. Sourced by the run.sh scripts,
# never executed on its own. POSIX sh - no bashisms.
#
# Every helper writes its result into a global variable instead of stdout, so a
# failure can abort the calling script directly (a "$(...)" substitution would
# only abort the subshell and hand the caller an empty value).
#
# shellcheck disable=SC2034  # the FLOW_* results are read by the sourcing script

# The caller resolves and exports FLOW_REPO_ROOT (the repository root) before
# sourcing this file - POSIX sh gives a sourced script no reliable way to find
# its own path.
: "${FLOW_REPO_ROOT:?FLOW_REPO_ROOT must be set before sourcing flows/lib.sh}"

flow_die() {
    printf '%s: %s\n' "${FLOW_NAME:-flow}" "$*" >&2
    exit 1
}

flow_step() {
    printf '\n=== %s\n' "$*"
}

# flow_find_binary DESCRIPTION OVERRIDE RELATIVE_PATH
# Sets FLOW_BINARY. OVERRIDE (an environment variable value, may be empty) wins;
# otherwise the standalone and in-tree build directories are searched.
flow_find_binary() {
    _desc=$1
    _override=$2
    _rel=$3

    if [ -n "$_override" ]; then
        [ -x "$_override" ] || flow_die "$_desc is not executable: $_override"
        FLOW_BINARY=$_override
        return 0
    fi

    for _dir in build build-qt6 ../build/examples ../build-qt6/examples; do
        _cand="$FLOW_REPO_ROOT/$_dir/$_rel"
        if [ -x "$_cand" ]; then
            FLOW_BINARY=$_cand
            return 0
        fi
    done

    flow_die "$_desc not found. Build the examples first:
  cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=\"/path/to/Qt;/path/to/vericue\"
  cmake --build build --parallel
Searched for $_rel under $FLOW_REPO_ROOT/{build,build-qt6} and the in-tree build."
}

# flow_find_injector - sets FLOW_INJECTOR (bin/vericue-inject) and, when the
# probe does not sit next to it in an installed SDK, FLOW_INJECT_LIB.
flow_find_injector() {
    if [ -n "${VERICUE_INJECT:-}" ]; then
        [ -x "$VERICUE_INJECT" ] || flow_die "VERICUE_INJECT is not executable: $VERICUE_INJECT"
        FLOW_INJECTOR=$VERICUE_INJECT
    else
        FLOW_INJECTOR=$(command -v vericue-inject 2>/dev/null || true)
        [ -n "$FLOW_INJECTOR" ] || flow_die "vericue-inject not found on PATH.
It ships in the veriCue package as bin/vericue-inject. Either add that bin/
directory to PATH or point VERICUE_INJECT at the script."
    fi
    FLOW_INJECT_LIB=${VERICUE_INJECT_LIB:-}
}

# flow_python - sets FLOW_PYTHON to an interpreter that can import vericue.
flow_python() {
    FLOW_PYTHON=${PYTHON:-python3}
    command -v "$FLOW_PYTHON" >/dev/null 2>&1 || flow_die "python interpreter not found: $FLOW_PYTHON"
    "$FLOW_PYTHON" -c 'import vericue' >/dev/null 2>&1 || flow_die \
        "the veriCue Python client is not importable by $FLOW_PYTHON.
Install it with: $FLOW_PYTHON -m pip install vericue"
}

# flow_headless_default - use the offscreen Qt platform when there is no display,
# so the flows also run in CI. A desktop session still gets a real window.
flow_headless_default() {
    if [ -z "${QT_QPA_PLATFORM:-}" ] && [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
        QT_QPA_PLATFORM=offscreen
        export QT_QPA_PLATFORM
        printf 'No display detected - running Qt with QT_QPA_PLATFORM=offscreen\n'
    fi
}

# flow_wait_for KEY LOGFILE PID [TIMEOUT_SECONDS]
# Waits for a "KEY=value" announcement on the application's stdout and sets
# FLOW_VALUE. Fails with a clear message if the process dies first or the
# announcement never arrives - never sleeps blindly and never guesses a value.
flow_wait_for() {
    _key=$1
    _log=$2
    _pid=$3
    _timeout=${4:-20}
    _tries=$((_timeout * 5))

    while [ "$_tries" -gt 0 ]; do
        FLOW_VALUE=$(sed -n "s/^${_key}=//p" "$_log" | head -n 1)
        if [ -n "$FLOW_VALUE" ]; then
            return 0
        fi
        if ! kill -0 "$_pid" 2>/dev/null; then
            flow_die "the application exited before announcing $_key. Its output was:
$(cat "$_log")"
        fi
        sleep 0.2
        _tries=$((_tries - 1))
    done

    flow_die "timed out after ${_timeout}s waiting for $_key on the application's stdout.
Output so far:
$(cat "$_log")"
}

# flow_wait_for_exit PID [TIMEOUT_SECONDS] - returns 0 if the process is gone.
flow_wait_for_exit() {
    _pid=$1
    _timeout=${2:-10}
    _tries=$((_timeout * 5))
    while [ "$_tries" -gt 0 ]; do
        kill -0 "$_pid" 2>/dev/null || return 0
        sleep 0.2
        _tries=$((_tries - 1))
    done
    return 1
}

# flow_random_token - sets FLOW_TOKEN to a fresh random token. Tokens are
# generated per run: an example must never ship a real shared secret.
flow_random_token() {
    FLOW_TOKEN=$(od -An -tx1 -N16 /dev/urandom 2>/dev/null | tr -d ' \n')
    [ -n "$FLOW_TOKEN" ] || flow_die "could not generate a random token from /dev/urandom"
}
