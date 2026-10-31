#!/bin/bash
# Install AppImages dropped into ~/Applications: extract to ~/Applications/<Name>/,
# create launcher + icon + PATH command, then delete the AppImage.
# Deleting ~/Applications/<Name>/ uninstalls the app.
APPS="$HOME/Applications"
DESK="$HOME/.local/share/applications"
BIN="$HOME/.local/bin"
mkdir -p "$APPS" "$DESK" "$BIN"
shopt -s nullglob nocaseglob
for f in "$APPS"/*.AppImage; do
  base=$(basename "$f"); base=${base%.[Aa]pp[Ii]mage}
  base=$(echo "$base" | sed -E 's/[-_.]?(x86_64|amd64|aarch64)//Ig; s/[-_]v?[0-9]+(\.[0-9]+)+.*$//; s/[-_]+$//')
  [ -n "$base" ] || base=$(basename "$f" .AppImage)
  dir="$APPS/$base"
  id="appimage-$(echo "$base" | tr -c 'A-Za-z0-9._\n-' '_')"
  cmd=$(echo "$base" | tr 'A-Z ' 'a-z-')
  chmod +x "$f"
  tmp=$(mktemp -d "$APPS/.install.XXXXXX")
  if ! (cd "$tmp" && "$f" --appimage-extract >/dev/null 2>&1) || [ ! -x "$tmp/squashfs-root/AppRun" ]; then
    echo "appimage-sync: failed to extract $f" >&2
    rm -rf "$tmp"; continue
  fi
  rm -rf "$dir"; mv "$tmp/squashfs-root" "$dir"; rm -rf "$tmp"
  find "$dir" -maxdepth 1 -type d -exec chmod u+rwx {} + 2>/dev/null
  src=$(ls "$dir"/*.desktop 2>/dev/null | head -1)
  name="$base"; comment=""; cats="Utility;"; ic=""; extra=""
  if [ -n "$src" ]; then
    g() { grep -m1 "^$1=" "$src" | cut -d= -f2-; }
    v=$(g Name); [ -n "$v" ] && name=$v
    comment=$(g Comment); v=$(g Categories); [ -n "$v" ] && cats=$v
    ic=$(g Icon); extra=$(grep -E '^(MimeType|StartupWMClass|Keywords)=' "$src")
  fi
  icon="application-x-executable"
  if [ -n "$ic" ]; then
    img=$(find -L "$dir" \( -name "$ic.png" -o -name "$ic.svg" -o -name "$ic.xpm" \) -type f -printf '%s %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
    [ -z "$img" ] && [ -f "$dir/.DirIcon" ] && img="$dir/.DirIcon"
    [ -n "$img" ] && icon="$img"
  fi
  cat > "$DESK/$id.desktop" <<D
[Desktop Entry]
Type=Application
Name=$name
Comment=$comment
Exec="$dir/AppRun" %U
Icon=$icon
Categories=$cats
Terminal=false
$extra
X-AppImage-Dir=$dir
X-AppImage-Cmd=$cmd
D
  ln -sf "$dir/AppRun" "$BIN/$cmd"
  rm -f "$f"
done
# uninstall: entries whose app folder is gone
for d in "$DESK"/appimage-*.desktop; do
  dir=$(grep -m1 '^X-AppImage-Dir=' "$d" | cut -d= -f2-)
  [ -n "$dir" ] && [ ! -d "$dir" ] || continue
  cmd=$(grep -m1 '^X-AppImage-Cmd=' "$d" | cut -d= -f2-)
  rm -f "$d" "$BIN/$cmd"
done
update-desktop-database "$DESK" >/dev/null 2>&1
exit 0
