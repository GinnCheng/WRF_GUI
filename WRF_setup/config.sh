#!/usr/bin/env bash

# ============================================================
# PROJECT PATH
# ============================================================

BASE="/appdisk/WRF"

PROJECT="projects"
SITE="TUAS3_GC"

# ============================================================
# SITE DETAILS
# ============================================================

SITE_LAT=1.28
SITE_LON=103.64

TZ_OFFSET_HR=8
TIMEZONE_NAME="AEST"

# Lambert projection defaults
TRUELAT1="${SITE_LAT}"
TRUELAT2="${SITE_LAT}"
STAND_LON="${SITE_LON}"

# ============================================================
# SOFTWARE PATHS
# ============================================================

WRF_DIR="/appdisk/WRF/software/WRF"
WPS_DIR="/appdisk/WRF/software/WPS"
WPS_GEOG="/appdisk/WRF/software/WPS"
MMIF_EXE_DEFAULT="/appdisk/WRF/software/MMIF/MMIF4.1.1/mmif"
CALWRF_EXE_DEFAULT="/appdisk/WRF/software/CALWRF/code/calwrf"

# ============================================================
# ERA5 GEOGRAPHIC SETTINGS
# ============================================================

ERA5_VENV="${HOME}/.venvs/era5"
ERA5_PY="${ERA5_VENV}/bin/python"
ERA5_DOWNLOAD_MODE="submit_only"
# submit_only
# download

ERA5_USE_AREA="true"

BBOX_NORTH="4.6"
BBOX_SOUTH="-2.0"

BBOX_WEST="100.3"
BBOX_EAST="106.9"

BBOX_BUFFER_DEG="1"

# ============================================================
# DOMAIN SETTINGS
# ============================================================

MAX_DOM=3

# Domain 1
D01_DX=9000
D01_DY=9000
D01_E_WE=31
D01_E_SN=31

# Domain 2
D02_DX=3000
D02_DY=3000
D02_E_WE=31
D02_E_SN=31

# Domain 3
D03_DX=1000
D03_DY=1000
D03_E_WE=31
D03_E_SN=31

# ============================================================
# WRF SETTINGS
# ============================================================

TIME_STEP=54
E_VERT=35
P_TOP_REQUESTED=5000
HISTORY_INTERVAL=60
FRAMES_PER_OUTFILE=24

# ============================================================
# PHYSICS
# ============================================================

MP_PHYSICS=4

RA_LW_PHYSICS=1
RA_SW_PHYSICS=1

BL_PBL_PHYSICS=1

CU_PHYSICS_D01=1
CU_PHYSICS_NEST=0

SF_SFCLAY_PHYSICS=1
SF_SURFACE_PHYSICS=2

NUM_SOIL_LAYERS=4

# ============================================================
# EXECUTION
# ============================================================

NPROC=4
DEFAULT_DOMAIN="d03"

# ============================================================
# DERIVED PATHS
# ============================================================

ROOT="${BASE}/${PROJECT}/${SITE}"
CONFIG_DIR="${ROOT}/00_config"
TEMPLATE_DIR="${CONFIG_DIR}/templates"
NOTE_DIR="${CONFIG_DIR}/notes"
SITE_DIR="${CONFIG_DIR}/site"
ERA5_STORE="${ROOT}/02_met_data/ERA5"
RUN_DIR="${ROOT}/03_runs"
AERMOD_DIR="${ROOT}/04_aermod"
CALMET_DIR="${ROOT}/04_calmet"
LOG_DIR="${ROOT}/05_logs"

# ============================================================
# OUTPUT CONTROL
# ============================================================

GENERATE_MMIF="true"
GENERATE_CALWRF="true"
GENERATE_YEARLY_MMIF="true"
GENERATE_YEARLY_CALWRF="true"



# ============================================================
# CREATE PROJECT STRUCTURE
# ============================================================

mkdir -p "${ROOT}"

mkdir -p "${CONFIG_DIR}"
mkdir -p "${TEMPLATE_DIR}"
mkdir -p "${NOTE_DIR}"
mkdir -p "${SITE_DIR}"

mkdir -p "${ERA5_STORE}"

mkdir -p "${RUN_DIR}"

mkdir -p "${AERMOD_DIR}"
mkdir -p "${CALMET_DIR}"

mkdir -p "${LOG_DIR}"