#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

usage() {
    echo "Usage: $0 YYYYMM"
    exit 1
}

[[ $# -eq 1 ]] || usage

YYYYMM="$1"

[[ "${YYYYMM}" =~ ^[0-9]{6}$ ]] || usage

YEAR="${YYYYMM:0:4}"

RUNROOT="${RUN_DIR}/${YEAR}/${YYYYMM}"

WPSRUN="${RUNROOT}/WPS"
WRFRUN="${RUNROOT}/WRF"
LOGRUN="${RUNROOT}/logs"

METDIR="${ROOT}/02_met_data/${YEAR}/${YYYYMM}"

# ------------------------------------------------------------
# Validation
# ------------------------------------------------------------

[[ -f "${WPSRUN}/namelist.wps" ]] || {
    echo "ERROR: Missing ${WPSRUN}/namelist.wps"
    echo "Run pre_runwrf_era5.sh ${YYYYMM} first"
    exit 10
}

[[ -f "${WRFRUN}/namelist.input.real" ]] || {
    echo "ERROR: Missing ${WRFRUN}/namelist.input.real"
    echo "Run pre_runwrf_era5.sh ${YYYYMM} first"
    exit 10
}

[[ -f "${WRFRUN}/namelist.input.wrf" ]] || {
    echo "ERROR: Missing ${WRFRUN}/namelist.input.wrf"
    echo "Run pre_runwrf_era5.sh ${YYYYMM} first"
    exit 10
}

[[ -f "${WRFRUN}/namelist.input" ]] || {
    echo "ERROR: Missing ${WRFRUN}/namelist.input"
    echo "Run pre_runwrf_era5.sh ${YYYYMM} first"
    exit 10
}

[[ -d "${METDIR}" ]] || {
    echo "ERROR: Missing ${METDIR}"
    echo "Run pre_runwrf_era5.sh ${YYYYMM} first"
    exit 10
}

ls "${METDIR}"/*.grib >/dev/null 2>&1 || {
    echo "ERROR: No GRIB files found in ${METDIR}"
    echo "Run pre_runwrf_era5.sh ${YYYYMM} first"
    exit 10
}

# ------------------------------------------------------------
# WPS
# ------------------------------------------------------------

cd "${WPSRUN}"

ln -sf "${WPS_DIR}/geogrid.exe" .
ln -sf "${WPS_DIR}/ungrib.exe" .
ln -sf "${WPS_DIR}/metgrid.exe" .
ln -sf "${WPS_DIR}/link_grib.csh" .

echo
echo "================================================"
echo "Running geogrid"
echo "================================================"

./geogrid.exe \
2>&1 | tee "${LOGRUN}/geogrid_${YYYYMM}.log"

echo
echo "================================================"
echo "Linking GRIB"
echo "================================================"

rm -f GRIBFILE.*

./link_grib.csh "${METDIR}"/*.grib \
2>&1 | tee "${LOGRUN}/link_grib_${YYYYMM}.log"

ln -sf \
"${WPS_DIR}/ungrib/Variable_Tables/Vtable.ECMWF" \
Vtable

echo
echo "================================================"
echo "Running ungrib"
echo "================================================"

./ungrib.exe \
2>&1 | tee "${LOGRUN}/ungrib_${YYYYMM}.log"

echo
echo "================================================"
echo "Running metgrid"
echo "================================================"

./metgrid.exe \
2>&1 | tee "${LOGRUN}/metgrid_${YYYYMM}.log"

# ------------------------------------------------------------
# WRF
# ------------------------------------------------------------

cd "${WRFRUN}"

ln -sf "${WPSRUN}/met_em.d0"* .
ln -sf "${WPSRUN}/geo_em.d0"* .

ln -sf "${WRF_DIR}/main/real.exe" .
ln -sf "${WRF_DIR}/main/wrf.exe" .

cp -n "${WRF_DIR}/run/"* . 2>/dev/null || true

read LVL SLV < <(
    python3 "${SCRIPT_DIR}/common.py" \
    metgrid_levels \
    "${WPSRUN}/met_em.d01."*
)

sed -i \
"s/METGRID_LEVELS/${LVL}/g" \
namelist.input

sed -i \
"s/METGRID_SOIL_LEVELS/${SLV}/g" \
namelist.input

echo
echo "================================================"
echo "Running REAL"
echo "================================================"

mpirun -np "${NPROC}" \
./real.exe \
2>&1 | tee "${LOGRUN}/real_${YYYYMM}.log"

cp -f namelist.input.wrf namelist.input

sed -i \
"s/METGRID_LEVELS/${LVL}/g" \
namelist.input

sed -i \
"s/METGRID_SOIL_LEVELS/${SLV}/g" \
namelist.input

echo
echo "================================================"
echo "Running WRF"
echo "================================================"

mpirun -np "${NPROC}" \
./wrf.exe \
2>&1 | tee "${LOGRUN}/wrf_${YYYYMM}.log"

echo
echo "================================================"
echo "COMPLETE"
echo "================================================"

ls -1 wrfout_d01_* >/dev/null

echo "WRF month complete: ${YYYYMM}"