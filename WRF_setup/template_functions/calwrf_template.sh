#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${SCRIPT_DIR}/config.sh"

cat > "${TEMPLATE_DIR}/calwrf.inp.template" << 'EOF'
Create 3D.DAT file for WRF output
CALWRF_LOGFILE ! Log file name
CALWRF_OUTFILE ! Output 3D.DAT (m3d) file name
-1,-1,-1,-1,-1,-1 ! Beg/End I/J/K ("-" for all)
START_YYYYMMDDHH ! Start datetime (UTC yyyymmddhh)
END_YYYYMMDDHH ! End datetime (UTC yyyymmddhh)
NFILES ! Number of WRF output files
WRFOUT_FILES_HERE
EOF