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
    python3 common.py \
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
    python3 common.py \
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

declare -a MISSING

for TAG in ${NEEDED_MONTHS}
do

    YR="${TAG:0:4}"

    PL="${ERA5_STORE}/${YR}/era5_pl_${TAG}.grib"

    SFC="${ERA5_STORE}/${YR}/era5_sfc_${TAG}.grib"

    [[ -s "${PL}" ]] || MISSING+=("${PL}")

    [[ -s "${SFC}" ]] || MISSING+=("${SFC}")

done

INV="${ERA5_STORE}/${YEAR}/era5_invariant.grib"

[[ -s "${INV}" ]] || MISSING+=("${INV}")

if [[ ${#MISSING[@]} -gt 0 ]]
then

    echo
    echo "Missing ERA5 files detected."
    echo "Attempting retrieval..."
    echo

    for TAG in ${NEEDED_MONTHS}
    do

        YR="${TAG:0:4}"
        MO="${TAG:4:2}"

        PL="${ERA5_STORE}/${YR}/era5_pl_${TAG}.grib"
        SFC="${ERA5_STORE}/${YR}/era5_sfc_${TAG}.grib"

        mkdir -p "${ERA5_STORE}/${YR}"

        if [[ ! -s "${PL}" || ! -s "${SFC}" ]]
        then

            echo "Requesting ERA5 ${TAG}"

            "${ERA5_PY}" \
                "${SCRIPT_DIR}/era5_download_month.py" \
                "${YR}" \
                "${MO}" \
                "${ERA5_STORE}/${YR}"

        fi

    done

    INV="${ERA5_STORE}/${YEAR}/era5_invariant.grib"

    echo
    echo "Rechecking ERA5 inventory..."
    echo

    MISSING=()

    for TAG in ${NEEDED_MONTHS}
    do

        YR="${TAG:0:4}"

        PL="${ERA5_STORE}/${YR}/era5_pl_${TAG}.grib"
        SFC="${ERA5_STORE}/${YR}/era5_sfc_${TAG}.grib"

        [[ -s "${PL}" ]] || MISSING+=("${PL}")
        [[ -s "${SFC}" ]] || MISSING+=("${SFC}")

    done

    [[ -s "${INV}" ]] || MISSING+=("${INV}")

    if [[ ${#MISSING[@]} -gt 0 ]]
    then

        echo
        echo "ERROR: ERA5 still missing after retrieval attempt"
        echo

        for f in "${MISSING[@]}"
        do
            echo "  ${f}"
        done

        exit 10

    fi

fi

# ============================================================
# Link ERA5 Files
# ============================================================

rm -f "${METDIR}"/*.grib

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