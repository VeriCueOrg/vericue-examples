#!/bin/sh
# The examples must not go on advertising a release that is no longer current.
#
# This repository told readers that "all three flows run against v0.4.0, the
# current package" for the whole of v0.5.0's life, and the CI job pinned the
# 0.4.0 Python client while downloading whatever /latest named. Both were
# hand-maintained constants that nobody had a reason to revisit.
#
# So: any vX.Y.Z that the docs present as *the current package* must be the one
# https://dl.vericue.dev/latest names. Version numbers that say when a feature
# arrived ("arrived in 0.4.0", "0.5.0+") are history and are left alone.
#
# Usage: scripts/check_release_claims.sh   (needs network; CI has it)
set -eu

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
LATEST=$(curl -fsSL https://dl.vericue.dev/latest 2>/dev/null | tr -d ' \t\r\n' || true)

if [ -z "$LATEST" ]; then
    echo "could not resolve https://dl.vericue.dev/latest - skipping" >&2
    exit 0        # a network fault is not a documentation defect
fi
echo "current release: $LATEST"

status=0
# "current package" / "the current release" next to a version is the claim.
for file in "$ROOT/README.md" "$ROOT/flows/README.md" "$ROOT/clients/README.md"; do
    [ -f "$file" ] || continue
    claims=$(grep -nE '(current (package|release)[^.]*v?[0-9]+\.[0-9]+\.[0-9]+|v?[0-9]+\.[0-9]+\.[0-9]+[^.]*(is )?the current (package|release))' "$file" || true)
    [ -z "$claims" ] && continue
    echo "$claims" | while IFS= read -r line; do
        case "$line" in
            *"$LATEST"*) ;;
            *) echo "  ${file#"$ROOT"/}: $line" >&2
               echo "    names a current release that is not $LATEST" >&2
               status=1 ;;
        esac
    done
    # `while` runs in a subshell: recompute the verdict outside it.
    if echo "$claims" | grep -qvF "$LATEST"; then
        status=1
    fi
done

if [ "$status" -ne 0 ]; then
    echo "" >&2
    echo "The docs advertise a release that is not the current one ($LATEST)." >&2
    echo "Say 'the current package is whatever dl.vericue.dev/latest names', or" >&2
    echo "update the number." >&2
    exit 1
fi
echo "no stale 'current release' claims in the examples docs"
