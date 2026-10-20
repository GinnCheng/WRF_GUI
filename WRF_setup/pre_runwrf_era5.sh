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

# ============================================================
# ERA5 ENVIRONMENT FOR DOWNLOAD SCRIPT
# ============================================================

export ERA5_USE_AREA
export BBOX_NORTH
export BBOX_WEST
export BBOX_SOUTH
export BBOX_EAST
export BBOX_BUFFER_DEG



# ============================================================
# functions
# ============================================================

usage() {

    echo "Usage: $0 YYYYMM"

    exit 1
}

[[ $# -eq 1 ]] || usage

YYYYMM="$1"

[[ "${YYYYMM}" =~ ^[0-9]{6}$ ]] || usage

YEAR="${YYYYMM:0:4}"
MONTH="${YYYYMM:4:2}"

RUNROOT="${RUN_DIR}/${YEAR}/${YYYYMM}"

WPSRUN="${RUNROOT}/WPS"
WRFRUN="${RUNROOT}/WRF"
LOGRUN="${RUNROOT}/logs"

METDIR="${ROOT}/02_met_data/${YEAR}/${YYYYMM}"

mkdir -p "${WPSRUN}"
mkdir -p "${WRFRUN}"
mkdir -p "${LOGRUN}"
mkdir -p "${METDIR}"

# ============================================================
# Time Windows
# ============================================================

WINDOW_JSON=$(
    python3 "${SCRIPT_DIR}/common.py" \
        month_window \
        "${YEAR}" \
        "${MONTH}" \
        "${TZ_OFFSET_HR}"
)

START_DATE_UTC=$(echo "$WINDOW_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["start_date_utc"])')
END_DATE_UTC=$(echo "$WINDOW_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["end_date_utc"])')
REAL_END_DATE_UTC=$(echo "$WINDOW_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["real_end_date_utc"])')
WPS_START_DATE_UTC=$(echo "$WINDOW_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["wps_start_date_utc"])')
WPS_END_DATE_UTC=$(echo "$WINDOW_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["wps_end_date_utc"])')

echo
echo "================================================"
echo "Month : ${YYYYMM}"
echo "================================================"
echo "Sim Start : ${START_DATE_UTC}"
echo "Sim End   : ${END_DATE_UTC}"
echo "Real End  : ${REAL_END_DATE_UTC}"
echo "WPS Start : ${WPS_START_DATE_UTC}"
echo "WPS End   : ${WPS_END_DATE_UTC}"
echo

# ============================================================
# Required ERA5 Months
# ============================================================

NEEDED_MONTHS=$(
    python3 "${SCRIPT_DIR}/common.py" \
        required_months \
        "${WPS_START_DATE_UTC}" \
        "${WPS_END_DATE_UTC}"
)

echo "Required ERA5 months:"
echo "${NEEDED_MONTHS}"
echo

# ============================================================
# ERA5 Validation
# ============================================================

declare -a MISSING_MONTHS=()

for TAG in ${NEEDED_MONTHS}
do

    YR="${TAG:0:4}"

    PL="${ERA5_STORE}/${YR}/era5_pl_${TAG}.grib"
    SFC="${ERA5_STORE}/${YR}/era5_sfc_${TAG}.grib"

    if [[ ! -s "${PL}" || ! -s "${SFC}" ]]
    then
        MISSING_MONTHS+=("${TAG}")
    fi

done

INV="${ERA5_STORE}/${YEAR}/era5_invariant.grib"

if [[ ${#MISSING_MONTHS[@]} -eq 0 && -s "${INV}" ]]
then

    echo
    echo "All required ERA5 files already exist."
    echo "Skipping ERA5 retrieval."
    echo

else

    echo
    echo "Missing ERA5 files detected."
    echo

    MODE="${ERA5_DOWNLOAD_MODE:-download}"

    for TAG in "${MISSING_MONTHS[@]}"
    do

        YR="${TAG:0:4}"
        MO="${TAG:4:2}"

        echo
        echo "Retrieving ERA5 ${TAG}"
        echo

        if [[ "${MODE}" == "submit_only" ]]
        then

            "${ERA5_PY}" \
                "${SCRIPT_DIR}/python_scripts/era5_download_month.py" \
                "${YR}" \
                "${MO}" \
                "${ERA5_STORE}/${YR}" \
                --submit-only

        else

            "${ERA5_PY}" \
                "${SCRIPT_DIR}/python_scripts/era5_download_month.py" \
                "${YR}" \
                "${MO}" \
                "${ERA5_STORE}/${YR}"

        fi

    done

    if [[ "${MODE}" == "submit_only" ]]
    then

        echo
        echo "ERA5 requests submitted."
        echo "Download the GRIB files and rerun."
        echo

        exit 0

    fi

fi

# ============================================================
# Link ERA5 Files
# ============================================================

for TAG in ${NEEDED_MONTHS}
do

    YR="${TAG:0:4}"

    ln -sf \
        "${ERA5_STORE}/${YR}/era5_pl_${TAG}.grib" \
        "${METDIR}/"

    ln -sf \
        "${ERA5_STORE}/${YR}/era5_sfc_${TAG}.grib" \
        "${METDIR}/"

done

ln -sf \
    "${INV}" \
    "${METDIR}/era5_invariant.grib"

# ============================================================
# Render namelist.wps
# ============================================================

sed \
-e "s/START_DATE/${WPS_START_DATE_UTC}/g" \
-e "s/END_DATE/${WPS_END_DATE_UTC}/g" \
"${TEMPLATE_DIR}/namelist.wps.template" \
> "${WPSRUN}/namelist.wps"

# ============================================================
# Date Components
# ============================================================

START_YEAR=$(echo "${START_DATE_UTC}" | cut -c1-4)
START_MONTH=$(echo "${START_DATE_UTC}" | cut -c6-7)
START_DAY=$(echo "${START_DATE_UTC}" | cut -c9-10)
START_HOUR=$(echo "${START_DATE_UTC}" | cut -c12-13)

END_YEAR=$(echo "${END_DATE_UTC}" | cut -c1-4)
END_MONTH=$(echo "${END_DATE_UTC}" | cut -c6-7)
END_DAY=$(echo "${END_DATE_UTC}" | cut -c9-10)
END_HOUR=$(echo "${END_DATE_UTC}" | cut -c12-13)

REAL_END_YEAR=$(echo "${REAL_END_DATE_UTC}" | cut -c1-4)
REAL_END_MONTH=$(echo "${REAL_END_DATE_UTC}" | cut -c6-7)
REAL_END_DAY=$(echo "${REAL_END_DATE_UTC}" | cut -c9-10)
REAL_END_HOUR=$(echo "${REAL_END_DATE_UTC}" | cut -c12-13)

# ============================================================
# namelist.input.real
# ============================================================

sed \
-e "s/START_YYYY/${START_YEAR}/g" \
-e "s/START_MM/${START_MONTH}/g" \
-e "s/START_DD/${START_DAY}/g" \
-e "s/START_HH/${START_HOUR}/g" \
-e "s/END_YYYY/${REAL_END_YEAR}/g" \
-e "s/END_MM/${REAL_END_MONTH}/g" \
-e "s/END_DD/${REAL_END_DAY}/g" \
-e "s/END_HH/${REAL_END_HOUR}/g" \
"${TEMPLATE_DIR}/namelist.input.template" \
> "${WRFRUN}/namelist.input.real"

# ============================================================
# namelist.input.wrf
# ============================================================

sed \
-e "s/START_YYYY/${START_YEAR}/g" \
-e "s/START_MM/${START_MONTH}/g" \
-e "s/START_DD/${START_DAY}/g" \
-e "s/START_HH/${START_HOUR}/g" \
-e "s/END_YYYY/${END_YEAR}/g" \
-e "s/END_MM/${END_MONTH}/g" \
-e "s/END_DD/${END_DAY}/g" \
-e "s/END_HH/${END_HOUR}/g" \
"${TEMPLATE_DIR}/namelist.input.template" \
> "${WRFRUN}/namelist.input.wrf"

cp -f \
"${WRFRUN}/namelist.input.real" \
"${WRFRUN}/namelist.input"

echo
echo "Preparation complete"
echo
echo "Created:"
echo "  ${WPSRUN}/namelist.wps"
echo "  ${WRFRUN}/namelist.input.real"
echo "  ${WRFRUN}/namelist.input.wrf"
echo
echo "ERA5 linked into:"
echo "  ${METDIR}"
echo