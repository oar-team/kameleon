#!/usr/bin/env bash

_kameleon() {
    COMPREPLY=()
    local word="${COMP_WORDS[COMP_CWORD]}"

    if [ "$COMP_CWORD" -eq 1 ]; then
        local commands="$(compgen -W "$(kameleon commands)" -- "$word")"
        COMPREPLY=( $commands $projects )
    fi
}

complete -o default -F _kameleon kameleon
