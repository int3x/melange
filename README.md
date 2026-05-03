# melange

Theme for oh-my-zsh with a melange of features.

## Installation

```console
$ git clone --depth 1 https://github.com/olets/zsh-transient-prompt ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/transient-prompt
$ wget https://raw.githubusercontent.com/int3x/melange/refs/heads/main/melange.zsh-theme -O ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/melange.zsh-theme
```

In `~/.zshrc`, set the theme to `melange` and include `transient-prompt` in plugins:

```text
ZSH_THEME="melange"
#.....SNIP.....
plugins=(
    git
#.....SNIP.....
    transient-prompt
)
```
