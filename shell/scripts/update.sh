#!/bin/sh
# hearthshell updater: downloads the latest shell from GitHub and applies it in place.
#
#   update.sh                 update the install this script lives in
#   update.sh --dry-run       download and list what would change, touch nothing
#   update.sh --restore       put the most recent backup back
#   update.sh --target DIR    work on another folder (for testing)
#   update.sh --ref NAME      branch or tag to update to (default main)
#
# Your settings, presets, custom themes, wallpapers and PAM choice are never touched.
# A backup of the current shell is saved before every update.
set -eu

REPO=${HEARTHSHELL_REPO:-veelvoer/hearthshell}
REF=main
DRY=0
RESTORE=0
HERE=$(cd "$(dirname "$0")/.." && pwd)
TARGET=$HERE

while [ $# -gt 0 ]; do
    case $1 in
        --dry-run) DRY=1 ;;
        --restore) RESTORE=1 ;;
        --target) shift; TARGET=$1 ;;
        --ref) shift; REF=$1 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

STATE=${XDG_STATE_HOME:-$HOME/.local/state}/hearthshell
BACKUPS=$STATE/backups
mkdir -p "$BACKUPS"

if [ "$RESTORE" = 1 ]; then
    last=$(ls -1t "$BACKUPS"/shell-*.tar.gz 2>/dev/null | head -n 1 || true)
    [ -n "$last" ] || { echo "no backup found in $BACKUPS" >&2; exit 1; }
    tar -xzf "$last" -C "$TARGET"
    echo "restored $(basename "$last")"
    exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

echo "downloading $REPO ($REF)"
curl -fsSL -m 120 "https://codeload.github.com/$REPO/tar.gz/$REF" -o "$tmp/src.tar.gz"
mkdir "$tmp/src"
tar -xzf "$tmp/src.tar.gz" -C "$tmp/src" --strip-components=1
SRC=$tmp/src/shell
[ -f "$SRC/shell.qml" ] || { echo "the download has no shell/shell.qml" >&2; exit 1; }

sha=$(curl -fsS -m 20 -H 'Accept: application/vnd.github.sha' "https://api.github.com/repos/$REPO/commits/$REF" 2>/dev/null || true)

# what an update replaces: the code, never the user's own data or leftovers of a bad copy
EXCLUDES="--exclude=./settings.json --exclude=./custom-themes.json --exclude=./presets.json --exclude=./pam-service
 --exclude=./wallpapers --exclude=./.version --exclude=./shell --exclude=./docs --exclude=./dotfiles
 --exclude=./integration --exclude=./lib --exclude=./tests --exclude=./LICENSE --exclude=./README.md
 --exclude=./get.sh --exclude=./install.sh --exclude=./uninstall.sh --exclude=__pycache__"

if [ "$DRY" = 1 ]; then
    echo "would update these files in $TARGET:"
    # shellcheck disable=SC2086
    (cd "$SRC" && tar -cf - $EXCLUDES . | tar -tf - | grep -v '/$' | sed 's|^\./||' | sort) | while read -r f; do
        if [ ! -f "$TARGET/$f" ]; then echo "  new      $f"
        elif ! cmp -s "$SRC/$f" "$TARGET/$f"; then echo "  changed  $f"; fi
    done
    exit 0
fi

stamp=$(date +%Y%m%d-%H%M%S)
echo "backing up the current shell"
tar -czf "$BACKUPS/shell-$stamp.tar.gz" -C "$TARGET" --exclude=./wallpapers --exclude=__pycache__ .
# keep the ten most recent backups
ls -1t "$BACKUPS"/shell-*.tar.gz | tail -n +11 | while read -r old; do rm -f "$old"; done

echo "applying the update"
# shellcheck disable=SC2086
(cd "$SRC" && tar -cf - $EXCLUDES .) | (cd "$TARGET" && tar -xf -)
[ -n "$sha" ] && printf '%s\n' "$sha" > "$TARGET/.version"
echo "done ${sha:-}"
