#!/usr/bin/env bash

set -o errexit
set -o pipefail

__ROOT_DIRECTORY__=$(dirname $(readlink -f ${BASH_SOURCE[0]}))

function save_env {
    # Save environment
    <% if Kameleon.env.debug %>set +x<% end %>
    (comm -3 <(declare | sort) <(declare -f | sort)) > "${__ROOT_DIRECTORY__}/<%= File.basename(@bash_env_file) %>"
}

trap 'save_env' INT TERM EXIT

# Load environment
source "${__ROOT_DIRECTORY__}/<%= File.basename(@bash_env_file) %>" 2> /dev/null || true

# Log cmd
echo <%= Shellwords.escape(cmd.value) %> >> "${__ROOT_DIRECTORY__}/<%= File.basename(@bash_history_file) %>"

<% if Kameleon.env.debug %>set -o xtrace <% end %>

<%= cmd.value %>
