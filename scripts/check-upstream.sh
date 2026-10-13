#!/usr/bin/env bash
# check-upstream.sh - print the newest upstream FileZilla Client version.
#
# Version source of truth: the official FileZilla newsfeed (Atom), which
# announces every release on the day it ships. We previously used the Debian
# source package index, which lags upstream by weeks — it reported 3.71.0
# while 3.71.1 had been out for seven weeks.
#
# Output: a bare version string, e.g. "3.71.1".
set -euo pipefail

feed="$(curl -fsSL --retry 3 --max-time 30 \
    "https://filezilla-project.org/newsfeed.php")"

# Feed titles look like "FileZilla Client 3.71.1 released". Match "Client"
# specifically — the same feed announces FileZilla Server releases too.
ver="$(printf '%s' "$feed" \
    | grep -oE 'FileZilla Client [0-9]+(\.[0-9]+)+' \
    | grep -oE '[0-9]+(\.[0-9]+)+' \
    | sort -rV | head -n1)"

if [ -z "$ver" ]; then
    echo "check-upstream: could not determine latest version" >&2
    exit 1
fi

# Sanity: the source tarball must actually exist on the upstream mirror.
if ! curl -fsIL --max-time 30 \
    "https://download.filezilla-project.org/client/FileZilla_${ver}_src.tar.xz" >/dev/null; then
    echo "check-upstream: tarball for $ver not found on upstream mirror" >&2
    exit 1
fi

printf '%s\n' "$ver"
