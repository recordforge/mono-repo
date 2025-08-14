# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="powerlevel10k/powerlevel10k"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
HYPHEN_INSENSITIVE="true"

# Uncomment the following line to automatically update without prompting.
DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Which plugins would you like to load?
plugins=(
    git
    docker
    docker-compose
    kubectl
    helm
    npm
    node
    python
    pip
    virtualenv
    colored-man-pages
    command-not-found
    extract
    sudo
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
)

# Load completions
autoload -U compinit && compinit

source $ZSH/oh-my-zsh.sh

# User configuration

# Set default editor
export EDITOR='code'

# Aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gpl='git pull'
alias gco='git checkout'
alias gb='git branch'
alias gd='git diff'
alias glog='git log --oneline --graph --decorate'
alias k='kubectl'
alias d='docker'
alias dc='docker-compose'
alias cls='clear'

# Docker aliases
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias drm='docker rm'
alias drmi='docker rmi'
alias dexec='docker exec -it'
alias dlogs='docker logs -f'

# Kubernetes aliases
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'
alias klog='kubectl logs -f'
alias kexec='kubectl exec -it'
alias kctx='kubectl config current-context'
alias kns='kubectl config set-context --current --namespace'

# Function to create and enter directory
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Function for quick git commit (unset alias first if it exists)
unalias gcm 2>/dev/null || true
gcm() {
    git commit -m "$*"
}

# Function to search history
hgrep() {
    history | grep "$*"
}

# Better history settings
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

# Enable better tab completion
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# Docker completion
zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes

# Git and GitHub CLI setup
gh auth setup-git 2>/dev/null || true
git config --global user.name "$(gh api user --jq .login 2>/dev/null || echo vscode)"
git config --global user.email "$(gh api user --jq .login 2>/dev/null || echo vscode)@users.noreply.github.com"

# UV (Python package manager)
export PATH="/home/vscode/.cargo/bin:$PATH"

# Node.js
export NODE_OPTIONS="--max-old-space-size=4096"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Auto-suggestions configuration
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# Syntax highlighting configuration
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)
typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[function]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[path]='fg=cyan'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=blue,bold'

# FZF if available
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Welcome message
echo "🚀 Dev Container Ready!"
echo "📦 Available tools: Docker, Kubernetes (kubectl), Helm, Minikube, Node.js, Python (uv)"
echo "💡 Type 'alias' to see all available shortcuts"