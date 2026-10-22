#!/usr/bin/env python3

import sys
import json

from datetime import datetime
from datetime import timedelta

try:
    from netCDF4 import Dataset
except ImportError:
    Dataset = None


# ============================================================
# TIME UTILITIES
# ============================================================

def floor_to_6h(dt):

    hour = (dt.hour // 6) * 6

    return dt.replace(
        hour=hour,
        minute=0,
        second=0,
        microsecond=0
    )


def ceil_to_6h(dt):

    if (
        dt.minute == 0 and
        dt.second == 0 and
        dt.hour % 6 == 0
    ):
        return dt

    return floor_to_6h(dt) + timedelta(hours=6)


def calculate_month_window(
    year,
    month,
    tz_offset
):

    local_start = datetime(
        year,
        month,
        1,
        0,
        0,
        0
    )

    if month == 12:

        local_end = datetime(
            year + 1,
            1,
            1,
            0,
            0,
            0
        )

    else:

        local_end = datetime(
            year,
            month + 1,
            1,
            0,
            0,
            0
        )

    utc_start = local_start - timedelta(hours=tz_offset)

    utc_end = local_end - timedelta(hours=tz_offset)

    real_end = utc_end + timedelta(hours=1)

    wps_start = floor_to_6h(utc_start)

    wps_end = ceil_to_6h(real_end)

    return {

        "start_date_utc":
            utc_start.strftime("%Y-%m-%d_%H:%M:%S"),

        "end_date_utc":
            utc_end.strftime("%Y-%m-%d_%H:%M:%S"),

        "real_end_date_utc":
            real_end.strftime("%Y-%m-%d_%H:%M:%S"),

        "wps_start_date_utc":
            wps_start.strftime("%Y-%m-%d_%H:%M:%S"),

        "wps_end_date_utc":
            wps_end.strftime("%Y-%m-%d_%H:%M:%S")
    }


# ============================================================
# ERA5 MONTHS REQUIRED
# ============================================================

def required_era5_months(
    start_string,
    end_string
):

    start = datetime.strptime(
        start_string,
        "%Y-%m-%d_%H:%M:%S"
    )

    end = datetime.strptime(
        end_string,
        "%Y-%m-%d_%H:%M:%S"
    )

    current = datetime(
        start.year,
        start.month,
        1
    )

    finish = datetime(
        end.year,
        end.month,
        1
    )

    months = []

    while current <= finish:

        months.append(
            f"{current.year}{current.month:02d}"
        )

        if current.month == 12:

            current = datetime(
                current.year + 1,
                1,
                1
            )

        else:

            current = datetime(
                current.year,
                current.month + 1,
                1
            )

    return months


# ============================================================
# WRF UTILITIES
# ============================================================

def get_first_last_wrf_time(wrf_file):

    if Dataset is None:

        raise RuntimeError(
            "netCDF4 is not installed"
        )

    ds = Dataset(wrf_file)

    try:

        times = [

            ''.join(
                row.astype(str)
            ).strip()

            for row in ds.variables["Times"][:]

        ]

        return (
            times[0],
            times[-1]
        )

    finally:

        ds.close()


def utc_to_lst(
    utc_timestring,
    offset
):

    dt = datetime.strptime(
        utc_timestring,
        "%Y-%m-%d_%H:%M:%S"
    )

    dt += timedelta(hours=offset)

    return dt.strftime(
        "%Y %m %d %H"
    )


def utc_to_yyyymmddhh(
    utc_timestring
):

    dt = datetime.strptime(
        utc_timestring,
        "%Y-%m-%d_%H:%M:%S"
    )

    return dt.strftime(
        "%Y%m%d%H"
    )


# ============================================================
# METGRID UTILITIES
# ============================================================

def get_metgrid_levels(
    met_file
):

    if Dataset is None:

        raise RuntimeError(
            "netCDF4 is not installed"
        )

    ds = Dataset(met_file)

    try:

        levels = len(
            ds.dimensions["num_metgrid_levels"]
        )

        soil_levels = getattr(
            ds,
            "NUM_METGRID_SOIL_LEVELS",
            ""
        )

        return (
            str(levels).strip(),
            str(soil_levels).strip()
        )

    finally:

        ds.close()


# ============================================================
# CLI
# ============================================================

def cmd_month_window():

    year = int(sys.argv[2])

    month = int(sys.argv[3])

    tz_offset = int(sys.argv[4])

    result = calculate_month_window(
        year,
        month,
        tz_offset
    )

    print(
        json.dumps(
            result,
            indent=2
        )
    )


def cmd_required_months():

    months = required_era5_months(
        sys.argv[2],
        sys.argv[3]
    )

    print(
        " ".join(months)
    )


def cmd_wrf_times():

    first, last = get_first_last_wrf_time(
        sys.argv[2]
    )

    print(first)
    print(last)


def cmd_lst():

    print(
        utc_to_lst(
            sys.argv[2],
            int(sys.argv[3])
        )
    )


def cmd_yyyymmddhh():

    print(
        utc_to_yyyymmddhh(
            sys.argv[2]
        )
    )


def cmd_metgrid_levels():

    levels, soil_levels = get_metgrid_levels(
        sys.argv[2]
    )

    print(
        levels,
        soil_levels
    )


def main():

    if len(sys.argv) < 2:

        sys.exit(
            "Usage: python common.py COMMAND ..."
        )

    command = sys.argv[1]

    if command == "month_window":
        cmd_month_window()

    elif command == "required_months":
        cmd_required_months()

    elif command == "wrf_times":
        cmd_wrf_times()

    elif command == "lst":
        cmd_lst()

    elif command == "yyyymmddhh":
        cmd_yyyymmddhh()

    elif command == "metgrid_levels":
        cmd_metgrid_levels()

    else:

        sys.exit(
            f"Unknown command: {command}"
        )


if __name__ == "__main__":

    main()