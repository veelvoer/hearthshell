#!/bin/sh
# hearthshell installer.
#
#   ./install.sh              interactive install, asks before anything that needs a choice
#   ./install.sh --dry-run    show everything it would do, change nothing
#   ./install.sh --help       all options
#
# Everything it does is written to ~/.local/state/hearthshell/manifest, and
# ~/.local/share/hearthshell/uninstall.sh (or `hearthshell uninstall`) undoes exactly that.
# Plain POSIX sh: no bash needed.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

usage() {
    cat <<'EOT'
hearthshell installer

usage: ./install.sh [options]

  -y, --yes            answer yes to every question (for scripts)
  -n, --dry-run        print what would be done, change nothing
      --no-deps        do not install any packages
      --no-fonts       do not download the Nerd Font used for icons
      --no-wallpapers  do not download and recolour the wallpapers
      --no-integrate   only install the shell; leave hyprland, kitty, rofi and GTK configs alone
      --no-binds       do not add the Super+, (settings) and Super+N (lock) key binds
      --no-kitty       do not touch kitty        --no-rofi   do not touch rofi
      --no-gtk         do not touch GTK css
      --autostart MODE how the shell starts with your session:
                         hyprland  (default) a line in your Hyprland config
                         systemd   a systemd user service (restarts if it crashes)
                         none      start it yourself with `hearthshell`
      --fish-prompt    also install the hearthshell fish prompt (replaces your fish_prompt, backed up)
      --start          start the shell when finished (default: ask)
  -h, --help           this text

Nothing is changed outside what is listed in docs/INSTALL.md. Undo it all with:
  hearthshell uninstall      (or ~/.local/share/hearthshell/uninstall.sh)
EOT
}

DO_DEPS=1; DO_FONTS=1; DO_WALLS=1; DO_INTEGRATE=1; DO_BINDS=1
DO_KITTY=1; DO_ROFI=1; DO_GTK=1; DO_FISH_PROMPT=0; AUTOSTART=hyprland; START=ask

while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes) ASSUME_YES=1 ;;
        -n|--dry-run) DRY_RUN=1 ;;
        --no-deps) DO_DEPS=0 ;;
        --no-fonts) DO_FONTS=0 ;;
        --no-wallpapers) DO_WALLS=0 ;;
        --no-integrate) DO_INTEGRATE=0 ;;
        --no-binds) DO_BINDS=0 ;;
        --no-kitty) DO_KITTY=0 ;;
        --no-rofi) DO_ROFI=0 ;;
        --no-gtk) DO_GTK=0 ;;
        --autostart) shift; AUTOSTART=${1:-}; case "$AUTOSTART" in hyprland|systemd|none) ;; *) die "--autostart needs hyprland, systemd or none" ;; esac ;;
        --fish-prompt) DO_FISH_PROMPT=1 ;;
        --start) START=yes ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "unknown option: $1" ;;
    esac
    shift
done

[ "$(id -u)" != 0 ] || die "do not run this as root: it installs into your home directory (it asks for sudo only to install packages)"
[ -f "$HERE/shell/shell.qml" ] || die "shell/shell.qml not found next to install.sh. Run it from a full clone of the repository."
[ -n "${HOME:-}" ] && [ -d "$HOME" ] || die "HOME is not set"

dry && say "${C_Y}Dry run: nothing will be changed.${C_0}"

# ===================================================================== 1. packages
PM=$(detect_pm)
SUDO=''
if [ "$(id -u)" != 0 ]; then
    if have sudo; then SUDO=sudo; elif have doas; then SUDO=doas; fi
fi

# role -> package name for a package manager (empty = no known package)
pkg_for() {
    pm=$1; role=$2
    case "$pm:$role" in
        pacman:quickshell) echo quickshell ;;           pacman:python3) echo python ;;
        pacman:imagemagick) echo imagemagick ;;         pacman:grim) echo grim ;;
        pacman:brightnessctl) echo brightnessctl ;;     pacman:networkmanager) echo networkmanager ;;
        pacman:bluez) echo "bluez bluez-utils" ;;       pacman:chooser) echo zenity ;;
        apt-get:python3) echo python3 ;;                apt-get:imagemagick) echo imagemagick ;;
        apt-get:grim) echo grim ;;                      apt-get:brightnessctl) echo brightnessctl ;;
        apt-get:networkmanager) echo network-manager ;; apt-get:bluez) echo bluez ;;
        apt-get:chooser) echo zenity ;;
        dnf:quickshell) echo quickshell ;;              dnf:python3) echo python3 ;;
        dnf:imagemagick) echo ImageMagick ;;            dnf:grim) echo grim ;;
        dnf:brightnessctl) echo brightnessctl ;;        dnf:networkmanager) echo NetworkManager ;;
        dnf:bluez) echo bluez ;;                        dnf:chooser) echo zenity ;;
        zypper:quickshell) echo quickshell ;;           zypper:python3) echo python3 ;;
        zypper:imagemagick) echo ImageMagick ;;         zypper:grim) echo grim ;;
        zypper:brightnessctl) echo brightnessctl ;;     zypper:networkmanager) echo NetworkManager ;;
        zypper:bluez) echo bluez ;;                     zypper:chooser) echo zenity ;;
        apk:quickshell) echo quickshell ;;              apk:python3) echo python3 ;;
        apk:imagemagick) echo imagemagick ;;            apk:grim) echo grim ;;
        apk:brightnessctl) echo brightnessctl ;;        apk:networkmanager) echo networkmanager ;;
        apk:bluez) echo bluez ;;                        apk:chooser) echo zenity ;;
        xbps-install:quickshell) echo quickshell ;;     xbps-install:python3) echo python3 ;;
        xbps-install:imagemagick) echo ImageMagick ;;   xbps-install:grim) echo grim ;;
        xbps-install:brightnessctl) echo brightnessctl ;; xbps-install:networkmanager) echo NetworkManager ;;
        xbps-install:bluez) echo bluez ;;               xbps-install:chooser) echo zenity ;;
        emerge:quickshell) echo gui-apps/quickshell ;;  emerge:python3) echo dev-lang/python ;;
        emerge:imagemagick) echo media-gfx/imagemagick ;; emerge:grim) echo gui-apps/grim ;;
        emerge:brightnessctl) echo app-misc/brightnessctl ;; emerge:networkmanager) echo net-misc/networkmanager ;;
        emerge:bluez) echo net-wireless/bluez ;;        emerge:chooser) echo gnome-extra/zenity ;;
        eopkg:python3) echo python3 ;;                  eopkg:imagemagick) echo imagemagick ;;
        eopkg:grim) echo grim ;;                        eopkg:brightnessctl) echo brightnessctl ;;
        eopkg:networkmanager) echo network-manager ;;   eopkg:bluez) echo bluez ;;
        eopkg:chooser) echo zenity ;;
        *) echo '' ;;
    esac
}

role_present() {
    case "$1" in
        quickshell) have qs || have quickshell ;;
        python3) have python3 ;;
        imagemagick) have magick || have convert ;;
        grim) have grim ;;
        brightnessctl) have brightnessctl ;;
        networkmanager) have nmcli ;;
        bluez) have bluetoothctl ;;
        chooser) have kdialog || have zenity || have yad ;;
    esac
}

pm_install() {  # pm_install <manager> <package...>   (one package at a time, failures are not fatal)
    pm=$1; shift
    for p in "$@"; do
        case "$pm" in
            pacman) cmd="$SUDO pacman -S --needed $p" ;;
            apt-get) cmd="$SUDO apt-get install -y $p" ;;
            dnf) cmd="$SUDO dnf install -y $p" ;;
            zypper) cmd="$SUDO zypper install -y $p" ;;
            apk) cmd="$SUDO apk add $p" ;;
            xbps-install) cmd="$SUDO xbps-install -y $p" ;;
            emerge) cmd="$SUDO emerge --noreplace $p" ;;
            eopkg) cmd="$SUDO eopkg install -y $p" ;;
            *) return 1 ;;
        esac
        if dry; then info "${C_D}would run:${C_0} $cmd"; continue; fi
        # shellcheck disable=SC2086
        if $cmd; then record "PKG $pm $p"; else warn "could not install '$p' with $pm"; fi
    done
}

step "Checking dependencies"
info "distribution package manager: $PM"
REQUIRED='quickshell python3 imagemagick grim'
OPTIONAL='brightnessctl networkmanager bluez chooser'
MISSING_REQ=''; MISSING_OPT=''
for r in $REQUIRED; do role_present "$r" || MISSING_REQ="$MISSING_REQ $r"; done
for r in $OPTIONAL; do role_present "$r" || MISSING_OPT="$MISSING_OPT $r"; done

if have hyprctl; then info "Hyprland: found"; else
    warn "Hyprland (hyprctl) not found. This shell is built for Hyprland; install it first (https://wiki.hypr.land/Getting-Started/Installation/)."
    ask "Continue anyway?" n || die "aborted"
fi
[ -z "$MISSING_REQ" ] && info "required tools: all present"
[ -n "$MISSING_REQ" ] && info "missing (required):$MISSING_REQ"
[ -n "$MISSING_OPT" ] && info "missing (optional):$MISSING_OPT  (brightness, network menu, Bluetooth menu, file picker)"

if [ "$DO_DEPS" = 1 ] && [ -n "$MISSING_REQ$MISSING_OPT" ]; then
    if [ "$PM" = nix ]; then
        warn "NixOS: add the missing packages to your configuration (see docs/INSTALL.md, section NixOS) and run this again with --no-deps."
    elif [ "$PM" = unknown ]; then
        warn "No supported package manager found. Install the missing tools yourself (docs/INSTALL.md lists them), then run with --no-deps."
    else
        want=''
        for r in $MISSING_REQ $MISSING_OPT; do
            p=$(pkg_for "$PM" "$r")
            if [ -n "$p" ]; then want="$want $p"; else
                if [ "$r" = quickshell ]; then
                    warn "$PM has no known Quickshell package. Build it from source: https://quickshell.org/docs/guide/install-setup/"
                else info "no known $PM package for '$r', skipping"; fi
            fi
        done
        if [ -n "$want" ]; then
            info "packages to install with $PM:$want"
            [ -n "$SUDO" ] || warn "no sudo or doas found; package installation will likely fail"
            if ask "Install these packages now?" y; then
                # shellcheck disable=SC2086
                pm_install "$PM" $want
            else
                info "skipped. Install them yourself if something is missing later."
            fi
        fi
    fi
fi

# re-check what is still missing
STILL=''
for r in $REQUIRED; do role_present "$r" || STILL="$STILL $r"; done
if [ -n "$STILL" ] && ! dry; then
    warn "still missing:$STILL"
    if [ "$DO_DEPS" = 1 ]; then ask "Continue installing the files anyway?" n || die "install the missing tools and run ./install.sh again"; fi
fi

# ===================================================================== 2. the shell itself
step "Installing the shell to $INSTALL_DIR"
if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/shell.qml" ]; then info "updating an existing install (your settings, themes and wallpapers are kept)"; fi
make_dir "$INSTALL_DIR"
if dry; then info "${C_D}would copy${C_0} $HERE/shell/ -> $INSTALL_DIR/"; else
    cp -R "$HERE/shell/." "$INSTALL_DIR/" || die "copying the shell failed"
    chmod +x "$INSTALL_DIR"/scripts/*.py "$INSTALL_DIR"/scripts/*.sh "$INSTALL_DIR"/bin/hearthshell 2>/dev/null
    [ -f "$INSTALL_DIR/custom-themes.json" ] || printf '{}\n' > "$INSTALL_DIR/custom-themes.json"
fi

# PAM service the lock screen checks the password against
PAM=login
if [ -f /etc/pam.d/hyprlock ]; then PAM=hyprlock
elif [ -f /etc/pam.d/login ]; then PAM=login
elif [ -f /etc/pam.d/system-auth ]; then PAM=system-auth; fi
if dry; then info "${C_D}would set lock PAM service to${C_0} $PAM"; else printf '%s\n' "$PAM" > "$INSTALL_DIR/pam-service"; fi
info "lock screen password check uses PAM service: $PAM"

step "Installing the launcher and uninstaller"
make_dir "$BIN_DIR"
install_file "$HERE/shell/bin/hearthshell" "$BIN_DIR/hearthshell" 755
make_dir "$SHARE_DIR/lib"
install_file "$HERE/uninstall.sh" "$SHARE_DIR/uninstall.sh" 755
install_file "$HERE/lib/common.sh" "$SHARE_DIR/lib/common.sh" 644
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) warn "$BIN_DIR is not in your PATH. Add it, or call $BIN_DIR/hearthshell directly." ;; esac
HS="$BIN_DIR/hearthshell"

# ===================================================================== 3. font
if [ "$DO_FONTS" = 1 ] && have fc-list; then
    if fc-list ':charset=f0581' family 2>/dev/null | grep -q .; then
        info "a font with the bar icons is installed"
    else
        step "Icon font"
        info "The bar icons come from a Nerd Font and none is installed."
        if ask "Download JetBrainsMono Nerd Font (about 25 MB) into your user fonts?" y; then
            FD="$DATA_HOME/fonts/$NAME"
            if dry; then info "${C_D}would download${C_0} JetBrainsMono.tar.xz -> $FD"; else
                make_dir "$FD"
                URL=https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
                TMP=$(mktemp -d)
                if { have curl && curl -fsSL "$URL" -o "$TMP/f.tar.xz"; } || { have wget && wget -q "$URL" -O "$TMP/f.tar.xz"; }; then
                    tar -xJf "$TMP/f.tar.xz" -C "$FD" --wildcards '*.ttf' 2>/dev/null || tar -xJf "$TMP/f.tar.xz" -C "$FD" 2>/dev/null
                    fc-cache -f "$FD" >/dev/null 2>&1
                    info "installed to $FD"
                else
                    warn "download failed (needs curl or wget and network). Install a Nerd Font by hand, see docs/INSTALL.md."
                fi
                rm -rf "$TMP"
            fi
        fi
    fi
fi

# ===================================================================== 4. wallpapers
if [ "$DO_WALLS" = 1 ]; then
    step "Wallpapers"
    info "No images ship with the repository. They are downloaded from their original"
    info "sources and recoloured to each theme on your machine (13 themes x 4 images, a few minutes)."
    if have python3 && ask "Download and prepare the wallpapers now?" y; then
        if dry; then info "${C_D}would run:${C_0} python3 $INSTALL_DIR/scripts/fetch-wallpapers.py"; else
            python3 "$INSTALL_DIR/scripts/fetch-wallpapers.py" || warn "some wallpapers could not be prepared; themes fall back to a plain gradient"
        fi
    else
        info "skipped. Later:  python3 $INSTALL_DIR/scripts/fetch-wallpapers.py [theme]"
    fi
fi

# ===================================================================== 5. integration
HMODE=$(hypr_mode)
HYPR="$CONF_HOME/hypr"
if [ "$DO_INTEGRATE" = 1 ]; then
    step "Connecting to your desktop"

    # ---------------- Hyprland
    case "$HMODE" in
    lua)
        info "Hyprland config: Lua ($HYPR/hyprland.lua)"
        {
            echo "-- hearthshell: layer rules, key binds and autostart. Generated by install.sh, safe to edit."
            echo '-- Remove it all with `hearthshell uninstall`.'
            echo 'hl.layer_rule({ match = { namespace = "^quickshell-settings$" }, blur = true, ignore_alpha = 0.1, no_anim = true })'
            echo 'hl.layer_rule({ match = { namespace = "^quickshell-popup$" }, no_anim = true })'
            echo 'hl.layer_rule({ match = { namespace = "^quickshell-wallpaper$" }, no_anim = true })'
            echo 'hl.layer_rule({ match = { namespace = "^quickshell-bar$" }, no_anim = true })'
            if [ "$DO_BINDS" = 1 ]; then
                if grep -Eqi 'comma' "$HYPR/hyprland.lua" 2>/dev/null; then
                    echo '-- Super + , was not added because your config already mentions "comma". Bind it yourself:'
                    echo "-- hl.bind(\"SUPER + comma\", hl.dsp.exec_cmd(\"$HS settings\"))"
                else
                    echo "hl.bind(\"SUPER + comma\", hl.dsp.exec_cmd(\"$HS settings\"))"
                fi
                echo "hl.bind(\"SUPER + N\", hl.dsp.exec_cmd(\"$HS lock\"))"
            fi
            if [ "$AUTOSTART" = hyprland ]; then
                echo "hl.on(\"hyprland.start\", function() hl.exec_cmd(\"$HS\") end)"
            fi
            echo "pcall(dofile, \"$HYPR/hearthshell-theme.lua\")"
        } | write_file "$HYPR/hearthshell.lua"
        printf 'pcall(dofile, "%s/hearthshell.lua")\n' "$HYPR" | patch_block "$HYPR/hyprland.lua" hearthshell '--' ''
        ;;
    conf)
        info "Hyprland config: hyprlang ($HYPR/hyprland.conf)"
        warn "hyprlang support is best effort: the layer-rule syntax differs between Hyprland versions. See docs/INSTALL.md if a rule is rejected."
        {
            echo "# hearthshell: layer rules, key binds and autostart. Generated by install.sh, safe to edit."
            for ns in quickshell-settings quickshell-popup quickshell-wallpaper quickshell-bar; do echo "layerrule = noanim, $ns"; done
            echo "layerrule = blur, quickshell-settings"
            echo "layerrule = ignorealpha 0.1, quickshell-settings"
            echo "layerrule = blur, quickshell-bar"
            echo "layerrule = ignorealpha 0.05, quickshell-bar"
            echo "layerrule = blur, quickshell-popup"
            echo "layerrule = ignorealpha 0.1, quickshell-popup"
            if [ "$DO_BINDS" = 1 ]; then
                if grep -Eqi 'comma' "$HYPR/hyprland.conf" 2>/dev/null; then
                    echo "# Super + , was not added because your config already mentions comma. Bind it yourself:"
                    echo "# bind = SUPER, comma, exec, $HS settings"
                else
                    echo "bind = SUPER, comma, exec, $HS settings"
                fi
                echo "bind = SUPER, N, exec, $HS lock"
            fi
            [ "$AUTOSTART" = hyprland ] && echo "exec-once = $HS"
            echo "source = $HYPR/hearthshell-theme.conf"
        } | write_file "$HYPR/hearthshell.conf"
        # the sourced theme file must exist even before the first apply
        [ -e "$HYPR/hearthshell-theme.conf" ] || { echo "# written by hearthshell" | write_file "$HYPR/hearthshell-theme.conf"; }
        printf 'source = %s/hearthshell.conf\n' "$HYPR" | patch_block "$HYPR/hyprland.conf" hearthshell '#' ''
        ;;
    none)
        warn "No Hyprland config found in $HYPR (hyprland.lua or hyprland.conf). Nothing was added."
        warn "Add the key binds and autostart yourself, see docs/INSTALL.md (Manual install)."
        ;;
    esac

    # ---------------- systemd user service (optional autostart)
    if [ "$AUTOSTART" = systemd ]; then
        if have systemctl; then
            {
                echo "[Unit]"
                echo "Description=hearthshell (Quickshell desktop shell)"
                echo "After=graphical-session.target"
                echo "StartLimitIntervalSec=60"
                echo "StartLimitBurst=10"
                echo ""
                echo "[Service]"
                echo "Type=simple"
                echo "ExecStart=$HS run"
                echo "Restart=on-failure"
                echo "RestartSec=2"
                echo "KillMode=mixed"
                echo "TimeoutStopSec=5"
                echo ""
                echo "[Install]"
                echo "WantedBy=default.target"
            } | write_file "$CONF_HOME/systemd/user/hearthshell.service"
            if ! dry; then
                systemctl --user daemon-reload 2>/dev/null
                if systemctl --user enable hearthshell.service >/dev/null 2>&1; then record "SERVICE hearthshell.service"; info "systemd user service enabled"
                else warn "could not enable the systemd user service"; fi
            fi
        else
            warn "systemctl not found; falling back to no autostart. Start the shell with: hearthshell"
        fi
    fi

    # ---------------- kitty
    if [ "$DO_KITTY" = 1 ] && { have kitty || [ -d "$CONF_HOME/kitty" ]; }; then
        info "kitty: adding an include of the generated theme"
        printf 'include hearthshell-theme.conf\n' | patch_block "$CONF_HOME/kitty/kitty.conf" hearthshell '#' ''
    fi

    # ---------------- rofi
    if [ "$DO_ROFI" = 1 ] && { have rofi || [ -d "$CONF_HOME/rofi" ]; }; then
        info "rofi: installing the hearthshell theme"
        make_dir "$CONF_HOME/rofi"
        sed "s|@CONF@|$CONF_HOME|g" "$HERE/integration/rofi-hearthshell.rasi" | write_file "$CONF_HOME/rofi/themes/hearthshell.rasi"
        if [ ! -e "$CONF_HOME/rofi/config.rasi" ]; then
            printf '@theme "hearthshell"\n' | patch_block "$CONF_HOME/rofi/config.rasi" hearthshell '/*' '*/'
            info "rofi: made it the default theme"
        else
            info "rofi: you already have a config.rasi, so it was left alone. Use the theme with: rofi -show drun -theme hearthshell"
        fi
    fi

    # ---------------- GTK
    if [ "$DO_GTK" = 1 ] && ask "Let hearthshell colour GTK apps (accent and window colours)? You can turn it off later in Settings." y; then
        for g in gtk-3.0 gtk-4.0; do
            make_dir "$CONF_HOME/$g"
            printf "@import 'hearthshell.css';\n" | patch_block "$CONF_HOME/$g/gtk.css" hearthshell '/*' '*/'
        done
    fi

    # ---------------- hyprlock template (never replaces your own hyprlock.conf)
    install_tmpl() { sed "s|@CONF@|$CONF_HOME|g" "$HERE/integration/hyprlock-hearthshell.conf" | write_file "$HYPR/hyprlock-hearthshell.conf"; }
    if [ -d "$HYPR" ]; then install_tmpl; info "hyprlock: template installed as hyprlock-hearthshell.conf (your own hyprlock.conf is untouched)"; fi

    # ---------------- fish prompt (opt-in)
    if [ "$DO_FISH_PROMPT" = 1 ]; then
        install_file "$HERE/integration/fish_prompt.fish" "$CONF_HOME/fish/functions/fish_prompt.fish" 644
        info "fish: installed the hearthshell prompt"
    fi
fi

# ===================================================================== 6. first theme apply
step "Applying the theme"
if dry; then info "${C_D}would run:${C_0} python3 $INSTALL_DIR/scripts/apply-theme.py (current settings or Everforest)"; else
    if have python3; then
        s="$INSTALL_DIR/settings.json"; theme=everforest; opts='{}'
        if [ -f "$s" ]; then
            theme=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('theme','everforest'))" "$s" 2>/dev/null || echo everforest)
            opts=$(cat "$s")
        fi
        python3 "$INSTALL_DIR/scripts/apply-theme.py" "$theme" "$opts" || warn "applying the theme failed (is Hyprland running?). Run: hearthshell apply"
    fi
fi

# ===================================================================== done
step "Done"
cat <<EOT
  Installed to:   $INSTALL_DIR
  Launcher:       $HS   (try: hearthshell help)
  Settings:       press Super + ,   (or: hearthshell settings)
  Lock screen:    Super + N         (or: hearthshell lock)
  Check it:       hearthshell doctor
  Uninstall:      hearthshell uninstall      (undoes everything this installer did)
  Guide:          docs/INSTALL.md in the repository (https://github.com/veelvoer/hearthshell)
EOT
if [ "$HMODE" = lua ] || [ "$HMODE" = conf ]; then
    say "  Hyprland reads the new binds on its next reload (hyprctl reload) or restart."
fi

if ! dry; then
    if [ "$START" = ask ]; then
        if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
            ask "Start the shell now?" y && START=yes || START=no
        else START=no; fi
    fi
    if [ "$START" = yes ]; then
        if have hyprctl; then hyprctl reload >/dev/null 2>&1; fi
        nohup "$HS" run >/dev/null 2>&1 &
        info "started"
    fi
fi
exit 0
