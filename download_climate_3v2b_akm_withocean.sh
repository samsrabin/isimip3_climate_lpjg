#!/bin/bash
set -e

# Downloads climate files from Midway cluster, with an "automated kicking machine" to ensure that the transfer is restarted when the connection goes bad for some reason.

timeout=15
bwlimit=10000 # KBytes per second
fileext=".nc"

# Options
# gcm:    GFDL-ESM4, IPSL-CM6A-LR, MPI-ESM1-2-HR, MRI-ESM2-0, or UKESM1-0-LL
gcm=$1
if [[ "${gcm}" == "" ]]; then
   echo "You must provide a GCM or reanalysis product name!"
   exit 1
fi
period=$2
if [[ "${period}" == "" ]]; then
   echo "You must provide a period name!"
   exit 1
fi
doit=$3
if [[ "${doit}" != "" ]]; then
   doit=1
else
   doit=0
fi

# Make sure GCM name is uppercase
#gcm=$(echo "$gcm" | tr '[:upper:]' '[:lower:]')
gcm=$(echo "$gcm" | tr '[:lower:]' '[:upper:]')

# Where will the files be on the remote?
remote_dir=/work/bb0820/ISIMIP/ISIMIP3b/InputData/climate/atmosphere/bias-adjusted/global/daily/${period}/${gcm}

# Where will we be downloading to?
local_dir=climate3b/${period}/${gcm}-withocean
mkdir -p climate3b/${period}/${gcm}-withocean

# Get list of includes
include_list="--include=*_hurs_* --include=*_pr_* --include=*_rsds_* --include=*_sfcwind_* --include=*_tas_* --include=*_tasmax_* --include=*_tasmin_*"
#include_list="--exclude=*_daily_1[67]* --exclude=*_daily_18[0-3]* --include=*_hurs_* --include=*_pr_* --include=*_rsds_* --include=*_sfcwind_* --include=*_tas_* --include=*_tasmax_* --include=*_tasmin_*"
#include_list="--exclude=*_daily_19* --exclude=*_daily_2* --exclude=*_daily_18[5-9]* --include=*_hurs_* --include=*_pr_* --include=*_rsds_* --include=*_sfcwind_* --include=*_tas_* --include=*_tasmax_* --include=*_tasmin_*"

if [[ ${doit} -eq 0 ]]; then
   rsync -ahm --dry-run -v --info=progress2 --ignore-existing  ${include_list} --include="**/" --exclude="*" mistral:${remote_dir} ${local_dir}
   echo " "
   echo "Dry run. To actually download, type anything for a third argument."
else
    transfertxt="${include_list} --exclude="*" mistral:${remote_dir}/"*" ${local_dir}/"
    # Do we need to rsync this file? This does a dry run and counts the number of files that would be transferred.
    notdoneyet=$(rsync -avtn --prune-empty-dirs --ignore-existing  ${transfertxt} | grep $fileext | wc -l)
    ntries=0
    theproblem=" "

    if [[ ${notdoneyet} -gt 0 ]]; then
       echo Starting $d
       while [[ ${notdoneyet} -gt 0 ]]; do
          ntries=$((ntries+1))
          if [[ ${ntries} -gt 1 ]]; then
             echo "Starting try ${ntries} (${theproblem})"
          fi
          set +e
          rsync --prune-empty-dirs -av -h --info=progress2 --timeout=$timeout --bwlimit=$bwlimit --ignore-existing  ${transfertxt}
          result=$?
          if [[ $result -eq 30 ]]; then
            theproblem=timeout
            echo $theproblem
          elif [[ $result -gt 0 ]]; then
            theproblem="error $result"
            echo $theproblem
          fi
          set -e
          notdoneyet=$(rsync -avtn --prune-empty-dirs --ignore-existing  ${transfertxt} | grep $fileext | wc -l)
       done
       echo Done with $d
    else
       echo Skipping $d
    fi
fi

exit 0

