#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/config.sh"


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



cd "${WPSRUN}"

echo "${WPSRUN}"

METFILE=$(ls met_em.d01*.nc | head -1)

echo "$METFILE"

"${ERA5_PY}" \
"${SCRIPT_DIR}/common.py" \
metgrid_levels \
"$METFILE"
