#!/usr/bin/env bash

# /bin/bash <(curl -sSL https://raw.githubusercontent.com/brendonthiede/brendonthiede.github.io/master/scripts/cloudshell-init.sh)

HAS_CHANGES="false"

ORIGINAL_CHECKSUM="$(md5sum ~/.cloudshell_profile | awk '{print $1}')"
curl -sSLo ~/.cloudshell_profile https://raw.githubusercontent.com/brendonthiede/brendonthiede.github.io/master/scripts/.cloudshell_profile
NEW_CHECKSUM="$(md5sum ~/.cloudshell_profile | awk '{print $1}')"

if [[ "${ORIGINAL_CHECKSUM}" != "${NEW_CHECKSUM}" ]]; then
    HAS_CHANGES="true"
fi

mkdir -p "${HOME}/.bash_completion.d"

if [[ ! -f "${HOME}/.local/bin/kubetail" ]]; then
    curl -sSLo "${HOME}/.local/bin/kubetail" "https://raw.githubusercontent.com/johanhaleby/kubetail/master/kubetail"
    chmod +x "${HOME}/.local/bin/kubetail"
    curl -sSLo "${HOME}/.bash_completion.d/kubetail" "https://raw.githubusercontent.com/johanhaleby/kubetail/master/completion/kubetail.bash"
    HAS_CHANGES="true"
fi

if [[ ! -f "${HOME}/.local/bin/helm" ]]; then
    curl -sSLo "${HOME}/helm.tgz" https://get.helm.sh/helm-v3.12.0-rc.1-linux-amd64.tar.gz
    tar -zxf "${HOME}/helm.tgz" '**/helm'
    mv "./linux-amd64/helm" "${HOME}/.local/bin/helm"
    rm -rf "./linux-amd64" "${HOME}/helm.tgz"
    HAS_CHANGES="true"
fi

if ! grep 'source ~/\.cloudshell_profile' ~/.bash_profile >/dev/null; then
    echo 'source ~/.cloudshell_profile' >>~/.bash_profile
    HAS_CHANGES="true"
fi

mkdir -p "${HOME}/.local/bin"

if [[ ! -f "${HOME}/.local/bin/rdcli" ]]; then
    npm install --prefix ~/ redis-cli
    ln -s ~/node_modules/redis-cli/bin/rdcli ~/.local/bin/rdcli
    HAS_CHANGES="true"
fi

if [[ "${HAS_CHANGES}" == "true" ]]; then
    echo "Changes detected. Restarting shell..."
    exec bash
    exit
else
    echo "No changes detected."
fi
