#!/bin/bash
set -euo pipefail

# Assuming this script is always located in 'api_scripts' and is called from the parent directory
pushd "$(dirname "$0")" >/dev/null 2>&1

source nb_script_function.sh

nb_runscript 3_Services.L2VPNsBulkImport --file ../intents/netbox_intents/l2vpns-lab01.yaml "$@"
nb_runscript 3_Services.VRFsBulkImport --file ../intents/netbox_intents/l3vpns-lab01.yaml "$@"

popd >/dev/null 2>&1
