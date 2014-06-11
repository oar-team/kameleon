#!/usr/bin/env zsh

if [[ ! -o interactive ]]; then
    return
fi

compctl -f -K _kameleon kameleon

_kameleon() {
  local words completions
  read -cA words

  if [ "${#words}" -eq 2 ]; then
    completions="$(kameleon commands)"
  fi

  reply=("${(ps:\n:)completions}")
}
