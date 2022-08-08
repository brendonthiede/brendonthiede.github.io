#/usr/bin/env bash

_shipa_completions() {
    COMPREPLY=($(compgen -W "$(shipa --help | grep '^  [a-z]*-' | awk '{print $1}' | tr '\n' ' ')" "${COMP_WORDS[1]}"))
}

complete -F _shipa_completions shipa
