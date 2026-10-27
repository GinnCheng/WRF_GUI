#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "${SCRIPT_DIR}/config.sh"

cat > "${TEMPLATE_DIR}/namelist.wps.template" << EOF
&share
 wrf_core = 'ARW',
 max_dom = ${MAX_DOM},

 start_date = 'START_DATE', 'START_DATE', 'START_DATE',
 end_date   = 'END_DATE',   'END_DATE',   'END_DATE',

 interval_seconds = 3600,

 io_form_geogrid = 2,
/

&geogrid
 parent_id = 1, 1, 2,

 parent_grid_ratio = 1, 3, 3,

 i_parent_start = 1, 11, 12,
 j_parent_start = 1, 11, 12,

 e_we = ${D01_E_WE}, ${D02_E_WE}, ${D03_E_WE},
 e_sn = ${D01_E_SN}, ${D02_E_SN}, ${D03_E_SN},

 dx = ${D01_DX},
 dy = ${D01_DY},

 map_proj = 'lambert',

 ref_lat = ${SITE_LAT},
 ref_lon = ${SITE_LON},

 truelat1 = ${TRUELAT1},
 truelat2 = ${TRUELAT2},

 stand_lon = ${STAND_LON},

 geog_data_res = 'default', 'default', 'default',

 geog_data_path = '${WPS_GEOG}',

 opt_geogrid_tbl_path = '${WPS_DIR}/geogrid',
/

&ungrib
 out_format = 'WPS',
 prefix = 'FILE',
/

&metgrid
 fg_name = 'FILE',
 io_form_metgrid = 2,
 opt_metgrid_tbl_path = '${WPS_DIR}/metgrid',
/
EOF