#!/bin/sh
# hearthshell uninstaller: undoes exactly what install.sh recorded in
# ~/.local/state/hearthshell/manifest, plus the files hearthshell generated while running.
#
#   hearthshell uninstall            (or ~/.local/share/hearthshell/uninstall.sh)
#   options: -y/--yes  -n/--dry-run  --keep-data  --remove-packages  -h/--help
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

KEEP_DATA=0; REMOVE_PKGS=0
while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes) ASSUME_YES=1 ;;
        -n|--dry-run) DRY_RUN=1 ;;
        --keep-data) KEEP_DATA=1 ;;
        --remove-packages) REMOVE_PKGS=1 ;;
        -h|--help)
            cat <<'EOT'
hearthshell uninstaller

  -y, --yes           do not ask for confirmation
  -n, --dry-run       show what would be removed, change nothing
      --keep-data     keep your settings, custom themes and wallpapers
                      (moved to ~/hearthshell-kept-<date>/ instead of deleted)
      --remove-packages
                      also remove the packages install.sh installed for you
                      (off by default: other programs may use them)
EOT
            exit 0 ;;
        *) die "unknown option: $1 (try --help)" ;;
    esac
    shift
done

dry && say "${C_Y}Dry run: nothing will be changed.${C_0}"

if [ ! -f "$MANIFEST" ]; then
    warn "No install record found at $MANIFEST."
    warn "hearthshell does not look installed for this user, so there is nothing to undo."
    exit 0
fi

step "What will be undone"
info "files we created:        $(grep -c '^FILE ' "$MANIFEST")"
info "config blocks we added:  $(grep -c '^BLOCK ' "$MANIFEST")  (only our marked lines are removed)"
info "files we replaced:       $(grep -c '^OVERWRITE ' "$MANIFEST")  (restored from backup)"
grep -q '^BUILD ' "$MANIFEST" && info "Quickshell:              built by the installer, will be removed from ~/.local"
info "install directory:       $INSTALL_DIR"
[ "$KEEP_DATA" = 1 ] && info "your settings and wallpapers will be kept in ~/hearthshell-kept-*/"
ask "Continue?" y || { say "Nothing was changed."; exit 0; }

# ------------------------------------------------------------ stop the shell
step "Stopping hearthshell"
QSB=$(qs_bin)
if [ -n "$QSB" ] && ! dry; then "$QSB" kill -c "$NAME" >/dev/null 2>&1; fi
if have systemctl && grep -q '^SERVICE ' "$MANIFEST"; then
    run systemctl --user disable --now hearthshell.service >/dev/null 2>&1
fi

# ------------------------------------------------------------ fish variables back to how they were
if [ -f "$INSTALL_DIR/scripts/fishvars.py" ] && have python3 && have fish; then
    step "Restoring your fish colours"
    run python3 "$INSTALL_DIR/scripts/fishvars.py" restore
fi

# ------------------------------------------------------------ Firefox, Yazi, KDE apps, micro and cava
if [ -f "$INSTALL_DIR/scripts/appthemes.py" ] && have python3; then
    step "Removing the other app themes"
    run env XDG_CONFIG_HOME="$CONF_HOME" python3 "$INSTALL_DIR/scripts/appthemes.py" --remove
fi

# ------------------------------------------------------------ files generated while the shell ran
step "Removing generated theme files"
for f in \
    "$CONF_HOME/kitty/hearthshell-theme.conf" \
    "$CONF_HOME/rofi/hearthshell-colors.rasi" \
    "$CONF_HOME/gtk-3.0/hearthshell.css" "$CONF_HOME/gtk-4.0/hearthshell.css" \
    "$CONF_HOME/hypr/hearthshell-theme.lua" "$CONF_HOME/hypr/hearthshell-theme.conf" \
    "$CONF_HOME/hypr/hearthshell-hyprlock.conf"; do
    if [ -e "$f" ]; then run rm -f "$f"; info "removed $f"; fi
done

# ------------------------------------------------------------ walk the manifest backwards
step "Undoing the install"
REV=$(awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}' "$MANIFEST")
PKGS=''
restore_backup() {
    orig=$1
    b=$(awk -v o="$orig" '$1=="BACKUP" && $2==o {print $3}' "$MANIFEST" | head -n 1)
    if [ -n "$b" ] && [ -e "$b" ]; then run cp -p "$b" "$orig"; info "restored $orig"; else warn "no backup for $orig, left as is"; fi
}
printf '%s\n' "$REV" | while IFS= read -r line; do
    set -- $line
    kind=$1
    case "$kind" in
        BLOCK)
            f=$2; id=$3; created=$4
            case "$f" in
                *.lua) o='--'; c='' ;;
                *.css|*.rasi) o='/*'; c='*/' ;;
                *) o='#'; c='' ;;
            esac
            if dry; then info "${C_D}would remove block from${C_0} $f"; else
                unpatch_block "$f" "$id" "$o" "$c"
                if [ "$created" = 1 ] && [ -f "$f" ] && ! grep -q '[^[:space:]]' "$f"; then rm -f "$f"; info "removed $f (it only held our block)"
                else info "cleaned $f"; fi
            fi ;;
        OVERWRITE) restore_backup "$2" ;;
        FILE) [ -e "$2" ] && { run rm -f "$2"; info "removed $2"; } ;;
        BUILD)  # Quickshell compiled by the installer: remove exactly the files cmake installed
            if [ -f "$2" ]; then
                while IFS= read -r bf; do [ -n "$bf" ] && [ -e "$bf" ] && { dry || rm -f "$bf"; }; done < "$2"
                # the `qs` shortcut is a symlink cmake does not list in its manifest
                if [ -L "$HOME/.local/bin/qs" ] && [ "$(readlink "$HOME/.local/bin/qs")" = quickshell ]; then dry || rm -f "$HOME/.local/bin/qs"; fi
                info "removed the Quickshell build installed to ~/.local"
            fi ;;
        DIR) ;;     # directories are handled after the files are gone
        SERVICE) have systemctl && run systemctl --user disable "$2" >/dev/null 2>&1 ;;
    esac
done

# remove directories we created, deepest first, only when empty
awk '$1=="DIR"{print $2}' "$MANIFEST" | awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}' | while IFS= read -r d; do
    [ "$d" = "$INSTALL_DIR" ] && continue
    [ -d "$d" ] && ! dry && rmdir "$d" 2>/dev/null && info "removed empty directory $d"
done

# ------------------------------------------------------------ the install directory (code + your data)
step "Removing $INSTALL_DIR"
if [ -d "$INSTALL_DIR" ]; then
    if [ "$KEEP_DATA" = 1 ]; then
        KEEP="$HOME/hearthshell-kept-$(date +%Y%m%d-%H%M%S)"
        if dry; then info "${C_D}would keep your data in${C_0} $KEEP"; else
            mkdir -p "$KEEP"
            for f in settings.json custom-themes.json presets.json wallpapers; do [ -e "$INSTALL_DIR/$f" ] && mv "$INSTALL_DIR/$f" "$KEEP/"; done
            info "your settings, custom themes and wallpapers are in $KEEP"
        fi
    fi
    run rm -rf "$INSTALL_DIR"
    rmdir "$CONF_HOME/quickshell" 2>/dev/null
fi

# ------------------------------------------------------------ packages
PKGLINES=$(grep '^PKG ' "$MANIFEST" 2>/dev/null)
if [ -n "$PKGLINES" ]; then
    if [ "$REMOVE_PKGS" = 1 ]; then
        step "Removing packages that install.sh installed"
        SUDO=''; [ "$(id -u)" != 0 ] && { have sudo && SUDO=sudo || { have doas && SUDO=doas; }; }
        printf '%s\n' "$PKGLINES" | while read -r _ pm p; do
            case "$pm" in
                pacman) run $SUDO pacman -Rns "$p" ;;
                apt-get) run $SUDO apt-get remove -y "$p" ;;
                dnf) run $SUDO dnf remove -y "$p" ;;
                zypper) run $SUDO zypper remove -y "$p" ;;
                apk) run $SUDO apk del "$p" ;;
                xbps-install) run $SUDO xbps-remove -y "$p" ;;
                emerge) run $SUDO emerge --deselect "$p" ;;
                eopkg) run $SUDO eopkg remove -y "$p" ;;
            esac
        done
    else
        step "Packages"
        info "install.sh installed these packages. They were left in place because other programs may use them:"
        printf '%s\n' "$PKGLINES" | while read -r _ pm p; do info "  $p  ($pm)"; done
        info "Remove them with --remove-packages, or with your package manager."
    fi
fi

# ------------------------------------------------------------ let Hyprland drop the settings we pushed
if have hyprctl && ! dry; then hyprctl reload >/dev/null 2>&1 && info "Hyprland reloaded"; fi

# ------------------------------------------------------------ the uninstaller's own files
step "Cleaning up"
run rm -rf "$BACKUP_DIR" "$STATE_DIR/build" "$STATE_DIR/quickshell-files" "$STATE_DIR/wayland-protocols-files" "$STATE_DIR/cli11-files"
run rm -f "$STATE_DIR/fish-vars.json"
run rm -f "$MANIFEST"
run rmdir "$STATE_DIR" 2>/dev/null
run rm -rf "$SHARE_DIR"
say ""
say "${C_G}hearthshell is uninstalled.${C_0} Your own configs were only touched inside the lines hearthshell added."
exit 0
