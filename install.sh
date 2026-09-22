#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly BREWFILE="${SCRIPT_DIR}/Brewfile"
readonly HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

installer_file=""
brew_bin=""

cleanup() {
    if [[ -n "${installer_file}" && -f "${installer_file}" ]]; then
        rm -f -- "${installer_file}"
    fi
}

on_error() {
    local exit_code=$?
    printf 'Error: command failed (line %s, exit code %s).\n' "${BASH_LINENO[0]}" "${exit_code}" >&2
    exit "${exit_code}"
}

trap cleanup EXIT
trap on_error ERR

if [[ "$(uname -s)" != "Darwin" ]]; then
    printf 'Error: this installer is intended for macOS.\n' >&2
    exit 1
fi

if [[ ! -f "${BREWFILE}" ]]; then
    printf 'Error: Brewfile not found at %s.\n' "${BREWFILE}" >&2
    exit 1
fi

find_brew() {
    local candidate

    if command -v brew >/dev/null 2>&1; then
        command -v brew
        return 0
    fi

    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "${candidate}" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done

    return 1
}

if ! brew_bin="$(find_brew)"; then
    if ! command -v curl >/dev/null 2>&1; then
        printf 'Error: curl is required to install Homebrew but was not found.\n' >&2
        exit 1
    fi

    printf 'Homebrew not found. Downloading the official installer...\n'
    installer_file="$(mktemp -t homebrew-install.XXXXXX)"
    curl --fail --silent --show-error --location "${HOMEBREW_INSTALL_URL}" \
        --output "${installer_file}"
    /bin/bash "${installer_file}"

    if ! brew_bin="$(find_brew)"; then
        printf 'Error: Homebrew installation completed, but brew could not be found.\n' >&2
        exit 1
    fi
fi

# Make brew and its subcommands available in this process, including after a
# fresh Apple Silicon installation.
eval "$("${brew_bin}" shellenv)"
brew_bin="$(command -v brew)"

printf 'Using Homebrew at %s\n' "${brew_bin}"
printf 'Checking Brewfile dependencies...\n'

if ! "${brew_bin}" bundle check --file="${BREWFILE}"; then
    printf 'Some Brewfile dependencies are missing; installing them...\n'
    "${brew_bin}" bundle install --file="${BREWFILE}"
else
    printf 'Brewfile dependencies are already satisfied.\n'
fi

printf 'Homebrew setup complete.\n'
