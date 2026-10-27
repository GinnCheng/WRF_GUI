#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "${SCRIPT_DIR}/config.sh"

cat > "${TEMPLATE_DIR}/namelist.input.template" << EOF
&time_control

 run_days = 0,
 run_hours = 0,
 run_minutes = 0,
 run_seconds = 0,

 start_year  = START_YYYY, START_YYYY, START_YYYY,
 start_month = START_MM, START_MM, START_MM,
 start_day   = START_DD, START_DD, START_DD,
 start_hour  = START_HH, START_HH, START_HH,

 end_year  = END_YYYY, END_YYYY, END_YYYY,
 end_month = END_MM, END_MM, END_MM,
 end_day   = END_DD, END_DD, END_DD,
 end_hour  = END_HH, END_HH, END_HH,

 interval_seconds = 3600,

 input_from_file = .true., .true., .true.,

 history_interval = ${HISTORY_INTERVAL}, ${HISTORY_INTERVAL}, ${HISTORY_INTERVAL},

 frames_per_outfile = ${FRAMES_PER_OUTFILE}, ${FRAMES_PER_OUTFILE}, ${FRAMES_PER_OUTFILE},

 restart = .false.,

 io_form_history = 2,
 io_form_restart = 2,
 io_form_input = 2,
 io_form_boundary = 2,
/

&domains

 time_step = ${TIME_STEP},

 max_dom = ${MAX_DOM},

 e_we = ${D01_E_WE}, ${D02_E_WE}, ${D03_E_WE},
 e_sn = ${D01_E_SN}, ${D02_E_SN}, ${D03_E_SN},

 e_vert = ${E_VERT}, ${E_VERT}, ${E_VERT},

 p_top_requested = ${P_TOP_REQUESTED},

 num_metgrid_levels = METGRID_LEVELS,
 num_metgrid_soil_levels = METGRID_SOIL_LEVELS,

 dx = ${D01_DX}, ${D02_DX}, ${D03_DX},
 dy = ${D01_DY}, ${D02_DY}, ${D03_DY},

 grid_id = 1, 2, 3,

 parent_id = 1, 1, 2,

 i_parent_start = 1, 11, 12,
 j_parent_start = 1, 11, 12,

 parent_grid_ratio = 1, 3, 3,
 parent_time_step_ratio = 1, 3, 3,

 feedback = 0,
 smooth_option = 0,
/

&physics

 mp_physics = ${MP_PHYSICS}, ${MP_PHYSICS}, ${MP_PHYSICS},

 ra_lw_physics = ${RA_LW_PHYSICS}, ${RA_LW_PHYSICS}, ${RA_LW_PHYSICS},
 ra_sw_physics = ${RA_SW_PHYSICS}, ${RA_SW_PHYSICS}, ${RA_SW_PHYSICS},

 bl_pbl_physics = ${BL_PBL_PHYSICS}, ${BL_PBL_PHYSICS}, ${BL_PBL_PHYSICS},

 cu_physics = ${CU_PHYSICS_D01}, ${CU_PHYSICS_NEST}, ${CU_PHYSICS_NEST},

 sf_sfclay_physics = ${SF_SFCLAY_PHYSICS}, ${SF_SFCLAY_PHYSICS}, ${SF_SFCLAY_PHYSICS},
 sf_surface_physics = ${SF_SURFACE_PHYSICS}, ${SF_SURFACE_PHYSICS}, ${SF_SURFACE_PHYSICS},

 num_soil_layers = ${NUM_SOIL_LAYERS},
/

&dynamics

 w_damping = 0,

 diff_opt = 1,

 km_opt = 4,
/

&bdy_control

 spec_bdy_width = 5,

 specified = .true., .false., .false.,
 nested = .false., .true., .true.,
/

&namelist_quilt

 nio_tasks_per_group = 0,
 nio_groups = 1,
/
EOF