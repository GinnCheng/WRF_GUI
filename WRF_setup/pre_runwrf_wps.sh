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
LOGRUN="${RUNROOT}/logs"
METDIR="${ROOT}/02_met_data/${YEAR}/${YYYYMM}"

mkdir -p "${LOGRUN}"

[[ -s "${WPSRUN}/namelist.wps" ]] || {
    echo "ERROR: Missing ${WPSRUN}/namelist.wps"
    echo "Run pre_runwrf_era5.sh ${YYYYMM} first"
    exit 10
}

[[ -d "${METDIR}" ]] || {
    echo "ERROR: Missing ${METDIR}"
    exit 10
}

cd "${WPSRUN}"

ln -sf "${WPS_DIR}/geogrid.exe" .
ln -sf "${WPS_DIR}/ungrib.exe" .
ln -sf "${WPS_DIR}/metgrid.exe" .
ln -sf "${WPS_DIR}/link_grib.csh" .

# ------------------------------------------------------------
# geogrid
# ------------------------------------------------------------

if [[ -s geo_em.d01.nc ]]; then

    echo "geogrid: geo_em.d01.nc exists -> skipping" \
    | tee "${LOGRUN}/geogrid_${YYYYMM}.log"

else

    ./geogrid.exe \
    2>&1 | tee "${LOGRUN}/geogrid_${YYYYMM}.log"

fi

[[ -s geo_em.d01.nc ]] || {
    echo "ERROR: geo_em.d01.nc not produced"
    exit 10
}

# ------------------------------------------------------------
# Link GRIB
# ------------------------------------------------------------

rm -f GRIBFILE.*

./link_grib.csh "${METDIR}"/*.grib \
2>&1 | tee "${LOGRUN}/link_grib_${YYYYMM}.log"

NLINK=$(ls -1 GRIBFILE.* 2>/dev/null | wc -l || true)

[[ "${NLINK}" -gt 0 ]] || {
    echo "ERROR: link_grib created no GRIBFILE.*"
    exit 10
}

# ------------------------------------------------------------
# Vtable
# ------------------------------------------------------------

rm -f Vtable

ln -sf \
"${WPS_DIR}/ungrib/Variable_Tables/Vtable.ECMWF" \
Vtable

[[ -s Vtable ]] || {
    echo "ERROR: Failed to create Vtable"
    exit 10
}

# ------------------------------------------------------------
# ungrib
# ------------------------------------------------------------

rm -f FILE:* PFILE:* ungrib.log

./ungrib.exe \
2>&1 | tee "${LOGRUN}/ungrib_${YYYYMM}.log"

# ------------------------------------------------------------
# metgrid
# ------------------------------------------------------------

rm -f met_em.d0*.nc metgrid.log

./metgrid.exe \
2>&1 | tee "${LOGRUN}/metgrid_${YYYYMM}.log"

NMET=$(ls -1 met_em.d01.*.nc 2>/dev/null | wc -l || true)

[[ "${NMET}" -gt 0 ]] || {
    echo "ERROR: metgrid produced no met_em.d01.*.nc"
    exit 10
}

echo "WPS complete for ${YYYYMM}"