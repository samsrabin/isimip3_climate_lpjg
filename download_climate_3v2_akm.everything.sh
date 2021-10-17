#!/bin/bash
set -e

# Downloads climate files from Midway cluster, with an "automated kicking machine" to ensure that the transfer is restarted when the connection goes bad for some reason.

timeout=15
bwlimit=10000 # KBytes per second
fileext=".nc"

# Options
phase=$1
if [[ "${phase}" == "" ]]; then
   echo "You must provide a phase!"
   exit 1
elif [[ "${phase}" == "a" ]] || [[ "${phase}" == "b" ]]; then
   phase=3${phase}
fi
if [[ "${phase}" != "3a" ]] && [[ "${phase}" != "3b" ]]; then
   echo "Phase ${phase} not recognized!"
   exit 1
fi
# gcm:    GFDL-ESM4, IPSL-CM6A-LR, MPI-ESM1-2-HR, MRI-ESM2-0, or UKESM1-0-LL
gcm=$2
if [[ "${gcm}" == "" ]]; then
   echo "Will try to download all GCMs or reanalysis products"
fi
doit=$3
if [[ "${doit}" != "" ]]; then
   doit=1
else
   doit=0
fi

# Make sure GCM name is lowercase
gcm=$(echo "$gcm" | tr '[:upper:]' '[:lower:]')

# Where will the files be on the remote?
remote_dir_top=/project2/ggcmi/AgMIP.input/phase3/ISIMIP3/climate_land_only_v2/climate${phase}

# Get list of includes
include_list="--include=${gcm}*_hurs_* --include=${gcm}*_pr_* --include=${gcm}*_rsds_* --include=${gcm}*_sfcwind_* --include=${gcm}*_tas_* --include=${gcm}*_tasmax_* --include=${gcm}*_tasmin_*"

if [[ ${doit} -eq 0 ]]; then
#   #rsync -ahm --dry-run -v --info=progress2 --partial ${include_list} --include="*/*/" --include="*/" --exclude="*" midway:${remote_dir_top} .
   rsync -ahm --dry-run -v --info=progress2 --ignore-existing  ${include_list} --include="*/*/" --include="*/" --exclude="*" midway:${remote_dir_top} .
   echo " "
   echo "Dry run. To actually download, type anything for a third argument."
else
    transfertxt="${include_list} --include="*/*/" --include="*/" --exclude="*" midway:${remote_dir_top} ."
    # Do we need to rsync this file? This does a dry run and counts the number of files that would be transferred.
#    notdoneyet=$(rsync -avtn --prune-empty-dirs --partial ${transfertxt} | grep $fileext | wc -l)
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
          #rsync --prune-empty-dirs -a -v -h --progress --timeout=$timeout --bwlimit=$bwlimit --partial ${transfertxt}
#          rsync --prune-empty-dirs -av -h --info=progress2 --timeout=$timeout --bwlimit=$bwlimit --partial ${transfertxt}
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
#          notdoneyet=$(rsync -avtn --prune-empty-dirs --partial ${transfertxt} | grep $fileext | wc -l)
          notdoneyet=$(rsync -avtn --prune-empty-dirs --ignore-existing  ${transfertxt} | grep $fileext | wc -l)
       done
       echo Done with $d
    else
       echo Skipping $d
    fi
fi

exit 0

