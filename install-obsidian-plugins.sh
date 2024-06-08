#!/bin/bash

# ------------------------------------------------------------------------------------
# Run this script from inside an Obsidian vault, and it will automatically install
# all the registered community plugins and themes into the .obsidian directory
#

set -Eeuo pipefail
trap clean_up ERR EXIT SIGINT SIGTERM

clean_up() {
    trap - ERR EXIT SIGINT SIGTERM
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m' GRAY='\e[38;5;251m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "${RED}$msg${NOFORMAT}"
  exit "$code"
}

join_list() {
    join_pattern=${2-, }
    echo "${1}" | awk "ORS=\"$join_pattern\"" | sed "s/$join_pattern$/\n/"
}

download_latest_gh_assets() {
    repo="${1}"
    location="${2}"
    assets=("$@")
    assets=("${assets[@]:2}")

    mkdir -p "$location"

    release_dl_failed=0
    for asset in "${assets[@]}"; do
        set +e
        wget "https://github.com/$repo/releases/latest/download/$asset" -qO "$location/$asset"
        result=$?
        set -e

        if [ "$result" -ne 0 ] && [[ ! "${OPTIONAL_ASSETS[@]}" =~ "$asset" ]]; then
            msg "${YELLOW}Missing asset from releases: ${GRAY}$asset${NOFORMAT}"
            release_dl_failed=1 
            break
        fi
    done

    repo_dl_failed=0
    if [ "$release_dl_failed" -ne 0 ]; then
        msg "${YELLOW}Github release asset download failed, attempting to find assets in repo root...${NOFORMAT}"
        rm -rf "$location/*" # Cleanup partial release dl

        assets_include=""
        for asset in "${assets[@]}"; do assets_include+="*/$asset "; done

        set +e
        wget "https://github.com/$repo/archive/master.tar.gz" -qO- | \
            tar xz -C "$location" --strip-components 1 --wildcards $assets_include
        result=$?
        set -e

        if [ "$result" -ne 0 ]; then
            repo_dl_failed=1
        fi
    fi

    # Complete failure state, clean up and skip
    if [ "$repo_dl_failed" -ne 0 ]; then
        rm -rf "$location"
        msg "${YELLOW}Failed to find all assets, skipping...${NOFORMAT}"
    fi
}

OBSIDIAN_PLUGIN_REPO_JSON="" # cache
get_plugins_data() {
    if [ -z "${OBSIDIAN_PLUGIN_REPO_JSON}" ]; then
        OBSIDIAN_PLUGIN_REPO_JSON="$(curl -sf https://raw.githubusercontent.com/obsidianmd/obsidian-releases/master/community-plugins.json)" || die "Failed to fetch Obsidian community plugin repository."
    fi
    echo "${OBSIDIAN_PLUGIN_REPO_JSON}"
}
OBSIDIAN_THEME_REPO_JSON="" # cache
get_themes_data() {
    if [ -z "${OBSIDIAN_THEME_REPO_JSON}" ]; then
        OBSIDIAN_THEME_REPO_JSON="$(curl -sf https://raw.githubusercontent.com/obsidianmd/obsidian-releases/master/community-css-themes.json)" || die "Failed to fetch Obsidian theme repository."
    fi
    echo "${OBSIDIAN_THEME_REPO_JSON}"
}

get_plugin_repo() {
    plugin="${1}"
    plugin_repo=$(get_plugins_data | jq -r ".[] | select(.id == \"$plugin\") | .repo")

    # Apply repo patch if available
    [ -f "${PLUGIN_PATCH_FILE}" ] \
        && plugin_repo_patch=$(jq -r ".[] | select(.id == \"$plugin\") | .repo" "${PLUGIN_PATCH_FILE}") \
        || plugin_repo_patch=""
    [ -z "${plugin_repo_patch}" ] || plugin_repo="${plugin_repo_patch}"

    [ -z "${plugin_repo}" ] && die "Failed to find the repo for the plugin ${GRAY}${plugin}${NOFORMAT}"
    echo "${plugin_repo}"
}
get_theme_repo() {
    theme="${1}"
    theme_repo=$(get_themes_data | jq -r ".[] | select(.name == \"$theme\") | .repo")
    [ -z "${theme_repo}" ] && die "Failed to find the repo for the theme ${GRAY}${theme}${NOFORMAT}"
    echo "${theme_repo}"
}

install_plugin() {
    plugin_id="${1}"

    [ "${FORCE}" -ne 1 ] && [ -f "${PLUGINS_DIR}/$plugin_id/${PLUGIN_ASSETS[0]}" ] && msg "${GRAY}$plugin_id${NOFORMAT} already installed, skipping..." && return
    repo="$(get_plugin_repo $plugin_id)"

    msg "Installing plugin ${GRAY}$plugin_id${NOFORMAT}..."
    download_latest_gh_assets "$repo" "${PLUGINS_DIR}/$plugin_id" "${PLUGIN_ASSETS[@]}"
}
install_theme() {
    theme_name="${1}"

    [ "${FORCE}" -ne 1 ] && [ -d "${THEMES_DIR}/$theme_name" ] && msg "${GRAY}$theme_name${NOFORMAT} already installed, skipping..." && return
    repo="$(get_theme_repo "$theme_name")"

    msg "Installing theme ${GRAY}$theme_name${NOFORMAT}..."
    download_latest_gh_assets "$repo" "${THEMES_DIR}/$theme_name" "${THEME_ASSETS[@]}"
}

setup_colors

# Prereqs
command -v jq >/dev/null || die "jq required for parsing - install and run this script again."

VAULT_ROOT=$(git rev-parse --show-toplevel || pwd)
cd "$VAULT_ROOT"

FORCE=0
[ "${1-}" = "-f" ] && FORCE=1

PLUGIN_LIST_FILE="./.obsidian/community-plugins.json"
PLUGIN_PATCH_FILE="./.obsidian/community-plugins-patch.json"
PLUGINS_DIR="./.obsidian/plugins"
PLUGIN_ASSETS=(manifest.json main.js styles.css)

APPEARANCE_FILE="./.obsidian/appearance.json"
THEMES_DIR="./.obsidian/themes"
THEME_ASSETS=(manifest.json theme.css)

OPTIONAL_ASSETS=(styles.css) # Dont fail on these

[ -f "${PLUGIN_LIST_FILE}" ] || die "Could not find Obsidian plugin list ${PLUGIN_LIST_FILE} - run script inside an Obsidian vault"
[ -f "${APPEARANCE_FILE}" ] || die "Could not find Obsidian appearance file ${APPEARANCE_FILE} - run script inside an Obsidian vault"

msg "Running on the vault at ${PWD}"

[ "${FORCE}" -eq 1 ] && msg "Force-reinstalling found plugins and themes..."

plugins=$(jq -r '.[]' ${PLUGIN_LIST_FILE})
theme=$(jq -r '.cssTheme' ${APPEARANCE_FILE})

msg
msg "Found registered community plugins:"
msg "${GRAY}$(join_list "$plugins")${NOFORMAT}"

msg
msg "Installing plugins to ${PLUGINS_DIR}"

while IFS= read -r plugin; do
    install_plugin "$plugin"
done <<< "$plugins"

msg
msg "Installing themes to ${THEMES_DIR}"
install_theme "$theme"

msg
msg "${GREEN}Done${NOFORMAT}"
