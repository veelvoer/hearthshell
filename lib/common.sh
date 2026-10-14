# hearthshell installer helpers. Sourced by install.sh and uninstall.sh (POSIX sh).
# shellcheck shell=sh

NAME=hearthshell
CONF_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
BIN_DIR="$HOME/.local/bin"
INSTALL_DIR="$CONF_HOME/quickshell/$NAME"
STATE_DIR="$STATE_HOME/$NAME"
SHARE_DIR="$DATA_HOME/$NAME"
MANIFEST="$STATE_DIR/manifest"
BACKUP_DIR="$STATE_DIR/backups"

DRY_RUN=${DRY_RUN:-0}
ASSUME_YES=${ASSUME_YES:-0}

# ---------------------------------------------------------------- output
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_B=$(printf '\033[1m'); C_G=$(printf '\033[32m'); C_Y=$(printf '\033[33m'); C_R=$(printf '\033[31m'); C_D=$(printf '\033[2m'); C_0=$(printf '\033[0m')
else
    C_B=''; C_G=''; C_Y=''; C_R=''; C_D=''; C_0=''
fi
say()  { printf '%s\n' "$*"; }
step() { printf '\n%s==>%s %s%s%s\n' "$C_G" "$C_0" "$C_B" "$*" "$C_0"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '%s  ! %s%s\n' "$C_Y" "$*" "$C_0" >&2; }
err()  { printf '%s  x %s%s\n' "$C_R" "$*" "$C_0" >&2; }
die()  { err "$*"; exit 1; }
dry()  { [ "$DRY_RUN" = 1 ]; }

have() { command -v "$1" >/dev/null 2>&1; }

# ask "question" default(y|n)  ->  0 = yes
ask() {
    q=$1; def=${2:-y}
    if [ "$ASSUME_YES" = 1 ]; then return 0; fi
    if [ ! -t 0 ]; then [ "$def" = y ]; return; fi
    if [ "$def" = y ]; then hint='[Y/n]'; else hint='[y/N]'; fi
    printf '  ? %s %s ' "$q" "$hint"
    read -r a || a=''
    case "$a" in
        y|Y|yes|YES) return 0 ;;
        n|N|no|NO) return 1 ;;
        *) [ "$def" = y ] ;;
    esac
}

# run a command, or just print it in --dry-run mode
run() {
    if dry; then info "${C_D}would run:${C_0} $*"; return 0; fi
    "$@"
}

# ---------------------------------------------------------------- manifest
# One line per thing the installer did, so uninstall.sh can undo exactly that:
#   FILE <path>             a file we created
#   OVERWRITE <path>        a file that already existed and that we replaced (restored from BACKUP)
#   DIR <path>              a directory we created (removed when empty / when it is ours)
#   BLOCK <path> <id> <1|0> a marked block we added to a file (1 = we created the file)
#   BACKUP <orig> <copy>    a copy of a file taken before we first changed it
#   SERVICE <unit>          a systemd user unit we enabled
#   PKG <manager> <name>    a package we installed
record() {
    dry && return 0
    mkdir -p "$STATE_DIR"
    touch "$MANIFEST"
    grep -qxF -- "$*" "$MANIFEST" 2>/dev/null || printf '%s\n' "$*" >> "$MANIFEST"
}

# mkdir -p that records the directories it actually creates
make_dir() {
    local d
    d=$1
    [ -d "$d" ] && return 0
    if dry; then info "${C_D}would create${C_0} $d"; return 0; fi
    make_dir "$(dirname "$d")"
    mkdir "$d" && record "DIR $d"
}

# write_file <path> : stdin -> file; records it unless it already existed
write_file() {
    f=$1
    make_dir "$(dirname "$f")"
    if dry; then info "${C_D}would write${C_0} $f"; cat >/dev/null; return 0; fi
    existed=0; [ -e "$f" ] && existed=1
    if [ "$existed" = 1 ] && ! grep -qxF "FILE $f" "$MANIFEST" 2>/dev/null; then
        backup_file "$f"
    fi
    cat > "$f"
    if [ "$existed" = 0 ]; then record "FILE $f"; else record "OVERWRITE $f"; fi
    return 0
}

# install_file <src> <dest> [mode] : copy a file through write_file (backed up + recorded)
install_file() {
    write_file "$2" < "$1"
    [ -n "${3:-}" ] && ! dry && chmod "$3" "$2"
    return 0
}

backup_file() {
    f=$1
    [ -e "$f" ] || return 0
    dry && return 0
    mkdir -p "$BACKUP_DIR"
    n=$(printf '%s' "$f" | tr '/' '_')
    [ -e "$BACKUP_DIR/$n" ] || { cp -p "$f" "$BACKUP_DIR/$n" && record "BACKUP $f $BACKUP_DIR/$n"; }
}

# ---------------------------------------------------------------- marked blocks
# Blocks look like   <open> >>> hearthshell:<id> >>> <close> ... <open> <<< hearthshell:<id> <<< <close>
# open/close are the comment delimiters of the target file ("#" or "--" or "/*" "*/").
block_start() { if [ -n "$3" ]; then printf '%s >>> %s:%s >>> %s' "$2" "$NAME" "$1" "$3"; else printf '%s >>> %s:%s >>>' "$2" "$NAME" "$1"; fi; }
block_end()   { if [ -n "$3" ]; then printf '%s <<< %s:%s <<< %s' "$2" "$NAME" "$1" "$3"; else printf '%s <<< %s:%s <<<' "$2" "$NAME" "$1"; fi; }

# strip_block <file> <start-line> <end-line> : print the file without our block (and without the
# blank separator line install put in front of it)
strip_block() {
    awk -v s="$2" -v e="$3" '
        skip { if (index($0, e)) skip = 0; next }
        index($0, s) { skip = 1; if (havep && prev == "") havep = 0; next }
        { if (havep) print prev; prev = $0; havep = 1 }
        END { if (havep) print prev }' "$1"
}

# patch_block <file> <id> <open> <close> : block body on stdin. Idempotent; never touches
# anything outside its own markers.
patch_block() {
    f=$1; id=$2; open=$3; close=$4
    body=$(cat)
    if dry; then info "${C_D}would add block '$id' to${C_0} $f"; return 0; fi
    make_dir "$(dirname "$f")"
    created=0
    if [ ! -e "$f" ]; then created=1; : > "$f"; else backup_file "$f"; fi
    start=$(block_start "$id" "$open" "$close"); end=$(block_end "$id" "$open" "$close")
    tmp="$f.hearthshell.$$"
    # drop a previous version of the block, then append the new one
    strip_block "$f" "$start" "$end" > "$tmp"
    { cat "$tmp"; [ -s "$tmp" ] && printf '\n'; printf '%s\n%s\n%s\n' "$start" "$body" "$end"; } > "$f"
    rm -f "$tmp"
    if [ "$created" = 1 ]; then record "BLOCK $f $id 1"; else record "BLOCK $f $id 0"; fi
}

# unpatch_block <file> <id> <open> <close> : remove our block, keep everything else
unpatch_block() {
    f=$1; id=$2; open=$3; close=$4
    [ -f "$f" ] || return 0
    start=$(block_start "$id" "$open" "$close"); end=$(block_end "$id" "$open" "$close")
    tmp="$f.hearthshell.$$"
    strip_block "$f" "$start" "$end" > "$tmp" && cat "$tmp" > "$f"
    rm -f "$tmp"
}


# ---------------------------------------------------------------- environment
detect_pm() {
    if [ -e /etc/NIXOS ] || have nixos-rebuild; then echo nix; return; fi
    for pm in pacman apt-get dnf zypper apk xbps-install emerge eopkg; do
        if have "$pm"; then echo "$pm"; return; fi
    done
    echo unknown
}

hypr_mode() {  # lua | conf | none
    if [ -f "$CONF_HOME/hypr/hyprland.lua" ]; then echo lua
    elif [ -f "$CONF_HOME/hypr/hyprland.conf" ]; then echo conf
    else echo none; fi
}

qs_bin() { if have qs; then echo qs; elif have quickshell; then echo quickshell; fi; }
