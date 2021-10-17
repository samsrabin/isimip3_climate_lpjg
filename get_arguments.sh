#!/bin/bash

# Arguments: Phase and GCM

phase=$1
if [[ "${phase}" != "3a" && "${phase}" != "3b" ]]; then
   echo "First argument (phase) must be either 3a or 3b, not '${phase}'"
   exit 1
fi
dir_phase="climate${phase}"

gcm=$(echo $3 | tr '[:lower:]' '[:upper:]') # Ensure uppercase
if [[ "${gcm}" == "" ]]; then
   echo "You must provide an argument (3rd) for gcm."
   exit 1
fi

