#!/usr/bin/env bash

_kameleon() {
    COMPREPLY=()
    local i=1
    while [ $i -le "$COMP_CWORD" -a  "${COMP_WORDS[$i]:0:1}" == "-" ]; do
        ((i++))
    done
    if [ "$COMP_CWORD" -eq $i ]; then
        local commands="$(compgen -W "$(kameleon commands)" -- "${COMP_WORDS[$i]}")"
        COMPREPLY=( $commands $projects )
    fi
    while [ $i -le "$COMP_CWORD" -a  "${COMP_WORDS[$i]:0:1}" == "-" ]; do
        ((i++))
    done
    if [ "$COMP_CWORD" -eq $((i+1)) ] && kameleon commands | grep -q "${COMP_WORDS[$i]}" ; then
        if kameleon help | grep -qe "^  kameleon ${COMP_WORDS[$i]}[a-z]* <SUBCOMMAND>"; then
            local commands="$(compgen -W "$(kameleon ${COMP_WORDS[$i]} commands)" -- "${COMP_WORDS[$((i+1))]}")"
            COMPREPLY=( $commands $projects )
        fi
    fi
}

complete -o default -F _kameleon kameleon
