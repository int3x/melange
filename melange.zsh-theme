setopt PROMPT_SUBST

# ------------------------------------------------------------
# GIT PROMPT STYLE (used by git_prompt_info / git_prompt_short_sha)
# ------------------------------------------------------------
YS_VCS_PROMPT_PREFIX="%{$fg_bold[cyan]%} "
YS_VCS_PROMPT_SUFFIX="%{$reset_color%} "
YS_VCS_PROMPT_DIRTY=" %{$fg[red]%}●"
YS_VCS_PROMPT_CLEAN=" %{$fg[green]%}●"
ZSH_THEME_GIT_PROMPT_PREFIX="$YS_VCS_PROMPT_PREFIX"
ZSH_THEME_GIT_PROMPT_SUFFIX="$YS_VCS_PROMPT_SUFFIX"
ZSH_THEME_GIT_PROMPT_DIRTY="$YS_VCS_PROMPT_DIRTY"
ZSH_THEME_GIT_PROMPT_CLEAN="$YS_VCS_PROMPT_CLEAN"
ZSH_THEME_GIT_PROMPT_SHA_BEFORE="%{$fg_bold[red]%}"
ZSH_THEME_GIT_PROMPT_SHA_AFTER="%{$reset_color%}"

# ------------------------------------------------------------
# ASYNC GIT STATE  (populated by the background worker)
# ------------------------------------------------------------
# Each variable holds a pre-rendered prompt fragment (or empty string).
# They are written only from _theme_async_callback, read only from PROMPT.
typeset -g _async_git_info=""      # output of git_prompt_info
typeset -g _async_git_sha=""       # output of git_prompt_short_sha
typeset -g _async_git_arrows=""    # ⇡ / ⇣
typeset -g _async_git_stash=""     # ≡
typeset -g _async_fd=0             # fd of the active background job (0 = none)

# ------------------------------------------------------------
# BACKGROUND WORKER
# Runs in a subshell; writes NUL-terminated records to stdout.
# All four fields are always emitted so the callback can parse
# them positionally without needing a separator scheme.
# ------------------------------------------------------------
_theme_async_worker() {
    # Must be called with the PWD already set to the right directory.
    # We receive it as $1 so the subshell starts in the correct place.
    builtin cd -q "$1" 2>/dev/null

    # ---- git_prompt_info (branch + dirty/clean dot) ----
    local gpi=""
    if command git rev-parse --git-dir &>/dev/null 2>&1; then
        # Replicate what oh-my-zsh's git_prompt_info does, but inline so
        # we don't depend on the OMZ function being available in the subshell.
        local branch
        branch=$(command git symbolic-ref --short HEAD 2>/dev/null) \
            || branch=$(command git rev-parse --short HEAD 2>/dev/null)
        if [[ -n $branch ]]; then
            local dirty=""
            if [[ -n $(command git status --porcelain --ignore-submodules=dirty 2>/dev/null | head -1) ]]; then
                dirty="$ZSH_THEME_GIT_PROMPT_DIRTY"
            else
                dirty="$ZSH_THEME_GIT_PROMPT_CLEAN"
            fi
            gpi="${ZSH_THEME_GIT_PROMPT_PREFIX}${branch}${dirty}${ZSH_THEME_GIT_PROMPT_SUFFIX}"
        fi
    fi

    # ---- git_prompt_short_sha ----
    local sha=""
    if command git rev-parse --git-dir &>/dev/null 2>&1; then
        local s
        s=$(command git rev-parse --short HEAD 2>/dev/null)
        if [[ -n $s ]]; then
            sha="${ZSH_THEME_GIT_PROMPT_SHA_BEFORE}${s}${ZSH_THEME_GIT_PROMPT_SHA_AFTER}"
        fi
    fi

    # ---- push/pull arrows ----
    local arrows=""
    if command git rev-parse --git-dir &>/dev/null 2>&1; then
        local counts ahead=0 behind=0
        counts=$(command git rev-list --left-right --count HEAD...@'{u}' 2>/dev/null)
        if [[ -n $counts ]]; then
            ahead=${counts%%$'\t'*}
            behind=${counts##*$'\t'}
            local arrow_u="" arrow_d=""
            (( ahead  > 0 )) && arrow_u="⇡"
            (( behind > 0 )) && arrow_d="⇣"
            arrows="${arrow_d}${arrow_u}"
        fi
    fi

    # ---- stash indicator ----
    local stash=""
    if command git rev-parse --git-dir &>/dev/null 2>&1; then
        local stash_count
        stash_count=$(command git rev-list --walk-reflogs --count refs/stash 2>/dev/null)
        [[ -n $stash_count && $stash_count -gt 0 ]] && stash="≡"
    fi

    # Emit four NUL-terminated fields.
    # Using printf %s\0 ensures even empty values produce a record.
    printf '%s\0%s\0%s\0%s\0' "$gpi" "$sha" "$arrows" "$stash"
}

# ------------------------------------------------------------
# ZLE CALLBACK — fires when the fd becomes readable
# ------------------------------------------------------------
_theme_async_callback() {
    local fd=$1
    local data

    # Read all four NUL-terminated fields.
    # IFS='' + read -d $'\0' reads one field per call.
    local gpi sha arrows stash
    IFS='' builtin read -r -d $'\0' -u "$fd" gpi
    IFS='' builtin read -r -d $'\0' -u "$fd" sha
    IFS='' builtin read -r -d $'\0' -u "$fd" arrows
    IFS='' builtin read -r -d $'\0' -u "$fd" stash

    # Deregister the handler and close the fd.
    zle -F "$fd"
    exec {fd}<&-
    _async_fd=0

    # Store rendered fragments.
    _async_git_info="$gpi"
    _async_git_sha="$sha"

    if [[ -n $arrows ]]; then
        _async_git_arrows="%{$fg_bold[cyan]%}${arrows}%{$reset_color%} "
    else
        _async_git_arrows=""
    fi

    if [[ -n $stash ]]; then
        _async_git_stash="%{$fg[cyan]%}${stash}%{$reset_color%} "
    else
        _async_git_stash=""
    fi

    # Repaint the prompt without blocking the current line.
    zle && zle .reset-prompt
}

# ------------------------------------------------------------
# LAUNCH A NEW ASYNC JOB
# Called from precmd. Cancels any previous in-flight job first.
# ------------------------------------------------------------
_theme_async_start() {
    # Close any still-open fd from a previous (slow) job.
    if (( _async_fd )); then
        zle -F "$_async_fd" 2>/dev/null
        exec {_async_fd}<&-
        _async_fd=0
    fi

    # Spawn the worker as a process substitution and grab its fd.
    exec {_async_fd} < <(_theme_async_worker "$PWD")

    # Register the ZLE I/O handler — fires when data is ready.
    zle -F "$_async_fd" _theme_async_callback
}

# ------------------------------------------------------------
# TUN0 IP ADDRESS INDICATOR
# ------------------------------------------------------------
_tun0_init() {
    local addr
    addr=$(/sbin/ip -br -4 addr list tun0 2>/dev/null | awk '{print $3}' | cut -d/ -f1)
    _tun0_cache="${addr}"
}
_tun0_init
_tun0_prompt() {
    if [[ -n $_tun0_cache ]]; then
        echo "%{$fg_bold[red]%}󰐷 $_tun0_cache%{$reset_color%} "
    fi
}

# ------------------------------------------------------------
# VIRTUAL ENVIRONMENT INDICATOR
# ------------------------------------------------------------
export VIRTUAL_ENV_DISABLE_PROMPT=1
_virtualenv_info() {
    if [[ -n $VIRTUAL_ENV ]]; then
        echo "%{$fg_bold[cyan]%}󱔎 [${VIRTUAL_ENV:t}]%{$reset_color%} "
    fi
}

# ------------------------------------------------------------
# USERNAME@HOSTNAME INDICATOR
# ------------------------------------------------------------
_prompt_userhost() {
    echo "%{$fg_bold[blue]%}%n@%m%{$reset_color%} "
}

# ------------------------------------------------------------
# CHPWD HOOK — fetch once when entering a git repo root
# Subdirectories won't have .git so they won't re-trigger.
# Use -e instead of -d if you use git worktrees (.git file).
# ------------------------------------------------------------
_theme_chpwd_git_fetch() {
    [[ -d $PWD/.git ]] || return
    (command git fetch --quiet 2>/dev/null &)
}

# ------------------------------------------------------------
# PRECMD HOOK — launch async worker, keep sync parts cheap
# ------------------------------------------------------------
_custom_precmd() {
    _theme_async_start
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _theme_chpwd_git_fetch
add-zsh-hook precmd _custom_precmd

# ------------------------------------------------------------
# THE PROMPT
# ------------------------------------------------------------
PROMPT='$(_virtualenv_info)\
$(_prompt_userhost)\
%{$fg_bold[yellow]%}道${PWD/#$HOME/~}%{$reset_color%} \
$(_tun0_prompt)\
${_async_git_info}\
${_async_git_sha}\
${_async_git_arrows}\
${_async_git_stash}\
%(1j.%{$fg_bold[yellow]%}✦%{$reset_color%} .)
%(?.%{$fg_bold[green]%}❯ .%{$fg_bold[red]%}❯ )%{$reset_color%}'

TRANSIENT_PROMPT_PROMPT=$PROMPT
TRANSIENT_PROMPT_TRANSIENT_PROMPT='%(?.%{$fg_bold[green]%}❯ .%{$fg_bold[red]%}❯ )%{$reset_color%}'
