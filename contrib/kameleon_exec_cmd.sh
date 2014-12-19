#!/usr/bin/env bash

ROOT_DIRECTORY=$(dirname $(readlink -f ${BASH_SOURCE[0]}))

function save_env {
    # Save environment
    (comm -3 <(declare | sort) <(declare -f | sort)) > "$ROOT_DIRECTORY/<%= File.basename(@bash_env_file) %>"
}

trap 'save_env' INT TERM EXIT

# Load environment
source "$ROOT_DIRECTORY/<%= File.basename(@bash_env_file) %>" 2> /dev/null || true

# Log cmd
echo <%= Shellwords.escape(cmd.value) %> >> "$ROOT_DIRECTORY/<%= File.basename(@bash_history_file) %>"

<%= cmd.value %>
