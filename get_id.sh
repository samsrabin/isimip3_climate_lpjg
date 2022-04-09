#!/bin/bash

gcm_lower=$(echo ${gcm} | tr '[:upper:]' '[:lower:]') # Ensure lowercase
if [[ "${gcm_lower}" == "mpi-esm1-2-hr" || "${gcm_lower}" == "mri-esm2-0" ]]; then
	gcm_token=${gcm_lower:0:3}
else
	gcm_token=${gcm_lower:0:4}
fi

if [[ "${period_actual}" == "preind1" ]]; then
	pa_token=p1
elif [[ "${period_actual}" == "preind2" ]]; then
	pa_token=p2
else
	pa_token=${period_actual:0:2}
fi

if [[ ${period_actual} == "" ]]; then
	thisid="${phase}-${period:0:4}-${gcm_token}-${var}"
	period_actual=${period}
else
	thisid="${phase}-${period:0:2}${pa_token}-${gcm_token}-${var}"
fi

