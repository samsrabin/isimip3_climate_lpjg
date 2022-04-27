#!/bin/bash

. ./get_years.sh

# Parse ID string and, if needed, make period_actual=period
gcm_lower=$(echo $3 | tr '[:upper:]' '[:lower:]') # Ensure lowercase
. ./get_id.sh

# Check for existing output file(s)
file_nc4="${gcmdir_lpjg}/${gcm_lower}_*_${period}_${var}_global_daily_${firstyear}_${lastyear}.nc4"
does_exist=$(ls ${file_nc4} 2>/dev/null | wc -l)

# For some periods, ensure there's enough memory available
if [[ ${period_actual} == "picontrol" ]]; then
   partition_submit="fat"
   childmem_submit="120G"
#elif [[ ${period_actual} == "historical" ]]; then
#   partition_submit="iojobs"
else
   partition_submit=${partition}
   childmem_submit=${childmem}
fi

# If file does not exist, either submit or save for later
if [ ${does_exist} -eq 0 ]; then
    logfile=${gcmdir_logs}/${thisid}.$(date "+%Y%m%d%H%M%S").log
    thecommand="sbatch -p ${partition_submit} --mem=${childmem_submit} -n 1 -t 12:00:00 -o ${logfile} -J ${thisid} DEPENDENCY ./${childscript} ${phase} ${period} ${gcm} ${period_actual} ${var} ${testing} ${deflate_lvl} ${gcmdir_orig} ${ntest}"

    # Submit historical and future sub-periods of picontrol after all other runs
    if [[ ${period} == "picontrol" && ${period_actual} != "picontrol" ]]; then
       command_list+=("${thecommand}")
       partition_submit_list+=(${partition_submit})
       childmem_submit_list+=(${childmem_submit})
       thisid_list+=(${thisid})
    else
        . ./submit_grandchild.sh
    fi
else
    echo "Skipping ${thisid}"
fi

