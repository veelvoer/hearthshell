#!/bin/sh
# hearthshell: installation wizard.
#
#   ./install.sh               the wizard: detects your system, asks a few questions, then installs
#                              and downloads everything it needs (packages, Quickshell if your distro
#                              has no package for it, icon font, wallpapers, config hooks)
#   ./install.sh --yes         no questions: the recommended setup
#   ./install.sh --dry-run     show the whole plan and every command, change nothing
#   ./install.sh --help        all options
#
# Everything it does is written to ~/.local/state/hearthshell/manifest, and
# `hearthshell uninstall` undoes exactly that. Plain POSIX sh, no bash needed.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"
# shellcheck source=lib/distro.sh
. "$HERE/lib/distro.sh"

usage() {
    cat <<'EOT'
hearthshell installation wizard

usage: ./install.sh [options]

  -y, --yes            no questions: use the recommended setup ("Everything")
  -n, --dry-run        print the plan and every command, change nothing
      --profile P      skip the menu: everything | custom | minimal
      --no-deps        do not install packages
      --no-build       do not build Quickshell from source when your distro has no package
      --qs-version T   Quickshell release to build (default v0.3.2)
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
      --dotfiles       also install the author's own configs (hyprland, kitty, rofi, fish, cava,
                       hyprlock and the shell settings). REPLACES yours; every file is backed up first
      --no-dotfiles    never offer the dotfiles
      --fish-prompt    also install the hearthshell fish prompt (replaces your fish_prompt, backed up)
      --start          start the shell when finished (default: ask)
  -h, --help           this text

Profiles
  everything   packages, Quickshell build if needed, icon font, wallpapers, themes for every app,
               autostart (the default with --yes)
  custom       the wizard asks about each part
  minimal      only the shell and what it needs to run: no changes to your other configs

Undo it all with:  hearthshell uninstall      (or ~/.local/share/hearthshell/uninstall.sh)
EOT
}

# ---------------------------------------------------------------- options
PROFILE=''
W_DEPS=''; W_BUILD=''; W_FONTS=''; W_WALLS=''; W_INTEGRATE=''; W_BINDS=''
W_KITTY=''; W_ROFI=''; W_GTK=''; W_DOTS=''; W_FISHP=''; AUTOSTART=''; START=ask

while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes) ASSUME_YES=1 ;;
        -n|--dry-run) DRY_RUN=1 ;;
        --profile) shift; PROFILE=${1:-}; case "$PROFILE" in everything|custom|minimal) ;; *) die "--profile needs everything, custom or minimal" ;; esac ;;
        --no-deps) W_DEPS=0 ;;
        --no-build) W_BUILD=0 ;;
        --qs-version) shift; QS_TAG=${1:-}; [ -n "$QS_TAG" ] || die "--qs-version needs a tag such as v0.3.2" ;;
        --no-fonts) W_FONTS=0 ;;
        --no-wallpapers) W_WALLS=0 ;;
        --no-integrate) W_INTEGRATE=0 ;;
        --no-binds) W_BINDS=0 ;;
        --no-kitty) W_KITTY=0 ;;
        --no-rofi) W_ROFI=0 ;;
        --no-gtk) W_GTK=0 ;;
        --autostart) shift; AUTOSTART=${1:-}; case "$AUTOSTART" in hyprland|systemd|none) ;; *) die "--autostart needs hyprland, systemd or none" ;; esac ;;
        --dotfiles) W_DOTS=1 ;;
        --no-dotfiles) W_DOTS=0 ;;
        --fish-prompt) W_FISHP=1 ;;
        --start) START=yes ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "unknown option: $1" ;;
    esac
    shift
done
[ "${HEARTHSHELL_ALLOW_ROOT:-0}" = 1 ] || [ "$(id -u)" != 0 ] || die "do not run this as root: it installs into your home directory (it asks for your password only to install packages)"
[ -f "$HERE/shell/shell.qml" ] || die "shell/shell.qml not found next to install.sh. Run it from a full clone of the repository."
[ -n "${HOME:-}" ] && [ -d "$HOME" ] || die "HOME is not set"

INTERACTIVE=0
if [ -t 0 ] && [ "$ASSUME_YES" != 1 ]; then INTERACTIVE=1; fi

# ---------------------------------------------------------------- banner and detection
banner() {
    printf '\n%s' "$C_B"
    cat <<'EOT'
   _                      _   _          _          _ _
  | |__   ___  __ _ _ __| |_| |__  ___ | |__   ___| | |
  | '_ \ / _ \/ _` | '__| __| '_ \/ __|| '_ \ / _ \ | |
  | | | |  __/ (_| | |  | |_| | | \__ \| | | |  __/ | |
  |_| |_|\___|\__,_|_|   \__|_| |_|___/|_| |_|\___|_|_|
EOT
    printf '%s  a warm, animated Hyprland desktop shell. This wizard sets everything up.\n\n' "$C_0"
}

PM=$(detect_pm)
DISTRO=$(os_pretty)
HMODE=$(hypr_mode)
HYPR="$CONF_HOME/hypr"
HS="$BIN_DIR/hearthshell"

SESSION="not inside a Hyprland session"
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then SESSION="Hyprland (running)"
elif [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then SESSION="${XDG_CURRENT_DESKTOP}"; fi

banner
dry && say "${C_Y}Dry run: nothing will be changed.${C_0}"
step "Your system"
info "distribution:      $DISTRO"
info "package manager:   $(pm_label "$PM")"
info "session:           $SESSION"
case "$HMODE" in
    lua)  info "Hyprland config:   Lua  ($HYPR/hyprland.lua)" ;;
    conf) info "Hyprland config:   hyprlang  ($HYPR/hyprland.conf)" ;;
    none) info "Hyprland config:   none found" ;;
esac
role_present quickshell && info "Quickshell:        found" || info "Quickshell:        ${C_Y}not installed${C_0}"
role_present hyprland   && info "Hyprland:          found" || info "Hyprland:          ${C_Y}not installed${C_0}"
if [ -f "$MANIFEST" ]; then info "hearthshell:       already installed, this run updates it (your settings are kept)"; fi

# ---------------------------------------------------------------- the questions
set_default() {  # set_default VAR value : only when the user did not already decide through a flag
    eval "v=\${$1}"
    [ -n "$v" ] || eval "$1=\$2"
}

if [ -z "$PROFILE" ]; then
    if [ "$INTERACTIVE" = 1 ]; then
        printf '\n  How do you want to install?\n'
        printf '    %s1)%s Everything %s(recommended)%s  packages, icon font, wallpapers, themes for every app, autostart\n' "$C_B" "$C_0" "$C_G" "$C_0"
        printf '    %s2)%s Let me choose each part\n' "$C_B" "$C_0"
        printf '    %s3)%s Only the shell                 no changes to your other configs\n' "$C_B" "$C_0"
        printf '  Choice [1]: '
        read -r c || c=''
        case "$c" in 2) PROFILE=custom ;; 3) PROFILE=minimal ;; *) PROFILE=everything ;; esac
    else
        PROFILE=everything
    fi
fi
info "setup: $PROFILE"

case "$PROFILE" in
    everything)
        set_default W_DEPS 1; set_default W_BUILD 1; set_default W_FONTS 1; set_default W_WALLS 1
        set_default W_INTEGRATE 1; set_default W_BINDS 1; set_default W_KITTY 1; set_default W_ROFI 1
        set_default W_GTK 1; set_default AUTOSTART hyprland ;;
    minimal)
        set_default W_DEPS 1; set_default W_BUILD 1; set_default W_FONTS 1; set_default W_WALLS 1
        set_default W_INTEGRATE 0; set_default W_BINDS 0; set_default W_KITTY 0; set_default W_ROFI 0
        set_default W_GTK 0; set_default AUTOSTART none ;;
    custom)
        printf '\n'
        set_default W_DEPS "$(ask "Install missing packages with your package manager?" y && echo 1 || echo 0)"
        role_present quickshell || set_default W_BUILD "$(ask "Build Quickshell from source if your distribution has no package for it?" y && echo 1 || echo 0)"
        fc-list ':charset=f0581' family 2>/dev/null | grep -q . || set_default W_FONTS "$(ask "Download an icon font (JetBrainsMono Nerd Font, ~25 MB)?" y && echo 1 || echo 0)"
        set_default W_WALLS "$(ask "Download and recolour the wallpapers (13 themes x 4 images)?" y && echo 1 || echo 0)"
        set_default W_INTEGRATE "$(ask "Connect to Hyprland (layer rules and theme hook)?" y && echo 1 || echo 0)"
        if [ "$W_INTEGRATE" = 1 ]; then
            set_default W_BINDS "$(ask "Add the key binds Super+, (settings) and Super+N (lock)?" y && echo 1 || echo 0)"
            if [ -z "$AUTOSTART" ]; then
                printf '  Start the shell with your session through:  1) a Hyprland autostart line  2) a systemd service  3) nothing\n  Choice [1]: '
                read -r a || a=''
                case "$a" in 2) AUTOSTART=systemd ;; 3) AUTOSTART=none ;; *) AUTOSTART=hyprland ;; esac
            fi
        fi
        { have kitty || [ -d "$CONF_HOME/kitty" ]; } && set_default W_KITTY "$(ask "Theme kitty too?" y && echo 1 || echo 0)"
        { have rofi || [ -d "$CONF_HOME/rofi" ]; } && set_default W_ROFI "$(ask "Install the rofi theme?" y && echo 1 || echo 0)"
        set_default W_GTK "$(ask "Let hearthshell colour GTK apps (accent and window colours)?" y && echo 1 || echo 0)"
        have fish && set_default W_FISHP "$(ask_strict "Replace your fish prompt with the hearthshell one (backed up)?" && echo 1 || echo 0)" ;;
esac
set_default W_DEPS 1; set_default W_BUILD 1; set_default W_FONTS 1; set_default W_WALLS 1; set_default W_INTEGRATE 1
set_default W_BINDS 1; set_default W_KITTY 1; set_default W_ROFI 1; set_default W_GTK 1
set_default W_FISHP 0; set_default AUTOSTART hyprland

# the author's dotfiles: never implied by --yes, because they replace configs
DOTS_AVAILABLE=0; [ -d "$HERE/dotfiles" ] && DOTS_AVAILABLE=1
if [ -z "$W_DOTS" ]; then
    W_DOTS=0
    if [ "$DOTS_AVAILABLE" = 1 ] && [ "$INTERACTIVE" = 1 ] && [ "$PROFILE" != minimal ]; then
        DOTS=$(cd "$HERE/dotfiles" && find . -type f ! -path './quickshell/*' ! -name README.md | sed 's|^\./||' | sort)
        printf '\n'
        if [ "$HMODE" = none ]; then
            info "You have no Hyprland config yet. The repository includes the author's complete setup"
            info "(Hyprland, hyprlock, kitty, rofi, fish, cava and the shell settings): a working desktop in one go."
            def=y
        else
            info "The repository also holds the author's own configs. They are made for one laptop (monitor, Belgian"
            info "keyboard), so most people skip them. Installing them REPLACES these files (backed up, restored on uninstall):"
            for rel in $DOTS; do
                if [ -e "$CONF_HOME/$rel" ]; then info "  replace  $CONF_HOME/$rel"; else info "  create   $CONF_HOME/$rel"; fi
            done
            def=n
        fi
        if [ "$def" = y ]; then
            printf '  ? Install the author configs? [Y/n] '; read -r a || a=''
            case "$a" in n|N|no|NO) W_DOTS=0 ;; *) W_DOTS=1 ;; esac
        else
            ask_strict "Install the author's dotfiles?" && W_DOTS=1
        fi
    fi
fi
[ "$DOTS_AVAILABLE" = 1 ] || W_DOTS=0
[ "$W_DOTS" = 1 ] && HMODE_AFTER=lua || HMODE_AFTER=$HMODE

# ---------------------------------------------------------------- what is missing
REQUIRED='quickshell python3 imagemagick grim'
OPTIONAL='brightnessctl networkmanager bluez chooser pipewire wireplumber upower fontconfig fonts'
DESKTOP='kitty rofi fish hyprlock slurp wl-clipboard playerctl cava'
MISSING=''; PKGS=''; NEED_BUILD=0; NOPKG=''
add_pkgs() { for p in $1; do case " $PKGS " in *" $p "*) ;; *) PKGS="$PKGS $p" ;; esac; done; }

if [ "$W_DEPS" = 1 ]; then
    roles="$REQUIRED $OPTIONAL"
    [ "$W_DOTS" = 1 ] && roles="$roles $DESKTOP"
    role_present hyprland || roles="$roles hyprland"
    # the icon font download needs curl or wget
    if [ "$W_FONTS" = 1 ] && ! role_present curl; then roles="$roles curl"; fi
    for r in $roles; do
        role_present "$r" && continue
        MISSING="$MISSING $r"
        p=$(pkg_for "$PM" "$r")
        if [ -n "$p" ]; then add_pkgs "$p"; else
            if [ "$r" = quickshell ]; then
                if [ "$W_BUILD" = 1 ] && qs_buildable "$PM"; then NEED_BUILD=1; else NOPKG="$NOPKG $r"; fi
            else NOPKG="$NOPKG $r"; fi
        fi
    done
else
    for r in $REQUIRED; do role_present "$r" || MISSING="$MISSING $r"; done
fi

NEED_FONT=0
# without fontconfig yet (it is installed above) we cannot look, so the icon font is fetched; it is skipped when a package already provided it
if [ "$W_FONTS" = 1 ] && ! { have fc-list && fc-list ':charset=f0581' family 2>/dev/null | grep -q .; }; then NEED_FONT=1; fi
NWALL=$(awk 'BEGIN{n=0} /"path"/{n++} END{print n}' "$HERE/shell/wallpapers.json" 2>/dev/null || echo 52)

# ---------------------------------------------------------------- the plan
step "The plan"
PLAN_N=0
plan() { PLAN_N=$((PLAN_N + 1)); info "$PLAN_N. $*"; }
ROOT_TOOL=$(root_tool)
if [ -n "$PKGS" ]; then
    case "$ROOT_TOOL" in
        root) plan "install packages:$PKGS" ;;
        none) plan "install packages (needs root; no sudo found, the wizard will show you the command):$PKGS" ;;
        *) plan "install packages with $ROOT_TOOL (asks for your password):$PKGS" ;;
    esac
fi
[ "$NEED_BUILD" = 1 ] && plan "build Quickshell ${QS_TAG:-$QS_TAG_DEFAULT} from source into ~/.local (your distribution has no package; takes about 5-15 minutes)"
[ "$NEED_FONT" = 1 ] && plan "download JetBrainsMono Nerd Font (~25 MB) for the bar icons"
plan "copy the shell to $INSTALL_DIR and the launcher to $HS"
[ "$W_WALLS" = 1 ] && plan "download and recolour the wallpapers ($NWALL images, a few minutes)"
[ "$W_DOTS" = 1 ] && plan "install the author's dotfiles (replaces matching configs, each backed up)"
if [ "$W_INTEGRATE" = 1 ]; then
    plan "connect Hyprland: layer rules, theme hook$( [ "$W_BINDS" = 1 ] && printf ', Super+, and Super+N' )$( [ "$AUTOSTART" != none ] && printf ', autostart (%s)' "$AUTOSTART" )"
    others=''
    { [ "$W_KITTY" = 1 ] && { have kitty || [ -d "$CONF_HOME/kitty" ]; }; } && others="$others kitty"
    { [ "$W_ROFI" = 1 ] && { have rofi || [ -d "$CONF_HOME/rofi" ]; }; } && others="$others rofi"
    [ "$W_GTK" = 1 ] && others="$others GTK"
    [ -n "$others" ] && info "   also themed:$others (one marked line or file each)"
else
    info "   no changes to your other configs"
fi
plan "write the first theme"
[ -n "$NOPKG" ] && warn "no package for:$NOPKG on this system; install them yourself (docs/INSTALL.md) if you want those features"
if ! role_present hyprland && [ -z "$(pkg_for "$PM" hyprland)" ]; then
    warn "Hyprland is not installed and $(pm_label "$PM") has no package for it: install it first (https://wiki.hypr.land/Getting-Started/Installation/)"
fi
if [ "$HMODE_AFTER" = none ] && [ "$W_INTEGRATE" = 1 ]; then
    warn "No Hyprland config exists yet: start Hyprland once (it writes a default config), then run ./install.sh again to hook in."
fi
printf '\n'
if [ "$INTERACTIVE" = 1 ] && ! dry; then
    ask "Start the installation?" y || { say "Nothing was changed."; exit 0; }
fi

# ================================================================= execution
STEP_I=0
run_step() { STEP_I=$((STEP_I + 1)); step "[$STEP_I/$PLAN_N] $*"; }

# ---------------------------------------------------------------- packages
if [ -n "$PKGS" ]; then
    run_step "Installing packages"
    if [ "$PM" = nix ]; then
        warn "NixOS: add these to your configuration instead, then run this wizard again:$PKGS"
    else
        pm_refresh "$PM" || true
        # shellcheck disable=SC2086
        pm_install_pkgs "$PM" $PKGS || warn "some packages were not installed"
    fi
fi

# services the shell talks to are not started by the packages on every distribution
enable_unit() {  # enable_unit <unit> <why>
    have systemctl && [ -d /run/systemd/system ] || return 0
    systemctl is-enabled "$1" >/dev/null 2>&1 && return 0
    if dry; then info "${C_D}would enable${C_0} $1 ($2)"; return 0; fi
    if as_root systemctl enable --now "$1" >/dev/null 2>&1; then info "enabled $1 ($2)"; else warn "could not enable $1; run: sudo systemctl enable --now $1"; fi
}
if [ "$W_DEPS" = 1 ] && [ -n "$PKGS" ] && [ "$PM" != nix ]; then
    case " $MISSING " in *" bluez "*) enable_unit bluetooth.service "Bluetooth menu" ;; esac
    case " $MISSING " in *" upower "*) enable_unit upower.service "battery module" ;; esac
    case " $MISSING " in *" networkmanager "*)
        # only when nothing else manages the network, so a working connection is never replaced
        other=0
        for u in systemd-networkd iwd connman dhcpcd wicd; do systemctl is-active "$u" >/dev/null 2>&1 && other=1; done
        [ "$other" = 0 ] && enable_unit NetworkManager.service "Wi-Fi menu" ;;
    esac
fi

# ---------------------------------------------------------------- Quickshell
if [ "$NEED_BUILD" = 1 ]; then
    run_step "Building Quickshell"
    if ! build_quickshell "$PM"; then
        warn "Quickshell could not be built here. Build it by hand (https://quickshell.org/docs/guide/install-setup/)"
        warn "and run this wizard again with --no-deps."
    fi
fi
if ! role_present quickshell && [ -d "$HOME/.local/bin" ]; then PATH="$HOME/.local/bin:$PATH"; export PATH; fi

# ---------------------------------------------------------------- font
if [ "$NEED_FONT" = 1 ]; then
    run_step "Icon font"
    FD="$DATA_HOME/fonts/$NAME"
    if ! dry && have fc-list && fc-list ':charset=f0581' family 2>/dev/null | grep -q .; then info "an icon font is already installed (from a package), nothing to download"
    elif dry; then info "${C_D}would download${C_0} JetBrainsMono.tar.xz -> $FD"; else
        make_dir "$FD"
        URL=https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
        TMP=$(mktemp -d)
        if { have curl && curl -fsSL "$URL" -o "$TMP/f.tar.xz"; } || { have wget && wget -q "$URL" -O "$TMP/f.tar.xz"; }; then
            tar -xJf "$TMP/f.tar.xz" -C "$FD" --wildcards '*.ttf' 2>/dev/null || tar -xJf "$TMP/f.tar.xz" -C "$FD" 2>/dev/null
            have fc-cache && fc-cache -f "$FD" >/dev/null 2>&1
            info "installed to $FD"
        else
            warn "download failed (needs curl or wget, and network). Install a Nerd Font by hand: docs/INSTALL.md"
        fi
        rm -rf "$TMP"
    fi
fi

# ---------------------------------------------------------------- the shell
run_step "Installing the shell"
if [ -f "$INSTALL_DIR/shell.qml" ]; then info "updating an existing install (settings, themes and wallpapers are kept)"; fi
make_dir "$INSTALL_DIR"
if dry; then info "${C_D}would copy${C_0} $HERE/shell/ -> $INSTALL_DIR/"; else
    cp -R "$HERE/shell/." "$INSTALL_DIR/" || die "copying the shell failed"
    chmod +x "$INSTALL_DIR"/scripts/*.py "$INSTALL_DIR"/scripts/*.sh "$INSTALL_DIR"/bin/hearthshell 2>/dev/null
    [ -f "$INSTALL_DIR/custom-themes.json" ] || printf '{}\n' > "$INSTALL_DIR/custom-themes.json"
fi
PAM=login
if [ -f /etc/pam.d/hyprlock ]; then PAM=hyprlock
elif [ -f /etc/pam.d/login ]; then PAM=login
elif [ -f /etc/pam.d/system-auth ]; then PAM=system-auth; fi
if dry; then info "${C_D}would set lock PAM service to${C_0} $PAM"; else printf '%s\n' "$PAM" > "$INSTALL_DIR/pam-service"; fi
info "lock screen password check uses PAM service: $PAM"
make_dir "$BIN_DIR"
install_file "$HERE/shell/bin/hearthshell" "$BIN_DIR/hearthshell" 755
make_dir "$SHARE_DIR/lib"
install_file "$HERE/uninstall.sh" "$SHARE_DIR/uninstall.sh" 755
install_file "$HERE/lib/common.sh" "$SHARE_DIR/lib/common.sh" 644
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) warn "$BIN_DIR is not in your PATH. Add it, or call $BIN_DIR/hearthshell directly. (Hyprland binds use the full path.)" ;; esac

# ---------------------------------------------------------------- wallpapers
if [ "$W_WALLS" = 1 ]; then
    run_step "Wallpapers"
    info "Downloaded from their original sources and recoloured to each theme on this machine."
    if have python3; then
        if dry; then info "${C_D}would run:${C_0} python3 $INSTALL_DIR/scripts/fetch-wallpapers.py"; else
            python3 "$INSTALL_DIR/scripts/fetch-wallpapers.py" || warn "some wallpapers could not be prepared; themes fall back to a plain gradient"
        fi
    else
        warn "Python 3 is missing, so wallpapers were skipped. Later: python3 $INSTALL_DIR/scripts/fetch-wallpapers.py"
    fi
fi

# ---------------------------------------------------------------- dotfiles
if [ "$W_DOTS" = 1 ]; then
    run_step "The author's dotfiles"
    DOTS=$(cd "$HERE/dotfiles" && find . -type f ! -path './quickshell/*' ! -name README.md | sed 's|^\./||' | sort)
    for rel in $DOTS; do
        install_file "$HERE/dotfiles/$rel" "$CONF_HOME/$rel" 644
        info "$rel"
    done
    if [ -f "$HERE/dotfiles/quickshell/settings.json" ]; then
        install_file "$HERE/dotfiles/quickshell/settings.json" "$INSTALL_DIR/settings.json" 644
        info "shell settings (theme, bar layout, modules)"
    fi
    HMODE=$(hypr_mode)
fi

# ---------------------------------------------------------------- integration
if [ "$W_INTEGRATE" = 1 ]; then
    run_step "Connecting to your desktop"
    case "$HMODE" in
    lua)
        info "Hyprland config: Lua ($HYPR/hyprland.lua)"
        {
            echo "-- hearthshell: layer rules, key binds and autostart. Generated by install.sh, safe to edit."
            echo '-- Remove it all with `hearthshell uninstall`.'
            echo 'hl.layer_rule({ match = { namespace = "^quickshell-settings$" }, no_anim = true })'
            echo 'hl.layer_rule({ match = { namespace = "^quickshell-popup$" }, no_anim = true })'
            echo 'hl.layer_rule({ match = { namespace = "^quickshell-wallpaper$" }, no_anim = true })'
            echo 'hl.layer_rule({ match = { namespace = "^quickshell-bar$" }, no_anim = true })'
            if [ "$W_BINDS" = 1 ]; then
                if grep -Eqi '[+,] *comma([^a-z]|$)' "$HYPR/hyprland.lua" 2>/dev/null; then
                    echo '-- Super + , was not added because your config already binds comma. Bind it yourself:'
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
            echo "layerrule = blur, quickshell-bar"
            echo "layerrule = ignorealpha 0.05, quickshell-bar"
            echo "layerrule = blur, quickshell-popup"
            echo "layerrule = ignorealpha 0.1, quickshell-popup"
            if [ "$W_BINDS" = 1 ]; then
                if grep -Eqi '[+,] *comma([^a-z]|$)' "$HYPR/hyprland.conf" 2>/dev/null; then
                    echo "# Super + , was not added because your config already binds comma. Bind it yourself:"
                    echo "# bind = SUPER, comma, exec, $HS settings"
                else
                    echo "bind = SUPER, comma, exec, $HS settings"
                fi
                echo "bind = SUPER, N, exec, $HS lock"
            fi
            [ "$AUTOSTART" = hyprland ] && echo "exec-once = $HS"
            echo "source = $HYPR/hearthshell-theme.conf"
        } | write_file "$HYPR/hearthshell.conf"
        [ -e "$HYPR/hearthshell-theme.conf" ] || { echo "# written by hearthshell" | write_file "$HYPR/hearthshell-theme.conf"; }
        printf 'source = %s/hearthshell.conf\n' "$HYPR" | patch_block "$HYPR/hyprland.conf" hearthshell '#' ''
        ;;
    none)
        warn "No Hyprland config found in $HYPR (hyprland.lua or hyprland.conf), so key binds and autostart were not added."
        warn "Start Hyprland once so it writes its default config, then run this wizard again. Until then: hearthshell"
        ;;
    esac

    if [ "$AUTOSTART" = systemd ]; then
        if have systemctl; then
            {
                echo "[Unit]"; echo "Description=hearthshell (Quickshell desktop shell)"; echo "After=graphical-session.target"
                echo "StartLimitIntervalSec=60"; echo "StartLimitBurst=10"; echo ""
                echo "[Service]"; echo "Type=simple"; echo "ExecStart=$HS run"; echo "Restart=on-failure"
                echo "RestartSec=2"; echo "KillMode=mixed"; echo "TimeoutStopSec=5"; echo ""
                echo "[Install]"; echo "WantedBy=default.target"
            } | write_file "$CONF_HOME/systemd/user/hearthshell.service"
            if ! dry; then
                systemctl --user daemon-reload 2>/dev/null
                if systemctl --user enable hearthshell.service >/dev/null 2>&1; then record "SERVICE hearthshell.service"; info "systemd user service enabled"
                else warn "could not enable the systemd user service"; fi
            fi
        else
            warn "systemctl not found; no autostart was set up. Start the shell with: hearthshell"
        fi
    fi

    if [ "$W_KITTY" = 1 ] && { have kitty || [ -d "$CONF_HOME/kitty" ]; }; then
        info "kitty: adding an include of the generated theme"
        printf 'include hearthshell-theme.conf\n' | patch_block "$CONF_HOME/kitty/kitty.conf" hearthshell '#' ''
    fi
    if [ "$W_ROFI" = 1 ] && { have rofi || [ -d "$CONF_HOME/rofi" ]; }; then
        info "rofi: installing the hearthshell theme"
        make_dir "$CONF_HOME/rofi"
        sed "s|@CONF@|$CONF_HOME|g" "$HERE/integration/rofi-hearthshell.rasi" | write_file "$CONF_HOME/rofi/themes/hearthshell.rasi"
        if [ ! -e "$CONF_HOME/rofi/config.rasi" ]; then
            printf '@theme "hearthshell"\n' | patch_block "$CONF_HOME/rofi/config.rasi" hearthshell '/*' '*/'
            info "rofi: made it the default theme"
        else
            info "rofi: your config.rasi was left alone. Use the theme with: rofi -show drun -theme hearthshell"
        fi
    fi
    if [ "$W_GTK" = 1 ]; then
        for g in gtk-3.0 gtk-4.0; do
            make_dir "$CONF_HOME/$g"
            printf "@import 'hearthshell.css';\n" | patch_block "$CONF_HOME/$g/gtk.css" hearthshell '/*' '*/'
        done
        info "GTK: apps pick up the colours when they start (switch it off in Settings -> System)"
    fi
    if [ -d "$HYPR" ]; then
        sed "s|@CONF@|$CONF_HOME|g" "$HERE/integration/hyprlock-hearthshell.conf" | write_file "$HYPR/hyprlock-hearthshell.conf"
        info "hyprlock: template installed as hyprlock-hearthshell.conf (your own hyprlock.conf is untouched)"
    fi
    if [ "$W_FISHP" = 1 ]; then
        install_file "$HERE/integration/fish_prompt.fish" "$CONF_HOME/fish/functions/fish_prompt.fish" 644
        info "fish: installed the hearthshell prompt"
    fi
fi

# ---------------------------------------------------------------- first theme
run_step "Applying the theme"
if dry; then info "${C_D}would run:${C_0} python3 $INSTALL_DIR/scripts/apply-theme.py"; else
    if have python3; then
        s="$INSTALL_DIR/settings.json"; theme=everforest; opts='{}'
        if [ -f "$s" ]; then
            theme=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('theme','everforest'))" "$s" 2>/dev/null || echo everforest)
            opts=$(cat "$s")
        fi
        python3 "$INSTALL_DIR/scripts/apply-theme.py" "$theme" "$opts" || warn "applying the theme failed (is Hyprland running?). Run: hearthshell apply"
        info "theme: $theme"
    else
        warn "Python 3 is missing, so no theme was applied."
    fi
fi

# ================================================================= done
step "Done"
if ! dry && [ -x "$HS" ]; then
    printf '\n'
    "$HS" doctor 2>&1 | sed 's/^/  /'
    printf '\n'
fi
cat <<EOT
  Installed to:   $INSTALL_DIR
  Launcher:       $HS   (hearthshell help)
  Settings:       Super + ,     (or: hearthshell settings)
  Lock screen:    Super + N     (or: hearthshell lock)
  Uninstall:      hearthshell uninstall      (undoes everything this wizard did)
  Guide:          docs/INSTALL.md in the repository (https://github.com/veelvoer/hearthshell)
EOT

if ! dry; then
    if [ "$START" = ask ]; then
        if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ "$INTERACTIVE" = 1 ]; then
            ask "Start the shell now?" y && START=yes || START=no
        else START=no; fi
    fi
    if [ "$START" = yes ] && [ -x "$HS" ]; then
        if have hyprctl; then hyprctl reload >/dev/null 2>&1; fi
        nohup "$HS" run >/dev/null 2>&1 &
        info "started"
    elif [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        say "  Reload Hyprland (hyprctl reload) to activate the key binds, then start the shell with: hearthshell"
    else
        say "  Log in to a Hyprland session; the shell starts with it."
    fi
fi
exit 0
