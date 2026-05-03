setopt PROMPT_SUBST

# ------------------------------------------------------------
# GIT BRANCH, COMMIT HASH, DIRTY/CLEAN, PUSH/PULL AND STASH INDICATOR
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

_git_arrows=""
_git_stash=""

_precmd_git_info() {
    if ! command git rev-parse --git-dir &>/dev/null 2>&1; then
        _git_arrows=""
        _git_stash=""
        return
    fi

    local arrow_u="" arrow_d=""
    local counts
    counts=$(command git rev-list --left-right --count HEAD...@'{u}' 2>/dev/null)
    if [[ -n $counts ]]; then
        local ahead behind
        ahead=${counts%%$'\t'*}
        behind=${counts##*$'\t'}
        (( ahead  > 0 )) && arrow_u="⇡"
        (( behind > 0 )) && arrow_d="⇣"
    fi
    _git_arrows="${arrow_d}${arrow_u}"

    local stash_count
    stash_count=$(command git rev-list --walk-reflogs --count refs/stash 2>/dev/null)
    if [[ -n $stash_count && $stash_count -gt 0 ]]; then
        _git_stash="≡"
    else
        _git_stash=""
    fi
}

_prompt_git_extras() {
    if [[ -n $_git_arrows ]]; then
        echo "%{$fg_bold[cyan]%}${_git_arrows}%{$reset_color%} "
    fi
    if [[ -n $_git_stash ]]; then
        echo "%{$fg[cyan]%}${_git_stash}%{$reset_color%} "
    fi
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
# PRECMD HOOK
# ------------------------------------------------------------
_custom_precmd() {
    _precmd_git_info
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _custom_precmd


# ------------------------------------------------------------
# THE PROMPT
# ------------------------------------------------------------
PROMPT='$(_virtualenv_info)\
$(_prompt_userhost)\
%{$fg_bold[yellow]%}道${PWD/#$HOME/~}%{$reset_color%} \
$(_tun0_prompt)\
$(git_prompt_info)\
$(git_prompt_short_sha)\
$(_prompt_git_extras)\
%(1j.%{$fg_bold[yellow]%}✦%{$reset_color%} .)
%(?.%{$fg_bold[green]%}❯ .%{$fg_bold[red]%}❯ )%{$reset_color%}'

TRANSIENT_PROMPT_PROMPT=$PROMPT
TRANSIENT_PROMPT_TRANSIENT_PROMPT='%(?.%{$fg_bold[green]%}❯ .%{$fg_bold[red]%}❯ )%{$reset_color%}'
