# If not running interactively, don't do anything
export USER=${USER:-"root"}
export HOME=${HOME:-"/root"}
export PATH=/usr/bin:/usr/sbin:/bin:/sbin:$PATH
export LC_ALL=${LC_ALL:-"POSIX"}

export DEBIAN_FRONTEND=noninteractive

mkdir -p $(dirname <%= @bash_history_file %>) ; touch "<%= @bash_history_file %>"
mkdir -p $(dirname <%= @bash_env_file %>) ; touch "<%= @bash_env_file %>"

source /etc/bash.bashrc 2> /dev/null

export KAMELEON_CONTEXT_NAME="<%= @context_name %>_context"
export HISTFILE="<%= @bash_history_file %>"

## functions

function fail {
    echo $@ 1>&2
    false
}

## aliases
if [ -t 1 ] ; then
# restore previous env
source "<%= @bash_env_file %>"  2> /dev/null
export TERM=xterm
# for fast typing
alias h='history'
alias g='git status'
alias l='ls -lah'
alias ll='ls -lh'
alias la='ls -Ah'

# for human readable output
alias ls='ls -h'
alias df='df -h'
alias du='du -h'

# simple history browsing
export HISTCONTROL=erasedups
export HISTSIZE=10000
export HISTIGNORE="history*"
shopt -s histappend
bind '"\e[A"':history-search-backward
bind '"\e[B"':history-search-forward

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# If this is an xterm set the title to user@host:dir
PROMPT_COMMAND='echo -ne "\033]0;${KAMELEON_CONTEXT_NAME:+($KAMELEON_CONTEXT_NAME)}${USER}@${HOSTNAME}: ${PWD}\007"'

# set variable to show git branch when in a git repository
# source: https://github.com/jimeh/git-aware-prompt/blob/master/prompt.sh
# added highlighting of repo part in path
function find_git_branch {
    git_subpath='/'
    local dir=${PWD} head
    until [ "$dir" = "" ]; do
        if [ -f "$dir/.git/HEAD" ]; then
            head=$(< "$dir/.git/HEAD")
            if [[ $head == ref:\ refs/heads/* ]]; then
                git_branch=" (${head#*/*/})"
            elif [[ $head != '' ]]; then
                git_describe=$(git describe --always)
                git_branch=" (detached: $git_describe)"
            else
                git_branch=' (unknown)'
            fi
            prompt_dir="${dir/$HOME/~}"
            return
        fi
        git_subpath="/${dir##*/}$git_subpath"
        dir="${dir%/*}"
    done
    git_branch=''
    prompt_dir="${PWD/$HOME/~}"
    git_subpath=''
}
function find_git_dirty {
    st=$(git status -s 2>/dev/null | tail -n 1)
    if [[ $st == "" ]]; then
        git_dirty=''
    else
        git_dirty='*'
    fi
}
export find_git_branch
export find_git_dirty
PROMPT_COMMAND="find_git_branch; find_git_dirty; history -a ; $PROMPT_COMMAND"

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

# if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # We have color support; assume it's compliant with Ecma-48
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
        # a case would tend to support setf rather than setaf.)
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${KAMELEON_CONTEXT_NAME:+($KAMELEON_CONTEXT_NAME) }\[\033[01;32m\]\u@\h\[\033[00m\]: \[\e[1;37m\]$prompt_dir\[\e[1;36m\]$git_subpath\[\e[0;31m\]$git_branch\[\e[1;33m\]$git_dirty\[\033[01;34m\] \$\[\033[00m\] '
else
    PS1='${KAMELEON_CONTEXT_NAME:+($KAMELEON_CONTEXT_NAME) }\u@\h: $prompt_dir$git_subpath$git_branch$git_dirty \$ '
fi

# colors
if [ -x /usr/bin/dircolors ]; then
    eval "`dircolors -b`"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
else
    alias ls='ls -G'
fi
fi

function __download {
    echo "Downloading: $1..."
    if which curl >/dev/null; then
        curl -# "$1" -o "$2" 2>&1
    else
        fail "curl is missing, trying with wget..."
        if which wget >/dev/null; then
            wget --progress=bar:force "$1" -O "$2" 2>&1
        else
            fail "wget is missing, trying with python..."
            if which python >/dev/null; then
                python -c "
import sys
import time
if sys.version_info >= (3,):
    import urllib.request as urllib
else:
    import urllib


def reporthook(count, block_size, total_size):
    global start_time
    if count == 0:
        start_time = time.time()
        return
    duration = time.time() - start_time
    progress_size = float(count * block_size)
    if duration != 0:
        if total_size == -1:
            total_size = block_size
            percent = 'Unknown size, '
        else:
            percent = '%.0f%%, ' % float(count * block_size * 100 / total_size)
        speed = int(progress_size / (1024 * duration))
        sys.stdout.write('\r%s%.2f MB, %d KB/s, %d seconds passed'
                         % (percent, progress_size / (1024 * 1024), speed, duration))
        sys.stdout.flush()

urllib.urlretrieve('$1', '$2', reporthook=reporthook)
print('\n')
"
            true
            else
                fail "Cannot download $1"
            fi
        fi
    fi
}
