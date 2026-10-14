#!/bin/sh
# Installs hearthshell twice into a throw-away HOME (with a few pre-existing configs), uninstalls it,
# and checks that every pre-existing file is byte-for-byte what it was before.
# Safe to run: it never touches your real home directory or your running Hyprland.
#   sh tests/sandbox-cycle.sh [install.sh options]
set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
T="$W/home"
mkdir -p "$T"
mkdir -p "$T/.config/hypr" "$T/.config/kitty" "$T/.config/gtk-4.0" "$T/.config/rofi" "$T/.local/bin"
printf 'hl.config({ general = { gaps_in = 5 } })\n' > "$T/.config/hypr/hyprland.lua"
printf 'font_size 12\n' > "$T/.config/kitty/kitty.conf"
printf "@import 'colors.css';\n" > "$T/.config/gtk-4.0/gtk.css"
printf 'configuration { modi: "drun"; }\n' > "$T/.config/rofi/config.rasi"
snap() { (cd "$T" && find . -type f ! -path './.cache/*' ! -path './.local/share/fish/*' ! -name fish_variables -exec md5sum {} + | sort); }
snap > "$W/before.md5"
run() { env -i HOME="$T" PATH="$PATH" TERM=dumb sh "$@"; }
OPTS="--yes --no-deps --no-fonts --no-wallpapers ${*:-}"
# shellcheck disable=SC2086
run "$HERE/install.sh" $OPTS > "$W/install1.log" 2>&1 || { cat "$W/install1.log"; echo "FAIL: first install"; exit 1; }
# shellcheck disable=SC2086
run "$HERE/install.sh" $OPTS > "$W/install2.log" 2>&1 || { cat "$W/install2.log"; echo "FAIL: second install"; exit 1; }
blocks=$(grep -c '>>> hearthshell' "$T/.config/kitty/kitty.conf")
[ "$blocks" = 1 ] || { echo "FAIL: kitty.conf has $blocks blocks after two installs"; exit 1; }
run "$T/.local/share/hearthshell/uninstall.sh" --yes > "$W/uninstall.log" 2>&1 || { cat "$W/uninstall.log"; echo "FAIL: uninstall"; exit 1; }
snap > "$W/after.md5"
if diff "$W/before.md5" "$W/after.md5" >/dev/null; then echo "PASS: install x2 + uninstall left every pre-existing file unchanged"
else diff "$W/before.md5" "$W/after.md5"; echo "FAIL: files differ"; exit 1; fi
