import os
import sys
import json
import calendar

try:
    import cdsapi
except ImportError:
    print("ERROR: cdsapi not installed. Install in your venv: pip install 'cdsapi>=0.7.7'", file=sys.stderr)
    sys.exit(2)

TIMES_6H = ['00:00', '06:00', '12:00', '18:00']


def use_area_from_env() -> bool:
    v = os.environ.get('ERA5_USE_AREA', 'true').strip().lower()
    return v not in ('0', 'false', 'no', 'off')


def area_from_env():
    north = float(os.environ['BBOX_NORTH'])
    west = float(os.environ['BBOX_WEST'])
    south = float(os.environ['BBOX_SOUTH'])
    east = float(os.environ['BBOX_EAST'])
    buf = float(os.environ.get('BBOX_BUFFER_DEG', '0'))
    return [north + buf, west - buf, south - buf, east + buf]


def extract_request_id(obj):
    for attr in ('request_id', 'id'):
        if hasattr(obj, attr) and getattr(obj, attr):
            return str(getattr(obj, attr))
    if hasattr(obj, 'reply') and isinstance(obj.reply, dict):
        for k in ('request_id', 'id'):
            if k in obj.reply:
                return str(obj.reply[k])
    return None


def extract_location(obj):
    if hasattr(obj, 'location') and getattr(obj, 'location'):
        return str(getattr(obj, 'location'))
    if hasattr(obj, 'reply') and isinstance(obj.reply, dict) and 'location' in obj.reply:
        return str(obj.reply['location'])
    return None


def submit_or_download(client, dataset, request, target_path, submit_only, meta_list, tag):
    if submit_only:
        res = client.retrieve(dataset, request)
        meta_list.append({
            'tag': tag,
            'dataset': dataset,
            'request_id': extract_request_id(res),
            'location': extract_location(res),
            'suggested_filename': os.path.basename(target_path),
        })
        return
    client.retrieve(dataset, request, target_path)


def main():
    argv = sys.argv[1:]
    submit_only = False
    if '--submit-only' in argv:
        submit_only = True
        argv.remove('--submit-only')

    if len(argv) != 3:
        print('Usage: era5_download_month.py YYYY MM OUTDIR [--submit-only]', file=sys.stderr)
        sys.exit(1)

    year = int(argv[0])
    month = int(argv[1])
    outdir = argv[2]
    os.makedirs(outdir, exist_ok=True)

    yyyymm = f"{year}{month:02d}"
    pl_file = os.path.join(outdir, f"era5_pl_{yyyymm}.grib")
    sfc_file = os.path.join(outdir, f"era5_sfc_{yyyymm}.grib")
    inv_file = os.path.join(outdir, 'era5_invariant.grib')
    meta_file = os.path.join(outdir, f"era5_requests_{yyyymm}.json")

    ndays = calendar.monthrange(year, month)[1]
    days = [f"{d:02d}" for d in range(1, ndays + 1)]

    area = area_from_env() if use_area_from_env() else None

    c = cdsapi.Client()

    meta = {
        'yyyymm': yyyymm,
        'submit_only': submit_only,
        'submitted': [],
        'expected_files': [os.path.basename(pl_file), os.path.basename(sfc_file), os.path.basename(inv_file)],
    }

    pl_req = {
        'product_type': 'reanalysis',
        'variable': ['geopotential', 'temperature', 'relative_humidity', 'u_component_of_wind', 'v_component_of_wind'],
        'pressure_level': [
            '1000','975','950','925','900','875','850','825','800','775','750',
            '700','650','600','550','500','450','400','350','300','250','225',
            '200','175','150','125','100','70','50','30','20','10'
        ],
        'year': f"{year}",
        'month': f"{month:02d}",
        'day': days,
        'time': TIMES_6H,
        'data_format': 'grib',
    }
    if area is not None:
        pl_req['area'] = area

    sfc_req = {
        'product_type': 'reanalysis',
        'variable': [
            '10m_u_component_of_wind', '10m_v_component_of_wind', '2m_temperature', '2m_dewpoint_temperature',
            'surface_pressure', 'mean_sea_level_pressure', 'skin_temperature', 'sea_surface_temperature',
            'sea_ice_cover', 'snow_depth', 'soil_temperature_level_1', 'soil_temperature_level_2',
            'soil_temperature_level_3', 'soil_temperature_level_4', 'volumetric_soil_water_layer_1',
            'volumetric_soil_water_layer_2', 'volumetric_soil_water_layer_3', 'volumetric_soil_water_layer_4'
        ],
        'year': f"{year}",
        'month': f"{month:02d}",
        'day': days,
        'time': TIMES_6H,
        'data_format': 'grib',
    }
    if area is not None:
        sfc_req['area'] = area

    submit_or_download(c, 'reanalysis-era5-pressure-levels', pl_req, pl_file, submit_only, meta['submitted'], 'pl')
    submit_or_download(c, 'reanalysis-era5-single-levels', sfc_req, sfc_file, submit_only, meta['submitted'], 'sfc')

    # Invariants are time-independent; download once if missing.
    if not (os.path.exists(inv_file) and os.path.getsize(inv_file) > 0):
        inv_req = {
            'product_type': 'reanalysis',
            'variable': ['land_sea_mask', 'geopotential'],
            'date': ['2020-01-01/2020-01-01'],
            'time': ['00:00'],
            'data_format': 'grib',
        }
        if area is not None:
            inv_req['area'] = area
        submit_or_download(c, 'reanalysis-era5-single-levels', inv_req, inv_file, submit_only, meta['submitted'], 'invariant')

    if submit_only:
        with open(meta_file, 'w', encoding='utf-8') as f:
            json.dump(meta, f, indent=2)
        print('Submitted ERA5 requests (no download). Metadata written to:', meta_file)
    else:
        print('Downloaded ERA5 GRIB files into:', outdir)


if __name__ == '__main__':
    main()