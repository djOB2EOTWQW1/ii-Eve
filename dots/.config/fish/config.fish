# Commands to run in interactive sessions can go here
if status is-interactive
    # No greeting
    set fish_greeting

    # Use starship
    function starship_transient_prompt_func
        starship module character
    end
    if test "$TERM" != "linux"
        starship init fish | source
        enable_transience
    end
    # Colors
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    if status is-interactive
        alias cat 'bat --paging=never'
    end

    if test "$TERM" != "linux"
        alias ls 'eza --icons'
    end

    zoxide init fish | source
    fastfetch

end
