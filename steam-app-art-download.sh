#!/usr/bin/env bash

set -Eeuo pipefail

ASSETS=(
    "capsule_231x87.jpg"
    "capsule_616x353.jpg"
    "header.jpg"
    "hero_capsule.jpg"
    "library_600x900.jpg"
    "library_header.jpg"
    "library_hero.jpg"
    "logo.png")

APP_ID="${1-}"

if [ ! -z "${APP_ID}" ]; then
    for asset in "${ASSETS[@]}"; do
        wget -O "steam.${APP_ID}.${asset}" \
            "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/${APP_ID}/${asset}" || true
    done
fi
