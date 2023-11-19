# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="avit"
#ZSH_THEME="jonathan"

# Uncomment one of the following lines to change the auto-update behavior
zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git z)
source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# my aliases
alias zshconfig="mate ~/.zshrc"
alias ohmyzsh="mate ~/.oh-my-zsh"
alias pip="pip3"
alias python="python3"
alias nano='/Users/mattsampson/homebrew/bin/nano'
alias create='python scripts/txt2img.py --plms --skip_grid --n_samples 1 --prompt'
alias jupe="ssh -L 8890:localhost:8890 adi"

# added paths
export PATH=/usr/local/bin:/usr/local/sbin:${PATH}
export PATH=/Library/TeX/texbin/${PATH}
export PATH=/opt/homebrew/bin:${PATH}

# MESA things for Stars class with Adam Burrows
export MESASDK_ROOT=/Applications/mesasdk
source $MESASDK_ROOT/bin/mesasdk_init.sh
export MESA_DIR=/Users/mattsampson/Princeton/Software/mesa-r22.11.1
export OMP_NUM_THREADS=4

# added flags for installs
eval "$(homebrew/bin/brew shellenv)"

# testing alt brew location
#eval "$(/opt/homebrew/bin/brew shellenv)"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/mattsampson/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/mattsampson/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/mattsampson/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/mattsampson/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

#export PATH=/opt/homebrew/bin:/Users/mattsampson/miniconda3/bin:/Users/mattsampson/miniconda3/condabin:/Users/mattsampson/homebrew/bin:/Users/mattsampson/homebrew/sbin:/Library/TeX/texbin/usr/local/bin:/usr/local/sbin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/TeX/texbin:/Users/mattsampson/.cargo/bin:/Users/mattsampson/Library/Application Support/JetBrains/Toolbox/scripts
