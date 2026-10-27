#!/usr/bin/env bash

set -euo pipefail

INIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${INIT_DIR}/config.sh"


# ============================================================
# ERA5 VENV
# ============================================================

VENV_DIR="${ERA5_VENV}"
PY_SYS="$HOME/python310/bin/python3.10"

mkdir -p "$(dirname "${VENV_DIR}")"

if [[ ! -x "${VENV_DIR}/bin/python" ]]
then

    echo "Creating ERA5 venv at ${VENV_DIR}"

    "${PY_SYS}" -m venv "${VENV_DIR}"

fi

if ! "${VENV_DIR}/bin/python" -c "import netCDF4" >/dev/null 2>&1
then

    echo "Installing netCDF4..."

    "${VENV_DIR}/bin/python" -m pip install \
        --upgrade \
        pip setuptools wheel

    "${VENV_DIR}/bin/python" -m pip install \
        netCDF4

fi

ERA5_PY="${VENV_DIR}/bin/python"

[[ -x "${ERA5_PY}" ]] || {
    echo "ERROR: ERA5 python not found: ${ERA5_PY}"
    exit 10
}


# -------------------------------------------------------------
# setup paths
# -------------------------------------------------------------

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

ls -1 "${WPSRUN}/met_em.d01."*.nc >/dev/null 2>&1 || {
    echo "ERROR: No met_em.d01.*.nc in ${WPSRUN}"
    echo "Run pre_runwrf_wps.sh ${YYYYMM} first"
    exit 10
}

# ------------------------------------------------------------
# WRF
# ------------------------------------------------------------

cd "${WRFRUN}"

ln -sf "${WPSRUN}/met_em.d0"* .
ln -sf "${WPSRUN}/geo_em.d0"* .

ln -sf "${WRF_DIR}/main/real.exe" .
ln -sf "${WRF_DIR}/main/wrf.exe" .

cp -n "${WRF_DIR}/run/"* . 2>/dev/null || true

MET1=$(find "${WPSRUN}" \
    -maxdepth 1 \
    -name 'met_em.d01*.nc' \
    -print \
    -quit)

if [[ -z "${MET1}" ]]; then
    echo "ERROR: No met_em.d01*.nc found in ${WPSRUN}"
    exit 10
fi

echo "Using MET1=${MET1}"

read LVL SLV < <(
    "${ERA5_PY}" \
    "${SCRIPT_DIR}/common.py" \
    metgrid_levels \
    "${MET1}"
)




echo "Detected LVL=${LVL} SLV=${SLV}"

[[ -n "${LVL}" ]] || {
    echo "ERROR: Failed to determine num_metgrid_levels"
    exit 10
}

[[ -n "${SLV}" ]] || {
    echo "ERROR: Failed to determine num_metgrid_soil_levels"
    exit 10
}

for f in \
    namelist.input \
    namelist.input.real \
    namelist.input.wrf
do

    sed -i \
    "s/METGRID_LEVELS/${LVL}/g" \
    "$f"

    sed -i \
    "s/METGRID_SOIL_LEVELS/${SLV}/g" \
    "$f"

done


cp -f namelist.input.real namelist.input

echo
echo "================================================"
echo "Running REAL"
echo "================================================"

mpirun -np "${NPROC}" \
./real.exe \
2>&1 | tee "${LOGRUN}/real_${YYYYMM}.log"


[[ -s wrfinput_d01 ]] || {
    echo "ERROR: real.exe did not create wrfinput_d01"
    exit 10
}

[[ -s wrfbdy_d01 ]] || {
    echo "ERROR: real.exe did not create wrfbdy_d01"
    exit 10
}


echo
echo "================================================"
echo "Running WRF"
echo "================================================"

cp -f namelist.input.wrf namelist.input

mpirun -np "${NPROC}" \
./wrf.exe \
2>&1 | tee "${LOGRUN}/wrf_${YYYYMM}.log"

echo
echo "================================================"
echo "COMPLETE"
echo "================================================"

ls -1 wrfout_d01_* >/dev/null

echo "WRF month complete: ${YYYYMM}"