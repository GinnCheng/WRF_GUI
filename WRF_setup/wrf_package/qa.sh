#!/usr/bin/env bash

set -euo pipefail

INIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${INIT_DIR}/config.sh"

usage() {

    echo
    echo "Usage:"
    echo "  $0 YYYYMM"
    echo

    exit 1
}

[[ $# -eq 1 ]] || usage

YYYYMM="$1"

YEAR="${YYYYMM:0:4}"

RUNROOT="${RUN_DIR}/${YEAR}/${YYYYMM}"

WPSRUN="${RUNROOT}/WPS"

WRFRUN="${RUNROOT}/WRF"

AERMOD_MET="${AERMOD_DIR}/met/${YEAR}"

CALMET_MET="${CALMET_DIR}/met/${YEAR}"

FAIL=0

# ============================================================
# Reporting helpers
# ============================================================

pass() {

    printf "%-15s PASS\n" "$1"
}

fail() {

    printf "%-15s FAIL\n" "$1"

    FAIL=1
}

section() {

    echo
    echo "================================================"
    echo "$1"
    echo "================================================"
}

# ============================================================
# ERA5
# ============================================================

section "ERA5"

PL_COUNT=$(find "${ERA5_STORE}" \
    -name "era5_pl_*.grib" 2>/dev/null | wc -l)

SFC_COUNT=$(find "${ERA5_STORE}" \
    -name "era5_sfc_*.grib" 2>/dev/null | wc -l)

if [[ ${PL_COUNT} -gt 0 && ${SFC_COUNT} -gt 0 ]]
then
    pass "ERA5"
else
    fail "ERA5"
fi

# ============================================================
# GEOGRID
# ============================================================

section "WPS"

if ls "${WPSRUN}"/geo_em.d01.nc >/dev/null 2>&1
then
    pass "GEOGRID"
else
    fail "GEOGRID"
fi

# ============================================================
# METGRID
# ============================================================

MET_COUNT=$(find "${WPSRUN}" \
    -name "met_em.d01*" 2>/dev/null | wc -l)

if [[ ${MET_COUNT} -gt 0 ]]
then
    pass "METGRID"
else
    fail "METGRID"
fi

# ============================================================
# REAL
# ============================================================

section "REAL"

if [[ \
    -f "${WRFRUN}/wrfinput_d01" &&
    -f "${WRFRUN}/wrfbdy_d01"
]]
then
    pass "REAL"
else
    fail "REAL"
fi

# ============================================================
# WRF
# ============================================================

section "WRF"

WRF_COUNT=$(find "${WRFRUN}" \
    -name "wrfout_d01_*" 2>/dev/null | wc -l)

if [[ ${WRF_COUNT} -gt 0 ]]
then

    pass "WRF"

    FIRST_WRF=$(find "${WRFRUN}" \
        -name "wrfout_${DEFAULT_DOMAIN}_*" \
        | sort | head -n 1)

    LAST_WRF=$(find "${WRFRUN}" \
        -name "wrfout_${DEFAULT_DOMAIN}_*" \
        | sort | tail -n 1)

    if [[ -n "${FIRST_WRF}" ]]
    then

        START_TIME=$(
            python "${SCRIPT_DIR}/common.py" \
            wrf_times "${FIRST_WRF}" \
            | head -n 1
        )

        END_TIME=$(
            python "${SCRIPT_DIR}/common.py" \
            wrf_times "${LAST_WRF}" \
            | tail -n 1
        )

        echo
        echo "First timestep : ${START_TIME}"
        echo "Last timestep  : ${END_TIME}"

    fi

else

    fail "WRF"

fi

# ============================================================
# MMIF
# ============================================================

section "MMIF"

SFC_FILE="${AERMOD_MET}/${SITE}_${YYYYMM}_${DEFAULT_DOMAIN}.SFC"

PFL_FILE="${AERMOD_MET}/${SITE}_${YYYYMM}_${DEFAULT_DOMAIN}.PFL"

if [[ \
    -s "${SFC_FILE}" &&
    -s "${PFL_FILE}"
]]
then
    pass "MMIF"
else
    fail "MMIF"
fi

# ============================================================
# CALWRF
# ============================================================

section "CALWRF"

M3D_FILE="${CALMET_MET}/${SITE}_${YYYYMM}_${DEFAULT_DOMAIN}.m3d"

if [[ -s "${M3D_FILE}" ]]
then
    pass "CALWRF"
else
    fail "CALWRF"
fi

# ============================================================
# Logs
# ============================================================

section "LOGS"

LOG_COUNT=$(find "${RUNROOT}/logs" \
    -name "*.log" 2>/dev/null | wc -l)

echo "Log files : ${LOG_COUNT}"

# ============================================================
# Summary
# ============================================================

echo
echo "================================================"
echo "SUMMARY"
echo "================================================"

echo "Month     : ${YYYYMM}"

echo "WPS files : ${MET_COUNT}"

echo "WRF files : ${WRF_COUNT}"

echo

if [[ ${FAIL} -eq 0 ]]
then

    echo "STATUS : PASS"

else

    echo "STATUS : FAIL"

    exit 1

fi