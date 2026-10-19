set -g fish_greeting ""

# Make the opencode CLI available if installed
if test -d "$HOME/.opencode/bin"
    fish_add_path "$HOME/.opencode/bin"
end

# Make ~/.local/bin available for local CLIs (claude, lock.sh, ...)
if test -d "$HOME/.local/bin"
    fish_add_path "$HOME/.local/bin"
end

# ---------------------------------------------------------------------------
# Claude Code Token Optimization Environment Variables
# ---------------------------------------------------------------------------
# Force subagents to execute on a lower-cost model tier
set -gx CLAUDE_CODE_SUBAGENT_MODEL claude-sonnet-5

# Extend API prompt cache TTL from 5 minutes to 1 hour
set -gx ENABLE_PROMPT_CACHING_1H 1

# Suppress background non-essential API calls (tips, telemetry checks)
set -gx DISABLE_NON_ESSENTIAL_MODEL_CALLS 1

# Suppress extra UI cost notifications to keep output context minimal
set -gx DISABLE_COST_WARNINGS 1

# ---------------------------------------------------------------------------
# Fish Abbreviations
# ---------------------------------------------------------------------------
if status is-interactive
    abbr --add shutdown "$HOME/.config/rofi/dashboard.sh '    Afsluiten (Shutdown)'"
    abbr --add reboot   "$HOME/.config/rofi/dashboard.sh '    Herstarten (Reboot)'"
    abbr --add sleep    "$HOME/.config/rofi/dashboard.sh '    Slaapstand (Suspend)'"
    abbr --add lock     "$HOME/.config/rofi/dashboard.sh '    Systeem Vergrendelen'"
    abbr --add update   "$HOME/.config/rofi/dashboard.sh '    Systeem Updaten'"
    
    # Fast Claude launch shortcuts
    abbr --add cplan    "claude --model opusplan"
    abbr --add cfast    "claude --effort low"
end

# ---------------------------------------------------------------------------
# Themed prompt (Universal Nerd Fonts v3 Fix)
# ---------------------------------------------------------------------------
function fish_prompt
    set -l last_status $status

    # Colours come from universal variables written by quickshell/scripts/apply-theme.py
    set -l bg_pill     (set -q qs_pill;  and echo $qs_pill;  or echo 343f44)
    set -l bg_git      (set -q qs_git;   and echo $qs_git;   or echo 4f5b58)
    set -l light_text  (set -q qs_fg;    and echo $qs_fg;    or echo d3c6aa)
    set -l bright_aqua (set -q qs_aqua;  and echo $qs_aqua;  or echo 83c092)
    set -l green_glow  (set -q qs_green; and echo $qs_green; or echo a7c080)
    set -l warm_amber  (set -q qs_amber; and echo $qs_amber; or echo dbbc7f)
    set -l error_red   (set -q qs_red;   and echo $qs_red;   or echo e67e80)

    echo -e "" # Spacer line

    # 1. Directory Pill [  ~/path ]
    set_color normal
    set_color $bg_pill
    echo -n ""
    set_color -b $bg_pill
    set_color --bold $bright_aqua
    echo -n "  " 
    set_color -b $bg_pill
    set_color $light_text
    echo -n (prompt_pwd)
    set_color normal
    set_color $bg_pill
    echo -n " "

    # 2. Git Pill [  main ]
    if type -q git; and command git rev-parse --is-inside-work-tree >/dev/null 2>&1
        set -l branch (command git branch --show-current 2>/dev/null)
        test -z "$branch"; and set branch (command git rev-parse --short HEAD 2>/dev/null)

        set_color normal
        set_color $bg_git
        echo -n ""
        set_color -b $bg_git
        set_color --bold $green_glow
        echo -n "  " 
        set_color -b $bg_git
        set_color $light_text
        echo -n "$branch"

        if command git status --porcelain 2>/dev/null | string length -q
            set_color -b $bg_git
            set_color --bold $error_red
            echo -n " •"
        end

        set_color normal
        set_color $bg_git
        echo -n " "
    end

    # 3. Clock Pill [  14:30 ]
    set_color normal
    set_color $bg_pill
    echo -n ""
    set_color -b $bg_pill
    set_color --bold $warm_amber
    echo -n "  " 
    set_color -b $bg_pill
    set_color $light_text
    echo -n (date "+%H:%M")
    set_color normal
    set_color $bg_pill
    echo -n ""

    # LINE 2: PROMPT SYMBOL
    echo ""
    if test $last_status -eq 0
        set_color --bold $green_glow
        echo -n " ❯ "
    else
        set_color --bold $error_red
        echo -n " ✖ "
    end

    set_color normal
end

function fish_right_prompt
end
