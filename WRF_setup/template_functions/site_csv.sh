#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${SCRIPT_DIR}/config.sh"

cat > "${SITE_DIR}/site_${SITE}.csv" << EOF
site,lat,lon,tz
${SITE},${SITE_LAT},${SITE_LON},${TIMEZONE_NAME}
EOF