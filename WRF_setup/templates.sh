#!/usr/bin/env bash

set -euo pipefail

source config.sh

bash template_functions/namelist_wps.sh
bash template_functions/namelist_input.sh
bash template_functions/mmif_template.sh
bash template_functions/calwrf_template.sh
bash template_functions/site_csv.sh