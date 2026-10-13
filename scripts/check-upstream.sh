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

# Sanity: a usable source tarball must exist somewhere we build from.
# download.filezilla-project.org only hosts binaries — source requests 307 to
# the homepage, which -fsIL follows into a fake 200, so it can't be checked.
# The build script tries the Debian pool first, then Fedora's lookaside
# cache; mirror that here. Debian HEADs return a bare 200/404 (no -L needed);
# Fedora's dist-git 'sources' index lists every upstream tarball by name.
if ! curl -fsI --max-time 30 \
    "https://deb.debian.org/debian/pool/main/f/filezilla/filezilla_${ver}.orig.tar.xz" >/dev/null \
    && ! curl -fsSL --retry 3 --max-time 30 \
        "https://src.fedoraproject.org/rpms/filezilla/raw/rawhide/f/sources" \
        | grep -qF "FileZilla_${ver}_src.tar.xz"; then
    echo "check-upstream: no source tarball for $ver on Debian or Fedora" >&2
    exit 1
fi

printf '%s\n' "$ver"
