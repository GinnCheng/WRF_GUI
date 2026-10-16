#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

usage() {

    echo
    echo "Usage:"
    echo "  $0 month YYYYMM [domain]"
    echo "  $0 year  YYYY   [domain]"
    echo

    exit 1
}

[[ $# -ge 2 ]] || usage

MODE="$1"

TAG="$2"

DOMAIN="${3:-${DEFAULT_DOMAIN}}"

# ============================================================
# Helpers
# ============================================================

build_control_file() {

    local CTRL="$1"

    local START="$2"

    local END="$3"

    local FILELIST="$4"

    local SFC_OUT="$5"

    local PFL_OUT="$6"

    cp \
        "${TEMPLATE_DIR}/mmif.aermod.ctrl.template" \
        "${CTRL}"

    START_LST=$(
        python "${SCRIPT_DIR}/common.py" \
            lst \
            "${START}" \
            "${TZ_OFFSET_HR}"
    )

    END_LST=$(
        python "${SCRIPT_DIR}/common.py" \
            lst \
            "${END}" \
            "${TZ_OFFSET_HR}"
    )

    read SYYYY SMM SDD SHH <<< "${START_LST}"

    read EYYYY EMM EDD EHH <<< "${END_LST}"

    sed -i \
        -e "s/START_YYYY/${SYYYY}/g" \
        -e "s/START_MM/${SMM}/g" \
        -e "s/START_DD/${SDD}/g" \
        -e "s/START_HH/${SHH}/g" \
        "${CTRL}"

    sed -i \
        -e "s/STOP_YYYY/${EYYYY}/g" \
        -e "s/STOP_MM/${EMM}/g" \
        -e "s/STOP_DD/${EDD}/g" \
        -e "s/STOP_HH/${EHH}/g" \
        "${CTRL}"

    sed -i \
        -e "s/TZ_OFFSET_HR/${TZ_OFFSET_HR}/g" \
        -e "s/SITE_LAT/${SITE_LAT}/g" \
        -e "s/SITE_LON/${SITE_LON}/g" \
        "${CTRL}"

    sed -i \
        -e "s|OUT_SFC|${SFC_OUT}|g" \
        -e "s|OUT_PFL|${PFL_OUT}|g" \
        "${CTRL}"

    TMP=$(mktemp)

    while read -r F
    do

        echo "INPUT ${F}" >> "${TMP}"

    done < "${FILELIST}"

    sed -i \
        "/INPUT_FILES_HERE/r ${TMP}" \
        "${CTRL}"

    sed -i \
        "/INPUT_FILES_HERE/d" \
        "${CTRL}"

    rm -f "${TMP}"
}

# ============================================================
# Monthly MMIF
# ============================================================

run_month() {

    YYYYMM="$1"

    YEAR="${YYYYMM:0:4}"

    WRFDIR="${RUN_DIR}/${YEAR}/${YYYYMM}/WRF"

    OUTDIR="${AERMOD_DIR}/met/${YEAR}"

    mkdir -p "${OUTDIR}"

    FILELIST=$(mktemp)

    find "${WRFDIR}" \
        -name "wrfout_${DOMAIN}_*" \
        | sort \
        > "${FILELIST}"

    if [[ ! -s "${FILELIST}" ]]
    then

        echo "ERROR: No WRF outputs found"

        exit 1

    fi

    FIRST_FILE=$(head -n 1 "${FILELIST}")

    LAST_FILE=$(tail -n 1 "${FILELIST}")

    FIRST_TIME=$(
        python "${SCRIPT_DIR}/common.py" \
            wrf_times \
            "${FIRST_FILE}" \
        | head -n 1
    )

    LAST_TIME=$(
        python "${SCRIPT_DIR}/common.py" \
            wrf_times \
            "${LAST_FILE}" \
        | tail -n 1
    )

    CTRL="${OUTDIR}/mmif_${YYYYMM}_${DOMAIN}.ctrl"

    SFC_OUT="${OUTDIR}/${SITE}_${YYYYMM}_${DOMAIN}.SFC"

    PFL_OUT="${OUTDIR}/${SITE}_${YYYYMM}_${DOMAIN}.PFL"

    build_control_file \
        "${CTRL}" \
        "${FIRST_TIME}" \
        "${LAST_TIME}" \
        "${FILELIST}" \
        "${SFC_OUT}" \
        "${PFL_OUT}"

    echo
    echo "======================================"
    echo "Running MMIF"
    echo "======================================"
    echo

    "${MMIF_EXE}" "${CTRL}" \
        > "${OUTDIR}/mmif_${YYYYMM}_${DOMAIN}.log" \
        2>&1

    echo
    echo "Generated:"
    echo "  ${SFC_OUT}"
    echo "  ${PFL_OUT}"
    echo

    rm -f "${FILELIST}"
}

# ============================================================
# Annual MMIF
# ============================================================

run_year() {

    YEAR="$1"

    OUTDIR="${AERMOD_DIR}/met/${YEAR}"

    mkdir -p "${OUTDIR}"

    FILELIST=$(mktemp)

    find "${RUN_DIR}/${YEAR}" \
        -path "*WRF/wrfout_${DOMAIN}_*" \
        | sort \
        > "${FILELIST}"

    if [[ ! -s "${FILELIST}" ]]
    then

        echo "ERROR: No annual WRF outputs found"

        exit 1

    fi

    FIRST_FILE=$(head -n 1 "${FILELIST}")

    LAST_FILE=$(tail -n 1 "${FILELIST}")

    FIRST_TIME=$(
        python "${SCRIPT_DIR}/common.py" \
            wrf_times \
            "${FIRST_FILE}" \
        | head -n 1
    )

    LAST_TIME=$(
        python "${SCRIPT_DIR}/common.py" \
            wrf_times \
            "${LAST_FILE}" \
        | tail -n 1
    )

    CTRL="${OUTDIR}/mmif_${YEAR}_${DOMAIN}.ctrl"

    SFC_OUT="${OUTDIR}/${SITE}_${YEAR}_${DOMAIN}.SFC"

    PFL_OUT="${OUTDIR}/${SITE}_${YEAR}_${DOMAIN}.PFL"

    build_control_file \
        "${CTRL}" \
        "${FIRST_TIME}" \
        "${LAST_TIME}" \
        "${FILELIST}" \
        "${SFC_OUT}" \
        "${PFL_OUT}"

    echo
    echo "======================================"
    echo "Running Annual MMIF"
    echo "======================================"
    echo

    "${MMIF_EXE}" "${CTRL}" \
        > "${OUTDIR}/mmif_${YEAR}_${DOMAIN}.log" \
        2>&1

    echo
    echo "Generated:"
    echo "  ${SFC_OUT}"
    echo "  ${PFL_OUT}"
    echo

    rm -f "${FILELIST}"
}

# ============================================================
# Main
# ============================================================

case "${MODE}" in

    month)

        run_month "${TAG}"
        ;;

    year)

        run_year "${TAG}"
        ;;

    *)

        usage
        ;;

esac