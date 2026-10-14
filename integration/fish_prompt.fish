# hearthshell prompt: pills for directory, git branch and time. Needs a Nerd Font.
# Colours come from the universal variables hearthshell sets (qs_pill, qs_git, qs_fg, ...).
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
