#!/bin/bash
set -euo pipefail

# Assuming this script is always located in 'api_scripts' and is called from the parent directory
pushd "$(dirname "$0")" >/dev/null 2>&1

source nb_script_function.sh

nb_runscript 1_NetboxInit.InitializeNetbox "$@"

nb_runscript 2_Infrastructure.ImportFabricFromYAML --file ../intents/netbox_intents/lab01.yaml "$@"
nb_runscript 2_Infrastructure.BulkImportLAGsFromYAML --file ../intents/netbox_intents/lags-lab01.yaml "$@"

popd >/dev/null 2>&1
