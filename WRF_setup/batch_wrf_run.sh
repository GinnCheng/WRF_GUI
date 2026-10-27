#!/usr/bin/env bash

set -euo pipefail

INIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/wrf_package" && pwd)"

source "${INIT_DIR}/config.sh"

# ============================================================
# Python Virtual Environment
# ============================================================
VENV_DIR="${ERA5_VENV}"
PY_SYS="$HOME/python310/bin/python3.10"

mkdir -p "$(dirname "${VENV_DIR}")"

if [[ ! -x "${VENV_DIR}/bin/python" ]]
then

    echo "Creating ERA5 venv at ${VENV_DIR}"

    "${PY_SYS}" -m venv "${VENV_DIR}"

fi

if ! "${VENV_DIR}/bin/python" -c "import cdsapi" >/dev/null 2>&1
then

    echo "Installing ERA5 dependencies..."

    "${VENV_DIR}/bin/python" -m pip install \
        --upgrade \
        pip setuptools wheel

    "${VENV_DIR}/bin/python" -m pip install \
        cdsapi \
        requests \
        urllib3 \
        certifi

fi

ERA5_PY="${VENV_DIR}/bin/python"

[[ -x "${ERA5_PY}" ]] || {
    echo "ERROR: ERA5 python not found: ${ERA5_PY}"
    exit 10
}

#================================================
# RUN
#================================================

while read -r YYYYMM
do

    echo "START wrfing ${YYYYMM}"

    "${SCRIPT_DIR}/pre_runwrf_era5.sh" "${YYYYMM}" < /dev/null

    "${SCRIPT_DIR}/pre_runwrf_wps.sh" "${YYYYMM}" < /dev/null

    "${SCRIPT_DIR}/run_wrf.sh" "${YYYYMM}" < /dev/null

    echo "END wrfing ${YYYYMM}"

done < <(
    "${ERA5_PY}" \
    "${SCRIPT_DIR}/common.py" \
    batch \
    "${START_YYYYMM}" \
    "${END_YYYYMM}" \
    month
)