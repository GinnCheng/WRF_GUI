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
# Build input file
# ============================================================

build_input_file() {

    local INPUT_FILE="$1"

    local START_TIME="$2"

    local END_TIME="$3"

    local FILELIST="$4"

    local OUTFILE="$5"

    local LOGFILE="$6"

    cp \
        "${TEMPLATE_DIR}/calwrf.inp.template" \
        "${INPUT_FILE}"

    START_YYYYMMDDHH=$(
        python "${SCRIPT_DIR}/common.py" \
            yyyymmddhh \
            "${START_TIME}"
    )

    END_YYYYMMDDHH=$(
        python "${SCRIPT_DIR}/common.py" \
            yyyymmddhh \
            "${END_TIME}"
    )

    NFILES=$(wc -l < "${FILELIST}")

    sed -i \
        -e "s|CALWRF_LOGFILE|${LOGFILE}|g" \
        -e "s|CALWRF_OUTFILE|${OUTFILE}|g" \
        -e "s|START_YYYYMMDDHH|${START_YYYYMMDDHH}|g" \
        -e "s|END_YYYYMMDDHH|${END_YYYYMMDDHH}|g" \
        -e "s|NFILES|${NFILES}|g" \
        "${INPUT_FILE}"

    TMP=$(mktemp)

    cat "${FILELIST}" > "${TMP}"

    sed -i \
        "/WRFOUT_FILES_HERE/r ${TMP}" \
        "${INPUT_FILE}"

    sed -i \
        "/WRFOUT_FILES_HERE/d" \
        "${INPUT_FILE}"

    rm -f "${TMP}"
}

# ============================================================
# Monthly
# ============================================================

run_month() {

    YYYYMM="$1"

    YEAR="${YYYYMM:0:4}"

    OUTDIR="${CALMET_DIR}/met/${YEAR}"

    mkdir -p "${OUTDIR}"

    FILELIST=$(mktemp)

    find "${RUN_DIR}/${YEAR}/${YYYYMM}/WRF" \
        -name "wrfout_${DOMAIN}_*" \
        | sort \
        > "${FILELIST}"

    if [[ ! -s "${FILELIST}" ]]
    then

        echo "ERROR: No WRF files found"

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

    INPUT_FILE="${OUTDIR}/calwrf_${YYYYMM}_${DOMAIN}.inp"

    OUTFILE="${OUTDIR}/${SITE}_${YYYYMM}_${DOMAIN}.m3d"

    LOGFILE="${OUTDIR}/calwrf_${YYYYMM}_${DOMAIN}.log"

    build_input_file \
        "${INPUT_FILE}" \
        "${FIRST_TIME}" \
        "${LAST_TIME}" \
        "${FILELIST}" \
        "${OUTFILE}" \
        "${LOGFILE}"

    echo
    echo "======================================"
    echo "Running CALWRF"
    echo "======================================"
    echo

    (
        cd "${OUTDIR}"

        "${CALWRF_EXE}" < "${INPUT_FILE}"
    ) > "${LOGFILE}" 2>&1

    echo
    echo "Generated:"
    echo "  ${OUTFILE}"
    echo

    rm -f "${FILELIST}"
}

# ============================================================
# Annual
# ============================================================

run_year() {

    YEAR="$1"

    OUTDIR="${CALMET_DIR}/met/${YEAR}"

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

    INPUT_FILE="${OUTDIR}/calwrf_${YEAR}_${DOMAIN}.inp"

    OUTFILE="${OUTDIR}/${SITE}_${YEAR}_${DOMAIN}.m3d"

    LOGFILE="${OUTDIR}/calwrf_${YEAR}_${DOMAIN}.log"

    build_input_file \
        "${INPUT_FILE}" \
        "${FIRST_TIME}" \
        "${LAST_TIME}" \
        "${FILELIST}" \
        "${OUTFILE}" \
        "${LOGFILE}"

    echo
    echo "======================================"
    echo "Running Annual CALWRF"
    echo "======================================"
    echo

    (
        cd "${OUTDIR}"

        "${CALWRF_EXE}" < "${INPUT_FILE}"
    ) > "${LOGFILE}" 2>&1

    echo
    echo "Generated:"
    echo "  ${OUTFILE}"
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