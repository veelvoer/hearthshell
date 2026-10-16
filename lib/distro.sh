# hearthshell installer: distribution support (package managers, root access, building Quickshell).
# Sourced by install.sh after lib/common.sh (POSIX sh).
# shellcheck shell=sh

# ---------------------------------------------------------------- what are we running on
os_pretty() {
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        ( . /etc/os-release; printf '%s' "${PRETTY_NAME:-${NAME:-Linux}}" )
    else
        printf 'Linux'
    fi
}

detect_pm() {
    if [ -e /etc/NIXOS ] || have nixos-rebuild; then echo nix; return; fi
    for pm in pacman apt-get dnf zypper apk xbps-install emerge eopkg; do
        if have "$pm"; then echo "$pm"; return; fi
    done
    echo unknown
}

pm_label() {
    case "$1" in
        pacman) echo pacman ;; apt-get) echo apt ;; dnf) echo dnf ;; zypper) echo zypper ;;
        apk) echo apk ;; xbps-install) echo xbps ;; emerge) echo portage ;; eopkg) echo eopkg ;;
        nix) echo "Nix (declarative)" ;; *) echo "no known package manager" ;;
    esac
}

# ---------------------------------------------------------------- roles
# A "role" is a capability the shell needs; each maps to one command and, per package manager, to packages.
role_cmds() {
    case "$1" in
        quickshell) echo "qs quickshell" ;;   python3) echo python3 ;;
        imagemagick) echo "magick convert" ;; grim) echo grim ;;
        brightnessctl) echo brightnessctl ;;  networkmanager) echo nmcli ;;
        bluez) echo bluetoothctl ;;           chooser) echo "kdialog zenity yad" ;;
        hyprland) echo hyprctl ;;             hyprlock) echo hyprlock ;;
        kitty) echo kitty ;;                  rofi) echo rofi ;;
        fish) echo fish ;;                    slurp) echo slurp ;;
        wl-clipboard) echo wl-copy ;;         playerctl) echo playerctl ;;
        cava) echo cava ;;                    git) echo git ;;
        curl) echo "curl wget" ;;
        pipewire) echo pipewire ;;            wireplumber) echo wpctl ;;
        upower) echo upower ;;                fontconfig) echo fc-list ;;
        *) echo "$1" ;;
    esac
}

role_label() {
    case "$1" in
        quickshell) echo "Quickshell" ;;      python3) echo "Python 3" ;;
        imagemagick) echo "ImageMagick" ;;    grim) echo "grim (screenshots for the lock screen)" ;;
        brightnessctl) echo "brightnessctl" ;; networkmanager) echo "NetworkManager" ;;
        bluez) echo "BlueZ (Bluetooth)" ;;    chooser) echo "a file chooser (zenity)" ;;
        hyprland) echo "Hyprland" ;;          hyprlock) echo "hyprlock" ;;
        wl-clipboard) echo "wl-clipboard" ;;  *) echo "$1" ;;
    esac
}

role_present() {
    # the text fonts are checked by name, not by a command
    if [ "$1" = fonts ]; then
        have fc-list || return 1
        fc-list family 2>/dev/null | grep -qi '^inter' && fc-list family 2>/dev/null | grep -qi 'noto serif'
        return
    fi
    for c in $(role_cmds "$1"); do have "$c" && return 0; done
    return 1
}

# pkg_for <manager> <role>  -> package name(s), empty when the distribution has none
pkg_for() {
    pm=$1; role=$2
    case "$role" in pipewire|wireplumber|upower|fontconfig|fonts) pkg_for_system "$pm" "$role"; return ;; esac
    case "$pm" in
    pacman)
        case "$role" in
            quickshell) echo quickshell ;; hyprland) echo hyprland ;; hyprlock) echo hyprlock ;;
            python3) echo python ;; imagemagick) echo imagemagick ;; grim) echo grim ;;
            brightnessctl) echo brightnessctl ;; networkmanager) echo networkmanager ;;
            bluez) echo "bluez bluez-utils" ;; chooser) echo zenity ;; kitty) echo kitty ;;
            rofi) echo rofi ;; fish) echo fish ;; slurp) echo slurp ;; wl-clipboard) echo wl-clipboard ;;
            playerctl) echo playerctl ;; cava) echo cava ;; git) echo git ;; curl) echo curl ;;
        esac ;;
    apt-get)
        case "$role" in
            hyprland) echo hyprland ;; hyprlock) echo hyprlock ;;
            python3) echo python3 ;; imagemagick) echo imagemagick ;; grim) echo grim ;;
            brightnessctl) echo brightnessctl ;; networkmanager) echo network-manager ;;
            bluez) echo bluez ;; chooser) echo zenity ;; kitty) echo kitty ;; rofi) echo rofi ;;
            fish) echo fish ;; slurp) echo slurp ;; wl-clipboard) echo wl-clipboard ;;
            playerctl) echo playerctl ;; cava) echo cava ;; git) echo git ;; curl) echo curl ;;
        esac ;;
    dnf)
        case "$role" in
            quickshell) echo quickshell ;; python3) echo python3 ;; imagemagick) echo ImageMagick ;;
            grim) echo grim ;; brightnessctl) echo brightnessctl ;; networkmanager) echo NetworkManager ;;
            bluez) echo bluez ;; chooser) echo zenity ;; kitty) echo kitty ;; rofi) echo rofi ;;
            fish) echo fish ;; slurp) echo slurp ;; wl-clipboard) echo wl-clipboard ;;
            playerctl) echo playerctl ;; cava) echo cava ;; git) echo git ;; curl) echo curl ;;
        esac ;;
    zypper)
        case "$role" in
            hyprland) echo hyprland ;; hyprlock) echo hyprlock ;; python3) echo python3 ;;
            imagemagick) echo ImageMagick ;; grim) echo grim ;; brightnessctl) echo brightnessctl ;;
            networkmanager) echo NetworkManager ;; bluez) echo bluez ;; chooser) echo zenity ;;
            kitty) echo kitty ;; rofi) echo rofi ;; fish) echo fish ;; slurp) echo slurp ;;
            wl-clipboard) echo wl-clipboard ;; playerctl) echo playerctl ;; cava) echo cava ;; git) echo git ;; curl) echo curl ;;
        esac ;;
    apk)
        case "$role" in
            hyprland) echo hyprland ;; python3) echo python3 ;; imagemagick) echo imagemagick ;;
            grim) echo grim ;; brightnessctl) echo brightnessctl ;; networkmanager) echo networkmanager ;;
            bluez) echo bluez ;; chooser) echo zenity ;; kitty) echo kitty ;; rofi) echo rofi ;;
            fish) echo fish ;; slurp) echo slurp ;; wl-clipboard) echo wl-clipboard ;;
            playerctl) echo playerctl ;; git) echo git ;; curl) echo curl ;;
        esac ;;
    xbps-install)
        case "$role" in
            quickshell) echo quickshell ;; hyprland) echo hyprland ;; python3) echo python3 ;;
            imagemagick) echo ImageMagick ;; grim) echo grim ;; brightnessctl) echo brightnessctl ;;
            networkmanager) echo NetworkManager ;; bluez) echo bluez ;; chooser) echo zenity ;;
            kitty) echo kitty ;; rofi) echo rofi ;; fish) echo fish-shell ;; slurp) echo slurp ;;
            wl-clipboard) echo wl-clipboard ;; playerctl) echo playerctl ;; cava) echo cava ;; git) echo git ;; curl) echo curl ;;
        esac ;;
    emerge)
        case "$role" in
            quickshell) echo gui-apps/quickshell ;; hyprland) echo gui-wm/hyprland ;;
            hyprlock) echo gui-apps/hyprlock ;; python3) echo dev-lang/python ;;
            imagemagick) echo media-gfx/imagemagick ;; grim) echo gui-apps/grim ;;
            brightnessctl) echo app-misc/brightnessctl ;; networkmanager) echo net-misc/networkmanager ;;
            bluez) echo net-wireless/bluez ;; chooser) echo gnome-extra/zenity ;; kitty) echo x11-terms/kitty ;;
            rofi) echo x11-misc/rofi ;; fish) echo app-shells/fish ;; slurp) echo gui-apps/slurp ;;
            wl-clipboard) echo gui-apps/wl-clipboard ;; playerctl) echo media-sound/playerctl ;; git) echo dev-vcs/git ;; curl) echo net-misc/curl ;;
        esac ;;
    eopkg)
        case "$role" in
            python3) echo python3 ;; imagemagick) echo imagemagick ;; grim) echo grim ;;
            brightnessctl) echo brightnessctl ;; networkmanager) echo network-manager ;; bluez) echo bluez ;;
            chooser) echo zenity ;; kitty) echo kitty ;; rofi) echo rofi ;; fish) echo fish ;; git) echo git ;; curl) echo curl ;;
        esac ;;
    esac
}

# Sound, battery and font packages the shell reads from (volume pop-up, battery module, text fonts).
pkg_for_system() {
    pm=$1; role=$2
    case "$pm:$role" in
        pacman:pipewire) echo "pipewire pipewire-pulse" ;;  pacman:wireplumber) echo wireplumber ;;
        pacman:upower) echo upower ;;                        pacman:fontconfig) echo fontconfig ;;
        pacman:fonts) echo "inter-font noto-fonts ttf-jetbrains-mono-nerd" ;;
        apt-get:pipewire) echo "pipewire pipewire-pulse" ;;  apt-get:wireplumber) echo wireplumber ;;
        apt-get:upower) echo upower ;;                       apt-get:fontconfig) echo fontconfig ;;
        apt-get:fonts) echo "fonts-inter fonts-noto-core" ;;
        dnf:pipewire) echo "pipewire pipewire-pulseaudio" ;; dnf:wireplumber) echo wireplumber ;;
        dnf:upower) echo upower ;;                           dnf:fontconfig) echo fontconfig ;;
        dnf:fonts) echo "rsms-inter-fonts google-noto-serif-fonts" ;;
        zypper:pipewire) echo "pipewire pipewire-pulseaudio" ;; zypper:wireplumber) echo wireplumber ;;
        zypper:upower) echo upower ;;                        zypper:fontconfig) echo fontconfig ;;
        apk:pipewire) echo "pipewire pipewire-pulse" ;;     apk:wireplumber) echo wireplumber ;;
        apk:upower) echo upower ;;                           apk:fontconfig) echo fontconfig ;;
        apk:fonts) echo "font-inter font-noto" ;;
        xbps-install:pipewire) echo pipewire ;;              xbps-install:wireplumber) echo wireplumber ;;
        xbps-install:upower) echo upower ;;                  xbps-install:fontconfig) echo fontconfig ;;
        xbps-install:fonts) echo "font-inter-ttf noto-fonts-ttf" ;;
    esac
}

# ---------------------------------------------------------------- root access
HAVE_ROOT_TOOL=''
root_tool() {
    if [ "$(id -u)" = 0 ]; then echo root; return; fi
    for t in sudo doas pkexec; do have "$t" && { echo "$t"; return; }
    done
    echo none
}

# as_root <command...> : run with the best available way to become root. When there is none, show the
# command and wait while the user runs it in another terminal.
as_root() {
    t=$(root_tool)
    case "$t" in
        root) if [ "${QUIET:-0}" = 1 ]; then "$@" >/dev/null 2>&1; else "$@"; fi ;;
        sudo|doas|pkexec) if [ "${QUIET:-0}" = 1 ]; then "$t" "$@" >/dev/null 2>&1; else "$t" "$@"; fi ;;
        none)
            warn "No sudo, doas or pkexec found. Run this command as root in another terminal:"
            say "      su -c '$*'"
            if [ -t 0 ] && [ "$ASSUME_YES" != 1 ]; then
                printf '  Press Enter when it has finished (or Ctrl-C to stop) ... '
                read -r _ || true
                return 0
            fi
            return 1 ;;
    esac
}

# ---------------------------------------------------------------- packages
pm_refresh() {  # refresh package indexes where the manager needs it before installing
    case "$1" in
        apt-get) as_root apt-get -qq update ;;
        apk) as_root apk -q update ;;
        xbps-install) as_root xbps-install -S ;;
        *) return 0 ;;
    esac
}

pm_install_cmd() {  # print the install command for a manager (packages appended by the caller)
    case "$1" in
        pacman) echo "pacman -S --needed --noconfirm" ;;
        apt-get) echo "apt-get install -y" ;;
        dnf) echo "dnf install -y" ;;
        zypper) echo "zypper --non-interactive install" ;;
        apk) echo "apk add" ;;
        xbps-install) echo "xbps-install -y" ;;
        emerge) echo "emerge --noreplace" ;;
        eopkg) echo "eopkg install -y" ;;
    esac
}

pm_remove_cmd() {
    case "$1" in
        pacman) echo "pacman -Rns --noconfirm" ;; apt-get) echo "apt-get remove -y" ;;
        dnf) echo "dnf remove -y" ;; zypper) echo "zypper --non-interactive remove" ;;
        apk) echo "apk del" ;; xbps-install) echo "xbps-remove -y" ;;
        emerge) echo "emerge --deselect" ;; eopkg) echo "eopkg remove -y" ;;
    esac
}

# pm_install_pkgs <manager> <package...> : one transaction first, then one by one so a single unknown
# package name never blocks the rest. Records every package that ends up installed by us.
pm_install_pkgs() {
    pm=$1; shift
    [ $# -gt 0 ] || return 0
    cmd=$(pm_install_cmd "$pm")
    [ -n "$cmd" ] || return 1
    if dry; then info "${C_D}would run as root:${C_0} $cmd $*"; return 0; fi
    # shellcheck disable=SC2086
    if as_root $cmd "$@"; then
        for p in "$@"; do record "PKG $pm $p"; done
        return 0
    fi
    info "the combined install failed, trying the packages one by one"
    failed=''
    for p in "$@"; do
        # shellcheck disable=SC2086
        if QUIET=1 as_root $cmd "$p"; then record "PKG $pm $p"; else failed="$failed $p"; fi
    done
    if [ -n "$failed" ]; then warn "could not install:$failed"; return 1; fi
}

# ---------------------------------------------------------------- building Quickshell from source
QS_TAG_DEFAULT=v0.3.2

qs_build_deps() {  # dependencies for compiling Quickshell, per package manager
    case "$1" in
        apt-get) echo "git curl cmake ninja-build meson pkg-config g++ qt6-base-dev qt6-base-private-dev qt6-declarative-dev qt6-declarative-private-dev qt6-shadertools-dev qt6-svg-dev qt6-wayland-dev qt6-wayland-private-dev libwayland-dev wayland-protocols libpipewire-0.3-dev libpam0g-dev libdrm-dev libgbm-dev libegl-dev libgles-dev libpolkit-agent-1-dev libglib2.0-dev libjemalloc-dev libcli11-dev spirv-tools" ;;
        dnf) echo "git curl cmake ninja-build meson gcc-c++ pkgconf-pkg-config qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel qt6-qtshadertools-devel qt6-qtsvg-devel qt6-qtwayland-devel wayland-devel wayland-protocols-devel pipewire-devel pam-devel libdrm-devel mesa-libgbm-devel mesa-libEGL-devel polkit-devel glib2-devel jemalloc-devel cli11-devel spirv-tools" ;;
        zypper) echo "git curl cmake ninja meson gcc-c++ pkg-config qt6-base-devel qt6-base-private-devel qt6-declarative-devel qt6-declarative-private-devel qt6-shadertools-devel qt6-svg-devel qt6-wayland-devel qt6-wayland-private-devel wayland-devel wayland-protocols-devel pipewire-devel pam-devel libdrm-devel libgbm-devel Mesa-libEGL-devel polkit-devel glib2-devel jemalloc-devel cli11-devel spirv-tools" ;;
        apk) echo "git curl cmake samurai meson g++ pkgconf qt6-qtbase-dev qt6-qtdeclarative-dev qt6-qtshadertools-dev qt6-qtsvg-dev qt6-qtwayland-dev wayland-dev wayland-protocols pipewire-dev linux-pam-dev libdrm-dev mesa-dev polkit-dev glib-dev jemalloc-dev spirv-tools" ;;
        pacman) echo "git curl cmake ninja meson pkgconf gcc qt6-base qt6-declarative qt6-shadertools qt6-svg qt6-wayland wayland wayland-protocols libpipewire pam libdrm mesa polkit glib2 jemalloc cli11 spirv-tools" ;;
    esac
}

qs_buildable() { [ -n "$(qs_build_deps "$1")" ]; }


# Quickshell 0.3 needs the ext-background-effect Wayland protocol (wayland-protocols 1.45+); older distributions
# (for example Debian 13) ship less. Build a current wayland-protocols into ~/.local when it is missing.
WLP_VERSION=1.47
ensure_wayland_protocols() {
    pd=$(pkg-config --variable=pkgdatadir wayland-protocols 2>/dev/null)
    if [ -n "$pd" ] && [ -f "$pd/staging/ext-background-effect/ext-background-effect-v1.xml" ]; then return 0; fi
    info "this distribution's wayland-protocols is too old, building version $WLP_VERSION"
    have meson || { warn "meson is missing, cannot build wayland-protocols"; return 1; }
    mkdir -p "$STATE_DIR/build"; wd="$STATE_DIR/build/wayland-protocols"; rm -rf "$wd"; mkdir -p "$wd"
    url="https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/$WLP_VERSION/downloads/wayland-protocols-$WLP_VERSION.tar.xz"
    if ! { have curl && curl -fsSL "$url" -o "$wd/wp.tar.xz"; } && ! { have wget && wget -q "$url" -O "$wd/wp.tar.xz"; }; then
        warn "could not download wayland-protocols"; return 1
    fi
    ( cd "$wd" && tar -xJf wp.tar.xz && cd "wayland-protocols-$WLP_VERSION" \
        && meson setup build --prefix="$HOME/.local" -Dtests=false >/dev/null 2>&1 \
        && meson install -C build >/dev/null 2>&1 ) || { warn "building wayland-protocols failed"; return 1; }
    grep '^/' "$wd/wayland-protocols-$WLP_VERSION/build/meson-logs/install-log.txt" > "$STATE_DIR/wayland-protocols-files" 2>/dev/null
    record "BUILD $STATE_DIR/wayland-protocols-files"
    rm -rf "$wd"
    PKG_CONFIG_PATH="$HOME/.local/share/pkgconfig:$HOME/.local/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"; export PKG_CONFIG_PATH
    return 0
}


cmake_gen() { if have ninja || have samu; then echo Ninja; else echo "Unix Makefiles"; fi; }

# CLI11 (a header-only command line library) is not packaged everywhere (for example Alpine): build it into ~/.local.
CLI11_VERSION=v2.5.0
ensure_cli11() {
    for h in /usr/include/CLI/CLI.hpp /usr/local/include/CLI/CLI.hpp "$HOME/.local/include/CLI/CLI.hpp"; do
        [ -f "$h" ] && return 0
    done
    info "CLI11 is not packaged here, building version $CLI11_VERSION"
    mkdir -p "$STATE_DIR/build"; cd_="$STATE_DIR/build/cli11"; rm -rf "$cd_"
    git clone -q --depth 1 --branch "$CLI11_VERSION" https://github.com/CLIUtils/CLI11 "$cd_" 2>/dev/null || { warn "could not download CLI11"; return 1; }
    ( cd "$cd_" && cmake -G "$(cmake_gen)" -B build -DCMAKE_INSTALL_PREFIX="$HOME/.local" -DCLI11_BUILD_TESTS=OFF -DCLI11_BUILD_EXAMPLES=OFF \
        -DCLI11_BUILD_DOCS=OFF >/dev/null 2>&1 && cmake --install build >/dev/null 2>&1 ) || { warn "building CLI11 failed"; return 1; }
    cp "$cd_/build/install_manifest.txt" "$STATE_DIR/cli11-files" 2>/dev/null && record "BUILD $STATE_DIR/cli11-files"
    rm -rf "$cd_"
    return 0
}

# build_quickshell <package-manager> : compile and install Quickshell into ~/.local (no root for the build itself)
build_quickshell() {
    pm=$1
    tag=${QS_TAG:-$QS_TAG_DEFAULT}
    deps=$(qs_build_deps "$pm")
    [ -n "$deps" ] || { warn "building Quickshell is not automated for this distribution"; return 1; }
    info "installing the build tools and libraries Quickshell needs"
    # shellcheck disable=SC2086
    pm_install_pkgs "$pm" $deps || warn "some build dependencies could not be installed; the build may fail"
    if dry; then info "${C_D}would build Quickshell $tag into ~/.local${C_0}"; return 0; fi
    for c in git cmake; do have "$c" || { warn "$c is missing, cannot build Quickshell"; return 1; }; done
    if ! { have ninja || have samu; } && ! have make; then warn "no ninja or make found"; return 1; fi
    if have pkg-config; then
        qtv=$(pkg-config --modversion Qt6Core 2>/dev/null || echo 0)
        case "$qtv" in 6.[0-5].*|6.[0-5]|0|'')
            warn "Qt 6.6 or newer is required (found: ${qtv:-none}). This distribution's Qt is too old to build Quickshell."
            return 1 ;;
        esac
        info "Qt $qtv"
    fi
    ensure_wayland_protocols || return 1
    ensure_cli11 || return 1
    src="$STATE_DIR/build/quickshell"
    mkdir -p "$STATE_DIR/build"; rm -rf "$src"
    info "downloading Quickshell $tag"
    git clone -q --depth 1 --branch "$tag" https://github.com/quickshell-mirror/quickshell "$src" 2>/dev/null \
        || git clone -q --depth 1 https://github.com/quickshell-mirror/quickshell "$src" \
        || { warn "could not download the Quickshell sources"; return 1; }
    gen=$(cmake_gen)
    info "configuring"
    ( cd "$src" && cmake -G "$gen" -B build -DCMAKE_BUILD_TYPE=Release -DCRASH_HANDLER=OFF -DCRASH_REPORTER=OFF \
        -DDISTRIBUTOR="hearthshell installer" -DCMAKE_PREFIX_PATH="$HOME/.local" -DCMAKE_INSTALL_PREFIX="$HOME/.local" > "$STATE_DIR/build/configure.log" 2>&1 ) \
        || { warn "configuring failed, see $STATE_DIR/build/configure.log"; tail -15 "$STATE_DIR/build/configure.log" >&2; return 1; }
    jobs=$(nproc 2>/dev/null || echo 2)
    info "compiling with $jobs jobs (this takes a few minutes)"
    ( cd "$src" && cmake --build build -j "$jobs" > "$STATE_DIR/build/build.log" 2>&1 ) \
        || { warn "the build failed, see $STATE_DIR/build/build.log"; tail -15 "$STATE_DIR/build/build.log" >&2; return 1; }
    ( cd "$src" && cmake --install build > "$STATE_DIR/build/install.log" 2>&1 ) \
        || { warn "installing failed, see $STATE_DIR/build/install.log"; return 1; }
    [ -f "$src/build/install_manifest.txt" ] && cp "$src/build/install_manifest.txt" "$STATE_DIR/quickshell-files"
    # the `qs` shortcut is not always in cmake's manifest, but it is ours too
    [ -e "$HOME/.local/bin/qs" ] && ! grep -qxF "$HOME/.local/bin/qs" "$STATE_DIR/quickshell-files" 2>/dev/null \
        && printf '%s\n' "$HOME/.local/bin/qs" >> "$STATE_DIR/quickshell-files"
    record "BUILD $STATE_DIR/quickshell-files"
    rm -rf "$src"
    PATH="$HOME/.local/bin:$PATH"; export PATH
    have quickshell || return 1
    info "$(quickshell --version 2>/dev/null | head -n 1 | cut -d" " -f1-2) built and installed to ~/.local"
    return 0
}
