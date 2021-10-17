#!/bin/bash

gcm_lower=$(echo ${gcm} | tr '[:upper:]' '[:lower:]') # Ensure lowercase

# Parse phase from GCM
if [[ "${gcm_lower}" == "gswp3" || "${gcm_lower}" == "gswp3-w5e5" ]]; then
   phase="3a"
elif [[ "${gcm_lower}" = "gfdl-esm4" || "${gcm_lower}" = "ipsl-cm6a-lr" || "${gcm_lower}" = "mpi-esm1-2-hr" || "${gcm_lower}" = "mri-esm2-0" || "${gcm_lower}" = "ukesm1-0-ll" ]]; then
   phase="3b"
else
   echo "GCM ${gcm} not recognized!"
   exit 1
fi

