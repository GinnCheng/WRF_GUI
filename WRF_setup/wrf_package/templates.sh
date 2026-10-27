#!/usr/bin/env bash

set -euo pipefail

INIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${INIT_DIR}/config.sh"

bash template_functions/namelist_wps.sh
bash template_functions/namelist_input.sh
bash template_functions/mmif_template.sh
bash template_functions/calwrf_template.sh
bash template_functions/site_csv.sh