#!/usr/bin/env bash

ROOT_DIRECTORY=$(dirname $(readlink -f ${BASH_SOURCE[0]}))

function post_exec_wrapper {
    echo $? > "$ROOT_DIRECTORY/<%= File.basename(@bash_status_file) %>"
    # Print end flags
    echo -n <%= cmd.end_err %> 1>&2
    echo -n <%= cmd.end_out %>
}

function pre_exec_wrapper {
    # Print begin flags
    echo -n <%= cmd.begin_err %> 1>&2
    echo -n <%= cmd.begin_out %>
}

trap 'post_exec_wrapper' INT TERM EXIT

## Started
pre_exec_wrapper
bash --rcfile "<%= @bashrc_file %>" <%= File.join(@bash_scripts_dir, "#{cmd}.sh" ) %>
