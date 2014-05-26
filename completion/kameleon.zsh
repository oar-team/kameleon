#!/usr/bin/env zsh

if [[ ! -o interactive ]]; then
    return
fi

compctl -K _kameleon kameleon

_kameleon() {
  local words completions
  read -cA words

  if [ "${#words}" -eq 2 ]; then
    completions="$(kameleon commands)"
  else
    completions="$(kameleon completions ${words[2,-2]})"
  fi

  reply=("${(ps:\n:)completions}")
}
