#!/usr/bin/env bash
# check-upstream.sh - print the newest upstream FileZilla Client version.
#
# Upstream publishes source tarballs without a machine-readable index, so we
# use the Debian source package API (which tracks upstream closely) as the
# version source of truth.
#
# Output: a bare version string, e.g. "3.71.0".
set -euo pipefail

json="$(curl -fsSL --retry 3 --max-time 30 \
    "https://sources.debian.org/api/src/filezilla/")"

# Extract upstream part of each Debian version ("3.71.0-1" -> "3.71.0"),
# keep only dotted-numeric versions, pick the highest.
ver="$(printf '%s' "$json" \
    | grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | sed -E 's/.*"([^"]+)".*/\1/; s/-.*//' \
    | grep -E '^[0-9]+(\.[0-9]+)+$' \
    | sort -rV | head -n1)"

if [ -z "$ver" ]; then
    echo "check-upstream: could not determine latest version" >&2
    exit 1
fi

# Sanity: the source tarball must actually exist on the Debian mirror.
if ! curl -fsI --max-time 30 \
    "https://deb.debian.org/debian/pool/main/f/filezilla/filezilla_${ver}.orig.tar.xz" >/dev/null; then
    echo "check-upstream: tarball for $ver not found on Debian pool" >&2
    exit 1
fi

printf '%s\n' "$ver"
