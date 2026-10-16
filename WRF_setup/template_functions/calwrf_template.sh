#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${SCRIPT_DIR}/config.sh"

cat > "${TEMPLATE_DIR}/calwrf.inp.template" << 'EOF'
Create 3D.DAT file for WRF output

CALWRF_LOGFILE

CALWRF_OUTFILE

-1,-1,-1,-1,-1,-1

START_YYYYMMDDHH

END_YYYYMMDDHH

NFILES

WRFOUT_FILES_HERE
EOF