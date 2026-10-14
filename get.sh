#!/bin/sh
# One-line installer:
#   curl -fsSL https://raw.githubusercontent.com/veelvoer/hearthshell/main/get.sh | sh
# It downloads the repository to a temporary directory and runs install.sh from there.
# Extra options go after `sh -s --`, e.g.  ... | sh -s -- --dry-run
# Read the script before piping anything to a shell: it is short, and so is install.sh.
set -eu

REPO=veelvoer/hearthshell
REF=${HEARTHSHELL_REF:-main}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

if command -v git >/dev/null 2>&1; then
    git clone --quiet --depth 1 --branch "$REF" "https://github.com/$REPO" "$tmp/src"
elif command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
    mkdir -p "$tmp/src"
    curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$REF" | tar -xz -C "$tmp/src" --strip-components=1
else
    echo "get.sh needs git, or curl and tar" >&2
    exit 1
fi

# `curl | sh` uses stdin for the script itself, so give the installer the terminal for its questions
if (: < /dev/tty) 2>/dev/null; then
    sh "$tmp/src/install.sh" "$@" < /dev/tty
else
    sh "$tmp/src/install.sh" "$@"
fi
