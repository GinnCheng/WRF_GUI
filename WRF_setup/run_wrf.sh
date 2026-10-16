#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

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
mkdir -p "${METDIR}"
mkdir -p "${LOGRUN}"

# ------------------------------------------------------------
# Create templates
# ------------------------------------------------------------

if [[ ! -f "${TEMPLATE_DIR}/namelist.wps.template" ]]; then
    bash "${SCRIPT_DIR}/templates.sh"
fi

# ------------------------------------------------------------
# Calculate time windows
# ------------------------------------------------------------

WINDOW_JSON=$(
    python3 "${SCRIPT_DIR}/common.py" \
        month_window \
        "${YEAR}" \
        "${MONTH}" \
        "${TZ_OFFSET_HR}"
)

START_DATE_UTC=$(echo "$WINDOW_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["start_date_utc"])')
END_DATE_UTC=$(echo "$WINDOW_JSON"   | python3 -c 'import sys,json;print(json.load(sys.stdin)["end_date_utc"])')
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

# ------------------------------------------------------------
# Determine required ERA5 months
# ------------------------------------------------------------

NEEDED_MONTHS=$(
    python3 "${SCRIPT_DIR}/common.py" \
        required_months \
        "${WPS_START_DATE_UTC}" \
        "${WPS_END_DATE_UTC}"
)

echo "Required ERA5 months:"
echo "${NEEDED_MONTHS}"
echo

# ------------------------------------------------------------
# Check ERA5 files
# ------------------------------------------------------------

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

    echo "ERROR: Missing ERA5 files"

    for f in "${MISSING[@]}"
    do
        echo "   ${f}"
    done

    exit 10

fi

# ------------------------------------------------------------
# Link ERA5 files
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Render namelist.wps
# ------------------------------------------------------------

sed \
    -e "s/START_DATE/${WPS_START_DATE_UTC}/g" \
    -e "s/END_DATE/${WPS_END_DATE_UTC}/g" \
    "${TEMPLATE_DIR}/namelist.wps.template" \
    > "${WPSRUN}/namelist.wps"

# ------------------------------------------------------------
# Render WRF namelist files
# ------------------------------------------------------------

START_YEAR=$(echo "${START_DATE_UTC}" | cut -c1-4)
START_MONTH2=$(echo "${START_DATE_UTC}" | cut -c6-7)
START_DAY=$(echo "${START_DATE_UTC}" | cut -c9-10)
START_HOUR=$(echo "${START_DATE_UTC}" | cut -c12-13)

END_YEAR=$(echo "${END_DATE_UTC}" | cut -c1-4)
END_MONTH2=$(echo "${END_DATE_UTC}" | cut -c6-7)
END_DAY=$(echo "${END_DATE_UTC}" | cut -c9-10)
END_HOUR=$(echo "${END_DATE_UTC}" | cut -c12-13)

REAL_END_YEAR=$(echo "${REAL_END_DATE_UTC}" | cut -c1-4)
REAL_END_MONTH=$(echo "${REAL_END_DATE_UTC}" | cut -c6-7)
REAL_END_DAY=$(echo "${REAL_END_DATE_UTC}" | cut -c9-10)
REAL_END_HOUR=$(echo "${REAL_END_DATE_UTC}" | cut -c12-13)

sed \
-e "s/START_YYYY/${START_YEAR}/g" \
-e "s/START_MM/${START_MONTH2}/g" \
-e "s/START_DD/${START_DAY}/g" \
-e "s/START_HH/${START_HOUR}/g" \
-e "s/END_YYYY/${REAL_END_YEAR}/g" \
-e "s/END_MM/${REAL_END_MONTH}/g" \
-e "s/END_DD/${REAL_END_DAY}/g" \
-e "s/END_HH/${REAL_END_HOUR}/g" \
"${TEMPLATE_DIR}/namelist.input.template" \
> "${WRFRUN}/namelist.input.real"

sed \
-e "s/START_YYYY/${START_YEAR}/g" \
-e "s/START_MM/${START_MONTH2}/g" \
-e "s/START_DD/${START_DAY}/g" \
-e "s/START_HH/${START_HOUR}/g" \
-e "s/END_YYYY/${END_YEAR}/g" \
-e "s/END_MM/${END_MONTH2}/g" \
-e "s/END_DD/${END_DAY}/g" \
-e "s/END_HH/${END_HOUR}/g" \
"${TEMPLATE_DIR}/namelist.input.template" \
> "${WRFRUN}/namelist.input.wrf"

cp -f \
"${WRFRUN}/namelist.input.real" \
"${WRFRUN}/namelist.input"

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